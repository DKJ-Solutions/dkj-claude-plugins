<#
.SYNOPSIS
    Tests for plugins/dkj-policy/hub/lib/logbook-lib.ps1 -- the Logbook page of the dev server (#3364): the label, the hook's rules,
    the store's session list, the hook script itself against a fixture checkout, and the two pages.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Continue'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $RepoRoot 'scripts\lib\dev-pages-lib.ps1')
. (Join-Path $RepoRoot 'plugins\dkj-policy\hub\lib\logbook-lib.ps1')

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else            { $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}
# A statement that throws is skipped under 'Continue', so count it instead (as stopwatch.tests.ps1 does).
trap { $script:fail++; Write-Host "  [FAIL] unhandled terminating error: $_" -ForegroundColor Red; continue }
function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    Assert-True ("$Expected" -eq "$Actual") ($Name + $(if ("$Expected" -ne "$Actual") { " (expected '$Expected', got '$Actual')" } else { '' }))
}

$t0 = [datetime]::new(2026, 10, 24, 10, 0, 0, [DateTimeKind]::Utc)
$at = { param([double]$s) $t0.AddSeconds($s) }

Write-Host '-- the label' -ForegroundColor Cyan
Assert-Equal 'add a card to the hub' (Get-LogbookPromptLabel -Prompt "  add a card to the hub  `nand the rest") 'the label is the prompt''s first line, trimmed'
Assert-Equal 'from a paste' (Get-LogbookPromptLabel -Prompt "<pasted_content id=`"3f0a`">`r`nfrom a paste`r`nmore`r`n</pasted_content id=`"3f0a`">") 'a prompt that is a paste is read from the pasted text''s first line'
Assert-Equal 80 (Get-LogbookPromptLabel -Prompt ('a' * 200)).Length 'it is cut at the label maximum'
Assert-Equal 'Assignment' (Get-LogbookPromptLabel -Prompt "   `n") 'an empty first line is called Assignment'
Assert-Equal 'a b' (Get-LogbookPromptLabel -Prompt ('a' + [char]7 + 'b')) 'a control character becomes a space'

Write-Host '-- the hook rules' -ForegroundColor Cyan
$ev = { param($hook, $runs, $seen, $sid, $s, $branch, $clean, $ship) Invoke-LogbookHookEvent -Hook $hook -Runs $runs -Sessions $seen -SessionId $sid -Now (& $at $s) -Branch $branch -Clean $clean -Head 'aaa' -Trunk 'main' -Prompt "fix the thing`nplease" -ShipInFlight $ship }
$h = & $ev 'Prompt' @() @() 's1' 10 'main' $true $false
Assert-True ($h.Changed -and @($h.Runs).Count -eq 1 -and $h.Runs[0].Session -eq 's1' -and $h.Runs[0].Label -eq 'fix the thing' -and $h.Runs[0].Start -eq (& $at 10) -and -not $h.Runs[0].End -and (@($h.Sessions) -join ',') -eq 's1') 'the first prompt of a new session on a clean trunk starts a run for that session and records the session'
$h2 = & $ev 'Prompt' $h.Runs $h.Sessions 's1' 20 'main' $true $false
Assert-True (-not $h2.Changed -and @($h2.Runs).Count -eq 1) 'a later prompt of the same session starts nothing'
$d = & $ev 'Prompt' @() @() 's2' 10 'feat/x' $true $false
Assert-True ($d.Changed -and @($d.Runs).Count -eq 0 -and (@($d.Sessions) -join ',') -eq 's2') 'a new session on a branch starts no run, but is recorded as seen'
$d2 = & $ev 'Prompt' $d.Runs $d.Sessions 's2' 50 'main' $true $false
Assert-True (-not $d2.Changed -and @($d2.Runs).Count -eq 0) 'so a session that began in the middle of work never starts a run later, even back on the trunk'
Assert-True (@((& $ev 'Prompt' @() @() 's3' 10 'main' $false $false).Runs).Count -eq 0) 'a dirty trunk is not a clean start'
Assert-True (-not (& $ev 'Prompt' @() @() '' 10 'main' $true $false).Changed -and -not (& $ev 'Stop' $h.Runs $h.Sessions '' 10 'main' $true $false).Changed) 'no session id, no decision'
$kept = Invoke-LogbookHookEvent -Hook Prompt -Runs @() -Sessions @(1..$script:LogbookSessionsKept | ForEach-Object { "old$_" }) -SessionId 'new' -Now (& $at 1) -Branch 'x'
Assert-True (@($kept.Sessions).Count -eq $script:LogbookSessionsKept -and $kept.Sessions[-1] -eq 'new' -and $kept.Sessions[0] -eq 'old2') 'the session list keeps the newest ones, dropping the oldest'

$st = & $ev 'Stop' $h.Runs $h.Sessions 's1' 300 'main' $true $false
Assert-True ($st.Changed -and $st.Runs[0].End -eq (& $at 300)) 'a Stop on a clean trunk ends the session''s run, also when HEAD never moved'
Assert-True (-not (& $ev 'Stop' $h.Runs $h.Sessions 's1' 300 'feat/x' $true $false).Changed) 'a Stop on a branch keeps it going: a branch parked for the owner''s eye is not the trunk'
Assert-True (-not (& $ev 'Stop' $h.Runs $h.Sessions 's1' 300 'main' $false $false).Changed) 'a Stop on a dirty trunk keeps it going'
Assert-True (-not (& $ev 'Stop' $h.Runs $h.Sessions 's1' 300 'main' $true $true).Changed) 'a Stop while a ship-pr CI wait is live keeps it going'
Assert-True (-not (& $ev 'Stop' $h.Runs $h.Sessions 'other' 300 'main' $true $false).Changed) 'another session''s Stop leaves this session''s run alone'
$two = @($h.Runs) + @((& $ev 'Prompt' @() @() 's9' 40 'main' $true $false).Runs)
$st2 = & $ev 'Stop' $two @('s1', 's9') 's9' 400 'main' $true $false
Assert-True ($st2.Changed -and -not ($st2.Runs | Where-Object { $_.Session -eq 's1' }).End -and ($st2.Runs | Where-Object { $_.Session -eq 's9' }).End -eq (& $at 400)) 'two sessions side by side each keep their own run'
Assert-True (-not (& $ev 'Stop' $st.Runs $st.Sessions 's1' 500 'main' $true $false).Changed) 'a run that ended is not ended again'

Write-Host '-- the store keeps the sessions; the Stopwatch''s does not grow them' -ForegroundColor Cyan
$dir = Join-Path ([System.IO.Path]::GetTempPath()) ('logbook-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dir | Out-Null
try {
    $store = Join-Path $dir 'logbook.json'
    Save-StopwatchStore -Path $store -Runs $st.Runs -Sessions $st.Sessions
    $rs = Read-StopwatchStore -Path $store
    Assert-True (-not $rs.Error -and @($rs.Runs).Count -eq 1 -and $rs.Runs[0].Session -eq 's1' -and $rs.Runs[0].End -eq (& $at 300) -and (@($rs.Sessions) -join ',') -eq 's1') 'a run''s session and the session list survive a round trip'
    $swStore = Join-Path $dir 'stopwatch.json'
    Save-StopwatchStore -Path $swStore -Runs @(@{ Id = 'w1'; Label = 'x'; Start = (& $at 0); End = $null; Auto = $true; StartHead = 'a' })
    Assert-True ((Get-Content -LiteralPath $swStore -Raw) -notmatch 'session') 'a Stopwatch store is written without a session field or list'
    [System.IO.File]::WriteAllText($swStore, '{ "runs": [], "sessions": [ "ok-1", "bad id!", 7 ] }')
    Assert-Equal 'ok-1' (@((Read-StopwatchStore -Path $swStore).Sessions) -join ',') 'a session id that is not one is dropped on read'

    # The hook script, against a fixture checkout of its own: the libs it loads, git on main, its own store and
    # its own run-progress directory. The payload arrives as JSON on stdin; silent, exit 0.
    $fx = Join-Path $dir 'checkout'
    # The plugin's layout (#3470): the hook under hooks\, its libs under hub\lib\ and dkj-policy's scripts\lib\.
    $fxPlugin = Join-Path $fx 'plugins\dkj-policy'
    New-Item -ItemType Directory -Path (Join-Path $fxPlugin 'hooks'), (Join-Path $fxPlugin 'hub\lib'), (Join-Path $fxPlugin 'scripts\lib') -Force | Out-Null
    foreach ($lib in 'logbook-lib.ps1', 'stopwatch-lib.ps1') { Copy-Item (Join-Path $RepoRoot "plugins\dkj-policy\hub\lib\$lib") (Join-Path $fxPlugin 'hub\lib\') }
    foreach ($lib in 'run-progress-lib.ps1', 'command-probe-lib.ps1') { Copy-Item (Join-Path $RepoRoot "plugins\dkj-policy\scripts\lib\$lib") (Join-Path $fxPlugin 'scripts\lib\') }
    Copy-Item (Join-Path $RepoRoot 'plugins\dkj-policy\hooks\logbook-hook.ps1') (Join-Path $fxPlugin 'hooks\')
    & git -C $fx init -q -b main 2>$null
    & git -C $fx -c user.name=t -c user.email=t@example.invalid add -A 2>$null
    & git -C $fx -c user.name=t -c user.email=t@example.invalid commit -q -m 'first' 2>$null
    $hookScript = Join-Path $fxPlugin 'hooks\logbook-hook.ps1'
    $hookStore = Join-Path $dir 'hook\logbook.json'
    $prog = Join-Path $dir 'progress'
    $run = { param($hook, $json) $o = $json | & powershell -NoProfile -ExecutionPolicy Bypass -File $hookScript -Hook $hook -StorePath $hookStore -RepoRoot $fx -ProgressRoot $prog 2>&1; @{ Out = $o; Exit = $LASTEXITCODE } }

    $r = & $run 'Prompt' '{"session_id":"abc-1","prompt":"Time this one\nand the rest"}'
    $hs = Read-StopwatchStore -Path $hookStore
    Assert-True ($r.Exit -eq 0 -and -not $r.Out -and @($hs.Runs).Count -eq 1 -and $hs.Runs[0].Label -eq 'Time this one' -and $hs.Runs[0].Session -eq 'abc-1' -and $hs.Runs[0].StartHead -match '^[0-9a-f]{40}$') 'the hook script starts a run at the first prompt of a session on a clean main, silently'
    $before = Get-Content -LiteralPath $hookStore -Raw
    $r = & $run 'Prompt' '{"session_id":"abc-1","prompt":"a follow-up"}'
    Assert-True ($r.Exit -eq 0 -and -not $r.Out -and (Get-Content -LiteralPath $hookStore -Raw) -eq $before) 'a second prompt of that session leaves the store untouched'
    [void](Write-RunProgress -Id 'ship-pr-ci-1' -Label 'ship-pr: CI on PR #1' -Root $prog -WriterPid $PID -Workspace $fx)
    $r = & $run 'Stop' '{"session_id":"abc-1"}'
    Assert-True ($r.Exit -eq 0 -and -not $r.Out -and -not (Read-StopwatchStore -Path $hookStore).Runs[0].End) 'a Stop while a ship-pr CI wait is live in this checkout keeps the run going'
    Remove-Item -LiteralPath $prog -Recurse -Force
    [System.IO.File]::WriteAllText((Join-Path $fx 'dirty.txt'), 'x')
    $r = & $run 'Stop' '{"session_id":"abc-1"}'
    Assert-True ($r.Exit -eq 0 -and -not (Read-StopwatchStore -Path $hookStore).Runs[0].End) 'a Stop on a dirty main keeps it going'
    Remove-Item -LiteralPath (Join-Path $fx 'dirty.txt')
    $r = & $run 'Stop' '{"session_id":"abc-1"}'
    Assert-True ($r.Exit -eq 0 -and -not $r.Out -and (Read-StopwatchStore -Path $hookStore).Runs[0].End) 'a Stop on a clean main ends it, though HEAD never moved'
    & git -C $fx checkout -q -b feat/x 2>$null
    $r = & $run 'Prompt' '{"session_id":"abc-2","prompt":"mid-work"}'
    $hs = Read-StopwatchStore -Path $hookStore
    Assert-True ($r.Exit -eq 0 -and @($hs.Runs).Count -eq 1 -and @($hs.Sessions) -ccontains 'abc-2') 'a session whose first prompt finds a branch starts no run, and is remembered'
    $r = & $run 'Prompt' '{"prompt":"no session"}'
    Assert-True ($r.Exit -eq 0 -and -not $r.Out) 'a payload without a session id ends the hook quietly'
    [System.IO.File]::WriteAllText($hookStore, '{ not json')
    $r = & $run 'Prompt' '{"session_id":"abc-3","prompt":"x"}'
    Assert-True ($r.Exit -eq 0 -and -not $r.Out -and (Get-Content -LiteralPath $hookStore -Raw) -eq '{ not json') 'the hook never writes over a store that does not read'
} finally {
    Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host '-- the model and the pages' -ForegroundColor Cyan
$runs = @(
    @{ Id = 'r1'; Label = 'First'; Start = (& $at 0); End = (& $at 120); Auto = $true; StartHead = 'a'; Session = 's1' },
    @{ Id = 'r2'; Label = 'Parked <for> a look'; Start = (& $at 1000); End = $null; Auto = $true; StartHead = 'a'; Session = 's2' },
    @{ Id = 'r3'; Label = 'Side by side'; Start = (& $at 2000); End = $null; Auto = $true; StartHead = 'a'; Session = 's3' }
)
$m = ConvertTo-StopwatchModel -Runs $runs -KeepOpenRuns
Assert-True (@($m.Groups).Count -eq 3 -and @($m.Groups | Where-Object { $_.Running }).Count -eq 2) 'with -KeepOpenRuns every open run is shown as going, not only the newest'
Assert-Equal 2 @((ConvertTo-StopwatchModel -Runs $runs).Groups).Count 'without it the Stopwatch keeps showing only the newest open run'
$lm = ConvertTo-LogbookModel -Runs $runs -Now (& $at (1000 + 24 * 3600 + 500))
Assert-Equal 'Side by side,First' (($lm.Groups | ForEach-Object { $_.Label }) -join ',') 'the Logbook hides an open run older than a day, an abandoned session, and keeps the finished ones'
Assert-Equal 3 @((ConvertTo-LogbookModel -Runs $runs -Now (& $at 2100)).Groups).Count 'and shows every open run younger than that'
$page = Format-LogbookPageHtml -Runs $runs -StorePath 'C:\x\logbook.json' -Now (& $at 2100)
Assert-True ($page -match '<title>[^<]*Logbook' -and $page -match 'href="/logbook/\d{4}-\d{2}-\d{2}-\d{4}"' -and $page -notmatch 'href="/stopwatch') 'the overview is titled Logbook and links its runs under /logbook'
Assert-True ($page -match 'Parked &lt;for&gt; a look' -and $page -notmatch 'Parked <for>') 'a label is escaped'
Assert-True ($page -notmatch 'first run|faster|slower|the run before' -and ([regex]::Matches($page, 'data-start=')).Count -eq 2) 'no change against a run before, and a live clock on each open run'
Assert-True ($page -match 'not shared' -and $page -match 'logbook-hook\.ps1') 'its footer says the store is not shared and names the hook'
$tr = @{ r1 = @{ Sessions = 1; Phases = @(@{ Name = 'Claude working'; Seconds = 45 }, @{ Name = 'Waiting on you'; Seconds = 75 }) } }
$wt = Get-LogbookWorkTimes -Runs $runs -Transcript $tr
Assert-True (@($wt.Keys).Count -eq 1 -and $wt.r1.Work -eq 45 -and $wt.r1.Waiting -eq 75) 'a run''s work time is its time less the time waiting on the owner; an open run has none'
Assert-Equal 0 @((Get-LogbookWorkTimes -Runs $runs -Transcript @{ r1 = @{ Sessions = 0; Phases = @() } }).Keys).Count 'a run no session covered has no work time, rather than all of it'
$wpage = Format-LogbookPageHtml -Runs $runs -Transcript $tr -Now (& $at 2100)
Assert-True ($wpage -match '>First</span><span class="menu-item__value"><span class="sw-time num">2:00<span class="sw-change">work 45\.0s</span></span>' -and $page -notmatch 'work \d') 'the card shows the work time beside the time, and only for a run the transcripts measured'
$speed = @(
    @{ Id = 'f'; Start = (& $at 0); End = (& $at ($script:LogbookFastSeconds - 1)) },
    @{ Id = 'm'; Start = (& $at 0); End = (& $at $script:LogbookFastSeconds) },
    @{ Id = 's'; Start = (& $at 0); End = (& $at $script:LogbookSlowSeconds) },
    @{ Id = 'w'; Start = (& $at 0); End = (& $at ($script:LogbookSlowSeconds * 3)) },
    @{ Id = 'o'; Start = (& $at 0); End = $null }
)
$tones = Get-LogbookSpeedTones -Runs $speed -WorkTimes @{ w = @{ Work = 60; Waiting = 0 } }
Assert-Equal 'fast,medium,slow,fast' ((@('f', 'm', 's', 'w') | ForEach-Object { $tones[$_] }) -join ',') 'a run is fast under the first bound, medium from it, slow from the second, and read off its work time where it has one'
Assert-True (-not $tones.ContainsKey('o')) 'an open run has no speed'
Assert-True ($wpage -match 'class="card card--link sw-card sw-card--fast sw-run"><nav [^>]*><a [^>]*><span class="menu-item__label">[^<]*<span class="menu-item__sub">First<' -and ([regex]::Matches($wpage, '<section class="card card--link sw-card sw-card--')).Count -eq 1 -and $wpage -match 'green under 15 minutes') 'the overview colours a finished run''s card by its speed, leaves an open run uncoloured, and its footer names the bounds'
$g = Find-StopwatchGroup -Model $m -Slug $m.Groups[2].PageSlug
$rp = Format-LogbookRunPageHtml -Group $g -StorePath 'C:\x\logbook.json'
Assert-True ((Format-LogbookRunPageHtml -Group $g -Transcript $tr) -match 'Work 45\.0s, waiting on you 1:15\.' -and $rp -notmatch 'waiting on you \d') 'a run''s page states its work time and its waiting under its time'
Assert-True ($rp -match 'First' -and $rp -match '2:00' -and $rp -match 'href="/logbook"' -and $rp -notmatch 'first run|than the previous run') 'a run''s page shows its time, crumbs back to /logbook, and no change against a run before'

Write-Host '-- a sweep, per issue (#3405)' -ForegroundColor Cyan
$mk = { param([double]$s, $run = 'ship-pr', $step = 'fold') @{ At = (& $at $s); Run = $run; Step = $step; Workspace = 'C:\x' } }
$cm = { param([double]$s, $subject) @{ At = (& $at $s); Subject = $subject } }
$folds = Get-LogbookFolds -Marks @((& $mk 600), (& $mk 500 'ship-pr' 'merge'), (& $mk 1800), (& $mk 900 'stopwatch'), (& $mk 2500)) `
    -Commits @((& $cm 1804 'fold: fix/3397-walk changelog (#3399)'), (& $cm 604 'fold: feat/3392-scope changelog (#3398)'), (& $cm 2000 'merge: feat/3400-x (#3402)'), (& $cm 1500 'fold: feat/3393-elsewhere changelog (#3396)'))
Assert-Equal '600:3392,1800:3397,2500:' (($folds | ForEach-Object { '{0}:{1}' -f ($_.At - $t0).TotalSeconds, $_.Issue }) -join ',') 'every ship-pr fold mark is a fold, named after the fold commit made just after it; a commit minutes before it, or no commit, names none'
Assert-Equal '' (Get-LogbookFolds -Marks @((& $mk 600)) -Commits @((& $cm 604 'fold: docs/no-number changelog (#1)')))[0].Issue 'a fold commit whose branch carries no issue number names none'

$sw = @{ Id = 'sw1'; Label = '/sweep-issues'; Start = (& $at 0); End = (& $at 1830); Auto = $true; StartHead = 'a'; Session = 's1' }
$other = @{ Id = 'o1'; Label = 'fix the thing'; Start = (& $at 100); End = (& $at 700); Auto = $true; StartHead = 'a'; Session = 's2' }
$split = Split-LogbookSweepRuns -Runs @($sw, $other) -Folds $folds
$shape = { param($rs) ($rs | ForEach-Object { '{0}|{1}|{2}-{3}' -f $_.Id, $_.Label, ($_.Start - $t0).TotalSeconds, $(if ($_.End) { ($_.End - $t0).TotalSeconds } else { 'going' }) }) -join ', ' }
Assert-Equal 'sw1-1|/sweep-issues #3392|0-600, o1|fix the thing|100-700, sw1-2|/sweep-issues #3397|600-1800' (& $shape $split) 'a finished sweep becomes one run per issue, clean trunk to clean trunk; its time after the last fold is dropped, and another run is left alone'
Assert-True ($split[0].Session -eq 's1' -and $sw.Id -eq 'sw1' -and $sw.Label -eq '/sweep-issues') 'an issue keeps the sweep''s session, and the stored run is not changed'
$going = $sw.Clone(); $going.End = $null
Assert-Equal 'sw1-1|/sweep-issues #3392|0-600, sw1-2|/sweep-issues #3397|600-1800, sw1-3|/sweep-issues issue 3|1800-going' (& $shape (Split-LogbookSweepRuns -Runs @($going) -Folds @($folds[0], $folds[1]))) 'in a going sweep the issue in progress is going'
Assert-Equal 'sw1-1|/dkj-policy:sweep-issues issue 1|0-600' (& $shape (Split-LogbookSweepRuns -Runs @(@{ Id = 'sw1'; Label = '/dkj-policy:sweep-issues'; Start = (& $at 0); End = (& $at 700) }) -Folds @(@{ At = (& $at 600); Issue = '' }))) 'the plugin-qualified command is a sweep too, and a fold that named no issue is numbered'
Assert-Equal 'sw1|/sweep-issues|0-1830' (& $shape (Split-LogbookSweepRuns -Runs @($sw) -Folds @(@{ At = (& $at 1900); Issue = '1' }))) 'a sweep with no fold inside it stays whole'
Assert-Equal 'o1|fix the thing|100-700' (& $shape (Split-LogbookSweepRuns -Runs @($other) -Folds $folds)) 'a run that is not a sweep is never cut, whatever it shipped'
Assert-Equal 'sw1|/sweep-issues|0-1830' (& $shape (Get-LogbookRuns -Runs @($sw) -StepLogPath '')) 'without a step log the pages show the sweep whole'
$two = @(
    @{ Id = 'a'; Label = '/sweep-issues'; Start = (& $at 0); End = (& $at 2000); Session = 'sa' },
    @{ Id = 'b'; Label = '/sweep-issues'; Start = (& $at 100); End = (& $at 2100); Session = 'sb' }
)
$own = @(@{ At = (& $at 500); Issue = '1'; Session = 'sa' }, @{ At = (& $at 900); Issue = '2'; Session = 'sb' }, @{ At = (& $at 1500); Issue = '3'; Session = 'sa' }, @{ At = (& $at 1900); Issue = '4'; Session = 'sb' })
Assert-Equal 'a-1|/sweep-issues #1|0-500, b-1|/sweep-issues #2|100-900, a-2|/sweep-issues #3|500-1500, b-2|/sweep-issues #4|900-1900' (& $shape (Split-LogbookSweepRuns -Runs $two -Folds $own)) 'two overlapping sweeps from different sessions are each cut only at their own folds (#3534)'
Assert-Equal 'a-1|/sweep-issues #1|0-500, a-2|/sweep-issues #2|500-900' (& $shape (Split-LogbookSweepRuns -Runs @($two[0]) -Folds @(@{ At = (& $at 500); Issue = '1'; Session = '' }, @{ At = (& $at 900); Issue = '2' }))) 'a fold that names no session, written before it did, still cuts every sweep'
Assert-Equal 'sa,sb' (((Get-LogbookFolds -Marks @(@{ At = (& $at 500); Run = 'ship-pr'; Step = 'fold'; Session = 'sa' }, @{ At = (& $at 900); Run = 'ship-pr'; Step = 'fold'; Session = 'sb' })) | ForEach-Object { $_.Session }) -join ',') 'a fold carries the session of its mark'
$old = 24 * 3600 + 3600
$stale = Split-LogbookSweepRuns -Runs @($going) -Folds @($folds[0], @{ At = (& $at ($old - 600)); Issue = '3500' })
$sm = ConvertTo-LogbookModel -Runs $stale -Now (& $at $old)
Assert-True ($stale[-1].RunStart -eq $going.Start -and @($sm.Groups | Where-Object { $_.Running }).Count -eq 0 -and @($sm.Groups).Count -eq 2) 'an open sweep older than a day shows no going lap, even with a fold inside the last hour; its finished laps stay (#3533)'
$young = Split-LogbookSweepRuns -Runs @($going) -Folds @($folds[0], @{ At = (& $at 85000); Issue = '3500' })
Assert-Equal 1 @((ConvertTo-LogbookModel -Runs $young -Now (& $at 86000)).Groups | Where-Object { $_.Running }).Count 'and a sweep under a day old still shows its issue in progress going'

Write-Host ''
Write-Host "logbook: $script:pass passed, $script:fail failed"
if ($script:fail -gt 0) { exit 1 }
exit 0
