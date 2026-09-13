<#
.SYNOPSIS
    check-plugin-integrity.ps1, part 4 of 4: the checks over what this repo SHIPS -- shared-script
    parameters against their skill (18), claimed section counts (20), the changelog intro (20b),
    machine-specific commands in skill pages (22), the PR template contract (24), consumer tier
    links (25), frontmatter byte-order marks (26), the manual/backer pairing (6b) -- and the
    -SkipCheck parameter itself.

.DESCRIPTION
    The fixture, the assert helpers and Invoke-Integrity live in check-plugin-integrity-fixture.ps1,
    which also records why this suite is four files.

    The -SkipCheck scenarios at the end are the guard on this suite family's own speed valve: a
    skipped check must announce itself and must never be reported as 'checked 0', an unknown name
    must be refused rather than ignored, and no gate that guards main may pass the parameter at all.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'check-plugin-integrity-fixture.ps1')

$Fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("check-plugin-integrity-docs-$PID-$([guid]::NewGuid().ToString('n'))")

# The entry format's levels, composed from the lib rather than typed -- the same rule the entries suite
# follows. Both pairs shifted one deeper on August 26, 2026, and a fixture stating them in literals is a
# second definition of the format that the check under test does not read.
#
# THE BACKTICK COMES FROM ITS CODE POINT, because it is PowerShell's own escape character: written literally
# inside a double-quoted string it escapes the next character instead of appearing.
$docTick      = [char]0x60
$docEntryHash = '#' * (Get-EntryHeadingLevel)
$docSectHash  = '#' * (Get-EntrySectionLevel)
$docEntryH    = $docTick + $docEntryHash + $docTick
$docSectH     = $docTick + $docSectHash + $docTick

