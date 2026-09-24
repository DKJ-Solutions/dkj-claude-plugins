<#
.SYNOPSIS
    check-plugin-integrity.ps1, checks 15 and 16: a captured output sample, and a measured figure in
    prose, must each say what they are bound to.

.DESCRIPTION
    The fixture, the assert helpers and Invoke-Integrity live in check-plugin-integrity-fixture.ps1,
    which also records why this suite family is more than one file. Split out of -entries under #2304
    (step 4); at 22 gate invocations these two checks were the larger half of that file.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'check-plugin-integrity-fixture.ps1')

$Fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("check-plugin-integrity-figures-$PID-$([guid]::NewGuid().ToString('n'))")

try {
    New-IntegrityFixture -Fixture $Fixture

    # --- check 15: a captured output sample must say what it is bound to ----------------------------
    # The class behind four of test round v11's nine findings. Each case below is one of the two ways
    # this check can fail badly: missing a real unbound sample, or firing on something that is not one.
    # The false-positive half is not optional politeness -- a gate that cries wolf gets an opt-out
    # pasted over every finding and then reports green while asserting nothing.
    # THE PATH HAS TO BE ONE $consumerDocs ACTUALLY NAMES, and this fixture has now been caught by that
    # twice. $consumerDocs holds paths rather than bare names, and both checks Test-Path-skip an entry
    # they cannot find, in silence -- so a fixture writing anywhere else leaves every assertion below
    # passing over a document the check never opened. First it was the move into plugins/; on
    # August 14, 2026 the adoption half split off into plugins/ADOPTION.md and the two plumbing pages
    # went to the repo root (inbound #664), which moved the subject again.
    #
    # ADOPTION.md rather than the root INSTALL.md, deliberately: in the real tree it is the page that
    # carries the captured samples and measured figures these two checks exist for -- the bootstrap's
    # closing line, the 4+15+2 counts. Pointing the fixture at the document that really holds the
    # subject is what keeps this suite honest about what it proves.
    $qsDir = Join-Path $Fixture 'plugins'
    if (-not (Test-Path -LiteralPath $qsDir)) { New-Item -ItemType Directory -Path $qsDir -Force | Out-Null }
    $qs = Join-Path $qsDir 'ADOPTION.md'
    # Fence and box drawing from codepoints, never as literals. The first version wrote the fence
    # literally and silently produced an opening fence with the language on the NEXT line, so the
    # "a command block is not examined" case was testing a language-less block and failing for a
    # reason that had nothing to do with the check. Same discipline as fix-mojibake's ASCII-only
    # source, and for the same class of reason.
    #
    # AND EVERY '$fence + <lang>' BELOW IS PARENTHESISED, which is not style. In PowerShell the comma
    # binds TIGHTER than '+', so @('a', $fence + 'powershell', 'b') parses as ('a', $fence) +
    # ('powershell', 'b') -- four elements, and the language lands on its own line. That is what
    # actually broke the command-block case, twice, while the check under test was correct throughout.
    $bt    = [string][char]0x60
    $fence = $bt + $bt + $bt
    $tree  = 'repo/' + "`n" + [char]0x251C + [char]0x2500 + ' CLAUDE.md'

    # 1. THE FINDING: output quoted with nothing saying what it came from.
    [System.IO.File]::WriteAllText($qs, @(
        '# Quickstart', '', 'The closing line reads:', '', $fence,
        'Done: 4 created, 0 already present.', $fence, '', 'Compare it against yours.'
    ) -join "`n", $Utf8NoBom)
    $s1 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($s1.Out -match '\[expected-output\].*ADOPTION\.md') `
        'expected-output: an output sample with no stated binding is reported'
    Assert-True ($s1.Out -match 'expected-output. checked [1-9]') `
        'expected-output: and the coverage line counts samples examined, not check runs'

    # 2. BOUND, three ways -- a version, a date, and a hedge. Each must clear it on its own.
    foreach ($binding in @('Measured on CLI 2.1.220.', 'Measured on 1 August 2026.', 'This varies by repo.')) {
        [System.IO.File]::WriteAllText($qs, @(
            '# Quickstart', '', 'The closing line reads:', '', $fence,
            'Done: 4 created, 0 already present.', $fence, '', $binding
        ) -join "`n", $Utf8NoBom)
        $s2 = Invoke-Integrity -FixtureRoot $Fixture
        Assert-True (-not ($s2.Out -match '\[expected-output\].*ADOPTION\.md')) `
            "expected-output: a sample bound by '$binding' passes"
    }

    # 3. A COMMAND IS NOT A SAMPLE. Tagged blocks are things to run; they cannot go stale under a reader
    #    the way a captured transcript can.
    [System.IO.File]::WriteAllText($qs, @(
        '# Quickstart', '', 'Run this:', '', ($fence + 'powershell'),
        'claude plugin install dkj-subagents-alpha@dkj-claude-plugins --scope project', $fence
    ) -join "`n", $Utf8NoBom)
    $s3 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($s3.Out -match '\[expected-output\].*ADOPTION\.md')) `
        'expected-output: a powershell block is a command to run, not examined'

    # 4. A DIAGRAM IS DRAWN, NOT CAPTURED. The check's first real false positive, on the seam diagram in
    #    the root README.
    [System.IO.File]::WriteAllText($qs, @(
        '# Quickstart', '', 'The shape is:', '', ($fence + 'text'), $tree, $fence
    ) -join "`n", $Utf8NoBom)
    $s4 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($s4.Out -match '\[expected-output\].*ADOPTION\.md')) `
        'expected-output: a box-drawing diagram is not a captured sample'

    # 5. THE OPT-OUT HAS TO NAME A REASON. A bare marker must not silence the check, or the escape hatch
    #    becomes the way the gate is defeated rather than the way an exception is recorded.
    [System.IO.File]::WriteAllText($qs, @(
        '# Quickstart', '', 'Reads:', '', $fence, 'Done: 4 created.', $fence, '', '<!-- unbound-sample: -->'
    ) -join "`n", $Utf8NoBom)
    $s5 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($s5.Out -match '\[expected-output\].*ADOPTION\.md') `
        'expected-output: an opt-out marker with no reason does not silence the check'
    [System.IO.File]::WriteAllText($qs, @(
        '# Quickstart', '', 'Reads:', '', $fence, 'Done: 4 created.', $fence, '',
        '<!-- unbound-sample: invented for the test fixture, bound to nothing real -->'
    ) -join "`n", $Utf8NoBom)
    $s6 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($s6.Out -match '\[expected-output\].*ADOPTION\.md')) `
        'expected-output: an opt-out that names a reason does silence it'

    # --- check 16: a measured figure in prose names what it was measured on -------------------------
    # Check 15's class, one step outside its reach: the same staleness, in running prose where there is
    # no fence to mark it. Test round v12's #374 and its unfiled twin one section down. The cases below
    # are again the two ways this fails badly -- missing a real unbound figure, and firing on something
    # that is not one -- plus the three design decisions that could otherwise erode silently: the window
    # is bounded, a fence belongs to check 15, and 'measured' is not a binding.

    # 1. THE FINDING: a byte count with nothing saying whose machine it came from.
    [System.IO.File]::WriteAllText($qs, @(
        '# Quickstart', '', 'After the teardown the file is 288 bytes and holds nothing of ours.'
    ) -join "`n", $Utf8NoBom)
    $f1 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($f1.Out -match '\[measured-figure\].*ADOPTION\.md') `
        'measured-figure: a byte count in prose with no stated binding is reported'
    Assert-True ($f1.Out -match 'measured-figure. checked [1-9]') `
        'measured-figure: and the coverage line counts figures examined, not check runs'

    # 2. BOUND, five ways -- a date, a test round, a version, a named profile state, and a hedge. Each
    #    must clear it on its own, because a writer will reach for whichever one fits the sentence.
    foreach ($binding in @(
        'Measured on 1 August 2026.', 'Measured in round v12.', 'Measured on CLI 2.1.220.',
        'Measured on a virgin profile.', 'The figure varies by platform.'
    )) {
        [System.IO.File]::WriteAllText($qs, @(
            '# Quickstart', '', "After the teardown the file is 288 bytes. $binding"
        ) -join "`n", $Utf8NoBom)
        $f2 = Invoke-Integrity -FixtureRoot $Fixture
        Assert-True (-not ($f2.Out -match '\[measured-figure\].*ADOPTION\.md')) `
            "measured-figure: a figure bound by '$binding' passes"
    }

    # 3. THE WINDOW REACHES THE NEIGHBOURING BLOCKS, IN BOTH DIRECTIONS. A table row is bound by the
    #    paragraph introducing the table (the #339 table) or by the note underneath it saying which
    #    column came from where (the bracket table). Neither binding sits on the row itself, and a
    #    line-count window would have to guess how many rows the table has.
    [System.IO.File]::WriteAllText($qs, @(
        '# Quickstart', '', 'Measured on a virgin profile, 1 August 2026:', '',
        '| file | size |', '|---|---|', '| settings.json | 288 bytes |'
    ) -join "`n", $Utf8NoBom)
    $f3 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($f3.Out -match '\[measured-figure\].*ADOPTION\.md')) `
        'measured-figure: a binding in the paragraph ABOVE a table binds its rows'
    [System.IO.File]::WriteAllText($qs, @(
        '# Quickstart', '', 'The sizes:', '',
        '| file | size |', '|---|---|', '| settings.json | 288 bytes |', '',
        'The right-hand column is round v12.'
    ) -join "`n", $Utf8NoBom)
    $f4 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($f4.Out -match '\[measured-figure\].*ADOPTION\.md')) `
        'measured-figure: a binding in the paragraph BELOW a table binds its rows too'

    # 4. AND IT STOPS THERE. A binding two blocks away does NOT count -- otherwise the gate is satisfied
    #    by a date in an unrelated subsection, which is how a window quietly becomes section-wide.
    [System.IO.File]::WriteAllText($qs, @(
        '# Quickstart', '', 'Measured on a virgin profile, 1 August 2026.', '',
        'An unrelated paragraph sits in between.', '', 'The file is 288 bytes.'
    ) -join "`n", $Utf8NoBom)
    $f5 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($f5.Out -match '\[measured-figure\].*ADOPTION\.md') `
        'measured-figure: a binding two blocks away is out of reach -- the window is bounded'

    # 5. A FENCED FIGURE BELONGS TO CHECK 15. Counting it here would report one sample as two findings,
    #    and would flag verbatim command output that is deliberately reproduced.
    [System.IO.File]::WriteAllText($qs, @(
        '# Quickstart', '', 'Measured in round v12, the output reads:', '', ($fence + 'text'),
        'known_marketplaces.json  288 bytes', $fence
    ) -join "`n", $Utf8NoBom)
    $f6 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($f6.Out -match '\[measured-figure\] checked 0') `
        'measured-figure: a figure inside a fence is check 15''s, and is not counted twice'

    # 6. 'measured' ON ITS OWN IS NOT A BINDING. It says the author saw the number, which was true of
    #    every finding this check exists for. Same rejection as check 15 makes, and for the same reason.
    [System.IO.File]::WriteAllText($qs, @(
        '# Quickstart', '', 'The clone is deleted (measured: 288 bytes, gone).'
    ) -join "`n", $Utf8NoBom)
    $f7 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($f7.Out -match '\[measured-figure\].*ADOPTION\.md') `
        'measured-figure: the word ''measured'' alone does not bind a figure'

    # 7. NOT EVERY 'byte' IS A FIGURE. 'byte-identical' is a word, and a check that flagged it would be
    #    training writers to paste opt-outs over prose. The leading digit is what makes it a measurement.
    [System.IO.File]::WriteAllText($qs, @(
        '# Quickstart', '', 'The install leaves the file byte-identical, so the diff is empty.'
    ) -join "`n", $Utf8NoBom)
    $f8 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($f8.Out -match '\[measured-figure\] checked 0') `
        'measured-figure: ''byte-identical'' carries no number and is not a figure'

    # 8. THE OPT-OUT HAS TO NAME A REASON, exactly as check 15's does.
    [System.IO.File]::WriteAllText($qs, @(
        '# Quickstart', '', 'The file is 288 bytes.', '', '<!-- unbound-figure: -->'
    ) -join "`n", $Utf8NoBom)
    $f9 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($f9.Out -match '\[measured-figure\].*ADOPTION\.md') `
        'measured-figure: an opt-out marker with no reason does not silence the check'
    [System.IO.File]::WriteAllText($qs, @(
        '# Quickstart', '', 'The file is 288 bytes.', '',
        '<!-- unbound-figure: invented for the test fixture, bound to nothing real -->'
    ) -join "`n", $Utf8NoBom)
    $f10 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($f10.Out -match '\[measured-figure\].*ADOPTION\.md')) `
        'measured-figure: an opt-out that names a reason does silence it'
} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Complete-IntegritySuite
