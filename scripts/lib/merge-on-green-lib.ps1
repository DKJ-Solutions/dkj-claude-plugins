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
        therefore generous on the live side, and on the dead side it costs one extra scheduled sweep
        at the outside -- the calling workflow's own cadence (issue #2487: */30 on the source repo,
        sparser on a metered consumer's template).
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
            # it back to [string] would drop the Z and re-read it as local time. UNTESTED HERE: CI and the
            # suites run Windows PowerShell 5.1 only, which leaves the string, so this arm has never run
            # in this tree. It exists for a consumer invoking the picker under pwsh.
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

function Get-MergeOnGreenExecutedPathHit {
    <#
    .SYNOPSIS
        Why this pull request's diff reaches code the merge-on-green runner executes UNTRUSTED, from the
        branch itself, or '' where it does not -- issue #2338, SHRUNK by #2437.

    .DESCRIPTION
        UNTIL #2437, THIS MATCHED FOUR PREFIXES (scripts/, .github/, .workflow-scripts/,
        plugins/**/scripts/), because the runner ran ship-pr.ps1 -- and everything it dot-sources --
        FROM THE CHECKED-OUT BRANCH, with FOLD_PUSH_TOKEN in that same workspace. #2437 moved the runner
        onto a TRUSTED tree instead: `.github/workflows/merge-on-green.yml` now checks out a copy of the
        trunk beside the branch (both `persist-credentials: false`, the push credential supplied only as
        ephemeral environment config for the one step that pushes) and runs `ship-pr.ps1` -- and every sibling lib it loads via `$PSScriptRoot` -- from THAT tree, never
        from the branch. See that workflow's own header comments for the two-checkout shape and
        ship-pr.ps1's `-TrustedRoot` parameter for what runs where.

        WHAT SURVIVES THE SHRINK, AND WHY IT IS EXACTLY THESE TWO. `ship-pr.ps1` and `open-pr.ps1` still
        read two files from the SHIPPED tree rather than the trusted one -- `scripts/repo-config.ps1` and
        `scripts/lib/branch-info.ps1` -- because they are REPO-OWNED configuration, not portable plugin
        code, and `-TrustedRoot`/`-SeamRoot` repoints exactly those two dot-sources at the trusted tree
        too. So as of #2437 NEITHER file is executed from the branch either -- the sweep never runs a
        PR's own version of `Get-RepoName` or the branch-prefix table. What a PR editing one of them still
        loses is not safety but CURRENCY: the sweep ships under the TRUNK's answer to "what does this repo
        call itself" and "which branch prefixes exist", so a PR that renames the repo or adds a prefix in
        the same breath as it fixes something else has that rename take effect only once IT lands, not
        while it merges. That is a staleness risk worth a session's judgement, not a security one -- which
        is why these two stay on the list while the other three came off it (Sebastian #23's design
        review on #2437: "the rule shrinks to the seam files, not to none").

        NEITHER FILE EXISTS IN THE SOURCE REPO'S OWN SHAPE ONLY -- every consumer running this workflow
        carries its own `scripts/repo-config.ps1` and `scripts/lib/branch-info.ps1`, so the two-name list
        below is not source-repo-specific.

        THE MATCH IS NORMALISED, NOT EXACT. Separators, doubled slashes, a leading './' or '/',
        surrounding whitespace and CASE are all folded before the comparison, because a `git mv` to
        'Scripts/Repo-Config.ps1' is the same file on a case-insensitive filesystem -- and a guard that
        misses a spelling fails open.

        FAIL-CLOSED ON AN INCOMPLETE LIST. `gh pr list --json files` returns at most 100 files, so a
        record whose files fall short of its changedFiles has not shown the whole diff, and one with no
        file list at all has shown none of it. Both refuse: a path this function did not see is not a
        path it cleared.

    .PARAMETER Record
        A pull request record carrying `files` and `changedFiles`.

    .OUTPUTS
        [string] the reason, or '' where the diff touches neither seam file.
    #>
    param($Record)

    if ($null -eq $Record -or -not $Record.PSObject.Properties['files'] -or $null -eq $Record.files) {
        return 'its changed files could not be read'
    }
    $paths = @(@($Record.files) | ForEach-Object { if ($_ -and $_.PSObject.Properties['path']) { [string]$_.path } })
    $total = -1
    if ($Record.PSObject.Properties['changedFiles']) { $total = [int]$Record.changedFiles }
    if ($total -lt 0 -or $paths.Count -lt $total) {
        return "only $($paths.Count) of its changed files could be listed"
    }
    # THE ENUMERATED LIST -- ONLY THESE TWO, since #2437's trusted-tree ship. Both are repo-owned
    # config, never plugin payload, which is why -TrustedRoot/-SeamRoot cannot load them from a trusted
    # tree unconditionally: a repo's OWN answer to Get-RepoName lives only on its own branches.
    $seamFiles = @('scripts/repo-config.ps1', 'scripts/lib/branch-info.ps1')
    foreach ($p in $paths) {
        # Fail closed on every spelling git or a case-insensitive filesystem could deliver for the same
        # file: separators, a leading './' or '/', doubled slashes, surrounding whitespace, and CASE --
        # a `git mv` to 'Scripts/Repo-Config.ps1' is the same seam on Windows and macOS.
        $norm = (($p.Trim() -replace '\\', '/') -replace '/{2,}', '/') -replace '^(\./|/)+', ''
        if ($seamFiles -contains $norm) {
            # A path is chosen by whoever pushed the branch, and this reason is printed into a CI log.
            $shown = $norm -replace '[^\x20-\x7E]', '?'
            return "it changes '$shown', a repo-owned seam this runner ships under the TRUNK's answer for"
        }
    }
    return ''
}

