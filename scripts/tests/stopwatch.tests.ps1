<#
.SYNOPSIS
    Tests for scripts/lib/stopwatch-lib.ps1 -- the Stopwatch page of the dev server (#3315, #3323): the store, the
    hook's rules and the hook script itself, the model the page draws and the read-only page.

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

Write-Host '-- the stopwatch: marker (#3323)' -ForegroundColor Cyan
Assert-Equal 'CSS comment' (Get-StopwatchPromptMarker -Prompt "  StopWatch:  CSS comment  `nthe rest of the prompt") 'the marker is case-insensitive, leading whitespace is fine, and the label is the rest of the first line trimmed'
Assert-Equal 'Assignment' (Get-StopwatchPromptMarker -Prompt "stopwatch:   `nsomething") 'an empty label falls back to Assignment'
Assert-Equal 80 (Get-StopwatchPromptMarker -Prompt ('stopwatch: ' + ('a' * 200))).Length 'the label is cut at the label maximum'
Assert-True ($null -eq (Get-StopwatchPromptMarker -Prompt "fix this`nstopwatch: x")) 'a marker on a later line is not a marker'
Assert-True ($null -eq (Get-StopwatchPromptMarker -Prompt 'please stopwatch: x') -and $null -eq (Get-StopwatchPromptMarker -Prompt '')) 'a prompt that does not begin with the marker, and an empty one, carry none'

Write-Host '-- the hook rules (#3323)' -ForegroundColor Cyan
$h = Invoke-StopwatchHookEvent -Hook Prompt -Runs @() -Now (& $at 10) -Head 'aaa' -Prompt "stopwatch: Docs fix`nplease do it"
Assert-True ($h.Changed -and @($h.Runs).Count -eq 1 -and $h.Runs[0].Auto -and $h.Runs[0].Label -eq 'Docs fix' -and $h.Runs[0].StartHead -eq 'aaa' -and $h.Runs[0].Start -eq (& $at 10) -and -not $h.Runs[0].End) 'a marked prompt starts an Auto run under its label at the current HEAD'
Assert-True ($h.Runs[0].Id -match '^20261023-100010-[0-9a-f]{4}$') 'its id is the start time plus four hex'
$h = Invoke-StopwatchHookEvent -Hook Prompt -Runs @() -Now (& $at 10) -Head 'aaa' -Prompt 'stopwatch:'
Assert-Equal 'Assignment' $h.Runs[0].Label 'a marker with an empty label starts a run called Assignment'
$done = @{ Id = 'd1'; Label = 'Old'; Start = (& $at 0); End = (& $at 5); Auto = $true; StartHead = 'x' }
$going = @{ Id = 'g1'; Label = 'Going'; Start = (& $at 6); End = $null; Auto = $true; StartHead = 'aaa' }
$h = Invoke-StopwatchHookEvent -Hook Prompt -Runs @($done, $going) -Now (& $at 10) -Head 'bbb' -Prompt 'stopwatch: Next'
Assert-True ($h.Changed -and @($h.Runs).Count -eq 2 -and $h.Runs[0].Id -eq 'd1' -and $h.Runs[1].Label -eq 'Next' -and -not $h.Runs[1].End -and $h.Runs[1].StartHead -eq 'bbb') 'a marked prompt while a run is going discards that run, keeps the finished ones and starts the new one'
$h = Invoke-StopwatchHookEvent -Hook Prompt -Runs @($going) -Now (& $at 10) -Head '' -Prompt 'stopwatch: x'
Assert-True (-not $h.Changed -and @($h.Runs).Count -eq 1 -and $h.Runs[0].Id -eq 'g1') 'a marked prompt with an unknown HEAD starts nothing and discards nothing'
Assert-True (-not (Invoke-StopwatchHookEvent -Hook Prompt -Runs @($going) -Now (& $at 10) -Head 'aaa' -Prompt 'just a question').Changed) 'an unmarked prompt does nothing, a run going keeps going'
$auto = @($going)
$stop = { param($b, $c, $hd, $rs) Invoke-StopwatchHookEvent -Hook Stop -Runs $rs -Now (& $at 500) -Branch $b -Clean $c -Head $hd }
$h = & $stop 'main' $true 'bbb' $auto
Assert-True ($h.Changed -and $h.Runs[0].End -eq (& $at 500)) 'a Stop on the trunk, clean, with HEAD moved ends the run'
Assert-True (-not (& $stop 'main' $true 'aaa' $auto).Changed) 'a turn that left HEAD where it was keeps the run going'
Assert-True (-not (& $stop 'feat/x' $true 'bbb' $auto).Changed) 'a branch parked off the trunk keeps the run going'
Assert-True (-not (& $stop 'main' $false 'bbb' $auto).Changed) 'a dirty checkout keeps the run going'
Assert-True (-not (& $stop 'main' $true '' $auto).Changed) 'an unknown HEAD keeps the run going'
$oldHand = @{ Id = 'h1'; Label = 'by hand'; Start = (& $at 0); End = $null; Auto = $false; StartHead = '' }
Assert-True (-not (& $stop 'main' $true 'bbb' @($oldHand)).Changed) 'an old hand-started run is never stopped by the hook'
$noHeadRun = $going.Clone(); $noHeadRun.StartHead = ''
Assert-True (-not (& $stop 'main' $true 'bbb' @($noHeadRun)).Changed) 'a run with no StartHead is never stopped by the hook'
Assert-True ((Invoke-StopwatchHookEvent -Hook Stop -Runs $auto -Now (& $at 500) -Branch 'master' -Clean $true -Head 'bbb' -Trunk 'master').Changed) 'the trunk name is a parameter'
Assert-True (-not (Invoke-StopwatchHookEvent -Hook Stop -Runs @($done) -Now (& $at 500) -Branch 'main' -Clean $true -Head 'bbb').Changed) 'a Stop with no run going does nothing'

Write-Host '-- the store' -ForegroundColor Cyan
$dir = Join-Path ([System.IO.Path]::GetTempPath()) ('stopwatch-tests-' + [guid]::NewGuid().ToString('N'))
$store = Join-Path $dir 'sub\stopwatch.json'
try {
    $empty = Read-StopwatchStore -Path $store
    Assert-True (-not $empty.Error -and @($empty.Runs).Count -eq 0) 'a missing store is an empty one, not an error'
    Save-StopwatchStore -Path $store -Runs @($done, $going)
    $back = Read-StopwatchStore -Path $store
    Assert-True (-not $back.Error -and @($back.Runs).Count -eq 2) 'a saved store reads back, its folder made on the way'
    Assert-True ($back.Runs[0].Start -eq (& $at 0) -and $back.Runs[0].End -eq (& $at 5) -and $back.Runs[1].End -eq $null -and $back.Runs[1].Auto -and $back.Runs[1].StartHead -eq 'aaa') 'every time, Auto and StartHead survive the round trip'
    Assert-True (-not (Test-Path -LiteralPath "$store.tmp")) 'and no temp file is left beside it'
    Save-StopwatchStore -Path $store -Runs @()
    Assert-True ((Get-Content -LiteralPath $store -Raw) -match '"runs":\s*\[\s*\]') 'an empty store is written as an empty list'
    [System.IO.File]::WriteAllText($store, '{ "runs": [ { "id": "x1", "label": "ok", "start": "2026-10-23T10:00:00.000Z" }, { "id": "bad id!", "label": "x", "start": "2026" }, { "id": "x2\n", "label": "x", "start": "2026-10-23T10:00:00.000Z" } ] }')
    $mixed = Read-StopwatchStore -Path $store
    Assert-True (@($mixed.Runs).Count -eq 1 -and $mixed.Skipped -eq 2) 'a run that does not parse is skipped and counted, an id with a trailing newline too'
    # An older store: laps, a note and an armed label, written by buttons that are gone.
    [System.IO.File]::WriteAllText($store, '{ "runs": [ { "id": "o1", "label": "Old", "start": "2026-10-23T10:00:00.000Z", "end": "2026-10-23T10:05:00.000Z", "laps": [ { "name": "a", "at": "2026-10-23T10:01:00.000Z" } ], "note": "n" } ], "armed": { "label": "x", "at": "2026-10-23T10:00:00.000Z" } }')
    $oldStore = Read-StopwatchStore -Path $store
    Assert-True (-not $oldStore.Error -and @($oldStore.Runs).Count -eq 1 -and $oldStore.Skipped -eq 0 -and $oldStore.Runs[0].End -eq (& $at 300) -and -not $oldStore.Runs[0].Auto) 'an older store reads, its laps, note and armed label ignored'
    Save-StopwatchStore -Path $store -Runs $oldStore.Runs
    $text = Get-Content -LiteralPath $store -Raw
    Assert-True ($text -notmatch 'laps|note|armed') 'and the next write drops what this version does not know'
    [System.IO.File]::WriteAllText($store, '{ not json')
    Assert-Equal 'it is not valid JSON' (Read-StopwatchStore -Path $store).Error 'a store that is not JSON is an error, so nothing writes over it'

    # The hook script itself, against stores of its own: the prompt arrives as JSON on stdin; silent, exit 0.
    $hookScript = Join-Path $RepoRoot 'scripts\dashboard\stopwatch-hook.ps1'
    $hookStore = Join-Path $dir 'hook\stopwatch.json'
    $out = '{"session_id":"s","prompt":"  Stopwatch: From the terminal\nand the rest"}' | & powershell -NoProfile -ExecutionPolicy Bypass -File $hookScript -Hook Prompt -StorePath $hookStore 2>&1
    $exit = $LASTEXITCODE
    $hs = Read-StopwatchStore -Path $hookStore
    Assert-True ($exit -eq 0 -and -not $out -and @($hs.Runs).Count -eq 1 -and $hs.Runs[0].Auto -and $hs.Runs[0].Label -eq 'From the terminal' -and $hs.Runs[0].StartHead -match '^[0-9a-f]{40}$') 'the hook script reads the prompt from stdin and a marked one starts an Auto run, silently'
    $firstId = $hs.Runs[0].Id
    $out = '{"prompt":"just a question"}' | & powershell -NoProfile -ExecutionPolicy Bypass -File $hookScript -Hook Prompt -StorePath $hookStore 2>&1
    $exit = $LASTEXITCODE
    Assert-True ($exit -eq 0 -and -not $out -and @((Read-StopwatchStore -Path $hookStore).Runs).Count -eq 1 -and (Read-StopwatchStore -Path $hookStore).Runs[0].Id -eq $firstId) 'an unmarked prompt leaves the store alone'
    $cheapStore = Join-Path $dir 'hook\cheap.json'
    $out = '{"prompt":"an ordinary prompt"}' | & powershell -NoProfile -ExecutionPolicy Bypass -File $hookScript -Hook Prompt -StorePath $cheapStore 2>&1
    $exit = $LASTEXITCODE
    Assert-True ($exit -eq 0 -and -not $out -and -not (Test-Path -LiteralPath $cheapStore)) 'a payload without the marker ends the hook before it loads anything: exit 0, no output, nothing written'
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $hookScript -Hook Stop -StorePath $hookStore 2>&1
    $exit = $LASTEXITCODE
    Assert-True ($exit -eq 0 -and -not $out -and -not (Read-StopwatchStore -Path $hookStore).Runs[0].End) 'a Stop with HEAD where the run started leaves it going'
    $out = '{"prompt":"stopwatch: again"}' | & powershell -NoProfile -ExecutionPolicy Bypass -File $hookScript -Hook Prompt -StorePath $hookStore 2>&1
    $exit = $LASTEXITCODE
    $hs = Read-StopwatchStore -Path $hookStore
    Assert-True ($exit -eq 0 -and -not $out -and @($hs.Runs).Count -eq 1 -and $hs.Runs[0].Label -eq 'again' -and $hs.Runs[0].Id -ne $firstId) 'a second marked prompt while the run goes discards it and starts the new one'
    [System.IO.File]::WriteAllText($hookStore, '{ not json')
    $out = '{"prompt":"stopwatch: x"}' | & powershell -NoProfile -ExecutionPolicy Bypass -File $hookScript -Hook Prompt -StorePath $hookStore 2>&1
    $exit = $LASTEXITCODE
    Assert-True ($exit -eq 0 -and -not $out -and (Get-Content -LiteralPath $hookStore -Raw) -eq '{ not json') 'the hook never writes over a store that does not read'
    $skipStore = Join-Path $dir 'hook\skip.json'
    [System.IO.File]::WriteAllText($skipStore, '{ "runs": [ { "id": "bad id!", "label": "x", "start": "2026" } ] }')
    $out = '{"prompt":"stopwatch: y"}' | & powershell -NoProfile -ExecutionPolicy Bypass -File $hookScript -Hook Prompt -StorePath $skipStore 2>&1
    Assert-True ((Test-Path -LiteralPath "$skipStore.bak") -and @((Read-StopwatchStore -Path $skipStore).Runs).Count -eq 1) 'a run the write drops is kept in a .bak beside the store'
} finally {
    Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host '-- the model' -ForegroundColor Cyan
$mk = { param($label, $start, $end) @{ Id = "id$start"; Label = $label; Start = (& $at $start); End = $(if ($null -ne $end) { & $at $end } else { $null }); Auto = $true; StartHead = 'a' } }
$m = ConvertTo-StopwatchModel -Runs @((& $mk 'CSS comment' 0 300), (& $mk 'css COMMENT' 1000 1200), (& $mk 'Docs' 2000 2500), (& $mk 'CSS comment' 3000 3250), (& $mk 'Live' 5000 $null))
Assert-True ($m.Running -and $m.Running.Label -eq 'Live') 'the run without an end is the running one'
Assert-Equal 4 $m.Count 'only finished runs are counted'
Assert-Equal 'Live,CSS comment,Docs' (($m.Groups | ForEach-Object { $_.Label }) -join ',') 'labels group case-insensitively, the group with the newest run first, one going now included'
Assert-True (@($m.Groups[0].Rows).Count -eq 0 -and $m.Groups[0].Running.Label -eq 'Live' -and $null -eq $m.Groups[1].Running) 'a label with only a run going has no rows, and only its group holds the running run'
$css = $m.Groups[1]
Assert-Equal '250,200,300' (($css.Rows | ForEach-Object { $_.Seconds }) -join ',') 'a group''s runs are newest first'
Assert-Equal '50,-100,' (($css.Rows | ForEach-Object { $_.DeltaSeconds }) -join ',') 'each against the run before it, and the first against nothing'
Assert-Equal 200 $css.Best 'the best is the shortest run'

Write-Host '-- the slugs (#3323)' -ForegroundColor Cyan
$sl = Get-StopwatchSlugs -Labels @('CSS comment change', 'css COMMENT change', 'Docs', '???', 'Ship it!!')
Assert-Equal 'css-comment-change' $sl['css comment change'] 'a slug is the lower-cased label with every other run turned into one dash'
Assert-Equal 4 @($sl.Keys).Count 'labels that differ only in case are one label'
Assert-Equal 'run' $sl['???'] 'a label with no letter or digit is called run'
Assert-Equal 'ship-it' $sl['ship it!!'] 'trailing punctuation leaves no trailing dash'
Assert-Equal 40 (Get-StopwatchSlugs -Labels @('a' * 100))['a' * 100].Length 'a slug is cut at 40 characters'
$clash = Get-StopwatchSlugs -Labels @('A b', 'a-b', 'Other')
Assert-True ($clash['a b'] -ne $clash['a-b'] -and $clash['a b'] -match '^a-b-[0-9a-f]{6}$' -and $clash['a-b'] -match '^a-b-[0-9a-f]{6}$') 'two labels that slug the same each take a hash suffix and do not merge'
Assert-Equal 'other' $clash['other'] 'a label that collides with nobody keeps its plain slug'
$clash2 = Get-StopwatchSlugs -Labels @('Other', 'a-b', 'A b')
Assert-True ($clash2['a b'] -ceq $clash['a b'] -and $clash2['a-b'] -ceq $clash['a-b']) 'the suffixes depend on the label, not on the order'
$cm = ConvertTo-StopwatchModel -Runs @((& $mk 'A b' 0 10), (& $mk 'a-b' 100 130))
Assert-Equal 2 @($cm.Groups).Count 'the two colliding labels stay two groups'
Assert-True ((Find-StopwatchGroup -Model $cm -Slug $clash['a b']).Label -eq 'A b' -and (Find-StopwatchGroup -Model $cm -Slug $clash['a-b']).Label -eq 'a-b') 'each slug finds its own label'
Assert-True ($null -eq (Find-StopwatchGroup -Model $cm -Slug 'a-b') -and $null -eq (Find-StopwatchGroup -Model $cm -Slug '')) 'a slug no label has finds nothing'
foreach ($g in @($m.Groups)) { Assert-Equal $g.Label (Find-StopwatchGroup -Model $m -Slug $g.Slug).Label ("the slug '$($g.Slug)' finds its group again") }

Write-Host '-- the page' -ForegroundColor Cyan
$page = Format-StopwatchPageHtml -Model $m -StorePath 'C:\x\stopwatch.json' -Now (& $at 5065)
Assert-True ($page -match 'aria-current="page">Stopwatch</span>' -and $page -match '<li><a href="/">Home</a></li>') 'the page has the house shell and its crumb back to the hub'
Assert-True ($page -notmatch '<h1|class="lead"|hub-banner|Runs recorded|id="now"|class="sw-clock') 'the overview is bare: no h1, lead, airsquats banner, tiles or Now section above the cards'
Assert-True ($page -match '<h2>Measurements</h2>' -and $page.IndexOf('<h2>Measurements</h2>') -lt $page.IndexOf('card--link')) 'it opens on the Measurements heading, then the cards'
Assert-True ($page -match 'querySelectorAll\("\[data-start\]"\)') 'the clock script ticks every [data-start] element, the card''s going-now span included'
Assert-Equal 3 ([regex]::Matches($page, '<section class="card card--link">')).Count 'one card per label: CSS comment, Docs and the one only going now'
Assert-True ($page -match 'href="/stopwatch/css-comment"><span class="menu-item__label">CSS comment<span class="menu-item__sub">3 run\(s\) - latest 4:10 - 50.0s slower than the run before</span>') 'a card gives the label, the runs, the latest time and its change, and links the label page'
Assert-True ($page -match 'href="/stopwatch/docs"><span class="menu-item__label">Docs<span class="menu-item__sub">1 run\(s\) - latest 8:20 - first run<') 'a label with one run says first run'
Assert-True ($page -match 'href="/stopwatch/live"><span class="menu-item__label">Live<span class="menu-item__sub">0 run\(s\) - going now <span class="num" data-start="2026-10-23T11:23:20.000Z">1:05</span>') 'the label going now carries its live clock on its card'
Assert-True ($page -notmatch 'Against the run before</th>') 'the overview holds no table of runs; they are on the label page'
Assert-True ($page -notmatch '<section class="card[^"]*">\s*<h2') 'no h2 stands inside a card'
Assert-True ($page -match 'C:\\x\\stopwatch.json') 'the footer names where the runs are kept'
Assert-True ($page -notmatch '<form|<button|<textarea|data-sw=|data-action=|fetch\(|method: "POST"|sw-form') 'the page is read-only: no form, button, textarea or POST script of its own (the hub shell banner checkbox is not the page)'
Assert-True ($page -match 'stopwatch:') 'the page says how a run starts'
$idle = Format-StopwatchPageHtml -Model (ConvertTo-StopwatchModel -Runs @((& $mk 'Docs' 0 10))) -StorePath 's'
Assert-True ($idle -notmatch 'going now' -and $idle -notmatch 'data-start=') 'with nothing running no card carries a clock'
Assert-True ((Format-StopwatchPageHtml -Model (ConvertTo-StopwatchModel -Runs @()) -StorePath 's') -match 'No run yet') 'with no run at all it says so, with no card'
$evil = Format-StopwatchPageHtml -Model (ConvertTo-StopwatchModel -Runs @((& $mk '<script>x</script>' 0 10))) -StorePath 's'
Assert-True ($evil -notmatch '<script>x</script>' -and $evil -match '&lt;script&gt;x&lt;/script&gt;' -and $evil -match 'href="/stopwatch/script-x-script"') 'a label is escaped wherever it is shown, and its slug is URL-safe'
$broken = Format-StopwatchPageHtml -Model (ConvertTo-StopwatchModel -Runs @()) -ReadError 'it is not valid JSON' -StorePath 's'
Assert-True ($broken -match 'could not be read') 'a store that does not read says so'

Write-Host '-- the label page (#3323)' -ForegroundColor Cyan
$cssGroup = Find-StopwatchGroup -Model $m -Slug 'css-comment'
$lp = Format-StopwatchLabelPageHtml -Group $cssGroup -StorePath 's'
Assert-True ($lp -match '<h2>CSS comment</h2>' -and $lp -notmatch 'Back to the Stopwatch' -and $lp -notmatch '<h1|hub-banner') 'the label page is named for the label, leaves the way back to the crumbs and carries no banner'
Assert-True ($lp -match '<li><a href="/">Home</a></li>\s*<li><span class="breadcrumbs__sep"[^>]*>.*?</span><a href="/stopwatch">Stopwatch</a></li>\s*<li><span class="breadcrumbs__sep"[^>]*>.*?</span><span aria-current="page">CSS comment</span></li>') 'the trail reads Home, Stopwatch (linking /stopwatch), then the label'
Assert-True ($lp -match 'badge--good">1:40 faster<' -and $lp -match 'badge--bad">50.0s slower<' -and $lp -match 'first run') 'each run says faster or slower than the one before'
Assert-Equal 3 ([regex]::Matches($lp, '<tr><td')).Count 'every run of the label has a row'
Assert-True ($lp -match '4:10</td>[\s\S]*3:20</td>[\s\S]*5:00</td>') 'the rows run newest first'
Assert-True ($lp -match '3 run\(s\), best 3:20') 'it names the runs and the best'
$live = Format-StopwatchLabelPageHtml -Group (Find-StopwatchGroup -Model $m -Slug 'live') -StorePath 's' -Now (& $at 5065)
Assert-True ($live -match 'class="sw-clock num" data-start="2026-10-23T11:23:20.000Z">1:05<' -and $live -match 'No finished run of this label yet') 'a label with only a run going shows its clock'
$evilGroup = (ConvertTo-StopwatchModel -Runs @((& $mk '<b>x</b>' 0 10))).Groups[0]
Assert-True ((Format-StopwatchLabelPageHtml -Group $evilGroup -StorePath '<i>') -notmatch '<b>x</b>|<i>') 'the label and the store path are escaped on the label page'

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
    $run = @{ Id = 'r1'; Label = 'CSS comment'; Start = (& $at 0); End = (& $at 330); Auto = $true; StartHead = 'a' }
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

    # One label's page asks for its own runs only, and the file is written whole: the others must survive it.
    $twoPath = Join-Path $tdir 'two\stopwatch-phases.json'
    # Windows from an hour ago to now, so the transcript files just written are inside them whatever the clock says.
    $w0 = [datetime]::UtcNow.AddHours(-1)
    $runA = @{ Id = 'ra'; Label = 'A'; Start = $w0; End = $w0.AddSeconds(330); Auto = $true; StartHead = 'a' }
    $runB = @{ Id = 'rb'; Label = 'B'; Start = $w0; End = $w0.AddSeconds(330); Auto = $true; StartHead = 'a' }
    [void](Get-StopwatchTranscriptCache -Runs @($runA, $runB) -CachePath $twoPath -TranscriptDir $tdir)
    $runA2 = @{ Id = 'ra'; Label = 'A'; Start = $w0; End = $w0.AddSeconds(340); Auto = $true; StartHead = 'a' }
    [void](Get-StopwatchTranscriptCache -Runs @($runA2) -CachePath $twoPath -TranscriptDir $tdir)
    $twoDoc = Get-Content -LiteralPath $twoPath -Raw | ConvertFrom-Json
    Assert-True ($null -ne $twoDoc.rb -and $null -ne $twoDoc.ra -and $twoDoc.ra.end -eq (Format-StopwatchStamp $w0.AddSeconds(340))) 'a write for one label keeps the other label''s cached phases'

    $cell = Format-StopwatchTranscriptCell $first.r1 330
    Assert-True ($cell -match 'Waiting on you <span class="num">1:41</span> <span class="note">31%</span>') 'the cell gives each phase its time and its share of the run'
    Assert-True ((Format-StopwatchTranscriptCell @{ Sessions = 0; Phases = @() } 60) -match 'no session') 'a run no session saw says so'
    $tm = ConvertTo-StopwatchModel -Runs @($run)
    Assert-True ((Format-StopwatchLabelPageHtml -Group $tm.Groups[0] -StorePath 's' -Transcript $first) -match 'From the transcripts</th>[\s\S]*Ship: CI wait, merge, fold <span class="num">2:50') 'a label page shows the transcript phases of each run'
} finally {
    Remove-Item -LiteralPath $tdir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host "stopwatch: $script:pass passed, $script:fail failed"
if ($script:fail -gt 0) { exit 1 }
exit 0
