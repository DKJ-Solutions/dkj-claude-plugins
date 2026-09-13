<#
.SYNOPSIS
    Tests for scripts/maintenance/fix-mojibake.ps1 and the lint gate that consults it (check 14).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Exit code 0 if everything passes, 1 on a
    failure -- so usable as a CI gate.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/fix-mojibake.tests.ps1

    WHY THIS SUITE EXISTS, measured August 1, 2026. Demoting four headings in CHANGELOG.md with
    Get-Content + WriteAllLines mangled 35 separators into 105 double-encoded sequences. Windows
    PowerShell 5.1's Get-Content reads a BOM-less UTF-8 file as ANSI, so a middot (U+00B7, bytes C2 B7)
    comes back as two characters, and writing that back as UTF-8 stores the mangled pair. NOTHING ERRORS:
    the file stays valid UTF-8 and simply says something else.

    It was not cosmetic. The middot IS the field delimiter in a changelog entry heading, so
    cut-release.ps1 could no longer read the entry TYPE and eleven entries fell into a catch-all category
    instead of Features/Fixes/Documentation. It was caught by inspecting the generated notes before
    pushing -- one person looking carefully at the right moment, which is exactly what a gate is for.

    THIS FILE IS PURE ASCII, like the script it tests: every non-ASCII character is built from
    codepoints. A test for mojibake that is itself written in literal mangled characters corrupts on the
    first careless edit and then asserts nothing.

    Third repo to meet this class (smartwatchbanden -> life-hub -> here), so the suite asserts the two
    properties that make the tool trustworthy rather than merely present: the fixpoint loop (double
    damage needs two passes) and idempotence (a second run changes nothing).
#>
$ErrorActionPreference = 'Stop'

# THE REPO ROOT, judged and ANCHORED (#1917). -From pins the git call to this file's own directory
# instead of the inherited working directory: this suite tree stands up throwaway git repos and
# changes into them, so a cwd-relative answer can name the wrong repo. Resolve-RepoRootOrFail
# refuses with git's exit code and stderr where the old (git rev-parse ...).Trim() died on
# $null.Trim() -- which here meant a suite testing the wrong file, or none.
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$RepoRoot = Resolve-RepoRootOrFail -From $PSScriptRoot -ScriptName 'fix-mojibake.tests.ps1'
$Script = Join-Path $RepoRoot 'scripts\maintenance\fix-mojibake.ps1'
$Lint = Join-Path $RepoRoot 'scripts\lint\check-plugin-integrity.ps1'

$script:pass = 0
$script:fail = 0

function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    if ($Expected -eq $Actual) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}
function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}

