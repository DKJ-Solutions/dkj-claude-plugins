<#
.SYNOPSIS
    Claim a GitHub issue for THIS checkout before any work on it starts -- under the account its
    commits will name, and refusing where the issue is closed, missing, or already somebody else's.

.DESCRIPTION
    THE RULE THIS IMPLEMENTS ALREADY EXISTED; NOTHING PERFORMED IT. Chris's persona body ("Picking up
    an issue -- claim it before you work it") and dkj-policy/CONTRIBUTING.md both prescribe
    `gh issue edit <n> --add-assignee @me`, and both leave it to a session to remember, to type, and
    to read the result of. This script is that step, so that "fix issue 1234" cannot begin before the
    tracker says who is on it.

    WHY THE TRACKER IS WHERE THIS HAS TO HAPPEN. It is the only thing two sessions share. The same
    owner may be running a second machine and a colleague may be working the same board; neither
    session sees the other's branch or intent, so an unassigned issue is indistinguishable from an
    untouched one -- which is how the same work gets built twice and discovered at the merge.

    THREE THINGS THE DOCUMENTED ONE-LINER GETS WRONG, and each is a refusal below:

      1. `@me` CAN NAME THE WRONG ACCOUNT. It resolves through the GitHub API, so it binds to whatever
         gh is authenticated as -- while the branch a second session correlates the claim with carries
         the git identity. Measured (issue #1315): gh acting as DaveKJohn on a checkout committing as
         davekokbwj put the wrong account on #1314. This script never sends `@me`: it resolves the
         account from both reads and claims by NAME, which is what check-git-identity.ps1's own report
         already instructs. See Resolve-ClaimAccount.

      2. IT SUCCEEDS SILENTLY ON A CLOSED ISSUE. So the claim gives a session every signal of having
         taken ownership of work that is already finished. That is the case new-branch.ps1's stale-base
         block records: a branch cut, committed, pushed and PR'd against an issue another session had
         closed by a merged PR four minutes earlier. Nothing downstream catches it, because every gate
         reads the branch and the branch is fine.

      3. IT ADDS, SO IT NEVER TELLS YOU THE ISSUE IS TAKEN. `--add-assignee` on an issue somebody else
         holds puts you beside them and reports success. Reading the claim is a separate command that
         the rule names and nobody runs; here it is one step with the write.

    AND ONE THING IT READS THAT NOTHING ELSE DOES: THE BRANCHES (issue #1853). All three signals a
    session has at pickup -- the issue's state, its assignees, and any PR resolving it -- read exactly
    the same whether the work is untouched or already done and PUSHED ON A PARKED BRANCH. Measured
    September 11, 2026: #1847 was claimed correctly and repaired in full, while the identical repair sat
    in a commit on origin/feat/1842-unify-prio-labels-bwj, which has no PR and never closed the issue.
    So on a claim (and on a resume) this scans the commit messages OFF THE TRUNK for the issue number
    and names the branch and the commit. It WARNS and never refuses: it cannot tell a fix from a
    mention, and a claim that blocks costs the whole assignment (#1485).

    IT WRITES ONE THING AND NOTHING ELSE. An assignee on one issue. No branch, no checkout, no commit,
    no label, no comment -- opening the branch is new-branch.ps1's job and stays a separate decision,
    because the branch name is a judgement about the work and this step has not read the work yet. The
    scan above does not break that: `git fetch` and `git log` write nothing in the tree, and HEAD does
    not move.

    THE VERDICT IS TESTED AND THE COMMANDS ARE NOT (scripts/lib/claim-issue-lib.ps1). Everything here
    around the library calls is a gh or git round-trip a suite cannot run; the decisions are pure, so
    they are where the refusals live -- and so are the scan's pattern, its two parses and its report.

    Dual-context: run the root copy in this repo, the plugin mirror in a consumer.

    Pure ASCII, per this repo's script-layer convention.

.PARAMETER Issue
    The issue to claim. Accepts a bare number (1234), a hash-prefixed one (#1234), or the issue's own
    URL -- all three are what a person has in their hand at that moment, and requiring one spelling
    would only teach the caller to strip characters this script can strip itself.

.PARAMETER DryRun
    Read and judge, write nothing. Prints the verdict it would act on, so a caller can see who holds
    an issue without taking it.

.PARAMETER RootOverride
    Repo root to resolve repo-config.ps1 in, for the test suite. A consumer never types this: the root
    is resolved dual-context like every other shared script.

.EXAMPLE
    ./scripts/task/claim-issue.ps1 1234

.EXAMPLE
    ./scripts/task/claim-issue.ps1 '#1234' -DryRun
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Issue,
    [switch]$DryRun,
    [string]$RootOverride = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# Repo root -- dual context: a consumer running the shared plugin mirror gets it from
# CLAUDE_PROJECT_DIR, a run inside this repo from git itself.
# JUDGED (#1917): Resolve-RepoRootOrFail is check-report-lib's refusing sibling of Resolve-CheckRoot
# -- same precedence, but it names git's exit code and stderr instead of dying on $null.Trim().
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$repoRoot = Resolve-RepoRootOrFail -Override $RootOverride -ScriptName 'claim-issue.ps1'

. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\git-identity-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\claim-issue-lib.ps1')
# THE FETCH-ATTEMPT RECORD (issue #1860) -- the parked-fix scan's fetch runs through it, so an
# unreachable remote is not waited out again by new-branch.ps1 seconds later.
. (Join-Path $PSScriptRoot '..\lib\fetch-attempt-lib.ps1')

# --- WHICH ISSUE ----------------------------------------------------------------------------------
#
# The three spellings a caller actually has: 1234, #1234, and the URL they just copied out of the
# browser. A URL is reduced to its trailing path segment rather than pattern-matched against
# github.com, because a self-hosted tracker is somebody else's host and the number is in the same
# place either way.
$raw = $Issue.Trim().TrimStart('#')
if ($raw -match '/([0-9]+)/?$') { $raw = $Matches[1] }
if ($raw -notmatch '^[0-9]+$') {
    Write-Host "[ERROR] '$Issue' is not an issue number." -ForegroundColor Red
    Write-Host '        Give the number (1234), the number with a hash (#1234), or the issue URL.' -ForegroundColor Red
    exit 1
}
$number = $raw

# --- WHICH REPO -----------------------------------------------------------------------------------
#
# Get-RepoName pins the tracker explicitly, which matters in a worktree or when the run starts from a
# directory other than the checkout: gh would otherwise resolve the repo from the CURRENT directory,
# and a claim landing on the wrong tracker is a silent failure of exactly the kind this script exists
# to remove. Read defensively, like every other shared script reads repo-config.ps1 -- that file
# belongs to the consumer, and a fault in it must not take this step down. Without it, gh's own
# resolution stands and is said out loud.
#
# THE TRUNK NAME IS READ IN THE SAME BLOCK, from the same OPTIONAL seam (Get-TrunkBranchName), because
# the parked-fix scan below needs it and 'main' is a consumer's answer rather than a constant. It is
# deliberately NOT taken from entry-scaffold-lib.ps1's Get-BranchTrunkName, which is the same three
# lines: that lib is thousands of lines long and this script currently dot-sources four small ones, so
# pulling it in for one accessor would put the cost of the whole scaffolder on every claim.
$repoName = ''
$trunkBranch = 'main'
$configPath = Join-Path $repoRoot 'scripts\repo-config.ps1'
if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    try {
        . $configPath
        if (Test-FunctionDefined 'Get-RepoName') { $repoName = [string](Get-RepoName) }
        if (Test-FunctionDefined 'Get-TrunkBranchName') {
            $configuredTrunk = [string](Get-TrunkBranchName)
            if ($configuredTrunk) { $trunkBranch = $configuredTrunk }
        }
    } catch {
        $repoName = ''
    }
}
$repoArgs = if ($repoName) { @('--repo', $repoName) } else { @() }

Write-Host "== claim-issue #$number$(if ($DryRun) {' -DryRun'}) -- $(if ($repoName) { $repoName } else { 'repo per gh (no Get-RepoName)' }) ==" -ForegroundColor Cyan

# --- WHO THIS CHECKOUT IS -------------------------------------------------------------------------
$identity = Resolve-ClaimAccount -GhAccount (Get-ActiveGhAccount) -GitUserName (Get-GitUserName -RepoRoot $repoRoot)

if ($identity.Reason -eq 'split') {
    # Not an error here, and deliberately not: check-git-identity.ps1 owns that report and the
    # SessionStart hook has already made it. What this step owes the reader is which of the two names
    # it is about to write, and why that is the git one.
    Write-Host "  [split identity] gh acts as '$($identity.GhAccount)', git commits as '$($identity.GitUserName)'." -ForegroundColor Yellow
    Write-Host "                   Claiming as '$($identity.Account)' -- the account the branch will name." -ForegroundColor Yellow
}

# --- WHAT THE TRACKER SAYS ------------------------------------------------------------------------
#
# -DiscardStderr because this output is parsed: gh writes its progress and its warnings to stderr, and
# merged in they are not JSON. The failure branch below therefore says what it can from the exit code
# rather than quoting gh, which is the trade native-capture-lib names.
#
# BOUNDED, LIKE EVERY OTHER NETWORK CALL IN THIS FAMILY (issue #1639). All three `gh` calls in this
# script were unbounded while every sibling script bounded its own, and the cost lands hardest here:
# the claim is the FIRST step of an issue-driven assignment (#1485), so a stall at this line is a
# session that never starts, with nothing printed to say why. The failure mode is not hypothetical on
# this surface -- #1628's measurement is a checkout where `gh` returned exit 1 intermittently while
# working fine from the shell, minutes apart, in one session, and an intermittently-unhealthy `gh` is
# exactly the shape that hangs rather than exits.
$view = Invoke-NativeCapture -FilePath 'gh' -Arguments (@('issue', 'view', $number) + $repoArgs + @('--json', 'number,title,state,url,assignees')) -Utf8 -DiscardStderr `
                             -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
if (-not $view -or $view.ExitCode -ne 0) {
    Write-Host "[ERROR] could not read issue #$number." -ForegroundColor Red
    if ($view -and $view.TimedOut) {
        # A STALL IS NOT ONE OF THE THREE BELOW, so it does not get their list. Each of those is a
        # verdict gh reached and reported; this is gh reaching none, and sending a reader down a
        # list of causes that cannot produce a hang is the bound announcing itself as the wrong thing.
        Write-Host "        gh did not answer within $NativeCaptureNetworkTimeoutSeconds seconds -- see the [timeout] line above." -ForegroundColor Red
        Write-Host '        That is a stall, not a verdict about the issue: nothing was read and nothing was claimed.' -ForegroundColor Red
        Write-Host '        Check that gh is healthy here (gh auth status) and run this again -- it costs one read.' -ForegroundColor Red
    } else {
        Write-Host '        Three things this is, in the order they are worth checking:' -ForegroundColor Red
        Write-Host "          1. the number does not exist in $(if ($repoName) { $repoName } else { 'this repo' }), or names a pull request rather than an issue;" -ForegroundColor Red
        Write-Host '          2. gh is not logged in here      -- run: gh auth status' -ForegroundColor Red
        Write-Host '          3. this account cannot see it    -- a private repo it has no access to.' -ForegroundColor Red
    }
    exit 1
}

$viewJson = (@($view.Output) -join "`n")
$facts = $null
try {
    $facts = $viewJson | ConvertFrom-Json
} catch {
    # THE REASON, NOT JUST THE SYMPTOM (issue #1679). This branch is also where a SHORT READ lands: the
    # -Utf8 arm can answer 0 with a capture still being written, and a truncated JSON document does not
    # parse -- so the verdict here is right (refuse, nothing claimed) while "gh returned something that
    # is not JSON" sends the reader after gh instead of after their own machine. Named separately, and
    # the re-run is only offered on the arm where it is the actual remedy.
    if ($view.ShortRead) {
        Write-Host "[ERROR] the read of issue #$number came back truncated -- nothing was claimed." -ForegroundColor Red
        Write-Host '        gh exited 0, but its capture was still being written when this run read it, so what' -ForegroundColor Red
        Write-Host '        arrived was not a whole JSON document. That is a fact about this run rather than' -ForegroundColor Red
        Write-Host '        anything about the issue -- run this again and it normally settles.' -ForegroundColor Red
    } else {
        Write-Host "[ERROR] gh returned something that is not JSON for issue #$number -- nothing was claimed." -ForegroundColor Red
    }
    exit 1
}

# The logins come out of the JSON TEXT rather than off $facts, because the reading is where the 5.1
# traps are and a lib function is the half a suite can hold. gh's exit code was checked above AND the
# parse above succeeded, so an empty list here means unassigned rather than unanswered -- the second
# half matters since #1679: a short read is what an exit code alone cannot rule out, and what rules it
# out here is that a truncated document would not have parsed.
$assignees = @(Get-AssigneeLogins -Json $viewJson)

$title = Format-ForConsole -Text ([string]$facts.title)

Write-Host "  #$($facts.number)  $($facts.state)  $title"
if ($assignees.Count -gt 0) { Write-Host "  assignees: $($assignees -join ', ')" }

# --- MAY IT BE CLAIMED ----------------------------------------------------------------------------
$verdict = Get-ClaimVerdict -Account $identity.Account -State ([string]$facts.state) -Assignees $assignees

# --- IS THE FIX ALREADY SITTING ON A BRANCH (issue #1853) -----------------------------------------
#
# THE FOURTH PICKUP SIGNAL, and the one none of the three above can carry. The verdict just reached
# reads the issue's STATE and its ASSIGNEES; Get-TargetIssueWarnings, which new-branch.ps1 and
# open-pr.ps1 both run, resolves an issue to a PULL REQUEST. Measured September 11, 2026: a session
# claimed #1847 -- open, unassigned, correctly -- and wrote the fix, only for open-pr's remote-ahead
# gate to show that the identical repair was already pushed on origin/feat/1842-unify-prio-labels-bwj
# and said so in its own commit message. That branch is PARKED, so there was no PR to find and nothing
# had closed the issue: all three signals read 'untouched'. The commit message is where a parked fix
# announces itself and the only place it does.
#
# IT RUNS ONLY WHERE THERE IS SOMETHING TO SAVE, which is why it sits above the switch rather than
# below it. 'claim' is the case #1853 measured; 'skip' is a RESUME, where it matters at least as much --
# Chris's own body says resuming is picking up, and on a second machine the other session's branch is
# the only trace there is. The two refusals below never reach it, so a closed or taken issue pays
# nothing for a check whose answer it would not use.
#
# ADVISORY, NEVER A REFUSAL. An issue can be legitimately named in a commit on a branch that does not
# fix it -- the run that produced this measurement saw open-pr warn about four such mentions, all
# correct as context -- and a claim that blocks costs the whole assignment (#1485). Every failure below
# is therefore a note and a carry-on, including the fetch's.
#
# ONE THING IT DOES CHANGE IS WHAT THIS SCRIPT SAYS LAST (#1878). Advisory is about the exit code and
# the claim, not about the wording: a run that prints 'ASK THEM BEFORE YOU WRITE ANYTHING' and then
# closes with 'the work starts here' has said both and settled neither, and the second line is the one
# a session acts on. So the closing verdict below reads this flag.
$foreignParked = $false
if ($verdict.Action -eq 'claim' -or $verdict.Action -eq 'skip') {
    $scanPattern = Get-IssueMentionPattern -Issue ([int]$number)

    # THE EXCLUSIONS ARE ESTABLISHED BEFORE THE NETWORK CALL, because they decide whether it is worth
    # making. Without a trunk ref to subtract, `git log --all` reports every commit on the trunk that
    # ever named this number -- which for a long-lived issue is its own repair, merged, and is exactly
    # the noise that teaches a reader to skip this warning. So: no trunk ref, no scan.
    $trunkRefs = @()
    foreach ($ref in @($trunkBranch, "origin/$trunkBranch")) {
        $probe = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $repoRoot, 'rev-parse', '--verify', '--quiet', $ref) -DiscardStderr
        if ($probe -and $probe.ExitCode -eq 0) { $trunkRefs += $ref }
    }

    $headProbe = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $repoRoot, 'rev-parse', '--abbrev-ref', 'HEAD') -DiscardStderr
    $currentBranch = if ($headProbe -and $headProbe.ExitCode -eq 0) { (@($headProbe.Output) -join '').Trim() } else { '' }
    $excludeBranches = @($trunkBranch, "origin/$trunkBranch")
    if ($currentBranch -and $currentBranch -ne 'HEAD') { $excludeBranches += @($currentBranch, "origin/$currentBranch") }

    if ($scanPattern -and $trunkRefs.Count -gt 0) {
        # THE FETCH IS THE ONLY NETWORK CALL THIS SCRIPT MAKES TO git, and it is the cost #1853 weighed
        # this check against. It is `fetch --quiet` rather than `--all`: one remote's default refspec is
        # what the scan reads, and a checkout with three remotes should not pay for two of them here.
        # Bounded like every other network call in this family (#1639) and BEST-EFFORT -- a failure
        # leaves the already-fetched refs in place, which is a smaller answer rather than a wrong one,
        # and the note below says so instead of letting it read as a clean scan.
        #
        # AND A FAILURE OF IT IS NOT PAID FOR TWICE (issue #1860). Invoke-RecordedRemoteFetch is the seam
        # new-branch.ps1 also fetches through, and the two land seconds apart by design: the claim is the
        # OPENING of the work (#1485), so new-branch follows in the same turn. Against an unreachable
        # remote that used to mean two full two-minute bounds back to back, at the one moment a session
        # has nothing on screen yet to explain the wait; now the second call reports the first's failure.
        #
        # THE ORDINARY ~700ms IS STILL PAID TWICE, DELIBERATELY. A seam that also skipped on a recent
        # SUCCESS would remove it, and new-branch.tests.ps1 cases (v) and (y1) refuse that: the probes it
        # would let stand on a cached fetch are the ones that exist to see a push another session made
        # seconds ago (#1139, #1439). A failed attempt refreshed nothing, so reporting it blinds nothing.
        #
        # THE ARGUMENT-LESS FORM IS KEPT, AND THE SEAM RESOLVES THE NAME ONLY FOR ITS RECORD. #1853's
        # choice was git's default remote, not 'origin' by name, and a checkout whose default is
        # something else must therefore match nothing rather than be assumed into this one's premise.
        #
        # NO -DiscardStderr, AND THAT IS THE CONVENTION RATHER THAN AN OVERSIGHT (#1313). A git call that
        # talks to a remote writes ALL of its output to stderr, and git redacts the credential out of
        # that line itself (transport_anonymize_url -- measured on 2.55.0). Nothing here parses the
        # capture, so the flag would buy nothing and cost the reader git's own reason: exactly the trade
        # #1313 declined for ship-pr's fetch, worktree-lane and prune-merged. The lines are printed under
        # the note below, because keeping stderr and then never showing it is the same loss one step
        # later. The two reads further down DO parse, so they keep the flag.
        $fetch = Invoke-RecordedRemoteFetch -RepoRoot $repoRoot -RecentFailureSeconds $RemoteFetchRecentFailureSeconds `
                                         -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
        $staleNote = "$($fetch.Note)"
        $staleDetail = @(@($fetch.Output) | Where-Object { $_ -and ([string]$_).Trim() })
        if (-not $staleNote) { $staleDetail = @() }

        # FOUR FIELDS, AND THE TWO ADDED ONES ARE THE JUDGEMENT (#1878). %an and %at cost nothing --
        # the same log call, the same walk -- and they carry the two facts the reader's decision
        # actually turns on. Without them this block printed a sha and a subject, and the one commit
        # shape a parked branch always has (a 'park:' scaffold) reads as empty: measured September 11,
        # 2026, a session read exactly such a commit, found nothing in it, and built a second
        # implementation of #1874 while its author's PR was minutes from opening.
        $logArgs = @('-C', $repoRoot, 'log', '--all', '-E', "--grep=$scanPattern", '--format=%H%x1f%an%x1f%at%x1f%s', '--not') + $trunkRefs
        $scanLog = Invoke-NativeCapture -FilePath 'git' -Arguments $logArgs -Utf8 -DiscardStderr
        if (-not $scanLog -or $scanLog.ExitCode -ne 0 -or $scanLog.ShortRead) {
            $why = if (-not $scanLog) { 'it could not be run at all' } elseif ($scanLog.ShortRead) { 'its capture was still being written when it was read' } else { "it exited $($scanLog.ExitCode)" }
            Write-Host "  [parked-fix scan skipped] git log for #$number was not readable -- $why." -ForegroundColor DarkGray
        } else {
            # THE CONTAINMENT LOOP IS BOUNDED, and the display cap in Format-ParkedFixReport does NOT
            # bound it -- that one trims what is printed, after every commit has already paid for its own
            # ancestry walk. Measured here on the review pass: `git branch -a --contains` costs ~30ms and
            # a realistic parked branch matches 0-4 commits, so the ordinary run spends under 120ms; the
            # worst case is a branch whose every subject carries the number (the convention is
            # `fix(1853): ...`), which one issue in this repo's history reaches at 21.
            #
            # INVERTING THE LOOP WAS CONSIDERED AND DECLINED. Asking each branch which of ITS commits
            # match -- one `git log <branch>` per branch -- is O(branches) instead of O(matches), and this
            # repo carries 19 branches off the trunk against a handful of matches, so it makes the
            # ordinary run four times slower to make the rare one faster. The ceiling costs nothing in
            # the ordinary run and is what the rare one actually needs.
            #
            # NEWEST FIRST, because that is git log's own order and the newest commits are the ones whose
            # branches are still live. The overflow is stated rather than swallowed -- a truncation a
            # reader cannot see is the defect this whole check exists to remove, one layer in.
            $maxContainmentReads = 25
            $scanMatches = @(ConvertFrom-CommitScanLog -Text ((@($scanLog.Output) -join "`n")))
            $resolved = @($scanMatches | Select-Object -First $maxContainmentReads)
            if ($scanMatches.Count -gt $resolved.Count) {
                Write-Host "  [parked-fix scan] $($scanMatches.Count) commits name #$number off the trunk; the newest $($resolved.Count) were resolved to a branch." -ForegroundColor DarkGray
            }
            $findings = @()
            foreach ($commit in $resolved) {
                $contains = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $repoRoot, 'branch', '-a', '--contains', $commit.Sha) -Utf8 -DiscardStderr
                if (-not $contains -or $contains.ExitCode -ne 0) { continue }
                $branches = @(Get-ContainingBranchNames -Text ((@($contains.Output) -join "`n")) -Exclude $excludeBranches)
                if ($branches.Count -eq 0) { continue }
                # THE BRANCH NAME IS UNTRUSTED TEXT TOO, and it was the half that got printed raw. A
                # subject and a ref name come from the same place -- anyone who can push -- so both go
                # through the same filter, AFTER the exclusion above, which must compare the ref as git
                # spells it. git's own check-ref-format already refuses the C0 range in a ref, so this
                # strips nothing in practice today; it is here so that the one sanitiser this output has
                # covers every field of it, rather than leaving a second class of pushed text as the
                # exception a later widening would have to remember.
                # THE AUTHOR NAME IS THE THIRD FIELD OF PUSHED TEXT, so it goes through the same filter
                # as the other two. It is written by whoever made the commit -- git config user.name is
                # free text -- and #1878 put it on a line a session reads before deciding whether to
                # stop, which is exactly the position the sanitiser exists for.
                $findings += [pscustomobject]@{
                    Sha         = $commit.Sha
                    Author      = (Format-ForConsole -Text $commit.Author)
                    AuthorEpoch = $commit.AuthorEpoch
                    Subject     = (Format-ForConsole -Text $commit.Subject)
                    Branches    = @($branches | ForEach-Object { Format-ForConsole -Text $_ })
                }
            }

            # WHOSE COMMITS COUNT AS THIS CHECKOUT'S OWN. The git name first, because %an is what the
            # scan read and the git name is what this checkout would have written; the claiming login
            # second, so a split checkout (#1315) recognises itself under either. Test-SelfAuthored
            # treats an empty list as 'no verdict', which is the honest answer on a checkout with no
            # user.name configured.
            $selfNames = @($identity.GitUserName, $identity.Account)
            $parkedReport = @(Format-ParkedFixReport -Issue ([int]$number) -Findings $findings -SelfNames $selfNames)
            foreach ($line in $parkedReport) {
                Write-Host "  $line" -ForegroundColor Yellow
            }
            # ASKED AGAIN RATHER THAN SCRAPED BACK OUT OF THE LINES ABOVE -- the closing verdict of this
            # script has to agree with the block, and a regex over printed prose is how those two drift.
            if (Get-ForeignParkedCommit -Findings $findings -SelfNames $selfNames) { $foreignParked = $true }
        }

        # PRINTED WHETHER OR NOT ANYTHING WAS FOUND, and that is the whole reason it is a separate line:
        # "nothing names this issue" and "I could not refresh the refs I looked at" are different
        # sentences, and merging them lets a failed fetch read as a clean scan.
        if ($staleNote) {
            Write-Host "  [parked-fix scan] $staleNote -- the branches read here may be behind origin." -ForegroundColor DarkGray
            # git's own words, which is the whole reason stderr was kept above: "could not read from
            # remote repository" and "Authentication failed" are what tell a reader whether this is
            # their credentials or their network, and neither is derivable from the exit code.
            foreach ($detail in $staleDetail) { Write-Host "                    $(Format-ForConsole -Text $detail)" -ForegroundColor DarkGray }
        }
    }
}

