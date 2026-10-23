<#
.SYNOPSIS
    The Stopwatch page of this repo's dev server (#3315, #3323): a read-only view of how long each assignment took,
    from the prompt that gave it to the moment Claude was back on the trunk, with each run compared against the
    previous run of the same label, so the slow steps of the workflow show and every next run can be made shorter.

.DESCRIPTION
    THE PAGE ONLY SHOWS. It has no button and the server takes no POST for it. The runs are written by two Claude
    Code hooks, scripts/dashboard/stopwatch-hook.ps1, which call Invoke-StopwatchHookEvent here:

      - A prompt whose first line begins with `stopwatch:` (any case, leading whitespace allowed) starts an Auto
        run at once, labelled with the rest of that line (Get-StopwatchPromptMarker; "Assignment" when empty),
        with the checkout's HEAD as its StartHead. It is the only way a run starts. A run still going when a
        marked prompt arrives is DISCARDED and the new one starts: a run that never reached the trunk would
        otherwise block every later measurement, and the page has no button left to discard it.
      - A Stop hook ends the running run once the checkout is on the trunk, clean, with HEAD moved off StartHead.
        That is a sign the work landed, not a proof of it. The HEAD test is the reason no branch needs to be seen:
        a whole ship (branch, PR, merge, fold) usually happens inside one turn, and the Stop hook fires only at a
        turn's end. A turn that only answers leaves HEAD where it was, and a branch parked for the owner's eye is
        not on the trunk, so the run keeps going in both.

    TWO PAGES, BOTH READ-ONLY AND BARE (no h1, lead, tiles or the hub's airsquats banner above their content; the
    plugin's Format-GeneralPageHtml -Bare). '/stopwatch' is an overview of cards, one per measurement label (the label's number
    of runs, its latest run's time and change against the run before, and the run going now with its live clock),
    in the hub's own card markup; each card links to '/stopwatch/<slug>', the label's page: every run, newest
    first, with its start, time and change, and below them a card per run with its transcript phases. A slug is made of the label alone
    (Get-StopwatchSlugs); two labels that would share one each get a hash suffix, so they never merge, and an
    unknown slug is a 404.

    THE CLOCK IS THE HOOKS', NOT THE PAGE'S. A run is a start stamp and an end stamp in the store, and the page
    only draws the time since the stored start. The hub restarts itself whenever the checkout's HEAD moves
    (#3122), and the workflow a run measures moves HEAD at every branch switch, merge and fold, so a clock kept in
    the page would be lost halfway through the very run it is timing.

    THE STORE IS OUTSIDE THE TREE: %LOCALAPPDATA%\dkj-claude-plugins\stopwatch.json (Get-StopwatchStorePath).
    A file in the checkout would dirty it in the middle of the workflow being measured, and the scripts
    that ship a branch refuse a dirty tree. So the runs are this machine's, like the session transcripts the
    transcript phases read (below).

    OLD STORES STILL READ. Earlier versions of the page also kept laps, notes and an armed label, written by
    buttons that are gone. A field this file does not know is ignored on read and is not written back, so the
    first hook write after the upgrade drops it; an old hand-started run shows as a plain row. A running hub must
    be restarted to pick up this code: an old server would write the old shape back.

    A STORE THAT DOES NOT READ IS NEVER WRITTEN OVER. Read-StopwatchStore returns an Error for a file that
    is not valid JSON, and the hook refuses to write while it is set, so one bad edit by hand loses nothing.

    Pure except Read-StopwatchStore and Save-StopwatchStore (the store's own file), Read-StopwatchTranscriptEvents
    (one session transcript, read only) and Get-StopwatchTranscriptCache (the transcripts, and stopwatch-phases.json
    beside the store). Every
    value that reaches the page is escaped through ConvertTo-DashboardText. Pure ASCII (repo convention for
    .ps1). Tested by scripts/tests/stopwatch.tests.ps1.
#>

$script:StopwatchLabelMax = 80

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
    return @{ Id = $id; Label = $label.Trim(); Start = $start; End = (ConvertTo-StopwatchTime $Raw.end); Auto = [bool]$Raw.auto; StartHead = [string]$Raw.startHead }
}

function Read-StopwatchStore {
    <#
        The runs in the store at -Path, oldest first, and an Error that is empty when it read. A missing file is
        an empty store, not an error. A run that does not parse is skipped and counted in Skipped; a field of an
        older version (laps, notes, an armed label) is ignored.
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
                    id        = $r.Id
                    label     = $r.Label
                    start     = (Format-StopwatchStamp $r.Start)
                    end       = $(if ($r.End) { Format-StopwatchStamp $r.End } else { $null })
                    auto      = [bool]$r.Auto
                    startHead = [string]$r.StartHead
                }
            }) }
    $tmp = "$Path.tmp"
    [System.IO.File]::WriteAllText($tmp, ($out | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function New-StopwatchRunId {
    <# A run's id: the start time plus four hex. #>
    param([Parameter(Mandatory = $true)][datetime]$Now)
    return $Now.ToUniversalTime().ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture) + '-' + ([guid]::NewGuid().ToString('N').Substring(0, 4))
}

function New-StopwatchRun {
    <# A run that starts now, started by a hook (Auto) at the checkout's HEAD, -StartHead (#3323). #>
    param([Parameter(Mandatory = $true)][string]$Label, [Parameter(Mandatory = $true)][datetime]$Now, [string]$StartHead = '')
    return @{ Id = (New-StopwatchRunId -Now $Now); Label = $Label; Start = $Now.ToUniversalTime(); End = $null; Auto = $true; StartHead = $StartHead }
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
        -Hook Prompt: a -Prompt marked `stopwatch:` (Get-StopwatchPromptMarker) starts a run at -Now under its
        label with -Head as its StartHead, and DISCARDS a run still going (it would otherwise block every later
        measurement); any other prompt does nothing, and so does a marked one with an empty -Head, since a run
        without a StartHead could never stop by itself. -Hook Stop: the running run ends at -Now only when it is
        Auto, -Branch is -Trunk, -Clean (git status --porcelain was empty) and -Head is not the run's StartHead,
        taken as work that landed (it proves HEAD moved, not that anything was merged); otherwise nothing.
        Returns Runs and Changed (write only when set).
    #>
    param(
        [Parameter(Mandatory = $true)][ValidateSet('Prompt', 'Stop')][string]$Hook,
        [AllowEmptyCollection()][object[]]$Runs = @(),
        [Parameter(Mandatory = $true)][datetime]$Now,
        [string]$Branch = '',
        [bool]$Clean = $false,
        [string]$Head = '',
        [string]$Trunk = 'main',
        [AllowEmptyString()][string]$Prompt = ''
    )
    $runs = @($Runs | Where-Object { $_ })
    $running = @($runs | Where-Object { -not $_.End }) | Select-Object -Last 1
    $same = @{ Runs = $runs; Changed = $false }
    if ($Hook -eq 'Prompt') {
        $label = Get-StopwatchPromptMarker -Prompt $Prompt
        if ($null -eq $label -or -not $Head) { return $same }
        $kept = @($runs | Where-Object { $_.End })
        return @{ Runs = @($kept + @(New-StopwatchRun -Label $label -Now $Now -StartHead $Head)); Changed = $true }
    }
    if (-not $running -or -not $running.Auto -or -not $running.StartHead) { return $same }
    if ($Branch -cne $Trunk -or -not $Clean -or -not $Head -or $Head -ceq $running.StartHead) { return $same }
    $copy = $running.Clone(); $copy.End = $Now.ToUniversalTime()
    return @{ Runs = @($runs | ForEach-Object { if ($_.Id -eq $copy.Id) { $copy } else { $_ } }); Changed = $true }
}

function Get-StopwatchSlugs {
    <#
        The URL slug of each label in -Labels, as a hashtable from the label lower-cased (labels group
        case-insensitively) to its slug (#3323). A slug is the label's lower-case letters and digits with every other
        run turned into one dash, cut at 40 characters, and 'run' for a label with none. Two labels that give the
        same slug are never merged: each of them takes a suffix, the first hex digits of the SHA-1 of its
        lower-cased label, as many as it takes for every slug to differ. So a slug depends only on the label and on
        whether another label shares its base, never on the order the runs came in.
    #>
    param([AllowEmptyCollection()][string[]]$Labels = @())
    $keys = @($Labels | Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() } | Sort-Object -Unique)
    $base = @{}
    foreach ($k in $keys) {
        $b = ($k -replace '[^a-z0-9]+', '-').Trim('-')
        if ($b.Length -gt 40) { $b = $b.Substring(0, 40).Trim('-') }
        if (-not $b) { $b = 'run' }
        $base[$k] = $b
    }
    $count = @{}
    foreach ($b in $base.Values) { $count[$b] = 1 + [int]$count[$b] }
    $sha = [Security.Cryptography.SHA1]::Create()
    $hex = @{}
    foreach ($k in $keys) { $hex[$k] = (($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($k)) | ForEach-Object { $_.ToString('x2') }) -join '') }
    $slugs = @{}
    for ($len = 6; $len -le 40; $len += 2) {
        foreach ($k in $keys) { $slugs[$k] = $(if ($count[$base[$k]] -gt 1) { $base[$k] + '-' + $hex[$k].Substring(0, $len) } else { $base[$k] }) }
        if (@($slugs.Values | Sort-Object -Unique).Count -eq $keys.Count) { break }
    }
    return $slugs
}