try {
    New-IntegrityFixture -Fixture $Fixture

    # --- check 18: a shared script's parameters must appear in the skill that documents it ------------
    # THE MEASURED DEFECT, August 4, 2026: the fold-changelog skill told consumers to commit the fold BY
    # HAND for two days after the script gained -Commit/-Push, because that improvement went into this
    # repo's lens. Looking for siblings found four more, including cut-release's -Bump and -NoPush.
    #
    # park-branch is the fixture's subject: one parameter (-Intent), one skill (park), so the scenario
    # exercises the mapping rather than a script's complexity. Both directions are asserted, because a
    # positive-only test would pass against a check that examines nothing at all.
    Write-Host "check 18: shared-script parameters vs. their skill" -ForegroundColor Cyan
    $parkSrc   = Join-Path $Fixture 'scripts\task\park-branch.ps1'
    $parkSkill = Join-Path $Fixture 'plugins\dkj-policy\skills\park\SKILL.md'
    New-Item -ItemType Directory -Path (Split-Path -Parent $parkSrc) -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path -Parent $parkSkill) -Force | Out-Null
    # A real param block, so the AST reader is what is being exercised -- not a string the test planted.
    [System.IO.File]::WriteAllText($parkSrc, "param([string]`$Intent)`nWrite-Host 'fixture'`n", $Utf8NoBom)

    # 38. A skill that never names the parameter is reported, naming the script and the parameter.
    [System.IO.File]::WriteAllText($parkSkill, "# park`n`nParks the current branch. No options described.`n", $Utf8NoBom)
    $s1 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($s1.Out -match '\[skill-param\].*park-branch\.ps1.*-Intent') `
        'skill-param: an undocumented parameter is reported, naming both the script and the parameter'
    Assert-True ($s1.Out -match '\[skill-param\] checked [1-9]') `
        'skill-param: the coverage count proves a parameter was actually examined, not an empty scan'

    # 39. Documenting it in the skill -- and changing nothing else -- makes the same file pass.
    [System.IO.File]::WriteAllText($parkSkill, "# park`n`nParks the current branch. Use ``-Intent`` to record where you left off.`n", $Utf8NoBom)
    $s2 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($s2.Out -match '\[skill-param\].*park-branch\.ps1')) `
        'skill-param: naming the parameter in the skill alone clears the finding'

    # 40. (THE FIXTURE-QUIET GUARD) a registered script that does not exist in this tree is skipped
    #     rather than reported as a missing skill. Check 8 already reports the missing source, and
    #     duplicating that here would have made this check fire on every scenario above it -- which is
    #     exactly what the first version of it did.
    Assert-True (-not ($s2.Out -match '\[skill-param\].*cut-release\.ps1')) `
        'skill-param: a registered script absent from the tree is skipped, not reported (check 8 owns that finding)'

    # 41. The coverage line names what it could NOT cover, rather than reading as complete -- the
    #     no-silent-caps rule. A registered script declaring Skill = '' must be listed by name.
    #     check-script-contract is the subject because its '' is a deliberate "no procedure to write
    #     down" (it runs from a hook), so the fixture only needs it to EXIST to reach the gaps list.
    #     Note this had to be a script present in the tree: scenario 40's skip fires first otherwise,
    #     which is why asserting on ship-pr here failed -- the fixture has no ship-pr.ps1.
    $contractStub = Join-Path $Fixture 'scripts\sync\check-script-contract.ps1'
    New-Item -ItemType Directory -Path (Split-Path -Parent $contractStub) -Force | Out-Null
    [System.IO.File]::WriteAllText($contractStub, "Write-Host 'fixture'`n", $Utf8NoBom)
    $s3 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($s3.Out -match '\[skill-param\].*NOT covered.*check-script-contract') `
        'skill-param: the coverage line names an entry point that declares no skill'
    Assert-True (-not ($s3.Out -match '\[skill-param\] scripts\\sync\\check-script-contract')) `
        'skill-param: and declaring no skill is coverage, not an error -- writing a missing skill is separate work'

    # --- check 39: a depth-sensitive $PSScriptRoot resolution must declare the suite that runs it ---
    # ISSUE #1857. Check 8 holds a shared script byte-identical to its plugin mirror, and that is what
    # hides this: the two copies sit at different depths, so a resolution ascending TWO levels reaches
    # the repo root from one and the plugin root from the other. Identical characters, different
    # folder, nothing to diff -- and the mirror is the copy every consumer runs.
    #
    # park-branch.ps1 is the subject again, for the reason check 18 uses it: it is registered, it is
    # already in the fixture, and its skill is already satisfied above -- so the scenario exercises the
    # depth rule rather than a script's complexity. Its content is restored at the end of the block, so
    # the scenarios below see the fixture check 18 left behind.
    Write-Host "check 39: a depth-sensitive resolution vs. the suite that runs the mirror" -ForegroundColor Cyan
    $depthSrc  = $parkSrc
    $depthKeep = [System.IO.File]::ReadAllText($depthSrc)

    # 43a. ONE HOP IS NOT A SUBJECT. '..\lib\...' reaches the same folder relative to the file in both
    #      copies, so it cannot differ -- and a check that flagged it would bury the crossings that
    #      matter under every dot-source in the tree. Asserted first, because a check that fires on
    #      everything passes the positive test below while being useless.
    [System.IO.File]::WriteAllText($depthSrc,
        ($depthKeep + ". (Join-Path `$PSScriptRoot '..\lib\native-capture-lib.ps1')`n"), $Utf8NoBom)
    $d1 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($d1.Out -match '\[mirror-depth\].*park-branch')) `
        'mirror-depth: a single-hop resolution is not a finding -- it means the same folder in both copies'
    Assert-True ($d1.Out -match '\[mirror-depth\] checked [1-9]') `
        'mirror-depth: the coverage count proves scripts were actually scanned, not an empty pass'

    # 43b. TWO HOPS, UNDECLARED -- the defect itself.
    [System.IO.File]::WriteAllText($depthSrc,
        ($depthKeep + "`$ref = Join-Path `$PSScriptRoot '..\..\blueprint\thing.json'`n"), $Utf8NoBom)
    $d2 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($d2.Out -match '\[mirror-depth\].*park-branch\.ps1.*ascends two') `
        'mirror-depth: a two-hop resolution with no declaration is reported, naming the script'
    Assert-True ($d2.Out -match '\[mirror-depth\].*MirrorRun') `
        'mirror-depth: and the finding names the declaration that answers it, rather than only the symptom'

    # 43c. THE SECOND FORM, which a scan for '..' would miss entirely: the same ascent written as
    #      nested Split-Path calls. check-policy-drift resolves its sibling plugins exactly this way,
    #      and the detector's first draft found nothing there while reporting the literal form
    #      correctly -- it stopped climbing at the INNER pipeline, where one hop is in scope.
    [System.IO.File]::WriteAllText($depthSrc,
        ($depthKeep + "`$own = Split-Path (Split-Path `$PSScriptRoot -Parent) -Parent`n"), $Utf8NoBom)
    $d3 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($d3.Out -match '\[mirror-depth\].*park-branch\.ps1') `
        'mirror-depth: a nested Split-Path ascent is reported too, not only a literal ..\.. path'

    [System.IO.File]::WriteAllText($depthSrc, $depthKeep, $Utf8NoBom)
    $d4 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($d4.Out -match '\[mirror-depth\].*park-branch')) `
        'mirror-depth: removing the resolution clears the finding, so the check reads the script and not its name'

    # --- check 40: a plugin script may only load a lib its OWN plugin ships ------------------------
    # ISSUE #1925. Check 8 holds a registered mirror byte-identical to its source and check 39 holds a
    # depth-crossing resolution to a declared suite; between them sits the class where the text is
    # right, the folder is right, and the FILE IS NOT THERE. A lib registered for two plugins,
    # dot-sourced by a script that mirrors into a third, resolves inside that third plugin and finds
    # nothing -- four shopify scripts shipped exactly that way and the gate reported 0 error(s).
    #
    # THE SUBJECT IS A PLUGIN SCRIPT, so unlike checks 18 and 39 the fixture's own scripts\ cannot
    # serve: the defect only exists in the copy that lands somewhere without the lib. dkj-subagents-shopify is
    # the plugin, which is the measured instance's own plugin rather than a convenience.
    Write-Host "check 40: a plugin script's load vs. the plugin that carries it" -ForegroundColor Cyan
    $libDir  = Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-shopify\scripts\lib'
    $taskDir = Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-shopify\scripts\task'
    New-Item -ItemType Directory -Path $libDir -Force | Out-Null
    New-Item -ItemType Directory -Path $taskDir -Force | Out-Null
    $ownLib  = Join-Path $libDir 'own-lib.ps1'
    $plScript = Join-Path $taskDir 'plugin-native.ps1'
    [System.IO.File]::WriteAllText($ownLib, "function Get-FixtureThing { 'thing' }`n", $Utf8NoBom)

    # 44a. A LIB THE PLUGIN ACTUALLY SHIPS IS NOT A FINDING. Asserted first, because a check that fires
    #      on every dot-source would pass the positive case below while being unusable -- and there are
    #      154 such loads in the real tree.
    [System.IO.File]::WriteAllText($plScript,
        ". (Join-Path `$PSScriptRoot '..\lib\own-lib.ps1')`n", $Utf8NoBom)
    $p1 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($p1.Out -match '\[plugin-lib\].*plugin-native')) `
        'plugin-lib: a lib the plugin does ship is not a finding'
    Assert-True ($p1.Out -match '\[plugin-lib\] checked [1-9]') `
        'plugin-lib: the coverage count proves plugin scripts were read, not an empty pass'

    # 44b. THE MEASURED DEFECT: a lib this plugin does not have. The finding must name the script AND
    #      the expression, because the repair is choosing between registering a mirror and guarding the
    #      load, and neither is decidable from a file name alone.
    [System.IO.File]::WriteAllText($plScript,
        ". (Join-Path `$PSScriptRoot '..\lib\check-report-lib.ps1')`n", $Utf8NoBom)
    $p2 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($p2.Out -match '\[plugin-lib\].*plugin-native\.ps1.*check-report-lib\.ps1') `
        'plugin-lib: a load of a lib the plugin does not ship is reported, naming the script and the lib'
    Assert-True ($p2.Out -match '\[plugin-lib\].*ships no such file') `
        'plugin-lib: and the finding says what is wrong rather than only that something is'

    # 44c. A GUARDED LOAD IS NOT A FINDING, with the file just as absent as in 44b -- so this asserts
    #      the guard and not the file. That idiom is how this tree declares a seam that deliberately
    #      does not travel (release-lib's repo-owned branch-info sibling), and 70 real references use
    #      it; judging them would have arrived with an exemption list.
    [System.IO.File]::WriteAllText($plScript,
        ("`$lib = Join-Path `$PSScriptRoot '..\lib\check-report-lib.ps1'`n" +
         "if (Test-Path -LiteralPath `$lib) { . `$lib }`n"), $Utf8NoBom)
    $p3 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($p3.Out -match '\[plugin-lib\].*plugin-native')) `
        'plugin-lib: a Test-Path-guarded load of the same absent lib is not a finding'

    # 44d. THE CONTAINMENT ARM, AND WHY IT IS NOT REDUNDANT. This path climbs out of the plugin to a
    #      file that EXISTS in the fixture -- scripts\lib\shared-scripts-lib.ps1, which the fixture
    #      copies for the gate itself -- so the existence arm passes it and only containment reports
    #      it. In the installed copy the 'plugins/' level, the family level and every sibling are gone.
    [System.IO.File]::WriteAllText($plScript,
        ". (Join-Path `$PSScriptRoot '..\..\..\..\..\scripts\lib\shared-scripts-lib.ps1')`n", $Utf8NoBom)
    $p4 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (Test-Path -LiteralPath (Join-Path $Fixture 'scripts\lib\shared-scripts-lib.ps1')) `
        'plugin-lib: (precondition) the escaping path names a file that really is in the fixture'
    Assert-True ($p4.Out -match '\[plugin-lib\].*plugin-native\.ps1.*climbs OUT of') `
        'plugin-lib: a load escaping the plugin root is reported even though the file exists in this tree'

    # 44e. THE FALSE-POSITIVE CLASS THE CHECK IS BOUND AGAINST. A $repoRoot-relative path names a file
    #      in the CONSUMER'S own root by design -- branch-info.ps1 is repo-owned and travels in no
    #      mirror -- so it must not be read as plugin-relative. A regex over 'lib\<name>.ps1' reports
    #      14 of these on the real tree, all 14 false.
    [System.IO.File]::WriteAllText($plScript,
        ("`$repoRoot = 'C:\somewhere'`n" +
         ". (Join-Path `$repoRoot 'scripts\lib\branch-info.ps1')`n"), $Utf8NoBom)
    $p5 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($p5.Out -match '\[plugin-lib\].*plugin-native')) `
        'plugin-lib: a $repoRoot-relative load is not read as plugin-relative, however absent the file'

    # 44f. Removing the script clears every finding, so the check reads what is in the file rather than
    #      remembering a name it has seen.
    Remove-Item -LiteralPath $plScript -Force
    $p6 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($p6.Out -match '\[plugin-lib\].*plugin-native')) `
        'plugin-lib: removing the script clears the finding'

    # --- check 19: a named consumer-facing document that is not there ------------------------------
    # 42. THE SILENT-COVERAGE CASE. Checks 15 and 16 open each $consumerDocs entry with a Test-Path
    #     'continue', so a stale entry costs coverage and says nothing. Measured August 6, 2026, moving
    #     those documents into plugins/: expected-output went 5 -> 1 and measured-figure 11 -> 0 in one
    #     commit, no error anywhere, and it surfaced only because somebody read the coverage line.
    #     The fixture never creates plugins/UNINSTALL.md, so the entry is genuinely absent here.
    $s4 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($s4.Out -match '\[consumer-doc\].*UNINSTALL\.md') `
        'consumer-doc: a named document that does not exist is reported instead of skipped in silence'
    Assert-True ($s4.Out -match '\[consumer-doc\].*(update the list|drop the entry)') `
        'consumer-doc: and the finding names both repairs, since the list and the tree can each be the wrong one'

    # 43. AND THE REASON THIS ASSERT EXISTS AT ALL, which is not check 19's subject. Adding a finding
    #     used to depend on WHERE in the file you added it: sixteen bare '$errors += ...' lines rebuilt
    #     the List[string] as a fixed-size array, so the first Add-Error below the last of them threw
    #     "the collection is of a fixed size" and killed the run mid-scan. Check 19 sits below all of
    #     them and is therefore the canary: if the '+=' style ever comes back, this scenario stops
    #     reporting a finding and starts reporting an exception.
    Assert-True (-not ($s4.Out -match 'fixed size|vaste grootte')) `
        'consumer-doc: the run completes -- a finding raised after the last check does not hit a fixed-size collection'
    Assert-True ($s4.Out -match 'Summary: \d+ error') `
        'consumer-doc: and the summary is still reached, so the scan ended normally rather than dying mid-file'

    # --- check 20: a claimed section COUNT is held to the scaffolder's ------------------------------
    # ISSUE #508. The entry format lives in ~10 hand-maintained descriptions against two that cannot
    # drift, and two of those descriptions were measured stale. Both said the same checkable thing --
    # "three named `###` sections" -- while the scaffolder had moved to six.
    #
    # THE COUNT AND NOT THE NAMES, and the fixture below is why that matters more than it sounds: a
    # name-matching rule was measured against the real tree first and accused SIX correct documents,
    # because 'What does this change do?' and 'Type of change' are retired entry sections AND were, at
    # the time of that measurement, live headings of .github/pull_request_template.md. Both directions
    # are asserted, since a positive-only test would pass against a check that examines nothing.
    #
    # That collision was removed on 2026-08-09 (#538) when the template lost those sections, and the
    # choice does not move with it: name-matching also lost on its narrowed variant (3 findings, 2
    # false, against 4 claims with 3 correct), and a rule keyed on names is one rename away from going
    # silent -- which is exactly what just happened to the collision itself.
    Write-Host "check 20: a claimed section count vs. the scaffolder" -ForegroundColor Cyan
    $shapeDoc = Join-Path $Fixture 'dkj-policy\branch\README.md'
    New-Item -ItemType Directory -Path (Split-Path -Parent $shapeDoc) -Force | Out-Null

    # 44. A wrong count is reported, naming the file, the claim and the truth.
    [System.IO.File]::WriteAllText($shapeDoc, "# branch`n`nAn entry is one $docEntryH heading with three named $docSectH sections under it.`n", $Utf8NoBom)
    $e1 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($e1.Out -match '\[entry-shape\].*README\.md.*says an entry has 3') `
        'entry-shape: a stale section count is reported, naming the document and the number it claims'
    Assert-True ($e1.Out -match '\[entry-shape\] checked [1-9]') `
        'entry-shape: the coverage count proves a claim was actually examined, not an empty scan'

    # 45. The RIGHT count -- and nothing else changed -- makes the same file pass. Written from
    #     Get-EntryWrittenSectionKeys rather than the literal 'six', so this asserts the check is DERIVED:
    #     if the format gains a section, the fixture follows and the assert still means something.
    #     THE WRITTEN KEYS, NOT EVERY RECOGNISED ONE (August 16, 2026): Get-EntrySectionHeadings answers
    #     for the four retired sections too -- which is what keeps older entries readable -- so counting
    #     it would hold a document to a shape no reader ever meets.
    $shapeCount = @(Get-EntryWrittenSectionKeys).Count
    [System.IO.File]::WriteAllText($shapeDoc, "# branch`n`nAn entry is one $docEntryH heading with $shapeCount named $docSectH sections under it.`n", $Utf8NoBom)
    $e2 = Invoke-Integrity -FixtureRoot $Fixture
    # MATCHED ON THE FINDING'S OWN WORDS, not on the file name, and that is a repair rather than a style
    # choice: '\[entry-shape\].*README\.md' also matches the COVERAGE line, which names the branch README
    # while explaining what it does not exclude. Both negative asserts here failed on their first run for
    # that reason, against a check that was behaving correctly -- a fixture reproduction showed 'checked 1'
    # and no finding. An assert that can match the check's own prose is testing the note, not the rule.
    Assert-True (-not ($e2.Out -match 'says an entry has')) `
        'entry-shape: the correct count clears the finding, and the expected number comes from the scaffolder'

    # 46. THE HAYSTACK IS NARROW ON PURPOSE. Without the level marker the pattern matches ordinary prose
    #     about anything -- "one section apart", "two sections went in the same movement" -- which
    #     measured 18 disagreements of which 17 were noise. A count with no '###' beside it is not a
    #     claim about the entry's shape and must stay silent.
    [System.IO.File]::WriteAllText($shapeDoc, "# branch`n`nThe clean-machine claim appeared twice, one section apart, and three sections went with it.`n", $Utf8NoBom)
    $e3 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($e3.Out -match 'says an entry has')) `
        'entry-shape: a count with no level marker is prose about something else, not a claim about the shape'

    # --- check 20b: CHANGELOG.md's INTRO is in scope, its entries are not ---------------------------
    # The whole file used to be excluded as history, and the intro is not history: a cut empties the
    # document down to it and copies it through verbatim, so no release rewrites it and no reviewer opens
    # it. Measured on August 8, 2026 -- it claimed three sections while the scaffolder wrote six, two days
    # and one release after the format moved.
    #
    # TWO SEPARATE THINGS HELD IT OUT OF REACH, so both directions are asserted below: the file was
    # excluded, AND the pattern would have missed the sentence anyway -- it carried no '###' and it ran
    # across a line break. A test that only pinned the exclusion would pass against a check that still sees
    # nothing.
    Write-Host "check 20b: the changelog intro is held, its entries stay history" -ForegroundColor Cyan
    $shapeCl = Join-Path $Fixture 'dkj-policy\CHANGELOG.md'
    $shapeEntry = @(
        ''
        '## #123 ' + ([char]0x00B7) + ' A real entry'
        ''
        '### What does this change do?'
        ''
        'A body.'
        ''
        '### Significance'
        ''
        '#### Tier 0'
        ''
        'Only this repo notices.'
        ''
        '**Score:** 1'
        ''
    )
    function Write-ShapeChangelog([string]$Intro) {
        [System.IO.File]::WriteAllText($shapeCl,
            ((@('# Changelog', '', $Intro) + $shapeEntry) -join "`n") + "`n", $Utf8NoBom)
    }

    # 47. A stale count in the intro is reported -- WITHOUT a level marker, which the tree-wide pattern
    #     requires and this one deliberately does not. This is the exact sentence that was on main.
    Write-ShapeChangelog 'Everything merged since the last release: one `##` per change, and under it three named sections.'
    $e4 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($e4.Out -match '\[entry-shape\] dkj-policy[\\/]CHANGELOG\.md:3: says an entry has 3') `
        'entry-shape: a stale count in the changelog intro is reported, with its line, and needs no level marker'

    # 48. THE RELAXATION IS CONFINED TO THE HEAD. The same markerless claim below the first entry heading
    #     stays silent: entries ARE history, and they are full of prose about older shapes that was true
    #     when it was written. Without this assert the widening would quietly re-accuse the whole archive.
    Write-ShapeChangelog 'Everything merged since the last release, furthest reach first.'
    [System.IO.File]::WriteAllText($shapeCl,
        ([System.IO.File]::ReadAllText($shapeCl, [System.Text.Encoding]::UTF8)).Replace(
            'A body.', 'Back then an entry was one `##` heading with three named sections under it.'), $Utf8NoBom)
    $e5 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($e5.Out -match 'says an entry has')) `
        'entry-shape: the same markerless claim inside an ENTRY is history and stays silent'

    # 49. A claim REFLOWED across a line break is still caught. Matching is over the whole head rather than
    #     line by line, because where the wrap falls is a formatting accident no author would think of as a
    #     bypass -- and the drift that prompted this was written exactly that way.
    Write-ShapeChangelog "Everything merged since the last release: one $docEntryH per change, and under it three`nnamed $docSectH sections."
    $e6 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($e6.Out -match '\[entry-shape\] dkj-policy[\\/]CHANGELOG\.md:3: says an entry has 3') `
        'entry-shape: a claim split across a line break in the intro is caught, at the line it starts on'

    # 50. And the right count clears it -- taken from the scaffolder, not from the literal 'six', so this
    #     keeps meaning something the day the format gains a section.
    Write-ShapeChangelog "Everything merged since the last release: one $docEntryH per change, and under it $shapeCount named $docSectH sections."
    $e7 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($e7.Out -match 'says an entry has')) `
        'entry-shape: an intro stating the count the scaffolder writes clears the finding'
    Assert-True ($e7.Out -match '\[entry-shape\] checked [1-9]') `
        'entry-shape: and the intro was actually examined rather than skipped into silence'

    # --- check 22: a skill's runnable command must resolve on the reader's machine -------------------------
    # THE MEASURED DEFECT, August 8-9, 2026: adopt-config's page shipped in v3.8.0 with both commands
    # written as 'C:/Users/<the author>/.claude/plugins/cache/.../3.8.0/scripts/...'. It was the newest of
    # eleven skill pages and the only one not using the substitution, and it was the first command a
    # consumer runs to reach the release's headline feature.
    #
    # BOTH DIRECTIONS PLUS THE DELIBERATE PASS, because the third is what keeps this check exemption-free:
    # a '<plugin>' placeholder must NOT be reported. Angle brackets ask the reader to substitute; an
    # absolute path reads as a line to paste. A test that only pinned the positive would pass against a
    # stricter check that starts accusing the teardown page and needs a list to quiet it back down.
    Write-Host "check 22: a skill's command must not point at the author's disk" -ForegroundColor Cyan
    $cmdSkill = Join-Path $Fixture 'plugins\dkj-policy\skills\adopt-config\SKILL.md'
    New-Item -ItemType Directory -Path (Split-Path -Parent $cmdSkill) -Force | Out-Null
    function Write-CmdSkill([string]$Path) {
        [System.IO.File]::WriteAllText($cmdSkill,
            "# adopt-config`n`n## Run it`n`n``````powershell`npowershell -NoProfile -File `"$Path`"`n```````n", $Utf8NoBom)
    }

    # 51. The exact defect that shipped: a drive-letter path, reported with its file, its line and the
    #     offending path, so the finding names what to replace rather than only that something is wrong.
    Write-CmdSkill 'C:/Users/SomeAuthor/.claude/plugins/cache/mp/plugin/3.8.0/scripts/task/adopt-config.ps1'
    $c1 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($c1.Out -match '\[skill-command\].*adopt-config\\SKILL\.md:6: the command points at an absolute path') `
        'skill-command: a hardcoded cache path is reported, with the file and the line'
    Assert-True ($c1.Out -match [regex]::Escape('C:/Users/SomeAuthor')) `
        'skill-command: and the finding quotes the offending path, so the repair is obvious'
    Assert-True ($c1.Out -match '\[skill-command\] checked [1-9]') `
        'skill-command: the coverage count proves a command was actually examined, not an empty scan'

    # 52. A POSIX absolute path is the same defect on another machine, and would slip a drive-letter-only
    #     rule -- the plugin cache lives under a home directory on macOS and Linux.
    Write-CmdSkill '/home/someauthor/.claude/plugins/cache/mp/plugin/3.8.0/scripts/task/adopt-config.ps1'
    $c2 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($c2.Out -match '\[skill-command\].*the command points at an absolute path') `
        'skill-command: a POSIX home path is caught too, not just a Windows drive letter'

    # 53. The substitution clears it, changing nothing else about the page. This is the repair the finding
    #     asks for, so the test proves the advice actually works.
    Write-CmdSkill '${CLAUDE_PLUGIN_ROOT}/scripts/task/adopt-config.ps1'
    $c3 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($c3.Out -match '\[skill-command\] plugins')) `
        'skill-command: the ${CLAUDE_PLUGIN_ROOT} form clears the finding'

    # 54. THE EXEMPTION-FREE PROPERTY. The teardown page documents its command with a '<plugin>'
    #     placeholder, and that is honest rather than broken. Measured before the check was written:
    #     3 of the tree's 26 invocations are this shape, and reporting them would have needed a list.
    Write-CmdSkill '<plugin>/skills/specialists-teardown/teardown.ps1'
    $c4 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($c4.Out -match '\[skill-command\] plugins')) `
        'skill-command: a signposted <plugin> placeholder passes, so the check needs no exemption list'

    # --- check 24: the PR template keeps the two promises open-pr makes about it ---------------------
    # 56-61. The defect this guards was measured at a consumer, not imagined (#573): a template one word
    #        away from a recognised placeholder matched nothing, and TWELVE of their sixty merged PRs
    #        carried no description at all. Both halves are asserted, because they are held to different
    #        strengths on purpose -- the shipped reference byte for byte, the repo's own template only to
    #        the contract. That contract is ONE promise since issue #865: a placeholder line the matcher
    #        recognises. Scenario 57 is where the retired half is written down.
    Write-Host "  check 24: the PR template's two promises" -ForegroundColor DarkCyan
    $prtRefFixture = Join-Path $Fixture 'plugins\dkj-policy\templates\pull_request_template.md'
    $prtOwnFixture = Join-Path $Fixture '.github\pull_request_template.md'
    New-Item -ItemType Directory -Path (Join-Path $Fixture '.github') -Force | Out-Null

    # 56. THE NEAR-MISS, which is the whole reason the check exists. One word different from a recognised
    #     string: a human reads it as correct, and the whole-line comparison in open-pr does not.
    [System.IO.File]::WriteAllText($prtOwnFixture,
        "# What does the change on this branch bring to main?`n<!-- Brief description of what changes and why. -->`n", $Utf8NoBom)
    $p1 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($p1.Out -match '\[pr-template\].*no placeholder line open-pr recognises') `
        'pr-template: a near-miss placeholder is reported, not walked past'
    Assert-True ($p1.Out -match [regex]::Escape((Get-PrTemplateCanonicalPlaceholder))) `
        'pr-template: and the finding prints the strings that WOULD be recognised, so the repair is one paste'

    # 57. A TEMPLATE WITH NO HEADING IS CORRECT SINCE AUGUST 24, 2026 (issue #865), and this scenario is
    #     inverted rather than deleted. It used to assert the opposite: a heading was part of the contract,
    #     because -RefreshBody replaced the description under the template's first one and a template with
    #     none degraded to a warning on every run. That switch now reads the PLACEHOLDER's position
    #     instead -- headings above it are the description's, headings below it bound it, and where the
    #     placeholder comes first the description is the body's leading section. So the shape this repo
    #     ships is exactly the shape the old assert refused, which is why the scenario has to change with
    #     the rule rather than be relaxed around it.
    [System.IO.File]::WriteAllText($prtOwnFixture,
        ((Get-PrTemplateCanonicalPlaceholder) + "`n"), $Utf8NoBom)
    $p2 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($p2.Out -match '\[pr-template\] \.github')) `
        'pr-template: a heading-less template is not a finding -- it is the shape open-pr''s leading path expects'
    Assert-True ($p2.Out -match '\[pr-template\] checked 2') `
        'pr-template: and it was still examined rather than skipped into silence'

    # 58. The recognised placeholder clears it -- including a LEGACY one, because a consumer template
    #     carrying the Dutch string is correct and must not be accused of anything.
    [System.IO.File]::WriteAllText($prtOwnFixture,
        "## Wat doet deze wijziging?`n<!-- Korte beschrijving van wat er verandert en waarom. -->`n", $Utf8NoBom)
    $p3 = Invoke-Integrity -FixtureRoot $Fixture
    # Matched on the FINDING shape, not on the category tag: every run prints a '[pr-template] checked N'
    # coverage line, so a bare tag match would pass here for the wrong reason and keep passing after the
    # check was broken.
    Assert-True (-not ($p3.Out -match '\[pr-template\] \.github')) `
        'pr-template: a legacy-but-recognised placeholder clears the finding, so no exemption list is needed'
    Assert-True (-not ($p3.Out -match 'no placeholder line open-pr recognises')) `
        'pr-template: and specifically no placeholder finding, matched on the message rather than the tag'
    Assert-True ($p3.Out -match '\[pr-template\] checked 2') `
        'pr-template: and both subjects were actually examined, not skipped into silence'

    # 59. THE SHIPPED REFERENCE IS THE STRICT HALF. Editing it by hand is the drift that would hand a
    #     consumer a template open-pr walks past -- authoritative-looking and wrong.
    [System.IO.File]::WriteAllText($prtRefFixture,
        "# What does the change on this branch bring to main?`n<!-- Paste your description here. -->`n", $Utf8NoBom)
    $p4 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($p4.Out -match '\[pr-template\].*no longer matches Get-PrTemplateReference') `
        'pr-template: a hand-edited shipped reference is reported'
    [System.IO.File]::WriteAllText($prtRefFixture, (((Get-PrTemplateReference) -join "`n") + "`n"), $Utf8NoBom)

    # 60. NO TEMPLATE AT ALL IS NOT A FINDING. A repo without one is a repo open-pr simply does not
    #     pre-fill a body for; only a template that exists makes a promise. Refusing here would make the
    #     check fire on every consumer that has not written one, which is how a gate gets switched off.
    Remove-Item -LiteralPath $prtOwnFixture -Force
    $p5 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($p5.Out -match '\[pr-template\] \.github')) `
        'pr-template: a repo with no template of its own is not accused of anything'
    Assert-True ($p5.Out -match '\[pr-template\] checked 1') `
        'pr-template: and the coverage line says so, instead of reporting the same number as a full run'

    # --- check 25: the consumer document does not misroute its own reader -----------------------------
    # 62-67. The defect is measured rather than imagined: on the day this landed, TWO of eleven consumer
    #        documents linked into releases/development/, the tree defined as "only this repo's own
    #        developers", and both labelled it invitingly ("The full recap is in the release notes").
    #        What has to be asserted is not only that a link is caught, but the three ways this check is
    #        deliberately NARROWER than the obvious version -- each of those is a false finding it would
    #        otherwise produce on this repo's own tree.
    Write-Host "  check 25: a consumer document does not link into another tier" -ForegroundColor DarkCyan
    $ctrDir = Join-Path $Fixture 'releases\consumer\9.x'
    New-Item -ItemType Directory -Path $ctrDir -Force | Out-Null
    $ctrDoc = Join-Path $ctrDir '9.0.0.md'

    # 62. The measured defect itself, in the exact shape it had.
    [System.IO.File]::WriteAllText($ctrDoc,
        "# Release notes v9.0.0`n`nThe full recap is in the [release notes](../../development/9.x/9.0.0.md).`n", $Utf8NoBom)
    $t1 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($t1.Out -match "\[consumer-tier\].*links into 'development/'") `
        'consumer-tier: a link into the development tree is reported'
    Assert-True ($t1.Out -match 'line 3') `
        'consumer-tier: and the finding names the LINE, so the repair does not need a search'
    # The internal tier too -- tier 1 is not this document's reader either, and a check that knew only
    # about tier 0 would wave through the nearer half of the same mistake.
    [System.IO.File]::WriteAllText($ctrDoc,
        "# Release notes v9.0.0`n`nSee the [summary](../../internal/9.x/9.0.0.md).`n", $Utf8NoBom)
    $t2 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($t2.Out -match "\[consumer-tier\].*links into 'internal/'") `
        'consumer-tier: a link into the internal tree is reported too'
    # AND THE TIER-0 TREE UNDER ITS CURRENT NAME (issue #914, August 26, 2026). The directory renamed
    # 'development' -> 'changelog', and this check matches the tier by LITERAL directory name -- so the
    # rename would have taken it silent on the exact defect it was written for, with its coverage count
    # still reading healthy. Both names are asserted, in both directions: the new one because it is what
    # this repo has, the old one above because an unmigrated consumer still has that.
    [System.IO.File]::WriteAllText($ctrDoc,
        "# Release notes v9.0.0`n`nThe full recap is in the [release notes](../../changelog/9.x/9.0.0.md).`n", $Utf8NoBom)
    $t2b = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($t2b.Out -match "\[consumer-tier\].*links into 'changelog/'") `
        'consumer-tier: a link into the RENAMED tier-0 tree is reported -- the rename did not silence the check'
    Assert-True ($t2b.Out -match "tier 0, only this repo's own developers") `
        'consumer-tier: and it is named as tier 0, the same tier the old directory name reports'

    # 63. THE LINK TEXT IS NOT THE TARGET. v3.7.0's real consumer document writes ABOUT the tiers, and a
    #     check matching anywhere on the line would accuse it. This is the first of the three narrowings.
    [System.IO.File]::WriteAllText($ctrDoc,
        "# Release notes v9.0.0`n`nThe development notes carry the full record; see [the tier model](../../README.md).`n", $Utf8NoBom)
    $t3 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($t3.Out -match '\[consumer-tier\] releases')) `
        'consumer-tier: a tier NAMED in prose or link text is not a finding -- only the link target counts'

    # 64. A link to another CONSUMER document is the correct thing to offer, and the most common one.
    [System.IO.File]::WriteAllText($ctrDoc,
        "# Release notes v9.0.0`n`nStart at [the v3.2.0 notes](../3.x/3.2.0.md).`n", $Utf8NoBom)
    $t4 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($t4.Out -match '\[consumer-tier\] releases')) `
        'consumer-tier: a link to another consumer document clears the check'
    Assert-True ($t4.Out -match '\[consumer-tier\] checked \d+') `
        'consumer-tier: and the coverage line proves a document was actually read, not skipped into silence'

    # 64b. AN INTERNAL NOTE IS NOT SCANNED, and this is the assert that keeps the check from being
    #      "tidied" into symmetry. releases/internal/ is the two-document flow's ORGANISATIONAL document:
    #      its reader IS the organisation, so a link from it into the per-PR record is correct, and reading
    #      that tree here would accuse a right document of the one thing it cannot do. Written down on
    #      August 12, 2026, when this repo's own releases/consumer/ + releases/internal/ pairs were merged
    #      into releases/audience/ -- the merged document is covered because both registers share ONE file,
    #      which the reader-not-directory rule already handles, and not because both trees are read.
    $ctrIntDir = Join-Path $Fixture 'releases\internal\9.x'
    New-Item -ItemType Directory -Path $ctrIntDir -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $ctrIntDir '9.0.0.md'),
        "# Internal summary v9.0.0`n`nThe per-PR record is in [the notes](../../development/9.x/9.0.0.md).`n", $Utf8NoBom)
    $t4b = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($t4b.Out -match '\[consumer-tier\] releases\\internal')) `
        'consumer-tier: an internal note linking into the development tree is NOT a finding -- its reader is the organisation'
    Remove-Item -Recurse -Force -LiteralPath (Join-Path $Fixture 'releases\internal') -ErrorAction SilentlyContinue

    # 65. NO CONSUMER TREE IS NOT A FINDING -- that is the tier switched off, which is the default for
    #     every consumer that has not opted into it. Refusing here is how a gate gets switched off.
    Remove-Item -Recurse -Force -LiteralPath (Join-Path $Fixture 'releases\consumer') -ErrorAction SilentlyContinue
    $t5 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($t5.Out -match '\[consumer-tier\] releases')) `
        'consumer-tier: a repo with no consumer tier is not accused of anything'
    Assert-True ($t5.Out -match '\[consumer-tier\] checked 0') `
        'consumer-tier: and it says so, rather than reporting the same coverage as a full run'

    # 66. THE LIVE ROOT FOLLOWS Get-ReleaseNoteRoot, AND THIS IS THE ASSERT THAT WOULD HAVE CAUGHT THE BUG.
    #     Until August 12, 2026 the check named 'releases\notes' as a literal, so a repo that repointed the
    #     seam -- which this repo then did, to releases/audience -- would have had its live tree walk past
    #     unread while the coverage line still printed a plausible number. A gate going quiet with nothing
    #     erroring is the failure class this repo keeps paying for, and the only defence is a fixture whose
    #     root is deliberately NOT the default. The document below is placed under a third name that is
    #     neither the default nor the archive, so nothing but the seam can find it.
    $ctrSeamDir = Join-Path $Fixture 'releases\audience\9.x'
    New-Item -ItemType Directory -Path $ctrSeamDir -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $ctrSeamDir '9.0.0.md'),
        "# Release notes v9.0.0`n`nThe full recap is in the [release notes](../../development/9.x/9.0.0.md).`n", $Utf8NoBom)
    $ctrSeamCfg = Join-Path $Fixture 'scripts\repo-config.ps1'
    New-Item -ItemType Directory -Path (Split-Path -Parent $ctrSeamCfg) -Force | Out-Null
    [System.IO.File]::WriteAllText($ctrSeamCfg,
        "function Get-ReleaseNoteRoot { return 'releases/audience' }`n", $Utf8NoBom)
    $t6 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($t6.Out -match "\[consumer-tier\].*links into 'development/'") `
        'consumer-tier: the tree named by Get-ReleaseNoteRoot is walked, not a hardcoded releases/notes'
    Assert-True ($t6.Out -match '\[consumer-tier\] checked [1-9]') `
        'consumer-tier: and the coverage counts it, so a repointed root cannot report a healthy zero'

    # 67. THE PRE-RENAME ROOT IS STILL WALKED ALONGSIDE IT. A repo mid-migration has documents under both
    #     names, and reading only whichever the seam happens to name today would drop the other half in
    #     silence. Recognise both, write one -- the same rule the retired seam names get.
    $ctrOldDir = Join-Path $Fixture 'releases\notes\9.x'
    New-Item -ItemType Directory -Path $ctrOldDir -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $ctrOldDir '8.0.0.md'),
        "# Release notes v8.0.0`n`nSee the [summary](../../internal/9.x/9.0.0.md).`n", $Utf8NoBom)
    $t7 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($t7.Out -match "\[consumer-tier\] releases\\notes\\9\.x\\8\.0\.0\.md.*links into 'internal/'") `
        'consumer-tier: a document left behind under the pre-rename root is still held'
    Assert-True ($t7.Out -match "\[consumer-tier\] releases\\audience\\9\.x\\9\.0\.0\.md") `
        'consumer-tier: and the seam root is held in the same run -- both roots, not whichever one wins'

    Remove-Item -Recurse -Force -LiteralPath (Join-Path $Fixture 'releases\audience') -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force -LiteralPath (Join-Path $Fixture 'releases\notes') -ErrorAction SilentlyContinue
    Remove-Item -Force -LiteralPath $ctrSeamCfg -ErrorAction SilentlyContinue

    # --- check 26: a frontmatter document opens with '---', read as bytes -----------------------------
    # 66-71. The defect is measured, not imagined: adopt-config/SKILL.md shipped with EF BB BF in 4.1.0
    #        and was the one model-invocable skill of eleven missing from the agent's skill listing
    #        (#581). What makes it worth a gate is that NOTHING ELSE CAN SEE IT -- ReadAllText strips a
    #        BOM before any regex in this script runs, and no editor shows it -- so the assertions below
    #        pin the byte-level reading as much as the finding.
    Write-Host "  check 26: frontmatter opens with '---', with no byte-order mark" -ForegroundColor DarkCyan
    $bomSkill = Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-alpha\skills\skill-alpha\SKILL.md'
    $bomGoodBytes = [System.IO.File]::ReadAllBytes($bomSkill)

    # 66. The measured defect, in the exact shape it shipped: three bytes in front of a correct file.
    [System.IO.File]::WriteAllBytes($bomSkill, (@([byte]0xEF, [byte]0xBB, [byte]0xBF) + $bomGoodBytes))
    $fmb1 = Invoke-Integrity -FixtureRoot $Fixture -Full
    Assert-True ($fmb1.Out -match '\[frontmatter-bom\].*byte-order mark') `
        'frontmatter-bom: a BOM before the opening --- is reported'
    Assert-True ($fmb1.Out -match 'skill-alpha') `
        'frontmatter-bom: and the finding names the file, which is the only way to find a defect nothing renders'
    Assert-True ($fmb1.Code -ne 0) `
        'frontmatter-bom: and it fails the gate rather than warning -- the skill does not load at all'

    # 67. THE POINT OF READING BYTES. The same file is perfectly valid UTF-8 with valid YAML frontmatter,
    #     so every other check here passes it. If this assert ever fails it means the check started
    #     reading text, and the defect became invisible again.
    Assert-True (-not ($fmb1.Out -match '\[agent-def\].*skill-alpha')) `
        'frontmatter-bom: the BOMed file is otherwise valid -- no other check sees anything wrong with it'
    [System.IO.File]::WriteAllBytes($bomSkill, $bomGoodBytes)

    # 68. Removing the three bytes clears the finding, so the assert above is bound to the BOM rather than
    #     to something else the fixture happens to produce. Asserted on THIS file rather than on the
    #     absence of any finding at all: the suite's own fixtures for checks 18 and 22 are deliberately
    #     frontmatter-less minimal pages, which this check does not accuse -- see 69.
    $fmb2 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($fmb2.Out -match '\[frontmatter-bom\].*skill-alpha')) `
        'frontmatter-bom: stripping the BOM clears the finding -- it tracked the bytes, not the file'
    Assert-True ($fmb2.Out -match '\[frontmatter-bom\] checked [1-9]') `
        'frontmatter-bom: and the pass is not an empty scan'

    # 69. THE SUBJECT IS THE BOM, NOT "MUST HAVE FRONTMATTER". This repo deliberately tolerates a skill
    #     page with no 'name:' line -- the canonical reader falls back to the folder name for exactly that
    #     reason -- so a check demanding the block would be inventing a policy the repo declined. The
    #     proof is already sitting in this fixture: check 18's park page and check 22's adopt-config page
    #     are frontmatter-less on purpose. A rule requiring '---' was born accusing both, and quieting
    #     them meant shifting the line numbers check 22 asserts on. This assert is what keeps it narrow.
    Assert-True (-not ($fmb2.Out -match '\[frontmatter-bom\].*park')) `
        'frontmatter-bom: a frontmatter-less skill page is NOT a finding -- the subject is the BOM, not the block'

    # 70. THE REGISTRATION SCOPE. A deeper references/SKILL.md is a progressive-disclosure page that
    #     nothing registers, so there is no positional frontmatter parse for a BOM to break. The depth
    #     decoy already in this fixture is the subject, given a BOM it must NOT be reported for.
    $bomDecoy = Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-alpha\skills\skill-alpha\references\SKILL.md'
    $bomDecoyGood = [System.IO.File]::ReadAllBytes($bomDecoy)
    [System.IO.File]::WriteAllBytes($bomDecoy, (@([byte]0xEF, [byte]0xBB, [byte]0xBF) + $bomDecoyGood))
    $fmb4 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($fmb4.Out -match '\[frontmatter-bom\].*references')) `
        'frontmatter-bom: a progressive-disclosure references/SKILL.md is out of scope -- nothing registers it'
    [System.IO.File]::WriteAllBytes($bomDecoy, $bomDecoyGood)

    # --- check 27: the script layer is pure ASCII -----------------------------------------------------
    # 71-77. The rule is older than the check: .claude/rules/language-layers.md has required a code point
    #        for any non-ASCII character in a .ps1 since August 19, 2026, after a middot typed literally
    #        into entry-scaffold-lib.ps1 came out of every generated changelog template as two wrong
    #        characters. Windows PowerShell 5.1 reads a BOM-less .ps1 as the system ANSI code page, so the
    #        damage is a WRONG ANSWER rather than a failure -- a mis-decoded string is still a string.
    #        The scenarios below pin three things separately: that it fires, that the escaped form does
    #        NOT, and that a BOM does not either.
    Write-Host '  check 27: the script layer is pure ASCII' -ForegroundColor DarkCyan
    $asciiProbe = Join-Path $Fixture 'scripts\task\ascii-probe.ps1'
    New-Item -ItemType Directory -Path (Split-Path -Parent $asciiProbe) -Force | Out-Null
    $asciiCleanBody = "# A probe script. Pure ASCII (repo convention for .ps1).`nWrite-Host 'probe'`n"

    # 71. The measured defect in the exact shape it shipped: the middot, typed as itself.
    [System.IO.File]::WriteAllText($asciiProbe, ($asciiCleanBody + '$sep = ' + "'" + [char]0x00B7 + "'`n"), $Utf8NoBom)
    $sa1 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($sa1.Out -match '\[script-ascii\].*ascii-probe\.ps1:3') `
        'script-ascii: a literal non-ASCII character is reported, with the file and the line'
    Assert-True ($sa1.Out -match 'U\+00B7') `
        'script-ascii: and the finding names the code point, which is the one thing an editor will not show'
    Assert-True ($sa1.Out -match '\[char\]0x00B7') `
        'script-ascii: and it hands over the remedy in the form the rule asks for'
    Assert-True ($sa1.Code -ne 0) `
        'script-ascii: and it fails the gate -- the character reaches whatever the script emits'

    # 72. THE ESCAPED FORM IS THE POINT OF THE CHECK, so it must be silent. Without this assert the check
    #     could be satisfied by deleting the character rather than by writing it correctly, and the
    #     finding's own advice would be untested.
    [System.IO.File]::WriteAllText($asciiProbe, ($asciiCleanBody + '$sep = [char]0x00B7' + "`n"), $Utf8NoBom)
    $sa2 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($sa2.Out -match '\[script-ascii\].*ascii-probe')) `
        'script-ascii: the code-point form is not a finding -- that is the repair the message asks for'
    Assert-True ($sa2.Out -match '\[script-ascii\] checked [1-9]') `
        'script-ascii: and the pass is not an empty scan'

    # 73. A BOM IS DELIBERATELY NOT A FINDING, and this is the assert that keeps it that way. On a .ps1 a
    #     BOM is what makes 5.1 read the file correctly, so accusing it would push an author toward the
    #     very defect. Check 26 owns the documents where a BOM does break something, and that check reads
    #     BYTES precisely because this one reads text.
    $bomProbeBytes = @([byte]0xEF, [byte]0xBB, [byte]0xBF) + [System.IO.File]::ReadAllBytes($asciiProbe)
    [System.IO.File]::WriteAllBytes($asciiProbe, $bomProbeBytes)
    $sa3 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($sa3.Out -match '\[script-ascii\].*ascii-probe')) `
        'script-ascii: a BOM on a .ps1 is not a finding -- there it is the fix, not the defect'
    Remove-Item -LiteralPath $asciiProbe -Force

    # 74-75. THE PLUGIN HOOKS ARE IN THE SET, and they were not until August 23, 2026: this gate held 151
    #        of the 158 tracked .ps1 files, the seven absentees being every plugins/<kind>/<plugin>/hooks
    #        script. Both halves are asserted, because widening the set fixed TWO checks: the ASCII rule
    #        names that layer explicitly, and a SessionStart hook that does not parse fails silently --
    #        the harness reports it and the session simply continues without what the hook was there to
    #        say. A parse error there was invisible to this gate for as long as the hooks were out.
    $hookProbe = Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-alpha\hooks\probe-sessioncheck.ps1'
    New-Item -ItemType Directory -Path (Split-Path -Parent $hookProbe) -Force | Out-Null
    [System.IO.File]::WriteAllText($hookProbe, ($asciiCleanBody + '$sep = ' + "'" + [char]0x00B7 + "'`n"), $Utf8NoBom)
    $sa4 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($sa4.Out -match '\[script-ascii\].*probe-sessioncheck\.ps1') `
        'script-ascii: a plugin HOOK is in scope -- language-layers.md names that layer'

    # 75. The same widening, proven on check 5: a hook that does not parse is now reported. -Full, because
    #     the fixture skips 'parse' for speed and an absence-or-presence assert under a skip proves
    #     nothing either way.
    [System.IO.File]::WriteAllText($hookProbe, "function Broken( {`n", $Utf8NoBom)
    $sa5 = Invoke-Integrity -FixtureRoot $Fixture -Full
    Assert-True ($sa5.Out -match '\[parse\].*probe-sessioncheck\.ps1') `
        'parse: a plugin hook that does not parse is reported -- the set widened for check 27 fixed this too'
    # AND THE TWO CHECKS THAT WALK THE SAME SET SURVIVE IT (issue #1358). Since barred-skill and
    # shopify-cli started sharing one pass through Get-PsScriptCommandAsts, an unparseable file is an
    # EMPTY CommandAst list rather than each check's own null-and-continue. Both still count the file as
    # covered and neither aborts -- asserted here because this is the only scenario in the four suites
    # that puts a file the parser refuses in front of them, and a shared accessor that returned $null
    # would take both checks down together instead of one.
    Assert-True ($sa5.Out -match '\[barred-skill\] checked \d+') `
        'barred-skill: still reports its coverage with a file the parser refuses in the set'
    Assert-True ($sa5.Out -match '\[shopify-cli\] checked \d+') `
        'shopify-cli: still reports its coverage with a file the parser refuses in the set -- the shared pass degrades to an empty list, not a null'
    Remove-Item -LiteralPath $hookProbe -Force
    Assert-True ((Invoke-Integrity -FixtureRoot $Fixture).Out -notmatch '\[script-ascii\] \.') `
        'script-ascii: the fixture is clean again once both probes are gone'

    # --- check 35: a test fixture's own git command is judged -----------------------------------------
    # 76-84. WHAT THE CHECK IS FOR (issue #1655). A suite in scripts/tests/ builds its fixture with git,
    #        and the house idiom discarded the exit code along with the output -- so a git that FAILED
    #        read exactly like one that worked, and the asserts below it then measured a repo that was
    #        never built, attributing the failure to the script under test. #1635 converted seventeen
    #        suites and left nothing that refuses the next copy of the idiom.
    #
    #        THE SCENARIOS BELOW PIN THE BOUNDARY, NOT JUST THE FINDING, and that is the whole reason
    #        the check took a measurement before it was written: the false-positive class here is a git
    #        QUESTION whose non-zero exit IS the answer. The silent run below is the one that gives the
    #        check its meaning -- without it, flagging every discarded git call would pass every other
    #        assert here.
    #
    #        THREE GATE INVOCATIONS, NOT ONE PER SHAPE, and that is a cost decision with numbers behind
    #        it. Each Invoke-Integrity spawns a fresh powershell over the ~4,000-line gate: ~1.1s of
    #        interpreter start and parse, whatever the scenario asserts. Written the obvious way -- one
    #        rewrite-and-reinvoke per shape -- this block cost 12 invocations and took the suite from
    #        54.5s to 63.7s (+9.2s, +17%), on a file that runs on every push and again in CI. The shapes
    #        are independent, so they are batched by EXPECTED VERDICT instead: every shape that must fire
    #        in one run, every shape that must stay silent in the next. Same asserts, 3 invocations,
    #        57.3s (+2.8s, +5%) -- measured, 3 runs each side.
    #
    #        WHAT PAYS FOR THAT is that each probe carries its shape in its FILE NAME, so a single run's
    #        output still says which shape failed. Batching scenarios that could not be told apart in the
    #        output would trade a real diagnostic for the seconds, and that is not the trade being made.
    Write-Host '  check 35: a test fixture git command is judged' -ForegroundColor DarkCyan
    $fgDir  = Join-Path $Fixture 'scripts\tests'
    New-Item -ItemType Directory -Path $fgDir -Force | Out-Null
    $fgHead = "# A probe suite. Pure ASCII (repo convention for .ps1).`n`$dir = 'C:\nowhere'`n"
    function Write-FgProbe {
        param([string]$Name, [string]$Body)
        [System.IO.File]::WriteAllText((Join-Path $fgDir "$Name.tests.ps1"), ($fgHead + $Body + "`n"), $Utf8NoBom)
    }

    # 76-81. EVERY SHAPE THAT MUST FIRE, in one run. The first is the measured defect in the exact
    #        spelling it shipped in for as long as this directory has existed. The rest are the ways an
    #        author can write the same thing: a second INVOCATION spelling (source-repo-guard's
    #        scriptblock over Invoke-NativeCapture, nine calls the #1635 search never reached), and all
    #        three DISCARD spellings, two of them also in a parenthesised form -- because the check was
    #        first built with only the [void] arm climbing out of '(...)', so one pair of brackets was an
    #        escape hatch for the other two. A check whose arms disagree about wrapping teaches whichever
    #        shape the weakest arm accepts.
    Write-FgProbe 'fg-idiom'      '& git -C $dir init -q 2>$null | Out-Null'
    Write-FgProbe 'fg-varspell'   ('$git = { param([string[]]$a) & git @a }' + "`n" + '& $git @(''-C'', $dir, ''init'', ''-q'') | Out-Null')
    Write-FgProbe 'fg-nullassign' '$null = git -C $dir add -A'
    Write-FgProbe 'fg-voidcast'   '[void](& git -C $dir add -A)'
    Write-FgProbe 'fg-parennull'  '$null = (& git -C $dir init -q)'
    Write-FgProbe 'fg-parenout'   '(& git -C $dir add -A) | Out-Null'
    # AND THE CLEARING CONDITION READS THE AST, NOT THE LINE. This one belongs with the firing shapes
    # because it is a finding a text match would have wrongly CLEARED -- and a wrongly cleared miss leaves
    # nothing behind to notice, which is why it matters more here than anywhere else in the check.
    Write-FgProbe 'fg-litmention' ('& git -C $dir tag t | Out-Null' + "`n" + 'Write-Host ''mentions $LASTEXITCODE in a literal only''')
    $fgFire = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($fgFire.Out -match '\[fixture-git\].*fg-idiom\.tests\.ps1:3') `
        'fixture-git: the unjudged fixture idiom is reported, with the file and the line'
    Assert-True ($fgFire.Out -match 'Invoke-FixtureGitIn') `
        'fixture-git: and the finding hands over the shared lib, so the repair needs no source reading'
    Assert-True ($fgFire.Code -ne 0) `
        'fixture-git: and it fails the gate -- an unbuilt fixture makes every assert below it meaningless'
    Assert-True ($fgFire.Out -match '\[fixture-git\].*fg-varspell\.tests\.ps1:4') `
        'fixture-git: a call through a variable named exactly $git is in scope too'
    Assert-True ($fgFire.Out -match '\[fixture-git\].*fg-nullassign') `
        'fixture-git: $null = <git call> discards the result the same way and is a finding too'
    Assert-True ($fgFire.Out -match '\[fixture-git\].*fg-voidcast') `
        'fixture-git: a [void] cast is the third discard spelling and is a finding too'
    Assert-True ($fgFire.Out -match '\[fixture-git\].*fg-parennull') `
        'fixture-git: $null = (<git call>) -- parenthesised, still a finding'
    Assert-True ($fgFire.Out -match '\[fixture-git\].*fg-parenout') `
        'fixture-git: (<git call>) | Out-Null -- parenthesised, still a finding'
    Assert-True ($fgFire.Out -match '\[fixture-git\].*fg-litmention') `
        'fixture-git: $LASTEXITCODE inside a single-quoted string does not clear a finding -- it is not a read'
    Get-ChildItem -Path $fgDir -Filter 'fg-*.tests.ps1' -File | Remove-Item -Force

    # 82-84. EVERY SHAPE THAT MUST STAY SILENT, in one run. The QUESTION is the assert that gives this
    #        check its meaning: a 'rev-parse --verify --quiet' on a ref EXPECTED to be absent answers with
    #        exit 1 and is judged on the very next line, and #1635's own conversion hit that class twice.
    #        The CONVERTED form must be silent or the check could be satisfied by deleting a call rather
    #        than judging it, leaving its own advice untested. The BARE statement pipeline is a measured
    #        bound rather than an assumption -- widening to it yields 20 findings on this repo's tree and
    #        all 20 are value-returning questions.
    Write-FgProbe 'fg-question'  ('& git -C $dir rev-parse --verify --quiet refs/heads/main | Out-Null' + "`n" + 'if ($LASTEXITCODE -eq 0) { Write-Host ''present'' }')
    Write-FgProbe 'fg-converted' 'Invoke-FixtureGitIn $dir init -q'
    Write-FgProbe 'fg-barepipe'  '& git -C $dir log --oneline'
    # AND THE SCOPE, asserted from the outside. Production code that ignores a failed git usually goes on
    # to fail visibly; a fixture that ignores one produces a repo that is plausible and wrong. So the same
    # idiom under scripts/task/ is not this check's business, and a check quietly widened past its stated
    # set would break every caller relying on the boundary.
    $fgOutside = Join-Path $Fixture 'scripts\task\fg-outside.ps1'
    New-Item -ItemType Directory -Path (Split-Path -Parent $fgOutside) -Force | Out-Null
    [System.IO.File]::WriteAllText($fgOutside, ($fgHead + '& git -C $dir init -q 2>$null | Out-Null' + "`n"), $Utf8NoBom)
    $fgSilent = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($fgSilent.Out -match '\[fixture-git\].*fg-question')) `
        'fixture-git: a git QUESTION judged on the next statement is not a finding -- exit 1 is its answer'
    Assert-True ($fgSilent.Out -match '\[fixture-git\] checked [1-9]') `
        'fixture-git: and that pass is not an empty scan'
    Assert-True (-not ($fgSilent.Out -match '\[fixture-git\].*fg-converted')) `
        'fixture-git: the shared-lib form is not a finding -- that is the repair the message asks for'
    Assert-True (-not ($fgSilent.Out -match '\[fixture-git\].*fg-barepipe')) `
        'fixture-git: a bare statement pipeline is not a subject -- its output is the return value'
    Assert-True (-not ($fgSilent.Out -match '\[fixture-git\].*fg-outside')) `
        'fixture-git: the same idiom OUTSIDE scripts/tests/ is not a subject -- the set is stated and held to'
    Get-ChildItem -Path $fgDir -Filter 'fg-*.tests.ps1' -File | Remove-Item -Force
    Remove-Item -LiteralPath $fgOutside -Force
    Assert-True ((Invoke-Integrity -FixtureRoot $Fixture).Out -notmatch '\[fixture-git\] \.') `
        'fixture-git: the fixture is clean again once every probe is gone'

    # --- Scenario 55: A MARKETPLACE THAT DOES NOT PARSE STILL LEAVES A REPORTING GATE ----------------
    # 55. The lint reads the plugin set from marketplace.json now, and the whole point of doing that
    #     inside a swallowing try/catch is that the file it reads can be broken. Measured while this was
    #     being reviewed, before the repair: a SECOND, unguarded read further down (check 8's registry
    #     call) threw straight out of the script, so checks 9 through 22 never ran and no Summary line
    #     was printed at all. A gate that dies is worse than one reporting zero, because it looks like a
    #     crash rather than like a finding, and nothing downstream of it is heard from.
    #
    #     Asserted on the LAST check's coverage line and on the Summary, not on check 8's own output:
    #     what failed was everything AFTER the throw, so that is what has to be proven present. This is
    #     the only scenario that writes invalid JSON -- every other malformed-marketplace case in this
    #     suite (missing plugins list, missing source) is still syntactically valid, which is exactly
    #     why the suite could not see this.
    $goodMarketplace = [System.IO.File]::ReadAllText((Join-Path $Fixture '.claude-plugin\marketplace.json'), [System.Text.Encoding]::UTF8)
    [System.IO.File]::WriteAllText((Join-Path $Fixture '.claude-plugin\marketplace.json'), '{ this is not json ', $Utf8NoBom)
    $c5 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($c5.Out -match 'Summary:') `
        'corrupt marketplace: the run still reaches its Summary instead of dying mid-gate'
    Assert-True ($c5.Out -match '\[skill-command\]') `
        'corrupt marketplace: and the checks after the plugin-set read still report'
    Assert-True ($c5.Out -match '\[shared-script\] checked 0') `
        'corrupt marketplace: check 8 degrades to zero pairs, visibly, rather than throwing'
    Assert-True ($c5.Code -ne 0) `
        'corrupt marketplace: and the run still fails -- check 1 reported the unparseable file'
    [System.IO.File]::WriteAllText((Join-Path $Fixture '.claude-plugin\marketplace.json'), $goodMarketplace, $Utf8NoBom)

    # --- check 6b: a manual is backed by an agent def OR a persona ------------------------------------
    # ADDED WITH #1017 (August 28, 2026), which relaxed 6b -- and found check 6 had no coverage at all,
    # in any of the four suites. The relaxation is the kind that fails silently in the direction that
    # matters: a gate that now accepts MORE cannot be seen to have started accepting everything. So all
    # four states are asserted, not just the new one.
    #
    # The fixture's dkj-subagents-alpha carries no specialists, so this scenario builds its own pair and removes
    # them again -- every other check in this file reads that plugin too, and a stray agent def would
    # change what checks 7 and 26 walk for the scenarios below.
    Write-Host "check 6b: a manual may be backed by a persona, and must then be named by it" -ForegroundColor Cyan
    $spAgents   = Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-alpha\subagents'
    $spManuals  = Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-alpha\manuals'
    $spPersonas = Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-alpha\personas'
    New-Item -ItemType Directory -Path $spManuals  -Force | Out-Null
    New-Item -ItemType Directory -Path $spPersonas -Force | Out-Null
    $spManualPath  = Join-Path $spManuals  '99-99-manual.md'
    $spPersonaPath = Join-Path $spPersonas '99-99-persona.md'
    $spAgentPath   = Join-Path $spAgents   '99-99-agent.md'
    [System.IO.File]::WriteAllText($spManualPath, "---`nid: 99`ngroup: 99`n---`n`n# Fixture manual`n", $Utf8NoBom)

    # 1. Neither backer: still an orphan. The check's whole reason for existing survives the relaxation.
    $b1 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($b1.Out -match 'orphan manual') `
        'check 6b: a manual with neither an agent def nor a persona is still an orphan'
    Assert-True ($b1.Out -match 'personas/99-99-persona\.md') `
        'check 6b: and the finding names the persona path too, so the reader learns the second way out'

    # 2. A persona that does NOT name the manual: accepted as a backer, refused for being silent. This is
    #    the half that can break -- a persona is the only file that gets loaded, so an unnamed manual is
    #    a file nothing will ever read, which is indistinguishable from not having written it.
    [System.IO.File]::WriteAllText($spPersonaPath, "---`nid: 99`ngroup: 99`n---`n`n# Fixture persona`n", $Utf8NoBom)
    $b2 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($b2.Out -match 'orphan manual')) `
        'check 6b: a persona backs the manual, so it is no longer an orphan'
    Assert-True ($b2.Out -match 'does not name it') `
        'check 6b: but a persona that never names its manual is refused -- nothing would read it'

    # 3. A persona that names it: clean.
    [System.IO.File]::WriteAllText($spPersonaPath,
        "---`nid: 99`ngroup: 99`n---`n`n# Fixture persona`n`nPlaybook: manuals/99-99-manual.md`n", $Utf8NoBom)
    $b3 = Invoke-Integrity -FixtureRoot $Fixture
    # ASSERTED ON THE FINDING TEXT, not on '[specialist]'. That bracket also opens the coverage line
    # ('[specialist] checked 1'), which this check prints on every run including a clean one -- so the
    # obvious absence assert passes only while the check is silent about everything, including itself.
    Assert-True (-not ($b3.Out -match 'orphan manual')) `
        'check 6b: a persona that names its manual passes -- the pairing #1017 asked for'
    Assert-True (-not ($b3.Out -match 'does not name it')) `
        'check 6b: and naming it is what clears the second finding, nothing else about the file changed'

    # 4. A persona with NO manual is the normal case and is asserted about in neither direction. Bianca,
    #    Derek and Rendall are all in this state, so a rule that read a bare persona as a finding would
    #    fail the real repo on three files.
    Remove-Item -LiteralPath $spManualPath -Force
    $b4 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($b4.Out -match 'orphan manual|does not name it')) `
        'check 6b: a persona with no manual at all is untouched -- three real specialists live there'

    Remove-Item -LiteralPath $spPersonaPath -Force
    if (Test-Path -LiteralPath $spAgentPath) { Remove-Item -LiteralPath $spAgentPath -Force }
    Remove-Item -LiteralPath $spManuals -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $spPersonas -Recurse -Force -ErrorAction SilentlyContinue

    # --- check 38: the 'agents' key -- the installer's shape, and every def named -------------------
    # THE PRE-REPAIR TREE IS THE FIRST SCENARIO, deliberately. #1764's whole point is that the gate
    # reported 0 error(s) over four manifests 'claude plugin install' refuses outright, so a suite that
    # only proved the repaired shape passes would prove nothing about the defect. Scenario 1 below writes
    # exactly what v4.33.0 shipped.
    #
    # BOTH DIRECTIONS ARE EXERCISED because they fail differently and only one is reachable by
    # 'claude plugin validate': a bad element makes the installer refuse the whole plugin, an omitted def
    # installs fine and never loads.
    #
    # NO -Full IS NEEDED even though this check reads agent defs: it does its own discovery rather than
    # reusing $agentDefs, so -SkipCheck agent-def (this suite's default) does not narrow it. Asserted
    # below rather than assumed -- that is exactly the shape the fixture header warns about.
    Write-Host "check 38: the 'agents' key -- shape and completeness" -ForegroundColor Cyan
    $akManifest = Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-alpha\.claude-plugin\plugin.json'
    $akSubagents = Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-alpha\subagents'
    $akManifestOrig = [System.IO.File]::ReadAllText($akManifest, [System.Text.Encoding]::UTF8)
    New-Item -ItemType Directory -Path $akSubagents -Force | Out-Null
    $akDefA = Join-Path $akSubagents '01-01-agent.md'
    $akDefB = Join-Path $akSubagents '02-02-agent.md'
    foreach ($akDef in @($akDefA, $akDefB)) {
        [System.IO.File]::WriteAllText($akDef, "---`nname: fixture`nid: 01`ngroup: 01`n---`n`n# Fixture def`n", $Utf8NoBom)
    }
    function Set-AkManifest { param([string]$AgentsJson)
        $body = if ($AgentsJson) { ", `"agents`": $AgentsJson" } else { '' }
        [System.IO.File]::WriteAllText($akManifest,
            "{ `"name`": `"dkj-subagents-alpha`", `"version`": `"0.0.1`"$body }`n", $Utf8NoBom)
    }

    # 1. THE #1764 STATE: a directory as a bare string. The installer answers 'agents: Invalid input'
    #    and installs nothing; this gate said 0 error(s).
    Set-AkManifest -AgentsJson '"./subagents/"'
    $ak1 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($ak1.Out -match '\[agents-key\].*does not name a \.md file') `
        'check 38: a directory as the agents string is reported -- the exact manifest v4.33.0 shipped'
    Assert-True ($ak1.Out -match '\[agents-key\].*#1764') `
        'check 38: and the finding cites the issue, so a reader gets the measurement without the source'
    Assert-True ($ak1.Code -ne 0) 'check 38: the run fails, so the gate would have refused the release'

    # 2. THE ARRAY FORM OF THE SAME MISTAKE. The validator distinguishes them ('agents.0' rather than
    #    'agents'), so a check that only knew the string form would pass the obvious next attempt --
    #    which is the one #1764 measured second.
    Set-AkManifest -AgentsJson '["./subagents/"]'
    $ak2 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($ak2.Out -match '\[agents-key\].*does not name a \.md file') `
        'check 38: a directory INSIDE the array is reported too -- the array is legal, the element is not'

    # 3. A GLOB, which reads as the obvious way out of a hand-maintained list and is not expanded.
    Set-AkManifest -AgentsJson '["./subagents/*.md"]'
    $ak3 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($ak3.Out -match '\[agents-key\].*subagents/\*\.md') `
        'check 38: a glob is reported -- nothing expands it, so it names no file'

    # 4. A PATH THAT ENDS IN .md AND NAMES NOTHING. Distinct from 1-3: the shape is right and the file is
    #    absent, which is what a renamed def leaves behind -- and it takes the whole install down.
    Set-AkManifest -AgentsJson '["./subagents/01-01-agent.md", "./subagents/99-99-agent.md"]'
    $ak4 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($ak4.Out -match '\[agents-key\].*99-99-agent\.md.*names no file that exists') `
        'check 38: an entry naming a missing file is reported, naming the entry'

    # 5. CONTAINMENT: a path leaving the plugin cannot travel with it, the same rule check 1 holds a
    #    marketplace source to.
    Set-AkManifest -AgentsJson '["../dkj-subagents-shopify/subagents/01-01-agent.md"]'
    $ak5 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($ak5.Out -match '\[agents-key\].*resolves outside the plugin root') `
        'check 38: an entry escaping the plugin root is reported -- what is registered here gets published'

    # 6. THE COMPLETENESS DIRECTION, and the one 'claude plugin validate' cannot reach: a correct,
    #    installable list that omits a def the plugin ships. This is the drift Dave's chosen repair
    #    (keep subagents/, list the files) is exposed to, and the reason the check exists as a gate.
    Set-AkManifest -AgentsJson '["./subagents/01-01-agent.md"]'
    $ak6 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($ak6.Out -match '\[agents-key\].*02-02-agent\.md.*no .agents. entry names it') `
        'check 38: a def the list omits is reported -- it installs fine and loads for nobody'
    Assert-True (-not ($ak6.Out -match 'does not name a \.md file|names no file that exists')) `
        'check 38: and only that finding -- the shape of the entry it DOES carry is sound'

    # 7. THE COMPLETE LIST IS CLEAN. The absence assert is anchored on the '.' that opens every finding's
    #    relative manifest path, NOT on '[agents-key]' and not on any word: that bracket also opens the
    #    coverage line this check prints on every run, so '[agents-key] <lowercase>' matches
    #    '[agents-key] checked 6 -- ...' and passes only while the check says nothing at all, itself
    #    included. Written that way first and it failed here on scenarios 7 and 9 -- the trap check 6b's
    #    scenario 3 documents, met head-on.
    Set-AkManifest -AgentsJson '["./subagents/01-01-agent.md", "./subagents/02-02-agent.md"]'
    $ak7 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($ak7.Out -match '\[agents-key\] \.')) `
        'check 38: a list naming every def, each an existing file, is clean'
    Assert-True ($ak7.Out -match "\[agents-key\] checked") `
        'check 38: and the check reports its coverage, so a silent pass cannot hide an empty scan'
    Assert-True ($ak7.Out -match "\[agents-key\] checked \d+ -- published plugin\(s\) read, [1-9]") `
        'check 38: with a non-zero entry count -- proof -SkipCheck agent-def did not narrow this check'

    # 8. NO KEY AT ALL, with defs outside agents/: #1698's defect stated as a rule. Convention discovery
    #    reads agents/ and nothing else, so these are declared by nothing -- and it reads as a clean gate.
    Set-AkManifest -AgentsJson $null
    $ak8 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($ak8.Out -match "\[agents-key\].*declares no .agents. key") `
        'check 38: no key plus defs outside agents/ is reported -- nothing discovers them'
    Assert-True ($ak8.Out -match '\[agents-key\].*2 def\(s\) outside it') `
        'check 38: and the finding counts them, so the reader knows the size of what is not loading'

    # 9. NO KEY AND THE DEFS IN agents/: the convention, and silent. This is the state the repo was in
    #    before #1698 and the one the check must never accuse -- five of six real plugins rely on the
    #    silence half of this rule.
    $akConvention = Join-Path $Fixture 'plugins\dkj-subagents\dkj-subagents-alpha\agents'
    New-Item -ItemType Directory -Path $akConvention -Force | Out-Null
    Move-Item -LiteralPath $akDefA -Destination (Join-Path $akConvention '01-01-agent.md') -Force
    Move-Item -LiteralPath $akDefB -Destination (Join-Path $akConvention '02-02-agent.md') -Force
    $ak9 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($ak9.Out -match '\[agents-key\] \.')) `
        'check 38: no key with every def under agents/ is the convention and is silent'

    # 10. A NESTED PLUGIN ROOT IS NOT ITS PARENT'S CONTENT. plugins/dkj-policy/dkj-policy-bwj really sits
    #     inside plugins/dkj-policy in this repo, and neither ships a def today -- so nothing would fire
    #     if this were wrong, which is precisely why it is exercised here rather than left to the tree.
    #     The marketplace is rewritten for this scenario and restored immediately after: every later
    #     assert in this suite reads it.
    $akMpPath = Join-Path $Fixture '.claude-plugin\marketplace.json'
    $akMpOrig = [System.IO.File]::ReadAllText($akMpPath, [System.Text.Encoding]::UTF8)
    $akChildRoot = Join-Path $Fixture 'plugins\dkj-policy\dkj-policy-bwj'
    try {
        New-Item -ItemType Directory -Path (Join-Path $akChildRoot '.claude-plugin') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $akChildRoot 'agents') -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $akChildRoot '.claude-plugin\plugin.json'),
            "{ `"name`": `"dkj-policy-bwj`", `"version`": `"0.0.1`" }`n", $Utf8NoBom)
        # The child's def sits OUTSIDE its own agents/ dir on purpose: the child must be accused and the
        # parent must not. One file separates the two readings.
        New-Item -ItemType Directory -Path (Join-Path $akChildRoot 'subagents-stray') -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $akChildRoot 'subagents-stray\03-03-agent.md'),
            "---`nname: fixture`nid: 03`ngroup: 03`n---`n`n# Child def`n", $Utf8NoBom)
        [System.IO.File]::WriteAllText($akMpPath, (@'
{
  "name": "fixture-marketplace",
  "plugins": [
    { "name": "dkj-subagents-alpha",         "source": "./plugins/dkj-subagents/dkj-subagents-alpha" },
    { "name": "dkj-subagents-shopify",       "source": "./plugins/dkj-subagents/dkj-subagents-shopify" },
    { "name": "dkj-policy", "source": "./plugins/dkj-policy" },
    { "name": "dkj-policy-bwj", "source": "./plugins/dkj-policy/dkj-policy-bwj" }
  ]
}
'@), $Utf8NoBom)
        $ak10 = Invoke-Integrity -FixtureRoot $Fixture
        Assert-True ($ak10.Out -match "\[agents-key\] \./plugins/dkj-policy/dkj-policy-bwj.*declares no .agents. key|\[agents-key\] \.\\plugins\\dkj-policy\\dkj-policy-bwj.*declares no .agents. key") `
            'check 38: the nested plugin is accused of its own stray def'
        Assert-True (-not ($ak10.Out -match "\[agents-key\] \.[\\/]plugins[\\/]dkj-policy[\\/]\.claude-plugin")) `
            'check 38: and its PARENT is not -- a nested root is not its parent content'
    } finally {
        [System.IO.File]::WriteAllText($akMpPath, $akMpOrig, $Utf8NoBom)
        Remove-Item -LiteralPath $akChildRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Back to the canonical fixture: the manifest exactly as New-IntegrityFixture wrote it, and no defs.
    [System.IO.File]::WriteAllText($akManifest, $akManifestOrig, $Utf8NoBom)
    Remove-Item -LiteralPath $akConvention -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $akSubagents -Recurse -Force -ErrorAction SilentlyContinue

    # --- -SkipCheck: the guard rails around the one parameter that can make this gate check less ------
    #     The parameter exists for THIS suite and nothing else. Its failure mode is silence -- a gate
    #     that ran fewer checks and still said "0 errors" -- so the three things that make it safe are
    #     asserted here rather than trusted: a skip announces itself, an unknown name is refused, and no
    #     production caller passes it at all.
    Write-Host "-SkipCheck: a skipped check announces itself and is never reported as 'checked 0'" -ForegroundColor Cyan
    $skipRun = Invoke-Integrity -FixtureRoot $Fixture
    foreach ($cat in @('agent-def', 'parse', 'branch-template')) {
        Assert-True ($skipRun.Out -match ("\[SKIP\]\s+" + [regex]::Escape($cat) + "\b")) `
            "-SkipCheck: '$cat' prints a [SKIP] line saying nothing was asserted about it"
        # THE ONE THAT MATTERS MOST. This gate makes an empty scan visible on purpose -- 'checked 0' is a
        # finding-shaped statement. If a skip printed that instead, a reader (and an assert) could not
        # tell "there was nothing to check" from "this check did not run".
        Assert-True (-not ($skipRun.Out -match ("\[" + [regex]::Escape($cat) + "\] checked"))) `
            "-SkipCheck: and '$cat' prints NO coverage line, so a skip cannot be misread as an empty scan"
    }

    Write-Host "-SkipCheck: an unknown check name is refused rather than ignored" -ForegroundColor Cyan
    $badSkipPath = Join-Path $Fixture 'scripts\lint\check-plugin-integrity.ps1'
    $prevEapSkip = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $badOut  = & powershell -NoProfile -ExecutionPolicy Bypass -File $badSkipPath -SkipCheck 'agentdef' 2>&1
        $badCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prevEapSkip }
    Assert-True ($badCode -ne 0) '-SkipCheck: a misspelled name fails the run instead of quietly skipping nothing'
    Assert-True ($badCode -ne 1) '-SkipCheck: and its exit code is distinct from 1, so bad usage is not read as findings'
    Assert-True ((($badOut | Out-String) -match 'not a skippable check')) '-SkipCheck: the refusal says what was wrong'
    Assert-True ((($badOut | Out-String) -match 'agent-def')) '-SkipCheck: and names the ones that ARE skippable, so the fix needs no source reading'

    Write-Host "-SkipCheck: no gate that guards main passes it" -ForegroundColor Cyan
    # A reduced gate must never run where a merge depends on it. Asserted on the callers rather than on
    # the parameter, because the parameter cannot know who invoked it -- and these three are the whole
    # set of places this script runs outside its own suite.
    foreach ($caller in @('scripts\release\open-pr.ps1', 'scripts\release\cut-release.ps1', '.github\workflows\ci.yml')) {
        $callerPath = Join-Path $RepoRoot $caller
        Assert-True (Test-Path -LiteralPath $callerPath) "-SkipCheck: $caller exists to be checked"
        if (Test-Path -LiteralPath $callerPath) {
            $callerText = [System.IO.File]::ReadAllText($callerPath, [System.Text.Encoding]::UTF8)
            Assert-True (-not ($callerText -match '-SkipCheck')) `
                "-SkipCheck: $caller runs the FULL gate -- it never reduces the check set"
        }
    }
} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Complete-IntegritySuite
