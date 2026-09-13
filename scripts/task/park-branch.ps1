<#
.SYNOPSIS
    Park the current branch: commit any outstanding work and push it to origin -- NO PR, no live
    action.

.DESCRIPTION
    "Parking" a branch means: back it up to the remote so the exact same state is immediately
    continuable on any other device. Parking is the sibling of open-pr in the shared branch-workflow
    layer (issue #81), but deliberately stops well short of a PR:

      1. Guardrail: refuses on main -- parking is a feature-branch action (everything on main goes
         via a PR).
      2. Commits ALL outstanding work on the current branch (git add -A + commit), so nothing is
         left behind locally. The changelog entry file and any other WIP travel along, which is what
         makes "continue on another device" actually work.
      3. Pushes the branch to origin with `git push -u` (sets upstream tracking).

    What parking is NOT:
      - It opens NO pull request (push != PR -- the PR rule stays intact and separate, exactly like
        new-branch -Park).
      - It performs NO live/deploy action of any kind: it only touches git (add/commit/push). A
        consumer whose repo drives a live target (e.g. a Shopify theme) is never published by a park.

    Relation to `new-branch -Park`: that flag parks a branch AT CREATION and commits ONLY the branch
    files (leaving other staged work untouched). This script parks an EXISTING branch at
    any point mid-work and commits EVERYTHING outstanding. Use new-branch -Park to start-and-park in
    one move; use park-branch to back up a branch you are already working on.

    BOTH RUN THE SAME IMPLEMENTATION SINCE #507 (August 7, 2026) -- Invoke-GitPark in park-lib.ps1 --
    and the commit message now names the scope, so `park: <branch> (all outstanding work)` and
    `park: <branch> (the branch files only)` are told apart in the log. They used to be the same
    sentence, which meant that afterwards nothing said which half of your work was safely on origin.
    That was the finding; the two entry points themselves are NOT a defect and neither was deleted --
    they are two moments, and the measured usage backs both (of three park commits in the whole
    history, two came from -Park).

    Self-contained: depends only on git and the shared native-capture helper that travels with it --
    no repo-owned config (no branch-info, no repo-config), so it needs no consumer-side scaffold.

    Every git call goes through the shared Invoke-NativeCapture (EAP=Continue -> run -> record
    $LASTEXITCODE), because git writes progress ('remote:' lines, etc.) to stderr, which under
    EAP=Stop would become a terminating NativeCommandError before the exit code could be judged (the
    #96/#97/#107 pitfall). The commit message goes via `git commit -F <file>`, never `-m "...$branch..."`:
    a branch name may legally carry a `"` which embedded in an -m argument would break native argv
    reconstruction (the quoting lesson) -- a message file sidesteps argv entirely.

    Pure ASCII (repo convention for .ps1).

.PARAMETER Intent
    (Optional) a short note on where you left off / what is next. When outstanding work is committed,
    it is appended to the park commit message, so the "where I left off" state lives in git history
    rather than only in cross-session memory. Ignored when there is nothing new to commit (the branch
    was already committed locally and is merely being pushed).

.EXAMPLE
    ./scripts/task/park-branch.ps1

.EXAMPLE
    ./scripts/task/park-branch.ps1 -Intent "Skeleton + routing done; next: wire the API client."
#>
[CmdletBinding()]
param(
    [string]$Intent = ''
)

$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before. Why: the lib's header.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# Repo root -- dual context: if a consumer runs the shared plugin mirror, CLAUDE_PROJECT_DIR
# supplies its repo root; in the workshop root (or outside a session) it falls back to the git
# root. This way the SAME file works in both locations, and the root copy and the plugin mirror
# stay byte-identical (guarded by the shared-scripts drift lint).
# JUDGED (#1917): Resolve-RepoRootOrFail is check-report-lib's refusing sibling of Resolve-CheckRoot
# -- same precedence, but it names git's exit code and stderr instead of dying on $null.Trim().
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$repoRoot = Resolve-RepoRootOrFail -ScriptName 'park-branch.ps1'

# Shared native-capture helper (#114 item 1). $PSScriptRoot-relative, not $repoRoot: this lib is not
# repo-owned -- it travels with the SAME plugin/mirror payload as this script (registered in
# scripts\lib\shared-scripts-lib.ps1), so it resolves from the workshop root, a consumer's plugin
# cache, or the plugin mirror tree alike.
. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')

# The shared park implementation, same payload reasoning as the lib above: it travels with this script
# and with new-branch.ps1, the only two callers there are.
. (Join-Path $PSScriptRoot '..\lib\park-lib.ps1')

# THE CLOSE-OUT RECEIPT SHAPE (issue #1884), printed as this run's last line -- see closeout-lib.ps1
# for why step 6 of the ritual got a mechanism after losing four times in prose. Guarded on
# git-porcelain-lib's grounds: a consumer whose mirror predates this lib must not crash on load, and
# the call site tests for the function rather than assuming the dot-source took.
$parkCloseoutLib = Join-Path $PSScriptRoot '..\lib\closeout-lib.ps1'
if (Test-Path -LiteralPath $parkCloseoutLib -PathType Leaf) { . $parkCloseoutLib }

# Current branch from HEAD. Via Invoke-NativeCapture so a detached/edge git state cannot turn a
# stderr line into a terminating error before the exit code is judged.
$branchRes = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $repoRoot, 'rev-parse', '--abbrev-ref', 'HEAD')
if ($branchRes.ExitCode -ne 0) {
    Write-Error "park cannot run -- not a git repository (or no HEAD): $repoRoot"
    exit 1
}
$branch = ($branchRes.Output | Out-String).Trim()

# Guardrail: parking is a feature-branch action. On main everything goes via a PR, so there is
# nothing to park.
if ($branch -eq 'main') {
    Write-Error "You are on main; park works on a feature branch (everything on main goes via a PR)."
    exit 1
}

# THE STAGE-COMMIT-PUSH ITSELF LIVES IN park-lib.ps1 (issue #507, August 7, 2026), because
# new-branch.ps1 -Park had its own copy of these same four steps -- and the two had drifted in the way
# that matters least to a script and most to a person: they wrote the IDENTICAL commit message while
# committing different things. 'Everything' is this script's scope and always was; the scope now also
# chooses the words, so the log says which half of the work is on origin.
$ok = Invoke-GitPark -RepoRoot $repoRoot -Branch $branch -Scope 'Everything' -Intent $Intent
if (-not $ok) { exit 1 }

# THE RECEIPT SHAPE, LAST (issue #1884) -- see closeout-lib.ps1. A deliberate park is close-out shape
# C almost by definition: the work stopped, the state is already handled, and what is owed is a
# report rather than a question. That is the shape whose receipt most often grows into an apology.
if (Test-FunctionDefined 'Write-CloseOutReceipt') {
    # NOT A SPELLED-OUT DOCUMENT PATH. That name has been renamed four times and is named by its
    # resolver everywhere else in this workflow for exactly that reason; a hand-rolled copy here
    # would be a fifth spelling to go stale, and this script does not load the resolver's lib.
    Write-CloseOutReceipt -Cite "the branch document, parked on origin"
}
exit 0
