<#
.SYNOPSIS
    The Stopwatch page of this repo's dev server (#3315): time an assignment from the moment it is given to
    the moment it is done, by hand, and compare each run with the previous run of the same label, so the
    slow steps of the workflow show and every next run can be made shorter.

.DESCRIPTION
    THE CLOCK IS THE SERVER'S, NOT THE PAGE'S. Start, Lap and Stop each write a timestamp to the store,
    and the page only draws the time since the stored start. The hub restarts itself whenever the checkout's
    HEAD moves (#3122), and the workflow a run measures moves HEAD at every branch switch, merge and fold,
    so a clock kept in the page would be lost halfway through the very run it is timing.

    THE STORE IS OUTSIDE THE TREE: %LOCALAPPDATA%\dkj-claude-plugins\stopwatch.json (Get-StopwatchStorePath).
    A file in the checkout would dirty it in the middle of the workflow being measured, and the scripts
    that ship a branch refuse a dirty tree. So the runs are this machine's, like the session transcripts that the
    transcript phases of #3315's second PR will read.

    A STORE THAT DOES NOT READ IS NEVER WRITTEN OVER. Read-StopwatchStore returns an Error for a file that
    is not valid JSON, and every write refuses while it is set, so one bad edit by hand loses nothing.

    Pure except Read-StopwatchStore and Save-StopwatchStore, which touch only the store's own file. Every
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
    return @{ Id = $id; Label = $label.Trim(); Start = $start; End = (ConvertTo-StopwatchTime $Raw.end); Laps = $laps; Note = [string]$Raw.note }
}

function Read-StopwatchStore {
    <#
        The runs in the store at -Path, oldest first, and an Error that is empty when it read. A missing file is
        an empty store, not an error. A run that does not parse is skipped and counted in Skipped.
    #>
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @{ Runs = @(); Error = ''; Skipped = 0 } }
    try {
        $text = [System.IO.File]::ReadAllText($Path, (New-Object System.Text.UTF8Encoding($false)))
        $json = if ($text.Trim()) { $text | ConvertFrom-Json } else { $null }
    } catch {
        return @{ Runs = @(); Error = 'it is not valid JSON'; Skipped = 0 }
    }
    $runs = @(); $skipped = 0
    foreach ($r in @($(if ($json) { $json.runs } else { @() }))) {
        if ($null -eq $r) { continue }
        $run = ConvertTo-StopwatchRun $r
        if ($run) { $runs += $run } else { $skipped++ }
    }
    return @{ Runs = @($runs | Sort-Object { $_.Start }); Error = ''; Skipped = $skipped }
}

function Save-StopwatchStore {
    <# Writes -Runs to -Path through a file beside it, so a failed write never leaves half a store. #>
    param([Parameter(Mandatory = $true)][string]$Path, [AllowEmptyCollection()][object[]]$Runs = @())
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
                }
            }) }
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

function Invoke-StopwatchAction {
    <#
        One button press against -Runs: start, lap, stop, discard (the running run), note or delete (a finished
        run, by -Id). Returns the new runs and an Error; on an error the runs come back unchanged. -Now is the
        server's clock, passed in so every rule is tested without one.
    #>
    param(
        [AllowEmptyCollection()][object[]]$Runs = @(),
        [Parameter(Mandatory = $true)][string]$Action,
        [hashtable]$Query = @{},
        [Parameter(Mandatory = $true)][datetime]$Now
    )
    $runs = @($Runs | Where-Object { $_ })
    $running = @($runs | Where-Object { -not $_.End }) | Select-Object -Last 1
    $fail = { param($m) return @{ Runs = $runs; Error = $m } }
    # A control character becomes a space; -Lines keeps a note's line breaks and tabs (Victor, #3315).
    $text = { param($k, $max, [switch]$Lines) $cc = if ($Lines) { '[\x00-\x08\x0b-\x1f\x7f]' } else { '[\x00-\x1f\x7f]' }
        $v = ([string]$Query[$k] -replace "`r`n", "`n") -replace $cc, ' '; $v = $v.Trim(); if ($v.Length -gt $max) { $v = $v.Substring(0, $max) }; $v }
    $now = $Now.ToUniversalTime()
    switch ($Action) {
        'start' {
            if ($running) { return (& $fail "A run is already going: '$($running.Label)'. Stop or discard it first.") }
            $label = & $text 'label' $script:StopwatchLabelMax
            if (-not $label) { return (& $fail 'A run needs a label, such as "CSS comment".') }
            $id = $now.ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture) + '-' + ([guid]::NewGuid().ToString('N').Substring(0, 4))
            return @{ Runs = @($runs + @(@{ Id = $id; Label = $label; Start = $now; End = $null; Laps = @(); Note = '' })); Error = '' }
        }
        { $_ -in 'lap', 'stop', 'discard' } {
            if (-not $running) { return (& $fail 'No run is going.') }
            if ($Action -eq 'discard') { return @{ Runs = @($runs | Where-Object { $_.Id -ne $running.Id }); Error = '' } }
            $copy = $running.Clone()
            if ($Action -eq 'lap') {
                if (@($copy.Laps).Count -ge $script:StopwatchLapMax) { return (& $fail "A run holds at most $($script:StopwatchLapMax) laps.") }
                $name = & $text 'name' $script:StopwatchLabelMax
                if (-not $name) { $name = 'Lap ' + (@($copy.Laps).Count + 1) }
                $copy.Laps = @(@($copy.Laps) + @(@{ Name = $name; At = $now }))
            } else {
                $copy.End = $now
            }
            return @{ Runs = @($runs | ForEach-Object { if ($_.Id -eq $copy.Id) { $copy } else { $_ } }); Error = '' }
        }
        { $_ -in 'note', 'delete' } {
            $id = [string]$Query['id']
            $target = @($runs | Where-Object { $_.Id -ceq $id -and $_.End }) | Select-Object -First 1
            if (-not $target) { return (& $fail 'That run is not in the store, or it is still going.') }
            if ($Action -eq 'delete') { return @{ Runs = @($runs | Where-Object { $_.Id -cne $id }); Error = '' } }
            $copy = $target.Clone()
            $copy.Note = & $text 'text' $script:StopwatchNoteMax -Lines
            return @{ Runs = @($runs | ForEach-Object { if ($_.Id -ceq $id) { $copy } else { $_ } }); Error = '' }
        }
        default { return (& $fail "Unknown action '$Action'.") }
    }
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
    #>
    param([AllowEmptyCollection()][object[]]$Runs = @())
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
        Groups  = @($groups | Sort-Object { $_.Latest } -Descending)
        Labels  = @($groups | ForEach-Object { $_.Label } | Sort-Object)
        Count   = @($all | Where-Object { $_.End }).Count
    }
}

