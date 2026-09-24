<#
.SYNOPSIS
    check-plugin-integrity.ps1, the consumer-document checks: a named consumer-facing document that
    is not there (19), a claimed section COUNT against the scaffolder's (20), the changelog intro's
    scope (20b), the branch document's exemption by pattern (20c), and a consumer document that
    misroutes its own reader (25).

    The fixture, the assert helpers and Invoke-Integrity live in check-plugin-integrity-fixture.ps1,
    which also records why this suite family is more than one file.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'check-plugin-integrity-fixture.ps1')

# CHECK-REPORT-LIB INTO THE RUNNER TOO, for check 3d's scenarios: they compose the lens file names from
# Get-SpecialistFileName and Get-SpecialistFileNameCandidates rather than typing them. Same reason the
# fixture dot-sources entry-scaffold-lib and pr-body-lib, and through the $...Src path it already
# resolves for the copy -- a name typed here would be a second definition of the very shape the check
# under test holds, and it would pass on the day the row and the files come apart, which IS the defect
# (#2168).
. $CheckReportLibSrc

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

    # --- check 19: a named consumer-facing document that is not there ------------------------------
    # 42. THE SILENT-COVERAGE CASE. Checks 15 and 16 open each $consumerDocs entry with a Test-Path
    #     'continue', so a stale entry costs coverage and says nothing. Measured August 6, 2026, moving
    #     those documents into plugins/: expected-output went 5 -> 1 and measured-figure 11 -> 0 in one
    #     commit, no error anywhere, and it surfaced only because somebody read the coverage line.
    #     The fixture never creates plugins/ADOPTION.md, so the entry is genuinely absent here.
    $s4 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($s4.Out -match '\[consumer-doc\].*ADOPTION\.md') `
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

    # --- check 20c: the BRANCH's own document is exempt by pattern, its folder's pages are not -------
    # ISSUE #2180. The exclusion was a list built from a branch-less Get-BranchFilePaths, which answers the
    # pre-#1255 SHARED name -- so from the day the documents went per branch it named a file that no longer
    # exists, while $linkFiles went on sweeping the folder recursively. Here the failure direction is NOISE:
    # a branch document that quotes a section count while EXPLAINING the entry format is reported as stale
    # prose and fails the gate. No branch document has triggered it yet, and the scaffold misses it on TWO
    # independent counts rather than the one #2180 named: its sentence says 'HEADINGS' where the pattern
    # wants 'section', AND it carries the PHASE level (three hashes, Get-EntryHeadingLevel) where the
    # pattern wants the SECTION level (four, Get-EntrySectionLevel). Either alone is enough to miss, so a
    # reword on its own would not start the noise -- which is why the fixture writes the triggering
    # sentence by hand instead of leaning on the scaffold to keep missing it.
    #
    # THREE FILES, ONE GATE RUN, and both halves of that are deliberate.
    #
    # THREE, because a branch document going silent on its own reads the same whether it was excluded or
    # never swept. The folder's own README is a ReservedName, so the predicate answers false for it and it
    # is still checked -- carrying the identical sentence, it proves in the same output that the sweep
    # reaches this folder and that the exemption is per file rather than per folder. The third is a LEGACY
    # name, which pins that the fixed list was KEPT beside the predicate rather than replaced by it. It has
    # to come from the branch/ pair to mean that: the pre-#1255 SHARED name sits in the folder itself and so
    # matches the pattern too, which would let the assert pass against a repair that dropped the list
    # entirely. The branch/ pair is one directory down, where the predicate's own anchor cannot reach --
    # measured, Test-IsPerBranchDocumentPath answers false for it. A branch opened before that rename still
    # carries one, here and in every consumer, and meets this change through a plugin update rather than by
    # choosing to.
    #
    # ONE RUN, because each Invoke-Integrity spawns the whole gate against the fixture and this suite is the
    # test gate's critical path -- 83 such calls before this block, so a scenario per fact would have cost
    # the required check two spawns instead of one for no added proof. The check is evaluated per file, so
    # one report answers for all three, and every assert here is ANCHORED ON ITS OWN PATH rather than on the
    # output being silent -- which is what makes them independent inside a shared report, and is stricter
    # than a blanket absence check besides.
    Write-Host "check 20c: the branch document is exempt, the folder's own pages are not" -ForegroundColor Cyan
    $shapeStale   = "An entry is one $docEntryH heading with three named $docSectH sections under it."
    $shapeBranch  = Join-Path $Fixture 'dkj-policy\fix-2180-demo.md'
    $shapeFolderR = Join-Path $Fixture 'dkj-policy\README.md'
    $shapeLegacy  = Join-Path $Fixture ((Get-BranchFilePaths).LegacyCycle -replace '/', '\')

    # 51. All three in one run: the branch document silent, the folder's own page reported, the legacy name
    #     silent. The parent of the legacy name is created here rather than borrowed from check 20's block
    #     above, which happens to leave it behind -- an ordering dependency would fail as a raw
    #     DirectoryNotFoundException rather than as a readable assert the day those blocks move.
    New-Item -ItemType Directory -Path (Split-Path -Parent $shapeLegacy) -Force | Out-Null
    [System.IO.File]::WriteAllText($shapeBranch, "## fix/2180-demo`n`n$shapeStale`n", $Utf8NoBom)
    [System.IO.File]::WriteAllText($shapeFolderR, "# dkj-policy`n`n$shapeStale`n", $Utf8NoBom)
    [System.IO.File]::WriteAllText($shapeLegacy, "## feat/old-branch`n`n$shapeStale`n", $Utf8NoBom)
    $e8 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($e8.Out -match '\[entry-shape\] dkj-policy[\\/]fix-2180-demo\.md')) `
        'entry-shape: the branch''s OWN document is exempt by pattern, not by the retired shared name (#2180)'
    Assert-True ($e8.Out -match '\[entry-shape\] dkj-policy[\\/]README\.md:3: says an entry has 3') `
        'entry-shape: and the same sentence in the folder''s own page IS reported, so the sweep does reach here'
    Assert-True (-not ($e8.Out -match '\[entry-shape\] dkj-policy[\\/]branch[\\/]branch-cycle\.md')) `
        'entry-shape: a legacy branch-file name is still exempt -- the fixed list was kept, not swapped out'
    Remove-Item -LiteralPath $shapeBranch, $shapeFolderR, $shapeLegacy -Force

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

} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Complete-IntegritySuite
