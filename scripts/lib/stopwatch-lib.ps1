<#
.SYNOPSIS
    The Stopwatch page of this repo's dev server (#3315): time an assignment from the moment it is given to
    the moment it is done, by hand or armed to start and stop by itself (#3323), and compare each run with the
    previous run of the same label, so the slow steps of the workflow show and every next run can be made shorter.

.DESCRIPTION
    THE CLOCK IS THE SERVER'S, NOT THE PAGE'S. Start, Lap and Stop each write a timestamp to the store,
    and the page only draws the time since the stored start. The hub restarts itself whenever the checkout's
    HEAD moves (#3122), and the workflow a run measures moves HEAD at every branch switch, merge and fold,
    so a clock kept in the page would be lost halfway through the very run it is timing.

    THE STORE IS OUTSIDE THE TREE: %LOCALAPPDATA%\dkj-claude-plugins\stopwatch.json (Get-StopwatchStorePath).
    A file in the checkout would dirty it in the middle of the workflow being measured, and the scripts
    that ship a branch refuse a dirty tree. So the runs are this machine's, like the session transcripts the
    transcript phases read (below).

    A RUN CAN START ITSELF FROM THE TERMINAL (#3323): a prompt whose first line begins with `stopwatch:` (any case,
    leading whitespace allowed) starts an Auto run at once, labelled with the rest of that line (Get-StopwatchPromptMarker;
    "Assignment" when it is empty). That is the main route; it needs no page. A marked prompt while a run is going
    does nothing, and a marked prompt wins over an armed label and clears the arming.

    ARMED RUNS START AND STOP THEMSELVES (#3323). Arm stores a label as `armed` (top level of the store, beside
    the runs); no clock runs yet. scripts/dashboard/stopwatch-hook.ps1, wired in .claude/settings.json as a
    UserPromptSubmit and a Stop hook, calls Invoke-StopwatchHookEvent: the next prompt submitted in a session of
    this checkout starts the armed run (Auto, with the checkout's HEAD as StartHead) and clears the arming, and a
    Stop hook ends a running Auto run once the checkout is on the trunk, clean, with HEAD moved off StartHead (a
    sign the work landed, not a proof of it). The HEAD test is the reason no branch needs to be seen: a whole ship (branch, PR, merge, fold) usually happens
    inside one turn, and the Stop hook fires only at a turn's end. A turn that only answers leaves HEAD where it
    was, and a branch parked for the owner's eye is not on the trunk, so the run keeps going in both. A run
    started by hand is never touched by the hooks.

    A STORE THAT DOES NOT READ IS NEVER WRITTEN OVER. Read-StopwatchStore returns an Error for a file that
    is not valid JSON, and every write refuses while it is set, so one bad edit by hand loses nothing.

    Pure except Read-StopwatchStore and Save-StopwatchStore (the store's own file), Read-StopwatchTranscriptEvents
    (one session transcript, read only) and Get-StopwatchTranscriptCache (the transcripts, and stopwatch-phases.json
    beside the store). Every
    value that reaches the page is escaped through ConvertTo-DashboardText. Pure ASCII (repo convention for
    .ps1). Tested by scripts/tests/stopwatch.tests.ps1.
#>

$script:StopwatchLabelMax = 80
$script:StopwatchNoteMax = 2000
$script:StopwatchLapMax = 100

function Get-StopwatchStorePath {
    <# The store's path on this machine: under LOCALAPPDATA, else the per-user local data folder .NET names. #>
    $base = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { [Environment]::GetFolderPath('LocalApplicationData') }
    return (Join-Path $base 'dkj-claude-plugins\stopwatch.json')
}

function ConvertTo-StopwatchTime {
    <# A stored timestamp as a UTC DateTime, or $null. ConvertFrom-Json leaves it a string in 5.1 and makes it a DateTime in 7. #>
    param($Value)
    if ($Value -is [datetime]) { return $Value.ToUniversalTime() }
    if (-not $Value) { return $null }
    $t = [datetime]::MinValue
    if ([datetime]::TryParse([string]$Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind, [ref]$t)) { return $t.ToUniversalTime() }
    return $null
}

function Format-StopwatchStamp {
    <# A UTC DateTime as the store writes it: ISO 8601 with milliseconds and a Z. #>
    param([datetime]$Time)
    return $Time.ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'", [Globalization.CultureInfo]::InvariantCulture)
}

function ConvertTo-StopwatchRun {
    <# One run from the parsed store as a hashtable, or $null when it has no id, label or readable start. #>
    param($Raw)
    if ($null -eq $Raw) { return $null }
    $id = [string]$Raw.id; $label = [string]$Raw.label
    $start = ConvertTo-StopwatchTime $Raw.start
    if ($id -cnotmatch '^[0-9A-Za-z-]{1,40}\z' -or -not $label.Trim() -or -not $start) { return $null }
    $laps = @(foreach ($l in @($Raw.laps)) {
            if ($null -eq $l) { continue }
            $at = ConvertTo-StopwatchTime $l.at
            if ($at) { @{ Name = [string]$l.name; At = $at } }
        })
    return @{ Id = $id; Label = $label.Trim(); Start = $start; End = (ConvertTo-StopwatchTime $Raw.end); Laps = $laps; Note = [string]$Raw.note
        Auto = [bool]$Raw.auto; StartHead = [string]$Raw.startHead }
}

function Read-StopwatchStore {
    <#
        The runs in the store at -Path, oldest first, the Armed state (@{ Label; At }, or $null) and an Error that
        is empty when it read. A missing file is an empty store, not an error. A run that does not parse is skipped
        and counted in Skipped; an armed entry that does not parse is simply not armed.
    #>
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @{ Runs = @(); Armed = $null; Error = ''; Skipped = 0 } }
    try {
        $text = [System.IO.File]::ReadAllText($Path, (New-Object System.Text.UTF8Encoding($false)))
        $json = if ($text.Trim()) { $text | ConvertFrom-Json } else { $null }
    } catch {
        return @{ Runs = @(); Armed = $null; Error = 'it is not valid JSON'; Skipped = 0 }
    }
    $runs = @(); $skipped = 0
    foreach ($r in @($(if ($json) { $json.runs } else { @() }))) {
        if ($null -eq $r) { continue }
        $run = ConvertTo-StopwatchRun $r
        if ($run) { $runs += $run } else { $skipped++ }
    }
    $armed = $null
    if ($json -and $json.armed) {
        $al = ([string]$json.armed.label).Trim(); $aAt = ConvertTo-StopwatchTime $json.armed.at
        if ($al -and $aAt) { $armed = @{ Label = $al; At = $aAt } }
    }
    return @{ Runs = @($runs | Sort-Object { $_.Start }); Armed = $armed; Error = ''; Skipped = $skipped }
}

function Save-StopwatchStore {
    <# Writes -Runs and -Armed (@{ Label; At }, or $null) to -Path through a file beside it, so a failed write never leaves half a store. #>
    param([Parameter(Mandatory = $true)][string]$Path, [AllowEmptyCollection()][object[]]$Runs = @(), [hashtable]$Armed = $null)
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
    $out = @{ runs = @(foreach ($r in @($Runs)) {
                [ordered]@{
                    id    = $r.Id
                    label = $r.Label
                    start = (Format-StopwatchStamp $r.Start)
                    end   = $(if ($r.End) { Format-StopwatchStamp $r.End } else { $null })
                    laps  = @(foreach ($l in @($r.Laps)) { [ordered]@{ name = $l.Name; at = (Format-StopwatchStamp $l.At) } })
                    note  = $r.Note
                    auto  = [bool]$r.Auto
                    startHead = [string]$r.StartHead
                }
            })
        armed = $(if ($Armed) { [ordered]@{ label = $Armed.Label; at = (Format-StopwatchStamp $Armed.At) } } else { $null }) }
    $tmp = "$Path.tmp"
    [System.IO.File]::WriteAllText($tmp, ($out | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function ConvertFrom-StopwatchQuery {
    <# The query string of a request target as a hashtable of decoded values ('+' is a space). #>
    param([AllowEmptyString()][string]$Target = '')
    $q = @{}
    $i = $Target.IndexOf('?')
    if ($i -lt 0) { return $q }
    foreach ($pair in $Target.Substring($i + 1) -split '&') {
        if (-not $pair) { continue }
        $k, $v = $pair -split '=', 2
        try { $q[[Uri]::UnescapeDataString(($k -replace '\+', ' '))] = [Uri]::UnescapeDataString(([string]$v -replace '\+', ' ')) } catch { continue }
    }
    return $q
}

function New-StopwatchRunId {
    <# A run's id: the start time plus four hex. #>
    param([Parameter(Mandatory = $true)][datetime]$Now)
    return $Now.ToUniversalTime().ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture) + '-' + ([guid]::NewGuid().ToString('N').Substring(0, 4))
}

function New-StopwatchRun {
    <# A run that starts now. -Auto marks one a hook started; -StartHead is the checkout's HEAD then (#3323). #>
    param([Parameter(Mandatory = $true)][string]$Label, [Parameter(Mandatory = $true)][datetime]$Now, [switch]$Auto, [string]$StartHead = '')
    return @{ Id = (New-StopwatchRunId -Now $Now); Label = $Label; Start = $Now.ToUniversalTime(); End = $null; Laps = @(); Note = ''; Auto = [bool]$Auto; StartHead = $StartHead }
}

function Invoke-StopwatchAction {
    <#
        One button press against -Runs: start, lap, stop, discard (the running run), note or delete (a finished
        run, by -Id), and arm or disarm (-Armed, the stored armed label, #3323; a start clears it). Returns the new runs, the new
        Armed (the one passed in unless arm or disarm changed it) and an Error; on an error the runs and Armed
        come back unchanged. Arm is refused while a run is going and replaces an earlier armed label. -Now is
        the server's clock, passed in so every rule is tested without one.
    #>
    param(
        [AllowEmptyCollection()][object[]]$Runs = @(),
        [Parameter(Mandatory = $true)][string]$Action,
        [hashtable]$Query = @{},
        [Parameter(Mandatory = $true)][datetime]$Now,
        [hashtable]$Armed = $null
    )
    $runs = @($Runs | Where-Object { $_ })
    $running = @($runs | Where-Object { -not $_.End }) | Select-Object -Last 1
    $fail = { param($m) return @{ Runs = $runs; Armed = $Armed; Error = $m } }
    $ok = { param($r, $a) return @{ Runs = @($r); Armed = $a; Error = '' } }
    # A control character becomes a space; -Lines keeps a note's line breaks and tabs (Victor, #3315).
    $text = { param($k, $max, [switch]$Lines) $cc = if ($Lines) { '[\x00-\x08\x0b-\x1f\x7f]' } else { '[\x00-\x1f\x7f]' }
        $v = ([string]$Query[$k] -replace "`r`n", "`n") -replace $cc, ' '; $v = $v.Trim(); if ($v.Length -gt $max) { $v = $v.Substring(0, $max) }; $v }
    $now = $Now.ToUniversalTime()
    switch ($Action) {
        'start' {
            if ($running) { return (& $fail "A run is already going: '$($running.Label)'. Stop or discard it first.") }
            $label = & $text 'label' $script:StopwatchLabelMax
            if (-not $label) { return (& $fail 'A run needs a label, such as "CSS comment".') }
            # A manual start while armed clears the arming, so no auto run follows it.
            return (& $ok @($runs + @(New-StopwatchRun -Label $label -Now $now)) $null)
        }
        'arm' {
            if ($running) { return (& $fail "A run is already going: '$($running.Label)'. Stop or discard it before arming.") }
            $label = & $text 'label' $script:StopwatchLabelMax
            if (-not $label) { return (& $fail 'An armed run needs a label, such as "CSS comment".') }
            return (& $ok $runs @{ Label = $label; At = $now })
        }
        'disarm' { return (& $ok $runs $null) }
        { $_ -in 'lap', 'stop', 'discard' } {
            if (-not $running) { return (& $fail 'No run is going.') }
            if ($Action -eq 'discard') { return (& $ok @($runs | Where-Object { $_.Id -ne $running.Id }) $Armed) }
            $copy = $running.Clone()
            if ($Action -eq 'lap') {
                if (@($copy.Laps).Count -ge $script:StopwatchLapMax) { return (& $fail "A run holds at most $($script:StopwatchLapMax) laps.") }
                $name = & $text 'name' $script:StopwatchLabelMax
                if (-not $name) { $name = 'Lap ' + (@($copy.Laps).Count + 1) }
                $copy.Laps = @(@($copy.Laps) + @(@{ Name = $name; At = $now }))
            } else {
                $copy.End = $now
            }
            return (& $ok @($runs | ForEach-Object { if ($_.Id -eq $copy.Id) { $copy } else { $_ } }) $Armed)
        }
        { $_ -in 'note', 'delete' } {
            $id = [string]$Query['id']
            $target = @($runs | Where-Object { $_.Id -ceq $id -and $_.End }) | Select-Object -First 1
            if (-not $target) { return (& $fail 'That run is not in the store, or it is still going.') }
            if ($Action -eq 'delete') { return (& $ok @($runs | Where-Object { $_.Id -cne $id }) $Armed) }
            $copy = $target.Clone()
            $copy.Note = & $text 'text' $script:StopwatchNoteMax -Lines
            return (& $ok @($runs | ForEach-Object { if ($_.Id -ceq $id) { $copy } else { $_ } }) $Armed)
        }
        default { return (& $fail "Unknown action '$Action'.") }
    }
}

function Get-StopwatchPromptMarker {
    <#
        The label a prompt asks a run under, or $null when it carries no marker (#3323): the first line of -Prompt
        begins, after any leading whitespace, with `stopwatch:` in any case. The label is the rest of that line,
        control characters as spaces, trimmed and cut to the label maximum; empty becomes "Assignment".
    #>
    param([AllowEmptyString()][string]$Prompt = '')
    $m = [regex]::Match($Prompt.TrimStart(), '^stopwatch:([^' + [char]13 + [char]10 + ']*)', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $m.Success) { return $null }
    $label = ($m.Groups[1].Value -replace ('[' + [char]0 + '-' + [char]31 + [char]127 + ']'), ' ').Trim()
    if ($label.Length -gt $script:StopwatchLabelMax) { $label = $label.Substring(0, $script:StopwatchLabelMax).Trim() }
    if (-not $label) { $label = 'Assignment' }
    return $label
}

function Invoke-StopwatchHookEvent {
    <#
        What a Claude Code hook does to the store (#3323), decided without git or a clock so every rule is tested.
        -Hook Prompt: a -Prompt marked `stopwatch:` (Get-StopwatchPromptMarker) with no run going starts an Auto
        run under its label and clears any arming (the marker wins); a marked prompt while a run is going does
        nothing. An unmarked prompt with an armed label and no run going starts an Auto run under that label.
        Either way -Head is the run's StartHead and the arming is cleared; otherwise nothing. -Hook Stop: a running Auto run ends at -Now
        only when -Branch is -Trunk, -Clean (git status --porcelain was empty) and -Head is not the run's
        StartHead, taken as work that landed (it proves HEAD moved, not that anything was merged); otherwise nothing.
        A Prompt with an empty -Head starts nothing and keeps the arming, since a run without a StartHead could
        never stop by itself. A run without a StartHead never stops
        this way, and a run started by hand is never touched. Returns Runs, Armed and Changed (write only when set).
    #>
    param(
        [Parameter(Mandatory = $true)][ValidateSet('Prompt', 'Stop')][string]$Hook,
        [AllowEmptyCollection()][object[]]$Runs = @(),
        [hashtable]$Armed = $null,
        [Parameter(Mandatory = $true)][datetime]$Now,
        [string]$Branch = '',
        [bool]$Clean = $false,
        [string]$Head = '',
        [string]$Trunk = 'main',
        [AllowEmptyString()][string]$Prompt = ''
    )
    $runs = @($Runs | Where-Object { $_ })
    $running = @($runs | Where-Object { -not $_.End }) | Select-Object -Last 1
    $same = @{ Runs = $runs; Armed = $Armed; Changed = $false }
    if ($Hook -eq 'Prompt') {
        $marked = Get-StopwatchPromptMarker -Prompt $Prompt
        if ($running -or -not $Head -or (-not $Armed -and $null -eq $marked)) { return $same }
        $label = if ($null -ne $marked) { $marked } else { $Armed.Label }
        return @{ Runs = @($runs + @(New-StopwatchRun -Label $label -Now $Now -Auto -StartHead $Head)); Armed = $null; Changed = $true }
    }
    if (-not $running -or -not $running.Auto -or -not $running.StartHead) { return $same }
    if ($Branch -cne $Trunk -or -not $Clean -or -not $Head -or $Head -ceq $running.StartHead) { return $same }
    $copy = $running.Clone(); $copy.End = $Now.ToUniversalTime()
    return @{ Runs = @($runs | ForEach-Object { if ($_.Id -eq $copy.Id) { $copy } else { $_ } }); Armed = $Armed; Changed = $true }
}

function Get-StopwatchPhases {
    <# A run's laps as phases: each from the previous mark (the start, then each lap) to its own, and the last up to the end. #>
    param([Parameter(Mandatory = $true)][hashtable]$Run)
    $phases = @(); $from = $Run.Start
    foreach ($l in @($Run.Laps)) {
        $phases += @{ Name = $l.Name; Seconds = ($l.At - $from).TotalSeconds }
        $from = $l.At
    }
    if (@($Run.Laps).Count -and $Run.End) { $phases += @{ Name = 'Last stretch'; Seconds = ($Run.End - $from).TotalSeconds } }
    return $phases
}

function ConvertTo-StopwatchModel {
    <#
        What the page shows: the running run, if any, and the finished runs grouped by label (the groups in the
        order of their latest run, newest first; each group's runs newest first). Each finished run carries its
        Seconds and its DeltaSeconds against the run of the same label before it ($null for the first).
        -Armed (the stored armed label) is carried through for the page.
    #>
    param([AllowEmptyCollection()][object[]]$Runs = @(), [hashtable]$Armed = $null)
    $all = @($Runs | Where-Object { $_ } | Sort-Object { $_.Start })
    $running = @($all | Where-Object { -not $_.End }) | Select-Object -Last 1
    $groups = @()
    foreach ($g in @($all | Where-Object { $_.End } | Group-Object { $_.Label.ToLowerInvariant() })) {
        $prev = $null; $rows = @()
        foreach ($r in @($g.Group | Sort-Object { $_.Start })) {
            $sec = ($r.End - $r.Start).TotalSeconds
            $rows += @{ Run = $r; Seconds = $sec; DeltaSeconds = $(if ($null -ne $prev) { $sec - $prev } else { $null }); Phases = @(Get-StopwatchPhases -Run $r) }
            $prev = $sec
        }
        $best = ($rows | ForEach-Object { $_.Seconds } | Measure-Object -Minimum).Minimum
        [array]::Reverse($rows)
        $groups += @{ Label = $rows[0].Run.Label; Rows = $rows; Best = $best; Latest = $rows[0].Run.Start }
    }
    return @{
        Running = $running
        Armed   = $Armed
        Groups  = @($groups | Sort-Object { $_.Latest } -Descending)
        Labels  = @($groups | ForEach-Object { $_.Label } | Sort-Object)
        Count   = @($all | Where-Object { $_.End }).Count
    }
}

# THE TRANSCRIPT PHASES (#3315's second PR). A finished run's window is read back out of this machine's
# Claude Code session transcripts for this repo, and every second of it is given to exactly one phase: the
# first in this list that was going at that moment. So a ship that runs in the background while Claude
# writes is counted as the ship, and what is left when no session is busy is the time the work waited on a
# person. A Match is held to the COMMAND of a Bash or PowerShell call only, never to a whole serialised
# input: a subagent's brief or an edited file that names ship-pr.ps1 is not a ship (Victor, #3315).
$script:StopwatchToolPhases = @(
    @{ Name = 'Ship: CI wait, merge, fold'; Match = 'ship-pr\.ps1' },
    @{ Name = 'Local gates and tests'; Match = 'open-pr\.ps1|check-plugin-integrity\.ps1|\.tests\.ps1|test-suite-gate|check-[a-z-]+\.ps1' },
    @{ Name = 'Subagents'; Tool = '^(Agent|Task)$' },
    @{ Name = 'Branch and claim'; Match = 'new-branch\.ps1|claim-issue\.ps1|sync-main\.ps1|prune-merged\.ps1' },
    @{ Name = 'Other tool calls'; Tool = '.' }
)
$script:StopwatchShellTools = '^(Bash|PowerShell)$'
# What the harness answers when a call goes on in the background: a shell command sent there or moved there
# at its timeout, or an agent launched async. Held to those tools only, because a Read of a doc or an
# Artifact's answer can say "in the background" too, and such a call would then run to the end of the run.
$script:StopwatchBackgroundTools = '^(Bash|PowerShell|Agent|Task)$'
$script:StopwatchBackgroundText = '^\s*(Command running in background|Async agent launched)|was moved to the background'
$script:StopwatchBusyPhase = 'Claude thinking and writing'
$script:StopwatchIdlePhase = 'Waiting on you'

function Get-StopwatchTranscriptDir {
    <# Where Claude Code keeps this checkout's session transcripts: ~/.claude/projects/<root, every non-alphanumeric a dash>. #>
    param([Parameter(Mandatory = $true)][string]$RepoRoot)
    return (Join-Path $HOME ('.claude\projects\' + ($RepoRoot.TrimEnd('\', '/') -replace '[^A-Za-z0-9]', '-')))
}

function Get-StopwatchToolPhase {
    <# The phase one tool call belongs to: the first entry of $script:StopwatchToolPhases its name, or (a shell call) its command, matches. #>
    param([string]$Name, [AllowEmptyString()][string]$Command = '')
    $shell = $Name -match $script:StopwatchShellTools
    foreach ($p in $script:StopwatchToolPhases) {
        if ($p.Tool -and $Name -match $p.Tool) { return $p.Name }
        if ($p.Match -and $shell -and $Command -match $p.Match) { return $p.Name }
    }
    return $script:StopwatchToolPhases[-1].Name
}

function Read-StopwatchTranscriptEvents {
    <#
        What one transcript (-Path, a .jsonl) holds between -From and -To that the phases are made of: every
        turn's start (a typed prompt or a task notification), every tool call with its result and, for one that
        ran in the background, the notification that it finished, and the last moment each turn wrote anything.
        Returns @{ Turns = @(@{ Start; End }); Tools = @(@{ Phase; Start; End }) }, the times UTC.

        CHEAP ON PURPOSE: a transcript runs to tens of megabytes. A line's timestamp is read with a regex and
        compared as a string (ISO 8601 sorts as text), and only a user or assistant line inside the window is
        parsed as JSON. A line that is not JSON is skipped: a transcript being written is cut mid-line at its end.
        A tool or turn started up to an hour before -From is still read, so a ship started before Start is
        counted; a turn that started earlier still and is going at -From counts only from its next turn on.
    #>
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][datetime]$From, [Parameter(Mandatory = $true)][datetime]$To)
    $loText = Format-StopwatchStamp $From.AddHours(-1); $hiText = Format-StopwatchStamp $To
    $turns = New-Object System.Collections.ArrayList
    $calls = @{}; $results = @{}; $done = @{}
    $turn = $null
    foreach ($line in [IO.File]::ReadLines($Path)) {
        $m = [regex]::Match($line, '"timestamp":"([^"]+)"')
        if (-not $m.Success) { continue }
        $ts = $m.Groups[1].Value
        if ($ts -lt $loText -or $ts -gt $hiText) { continue }
        # A finished background call is announced twice: queued, then as the prompt of the turn it wakes. Only
        # those two records count, never a tool result that merely quotes one.
        if ($line.Contains('<task-notification>') -and ($line.StartsWith('{"type":"queue-operation"') -or $line.Contains('"content":"<task-notification>'))) {
            $n = [regex]::Match($line, '<tool-use-id>([^<]+)</tool-use-id>')
            if ($n.Success -and -not $done.ContainsKey($n.Groups[1].Value)) { $done[$n.Groups[1].Value] = $ts }
        }
        # A conversation record opens with its parentUuid; queue operations, snapshots and request blobs do not.
        if (-not $line.StartsWith('{"parentUuid"') -or $line.Contains('"isSidechain":true')) { continue }
        $isUser = $line.Contains('"type":"user"') -and -not $line.Contains('"isMeta":true')
        $isTool = $line.Contains('"type":"tool_use"')
        if ($isUser -or $isTool) {
            try { $rec = $line | ConvertFrom-Json } catch { $rec = $null }
            if ($rec -and $rec.message) {
                $content = $rec.message.content
                if ($rec.type -eq 'user') {
                    $isResult = $content -is [array] -and @($content | Where-Object { $_.type -eq 'tool_result' }).Count
                    if ($isResult) {
                        foreach ($c in @($content | Where-Object { $_.type -eq 'tool_result' })) {
                            $text = if ($c.content -is [string]) { $c.content } else { (@($c.content) | ForEach-Object { [string]$_.text }) -join "`n" }
                            $results[[string]$c.tool_use_id] = @{ At = $ts; Background = ($text -match $script:StopwatchBackgroundText) }
                        }
                    } else {
                        $turn = @{ Start = $ts; End = $ts }; [void]$turns.Add($turn)
                    }
                } elseif ($rec.type -eq 'assistant' -and $content -is [array]) {
                    foreach ($c in @($content | Where-Object { $_.type -eq 'tool_use' })) {
                        $name = [string]$c.name
                        $cmd = if ($name -match $script:StopwatchShellTools -and $c.input) { [string]$c.input.command } else { '' }
                        $calls[[string]$c.id] = @{ Start = $ts; Tool = $name; Phase = (Get-StopwatchToolPhase -Name $name -Command $cmd) }
                    }
                }
            }
        }
        if ($turn -and $ts -gt $turn.End) { $turn.End = $ts }
    }
    $tools = foreach ($id in $calls.Keys) {
        $c = $calls[$id]; $r = $results[$id]
        $background = $r -and $r.Background -and $c.Tool -match $script:StopwatchBackgroundTools
        # Still going at -To (no result yet, or a background run with no notification): it ran to the end.
        $end = if ($done.ContainsKey($id)) { $done[$id] } elseif ($r -and -not $background) { $r.At } else { $hiText }
        @{ Phase = $c.Phase; Start = (ConvertTo-StopwatchTime $c.Start); End = (ConvertTo-StopwatchTime $end) }
    }
    return @{
        Turns = @(foreach ($t in $turns) { @{ Start = (ConvertTo-StopwatchTime $t.Start); End = (ConvertTo-StopwatchTime $t.End) } })
        Tools = @($tools | Where-Object { $_ })
    }
}

function Get-StopwatchTranscriptPhases {
    <#
        A run's window from -From to -To split into phases, from the events of one or more transcripts
        (-Events, each what Read-StopwatchTranscriptEvents returns). Every second goes to the first phase
        going at that moment, in the order of $script:StopwatchToolPhases, then Claude's own turns, then
        waiting. Returns the phases with any time, in that order, as @{ Name; Seconds }, and Sessions: how many
        transcripts had a turn in the window. Pure.
    #>
    param([AllowEmptyCollection()][object[]]$Events = @(), [Parameter(Mandatory = $true)][datetime]$From, [Parameter(Mandatory = $true)][datetime]$To)
    $order = @($script:StopwatchToolPhases | ForEach-Object { $_.Name }) + @($script:StopwatchBusyPhase)
    $marks = New-Object System.Collections.ArrayList
    $add = { param($phase, $a, $b)
        if ($a -lt $From) { $a = $From }; if ($b -gt $To) { $b = $To }
        if ($b -gt $a) { [void]$marks.Add(@{ At = $a; Rank = $order.IndexOf($phase); Step = 1 }); [void]$marks.Add(@{ At = $b; Rank = $order.IndexOf($phase); Step = -1 }) } }
    $sessions = 0
    foreach ($ev in @($Events | Where-Object { $_ })) {
        $busy = $false
        foreach ($t in @($ev.Turns)) { if ($t.End -ge $From -and $t.Start -le $To) { $busy = $true }; & $add $script:StopwatchBusyPhase $t.Start $t.End }
        if ($busy) { $sessions++ }
        foreach ($t in @($ev.Tools | Where-Object { $_ })) { & $add $t.Phase $t.Start $t.End }
    }
    $seconds = @{}; $open = New-Object int[] ($order.Count)
    $at = $From
    foreach ($mk in @($marks | Sort-Object { $_.At }, { $_.Step })) {
        $span = ($mk.At - $at).TotalSeconds
        if ($span -gt 0) {
            $rank = -1; for ($i = 0; $i -lt $order.Count; $i++) { if ($open[$i] -gt 0) { $rank = $i; break } }
            $name = if ($rank -ge 0) { $order[$rank] } else { $script:StopwatchIdlePhase }
            $seconds[$name] = [double]$seconds[$name] + $span
        }
        $open[$mk.Rank] += $mk.Step; $at = $mk.At
    }
    $tail = ($To - $at).TotalSeconds
    if ($tail -gt 0) { $seconds[$script:StopwatchIdlePhase] = [double]$seconds[$script:StopwatchIdlePhase] + $tail }
    return @{
        Phases   = @(foreach ($n in @($order) + @($script:StopwatchIdlePhase)) { if ($seconds[$n] -gt 0) { @{ Name = $n; Seconds = $seconds[$n] } } })
        Sessions = $sessions
    }
}

function Get-StopwatchTranscriptCache {
    <#
        The transcript phases of every finished run in -Runs, by run id, read from the cache at -CachePath and
        computed for the runs it lacks from the transcripts in -TranscriptDir. A run's window is closed once it
        stops, so its phases never change and are read from the transcripts once; the cache is rewritten only
        when one was added. Like the store it lives outside the checkout. A cache that does not read is
        recomputed rather than trusted, and a write that fails costs only that read again on the next load.

        ONE PASS PER TRANSCRIPT, however many runs it lacks: each file is read once over the span from the
        earliest missing start to the latest missing end, and every run takes its own window out of those
        events (Sebastian and Victor, #3315). And nothing is cached unless a transcript was actually read, so a
        server started with the wrong -TranscriptDir does not file every run as "no session" for good.
    #>
    param([AllowEmptyCollection()][object[]]$Runs = @(), [Parameter(Mandatory = $true)][string]$CachePath, [Parameter(Mandatory = $true)][string]$TranscriptDir)
    $cache = @{}
    if (Test-Path -LiteralPath $CachePath -PathType Leaf) {
        try {
            $json = [System.IO.File]::ReadAllText($CachePath, (New-Object System.Text.UTF8Encoding($false))) | ConvertFrom-Json
            foreach ($p in @($json.PSObject.Properties)) {
                $cache[$p.Name] = @{ End = [string]$p.Value.end; Sessions = [int]$p.Value.sessions
                    Phases = @(foreach ($x in @($p.Value.phases)) { if ($x) { @{ Name = [string]$x.name; Seconds = [double]$x.seconds } } }) }
            }
        } catch { $cache = @{} }
    }
    $out = @{}; $missing = @()
    foreach ($r in @($Runs | Where-Object { $_ -and $_.End })) {
        if ($cache.ContainsKey($r.Id) -and $cache[$r.Id].End -eq (Format-StopwatchStamp $r.End)) { $out[$r.Id] = $cache[$r.Id] } else { $missing += $r }
    }
    if (-not $missing.Count) { return $out }
    $from = ($missing | ForEach-Object { $_.Start } | Measure-Object -Minimum).Minimum
    $to = ($missing | ForEach-Object { $_.End } | Measure-Object -Maximum).Maximum
    # A transcript last written before the earliest missing start holds nothing of any of them.
    $files = if (Test-Path -LiteralPath $TranscriptDir -PathType Container) { @(Get-ChildItem -LiteralPath $TranscriptDir -Filter *.jsonl -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTimeUtc -ge $from }) } else { @() }
    $events = @(foreach ($f in $files) { Read-StopwatchTranscriptEvents -Path $f.FullName -From $from -To $to })
    foreach ($r in $missing) {
        $p = Get-StopwatchTranscriptPhases -Events $events -From $r.Start -To $r.End
        $out[$r.Id] = @{ End = (Format-StopwatchStamp $r.End); Sessions = $p.Sessions; Phases = $p.Phases }
    }
    if ($files.Count) {
        $doc = [ordered]@{}
        foreach ($id in @($out.Keys | Sort-Object)) {
            $doc[$id] = [ordered]@{ end = $out[$id].End; sessions = $out[$id].Sessions; phases = @(foreach ($x in @($out[$id].Phases)) { [ordered]@{ name = $x.Name; seconds = [Math]::Round($x.Seconds, 3) } }) }
        }
        try {
            $dir = Split-Path -Parent $CachePath
            if (-not (Test-Path -LiteralPath $dir -PathType Container)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
            [System.IO.File]::WriteAllText("$CachePath.tmp", ($doc | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($false)))
            Move-Item -LiteralPath "$CachePath.tmp" -Destination $CachePath -Force
        } catch { }
    }
    return $out
}

function Format-StopwatchTranscriptCell {
    <# One run's transcript phases for the table: each phase with its time and share, or why there are none. #>
    param($Entry, [double]$Total)
    if ($null -eq $Entry) { return '<span class="note">--</span>' }
    if (-not $Entry.Sessions) { return '<span class="note">no session of this repo was active</span>' }
    $rows = @(foreach ($p in @($Entry.Phases)) {
            $share = if ($Total -gt 0) { [Math]::Round(100 * $p.Seconds / $Total) } else { 0 }
            (ConvertTo-DashboardText $p.Name) + ' <span class="num">' + (Format-DevSeconds $p.Seconds) + '</span> <span class="note">' + $share + '%</span>'
        })
    if ($Entry.Sessions -gt 1) { $rows += '<span class="note">' + $Entry.Sessions + ' sessions</span>' }
    return ($rows -join '<br>')
}

function Format-StopwatchDelta {
    <# Faster or slower than the run before, as a badge; nothing for a label's first run. #>
    param($Seconds)
    if ($null -eq $Seconds) { return '<span class="note">first run</span>' }
    if ([Math]::Abs([double]$Seconds) -lt 0.5) { return '<span class="badge badge--sm badge--neutral">same</span>' }
    if ($Seconds -lt 0) { return '<span class="badge badge--sm badge--good">' + (Format-DevSeconds (-[double]$Seconds)) + ' faster</span>' }
    return '<span class="badge badge--sm badge--bad">' + (Format-DevSeconds ([double]$Seconds)) + ' slower</span>'
}

function Format-StopwatchPageHtml {
    <#
        The page on '/stopwatch'. -ReadError is set when the store could not be read; then the buttons are off,
        since nothing may be written over it. -StorePath is named in the footer, so a run can be read and
        evaluated outside the page. -Transcript holds each finished run's transcript phases by run id
        (Get-StopwatchTranscriptCache); a run it lacks shows '--'.
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Model,
        [AllowEmptyString()][string]$ReadError = '',
        [int]$Skipped = 0,
        [AllowEmptyString()][string]$StorePath = '',
        [hashtable]$Transcript = @{},
        [datetime]$Now = [datetime]::UtcNow
    )
    $e = { param($v) ConvertTo-DashboardText $v }
    $off = if ($ReadError) { ' disabled' } else { '' }
    $local = { param($t) (& $e ($t.ToLocalTime().ToString('yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture))) }
    $body = New-Object System.Text.StringBuilder
    $last = if (@($Model.Groups).Count) { $Model.Groups[0].Rows[0] } else { $null }
    [void]$body.Append((Format-DevTiles @(
        @{ L = 'Runs recorded'; V = $Model.Count },
        @{ L = 'Labels'; V = @($Model.Labels).Count },
        @{ L = 'Last run'; V = (Format-DevSeconds $(if ($last) { $last.Seconds } else { $null })) },
        @{ L = 'Against the run before'; V = $(if (-not $last -or $null -eq $last.DeltaSeconds) { '--' } elseif ([Math]::Abs($last.DeltaSeconds) -lt 0.5) { 'same' }
                else { $(if ($last.DeltaSeconds -lt 0) { '-' } else { '+' }) + (Format-DevSeconds ([Math]::Abs($last.DeltaSeconds))) }) })))
    if ($ReadError) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">The store could not be read: ' + (& $e $ReadError) + '. Nothing is written over it until it reads again, so the buttons are off.</p>')
    }
    if ($Skipped) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">' + $Skipped + ' run(s) in the store could not be read and are not shown. The next button press writes the store without them.</p>')
    }
    [void]$body.AppendLine('<p class="msg msg--warn" role="alert" id="sw-error" hidden></p>')

    [void]$body.AppendLine('<div class="grid-2" id="now">')
    [void]$body.AppendLine('<div class="grid__head"><h2>Now</h2><p class="card__sub">Begin a prompt with stopwatch: and it starts there and stops when Claude is back on the trunk; or arm a label here, or start and stop by hand</p></div>')
    [void]$body.AppendLine('<section class="card grid__full">')
    $r = $Model.Running
    if ($r) {
        $startIso = Format-StopwatchStamp $r.Start
        [void]$body.AppendLine('<h3>' + (& $e $r.Label) + '</h3>')
        [void]$body.AppendLine('<p class="sw-clock num" data-start="' + $startIso + '">' + (Format-DevSeconds ($Now - $r.Start).TotalSeconds) + '</p>')
        [void]$body.AppendLine('<p class="note">Started ' + (& $local $r.Start) + '.' + $(if ($r.Auto) { ' <span class="badge badge--sm badge--info">auto</span> Stops by itself when Claude is back on the trunk, clean, with HEAD moved since the start.' }) + '</p>')
        if (@($r.Laps).Count) {
            [void]$body.AppendLine('<ol class="sw-laps">')
            foreach ($p in @(Get-StopwatchPhases -Run $r)) { [void]$body.AppendLine('<li>' + (& $e $p.Name) + ' <span class="num">' + (Format-DevSeconds $p.Seconds) + '</span></li>') }
            [void]$body.AppendLine('</ol>')
        }
        [void]$body.AppendLine('<form class="sw-form" data-action="lap"><label class="field"><span>Lap name (optional)</span><input name="name" maxlength="' + $script:StopwatchLabelMax + '" placeholder="e.g. PR opened" autocomplete="off"></label>')
        [void]$body.AppendLine('<div class="action-row"><button class="btn" type="submit"' + $off + '>Lap</button><button class="btn btn--primary" type="button" data-sw="stop"' + $off + '>Stop</button><button class="btn" type="button" data-sw="discard" data-confirm="Click again to discard"' + $off + '>Discard</button></div></form>')
    } else {
        [void]$body.AppendLine('<form class="sw-form" data-action="start"><label class="field"><span>Label</span><input name="label" list="sw-labels" maxlength="' + $script:StopwatchLabelMax + '" placeholder="e.g. CSS comment" required autocomplete="off"></label>')
        [void]$body.AppendLine('<datalist id="sw-labels">' + ((@($Model.Labels) | ForEach-Object { '<option value="' + (& $e $_) + '">' }) -join '') + '</datalist>')
        [void]$body.AppendLine('<div class="action-row"><button class="btn btn--primary" type="submit"' + $off + '>Start</button></div></form>')
        if ($Model.Armed) {
            [void]$body.AppendLine('<p class="msg" role="status">Armed: <strong>' + (& $e $Model.Armed.Label) + '</strong> -- starts on your next prompt to Claude. Armed ' + (& $local $Model.Armed.At) + '.</p>')
            [void]$body.AppendLine('<div class="action-row"><button class="btn" type="button" data-sw="disarm"' + $off + '>Disarm</button></div>')
        }
        [void]$body.AppendLine('<form class="sw-form" data-action="arm"><label class="field"><span>Arm a label</span><input name="label" list="sw-labels" maxlength="' + $script:StopwatchLabelMax + '" placeholder="e.g. CSS comment" required autocomplete="off"></label>')
        [void]$body.AppendLine('<div class="action-row"><button class="btn" type="submit"' + $off + '>Arm</button></div></form>')
    }
    [void]$body.AppendLine('</section>')
    [void]$body.AppendLine('</div>')

    foreach ($g in @($Model.Groups)) {
        [void]$body.AppendLine('<div class="grid-2">')
        [void]$body.AppendLine('<div class="grid__head"><h2>' + (& $e $g.Label) + '</h2><p class="card__sub">' + @($g.Rows).Count + ' run(s), best ' + (Format-DevSeconds $g.Best) + ', newest first</p></div>')
        [void]$body.AppendLine('<section class="card grid__full"><div class="table-wrap"><table class="table"><thead><tr><th class="sw-left">Started</th><th>Time</th><th>Against the run before</th><th class="sw-left">Laps</th><th class="sw-left">From the transcripts</th><th class="sw-left">What to improve next time</th></tr></thead><tbody>')
        foreach ($row in @($g.Rows)) {
            $phases = if (@($row.Phases).Count) { (@($row.Phases) | ForEach-Object { (& $e $_.Name) + ' <span class="num">' + (Format-DevSeconds $_.Seconds) + '</span>' }) -join '<br>' } else { '<span class="note">--</span>' }
            $id = & $e $row.Run.Id
            [void]$body.AppendLine('<tr><td class="sw-left">' + (& $local $row.Run.Start) + $(if ($row.Run.Auto) { ' <span class="badge badge--sm badge--info">auto</span>' }) + '</td><td class="num">' + (Format-DevSeconds $row.Seconds) + '</td><td>' + (Format-StopwatchDelta $row.DeltaSeconds) + '</td><td class="sw-left">' + $phases + '</td><td class="sw-left">' + (Format-StopwatchTranscriptCell $Transcript[$row.Run.Id] $row.Seconds) + '</td>' +
                '<td class="sw-left"><form class="sw-form sw-note" data-action="note"><input type="hidden" name="id" value="' + $id + '"><textarea name="text" rows="2" maxlength="' + $script:StopwatchNoteMax + '" aria-label="What to improve next time">' + (& $e $row.Run.Note) + '</textarea>' +
                '<div class="action-row"><button class="btn" type="submit"' + $off + '>Save note</button><button class="btn" type="button" data-sw="delete" data-id="' + $id + '" data-confirm="Click again to delete"' + $off + '>Delete</button></div></form></td></tr>')
        }
        [void]$body.AppendLine('</tbody></table></div></section>')
        [void]$body.AppendLine('</div>')
    }
    if (-not @($Model.Groups).Count) {
        [void]$body.AppendLine('<p class="note">No finished run yet. The first one sets the baseline for its label.</p>')
    }

    # The page's own layer: house tokens only, and the class names are the page's (sw-), never a house class restyled.
    $style = '.sw-clock { font-size: var(--text-h1); font-weight: 600; margin: var(--spacing-2) 0; }' + "`n" +
        '.sw-laps { margin: 0 0 var(--spacing-3-5); }' + "`n" +
        '.sw-left { text-align: left; }' + "`n" +
        '.sw-note textarea { display: block; width: 100%; min-width: 14rem; font: inherit; padding: var(--spacing-2); border: 1px solid var(--paper-3); border-radius: 8px; background: var(--paper-1); color: var(--fg-1); margin-bottom: var(--spacing-2); }'
    # Every press is a POST to /stopwatch/<action> with its values in the query; the page reloads on success.
    $script = @'
<script>(function () {
  // Format-DevSeconds' own form: one decimal under a minute, then m:ss, then h:mm:ss.
  function fmt(s) { s = Math.max(0, s); if (s < 59.95) return s.toFixed(1) + "s"; s = Math.round(s);
    var h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), x = s % 60;
    function p(n) { return (n < 10 ? "0" : "") + n; } return h ? h + ":" + p(m) + ":" + p(x) : m + ":" + p(x); }
  var clock = document.querySelector(".sw-clock[data-start]");
  if (clock) { var t0 = Date.parse(clock.getAttribute("data-start")); setInterval(function () { clock.textContent = fmt((Date.now() - t0) / 1000); }, 250); }
  var err = document.getElementById("sw-error");
  function send(action, values) {
    var q = Object.keys(values).map(function (k) { return encodeURIComponent(k) + "=" + encodeURIComponent(values[k]); }).join("&");
    // The values travel in the request head, which the server reads up to 8 KB.
    if (q.length > 7000) { err.textContent = "That is too long to send: shorten the note."; err.hidden = false; return; }
    fetch("/stopwatch/" + action + (q ? "?" + q : ""), { method: "POST" }).then(function (r) {
      if (r.ok) { location.reload(); return; }
      return r.text().then(function (t) { err.textContent = t || ("The server answered " + r.status + "."); err.hidden = false; });
    }, function () { err.textContent = "The server did not answer. Reload the page and press again."; err.hidden = false; });
  }
  document.addEventListener("submit", function (ev) {
    var f = ev.target.closest(".sw-form"); if (!f) return; ev.preventDefault();
    var v = {}; Array.prototype.forEach.call(f.elements, function (el) { if (el.name) v[el.name] = el.value; });
    send(f.getAttribute("data-action"), v);
  });
  document.addEventListener("click", function (ev) {
    var b = ev.target.closest("[data-sw]"); if (!b) return;
    var c = b.getAttribute("data-confirm");
    if (c && !b.hasAttribute("data-armed")) { b.setAttribute("data-armed", ""); b.setAttribute("data-label", b.textContent); b.textContent = c;
      setTimeout(function () { b.removeAttribute("data-armed"); b.textContent = b.getAttribute("data-label"); }, 3000); return; }
    var v = {}; if (b.hasAttribute("data-id")) v.id = b.getAttribute("data-id");
    send(b.getAttribute("data-sw"), v);
  });
})();</script>
'@
    $note = 'Kept on this machine in <code>' + (& $e $StorePath) + '</code>, outside the checkout, so a run never dirties the tree it is timing. ' +
        'A prompt whose first line begins with <code>stopwatch:</code> starts a run, labelled with the rest of that line, and an armed label starts one on the next prompt; either of a session in this checkout starts it, and it stops once Claude is back on the trunk, clean, with HEAD moved since the start (that suggests the work landed; it does not prove it) (<code>scripts/dashboard/stopwatch-hook.ps1</code>); a run started by hand is never stopped by a hook. ' +
        'The transcript column splits a run into phases read from this repo''s Claude Code session transcripts once a run has stopped: each second goes to the first phase going at that moment, ' +
        'so a ship running in the background counts as the ship, and a second in which no session was busy is time spent waiting on you. Built by <code>scripts/lib/stopwatch-lib.ps1</code>.'
    return Format-DevPageHtml -Title 'Stopwatch' -Style $style -Body ($body.ToString() + $script) `
        -Lead 'How long an assignment takes, from the moment it is given to the moment it is done. Give each run a label (begin a prompt with stopwatch: to start it from the terminal, arm it here, or start it yourself), mark its steps with Lap, and note after each run what to improve, so the next run of the same label is shorter.' `
        -FooterNote $note
}
