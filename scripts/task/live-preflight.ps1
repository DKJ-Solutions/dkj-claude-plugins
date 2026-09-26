<#
.SYNOPSIS
    The preflight between a merged trunk and a live theme push: verify the stand, derive the push list,
    hand it to the drift check as an ARRAY, take a verified backup, and print the push command. It
    verifies, it reports, and it never acts on the live theme.

.DESCRIPTION
    THE GAP THIS FILLS (inbound #2228, filed from a BWJ store on September 21, 2026). Everything this
    plugin shipped sat either BEFORE the merge -- push-preview, sync-main -- or AFTER the push --
    backup-live-theme, archive-theme, sweep-preview-themes. Nothing stood at the push itself, which is
    the one moment in the whole cycle where a mistake is visible to paying customers, so that step was
    assembled by hand, per release, from prose. Measured in the consumer preparing v2.44.0: eight manual
    steps, two of them at places where hand assembly is KNOWN to fail.

    ------------------------------------------------------------------------------------------------
    TWO BOUNDARIES, AND NEITHER IS NEGOTIABLE. Both were asked for by name in #2228 and both belong
    here, in the script's own docstring, rather than in a page somebody may not have open.

    1. THIS SCRIPT NEVER RUNS `shopify theme push`. The live guard is a PreToolUse hook that reads the
       COMMAND STRING of a tool call, and it cannot see inside a script -- so a push performed in here
       would disable the last rail standing around live. It prints the command; a person runs it.

    2. THIS SCRIPT NEVER WRITES THE AUTHORISATION MARKER. Green means THE CHECKLIST IS COMPLETE AND THE
       PUSH IS ALLOWED TO BE MADE. It never means the push is authorised. The marker authorises ONE
       command, visibly, in the transcript, and it stays a human act. Format-LivePushCommand in the lib
       beside this file cannot produce one even if a later caller asked it to.
    ------------------------------------------------------------------------------------------------

    THE TWO FAILURES IT MECHANISES, because they are the reason it is a script and not a checklist:

      DERIVING THE PUSH LIST. The consumer's range v2.43.0..HEAD held 61 changed files, of which 11
      lived in the eight theme directories; the other 50 were scripts, tests and docs that do not exist
      on a theme. Their own CLAUDE.md warns about it in words -- "de pushlijst is niet de changelog" --
      which is what a rule looks like when nothing enforces it. Step 3 derives the list instead.

      PASSING THAT LIST ON. Their drift check takes -Only. At v2.39.0 the list reached it through
      `powershell -File`, which delivers every argument as ONE string that never splits on commas: the
      check snapshotted zero files and printed a green "safe to push". The rollback artefact for that
      release did not exist and nothing said so. Step 6 calls the check IN THIS PROCESS with a real
      array, which is a mistake a caller that owns the list cannot make.

    THE ORDER IS COST-ORDERED, AND #2228 ASKED FOR THAT EXPLICITLY. The backup polls until the copy is
    provably complete and that took roughly EIGHT MINUTES in the consumer's store, so it runs after
    every cheap gate has passed. Failing a lint gate must not cost eight minutes first.

    WHAT A 'skip' MEANS, AND WHY IT IS NOT A PASS. A step whose seam the repo has not answered reports
    'skip' and the run stays allowed -- refusing there would break a repo that never adopted the
    optional half on its next plugin update. But it does not vanish either: it is named in the summary,
    because a checklist that reads green while a step sat inert is the exact failure the drift check's
    own green "safe to push" already demonstrated on this procedure.

    NEVER PUBLISHES, AND TOUCHES LIVE ONLY TO READ IT. The one thing it invokes that writes anything is
    backup-live-theme.ps1, whose writes are a duplicate theme and the rotation of the PREVIOUS backup
    out of this repo's own namespace, both guarded there.

.PARAMETER Store
    Store domain, overriding Get-ShopifyThemeEstateStore for this run. The same seam backup-live-theme
    reads, and deliberately NOT Get-ShopifyStoreDomain -- see that script's header for why answering
    the other one would lift an unrelated brake.

.PARAMETER SinceTag
    Derive the push list from this tag instead of the highest vX.Y.Z one in the repo. For a re-cut, or
    for a store whose last release was not the last tag.

.PARAMETER DriftCheckPath
    The consumer's drift check, relative to the repo root. Default 'scripts/theme/live-snapshot.ps1'.
    See the note on Get-ShopifyDriftCheckPath below: this is the one place #2228's "it would introduce
    no new seam" did not hold, and the default is what keeps it optional.

.PARAMETER SkipGates
    Do not re-run the repo's own lint and test gates. For a second run in the same session, where they
    have already passed and nothing has been committed since.

.PARAMETER SkipBackup
    Do not take the live-theme backup. Only correct when a VERIFIED backup of this same live stand
    already exists -- which is a fact about the store, not about this run, so the run says so out loud
    and carries the skip into its summary rather than quietly passing.

.PARAMETER RootOverride
    Fixture root, so a suite can drive this against a scratch tree instead of a real store.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/task/live-preflight.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/task/live-preflight.ps1 -SinceTag v2.43.0 -SkipBackup

.NOTES
    COVERAGE, STATED RATHER THAN LEFT TO INFERENCE. scripts/tests/live-push-rules.tests.ps1 pins the
    rules this script invokes: the eight theme directories, the push-list classification in all three of
    its verdicts, the numeric tag pick that lexical sorting gets wrong, the push command's shape and its
    refusal to produce one for an empty list, and the verdict fold including the state a skip is in.

    THIS SCRIPT ITSELF IS NOT DRIVEN, for the reason push-preview.ps1 and backup-live-theme.ps1 give:
    every path in it reaches git, the Shopify CLI against a real store, or a consumer's repo-config, and
    a suite must not be able to reach a store. What is therefore unpinned is the ORDER of the nine steps
    and the git derivation of sync provenance -- which is exactly why everything that CAN be judged
    without a network was moved into the lib.

    Pure ASCII (repo convention for .ps1).
#>
[CmdletBinding()]
param(
    [string]$Store = '',
    [string]$SinceTag = '',
    [string]$DriftCheckPath = '',
    [switch]$SkipGates,
    [switch]$SkipBackup,
    [string]$RootOverride = ''
)
$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')

# THE PUSH-LIST RULES. Unguarded, like the theme-lifecycle rules in backup-live-theme: a copy of this
# script without the lib must fail at LOAD rather than derive a push list from a theme-directory set it
# could not read. A short push list is invisible until a customer sees the half-updated page.
. (Join-Path $PSScriptRoot '..\lib\live-push-rules.ps1')

# The CLI wrapper, for the two theme-list reads below. Unguarded for the reason above.
. (Join-Path $PSScriptRoot '..\lib\shopify-cli-lib.ps1')

# THE QUOTED-PATH DECODE, for the two git reads whose lines are paths. Unguarded like the rest: a theme
# repo is exactly where a path with a byte above 0x7F turns up, and a payload that could not decode one
# would classify it as a path it had never seen. See Invoke-Git's header for the mechanism.
. (Join-Path $PSScriptRoot '..\lib\git-porcelain-lib.ps1')

# The bounded native capture, for git and for the consumer's own gate commands. Unguarded: every gate
# this script runs is somebody else's process, and running one without a bound is how a preflight sits
# forever on a command that stopped to ask a question nobody can see.
. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')

. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$repoRoot = Resolve-RepoRootOrFail -Override $RootOverride -ScriptName 'live-preflight.ps1' -OverrideName '-RootOverride'

# A repo that publishes plugins is this script's SOURCE, not a Shopify store. Same one-file test
# push-preview, sync-main, backup-live-theme and adopt-shopify-floor use for the same distinction.
if (-not $RootOverride -and (Test-Path -LiteralPath (Join-Path $repoRoot '.claude-plugin\marketplace.json') -PathType Leaf)) {
    Write-Host 'REFUSED: this repo publishes plugins, so it is this script''s source rather than a Shopify consumer.' -ForegroundColor Red
    Write-Host 'There is no live theme here to push to. Nothing was changed.'
    exit 1
}

Set-Location -LiteralPath $repoRoot

# --- The seam answers ------------------------------------------------------------------------------
# Read in a child scope with StrictMode OFF and inside a try, exactly as the live-theme guard and every
# other script in this plugin read the same file: repo-config.ps1 belongs to the consumer, so a fault in
# it must degrade to defaults rather than take this script down.
#
# THE PUSH MARKER IS DELIBERATELY NOT READ. This script has no use for it -- it never writes one -- and
# a run that held the marker in a variable is one edit away from printing it onto the command it also
# prints. Not reading it is the cheapest way to keep boundary 2 above true by construction.
$seam = & {
    Set-StrictMode -Off
    $answers = @{
        LiveThemeId = ''; StoreDomain = ''; TrunkIsLive = $true; Trunk = ''; SyncPrefix = ''
        LintScript = ''; TestCommands = @(); ChangelogPath = ''; DriftCheck = ''; DeleteMarker = ''
    }
    $cfg = Join-Path $args[0] 'scripts\repo-config.ps1'
    if (Test-Path -LiteralPath $cfg -PathType Leaf) {
        try { . $cfg } catch { Write-Warning "scripts/repo-config.ps1 could not be read: $(Format-SafeProseToken -Value $_.Exception.Message)" }
    }
    $branchInfo = Join-Path $args[0] 'scripts\lib\branch-info.ps1'
    if (Test-Path -LiteralPath $branchInfo -PathType Leaf) { try { . $branchInfo } catch { } }

    if (Test-FunctionDefined 'Get-ShopifyLiveThemeId')      { $answers.LiveThemeId   = [string](Get-ShopifyLiveThemeId) }
    if (Test-FunctionDefined 'Get-ShopifyThemeEstateStore') { $answers.StoreDomain   = [string](Get-ShopifyThemeEstateStore) }
    if (Test-FunctionDefined 'Get-ShopifyTrunkIsLive')      { $answers.TrunkIsLive   = [bool](Get-ShopifyTrunkIsLive) }
    if (Test-FunctionDefined 'Get-TrunkBranchName')         { $answers.Trunk         = [string](Get-TrunkBranchName) }
    if (Test-FunctionDefined 'Get-ShopifySyncBranchPrefix') { $answers.SyncPrefix    = [string](Get-ShopifySyncBranchPrefix) }
    if (Test-FunctionDefined 'Get-LintScript')              { $answers.LintScript    = [string](Get-LintScript) }
    if (Test-FunctionDefined 'Get-TestCommands')            { $answers.TestCommands  = @(Get-TestCommands) }
    if (Test-FunctionDefined 'Get-ChangelogPath')           { $answers.ChangelogPath = [string](Get-ChangelogPath) }
    if (Test-FunctionDefined 'Get-ShopifyThemeDeleteMarker'){ $answers.DeleteMarker  = [string](Get-ShopifyThemeDeleteMarker) }
    # THE ONE SEAM #2228 DID NOT HAVE, and it is named rather than smuggled in. That issue's second
    # argument for building this upstream was that "every seam it needs already exists", and it does --
    # for every FACT. What it does not have is the PATH of the consumer's drift check, because that
    # script is still consumer-side. So this is optional with a conventional default, and it is a bridge:
    # the same issue calls live-snapshot.ps1 "a strong candidate to move in the same release", and the
    # day it moves this seam stops having a job.
    if (Test-FunctionDefined 'Get-ShopifyDriftCheckPath')   { $answers.DriftCheck    = [string](Get-ShopifyDriftCheckPath) }
    [pscustomobject]$answers
} $repoRoot

$store = ([string]$Store).Trim()
if (-not $store) { $store = ([string]$seam.StoreDomain).Trim() }
if (-not $store -or $store -match 'VUL-IN') {
    Write-Host 'REFUSED: no store domain.' -ForegroundColor Red
    Write-Host 'Answer Get-ShopifyThemeEstateStore in scripts/repo-config.ps1, or pass -Store for this run.'
    Write-Host 'It is deliberately NOT Get-ShopifyStoreDomain: answering that one also unlocks sync-main''s'
    Write-Host 'bare PR route, which opens a PR without this repo''s lint and test gates (#1965).'
    exit 1
}

# A NON-NUMERIC LIVE ID COUNTS AS NO ANSWER -- the same rule the guard hook applies, and for the same
# reason: a 'VUL-IN' left behind in the seam block reads as answered to anything testing emptiness.
$liveId = ([string]$seam.LiveThemeId).Trim()
if ($liveId -notmatch '^\d+$') { $liveId = '' }
if (-not $liveId) {
    Write-Host 'REFUSED: no live theme id known.' -ForegroundColor Red
    Write-Host 'Answer Get-ShopifyLiveThemeId in scripts/repo-config.ps1. Every remaining step in this'
    Write-Host 'preflight is about the LIVE theme, so it refuses to guess which one that is.'
    exit 1
}

$trunk = ([string]$seam.Trunk).Trim()
if (-not $trunk) { $trunk = 'main' }
$syncPrefix = ([string]$seam.SyncPrefix).Trim()
if (-not $syncPrefix) { $syncPrefix = 'sync/' }

Write-Host "== live-preflight -- $store ==" -ForegroundColor Cyan
Write-Host '   it verifies and reports. It never pushes, and it never writes the authorisation marker.'
Write-Host ''

# The step record the verdict is folded from. Every step appends exactly one row, including the ones
# that pass, so the summary is a measurement rather than a count of complaints.
$steps = @()
function Add-Step {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][ValidateSet('pass', 'refuse', 'skip', 'warn')][string]$State,
        [string]$Detail = ''
    )
    $script:steps += [pscustomobject]@{ Name = $Name; State = $State; Detail = $Detail }
    $colour = switch ($State) { 'pass' { 'Green' } 'refuse' { 'Red' } 'skip' { 'Yellow' } default { 'Yellow' } }
    $label  = switch ($State) { 'pass' { 'OK     ' } 'refuse' { 'REFUSED' } 'skip' { 'SKIPPED' } default { 'NOTE   ' } }
    if ($Detail) { Write-Host "  $label $Detail" -ForegroundColor $colour }
    else         { Write-Host "  $label $Name"   -ForegroundColor $colour }
}

