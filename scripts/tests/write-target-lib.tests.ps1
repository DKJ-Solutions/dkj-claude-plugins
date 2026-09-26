<#
.SYNOPSIS
    Regression tests for scripts/lib/write-target-lib.ps1 -- Get-WriteTargetReparsePoint, the guard
    every adoption runs before writing into a file a consumer already has (issue #2533).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/write-target-lib.tests.ps1

    JUNCTIONS ALWAYS, FILE SYMLINKS WHERE THE MACHINE ALLOWS THEM. A directory junction needs no
    privilege on Windows, so the junctioned-directory cases always run. A file symlink needs Developer
    Mode or an elevated shell; where one cannot be created those cases are reported as skipped rather
    than passed, so a green run never claims coverage it did not have.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $RepoRoot 'scripts\lib\write-target-lib.ps1')
$Fixture = Join-Path ([System.IO.Path]::GetTempPath()) "write-target-lib-$PID-$([guid]::NewGuid().ToString('n'))"

$script:pass = 0
$script:fail = 0
function Assert-True([bool]$Condition, [string]$Message) {
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Message" -ForegroundColor Red }
}
function New-Junction([string]$Link, [string]$Target) {
    & cmd /c mklink /J "$Link" "$Target" | Out-Null
    return (Test-Path -LiteralPath $Link)
}
function New-FileSymlink([string]$Link, [string]$Target) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & cmd /c mklink "$Link" "$Target" 2>&1 | Out-Null } finally { $ErrorActionPreference = $prev }
    return [bool](@(([System.IO.DirectoryInfo](Split-Path -Parent $Link)).GetFileSystemInfos((Split-Path -Leaf $Link))).Count)
}

$junctions = New-Object System.Collections.Generic.List[string]
try {
    $repo = Join-Path $Fixture 'repo'
    $outside = Join-Path $Fixture 'outside'
    New-Item -ItemType Directory -Path $repo, $outside -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $outside 'repo-config.ps1') -Value '# outside'

    Write-Host ''
    Write-Host 'Plain paths'
    Set-Content -LiteralPath (Join-Path $repo 'CLAUDE.md') -Value '# T'
    Assert-True ($null -eq (Get-WriteTargetReparsePoint -Path (Join-Path $repo 'CLAUDE.md') -Root $repo)) 'a plain file under the root is safe'
    Assert-True ($null -eq (Get-WriteTargetReparsePoint -Path (Join-Path $repo 'missing\deeper\x.md') -Root $repo)) 'a path that does not exist yet is safe'
    $away = Join-Path $outside 'repo-config.ps1'
    Assert-True ((Get-WriteTargetReparsePoint -Path $away -Root $repo) -eq [System.IO.Path]::GetFullPath($away)) 'a path outside the root is returned'
    Assert-True ((Get-WriteTargetReparsePoint -Path (Join-Path $repo '..\outside\repo-config.ps1') -Root $repo) -ne $null) 'a path that climbs out with .. is returned'

    Write-Host ''
    Write-Host 'A junctioned directory between the file and the root'
    $scripts = Join-Path $repo 'scripts'
    if (New-Junction -Link $scripts -Target $outside) {
        $junctions.Add($scripts)
        Assert-True ((Get-WriteTargetReparsePoint -Path (Join-Path $scripts 'repo-config.ps1') -Root $repo) -eq $scripts) `
            'a plain file under a junctioned directory is refused, and the junction is named'
        Assert-True ((Get-WriteTargetReparsePoint -Path $scripts -Root $repo) -eq $scripts) 'the junction itself is refused'
    } else {
        Assert-True $false 'a directory junction could be created (needs no privilege)'
    }

    Write-Host ''
    Write-Host 'A root that itself sits under a junction is not judged'
    $viaJunction = Join-Path $Fixture 'via'
    if (New-Junction -Link $viaJunction -Target $repo) {
        $junctions.Add($viaJunction)
        Assert-True ($null -eq (Get-WriteTargetReparsePoint -Path (Join-Path $viaJunction 'CLAUDE.md') -Root $viaJunction)) `
            'the checkout is the consumer''s own arrangement: a file under a junctioned root is safe'
    }

    Write-Host ''
    Write-Host 'A file symlink'
    $link = Join-Path $repo 'LINKED.md'
    $dangling = Join-Path $repo 'DANGLING.md'
    if ((New-FileSymlink -Link $link -Target $away) -and (New-FileSymlink -Link $dangling -Target (Join-Path $outside 'nope.md'))) {
        Assert-True ((Get-WriteTargetReparsePoint -Path $link -Root $repo) -eq $link) 'a symlinked file is refused'
        Assert-True ((Get-WriteTargetReparsePoint -Path $dangling -Root $repo) -eq $dangling) 'a symlink to a missing file is refused too'
    } else {
        Write-Host '  [SKIP] file symlinks cannot be created on this machine (no Developer Mode or elevation)' -ForegroundColor Yellow
    }

    $bytes = [System.IO.File]::ReadAllBytes((Join-Path $RepoRoot 'scripts\lib\write-target-lib.ps1'))
    Assert-True (-not ($bytes | Where-Object { $_ -gt 127 })) 'the lib is pure ASCII (repo convention for .ps1)'
}
finally {
    # A junction is removed with rmdir, never recursively: a recursive delete walks INTO it and empties
    # the target.
    foreach ($j in $junctions) { if (Test-Path -LiteralPath $j) { & cmd /c rmdir "$j" | Out-Null } }
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -LiteralPath $Fixture -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
