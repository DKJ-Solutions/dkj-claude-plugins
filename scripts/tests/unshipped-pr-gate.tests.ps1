<#
.SYNOPSIS
    Regression tests for the unshipped-pull-request report (issue #2525): the check script
    scripts/lint/check-unshipped-pr.ps1 and the SessionStart hook
    plugins/dkj-policy/hooks/unshipped-pr-sessioncheck.ps1.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/unshipped-pr-gate.tests.ps1

    The same split as stranded-sweep-gate.tests.ps1, and for its reasons: the CHECK is driven end to
    end against a FAKE gh on PATH answering from environment variables, because a live tracker is not
    something a suite may depend on; the HOOK needs no gh at all and is driven against stub checks.

    The verdict itself (Get-UnshippedPrVerdict) is pinned case by case in merge-on-green-lib.tests.ps1;
    this suite pins what the SCRIPT does with it -- the author filter it sends, the sweep-file switch,
    the untrusted-data scrub, the resume lines and the honest [INCOMPLETE] split.

    Fixture paths carry $PID (repo convention). Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Script     = Join-Path $RepoRoot 'scripts\lint\check-unshipped-pr.ps1'
$Hook       = Join-Path $RepoRoot 'plugins\dkj-policy\hooks\unshipped-pr-sessioncheck.ps1'
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
    <# A fixture root. -WithFlow writes the merge-on-green workflow the check switches on. #>
    param([Parameter(Mandatory = $true)][string]$Label, [switch]$WithFlow)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("unshippedgate-$PID-$Label-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    if ($WithFlow) {
        $flowDir = Join-Path $dir '.github\workflows'
        New-Item -ItemType Directory -Path $flowDir -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $flowDir 'merge-on-green.yml'), "name: merge-on-green`n", (New-Object System.Text.UTF8Encoding($false)))
    }
    $script:trees += $dir
    return $dir
}

Write-Host '== check-unshipped-pr.ps1 + unshipped-pr-sessioncheck.ps1 ==' -ForegroundColor Cyan
Assert-True (Test-Path -LiteralPath $Script -PathType Leaf) 'check-unshipped-pr.ps1 exists at its registered source path'
Assert-True (Test-Path -LiteralPath $Hook -PathType Leaf) 'unshipped-pr-sessioncheck.ps1 exists at its registered source path'

Write-Host ''
Write-Host 'hooks.json registration' -ForegroundColor Cyan
$hooksParsed = Get-Content -LiteralPath $HooksJson -Raw | ConvertFrom-Json
$sessionStartHooks = @($hooksParsed.hooks.SessionStart | ForEach-Object { $_.hooks } | ForEach-Object { $_ })
$entry = @($sessionStartHooks | Where-Object { $_.command -match 'unshipped-pr-sessioncheck\.ps1' })
Assert-Equal 1 $entry.Count 'exactly one SessionStart hook entry names unshipped-pr-sessioncheck.ps1'
Assert-Equal 'command' $entry[0].type 'and it is a command hook'
Assert-True ([int]$entry[0].timeout -gt 0) 'and it carries a positive timeout, like its siblings'

