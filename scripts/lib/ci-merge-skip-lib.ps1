<#
.SYNOPSIS
    Pure helpers for issue #2303's CI-side re-derivation of ship-pr.ps1's own step-3b staleness
    check -- whether a 'merge: <branch> (#NN)' push to main may skip the test suites because the
    merged PR's own head SHA was already independently proved fresh.

.DESCRIPTION
    ONE PREDICATE, TWO MOMENTS. ship-pr.ps1's step 3b answers "has main moved since the run that
    certified this PR" BEFORE the merge, so it can refuse rather than land a stale tree.
    scripts/ci/get-merge-suite-skip.ps1 asks the SAME question AFTER the merge, from inside the CI
    run the push itself triggers -- using the identical pure functions
    (Get-RequiredCheckNames, Get-RequiredCheckRunIds, Get-CertifyingRunCreatedAt,
    Test-IsFoldOnlyCommit, Get-StaleCertificateVerdict, Get-CheckOutcome, all in
    pr-issues-lib.ps1) rather than inventing a second predicate for one question. Asking it AFTER
    the merge, from data CI reads itself, is what makes the answer trustworthy regardless of
    whether the merge came from ship-pr or from the GitHub UI -- #2303's own argument for why a
    UI merge cannot be trusted on the commit subject alone.

    What is new here is small on purpose: parsing the PR number back out of the merge commit's
    own subject (ship-pr's step 3b never had to recover it, having just written it) and combining
    the already-fetched facts into one Skip/Reason verdict.

    PURE: no git, no gh. The impure reads live in scripts/ci/get-merge-suite-skip.ps1; this file
    is asserted without a live remote, like every sibling pure function it calls.
#>

function Get-MergeCommitPrNumber {
    <#
    .SYNOPSIS
        The PR number out of a 'merge: <branch> (#NN)' commit subject -- ship-pr.ps1's own
        $mergeSubject shape ("merge: $branch (#$pr)") -- or $null when the subject does not
        match it.

    .DESCRIPTION
        ANCHORED AT THE END OF THE LINE, not searched for: the number must be the last
        parenthesised group, matching exactly what ship-pr.ps1 writes and refusing a branch name
        that happens to embed a '(#12)'-shaped substring earlier in the same subject. A subject
        this narrow could still come from a UI merge whose operator typed the same shape by hand
        rather than from ship-pr -- that is not a boundary this function draws. Nothing here is
        TRUSTED on the strength of the shape alone: the caller re-derives the certificate from
        GitHub's own records regardless of how the subject was produced, so a forged or
        coincidental match costs at most a wasted read that ends in skip=false.

    .PARAMETER Message
        A commit subject line (typically `git log -1 --format=%s`).
    #>
    param([string]$Message)

    $text = ([string]$Message).Trim()
    if ($text -notmatch '^merge:\s.+\(#(\d+)\)\s*$') { return $null }
    return $Matches[1]
}

function Get-MergeCommitSuiteSkipVerdict {
    <#
    .SYNOPSIS
        Given ALREADY-FETCHED facts about a merged PR, whether the 'merge:' push that landed it
        may skip the test suites -- issue #2303. Skip is true only when the repo's named check
        registered 'pass' on the merged PR's own head SHA, a dateable Actions run was found
        behind it, and 'main' gained no first-parent commit (net of folds) between that run and
        this merge.

    .DESCRIPTION
        FAIL-CLOSED AT EVERY BRANCH, the same posture ship-pr.ps1's own step 3b takes on every
        read it cannot make: anything short of a clean 'pass' plus a clean 'not stale' answers
        Skip=$false. The worst this function can be wrong about is a suite run that was not
        strictly necessary -- never a suite skipped that should have run.

    .PARAMETER RequiredCheckOutcome
        Get-CheckOutcome's answer for the repo's own named check (Get-CiTestCheckName) read off
        the MERGED PR's own checks payload. Anything other than 'pass' refuses.

    .PARAMETER CertifyingRunFound
        Whether at least one Actions run was found behind that check (Get-RequiredCheckRunIds
        non-empty) and its 'created_at' was readable (Get-CertifyingRunCreatedAt non-$null).
        $false collapses every read failure along the way into one refusal.

    .PARAMETER StaleVerdict
        Get-StaleCertificateVerdict's own object, read over the first-parent commits 'main'
        gained since the certifying run, net of fold exemptions. Only consulted when
        CertifyingRunFound is $true; $null there also refuses.

    .OUTPUTS
        [pscustomobject] Skip (bool), Reason (string, always set).
    #>
    param(
        [string]$RequiredCheckOutcome,
        [bool]$CertifyingRunFound,
        $StaleVerdict
    )

    if ($RequiredCheckOutcome -ne 'pass') {
        return [pscustomobject]@{ Skip = $false; Reason = "required check outcome is '$RequiredCheckOutcome', not 'pass'" }
    }
    if (-not $CertifyingRunFound) {
        return [pscustomobject]@{ Skip = $false; Reason = 'no dateable Actions run behind the required check' }
    }
    if ($null -eq $StaleVerdict) {
        return [pscustomobject]@{ Skip = $false; Reason = 'staleness could not be measured' }
    }
    if ($StaleVerdict.Stale) {
        return [pscustomobject]@{ Skip = $false; Reason = "main gained $($StaleVerdict.Count) commit(s) since the certifying run" }
    }
    return [pscustomobject]@{ Skip = $true; Reason = 'required check is pass on the merged head and main did not advance since (net of folds)' }
}
