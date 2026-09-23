<#
.SYNOPSIS
    check-plugin-integrity.ps1, the scan set: check 4 (the dead-link scan set) and check 28 (the
    '@'-import targets), which read the same set of files and answer the same question about two
    syntaxes.

.DESCRIPTION
    The fixture, the assert helpers and Invoke-Integrity live in check-plugin-integrity-fixture.ps1,
    which also records why this suite family is more than one file. The scenario documentation that used
    to open the single file is kept where each scenario is, rather than as one index several files would
    have to share.

    This file used to carry checks 10, 29, 30 and 32 as well, and at 539.2s on CI it became the gate's
    critical path once -docs had been split (#2304). Those four now live in -skill-spans, -plugin-spans
    and -plugin-links. Checks 4 and 28 stay together because scenario 23 asserts the one's coverage
    count against the other's, and that assert only means something inside one run.

    Check 4 guards file-set COVERAGE rather than the scan engine: if the $linkFiles list is refactored
    and drops CONTRIBUTING.md, the connectors README or one of the four payload layers, that must fail
    loudly here.

    Check 28 is check 4's sibling -- the same scan set, a different syntax -- and its scenarios pin the
    resolution rule (file-relative, NOT repo-root-relative) separately from both discriminators (a fenced
    '@(...)' and a prose line), because each can fail invisibly in the others' direction. One assert
    compares its coverage count against check 4's, so the two sets cannot silently drift apart.

    Test gap (honest, inherited from the single file): the anchor-slug logic and the full scan engine
    are not re-exercised here -- they are covered by the repo-wide lint smoke checks in
    subagent-shared.tests.ps1 and bootstrap-drift.tests.ps1.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'check-plugin-integrity-fixture.ps1')

$Fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("check-plugin-integrity-links-$PID-$([guid]::NewGuid().ToString('n'))")

