<#
.SYNOPSIS
    Gate: does the trunk carry an unfolded changelog entry -- a per-branch development document that a merge left
    behind because its fold never ran? (issue #1270)

.DESCRIPTION
    THE HOLE THIS CLOSES. The fold (fold-changelog-entry.ps1) runs from exactly one place: ship-pr.ps1,
    locally. A PR merged from the GitHub UI -- or any path that skips ship-pr -- merges the branch's
    development document into the trunk and never folds it: the '### DEPLOY:' entry stays trapped in the
    document, CHANGELOG.md never receives it, and a release cut in that window misses the change in the
    notes. Nothing downstream reported it. Measured on #1266: PRs #1253 and #1261 sat unfolded on main
    for ~10 hours. #1270 is the standing question that split off from it -- make the skipped fold loud.

    IT ADDS NO RULE OF ITS OWN. It calls Get-UnfoldedTrunkEntry in entry-scaffold-lib.ps1, which is the
    one definition of "a written entry stranded on the trunk". The invariant: on the trunk,
    dkj-policy/ carries no per-branch development document -- new-branch.ps1 creates one on a branch, the
    fold removes it at the merge. A written one whose declared branch is not the branch under HEAD is a
    leftover.

    TWO CALLERS, ONE ANSWER. The CI workflow .github/workflows/unfolded-entry.yml runs it on every push
    to main, so the leftover is caught regardless of who merged or how. The SessionStart hook
    unfolded-entry-sessioncheck.ps1 (workflow plugin) runs it in every repo that has the plugin, so the
    next specialists session is told at start rather than relying on a manual check.

    NO gh, NO NETWORK, NO PR. Whether the leftover's branch is merged, closed or still open does not
    change the answer: a written entry on the trunk is folded or it is a defect, and the fold is local.
    That is what lets the SessionStart hook run this in a consumer with no token.

    AND ONE THING THE WORKING COPY ALONE CANNOT ANSWER (issue #1585): whether the fold has ALREADY RUN
    on origin. A checkout that is merely BEHIND origin/<trunk> still carries the document on disk and
    still has a CHANGELOG.md without the entry, so the detector above -- which reads the working copy
    and nothing else -- reported a landed fold as a skipped one, and sent the reader at a fold when the
    repair was one 'git pull --ff-only'. Measured September 8, 2026: fold-on-merge.yml had folded
    fix/1575-prune-merged-dirty-guard and pushed it at 08:50:21Z, and a session starting 7 commits
    behind was told the fold never ran. Nothing was BROKEN -- fold-changelog-entry.ps1 has its own
    trunk guard and refuses on a stale checkout, so following the printed remedy was safe -- but the
    [ERROR] was indistinguishable from the real skipped-fold state this check exists to catch.

    SO EACH LEFTOVER IS ASKED ONE MORE QUESTION, AND IT COSTS NO NETWORK: is that branch's entry
    ALREADY IN CHANGELOG.md on the remote-tracking ref refs/remotes/origin/<trunk> that is on disk?
    Present there means the fold has landed and this checkout has not caught up.

    IT USED TO ASK THE OTHER HALF OF THE SAME COMMIT AND THAT WAS WRONG (issue #1601). The fold REMOVES
    the document and ADDS the entry in one commit, so #1585 asked the cheap half -- 'git cat-file -e
    <ref>:<document>', is it gone upstream -- and gated it on the checkout being BEHIND, since absence
    with a gap of ZERO means a document that was never committed. But a gap is not a direction:
    HEAD..origin/<trunk> is non-zero in a DIVERGED state too, and there a document committed locally
    and never pushed is also absent on origin. The check then reported a fold that was still owed as
    already landed, and named 'git pull --ff-only' as the remedy -- a pull that cannot fast-forward.
    Reproduced September 8, 2026 on a fixture one commit ahead and one behind.

    THE ENTRY'S PRESENCE HAS ONE CAUSE, whichever way the checkout has drifted, so the gap gate is gone
    rather than widened: it was sufficient and never necessary. Get-TrunkGap -NoFetch is still run --
    a reader who is behind is still told so, and the ref it names is where the changelog is read -- it
    simply no longer classifies anything. Nothing in CI changes: there the pushed commit IS
    origin/<trunk>, the entry is not in its changelog, and the leftover is reported exactly as before.

    AND THE TEST IS Test-BranchFoldedOnRef IN entry-scaffold-lib.ps1, NOT A REGEX HERE. Reading the
    heading in this script would put a second definition of "what a folded entry looks like in the
    changelog" beside Get-FoldedEntryForBranch -- the drift Get-UnfoldedTrunkEntry exists to prevent for
    the sibling question. That is why #1585 named this state instead of guarding it: doing it properly
    meant a lib function, which is more than that repair was.

    RUN IT FROM CI, and from the command line whenever you want the answer early:

        powershell -NoProfile -File scripts/lint/check-unfolded-entry.ps1
        powershell -NoProfile -File scripts/lint/check-unfolded-entry.ps1 -Branch main

    Exit 0 when the trunk is clean (or the only per-branch document present is the branch you are on),
    and exit 0 with a [WARN] when every document found has already been folded on origin -- the trunk
    that matters carries no unfolded entry, and only this checkout is behind. Exit 1 with the file(s)
    and the branch each declares whenever a fold is genuinely still owed.

    Pure ASCII, per this repo's script-layer convention.

.PARAMETER Branch
    The branch to treat as "current" -- its own development document is expected and not a leftover.
    Defaults to the current one. The CI workflow passes 'main' explicitly: a push to main IS main, but
    naming it keeps the workflow readable and independent of the checkout's detached state.

.PARAMETER RootOverride
    Repo root to operate on, for the test suite and the SessionStart hook. A consumer never types this:
    the root is resolved dual-context like every other shared script.

.EXAMPLE
    powershell -NoProfile -File scripts/lint/check-unfolded-entry.ps1 -Branch main
#>
[CmdletBinding()]
param(
    [string]$Branch = '',
    [string]$RootOverride = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# NO SOURCE-REPO GUARD, deliberately, and for exactly the reason source-repo-guard-lib.ps1's own header
# gives for check-roster-sync.ps1 and check-script-contract.ps1: a SessionStart hook invokes this from
# '${CLAUDE_PLUGIN_ROOT}/scripts/lint/' against the current repo, so Assert-OwnCopy would refuse it --

# Test-FunctionDefined (issue #1729): the seam probes below read the function table directly rather
# than through Get-Command, which parses the name as a wildcard pattern and pays a full PATH scan on
# every miss -- and a miss is the normal case for an optional seam. $PSScriptRoot-relative, so it
# resolves in the plugin mirror as well as here.
. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')
# and thereby the hook -- at every session start in the source repo. The CI half runs the in-repo copy
# (via actions/checkout), which the guard would not have fired on anyway.

# THE ROOT COMES FROM ONE DEFINITION (#1422). Dot-sourced guarded, so a mirror built before this lib
# existed degrades to the old inline form rather than throwing.
$checkLib = Join-Path $PSScriptRoot '..\lib\consumer-check-lib.ps1'
if (Test-Path -LiteralPath $checkLib -PathType Leaf) { . $checkLib }

$repoRoot = if (Test-FunctionDefined 'Resolve-CheckRepoRoot') {
    Resolve-CheckRepoRoot -RootOverride $RootOverride
} elseif ($RootOverride) { $RootOverride } elseif ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else {
    # JUDGED, AND DELIBERATELY TOLERANT (#1917). This branch is the degraded path -- it runs only where
    # consumer-check-lib is too old to define Resolve-CheckRepoRoot -- so it must answer what that lib
    # answers: '' for "could not tell", leaving the verdict to the block below, which is the one place
    # each of these checks decides what '' means for it. It must NOT refuse here, and it must not die on
    # $null.Trim() either, which is what it used to do before anything could read the guard.
    $t = ''
    try { $t = (& git rev-parse --show-toplevel 2>$null | Select-Object -First 1) } catch { $t = '' }
    if ($t) { ([string]$t).Trim() } else { '' }
}

# '' MEANS "COULD NOT TELL". This runs from a SessionStart hook as well as from CI, and the hook's case
# is a tree that is not a checkout -- where there is no trunk to carry a leftover, so there is nothing to
# judge rather than a failure. The CI half always has a checkout (actions/checkout), so it never lands here.
if (-not $repoRoot) {
    Write-Host '[OK] no git checkout here -- no trunk to carry an unfolded entry.'
    exit 0
}

# repo-config.ps1 first and optional, exactly as check-branch-entry loads it. Get-BranchFileDeclaredBranch
# reads the branch-line label from the wording rather than a hardcoded literal, and Get-BranchTrunkName
# reads an optional Get-TrunkBranchName -- a repo that translated the wording or renamed its trunk is
# read by its own names only while this is in the session.
$repoConfig = Join-Path $repoRoot 'scripts\repo-config.ps1'
if (Test-Path -LiteralPath $repoConfig -PathType Leaf) {
    try { . $repoConfig } catch { Write-Warning "scripts/repo-config.ps1 failed to load ($($_.Exception.Message)) -- the built-in wording is used." }
}

# GUARDED, LIKE consumer-check-lib ABOVE, AND FOR THE SAME REASON. Get-TrunkGap needs
# Invoke-NativeCapture, and this check is mirrored into a plugin whose cached copy in a consumer may
# predate #1585. Where the lib is absent the Get-Command probes below all miss, the upstream
# question is never asked, and the report degrades to exactly the pre-#1585 wording -- a check that
# still answers its original question rather than one that throws at a session start.
$nativeLib = Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1'
if (Test-Path -LiteralPath $nativeLib -PathType Leaf) { . $nativeLib }

# SEAM-LIB ON THE SAME TERMS, for the ONE seam this check reads: Get-ChangelogPath, the path
# Test-BranchFoldedOnRef opens on the remote-tracking ref (#1601). Guarded rather than plain because
# the whole point of this file's style is that a session start never dies on a cached mirror, and
# Get-SeamValue rather than a Get-Command probe of my own because the probe IS what that helper is,
# and check-branch-entry.ps1 next door already reads its seams through it.
$seamLib = Join-Path $PSScriptRoot '..\lib\seam-lib.ps1'
if (Test-Path -LiteralPath $seamLib -PathType Leaf) { . $seamLib }

. (Join-Path $PSScriptRoot '..\lib\entry-scaffold-lib.ps1')

# $Branch is passed through as-is, empty included. Get-UnfoldedTrunkEntry resolves HEAD itself, with
# its own try/catch -- so this script needs no git call and does not fall over on a fixture tree that
# is not a checkout (the SessionStart hook's case). An empty current branch excludes nothing, and
# every written per-branch document is then reported: the right answer for a CI checkout of the trunk, and
# the CI workflow passes -Branch main explicitly anyway.
if ($Branch -eq 'HEAD') { $Branch = '' }

$leftovers = @(Get-UnfoldedTrunkEntry -RepoRoot $repoRoot -CurrentBranch $Branch)

if ($leftovers.Count -eq 0) {
    Write-Host '[OK] no unfolded changelog entry on the trunk.'
    exit 0
}

# --- IS THE FOLD OWED, OR ALREADY LANDED ON ORIGIN? (issue #1585) --------------------------------
# The gap is measured with -NoFetch: the remote-tracking ref is read exactly as the last fetch left it,
# so a SessionStart hook stays offline and a fixture repo with no origin simply reports Measured=$false.
# A caller must never read "could not measure" as "behind" (Get-TrunkGap's own header says so), which is
# why $behind stays 0 unless the measurement actually succeeded.
$behind   = 0
$trunkRef = ''
if ((Test-FunctionDefined 'Get-TrunkGap') -and (Test-FunctionDefined 'Invoke-NativeCapture')) {
    try {
        $gap = Get-TrunkGap -RepoRoot $repoRoot -NoFetch
        # Measured means the remote-tracking ref EXISTS and the count parsed -- which is the only thing
        # the classification below needs from this call. Behind is read for the WORDING alone; see the
        # block on the gap gate under the loop.
        if ($gap.Measured) { $behind = [int]$gap.Behind; $trunkRef = [string]$gap.Ref }
    } catch { }
}

# The seam, read the same way fold-changelog-entry.ps1 reads it, and left EMPTY where the repo states
# nothing -- Test-BranchFoldedOnRef then falls back to '<workflow folder>/CHANGELOG.md', which is
# Get-DefaultChangelogPath's answer.
$changelogRel = ''
if (Test-FunctionDefined 'Get-SeamValue') {
    try { $changelogRel = [string](Get-SeamValue -Name 'Get-ChangelogPath' -Default '') } catch { }
}

# WHY THE TEST IS THE ENTRY AND NOT THE ABSENT DOCUMENT: the docstring above, and
# Test-BranchFoldedOnRef's own. The ONE thing decided here rather than there is what a $null means to
# THIS caller, and it is not $false: that function returns $null for every question it could not ask --
# no ref, no changelog at that ref, no lib in the session. Treating it as NOT FOLDED leaves the leftover
# reported, which is the pre-#1585 behaviour and the safe direction: an unanswerable question must never
# wave a skipped fold through on a measurement nobody took. Hence '-eq $true' and not a truthiness test.
$folded   = New-Object System.Collections.Generic.List[object]
$stranded = New-Object System.Collections.Generic.List[object]
foreach ($l in $leftovers) {
    $landed = $false
    if ($trunkRef -and (Test-FunctionDefined 'Test-BranchFoldedOnRef')) {
        try {
            $onRef = Test-BranchFoldedOnRef -RepoRoot $repoRoot -Ref $trunkRef -Branch $l.DeclaredBranch -ChangelogRel $changelogRel
            if ($onRef -eq $true) { $landed = $true }
        } catch { }
    }
    if ($landed) { $folded.Add($l) | Out-Null } else { $stranded.Add($l) | Out-Null }
}

if ($stranded.Count -eq 0) {
    # NOT [ERROR], AND NOT SILENCE EITHER. The trunk that matters -- origin's -- carries no unfolded
    # entry, so exit 1 would report a defect that does not exist; but a checkout this far behind is worth
    # one line, and the SessionStart hook surfaces this token with its own accurate headline.
    # THE GAP IS STATED ONLY WHERE THERE IS ONE (#1601). It used to be part of this sentence because the
    # classification could not be reached without it; now that the test is the entry on the ref, a
    # checkout in sync can land here too -- a document declaring a branch whose entry origin already
    # carries -- and "0 commit(s) behind" followed by a pull is a remedy for a state that is not this one.
    $gapPhrase = if ($behind -gt 0) { " -- this checkout is $behind commit(s) behind" } else { '' }
    Write-Host "[WARN] $($folded.Count) development document(s) here have ALREADY been folded on ${trunkRef}${gapPhrase}:" -ForegroundColor Yellow
    foreach ($l in $folded) {
        Write-Host "         $($l.Rel)  (declares branch '$($l.DeclaredBranch)')" -ForegroundColor Yellow
    }
    Write-Host '       So this is not a skipped fold and there is nothing to fold -- the entry is already in' -ForegroundColor Yellow
    if ($behind -gt 0) {
        Write-Host '       CHANGELOG.md on origin. Catch up instead:' -ForegroundColor Yellow
        Write-Host '         git pull --ff-only' -ForegroundColor Yellow
    } else {
        # NO PULL NAMED, because there is nothing to pull. What is certain about this state is stated and
        # nothing else: fold-changelog-entry.ps1 refuses a branch the changelog already carries (inbound
        # #1082), so the document is the stray half of a fold that has already happened.
        Write-Host '       CHANGELOG.md on the ref this checkout is level with. The document is the stray half:' -ForegroundColor Yellow
        Write-Host '       fold-changelog-entry.ps1 refuses a branch the changelog already carries (inbound #1082),' -ForegroundColor Yellow
        Write-Host '       so removing it is the repair -- not a fold, and not a pull.' -ForegroundColor Yellow
    }
    exit 0
}

Write-Host "[ERROR] the trunk carries $($stranded.Count) unfolded changelog entry(ies) -- a merge landed but its fold never ran:" -ForegroundColor Red
foreach ($l in $stranded) {
    Write-Host "          $($l.Rel)  (declares branch '$($l.DeclaredBranch)')" -ForegroundColor Red
}
Write-Host '        The DEPLOY section is still trapped in each document, so CHANGELOG.md never received' -ForegroundColor Red
Write-Host '        it and a release cut would miss the change. Fold each one now:' -ForegroundColor Red
foreach ($l in $stranded) {
    Write-Host "          fold-changelog-entry.ps1 -Branch $($l.DeclaredBranch) -Commit -Push" -ForegroundColor Red
}
Write-Host '        (In the source repo run scripts/release/fold-changelog-entry.ps1; a consumer runs the' -ForegroundColor Red
Write-Host '        fold-changelog skill.) If a ship is in progress the fold commit is seconds away and' -ForegroundColor Red
Write-Host '        this clears itself.' -ForegroundColor Red
if ($behind -gt 0) {
    # PULL FIRST, OR THE REMEDY ABOVE REFUSES. fold-changelog-entry.ps1's own trunk guard (#1405) stops
    # on a stale checkout, so naming the fold without naming the gap sends the reader at a command that
    # cannot run yet.
    Write-Host "        This checkout is also $behind commit(s) behind $trunkRef -- 'git pull --ff-only' first," -ForegroundColor Red
    Write-Host '        or the fold refuses on the stale trunk.' -ForegroundColor Red
}
foreach ($l in $folded) {
    # Same conditionality as the [WARN] arm above, and for the same reason: the pull is the remedy for
    # being behind, and this arm no longer implies that anybody is.
    $clears = if ($behind -gt 0) { ' -- the pull clears it.' } else { ' -- fold-changelog-entry.ps1 would refuse it as a duplicate.' }
    Write-Host "        (Already folded on origin, nothing owed: $($l.Rel)$clears)" -ForegroundColor Yellow
}
exit 1