function Invoke-Git {
    <#
        git through the bounded capture, so a prompt or a hung remote ends the step rather than the run.
        Local queries are fast; the fetch in step 1 is the one that can reach a network.

        '-c core.quotePath=true' ON EVERY CALL, and it is not tidiness -- it is the repair
        .claude/rules/language-layers.md prescribes for this whole class, and a theme is exactly where
        the class bites. Windows PowerShell 5.1 decodes a native child's stdout with the console code
        page, so a path like 'sections/cafe.liquid' with an accent comes back as different characters on
        cp850 and cp1252. Forced quoting holds the wire to ASCII, where every candidate code page
        agrees, and Convert-GitQuotedPath decodes it back here. The measured cost of not doing this is
        sync-main's own scar: a path that matched nothing on the other side and was treated as foreign.
        Forcing the flag rather than trusting git's default matters because a repo may set it itself.
    #>
    param([Parameter(Mandatory = $true)][string[]]$Arguments, [int]$TimeoutSeconds = 120)
    return Invoke-NativeCapture -FilePath 'git' -Arguments (@('-c', 'core.quotePath=true') + $Arguments) -TimeoutSeconds $TimeoutSeconds
}

function Get-GitLines {
    <# The captured output as trimmed, non-empty lines. One reader, so a dozen call sites do not each
       invent their own splitting -- and git's output on Windows carries CR that a naive split keeps. #>
    param($Capture)
    if ($null -eq $Capture) { return @() }
    return @(($Capture.Output | Out-String) -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Get-GitPaths {
    <# Get-GitLines plus the quoted-path decode, for the calls whose lines are PATHS rather than shas or
       counts. Separate from Get-GitLines on purpose: a sha has nothing to decode, and running every
       read through a path decoder would be one more thing to get wrong on output that never needed it. #>
    param($Capture)
    return @(Get-GitLines $Capture | ForEach-Object { Convert-GitQuotedPath -Path $_ })
}

# === 1/9 -- the trunk ==============================================================================
Write-Host '[1/9] trunk -- clean, on the trunk, and level with origin' -ForegroundColor Cyan

$branch = ''
$headCap = Invoke-Git -Arguments @('rev-parse', '--abbrev-ref', 'HEAD')
if ((Test-NativeExitMeasured -Capture $headCap) -and $headCap.ExitCode -eq 0) { $branch = (Get-GitLines $headCap | Select-Object -First 1) }

if ($branch -ne $trunk) {
    Add-Step -Name 'trunk' -State 'refuse' -Detail "on '$branch', not on the trunk '$trunk'. A live push ships what is MERGED, so this runs from the trunk."
} else {
    $dirty = @(Get-GitLines (Invoke-Git -Arguments @('status', '--porcelain')))
    if ($dirty.Count -gt 0) {
        Add-Step -Name 'trunk' -State 'refuse' -Detail "the working copy holds $($dirty.Count) uncommitted change(s). What is about to reach live must be what is committed on '$trunk'."
    } else {
        # THE FETCH IS READ-ONLY AND IT IS THE POINT. 'level with origin' asked of a stale ref answers
        # about the last time somebody fetched, which on a release day is exactly when a colleague's
        # merge is the thing you have not seen.
        $fetch = Invoke-Git -Arguments @('fetch', 'origin', $trunk) -TimeoutSeconds 120
        if (-not (Test-NativeExitMeasured -Capture $fetch) -or $fetch.ExitCode -ne 0) {
            Add-Step -Name 'trunk' -State 'warn' -Detail "could not fetch origin/$trunk ($(Get-NativeExitLabel -Capture $fetch)), so 'level with origin' is judged against whatever this checkout last saw."
        }
        $countCap = Invoke-Git -Arguments @('rev-list', '--left-right', '--count', "origin/$trunk...HEAD")
        $counts = (Get-GitLines $countCap | Select-Object -First 1)
        # THE MATCH IS TAKEN ONCE INTO ITS OWN VARIABLES, not read back out of $Matches in a later branch.
        # '-or' short-circuits, so a failing exit code leaves $Matches holding whatever the LAST regex in
        # this run put there -- and a stale $Matches here reads as a clean trunk, which is the direction
        # that lets a push go out from a checkout nobody else can see.
        $behind = -1
        $ahead  = -1
        if ((Test-NativeExitMeasured -Capture $countCap) -and $countCap.ExitCode -eq 0 -and $counts -match '^(\d+)\s+(\d+)$') {
            $behind = [int]$Matches[1]
            $ahead  = [int]$Matches[2]
        }
        if ($behind -lt 0) {
            Add-Step -Name 'trunk' -State 'warn' -Detail "could not compare with origin/$trunk -- the trunk is clean and checked out, and how it stands against the remote is unknown."
        } elseif ($behind -ne 0 -or $ahead -ne 0) {
            Add-Step -Name 'trunk' -State 'refuse' -Detail "'$trunk' is $behind behind and $ahead ahead of origin/$trunk. Push or pull first -- a live push from a trunk nobody else can see is not reproducible."
        } else {
            Add-Step -Name 'trunk' -State 'pass' -Detail "on '$trunk', clean, and level with origin/$trunk."
        }
    }
}

# === 2/9 -- the repo's own gates ===================================================================
Write-Host ''
Write-Host "[2/9] gates -- the repo's own lint and tests" -ForegroundColor Cyan

if ($SkipGates) {
    Add-Step -Name 'gates' -State 'skip' -Detail '-SkipGates was passed, so nothing here was re-run.'
} else {
    $lintScript = ([string]$seam.LintScript).Trim()
    $testCommands = @(@($seam.TestCommands) | ForEach-Object { "$_" } | Where-Object { $_.Trim() })

    if (-not $lintScript -and $testCommands.Count -eq 0) {
        # NOT A REFUSAL. A repo with no gate seams answered is a repo whose gates run somewhere else --
        # normally CI on the merge that produced this trunk, which is the premise of step 1. Saying so
        # is the honest answer; refusing would be this plugin deciding a workflow question for a repo
        # that never asked it to.
        Add-Step -Name 'gates' -State 'skip' -Detail 'neither Get-LintScript nor Get-TestCommands is answered, so no gate ran here. CI on the merge is what proved this trunk.'
    } else {
        # EVERY EXIT-CODE TEST BELOW ASKS Test-NativeExitMeasured FIRST (issue #2081). These captures are
        # BOUNDED, and a bounded capture's ExitCode is PowerShell's own $null about once in 300 fresh
        # Start-Process children -- against which '$r.ExitCode -ne 0' reads as a real failure and
        # '-eq 0' reads as one too. Both spellings fail towards "something went wrong", so the number
        # cannot be asked the question at all; it has to be asked BEFORE the number is looked at. Here
        # an unmeasurable gate is a gate failure, which is the safe direction on a live push -- what
        # changes is that the run SAYS so instead of printing 'exited ' with the number missing.
        $gateFailed = @()
        if ($lintScript) {
            $lintPath = Join-Path $repoRoot $lintScript
            if (-not (Test-Path -LiteralPath $lintPath -PathType Leaf)) {
                $gateFailed += "Get-LintScript names '$lintScript', which is not a file in this repo"
            } else {
                Write-Host "  running the lint gate ($lintScript)..."
                $lint = Invoke-NativeCapture -FilePath 'powershell' -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $lintPath) -TimeoutSeconds 1800
                if (-not (Test-NativeExitMeasured -Capture $lint) -or $lint.ExitCode -ne 0) {
                    $gateFailed += "the lint gate: $(Get-NativeExitLabel -Capture $lint)"
                }
            }
        }
        foreach ($cmd in $testCommands) {
            Write-Host "  running: $cmd"
            $run = Invoke-NativeCapture -FilePath 'powershell' -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $cmd) -TimeoutSeconds 3600
            if (-not (Test-NativeExitMeasured -Capture $run) -or $run.ExitCode -ne 0) {
                $gateFailed += "'$cmd': $(Get-NativeExitLabel -Capture $run)"
            }
        }
        if ($gateFailed.Count -gt 0) {
            Add-Step -Name 'gates' -State 'refuse' -Detail ($gateFailed -join '; ')
        } else {
            Add-Step -Name 'gates' -State 'pass' -Detail 'every gate this repo names passed.'
        }
    }
}

