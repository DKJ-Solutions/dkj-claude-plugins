<#
.SYNOPSIS
    The Stopwatch page of this repo's dev server (#3315, #3323): a read-only view of how long each assignment took,
    from the prompt that gave it to the moment Claude was back on the trunk, with each run compared against the
    previous run of the same label, so the slow steps of the workflow show and every next run can be made shorter.

.DESCRIPTION
    THE PAGE ONLY SHOWS. It has no button and the server takes no POST for it. The runs are written by two Claude
    Code hooks, scripts/dashboard/stopwatch-hook.ps1, which call Invoke-StopwatchHookEvent here:

      - A prompt whose first line begins with `stopwatch:` (any case, leading whitespace allowed) starts an Auto
        run at once, labelled with the rest of that line (Get-StopwatchPromptMarker; "Assignment" when empty),
        with the checkout's HEAD as its StartHead. It is the only way a run starts. A run still going when a
        marked prompt arrives is DISCARDED and the new one starts: a run that never reached the trunk would
        otherwise block every later measurement, and the page has no button left to discard it.
      - A Stop hook ends the running run once the checkout is on the trunk, clean, with HEAD moved off StartHead.
        That is a sign the work landed, not a proof of it. The HEAD test is the reason no branch needs to be seen:
        a whole ship (branch, PR, merge, fold) usually happens inside one turn, and the Stop hook fires only at a
        turn's end. A turn that only answers leaves HEAD where it was, and a branch parked for the owner's eye is
        not on the trunk, so the run keeps going in both. HEAD must also hold a commit made during the run, so a
        fast-forward of older commits stops nothing, and a label that begins with `release` waits for the cut's
        `release: vX.Y.Z release notes` commit (#3400), so a release cut is timed to its end.

    THREE PAGES, ALL READ-ONLY AND BARE (no lead or tiles above their content, only the hub's airsquats banner,
    which is on every hub page, #3356; the plugin's Format-GeneralPageHtml -Bare). '/stopwatch' is an overview of
    cards under an h1 naming the page, ONE PER PROMPT LABEL, three to a row (the owner, October 24, 2026): an h2 with the
    label's short title, when a run of it starts and stops, and its fastest time (or the live clock of its only run). Each links to '/stopwatch/<label slug>'
    (Get-StopwatchSlugs), the label's page, which holds ONE CARD PER RUN of that label, never merged (the owner,
    October 23, 2026: runs of one label were merged into one card twice): named by the run's start, with its label,
    its time and its change against the previous run of the same label, in the hub's own card markup. Each run card
    links to '/stopwatch/<run slug>', the run's page: its time, that change and its transcript phases. A run's slug
    is its start (ConvertTo-StopwatchModel) and is asked first, a label's second, and an unknown slug is a 404.

    THE CLOCK IS THE HOOKS', NOT THE PAGE'S. A run is a start stamp and an end stamp in the store, and the page
    only draws the time since the stored start. The hub restarts itself whenever the checkout's HEAD moves
    (#3122), and the workflow a run measures moves HEAD at every branch switch, merge and fold, so a clock kept in
    the page would be lost halfway through the very run it is timing.

    THE STORE IS OUTSIDE THE TREE: %LOCALAPPDATA%\dkj-claude-plugins\stopwatch.json (Get-StopwatchStorePath).
    A file in the checkout would dirty it in the middle of the workflow being measured, and the scripts
    that ship a branch refuse a dirty tree. So the store is this machine's, like the session transcripts the
    transcript phases read (below). ITS FINISHED RUNS ARE SHARED (#3349): each machine publishes them, with the phases
    it read for them, to a ref of its own on origin, and the pages show every other machine's beside this one's
    (scripts/lib/stopwatch-sync-lib.ps1). A run from another machine carries a Machine field; this machine's do not.

    OLD STORES STILL READ. Earlier versions of the page also kept laps, notes and an armed label, written by
    buttons that are gone. A field this file does not know is ignored on read and is not written back, so the
    first hook write after the upgrade drops it; an old hand-started run shows as a plain row. A running hub must
    be restarted to pick up this code: an old server would write the old shape back.

    A STORE THAT DOES NOT READ IS NEVER WRITTEN OVER. Read-StopwatchStore returns an Error for a file that
    is not valid JSON, and the hook refuses to write while it is set, so one bad edit by hand loses nothing.

    Pure except Read-StopwatchStore and Save-StopwatchStore (the store's own file), Read-StopwatchTranscriptEvents
    (one session transcript, read only) and Get-StopwatchTranscriptCache (the transcripts, and stopwatch-phases.json
    beside the store). Every
    value that reaches the page is escaped through ConvertTo-DashboardText. Pure ASCII (repo convention for
    .ps1). Tested by scripts/tests/stopwatch.tests.ps1.
#>

$script:StopwatchLabelMax = 80

# The step log's reader (#3338), for a ship's steps. Guarded: a tree that copies this file alone keeps one ship phase.
$swRunProgressLib = Join-Path $PSScriptRoot 'run-progress-lib.ps1'
$script:StopwatchStepLogAvailable = $false
if (Test-Path -LiteralPath $swRunProgressLib -PathType Leaf) { . $swRunProgressLib; $script:StopwatchStepLogAvailable = $true }

function Get-StopwatchStorePath {
    <# The store's path on this machine: under LOCALAPPDATA, else the per-user local data folder .NET names. #>
    $base = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { [Environment]::GetFolderPath('LocalApplicationData') }
    return (Join-Path $base 'dkj-claude-plugins\stopwatch.json')
}

function ConvertTo-StopwatchTime {
    <# A stored timestamp as a UTC DateTime, or $null. ConvertFrom-Json leaves it a string in 5.1 and makes it a DateTime in 7. #>
    param($Value)
    if ($Value -is [datetime]) { return $Value.ToUniversalTime() }
    if (-not $Value) { return $null }
    $t = [datetime]::MinValue
    if ([datetime]::TryParse([string]$Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind, [ref]$t)) { return $t.ToUniversalTime() }
    return $null
}

function Format-StopwatchStamp {
    <# A UTC DateTime as the store writes it: ISO 8601 with milliseconds and a Z. #>
    param([datetime]$Time)
    return $Time.ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'", [Globalization.CultureInfo]::InvariantCulture)
}

function ConvertTo-StopwatchRun {
    <# One run from the parsed store as a hashtable, or $null when it has no id, label or readable start. #>
    param($Raw)
    if ($null -eq $Raw) { return $null }
    $id = [string]$Raw.id; $label = [string]$Raw.label
    $start = ConvertTo-StopwatchTime $Raw.start
    if ($id -cnotmatch '^[0-9A-Za-z-]{1,40}\z' -or -not $label.Trim() -or -not $start) { return $null }
    return @{ Id = $id; Label = $label.Trim(); Start = $start; End = (ConvertTo-StopwatchTime $Raw.end); Auto = [bool]$Raw.auto; StartHead = [string]$Raw.startHead; Session = [string]$Raw.session }
}

function Read-StopwatchStore {
    <#
        The runs in the store at -Path, oldest first, and an Error that is empty when it read. A missing file is
        an empty store, not an error. A run that does not parse is skipped and counted in Skipped; a field of an
        older version (laps, notes, an armed label) is ignored. Sessions is the store's list of session ids seen,
        which only the Logbook's store keeps (scripts/lib/logbook-lib.ps1, #3364); empty for the Stopwatch's.
    #>
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @{ Runs = @(); Error = ''; Skipped = 0; Sessions = @() } }
    try {
        $text = [System.IO.File]::ReadAllText($Path, (New-Object System.Text.UTF8Encoding($false)))
        $json = if ($text.Trim()) { $text | ConvertFrom-Json } else { $null }
    } catch {
        return @{ Runs = @(); Error = 'it is not valid JSON'; Skipped = 0; Sessions = @() }
    }
    $runs = @(); $skipped = 0
    foreach ($r in @($(if ($json) { $json.runs } else { @() }))) {
        if ($null -eq $r) { continue }
        $run = ConvertTo-StopwatchRun $r
        if ($run) { $runs += $run } else { $skipped++ }
    }
    $sessions = @($(if ($json -and $json.sessions) { @($json.sessions) } else { @() }) | Where-Object { $_ -is [string] -and $_ -cmatch '^[0-9A-Za-z-]{1,64}\z' })
    return @{ Runs = @($runs | Sort-Object { $_.Start }); Error = ''; Skipped = $skipped; Sessions = $sessions }
}

function Save-StopwatchStore {
    <#
        Writes -Runs to -Path through a file beside it, so a failed write never leaves half a store. A run's Session
        and the store's -Sessions are written only when set: the Logbook's (#3364), never the Stopwatch's.
    #>
    param([Parameter(Mandatory = $true)][string]$Path, [AllowEmptyCollection()][object[]]$Runs = @(), [AllowEmptyCollection()][string[]]$Sessions)
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
    $out = @{ runs = @(foreach ($r in @($Runs)) {
                $o = [ordered]@{
                    id        = $r.Id
                    label     = $r.Label
                    start     = (Format-StopwatchStamp $r.Start)
                    end       = $(if ($r.End) { Format-StopwatchStamp $r.End } else { $null })
                    auto      = [bool]$r.Auto
                    startHead = [string]$r.StartHead
                }
                if ($r.Session) { $o.session = [string]$r.Session }
                $o
            }) }
    if ($PSBoundParameters.ContainsKey('Sessions')) { $out.sessions = @($Sessions | Where-Object { $_ }) }
    $tmp = "$Path.tmp"
    [System.IO.File]::WriteAllText($tmp, ($out | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function New-StopwatchRunId {
    <# A run's id: the start time plus four hex. #>
    param([Parameter(Mandatory = $true)][datetime]$Now)
    return $Now.ToUniversalTime().ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture) + '-' + ([guid]::NewGuid().ToString('N').Substring(0, 4))
}

function New-StopwatchRun {
    <# A run that starts now, started by a hook (Auto) at the checkout's HEAD, -StartHead (#3323). #>
    param([Parameter(Mandatory = $true)][string]$Label, [Parameter(Mandatory = $true)][datetime]$Now, [string]$StartHead = '')
    return @{ Id = (New-StopwatchRunId -Now $Now); Label = $Label; Start = $Now.ToUniversalTime(); End = $null; Auto = $true; StartHead = $StartHead }
}

function Get-StopwatchPromptMarker {
    <#
        The label a prompt asks a run under, or $null when it carries no marker (#3323): the first line of -Prompt
        begins, after any leading whitespace, with `stopwatch:` in any case. The label is the rest of that line,
        control characters as spaces, trimmed and cut to the label maximum; empty becomes "Assignment".
        A prompt that is a paste arrives wrapped, its first line Claude Code's `<pasted_content id="hhhh">` (#3336),
        so one such opening line is skipped and the marker is read from the pasted text's first line.
    #>
    param([AllowEmptyString()][string]$Prompt = '')
    $text = [regex]::Replace($Prompt.TrimStart(), '^<pasted_content id="[0-9a-f]{4}">[ \t]*\r?\n', '')
    $m = [regex]::Match($text.TrimStart(), '^stopwatch:([^' + [char]13 + [char]10 + ']*)', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $m.Success) { return $null }
    $label = ($m.Groups[1].Value -replace ('[' + [char]0 + '-' + [char]31 + [char]127 + ']'), ' ').Trim()
    if ($label.Length -gt $script:StopwatchLabelMax) { $label = $label.Substring(0, $script:StopwatchLabelMax).Trim() }
    if (-not $label) { $label = 'Assignment' }
    return $label
}

function ConvertFrom-StopwatchCommitLog {
    <#
        The commits Invoke-StopwatchHookEvent -Commits reads (#3400), from the lines of
        `git log --format='%ct %s' <StartHead>..HEAD`: each @{ Subject; Time }, Time the committer time in UTC. A
        line that does not start with a Unix time is skipped.
    #>
    param([AllowEmptyCollection()][string[]]$Lines = @())
    $epoch = New-Object DateTime 1970, 1, 1, 0, 0, 0, ([DateTimeKind]::Utc)
    return @(foreach ($line in @($Lines)) {
        $m = [regex]::Match([string]$line, '^(\d+) ?(.*)$')
        if ($m.Success) { @{ Subject = $m.Groups[2].Value; Time = $epoch.AddSeconds([double]$m.Groups[1].Value) } }
    })
}

function Invoke-StopwatchHookEvent {
    <#
        What a Claude Code hook does to the store (#3323), decided without git or a clock so every rule is tested.
        -Hook Prompt: a -Prompt marked `stopwatch:` (Get-StopwatchPromptMarker) starts a run at -Now under its
        label with -Head as its StartHead, and DISCARDS a run still going (it would otherwise block every later
        measurement); any other prompt does nothing, and so does a marked one with an empty -Head, since a run
        without a StartHead could never stop by itself. -Hook Stop: the running run ends at -Now only when it is
        Auto, -Branch is -Trunk, -Clean (git status --porcelain was empty) and -Head is not the run's StartHead,
        taken as work that landed (it proves HEAD moved, not that anything was merged); otherwise nothing.
        -Commits, the commits in StartHead..HEAD as @{ Subject; Time } (Time the committer time, UTC), narrows
        that further (#3400): HEAD must hold a commit made during the run, so a fast-forward that only brought in
        older commits by others stops nothing. And a run whose label begins with `release` (any case) stops only
        on a `release: vX.Y.Z release notes` commit made during the run, the commit cut-release's step 4
        prescribes, because a cut moves HEAD at the fast-forward and again at the release commit, minutes before
        it is done. A commit counts from the second the run started in, since a committer time has no fraction.
        $null (the hook could not read git) leaves the HEAD test alone: a timing aid that never stops is worse.
        Returns Runs and Changed (write only when set).
    #>
    param(
        [Parameter(Mandatory = $true)][ValidateSet('Prompt', 'Stop')][string]$Hook,
        [AllowEmptyCollection()][object[]]$Runs = @(),
        [Parameter(Mandatory = $true)][datetime]$Now,
        [string]$Branch = '',
        [bool]$Clean = $false,
        [string]$Head = '',
        [string]$Trunk = 'main',
        [AllowEmptyString()][string]$Prompt = '',
        [AllowEmptyCollection()][object[]]$Commits = $null
    )
    $runs = @($Runs | Where-Object { $_ })
    $running = @($runs | Where-Object { -not $_.End }) | Select-Object -Last 1
    $same = @{ Runs = $runs; Changed = $false }
    if ($Hook -eq 'Prompt') {
        $label = Get-StopwatchPromptMarker -Prompt $Prompt
        if ($null -eq $label -or -not $Head) { return $same }
        $kept = @($runs | Where-Object { $_.End })
        return @{ Runs = @($kept + @(New-StopwatchRun -Label $label -Now $Now -StartHead $Head)); Changed = $true }
    }
    if (-not $running -or -not $running.Auto -or -not $running.StartHead) { return $same }
    if ($Branch -cne $Trunk -or -not $Clean -or -not $Head -or $Head -ceq $running.StartHead) { return $same }
    if ($null -ne $Commits) {
        $s = $running.Start.ToUniversalTime()
        $from = $s.AddTicks(-($s.Ticks % [TimeSpan]::TicksPerSecond))
        $own = @($Commits | Where-Object { $_ -and $_.Time -and $_.Time.ToUniversalTime() -ge $from })
        if ([string]$running.Label -match '^release') { $own = @($own | Where-Object { [string]$_.Subject -match '^release: v\d+\.\d+\.\d+ release notes' }) }
        if (-not $own.Count) { return $same }
    }
    $copy = $running.Clone(); $copy.End = $Now.ToUniversalTime()
    return @{ Runs = @($runs | ForEach-Object { if ($_.Id -eq $copy.Id) { $copy } else { $_ } }); Changed = $true }
}

function Get-StopwatchSlugs {
    <#
        The URL slug of each label in -Labels, as a hashtable from the label lower-cased (labels group
        case-insensitively) to its slug (#3323). A slug is the label's lower-case letters and digits with every other
        run turned into one dash, cut at 40 characters, and 'run' for a label with none. Two labels that give the
        same slug are never merged: each of them takes a suffix, the first hex digits of the SHA-1 of its
        lower-cased label, as many as it takes for every slug to differ. So a slug depends only on the label and on
        whether another label shares its base, never on the order the runs came in.
    #>
    param([AllowEmptyCollection()][string[]]$Labels = @())
    $keys = @($Labels | Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() } | Sort-Object -Unique)
    $base = @{}
    foreach ($k in $keys) {
        $b = ($k -replace '[^a-z0-9]+', '-').Trim('-')
        if ($b.Length -gt 40) { $b = $b.Substring(0, 40).Trim('-') }
        if (-not $b) { $b = 'run' }
        $base[$k] = $b
    }
    $count = @{}
    foreach ($b in $base.Values) { $count[$b] = 1 + [int]$count[$b] }
    $sha = [Security.Cryptography.SHA1]::Create()
    $hex = @{}
    foreach ($k in $keys) { $hex[$k] = (($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($k)) | ForEach-Object { $_.ToString('x2') }) -join '') }
    $slugs = @{}
    for ($len = 6; $len -le 40; $len += 2) {
        foreach ($k in $keys) { $slugs[$k] = $(if ($count[$base[$k]] -gt 1) { $base[$k] + '-' + $hex[$k].Substring(0, $len) } else { $base[$k] }) }
        if (@($slugs.Values | Sort-Object -Unique).Count -eq $keys.Count) { break }
    }
    return $slugs
}

function ConvertTo-StopwatchModel {
    <#
        What the pages show: the running run, if any, and every run as a Group of its own (newest first), because each
        run gets a card and a page of its own, also when two runs share a label (the owner, October 23, 2026). A group
        carries its run's Label, its LabelSlug (Get-StopwatchSlugs), its Slug and PageSlug (the run's start as
        yyyy-MM-dd-HHmm, with the run's id after it when another run started in the same minute), its Rows (the run,
        when finished, with Seconds and its DeltaSeconds against the run of the same label before it, compared
        case-insensitively, $null for the first; no rows while it is going), Latest (its start) and Running (the run
        going now when this is it, else $null), and its Version of Versions: the run's place among the shown runs of
        its label, oldest first, and how many there are. A run without an end that is not the one going (a run a later prompt
        discarded) is not shown, unless -KeepOpenRuns: the Logbook's runs are one per session and several can be
        open at once (two sessions side by side, a branch parked for the owner's eye), so each is shown as going.
    #>
    param([AllowEmptyCollection()][object[]]$Runs = @(), [switch]$KeepOpenRuns)
    $all = @($Runs | Where-Object { $_ } | Sort-Object { $_.Start })
    $running = @($all | Where-Object { -not $_.End }) | Select-Object -Last 1
    $isGoing = { param($r) (-not $r.End) -and ($KeepOpenRuns -or ($running -and $r.Id -eq $running.Id)) }
    $labelSlugs = Get-StopwatchSlugs -Labels @($all | ForEach-Object { $_.Label })
    # Each finished run against the run of its label before it.
    $rowOf = @{}
    foreach ($g in @($all | Group-Object { $_.Label.ToLowerInvariant() })) {
        $prev = $null
        foreach ($r in @($g.Group | Where-Object { $_.End } | Sort-Object { $_.Start })) {
            $sec = ($r.End - $r.Start).TotalSeconds
            $rowOf[$r.Id] = @{ Run = $r; Seconds = $sec; DeltaSeconds = $(if ($null -ne $prev) { $sec - $prev } else { $null }) }
            $prev = $sec
        }
    }
    $shown = @($all | Where-Object { $_.End -or (& $isGoing $_) })
    # Each shown run's place among the shown runs of its label, so a card can say which run of it this is.
    $versionOf = @{}; $versionsOf = @{}
    foreach ($g in @($shown | Group-Object { $_.Label.ToLowerInvariant() })) {
        $n = 0; foreach ($r in @($g.Group)) { $n++; $versionOf[$r.Id] = $n; $versionsOf[$r.Id] = $g.Count }
    }
    $stampOf = @{}; $stamps = @{}
    foreach ($r in $shown) {
        $stampOf[$r.Id] = $r.Start.ToLocalTime().ToString('yyyy-MM-dd-HHmm', [Globalization.CultureInfo]::InvariantCulture)
        $stamps[$stampOf[$r.Id]] = 1 + [int]$stamps[$stampOf[$r.Id]]
    }
    $groups = @()
    foreach ($r in $shown) {
        $slug = $stampOf[$r.Id]
        if ($stamps[$slug] -gt 1) { $slug += '-' + ($r.Id.ToLowerInvariant() -replace '[^a-z0-9]+', '') }
        # Assigned apart: a $( ) around a one-row array would unroll it to the row itself.
        $rows = @(); if ($rowOf.ContainsKey($r.Id)) { $rows = @($rowOf[$r.Id]) }
        $groups += @{ Label = $r.Label; LabelSlug = $labelSlugs[$r.Label.ToLowerInvariant()]; Slug = $slug; PageSlug = $slug
            Rows = $rows; Latest = $r.Start; Version = $versionOf[$r.Id]; Versions = $versionsOf[$r.Id]
            Running = $(if (& $isGoing $r) { $r } else { $null }) }
    }
    return @{
        Running = $running
        Groups  = @($groups | Sort-Object { $_.Latest } -Descending)
        Count   = @($all | Where-Object { $_.End }).Count
    }
}

function Find-StopwatchGroup {
    <#
        The group of -Model whose PageSlug is -Slug, or $null: the run page's lookup. A label's slug is not a run's:
        it addresses the label's own page (Find-StopwatchLabel), so the server asks this first and that second, and
        a slug neither knows is a 404.
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Model, [AllowEmptyString()][string]$Slug = '')
    return (@($Model.Groups | Where-Object { $_.PageSlug -ceq $Slug }) | Select-Object -First 1)
}

function Get-StopwatchLabelSets {
    <#
        The groups of -Model per prompt label, compared case-insensitively (the owner, October 24, 2026): each a
        Title (the label of its newest run), a Slug (its LabelSlug) and its Groups, newest first; the labels in the
        order of their newest run.
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Model)
    $sets = @()
    foreach ($set in @($Model.Groups | Group-Object { $_.Label.ToLowerInvariant() } | Sort-Object { ($_.Group | ForEach-Object { $_.Latest } | Measure-Object -Maximum).Maximum } -Descending)) {
        $newest = @($set.Group | Sort-Object { $_.Latest } -Descending)
        $sets += @{ Title = $newest[0].Label; Slug = $newest[0].LabelSlug; Groups = $newest }
    }
    return $sets
}

function Get-StopwatchOverviewSets {
    <#
        The label sets the overview shows: Get-StopwatchLabelSets, then one set with no Groups for every pinned label
        ($script:StopwatchPinnedLabels) that has no run yet, so its card and its page exist before its first run (the
        owner, October 25, 2026: a new card comes with its own page). Its slug is computed beside every run label's, so
        a run label sharing its base gives both a suffix rather than one address to two labels.
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Model)
    $sets = @(Get-StopwatchLabelSets -Model $Model)
    $missing = @()
    foreach ($p in $script:StopwatchPinnedLabels) {
        if (-not @($sets | Where-Object { $_.Title -ieq $p.Label }).Count) { $missing += $p }
    }
    if ($missing.Count) {
        $slugs = Get-StopwatchSlugs -Labels (@($Model.Groups | ForEach-Object { $_.Label }) + @($missing | ForEach-Object { $_.Label }))
        foreach ($p in $missing) { $sets += @{ Title = $p.Label; Slug = $slugs[$p.Label.ToLowerInvariant()]; Groups = @() } }
    }
    return $sets
}

function Find-StopwatchLabel {
    <# The label set of -Model (Get-StopwatchOverviewSets, pinned labels included) whose Slug is -Slug, or $null: the label page's lookup. #>
    param([Parameter(Mandatory = $true)][hashtable]$Model, [AllowEmptyString()][string]$Slug = '')
    if (-not $Slug) { return $null }
    return (@(Get-StopwatchOverviewSets -Model $Model | Where-Object { $_.Slug -ceq $Slug }) | Select-Object -First 1)
}

# THE TRANSCRIPT PHASES (#3315's second PR). A finished run's window is read back out of this machine's
# Claude Code session transcripts for this repo, and every second of it is given to exactly one phase: the
# first in this list that was going at that moment. So a ship that runs in the background while Claude
# writes is counted as the ship, and what is left when no session is busy is the time the work waited on a
# person. A Match is held to the COMMAND of a Bash or PowerShell call only, never to a whole serialised
# input: a subagent's brief or an edited file that names ship-pr.ps1 is not a ship (Victor, #3315).
$script:StopwatchToolPhases = @(
    @{ Name = 'Ship: CI wait, merge, fold'; Match = 'ship-pr\.ps1' },
    @{ Name = 'Local gates and tests'; Match = 'open-pr\.ps1|check-plugin-integrity\.ps1|\.tests\.ps1|test-suite-gate|check-[a-z-]+\.ps1' },
    @{ Name = 'Subagents'; Tool = '^(Agent|Task)$' },
    @{ Name = 'Branch and claim'; Match = 'new-branch\.ps1|claim-issue\.ps1|sync-main\.ps1|prune-merged\.ps1' },
    @{ Name = 'Other tool calls'; Tool = '.' }
)
$script:StopwatchShellTools = '^(Bash|PowerShell)$'
# What the harness answers when a call goes on in the background: a shell command sent there or moved there
# at its timeout, or an agent launched async. Held to those tools only, because a Read of a doc or an
# Artifact's answer can say "in the background" too, and such a call would then run to the end of the run.
$script:StopwatchBackgroundTools = '^(Bash|PowerShell|Agent|Task)$'
$script:StopwatchBackgroundText = '^\s*(Command running in background|Async agent launched)|was moved to the background'
$script:StopwatchBusyPhase = 'Claude thinking and writing'
# A SHIP CALL SPLIT BY ITS OWN STEPS (#3338). A ship-pr call is one tool call, and its command line cannot say
# which of its local gates, its CI wait, a forwarded head's re-certification or its merge and fold a moment
# belongs to. ship-pr marks each step it enters in the opt-in step log (Add-RunStepMark in run-progress-lib.ps1,
# on when DKJ_RUN_STEP_LOG is set, as this repo's .claude/settings.json does), and a ship call with marks inside
# it is cut at them (Split-StopwatchShipTool): each step lasts until the next mark or the call's end, and the
# moments before the first mark are its checks before the PR. A ship call with no marks -- a run from before
# the log, or from a machine without it -- stays the one phase above.
$script:StopwatchShipStepPhases = [ordered]@{
    'before'  = 'Ship: checks before the PR'
    'gates'   = 'Ship: local gates and opening the PR'
    'ci-wait' = 'Ship: CI wait'
    'forward' = 'Ship: forwarded head, re-certified'
    'merge'   = 'Ship: merge'
    'fold'    = 'Ship: fold and close-out'
}
$script:StopwatchIdlePhase = 'Waiting on you'

function Get-StopwatchTranscriptDir {
    <# Where Claude Code keeps this checkout's session transcripts: ~/.claude/projects/<root, every non-alphanumeric a dash>. #>
    param([Parameter(Mandatory = $true)][string]$RepoRoot)
    return (Join-Path $HOME ('.claude\projects\' + ($RepoRoot.TrimEnd('\', '/') -replace '[^A-Za-z0-9]', '-')))
}

function Get-StopwatchToolPhase {
    <# The phase one tool call belongs to: the first entry of $script:StopwatchToolPhases its name, or (a shell call) its command, matches. #>
    param([string]$Name, [AllowEmptyString()][string]$Command = '')
    $shell = $Name -match $script:StopwatchShellTools
    foreach ($p in $script:StopwatchToolPhases) {
        if ($p.Tool -and $Name -match $p.Tool) { return $p.Name }
        if ($p.Match -and $shell -and $Command -match $p.Match) { return $p.Name }
    }
    return $script:StopwatchToolPhases[-1].Name
}

function Split-StopwatchShipTool {
    <#
        One tool call (@{ Phase; Start; End }, as Read-StopwatchTranscriptEvents returns it) as its segments: a
        ship call with step marks (-Marks, @{ At; Step }) strictly inside it is cut at each mark, the part before
        the first as 'before', and every segment named from $script:StopwatchShipStepPhases (a step it does not
        know keeps the ship's own phase). Any other call, or a ship with no mark inside, comes back whole. Pure.
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Tool, [AllowEmptyCollection()][object[]]$Marks = @())
    $ship = $script:StopwatchToolPhases[0].Name
    if ($Tool.Phase -ne $ship) { return , @($Tool) }
    $inside = @($Marks | Where-Object { $_ -and $_.At -gt $Tool.Start -and $_.At -lt $Tool.End } | Sort-Object { $_.At })
    if (-not $inside.Count) { return , @($Tool) }
    $name = { param($step) if ($script:StopwatchShipStepPhases.Contains($step)) { $script:StopwatchShipStepPhases[$step] } else { $ship } }
    $segs = @(@{ Phase = (& $name 'before'); Start = $Tool.Start; End = $inside[0].At })
    for ($i = 0; $i -lt $inside.Count; $i++) {
        $end = if ($i + 1 -lt $inside.Count) { $inside[$i + 1].At } else { $Tool.End }
        $segs += @{ Phase = (& $name $inside[$i].Step); Start = $inside[$i].At; End = $end }
    }
    return , $segs
}

function Read-StopwatchTranscriptEvents {
    <#
        What one transcript (-Path, a .jsonl) holds between -From and -To that the phases are made of: every
        turn's start (a typed prompt or a task notification), every tool call with its result and, for one that
        ran in the background, the notification that it finished, and the last moment each turn wrote anything.
        Returns @{ Turns = @(@{ Start; End }); Tools = @(@{ Phase; Start; End }) }, the times UTC.

        CHEAP ON PURPOSE: a transcript runs to tens of megabytes. A line's timestamp is read with a regex and
        compared as a string (ISO 8601 sorts as text), and only a user or assistant line inside the window is
        parsed as JSON. A line that is not JSON is skipped: a transcript being written is cut mid-line at its end.
        A tool or turn started up to an hour before -From is still read, so a ship started before Start is
        counted; a turn that started earlier still and is going at -From counts only from its next turn on.
    #>
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][datetime]$From, [Parameter(Mandatory = $true)][datetime]$To)
    $loText = Format-StopwatchStamp $From.AddHours(-1); $hiText = Format-StopwatchStamp $To
    $turns = New-Object System.Collections.ArrayList
    $calls = @{}; $results = @{}; $done = @{}
    $turn = $null
    foreach ($line in [IO.File]::ReadLines($Path)) {
        $m = [regex]::Match($line, '"timestamp":"([^"]+)"')
        if (-not $m.Success) { continue }
        $ts = $m.Groups[1].Value
        if ($ts -lt $loText -or $ts -gt $hiText) { continue }
        # A finished background call is announced twice: queued, then as the prompt of the turn it wakes. Only
        # those two records count, never a tool result that merely quotes one.
        if ($line.Contains('<task-notification>') -and ($line.StartsWith('{"type":"queue-operation"') -or $line.Contains('"content":"<task-notification>'))) {
            $n = [regex]::Match($line, '<tool-use-id>([^<]+)</tool-use-id>')
            if ($n.Success -and -not $done.ContainsKey($n.Groups[1].Value)) { $done[$n.Groups[1].Value] = $ts }
        }
        # A conversation record opens with its parentUuid; queue operations, snapshots and request blobs do not.
        if (-not $line.StartsWith('{"parentUuid"') -or $line.Contains('"isSidechain":true')) { continue }
        $isUser = $line.Contains('"type":"user"') -and -not $line.Contains('"isMeta":true')
        $isTool = $line.Contains('"type":"tool_use"')
        if ($isUser -or $isTool) {
            try { $rec = $line | ConvertFrom-Json } catch { $rec = $null }
            if ($rec -and $rec.message) {
                $content = $rec.message.content
                if ($rec.type -eq 'user') {
                    $isResult = $content -is [array] -and @($content | Where-Object { $_.type -eq 'tool_result' }).Count
                    if ($isResult) {
                        foreach ($c in @($content | Where-Object { $_.type -eq 'tool_result' })) {
                            $text = if ($c.content -is [string]) { $c.content } else { (@($c.content) | ForEach-Object { [string]$_.text }) -join "`n" }
                            $results[[string]$c.tool_use_id] = @{ At = $ts; Background = ($text -match $script:StopwatchBackgroundText) }
                        }
                    } else {
                        $turn = @{ Start = $ts; End = $ts }; [void]$turns.Add($turn)
                    }
                } elseif ($rec.type -eq 'assistant' -and $content -is [array]) {
                    foreach ($c in @($content | Where-Object { $_.type -eq 'tool_use' })) {
                        $name = [string]$c.name
                        $cmd = if ($name -match $script:StopwatchShellTools -and $c.input) { [string]$c.input.command } else { '' }
                        $calls[[string]$c.id] = @{ Start = $ts; Tool = $name; Phase = (Get-StopwatchToolPhase -Name $name -Command $cmd) }
                    }
                }
            }
        }
        if ($turn -and $ts -gt $turn.End) { $turn.End = $ts }
    }
    $tools = foreach ($id in $calls.Keys) {
        $c = $calls[$id]; $r = $results[$id]
        $background = $r -and $r.Background -and $c.Tool -match $script:StopwatchBackgroundTools
        # Still going at -To (no result yet, or a background run with no notification): it ran to the end.
        $end = if ($done.ContainsKey($id)) { $done[$id] } elseif ($r -and -not $background) { $r.At } else { $hiText }
        @{ Phase = $c.Phase; Start = (ConvertTo-StopwatchTime $c.Start); End = (ConvertTo-StopwatchTime $end) }
    }
    return @{
        Turns = @(foreach ($t in $turns) { @{ Start = (ConvertTo-StopwatchTime $t.Start); End = (ConvertTo-StopwatchTime $t.End) } })
        Tools = @($tools | Where-Object { $_ })
    }
}

function Get-StopwatchTranscriptPhases {
    <#
        A run's window from -From to -To split into phases, from the events of one or more transcripts
        (-Events, each what Read-StopwatchTranscriptEvents returns). A ship call is first cut at the step marks
        in -ShipMarks (Split-StopwatchShipTool). Every second goes to the first phase going at that moment, in
        the order of $script:StopwatchToolPhases (a ship's steps beside the ship), then Claude's own turns, then
        waiting. Returns the phases with any time, in that order, as @{ Name; Seconds }, and Sessions: how many
        transcripts had a turn in the window. Pure.
    #>
    param([AllowEmptyCollection()][object[]]$Events = @(), [Parameter(Mandatory = $true)][datetime]$From, [Parameter(Mandatory = $true)][datetime]$To,
        [AllowEmptyCollection()][object[]]$ShipMarks = @())
    $ship = $script:StopwatchToolPhases[0].Name
    $order = @(foreach ($p in $script:StopwatchToolPhases) { $p.Name; if ($p.Name -eq $ship) { @($script:StopwatchShipStepPhases.Values) } }) + @($script:StopwatchBusyPhase)
    $marks = New-Object System.Collections.ArrayList
    $add = { param($phase, $a, $b)
        if ($a -lt $From) { $a = $From }; if ($b -gt $To) { $b = $To }
        if ($b -gt $a) { [void]$marks.Add(@{ At = $a; Rank = $order.IndexOf($phase); Step = 1 }); [void]$marks.Add(@{ At = $b; Rank = $order.IndexOf($phase); Step = -1 }) } }
    $sessions = 0
    foreach ($ev in @($Events | Where-Object { $_ })) {
        $busy = $false
        foreach ($t in @($ev.Turns)) { if ($t.End -ge $From -and $t.Start -le $To) { $busy = $true }; & $add $script:StopwatchBusyPhase $t.Start $t.End }
        if ($busy) { $sessions++ }
        foreach ($t in @($ev.Tools | Where-Object { $_ })) { foreach ($seg in (Split-StopwatchShipTool -Tool $t -Marks $ShipMarks)) { & $add $seg.Phase $seg.Start $seg.End } }
    }
    $seconds = @{}; $open = New-Object int[] ($order.Count)
    $at = $From
    foreach ($mk in @($marks | Sort-Object { $_.At }, { $_.Step })) {
        $span = ($mk.At - $at).TotalSeconds
        if ($span -gt 0) {
            $rank = -1; for ($i = 0; $i -lt $order.Count; $i++) { if ($open[$i] -gt 0) { $rank = $i; break } }
            $name = if ($rank -ge 0) { $order[$rank] } else { $script:StopwatchIdlePhase }
            $seconds[$name] = [double]$seconds[$name] + $span
        }
        $open[$mk.Rank] += $mk.Step; $at = $mk.At
    }
    $tail = ($To - $at).TotalSeconds
    if ($tail -gt 0) { $seconds[$script:StopwatchIdlePhase] = [double]$seconds[$script:StopwatchIdlePhase] + $tail }
    return @{
        Phases   = @(foreach ($n in @($order) + @($script:StopwatchIdlePhase)) { if ($seconds[$n] -gt 0) { @{ Name = $n; Seconds = $seconds[$n] } } })
        Sessions = $sessions
    }
}

function Get-StopwatchTranscriptFirstStamp {
    <#
        The first timestamp in one transcript (-Path, a .jsonl) as ISO text, or $null when it holds none. Reads only up
        to that line, through a reader closed by hand: leaving a foreach over ReadLines early does not dispose it, and
        the file stays locked.
    #>
    param([Parameter(Mandatory = $true)][string]$Path)
    $reader = $null
    try {
        $reader = New-Object System.IO.StreamReader((New-Object System.IO.FileStream($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)))
        while ($null -ne ($line = $reader.ReadLine())) {
            $m = [regex]::Match($line, '"timestamp":"([^"]+)"')
            if ($m.Success) { return $m.Groups[1].Value }
        }
    } catch { } finally { if ($reader) { $reader.Dispose() } }
    return $null
}

function Get-StopwatchTranscriptCache {
    <#
        The transcript phases of every finished run in -Runs, by run id, read from the cache at -CachePath and
        computed for the runs it lacks from the transcripts in -TranscriptDir. A run's window is closed once it
        stops, so its phases never change and are read from the transcripts once; the cache is rewritten only
        when one was added. Like the store it lives outside the checkout. A cache that does not read is
        recomputed rather than trusted, and a write that fails costs only that read again on the next load.

        ONE PASS PER TRANSCRIPT, however many runs it lacks: each file is read once over the span from the
        earliest missing start to the latest missing end, and every run takes its own window out of those
        events (Sebastian and Victor, #3315).

        ONLY A RUN SOME TRANSCRIPT COVERS is read, cached or returned (#3350): one whose first event is no later
        than a minute after the run's start (the prompt hook stamps the start, possibly before the prompt's own
        record lands) and that was last written at or after it. A run whose transcripts were pruned, or a server
        started with the wrong -TranscriptDir, would otherwise be computed from nothing and filed for good as
        all waiting; uncovered, it is left out, so the page says no phases were read, and it costs no read. A
        cached entry with no session is judged again on the same terms: dropped when nothing covers its run, so
        one filed that way before goes, and kept as it stands when something does.

        A SHIP'S STEPS come from the step log at -StepLogPath (#3338; Read-RunStepMarks): the ship-pr marks
        whose checkout is -RepoRoot's, so a ship in another checkout on this machine never cuts this one's.
        Without -StepLogPath, or where run-progress-lib.ps1 is not beside this file, a ship stays one phase.
    #>
    param([AllowEmptyCollection()][object[]]$Runs = @(), [Parameter(Mandatory = $true)][string]$CachePath, [Parameter(Mandatory = $true)][string]$TranscriptDir,
        [string]$StepLogPath = '', [string]$RepoRoot = '')
    $cache = @{}
    if (Test-Path -LiteralPath $CachePath -PathType Leaf) {
        try {
            $json = [System.IO.File]::ReadAllText($CachePath, (New-Object System.Text.UTF8Encoding($false))) | ConvertFrom-Json
            foreach ($p in @($json.PSObject.Properties)) {
                $cache[$p.Name] = @{ End = [string]$p.Value.end; Sessions = [int]$p.Value.sessions
                    Phases = @(foreach ($x in @($p.Value.phases)) { if ($x) { @{ Name = [string]$x.name; Seconds = [double]$x.seconds } } }) }
            }
        } catch { $cache = @{} }
    }
    $out = @{}; $missing = @()
    foreach ($r in @($Runs | Where-Object { $_ -and $_.End })) {
        if ($cache.ContainsKey($r.Id) -and $cache[$r.Id].End -eq (Format-StopwatchStamp $r.End) -and $cache[$r.Id].Sessions) { $out[$r.Id] = $cache[$r.Id] } else { $missing += $r }
    }
    if (-not $missing.Count) { return $out }
    # A transcript last written before the earliest missing start holds nothing of any of them.
    $earliest = ($missing | ForEach-Object { $_.Start } | Measure-Object -Minimum).Minimum
    $all = if (Test-Path -LiteralPath $TranscriptDir -PathType Container) { @(Get-ChildItem -LiteralPath $TranscriptDir -Filter *.jsonl -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTimeUtc -ge $earliest }) } else { @() }
    $firsts = @{}; foreach ($f in $all) { $firsts[$f.FullName] = Get-StopwatchTranscriptFirstStamp -Path $f.FullName }
    $uncovered = @($missing | Where-Object { $r = $_; $by = Format-StopwatchStamp $r.Start.AddMinutes(1)
            -not @($all | Where-Object { $firsts[$_.FullName] -and $firsts[$_.FullName] -le $by -and $_.LastWriteTimeUtc -ge $r.Start }).Count })
    $dropped = $false; foreach ($r in $uncovered) { if ($cache.ContainsKey($r.Id)) { $cache.Remove($r.Id); $dropped = $true } }
    # A covered run whose cached entry had no session is taken as it stands: no session of this repo was active.
    $missing = @($missing | Where-Object { $uncovered -notcontains $_ } | Where-Object {
            if ($cache.ContainsKey($_.Id) -and $cache[$_.Id].End -eq (Format-StopwatchStamp $_.End)) { $out[$_.Id] = $cache[$_.Id]; $false } else { $true } })
    if ($missing.Count) {
        $from = ($missing | ForEach-Object { $_.Start } | Measure-Object -Minimum).Minimum
        $to = ($missing | ForEach-Object { $_.End } | Measure-Object -Maximum).Maximum
        $events = @(foreach ($f in @($all | Where-Object { $_.LastWriteTimeUtc -ge $from })) { Read-StopwatchTranscriptEvents -Path $f.FullName -From $from -To $to })
        $marks = @()
        if ($StepLogPath -and $script:StopwatchStepLogAvailable) {
            # From the earliest ship call's start, which the events read up to an hour before $from: a mark before it cuts nothing.
            $markFrom = (@($events | ForEach-Object { $_.Tools } | Where-Object { $_ -and $_.Start } | ForEach-Object { $_.Start }) + @($from) | Measure-Object -Minimum).Minimum
            $marks = @(Read-RunStepMarks -Path $StepLogPath -From $markFrom -To $to | Where-Object {
                    $_.Run -eq 'ship-pr' -and (-not $RepoRoot -or (Test-RunProgressInWorkspace -RecordWorkspace $_.Workspace -SessionWorkspace $RepoRoot)) })
        }
        foreach ($r in $missing) {
            $p = Get-StopwatchTranscriptPhases -Events $events -From $r.Start -To $r.End -ShipMarks $marks
            $out[$r.Id] = @{ End = (Format-StopwatchStamp $r.End); Sessions = $p.Sessions; Phases = $p.Phases }
        }
    }
    # A covered run means a transcript was read; a dropped entry means the file holds one it must lose.
    if ($missing.Count -or $dropped) {
        $doc = [ordered]@{}
        # The file is written whole, so every entry it was loaded with is carried over, not only the runs asked for
        # now: the run pages ask for one run at a time, and one run's visit must not wipe another's.
        # Two writers at once (the hub and the background sync) can still drop each other's new entries; such an
        # entry is only read from the transcripts again on the next load, so the cost is a read, never a wrong phase.
        $keep = @{}
        foreach ($id in $cache.Keys) { $keep[$id] = $cache[$id] }
        foreach ($id in $out.Keys) { $keep[$id] = $out[$id] }
        foreach ($id in @($keep.Keys | Sort-Object)) {
            $doc[$id] = [ordered]@{ end = $keep[$id].End; sessions = $keep[$id].Sessions; phases = @(foreach ($x in @($keep[$id].Phases)) { [ordered]@{ name = $x.Name; seconds = [Math]::Round($x.Seconds, 3) } }) }
        }
        try {
            $dir = Split-Path -Parent $CachePath
            if (-not (Test-Path -LiteralPath $dir -PathType Container)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
            # A temporary file of this call's own: the hub and the background sync (#3349) can both write the cache.
            $tmp = $CachePath + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
            [System.IO.File]::WriteAllText($tmp, ($doc | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($false)))
            Move-Item -LiteralPath $tmp -Destination $CachePath -Force
        } catch { }
    }
    return $out
}

function Format-StopwatchPhaseCard {
    <#
        One run's transcript phases as a card of their own: a heading with the run's start and time (-Title, already
        formatted by the caller) and, when more than one session took part, how many; then a table with a row per
        phase, longest first, each with its time, its share of the run and a bar of that share. A run with no
        phases says why instead.
    #>
    param($Entry, [double]$Total, [Parameter(Mandatory = $true)][string]$Title)
    $sub = if ($Entry -and $Entry.Sessions -gt 1) { '<p class="card__sub">' + $Entry.Sessions + ' sessions</p>' } else { '' }
    $card = '<section class="card"><div class="card__head"><h3 class="card__title">' + (ConvertTo-DashboardText $Title) + '</h3>' + $sub + '</div>'
    if ($null -eq $Entry) { return $card + '<p class="note">No phases read for this run yet.</p></section>' }
    if (-not $Entry.Sessions) { return $card + '<p class="note">No session of this repo was active during this run.</p></section>' }
    if (-not @($Entry.Phases | Where-Object { $_ }).Count) { return $card + '<p class="note">No phases read for this run yet.</p></section>' }
    $card += '<div class="table-wrap"><table class="table"><thead><tr><th class="sw-left">Phase</th><th>Time</th><th>Share</th><th class="sw-left">Of the run</th></tr></thead><tbody>'
    foreach ($p in @($Entry.Phases | Sort-Object -Property @{ Expression = { [double]$_.Seconds }; Descending = $true })) {
        # Capped at 100 so the bar never overflows its track; a phase is at most the run, so the cap only meets rounding.
        $share = if ($Total -gt 0) { [Math]::Min(100, [Math]::Round(100 * $p.Seconds / $Total)) } else { 0 }
        $card += '<tr><td class="sw-left">' + (ConvertTo-DashboardText $p.Name) + '</td><td class="num">' + (Format-DevSeconds $p.Seconds) + '</td><td class="num">' + $share + '%</td>' +
            '<td class="sw-left"><span class="sw-bar" role="img" aria-label="' + $share + '%"><span style="width: ' + $share + '%"></span></span></td></tr>'
    }
    return $card + '</tbody></table></div></section>'
}

function Format-StopwatchDelta {
    <# Faster or slower than the run before, as a badge; nothing for a label's first run. #>
    param($Seconds)
    if ($null -eq $Seconds) { return '<span class="note">first run</span>' }
    if ([Math]::Abs([double]$Seconds) -lt 0.5) { return '<span class="badge badge--sm badge--neutral">same</span>' }
    if ($Seconds -lt 0) { return '<span class="badge badge--sm badge--good">' + (Format-DevSeconds (-[double]$Seconds)) + ' faster</span>' }
    return '<span class="badge badge--sm badge--bad">' + (Format-DevSeconds ([double]$Seconds)) + ' slower</span>'
}

function Format-StopwatchChangePercent {
    <#
        A run's change against the run of its label before it, in percent of that run's time, beside the time on a
        card: only a sign and the number (the owner, October 24, 2026). The sign is the result's, not the time's: + for a
        faster run in the positive colour, - for a slower one in the negative colour. Under half a second is 0%, and a
        label's first run has nothing to compare with.
    #>
    param([double]$Seconds, $DeltaSeconds)
    if ($null -eq $DeltaSeconds) { return '' }
    $before = $Seconds - [double]$DeltaSeconds
    if ([Math]::Abs([double]$DeltaSeconds) -lt 0.5 -or $before -le 0) { return ' <span class="sw-change">0%</span>' }
    $pct = [Math]::Round([Math]::Abs([double]$DeltaSeconds) / $before * 100)
    $pctText = if ($pct -lt 1) { '&lt;1%' } else { [string]$pct + '%' }
    if ($DeltaSeconds -lt 0) { return ' <span class="sw-change sw-change--good">+' + $pctText + '</span>' }
    return ' <span class="sw-change sw-change--bad">-' + $pctText + '</span>'
}

function Format-StopwatchPageShell {
    <# The pieces the two pages share: the page's own style layer and the live-clock script. Names are the page's (sw-), house tokens only. #>
    $style = '.sw-clock { font-size: var(--text-h1); font-weight: 600; margin: var(--spacing-2) 0; }' + "`n" +
        # Five cards to a row, then two and one on a narrow screen (the owner, October 24, 2026).
        # A grid of the page's own rather than a .grid-3, so a group takes no top margin; the space between groups is
        # .sw-groups' gap instead.
        '.sw-groups { display: grid; gap: var(--spacing-7); }' + "`n" +
        '.sw-grid { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: var(--spacing-4); }' + "`n" +
        '.sw-grid > .card { margin-top: 0; }' + "`n" +
        # The overview's label cards are larger: three to a row at most (the owner, October 24, 2026). Before the
        # media rules, so a narrow screen still takes two and then one.
        '.sw-grid--wide { grid-template-columns: repeat(3, minmax(0, 1fr)); }' + "`n" +
        '@media (max-width: 1000px) { .sw-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); } }' + "`n" +
        '@media (max-width: 760px) { .sw-grid { grid-template-columns: 1fr; } }' + "`n" +
        '.sw-card > h2 a { color: inherit; text-decoration: none; }' + "`n" +
        # A card's lines are built from the house text sizes (--text-lg, -base, -sm, -xs), the text colour or --muted, and the
        # weights 300 to 800, and nothing else: no heading (the owner, October 24, 2026). The start is the card's
        # header (base, 800), the prompt label the least visible line under it (sm, regular, muted, its version likewise),
        # and the time under it (base, 300) with its change beside it (xs, regular).
        '.sw-card > p { margin: 0; }' + "`n" +
        '.sw-card > p + p { margin-top: var(--spacing-1); }' + "`n" +
        '.sw-stamp { font-size: var(--text-base); font-weight: 800; color: var(--fg-1); }' + "`n" +
        '.sw-instruction { font-size: var(--text-sm); font-weight: 400; color: var(--muted); overflow-wrap: anywhere; }' + "`n" +
        '.sw-instruction a { color: inherit; text-decoration: none; }' + "`n" +
        '.sw-instruction .muted { font-size: var(--text-sm); font-weight: 400; }' + "`n" +
        '.sw-time { font-size: var(--text-base); font-weight: 300; color: var(--fg-1); }' + "`n" +
        # A pinned label's steps (Format-StopwatchPinnedSteps): the instruction line's size and colour, numbered.
        '.sw-steps { margin: var(--spacing-2) 0 0; padding-left: var(--spacing-5); font-size: var(--text-sm); font-weight: 400; color: var(--muted); }' + "`n" +
        '.sw-steps > li + li { margin-top: var(--spacing-1); }' + "`n" +
        # A pinned label's prompt to copy (Format-StopwatchPinnedPrompt): the house has no code block, so this layer draws
        # one from house tokens, in a monospace face so the prompt reads as the text to paste.
        '.sw-prompt { margin: 0; padding: var(--spacing-3); background: var(--paper-2); color: var(--fg-1); border-radius: var(--spacing-2); font-family: ui-monospace, Consolas, monospace; font-size: var(--text-sm); white-space: pre-wrap; overflow-wrap: anywhere; }' + "`n" +
        '.sw-card > .sw-copy { margin-top: var(--spacing-3); }' + "`n" +
        '.sw-change { margin-left: var(--spacing-2); font-size: var(--text-xs); font-weight: 400; color: var(--muted); }' + "`n" +
        '.sw-change--good { color: var(--positive-5); }' + "`n" +
        '.sw-change--bad { color: var(--negative-5); }' + "`n" +
        '.sw-left { text-align: left; }' + "`n" +
        '.sw-bar { display: block; min-width: var(--spacing-24); height: var(--spacing-2); background: var(--paper-3); border-radius: var(--spacing-1); overflow: hidden; }' + "`n" +
        '.sw-bar > span { display: block; height: 100%; background: var(--primary); }'
    # The one script: every running clock, drawn from its stored start.
    $script = @'
<script>(function () {
  // Format-DevSeconds' own form: one decimal under a minute, then m:ss, then h:mm:ss.
  function fmt(s) { s = Math.max(0, s); if (s < 59.95) return s.toFixed(1) + "s"; s = Math.round(s);
    var h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), x = s % 60;
    function p(n) { return (n < 10 ? "0" : "") + n; } return h ? h + ":" + p(m) + ":" + p(x) : m + ":" + p(x); }
  var clocks = document.querySelectorAll("[data-start]");
  Array.prototype.forEach.call(clocks, function (c) { var t0 = Date.parse(c.getAttribute("data-start"));
    setInterval(function () { c.textContent = fmt((Date.now() - t0) / 1000); }, 250); });
})();</script>
'@
    return @{ Style = $style; Script = $script }
}

function Format-StopwatchCardTime {
    <# A card's time line: the live clock of a run going, else its time with its change in percent beside it (-NoDelta: none). #>
    param([Parameter(Mandatory = $true)][hashtable]$Group, [datetime]$Now = [datetime]::UtcNow, [switch]$NoDelta)
    if ($Group.Running) {
        return '<p class="sw-time num" data-start="' + (Format-StopwatchStamp $Group.Running.Start) + '">' + (Format-DevSeconds ($Now - $Group.Running.Start).TotalSeconds) + '</p>'
    }
    if (-not @($Group.Rows).Count) { return '' }
    $row = $Group.Rows[0]
    $change = if ($NoDelta) { '' } else { Format-StopwatchChangePercent -Seconds $row.Seconds -DeltaSeconds $row.DeltaSeconds }
    return '<p class="sw-time num">' + (Format-DevSeconds $row.Seconds) + $change + '</p>'
}

function Format-StopwatchRunCard {
    <#
        One run's card, in three lines with no header above them (the owner, October 24, 2026): the run's start, its
        prompt label (with its version behind it once the label has run more than once), and its time
        (Format-StopwatchCardTime). The label is the card's one link, to the run's page under -Route, stretched over
        the card. -CardNotes (text by run id) adds a fourth line to a finished run's card.
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Group, [string]$Route = '/stopwatch', [datetime]$Now = [datetime]::UtcNow, [switch]$NoDelta, [hashtable]$CardNotes = @{})
    $e = { param($v) ConvertTo-DashboardText $v }
    $stamp = & $e ($Group.Latest.ToLocalTime().ToString('yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture))
    $href = (& $e $Route) + '/' + (& $e $Group.PageSlug)
    $card = '<section class="card card--link sw-card"><p class="sw-stamp">' + $stamp + '</p>' +
        '<p class="sw-instruction"><a href="' + $href + '">' + (& $e $Group.Label) + '</a>' +
        $(if ($Group.Versions -gt 1) { ' <span class="muted">v' + $Group.Version + '</span>' } else { '' }) + '</p>' +
        (Format-StopwatchCardTime -Group $Group -Now $Now -NoDelta:$NoDelta)
    if (-not $Group.Running -and @($Group.Rows).Count -and $CardNotes[$Group.Rows[0].Run.Id]) { $card += '<p class="muted">' + (& $e ([string]$CardNotes[$Group.Rows[0].Run.Id])) + '</p>' }
    return $card + '</section>'
}

function Format-StopwatchLabelCard {
    <#
        One prompt label's card on the overview (the owner, October 24, 2026): an h2 with the label's short title
        (Get-StopwatchShortTitle), the card's one link, to the label's page; a line saying when a run of it starts and
        when it stops; and its fastest finished time, with no change beside it, or the live clock while its only run
        is still going. The run dates are on the label's page, not here.
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Set, [datetime]$Now = [datetime]::UtcNow)
    $e = { param($v) ConvertTo-DashboardText $v }
    $stop = if ([string]$Set.Title -match '^release') { 'the release notes of the cut are committed' } else { 'Claude is back on main, clean, with a commit of its own' }
    $fastest = @($Set.Groups | ForEach-Object { $_.Rows } | Where-Object { $_ } | Sort-Object { $_.Seconds }) | Select-Object -First 1
    # A pinned label with no run yet (Get-StopwatchOverviewSets) has no time to show, and says so.
    $time = if ($fastest) { '<p class="sw-time num">' + (Format-DevSeconds $fastest.Seconds) + '</p>' }
            elseif (-not @($Set.Groups).Count) { '<p class="sw-time">No run yet</p>' }
            else { Format-StopwatchCardTime -Group $Set.Groups[0] -Now $Now }
    return '<section class="card card--link sw-card"><h2><a href="/stopwatch/' + (& $e $Set.Slug) + '">' + (& $e (Get-StopwatchShortTitle $Set.Title)) + '</a></h2>' +
        '<p class="sw-instruction">From the prompt <code>stopwatch: ' + (& $e $Set.Title) + '</code> until ' + $stop + '.</p>' +
        $time + '</section>'
}

# A LABEL THE OVERVIEW SHOWS BEFORE ITS FIRST RUN (the owner, October 25, 2026), with the steps that time it the same
# way every time, so its runs can be compared with each other. It is an ordinary label card from the start, linking its
# own page (Get-StopwatchOverviewSets), and the STEPS STAND ON THAT PAGE, never on the card: a card is the way in, the
# page holds what it is about (the owner, October 25, 2026). Matched case-insensitively, like every label. The steps
# are plain text, escaped where they are drawn.
$script:StopwatchPinnedLabels = @(
    @{
        Label = 'Ship PR'
        # The prompt the label's page offers to copy (the owner, October 25, 2026): the marker line, then one line that
        # asks for the ship alone. It names no branch, so it pastes unchanged: step 1 leaves the checkout on the branch.
        Prompt = @('stopwatch: Ship PR', 'Ship the branch that is checked out now with ship-pr.ps1. Change nothing else.')
        Steps = @(
            'Get a branch ready first, outside the clock: its change committed, its DEPLOY section written, and the checkout left on it.',
            'Start the run by pasting the prompt above into a session of this checkout. Its first line is exactly "stopwatch: Ship PR", and its second only asks to ship that branch, so the run times the ship and nothing else.',
            'The run ends when Claude is back on main after the merge and the fold. Each run''s own page splits the ship into its steps: the checks before the PR, the local gates and opening the PR, the CI wait, the merge, and the fold.',
            'Repeat with the next ready branch under the same first line. Every run lands on this page and is compared with the run before it.',
            'To try a speed-up, change one thing between two runs, say which on the prompt''s second line, and compare the steps of the two runs.'
        )
    }
)

function Get-StopwatchPinnedLabel {
    <# The pinned label (above) whose Label is -Label, compared case-insensitively, or $null. #>
    param([AllowEmptyString()][string]$Label = '')
    return (@($script:StopwatchPinnedLabels | Where-Object { $_.Label -ieq $Label }) | Select-Object -First 1)
}

function Format-StopwatchPinnedSteps {
    <# The numbered steps of a pinned label, or '' for a label that is not pinned. #>
    param([AllowEmptyString()][string]$Label = '')
    $pinned = Get-StopwatchPinnedLabel -Label $Label
    if (-not $pinned) { return '' }
    $items = @($pinned.Steps | ForEach-Object { '<li>' + (ConvertTo-DashboardText $_) + '</li>' })
    return '<ol class="sw-steps">' + ($items -join '') + '</ol>'
}

function Format-StopwatchPinnedPrompt {
    <#
        A pinned label's prompt to copy, or '' for a label without one: the prompt in a block, and a copy button whose
        script puts the block's text on the clipboard. The button writes nothing anywhere else, so the page stays
        read-only.
    #>
    param([AllowEmptyString()][string]$Label = '')
    $pinned = Get-StopwatchPinnedLabel -Label $Label
    if (-not $pinned -or -not $pinned.Contains('Prompt')) { return '' }
    $text = ConvertTo-DashboardText (@($pinned.Prompt) -join "`n")
    return '<pre class="sw-prompt" id="sw-prompt">' + $text + '</pre>' +
        '<p class="sw-copy"><button type="button" class="btn" data-copy="sw-prompt">Copy the prompt</button></p>' +
        '<script>(function () {' +
        ' var b = document.querySelector("[data-copy]"); if (!b || !navigator.clipboard) { return; }' +
        ' b.addEventListener("click", function () {' +
        '  navigator.clipboard.writeText(document.getElementById(b.getAttribute("data-copy")).textContent).then(function () {' +
        '   b.textContent = "Copied"; setTimeout(function () { b.textContent = "Copy the prompt"; }, 2000); }); }); })();</script>'
}

function Get-StopwatchShortTitle {
    <# A label's short title for its card: the label up to its first comma or opening parenthesis, else the whole label. #>
    param([AllowEmptyString()][string]$Label = '')
    $short = ($Label -split '[,(]', 2)[0].Trim()
    if ($short) { return $short }
    return $Label
}

function Format-StopwatchPageHtml {
    <#
        The overview on '/stopwatch', read-only, and bare (no lead or tiles; the general banner stays, #3356): it opens on the
        banner, then a Stopwatch h1 with one card per prompt label, three to a row (Format-StopwatchLabelCard), linking the label's own
        page (Format-StopwatchLabelPageHtml), which holds that label's run cards (the owner, October 24, 2026). -Flat,
        the Logbook's, shows the run cards themselves (Format-StopwatchRunCard) under one Measurements h2 instead. Five
        cards to a row on a full screen. -ReadError is set when the
        store could not be read. -StorePath is named in the footer, so a run can be read and evaluated outside
        the page. The Logbook (scripts/lib/logbook-lib.ps1, #3364) draws its overview here too: -Route, -PageTitle
        and -FooterNote are its own, -NoDelta leaves out the change against the run before, which only means
        something between runs that share a label on purpose, and -CardNotes (text by run id) adds a part to a finished
        run's card line: its work time. -Fetching says the other machines' runs are still being fetched, in place of
        "no other machine has shared a run yet", and reloads the page until they are in (#3377). It is set on EVERY
        visit a fetch runs on, not only the first, and once other machines are shown it says it is checking for newer
        runs instead (#3403). -LastFetched, when given, is when the last fetch ended, and the footer names it beside the
        other machines' runs: a run another machine published since then is not on the page yet, and nothing else
        said so -- measured, a group showed one card short with no sign that the copy was stale.
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Model,
        [AllowEmptyString()][string]$ReadError = '',
        [int]$Skipped = 0,
        [AllowEmptyString()][string]$StorePath = '',
        [int]$SharedMachines = 0,
        [switch]$Fetching,
        [Nullable[datetime]]$LastFetched = $null,
        [datetime]$Now = [datetime]::UtcNow,
        [string]$Route = '/stopwatch',
        [string]$PageTitle = 'Stopwatch',
        [AllowEmptyString()][string]$FooterNote = '',
        [switch]$NoDelta,
        [hashtable]$CardNotes = @{},
        [switch]$Flat
    )
    $e = { param($v) ConvertTo-DashboardText $v }
    $body = New-Object System.Text.StringBuilder
    if ($ReadError) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">The store could not be read: ' + (& $e $ReadError) + '. Nothing is written over it until it reads again, so no new run is recorded.</p>')
    }
    if ($Skipped) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">' + $Skipped + ' run(s) in the store could not be read and are not shown. The next write by a hook drops them; the file as it was is kept beside the store as a .bak.</p>')
    }

    if ($Fetching) {
        # A sync is fetching the other machines' runs (#3377): say so, and reload until it has ended. On a later visit
        # the page already shows what the last fetch brought, and this one may bring newer runs (#3403).
        $what = if ($SharedMachines -gt 0) { 'Checking origin for newer runs from the other machines. This page reloads in a few seconds to show any.' }
                else { 'The other machines'' runs are being fetched from origin. This page reloads in a few seconds to show them.' }
        [void]$body.AppendLine('<p class="msg" role="status">' + $what + '</p>')
        [void]$body.AppendLine('<script>setTimeout(function () { location.reload(); }, 4000);</script>')
    }
    # One card per prompt label under the page's h1, each linking the label's page (the owner, October 24, 2026). -Flat
    # keeps every run card under one Measurements heading, for the Logbook, whose labels are the first lines of prompts and
    # rarely repeat.
    # The overview's labels, the pinned ones with no run yet included (not in -Flat, the Logbook's).
    $sets = if ($Flat) { @() } else { @(Get-StopwatchOverviewSets -Model $Model) }
    if (-not @($Model.Groups).Count -and -not $sets.Count) {
        [void]$body.AppendLine('<div class="grid__head"><h1>Measurements</h1></div>')
    } else {
        # The grid stands in a wrapper whose gap is the space between grids, so no grid carries a top margin (the owner,
        # October 24, 2026). A head is its h2 alone, with no sub line under it.
        [void]$body.AppendLine('<div class="sw-groups">')
        [void]$body.AppendLine($(if ($Flat) { '<div class="sw-grid">' } else { '<div class="sw-grid sw-grid--wide">' }))
        if ($Flat) {
            [void]$body.AppendLine('<div class="grid__head"><h1>Measurements</h1></div>')
            foreach ($g in @($Model.Groups)) { [void]$body.AppendLine((Format-StopwatchRunCard -Group $g -Route $Route -Now $Now -NoDelta:$NoDelta -CardNotes $CardNotes)) }
        } else {
            # The overview's one heading is an h1 naming the page (the owner, October 24, 2026).
            [void]$body.AppendLine('<div class="grid__head"><h1>Stopwatch</h1></div>')
            foreach ($set in $sets) { [void]$body.AppendLine((Format-StopwatchLabelCard -Set $set -Now $Now)) }
        }
        [void]$body.AppendLine('</div>')
        [void]$body.AppendLine('</div>')
    }
    if (-not @($Model.Groups).Count) {
        [void]$body.AppendLine('<p class="note">No run yet.' + $(if ($NoDelta) { '' } else { ' The first one sets the baseline for its label.' }) + '</p>')
    }

    $shell = Format-StopwatchPageShell
    # When the copy of the other machines' runs was last fetched (#3403), in local time like every time on these pages.
    $fetchedAt = if ($null -ne $LastFetched) { ', as last fetched ' + (& $e (([datetime]$LastFetched).ToLocalTime().ToString('yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture))) } else { '' }
    $note = if ($FooterNote) { $FooterNote } else { 'Kept on this machine in <code>' + (& $e $StorePath) + '</code>, outside the checkout, so a run never dirties the tree it is timing. ' +
        'Every finished run is also shared through a ref of this machine''s own on origin, <code>refs/stopwatch/&lt;machine&gt;</code> (<code>scripts/lib/stopwatch-sync-lib.ps1</code>), ' +
        $(if ($SharedMachines -eq 1) { "and the runs of one other machine are shown with these$fetchedAt. " } elseif ($SharedMachines -gt 1) { 'and the runs of ' + $SharedMachines + " other machines are shown with these$fetchedAt. " } elseif ($Fetching) { 'and the other machines'' runs are still being fetched. ' } else { "and no other machine has shared a run yet$fetchedAt. " }) +
        'A prompt whose first line begins with <code>stopwatch:</code> starts a run in a session of this checkout, labelled with the rest of that line, and discards a run still going; ' +
        'a Stop hook ends it once Claude is back on the trunk, clean, with HEAD moved since the start (that suggests the work landed; it does not prove it). Both are <code>scripts/dashboard/stopwatch-hook.ps1</code>. ' +
        'Built by <code>scripts/lib/stopwatch-lib.ps1</code>.' }
    # Bare, with no lead (the owner, October 24, 2026): the overview's h1 names it, the Logbook's breadcrumb does, and the footer says
    # how a run starts.
    return Format-DevPageHtml -Title $PageTitle -Style $shell.Style -Body ($body.ToString() + $shell.Script) -Lead '' -Bare `
        -FooterNote $note
}

function Format-StopwatchLabelPageHtml {
    <#
        One prompt label's page on '/stopwatch/<label slug>' (the owner, October 24, 2026), bare like the overview:
        an h2 with the label, and under it one card per run of that label, newest first (Format-StopwatchRunCard),
        each linking the run's own page. -Set is one of Get-StopwatchLabelSets. The crumbs lead back to '/stopwatch'.
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Set,
        [AllowEmptyString()][string]$StorePath = '',
        [datetime]$Now = [datetime]::UtcNow
    )
    $e = { param($v) ConvertTo-DashboardText $v }
    $body = New-Object System.Text.StringBuilder
    [void]$body.AppendLine('<div class="sw-groups">')
    [void]$body.AppendLine('<div class="sw-grid">')
    [void]$body.AppendLine('<div class="grid__head"><h1>' + (& $e $Set.Title) + '</h1></div>')
    foreach ($g in @($Set.Groups)) { [void]$body.AppendLine((Format-StopwatchRunCard -Group $g -Now $Now)) }
    # A pinned label before its first run (Get-StopwatchOverviewSets): one card saying so, where the runs will stand.
    if (-not @($Set.Groups).Count) { [void]$body.AppendLine('<section class="card sw-card"><p class="sw-instruction">No run yet. The first one sets the baseline for this label.</p></section>') }
    [void]$body.AppendLine('</div>')
    # A pinned label's prompt to copy and its steps stand here, on its page, each under an h2 of its own above the one
    # card that holds it: the prompt first, since it is what a run starts from.
    $prompt = Format-StopwatchPinnedPrompt -Label $Set.Title
    if ($prompt) {
        [void]$body.AppendLine('<div class="sw-howto">')
        [void]$body.AppendLine('<div class="grid__head"><h2>The prompt</h2></div>')
        [void]$body.AppendLine('<section class="card sw-card">' + $prompt + '</section>')
        [void]$body.AppendLine('</div>')
    }
    $steps = Format-StopwatchPinnedSteps -Label $Set.Title
    if ($steps) {
        [void]$body.AppendLine('<div class="sw-howto">')
        [void]$body.AppendLine('<div class="grid__head"><h2>How to time it</h2></div>')
        [void]$body.AppendLine('<section class="card sw-card">' + $steps + '</section>')
        [void]$body.AppendLine('</div>')
    }
    [void]$body.AppendLine('</div>')
    $shell = Format-StopwatchPageShell
    $note = 'Every run whose prompt began with <code>stopwatch: ' + (& $e $Set.Title) + '</code>, labels compared case-insensitively, each against the run of this label before it. ' +
        'Kept on this machine in <code>' + (& $e $StorePath) + '</code> and shared with the other machines through <code>refs/stopwatch/&lt;machine&gt;</code> on origin. Built by <code>scripts/lib/stopwatch-lib.ps1</code>.'
    return Format-DevPageHtml -Title ([string]$Set.Title) -Style $shell.Style -Body ($body.ToString() + $shell.Script) -Lead '' -Bare -ParentCrumbs @(@{ Label = 'Stopwatch'; Href = '/stopwatch' }) `
        -FooterNote $note
}

function Format-StopwatchRunPageHtml {
    <#
        One run's page on '/stopwatch/<slug>' (#3323), titled with the run's start and its label beneath. A run going
        now shows its live clock; a finished one its time on a card of its own, with its change against the previous
        run of the same label, and under Phases its transcript phases, a row and a bar each (-Transcript, by run id,
        from Get-StopwatchTranscriptCache; a run it lacks says so). -Group is one group of ConvertTo-StopwatchModel.
        The crumbs lead back to '/stopwatch', or to -Route under -ParentLabel for the Logbook (#3364), whose
        -FooterNote is its own, whose -NoDelta leaves out the change against the run before, and whose -TimeNote stands
        under the run's time: its work time. -LabelCrumb puts the run's label page (Format-StopwatchLabelPageHtml)
        between the parent and the run, as the Stopwatch's run pages have it.
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Group,
        [AllowEmptyString()][string]$StorePath = '',
        [hashtable]$Transcript = @{},
        [datetime]$Now = [datetime]::UtcNow,
        [string]$Route = '/stopwatch',
        [string]$ParentLabel = 'Stopwatch',
        [AllowEmptyString()][string]$FooterNote = '',
        [switch]$NoDelta,
        [AllowEmptyString()][string]$TimeNote = '',
        [switch]$LabelCrumb
    )
    $crumbs = @(@{ Label = $ParentLabel; Href = $Route })
    if ($LabelCrumb -and $Group.LabelSlug) { $crumbs += @{ Label = [string]$Group.Label; Href = $Route + '/' + $Group.LabelSlug } }
    $e = { param($v) ConvertTo-DashboardText $v }
    $local = { param($t) (& $e ($t.ToLocalTime().ToString('yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture))) }
    $body = New-Object System.Text.StringBuilder
    $pageTitle = $Group.Latest.ToLocalTime().ToString('yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture)
    [void]$body.AppendLine('<div class="grid__head"><h1>' + (& $e $pageTitle) + '</h1><p class="card__sub">' + (& $e $Group.Label) + '</p></div>')
    if ($Group.Running) {
        [void]$body.AppendLine('<section class="card"><h3>Going now</h3>')
        [void]$body.AppendLine('<p class="sw-clock num" data-start="' + (Format-StopwatchStamp $Group.Running.Start) + '">' + (Format-DevSeconds ($Now - $Group.Running.Start).TotalSeconds) + '</p>')
        [void]$body.AppendLine('<p class="note">Started ' + (& $local $Group.Running.Start) + '.</p></section>')
    }
    if (@($Group.Rows).Count) {
        $row = $Group.Rows[0]
        [void]$body.AppendLine('<section class="card"><div class="card__head"><h3 class="card__title">Time</h3><p class="card__sub">Started ' + (& $local $row.Run.Start) + $(if ($row.Run.Machine) { ' on another machine' } else { '' }) + '.</p></div>')
        [void]$body.AppendLine('<p class="sw-clock num">' + (Format-DevSeconds $row.Seconds) + '</p>')
        if ($TimeNote) { [void]$body.AppendLine('<p class="note">' + (& $e $TimeNote) + '</p>') }
        if (-not $NoDelta) { [void]$body.AppendLine('<p>' + (Format-StopwatchDelta $row.DeltaSeconds) + $(if ($null -ne $row.DeltaSeconds) { ' <span class="note">than the previous run of this label</span>' } else { '' }) + '</p>') }
        [void]$body.AppendLine('</section>')
        [void]$body.AppendLine('<div class="grid-2">')
        [void]$body.AppendLine('<div class="grid__head"><h2>Phases</h2><p class="card__sub">This run split into phases from the session transcripts, longest first</p></div>')
        [void]$body.AppendLine((Format-StopwatchPhaseCard $Transcript[$row.Run.Id] $row.Seconds -Title ((& $local $row.Run.Start) + ' - ' + (Format-DevSeconds $row.Seconds))))
        [void]$body.AppendLine('</div>')
    }
    $shell = Format-StopwatchPageShell
    $note = if ($FooterNote) { $FooterNote } else { 'Kept on this machine in <code>' + (& $e $StorePath) + '</code>, outside the checkout, and shared with the other machines through <code>refs/stopwatch/&lt;machine&gt;</code> on origin. ' +
        'The phases are read from this repo''s Claude Code session transcripts once a run has stopped: each second goes to the first phase going at that moment, ' +
        'so a ship running in the background counts as the ship, and a second in which no session was busy is time spent waiting on you. Built by <code>scripts/lib/stopwatch-lib.ps1</code>.' }
    return Format-DevPageHtml -Title ([string]$pageTitle) -Style $shell.Style -Body ($body.ToString() + $shell.Script) -Lead '' -Bare -ParentCrumbs $crumbs `
        -FooterNote $note
}
