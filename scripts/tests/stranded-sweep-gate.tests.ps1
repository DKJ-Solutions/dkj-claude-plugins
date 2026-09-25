<#
.SYNOPSIS
    Regression tests for the stranded-armed-pull-request report (issue #2438): the check script
    scripts/lint/check-stranded-sweep.ps1 and the SessionStart hook
    plugins/dkj-policy/hooks/stranded-sweep-sessioncheck.ps1.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/stranded-sweep-gate.tests.ps1

    THE CHECK SCRIPT READS THE TRACKER, unlike unfolded-entry-sessioncheck's own check
    (check-unfolded-entry.ps1, tested in unfolded-entry-gate.tests.ps1), which only ever reads the local
    git repository. So this suite drives it against a FAKE gh on PATH that records nothing and answers
    from environment variables -- the same mechanism verify-resolved-issues.tests.ps1 uses for the one
    other script in this tree that talks to gh end to end, and for the same reason: a live tracker is
    not a thing a suite may depend on.

    THE HOOK NEEDS NO gh AT ALL. It only runs the check script in-process and reads its Output/ExitCode
    (via hook-check-lib.ps1's Invoke-CheckScript, covered on its own in hook-check-lib.tests.ps1), so its
    own cases are driven against STUB check scripts written into the fixture -- the same split
    git-identity-gate.tests.ps1 draws between "the check reads the machine" and "the hook reads the
    check".

    Get-MergeOnGreenPrVerdict RETURNS EARLY ON THE EXECUTED-PATH CHECK, before it ever reads mergeable,
    the required-check state or the settle window (pinned in merge-on-green-lib.tests.ps1). So for an
    armed, non-draft, non-fork record whose diff touches such a path, Get-MergeOnGreenStrandedVerdict's
    own "does the verdict decline on this exact reason" gate always holds -- the only things that can
    still say "not stranded" for such a record are the required-check state and the settle window, which
    is exactly what this file's positive/negative fixtures vary.

    Fixture paths carry $PID (repo convention): the test gate is a throttled parallel scheduler, so two
    runs overlapping is ordinary and two sharing one fixed temp path tear down each other's tree.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Script     = Join-Path $RepoRoot 'scripts\lint\check-stranded-sweep.ps1'
$Hook       = Join-Path $RepoRoot 'plugins\dkj-policy\hooks\stranded-sweep-sessioncheck.ps1'
$HooksJson  = Join-Path $RepoRoot 'plugins\dkj-policy\hooks\hooks.json'

$script:pass  = 0
$script:fail  = 0
$script:trees = @()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor DarkGreen }
    else { $script:fail++; Write-Host "  [FAIL] $Message" -ForegroundColor Red }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message)
    if ("$Expected" -eq "$Actual") { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor DarkGreen }
    else { $script:fail++; Write-Host "  [FAIL] $Message`n         wanted: '$Expected'`n         got:    '$Actual'" -ForegroundColor Red }
}

function New-Tree {
    <# A fixture root. -WithFlow writes the one file the check feature-detects on. #>
    param([Parameter(Mandatory = $true)][string]$Label, [switch]$WithFlow)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("strandedgate-$PID-$Label-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    if ($WithFlow) {
        $flowDir = Join-Path $dir '.github\workflows'
        New-Item -ItemType Directory -Path $flowDir -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $flowDir 'merge-on-green.yml'), "name: merge-on-green`n", (New-Object System.Text.UTF8Encoding($false)))
    }
    $script:trees += $dir
    return $dir
}

Write-Host '== check-stranded-sweep.ps1 + stranded-sweep-sessioncheck.ps1 ==' -ForegroundColor Cyan
Assert-True (Test-Path -LiteralPath $Script -PathType Leaf) 'check-stranded-sweep.ps1 exists at its registered source path'
Assert-True (Test-Path -LiteralPath $Hook -PathType Leaf) 'stranded-sweep-sessioncheck.ps1 exists at its registered source path'

# --- hooks.json registration ------------------------------------------------------------------------
Write-Host ''
Write-Host 'hooks.json registration' -ForegroundColor Cyan

