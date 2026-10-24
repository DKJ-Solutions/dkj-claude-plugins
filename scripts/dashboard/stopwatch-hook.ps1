<#
.SYNOPSIS
    The Claude Code hook behind the Stopwatch (#3323): start a run when a prompt begins with `stopwatch:`, stop it
    when Claude is back on the trunk, clean, with HEAD moved since the start.

.DESCRIPTION
    Wired up in .claude/settings.json as a UserPromptSubmit hook (-Hook Prompt) and a Stop hook (-Hook Stop):

        powershell -NoProfile -ExecutionPolicy Bypass -File "scripts/dashboard/stopwatch-hook.ps1" -Hook Prompt

    THE MARKER IS THE ONLY WAY A RUN STARTS: the Prompt hook reads the UserPromptSubmit JSON from stdin (only parses
    its `prompt` field, never prints it) and a prompt whose first line begins with `stopwatch:` starts an Auto run
    labelled with the rest of that line (Get-StopwatchPromptMarker, which reads a pasted prompt past its
    `<pasted_content>` wrapper, #3336), discarding a run still going. The page is
    read-only.

    The rules are Invoke-StopwatchHookEvent's in scripts/lib/stopwatch-lib.ps1 (pure, tested by
    scripts/tests/stopwatch.tests.ps1); this script only gathers what they need (the store, the checkout's
    branch, cleanliness and HEAD) and writes the store back when the decision changed it.

    IT ALWAYS EXITS 0, PRINTS NOTHING AND NEVER BLOCKS. A UserPromptSubmit hook's stdout is injected into the
    session's context and a Stop hook that fails or prints can hold a turn open, so every error is swallowed:
    a timing aid must never cost the owner a turn. There is no network and no gh call in this process, only local
    git: a Stop that ended a run starts scripts/dashboard/stopwatch-sync.ps1 as a process of its own to share it
    (#3349) and does not wait for it. Git is asked only when a decision needs it (an unmarked Prompt, or a Stop with no Auto run going, never shells out). A store that does not read is left alone, as everywhere (Read-StopwatchStore).

    The store is outside the tree (Get-StopwatchStorePath), so a hook writing it dirties nothing. The hub only
    reads it. A store holding a run that does not parse is copied to a .bak beside it before the write drops it.

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
    # The UserPromptSubmit payload is JSON on stdin with the prompt in `prompt`. It is only parsed, never printed.
    # It is read first, and a payload that does not contain the marker anywhere ends the hook before the lib is
    # even loaded: nearly every prompt is unmarked, so that is the cheap path.
    $prompt = ''
    if ($Hook -eq 'Prompt') {
        $raw = ''
        if ([Console]::IsInputRedirected) {
            $reader = New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding($false)))
            $raw = $reader.ReadToEnd()
        }
        if ($raw -notmatch 'stopwatch:') { exit 0 }
    }
    $root = if ($RepoRoot) { $RepoRoot } else { (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path }
    . (Join-Path $root 'scripts\lib\stopwatch-lib.ps1')
    if (-not $StorePath) { $StorePath = Get-StopwatchStorePath }
    $store = Read-StopwatchStore -Path $StorePath
    if ($store.Error) { exit 0 }
    $running = @($store.Runs | Where-Object { -not $_.End }) | Select-Object -Last 1
    if ($Hook -eq 'Prompt' -and $raw.Trim()) { try { $prompt = [string]($raw | ConvertFrom-Json).prompt } catch { $prompt = '' } }
    # Nothing to decide, so no git: a Prompt needs the marker; a Stop an Auto run going.
    if ($Hook -eq 'Prompt' -and $null -eq (Get-StopwatchPromptMarker -Prompt $prompt)) { exit 0 }
    if ($Hook -eq 'Stop' -and (-not $running -or -not $running.Auto)) { exit 0 }

    $trunk = 'main'
    $cfg = Join-Path $root 'scripts\repo-config.ps1'
    if (Test-Path -LiteralPath $cfg -PathType Leaf) {
        try { . (Join-Path $root 'scripts\lib\command-probe-lib.ps1'); . $cfg *> $null; if (Test-FunctionDefined 'Get-TrunkBranchName') { $t = [string](Get-TrunkBranchName); if ($t.Trim()) { $trunk = $t.Trim() } } } catch { }
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
    # The commits since the run's start (#3400), only when HEAD moved: the run stops on one made during it, and a
    # release run on its notes commit. A log git refuses leaves $commits $null, which keeps the plain HEAD test.
    $commits = $null
    if ($Hook -eq 'Stop' -and $head -and $running.StartHead -and $head -cne $running.StartHead) {
        $out = @(git -C $root log -n 500 --format='%ct %s' "$($running.StartHead)..$head" 2>$null)
        if ($LASTEXITCODE -eq 0) { $commits = @(ConvertFrom-StopwatchCommitLog -Lines $out) }
    }
    $ErrorActionPreference = 'Stop'
    $r = Invoke-StopwatchHookEvent -Hook $Hook -Runs $store.Runs -Now ([datetime]::UtcNow) -Branch $branch -Clean $clean -Head $head -Trunk $trunk -Prompt $prompt -Commits $commits
    if ($r.Changed) {
        if ($store.Skipped) { Copy-Item -LiteralPath $StorePath -Destination "$StorePath.bak" -Force -ErrorAction SilentlyContinue }
        Save-StopwatchStore -Path $StorePath -Runs $r.Runs
        # A run that ended is shared with the other machines (#3349), in a process of its own so the turn never
        # waits on the network. Not when the tests pass a store of their own: a test must never push.
        if ($Hook -eq 'Stop' -and -not $PSBoundParameters.ContainsKey('StorePath')) {
            . (Join-Path $root 'scripts\lib\stopwatch-sync-lib.ps1')
            [void](Start-StopwatchSync -RepoRoot $root)
        }
    }
} catch { }
exit 0
