<#
.SYNOPSIS
    Stop a server the dev-preview hook started once the logon session that started it stays disconnected
    (INBOUND #3569). Started by hooks/dev-preview-sessionstart.ps1 beside every server it starts; never run
    by hand.

.DESCRIPTION
    A disconnected Windows session keeps its processes, so a product started there held its port for every
    later session on the machine -- measured cross-account, where the later session cannot stop it without
    elevation. This watcher runs in the same session as the server it watches. Every -PollSeconds it reads
    its own session's connect state (WTSQuerySessionInformation, WTSConnectState); once that has read
    WTSDisconnected for -GraceSeconds without a break, it stops the server's whole tree (taskkill /T /F) and
    exits. It exits as soon as the server does, so a server stopped by hand leaves nothing behind. The rules
    are Get-DevPreviewWatchStep in hub/lib/dev-preview-rules.ps1.

      -ProcessId     the cmd.exe the hook launched (the root of the server's tree)
      -StartTicks    that process's start time as FILETIME UTC: a pid reused by another process is not
                     the server, and is never stopped
      -GraceSeconds  how long the session must stay disconnected (default 60)
      -PollSeconds   how often it looks (default 15)
      -ForceState    the TEST override: the connect state to read instead of the session's own

    Exits 0 in every case: nobody reads its exit code. Pure ASCII (repo convention for .ps1).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][int]$ProcessId,
    [long]$StartTicks = 0,
    [int]$GraceSeconds = -1,
    [int]$PollSeconds = -1,
    [int]$ForceState = -2
)
$ErrorActionPreference = 'Stop'
try {
    . (Join-Path $PSScriptRoot '..\lib\dev-preview-rules.ps1')
    if ($GraceSeconds -lt 0) { $GraceSeconds = $script:DevPreviewWatchGraceSeconds }
    if ($PollSeconds -lt 1) { $PollSeconds = $script:DevPreviewWatchPollSeconds }

    # Held as a handle, so HasExited answers for THIS process even after its pid is reused.
    $target = [Diagnostics.Process]::GetProcessById($ProcessId)
    if ($StartTicks -and $target.StartTime.ToFileTimeUtc() -ne $StartTicks) { exit 0 }

    if ($ForceState -eq -2) {
        Add-Type -Namespace DkjDevPreview -Name Wts -MemberDefinition @'
[DllImport("wtsapi32.dll", SetLastError = true)]
static extern bool WTSQuerySessionInformation(IntPtr server, int sessionId, int infoClass, out IntPtr buffer, out int bytes);
[DllImport("wtsapi32.dll")]
static extern void WTSFreeMemory(IntPtr memory);
public static int ConnectState() {
    IntPtr buffer; int bytes;
    // WTS_CURRENT_SERVER_HANDLE, WTS_CURRENT_SESSION, WTSConnectState
    if (!WTSQuerySessionInformation(IntPtr.Zero, -1, 8, out buffer, out bytes)) { return -1; }
    try { return bytes >= 4 ? System.Runtime.InteropServices.Marshal.ReadInt32(buffer) : -1; }
    finally { WTSFreeMemory(buffer); }
}
'@
    }

    $since = $null
    while (-not $target.HasExited) {
        $state = if ($ForceState -ne -2) { $ForceState } else { try { [DkjDevPreview.Wts]::ConnectState() } catch { -1 } }
        $step = Get-DevPreviewWatchStep -State $state -Since $since -Now (Get-Date) -GraceSeconds $GraceSeconds
        if ($step.Stop) {
            # Read again just before the kill: a server gone since the last look leaves its pid free for reuse.
            if ($target.HasExited) { break }
            & taskkill.exe /T /F /PID $ProcessId 2>&1 | Out-Null
            break
        }
        $since = $step.Since
        [void]$target.WaitForExit($PollSeconds * 1000)
    }
} catch { }
exit 0