# THE TRANSCRIPT PHASES (#3315's second PR). A finished run's window is read back out of this machine's
# Claude Code session transcripts for this repo, and every second of it is given to exactly one phase: the
# first in this list that was going at that moment. So a ship that runs in the background while Claude
# writes is counted as the ship, and what is left when no session is busy is the time the work waited on a
# person. Each tool call is matched on its name and its serialised input, the way measure-closeouts.ps1
# matches a chain-ending script, so a script run from Bash, from PowerShell or inside a skill counts alike.
$script:StopwatchToolPhases = @(
    @{ Name = 'Ship: CI wait, merge, fold'; Match = 'ship-pr\.ps1' },
    @{ Name = 'Local gates and tests'; Match = 'open-pr\.ps1|check-plugin-integrity\.ps1|\.tests\.ps1|test-suite-gate|check-[a-z-]+\.ps1' },
    @{ Name = 'Subagents'; Tool = '^(Agent|Task)$' },
    @{ Name = 'Branch and claim'; Match = 'new-branch\.ps1|claim-issue\.ps1|sync-main\.ps1|prune-merged\.ps1' },
    @{ Name = 'Other tool calls'; Tool = '.' }
)
$script:StopwatchBusyPhase = 'Claude thinking and writing'
$script:StopwatchIdlePhase = 'Waiting on you'