switch ($verdict.Code) {
    'no-account' {
        Write-Host '[ERROR] gh names no active account here, so there is nobody to claim this as.' -ForegroundColor Red
        Write-Host '        Run: gh auth login   (then run this again)' -ForegroundColor Red
        Write-Host '        A claim exists to tell a second session whose work this is -- it cannot be made anonymously.' -ForegroundColor Red
        exit 1
    }
    'closed' {
        Write-Host "[REFUSED] issue #$number is CLOSED -- nothing was claimed." -ForegroundColor Red
        Write-Host '          The one-liner in the docs would have succeeded here and told you nothing, which is the' -ForegroundColor Red
        Write-Host '          most expensive way this step fails: work already done, built again in full, found at the' -ForegroundColor Red
        Write-Host '          merge. If it is closed and still broken, REOPEN it first -- the reopening is the record' -ForegroundColor Red
        Write-Host '          that the earlier repair did not hold, and this step is not the place to make it silently.' -ForegroundColor Red
        Write-Host "          $($facts.url)" -ForegroundColor Red
        exit 1
    }
    'taken' {
        Write-Host "[REFUSED] issue #$number is already claimed by $($verdict.Others -join ', ') -- nothing was claimed." -ForegroundColor Red
        if ($assignees -contains $identity.Account) {
            Write-Host "          '$($identity.Account)' is on it too, and that is not evidence about what the other is" -ForegroundColor Red
            Write-Host '          building: two people on one issue is the duplicate-work hazard, not a shared claim.' -ForegroundColor Red
        }
        Write-Host '          Pick another issue, or ask whoever holds it. There is deliberately no flag past this:' -ForegroundColor Red
        Write-Host '          the way through is a conversation, and a switch cannot have one.' -ForegroundColor Red
        Write-Host "          $($facts.url)" -ForegroundColor Red
        exit 1
    }
    'already-yours' {
        Write-Host "[OK] #$number is already yours ('$($identity.Account)') -- nothing to write." -ForegroundColor Green
        Write-Host '     A resume, then: read the branch and its document before you carry the work.' -ForegroundColor Green
        # A RESUME IS WHERE THE PARKED-FIX VERDICT MATTERS MOST, not least: the other session's branch
        # is already in this working copy, indistinguishable from your own, and the assignee field
        # cannot name a machine. So the one line that points forward says which branch it means.
        if ($foreignParked) {
            Write-Host '     BUT NOT THAT BRANCH: somebody else pushed to one of them -- see the parked-fix' -ForegroundColor Yellow
            Write-Host '     verdict above, and ask them before you carry it.' -ForegroundColor Yellow
        }
        Write-Host "     $($facts.url)"
        exit 0
    }
}

