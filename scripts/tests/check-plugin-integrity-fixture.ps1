<#
.SYNOPSIS
    Shared fixture, assert helpers and gate runner for the ten check-plugin-integrity suites.

.DESCRIPTION
    NOT NAMED *.tests.ps1 ON PURPOSE: the test gate globs that pattern, and this file asserts
    nothing. It is dot-sourced by the ten suites that do:

      check-plugin-integrity-links.tests.ps1        checks 4 and 28 -- the scan set, links and imports
      check-plugin-integrity-skill-spans.tests.ps1  check 10 and scenario 16 -- the skills:all spans
      check-plugin-integrity-plugin-spans.tests.ps1 checks 29 and 32 -- the plugin-scoped spans
      check-plugin-integrity-plugin-links.tests.ps1 check 30 -- a plugin link must stay in its plugin
      check-plugin-integrity-commands.tests.ps1     checks 11 and 12 -- printed commands and queries
      check-plugin-integrity-entries.tests.ps1      checks 13, 13b, 14-16 -- entries, templates, figures
      check-plugin-integrity-docs.tests.ps1         checks 19, 20, 20b, 20c, 25 -- consumer documents
      check-plugin-integrity-scripts.tests.ps1      checks 18, 39, 40, 27, 35 -- the script layer
      check-plugin-integrity-invocations.tests.ps1  checks 22, 42, 42b, 24, 26 -- printed invocations
      check-plugin-integrity-roster.tests.ps1       checks 6b, 38, 45, 3d and -SkipCheck -- defs and names

    WHY THERE IS MORE THAN ONE, MEASURED THREE TIMES. The gate parallelises per FILE, so the only way
    to give a heavy suite's work the idle lanes is to make it more than one file -- and the same
    measurement has now forced the same answer at two different scales, the second of them twice.

      #714, August 16, 2026 -- the FIRST split, one file into four. As one file this suite ran the
      gate 111 times in sequence, took 160s standalone and 196-213s inside the parallel gate -- and
      the gate's whole wall clock WAS this suite, to a tenth of a second, in four runs out of four.
      Every other suite finished at 126.9s, after which one process ran alone for another 70-86
      seconds with 15 of 16 lanes empty.

      #2304, September 22, 2026 -- the SECOND split, -docs into four. The same failure had regrown
      inside the largest of the four: at 669.1s on CI against a 391s work bound over 16 lanes,
      -docs alone WAS the gate's critical path, and the measured CI duration (11.5 min) matched that
      one file's recorded duration to within 0.3 min. #1358 had priced this split and declined it,
      correctly, when that file was 221.8s; it was three times that when the decision was revisited,
      so the gap it was weighed against had gone from ~15s to 278s. Standalone the split takes the
      family's longest file from 235.8s to 64.3s.

      #2304, September 23, 2026 -- the THIRD split, -links into four, which step 2 had named as the
      next critical path (539.2s on CI). Cut at check boundaries and balanced on gate invocations,
      13/18/21/13 of its 65; checks 4 and 28 stay together because scenario 23 compares their two
      coverage counts inside one run. Side by side on one workstation the longest part took 55s
      against the original's 159s.

    NOTHING WAS REMOVED TO BUY THE TIME, AT ANY SPLIT. The suites carry the same scenarios against
    the same fixture -- the asserts still sum to the count the single file reported, which is 188
    across the four -docs descendants and 141 across the four -links descendants, both verified by
    running them. Narrowing test scope was explicitly refused in #714 and is not what happened on
    any occasion.

    BOTH #2304 SPLITS SURFACED A LATENT ORDER DEPENDENCY, and both are repaired here rather than
    worked around by the grouping -- see the scripts\task note in New-IntegrityFixture and
    Write-QuietRootDocuments. A scenario that inherits state an earlier scenario created only works
    while the two share a file, which is precisely the property a cost-based partition may not
    depend on.

    EACH SUITE BUILDS ITS OWN FIXTURE, in its own per-process directory. They run CONCURRENTLY under
    the gate, so a shared path would have them tearing down each other's tree mid-assert -- the exact
    failure test-suite-gate.tests.ps1 pins the $PID convention against.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

