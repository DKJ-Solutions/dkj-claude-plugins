<#
.SYNOPSIS
    Tests for plugins/dkj-policy/hub/lib/stopwatch-lib.ps1 -- the Stopwatch page of the dev server (#3315, #3323): the store, the
    hook's rules and the hook script itself, the model the page draws and the read-only page.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Continue'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $RepoRoot 'scripts\lib\dev-pages-lib.ps1')
. (Join-Path $RepoRoot 'plugins\dkj-policy\hub\lib\stopwatch-lib.ps1')

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
Write-Host '-- a pasted prompt (#3336)' -ForegroundColor Cyan
Assert-Equal 'CSS comment change' (Get-StopwatchPromptMarker -Prompt "<pasted_content id=`"3f0a`">`r`nstopwatch: CSS comment change`r`nthe rest`r`n</pasted_content id=`"3f0a`">") 'a prompt that is nothing but a paste is read from the pasted text''s first line'
Assert-True ($null -eq (Get-StopwatchPromptMarker -Prompt "<pasted_content id=`"3f0a`">`nfix this`nstopwatch: x`n</pasted_content id=`"3f0a`">")) 'inside a paste, a marker on a later line is still not a marker'
Assert-True ($null -eq (Get-StopwatchPromptMarker -Prompt "<pasted_content id=`"nothex`">`nstopwatch: x") -and $null -eq (Get-StopwatchPromptMarker -Prompt "fix this`n<pasted_content id=`"3f0a`">`nstopwatch: x")) 'only Claude Code''s own wrapper, as the first line, is skipped'

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

Write-Host '-- a commit made during the run, and a release run (#3400)' -ForegroundColor Cyan
$log = @(ConvertFrom-StopwatchCommitLog -Lines @("$(1792749610) release: v5.30.0 release notes", 'garbage', "$(1792749600)"))
Assert-True ($log.Count -eq 2 -and $log[0].Subject -eq 'release: v5.30.0 release notes' -and $log[0].Time -eq (New-Object DateTime 2026, 10, 23, 10, 0, 10, ([DateTimeKind]::Utc)) -and $log[1].Subject -eq '') 'a %ct %s line becomes a subject and a UTC committer time; a line with no time is skipped'
$going7 = $going.Clone(); $going7.Start = (& $at 6.7)
$withCommits = { param($rs, $cs) Invoke-StopwatchHookEvent -Hook Stop -Runs $rs -Now (& $at 500) -Branch 'main' -Clean $true -Head 'bbb' -Commits $cs }
$older = @{ Subject = 'fold: someone else'; Time = (& $at 1) }
$sameSecond = @{ Subject = 'fold: mine'; Time = (& $at 6) }
Assert-True (-not (& $withCommits @($going7) @($older)).Changed) 'a fast-forward that brought in only commits older than the run stops nothing'
Assert-True (-not (& $withCommits @($going7) @()).Changed) 'an empty commit list stops nothing'
Assert-True ((& $withCommits @($going7) @($older, $sameSecond)).Changed) 'a commit made during the run stops it, from the second the run started in'
$release = $going7.Clone(); $release.Label = 'Release cut'
$cutCommit = @{ Subject = 'release: v5.30.0'; Time = (& $at 300) }
$notes = @{ Subject = 'release: v5.30.0 release notes'; Time = (& $at 400) }
Assert-True (-not (& $withCommits @($release) @($older, $cutCommit)).Changed) 'a release run does not stop on the release commit'
Assert-True ((& $withCommits @($release) @($older, $cutCommit, $notes)).Changed) 'a release run stops on a release-notes commit made during it'
$oldNotes = @{ Subject = 'release: v5.29.0 release notes'; Time = (& $at 2) }
Assert-True (-not (& $withCommits @($release) @($oldNotes)).Changed) 'a release-notes commit from before the run does not stop it'
$lower = $release.Clone(); $lower.Label = 'release patch'
Assert-True ((& $withCommits @($lower) @($notes)).Changed -and -not (& $withCommits @(@{ Id = 'p'; Label = 'Prerelease check'; Start = (& $at 6); End = $null; Auto = $true; StartHead = 'aaa' }) @($older)).Changed) 'the label test is any case and anchored at the start'
Assert-True ((& $stop 'main' $true 'bbb' @($release)).Changed) 'without a commit list (git could not be read) the plain HEAD test still ends the run'

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
    $hookScript = Join-Path $RepoRoot 'plugins\dkj-policy\hooks\stopwatch-hook.ps1'
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

Write-Host '-- one store per repo (#3470)' -ForegroundColor Cyan
Assert-Equal 'dkj-claude-plugins' (Get-HubRepoName -RepoRoot 'C:\src\dkj-solutions\dkj-claude-plugins') 'a checkout is named by its folder'
Assert-Equal 'life-hub' (Get-HubRepoName -RepoRoot 'C:\src\Life-Hub\') 'lowercased, a trailing slash ignored'
Assert-Equal 'my-repo-x' (Get-HubRepoName -RepoRoot 'C:\src\my repo&x') 'anything but a letter, digit, dot, dash or underscore becomes a dash'
Assert-True ((Get-HubRepoKey -RepoRoot 'C:\src\dkj-recipes') -cmatch '^dkj-recipes-[0-9a-f]{8}\z') 'its store key is the name and eight hex of a hash of its path'
Assert-Equal (Get-HubRepoKey -RepoRoot 'C:\src\dkj-recipes') (Get-HubRepoKey -RepoRoot 'C:\src\dkj-recipes-lanes\fix-1') 'a worktree-lane lane is the repo it was cut from'
Assert-Equal (Get-HubRepoKey -RepoRoot 'C:\src\dkj-recipes') (Get-HubRepoKey -RepoRoot 'C:\src\dkj-recipes\.claude\worktrees\agent-a1') 'a Claude Code worktree is the repo it lives in'
Assert-Equal (Get-HubRepoKey -RepoRoot 'C:\src\dkj-recipes') (Get-HubRepoKey -RepoRoot 'c:/SRC/dkj-recipes/') 'the same path in another case or with other slashes is the same repo'
Assert-True ((Get-HubRepoKey -RepoRoot 'C:\a\acme\app') -ne (Get-HubRepoKey -RepoRoot 'C:\b\other\app')) 'two unrelated repos in folders of one name never share a store (Sebastian, #3470)'
$swBase = Join-Path ([System.IO.Path]::GetTempPath()) ('sw-base-' + [guid]::NewGuid().ToString('N'))
$savedLocal = $env:LOCALAPPDATA
try {
    $env:LOCALAPPDATA = $swBase
    $repoA = Join-Path $swBase 'src\repo-a'; $source = Join-Path $swBase 'src\dkj-claude-plugins'
    Assert-Equal (Join-Path $swBase ('dkj-claude-plugins\repos\' + (Get-HubRepoKey -RepoRoot $repoA) + '\stopwatch.json')) (Get-StopwatchStorePath -RepoRoot $repoA) 'the store is the repo''s own, under repos\<repo>-<hash>'
    Assert-True ((Get-StopwatchStorePath -RepoRoot $repoA) -ne (Get-StopwatchStorePath -RepoRoot $source)) 'so two repos on one machine never share a store'
    [void](New-Item -ItemType Directory -Path (Join-Path $swBase 'dkj-claude-plugins') -Force)
    foreach ($n in 'stopwatch.json', 'logbook.json', 'stopwatch-machine.txt') { [System.IO.File]::WriteAllText((Join-Path $swBase "dkj-claude-plugins\$n"), "old $n") }
    Assert-Equal 0 @(Move-HubTimingLegacyStore -RepoRoot $repoA).Count 'a repo that does not carry the plugin''s source takes none of the old machine-wide store'
    $fixtureLike = Join-Path $swBase 'src\fixture'
    [void](New-Item -ItemType Directory -Path (Join-Path $fixtureLike 'plugins\dkj-policy\hub') -Force)
    Assert-Equal 0 @(Move-HubTimingLegacyStore -RepoRoot $fixtureLike).Count 'nor does a tree that carries the plugin''s source under another name, as a test fixture does (measured on #3470)'
    [void](New-Item -ItemType Directory -Path (Join-Path $source 'plugins\dkj-policy\hub') -Force)
    $movedNow = @(Move-HubTimingLegacyStore -RepoRoot $source)
    $srcDir = Split-Path -Parent (Get-StopwatchStorePath -RepoRoot $source)
    Assert-True ($movedNow -contains 'stopwatch.json' -and $movedNow -contains 'logbook.json' -and (Get-Content -LiteralPath (Join-Path $srcDir 'stopwatch.json') -Raw) -eq 'old stopwatch.json' -and -not (Test-Path -LiteralPath (Join-Path $swBase 'dkj-claude-plugins\stopwatch.json'))) 'the source repo takes the old store over as its own, moved rather than copied'
    Assert-True ((Test-Path -LiteralPath (Join-Path $swBase 'dkj-claude-plugins\stopwatch-machine.txt')) -and -not (Test-Path -LiteralPath (Join-Path $srcDir 'stopwatch-machine.txt'))) 'the machine id stays where it was: it names the machine, not a repo'
    [System.IO.File]::WriteAllText((Join-Path $swBase 'dkj-claude-plugins\stopwatch.json'), 'stray')
    Assert-True (@(Move-HubTimingLegacyStore -RepoRoot $source).Count -eq 0 -and (Get-Content -LiteralPath (Join-Path $srcDir 'stopwatch.json') -Raw) -eq 'old stopwatch.json') 'and never moves one over a store the repo already has'
} finally {
    $env:LOCALAPPDATA = $savedLocal
    Remove-Item -LiteralPath $swBase -Recurse -Force -ErrorAction SilentlyContinue
}
$savedShare = $env:DKJ_STOPWATCH_SHARE
try {
    $env:DKJ_STOPWATCH_SHARE = $null
    Assert-True (-not (Test-StopwatchShareEnabled)) 'a repo shares nothing until it opts in'
    $env:DKJ_STOPWATCH_SHARE = '1'
    Assert-True (Test-StopwatchShareEnabled) 'DKJ_STOPWATCH_SHARE=1 opts it in'
    $env:DKJ_STOPWATCH_SHARE = 'yes'
    Assert-True (-not (Test-StopwatchShareEnabled)) 'and nothing but 1 does'
    # A hub server keeps the environment it was started in, so the repo's own settings files are read too (#3470).
    $shareRepo = Join-Path ([System.IO.Path]::GetTempPath()) ('sw-share-' + [guid]::NewGuid().ToString('N'))
    [void](New-Item -ItemType Directory -Path (Join-Path $shareRepo '.claude') -Force)
    $env:DKJ_STOPWATCH_SHARE = $null
    Assert-True (-not (Test-StopwatchShareEnabled -RepoRoot $shareRepo)) 'a repo with no settings file does not share'
    [System.IO.File]::WriteAllText((Join-Path $shareRepo '.claude\settings.json'), '{ "env": { "DKJ_STOPWATCH_SHARE": "1" } }')
    Assert-True (Test-StopwatchShareEnabled -RepoRoot $shareRepo) 'with no variable set, the repo''s .claude/settings.json opts it in'
    [System.IO.File]::WriteAllText((Join-Path $shareRepo '.claude\settings.local.json'), '{ "env": { "DKJ_STOPWATCH_SHARE": "0" } }')
    Assert-True (-not (Test-StopwatchShareEnabled -RepoRoot $shareRepo)) 'and settings.local.json wins where it names the key, so a machine can answer otherwise'
    $env:DKJ_STOPWATCH_SHARE = '1'
    Assert-True (Test-StopwatchShareEnabled -RepoRoot $shareRepo) 'the environment decides wherever it is set, as Claude Code hands it to a hook'
    [System.IO.File]::WriteAllText((Join-Path $shareRepo '.claude\settings.local.json'), '{ not json')
    $env:DKJ_STOPWATCH_SHARE = $null
    Assert-True (Test-StopwatchShareEnabled -RepoRoot $shareRepo) 'a settings file that is not JSON says nothing, so the other one answers'
    Remove-Item -LiteralPath $shareRepo -Recurse -Force -ErrorAction SilentlyContinue} finally { $env:DKJ_STOPWATCH_SHARE = $savedShare }
$lockPath = Join-Path ([System.IO.Path]::GetTempPath()) ('sw-lock-' + [guid]::NewGuid().ToString('N') + '.json')
$held = Get-HubTimingLock -StorePath $lockPath
$other = Start-Job -ScriptBlock { param($lib, $p) . $lib; $m = Get-HubTimingLock -StorePath $p -TimeoutMs 300; [bool]$m } -ArgumentList (Join-Path $RepoRoot 'plugins\dkj-policy\hub\lib\stopwatch-lib.ps1'), $lockPath
$otherGot = Receive-Job -Job $other -Wait -AutoRemoveJob
Assert-True ($null -ne $held -and $otherGot -eq $false) 'while one hook holds a store''s lock, a second waits and does not get it'
$held.ReleaseMutex(); $held.Dispose()
$again = Get-HubTimingLock -StorePath $lockPath
Assert-True ($null -ne $again) 'and gets it once the first has let go'
$again.ReleaseMutex(); $again.Dispose()
Write-Host '-- the model' -ForegroundColor Cyan
$mk = { param($label, $start, $end) @{ Id = "id$start"; Label = $label; Start = (& $at $start); End = $(if ($null -ne $end) { & $at $end } else { $null }); Auto = $true; StartHead = 'a' } }
$stampAt = { param($s) (& $at $s).ToLocalTime().ToString('yyyy-MM-dd-HHmm', [Globalization.CultureInfo]::InvariantCulture) }
$sp = { param($s) (& $at $s).ToLocalTime().ToString('yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture) }
$m = ConvertTo-StopwatchModel -Runs @((& $mk 'CSS comment' 0 300), (& $mk 'css COMMENT' 1000 1200), (& $mk 'Docs' 2000 2500), (& $mk 'CSS comment' 3000 3250), (& $mk 'Live' 5000 $null))
Assert-True ($m.Running -and $m.Running.Label -eq 'Live') 'the run without an end is the running one'
Assert-Equal 4 $m.Count 'only finished runs are counted'
Assert-Equal 'Live,CSS comment,Docs,css COMMENT,CSS comment' (($m.Groups | ForEach-Object { $_.Label }) -join ',') 'every run is a group of its own, also when runs share a label, newest first, the one going now included'
Assert-True (@($m.Groups[0].Rows).Count -eq 0 -and $m.Groups[0].Running.Label -eq 'Live' -and $null -eq $m.Groups[1].Running) 'the run going has no rows, and only its group holds it'
Assert-True (@($m.Groups | Where-Object { @($_.Rows).Count -gt 1 }).Count -eq 0) 'no group holds two runs'
Assert-Equal '1/1,3/3,1/1,2/3,1/3' (($m.Groups | ForEach-Object { [string]$_.Version + '/' + $_.Versions }) -join ',') 'each run knows its place among the runs of its label, case-insensitively, oldest first'
Assert-Equal '250,500,200,300' ((@($m.Groups | Select-Object -Skip 1) | ForEach-Object { $_.Rows[0].Seconds }) -join ',') 'each finished run carries its own time'
Assert-Equal '50,,-100,' ((@($m.Groups | Select-Object -Skip 1) | ForEach-Object { $_.Rows[0].DeltaSeconds }) -join ',') 'each against the previous run of its label, case-insensitively, and a label''s first against nothing'
$gone = ConvertTo-StopwatchModel -Runs @((& $mk 'Old' 0 $null), (& $mk 'New' 100 $null))
Assert-Equal 'New' (($gone.Groups | ForEach-Object { $_.Label }) -join ',') 'a run a later prompt discarded is not shown'

Write-Host '-- the slugs (#3323)' -ForegroundColor Cyan
$sl = Get-StopwatchSlugs -Labels @('CSS comment change', 'css COMMENT change', 'Docs', '???', 'Ship it!!')
Assert-Equal 'css-comment-change' $sl['css comment change'] 'a label slug is the lower-cased label with every other run turned into one dash'
Assert-Equal 4 @($sl.Keys).Count 'labels that differ only in case are one label'
Assert-Equal 'run' $sl['???'] 'a label with no letter or digit is called run'
Assert-Equal 'ship-it' $sl['ship it!!'] 'trailing punctuation leaves no trailing dash'
Assert-Equal 40 (Get-StopwatchSlugs -Labels @('a' * 100))['a' * 100].Length 'a slug is cut at 40 characters'
$clash = Get-StopwatchSlugs -Labels @('A b', 'a-b', 'Other')
Assert-True ($clash['a b'] -ne $clash['a-b'] -and $clash['a b'] -match '^a-b-[0-9a-f]{6}$' -and $clash['a-b'] -match '^a-b-[0-9a-f]{6}$') 'two labels that slug the same each take a hash suffix and do not merge'
Assert-Equal 'other' $clash['other'] 'a label that collides with nobody keeps its plain slug'
Assert-Equal 'hub-lib-comment' (Get-StopwatchSlugs -Labels @('Hub lib comment, start to end'))['hub lib comment, start to end'] 'a slug is made of the label''s short title (the owner, October 25, 2026)'
$short2 = Get-StopwatchSlugs -Labels @('Hub lib comment, start to end', 'Hub lib comment')
Assert-True ($short2['hub lib comment'] -ne $short2['hub lib comment, start to end'] -and $short2['hub lib comment'] -match '^hub-lib-comment-[0-9a-f]{6}$') 'two labels with one short title are kept apart by the hash suffix'
$clash2 = Get-StopwatchSlugs -Labels @('Other', 'a-b', 'A b')
Assert-True ($clash2['a b'] -ceq $clash['a b'] -and $clash2['a-b'] -ceq $clash['a-b']) 'the suffixes depend on the label, not on the order'
foreach ($g in @($m.Groups)) { Assert-Equal $g.Latest (Find-StopwatchGroup -Model $m -Slug $g.PageSlug).Latest ("the slug '$($g.PageSlug)' finds its run again") }
Assert-Equal (& $stampAt 2000) @($m.Groups | Where-Object { $_.Label -eq 'Docs' })[0].PageSlug 'a run''s page is addressed by its start'
Assert-True ($null -eq (Find-StopwatchGroup -Model $m -Slug 'css-comment')) 'a label''s slug is not a run''s: it addresses the label''s page'
$cssLabel = Find-StopwatchLabel -Model $m -Slug 'css-comment'
Assert-True ($cssLabel -and $cssLabel.Title -eq 'CSS comment' -and @($cssLabel.Groups).Count -eq 3 -and $cssLabel.Groups[0].Latest -eq (& $at 3000) -and $cssLabel.Groups[2].Latest -eq (& $at 0)) 'a label''s slug finds every run of that label, case-insensitively, newest first, titled by the newest'
Assert-Equal 'live|css-comment|docs' ((Get-StopwatchLabelSets -Model $m | ForEach-Object { $_.Slug }) -join '|') 'the labels stand in the order of their newest run'
Assert-Equal 'docs|css-comment|live|ship-pr' ((Get-StopwatchOverviewSets -Model $m | ForEach-Object { $_.Slug }) -join '|') 'the overview stands slowest first by its fastest time, then a run going, then a pinned label with no run (the owner, October 25, 2026)'
Assert-True ($null -eq (Find-StopwatchGroup -Model $m -Slug 'nothing') -and $null -eq (Find-StopwatchGroup -Model $m -Slug '') -and $null -eq (Find-StopwatchLabel -Model $m -Slug 'nothing') -and $null -eq (Find-StopwatchLabel -Model $m -Slug '')) 'a slug no run or label has finds nothing'
$twin = ConvertTo-StopwatchModel -Runs @((& $mk 'One' 0 10), (& $mk 'One' 5 20))
$twinSlugs = @($twin.Groups | ForEach-Object { $_.PageSlug })
Assert-True ($twinSlugs.Count -eq 2 -and $twinSlugs[0] -ne $twinSlugs[1] -and $twinSlugs[0] -match '^\d{4}-\d{2}-\d{2}-\d{4}-id\d+$') 'two runs started in the same minute each take their id after the start'

Write-Host '-- the page' -ForegroundColor Cyan
$page = Format-StopwatchPageHtml -Model $m -StorePath 'C:\x\stopwatch.json' -Now (& $at 5065)
Assert-True ($page -match 'aria-current="page">Stopwatch</span>' -and $page -match '<li><a href="/hub">Home</a></li>') 'the page has the house shell and its crumb back to the hub'
Assert-True ((Format-StopwatchPageHtml -Model $m -StorePath 's' -HubHref '/' -RepoName 'dkj-claude-plugins') -match '<li><a href="/">Home</a></li>') 'a hub that answers Home itself passes its own -HubHref, as the source repo''s does (#3470)'
Assert-True ($page -notmatch 'class="lead"|Runs recorded|id="now"|class="sw-clock') 'the overview is bare: no lead, tiles or Now section above the cards'
Assert-True (([regex]::Matches($page, 'id="hub-banner"')).Count -eq 1 -and $page.IndexOf('id="hub-banner"') -lt $page.IndexOf('<h1>')) 'but it carries the airsquats banner once, above the first heading, as every hub page does (#3356)'
Assert-True ($page.IndexOf('<h1>') -lt $page.IndexOf('card--link')) 'it opens on its heading, then the cards'
Assert-Equal 'Stopwatch' (([regex]::Matches($page, '<h1>([^<]+)</h1>') | ForEach-Object { $_.Groups[1].Value }) -join '|') 'the overview has one h1, naming the page, over a card per prompt label'
Assert-True ($page -match '<div class="grid__head"><h1>Stopwatch</h1></div>' -and $page -notmatch 'card__sub') 'its head is its h1 alone: the overview carries no sub line'
Assert-True ($page -match 'querySelectorAll\("\[data-start\]"\)') 'the clock script ticks every [data-start] element, the card''s live time included'
Assert-Equal 4 ([regex]::Matches($page, '<section class="card card--link sw-card">')).Count 'one card per prompt label, case-insensitively: the three CSS comment runs are one card (three labels with runs, plus the pinned Ship PR)'
Assert-True ($page -match '<div class="sw-groups">\r?\n<div class="sw-grid[^"]*">' -and $page -notmatch 'class="grid-3' -and $page -match '\.sw-groups \{ display: grid; gap: var\(--spacing-7\); \}' -and $page -match '\.sw-grid \{ display: grid; grid-template-columns: repeat\(5, minmax\(0, 1fr\)\); gap: var\(--spacing-4\); \}' -and $page -notmatch 'max-width: 1400px') 'the cards stand five to a row, two and one only on a narrow screen, in grids of the page''s own with no top margin, spaced apart by their wrapper''s gap'
Assert-True ($page -match '<section class="card card--link sw-card"><nav class="menu-list" aria-label="CSS comment"><a class="menu-item" href="/stopwatch/css-comment"><div class="menu-item__label"><h2 class="menu-item__title">CSS comment</h2><span class="menu-item__sub">From the prompt <code>stopwatch: CSS comment</code> until Claude is back on the trunk, clean, with a commit of its own\.</span><span class="menu-item__value"><span class="sw-time num">3:20</span></span></div>') 'a label card holds an h2 with the label linking its page, when a run starts and stops, and the fastest time with no change beside it'
Assert-True ($page -match 'href="/stopwatch/docs"><div class="menu-item__label"><h2 class="menu-item__title">Docs</h2>[^\n]*<span class="sw-time num">8:20</span>') 'a label run once shows that run''s time'
Assert-True ($page -match ('href="/stopwatch/live"><div class="menu-item__label"><h2 class="menu-item__title">Live</h2><span class="menu-item__sub">[^\n]+</span><span class="menu-item__value"><span class="sw-time num" data-start="2026-10-23T11:23:20.000Z">1:05</span></span></div>')) 'a label whose only run is going carries its live clock'
Assert-True ($page -notmatch ('href="/stopwatch/' + (& $stampAt 3000) + '"') -and $page -notmatch 'class="sw-change|class="sw-stamp|newest') 'the overview links no run page and shows no run date or change: those are on the label''s page'
Assert-True ($page -match '<div class="sw-grid sw-grid--wide">' -and $page -match '\.sw-grid--wide \{ grid-template-columns: repeat\(3, minmax\(0, 1fr\)\); \}' -and $page.IndexOf('.sw-grid--wide {') -lt $page.IndexOf('@media (max-width: 1000px)')) 'the label cards stand three to a row at most, with the narrow-screen rules after it'
Assert-Equal 'CSS comment' (Get-StopwatchShortTitle 'CSS comment, start to end') 'a short title ends at the first comma'
Assert-Equal 'CSS comment change' (Get-StopwatchShortTitle 'CSS comment change (reconstructed)') 'or at the first parenthesis'
Assert-Equal '(x)' (Get-StopwatchShortTitle '(x)') 'a label with nothing before it keeps itself'
$rel = Format-StopwatchPageHtml -Model (ConvertTo-StopwatchModel -Runs @((& $mk 'Release cut' 0 10))) -StorePath 's'
Assert-True ($rel -match 'until the release notes of the cut are committed\.') 'a release label stops when its release notes are committed (#3400)'

Write-Host '-- the label page' -ForegroundColor Cyan
$labs = (@(Get-StopwatchLabelSets -Model $m) | ForEach-Object { Format-StopwatchLabelPageHtml -Set $_ -StorePath 'C:\x\stopwatch.json' -Now (& $at 5065) }) -join "`n"
$lab = Format-StopwatchLabelPageHtml -Set $cssLabel -StorePath 's'
Assert-True ($lab -match '<li><a href="/hub">Home</a></li>\s*<li><span class="breadcrumbs__sep"[^>]*>.*?</span><a href="/clock">Clock</a></li>\s*<li><span class="breadcrumbs__sep"[^>]*>.*?</span><a href="/stopwatch">Stopwatch</a></li>\s*<li><span class="breadcrumbs__sep"[^>]*>.*?</span><span aria-current="page">CSS comment</span></li>') 'the trail reads Home, Clock, Stopwatch (linking /stopwatch), then the label'
Assert-True ($lab -notmatch 'class="lead"' -and ([regex]::Matches($lab, 'id="hub-banner"')).Count -eq 1 -and $lab.IndexOf('id="hub-banner"') -lt $lab.IndexOf('<h1>')) 'it is bare like the overview, and carries the banner once, above its heading'
Assert-Equal 'CSS comment' (([regex]::Matches($lab, '<h1>([^<]+)</h1>') | ForEach-Object { $_.Groups[1].Value }) -join '|') 'it opens with an h1, the label, and has no other h1 (the owner, October 25, 2026: a page always begins with an h1)'
Assert-True ($lab -notmatch '<h2>') 'and a label that is not pinned has no h2 under it'
Assert-True (([regex]::Matches($lab, '<section class="card card--link sw-card sw-run">')).Count -eq 3 -and $lab.IndexOf('v3</span>') -lt $lab.IndexOf('v2</span>') -and $lab.IndexOf('v2</span>') -lt $lab.IndexOf('v1</span>')) 'it holds every run of the label, each a card, newest first'
Assert-True ($lab -match '\.sw-grid \{ display: grid; grid-template-columns: repeat\(5,' -and $lab -match 'C:\\x\\stopwatch.json|<code>s</code>') 'the run cards stand in the page''s own five-column grid, and the footer names the store'
Assert-True ($labs -match ('<section class="card card--link sw-card sw-run"><nav class="menu-list" aria-label="' + [regex]::Escape((& $sp 3000)) + '"><a class="menu-item" href="/stopwatch/css-comment/' + (& $stampAt 3000) + '"><span class="menu-item__label">' + [regex]::Escape((& $sp 3000)) + '<span class="menu-item__sub">CSS comment v3</span><span class="menu-item__value"><span class="sw-time num">4:10 <span class="sw-change sw-change--bad">-25%</span></span></span></span>')) 'a run card holds three lines: the run''s start, its label linking the run''s page under the label''s, and its time with its change in percent beside it'
$longSet = @(Get-StopwatchLabelSets -Model (ConvertTo-StopwatchModel -Runs @((& $mk 'Hub lib comment, start to end' 0 10))))[0]
$long = Format-StopwatchLabelPageHtml -Set $longSet -StorePath 's'
Assert-True ($long -match '<h1>Hub lib comment</h1>' -and $long -match '<title>[^<]*Hub lib comment</title>' -and $long -match '<span aria-current="page">Hub lib comment</span>' -and $long -match ('href="/stopwatch/hub-lib-comment/[^"]+"><span class="menu-item__label">[^<]*<span class="menu-item__sub">Hub lib comment</span>') -and $long -notmatch '>Hub lib comment, start to end<') 'a label page names the label by its short title, in its heading, its title, its crumb and its run cards (the owner, October 25, 2026)'
$longRun = Format-StopwatchRunPageHtml -Group $longSet.Groups[0] -StorePath 's' -LabelCrumb
Assert-True ($longRun -notmatch '<p class="card__sub">Hub lib comment</p>' -and $longRun -match '<a href="/stopwatch/hub-lib-comment">Hub lib comment</a>') 'with -LabelCrumb a run page names its label by its short title in the crumb, and only there'
Assert-True ($labs -match '<span class="sw-time num">3:20 <span class="sw-change sw-change--good">\+33%</span></span>') 'a faster run carries a plus and the percent of the run before'
Assert-True ($labs -match ('<span class="menu-item__label">' + [regex]::Escape((& $sp 2000)) + '<span class="menu-item__sub">Docs</span><span class="menu-item__value"><span class="sw-time num">8:20</span></span>')) 'a label''s first run has no change beside its time'
Assert-True ($labs -notmatch 'than the run before|first run' -and $page -notmatch 'than the run before|first run') 'a card carries no words for its change'
Assert-True ($labs -match '>css COMMENT v2</span>' -and $labs -notmatch '>(Docs|Live) v\d') 'a label run more than once carries its version behind it as a muted note, a label run once none'
Assert-True ($labs -match ('<span class="menu-item__label">' + [regex]::Escape((& $sp 5000)) + '<span class="menu-item__sub">Live</span><span class="menu-item__value"><span class="sw-time num" data-start="2026-10-23T11:23:20.000Z">1:05</span></span>')) 'the run going now carries its live clock as its time'
Assert-True ($page -notmatch '<section class="card[^"]*">(?:(?!</section>).)*<(h[13-6]|dt)' -and $labs -notmatch '<section class="card[^"]*">(?:(?!</section>).)*<(h[1-6]|dt)') 'a card holds no heading and no header above its lines: its header is its first line, set in a house text size and weight'
Assert-True ((Format-StopwatchLabelPageHtml -Set @(Get-StopwatchLabelSets -Model (ConvertTo-StopwatchModel -Runs @((& $mk '<b>x</b>' 0 10))))[0] -StorePath '<i>') -notmatch '<b>x</b>|<i>') 'the label and the store path are escaped on the label page'
Assert-True ($labs -notmatch 'run\(s\)|\d runs?,') 'a run card counts no runs: it is one'
Assert-True ($page -match '\.sw-run \.menu-item__label \{ font-weight: 800; \}' -and $page -match '\.sw-change \{ [^}]*font-size: var\(--text-xs\); font-weight: 400;') 'the start is the card''s heaviest line (base, 800), the prompt label its least visible line, the time light (300), its change small and regular'
$cardCss = @([regex]::Matches($page, '\.sw-(stamp|instruction|time|change)[^{]*\{[^}]*\}') | ForEach-Object { $_.Value })
Assert-True ($cardCss.Count -ge 4 -and -not @($cardCss | Where-Object { ([regex]::Matches($_, 'font-size: var\(--([a-z0-9-]+)\)') | Where-Object { $_.Groups[1].Value -notin 'text-lg', 'text-base', 'text-sm', 'text-xs' }) -or ([regex]::Matches($_, 'font-weight: (\d+)') | Where-Object { $_.Groups[1].Value -notin '300', '400', '500', '600', '700', '800' }) }).Count) 'a card''s text takes only --text-lg, -base, -sm or -xs and only the weights 300 to 800'
Assert-Equal ' <span class="sw-change">0%</span>' (Format-StopwatchChangePercent -Seconds 100.2 -DeltaSeconds 0.2) 'under half a second is 0%'
Assert-Equal ' <span class="sw-change sw-change--bad">-&lt;1%</span>' (Format-StopwatchChangePercent -Seconds 1000 -DeltaSeconds 2) 'a change under one percent is not rounded to nothing'
Assert-True ($page -notmatch 'Against the run before</th>') 'the overview holds no table of runs'
Assert-True ($labs -notmatch '<section class="card[^"]*">\s*<h2') 'a run card carries no h2: only a label card is titled'
Assert-True ($page -match 'C:\\x\\stopwatch.json') 'the footer names where the runs are kept'
Assert-True ($page.Replace((Format-RepoHubBanner), '') -notmatch '<form|<button|<textarea|data-sw=|data-action=|fetch\(|method: "POST"|sw-form') 'the page is read-only: no form, button, textarea or POST script of its own (the hub shell banner, which asks its own server since #3438, is not the page)'
Assert-True ($page -match 'stopwatch:') 'the page says how a run starts'
$idle = Format-StopwatchPageHtml -Model (ConvertTo-StopwatchModel -Runs @((& $mk 'Docs' 0 10))) -StorePath 's'
Assert-True ($idle -notmatch 'going now' -and $idle -notmatch 'data-start=') 'with nothing running no card carries a clock'
$none = Format-StopwatchPageHtml -Model (ConvertTo-StopwatchModel -Runs @()) -StorePath 's'
Assert-True ($none -match 'No run yet' -and ([regex]::Matches($none, 'card--link')).Count -eq 1) 'with no run at all it says so, and the only label card is the pinned one'

Write-Host '-- the pinned Ship PR label: a card and a page of its own, the steps on the page (the owner, October 25, 2026)' -ForegroundColor Cyan
# Before its first run the label already has its card, linking its own page, and that page holds the steps.
$pinnedCard = [regex]::Match($none, '<section class="card card--link sw-card"><nav class="menu-list" aria-label="Ship PR"><a class="menu-item" href="/stopwatch/ship-pr">.*?</section>')
Assert-True $pinnedCard.Success 'with no Ship PR run the overview still carries a Ship PR card, linking its own page'
Assert-True ($pinnedCard.Value -match '<code>stopwatch: Ship PR</code>' -and $pinnedCard.Value -match '<span class="sw-time">No run yet</span>') 'it names the prompt and says no run has been made'
Assert-True ($none -notmatch 'sw-steps">') 'the steps are not on the overview: a card is the way in'
$noneModel = ConvertTo-StopwatchModel -Runs @()
$shipSet = Find-StopwatchLabel -Model $noneModel -Slug 'ship-pr'
Assert-True ($null -ne $shipSet -and $shipSet.Title -eq 'Ship PR' -and @($shipSet.Groups).Count -eq 0) 'its page resolves before its first run, so the card''s link is never a 404'
$shipPage = Format-StopwatchLabelPageHtml -Set $shipSet -StorePath 's'
Assert-True ($shipPage -match '<div class="grid__head"><h1>Ship PR</h1></div>' -and $shipPage -match 'No run yet\. The first one sets the baseline') 'the page heads its runs with the label and says none has been made'
Assert-True ($shipPage -match '<div class="grid__head"><h2>How to time it</h2></div>\s*<section class="card sw-card"><ol class="sw-steps">(<li>[^<]+</li>){5}</ol></section>') 'and holds the five steps in one card, under an h2 of their own above it'
Assert-True ($shipPage -match 'exactly &quot;stopwatch: Ship PR&quot;' -and $shipPage -match 'ship-pr\.ps1' -and $shipPage -match 'the CI wait') 'the steps say which first line to use, what to ship, and which steps a run''s page splits out'
Assert-True ($shipPage -notmatch '<section class="card[^"]*">\s*<h2') 'no h2 stands inside a card on that page'
# THE PROMPT TO COPY (the owner, October 25, 2026): above the steps, pasteable unchanged, with a copy button.
Assert-True ($shipPage -match '<div class="grid__head"><h2>The prompt</h2></div>\s*<section class="card sw-card"><pre class="sw-prompt" id="sw-prompt">stopwatch: Ship PR\nShip the branch that is checked out now with ship-pr\.ps1\. Change nothing else\.</pre>') 'the page carries the prompt in a block of its own: the marker line, then the line that asks for the ship alone'
Assert-True ($shipPage.IndexOf('<h2>The prompt</h2>') -lt $shipPage.IndexOf('<h2>How to time it</h2>')) 'the prompt stands above the steps that refer to it'
Assert-True ($shipPage -match '<button type="button" class="btn" data-copy="sw-prompt">Copy the prompt</button>' -and $shipPage -match 'navigator\.clipboard\.writeText\(document\.getElementById\(b\.getAttribute\("data-copy"\)\)\.textContent\)') 'a house button copies the block''s text to the clipboard'
Assert-True ($shipPage.Replace((Format-RepoHubBanner), '') -notmatch '<form|method: "POST"|fetch\(') 'and the page still writes nothing: no form, POST or fetch'
Assert-True ($shipPage -match '\.sw-prompt \{ [^}]*background: var\(--paper-2\); color: var\(--fg-1\);[^}]*font-size: var\(--text-sm\);' -and $shipPage -notmatch '\.btn \{') 'the block is drawn from house tokens, and the house button is used, not restyled'
Assert-True ($shipPage -match 'pasting the prompt above' -and $shipPage -match 'the checkout left on it') 'the steps point at the prompt, and say to leave the checkout on the branch it ships'
# Once a run of it exists, it is an ordinary label: the run card on its page, the steps still under it.
$shipModel = ConvertTo-StopwatchModel -Runs @((& $mk 'ship pr' 0 10))
$shipRun = Format-StopwatchPageHtml -Model $shipModel -StorePath 's'
Assert-Equal 1 ([regex]::Matches($shipRun, '>(?i:ship pr)</h2>')).Count 'with a Ship PR run, case aside, the overview has one card for it, not two'
Assert-True ($shipRun -notmatch 'sw-steps">') 'and that card carries no steps either'
$shipRunPage = Format-StopwatchLabelPageHtml -Set (Find-StopwatchLabel -Model $shipModel -Slug 'ship-pr') -StorePath 's'
Assert-True ($shipRunPage -match 'card card--link sw-card' -and $shipRunPage -notmatch 'No run yet' -and $shipRunPage -match '<ol class="sw-steps">') 'its page holds the run card and the steps, and no longer says no run was made'
$cssPage = Format-StopwatchLabelPageHtml -Set $cssLabel -StorePath 's'
Assert-True ($cssPage -notmatch 'sw-steps">|How to time it|sw-prompt"|data-copy') 'a label that is not pinned has no steps and no prompt on its page'
$flatNone = Format-StopwatchPageHtml -Model $noneModel -StorePath 's' -Flat
# THE h1 NAMES THE PAGE ITS BREADCRUMB NAMES: it was a fixed "Measurements" on the Logbook and on an empty overview.
$flatRun = Format-StopwatchPageHtml -Model (ConvertTo-StopwatchModel -Runs @((& $mk 'Docs' 0 10))) -StorePath 's' -Flat -Route '/logbook' -PageTitle 'Logbook'
Assert-True ($flatRun -match '<div class="grid__head"><h1>Logbook</h1></div>' -and $flatRun -notmatch 'Measurements') 'the flat overview''s h1 is its -PageTitle, as the Logbook passes it'
Assert-True ($none -match '<div class="grid__head"><h1>Stopwatch</h1></div>' -and $none -notmatch 'Measurements') 'and an empty overview is headed with its page title too'
# EVERY PAGE BEGINS WITH AN h1 (the owner, October 25, 2026): the overview, a label's page with or without runs,
# and the Logbook's flat overview. The run page is held to it beside its own asserts below.
foreach ($pg in @(@{ N = 'the overview'; H = $page }, @{ N = 'an empty overview'; H = $none }, @{ N = 'a label page'; H = $cssPage }, @{ N = 'the Ship PR page'; H = $shipPage }, @{ N = 'the flat overview'; H = $flatNone })) {
    $first = [regex]::Match($pg.H, '<(h[1-6])[\s>]')
    Assert-Equal 'h1' $first.Groups[1].Value "$($pg.N) begins with an h1"
}
Assert-True ($flatNone -notmatch 'Ship PR') 'the Logbook''s flat overview carries no pinned card'
Assert-True ($none -match '\.sw-steps \{ [^}]*font-size: var\(--text-sm\); font-weight: 400; color: var\(--muted\); \}') 'the steps take the instruction line''s house size, weight and colour'
$evil = Format-StopwatchPageHtml -Model (ConvertTo-StopwatchModel -Runs @((& $mk '<script>x</script>' 0 10))) -StorePath 's'
Assert-True ($evil -notmatch '<script>x</script>' -and $evil -match '&lt;script&gt;x&lt;/script&gt;' -and $evil -match 'href="/stopwatch/script-x-script"' -and (ConvertTo-StopwatchModel -Runs @((& $mk '<script>x</script>' 0 10))).Groups[0].LabelSlug -eq 'script-x-script') 'a label is escaped wherever it is shown, and its slugs are URL-safe'
$empty = Format-StopwatchPageHtml -Model (ConvertTo-StopwatchModel -Runs @()) -StorePath 's' -Shared
Assert-True ($empty -match 'no other machine has shared a run yet' -and $empty -notmatch 'being fetched|location\.reload') 'with no sync under way an empty origin is stated, and the page does not reload'
$unshared = Format-StopwatchPageHtml -Model (ConvertTo-StopwatchModel -Runs @()) -StorePath 's'
Assert-True ($unshared -match 'Not shared with this repo''s other machines' -and $unshared -match 'DKJ_STOPWATCH_SHARE=1' -and $unshared -notmatch 'refs/stopwatch/') 'a repo that does not opt in is told its runs stay on this machine, and how to share them (#3470)'
$fetching = Format-StopwatchPageHtml -Model (ConvertTo-StopwatchModel -Runs @()) -StorePath 's' -Fetching -Shared
Assert-True ($fetching -match 'being fetched' -and $fetching -match 'still being fetched' -and $fetching -notmatch 'no other machine has shared' -and $fetching -match 'location\.reload') 'while the first sync fetches, the page says so instead of an empty origin, and reloads (#3377)'
# #3403: a later visit's fetch is said too, and the copy of the other machines' runs carries its age.
$later = Format-StopwatchPageHtml -Model (ConvertTo-StopwatchModel -Runs @()) -StorePath 's' -SharedMachines 2 -Fetching
Assert-True ($later -match 'Checking origin for newer runs' -and $later -match 'location\.reload' -and $later -notmatch 'are being fetched from origin') 'a fetch on a later visit, with machines already shown, says it checks for newer runs and reloads (#3403)'
$when = [datetime]::SpecifyKind([datetime]'2026-10-24 09:30:00', 'Utc')
$aged = Format-StopwatchPageHtml -Model (ConvertTo-StopwatchModel -Runs @()) -StorePath 's' -SharedMachines 2 -LastFetched $when -Shared
Assert-True ($aged -match ('the runs of 2 other machines are shown with these, as last fetched ' + [regex]::Escape($when.ToLocalTime().ToString('yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture)) + '\.') -and $aged -notmatch 'location\.reload') 'the footer names when the other machines'' runs were last fetched, in local time (#3403)'
Assert-True ($empty -notmatch 'as last fetched') 'with no fetch on record no time is claimed'
$broken = Format-StopwatchPageHtml -Model (ConvertTo-StopwatchModel -Runs @()) -ReadError 'it is not valid JSON' -StorePath 's'
Assert-True ($broken -match 'could not be read') 'a store that does not read says so'

Write-Host '-- the run page (#3323)' -ForegroundColor Cyan
$lp = Format-StopwatchRunPageHtml -Group (Find-StopwatchGroup -Model $m -Slug (& $stampAt 3000)) -StorePath 's'
Assert-True ($lp -match ('<h1>' + [regex]::Escape((& $sp 3000)) + '</h1><p class="card__sub">CSS comment</p>') -and ([regex]::Matches($lp, '<h1>')).Count -eq 1 -and ([regex]::Matches($lp, 'id="hub-banner"')).Count -eq 1 -and $lp.IndexOf('id="hub-banner"') -lt $lp.IndexOf('<h1>')) 'a run''s page is named by its start, its label beneath, and carries the banner once, above its heading (#3356)'
Assert-True ($lp -match ('<li><a href="/hub">Home</a></li>\s*<li><span class="breadcrumbs__sep"[^>]*>.*?</span><a href="/clock">Clock</a></li>\s*<li><span class="breadcrumbs__sep"[^>]*>.*?</span><a href="/stopwatch">Stopwatch</a></li>\s*<li><span class="breadcrumbs__sep"[^>]*>.*?</span><span aria-current="page">' + [regex]::Escape((& $sp 3000)) + '</span></li>')) 'the trail reads Home, Clock, Stopwatch (linking /stopwatch), then the run''s start'
$lpLabel = Format-StopwatchRunPageHtml -Group (Find-StopwatchGroup -Model $m -Slug (& $stampAt 3000)) -StorePath 's' -LabelCrumb
Assert-True ($lpLabel -match ('<a href="/stopwatch">Stopwatch</a></li>\s*<li><span class="breadcrumbs__sep"[^>]*>.*?</span><a href="/stopwatch/css-comment">CSS comment</a></li>\s*<li><span class="breadcrumbs__sep"[^>]*>.*?</span><span aria-current="page">' + [regex]::Escape((& $sp 3000)) + '</span></li>')) 'with -LabelCrumb the trail passes the run''s label page on the way to the run'
Assert-True ($lpLabel -match ('<h1>' + [regex]::Escape((& $sp 3000)) + '</h1></div>')) 'with -LabelCrumb the label is not said again beneath the heading'
Assert-True ($lp -notmatch 'card__title">Time<' -and $lp -match '<p class="note">No phases read for this run yet\.</p><p><strong>Total</strong> <span class="num">4:10</span> <span class="sw-change sw-change--bad">-25%</span></p>' -and $lp -notmatch 'slower|than the previous run') 'with no phases yet, its total and its change against the previous run of its label, a sign and a percent as on the label page, stand under the reason, not on a Time card of their own'
Assert-True ($lp -notmatch '<h2>Runs</h2>' -and $lp -notmatch 'Against the run before' -and $lp -notmatch '3:20|5:00') 'it holds this run only: no Runs heading, no table, no other run''s time'
Assert-True ((Format-StopwatchRunPageHtml -Group (Find-StopwatchGroup -Model $m -Slug (& $stampAt 0)) -StorePath 's') -notmatch 'first run|class="sw-change') 'a label''s first run carries no change and no words for it, as on the label page'
$live = Format-StopwatchRunPageHtml -Group (Find-StopwatchGroup -Model $m -Slug (& $stampAt 5000)) -StorePath 's' -Now (& $at 5065)
Assert-True ($live -match 'class="sw-clock num" data-start="2026-10-23T11:23:20.000Z">1:05<' -and $live -notmatch 'table-wrap|<strong>Total</strong>') 'the run going shows its clock, and no phases yet'
$evilGroup = (ConvertTo-StopwatchModel -Runs @((& $mk '<b>x</b>' 0 10))).Groups[0]
Assert-True ((Format-StopwatchRunPageHtml -Group $evilGroup -StorePath '<i>') -notmatch '<b>x</b>|<i>') 'the label and the store path are escaped on the run page'

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
    $gone = Get-StopwatchTranscriptCache -Runs @($moved) -CachePath $cachePath -TranscriptDir $tdir
    Assert-True (-not $gone.ContainsKey('r1')) 'a run whose end changed is read again, and with no transcript covering it any more it is left out, not filed as all waiting (#3350)'
    Assert-True (@((Get-Content -LiteralPath $cachePath -Raw | ConvertFrom-Json).PSObject.Properties.Name) -notcontains 'r1') 'and its stale entry leaves the cache file'
    [System.IO.File]::WriteAllText($tfile, ($lines -join "`n"), (New-Object System.Text.UTF8Encoding($false)))
    (Get-Item -LiteralPath $tfile).LastWriteTimeUtc = (& $at 330)
    [System.IO.File]::WriteAllText($cachePath, '{ not json')
    Assert-True ((Get-StopwatchTranscriptCache -Runs @($run) -CachePath $cachePath -TranscriptDir $tdir).ContainsKey('r1')) 'a cache that does not read is recomputed'
    $nowhere = Join-Path $tdir 'nowhere\stopwatch-phases.json'
    $blind = Get-StopwatchTranscriptCache -Runs @($run) -CachePath $nowhere -TranscriptDir (Join-Path $tdir 'no-such-dir')
    Assert-True (-not $blind.ContainsKey('r1') -and -not (Test-Path -LiteralPath $nowhere)) 'with no transcript to read nothing is cached, so a wrong folder is not filed for good'

    # A RUN WHOSE TRANSCRIPTS WERE PRUNED (#3350): a newer transcript still exists, but none spans the run's start.
    $pdir = Join-Path $tdir 'pruned'
    [void](New-Item -ItemType Directory -Path $pdir -Force)
    $newer = Join-Path $pdir 'newer.jsonl'
    [System.IO.File]::WriteAllText($newer, (& $rec 1000 'user' 'a later session'))
    (Get-Item -LiteralPath $newer).LastWriteTimeUtc = (& $at 1000)
    $prunedPath = Join-Path $pdir 'cache\stopwatch-phases.json'
    $pruned = Get-StopwatchTranscriptCache -Runs @($run) -CachePath $prunedPath -TranscriptDir $pdir
    Assert-True (-not $pruned.ContainsKey('r1') -and -not (Test-Path -LiteralPath $prunedPath)) 'a run no transcript covers is neither returned nor cached, though a newer transcript was there to read'
    $legacyPath = Join-Path $pdir 'legacy\stopwatch-phases.json'
    [void](New-Item -ItemType Directory -Path (Split-Path -Parent $legacyPath) -Force)
    [System.IO.File]::WriteAllText($legacyPath, ('{"r1":{"end":"' + (& $stamp 330) + '","sessions":0,"phases":[{"name":"Waiting on you","seconds":330}]}}'))
    $legacy = Get-StopwatchTranscriptCache -Runs @($run) -CachePath $legacyPath -TranscriptDir $pdir
    Assert-True (-not $legacy.ContainsKey('r1') -and @((Get-Content -LiteralPath $legacyPath -Raw | ConvertFrom-Json).PSObject.Properties.Name) -notcontains 'r1') 'a run cached as all waiting before #3350 is judged again, and dropped when nothing covers it'
    $late = Join-Path $pdir 'late.jsonl'
    [System.IO.File]::WriteAllText($late, ((& $rec 30 'user' 'time this'), (& $rec 40 'assistant' @(@{ type = 'text'; text = 'ok' }))) -join "`n")
    (Get-Item -LiteralPath $late).LastWriteTimeUtc = (& $at 330)
    $covered = Get-StopwatchTranscriptCache -Runs @($run) -CachePath $legacyPath -TranscriptDir $pdir
    Assert-Equal 1 $covered.r1.Sessions 'a transcript whose first record lands within a minute of the start covers the run (the prompt hook stamps the start first)'
    [System.IO.File]::WriteAllText($legacyPath, ('{"r1":{"end":"' + (& $stamp 330) + '","sessions":0,"phases":[{"name":"Waiting on you","seconds":330}]}}'))
    $stamped = (Get-Item -LiteralPath $legacyPath).LastWriteTimeUtc
    $quiet = Get-StopwatchTranscriptCache -Runs @($run) -CachePath $legacyPath -TranscriptDir $pdir
    Assert-True ($quiet.r1.Sessions -eq 0 -and (Get-Item -LiteralPath $legacyPath).LastWriteTimeUtc -eq $stamped) 'an entry with no session whose run IS covered is taken from the cache as it stands, not recomputed and rewritten on every load'

    # One run's page asks for its own run only, and the file is written whole: the others must survive it.
    $twoPath = Join-Path $tdir 'two\stopwatch-phases.json'
    # Windows from an hour ago to now, covered by a transcript of their own, whatever the clock says.
    $w0 = [datetime]::UtcNow.AddHours(-1)
    $twoDir = Join-Path $tdir 'two-transcripts'
    [void](New-Item -ItemType Directory -Path $twoDir -Force)
    [System.IO.File]::WriteAllText((Join-Path $twoDir 'now.jsonl'), ('{"parentUuid":"p","type":"user","isSidechain":false,"message":{"role":"user","content":"go"},"timestamp":"' + (Format-StopwatchStamp $w0) + '"}'))
    $runA = @{ Id = 'ra'; Label = 'A'; Start = $w0; End = $w0.AddSeconds(330); Auto = $true; StartHead = 'a' }
    $runB = @{ Id = 'rb'; Label = 'B'; Start = $w0; End = $w0.AddSeconds(330); Auto = $true; StartHead = 'a' }
    [void](Get-StopwatchTranscriptCache -Runs @($runA, $runB) -CachePath $twoPath -TranscriptDir $twoDir)
    $runA2 = @{ Id = 'ra'; Label = 'A'; Start = $w0; End = $w0.AddSeconds(340); Auto = $true; StartHead = 'a' }
    [void](Get-StopwatchTranscriptCache -Runs @($runA2) -CachePath $twoPath -TranscriptDir $twoDir)
    $twoDoc = Get-Content -LiteralPath $twoPath -Raw | ConvertFrom-Json
    Assert-True ($null -ne $twoDoc.rb -and $null -ne $twoDoc.ra -and $twoDoc.ra.end -eq (Format-StopwatchStamp $w0.AddSeconds(340))) 'a write for one label keeps the other label''s cached phases'

    $card = Format-StopwatchPhaseCard $first.r1 330 -Title 'T'
    Assert-True ($card -match '<tr><td class="sw-left">Waiting on you</td><td class="num">1:41</td><td class="num">31%</td>') 'a phase card gives each phase a row of its own, with its time and its share of the run'
    Assert-True ($card -match 'class="sw-bar" role="img" aria-label="31%"><span style="width: 31%">') 'and a bar as wide as its share'
    $secs = @([regex]::Matches($card, '<tr><td class="sw-left">[^<]+</td><td class="num">([^<]+)</td>') | ForEach-Object { $_.Groups[1].Value })
    Assert-Equal 5 $secs.Count 'every phase of the run has a row'
    Assert-Equal '2:50' $secs[0] 'the longest phase comes first'
    Assert-True ((Format-StopwatchPhaseCard @{ Sessions = 0; Phases = @() } 60 -Title 'T') -match 'No session of this repo') 'a run no session saw says so'
    Assert-True ((Format-StopwatchPhaseCard @{ Sessions = 1; Phases = @() } 60 -Title 'T') -match 'No phases read' -and (Format-StopwatchPhaseCard @{ Sessions = 1; Phases = @() } 60 -Title 'T') -notmatch '<table') 'a run with a session but no phases gets a line, not an empty table'
    Assert-True ((Format-StopwatchPhaseCard @{ Sessions = 2; Phases = @(@{ Name = 'x'; Seconds = 1 }) } 60 -Title 'T') -match '<div class="card__head"><h3 class="card__title">T</h3><p class="card__sub">2 sessions</p></div>') 'the card heading follows the house card head, with the sessions under the title'
    Assert-True ((Format-StopwatchPhaseCard $null 60 -Title '<b>') -match 'No phases read' -and (Format-StopwatchPhaseCard $null 60 -Title '<b>') -notmatch '<b>') 'a run with no phases yet says so, and the title is escaped'
    $tm = ConvertTo-StopwatchModel -Runs @($run)
    $tp = Format-StopwatchRunPageHtml -Group $tm.Groups[0] -StorePath 's' -Transcript $first
    Assert-True ($tp -match '<section class="card"><div class="table-wrap">[\s\S]*Ship: CI wait, merge, fold</td><td class="num">2:50' -and $tp -notmatch '<h2>Phases</h2>|split into phases') 'a run page shows its phases in a card of their own, with no section heading above it'
    $startOnce = (& $at 0).ToLocalTime().ToString('yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture)
    Assert-Equal 1 ([regex]::Matches(($tp -replace '<title>[\s\S]*?</title>' -replace '<nav[\s\S]*?</nav>'), [regex]::Escape($startOnce))).Count 'the run''s start shows once on its page, in the heading, not again on the Time or the phase card'
    Assert-Equal 1 ([regex]::Matches($tp, '>5:30<').Count) 'the run''s time shows once, on the Time card'
    Assert-True ((Format-StopwatchPhaseCard @{ Sessions = 1; Phases = @(@{ Name = 'x'; Seconds = 1 }) } 60) -notmatch 'card__head|<h3') 'a phase card with no title and one session has no empty head'
    Assert-True ($tp -notmatch 'From the transcripts') 'and the runs table no longer crams them into one cell'
    Assert-True ($tp -notmatch '<h2>Runs</h2>' -and $tp -notmatch 'Against the run before' -and $tp -match '</tbody><tfoot><tr><th class="sw-left" scope="row">Total</th><td class="num"><strong>5:30</strong></td><td></td><td class="sw-left"></td></tr></tfoot>' -and $tp -notmatch 'card__title">Time<') 'a run''s total closes its phases table, beside its change against the run before, with no Time card, no Runs heading and no comparison table'
    $startText = (& $at 0).ToLocalTime().ToString('yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture)
    Assert-True ($tp -match ('<h1>' + [regex]::Escape($startText) + '</h1><p class="card__sub">CSS comment</p>') -and $tp -match ('<span aria-current="page">' + [regex]::Escape($startText) + '</span>')) 'a run page is titled with its start, in the heading and the crumb, the label beneath'

    # A SHIP SPLIT BY ITS STEP MARKS (#3338). The ship above runs 30-200; ship-pr marks its gates at 40, its CI
    # wait at 60, its merge at 180 and its fold at 190.
    $sm = { param([double]$s, $step, $ws = 'C:\repo') @{ At = (& $at $s); Run = 'ship-pr'; Step = $step; Workspace = $ws } }
    $shipMarks = @((& $sm 40 'gates'), (& $sm 60 'ci-wait'), (& $sm 180 'merge'), (& $sm 190 'fold'))
    $split = Get-StopwatchTranscriptPhases -Events @($ev) -From (& $at 0) -To (& $at 330) -ShipMarks $shipMarks
    Assert-Equal 'Ship: checks before the PR=10;Ship: local gates and opening the PR=20;Ship: CI wait=120;Ship: merge=10;Ship: fold and close-out=10;Branch and claim=10;Other tool calls=1;Claude thinking and writing=48;Waiting on you=101' ((@($split.Phases) | ForEach-Object { "$($_.Name)=$([Math]::Round($_.Seconds))" }) -join ';') 'a ship call is cut at its step marks, each step lasting until the next mark or the call''s end'
    $segs = Split-StopwatchShipTool -Tool @{ Phase = 'Ship: CI wait, merge, fold'; Start = (& $at 0); End = (& $at 100) } -Marks @((& $sm 50 'forward'), (& $sm 70 'something-new'), (& $sm 150 'merge'))
    Assert-Equal 'Ship: checks before the PR,Ship: forwarded head, re-certified,Ship: CI wait, merge, fold' (($segs | ForEach-Object { $_.Phase }) -join ',') 'a mark outside the call is not its, and a step the page does not know keeps the ship''s own phase'
    Assert-Equal 1 @(Split-StopwatchShipTool -Tool @{ Phase = 'Branch and claim'; Start = (& $at 0); End = (& $at 100) } -Marks $shipMarks).Count 'a call that is not a ship is never cut'
    Assert-Equal 'Ship: CI wait, merge, fold' (@(Split-StopwatchShipTool -Tool @{ Phase = 'Ship: CI wait, merge, fold'; Start = (& $at 0); End = (& $at 20) } -Marks $shipMarks))[0].Phase 'a ship with no mark inside it stays one phase'

    # The cache reads the marks from the step log, and only this checkout's. The transcript was emptied above, so it is written again.
    [System.IO.File]::WriteAllText($tfile, ($lines -join "`n"), (New-Object System.Text.UTF8Encoding($false)))
    (Get-Item -LiteralPath $tfile).LastWriteTimeUtc = (& $at 330)
    $stepLog = Join-Path $tdir 'steps\run-steps.jsonl'
    foreach ($mk2 in @($shipMarks + @((& $sm 100 'merge' 'C:\other-checkout')))) {
        [void](Add-RunStepMark -Run $mk2.Run -Step $mk2.Step -Path $stepLog -NowUtc $mk2.At -Workspace $mk2.Workspace)
    }
    $stepped = Get-StopwatchTranscriptCache -Runs @($run) -CachePath (Join-Path $tdir 'stepped\stopwatch-phases.json') -TranscriptDir $tdir -StepLogPath $stepLog -RepoRoot 'C:\repo'
    Assert-Equal '120' ([string][Math]::Round((@($stepped.r1.Phases | Where-Object { $_.Name -eq 'Ship: CI wait' })[0]).Seconds)) 'the cache cuts a ship at this checkout''s marks, and another checkout''s mark at 100 does not cut it'
} finally {
    Remove-Item -LiteralPath $tdir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host "stopwatch: $script:pass passed, $script:fail failed"
if ($script:fail -gt 0) { exit 1 }
exit 0