# --- Fake gh ---------------------------------------------------------------------------------------
# It also RECORDS the pr-list arguments into a file, so the author filter the script sends is asserted
# rather than assumed -- that filter is the whole of what keeps a colleague's pull request out of your
# session start.
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
$fakeBin = Join-Path ([System.IO.Path]::GetTempPath()) ("unshippedgate-bin-$PID-$([guid]::NewGuid().ToString('n'))")
New-Item -ItemType Directory -Path $fakeBin -Force | Out-Null
$emptyBin = Join-Path ([System.IO.Path]::GetTempPath()) ("unshippedgate-empty-$PID-$([guid]::NewGuid().ToString('n'))")
New-Item -ItemType Directory -Path $emptyBin -Force | Out-Null
$argLog = Join-Path $fakeBin 'pr-list-args.txt'
$checksLog = Join-Path $fakeBin 'pr-checks-count.txt'
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
    if ($env:GH_FAKE_ARG_LOG) { [System.IO.File]::WriteAllText($env:GH_FAKE_ARG_LOG, ($args -join ' ')) }
    if ($env:GH_FAKE_PR_LIST_FAIL) { exit 1 }
    Write-Output $env:GH_FAKE_PR_LIST_JSON
    exit 0
}
if ($args -contains 'pr' -and $args -contains 'checks') {
    if ($env:GH_FAKE_CHECKS_LOG) { [System.IO.File]::AppendAllText($env:GH_FAKE_CHECKS_LOG, "x`n") }
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
$PowershellExe = (Get-Process -Id $PID).Path

function Invoke-Check {
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [string]$Path = $env:PATH,
        [string]$Account = '',
        [string]$Repo = '',
        [string]$PrListJson = '[]',
        [switch]$PrListFail,
        [string]$PrChecksJson = '[]',
        [switch]$PrChecksFail,
        [int]$MaxElapsedSeconds = -1,
        # Generous per-call bound, never the 15s default -- stranded-sweep-gate.tests.ps1 records why
        # (#2470): the fake gh launches a fresh powershell.exe, which a loaded parallel gate can delay.
        [int]$TimeoutSeconds = 120
    )
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $env:PATH = $Path
        $env:GITHUB_REPOSITORY = $Repo
        $env:GH_FAKE_ACCOUNT = $Account
        $env:GH_FAKE_PR_LIST_JSON = $PrListJson
        $env:GH_FAKE_ARG_LOG = $argLog
        $env:GH_FAKE_CHECKS_LOG = $checksLog
        Remove-Item -LiteralPath $argLog, $checksLog -ErrorAction SilentlyContinue
        if ($PrListFail) { $env:GH_FAKE_PR_LIST_FAIL = '1' } else { Remove-Item Env:\GH_FAKE_PR_LIST_FAIL -ErrorAction SilentlyContinue }
        $env:GH_FAKE_PR_CHECKS_JSON = $PrChecksJson
        if ($PrChecksFail) { $env:GH_FAKE_PR_CHECKS_FAIL = '1' } else { Remove-Item Env:\GH_FAKE_PR_CHECKS_FAIL -ErrorAction SilentlyContinue }
        $scriptArgs = @('-RootOverride', $Dir, '-TimeoutSeconds', $TimeoutSeconds)
        if ($MaxElapsedSeconds -ge 0) { $scriptArgs += @('-MaxElapsedSeconds', $MaxElapsedSeconds) }
        $out = & $PowershellExe -NoProfile -ExecutionPolicy Bypass -File $Script @scriptArgs 2>&1
        $listArgs = if (Test-Path -LiteralPath $argLog) { [System.IO.File]::ReadAllText($argLog) } else { '' }
        $checksCalls = if (Test-Path -LiteralPath $checksLog) { @([System.IO.File]::ReadAllLines($checksLog) | Where-Object { $_ }).Count } else { 0 }
        return @{ Out = ($out | Out-String); Code = $LASTEXITCODE; ListArgs = $listArgs; ChecksCalls = $checksCalls }
    } finally {
        $ErrorActionPreference = $prevEap
        $env:PATH = $prevPath
        $env:GITHUB_REPOSITORY = $prevGithubRepo
        Remove-Item Env:\GH_FAKE_ACCOUNT, Env:\GH_FAKE_PR_LIST_JSON, Env:\GH_FAKE_PR_CHECKS_JSON, Env:\GH_FAKE_ARG_LOG, Env:\GH_FAKE_CHECKS_LOG -ErrorAction SilentlyContinue
        Remove-Item Env:\GH_FAKE_PR_LIST_FAIL, Env:\GH_FAKE_PR_CHECKS_FAIL -ErrorAction SilentlyContinue
    }
}

function New-CheckedJson {
    param([int]$MinutesAgo = 30)
    $ts = (Get-Date).ToUniversalTime().AddMinutes(-$MinutesAgo).ToString('yyyy-MM-ddTHH:mm:ssZ')
    return "[{`"name`":`"lint-en-tests`",`"bucket`":`"pass`",`"state`":`"SUCCESS`",`"completedAt`":`"$ts`"}]"
}
$GreenSettled = New-CheckedJson -MinutesAgo 30
$GreenFresh   = New-CheckedJson -MinutesAgo 1

