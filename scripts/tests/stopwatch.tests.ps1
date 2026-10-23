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
    [System.IO.File]::WriteAllText($store, '{ not json')
    Assert-Equal 'it is not valid JSON' (Read-StopwatchStore -Path $store).Error 'a store that is not JSON is an error, so nothing writes over it'
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

Write-Host ''
Write-Host "stopwatch: $script:pass passed, $script:fail failed"
if ($script:fail -gt 0) { exit 1 }
exit 0
