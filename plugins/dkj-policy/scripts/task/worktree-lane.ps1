<#
.SYNOPSIS
    Open a branch in its own git worktree -- a "lane" -- so one branch can be BUILT while another one
    SHIPS, and hand a lane's branch back to the primary checkout when it is ready to ship.

.DESCRIPTION
    THE PROBLEM THIS SOLVES, MEASURED (August 23, 2026). ship-pr.ps1 step 3 is a synchronous
    `gh pr checks --watch`, and branch protection means the merge cannot happen before that check is
    green. Measured over the 65 most recent blocking runs, the `pull_request` CI leg has a median of
    8m 01s (min 5m 06s, p90 9m 39s). At 73 merged PRs in seven days that is 9h 45m per week during
    which the session that opened the PR can do nothing else. The 135 `push` runs in the same window
    (median 8m 05s) block nobody and are not part of that bill -- the blocking/non-blocking split is
    the whole point of the measurement.

    THE OBVIOUS FIX DOES NOT WORK, AND FAILS IN THE WORST PLACE. Running ship-pr.ps1 in the
    background and starting the next branch in the SAME checkout ends badly: at step 5 ship-pr does
    `git checkout main` (to fold), which yanks HEAD out from under the work in progress. Doing it the
    other way around -- ship from inside a worktree while the primary sits on main -- fails harder,
    because git refuses one branch in two worktrees:

        fatal: 'main' is already used by worktree at '<primary checkout>'

    That refusal lands AFTER the merge has already happened, which is exactly the half-state
    ship-pr.ps1 warns about at that same step: "the PR is merged, the entry file is still in the root,
    and every gate stays green until a release trips over it." Probed and confirmed rather than
    reasoned about, on git 2.54.0.windows.1.

    SO THE LANES RUN THE OTHER WAY AROUND:

        The worktree is where you BUILD. The primary checkout is where you SHIP.

    One shipping lane, N building lanes. Branch A ships in the primary -- `git checkout main` is legal
    there, because no other worktree holds main -- while you build branch B in its own lane. Nothing
    collides, and no shipping script is touched.

    THE STEPS, IN ORDER (open a lane):

      1. Resolve the PRIMARY worktree from git itself (the first entry of `git worktree list
         --porcelain`), anchored on the dual-context repo root. Never inferred from the caller's cwd or
         read straight off CLAUDE_PROJECT_DIR -- the whole point is that the caller may be standing in
         a lane, and in a session that IS a lane, that variable holds the lane.
      2. Fetch origin, and base the lane on `origin/main` rather than on the local trunk. Derek's
         branch-hygiene rule ("a fresh pull before every new branch") applies to a lane exactly as it
         does to a branch, and reading origin directly also means the lane does not care what the
         primary checkout currently has checked out.
      3. Add the worktree DETACHED at that commit. Detached, not `-b <name>`: the branch and both
         branch-dossier files are new-branch.ps1's job, and creating the branch here as well would be
         a second implementation of the one thing that script exists for.
      4. Delegate to new-branch.ps1 with the lane as its -RepoRoot, so the branch, the cycle file and
         the deployment entry all come into being INSIDE the lane. Every rule new-branch enforces --
         the prefix taxonomy, Test-BranchName, the entry scaffold, the tier sections -- therefore
         holds in a lane without being restated here. That parameter was added for this caller, on the
         #101 precedent fold-changelog-entry.ps1 already set; the comment at the call site records why
         the cheaper-looking route (repointing CLAUDE_PROJECT_DIR) is wrong.
      5. If that delegation fails for any reason, REMOVE the worktree again and exit non-zero. A
         rejected branch name must not leave a stray worktree behind; the rollback is what lets step 3
         run before the name is ever validated.

    THE STEPS, IN ORDER (-HandBack):

      1. Refuse if the lane tree has uncommitted work. `git worktree remove` refuses that by itself,
         but it refuses after this script has already decided to proceed -- and the message a person
         needs is "commit or park your work first", not git's.
      2. Refuse if the PRIMARY tree is dirty. It is about to receive `git checkout <branch>`, which
         would either fail halfway or drag those edits across; both are worse than stopping with a
         sentence. Same reasoning as prune-merged.ps1 step 1.
      3. Remove the worktree -- WITHOUT --force, deliberately, so git's own safety net stays the last
         word rather than something this script has overridden in advance.
      4. Check the branch out in the primary, and say plainly that ship-pr runs from there.

    WHY A HAND-BACK IS NEEDED AT ALL, stated rather than hidden: a branch checked out in a lane cannot
    also be checked out in the primary -- that is the same git refusal quoted above, mirrored. So the
    lane has to release the branch before the primary can ship it. Two commands, once per lane. The
    alternative was a one-line change to ship-pr.ps1 (fold via whichever worktree holds main instead
    of `git checkout main`); it was measured as saving those two commands and nothing in wall-clock,
    against a change to the single line that produces the state nothing reports. Declined on that
    trade, deliberately, not overlooked.

    THAT DECLINE STILL STANDS, AND ship-pr.ps1's STEP 5 NOW HAS A WORKTREE ARM ANYWAY -- the two are
    about different things, which is worth saying here because this paragraph reads as though they are
    not. Declined above: fold via whichever worktree ALREADY HOLDS main, to spare a lane its two
    hand-back commands. Added there (Dave, issue #972): a THROWAWAY worktree of its own, entered only
    when HEAD has moved off the shipping branch, because that single line was measured producing the
    state nothing reports rather than merely risking it. A lane still hands its branch back to the
    primary to ship it; nothing in this script changed.

    WHAT THIS SCRIPT DOES NOT DO:
      - It opens no PR, merges nothing and folds nothing. A lane is a place to work, and shipping
        stays exactly where it was.
      - It never touches the primary checkout's HEAD when opening a lane. Opening a lane while a ship
        is running in the primary is the entire use case, so reaching for the primary's HEAD would
        defeat it.
      - It removes no branch, locally or on the remote. Removing a lane leaves its branch untouched;
        branch cleanup is prune-merged.ps1's.

    Lanes live OUTSIDE the repo (a sibling `<repo>-lanes/` directory) and that is deliberate: a
    worktree inside the tree would be walked by the lint gate's link scan and by the test suites,
    which would report a second copy of the whole repo as findings.

    Every git call goes through the shared Invoke-NativeCapture (EAP=Continue -> run -> record
    $LASTEXITCODE), because git writes progress to stderr, which under EAP=Stop would become a
    terminating NativeCommandError before the exit code could be judged (the #96/#97/#107 pitfall).

    Pure ASCII (repo convention for .ps1).

.PARAMETER Name
    The branch name for the new lane, exactly as new-branch.ps1 takes it (`<prefix>/<short-name>`).
    Not validated here on purpose -- new-branch.ps1 owns the taxonomy, and step 5 rolls the worktree
    back when it refuses.

.PARAMETER Title
    (Optional) the entry title, passed straight through to new-branch.ps1.

.PARAMETER Intent
    (Optional) a short note on what this lane is for, passed straight through to new-branch.ps1.

.PARAMETER Path
    (Optional) where to put the lane's worktree. Default: a sibling of the primary checkout,
    `<repo>-lanes/<branch name with the separator flattened>`. Supply this only when that default is
    wrong for your machine.

.PARAMETER HandBack
    Close a lane and give its branch back to the primary checkout, so ship-pr can run there.

.PARAMETER Lane
    (Optional, with -HandBack) which lane to hand back. Default: the worktree you are standing in.

.EXAMPLE
    ./scripts/task/worktree-lane.ps1 -Name "feat/next-thing" -Title "The next thing"

.EXAMPLE
    ./scripts/task/worktree-lane.ps1 -HandBack

.EXAMPLE
    ./scripts/task/worktree-lane.ps1 -HandBack -Lane "C:\...\claude-code-specialists-lanes\feat--next-thing"
#>
[CmdletBinding(DefaultParameterSetName = 'Open')]
param(
    [Parameter(ParameterSetName = 'Open', Mandatory = $true)][string]$Name,
    [Parameter(ParameterSetName = 'Open')][string]$Title = '',
    [Parameter(ParameterSetName = 'Open')][string]$Intent = '',
    [Parameter(ParameterSetName = 'Open')][string]$Path = '',
    [Parameter(ParameterSetName = 'HandBack', Mandatory = $true)][switch]$HandBack,
    [Parameter(ParameterSetName = 'HandBack')][string]$Lane = ''
)

$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before. Why: the lib's header.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# Shared native-capture helper (#114 item 1). $PSScriptRoot-relative, not repo-root-relative: this lib
# is not repo-owned -- it travels with the SAME plugin/mirror payload as this script (registered in
# scripts\lib\shared-scripts-lib.ps1), so it resolves from the workshop root, a consumer's plugin
# cache, or the plugin mirror tree alike.
. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')

# The trunk, as a literal. Same choice park-branch.ps1 makes for the same reason: this script needs
# the trunk only to name a base commit and never to write to it, so a repo-owned Get-Trunk seam would
# add a contract entry that every consumer must fill in before a lane can be opened at all.
$trunk = 'main'

# Normalise every path through one function, so a comparison is always between two resolved paths
# rather than between one resolved and one as-typed. On Windows those differ in separator AND in case,
# and getting either wrong would silently treat a lane as the primary (or the reverse) -- the one
# mistake in this script that could delete work.
function Resolve-LanePath {
    param([Parameter(Mandatory = $true)][string]$Candidate)
    try {
        return (Resolve-Path -LiteralPath $Candidate -ErrorAction Stop).ProviderPath.TrimEnd('\', '/')
    } catch {
        return $Candidate.Replace('/', '\').TrimEnd('\')
    }
}

# Repo root -- dual context: if a consumer runs the shared plugin mirror, CLAUDE_PROJECT_DIR supplies
# its repo root; in the workshop root (or outside a session) it falls back to the git root. This way
# the SAME file works in both locations, and the root copy and the plugin mirror stay byte-identical
# (guarded by the shared-scripts drift lint).
#
# HERE IT IS AN ANCHOR FOR THE GIT CALL, NOT THE ANSWER, and the distinction is the point. Every other
# shared script wants "the repo I am working on" and stops there; this one wants "the PRIMARY worktree
# of that repo", which CLAUDE_PROJECT_DIR would name only by coincidence -- a session running inside a
# lane has the LANE as its project dir. So the anchor only tells git which repository to answer about,
# and git's own answer decides which worktree is primary.
#
# The first version skipped the anchor and let cwd carry it. The shared-scripts suite failed it for
# breaking the dual-context invariant, and it was right on a point beyond the convention: a caller
# standing outside the tree got a confusing git error instead of an answer.
# JUDGED (#1917): Resolve-RepoRootOrFail is check-report-lib's refusing sibling of Resolve-CheckRoot
# -- same precedence, but it names git's exit code and stderr instead of dying on $null.Trim().
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$repoRoot = Resolve-RepoRootOrFail -ScriptName 'worktree-lane.ps1'

# The primary worktree: `git worktree list --porcelain` lists the MAIN worktree first, and that
# ordering is what makes this reliable no matter which worktree the anchor above resolved to.
# Deliberately not `git rev-parse --show-toplevel` for this question -- that answers "the tree I am
# standing in", which is the opposite of what is needed and is used only for -HandBack's default.
$wtRes = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $repoRoot, 'worktree', 'list', '--porcelain')
if ($wtRes.ExitCode -ne 0) {
    Write-Error "worktree-lane cannot run -- not a git repository (or git failed to list worktrees): $repoRoot"
    exit 1
}
$worktreePaths = @(
    $wtRes.Output |
        Where-Object { $_ -match '^worktree\s+(.+)$' } |
        ForEach-Object { ($_ -replace '^worktree\s+', '').Trim() }
)
if ($worktreePaths.Count -eq 0) {
    Write-Error "worktree-lane cannot run -- git reported no worktrees at all."
    exit 1
}
$primaryRoot = Resolve-LanePath $worktreePaths[0]

if ($HandBack) {
    # -----------------------------------------------------------------------------------------------
    # HAND BACK: release the lane's branch so the primary can ship it.
    # -----------------------------------------------------------------------------------------------
    if ($Lane) {
        if (-not (Test-Path -LiteralPath $Lane -PathType Container)) {
            Write-Error "No such lane directory: $Lane"
            exit 1
        }
        $laneRoot = Resolve-LanePath $Lane
    } else {
        $topRes = Invoke-NativeCapture -FilePath 'git' -Arguments @('rev-parse', '--show-toplevel')
        if ($topRes.ExitCode -ne 0) {
            Write-Error "Cannot tell which worktree you are in. Run this from inside a lane, or pass -Lane."
            exit 1
        }
        $laneRoot = Resolve-LanePath (($topRes.Output | Out-String).Trim())
    }

    if ($laneRoot -ieq $primaryRoot) {
        Write-Error "That is the primary checkout, not a lane -- there is nothing to hand back. Ship from here."
        exit 1
    }
    if ($worktreePaths.Count -lt 2 -or -not ($worktreePaths | Where-Object { (Resolve-LanePath $_) -ieq $laneRoot })) {
        Write-Error "Not a registered worktree of this repository: $laneRoot"
        exit 1
    }

    # The lane's branch, read from the lane and not from HEAD here -- the caller may be standing
    # anywhere, including in the primary while handing back a lane by path.
    $laneBranchRes = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $laneRoot, 'rev-parse', '--abbrev-ref', 'HEAD')
    if ($laneBranchRes.ExitCode -ne 0) {
        Write-Error "Cannot read the branch of lane $laneRoot."
        exit 1
    }
    $laneBranch = ($laneBranchRes.Output | Out-String).Trim()
    if ($laneBranch -eq 'HEAD') {
        Write-Error "Lane $laneRoot is detached -- there is no branch to hand back."
        exit 1
    }

    # Step 1: uncommitted work in the lane. git would refuse the removal by itself, but only after
    # this script had already committed to the path; saying it here gives the actual next action.
    $laneDirty = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $laneRoot, 'status', '--porcelain')
    if ($laneDirty.ExitCode -ne 0) {
        Write-Error "Cannot read the status of lane $laneRoot."
        exit 1
    }
    if (($laneDirty.Output | Out-String).Trim()) {
        Write-Error "Lane $laneRoot has uncommitted work. Commit it (or park the branch) before handing back."
        exit 1
    }

    # Step 2: the primary is about to receive a checkout, so it has to be clean.
    $primaryDirty = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $primaryRoot, 'status', '--porcelain')
    if ($primaryDirty.ExitCode -ne 0) {
        Write-Error "Cannot read the status of the primary checkout $primaryRoot."
        exit 1
    }
    if (($primaryDirty.Output | Out-String).Trim()) {
        Write-Error "The primary checkout has uncommitted work; it cannot receive '$laneBranch' yet. Finish or stash it there first."
        exit 1
    }

    # Step 3a: step out of the lane first. On Windows the process's working directory holds an open
    # handle on that directory, so removing the lane you are STANDING IN fails with
    # "error: failed to delete '<lane>': Permission denied" -- and standing in the lane is the normal
    # case, since finishing the work there is the whole point. Measured on the first run of this path.
    #
    # This is the one place this script mutates the caller's location, against the convention
    # park-branch.ps1 states ("does not mutate the caller's cwd"). Deliberate on two grounds: the
    # directory the caller is in is about to stop existing, and the primary is exactly where they need
    # to be next. Doing it before the removal rather than after also means a failed removal leaves them
    # somewhere that still exists.
    $here = (Get-Location).ProviderPath.TrimEnd('\', '/')
    if ($here -ieq $laneRoot -or $here.StartsWith($laneRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Host "Stepping out of the lane into the primary checkout first." -ForegroundColor DarkGray
        Set-Location -LiteralPath $primaryRoot
    }

    # Step 3b: no --force. If git has a reason to refuse beyond the checks above, its reason wins.
    Write-Host "Removing lane: $laneRoot" -ForegroundColor Cyan
    $rm = Invoke-NativeCapture -FilePath 'git' -Arguments @('worktree', 'remove', $laneRoot)
    $rm.Output | ForEach-Object { Write-Host $_ }
    if ($rm.ExitCode -ne 0) {
        # A NON-ZERO EXIT HERE DOES NOT MEAN NOTHING HAPPENED, and the first version of this script
        # said it did. `git worktree remove` is not atomic: measured on the Permission-denied case
        # above, it had already emptied the tree AND deregistered the worktree, and failed only on
        # deleting the now-empty directory. Reporting "nothing was changed" there would send someone
        # looking for a lane that is, for every purpose except one empty folder, already gone. So ask
        # git what it actually thinks now rather than inferring from the exit code.
        $after = Invoke-NativeCapture -FilePath 'git' -Arguments @('worktree', 'list', '--porcelain')
        $stillRegistered = $false
        if ($after.ExitCode -eq 0) {
            $stillRegistered = [bool](
                $after.Output |
                    Where-Object { $_ -match '^worktree\s+(.+)$' } |
                    Where-Object { (Resolve-LanePath (($_ -replace '^worktree\s+', '').Trim())) -ieq $laneRoot }
            )
        }
        if ($stillRegistered) {
            Write-Error "git worktree remove failed and the lane is still registered -- nothing was changed. Branch '$laneBranch' is untouched. If git reported 'Permission denied', another program still has that directory open (a second terminal, an editor, a file explorer)."
            exit 1
        }
        Write-Host "git could not delete the directory itself, but the lane is already deregistered and empty -- continuing." -ForegroundColor Yellow
        Write-Host "  Remove the leftover folder when whatever holds it open has let go: $laneRoot" -ForegroundColor Yellow
    }

    # Step 4. If this fails the lane is already gone, which is worth saying out loud: no work is lost
    # (the branch and its commits are in the repository either way), but the caller has to check the
    # branch out themselves.
    $co = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $primaryRoot, 'checkout', $laneBranch)
    $co.Output | ForEach-Object { Write-Host $_ }
    if ($co.ExitCode -ne 0) {
        Write-Error "Lane removed, but checking '$laneBranch' out in the primary failed. Nothing is lost -- the branch still holds every commit. Check it out there by hand."
        exit 1
    }

    Write-Host ""
    Write-Host "Handed back: '$laneBranch' is now checked out in the primary checkout." -ForegroundColor Green
    Write-Host "  $primaryRoot"
    Write-Host "Ship it from there: ./scripts/release/ship-pr.ps1" -ForegroundColor Cyan
    exit 0
}

# ---------------------------------------------------------------------------------------------------
# OPEN a lane.
# ---------------------------------------------------------------------------------------------------

# Where the lane goes. Outside the repo, for the reason in the header: a worktree inside the tree
# would be walked by the lint gate's link scan and by the test suites.
if ($Path) {
    $lanePath = $Path
} else {
    $parent   = Split-Path -Parent $primaryRoot
    $leaf     = Split-Path -Leaf   $primaryRoot
    # The branch separator is flattened rather than preserved as a directory level: '<repo>-lanes/feat'
    # would otherwise become a shared parent that the LAST lane of a prefix deletes out from under any
    # other lane still using it.
    $flat     = ($Name -replace '[\\/]', '--')
    $lanePath = Join-Path (Join-Path $parent "$leaf-lanes") $flat
}

if (Test-Path -LiteralPath $lanePath) {
    $existing = @(Get-ChildItem -LiteralPath $lanePath -Force -ErrorAction SilentlyContinue)
    if ($existing.Count -gt 0) {
        Write-Error "Lane path already exists and is not empty: $lanePath -- hand back or remove that lane first."
        exit 1
    }
}

Write-Host "Primary checkout: $primaryRoot" -ForegroundColor DarkGray
Write-Host "Fetching origin..." -ForegroundColor Cyan
$fetch = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $primaryRoot, 'fetch', 'origin', '--quiet')
$fetch.Output | ForEach-Object { Write-Host $_ }
if ($fetch.ExitCode -ne 0) {
    Write-Error "git fetch origin failed -- a lane must not be based on a stale trunk."
    exit 1
}