# === 3/9 -- the push list ==========================================================================
Write-Host ''
Write-Host '[3/9] push list -- derived from the range, never typed' -ForegroundColor Cyan

$pushFiles = @()
$sinceTag = ([string]$SinceTag).Trim()
if (-not $sinceTag) {
    # Get-HighestReleaseTag AND NOT 'git tag --sort=-v:refname | head -1'. The sort exists and works;
    # what it does not do is travel -- the pick is asserted in the suite, and a pipeline is not.
    $sinceTag = Get-HighestReleaseTag -Tags (Get-GitLines (Invoke-Git -Arguments @('tag', '--list')))
}

if (-not $sinceTag) {
    Add-Step -Name 'push list' -State 'refuse' -Detail 'no vX.Y.Z tag in this repo, so there is no previous release to diff against. Pass -SinceTag to name the baseline explicitly.'
} else {
    $rangeCap = Invoke-Git -Arguments @('diff', '--name-only', "$sinceTag..HEAD")
    if (-not (Test-NativeExitMeasured -Capture $rangeCap) -or $rangeCap.ExitCode -ne 0) {
        Add-Step -Name 'push list' -State 'refuse' -Detail "could not diff $sinceTag..HEAD ($(Get-NativeExitLabel -Capture $rangeCap)) -- is '$sinceTag' a tag this checkout has? Try 'git fetch --tags'."
    } else {
        $changed = @(Get-GitPaths $rangeCap)

        # --- SYNC PROVENANCE ------------------------------------------------------------------------
        # A SYNC IS ONE-WAY, so a file whose only history in this range came in through one is already
        # on live -- pushing it back is a no-op on a good day, and on the day the third party has edited
        # again since, it silently reverts their work.
        #
        # TWO MERGE SHAPES, BECAUSE TWO WORKFLOWS EXIST. A merge commit carries the branch name in its
        # subject ('merge: sync/2026-09-20 (#123)'), and a squash merge has no merge commit at all --
        # there the single commit's own subject is what names the branch. Both are read; a repo using
        # neither simply produces an empty set, and then nothing is excluded, which is the safe
        # direction: a push list that is one file too LONG re-pushes bytes that are already correct.
        $syncCommits = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        $headCaps = @(Get-GitLines (Invoke-Git -Arguments @('log', '--no-renames', '--format=%H%x09%P%x09%s', "$sinceTag..HEAD")))
        foreach ($line in $headCaps) {
            $f = $line -split "`t", 3
            if ($f.Count -lt 3) { continue }
            $sha = $f[0]; $parents = @(($f[1] -split '\s+') | Where-Object { $_ }); $subject = $f[2]
            if ($subject -notmatch [regex]::Escape($syncPrefix)) { continue }
            if ($parents.Count -ge 2) {
                # A merge: the commits it brought in are its second-parent side, up to the merge base.
                foreach ($s in (Get-GitLines (Invoke-Git -Arguments @('rev-list', "$($parents[0])..$sha")))) { [void]$syncCommits.Add($s) }
            } else {
                [void]$syncCommits.Add($sha)
            }
        }

        # ONE LOG WALK, AND NO PATH IS EVER HANDED BACK TO GIT. The obvious shape here is a `git log
        # -- <path>` per candidate, and it is the wrong one on this platform: the paths come back
        # ASCII-quoted and decoded (see Invoke-Git), so passing one as an ARGUMENT would re-encode it
        # with the console code page -- the same round trip the quoting exists to avoid, in the other
        # direction. Walking the log once and attributing paths to commits asks git nothing it has to
        # decode, and costs one call instead of one per file.
        $syncOwned = @()
        if ($syncCommits.Count -gt 0) {
            $touchedBySync = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
            $touchedByUs   = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
            $current = ''
            $walk = Invoke-Git -Arguments @('log', '--no-renames', '--format=COMMIT%x09%H', '--name-only', "$sinceTag..HEAD")
            foreach ($line in (Get-GitLines $walk)) {
                if ($line.StartsWith("COMMIT`t")) { $current = $line.Substring(7); continue }
                if (-not $current) { continue }
                $p = (Convert-GitQuotedPath -Path $line) -replace '\\', '/'
                if ($syncCommits.Contains($current)) { [void]$touchedBySync.Add($p) } else { [void]$touchedByUs.Add($p) }
            }
            # EVERY touching commit, not any -- a file a sync mirrored AND this repo then changed itself
            # is this repo's to push. The direction of that asymmetry is deliberate: treating it as
            # sync-owned would drop a real change out of the push list silently, and a short push list is
            # the failure nobody sees until a customer does.
            foreach ($p in $touchedBySync) { if (-not $touchedByUs.Contains($p)) { $syncOwned += $p } }
        }

        $rows = @(Get-LivePushRows -ChangedPaths $changed -SyncOwnedPaths $syncOwned)
        $pushFiles = @($rows | Where-Object { $_.Push } | ForEach-Object { $_.Path })
        $held = @($rows | Where-Object { -not $_.Push })

        Write-Host "  $sinceTag..HEAD changed $($changed.Count) file(s)."
        foreach ($r in ($rows | Where-Object { $_.Push })) { Write-Host "    push  $($r.Path)" -ForegroundColor Green }
        # EVERY HELD ROW IS PRINTED TOO, grouped rather than silent: a list that showed only the keepers
        # would be unfalsifiable, because the files it must never push are exactly the rows it would not
        # print. Grouped by reason so 50 script paths read as one fact and not as fifty.
        $byKind = $held | Group-Object -Property Kind
        foreach ($g in $byKind) {
            Write-Host "    held  $($g.Count) file(s): $($g.Group[0].Reason)" -ForegroundColor DarkGray
            foreach ($r in $g.Group) { Write-Host "            $($r.Path)" -ForegroundColor DarkGray }
        }

        # A PATH THAT IS NOT SAFE TO PASTE REFUSES HERE, AT STEP 3, AND NOT AT THE COMMAND (#2514). Step
        # 8 prints the push for a person to paste, and a theme filename off a sync branch is text nobody
        # in this repo typed -- '$(...)', ';' or a newline in one runs when the line is pasted. Refusing
        # this early is the cost-ordering rule: the backup at step 7 is skipped once anything has
        # refused, so a push that can never be printed does not first cost eight minutes and a theme
        # slot. Each refused path is NAMED through Format-SafePathToken, which strips the control
        # characters a newline attack needs; the name is a display, never part of a command.
        $unsafePush = @(Get-LivePushUnsafePaths -Paths $pushFiles)

        if ($pushFiles.Count -eq 0) {
            Add-Step -Name 'push list' -State 'refuse' -Detail "nothing in $sinceTag..HEAD lives on a theme, so there is nothing to push. This release is code and docs only."
        } elseif ($unsafePush.Count -gt 0) {
            $named = (@($unsafePush | Select-Object -First 5) | ForEach-Object { "'$(Format-SafePathToken -Value $_)'" }) -join ', '
            $more  = if ($unsafePush.Count -gt 5) { ", and $($unsafePush.Count - 5) more" } else { '' }
            Add-Step -Name 'push list' -State 'refuse' -Detail "$($unsafePush.Count) theme path(s) are not safe to print inside a command a person pastes: $named$more. Only letters (Latin accents included), digits, '.', '_', '/' and '-' are printed. Rename the file on the theme, or push it by hand after reading its name byte by byte."
        } else {
            Add-Step -Name 'push list' -State 'pass' -Detail "$($pushFiles.Count) theme file(s) to push, out of $($changed.Count) changed."
        }
    }
}

