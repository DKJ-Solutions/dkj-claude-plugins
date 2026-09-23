<#
.SYNOPSIS
    check-plugin-integrity.ps1, the script-layer checks: a shared script's parameters against the
    skill that documents it (18), a depth-sensitive $PSScriptRoot resolution declaring the suite
    that runs it (39), a plugin script loading only a lib its OWN plugin ships (40), the script
    layer's pure-ASCII rule (27), and a test fixture's own git command (35).

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

$Fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("check-plugin-integrity-scripts-$PID-$([guid]::NewGuid().ToString('n'))")

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
    Assert-True ($c5.Out -match '\[JSON\].*is not valid JSON') `
        'corrupt marketplace: and it IS named as malformed -- the half scenario 55b must not collide with'
    [System.IO.File]::WriteAllText((Join-Path $Fixture '.claude-plugin\marketplace.json'), $goodMarketplace, $Utf8NoBom)

    # --- Scenario 55b: A VALID MANIFEST THIS READER CANNOT READ IS NOT CALLED MALFORMED -------------
    # 55b. ISSUE #2003, and it is scenario 55's mirror image. Windows PowerShell 5.1's ConvertFrom-Json
    #      folds object keys case-insensitively and then refuses the collision it made itself, so a
    #      VALID document carrying '.c' beside '.C' throws at the same line a malformed one does -- and
    #      was reported with the same words. The accusation is the kind a reader ACTS on, by editing a
    #      file that has nothing wrong with it.
    #
    #      THE DOCUMENT HERE IS THE REAL CASE, not an invention: the official marketplace's
    #      lspServers.clangd.extensionToLanguage map legitimately lists both spellings, and it is the
    #      manifest this repo's own consumers install from.
    #
    #      Invoke-Integrity runs the gate through 'powershell', which on Windows is always 5.1, so this
    #      scenario is deterministic. Under PowerShell 7 ConvertFrom-Json is case-sensitive, the file
    #      parses, and there is no finding to assert at all -- which is the correct behaviour there and
    #      the reason the repair diagnoses rather than refuses.
    # THE FIXTURE'S OWN MARKETPLACE PLUS ONE COLLIDING MAP -- the plugin list is NOT trimmed, and that is
    # load-bearing rather than tidiness. Since #1993 landed, Get-PluginRoots reads this document through
    # ConvertFrom-MarketplaceJson, whose fallback SUCCEEDS on a case collision -- so unlike scenario 55
    # the plugin set here is real rather than empty, and a short list trips the shared-scripts registry's
    # throw on a pair naming a plugin the marketplace does not declare, killing the gate mid-run. Measured
    # on this branch: a one-plugin list failed three of the five asserts below for that reason and nothing
    # to do with JSON. The only difference from the good document must be the collision itself.
    $collideMarketplace = @'
{
  "name": "fixture-marketplace",
  "lspServers": { "clangd": { "extensionToLanguage": { ".c": "c", ".C": "cpp" } } },
  "plugins": [
    { "name": "dkj-subagents-alpha",         "source": "./plugins/dkj-subagents/dkj-subagents-alpha" },
    { "name": "dkj-subagents-shopify",       "source": "./plugins/dkj-subagents/dkj-subagents-shopify" },
    { "name": "dkj-policy", "source": "./plugins/dkj-policy" }
  ]
}
'@
    [System.IO.File]::WriteAllText((Join-Path $Fixture '.claude-plugin\marketplace.json'), $collideMarketplace, $Utf8NoBom)
    $c5b = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($c5b.Out -match '\[JSON\].*is VALID JSON that THIS PowerShell cannot read') `
        'case-colliding marketplace: the verdict says the FILE is valid and this reader is not'
    Assert-True ($c5b.Out -notmatch '\[JSON\].*is not valid JSON') `
        'case-colliding marketplace: and it is never accused of being malformed (issue #2003)'
    Assert-True ($c5b.Out -match "'\.C' and '\.c' in lspServers\.clangd\.extensionToLanguage") `
        'case-colliding marketplace: the colliding keys are named, with the path they sit at'
    Assert-True ($c5b.Out -match 'Summary:') `
        'case-colliding marketplace: the run still reaches its Summary, like scenario 55'
    Assert-True ($c5b.Code -ne 0) `
        'case-colliding marketplace: and still FAILS -- check 1 could not read the manifest it validates'
    [System.IO.File]::WriteAllText((Join-Path $Fixture '.claude-plugin\marketplace.json'), $goodMarketplace, $Utf8NoBom)

} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Complete-IntegritySuite