Assert-True (Test-Path -LiteralPath $HooksJson -PathType Leaf) 'plugins/dkj-policy/hooks/hooks.json exists'
$hooksParsed = Get-Content -LiteralPath $HooksJson -Raw | ConvertFrom-Json
$sessionStartHooks = @($hooksParsed.hooks.SessionStart | ForEach-Object { $_.hooks } | ForEach-Object { $_ })
$strandedEntry = @($sessionStartHooks | Where-Object { $_.command -match 'stranded-sweep-sessioncheck\.ps1' })
Assert-Equal 1 $strandedEntry.Count 'exactly one SessionStart hook entry names stranded-sweep-sessioncheck.ps1'
Assert-Equal 'command' $strandedEntry[0].type 'and it is a command hook'
Assert-True ([int]$strandedEntry[0].timeout -gt 0) 'and it carries a positive timeout, like its siblings'

# --- Fake gh, recording nothing, answering from environment variables -------------------------------
# Same mechanism as verify-resolved-issues.tests.ps1 -- the one other script in this tree that talks to
# gh end to end -- for the same reason: this check's tracker reads are not something a suite may depend
# on being real.
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
$fakeBin = Join-Path ([System.IO.Path]::GetTempPath()) ("strandedgate-bin-$PID-$([guid]::NewGuid().ToString('n'))")
New-Item -ItemType Directory -Path $fakeBin -Force | Out-Null
$emptyBin = Join-Path ([System.IO.Path]::GetTempPath()) ("strandedgate-empty-$PID-$([guid]::NewGuid().ToString('n'))")
New-Item -ItemType Directory -Path $emptyBin -Force | Out-Null
$script:trees += @($fakeBin, $emptyBin)

$ghImpl = @'
if ($args -contains 'auth' -and $args -contains 'status') {
    if (-not $env:GH_FAKE_ACCOUNT) {
        [Console]::Error.WriteLine('You are not logged into any GitHub hosts.')
        exit 1
    }
    Write-Output 'github.com'
    Write-Output "  * Logged in to github.com account $($env:GH_FAKE_ACCOUNT) (keyring)"
    Write-Output '  - Active account: true'
    exit 0
}
if ($args -contains 'pr' -and $args -contains 'list') {
    if ($env:GH_FAKE_PR_LIST_FAIL) { exit 1 }
    Write-Output $env:GH_FAKE_PR_LIST_JSON
    exit 0
}
if ($args -contains 'pr' -and $args -contains 'checks') {
    if ($env:GH_FAKE_PR_CHECKS_FAIL) { exit 1 }
    Write-Output $env:GH_FAKE_PR_CHECKS_JSON
    exit 0
}
exit 1
'@
[System.IO.File]::WriteAllText((Join-Path $fakeBin 'gh-impl.ps1'), $ghImpl, $Utf8NoBom)
$ghCmd = "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0gh-impl.ps1`" %*`r`nexit /b %ERRORLEVEL%`r`n"
[System.IO.File]::WriteAllText((Join-Path $fakeBin 'gh.cmd'), $ghCmd, $Utf8NoBom)

$prevPath = $env:PATH
$prevGithubRepo = $env:GITHUB_REPOSITORY
# THE FULL PATH TO THIS SESSION'S OWN powershell.exe, CAPTURED BEFORE ANY CASE NARROWS $env:PATH. The
# 'no gh on PATH' case sets PATH to a directory holding nothing at all -- and '&' resolves a bare
# 'powershell' through THAT SAME PATH, so an unqualified call would fail to launch the child at the one
# moment this suite most needs it to.
$PowershellExe = (Get-Process -Id $PID).Path