# --- CLAIM IT -------------------------------------------------------------------------------------
if ($DryRun) {
    Write-Host "[DRY RUN] would claim #$number for '$($identity.Account)'. Nothing was written." -ForegroundColor Yellow
    Write-Host "          $($facts.url)"
    exit 0
}

$edit = Invoke-NativeCapture -FilePath 'gh' -Arguments (@('issue', 'edit', $number) + $repoArgs + @('--add-assignee', $identity.Account)) -Utf8 `
                             -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
if ($edit -and $edit.TimedOut) {
    # THE ONE PLACE A TIMEOUT IS NOT THE SAME AS A FAILURE, and it is split out above the branch below
    # for that reason alone. Every other bounded call in this script only READS; this one WRITES, and a
    # write that never answered may well have landed server-side. So the honest report is neither "the
    # claim failed" (which the branch below would print, and which would be a claim about the tracker
    # this run cannot make) nor an [OK].
    #
    # IT STILL STOPS, unlike the read-back's could-not-verify state further down. The difference is
    # what has already been proven: there, the write returned 0 and only the confirmation was missing,
    # so carrying on was the likelier-correct act. Here nothing about the write is known at all.
    # RE-RUNNING IS SAFE AND IS THE WAY OUT: the pre-write read at the top would then report
    # 'already-yours' if it did land, which is a complete answer, and claim it if it did not.
    Write-Host "[ERROR] 'gh issue edit' did not answer within $NativeCaptureNetworkTimeoutSeconds seconds -- see the [timeout] line above." -ForegroundColor Red
    Write-Host "        THIS RUN DOES NOT KNOW whether the claim landed: the write reached the network and never" -ForegroundColor Red
    Write-Host '        reported back, so it may be on the tracker already. Treat the issue as UNCLAIMED until you' -ForegroundColor Red
    Write-Host '        have looked, and run this again -- a claim that did land comes back as "already yours".' -ForegroundColor Red
    Write-Host "          gh issue view $number --json assignees" -ForegroundColor Red
    Write-Host "        $($facts.url)" -ForegroundColor Red
    exit 1
}
if (-not $edit -or $edit.ExitCode -ne 0) {
    Write-Host "[ERROR] the claim failed -- #$number is NOT yours." -ForegroundColor Red
    foreach ($line in @($edit.Output)) { Write-Host "        $line" -ForegroundColor Red }
    if ($identity.Split) {
        Write-Host "        This checkout has a split identity, so the likely cause is that '$($identity.Account)'" -ForegroundColor Red
        Write-Host "        (the account it COMMITS as) cannot be assigned in this repo, while gh acts as" -ForegroundColor Red
        Write-Host "        '$($identity.GhAccount)'. Resolve the split rather than claiming as the other one:" -ForegroundColor Red
        Write-Host '        check-git-identity.ps1 prints both ways out.' -ForegroundColor Red
    }
    exit 1
}

# --- READ THE CLAIM BACK --------------------------------------------------------------------------
#
# The write is not the proof. `--add-assignee` reports success for a login GitHub silently drops (a
# non-collaborator on a repo that allows the edit), and an unverified claim is worse than none: the
# session believes the tracker says something it does not. One extra read, at the one moment it
# settles the question this whole script exists to answer.
#
# THREE STATES, NOT TWO (#1628, September 8, 2026). A single `$landed` boolean collapsed "the read
# succeeded and the account is absent" -- the claim was refused -- into "the read never happened", and
# then printed the first. Those are opposite facts: one says the tracker rejected the claim, the other
# says THIS RUN DOES NOT KNOW, while the write it is checking returned 0. Measured claiming #1623 in
# this repo: the message fired, named a cause it had not measured ("most often an account with no
# write access"), and told the operator to treat the issue as UNCLAIMED -- and a plain `gh issue view`
# on the same checkout, seconds later, showed the claim sitting there. The same session's `new-branch`
# run printed 'could not ask gh which issues are open (exit 1)' minutes later, so gh was answering
# intermittently and the second branch of the old `if` was being reported as the first. Note the
# contrast that made it legible: `new-branch` names the exit code and says the check COULD NOT ASK.
#
# `-DiscardStderr` STAYS, so the could-not-verify line names the exit code rather than gh's own words:
# Output is parsed as JSON here, and stderr mixed into it would break the parse to improve a message.
$after = Invoke-NativeCapture -FilePath 'gh' -Arguments (@('issue', 'view', $number) + $repoArgs + @('--json', 'assignees')) -Utf8 -DiscardStderr `
                              -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
