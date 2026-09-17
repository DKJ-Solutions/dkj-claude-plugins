<#
.SYNOPSIS
    The close-out receipt shape, printed at the moment a work chain ends -- so the rule is in front of
    the session that is about to write one, instead of 300 lines back in a persona body.

.DESCRIPTION
    Dot-source this file:

        . (Join-Path $PSScriptRoot '..\lib\closeout-lib.ps1')

    WHY THIS EXISTS (issue #1884, September 11, 2026). Chris's ritual has six steps and step 6 -- the
    close-out -- was the only one with no mechanism behind it. It is also the step that runs LAST,
    when the session is longest and the rule is furthest back in context, and it has now been
    repaired in prose four times and lost four times:

        #849   August 24, 2026   the three permitted shapes (A done / B one decision / C parked)
        --     August 27, 2026   "THE CLOSE-OUT IS A RECEIPT, NOT THE REPORT"
        #1402  September 4, 2026 the filing line bounded to a number and at most a short clause
        #1408  September 4, 2026 the order: duplication filters first, then a ceiling of 2-3 lines

    All four were live, in context, and byte-identical between clone and install cache on the session
    that broke two of them at once with a ~25-line close-out carrying two tables. #1402 named the
    diagnosis correctly a week before this file existed -- "this is not a missing rule. It is a rule
    that keeps losing" -- and the new information in #1884 is only that a fourth sharpening has now
    been tried. That is evidence about the REPAIR STRATEGY, not about the wording, which is why the
    fifth repair is not a fifth paragraph.

    THE PRECEDENT IS THE CLAIM STEP, AND IT IS STATED IN THE SAME PERSONA 250 LINES BELOW: "a rule
    enforced by nothing but memory is one that gets skipped". That principle was acted on for
    claiming -- it became claim-issue.ps1 plus a model-invocable skill -- and step 6 is what was left
    memory-only. This is that same move, one step further down the ritual.

    WHY PRINTING AND NOT MEASURING. The alternative #1884 weighed was a Stop hook reading the
    transcript and reporting the line count after the fact. It is strictly more thorough and it is
    not what this is, for two reasons: it has to parse a transcript shape that differs across the
    harness versions consumers run (#1884 lists that as not investigated), and it reports a close-out
    that has ALREADY been written, where this lands before one is composed. A reminder that arrives
    after the failure is a second report to read, which is the thing being complained about.

    SO THE PLACEMENT IS THE WHOLE MECHANISM: the run's closing lines are typically the last thing in
    context when the close-out is composed. In four of the five callers this is literally the last
    statement; in cut-release.ps1 it sits just above the hand-written-note reminder, deliberately, so
    a reminder about the close-out is not read as the last item on a to-do list. Nothing here refuses
    anything, nothing fails a run, and nothing is measured -- it costs three lines of DarkGray at the
    one moment they are free.

    AND THAT PARAGRAPH TURNED OUT TO BE HALF TRUE, WHICH IS WHY THE TEXT IS A TEMPLATE NOW (inbound
    #2043, September 17, 2026 -- the FIFTH recurrence, and the first with this file already in force).
    The print fired verbatim on the run #2043 complained about, and the session wrote four paragraphs
    anyway.
    The report's own diagnosis was that the print lands ~35 lines from the end of ship-pr, and its
    first proposed repair was to move it last. VERIFIED AND ALREADY TRUE: the call IS ship-pr's last
    statement, with a comment saying so deliberately, and the released 5.3.0 mirror the report measured
    is byte-identical to the source on that block. So the proposal was a no-op and the reason was
    wrong.

    WHAT THE ~35 LINES ACTUALLY WERE: the CHILD processes' output. ship-pr spawns open-pr, the fold and
    verify-resolved-issues, and on the reporting run every one of the parent's own lines appeared
    before every one of theirs -- 'Done: PR #683 shipped' above 'PR created for', which is the reverse
    of the file order. Filed in that report as a secondary observation; it is the primary cause. It did
    not reproduce here (a parent/child probe through this harness interleaved correctly), so WHAT the
    order was is measured and WHY it inverted is not; that half is tracked separately as #2044.

    THE CONSEQUENCE FOR THIS FILE: last in the file does not mean last on the screen, so the receipt
    cannot be built on being the final thing anybody reads. That RETIRES proposal 1 and licenses
    nothing on its own -- and the two arguments must not be run together, because a template printed
    in a buried position is exactly as buried as prose was. Said plainly, so nobody inherits the
    overclaim: THIS CHANGE DOES NOT REPAIR THE ORDERING, and it is not offered as doing so.

    WHAT THE TEMPLATE STANDS ON IS #2043's OWN SECOND ARGUMENT, which is independent of where the line
    lands: a shape that is DESCRIBED has to be composed, and a shape that is HANDED OVER has to be
    filled. That is the whole of it. Whether blanks also read better in the middle of a dump is
    plausible and UNMEASURED, so it is not a reason here. The three parts are unchanged; only their
    delivery is. Placement stays as it is, because it is right and costs nothing -- it is simply no
    longer load-bearing.

    IT OBEYS ITS OWN CEILING IN THE BASE CASE, deliberately. A reminder about brevity that runs ten
    lines teaches the opposite of what it says, and would be the fifth prose repair wearing a
    script's clothes. The bypass clause is the one place it runs to a fourth line, because that fact
    has nowhere else to live -- see Write-CloseOutReceipt's -Bypass.

    AND THEN IT WAS COUNTED, WHICH IS THE ONLY THING NONE OF THE SIX REPAIRS ABOVE HAD EVER DONE
    (inbound #2048, September 17, 2026). That report asked why five repairs each correctly diagnosed
    the previous failure and did not prevent the next, and named that pattern as itself the finding.
    It is, and the mechanism behind it is not subtle: NO REPAIR WAS EVER MEASURED. Each was evaluated
    by waiting to see whether Dave complained again -- a sample of one, weeks later, from whichever
    repo he happened to be in. Judged that way, a repair that did nothing and a repair that halved the
    problem are indistinguishable, and six rounds of that is what the history above actually records.

    THE NUMBER, measured by scripts/maintenance/measure-closeouts.ps1 over 328 recorded sessions on
    this machine, 263 of them ending in a real close-out (one that follows a chain-ending script, i.e.
    exactly where this file prints):

        over the 3-line ceiling   222 / 263   84%
        over 6 lines              146 / 263   56%
        median / mean / p90 / max lines       7 / 8.5 / 16 / 76

    SO THE RULE HAS NEVER BEEN IN FORCE ANYWHERE. Five complaints are five of two hundred and
    twenty-two. That reframes every entry in the table above: they were not guardrails that kept
    slipping, they were advice against an 84% baseline nobody had ever counted -- and the one repo
    that writes the rule is its best performer at 50%, while two consumers sit at 97% and 88%.

    THE REPORT'S LEADING HYPOTHESIS IS ANSWERED, AND IT IS NOT THE CAUSE. #2048 proposed that the
    trigger is VOLUME OF WORK rather than forgetting, and said that if so, no amount of print
    placement touches it. Measured: r(tool calls, close-out lines) = 0.207 over n=263 -- significant
    at that n, and about 4% of the variance. The quartile means are what settle it: the SMALLEST
    quarter of sessions (9-58 tool calls) already averages 5.8 lines against a ceiling of 3. The
    effect is real and removing it entirely would leave the rule broken, so a repair aimed at long
    sessions would have been the sixth correct diagnosis of the wrong thing.

    AND THE MEASURE-IT ROUTE #1884 DECLINED IS NO LONGER THE ROUTE IT DECLINED. That paragraph rejected
    a Stop hook on the ground that it "has to parse a transcript shape that differs across the harness
    versions consumers run". The harness now hands a Stop hook the close-out directly -- the documented
    field is last_assistant_message, and the reference says in so many words that hooks needing the
    final assistant text "should use last_assistant_message on Stop and SubagentStop instead of reading
    the transcript" (code.claude.com/docs/en/hooks). So the objection has expired on its facts rather
    than on its reasoning. Its SECOND objection stands and is now the whole question: a hook that
    merely reports arrives after the close-out is written. Worse than #1884 knew -- a Stop hook exiting
    0 puts plain stdout in the debug log, where neither Dave nor the model reads it -- so the only
    shape that can change anything is one that BLOCKS, and this workflow has never blocked on a
    close-out. That decision is open and is deliberately not taken here.

    NOTHING IN THIS FILE CHANGED FOR #2048, AND THAT IS THE POINT. The finding is about how repairs are
    evaluated, not about what this file prints; a seventh sharpening of the text below would be the
    exact move the measurement says has never once worked. What the investigation added is an
    instrument and a recorded baseline, so the NEXT change here can be shown to have done something.

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script.
    Pure ASCII (repo convention for .ps1).
#>

# ONE CHAIN, ONE RECEIPT -- and the suppression travels in the ENVIRONMENT rather than in a parameter
# (issue #1884, found by the code review on the branch that built this). ship-pr.ps1 is a conductor: it
# spawns open-pr.ps1 and fold-changelog-entry.ps1 as CHILD PROCESSES, each of which reaches its own
# chain ending and printed its own receipt -- so an ordinary successful ship printed the reminder three
# times, twice of them mid-chain, before CI had even started.
#
# WHY NOT A -Quiet SWITCH FORWARDED AT EACH CALL. That is the same class of rule this whole file exists
# to retire: it works only while every future nesting site remembers to forward it, and a rule enforced
# by nothing but memory is one that gets skipped. A child process inherits its parent's environment for
# free, so a conductor declares itself ONCE and every descendant is covered -- including ones nobody has
# written yet. The parameter is kept for a caller that wants to suppress its own single call.
$script:CloseOutSuppressVar = 'DKJ_CLOSEOUT_SUPPRESS'

# AND THE GATE THAT REFUSES ONE (issue #2050). closeout-gate-lib.ps1 carries the band, the marker and
# the verdict; this file's only part in it is dropping the marker at the same moment it prints, so the
# printed shape and the gated turn have exactly ONE trigger between them and no future caller has to
# remember to do both.
#
# GUARDED, on the reasoning gate-lib.ps1 already gives for its own dot-source of THIS file: these libs
# are mirrored into every consumer's plugin cache and arrive by plugin UPDATE rather than by choice, so
# a consumer whose mirror predates the gate lib must not crash on LOAD of the file every chain-ending
# script loads. Without it the receipt still prints and the gate is simply off, which is the same
# direction every other path in the gate fails in.
#
# THE LOAD IS RECORDED RATHER THAN PROBED FOR AFTERWARDS. An inline `Get-Command Write-CloseOutMarker`
# at the call site is exactly the function-table probe #1729 retired, and it would answer the wrong
# question anyway: a consumer whose repo-config happens to define that name would pass the probe while
# this file's own dependency was absent. What the receipt needs to know is whether IT loaded the lib.
$script:CloseOutGateLoaded = $false
$closeoutGateLib = Join-Path $PSScriptRoot 'closeout-gate-lib.ps1'
if (Test-Path -LiteralPath $closeoutGateLib -PathType Leaf) {
    try { . $closeoutGateLib; $script:CloseOutGateLoaded = $true } catch { $script:CloseOutGateLoaded = $false }
}

function Write-CloseOutReceipt {
    <#
    .SYNOPSIS
        Print the three-part close-out shape, with the citation this run already knows.

    .DESCRIPTION
        Called at the end of a chain-ending script. Prints nothing that a reader has to act on -- it
        is a reminder, not a check -- and never touches an exit code.

    .PARAMETER Cite
        Where the detail already lives, in the form a receipt would carry it: 'PR #1885', 'issue
        #1884', 'the branch document'. The point of naming it is that the receipt's middle part is
        the one a session most often replaces with prose, because "where to read it" feels like it
        needs explaining. It does not; it needs a number.

        SINCE #2043 IT IS DROPPED STRAIGHT INTO THE TEMPLATE, unparenthesised, as the one slot that
        arrives already filled -- the caller knows this and the session does not, which is exactly the
        split that decides what a mechanism should carry. Omitted, the slot falls back to a blank
        '<where to read it>' like the other two, so the line is still a template rather than a
        sentence with a hole in it.

    .PARAMETER Bypass
        A gate this run was told to skip ('-SkipTests', '-SkipLint'), so the reminder can say where a
        deliberate bypass belongs. This is #1884's SECOND, smaller finding and the reason it is a
        parameter rather than a fixed sentence: the three permitted shapes have no home for "I
        deviated from a gate", so the failing session disclosed it in the reply -- correctly refusing
        to let the requester learn it later, and with nowhere else to put it. The honest home is the
        PR body, with the receipt carrying a clause. The SCRIPT knows this fact and the persona
        cannot, which is exactly the kind of thing a mechanism should be carrying rather than prose.
        Build it with Get-GateBypassNote rather than by hand.

    .PARAMETER Quiet
        Print nothing. For one call a caller wants silenced; a whole nested chain is covered by
        Push-CloseOutSuppression instead.
    #>
    [CmdletBinding()]
    param(
        [string]$Cite = '',
        [string]$Bypass = '',
        [switch]$Quiet
    )

    if ($Quiet) { return }
    # THE CONDUCTOR HAS ALREADY CLAIMED THIS CHAIN'S RECEIPT, so this run is a link in the middle of
    # one and says nothing. Read from the environment, so it holds across the process boundary that
    # created the problem in the first place.
    if (-not [string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($script:CloseOutSuppressVar))) { return }

    # THE MIDDLE PART IS THE ONE THAT DRIFTS, so it is the one that gets the caller's own answer.
    # It goes into the TEMPLATE as a filled slot, which is the whole of #2043's repair: the other two
    # parts arrive as blanks to complete and this one arrives already answered, because the run knows
    # it and the session would otherwise compose a sentence about it.
    $where = if ([string]::IsNullOrWhiteSpace($Cite)) { '<where to read it>' } else { $Cite.Trim() }

    Write-Host ""
    Write-Host "Close-out: a receipt, not a report. Fill this in -- two or three lines, no more:" -ForegroundColor DarkGray
    Write-Host "  <what happened> -- see $where. [Filed #<n>.] Session can be cleared." -ForegroundColor DarkGray
    Write-Host "  What does not fit is rehoused, not cut: the branch document, the PR body, or an issue the receipt cites by number." -ForegroundColor DarkGray

    # ONLY WHERE THERE IS SOMETHING TO SAY. A run that skipped nothing prints nothing here, so the
    # clause keeps its signal -- the same reasoning every other conditional line in this workflow
    # carries, and the reason this is not folded into the three lines above.
    if (-not [string]::IsNullOrWhiteSpace($Bypass)) {
        Write-Host "  This run skipped $($Bypass.Trim()): a deliberate gate bypass belongs in the PR body, with a clause in the receipt." -ForegroundColor DarkGray
    }

    # THE MARKER, AND IT IS THE LAST THING THIS FUNCTION DOES (issue #2050). It says "a work chain ended
    # in this repo", which is what lets the Stop hook tell a close-out from an ordinary turn -- gating
    # every turn would refuse a mid-work answer or a question to the reader, which would be actively
    # wrong. Written HERE rather than at each caller for the reason the suppression is an environment
    # variable rather than a switch: a rule enforced by nothing but memory is one that gets skipped.
    #
    # IT SITS BELOW BOTH EARLY RETURNS ON PURPOSE. A -Quiet call and a link in the middle of somebody
    # else's chain print no receipt, and neither is the moment a close-out gets written -- so neither
    # should arm the gate. One chain, one receipt, one marker.
    #
    # Silent and best-effort: an unwritable cache means no gate on this chain, never a chain-ending
    # script that fails over one.
    if ($script:CloseOutGateLoaded) {
        try { $null = Write-CloseOutMarker } catch { }
    }
}

function Get-GateBypassNote {
    <#
    .SYNOPSIS
        The switches this run was told to skip, in the words the operator typed -- '' when none.

    .DESCRIPTION
        ONE COPY, because there were three (the code review on #1884's branch). ship-pr.ps1 had a
        private helper and open-pr.ps1 had the same three lines inline at both of its endings, all of
        them collecting the SAME two switch names for the SAME sentence. Three independent copies of
        one string-building rule is the drift shape this repo has scar tissue from, and the fix is
        the ordinary one: the lib that owns the sentence owns the phrase that goes in it.

        TAKEN AS EXPLICIT BOOLEANS rather than read out of the caller's scope. A function CAN see a
        script-scope $SkipTests by dynamic scoping, and doing that would make this silently
        caller-dependent -- correct in the two scripts that happen to name their switches that way,
        and quietly wrong in the next one that does not.
    #>
    [CmdletBinding()]
    param(
        [bool]$SkipLint = $false,
        [bool]$SkipTests = $false
    )

    $skipped = @()
    if ($SkipLint)  { $skipped += '-SkipLint' }
    if ($SkipTests) { $skipped += '-SkipTests' }
    if ($skipped.Count -eq 0) { return '' }
    return ($skipped -join ' and ')
}

function Push-CloseOutSuppression {
    <#
    .SYNOPSIS
        Declare this process the conductor of the chain: descendants print no receipt.

    .DESCRIPTION
        Set before spawning a child that is itself a chain-ending script, and cleared with
        Pop-CloseOutSuppression once it returns. The conductor prints the one receipt at its own
        ending, which is the only place in the chain where "the session can be cleared" is a fact
        rather than a guess.
    #>
    [CmdletBinding()]
    param()
    [Environment]::SetEnvironmentVariable($script:CloseOutSuppressVar, '1')
}

function Pop-CloseOutSuppression {
    <#
    .SYNOPSIS
        Undo Push-CloseOutSuppression, so this process's own receipt still prints.

    .DESCRIPTION
        UNCONDITIONAL, not a restore of a saved value. A conductor that was ITSELF spawned under
        suppression is a case that does not arise -- nothing in this workflow nests three deep -- and
        if it ever did, the safe failure is one receipt too many rather than a chain that prints
        none, which is the state #1884 was filed about.
    #>
    [CmdletBinding()]
    param()
    [Environment]::SetEnvironmentVariable($script:CloseOutSuppressVar, $null)
}

function Suspend-CloseOutSuppression {
    <#
    .SYNOPSIS
        Step a NESTED RUN out of the chain's suppression, reporting what it was so it can be put back.

    .DESCRIPTION
        THE PAIR ABOVE IS NOT THIS PAIR, and that is why this one exists (issue #1910). Push/Pop are a
        conductor declaring itself: unconditional in both directions, because a conductor knows it is
        the top of its chain. This pair is for a run that is UNDER a conductor and has to spawn
        children that are not part of the chain at all -- a gate running the test suites is the
        measured case. It has to leave the suppression exactly as it found it, which Pop cannot do:
        Pop clears, so a run that used it would un-mute the conductor's own remaining children.

        WHY A NESTED RUN NEEDS THIS AT ALL. The suppression travels in the ENVIRONMENT precisely so
        that every descendant inherits it without anyone forwarding a switch -- see the note above
        $script:CloseOutSuppressVar. That is exactly right for the descendants #1884 was about, which
        are chain-ending scripts, and exactly wrong for descendants that are not: they inherit a flag
        about a chain they are not in. Measured September 13, 2026 -- ship-pr suppressed around its
        open-pr child, open-pr's test gate spawned scripts\tests\*.tests.ps1, and closeout-lib's own
        suite read the inherited flag, got nothing back from Write-CloseOutReceipt, and crashed on
        `$lines[0]`. The gate that failed was only ever the local one: a CI runner has no conductor
        above it, so the suites there stayed green and the two gates disagreed.

        RETURNS A BOOL rather than writing a saved value into script scope: the caller holds it across
        its own try/finally, so two nested suspensions cannot overwrite one another's saved state.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    $wasActive = -not [string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($script:CloseOutSuppressVar))
    [Environment]::SetEnvironmentVariable($script:CloseOutSuppressVar, $null)
    return $wasActive
}

function Restore-CloseOutSuppression {
    <#
    .SYNOPSIS
        Put back what Suspend-CloseOutSuppression found, so the conductor's own chain is unaffected.

    .PARAMETER WasActive
        The value Suspend-CloseOutSuppression returned. Mandatory and not defaulted: a restore that
        guessed would silently pick one of the two failures this pair exists to avoid -- a chain that
        prints three receipts, or one that prints none.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][bool]$WasActive)
    if ($WasActive) { [Environment]::SetEnvironmentVariable($script:CloseOutSuppressVar, '1') }
    else            { [Environment]::SetEnvironmentVariable($script:CloseOutSuppressVar, $null) }
}
