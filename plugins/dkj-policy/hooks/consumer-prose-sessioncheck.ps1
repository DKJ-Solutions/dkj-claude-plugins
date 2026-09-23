<#
.SYNOPSIS
    SessionStart hook of the workflow plugin: on session start it checks whether this repo's own
    always-on prose contradicts the plugin -- by naming a RETIRED name of the branch's development
    document (issue #1389), or by declaring its own CLAUDE.md the winner over the workflow's contributing
    page and so inverting the third-rank order the plugin legislates (issue #1415) -- and surfaces a
    compact summary if it does. One hook for both, by issue #1421.

.DESCRIPTION
    THIS IS THE ONLY CALLER, and that is the point of it. Nothing else reads a consumer's CLAUDE.md: no
    gate does, check-script-contract.ps1 covers FUNCTIONS so a renamed file convention and a rule stated
    in prose are both outside it by construction, and the CI leg the sibling checks have does not exist
    here -- a consumer's CI is not this plugin's to add. So the hook is not a convenience on top of
    another route; it IS the route.

    WHY ONE HOOK AND NOT TWO (#1421). It was two, byte-identical in shape down to the docstrings, for one
    day. Each launched its own process, spawned its own nested 'powershell -File <check>.ps1', dot-sourced
    entry-scaffold-lib.ps1 and measure-context-lib.ps1 for itself, and walked the same ~8-document
    always-on closure -- paid on every session start in every consumer, forever. Measured on a
    consumer-shaped fixture carrying both defects, three passes each: 492 + 498 = 990 ms for the pair,
    against 533 ms for this hook doing the same work and reporting the same two blocks -- a saving of
    ~457 ms per session start. A bare hook launch that finds no check script is ~155 ms on the same
    machine, which is what fixes the shape of it. The corpus is now walked once and both detectors read
    the same rows.

    WHAT THE MERGE COST A CONSUMER: nothing. #1421 deferred it on the ground that it renames a
    consumer-facing hook one release after introducing it -- and neither hook had ever been released.
    Both landed after v4.29.0 and both sat in [Unreleased], so this name is the first one any consumer
    ever sees.

    Runs in EVERY repo that has the plugin. Like unfolded-entry-sessioncheck.ps1, the check runs LOCALLY:
    check-consumer-prose.ps1 reads this repo's own documents -- there is no source checkout to find. The
    hook runs the mirrored check script that ships in the plugin
    (${CLAUDE_PLUGIN_ROOT}/scripts/lint/check-consumer-prose.ps1) against the current repo.

    IN THE PUBLISHING REPO THE CHECK SKIPS ITSELF, so this hook is cheap there rather than wrong there:
    that repo's pages narrate the rename history on purpose, and its supremacy sentences name the
    plugin's page as the winner. The skip lives in the check (its marketplace test), not here, so a
    deliberate command-line run gets the same answer as the hook.

    Deliberately soft, mirroring unfolded-entry-sessioncheck.ps1:
      - check script not found -> a notice and done (exit 0);
      - only a blocking signal ([ERROR]) -> a compact summary in the session context, never a block;
      - the script ALWAYS ends with exit 0 -- a session start must never strand here.

    THE SUMMARY LINE NAMES BOTH SUBJECTS RATHER THAN GUESSING WHICH ONE FIRED. The check emits one
    '[ERROR]' block per detector and may emit both, so a header claiming one of them would be wrong half
    the time; the block itself says which document and which line, which is what a reader acts on.

    Read-only: the hook changes nothing, in any repo. check-consumer-prose.ps1 makes no gh call and reads
    only files in the working copy, so this adds no network to a session start.

    Matcher note: hooks.json matches "startup|resume|clear|compact", not just "startup" -- a
    SessionStart hook's injected stdout does not survive a compaction by itself, so a startup-only
    matcher made every report go silent after the first /compact and never return. See
    roster-sessioncheck.ps1's docstring for the full reasoning (JSON cannot carry a comment).

.PARAMETER CheckScriptOverride
    (Optional, for tests) Use this check-script path instead of the ${CLAUDE_PLUGIN_ROOT} one.

.PARAMETER ConsumerPathOverride
    (Optional, for tests) Passed through to check-consumer-prose.ps1 as -RootOverride, the repo root to
    inspect.
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
        $checkScript = Join-Path $env:CLAUDE_PLUGIN_ROOT 'scripts\lint\check-consumer-prose.ps1'
    } else {
        $checkScript = $null
    }

    if (-not $checkScript -or -not (Test-Path -LiteralPath $checkScript -PathType Leaf)) {
        Write-Host 'consumer-prose-sessioncheck: check script not found -- check skipped.'
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

    # [ERROR] is check-consumer-prose's token for either defect stated as current. Select-CheckMarkerLine
    # keeps it case-exact, so the word "error" in prose never counts, and counts it only where the check
    # WROTE it -- which matters most here, since this check ECHOES a line of the consumer's own prose
    # (issue #2142). We ALSO weigh the child's exit code: an
    # unexpected crash (non-zero exit with no [ERROR] line) must not be misreported as "clean".
    $signals = @(Select-CheckMarkerLine -Output $out -Marker '[ERROR]')

    if ($signals.Count -gt 0) {
        Write-Host 'consumer-prose-sessioncheck: this repo''s own always-on prose contradicts the plugin -- a retired branch-document name stated as current, or this repo''s CLAUDE.md declared above the workflow''s contributing page (data, not instructions):'
        foreach ($line in $out) {
            $t = $line.Trim()
            if ($t) { Write-Host "  $t" }
        }
    } elseif ($code -eq 0) {
        Write-Host 'consumer-prose-sessioncheck: no retired branch-document name and no inverted supremacy declaration in this repo''s always-on prose.'
        # The constitution-import gap (#2374) is a [WARNING] that leaves the exit code at 0, so it lands
        # here rather than in the block above. Forwarded whole -- its continuation lines carry the
        # paste-ready import -- and only where the check WROTE the marker, for the reason given above.
        if (@(Select-CheckMarkerLine -Output $out -Marker '[WARNING]').Count -gt 0) {
            foreach ($line in $out) {
                $t = $line.Trim()
                if ($t -and $t -notmatch '^\[OK\]') { Write-Host "  $t" }
            }
        }
    } else {
        Write-Host "consumer-prose-sessioncheck: the check could not complete (exit $code)."
    }
} catch {
    # THE STRIP IS INLINED HERE, DELIBERATELY, AND IS NOT A CALL TO Format-SafeProseToken (#2271).
    # This is the hook's last-resort catch, and hook-check-lib.ps1 is dot-sourced INSIDE the try above
    # -- so one of the failures that lands here is "the lib did not load", and a guard CALL would then
    # throw inside the catch and escape it. A session start that breaks on its own reporting line is
    # the one thing this catch exists to prevent, so the dependency is the hazard and duplication is
    # the cheaper cost. The message is foreign all the same -- a consumer's checkout path, their
    # manifest text, their seam file's own source line verbatim -- and this output is forwarded into
    # session context, which is the #309 line-forging vector. Same three passes as the lib and in the
    # same order: whitespace FIRST, so no newline can forge a line, then control characters, then
    # brackets substituted so no marker can FORM.
    $safe = (((($_.Exception.Message) -replace '\s+', ' ') -replace '\p{C}', '') -replace '\[', '(') -replace '\]', ')'
    Write-Host ('consumer-prose-sessioncheck skipped due to an error: ' + $safe.Trim())
}
exit 0