# === 4/9 -- what the version owes ==================================================================
Write-Host ''
Write-Host '[4/9] version -- what the pending entries owe, and the target' -ForegroundColor Cyan

$changelogPath = ([string]$seam.ChangelogPath).Trim()
if (-not $changelogPath) { $changelogPath = 'CHANGELOG.md' }
$changelogFull = Join-Path $repoRoot $changelogPath

if (-not (Test-Path -LiteralPath $changelogFull -PathType Leaf)) {
    Add-Step -Name 'version' -State 'skip' -Detail "no changelog at '$changelogPath', so what the version owes was not read."
} else {
    # THE BUMP RULE IS NOT RESTATED HERE, AND THAT IS THE WHOLE DESIGN OF THIS STEP. Which bump a set of
    # pending entries earns is one rule, owned by the workflow that cuts releases, and a second copy of
    # it inside a Shopify plugin would be free to drift from the gate that actually enforces it. So the
    # authority is CALLED where the repo has it -- guarded, in a child scope -- and where it does not,
    # this step says it could not read rather than inventing an answer.
    $pending = & {
        Set-StrictMode -Off
        $lib = Join-Path $args[0] 'scripts\lib\entry-scaffold-lib.ps1'
        if (-not (Test-Path -LiteralPath $lib -PathType Leaf)) { return $null }
        try { . $lib } catch { return $null }
        if (-not (Test-FunctionDefined 'Get-ChangelogPendingCounts') -or -not (Test-FunctionDefined 'Get-EntryEarnedBump')) { return $null }
        try {
            $counts = Get-ChangelogPendingCounts -Content ([IO.File]::ReadAllText($args[1]))
            $earned = Get-EntryEarnedBump -ByTier $counts.ByTier
            return [pscustomobject]@{ Total = [int]$counts.Total; Bump = [string]$earned.Bump; Notable = [int]$earned.Notable }
        } catch { return $null }
    } $repoRoot $changelogFull

    if ($null -eq $pending) {
        Add-Step -Name 'version' -State 'skip' -Detail "this repo has no local copy of the release workflow's entry lib, so the bump the pending entries owe was not computed. The cut decides it."
    } elseif ($pending.Total -eq 0) {
        Add-Step -Name 'version' -State 'warn' -Detail "'$changelogPath' has no pending entries. A live push normally follows a cut, and a cut with nothing pending has nothing to describe."
    } else {
        # THE ARITHMETIC IS LOCAL AND THE RULE IS NOT. Adding one to a component is not a policy; which
        # component to add it to is, and that answer came from the call above.
        $target = ''
        if ($sinceTag -match '^v(\d+)\.(\d+)\.(\d+)$') {
            $maj = [int]$Matches[1]; $min = [int]$Matches[2]; $pat = [int]$Matches[3]
            if ($pending.Bump -eq 'minor') { $min++; $pat = 0 } else { $pat++ }
            $target = "v$maj.$min.$pat"
        }
        $targetText = if ($target) { " -- target $target" } else { '' }
        Add-Step -Name 'version' -State 'pass' -Detail "$($pending.Total) pending entr(y/ies), $($pending.Notable) of them reaching beyond this repo: a $($pending.Bump)$targetText."
    }
}

