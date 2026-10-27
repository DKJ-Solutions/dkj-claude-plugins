<#
.SYNOPSIS
    Regression tests for the trunk fast-forward (issue #3605): Invoke-TrunkFastForward
    (scripts/lib/trunk-sync-lib.ps1), its entry point scripts/task/sync-trunk.ps1, and the SessionStart
    prep hook plugins/dkj-policy/hooks/trunk-sync-sessionprep.ps1.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell and git.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/trunk-sync.tests.ps1

    Every case builds a bare origin, a "session" clone and a "pusher" clone that lands commits on
    origin, so the session clone is genuinely behind. Each safety condition gets a case of its own, and
    each case also asserts what did NOT move -- a skip that quietly moved the trunk anyway is the defect
    this suite exists to catch.

    Fixture paths carry $PID (repo convention). Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Script   = Join-Path $RepoRoot 'scripts\task\sync-trunk.ps1'
$Hook     = Join-Path $RepoRoot 'plugins\dkj-policy\hooks\trunk-sync-sessionprep.ps1'
$Dispatch = Join-Path $RepoRoot 'plugins\dkj-policy\hooks\sessioncheck-dispatch.ps1'
. (Join-Path $RepoRoot 'scripts\lib\native-capture-lib.ps1')
. (Join-Path $RepoRoot 'scripts\lib\trunk-sync-lib.ps1')

$script:pass  = 0
$script:fail  = 0
$script:trees = @()
$Utf8 = New-Object System.Text.UTF8Encoding($false)

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

function Invoke-Git {
    param([string]$Path, [string[]]$GitArgs)
    $r = Invoke-NativeCapture -FilePath 'git' -Arguments (@('-C', $Path, '-c', 'user.name=t', '-c', 'user.email=t@t', '-c', 'commit.gpgsign=false') + $GitArgs)
    if ($r.ExitCode -ne 0) { throw "git $($GitArgs -join ' ') failed in ${Path}: $(@($r.Output) -join ' ')" }
    return @($r.Output)
}

function Get-Head { param([string]$Path) return ((Invoke-Git $Path @('rev-parse', 'HEAD')) -join '').Trim() }

function Add-Commit {
    param([string]$Path, [string]$File, [string]$Text)
    [System.IO.File]::WriteAllText((Join-Path $Path $File), $Text, $Utf8)
    Invoke-Git $Path @('add', '--', $File) | Out-Null
    Invoke-Git $Path @('commit', '--quiet', '-m', "add $File") | Out-Null
}

function New-Fixture {
    # A bare origin with one commit on main, a session clone, and a pusher clone two commits ahead of
    # the session on origin.
    param([string]$Label, [int]$Pushed = 2)
    $base = Join-Path ([System.IO.Path]::GetTempPath()) ("trunk-sync-$PID-$Label-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
    $script:trees += $base
    $origin = Join-Path $base 'origin.git'
    $seed = Join-Path $base 'seed'
    New-Item -ItemType Directory -Path $seed -Force | Out-Null
    Invoke-Git $base @('init', '--quiet', '--bare', '--initial-branch=main', $origin) | Out-Null
    Invoke-Git $seed @('init', '--quiet', '--initial-branch=main') | Out-Null
    Add-Commit $seed 'README.md' 'seed'
    Invoke-Git $seed @('remote', 'add', 'origin', $origin) | Out-Null
    Invoke-Git $seed @('push', '--quiet', 'origin', 'main') | Out-Null
    $session = Join-Path $base 'session'
    Invoke-Git $base @('clone', '--quiet', $origin, $session) | Out-Null
    for ($i = 1; $i -le $Pushed; $i++) { Add-Commit $seed "pushed-$i.md" "p$i" }
    if ($Pushed -gt 0) { Invoke-Git $seed @('push', '--quiet', 'origin', 'main') | Out-Null }
    return [pscustomobject]@{ Base = $base; Origin = $origin; Seed = $seed; Session = $session; OriginHead = (Get-Head $seed) }
}

Write-Host '== trunk-sync ==' -ForegroundColor Cyan

# --- the lib: each outcome, and what did not move -------------------------------------------------
Write-Host ''
Write-Host 'Invoke-TrunkFastForward' -ForegroundColor Cyan

$f = New-Fixture 'synced'
$r = Invoke-TrunkFastForward -RepoRoot $f.Session
Assert-Equal 'synced' $r.Outcome 'a clean trunk merely behind is fast-forwarded'
Assert-Equal 2 $r.Behind 'and it reports how far it moved'
Assert-Equal $f.OriginHead (Get-Head $f.Session) 'and the trunk now IS origin/main'
$r = Invoke-TrunkFastForward -RepoRoot $f.Session
Assert-Equal 'current' $r.Outcome 'a second run has nothing to do'

$f = New-Fixture 'current' -Pushed 0
Assert-Equal 'current' (Invoke-TrunkFastForward -RepoRoot $f.Session).Outcome 'a trunk level with origin is current'

$f = New-Fixture 'dryrun'
$before = Get-Head $f.Session
$r = Invoke-TrunkFastForward -RepoRoot $f.Session -DryRun
Assert-Equal 'would' $r.Outcome '-DryRun reports what it would do'
Assert-Equal $before (Get-Head $f.Session) '-DryRun moves nothing'

$f = New-Fixture 'dirty'
$before = Get-Head $f.Session
[System.IO.File]::WriteAllText((Join-Path $f.Session 'README.md'), 'edited', $Utf8)
$r = Invoke-TrunkFastForward -RepoRoot $f.Session
Assert-Equal 'skipped' $r.Outcome 'an uncommitted change to a tracked file is never fast-forwarded over'
Assert-Equal 2 $r.Behind 'and the skip still says how far behind it is'
Assert-Equal $before (Get-Head $f.Session) 'and the trunk did not move'
Assert-Equal 'edited' ([System.IO.File]::ReadAllText((Join-Path $f.Session 'README.md'))) 'and the edit is untouched'

$f = New-Fixture 'untracked'
[System.IO.File]::WriteAllText((Join-Path $f.Session 'scratch.txt'), 'mine', $Utf8)
$r = Invoke-TrunkFastForward -RepoRoot $f.Session
Assert-Equal 'synced' $r.Outcome 'an untracked file that nothing overwrites does not block the sync'
Assert-True (Test-Path -LiteralPath (Join-Path $f.Session 'scratch.txt')) 'and the untracked file survives'

$f = New-Fixture 'collide'
[System.IO.File]::WriteAllText((Join-Path $f.Session 'pushed-1.md'), 'mine', $Utf8)
$before = Get-Head $f.Session
$r = Invoke-TrunkFastForward -RepoRoot $f.Session
Assert-Equal 'failed' $r.Outcome 'an untracked file the fast-forward would overwrite makes git refuse -- reported as failed'
Assert-Equal $before (Get-Head $f.Session) 'and the trunk did not move'
Assert-Equal 'mine' ([System.IO.File]::ReadAllText((Join-Path $f.Session 'pushed-1.md'))) 'and the untracked file is untouched'

$f = New-Fixture 'diverged'
Add-Commit $f.Session 'local.md' 'local'
$before = Get-Head $f.Session
$r = Invoke-TrunkFastForward -RepoRoot $f.Session
Assert-Equal 'skipped' $r.Outcome 'a trunk with a local commit origin lacks is never merged'
Assert-True ($r.Detail -match 'diverged') 'and the skip names the divergence'
Assert-Equal $before (Get-Head $f.Session) 'and the trunk did not move'

$f = New-Fixture 'branch'
Invoke-Git $f.Session @('checkout', '--quiet', '-b', 'feat/x') | Out-Null
$r = Invoke-TrunkFastForward -RepoRoot $f.Session
Assert-Equal 'skipped' $r.Outcome 'a checkout off its trunk is never touched'
Assert-Equal -1 $r.Behind 'and it is not even fetched for'
$mainHead = ((Invoke-Git $f.Session @('rev-parse', 'refs/heads/main')) -join '').Trim()
Assert-True ($mainHead -ne $f.OriginHead) 'and its local main did not move either'

$f = New-Fixture 'detached'
Invoke-Git $f.Session @('checkout', '--quiet', '--detach') | Out-Null
Assert-Equal 'skipped' (Invoke-TrunkFastForward -RepoRoot $f.Session).Outcome 'a detached HEAD (a rebase, a bisect) is never touched'

$f = New-Fixture 'noorigin'
Invoke-Git $f.Session @('remote', 'remove', 'origin') | Out-Null
$r = Invoke-TrunkFastForward -RepoRoot $f.Session
Assert-Equal 'skipped' $r.Outcome 'a checkout with no origin/<trunk> is skipped'

$f = New-Fixture 'subdir'
$sub = Join-Path $f.Session 'sub'
New-Item -ItemType Directory -Path $sub -Force | Out-Null
Assert-Equal 'skipped' (Invoke-TrunkFastForward -RepoRoot $sub).Outcome 'a folder that is not the root of a checkout is skipped'

$f = New-Fixture 'unreachable'
Invoke-Git $f.Session @('remote', 'set-url', 'origin', (Join-Path $f.Base 'gone.git')) | Out-Null
$r = Invoke-TrunkFastForward -RepoRoot $f.Session
Assert-Equal 'failed' $r.Outcome 'a fetch that fails is a failure, never a clean "current"'
Assert-True ($r.Detail -match 'fetch') 'and it says the fetch is what failed'

# -NoRepoHooks: a post-merge hook in the checkout runs on an ordinary sync and NOT on a hook-free one.
foreach ($case in @(@{ Off = $false; Want = $true; Say = 'an ordinary sync runs the checkout''s own post-merge hook' },
                    @{ Off = $true;  Want = $false; Say = '-NoRepoHooks runs none of the checkout''s own hooks' })) {
    $f = New-Fixture ("hooks-" + $case.Off)
    $hookMarker = Join-Path $f.Base 'post-merge-ran.txt'
    $hookFile = Join-Path $f.Session '.git\hooks\post-merge'
    [System.IO.File]::WriteAllText($hookFile, "#!/bin/sh`necho x > '$($hookMarker.Replace([char]92, [char]47))'`n", $Utf8)
    $r = Invoke-TrunkFastForward -RepoRoot $f.Session -NoRepoHooks:$case.Off
    Assert-Equal 'synced' $r.Outcome "the sync itself succeeds either way ($($case.Off))"
    Assert-Equal $case.Want (Test-Path -LiteralPath $hookMarker) $case.Say
}

Assert-Equal 'a (b) c' (Format-TrunkSyncSafeText "a`n[b]`tc") 'foreign text loses its newlines and brackets before it is forwarded'

# --- sync-trunk.ps1 -------------------------------------------------------------------------------
Write-Host ''
Write-Host 'sync-trunk.ps1' -ForegroundColor Cyan

$f = New-Fixture 'cli'
$out = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $Script -RootOverride $f.Session 2>&1)
Assert-Equal 0 $LASTEXITCODE 'a single-checkout sync exits 0'
Assert-True ((($out -join "`n")) -match 'fast-forwarded') 'and says it fast-forwarded'
Assert-Equal $f.OriginHead (Get-Head $f.Session) 'and the trunk moved'

$f = New-Fixture 'cli-fail'
Invoke-Git $f.Session @('remote', 'set-url', 'origin', (Join-Path $f.Base 'gone.git')) | Out-Null
& powershell -NoProfile -ExecutionPolicy Bypass -File $Script -RootOverride $f.Session *> $null
Assert-Equal 1 $LASTEXITCODE 'a failed sync exits 1'

# -AllCheckouts over a fixture install administration: one to sync, one on a branch, one gone.
$a = New-Fixture 'all-a'
$b = New-Fixture 'all-b'
Invoke-Git $b.Session @('checkout', '--quiet', '-b', 'feat/y') | Out-Null
$homeDir = Join-Path $a.Base 'home'
$pluginsDir = Join-Path $homeDir '.claude\plugins'
New-Item -ItemType Directory -Path $pluginsDir -Force | Out-Null
$records = @{
    'dkj-policy@dkj-claude-plugins' = @(
        @{ scope = 'project'; projectPath = $a.Session },
        @{ scope = 'project'; projectPath = $b.Session },
        @{ scope = 'project'; projectPath = (Join-Path $a.Base 'vanished') }
    )
}
[System.IO.File]::WriteAllText((Join-Path $pluginsDir 'installed_plugins.json'), (@{ plugins = $records } | ConvertTo-Json -Depth 6), $Utf8)
$bBefore = Get-Head $b.Session
$out = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File $Script -AllCheckouts -UserHomeOverride $homeDir 2>&1) -join "`n")
Assert-Equal 0 $LASTEXITCODE '-AllCheckouts exits 0 when nothing failed -- a skip is not a failure'
Assert-Equal $a.OriginHead (Get-Head $a.Session) '-AllCheckouts syncs the clean trunk'
Assert-Equal $bBefore (Get-Head $b.Session) 'and leaves the checkout on a branch alone'
Assert-True ($out -match '1 install record path') 'and counts the vanished folder into one line'
Assert-True ($out -match '1 synced, 0 current, 1 skipped, 0 failed') 'and the summary adds up'

