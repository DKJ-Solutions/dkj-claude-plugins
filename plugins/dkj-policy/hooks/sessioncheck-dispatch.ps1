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
    check (consumer, ~2.8 s) plus little. Threads inside one process are what the pool costs instead.

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
      - STDIN is one handle per process, and the harness's payload (session_id, cwd, source) is
        written to it once. Two checks read it through Get-HookPayloadRaw for their per-session
        cache, and on the pool only the first reader got it -- measured in review: of three
        concurrent reads one returned the id and two returned ''. So this dispatcher reads the
        payload once, before the pool opens, and hands it over in DKJ_HOOK_PAYLOAD, which
        Get-HookPayloadRaw prefers when set.
      - STDOUT: a check that wrote to [Console]::Out directly would bypass the capture. None does.
      - $global: and the location are per runspace, and the suite holds every check to writing no
        process-wide state but the two non-interactive variables above.

    DISCOVERY, NOT A LIST. Every *-sessioncheck.ps1 in this directory is run, in name order, which is
    also the order of the report. A new check is added by adding its file -- there is no second place
    to forget. dev-preview-sessionstart.ps1 does not match the pattern on purpose: it starts servers,
    fires on a narrower matcher, and keeps its own hooks.json entry.

    THE OUTPUT is one SessionStart JSON object. A check that answers in SessionStart JSON
    (release-freshness) gives its systemMessage and its additionalContext. Only an object whose
    hookSpecificOutput.hookEventName is 'SessionStart' is read that way, so a plain check whose text
    merely parses as JSON cannot promote a line of it to the systemMessage the person sees -- it is
    forwarded as text. A check that writes plain lines gives those lines,
    which are additionalContext -- what plain stdout of a SessionStart hook already was. Nothing is
    reordered within a check, and nothing a check filtered out is added back.

    THE DEADLINE. The harness kills a hook at its hooks.json timeout and keeps none of its output, so
    one hung check would silence all ten. This dispatcher stops waiting at -DeadlineSeconds, reports the
    checks that had not finished by name, and leaves the process -- comfortably inside the 120 s entry.

    THE TIMING LINE. A session start had grown heavy (a trunk sync, ten checks, a hub start beside them)
    while nothing on screen said how long it took. So the dispatcher times each prep step and each check
    and ends its systemMessage with one line the person sees:
        sessionstart: 3.4 s -- prep 0.9 s (trunk-sync), checks 2.5 s (slowest: consumer 2.3 s, ...)
    It goes to the systemMessage only, never to additionalContext: it is for the person waiting, and the
    model has no use for it, so it costs no context. The interpreter's own cold start and the separate
    dev-preview entry, which runs beside this one, are outside it -- the line says "dispatcher" time,
    not the session's. The spinner text while this runs is hooks.json's statusMessage.

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

function Format-DispatchSeconds([double]$Ms) {
    return ($Ms / 1000).ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture) + ' s'
}

# Each script's name without its pattern suffix, so the timing line reads 'consumer', not
# 'consumer-sessioncheck'.
function Get-DispatchShortName([string]$BaseName) {
    return ($BaseName -replace '-session(check|prep)$', '')
}

