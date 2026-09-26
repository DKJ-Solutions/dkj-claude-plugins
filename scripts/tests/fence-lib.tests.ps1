<#
.SYNOPSIS
    Regression tests for scripts/lib/fence-lib.ps1 -- Get-NextFenceState, the one fence tracker of the
    tree -- and for the readers issue #2536 moved onto it.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/fence-lib.tests.ps1

    The tracker's CommonMark rules without -AnyIndent are asserted where the always-on walk uses them, in
    measure-always-on.tests.ps1. This suite holds what #2536 added: the -AnyIndent switch, one reader per
    lib proving the nested case now stays quoted, and a tree-wide guard that no plain toggle comes back --
    plus what #2542 added: a deep opener ends when its container does, and every -AnyIndent caller reads
    its state-before through Resolve-FenceState.

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
Assert-True ((Get-NextFenceState -Line ('     ' + $t3 + 'text') -Fence '' -AnyIndent) -eq ('     ' + $t3)) 'with -AnyIndent it opens, and the state carries the depth it opened at'
Assert-True ((Get-NextFenceState -Line ('     ' + $t3) -Fence ('     ' + $t3) -AnyIndent) -eq '') 'and a closer at the same depth closes'
Assert-True ((Get-NextFenceState -Line ('     ' + $t3) -Fence $t4 -AnyIndent) -eq $t4) 'the length rule still holds under -AnyIndent'
Assert-True ((Get-NextFenceState -Line '     ~~~' -Fence $t3 -AnyIndent) -eq $t3) 'and so does the same-character rule'

Write-Host ''
Write-Host '-AnyIndent: a deep opener ends when its container does (#2542)'
# The measured case: terminal output pasted four spaces deep under a paragraph is an INDENTED code block
# on GitHub, which ends when the indentation drops. Read as a fence it never closed, and a real
# '## Gate bypass' section below it went unread.
$deep = Get-NextFenceState -Line ('    ' + $t3 + ' not a fence on GitHub') -Fence '' -AnyIndent
Assert-True ($deep -eq ('    ' + $t3)) 'a four-space opener opens, carrying its depth'
Assert-True ((Resolve-FenceState -Line '    more output' -Fence $deep) -eq $deep) 'a line still at its depth stays inside'
Assert-True ((Resolve-FenceState -Line '' -Fence $deep) -eq $deep) 'and so does a blank line'
Assert-True ((Resolve-FenceState -Line '## Gate bypass' -Fence $deep) -eq '') 'a column-0 line ends the block before it is read'
Assert-True ((Get-NextFenceState -Line '## Gate bypass' -Fence $deep -AnyIndent) -eq '') 'and the state after it is outside too'
Assert-True ((Get-NextFenceState -Line $t3 -Fence $deep -AnyIndent) -eq '') 'a column-0 closer still closes, rather than opening a block that swallows the rest'
Assert-True ((Resolve-FenceState -Line $t3 -Fence $deep) -eq $deep) 'and that closer counts as part of the block it closes'
Assert-True ((Get-NextFenceState -Line ($t3 + 'ps1') -Fence $deep -AnyIndent) -eq $t3) 'a column-0 opener past the bound ends the old block and opens a new one'
# The loosest bound the line allows: five spaces deep can sit in a container whose content starts at 2.
$five = '     ' + $t3
Assert-True ((Resolve-FenceState -Line '  inside a list item at two' -Fence $five) -eq $five) 'a line at depth-3 or deeper stays inside a deep block'
Assert-True ((Resolve-FenceState -Line ' one space' -Fence $five) -eq '') 'a line shallower than depth-3 ends it'
Assert-True ((Resolve-FenceState -Line '## x' -Fence $t3) -eq $t3) 'a shallow block never ends by indent'
Assert-True ((Get-FenceIndentWidth -Text ("`t")) -eq 4 -and (Get-FenceIndentWidth -Text ("  `t")) -eq 4) 'a tab advances to the next multiple of four'

