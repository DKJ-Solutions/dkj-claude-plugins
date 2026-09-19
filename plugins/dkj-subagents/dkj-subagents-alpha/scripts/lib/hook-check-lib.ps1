<#
.SYNOPSIS
    The two things every SessionStart hook in this family does with its check script, so neither is
    copied per hook: Invoke-CheckScript RUNS it in the hook's own interpreter instead of spawning a
    second powershell.exe for it (issue #1625), and Select-CheckMarkerLine READS its output, counting
    a verdict marker only where the check WROTE it rather than anywhere it appears (issue #2142).

.DESCRIPTION
    Dot-source this file as a $PSScriptRoot-relative sibling, exactly like check-report-lib.ps1 and
    native-capture-lib.ps1 -- it is plugin-carried, not repo-owned, so a consumer answers no seam for
    it and needs no scaffold:

        . (Join-Path $PSScriptRoot '..\scripts\lib\hook-check-lib.ps1')   -- from hooks/*

    WHAT IT REPLACES, AND WHAT THAT COST. Every session check in this family ran its check script the
    same way:

        $out  = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $checkScript @checkArgs)
        $code = $LASTEXITCODE

    The harness already pays one interpreter start-up to run the hook, so the second one is pure
    addition. Measured on Windows PowerShell 5.1, a script whose only line is 'exit 0': 219 ms median
    for the spawn against 6 ms for the in-process call -- and six hooks carried one each.

    THE SAVING IS WALL-CLOCK AND IT IS NOT THE SUM, BECAUSE THE HARNESS RUNS HOOKS IN PARALLEL.
    "Claude Code runs all matching hooks in parallel" (Claude Code hooks guide), so the six spawns
    never sat end to end on the critical path and the ~1.3 s that summing them suggests was never
    real.

    TWO MEASUREMENTS BOUND IT, AND NEITHER IS THE SUM. Six concurrent copies of a SYNTHETIC hook --
    identical work either side, so only the spawn differs -- came out 311-443 ms apart over three
    rounds. That is MORE than one spawn in isolation and far less than six, because six simultaneous
    process creations contend for CPU and disk rather than each costing what one costs. Against that,
    a parallel batch cannot finish before its slowest member, and the slowest of the six real hooks
    (connector) went from 2161 ms to 1856 ms -- so ~305 ms is the floor the real hooks put under it.
    The two agree, which is the only reason either is quoted.

    THE REAL SIX WERE ALSO TIMED IN PARALLEL, AND THAT RUN IS NOT QUOTED ANYWHERE. Its variance was
    +/-2 s against an effect of ~300 ms -- one round of three came out NEGATIVE -- so it cannot
    resolve the thing it was measuring. It is recorded here rather than dropped because the absence
    of a real-hook parallel figure is otherwise the first thing a reader goes looking for.

    Paid on every startup, resume, clear and compact.

    Those measurements are the reason this lib exists at all rather than the issue being closed as an
    accepted cost: #1625 filed the figure as ~875 ms additive on the assumption that hooks run
    sequentially, and settling the parallel question was named there as the thing to do BEFORE
    optimising on the number. Settled, the prize is smaller than filed and still worth a contained
    change.

    THREE TRAPS, WHICH IS WHY THIS IS A LIB AND NOT FOUR LINES COPIED SIX TIMES. Each of them fails
    SILENTLY -- a wrong answer, not a crash -- so a drifted copy would report a clean check rather
    than announce itself:

      1. AN ARRAY SPLATS POSITIONALLY IN-PROCESS. '& powershell -File $s @arr' hands the child a
         command LINE, so '-Skip','-Path','C:\x' binds by name. '& $s @arr' hands a script an
         ARGUMENT LIST, and the same array binds '-Skip' to the first positional parameter. Measured:
         a script with 'param([switch]$Skip,[string]$Path)' called that way reported
         'Skip=False Path=-Skip'. Nothing errors. So this function takes a HASHTABLE and callers pass
         one.
      2. Write-Host DOES NOT REACH THE PIPELINE. In a child process it lands on the child's stdout,
         which the caller captures. In-process it goes to the information stream (6) -- so a plain
         '$out = @(& $s)' captures NOTHING and every line the check wrote leaks straight to the hook's
         own stdout, i.e. unfiltered into the session context. That is the failure that matters most
         here: these hooks exist to forward [ERROR] and hold everything else back, and it would
         forward the lot. '6>&1' is what makes the capture equivalent.
      3. ONE Write-Host CAN CARRY SEVERAL LINES. A child process's stdout arrives already split, so a
         Write-Host of "a", "b" and "c" joined by newlines reached the old callers as three elements.
         Stringifying an InformationRecord gives one element holding two newlines instead, and the
         hooks then indent the block once and line-match it as a unit. Measured on a fixture: 5
         captured lines through the child, 3 in-process, 5 again once split. So the records are split
         on newlines and in-process capture is line-for-line what the spawn produced.

    AND ONE THAT DOES NOT FAIL SILENTLY BUT IS WORTH THE SAME CARE: $LASTEXITCODE IS STALE, NOT
    ABSENT. A '-File' child always leaves an exit code behind. A script called in-process that returns
    without reaching an 'exit' leaves $LASTEXITCODE holding whatever the previous native call put
    there, so a check that ended cleanly could report its predecessor's failure. It is reset before
    the call, which makes "no exit statement" read as 0 -- which is what the child did.

    WHY IN-PROCESS IS SAFE FOR THESE CALLERS, on the two grounds a reviewer asks about:

      - 'exit' DOES NOT TAKE THE HOOK WITH IT. The check scripts call it freely (6 in
        check-unfolded-entry.ps1, 6 in check-git-identity.ps1, 5 in check-consumer-prose.ps1), and
        #1625 reasoned from that to "the obvious fix is not a one-liner". That reasoning holds for
        DOT-SOURCING, which runs in the caller's scope, and for a script BLOCK invoked with '&'.
        It does not hold for a .ps1 FILE invoked with '&': that gets its own scope, its 'exit'
        terminates the script alone, and control returns to the hook with $LASTEXITCODE set.
        Verified before this lib was written, not assumed.
      - SCOPE DOES NOT LEAK EITHER WAY THAT MATTERS. '&' gives the script a child scope, so nothing
        it defines or assigns reaches the hook. It does INHERIT the hook's Set-StrictMode and
        $ErrorActionPreference -- and every check script in this family sets both itself, on its
        first two statements, so the inherited values are overwritten before any of its code runs.
        A future check that does not set them is the one case a caller has to think about.

    STDERR IS NOT MERGED BY DEFAULT, AND -MergeAllStreams IS THE OPT-IN (issue #1641). A '-File'
    child's stderr never reached the SESSION-CHECK callers either -- it went to the hook's own stderr
    -- and merging it for them would put lines the check never meant as findings in front of their
    [ERROR] filter. In-process, a terminating error surfaces as an exception instead, which every one
    of those hooks wraps in a try/catch that reports the check as skipped.

    THAT REASON IS ABOUT A FILTER, AND ONE CALLER HAS NONE. cycle-autopark is a Stop hook that relays
    whatever park-cycle says, verbatim -- it has no [ERROR] filter for a stray line to get in front
    of, and its child was ALREADY captured with '2>&1' on purpose (#1600): a refused push is this
    workflow's earliest signal that a second session is on the same branch, and the sentence naming
    that is written through Write-Error. So the default's reason does not apply to it, which is what
    makes this a switch rather than a second function: everything else here -- the hashtable splat,
    the newline split, the $LASTEXITCODE reset, the return shape -- is identical, and all three traps
    above fail SILENTLY, so a second copy is exactly the drift this lib exists to prevent.

    IT MERGES EVERY STREAM ('*>&1'), NOT ONLY STDERR, and the widening is deliberate: the point of
    that capture is that no future line of the callee's can be lost to the stream it happened to
    choose. Order across streams is preserved, which is why this is one redirect and not several
    buckets read afterwards.

    PARTIAL OUTPUT, AND WHY -OutputTo EXISTS (also #1641). A child process had already PRINTED its
    early lines before it died; in-process, a check that throws halfway leaves the caller with no
    return value at all, so those lines are gone. For the six session checks that is the right answer
    -- a crashed check should not have half its output forwarded past their [ERROR] filter -- and it
    is why this function still lets the exception propagate rather than swallowing it. For a caller
    that RELAYS, the lines a check managed to write before falling over are the diagnosis. -OutputTo
    hands such a caller a list that is appended to as the lines stream past, readable from its own
    catch. Nothing changes for a caller that omits it, and the throw contract above is untouched
    either way.

    NOT A REPLACEMENT FOR Invoke-NativeCapture. That lib bounds a child process with a timeout,
    which is the right tool when the callee may HANG -- a hook's try/catch cannot save it from a
    blocking call. This function has no timeout and cannot have a useful one: an in-process call
    cannot be abandoned from the thread that is making it. Nothing regresses, because the six calls
    it replaces were unbounded spawns with no timeout either; the harness's own per-hook timeout in
    hooks.json remains the backstop for both. A check that grows a network call of its own belongs
    behind Invoke-NativeCapture, not here.

    Pure ASCII, per this repo's script-layer convention.
#>

function Invoke-CheckScript {
    <#
    .SYNOPSIS
        Run a check script in this interpreter and return its output lines and its exit code.

    .DESCRIPTION
        Returns a hashtable, deliberately the same two-field shape Invoke-NativeCapture returns so a
        caller can be moved between the two without re-reading its own result handling:

            Output    string[] -- the check's lines, split as the child's stdout was split
            ExitCode  int      -- the check's exit code, 0 when it returned without exiting

        Throws nothing of its own. A terminating error inside the check propagates to the caller,
        which in every current caller is a hook whose try/catch reports the check as skipped.

    .PARAMETER Path
        The check script. Resolved and existence-checked by the CALLER -- every hook here already
        does that in order to print its own "check script not found" line, and duplicating the test
        would mean two different messages for one state.

    .PARAMETER Arguments
        The check's parameters as a HASHTABLE, splatted by name. Never an array: see trap 1 in this
        file's header. Omit for a check that takes none.

    .PARAMETER MergeAllStreams
        Capture EVERY stream the callee writes to -- error, warning, verbose and debug alongside
        Write-Host and the pipeline -- instead of Write-Host and the pipeline alone. For a caller that
        relays its callee verbatim rather than filtering it; see the header for why the default runs
        the other way and which caller needs this.

    .PARAMETER OutputTo
        A list this function appends each captured line to AS IT IS PRODUCED, so a caller can still
        read what the check managed to say when the check then THROWS -- at which point there is no
        return value to read. Optional, and nothing changes for a caller that omits it: the returned
        Output holds the same lines. See "PARTIAL OUTPUT" in this file's header.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [hashtable]$Arguments = @{},
        [switch]$MergeAllStreams,
        [System.Collections.Generic.List[string]]$OutputTo = $null
    )

    # Reset, so "the check returned without an exit statement" reads as 0 rather than as whatever the
    # last native call in this hook left behind. See the header.
    $global:LASTEXITCODE = 0

    # TWO STATEMENTS, NOT '$collected = if (...) { $OutputTo } else { ... }'. A block's output goes
    # through the pipeline, which UNROLLS a collection -- and an empty List unrolls to nothing, so that
    # spelling assigns $null and every Add() below fails on a null reference. Silent in the shape that
    # matters: the check still runs, and the caller gets an empty report. Measured while writing this.
    $collected = $OutputTo
    if ($null -eq $collected) { $collected = New-Object System.Collections.Generic.List[string] }

    # 6>&1 captures Write-Host (trap 2); *>&1 additionally captures error, warning, verbose and debug
    # for a caller that relays rather than filters. The split makes one multi-line record into the
    # several lines the spawn produced (trap 3); @Arguments splats a hashtable by name (trap 1).
    #
    # TWO REDIRECTS, NOT ONE COMPOSED AT RUNTIME: a redirection operator is parsed, so it cannot come
    # from a variable, and the alternative -- building the call as a string for Invoke-Expression --
    # would hand this lib's own callee path to the parser. Two literal pipelines is the cheap answer.
    #
    # APPENDED INSIDE THE PIPELINE, not assigned from it, which is what makes $OutputTo work at all: a
    # throw halfway leaves an ASSIGNMENT unmade -- the variable is never set and every line already
    # produced is gone -- while lines added as they stream past are already in the list. Measured both
    # ways: 0 lines recovered from the assignment, 2 from the list, on a check that printed twice and
    # then threw.
    if ($MergeAllStreams) {
        & $Path @Arguments *>&1 | ForEach-Object { foreach ($l in ([string]$_ -split "`r?`n")) { $collected.Add($l) } }
    } else {
        & $Path @Arguments 6>&1 | ForEach-Object { foreach ($l in ([string]$_ -split "`r?`n")) { $collected.Add($l) } }
    }

    return @{
        Output   = @($collected)
        ExitCode = [int]$LASTEXITCODE
    }
}

function Select-CheckMarkerLine {
    <#
    .SYNOPSIS
        Select the lines of a check's output that CARRY a verdict marker, rather than the lines that
        merely contain one (issue #2142).

    .DESCRIPTION
        Every session check in this family decides what to forward into the session context by
        matching a marker over the check's whole output, and every one of them wrote that match
        unanchored:

            $warned = @($out | Where-Object { $_ -cmatch '\[WARN\]' })

        A marker is a PREFIX in every line any check here emits -- at column 0, or behind the
        indentation of a continuation. The unanchored form cannot tell a marker the check WROTE from
        one that arrived inside a value the check is REPORTING, and those values come out of the
        tree: an '@'-import target and the path of the file importing it (check-always-on-budget), a
        workflow filename off a consumer's directory listing (check-connectors), a line of the
        consumer's own prose (check-consumer-prose). So a document able to put the characters
        '[WARN]' on the always-on path had its own line forwarded to every session start under the
        hook's indentation, and '[ERROR]' did more than add a line: it made the hook print its
        over-the-limit headline and the WHOLE report on a run whose verdict was '[OK]'.

        NOT A NEW HOLE, AND THE SANITIZERS ARE NOT REPLACED BY THIS. Format-SafePathToken and
        Format-SafeProseToken in check-report-lib.ps1 already strip square brackets out of exactly
        such values, for exactly this reason, and they remain the first line: they also strip the
        control characters this function cannot see, and they act where the value enters the line.
        What was missing is the other end -- a display filter that reads its own marker out of
        reported data is the shape that goes wrong later, when somebody adds a field to a report and
        does not know a sanitizer was load-bearing for it.

        ONE DEFINITION, BECAUSE THE RULE WAS THE SAME IN TWENTY-SIX PLACES. Eight hooks across two
        plugins selected on markers, each with its own hand-written '\[...\]' escape, and one block
        (connector-sessioncheck's engine branch) had already been anchored on its own -- which is the
        drift this lib exists to prevent. Markers are passed as LITERALS ('[ERROR]'), escaped here, so
        a call site cannot get the escaping subtly wrong either: read as a regex, '[ERROR]' is a
        character class matching one of E/R/O, which selects nearly every line and still looks right.

        ONE CALL SITE DELIBERATELY DOES NOT USE THIS, and it is not an oversight to tidy away.
        connector-sessioncheck's engine branch runs BEFORE this lib is dot-sourced, because that
        dot-source sits inside the branch that has a source checkout and moving it up was measured to
        take out three of that hook's engine-branch test cases. So that block writes the anchor out by
        hand and says so at the line. Same shape as asana-mirror.ps1's standalone copy of the
        foreign-text strip: a file that cannot reach the lib carries the rule, and the lib stays the
        place the rule is argued.

        ANCHORED TO '^\s*', NOT TO '^'. Continuation and roll-up lines are legitimately indented, and
        the callers Trim() before printing; the leading whitespace is the check's own layout rather
        than part of the marker.

        AND THAT ANCHOR RESTS ON A CONVENTION NOTHING ENFORCES. It is safe only while every check
        writes its marker as the first token of the line -- measured true across all 17 markers in this
        family at the time this landed, with zero exceptions, which is why the anchor introduced no
        blind spot. A future Write-Host "note: [ERROR] ..." would have its finding SILENTLY DROPPED
        here. No gate holds that convention today; #2150 is the proposal and its measurement.

    .PARAMETER Output
        The check's captured lines -- Invoke-CheckScript's Output field.

    .PARAMETER Marker
        One or more markers, written as they appear ('[ERROR]', '[SCOPE]'). Regex-escaped here. A line
        matches when it carries ANY of them.

    .EXAMPLE
        $refused = Select-CheckMarkerLine -Output $out -Marker '[ERROR]'
    .EXAMPLE
        $signals = Select-CheckMarkerLine -Output $out -Marker '[ERROR]', '[SCOPE]'
    #>
    param(
        [AllowNull()][AllowEmptyCollection()][object[]]$Output = @(),
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string[]]$Marker
    )

    $alternation = (@($Marker) | ForEach-Object { [regex]::Escape($_) }) -join '|'
    $pattern = '^\s*(?:' + $alternation + ')'

    # -cmatch, preserved from every call site this replaces: the markers are upper-case tokens, and a
    # case-insensitive match would count the words "error" and "ok" in a check's own prose.
    return @(@($Output) | Where-Object { $_ -cmatch $pattern })
}
