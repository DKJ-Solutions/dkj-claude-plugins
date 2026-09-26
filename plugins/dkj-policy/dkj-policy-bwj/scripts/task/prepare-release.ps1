<#
.SYNOPSIS
    Stage a store release DAYS ahead of release day, so the day itself is push -> verify -> cut. It
    reads, it reports, and it prints the release-day runbook. It never pushes, cuts, tags, or writes
    the authorisation marker.

.DESCRIPTION
    INBOUND #2509 (from BWJ-Development/smartwatchbanden, September 26, 2026). The chain had tools for
    the MOMENT of release -- live-preflight, the push, cut-release, theme-lifecycle, golive-block -- and
    nothing for "release is on Monday, get me ready now". Answering that on the Friday meant reading
    five lens sections and running the diff by hand, which is the manual sequence coming round a second
    time.

    EIGHT STEPS, EACH A READ:

      1 trunk        on the trunk, clean, level with origin, no branch document left beside the
                     changelog, and the head's check runs green.
      2 scope        every pending entry, the bump the fold's tally names, the version that makes, and
                     whether a minor owes the hand-written audience note.
      3 scores       pending entries whose score is worth a second look (advisory; see the lib).
      4 push list    the range's theme files, by the SAME rules live-preflight uses -- live-push-rules.ps1,
                     mirrored into this plugin -- sync-owned files held back, new files marked.
      5 early drift  the repo's own drift check over that list, as an array, so a third-party edit is
                     found on Friday and can get a sync/ branch. It runs again, for real, on the day.
      6 obligations  the "once this is live" sentences in the entries' prose, as one checklist.
      7 open work    open pull requests, so what rides along is decided before the weekend.
      8 runbook      the day's sequence with every derived fact filled in; -OutFile also writes it.

    ------------------------------------------------------------------------------------------------
    THE BOUNDARIES live-preflight STATES HOLD HERE UNCHANGED, and for the same reasons.

    1. NOTHING HERE WRITES TO THE STORE. No push, no publish, no duplicate, no delete. The live guard is
       a PreToolUse hook reading a COMMAND STRING and cannot see inside a script, so a store write in
       here would be a write nothing guards. The early drift read calls the repo's own drift check,
       which pulls FROM live into a local folder; it is skipped with -SkipDrift.

    2. NOTHING HERE WRITES THE AUTHORISATION MARKER, OR READS IT. The runbook's push command is composed
       by Format-LivePushCommand, which cannot produce one, and the text names the marker's job and never
       the marker.

    3. NOTHING HERE WRITES TO GIT. No commit, no branch, no tag. The one file it can write is -OutFile,
       where the caller names it.
    ------------------------------------------------------------------------------------------------

    A REPORT, SO ITS EXIT CODE IS A SUMMARY RATHER THAN A GATE: 0 where nothing needs attention, 1 where
    something does. A step that could not measure is a 'skip' and is named, never counted as a pass.

    Pure ASCII (repo convention for .ps1).

.PARAMETER Store
    Store domain, overriding Get-ShopifyThemeEstateStore -- the seam live-preflight reads.

.PARAMETER SinceTag
    Derive the push list from this tag instead of the highest vX.Y.Z one.

.PARAMETER DriftCheckPath
    The repo's drift check, relative to the root. Default Get-ShopifyDriftCheckPath, then
    'scripts/theme/live-snapshot.ps1' -- the same default live-preflight uses.

.PARAMETER SkipDrift
    Do not run the early drift read. For a run with no Shopify CLI at hand, or a second run the same day.

.PARAMETER ReleaseDay
    The weekday releases are cut on. Monday, BWJ's cadence -- the same default golive-block uses.

.PARAMETER ObligationPattern
    Regular expressions that mark a go-live obligation in an entry's prose, REPLACING the English
    defaults. For a store whose entries are written in another language.

.PARAMETER OutFile
    Also write the runbook to this path (UTF-8, no BOM). Name a gitignored file, or the branch document.

