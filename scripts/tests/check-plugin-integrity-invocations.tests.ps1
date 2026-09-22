<#
.SYNOPSIS
    check-plugin-integrity.ps1, the printed-invocation checks: a skill's runnable command resolving
    on the reader's machine (22), a printed powershell command carrying -ExecutionPolicy Bypass in
    the document layer (42) and over the script layer (42b), the PR template's two promises to
    open-pr (24), and a frontmatter document opening with '---' read as bytes (26).

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

$Fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("check-plugin-integrity-invocations-$PID-$([guid]::NewGuid().ToString('n'))")

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
            "# adopt-config`n`n## Run it`n`n``````powershell`npowershell -NoProfile -ExecutionPolicy Bypass -File `"$Path`"`n```````n", $Utf8NoBom)
    }
    # THE BYPASS IN THAT FIXTURE IS CHECK 42'S, NOT CHECK 22'S, and it is here so this block's own page
    # does not model the defect the next one forbids -- a fixture is read by every check in the run, so a
    # bare form here would have put an [exec-policy] finding under every assert below. Check 22's subject
    # is the '-File' argument, which is untouched by it.

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

    # --- check 42: a printed powershell command carries -ExecutionPolicy Bypass ----------------------
    # THE MEASURED DEFECT, September 14, 2026 (#1985): a fresh Windows profile sits at 'Restricted', which
    # refuses every .ps1, so the form 32 documents printed -- 'powershell -NoProfile -File <script>' --
    # died with 'running scripts is disabled on this system' on the machine it was pasted into. Everywhere
    # this tree controls the invocation it already passed Bypass, so nothing was red: the gates never
    # execute the lines a reader types.
    #
    # FOUR DIRECTIONS, and the second is the one that keeps this check exemption-free. Prose naming the
    # invocation MODE -- "across `powershell -File` a comma list is cast to a single number" -- must NOT be
    # reported; measured before the check was written, a rule without that narrowing is born with 12
    # findings and all 12 are correct sentences. The fourth pins the check's deliberate weakness: the VALUE
    # is not this gate's to choose, so 'RemoteSigned' clears it too.
    Write-Host "check 42: a printed powershell command carries -ExecutionPolicy Bypass" -ForegroundColor Cyan
    $epSkill = Join-Path $Fixture 'plugins\dkj-policy\skills\claim-issue\SKILL.md'
    New-Item -ItemType Directory -Path (Split-Path -Parent $epSkill) -Force | Out-Null
    function Write-EpSkill([string]$Command) {
        [System.IO.File]::WriteAllText($epSkill,
            "# claim-issue`n`n## Run it`n`n``````powershell`n$Command`n```````n", $Utf8NoBom)
    }

    # 55a. The exact defect that shipped, reported with the file and the line, and the finding names the
    #      replacement rather than only the fault.
    Write-EpSkill 'powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/claim-issue.ps1" 1234'
    $p1 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($p1.Out -match '\[exec-policy\].*claim-issue\\SKILL\.md:6: the printed command names no -ExecutionPolicy') `
        'exec-policy: a bare printed command is reported, with the file and the line'
    Assert-True ($p1.Out -match [regex]::Escape('running scripts is disabled on this system')) `
        'exec-policy: and the finding quotes the failure the reader will actually see'
    Assert-True ($p1.Out -match '\[exec-policy\] checked [1-9]') `
        'exec-policy: the coverage count proves an invocation was examined, not an empty scan'

    # 55b. THE EXEMPTION-FREE PROPERTY. Prose naming the invocation mode carries no -NoProfile, and there
    #      are 12 such sentences in this tree -- every one of them correct. Reporting them would have
    #      needed the exemption list this repo declines.
    Write-EpSkill 'Across `powershell -File` a comma list is cast to a single number via the separator.'
    $p2 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($p2.Out -match '\[exec-policy\] plugins')) `
        'exec-policy: prose naming the invocation mode is not a subject, so the check needs no exemption list'

    # 55c. History is excluded, via check 11's set rather than a rule of its own: an archived release note
    #      quotes the form that was current when it was written and is never rewritten.
    Write-EpSkill 'powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/claim-issue.ps1"'
    $epNote = Join-Path $Fixture 'dkj-policy\releases\audience\4.x\4.2.0.md'
    New-Item -ItemType Directory -Path (Split-Path -Parent $epNote) -Force | Out-Null
    [System.IO.File]::WriteAllText($epNote,
        "# 4.2.0`n`n``````powershell`npowershell -NoProfile -File `"scripts/release/open-pr.ps1`"`n```````n", $Utf8NoBom)
    $p3 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($p3.Out -match '\[exec-policy\] dkj-policy')) `
        'exec-policy: an archived release note keeps the old form -- history is never rewritten to satisfy a gate'

    # 55d. And the value is NOT pinned. The rule is that the policy be answered; a repo answering it with
    #      'RemoteSigned' has made the decision this check exists to force, and this gate does not get to
    #      legislate which one. Left last on purpose, so the fixture ends in a passing state.
    Write-EpSkill 'powershell -NoProfile -ExecutionPolicy RemoteSigned -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/claim-issue.ps1"'
    $p4 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($p4.Out -match '\[exec-policy\] plugins')) `
        'exec-policy: RemoteSigned clears it too -- the check asks that the policy be answered, not which answer'
    Assert-True ($p4.Out -match '\[exec-policy\] checked [1-9]') `
        'exec-policy: and that pass is over a command actually read, not an empty set'

    # --- check 42b: the same rule over the SCRIPT layer (#1989) --------------------------------------
    # WHY IT IS A SECOND PASS RATHER THAN THE SAME LOOP. Check 42's markdown half landed green over 85
    # subjects; the naive rule over .ps1 is born at 93 findings tree-wide, because a script holds three
    # things a page does not -- prose ABOUT the invocation form, fixture strings that must MODEL the
    # defect, and real invocations the script RUNS. Split out as #1989 rather than swept into #1985.
    #
    # SIX DIRECTIONS, AND FOUR OF THEM ARE NEGATIVE, which is the proportion the three narrowings force. A
    # positive-only suite here would pass just as happily against a check that reports every line it reads,
    # and reporting every line is precisely the failure the narrowings exist to prevent.
    Write-Host "check 42b: a printed powershell command in the script layer" -ForegroundColor Cyan
    $epsSrc = Join-Path $Fixture 'scripts\task\ep-fixture.ps1'
    function Write-EpScript([string]$Body) {
        [System.IO.File]::WriteAllText($epsSrc, $Body, $Utf8NoBom)
    }

    # 55e. The defect this pass was built for: an .EXAMPLE block in comment-based help, which is the shape
    #      41 of the 43 source sites had. Reported with the file and the line, as the markdown half is.
    Write-EpScript @'