# === 5/9 -- the live theme, by id AND by role ======================================================
Write-Host ''
Write-Host '[5/9] live theme -- by configured id AND by the role the store reports' -ForegroundColor Cyan

function Get-ThemeList {
    # -Quiet AND -DiscardStderr, both required rather than tidy: the CLI writes a hint line to stderr
    # WHILE SUCCEEDING under Claude Code, which ConvertFrom-Json then refuses as a JSON primitive.
    #
    # AND THE WHOLE CALL IS IN A try, because a MISSING CLI does not come back as an exit code -- it
    # throws CommandNotFoundException, under this script's 'Stop', and takes the run down at step 5 with
    # a stack trace instead of a verdict. Measured against a fixture on a machine with no Shopify CLI
    # installed, which is every machine that is not a store's. A preflight whose job is to refuse
    # cleanly must not be the one thing in the chain that crashes.
    $list = $null
    try {
        $list = Invoke-ShopifyCli -Arguments @('theme', 'list', '--store', $store, '--json') -Quiet -DiscardStderr
    } catch {
        Write-Warning "the Shopify CLI could not be run: $(Format-SafeProseToken -Value $_.Exception.Message)"
        return $null
    }
    if ($null -eq $list -or $list.ExitCode -ne 0) { return $null }
    $parsed = $null
    try { $parsed = ($list.Output | Out-String) | ConvertFrom-Json } catch { return $null }
    # THE WRAPPER TEST IS ON THE PROPERTY, NOT ON TRUTHINESS: '$array.themes' does member enumeration in
    # PowerShell 5.1 and yields an array of $null that is not empty and is therefore truthy.
    if ($parsed -isnot [System.Array] -and $parsed.PSObject.Properties.Name -contains 'themes') { return @($parsed.themes) }
    return @($parsed)
}

