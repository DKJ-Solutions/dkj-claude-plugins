<#
.SYNOPSIS
    The Stopwatch's and the Logbook's routes, answered for any hub server (#3470): /stopwatch, /stopwatch/<label>,
    /stopwatch/<label>/<run>, /logbook and /logbook/<slug>.

.DESCRIPTION
    ONE ROUTER FOR TWO SERVERS. The pages began on the source repo's own hub (serve-connector-dashboard.ps1) and are
    every repo's since #3470, served by this plugin's serve-general-pages.ps1. Both servers call
    Resolve-HubTimingPage with a context from New-HubTimingContext, so the rules of which page a path is, and which
    path is a redirect or a 404, are written once.

    THE CONTEXT FIXES WHAT A SERVER READS FOR ITS WHOLE LIFE: the repo's stores (one per repo, Get-StopwatchStorePath),
    its transcripts, ship-pr's step log, and whether it shares its runs with its other machines
    (Test-StopwatchShareEnabled, read from the environment the server was started in). A test passes stores of its
    own, and then the context never shares: a test must neither read the checkout's refs nor reach the network.

    The pages themselves are stopwatch-lib.ps1's and logbook-lib.ps1's, the sync stopwatch-sync-lib.ps1's, all
    beside this file and loaded by it, with general-pages-lib.ps1, which the caller loads first. Pure ASCII (repo
    convention for .ps1). Tested by scripts/tests/dev-pages.tests.ps1 in the source repo.
#>

. (Join-Path $PSScriptRoot 'logbook-lib.ps1')
. (Join-Path $PSScriptRoot 'stopwatch-sync-lib.ps1')

function New-HubTimingContext {
    <#
        What a server hands Resolve-HubTimingPage on every request: the repo at -RepoRoot, its name for the page
        header (-RepoName) and where Home goes (-HubHref), and the stores. -StopwatchPath, -LogbookPath and
        -TranscriptDir are for the tests; a store passed in turns sharing off. Without them the machine-wide stores of
        before #3470 are taken over first, where this is the source repo (Move-HubTimingLegacyStore).
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [AllowEmptyString()][string]$RepoName = '',
        [string]$HubHref = '/hub',
        [AllowEmptyString()][string]$StopwatchPath = '',
        [AllowEmptyString()][string]$LogbookPath = '',
        [AllowEmptyString()][string]$TranscriptDir = ''
    )
    $own = -not $StopwatchPath
    if ($own) { [void](Move-HubTimingLegacyStore -RepoRoot $RepoRoot); $StopwatchPath = Get-StopwatchStorePath -RepoRoot $RepoRoot }
    if (-not $LogbookPath) { $LogbookPath = Join-Path (Split-Path -Parent $StopwatchPath) 'logbook.json' }
    if (-not $TranscriptDir) { $TranscriptDir = Get-StopwatchTranscriptDir -RepoRoot $RepoRoot }
    $shared = $own -and (Test-StopwatchShareEnabled)
    return @{
        Root = $RepoRoot; RepoName = $RepoName; HubHref = $HubHref
        StopwatchPath = $StopwatchPath; LogbookPath = $LogbookPath; TranscriptDir = $TranscriptDir
        StopwatchPhasesPath = (Join-Path (Split-Path -Parent $StopwatchPath) 'stopwatch-phases.json')
        LogbookPhasesPath = (Join-Path (Split-Path -Parent $LogbookPath) 'logbook-phases.json')
        # ship-pr's step marks (#3338): the writer's own path, from the lib stopwatch-lib.ps1 loads.
        StepLogPath = $(if ($script:StopwatchStepLogAvailable) { Get-RunStepLogPath } else { '' })
        Shared = $shared
        # The machine id names this machine, so it is one for every repo's store on it (#3470).
        MachineId = $(if ($shared) { Get-StopwatchMachineId -StoreDir (Get-HubTimingBaseDir) } else { '' })
    }
}

