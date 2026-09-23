<#
.SYNOPSIS
    Claim a GitHub issue for THIS checkout before any work on it starts -- under the account its
    commits will name, and refusing where the issue is closed, missing, or already somebody else's.

.DESCRIPTION
    THE RULE THIS IMPLEMENTS ALREADY EXISTED; NOTHING PERFORMED IT. Chris's persona body ("Picking up
    an issue -- claim it before you work it"), and a repo's own dkj-policy/CONTRIBUTING.md where it
    still carries one (#2171 stopped scaffolding that page, September 20, 2026), both prescribe
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

         AND WHEN IT IS TAKEN, WHO BY MATTERS (issue #2207). A holder that is a SECOND ACCOUNT
         AUTHENTICATED IN GH ON THIS MACHINE is one person running two sessions -- the duplicate-work
         hazard itself -- where the refusal's own words ("ask whoever holds it") describe a colleague
         elsewhere. Measured September 20, 2026: the refusal fired correctly on #2197, was read as
         stale bookkeeping by the operator's own other account, overridden, and the live session under
         that account finished eight minutes later with a fuller measurement of the same issue. The
         note is printed from the SAME `gh auth status` read the identity resolution above already
         makes; see Get-LocalAccountHolders and Format-ConcurrentSessionNote.

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

    AND THERE IS A SECOND CLAIM IN HERE, FOR A SWEEP (-Tag, issue #2243). Where SEVERAL MACHINES work
    one backlog at once, the assignee cannot be the claim on either half: two checkouts under one
    account write the same name and neither can tell its own claim from the other's, and an assignee a
    colleague put on their own ticket months ago is not somebody mid-flight. So -Tag claims with a
    MARKER COMMENT carrying 'machine/account', writes the assignee beside it as the visible signal, and
    settles a two-session race on the tracker's own timestamps -- earliest comment wins, and only the
    losers release. The default mode is untouched by all of it: without -Tag this script behaves
    exactly as it did, refusals and all. The lib section 'THE CLAIM TAG' carries the measurements.

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

.PARAMETER Tag
    Claim by TAG rather than by assignee -- the sweep mode (issue #2243). The tag is
    'machine/account', written as a marker comment, and it is what a second machine reads. The
    assignee is still written beside it, as the tracker's own visible signal rather than as the claim.
    Everything the default mode refuses on the assignee is unchanged OUTSIDE this switch: in tag mode a
    foreign assignee is a NOTE, because an issue carrying the name of the colleague who owns the ticket
    is not an issue somebody is mid-flight on.

.PARAMETER Verify
    With -Tag: read only. Answers whether THIS tag still holds the issue -- exit 0 when it does,
    exit 1 when it does not. The resume step of a sweep turns on it, and it writes nothing.

.PARAMETER Release
    With -Tag: drop this tag's claim -- its marker comment and its assignee, and nothing else. The
    losing side of a race runs it, and so does a session abandoning an issue it cannot finish.

.PARAMETER Candidates
    List which open issues a sweep may pick up -- free, this tag's already, held by another tag, or
    skipped with the reason. Takes no issue number and WRITES NOTHING: choosing is a separate step from
    claiming, because between the two a session may still find the issue is not this repo's work.

.PARAMETER Marker
    The marker names a claim is recognised by. The first is the one a claim WRITES; the rest are
    predecessors a repo still has comments under. Default: 'claim-tag'. A comma list works under
    powershell -File too (-Marker claim-tag,swb-lane): -File binds it as one string, and the script
    splits it into names (#2358).

.PARAMETER SkipLabel
    With -Candidates: labels that park an issue with somebody else, so a sweep leaves it alone.

.PARAMETER SkipIssue
    With -Candidates: issue numbers held out of this round by hand.

.PARAMETER Limit
    With -Candidates: how many open issues to read. Default 100.

.PARAMETER RootOverride
    Repo root to resolve repo-config.ps1 in, for the test suite. A consumer never types this: the root
    is resolved dual-context like every other shared script.

.EXAMPLE
    ./scripts/task/claim-issue.ps1 1234

.EXAMPLE
    ./scripts/task/claim-issue.ps1 '#1234' -DryRun

.EXAMPLE
    ./scripts/task/claim-issue.ps1 -Candidates -SkipLabel needs-info

.EXAMPLE
    ./scripts/task/claim-issue.ps1 1234 -Tag

.EXAMPLE
    ./scripts/task/claim-issue.ps1 1234 -Tag -Verify
#>
[CmdletBinding(DefaultParameterSetName = 'Issue')]
param(
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Issue')][string]$Issue,
    [Parameter(ParameterSetName = 'Issue')][switch]$Tag,
    [Parameter(ParameterSetName = 'Issue')][switch]$Verify,
    [Parameter(ParameterSetName = 'Issue')][switch]$Release,
    [Parameter(Mandatory = $true, ParameterSetName = 'Candidates')][switch]$Candidates,
    [Parameter(ParameterSetName = 'Candidates')][string[]]$SkipLabel = @(),
    [Parameter(ParameterSetName = 'Candidates')][int[]]$SkipIssue = @(),
    [Parameter(ParameterSetName = 'Candidates')][int]$Limit = 100,
    [string[]]$Marker = @('claim-tag'),
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
$repoRoot = Resolve-RepoRootOrFail -Override $RootOverride -ScriptName 'claim-issue.ps1' -OverrideName '-RootOverride'

. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\git-identity-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\claim-issue-lib.ps1')
# -File binds '-Marker a,b' as ONE literal element, so the list is split here, once, before any read,
# write or self-invocation sees it (#2358). An empty result falls back to the documented default.
$Marker = @(Split-ClaimMarkerNames -Marker $Marker)
if ($Marker.Count -eq 0) { $Marker = @('claim-tag') }
# THE FETCH-ATTEMPT RECORD (issue #1860) -- the parked-fix scan's fetch runs through it, so an
# unreachable remote is not waited out again by new-branch.ps1 seconds later.
. (Join-Path $PSScriptRoot '..\lib\fetch-attempt-lib.ps1')

# --- WHICH ISSUE ----------------------------------------------------------------------------------
#
# The three spellings a caller actually has: 1234, #1234, and the URL they just copied out of the
# browser. A URL is reduced to its trailing path segment rather than pattern-matched against
# github.com, because a self-hosted tracker is somebody else's host and the number is in the same
# place either way.
#
# -Candidates HAS NO ISSUE, which is the whole of why it is its own parameter set: it asks WHICH issue
# rather than about one, so a mandatory number there would be a value the caller cannot have yet.
$number = ''
if (-not $Candidates) {
    $raw = $Issue.Trim().TrimStart('#')
    if ($raw -match '/([0-9]+)/?$') { $raw = $Matches[1] }
    if ($raw -notmatch '^[0-9]+$') {
        Write-Host "[ERROR] '$Issue' is not an issue number." -ForegroundColor Red
        Write-Host '        Give the number (1234), the number with a hash (#1234), or the issue URL.' -ForegroundColor Red
        exit 1
    }
    $number = $raw

    # -Verify and -Release are readings of a TAG claim, so neither means anything without one: the
    # assignee path has no claim of this session's to verify or to drop. Refused rather than treated as
    # -Tag, because guessing which mode was meant is how a release removes an assignee somebody else
    # relies on.
    if (($Verify -or $Release) -and -not $Tag) {
        $named = if ($Verify -and $Release) { '-Verify and -Release' } elseif ($Verify) { '-Verify' } else { '-Release' }
        Write-Host "[ERROR] $named only mean something with -Tag -- nothing was read or written." -ForegroundColor Red
        Write-Host '        They read and drop a TAG claim (the marker comment). The default mode claims by' -ForegroundColor Red
        Write-Host '        assignee and has nothing of this session''s to verify or release.' -ForegroundColor Red
        exit 1
    }
    if ($Verify -and $Release) {
        Write-Host '[ERROR] -Verify and -Release are opposite acts -- name one.' -ForegroundColor Red
        Write-Host '        -Verify reads and writes nothing; -Release drops this tag''s claim.' -ForegroundColor Red
        exit 1
    }
}

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

$banner = if ($Candidates) { 'candidates' }
          elseif ($Verify) { "#$number -Tag -Verify" }
          elseif ($Release) { "#$number -Tag -Release" }
          elseif ($Tag) { "#$number -Tag" }
          else { "#$number" }
Write-Host "== claim-issue $banner$(if ($DryRun) {' -DryRun'}) -- $(if ($repoName) { $repoName } else { 'repo per gh (no Get-RepoName)' }) ==" -ForegroundColor Cyan

# --- WHO THIS CHECKOUT IS -------------------------------------------------------------------------
# ONE `gh auth status` READ, TWO QUESTIONS (issue #2207). Get-ActiveGhAccount used to make this
# capture privately and discard every account but the active one, which is the fact the 'taken'
# refusal below turned out to need: a holder that is a SECOND ACCOUNT AUTHENTICATED HERE is a
# concurrent session on this machine rather than a colleague elsewhere. The records are read once and
# passed on, so the signal costs no second process -- which is that issue's own scope note settled.
$ghAccounts = @(Get-GhAuthAccounts)
$identity = Resolve-ClaimAccount -GhAccount (Get-ActiveGhAccount -Accounts $ghAccounts) -GitUserName (Get-GitUserName -RepoRoot $repoRoot)

if ($identity.Reason -eq 'split') {
    # Not an error here, and deliberately not: check-git-identity.ps1 owns that report and the
    # SessionStart hook has already made it. What this step owes the reader is which of the two names
    # it is about to write, and why that is the git one.
    Write-Host "  [split identity] gh acts as '$($identity.GhAccount)', git commits as '$($identity.GitUserName)'." -ForegroundColor Yellow
    Write-Host "                   Claiming as '$($identity.Account)' -- the account the branch will name." -ForegroundColor Yellow
}

# --- WHICH TAG THIS SESSION CLAIMS UNDER (issue #2243) --------------------------------------------
#
# ONLY IN THE MODES THAT USE IT, so the default path pays for no environment read it does not need.
#
# THE ACCOUNT HALF IS THE GH ACCOUNT AND NOT $identity.Account, and the divergence is deliberate --
# Get-ClaimTag's docstring carries the argument. In one line: the assignee answers WHO SHOULD OWN THIS
# and is the git name, the tag answers WHAT A SECOND SESSION WILL READ AS THE AUTHOR OF MY COMMENT and
# gh writes comments as the gh account. On a split checkout the two differ, and a tag disagreeing with
# the metadata beside it is the ambiguity the tag exists to remove.
$claimTag = $null
if ($Tag -or $Candidates) {
    # $env:COMPUTERNAME is Windows' answer; `hostname` is everyone else's. Read in that order rather
    # than branched on the platform, because a cross-platform shell can carry both and the variable is
    # the cheaper read.
    $machineName = ''
    if ($env:COMPUTERNAME) { $machineName = [string]$env:COMPUTERNAME }
    if (-not $machineName) {
        $hostCapture = Invoke-NativeCapture -FilePath 'hostname' -Arguments @() -Utf8 -DiscardStderr -TimeoutSeconds 10
        if ($hostCapture -and (Test-NativeExitMeasured -Capture $hostCapture) -and $hostCapture.ExitCode -eq 0) {
            $machineName = (@($hostCapture.Output) -join '').Trim()
        }
    }
    $claimTag = Get-ClaimTag -MachineName $machineName -Account $identity.GhAccount

    if (-not $claimTag.Complete) {
        # REFUSED BEFORE ANY READ, because every mode below this line reasons about "mine" against
        # "somebody else's" and an incomplete tag cannot tell them apart. Measured September 17, 2026
        # (#701): three sessions of one round produced an identical or ambiguous string, and the
        # read-back that is supposed to settle a race counts two identical strings as one.
        $missing = switch ($claimTag.Missing) {
            'machine' { 'this machine has no name ($env:COMPUTERNAME is empty and hostname did not answer)' }
            'account' { 'gh names no active account here -- run: gh auth login' }
            default   { 'neither this machine nor gh could be named' }
        }
        Write-Host "[ERROR] there is no complete claim tag to work under: $missing." -ForegroundColor Red
        Write-Host '        A tag is machine/account, and BOTH halves carry weight: the machine tells two sessions' -ForegroundColor Red
        Write-Host '        under one account apart, the account tells two machines under one name apart. Half a tag' -ForegroundColor Red
        Write-Host '        reads like a claim and settles nothing.' -ForegroundColor Red
        exit 1
    }
    Write-Host "  tag: $($claimTag.Tag)"
}

# --- WHICH ISSUES ARE FREE (-Candidates) ----------------------------------------------------------
#
# IT WRITES NOTHING, AND THAT IS THE DESIGN RATHER THAN CAUTION. Choosing and claiming are two steps
# because between them a session still has to ask whether the issue is this repo's work at all -- the
# case the BWJ board measured on September 17, 2026 (#722), where four tickets were mirrored onto the
# board and three of them belonged to a colleague's own experiment. A scan that claimed as it went
# would have taken those three before anybody looked.
if ($Candidates) {
    $listArgs = @('issue', 'list') + $repoArgs + @('--state', 'open', '--limit', "$Limit", '--json', 'number,title,labels,comments')
    $list = Invoke-NativeCapture -FilePath 'gh' -Arguments $listArgs -Utf8 -DiscardStderr -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
    if (-not $list -or -not (Test-NativeExitMeasured -Capture $list) -or $list.ExitCode -ne 0 -or $list.ShortRead) {
        # AN UNREADABLE BACKLOG IS NOT AN EMPTY ONE, and this is the one refusal this mode has. Read the
        # other way round, a tracker that did not answer presents as "nothing is claimed" -- so a sweep
        # would start claiming issues six machines are already holding.
        Write-Host '[ERROR] could not read the open issues -- nothing was judged.' -ForegroundColor Red
        Write-Host '        An unread backlog is not an empty one: every issue would look unclaimed, which is the' -ForegroundColor Red
        Write-Host '        one wrong answer this mode must never give. Check gh (gh auth status) and run it again.' -ForegroundColor Red
        exit 1
    }

    # NOT $candidates, AND THAT IS NOT A STYLE CHOICE. PowerShell variable names are CASE-INSENSITIVE,
    # so `$candidates = ...` assigns to the SWITCH PARAMETER $Candidates two screens up -- which
    # re-applies its [switch] transformation to an array and throws
    # ArgumentTransformationMetadataException at the assignment, reported as "Cannot convert
    # System.Object[] to SwitchParameter" AT THE CALL that produced the value. Measured while writing
    # this (#2243): the message names a type mismatch in a call whose arguments are all correct, and
    # the call is not where the fault is.
    $sweepList = @(Get-SweepCandidates -Json (@($list.Output) -join "`n") -Tag $claimTag.Tag `
                                       -Marker $Marker -SkipLabel $SkipLabel -SkipIssue $SkipIssue)
    if ($sweepList.Count -eq 0) {
        Write-Host '[OK] no open issues on this tracker.' -ForegroundColor Green
        exit 0
    }

    foreach ($candidate in $sweepList) {
        $line = "  #{0,-6} {1,-8} {2}" -f $candidate.Number, $candidate.Verdict, (Format-ForConsole -Text $candidate.Title)
        $colour = switch ($candidate.Verdict) {
            'free'    { 'Green' }
            'mine'    { 'Cyan' }
            'held'    { 'DarkGray' }
            default   { 'DarkGray' }
        }
        Write-Host $line -ForegroundColor $colour
        # THE REASON CAN CARRY A TAG SOMEBODY ELSE WROTE, so it is stripped like every other piece of
        # foreign text this script prints -- a marker lives in an issue comment, which anybody with access
        # to the tracker can write.
        if ($candidate.Reason) { Write-Host "          $(Format-ForConsole -Text $candidate.Reason)" -ForegroundColor DarkGray }
    }

    $free = @($sweepList | Where-Object { $_.Verdict -eq 'free' })
    $mine = @($sweepList | Where-Object { $_.Verdict -eq 'mine' })
    Write-Host ''
    Write-Host "[OK] $($free.Count) free, $($mine.Count) already this tag's, $($sweepList.Count) open in total. Nothing was written." -ForegroundColor Green
    if ($free.Count -gt 0) {
        # THE LOWEST NUMBER, NAMED RATHER THAN TAKEN. Oldest first is the only order six machines agree
        # on without talking to each other, so two sessions starting together collide on ONE issue and
        # then diverge -- and the collision is what the claim's read-back is for.
        Write-Host "     Lowest free: #$($free[0].Number) -- claim it with: claim-issue.ps1 $($free[0].Number) -Tag" -ForegroundColor Green
    }
    exit 0
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
# THE BODY IS ONE MORE FIELD ON A CALL ALREADY BEING MADE (issue #2064), and it is read for one
# purpose: the paths the issue itself cites, which the sixth signal holds against the trunk. Nothing
# else in this script reads it, and it is never printed -- an issue body is untrusted text of
# unbounded length, so what leaves Get-IssuePathCitations is a bounded list of path-shaped tokens
# rather than anything a reader sees verbatim.
#
# AND THE COMMENTS ARE ASKED FOR ONLY IN TAG MODE (issue #2243), where they ARE the claim. The default
# path does not read them: they are unbounded text on a call every pickup makes, and a field nothing
# downstream reads is payload bought for nothing.
$viewFields = if ($Tag) { 'number,title,state,url,assignees,body,comments' } else { 'number,title,state,url,assignees,body' }
$view = Invoke-NativeCapture -FilePath 'gh' -Arguments (@('issue', 'view', $number) + $repoArgs + @('--json', $viewFields)) -Utf8 -DiscardStderr `
                             -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
# AND IT RE-ASKS ONCE WHEN THE EXIT CODE WAS NOT A MEASUREMENT (issue #1931, audited under #2081). This
# is the ONE site in the audited family that re-asks rather than reporting the state as itself, and the
# two conditions that make it sound are both met here and almost nowhere else:
#
#   IT IS IDEMPOTENT AND READ-ONLY. `gh issue view` changes nothing, so a second call cannot double
#   anything -- the same test park-cycle.ps1's own re-ask was argued on (#2068), and the reason the lib
#   cannot make this decision for every caller: it has no way to know that `git push` is not.
#
#   THE COST OF NOT ASKING IS THE WHOLE ASSIGNMENT. This is the first step of an issue-driven session
#   (#1485). Every other site in this audit degrades to a skipped check or a stated unknown; here a
#   non-answer means the session never starts, and it would say so by printing a list of three causes --
#   the number does not exist, gh is not logged in, this account cannot see it -- not one of which can
#   produce an unmeasurable exit code. The reader is sent to `gh auth status` over a race in
#   Start-Process, which is the "confident wrong verdict" #1931 was filed about, at the sharpest site.
#
# ONCE, NOT IN A LOOP: the race is measured at roughly 1 in 300 fresh processes, so a single retry takes
# the residue to about 1 in 90,000, and a loop would trade a rare wrong sentence for an unbounded wait.
# A second unmeasurable read falls through to the branch below, which now names the state.
#
# AND IT DOES NOT RE-ASK A COMMAND THAT NEVER STARTED (issue #2234). An absent `gh` returns a capture
# rather than throwing since that issue, and it sets ExitCodeUnknown on purpose -- so without this
# second condition the guard above would fire on it, print "asking once more" about a race that did not
# happen, and spend a second launch of a command that is not installed. Both halves of the argument for
# the re-ask fail on it too: the retry is still idempotent, but it cannot answer, and the residue it
# buys is 1 rather than 1 in 90,000. The branch below already names the state without a retry.
if ($view -and (Test-NativeCommandStarted -Capture $view) -and -not (Test-NativeExitMeasured -Capture $view)) {
    Write-Host "  [re-asking] gh's exit code came back unmeasurable reading #$number (issue #1931) -- asking once more." -ForegroundColor DarkGray
    $view = Invoke-NativeCapture -FilePath 'gh' -Arguments (@('issue', 'view', $number) + $repoArgs + @('--json', $viewFields)) -Utf8 -DiscardStderr `
                                 -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
}
if (-not $view -or -not (Test-NativeExitMeasured -Capture $view) -or $view.ExitCode -ne 0) {
    Write-Host "[ERROR] could not read issue #$number." -ForegroundColor Red
    if ($view -and $view.TimedOut) {
        # A STALL IS NOT ONE OF THE THREE BELOW, so it does not get their list. Each of those is a
        # verdict gh reached and reported; this is gh reaching none, and sending a reader down a
        # list of causes that cannot produce a hang is the bound announcing itself as the wrong thing.
        Write-Host "        gh did not answer within $NativeCaptureNetworkTimeoutSeconds seconds -- see the [timeout] line above." -ForegroundColor Red
        Write-Host '        That is a stall, not a verdict about the issue: nothing was read and nothing was claimed.' -ForegroundColor Red
        Write-Host '        Check that gh is healthy here (gh auth status) and run this again -- it costs one read.' -ForegroundColor Red
    } elseif ($view -and -not (Test-NativeCommandStarted -Capture $view)) {
        # gh IS NOT INSTALLED HERE (issue #2234), and this arm sits ahead of the unmeasurable one
        # because a not-started capture sets ExitCodeUnknown too -- absorbed there, it would have read
        # as "unmeasurable twice in a row" and sent the reader to a race in Start-Process over a
        # dependency that is simply absent. It also sits ahead of the three below for the reason the
        # stall does: cause 2 says "gh is not logged in here -- run: gh auth status", which is a
        # sentence that cannot be acted on when there is no gh to run it with.
        #
        # THE WHOLE SCRIPT USED TO DIE BEFORE REACHING ANY OF THIS. The read above threw, under this
        # script's own $ErrorActionPreference = 'Stop', so the documented 'no account' refusal never
        # printed on the one machine state it was written for.
        Write-Host '        gh is not installed on this machine, or is not on PATH -- see the [not-started] line above.' -ForegroundColor Red
        Write-Host '        Nothing was read and nothing was claimed. This is a fact about the machine, not about the issue.' -ForegroundColor Red
        Write-Host '        Install the GitHub CLI (https://cli.github.com) and run this again.' -ForegroundColor Red
    } elseif ($view -and -not (Test-NativeExitMeasured -Capture $view)) {
        # THE SECOND UNMEASURABLE READ IN A ROW, which the re-ask above has already spent its one retry
        # on. It belongs with the stall rather than with the three below for the same reason the stall
        # does: each of those is a verdict gh reached, and this is gh reaching one this run could not
        # read. Nothing was claimed, so re-running is free.
        Write-Host "        gh's exit code came back unmeasurable twice in a row (issue #1931) -- see that issue for the race." -ForegroundColor Red
        Write-Host '        That is a fact about this run, not a verdict about the issue: nothing was read and nothing was claimed.' -ForegroundColor Red
        Write-Host '        Run this again -- it costs one read, and two in a row is rare enough to be worth reporting if it repeats.' -ForegroundColor Red
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

# THE FIFTH PICKUP SIGNAL'S INPUT (issue #2018), READ HERE WHILE $facts IS STILL IN HAND. Whether
# there is anything worth comparing branch names against is known before any network call below, so a
# title with no significant words (rare, but Get-SignificantWords -MinLength floors it) skips that
# whole scan rather than fetching and listing branches for nothing.
$titleWords = @(Get-SignificantWords -Text ([string]$facts.title))

Write-Host "  #$($facts.number)  $($facts.state)  $title"
if ($assignees.Count -gt 0) { Write-Host "  assignees: $($assignees -join ', ')" }

# --- MAY IT BE CLAIMED, BY THIS TAG (issue #2243) -------------------------------------------------
#
# THE TAG VERDICT REPLACES THE ASSIGNEE VERDICT AND DOES NOT SIT BESIDE IT. Both would refuse the
# other's free issue: the assignee path refuses on the colleague's name a sweep must work past, and the
# tag path refuses on a marker the assignee path cannot see. Running both means whichever is stricter
# wins, and that is the assignee -- which is the behaviour -Tag exists to leave behind.
#
# IT IS MAPPED ONTO $verdict RATHER THAN BRANCHING AROUND EVERYTHING BELOW, so the parked-fix scan, the
# prerequisite scan and the title-overlap scan all run in tag mode unchanged. Those are the signals
# #1853, #2018 and #2064 added, and a sweep needs them at least as much as a pickup does: a branch
# somebody parked months ago carries no claim marker at all, so the tag says free and the commit
# messages say otherwise.
$tagVerdict = $null
$claimRecords = @()
if ($Tag) {
    $claimRecords = @(Get-ClaimRecords -Json $viewJson -Marker $Marker)
    $tagVerdict = Get-TagClaimVerdict -Tag $claimTag.Tag -State ([string]$facts.state) -Records $claimRecords

    if ($claimRecords.Count -gt 0) {
        foreach ($record in $claimRecords) {
            $mineMark = if ($record.Tag -ieq $claimTag.Tag) { ' (this session)' } else { '' }
            # Stripped, all three: the tag and the author come out of a comment body, and the timestamp is
            # printed beside them rather than trusted to be shaped like one.
            Write-Host "  claim: $(Format-ForConsole -Text $record.Tag)$mineMark  $(Format-ForConsole -Text $record.CreatedAt)  by $(Format-ForConsole -Text $record.Author)" -ForegroundColor DarkGray
        }
    }

    # -Verify IS A READING AND STOPS HERE. It is the resume step of a sweep: hours after the work was
    # parked, an approval names a branch, and the question is whether THIS tag is the one that built it.
    # Answering with an exit code rather than with prose is the point -- the caller is a script.
    if ($Verify) {
        if ($tagVerdict.Code -eq 'already-yours') {
            Write-Host "[OK] #$number is held by this tag ($($claimTag.Tag)) -- resuming it is resuming your own work." -ForegroundColor Green
            Write-Host "     $($facts.url)"
            exit 0
        }
        $held = if (@($tagVerdict.Holders).Count -gt 0) { " -- it is held by $(Format-ForConsole -Text (@($tagVerdict.Holders) -join ', '))" } else { ' -- nobody holds it' }
        Write-Host "[NO] #$number is NOT held by this tag ($($claimTag.Tag))$held." -ForegroundColor Yellow
        Write-Host '     Do not resume it. A branch built under another tag is another session''s work, and on this' -ForegroundColor Yellow
        Write-Host '     machine it is indistinguishable from your own once it is checked out.' -ForegroundColor Yellow
        Write-Host "     $($facts.url)" -ForegroundColor Yellow
        exit 1
    }

    # -Release DROPS THIS TAG'S CLAIM AND NOTHING ELSE. The losing side of a race runs it, and so does a
    # session giving an issue back. It removes only markers carrying THIS tag: a comment written by
    # another session is another session's record, and deleting it would erase the claim that beat us.
    if ($Release) {
        $mineRecords = @($claimRecords | Where-Object { $_.Tag -ieq $claimTag.Tag })
        if ($mineRecords.Count -eq 0) {
            Write-Host "[OK] #$number carries no claim of this tag ($($claimTag.Tag)) -- nothing to release." -ForegroundColor Green
            exit 0
        }
        if ($DryRun) {
            Write-Host "[DRY RUN] would delete $($mineRecords.Count) claim comment(s) of '$($claimTag.Tag)' and remove the assignee. Nothing was written." -ForegroundColor Yellow
            exit 0
        }
        $failed = 0
        foreach ($record in $mineRecords) {
            if (-not $record.Id) { $failed++; continue }
            # THE GRAPHQL MUTATION RATHER THAN THE REST ROUTE, because the id in hand is the node id
            # `gh issue view --json comments` returns ('IC_...'). REST wants the numeric database id,
            # which would mean a second read of the same comments to learn a number we already have an
            # identifier for.
            $deleteArgs = @('api', 'graphql', '-f', 'query=mutation($id:ID!){deleteIssueComment(input:{id:$id}){clientMutationId}}', '-f', "id=$($record.Id)")
            $del = Invoke-NativeCapture -FilePath 'gh' -Arguments $deleteArgs -Utf8 -DiscardStderr -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
            if (-not $del -or -not (Test-NativeExitMeasured -Capture $del) -or $del.ExitCode -ne 0) { $failed++ }
        }

        # The assignee goes with it, and its failure is a WARNING rather than a stop: the marker is the
        # claim, so an assignee left behind is untidy where a marker left behind is a held issue.
        if ($assignees -contains $identity.Account) {
            $unassign = Invoke-NativeCapture -FilePath 'gh' -Arguments (@('issue', 'edit', $number) + $repoArgs + @('--remove-assignee', $identity.Account)) -Utf8 `
                                             -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
            if (-not $unassign -or -not (Test-NativeExitMeasured -Capture $unassign) -or $unassign.ExitCode -ne 0) {
                Write-Host "[WARNING] the assignee '$($identity.Account)' could not be removed from #$number." -ForegroundColor Yellow
                Write-Host "          The claim itself is released -- the marker is what another session reads." -ForegroundColor Yellow
            }
        }

        if ($failed -gt 0) {
            Write-Host "[ERROR] $failed of $($mineRecords.Count) claim comment(s) could not be deleted -- #$number MAY STILL READ AS HELD." -ForegroundColor Red
            Write-Host '        That is the direction that costs: a marker left behind parks the issue against every' -ForegroundColor Red
            Write-Host '        other machine. Delete the comment by hand, or run this again.' -ForegroundColor Red
            Write-Host "        $($facts.url)" -ForegroundColor Red
            exit 1
        }
        Write-Host "[OK] #$number released by $($claimTag.Tag) -- it is free for the next machine." -ForegroundColor Green
        Write-Host "     $($facts.url)"
        exit 0
    }

    # A FOREIGN ASSIGNEE IS A NOTE HERE AND A REFUSAL THERE, and this is the whole inversion. Measured
    # on the BWJ board, September 17, 2026: three of fourteen open issues carried the name of the
    # colleague who owns the ticket, months old, on work that was the ordinary business of that round.
    $foreignAssignees = @($assignees | Where-Object { $_ -ine $identity.Account })
    if ($foreignAssignees.Count -gt 0) {
        Write-Host "  [note] assigned to $($foreignAssignees -join ', ') -- in tag mode that is not a claim." -ForegroundColor DarkGray
        Write-Host '         The marker comments above are. An assignee months old is whose TICKET this is.' -ForegroundColor DarkGray
    }

    switch ($tagVerdict.Code) {
        'no-tag' {
            # Unreachable in practice -- the tag was proven complete before any read -- and kept because
            # the verdict has five codes and a switch that silently falls through one of them is how a
            # later change gets a claim it never judged.
            Write-Host '[ERROR] there is no tag to claim under -- nothing was written.' -ForegroundColor Red
            exit 1
        }
        'closed' {
            Write-Host "[REFUSED] issue #$number is CLOSED -- nothing was claimed." -ForegroundColor Red
            Write-Host '          A sweep claiming closed work builds it again in full and finds out at the merge.' -ForegroundColor Red
            Write-Host "          $($facts.url)" -ForegroundColor Red
            exit 1
        }
        'held' {
            Write-Host "[REFUSED] issue #$number is claimed by $(Format-ForConsole -Text (@($tagVerdict.Holders) -join ', ')) -- nothing was claimed." -ForegroundColor Red
            Write-Host '          Another machine is mid-flight on it and its branch is somewhere this session cannot' -ForegroundColor Red
            Write-Host '          see. Take the next free number instead -- claim-issue.ps1 -Candidates names it.' -ForegroundColor Red
            Write-Host "          $($facts.url)" -ForegroundColor Red
            exit 1
        }
    }

    # MAPPED ONTO THE ASSIGNEE VERDICT'S VOCABULARY so that everything below reads one variable: 'claim'
    # writes, 'skip' is a resume. The Others field carries the foreign assignees rather than the rival
    # tags -- a rival tag refused above and never reaches here.
    $verdict = [pscustomobject]@{
        Action = if ($tagVerdict.Code -eq 'already-yours') { 'skip' } else { 'claim' }
        Code   = $tagVerdict.Code
        Others = $foreignAssignees
    }
}

# --- MAY IT BE CLAIMED ----------------------------------------------------------------------------
if (-not $Tag) {
    $verdict = Get-ClaimVerdict -Account $identity.Account -State ([string]$facts.state) -Assignees $assignees
}

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
#
# AND THE SIXTH SIGNAL READS THE SAME FLAG ONE AXIS OVER (#2064). A surfaced branch can be in your way
# without being a rival, and the verdict above cannot say so: it asks who is mid-flight, not whether
# your route runs through their branch. Same advisory bound, same effect on the closing line.
$foreignParked = $false
$prerequisiteFound = $false
if ($verdict.Action -eq 'claim' -or $verdict.Action -eq 'skip') {
    $scanPattern = Get-IssueMentionPattern -Issue ([int]$number)

    # EVERY BRANCH THE TWO SCANS BELOW SURFACE, COLLECTED AS THEY GO (#2064). The sixth signal weighs
    # exactly this set and nothing else: a branch neither scan had a reason to name is a branch the
    # reader is not being pointed at, so measuring it would be noise bought with a git call.
    $surfacedBranches = New-Object System.Collections.Generic.List[string]

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

    if ($trunkRefs.Count -gt 0 -and ($scanPattern -or $titleWords.Count -gt 0)) {
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
        if ($scanPattern) {
            $logArgs = @('-C', $repoRoot, 'log', '--all', '-E', "--grep=$scanPattern", '--format=%H%x1f%an%x1f%at%x1f%s', '--not') + $trunkRefs
            $scanLog = Invoke-NativeCapture -FilePath 'git' -Arguments $logArgs -Utf8 -DiscardStderr
            if (-not $scanLog -or -not (Test-NativeExitMeasured -Capture $scanLog) -or $scanLog.ExitCode -ne 0 -or $scanLog.ShortRead) {
                # THE UNMEASURABLE CODE GETS ITS OWN CLAUSE (issue #1931, audited under #2081), ahead of
                # the exit-code one it was falling into: `$null -ne 0` is true, so the skip line read
                # "it exited " with nothing after it. Skipping the scan is unchanged and is right -- it is
                # a warning-only signal -- so what this buys is a reader who knows to run it again.
                $why = if (-not $scanLog) { 'it could not be run at all' }
                       elseif (-not (Test-NativeExitMeasured -Capture $scanLog)) { 'its exit code came back unmeasurable (issue #1931), so this run could not judge the read' }
                       elseif ($scanLog.ShortRead) { 'its capture was still being written when it was read' }
                       else { "it exited $($scanLog.ExitCode)" }
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
                    # AUDITED UNDER #2081, WITH THE FOUR `-eq 0` READS BELOW IT (the trunk ls-tree, the
                    # rev-list count, the per-branch ls-tree) AND LEFT AS THEY ARE. An unmeasurable exit
                    # code (#1931) makes this `continue` and makes each of those keep its already-chosen
                    # neutral value -- an empty $missingFromTrunk, an $ahead of -1, an empty $onlyThere --
                    # every one of which the report renders as "not measured" rather than as a finding.
                    # These signals warn and never refuse, so under-reporting is their safe direction and
                    # a third state would buy a sentence about one commit inside a scan that already
                    # states its own caps. Recorded as deliberate; that is this family's audited verdict.
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
                        # THE SAME NAMES AS GIT SPELLS THEM, carried BESIDE the stripped copies rather
                        # than instead of them (#2075). Branches is what the report prints and stays
                        # stripped; GitBranches is what the sixth signal ASKS GIT ABOUT -- `rev-list
                        # --count` and `ls-tree` -- and Format-ForConsole replaces each stripped
                        # character with a SPACE, so a stripped name is a ref git does not have. Both
                        # of those calls pass -DiscardStderr and are guarded on their exit code, so the
                        # scan reported no dependency without printing or erroring: indistinguishable
                        # from there being none, and only ever in the adversarial case the strip exists
                        # for. Same seam the weighing loop below already draws for itself, where Branch
                        # is stripped into the printed record and $branch is not.
                        GitBranches = @($branches)
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
                # The same records the report prints from, so the sixth signal weighs exactly what the
                # reader was just pointed at -- a finding whose branches were all excluded is already gone.
                # OFF GitBranches AND NOT Branches (#2075): same records, one field over. The sixth
                # signal QUERIES these names rather than printing them, so it needs the spelling git
                # has; "the records the report prints from" was right about WHICH records and wrong
                # about which field of them.
                foreach ($f in $findings) {
                    foreach ($b in @(@($f.GitBranches) | Where-Object { $_ })) { $surfacedBranches.Add([string]$b) | Out-Null }
                }
            }
        }

        # THE FIFTH SIGNAL (#2018): EVERY BRANCH OFF THE TRUNK, MATCHED ON THE ISSUE'S TITLE, NOT ITS
        # NUMBER. This runs whether or not the number-scan above found anything, and whether or not it
        # even ran -- a branch named for the subject (see claim-issue-lib.ps1's own section header)
        # carries no commit the scan above can match, on this claim or any future one, however long the
        # branch grows. Same fetch as above ($fetch was already attempted), so this costs one more `git
        # branch -a` and nothing more against the network.
        if ($titleWords.Count -gt 0) {
            $allBranchesCapture = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $repoRoot, 'branch', '-a') -Utf8 -DiscardStderr
            if (-not $allBranchesCapture -or $allBranchesCapture.ExitCode -ne 0) {
                Write-Host "  [title-overlap scan skipped] git branch -a was not readable." -ForegroundColor DarkGray
            } else {
                $allBranches = @(Get-ContainingBranchNames -Text ((@($allBranchesCapture.Output) -join "`n")) -Exclude $excludeBranches)
                $overlaps = @(Get-TitleOverlapBranches -Title ([string]$facts.title) -Branches $allBranches)
                # THE BRANCH NAME IS THE ONLY UNTRUSTED FIELD THIS BLOCK PRINTS, and it reached the
                # terminal raw until #2069 -- the same class #1858 closed one signal up, off the same
                # `git branch -a` text, reintroduced by a block written afterwards that never acquired
                # the call. `git check-ref-format` enforces \p{Cc} and ACCEPTS \p{Cf}, so a branch
                # fetched from origin can carry U+202E or a zero-width run into the one line whose
                # whole job is to say which branch to go and read before writing anything.
                #
                # STRIPPED ON THE WAY OUT, NOT ON THE WAY IN, and that is what #2064 decided one block
                # down rather than a preference: $overlaps feeds the sixth signal, which puts each name
                # back to git (`rev-list --count`, `ls-tree`), so a name this strip has rewritten is a
                # ref git does not have -- and the scan would report nothing where it should report a
                # prerequisite, in exactly the adversarial case the strip exists for. The exclusion
                # above needs the git spelling for the same reason. So the record keeps the ref as git
                # wrote it and the REPORT gets a stripped copy: the same seam the weighing loop below
                # draws, where Branch is stripped into the printed record and $branch is not.
                # The `shares:` words need nothing -- Get-SignificantWords tokenizes on [^A-Za-z0-9]+,
                # so nothing outside that class survives into them.
                $safeOverlaps = @($overlaps | ForEach-Object {
                    [pscustomobject]@{ Branch = (Format-ForConsole -Text ([string]$_.Branch)); SharedWords = @($_.SharedWords) }
                })
                $overlapReport = @(Format-TitleOverlapReport -Issue ([int]$number) -Title ([string]$facts.title) -Overlaps $safeOverlaps)
                foreach ($line in $overlapReport) {
                    Write-Host "  $line" -ForegroundColor Yellow
                }
                foreach ($o in $overlaps) { $surfacedBranches.Add([string]$o.Branch) | Out-Null }
            }
        }

        # THE SIXTH SIGNAL (#2064): IS A SURFACED BRANCH A PREREQUISITE RATHER THAN A COMPETITOR? Every
        # signal above asks who is mid-flight; this asks whether the route to the issue runs through
        # somebody's unlanded branch. See the block comment above Get-IssuePathCitations for the
        # measurement -- #2051's subject existed only on the branch the fourth signal had just named as
        # a possible rival, and the ownership verdict pointed at the wrong question.
        #
        # IT COSTS NOTHING ON A QUIET CLAIM, which is the ordinary one: no branch surfaced, no git call
        # made. Where something was surfaced the bill is one `rev-list --count` per branch plus ONE
        # `ls-tree` on the trunk carrying every cited path at once -- and the per-branch `ls-tree` only
        # for the paths the trunk turned out to lack, which is normally none. Trunk first is what keeps
        # the ordinary shape at O(branches) instead of O(branches x paths).
        if ($surfacedBranches.Count -gt 0) {
            # THE REMOTE TRUNK WHERE THERE IS ONE, and that is a correctness choice rather than a
            # preference: a local trunk sitting behind origin reports commits as unlanded that have in
            # fact landed, which inflates a branch's weight in exactly the direction this signal must
            # not err. $trunkRefs was probed above, in @(local, remote) order, so the remote is picked
            # by name rather than by position.
            $weighTrunk = if ($trunkRefs -contains "origin/$trunkBranch") { "origin/$trunkBranch" } else { [string]$trunkRefs[0] }

            # A BOUND ON THE BRANCHES TOO, for the same reason the containment loop has one: a
            # pathological issue can surface more branches than a reader will act on, and the overflow
            # is stated rather than swallowed.
            $maxWeighedBranches = 5
            $allSurfaced = @($surfacedBranches | Select-Object -Unique)
            $weighed = @($allSurfaced | Select-Object -First $maxWeighedBranches)
            if ($allSurfaced.Count -gt $weighed.Count) {
                Write-Host "  [branch-weight scan] $($allSurfaced.Count) branches were surfaced; the first $($weighed.Count) were weighed." -ForegroundColor DarkGray
            }

            # ONE MORE THAN WILL BE USED, so that a truncation here can be STATED like the other two
            # in this block. The reader function returns paths rather than a record, and an extra
            # element is the cheapest evidence that a ninth existed -- one regex pass over a string
            # already in memory, no second git call, and no contract change for a pure function three
            # suites hold. The notice says 'more than N' rather than a count, because that is exactly
            # what a +1 probe measured: a cap a reader cannot see is the defect the parked-fix scan's
            # own overflow line exists to remove, one layer in.
            $maxCitedPaths = 8
            $probedPaths = @(Get-IssuePathCitations -Text ([string]$facts.body) -MaxPaths ($maxCitedPaths + 1))
            $citedPaths = @($probedPaths | Select-Object -First $maxCitedPaths)
            if ($probedPaths.Count -gt $citedPaths.Count) {
                Write-Host "  [branch-weight scan] #$number cites more than $maxCitedPaths paths; the first $maxCitedPaths were held against $weighTrunk." -ForegroundColor DarkGray
            }
            # WHICH OF THEM THE TRUNK ALREADY CARRIES -- one call, every path as its own pathspec.
            # ls-tree answers by omission and exits 0 either way, so the verdict is which came back;
            # where the call itself fails, $missingFromTrunk stays empty and the report falls to its
            # weight-only ending rather than claiming a dependency it could not measure.
            $missingFromTrunk = @()
            if ($citedPaths.Count -gt 0) {
                $trunkTree = Invoke-NativeCapture -FilePath 'git' -Arguments (@('-C', $repoRoot, 'ls-tree', $weighTrunk, '--') + $citedPaths) -Utf8 -DiscardStderr
                if ($trunkTree -and $trunkTree.ExitCode -eq 0) {
                    $onTrunk = @(Get-LsTreePaths -Text ((@($trunkTree.Output) -join "`n")))
                    $trunkSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$onTrunk, [System.StringComparer]::Ordinal)
                    $missingFromTrunk = @($citedPaths | Where-Object { -not $trunkSet.Contains($_) })
                }
            }

            $weights = @()
            foreach ($branch in $weighed) {
                $ahead = -1
                $countCapture = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $repoRoot, 'rev-list', '--count', "$weighTrunk..$branch") -Utf8 -DiscardStderr
                if ($countCapture -and $countCapture.ExitCode -eq 0) {
                    $rawCount = ((@($countCapture.Output) -join '')).Trim()
                    if ($rawCount -match '^\d+$') { $ahead = [int]$rawCount }
                }
                $onlyThere = @()
                if ($missingFromTrunk.Count -gt 0) {
                    $branchTree = Invoke-NativeCapture -FilePath 'git' -Arguments (@('-C', $repoRoot, 'ls-tree', $branch, '--') + $missingFromTrunk) -Utf8 -DiscardStderr
                    if ($branchTree -and $branchTree.ExitCode -eq 0) {
                        $onlyThere = @(Get-LsTreePaths -Text ((@($branchTree.Output) -join "`n")))
                    }
                }
                $weights += [pscustomobject]@{
                    # The branch name came off a pushed ref and is sanitised exactly like the other two
                    # fields of pushed text this script prints; the paths came out of an issue body, and
                    # Get-IssuePathCitations' character class is their bound.
                    Branch    = (Format-ForConsole -Text $branch)
                    Ahead     = $ahead
                    OnlyThere = @($onlyThere | ForEach-Object { Format-ForConsole -Text $_ })
                }
            }

            $prereqReport = @(Format-PrerequisiteReport -Issue ([int]$number) -Branches $weights `
                                                        -CitedPathCount $citedPaths.Count -TrunkLabel $weighTrunk)
            foreach ($line in $prereqReport) {
                Write-Host "  $line" -ForegroundColor Yellow
            }
            if (@($weights | Where-Object { @(@($_.OnlyThere) | Where-Object { $_ }).Count -gt 0 }).Count -gt 0) {
                $prerequisiteFound = $true
            }
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
        # THE HOLDER MAY BE A SECOND ACCOUNT AUTHENTICATED ON THIS MACHINE (issue #2207). Printed
        # ABOVE the "pick another issue, or ask whoever holds it" line on purpose: that line describes
        # a colleague elsewhere, and where this note fires it is the sentence being corrected. The
        # verdict, the exit code and the five verdicts are untouched -- this adds a reading, not a
        # rule.
        $localHolders = @(Get-LocalAccountHolders -Holders $verdict.Others -LocalAccounts $ghAccounts)
        foreach ($line in @(Format-ConcurrentSessionNote -LocalHolders $localHolders -Account $identity.Account)) {
            Write-Host "          $line" -ForegroundColor Yellow
        }
        Write-Host '          Pick another issue, or ask whoever holds it. There is deliberately no flag past this:' -ForegroundColor Red
        Write-Host '          the way through is a conversation, and a switch cannot have one.' -ForegroundColor Red
        Write-Host "          $($facts.url)" -ForegroundColor Red
        exit 1
    }
    'already-yours' {
        # WHOSE IT IS DEPENDS ON WHICH CLAIM WAS MADE, and naming the wrong one here is how a sweep's
        # resume goes to another session's branch: 'yours' under -Tag means this machine AND this
        # account, where the assignee alone means the account on any machine.
        $holderName = if ($Tag) { "tag $($claimTag.Tag)" } else { "'$($identity.Account)'" }
        Write-Host "[OK] #$number is already yours ($holderName) -- nothing to write." -ForegroundColor Green
        Write-Host '     A resume, then: read the branch and its document before you carry the work.' -ForegroundColor Green
        # A RESUME IS WHERE THE PARKED-FIX VERDICT MATTERS MOST, not least: the other session's branch
        # is already in this working copy, indistinguishable from your own, and the assignee field
        # cannot name a machine. So the one line that points forward says which branch it means.
        if ($foreignParked) {
            Write-Host '     BUT NOT THAT BRANCH: somebody else pushed to one of them -- see the parked-fix' -ForegroundColor Yellow
            Write-Host '     verdict above, and ask them before you carry it.' -ForegroundColor Yellow
        }
        # AND A RESUME IS WHERE AN ORDERING BITES HARDEST (#2064): the branch you are carrying may need
        # somebody else's to land first, and nothing in this working copy says so -- the file the work
        # needs is either there or it is not, and 'not there' reads as 'not written yet'.
        if ($prerequisiteFound) {
            Write-Host '     AND CHECK THE ORDER: a branch above carries a file this issue names and the trunk' -ForegroundColor Yellow
            Write-Host '     does not -- see the prerequisite verdict before you carry this any further.' -ForegroundColor Yellow
        }
        Write-Host "     $($facts.url)"
        exit 0
    }
}

# --- CLAIM IT -------------------------------------------------------------------------------------
if ($DryRun) {
    $who = if ($Tag) { "tag $($claimTag.Tag) (a marker comment, and the assignee '$($identity.Account)' beside it)" } else { "'$($identity.Account)'" }
    Write-Host "[DRY RUN] would claim #$number for $who. Nothing was written." -ForegroundColor Yellow
    Write-Host "          $($facts.url)"
    exit 0
}

# THE MARKER GOES FIRST, AND THE ORDER IS THE RACE RULE ITSELF (issue #2243). The winner is the
# EARLIEST marker comment, so every step taken before writing it is time added to this session's own
# timestamp -- writing the assignee first would hand the issue to a machine that started later.
if ($Tag) {
    $comment = Invoke-NativeCapture -FilePath 'gh' -Arguments (@('issue', 'comment', $number) + $repoArgs + @('--body', (Format-ClaimComment -Tag $claimTag.Tag -Marker @($Marker)[0]))) -Utf8 `
                                    -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
    if (-not $comment -or -not (Test-NativeExitMeasured -Capture $comment) -or $comment.ExitCode -ne 0) {
        # THE SAME READING AS THE ASSIGNEE WRITE BELOW, for the same reason: a write that did not answer
        # may be on the tracker. It stops rather than carrying on, and re-running is safe -- a marker
        # that did land comes back as 'already-yours', which is a complete answer.
        Write-Host "[ERROR] the claim comment on #$number did not land, so the issue is NOT claimed." -ForegroundColor Red
        Write-Host '        The marker IS the claim in tag mode -- without it nothing on the tracker says this' -ForegroundColor Red
        Write-Host '        machine is working here, and a second machine would take the same issue.' -ForegroundColor Red
        Write-Host '        Run this again: a marker that did land comes back as already-yours.' -ForegroundColor Red
        Write-Host "        $($facts.url)" -ForegroundColor Red
        exit 1
    }
}

$edit = Invoke-NativeCapture -FilePath 'gh' -Arguments (@('issue', 'edit', $number) + $repoArgs + @('--add-assignee', $identity.Account)) -Utf8 `
                             -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds

# IN TAG MODE THE ASSIGNEE IS NOT THE CLAIM, SO ITS FAILURE IS NOT A FAILED CLAIM (issue #2243). The
# three branches below all stop, correctly, where the assignee IS the claim. Here the marker is already
# on the tracker -- every other machine reads the issue as held -- and stopping now would leave a claim
# standing with a session told it had none, which is the one state the two-writes order can produce and
# the worst one to report wrongly. So it is a warning and the run carries on to the read-back.
$assigneeLanded = ($edit -and (Test-NativeExitMeasured -Capture $edit) -and $edit.ExitCode -eq 0)
if ($Tag -and -not $assigneeLanded) {
    Write-Host "[WARNING] the claim marker landed on #$number but the assignee '$($identity.Account)' did not." -ForegroundColor Yellow
    Write-Host '          The issue IS claimed -- the marker is what another machine reads. What is missing is the' -ForegroundColor Yellow
    Write-Host '          tracker''s own visible signal, so the issue looks untouched in a list view.' -ForegroundColor Yellow
    if ($identity.Split) {
        Write-Host "          This checkout has a split identity, so the likely cause is that '$($identity.Account)'" -ForegroundColor Yellow
        Write-Host "          cannot be assigned in this repo while gh acts as '$($identity.GhAccount)'." -ForegroundColor Yellow
    }
}
if ($Tag -and $edit -and $edit.TimedOut) {
    Write-Host "          (the assignee write did not answer within $NativeCaptureNetworkTimeoutSeconds seconds -- it may yet have landed)" -ForegroundColor Yellow
}

if (-not $Tag -and $edit -and $edit.TimedOut) {
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
if ($Tag -and $edit -and -not (Test-NativeCommandStarted -Capture $edit)) {
    # THE $Tag HALF, beside the timeout parenthetical above it and for the same reason: under -Tag the
    # marker comment has already landed, so a failed assignee write is a warning the run carries on
    # from rather than a stop. What differs is only the sentence -- a write that never started is the
    # one non-answer that IS known, so this one does not hedge about whether it may yet have landed.
    Write-Host '          (the assignee write never ran -- gh is not on PATH here, issue #2234 -- so it did NOT land)' -ForegroundColor Yellow
}

if (-not $Tag -and $edit -and -not (Test-NativeCommandStarted -Capture $edit)) {
    # A WRITE THAT NEVER STARTED IS THE ONE NON-ANSWER THAT *IS* KNOWN (issue #2234), which is why it
    # sits ahead of the unmeasured arm below rather than inside it. Both other arms say "THIS RUN DOES
    # NOT KNOW whether the claim landed -- it may be on the tracker already", and that is exactly right
    # for a write that reached the network. It is exactly WRONG here: nothing was sent, because there was
    # no process to send it. Absorbed below -- which the shared ExitCodeUnknown flag would do -- this
    # script would tell a session to go and look on the tracker for a write that provably never left the
    # machine, which is the same class of confident wrong verdict #1931 was filed about.
    #
    # NORMALLY UNREACHABLE, AND WRITTEN ANYWAY. The read at the top of this script now refuses on the
    # same state, so an absent gh stops long before here; what this covers is gh disappearing between
    # the two calls. The arm exists because the sentence's correctness must not depend on an upstream
    # guard staying where it is -- that coupling is invisible from this block, which is where a later
    # reader will be standing.
    Write-Host '[ERROR] gh could not be started for the claim -- it is not on PATH here (issue #2234).' -ForegroundColor Red
    Write-Host '        NOTHING WAS SENT, so unlike a stall this is not an unknown: the claim did not land, and' -ForegroundColor Red
    Write-Host '        there is nothing to go and look for on the tracker. The issue is still unclaimed.' -ForegroundColor Red
    Write-Host '        Install the GitHub CLI (https://cli.github.com) and run this again.' -ForegroundColor Red
    Write-Host "        $($facts.url)" -ForegroundColor Red
    exit 1
}
if (-not $Tag -and $edit -and -not (Test-NativeExitMeasured -Capture $edit)) {
    # THE SECOND PLACE A NON-ANSWER IS NOT A FAILURE, and it is the block above one field over (issue
    # #1931, audited under #2081). `$null -ne 0` is true, so an unmeasurable code took the arm below and
    # printed "the claim failed -- #N is NOT yours" -- about a write that may be sitting on the tracker,
    # and then went on to blame a split identity for it. That is the worst sentence this script can say
    # wrongly: a session told the claim failed either stops, or claims again under another account.
    #
    # IT DOES NOT RE-ASK, unlike the READ at the top of this script. The re-ask there is sound precisely
    # because `gh issue view` changes nothing; this is a write, and a write whose outcome is unknown is
    # the one thing that must never be repeated blind. Re-running the SCRIPT is the way out, and it is
    # safe for the reason the timeout arm above already gives: the pre-write read reports 'already yours'
    # if it landed, which is a complete answer.
    Write-Host "[ERROR] 'gh issue edit' ran but its exit code could not be measured (issue #1931)." -ForegroundColor Red
    Write-Host '        THIS RUN DOES NOT KNOW whether the claim landed -- the write may be on the tracker already.' -ForegroundColor Red
    Write-Host '        It is NOT evidence that the claim was refused, so do not re-claim under another account.' -ForegroundColor Red
    Write-Host '        Look, then run this again -- a claim that did land comes back as "already yours".' -ForegroundColor Red
    Write-Host "          gh issue view $number --json assignees" -ForegroundColor Red
    Write-Host "        $($facts.url)" -ForegroundColor Red
    exit 1
}
if (-not $Tag -and -not $assigneeLanded) {
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

# --- WHO WON, IF TWO MACHINES CLAIMED AT ONCE (issue #2243) ---------------------------------------
#
# THE READ-BACK IN TAG MODE ANSWERS A DIFFERENT QUESTION FROM THE ONE BELOW, which is why it is its own
# block and exits rather than falling through. Below, the question is whether the write landed. Here it
# is WHO HOLDS THE ISSUE: two machines can both have written a marker in the same second, both
# successfully, and the tracker's timestamps are the only record either of them can read the same way.
#
# AND IT NAMES THE WINNER RATHER THAN THE LOSER. The prompt this replaces said "if you see a claim that
# is not yours, let go" -- under which both sessions let go and the issue is released by everybody who
# wanted it. Resolve-ClaimRace picks the earliest marker, so exactly one session keeps it and the
# others release. See its docstring for the tie-break.
if ($Tag) {
    $raceRead = Invoke-NativeCapture -FilePath 'gh' -Arguments (@('issue', 'view', $number) + $repoArgs + @('--json', 'comments')) -Utf8 -DiscardStderr `
                                     -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
    $raceOk = [bool]($raceRead -and (Test-NativeExitMeasured -Capture $raceRead) -and $raceRead.ExitCode -eq 0 -and -not $raceRead.ShortRead)
    if (-not $raceOk) {
        # UNVERIFIED IS NOT LOST, and it does not release. The marker was written and gh accepted it, so
        # the likeliest state by far is a claim that landed and a read that did not -- and releasing on
        # a failed READ would hand back work this session is holding. It stops instead of carrying on,
        # because carrying on means building on an unsettled race.
        Write-Host "[WARNING] the claim was written, but the read-back of #$number did not answer." -ForegroundColor Yellow
        Write-Host '          So this run cannot say whether a second machine claimed it in the same breath. Do not' -ForegroundColor Yellow
        Write-Host '          start building yet -- run this again, or look:' -ForegroundColor Yellow
        Write-Host "            claim-issue.ps1 $number -Tag -Verify" -ForegroundColor Yellow
        Write-Host "          $($facts.url)" -ForegroundColor Yellow
        exit 1
    }

    $race = Resolve-ClaimRace -Tag $claimTag.Tag -Records @(Get-ClaimRecords -Json (@($raceRead.Output) -join "`n") -Marker $Marker)

    if ($race.Action -eq 'absent') {
        Write-Host "[ERROR] gh accepted the claim comment, but no marker for $($claimTag.Tag) is on #$number." -ForegroundColor Red
        Write-Host '        Treat the issue as UNCLAIMED. Nothing on the tracker says this machine is working here.' -ForegroundColor Red
        Write-Host "        $($facts.url)" -ForegroundColor Red
        exit 1
    }

    if ($race.Action -eq 'release') {
        # THE LOSER RELEASES ITSELF, HERE, RATHER THAN LEAVING IT TO THE CALLER. A marker left behind
        # parks the issue against every other machine, and the session that knows it lost is the only
        # one that can tell the difference between its own marker and the winner's.
        Write-Host "[RACE] #$number went to $(Format-ForConsole -Text $race.Winner) -- their marker is earlier than this one." -ForegroundColor Yellow
        $releaseArgs = @($number, '-Tag', '-Release', '-Marker') + @($Marker)
        if ($RootOverride) { $releaseArgs += @('-RootOverride', $RootOverride) }
        & $PSCommandPath @releaseArgs
        Write-Host '       Nothing was lost: a claim, not work. Take the next free number --' -ForegroundColor Yellow
        Write-Host '         claim-issue.ps1 -Candidates' -ForegroundColor Yellow
        exit 1
    }

    $rivalNote = if (@($race.Rivals).Count -gt 0) { " (ahead of $(Format-ForConsole -Text (@($race.Rivals) -join ', ')))" } else { '' }
    Write-Host "[OK] #$number claimed by $($claimTag.Tag)$rivalNote." -ForegroundColor Green
    Write-Host "     $title"
    if ($foreignParked) {
        Write-Host '     Read the issue -- then settle the branch named above BEFORE you open one of your own.' -ForegroundColor Yellow
    } else {
        Write-Host '     Read the issue, then open the branch (new-branch) -- in this same turn, without asking' -ForegroundColor Green
        Write-Host '     whether to go on.' -ForegroundColor Green
    }
    Write-Host "     $($facts.url)"
    exit 0
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
    #
    # AND THE UNMEASURABLE EXIT CODE IS THE FOURTH (issue #1931, audited under #2081), by the same
    # argument again: it is a read whose outcome this run could not judge, so it says nothing about the
    # tracker -- and `$readOk` already excludes it, because that test is written `-eq 0` and `$null` is
    # not. So the verdict was right and only the REASON was wrong: the arm below would have printed
    # "exited " with nothing after it. It is named before that arm for exactly the reason the short read
    # is, one paragraph up.
    $why = if ($after -and $after.TimedOut) {
        "did not answer within $NativeCaptureNetworkTimeoutSeconds seconds"
    } elseif ($after -and $after.ShortRead) {
        'exited 0 with its capture still being written, so what came back may be truncated'
    } elseif ($after -and -not (Test-NativeExitMeasured -Capture $after)) {
        # THE WORDING AVOIDS THE BARE WORD "exit" ON PURPOSE, and it is not squeamishness: this branch's
        # own suite asserts that no `exit` STATEMENT appears in it, over the code with comments stripped
        # -- the non-blocking promise #1485 turns on. A string carrying the word reads to that assert as
        # the defect returning, and a test that a correct sentence can fail teaches the next author to
        # write a worse one. "returned a code this run could not measure" says the same thing.
        'returned a code this run could not measure (issue #1931), so the read-back could not be judged'
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
#
# TWO VERDICTS CAN FIRE AT ONCE, AND THE HEADLINE NAMES BOTH (#2064). They are different questions --
# who is mid-flight, and whether your route runs through their branch -- so a headline that named only
# the first would send a reader to a block that settles the wrong one. Naming neither by falling back
# to 'the work starts here' is the failure #1878 measured; naming one of two is the same failure, at
# half the size.
$opening = if ($foreignParked -and $prerequisiteFound) { ' -- but read the parked-fix and prerequisite verdicts above before you start.' }
           elseif ($foreignParked) { ' -- but read the parked-fix verdict above before you start.' }
           elseif ($prerequisiteFound) { ' -- but read the prerequisite verdict above before you start.' }
           else { ' -- the work starts here.' }
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

