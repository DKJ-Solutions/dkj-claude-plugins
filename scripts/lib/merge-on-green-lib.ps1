<#
.SYNOPSIS
    Pure helpers for issue #2319's merge-on-green sweep -- which open pull request, of those a
    shipping session ARMED, a CI runner may hand to ship-pr.ps1 to finish.

.DESCRIPTION
    WHAT THIS FILE IS NOT, AND THE RESTRAINT IS THE WHOLE DESIGN. #2319 asks for a runner that
    merges "only when the required check is green on the exact head and the staleness count is
    zero". The second half of that sentence is ship-pr.ps1's own step 3b, the DEPLOY lock and the
    step-list gate are two more gates the same script already runs, and none of them is re-derived
    here. The runner checks the branch out and runs ship-pr.ps1 -- so what this file decides is
    only whether there is a pull request worth STARTING that script for, never whether the merge
    itself is sound.

    That split is the one ci-merge-skip-lib.ps1 already drew one file over: it answers ship-pr's
    own staleness question a second time, from inside CI, and it does so by calling the identical
    pure functions rather than by writing new ones. Two implementations of one predicate is the
    failure both files are shaped to avoid; here it is avoided outright, by running the script that
    holds the predicate.

    FAIL-CLOSED AT EVERY BRANCH, the same posture as the sibling above. Anything short of a clean
    read answers Eligible=$false. The worst this file can be wrong about is a merge that waits for
    the next sweep -- thirty minutes at the outside -- and the pull request stays exactly as it
    was. It can never be wrong about a merge that should not have happened, because it does not decide one.

    PURE: no git, no gh, no environment. The reads live in scripts/ci/pick-merge-on-green.ps1.
#>

# THE LABEL IS A CONSTANT, NOT A SEAM, AND THAT IS A DECISION RATHER THAN AN OMISSION. Every seam in
# this workflow exists because a consumer legitimately answers it differently -- which trunk, which
# changelog path, which merge method. This one is a handshake between two files that always travel
# together: ship-pr.ps1 writes it and pick-merge-on-green.ps1 reads it. A repo that renamed one half
# would have armed pull requests no sweep can see, and nothing would report it -- a seam would buy a
# choice nobody wants at the price of a silent half-configured state.
$script:MergeOnGreenArmLabel = 'merge-when-green'

function Get-MergeOnGreenArmLabel {
    <#
    .SYNOPSIS
        The label a shipping session sets to say "this merge is owed once CI is green" -- the one
        thing that makes a pull request visible to the sweep.

    .DESCRIPTION
        WHY THERE IS A LABEL AT ALL. CLAUDE.md holds two kinds of pull request back for the owner's
        own word: one with a VISIBLE RESULT that has to be judged by eye, and one that is
        IRREVERSIBLE OR OUTWARD-FACING. A runner that merged every green pull request would merge
        those two as well, which is the one outcome this whole mechanism must not produce.

        ship-pr.ps1 is the only writer, and it writes this at the moment its own CI verdict refuses.
        So the label is not a preference a reviewer sets: it is the record that a session had
        already begun shipping this branch when CI took the decision away from it. A pull request
        kept back for the owner never had ship-pr run on it, so it can never carry this.
    #>
    return $script:MergeOnGreenArmLabel
}

