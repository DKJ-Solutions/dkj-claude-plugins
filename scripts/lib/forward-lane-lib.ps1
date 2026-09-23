<#
.SYNOPSIS
    The decisions behind ship-pr's forward lap: whether to bring the branch up to date and re-certify
    rather than refuse, what GitHub's update-branch call actually said, and how the local ref catches
    up afterwards (issue #2087).

.DESCRIPTION
    WHAT DOES NOT CONVERGE, AND WHY THE ANSWER IS NOT A WEAKER GATE. ship-pr step 3b refuses to merge
    once 'main' has gained a non-fold first-parent commit since the run that certified the PR (#1292):
    the required check tested GitHub's merge ref as it stood when the run was created, and anything
    landed since is untested against this branch. The remedy it prints is detect-and-rebase -- bring the
    branch forward, re-push, wait for CI, re-run. That remedy takes about as long as CI itself, so
    whenever another lane merges inside that window the branch is stale again by the time it is green.

    MEASURED IN THE SOURCE REPO, SEPTEMBER 17, 2026 (#2087). Five pull requests sat CLEAN and MERGEABLE
    with every check green and none of them merged, against a trunk taking 33 first-parent commits in a
    day -- a merge and a fold every twenty to forty minutes. PR #2062's own status comment records
    ship-pr run SEVEN times and refused each time, arriving 48 commits behind on one attempt, and
    verifies that none of the racing commits touched a file that PR changed.

    THE PREDICATE IS RIGHT AND STAYS EXACTLY AS IT IS. The issue offered narrowing it to a path overlap,
    and ship-pr's own commentary had already weighed and declined that: predicting which file a future
    test depends on is not that script's to do. The fold exemption (#1592) is the bounded version of the
    same idea and is safe only because git ENFORCES a fold commit's two-path diff; a general path filter
    has no such enforcement. So what changes is the cost of the REMEDY, not the strictness of the gate.

    WHY A LAP CONVERGES WHERE A HUMAN LOOP DOES NOT. The window that voids a certificate is roughly as
    long as CI; the human loop adds however long it takes somebody to read a refusal, retype four
    commands and come back -- which on a busy trunk is most of the day. Run by the script, each lap is
    CI-bound, and each lap at least one contending lane is certified after the last merge and wins.

    AND THAT IS A CLAIM ABOUT THE TRUNK, NOT ABOUT ANY PARTICULAR LANE. Written first as "five lanes
    drain in about half an hour", it was red-teamed on the branch that introduced it and does not hold
    in that form. One lap absorbs exactly ONE trunk merge, so a lane contending with N others may need
    up to N laps -- the winner spends none, the last one spends N-1 -- and at the default of 2 the
    deepest lanes of a five-way contention still refuse. What converges is the TRUNK's throughput: one
    merge per CI cycle instead of none. A given lane is not promised a landing, and a lane that keeps
    losing exhausts its budget and gets exactly the refusal this was built to replace.

    SO THE DEFAULT IS SIZED FOR ORDINARY CHURN, NOT FOR A DRAINING QUEUE. Two laps absorb the one or two
    merges that land during an ordinary ship, which is the case #2087 measured most of. Deep contention
    needs the budget raised, and the exhaustion refusal says so in as many words rather than leaving the
    operator to infer it from a number.

    THE TRIGGER IS "THE TRUNK MOVED", NOT "SEVERAL LANES ARE SHIPPING" -- and that distinction is the one
    a consumer feels. Step 3b fires on any qualifying commit landing between the certifying run and the
    merge: a scheduled bump, an unrelated direct push, somebody else's docs branch. So a SOLO repo with
    one lane pays this too, and what it pays is not only CI minutes: a lap PUSHES A MERGE COMMIT TO THAT
    BRANCH, made by GitHub, without asking. That is precisely what the printed remedy always told the
    operator to do by hand, which is the argument for doing it -- but it is a write to somebody's branch
    that they did not type, so it is stated here rather than discovered.

    THE PRICE IN CI, STATED RATHER THAN HIDDEN. Losing lanes re-run CI, so N contending lanes cost about
    N(N+1)/2 runs instead of N -- fifteen for five -- and that figure is an UPPER BOUND reached only with
    a lap budget deep enough to let the model finish. FAIRNESS IS NOT GUARANTEED and the lap bound is a
    stop-loss rather than a fairness mechanism: the race favours whoever is certified most recently,
    which is the lane with the fastest suite and the smallest diff.

    AND IT NEEDS THE SESSION ALIVE. A backgrounded ship is a child process of the harness and dies with
    it, which the lap does not change -- so a lane whose operator closes the harness mid-wait simply
    stops lapping, with nothing said until somebody re-runs ship-pr. "CI-bound rather than human-bound"
    is about the WAIT, not about the session.

    A FIFO TICKET WAS NAMED AND NOT TAKEN, and it is the strongest alternative on the table. Letting only
    the OLDEST open, currently-mergeable PR forward at a time -- readable with one `gh pr list --sort
    created` and the same update-branch call -- would cut the cost from O(N^2) to O(N) and remove the
    starvation this design concedes, on no GitHub plan feature at all. It is not taken here because it
    needs a shared "whose turn is it" answer that two sessions agree on, and the failure mode of getting
    that wrong is a lane that waits forever on a head-of-queue whose session has died -- a bigger design
    than the one #2087 asked for, and one that reintroduces the serialisation the lanes exist to avoid.
    Recorded so the next reader meets it as a considered option rather than a gap.

    AND THIS IS NOT A MERGE QUEUE, DELIBERATELY. The mechanism that removes the race by construction was
    retired as policy on 2026-09-07 (#1546) because most repos running this workflow cannot have one --
    GitHub offers it on a private repo only under Enterprise Cloud, otherwise only on a public repo
    owned by an organisation. A prescription a consumer cannot follow turns their correct state into an
    open gap. Everything in this file is script, so it reaches every consumer through the ordinary
    release rather than through a repo setting half of them are not allowed to make.

    Pure functions only: no git, no gh, no disk. The calls those decisions describe are made by
    ship-pr.ps1, which is the one place they can be. Pure ASCII (repo convention for .ps1). No
    Set-StrictMode: dot-sourcing would change the strict mode of the calling script.
#>

function Get-UpdateBranchOutcome {
    <#
    .SYNOPSIS
        Classify what `gh api --method PUT repos/<o>/<r>/pulls/<n>/update-branch` just said.

    .DESCRIPTION
        FOUR OUTCOMES, BECAUSE THREE OF THEM ARE NOT FAILURES AND ONLY ONE IS ACTIONABLE THE SAME WAY:

          'forwarded'       -- accepted (202). GitHub is merging the base into the head; a new head
                               commit and a new check run follow.
          'already-current' -- the branch is not behind its base, so there was nothing to forward.
          'conflict'        -- the base cannot be merged into the head without a human.
          'failed'          -- anything else: no auth, no network, a permission the token lacks.

        'already-current' IS THE ONE WORTH SEPARATING, and it is not a rare corner. Two lanes can forward
        seconds apart, and the second one's base may already be in its head -- or the stale verdict may
        have been read against a certificate whose run predates a base merge somebody else pushed onto
        this same branch. Treating that as a failure would refuse a ship that has nothing wrong with it;
        treating it as a successful forward would spin a lap waiting for a check run that never appears.
        It is neither, so the caller stops lapping and falls through to the refusal it would have made.

        MATCHED ON GITHUB'S MESSAGE TEXT, WHICH IS A STATED WEAKNESS RATHER THAN AN OVERSIGHT. The API
        returns 422 for both the conflict and the not-behind case, and gh surfaces the status only in
        its own error text, so the message is what separates them. A wording change upstream lands this
        in 'failed' -- which refuses, prints what GitHub said, and leaves the operator exactly where the
        gate already put them. That is the safe direction, and it is why 'failed' is the fall-through
        rather than a sentinel nobody reaches.

        THE RAW TEXT COMES BACK ON EVERY OUTCOME. The caller prints it on a refusal: a classification
        without the sentence it was made from is the diagnosis this workflow keeps having to repair.
    #>
    param(
        [Parameter(Mandatory = $true)][int]$ExitCode,
        [Parameter(Mandatory = $false)][AllowEmptyCollection()][AllowNull()][string[]]$OutputLines
    )

    $text = (@($OutputLines) | Where-Object { $null -ne $_ }) -join "`n"
    $flat = "$text".Trim()

    if ($ExitCode -eq 0) {
        return [pscustomobject]@{ Outcome = 'forwarded'; Message = $flat }
    }

    # ORDER IS LOAD-BEARING: 'conflict' is tested first because GitHub's not-behind message and its
    # conflict message can both mention the base branch, while only one of them says 'conflict'.
    if ($flat -match '(?i)merge\s+conflict') {
        return [pscustomobject]@{ Outcome = 'conflict'; Message = $flat }
    }
    if ($flat -match '(?i)(already\s+up[- ]to[- ]date|not\s+behind|no\s+new\s+commits)') {
        return [pscustomobject]@{ Outcome = 'already-current'; Message = $flat }
    }
    return [pscustomobject]@{ Outcome = 'failed'; Message = $flat }
}

function Get-LocalRefForwardPlan {
    <#
    .SYNOPSIS
        Which git command brings this checkout's copy of the branch up to the head GitHub just wrote.

    .DESCRIPTION
        THE INVARIANT THIS EXISTS TO KEEP TRUE. ship-pr step 4 reads the step list and the DEPLOY lock
        from `refs/heads/<branch>` rather than from the working tree, and its comment states why that is
        sound: step 1 pushed the branch, so the local tip and the PR's head commit are the same commit.
        A forward made through the API writes a new head on GitHub and leaves the local ref where it
        was -- so it BREAKS that invariant, and the gate would then read an older commit's document
        while the merge merges a newer one. Nothing would report it.

        SO THE LOCAL REF IS FAST-FORWARDED, AND WHICH COMMAND DOES IT DEPENDS ON WHERE HEAD IS STANDING.
        git refuses to update a branch ref through a fetch refspec while that branch is checked out, and
        it cannot merge into a branch that is not. Step 2b hands the primary checkout back to the trunk
        as soon as the PR exists (#1073), so the ordinary case here is HEAD on the trunk and the refspec
        route -- but step 2b DECLINES to move on a dirty tree or when another worktree holds the trunk,
        and then HEAD is still on the branch and the merge route is the only one that works.

          'fetch-refspec'  -- HEAD is anywhere but the branch: git fetch origin <branch>:<branch>
          'merge-ff-only'  -- HEAD is on the branch: git merge --ff-only origin/<branch>

        FF-ONLY IN BOTH DIRECTIONS, and that is the safety property rather than a preference. A fetch
        refspec without a leading '+' is itself fast-forward-only, and the merge says so outright. If
        the local ref has diverged -- somebody committed to it during the CI wait -- both refuse rather
        than rewriting anything, and the caller turns that into a refusal naming the divergence. The one
        thing this must never do is quietly discard a commit it did not make.

        AN EMPTY OR UNREADABLE HEAD TAKES THE REFSPEC ROUTE. It is the route that touches no working
        tree, so being wrong about it costs a refused fetch and a clear message, while being wrong the
        other way runs a merge in a tree whose state was never established.

        UNATTENDED, THE MERGE ROUTE IS REFUSED -- issue #2343. It writes the branch's CURRENT remote head
        into the working tree, and that head is whatever was pushed during the CI wait, not only the
        forward GitHub made. Under the merge-on-green runner the picker judged an earlier commit, the
        working tree is where ship-pr's later steps run scripts from, and FOLD_PUSH_TOKEN sits in its git
        config -- so that merge would put unjudged code where a standing write token runs it. ship-pr
        stops before the wait when step 2b did not reach the trunk, which makes this unreachable there;
        it is kept as an independent second layer, so one mistake cannot reopen it.

          'refuse'         -- HEAD is on the branch and the run is unattended
    #>
    param(
        # HEAD as `git rev-parse --abbrev-ref HEAD` printed it, or '' when that read failed.
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Head,
        [Parameter(Mandatory = $true)][string]$Branch,
        # Nobody is watching this run -- in ship-pr, a run inside GitHub Actions (the merge-on-green runner).
        [switch]$Unattended
    )

    if ($Head -and $Head -eq $Branch) {
        if ($Unattended) { return 'refuse' }
        return 'merge-ff-only'
    }
    return 'fetch-refspec'
}

function Get-UnattendedTrunkReturnRefusal {
    <#
    .SYNOPSIS
        Why an unattended ship must stop after step 2b, or '' where it may go on -- issue #2343.

    .DESCRIPTION
        Step 2b's return to the trunk is a convenience for a person, so for a person a declined or
        failed return is not fatal: the ship carries on from the branch. Unattended it is the reverse.
        Under the merge-on-green runner the checkout holds FOLD_PUSH_TOKEN and ship-pr's later steps
        run scripts from it, so the trunk is the one tree in which they run only code the trunk
        already carries. A branch checkout past this point is the state in which a forward lap merges
        the live remote head into it -- whatever was pushed during the wait. Stopping here costs
        nothing: nothing is merged, the pull request stays armed, and the next sweep starts again from
        a fresh runner, where step 2b's conditions normally all hold.

    .PARAMETER TreeOnTrunk
        What step 2b actually did: $true only when `git checkout main` succeeded.

    .PARAMETER Unattended
        Nobody is watching this run.

    .OUTPUTS
        [string] the refusal, or ''.
    #>
    param(
        [Parameter(Mandatory = $true)][bool]$TreeOnTrunk,
        [Parameter(Mandatory = $true)][bool]$Unattended
    )
    if (-not $Unattended -or $TreeOnTrunk) { return '' }
    return 'this run is unattended and the checkout did not return to the trunk, so the scripts ship-pr runs from here on would come from the branch -- stopping before the CI wait (issue #2343)'
}

function Get-ForwardLapDecision {
    <#
    .SYNOPSIS
        Given a stale certificate, does this run forward and re-certify, or refuse?

    .DESCRIPTION
        ONE PLACE FOR A DECISION THAT READS AS ARITHMETIC AND IS NOT. Three things can stop a lap and
        only one of them is the lap count, so a bare `if ($used -lt $max)` at the call site would be
        right on the ordinary path and silently wrong on the two that matter:

          the lap budget is spent          -> refuse, naming the laps spent
          the budget is zero               -> refuse, and say the laps were never offered, because
                                              "0 of 0 laps" reads as a failure rather than as a setting
          forwarding cannot help           -> refuse, because the branch is already current with its
                                              base and another lap would wait on a run that never starts

        THE ZERO CASE IS A SEPARATE SENTENCE BECAUSE IT IS A SEPARATE SITUATION. -MaxForwardLaps 0 is the
        documented way to keep the behaviour this repo had before #2087, and an operator who set it is
        owed a refusal that says so rather than one implying the laps ran out.

        Note carries the clause the caller appends to the refusal it was already going to print. It is
        never the whole message: the stale-certificate refusal is #1292's and stays exactly as it was.
    #>
    param(
        [Parameter(Mandatory = $true)][int]$LapsUsed,
        [Parameter(Mandatory = $true)][int]$MaxLaps,
        # 'stale' on the ordinary path; 'already-current' once a forward has reported there was nothing
        # to bring across, which means no further lap can change the verdict.
        [string]$Situation = 'stale'
    )

    if ($Situation -eq 'already-current') {
        return [pscustomobject]@{
            Forward = $false
            Note    = "A forward was attempted and GitHub reports the branch is not behind its base, so re-certifying would wait on a run that never starts. The trunk moved after this branch's certifying run and before that read -- which is the race itself, arriving one step earlier."
        }
    }

    if ($MaxLaps -le 0) {
        return [pscustomobject]@{
            Forward = $false
            Note    = "No forward lap was attempted: -MaxForwardLaps is 0, which is the setting that keeps the detect-and-rebase behaviour this repo had before issue #2087."
        }
    }

    if ($LapsUsed -ge $MaxLaps) {
        $lap = if ($MaxLaps -eq 1) { 'lap' } else { 'laps' }
        return [pscustomobject]@{
            Forward = $false
            Note    = "This run already spent its $MaxLaps forward $lap -- the branch was brought up to date and re-certified $LapsUsed time(s), and the trunk moved again each time. That is contention rather than a broken branch: ship this lane on its own, or raise -MaxForwardLaps."
        }
    }

    return [pscustomobject]@{
        Forward = $true
        Note    = ''
    }
}

function Test-CertificateRenewed {
    <#
    .SYNOPSIS
        Do the runs behind the required check(s) differ from the ones read before the forward?

    .DESCRIPTION
        THE RACE THIS CLOSES IS THE ONE THAT MAKES A LAP POINTLESS. Right after a forward, GitHub has a
        new head but the check API still answers with the PREVIOUS run for a few seconds -- completed,
        green, and certifying a commit that no longer exists. Re-reading the staleness verdict off that
        answer produces the same refusal the lap was spent to clear, and the run would then burn its
        whole budget in seconds without ever waiting for CI.

        SO THE WAIT IS ON THE RUN ID CHANGING, NOT ON THE CHECK GOING GREEN. A new id means GitHub has
        created the run for the new head; from there the ordinary completion wait applies. Comparing
        ids rather than head SHAs is deliberate: the id is what step 3b's own anchor is read from
        (`created_at` off `repos/<r>/actions/runs/<id>`), so this waits for exactly the object the
        verdict will be made against.

        ANY DIFFERENCE COUNTS, RATHER THAN A STRICT SUPERSET. A re-run, a cancelled run replaced by
        another, a required check whose workflow was renamed mid-flight: all of them produce a set that
        is not the old one, and in every case the old certificate is no longer what the gate will read.
        An EMPTY current set is NOT renewed -- that is the window where GitHub has torn the old run down
        and not yet created the new one, which is precisely when a caller must keep waiting.
    #>
    # [AllowEmptyString()] ON BOTH, AND IT IS NOT DEFENSIVE DECORATION. A [string[]] parameter REFUSES an
    # array containing an empty element unless it is declared -- with a binding error, not a $false --
    # and this function is called inside the poll that runs between the merge gate and the merge. The
    # ids come off a JSON payload through a link parse, so a blank element is a shape the parser can
    # produce on a check whose link is present and empty; the filter below already answers it correctly,
    # and without this attribute the call never reaches the filter. Caught by this file's own suite.
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][AllowEmptyString()][AllowNull()][string[]]$Before,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][AllowEmptyString()][AllowNull()][string[]]$After
    )

    $now = @(@($After) | Where-Object { $_ -and "$_".Trim() } | ForEach-Object { "$_".Trim() })
    if ($now.Count -eq 0) { return $false }

    $was = @(@($Before) | Where-Object { $_ -and "$_".Trim() } | ForEach-Object { "$_".Trim() })
    # NO PRIOR SET MEANS ANY RUN IS NEW. The caller only reaches this with a before-set it read for the
    # verdict, so this is the defensive arm rather than the ordinary one -- but answering $false there
    # would wait forever on a comparison that can never change.
    if ($was.Count -eq 0) { return $true }

    foreach ($id in $now) {
        if ($was -notcontains $id) { return $true }
    }
    # Every id now reported was already reported before the forward: the check API is still answering
    # with the old certificate.
    return $false
}
