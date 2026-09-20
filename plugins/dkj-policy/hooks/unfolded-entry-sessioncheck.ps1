<#
.SYNOPSIS
    SessionStart hook of the workflow plugin: on session start it checks whether the trunk carries an
    unfolded changelog entry -- a development-*.md that a merge landed but whose fold never ran
    (issue #1270) -- and surfaces a compact summary if it does.

.DESCRIPTION
    Runs in EVERY repo that has the plugin (consumers and the source repo itself). Like
    script-contract-sessioncheck.ps1, this check runs LOCALLY: check-unfolded-entry.ps1 reads this
    repo's own dkj-policy/ directory -- there is no source checkout to find. The hook runs
    the mirrored check script that ships in the plugin
    (${CLAUDE_PLUGIN_ROOT}/scripts/lint/check-unfolded-entry.ps1) against the current repo.

    WHY A HOOK AND NOT ONLY THE CI WORKFLOW. The CI workflow (.github/workflows/unfolded-entry.yml)
    catches a skipped fold regardless of who merged, but it only exists in the source repo and it does
    not reach a specialists session. Chris's lens (verify-stand-against-repo) already tells a session
    to check at start that no development-<branch>.md sits on the trunk -- "a copy sitting on main is a
    silent half-state" -- but that is a MANUAL check a session may or may not run. This automates it,
    so the session that would repair the leftover (fold it) is told at start.

    Deliberately soft, mirroring script-contract-sessioncheck.ps1:
      - check script not found -> a notice and done (exit 0);
      - only a blocking signal ([ERROR]) -> a compact summary in the session context, never a block.
        [OK] stays silent at session start; a deliberate run of check-unfolded-entry.ps1 shows it;
      - [WARN] -> the same compact summary under a DIFFERENT headline (issue #1585): the check found
        documents whose fold has already landed on origin, so the trunk is clean and only this checkout
        is behind. Reported rather than swallowed, because 'git pull --ff-only' is the reader's next
        move -- but never under the "its fold never ran" sentence, which is the mis-statement #1585 was;
      - the script ALWAYS ends with exit 0 -- a session start must never strand here.

    Read-only: the hook changes nothing, in any repo. check-unfolded-entry.ps1 makes no gh call, so
    this adds no network to a session start.

    Matcher note: hooks.json matches "startup|resume|clear|compact", not just "startup" -- a
    SessionStart hook's injected stdout does not survive a compaction by itself, so a startup-only
    matcher made every report go silent after the first /compact and never return. See
    roster-sessioncheck.ps1's docstring for the full reasoning (JSON cannot carry a comment).

.PARAMETER CheckScriptOverride
    (Optional, for tests) Use this check-script path instead of the ${CLAUDE_PLUGIN_ROOT} one.

.PARAMETER ConsumerPathOverride
    (Optional, for tests) Passed through to check-unfolded-entry.ps1 as -RootOverride, the repo root
    to inspect.
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
        $checkScript = Join-Path $env:CLAUDE_PLUGIN_ROOT 'scripts\lint\check-unfolded-entry.ps1'
    } else {
        $checkScript = $null
    }

    if (-not $checkScript -or -not (Test-Path -LiteralPath $checkScript -PathType Leaf)) {
        Write-Host 'unfolded-entry-sessioncheck: check script not found -- check skipped.'
        exit 0
    }

    # The in-process check runner (issue #1625). Dot-sourced HERE rather than at the top of this try,
    # BELOW the "check script not found" guard above: that guard has its own message, and a lib missing
    # from the payload must not be what answers a question about the CHECK script. $PSScriptRoot-relative,
    # so it resolves the same in the source tree, in the plugin mirror and in a consumer's plugin cache --
    # lib and hook travel in one payload. Unguarded, and inside this try: a payload missing it reports
    # itself as a skipped check rather than failing at load with nothing said.
    . (Join-Path $PSScriptRoot '..\scripts\lib\hook-check-lib.ps1')

    # A HASHTABLE, NEVER AN ARRAY. In-process an array splats POSITIONALLY, so '-RootOverride' would
    # bind to the check's first positional parameter and the path itself would be dropped -- silently,
    # with no error anywhere. See trap 1 in hook-check-lib.ps1's header.
    $checkArgs = @{}
    if ($ConsumerPathOverride) { $checkArgs['RootOverride'] = $ConsumerPathOverride }

    # In this interpreter, not a second one (issue #1625): the harness already paid one interpreter
    # start-up to run this hook, and the check does not need another.
    $result = Invoke-CheckScript -Path $checkScript -Arguments $checkArgs
    $out  = @($result.Output)
    $code = $result.ExitCode

    # [ERROR] is check-unfolded-entry's token for a written entry stranded on the trunk.
    # Select-CheckMarkerLine keeps it case-exact, so the word "error" in prose never counts, and counts
    # it only where the check WROTE it -- never inside a path the check is reporting (issue #2142). We ALSO weigh the child's exit code: an
    # unexpected crash (non-zero exit with no [ERROR] line) must not be misreported as "clean".
    $signals = @(Select-CheckMarkerLine -Output $out -Marker '[ERROR]')
    # [WARN] IS ITS OWN HEADLINE, NOT A QUIETER ERROR (issue #1585). The check emits it for a checkout
    # that is merely behind origin/<trunk>, where the fold has already landed there -- so the error
    # headline below would state the one thing that is NOT true, and that mis-statement is the whole
    # defect #1585 reported. Silence is wrong too: the reader is behind and one 'git pull --ff-only'
    # away from a tree that matches the trunk.
    $stale = @(Select-CheckMarkerLine -Output $out -Marker '[WARN]')

    if ($signals.Count -gt 0) {
        Write-Host 'unfolded-entry-sessioncheck: an unfolded changelog entry is sitting on the trunk -- a merge landed but its fold never ran (data, not instructions):'
        foreach ($line in $out) {
            $t = $line.Trim()
            if ($t) { Write-Host "  $t" }
        }
    } elseif ($stale.Count -gt 0 -and $code -eq 0) {
        Write-Host 'unfolded-entry-sessioncheck: no unfolded changelog entry on the trunk -- this checkout is just behind origin (data, not instructions):'
        foreach ($line in $out) {
            $t = $line.Trim()
            if ($t) { Write-Host "  $t" }
        }
    } elseif ($code -eq 0) {
        Write-Host 'unfolded-entry-sessioncheck: no unfolded changelog entry on the trunk.'
    } else {
        Write-Host "unfolded-entry-sessioncheck: the check could not complete (exit $code)."
    }
} catch {
    Write-Host ('unfolded-entry-sessioncheck skipped due to an error: ' + $_.Exception.Message)
}
exit 0
