<#
.SYNOPSIS
    SessionStart hook of the workflow plugin: runs every *-sessioncheck.ps1 beside it in ONE
    interpreter, in parallel, and hands the harness their merged report (issue #3472).

.DESCRIPTION
    WHY ONE ENTRY AND NOT TEN. Each session check used to be its own hooks.json entry, so every
    startup, resume, clear and compact started ten cold powershell.exe processes in the same instant --
    thirteen with the core team's and dkj-solutions' own. Under system pressure an interpreter can fail
    during initialization, before a line of its script runs ('Unable to start thread', measured on
    October 25, 2026 in a consumer, #3472; the same class as #2217). The checks are informational, so
    nothing went unguarded, but the person got a wall of harness errors and some checks silently did
    not report. One entry starts one interpreter; a check that fails here lands as a line in the merged
    report instead of as a harness error.

    WHY A RUNSPACE POOL AND NOT A LOOP. "Claude Code runs all matching hooks in parallel", so ten
    entries cost the SLOWEST check, not the sum. A loop would trade the cold starts for wall-clock.
    Measured on this repo, n=2, Windows PowerShell 5.1: the ten checks one after another in one
    interpreter 7529 / 7659 ms; the same ten in a runspace pool 3124 / 2967 ms, which is the slowest
    check (connector, ~2.8 s) plus little. Threads inside one process are what the pool costs instead.

    EACH CHECK STILL RUNS AS ITS OWN SCRIPT, through Invoke-CheckScript (hook-check-lib.ps1, #1625):
    its 'exit' ends the check and not this dispatcher, and its Write-Host is captured rather than
    leaking to stdout. So every *-sessioncheck.ps1 keeps working when run on its own, and its suite
    tests it that way.

    WHAT A POOL SHARES THAT TEN PROCESSES DID NOT, and why each is safe:
      - the WORKING DIRECTORY: every runspace starts in the process's, which is the harness's -- the
        directory each check ran in before. No check in this plugin changes it.
      - ENVIRONMENT VARIABLES are process-wide. Invoke-NativeCapture sets GIT_TERMINAL_PROMPT and
        GCM_INTERACTIVE around each child and restores them afterwards, and two checks doing that at
        once would interleave the restores -- one check's child could then start interactive. So this
        dispatcher sets those values ONCE, before the pool opens: every push then saves the value it
        sets, every pop restores it, and the interleaving changes nothing. Nothing interactive is ever
        wanted from a session-start hook.
      - STDOUT: a check that wrote to [Console]::Out directly would bypass the capture. None does.

    DISCOVERY, NOT A LIST. Every *-sessioncheck.ps1 in this directory is run, in name order, which is
    also the order of the report. A new check is added by adding its file -- there is no second place
    to forget. dev-preview-sessionstart.ps1 does not match the pattern on purpose: it starts servers,
    fires on a narrower matcher, and keeps its own hooks.json entry.

    THE OUTPUT is one SessionStart JSON object. A check that answers in JSON (release-freshness) gives
    its systemMessage and its additionalContext; a check that writes plain lines gives those lines,
    which are additionalContext -- what plain stdout of a SessionStart hook already was. Nothing is
    reordered within a check, and nothing a check filtered out is added back.

    THE DEADLINE. The harness kills a hook at its hooks.json timeout and keeps none of its output, so
    one hung check would silence all ten. This dispatcher stops waiting at -DeadlineSeconds, reports the
    checks that had not finished by name, and leaves the process -- comfortably inside the 120 s entry.

    The script ALWAYS ends with exit 0 -- a session start must never strand here.

.PARAMETER HooksDir
    (Optional, for tests) The directory to discover *-sessioncheck.ps1 in. Defaults to this script's.

.PARAMETER DeadlineSeconds
    (Optional) How long to wait for the checks before reporting the unfinished ones. Default 100.
#>
[CmdletBinding()]
param(
    [string]$HooksDir = '',
    [int]$DeadlineSeconds = 100
)

Set-StrictMode -Version Latest

# The same last-resort strip every check's own catch inlines (#2271): whitespace first, so no newline
# can forge a line, then control characters, then brackets, so no marker can form. A check's exception
# text is foreign -- a consumer's path, their file's own line -- and it is forwarded into session context.
function Format-DispatchSafeText([string]$Text) {
    return ((((($Text) -replace '\s+', ' ') -replace '\p{C}', '') -replace '\[', '(') -replace '\]', ')').Trim()
}

$system  = New-Object System.Collections.Generic.List[string]
$context = New-Object System.Collections.Generic.List[string]
$pool = $null
$exitHard = $false

try {
    if (-not $HooksDir) { $HooksDir = $PSScriptRoot }
    $libDir = Join-Path $PSScriptRoot '..\scripts\lib'
    $hookLib = Join-Path $libDir 'hook-check-lib.ps1'

    # Process-wide, once, before any runspace exists -- see "ENVIRONMENT VARIABLES" above. The values
    # come from native-capture-lib's own table, so this cannot drift from what its push sets.
    . (Join-Path $libDir 'native-capture-lib.ps1')
    foreach ($name in @($script:NativeCaptureNonInteractiveEnv.Keys)) {
        [Environment]::SetEnvironmentVariable($name, $script:NativeCaptureNonInteractiveEnv[$name], 'Process')
    }

    $checks = @(Get-ChildItem -LiteralPath $HooksDir -Filter '*-sessioncheck.ps1' -File | Sort-Object Name)

    $pool = [runspacefactory]::CreateRunspacePool(1, [Math]::Max(1, $checks.Count))
    $pool.Open()

    $runs = foreach ($c in $checks) {
        $ps = [powershell]::Create()
        $ps.RunspacePool = $pool
        [void]$ps.AddScript({
            param($lib, $path)
            . $lib
            Invoke-CheckScript -Path $path
        }).AddArgument($hookLib).AddArgument($c.FullName)
        [pscustomobject]@{ Name = $c.BaseName; PS = $ps; Handle = $ps.BeginInvoke() }
    }

    # One deadline for the whole batch, not one per check: they run at the same time.
    $deadline = [DateTime]::UtcNow.AddSeconds($DeadlineSeconds)
    foreach ($r in $runs) {
        $left = [int][Math]::Max(0, ($deadline - [DateTime]::UtcNow).TotalMilliseconds)
        if (-not $r.Handle.AsyncWaitHandle.WaitOne($left)) {
            $context.Add("$($r.Name): did not finish within $DeadlineSeconds s -- skipped.")
            $exitHard = $true
            continue
        }
        try {
            $result = @($r.PS.EndInvoke($r.Handle))
            $lines = @()
            if ($result.Count -gt 0 -and $result[-1] -is [hashtable]) { $lines = @($result[-1].Output) }
            # A check that answers in JSON writes one object as its whole output; anything else is
            # plain lines. Recognised by parsing, not by name, so a second JSON check needs no edit here.
            $text = (@($lines | Where-Object { $_ -ne $null -and "$_".Trim() }) -join "`n").Trim()
            $json = $null
            if ($text.StartsWith('{')) { try { $json = $text | ConvertFrom-Json } catch { $json = $null } }
            if ($json) {
                if ($json.PSObject.Properties['systemMessage'] -and $json.systemMessage) { $system.Add([string]$json.systemMessage) }
                if ($json.PSObject.Properties['hookSpecificOutput'] -and $json.hookSpecificOutput -and
                    $json.hookSpecificOutput.PSObject.Properties['additionalContext'] -and $json.hookSpecificOutput.additionalContext) {
                    $context.Add([string]$json.hookSpecificOutput.additionalContext)
                }
            } elseif ($text) {
                $context.Add($text)
            }
        } catch {
            # EndInvoke wraps the check's own exception ('Exception calling "EndInvoke" ...'); the
            # reader wants what the check said, so the innermost one is reported.
            $e = $_.Exception
            while ($e.InnerException) { $e = $e.InnerException }
            $context.Add("$($r.Name) skipped due to an error: " + (Format-DispatchSafeText $e.Message))
        }
    }
} catch {
    $context.Add('sessioncheck-dispatch skipped due to an error: ' + (Format-DispatchSafeText $_.Exception.Message))
}

if ($system.Count -gt 0 -or $context.Count -gt 0) {
    $payload = [ordered]@{}
    if ($system.Count -gt 0) { $payload['systemMessage'] = ($system -join "`n") }
    $payload['hookSpecificOutput'] = [ordered]@{
        hookEventName     = 'SessionStart'
        additionalContext = ($context -join "`n")
    }
    [Console]::Out.WriteLine(($payload | ConvertTo-Json -Depth 4 -Compress))
    [Console]::Out.Flush()
}

# A check still running past the deadline holds a pool thread that a normal exit would wait on, so that
# one case leaves the process outright. Otherwise the pool is closed the ordinary way.
if ($exitHard) { [Environment]::Exit(0) }
if ($pool) { $pool.Close(); $pool.Dispose() }
exit 0
