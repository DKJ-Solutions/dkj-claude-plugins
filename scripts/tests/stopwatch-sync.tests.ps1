<#
.SYNOPSIS
    Tests for plugins/dkj-policy/hub/lib/stopwatch-sync-lib.ps1 -- the Stopwatch's shared copy (#3349): the machine id, the ASCII
    payload and its round trip, the merge, the sync interval, and a publish and a read between two clones of a
    bare origin of their own, which must leave each clone's index, working tree and HEAD as they were.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Continue'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $RepoRoot 'scripts\lib\dev-pages-lib.ps1')
. (Join-Path $RepoRoot 'plugins\dkj-policy\hub\lib\stopwatch-lib.ps1')
. (Join-Path $RepoRoot 'plugins\dkj-policy\hub\lib\stopwatch-sync-lib.ps1')

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

$t0 = [datetime]::new(2026, 10, 23, 10, 0, 0, [DateTimeKind]::Utc)
$at = { param([double]$s) $t0.AddSeconds($s) }
# A label with a character above 0x7E, composed from its code point (the script layer is ASCII).
$accent = 'Caf' + [char]0x00E9 + ' fix'
$done1 = @{ Id = '20261023-100000-aaaa'; Label = $accent; Start = (& $at 0); End = (& $at 90); Auto = $true; StartHead = 'h1' }
$done2 = @{ Id = '20261023-110000-bbbb'; Label = 'Docs'; Start = (& $at 3600); End = (& $at 3700); Auto = $true; StartHead = 'h2' }
$going = @{ Id = '20261023-120000-cccc'; Label = 'Docs'; Start = (& $at 7200); End = $null; Auto = $true; StartHead = 'h3' }
$phases = @{ $done1.Id = @{ End = (Format-StopwatchStamp $done1.End); Sessions = 2; Phases = @(@{ Name = 'Local gates and tests'; Seconds = 60.12345 }, @{ Name = 'Waiting on you'; Seconds = 29.87655 }) } }

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('stopwatch-sync-tests-' + [guid]::NewGuid().ToString('N'))
try {
    [void](New-Item -ItemType Directory -Path $tmp -Force)

    # --- The machine id ---
    $id = Get-StopwatchMachineId -StoreDir (Join-Path $tmp 'store')
    Assert-True ($id -cmatch '^[0-9a-f]{8}$') 'a machine id is eight hex, written the first time it is asked for'
    Assert-Equal $id (Get-StopwatchMachineId -StoreDir (Join-Path $tmp 'store')) 'and the same id comes back after that'
    [System.IO.File]::WriteAllText((Join-Path $tmp 'store\stopwatch-machine.txt'), 'not an id')
    $id2 = Get-StopwatchMachineId -StoreDir (Join-Path $tmp 'store')
    Assert-True ($id2 -cmatch '^[0-9a-f]{8}$' -and $id2 -ne 'not an id') 'a file that holds no id is replaced by a new one'

    # --- The payload ---
    $json = ConvertTo-StopwatchSharedJson -MachineId 'abcdef01' -Runs @($done2, $going, $done1) -Phases $phases
    Assert-True ($json -cmatch '^[\x00-\x7E]*$') 'the payload is pure ASCII, an accent included'
    Assert-True (-not $json.Contains("`r")) 'and has LF line ends, as git hands a blob back'
    Assert-Equal $json (ConvertTo-StopwatchSharedJson -MachineId 'abcdef01' -Runs @($done1, $done2) -Phases $phases) 'the same finished runs in another order give the same text, and a run going is not published'
    $back = ConvertFrom-StopwatchSharedJson -Text $json
    Assert-True ($back.Machine -eq 'abcdef01' -and @($back.Runs).Count -eq 2) 'the payload reads back with its machine and its two finished runs'
    Assert-Equal $accent $back.Runs[0].Label 'a label with an accent survives the round trip'
    Assert-True ($back.Runs[0].Start -eq $done1.Start -and $back.Runs[0].End -eq $done1.End -and $back.Runs[0].Machine -eq 'abcdef01') 'a run keeps its start and end, and carries the machine it came from'
    Assert-True ($back.Phases.ContainsKey($done1.Id) -and $back.Phases[$done1.Id].Sessions -eq 2 -and @($back.Phases[$done1.Id].Phases).Count -eq 2) 'its phases come back by run id'
    Assert-True (-not $back.Phases.ContainsKey($done2.Id)) 'a run published without phases has none on the other side, so the page says none were read'
    Assert-True ($null -eq (ConvertFrom-StopwatchSharedJson -Text 'not json') -and $null -eq (ConvertFrom-StopwatchSharedJson -Text '{"machine":"NOPE","runs":[]}')) 'text that is not a payload, or names no machine id, is no payload'
    $onePhase = @{ $done2.Id = @{ End = (Format-StopwatchStamp $done2.End); Sessions = 1; Phases = @(@{ Name = 'Subagents'; Seconds = 100 }) } }
    Assert-True ((ConvertTo-StopwatchSharedJson -MachineId 'abcdef01' -Runs @($done2) -Phases $onePhase) -match '"phases":\s*\[') 'a run with one phase publishes its phases as an array, not a bare object'
    $poison = '{"machine":"abcdef01","runs":[{"id":"p1","label":"Bad","start":"2026-10-23T10:00:00.000Z","end":"2026-10-23T10:01:00.000Z","sessions":"x","phases":[{"name":"N","seconds":"abc"}]},' +
        '{"id":"p2","label":"' + ('L' * 300) + '","start":"2026-10-23T11:00:00.000Z","end":"2026-10-23T11:01:00.000Z","sessions":99999,"phases":[{"name":"N","seconds":1e9}]}]}'
    $pz = ConvertFrom-StopwatchSharedJson -Text $poison
    Assert-True ($pz -and @($pz.Runs).Count -eq 1 -and $pz.Runs[0].Id -eq 'p2') 'a run with values that do not parse is skipped, and the rest of the payload still reads'
    Assert-True ($pz.Runs[0].Label.Length -eq 80 -and $pz.Phases.p2.Sessions -eq 1000 -and $pz.Phases.p2.Phases[0].Seconds -eq 60) 'another machine''s label, session count and phase time are bounded'
    $withOpen ='{"machine":"abcdef01","runs":[{"id":"x1","label":"L","start":"2026-10-23T10:00:00.000Z","end":null}]}'
    Assert-Equal 0 @((ConvertFrom-StopwatchSharedJson -Text $withOpen).Runs).Count 'a run without an end in a payload is dropped'

    # --- The merge ---
    $remote = $done1.Clone(); $remote.Machine = 'abcdef01'; $remote.Label = 'remote copy'
    $other = @{ Id = '20261023-090000-dddd'; Label = 'Other'; Start = (& $at -3600); End = (& $at -3500); Auto = $true; Machine = 'abcdef01' }
    $merged = Merge-StopwatchRuns -Local @($done1, $done2) -Shared @($remote, $other)
    Assert-True (@($merged).Count -eq 3 -and $merged[0].Id -eq $other.Id) 'the merge keeps every run once, oldest first'
    Assert-Equal $accent ((@($merged | Where-Object { $_.Id -eq $done1.Id }))[0].Label) 'a shared run with a local run''s id loses to the local one'

    # --- Hiding a run or a label (#3446) ---
    $h1 = @(Set-StopwatchHiddenEntry -Entries @() -Kind 'run' -Value $done1.Id -Now (& $at 100))
    Assert-True (@($h1).Count -eq 1 -and $h1[0].Hidden) 'a hide entry is written for a run id'
    Assert-True ($null -eq (Set-StopwatchHiddenEntry -Kind 'run' -Value 'not an id!' -Now (& $at 100)) -and $null -eq (Set-StopwatchHiddenEntry -Kind 'other' -Value 'x')) 'a value that is no run id, or an unknown kind, writes nothing'
    $vis = Select-StopwatchVisibleRuns -Runs @($done1, $done2, $going) -Entries $h1
    Assert-True (@($vis).Count -eq 2 -and -not @($vis | Where-Object { $_.Id -eq $done1.Id }).Count) 'a hidden run is left out, the others stay'
    $byLabel = Set-StopwatchHiddenEntry -Entries @() -Kind 'label' -Value 'Docs' -Now (& $at 100)
    $vis = Select-StopwatchVisibleRuns -Runs @($done1, $done2, $going) -Entries $byLabel
    Assert-True (@($vis).Count -eq 2 -and @($vis | Where-Object { $_.Id -eq $going.Id }).Count) 'a label hide leaves out its finished runs, but never a run still going'
    Assert-Equal 3 @(Select-StopwatchVisibleRuns -Runs @($done1, $done2, $going) -Entries (Set-StopwatchHiddenEntry -Kind 'label' -Value 'docs' -Now (& $at 100))).Count 'a label is matched exactly, case included'
    $shownElsewhere = @(Set-StopwatchHiddenEntry -Kind 'run' -Value $done1.Id -Hidden $false -Now (& $at 200))
    Assert-Equal 3 @(Select-StopwatchVisibleRuns -Runs @($done1, $done2, $going) -Entries (@($h1) + $shownElsewhere)).Count 'a newer show entry from another machine undoes the hide'
    $olderShow = @(Set-StopwatchHiddenEntry -Kind 'run' -Value $done1.Id -Hidden $false -Now (& $at 50))
    Assert-Equal 2 @(Select-StopwatchVisibleRuns -Runs @($done1, $done2, $going) -Entries (@($h1) + $olderShow)).Count 'an older show entry does not'
    $again = @(Set-StopwatchHiddenEntry -Entries $h1 -Kind 'run' -Value $done1.Id -Hidden $false -Now (& $at 300))
    Assert-True (@($again).Count -eq 1 -and -not $again[0].Hidden) 'this machine''s own entry for a run is replaced, not added to'
    $hidePath = Join-Path $tmp 'hide\stopwatch-hidden.json'
    Assert-Equal 0 @((Read-StopwatchHidden -Path $hidePath).Entries).Count 'a missing hide file is no entries'
    $accentHide = Set-StopwatchHiddenEntry -Entries $h1 -Kind 'label' -Value $accent -Now (& $at 100)
    Save-StopwatchHidden -Path $hidePath -Entries $accentHide
    $readHide = Read-StopwatchHidden -Path $hidePath
    Assert-True ([System.IO.File]::ReadAllText($hidePath) -cmatch '^[\x00-\x7E]*$' -and @($readHide.Entries).Count -eq 2 -and @($readHide.Entries | Where-Object { $_.Value -ceq $accent }).Count) 'the hide file is ASCII and reads back, an accented label included'
    [System.IO.File]::WriteAllText($hidePath, 'not json')
    Assert-Equal 'it is not valid JSON' (Read-StopwatchHidden -Path $hidePath).Error 'a hide file that does not read is an error, so nothing publishes or writes over it'
    Assert-Equal $json (ConvertTo-StopwatchSharedJson -MachineId 'abcdef01' -Runs @($done1, $done2) -Phases $phases -Hidden @()) 'a machine with no hide entries publishes the same text as before'
    $hj = ConvertFrom-StopwatchSharedJson -Text (ConvertTo-StopwatchSharedJson -MachineId 'abcdef01' -Runs @($done1) -Phases @{} -Hidden $accentHide)
    Assert-True (@($hj.Hidden).Count -eq 2 -and @($hj.Hidden | Where-Object { $_.Kind -eq 'run' -and $_.Value -eq $done1.Id -and $_.Hidden }).Count) 'hide entries travel in the payload and read back'
    $badHide = '{"machine":"abcdef01","runs":[],"hidden":[{"kind":"run","value":"../x","at":"2026-10-23T10:00:00.000Z","hidden":true},{"kind":"label","value":"' + ('L' * 300) + '","at":"2026-10-23T10:00:00.000Z","hidden":true},{"kind":"run","value":"ok-1","at":"never","hidden":true}]}'
    $bh = ConvertFrom-StopwatchSharedJson -Text $badHide
    Assert-True (@($bh.Hidden).Count -eq 1 -and $bh.Hidden[0].Value.Length -eq 80) 'another machine''s hide entries are bounded: a bad run id or time is dropped, a long label cut'
    $twoCases = @(Set-StopwatchHiddenEntry -Kind 'label' -Value 'Docs' -Now (& $at 100)) + @(Set-StopwatchHiddenEntry -Kind 'label' -Value 'docs' -Hidden $false -Now (& $at 200))
    Assert-True ((Get-StopwatchHiddenState -Entries $twoCases).Labels.ContainsKey('Docs')) 'a show of a label in other case does not undo the hide: two cases are two labels'
    Save-StopwatchHidden -Path $hidePath -Entries $h1
    Assert-True ([System.IO.File]::ReadAllText($hidePath) -match '"hidden":\s*\[') 'one hide entry is written as an array, not a bare object'
    # The erase (#3453): the recording machine drops a hidden finished run from its own store, never a run still going.
    $eraseStore = Join-Path $tmp 'erase\stopwatch.json'
    Save-StopwatchStore -Path $eraseStore -Runs @($done1, $done2, $going)
    $er = Remove-StopwatchHiddenFromStore -StorePath $eraseStore -Entries $byLabel
    $left = @((Read-StopwatchStore -Path $eraseStore).Runs)
    Assert-True (@($er.Erased).Count -eq 1 -and $er.Erased[0] -eq $done2.Id -and $left.Count -eq 2 -and @($left | Where-Object { $_.Id -eq $going.Id }).Count) 'a label hide erases its finished run from the store, and keeps the run still going'
    $goingHide = @(Set-StopwatchHiddenEntry -Kind 'run' -Value $going.Id -Now (& $at 100))
    Assert-True (-not @((Remove-StopwatchHiddenFromStore -StorePath $eraseStore -Entries $goingHide).Erased).Count -and @((Read-StopwatchStore -Path $eraseStore).Runs | Where-Object { $_.Id -eq $going.Id }).Count) 'a run still going is not erased even when its own run id is hidden'
    $before = [System.IO.File]::GetLastWriteTimeUtc($eraseStore)
    Start-Sleep -Milliseconds 20
    $none = Remove-StopwatchHiddenFromStore -StorePath $eraseStore -Entries (@($byLabel) + $shownElsewhere)
    Assert-True (-not @($none.Erased).Count -and -not $none.Error -and [System.IO.File]::GetLastWriteTimeUtc($eraseStore) -eq $before) 'nothing hidden is nothing erased, and the store is not rewritten'
    [System.IO.File]::WriteAllText($eraseStore, '{"runs":[{"id":"20261023-100000-aaaa","label":"x","start":"2026-10-23T10:00:00.000Z","end":"2026-10-23T10:01:00.000Z"},{"id":"bad id!"}]}')
    $skip = Remove-StopwatchHiddenFromStore -StorePath $eraseStore -Entries $h1
    Assert-True (-not @($skip.Erased).Count -and $skip.Error -match 'do not parse' -and ([System.IO.File]::ReadAllText($eraseStore)) -match 'bad id!') 'a store with a run that does not parse is not rewritten, since that run would be lost'
    $future ='{"machine":"abcdef01","runs":[],"hidden":[{"kind":"label","value":"Docs","at":"9999-12-31T00:00:00.000Z","hidden":true}]}'
    Assert-Equal 0 @((ConvertFrom-StopwatchSharedJson -Text $future).Hidden).Count 'a hide entry dated far ahead is dropped, since no show could ever be newer'

    # --- The interval ---
    $stamp = Join-Path $tmp 'sync.stamp'
    Assert-True (Test-StopwatchSyncDue -StampPath $stamp) 'with no stamp a sync is due'
    [System.IO.File]::WriteAllText($stamp, 'x')
    Assert-True (-not (Test-StopwatchSyncDue -StampPath $stamp -Now ([datetime]::UtcNow))) 'a fresh stamp holds the next sync back'
    Assert-True (Test-StopwatchSyncDue -StampPath $stamp -Now ([datetime]::UtcNow.AddMinutes(6))) 'and lets it through once the interval has passed'

    # --- A sync under way (#3377) ---
    $syncLog = Join-Path $tmp 'sync.log'
    Assert-True (-not (Test-StopwatchSyncRunning -StampPath (Join-Path $tmp 'none.stamp') -LogPath $syncLog)) 'with no stamp no sync is under way'
    Assert-True (Test-StopwatchSyncRunning -StampPath $stamp -LogPath $syncLog) 'a fresh stamp and no log yet: the first sync is under way'
    [System.IO.File]::WriteAllText($syncLog, 'x')
    (Get-Item -LiteralPath $syncLog).LastWriteTimeUtc = (Get-Item -LiteralPath $stamp).LastWriteTimeUtc.AddSeconds(-30)
    Assert-True (Test-StopwatchSyncRunning -StampPath $stamp -LogPath $syncLog) 'a log older than the stamp is the sync before: this one is under way'
    (Get-Item -LiteralPath $syncLog).LastWriteTimeUtc = (Get-Item -LiteralPath $stamp).LastWriteTimeUtc.AddSeconds(4)
    Assert-True (-not (Test-StopwatchSyncRunning -StampPath $stamp -LogPath $syncLog)) 'a log newer than the stamp: the sync has ended'
    Remove-Item -LiteralPath $syncLog
    Assert-True (-not (Test-StopwatchSyncRunning -StampPath $stamp -LogPath $syncLog -Now ([datetime]::UtcNow.AddMinutes(6)))) 'a sync that died without its log stops counting once the stamp has aged'

    # --- Publish and read between two clones of a bare origin ---
    $origin = Join-Path $tmp 'origin.git'
    $a = Join-Path $tmp 'a'; $b = Join-Path $tmp 'b'
    & git init --quiet --bare $origin 2>$null
    & git init --quiet $a 2>$null
    foreach ($kv in @(@('user.name', 'Test'), @('user.email', 'test@example.invalid'))) { & git -C $a config $kv[0] $kv[1] }
    [System.IO.File]::WriteAllText((Join-Path $a 'README.md'), "seed`n")
    & git -C $a add README.md 2>$null; & git -C $a commit --quiet -m seed 2>$null
    & git -C $a remote add origin $origin; & git -C $a push --quiet origin HEAD:refs/heads/main 2>$null
    & git clone --quiet $origin $b 2>$null
    foreach ($kv in @(@('user.name', 'Test'), @('user.email', 'test@example.invalid'))) { & git -C $b config $kv[0] $kv[1] }
    [System.IO.File]::WriteAllText((Join-Path $a 'dirty.txt'), "work in progress`n")
    $headA = (& git -C $a rev-parse HEAD); $statusA = @(& git -C $a status --porcelain)

    # A payload names the machine whose ref holds it; a ref holding another machine's payload is not read (below).
    $json = ConvertTo-StopwatchSharedJson -MachineId 'aaaaaaa1' -Runs @($done1, $done2) -Phases $phases
    Assert-True (Receive-StopwatchShared -RepoRoot $a) 'a fetch from an origin with no stopwatch ref yet answers'
    $p = Publish-StopwatchShared -RepoRoot $a -MachineId 'aaaaaaa1' -Json $json -TempDir (Join-Path $tmp 'ta')
    Assert-Equal 'pushed' $p.Status 'the first publish pushes this machine''s ref'
    Assert-True ((@(& git -C $a status --porcelain) -join '|') -eq ($statusA -join '|') -and (& git -C $a rev-parse HEAD) -eq $headA) 'and leaves the working tree, the index and HEAD as they were'
    Assert-True (@(& git -C $a branch --list --all) -join ' ' -notmatch 'stopwatch') 'and creates no branch'
    $ident = @(& git -C $origin log -1 '--format=%an <%ae>|%cn <%ce>|%ai' 'refs/stopwatch/aaaaaaa1')[0]
    Assert-True ($ident -like 'stopwatch <stopwatch@noreply.invalid>|stopwatch <stopwatch@noreply.invalid>|* +0000') 'the commit names a neutral identity and a UTC date, not this machine''s git name or time zone'
    Assert-Equal 'unchanged' (Publish-StopwatchShared -RepoRoot $a -MachineId 'aaaaaaa1' -Json $json -TempDir (Join-Path $tmp 'ta')).Status 'the same text again is not pushed'

    Assert-True (Receive-StopwatchShared -RepoRoot $b) 'the other machine fetches it'
    $seen = Read-StopwatchShared -RepoRoot $b -MachineId 'bbbbbbb2'
    Assert-True ($seen.Machines -eq 1 -and @($seen.Runs).Count -eq 2 -and $seen.Phases.ContainsKey($done1.Id)) 'and reads the first machine''s runs and phases'
    Assert-Equal $accent ((@($seen.Runs | Where-Object { $_.Id -eq $done1.Id }))[0].Label) 'with the accent intact after git'
    Assert-Equal 0 (Read-StopwatchShared -RepoRoot $b -MachineId 'aaaaaaa1').Machines 'a machine skips its own copy'

    $done3 = @{ Id = '20261023-130000-eeee'; Label = 'Docs'; Start = (& $at 9000); End = (& $at 9100); Auto = $true }
    $json2 = ConvertTo-StopwatchSharedJson -MachineId 'aaaaaaa1' -Runs @($done1, $done2, $done3) -Phases $phases
    $p2 = Publish-StopwatchShared -RepoRoot $a -MachineId 'aaaaaaa1' -Json $json2 -TempDir (Join-Path $tmp 'ta')
    $parent = (& git -C $origin rev-parse 'refs/stopwatch/aaaaaaa1^')
    Assert-True ($p2.Status -eq 'pushed' -and $parent -eq $p.Message) 'a later publish is a fast-forward on top of the copy before it'
    [void](Receive-StopwatchShared -RepoRoot $b)
    Assert-Equal 3 @((Read-StopwatchShared -RepoRoot $b -MachineId 'bbbbbbb2').Runs).Count 'and the other machine sees the new run after its next fetch'

    $foreign = ConvertTo-StopwatchSharedJson -MachineId 'ccccccc3' -Runs @($done1) -Phases @{}
    Assert-Equal 'pushed' (Publish-StopwatchShared -RepoRoot $a -MachineId 'ddddddd4' -Json $foreign -TempDir (Join-Path $tmp 'ta')).Status 'a payload naming another machine can be pushed under a ref'
    [void](Receive-StopwatchShared -RepoRoot $b)
    Assert-Equal 1 (Read-StopwatchShared -RepoRoot $b -MachineId 'bbbbbbb2').Machines 'but is not read: a ref counts only with its own machine''s payload'
    # The script itself, end to end against clone b, with a store and transcripts of its own: it never reaches the real origin.
    $syncStore = Join-Path $tmp 'syncstore\stopwatch.json'
    Save-StopwatchStore -Path $syncStore -Runs @($done1, $going)
    [void](New-Item -ItemType Directory -Path (Join-Path $tmp 'transcripts') -Force)
    # A repo that has not opted in (#3470): the script says so in its log and neither fetches nor pushes.
    $savedShare = $env:DKJ_STOPWATCH_SHARE
    $env:DKJ_STOPWATCH_SHARE = $null
    $refsBefore = @(& git -C $origin for-each-ref --format='%(refname)' refs/stopwatch)
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'plugins\dkj-policy\hub\pages\stopwatch-sync.ps1') -StorePath $syncStore -TranscriptDir (Join-Path $tmp 'transcripts') -RepoRoot $b *> $null
    $notShared = [System.IO.File]::ReadAllText((Join-Path $tmp 'syncstore\stopwatch-sync.log'))
    Assert-True ($LASTEXITCODE -eq 0 -and $notShared -match ' not shared: ' -and (@(& git -C $origin for-each-ref --format='%(refname)' refs/stopwatch) -join ',') -eq ($refsBefore -join ',') -and -not (Test-Path -LiteralPath (Join-Path $tmp 'syncstore\stopwatch-machine.txt'))) 'without DKJ_STOPWATCH_SHARE=1 the sync logs not shared and touches no ref (#3470)'
    Assert-True (-not (Start-StopwatchSync -RepoRoot $b)) 'and Start-StopwatchSync does not even start one'
    $env:DKJ_STOPWATCH_SHARE = '1'
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'plugins\dkj-policy\hub\pages\stopwatch-sync.ps1') -StorePath $syncStore -TranscriptDir (Join-Path $tmp 'transcripts') -RepoRoot $b *> $null
    $logLine = [System.IO.File]::ReadAllText((Join-Path $tmp 'syncstore\stopwatch-sync.log'))
    $syncId = ([System.IO.File]::ReadAllText((Join-Path $tmp 'syncstore\stopwatch-machine.txt'))).Trim()
    Assert-True ($LASTEXITCODE -eq 0 -and $logLine -match ' pushed: [0-9a-f]{40}$') 'stopwatch-sync.ps1 publishes the store''s finished runs and logs it'
    [void](Receive-StopwatchShared -RepoRoot $a)
    $fromScript = Read-StopwatchShared -RepoRoot $a -MachineId 'aaaaaaa1'
    Assert-True (@($fromScript.Runs | Where-Object { $_.Machine -eq $syncId }).Count -eq 1) 'and the other machine reads that one finished run under the script''s machine id'
    # The hide script, end to end: machine b hides a run machine a recorded, a reads the entry, then b shows it again.
    $hideOut = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'plugins\dkj-policy\hub\pages\stopwatch-hide.ps1') -RunId $done2.Id -StorePath $syncStore -RepoRoot $b 2>&1
    Assert-True ($LASTEXITCODE -eq 0 -and ($hideOut -join "`n") -match ('\[OK\] hidden: run "' + $done2.Id + '"') -and ($hideOut -join "`n") -match 'sync: .* pushed: ') 'stopwatch-hide.ps1 writes the entry and syncs it'
    [void](Receive-StopwatchShared -RepoRoot $a)
    $seenA = Read-StopwatchShared -RepoRoot $a -MachineId 'aaaaaaa1'
    Assert-True (-not @(Select-StopwatchVisibleRuns -Runs @($done1, $done2) -Entries $seenA.Hidden | Where-Object { $_.Id -eq $done2.Id }).Count) 'and the machine that recorded the run leaves it out of its pages'
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'plugins\dkj-policy\hub\pages\stopwatch-hide.ps1') -RunId $done2.Id -Show -StorePath $syncStore -RepoRoot $b *> $null
    [void](Receive-StopwatchShared -RepoRoot $a)
    Assert-Equal 2 @(Select-StopwatchVisibleRuns -Runs @($done1, $done2) -Entries (Read-StopwatchShared -RepoRoot $a -MachineId 'aaaaaaa1').Hidden).Count '-Show undoes it on every machine'
    # Hiding a run this machine recorded: its own sync erases it from the store and publishes without it (#3453).
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'plugins\dkj-policy\hub\pages\stopwatch-hide.ps1') -RunId $done1.Id -StorePath $syncStore -RepoRoot $b *> $null
    $afterErase = @((Read-StopwatchStore -Path $syncStore).Runs)
    Assert-True (-not @($afterErase | Where-Object { $_.Id -eq $done1.Id }).Count -and @($afterErase | Where-Object { $_.Id -eq $going.Id }).Count) 'the recording machine erases a run it hid from its own store, and keeps the run still going'
    [void](Receive-StopwatchShared -RepoRoot $a)
    Assert-Equal 0 @((Read-StopwatchShared -RepoRoot $a -MachineId 'aaaaaaa1').Runs | Where-Object { $_.Machine -eq $syncId }).Count 'and publishes without it, so no other machine reads it any more'
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'plugins\dkj-policy\hub\pages\stopwatch-hide.ps1') -StorePath $syncStore -RepoRoot $b -NoSync *> $null
    Assert-Equal 1 $LASTEXITCODE 'naming neither a run nor a label is refused'
    $free = $false
    try { [System.IO.File]::Open((Join-Path $tmp 'syncstore\stopwatch-sync.lock'), 'OpenOrCreate', 'ReadWrite', 'None').Dispose(); $free = $true } catch { }
    Assert-True $free 'and releases its lock when it ends'
    $env:DKJ_STOPWATCH_SHARE = $savedShare
    Assert-Equal 'failed' (Publish-StopwatchShared -RepoRoot $a -MachineId 'nope' -Json $json -TempDir (Join-Path $tmp 'ta')).Status 'no machine id, no publish'
    Assert-True (-not (Receive-StopwatchShared -RepoRoot $a -Remote 'no-such-remote')) 'a fetch from a remote that does not answer says so instead of throwing'
    Assert-Equal 0 @(Get-ChildItem -LiteralPath (Join-Path $tmp 'ta') -Filter 'stopwatch-sync-*' -ErrorAction SilentlyContinue).Count 'the blob file and the throwaway index are removed after a publish'
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host "stopwatch-sync: $script:pass passed, $script:fail failed"
if ($script:fail -gt 0) { exit 1 }
exit 0
