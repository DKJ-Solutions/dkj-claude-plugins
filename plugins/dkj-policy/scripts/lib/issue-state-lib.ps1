<#
.SYNOPSIS
    Asks gh what each cited number actually IS in this repo, so the already-done check can be TOLD
    which of them are closed issues instead of inferring it from an absence. The impure half of
    inbound #2056; the rule it applies is Get-IssueStateVerdict, in pr-issues-lib.ps1.

.DESCRIPTION
    THE DEFECT THIS CLOSES. Get-TargetIssueWarnings used to take the OPEN issue list alone and read
    "determinable, and this number is not in it" as CLOSED. There was no third state, so a number that
    has never existed in this repo was reported as closed, and the caller told the author the branch
    "may repeat work that is already merged".

    AND IT FIRED LOUDEST ON THE BRANCHES THAT FOLLOW THE DOCUMENTED ROUTE. The numbers being tested are
    scraped as bare integers out of the development document, and this workflow PRESCRIBES citing an
    issue in another repo: the inbound route files a shared-core finding on the marketplace repo, and
    the consumer then cites that number in a docstring, a README entry and the DEPLOY section. Every
    one of those is a bare '#<n>' after scraping, pointing at a repo this check never queries. Measured
    in the consumer that filed it: 'issue #2055 is already CLOSED' on a branch that had opened #2055
    upstream twenty minutes earlier, where no #2055 exists locally at all.

    WHY THE SPLIT ACROSS TWO FILES. Everything that can be decided from gh's answer is a pure function
    of that answer, and it lives in pr-issues-lib.ps1 where a suite asserts it exactly, without a
    network. What is left here is the part that CANNOT be asserted that way: the loop, and the calls.
    The same split preview-theme.ps1 and theme-lifecycle-rules.ps1 make, for the same reason.

    WHY PER NUMBER AND NOT ONE LIST. The obvious single query -- 'gh issue list --state all' -- cannot
    serve: it is paged, and this repo alone is past 2000 issues, so a genuinely closed issue behind the
    page boundary would come back as "not here" and lose the #1282 signal the check exists for. The set
    needing resolution is small by construction -- only the targets the caller could not already
    account for from its open-issue list, which on an ordinary branch is a handful -- so one call each
    is bounded by the citation count rather than by the size of the tracker.

    SILENCE IS THE SAFE FAILURE DIRECTION, and every path here takes it. The check is advisory and
    never blocks, so a number this function cannot resolve contributes nothing and produces no warning
    at all. A wrong warning costs the author's trust in every later one -- which is the cost #2056
    names as the one that matters -- while a missing warning costs only what it always cost.

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script. Depends on
    Invoke-NativeCapture (native-capture-lib.ps1) and on Get-IssueStateVerdict (pr-issues-lib.ps1);
    both callers already load both.
    Pure ASCII (repo convention for .ps1).
#>

# THE CEILING ON HOW MANY NUMBERS ONE RUN RESOLVES, in one place. Which numbers survive it -- the
# newest, not the lowest -- is Get-IssueResolveBatch's judgement, over in the pure lib where a suite can
# assert it. Here it is only the number.
$script:IssueStateResolveLimit = 25

function Get-ClosedIssueSet {
    <#
    .SYNOPSIS
        Which of these numbers are CLOSED ISSUES of this repo. Returns an object with Closed (an int[],
        possibly empty), Unreadable ($true when gh could not answer for at least one number), and
        Truncated ($true when the resolve limit was reached).

    .DESCRIPTION
        ONE 'gh issue view <n> --repo <owner/name> --json state,url' PER NUMBER, each answer judged by
        Get-IssueStateVerdict -- see that function for the three states, and for why a pull request is
        not a separate case but the second half of the same conflation. Which numbers a run takes when
        there are more than the limit is Get-IssueResolveBatch's, and both live in pr-issues-lib.ps1
        because both are pure.

        THE RESULT IS DELIBERATELY NOT JUST A LIST. Closed alone cannot distinguish "none of them is
        closed" from "I could not ask", and those carry opposite weight in an advisory check: the first
        is a determinate answer, the second is a gap the caller has to say out loud. Unreadable is that
        second fact, and it is per-run rather than per-number because the caller's sentence is per-run
        too.

    .PARAMETER Repo
        'owner/name' -- passed explicitly rather than left to gh's own resolution, so a run started
        outside the checkout or inside a worktree lane asks about the repo the caller means.

    .PARAMETER Numbers
        The numbers to resolve. The caller passes only the ones it could not already account for from
        the open-issue list it has; resolving a number already known to be open is a round trip for an
        answer in hand.

    .PARAMETER TimeoutSeconds
        Passed through to Invoke-NativeCapture, so a stalled gh is reported rather than waited out --
        the same bound every other network call in this workflow passes.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [int[]]$Numbers = @(),
        [int]$TimeoutSeconds = 120
    )

    $batch  = Get-IssueResolveBatch -Numbers $Numbers -Limit $script:IssueStateResolveLimit
    $wanted = @($batch.Numbers)
    $result = [pscustomobject]@{ Closed = @(); Unreadable = $false; Truncated = [bool]$batch.Truncated }
    if ($wanted.Count -eq 0) { return $result }

    $closed = @()
    foreach ($n in $wanted) {
        # NO -DiscardStderr, DELIBERATELY, AND IT IS THE ONE LINE THIS FUNCTION TURNS ON. gh writes
        # "Could not resolve to an issue or pull request with the number of <n>" to STDERR, and that
        # sentence is the entire difference between "this number is not an issue here" (silent) and
        # "gh is broken" (said out loud). Discarding it collapses the two, which is how the first cut
        # of this repair went on warning about exactly the citations it was written to silence --
        # measured on gh 2.74.0 during this branch's review. Same convention as Test-GhMutationTransient
        # one lib over, whose docstring says "stdout + stderr merged" for the same reason.
        $q = Invoke-NativeCapture -FilePath 'gh' -Arguments @(
            'issue', 'view', "$n", '--repo', $Repo, '--json', 'state,url'
        ) -TimeoutSeconds $TimeoutSeconds

        # AUDITED UNDER #2081 AND LEFT AS IT IS, on a mechanism worth stating because it is invisible:
        # Get-IssueStateVerdict declares `[int]$ExitCode = 0`, and PowerShell coerces $null to 0 on the
        # way in -- so an unmeasurable code (#1931) arrives as a clean exit and the verdict is reached
        # from the PAYLOAD instead. That is the right answer rather than a lucky one: the child ran, its
        # JSON is in hand, and the code is the weaker of the two pieces of evidence. A payload that is
        # missing or unparseable still returns 'unreadable', which this caller turns into silence.
        # IT DEPENDS ON THAT [int], so do not relax the parameter's type without replacing this reading.
        switch (Get-IssueStateVerdict -ExitCode $q.ExitCode -Output (@($q.Output) -join "`n")) {
            'closed'     { $closed += [int]$n }
            'unreadable' { $result.Unreadable = $true }
            default      { }
        }
    }

    $result.Closed = @($closed | Sort-Object -Unique)
    return $result
}