function Get-StopwatchTranscriptDir {
    <# Where Claude Code keeps this checkout's session transcripts: ~/.claude/projects/<root, every non-alphanumeric a dash>. #>
    param([Parameter(Mandatory = $true)][string]$RepoRoot)
    return (Join-Path $HOME ('.claude\projects\' + ($RepoRoot.TrimEnd('\', '/') -replace '[^A-Za-z0-9]', '-')))
}

function Get-StopwatchToolPhase {
    <# The phase one tool call belongs to: the first entry of $script:StopwatchToolPhases its name or input matches. #>
    param([string]$Name, [string]$Serialized)
    foreach ($p in $script:StopwatchToolPhases) {
        if ($p.Tool -and $Name -match $p.Tool) { return $p.Name }
        if ($p.Match -and $Serialized -match $p.Match) { return $p.Name }
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
        A tool started up to an hour before -From is still read, so a ship started before Start is counted.
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
        if ($line.Contains('<task-notification>')) {
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
                            $results[[string]$c.tool_use_id] = @{ At = $ts; Background = ($text -match 'running in background|in the background|Async agent launched') }
                        }
                    } else {
                        $turn = @{ Start = $ts; End = $ts }; [void]$turns.Add($turn)
                    }
                } elseif ($rec.type -eq 'assistant' -and $content -is [array]) {
                    foreach ($c in @($content | Where-Object { $_.type -eq 'tool_use' })) {
                        $in = ''; try { $in = $c.input | ConvertTo-Json -Depth 6 -Compress } catch { $in = '' }
                        $calls[[string]$c.id] = @{ Start = $ts; Phase = (Get-StopwatchToolPhase -Name ([string]$c.name) -Serialized $in) }
                    }
                }
            }
        }
        if ($turn -and $ts -gt $turn.End) { $turn.End = $ts }
    }
    $tools = foreach ($id in $calls.Keys) {
        $c = $calls[$id]; $r = $results[$id]
        # Still going at -To (no result yet, or a background run with no notification): it ran to the end.
        $end = if ($done.ContainsKey($id)) { $done[$id] } elseif ($r -and -not $r.Background) { $r.At } else { $hiText }
        if ($end) { @{ Phase = $c.Phase; Start = (ConvertTo-StopwatchTime $c.Start); End = (ConvertTo-StopwatchTime $end) } }
    }
    return @{
        Turns = @(foreach ($t in $turns) { @{ Start = (ConvertTo-StopwatchTime $t.Start); End = (ConvertTo-StopwatchTime $t.End) } })
        Tools = @($tools)
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
        recomputed rather than trusted.
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
    $files = if (Test-Path -LiteralPath $TranscriptDir -PathType Container) { @(Get-ChildItem -LiteralPath $TranscriptDir -Filter *.jsonl -File -ErrorAction SilentlyContinue) } else { @() }
    $out = @{}; $added = $false
    foreach ($r in @($Runs | Where-Object { $_ -and $_.End })) {
        $end = Format-StopwatchStamp $r.End
        if ($cache.ContainsKey($r.Id) -and $cache[$r.Id].End -eq $end) { $out[$r.Id] = $cache[$r.Id]; continue }
        # A transcript last written before the run started holds nothing of it.
        $events = @(foreach ($f in $files) { if ($f.LastWriteTimeUtc -ge $r.Start) { Read-StopwatchTranscriptEvents -Path $f.FullName -From $r.Start -To $r.End } })
        $p = Get-StopwatchTranscriptPhases -Events $events -From $r.Start -To $r.End
        $out[$r.Id] = @{ End = $end; Sessions = $p.Sessions; Phases = $p.Phases }
        $added = $true
    }
    if ($added) {
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
        (Get-StopwatchTranscriptCache); a run it lacks shows none.
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
    [void]$body.AppendLine('<div class="grid__head"><h2>Now</h2><p class="card__sub">Start when you give the assignment, stop when it is done</p></div>')
    [void]$body.AppendLine('<section class="card grid__full">')
    $r = $Model.Running
    if ($r) {
        $startIso = Format-StopwatchStamp $r.Start
        [void]$body.AppendLine('<h3>' + (& $e $r.Label) + '</h3>')
        [void]$body.AppendLine('<p class="sw-clock num" data-start="' + $startIso + '">' + (Format-DevSeconds ($Now - $r.Start).TotalSeconds) + '</p>')
        [void]$body.AppendLine('<p class="note">Started ' + (& $local $r.Start) + '.</p>')
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
    }
    [void]$body.AppendLine('</section>')
    [void]$body.AppendLine('</div>')

    foreach ($g in @($Model.Groups)) {
        [void]$body.AppendLine('<div class="grid-2">')
        [void]$body.AppendLine('<div class="grid__head"><h2>' + (& $e $g.Label) + '</h2><p class="card__sub">' + @($g.Rows).Count + ' run(s), best ' + (Format-DevSeconds $g.Best) + ', newest first</p></div>')
        [void]$body.AppendLine('<section class="card grid__full"><div class="table-wrap"><table class="table"><thead><tr><th class="sw-left">Started</th><th>Time</th><th>Against the run before</th><th class="sw-left">Phases</th><th class="sw-left">From the transcripts</th><th class="sw-left">What to improve next time</th></tr></thead><tbody>')
        foreach ($row in @($g.Rows)) {
            $phases = if (@($row.Phases).Count) { (@($row.Phases) | ForEach-Object { (& $e $_.Name) + ' <span class="num">' + (Format-DevSeconds $_.Seconds) + '</span>' }) -join '<br>' } else { '<span class="note">--</span>' }
            $id = & $e $row.Run.Id
            [void]$body.AppendLine('<tr><td class="sw-left">' + (& $local $row.Run.Start) + '</td><td class="num">' + (Format-DevSeconds $row.Seconds) + '</td><td>' + (Format-StopwatchDelta $row.DeltaSeconds) + '</td><td class="sw-left">' + $phases + '</td><td class="sw-left">' + (Format-StopwatchTranscriptCell $Transcript[$row.Run.Id] $row.Seconds) + '</td>' +
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
        'The transcript phases are read from this repo''s Claude Code session transcripts once a run has stopped: each second goes to the first phase going at that moment, ' +
        'so a ship running in the background counts as the ship, and a second in which no session was busy is time spent waiting on you. Built by <code>scripts/lib/stopwatch-lib.ps1</code>.'
    return Format-DevPageHtml -Title 'Stopwatch' -Style $style -Body ($body.ToString() + $script) `
        -Lead 'How long an assignment takes, from the moment it is given to the moment it is done. Give each run a label, mark the phases with Lap, and note after each run what to improve, so the next run of the same label is shorter.' `
        -FooterNote $note
}