$themes = Get-ThemeList
if ($null -eq $themes) {
    Add-Step -Name 'live theme' -State 'refuse' -Detail 'could not read the store''s theme list -- the Shopify CLI is missing, not authenticated, or the store is wrong. Which theme is live is therefore unverified, and everything after this is about that theme.'
} else {
    $match = @($themes | Where-Object { $_ -and ([string]$_.id).Trim() -eq $liveId })
    $byRole = @($themes | Where-Object { $_ -and ([string]$_.role).Trim().ToLower() -eq 'main' })
    if ($match.Count -ne 1) {
        Add-Step -Name 'live theme' -State 'refuse' -Detail "the configured live theme id ($liveId) is not in this store's theme list. Get-ShopifyLiveThemeId has gone stale, or this is the wrong store."
    } elseif ($byRole.Count -eq 1 -and ([string]$byRole[0].id).Trim() -ne $liveId) {
        # TWO INDEPENDENT ANSWERS, AND THE DAY THEY DIFFER IS THE DAY ONE OF THEM IS THE ONLY GUARD LEFT
        # -- the same pairing the preview sweep refuses on. A push aimed at a stale id lands on a theme
        # no customer sees, which reads as a successful release nobody can find.
        Add-Step -Name 'live theme' -State 'refuse' -Detail "the store reports theme $(([string]$byRole[0].id).Trim()) ('$($byRole[0].name)') as live, and this repo is configured for $liveId. One of the two is wrong and a push must not guess which."
    } else {
        Add-Step -Name 'live theme' -State 'pass' -Detail "live is '$($match[0].name)' (id $liveId, role $($match[0].role)) -- id and role agree."
    }
}