# JUDGING THIS FIXTURE'S OWN CHILD -- issues #1934 and #1954. Invoke-Integrity copies the gate into a
# fixture tree together with the libs it dot-sources, so a lib the copy list has gone stale on kills the
# child during LOAD and every scenario below then measures a gate that never ran. Placed here rather than
# in each suite because the invocation and the close-out are both shared: this one wiring covers all four
# check-plugin-integrity suites.
. (Join-Path $PSScriptRoot '..\lib\fixture-script-lib.ps1')

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$IntegritySrc      = Join-Path $RepoRoot 'scripts\lint\check-plugin-integrity.ps1'
$AgentSharedLibSrc = Join-Path $RepoRoot 'scripts\lib\subagent-shared-lib.ps1'
$SharedScriptsLibSrc = Join-Path $RepoRoot 'scripts\lib\shared-scripts-lib.ps1'
# Third dot-sourced dependency since #221: check-report-lib.ps1, for the non-counting Write-Coverage
# line every category closes with. Copied like the other two, so the fixture runs the REAL script.
$CheckReportLibSrc = Join-Path $RepoRoot 'scripts\lib\check-report-lib.ps1'
# Fourth and fifth dot-sourced dependencies: release-lib.ps1 and the branch-info.ps1 it dot-sources
# from its own folder. Both are copied for the same reason as the three above -- the fixture runs the
# REAL script, so a missing dependency is a broken suite rather than one skipped check. They arrived
# for check 17 and outlived it: the lint still dot-sources release-lib, so a fixture without it is a
# suite that cannot start rather than one check fewer.
$ReleaseLibSrc = Join-Path $RepoRoot 'scripts\lib\release-lib.ps1'
$BranchInfoSrc = Join-Path $RepoRoot 'scripts\lib\branch-info.ps1'
# Sixth, since the tier model (August 5, 2026): release-lib dot-sources entry-scaffold-lib.ps1 for the
# changelog's tier sections. Copied for the same reason as the five above -- this fixture runs the REAL
# script, so a missing sibling is a broken suite rather than one skipped check.
$EntryScaffoldSrc = Join-Path $RepoRoot 'scripts\lib\entry-scaffold-lib.ps1'
# Seventh, since #1650: entry-scaffold-lib.ps1 dot-sources this one for Get-DisplayRef -- see the copy
# below for what a fixture that forgets it looks like.
$RefPrintLibSrc = Join-Path $RepoRoot 'scripts\lib\ref-print-lib.ps1'
# Seventh, since the plugin set became derived (August 9, 2026): plugin-tree-lib.ps1, dot-sourced by
# release-lib AND by shared-scripts-lib, and read by the lint itself for the published plugin roots.
# Copied for the same reason as the six above.
$PluginTreeSrc = Join-Path $RepoRoot 'scripts\lib\plugin-tree-lib.ps1'
# Eighth, since check 24 (August 10, 2026): pr-body-lib.ps1 holds the recognised placeholder strings and
# the reference PR template, both dot-sourced by the lint. Copied for the same reason as the seven above.
$PrBodyLibSrc = Join-Path $RepoRoot 'scripts\lib\pr-body-lib.ps1'
# Ninth, since check 28 (August 26, 2026): measure-context-lib.ps1 holds the '@'-import parser the lint
# resolves import targets with. Copied for the same reason as the eight above -- a lib the fixture does
# not carry does not make one check misbehave, it kills the script at the dot-source and every check
# after it silently never runs.
$MeasureContextSrc = Join-Path $RepoRoot 'scripts\lib\measure-context-lib.ps1'
# seam-lib.ps1 -- added August 27, 2026, when checks 11, 19 and 20b stopped naming 'CHANGELOG.md' as a
# literal and started reading Get-ChangelogPath the way the fold reads it. Exactly the failure the
# paragraph above describes: without this copy the gate dies at that dot-source, before check 11, and four
# suites report dozens of unrelated scenarios as broken.
$SeamLibSrc = Join-Path $RepoRoot 'scripts\lib\seam-lib.ps1'
# Dot-sourced into the RUNNER as well as copied into the fixture: check 13b's scenarios build their
# template files from Get-BranchTemplates, so the test and the check read the same definition. A fixture
# written out by hand here would be the very second source of the format that check exists to prevent.
# Check 24's scenarios do the same with Get-PrTemplateReference, for the same reason.
. $EntryScaffoldSrc
. $PrBodyLibSrc
$script:pass = 0
$script:fail = 0

