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

    IT OBEYS ITS OWN CEILING IN THE BASE CASE, deliberately. A reminder about brevity that runs ten
    lines teaches the opposite of what it says, and would be the fifth prose repair wearing a
    script's clothes. The bypass clause is the one place it runs to a fourth line, because that fact
    has nowhere else to live -- see Write-CloseOutReceipt's -Bypass.

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
        needs explaining. It does not; it needs a number. Omitted, the line falls back to the generic
        wording rather than printing an empty parenthesis.

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
    $where = if ([string]::IsNullOrWhiteSpace($Cite)) { 'where to read it' } else { "where to read it ($($Cite.Trim()))" }

    Write-Host ""
    Write-Host "Close-out: a receipt, not a report." -ForegroundColor DarkGray
    Write-Host "  What happened, $where, and that the session can be cleared -- two or three lines." -ForegroundColor DarkGray
    Write-Host "  Longer than that is rehoused, not cut: the branch document, the PR body, or an issue the receipt cites by number." -ForegroundColor DarkGray

    # ONLY WHERE THERE IS SOMETHING TO SAY. A run that skipped nothing prints nothing here, so the
    # clause keeps its signal -- the same reasoning every other conditional line in this workflow
    # carries, and the reason this is not folded into the three lines above.
    if (-not [string]::IsNullOrWhiteSpace($Bypass)) {
        Write-Host "  This run skipped $($Bypass.Trim()): a deliberate gate bypass belongs in the PR body, with a clause in the receipt." -ForegroundColor DarkGray
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
