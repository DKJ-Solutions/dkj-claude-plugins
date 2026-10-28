<#
.SYNOPSIS
    Name every hub server and dev-preview-watch process on this machine that has outlived the run that
    started it, with its memory and the line that stops it (#3620). Reports; stops nothing.

.DESCRIPTION
    MEASURED OCTOBER 28, 2026 (#3620): a ship-pr killed for low memory mid-gate left 26 hub servers and
    watchers from the suites it was running, about 2.3 GB, and a watcher from plugin 5.34.0 had outlived
    its own server by five hours. That memory is what pushes the next gate into the same kill, and nothing
    reported it. #3625 tied a suite's servers to the suite; this is the reading that names what still got
    through -- a run killed before #3625, a watcher that missed its server's end, a plugin version the
    machine has moved past.

    WHICH PROCESS COUNTS, and why the parent is not the test: Get-HubProcessVerdict in tidy-lib.ps1.

    ITS TWO CALLERS are hub-processes-sessioncheck.ps1, so a session is told at start, and tidy-machine's
    lane 13, which lists the same thing on demand.

    IT STOPS NOTHING. A process is not a merge proof, and tidy-machine's authority split (Dave, September
    10, 2026) lets it act on those alone. The Stop-Process line it prints is the reader's.

    A process whose command line this run cannot read -- another security context, elevated or sandboxed
    -- is counted and said, never judged: "not ours" would be a guess.

    Output markers: [WARN] per finding, [OK] when there is none, [INFO] for the unreadable count. Exit 0
    always: it is advisory, and its callers decide what to make of it.

    Windows only (the process table is CIM). Pure ASCII (repo convention for .ps1).

.PARAMETER UserHomeOverride
    (Fixtures) the home whose ~/.claude holds the install register and the plugin cache.

.PARAMETER ProcessTableJson
    (Fixtures) a JSON file holding the process table to judge instead of this machine's: an array of
    { ProcessId, ParentProcessId, Name, CommandLine, Ticks, WorkingSetMB }.
#>
[CmdletBinding()]
param(
    [string]$UserHomeOverride = '',
    [string]$ProcessTableJson = ''
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\tidy-lib.ps1')

$rows = @()
if ($ProcessTableJson) {
    # Enumerated, because Windows PowerShell 5.1's ConvertFrom-Json hands a JSON array on as ONE object.
    $rows = @((Get-Content -LiteralPath $ProcessTableJson -Raw | ConvertFrom-Json) | ForEach-Object { $_ })
} else {
    if ($env:OS -ne 'Windows_NT') { Write-Host '[OK] not Windows -- there is no hub process to judge here.'; exit 0 }
    try {
        # ONE read of the whole table: the verdict walks parents and checks pids that are not
        # powershell.exe (the cmd.exe a server runs under, the suite that owns a watcher).
        $rows = @(Get-CimInstance -ClassName Win32_Process -Property ProcessId, ParentProcessId, Name, CommandLine, CreationDate, WorkingSetSize -ErrorAction Stop |
            ForEach-Object {
                [pscustomobject]@{
                    ProcessId       = [int]$_.ProcessId
                    ParentProcessId = [int]$_.ParentProcessId
                    Name            = [string]$_.Name
                    CommandLine     = [string]$_.CommandLine
                    Ticks           = $(if ($_.CreationDate) { $_.CreationDate.ToFileTimeUtc() } else { 0 })
                    WorkingSetMB    = [math]::Round(([double]$_.WorkingSetSize) / 1MB)
                }
            })
    } catch {
        Write-Host ('[INFO] the process table could not be read -- nothing judged: ' + ((([string]$_.Exception.Message) -replace '\s+', ' ') -replace '\p{C}', ''))
        exit 0
    }
}

$table = @{}
foreach ($r in $rows) { $table[[int]$r.ProcessId] = @{ ParentId = [int]$r.ParentProcessId; Name = [string]$r.Name; Ticks = [long]$r.Ticks } }

$userHome = Get-UserClaudeHome -UserHomeOverride $UserHomeOverride
$cacheRoot = if ($userHome) { Join-Path $userHome '.claude\plugins\cache' } else { '' }
$installPaths = @()
$registerRead = $false
if ($userHome) {
    # Only AllRecords is read, which does not depend on the root. It is resolved properly anyway, as
    # check-claude-home.ps1 does and for its reason: every shared script resolves its root dual-context.
    $rootScope = Resolve-CheckRoot -Override ''
    $scopeRoot = if ($rootScope.Path) { $rootScope.Path } else { $PSScriptRoot }
    $install = Get-InstallRecord -RepoRoot $scopeRoot -UserHomeOverride $UserHomeOverride
    if ($install.Exists -and $install.Readable) {
        $installPaths = @(@($install.AllRecords) | ForEach-Object { [string]$_.InstallPath } | Where-Object { $_ })
        $registerRead = $installPaths.Count -gt 0
    }
}

# TWO PASSES: the watchers first, because a suite's server is judged by its watcher (Get-HubProcessVerdict).
$shells = @($rows | Where-Object { [string]$_.Name -match '^(powershell|pwsh)\.exe$' })
function Get-Verdict($r, [hashtable]$Watchers) {
    Get-HubProcessVerdict -CommandLine ([string]$r.CommandLine) -ParentId ([int]$r.ParentProcessId) -Processes $table `
        -InstallPaths $installPaths -CacheRoot $cacheRoot -RegisterRead $registerRead `
        -ProcessId ([int]$r.ProcessId) -Ticks ([long]$r.Ticks) -Watchers $Watchers
}
$watchers = @{}
foreach ($r in $shells) {
    $w = Get-Verdict $r @{}
    if ($w.Kind -eq 'watcher' -and $w.Target -gt 0) { $watchers[[int]$w.Target] = $(if ($w.Class -eq 'orphan') { 'orphan' } else { 'live' }) }
}

$findings = @()
$unreadable = 0; $unreadableMB = 0; $live = 0
foreach ($r in $shells) {
    $v = Get-Verdict $r $watchers
    switch ($v.Class) {
        'unreadable' { $unreadable++; $unreadableMB += [double]$r.WorkingSetMB }
        'live'       { $live++ }
        { $_ -in 'orphan', 'stale' } { $findings += [pscustomobject]@{ Pid = [int]$r.ProcessId; MB = [double]$r.WorkingSetMB; Verdict = $v } }
    }
}

if ($findings.Count -eq 0) {
    Write-Host "[OK] no hub process has outlived the run that started it ($live running as they should)."
} else {
    $total = ($findings | Measure-Object -Property MB -Sum).Sum
    Write-Host "[WARN] $($findings.Count) hub process(es) outlived the run that started them, holding about $([int]$total) MB:"
    foreach ($f in @($findings | Sort-Object -Property MB -Descending)) {
        Write-Host ("  [WARN] pid {0}, {1} MB -- {2} from {3}: {4}" -f $f.Pid, [int]$f.MB, $f.Verdict.Kind, $f.Verdict.Where, $f.Verdict.Reason)
        Write-Host ("         Stop-Process -Id {0} -Force" -f $f.Pid)
    }
    Write-Host '  Stopping one ends nothing a session needs: the next session start brings its own hub back.'
}
if (-not $registerRead) {
    Write-Host '[INFO] the install register could not be read, so no hub process was judged stale by its plugin version.'
}
if ($unreadable -gt 0) {
    Write-Host "[INFO] $unreadable powershell.exe process(es), about $([int]$unreadableMB) MB, run in another security context (elevated, or a sandboxed run) and hide their command line from this one -- not judged."
}
exit 0
