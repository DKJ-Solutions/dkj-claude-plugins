<#
.SYNOPSIS
    Tests for plugins/dkj-policy/hub/lib/airsquats-lib.ps1 -- the hub banner's airsquats state, shared by every hub
    and every machine (#3438): the merge rule, the hours a poll counts, the API the banner asks, and one sync with
    the gist through a fake gh. The machine's file is a scratch folder (DKJ_HUB_STATE_DIR), and no child is started
    (DKJ_HUB_NO_SYNC).

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Continue'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $RepoRoot 'plugins\dkj-policy\hub\lib\airsquats-lib.ps1')

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else            { $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}
trap { $script:fail++; Write-Host "  [FAIL] unhandled terminating error: $_" -ForegroundColor Red; continue }
function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    Assert-True ("$Expected" -eq "$Actual") ($Name + $(if ("$Expected" -ne "$Actual") { " (expected '$Expected', got '$Actual')" } else { '' }))
}

$H = [int64]3600000
$base = [int64]490000 * $H   # a full hour, some time in 2025

$scratch = Join-Path ([System.IO.Path]::GetTempPath()) ('hub-airsquats-' + [guid]::NewGuid().ToString('N'))
$oldDir = $env:DKJ_HUB_STATE_DIR; $oldNoSync = $env:DKJ_HUB_NO_SYNC; $oldGist = $env:DKJ_HUB_AIRSQUATS_GIST
$env:DKJ_HUB_STATE_DIR = $scratch; $env:DKJ_HUB_NO_SYNC = '1'; $env:DKJ_HUB_AIRSQUATS_GIST = ''
try {
    Write-Host '-- the merge rule' -ForegroundColor Cyan
    $a = @{ hours = @(490001, 490002); clearedAt = [int64]0 }
    $b = @{ hours = @(490002, 490003); clearedAt = [int64]0 }
    Assert-Equal '490001,490002,490003' ((Merge-AirsquatsState -Into $a -From $b).hours -join ',') 'the hours are the union of both sides'
    Assert-Equal (Get-AirsquatsShared (Merge-AirsquatsState -Into $a -From $b)) (Get-AirsquatsShared (Merge-AirsquatsState -Into $b -From $a)) 'and the merge is the same whichever side merges first'
    $cleared = @{ hours = @(490001); clearedAt = 490002 * $H + 5 }
    $m = Merge-AirsquatsState -Into $b -From $cleared
    Assert-Equal (490002 * $H + 5) $m.clearedAt 'the later tick-off wins'
    Assert-Equal '490003' ($m.hours -join ',') 'and the hours it cleared are gone, on whichever side they were'
    Assert-Equal 1 (Get-AirsquatsOwedHours $m) 'so one hour is owed: the one after the tick-off'
    $many = @{ hours = @(1..100 | ForEach-Object { 490000 + $_ }); clearedAt = [int64]0 }
    Assert-Equal 72 (Get-AirsquatsOwedHours $many) 'at most the newest 72 hours are kept'
    Assert-Equal 0 (Get-AirsquatsOwedHours (ConvertTo-AirsquatsState ('{"hours":"x","clearedAt":"y"}' | ConvertFrom-Json))) 'a state that does not parse reads as nothing owed, never as an error'
    Assert-Equal '{"v":1,"hours":[490003],"clearedAt":1764007200005}' (Get-AirsquatsShared $m) 'the shared half is compact JSON: version, hours, clearedAt'

    Write-Host '-- the hours a poll counts' -ForegroundColor Cyan
    $s = Add-AirsquatsSeen -State @{} -Now ($base + 10)
    Assert-Equal 0 (Get-AirsquatsOwedHours $s) 'a first poll counts nothing'
    $s = Add-AirsquatsSeen -State $s -Now ($base + $H - 15000)
    Assert-Equal 0 (Get-AirsquatsOwedHours $s) 'nor does a poll inside the same hour'
    $s = Add-AirsquatsSeen -State @{ lastSeen = $base + $H - 15000 } -Now ($base + $H + 1000)
    Assert-Equal '490001' ($s.hours -join ',') 'a poll just past the hour, with one just before it, counts that hour'
    $s = Add-AirsquatsSeen -State @{ lastSeen = $base + 10 } -Now ($base + 5 * $H)
    Assert-Equal 0 (Get-AirsquatsOwedHours $s) 'a hub closed for hours adds nothing on its return (#3250)'
    Assert-Equal ($base + 5 * $H) $s.lastSeen 'and lastSeen moves on either way'

    Write-Host '-- the API the banner asks' -ForegroundColor Cyan
    $r = Invoke-AirsquatsApi -Method GET -Path '/api/airsquats' -Now ($base + $H - 10000)
    Assert-True ($r.Status -eq 200 -and $r.Body -match '"owed":0' -and $r.Body -match '"per":10' -and $r.Body -match '"announce":false') 'a GET answers JSON: nothing owed, 10 per hour, no tone'
    Assert-True (Test-Path -LiteralPath (Join-Path $scratch 'airsquats.json')) 'and the machine''s file is written'
    $r = Invoke-AirsquatsApi -Method GET -Path '/api/airsquats' -Now ($base + $H + 5000)
    Assert-True ($r.Body -match '"owed":1' -and $r.Body -match '"announce":true') 'the poll past the hour owes one and plays the tone'
    $r = Invoke-AirsquatsApi -Method GET -Path '/api/airsquats' -Now ($base + $H + 20000)
    Assert-True ($r.Body -match '"owed":1' -and $r.Body -match '"announce":false') 'the next poll -- another tab, another repo hub -- plays it no more: once per machine'
    $r = Invoke-AirsquatsApi -Method POST -Path '/api/airsquats/clear' -SecFetchSite 'same-site' -Now ($base + $H + 30000)
    Assert-Equal 403 $r.Status 'a POST from another port of this machine may not clear the box'
    $r = Invoke-AirsquatsApi -Method POST -Path '/api/airsquats/clear' -SecFetchSite 'cross-site' -Now ($base + $H + 30000)
    Assert-Equal 403 $r.Status 'nor one from another site'
    $r = Invoke-AirsquatsApi -Method GET -Path '/api/airsquats/clear' -Now ($base + $H + 30000)
    Assert-True ($r.Status -eq 405 -and $r.Allow -eq 'POST') 'clearing is a POST only'
    $r = Invoke-AirsquatsApi -Method POST -Path '/api/airsquats' -Now ($base + $H + 30000)
    Assert-Equal 405 $r.Status 'and the state is read with a GET only'
    Assert-Equal 404 (Invoke-AirsquatsApi -Method GET -Path '/api/airsquats/other').Status 'any other path under it is not found'
    $r = Invoke-AirsquatsApi -Method POST -Path '/api/airsquats/clear' -SecFetchSite 'same-origin' -Now ($base + $H + 30000)
    Assert-True ($r.Status -eq 200 -and $r.Body -match '"owed":0') 'the page''s own POST clears it'
    $r = Invoke-AirsquatsApi -Method GET -Path '/api/airsquats' -Now ($base + $H + 45000)
    Assert-True ($r.Body -match '"owed":0' -and $r.Body -match '"announce":false') 'and every later poll on this machine reads it cleared'

    Write-Host '-- one sync with the gist, through a fake gh' -ForegroundColor Cyan
    $script:gists = @{}
    $script:calls = New-Object System.Collections.Generic.List[string]
    $fake = {
        param([string[]]$a)
        $script:calls.Add(($a -join ' '))
        if ($a[0] -ne 'api') { return @{ ExitCode = 1; Out = '' } }
        if ($a[1] -eq 'gists?per_page=100') {
            $list = @($script:gists.Keys | ForEach-Object { @{ id = $_; description = 'dkj-hub-airsquats'; files = @{ 'airsquats.json' = @{} } } })
            return @{ ExitCode = 0; Out = (ConvertTo-Json -InputObject $list -Depth 5 -Compress) }
        }
        if ($a[1] -eq '-X') {
            $body = [System.IO.File]::ReadAllText($a[5]) | ConvertFrom-Json
            $id = if ($a[2] -eq 'POST') { 'abcdef0123456789' } else { $a[3] -replace '^gists/', '' }
            if ($a[2] -eq 'POST') { $script:posted = $body }
            $script:gists[$id] = $body.files.'airsquats.json'.content
            return @{ ExitCode = 0; Out = ('{"id":"' + $id + '"}') }
        }
        $id = $a[1] -replace '^gists/', ''
        if (-not $script:gists.ContainsKey($id)) { return @{ ExitCode = 1; Out = '' } }
        return @{ ExitCode = 0; Out = (@{ id = $id; files = @{ 'airsquats.json' = @{ content = $script:gists[$id] } } } | ConvertTo-Json -Depth 5 -Compress) }
    }
    $r = Sync-AirsquatsGist -Gh $fake
    Assert-True ($r.Ok -and $r.Pushed -and $r.Gist -eq 'abcdef0123456789') 'with no gist anywhere, the first sync creates it'
    Assert-True ($script:posted.public -eq $false -and $script:posted.description -eq 'dkj-hub-airsquats') 'private, under the description a second machine finds it by'
    $local = Use-AirsquatsFile -Change { param($s) $s }
    Assert-True ($local.gist -eq 'abcdef0123456789' -and -not $local.syncError -and $local.syncedAt -gt 0) 'the machine remembers the gist, and that the sync landed'

    # Another machine ticks an hour into the gist; this machine's next sync takes it in.
    $script:gists['abcdef0123456789'] = '{"v":1,"hours":[' + (490000 + 3) + '],"clearedAt":0}'
    $script:calls.Clear()
    $r = Sync-AirsquatsGist -Gh $fake
    Assert-True ($r.Ok -and -not ($script:calls -match 'gists\?per_page')) 'a remembered gist is read by its id, with no search'
    Assert-Equal 1 (Get-AirsquatsOwedHours (Use-AirsquatsFile -Change { param($s) $s })) 'the other machine''s hour reaches this machine'
    $script:calls.Clear()
    $r = Sync-AirsquatsGist -Gh $fake
    Assert-True ($r.Ok -and -not $r.Pushed -and -not ($script:calls -match 'PATCH')) 'and a sync that changes nothing writes nothing to the gist'

    # This machine ticks it off; the next sync carries the tick-off to the gist.
    [void](Invoke-AirsquatsApi -Method POST -Path '/api/airsquats/clear' -Now (490004 * $H))
    $r = Sync-AirsquatsGist -Gh $fake
    Assert-True ($r.Pushed -and ($script:gists['abcdef0123456789'] | ConvertFrom-Json).clearedAt -eq (490004 * $H)) 'a tick-off here is written to the gist, for every other machine'

    # A second machine, its own folder, the same account: it finds the gist by its description.
    $env:DKJ_HUB_STATE_DIR = Join-Path $scratch 'second'
    $r = Sync-AirsquatsGist -Gh $fake
    Assert-True ($r.Ok -and $r.Gist -eq 'abcdef0123456789' -and (Use-AirsquatsFile -Change { param($s) $s }).clearedAt -eq (490004 * $H)) 'a second machine finds the same gist with nothing configured, and reads it cleared'
    $env:DKJ_HUB_STATE_DIR = $scratch

    $r = Sync-AirsquatsGist -Gh { param($a) @{ ExitCode = 1; Out = '' } }
    $local = Use-AirsquatsFile -Change { param($s) $s }
    Assert-True (-not $r.Ok -and $local.syncError -and $local.gist -eq 'abcdef0123456789') 'a gh that fails is written into the state as the sync''s error, and the remembered gist is kept'
    $env:DKJ_HUB_AIRSQUATS_GIST = '../../etc'
    $script:calls.Clear()
    [void](Sync-AirsquatsGist -Gh $fake)
    Assert-True (-not ($script:calls -match '\.\.')) 'a pinned gist id that is not an id is never put in a gh call'
    $env:DKJ_HUB_AIRSQUATS_GIST = ''
} finally {
    $env:DKJ_HUB_STATE_DIR = $oldDir; $env:DKJ_HUB_NO_SYNC = $oldNoSync; $env:DKJ_HUB_AIRSQUATS_GIST = $oldGist
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host "hub-airsquats: $script:pass passed, $script:fail failed"
if ($script:fail -gt 0) { exit 1 }
exit 0
