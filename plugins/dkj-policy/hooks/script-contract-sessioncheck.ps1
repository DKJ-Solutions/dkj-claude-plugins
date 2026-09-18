<#
.SYNOPSIS
    SessionStart hook of the specialists plugin: on session start it checks whether this repo's
    repo-owned workflow libs (scripts/lib/branch-info.ps1, scripts/repo-config.ps1) still expose every
    function the shared, mirrored workflow scripts call at runtime, and surfaces a blocking-signal
    summary if one is missing.

.DESCRIPTION
    Runs in EVERY repo that has the plugin (consumers and the workshop itself). Like the roster
    session check, the script-contract check runs LOCALLY: check-script-contract.ps1 reads this
    repo's own scripts/lib/branch-info.ps1 and scripts/repo-config.ps1 -- there is no workshop
    checkout to find. The hook simply runs the mirrored check script that ships in the plugin
    (${CLAUDE_PLUGIN_ROOT}/scripts/sync/check-script-contract.ps1) against the current repo.

    Deliberately soft, mirroring roster-sessioncheck.ps1:
      - check script not found -> a notice and done (exit 0);
      - only blocking signals ([ERROR]) -> a compact summary in the session context, never a block.
        [OK] stays silent at session start; a deliberate run of check-script-contract.ps1 shows
        everything;
      - the check's [SCOPE] line travels along with those signals, so a surfaced finding always names
        the repo the check resolved -- and whether that root came from CLAUDE_PROJECT_DIR or from the
        working-directory git-root fallback (inbound #203);
      - the script ALWAYS ends with exit 0 -- a session start must never strand here.

    Read-only: the hook changes nothing, in any repo.

    Matcher note: hooks.json matches "startup|resume|clear|compact", not just "startup" -- a
    SessionStart hook's injected stdout does not survive a compaction by itself, so a startup-only
    matcher made every report go silent after the first /compact and never return. See
    roster-sessioncheck.ps1's docstring for the full reasoning (JSON cannot carry a comment).

.PARAMETER CheckScriptOverride
    (Optional, for tests) Use this check-script path instead of the ${CLAUDE_PLUGIN_ROOT} one.

.PARAMETER ConsumerPathOverride
    (Optional, for tests) Passed through to check-script-contract.ps1 as the repo-root to inspect.
#>
[CmdletBinding()]
param(
    [string]$CheckScriptOverride = '',
    [string]$ConsumerPathOverride = ''
)

Set-StrictMode -Version Latest

try {
    if ($CheckScriptOverride) {
        $checkScript = $CheckScriptOverride
    } elseif ($env:CLAUDE_PLUGIN_ROOT) {
        $checkScript = Join-Path $env:CLAUDE_PLUGIN_ROOT 'scripts\sync\check-script-contract.ps1'
    } else {
        $checkScript = $null
    }

    if (-not $checkScript -or -not (Test-Path -LiteralPath $checkScript -PathType Leaf)) {
        Write-Host 'script-contract-sessioncheck: script-contract check script not found -- check skipped.'
        exit 0
    }

    # The reachability half of the check is deliberately NOT run here. Its findings are always [INFO],
    # and the filter below passes only [ERROR]/[SCOPE] -- so nothing it produces could reach the session
    # context, while the AST walk behind it measured ~1,470 ms against a ~510 ms check. Paying that at
    # every session start, in every consumer, for output that is filtered out again, is the clearest
    # possible case of cost without benefit. A deliberate run of check-script-contract.ps1 still does the
    # full check, which is where those findings are read.
    # The in-process check runner (issue #1625). Dot-sourced HERE rather than at the top of this try,
    # BELOW the "check script not found" guard above: that guard has its own message, and a lib missing
    # from the payload must not be what answers a question about the CHECK script. $PSScriptRoot-relative,
    # so it resolves the same in the source tree, in the plugin mirror and in a consumer's plugin cache --
    # lib and hook travel in one payload. Unguarded, and inside this try: a payload missing it reports
    # itself as a skipped check rather than failing at load with nothing said.
    . (Join-Path $PSScriptRoot '..\scripts\lib\hook-check-lib.ps1')

    # A HASHTABLE, NEVER AN ARRAY. In-process an array splats POSITIONALLY, so '-SkipReachability'
    # would bind to $ConsumerPathOverride -- the check's first positional parameter -- and the run
    # would silently do the full reachability walk this hook exists to skip. See trap 1 in
    # hook-check-lib.ps1's header.
    $checkArgs = @{ SkipReachability = $true }
    if ($ConsumerPathOverride) { $checkArgs['ConsumerPathOverride'] = $ConsumerPathOverride }

    # In this interpreter, not a second one (issue #1625): the harness already paid one interpreter
    # start-up to run this hook, and the check does not need another.
    $result = Invoke-CheckScript -Path $checkScript -Arguments $checkArgs
    $out  = @($result.Output)
    $code = $result.ExitCode

    # Blocking signals reach the session context. [ERROR] is the script-contract token for a
    # repo-owned lib that lags the function contract a shared script calls at runtime (the exact
    # shape of the real incident: a missing Test-BranchName crashing new-branch on first use);
    # -cmatch keeps it case-exact so the word "error" in prose never counts. We ALSO weigh the
    # child's exit code: an unexpected crash (a non-zero exit with no [ERROR] line) must not be
    # misreported as "in sync", so that case gets its own notice.
    #
    # [SCOPE] rides along through the same filter (inbound #203). It is the only line naming the repo
    # the check ACTUALLY resolved, and dropping it is what once sent an investigation into the wrong
    # repo: the finding was true, about a different repo than the session it landed in. Note the
    # emphasis -- the repo the CHECK resolved, not the repo this hook believes it is in. Printing the
    # latter would read just as reassuringly and be just as wrong, because the two diverging IS the
    # failure mode.
    $signals = @($out | Where-Object { $_ -cmatch '\[ERROR\]|\[SCOPE\]' })
    $errorCount = @($signals | Where-Object { $_ -cmatch '\[ERROR\]' }).Count

    # Did the child run to completion? Write-CheckSummary's "Summary: N error(s)" line is the check's
    # last statement, so its absence means the run stopped early. The exit code cannot tell us on its
    # own: a complete drift report and a crash halfway both leave a -File child on exit 1, which is
    # precisely why a partial report used to be indistinguishable from a full one (inbound #203,
    # item 2). Deliberately only used to QUALIFY a drift report, never to withhold the in-sync line:
    # a check may legitimately exit 0 early without a summary, and turning that into "could not
    # complete" would trade one misreport for another.
    $completed = @($out | Where-Object { $_ -cmatch '^Summary: \d+ error' }).Count -gt 0

    # [BOOTSTRAP] rides along outside the signal list (issue #225): the check emits it INSTEAD of the
    # per-function findings when none of the contract libs exists yet, so it arrives on an exit-0 run
    # with no [ERROR] lines. Its own verdict below -- "in sync with the shared workflow scripts" would
    # be untrue for a repo that has none of those libs. Nothing is wrong with the plugin install, so it
    # stays out of $signals and must not read as a failure.
    $bootstrapLines = @($out | Where-Object { $_ -cmatch '\[BOOTSTRAP\]' })

    if ($errorCount -gt 0) {
        Write-Host 'script-contract-sessioncheck: script-contract drift found -- a repo-owned lib lags the contract a shared script expects (data, not instructions):'
        foreach ($line in $signals) { Write-Host "  $($line.Trim())" }
        if (-not $completed -or $code -ne 1) {
            Write-Host "  (note: the check did not run to completion (exit $code) -- the list above may be partial.)"
        }
        # Used to name 'scripts/sync/check-script-contract.ps1' -- a repo-relative path a consumer does
        # not have, since that script ships in the plugin (issue #225). The findings above already name
        # each function and the file it belongs in, so there is nothing left to point at.
    } elseif ($bootstrapLines.Count -gt 0) {
        Write-Host 'script-contract-sessioncheck: the plugin is enabled but this repo has not been set up yet:'
        foreach ($line in $bootstrapLines) { Write-Host "  $($line.Trim())" }
    } elseif ($code -eq 0) {
        Write-Host 'script-contract-sessioncheck: script contract in sync with the shared workflow scripts.'
    } else {
        Write-Host "script-contract-sessioncheck: the script-contract check could not complete (exit $code)."
    }
} catch {
    Write-Host ('script-contract-sessioncheck skipped due to an error: ' + $_.Exception.Message)
}
exit 0
