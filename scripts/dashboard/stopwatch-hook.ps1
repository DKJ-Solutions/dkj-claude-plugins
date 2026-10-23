<#
.SYNOPSIS
    The Claude Code hook behind the Stopwatch's armed runs (#3323): start the armed run when a prompt is
    submitted, stop it when Claude is back on the trunk with the work landed.

.DESCRIPTION
    Wired up in .claude/settings.json as a UserPromptSubmit hook (-Hook Prompt) and a Stop hook (-Hook Stop):

        powershell -NoProfile -ExecutionPolicy Bypass -File "scripts/dashboard/stopwatch-hook.ps1" -Hook Prompt

    The rules are Invoke-StopwatchHookEvent's in scripts/lib/stopwatch-lib.ps1 (pure, tested by
    scripts/tests/stopwatch.tests.ps1); this script only gathers what they need (the store, the checkout's
    branch, cleanliness and HEAD) and writes the store back when the decision changed it.

    IT ALWAYS EXITS 0, PRINTS NOTHING AND NEVER BLOCKS. A UserPromptSubmit hook's stdout is injected into the
    session's context and a Stop hook that fails or prints can hold a turn open, so every error is swallowed:
    a timing aid must never cost the owner a turn. There is no network and no gh call, only local git, and git is
    asked only when a decision needs it (a Prompt with nothing armed, or a Stop with no Auto run going, never
    shells out). A store that does not read is left alone, as everywhere (Read-StopwatchStore).

    The store is outside the tree (Get-StopwatchStorePath), so a hook writing it dirties nothing. The hub server
    writes the same file on a button press; the two writes are a read and a rename apart, which is acceptable for
    a human's button against a turn boundary.

    -StorePath and -RepoRoot are for the tests; settings.json passes neither.

    Pure ASCII (repo convention for .ps1).
#>
[CmdletBinding()]
param(
    [ValidateSet('Prompt', 'Stop')][string]$Hook = 'Prompt',
    [string]$StorePath = '',
    [string]$RepoRoot = ''
)
$ErrorActionPreference = 'Stop'
try {
    $root = if ($RepoRoot) { $RepoRoot } else { (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path }
    . (Join-Path $root 'scripts\lib\stopwatch-lib.ps1')
    if (-not $StorePath) { $StorePath = Get-StopwatchStorePath }
    $store = Read-StopwatchStore -Path $StorePath
    if ($store.Error) { exit 0 }
    $running = @($store.Runs | Where-Object { -not $_.End }) | Select-Object -Last 1
    # Nothing to decide, so no git: a Prompt needs an armed label and no run going, a Stop an Auto run going.
    if ($Hook -eq 'Prompt' -and (-not $store.Armed -or $running)) { exit 0 }
    if ($Hook -eq 'Stop' -and (-not $running -or -not $running.Auto)) { exit 0 }

    $trunk = 'main'
    $cfg = Join-Path $root 'scripts\repo-config.ps1'
    if (Test-Path -LiteralPath $cfg -PathType Leaf) {
        try { . $cfg *> $null; if (Get-Command Get-TrunkBranchName -ErrorAction SilentlyContinue) { $t = [string](Get-TrunkBranchName); if ($t.Trim()) { $trunk = $t.Trim() } } } catch { }
    }
    # Windows PowerShell 5.1 turns a native command's stderr line into a terminating error under 'Stop', so the
    # git calls run under 'Continue' and are judged by their exit code and output (Victor, #3323).
    $ErrorActionPreference = 'Continue'
    $head = ''; $branch = ''; $clean = $false
    $out = @(git -C $root rev-parse HEAD 2>$null)
    if ($LASTEXITCODE -eq 0 -and $out.Count) { $head = ([string]$out[0]).Trim() }
    if ($Hook -eq 'Stop') {
        $out = @(git -C $root rev-parse --abbrev-ref HEAD 2>$null)
        if ($LASTEXITCODE -eq 0 -and $out.Count) { $branch = ([string]$out[0]).Trim() }
        # --no-optional-locks: a status run beside Claude's own git must not take the index lock.
        $porcelain = @(git -C $root --no-optional-locks status --porcelain 2>$null)
        $clean = ($LASTEXITCODE -eq 0) -and ($porcelain.Count -eq 0)
    }
    $ErrorActionPreference = 'Stop'
    $r = Invoke-StopwatchHookEvent -Hook $Hook -Runs $store.Runs -Armed $store.Armed -Now ([datetime]::UtcNow) -Branch $branch -Clean $clean -Head $head -Trunk $trunk
    if ($r.Changed) { Save-StopwatchStore -Path $StorePath -Runs $r.Runs -Armed $r.Armed }
} catch { }
exit 0
