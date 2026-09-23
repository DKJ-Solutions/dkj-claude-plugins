<#
.SYNOPSIS
    check-plugin-integrity.ps1, the plugin-scoped spans: check 29 (the <!-- skills:plugin --> spans)
    and check 32 (the <!-- shared-scripts:mirror --> tables).

.DESCRIPTION
    The fixture, the assert helpers and Invoke-Integrity live in check-plugin-integrity-fixture.ps1,
    which also records why this suite family is more than one file. Split out of -links under #2304.

    Check 29 is check 10's plugin-scoped sibling (check 10 lives in -skill-spans): same scan set, same
    marker mechanics, one deliberate difference each. The two that matter are asserted head-on -- the
    SCOPE (27, which manufactures a third skill in a second plugin so the two canonical sets genuinely
    differ) and the LINK-versus-BACKTICK reading (28). Without the manufactured skill the fixture's two
    sets coincide and the scope assertion is vacuous, which is the failure mode this suite exists to
    prevent.

    Check 32 is the THIRD opt-in span, and since #1491 all three run one walk -- Invoke-MarkedSpanWalk.
    Its eight scenarios therefore do not restage the marker mechanics checks 10 and 29 already prove;
    they cover what is its own, and two of them exist because an implementation that got them wrong
    would pass everything else here: 45 (the claim is the row's FIRST CELL, not every backtick and not a
    link) and 48 (the scope is the marked document's OWN FOLDER, not its plugin). Its expected set is
    DERIVED from Get-SharedScriptPairs rather than typed, so a newly shared script does not turn this
    suite red for having found nothing -- and 42 asserts that derived set is non-empty, because
    comparing empty to empty is exactly how check 29 came out green for the wrong reason while #1491 was
    being built.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'check-plugin-integrity-fixture.ps1')

$Fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("check-plugin-integrity-plugin-spans-$PID-$([guid]::NewGuid().ToString('n'))")