# A SHORT READ IS NOT gh DISAGREEING (issue #1679). $readOk asked the exit code alone, and the -Utf8 arm
# can answer 0 with an empty or truncated capture -- in which case $landed is false and the run took the
# REFUSED branch below, printing "gh accepted the claim but '<account>' is not on #N ... Treat the issue
# as UNCLAIMED" and exiting 1. That is a confident false negative on the step that OPENS every
# issue-driven assignment (#1485), and its own comment says why it is wrong: it claims gh answered and
# the account was not in the list it returned, when on a short read gh's answer never reached us.
#
# THE RIGHT BRANCH ALREADY EXISTS AND IS TWO BLOCKS DOWN. "Could not verify" is exactly this state, and
# it deliberately does not block -- so folding ShortRead into $readOk needs no new verdict, no new
# message and no new policy. #1679 filed this site in its group C on the ground that "the read-back
# fails, which is the safe direction"; the read-back does not fail, it succeeds with nothing, which is
# the whole reason the field had to exist.
$readOk = [bool]($after -and $after.ExitCode -eq 0 -and -not $after.ShortRead)
$landed = $readOk -and ((Get-AssigneeLogins -Json (@($after.Output) -join "`n")) -contains $identity.Account)

if ($readOk -and -not $landed) {
    # REFUSED -- measured rather than inferred: gh answered, and the account is not in the list it
    # returned. This is the only state the old message was ever right about, and it is unchanged.
    Write-Host "[ERROR] gh accepted the claim but '$($identity.Account)' is not on #$number." -ForegroundColor Red
    Write-Host '        GitHub drops an assignee it will not accept without failing the command -- most often an' -ForegroundColor Red
    Write-Host '        account with no write access to this repo. Treat the issue as UNCLAIMED.' -ForegroundColor Red
    Write-Host "        $($facts.url)" -ForegroundColor Red
    exit 1
}