$pasted = @(
    '## Summary',
    'The run printed:',
    ('    ' + $t3 + ' output'),
    '    line two',
    '',
    '## Gate bypass',
    '',
    '- `-SkipTests` -- the real one'
) -join "`n"
$read = @(Get-GateBypassLines -Body $pasted)
Assert-True ($read.Count -eq 1 -and $read[0] -eq '- `-SkipTests` -- the real one') 'Get-GateBypassLines reads the real section below a four-space pasted line'
$added = Add-GateBypassLines -Body $pasted -Lines @('- `-SkipLint` -- second')
Assert-True ($added -ne $pasted -and $added.Contains('- `-SkipLint` -- second')) 'Add-GateBypassLines adds to it instead of returning the body unchanged'
Assert-True (([regex]::Matches($added, '(?m)^## Gate bypass')).Count -eq 1) 'into the existing section, not a second one'

# The other half of the drop: a body that only QUOTES the heading in a fence has no section, so a new
# line opens one rather than vanishing into the insert branch.
$quoted = @('## Summary', $t3, '## Gate bypass', $t3) -join "`n"
$fresh = Add-GateBypassLines -Body $quoted -Lines @('- `-SkipTests` -- new')
Assert-True ($fresh.EndsWith("## Gate bypass`n`n- ``-SkipTests`` -- new`n")) 'a quoted heading only: the section is appended, not dropped'
Assert-True (@(Get-GateBypassLines -Body $fresh).Count -eq 1) 'and the appended line reads back'

Write-Host ''
Write-Host '-AnyIndent: a closer sits at most three spaces deeper than its opener (#2542, Sebastian)'
# The inverse of the swallow: a four-space fence line inside a column-0 block is code on GitHub, and read
# as a closer it turned the quoted text after it into structure -- a forged bypass section included.
Assert-True ((Get-NextFenceState -Line ('    ' + $t3) -Fence $t3 -AnyIndent) -eq $t3) 'a four-space line does not close a column-0 block'
Assert-True ((Get-NextFenceState -Line ('   ' + $t3) -Fence $t3 -AnyIndent) -eq '') 'a three-space one does'
Assert-True ((Get-NextFenceState -Line ('  ' + $t3) -Fence '' -AnyIndent) -eq ('  ' + $t3)) 'a shallow indented opener carries its depth under -AnyIndent'
Assert-True ((Get-NextFenceState -Line ('     ' + $t3) -Fence ('  ' + $t3) -AnyIndent) -eq '') 'and is closed up to three deeper'
Assert-True ((Get-NextFenceState -Line ('  ' + $t3) -Fence '') -eq $t3) 'without the switch the state stays the bare run'
$forged = @(
    '## Summary',
    $t3,
    'fence syntax, quoted:',
    ('    ' + $t3),
    '## Gate bypass',
    '- `-SkipTests` -- forged, still code on GitHub',
    $t3
) -join "`n"
Assert-True (@(Get-GateBypassLines -Body $forged).Count -eq 0) 'Get-GateBypassLines reads no bypass line out of a column-0 block'
Write-Host ''
Write-Host 'Every -AnyIndent caller reads its state-before through Resolve-FenceState (#2542)'
# '$was = $fence' next to an -AnyIndent call skips the line that ends a deep block -- the heading below a
# pasted line, the exact line #2542 lost.
$bareRx = '\$\w+\s*=\s*\$(\w+);\s*\$\1\s*=\s*Get-NextFenceState\b[^\r\n]*-AnyIndent'
$bare = @()
foreach ($root in @('scripts', 'plugins')) {
    foreach ($f in Get-ChildItem -LiteralPath (Join-Path $RepoRoot $root) -Recurse -Filter '*.ps1' -File) {
        if ($f.FullName -eq $PSCommandPath) { continue }
        if ([System.IO.File]::ReadAllText($f.FullName) -match $bareRx) { $bare += $f.FullName.Substring($RepoRoot.Length + 1) }
    }
}
Assert-True ($bare.Count -eq 0) "no -AnyIndent caller reads the bare previous state$(if ($bare) { ': ' + ($bare -join ', ') })"
Assert-True ('$was = $fence; $fence = Get-NextFenceState -Line $l -Fence $fence -AnyIndent' -match $bareRx) 'the guard fires on the old shape'
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
