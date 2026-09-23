<#
.SYNOPSIS
    check-plugin-integrity.ps1, three rules over printed output and the script layer: check 33
    (printed instructions naming a model-barred skill), check 31 (the Shopify CLI is never invoked
    bare) and check 34 (a numbered section header is unique, ascending, and in one form).

.DESCRIPTION
    The fixture, the assert helpers and Invoke-Integrity live in check-plugin-integrity-fixture.ps1,
    which also records why this suite family is more than one file. Split out of -commands under #2304.

    Each of the three reads the parser rather than matching lines, so a comment quoting the forbidden
    shape is never a subject -- the reason check 33's scenario 46 exists, and the reason check 34's own
    scenario separators in this file are indented (scenario 57).

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'check-plugin-integrity-fixture.ps1')

$Fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("check-plugin-integrity-script-rules-$PID-$([guid]::NewGuid().ToString('n'))")

try {
    New-IntegrityFixture -Fixture $Fixture
    # The root documents as check 4's scenario B leaves them -- see Write-QuietRootDocuments for why this
    # suite states that starting point instead of inheriting it from a scenario in another file.
    Write-QuietRootDocuments -Fixture $Fixture

    # --- check 33: a printed instruction must not name a skill barred to its reader -------------------
    # The class #731 -> #734 repaired once and #1093/#1096 rediscovered from scratch a month later. The
    # fixture's skill-beta carries 'disable-model-invocation: true' and skill-alpha does not, which is
    # the pair every scenario below turns on: the SAME sentence about the two must come out differently.
    #
    # Matched on the error phrase rather than the bare '[barred-skill]' tag -- that tag also prefixes the
    # coverage line, which is present on every run. Same trap the check 10 and check 11 patterns document.
    $BarredFindingPattern = "\[barred-skill\].*tells its reader to run the"

    # --- Scenario 42: a printed message naming a BARRED skill fails ----------------------------------
    Write-Host "check 33 -- a printed instruction naming a barred skill fails" -ForegroundColor Cyan
    $s42Lines = @(
        '$ErrorActionPreference = ''Stop'''
        'Write-Host "  [STOP] nothing is set up here -- run the skill-beta skill first."'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'scripts\probe.ps1'), (($s42Lines -join "`n") + "`n"), $Utf8NoBom)
    $rB42 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 $rB42.Code 'scenario 42: exit 1 -- naming a barred skill is an error'
    Assert-True ($rB42.Out -match [regex]::Escape('probe.ps1:2') + ".*tells its reader to run the 'skill-beta' skill") 'scenario 42: the finding names the file, the line and the skill'
    Assert-True ($rB42.Out -match '/skill-beta') 'scenario 42: and hands over the slash-command form as the remedy'
    Assert-True ($rB42.Out -match '\[barred-skill\] checked [1-9]') 'scenario 42: and the set WAS examined -- the failure is not an empty scan'

    # --- Scenario 43: the SAME sentence about an UNFLAGGED skill passes ------------------------------
    #     The scenario that keeps this from being a phrasing rule. check-script-contract.ps1 names
    #     'adopt-dkj-policy' with exactly this wording in the real tree and is correct to; a check
    #     built as a grep for the phrasing would be born with that false finding.
    Write-Host "check 33 -- the same wording about an UNFLAGGED skill passes" -ForegroundColor Cyan
    $s43Lines = @(
        '$ErrorActionPreference = ''Stop'''
        'Write-Host "  [STOP] nothing is set up here -- run the skill-alpha skill first."'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'scripts\probe.ps1'), (($s43Lines -join "`n") + "`n"), $Utf8NoBom)
    $rB43 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rB43.Out -match $BarredFindingPattern)) 'scenario 43: an unflagged skill may be named with a bare imperative'

    # --- Scenario 44: the DISCRIMINATOR -- an imperative without the word 'skill' passes -------------
    #     Measured on the real tree: without this, 8 unique sites of which 4 are wrong. Three of the four
    #     name the SCRIPT rather than the skill, which is a correct instruction to a reader who has just
    #     run it.
    Write-Host "check 33 -- naming the script rather than the skill passes" -ForegroundColor Cyan
    $s44Lines = @(
        '$ErrorActionPreference = ''Stop'''
        'Write-Host "  that push failed -- run skill-beta by hand for the reason."'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'scripts\probe.ps1'), (($s44Lines -join "`n") + "`n"), $Utf8NoBom)
    $rB44 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rB44.Out -match $BarredFindingPattern)) 'scenario 44: without the word "skill" it is a script name, not a route to a page'

    # --- Scenario 45: a HYPHENATED continuation is not the barred name ------------------------------
    #     The false finding the naive rule really produced: '\bpark\b' matches inside 'park-cycle',
    #     because a hyphen is a non-word character. The check's own boundary is (?![\w-]).
    Write-Host "check 33 -- a longer hyphenated name is not the barred one" -ForegroundColor Cyan
    $s45Lines = @(
        '$ErrorActionPreference = ''Stop'''
        'Write-Host "  run the skill-beta-helper skill to finish up."'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'scripts\probe.ps1'), (($s45Lines -join "`n") + "`n"), $Utf8NoBom)
    $rB45 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rB45.Out -match $BarredFindingPattern)) 'scenario 45: skill-beta-helper is a different name, not skill-beta with a suffix'

    # --- Scenario 46: a COMMENT carrying the wording passes ------------------------------------------
    #     The reason this reads the PowerShell parser instead of matching lines: every comment explaining
    #     the rule -- check 33's own included -- has to quote the wording it forbids.
    Write-Host "check 33 -- the same wording in a COMMENT is not an instruction" -ForegroundColor Cyan
    $s46Lines = @(
        '$ErrorActionPreference = ''Stop'''
        '# This used to say "run the skill-beta skill", which is the defect this comment records.'
        'Write-Host "  nothing to do here."'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'scripts\probe.ps1'), (($s46Lines -join "`n") + "`n"), $Utf8NoBom)
    $rB46 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rB46.Out -match $BarredFindingPattern)) 'scenario 46: a comment is not printed output, so it is not a subject'

    # --- Scenario 47: MARKDOWN is a subject too ------------------------------------------------------
    #     Measured: printed output carried 6 of the 7 real sites and INSTALL.md the seventh -- the one a
    #     consumer actually reads. An output-only check would have passed straight over it.
    Write-Host "check 33 -- a shipped markdown page is a subject as well" -ForegroundColor Cyan
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'scripts\probe.ps1'), "`$ErrorActionPreference = 'Stop'`n", $Utf8NoBom)
    $s47Lines = @(
        '# Contributing'
        ''
        'When the roster drifts, run the `skill-beta` skill to stage the catch-up.'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s47Lines -join "`n") + "`n"), $Utf8NoBom)
    $rB47 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-Equal 1 $rB47.Code 'scenario 47: exit 1 -- a shipped page may not name a barred skill either'
    Assert-True ($rB47.Out -match [regex]::Escape('CONTRIBUTING.md:3') + ".*'skill-beta'") 'scenario 47: the finding names the markdown file and its line'

    # --- Scenario 48: the REPAIRED wording passes ----------------------------------------------------
    #     The shape every one of the seven real sites was rewritten into, asserted so the check and the
    #     repair cannot drift apart: name the command, and say who types it.
    Write-Host "check 33 -- the repaired wording passes" -ForegroundColor Cyan
    $s48Lines = @(
        '# Contributing'
        ''
        'When the roster drifts, type `/dkj-subagents-alpha:skill-beta` to stage the catch-up -- that command is'
        'reserved for explicit user invocation, so a session hands it to you rather than running it.'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s48Lines -join "`n") + "`n"), $Utf8NoBom)
    $rB48 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rB48.Out -match $BarredFindingPattern)) 'scenario 48: naming the command and the actor is what the check asks for'
    Remove-Item -LiteralPath (Join-Path $Fixture 'scripts\probe.ps1') -Force -ErrorAction SilentlyContinue


    # --- Scenario 49: a FENCED example is an illustration, not an instruction ------------------------
    #     How this exclusion was found: the branch that added check 33 quotes the forbidden wording in its
    #     own plan in order to explain what the check forbids, and the gate refused to push it. A rule that
    #     cannot be written down in the document introducing it is a rule nobody can explain. Checks 10 and
    #     11 mask fences for the same reason, and this borrows their Get-FenceMaskedText.
    Write-Host "check 33 -- a fenced example of the wording is not an instruction" -ForegroundColor Cyan
    $s49Lines = @(
        '# Contributing'
        ''
        'Do not write this:'
        ''
        '```text'
        'run the skill-beta skill to stage the catch-up'
        '```'
        ''
        'Write the command and say who types it instead.'
    )
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), (($s49Lines -join "`n") + "`n"), $Utf8NoBom)
    $rB49 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rB49.Out -match $BarredFindingPattern)) 'scenario 49: a fenced example is masked, so the rule can be written down'

    # --- Scenario 50: HISTORY is excluded ------------------------------------------------------------
    #     Check 11's exclusion, inherited with its file set: CHANGELOG.md records what was true then and is
    #     never rewritten, so a released note describing the old wording must not become a finding. Asserted
    #     rather than assumed, because the set is borrowed and a later narrowing of check 11's would move
    #     this check in silence.
    Write-Host "check 33 -- history is not rewritten, so it is not a subject" -ForegroundColor Cyan
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'CONTRIBUTING.md'), "# Contributing`n`nNothing here.`n", $Utf8NoBom)
    $s50Path = Join-Path $Fixture 'dkj-policy\CHANGELOG.md'
    $s50Prev = if (Test-Path -LiteralPath $s50Path) { [System.IO.File]::ReadAllText($s50Path, [System.Text.Encoding]::UTF8) } else { $null }
    $s50Lines = @(
        '# Changelog'
        ''
        '## [Unreleased]'
        ''
        'The line then read: run the skill-beta skill to stage the catch-up.'
    )
    [System.IO.File]::WriteAllText($s50Path, (($s50Lines -join "`n") + "`n"), $Utf8NoBom)
    $rB50 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rB50.Out -match $BarredFindingPattern)) 'scenario 50: the changelog records the old wording and is never rewritten'
    if ($null -ne $s50Prev) { [System.IO.File]::WriteAllText($s50Path, $s50Prev, $Utf8NoBom) } else { Remove-Item -LiteralPath $s50Path -Force -ErrorAction SilentlyContinue }


    # --- check 31: the Shopify CLI is never invoked bare ---------------------------------------------
    #     Inbound #1183. Under $ErrorActionPreference = 'Stop' -- which every script here sets -- one
    #     stderr line from the CLI is a TERMINATING ErrorRecord, so a bare call dies on the line AFTER it
    #     and the $LASTEXITCODE check below it never runs. The wrapper is scripts/lib/shopify-cli-lib.ps1;
    #     what this check exists for is that THE DANGEROUS FORM IS THE ABSENCE OF ONE -- there is no
    #     redirect to grep for, so a convention alone produced four bare sites before anybody noticed.
    #
    #     Matched on the error phrase rather than the bare '[shopify-cli]' tag: that tag also prefixes the
    #     coverage line, which is present on every run. Same trap the check 11 and check 33 patterns document.
    $ShopifyFindingPattern = '\[shopify-cli\].*invokes the Shopify CLI bare'
    New-Item -ItemType Directory -Path (Join-Path $Fixture 'scripts\task') -Force | Out-Null

    # --- Scenario 51: a bare call is a finding, and it names the line --------------------------------
    Write-Host "check 31 -- a bare '& shopify' call is reported with its line" -ForegroundColor Cyan
    $s51Path  = Join-Path $Fixture 'scripts\task\sync-something.ps1'
    $s51Lines = @(
        '$ErrorActionPreference = ''Stop'''
        '# A comment naming shopify theme list must NOT be a subject -- only a CommandAst is.'
        'Write-Host "run: shopify theme list --store x"'
        '& shopify theme pull --store x --theme 1 --path y'
        'if ($LASTEXITCODE -ne 0) { exit 1 }'
    )
    [System.IO.File]::WriteAllText($s51Path, (($s51Lines -join "`n") + "`n"), $Utf8NoBom)
    $rC51 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($rC51.Out -match $ShopifyFindingPattern) 'scenario 51: the bare call is a finding'
    Assert-True ($rC51.Out -match 'sync-something\.ps1:4:') 'scenario 51: and it names the line the call is on, not the file alone'
    Assert-Equal 1 ([regex]::Matches($rC51.Out, $ShopifyFindingPattern).Count) 'scenario 51: the comment and the printed hint are NOT subjects -- exactly one finding'

    # --- Scenario 52: the wrapper itself is exempt, by name ------------------------------------------
    #     The one permitted bare call lives inside the wrapper, so the check would otherwise report the
    #     repair as the defect. Matched on the file NAME rather than a full path, which is what makes the
    #     plugin mirror exempt too -- the same file, one directory tree over, and check 8 already holds
    #     the two byte-identical.
    Write-Host "check 31 -- the wrapper holds the one permitted call and is exempt" -ForegroundColor Cyan
    Remove-Item -LiteralPath $s51Path -Force
    $s52Path = Join-Path $Fixture 'scripts\lib\shopify-cli-lib.ps1'
    [System.IO.File]::WriteAllText($s52Path, "function Invoke-ShopifyCli {`n    & shopify @args`n}`n", $Utf8NoBom)
    $rC52 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rC52.Out -match $ShopifyFindingPattern)) 'scenario 52: the wrapper is not reported for holding the call it exists to hold'
    Remove-Item -LiteralPath $s52Path -Force


    # --- check 34: a numbered section header is unique, ascending, and in one form -------------------
    #     Issue #1494. Two unrelated checks in check-plugin-integrity.ps1 both carried the number 30, and
    #     both were already load-bearing in published release notes pointing at DIFFERENT checks. The
    #     numbers were prose -- hand-assigned, cited everywhere, read back by nothing -- in the one file
    #     whose purpose is refusing a hand-maintained list a machine could check.
    #
    #     THE HEADERS IN THIS SUITE ARE INDENTED ON PURPOSE, including the one directly above. Scenario
    #     separators inside a function are not file sections and carry their own numbering; scenario 57
    #     is the assert that keeps them out of the check's reach, so this suite is its own fixture for
    #     that bound.
    #
    #     Matched on the finding phrases rather than the bare '[section-number]' tag: that tag also
    #     prefixes the coverage line, which is present on every run. Same trap the check 11, 33 and 31 patterns
    #     document.
    $SectionFindingPattern = '\[section-number\].*(is already used at line|no longer ascend|second form)'
    $s53Dir = Join-Path $Fixture 'scripts\task'
    New-Item -ItemType Directory -Path $s53Dir -Force | Out-Null

    # --- Scenario 53: two sections sharing a number is a finding, naming BOTH lines ------------------
    #     The measured defect itself. Naming only the second line would leave a reader to hunt for the
    #     first, which is the search that returned two answers in the first place.
    Write-Host "check 34 -- two sections sharing a number is a finding, at both lines" -ForegroundColor Cyan
    $s53Path  = Join-Path $s53Dir 'numbered-dupe.ps1'
    $s53Lines = @(
        '# --- 1. the first thing -------------------------------------------------'
        '$a = 1'
        ''
        '# --- 2. the second thing ------------------------------------------------'
        '$b = 2'
        ''
        '# --- 2. an unrelated thing that took a taken number ----------------------'
        '$c = 3'
    )
    [System.IO.File]::WriteAllText($s53Path, (($s53Lines -join "`n") + "`n"), $Utf8NoBom)
    $rC53 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($rC53.Out -match 'section number 2 is already used at line 4') 'scenario 53: the duplicate is a finding and names the line the number was first used on'
    Assert-True ($rC53.Out -match 'numbered-dupe\.ps1:7:') 'scenario 53: and it is reported at the LATER of the two, which is the one that has to move'
    Assert-Equal 1 ([regex]::Matches($rC53.Out, $SectionFindingPattern).Count) 'scenario 53: one duplicate is one finding -- the ascending rule does not report it a second time'
    Remove-Item -LiteralPath $s53Path -Force

    # --- Scenario 54: a number that goes backwards is a finding --------------------------------------
    #     Ascending order is the property that leaves a new section exactly one legal number, so it is
    #     what prevents the duplicate rather than merely tidying the file. Renumbering a colliding check
    #     without moving it satisfies uniqueness and lands here instead, which is the case this asserts:
    #     it is what a repair of scenario 53 looks like if the block is left where it was.
    Write-Host "check 34 -- a section number that goes backwards is a finding" -ForegroundColor Cyan
    $s54Path  = Join-Path $s53Dir 'numbered-desc.ps1'
    $s54Lines = @(
        '# --- 1. the first thing -------------------------------------------------'
        '$a = 1'
        ''
        '# --- 9. renumbered out of the way but left where it sat ------------------'
        '$b = 2'
        ''
        '# --- 2. the section it was inserted above --------------------------------'
        '$c = 3'
    )
    [System.IO.File]::WriteAllText($s54Path, (($s54Lines -join "`n") + "`n"), $Utf8NoBom)
    $rC54 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($rC54.Out -match 'section number 2 sits after 9 at line 4') 'scenario 54: the descent is a finding and names what it came after'
    Assert-True ($rC54.Out -match 'numbered-desc\.ps1:7:') 'scenario 54: reported at the header that broke the order'
    Remove-Item -LiteralPath $s54Path -Force

    # --- Scenario 55: the second spelling is a finding wherever it appears ---------------------------
    #     Four headers in the gate read '# --- Check <n>: ' where the rest read '# --- <n>. ', so no
    #     single pattern listed them all and the duplicate showed up in a grep of neither. Passing over
    #     an unrecognised spelling would let a file opt out of the numbering rule entirely.
    Write-Host "check 34 -- the second header spelling is a finding" -ForegroundColor Cyan
    $s55Path  = Join-Path $s53Dir 'numbered-form.ps1'
    $s55Lines = @(
        '# --- 1. the first thing -------------------------------------------------'
        '$a = 1'
        ''
        '# --- Check 2: the same thing said the other way --------------------------'
        '$b = 2'
    )
    [System.IO.File]::WriteAllText($s55Path, (($s55Lines -join "`n") + "`n"), $Utf8NoBom)
    $rC55 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($rC55.Out -match 'numbered-form\.ps1:4:.*second form') 'scenario 55: the other spelling is reported, at its own line'
    Assert-True ($rC55.Out -match "Rewrite it as '# --- 2\. ") 'scenario 55: and the finding says what to write instead, in the legal form'
    Remove-Item -LiteralPath $s55Path -Force

    # --- Scenario 56: gaps and lettered sub-sections are legal ---------------------------------------
    #     Both are deliberate conventions in the gate: 9, 17 and 19 are retired checks whose numbers are
    #     NOT reused (reusing one would silently repoint every older citation), and 3b/3c/13b are
    #     sub-sections of the check above them. A rule that reported either would be the gate inventing a
    #     convention the repo declined -- the narrowing check 26 had to make for the same reason.
    Write-Host "check 34 -- a gap and a lettered sub-section are not findings" -ForegroundColor Cyan
    $s56Path  = Join-Path $s53Dir 'numbered-clean.ps1'
    $s56Lines = @(
        '# --- 3. the first thing -------------------------------------------------'
        '$a = 1'
        ''
        '# --- 3b. a sub-section of it ---------------------------------------------'
        '$b = 2'
        ''
        '# --- 3c. and another -----------------------------------------------------'
        '$c = 3'
        ''
        '# --- 7. after a gap where two retired checks stood ------------------------'
        '$d = 4'
        ''
        '# --- Report --------------------------------------------------------------'
        '$e = 5'
    )
    [System.IO.File]::WriteAllText($s56Path, (($s56Lines -join "`n") + "`n"), $Utf8NoBom)
    $rC56 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rC56.Out -match 'numbered-clean\.ps1')) 'scenario 56: a gap, three lettered sub-sections and an unnumbered terminator are all legal'
    Remove-Item -LiteralPath $s56Path -Force

    # --- Scenario 57: an INDENTED header is not a subject --------------------------------------------
    #     The bound the whole check rests on, and the one it would be easiest to get wrong: this suite
    #     and its three siblings use the same '# ---' marker indented inside a function to separate
    #     scenarios, under their own numbering, which restarts and repeats freely. Those are not file
    #     sections. Written as a fixture rather than left to the suites' own headers so the assert says
    #     what it is proving instead of depending on this file staying shaped as it is.
    Write-Host "check 34 -- an indented header belongs to its block, not to the file" -ForegroundColor Cyan
    $s57Path  = Join-Path $s53Dir 'numbered-indented.ps1'
    $s57Lines = @(
        'function Test-Something {'
        '    # --- 1. a scenario separator inside a function ------------------------'
        '    $a = 1'
        '    # --- 1. the same number again, one block down -------------------------'
        '    $b = 2'
        '    # --- Check 1: and in the other spelling -------------------------------'
        '    $c = 3'
        '}'
    )
    [System.IO.File]::WriteAllText($s57Path, (($s57Lines -join "`n") + "`n"), $Utf8NoBom)
    $rC57 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($rC57.Out -match 'numbered-indented\.ps1')) 'scenario 57: three headers that would all be findings at column 0 are passed over when indented'
    Assert-True ($rC57.Out -match '\[section-number\] checked \d+') 'scenario 57: and the check still reports its coverage, so passing over is not the same as not running'
    Remove-Item -LiteralPath $s57Path -Force

} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Complete-IntegritySuite