# Detached at origin/<trunk>: see step 3 in the header for why the branch is not created here.
Write-Host "Adding lane worktree at origin/$trunk : $lanePath" -ForegroundColor Cyan
$add = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $primaryRoot, 'worktree', 'add', '--detach', $lanePath, "origin/$trunk")
$add.Output | ForEach-Object { Write-Host $_ }
if ($add.ExitCode -ne 0) {
    Write-Error "git worktree add failed -- no lane was created."
    exit 1
}

# Delegate branch + both dossier files to new-branch.ps1, pointed at the lane via -RepoRoot.
#
# THAT PARAMETER EXISTS BECAUSE THE OBVIOUS ROUTE WAS TRIED AND REFUSED. The first version set
# CLAUDE_PROJECT_DIR to the lane for the duration of this call, on the reasoning that the env var is
# how every shared workflow script is told which repo root it works on. The source-repo guard refused
# it, and it was right to: that guard resolves "the repo being operated on" from the SAME env var, so
# pointing it at the lane made new-branch.ps1 -- sitting in the primary checkout -- look like a
# released copy being run from outside the repo it maintains. The env var answers "which repo is this
# session working on"; -RepoRoot answers "which tree does this one call write to". Two questions, and
# conflating them broke a guard that had done nothing wrong.
$newBranch = Join-Path $PSScriptRoot 'new-branch.ps1'
if (-not (Test-Path -LiteralPath $newBranch -PathType Leaf)) {
    Write-Error "Cannot find new-branch.ps1 next to this script -- expected at $newBranch"
    exit 1
}

