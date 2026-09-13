<#
.SYNOPSIS
    Gate: does this branch carry a written changelog entry? For CI, so the branch-entry convention is
    enforced by something other than goodwill (inbound #789).

.DESCRIPTION
    THE CONVENTION SHIPPED WITH NOTHING ENFORCING IT. open-pr refuses to push an unwritten entry and
    ship-pr refuses to merge with unresolved steps -- but both are local, and a branch pushed by hand or
    a PR opened in the GitHub UI meets neither. So both consumers wrote a CI gate for this, from scratch,
    against the same convention. That is a second definition of the format in every consumer, free to
    drift from the fold that reads the first one, and it HAD drifted: measured on pickup, both
    hand-written gates refuse a merge over a missing significance score, which is a refusal Dave
    deliberately placed at the release cut instead (open-pr.ps1, August 5, 2026 -- "an author who has not
    settled it should not be blocked from merging over it"), justified in one of them by "tier 0 can
    never legitimately stay empty" while this system's own rule reads TIER 0 OWES NOTHING.

    SO THIS SCRIPT ADDS NO RULE OF ITS OWN. It calls the two functions open-pr already calls -- there is
    exactly one definition of "written" in the system and this is not a second one:

        Test-BranchChangelogIsFilled   is the file an entry at all, or the reset state the fold leaves?
        Get-EntryScaffoldFindings      which fields is the scaffolder still waiting for?

    That second one is why no test on the score is needed. A freshly scaffolded entry already carries an
    H3 and a title, so a heading test passes it -- the case the hand-written gates reached for the score
    to catch. Get-EntryScaffoldFindings answers it properly: it measures the fields the scaffolder left,
    names each one, and catches an untouched entry AND one whose prompt was deleted rather than answered.
    The gate that reuses it is therefore SIMPLER than the one written by hand, not more complex.

    THE SIGNIFICANCE IS REPORTED, NEVER REFUSED, for the reason above. An entry whose scores are not
    settled is a branch that can merge and a release that cannot be cut from it; this prints what the cut
    will say, so the author learns it here rather than at the cut, and merges anyway.

    THE DEPLOY LOCK, AND IT IS WHY THIS SCRIPT NOW READS A PR BODY AT ALL (Dave, issue #884,
    August 25, 2026). The DEPLOY section travels four times -- the branch's development document, the PR body,
    CHANGELOG.md, the release notes -- and is fixed at the moment the PR opens, because that is what the
    review approved and what the fold takes. ship-pr refuses the merge on divergence, and ship-pr is
    local, which is this gate's whole reason for existing. It ADDS NO RULE HERE EITHER: the comparison is
    Test-DeployLock in pr-body-lib, the same function ship-pr calls.

    ONLY WITH -Pr, AND SILENT-BUT-SAID WITHOUT IT. This paragraph replaces one that read "It reads no PR
    body and knows nothing about labels, previews or review state" -- and the half of that which was
    load-bearing is kept rather than quietly dropped: the entry checks above still need no token, no
    network and no PR, so the gate stays runnable on a branch that has none. The lock is therefore
    OPT-IN by parameter rather than resolved from the branch. What has genuinely changed is only that a
    caller may now hand it a PR number, and what has NOT is review state: a text comparison against a
    published copy is not a judgement a visitor makes. A repo whose merge rule turns on something a
    visitor can SEE still gates that separately -- one consumer does, against its own PR template, and
    that template is its own rather than anything this plugin ships.

    AN UNREADABLE BODY IS NOT A FINDING, the same tolerance ship-pr applies: gh failing says something
    about the token or the network, not about the section, and a gate that refused on that would be
    refusing on no evidence.

    RUN IT FROM CI, and from the command line whenever you want the answer early:

        powershell -NoProfile -File scripts/lint/check-branch-entry.ps1
        powershell -NoProfile -File scripts/lint/check-branch-entry.ps1 -Branch feat/something

    Exit 0 when the entry is written or the branch is exempt; exit 1 with an actionable message otherwise.

    SEAM IT READS, from the consumer's own scripts/repo-config.ps1, probed with Get-Command like every
    other optional knob:

      Get-EntryGateExemptPrefixes   branch prefixes that owe no entry. Default: 'sync'. A mirror branch
                                    carries somebody else's work rather than this repo's, so there is
                                    nothing for it to declare -- both consumers reached that answer
                                    independently, with nothing recording that it was the expected one.

    Pure ASCII, per this repo's script-layer convention.

.PARAMETER Branch
    The branch to judge. Defaults to the current one. CI passes the PR's head ref, because a pull_request
    checkout is a detached merge commit and 'git rev-parse --abbrev-ref HEAD' answers 'HEAD' there.

.PARAMETER Pr
    The PR number to hold the DEPLOY section against, enabling the lock. Omitted, the lock is skipped and
    the run says so -- every other check here needs no PR, no token and no network, and that stays true.
    CI passes the pull_request event's own number; on the command line it is what makes "does my PR still
    match my document?" answerable before the merge refuses it.

.PARAMETER RootOverride
    Repo root to operate on, for the test suite. A consumer never types this: the root is resolved
    dual-context like every other shared script.

.EXAMPLE
    powershell -NoProfile -File scripts/lint/check-branch-entry.ps1 -Branch fix/something
#>
[CmdletBinding()]
param(
    [string]$Branch = '',
    [string]$Pr = '',
    [string]$RootOverride = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before. Why: the lib's header.
# It cannot fire in a consumer's CI, and that is by its own design rather than by luck -- its second
# condition is that the repo being operated on publishes plugins, which a consumer does not.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# Test-FunctionDefined (issue #1729): the seam probes below read the function table directly rather
# than through Get-Command, which parses the name as a wildcard pattern and pays a full PATH scan on
# every miss -- and a miss is the normal case for an optional seam. $PSScriptRoot-relative, so it
# resolves in the plugin mirror as well as here.
. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')

# THE ROOT COMES FROM ONE DEFINITION (#1422). Dot-sourced guarded, so a mirror built before this lib
# existed degrades to the old inline form rather than throwing. AFTER the source-repo guard above, which
# is dot-sourced on the first line that runs and may rely on nothing being loaded yet.
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

# '' MEANS "COULD NOT TELL", AND THIS ONE REFUSES -- which is why the lib returns the fact and not the
# verdict. A CI gate that cannot find the tree it is gating must not pass, because passing is what the
# merge reads. THE OTHER FOUR ANSWER DIFFERENTLY, AND NOT EVEN ALL THE SAME WAY, which is the whole
# argument for leaving the verdict here: three of them (retired-doc-name, supremacy-declaration,
# unfolded-entry) exit 0 on '' because there is genuinely no prose and no trunk to judge, while
# check-git-identity carries no test at all -- '' reaches Get-GitUserName, which drops the '-C' and reads
# the GLOBAL git config, and comparing THAT against the active gh account is still a meaningful answer.
# Three verdicts from one resolution; folding any of them into the lib would impose it on the other two.
if (-not $repoRoot) {
    Write-Host '[ERROR] Could not tell which repo to judge, and a gate must not pass on that.' -ForegroundColor Red
    Write-Host '        Run this from inside the checkout, or pass -RootOverride "<path>".'
    exit 1
}

# repo-config.ps1 first and optional, exactly as new-branch and adopt-workflow-folder load it. It is not
# only the seam above: entry-scaffold-lib reads the wording overrides from it, and a gate that judged an
# entry against the ENGLISH scaffold wording in a repo that translated it would accuse a finished entry.
$repoConfig = Join-Path $repoRoot 'scripts\repo-config.ps1'
if (Test-Path -LiteralPath $repoConfig -PathType Leaf) {
    try { . $repoConfig } catch { Write-Warning "scripts/repo-config.ps1 failed to load ($($_.Exception.Message)) -- the built-in wording is used." }
}

. (Join-Path $PSScriptRoot '..\lib\entry-scaffold-lib.ps1')

# For the DEPLOY lock, and only reached when -Pr is given. Loaded AFTER entry-scaffold-lib, because
# Get-PrDescription probes the section-heading seams with Get-Command: a repo that renamed a heading is
# read by its own names only while that lib is already in the session. native-capture-lib is what keeps
# the gh call out of PowerShell 5.1's native-stderr trap, where a zero exit code still sets $? to false.
. (Join-Path $PSScriptRoot '..\lib\pr-body-lib.ps1')
# Test-IsWorkflowSourceRepo, for the heading rule's source-repo scoping (#898). The one-file test -- a repo
# with .claude-plugin/marketplace.json is the workflow's source -- already factored out here rather than
# repeated a fifth time. Both issues that asked for this scoping named it 'Test-SourceRepo', which exists
# nowhere; the mechanism is real and this is its name.
. (Join-Path $PSScriptRoot '..\lib\seam-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')

# branch-info.ps1 is REPO-OWNED and does not travel with the plugin -- every consumer keeps their own
# prefix table -- so it is loaded from the repo being judged, guarded. All this gate wants from it is
# SafeName for the legacy entry path, which is one substitution, so a repo without the lib degrades to
# computing it here rather than to a failure.
$branchInfoLib = Join-Path $repoRoot 'scripts\lib\branch-info.ps1'
if (Test-Path -LiteralPath $branchInfoLib -PathType Leaf) {
    try { . $branchInfoLib } catch { Write-Warning "scripts/lib/branch-info.ps1 failed to load ($($_.Exception.Message)) -- the legacy entry path is resolved without it." }
}

if (-not $Branch) {
    $Branch = (git -C $repoRoot rev-parse --abbrev-ref HEAD).Trim()
}
if (-not $Branch -or $Branch -eq 'HEAD') {
    Write-Host '[ERROR] Could not tell which branch to judge, and refusing to guess.' -ForegroundColor Red
    Write-Host '        A pull_request checkout is a detached merge commit, so pass the head ref explicitly:'
    Write-Host '        -Branch "${{ github.head_ref }}"'
    exit 1
}

$trunk = if (Test-FunctionDefined 'Get-TrunkBranchName') {
    $t = ([string](Get-TrunkBranchName)).Trim(); if ($t) { $t } else { 'main' }
} else { 'main' }

if ($Branch -eq $trunk) {
    # The trunk is where the fold REMOVES the document, so judging it would report the trunk's own normal
    # state as a defect on every push. Said out loud rather than silently passing: a gate that answers 0 for
    # a reason it does not name is a gate somebody will point at the trunk and believe.
    Write-Host "[OK] '$Branch' is the trunk, where the fold removes the document by design."
    Write-Host '     Nothing to judge here -- point this at a branch, or run it on pull_request only.'
    exit 0
}

# --- Exempt prefixes -------------------------------------------------------------------------------
$exempt = if (Test-FunctionDefined 'Get-EntryGateExemptPrefixes') {
    @(Get-EntryGateExemptPrefixes)
} else { @('sync') }

$prefix = if ($Branch -match '/') { ($Branch -split '/')[0] } else { ($Branch -split '-')[0] }
if ($exempt -contains $prefix) {
    Write-Host "[OK] '$Branch' carries the exempt prefix '$prefix', which owes no entry."
    exit 0
}

# --- The entry --------------------------------------------------------------------------------------
# Same resolution open-pr uses, and for the same reason: the file has moved twice and a branch created
# before a move carries the older path. Preferring the current one and falling back is what lets a
# branch cut over mid-flight without this gate suddenly finding nothing -- which would not merely warn,
# it would PASS, since a gate with nothing to read reports nothing.
$safeName = if (Test-FunctionDefined 'Get-BranchInfo') {
    (Get-BranchInfo -Branch $Branch).SafeName
} else { $Branch -replace '/', '-' }

# -Branch IS PASSED RATHER THAN LEFT TO DEFAULT (#1255), and this is the one caller where that is not
# merely tidier. This gate runs in CI, where the checkout is a detached HEAD at the merge or head ref --
# so the resolver's HEAD fallback would find no branch name at all and fall back to the shared name. The
# branch is already resolved above, from the parameter the workflow passes.
$entryRel  = Resolve-BranchFilePath -Kind Deployment -RepoRoot $repoRoot -Branch $Branch
$entryPath = Join-Path $repoRoot $entryRel
if (-not (Test-Path -LiteralPath $entryPath)) {
    $entryPath = Join-Path $repoRoot ($safeName + '.md')
    $entryRel  = $safeName + '.md'
} elseif (-not (Test-BranchChangelogIsFilled -Text ([System.IO.File]::ReadAllText($entryPath, [System.Text.Encoding]::UTF8)))) {
    # Present but in its reset state: this branch may still be carrying a legacy root entry, and the
    # reset file must not be read as an empty one.
    $legacyPath = Join-Path $repoRoot ($safeName + '.md')
    if (Test-Path -LiteralPath $legacyPath) { $entryPath = $legacyPath; $entryRel = $safeName + '.md' }
}

if (-not (Test-Path -LiteralPath $entryPath)) {
    Write-Host "[ERROR] '$entryRel' does not exist, so this branch declares nothing." -ForegroundColor Red
    Write-Host '        The new-branch skill creates the branch and both of its files in one step; run it'
    Write-Host '        on this branch (it is idempotent) and write what the change does.'
    exit 1
}

# THE DEPLOY SECTION, NOT THE WHOLE DOCUMENT. The entry is a section of the branch's development document since
# August 23, 2026, and every reader below is entry-shaped -- handed the plan as well, the scaffold check
# would accuse the step list of being an unfinished entry. Get-DevelopmentEntryText hands back the
# whole text for a legacy file that IS an entry, so a branch created before the merge is read as it was.
$fileText  = [System.IO.File]::ReadAllText($entryPath, [System.Text.Encoding]::UTF8)
$entryText = Get-DevelopmentEntryText -Text $fileText

# "IS THIS THE RESET STATE" IS A QUESTION ABOUT THE DOCUMENT, NOT ABOUT THE SECTION -- and asking it of the
# section is a measured defect rather than a hypothetical. A reset document's DEPLOY section opens with a
# heading of its own, so the level half of Test-BranchChangelogIsFilled reads it as an entry: the gate then fell
# through to the scaffold check and refused a reset file with "has not been written yet" instead of "still
# in its reset state". Correct verdict, wrong reason, and the wrong reason sends the reader to write in a
# file they should not be writing in at all. Caught by branch-entry-gate.tests.ps1.
if (-not (Test-BranchChangelogIsFilled -Text $fileText)) {
    Write-Host "[ERROR] '$entryRel' is still in its empty reset state, so this branch has no entry." -ForegroundColor Red
    Write-Host '        The reset state is what the fold leaves behind after a merge; its heading names the'
    Write-Host '        TRUNK, and a written one names your branch. Run the new-branch skill on this branch'
    Write-Host '        and write what the change does.'
    exit 1
}

# AND "IS THERE AN ENTRY AT ALL" IS A THIRD QUESTION, ahead of the scaffold check rather than inside it
# (issue #1632). The two checks above and the one below cover three states -- no file, the reset state, an
# entry still carrying the scaffolder's wording -- and a document whose DEPLOY SECTION HAS BEEN DELETED is
# none of them. It passed all three: Get-DevelopmentEntryText's fallback handed the scaffold check the
# guidance PREAMBLE, which contains no scaffold marker because nobody scaffolded it, so the gate reported a
# written entry over a file with no entry text whatsoever. The scaffold gate passes by ABSENCE.
#
# ASKED OF THE DOCUMENT AND ANSWERED BY THE LIB, for the same reason the reset check above is: the
# predicate reads the document's SHAPE -- guidance blockquote, named phases -- and a second copy of that
# reasoning here would be free to disagree with open-pr's, which is the drift entry-scaffold-lib.ps1
# exists to prevent. Test-DevelopmentEntryMissing's own header carries the measurement.
#
# BEFORE the shape checks further down, deliberately. Those report '0 heading(s), and nothing but guidance
# above the first' as a PASS on exactly this document -- while the guidance it just read says in capitals
# FOUR HEADINGS, AND NEVER A FIFTH. #898 closed the upper bound and the lower one was never asserted, so
# zero was admitted. Refusing here means that line is never reached to say it.
if (Test-DevelopmentEntryMissing -Text $fileText) {
    Write-Host "[ERROR] '$entryRel' has no entry at all -- its DEPLOY section is gone." -ForegroundColor Red
    Write-Host '        This document carries a plan (its guidance block, its phases, or both) but no'
    Write-Host '        DEPLOY heading, so there is nothing for the fold to move into the changelog. Left'
    Write-Host '        as it is, the fold would paste the GUIDANCE into it as the change description.'
    Write-Host '        The new-branch skill is idempotent: run it on this branch to restore the section,'
    Write-Host '        then write what the change does.'
    exit 1
}

$scaffoldFindings = @(Get-EntryScaffoldFindings -EntryText $entryText -Wording (Get-EntryScaffoldWording))
if ($scaffoldFindings.Count -gt 0) {
    Write-Host "[ERROR] '$entryRel' has not been written yet:" -ForegroundColor Red
    foreach ($f in $scaffoldFindings) { Write-Host "          - $($f.Label): '$($f.Marker)'" -ForegroundColor Red }
    Write-Host '        Each line is a field the scaffolder left for you with nothing in it, wording it'
    Write-Host '        wrote that is still standing, or -- for a tier -- an answer written one line too'
    Write-Host '        low. The guidance comments do not count as an answer: the fold strips them, so a'
    Write-Host '        section that looks filled in on the branch lands in the changelog empty.'
    exit 1
}

Write-Host "[OK] '$entryRel' carries a written entry."

# --- The document's SHAPE: the phase arc (#898) and a generic preamble (#899) -------------------------
# BOTH RULES ARE THE LIB'S, and since September 8, 2026 (issue #1650) that is what lets open-pr.ps1 refuse
# them BEFORE the push. They were inline here, in the one gate of the five that runs only in CI and only
# ADVISORILY -- so nothing stopped a document that had lost its first phase heading: PR #1644 went through
# push, the required check, the merge and the fold with the shape rule red, and the fold then DELETED the
# file this check names, leaving an advisory finding pointing at a path a reader cannot open. What runs
# here is unchanged -- the same text, the same two rules, the same message.
#
# THE ARC IS THE SOURCE REPO'S RULE AND THE PREAMBLE HOLDS EVERYWHERE, and the switch is passed from here
# rather than read inside because this script has the repo root while the lib is handed a text.
# Get-DevelopmentShapeFindings's own header carries the measurement behind each, and the asymmetry.
$shape = Get-DevelopmentShapeFindings -Text $fileText -EnforcePhaseArc:(Test-IsWorkflowSourceRepo -RepoRoot $repoRoot)
$shapeFindings = @($shape.Findings)

if ($shapeFindings.Count -gt 0) {
    Write-Host "[ERROR] '$entryRel' $($shapeFindings[0])" -ForegroundColor Red
    foreach ($f in ($shapeFindings | Select-Object -Skip 1)) { Write-Host "        $f" -ForegroundColor Red }
    exit 1
}
# The level in this line is the one that was actually READ, not a literal: the lib derives the phase level
# from the document's own title, so a message naming '##' would have described the wrong shape for every
# document written after August 26, 2026 -- and a coverage line that misreports what it read is worse than
# none, because it reads as confirmation. Both numbers come back from the call that judged the document,
# which is what kept the findings and this line agreeing after a day when each composed its own.
Write-Host "[OK] '$entryRel' keeps its shape: $($shape.PhaseCount) '$($shape.PhaseMark)' heading(s), and nothing but guidance above the first."

# --- The DEPLOY lock: is the section still what the PR published? ------------------------------------
# Refused, not reported, which puts it with the checks above rather than with the significance below. The
# distinction is who the judgement belongs to: a significance score is the author's call about a finished
# change, so this gate names it and merges anyway; a section that no longer matches the PR is not a
# judgement at all, it is two copies of one text disagreeing, and the fold is about to pick one.
if ($Pr) {
    # -Utf8 for the same reason ship-pr.ps1 passes it (issue #907): this body is COMPARED against the
    # document, so it must not be decoded with whatever console code page the run inherited. CI runs
    # UTF-8 and would not have shown it; a local run of this gate is where it bites.
    $lockView = Invoke-NativeCapture -Utf8 -FilePath 'gh' -Arguments @('pr', 'view', "$Pr", '--json', 'body')
    # A SHORT READ COUNTS AS UNREADABLE HERE TOO (issue #1679). The -Utf8 arm can hand back an empty
    # Output with ExitCode 0, and this gate would then compare the section against an empty body and
    # report drift that is not there -- the advisory twin of the refusal ship-pr.ps1 makes on the same
    # read. The reason is carried rather than assumed, because the sentence below was written for a
    # token or a network and says the wrong thing about a read this run lost.
    $lockUnread = ''
    if ($lockView.ExitCode -ne 0) {
        $lockUnread = 'That is a statement about the token or the network, not about the section'
    } elseif ($lockView.ShortRead) {
        $lockUnread = 'gh exited 0 but its capture was still being written when it was read, so the body may be truncated -- a re-run normally settles it'
    }
    if ($lockUnread) {
        Write-Host "[INFO] PR #$Pr's body could not be read, so the DEPLOY lock was not checked." -ForegroundColor DarkYellow
        Write-Host "       $lockUnread." -ForegroundColor DarkYellow
    } else {
        $lockBody = ''
        try { $lockBody = [string](($lockView.Output -join "`n") | ConvertFrom-Json).body } catch { $lockBody = '' }
        $lock = Test-DeployLock -EntryText $entryText -PrBody $lockBody
        if (-not $lock.Applicable) {
            Write-Host "[OK] nothing to lock against PR #$Pr -- this entry carries no DEPLOY heading of its own."
        } elseif ($lock.Locked) {
            Write-Host "[OK] the DEPLOY section still matches what PR #$Pr published."
        } else {
            Write-Host "[ERROR] '$entryRel' has changed since PR #$Pr was opened." -ForegroundColor Red
            if ($lock.FirstDrift -eq $lock.Heading) {
                Write-Host "        PR #$Pr's body does not carry the section at all -- its heading is missing:" -ForegroundColor Red
                Write-Host "          $($lock.Heading)" -ForegroundColor Red
            } else {
                Write-Host '        The first line the PR body does not have is:' -ForegroundColor Red
                Write-Host "          $($lock.FirstDrift)" -ForegroundColor Red
            }
            Write-Host '        The DEPLOY section is fixed when the PR opens: it is what the review approved,'
            Write-Host '        and the fold puts it verbatim into CHANGELOG.md and from there into the release'
            Write-Host '        notes. Put it back to what the PR published, or republish it deliberately with'
            Write-Host '        open-pr.ps1 -RefreshBody so the change is reviewable where the review happens.'
            exit 1
        }
    }
} else {
    Write-Host '[INFO] no -Pr given, so the DEPLOY lock was not checked (every check above needs none).' -ForegroundColor DarkGray
}

# --- The significance: reported, never refused ------------------------------------------------------
if (Test-EntrySignificanceActive) {
    $impactFindings = @(Get-EntryImpactFindings -EntryText $entryText)
    if ($impactFindings.Count -gt 0) {
        Write-Host '[INFO] the significance is not settled yet -- the RELEASE CUT will refuse until it is,' -ForegroundColor DarkYellow
        Write-Host '       and this gate deliberately will not: a score is a judgement about a finished' -ForegroundColor DarkYellow
        Write-Host '       change, and an author who has not settled it is not blocked from merging over it.' -ForegroundColor DarkYellow
        foreach ($f in $impactFindings) { Write-Host "         $f" -ForegroundColor DarkYellow }
    } else {
        $impact = Resolve-EntryImpact -EntryText $entryText
        $scored = @($impact.Rows | Where-Object { [int]$_.Score -gt 0 } | ForEach-Object { "tier $($_.Tier): $($_.Score)" })
        if ($scored.Count -gt 0) { Write-Host "[OK] significance -- $($scored -join ', ')" }
    }
}

exit 0
