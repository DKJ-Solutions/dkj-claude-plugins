<#
.SYNOPSIS
    check-plugin-integrity.ps1, the marketplace-wide skill spans: check 10 (the marked
    <!-- skills:all --> spans), plus scenario 16 -- a root entry file is scanned before the fold.

.DESCRIPTION
    The fixture, the assert helpers and Invoke-Integrity live in check-plugin-integrity-fixture.ps1,
    which also records why this suite family is more than one file. Split out of -links under #2304.

    Check 10's sixteen scenarios cover the span mechanics, the fence masking in both directions, and the
    two symmetric sweeps -- the orphan END, and (since August 26, 2026, scenario 14b) the nested BEGIN
    that used to pair across an open span in silence. Its plugin-scoped sibling, check 29, lives in
    -plugin-spans, and the marker mechanics proven here are the ones that suite restages only where its
    reading differs.

    Scenario 16 asserts check 4 and check 10 together on one entry file. It sits here rather than beside
    check 4 because the case that produced it (#234) was the quoted marker.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'check-plugin-integrity-fixture.ps1')

$Fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("check-plugin-integrity-skill-spans-$PID-$([guid]::NewGuid().ToString('n'))")

try {
    New-IntegrityFixture -Fixture $Fixture
    # The root documents as check 4's scenario B leaves them -- see Write-QuietRootDocuments for why this
    # suite states that starting point instead of inheriting it from a scenario in another file.
    Write-QuietRootDocuments -Fixture $Fixture

    # === check 10: marked "all skills" enumerations vs. the canonical skillset ==========================
    # Only CONTRIBUTING.md's content is varied per scenario. The connectors README is left exactly as
    # Write-QuietRootDocuments wrote it above (marker-free), so it never contributes a
    # <!-- skills:all --> span of its own -- keeping every assertion below attributable to
    # CONTRIBUTING.md alone.
    #
    # NOTE: the "[skill-list]" tag prefixes BOTH the error lines and the informational
    # "checked N span(s) against M canonical skill(s)" pass-line -- so "no finding" assertions must
    # match on an actual error phrase, not on the bare "[skill-list]" tag (which is always present
    # once at least one span exists).
    $SkillListFindingPattern = '\[skill-list\].*(is missing:|not a known skill:|has no matching)'

    # --- Scenario 1: a complete marked span passes. The canonical-skill count printed in the info
    # line doubles as proof that the depth-decoy SKILL.md is NOT counted as a 3rd canonical skill --
    Write-Host "check 10 -- a complete <!-- skills:all --> span passes" -ForegroundColor Cyan
    $s1Lines = @(
        '# Contributing'
        ''
        '<!-- skills:all -->'
        '- `skill-alpha`'
        '- `skill-beta`'
        '<!-- /skills:all -->'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s1Lines -join "`n") + "`n"), $Utf8NoBom)

    $r1 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($r1.Out -match $SkillListFindingPattern)) 'scenario 1: a complete span reports no [skill-list] finding'
    Assert-True ($r1.Out -match [regex]::Escape('checked 1 <!-- skills:all --> span(s) against 2 canonical skill(s)')) 'scenario 1: canonical set is exactly 2 -- the depth-decoy SKILL.md was not counted as a 3rd'

    # --- Scenario 2: a span missing a canonical skill name fails, naming it --------------------------
    Write-Host "check 10 -- a span missing a canonical skill name fails" -ForegroundColor Cyan
    $s2Lines = @(
        '# Contributing'
        ''
        '<!-- skills:all -->'
        '- `skill-alpha`'
        '<!-- /skills:all -->'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s2Lines -join "`n") + "`n"), $Utf8NoBom)

    $r2 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($r2.Out -match '\[skill-list\].*is missing: skill-beta') 'scenario 2: the missing skill-beta is named in the finding'

    # --- Scenario 3: a span naming something that is not a skill fails -------------------------------
    Write-Host "check 10 -- a span naming a non-skill fails" -ForegroundColor Cyan
    $s3Lines = @(
        '# Contributing'
        ''
        '<!-- skills:all -->'
        '- `skill-alpha`'
        '- `skill-beta`'
        '- `not-a-real-skill`'
        '<!-- /skills:all -->'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s3Lines -join "`n") + "`n"), $Utf8NoBom)

    $r3 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($r3.Out -match '\[skill-list\].*not a known skill: not-a-real-skill') 'scenario 3: the unknown name not-a-real-skill is named in the finding'

    # --- Scenario 4: an unpaired BEGIN marker (no matching END) is a hard error ----------------------
    Write-Host "check 10 -- an unpaired BEGIN marker fails" -ForegroundColor Cyan
    $s4Lines = @(
        '# Contributing'
        ''
        '<!-- skills:all -->'
        '- `skill-alpha`'
        '- `skill-beta`'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s4Lines -join "`n") + "`n"), $Utf8NoBom)

    $r4 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($r4.Out -match [regex]::Escape("has no matching '<!-- /skills:all -->'")) 'scenario 4: the unpaired BEGIN marker is reported'

    # --- Scenario 5: TWO unpaired BEGIN markers in the SAME file -- BOTH must be reported. Regression
    # guard: an earlier version used 'break' on the first unpaired marker and silently abandoned the
    # rest of the file, so a second, later problem in the same doc went unnoticed. The fix continues
    # scanning past a malformed marker instead of bailing out of the whole file.
    Write-Host "check 10 -- two unpaired BEGIN markers in one file are BOTH reported" -ForegroundColor Cyan
    $s5Lines = @(
        '# Contributing'
        ''
        '<!-- skills:all -->'
        '- `skill-alpha`'
        ''
        'Some unrelated paragraph in between.'
        ''
        '<!-- skills:all -->'
        '- `skill-beta`'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s5Lines -join "`n") + "`n"), $Utf8NoBom)

    $r5 = Invoke-Integrity -FixtureRoot $Fixture
    $unpairedHits = [regex]::Matches($r5.Out, [regex]::Escape("has no matching '<!-- /skills:all -->'"))
    Assert-Equal 2 $unpairedHits.Count 'scenario 5: both unpaired BEGIN markers are reported, not just the first (no break-and-abandon regression)'

    # --- Scenario 6: an UNMARKED, deliberately incomplete enumeration must NOT fail. This is the
    # whole reason check 10 is opt-in rather than a generic prose scan: a real doc (e.g.
    # QUICKSTART.md) legitimately lists only SOME skills as illustration, without ever claiming to be
    # exhaustive, and must not be flagged just because it happens to under-enumerate.
    Write-Host "check 10 -- an unmarked, deliberately incomplete list is NOT flagged" -ForegroundColor Cyan
    $s6Lines = @(
        '# Contributing'
        ''
        'Here is one skill, for illustration only (this list is not exhaustive):'
        '- `skill-alpha`'
        ''
        "That's not all of them."
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s6Lines -join "`n") + "`n"), $Utf8NoBom)

    $r6 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($r6.Out -match $SkillListFindingPattern)) 'scenario 6: an unmarked, incomplete list reports no [skill-list] finding'
    Assert-True ($r6.Out -match [regex]::Escape('0 <!-- skills:all --> span(s) found')) 'scenario 6: zero spans found across the fixture -- opt-in, so this is a pass'

    # --- Scenario 7: an INLINE span in running prose -- backtick terms OUTSIDE the span that are not
    # skill names must not be flagged. Mirrors the real family-README sentence (the three
    # *-sessioncheck hook names sit one line above the skill enumeration, outside its span).
    Write-Host "check 10 -- an inline span in prose ignores backtick terms outside it" -ForegroundColor Cyan
    $s7Lines = @(
        '# Contributing'
        ''
        'Session hooks `connector-sessioncheck`, `roster-sessioncheck`, and `script-contract-sessioncheck` run at session start.'
        'Only the skills (<!-- skills:all -->`skill-alpha`, `skill-beta`<!-- /skills:all -->) remain available there.'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s7Lines -join "`n") + "`n"), $Utf8NoBom)

    $r7 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($r7.Out -match $SkillListFindingPattern)) 'scenario 7: hook names outside the inline span are not treated as claimed skill names'

    # --- Scenario 8: the depth-decoy SKILL.md (skills/<name>/references/SKILL.md) is not part of the
    # canonical skillset -- naming it inside a span is reported as an unknown name, proving it was
    # never picked up as a real skill in the first place (the flip side of scenario 1's count check).
    Write-Host "check 10 -- a SKILL.md nested one level too deep is not a canonical skill" -ForegroundColor Cyan
    $s8Lines = @(
        '# Contributing'
        ''
        '<!-- skills:all -->'
        '- `skill-alpha`'
        '- `skill-beta`'
        '- `skill-deep-decoy`'
        '<!-- /skills:all -->'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s8Lines -join "`n") + "`n"), $Utf8NoBom)

    $r8 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($r8.Out -match '\[skill-list\].*not a known skill: skill-deep-decoy') 'scenario 8: the depth decoy skill-deep-decoy is reported as unknown -- it was never in the canonical set'

    # --- Scenario 9: a complete marker EXAMPLE inside a fenced ```-code block -- reports nothing, AND
    # does not count in the span total. Asserting the count (not just "no error") is the point: it is
    # the proof the example is genuinely invisible to the scan, not "seen, checked, and happened to
    # pass" -- see Get-FenceMaskedText in the real script (added because a literal marker example in
    # a doc, e.g. Tessa's convention writeup, would otherwise itself be read as a live span).
    Write-Host "check 10 -- a fenced marker EXAMPLE is invisible to the scan (not counted)" -ForegroundColor Cyan
    $s9Lines = @(
        '# Contributing'
        ''
        'Here is how you show the marker literally:'
        ''
        '```'
        '<!-- skills:all -->'
        '- `skill-alpha`'
        '- `skill-beta`'
        '<!-- /skills:all -->'
        '```'
        ''
        'End of example.'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s9Lines -join "`n") + "`n"), $Utf8NoBom)

    $r9 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($r9.Out -match $SkillListFindingPattern)) 'scenario 9: a fenced marker example reports no [skill-list] finding'
    Assert-True ($r9.Out -match [regex]::Escape('0 <!-- skills:all --> span(s) found')) 'scenario 9: the fenced example is not counted as a span at all -- proves it is invisible, not merely passing'

    # --- Scenario 10: a fence containing ONLY the BEGIN marker, with no '<!-- /skills:all -->'
    # ANYWHERE ELSE in the file either -- must NOT raise "has no matching END". This is exactly the
    # case that gave a hard error before the fence-masking fix (the reason for the change): a fenced
    # BEGIN-only example used to be indistinguishable from a genuinely malformed live marker.
    Write-Host "check 10 -- a fenced BEGIN-only example (no END anywhere) is NOT an unpaired-marker error" -ForegroundColor Cyan
    $s10Lines = @(
        '# Contributing'
        ''
        'Example of just the opening marker:'
        ''
        '```'
        '<!-- skills:all -->'
        '```'
        ''
        '(no matching end anywhere in this file)'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s10Lines -join "`n") + "`n"), $Utf8NoBom)

    $r10 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($r10.Out -match $SkillListFindingPattern)) 'scenario 10: a fenced BEGIN-only example reports no "has no matching END" error'
    Assert-True ($r10.Out -match [regex]::Escape('0 <!-- skills:all --> span(s) found')) 'scenario 10: the masked BEGIN inside the fence never becomes a span (not even an unpaired one)'

    # --- Scenario 11: a REAL span OUTSIDE a fence, in the SAME file as a fenced example -- still
    # checked normally, and its reported LINE NUMBER matches the actual line. The line number is the
    # crux of the masking approach (same length + same newline positions as the original) -- if
    # someone ever swaps the mask for a cut/splice, this assert is designed to break.
    Write-Host "check 10 -- a real span outside a fence is still checked, with the correct line number" -ForegroundColor Cyan
    $s11Lines = @(
        '# Contributing'                             # line 1
        ''                                             # line 2
        'Example of the marker (not a live span):'    # line 3
        ''                                             # line 4
        '```'                                          # line 5
        '<!-- skills:all -->'                          # line 6
        '- `something`'                                # line 7
        '<!-- /skills:all -->'                          # line 8
        '```'                                          # line 9
        ''                                             # line 10
        'Real usage below:'                            # line 11
        ''                                             # line 12
        '<!-- skills:all -->'                          # line 13
        '- `skill-alpha`'                              # line 14
        '<!-- /skills:all -->'                          # line 15
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s11Lines -join "`n") + "`n"), $Utf8NoBom)

    $r11 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($r11.Out -match [regex]::Escape('span at line 13 is missing: skill-beta')) 'scenario 11: the real span outside the fence is checked, and reports the correct line (13)'
    Assert-True (-not ($r11.Out -match 'not a known skill: something')) 'scenario 11: the fenced examples "something" never surfaces as an unknown-skill finding -- it is masked, not scanned'
    Assert-True ($r11.Out -match [regex]::Escape('checked 1 <!-- skills:all --> span(s) against 2 canonical skill(s)')) 'scenario 11: only the real span is counted -- the fenced example contributes 0'

    # --- Scenario 12 (deliberate-boundary lock, not a bug guard): a marker written as INLINE code
    # (single backticks, not a fence) is NOT masked and IS still scanned as a live span. Sylvester's
    # documented trade-off: a real span's own claimed skill names are themselves single-backtick
    # delimited, so there is no character-level way to tell "this pair of backticks is an inline-code
    # escape" from "this pair of backticks is a claimed skill name" -- masking inline code would erase
    # genuine findings along with any escaped example. Fixing this assert to expect silence later
    # would mean someone changed that boundary without discussing it first.
    Write-Host "check 10 -- a marker in INLINE code (not a fence) is still scanned as live (deliberate boundary)" -ForegroundColor Cyan
    $s12Lines = @(
        '# Contributing'                                                # line 1
        ''                                                                # line 2
        'Inline example (not fenced): `<!-- skills:all -->`'             # line 3
        '- `skill-alpha`'                                                  # line 4
        '`<!-- /skills:all -->`'                                           # line 5
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s12Lines -join "`n") + "`n"), $Utf8NoBom)

    $r12 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($r12.Out -match [regex]::Escape('span at line 3 is missing: skill-beta')) 'scenario 12: a marker inside single-backtick inline code is still read as a live span (deliberately not masked)'

    # --- Scenario 13: a LONE orphan END, with no BEGIN anywhere in the file -- a hard error, with the
    # correct line number. Victor's finding: the original check-10 only guarded BEGIN-without-END; an
    # orphan or duplicate END vanished silently. This is the symmetric counterpart of scenario 4.
    Write-Host "check 10 -- a lone orphan END (no BEGIN anywhere) fails" -ForegroundColor Cyan
    $s13Lines = @(
        '# Contributing'                              # line 1
        ''                                              # line 2
        '<!-- /skills:all -->'                          # line 3
        ''                                              # line 4
        'No begin marker anywhere in this file.'        # line 5
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s13Lines -join "`n") + "`n"), $Utf8NoBom)

    $r13 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($r13.Out -match [regex]::Escape("'<!-- /skills:all -->' at line 3 has no matching '<!-- skills:all -->'")) 'scenario 13: the lone orphan END is reported, with the correct line number'

    # --- Scenario 14 (the important one): a SECOND END pasted inside an already-open, otherwise real
    # span -- exactly the copy-paste mistake that used to go silently, dangerously GREEN: the span
    # closed early at the first END, the rest of the enumeration became unchecked prose, the surplus
    # END vanished, and the check reported "checked 1 span" after only checking half of it. Two
    # things must both be true now: the truncated span reports its now-missing name (proof it closed
    # early), AND the surplus END is reported separately, on its own line.
    Write-Host "check 10 -- a second END pasted inside a real span is caught, not silently swallowed" -ForegroundColor Cyan
    $s14Lines = @(
        '# Contributing'                              # line 1
        ''                                              # line 2
        '<!-- skills:all -->'                          # line 3
        '- `skill-alpha`'                                # line 4
        '<!-- /skills:all -->'                          # line 5
        '<!-- /skills:all -->'                          # line 6 -- copy-paste duplicate
        '- `skill-beta`'                                 # line 7 -- now just prose, outside the span
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s14Lines -join "`n") + "`n"), $Utf8NoBom)

    $r14 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($r14.Out -match [regex]::Escape('span at line 3 is missing: skill-beta')) 'scenario 14: the span closed early at the first END -- skill-beta (now outside it) is reported missing'
    Assert-True ($r14.Out -match [regex]::Escape("'<!-- /skills:all -->' at line 6 has no matching '<!-- skills:all -->'")) 'scenario 14: the surplus second END is reported separately, on its own line'

    # --- Scenario 14b: the MIRROR of 14 -- a second BEGIN pasted INSIDE an already-open span. Silent
    # here from the day this check shipped, and for the same structural reason 14 describes facing the
    # other way: the walk jumps from a span's opener straight past its END, so a BEGIN in between is
    # never visited and the span simply pairs across it. Found on August 26, 2026 by walking into it on
    # check 29's branch, where the marker was written in prose above a real span and the run came out
    # GREEN -- the prose BEGIN had paired with the real END, swallowing the real BEGIN and checking the
    # whole table as one span. A pass for the wrong reason is worse than a finding, so both halves are
    # asserted: the nested BEGIN is reported, AND the enumeration it swallowed is still checked (one
    # span, not two, and no spurious missing name).
    Write-Host "check 10 -- a second BEGIN pasted inside a real span is caught, not silently swallowed" -ForegroundColor Cyan
    $s14bLines = @(
        '# Contributing'                                # line 1
        ''                                              # line 2
        '<!-- skills:all -->'                           # line 3
        '- `skill-alpha`'                               # line 4
        '<!-- skills:all -->'                           # line 5 -- nested, opens nothing
        '- `skill-beta`'                                # line 6
        '<!-- /skills:all -->'                          # line 7
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s14bLines -join "`n") + "`n"), $Utf8NoBom)

    $r14b = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($r14b.Out -match [regex]::Escape("'<!-- skills:all -->' at line 5 sits INSIDE an already-open span")) 'scenario 14b: the nested second BEGIN is reported, with the correct line number'
    Assert-True (-not ($r14b.Out -match '\[skill-list\].*is missing:')) 'scenario 14b: and the swallowed enumeration was still checked as one span -- no spurious missing name. Anchored on the tag, not on the bare phrase: [shared-script] says "source is missing:" too, and an unanchored assert fails on it'
    Assert-True ($r14b.Out -match [regex]::Escape('checked 1 <!-- skills:all --> span(s)')) 'scenario 14b: exactly one span, not two -- the nested BEGIN opened nothing'

    # --- Scenario 15: an END inside a code fence -- no error. Proves the masking is symmetric: a
    # fenced END is exactly as invisible to the sweep as a fenced BEGIN was in scenario 9/10.
    Write-Host "check 10 -- an END inside a code fence is invisible too (symmetric masking)" -ForegroundColor Cyan
    $s15Lines = @(
        '# Contributing'
        ''
        '```'
        '<!-- /skills:all -->'
        '```'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s15Lines -join "`n") + "`n"), $Utf8NoBom)

    $r15 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($r15.Out -match $SkillListFindingPattern)) 'scenario 15: a fenced END reports no [skill-list] finding'
    Assert-True ($r15.Out -match [regex]::Escape('0 <!-- skills:all --> span(s) found')) 'scenario 15: the masked END never becomes an orphan finding -- it is invisible, same as a masked BEGIN'

    # --- Scenario 16: root changelog ENTRY files are IN the scan set (#234) --------------------------
    # The window this closes: an entry file's text sits outside every scanned path while the PR is
    # open, and only lands in a scanned file at FOLD time -- which happens directly on main, past every
    # PR gate. v2.13.0 was blocked by exactly that: a marker quoted in changelog prose became an
    # unpaired BEGIN in CHANGELOG.md, discovered only when cut-release ran the full gate on main.
    # Both halves are asserted here: the dead link (check 4) AND the quoted marker (check 10, the
    # original case), because they share this file set and the window covered both.
    Write-Host "check 4 + 10 -- a root changelog entry file is scanned BEFORE the fold" -ForegroundColor Cyan
    $midDot = [char]0x00B7
    $entryPath = Join-Path $Fixture 'fix-my-branch.md'
    $s16Lines = @(
        "### My change $midDot Fix $midDot 2026-07-29"
        ''
        "See [nope]($deadLink) for details."
        'The gate caught the skill missing from a `<!-- skills:all -->` span.'
    )
    [System.IO.File]::WriteAllText($entryPath, (($s16Lines -join "`n") + "`n"), $Utf8NoBom)

    $r16 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 $r16.Code 'scenario 16: exit 1 -- an entry file is scanned, so its findings surface while the PR is open'
    Assert-True ($r16.Out -match [regex]::Escape('.\fix-my-branch.md') -and $r16.Out -match '\[link\]') 'scenario 16: a dead link in an entry body is reported BEFORE the fold, not after'
    Assert-True ($r16.Out -match [regex]::Escape("'<!-- skills:all -->' at line 4 has no matching")) 'scenario 16: the original #234 case -- a marker quoted in entry prose is caught on the PR instead of on main'
    # The entry-format rule still has to hold, and since #405 it is CHECK 13 that carries it rather than
    # the dead-link scan. Every root *.md is link-scanned now, so "is this an entry file?" no longer
    # decides whether a root document is READ -- it decides whether it is judged as a changelog entry
    # (heading levels) and whether checks 11 and 12 skip it as history in the making. A permanent root
    # doc must never be counted as one: the fixture root holds CONTRIBUTING.md and CHANGELOG.md beside
    # the single entry file, so the count is the discriminator, and it would catch the entry rule
    # degrading into "any root .md" just as the old NOTES.md assertion did.
    Assert-True ($r16.Out -match '\[entry-heading\].*1 unfolded entry\(ies\)') 'scenario 16: exactly ONE root file is read as an entry -- a permanent root doc is scanned but never judged as one'

    # And once the fold has taken it away, it simply drops out of the set again -- no stale reference,
    # no error about a file that no longer exists.
    Remove-Item -LiteralPath $entryPath -Force
    $r17 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($r17.Out -match [regex]::Escape('fix-my-branch.md'))) 'scenario 16: after the fold removes it, the entry file is gone from the set without complaint'

} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Complete-IntegritySuite
