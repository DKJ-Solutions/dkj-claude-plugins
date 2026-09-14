<#
.SYNOPSIS
    Gate: does this checkout commit as the same account it acts as on the tracker? (issue #1315)

.DESCRIPTION
    THE HOLE THIS CLOSES. The claim rule -- Chris's persona body and
    dkj-policy/CONTRIBUTING.md both prescribe `gh issue edit <n> --add-assignee @me` --
    resolves `@me` through the GitHub API, so it writes whichever account `gh` holds. Nothing anywhere
    compared that against the identity `git` commits as. Measured on DAVE-KOK-BWJ (September 3, 2026):
    `gh` was authenticated as `DaveKJohn` while `git config user.name` read `davekokbwj`, so claiming
    #1314 with the documented idiom put `DaveKJohn` on an issue whose every commit would read
    `davekokbwj`, and it had to be corrected by hand.

    TWO THINGS BREAK, AND BOTH ARE SILENT. A claim's whole job under the claim rule is to let a second
    session tell "somebody else's work" from "untouched" -- and a second session correlates the claim
    with the BRANCH, which shows the committer. So a split identity makes the tracker and the branch
    disagree about who is working. Worse, this repo's own branch-hygiene lens
    (.claude/specialists/lenses/05-05-extension.md) teaches exactly that disagreement as the tell for
    work built on ANOTHER DEVICE -- so on a split checkout the tell fires by construction, and a later
    session reads "built elsewhere" off a branch that never left the machine.

    WHY IT COMPARES NAMES AND NOT EMAILS. GitHub attributes a commit by email, so the comparison one
    reaches for first is "does git config user.email belong to the authenticated account". It is not
    available: `gh api user` returns a null email for an account with no public one, and
    `gh api user/emails` needs the "user" token scope (this family's tokens carry gist, read:org and
    repo). Widening a token scope to print an advisory line is the wrong trade. `gh auth status` names
    the active account from the KEYRING -- no network, no extra scope -- so that is what this reads.

    WHY IT FIRES ONLY ON A LOGIN-SHAPED user.name, WHICH IS THE WHOLE NOISE STORY. `git config
    user.name` is free text, and in most repos it holds a display name ("Ada Lovelace") rather than a
    login -- so comparing it to a GitHub account unconditionally would fire forever in every consumer
    that spells its name normally. This repo has already DECLINED a check for precisely that reason
    (the stale-path check, 124 findings all false; see the system-administration lens). So a mismatch
    is reported only when user.name is itself a valid GitHub username by GitHub's own rule AND differs
    from the active account. A name with a space, or one longer than 39 characters, is silence. The
    three accounts in this family -- DaveKJohn, davekokbwj, maikel-bwj -- are all login-shaped, so the
    measured case is caught.

    IT IS ADVISORY, AND IT IS DELIBERATELY NOT A GATE. It reports a fact about the MACHINE, not about
    the diff, so it has no place in check-plugin-integrity.ps1 or in main-ci-gate: a CI runner
    authenticates as a bot and commits as one, which is a mismatch by design and says nothing about
    the change under review. Its one automatic caller is the SessionStart hook
    git-identity-sessioncheck.ps1 (workflow plugin), which tells the session at start -- the moment
    before it claims an issue and starts committing.

    NO NETWORK. `gh auth status` reads the keyring, `git config` reads a config file, and `git var`
    reads config plus the environment, so this adds nothing to a session start beyond three local
    processes -- and only one of them on the checkout that cannot commit, which exits before the two
    identity reads.

    RUN IT from the command line whenever you want the answer directly:

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/lint/check-git-identity.ps1

    IT ALSO ANSWERS A SECOND, BLUNTER QUESTION FIRST (inbound #1867): can this checkout commit at
    all? That used to be folded into the "user.name is unset" skip and go unsaid, on the ground that
    git refuses such a commit itself and so needs no second reporter -- true about WHETHER, wrong
    about WHEN, and the when is the whole cost. The first commit of the cycle happens inside
    new-branch.ps1, after HEAD has moved and the branch document is written, so "git will tell you"
    means "git will tell you once a branch exists". `git var GIT_AUTHOR_IDENT` is the probe that
    answers it without a network call; Test-GitCanCommit carries why user.name is the wrong reading
    for it in BOTH directions.

    Exit 0 when the two agree, when the comparison is not meaningful, when there is nothing to
    compare, or when the checkout cannot commit (a [WARNING] rather than a gate -- new-branch.ps1 is
    what refuses); exit 1 with both names and the two ways out when they are provably different
    accounts.

    Pure ASCII, per this repo's script-layer convention.

.PARAMETER RootOverride
    Repo root to read `git config` in, for the test suite and the SessionStart hook. A consumer never
    types this: the root is resolved dual-context like every other shared script.

.PARAMETER GhAccountOverride
    (Optional, for tests) Use this as the active `gh` account instead of running `gh auth status`.
    The literal string 'NONE' stands for "gh is absent or logged out", which no real account name can
    collide with -- a GitHub login cannot be spelled in a way that reaches this parameter as 'NONE'
    while meaning an account, because the comparison below is case-insensitive and a login IS a
    possible spelling of it. So the sentinel is honoured only from a test, which is the only caller
    that passes this parameter at all.

.PARAMETER GitUserNameOverride
    (Optional, for tests) Use this as `git config user.name` instead of reading it. The literal
    string 'NONE' stands for "unset", on the same footing as above.

.PARAMETER CanCommitOverride
    (Optional, for tests) Answer the "can this checkout commit at all" probe instead of running
    `git var GIT_AUTHOR_IDENT`. The literal string 'NO' stands for "git would refuse"; any other
    non-empty value stands for "it would accept". A sentinel rather than a switch, so that "not
    passed" stays distinguishable from "passed as false" -- the same reason the two above spell
    absence as 'NONE' rather than as an empty string.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/lint/check-git-identity.ps1
#>
[CmdletBinding()]
param(
    [string]$RootOverride = '',
    [string]$GhAccountOverride = '',
    [string]$GitUserNameOverride = '',
    [string]$CanCommitOverride = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# NO SOURCE-REPO GUARD, deliberately, and for the same reason check-unfolded-entry.ps1 gives: a
# SessionStart hook invokes this from '${CLAUDE_PLUGIN_ROOT}/scripts/lint/' against the current repo,
# so Assert-OwnCopy would refuse it -- and thereby the hook -- at every session start in the source

# Test-FunctionDefined (issue #1729): the seam probes below read the function table directly rather
# than through Get-Command, which parses the name as a wildcard pattern and pays a full PATH scan on
# every miss -- and a miss is the normal case for an optional seam. $PSScriptRoot-relative, so it
# resolves in the plugin mirror as well as here.
. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')
# repo.

# THE ROOT COMES FROM ONE DEFINITION (#1422), and this script's wrapped variant is the one that BECAME
# it: four siblings resolved the root on one line and died on `.Trim()` against $null in a tree that is
# not a checkout, which this one had already handled. The tolerant reading won because a SessionStart
# hook must not fail over an advisory check. Dot-sourced guarded, so a mirror built before this lib
# existed degrades to the wrapped inline form this line replaces rather than throwing.
$checkLib = Join-Path $PSScriptRoot '..\lib\consumer-check-lib.ps1'
if (Test-Path -LiteralPath $checkLib -PathType Leaf) { . $checkLib }

$repoRoot = ''
if (Test-FunctionDefined 'Resolve-CheckRepoRoot') {
    $repoRoot = Resolve-CheckRepoRoot -RootOverride $RootOverride
} elseif ($RootOverride) {
    $repoRoot = $RootOverride
} elseif ($env:CLAUDE_PROJECT_DIR) {
    $repoRoot = $env:CLAUDE_PROJECT_DIR
} else {
    try { $repoRoot = (git rev-parse --show-toplevel 2>$null | Select-Object -First 1) } catch { $repoRoot = '' }
    if ($repoRoot) { $repoRoot = $repoRoot.Trim() }
}

# THE THREE IDENTITY READS ARE A LIB NOW, not this file's own (claim-issue.ps1). They were written
# here because this was the only caller; the claim step needs the same three -- it has to ACT under
# the account this checkout commits as -- and it cannot reach them by dot-sourcing this file, which
# runs its whole comparison and exits on load. What stays here is the half that is genuinely this
# script's: what it does with the two names once it has them.
. (Join-Path $PSScriptRoot '..\lib\git-identity-lib.ps1')

# CAN THIS CHECKOUT COMMIT AT ALL? AND IT IS ASKED FIRST (inbound #1867) -- first meaning BEFORE THE
# TWO IDENTITY READS BELOW, not merely before the three skips further down. Everything after this block
# compares two identities; this asks whether there is a usable one at all, and that question outranks
# the comparison -- a machine that cannot commit cannot act on the answer to it either. It also runs
# ahead of the gh-absent skip, for the same reason: gh absent is the ordinary state of a consumer that
# never uses the tracker, while no author identity breaks every commit in the cycle.
#
# AND THE ORDER IS A COST DECISION TOO, not only a precedence one. Get-ActiveGhAccount shells out to
# `gh auth status` through the heavier capture arm; this probe is one `git var` that reads config files.
# Sitting below those reads, the branch that fires on the broken machine -- at EVERY session start on it,
# since a SessionStart hook is this script's one automatic caller -- would be the most expensive path
# through the file while discarding both values it had just paid for. Above them it is the cheapest.
#
# THE THIRD SKIP BELOW IS WHAT THIS SPLITS OUT. 'user.name is unset' used to carry this state and
# justify its silence with "a state git itself refuses to commit in, so it needs no second reporter".
# That is right about WHETHER git refuses and wrong about WHEN, and the when is the whole cost: the
# first commit of the cycle is inside new-branch.ps1, after HEAD has moved and the branch document is
# written. Reported here, it is known before a branch is cut.
#
# ADVISORY (exit 0), like the rest of this script and for the same reason its docstring gives: it is a
# fact about the MACHINE, and the refusal that actually protects the work is new-branch.ps1's, which
# reads the same lib function.
if ($CanCommitOverride) {
    $canCommit = ($CanCommitOverride -ne 'NO')
} else {
    $canCommit = Test-GitCanCommit -RepoRoot $repoRoot
}
if (-not $canCommit) {
    Write-Host '[WARNING] this checkout has no usable git author identity -- it cannot commit at all.' -ForegroundColor Yellow
    Write-Host '          `git var GIT_AUTHOR_IDENT` exits 128 here, which is exactly the state `git commit`' -ForegroundColor Yellow
    Write-Host '          refuses in. Nothing in this cycle works until it is set: new-branch, the park, the' -ForegroundColor Yellow
    Write-Host '          fold and the release all commit.' -ForegroundColor Yellow
    Write-Host '        Set both, and the identity question below answers itself:' -ForegroundColor Yellow
    Write-Host '          git config --global user.name  "<your GitHub login>"' -ForegroundColor Yellow
    Write-Host '          git config --global user.email "<the address on that account>"' -ForegroundColor Yellow
    Write-Host '        (Drop --global to set it for this checkout only.)' -ForegroundColor Yellow
    exit 0
}

# The overrides exist so the suite can put this script in front of every state without a keyring or a
# git identity of its own. 'NONE' is the spelling for "absent"; see the .PARAMETER blocks.
if ($GhAccountOverride) {
    $ghAccount = if ($GhAccountOverride -eq 'NONE') { '' } else { $GhAccountOverride }
} else {
    $ghAccount = Get-ActiveGhAccount
}

if ($GitUserNameOverride) {
    $gitUserName = if ($GitUserNameOverride -eq 'NONE') { '' } else { $GitUserNameOverride }
} else {
    $gitUserName = Get-GitUserName -RepoRoot $repoRoot
}

# THREE WAYS THERE IS NOTHING TO SAY, and each is a [SKIP] rather than a pass: a pass would claim the
# two were compared and agreed. gh absent or logged out is the ordinary state of a consumer that never
# uses the tracker; an unset user.name is genuinely nothing to COMPARE, now that the block above has
# ruled out the state that made it matter (inbound #1867) -- a checkout reaching this line commits
# fine, whether from the environment or from git's own auto-guess; and a display name is the common,
# correct spelling that this check must stay silent on.
if (-not $ghAccount) {
    Write-Host '[SKIP] gh names no active account (absent, or logged out) -- nothing to compare the git identity against.'
    exit 0
}
if (-not $gitUserName) {
    Write-Host "[SKIP] git config user.name is unset -- nothing to compare against the gh account '$ghAccount'."
    exit 0
}
if (-not (Test-GitHubLoginShape -Value $gitUserName)) {
    Write-Host "[SKIP] git config user.name ('$gitUserName') is not a valid GitHub username, so it names a person"
    Write-Host "       rather than an account and a difference from '$ghAccount' would prove nothing."
    exit 0
}

# GitHub logins are case-insensitive, so a spelling difference in case is the SAME account and must
# not be reported as two.
if ($ghAccount -ieq $gitUserName) {
    Write-Host "[OK] gh and git are the same account ('$ghAccount') -- the claim rule's @me writes the account your commits will read."
    exit 0
}

Write-Host '[ERROR] this checkout acts as one GitHub account and commits as another:' -ForegroundColor Red
Write-Host "          gh acts as           '$ghAccount'   (gh auth status -- what '@me' resolves to)" -ForegroundColor Red
Write-Host "          git commits as       '$gitUserName'   (git config user.name)" -ForegroundColor Red
Write-Host '        Two things follow, and both are silent today. The claim rule writes the WRONG account:' -ForegroundColor Red
Write-Host "        'gh issue edit <n> --add-assignee @me' puts '$ghAccount' on an issue whose every commit" -ForegroundColor Red
Write-Host "        will read '$gitUserName', so the tracker and the branch disagree about who is working. And" -ForegroundColor Red
Write-Host '        the cross-device tell in the branch-hygiene lens -- a branch whose commits name a different' -ForegroundColor Red
Write-Host '        account than this checkout -- fires here by construction, so it is NOT diagnostic on this' -ForegroundColor Red
Write-Host '        machine until the two agree.' -ForegroundColor Red
Write-Host '        Either way out is fine, and both end the report:' -ForegroundColor Red
Write-Host "          1. commit as the account you act as:   git config user.name '$ghAccount'" -ForegroundColor Red
Write-Host "             (and set user.email to that account's address in the same move)" -ForegroundColor Red
Write-Host "          2. or act as the account you commit as: gh auth login   (as '$gitUserName')" -ForegroundColor Red
Write-Host "        Until then, claim by NAME rather than with @me:  --add-assignee $gitUserName" -ForegroundColor Red
exit 1
