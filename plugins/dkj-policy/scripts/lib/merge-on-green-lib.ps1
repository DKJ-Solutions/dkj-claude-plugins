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

        ship-pr.ps1 is the only writer, and it writes this once the pull request is open and before it
        starts waiting on CI (#2393; until then only at the moment its own CI verdict refused, which
        left every other ending -- a process that died mid-watch, a step-3b refusal -- unarmed). So
        the label is not a preference a reviewer sets: it is the record that a session had already
        begun shipping this branch. A pull request kept back for the owner never had ship-pr run on
        it, so it can never carry this.
    #>
    return $script:MergeOnGreenArmLabel
}

function Get-MergeOnGreenSettleMinutes {
    <#
    .SYNOPSIS
        How long every required check must have been green before the sweep may take an armed pull
        request over -- issue #2393.

    .DESCRIPTION
        WHY THERE IS A WINDOW AT ALL. Since #2393 ship-pr arms BEFORE its CI wait, so a live session's
        pull request is armed while that session is still watching. The sweep is woken by CI
        completing -- the same moment that watch returns -- so without a window every ordinary ship
        would be handed to a second ship-pr on the runner while the live one merges it. Step 5c would
        absorb the doubled fold, but the runner would still have been started for nothing, and with a
        standing write token in its workspace.

        TEN MINUTES, AND WHAT IT HAS TO COVER. A live ship merges seconds after green: step 3b's
        staleness read and the step-4 gates are local reads plus a handful of gh calls. A forward lap
        pushes a new head, which starts a new CI run, so the required checks are no longer green and
        the window starts over on the new head -- a lap never runs out this clock. Ten minutes is
        therefore generous on the live side, and on the dead side it costs one extra half-hourly sweep
        at the outside.
    #>
    return 10
}

function Get-RequiredGreenAgeMinutes {
    <#
    .SYNOPSIS
        Minutes since the LAST required check finished, from a `gh pr checks --required --json
        name,bucket,completedAt` payload -- $null where that cannot be read.

    .DESCRIPTION
        THE LAST ONE, because the pull request only became green when the slowest required check
        finished; the earlier ones say nothing about when the watch returned.

        $null ON ANYTHING SHORT OF A CLEAN READ, and the caller refuses on $null. An empty payload, a
        check with no completedAt, one that is still pending (GitHub reports completedAt as the zero
        date there) -- none of them is evidence the settle window has passed.

    .PARAMETER RequiredChecksJson
        The raw payload.

    .PARAMETER Now
        The current time, passed in so this stays pure.

    .OUTPUTS
        [double] or $null.
    #>
    param(
        [string]$RequiredChecksJson,
        [datetime]$Now
    )

    if ([string]::IsNullOrWhiteSpace($RequiredChecksJson)) { return $null }
    try { $parsed = ConvertFrom-Json -InputObject $RequiredChecksJson } catch { return $null }
    $checks = @($parsed | ForEach-Object { $_ })
    if ($checks.Count -eq 0) { return $null }

    $latest = $null
    foreach ($check in $checks) {
        if ($null -eq $check -or -not $check.PSObject.Properties['completedAt']) { return $null }
        $value = $check.completedAt
        $at = [datetime]::MinValue
        if ($value -is [datetime]) {
            # PowerShell 7's ConvertFrom-Json has already parsed the ISO string, keeping its Kind; casting
            # it back to [string] would drop the Z and re-read it as local time.
            $at = $value
        } elseif (-not [datetime]::TryParse([string]$value, [Globalization.CultureInfo]::InvariantCulture,
                [Globalization.DateTimeStyles]::RoundtripKind, [ref]$at)) {
            # RoundtripKind keeps the trailing Z as UTC, so the subtraction below is between two UTC times.
            return $null
        }
        $at = $at.ToUniversalTime()
        if ($at.Year -lt 2000) { return $null }
        if ($null -eq $latest -or $at -gt $latest) { $latest = $at }
    }
    return ($Now.ToUniversalTime() - $latest).TotalMinutes
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

    .PARAMETER GreenAgeMinutes
        Get-RequiredGreenAgeMinutes' answer for THIS pull request. $null -- unreadable, or not passed
        -- refuses, like every other fact this verdict cannot read (#2393).

    .PARAMETER Label
        The arming label; defaults to Get-MergeOnGreenArmLabel.

    .OUTPUTS
        [pscustomobject] Eligible (bool), Reason (string, always set).
    #>
    param(
        $Record,
        $MergeBlockVerdict,
        $GreenAgeMinutes = $null,
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

    # GREEN IS NOT YET ORPHANED (#2393). ship-pr arms before its own wait, so a pull request that has
    # only just gone green is normally being merged by the live session that armed it -- and this sweep
    # was woken by that same CI completion. Get-MergeOnGreenSettleMinutes carries the reasoning.
    $settle = Get-MergeOnGreenSettleMinutes
    # NaN and Infinity compare false against every number, so '-lt' alone would read them as settled.
    if ($null -eq $GreenAgeMinutes -or [double]::IsNaN([double]$GreenAgeMinutes) -or [double]::IsInfinity([double]$GreenAgeMinutes)) {
        return [pscustomobject]@{ Eligible = $false; Reason = 'when the required checks finished could not be read, so it cannot be told from a live ship' }
    }
    if ([double]$GreenAgeMinutes -lt $settle) {
        return [pscustomobject]@{ Eligible = $false; Reason = ("green for {0:N0} minute(s), under the {1}-minute settle window -- a live ship-pr may still be merging it" -f [math]::Floor([double]$GreenAgeMinutes), $settle) }
    }

    return [pscustomobject]@{ Eligible = $true; Reason = "armed, not a draft, mergeable, and every required check has been green on its own head for at least $settle minutes" }
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
