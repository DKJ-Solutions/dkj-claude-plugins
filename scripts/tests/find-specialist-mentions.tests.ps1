<#
.SYNOPSIS
    Regression tests for scripts/sync/find-specialist-mentions.ps1 (report every live mention of a
    specialist's name, grouped by layer).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Integration style -- runs the REAL script as a
    child process against a throwaway git repo, so the roster derivation, the layer classification and
    the git-backed file walk are all exercised for real rather than mocked.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/find-specialist-mentions.tests.ps1

    WHY A FIXTURE AND NOT THE OWN TREE. The script's whole job is to report what the tree contains, so
    asserting against the real repo would pin numbers that every future commit changes -- a suite that
    goes red on correct work. The fixture carries invented specialists (Zephyr, Quill) whose names
    exist nowhere else, so every count is decided by this file.

    THE ONE ASSERT THAT MATTERS MOST is that the roster is DERIVED. A hardcoded list would pass every
    other test here while being exactly the defect the script exists to avoid, so the fixture's
    specialists are deliberately names this repo has never used.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot  = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

# JUDGING THIS SUITE'S OWN FIXTURE git CALLS -- issue #1635. See the lib for why an unjudged fixture
# command is worse than an unjudged production one, and why the count decides the exit code.
. (Join-Path $PSScriptRoot '..\lib\fixture-git-lib.ps1')

# JUDGING THIS SUITE'S OWN FIXTURE CHILD -- issues #1934 and #1954. This suite copies the acting script
# into a fixture tree and runs it there, so a lib its copy list has gone stale on kills the child during
# LOAD, before it writes anything. What the asserts below would then report is the absence of the
# document the child never got far enough to write, naming the absent lib not at all.
. (Join-Path $PSScriptRoot '..\lib\fixture-script-lib.ps1')
$ScriptSrc = Join-Path $RepoRoot 'scripts\sync\find-specialist-mentions.ps1'
# The script dot-sources this sibling lib unconditionally for Get-DisplayName, so the fixture must
# carry it too -- the same arrangement park-branch.tests.ps1 makes for native-capture-lib.
$ReportLibSrc = Join-Path $RepoRoot 'scripts\lib\check-report-lib.ps1'

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red
    }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    if ($Expected -eq $Actual) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++
        Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red
    }
}