function Invoke-Check {
    <# Runs check-stranded-sweep.ps1 as a real child process (it makes real, if faked, native gh calls,
       which is exactly what a fixture-driven end-to-end suite has to exercise rather than stub away). #>
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [string]$Path = $env:PATH,
        [string]$Account = '',
        [string]$Repo = '',
        [string]$PrListJson = '[]',
        [switch]$PrListFail,
        [string]$PrChecksJson = '[]',
        [switch]$PrChecksFail,
        # -1 means "do not pass -MaxElapsedSeconds at all", so the script's own default (90) applies --
        # a caller that wants the budget behaviour under test passes a real value (issue #2438).
        [int]$MaxElapsedSeconds = -1,
        # THE PER-CALL BOUND IS PASSED GENEROUSLY, NEVER LEFT AT THE SCRIPT'S 15s DEFAULT (issue #2470).
        # The fake gh is a .cmd that launches a fresh powershell.exe, and under the parallel open-pr gate
        # (22 lanes) that launch alone can outrun 15s -- the list read then times out into [SKIP], or a
        # checks read into [INCOMPLETE], and an [OK] assert goes red for a race the tree had no part in.
        # No case here tests the per-call timeout, so this suite has no reason to be exposed to it.
        [int]$TimeoutSeconds = 120
    )
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'  # native call below -- the #107 stderr pitfall guard
        $env:PATH = $Path
        $env:GITHUB_REPOSITORY = $Repo
        $env:GH_FAKE_ACCOUNT = $Account
        $env:GH_FAKE_PR_LIST_JSON = $PrListJson
        if ($PrListFail) { $env:GH_FAKE_PR_LIST_FAIL = '1' } else { Remove-Item Env:\GH_FAKE_PR_LIST_FAIL -ErrorAction SilentlyContinue }
        $env:GH_FAKE_PR_CHECKS_JSON = $PrChecksJson
        if ($PrChecksFail) { $env:GH_FAKE_PR_CHECKS_FAIL = '1' } else { Remove-Item Env:\GH_FAKE_PR_CHECKS_FAIL -ErrorAction SilentlyContinue }
        $scriptArgs = @('-RootOverride', $Dir, '-TimeoutSeconds', $TimeoutSeconds)
        if ($MaxElapsedSeconds -ge 0) { $scriptArgs += @('-MaxElapsedSeconds', $MaxElapsedSeconds) }
        $out = & $PowershellExe -NoProfile -ExecutionPolicy Bypass -File $Script @scriptArgs 2>&1
        return @{ Out = ($out | Out-String); Code = $LASTEXITCODE }
    } finally {
        $ErrorActionPreference = $prevEap
        $env:PATH = $prevPath
        $env:GITHUB_REPOSITORY = $prevGithubRepo
        Remove-Item Env:\GH_FAKE_ACCOUNT, Env:\GH_FAKE_PR_LIST_JSON, Env:\GH_FAKE_PR_CHECKS_JSON -ErrorAction SilentlyContinue
        Remove-Item Env:\GH_FAKE_PR_LIST_FAIL, Env:\GH_FAKE_PR_CHECKS_FAIL -ErrorAction SilentlyContinue
    }
}

# One armed, executed-path, green, settled record, and one that touches nothing the runner executes --
# the two fixture shapes every gh-facing case below is built from. completedAt is computed AT RUN TIME
# so the suite never depends on the wall clock it happens to run under.
function New-CheckedJson {
    param([int]$MinutesAgo = 30)
    $ts = (Get-Date).ToUniversalTime().AddMinutes(-$MinutesAgo).ToString('yyyy-MM-ddTHH:mm:ssZ')
    return "[{`"name`":`"lint-en-tests`",`"bucket`":`"pass`",`"state`":`"SUCCESS`",`"completedAt`":`"$ts`"}]"
}
$GreenSettledChecksJson = New-CheckedJson -MinutesAgo 30

# A CONTROL CHARACTER IN THE BRANCH NAME AND THE TITLE -- untrusted data, chosen by whoever opened the
# pull request on this public repository. [char]0x1b is the same escape sequence
# Get-MergeOnGreenExecutedPathHit's own suite (merge-on-green-lib.tests.ps1) already uses to prove a
# control character never reaches a printed reason.
$UntrustedBranch = "fix/501-x$([char]0x1b)[2J"
$UntrustedTitle  = "evil title$([char]0x07)bell"
$StrandedPrJson = "[{`"number`":501,`"headRefName`":`"$UntrustedBranch`",`"title`":`"$UntrustedTitle`",`"isDraft`":false,`"mergeable`":`"MERGEABLE`",`"isCrossRepository`":false,`"labels`":[{`"name`":`"merge-when-green`"}],`"files`":[{`"path`":`"scripts/repo-config.ps1`",`"additions`":1,`"deletions`":0}],`"changedFiles`":1}]"
$OrdinaryPrJson = '[{"number":77,"headRefName":"docs/77-x","title":"an ordinary docs PR","isDraft":false,"mergeable":"MERGEABLE","isCrossRepository":false,"labels":[{"name":"merge-when-green"}],"files":[{"path":"README.md","additions":1,"deletions":0}],"changedFiles":1}]'