if (-not $readOk) {
    # COULD NOT VERIFY -- and it does NOT block, for the reason the claim step exists at all (#1485): a
    # claim is the OPENING of the work, so a false stop here costs the whole assignment. Everything
    # that guards against duplicate work has already succeeded -- the pre-write read answered and
    # showed nobody else holding this issue, and `gh issue edit` returned 0 -- so by far the likelier
    # state is a claim that landed and a read that did not. What this run cannot do is call that
    # proven, so it says which of the two states it is in and hands over the command that settles it.
    #
    # THE TimedOut REASON IS REACHABLE NOW, AND #1628 LEFT ROOM FOR IT ON PURPOSE. This block used to
    # carry the opposite note -- "no TimedOut branch, deliberately: this script passes no
    # -TimeoutSeconds anywhere, so that field is always $false here and a branch on it would be a
    # reason that can never print" -- which was exactly right on the day it was written and stopped
    # being true the moment the three calls above were bounded (issue #1639). It is the one reason
    # worth naming separately here, because a stall and an exit code point the reader at different
    # things: an exit code means gh answered and disagreed, a timeout means the read never happened at
    # all, and only the second says nothing whatever about the tracker's state.
    #
    # AND THE SHORT READ IS THE THIRD SUCH REASON (issue #1679), for the same argument one paragraph up
    # rather than a new one: it is a read that did not happen, so it says nothing about the tracker
    # either -- and unlike a stall it arrives at exit 0, so naming the exit code here would print
    # "exited 0" as the reason the read-back failed. That is the misleading half; it must be named
    # before the exit-code arm or it can never print.
    $why = if ($after -and $after.TimedOut) {
        "did not answer within $NativeCaptureNetworkTimeoutSeconds seconds"
    } elseif ($after -and $after.ShortRead) {
        'exited 0 with its capture still being written, so what came back may be truncated'
    } elseif ($after) {
        "exited $($after.ExitCode)"
    } else {
        'could not be run at all'
    }
    Write-Host "[WARNING] the claim was written and gh accepted it, but the read-back $why," -ForegroundColor Yellow
    Write-Host "          so this run cannot confirm '$($identity.Account)' is on #$number. It most likely IS:" -ForegroundColor Yellow
    Write-Host '          the write returned 0, and the read before it answered normally. Confirm it if you' -ForegroundColor Yellow
    Write-Host "          want certainty -- gh issue view $number --json assignees" -ForegroundColor Yellow
    Write-Host "          $($facts.url)" -ForegroundColor Yellow
}

