<#
.SYNOPSIS
    Regression tests for scripts/lib/fence-lib.ps1 -- Get-NextFenceState, the one fence tracker of the
    tree -- and for the readers issue #2536 moved onto it.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/fence-lib.tests.ps1

    The tracker's CommonMark rules without -AnyIndent are asserted where the always-on walk uses them, in
    measure-always-on.tests.ps1. This suite holds what #2536 added: the -AnyIndent switch, one reader per
    lib proving the nested case now stays quoted, and a tree-wide guard that no plain toggle comes back.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $RepoRoot 'scripts\lib\fence-lib.ps1')
. (Join-Path $RepoRoot 'scripts\lib\entry-scaffold-lib.ps1')
. (Join-Path $RepoRoot 'scripts\lib\pr-body-lib.ps1')

$script:pass = 0
$script:fail = 0
function Assert-True([bool]$Condition, [string]$Message) {
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Message" -ForegroundColor Red }
}

$t3 = ([string][char]0x60) * 3
$t4 = ([string][char]0x60) * 4

Write-Host ''
Write-Host '-AnyIndent: a fence inside a list item'
# The measured case: cut-release's SKILL.md fences a '### DEPLOY:' example at five spaces inside a
# numbered item. Without the switch that opener is not a fence, and the heading inside it reads as real.
Assert-True ((Get-NextFenceState -Line ('     ' + $t3 + 'text') -Fence '') -eq '') 'without -AnyIndent, five spaces of indent does not open'
Assert-True ((Get-NextFenceState -Line ('     ' + $t3 + 'text') -Fence '' -AnyIndent) -eq $t3) 'with -AnyIndent it opens'
Assert-True ((Get-NextFenceState -Line ('     ' + $t3) -Fence $t3 -AnyIndent) -eq '') 'and a closer at the same depth closes'
Assert-True ((Get-NextFenceState -Line ('     ' + $t3) -Fence $t4 -AnyIndent) -eq $t4) 'the length rule still holds under -AnyIndent'
Assert-True ((Get-NextFenceState -Line '     ~~~' -Fence $t3 -AnyIndent) -eq $t3) 'and so does the same-character rule'

# The document every reader below is handed: a four-backtick block quoting a three-backtick example that
# itself carries structure, then the real structure after it.
$nested = @(
    '## Summary',
    ($t4 + 'md'),
    $t3,
    '## Gate bypass',
    '- quoted, not a bypass',
    $t3,
    '## Gate bypass',
    '- still quoted',
    $t4,
    '## Gate bypass',
    '- `-SkipTests` -- the real one'
)

Write-Host ''
Write-Host 'Get-FencedLineFlags (entry-scaffold-lib): the entry format reader'
$flags = @(Get-FencedLineFlags -Lines $nested)
$expected = '01111111100'
Assert-True ((($flags | ForEach-Object { [int]$_ }) -join '') -eq $expected) "the whole four-backtick block is fenced, its inner fences included ($expected)"
$tilde = @(Get-FencedLineFlags -Lines @('~~~~', '~~~', '## Q', '~~~', '~~~~', 'after'))
Assert-True ((($tilde | ForEach-Object { [int]$_ }) -join '') -eq '111110') 'the same holds for a tilde block wrapping a shorter tilde block'

Write-Host ''
Write-Host 'Get-GateBypassLines (pr-body-lib): a PR-body section reader'
$lines = @(Get-GateBypassLines -Body ($nested -join "`n"))
Assert-True ($lines.Count -eq 1 -and $lines[0] -eq '- `-SkipTests` -- the real one') 'only the real section''s bullet is read; the quoted headings are not sections'

Write-Host ''
Write-Host 'One definition in the tree'
# A plain toggle is the shape #2536 removed: a boolean flipped on every delimiter line. Keyed on the
# ASSIGNMENT, not on a mention, so a comment explaining the history does not trip it.
$toggleRx = '(?m)^\s*[^#\r\n]*\$\w*[Ff]ence\w*\s*=\s*-not\s+\$\w*[Ff]ence'
$scanned = 0
$offenders = @()
foreach ($root in @('scripts', 'plugins')) {
    foreach ($f in Get-ChildItem -LiteralPath (Join-Path $RepoRoot $root) -Recurse -Filter '*.ps1' -File) {
        # This suite quotes the toggle below to falsify the guard, so it is the one file not scanned.
        if ($f.FullName -eq $PSCommandPath) { continue }
        $scanned++
        $text = [System.IO.File]::ReadAllText($f.FullName)
        if ($text -match $toggleRx) { $offenders += $f.FullName.Substring($RepoRoot.Length + 1) }
    }
}
Assert-True ($scanned -gt 100) "the guard scanned the tree ($scanned files), not an empty set"
Assert-True ($offenders.Count -eq 0) "no plain fence toggle is left anywhere under scripts/ or plugins/$(if ($offenders) { ': ' + ($offenders -join ', ') })"
# Falsified before trusted: the guard must fire on the shape it exists to catch.
Assert-True ('    $inFence = -not $inFence' -match $toggleRx) 'the guard fires on the old toggle'
Assert-True ('        if ($x) { $tplFence = -not $tplFence; continue }' -match $toggleRx) 'and on an inline one'
$defs = @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'scripts') -Recurse -Filter '*.ps1' -File |
    Where-Object { [System.IO.File]::ReadAllText($_.FullName) -match '(?m)^function (Get-NextFenceState|Test-FenceDelimiterLine)\b' })
Assert-True ($defs.Count -eq 1 -and $defs[0].Name -eq 'fence-lib.ps1') 'Get-NextFenceState is defined once, in fence-lib.ps1, and Test-FenceDelimiterLine is gone'

$bytes = [System.IO.File]::ReadAllBytes((Join-Path $RepoRoot 'scripts\lib\fence-lib.ps1'))
Assert-True (-not ($bytes | Where-Object { $_ -gt 127 })) 'the lib is pure ASCII (repo convention for .ps1)'

Write-Host ''
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
