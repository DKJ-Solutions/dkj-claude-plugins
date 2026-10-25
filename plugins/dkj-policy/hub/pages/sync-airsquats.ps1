<#
.SYNOPSIS
    One sync of this machine's airsquats state with the private GitHub gist every machine shares (#3438).

.DESCRIPTION
    Started by a hub server (Start-AirsquatsSync, hub/lib/airsquats-lib.ps1) in a hidden child, so the server's
    single-threaded loop never waits on the network. The rules -- which gist, how the two states merge, when the
    gist is written -- are Sync-AirsquatsGist's; this file is the process around it: a lock of its own, so two
    servers' children never sync at once, and gh bounded at 20 s a call.

    THE GIST. Found by DKJ_HUB_AIRSQUATS_GIST where set, else by the id this machine remembers, else by its
    description ('dkj-hub-airsquats') among the gists of the account gh is logged in as, and created private on
    first use. So two machines on the same gh account find each other with nothing configured; machines on
    different accounts each pin the same id with DKJ_HUB_AIRSQUATS_GIST.

    Exits 0 always: a failed sync is written into the state file (syncError) for the banner, never raised.

    Pure ASCII (repo convention for .ps1). The rules are tested by scripts/tests/hub-airsquats.tests.ps1.
#>
[CmdletBinding()]
param([ValidateRange(1000, 120000)][int]$GhTimeoutMs = 20000)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\airsquats-lib.ps1')

function Invoke-BoundedGh {
    <# gh with -Arguments, bounded at -TimeoutMs: @{ ExitCode; Out }. A run past the bound is killed and reads as exit 124. #>
    param([string[]]$Arguments, [int]$TimeoutMs)
    $gh = Get-Command gh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $gh) { return @{ ExitCode = 127; Out = '' } }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $gh.Source
    $psi.Arguments = (($Arguments | ForEach-Object { if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }) -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = New-Object System.Text.UTF8Encoding($false)
    $p = [System.Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEndAsync()
    $null = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit($TimeoutMs)) { try { $p.Kill() } catch { }; return @{ ExitCode = 124; Out = '' } }
    $p.WaitForExit()
    return @{ ExitCode = $p.ExitCode; Out = $out.Result }
}

$dir = Get-AirsquatsDir
if (-not (Test-Path -LiteralPath $dir)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
$lock = $null
try { $lock = [System.IO.File]::Open((Join-Path $dir 'sync.lock'), 'OpenOrCreate', 'ReadWrite', 'None') } catch { exit 0 }
try {
    $timeout = $GhTimeoutMs
    [void](Sync-AirsquatsGist -Gh { param([string[]]$a) Invoke-BoundedGh -Arguments $a -TimeoutMs $timeout })
} catch {
} finally {
    $lock.Dispose()
}
exit 0