function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    if ($Expected -eq $Actual) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red
    }
}

# THE THREE CHECKS THIS SUITE SKIPS BY DEFAULT. Profiled when this was one file, agent-def, parse and
# branch-template were reported as half of every run's work, and almost no scenario here is about those
# three -- so the fast path became the default.
#
# THAT SAVING IS NOW 2.0%, RE-MEASURED September 3, 2026 (issue #1358), and the figure is corrected here
# rather than the skip removed. Over this fixture a full invocation is 1.390s and the -SkipCheck one
# 1.362s. The reason is the fixture rather than the checks: it carries 2 skills, no manuals and no
# personas, so agent-def, parse and branch-template have almost nothing to walk in it -- the 'half of
# every run' figure cannot have been this tree. What actually dominates an invocation here was measured at
# the same time: ~283ms (21%) is fixed overhead the child process pays before any check runs -- spawn,
# the 3419-line parse, the libs -- and the rest is the checks' own work, of which barred-skill and
# shopify-cli were 216ms and 174ms until #1358 gave them one shared pass.
#
# SO DO NOT REACH FOR -SkipCheck FOR SPEED. It buys 2% and it is the one knob here that can make an
# absence assert pass vacuously; it stays the default only because the scenarios do not need those three,
# not because it is fast.
#
# NINE SCENARIOS PASS -Full, and this is the complete list: in the entries suite, the six check-13b
# branch-template scenarios (r13bAbsent, r13bOnBranch, r13bLeftover, r13bNameless, r13bMaster,
# r13bMainOnMaster) and the [COVERAGE] scenario (which asserts 'agent-def' reports its count); in the docs
# suite, the frontmatter-bom scenario and the one that writes a hook which does not parse and asserts
# check 5 reports it. That last one is the shape to be careful about -- an assert about a SKIPPED check
# proves nothing either way under the default, which is why its own comment says so.
#
# It said FOUR until September 3, 2026 (issue #1358), naming two scenarios (r13bGood, r13bGone) that no
# longer exist -- a count in a comment that the split and check 13b's growth had both moved past.
#
# If you add a scenario that asserts anything about those three checks, pass -Full. A presence assert
# fails loudly without it; an absence assert does not, which is why this note is here rather than in a
# commit message.
$script:SkippedForSpeed = 'agent-def,parse,branch-template'

function Invoke-Integrity {
    param([string]$FixtureRoot, [switch]$Full)
    $scriptPath = Join-Path $FixtureRoot 'scripts\lint\check-plugin-integrity.ps1'
    $skipArgs = if ($Full) { @() } else { @('-SkipCheck', $script:SkippedForSpeed) }
    # $ErrorActionPreference IS RELAXED AROUND THE CHILD CALL, the same way Invoke-Fold does it in
    # fold-changelog.tests.ps1. With 'Stop' in force, anything the gate writes to stderr comes back as a
    # terminating NativeCommandError and kills THIS script -- so a scenario that makes the gate crash
    # aborts the suite mid-run instead of failing its own assert. Measured while adding the corrupt-
    # marketplace scenario: the run ended at this line with a raw exception and printed neither a [FAIL]
    # nor a total, which is a test that discriminates but cannot say why. A gate crashing is exactly the
    # kind of thing this suite exists to catch, so it has to survive catching it.
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @skipArgs 2>&1
        $code = $LASTEXITCODE
        # #1934: a load failure is not a gate crash -- say so before the scenarios read an empty verdict.
        Assert-FixtureScriptLoaded -Code $code -Script $scriptPath -Output $out
    } finally {
        $ErrorActionPreference = $prevEap
    }
    return [pscustomobject]@{ Code = $code; Out = ($out -join "`n") }
}

$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
$deadLink = './this-file-does-not-exist-xyz.md'

# THE ONE PIECE OF SCENARIO STATE TWO SUITES SHARE, and the only reason it is here rather than in a
# scenario. The commands suite writes this quiet CONTRIBUTING.md for scenario 24 (proving history is
# excluded); the entries suite restores it before the [COVERAGE] block, which needs a root document
# that prints no lifecycle command. While the two were one file the second use simply read the first's
# variable, 500 lines further down. A copy in each file would be free to drift, and the drift would
# show up as a coverage assert failing in a suite that never wrote the file.
$s24Contributing = @('# Contributing', '', 'Nothing to run here.')

