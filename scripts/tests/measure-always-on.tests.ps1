<#
.SYNOPSIS
    Tests for scripts/lib/measure-context-lib.ps1 and scripts/maintenance/measure-always-on.ps1.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Exit code 0 if everything passes, 1 on a
    failure -- so usable as a CI gate.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/measure-always-on.tests.ps1

    WHAT THIS SUITE IS FOR. The subject is a MEASUREMENT, and a measurement that is quietly wrong is
    worse than one that refuses: it gets pasted into a document, cited, and planned against. So the
    asserts here are mostly about arithmetic and about the walk's guards, not about wording -- the two
    properties that make the number trustworthy rather than merely present:

      1. THE PARTS SUM TO THE WHOLE. The sections tile a file by construction, so their bytes must equal
         the file length exactly. If they do not, every share in the report is wrong.
      2. THE WALK TERMINATES AND COUNTS EACH DOCUMENT ONCE. A cycle must not hang, a diamond must not
         double-count, and the hop cap must actually cap.

    THREE OF THESE ASSERTS EXIST BECAUSE THE FIRST DRAFT GOT THEM WRONG, which is the honest reason to
    pin them rather than trust them:

      - `$home` is a READ-ONLY automatic variable. Assigning to it threw a non-terminating error while
        the built-in value -- the user profile, i.e. usually the right answer -- stayed in place, so the
        home-relative import resolved CORRECTLY while erroring. Well-formed wrong output, arriving
        through the front door.
      - the number formatting followed the CURRENT CULTURE, so on this machine (nl-NL) the report printed
        '29.044' for 29,044 bytes and '3,12' for the factor -- the exact ambiguity
        measure-skill-lib's ConvertTo-TokenCount is documented to disambiguate. That suite pins the same
        class by setting the culture to nl-NL on purpose, and this one follows it.
      - `if` is not an expression in a hashtable value position in Windows PowerShell 5.1, so the walk
        did not parse at all until the branches were hoisted out.

    THIS FILE IS PURE ASCII, like the sources it tests: every non-ASCII character is built from
    codepoints. The fixture deliberately contains a multi-byte character, because a byte count that is
    secretly a character count agrees with the truth for pure ASCII and diverges the moment it does not.
#>
$ErrorActionPreference = 'Stop'

# THE REPO ROOT, judged and ANCHORED (#1917). -From pins the git call to this file's own directory
# instead of the inherited working directory: this suite tree stands up throwaway git repos and
# changes into them, so a cwd-relative answer can name the wrong repo. Resolve-RepoRootOrFail
# refuses with git's exit code and stderr where the old (git rev-parse ...).Trim() died on
# $null.Trim() -- which here meant a suite testing the wrong file, or none.
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$RepoRoot = Resolve-RepoRootOrFail -From $PSScriptRoot -ScriptName 'measure-always-on.tests.ps1'
$Lib = Join-Path $RepoRoot 'scripts\lib\measure-context-lib.ps1'
$Script = Join-Path $RepoRoot 'scripts\maintenance\measure-always-on.ps1'

. $Lib

$script:pass = 0
$script:fail = 0

function Assert-Equal {
    # SCALARS ONLY. '-eq' against an array FILTERS it rather than comparing it, so an array assert
    # silently degrades into a truthiness test and then reports two identical-looking values as
    # different. Compare a joined string instead -- three asserts in the first draft of this suite
    # failed in exactly that way, printing the same text on both lines.
    param($Expected, $Actual, [string]$Name)
    if ($Expected -eq $Actual) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}
function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}

# Built from codepoints so this source stays ASCII-only. U+00B7 is two bytes in UTF-8, which is the
# point: it makes a byte count and a character count disagree.
function C([int[]]$cp) { -join ($cp | ForEach-Object { [char]$_ }) }
$MIDDOT = C 0xB7

# $PID in the fixture path, per the suite convention in scripts/README.md: the test gate is a throttled
# PARALLEL scheduler, so two runs at one fixed path tear down each other's tree mid-assert and the
# visible result is a red gate naming a subject that is fine.
$Fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("measure-always-on-$PID-$([guid]::NewGuid().ToString('n'))")
if (Test-Path $Fixture) { Remove-Item -Recurse -Force $Fixture }
New-Item -ItemType Directory -Path $Fixture -Force | Out-Null
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

