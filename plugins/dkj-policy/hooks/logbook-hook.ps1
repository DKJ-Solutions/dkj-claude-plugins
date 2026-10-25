<#
.SYNOPSIS
    The Claude Code hook behind the Logbook (#3364): start a run at the first prompt of a new session on a clean
    trunk, stop it when a turn ends with Claude back on the trunk, clean.

.DESCRIPTION
    Wired up in this plugin's hooks/hooks.json as a UserPromptSubmit hook (-Hook Prompt) and a Stop hook (-Hook Stop),
    in every repo that runs dkj-policy (#3470; until then in the source repo's .claude/settings.json alone):

        powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/hooks/logbook-hook.ps1" -Hook Prompt

    Both events carry the session's id on stdin as JSON (`session_id`), and UserPromptSubmit its `prompt`; both are
    only parsed, never printed. The rules are Invoke-LogbookHookEvent's in hub/lib/logbook-lib.ps1 (pure, tested
    by scripts/tests/logbook.tests.ps1); this script only gathers what they need (the store, the checkout's branch,
    cleanliness and HEAD, and whether a ship-pr CI wait is live) and writes the store back when the decision changed
    it.

    GIT IS ASKED ONLY WHEN A DECISION NEEDS IT: a Prompt from a session already seen, or a Stop from a session with no
    open run, ends before any git call. That is nearly every event, since only a session's first prompt is new.

    IT ALWAYS EXITS 0, PRINTS NOTHING AND NEVER BLOCKS, for the Stopwatch hook's reason: a UserPromptSubmit hook's
    stdout is injected into the session's context, and a Stop hook that fails or prints can hold a turn open. No
    network, no gh. A store that does not read is left alone (Read-StopwatchStore); one holding a run that does not
    parse is copied to a .bak beside it before the write drops it.

    The store is one per repo (Get-LogbookStorePath), the repo CLAUDE_PROJECT_DIR, else the working directory. One hook
    at a time per store (Get-HubTimingLock), for the Stopwatch hook's reason: a repo that still wires this script itself
    beside the plugin's copy must not log one session twice (#3470).

    -StorePath, -RepoRoot and -ProgressRoot are for the tests; hooks.json passes none of them.

    Pure ASCII (repo convention for .ps1).
#>
[CmdletBinding()]
param(
    [ValidateSet('Prompt', 'Stop')][string]$Hook = 'Prompt',
    [string]$StorePath = '',
    [string]$RepoRoot = '',
    [string]$ProgressRoot = ''
)
$ErrorActionPreference = 'Stop'
try {
    $raw = ''
    if ([Console]::IsInputRedirected) {
        $reader = New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding($false)))
        $raw = $reader.ReadToEnd()
    }
    if (-not $raw.Trim()) { exit 0 }
    $payload = $raw | ConvertFrom-Json
    $session = [string]$payload.session_id
    if ($session -cnotmatch '^[0-9A-Za-z-]{1,64}\z') { exit 0 }

    $root = if ($RepoRoot) { $RepoRoot } elseif ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
    $root = [System.IO.Path]::GetFullPath($root).TrimEnd('\', '/')
    . (Join-Path $PSScriptRoot '..\hub\lib\logbook-lib.ps1')
    if (-not $StorePath) { [void](Move-HubTimingLegacyStore -RepoRoot $root); $StorePath = Get-LogbookStorePath -RepoRoot $root }
    $lock = Get-HubTimingLock -StorePath $StorePath
    $store = Read-StopwatchStore -Path $StorePath
    if ($store.Error) { exit 0 }
    # Nothing to decide, so no git: a Prompt needs a session not seen yet; a Stop an open run of this session.
    if ($Hook -eq 'Prompt' -and @($store.Sessions) -ccontains $session) { exit 0 }
    if ($Hook -eq 'Stop' -and -not @($store.Runs | Where-Object { -not $_.End -and $_.Session -ceq $session }).Count) { exit 0 }

    $trunk = 'main'
    $cfg = Join-Path $root 'scripts\repo-config.ps1'
    if (Test-Path -LiteralPath $cfg -PathType Leaf) {
        try { . (Join-Path $PSScriptRoot '..\scripts\lib\command-probe-lib.ps1'); . $cfg *> $null; if (Test-FunctionDefined 'Get-TrunkBranchName') { $t = [string](Get-TrunkBranchName); if ($t.Trim()) { $trunk = $t.Trim() } } } catch { }
    }
    # Windows PowerShell 5.1 turns a native command's stderr line into a terminating error under 'Stop', so the git
    # calls run under 'Continue' and are judged by their exit code and output (as in stopwatch-hook.ps1).
    $ErrorActionPreference = 'Continue'
    $head = ''; $branch = ''; $clean = $false
    $out = @(git -C $root rev-parse HEAD 2>$null)
    if ($LASTEXITCODE -eq 0 -and $out.Count) { $head = ([string]$out[0]).Trim() }
    $out = @(git -C $root rev-parse --abbrev-ref HEAD 2>$null)
    if ($LASTEXITCODE -eq 0 -and $out.Count) { $branch = ([string]$out[0]).Trim() }
    # Off the trunk the answer is known, so no status. --no-optional-locks: a status run beside Claude's own git must
    # not take the index lock.
    if ($branch -ceq $trunk) {
        $porcelain = @(git -C $root --no-optional-locks status --porcelain 2>$null)
        $clean = ($LASTEXITCODE -eq 0) -and ($porcelain.Count -eq 0)
    }
    $ErrorActionPreference = 'Stop'
    # A ship-pr CI wait still live in this checkout holds the run open (its record: this plugin's scripts/lib/run-progress-lib.ps1).
    $ship = $false
    if ($Hook -eq 'Stop' -and $script:StopwatchStepLogAvailable) {
        $ship = [bool](@(Get-LiveRunProgress -Root $ProgressRoot -Workspace $root | Where-Object { $_.Id -like 'ship-pr-*' }).Count)
    }
    $prompt = if ($Hook -eq 'Prompt') { [string]$payload.prompt } else { '' }
    $r = Invoke-LogbookHookEvent -Hook $Hook -Runs $store.Runs -Sessions $store.Sessions -SessionId $session -Now ([datetime]::UtcNow) `
        -Branch $branch -Clean $clean -Head $head -Trunk $trunk -Prompt $prompt -ShipInFlight $ship
    if ($r.Changed) {
        if ($store.Skipped) { Copy-Item -LiteralPath $StorePath -Destination "$StorePath.bak" -Force -ErrorAction SilentlyContinue }
        Save-StopwatchStore -Path $StorePath -Runs $r.Runs -Sessions $r.Sessions
    }
} catch {
} finally {
    if ($lock) { try { $lock.ReleaseMutex() } catch { }; $lock.Dispose() }
}
exit 0
