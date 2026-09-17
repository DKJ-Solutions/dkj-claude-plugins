<#
.SYNOPSIS
    Stop hook of the contributing plugin: refuse a close-out that runs past this repo's band, once per
    work chain -- so step 6 of the ritual is enforced rather than advised.

.DESCRIPTION
    WHY A HOOK THAT BLOCKS (issue #2050, September 17, 2026). Six repairs to the close-out are on the
    record and all six were advice; #2048's instrument then measured the baseline none of them had ever
    been argued against -- 84% of close-outs over the stated ceiling. The full argument, the band, and
    the verification that #1884's objection to a Stop hook has expired on its facts are in
    closeout-gate-lib.ps1's header, which is also where every rule this file applies lives.

    THIS FILE IS DELIBERATELY THIN, the same shape as cycle-autopark.ps1 beside it: it reads the
    payload, claims the marker, resolves the band and prints. The band, the marker's path, the line
    count and the verdict are all the lib's, so the suite can walk every case without a harness.

    THE FOUR THINGS THAT MUST ALL BE TRUE before anything is refused, in the order they are asked:

      1. the harness is not already re-firing after a block (stop_hook_active);
      2. a work chain ENDED this turn -- a marker Write-CloseOutReceipt dropped, claimed here and
         removed as it is read, which is both the scope answer and the loop guard;
      3. this repo has OPTED IN, by answering Get-CloseOutGateBand in scripts/repo-config.ps1;
      4. the close-out is over that band.

    THE ORDER IS THE COST ORDER AND ALSO THE CORRECTNESS ORDER. The marker is claimed before the seam
    is read, so an ordinary turn -- the overwhelming majority -- costs one Test-Path and never loads a
    1,000-line repo-config. And claiming it before the decision is what makes the loop impossible: the
    turn this hook blocks fires Stop again, finds no marker, and exits 0. stop_hook_active is checked
    as well and is deliberately not what this rests on -- this repo could not confirm its availability
    across the harness versions consumers run, and a loop guard nobody could verify is not a loop
    guard.

    EVERY OTHER PATH EXITS 0, and that is the half of cycle-autopark's contract that does transfer. A
    missing lib, an unparseable payload, an unreadable repo-config, a repo that never opted in, an
    empty message: each means "no measurement", and no measurement must never mean a stranded turn. It
    blocks on a measured over-run and on nothing else.

    NOTHING IS PRINTED ON THE ALLOWED PATH, not even a healthy line. A Stop hook's plain stdout goes to
    the debug log rather than to anybody who could read it, so a report here would be write-only noise
    -- which is the same finding that settled the exit-2 shape in the first place.

    Read-only with respect to the working tree: it removes its own marker from the per-user session
    cache and touches nothing in any repo.

    Exit codes (Stop contract): 2 = block the turn and send stderr to Claude; 0 = let it end.

    Matcher note: no matcher -- Stop carries none, unlike the SessionStart hooks in this plugin, which
    match "startup|resume|clear|compact" so their report survives a compaction.

    Pure ASCII (repo convention for .ps1): Windows PowerShell 5.1 reads a BOM-less script as ANSI.
    Tested by scripts/tests/closeout-gate.tests.ps1 in the source repo -- change one, run the other.

.PARAMETER LibOverride
    (Optional, for tests) Use this closeout-gate-lib.ps1 path instead of the one beside this hook.

.PARAMETER RepoRootOverride
    (Optional, for tests) Resolve the seam from this tree instead of from CLAUDE_PROJECT_DIR.

.PARAMETER CacheRootOverride
    (Optional, for tests) Claim the marker from this directory instead of the per-user session cache.
#>
param(
    [string]$LibOverride = '',
    [string]$RepoRootOverride = '',
    [string]$CacheRootOverride = ''
)

$ErrorActionPreference = 'Stop'

# READ BEFORE ANYTHING ELSE. The harness writes the payload and closes the handle, so this returns
# immediately; a hook run by hand from a terminal has no redirected stdin and would block on a console
# read, which is why the guard is the same one session-cache-lib's own reader uses.
$raw = ''
try {
    if ([Console]::IsInputRedirected) { $raw = [Console]::In.ReadToEnd() }
} catch { $raw = '' }

try {
    # $PSScriptRoot-relative, so it resolves the same in the source tree, in the plugin mirror and in a
    # consumer's plugin cache -- the rule the sibling hooks state for hook-check-lib.ps1.
    $libPath = if ($LibOverride) { $LibOverride } else { Join-Path $PSScriptRoot '..\scripts\lib\closeout-gate-lib.ps1' }
    # SILENT WHERE THE SIBLING GUARD WARNS, and the difference is which stream reaches somebody. A
    # PreToolUse hook's stderr is delivered even on exit 0, so guard-working-copy can say its guard is
    # off; a Stop hook exiting 0 writes to the debug log, so the same notice here would be a line per
    # turn that nobody ever sees. It is also the failure this whole file is built to fail towards.
    if (-not (Test-Path -LiteralPath $libPath -PathType Leaf)) { exit 0 }
    . $libPath

    $payload = Get-CloseOutGatePayload -Raw $raw

    # 1. ALREADY RE-FIRING. Belt to the marker's braces -- see the header for why it is not the guard.
    if ($payload.StopHookActive) { exit 0 }

    # 2. DID A CHAIN END? Claimed and consumed in one call, before any decision is taken, so the block
    #    this run may be about to issue cannot be issued twice.
    if (-not (Pop-CloseOutMarker -Cwd $payload.Cwd -Root $CacheRootOverride)) { exit 0 }

    # 3. HAS THIS REPO OPTED IN? The seam lives in the repo's own scripts/repo-config.ps1, which is
    #    loaded HERE rather than trusted to be in scope: this is the only participant that can resolve
    #    the project root deliberately, and a band read from whatever happened to be loaded would be a
    #    gate that fires in some chains and not others. CLAUDE_PROJECT_DIR is the session's project,
    #    the payload cwd the fallback -- the same precedence guard-working-copy.ps1 uses.
    $repoRoot = if ($RepoRootOverride) { $RepoRootOverride }
                elseif ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR }
                else { $payload.Cwd }
    if (-not $repoRoot) { exit 0 }

    $configPath = Join-Path $repoRoot 'scripts\repo-config.ps1'
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { exit 0 }
    . $configPath

    $band = Resolve-CloseOutGateBand
    if ($band -le 0) { exit 0 }

    # 4. IS IT OVER? Everything above this line is about whether the question applies; the answer
    #    itself is one pure call, which is what the suite exercises.
    $verdict = Get-CloseOutGateVerdict -Message $payload.LastAssistantMessage -Band $band
    if (-not $verdict.Blocked) { exit 0 }

    [Console]::Error.WriteLine((Get-CloseOutGateRefusal -Verdict $verdict) -join "`n")
    exit 2
} catch {
    # Swallowed on purpose -- see the header's "every other path exits 0". The message is dropped
    # rather than printed for the same reason the missing-lib case is silent: on exit 0 there is no
    # stream from a Stop hook that reaches anybody who could act on it.
    exit 0
}
