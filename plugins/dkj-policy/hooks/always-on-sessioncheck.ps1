<#
.SYNOPSIS
    SessionStart hook of the workflow plugin: prints what this repo's ALWAYS-ON DOCUMENT PATH costs and
    how much room is left under its budget (issue #2037), so the figure is in front of whoever is about
    to add to it.

.DESCRIPTION
    Runs in EVERY repo that has the plugin. Like unfolded-entry-sessioncheck.ps1 this check runs
    LOCALLY -- check-always-on-budget.ps1 reads this repo's own CLAUDE.md and its '@'-import closure,
    with no network and no gh -- via the mirrored check script that ships in the plugin.

    WHY A HOOK AND NOT ONLY THE TWO GATES. The gate in open-pr and the one in CI both fire at the END of
    the work, when the weight is already written and the author is trying to ship. Everything this
    mechanism is for happens EARLIER: a session that knows the path has 900 B of headroom left puts its
    next paragraph in a lens instead of in CLAUDE.md. A number discovered at a red check has already
    cost the writing it was meant to steer.

    ONE LINE ON THE HAPPY PATH, AND THAT IS THE WHOLE DIFFERENCE FROM ITS SIBLINGS. The other session
    checks are silent when clean, correctly: they report a DEFECT, and a clean repo has nothing to say.
    This one reports a BUDGET, and a budget nobody sees until it is breached is the thing #2037 was filed
    about -- measurement that reports only when it is too late does not hold a line either. So the
    headroom is always named, in one line, and the full output only appears when the path is over.

    IT NEVER WRITES. -Record is deliberately not passed: the ratchet's memory is lowered by the LOCAL
    gate in open-pr, inside the branch's own commit, where the change is reviewable. A session-start hook
    that rewrote it would move the baseline on every machine that opened the repo, with nothing in any
    diff to say so.

    Deliberately soft, mirroring its siblings:
      - check script not found -> a notice and done (exit 0);
      - the script ALWAYS ends with exit 0 -- a session start must never strand here, and a budget is
        not a reason to refuse anybody a session.

    Matcher note: hooks.json matches "startup|resume|clear|compact", not just "startup" -- a
    SessionStart hook's injected stdout does not survive a compaction by itself, so a startup-only
    matcher made every report go silent after the first /compact and never return. See
    roster-sessioncheck.ps1's docstring for the full reasoning (JSON cannot carry a comment).

.PARAMETER CheckScriptOverride
    (Optional, for tests) Use this check-script path instead of the ${CLAUDE_PLUGIN_ROOT} one.

.PARAMETER ConsumerPathOverride
    (Optional, for tests) Passed through to check-always-on-budget.ps1 as -RootOverride, the repo root
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
        $checkScript = Join-Path $env:CLAUDE_PLUGIN_ROOT 'scripts\lint\check-always-on-budget.ps1'
    } else {
        $checkScript = $null
    }

    if (-not $checkScript -or -not (Test-Path -LiteralPath $checkScript -PathType Leaf)) {
        Write-Host 'always-on-sessioncheck: check script not found -- check skipped.'
        exit 0
    }

    # The in-process check runner (issue #1625). Dot-sourced HERE rather than at the top of this try,
    # BELOW the "check script not found" guard above: that guard has its own message, and a lib missing
    # from the payload must not be what answers a question about the CHECK script.
    . (Join-Path $PSScriptRoot '..\scripts\lib\hook-check-lib.ps1')

    # A HASHTABLE, NEVER AN ARRAY. In-process an array splats POSITIONALLY, so '-RootOverride' would
    # bind to the check's first positional parameter and the path itself would be dropped -- silently,
    # with no error anywhere. See trap 1 in hook-check-lib.ps1's header.
    $checkArgs = @{}
    if ($ConsumerPathOverride) { $checkArgs['RootOverride'] = $ConsumerPathOverride }

    $result = Invoke-CheckScript -Path $checkScript -Arguments $checkArgs
    $out  = @($result.Output)
    $code = $result.ExitCode

    # THE SUMMARY LINE IS THE CHECK'S OWN, LIFTED RATHER THAN RECOMPOSED. Restating "N B against M B"
    # here would be a second place that sentence is written, free to drift from the one the gate prints
    # at the red check -- which is the exact class this workflow keeps extracting libs to end.
    $headline = @($out | Where-Object { $_ -match 'always-on path:' })
    $refused  = @(Select-CheckMarkerLine -Output $out -Marker '[ERROR]')
    $warned   = @(Select-CheckMarkerLine -Output $out -Marker '[WARN]')

    if ($code -ne 0 -or $refused.Count -gt 0) {
        Write-Host 'always-on-sessioncheck: the always-on document path is over its limit -- every session pays it (data, not instructions):'
        foreach ($line in $out) {
            $t = $line.Trim()
            if ($t) { Write-Host "  $t" }
        }
        exit 0
    }

    if ($headline.Count -gt 0) {
        # The verdict line ([OK] ...) carries the headroom or the "not growing" state; both are worth the
        # one line, and neither is worth the whole report on a session that is nowhere near the limit.
        $verdictLine = @(Select-CheckMarkerLine -Output $out -Marker '[OK]')
        Write-Host "always-on-sessioncheck: $($headline[0].Trim())"
        if ($verdictLine.Count -gt 0) { Write-Host ("  " + $verdictLine[0].Trim()) }
        if ($warned.Count -gt 0) {
            # TWO KINDS OF WARNING REACH HERE, and both belong at a session start. An UNMEASURED
            # document is cost the figure above does NOT contain, so the figure is a floor -- never
            # folded into the happy-path line, because a floor reported as a total is the one wrong
            # answer this whole mechanism exists to stop. A DEAD import (issue #2138) is not about the
            # figure at all: the document is not being loaded by the session reading this line, which
            # is the most consequential thing the check can find and the reason these lines are
            # forwarded verbatim.
            #
            # ONLY THE MARKED LINES TRAVEL. The check's indented continuations are dropped here, so
            # anything a reader must act on has to sit on a [WARN] line -- a constraint the check
            # script's own comment states from the other side, since neither file can see the other.
            foreach ($w in $warned) { Write-Host ("  " + $w.Trim()) }
        }
        exit 0
    }

    Write-Host 'always-on-sessioncheck: no always-on document path to measure here.'
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
    Write-Host ('always-on-sessioncheck skipped due to an error: ' + $safe.Trim())
}
exit 0
