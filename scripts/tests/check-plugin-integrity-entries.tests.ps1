<#
.SYNOPSIS
    check-plugin-integrity.ps1, check 13: the entry format -- the heading levels of an unfolded entry file
    and of the folded changelog, and the declared sections inside each.

.DESCRIPTION
    The fixture, the assert helpers and Invoke-Integrity live in check-plugin-integrity-fixture.ps1,
    which also records why this suite family is more than one file. Split under #2304 (step 4): check 13b
    and the [COVERAGE] contract went to -branch-document, checks 15 and 16 to -figures.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'check-plugin-integrity-fixture.ps1')

$Fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("check-plugin-integrity-entries-$PID-$([guid]::NewGuid().ToString('n'))")

try {
    New-IntegrityFixture -Fixture $Fixture

    # --- Scenario 34: check 13, entry heading levels (this repo's own defect, four times in one day) ---
    #     An entry body used a sub-heading at the entry's own level, so the two became siblings: after the
    #     fold CHANGELOG.md carried headings with no PR number, and the release renderer split an entry on
    #     every one of them, shipping "entries" with no number, no type and no Plugins line. Rendall's lens
    #     warned about it and the warning did not stop it, which is the whole argument for a gate: the rule
    #     is exactly checkable.
    #
    #     REWRITTEN FOR THE FLAT CHANGELOG (August 5, 2026). An entry became an H2 with three named H3
    #     sections, so the forbidden levels moved up by one AND a second, new rule joined them: a heading
    #     AT the section level that is not one of the declared sections. Both halves are asserted here,
    #     and so is the case that must stay silent -- the real section headings, which the pre-flat
    #     version of this check would have reported as a defect each.
    #
    #     AND SHIFTED ONE LEVEL DEEPER AGAIN (August 26, 2026), when '## [Unreleased]' took H2 and both level
    #     pairs moved down. The levels below are COMPOSED from the lib rather than typed, which is the whole
    #     lesson of that shift for this file: a fixture that states the format in literals is a second
    #     definition of it, and the check under test reads the first one. Typed out, these headings went on
    #     describing yesterday's document while the gate judged today's.
    $s34Md = [char]0x00B7
    $s34EntryH = '#' * (Get-EntryHeadingLevel)
    $s34SectH  = '#' * (Get-EntrySectionLevel)
    $s34SubH   = '#' * ((Get-EntrySectionLevel) + 1)
    $s34Sections = @(
        "$s34SectH What does this change do?"
        ''
        'A body with a correctly demoted sub-heading.'
        ''
        "$s34SubH Tested"
        ''
        'All green.'
        ''
        "$s34SectH Significance"
        ''
        "$s34SubH Tier 0"
        ''
        'Only this repo notices.'
        ''
        'Score: 2'
        ''
        "$s34SectH Type of change"
        ''
        'Fix'
    )
    Write-Host 'check 13 -- an entry is an H3 with two named H4 sections, and a body heading may be neither' -ForegroundColor Cyan
    $s34Entry = Join-Path $Fixture 'fix-a-branch-name.md'
    $s34Good = @("$s34EntryH A fixture entry") + @('') + $s34Sections
    [System.IO.File]::WriteAllText($s34Entry, (($s34Good -join "`n") + "`n"), $Utf8NoBom)
    $r34a = Invoke-Integrity -FixtureRoot $Fixture
    # THE ASSERT THAT MATTERS MOST HERE, because the whole entry format would trip a level-only rule: the
    # declared section headings sit at the section level BY DESIGN and must be silent, while a sub-heading
    # one level deeper inside one of them is the ordinary accepted case.
    Assert-True (-not ($r34a.Out -match 'entry-heading.*fix-a-branch-name')) 'scenario 34: the declared sections plus a deeper sub-heading are accepted'
    Assert-True ($r34a.Out -match '\[entry-heading\] checked') 'scenario 34: and the entry file WAS examined -- the pass is not an empty scan'
    Assert-True ($r34a.Out -match '\[entry-heading\].*1 unfolded entry\(ies\)') 'scenario 34: an entry file at the current level is RECOGNISED as one -- the detector was pinned one level off until August 5, 2026, so this check silently judged nothing'

    # Defect one: a heading at the entry's own level inside the body. This is the old "$s34SectH Tested" defect,
    # one level up, and now the worse one -- it becomes a separate entry rather than a stray sub-heading.
    $s34Bad = @($s34Good) -replace ("^" + $s34SubH + " Tested$"), "$s34EntryH Tested"
    [System.IO.File]::WriteAllText($s34Entry, (($s34Bad -join "`n") + "`n"), $Utf8NoBom)
    $r34b = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($r34b.Out -match 'entry-heading.*fix-a-branch-name\.md:7') 'scenario 34: a heading at the entry level in a body is reported, with its line number'
    Assert-True ($r34b.Out -match 'SEPARATE entry') 'scenario 34: and the message says WHY, by naming the consequence at fold time'
    Assert-True ($r34b.Out -match 'undeclared tier 0') 'scenario 34: including what the phantom entry declares -- nothing'

    # Defect two, new with the format: a heading at the SECTION level that is not a declared section. The
    # dangerous version of this is a MISSPELLED section heading, which costs the entry its declaration
    # silently -- so the fixture uses exactly that rather than an obviously unrelated word.
    $s34Typo = @($s34Good) -replace ('^' + $s34SectH + ' Significance$'), "$s34SectH Significanse"
    [System.IO.File]::WriteAllText($s34Entry, (($s34Typo -join "`n") + "`n"), $Utf8NoBom)
    $r34c = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($r34c.Out -match 'entry-heading.*fix-a-branch-name\.md:11') 'scenario 34: a misspelled section heading is reported, with its line'
    Assert-True ($r34c.Out -match 'not one of them') 'scenario 34: and the message lists the sections that ARE declared'
    Assert-True ($r34c.Out -match 'loses that declaration') 'scenario 34: naming the silent cost rather than only the rule'

    # Defect three (issue #1367): a DECLARED section heading that appears TWICE in one entry. Both copies
    # are valid names, so the misspelling rule above says nothing -- the entry validates and every gate
    # passes, and the split only shows in a published Release body, because the fold links the LAST copy
    # while the release renderer reads the FIRST. The fixture doubles 'Significance', which is exactly the
    # shape the v4.29.0 body shipped ('#### Pull Request' twice, the linkless copy chosen).
    $s34DupSection = @($s34Good) + @('', "$s34SectH Significance", '', 'A stray second copy.')
    [System.IO.File]::WriteAllText($s34Entry, (($s34DupSection -join "`n") + "`n"), $Utf8NoBom)
    $r34c2 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($r34c2.Out -match 'entry-heading.*fix-a-branch-name\.md:23') 'scenario 34: a repeated declared section is reported, on the SECOND occurrence''s line'
    Assert-True ($r34c2.Out -match "a second 'Significance' section") 'scenario 34: and the message names which section was doubled'
    Assert-True ($r34c2.Out -match 'no PR link') 'scenario 34: naming the silent published cost, and #1367'

    # The negative that keeps this from over-firing: a repeated heading QUOTED in a fence is a mention,
    # not a use -- and this branch's own changelog entry does exactly that.
    $s34DupFenced = @(
        "$s34EntryH A fixture entry"
        ''
        "$s34SectH What does this change do?"
        ''
        'The doubled form looks like this:'
        ''
        '```markdown'
        "$s34SectH Significance"
        "$s34SectH Significance"
        '```'
        ''
        "$s34SectH Significance"
        ''
        'Score: 2'
        ''
        "$s34SectH Type of change"
        ''
        'Fix'
    )
    [System.IO.File]::WriteAllText($s34Entry, (($s34DupFenced -join "`n") + "`n"), $Utf8NoBom)
    $r34c3 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($r34c3.Out -match 'entry-heading.*fix-a-branch-name')) 'scenario 34: a duplicated section heading inside a fence is a mention, not a finding'

    # Fence-aware: an entry that QUOTES a heading is discussing structure, not creating it -- the
    # mention-versus-use question this file answers in four other checks, and one this repo's own entry
    # files do (the entry for this very change quotes the format).
    $s34Fenced = @(
        "$s34EntryH A fixture entry"
        ''
        "$s34SectH What does this change do?"
        ''
        'The wrong form looks like this:'
        ''
        '```markdown'
        "$s34EntryH Tested"
        "$s34SectH Significanse"
        '```'
        ''
        "$s34SectH Significance"
        ''
        "$s34SubH Tier 0"
        ''
        'Only this repo notices.'
        ''
        'Score: 2'
        ''
        "$s34SectH Type of change"
        ''
        'Fix'
    )
    [System.IO.File]::WriteAllText($s34Entry, (($s34Fenced -join "`n") + "`n"), $Utf8NoBom)
    $r34d = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($r34d.Out -match 'entry-heading.*fix-a-branch-name')) 'scenario 34: both fenced examples are mentions, not uses -- neither level is reported'

    # A PRE-FORMAT entry file, which is not history: an entry file lives only on a branch, so a branch
    # opened in the flat window (August 5-26, 2026) still carries the shape from then -- the entry one level
    # below the current heading -- and this repo had one parked on the remote the day the format landed. It
    # must still be RECOGNISED (line 1 is skipped whatever its level, because the fold re-levels it) while
    # its body is judged by the same rules. The heading is composed as 'entryLevel - 1' rather than typed:
    # the detector ranges DOWN from the current level since issue #1344, and a literal would pin yesterday's.
    $s34Legacy = @(
        ('#' * ((Get-EntryHeadingLevel) - 1)) + " An older entry " + $s34Md + ' Fix ' + $s34Md + ' 2026-08-01'
        ''
        'Body prose.'
        ''
        "$s34EntryH Not allowed here either"
    )
    [System.IO.File]::WriteAllText($s34Entry, (($s34Legacy -join "`n") + "`n"), $Utf8NoBom)
    $r34e = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($r34e.Out -match '\[entry-heading\].*1 unfolded entry\(ies\)') 'scenario 34: a pre-format flat-window entry file is still recognised as an entry file'
    Assert-True ($r34e.Out -match 'entry-heading.*fix-a-branch-name\.md:5') 'scenario 34: and its body is judged by the same rules'
    Assert-True (-not ($r34e.Out -match 'fix-a-branch-name\.md:1')) 'scenario 34: while its own heading on line 1 is NOT reported -- that is the entry, and the fold re-levels it'
    Remove-Item -LiteralPath $s34Entry -Force

    # The CHANGELOG half, which is what cut-release actually parses -- and the half that catches damage
    # arriving through the fold, the one write that happens directly on main past every PR gate.
    $s34Cl = Join-Path $Fixture 'dkj-policy\CHANGELOG.md'
    $s34ClGood = @(
        '# Changelog'
        ''
        'Everything merged since the last release, furthest reach first.'
        ''
        "$s34EntryH #123 " + $s34Md + ' A real entry'
        ''
    ) + $s34Sections + @('')
    [System.IO.File]::WriteAllText($s34Cl, (($s34ClGood -join "`n") + "`n"), $Utf8NoBom)
    $r34f = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($r34f.Out -match 'entry-heading. CHANGELOG')) 'scenario 34: a well-formed flat changelog is silent'

    # AND SO IS A STAMPED 'Pull Request' HEADING, which is what the fold actually writes into this file
    # (August 19, 2026). This gate compares the whole captured heading text against the declared names, so
    # while it was anchored on a bare '\s*$' the stamp made a declared section unrecognisable -- and the
    # error would have landed HERE, on the one write that happens directly on main past every PR gate,
    # inside the required CI check. Every PR after the first fold would have been blocked by the fold of
    # the one before it. The scenario is the fold's own output rather than a hand-built line, because that
    # is the shape nobody would have thought to type.
    $s34ClStamped = @($s34ClGood) + @(
        "$s34SectH Pull Request " + $s34Md + ' 20260819-171500'
        ''
        '[PR #123](https://gh.test/pr/123)'
        ''
    )
    [System.IO.File]::WriteAllText($s34Cl, (($s34ClStamped -join "`n") + "`n"), $Utf8NoBom)
    $r34f2 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($r34f2.Out -match 'entry-heading. CHANGELOG')) 'scenario 34: a folded entry whose Pull Request heading carries the landing stamp is accepted'
    Assert-True ($r34f2.Out -match '\[entry-heading\] checked') 'scenario 34: and the file WAS examined -- the pass is not an empty scan'

    # THE TOLERANCE IS THE STAMP, NOT THE NAME. A misspelling still has to be caught: this is the failure
    # the exact comparison exists for, and a tail that swallowed anything after the name would have traded
    # one silent defect for another.
    $s34ClMisspelled = @($s34ClStamped) -replace ("^" + $s34SectH + " Pull Request "), "$s34SectH Pull request "
    [System.IO.File]::WriteAllText($s34Cl, (($s34ClMisspelled -join "`n") + "`n"), $Utf8NoBom)
    $r34f3 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($r34f3.Out -match 'entry-heading. CHANGELOG') 'scenario 34: a MISSPELLED section heading is still reported, stamp or no stamp'
    Assert-True ($r34f3.Out -match "'Pull request'") 'scenario 34: and the message quotes the name without the stamp, which is the part to correct'

    [System.IO.File]::WriteAllText($s34Cl, (($s34ClGood -join "`n") + "`n"), $Utf8NoBom)

    # A body sub-heading written at the entry's own level, in the middle of a formatted entry. It SPLITS the
    # entry: the three sections land across two blocks, so the phantom's first section is whichever one
    # followed it -- never the first. That is the rule, and it is structural rather than a guess about intent.
    $s34ClStray = @($s34ClGood) -replace ("^" + $s34SubH + " Tested$"), "$s34EntryH Tested"
    [System.IO.File]::WriteAllText($s34Cl, (($s34ClStray -join "`n") + "`n"), $Utf8NoBom)
    $r34g = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($r34g.Out -match 'entry-heading. CHANGELOG\.md:11') 'scenario 34: a body heading at the entry level is reported, with its line'
    Assert-True ($r34g.Out -match 'has been SPLIT') 'scenario 34: and the message names what happened to the entry rather than only the rule'
    Assert-True ($r34g.Out -match "first named section is 'Significance'") 'scenario 34: quoting the section it starts at, which is the evidence'

    # A DECLARED SECTION REPEATED WITHIN ONE ENTRY, arriving through the fold (issue #1367). This is the
    # half that catches a doubled section on the one write that lands directly on main, past every PR
    # gate -- the v4.29.0 case, where '#### Pull Request' folded in twice and the Release body took the
    # linkless copy. The fixture doubles 'Significance'.
    $s34ClDup = @($s34ClGood) + @("$s34SectH Significance", '', 'A stray second copy of a section.')
    [System.IO.File]::WriteAllText($s34Cl, (($s34ClDup -join "`n") + "`n"), $Utf8NoBom)
    $r34g2 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($r34g2.Out -match 'entry-heading. CHANGELOG\.md:27') 'scenario 34: a repeated declared section in a folded entry is reported, on the second occurrence'
    Assert-True ($r34g2.Out -match "a second 'Significance' section in this H") 'scenario 34: and the message names the doubled section and #1367'

    # THE NEGATIVE THAT SCOPES IT: the SAME section name in two DIFFERENT entries is the norm, not a
    # duplicate -- the check resets per entry. Two well-formed entries, each with its own three sections.
    $s34ClTwo = @(
        '# Changelog'
        ''
        'Everything merged since the last release, furthest reach first.'
        ''
        "$s34EntryH #123 " + $s34Md + ' First entry'
        ''
    ) + $s34Sections + @('') + @(
        "$s34EntryH #124 " + $s34Md + ' Second entry'
        ''
    ) + $s34Sections + @('')
    [System.IO.File]::WriteAllText($s34Cl, (($s34ClTwo -join "`n") + "`n"), $Utf8NoBom)
    $r34g3 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($r34g3.Out -match 'entry-heading. CHANGELOG')) 'scenario 34: one section name per entry across two entries is not a duplicate -- the scan is per entry'

    [System.IO.File]::WriteAllText($s34Cl, (($s34ClGood -join "`n") + "`n"), $Utf8NoBom)

    # THE FALSE POSITIVE THIS AVOIDS, and it is the reason the rule is not simply "an entry heading needs a
    # #NN": the fold cannot reach gh on a manual merge, and then it writes a legitimate entry with no number
    # and no PR footer, saying so on the console. Keying on the number would report the fold's own
    # documented output as a defect.
    #
    # THE LEVEL IS COMPOSED HERE TOO, and it was a typed '^## ' until this line was swept: after the
    # August 26, 2026 shift the pattern matched nothing, so this scenario re-tested the untouched good
    # fixture and passed by asserting the assert two blocks up. The same lesson the block at the top of
    # this scenario draws, in the one place it was not applied.
    $s34ClNoPr = @($s34ClGood) -replace ('^' + $s34EntryH + ' #123 ' + [regex]::Escape($s34Md) + ' A real entry$'), "$s34EntryH A real entry with no PR number"
    [System.IO.File]::WriteAllText($s34Cl, (($s34ClNoPr -join "`n") + "`n"), $Utf8NoBom)
    $r34h = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($r34h.Out -match 'entry-heading. CHANGELOG')) 'scenario 34: an entry with no PR number but with its sections is accepted -- the manual-merge fold'

    # A PRE-FORMAT entry, which is the second legitimate shape: no sections at all, the type carried as a
    # heading field. Every entry this repo folded before August 5, 2026 looks like this, and so does anything
    # folded from a branch that predates the format -- so reporting it would fire on real history.
    $s34ClLegacy = @(
        '# Changelog'
        ''
        'Intro.'
        ''
        "$s34EntryH #99 " + $s34Md + ' An entry from before the format ' + $s34Md + ' Fix ' + $s34Md + ' 2026-08-01'
        ''
        'Body prose, no named sections.'
        ''
        "$s34SubH A properly demoted sub-heading"
        ''
        'More prose.'
        ''
    )
    [System.IO.File]::WriteAllText($s34Cl, (($s34ClLegacy -join "`n") + "`n"), $Utf8NoBom)
    $r34k = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($r34k.Out -match 'entry-heading. CHANGELOG')) 'scenario 34: a pre-format entry declaring its type in the heading is accepted -- no sections required of it'

    # THE PLACEMENT NEITHER RULE CATCHES ALONE, and the reason the check has two: a stray heading directly
    # BELOW the entry heading keeps all three sections in its own block, so the first rule sees a well-formed
    # entry. What gives it away is the entry ABOVE it, now sectionless -- and a current-format heading carries
    # no type field, so the type rule reports that one. The error lands on the real entry rather than on the
    # stray, which is why the message names both possibilities instead of asserting which it found.
    $s34ClAbsorbed = @(
        '# Changelog'
        ''
        'Intro.'
        ''
        "$s34EntryH #123 " + $s34Md + ' A real entry'
        ''
        "$s34EntryH A sub-heading that swallowed the entry"
        ''
    ) + $s34Sections + @('')
    [System.IO.File]::WriteAllText($s34Cl, (($s34ClAbsorbed -join "`n") + "`n"), $Utf8NoBom)
    $r34l = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($r34l.Out -match 'entry-heading. CHANGELOG\.md:5') 'scenario 34: a stray heading directly below an entry heading is caught via the entry it emptied'
    Assert-True ($r34l.Out -match 'declares neither its named sections nor a change type') 'scenario 34: and the message states exactly what is missing'
    Assert-True ($r34l.Out -match 'absorbed by such a heading directly below it') 'scenario 34: naming the second possibility, since the error lands on the victim rather than the cause'

    # An H1 below the intro, and a stray section-level heading, in one document -- so the assert on the
    # second one also proves the scan did not stop at the first. The pre-flat check keyed its boundary on a
    # heading NAME and had to reason carefully about not ending the scan at the very defect it looked for;
    # the boundary is structural now, so the scan simply runs to the end of the file.
    $s34ClMixed = @(
        '# Changelog'
        ''
        'Intro.'
        ''
        "$s34EntryH #123 " + $s34Md + ' A real entry'
        ''
        "$s34SectH What does this change do?"
        ''
        '# A body heading that climbs above every entry'
        ''
        "$s34SectH Tested"
        ''
        "$s34SectH Type of change"
        ''
        'Fix'
        ''
    )
    [System.IO.File]::WriteAllText($s34Cl, (($s34ClMixed -join "`n") + "`n"), $Utf8NoBom)
    $r34i = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($r34i.Out -match 'entry-heading. CHANGELOG\.md:9') 'scenario 34: an H1 below the intro is reported'
    Assert-True ($r34i.Out -match 'climbs above every entry') 'scenario 34: and the message names the consequence in the document'
    Assert-True ($r34i.Out -match 'entry-heading. CHANGELOG\.md:11') 'scenario 34: and the stray section heading AFTER it is still reported -- the scan did not stop'

    # A changelog with no entry at all is the normal state between a release and the next merge: not judged
    # and not an error. Stated as an assert because "reports nothing" and "found nothing to report" look
    # identical from the outside, and the coverage line is what distinguishes them.
    [System.IO.File]::WriteAllText($s34Cl, "# Changelog`n`nNothing merged since the last release.`n", $Utf8NoBom)
    $r34j = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($r34j.Out -match 'entry-heading. CHANGELOG')) 'scenario 34: an entry-less changelog is not an error -- that is the state right after a release'
    Remove-Item -LiteralPath $s34Cl -Force

    # RETIRED, AUGUST 8, 2026 -- check 17's scenarios 33-37, with the check itself. They held the four
    # per-plugin CHANGELOG intros against Build-PluginChangelogIntro, which was the right repair for a
    # real defect: the intro was write-once, so all four kept naming a retired marketplace. The files
    # are gone -- a consumer already receives the root CHANGELOG.md through the marketplace clone -- so
    # there is no second copy left to hold against a generator.
} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Complete-IntegritySuite