$delegateOk = $false
try {
    Write-Host ""
    # -SkipStaleBase (issue #1417) KEEPS THIS SCRIPT'S CONTRACT EXACTLY AS IT WAS. new-branch refuses a
    # base behind origin/<trunk> since #1417, and that refusal is about an operator cutting from whatever
    # HEAD they were standing on. There is no such choice here: step 3 above added this worktree DETACHED
    # AT origin/$trunk, moments after a fetch this script refuses to proceed without. So the base was
    # chosen by this script, deliberately and freshly, and the only thing new-branch's own fetch can
    # discover is that origin moved in the seconds since -- which would refuse a lane, roll it straight
    # back at step 5, and print `git pull --ff-only` as the remedy for a DETACHED worktree, where it is
    # not the remedy. The warning still prints, which is the honest half; the refusal is the half that
    # would be answering a question nobody asked here.
    & $newBranch -Name $Name -Title $Title -Intent $Intent -RepoRoot $lanePath -SkipStaleBase
    $delegateOk = ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE)
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    $delegateOk = $false
}

# Step 5: roll the worktree back. This is what allows the worktree to be created before the branch
# name has ever been validated -- new-branch owns the taxonomy, and a refusal from it must not leave a
# stray lane on disk.
if (-not $delegateOk) {
    Write-Host "Rolling the lane back (new-branch refused or failed)..." -ForegroundColor Yellow
    $undo = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $primaryRoot, 'worktree', 'remove', '--force', $lanePath)
    $undo.Output | ForEach-Object { Write-Host $_ }
    if ($undo.ExitCode -ne 0) {
        Write-Error "new-branch failed AND the lane could not be removed. Remove it by hand: git worktree remove --force `"$lanePath`""
    } else {
        Write-Error "new-branch failed -- the lane was removed again, nothing was left behind."
    }
    exit 1
}

Write-Host ""
Write-Host "Lane open: '$Name'" -ForegroundColor Green
Write-Host "  $lanePath"
Write-Host ""
Write-Host "Build there; the primary checkout stays free to ship." -ForegroundColor Cyan
# THE GATES RUN THERE TOO, and saying so is the point (#851). Until August 24, 2026 they did not: the
# source-repo guard read every lane path as a released copy, so a gate run from a lane was refused --
# and the lint gate reported it as an encoding failure, because it sees only its sub-script's exit code.
# A lane that could be built in but not checked in gave back the wait it exists to remove, since CI was
# then the first thing to see the branch. Stated in the output rather than only in the guard, because
# this is the line a person reads before they try it.
Write-Host "The gates run there as well -- a lane is this repository, not a released copy." -ForegroundColor DarkGray
Write-Host "When it is ready:  ./scripts/task/worktree-lane.ps1 -HandBack" -ForegroundColor Cyan
Write-Host "                   (from the lane, then ship-pr from the primary)"
exit 0