# THE QUIET ROOT DOCUMENTS -- issue #2304, the -links split. The fixture itself writes neither
# CONTRIBUTING.md nor the connectors README; check 4's scenarios A and B do, first broken and then fixed,
# and while checks 10, 28, 29, 30 and 32 shared that file every one of them started from the FIXED pair
# without saying so. Two of them lean on it outright: check 28's scenario 19 needs a CONTRIBUTING.md at
# the root to prove the import rule is file-relative, and check 32's scenario 49 reads the file back to
# restore it. So the suites split out of -links call this first, and it writes exactly what scenario B
# leaves behind -- the same state, stated once, rather than inherited from whichever scenario ran above.
function Write-QuietRootDocuments {
    param([Parameter(Mandatory)][string]$Fixture)
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), "# Contributing`n`nNothing to link to here.`n", $Utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'connectors\README.md'), "# Connectors`n`nNothing to link to here.`n", $Utf8NoBom)
}

# The fixture every one of the four suites starts from: a throwaway repo root holding the REAL
# check-plugin-integrity.ps1 and its dot-sourced libs, a marketplace declaring three plugins, a
# canonical two-skill skillset with its depth decoy, and the generated PR template. It ends where
# the first scenario used to begin, so each suite starts from the same canonical state instead of
# from whatever the previous scenario left behind.
function New-IntegrityFixture {
    param([Parameter(Mandatory)][string]$Fixture)
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture }
    New-Item -ItemType Directory -Path (Join-Path $Fixture 'scripts\lint') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Fixture 'scripts\lib') -Force | Out-Null
    # scripts\task IS FIXTURE INFRASTRUCTURE, NOT ONE SCENARIO'S SETUP -- issue #2304. Two independent
    # checks write into it: 18 (a shared script's parameters against its skill, via park-branch.ps1) and
    # 42b (a printed powershell command in the script layer, via ep-fixture.ps1). While both sat in one
    # file, 18 ran first and created the directory, and 42b inherited it -- an order dependency nothing
    # declared and nothing tested. The split that moved them into separate suites is what surfaced it:
    # 42b alone died at its first WriteAllText with DirectoryNotFoundException. Created here beside
    # scripts\lint and scripts\lib so each scenario owns its own state, which is what lets the suites be
    # partitioned on cost rather than on which one happens to run first.
    New-Item -ItemType Directory -Path (Join-Path $Fixture 'scripts\task') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Fixture 'connectors') -Force | Out-Null
    # check 10 fixture: two canonical skills (skill-alpha, skill-beta) plus a DEPTH DECOY -- a
    # SKILL.md one level deeper (skills/<name>/references/SKILL.md) that must NOT be picked up as a
    # third canonical skill, exercising the exact-depth binding of check 10's canonical-skillset scan.
    New-Item -ItemType Directory -Path (Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-alpha\skills\skill-alpha\references') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-alpha\skills\skill-beta') -Force | Out-Null

    # The marketplace: what makes those directories PLUGINS rather than just directories. EVERY plugin
    # the shared-scripts registry names is declared here, each with a manifest, so checks 1 and 2 pass
    # cleanly and the registry resolves. See this file's header for why the fixture stopped being
    # marketplace-less.
    #
    # THAT LIST HAS TO GROW WITH THE REGISTRY, and the failure mode when it does not is loud rather than
    # subtle: Get-SharedScriptPairs throws on a pair naming a plugin the marketplace does not declare,
    # which kills the gate mid-run and fails a dozen unrelated scenarios. Measured when workflow-default
    # was added and this list was not. Loud is the design -- a silently dropped pair would be worse --
    # but it means adding a plugin means adding it here too.
    New-Item -ItemType Directory -Path (Join-Path $Fixture '.claude-plugin') -Force | Out-Null
    # THE WORKFLOW FOLDER, since issue #998 (August 27, 2026). This fixture publishes
    # dkj-policy, so it IS this workflow's source -- and #998 retired the source branch from
    # Get-DefaultChangelogPath, so its changelog resolves to dkj-policy/CHANGELOG.md like
    # every other repo's. The three suites that write a changelog into this fixture write it there.
    New-Item -ItemType Directory -Path (Join-Path $Fixture 'dkj-policy') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-alpha\.claude-plugin') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-shopify\.claude-plugin') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Fixture 'plugins\dkj-policy\.claude-plugin') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $Fixture '.claude-plugin\marketplace.json'), (@'
{
  "name": "fixture-marketplace",
  "plugins": [
    { "name": "dkj-subagents-alpha",         "source": "./plugins/dkj-subagents/dkj-subagents-alpha" },
    { "name": "dkj-subagents-shopify",       "source": "./plugins/dkj-subagents/dkj-subagents-shopify" },
    { "name": "dkj-policy", "source": "./plugins/dkj-policy" }
  ]
}
'@), $Utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-alpha\.claude-plugin\plugin.json'),
        "{ `"name`": `"dkj-subagents-alpha`", `"version`": `"0.0.1`" }`n", $Utf8NoBom)
    # dkj-subagents-shopify joined the registry on August 20, 2026 with adopt-shopify-floor and its copy of the
    # source-repo guard lib. It is here for exactly the reason the paragraph above gives, and it cost
    # 22 unrelated failures across this suite's siblings before the list grew with it -- the second
    # measured instance of that same failure, after workflow-default.
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-shopify\.claude-plugin\plugin.json'),
        "{ `"name`": `"dkj-subagents-shopify`", `"version`": `"0.0.1`" }`n", $Utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'plugins\dkj-policy\.claude-plugin\plugin.json'),
        "{ `"name`": `"dkj-policy`", `"version`": `"0.0.1`" }`n", $Utf8NoBom)

    Copy-Item -Path $IntegritySrc -Destination (Join-Path $Fixture 'scripts\lint\check-plugin-integrity.ps1') -Force
    Copy-Item -Path $AgentSharedLibSrc -Destination (Join-Path $Fixture 'scripts\lib\subagent-shared-lib.ps1') -Force
    Copy-Item -Path $SharedScriptsLibSrc -Destination (Join-Path $Fixture 'scripts\lib\shared-scripts-lib.ps1') -Force
    Copy-Item -Path $CheckReportLibSrc -Destination (Join-Path $Fixture 'scripts\lib\check-report-lib.ps1') -Force
    Copy-Item -Path $ReleaseLibSrc -Destination (Join-Path $Fixture 'scripts\lib\release-lib.ps1') -Force
    Copy-Item -Path $BranchInfoSrc -Destination (Join-Path $Fixture 'scripts\lib\branch-info.ps1') -Force
    Copy-Item -Path $EntryScaffoldSrc -Destination (Join-Path $Fixture 'scripts\lib\entry-scaffold-lib.ps1') -Force
    # AND ITS OWN SIBLING WITH IT (#1650). entry-scaffold-lib.ps1 dot-sources ref-print-lib.ps1 from
    # $PSScriptRoot, so a fixture that copies the one and not the other hands the lint gate a lib that
    # THROWS ON LOAD -- and the failure is loud rather than subtle: 85 of this suite's asserts went red at
    # once, because the script died before it could report a single finding. That loudness is the reason
    # the dot-source is unconditional rather than guarded: a fixture forgetting it fails immediately
    # instead of silently dropping the control-character strip the lib loads it for.
    Copy-Item -Path $RefPrintLibSrc -Destination (Join-Path $Fixture 'scripts\lib\ref-print-lib.ps1') -Force
    Copy-Item -Path $PluginTreeSrc -Destination (Join-Path $Fixture 'scripts\lib\plugin-tree-lib.ps1') -Force
    Copy-Item -Path $PrBodyLibSrc -Destination (Join-Path $Fixture 'scripts\lib\pr-body-lib.ps1') -Force
    Copy-Item -Path $MeasureContextSrc -Destination (Join-Path $Fixture 'scripts\lib\measure-context-lib.ps1') -Force
    Copy-Item -Path $SeamLibSrc -Destination (Join-Path $Fixture 'scripts\lib\seam-lib.ps1') -Force
    # command-probe-lib.ps1 is a sibling of a sibling (#1729): the three libs above dot-source it for
    # Test-FunctionDefined, so the fixture owes it exactly as it owes ref-print-lib.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\command-probe-lib.ps1') -Destination (Join-Path $Fixture 'scripts\lib\command-probe-lib.ps1') -Force
    # repo-root-lib.ps1 likewise (#2115): check-report-lib.ps1 resolves the repo root through
    # Get-GitTopLevelPath, which lives there. UNGUARDED in that lib, deliberately -- it is mirrored
    # beside it into every plugin that carries it, so a payload missing it is broken rather than old.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\repo-root-lib.ps1') -Destination (Join-Path $Fixture 'scripts\lib\repo-root-lib.ps1') -Force
    # document-newline-lib.ps1 likewise (#1832): entry-scaffold-lib.ps1 and pr-body-lib.ps1 dot-source it
    # for Get-DocumentNewline, unconditionally and for the same reason -- so the fixture owes it too.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\document-newline-lib.ps1') -Destination (Join-Path $Fixture 'scripts\lib\document-newline-lib.ps1') -Force
    # fetch-attempt-lib.ps1 likewise (#1860): entry-scaffold-lib.ps1 dot-sources it for
    # Invoke-RecordedRemoteFetch, which Get-TrunkGap's fetch runs through -- so the fixture owes it too.
    # THE #1650 FAILURE ABOVE, REPRODUCED EXACTLY when this line was missing: 4 of this suite's siblings
    # went red at once and every one of their "is reported" asserts failed, because the gate died on load
    # before printing a single finding. fixture-lib-deps.tests.ps1 (#1693) is the gate for this class and
    # did not catch it -- it walks *.tests.ps1, and this shared builder is not one.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\fetch-attempt-lib.ps1') -Destination (Join-Path $Fixture 'scripts\lib\fetch-attempt-lib.ps1') -Force

    # The reference PR template check 24 holds, written from the same function the check compares against
    # -- never typed out here, for the reason stated at the dot-source above.
    New-Item -ItemType Directory -Path (Join-Path $Fixture 'plugins\dkj-policy\templates') -Force | Out-Null
    [System.IO.File]::WriteAllText(
        (Join-Path $Fixture 'plugins\dkj-policy\templates\pull_request_template.md'),
        (((Get-PrTemplateReference) -join "`n") + "`n"), $Utf8NoBom)

    $skillAlphaMd = "---`nname: skill-alpha`ndescription: Fixture skill alpha.`n---`n`n# Skill Alpha`n"
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-alpha\skills\skill-alpha\SKILL.md'), $skillAlphaMd, $Utf8NoBom)
    # SKILL-BETA IS THE BARRED ONE (check 33), and skill-alpha above deliberately is not. That pair is
    # the whole fixture check 33 needs: the same sentence about the two must come out differently, which
    # is what makes the rule frontmatter-driven rather than a phrasing convention. Adding the line here
    # rather than in a fifth fixture skill keeps the canonical set at two, which check 10's scenarios
    # count on.
    $skillBetaMd = "---`nname: skill-beta`ndescription: Fixture skill beta.`ndisable-model-invocation: true`n---`n`n# Skill Beta`n"
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-alpha\skills\skill-beta\SKILL.md'), $skillBetaMd, $Utf8NoBom)
    # The depth decoy claims its own name (skill-deep-decoy) in frontmatter -- if check 10 ever
    # regressed to a looser depth match, that name would silently become a 3rd canonical skill.
    $skillDeepDecoyMd = "---`nname: skill-deep-decoy`ndescription: Depth decoy -- must not count as a canonical skill.`n---`n`n# Skill Deep Decoy`n"
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-alpha\skills\skill-alpha\references\SKILL.md'), $skillDeepDecoyMd, $Utf8NoBom)
}

# The closing summary, identical in all four suites: one place, so four files cannot drift on how
# they report a failure.
function Complete-IntegritySuite {
    # ABOVE THE VERDICT AND EVEN ON A GREEN RUN (issues #1934 and #1954): a scenario whose child died
    # on load measured a fixture rather than the gate, and a case that only checks something is ABSENT
    # passes while proving nothing. So the count decides the exit code here too, ahead of the asserts.
    $loadBroken = Write-FixtureScriptSummary -Subject 'check-plugin-integrity.ps1'
    if ($loadBroken) {
        Write-Host "FAILED: $(Get-FixtureScriptLoadFailureCount) child gate run(s) died on load -- this run measured a fixture, not the gate." -ForegroundColor Red
        exit 1
    }
    Write-Host ""
    if ($script:fail -gt 0) {
        Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
        exit 1
    }
    Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
    exit 0
}
