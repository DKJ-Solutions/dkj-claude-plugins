<#
.SYNOPSIS
    Tests for scripts/lib/stopwatch-lib.ps1 -- the Stopwatch page of the dev server (#3315): the store, every
    button press, the model the page draws and the page itself. The server's POST route is the lib's, called
    with the server's clock.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Continue'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $RepoRoot 'scripts\lib\dev-pages-lib.ps1')
. (Join-Path $RepoRoot 'scripts\lib\stopwatch-lib.ps1')

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else            { $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}
# A statement that throws is skipped under 'Continue', so count it instead (as dev-pages.tests.ps1 does).
trap { $script:fail++; Write-Host "  [FAIL] unhandled terminating error: $_" -ForegroundColor Red; continue }
function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    Assert-True ("$Expected" -eq "$Actual") ($Name + $(if ("$Expected" -ne "$Actual") { " (expected '$Expected', got '$Actual')" } else { '' }))
}

$t0 = [datetime]::new(2026, 10, 23, 10, 0, 0, [DateTimeKind]::Utc)
$at = { param([double]$s) $t0.AddSeconds($s) }

Write-Host '-- the query' -ForegroundColor Cyan
$q = ConvertFrom-StopwatchQuery -Target '/stopwatch/start?label=CSS+comment%20%26%20more&x='
Assert-Equal 'CSS comment & more' $q['label'] 'a value is decoded, + and %20 both a space'
Assert-Equal '' $q['x'] 'an empty value is empty'
Assert-Equal 0 (ConvertFrom-StopwatchQuery -Target '/stopwatch/stop').Count 'no query is no values'

Write-Host '-- the buttons' -ForegroundColor Cyan
$r = Invoke-StopwatchAction -Runs @() -Action 'start' -Query @{ label = '  CSS comment  ' } -Now (& $at 0)
Assert-True (-not $r.Error -and @($r.Runs).Count -eq 1 -and $r.Runs[0].Label -eq 'CSS comment' -and -not $r.Runs[0].End) 'start opens a run under its trimmed label'
Assert-True ($r.Runs[0].Id -match '^20261023-100000-[0-9a-f]{4}$') 'its id is the start time plus four hex'
$runs = $r.Runs
Assert-True ((Invoke-StopwatchAction -Runs $runs -Action 'start' -Query @{ label = 'x' } -Now (& $at 1)).Error -match 'already going') 'a second start while one runs is refused'
Assert-True ((Invoke-StopwatchAction -Runs @() -Action 'start' -Query @{ label = '   ' } -Now (& $at 0)).Error -match 'needs a label') 'a start without a label is refused'
Assert-Equal 80 (Invoke-StopwatchAction -Runs @() -Action 'start' -Query @{ label = ('a' * 200) } -Now (& $at 0)).Runs[0].Label.Length 'a label is cut at 80 characters'
Assert-Equal 'a b' (Invoke-StopwatchAction -Runs @() -Action 'start' -Query @{ label = "a`nb" } -Now (& $at 0)).Runs[0].Label 'a control character becomes a space'
$runs = (Invoke-StopwatchAction -Runs $runs -Action 'lap' -Query @{ name = 'PR opened' } -Now (& $at 60)).Runs
$runs = (Invoke-StopwatchAction -Runs $runs -Action 'lap' -Query @{} -Now (& $at 90)).Runs
Assert-Equal 'PR opened,Lap 2' ((@($runs[0].Laps) | ForEach-Object { $_.Name }) -join ',') 'a lap keeps its name, and one without a name is numbered'
$r = Invoke-StopwatchAction -Runs $runs -Action 'stop' -Query @{} -Now (& $at 100)
Assert-True (-not $r.Error -and $r.Runs[0].End -eq (& $at 100)) 'stop ends the run at the server''s clock'
$runs = $r.Runs
Assert-True ((Invoke-StopwatchAction -Runs $runs -Action 'stop' -Now (& $at 101)).Error -match 'No run is going') 'stop with no run going is refused'
Assert-True ((Invoke-StopwatchAction -Runs $runs -Action 'lap' -Now (& $at 101)).Error -match 'No run is going') 'and so is a lap'
$id = $runs[0].Id
$r = Invoke-StopwatchAction -Runs $runs -Action 'note' -Query @{ id = $id; text = 'run the gate once' } -Now (& $at 102)
Assert-True (-not $r.Error -and $r.Runs[0].Note -eq 'run the gate once') 'a note lands on a finished run'
Assert-True ((Invoke-StopwatchAction -Runs $runs -Action 'note' -Query @{ id = 'nope'; text = 'x' } -Now (& $at 102)).Error -match 'not in the store') 'a note for an unknown id is refused'
Assert-Equal "- one`n- two`tb" (Invoke-StopwatchAction -Runs $runs -Action 'note' -Query @{ id = $id; text = "- one`r`n- two`tb`a" } -Now (& $at 102)).Runs[0].Note 'a note keeps its line breaks and tabs, and loses any other control character'
$full = @{ Id = 'f'; Label = 'F'; Start = (& $at 0); End = $null; Laps = @(1..100 | ForEach-Object { @{ Name = "l$_"; At = (& $at $_) } }); Note = '' }
Assert-True ((Invoke-StopwatchAction -Runs @($full) -Action 'lap' -Now (& $at 200)).Error -match 'at most 100 laps') 'a run holds at most 100 laps'
$going = (Invoke-StopwatchAction -Runs $runs -Action 'start' -Query @{ label = 'b' } -Now (& $at 200)).Runs
Assert-True ((Invoke-StopwatchAction -Runs $going -Action 'note' -Query @{ id = $going[1].Id; text = 'x' } -Now (& $at 201)).Error -match 'still going') 'a note for the running run is refused'
Assert-Equal 1 @((Invoke-StopwatchAction -Runs $going -Action 'discard' -Now (& $at 201)).Runs).Count 'discard drops the running run and keeps the rest'
Assert-Equal 0 @((Invoke-StopwatchAction -Runs $runs -Action 'delete' -Query @{ id = $id } -Now (& $at 201)).Runs).Count 'delete drops a finished run'
Assert-True ((Invoke-StopwatchAction -Runs $runs -Action 'reset' -Now (& $at 201)).Error -match 'Unknown action') 'an unknown action is refused'

