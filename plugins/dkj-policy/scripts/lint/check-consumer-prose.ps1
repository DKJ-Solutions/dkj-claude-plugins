<#
.SYNOPSIS
    Gate: does this consumer's own law-bearing prose contradict the plugin? Two detectors over one
    corpus, read once -- a RETIRED name of the branch's development document (issue #1389), and an
    inverted declaration putting this repo's own 'CLAUDE.md' above the workflow's contributing page
    (issue #1415). Merged into one script by issue #1421.

.DESCRIPTION
    THE HOLE THIS CLOSES, and it is one hole with two shapes. Nothing else reads a consumer's CLAUDE.md:
    check-script-contract.ps1 covers FUNCTIONS, so a renamed FILE CONVENTION and a rule stated in PROSE
    are both outside it by construction, and the CI leg the sibling gates have does not exist here -- a
    consumer's CI is not this plugin's to add. So the SessionStart hook is not a convenience on top of
    another route; it IS the route.

    WHY ONE SCRIPT AND NOT TWO, which is the whole of #1421. The two detectors were built an hour apart
    (#1389 merged as PR #1414; #1415 followed), and the second deliberately copied the first's shape
    rather than introducing a variant. That left the pair sharing their CORPUS -- Get-ConsumerProseDocuments
    -- and nothing else: two hook rows, two outer process launches, two nested 'powershell -File' spawns,
    two dot-sources of entry-scaffold-lib.ps1 and measure-context-lib.ps1, and two walks of the same
    ~8-document always-on closure, all on every session start in every consumer.

    MEASURED, on a consumer-shaped fixture carrying both defects, three passes each (September 5, 2026):

        before   retired-doc-name-sessioncheck      492 / 492 / 493 ms
                 supremacy-declaration-sessioncheck 498 / 494 / 503 ms
                 PAIR                               990 / 986 / 995 ms
        after    consumer-prose-sessioncheck        541 / 527 / 530 ms   (both blocks still reported)

    A saving of ~457 ms per session start, in every consumer, indefinitely -- slightly ABOVE the
    ~350-450 ms #1421 inferred from the component costs, which is worth stating because the issue was
    honest that no merged version had been built to measure. A bare 'powershell -NoProfile' hook launch
    that finds no check script measures ~155 ms on the same machine, which is what fixes the shape of it:
    one of the two outer launches goes, one of the two nested spawns goes, and one of the two
    dot-source-plus-walk passes goes. COMPARE THE PAIR, NEVER THE ABSOLUTE FIGURE -- both halves swing
    together with machine load, which is the same sensitivity #1401 closed by making a duration assert
    compare against its queue rather than against a fixed ceiling.

    AND IT IS NOT THE LARGEST ITEM ON THAT BILL, named so the next reader sizes it against the real
    total: measured in the same batch, all 7 SessionStart hooks came to ~6.8 s on this machine, of which
    connector-sessioncheck alone was ~4.9 s (~72%).

    WHAT DID NOT BLOCK IT, stated because the issue expected it to. #1421 deferred the merge on the
    ground that it would rename a consumer-facing hook one release after introducing it. Checked before
    building: NEITHER hook has ever been released. Both landed after the v4.29.0 tag and both sit in
    CHANGELOG.md's [Unreleased] section, so no consumer has ever received either name and the rename
    costs nobody anything. Doing it before the cut is strictly cheaper than doing it after.

    THE TWO DETECTORS STAY TWO FUNCTIONS, and that is not a compromise. Get-RetiredDocNameMention looks
    for a filename and Get-SupremacyDeclaration looks for a direction; they share which DOCUMENTS they
    may read and nothing about how they read them. What is merged here is the plumbing around them --
    the process, the root resolution, the skip, the lib loads and the corpus walk -- while each detector
    keeps its own measurement, its own suppressions and its own report block below.

    IT SKIPS THE REPO THAT PUBLISHES THE PLUGIN, on the source-repo guard's own condition 2
    ('.claude-plugin/marketplace.json' exists). For the retired-name detector that skip is a REPAIR:
    this repo's pages narrate the rename history on purpose, and without it the SOURCE reads as consumer
    drift, which is exactly what the first pass of #1380's measurement did. For the supremacy detector it
    is a GUARD rather than a repair: measured at zero hits here on the day it was written, because every
    supremacy sentence this repo carries names the plugin's page as the winner and adjacency reads that
    correctly. One skip serves both, and the honest reading of it differs per detector -- which is the
    kind of thing that drifts when it is written twice.

    Assert-OwnCopy is deliberately NOT used, for the reason check-unfolded-entry.ps1 and
    check-git-identity.ps1 give: a SessionStart hook invokes this from '${CLAUDE_PLUGIN_ROOT}/scripts/lint/'
    against the current repo, so the guard would refuse it -- and thereby the hook -- at every session
    start in the publishing repo. What the publishing repo needs here is a SKIP, which is a different
    question and the test below.

    NO gh, NO NETWORK. Every input is a file in the working copy, which is what lets the SessionStart
    hook run this in a consumer with no token.

    WHAT IT PRINTS OUT OF A CONSUMER'S FILES IS SANITIZED (#1419). Each finding names a path and echoes a
    LINE of the consumer's prose, and the hook forwards this whole report into session context while
    deciding what to surface by matching '[ERROR]' over it -- so a raw echo lets untrusted text choose how
    loudly it is reported, and repaint a terminal on the way past. Paths go through
    check-report-lib.ps1's Format-SafePathToken; prose goes through Format-SafeProseToken. The PLUGIN'S
    OWN strings stay raw, and in the retired-name block that is deliberate: Name comes from
    Get-BranchFileLegacyNames and Since is a sentence written in entry-scaffold-lib.ps1, so sanitizing
    either would be theatre and would quietly cap or reshape text this repo controls. The prose form
    substitutes square brackets rather than deleting them -- argued in full in that function's docstring,
    and disclosed to the reader in the footer each block prints.

    ONE CALLER, and it is automatic: the SessionStart hook consumer-prose-sessioncheck.ps1 in the workflow
    plugin. NO CI leg, deliberately -- a consumer's CI is not this repo's to add, and here the check skips
    by design.

    RUN IT FROM THE COMMAND LINE whenever you want the answer directly:

        powershell -NoProfile -File scripts/lint/check-consumer-prose.ps1

    Exit 0 when the prose is clean (or this is the publishing repo); exit 1 with the document, the line
    and the matched text otherwise. BOTH detectors always run -- the first one to find something does not
    short-circuit the second, because a session start that reported one defect and hid the other would be
    the worse half of the two-hook arrangement without the cost saving.

    Pure ASCII, per this repo's script-layer convention.

.PARAMETER RootOverride
    Repo root to operate on, for the test suite and the SessionStart hook. A consumer never types this:
    the root is resolved dual-context like every other shared script.

.PARAMETER RootDocument
    (Optional, for tests) the always-on root to walk instead of '<root>/CLAUDE.md'.

.EXAMPLE
    powershell -NoProfile -File scripts/lint/check-consumer-prose.ps1
#>
[CmdletBinding()]
param(
    [string]$RootOverride = '',
    [string]$RootDocument = ''
)

# Test-FunctionDefined (issue #1729): the seam probes below read the function table directly rather
# than through Get-Command, which parses the name as a wildcard pattern and pays a full PATH scan on
# every miss -- and a miss is the normal case for an optional seam. $PSScriptRoot-relative, so it
# resolves in the plugin mirror as well as here.
. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

# '' MEANS "COULD NOT TELL", and for an advisory session check that is nothing to judge rather than a
# failure. THE RESOLUTION IS SHARED, THE VERDICT IS NOT: this runs from a SessionStart hook, where a
# fixture tree or a session started outside a checkout must not strand the hook, so it exits 0 -- while
# a CI gate reading the same '' must refuse.
if (-not $repoRoot) {
    Write-Host '[OK] no git checkout here -- no always-on prose to judge.'
    exit 0
}

# THE SKIP. See the docstring: a repair for the retired-name detector and a guard for the supremacy one.
# Since #1422 it asks Test-IsWorkflowSourceRepo rather than re-testing the manifest file inline -- the
# question both detectors mean is "is this repo the source of THIS workflow's conventions", and the broad
# 'does this repo publish plugins' test answers a different one that Dave's one-product-one-repository
# rule guarantees will come apart.
. (Join-Path $PSScriptRoot '..\lib\seam-lib.ps1')
if (Test-IsWorkflowSourceRepo -RepoRoot $repoRoot) {
    Write-Host '[OK] this repo publishes the workflow -- its own pages are the source of these conventions, not a copy of them.'
    exit 0
}

# repo-config.ps1 first and optional, exactly as check-unfolded-entry loads it. Nothing here requires a
# seam today; it is loaded so that a repo which HAS answered one is read by its own names rather than by
# the built-in defaults, on the day a seam does reach this path.
$repoConfig = Join-Path $repoRoot 'scripts\repo-config.ps1'
if (Test-Path -LiteralPath $repoConfig -PathType Leaf) {
    try { . $repoConfig } catch { Write-Warning "scripts/repo-config.ps1 failed to load ($($_.Exception.Message)) -- the built-in wording is used." }
}

. (Join-Path $PSScriptRoot '..\lib\entry-scaffold-lib.ps1')

# THE SANITIZERS, for every value below that comes out of a CONSUMER'S OWN FILES (#1419).
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')

# THE WALK IS NOT REIMPLEMENTED HERE, and it happens ONCE -- which is the saving #1421 is about. Since
# #1422 its LOADING is not restated either: Get-CheckProseCorpus owns the guarded measure-context-lib load
# and the Get-AlwaysOnDocuments call. Get-AlwaysOnDocuments still owns the '@'-import closure (the hop cap,
# the cycle guard, the fenced-block skip and the tree/external split); Get-ConsumerProseDocuments owns
# which of those documents a consumer-prose check may look in, and both detectors below are handed the
# same rows. Still guarded rather than required: a tree that carries neither lib gets @() and still has
# the workflow folder's own pages judged, which is where one of #1389's two measured instances sat.
$documents = if (Test-FunctionDefined 'Get-CheckProseCorpus') {
    @(Get-CheckProseCorpus -RepoRoot $repoRoot -RootDocument $RootDocument)
} else { @() }

$retired  = @(Get-RetiredDocNameMention -RepoRoot $repoRoot -Documents $documents)
$inverted = @(Get-SupremacyDeclaration -RepoRoot $repoRoot -Documents $documents)

if ($retired.Count -eq 0 -and $inverted.Count -eq 0) {
    Write-Host '[OK] no retired branch-document name and no inverted supremacy declaration in this repo''s always-on prose.'
    exit 0
}

# THE RETIRED-NAME BLOCK (#1389).
if ($retired.Count -gt 0) {
    Write-Host "[ERROR] $($retired.Count) retired name(s) of the branch's development document are still stated here as current:" -ForegroundColor Red
    foreach ($f in $retired) {
        # Rel and Text are the consumer's; Name and Since are the PLUGIN'S OWN and stay raw -- see the
        # docstring. Rel is a path, so it takes the path-shaped sanitizer; Text is a sentence, so it takes
        # the prose-shaped one.
        Write-Host "          $(Format-SafePathToken -Value $f.Rel):$($f.Line)  names '$($f.Name)'" -ForegroundColor Red
        Write-Host "            $(Format-SafeProseToken -Value $f.Text)" -ForegroundColor DarkYellow
        Write-Host "            -> $($f.Since)" -ForegroundColor Red
    }
    Write-Host '        A consumer document may POINT at a shared convention, state this repo''s answer to a' -ForegroundColor Red
    Write-Host '        seam the plugin names, or say NOTHING -- never restate the convention in its own words.' -ForegroundColor Red
    Write-Host '        The rule is in CONTRIBUTING-portable.md, "The two contributing layers, and which one' -ForegroundColor Red
    Write-Host '        wins"; a restatement does not fail on the day it is written, only on the day the' -ForegroundColor Red
    Write-Host '        plugin''s answer moves under it. Replace each line above with a pointer.' -ForegroundColor Red
    Write-Host '        The echoed line is a PREVIEW, not the text: square brackets are shown as round ones' -ForegroundColor DarkGray
    Write-Host '        so nothing in it can be read as a marker of ours. Open it at the file and line above.' -ForegroundColor DarkGray
}

# THE SUPREMACY BLOCK (#1415). Printed after the block above and never instead of it: both detectors run.
if ($inverted.Count -gt 0) {
    Write-Host "[ERROR] $($inverted.Count) line(s) declare this repo's CLAUDE.md the winner over the workflow's contributing page:" -ForegroundColor Red
    foreach ($f in $inverted) {
        # All three are the consumer's: Rel is a path, Match and Text are prose. Nothing on these lines is
        # the plugin's own text, which is what makes this block untrusted end to end -- unlike the one
        # above, where the retired name and its "since" sentence come from the plugin and stay raw.
        Write-Host "          $(Format-SafePathToken -Value $f.Rel):$($f.Line)  matched '$(Format-SafeProseToken -Value $f.Match)'" -ForegroundColor Red
        Write-Host "            $(Format-SafeProseToken -Value $f.Text)" -ForegroundColor DarkYellow
    }
    Write-Host '        THE ORDER RUNS THE OTHER WAY. The plugin''s portable pages and skills outrank' -ForegroundColor Red
    Write-Host '        dkj-policy/CONTRIBUTING.md, which outranks this repo''s own CLAUDE.md --' -ForegroundColor Red
    Write-Host '        see CONTRIBUTING-portable.md, "A third rank sits above both". A line above inverts it,' -ForegroundColor Red
    Write-Host '        so a session reading that page and a session reading CLAUDE.md follow different rules' -ForegroundColor Red
    Write-Host '        and neither is wrong on the page it read.' -ForegroundColor Red
    Write-Host '        A repo that genuinely wants its own constitution to lead states that as a SEAM answer,' -ForegroundColor Red
    Write-Host '        not by overriding the page in prose. Otherwise replace each line above with a pointer.' -ForegroundColor Red
    Write-Host '        The phrase and the line are a PREVIEW: square brackets are shown as round ones, so' -ForegroundColor DarkGray
    Write-Host '        nothing in them reads as a marker of ours. Open the file and line above for the text.' -ForegroundColor DarkGray
}

exit 1