function Get-StopwatchPageRuns {
    <#
        The Stopwatch's runs for a page: this machine's store, less what this machine hid (#3446), and where -Context
        shares, the other machines' runs merged in (Merge-StopwatchRuns) with their phases, less what any machine hid;
        then it also starts a background sync when one is due. Returns @{ Store; Runs; Shared }.
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context)
    $path = $Context.StopwatchPath
    $store = Read-StopwatchStore -Path $path
    $shared = @{ Runs = @(); Phases = @{}; Hidden = @(); Machines = 0 }
    $ownHidden = @((Read-StopwatchHidden -Path (Get-StopwatchHiddenPath -StorePath $path)).Entries)
    if (-not $Context.Shared) { return @{ Store = $store; Runs = @(Select-StopwatchVisibleRuns -Runs $store.Runs -Entries $ownHidden); Shared = $shared } }
    $stamp = Join-Path (Split-Path -Parent $path) 'stopwatch-sync.stamp'
    if (Test-StopwatchSyncDue -StampPath $stamp) {
        # Stamped here as well as by the sync itself, so the loads before it starts do not start more.
        try { [System.IO.File]::WriteAllText($stamp, (Format-StopwatchStamp ([datetime]::UtcNow))) } catch { }
        [void](Start-StopwatchSync -RepoRoot $Context.Root)
    }
    $shared = Read-StopwatchShared -RepoRoot $Context.Root -MachineId $Context.MachineId
    # A sync under way is said on every visit, not only the first (#3377, #3403): the page renders the refs LAST
    # fetched, so a run published since is missing until the sync ends. The log a sync writes as it ends dates that copy.
    $syncLog = Join-Path (Split-Path -Parent $path) 'stopwatch-sync.log'
    $shared.Fetching = Test-StopwatchSyncRunning -StampPath $stamp -LogPath $syncLog
    $shared.LastFetched = if (Test-Path -LiteralPath $syncLog -PathType Leaf) { (Get-Item -LiteralPath $syncLog).LastWriteTimeUtc } else { $null }
    # What any machine hid (#3446): this machine's own entries straight from its hide file, so a hide shows before it is synced.
    $runs = Select-StopwatchVisibleRuns -Runs (Merge-StopwatchRuns -Local $store.Runs -Shared $shared.Runs) -Entries ($ownHidden + @($shared.Hidden))
    return @{ Store = $store; Runs = $runs; Shared = $shared }
}