# === 6/9 -- the drift check, with the list AS AN ARRAY =============================================
Write-Host ''
Write-Host '[6/9] drift -- third-party edits on the files about to be overwritten' -ForegroundColor Cyan

$driftRel = ([string]$DriftCheckPath).Trim()
if (-not $driftRel) { $driftRel = ([string]$seam.DriftCheck).Trim() }
if (-not $driftRel) { $driftRel = 'scripts/theme/live-snapshot.ps1' }
$driftFull = Join-Path $repoRoot $driftRel

if ($pushFiles.Count -eq 0) {
    Add-Step -Name 'drift' -State 'skip' -Detail 'there is no push list to check.'
} elseif (-not (Test-Path -LiteralPath $driftFull -PathType Leaf)) {
    Add-Step -Name 'drift' -State 'skip' -Detail "no drift check at '$driftRel'. The push list is derived and UNCHECKED against what a third party may have written on live since; pass -DriftCheckPath, or answer Get-ShopifyDriftCheckPath."
} else {
    # CALLED IN THIS PROCESS WITH A REAL ARRAY, AND THAT IS THE ENTIRE POINT OF THE STEP. The measured
    # failure (#2228, at v2.39.0) is this same call made through `powershell -File`, which flattens
    # -Only into ONE string that never splits on commas: the check snapshotted zero files and printed a
    # green "safe to push", and the rollback artefact for that release did not exist. '&' with a
    # [string[]] cannot flatten, so the defect is closed by construction rather than by remembering.
    Write-Host "  $driftRel -Only <$($pushFiles.Count) paths, as an array>"
    $driftExit = 0
    try {
        $global:LASTEXITCODE = 0
        & $driftFull -Only $pushFiles
        $driftExit = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
    } catch {
        $driftExit = -1
        Write-Warning "the drift check threw: $(Format-SafeProseToken -Value $_.Exception.Message)"
    }
    if ($driftExit -eq 0) {
        Add-Step -Name 'drift' -State 'pass' -Detail "the drift check passed on all $($pushFiles.Count) file(s)."
    } else {
        # DRIFT IS A REFUSAL AND NOT A WARNING, which #2228 asked for in those words. A file a third
        # party has edited on live since this repo last saw it is a file whose push DESTROYS their work.
        Add-Step -Name 'drift' -State 'refuse' -Detail "the drift check exited $driftExit. Something on live is not what this repo thinks it is -- read its report before anything is pushed."
    }
}

# === 7/9 -- the verified backup ====================================================================
Write-Host ''
Write-Host '[7/9] backup -- one verified copy of live, before anything overwrites it' -ForegroundColor Cyan

$backupScript = Join-Path $PSScriptRoot 'backup-live-theme.ps1'

# THE ONE STEP THAT WRITES TO THE STORE DOES NOT RUN ONCE THE RUN HAS ALREADY REFUSED, and this is the
# cost-ordering rule taken to its conclusion rather than a separate idea. Every other step here reads;
# this one duplicates a theme, waits minutes for it to fill, and ROTATES THE PREVIOUS BACKUP OUT. Doing
# that for a push that is not going to happen spends a theme slot on a finite estate and, worse,
# replaces a good backup with a rollback point for a stand nobody is pushing from.
#
# IT IS ITS OWN SKIP RATHER THAN AN EARLY EXIT, because the remaining steps still report and a reader
# wants the whole picture in one run -- which is the entire premise of a preflight that reports.
$alreadyRefused = @($steps | Where-Object { $_.State -eq 'refuse' })
if ($alreadyRefused.Count -gt 0 -and -not $SkipBackup) {
    Add-Step -Name 'backup' -State 'skip' -Detail "not taken: $($alreadyRefused.Count) earlier step(s) already refused, and this is the one step that writes to the store. A backup rotates the previous one out, which is not worth spending on a push that is not happening."
} elseif ($SkipBackup) {
    Add-Step -Name 'backup' -State 'skip' -Detail '-SkipBackup was passed. Only correct if a VERIFIED backup of this same live stand already exists.'
} elseif (-not (Test-Path -LiteralPath $backupScript -PathType Leaf)) {
    Add-Step -Name 'backup' -State 'skip' -Detail 'backup-live-theme.ps1 is not beside this script, so no rollback point was taken.'
} else {
    # IT RUNS HERE, LAST OF THE ACTING STEPS, BECAUSE IT IS THE EXPENSIVE ONE. The verify polled roughly
    # eight minutes in the consumer's store, and #2228 asked for exactly this ordering: failing a lint
    # gate must not cost eight minutes first.
    #
    # AND ITS MEANING CHANGED WITH ITS MOMENT. Taken here it is a ROLLBACK POINT -- the stand before the
    # push -- rather than the baseline of what shipped. That trade-off is the consumer's to make and is
    # argued in that script's own header; what matters here is that a Shopify push is per-file, has no
    # locking and CAN ARRIVE PARTIALLY, so a backup taken after one has captured the broken state and is
    # by construction not a rollback.
    Write-Host '  this is the slow step: the copy is polled until it is provably complete (roughly eight'
    Write-Host '  minutes in the store this was specified from). Nothing after it is expensive.'
    $backup = Invoke-NativeCapture -FilePath 'powershell' -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $backupScript, '-Store', $store) -TimeoutSeconds 2700
    Write-Host ($backup.Output | Out-String)
    if ((Test-NativeExitMeasured -Capture $backup) -and $backup.ExitCode -eq 0) {
        Add-Step -Name 'backup' -State 'pass' -Detail 'a verified backup of live is standing, and the previous one was rotated out only after it was proven complete.'
    } else {
        Add-Step -Name 'backup' -State 'refuse' -Detail "backup-live-theme: $(Get-NativeExitLabel -Capture $backup). It fails loudly and rotates nothing, so the PREVIOUS backup is still standing -- but this push would have no rollback point taken from this stand."
    }
}