Write-Host '-- arm and disarm (#3323)' -ForegroundColor Cyan
$ra = Invoke-StopwatchAction -Runs @() -Action 'arm' -Query @{ label = '  CSS comment  ' } -Now (& $at 0)
Assert-True (-not $ra.Error -and $ra.Armed.Label -eq 'CSS comment' -and $ra.Armed.At -eq (& $at 0) -and @($ra.Runs).Count -eq 0) 'arm stores the trimmed label and starts no clock'
$armed = $ra.Armed
Assert-Equal 'Docs' (Invoke-StopwatchAction -Runs @() -Action 'arm' -Query @{ label = 'Docs' } -Now (& $at 5) -Armed $armed).Armed.Label 'arming again replaces the armed label'
Assert-True ((Invoke-StopwatchAction -Runs @() -Action 'arm' -Query @{ label = ' ' } -Now (& $at 5) -Armed $armed).Error -match 'needs a label') 'arm without a label is refused'
$refused = Invoke-StopwatchAction -Runs $going -Action 'arm' -Query @{ label = 'x' } -Now (& $at 5) -Armed $armed
Assert-True ($refused.Error -match 'already going' -and $refused.Armed.Label -eq 'CSS comment') 'arm while a run is going is refused, and the old arming stays'
Assert-True ($null -eq (Invoke-StopwatchAction -Runs @() -Action 'disarm' -Now (& $at 6) -Armed $armed).Armed) 'disarm clears the armed label'
Assert-True (-not (Invoke-StopwatchAction -Runs @() -Action 'disarm' -Now (& $at 6)).Error) 'disarm with nothing armed is not an error'
Assert-Equal 'CSS comment' (Invoke-StopwatchAction -Runs $going -Action 'lap' -Now (& $at 6) -Armed $armed).Armed.Label 'a lap leaves the arming alone'
Assert-True ($null -eq (Invoke-StopwatchAction -Runs @() -Action 'start' -Query @{ label = 'b' } -Now (& $at 6) -Armed $armed).Armed) 'a manual start while armed clears the arming'
Assert-True (-not (Invoke-StopwatchAction -Runs @() -Action 'start' -Query @{ label = 'b' } -Now (& $at 6)).Runs[0].Auto) 'a run started by hand is not Auto'