function New-PrJson {
    param([int]$Number, [string]$Branch, [string]$Title = 'ok', [string[]]$Labels = @('bug'), [string]$Draft = 'false')
    $labelJson = (@($Labels | ForEach-Object { "{`"name`":`"$_`"}" }) -join ',')
    return "{`"number`":$Number,`"headRefName`":`"$Branch`",`"title`":`"$Title`",`"isDraft`":$Draft,`"isCrossRepository`":false,`"labels`":[$labelJson]}"
}

# PR #2515's shape: unarmed, carrying only 'bug'. The control characters are untrusted data.
$UntrustedBranch = "fix/2515-x$([char]0x1b)[2J"
$UntrustedTitle  = "golive block$([char]0x07)bell"
$UnarmedJson = '[' + (New-PrJson -Number 2515 -Branch $UntrustedBranch -Title $UntrustedTitle) + ']'
$ArmedJson   = '[' + (New-PrJson -Number 88 -Branch 'docs/88-x' -Labels @('merge-when-green')) + ']'
$DraftJson   = '[' + (New-PrJson -Number 89 -Branch 'docs/89-x' -Draft 'true') + ']'
$HostileBranch = 'fix/601`x`;$(y)'
$QuotingJson = '[' + (New-PrJson -Number 601 -Branch $HostileBranch) + ',' + (New-PrJson -Number 602 -Branch 'fix/602-safe') + ']'
$SeveralJson = '[' + ((701..703 | ForEach-Object { New-PrJson -Number $_ -Branch "docs/$_-x" }) -join ',') + ']'

$fake = "$fakeBin;$prevPath"

try {
    Write-Host ''
    Write-Host 'check-unshipped-pr.ps1 -- [SKIP] paths, each exit 0' -ForegroundColor Cyan

    $t = New-Tree -Label 'no-gh'
    $r = Invoke-Check -Dir $t -Path $emptyBin
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[SKIP\]' -and $r.Out -match 'gh is not installed') 'gh not on PATH -- [SKIP], exit 0'

    $t = New-Tree -Label 'no-auth'
    $r = Invoke-Check -Dir $t -Path $fake -Account ''
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[SKIP\]' -and $r.Out -match 'no active account') 'gh logged out -- [SKIP], exit 0'

    $t = New-Tree -Label 'no-repo'
    $r = Invoke-Check -Dir $t -Path $fake -Account 'tester' -Repo ''
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[SKIP\]' -and $r.Out -match 'repo name unresolvable') 'no repo name -- [SKIP], exit 0'

    $t = New-Tree -Label 'list-fails'
    $r = Invoke-Check -Dir $t -Path $fake -Account 'tester' -Repo 'fake/repo' -PrListFail
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[SKIP\]' -and $r.Out -match 'could not be read') 'the list read fails -- [SKIP], exit 0'

    Write-Host ''
    Write-Host 'check-unshipped-pr.ps1 -- the author filter, and no workflow-file gate' -ForegroundColor Cyan

    # NO merge-on-green.yml HERE ON PURPOSE: unlike check-stranded-sweep.ps1 this check must run without
    # a sweep, because a repo with no sweep is one of the two places this hole exists.
    $t = New-Tree -Label 'none'
    $r = Invoke-Check -Dir $t -Path $fake -Account 'tester' -Repo 'fake/repo' -PrListJson '[]'
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[OK\]' -and $r.Out -match 'nothing can be left unshipped') `
        'no open pull request by this account -- [OK], exit 0, and it ran without a merge-on-green.yml'
    Assert-True ($r.ListArgs -match '--author tester(\s|$)') 'the list read filters on the ACTIVE gh account by name (--author tester), never @me'
    Assert-True ($r.ListArgs -match '--state open') 'and reads open pull requests only'

    Write-Host ''
    Write-Host 'check-unshipped-pr.ps1 -- [UNSHIPPED], the case #2525 measured' -ForegroundColor Cyan

    $t = New-Tree -Label 'unshipped' -WithFlow
    $r = Invoke-Check -Dir $t -Path $fake -Account 'tester' -Repo 'fake/repo' -PrListJson $UnarmedJson -PrChecksJson $GreenSettled
    Assert-True ($r.Code -eq 0) 'a finding still exits 0'
    Assert-True ($r.Out -match '\[UNSHIPPED\]') 'unarmed + green + settled, with a sweep present -- [UNSHIPPED]'
    Assert-True ($r.Out -match '#2515') 'it names the pull request'
    Assert-True ($r.Out -match 'green for 30 minute\(s\)') 'and how long it has been green'
    Assert-True ($r.Out -match 'git checkout' -and $r.Out -match 'ship-pr\.ps1') 'and prints the resume: a checkout, then a bare ship-pr run'
    Assert-True ($r.Out -match 'ship-pr -NoMerge') 'and names the other reading -- held back on purpose -- rather than claiming a dead ship'
    Assert-True ($r.Out -notmatch [regex]::Escape([string][char]0x1b)) 'the ESC in the branch name never reaches printed output'
    Assert-True ($r.Out -notmatch [regex]::Escape([string][char]0x07)) 'nor the BEL in the title'
    Assert-True ($r.Out -match [regex]::Escape('fix/2515-x?[2J')) 'the branch prints scrubbed to ?, not silently dropped'

    $t = New-Tree -Label 'unshipped-nosweep'
    $r = Invoke-Check -Dir $t -Path $fake -Account 'tester' -Repo 'fake/repo' -PrListJson $ArmedJson -PrChecksJson $GreenSettled
    Assert-True ($r.Out -match '\[UNSHIPPED\]' -and $r.Out -match '#88') 'armed, but NO sweep in this repo -- the label is inert, so [UNSHIPPED]'

    Write-Host ''
    Write-Host 'check-unshipped-pr.ps1 -- what it leaves alone' -ForegroundColor Cyan

    $t = New-Tree -Label 'armed-sweep' -WithFlow
    $r = Invoke-Check -Dir $t -Path $fake -Account 'tester' -Repo 'fake/repo' -PrListJson $ArmedJson -PrChecksJson $GreenSettled
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[OK\]' -and $r.Out -notmatch '\[UNSHIPPED\]') 'armed, with a sweep present -- [OK]; the sweep or check-stranded-sweep owns it'
    Assert-Equal 0 $r.ChecksCalls 'and its required checks are never even read -- the cheap disqualifier spends no network call'

    $t = New-Tree -Label 'draft'
    $r = Invoke-Check -Dir $t -Path $fake -Account 'tester' -Repo 'fake/repo' -PrListJson $DraftJson -PrChecksJson $GreenSettled
    Assert-True ($r.Out -match '\[OK\]' -and $r.Out -notmatch '\[UNSHIPPED\]') 'a draft -- [OK]'
    Assert-Equal 0 $r.ChecksCalls 'and no checks read for it either'

    $t = New-Tree -Label 'fresh'
    $r = Invoke-Check -Dir $t -Path $fake -Account 'tester' -Repo 'fake/repo' -PrListJson $UnarmedJson -PrChecksJson $GreenFresh
    Assert-True ($r.Out -match '\[OK\]' -and $r.Out -notmatch '\[UNSHIPPED\]') 'green for one minute -- [OK]; a live ship-pr may still be merging it'

    Write-Host ''
    Write-Host 'check-unshipped-pr.ps1 -- the checkout line never carries a shell metacharacter raw (#1594)' -ForegroundColor Cyan

    $t = New-Tree -Label 'quoting'
    $r = Invoke-Check -Dir $t -Path $fake -Account 'tester' -Repo 'fake/repo' -PrListJson $QuotingJson -PrChecksJson $GreenSettled
    Assert-True ($r.Out -notmatch [regex]::Escape('git checkout fix/601')) 'the hostile branch never reaches the checkout line raw'
    Assert-True ($r.Out -match [regex]::Escape('git checkout <branch>')) 'the placeholder prints instead'
    Assert-True ($r.Out -match [regex]::Escape('git checkout fix/602-safe')) 'an ordinary branch still round-trips unchanged'

    Write-Host ''
    Write-Host 'check-unshipped-pr.ps1 -- honest [INCOMPLETE], never a silent [OK]' -ForegroundColor Cyan

    $t = New-Tree -Label 'checks-fail'
    $r = Invoke-Check -Dir $t -Path $fake -Account 'tester' -Repo 'fake/repo' -PrListJson $UnarmedJson -PrChecksFail
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[INCOMPLETE\]' -and $r.Out -match 'judged 0 of 1') 'a failed required-check read -- [INCOMPLETE], judged 0 of 1, exit 0'

    $t = New-Tree -Label 'budget'
    $r = Invoke-Check -Dir $t -Path $fake -Account 'tester' -Repo 'fake/repo' -PrListJson $SeveralJson -PrChecksJson $GreenSettled -MaxElapsedSeconds 0
    Assert-True ($r.Code -eq 0 -and $r.Out -match '\[INCOMPLETE\]' -and $r.Out -match 'judged 0 of 3' -and $r.Out -notmatch '\[OK\]') `
        'a zero-second budget -- [INCOMPLETE], judged 0 of 3, never [OK]'
} finally {
    $env:PATH = $prevPath
    $env:GITHUB_REPOSITORY = $prevGithubRepo
}

# --- the hook (always exit 0, no gh involved) -------------------------------------------------------
Write-Host ''
Write-Host 'unshipped-pr-sessioncheck.ps1 -- forwards the check verbatim, exits 0 regardless' -ForegroundColor Cyan

function New-StubCheck {
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
    $hookArgs = @('-CheckScriptOverride', $CheckScriptOverride)
    if ($Dir) { $hookArgs += @('-ConsumerPathOverride', $Dir) }
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Hook @hookArgs 2>&1
        return @{ Out = ($out | Out-String); Code = $LASTEXITCODE }
    } finally { $ErrorActionPreference = $prevEap }
}

$hookFixture = New-Tree -Label 'hook-stubs'

$r = Invoke-Hook -CheckScriptOverride (New-StubCheck -Dir $hookFixture -Name 'skip' -Body '[SKIP] gh is not installed' -ExitCode 0) -Dir $hookFixture
Assert-True ($r.Code -eq 0 -and $r.Out -notmatch 'unshipped-pr-sessioncheck:') '[SKIP] -- the hook stays silent, exit 0'

$r = Invoke-Hook -CheckScriptOverride (New-StubCheck -Dir $hookFixture -Name 'ok' -Body '[OK] no open pull request authored by this account' -ExitCode 0) -Dir $hookFixture
Assert-True ($r.Code -eq 0 -and $r.Out -notmatch 'unshipped-pr-sessioncheck:') '[OK] -- silent too, exit 0'

$unshippedStub = New-StubCheck -Dir $hookFixture -Name 'unshipped' -ExitCode 0 -Body @'
[UNSHIPPED] 1 open pull request(s) by this account are green and settled, and nothing is going to merge them:
  #2515 (fix/2515-x), green for 150 minute(s)
    git checkout fix/2515-x
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/release/ship-pr.ps1
'@
$r = Invoke-Hook -CheckScriptOverride $unshippedStub -Dir $hookFixture
Assert-True ($r.Code -eq 0 -and $r.Out -match 'unshipped-pr-sessioncheck:' -and $r.Out -match '\[UNSHIPPED\]') '[UNSHIPPED] -- forwarded under the hook''s headline, exit 0'
Assert-True ($r.Out -match '#2515' -and $r.Out -match 'git checkout fix/2515-x' -and $r.Out -match 'ship-pr\.ps1') 'every line forwarded verbatim, resume command included'

$r = Invoke-Hook -CheckScriptOverride (New-StubCheck -Dir $hookFixture -Name 'incomplete' -ExitCode 0 -Body '[INCOMPLETE] judged 1 of 3 open pull request(s); 2 not checked') -Dir $hookFixture
Assert-True ($r.Code -eq 0 -and $r.Out -match 'unshipped-pr-sessioncheck:' -and $r.Out -match 'judged 1 of 3') '[INCOMPLETE] -- forwarded, not silent'

# A MARKER INSIDE A TITLE DOES NOT COUNT (#2142): only a line the check WROTE starting with it does.
$r = Invoke-Hook -CheckScriptOverride (New-StubCheck -Dir $hookFixture -Name 'titled' -ExitCode 0 -Body '[OK] 1 open pull request(s) by this account -- title mentions [UNSHIPPED]') -Dir $hookFixture
Assert-True ($r.Out -notmatch 'unshipped-pr-sessioncheck:') 'a marker appearing mid-line in data does not trip the hook'

$r = Invoke-Hook -CheckScriptOverride (New-StubCheck -Dir $hookFixture -Name 'crash' -Body '' -ExitCode 3) -Dir $hookFixture
Assert-True ($r.Code -eq 0 -and $r.Out -match 'could not complete \(exit 3\)') 'a non-zero check exit -- reported, still exit 0'

$missing = Join-Path ([System.IO.Path]::GetTempPath()) "no-such-check-$PID-$([guid]::NewGuid().ToString('n')).ps1"
$r = Invoke-Hook -CheckScriptOverride $missing -Dir $hookFixture
Assert-True ($r.Code -eq 0 -and $r.Out -match 'check script not found -- check skipped') 'check script missing -- a notice, exit 0'

$rawCheck = Get-Content -LiteralPath $Script -Raw
$rawHook  = Get-Content -LiteralPath $Hook -Raw
Assert-True (-not ($rawCheck -cmatch '[^\x00-\x7F]')) 'check-unshipped-pr.ps1 is pure ASCII'
Assert-True (-not ($rawHook -cmatch '[^\x00-\x7F]')) 'unshipped-pr-sessioncheck.ps1 is pure ASCII'

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