# SEVERAL ARMED, ORDINARY PULL REQUESTS -- for the -MaxElapsedSeconds budget (issue #2438): the total
# bound is exercised across a set larger than the ordinary 0-1, and none of these touches an executed
# path, so a run that DOES judge one is never itself the reason it reports [STRANDED].
$SeveralArmedJson = '[' + (
    (701..703 | ForEach-Object {
        "{`"number`":$_,`"headRefName`":`"docs/$_-x`",`"title`":`"ok`",`"isDraft`":false,`"mergeable`":`"MERGEABLE`",`"isCrossRepository`":false,`"labels`":[{`"name`":`"merge-when-green`"}],`"files`":[{`"path`":`"README.md`",`"additions`":1,`"deletions`":0}],`"changedFiles`":1}"
    }) -join ','
) + ']'

# A BRANCH NAME CARRYING SHELL METACHARACTERS THAT SURVIVE THE DISPLAY SCRUB (issue #1594, Sebastian):
# backtick, semicolon and '$(...)' are all printable ASCII, so [^\x20-\x7E] leaves every one of them
# untouched. Alongside it, an ORDINARY branch name -- this workflow's own shape -- as the control: it
# must still round-trip into the checkout line unchanged. Both touch an executed path so both strand.
$HostileBranch = 'fix/601`x`;$(y)'
$QuotingPrJson = "[{`"number`":601,`"headRefName`":`"$HostileBranch`",`"title`":`"ok`",`"isDraft`":false,`"mergeable`":`"MERGEABLE`",`"isCrossRepository`":false,`"labels`":[{`"name`":`"merge-when-green`"}],`"files`":[{`"path`":`"scripts/repo-config.ps1`",`"additions`":1,`"deletions`":0}],`"changedFiles`":1},{`"number`":602,`"headRefName`":`"fix/602-safe`",`"title`":`"ok`",`"isDraft`":false,`"mergeable`":`"MERGEABLE`",`"isCrossRepository`":false,`"labels`":[{`"name`":`"merge-when-green`"}],`"files`":[{`"path`":`"scripts/repo-config.ps1`",`"additions`":1,`"deletions`":0}],`"changedFiles`":1}]"