# === 8/9 -- the command ============================================================================
Write-Host ''
Write-Host '[8/9] the push command -- without the authorisation marker' -ForegroundColor Cyan

# NOT COMPOSED WHEN STEP 3 FOUND A PATH UNSAFE TO PASTE (#2514). Format-LivePushCommand throws on one,
# as the backstop for any caller that skipped the check; this caller did not skip it, so it reports the
# step instead of letting the throw end the run before the verdict.
$pushCommand = ''
$unsafeAtCommand = @(Get-LivePushUnsafePaths -Paths $pushFiles)
if ($unsafeAtCommand.Count -eq 0) { $pushCommand = Format-LivePushCommand -Store $store -ThemeId $liveId -Only $pushFiles }
if ($unsafeAtCommand.Count -gt 0) {
    Add-Step -Name 'command' -State 'skip' -Detail "not composed: $($unsafeAtCommand.Count) path(s) in the push list are not safe to paste, and the push-list step names them."
} elseif (-not $pushCommand) {
    Add-Step -Name 'command' -State 'skip' -Detail 'no push list, so no command was composed. A theme push without --only pushes the WHOLE theme, which is never printed from here.'
} else {
    Add-Step -Name 'command' -State 'pass' -Detail 'composed, one --only per file.'
}

# === 9/9 -- the aftercare, previewed ===============================================================
Write-Host ''
Write-Host '[9/9] aftercare -- what comes off the estate once the push has landed' -ForegroundColor Cyan

$sweepScript = Join-Path $PSScriptRoot 'sweep-preview-themes.ps1'
if (-not (Test-Path -LiteralPath $sweepScript -PathType Leaf)) {
    Add-Step -Name 'aftercare' -State 'skip' -Detail 'sweep-preview-themes.ps1 is not beside this script, so the aftercare was not previewed.'
} else {
    # DRY RUN IS THE SWEEP'S DEFAULT and no -Execute is passed here, deliberately: this step exists to
    # SHOW what the aftercare would take, and a preflight that quietly deleted themes would be acting.
    $sweep = Invoke-NativeCapture -FilePath 'powershell' -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $sweepScript, '-Store', $store) -TimeoutSeconds 600
    Write-Host ($sweep.Output | Out-String)
    if ((Test-NativeExitMeasured -Capture $sweep) -and $sweep.ExitCode -eq 0) {
        Add-Step -Name 'aftercare' -State 'pass' -Detail 'previewed above -- nothing was removed, because the sweep only removes with -Execute.'
    } else {
        Add-Step -Name 'aftercare' -State 'warn' -Detail "the sweep preview: $(Get-NativeExitLabel -Capture $sweep). It changes nothing either way; the aftercare is simply unlisted."
    }
}

# === the verdict ===================================================================================
$verdict = Get-LivePreflightVerdict -Steps $steps

Write-Host ''
Write-Host '== verdict ==' -ForegroundColor Cyan
foreach ($r in $verdict.Refusals) { Write-Host "  REFUSED  $($r.Name): $($r.Detail)" -ForegroundColor Red }
foreach ($r in $verdict.Skipped)  { Write-Host "  SKIPPED  $($r.Name): $($r.Detail)" -ForegroundColor Yellow }
foreach ($r in $verdict.Warnings) { Write-Host "  NOTE     $($r.Name): $($r.Detail)" -ForegroundColor Yellow }
Write-Host ''

if (-not $verdict.Allowed) {
    Write-Host $verdict.Summary -ForegroundColor Red
    Write-Host 'Nothing was pushed and nothing was authorised. Fix what refused and run this again.'
    exit 1
}

Write-Host $verdict.Summary -ForegroundColor Green
if ($pushCommand) {
    Write-Host ''
    Write-Host 'The push, for a person to make:' -ForegroundColor Cyan
    Write-Host "  $pushCommand"
    Write-Host ''
    # THE GUIDANCE NAMES THE MARKER'S JOB AND NEVER THE MARKER. Printing the string here would put the
    # authorised command on the screen in two pieces a copy-paste away from each other, which is the
    # same thing as printing it whole. The repo states its own marker in its own safety rules, where a
    # person reads it deliberately.
    Write-Host 'That command is REFUSED as it stands, and that is deliberate: this plugin''s live guard' -ForegroundColor Yellow
    Write-Host 'requires the authorisation marker your repo states in its own safety rules, appended to' -ForegroundColor Yellow
    Write-Host 'this exact command as a shell comment. Adding it is a human act and no script does it.' -ForegroundColor Yellow
}
exit 0