function Test-Says {
    <# Does captured child output contain this phrase, whatever the console did to it?

       Strips ALL whitespace from both sides. Normalizing '\s+' to a single space -- which this file
       does to the captured text -- repairs a wrap BETWEEN words and does nothing for a wrap INSIDE
       one, and the child's formatter breaks at whatever character sits at the buffer column. Which
       asserts straddle a break is decided by the width, so a green run is not evidence (issue #1512;
       the worked measurement is in verify-resolved-issues.tests.ps1).

       Literal (IndexOf), so a phrase carrying '(', ')', '.', '[' or ']' needs no escaping;
       OrdinalIgnoreCase keeps the case-insensitivity that -match had at these call sites. #>
    param([string]$Text, [string]$Phrase)
    $haystack = ($Text -replace '\s', '')
    $needle = ($Phrase -replace '\s', '')
    return ($haystack.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
}

function Assert-Says {
    param([string]$Text, [string]$Phrase, [string]$Name)
    if (Test-Says -Text $Text -Phrase $Phrase) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         wanted to find: '$Phrase'`n         in:             '$Text'" -ForegroundColor Red
    }
}

# Build strings from codepoints, so this source stays ASCII-only.
function C([int[]]$cp) { -join ($cp | ForEach-Object { [char]$_ }) }
$MIDDOT = C 0xB7          # the correct character
$ONCE = C 0xC2, 0xB7      # mangled once
$TWICE = C 0xC3, 0x201A, 0xC2, 0xB7  # mangled twice -- what a second round trip leaves
$EMDASH = C 0x2014
$EMDASH_BAD = C 0xE2, 0x20AC, 0x201D

$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
$Fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("mojibake-fix-$PID-$([guid]::NewGuid().ToString('n'))")
New-Item -ItemType Directory -Path $Fixture -Force | Out-Null

function Invoke-Fix {
    # .Out is whitespace-NORMALIZED so a failing assert prints one readable line -- it is NOT what
    # makes the asserts width-proof. The child wraps at its own console width and the break lands
    # inside a word as readily as on a space, which collapsing '\s+' to a space does not repair
    # (#1512). Prose asserts therefore go through Assert-Says, which strips ALL whitespace.
    param([string]$FilePath, [switch]$CheckOnly)
    $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Script, '-Path', $FilePath)
    if ($CheckOnly) { $a += '-Check' }
    $out = (& powershell @a 2>&1 | Out-String)
    return [pscustomobject]@{ Out = ($out -replace '\s+', ' '); Code = $LASTEXITCODE }
}

function Invoke-FixWithDefaultPaths {
    <#
        Runs the tool with NO -Path, against a throwaway repo root supplied via CLAUDE_PROJECT_DIR --
        the same dual-context door a consumer running the plugin mirror comes through. That is the only
        way to exercise the DEFAULT file set (issue #413), which every other scenario in this suite
        bypasses by naming its file explicitly.

        CLAUDE_PROJECT_DIR is set for the CHILD only and restored afterwards, so a fixture cannot leak
        into the rest of the suite or into the lint-gate run at the bottom of this file.
    #>
    param([string]$Root, [switch]$CheckOnly)
    $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Script)
    if ($CheckOnly) { $a += '-Check' }
    $prev = $env:CLAUDE_PROJECT_DIR
    try {
        $env:CLAUDE_PROJECT_DIR = $Root
        $out = (& powershell @a 2>&1 | Out-String)
        return [pscustomobject]@{ Out = ($out -replace '\s+', ' '); Code = $LASTEXITCODE }
    } finally {
        if ($null -eq $prev) { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_PROJECT_DIR = $prev }
    }
}

function New-DefaultPathsRoot {
    <# A throwaway repo root holding a damaged file in the ROOT and a damaged file in a SUBDIRECTORY,
       so the two default-set scenarios can tell which of them a run actually reached. #>
    param([string]$Label)
    $root = Join-Path $Fixture "root-$Label"
    New-Item -ItemType Directory -Path (Join-Path $root 'deep') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root 'scripts') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $root 'CHANGELOG.md'), "### #1 $ONCE Title $ONCE Fix", $Utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $root 'feat-some-branch.md'), "### #2 $ONCE Entry $ONCE Feat", $Utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $root 'deep\buried.md'), "### #3 $ONCE Buried $ONCE Docs", $Utf8NoBom)
    return $root
}

function Set-Fixture {
    param([string]$Name, [string]$Text, [switch]$WithBom)
    $p = Join-Path $Fixture $Name
    $enc = New-Object System.Text.UTF8Encoding ([bool]$WithBom)
    [System.IO.File]::WriteAllText($p, $Text, $enc)
    return $p
}
function Get-FixtureText {
    param([string]$Path)
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

try {
    Write-Host 'A single mangled separator is repaired' -ForegroundColor Cyan
    $f = Set-Fixture -Name 'one.md' -Text ("### #1 $ONCE Title $ONCE Fix $ONCE 2026-08-01")
    $r = Invoke-Fix -FilePath $f
    Assert-Equal 0 $r.Code 'exits 0'
    $t = Get-FixtureText -Path $f
    Assert-Equal 3 (@([regex]::Matches($t, [regex]::Escape($MIDDOT))).Count) 'all three separators are correct middots'
    Assert-True ($t -notmatch [regex]::Escape($ONCE)) 'no mangled sequence survives'

    Write-Host 'DOUBLE damage needs the fixpoint loop, not one pass' -ForegroundColor Cyan
    #      The property that cost life-hub a manual fix at v2.1.0: one pass peels the outer layer and
    #      leaves a remainder that matches no rule. If the loop is ever replaced by a single pass, this
    #      is the assert that fails.
    $f2 = Set-Fixture -Name 'twice.md' -Text ("### #2 $TWICE Title $TWICE Docs")
    $r2 = Invoke-Fix -FilePath $f2
    $t2 = Get-FixtureText -Path $f2
    Assert-Equal 2 (@([regex]::Matches($t2, [regex]::Escape($MIDDOT))).Count) 'doubly mangled separators come out as middots'
    Assert-True ($t2 -notmatch [regex]::Escape($ONCE)) 'and no half-peeled remainder is left behind'

    Write-Host 'DOUBLE damage in a character the table never listed' -ForegroundColor Cyan
    #      THE GAP THAT SHIPPED (August 2, 2026). The case above works because the table happens to carry a
    #      peel rule for the outer layer of a 0xC2 sequence. Nothing covered the outer layer of an 0xE2
    #      sequence, so a doubly-mangled em dash, arrow or ellipsis matched no rule at all: the fixpoint
    #      loop exited on its first pass and the file was pronounced clean. Measured on this repo at
    #      v3.1.0 -- 517 damaged runs across four files, three of them inside the gate's own stated scope,
    #      while the gate reported "No findings".
    #
    #      Asserted per character rather than once, because the table's coverage was exactly the thing that
    #      looked complete and was not. These four are the ones the repo actually carried; the point of the
    #      general inverse is that it does not need them enumerated, and this test would keep passing if a
    #      fifth turned up.
    foreach ($case in @(
        @{ Name = 'em dash';  Good = (C 0x2014); Bad = (C 0xC3, 0xA2, 0xE2, 0x201A, 0xAC, 0xE2, 0x20AC, 0x9D) },
        @{ Name = 'arrow';    Good = (C 0x2192); Bad = (C 0xC3, 0xA2, 0xE2, 0x20AC, 0xA0, 0xE2, 0x20AC, 0x2122) },
        @{ Name = 'ellipsis'; Good = (C 0x2026); Bad = (C 0xC3, 0xA2, 0xE2, 0x201A, 0xAC, 0xC2, 0xA6) },
        @{ Name = 'en dash';  Good = (C 0x2013); Bad = (C 0xC3, 0xA2, 0xE2, 0x201A, 0xAC, 0xE2, 0x20AC, 0x153) }
    )) {
        $fd = Set-Fixture -Name ("double-" + ($case.Name -replace ' ', '-') + '.md') -Text ("before $($case.Bad) after")
        Invoke-Fix -FilePath $fd | Out-Null
        $td = Get-FixtureText -Path $fd
        Assert-Equal "before $($case.Good) after" $td "doubly mangled $($case.Name) is peeled all the way back"
    }

    Write-Host 'Correct text survives the general inverse untouched' -ForegroundColor Cyan
    #      The round trip is only safe because it FAILS on text that was never mojibake. If either encoder
    #      is ever given a lenient fallback, this is the assert that catches it -- a lenient Windows-1252
    #      encoder turns every one of these into '?' without raising anything.
    $intact = "em dash $EMDASH arrow $(C 0x2192) middot $MIDDOT e-acute $(C 0xE9) u-diaeresis $(C 0xFC)$(C 0xFC) bulb $([System.Char]::ConvertFromUtf32(0x1F4A1))"
    $fi = Set-Fixture -Name 'intact.md' -Text $intact
    $ri = Invoke-Fix -FilePath $fi
    Assert-Equal $intact (Get-FixtureText -Path $fi) 'every correctly encoded character survives the round trip'
    Assert-Says $ri.Out 'Nothing to repair' 'and the tool reports nothing to do'

    Write-Host 'Idempotent: a second run changes nothing' -ForegroundColor Cyan
    $before = Get-FixtureText -Path $f2
    $r3 = Invoke-Fix -FilePath $f2
    Assert-Equal $before (Get-FixtureText -Path $f2) 'the file is byte-for-byte unchanged on a second run'
    Assert-Says $r3.Out 'Nothing to repair' 'and it says so rather than reporting phantom replacements'

    Write-Host 'Correctly encoded text is left alone' -ForegroundColor Cyan
    #      The direction of error that matters: this tool may only ever repair, never invent. A middot and
    #      an em dash that are already right must survive untouched.
    $good = "### #3 $MIDDOT A title with an em dash $EMDASH here $MIDDOT Feat"
    $f4 = Set-Fixture -Name 'good.md' -Text $good
    $r4 = Invoke-Fix -FilePath $f4
    Assert-Equal $good (Get-FixtureText -Path $f4) 'a correct file is not touched'
    Assert-Says $r4.Out 'Nothing to repair' 'and it reports nothing to do'

    Write-Host 'A mangled em dash is repaired too (not just the separator)' -ForegroundColor Cyan
    $f5 = Set-Fixture -Name 'emdash.md' -Text ("A title $EMDASH_BAD with damage")
    Invoke-Fix -FilePath $f5 | Out-Null
    Assert-True ((Get-FixtureText -Path $f5) -match [regex]::Escape($EMDASH)) 'the em dash is restored'

    Write-Host 'A UTF-8 BOM is preserved, and absence of one is preserved too' -ForegroundColor Cyan
    $f6 = Set-Fixture -Name 'bom.md' -Text ("### #6 $ONCE T") -WithBom
    Invoke-Fix -FilePath $f6 | Out-Null
    $b6 = [System.IO.File]::ReadAllBytes($f6)
    Assert-True ($b6[0] -eq 0xEF -and $b6[1] -eq 0xBB -and $b6[2] -eq 0xBF) 'a file with a BOM keeps it'
    $f7 = Set-Fixture -Name 'nobom.md' -Text ("### #7 $ONCE T")
    Invoke-Fix -FilePath $f7 | Out-Null
    $b7 = [System.IO.File]::ReadAllBytes($f7)
    Assert-True (-not ($b7[0] -eq 0xEF -and $b7[1] -eq 0xBB -and $b7[2] -eq 0xBF)) 'a file without a BOM does not gain one'

    Write-Host '-Check reports without changing, and exits 1 on damage' -ForegroundColor Cyan
    $f8 = Set-Fixture -Name 'check.md' -Text ("### #8 $ONCE T")
    $textBefore = Get-FixtureText -Path $f8
    $r8 = Invoke-Fix -FilePath $f8 -CheckOnly
    Assert-Equal 1 $r8.Code '-Check exits 1 when there is damage'
    Assert-Equal $textBefore (Get-FixtureText -Path $f8) '-Check changed nothing'
    Assert-Says $r8.Out '[mojibake]' '-Check names the finding with the marker the lint gate reads'
    Assert-Says $r8.Out 'check.md' '-Check names the file'

    Write-Host '-Check on a clean file exits 0' -ForegroundColor Cyan
    $f9 = Set-Fixture -Name 'clean.md' -Text ("### #9 $MIDDOT T")
    $r9 = Invoke-Fix -FilePath $f9 -CheckOnly
    Assert-Equal 0 $r9.Code '-Check exits 0 on a clean file'
    Assert-Says $r9.Out 'clean' 'and says so'

    Write-Host 'Default file set without a repo-config: every *.md in the repo root (#413)' -ForegroundColor Cyan
    #      The fallback has to be a real answer, not a degraded one. The old hardcoded default listed
    #      four file names plus two workshop directories, so in a consumer it reduced to whichever of
    #      those happened to exist -- and it never covered an unfolded ENTRY file at all, which is the
    #      freshest, most non-ASCII-carrying file in any repo that uses this flow.
    $rootA = New-DefaultPathsRoot -Label 'a'
    $rA = Invoke-FixWithDefaultPaths -Root $rootA
    Assert-Equal 0 $rA.Code 'no repo-config: exits 0'
    Assert-Equal "### #1 $MIDDOT Title $MIDDOT Fix" (Get-FixtureText -Path (Join-Path $rootA 'CHANGELOG.md')) 'no repo-config: the root CHANGELOG.md was repaired'
    Assert-Equal "### #2 $MIDDOT Entry $MIDDOT Feat" (Get-FixtureText -Path (Join-Path $rootA 'feat-some-branch.md')) 'no repo-config: an unfolded ENTRY file in the root was repaired -- the case the old hardcoded default never covered'
    Assert-Equal "### #3 $ONCE Buried $ONCE Docs" (Get-FixtureText -Path (Join-Path $rootA 'deep\buried.md')) 'no repo-config: a file OUTSIDE the root was left alone -- the fallback is the root, and it says so rather than guessing'

    Write-Host 'Get-MojibakePaths overrides the fallback entirely (#413)' -ForegroundColor Cyan
    #      The point of the seam: a repo that keeps markdown somewhere else says so, and the tool walks
    #      what the repo named instead of what the tool assumed. Deliberately a set that does NOT include
    #      the root -- so a pass here cannot be explained by the fallback having run anyway.
    $rootB = New-DefaultPathsRoot -Label 'b'
    $cfgB = @"
function Get-MojibakePaths {
    param([Parameter(Mandatory = `$true)][string]`$RepoRoot)
    return @((Join-Path `$RepoRoot 'deep\buried.md'))
}
"@
    [System.IO.File]::WriteAllText((Join-Path $rootB 'scripts\repo-config.ps1'), $cfgB, $Utf8NoBom)
    $rB = Invoke-FixWithDefaultPaths -Root $rootB
    Assert-Equal 0 $rB.Code 'configured set: exits 0'
    Assert-Equal "### #3 $MIDDOT Buried $MIDDOT Docs" (Get-FixtureText -Path (Join-Path $rootB 'deep\buried.md')) 'configured set: the file the repo named was repaired'
    Assert-Equal "### #1 $ONCE Title $ONCE Fix" (Get-FixtureText -Path (Join-Path $rootB 'CHANGELOG.md')) 'configured set: the root fallback did NOT also run -- the repo-owned list replaces it, it does not extend it'

    Write-Host 'A broken repo-config degrades to the fallback rather than stopping (#413)' -ForegroundColor Cyan
    #      Same discipline as new-branch (#410): a repair tool that refuses to run because a
    #      config file has a syntax error helps nobody, least of all the person whose repo is already
    #      in a state worth repairing.
    $rootC = New-DefaultPathsRoot -Label 'c'
    [System.IO.File]::WriteAllText((Join-Path $rootC 'scripts\repo-config.ps1'), "function Get-MojibakePaths { `n", $Utf8NoBom)
    $rC = Invoke-FixWithDefaultPaths -Root $rootC
    Assert-Equal 0 $rC.Code 'broken repo-config: still exits 0'
    Assert-Equal "### #1 $MIDDOT Title $MIDDOT Fix" (Get-FixtureText -Path (Join-Path $rootC 'CHANGELOG.md')) 'broken repo-config: the root fallback ran'
    Assert-Says $rC.Out 'could not be loaded' 'broken repo-config: says so out loud instead of silently examining a different set'

    Write-Host 'The lint gate (check 14) reports its category on the real repo' -ForegroundColor Cyan
    #      Asserted on the coverage line rather than on a fixture: the gate consults the tool over the
    #      repo's own docs, and "the category was examined" is the property that a refactor could silently
    #      drop. The damage-detected direction is covered by the -Check asserts above, on a fixture --
    #      deliberately, because deliberately corrupting the real CHANGELOG.md to test a gate is how a
    #      suite leaves damage behind when it fails halfway.
    #      The count is FILES, and asserted as "more than one" rather than as a literal (August 2, 2026).
    #      It used to read 'checked 1' -- the number of tool invocations, which is true of every possible
    #      scope and therefore evidence of none. Pinning the exact figure here would only mean editing this
    #      test whenever a release note is added, so the assert is on the property: the gate reports a real
    #      file count that grew past the old placeholder.
    $lintOut = (& powershell -NoProfile -ExecutionPolicy Bypass -File $Lint 2>&1 | Out-String)
    # This capture is NOT whitespace-normalized like Invoke-Fix's, so it is read whitespace-free: the
    # gate wraps its own lines at the console width and a break lands mid-word as readily as on a
    # space (#1512). The coverage regex is matched against the stripped text for the same reason --
    # '[mojibake] checked 42' split after 'check' would otherwise report the gate as never having run.
    $lintFlat = ($lintOut -replace '\s', '')
    $mjCov = [regex]::Match($lintFlat, '\[mojibake\]checked(\d+)')
    Assert-True $mjCov.Success 'the lint gate ran the encoding check'
    Assert-True ([int]$mjCov.Groups[1].Value -gt 1) 'and reports how many files it examined, not how many times it ran the tool'
    Assert-Says $lintOut 'releases/' 'and its coverage line names the releases/ notes, which were outside the scope until #360-era'
    Assert-Says $lintOut 'Summary: 0 error' 'and the repo is clean of mojibake'
    # The findings, on failure only -- same reason as the twin asserts in bootstrap-drift.tests.ps1 and
    # subagent-shared.tests.ps1: this reads the gate's verdict over the LIVE repo, so it can fail from a
    # collision with a concurrent suite. Measured August 16, 2026: this assert and bootstrap-drift's failed
    # together in one pooled run of 43 suites and passed in the next three, and neither said WHAT the gate
    # had found. Note it fires on any non-zero summary, including one that names no mojibake at all -- that
    # is the point: the assert reads the whole gate, so its failure has to be readable as such.
    if ($lintOut -notmatch 'Summary: 0 error') {
        @($lintOut -split "`r?`n" | Where-Object { $_ -match '^\s*\[' -and $_ -notmatch 'checked \d' } | Select-Object -First 10) |
            ForEach-Object { Write-Host ("         gate said: " + $_.Trim()) -ForegroundColor DarkYellow }
    }
} finally {
    Remove-Item -LiteralPath $Fixture -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
