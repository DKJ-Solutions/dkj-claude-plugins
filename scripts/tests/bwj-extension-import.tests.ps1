<#
.SYNOPSIS
    Regression tests for bwj-development's adopt-extension-import.ps1 and the shared writer behind it,
    Add-ClaudeMdImportLine in scripts/lib/claude-md-import-lib.ps1 (issue #2532).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/bwj-extension-import.tests.ps1

    The script runs in a child process against fixture directories through -RootOverride, so no fixture
    needs to be a git checkout. The constitution half of the same writer is covered through
    adopt-workflow-folder.ps1 by adopt-workflow-folder.tests.ps1; this suite covers the extension half,
    the -AfterPattern placement only it uses, and the order the two adoptions leave behind when they run
    the other way round.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$ScriptPath = Join-Path $RepoRoot 'plugins\dkj-policy\bwj-development\scripts\task\adopt-extension-import.ps1'
$Fixture    = Join-Path ([System.IO.Path]::GetTempPath()) "bwj-extension-import-$PID-$([guid]::NewGuid().ToString('n'))"

. (Join-Path $RepoRoot 'scripts\lib\claude-md-import-lib.ps1')

$script:pass = 0
$script:fail = 0
function Assert-True([bool]$Condition, [string]$Message) {
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Message" -ForegroundColor Red }
}
function Assert-Equal($Expected, $Actual, [string]$Message) {
    $ok = "$Expected" -ceq "$Actual"
    if (-not $ok) { $Message = "$Message (expected '$Expected', got '$Actual')" }
    Assert-True $ok $Message
}

$Const = '@~/.claude/plugins/marketplaces/dkj-claude-plugins/plugins/dkj-policy/CLAUDE.md'
$Ext   = '@~/.claude/plugins/marketplaces/dkj-claude-plugins/plugins/dkj-policy/bwj-development/CLAUDE.md'

function New-Consumer([string]$Label) {
    $d = Join-Path $Fixture $Label
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    return $d
}
function Invoke-Script([string]$Dir, [string[]]$ScriptArgs = @()) {
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath -RootOverride $Dir @ScriptArgs 2>&1
    return [pscustomobject]@{ Code = $LASTEXITCODE; Flat = (@($out) -join "`n") }
}
function Get-Lines([string]$Path) { @(([System.IO.File]::ReadAllText($Path)).TrimEnd() -split "`r?`n") }

try {
    New-Item -ItemType Directory -Path $Fixture -Force | Out-Null

    Write-Host ''
    Write-Host 'The line'
    Assert-Equal $Ext (Get-ExtensionImportLine -Extension 'bwj-development' -LibDir (Join-Path $RepoRoot 'scripts\lib')) 'the source tree builds the canonical line'
    Assert-Equal '@~/.claude/plugins/marketplaces/claude-code-specialists/plugins/dkj-policy/bwj-development/CLAUDE.md' `
        (Get-ExtensionImportLine -Extension 'bwj-development' -LibDir 'C:\Users\x\.claude\plugins\cache\claude-code-specialists\bwj-development\5.8.0\scripts\lib') `
        'a bwj payload under an older marketplace name keeps that name'
    Assert-Equal '@~/.claude/plugins/marketplaces/claude-code-specialists/plugins/dkj-policy/dkj-solutions/CLAUDE.md' `
        (Get-ExtensionImportLine -Extension 'dkj-solutions' -LibDir 'C:\Users\x\.claude\plugins\cache\claude-code-specialists\dkj-policy\5.8.0\scripts\lib') `
        'any extension builds its line, under the marketplace name read off the payload (#2697)'
    Assert-Equal '@~/.claude/plugins/marketplaces/old-mkt/plugins/dkj-policy/CLAUDE.md' `
        (Get-ConstitutionImportLine -LibDir 'C:\Users\x\.claude\plugins\cache\old-mkt\dkj-solutions\1.0.0\scripts\lib') `
        'the marketplace segment is read off any extension payload, not bwj alone (#2697)'
    Assert-Equal '@~/.claude/plugins/marketplaces/old-mkt/plugins/dkj-policy/CLAUDE.md' `
        (Get-ConstitutionImportLine -LibDir 'C:\Users\x\.claude\plugins\cache\old-mkt\dkj-policy-bwj\5.14.0\scripts\lib') `
        'and off a payload still under a retired extension name (#2788)'
    Assert-Equal '@~/.claude/plugins/marketplaces/dkj-claude-plugins/plugins/dkj-policy/CLAUDE.md' `
        (Get-ConstitutionImportLine -LibDir 'C:\Users\x\.claude\plugins\cache\old-mkt\dkj-subagents-alpha\5.14.0\scripts\lib') `
        'but not off a payload that is no dkj-policy plugin at all'

    Write-Host ''
    Write-Host 'Which plugins are extensions (#2697, #2788)'
    Assert-Equal 'bwj-development|dkj-solutions' ((Get-PolicyExtensionNames -PluginIds @(
        'dkj-solutions@dkj-claude-plugins', 'dkj-policy@dkj-claude-plugins', 'dkj-subagents-alpha@dkj-claude-plugins',
        'bwj-development@claude-code-specialists', 'dkj-solutions@other', 'dkj-policy-Evil/../x@m')) -join '|') `
        'only listed extension ids, de-duplicated and sorted; the constitution, a team and a non-slug are not'
    Assert-Equal '' ((Get-PolicyExtensionNames -PluginIds @()) -join '|') 'no ids, no extensions'
    Assert-Equal 'bwj-development|dkj-solutions' ((Get-PolicyExtensionNames -PluginIds @(
        'dkj-policy-bwj@dkj-claude-plugins', 'dkj-policy-dkjs@dkj-claude-plugins')) -join '|') `
        'a retired id counts as the extension it became, so an unmigrated consumer is still owed the current line (#2788)'
    Assert-True (-not (Test-PolicyExtensionName 'dkj-policy-bwj')) 'a retired name is not itself an extension name'
    Assert-True (-not (Test-PolicyExtensionName 'dkj-policy-other')) 'and the old prefix alone makes nothing an extension any more'
    Assert-True ('@~/.claude/plugins/marketplaces/m/plugins/dkj-policy/dkj-policy-dkjs/CLAUDE.md' -match (Get-RetiredExtensionImportPattern -Extension 'dkj-solutions')) `
        'the retired-line pattern of dkj-solutions matches the dkj-policy-dkjs line'
    Assert-True (-not ('@~/.claude/plugins/marketplaces/m/plugins/dkj-policy/dkj-solutions/CLAUDE.md' -match (Get-RetiredExtensionImportPattern -Extension 'dkj-solutions'))) `
        'and not the current line'
    $retiredRows = @(Get-RetiredExtensionImports -Documents @(
        [pscustomobject]@{ Path = 'C:\h\.claude\plugins\marketplaces\m\plugins\dkj-policy\dkj-policy-bwj\CLAUDE.md' },
        [pscustomobject]@{ Path = 'C:\h\.claude\plugins\marketplaces\m\plugins\dkj-policy\bwj-development\CLAUDE.md' }))
    Assert-Equal 'dkj-policy-bwj>bwj-development' (($retiredRows | ForEach-Object { "$($_.Retired)>$($_.Current)" }) -join '|') `
        'Get-RetiredExtensionImports finds the retired row only, with the name it became'

    # The list is the whole set: every plugin under plugins/dkj-policy/ other than dkj-policy itself is an
    # extension, and nothing else is (#2788). A new extension that is not listed fails here instead of
    # silently never being imported.
    $pluginDirs = @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'plugins\dkj-policy') -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName '.claude-plugin\plugin.json') -PathType Leaf } |
        ForEach-Object { $_.Name } | Sort-Object)
    Assert-Equal ((@(Get-PolicyExtensionList) | Sort-Object) -join '|') ($pluginDirs -join '|') `
        'Get-PolicyExtensionList names exactly the plugin folders under plugins/dkj-policy/'
    $threw = $false
    try { Get-ExtensionImportLine -Extension 'dkj-policy-../x' | Out-Null } catch { $threw = $true }
    Assert-True $threw 'a name that is not a slug is refused rather than built into a line'
    Assert-True (Test-ExtensionImported -Extension 'dkj-solutions' -Documents @([pscustomobject]@{ Path = 'C:\h\.claude\plugins\marketplaces\m\plugins\dkj-policy\dkj-solutions\CLAUDE.md' })) `
        'Test-ExtensionImported matches its own extension'
    Assert-True (-not (Test-ExtensionImported -Extension 'dkj-solutions' -Documents @([pscustomobject]@{ Path = 'C:\h\plugins\dkj-policy\bwj-development\CLAUDE.md' }))) `
        'and not another extension'

    # Every extension in the source tree ships the CLAUDE.md its import line points at.
    foreach ($name in @(Get-PolicyExtensionList)) {
        Assert-True (Test-Path -LiteralPath (Join-Path $RepoRoot "plugins\dkj-policy\$name\CLAUDE.md") -PathType Leaf) "extension $name ships a CLAUDE.md"
    }
    Assert-Equal '@~/.claude/plugins/marketplaces/claude-code-specialists/plugins/dkj-policy/CLAUDE.md' `
        (Get-ConstitutionImportLine -LibDir 'C:\Users\x\.claude\plugins\cache\claude-code-specialists\bwj-development\5.8.0\scripts\lib') `
        'the constitution line built from the bwj mirror reads the same segment'

    Write-Host ''
    Write-Host 'No CLAUDE.md'
    $c1 = New-Consumer 'none'
    $r1 = Invoke-Script -Dir $c1 -ScriptArgs @('-Apply')
    Assert-Equal 0 $r1.Code 'exit 0'
    $c1Md = Join-Path $c1 'CLAUDE.md'
    Assert-True (Test-Path -LiteralPath $c1Md -PathType Leaf) 'CLAUDE.md is created'
    if (Test-Path -LiteralPath $c1Md) { Assert-Equal $Ext ((Get-Lines $c1Md) -join '|') 'holding only the extension import' }

    Write-Host ''
    Write-Host 'Below the constitution, CRLF and BOM kept'
    $c2 = New-Consumer 'crlf'
    $c2Md = Join-Path $c2 'CLAUDE.md'
    [System.IO.File]::WriteAllText($c2Md, "# Title`r`n`r`n$Const`r`n@~/.claude/other.md`r`n", (New-Object System.Text.UTF8Encoding($true)))
    $r2 = Invoke-Script -Dir $c2 -ScriptArgs @('-Apply')
    Assert-True ($r2.Flat -match '\[added\]') 'reports the line as added'
    $c2Bytes = [System.IO.File]::ReadAllBytes($c2Md)
    Assert-True ($c2Bytes[0] -eq 0xEF -and $c2Bytes[1] -eq 0xBB -and $c2Bytes[2] -eq 0xBF) 'the byte-order mark is kept'
    $c2Text = [System.IO.File]::ReadAllText($c2Md)
    Assert-True (($c2Text -replace "`r`n", '') -notmatch "`n") 'no lone LF lands in a CRLF file'
    $c2Lines = Get-Lines $c2Md
    Assert-Equal $Const $c2Lines[2] 'the constitution stays where it was'
    Assert-Equal $Ext $c2Lines[3] 'the extension lands directly below it'
    Assert-Equal '@~/.claude/other.md' $c2Lines[4] 'and the next import follows unchanged'
    $r2b = Invoke-Script -Dir $c2 -ScriptArgs @('-Apply')
    Assert-Equal $c2Text ([System.IO.File]::ReadAllText($c2Md)) 'a re-run changes nothing'
    Assert-True ($r2b.Flat -match '\[keep\]\s+CLAUDE\.md already imports') 'and says it kept it'

    Write-Host ''
    Write-Host 'The constitution is the last line, with no terminator'
    $c3 = New-Consumer 'noeol'
    $c3Md = Join-Path $c3 'CLAUDE.md'
    [System.IO.File]::WriteAllText($c3Md, "# T`n$Const", (New-Object System.Text.UTF8Encoding($false)))
    Invoke-Script -Dir $c3 -ScriptArgs @('-Apply') | Out-Null
    Assert-Equal "# T`n$Const`n$Ext" ([System.IO.File]::ReadAllText($c3Md)) 'the constitution gets a terminator and the extension the next line'

    Write-Host ''
    Write-Host 'No constitution yet'
    $c4 = New-Consumer 'noconst'
    $c4Md = Join-Path $c4 'CLAUDE.md'
    [System.IO.File]::WriteAllText($c4Md, "# T`n`n@~/.claude/other.md`n", (New-Object System.Text.UTF8Encoding($false)))
    Invoke-Script -Dir $c4 -ScriptArgs @('-Apply') | Out-Null
    $c4Lines = Get-Lines $c4Md
    Assert-Equal $Ext $c4Lines[2] 'the extension lands above the first import, where the constitution would'
    # The other order of the two adoptions: adopt-dkj-policy running afterwards must still put the
    # constitution first. Same call adopt-workflow-folder.ps1 makes.
    Add-ClaudeMdImportLine -Path $c4Md -Root $c4 -Line $Const -ImportedPattern '^\s*@\S*/plugins/dkj-policy/CLAUDE\.md\s*$' -Apply | Out-Null
    $c4Lines = Get-Lines $c4Md
    Assert-Equal "$Const|$Ext" (($c4Lines[2], $c4Lines[3]) -join '|') 'a later constitution write lands directly above the extension'

    Write-Host ''
    Write-Host 'Imported under the retired name dkj-policy-bwj (#2788)'
    $c9 = New-Consumer 'retired-name'
    $c9Md = Join-Path $c9 'CLAUDE.md'
    $c9Old = '@~/.claude/plugins/marketplaces/dkj-claude-plugins/plugins/dkj-policy/dkj-policy-bwj/CLAUDE.md'
    [System.IO.File]::WriteAllText($c9Md, "# T`r`n$Const`r`n$c9Old`r`n@~/.claude/other.md`r`n", (New-Object System.Text.UTF8Encoding($false)))
    $r9 = Invoke-Script -Dir $c9 -ScriptArgs @('-Apply')
    Assert-True ($r9.Flat -match '\[renamed\]') 'reports the retired line as renamed'
    Assert-Equal "# T`r`n$Const`r`n$Ext`r`n@~/.claude/other.md`r`n" ([System.IO.File]::ReadAllText($c9Md)) `
        'the retired line is rewritten in place, its CRLF kept, and no second line is added'
    $r9b = Invoke-Script -Dir $c9 -ScriptArgs @('-Apply')
    Assert-True ($r9b.Flat -match '\[keep\]') 'a re-run keeps it'

    Write-Host ''
    Write-Host 'Already imported, and quoted in a fence'
    $c5 = New-Consumer 'old-name'
    $c5Md = Join-Path $c5 'CLAUDE.md'
    $c5Text = "$Const`n@~/.claude/plugins/marketplaces/claude-code-specialists/plugins/dkj-policy/bwj-development/CLAUDE.md`n"
    [System.IO.File]::WriteAllText($c5Md, $c5Text, (New-Object System.Text.UTF8Encoding($false)))
    $r5 = Invoke-Script -Dir $c5 -ScriptArgs @('-Apply')
    Assert-Equal $c5Text ([System.IO.File]::ReadAllText($c5Md)) 'imported under an older marketplace name: untouched'
    Assert-True ($r5.Flat -match '\[keep\]') 'and says it kept it'

    $c6 = New-Consumer 'fenced'
    $c6Md = Join-Path $c6 'CLAUDE.md'
    $f4 = [string]::new([char]0x60, 4)
    $f3 = [string]::new([char]0x60, 3)
    $c6Body = @('# T', ($f4 + 'md'), $f3, $Const, $Ext, $f3, $f4, $Const) -join "`n"
    [System.IO.File]::WriteAllText($c6Md, $c6Body + "`n", (New-Object System.Text.UTF8Encoding($false)))
    Invoke-Script -Dir $c6 -ScriptArgs @('-Apply') | Out-Null
    $c6Lines = Get-Lines $c6Md
    Assert-Equal 9 $c6Lines.Count 'a line quoted in a nested fence is not an import: one line is added'
    Assert-Equal $Const $c6Lines[7] 'the real constitution import is found past the fence'
    Assert-Equal $Ext $c6Lines[8] 'and the extension lands below it, not in the example'

    # Claude Code reads only a column-0 '@' as an import, so an indented look-alike in a bullet is prose:
    # neither "already imported" nor the constitution anchor.
    $c8 = New-Consumer 'indented'
    $c8Md = Join-Path $c8 'CLAUDE.md'
    [System.IO.File]::WriteAllText($c8Md, "- see:`n  $Ext`n  $Const`n$Const`n", (New-Object System.Text.UTF8Encoding($false)))
    $r8 = Invoke-Script -Dir $c8 -ScriptArgs @('-Apply')
    Assert-True ($r8.Flat -match '\[added\]') 'an indented look-alike is not an import: the line is added'
    $c8Lines = Get-Lines $c8Md
    Assert-Equal "$Const|$Ext" (($c8Lines[3], $c8Lines[4]) -join '|') 'and lands below the column-0 constitution, not the indented one'

    Write-Host ''
    Write-Host 'Dry run'
    $c7 = New-Consumer 'dry'
    $r7 = Invoke-Script -Dir $c7
    Assert-True ($r7.Flat -match '\[create\]') 'lists CLAUDE.md as to-create'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $c7 'CLAUDE.md'))) 'and does not write it'

    Write-Host ''
    $bytes = [System.IO.File]::ReadAllBytes($ScriptPath)
    Assert-True (-not ($bytes | Where-Object { $_ -gt 127 })) 'the script is pure ASCII (repo convention for .ps1)'
}
finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -LiteralPath $Fixture -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
