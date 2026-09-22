<#
.SYNOPSIS
    Drives the REAL cut-release.ps1 end to end against a throwaway git repo (issue #708).

.DESCRIPTION
    Dependency-free: no Pester, plain PowerShell. This is the sibling of cut-release-guardrail.tests.ps1
    and deliberately a different KIND of test. That suite reads cut-release's source text and asserts on
    what it says; this one runs it and asserts on what it leaves behind.

    WHY THIS SUITE EXISTS. cut-release.ps1 is the highest-blast-radius script in the repo: it bumps every
    plugin.json in lockstep, empties CHANGELOG.md down to its intro, writes the release notes, rewrites
    the history table, commits DIRECTLY on the trunk and pushes a tag. Because it runs under the
    narrowly-bounded exception to "never directly on main", no PR and no CI stand between a defect and
    the tag -- CI first sees that commit when it is already pushed and tagged. Until #708 its only
    dedicated coverage was an allowlist drift guard plus source-text asserts, and -- unlike ship-pr.ps1,
    which names its own gap twice in its docstring -- it said nothing about the gap at all, so the
    absence read as coverage.

    HOW IT IS SAFE. The fixture is a fresh `git init` under the temp folder with NO remote, and every run
    passes -NoPush, so nothing can reach a real remote even if the script's push branch were entered. The
    real script is invoked in a CHILD PROCESS with CLAUDE_PROJECT_DIR pointed at the fixture, which is the
    documented way cut-release resolves its repo root. -SkipLint and -SkipTests are passed because the
    fixture has neither a lint script nor suites: this suite is about what cut-release WRITES, and the
    gate behaviour it skips is what cut-release-guardrail.tests.ps1 already pins from the source.

    FIXTURE STRATEGY. scripts/repo-config.ps1 and scripts/lib/branch-info.ps1 are copied VERBATIM from
    this repo -- the same choice script-contract.tests.ps1 makes, and for the same reason: a passing
    suite is then grounded in this repo's real seam answers rather than a hand-rolled stand-in that
    could drift away from them. Everything else the fixture holds is the minimum tree those answers
    describe.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/cut-release-drive.tests.ps1

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$CutRelease = Join-Path $RepoRoot 'scripts\release\cut-release.ps1'

# Every git call below goes through the repo's own Invoke-NativeCapture, and that is not decoration.
# Under EAP=Stop, PowerShell 5.1 promotes a native command's stderr to a terminating NativeCommandError
# -- so `git add` writing its ordinary "LF will be replaced by CRLF" warning kills the caller. That is
# the exact pitfall that broke cutting v1.12.0 (#107), which is why this lib exists; a suite about
# cut-release re-learning it by hand would be the wrong lesson.
. (Join-Path $RepoRoot 'scripts\lib\native-capture-lib.ps1')
# The entry format's levels, so the fixture below states the shape the cut actually reads rather than a copy
# of it. Loaded here because this suite drives the cut as a child process and had no need for the lib until
# the levels became something a fixture must not hardcode.
. (Join-Path $RepoRoot 'scripts\lib\entry-scaffold-lib.ps1')
$FixtureDir = Join-Path ([System.IO.Path]::GetTempPath()) "cut-release-drive-$PID-$([guid]::NewGuid().ToString('n'))"

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { Write-Host "  [PASS] $Message" -ForegroundColor Green; $script:pass++ }
    else            { Write-Host "  [FAIL] $Message" -ForegroundColor Red;   $script:fail++ }
}
function Assert-Equal {
    param($Expected, $Actual, [string]$Message)
    if ("$Expected" -eq "$Actual") { Write-Host "  [PASS] $Message" -ForegroundColor Green; $script:pass++ }
    else { Write-Host "  [FAIL] $Message (expected '$Expected', got '$Actual')" -ForegroundColor Red; $script:fail++ }
}
function Assert-Match {
    param([string]$Pattern, [string]$Text, [string]$Message)
    if ($Text -match $Pattern) { Write-Host "  [PASS] $Message" -ForegroundColor Green; $script:pass++ }
    else { Write-Host "  [FAIL] $Message (pattern '$Pattern' not found)" -ForegroundColor Red; $script:fail++ }
}
function Assert-NotMatch {
    param([string]$Pattern, [string]$Text, [string]$Message)
    if ($Text -notmatch $Pattern) { Write-Host "  [PASS] $Message" -ForegroundColor Green; $script:pass++ }
    else { Write-Host "  [FAIL] $Message (pattern '$Pattern' unexpectedly found)" -ForegroundColor Red; $script:fail++ }
}