Write-Host '-- the hook rules (#3323)' -ForegroundColor Cyan
$arm = @{ Label = 'Feature'; At = (& $at 0) }
$h = Invoke-StopwatchHookEvent -Hook Prompt -Runs @() -Armed $arm -Now (& $at 10) -Head 'aaa'
Assert-True ($h.Changed -and $null -eq $h.Armed -and @($h.Runs).Count -eq 1 -and $h.Runs[0].Auto -and $h.Runs[0].Label -eq 'Feature' -and $h.Runs[0].Start -eq (& $at 10) -and $h.Runs[0].StartHead -eq 'aaa' -and -not $h.Runs[0].End) 'a prompt starts the armed run now, Auto, at the current HEAD, and clears the arming'
$h = Invoke-StopwatchHookEvent -Hook Prompt -Runs @() -Armed $arm -Now (& $at 10) -Head ''
Assert-True (-not $h.Changed -and $h.Armed.Label -eq 'Feature' -and @($h.Runs).Count -eq 0) 'a prompt with an unknown HEAD starts nothing and keeps the arming'
Assert-True (-not (Invoke-StopwatchHookEvent -Hook Prompt -Runs @() -Armed $null -Now (& $at 10) -Head 'aaa').Changed) 'a prompt with nothing armed does nothing'
$manual = (Invoke-StopwatchAction -Runs @() -Action 'start' -Query @{ label = 'by hand' } -Now (& $at 0)).Runs
$h = Invoke-StopwatchHookEvent -Hook Prompt -Runs $manual -Armed $arm -Now (& $at 10) -Head 'aaa'
Assert-True (-not $h.Changed -and $h.Armed.Label -eq 'Feature' -and @($h.Runs).Count -eq 1) 'a prompt while a run is going starts nothing and keeps the arming'
$auto = @((Invoke-StopwatchHookEvent -Hook Prompt -Runs @() -Armed $arm -Now (& $at 10) -Head 'aaa').Runs)
$stop = { param($b, $c, $hd, $rs) Invoke-StopwatchHookEvent -Hook Stop -Runs $rs -Armed $null -Now (& $at 500) -Branch $b -Clean $c -Head $hd }
$h = & $stop 'main' $true 'bbb' $auto
Assert-True ($h.Changed -and $h.Runs[0].End -eq (& $at 500)) 'a Stop on the trunk, clean, with HEAD moved ends the Auto run'
Assert-True (-not (& $stop 'main' $true 'aaa' $auto).Changed) 'a turn that left HEAD where it was keeps the run going'
Assert-True (-not (& $stop 'feat/x' $true 'bbb' $auto).Changed) 'a branch parked off the trunk keeps the run going'
Assert-True (-not (& $stop 'main' $false 'bbb' $auto).Changed) 'a dirty checkout keeps the run going'
Assert-True (-not (& $stop 'main' $true '' $auto).Changed) 'an unknown HEAD keeps the run going'
Assert-True (-not (& $stop 'main' $true 'bbb' $manual).Changed) 'a run started by hand is never stopped by the hook'
$noHeadRun = $auto[0].Clone(); $noHeadRun.StartHead = ''
Assert-True (-not (& $stop 'main' $true 'bbb' @($noHeadRun)).Changed) 'an Auto run with no StartHead is never stopped by the hook'
Assert-True ((Invoke-StopwatchHookEvent -Hook Stop -Runs $auto -Armed $null -Now (& $at 500) -Branch 'master' -Clean $true -Head 'bbb' -Trunk 'master').Changed) 'the trunk name is a parameter'
Assert-True (-not (Invoke-StopwatchHookEvent -Hook Stop -Runs @() -Armed $arm -Now (& $at 500) -Branch 'main' -Clean $true -Head 'bbb').Changed) 'a Stop with no run going does nothing'