function Resolve-HubTimingPage {
    <#
        The answer to -Path when it is one of the Stopwatch's or the Logbook's routes, else $null: @{ Status; Html;
        Location }, Status 200 with the page, 301 with the Location a bare run slug moved to, or 404. A label's page,
        or a run's page under its label's (#3323), so the URL reads as the crumbs do; a slug neither has is a 404, like
        any other path. A store that does not read shows the overview's warning on every page, not a bare 404 for a
        page that may well exist.
    #>
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][hashtable]$Context)
    $c = $Context
    $site = @{ RepoName = $c.RepoName; HubHref = $c.HubHref }
    $ok = { param($html) @{ Status = 200; Html = $html; Location = '' } }
    $missing = @{ Status = 404; Html = ''; Location = '' }
    if ($Path -eq '/stopwatch') {
        $sw = Get-StopwatchPageRuns -Context $c; $store = $sw.Store
        return (& $ok (Format-StopwatchPageHtml -Model (ConvertTo-StopwatchModel -Runs $sw.Runs) -ReadError $store.Error -Skipped $store.Skipped -StorePath $c.StopwatchPath `
            -SharedMachines $sw.Shared.Machines -Fetching:([bool]$sw.Shared.Fetching) -LastFetched $(if ($sw.Shared.ContainsKey('LastFetched')) { $sw.Shared.LastFetched } else { $null }) `
            -Shared:([bool]$c.Shared) @site))
    }
    if ($Path -match '^/stopwatch/([a-z0-9-]{1,60})(?:/([a-z0-9-]{1,60}))?$') {
        $swSlug = $Matches[1]; $swRunSlug = $Matches[2]
        $sw = Get-StopwatchPageRuns -Context $c; $store = $sw.Store
        if ($store.Error) { return (& $ok (Format-StopwatchPageHtml -Model (ConvertTo-StopwatchModel -Runs @()) -ReadError $store.Error -StorePath $c.StopwatchPath -Shared:([bool]$c.Shared) @site)) }
        $swModel = ConvertTo-StopwatchModel -Runs $sw.Runs
        $labelSet = Find-StopwatchLabel -Model $swModel -Slug $swSlug
        if (-not $swRunSlug) {
            $group = Find-StopwatchGroup -Model $swModel -Slug $swSlug
            if ($group -and $group.LabelSlug) { return @{ Status = 301; Html = ''; Location = "/stopwatch/$($group.LabelSlug)/$($group.PageSlug)" } }
            if ($labelSet) { return (& $ok (Format-StopwatchLabelPageHtml -Set $labelSet -StorePath $c.StopwatchPath -Shared:([bool]$c.Shared) @site)) }
            return $missing
        }
        $group = if ($labelSet) { @($labelSet.Groups | Where-Object { $_.PageSlug -ceq $swRunSlug }) | Select-Object -First 1 } else { $null }
        if (-not $group) { return $missing }
        # Only this machine's runs are read from its transcripts; another machine's carry the phases it read from its own.
        $phases = Get-StopwatchTranscriptCache -Runs @($group.Rows | ForEach-Object { $_.Run } | Where-Object { -not $_.Machine }) -CachePath $c.StopwatchPhasesPath -TranscriptDir $c.TranscriptDir -StepLogPath $c.StepLogPath -RepoRoot $c.Root
        foreach ($k in $sw.Shared.Phases.Keys) { if (-not $phases.ContainsKey($k)) { $phases[$k] = $sw.Shared.Phases[$k] } }
        return (& $ok (Format-StopwatchRunPageHtml -Group $group -StorePath $c.StopwatchPath -Transcript $phases -LabelCrumb -Shared:([bool]$c.Shared) @site))
    }
    if ($Path -eq '/logbook') {
        $lb = Read-StopwatchStore -Path $c.LogbookPath
        # A sweep is shown per issue, cut at its folds (#3405).
        $lbRuns = Get-LogbookRuns -Runs $lb.Runs -StepLogPath $c.StepLogPath -RepoRoot $c.Root
        # Every finished run's phases, for its work time on its card: read from the transcripts once, then cached.
        $phases = Get-StopwatchTranscriptCache -Runs @($lbRuns | Where-Object { $_.End }) -CachePath $c.LogbookPhasesPath -TranscriptDir $c.TranscriptDir -StepLogPath $c.StepLogPath -RepoRoot $c.Root
        return (& $ok (Format-LogbookPageHtml -Runs $lbRuns -ReadError $lb.Error -Skipped $lb.Skipped -StorePath $c.LogbookPath -Transcript $phases @site))
    }
    if ($Path -match '^/logbook/([a-z0-9-]{1,60})$') {
        $lbSlug = $Matches[1]
        $lb = Read-StopwatchStore -Path $c.LogbookPath
        if ($lb.Error) { return (& $ok (Format-LogbookPageHtml -Runs @() -ReadError $lb.Error -StorePath $c.LogbookPath @site)) }
        $group = Find-StopwatchGroup -Model (ConvertTo-LogbookModel -Runs (Get-LogbookRuns -Runs $lb.Runs -StepLogPath $c.StepLogPath -RepoRoot $c.Root)) -Slug $lbSlug
        if (-not $group) { return $missing }
        $phases = Get-StopwatchTranscriptCache -Runs @($group.Rows | ForEach-Object { $_.Run }) -CachePath $c.LogbookPhasesPath -TranscriptDir $c.TranscriptDir -StepLogPath $c.StepLogPath -RepoRoot $c.Root
        return (& $ok (Format-LogbookRunPageHtml -Group $group -StorePath $c.LogbookPath -Transcript $phases @site))
    }
    return $null
}