function Test-Says {
    <# Does the child's captured output contain this phrase, whatever the console did to it?

       THIS SUITE NEEDS IT AND MOST DO NOT, which is the whole of #1728's classification. Invoke-Cut
       below returns ($out + "`n" + $err), so the child's ERROR stream is in the capture -- and a
       'throw', a 'Write-Error' or a 'Write-Warning' reaches a capture through PowerShell's error
       formatter, which hard-wraps at the host's buffer column INSIDE a word. cut-release.ps1 carries 29
       Write-Error and 2 Write-Warning, so the reach is real even though the four call sites below happen
       to read Write-Host lines today. Write-Host is unaffected, and a suite capturing stdout only never
       meets this at all (issue #1512).

       Strips ALL whitespace from both sides rather than normalizing runs of it: collapsing '\s+' to one
       space repairs a wrap BETWEEN words and does nothing for a wrap INSIDE one. Which asserts straddle
       a break is decided by the render width and by the length of whatever path the message
       interpolates, so A GREEN RUN IS NOT EVIDENCE -- #1723's site passed for months.

       Literal (IndexOf), so a phrase carrying '.', '(' or '[' needs no escaping -- which is why the
       call sites below lost their backslashes. #>
    param([string]$Text, [string]$Phrase)
    $haystack = ($Text -replace '\s', '')
    $needle = ($Phrase -replace '\s', '')
    return ($haystack.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
}

function Assert-Says {
    <# PHRASE FIRST, TEXT SECOND -- deliberately NOT the ($Text, $Phrase) order the other suites carrying
       this helper use. It matches Assert-Match and Assert-NotMatch in THIS file, which its call sites sit
       beside. Both parameters are strings, so a mismatched order between neighbours is a silent swap
       rather than an error, and the neighbour is what a reader copies from. #>
    param([string]$Phrase, [string]$Text, [string]$Message)
    if (Test-Says -Text $Text -Phrase $Phrase) { Write-Host "  [PASS] $Message" -ForegroundColor Green; $script:pass++ }
    else { Write-Host "  [FAIL] $Message (phrase '$Phrase' not found)" -ForegroundColor Red; $script:fail++ }
}

function Write-Utf8 {
    param([string]$Path, [string]$Text)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function New-CutFixture {
    <#
        The minimum tree this repo's own seam answers describe: a marketplace, two plugins to bump in
        lockstep, a CHANGELOG with an intro and one pending entry, the release history table, and the
        two note roots. Returns the fixture path.
    #>
    # The history shape is copied from this repo's own page rather than invented: '### The release list',
    # then one '#### <major>.x' per major, each over a table whose header is '| Version | Date | Type |
    # Title |'. Getting this wrong is not a loud failure -- the first draft of this fixture used
    # '| Release |' and no list heading, and the cut simply wrote no row and refused nothing, which is
    # exactly the silent shape a suite about this script exists to catch.
    # $AudienceTier and $EntryTopTier exist for the tier-1 scenario, and 2/0 keep every earlier caller
    # byte-identical. They are two parameters rather than one switch because they are two independent
    # facts -- which audience the repo publishes to, and how far its pending entry reaches -- and the
    # defect they were added for (#747) is precisely what happens when one is assumed from the other.
    param(
        [string]$Name,
        [string]$PluginVersion = '1.4.0',
        [string]$HistoryMajors = "#### 1.x`n`n| Version | Date | Type | Title |`n|---|---|---|---|`n",
        [int]$AudienceTier = 2,
        [int]$EntryTopTier = 0,
        # A SECOND, CALLER-WRITTEN ENTRY, appended verbatim after the fixture's own one (inbound #2230).
        # Raw rather than another set of named knobs: the one scenario that needs it is a 'Retracts:' entry,
        # whose whole point is a line no other scenario's fixture needs to know about.
        [string]$ExtraEntry = '')

    $root = Join-Path $FixtureDir $Name
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    # The two seam libs, verbatim from this repo.
    New-Item -ItemType Directory -Path (Join-Path $root 'scripts\lib') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\repo-config.ps1')     -Destination (Join-Path $root 'scripts\repo-config.ps1') -Force
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\branch-info.ps1') -Destination (Join-Path $root 'scripts\lib\branch-info.ps1') -Force
    # THE ONE DELIBERATE DEPARTURE FROM 'VERBATIM', and only when asked for. This repo answers 2, so the
    # tier-1 path cannot be reached with its seam file unaltered -- which is the whole reason #747 shipped:
    # every local run of every gate produced a correct document. Patched by targeted replacement rather
    # than by hand-writing a stand-in config, so the fixture keeps every OTHER answer grounded in the real
    # file. The assert makes a failed patch loud: a silent no-op would leave this scenario testing tier 2
    # twice and reporting a pass.
    if ($AudienceTier -ne 2) {
        $cfgPath = Join-Path $root 'scripts\repo-config.ps1'
        $cfg = Get-Content -LiteralPath $cfgPath -Raw
        $patched = $cfg -replace '(?m)^\$script:ReleaseAudienceTier\s*=\s*2\s*$', "`$script:ReleaseAudienceTier = $AudienceTier"
        if ($patched -eq $cfg) { throw "fixture: could not repoint ReleaseAudienceTier to $AudienceTier -- the seam literal in repo-config.ps1 changed shape." }
        Write-Utf8 $cfgPath $patched
    }

    # THE SECOND DEPARTURE, and unconditional (August 27, 2026). This repo moved its changelog, its release
    # list and its internal-note root into dkj-policy/ and now STATES all three seams, so a
    # verbatim copy carries those answers into a fixture whose whole layout -- and every path this suite
    # asserts on -- is the root one. Patched by the same targeted replacement as the tier above, and for the
    # same reason: every OTHER answer stays grounded in the real file. What this suite tests is the CUT, not
    # where a repo keeps its documents; the seams' own defaults are covered by seam-lib.tests.ps1.
    $relocPath = Join-Path $root 'scripts\repo-config.ps1'
    $reloc = Get-Content -LiteralPath $relocPath -Raw
    foreach ($seam in @(
        @{ Var = 'ChangelogPath';            Root = 'CHANGELOG.md' },
        @{ Var = 'ReleaseHistoryPath';       Root = 'releases/README.md' },
        @{ Var = 'ReleaseInternalNotesRoot'; Root = 'releases/internal' })) {
        $before = $reloc
        $reloc = $reloc -replace ("(?m)^\`$script:" + $seam.Var + "\s*=.*$"), ("`$script:" + $seam.Var + " = '" + $seam.Root + "'")
        if ($reloc -eq $before) { throw "fixture: could not repoint $($seam.Var) to the root -- the seam literal in repo-config.ps1 changed shape." }
    }
    Write-Utf8 $relocPath $reloc

    Write-Utf8 (Join-Path $root '.claude-plugin\marketplace.json') @"
{
  "name": "dkj-claude-plugins",
  "owner": { "name": "fixture" },
  "plugins": [
    { "name": "team-fixture",     "source": "./plugins/dkj-subagents/team-fixture" },
    { "name": "workflow-fixture", "source": "./plugins/workflows/workflow-fixture" }
  ]
}
"@
    foreach ($p in @(
        @{ Path = 'plugins\dkj-subagents\team-fixture';         Name = 'team-fixture' },
        @{ Path = 'plugins\workflows\workflow-fixture'; Name = 'workflow-fixture' })) {
        Write-Utf8 (Join-Path $root "$($p.Path)\.claude-plugin\plugin.json") @"
{
  "name": "$($p.Name)",
  "description": "A fixture plugin.",
  "version": "$PluginVersion"
}
"@
    }

    # THE LEVELS COME FROM THE LIB, not from literals in the here-strings below (August 26, 2026). Both
    # pairs shifted one deeper and a pending section joined them, so a fixture stating the old shape is a
    # document the cut now correctly REFUSES to read -- which is how seventeen assertions here went red
    # against untouched machinery.
    $cutEntryH = '#' * (Get-EntryHeadingLevel)
    $cutSectH  = '#' * (Get-EntrySectionLevel)
    $cutTierH  = '#' * (Get-EntryTierSubLevel)
    $cutPendH  = Get-ChangelogUnreleasedHeading

    # CHANGELOG: an intro, then one pending entry scored at tier 0 so a patch is what it earns -- plus a
    # higher tier's section where the caller asked for one, which is what lets a minor be earned AND gives
    # the audience section something real to be pre-filled from.
    $topTierSection = if ($EntryTopTier -gt 0) { @"

$cutTierH Tier $EntryTopTier

The reader this repo publishes to notices it.

**Score:** 4
"@ } else { '' }
    Write-Utf8 (Join-Path $root 'CHANGELOG.md') @"
# Changelog

Everything merged since the last release, furthest reach first.

$cutPendH

$cutEntryH ``fix/a-fixture-change`` changelog

$cutSectH Branch title

A fixture change

$cutSectH Branch ID

20260815-000000

$cutSectH Branch type

fix

$cutSectH What does the change on this branch bring to main?

A fixture entry, written so this suite has something real to fold.

$cutSectH Significance

$cutTierH Tier 0

The maintainers notice it.

**Score:** 2
$topTierSection

$cutSectH Pull Request

https://github.com/DaveKJohn/claude-code-specialists/pull/1

$ExtraEntry
"@

    Write-Utf8 (Join-Path $root 'releases\README.md') @"
# Releases

A fixture release page.

### The release list

$HistoryMajors
"@
    New-Item -ItemType Directory -Path (Join-Path $root 'dkj-policy\releases\audience\1.x') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root 'dkj-policy\releases\changelog\1.x') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root 'dkj-policy\releases\github\1.x') -Force | Out-Null

    # A git repo with NO remote: -NoPush is belt, this is braces.
    Push-Location $root
    try {
        Invoke-NativeCapture -FilePath 'git' -Arguments @('init', '--quiet', '--initial-branch=main') | Out-Null
        Invoke-NativeCapture -FilePath 'git' -Arguments @('config', 'user.email', 'fixture@example.invalid') | Out-Null
        Invoke-NativeCapture -FilePath 'git' -Arguments @('config', 'user.name', 'Fixture') | Out-Null
        # gpgsign off: a locked signing agent must not fail a fixture commit for a reason unrelated to the test (#1287).
        Invoke-NativeCapture -FilePath 'git' -Arguments @('config', 'commit.gpgsign', 'false') | Out-Null
        Invoke-NativeCapture -FilePath 'git' -Arguments @('add', '-A') | Out-Null
        Invoke-NativeCapture -FilePath 'git' -Arguments @('commit', '--quiet', '-m', 'fixture: initial') | Out-Null
    } finally { Pop-Location }

    return $root
}

function Invoke-Cut {
    param([string]$Root, [string[]]$Arguments)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = 'powershell'
    $psi.Arguments = (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$CutRelease`"") + $Arguments) -join ' '
    $psi.WorkingDirectory      = $Root
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute        = $false
    $psi.EnvironmentVariables['CLAUDE_PROJECT_DIR'] = $Root
    $p = [System.Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    return [pscustomobject]@{ Code = $p.ExitCode; Out = ($out + "`n" + $err) }
}

function Get-GitOut {
    param([string]$Root, [string[]]$GitArgs)
    Push-Location $Root
    try { return ((Invoke-NativeCapture -FilePath 'git' -Arguments $GitArgs).Output | Out-String) }
    finally { Pop-Location }
}

try {
    Write-Host "== cut-release-drive.tests ==" -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $FixtureDir -Force | Out-Null

    # --- 1. The happy path: a patch is cut, and every artefact it owns is on disk ------------------
    Write-Host ""
    Write-Host "cut-release.ps1 -- a patch cut writes every artefact and tags the commit" -ForegroundColor Cyan
    $root = New-CutFixture -Name 'happy'
    $r = Invoke-Cut -Root $root -Arguments @('-Bump', 'patch', '-NoPush', '-SkipLint', '-SkipTests')
    Assert-Equal 0 $r.Code 'happy path: exit code 0'

    # Lockstep is the property a consumer depends on: team-fixture and workflow-fixture must move
    # together, because a consumer running both needs matching versions.
    $v1 = (Get-Content -LiteralPath (Join-Path $root 'plugins\dkj-subagents\team-fixture\.claude-plugin\plugin.json') -Raw | ConvertFrom-Json).version
    $v2 = (Get-Content -LiteralPath (Join-Path $root 'plugins\workflows\workflow-fixture\.claude-plugin\plugin.json') -Raw | ConvertFrom-Json).version
    Assert-Equal '1.4.1' $v1 'happy path: the team plugin was bumped to the patch version'
    Assert-Equal '1.4.1' $v2 'happy path: the workflow plugin moved with it -- lockstep, not per plugin'

    # CHANGELOG down to its intro: the entry is gone, the intro survives verbatim.
    $changelog = Get-Content -LiteralPath (Join-Path $root 'CHANGELOG.md') -Raw
    Assert-Match '# Changelog'   $changelog 'happy path: the CHANGELOG intro survives the cut'
    Assert-NotMatch 'a-fixture-change' $changelog 'happy path: the pending entry is gone from CHANGELOG.md'

    # The changelog note carries the entry that was folded away, which is the whole point of writing
    # it before emptying the file.
    $notePath = Join-Path $root 'dkj-policy\releases\changelog\1.x\1.4.1.md'
    Assert-True (Test-Path -LiteralPath $notePath) 'happy path: the changelog note was written at the grouped path'
    if (Test-Path -LiteralPath $notePath) {
        Assert-Match 'A fixture change' (Get-Content -LiteralPath $notePath -Raw) 'happy path: and it carries the entry the CHANGELOG lost'
    }

    # The history table gains its own row -- the cut inserts it, so nobody adds one by hand.
    $history = Get-Content -LiteralPath (Join-Path $root 'releases\README.md') -Raw
    Assert-Match '1\.4\.1' $history 'happy path: the release history table gained a row for this version'

    # Commit + tag on the trunk, which is the irreversible half of the exception this script runs under.
    Assert-Match 'v1\.4\.1' (Get-GitOut -Root $root -GitArgs @('tag','--list')) 'happy path: the tag exists'
    Assert-Match 'v1\.4\.1' (Get-GitOut -Root $root -GitArgs @('log','-1','--pretty=%D')) 'happy path: and it points at the commit the cut just made'
    Assert-Equal '' (Get-GitOut -Root $root -GitArgs @('status','--porcelain')).Trim() 'happy path: the tree is clean afterwards -- everything written was committed'

    # THE TWO NUMBERS THE LABELLING HANGS ON, on the -NoPush path (inbound #802). The push path has always
    # closed with them; this branch exits before it and printed neither -- so the flag whose entire purpose
    # is inspecting a release before it is public was the one path that concealed the baseline.
    Assert-Says '1.4.0 -> 1.4.1' $r.Out '-NoPush: the closing line names the baseline and the new version'
    Assert-Says 'Patch' $r.Out '-NoPush: and the bump type it derived from them'

    # --- 2. The bump gate: tier 0 alone does not earn a minor -------------------------------------
    Write-Host ""
    Write-Host "cut-release.ps1 -- a bump that the pending entries have not earned is refused" -ForegroundColor Cyan
    $root2 = New-CutFixture -Name 'unearned'
    $r2 = Invoke-Cut -Root $root2 -Arguments @('-Bump', 'minor', '-NoPush', '-SkipLint', '-SkipTests')
    Assert-True ($r2.Code -ne 0) 'unearned minor: refused with a non-zero exit'
    $v3 = (Get-Content -LiteralPath (Join-Path $root2 'plugins\dkj-subagents\team-fixture\.claude-plugin\plugin.json') -Raw | ConvertFrom-Json).version
    Assert-Equal '1.4.0' $v3 'unearned minor: NOTHING was written -- the gate runs before the first write'
    Assert-Equal '' (Get-GitOut -Root $root2 -GitArgs @('tag','--list')).Trim() 'unearned minor: and no tag was created'

    # --- 3. A new major refuses until its section exists ------------------------------------------
    # This is the case CLAUDE.md documents as needing two hand edits on the trunk BEFORE a cut will
    # run. Pinning it here means the refusal cannot quietly become a silent success.
    Write-Host ""
    Write-Host "cut-release.ps1 -- a major with no section in the history table refuses" -ForegroundColor Cyan
    $root3 = New-CutFixture -Name 'newmajor'
    $r3 = Invoke-Cut -Root $root3 -Arguments @('-Version', '2.0.0', '-NoPush', '-SkipLint', '-SkipTests', '-SkipTierGate')
    Assert-True ($r3.Code -ne 0) 'new major: refused with a non-zero exit'
    Assert-Equal '' (Get-GitOut -Root $root3 -GitArgs @('tag','--list')).Trim() 'new major: no tag was created'
    $v4 = (Get-Content -LiteralPath (Join-Path $root3 'plugins\dkj-subagents\team-fixture\.claude-plugin\plugin.json') -Raw | ConvertFrom-Json).version
    Assert-Equal '1.4.0' $v4 'new major: and no version was bumped -- the refusal leaves the tree untouched'

    # --- 4. The audience section follows the repo's tier, not the literal 2 (inbound #747) ---------
    # THE DEFECT THIS PINS could not be seen from inside this repo: Get-ReleaseAudienceTier answers 2
    # here, so every gate and every local cut produced a correct document while a tier-1 consumer's
    # draft came out with the two sections that cannot be generated and none that said what shipped.
    # Driven through the real script rather than asserted at the lib, because the hardcode was in the
    # SELECTION (cut-release.ps1) and not in the renderer -- a lib-level test would have passed
    # throughout, which is how a suite of 40 files missed this.
    Write-Host ""
    Write-Host "cut-release.ps1 -- the audience section is drawn from the repo's own tier" -ForegroundColor Cyan
    $root4 = New-CutFixture -Name 'tier1' -AudienceTier 1 -EntryTopTier 1
    $r4 = Invoke-Cut -Root $root4 -Arguments @('-Bump', 'minor', '-NoPush', '-SkipLint', '-SkipTests')
    Assert-Equal 0 $r4.Code 'tier 1: the minor is earned by the tier-1 entry and the cut succeeds'
    $note4 = Join-Path $root4 'dkj-policy\releases\audience\1.x\1.5.0.md'
    Assert-True (Test-Path -LiteralPath $note4) 'tier 1: the hand-written note was drafted'
    if (Test-Path -LiteralPath $note4) {
        $n4 = Get-Content -LiteralPath $note4 -Raw
        # The finding itself: a section that says what changed, at all.
        Assert-Match '(?m)^## What changed$'  $n4 'tier 1: the draft HAS a section saying what changed -- the whole of #747'
        # NO HEADING NAMES ITS OWN READER, at either tier (Dave, August 21, 2026). 'For consumers' told the
        # consumer something they already knew; the section BELOW still names a reader, because that one is
        # deliberately the half the audience section may not contain.
        Assert-NotMatch '(?m)^## For ' $n4 'tier 1: and no section heading names its own reader'
        # PRE-FILLED, not merely asked for. #747 proposed an empty heading on the reasoning that a tier-1
        # repo has no generatable source; it has the same source a tier-2 repo has, and this is the assert
        # that would fail if the fix were narrowed back to a bare heading.
        Assert-Match 'A fixture change' $n4 'tier 1: the section is PRE-FILLED from the tier-1 entry, not left empty'
        # The two sections that genuinely cannot be generated still arrive, still empty.
        Assert-Match '(?m)^## What it is worth$'                 $n4 "tier 1: 'what it is worth' still arrives"
        Assert-Match '(?m)^## What was still open at this release$' $n4 'tier 1: and so does the open section'
        # #747's second finding: the audience line promised two readers with one section each, in a
        # document that renders one reader and two sections.
        Assert-NotMatch 'consumers of this product' $n4 'tier 1: the audience line no longer promises a reader this repo does not publish to'
        Assert-Match '(?m)^\*\*For whom:\*\* colleagues in the organisation' $n4 'tier 1: it names the reader the repo actually has'
        # The score is a self-assigned number and must not reach a document that travels outward, at
        # either tier -- the strip is inherited, so this catches a caller that stopped passing it.
        Assert-NotMatch '\*\*Score:\*\*' $n4 'tier 1: the self-assigned score is stripped, as at tier 2'
    }

    # --- 5. And tier 2 is unmoved by the same change -----------------------------------------------
    # The other half of the claim. A fix that reads a seam is only safe if the answer this repo gives
    # produces what it produced before, so the tier-2 path is driven with a tier-2 entry and asserted
    # on the heading the change could most easily have broken.
    Write-Host ""
    Write-Host "cut-release.ps1 -- a tier-2 repo's consumer section is unchanged by the same code" -ForegroundColor Cyan
    $root5 = New-CutFixture -Name 'tier2' -EntryTopTier 2
    $r5 = Invoke-Cut -Root $root5 -Arguments @('-Bump', 'minor', '-NoPush', '-SkipLint', '-SkipTests')
    Assert-Equal 0 $r5.Code 'tier 2: the minor is earned by the tier-2 entry and the cut succeeds'
    $note5 = Join-Path $root5 'dkj-policy\releases\audience\1.x\1.5.0.md'
    Assert-True (Test-Path -LiteralPath $note5) 'tier 2: the hand-written note was drafted'
    if (Test-Path -LiteralPath $note5) {
        $n5 = Get-Content -LiteralPath $note5 -Raw
        Assert-Match '(?m)^## What changed$' $n5 'tier 2: the audience section says what it holds, not who it is for'
        Assert-NotMatch '(?m)^## For consumers$' $n5 'tier 2: and the retired heading does not come back'
        Assert-Match 'consumers of this product' $n5 'tier 2: its audience line still names both readers'
        Assert-Match 'A fixture change' $n5 'tier 2: pre-filled from the tier-2 entry, as before'
    }

    # --- 6. The baseline cross-check: a history that records a different release refuses (#802) -----
    # THE FAILURE THIS PINS IS SILENT, and that is the whole reason it is driven rather than asserted on
    # the source text. Where the baseline and the recorded numbering disagree, the cut still succeeds and
    # still writes a plausible release -- with the wrong bump TYPE in the notes, in the overview row, in
    # the question the tier gate answered, and in whether a consumer document was drafted at all. The
    # reporting consumer got a 'Minor' patch and found out by reading the files afterwards.
    #
    # The fixture's history normally carries an EMPTY table, so every scenario above leaves this check
    # dormant -- which is also why they are unaffected by it. Here it gets a row, and a row that names a
    # release the manifests have never heard of.
    Write-Host ""
    Write-Host "cut-release.ps1 -- a baseline that disagrees with the recorded release numbering refuses" -ForegroundColor Cyan
    $recordedHistory = "#### 1.x`n`n| Version | Date | Type | Title |`n|---|---|---|---|`n| [1.9.9](../dkj-policy/releases/changelog/1.x/1.9.9.md) | 2026-08-20 | Patch | Recorded, but untagged and unbumped |`n"
    $root6 = New-CutFixture -Name 'baseline' -HistoryMajors $recordedHistory
    $r6 = Invoke-Cut -Root $root6 -Arguments @('-Bump', 'patch', '-NoPush', '-SkipLint', '-SkipTests')
    Assert-True ($r6.Code -ne 0) 'baseline: refused with a non-zero exit'
    # BOTH NUMBERS IN THE MESSAGE, because the point of the refusal is telling the reader WHICH of the two
    # is behind -- a refusal naming one of them leaves exactly the question that caused the defect.
    Assert-Says '1.4.0' $r6.Out 'baseline: the message names the baseline it read'
    Assert-Says '1.9.9' $r6.Out 'baseline: and the version the overview records'
    $v6 = (Get-Content -LiteralPath (Join-Path $root6 'plugins\dkj-subagents\team-fixture\.claude-plugin\plugin.json') -Raw | ConvertFrom-Json).version
    Assert-Equal '1.4.0' $v6 'baseline: nothing was written -- the check runs with the other guardrails, before the first write'
    Assert-Equal '' (Get-GitOut -Root $root6 -GitArgs @('tag','--list')).Trim() 'baseline: and no tag was created'

    # --- 7. -Type is the way through, and it produces a CORRECT release ----------------------------
    # A -Skip switch would have handed back the very label the check caught. This asserts the other half:
    # the escape valve exists, and what comes out the other side is labelled the way the author stated
    # rather than the way the disagreement implied. Off a 1.9.9 baseline, inference would have called
    # 1.4.1 a Minor (the minor component moved DOWN, so Get-BumpType reads the highest changed field);
    # -Type patch is what makes it a Patch.
    Write-Host ""
    Write-Host "cut-release.ps1 -- -Type states the bump type where the divergence is deliberate" -ForegroundColor Cyan
    $root7 = New-CutFixture -Name 'statedtype' -HistoryMajors $recordedHistory
    $r7 = Invoke-Cut -Root $root7 -Arguments @('-Version', '1.4.1', '-Type', 'patch', '-NoPush', '-SkipLint', '-SkipTests')
    Assert-Equal 0 $r7.Code 'stated type: the cut runs'
    $note7 = Join-Path $root7 'dkj-policy\releases\changelog\1.x\1.4.1.md'
    Assert-True (Test-Path -LiteralPath $note7) 'stated type: the changelog note was written'
    if (Test-Path -LiteralPath $note7) {
        Assert-Match '(?m)^\*\*Type:\*\*\s*Patch' (Get-Content -LiteralPath $note7 -Raw) 'stated type: and it is labelled Patch -- the type the author stated, not the one the baseline implied'
    }
    Assert-Match '(?m)^\|\s*\[?1\.4\.1[^|]*\|[^|]*\|\s*Patch\s*\|' (Get-Content -LiteralPath (Join-Path $root7 'releases\README.md') -Raw) 'stated type: the overview row carries the same label'
    # -Type and -Bump are two answers to one question, and the refusal is the same call the -Version/-Bump
    # pair already makes.
    $r8 = Invoke-Cut -Root $root7 -Arguments @('-Bump', 'patch', '-Type', 'patch', '-NoPush', '-SkipLint', '-SkipTests')
    Assert-True ($r8.Code -ne 0) '-Type alongside -Bump is refused rather than resolved by precedence'

    # --- 8. A retracted change is withheld from the audience document, not from the record (#2230) --
    # The measured instance, reproduced end to end: a tier-2 entry ('fix/a-fixture-change') and a second,
    # repo-internal entry that undoes it ('fix/revert-a-fixture-change', tier 0) and names it in a
    # 'Retracts:' line. The audience document must not carry the retracted change; CHANGELOG.md's own
    # record (folded into the changelog note) must carry both, because both reached the trunk.
    Write-Host ""
    Write-Host "cut-release.ps1 -- a retracted entry is withheld from the audience document, not the record" -ForegroundColor Cyan
    $cutEntryH = '#' * (Get-EntryHeadingLevel)
    $cutSectH  = '#' * (Get-EntrySectionLevel)
    $cutTierH  = '#' * (Get-EntryTierSubLevel)
    $revertEntry = @"
$cutEntryH ``fix/revert-a-fixture-change`` changelog

Retracts: fix/a-fixture-change

$cutSectH Branch title

Revert a-fixture-change

$cutSectH Branch ID

20260816-000000

$cutSectH Branch type

fix

$cutSectH What does the change on this branch bring to main?

Restores the file exactly as it was before -- the earlier merge is undone before this release ships.

$cutSectH Significance

$cutTierH Tier 0

The maintainers notice it.

**Score:** 2

$cutSectH Pull Request

https://github.com/DaveKJohn/claude-code-specialists/pull/2
"@
    $root9 = New-CutFixture -Name 'retraction' -EntryTopTier 2 -ExtraEntry $revertEntry
    $r9 = Invoke-Cut -Root $root9 -Arguments @('-Bump', 'minor', '-NoPush', '-SkipLint', '-SkipTests')
    Assert-Equal 0 $r9.Code 'retraction: the minor is still earned by the retracted entry''s own tier-2 declaration'
    $note9 = Join-Path $root9 'dkj-policy\releases\audience\1.x\1.5.0.md'
    Assert-True (Test-Path -LiteralPath $note9) 'retraction: the audience document was still drafted'
    if (Test-Path -LiteralPath $note9) {
        $n9 = Get-Content -LiteralPath $note9 -Raw
        Assert-Match   '(?m)^## What changed$' $n9 'retraction: the audience section still renders'
        Assert-NotMatch 'A fixture change'     $n9 'retraction: but the retracted entry''s own body is withheld from it'
        Assert-Match 'fix/a-fixture-change'         $n9 'retraction: the withheld-note names the retracted branch'
        Assert-Match 'fix/revert-a-fixture-change'   $n9 'retraction: and the branch that retracted it'
    }
    # THE RECORD KEEPS BOTH -- CHANGELOG.md's own history, folded into the changelog note, is untouched
    # by any of this: it is what reached the trunk, and both entries did.
    $changelogNote9 = Join-Path $root9 'dkj-policy\releases\changelog\1.x\1.5.0.md'
    Assert-True (Test-Path -LiteralPath $changelogNote9) 'retraction: the changelog note (the record) was written'
    if (Test-Path -LiteralPath $changelogNote9) {
        $cn9 = Get-Content -LiteralPath $changelogNote9 -Raw
        Assert-Match 'A fixture change' $cn9 'retraction: the record keeps the retracted entry'
        Assert-Match 'fix/revert-a-fixture-change' $cn9 'retraction: and the entry that retracted it'
    }

    # --- 9. An unresolvable 'Retracts:' target refuses the cut, before anything is written -----------
    Write-Host ""
    Write-Host "cut-release.ps1 -- a 'Retracts:' typo refuses the cut instead of reading as nothing to withhold" -ForegroundColor Cyan
    $typoEntry = $revertEntry -replace 'fix/a-fixture-change', 'fix/a-fixture-chnage'
    $root10 = New-CutFixture -Name 'retraction-typo' -EntryTopTier 2 -ExtraEntry $typoEntry
    $r10 = Invoke-Cut -Root $root10 -Arguments @('-Bump', 'minor', '-NoPush', '-SkipLint', '-SkipTests')
    Assert-True ($r10.Code -ne 0) 'retraction typo: refused with a non-zero exit'
    Assert-Says 'do not name any pending entry' $r10.Out 'retraction typo: and says why'
    $v10 = (Get-Content -LiteralPath (Join-Path $root10 'plugins\dkj-subagents\team-fixture\.claude-plugin\plugin.json') -Raw | ConvertFrom-Json).version
    Assert-Equal '1.4.0' $v10 'retraction typo: nothing was written -- the guardrail runs before the first write'
    Assert-Equal '' (Get-GitOut -Root $root10 -GitArgs @('tag','--list')).Trim() 'retraction typo: and no tag was created'

} finally {
    if (Test-Path -LiteralPath $FixtureDir) {
        Remove-Item -LiteralPath $FixtureDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
