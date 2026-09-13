<#
.SYNOPSIS
    Reports which of this workflow's four canonical triage-priority labels ('prio-1' through
    'prio-4') this repository's tracker is missing, and prints a paste-ready `gh label create` line
    for each one -- never creates a label itself. Issue #1895, split from #1843.

.DESCRIPTION
    THE GAP THIS CLOSES. `.claude/specialists/lenses/01-01-extension.md` (this workflow's own source
    repo) prescribes a priority label on every issue it files -- 'prio-1' (lowest) through 'prio-4'
    (highest) -- but until now that scale was PROSE in one family's page and nothing in `dkj-policy`
    itself knew the four names, so a consumer adopting the convention had to read that page, retype
    four names and guess at four colours. #1895 (split from #1843) asked three questions and Dave
    answered all three on 2026-09-12: apply or print (PRINT, see below), is there a shared set at all
    (YES, one set, not a per-consumer table), and where it is declared (its OWN seam, not
    `branch-info.ps1`'s -- see the contract record's AdoptWhy for why that seam was the wrong home).

    IT NEVER CREATES A LABEL, AND THIS IS NOT THE FIRST TIME THAT LINE WAS DRAWN. `Get-MissingLabelNote`
    in `pr-issues-lib.ps1` already refuses to substitute or drop a missing PR label for exactly this
    reason: "both silent options look like kindnesses and both break a repo that gates on the label."
    Creating a label is a GitHub-side write with the same shape as the ruleset write
    `adopt-ci-floor.ps1` refuses to make -- irreversible in the sense that matters (every future `gh
    label create`/`gh issue create --label` in this repo now resolves against it) and outward-facing.
    So this script does what that function already does, one layer up: it composes the exact command
    a person would type and stops. There is deliberately NO -Apply switch here, unlike
    `adopt-ci-floor.ps1` -- that script's -Apply places LOCAL WORKFLOW FILES beside a ruleset it
    still only reports on; a label has no such local-file half, so there is nothing this script could
    ever apply short of the write itself, which stays a person's call.

    ONE SHARED SET, NOT A PER-CONSUMER TABLE. `Get-TriageLabels` in `scripts/repo-config.ps1` is
    `Adopt = 'copy'` in the script contract, not `'decide'` like `Get-BranchInfo`. The two axes look
    alike -- both are seams a consumer answers in their own repo-config -- and the difference is the
    same one `Get-ReachLabel` already drew one axis over (issue #1870): a 'decide' value states WHAT
    THE REPO IS (three branch prefixes because THIS repo lands a release directly on its trunk), and
    copying it would assert something about a consumer that may be false. 'prio-1' through 'prio-4'
    assert nothing about the adopting repo at all -- they are four rungs of urgency, and the rungs mean
    the same thing everywhere this workflow runs. Refusing to share them would leave every consumer to
    reinvent four names and four colours on their own, which is the exact "prose in one family's page"
    #1895 was filed about.

    NOT THE SAME QUESTION AS #1686, AND NOT A REVERSAL OF IT. #1686 (closed 2026-09-09) kept this
    repo's `prio-*` rungs and the BWJ tracker's own reach BUCKETS deliberately disjoint -- a different
    axis, so a session crossing families gets a refused label rather than one that quietly means
    something else there. This script never touches dkj-policy-bwj's buckets or `Get-ReachLabel`'s
    reach axis; it only offers the priority axis to an ordinary dkj-policy consumer that has no BWJ
    board of its own.

    TWO DIFFERENT GUARDS, AND THIS SCRIPT CARRIES ONLY ONE OF THEM. `source-repo-guard-lib.ps1`'s
    `Assert-OwnCopy` is the UNIVERSAL one every person-invoked shared script in this family carries
    (`source-repo-guard.tests.ps1`'s own coverage assert enforces it, with an exemption reserved for a
    hook nobody types): it refuses a STALE, released copy of THIS script running from inside the repo
    that maintains it, and does nothing anywhere else. This script has it, right below.
    `Test-IsWorkflowSourceRepo`, the SEPARATE, content-specific refusal `adopt-ci-floor.ps1` and
    `adopt-workflow-folder.ps1` carry, is different: it refuses the whole OPERATION in the source repo,
    because those commands WRITE local files that would collide with the hand-kept originals they are
    derived from. This script writes nothing anywhere -- it only reads `gh label list` and prints -- so
    there is nothing for that second guard to protect, and running it here simply checks this repo
    against its own canonical answer instead of conflicting with anything (which is exactly what the
    test suite does). If that ever changes, the argument to add it is a write this script gained, not
    one it always had.

    NO DRIFT DETECTION. A label that already exists is reported '[ok]' without comparing its colour or
    description against the canonical values -- that is a different, harder problem (a repo may have
    deliberately retextured its own label) and #1895 scoped it out. This script only answers "does a
    label with this name exist at all", the same question `Get-MissingLabelNote` already asks and the
    same case-insensitive comparison, because GitHub itself is case-insensitive on label names.

    STRICTLY READ-ONLY, NEVER A GATE. Nothing in this workflow refuses a PR or a merge over a missing
    triage label -- unlike the reach label, which `open-pr`/`ship-pr` never read either but which a
    consumer's OWN `gh issue create` call fails on if it names a label that is not there. This script
    exists so that failure never has to happen: run it once after adopting the convention, paste
    whatever it prints, and `gh issue create --label prio-2` (or your tracker's equivalent) resolves.

    RUN IT FROM THE ROOT OF THE CONSUMING REPO:

        powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/adopt-triage-labels.ps1"

    Always exits 0: this is a report, not a gate, and a missing label is a to-do rather than a defect
    -- the same reasoning `plugin-versions.ps1` gives for its own always-0 exit.

    Pure ASCII (repo convention for .ps1).

.PARAMETER LabelJsonOverride
    A file holding a `gh label list --json name,color,description` payload, read instead of calling
    gh. For the test suite, which has to reach every arm (missing labels, all present, an unreadable
    payload) without a network or a real repo. A consumer never types it.

.EXAMPLE
    .\scripts\task\adopt-triage-labels.ps1
#>

[CmdletBinding()]
param(
    [string]$LabelJsonOverride = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD: refuses THIS script when it is a released copy running in the repo that
# maintains it -- the universal one, not the content-specific Test-IsWorkflowSourceRepo (see the
# header). Guarded dot-source, so a tree without the lib behaves as before. Why: the lib's own header.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# Dual-context repo root: a consumer running the plugin mirror gets it from CLAUDE_PROJECT_DIR, the
# source's root copy falls back to the git root. Same resolution as every other mirrored script.
$repoRoot = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (git rev-parse --show-toplevel).Trim() }

# repo-config.ps1 first and optional, exactly as adopt-ci-floor loads it: it supplies Get-RepoName
# and (once a consumer has adopted it) Get-TriageLabels. Absent or not yet defining either is the
# ordinary state for a fresh adoption, not a failure -- every read below has a fallback.
$repoConfig = Join-Path $repoRoot 'scripts\repo-config.ps1'
if (Test-Path -LiteralPath $repoConfig -PathType Leaf) {
    try { . $repoConfig } catch { Write-Warning "scripts/repo-config.ps1 failed to load ($($_.Exception.Message)) -- the built-in canonical labels are used instead." }
}

. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\pr-issues-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')

# --- The canonical four, with a BUILT-IN fallback ---------------------------------------------------
# Get-TriageLabels is Optional in the script contract, so a repo that has not yet run adopt-config (or
# is on a plugin version older than this seam) does not define it -- and that must not read as "no
# canonical set exists". The four values below are this repo's OWN live labels (read back from
# `gh label list --repo DKJ-Solutions/dkj-claude-plugins` at the time this was written) and must stay
# byte-identical to $script:TriageLabels in scripts/repo-config.ps1: the two are one answer stated
# twice for the same reason Get-EntryFallbackType's 'Chore' is -- a consumer who has adopted the seam
# and one who has not must never be told two different canonical sets.
$builtInTriageLabels = @(
    [pscustomobject]@{ Name = 'prio-1'; Color = '006B75'; Description = 'Priority 1 of 4 (lowest) -- nobody is waiting for it' }
    [pscustomobject]@{ Name = 'prio-2'; Color = 'FBCA04'; Description = 'Priority 2 of 4 -- worth doing, no pressure' }
    [pscustomobject]@{ Name = 'prio-3'; Color = 'D93F0B'; Description = 'Priority 3 of 4 -- do this before the ordinary backlog' }
    [pscustomobject]@{ Name = 'prio-4'; Color = 'B60205'; Description = 'Priority 4 of 4 (highest) -- takes precedence over other work' }
)

# @(...) WRAPS THE WHOLE if/else, NOT JUST EACH BRANCH -- the trap this repo's own manual catalogues
# under the PowerShell traps that produce well-formed wrong output. An if-block used as an expression
# EMITS its last value through the normal output stream, which auto-enumerates an array; assigning that
# to a variable then RE-COLLECTS however many objects came out -- so a branch of four elements survives
# as an array of four, and a branch of exactly ONE element collapses to that single object, unwrapped,
# even though the branch itself wrote '@(Get-TriageLabels)'. A consumer's Get-TriageLabels returning one
# label (issue #1895's own test suite) then made $triageLabels a bare [pscustomobject], and the next
# line's '.Count' threw under Set-StrictMode instead of ever comparing. Wrapping the ENTIRE expression
# forces array semantics regardless of how many elements either branch produces.
$triageLabels = @(if (Test-FunctionDefined 'Get-TriageLabels') { @(Get-TriageLabels) } else { $builtInTriageLabels })
if ($triageLabels.Count -eq 0) {
    # A seam that resolves to nothing is not "no canonical set" here -- the built-in copy is what a
    # consumer without the seam already relies on, so an emptied override falls back to it too rather
    # than reporting a set of zero labels as if that were the answer.
    $triageLabels = $builtInTriageLabels
}

# --- Which repo, and its current labels --------------------------------------------------------------
$repoSlug = ''
if (Test-FunctionDefined 'Get-RepoName') { $repoSlug = [string](Get-RepoName) }
if (-not $repoSlug) {
    # No seam answer: ask gh what repo this checkout is, exactly as adopt-ci-floor does for the same
    # reason -- a fresh adoption has not necessarily answered Get-RepoName yet, and refusing here would
    # gate this report on a seam that has nothing to do with it.
    $slugRead = Invoke-NativeCapture -FilePath 'gh' -DiscardStderr -Arguments @('repo', 'view', '--json', 'nameWithOwner', '--jq', '.nameWithOwner')
    if ($slugRead.ExitCode -eq 0) { $repoSlug = ($slugRead.Output -join '').Trim() }
}

$labelJson = ''
if ($LabelJsonOverride) {
    if (Test-Path -LiteralPath $LabelJsonOverride -PathType Leaf) {
        $labelJson = [System.IO.File]::ReadAllText($LabelJsonOverride)
    }
} elseif ($repoSlug) {
    # --limit 500, the same guard open-pr.ps1 already applies to this exact command: gh label list
    # defaults to 30, and a truncated list would report a label as missing when it is only unlisted.
    $labelArgs = @('label', 'list', '--repo', $repoSlug, '--json', 'name,color,description', '--limit', '500')
    # -DiscardStderr because this output is PARSED: a gh warning merged into it would break the
    # ConvertFrom-Json inside Get-LabelNames, exactly the reasoning adopt-ci-floor's own rules read
    # gives for the same flag.
    $labelRead = Invoke-NativeCapture -FilePath 'gh' -DiscardStderr -Arguments $labelArgs
    if ($labelRead.ExitCode -eq 0) { $labelJson = $labelRead.Output -join "`n" }
}

function Format-SingleQuotedArg {
    <#
        Escapes $Value for a paste-ready PowerShell single-quoted argument, by doubling any embedded
        single quote -- the exact escape PowerShell itself reads back as one literal quote inside a
        '...' string.

        WHY THIS EXISTS AT ALL (security review finding on issue #1895's own PR). The four BUILT-IN
        canonical labels happen to carry no apostrophe, which is why this bug shipped unnoticed through
        this script's own first test pass: nothing exercised it. But Get-TriageLabels is
        Adopt = 'copy' and Optional, which means a consumer is free to answer the seam with their own
        Name/Color/Description -- arbitrary free text, and test 6 in adopt-triage-labels.tests.ps1
        already proves the seam fully replaces the built-in set. A Description containing an ordinary
        apostrophe ("won't wait", "team's convention") would close the surrounding '...' early in the
        composed `gh label create` line, and the rest of that line would spill out as separate,
        unintended shell tokens the moment a person pastes it -- which is the entire point of this
        script: it never runs the command itself, so the printed line IS the product, and it has to be
        safe to paste unmodified.

        NOT NEEDED ON THE '[ok]'/'[missing]' DISPLAY LINES, deliberately: those are prose read by a
        person, never composed into something a shell parses, so escaping there would only make an
        apostrophe read oddly for no safety gained. This function is called at exactly the one site
        that builds a command line.
    #>
    param([string]$Value)
    return ($Value -replace "'", "''")
}

# Get-LabelNames only reads the 'name' field of each record and ignores the rest -- exactly what this
# script needs, since colour/description drift on an EXISTING label is out of scope (see the header).
#
# EMPTY IS "UNKNOWABLE" AND NOT "ABSENT" -- the exact contract Get-LabelNames already documents for its
# other caller, Get-MissingLabelNote, and deliberately not distinguished here from "could not even ask"
# (a failed gh call, a missing override file, a network hiccup): GitHub creates several default labels
# on every repository, so a genuinely label-less repo is not a real case worth telling apart from an
# unreadable one, and collapsing the two into one signal is what Get-MissingLabelNote already does --
# `if ($known.Count -eq 0) { return '' }`, no matter why the count is zero.
$existingNames = @(Get-LabelNames -Json $labelJson)

# --- Report --------------------------------------------------------------------------------------------
Write-Host "== adopt-triage-labels -- $repoRoot ==" -ForegroundColor Cyan
Write-Host '  READ-ONLY -- this command never runs gh label create. It only prints the command.' -ForegroundColor Yellow
Write-Host ''

if ($existingNames.Count -eq 0) {
    Write-Host "  [skip]    could not read this repo's labels$(if ($repoSlug) { " ($repoSlug)" } else { '' }) -- no gh, no network, or a token that cannot list them." -ForegroundColor DarkGray
    Write-Host '            Nothing below was judged against a list that could not be read.' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host "  Read it yourself with:  gh label list --repo <owner>/<repo> --json name,color,description --limit 500" -ForegroundColor DarkGray
    exit 0
}

$missing = 0
$ok = 0
foreach ($label in $triageLabels) {
    # Case-INSENSITIVE, because that is how GitHub treats a label name: it refuses to create 'Prio-2'
    # beside 'prio-2', and attaching 'prio-2' would resolve to the existing 'Prio-2'. Same comparison
    # Get-MissingLabelNote already makes for the same reason.
    $exists = @($existingNames | Where-Object { $_ -eq $label.Name }).Count -gt 0
    if ($exists) {
        $ok++
        Write-Host "  [ok]      '$($label.Name)' already exists" -ForegroundColor Green
        continue
    }
    $missing++
    $repoArg = if ($repoSlug) { " --repo $repoSlug" } else { '' }
    Write-Host "  [missing] '$($label.Name)' -- $($label.Description)" -ForegroundColor Yellow
    # ESCAPED HERE, AND ONLY HERE (see Format-SingleQuotedArg's own docstring): this is the one line
    # that composes an actual command a person pastes, and Name/Color/Description all come from
    # $triageLabels -- the built-in four today, but a consumer's own free-text Get-TriageLabels answer
    # tomorrow, which test 6 in adopt-triage-labels.tests.ps1 proves fully replaces them.
    $qName = Format-SingleQuotedArg -Value $label.Name
    $qColor = Format-SingleQuotedArg -Value $label.Color
    $qDescription = Format-SingleQuotedArg -Value $label.Description
    Write-Host "            gh label create '$qName' --color '$qColor' --description '$qDescription'$repoArg" -ForegroundColor Yellow
}

Write-Host ''
if ($missing -eq 0) {
    Write-Host "Done: all $ok canonical triage label(s) already exist$(if ($repoSlug) { " in $repoSlug" } else { '' })." -ForegroundColor Green
} else {
    Write-Host "$missing of $($triageLabels.Count) canonical triage label(s) missing$(if ($repoSlug) { " in $repoSlug" } else { '' }); $ok already exist. Paste the command(s) above -- nothing was created." -ForegroundColor Yellow
}

# ALWAYS 0. This is a report, never a gate: nothing in this workflow refuses a PR or a merge over a
# missing triage label, so a missing one is a to-do rather than a live defect -- the same reasoning
# plugin-versions.ps1 gives for its own always-0 exit.
exit 0