.PARAMETER RootOverride
    The repo root, when this is not run from inside the checkout -- and the fixture root for a suite.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/prepare-release.ps1"

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/prepare-release.ps1" -SkipDrift -OutFile .release-runbook.md
#>
[CmdletBinding()]
param(
    [string]$Store = '',
    [string]$SinceTag = '',
    [string]$DriftCheckPath = '',
    [switch]$SkipDrift,
    [System.DayOfWeek]$ReleaseDay = [System.DayOfWeek]::Monday,
    [string[]]$ObligationPattern = @(),
    [string]$OutFile = '',
    [string]$RootOverride = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Captured before the repo's own config is dot-sourced below: repo-config.ps1 is the consumer's, and it
# may bind any name it likes -- the guard build-golive-block.ps1 keeps for the same reason.
$StoreArg = $Store; $SinceTagArg = $SinceTag; $DriftArg = $DriftCheckPath; $SkipDriftArg = [bool]$SkipDrift
$ReleaseDayArg = $ReleaseDay; $PatternArg = @($ObligationPattern); $OutFileArg = $OutFile; $RootArg = $RootOverride

. (Join-Path $PSScriptRoot '..\lib\repo-root-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\live-push-rules.ps1')
. (Join-Path $PSScriptRoot '..\lib\git-porcelain-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\ref-print-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\golive-block-rules.ps1')
. (Join-Path $PSScriptRoot '..\lib\prepare-release-rules.ps1')

$repoRoot = Resolve-BwjRepoRoot -Override $RootArg
# gh resolves its repo from the CURRENT directory, so a run started elsewhere -- or through -RootOverride
# -- would otherwise read another repo's pull requests. Measured on the first fixture run.
Set-Location -LiteralPath $repoRoot

# A repo that publishes plugins is this script's SOURCE, not a store -- the one-file test live-preflight
# and push-preview make for the same distinction.
if (-not $RootArg -and (Test-Path -LiteralPath (Join-Path $repoRoot '.claude-plugin\marketplace.json') -PathType Leaf)) {
    Write-Host 'REFUSED: this repo publishes plugins, so it is this script''s source rather than a store.' -ForegroundColor Red
    Write-Host 'There is no theme and no release day here to prepare. Nothing was read or written.'
    exit 1
}

# THE SEAMS, AT SCRIPT SCOPE -- the #2339 lesson build-golive-block.ps1 records: a config dot-sourced
# inside a scriptblock loses every function it defined when that scope ends. StrictMode is off for the
# read only, because repo-config.ps1 is written on the assumption that it is.
$configPath = Join-Path $repoRoot 'scripts\repo-config.ps1'
if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    Set-StrictMode -Off
    $resolvedRoot = $repoRoot
    try { . $configPath } catch { Write-Warning "scripts/repo-config.ps1 could not be read: $($_.Exception.Message)" }
    Set-StrictMode -Version Latest
    $repoRoot = $resolvedRoot
}

function Get-Seam {
    <# The answer of an optional seam function, or $Default where the repo has not defined it. The same
       inline probe build-golive-block.ps1 writes: Get-Command on a MISS pays a full PATH scan. #>
    param([Parameter(Mandatory = $true)][string]$Name, $Default = '')
    if (@($ExecutionContext.InvokeCommand.GetCommands($Name, 'Function', $false)).Count -eq 0) { return $Default }
    try { return (& $Name) } catch { Write-Warning "$Name threw: $($_.Exception.Message)"; return $Default }
}

function Invoke-Native {
    <# A native command whose stderr and exit code are read rather than thrown on -- the try/finally
       shape repo-root-lib.ps1 documents, which the repo-wide redirect guard exonerates.
       AND A CATCH, because a MISSING executable is not an exit code: it throws CommandNotFoundException,
       which would take the run down at the first gh call instead of reporting that step as skipped --
       measured by this branch's copy edit. It comes back as a failed call (-1) with no output. #>
    param([Parameter(Mandatory = $true)][scriptblock]$Command)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = @()
    try {
        $out  = & $Command 2>$null
        $code = $LASTEXITCODE
    } catch {
        $code = -1
    } finally {
        $ErrorActionPreference = $prev
    }
    return [pscustomobject]@{ Lines = @(@($out) | ForEach-Object { "$_".Trim() } | Where-Object { $_ }); Code = $code }
}

