<#
.SYNOPSIS
    check-plugin-integrity.ps1, the script set and what is read from it: check 37 (the gate's own check
    list, against the headers it claims to enumerate), the shared script set reaching a plugin's
    templates/ (#1998), and check 44 (a prompting Shopify theme call carries --force).

.DESCRIPTION
    The fixture, the assert helpers and Invoke-Integrity live in check-plugin-integrity-fixture.ps1,
    which also records why this suite family is more than one file. Split out of -commands under #2304.

    The script-set scenarios assert check 31's finding as well as check 5's, so this file defines
    check 31's finding pattern itself -- while the two shared a file it was simply read from the block
    above, which is the kind of inheritance a cost-based partition may not depend on.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'check-plugin-integrity-fixture.ps1')

$Fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("check-plugin-integrity-script-set-$PID-$([guid]::NewGuid().ToString('n'))")

try {
    New-IntegrityFixture -Fixture $Fixture
    # The root documents as check 4's scenario B leaves them -- see Write-QuietRootDocuments for why this
    # suite states that starting point instead of inheriting it from a scenario in another file.
    Write-QuietRootDocuments -Fixture $Fixture

    # --- check 37: this file's own check list, against the headers it claims to enumerate ------------
    #     Issue #1680. Check 34 holds the column-0 headers to EACH OTHER; nothing read the prose list in
    #     check-plugin-integrity.ps1's own .DESCRIPTION -- the summary a reader who has not opened the
    #     file consults, and the one a lens, a hook, a test name or a release note quotes a number from.
    #     It had stopped at 30 while the code ran to 36, its item 30 described the check #1494 had
    #     renumbered to 33, 13b was missing with no report having noticed, and 9 and 17 still read as
    #     live checks a month after they were retired.
    #
    #     THE MARKER IS COMPOSED, NEVER WRITTEN OUT, and that is not style. This suite is a .ps1 in the
    #     script set check 37 walks, so a literal marker in these fixture lines would open a span in the
    #     SUITE -- a file with no numbered headers of its own -- and the real gate run would report this
    #     file. Same self-fixturing trap scenario 57 documents for check 34's indented headers, arriving
    #     through the other door: there the suite has to prove the bound, here it has to stay outside it.
    $clTag   = 'checks:list'
    $clOpen  = "<!-- $clTag -->"
    $clClose = "<!-- /$clTag -->"
    #     Matched on the finding's PATH rather than on a phrase, and that is not a shortcut: this check's
    #     own coverage line -- present on every run -- contains the words "claims to enumerate them", so a
    #     phrase pattern counts the coverage line as a second finding. It did, on the first run of
    #     scenario 58. A finding opens with the repo-relative path; the coverage line opens with 'checked'.
    $ClFindingPattern = '\[check-list\] \.'
    $s58Dir = Join-Path $Fixture 'scripts\lint'
    New-Item -ItemType Directory -Path $s58Dir -Force | Out-Null

    # --- Scenario 58: a header with no entry in the list is a finding, naming both lines -------------
    #     The measured defect. Naming only the header would leave a reader to find the list; naming only
    #     the list would leave them to find which check is missing.
    Write-Host "check 37 -- a header absent from the marked list is a finding" -ForegroundColor Cyan
    $s58Path  = Join-Path $s58Dir 'listed-gap.ps1'
    $s58Lines = @(
        '<#'
        '.SYNOPSIS'
        '    A gate that says what it checks.'
        '.DESCRIPTION'
        "    $clOpen"
        '      1. the first thing.'
        '      2. the second thing.'
        "    $clClose"
        '#>'
        '# --- 1. the first thing -------------------------------------------------'
        '$a = 1'
        ''
        '# --- 2. the second thing ------------------------------------------------'
        '$b = 2'
        ''
        '# --- 3. the one nobody wrote down ---------------------------------------'
        '$c = 3'
    )
    [System.IO.File]::WriteAllText($s58Path, (($s58Lines -join "`n") + "`n"), $Utf8NoBom)
    $rC58 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($rC58.Out -match 'listed-gap\.ps1:16:.*check 3 has a section header but no entry') 'scenario 58: the unlisted check is a finding, at the line its header sits on'
    Assert-True ($rC58.Out -match 'span at line 5') 'scenario 58: and it names the line the list opens on, so the reader has both ends'
    Assert-Equal 1 ([regex]::Matches($rC58.Out, $ClFindingPattern).Count) 'scenario 58: the two checks that ARE listed are not reported -- exactly one finding'
    Remove-Item -LiteralPath $s58Path -Force

    # --- Scenario 59: an entry with NO header is deliberately not a finding --------------------------
    #     The bound the whole check rests on, and the reason it could be born green. A retired check
    #     keeps its number as a tombstone (9 and 17 in the real gate), and the consumer-doc guard the
    #     suites call check 19 carries no header of its own. Asserting the reverse direction would have
    #     needed exactly those three as exemptions on the day it was written -- the shape this repo
    #     declined at 124 findings all false.
    Write-Host "check 37 -- an entry with no header of its own is not a finding" -ForegroundColor Cyan
    $s59Path  = Join-Path $s58Dir 'listed-tombstone.ps1'
    $s59Lines = @(
        '<#'
        '.DESCRIPTION'
        "    $clOpen"
        '      1. the first thing.'
        '      2. RETIRED, and its number is kept so older citations still mean this.'
        '      3. a guard the suites name but that carries no header of its own.'
        '      4. the last thing.'
        "    $clClose"
        '#>'
        '# --- 1. the first thing -------------------------------------------------'
        '$a = 1'
        ''
        '# --- 4. after a gap where a retired check stood --------------------------'
        '$b = 2'
    )
    [System.IO.File]::WriteAllText($s59Path, (($s59Lines -join "`n") + "`n"), $Utf8NoBom)
    $rC59 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rC59.Out -match 'listed-tombstone\.ps1')) 'scenario 59: two entries with no header -- a tombstone and a headerless guard -- are both legal'
    Remove-Item -LiteralPath $s59Path -Force

    # --- Scenario 60: a lettered sub-section needs its own entry -------------------------------------
    #     13b was the seventh missing entry and the one no report had noticed: it is a real check with a
    #     real header, and reading '13' as covering it would let a whole sub-section vanish from the
    #     summary. The key is the number AND the letter, exactly as check 34 reads it.
    Write-Host "check 37 -- a lettered sub-section is a header of its own" -ForegroundColor Cyan
    $s60Path  = Join-Path $s58Dir 'listed-lettered.ps1'
    $s60Lines = @(
        '<#'
        '.DESCRIPTION'
        "    $clOpen"
        '      1. the first thing.'
        "    $clClose"
        '#>'
        '# --- 1. the first thing -------------------------------------------------'
        '$a = 1'
        ''
        '# --- 1b. a sub-section of it ---------------------------------------------'
        '$b = 2'
    )
    [System.IO.File]::WriteAllText($s60Path, (($s60Lines -join "`n") + "`n"), $Utf8NoBom)
    $rC60 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($rC60.Out -match 'listed-lettered\.ps1:10:.*check 1b has a section header but no entry') 'scenario 60: the sub-section is a subject of its own, not covered by the number above it'
    Remove-Item -LiteralPath $s60Path -Force

    # --- Scenario 61: a list in a file with no headers at all is a finding ---------------------------
    #     Silence there would read as a pass. Either the headers were renamed out of the convention check
    #     34 holds, or the marker is on the wrong file; both are worth a sentence rather than a green run.
    Write-Host "check 37 -- a marked list in a file carrying no headers is a finding" -ForegroundColor Cyan
    $s61Path  = Join-Path $s58Dir 'listed-headerless.ps1'
    $s61Lines = @(
        '<#'
        '.DESCRIPTION'
        "    $clOpen"
        '      1. something this file has no header for.'
        "    $clClose"
        '#>'
        '$a = 1'
    )
    [System.IO.File]::WriteAllText($s61Path, (($s61Lines -join "`n") + "`n"), $Utf8NoBom)
    $rC61 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($rC61.Out -match 'listed-headerless\.ps1:.*claims to') 'scenario 61: a list claiming to enumerate nothing is reported rather than passed over'
    Remove-Item -LiteralPath $s61Path -Force

    # --- Scenario 62: an unpaired marker is a hard error, and no marker at all is not a subject ------
    #     The first half is Invoke-MarkedSpanWalk's rule, asserted here for this category too: a typo'd
    #     sentinel must never read as "no list here", which is the one failure that turns a gate green by
    #     silencing it. The second half is what makes the check opt-in -- the 19 files check 34 measured
    #     carry numbered headers and claim to enumerate nothing, and none of them may be a finding.
    Write-Host "check 37 -- an unpaired marker is an error; no marker is not a subject" -ForegroundColor Cyan
    $s62Path  = Join-Path $s58Dir 'listed-unpaired.ps1'
    $s62Lines = @(
        '<#'
        '.DESCRIPTION'
        "    $clOpen"
        '      1. the first thing.'
        '#>'
        '# --- 1. the first thing -------------------------------------------------'
        '$a = 1'
    )
    [System.IO.File]::WriteAllText($s62Path, (($s62Lines -join "`n") + "`n"), $Utf8NoBom)
    $rC62 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($rC62.Out -match 'listed-unpaired\.ps1:.*has no matching') 'scenario 62: the opener without a closer is a hard error, not a silent skip'
    Remove-Item -LiteralPath $s62Path -Force

    $s62bPath  = Join-Path $s58Dir 'listed-unmarked.ps1'
    $s62bLines = @(
        '# --- 1. the first thing -------------------------------------------------'
        '$a = 1'
        ''
        '# --- 2. the second thing ------------------------------------------------'
        '$b = 2'
    )
    [System.IO.File]::WriteAllText($s62bPath, (($s62bLines -join "`n") + "`n"), $Utf8NoBom)
    $rC62b = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rC62b.Out -match 'listed-unmarked\.ps1')) 'scenario 62: a file with headers and no marker claims nothing, so it is not a subject'
    Assert-True ($rC62b.Out -match '\[check-list\] checked \d+') 'scenario 62: and the check still reports its coverage, so opting out is not the same as not running'
    Remove-Item -LiteralPath $s62bPath -Force

    # --- Scenario 63: a nested enumeration inside an entry's prose is not a claim --------------------
    #     Found by PROBING the check rather than by measuring the tree -- the real list contains no such
    #     shape, so no measurement of it would have surfaced this (check 35's lesson, applied to its
    #     neighbour). A number opening a line is ordinary inside an entry's prose, and counting one as a
    #     claim silences the check exactly where it matters: the nested pair below would keep satisfying
    #     headers that had been dropped from the list, with the gate green.
    Write-Host "check 37 -- a number opening a line inside an entry's prose is not a claim" -ForegroundColor Cyan
    $s63Path  = Join-Path $s58Dir 'listed-nested.ps1'
    $s63Lines = @(
        '<#'
        '.DESCRIPTION'
        "    $clOpen"
        '      1. the first thing.'
        '      2. the second thing, which documents two cases of its own:'
        '         3. the first case -- indented past the gutter, so it is prose, not an entry.'
        '         4. the second case.'
        "    $clClose"
        '#>'
        '# --- 1. the first thing -------------------------------------------------'
        '$a = 1'
        ''
        '# --- 2. the second thing ------------------------------------------------'
        '$b = 2'
        ''
        '# --- 3. the one the nested list would have covered for -------------------'
        '$c = 3'
    )
    [System.IO.File]::WriteAllText($s63Path, (($s63Lines -join "`n") + "`n"), $Utf8NoBom)
    $rC63 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($rC63.Out -match 'listed-nested\.ps1:16:.*check 3 has a section header but no entry') 'scenario 63: the nested 3. does not satisfy header 3 -- the gap is still reported'
    Assert-Equal 1 ([regex]::Matches($rC63.Out, $ClFindingPattern).Count) 'scenario 63: and the nested 4., which matches no header, adds nothing -- exactly one finding'
    Remove-Item -LiteralPath $s63Path -Force

    # --- Scenario 64: two spans in one file are unioned and counted once -----------------------------
    #     Run inside the span callback this counted each header once PER SPAN, so a second span doubled
    #     the coverage figure and named one missing entry twice -- one defect, two owners, which is what
    #     the first-occurrence rule for headers already avoids. A split list still enumerates one file,
    #     so the union is the tolerant reading rather than an error of its own.
    Write-Host "check 37 -- two spans are read as one list, and a gap is named once" -ForegroundColor Cyan
    $s64Path  = Join-Path $s58Dir 'listed-twospans.ps1'
    $s64Lines = @(
        '<#'
        '.DESCRIPTION'
        '    The early checks:'
        "    $clOpen"
        '      1. the first thing.'
        "    $clClose"
        '    And the later ones:'
        "    $clOpen"
        '      2. the second thing.'
        "    $clClose"
        '#>'
        '# --- 1. the first thing -------------------------------------------------'
        '$a = 1'
        ''
        '# --- 2. the second thing ------------------------------------------------'
        '$b = 2'
        ''
        '# --- 3. the one in neither span ------------------------------------------'
        '$c = 3'
    )
    [System.IO.File]::WriteAllText($s64Path, (($s64Lines -join "`n") + "`n"), $Utf8NoBom)
    $rC64 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 ([regex]::Matches($rC64.Out, $ClFindingPattern).Count) 'scenario 64: the header in neither span is one finding, not one per span'
    Assert-True ($rC64.Out -match "any of this file's 2 'checks:list' spans \(lines 4, 8\)") 'scenario 64: and the finding names both spans, since either could hold the entry'
    Remove-Item -LiteralPath $s64Path -Force

    # Check 31's finding pattern, defined here because the script-set scenarios below assert it. While
    # check 31's own scenarios shared this file they defined it and these simply read it; the split put
    # them in -script-rules, so the pattern is stated again rather than inherited across a file boundary.
    $ShopifyFindingPattern = '\[shopify-cli\].*invokes the Shopify CLI bare'

    # --- the SET every script-layer check shares: a plugin's templates/ is inside it -----------------
    #     Issue #1998. Get-PsScriptFiles used to anchor on three named subtrees inside plugins/ --
    #     skills/, scripts/ and hooks/ -- and ONE tracked file sat in none of them:
    #     plugins/dkj-policy/dkj-policy-bwj/templates/asana-mirror.ps1, 1812 lines. Checks 5 (parse), 27
    #     (script-ascii), 33 (shopify-cli), 36 (section-number) and 42b (exec-policy/script) had
    #     therefore never read a line of it.
    #
    #     WHY IT IS ASSERTED HERE RATHER THAN BY COUNTING THE SET. A coverage number would pin the
    #     arithmetic of one tree and go stale on the next file anybody adds -- the tally shape this repo
    #     has scar tissue from. What these scenarios pin is the PROPERTY: put a defect in a plugin's
    #     templates/ and the gate must find it. That holds whatever the count is.
    #
    #     TWO CHECKS, NOT ONE, because they reach the file by different routes and could regress apart:
    #     check 5 parses each file itself, while check 33 reads the shared CommandAst cache built over
    #     the same set (#1358). A set change that fed one and not the other would pass a single assert.
    #
    #     AND THE FILE IS NAMED asana-mirror.ps1 on purpose: adopt-dkj-policy-bwj copies that real file
    #     into a consumer's repo as .github/scripts/asana-mirror.ps1, where it runs in their CI holding
    #     `issues: write`. A parse error in it reaches them and not us, which is check 5's own argument
    #     for existing.
    Write-Host "the shared script set -- a .ps1 under a plugin's templates/ is read (#1998)" -ForegroundColor Cyan
    $tplDir = Join-Path $Fixture 'plugins\dkj-policy\templates'
    New-Item -ItemType Directory -Path $tplDir -Force | Out-Null

    # Scenario 80: check 5 reaches it. An unclosed brace, so the parser has something to object to.
    $s80Path = Join-Path $tplDir 'asana-mirror.ps1'
    [System.IO.File]::WriteAllText($s80Path, "function Invoke-Mirror {`n    if (`$true) {`n", $Utf8NoBom)
    # -Full, AND IT IS THE ONLY CALL IN THIS SUITE THAT NEEDS IT: $SkippedForSpeed names 'parse', so the
    # ordinary invocation cannot see check 5 at all. Written without it first, and the scenario failed
    # while its two siblings passed -- which is worth leaving here, because that is what the gap looks
    # like from the outside and the next reader will reach for the same one-liner.
    $rC80 = Invoke-Integrity -FixtureRoot $Fixture -Full
    Assert-True ($rC80.Out -match '\[parse\] .*asana-mirror\.ps1') 'scenario 80: a parse error in a plugin templates/ script is reported at all'
    Remove-Item -LiteralPath $s80Path -Force

    # Scenario 81: and the AST-reading checks reach it too, off the shared cache rather than their own
    # parse. Syntactically valid this time -- a file the parser accepts is the only kind check 33 can
    # have an opinion about.
    [System.IO.File]::WriteAllText($s80Path, ((@(
        '$ErrorActionPreference = ''Stop'''
        '& shopify theme list --store x'
    ) -join "`n") + "`n"), $Utf8NoBom)
    $rC81 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rC81.Out -match '\[parse\] .*asana-mirror\.ps1')) 'scenario 81: the valid file parses cleanly, so what follows is not the parse finding again'
    Assert-True ($rC81.Out -match $ShopifyFindingPattern) 'scenario 81: and the bare CLI call in a plugin templates/ script is a finding'
    Assert-True ($rC81.Out -match 'asana-mirror\.ps1:2:') 'scenario 81: named with its line, so the set really carried this file and not a sibling'
    Remove-Item -LiteralPath $s80Path -Force

    # Scenario 82: and the layer is not blanket-noisy -- a clean templates/ script reports nothing. The
    # guard against a repair that widens the set by making it accuse whatever it newly reads.
    [System.IO.File]::WriteAllText($s80Path, "`$ErrorActionPreference = 'Stop'`nWrite-Host 'mirrored'`n", $Utf8NoBom)
    $rC82 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rC82.Out -match 'asana-mirror\.ps1')) 'scenario 82: a clean plugin templates/ script draws no finding of any kind'
    Remove-Item -LiteralPath $s80Path -Force

    # --- check 44: a prompting Shopify theme call carries --force ------------------------------------
    #     Inbound #2031. backup-live-theme.ps1 duplicated the live theme without --force and so failed at
    #     step 1/3 in EVERY agent session, while both BWJ consumer repos name that script as the closing
    #     step of a release cut. It failed CLEANLY -- nothing created, nothing rotated, and a message
    #     correctly saying the previous backup still stood -- which is exactly why a store went a release
    #     without a baseline while every document said it had one.
    #
    #     THE SET IS MEASURED, and these scenarios are what pins it: against Shopify CLI 4.8.0, exactly
    #     three of the seventeen 'theme' subcommands declare a -f/--force flag (delete, duplicate,
    #     publish), all three documenting it as "Required if non interactive". 'pull' and 'push' accept
    #     no such flag, so scenario 86 is not a nicety -- a check that demanded --force there would make
    #     the gate insist on an argument the CLI would reject.
    #
    #     SCENARIO 85 IS THE ONE THAT WOULD HAVE CAUGHT THE CHECK'S OWN FIRST CUT. That version read an
    #     ArrayLiteralAst at the call site and both spellings at an assignment -- but `@(...)` written
    #     directly as an argument parses as an ArrayExpressionAst, so it resolved 2 of 30 real call sites
    #     and reported 0 findings. Green, and blind to 'theme delete --force', the one call in the tree
    #     that proves the rule. Both spellings are asserted here so one reader cannot regrow into two.
    #
    #     Matched on the error phrase rather than the bare '[shopify-force]' tag, which also prefixes the
    #     coverage line present on every run -- the same trap the check 11, 31 and 33 patterns document.
    $ForceFindingPattern = '\[shopify-force\].*is invoked without --force'
    $s83Dir = Join-Path $Fixture 'scripts\task'
    New-Item -ItemType Directory -Path $s83Dir -Force | Out-Null
    $s83Path = Join-Path $s83Dir 'theme-thing.ps1'

    # --- Scenario 83: an inline @(...) missing the flag is a finding, and it names the line ----------
    Write-Host "check 44 -- an inline 'theme duplicate' without --force is reported with its line" -ForegroundColor Cyan
    [System.IO.File]::WriteAllText($s83Path, ((@(
        '$ErrorActionPreference = ''Stop'''
        '# A comment naming theme duplicate must NOT be a subject -- only a CommandAst is.'
        '$d = Invoke-ShopifyCli -Arguments @(''theme'', ''duplicate'', ''--store'', $s, ''--name'', $n)'
    ) -join "`n") + "`n"), $Utf8NoBom)
    $rC83 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($rC83.Out -match $ForceFindingPattern) 'scenario 83: the flagless duplicate is a finding'
    Assert-True ($rC83.Out -match 'theme-thing\.ps1:3:') 'scenario 83: and it names the line the call is on, not the file alone'
    Assert-Equal 1 ([regex]::Matches($rC83.Out, $ForceFindingPattern).Count) 'scenario 83: the comment is NOT a subject -- exactly one finding'

    # --- Scenario 84: the same call carrying the flag is clean --------------------------------------
    Write-Host "check 44 -- the same call with --force draws nothing" -ForegroundColor Cyan
    [System.IO.File]::WriteAllText($s83Path, ((@(
        '$ErrorActionPreference = ''Stop'''
        '$d = Invoke-ShopifyCli -Arguments @(''theme'', ''duplicate'', ''--store'', $s, ''--force'')'
    ) -join "`n") + "`n"), $Utf8NoBom)
    $rC84 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rC84.Out -match $ForceFindingPattern)) 'scenario 84: --force present, so nothing is reported'

    # --- Scenario 85: -Arguments naming a VARIABLE is resolved, both ways ---------------------------
    #     The shape the #2031 repair itself uses: the list is built once so the dry run cannot print a
    #     command different from the one that runs. A check that could not follow it would have been
    #     born blind to the very call site it was written for.
    Write-Host "check 44 -- a variable holding the argument list is followed, in both directions" -ForegroundColor Cyan
    [System.IO.File]::WriteAllText($s83Path, ((@(
        '$ErrorActionPreference = ''Stop'''
        '$args1 = @(''theme'', ''publish'', ''--store'', $s, ''--theme'', $id)'
        '$p = Invoke-ShopifyCli -Arguments $args1'
    ) -join "`n") + "`n"), $Utf8NoBom)
    $rC85 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($rC85.Out -match $ForceFindingPattern) 'scenario 85: a flagless list reached through a variable is still a finding'
    Assert-True ($rC85.Out -match 'theme-thing\.ps1:3:') 'scenario 85: reported at the CALL, which is the line a reader has to change'
    [System.IO.File]::WriteAllText($s83Path, ((@(
        '$ErrorActionPreference = ''Stop'''
        '$args1 = @(''theme'', ''publish'', ''--store'', $s, ''--force'')'
        '$p = Invoke-ShopifyCli -Arguments $args1'
    ) -join "`n") + "`n"), $Utf8NoBom)
    $rC85b = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rC85b.Out -match $ForceFindingPattern)) 'scenario 85: and the flag is seen through the variable too, so the variable lane is not write-only'

    # --- Scenario 86: pull and push are NOT subjects, because they accept no --force ----------------
    #     Out of scope BY MEASUREMENT, not by exemption. Demanding the flag here would have the gate
    #     insist on an argument the CLI rejects -- the failure mode of a rule reasoned about rather than
    #     measured, which this repo has declined before at 124 findings all false.
    Write-Host "check 44 -- 'theme pull' and 'theme push' accept no --force and are not subjects" -ForegroundColor Cyan
    [System.IO.File]::WriteAllText($s83Path, ((@(
        '$ErrorActionPreference = ''Stop'''
        '$a = Invoke-ShopifyCli -Arguments @(''theme'', ''pull'', ''--store'', $s, ''--path'', $p)'
        '$b = Invoke-ShopifyCli -Arguments @(''theme'', ''push'', ''--store'', $s, ''--theme'', $id)'
        '$c = Invoke-ShopifyCli -Arguments @(''theme'', ''list'', ''--store'', $s, ''--json'')'
    ) -join "`n") + "`n"), $Utf8NoBom)
    $rC86 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rC86.Out -match $ForceFindingPattern)) 'scenario 86: no finding for pull, push or list -- none of them takes the flag'

    # --- Scenario 87: an unreadable argument list is COUNTED, never a finding -----------------------
    #     A list returned by a function is exactly what push-preview does (Get-ThemeCreateArgs), and a
    #     check that guessed at it would be inventing the bytes under test. It must say what it could
    #     not see rather than pass over it in silence or accuse it.
    Write-Host "check 44 -- an argument list it cannot read is named in the coverage, not accused" -ForegroundColor Cyan
    [System.IO.File]::WriteAllText($s83Path, ((@(
        '$ErrorActionPreference = ''Stop'''
        '$x = Invoke-ShopifyCli -Arguments (Get-SomeArgs -Store $s)'
    ) -join "`n") + "`n"), $Utf8NoBom)
    $rC87 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rC87.Out -match $ForceFindingPattern)) 'scenario 87: an unresolvable list is not a finding'
    Assert-True ($rC87.Out -match 'NOT REACHED:.*theme-thing\.ps1:2') 'scenario 87: and it is named in the coverage line, so the check states its own reach'
    Remove-Item -LiteralPath $s83Path -Force

} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Complete-IntegritySuite