& powershell -NoProfile -ExecutionPolicy Bypass -File $Script -AllCheckouts -RootOverride $a.Session *> $null
Assert-Equal 1 $LASTEXITCODE '-AllCheckouts with -RootOverride is refused'

# --- the prep hook and the dispatcher ---------------------------------------------------------------
Write-Host ''
Write-Host 'trunk-sync-sessionprep.ps1' -ForegroundColor Cyan

$f = New-Fixture 'hook'
$out = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File $Hook -ConsumerPathOverride $f.Session 2>&1) -join "`n")
Assert-Equal 0 $LASTEXITCODE 'the hook exits 0'
Assert-True ($out -match "fast-forwarded 'main' by 2 commit") 'the hook reports the fast-forward'
Assert-Equal $f.OriginHead (Get-Head $f.Session) 'and the trunk moved'
$out = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File $Hook -ConsumerPathOverride $f.Session 2>&1) -join "`n").Trim()
Assert-Equal '' $out 'a current trunk is silent'

$f = New-Fixture 'hook-branch'
Invoke-Git $f.Session @('checkout', '--quiet', '-b', 'feat/z') | Out-Null
$out = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File $Hook -ConsumerPathOverride $f.Session 2>&1) -join "`n").Trim()
Assert-Equal '' $out 'a session on a branch is silent -- the ordinary case'