function Get-FlatOutput {
    <#
        Line breaks removed, so a phrase assert cannot fail on a break the script does not decide --
        the console-width lesson from park-branch.tests.ps1 and prune-merged.tests.ps1, which carries
        the full reasoning.

        JOIN WITH NOTHING, not collapse to a space (#1742, September 9, 2026). This file collapsed the
        break until then, citing park-branch.tests.ps1 and new-branch.tests.ps1 -- neither of which
        uses that substitution. #1736 measured all three variants over 120 wrap positions x 4 phrases
        (480 checks each), padding a Write-Error until its break swept every column of a 120-wide
        render: collapsing to a space failed 68 of 480, because the formatter breaks INSIDE a word and
        a space cannot repair the split it exists for ('dirty working tre e'). Joining with '' failed
        0 of 480, and is what the other suites in this tree use.

        NOTHING WAS FAILING HERE, and that is the reason this was worth changing. The script under test
        reaches the error stream exactly once and no assert below reads it -- every phrase asserted
        here is Write-Host output, which never touches the formatter. So all 480 checks were moot, and
        the silence sat in exactly the wrong place: the first assert anyone adds on a refusal would have
        landed on the one variant measured to drop phrases, failing at some console widths and not
        others.

        NOT Test-Says, for the same reason prune-merged.tests.ps1 keeps -match on its Write-Host lines:
        stripping ALL whitespace from both sides is immune by construction, but it would assert LESS
        than the phrases below do -- '2 specialists', '11 live mentions' and '2 x link text' are read
        for their spacing. Route a refusal assert through Test-Says when one is added; do not weaken
        these.
    #>
    param($Captured)
    return (($Captured | ForEach-Object { [string]$_ }) -join '')
}

function New-Fixture {
    <# A throwaway git repo carrying one specialist per shape (agent def + persona) and one file per
       layer. Every mention below is placed on purpose; the counts in the asserts are read off this. #>
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("fsm-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null

    function Write-Fixture([string]$Rel, [string[]]$Lines) {
        $full = Join-Path $dir $Rel
        $parent = Split-Path -Parent $full
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        [System.IO.File]::WriteAllLines($full, $Lines, (New-Object System.Text.UTF8Encoding $false))
    }

    # --- the roster, in both shapes -------------------------------------------------
    Write-Fixture 'plugins\dkj-subagents\team-test\agents\09-91-agent.md' @(
        '---',
        'name: zephyr',
        'id: 91',
        'group: 09',
        '---',
        '',
        '# Zephyr -- the Test Specialist'
    )
    Write-Fixture 'plugins\dkj-subagents\team-test\personas\09-92-persona.md' @(
        '---',
        'id: 92',
        'group: 09',
        '---',
        '',
        '# Quill -- the Persona Specialist'
    )

    # --- context layer: prose + link text -------------------------------------------
    Write-Fixture 'CLAUDE.md' @(
        '# Fixture',
        '',
        'Zephyr owns the manuals.',                                   # prose
        'See [Zephyr #91](plugins/dkj-subagents/team-test/agents/09-91-agent.md) for detail.',  # link text
        'Quill routes the work.',                                     # prose, persona name
        # THE REGRESSION LINE. Two occurrences of one name on a single line: one inside a link's text,
        # one in prose after it. The line-based version of Find-Mentions reported this as ONE hit and
        # filed it as link text, hiding the prose half behind a 'safe to leave' label -- the exact shape
        # of .claude/specialists/lenses/06-25-extension.md:430 in the real tree.
        'Owned by [Zephyr #91](x.md); Zephyr also signs off the release.'
    )

    # --- docs layer -------------------------------------------------------------------
    Write-Fixture 'README.md' @(
        '# Fixture readme',
        'Zephyr is listed here.'
    )

    # A README that no hardcoded allowlist would have named. Classification is by FILENAME, so this
    # must land in DOCS rather than CONTEXT -- the gap review found, where .claude/specialists/README.md
    # (eleven mentions of Chris) was being reported as model context.
    Write-Fixture 'deep\nested\place\README.md' @(
        '# Nested readme',
        'Zephyr is mentioned here too.'
    )

    # --- history layer (must be counted, not listed, by default) -----------------------
    Write-Fixture 'releases\1.x\1.0.0.md' @(
        '# Release 1.0.0',
        'Zephyr joined in this release.',
        'Zephyr was renamed from nothing.'
    )
    Write-Fixture 'CHANGELOG.md' @(
        '# Changelog',
        'Zephyr did the work.'
    )

    # --- releases/README.md is the LIVING index, not history --------------------------
    Write-Fixture 'releases\README.md' @(
        '# Releases',
        'Zephyr maintains this page.'
    )

    # --- tests layer -------------------------------------------------------------------
    Write-Fixture 'scripts\tests\sample.tests.ps1' @(
        '# Assert on Zephyr here'
    )

    # --- scripts layer ------------------------------------------------------------------
    Write-Fixture 'scripts\lib\sample-lib.ps1' @(
        '# NOTE (Zephyr, review finding): keep this'
    )

    # --- the word-boundary trap ----------------------------------------------------------
    # 'Zephyrion' must NOT count as 'Zephyr'. A substring match here would inflate every number the
    # script prints and would be invisible in the output, which is the worst kind of wrong.
    Write-Fixture 'docs\trap.md' @(
        'Zephyrion is a different word entirely.',
        'So is prezephyr.'
    )

    Push-Location $dir
    try {
        Invoke-FixtureGitJudged @('init', '--quiet')
        Invoke-FixtureGitJudged @('config', 'user.email', 'fixture@example.com')
        Invoke-FixtureGitJudged @('config', 'user.name', 'Fixture')
        # gpgsign off: a locked signing agent must not fail a fixture commit for a reason unrelated to the test (#1287).
        Invoke-FixtureGitJudged @('config', 'commit.gpgsign', 'false')
        Invoke-FixtureGitJudged @('add', '-A')
        Invoke-FixtureGitJudged @('commit', '--quiet', '-m', 'fixture')
    } finally {
        Pop-Location
    }
    return $dir
}

function Invoke-Script {
    param([string]$Fixture, [string[]]$ScriptArgs = @())
    # COPIED TO THE PATH IT REALLY LIVES AT, scripts\sync\ (issue #2115). It used to land in the
    # fixture ROOT, which was invisible for as long as every lib this script loads was resolved from
    # $repoRoot -- CLAUDE_PROJECT_DIR points at the fixture, so those found their way. A
    # $PSScriptRoot-relative sibling load cannot: from the fixture root '..\lib' resolves OUTSIDE the
    # fixture entirely. The fixture was misplacing the script; the script was right.
    $syncDir = Join-Path $Fixture 'scripts\sync'
    if (-not (Test-Path -LiteralPath $syncDir)) { New-Item -ItemType Directory -Path $syncDir -Force | Out-Null }
    $copied = Join-Path $syncDir 'find-specialist-mentions.ps1'
    Copy-Item -LiteralPath $ScriptSrc -Destination $copied -Force

    $libDir = Join-Path $Fixture 'scripts\lib'
    if (-not (Test-Path -LiteralPath $libDir)) { New-Item -ItemType Directory -Path $libDir -Force | Out-Null }
    Copy-Item -LiteralPath $ReportLibSrc -Destination (Join-Path $libDir 'check-report-lib.ps1') -Force
    # repo-root-lib.ps1 (#2115): the script resolves its git-root fallback through Get-GitTopLevelPath,
    # loaded $PSScriptRoot-relative -- so it is a sibling of the COPY above, not of the original.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\repo-root-lib.ps1') -Destination (Join-Path $libDir 'repo-root-lib.ps1') -Force

    $prev = $env:CLAUDE_PROJECT_DIR
    $env:CLAUDE_PROJECT_DIR = $Fixture
    try {
        # EAP LOWERED FOR THE CALL, AND THE VERDICT DEPENDS ON IT (#1954). Under '& powershell ... 2>&1'
        # the parent re-renders the child's stderr as its own NativeCommandError, which at 'Stop' is
        # TERMINATING -- so a child that died on load killed this suite at the invocation and the verdict
        # below never ran. Measured here by dropping check-report-lib.ps1 from the copy list above: the
        # run ended at the first case with a truncated NativeCommandError and no headline at all. This is
        # function-scoped, so it reverts on return, and it is the same arrangement the six suites #1934
        # wired already make.
        $ErrorActionPreference = 'Continue'
        $out  = & powershell -NoProfile -ExecutionPolicy Bypass -File $copied @ScriptArgs 2>&1
        $code = $LASTEXITCODE
        # #1934: a load failure is not a refusal -- say so before the asserts read a document nothing wrote.
        Assert-FixtureScriptLoaded -Code $code -Script $copied -Output $out
        return [pscustomobject]@{ Out = (Get-FlatOutput $out); Code = $code }
    } finally {
        $env:CLAUDE_PROJECT_DIR = $prev
    }
}

Write-Host ''
Write-Host '== find-specialist-mentions.tests.ps1 ==' -ForegroundColor Cyan

$fixture = New-Fixture
try {
    # -- 1. the overview -------------------------------------------------------------
    Write-Host ''
    Write-Host '-- overview mode'
    $r = Invoke-Script -Fixture $fixture
    Assert-Equal 0 $r.Code 'overview: exit code 0'
    Assert-True ($r.Out -match 'Zephyr')                 'overview: the agent-def specialist is listed'
    Assert-True ($r.Out -match 'Quill')                  'overview: the PERSONA specialist is listed too'
    Assert-True ($r.Out -match '2 specialists')          'overview: both shapes counted, and nothing else invented'

    # The roster is derived, not hardcoded: no name from the real repo may appear for this fixture.
    Assert-True ($r.Out -notmatch '\bTessa\b')           'overview: roster is DERIVED -- no real-repo name leaks in'
    Assert-True ($r.Out -notmatch '\bChris\b')           'overview: roster is DERIVED -- orchestrator name absent too'

    # -- 2. the detail view ----------------------------------------------------------
    Write-Host ''
    Write-Host '-- detail mode'
    $d = Invoke-Script -Fixture $fixture -ScriptArgs @('-Name', 'Zephyr')
    Assert-Equal 0 $d.Code 'detail: exit code 0'

    # Live = the agent def itself (2: its `name:` line and its H1) + CLAUDE.md (4: prose, link, and the
    #        regression line's link + prose) + README.md (1) + nested README (1) + releases/README.md (1)
    #      + tests (1) + scripts (1) = 11.
    # The specialist's OWN definition counting is deliberate and worth stating: at a rename that file
    # is the first place that has to change, so a report that hid it would hide the important one.
    # History = releases/1.x/1.0.0.md (2) + CHANGELOG.md (1) = 3, counted but not listed.
    Assert-True ($d.Out -match '11 live mentions')       'detail: live count excludes history'
    Assert-True ($d.Out -match '09-91-agent\.md')        'detail: the specialist OWN definition is reported'
    Assert-True ($d.Out -match 'HISTORY: 3 more')        'detail: history is counted separately'
    Assert-True ($d.Out -notmatch '1\.0\.0\.md')         'detail: history is NOT listed without -IncludeHistory'

    # -- 3. layer classification -----------------------------------------------------
    Write-Host ''
    Write-Host '-- layers'
    Assert-True ($d.Out -match 'CONTEXT')                'layers: context layer reported'
    Assert-True ($d.Out -match 'DOCS')                   'layers: docs layer reported'
    Assert-True ($d.Out -match 'TESTS')                  'layers: tests layer reported'
    Assert-True ($d.Out -match 'SCRIPTS')                'layers: scripts layer reported'
    # releases/README.md is the living index and must NOT be filed as history.
    Assert-True ($d.Out -match 'releases/README\.md|releases\\README\.md') 'layers: releases/README.md counts as live, not history'
    # A README nowhere near an allowlist still lands in DOCS -- classification is by filename.
    $docsBlock = ($d.Out -split '-- SCRIPTS')[0]
    Assert-True ($docsBlock -match 'deep/nested/place/README\.md|deep\\nested\\place\\README\.md') `
        'layers: a nested README is DOCS, not CONTEXT'

    # -- 4. link text vs prose -------------------------------------------------------
    Write-Host ''
    Write-Host '-- link text vs prose'
    Assert-True ($d.Out -match 'link text')              'split: link-text group is named'
    Assert-True ($d.Out -match 'prose')                  'split: prose group is named'
    # Two links carry the name; every other occurrence is prose. Counting per LINE would give 1 here.
    Assert-True ($d.Out -match '2 x link text')          'split: both markdown links counted, per occurrence'

    # THE REGRESSION ASSERT. The line carrying a link AND a prose mention of the same name must be
    # reported TWICE -- once under link text, once under prose. Under the line-based version it
    # appeared once, filed as link text, which is the failure mode that silently under-reports a
    # rename. Counted rather than pattern-matched across groups: the count is the claim, and a regex
    # spanning two group headings in flattened output is fragile in a way this assert must not be.
    $regressionHits = ([regex]::Matches($d.Out, 'also signs off the release')).Count
    Assert-Equal 2 $regressionHits 'split: a line with link AND prose is reported in both groups'

    # -- 5. the word-boundary trap ---------------------------------------------------
    Write-Host ''
    Write-Host '-- word boundary'
    Assert-True ($d.Out -notmatch 'Zephyrion')           'boundary: a longer word containing the name is not a match'
    Assert-True ($d.Out -notmatch 'trap\.md')            'boundary: the trap file produces no hit at all'

    # -- 6. a retired name is still scanned ------------------------------------------
    # The case the tool exists for: verifying a FINISHED rename. The old name is by definition no
    # longer in the roster, so refusing to scan it would make the tool useless for its main job.
    Write-Host ''
    Write-Host '-- retired name'
    $ret = Invoke-Script -Fixture $fixture -ScriptArgs @('-Name', 'Zephyrion')
    Assert-Equal 0 $ret.Code 'retired: exit code 0 (never a gate)'
    Assert-True ($ret.Out -match 'Unknown specialist')   'retired: says the name is not in the roster'
    Assert-True ($ret.Out -match 'scanned anyway')       'retired: states that it scans regardless'
    Assert-True ($ret.Out -match '1 live mention')       'retired: and actually reports the hit'

    # -- 7. -IncludeHistory ----------------------------------------------------------
    Write-Host ''
    Write-Host '-- IncludeHistory'
    $h = Invoke-Script -Fixture $fixture -ScriptArgs @('-Name', 'Zephyr', '-IncludeHistory')
    Assert-Equal 0 $h.Code 'history: exit code 0'
    Assert-True ($h.Out -match '1\.0\.0\.md')            'history: the release note IS listed with the switch'

    # -- 8. read-only ----------------------------------------------------------------
    # The promise in the docstring, asserted rather than trusted: a reporter that quietly edits is a
    # different tool than the one this was reviewed as.
    Write-Host ''
    Write-Host '-- read-only'
    Push-Location $fixture
    try {
        # The files Invoke-Script copies in are the harness, not the script's doing -- the script
        # itself, and the two libs it loads ($PSScriptRoot-relative repo-root-lib since #2115).
        # -uall, AND IT IS LOAD-BEARING SINCE #2115. Plain --porcelain COLLAPSES a wholly untracked
        # directory into one entry, and this suite's copy target moved into scripts\sync\, which the
        # fixture does not track -- so the entry read '?? scripts/sync/' and matched no filename in the
        # filter below. scripts\lib\ never had the problem: the fixture tracks a file there, so git
        # already listed its members one by one. -uall makes every entry a FILE path, which is what the
        # filter is written against and what a stray write would have to appear as anyway.
        $status = @(git status --porcelain -uall 2>$null |
            Where-Object { $_ -notmatch 'find-specialist-mentions\.ps1' -and $_ -notmatch 'check-report-lib\.ps1' -and $_ -notmatch 'repo-root-lib\.ps1' })
    } finally {
        Pop-Location
    }
    Assert-Equal 0 $status.Count 'read-only: the tree is untouched after four runs'
    Assert-True ($d.Out -match 'only reads')             'read-only: and the script says so in its output'

} finally {
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
# ABOVE THE VERDICT AND EVEN ON A GREEN RUN: a clean sweep over a fixture repo that was never built
# proves less than it appears to, so the count decides the exit code too (issue #1635).
$fixtureBroken = Write-FixtureGitSummary -Subject 'find-specialist-mentions.ps1'
# AND THE SAME FOR A CHILD THAT DIED ON LOAD (issues #1934 and #1954): a run where every assert happened
# to pass is still a run that measured a fixture rather than the script, so the count decides the exit
# code here too.
$loadBroken = Write-FixtureScriptSummary -Subject 'find-specialist-mentions.ps1'
Write-Host ("  {0} passed, {1} failed" -f $script:pass, $script:fail)
Write-Host ''
if ($script:fail -gt 0) { exit 1 }
if ($loadBroken) {
    Write-Host "FAILED: $(Get-FixtureScriptLoadFailureCount) child script(s) died on load -- this run measured a fixture, not the script." -ForegroundColor Red
    exit 1
}
if ($fixtureBroken) {
    Write-Host "FAILED: every assert passed, but $(Get-FixtureGitFailureCount) fixture git command(s) did not -- this run proves less than it appears to." -ForegroundColor Red
    exit 1
}
exit 0