try {
    New-IntegrityFixture -Fixture $Fixture

    # --- Scenario A: dead links in the two target files + a decoy outside the scan set --------------
    Write-Host "check 4 coverage -- CONTRIBUTING.md + connectors README are IN the scan set" -ForegroundColor Cyan
    $contributingBroken = "# Contributing`n`nSee [nope]($deadLink) for details.`n"
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), $contributingBroken, $Utf8NoBom)
    $connectorsBroken = "# Connectors`n`nSee [nope]($deadLink) for details.`n"
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'connectors\README.md'), $connectorsBroken, $Utf8NoBom)
    # Decoy: same dead link, but in a file that check 4 does NOT scan -- proves the two hits below
    # are due to CONTRIBUTING.md / the connectors README specifically being in the file list, not
    # some accidental blanket scan of every .md file in the fixture.
    #
    # IT MOVED OUT OF THE ROOT IN #405, AND THAT IS THE POINT IT NOW PROVES. This decoy used to sit at
    # 'NOTES.md' in the fixture root, back when the root docs were a NAMED list and the *.md glob covered
    # the separate family directory that held QUICKSTART.md, UNINSTALL.md and the family README. Flattening
    # moved those three documents INTO the root, so the root became the directory where consumer-facing
    # pages live and inherited the glob (see scenario 33, which requires exactly that). A root decoy would
    # now be testing that the glob does not work.
    #
    # So the decoy moved one directory down instead of being deleted: the property under test -- the scan
    # is scope-limited rather than a blanket walk of every .md in the tree -- is unchanged and still worth
    # asserting. Only the boundary moved, from "which root files are named" to "the root, and not below it".
    $decoyBroken = "# Decoy`n`nSee [nope]($deadLink) for details.`n"
    New-Item -ItemType Directory -Path (Join-Path $Fixture 'notes') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'notes\NOTES.md'), $decoyBroken, $Utf8NoBom)

    $a = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 $a.Code 'scenario A: exit 1 (findings present)'
    Assert-True ($a.Out -match [regex]::Escape('.\CONTRIBUTING.md') -and $a.Out -match '\[link\]') 'CONTRIBUTING.md dead link is reported'
    Assert-True ($a.Out -match [regex]::Escape('.\connectors\README.md')) 'connectors README dead link is reported'
    Assert-True (-not ($a.Out -match [regex]::Escape('NOTES.md'))) 'decoy notes\NOTES.md (outside the scan set) is NOT reported -- proves the scan is scope-limited, not a blanket walk'

    # --- Scenario B: fix both dead links -- the two specific findings disappear ----------------------
    Write-Host "check 4 coverage -- fixing the dead links removes exactly those findings" -ForegroundColor Cyan
    $contributingFixed = "# Contributing`n`nNothing to link to here.`n"
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), $contributingFixed, $Utf8NoBom)
    $connectorsFixed = "# Connectors`n`nNothing to link to here.`n"
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'connectors\README.md'), $connectorsFixed, $Utf8NoBom)

    $b = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($b.Out -match [regex]::Escape('.\CONTRIBUTING.md') + '.*dead link')) 'CONTRIBUTING.md dead-link finding is gone once fixed'
    Assert-True (-not ($b.Out -match [regex]::Escape('.\connectors\README.md') + '.*dead link')) 'connectors README dead-link finding is gone once fixed'

    # --- Scenario B2: the four payload layers added in #481 are IN the scan set ---------------------
    # Agent defs, subagent-shared, .github and .claude/rules matched no category until August 6, 2026 --
    # 40 files, the largest of them the agent defs, which are the biggest body of prose this repo ships.
    # A real dead link had been sitting in one of them, seen by nothing. Each layer gets its own broken
    # link here rather than one shared assertion, because they are four separate rules and a single
    # combined check would pass while three of them were absent.
    Write-Host "check 4 coverage -- the payload layers (#481) are IN the scan set" -ForegroundColor Cyan
    $payloadTargets = @(
        @{ Rel = 'plugins\dkj-subagents\dkj-subagents-alpha\subagents\09-99-agent.md';   Label = 'an agent def' },
        @{ Rel = 'plugins\dkj-subagents\subagent-shared\fixture-block.md';  Label = 'a shared agent-def block' },
        @{ Rel = '.github\pull_request_template.md';             Label = 'a .github template' },
        @{ Rel = '.claude\rules\fixture-rule.md';                Label = 'a path-scoped rule' }
    )
    foreach ($pt in $payloadTargets) {
        $ptFull = Join-Path $Fixture $pt.Rel
        New-Item -ItemType Directory -Path (Split-Path -Parent $ptFull) -Force | Out-Null
        [System.IO.File]::WriteAllText($ptFull, "# Fixture`n`nSee [nope]($deadLink) for details.`n", $Utf8NoBom)
    }
    $b2 = Invoke-Integrity -FixtureRoot $Fixture
    foreach ($pt in $payloadTargets) {
        Assert-True ($b2.Out -match [regex]::Escape('.\' + $pt.Rel)) `
            ("payload scan: a dead link in $($pt.Label) is reported -- " + $pt.Rel)
    }
    Assert-True (-not ($b2.Out -match [regex]::Escape('NOTES.md'))) `
        'payload scan: the out-of-scope decoy is STILL not reported -- the four new rules are scoped, not a blanket walk'

    # And removing them again clears exactly those findings, so the assertions above are bound to the
    # files rather than to some other error the fixture happens to produce.
    foreach ($pt in $payloadTargets) { Remove-Item -LiteralPath (Join-Path $Fixture $pt.Rel) -Force }
    $b3 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($b3.Out -match [regex]::Escape('09-99-agent.md'))) `
        'payload scan: removing the agent def clears its finding -- the report tracked the file, not the fixture'

    # --- Scenario B4: the entry's links resolve WHERE THE FOLD WRITES, not where the file sits --------
    # The branch document's DEPLOY section is pasted verbatim into the changelog, so its links have to work
    # THERE. Until the branch/ split the file sat beside the changelog in the root and that held by
    # construction; moving it one level down turned every link in an entry into a dead one, measured on the
    # first entry written after the move.
    #
    # THE BASE IS THE CHANGELOG'S DIRECTORY AND NOT THE REPO ROOT (issue #1041, August 28, 2026). Those were
    # the same value until CHANGELOG.md moved into contributing-davekjohn/ on August 27, and this scenario
    # asserted the root by name -- so it passed while the check demanded a form the fold then broke.
    #
    # BOTH NAMES ARE EXERCISED, because they land on opposite sides of the repair:
    #   * TODAY'S name sits IN the changelog's directory, so the correct link is the one that reads
    #     correctly in front of the author. This is the case the issue measured and the only one an author
    #     meets today.
    #   * A LEGACY name sits one level BELOW it, so the base still differs from where the file sits -- which
    #     is why the special case survives the repair rather than being dropped. A branch open since before
    #     the August 23 merge still carries one.
    # And the root form is asserted DEAD on the legacy file, which is the direction pin: a repair that
    # simply left $RepoRoot in place, or one that dropped the case altogether, fails one of the three.
    Write-Host "check 4 coverage -- an entry's links are judged where the text LANDS" -ForegroundColor Cyan
    $entryDirFx = Join-Path $Fixture 'dkj-policy\branch'
    New-Item -ItemType Directory -Path $entryDirFx -Force | Out-Null
    $entryFx    = Join-Path $entryDirFx 'branch-deployment.md'
    $progressFx = Join-Path $entryDirFx 'branch-cycle.md'
    $devFx      = Join-Path $Fixture 'dkj-policy\development.md'
    # 'connectors/README.md' exists in this fixture. From dkj-policy/ -- where this fixture's
    # CHANGELOG.md resolves to -- it is reached with one '../', and the bare root form is dead there.
    [System.IO.File]::WriteAllText($entryFx,
        "## Fixture entry`n`nSee [the connectors README](../connectors/README.md), [the root form](connectors/README.md) and [nope]($deadLink).`n", $Utf8NoBom)
    # Today's single document: the changelog sits in ITS directory, so the link reads exactly as written.
    [System.IO.File]::WriteAllText($devFx,
        "## Development: ``feat/fixture```n`n### DEPLOY: ``feat/fixture```n`nSee [the connectors README](../connectors/README.md).`n", $Utf8NoBom)
    # The step list never travels, so it keeps the ordinary nested convention: '../../' to reach the root.
    [System.IO.File]::WriteAllText($progressFx,
        "# Branch progress`n`n**Branch:** ``feat/fixture```n`n## Steps`n`n- [ ] see [the connectors README](../../connectors/README.md)`n", $Utf8NoBom)

    $b4 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($b4.Out -match 'dead link ''\.\./connectors/README\.md''')) `
        'entry links: the link that reads correctly beside the changelog is NOT dead -- that is where the fold puts the text'
    Assert-True (-not ($b4.Out -match [regex]::Escape('.\dkj-policy\development.md'))) `
        "entry links: today's document is judged from its own directory, because the changelog sits there too"
    Assert-True ($b4.Out -match 'dead link ''connectors/README\.md''') `
        'entry links: the ROOT form IS dead on the legacy name -- the base is the changelog, not the repo root'
    Assert-True ($b4.Out -match [regex]::Escape('.\dkj-policy\branch\branch-deployment.md') -and $b4.Out -match [regex]::Escape($deadLink)) `
        'entry links: a genuinely dead link in the entry IS still reported -- the rebase is not a way out of the check'
    Assert-True (-not ($b4.Out -match [regex]::Escape('.\dkj-policy\branch\branch-cycle.md'))) `
        'entry links: the step list keeps the ordinary nested convention -- it never travels, so ../../ is correct there'

    Remove-Item -LiteralPath $entryFx, $progressFx, $devFx -Force

    # --- Scenario B5: plugins/ is read WHOLE, and a file gathered twice is reported once -------------
    # Inbound #566. Every rule in the scan set names either a SHAPE of file (SKILL.md, *-manual.md,
    # */agents/*.md) or a PLACE it takes entirely (the root, branch/, releases/). A markdown file sitting at
    # plugin level matched neither, which is exactly where a plugin's own README.md lives -- the first page a
    # consumer reads. Five such files were in the tree, unread, when a sixth was added: a portable
    # contribution guide whose whole purpose is to be copied, and whose dead links would be copied with it.
    #
    # Both halves are asserted because each one alone is satisfiable by a wrong fix. Widening the glob
    # without deduping double-reports every file two rules now claim; deduping without widening leaves the
    # gap. And the decoy is asserted a third time: plugins/ being read whole must not become "every .md in
    # the tree", which is the property scenarios A and B2 already defend at their own boundaries.
    Write-Host "check 4 coverage -- a plugin-level document is IN the scan set, and counted once" -ForegroundColor Cyan
    $pluginDocTargets = @(
        @{ Rel = 'plugins\dkj-subagents\dkj-subagents-alpha\README.md';         Label = "a plugin's own README (plugin level, no shape rule matches it)" },
        @{ Rel = 'plugins\dkj-subagents\dkj-subagents-alpha\scripts\README.md'; Label = 'a README in a plugin subdirectory that no shape rule reaches' }
    )
    # The dedupe witness: an agent def is gathered by the */agents/*.md payload rule AND by the recursive
    # plugins/ glob. One dead link in it must produce exactly one [link] finding. Counted on LINES carrying
    # both the path and the [link] tag, because check 3 also names this file (no frontmatter) and a naive
    # match on the path alone would count that too.
    $dupWitnessRel = 'plugins\dkj-subagents\dkj-subagents-alpha\subagents\09-98-agent.md'
    foreach ($pd in @($pluginDocTargets.Rel + $dupWitnessRel)) {
        $pdFull = Join-Path $Fixture $pd
        New-Item -ItemType Directory -Path (Split-Path -Parent $pdFull) -Force | Out-Null
        [System.IO.File]::WriteAllText($pdFull, "# Fixture`n`nSee [nope]($deadLink) for details.`n", $Utf8NoBom)
    }
    $b5 = Invoke-Integrity -FixtureRoot $Fixture
    foreach ($pd in $pluginDocTargets) {
        Assert-True ($b5.Out -match [regex]::Escape('.\' + $pd.Rel)) `
            ("plugin-doc scan: a dead link in $($pd.Label) is reported -- " + $pd.Rel)
    }
    $dupHits = @(($b5.Out -split "`r?`n") | Where-Object { $_ -match [regex]::Escape($dupWitnessRel) -and $_ -match '\[link\]' })
    Assert-Equal 1 $dupHits.Count `
        'plugin-doc scan: a file gathered by two rules yields ONE dead-link finding -- the scan set is deduped, so widening a rule never double-reports'
    Assert-True (-not ($b5.Out -match [regex]::Escape('NOTES.md'))) `
        'plugin-doc scan: the out-of-scope decoy is STILL not reported -- plugins/ is read whole, the tree is not'

    # Removing them clears exactly those findings, so the assertions above are bound to these files rather
    # than to other noise this near-empty fixture produces.
    foreach ($pd in @($pluginDocTargets.Rel + $dupWitnessRel)) { Remove-Item -LiteralPath (Join-Path $Fixture $pd) -Force }
    Remove-Item -LiteralPath (Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-alpha\scripts') -Recurse -Force
    $b6 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($b6.Out -match [regex]::Escape('.\plugins\dkj-subagents\dkj-subagents-alpha\README.md'))) `
        "plugin-doc scan: removing the plugin README clears its finding -- the report tracked the file, not the fixture"


    # --- check 28: every '@'-import target resolves ----------------------------------------------------
    # 18-24. THE SIBLING OF CHECK 4, AND IT BELONGS IN THIS FILE FOR THAT REASON: it reads the same
    #        $linkFiles set and answers the same question about a different syntax. Issue #874.
    #
    #        What separates them is the COST OF BEING WRONG. A dead markdown link costs a reader one
    #        click; a dead '@'-import costs the session the WHOLE document, and nothing errors -- Claude
    #        Code drops an import it cannot resolve in silence, so the only symptom is a session behaving
    #        as if it had never read the layer that vanished. In this repo that layer is the safety rules
    #        or the roster.
    #
    #        The scenarios below pin the resolution rule and BOTH discriminators, because each of the
    #        three can fail on its own and each failure is invisible in the other two's direction: a
    #        check that resolved root-relative would pass every positive test in a root document and be
    #        wrong everywhere else, and a check without the discriminators would be born accusing correct
    #        files -- which is the shape this repo refuses on principle (see check 27's exemption note).
    Write-Host "check 28: '@'-import targets resolve" -ForegroundColor Cyan
    $impDir     = Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-alpha'
    $impProbe   = Join-Path $impDir 'import-probe.md'
    $impSibling = Join-Path $impDir 'import-sibling.md'
    [System.IO.File]::WriteAllText($impSibling, "# The sibling`n`nA target that exists.`n", $Utf8NoBom)

    # 18. A RESOLVING IMPORT IS SILENT, and the coverage line still reports a non-empty scan. Without the
    #     second half a check that examined nothing at all would pass this scenario.
    [System.IO.File]::WriteAllText($impProbe, "# The probe`n`n@import-sibling.md`n", $Utf8NoBom)
    $im1 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($im1.Out -match '\[import\].*import-probe')) `
        'import: a resolving import is not a finding'
    Assert-True ($im1.Out -match '\[import\] checked [1-9]') `
        'import: and the pass is not an empty scan'

    # 19. THE RESOLUTION RULE ITSELF, which is the one thing a second implementation would get wrong:
    #     an import resolves relative to the IMPORTING FILE's own directory, not to the repo root. The
    #     fixture root holds a CONTRIBUTING.md; this probe sits three levels down and must NOT find it.
    #     A root-relative reader passes scenario 18 and fails only here.
    [System.IO.File]::WriteAllText($impProbe, "# The probe`n`n@CONTRIBUTING.md`n", $Utf8NoBom)
    $im2 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($im2.Out -match '\[import\].*import-probe\.md:3') `
        'import: a target that exists at the REPO ROOT but not beside the importing file is dead -- the rule is file-relative'
    Assert-True ($im2.Code -ne 0) `
        'import: and it fails the gate -- a dropped import costs the session the whole document'
    Assert-True ($im2.Out -match 'importing file') `
        'import: and the finding states the base it resolved from, so the repair needs no source reading'

    # 20. A HOME-RELATIVE IMPORT IS COUNTED, NEVER REFUSED. SPECIALISTS.md imports the orchestrator's
    #     persona from the plugin marketplace clone under '~/', and CI is a machine with no clone. An
    #     error there would fail every PR for a correct file, so this assert is what keeps CI usable.
    [System.IO.File]::WriteAllText($impProbe,
        "# The probe`n`n@~/.claude/plugins/marketplaces/nothing-here/absent.md`n", $Utf8NoBom)
    $im3 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($im3.Out -match '\[import\].*import-probe')) `
        'import: a target outside the repo is not a finding -- CI has no marketplace clone'
    Assert-True ($im3.Out -match '1 outside the repo') `
        'import: but it is counted and named, so "no findings" does not mean "nothing was seen"'

    # 21. A FENCED '@(...)' IS POWERSHELL, NOT AN IMPORT. Seven of the twelve column-0 '@' lines in the
    #     real tree are exactly this, and check 4 already argues the case for links: illustrating a thing
    #     is not doing it.
    # Built from single-quoted parts and joined, so the fence delimiters are literal backticks rather
    # than an escape sequence three levels deep -- the readable form, and the one a later editor cannot
    # miscount.
    [System.IO.File]::WriteAllText($impProbe,
        ((@('# The probe', '', '```powershell', '@(Get-ChildItem .).Count', '```', '')) -join "`n"), $Utf8NoBom)
    $im4 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($im4.Out -match '\[import\].*import-probe')) `
        'import: a fenced PowerShell array expression is not an import'

    # 22. PROSE THAT WRAPS ONTO AN '@' IS NOT AN IMPORT EITHER, and this is the discriminator that keeps
    #     the check from being born with an exemption list. One line in the real tree needs it --
    #     releases/development/1.x/1.16.0.md, a paragraph that wraps onto '@-imported here (...)' -- and
    #     it sits in an archived note the language rule already exempts from repair. A target containing
    #     WHITESPACE is prose; the lib's parser takes the rest of the line, which is right for the
    #     always-on walk (it never meets prose) and wrong for a set that includes release history.
    [System.IO.File]::WriteAllText($impProbe,
        "# The probe`n`nA sentence that wraps onto`n@-imported here (which is prose, not a path).`n", $Utf8NoBom)
    $im5 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($im5.Out -match '\[import\].*import-probe')) `
        'import: a line beginning with @ whose target contains whitespace is prose, not an import'
    Assert-True ($im5.Out -match 'read as prose') `
        'import: and the coverage line says how many were read that way, so the discriminator is visible rather than silent'

    # 23. THE SET IS CHECK 4'S SET, asserted on the count rather than on a name. If $linkFiles is ever
    #     refactored and this check is left reading something narrower, the two numbers diverge and this
    #     fails -- which is the same coverage guard the rest of this file exists for.
    Assert-True ($im5.Out -match '\[import\] checked (\d+)') 'import: the coverage line reports a count'
    $impCount  = [int]([regex]::Match($im5.Out, '\[import\] checked (\d+)').Groups[1].Value)
    $linkCount = [int]([regex]::Match($im5.Out, '\[link-scan\] checked (\d+)').Groups[1].Value)
    Assert-True ($impCount -eq $linkCount) `
        'import: the scan set IS check 4 set -- a narrower one here would go unnoticed without this'

    # 24. And the fixture is clean again once the probe is gone, so nothing above leaks into a later run.
    Remove-Item -LiteralPath $impProbe -Force
    Remove-Item -LiteralPath $impSibling -Force
    Assert-True (-not ((Invoke-Integrity -FixtureRoot $Fixture).Out -match '\[import\] \.')) `
        'import: the fixture is clean again once the probes are gone'

} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Complete-IntegritySuite
