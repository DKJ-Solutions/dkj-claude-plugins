<#
.SYNOPSIS
    Tests for scripts/release/upload-release-asset.ps1 (the by-id re-upload of a release attachment).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Exit code 0 if everything passes, 1 on a
    failure -- so usable as a CI gate.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/upload-release-asset.tests.ps1

    Why this suite exists (issue #2347): the script DELETES a published asset before it uploads, so the
    failure that matters -- a Release left without the attachment, or with a stale one reported as
    fresh -- is only visible on a live Release. It is driven end to end against a FAKE gh on PATH that
    keeps the Release's asset list in a state file and records every call.

    The fake refuses an upload whose name already exists with the 422 #2347 measured, so a script that
    skipped the by-id delete, or went back to --clobber, fails here rather than at the next cut.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$RepoRoot = Resolve-RepoRootOrFail -From $PSScriptRoot -ScriptName 'upload-release-asset.tests.ps1'
$ScriptPath = Join-Path $RepoRoot 'scripts\release\upload-release-asset.ps1'
. (Join-Path $RepoRoot 'scripts\lib\native-capture-lib.ps1')

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
        $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red
    }
}

function Test-Says {
    <# Whitespace-stripped, literal, case-insensitive containment -- survives a console wrap anywhere
       in the phrase, including inside a word (the #1512 lesson verify-resolved-issues.tests.ps1 records). #>
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

$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
$work = Join-Path ([System.IO.Path]::GetTempPath()) ("upload-release-asset-$PID-$([guid]::NewGuid().ToString('n'))")
$fakeBin = Join-Path $work 'bin'
$callLog = Join-Path $work 'calls.log'
$stateFile = Join-Path $work 'assets.json'
$prevPath = $env:PATH

try {
    $ErrorActionPreference = 'Continue'  # native calls below -- the #107 stderr pitfall guard
    New-Item -ItemType Directory -Path $fakeBin -Force | Out-Null

    # --- Fake gh -----------------------------------------------------------------------------------
    # State: GH_ASSETS_FILE holds a JSON array of {id,name,size}. Answers:
    #   api repos/<r>/releases/tags/<t>           -> {"assets":[...]}   (GH_FAIL_VIEW: exit 1)
    #   api -X DELETE repos/<r>/releases/assets/N -> removes id N        (GH_FAIL_DELETE: exit 1)
    #   release upload <t> <file>                 -> 422 when the name exists; otherwise adds it with
    #                                                the file's length, or GH_UPLOAD_SIZE when set;
    #                                                GH_UPLOAD_NOOP: exit 0 and add nothing
    $ghImpl = @'
if ($env:GH_CALL_LOG) { Add-Content -Path $env:GH_CALL_LOG -Value ($args -join ' ') }
$assets = @()
# Assign first, then wrap: @(... | ConvertFrom-Json) on 5.1 yields ONE element holding the whole array.
if (Test-Path $env:GH_ASSETS_FILE) { $parsed = Get-Content -Raw $env:GH_ASSETS_FILE | ConvertFrom-Json; $assets = @($parsed) }
function Save($list) { Set-Content -Path $env:GH_ASSETS_FILE -Value (ConvertTo-Json -InputObject @($list) -Depth 3) }
if ($args[0] -eq 'api' -and $args -contains 'DELETE') {
    if ($env:GH_FAIL_DELETE) { [Console]::Error.WriteLine('fake gh: delete failed'); exit 1 }
    $id = ($args[-1] -split '/')[-1]
    Save @($assets | Where-Object { "$($_.id)" -ne $id })
    exit 0
}
if ($args[0] -eq 'api') {
    if ($env:GH_FAIL_VIEW) { [Console]::Error.WriteLine('fake gh: release not found'); exit 1 }
    Write-Output (ConvertTo-Json -InputObject @{ assets = @($assets) } -Depth 3)
    exit 0
}
if ($args[0] -eq 'release' -and $args[1] -eq 'upload') {
    $file = Get-Item -LiteralPath $args[3]
    if (@($assets | Where-Object { $_.name -eq $file.Name }).Count -gt 0) {
        [Console]::Error.WriteLine('HTTP 422: Validation Failed (ReleaseAsset.name already exists)'); exit 1
    }
    if ($env:GH_UPLOAD_NOOP) { exit 0 }
    $size = if ($env:GH_UPLOAD_SIZE) { [long]$env:GH_UPLOAD_SIZE } else { $file.Length }
    Save (@($assets) + @([pscustomobject]@{ id = 99; name = $file.Name; size = $size }))
    exit 0
}
exit 1
'@
    [System.IO.File]::WriteAllText((Join-Path $fakeBin 'gh-impl.ps1'), $ghImpl, $Utf8NoBom)
    $ghCmd = "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0gh-impl.ps1`" %*`r`nexit /b %ERRORLEVEL%`r`n"
    [System.IO.File]::WriteAllText((Join-Path $fakeBin 'gh.cmd'), $ghCmd, $Utf8NoBom)
    $env:PATH = "$fakeBin;$env:PATH"
    $env:GH_CALL_LOG = $callLog
    $env:GH_ASSETS_FILE = $stateFile

    $doc = Join-Path $work 'v9.9.9-notes-for-users.md'
    [System.IO.File]::WriteAllText($doc, ('x' * 1234), $Utf8NoBom)

    function Invoke-Upload {
        <# Runs the script against a fresh asset state; returns output, exit code, call log, final state. #>
        param([object[]]$Assets = @(), [string]$Path = $doc, [hashtable]$Env = @{})
        Remove-Item -Path $callLog -Force -ErrorAction SilentlyContinue
        [System.IO.File]::WriteAllText($stateFile, (ConvertTo-Json -InputObject @($Assets) -Depth 3), $Utf8NoBom)
        foreach ($k in 'GH_FAIL_VIEW', 'GH_FAIL_DELETE', 'GH_UPLOAD_NOOP', 'GH_UPLOAD_SIZE') {
            if ($Env.ContainsKey($k)) { Set-Item "Env:\$k" $Env[$k] } else { Remove-Item "Env:\$k" -ErrorAction SilentlyContinue }
        }
        $run = Invoke-NativeCapture -FilePath 'powershell' -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', $ScriptPath, '-Tag', 'v9.9.9', '-Path', $Path, '-Repo', 'fake/repo') -Utf8
        $log = if (Test-Path $callLog) { @(Get-Content -Path $callLog) } else { @() }
        $parsed = Get-Content -Raw $stateFile | ConvertFrom-Json  # assign first -- see the fake gh
        $state = @($parsed)
        return [pscustomobject]@{ Output = ($run.Output -join ' '); ExitCode = $run.ExitCode; Log = $log; State = $state }
    }

    $staleAsset = [pscustomobject]@{ id = 11; name = 'v9.9.9-notes-for-users.md'; size = 1000 }
    $otherAsset = [pscustomobject]@{ id = 12; name = 'v9.9.9-development-notes.md'; size = 5000 }

    Write-Host "A stale asset of the same name is deleted BY ID, then uploaded fresh (#2347)" -ForegroundColor Cyan
    $r = Invoke-Upload -Assets @($staleAsset, $otherAsset)
    Assert-Equal 0 $r.ExitCode 'exit 0 when the published size matches the file'
    Assert-True (@($r.Log | Where-Object { $_ -match 'DELETE repos/fake/repo/releases/assets/11$' }).Count -eq 1) 'deletes the stale asset through the API by its id'
    Assert-True (@($r.Log | Where-Object { $_ -match '--clobber|delete-asset' }).Count -eq 0) 'never uses --clobber or delete-asset -- the by-name lookups #2347 measured failing'
    Assert-True (@($r.State | Where-Object { $_.name -eq 'v9.9.9-notes-for-users.md' -and $_.size -eq 1234 }).Count -eq 1) 'exactly one asset of that name remains, at the file size'
    Assert-True (@($r.State | Where-Object { $_.id -eq 12 }).Count -eq 1) 'an asset with another name is left alone'
    Assert-Says $r.Output 'published on v9.9.9 at 1234 B' 'says the verified byte count'

    Write-Host "No existing asset: nothing is deleted" -ForegroundColor Cyan
    $r = Invoke-Upload -Assets @($otherAsset)
    Assert-Equal 0 $r.ExitCode 'exit 0 on a first upload'
    Assert-True (@($r.Log | Where-Object { $_ -match 'DELETE' }).Count -eq 0) 'no delete when the name is not on the Release'

    Write-Host "A Release with NO attachments yet (step 5's first upload) is readable, not a failed read" -ForegroundColor Cyan
    $r = Invoke-Upload -Assets @()
    Assert-Equal 0 $r.ExitCode 'exit 0 -- an empty asset list must not unroll to $null and read as unreadable'
    Assert-True (@($r.Log | Where-Object { $_ -match 'release upload' }).Count -eq 1) 'the upload runs'

    Write-Host "The upload lands at the wrong size: refused" -ForegroundColor Cyan
    $r = Invoke-Upload -Assets @($staleAsset) -Env @{ GH_UPLOAD_SIZE = '1000' }
    Assert-Equal 1 $r.ExitCode 'exit 1 when the published byte count differs from the file'
    Assert-Says $r.Output 'the attachment is not the document' 'names the mismatch'

    Write-Host "The upload exits 0 but nothing lands: refused, and says the stale copy is gone" -ForegroundColor Cyan
    $r = Invoke-Upload -Assets @($staleAsset) -Env @{ GH_UPLOAD_NOOP = '1' }
    Assert-Equal 1 $r.ExitCode 'exit 1 when the asset is missing after a clean upload exit'
    Assert-Says $r.Output 'WAS deleted' 'tells the reader the Release now lacks the attachment'

    Write-Host "The Release cannot be read: nothing is deleted or uploaded" -ForegroundColor Cyan
    $r = Invoke-Upload -Assets @($staleAsset) -Env @{ GH_FAIL_VIEW = '1' }
    Assert-Equal 1 $r.ExitCode 'exit 1 when the Release read fails'
    Assert-True (@($r.Log | Where-Object { $_ -match 'DELETE|release upload' }).Count -eq 0) 'no delete and no upload after a failed read'

    Write-Host "The delete fails: nothing is uploaded, the old asset stands" -ForegroundColor Cyan
    $r = Invoke-Upload -Assets @($staleAsset) -Env @{ GH_FAIL_DELETE = '1' }
    Assert-Equal 1 $r.ExitCode 'exit 1 when the by-id delete fails'
    Assert-True (@($r.Log | Where-Object { $_ -match 'release upload' }).Count -eq 0) 'no upload after a failed delete'
    Assert-True (@($r.State | Where-Object { $_.id -eq 11 }).Count -eq 1) 'the stale asset is still there'

    Write-Host "No file at -Path: no gh call at all" -ForegroundColor Cyan
    $r = Invoke-Upload -Assets @($staleAsset) -Path (Join-Path $work 'missing.md')
    Assert-Equal 1 $r.ExitCode 'exit 1 for a missing file'
    Assert-Equal 0 $r.Log.Count 'gh is never called'
}
finally {
    $env:PATH = $prevPath
    foreach ($k in 'GH_CALL_LOG', 'GH_ASSETS_FILE', 'GH_FAIL_VIEW', 'GH_FAIL_DELETE', 'GH_UPLOAD_NOOP', 'GH_UPLOAD_SIZE') {
        Remove-Item "Env:\$k" -ErrorAction SilentlyContinue
    }
    Remove-Item -Path $work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Passed: $script:pass  Failed: $script:fail"
if ($script:fail -gt 0) { exit 1 }
exit 0