function ConvertFrom-MergeOnGreenListJson {
    <#
    .SYNOPSIS
        The records of one `gh pr list --json ...` payload, ENUMERATED -- one element per pull request,
        under Windows PowerShell 5.1 as under 7.

    .DESCRIPTION
        WHY THIS IS A FUNCTION AND NOT ONE LINE IN THE SCRIPT (#2381). The sweep read the list as
        `@($text | ConvertFrom-Json)`. Under 5.1 -- which is what the runner's `powershell` is --
        ConvertFrom-Json writes a JSON array down the pipeline as ONE Object[] instead of enumerating
        it, so `@(...)` wrapped it: one "record" that was the whole array, with no `number` property.
        The loop skipped it without a word and every sweep reported "0 armed pull request(s), none
        eligible yet" while PR #2345 sat armed and green. It held for ANY number of armed pull requests,
        so under 5.1 the sweep could never pick anything.

        The repair is to take the parse result as a value first and enumerate it explicitly, which
        behaves the same on both editions. It lives here because the lib's suite is what can feed it a
        real one- and multi-element payload; the script's own line was invisible to every test.

    .PARAMETER Json
        The payload text.

    .OUTPUTS
        The records, written to the pipeline one by one -- collect them with @(...). Nothing for an
        empty list. THROWS on text that is not JSON, so the caller keeps its own fail-closed "could
        not be parsed" verdict.
    #>
    param([string]$Json)

    if (-not $Json -or -not $Json.Trim()) { return @() }
    $parsed = ConvertFrom-Json -InputObject $Json
    if ($null -eq $parsed) { return @() }
    # The ForEach-Object is the enumeration 5.1 skips. NO unary comma on the way out: callers collect
    # with @(...), and a comma would hand that one element -- the array -- and re-create the defect.
    return @($parsed | ForEach-Object { $_ })
}

function Test-MergeOnGreenArmed {
    <#
    .SYNOPSIS
        Whether one `gh pr list --json labels` record carries the arming label.

    .DESCRIPTION
        ASKED AGAIN HERE ALTHOUGH THE QUERY ALREADY FILTERED ON IT. `gh pr list --label` does the
        filtering server-side and is reliable; this re-asks it locally because the sweep's whole
        authorisation rests on this one fact, and a filter that silently stopped matching -- a
        renamed label, a gh flag that changed meaning, a payload fetched by some future caller
        without the filter -- would hand every open pull request to a merge. One property read
        against a list already in memory, and it closes the class outright.

    .PARAMETER Record
        A pull request record carrying a `labels` array of objects with a `name`.

    .PARAMETER Label
        The arming label; defaults to Get-MergeOnGreenArmLabel.

    .OUTPUTS
        [bool]
    #>
    param(
        $Record,
        [string]$Label = (Get-MergeOnGreenArmLabel)
    )

    if ($null -eq $Record) { return $false }
    if (-not $Record.PSObject.Properties['labels']) { return $false }
    foreach ($entry in @($Record.labels)) {
        if ($null -eq $entry) { continue }
        $name = ''
        if ($entry.PSObject.Properties['name']) { $name = ([string]$entry.name).Trim() }
        # -ceq, NOT -eq, AND FOR Get-InterruptedShipCandidates' REASON ONE AXIS OVER: PowerShell's own
        # string comparison is case-INSENSITIVE, so `-eq` would arm on 'Merge-When-Green' -- a label
        # this script never wrote. GitHub will not let two labels differ only in case, so a variant
        # spelling is somebody else's label rather than a near-miss of this one, and the safe answer to
        # somebody else's label is no.
        if ($name -and $name -ceq $Label) { return $true }
    }
    return $false
}

function Get-MergeOnGreenPrVerdict {
    <#
    .SYNOPSIS
        Whether one armed pull request is worth handing to ship-pr.ps1 right now -- Eligible plus a
        Reason that is always set.

    .DESCRIPTION
        THE ORDER OF THE TESTS IS THE ORDER OF WHAT THEY COST THE READER, cheapest disqualifier
        first, so the Reason a sweep prints names the thing a person would have noticed first
        themselves.

        MERGEABLE='UNKNOWN' REFUSES, AND THAT IS NOT PESSIMISM. GitHub computes mergeability lazily
        and reports UNKNOWN while it is still doing so, so the state means "ask again", which is
        exactly what a sweep on a half-hourly cadence is for. Treating it as mergeable would
        start ship-pr against a pull request that may be CONFLICTING, and ship-pr would then spend
        its whole CI wait on a branch that can never merge.

        A PENDING REQUIRED CHECK IS NOT A FINDING, and it is by far the commonest answer here: most
        sweeps land while something is still running. It refuses like every other non-pass outcome
        and the Reason says which, so a log line never reads as a defect when it is a wait.

    .PARAMETER Record
        A pull request record from
        `gh pr list --json number,headRefName,isDraft,mergeable,labels,isCrossRepository`.

    .PARAMETER MergeBlockVerdict
        Get-MergeBlockVerdict's own object for THIS pull request, formed from its own
        `gh pr checks --required` payload. Reused rather than re-derived: it is the function
        ship-pr.ps1's step 3 uses to decide whether a green watch is really green, including the
        UnfinishedRequired field inbound #1549 added for exactly that decision. $null refuses.

    .PARAMETER Label
        The arming label; defaults to Get-MergeOnGreenArmLabel.

    .OUTPUTS
        [pscustomobject] Eligible (bool), Reason (string, always set).
    #>
    param(
        $Record,
        $MergeBlockVerdict,
        [string]$Label = (Get-MergeOnGreenArmLabel)
    )

    if ($null -eq $Record) {
        return [pscustomobject]@{ Eligible = $false; Reason = 'no pull request record' }
    }
    if (-not (Test-MergeOnGreenArmed -Record $Record -Label $Label)) {
        return [pscustomobject]@{ Eligible = $false; Reason = "not armed: no '$Label' label" }
    }

    $isDraft = $false
    if ($Record.PSObject.Properties['isDraft']) { $isDraft = [bool]$Record.isDraft }
    if ($isDraft) {
        return [pscustomobject]@{ Eligible = $false; Reason = 'the pull request is a draft' }
    }

    # A PULL REQUEST FROM A FORK IS REFUSED OUTRIGHT, and it is asked here rather than left to fail
    # later. The runner's whole body is `git checkout <headRefName>` in a clone of THIS repository, and
    # a fork's head ref is not a branch here -- so a cross-repository pull request could at best turn
    # the job red on a checkout that was never going to resolve. The real reason is the other one: this
    # repository is public, so anybody may open one, and the sweep's only authorisation is a label. The
    # label is out of a stranger's reach today, but "is the head ref in this repo" is a second, cheaper
    # fact that does not depend on that remaining true.
    $crossRepo = $false
    if ($Record.PSObject.Properties['isCrossRepository']) { $crossRepo = [bool]$Record.isCrossRepository }
    if ($crossRepo) {
        return [pscustomobject]@{ Eligible = $false; Reason = 'the head branch is on a fork -- this runner only ships branches of this repository' }
    }

    $mergeable = ''
    if ($Record.PSObject.Properties['mergeable']) { $mergeable = ([string]$Record.mergeable).Trim().ToUpperInvariant() }
    if ($mergeable -ne 'MERGEABLE') {
        $shown = if ($mergeable) { $mergeable } else { '(unreadable)' }
        return [pscustomobject]@{ Eligible = $false; Reason = "mergeable is '$shown', not 'MERGEABLE'" }
    }

    # THE CHECK VERDICT IS BORROWED WHOLE, NOT REBUILT. Get-MergeBlockVerdict already refuses on an
    # unreadable required-check list -- it cannot tell "this ruleset requires nothing" from "the
    # required checks have not reported yet", and its own header says why refusing is the safe tie-break
    # there. That is the posture a sweep wants unchanged: with nothing named there is no green to wait
    # for, so "merge on green" has no trigger at all and the honest answer is to leave the pull request
    # to a person.
    if ($null -eq $MergeBlockVerdict) {
        return [pscustomobject]@{ Eligible = $false; Reason = 'the required-check state could not be read' }
    }
    if ($MergeBlockVerdict.PSObject.Properties['Blocked'] -and $MergeBlockVerdict.Blocked) {
        $why = ''
        if ($MergeBlockVerdict.PSObject.Properties['Reason']) { $why = [string]$MergeBlockVerdict.Reason }
        if (-not $why) { $why = 'a required check is not green' }
        return [pscustomobject]@{ Eligible = $false; Reason = $why }
    }

    # NOT BLOCKED IS NOT THE SAME AS GREEN, and this is the exact hole inbound #1549 measured on the
    # other caller. A required check that has not REGISTERED yet fails nothing, so Blocked is $false
    # while the certificate this sweep exists to spend does not exist -- ship-pr would then be started
    # only to sit through the whole wait itself. Reading the field rather than the verdict is what
    # #1549 added it for.
    $pending = @()
    if ($MergeBlockVerdict.PSObject.Properties['UnfinishedRequired']) { $pending = @($MergeBlockVerdict.UnfinishedRequired) }
    if ($pending.Count -gt 0) {
        return [pscustomobject]@{ Eligible = $false; Reason = "a required check has not finished: $($pending -join ', ')" }
    }

    return [pscustomobject]@{ Eligible = $true; Reason = 'armed, not a draft, mergeable, and every required check is green on its own head' }
}

function Select-MergeOnGreenCandidate {
    <#
    .SYNOPSIS
        The one pull request a sweep hands over, out of the verdicts it has already formed --
        the eligible one with the LOWEST number, or $null.

    .DESCRIPTION
        ONE PER SWEEP, DELIBERATELY. The runner's whole body is a checkout plus a ship-pr run, and
        ship-pr ends on the trunk having folded; a second pull request in the same job would start
        from a tree that has just moved under it. Nothing is lost by waiting: the merge this sweep
        performs is itself a push to the trunk, which runs CI, whose completion wakes the next
        sweep. The queue drains by construction rather than by looping.

        LOWEST NUMBER RATHER THAN NEWEST, so the order is stable across sweeps and the oldest owed
        merge is never starved by a newer one arriving. It also makes a run reproducible from its
        own log: the same armed set always yields the same pick.

    .PARAMETER Verdicts
        Records carrying at least Number and Eligible -- typically the pull request record with
        Get-MergeOnGreenPrVerdict's own fields merged onto it.

    .OUTPUTS
        The chosen record, or $null when none is eligible.
    #>
    param($Verdicts)

    $eligible = @(@($Verdicts) | Where-Object {
        $_ -and $_.PSObject.Properties['Eligible'] -and $_.Eligible -and $_.PSObject.Properties['Number']
    })
    if ($eligible.Count -eq 0) { return $null }
    return @($eligible | Sort-Object { [int]$_.Number } | Select-Object -First 1)[0]
}