try {
    # --- SKIP: no .github/workflows/merge-on-green.yml -----------------------------------------------
    Write-Host ''
    Write-Host 'check-stranded-sweep.ps1 -- [SKIP] paths, each one exit 0' -ForegroundColor Cyan

    $noFlow = New-Tree -Label 'no-flow'
    $r = Invoke-Check -Dir $noFlow
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[SKIP\]' -and $r.Out -match 'merge-on-green\.yml') `
        'no .github/workflows/merge-on-green.yml -- [SKIP], exit 0, and gh is never even reached for'

    # --- SKIP: gh not on PATH -------------------------------------------------------------------------
    $noGh = New-Tree -Label 'no-gh' -WithFlow
    $r = Invoke-Check -Dir $noGh -Path $emptyBin
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[SKIP\]' -and $r.Out -match 'gh is not installed') `
        'the workflow file exists but gh is not on PATH -- [SKIP], exit 0'

    # --- SKIP: gh present, not authenticated -----------------------------------------------------------
    $noAuth = New-Tree -Label 'no-auth' -WithFlow
    $r = Invoke-Check -Dir $noAuth -Path "$fakeBin;$prevPath" -Account ''
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[SKIP\]' -and $r.Out -match 'no active account') `
        'gh installed but logged out -- [SKIP], exit 0'

    # --- SKIP: authenticated, repo name unresolvable ----------------------------------------------------
    $noRepo = New-Tree -Label 'no-repo' -WithFlow
    $r = Invoke-Check -Dir $noRepo -Path "$fakeBin;$prevPath" -Account 'tester' -Repo ''
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[SKIP\]' -and $r.Out -match 'repo name unresolvable') `
        'authenticated but no repo-config.ps1 and no GITHUB_REPOSITORY -- [SKIP], exit 0'

    # --- SKIP: the pull-request list read fails ---------------------------------------------------------
    $listFails = New-Tree -Label 'list-fails' -WithFlow
    $r = Invoke-Check -Dir $listFails -Path "$fakeBin;$prevPath" -Account 'tester' -Repo 'fake/repo' -PrListFail
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[SKIP\]' -and $r.Out -match 'could not be read') `
        'gh pr list fails (offline, rate limit, ...) -- [SKIP], exit 0, never a strand over a bad read'

    # --- OK: nothing armed ---------------------------------------------------------------------------
    Write-Host ''
    Write-Host 'check-stranded-sweep.ps1 -- [OK], nothing to report' -ForegroundColor Cyan

    $none = New-Tree -Label 'none-armed' -WithFlow
    $r = Invoke-Check -Dir $none -Path "$fakeBin;$prevPath" -Account 'tester' -Repo 'fake/repo' -PrListJson '[]'
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[OK\]' -and $r.Out -match "nothing can be stranded") `
        'no open pull request carries the arming label -- [OK], exit 0'

    # --- OK: armed, but not stranded (an ordinary docs PR) --------------------------------------------
    $ordinary = New-Tree -Label 'ordinary' -WithFlow
    $r = Invoke-Check -Dir $ordinary -Path "$fakeBin;$prevPath" -Account 'tester' -Repo 'fake/repo' `
        -PrListJson $OrdinaryPrJson -PrChecksJson $GreenSettledChecksJson
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[OK\]' -and $r.Out -match 'none stranded') `
        'one armed pull request, touching nothing the runner executes -- [OK], exit 0, not [STRANDED]'

    # --- OK, AT SCALE: several armed, all judged, none stranded -- the unchanged wording stays honest ---
    # about the count once there is more than one (issue #2438, Victor's judged/unjudged split).
    $okMultiple = New-Tree -Label 'ok-multiple' -WithFlow
    $r = Invoke-Check -Dir $okMultiple -Path "$fakeBin;$prevPath" -Account 'tester' -Repo 'fake/repo' `
        -PrListJson $SeveralArmedJson -PrChecksJson $GreenSettledChecksJson
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[OK\]' -and $r.Out -match '3 armed pull request\(s\), none stranded') `
        'three armed pull requests, all judged, none stranded -- the unchanged [OK] wording, honest about the count'
    Assert-True ($r.Out -notmatch '\[INCOMPLETE\]') 'and no [INCOMPLETE] marker prints when nothing went unjudged'

    # --- STRANDED: the load-bearing positive case ------------------------------------------------------
    Write-Host ''
    Write-Host 'check-stranded-sweep.ps1 -- [STRANDED], and untrusted data scrubbed before it is printed' -ForegroundColor Cyan

    $stranded = New-Tree -Label 'stranded' -WithFlow
    $r = Invoke-Check -Dir $stranded -Path "$fakeBin;$prevPath" -Account 'tester' -Repo 'fake/repo' `
        -PrListJson $StrandedPrJson -PrChecksJson $GreenSettledChecksJson
    Assert-True ($r.Code -eq 0) 'a genuine finding still exits 0 -- this check must never fail a session start'
    Assert-True ($r.Out -match '\[STRANDED\]') 'armed + executed-path hit + green + settled -- [STRANDED]'
    Assert-True ($r.Out -match '#501') 'and it names the pull request number'
    Assert-True ($r.Out -match 'git checkout') 'and prints the resume: a checkout of the branch'
    Assert-True ($r.Out -match 'ship-pr\.ps1') 'and the bare ship-pr.ps1 run after it -- two lines, not one chained with &&'
    Assert-True ($r.Out -notmatch [regex]::Escape([string][char]0x1b)) 'the ESC control character in the branch name never reaches printed output'
    Assert-True ($r.Out -notmatch [regex]::Escape([string][char]0x07)) 'nor does the BEL control character in the title'
    Assert-True ($r.Out -match [regex]::Escape('fix/501-x?[2J')) 'the branch is printed with the control character scrubbed to ?, not silently dropped'
    Assert-True ($r.Out -match [regex]::Escape('evil title?bell')) 'and so is the title'

    # --- THE CHECKOUT LINE JUDGES THE RAW BRANCH THROUGH Get-PasteableRef, NOT THE DISPLAY SCRUB --------
    # (issue #1594, Sebastian). Backtick, ';' and '$(...)' are all printable ASCII and sail through
    # [^\x20-\x7E] unchanged, so only Get-PasteableRef's own allowlist stands between one of them and a
    # command a reader is invited to paste.
    Write-Host ''
    Write-Host 'check-stranded-sweep.ps1 -- the printed checkout line never carries a shell metacharacter raw (#1594)' -ForegroundColor Cyan

    $quoting = New-Tree -Label 'quoting' -WithFlow
    $r = Invoke-Check -Dir $quoting -Path "$fakeBin;$prevPath" -Account 'tester' -Repo 'fake/repo' `
        -PrListJson $QuotingPrJson -PrChecksJson $GreenSettledChecksJson
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[STRANDED\]') 'both armed pull requests strand -- the shape this case needs'
    Assert-True ($r.Out -notmatch [regex]::Escape('git checkout fix/601')) `
        'the hostile branch name never reaches the git checkout line raw'
    Assert-True ($r.Out -match [regex]::Escape('git checkout <branch>')) `
        'it prints the placeholder instead (Get-PasteableRef, issue #1594)'
    Assert-True ($r.Out -match 'NOTE: the branch name is not safe to paste') `
        'and the explaining note is printed beneath it'
    Assert-True ($r.Out -match [regex]::Escape("The branch name is: $HostileBranch")) `
        'the note names the real branch as prose, where the metacharacters are inert'
    Assert-True ($r.Out -match [regex]::Escape('git checkout fix/602-safe')) `
        'an ordinary branch name still round-trips into the checkout line unchanged'

    # --- exit 0 no matter what: a per-PR required-check read failing does not abandon the whole run ----
    Write-Host ''
    Write-Host 'check-stranded-sweep.ps1 -- a per-PR read failure is honestly [INCOMPLETE], never a silent [OK] (#2438)' -ForegroundColor Cyan

    $partial = New-Tree -Label 'partial-fail' -WithFlow
    $r = Invoke-Check -Dir $partial -Path "$fakeBin;$prevPath" -Account 'tester' -Repo 'fake/repo' `
        -PrListJson $StrandedPrJson -PrChecksFail
    Assert-True ($r.Code -eq 0 -and $r.Out -notmatch '\[STRANDED\]') `
        'this one pull request''s required-check read fails -- read as not-green for it alone, no strand claimed, exit 0'
    Assert-True ($r.Out -match '\[INCOMPLETE\]') `
        'and the run reports [INCOMPLETE], not [OK] -- it never actually judged this pull request'
    Assert-True ($r.Out -match 'judged 0 of 1') 'naming the honest split: the one armed pull request was never judged'

    # --- THE TOTAL BUDGET: a tiny -MaxElapsedSeconds against several armed pull requests (issue #2438) --
    Write-Host ''
    Write-Host 'check-stranded-sweep.ps1 -- -MaxElapsedSeconds bounds the scan in TOTAL, honestly (#2438, Victor)' -ForegroundColor Cyan

    $budgetTiny = New-Tree -Label 'budget-tiny' -WithFlow
    $r = Invoke-Check -Dir $budgetTiny -Path "$fakeBin;$prevPath" -Account 'tester' -Repo 'fake/repo' `
        -PrListJson $SeveralArmedJson -PrChecksJson $GreenSettledChecksJson -MaxElapsedSeconds 0
    Assert-True ($r.Code -eq 0) 'a zero-second scan budget still exits 0'
    Assert-True ($r.Out -notmatch '\[OK\]') 'and it is never reported as [OK] once anything went unjudged'
    Assert-True ($r.Out -match '\[INCOMPLETE\]') 'it is reported as [INCOMPLETE] instead'
    Assert-True ($r.Out -match 'judged 0 of 3') 'naming the right judged/total split -- a zero budget judges nothing'
    Assert-True ($r.Out -match '3 not checked') 'and the right unjudged count'
} finally {
    $env:PATH = $prevPath
    $env:GITHUB_REPOSITORY = $prevGithubRepo
}

# --- stranded-sweep-sessioncheck.ps1, the hook (always exit 0, no gh involved at all) -----------------
Write-Host ''
Write-Host 'stranded-sweep-sessioncheck.ps1 -- forwards the check verbatim, exits 0 regardless' -ForegroundColor Cyan

function New-StubCheck {
    <# A stand-in check script -- same shape as git-identity-gate.tests.ps1's helper of the same name.
       It accepts -RootOverride because that is the only argument the hook passes. #>
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Body,
        [Parameter(Mandatory = $true)][int]$ExitCode
    )
    $path = Join-Path $Dir "$Name.ps1"
    $lines = @("param([string]`$RootOverride = '')")
    foreach ($b in ($Body -split "`n")) {
        if ($b) { $lines += ("Write-Host '" + ($b -replace "'", "''") + "'") }
    }
    $lines += "exit $ExitCode"
    [System.IO.File]::WriteAllText($path, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
    return $path
}