function Invoke-Git {
    <# git with core.quotePath forced on, so a path above 0x7F crosses the pipe as ASCII and is decoded
       here (Convert-GitQuotedPath) rather than by the console code page -- the class
       .claude/rules/language-layers.md measured in sync-main. #>
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $a = @('-C', $repoRoot, '-c', 'core.quotePath=true') + $Arguments
    return Invoke-Native { & git @a }
}

$store = ([string]$StoreArg).Trim()
if (-not $store) { $store = ([string](Get-Seam 'Get-ShopifyThemeEstateStore')).Trim() }
if ($store -match 'VUL-IN') { $store = '' }
$liveId = ([string](Get-Seam 'Get-ShopifyLiveThemeId')).Trim()
if ($liveId -notmatch '^\d+$') { $liveId = '' }
$trunk = ([string](Get-Seam 'Get-TrunkBranchName' 'main')).Trim(); if (-not $trunk) { $trunk = 'main' }
$syncPrefix = ([string](Get-Seam 'Get-ShopifySyncBranchPrefix' 'sync/')).Trim(); if (-not $syncPrefix) { $syncPrefix = 'sync/' }
$changelogRel = ([string](Get-Seam 'Get-ChangelogPath' 'CHANGELOG.md')).Trim(); if (-not $changelogRel) { $changelogRel = 'CHANGELOG.md' }
$audience = Get-Seam 'Get-ReleaseAudienceTier' $null

# COUNTED FROM YESTERDAY, so a run ON the release day names today. Get-NextReleaseDate is strictly-after
# on purpose -- work closing on a Monday ships the NEXT Monday -- but a release being prepared that
# morning is this one, and naming next week would put the wrong date on the runbook.
$releaseDate = Format-GoLiveDate -Date (Get-NextReleaseDate -From (Get-Date).AddDays(-1) -ReleaseDay $ReleaseDayArg)

Write-Host "== prepare-release -- $(if ($store) { $store } else { '(no store domain)' }) -- release day $releaseDate ==" -ForegroundColor Cyan
Write-Host '   it reads and reports. It never pushes, cuts, tags, or writes the authorisation marker.'
Write-Host ''

$steps = @()
function Add-Step {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][ValidateSet('ready', 'attention', 'skip')][string]$State,
        [Parameter(Mandatory = $true)][string]$Detail
    )
    $script:steps += [pscustomobject]@{ Name = $Name; State = $State; Detail = $Detail }
    $colour = switch ($State) { 'ready' { 'Green' } 'attention' { 'Red' } default { 'Yellow' } }
    $label  = switch ($State) { 'ready' { 'READY    ' } 'attention' { 'ATTENTION' } default { 'SKIPPED  ' } }
    Write-Host "  $label $Detail" -ForegroundColor $colour
}

# === 1/8 -- the trunk ==============================================================================
Write-Host '[1/8] trunk -- clean, level with origin, nothing unfolded, checks green' -ForegroundColor Cyan

$branch = @((Invoke-Git @('rev-parse', '--abbrev-ref', 'HEAD')).Lines) | Select-Object -First 1
$problems = @()
if ("$branch" -ne $trunk) { $problems += "on '$branch', not on the trunk '$trunk'" }
$dirty = @((Invoke-Git @('status', '--porcelain')).Lines)
if ($dirty.Count -gt 0) { $problems += "$($dirty.Count) uncommitted change(s)" }
$fetch = Invoke-Git @('fetch', 'origin', $trunk)
$counts = Invoke-Git @('rev-list', '--left-right', '--count', "origin/$trunk...$trunk")
$countLine = @($counts.Lines) | Select-Object -First 1
if ($counts.Code -eq 0 -and "$countLine" -match '^(\d+)\s+(\d+)$') {
    $behind = [int]$Matches[1]; $ahead = [int]$Matches[2]
    if ($behind -ne 0 -or $ahead -ne 0) { $problems += "'$trunk' is $behind behind and $ahead ahead of origin/$trunk" }
} else {
    $problems += "could not compare '$trunk' with origin/$trunk"
}
if ($fetch.Code -ne 0) { $problems += "the fetch of origin/$trunk failed, so 'level' is judged against the last fetch" }