$total = [System.Diagnostics.Stopwatch]::StartNew()
$system  = New-Object System.Collections.Generic.List[string]
$context = New-Object System.Collections.Generic.List[string]
$prepTimes  = New-Object System.Collections.Generic.List[object]
$checkTimes = New-Object System.Collections.Generic.List[object]
$prepMs = 0
$checkClock = $null
$pool = $null
$exitHard = $false
$payload = $null

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

    # Stdin, once, before any runspace exists -- see "STDIN" above. An empty payload is not handed
    # over, so a check falls back to reading stdin itself, which then finds nothing either.
    . (Join-Path $libDir 'session-cache-lib.ps1')
    $payload = Get-HookPayloadRaw
    if ($payload) { [Environment]::SetEnvironmentVariable('DKJ_HOOK_PAYLOAD', $payload, 'Process') }

    # PREP STEPS FIRST, ONE AFTER ANOTHER, BEFORE THE POOL OPENS (issue #3605). A prep step changes the
    # state the checks read -- trunk-sync-sessionprep fast-forwards the trunk the unfolded-entry check
    # reads -- so running it beside them would let a check measure a tree that moves under it. Same
    # discovery, same capture, same deadline; only the order differs.
    . $hookLib
    $deadline = [DateTime]::UtcNow.AddSeconds($DeadlineSeconds)
    $prepClock = [System.Diagnostics.Stopwatch]::StartNew()
    foreach ($prep in @(Get-ChildItem -LiteralPath $HooksDir -Filter '*-sessionprep.ps1' -File | Sort-Object Name)) {
        $stepClock = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $prepLines = @((Invoke-CheckScript -Path $prep.FullName).Output)
            $prepText = (@($prepLines | Where-Object { $_ -ne $null -and "$_".Trim() }) -join "`n").Trim()
            if ($prepText) { $context.Add($prepText) }
        } catch {
            $context.Add("$($prep.BaseName) skipped due to an error: " + (Format-DispatchSafeText $_.Exception.Message))
        }
        $prepTimes.Add([pscustomobject]@{ Name = (Get-DispatchShortName $prep.BaseName); Ms = $stepClock.ElapsedMilliseconds })
    }
    $prepMs = $prepClock.ElapsedMilliseconds
    # THE PREP IS DONE, AND THE DEV-PREVIEW HOOK WAITS FOR THIS MARK (issue #3657): it is a separate
    # SessionStart entry running beside this one, and a product server it starts before the trunk moved
    # serves the code from before the sync. Advisory: a mark that does not land costs that hook its wait.
    try { $null = Set-SessionPrepDone -SessionId (Get-SessionIdFromPayload -Payload $payload) } catch { }

    $checks = @(Get-ChildItem -LiteralPath $HooksDir -Filter '*-sessioncheck.ps1' -File | Sort-Object Name)

    $checkClock = [System.Diagnostics.Stopwatch]::StartNew()
    $pool = [runspacefactory]::CreateRunspacePool(1, [Math]::Max(1, $checks.Count))
    $pool.Open()

    $runs = foreach ($c in $checks) {
        $ps = [powershell]::Create()
        $ps.RunspacePool = $pool
        # The check's own clock runs inside its runspace, so a check that waited for a pool thread is
        # not charged for the wait. Ms rides on the result hashtable Invoke-CheckScript returns.
        [void]$ps.AddScript({
            param($lib, $path)
            $clock = [System.Diagnostics.Stopwatch]::StartNew()
            . $lib
            $res = Invoke-CheckScript -Path $path
            if ($res -is [hashtable]) { $res['Ms'] = $clock.ElapsedMilliseconds }
            $res
        }).AddArgument($hookLib).AddArgument($c.FullName)
        [pscustomobject]@{ Name = $c.BaseName; PS = $ps; Handle = $ps.BeginInvoke() }
    }

    # One deadline for the whole batch, not one per check: they run at the same time. It was set before
    # the prep steps, so their time is spent from the same budget.
    foreach ($r in $runs) {
        $left = [int][Math]::Max(0, ($deadline - [DateTime]::UtcNow).TotalMilliseconds)
        if (-not $r.Handle.AsyncWaitHandle.WaitOne($left)) {
            $context.Add("$($r.Name): did not finish within $DeadlineSeconds s -- skipped.")
            # The slowest check of all must not be the one the timing line leaves out.
            $checkTimes.Add([pscustomobject]@{ Name = (Get-DispatchShortName $r.Name); Ms = [long]$DeadlineSeconds * 1000; Hung = $true })
            $exitHard = $true
            continue
        }
        try {
            $result = @($r.PS.EndInvoke($r.Handle))
            $lines = @()
            if ($result.Count -gt 0 -and $result[-1] -is [hashtable]) {
                $lines = @($result[-1].Output)
                if ($result[-1].ContainsKey('Ms')) { $checkTimes.Add([pscustomobject]@{ Name = (Get-DispatchShortName $r.Name); Ms = [long]$result[-1].Ms; Hung = $false }) }
            }
            # A check that answers in JSON writes one object as its whole output; anything else is
            # plain lines. Recognised by parsing, not by name, so a second JSON check needs no edit here.
            $text = (@($lines | Where-Object { $_ -ne $null -and "$_".Trim() }) -join "`n").Trim()
            $json = $null
            if ($text.StartsWith('{')) { try { $json = $text | ConvertFrom-Json } catch { $json = $null } }
            # A SessionStart object, or text -- see THE OUTPUT above.
            if ($json -and -not ($json.PSObject.Properties['hookSpecificOutput'] -and $json.hookSpecificOutput -and
                    $json.hookSpecificOutput.PSObject.Properties['hookEventName'] -and
                    $json.hookSpecificOutput.hookEventName -eq 'SessionStart')) { $json = $null }
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
    # The prep-done mark is owed whatever failed (#3657): without it the dev-preview hook waits out its bound.
    try { $null = Set-SessionPrepDone -SessionId (Get-SessionIdFromPayload -Payload $payload) } catch { }
    # Checks may still be running on the pool, and Close() would wait on them.
    $exitHard = $true
}

# The timing line -- see THE TIMING LINE above. Built in its own try, so a failure here can never cost
# the report the checks produced.
try {
    $parts = New-Object System.Collections.Generic.List[string]
    if ($prepTimes.Count -gt 0) {
        $parts.Add('prep ' + (Format-DispatchSeconds $prepMs) + ' (' + (@($prepTimes | ForEach-Object { $_.Name }) -join ', ') + ')')
    }
    if ($checkTimes.Count -gt 0 -and $checkClock) {
        $slowest = @($checkTimes | Sort-Object -Property Ms -Descending | Select-Object -First 3 |
            ForEach-Object { if ($_.Hung) { "$($_.Name) >$DeadlineSeconds s" } else { "$($_.Name) " + (Format-DispatchSeconds $_.Ms) } })
        $parts.Add('checks ' + (Format-DispatchSeconds $checkClock.ElapsedMilliseconds) + ' (slowest: ' + ($slowest -join ', ') + ')')
    }
    $timing = 'sessionstart: ' + (Format-DispatchSeconds $total.ElapsedMilliseconds) + ' in the dispatcher'
    if ($parts.Count -gt 0) { $timing += ' -- ' + ($parts -join ', ') }
    $system.Add($timing)
} catch {
    $system.Add('sessionstart: timing skipped due to an error: ' + (Format-DispatchSafeText $_.Exception.Message))
}

if ($system.Count -gt 0 -or $context.Count -gt 0) {
    $payload = [ordered]@{}
    if ($system.Count -gt 0) { $payload['systemMessage'] = ($system -join "`n") }
    # The timing line is always there, so an otherwise silent start carries no hookSpecificOutput --
    # an empty additionalContext would only be noise in the session's context.
    if ($context.Count -gt 0) {
        $payload['hookSpecificOutput'] = [ordered]@{
            hookEventName     = 'SessionStart'
            additionalContext = ($context -join "`n")
        }
    }
    [Console]::Out.WriteLine(($payload | ConvertTo-Json -Depth 4 -Compress))
    [Console]::Out.Flush()
}

# A check still running past the deadline holds a pool thread that a normal exit would wait on, so that
# one case leaves the process outright. Otherwise the pool is closed the ordinary way.
if ($exitHard) { [Environment]::Exit(0) }
if ($pool) { $pool.Close(); $pool.Dispose() }
exit 0