function Invoke-Hook {
    param([Parameter(Mandatory = $true)][string]$CheckScriptOverride, [string]$Dir = '')
    $args = @('-CheckScriptOverride', $CheckScriptOverride)
    if ($Dir) { $args += @('-ConsumerPathOverride', $Dir) }
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Hook @args 2>&1
        return @{ Out = ($out | Out-String); Code = $LASTEXITCODE }
    } finally { $ErrorActionPreference = $prevEap }
}

$hookFixture = New-Tree -Label 'hook-stubs'

$skipStub = New-StubCheck -Dir $hookFixture -Name 'skip' -Body '[SKIP] no .github/workflows/merge-on-green.yml' -ExitCode 0
$r = Invoke-Hook -CheckScriptOverride $skipStub -Dir $hookFixture
Assert-True ($r.Code -eq 0 -and $r.Out -notmatch 'stranded-sweep-sessioncheck:') `
    'the check reports [SKIP] -- the hook stays silent, exit 0'

$okStub = New-StubCheck -Dir $hookFixture -Name 'ok' -Body '[OK] no open pull request carries the label' -ExitCode 0
$r = Invoke-Hook -CheckScriptOverride $okStub -Dir $hookFixture
Assert-True ($r.Code -eq 0 -and $r.Out -notmatch 'stranded-sweep-sessioncheck:') `
    'the check reports [OK] -- the hook stays silent too, exit 0'