Write-Host '-- the store' -ForegroundColor Cyan
$dir = Join-Path ([System.IO.Path]::GetTempPath()) ('stopwatch-tests-' + [guid]::NewGuid().ToString('N'))
$store = Join-Path $dir 'sub\stopwatch.json'
try {
    $empty = Read-StopwatchStore -Path $store
    Assert-True (-not $empty.Error -and @($empty.Runs).Count -eq 0) 'a missing store is an empty one, not an error'
    Save-StopwatchStore -Path $store -Runs $r.Runs
    $back = Read-StopwatchStore -Path $store
    Assert-True (-not $back.Error -and @($back.Runs).Count -eq 1) 'a saved store reads back, its folder made on the way'
    Assert-True ($back.Runs[0].Start -eq (& $at 0) -and $back.Runs[0].End -eq (& $at 100) -and $back.Runs[0].Laps[1].At -eq (& $at 90) -and $back.Runs[0].Note -eq 'run the gate once') 'every time and the note survive the round trip'
    Assert-True (-not (Test-Path -LiteralPath "$store.tmp")) 'and no temp file is left beside it'
    Save-StopwatchStore -Path $store -Runs @()
    Assert-True ((Get-Content -LiteralPath $store -Raw) -match '"runs":\s*\[\s*\]') 'an empty store is written as an empty list'
    [System.IO.File]::WriteAllText($store, '{ "runs": [ { "id": "x1", "label": "ok", "start": "2026-10-23T10:00:00.000Z" }, { "id": "bad id!", "label": "x", "start": "2026" }, { "id": "x2\n", "label": "x", "start": "2026-10-23T10:00:00.000Z" } ] }')
    $mixed = Read-StopwatchStore -Path $store
    Assert-True (@($mixed.Runs).Count -eq 1 -and $mixed.Skipped -eq 2) 'a run that does not parse is skipped and counted, an id with a trailing newline too'
    Assert-True ($null -eq $mixed.Armed) 'a store with no armed entry reads as not armed'
    Save-StopwatchStore -Path $store -Runs $auto -Armed $armed
    $auto2 = Read-StopwatchStore -Path $store
    Assert-True ($auto2.Armed.Label -eq 'CSS comment' -and $auto2.Armed.At -eq (& $at 0) -and $auto2.Runs[0].Auto -and $auto2.Runs[0].StartHead -eq 'aaa') 'armed, Auto and StartHead survive the round trip'
    Save-StopwatchStore -Path $store -Runs $manual
    $plain = Read-StopwatchStore -Path $store
    Assert-True ($null -eq $plain.Armed -and -not $plain.Runs[0].Auto -and $plain.Runs[0].StartHead -eq '') 'a store saved without them reads back not armed and not Auto'
    [System.IO.File]::WriteAllText($store, '{ "runs": [], "armed": { "label": " ", "at": "x" } }')
    Assert-True ($null -eq (Read-StopwatchStore -Path $store).Armed) 'an armed entry that does not parse is not armed'
    [System.IO.File]::WriteAllText($store, '{ not json')
    Assert-Equal 'it is not valid JSON' (Read-StopwatchStore -Path $store).Error 'a store that is not JSON is an error, so nothing writes over it'
    # The hook script itself, against a store of its own: silent, exit 0, and the same decisions.
    $hookScript = Join-Path $RepoRoot 'scripts\dashboard\stopwatch-hook.ps1'
    $hookStore = Join-Path $dir 'hook\stopwatch.json'
    Save-StopwatchStore -Path $hookStore -Runs @() -Armed @{ Label = 'Hooked'; At = (& $at 0) }
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $hookScript -Hook Prompt -StorePath $hookStore 2>&1
    Assert-True ($LASTEXITCODE -eq 0 -and -not $out) 'the hook script exits 0 and prints nothing'
    $hs = Read-StopwatchStore -Path $hookStore
    Assert-True ($null -eq $hs.Armed -and @($hs.Runs).Count -eq 1 -and $hs.Runs[0].Auto -and $hs.Runs[0].Label -eq 'Hooked' -and $hs.Runs[0].StartHead -match '^[0-9a-f]{40}$') 'the Prompt hook starts the armed run with this checkout''s HEAD'
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $hookScript -Hook Stop -StorePath $hookStore 2>&1
    Assert-True ($LASTEXITCODE -eq 0 -and -not $out -and -not (Read-StopwatchStore -Path $hookStore).Runs[0].End) 'a Stop with HEAD where the run started leaves it going'
    [System.IO.File]::WriteAllText($hookStore, '{ not json')
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $hookScript -Hook Prompt -StorePath $hookStore 2>&1
    Assert-True ($LASTEXITCODE -eq 0 -and -not $out -and (Get-Content -LiteralPath $hookStore -Raw) -eq '{ not json') 'the hook never writes over a store that does not read'
} finally {
    Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host '-- the model' -ForegroundColor Cyan
$mk = { param($label, $start, $end) @{ Id = "id$start"; Label = $label; Start = (& $at $start); End = $(if ($null -ne $end) { & $at $end } else { $null }); Laps = @(); Note = '' } }
$m = ConvertTo-StopwatchModel -Runs @((& $mk 'CSS comment' 0 300), (& $mk 'css COMMENT' 1000 1200), (& $mk 'Docs' 2000 2500), (& $mk 'CSS comment' 3000 3250), (& $mk 'Live' 5000 $null))
Assert-True ($m.Running -and $m.Running.Label -eq 'Live') 'the run without an end is the running one'
Assert-Equal 4 $m.Count 'only finished runs are counted'
Assert-Equal 'CSS comment,Docs' (($m.Groups | ForEach-Object { $_.Label }) -join ',') 'labels group case-insensitively, the group with the newest run first'
$css = $m.Groups[0]
Assert-Equal '250,200,300' (($css.Rows | ForEach-Object { $_.Seconds }) -join ',') 'a group''s runs are newest first'
Assert-Equal '50,-100,' (($css.Rows | ForEach-Object { $_.DeltaSeconds }) -join ',') 'each against the run before it, and the first against nothing'
Assert-Equal 200 $css.Best 'the best is the shortest run'
$lapped = @{ Id = 'l'; Label = 'L'; Start = (& $at 0); End = (& $at 100); Laps = @(@{ Name = 'a'; At = (& $at 30) }, @{ Name = 'b'; At = (& $at 70) }); Note = '' }
Assert-Equal 'a=30,b=40,Last stretch=30' ((Get-StopwatchPhases -Run $lapped | ForEach-Object { "$($_.Name)=$($_.Seconds)" }) -join ',') 'laps become phases, the last one up to the stop'
Assert-Equal 0 @(Get-StopwatchPhases -Run (& $mk 'x' 0 10)).Count 'a run without laps has no phases'

Write-Host '-- the page' -ForegroundColor Cyan
$page = Format-StopwatchPageHtml -Model $m -StorePath 'C:\x\stopwatch.json' -Now (& $at 5065)
Assert-True ($page -match '<h1>Stopwatch</h1>' -and $page -match '<li><a href="/">Home</a></li>') 'the page has the house shell and its crumb back to the hub'
Assert-True ($page -match 'class="sw-clock num" data-start="2026-10-23T11:23:20.000Z">1:05<' -and $page -match 'data-sw="stop"') 'a running run shows its clock from the stored start, and Stop'
Assert-True ($page -match 'badge--good">1:40 faster<' -and $page -match 'badge--bad">50.0s slower<' -and $page -match 'first run') 'each run says faster or slower than the one before'
Assert-True ($page -notmatch '<section class="card[^"]*">\s*<h2') 'no h2 stands inside a card'
Assert-True ($page -match 'C:\\x\\stopwatch.json') 'the footer names where the runs are kept'
$idle = Format-StopwatchPageHtml -Model (ConvertTo-StopwatchModel -Runs @((& $mk 'Docs' 0 10))) -StorePath 's'
Assert-True ($idle -match 'data-action="start"' -and $idle -match '<option value="Docs">' -and $idle -notmatch 'class="sw-clock') 'with nothing running it offers Start, with the labels used before'
$evil = Format-StopwatchPageHtml -Model (ConvertTo-StopwatchModel -Runs @((& $mk '<script>x</script>' 0 10))) -StorePath 's'
Assert-True ($evil -notmatch '<script>x</script>' -and $evil -match '&lt;script&gt;x&lt;/script&gt;') 'a label is escaped wherever it is shown'
$broken = Format-StopwatchPageHtml -Model (ConvertTo-StopwatchModel -Runs @()) -ReadError 'it is not valid JSON' -StorePath 's'
Assert-True ($broken -match 'could not be read' -and $broken -match 'type="submit" disabled') 'a store that does not read says so, and turns the buttons off'
Assert-True ($idle -match 'data-action="arm"' -and $idle -notmatch 'data-sw="disarm"' -and $idle -notmatch 'Armed:') 'with nothing running it offers Arm beside Start, and no Disarm until something is armed'
$armedPage = Format-StopwatchPageHtml -Model (ConvertTo-StopwatchModel -Runs @() -Armed @{ Label = '<b>Feature</b>'; At = (& $at 0) }) -StorePath 's'
Assert-True ($armedPage -match 'Armed: <strong>&lt;b&gt;Feature&lt;/b&gt;</strong> -- starts on your next prompt to Claude' -and $armedPage -match 'data-sw="disarm"') 'an armed label is shown, escaped, with Disarm'
$autoRun = @{ Id = 'au'; Label = 'Auto'; Start = (& $at 0); End = (& $at 60); Laps = @(); Note = ''; Auto = $true; StartHead = 'a' }
$autoPage = Format-StopwatchPageHtml -Model (ConvertTo-StopwatchModel -Runs @($autoRun, (& $mk 'Hand' 100 160))) -StorePath 's'
Assert-Equal 1 ([regex]::Matches($autoPage, 'badge--info">auto<')).Count 'only an auto-started run carries the auto tag'

Write-Host '-- the transcript phases' -ForegroundColor Cyan
Assert-Equal (Join-Path $HOME '.claude\projects\C--Users-x-my-repo') (Get-StopwatchTranscriptDir -RepoRoot 'C:\Users\x\my.repo\') 'the transcripts are under the root with every non-alphanumeric a dash'
Assert-Equal 'Ship: CI wait, merge, fold' (Get-StopwatchToolPhase -Name 'PowerShell' -Command 'scripts/release/ship-pr.ps1 -NoResolves') 'ship-pr is the ship'
Assert-Equal 'Local gates and tests' (Get-StopwatchToolPhase -Name 'Bash' -Command 'scripts/tests/stopwatch.tests.ps1') 'a suite is a gate'
Assert-Equal 'Subagents' (Get-StopwatchToolPhase -Name 'Agent') 'an Agent call is a subagent'
Assert-Equal 'Other tool calls' (Get-StopwatchToolPhase -Name 'Read') 'anything else is another tool call'
Assert-Equal 'Other tool calls' (Get-StopwatchToolPhase -Name 'Edit' -Command 'ship-pr.ps1') 'a script name counts only in a shell command, not in an edit'
# One session: a prompt at 0, new-branch 10-20, ship-pr backgrounded at 30 and done at 200, a reply to the
# notification until 210, the next prompt at 300, a Read 305-306, the last word at 320. The window is 0-330.
$stamp = { param([double]$s) Format-StopwatchStamp (& $at $s) }
$rec = { param([double]$s, [string]$type, $content) [ordered]@{ parentUuid = 'p'; isSidechain = $false; type = $type; message = @{ role = $type; content = $content }; timestamp = (& $stamp $s) } | ConvertTo-Json -Depth 8 -Compress }
$use = { param([double]$s, $id, $name, $cmd) & $rec $s 'assistant' @(@{ type = 'tool_use'; id = $id; name = $name; input = @{ command = $cmd } }) }
$res = { param([double]$s, $id, $text) & $rec $s 'user' @(@{ type = 'tool_result'; tool_use_id = $id; content = $text }) }
$lines = @(
    (& $rec 0 'user' 'time this'),
    (& $use 10 't1' 'PowerShell' 'scripts/task/new-branch.ps1 -Name feat/x'), (& $res 20 't1' 'ok'),
    (& $use 30 't2' 'PowerShell' 'scripts/release/ship-pr.ps1'), (& $res 31 't2' 'Command running in background with ID: b1.'),
    (& $rec 40 'assistant' @(@{ type = 'text'; text = 'shipping' })),
    ('{"type":"queue-operation","operation":"enqueue","timestamp":"' + (& $stamp 200) + '","content":"<task-notification>\n<tool-use-id>t2</tool-use-id>\n</task-notification>"}'),
    (& $rec 201 'user' "<task-notification>`n<tool-use-id>t2</tool-use-id>`n</task-notification>"),
    (& $rec 210 'assistant' @(@{ type = 'text'; text = 'done' })),
    ('{"parentUuid":"p","isSidechain":true,"type":"user","message":{"content":"a subagent"},"timestamp":"' + (& $stamp 250) + '"}'),
    '{"parentUuid":"p","type":"user","timestamp":"cut off mid-line',
    (& $rec 300 'user' 'next'),
    (& $use 305 't3' 'Read' 'x'), (& $res 306 't3' 'a doc: eight minutes running in the background. <task-notification><tool-use-id>t1</tool-use-id></task-notification>'),
    (& $rec 320 'assistant' @(@{ type = 'text'; text = 'receipt' }))
)
$tdir = Join-Path ([System.IO.Path]::GetTempPath()) ('stopwatch-transcripts-' + [guid]::NewGuid().ToString('N'))
try {
    [void](New-Item -ItemType Directory -Path $tdir -Force)
    $tfile = Join-Path $tdir 'session.jsonl'
    [System.IO.File]::WriteAllText($tfile, ($lines -join "`n"), (New-Object System.Text.UTF8Encoding($false)))
    $ev = Read-StopwatchTranscriptEvents -Path $tfile -From (& $at 0) -To (& $at 330)
    Assert-Equal 3 @($ev.Turns).Count 'a typed prompt and a task notification each start a turn; a subagent''s line and a cut-off line do not'
    $ship = @($ev.Tools | Where-Object { $_.Phase -like 'Ship*' })[0]
    Assert-True ($ship.End -eq (& $at 200)) 'a background run ends at its notification, not at its immediate result'
    $p = Get-StopwatchTranscriptPhases -Events @($ev) -From (& $at 0) -To (& $at 330)
    $got = (@($p.Phases) | ForEach-Object { "$($_.Name)=$([Math]::Round($_.Seconds))" }) -join ';'
    Assert-Equal 'Ship: CI wait, merge, fold=170;Branch and claim=10;Other tool calls=1;Claude thinking and writing=48;Waiting on you=101' $got 'every second goes to the first phase going at that moment, and the rest is waiting (200-201: the notification is queued before its turn starts)'
    Assert-Equal 1 $p.Sessions 'one session had a turn in the window'
    $late = Get-StopwatchTranscriptPhases -Events @($ev) -From (& $at 100) -To (& $at 150)
    Assert-Equal 'Ship: CI wait, merge, fold=50' ((@($late.Phases) | ForEach-Object { "$($_.Name)=$([Math]::Round($_.Seconds))" }) -join ';') 'a phase is clipped to the window'
    $none = Get-StopwatchTranscriptPhases -Events @() -From (& $at 0) -To (& $at 60)
    Assert-True ($none.Sessions -eq 0 -and $none.Phases[0].Name -eq 'Waiting on you') 'with no transcript the whole window is waiting'

    # The cache skips a transcript last written before the run started, so the fixture is dated inside the run.
    (Get-Item -LiteralPath $tfile).LastWriteTimeUtc = (& $at 330)
    Assert-True (@($ev.Tools | Where-Object { $_.Phase -like 'Branch*' })[0].End -eq (& $at 20)) 'a tool result that quotes a notification does not end another call'
    Assert-True (@($ev.Tools | Where-Object { $_.Phase -like 'Other*' })[0].End -eq (& $at 306)) 'a Read whose text says "in the background" is not a background call'

    $tfile2 = Join-Path $tdir 'timeout.jsonl'
    [System.IO.File]::WriteAllText($tfile2, ((& $rec 0 'user' 'go'), (& $use 1 'u1' 'Bash' 'scripts/release/ship-pr.ps1'),
            (& $res 601 'u1' 'Command did not complete within its 600s timeout and was moved to the background (ID: b2).'),
            (& $use 610 'u2' 'Agent' 'review ship-pr.ps1 and open-pr.ps1'), (& $res 611 'u2' 'Async agent launched successfully.')) -join "`n")
    $ev2 = Read-StopwatchTranscriptEvents -Path $tfile2 -From (& $at 0) -To (& $at 900)
    $p2 = Get-StopwatchTranscriptPhases -Events @($ev2) -From (& $at 0) -To (& $at 900)
    Assert-Equal 'Ship: CI wait, merge, fold=899;Claude thinking and writing=1' ((@($p2.Phases) | ForEach-Object { "$($_.Name)=$([Math]::Round($_.Seconds))" }) -join ';') 'a call moved to the background at its timeout runs on, and an agent naming ship-pr is not a ship'
    Assert-True (@($ev2.Tools | Where-Object { $_.Phase -eq 'Subagents' })[0].End -eq (& $at 900)) 'an async agent with no notification yet runs to the end'
    Remove-Item -LiteralPath $tfile2

    $cachePath = Join-Path $tdir 'cache\stopwatch-phases.json'
    $run = @{ Id = 'r1'; Label = 'CSS comment'; Start = (& $at 0); End = (& $at 330); Laps = @(); Note = '' }
    $old = Join-Path $tdir 'old.jsonl'
    [System.IO.File]::WriteAllText($old, (& $rec 100 'user' 'from before the run'))
    (Get-Item -LiteralPath $old).LastWriteTimeUtc = (& $at -1)
    $first = Get-StopwatchTranscriptCache -Runs @($run, (& $mk 'Live' 400 $null)) -CachePath $cachePath -TranscriptDir $tdir
    Assert-True ($first.ContainsKey('r1') -and -not $first.ContainsKey('id400') -and (Test-Path -LiteralPath $cachePath)) 'a finished run is read and cached, a running one is not'
    Assert-Equal 1 $first.r1.Sessions 'a transcript last written before the run started is not read'
    [System.IO.File]::WriteAllText($tfile, '')
    $again = Get-StopwatchTranscriptCache -Runs @($run) -CachePath $cachePath -TranscriptDir $tdir
    Assert-Equal 5 @($again.r1.Phases).Count 'the cache is read back instead of the transcripts'
    $moved = $run.Clone(); $moved.End = (& $at 331)
    Assert-Equal 0 (Get-StopwatchTranscriptCache -Runs @($moved) -CachePath $cachePath -TranscriptDir $tdir).r1.Sessions 'a run whose end changed is read again'
    [System.IO.File]::WriteAllText($cachePath, '{ not json')
    Assert-True ((Get-StopwatchTranscriptCache -Runs @($run) -CachePath $cachePath -TranscriptDir $tdir).ContainsKey('r1')) 'a cache that does not read is recomputed'
    $nowhere = Join-Path $tdir 'nowhere\stopwatch-phases.json'
    $blind = Get-StopwatchTranscriptCache -Runs @($run) -CachePath $nowhere -TranscriptDir (Join-Path $tdir 'no-such-dir')
    Assert-True ($blind.r1.Sessions -eq 0 -and -not (Test-Path -LiteralPath $nowhere)) 'with no transcript to read nothing is cached, so a wrong folder is not filed for good'

    $cell = Format-StopwatchTranscriptCell $first.r1 330
    Assert-True ($cell -match 'Waiting on you <span class="num">1:41</span> <span class="note">31%</span>') 'the cell gives each phase its time and its share of the run'
    Assert-True ((Format-StopwatchTranscriptCell @{ Sessions = 0; Phases = @() } 60) -match 'no session') 'a run no session saw says so'
    $tm = ConvertTo-StopwatchModel -Runs @($run)
    Assert-True ((Format-StopwatchPageHtml -Model $tm -StorePath 's' -Transcript $first) -match 'From the transcripts</th>[\s\S]*Ship: CI wait, merge, fold <span class="num">2:50') 'the page shows the transcript phases beside the laps'
} finally {
    Remove-Item -LiteralPath $tdir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host "stopwatch: $script:pass passed, $script:fail failed"
if ($script:fail -gt 0) { exit 1 }
exit 0