# A BRANCH DOCUMENT LEFT BESIDE THE CHANGELOG is a merge whose fold never ran: its entry is not in the
# changelog, so it would be missing from this release's scope and from the cut. Only the changelog's own
# folder is read, and only its direct children -- a release archive beside it is not a branch document.
$changelogFull = Join-Path $repoRoot ($changelogRel -replace '/', '\')
$changelogDir = Split-Path -Parent $changelogFull
if ($changelogDir -and (Test-Path -LiteralPath $changelogDir -PathType Container) -and ($changelogDir -ne $repoRoot)) {
    $strays = @(Get-ChildItem -LiteralPath $changelogDir -Filter '*.md' -File |
        Where-Object { $_.FullName -ne $changelogFull -and $_.Name -notmatch '^(?i)(README|SYNC-LOG)\.md$' })
    if ($strays.Count -gt 0) { $problems += "unfolded branch document(s) beside the changelog: $(@($strays | ForEach-Object { $_.Name }) -join ', ')" }
}

# THE HEAD'S CHECK RUNS. The required check is a branch-protection fact this script cannot read without
# admin rights, so it reads every check run on the head and asks for all of them to have succeeded.
$repoName = ([string](Get-Seam 'Get-RepoName')).Trim()
if (-not $repoName) { $repoName = @((Invoke-Native { gh repo view --json nameWithOwner -q .nameWithOwner }).Lines) | Select-Object -First 1 }
$headSha = @((Invoke-Git @('rev-parse', 'HEAD')).Lines) | Select-Object -First 1
$checkNote = ''
if (-not $repoName -or -not $headSha) {
    $checkNote = 'check runs not read (no repo name or no head)'
} else {
    $runs = Invoke-Native { gh api "repos/$repoName/commits/$headSha/check-runs" --jq '.check_runs[] | [.name, .status, (.conclusion // "")] | @tsv' }
    if ($runs.Code -ne 0) {
        $checkNote = 'check runs could not be read (gh missing, logged out, or offline)'
    } elseif ($runs.Lines.Count -eq 0) {
        $problems += 'the head carries no check runs at all -- nothing has proved this trunk'
    } else {
        $bad = @($runs.Lines | Where-Object { $f = $_ -split "`t"; -not ($f.Count -ge 3 -and $f[1] -eq 'completed' -and $f[2] -in @('success', 'skipped', 'neutral')) })
        if ($bad.Count -gt 0) { $problems += "check run(s) not green on the head: $(@($bad | ForEach-Object { ($_ -split "`t")[0] }) -join ', ')" }
    }
}

if ($problems.Count -gt 0) {
    Add-Step -Name 'trunk' -State 'attention' -Detail ($problems -join '; ')
} else {
    Add-Step -Name 'trunk' -State 'ready' -Detail "on '$trunk', clean, level with origin, nothing unfolded$(if ($checkNote) { "; $checkNote" } else { ', every check run green' })."
}

# === 2/8 -- the release scope ======================================================================
Write-Host ''
Write-Host '[2/8] scope -- what is pending, and the version it makes' -ForegroundColor Cyan

$entries = @()
$bump = $null
$sinceTag = ([string]$SinceTagArg).Trim()
if (-not $sinceTag) { $sinceTag = Get-HighestReleaseTag -Tags (Invoke-Git @('tag', '--list')).Lines }
$targetVersion = ''
if (-not (Test-Path -LiteralPath $changelogFull -PathType Leaf)) {
    Add-Step -Name 'scope' -State 'skip' -Detail "no changelog at '$changelogRel', so nothing pending could be read."
} else {
    $changelogText = [System.IO.File]::ReadAllText($changelogFull)
    $entries = @(Get-PendingChangelogEntries -Changelog $changelogText)
    $bump = Get-PendingBumpFromTally -Changelog $changelogText
    foreach ($e in $entries) { Write-Host "    $(ConvertTo-ConsoleStrippedText -Text $e.Branch)" -ForegroundColor DarkGray }
    if ($sinceTag -and $bump) { $targetVersion = Step-SemVer -Current ($sinceTag -replace '^v', '') -Bump $bump }
    if ($entries.Count -eq 0) {
        Add-Step -Name 'scope' -State 'attention' -Detail "nothing is pending in '$changelogRel' -- there is no release to prepare."
    } elseif (-not $bump) {
        Add-Step -Name 'scope' -State 'attention' -Detail "$($entries.Count) pending entr(y/ies), and the pending tally could not be read -- so the bump is unknown. The fold writes that tally; run it."
    } else {
        $owed = if ($bump -eq 'minor') { ' A minor owes the hand-written audience note -- draft it before the day.' } else { '' }
        Add-Step -Name 'scope' -State 'ready' -Detail "$($entries.Count) pending entr(y/ies): a $bump$(if ($targetVersion) { ", $sinceTag -> v$targetVersion" }).$owed"
    }
}

# === 3/8 -- the scores =============================================================================
Write-Host ''
Write-Host '[3/8] scores -- entries worth a second look before the cut' -ForegroundColor Cyan

if ($entries.Count -eq 0) {
    Add-Step -Name 'scores' -State 'skip' -Detail 'no pending entries to read.'
} elseif ("$audience" -ne '1') {
    Add-Step -Name 'scores' -State 'skip' -Detail "the check applies at audience tier 1 and this repo answers '$audience' -- see Get-EntryScoreNotes."
} else {
    $notes = @(Get-EntryScoreNotes -Entries $entries -AudienceTier $audience)
    foreach ($n in $notes) { Write-Host "    $(ConvertTo-ConsoleStrippedText -Text $n.Branch): $(ConvertTo-ConsoleStrippedText -Text $n.Note)" -ForegroundColor Yellow }
    if ($notes.Count -gt 0) { Add-Step -Name 'scores' -State 'attention' -Detail "$($notes.Count) entr(y/ies) to confirm -- advisory; the cut's tier gate decides." }
    else { Add-Step -Name 'scores' -State 'ready' -Detail 'no score looks out of place.' }
}

# === 4/8 -- the push list ==========================================================================
Write-Host ''
Write-Host '[4/8] push list -- derived by the rules live-preflight uses' -ForegroundColor Cyan

$pushFiles = @()
if (-not $sinceTag) {
    Add-Step -Name 'push list' -State 'attention' -Detail 'no vX.Y.Z tag, so there is no previous release to diff against. Pass -SinceTag.'
} else {
    $range = Invoke-Git @('diff', '--name-only', "$sinceTag..HEAD")
    if ($range.Code -ne 0) {
        Add-Step -Name 'push list' -State 'attention' -Detail "could not diff $sinceTag..HEAD -- is the tag fetched? Try 'git fetch --tags'."
    } else {
        $changed = @($range.Lines | ForEach-Object { Convert-GitQuotedPath -Path $_ })
        $added = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($p in (Invoke-Git @('diff', '--name-only', '--diff-filter=A', "$sinceTag..HEAD")).Lines) { [void]$added.Add(((Convert-GitQuotedPath -Path $p) -replace '\\', '/')) }

        # SYNC PROVENANCE, by the two lib rules live-preflight calls -- so a file held back on Friday is
        # the file held back on Monday.
        $syncCommits = @()
        foreach ($h in @(Get-SyncMergeCommits -SyncPrefix $syncPrefix -LogLines (Invoke-Git @('log', '--no-renames', '--format=%H%x09%P%x09%s', "$sinceTag..HEAD")).Lines)) {
            if ($h.IsMerge) { $syncCommits += @((Invoke-Git @('rev-list', "$($h.FirstParent)..$($h.Sha)")).Lines) }
            else            { $syncCommits += $h.Sha }
        }
        $syncOwned = @()
        if ($syncCommits.Count -gt 0) {
            $walk = Invoke-Git @('log', '--no-renames', '--format=COMMIT%x09%H', '--name-only', "$sinceTag..HEAD")
            $syncOwned = @(Get-SyncOwnedPaths -WalkLines @($walk.Lines | ForEach-Object { Convert-GitQuotedPath -Path $_ }) -SyncCommits $syncCommits)
        }

        $rows = @(Get-LivePushRows -ChangedPaths $changed -SyncOwnedPaths $syncOwned)
        $pushFiles = @($rows | Where-Object { $_.Push } | ForEach-Object { $_.Path })
        Write-Host "  $sinceTag..HEAD changed $($changed.Count) file(s)."
        foreach ($r in @($rows | Where-Object { $_.Push })) {
            $new = if ($added.Contains(($r.Path -replace '\\', '/'))) { '  (NEW on the theme)' } else { '' }
            Write-Host "    push  $(ConvertTo-ConsoleStrippedText -Text $r.Path)$new" -ForegroundColor Green
        }
        foreach ($g in @($rows | Where-Object { -not $_.Push } | Group-Object -Property Kind)) {
            Write-Host "    held  $($g.Count) file(s): $($g.Group[0].Reason)" -ForegroundColor DarkGray
        }
        $newCount = @($pushFiles | Where-Object { $added.Contains(($_ -replace '\\', '/')) }).Count
        # A PATH THAT IS NOT PASTE-SAFE STOPS THE RUNBOOK COMPOSING A COMMAND AROUND IT (see
        # Format-ReleaseRunbook), and it is named here so the reason is not only in the runbook.
        $unsafe = @($pushFiles | Where-Object { -not (Test-PathPasteSafe -Path $_) })
        if ($unsafe.Count -gt 0) {
            Add-Step -Name 'push list' -State 'attention' -Detail "$($unsafe.Count) of $($pushFiles.Count) theme path(s) cannot be pasted safely into a command line, so the runbook composes no push or pull. Read them: $(@($unsafe | ForEach-Object { ConvertTo-ConsoleStrippedText -Text $_ }) -join ', ')"
        } elseif ($pushFiles.Count -eq 0) {
            Add-Step -Name 'push list' -State 'ready' -Detail "nothing in $sinceTag..HEAD lives on a theme -- this release is code and docs only, with no live push."
        } else {
            Add-Step -Name 'push list' -State 'ready' -Detail "$($pushFiles.Count) theme file(s) to push, $newCount of them new on the theme, out of $($changed.Count) changed."
        }
    }
}

# === 5/8 -- early drift ============================================================================
Write-Host ''
Write-Host '[5/8] early drift -- third-party edits on live, found before the day' -ForegroundColor Cyan

$driftRel = ([string]$DriftArg).Trim()
if (-not $driftRel) { $driftRel = ([string](Get-Seam 'Get-ShopifyDriftCheckPath')).Trim() }
if (-not $driftRel) { $driftRel = 'scripts/theme/live-snapshot.ps1' }
$driftFull = Join-Path $repoRoot ($driftRel -replace '/', '\')

if ($SkipDriftArg) {
    Add-Step -Name 'drift' -State 'skip' -Detail '-SkipDrift was passed. Drift is still checked for real by live-preflight on the day.'
} elseif ($pushFiles.Count -eq 0) {
    Add-Step -Name 'drift' -State 'skip' -Detail 'there is no push list to check.'
} elseif (-not (Test-Path -LiteralPath $driftFull -PathType Leaf)) {
    Add-Step -Name 'drift' -State 'skip' -Detail "no drift check at '$driftRel'. Pass -DriftCheckPath, or answer Get-ShopifyDriftCheckPath."
} else {
    # IN THIS PROCESS, WITH A REAL ARRAY -- the measured #2228 failure was this list crossing a
    # `powershell -File` boundary as one string, and the check reading zero files as "safe to push".
    Write-Host "  $driftRel -Only <$($pushFiles.Count) paths, as an array>"
    $driftExit = 0
    try {
        $global:LASTEXITCODE = 0
        & $driftFull -Only $pushFiles
        $driftExit = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
    } catch {
        $driftExit = -1
        Write-Warning "the drift check threw: $($_.Exception.Message)"
    }
    if ($driftExit -eq 0) {
        Add-Step -Name 'drift' -State 'ready' -Detail "no drift on the $($pushFiles.Count) file(s) today. It runs again, for real, on the day."
    } else {
        Add-Step -Name 'drift' -State 'attention' -Detail "the drift check exited $driftExit -- something on live differs from this repo. A sync/ branch now is cheaper than a surprise on the day."
    }
}

# === 6/8 -- go-live obligations ====================================================================
Write-Host ''
Write-Host '[6/8] obligations -- what must happen once this is live' -ForegroundColor Cyan

$obligations = @(Get-GoLiveObligations -Entries $entries -Patterns $PatternArg)
foreach ($o in $obligations) { Write-Host "    - $(ConvertTo-ConsoleStrippedText -Text $o.Branch): $(ConvertTo-ConsoleStrippedText -Text $o.Sentence)" }
if ($entries.Count -eq 0) {
    Add-Step -Name 'obligations' -State 'skip' -Detail 'no pending entries to read.'
} else {
    Add-Step -Name 'obligations' -State 'ready' -Detail "$($obligations.Count) candidate(s) in $($entries.Count) entr(y/ies) -- matched by phrase, so read the entries before trusting a short list."
}

# === 7/8 -- open visible work ======================================================================
Write-Host ''
Write-Host '[7/8] open work -- pull requests that could still ride along' -ForegroundColor Cyan

$prArgs = @('pr', 'list', '--state', 'open', '--base', $trunk, '--json', 'number,title,headRefName,isDraft',
            '--jq', '.[] | [.number, .headRefName, .isDraft, .title] | @tsv')
if ($repoName) { $prArgs += @('--repo', $repoName) }
$prs = Invoke-Native { & gh @prArgs }
if ($prs.Code -ne 0) {
    Add-Step -Name 'open work' -State 'skip' -Detail 'open pull requests could not be read (gh missing, logged out, or offline).'
} else {
    foreach ($l in $prs.Lines) {
        $f = $l -split "`t", 4
        if ($f.Count -ge 4) { Write-Host "    #$($f[0])  $(ConvertTo-ConsoleStrippedText -Text $f[1])$(if ($f[2] -eq 'true') { '  (draft)' })  -- $(ConvertTo-ConsoleStrippedText -Text $f[3])" }
    }
    if ($prs.Lines.Count -eq 0) { Add-Step -Name 'open work' -State 'ready' -Detail "no open pull request against '$trunk'." }
    else { Add-Step -Name 'open work' -State 'attention' -Detail "$($prs.Lines.Count) open pull request(s) -- decide now whether each rides along; one merged after this run is not in the list above." }
}

# === 8/8 -- the runbook ============================================================================
Write-Host ''
Write-Host '[8/8] runbook -- the day, in order' -ForegroundColor Cyan
Write-Host ''

$runbook = @(Format-ReleaseRunbook -Store $store -LiveThemeId $liveId -PushFiles $pushFiles -Bump "$bump" `
    -TargetVersion $targetVersion -ReleaseDate $releaseDate -Obligations $obligations)
foreach ($l in $runbook) { Write-Host "  $l" }
if ($OutFileArg) {
    $outFull = if ([System.IO.Path]::IsPathRooted($OutFileArg)) { $OutFileArg } else { Join-Path $repoRoot $OutFileArg }
    [System.IO.File]::WriteAllText($outFull, (($runbook -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding $false))
    Write-Host ''
    Write-Host "  written to $outFull" -ForegroundColor DarkGray
}

# === the summary ===================================================================================
$attention = @($steps | Where-Object { $_.State -eq 'attention' })
$skipped   = @($steps | Where-Object { $_.State -eq 'skip' })
Write-Host ''
Write-Host '== summary ==' -ForegroundColor Cyan
foreach ($s in $attention) { Write-Host "  ATTENTION  $($s.Name): $($s.Detail)" -ForegroundColor Red }
foreach ($s in $skipped)   { Write-Host "  SKIPPED    $($s.Name): $($s.Detail)" -ForegroundColor Yellow }
Write-Host ''
if ($attention.Count -gt 0) {
    Write-Host "$($attention.Count) step(s) need attention before the day. Nothing was pushed, cut or authorised." -ForegroundColor Red
    exit 1
}
Write-Host "Ready for $releaseDate$(if ($skipped.Count -gt 0) { ", with $($skipped.Count) step(s) not measured" }). Nothing was pushed, cut or authorised." -ForegroundColor Green
exit 0