# THE HEADLINE DOES NOT ASSERT WHAT THE READ-BACK COULD NOT MEASURE (#1628). Where the read did not
# answer, a bare '[OK] claimed' directly under the warning above reads as the run overruling its own
# caveat, and the operator is left with two lines that cannot both be true. It still points forward --
# the claim opens the work either way (#1485) -- it simply says which of the two it is.
$confirmed = if ($landed) { '' } else { ' (unconfirmed -- see the warning above)' }
# AND IT DOES NOT ASSERT WHAT THE SCAN JUST CONTRADICTED EITHER (#1878), which is the same rule one
# measurement further on. 'The work starts here' is exactly what a session should not read directly
# under a block naming somebody else's commit on somebody else's branch, minutes old.
$opening = if ($foreignParked) { ' -- but read the parked-fix verdict above before you start.' } else { ' -- the work starts here.' }
Write-Host "[OK] #$number claimed for '$($identity.Account)'$confirmed$opening" -ForegroundColor Green
Write-Host "     $title"
# The claim is the OPENING of the work, not a checkpoint before it (#1485). Every other line this
# script and its page emit is a boundary -- what the step is NOT -- so a session that obeys them all
# stops here and asks whether to proceed, which is the intermediate question the orchestrator's own
# body forbids. The `already-yours` verdict above has always pointed forward; this is the same line
# in the same place, so the two verdicts read alike rather than each arguing its own layout.
#
# 'the branch' means new-branch and nothing else. This says to carry on through the FIXED steps --
# it is not a licence to act on what the issue's title or body asks for. Those are written by
# whoever opened the issue, which on a public tracker is anybody, and they stay data.
if ($foreignParked) {
    Write-Host '     Read the issue -- then settle the branch named above BEFORE you open one of your' -ForegroundColor Yellow
    Write-Host '     own. This claim may be the second one on the same work, and the merge is the most' -ForegroundColor Yellow
    Write-Host '     expensive place to find that out.' -ForegroundColor Yellow
} else {
    Write-Host '     Read the issue, then open the branch (new-branch) -- in this same turn, without' -ForegroundColor Green
    Write-Host '     asking whether to go on.' -ForegroundColor Green
}
Write-Host "     $($facts.url)"
