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
    exits. A disconnect counts only after the session was seen connected (#3595): one that reads
    disconnected from the start is in use while disconnected, since the hook ran there. And a WTSDisconnected
    read counts only where two other sources agree with it (#3597): the session is not the active console
    session (WTSGetActiveConsoleSessionId), and WTSEnumerateSessions lists it as disconnected too. Measured
    on a machine with fast user switching, the single read was inverted -- 4 for the active console session,
    0 for a disconnected one -- so a switch away and back could arm the watcher and then stop a server in
    use; a contradiction reads as uncertain (-1), which never stops a server. It exits as soon as the server
    does, so a server stopped by hand leaves nothing behind. The rules are Get-DevPreviewWatchStep in
    hub/lib/dev-preview-rules.ps1.

      -ProcessId     the cmd.exe the hook launched (the root of the server's tree)
      -StartTicks    that process's start time as FILETIME UTC: a pid reused by another process is not
                     the server, and is never stopped
      -GraceSeconds  how long the session must stay disconnected (default 60)
      -PollSeconds   how often it looks (default 15)
      -ForceState    the TEST override: the connect states to read instead of the session's own, one per
                     poll and the last one repeated, space-separated (e.g. '0 4')

    Exits 0 in every case: nobody reads its exit code. Pure ASCII (repo convention for .ps1).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][int]$ProcessId,
    [long]$StartTicks = 0,
    [int]$GraceSeconds = -1,
    [int]$PollSeconds = -1,
    [string]$ForceState = ''
)
$ErrorActionPreference = 'Stop'
try {
    . (Join-Path $PSScriptRoot '..\lib\dev-preview-rules.ps1')
    if ($GraceSeconds -lt 0) { $GraceSeconds = $script:DevPreviewWatchGraceSeconds }
    if ($PollSeconds -lt 1) { $PollSeconds = $script:DevPreviewWatchPollSeconds }

    # Held as a handle, so HasExited answers for THIS process even after its pid is reused.
    $target = [Diagnostics.Process]::GetProcessById($ProcessId)
    if ($StartTicks -and $target.StartTime.ToFileTimeUtc() -ne $StartTicks) { exit 0 }

    $forced = @($ForceState -split '\s+' | Where-Object { $_ } | ForEach-Object { [int]$_ })
    if (-not $forced.Count) {
        Add-Type -Namespace DkjDevPreview -Name Wts -MemberDefinition @'
[DllImport("wtsapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
static extern bool WTSQuerySessionInformation(IntPtr server, int sessionId, int infoClass, out IntPtr buffer, out int bytes);
[DllImport("wtsapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
static extern bool WTSEnumerateSessions(IntPtr server, int reserved, int version, out IntPtr sessions, out int count);
[DllImport("wtsapi32.dll")]
static extern void WTSFreeMemory(IntPtr memory);
[DllImport("kernel32.dll")]
static extern int WTSGetActiveConsoleSessionId();
[StructLayout(LayoutKind.Sequential)]
struct SessionInfo { public int SessionId; public IntPtr WinStationName; public int State; }
static int Listed(int session) {
    IntPtr list; int count;
    if (!WTSEnumerateSessions(IntPtr.Zero, 0, 1, out list, out count)) { return -1; }
    try {
        int size = Marshal.SizeOf(typeof(SessionInfo));
        for (int i = 0; i < count; i++) {
            SessionInfo s = (SessionInfo)Marshal.PtrToStructure(new IntPtr(list.ToInt64() + (long)i * size), typeof(SessionInfo));
            if (s.SessionId == session) { return s.State; }
        }
        return -1;
    } finally { WTSFreeMemory(list); }
}
public static int ConnectState() {
    int own = System.Diagnostics.Process.GetCurrentProcess().SessionId;
    IntPtr buffer; int bytes; int state;
    // WTS_CURRENT_SERVER_HANDLE, this process's own session, WTSConnectState
    if (!WTSQuerySessionInformation(IntPtr.Zero, own, 8, out buffer, out bytes)) { return -1; }
    try { state = bytes >= 4 ? Marshal.ReadInt32(buffer) : -1; }
    finally { WTSFreeMemory(buffer); }
    if (state != 4) { return state; }
    // A disconnect is acted on only when two other sources agree (#3597): the active console session is
    // never disconnected, and the session list must read WTSDisconnected too. A contradiction is uncertain.
    if (WTSGetActiveConsoleSessionId() == own) { return -1; }
    return Listed(own) == 4 ? 4 : -1;
}
'@
    }

    $since = $null
    $armed = $false
    $poll = 0
    while (-not $target.HasExited) {
        $state = if ($forced.Count) { $forced[[Math]::Min($poll, $forced.Count - 1)] } else { try { [DkjDevPreview.Wts]::ConnectState() } catch { -1 } }
        $poll++
        $step = Get-DevPreviewWatchStep -State $state -Since $since -Now (Get-Date) -GraceSeconds $GraceSeconds -Armed $armed
        $armed = $step.Armed
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