$strandedStub = New-StubCheck -Dir $hookFixture -Name 'stranded' -ExitCode 0 -Body @'
[STRANDED] 1 armed pull request(s) the sweep will never take -- their diff changes code the runner executes, so only a session can finish them:
  #501 (fix/501-x)
    git checkout fix/501-x
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/release/ship-pr.ps1
'@
$r = Invoke-Hook -CheckScriptOverride $strandedStub -Dir $hookFixture
Assert-True ($r.Code -eq 0 -and $r.Out -match 'stranded-sweep-sessioncheck:' -and $r.Out -match '\[STRANDED\]') `
    'the check reports [STRANDED] -- the hook forwards it under its own headline, exit 0'
Assert-True ($r.Out -match '#501' -and $r.Out -match 'git checkout fix/501-x' -and $r.Out -match 'ship-pr\.ps1') `
    'every line the check wrote is forwarded verbatim, including the resume command'

# [INCOMPLETE] IS NOT SILENT EITHER (issue #2438) -- it carries no [STRANDED] line, so without its own
# forwarding arm it would fall straight into the [OK]/[SKIP] silence below, and a scan that did not
# finish would be indistinguishable from one that finished and found nothing.
$incompleteStub = New-StubCheck -Dir $hookFixture -Name 'incomplete' -ExitCode 0 -Body @'
[INCOMPLETE] judged 1 of 3 armed pull request(s); 2 not checked (a per-PR required-check read failed, or the 90s scan budget ran out) -- the rest were not checked, so run this again to cover them.
'@
$r = Invoke-Hook -CheckScriptOverride $incompleteStub -Dir $hookFixture
Assert-True ($r.Code -eq 0 -and $r.Out -match 'stranded-sweep-sessioncheck:' -and $r.Out -match '\[INCOMPLETE\]') `
    'the check reports [INCOMPLETE] -- the hook forwards it too, not silent, exit 0'
Assert-True ($r.Out -match 'judged 1 of 3') 'and the line is forwarded verbatim, judged/total count included'

$crashStub = New-StubCheck -Dir $hookFixture -Name 'crash' -Body '' -ExitCode 3
$r = Invoke-Hook -CheckScriptOverride $crashStub -Dir $hookFixture
Assert-True ($r.Code -eq 0 -and $r.Out -match 'could not complete \(exit 3\)') `
    'the check exits non-zero with no [STRANDED] marker -- reported as incomplete, still exit 0'

$missing = Join-Path ([System.IO.Path]::GetTempPath()) "no-such-check-$PID-$([guid]::NewGuid().ToString('n')).ps1"
$r = Invoke-Hook -CheckScriptOverride $missing -Dir $hookFixture
Assert-True ($r.Code -eq 0 -and $r.Out -match 'check script not found -- check skipped') `
    'check script missing entirely -- a notice, exit 0, never a strand'

foreach ($t in $script:trees) {
    if ($t -and (Test-Path -LiteralPath $t)) { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host "FAIL: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