function ConvertTo-StopwatchModel {
    <#
        What the pages show: the running run, if any, and the labels as Groups (newest activity first), one per
        label compared case-insensitively. A group carries its Label, its Slug (Get-StopwatchSlugs), its finished
        runs as Rows (newest first; each with Seconds and its DeltaSeconds against the run of the same label before
        it, $null for the first), Best, Latest (the start of its newest run, going or not) and Running: the run
        going now when it is this label's, else $null. A label whose only run is still going is a group with no Rows.
    #>
    param([AllowEmptyCollection()][object[]]$Runs = @())
    $all = @($Runs | Where-Object { $_ } | Sort-Object { $_.Start })
    $running = @($all | Where-Object { -not $_.End }) | Select-Object -Last 1
    $slugs = Get-StopwatchSlugs -Labels @($all | ForEach-Object { $_.Label })
    $groups = @()
    foreach ($g in @($all | Group-Object { $_.Label.ToLowerInvariant() })) {
        $prev = $null; $rows = @()
        foreach ($r in @($g.Group | Where-Object { $_.End } | Sort-Object { $_.Start })) {
            $sec = ($r.End - $r.Start).TotalSeconds
            $rows += @{ Run = $r; Seconds = $sec; DeltaSeconds = $(if ($null -ne $prev) { $sec - $prev } else { $null }) }
            $prev = $sec
        }
        $best = if ($rows.Count) { ($rows | ForEach-Object { $_.Seconds } | Measure-Object -Minimum).Minimum } else { $null }
        [array]::Reverse($rows)
        $newest = @($g.Group | Sort-Object { $_.Start })[-1]
        $groups += @{ Label = $newest.Label; Slug = $slugs[$g.Name]; Rows = $rows; Best = $best; Latest = $newest.Start
            Running = $(if ($running -and $running.Id -eq (@($g.Group | Where-Object { -not $_.End }) | Select-Object -Last 1).Id) { $running } else { $null }) }
    }
    return @{
        Running = $running
        Groups  = @($groups | Sort-Object { $_.Latest } -Descending)
        Count   = @($all | Where-Object { $_.End }).Count
    }
}