function New-Fixture {
    param([string]$RelPath, [string[]]$Lines)
    $full = Join-Path $Fixture $RelPath
    $dir = Split-Path -Parent $full
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($full, (($Lines -join "`n") + "`n"), $Utf8NoBom)
    return $full
}

try {
    Write-Host ''
    Write-Host 'The calibrated factor' -ForegroundColor Cyan

    $f = Get-CalibratedCharsPerToken
    Assert-Equal 3.12 $f.Value 'the factor is the calibrated median, not the retired 3.70'
    Assert-True ($f.Basis -match 'count_tokens') 'the factor carries its provenance'
    Assert-True ($f.Caveat -match 'ESTIMATE') 'the factor carries the estimate caveat'
    # 1000 / 3.12 = 320.5, so this rounds UP. The first draft asserted 320 and was simply wrong; pinned
    # at 321 rather than loosened, because a rounding rule is exactly the kind of thing worth fixing in
    # place once so it never drifts.
    Assert-Equal 321 (ConvertTo-EstimatedTokens -Bytes 1000 -CharsPerToken 3.12) '1000 B is ~321 tokens at 3.12'
    Assert-Equal 3205 (ConvertTo-EstimatedTokens -Bytes 10000) 'the default factor is the calibrated one'

    Write-Host ''
    Write-Host 'Invariant formatting -- pinned under a comma-decimal culture' -ForegroundColor Cyan

    # The whole point of this block: run it under nl-NL, where ':N0' would print '29.044' and '40,5'.
    $prevCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
    try {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('nl-NL')
        Assert-Equal '29,044' (Format-MeasuredBytes 29044) 'a byte count uses the comma as a thousands separator under nl-NL'
        Assert-Equal '40.5' (Format-MeasuredShare 40.5) 'a share uses the point as a decimal under nl-NL'
        Assert-Equal '3.12' (Format-MeasuredNumber -Value 3.12 -Format '{0:0.00}') 'the factor prints with a decimal point under nl-NL'
        Assert-Equal 'n/a' (Format-MeasuredBytes $null) 'a null is n/a, not zero'
    } finally {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = $prevCulture
    }

    Write-Host ''
    Write-Host 'Resolving an import target' -ForegroundColor Cyan

    Assert-Equal '.claude/x.md' (Get-ImportLinePath '@.claude/x.md') 'a column-0 @ line is an import'
    Assert-Equal $null (Get-ImportLinePath '  @.claude/x.md') 'an indented @ is not an import'
    Assert-Equal $null (Get-ImportLinePath 'ask @dkj-subagents-alpha:tessa about it') 'an @ mid-line is not an import'
    Assert-Equal $null (Get-ImportLinePath 'plain prose') 'prose is not an import'
    Assert-Equal $null (Get-ImportLinePath '@') 'a bare @ is not an import'

    $importer = Join-Path $Fixture 'a\b\CLAUDE.md'
    $rel = Resolve-ImportPath -Target 'lenses/x.md' -ImportingFile $importer
    Assert-Equal ([System.IO.Path]::GetFullPath((Join-Path $Fixture 'a\b\lenses\x.md'))) $rel 'a relative target resolves from the IMPORTING FILE, not the repo root'

    $env:MEASURE_CONTEXT_HOME = $Fixture
    try {
        $homeResolved = Resolve-ImportPath -Target '~/plugins/p.md' -ImportingFile $importer
        Assert-Equal ([System.IO.Path]::GetFullPath((Join-Path $Fixture 'plugins\p.md'))) $homeResolved 'a ~/ target resolves against the user home'
    } finally {
        Remove-Item Env:\MEASURE_CONTEXT_HOME -ErrorAction SilentlyContinue
    }

    Write-Host ''
    Write-Host 'The section split is byte-exact' -ForegroundColor Cyan

    $doc = New-Fixture 'sections\DOC.md' @(
        'preamble line',
        '',
        '# Title',
        'body of title',
        '## Alpha',
        "alpha body with a $MIDDOT in it",
        '### Alpha deep',
        'deep body',
        '#### Deeper still',
        'this belongs to Alpha deep at depth 3',
        '## Beta',
        'beta body'
    )
    $fileBytes = (Get-Item $doc).Length
    $sections = @(Get-DocumentSections -Path $doc -MaxLevel 3)
    $sum = ($sections | Measure-Object -Property Bytes -Sum).Sum
    Assert-Equal $fileBytes $sum 'the sections sum EXACTLY to the file length'
    Assert-Equal '(preamble)' $sections[0].Heading 'bytes before the first heading are a leading section, not discarded'
    Assert-Equal '(preamble)|Title|Alpha|Alpha deep|Beta' (@($sections | ForEach-Object { $_.Heading }) -join '|') 'a level-4 heading does not open a section at depth 3'

    $deep = @(Get-DocumentSections -Path $doc -MaxLevel 4)
    Assert-True (@($deep | Where-Object { $_.Heading -eq 'Deeper still' }).Count -eq 1) 'the same heading DOES open a section at depth 4'
    Assert-Equal $fileBytes (($deep | Measure-Object -Property Bytes -Sum).Sum) 'the deeper split also sums to the file length'

    # A byte count that is secretly a character count would come out one short here, because of the
    # two-byte middot. This is the assert that catches a decoded-text rewrite of the split.
    $alpha = @($sections | Where-Object { $_.Heading -eq 'Alpha' })[0]
    $alphaChars = ([System.IO.File]::ReadAllText($doc, [System.Text.Encoding]::UTF8) -split "`n" |
        Where-Object { $_ -match 'alpha body' })[0].Length
    Assert-True ($alpha.Bytes -gt $alphaChars) 'the split counts BYTES, so a multi-byte character costs more than one'

    Write-Host ''
    Write-Host 'A fence is not a section, and not an import' -ForegroundColor Cyan

    $fenced = New-Fixture 'fence\DOC.md' @(
        '# Real',
        'text',
        '```text',
        '# Not a heading',
        '@not/an/import.md',
        '```',
        '## Also real'
    )
    $fs = @(Get-DocumentSections -Path $fenced -MaxLevel 3)
    Assert-Equal 'Real|Also real' (@($fs | ForEach-Object { $_.Heading }) -join '|') 'a # inside a fence does not open a section'
    Assert-Equal ((Get-Item $fenced).Length) (($fs | Measure-Object -Property Bytes -Sum).Sum) 'the fenced document still sums exactly'

    $fenceWalk = @(Get-AlwaysOnDocuments -RootDocument $fenced -RepoRoot $Fixture)
    Assert-Equal 1 $fenceWalk.Count 'an @ inside a fence is illustration, not an import to follow'

    Write-Host ''
    Write-Host 'The import walk' -ForegroundColor Cyan

    New-Fixture 'walk\leaf.md' @('# Leaf', 'leaf body') | Out-Null
    New-Fixture 'walk\mid.md' @('# Mid', '@leaf.md') | Out-Null
    $walkRoot = New-Fixture 'walk\CLAUDE.md' @('# Root', '@walk/mid.md')
    # Written from the fixture root, so the root document's own directory is 'walk' -- the import above
    # therefore has to be 'mid.md', not 'walk/mid.md'. Rewritten here on purpose: getting this wrong is
    # exactly the mistake the file-relative rule exists to make impossible to make silently.
    [System.IO.File]::WriteAllText($walkRoot, "# Root`n@mid.md`n", $Utf8NoBom)

    $walk = @(Get-AlwaysOnDocuments -RootDocument $walkRoot -RepoRoot $Fixture)
    Assert-Equal 3 $walk.Count 'the walk follows a nested import to the leaf'
    Assert-Equal '0|1|2' (@($walk | ForEach-Object { $_.Hop }) -join '|') 'each document carries its hop distance'
    Assert-True (@($walk | Where-Object { -not $_.Exists }).Count -eq 0) 'every document on the fixture path exists'

    Assert-Equal 2 (@(Get-AlwaysOnDocuments -RootDocument $walkRoot -RepoRoot $Fixture -MaxHops 1).Count) 'the hop cap actually caps'

    Write-Host ''
    Write-Host 'The walk guards: a cycle, a diamond, a dead import' -ForegroundColor Cyan

    New-Fixture 'cycle\a.md' @('# A', '@b.md') | Out-Null
    New-Fixture 'cycle\b.md' @('# B', '@a.md') | Out-Null
    $cycle = @(Get-AlwaysOnDocuments -RootDocument (Join-Path $Fixture 'cycle\a.md') -RepoRoot $Fixture)
    Assert-Equal 2 $cycle.Count 'a cycle terminates and counts each document once'

    New-Fixture 'diamond\shared.md' @('# Shared', 'body') | Out-Null
    New-Fixture 'diamond\left.md' @('# Left', '@shared.md') | Out-Null
    New-Fixture 'diamond\right.md' @('# Right', '@shared.md') | Out-Null
    $diamondRoot = New-Fixture 'diamond\root.md' @('# Root', '@left.md', '@right.md')
    $diamond = @(Get-AlwaysOnDocuments -RootDocument $diamondRoot -RepoRoot $Fixture)
    Assert-Equal 4 $diamond.Count 'a diamond counts the shared document once, not twice'

    New-Fixture 'dead\gone.md' @('# placeholder') | Out-Null
    Remove-Item (Join-Path $Fixture 'dead\gone.md') -Force
    $deadRoot = New-Fixture 'dead\root.md' @('# Root', '@gone.md')
    $dead = @(Get-AlwaysOnDocuments -RootDocument $deadRoot -RepoRoot $Fixture)
    Assert-Equal 2 $dead.Count 'a missing import is RETURNED, not skipped'
    $deadRow = @($dead | Where-Object { -not $_.Exists })[0]
    Assert-Equal 0 $deadRow.Bytes 'a missing import costs 0 bytes'
    Assert-Equal 'gone.md' $deadRow.Target 'the missing import names the target as written'

    Write-Host ''
    Write-Host 'The byte column names its line-ending unit (inbound #1162)' -ForegroundColor Cyan

    # New-Fixture always writes LF. A CRLF copy of the same content is written by hand, because the
    # whole point of #1162 is that Bytes is the on-disk form and on a CRLF checkout that is one byte
    # per line above the LF the repository stores.
    function New-CrlfFixture {
        param([string]$RelPath, [string[]]$Lines)
        $full = Join-Path $Fixture $RelPath
        $dir = Split-Path -Parent $full
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        [System.IO.File]::WriteAllText($full, (($Lines -join "`r`n") + "`r`n"), $Utf8NoBom)
        return $full
    }

    $lfDoc = New-Fixture 'eol\lf.md' @('# Title', 'body one', 'body two', 'body three')
    Assert-Equal 0 (Get-CrlfPairCount -Path $lfDoc) 'an LF file has no CRLF pairs'

    $crlfLines = @('# Title', 'body one', 'body two', 'body three')
    $crlfDoc = New-CrlfFixture 'eol\crlf.md' $crlfLines
    Assert-Equal $crlfLines.Count (Get-CrlfPairCount -Path $crlfDoc) 'a CRLF file has one pair per line'

    # A lone CR that is not a line ending must not be counted: 0x0D followed by a letter, not 0x0A.
    $loneCr = Join-Path $Fixture 'eol\lonecr.md'
    [System.IO.File]::WriteAllText($loneCr, "# Title`nbody with a`rbare CR`n", $Utf8NoBom)
    Assert-Equal 0 (Get-CrlfPairCount -Path $loneCr) 'a bare CR is not a CRLF line ending'

    $eolWalk = @(Get-AlwaysOnDocuments -RootDocument $crlfDoc -RepoRoot $Fixture)
    $eolRow = $eolWalk[0]
    Assert-Equal ((Get-Item $crlfDoc).Length) $eolRow.Bytes 'Bytes is still the on-disk length'
    Assert-Equal $crlfLines.Count $eolRow.CrlfLines 'the row carries the CRLF line count'
    Assert-Equal ($eolRow.Bytes - $eolRow.CrlfLines) $eolRow.LfBytes 'LfBytes is Bytes minus one per CRLF line'
    Assert-Equal ((Get-Item $lfDoc).Length) $eolRow.LfBytes 'LfBytes equals the same content stored LF'

    $lfRow = @(Get-AlwaysOnDocuments -RootDocument $lfDoc -RepoRoot $Fixture)[0]
    Assert-Equal 0 $lfRow.CrlfLines 'an LF document reports no CRLF lines'
    Assert-Equal $lfRow.Bytes $lfRow.LfBytes 'an LF document has LfBytes equal to Bytes'

    $crlfOut = ((& powershell -NoProfile -ExecutionPolicy Bypass -File $Script -RepoRoot $Fixture -Root $crlfDoc -Documents 2>&1) | Out-String)
    Assert-True ($crlfOut -match 'working copy on disk') 'the always-present note names the unit of the byte column'
    Assert-True ($crlfOut -match 'CRLF line-ends') 'a CRLF document triggers the CRLF-vs-LF block'
    Assert-True ($crlfOut -match 'stored LF') 'the CRLF block names the LF size beside the on-disk one'

    $lfOut = ((& powershell -NoProfile -ExecutionPolicy Bypass -File $Script -RepoRoot $Fixture -Root $lfDoc -Documents 2>&1) | Out-String)
    Assert-True ($lfOut -match 'working copy on disk') 'the unit note is present on an all-LF path too'
    Assert-True ($lfOut -notmatch 'it is CRLF here') 'an all-LF path does not print the CRLF-vs-LF block'

    Write-Host ''
    Write-Host 'The script runs on this repo and agrees with the lib' -ForegroundColor Cyan

    $docs = @(Get-AlwaysOnDocuments -RootDocument (Join-Path $RepoRoot 'CLAUDE.md') -RepoRoot $RepoRoot)
    Assert-True ($docs.Count -ge 2) 'this repo has an always-on path with imports on it'
    Assert-True (@($docs | Where-Object { $_.Display -eq 'CLAUDE.md' }).Count -eq 1) 'the root document is on the path exactly once'

    $expected = 0
    foreach ($d in $docs) { if ($d.Exists) { $expected += (Get-Item -LiteralPath $d.Path).Length } }
    $reported = ($docs | Where-Object { $_.Exists } | Measure-Object -Property Bytes -Sum).Sum
    Assert-Equal $expected $reported 'the reported bytes are the files on disk, re-read independently'

    foreach ($d in ($docs | Where-Object { $_.Exists })) {
        $s = @(Get-DocumentSections -Path $d.Path -MaxLevel 3)
        Assert-Equal $d.Bytes (($s | Measure-Object -Property Bytes -Sum).Sum) ("sections sum to the file for " + $d.Display)
    }

    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Script -Top 3 2>&1
    $text = ($out | Out-String)
    Assert-Equal 0 $LASTEXITCODE 'the script exits 0 -- it reports, it does not gate'
    Assert-True ($text -match 'MEASUREMENT') 'the output states that bytes are a measurement'
    Assert-True ($text -match 'ESTIMATE') 'the output states that tokens are an estimate'
    Assert-True ($text -match '3\.12') 'the output names the factor with a decimal point'
    Assert-True ($text -notmatch 'reaches a verdict') 'the output does not claim a verdict'

    $outDocs = & powershell -NoProfile -ExecutionPolicy Bypass -File $Script -Documents 2>&1
    Assert-True ((($outDocs | Out-String)) -notmatch 'Where the mass sits') '-Documents suppresses the section breakdown'
} finally {
    Remove-Item -Recurse -Force $Fixture -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host ("  {0} passed, {1} failed" -f $script:pass, $script:fail) -ForegroundColor $(if ($script:fail -gt 0) { 'Red' } else { 'Green' })
if ($script:fail -gt 0) { exit 1 }
exit 0