function Get-IssueBodySet {
    <#
    .SYNOPSIS
        The BODY of each of these issues, as a hashtable of number -> text. Returns an object with
        Bodies, Unreadable (the numbers gh could not answer for) and Truncated ($true when the resolve
        limit was reached).

    .DESCRIPTION
        THE IMPURE HALF OF THE RESOLVES-EXEMPT GATE (inbound #2120). The rule it feeds is
        Get-ResolvesExemptFindings in pr-issues-lib.ps1, where a suite asserts it exactly and without a
        network; what is left here is the loop and the calls. The same split this file already makes for
        Get-ClosedIssueSet, and the reason is unchanged.

        ONE 'gh issue view <n> --repo <owner/name> --json body' PER NUMBER, over the issues a PR is about
        to declare it CLOSES -- a set of one or two on an ordinary branch, and bounded at the same
        resolve limit as Get-ClosedIssueSet above rather than at the size of the tracker. The caller only
        reaches this at all when the repo has stated matchers, so a repo that carves out no class of
        issue pays nothing.

        -Utf8, UNLIKE Get-ClosedIssueSet ABOVE, and the difference is what is being read. That function
        reads a state field -- 'OPEN' or 'CLOSED', ASCII whatever the console code page is. This one
        reads prose somebody typed, so a body carrying an accented word or a dash decoded through the
        console code page comes back mangled, and a matcher over mangled text matches by luck.

        UNREADABLE IS A LIST AND NOT A BOOLEAN, because the caller's sentence names the numbers: a gate
        that refuses on what it read has to be able to say which issue it could NOT read, or the author
        cannot tell a clean pass from a gap. An empty body is a READ body and not an unreadable one --
        it simply matches nothing.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [int[]]$Numbers = @(),
        [int]$TimeoutSeconds = 120
    )

    $batch  = Get-IssueResolveBatch -Numbers $Numbers -Limit $script:IssueStateResolveLimit
    $wanted = @($batch.Numbers)
    $result = [pscustomobject]@{ Bodies = @{}; Unreadable = @(); Truncated = [bool]$batch.Truncated }
    if ($wanted.Count -eq 0) { return $result }

    $unreadable = @()
    foreach ($n in $wanted) {
        # -DiscardStderr, WHERE Get-ClosedIssueSet DELIBERATELY KEEPS IT: that function turns gh's
        # "Could not resolve to an issue" sentence into a verdict, so it needs the stream. Here stderr
        # would be MERGED INTO THE PAYLOAD this function parses as JSON, and the only thing a failed
        # read produces here is a number on the Unreadable list either way.
        $q = Invoke-NativeCapture -Utf8 -FilePath 'gh' -Arguments @(
            'issue', 'view', "$n", '--repo', $Repo, '--json', 'body'
        ) -TimeoutSeconds $TimeoutSeconds -DiscardStderr

        # ASKED BEFORE THE NUMBER (issue #1931): an unmeasurable exit code is $null, and both spellings
        # of the comparison against 0 fail toward "something went wrong" without being able to say so.
        if (-not (Test-NativeExitMeasured -Capture $q)) { $unreadable += [int]$n; continue }
        if ($q.ExitCode -ne 0)                          { $unreadable += [int]$n; continue }
        if ($q.ShortRead)                               { $unreadable += [int]$n; continue }

        try {
            $parsed = (@($q.Output) -join "`n") | ConvertFrom-Json
            $result.Bodies[[int]$n] = [string]$parsed.body
        } catch {
            $unreadable += [int]$n
        }
    }

    $result.Unreadable = @($unreadable | Sort-Object -Unique)
    return $result
}