<#
.EXAMPLE
    powershell -NoProfile -File scripts/task/ep-fixture.ps1
#>
Write-Host 'fixture'
'@
    $q1 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($q1.Out -match '\[exec-policy/script\].*ep-fixture\.ps1:3: the printed command names no -ExecutionPolicy') `
        'exec-policy/script: a bare .EXAMPLE command is reported, with the file and the line'
    Assert-True ($q1.Out -match '\[exec-policy/script\] checked [1-9]') `
        'exec-policy/script: the coverage count proves a script invocation was examined, not an empty scan'

    # 55f. THE FIRST NARROWING. The invocation has to BEGIN its line; prose naming the form is a fragment of
    #      a sentence. Without this the check is born with 5 findings in this tree, every one of them a
    #      correct sentence -- the exemption list this repo declines, one layer below where check 42 met it.
    Write-EpScript @'
# Prose: 'powershell -NoProfile -File <script> -Skill a,b,c' does NOT parse PowerShell syntax.
Write-Host 'fixture'
'@
    $q2 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($q2.Out -match '\[exec-policy/script\] scripts')) `
        'exec-policy/script: prose naming the invocation form mid-sentence is not a subject'

    # 55g. THE SECOND NARROWING, and the one a leading-'&' rule would only half get right. A command the
    #      script RUNS is never a subject -- -ExecutionPolicy sets PSExecutionPolicyPreference, which a
    #      child inherits -- and BOTH shapes below are read off the AST rather than off the line, so the
    #      bare CommandAst on the second line is as silent as the call operator on the first.
    Write-EpScript @'
& powershell -NoProfile -File $child
powershell -NoProfile -File $child
'@
    $q3 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($q3.Out -match '\[exec-policy/script\] scripts')) `
        'exec-policy/script: a command the script RUNS is not a subject, whether or not it carries "&"'

    # 55h. THE STRING HALF OF THE FIRST NARROWING, and the strongest case in #1989 for sweeping at all: a
    #      printed operator hint is output a reader copies, not documentation. It begins the line of the
    #      STRING it sits in rather than the line of the file, so a file-line rule alone would miss it.
    Write-EpScript @'
Write-Host "     powershell -NoProfile -File scripts/task/ep-fixture.ps1 -Compare"
'@
    $q4 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True ($q4.Out -match '\[exec-policy/script\].*ep-fixture\.ps1:1:') `
        'exec-policy/script: a printed operator hint inside a string is reported -- it is pasted, not read'

    # 55i. THE THIRD NARROWING, and it is a LAYER rather than an exemption list. A suite proving this check
    #      fires has to contain what the check forbids, so a gate reaching into scripts/tests/ would be
    #      arguing with its own evidence -- this suite's own fixtures at 55a and 55c are two such lines.
    #      Measured: of the 75 subjects tree-wide exactly 2 sit under a tests/ folder, and both are those.
    Write-EpScript "Write-Host 'fixture'`n"
    $epsTestSrc = Join-Path $Fixture 'scripts\tests\ep-layer.tests.ps1'
    New-Item -ItemType Directory -Path (Split-Path -Parent $epsTestSrc) -Force | Out-Null
    [System.IO.File]::WriteAllText($epsTestSrc, "powershell -NoProfile -File scripts/task/ep-fixture.ps1`n", $Utf8NoBom)
    $q5 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($q5.Out -match '\[exec-policy/script\] scripts')) `
        'exec-policy/script: the fixture layer is excluded, so a suite may model the defect it proves'

    # 55j. And the value is not pinned here either, for the reason 55d gives. Left last on purpose, so the
    #      fixture ends in a passing state for every scenario below.
    Remove-Item -LiteralPath $epsTestSrc -Force
    Write-EpScript @'
<#
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy RemoteSigned -File scripts/task/ep-fixture.ps1
#>
Write-Host 'fixture'
'@
    $q6 = Invoke-Integrity -FixtureRoot $Fixture
    Assert-True (-not ($q6.Out -match '\[exec-policy/script\] scripts')) `
        'exec-policy/script: RemoteSigned clears the script layer too -- the policy is answered, not chosen'
    Assert-True ($q6.Out -match '\[exec-policy/script\] checked [1-9]') `
        'exec-policy/script: and that pass is over a command actually read, not an empty set'

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

} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Complete-IntegritySuite