try {
    New-IntegrityFixture -Fixture $Fixture
    # The root documents as check 4's scenario B leaves them -- see Write-QuietRootDocuments for why this
    # suite states that starting point instead of inheriting it from a scenario in another file.
    Write-QuietRootDocuments -Fixture $Fixture

    # === check 29: a plugin's OWN skill enumeration, scoped and read from its links =====================
    # 25-35. CHECK 10'S SIBLING, NOW IN A SUITE BESIDE IT RATHER THAN IN THE SAME FILE (#2304 split them
    #        on cost; check 10 is in -skill-spans). The two checks share the scan set, the fence masking
    #        and the whole marker mechanic, and they differ in exactly two respects (#920). Both differences are asserted head-on -- the SCOPE in 27 and the
    #        LINK-versus-BACKTICK reading in 28 -- because each is satisfiable by an implementation that
    #        gets the other wrong. A plugin-scoped check that quietly used the marketplace-wide canonical
    #        set passes every other scenario here, which is precisely why 27 manufactures a third skill in
    #        a SECOND plugin: without it the fixture's two sets coincide and the scope assertion is
    #        vacuous.
    #
    #        The document under test is the plugin's own README rather than CONTRIBUTING.md, and that is
    #        not incidental: this marker resolves its plugin from the FILE'S OWN PATH, so a root document
    #        cannot carry a valid one at all -- which is scenario 31.
    $PluginSkillFindingPattern = '\[skill-list-plugin\].*(links to none for:|ship no SKILL\.md there:|has no matching|sits INSIDE|belongs to no published plugin)'
    $pluginReadme = Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-alpha\README.md'

    # --- Scenario 25: a complete plugin-scoped span passes, and the coverage line proves it read the
    # links rather than merely finding the markers ---------------------------------------------------
    Write-Host "check 29 -- a complete <!-- skills:plugin --> span passes" -ForegroundColor Cyan
    $p25Lines = @(
        '# dkj-subagents-alpha'
        ''
        '<!-- skills:plugin -->'
        ''
        '| skill | when |'
        '|---|---|'
        '| [`skill-alpha`](skills/skill-alpha/SKILL.md) | the first one |'
        '| [`skill-beta`](skills/skill-beta/SKILL.md) | the second one |'
        ''
        '<!-- /skills:plugin -->'
    )
    [System.IO.File]::WriteAllText($pluginReadme, (($p25Lines -join "`n") + "`n"), $Utf8NoBom)

    $q25 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($q25.Out -match $PluginSkillFindingPattern)) 'scenario 25: a complete plugin-scoped span reports no [skill-list-plugin] finding'
    Assert-True ($q25.Out -match [regex]::Escape('[skill-list-plugin] checked 1')) 'scenario 25: exactly one span was counted'
    Assert-True ($q25.Out -match [regex]::Escape('with 2 claim(s) read from LINK TARGETS')) 'scenario 25: both rows were read as claims -- the coverage line proves the links were parsed, not just the markers found'

    # --- Scenario 26: a span that omits one of the plugin's skills fails, naming it ------------------
    Write-Host "check 29 -- a span omitting one of the plugin's skills fails" -ForegroundColor Cyan
    $p26Lines = @(
        '# dkj-subagents-alpha'
        ''
        '<!-- skills:plugin -->'
        '| [`skill-alpha`](skills/skill-alpha/SKILL.md) | the only row |'
        '<!-- /skills:plugin -->'
    )
    [System.IO.File]::WriteAllText($pluginReadme, (($p26Lines -join "`n") + "`n"), $Utf8NoBom)

    $q26 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($q26.Out -match [regex]::Escape("links to none for: skill-beta")) 'scenario 26: the omitted skill is named -- this is the drift the check exists to stop'
    Assert-Equal 1 $q26.Code 'scenario 26: and it fails the gate'

    # --- Scenario 27 (the SCOPE difference, and the reason this check exists at all): the canonical set
    # is THIS plugin's, not the marketplace's. A third skill is manufactured in a SECOND plugin, so the
    # two sets differ -- 3 marketplace-wide against 2 for dkj-subagents-alpha -- and both are asserted in the same
    # run: check 10's span sees 3, check 29's span passes with 2. Under the marketplace-wide set this
    # span would report skill-gamma missing, which is exactly what #920 measured and why a second marker
    # was needed rather than a wider check 10 ----------------------------------------------------------
    Write-Host "check 29 -- the canonical set is the DOCUMENT'S OWN plugin, not the marketplace" -ForegroundColor Cyan
    $gammaDir = Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-shopify\skills\skill-gamma'
    New-Item -ItemType Directory -Path $gammaDir -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $gammaDir 'SKILL.md'), "---`nname: skill-gamma`n---`n`n# Gamma`n", $Utf8NoBom)
    [System.IO.File]::WriteAllText($pluginReadme, (($p25Lines -join "`n") + "`n"), $Utf8NoBom)
    $s27Lines = @(
        '# Contributing'
        ''
        '<!-- skills:all -->'
        '- `skill-alpha`'
        '- `skill-beta`'
        '- `skill-gamma`'
        '<!-- /skills:all -->'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s27Lines -join "`n") + "`n"), $Utf8NoBom)

    $q27 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($q27.Out -match [regex]::Escape('against 3 canonical skill(s)')) 'scenario 27: the marketplace-wide set really is 3 -- so the two sets genuinely differ in this run'
    Assert-True (-not ($q27.Out -match $PluginSkillFindingPattern)) 'scenario 27: and the plugin-scoped span still passes with 2 -- skill-gamma belongs to another plugin and is not its business'
    Assert-True ($q27.Out -match [regex]::Escape('with 2 claim(s) read from LINK TARGETS')) 'scenario 27: two claims, not three -- the scope is the document own plugin'

    Remove-Item -LiteralPath (Split-Path -Parent $gammaDir) -Recurse -Force
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), "# Contributing`n`nNo markers here.`n", $Utf8NoBom)

    # --- Scenario 28 (the OTHER difference): a claim is a LINK TARGET, never a backtick. This is the
    # constraint that made check 10 unusable for a two-column table -- three rows of the real one carry a
    # backticked path or flag in their second column, and under check 10's rule each of those is a claimed
    # skill name. Here they are prose. A backticked name that is NOT a link is asserted too, in the same
    # span, because "ignores backticks" and "reads links" can each be implemented without the other -----
    Write-Host "check 29 -- prose and backticked paths in a row are not claims; the link is" -ForegroundColor Cyan
    $p28Lines = @(
        '# dkj-subagents-alpha'
        ''
        '<!-- skills:plugin -->'
        '| skill | when |'
        '|---|---|'
        '| [`skill-alpha`](skills/skill-alpha/SKILL.md) | scaffolds `dkj-policy/`, and takes `--force` |'
        '| [`skill-beta`](skills/skill-beta/SKILL.md) | stays out of the built-in `/continue` way |'
        '| `not-a-skill` | a backticked token with no link at all -- prose, not a claim |'
        '<!-- /skills:plugin -->'
    )
    [System.IO.File]::WriteAllText($pluginReadme, (($p28Lines -join "`n") + "`n"), $Utf8NoBom)

    $q28 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($q28.Out -match $PluginSkillFindingPattern)) 'scenario 28: backticked paths, flags and a bare backticked token inside the span cost nothing -- no author condition is needed'
    Assert-True ($q28.Out -match [regex]::Escape('with 2 claim(s) read from LINK TARGETS')) 'scenario 28: still exactly 2 claims -- the three extra backtick runs were not read as names'

    # --- Scenario 29: a link into this plugin's skills/ for a name that ships no SKILL.md ------------
    # The mirror of 26, and the case a renamed skill folder produces. Check 4 reports the dead link too;
    # this asserts the [skill-list-plugin] half, which is the one that says WHY it matters.
    Write-Host "check 29 -- a link to a skill this plugin does not ship is reported" -ForegroundColor Cyan
    $p29Lines = @(
        '# dkj-subagents-alpha'
        ''
        '<!-- skills:plugin -->'
        '| [`skill-alpha`](skills/skill-alpha/SKILL.md) | real |'
        '| [`skill-beta`](skills/skill-beta/SKILL.md) | real |'
        '| [`skill-ghost`](skills/skill-ghost/SKILL.md) | renamed away, or never there |'
        '<!-- /skills:plugin -->'
    )
    [System.IO.File]::WriteAllText($pluginReadme, (($p29Lines -join "`n") + "`n"), $Utf8NoBom)

    $q29 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($q29.Out -match [regex]::Escape('ship no SKILL.md there: skill-ghost')) 'scenario 29: the phantom row is named'
    Assert-Equal 1 $q29.Code 'scenario 29: and it fails the gate'

    # --- Scenario 30: the DEPTH DECOY, on the claim side this time. Check 10 binds its canonical walk to
    # exactly one segment between skills/ and SKILL.md; the same binding has to hold for a LINK, or a
    # level-3 progressive-disclosure page would be read as a claimed skill and reported as an extra ----
    Write-Host "check 29 -- a link to a level-3 SKILL.md is not a claim" -ForegroundColor Cyan
    $p30Lines = @(
        '# dkj-subagents-alpha'
        ''
        '<!-- skills:plugin -->'
        '| [`skill-alpha`](skills/skill-alpha/SKILL.md) | real |'
        '| [`skill-beta`](skills/skill-beta/SKILL.md) | real |'
        '| deeper reading | [the reference page](skills/skill-alpha/references/SKILL.md) |'
        '<!-- /skills:plugin -->'
    )
    [System.IO.File]::WriteAllText($pluginReadme, (($p30Lines -join "`n") + "`n"), $Utf8NoBom)

    $q30 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($q30.Out -match $PluginSkillFindingPattern)) 'scenario 30: the level-3 page is not read as a claimed skill, so it is not an extra'
    Assert-True ($q30.Out -match [regex]::Escape('with 2 claim(s) read from LINK TARGETS')) 'scenario 30: and it did not inflate the claim count either'

    # --- Scenario 31: a span in a document that belongs to NO plugin is a hard error, not a silent skip.
    # The marker means "this plugin", and a root document has none -- so there is nothing to adjudicate
    # against, and the honest answer is to say so rather than to pass. The message points at check 10,
    # which is the marker the author almost certainly wanted ------------------------------------------
    Write-Host "check 29 -- a span outside any plugin is refused, and points at the right marker" -ForegroundColor Cyan
    [System.IO.File]::WriteAllText($pluginReadme, "# dkj-subagents-alpha`n`nNo markers here.`n", $Utf8NoBom)
    $s31Lines = @(
        '# Contributing'
        ''
        '<!-- skills:plugin -->'
        '- [`skill-alpha`](plugins/dkj-subagents/dkj-subagents-alpha/skills/skill-alpha/SKILL.md)'
        '<!-- /skills:plugin -->'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s31Lines -join "`n") + "`n"), $Utf8NoBom)

    $q31 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($q31.Out -match [regex]::Escape('belongs to no published plugin')) 'scenario 31: a span in a root document is refused rather than silently skipped'
    Assert-True ($q31.Out -match [regex]::Escape('<!-- skills:all --> (check 10) instead')) 'scenario 31: and the finding names the marker that WOULD serve there'
    Assert-Equal 1 $q31.Code 'scenario 31: and it fails the gate'
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), "# Contributing`n`nNo markers here.`n", $Utf8NoBom)

    # --- Scenario 32: an unpaired BEGIN, reported with its line number -------------------------------
    Write-Host "check 29 -- an unpaired BEGIN is reported" -ForegroundColor Cyan
    $p32Lines = @(
        '# dkj-subagents-alpha'                                    # line 1
        ''                                                # line 2
        '<!-- skills:plugin -->'                          # line 3
        '| [`skill-alpha`](skills/skill-alpha/SKILL.md) | no closer follows |'
    )
    [System.IO.File]::WriteAllText($pluginReadme, (($p32Lines -join "`n") + "`n"), $Utf8NoBom)

    $q32 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($q32.Out -match [regex]::Escape("'<!-- skills:plugin -->' at line 3 has no matching '<!-- /skills:plugin -->'")) 'scenario 32: the unpaired BEGIN is reported, with the correct line number'
    Assert-Equal 1 $q32.Code 'scenario 32: a typo-ed sentinel must never read as "no span here"'

    # --- Scenario 33: a lone orphan END, the symmetric half ------------------------------------------
    Write-Host "check 29 -- a lone orphan END is reported" -ForegroundColor Cyan
    $p33Lines = @(
        '# dkj-subagents-alpha'                                    # line 1
        ''                                                # line 2
        '<!-- /skills:plugin -->'                         # line 3
    )
    [System.IO.File]::WriteAllText($pluginReadme, (($p33Lines -join "`n") + "`n"), $Utf8NoBom)

    $q33 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($q33.Out -match [regex]::Escape("'<!-- /skills:plugin -->' at line 3 has no matching '<!-- skills:plugin -->'")) 'scenario 33: the orphan END is reported, with the correct line number'

    # --- Scenario 34: a SECOND BEGIN inside an already-open span -- the mirror of check 10's scenario
    # 14b, shipped with it. This is the case that made the repair necessary: on this check's own branch
    # the marker was written in prose above the real span, the two paired across the whole table, and the
    # run came out GREEN with the real BEGIN swallowed. Both halves asserted, as in 14b -----------------
    Write-Host "check 29 -- a second BEGIN inside a real span is caught, not silently swallowed" -ForegroundColor Cyan
    $p34Lines = @(
        '# dkj-subagents-alpha'                                    # line 1
        ''                                                # line 2
        '<!-- skills:plugin -->'                          # line 3
        '| [`skill-alpha`](skills/skill-alpha/SKILL.md) | real |'
        '<!-- skills:plugin -->'                          # line 5 -- nested, opens nothing
        '| [`skill-beta`](skills/skill-beta/SKILL.md) | real |'
        '<!-- /skills:plugin -->'                         # line 7
    )
    [System.IO.File]::WriteAllText($pluginReadme, (($p34Lines -join "`n") + "`n"), $Utf8NoBom)

    $q34 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($q34.Out -match [regex]::Escape("'<!-- skills:plugin -->' at line 5 sits INSIDE an already-open span")) 'scenario 34: the nested second BEGIN is reported, with the correct line number'
    Assert-True (-not ($q34.Out -match [regex]::Escape('links to none for:'))) 'scenario 34: and the swallowed rows were still checked as one span -- no spurious missing name'
    Assert-True ($q34.Out -match [regex]::Escape('[skill-list-plugin] checked 1')) 'scenario 34: exactly one span, not two'

    # --- Scenario 35: a fenced example of the marker is invisible, and the fixture is clean again -----
    # The convention this check inherits from check 10: a fence is the supported way to SHOW the bare
    # marker text. Asserted on the span COUNT rather than on the absence of a finding, because zero
    # findings is also what a check that stopped reading the file would produce.
    Write-Host "check 29 -- a fenced example is not a live marker, and the fixture ends clean" -ForegroundColor Cyan
    $p35Lines = @(
        '# dkj-subagents-alpha'
        ''
        'Wrap the table like this:'
        ''
        '```'
        '<!-- skills:plugin -->'
        '<!-- /skills:plugin -->'
        '```'
    )
    [System.IO.File]::WriteAllText($pluginReadme, (($p35Lines -join "`n") + "`n"), $Utf8NoBom)

    $q35 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($q35.Out -match $PluginSkillFindingPattern)) 'scenario 35: a fenced example produces no finding'
    Assert-True ($q35.Out -match [regex]::Escape('[skill-list-plugin] checked 0')) 'scenario 35: the fenced markers never become a span at all -- invisible, not merely passing'

    Remove-Item -LiteralPath $pluginReadme -Force
    $q35b = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($q35b.Out -match '\[skill-list-plugin\] \.')) 'scenario 35: the fixture is clean again once the plugin README is gone'

    # === check 32: a mirror table's rows against the shared-scripts registry ============================
    # 42-49. WHY THESE SIT BESIDE CHECK 29 (issue #1491): the third opt-in span after checks 10 and 29,
    #        and since #1491 all three run the SAME walk -- Invoke-MarkedSpanWalk. The marker mechanics
    #        (fence masking, unpaired BEGIN, orphan END, nested BEGIN) are therefore proven once by
    #        check 10's and 29's scenarios and are not restaged here; 47 keeps one masking assert because
    #        it is the one mechanic this check reads DIFFERENTLY -- through table rows rather than through
    #        backticks or links.
    #
    #        THE EXPECTED SET IS DERIVED FROM THE REGISTRY, NOT TYPED. Get-SharedScriptPairs is the thing
    #        under test's own source of truth, so hardcoding two filenames here would turn every future
    #        `git`-shared script into a red suite that has found nothing. The tautology that invites is
    #        answered by 42's second assert: the derived set must be NON-EMPTY, so a registry that
    #        silently returned nothing cannot make every scenario below pass by comparing empty to empty
    #        -- which is exactly how check 29 came out green for the wrong reason while this branch was
    #        being written.
    #
    #        THE DOCUMENT SITS IN THE scripts/ FOLDER OF WHICHEVER PLUGIN THE REGISTRY FEEDS -- resolved
    #        below rather than named here -- and the folder is the point: this
    #        check scopes to the marked document's OWN directory rather than to its plugin. Scenario 48
    #        asserts that head-on by moving the same marker up to the plugin root, where the canonical set
    #        keeps the deeper 'scripts/' prefix -- the assertion that a plugin-scoped implementation
    #        (which would pass every other scenario here) fails.
    $MirrorFindingPattern = '\[shared-script-list\].*(has no row for:|does not mirror here:|has no matching|sits INSIDE|belongs to no published plugin)'
    # THE FOLDER IS DERIVED, NOT NAMED, and that is the whole lesson of the branch this arrived on.
    # It was written as a hardcoded 'plugins\teams\team-alpha\scripts', which passed locally and went red
    # on CI -- because CI tests the PR's MERGE commit, and the trunk had meanwhile renamed the tree to
    # plugins\dkj-subagents\dkj-subagents-alpha (#1480). The fixture's marketplace follows the real one, so the
    # canonical set landed somewhere the hardcoded docDir did not point, matched=0, and every scenario
    # below failed for a reason none of them was about. A test for a check whose entire subject is a
    # hand-maintained path list going stale must not itself carry a hand-maintained path.
    #
    # So: ask the registry which plugin actually receives mirrors, and put the document in ITS scripts/
    # folder. Any plugin with at least one mirror serves -- the scenarios below are about the mechanism,
    # not about which plugin it is -- and the smallest one is chosen deliberately, so the table stays
    # short and scenario 43's dropped row is easy to read in a finding.
    . (Join-Path $PSScriptRoot '..\lib\shared-scripts-lib.ps1')
    $mirrorAllPairs = @(Get-SharedScriptPairs -RepoRoot $Fixture -PluginRoots @(Get-RepoPluginRoots -RepoRoot $Fixture))
    $mirrorCountByPlugin = @{}
    foreach ($p in $mirrorAllPairs) {
        if (-not $mirrorCountByPlugin.ContainsKey($p.Plugin)) { $mirrorCountByPlugin[$p.Plugin] = 0 }
        $mirrorCountByPlugin[$p.Plugin]++
    }
    $mirrorHostRoot = @(Get-RepoPluginRoots -RepoRoot $Fixture |
        Where-Object { $mirrorCountByPlugin.ContainsKey($_.Name) } |
        Sort-Object { $mirrorCountByPlugin[$_.Name] })[0]
    if (-not $mirrorHostRoot) { throw 'check 32 scenarios: no published plugin in the fixture receives a registry mirror.' }
    $mirrorReadme = Join-Path (Join-Path $mirrorHostRoot.Root 'scripts') 'README.md'
    New-Item -ItemType Directory -Path (Split-Path -Parent $mirrorReadme) -Force | Out-Null

    # GetFullPath on BOTH sides, matching the check: the two paths arrive by different routes -- one from
    # a Get-ChildItem walk, one composed as Join-Path <root as written> <relative> -- and only agree while
    # the root is written canonically. Not the cause of the CI failure above (that was the rename), but a
    # real fragility the check carries and the reason its own comment says so. Sorted so the table below
    # is stable run to run.
    $mirrorDocDir = [System.IO.Path]::GetFullPath((Split-Path -Parent $mirrorReadme)).TrimEnd('\') + '\'
    $mirrorExpected = @(
        $mirrorAllPairs |
            Where-Object { [System.IO.Path]::GetFullPath($_.MirrorPath).StartsWith($mirrorDocDir, [System.StringComparison]::OrdinalIgnoreCase) } |
            ForEach-Object { [System.IO.Path]::GetFullPath($_.MirrorPath).Substring($mirrorDocDir.Length) -replace '\\', '/' } | Sort-Object)
    # PRINTED EVERY RUN, not only on failure: when this block went red in CI and green on three local
    # runs, the one thing the log could not tell me was which two paths had failed to match. A derived
    # set is an input to every scenario below, so it is reported like one.
    Write-Host "  [derived] docDir=$mirrorDocDir pairs=$($mirrorAllPairs.Count) matched=$($mirrorExpected.Count)" -ForegroundColor DarkGray
    if ($mirrorExpected.Count -eq 0 -and $mirrorAllPairs.Count -gt 0) {
      # Diagnostics only, and they must never be the reason a run dies: this branch exists precisely
      # when something is already not as expected, which is the worst moment to throw a second error
      # over the first one.
      try {
        foreach ($r in @(Get-RepoPluginRoots -RepoRoot $Fixture)) {
            Write-Host "  [derived] root name=$($r.Name) rel=$($r.RelativeRoot) root=$($r.Root)" -ForegroundColor DarkGray
        }
        foreach ($p in @($mirrorAllPairs | Where-Object { $_.Plugin -eq $mirrorHostRoot.Name })) {
            Write-Host "  [derived] host pair=$($p.Name) MirrorPath=$($p.MirrorPath)" -ForegroundColor DarkGray
        }
        Write-Host "  [derived] plugins on disk: $((Get-ChildItem -Path (Join-Path $Fixture 'plugins') -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path (Join-Path $_.FullName '.claude-plugin\plugin.json') } | ForEach-Object { $_.FullName.Substring($Fixture.Length) }) -join ' | ')" -ForegroundColor DarkGray
        Write-Host "  [derived] pairs by plugin: $((($mirrorAllPairs | Group-Object Plugin | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ' | '))" -ForegroundColor DarkGray
      } catch {
        Write-Host "  [derived] diagnostics threw: $($_.Exception.Message)" -ForegroundColor DarkGray
      }
    }

    function New-MirrorTable {
        # Builds the table body the way the real page writes it: a backticked path in the first cell,
        # running prose in the second, a link or the word 'none' in the third.
        param([string[]]$Rows)
        $out = @('| Script | What it is | Skill |', '|---|---|---|')
        foreach ($r in $Rows) { $out += "| ``$r`` | what it does | none -- dot-sourced lib |" }
        return $out
    }

    # --- Scenario 42: a table carrying every registered mirror passes, and the set is not empty --------
    Write-Host "check 32 -- a complete <!-- shared-scripts:mirror --> table passes" -ForegroundColor Cyan
    $p42Lines = @('# scripts', '', '<!-- shared-scripts:mirror -->') + (New-MirrorTable -Rows $mirrorExpected) + @('<!-- /shared-scripts:mirror -->')
    [System.IO.File]::WriteAllText($mirrorReadme, (($p42Lines -join "`n") + "`n"), $Utf8NoBom)

    $q42 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($q42.Out -match $MirrorFindingPattern)) 'scenario 42: a complete mirror table reports no [shared-script-list] finding'
    Assert-True ($mirrorExpected.Count -gt 0) 'scenario 42: the derived canonical set is NON-EMPTY -- without this every scenario below could pass by comparing empty to empty'
    Assert-True ($q42.Out -match [regex]::Escape('[shared-script-list] checked 1')) 'scenario 42: exactly one span was counted'
    Assert-True ($q42.Out -match [regex]::Escape(": $($mirrorExpected.Count) row(s) read from the first cell")) 'scenario 42: every row was read as a claim -- the coverage line proves the cells were parsed, not just the markers found'
    # The CANONICAL side, printed beside the claim side for the reason the check's own comment gives: a
    # claim count alone cannot tell 0-against-0 from 45-against-45, and both report "no findings".
    Assert-True ($q42.Out -match [regex]::Escape("against $($mirrorExpected.Count) registered mirror(s)")) 'scenario 42: and the registry side is reported too, so an empty-against-empty pass cannot read like a real one'

    # --- Scenario 43: THE RECURRENCE THIS CHECK EXISTS FOR. A registered script with no row is named.
    # Three hand passes (August 15, August 26, September 6 2026) repaired exactly this and reset the
    # clock; the finding below is what ends it ----------------------------------------------------------
    Write-Host "check 32 -- a registered mirror with no row is named" -ForegroundColor Cyan
    $mirrorDropped = $mirrorExpected[0]
    $p43Lines = @('# scripts', '', '<!-- shared-scripts:mirror -->') +
        (New-MirrorTable -Rows @($mirrorExpected | Where-Object { $_ -ne $mirrorDropped })) +
        @('<!-- /shared-scripts:mirror -->')
    [System.IO.File]::WriteAllText($mirrorReadme, (($p43Lines -join "`n") + "`n"), $Utf8NoBom)

    $q43 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($q43.Out -match [regex]::Escape("has no row for: $mirrorDropped")) 'scenario 43: the unlisted mirror is named -- this is the drift the check exists to stop'
    Assert-True ($q43.Out -match [regex]::Escape('Get-SharedScriptPairs')) 'scenario 43: and the finding names the registry to consult, so the repair needs no source reading'
    Assert-Equal 1 $q43.Code 'scenario 43: and it fails the gate'

    # --- Scenario 44: the other direction -- a row the registry does not mirror here. This is the half a
    # "count the rows" check could never catch, and the half that fires when a pair is RETIRED ----------
    Write-Host "check 32 -- a row for a script the registry does not mirror is reported" -ForegroundColor Cyan
    $p44Lines = @('# scripts', '', '<!-- shared-scripts:mirror -->') +
        (New-MirrorTable -Rows ($mirrorExpected + 'task/retired-long-ago.ps1')) +
        @('<!-- /shared-scripts:mirror -->')
    [System.IO.File]::WriteAllText($mirrorReadme, (($p44Lines -join "`n") + "`n"), $Utf8NoBom)

    $q44 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($q44.Out -match [regex]::Escape('does not mirror here: task/retired-long-ago.ps1')) 'scenario 44: the outlived row is named'
    Assert-Equal 1 $q44.Code 'scenario 44: and it fails the gate'

    # --- Scenario 45 (THE CLAIM RULE, and the one that separates this check from both siblings): only the
    # FIRST CELL is a claim. The real page's second column carries backticked flags and function names and
    # its third links a SKILL.md -- under check 10's every-backtick rule each would be a phantom row, and
    # under check 29's link rule the skill pages would be. Neither reading can serve this table ----------
    Write-Host "check 32 -- backticks and links elsewhere in a row are not claims; the first cell is" -ForegroundColor Cyan
    $p45Lines = @('# scripts', '', '<!-- shared-scripts:mirror -->', '| Script | What it is | Skill |', '|---|---|---|')
    foreach ($r in $mirrorExpected) {
        $p45Lines += "| ``$r`` | pass ``-Worker`` to ``Invoke-GitPark``, see ``CHANGELOG.md`` | [``park``](../skills/park/SKILL.md) |"
    }
    $p45Lines += '<!-- /shared-scripts:mirror -->'
    [System.IO.File]::WriteAllText($mirrorReadme, (($p45Lines -join "`n") + "`n"), $Utf8NoBom)

    $q45 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($q45.Out -match $MirrorFindingPattern)) 'scenario 45: backticked flags, function names and a SKILL.md link in the other cells cost nothing -- no author condition is needed'
    Assert-True ($q45.Out -match [regex]::Escape(": $($mirrorExpected.Count) row(s) read from the first cell")) 'scenario 45: still exactly one claim per row -- the four extra backtick runs per row were not read as names'

    # --- Scenario 46: a header row, a separator and running prose inside the span are passed over without
    # a rule of their own -- they simply carry no backticked first cell ----------------------------------
    Write-Host "check 32 -- a header, a separator and prose inside the span are not rows" -ForegroundColor Cyan
    $p46Lines = @('# scripts', '', '<!-- shared-scripts:mirror -->', 'Not every script here is reached through a skill.', '') +
        (New-MirrorTable -Rows $mirrorExpected) +
        @('', 'The registry is the only place that knows the answer.', '<!-- /shared-scripts:mirror -->')
    [System.IO.File]::WriteAllText($mirrorReadme, (($p46Lines -join "`n") + "`n"), $Utf8NoBom)

    $q46 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($q46.Out -match $MirrorFindingPattern)) 'scenario 46: the header, the separator and the surrounding prose produce no phantom rows'
    Assert-True ($q46.Out -match [regex]::Escape(": $($mirrorExpected.Count) row(s) read from the first cell")) 'scenario 46: and the claim count is unchanged by them'

    # --- Scenario 47: a FENCED example row is invisible, as in checks 10 and 29. Asserted on the
    # finding a masked row would produce rather than on the span count, because this check reads the mask
    # for its ROWS where check 10 reads it for its backticks -- the mechanic is shared, the reading is not
    Write-Host "check 32 -- a fenced example row is not a claim" -ForegroundColor Cyan
    $p47Lines = @('# scripts', '', '<!-- shared-scripts:mirror -->') + (New-MirrorTable -Rows $mirrorExpected) +
        @('', 'Add one like this:', '', '```', '| `task/not-a-real-mirror.ps1` | example | none |', '```', '', '<!-- /shared-scripts:mirror -->')
    [System.IO.File]::WriteAllText($mirrorReadme, (($p47Lines -join "`n") + "`n"), $Utf8NoBom)

    $q47 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($q47.Out -match [regex]::Escape('task/not-a-real-mirror.ps1'))) 'scenario 47: the fenced example row is masked, so it is not read as a phantom claim'
    Assert-True ($q47.Out -match [regex]::Escape(": $($mirrorExpected.Count) row(s) read from the first cell")) 'scenario 47: and the claim count is the real table alone'

    # --- Scenario 48 (THE SCOPE difference): the canonical set is the marked document's OWN FOLDER, not
    # its plugin. The same marker one level up, in the plugin root README, must expect the deeper
    # 'scripts/'-prefixed paths -- so the folder-relative table that passed in 42 now reports every one of
    # its rows twice over, missing and extra. A plugin-scoped implementation passes every scenario above
    # and fails only here, which is why this one is written ----------------------------------------------
    Write-Host "check 32 -- the scope is the marked document's OWN folder, not its plugin" -ForegroundColor Cyan
    Remove-Item -LiteralPath $mirrorReadme -Force
    $mirrorRootReadme = Join-Path $mirrorHostRoot.Root 'README.md'
    $p48Lines = @("# $($mirrorHostRoot.Name)", '', '<!-- shared-scripts:mirror -->') + (New-MirrorTable -Rows $mirrorExpected) + @('<!-- /shared-scripts:mirror -->')
    [System.IO.File]::WriteAllText($mirrorRootReadme, (($p48Lines -join "`n") + "`n"), $Utf8NoBom)

    $q48 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($q48.Out -match [regex]::Escape("has no row for: scripts/$($mirrorExpected[0])")) 'scenario 48: from the plugin root the canonical path keeps its scripts/ prefix -- the scope followed the document, not the plugin'
    Assert-True ($q48.Out -match [regex]::Escape("does not mirror here: $($mirrorExpected[0])")) 'scenario 48: and the folder-relative rows that passed one level down are now extras, for the same reason'

    # --- Scenario 49: a span in a document under no published plugin is refused rather than silently
    # skipped, exactly as check 29 refuses one (scenario 31) ---------------------------------------------
    Write-Host "check 32 -- a span outside any plugin is refused" -ForegroundColor Cyan
    Remove-Item -LiteralPath $mirrorRootReadme -Force
    $mirrorRootDoc = Join-Path $Fixture 'CONTRIBUTING.md'
    $mirrorRootDocOriginal = [System.IO.File]::ReadAllText($mirrorRootDoc, [System.Text.Encoding]::UTF8)
    $p49Lines = @('# Contributing', '', '<!-- shared-scripts:mirror -->', '| `task/whatever.ps1` | a row | none |', '<!-- /shared-scripts:mirror -->')
    [System.IO.File]::WriteAllText($mirrorRootDoc, (($p49Lines -join "`n") + "`n"), $Utf8NoBom)

    $q49 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($q49.Out -match [regex]::Escape('belongs to no published plugin')) 'scenario 49: a span in a root document is refused rather than silently skipped'
    Assert-Equal 1 $q49.Code 'scenario 49: and it fails the gate'

    [System.IO.File]::WriteAllText($mirrorRootDoc, $mirrorRootDocOriginal, $Utf8NoBom)
    $q49b = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($q49b.Out -match $MirrorFindingPattern)) 'scenario 49: the fixture is clean again once the span is gone'
    Assert-True ($q49b.Out -match [regex]::Escape('[shared-script-list] checked 0')) 'scenario 49: and zero spans is the opt-in pass, not a silent skip'

} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Complete-IntegritySuite