function Find-StopwatchGroup {
    <# The group of -Model whose Slug is -Slug, or $null: the label page's lookup, so an unknown slug is a 404. #>
    param([Parameter(Mandatory = $true)][hashtable]$Model, [AllowEmptyString()][string]$Slug = '')
    return (@($Model.Groups | Where-Object { $_.Slug -ceq $Slug }) | Select-Object -First 1)
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
        # The file is written whole, so every entry it was loaded with is carried over, not only the runs asked for
        # now: the label pages ask for one label's runs at a time, and one label's visit must not wipe another's.
        $keep = @{}
        foreach ($id in $cache.Keys) { $keep[$id] = $cache[$id] }
        foreach ($id in $out.Keys) { $keep[$id] = $out[$id] }
        foreach ($id in @($keep.Keys | Sort-Object)) {
            $doc[$id] = [ordered]@{ end = $keep[$id].End; sessions = $keep[$id].Sessions; phases = @(foreach ($x in @($keep[$id].Phases)) { [ordered]@{ name = $x.Name; seconds = [Math]::Round($x.Seconds, 3) } }) }
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

function Format-StopwatchPhaseCard {
    <#
        One run's transcript phases as a card of their own: a heading with the run's start and time (-Title, already
        formatted by the caller) and, when more than one session took part, how many; then a table with a row per
        phase, longest first, each with its time, its share of the run and a bar of that share. A run with no
        phases says why instead.
    #>
    param($Entry, [double]$Total, [Parameter(Mandatory = $true)][string]$Title)
    $sub = if ($Entry -and $Entry.Sessions -gt 1) { '<p class="card__sub">' + $Entry.Sessions + ' sessions</p>' } else { '' }
    $card = '<section class="card"><div class="card__head"><h3 class="card__title">' + (ConvertTo-DashboardText $Title) + '</h3>' + $sub + '</div>'
    if ($null -eq $Entry) { return $card + '<p class="note">No phases read for this run yet.</p></section>' }
    if (-not $Entry.Sessions) { return $card + '<p class="note">No session of this repo was active during this run.</p></section>' }
    if (-not @($Entry.Phases | Where-Object { $_ }).Count) { return $card + '<p class="note">No phases read for this run yet.</p></section>' }
    $card += '<div class="table-wrap"><table class="table"><thead><tr><th class="sw-left">Phase</th><th>Time</th><th>Share</th><th class="sw-left">Of the run</th></tr></thead><tbody>'
    foreach ($p in @($Entry.Phases | Sort-Object -Property @{ Expression = { [double]$_.Seconds }; Descending = $true })) {
        # Capped at 100 so the bar never overflows its track; a phase is at most the run, so the cap only meets rounding.
        $share = if ($Total -gt 0) { [Math]::Min(100, [Math]::Round(100 * $p.Seconds / $Total)) } else { 0 }
        $card += '<tr><td class="sw-left">' + (ConvertTo-DashboardText $p.Name) + '</td><td class="num">' + (Format-DevSeconds $p.Seconds) + '</td><td class="num">' + $share + '%</td>' +
            '<td class="sw-left"><span class="sw-bar" role="img" aria-label="' + $share + '%"><span style="width: ' + $share + '%"></span></span></td></tr>'
    }
    return $card + '</tbody></table></div></section>'
}

function Format-StopwatchDelta {
    <# Faster or slower than the run before, as a badge; nothing for a label's first run. #>
    param($Seconds)
    if ($null -eq $Seconds) { return '<span class="note">first run</span>' }
    if ([Math]::Abs([double]$Seconds) -lt 0.5) { return '<span class="badge badge--sm badge--neutral">same</span>' }
    if ($Seconds -lt 0) { return '<span class="badge badge--sm badge--good">' + (Format-DevSeconds (-[double]$Seconds)) + ' faster</span>' }
    return '<span class="badge badge--sm badge--bad">' + (Format-DevSeconds ([double]$Seconds)) + ' slower</span>'
}

function Format-StopwatchChangeText {
    <# A run's change against the run of its label before it, in words, for a card's line. #>
    param($Seconds)
    if ($null -eq $Seconds) { return 'first run' }
    if ([Math]::Abs([double]$Seconds) -lt 0.5) { return 'same as the run before' }
    if ($Seconds -lt 0) { return (Format-DevSeconds (-[double]$Seconds)) + ' faster than the run before' }
    return (Format-DevSeconds ([double]$Seconds)) + ' slower than the run before'
}

function Format-StopwatchPageShell {
    <# The pieces the two pages share: the page's own style layer and the live-clock script. Names are the page's (sw-), house tokens only. #>
    $style = '.sw-clock { font-size: var(--text-h1); font-weight: 600; margin: var(--spacing-2) 0; }' + "`n" +
        '.sw-left { text-align: left; }' + "`n" +
        '.sw-bar { display: block; min-width: var(--spacing-24); height: var(--spacing-2); background: var(--paper-3); border-radius: var(--spacing-1); overflow: hidden; }' + "`n" +
        '.sw-bar > span { display: block; height: 100%; background: var(--primary); }'
    # The one script: every running clock, drawn from its stored start.
    $script = @'
<script>(function () {
  // Format-DevSeconds' own form: one decimal under a minute, then m:ss, then h:mm:ss.
  function fmt(s) { s = Math.max(0, s); if (s < 59.95) return s.toFixed(1) + "s"; s = Math.round(s);
    var h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), x = s % 60;
    function p(n) { return (n < 10 ? "0" : "") + n; } return h ? h + ":" + p(m) + ":" + p(x) : m + ":" + p(x); }
  var clocks = document.querySelectorAll("[data-start]");
  Array.prototype.forEach.call(clocks, function (c) { var t0 = Date.parse(c.getAttribute("data-start"));
    setInterval(function () { c.textContent = fmt((Date.now() - t0) / 1000); }, 250); });
})();</script>
'@
    return @{ Style = $style; Script = $script }
}

function Format-StopwatchPageHtml {
    <#
        The overview on '/stopwatch', read-only, and bare (no h1, lead, tiles or general banner): it opens on the
        Measurements heading and one card per measurement label with its number of runs, its latest run's time,
        that run's change against the run before it and a link to the label's own page
        (Format-StopwatchLabelPageHtml), in the hub's card markup. A label going now shows its live clock on its
        card. -ReadError is set when the
        store could not be read. -StorePath is named in the footer, so a run can be read and evaluated outside
        the page.
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Model,
        [AllowEmptyString()][string]$ReadError = '',
        [int]$Skipped = 0,
        [AllowEmptyString()][string]$StorePath = '',
        [datetime]$Now = [datetime]::UtcNow
    )
    $e = { param($v) ConvertTo-DashboardText $v }
    $body = New-Object System.Text.StringBuilder
    if ($ReadError) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">The store could not be read: ' + (& $e $ReadError) + '. Nothing is written over it until it reads again, so no new run is recorded.</p>')
    }
    if ($Skipped) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">' + $Skipped + ' run(s) in the store could not be read and are not shown. The next write by a hook drops them; the file as it was is kept beside the store as a .bak.</p>')
    }

    [void]$body.AppendLine('<div class="grid__head"><h2>Measurements</h2><p class="card__sub">One card per label, newest first. Begin a prompt to Claude with stopwatch: and a label to time it.</p></div>')
    if (@($Model.Groups).Count) {
        [void]$body.AppendLine('<div class="grid-3">')
        foreach ($g in @($Model.Groups)) {
            $parts = @()
            $parts += @($g.Rows).Count.ToString() + ' run(s)'
            if (@($g.Rows).Count) { $parts += 'latest ' + (Format-DevSeconds $g.Rows[0].Seconds); $parts += (Format-StopwatchChangeText $g.Rows[0].DeltaSeconds) }
            $sub = (& $e ($parts -join ' - '))
            if ($g.Running) {
                $sub += ' - going now <span class="num" data-start="' + (Format-StopwatchStamp $g.Running.Start) + '">' + (Format-DevSeconds ($Now - $g.Running.Start).TotalSeconds) + '</span>'
            }
            $label = & $e $g.Label
            [void]$body.AppendLine('<section class="card card--link"><nav class="menu-list" aria-label="' + $label + '"><a class="menu-item" href="/stopwatch/' + (& $e $g.Slug) +
                '"><span class="menu-item__label">' + $label + '<span class="menu-item__sub">' + $sub + '</span></span>' + $script:RepoHubChevron + '</a></nav></section>')
        }
        [void]$body.AppendLine('</div>')
    } else {
        [void]$body.AppendLine('<p class="note">No run yet. The first one sets the baseline for its label.</p>')
    }

    $shell = Format-StopwatchPageShell
    $note = 'Kept on this machine in <code>' + (& $e $StorePath) + '</code>, outside the checkout, so a run never dirties the tree it is timing. ' +
        'A prompt whose first line begins with <code>stopwatch:</code> starts a run in a session of this checkout, labelled with the rest of that line, and discards a run still going; ' +
        'a Stop hook ends it once Claude is back on the trunk, clean, with HEAD moved since the start (that suggests the work landed; it does not prove it). Both are <code>scripts/dashboard/stopwatch-hook.ps1</code>. ' +
        'Built by <code>scripts/lib/stopwatch-lib.ps1</code>.'
    return Format-DevPageHtml -Title 'Stopwatch' -Style $shell.Style -Body ($body.ToString() + $shell.Script) -Lead '' -Bare `
        -FooterNote $note
}

function Format-StopwatchLabelPageHtml {
    <#
        One label's page on '/stopwatch/<slug>' (#3323): every finished run of -Group (a group of
        ConvertTo-StopwatchModel), newest first, each with its start, its time, its change against the run before
        and the run going now on top; below the table, under Phases, a card per run with its transcript phases, a row and a
        bar each (-Transcript, by run id, from Get-StopwatchTranscriptCache; a run it lacks says so). The crumbs lead
        back to '/stopwatch'.
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Group,
        [AllowEmptyString()][string]$StorePath = '',
        [hashtable]$Transcript = @{},
        [datetime]$Now = [datetime]::UtcNow
    )
    $e = { param($v) ConvertTo-DashboardText $v }
    $local = { param($t) (& $e ($t.ToLocalTime().ToString('yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture))) }
    $body = New-Object System.Text.StringBuilder
    [void]$body.AppendLine('<div class="grid__head"><h2>' + (& $e $Group.Label) + '</h2></div>')
    if ($Group.Running) {
        [void]$body.AppendLine('<section class="card"><h3>Going now</h3>')
        [void]$body.AppendLine('<p class="sw-clock num" data-start="' + (Format-StopwatchStamp $Group.Running.Start) + '">' + (Format-DevSeconds ($Now - $Group.Running.Start).TotalSeconds) + '</p>')
        [void]$body.AppendLine('<p class="note">Started ' + (& $local $Group.Running.Start) + '.</p></section>')
    }
    if (@($Group.Rows).Count) {
        [void]$body.AppendLine('<div class="grid-2">')
        [void]$body.AppendLine('<div class="grid__head"><h2>Runs</h2><p class="card__sub">' + @($Group.Rows).Count + ' run(s), best ' + (Format-DevSeconds $Group.Best) + ', newest first</p></div>')
        [void]$body.AppendLine('<section class="card grid__full"><div class="table-wrap"><table class="table"><thead><tr><th class="sw-left">Started</th><th>Time</th><th>Against the run before</th></tr></thead><tbody>')
        foreach ($row in @($Group.Rows)) {
            [void]$body.AppendLine('<tr><td class="sw-left">' + (& $local $row.Run.Start) + '</td><td class="num">' + (Format-DevSeconds $row.Seconds) + '</td><td>' + (Format-StopwatchDelta $row.DeltaSeconds) + '</td></tr>')
        }
        [void]$body.AppendLine('</tbody></table></div></section>')
        [void]$body.AppendLine('</div>')
        [void]$body.AppendLine('<div class="grid-2">')
        [void]$body.AppendLine('<div class="grid__head"><h2>Phases</h2><p class="card__sub">Each run split into phases from the session transcripts, longest first</p></div>')
        foreach ($row in @($Group.Rows)) {
            $title = (& $local $row.Run.Start) + ' - ' + (Format-DevSeconds $row.Seconds)
            [void]$body.AppendLine((Format-StopwatchPhaseCard $Transcript[$row.Run.Id] $row.Seconds -Title $title))
        }
        [void]$body.AppendLine('</div>')
    } else {
        [void]$body.AppendLine('<p class="note">No finished run of this label yet.</p>')
    }
    $shell = Format-StopwatchPageShell
    $note = 'Kept on this machine in <code>' + (& $e $StorePath) + '</code>, outside the checkout. ' +
        'The phases are read from this repo''s Claude Code session transcripts once a run has stopped: each second goes to the first phase going at that moment, ' +
        'so a ship running in the background counts as the ship, and a second in which no session was busy is time spent waiting on you. Built by <code>scripts/lib/stopwatch-lib.ps1</code>.'
    return Format-DevPageHtml -Title ([string]$Group.Label) -Style $shell.Style -Body ($body.ToString() + $shell.Script) -Lead '' -Bare -ParentCrumbs @(@{ Label = 'Stopwatch'; Href = '/stopwatch' }) `
        -FooterNote $note
}
