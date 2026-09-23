<#
.SYNOPSIS
    check-plugin-integrity.ps1, check 41: the #1934 fixture load guard cannot be half-removed -- a suite
    carrying any of its three parts must carry all three.

.DESCRIPTION
    The fixture, the assert helpers and Invoke-Integrity live in check-plugin-integrity-fixture.ps1,
    which also records why this suite family is more than one file. Split out of -commands under #2304;
    at sixteen gate invocations it was the largest single check in that file, so it stands alone.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'check-plugin-integrity-fixture.ps1')

$Fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("check-plugin-integrity-fixture-guard-$PID-$([guid]::NewGuid().ToString('n'))")

try {
    New-IntegrityFixture -Fixture $Fixture
    # The root documents as check 4's scenario B leaves them -- see Write-QuietRootDocuments for why this
    # suite states that starting point instead of inheriting it from a scenario in another file.
    Write-QuietRootDocuments -Fixture $Fixture

    # --- check 41: the #1934 fixture load guard cannot be half-removed -------------------------------
    # THE CLASS: a fixture missing a lib the copied acting script dot-sources UNGUARDED kills the child
    # during LOAD, and the suite then reports the absence of the document it never wrote. #1934 wired six
    # suites in three parts and nothing asserted any of the three was still there.
    #
    # THE RULE IS SELF-ANCHORING, which is what these scenarios are really pinning: a file carrying ANY
    # part must carry all three. The alternative #1948 proposed -- flag any captured child invocation
    # with no verdict -- was measured at 71 findings over 82 invocations on the real tree and is #1954,
    # not this check. So the discriminator below (a suite carrying NONE of the parts) matters as much as
    # the findings: get it wrong and this check becomes that one.
    $FsFindingPattern = '\[fixture-script\] \.'
    $fsTests = Join-Path $Fixture 'scripts\tests'
    New-Item -ItemType Directory -Path $fsTests -Force | Out-Null
    $fsPath = Join-Path $fsTests 'wired.tests.ps1'

    # A fully wired suite, in the shape the six real ones take: the dot-source, the verdict at the
    # invocation, and the summary whose return becomes an exit code.
    $fsWiredLines = @(
        '$ErrorActionPreference = ''Stop'''
        '. (Join-Path $PSScriptRoot ''..\lib\fixture-script-lib.ps1'')'
        'function Invoke-Child {'
        '    $out = & powershell -NoProfile -File $script:child 2>&1'
        '    $code = $LASTEXITCODE'
        '    Assert-FixtureScriptLoaded -Code $code -Script $script:child -Output $out'
        '    return $code'
        '}'
        '$loadBroken = Write-FixtureScriptSummary -Subject ''child.ps1'''
        'if ($loadBroken) { exit 1 }'
    )

    Write-Host "check 41 -- a fully wired suite reports nothing" -ForegroundColor Cyan
    [System.IO.File]::WriteAllText($fsPath, (($fsWiredLines -join "`n") + "`n"), $Utf8NoBom)
    $rC65 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 0 ([regex]::Matches($rC65.Out, $FsFindingPattern).Count) 'scenario 65: all three parts present and the summary read -- no finding'
    Assert-True ($rC65.Out -match '\[fixture-script\] checked \d+') 'scenario 65: and the check ran rather than being silently absent'

    # THE DISCRIMINATOR, and it is the whole boundary between this check and #1954. A suite that runs a
    # child with its output captured and carries NONE of the three parts is NOT a subject: 65 such suites
    # exist on the real tree, and reporting them is the 71-finding rule this check was built instead of.
    Write-Host "check 41 -- a suite carrying none of the parts is not a subject" -ForegroundColor Cyan
    $fsUnwired = Join-Path $fsTests 'unwired.tests.ps1'
    [System.IO.File]::WriteAllText($fsUnwired, (@(
        '$out = & powershell -NoProfile -File $child 2>&1'
        '$code = $LASTEXITCODE'
        'if ($code -ne 0) { Write-Host ''it failed'' }'
    ) -join "`n") + "`n", $Utf8NoBom)
    $rC66 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 0 ([regex]::Matches($rC66.Out, $FsFindingPattern).Count) 'scenario 66: an unwired suite that captures a child is not reported -- that is #1954, not this check'
    Remove-Item -LiteralPath $fsUnwired -Force

    # EACH PART, DROPPED ON ITS OWN. Three scenarios rather than one, because they fail differently and a
    # single "something is missing" assert would pass while naming the wrong part.
    Write-Host "check 41 -- each missing part is named" -ForegroundColor Cyan

    # The verdict dropped -- the #1948 hazard verbatim: an edit to the invocation helper removes the call.
    [System.IO.File]::WriteAllText($fsPath, ((($fsWiredLines | Where-Object { $_ -notmatch 'Assert-FixtureScriptLoaded' }) -join "`n") + "`n"), $Utf8NoBom)
    $rC67 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 ([regex]::Matches($rC67.Out, $FsFindingPattern).Count) 'scenario 67: the dropped verdict is one finding'
    Assert-True ($rC67.Out -match 'not a call to Assert-FixtureScriptLoaded') 'scenario 67: and the finding names the part that is gone, not merely that one is'

    # The summary dropped -- the run then exits 0 on a load failure the asserts happened not to notice.
    [System.IO.File]::WriteAllText($fsPath, ((($fsWiredLines | Where-Object { $_ -notmatch 'Write-FixtureScriptSummary|loadBroken' }) -join "`n") + "`n"), $Utf8NoBom)
    $rC68 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 ([regex]::Matches($rC68.Out, $FsFindingPattern).Count) 'scenario 68: the dropped summary is one finding'
    Assert-True ($rC68.Out -match 'not a call to Write-FixtureScriptSummary') 'scenario 68: and it is named'

    # The dot-source dropped. This one is the least likely to happen alone -- it makes the other two
    # unresolved commands -- but it is the cheapest to state and it closes the third direction.
    [System.IO.File]::WriteAllText($fsPath, ((($fsWiredLines | Where-Object { $_ -notmatch 'fixture-script-lib' }) -join "`n") + "`n"), $Utf8NoBom)
    $rC69 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 ([regex]::Matches($rC69.Out, $FsFindingPattern).Count) 'scenario 69: the dropped dot-source is one finding'
    Assert-True ($rC69.Out -match 'not the dot-source of scripts/lib/fixture-script-lib\.ps1') 'scenario 69: and it is named'

    # THE FOURTH FACT, AND THE WORSE FAILURE OF THE TWO. All three parts present, and the summary's
    # verdict thrown away: the block still PRINTS, so the run says a child died on load and then exits 0
    # -- wearing the guard's own output as proof that it is wired. Three discard spellings, because a
    # check whose arms disagree about wrapping teaches the shape that gets past it (check 35's lesson).
    Write-Host "check 41 -- a summary whose verdict is discarded, in three spellings" -ForegroundColor Cyan
    foreach ($fsDiscard in @(
        @{ Label = 'Out-Null';   Line = 'Write-FixtureScriptSummary -Subject ''child.ps1'' | Out-Null' }
        @{ Label = 'a null assignment'; Line = '$null = Write-FixtureScriptSummary -Subject ''child.ps1''' }
        @{ Label = 'assigned but never read'; Line = '$loadBroken = Write-FixtureScriptSummary -Subject ''child.ps1''' }
    )) {
        $fsLines = @(
            '$ErrorActionPreference = ''Stop'''
            '. (Join-Path $PSScriptRoot ''..\lib\fixture-script-lib.ps1'')'
            'function Invoke-Child {'
            '    $out = & powershell -NoProfile -File $script:child 2>&1'
            '    $code = $LASTEXITCODE'
            '    Assert-FixtureScriptLoaded -Code $code -Script $script:child -Output $out'
            '}'
            $fsDiscard.Line
        )
        [System.IO.File]::WriteAllText($fsPath, (($fsLines -join "`n") + "`n"), $Utf8NoBom)
        $rC70 = Invoke-Integrity -FixtureRoot $Fixture
        Assert-Equal 1 ([regex]::Matches($rC70.Out, $FsFindingPattern).Count) "scenario 70/$($fsDiscard.Label): a verdict that is never read is a finding"
        Assert-True ($rC70.Out -match 'is never read, so nothing turns it into an exit code') "scenario 70/$($fsDiscard.Label): and the finding says what is missing rather than that the call is"
    }

    # AND A PAIR OF BRACKETS IS NOT AN ESCAPE HATCH -- the same property check 35 states, asserted here
    # because this check climbs the same wrapping and would otherwise be free to drift from it.
    Write-Host "check 41 -- brackets do not launder a discard" -ForegroundColor Cyan
    [System.IO.File]::WriteAllText($fsPath, ((@(
        '$ErrorActionPreference = ''Stop'''
        '. (Join-Path $PSScriptRoot ''..\lib\fixture-script-lib.ps1'')'
        '$out = & powershell -NoProfile -File $child 2>&1'
        'Assert-FixtureScriptLoaded -Code $LASTEXITCODE -Output $out'
        '(Write-FixtureScriptSummary -Subject ''child.ps1'') | Out-Null'
    ) -join "`n") + "`n"), $Utf8NoBom)
    $rC71 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 ([regex]::Matches($rC71.Out, $FsFindingPattern).Count) 'scenario 71: a parenthesised discard is still a discard'

    # AND THE READ IS COUNTED IN EVERY SHAPE THE TREE ACTUALLY USES, so a suite asserting the return
    # rather than storing it is not reported. fixture-script-lib.tests.ps1 does exactly this.
    Write-Host "check 41 -- a verdict consumed in place is a read" -ForegroundColor Cyan
    foreach ($fsRead in @(
        @{ Label = 'an if condition'; Line = 'if (Write-FixtureScriptSummary -Subject ''child.ps1'') { exit 1 }' }
        @{ Label = 'an argument';     Line = 'Assert-True (Write-FixtureScriptSummary -Subject ''child.ps1'') ''it said so''' }
    )) {
        [System.IO.File]::WriteAllText($fsPath, ((@(
            '$ErrorActionPreference = ''Stop'''
            '. (Join-Path $PSScriptRoot ''..\lib\fixture-script-lib.ps1'')'
            '$out = & powershell -NoProfile -File $child 2>&1'
            'Assert-FixtureScriptLoaded -Code $LASTEXITCODE -Output $out'
            $fsRead.Line
        ) -join "`n") + "`n"), $Utf8NoBom)
        $rC72 = Invoke-Integrity -FixtureRoot $Fixture
        Assert-Equal 0 ([regex]::Matches($rC72.Out, $FsFindingPattern).Count) "scenario 72/$($fsRead.Label): consuming the verdict in place is a read"
    }

    # A MENTION IS NOT A WIRING, which is why the dot-source is read through the AST and not by matching
    # the lib's name in the text. A file naming it in a comment or a string has adopted nothing, and
    # reporting it would send a reader to wire a suite that never ran a child at all.
    Write-Host "check 41 -- a bare mention of the lib is not a wiring" -ForegroundColor Cyan
    [System.IO.File]::WriteAllText($fsPath, ((@(
        '# This suite does not use fixture-script-lib.ps1 -- it runs no child process.'
        '$note = ''see scripts/lib/fixture-script-lib.ps1 for the load guard'''
        'Write-Host $note'
    ) -join "`n") + "`n"), $Utf8NoBom)
    $rC73 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 0 ([regex]::Matches($rC73.Out, $FsFindingPattern).Count) 'scenario 73: a comment and a string naming the lib are not a dot-source'
    # THE FOUR PROBES THE CODE REVIEW RAN AGAINST THIS CHECK, pinned so the repairs cannot regress. Each
    # was a real answer the check gave before it was narrowed, and three of the four were FALSE NEGATIVES
    # -- the direction that matters for a guard whose whole subject is a guard that stopped guarding.
    Write-Host "check 41 -- the read search is scoped and ordered" -ForegroundColor Cyan

    # (a) A REFERENCE BEFORE THE ASSIGNMENT is a different variable's life, and used to clear the dead
    #     assignment that followed it.
    [System.IO.File]::WriteAllText($fsPath, ((@(
        '$ErrorActionPreference = ''Stop'''
        '. (Join-Path $PSScriptRoot ''..\lib\fixture-script-lib.ps1'')'
        '$out = & powershell -NoProfile -File $child 2>&1'
        'Assert-FixtureScriptLoaded -Code $LASTEXITCODE -Output $out'
        'if ($loadBroken) { Write-Host ''stale reference to a variable that does not exist yet'' }'
        '$loadBroken = Write-FixtureScriptSummary -Subject ''child.ps1'''
    ) -join "`n") + "`n"), $Utf8NoBom)
    $rC74 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 ([regex]::Matches($rC74.Out, $FsFindingPattern).Count) 'scenario 74: a reference BEFORE the assignment does not clear it'

    # (b) THE SAME NAME IN AN UNRELATED FUNCTION used to clear a dead file-scope assignment. PowerShell
    #     scopes by runtime lookup, so the two are genuinely different values.
    [System.IO.File]::WriteAllText($fsPath, ((@(
        '$ErrorActionPreference = ''Stop'''
        '. (Join-Path $PSScriptRoot ''..\lib\fixture-script-lib.ps1'')'
        '$out = & powershell -NoProfile -File $child 2>&1'
        'Assert-FixtureScriptLoaded -Code $LASTEXITCODE -Output $out'
        'function Test-Unrelated {'
        '    $loadBroken = $true'
        '    if ($loadBroken) { Write-Host ''this is a different variable entirely'' }'
        '}'
        '$loadBroken = Write-FixtureScriptSummary -Subject ''child.ps1'''
    ) -join "`n") + "`n"), $Utf8NoBom)
    $rC75 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 ([regex]::Matches($rC75.Out, $FsFindingPattern).Count) 'scenario 75: the same name inside an unrelated function does not clear a file-scope assignment'

    # (c) AND THE MIRROR OF (b): a read in the SAME function still clears, so the narrowing did not turn
    #     into a false positive on a suite that wires its guard inside a helper.
    [System.IO.File]::WriteAllText($fsPath, ((@(
        '$ErrorActionPreference = ''Stop'''
        '. (Join-Path $PSScriptRoot ''..\lib\fixture-script-lib.ps1'')'
        'function Complete-Suite {'
        '    $out = & powershell -NoProfile -File $child 2>&1'
        '    Assert-FixtureScriptLoaded -Code $LASTEXITCODE -Output $out'
        '    $loadBroken = Write-FixtureScriptSummary -Subject ''child.ps1'''
        '    if ($loadBroken) { exit 1 }'
        '}'
    ) -join "`n") + "`n"), $Utf8NoBom)
    $rC76 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 0 ([regex]::Matches($rC76.Out, $FsFindingPattern).Count) 'scenario 76: a read in the SAME function still clears -- the narrowing is not a false positive'

    # (d) A VERDICT HANDED BACK BY A FUNCTION is not discarded, in both spellings. This was a false
    #     POSITIVE: the call is the last statement of the body, which is PowerShell's implicit return.
    Write-Host "check 41 -- a verdict handed back by a function is not a discard" -ForegroundColor Cyan
    foreach ($fsRet in @(
        @{ Label = 'an implicit return'; Line = '    Write-FixtureScriptSummary -Subject ''child.ps1''' }
        @{ Label = 'an explicit return'; Line = '    return Write-FixtureScriptSummary -Subject ''child.ps1''' }
    )) {
        [System.IO.File]::WriteAllText($fsPath, ((@(
            '$ErrorActionPreference = ''Stop'''
            '. (Join-Path $PSScriptRoot ''..\lib\fixture-script-lib.ps1'')'
            '$out = & powershell -NoProfile -File $child 2>&1'
            'Assert-FixtureScriptLoaded -Code $LASTEXITCODE -Output $out'
            'function Get-LoadBroken {'
            $fsRet.Line
            '}'
            'if (Get-LoadBroken) { exit 1 }'
        ) -join "`n") + "`n"), $Utf8NoBom)
        $rC77 = Invoke-Integrity -FixtureRoot $Fixture
        Assert-Equal 0 ([regex]::Matches($rC77.Out, $FsFindingPattern).Count) "scenario 77/$($fsRet.Label): a verdict handed back to the caller is not a discard"
    }

    # AND A BARE CALL THAT IS *NOT* A RETURN IS STILL A DISCARD -- the discriminator for (d), without
    # which that arm would clear every dropped verdict at file scope.
    [System.IO.File]::WriteAllText($fsPath, ((@(
        '$ErrorActionPreference = ''Stop'''
        '. (Join-Path $PSScriptRoot ''..\lib\fixture-script-lib.ps1'')'
        '$out = & powershell -NoProfile -File $child 2>&1'
        'Assert-FixtureScriptLoaded -Code $LASTEXITCODE -Output $out'
        'Write-FixtureScriptSummary -Subject ''child.ps1'''
        'Write-Host ''done'''
    ) -join "`n") + "`n"), $Utf8NoBom)
    $rC78 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 ([regex]::Matches($rC78.Out, $FsFindingPattern).Count) 'scenario 78: a bare call at file scope is still a discard, not an implicit return'

    # AND A [void] CAST IS A DISCARD EVEN AS THE LAST STATEMENT OF A FUNCTION -- the OTHER discriminator
    # for (d), and the one that was missing. Scenario 78 pins that a bare call at file scope is not an
    # implicit return; this pins that a cast-away call inside a function is not one either. Until #1956
    # the check climbed straight through the ConvertExpressionAst without noticing the cast, so this
    # exact shape reached the implicit-return arm and was cleared as a READ -- 0 findings here, against
    # 1 for the same call one line further up. [void] is precisely what stops a last statement being a
    # return value, so the two positions have to agree, and a check whose three arms disagree about
    # wrapping teaches the shape that gets past it (check 35's lesson, one level up).
    #
    # FOUR POSITIONS RATHER THAN THE TWO THE REPAIR WAS ABOUT. Answering the discard FIRST reaches every
    # arm, not only the implicit-return one, and the two below are the arms that would otherwise CLEAR a
    # cast-away verdict: an explicit 'return', and an assignment to a variable that is read later. The
    # cast is what throws the value away, so no shape it wears afterwards can give it back -- but that
    # is reasoning, and reasoning is what these scenarios exist to stop standing in for a measurement.
    Write-Host "check 41 -- a [void] cast is a discard in every position" -ForegroundColor Cyan
    foreach ($fsVoid in @(
        @{ Label = 'as the last statement'
           Body  = @('    [void](Write-FixtureScriptSummary -Subject ''child.ps1'')') }
        @{ Label = 'one line further up'
           Body  = @('    [void](Write-FixtureScriptSummary -Subject ''child.ps1'')'
                     '    Write-Host ''done''') }
        @{ Label = 'behind an explicit return'
           Body  = @('    return [void](Write-FixtureScriptSummary -Subject ''child.ps1'')') }
        @{ Label = 'assigned to a variable that IS read later'
           Body  = @('    $loadBroken = [void](Write-FixtureScriptSummary -Subject ''child.ps1'')'
                     '    if ($loadBroken) { exit 1 }') }
    )) {
        [System.IO.File]::WriteAllText($fsPath, ((@(
            '$ErrorActionPreference = ''Stop'''
            '. (Join-Path $PSScriptRoot ''..\lib\fixture-script-lib.ps1'')'
            '$out = & powershell -NoProfile -File $child 2>&1'
            'Assert-FixtureScriptLoaded -Code $LASTEXITCODE -Output $out'
            'function Close-Suite {'
        ) + $fsVoid.Body + @(
            '}'
            'Close-Suite'
        ) -join "`n") + "`n"), $Utf8NoBom)
        $rC78b = Invoke-Integrity -FixtureRoot $Fixture
        Assert-Equal 1 ([regex]::Matches($rC78b.Out, $FsFindingPattern).Count) "scenario 78b/$($fsVoid.Label): a [void] cast is a discard, whatever shape it wears"
        Assert-True ($rC78b.Out -match 'is never read, so nothing turns it into an exit code') "scenario 78b/$($fsVoid.Label): and the finding says what is missing"
    }

    # (e) THE DOT-SOURCE LEAF IS ANCHORED: a different file whose name merely ends the same way is not
    #     this lib, and used to count as the wiring.
    Write-Host "check 41 -- a lookalike lib name is not the dot-source" -ForegroundColor Cyan
    [System.IO.File]::WriteAllText($fsPath, ((@(
        '$ErrorActionPreference = ''Stop'''
        '. (Join-Path $PSScriptRoot ''..\lib\my-other-fixture-script-lib.ps1'')'
        '$out = & powershell -NoProfile -File $child 2>&1'
        'Assert-FixtureScriptLoaded -Code $LASTEXITCODE -Output $out'
        '$loadBroken = Write-FixtureScriptSummary -Subject ''child.ps1'''
        'if ($loadBroken) { exit 1 }'
    ) -join "`n") + "`n"), $Utf8NoBom)
    $rC79 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 ([regex]::Matches($rC79.Out, $FsFindingPattern).Count) 'scenario 79: a lookalike leaf does not satisfy the dot-source part'
    Assert-True ($rC79.Out -match 'not the dot-source of scripts/lib/fixture-script-lib\.ps1') 'scenario 79: and the finding names the part that is genuinely absent'

    Remove-Item -LiteralPath $fsPath -Force

} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Complete-IntegritySuite