function Get-MergeOnGreenSweepRefusal {
    <#
    .SYNOPSIS
        Why the merge-on-green sweep will NEVER finish this pull request, or '' where it can -- read
        from a `gh pr view --json files,changedFiles` payload, for ship-pr.ps1's arm message (#2436).

    .DESCRIPTION
        THE SAME PREDICATE THE PICKER REFUSES ON, NOT A SECOND ONE. ship-pr arms every pull request and
        used to promise the sweep would finish it if the session died. For a diff the picker refuses on
        the executed-path rule (#2338) it declines it on every sweep, so that promise was false -- measured
        on #2436 at 32 of the last 40 merged PRs, before #2437 shrank the rule to the two repo-owned seam
        files and an incomplete file list -- and the stranded pull request stayed armed, green and silent. This function hands ship-pr exactly
        Get-MergeOnGreenExecutedPathHit's answer, so the sentence ship-pr prints and the verdict the
        sweep reaches cannot drift apart.

        ONLY THE PERMANENT REFUSAL. Every other thing the picker asks -- draft, mergeable, green, the
        settle window -- is a state that changes by itself. This one changes only with a commit, which
        is why it is the one worth saying at arm time.

        FAIL-CLOSED, LIKE THE PICKER: an unreadable or unparseable payload answers with the picker's own
        "could not be read" reason. Promising a sweep this run could not confirm is the defect being
        repaired, so the doubt goes the same way it goes on the runner.

    .PARAMETER FilesJson
        The raw payload text.

    .OUTPUTS
        [string] the reason, or '' where the sweep can ship it.
    #>
    param([string]$FilesJson)

    $record = $null
    if (-not [string]::IsNullOrWhiteSpace($FilesJson)) {
        try { $record = ConvertFrom-Json -InputObject $FilesJson } catch { $record = $null }
    }
    return (Get-MergeOnGreenExecutedPathHit -Record $record)
}

function Test-MergeOnGreenRequiredChecksSettled {
    <#
    .SYNOPSIS
        Is the required-check state readable, not blocked, not pending, and green for at least the
        settle window? -- the one block Get-MergeOnGreenPrVerdict and Get-MergeOnGreenStrandedVerdict
        used to each spell out on their own (Victor, issue #2438), extracted so the two cannot drift.

    .DESCRIPTION
        THE FOUR CHECKS, IN THE SAME ORDER BOTH CALLERS ALREADY RAN THEM: the required-check state is
        readable at all, it is not Blocked, nothing required is still UnfinishedRequired, and the age
        the checks have been green is readable and at least Get-MergeOnGreenSettleMinutes. Neither
        caller's own order changes: Get-MergeOnGreenPrVerdict still asks armed/draft/fork/executed-path/
        mergeable first and only reaches this block after all of them pass, exactly as before.

    .PARAMETER MergeBlockVerdict
        Get-MergeBlockVerdict's own object, from its own `gh pr checks --required` payload. $null reads
        as unreadable.

    .PARAMETER GreenAgeMinutes
        Get-RequiredGreenAgeMinutes' answer. $null, NaN or Infinity reads as unreadable, the same
        fail-closed reading both callers already gave it.

    .OUTPUTS
        [pscustomobject] Ready (bool), Reason (string, set only when Ready is $false -- the exact
        sentence Get-MergeOnGreenPrVerdict printed for this block before the extraction), Settle
        (the minutes value, so a caller composing its own success sentence need not ask a second time).
    #>
    param($MergeBlockVerdict, $GreenAgeMinutes = $null)

    $settle = Get-MergeOnGreenSettleMinutes

    if ($null -eq $MergeBlockVerdict) {
        return [pscustomobject]@{ Ready = $false; Reason = 'the required-check state could not be read'; Settle = $settle }
    }
    if ($MergeBlockVerdict.PSObject.Properties['Blocked'] -and $MergeBlockVerdict.Blocked) {
        $why = ''
        if ($MergeBlockVerdict.PSObject.Properties['Reason']) { $why = [string]$MergeBlockVerdict.Reason }
        if (-not $why) { $why = 'a required check is not green' }
        return [pscustomobject]@{ Ready = $false; Reason = $why; Settle = $settle }
    }

    # NOT BLOCKED IS NOT THE SAME AS GREEN (#1549's hole on the other caller): a required check that has
    # not REGISTERED yet fails nothing, so Blocked is $false while the certificate a sweep exists to
    # spend does not exist yet.
    $pending = @()
    if ($MergeBlockVerdict.PSObject.Properties['UnfinishedRequired']) { $pending = @($MergeBlockVerdict.UnfinishedRequired) }
    if ($pending.Count -gt 0) {
        return [pscustomobject]@{ Ready = $false; Reason = "a required check has not finished: $($pending -join ', ')"; Settle = $settle }
    }

    # GREEN IS NOT YET ORPHANED (#2393). NaN and Infinity compare false against every number, so '-lt'
    # alone would read them as settled.
    if ($null -eq $GreenAgeMinutes -or [double]::IsNaN([double]$GreenAgeMinutes) -or [double]::IsInfinity([double]$GreenAgeMinutes)) {
        return [pscustomobject]@{ Ready = $false; Reason = 'when the required checks finished could not be read, so it cannot be told from a live ship'; Settle = $settle }
    }
    if ([double]$GreenAgeMinutes -lt $settle) {
        return [pscustomobject]@{ Ready = $false; Reason = ("green for {0:N0} minute(s), under the {1}-minute settle window -- a live ship-pr may still be merging it" -f [math]::Floor([double]$GreenAgeMinutes), $settle); Settle = $settle }
    }

    return [pscustomobject]@{ Ready = $true; Reason = ''; Settle = $settle }
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
        exactly what the scheduled sweep is for. Treating it as mergeable would
        start ship-pr against a pull request that may be CONFLICTING, and ship-pr would then spend
        its whole CI wait on a branch that can never merge.

        A PENDING REQUIRED CHECK IS NOT A FINDING, and it is by far the commonest answer here: most
        sweeps land while something is still running. It refuses like every other non-pass outcome
        and the Reason says which, so a log line never reads as a defect when it is a wait.

    .PARAMETER Record
        A pull request record from
        `gh pr list --json number,headRefName,headRefOid,isDraft,mergeable,labels,isCrossRepository,files,changedFiles`.

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

    # A PULL REQUEST EDITING A REPO-OWNED SEAM IS LEFT TO A SESSION -- issue #2338, SHRUNK by #2437. The
    # runner used to check this head out with FOLD_PUSH_TOKEN in the workspace and execute ship-pr.ps1 --
    # and everything it dot-sources -- FROM THAT BRANCH. Since #2437 it runs ship-pr.ps1 from a separate,
    # token-free TRUSTED tree instead (see merge-on-green.yml and ship-pr.ps1's -TrustedRoot), so a PR can
    # no longer buy code execution with a PAT that bypasses the trunk ruleset merely by pushing a branch.
    # What is left is the two REPO-OWNED seams (scripts/repo-config.ps1, scripts/lib/branch-info.ps1),
    # which -TrustedRoot repoints at the trusted tree too rather than executing the branch's own copy --
    # so a PR touching one of them loses only CURRENCY (it ships under the trunk's answer, not its own),
    # never safety. Left here anyway because that staleness is a session's judgement call, not the
    # sweep's: ship-pr from a checkout still ships it, with the PR's own edit in effect.
    #
    # SEE Get-MergeOnGreenExecutedPathHit'S OWN HEADER for why exactly these two files, and Sebastian
    # #23's design review on #2437 for the verdict that kept them enumerated rather than dropping the
    # rule to nothing.
    $executed = Get-MergeOnGreenExecutedPathHit -Record $Record
    if ($executed) {
        return [pscustomobject]@{ Eligible = $false; Reason = "$executed -- ship it from a session" }
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
    #
    # NOT BLOCKED IS NOT THE SAME AS GREEN, and this is the exact hole inbound #1549 measured on the
    # other caller. A required check that has not REGISTERED yet fails nothing, so Blocked is $false
    # while the certificate this sweep exists to spend does not exist -- ship-pr would then be started
    # only to sit through the whole wait itself.
    #
    # GREEN IS NOT YET ORPHANED (#2393). ship-pr arms before its own wait, so a pull request that has
    # only just gone green is normally being merged by the live session that armed it -- and this sweep
    # was woken by that same CI completion.
    #
    # ALL FOUR OF THE ABOVE ARE ONE SHARED BLOCK (Victor, #2438): Test-MergeOnGreenRequiredChecksSettled,
    # reused rather than restated by Get-MergeOnGreenStrandedVerdict too, so the two cannot drift apart.
    $settled = Test-MergeOnGreenRequiredChecksSettled -MergeBlockVerdict $MergeBlockVerdict -GreenAgeMinutes $GreenAgeMinutes
    if (-not $settled.Ready) {
        return [pscustomobject]@{ Eligible = $false; Reason = $settled.Reason }
    }

    return [pscustomobject]@{ Eligible = $true; Reason = "armed, not a draft, touches no code the runner executes, mergeable, and every required check has been green on its own head for at least $($settled.Settle) minutes" }
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

function Get-MergeOnGreenStrandedVerdict {
    <#
    .SYNOPSIS
        Is this armed pull request STRANDED -- ready in every way the sweep can act on, except that its
        diff touches a path the runner executes, so no sweep will EVER take it and only a session
        running ship-pr.ps1 can (issue #2438, split out of #2436's step 2).

    .DESCRIPTION
        WHY THIS IS ITS OWN FUNCTION AND NOT A NEW BRANCH IN Get-MergeOnGreenPrVerdict. That function's
        order is deliberate -- cheapest disqualifier first, so its Reason names what a person would
        notice first -- and Get-MergeOnGreenExecutedPathHit is asked BEFORE mergeable, before the
        required-check state and before the settle window. So an armed pull request that has NOT yet
        gone green also reports the executed-path Reason there, and that function alone cannot say
        whether it would otherwise be ready. Reordering it would answer that, but it would also change
        which Reason every OTHER executed-path pull request reports mid-sweep -- a change to live
        picker behaviour this issue does not ask for, and one the existing suite pins against (several
        assertions there construct a record that is armed and touches an executed path while passing no
        -GreenAgeMinutes at all, and still expect the executed-path Reason back).

        SO THIS ASKS FROM THE OUTSIDE, REUSING RATHER THAN RESTATING. Get-MergeOnGreenExecutedPathHit
        decides whether the path reason applies at all -- the one fact Get-MergeOnGreenPrVerdict cannot
        expose once it has returned early on it. Get-MergeOnGreenPrVerdict itself then confirms that
        executed-path is genuinely the reason THIS pull request is declined right now: not armed, a
        draft or a fork all report a DIFFERENT Reason there, and comparing the verdict's Reason against
        the exact string Get-MergeOnGreenExecutedPathHit composes is what tells the two apart without
        restating the armed/draft/cross-repo checks a second time. Only once that identity holds does
        this read the two facts the verdict never reached for such a record -- whether the required
        checks are green (Get-MergeBlockVerdict's own Blocked/UnfinishedRequired fields) and whether
        that green has stood for the settle window (Get-RequiredGreenAgeMinutes against
        Get-MergeOnGreenSettleMinutes) -- which is exactly what Get-MergeOnGreenPrVerdict would have
        read next had the executed-path check not returned first.

        PURE, and every fact is a parameter, exactly like the function this reuses -- no git, no gh, no
        environment; the reads live in the caller (a SessionStart check, in this issue's case).

    .PARAMETER Record
        A pull request record, in the shape Get-MergeOnGreenPrVerdict and Get-MergeOnGreenExecutedPathHit
        themselves read (labels, isDraft, isCrossRepository, files, changedFiles).

    .PARAMETER MergeBlockVerdict
        Get-MergeBlockVerdict's own object for THIS pull request, from its own `gh pr checks --required`
        payload. $null reads as not-green, the same fail-closed reading Get-MergeOnGreenPrVerdict gives it.

    .PARAMETER GreenAgeMinutes
        Get-RequiredGreenAgeMinutes' answer for THIS pull request. $null -- unreadable, or not passed --
        reads as not-settled, for the same reason.

    .PARAMETER Label
        The arming label; defaults to Get-MergeOnGreenArmLabel.

    .OUTPUTS
        [pscustomobject] Stranded (bool), Reason (string, set only when Stranded is $true -- the same
        sentence Get-MergeOnGreenPrVerdict would print for this pull request today).
    #>
    param(
        $Record,
        $MergeBlockVerdict,
        $GreenAgeMinutes = $null,
        [string]$Label = (Get-MergeOnGreenArmLabel)
    )

    $notStranded = [pscustomobject]@{ Stranded = $false; Reason = '' }

    # THE ONE FACT Get-MergeOnGreenPrVerdict CANNOT EXPOSE FOR SUCH A RECORD. Asked first and asked
    # directly, because everything below only matters once this is non-empty.
    $hit = Get-MergeOnGreenExecutedPathHit -Record $Record
    if (-not $hit) { return $notStranded }

    # CONFIRM THE VERDICT DECLINES ON THIS REASON, EXACTLY -- not on "not armed", "a draft" or "a fork",
    # which are all checked earlier in Get-MergeOnGreenPrVerdict and would report a DIFFERENT Reason
    # here. String identity against the exact sentence Get-MergeOnGreenExecutedPathHit composes is what
    # tells these apart without re-deriving the armed/draft/cross-repo checks a second time.
    $verdict = Get-MergeOnGreenPrVerdict -Record $Record -MergeBlockVerdict $MergeBlockVerdict `
        -GreenAgeMinutes $GreenAgeMinutes -Label $Label
    if ($verdict.Eligible -or $verdict.Reason -ne "$hit -- ship it from a session") { return $notStranded }

    # THE VERDICT RETURNED BEFORE READING EITHER OF THESE TWO -- reached here only because the Reason
    # matched exactly, so this pull request already passed every check Get-MergeOnGreenPrVerdict makes
    # AHEAD of the executed-path one (armed, not a draft, not a fork). It is stranded only once these
    # also hold -- the two checks the picker would have made NEXT, read through the SAME shared block
    # Get-MergeOnGreenPrVerdict itself calls (Victor, #2438), so the two cannot drift apart.
    $settled = Test-MergeOnGreenRequiredChecksSettled -MergeBlockVerdict $MergeBlockVerdict -GreenAgeMinutes $GreenAgeMinutes
    if (-not $settled.Ready) { return $notStranded }

    return [pscustomobject]@{ Stranded = $true; Reason = "$hit -- ship it from a session" }
}