$f = New-Fixture 'hook-dirty'
[System.IO.File]::WriteAllText((Join-Path $f.Session 'README.md'), 'edited', $Utf8)
$out = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File $Hook -ConsumerPathOverride $f.Session 2>&1) -join "`n")
Assert-True ($out -match '2 commit\(s\) behind origin and was not fast-forwarded') 'a dirty trunk that is behind gets one line saying so'

$f = New-Fixture 'hook-off'
$before = Get-Head $f.Session
$env:DKJ_TRUNK_AUTOSYNC = '0'
try {
    $out = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File $Hook -ConsumerPathOverride $f.Session 2>&1) -join "`n").Trim()
} finally { Remove-Item Env:\DKJ_TRUNK_AUTOSYNC -ErrorAction SilentlyContinue }
Assert-Equal '' $out 'DKJ_TRUNK_AUTOSYNC=0 silences the hook'
Assert-Equal $before (Get-Head $f.Session) 'and moves nothing'

Write-Host ''
Write-Host 'sessioncheck-dispatch.ps1 runs prep steps before the checks' -ForegroundColor Cyan
# A fixture hooks dir: a prep step that writes a marker file, and a check that reports whether the
# marker exists. If the dispatcher ran the prep beside the checks, the check could not rely on it.
$hooksDir = Join-Path $f.Base 'hooks'
New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
$marker = Join-Path $f.Base 'prep-ran.txt'
[System.IO.File]::WriteAllText((Join-Path $hooksDir 'a-sessionprep.ps1'), "Start-Sleep -Milliseconds 300; [System.IO.File]::WriteAllText('$marker', 'x'); Write-Host 'prep: done'", $Utf8)
[System.IO.File]::WriteAllText((Join-Path $hooksDir 'b-sessioncheck.ps1'), "Write-Host ('check: marker=' + (Test-Path -LiteralPath '$marker'))", $Utf8)
$text = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File $Dispatch -HooksDir $hooksDir 2>$null) -join "`n").Trim()
$json = $null
try { $json = $text | ConvertFrom-Json } catch { $json = $null }
$ctx = if ($json) { [string]$json.hookSpecificOutput.additionalContext } else { '' }
Assert-True ($ctx -match 'prep: done') "the prep step's output reaches the session context"
Assert-True ($ctx -match 'check: marker=True') 'and the check saw what the prep step did -- it ran first'
Assert-True ($ctx.IndexOf('prep: done') -lt $ctx.IndexOf('check: marker')) 'and its line comes first in the report'

# --- teardown ---------------------------------------------------------------------------------------
foreach ($t in $script:trees) { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host ''
Write-Host "Result: $($script:pass) passed, $($script:fail) failed." -ForegroundColor $(if ($script:fail -gt 0) { 'Red' } else { 'Green' })
exit $(if ($script:fail -gt 0) { 1 } else { 0 })
