<#
.SYNOPSIS
    The hub banner's airsquats state, kept by the hub servers and shared by every machine (#3438): ticking the box
    on one machine clears it on all of them, and on every repo hub of each.

.DESCRIPTION
    Until #3438 the banner kept its state in the browser's localStorage, so it was one count per ORIGIN: every repo
    hub is its own port, so two repos on one machine already disagreed, and a second machine knew nothing.

    THREE LAYERS.
      1. The page asks its own server (GET /api/airsquats every 15 s and at the hour; POST /api/airsquats/clear
         when the box is ticked), and counts the minutes down by itself in between.
      2. Every hub server on a machine reads and writes ONE file, %LOCALAPPDATA%\dkj-hub\airsquats.json, under a
         lock -- so the repo hubs of one machine agree at once.
      3. That file is merged with a private GitHub gist, by sync-airsquats.ps1 in a child process, so the
         machines agree within a sync (owner's choice, October 25, 2026). The server never waits on the network:
         it starts the child and answers from the file. ONLY ON AN OPT-IN (#3439): DKJ_HUB_AIRSQUATS_GIST=auto
         finds or creates the gist, a gist id pins one, and unset there is no sync at all -- the banner then
         agrees across the repo hubs of one machine only, because a background server does not write to
         somebody's GitHub account unasked.

    THE STATE MERGES WITHOUT CONFLICT, which is what lets three layers write it in any order:
      hours      the full hours (Unix ms / 3600000) at whose start some hub was open. Merge: the union.
      clearedAt  the last tick-off, Unix ms. Merge: the later one.
    The number owed is 10 per hour in `hours` that starts after clearedAt. An hour counts only where a hub saw it
    begin -- a poll within two minutes before and one after -- so a night with every hub closed still adds
    nothing, the rule the banner kept from #3250. Hours at or before clearedAt can never count again and are
    pruned, and at most the newest 72 are kept, so the file and the gist stay a few hundred bytes.

    The local file also holds what is this machine's own and never synced: lastSeen (the last poll), announced
    (the newest hour this machine has played the tone for, so it plays once per machine, not once per tab or
    per repo hub), and the sync's bookkeeping.

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/hub-airsquats.tests.ps1 in the source repo.
#>

$script:AirsquatsHourMs = [int64]3600000
$script:AirsquatsAwayMs = [int64]120000
$script:AirsquatsPer = 10
$script:AirsquatsKeep = 72
$script:AirsquatsSyncEveryMs = [int64]20000
$script:AirsquatsGistDescription = 'dkj-hub-airsquats'
$script:AirsquatsGistFile = 'airsquats.json'
$script:AirsquatsSyncScript = Join-Path $PSScriptRoot '..\pages\sync-airsquats.ps1'
$script:AirsquatsSyncProcess = $null
$script:AirsquatsSyncStartedAt = [int64]0

function Get-AirsquatsNow { [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() }

function Get-AirsquatsDir {
    <# The machine's folder for the state: DKJ_HUB_STATE_DIR where set (the tests), else %LOCALAPPDATA%\dkj-hub. #>
    if ($env:DKJ_HUB_STATE_DIR) { return $env:DKJ_HUB_STATE_DIR }
    $base = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { [System.IO.Path]::GetTempPath() }
    return (Join-Path $base 'dkj-hub')
}

function Get-AirsquatsGistSetting {
    <#
        What DKJ_HUB_AIRSQUATS_GIST asks for, as @{ Mode; Id }: 'off' (unset -- no sync), 'auto' (find the gist,
        or create it), 'pinned' (that gist id, never another) or 'invalid' (set, but neither -- never put in a gh
        call). The opt-in is #3439's: without it nothing is written to the account gh is logged in as.
    #>
    $v = ([string]$env:DKJ_HUB_AIRSQUATS_GIST).Trim()
    if (-not $v) { return @{ Mode = 'off'; Id = '' } }
    if ($v -eq 'auto') { return @{ Mode = 'auto'; Id = '' } }
    if ($v -match '^[0-9a-fA-F]{8,64}\z') { return @{ Mode = 'pinned'; Id = $v } }
    return @{ Mode = 'invalid'; Id = '' }
}

function ConvertTo-AirsquatsState {
    <#
        Any parsed object (or $null) as a well-formed state: hours a sorted, distinct int64 list, clearedAt an
        int64, the local fields kept where present. Anything unreadable reads as nothing, never as an error.
        A gist is somebody else's text once DKJ_HUB_AIRSQUATS_GIST pins one, so the input is bounded: at most the
        first 1000 hours are read, and an hour or a time more than a day in the future is dropped -- it could
        otherwise pin or silence the banner for good, and overflow the hour-to-ms product.
    #>
    param($InputObject)
    $s = @{ hours = @(); clearedAt = [int64]0; lastSeen = [int64]0; announced = [int64]0; syncedAt = [int64]0; syncError = ''; gist = '' }
    if ($null -eq $InputObject) { return $s }
    $get = { param($n) if ($InputObject -is [hashtable]) { $InputObject[$n] } else { $InputObject.$n } }
    $maxMs = (Get-AirsquatsNow) + 86400000
    $maxHour = [Math]::Floor($maxMs / $script:AirsquatsHourMs)
    $h = New-Object 'System.Collections.Generic.SortedSet[int64]'
    foreach ($x in @(& $get 'hours' | Select-Object -First 1000)) { $v = [int64]0; if ($null -ne $x -and [int64]::TryParse([string]$x, [ref]$v) -and $v -gt 0 -and $v -le $maxHour) { [void]$h.Add($v) } }
    $s.hours = @($h)
    foreach ($n in 'clearedAt', 'lastSeen', 'announced', 'syncedAt') {
        $v = [int64]0
        $limit = if ($n -eq 'announced') { $maxHour } else { $maxMs }
        if ([int64]::TryParse([string](& $get $n), [ref]$v) -and $v -gt 0 -and $v -le $limit) { $s[$n] = $v }
    }
    foreach ($n in 'syncError', 'gist') { $v = & $get $n; if ($v) { $s[$n] = [string]$v } }
    return $s
}

function Limit-AirsquatsHours {
    <# The hours that can still count: after clearedAt, the newest $AirsquatsKeep of them. #>
    param([int64[]]$Hours, [int64]$ClearedAt)
    $live = @($Hours | Where-Object { ($_ * $script:AirsquatsHourMs) -gt $ClearedAt } | Sort-Object -Unique)
    if ($live.Count -gt $script:AirsquatsKeep) { $live = @($live | Select-Object -Last $script:AirsquatsKeep) }
    return [int64[]]$live
}

function Merge-AirsquatsState {
    <#
        -Into with the shared half of -From merged in: the union of the hours, the later clearedAt, then pruned.
        The local fields stay -Into's. Commutative on the shared half, so it does not matter who merges first.
    #>
    param([hashtable]$Into, [hashtable]$From)
    $r = ConvertTo-AirsquatsState $Into
    $f = ConvertTo-AirsquatsState $From
    $r.clearedAt = [Math]::Max($r.clearedAt, $f.clearedAt)
    $r.hours = @(Limit-AirsquatsHours -Hours (@($r.hours) + @($f.hours)) -ClearedAt $r.clearedAt)
    return $r
}

function Get-AirsquatsShared {
    <# The half that travels: version, hours and clearedAt, as compact JSON. Equal states give equal text. #>
    param([hashtable]$State)
    $s = ConvertTo-AirsquatsState $State
    $hours = (Limit-AirsquatsHours -Hours $s.hours -ClearedAt $s.clearedAt) -join ','
    return ('{"v":1,"hours":[' + $hours + '],"clearedAt":' + $s.clearedAt + '}')
}

function Add-AirsquatsSeen {
    <#
        A poll at -Now: every hour that began since the last poll is added, where that poll was within two minutes
        (AWAY). lastSeen moves to -Now either way.
    #>
    param([hashtable]$State, [int64]$Now)
    $s = ConvertTo-AirsquatsState $State
    if ($s.lastSeen -gt 0 -and $Now -gt $s.lastSeen -and ($Now - $s.lastSeen) -lt $script:AirsquatsAwayMs) {
        $from = [Math]::Floor($s.lastSeen / $script:AirsquatsHourMs) + 1
        $to = [Math]::Floor($Now / $script:AirsquatsHourMs)
        $added = @()
        for ($h = [int64]$from; $h -le $to; $h++) { $added += $h }
        $s.hours = @(Limit-AirsquatsHours -Hours (@($s.hours) + $added) -ClearedAt $s.clearedAt)
    }
    if ($Now -gt $s.lastSeen) { $s.lastSeen = $Now }
    return $s
}

function Get-AirsquatsOwedHours {
    <# How many hours are owed: the hours that began after the last tick-off. #>
    param([hashtable]$State)
    $s = ConvertTo-AirsquatsState $State
    return @(Limit-AirsquatsHours -Hours $s.hours -ClearedAt $s.clearedAt).Count
}

function Use-AirsquatsFile {
    <#
        Runs -Change on the machine's state under its lock and writes what it returns; returns that state. The lock
        is an exclusive open of airsquats.lock, waited for up to -TimeoutMs, because every hub server and the sync
        child of this machine write the same file.
    #>
    param([scriptblock]$Change, [int]$TimeoutMs = 3000)
    $dir = Get-AirsquatsDir
    if (-not (Test-Path -LiteralPath $dir)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
    $file = Join-Path $dir 'airsquats.json'
    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMs)
    $lock = $null
    while ($null -eq $lock) {
        try { $lock = [System.IO.File]::Open((Join-Path $dir 'airsquats.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
        catch { if ([DateTime]::UtcNow -gt $deadline) { throw "the airsquats state is locked: $dir" }; Start-Sleep -Milliseconds 20 }
    }
    try {
        $state = $null
        if (Test-Path -LiteralPath $file -PathType Leaf) {
            try { $state = ConvertTo-AirsquatsState ([System.IO.File]::ReadAllText($file) | ConvertFrom-Json) } catch { $state = $null }
        }
        if ($null -eq $state) { $state = ConvertTo-AirsquatsState $null }
        $new = ConvertTo-AirsquatsState (& $Change $state)
        $json = [ordered]@{ v = 1; hours = @($new.hours); clearedAt = $new.clearedAt; lastSeen = $new.lastSeen; announced = $new.announced; syncedAt = $new.syncedAt; syncError = $new.syncError; gist = $new.gist } | ConvertTo-Json -Compress
        [System.IO.File]::WriteAllText($file, $json, (New-Object System.Text.UTF8Encoding($false)))
        return $new
    } finally {
        $lock.Dispose()
    }
}

function Start-AirsquatsSync {
    <#
        Starts sync-airsquats.ps1 in a hidden child, unless this server's last one is still running. -Due says
        whether a sync is owed (the last one is older than AirsquatsSyncEveryMs, or the state just changed), and
        -Changed that the state did change. The child takes a lock of its own, so a second server's child simply
        exits. This server also keeps its own start time and starts no child within AirsquatsSyncEveryMs of the
        last unless the state changed: a child that dies before it records its attempt would otherwise be started
        again at every poll. DKJ_HUB_NO_SYNC (the tests), no opt-in (DKJ_HUB_AIRSQUATS_GIST unset, #3439) and a
        missing script start nothing.
    #>
    param([bool]$Due, [bool]$Changed = $false, [int64]$Now = (Get-AirsquatsNow))
    if (-not $Due -or $env:DKJ_HUB_NO_SYNC) { return $false }
    if ((Get-AirsquatsGistSetting).Mode -eq 'off') { return $false }
    if ($script:AirsquatsSyncProcess -and -not $script:AirsquatsSyncProcess.HasExited) { return $false }
    if (-not $Changed -and ($Now - $script:AirsquatsSyncStartedAt) -lt $script:AirsquatsSyncEveryMs) { return $false }
    if (-not (Test-Path -LiteralPath $script:AirsquatsSyncScript -PathType Leaf)) { return $false }
    try {
        $script:AirsquatsSyncProcess = Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -PassThru -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + (Resolve-Path -LiteralPath $script:AirsquatsSyncScript).Path + '"'))
        $script:AirsquatsSyncStartedAt = $Now
        return $true
    } catch { return $false }
}

function Invoke-AirsquatsApi {
    <#
        One request to /api/airsquats, answered from the machine's file: @{ Status; Reason; Body } with a JSON body
        { owed, per, announce, synced, syncError }. GET records the poll; POST /api/airsquats/clear ticks the box
        off. A POST is served only same-origin or with no Sec-Fetch-Site at all (curl, a relay such as the product
        port's): a page on another port or site cannot clear the box.
        announce is true once per machine per hour, and only within two minutes of that hour's start, so opening
        a hub later on a count another machine made plays no tone. Once per machine means the first poll to see
        the hour: where that is a background tab, or a browser holding audio back, no other tab plays it.
        The hours and tick-offs are each machine's own clock, so a machine whose clock runs ahead clears its
        hours a little early on the others; Windows' time sync keeps that to seconds.
    #>
    param([string]$Method, [string]$Path, [string]$SecFetchSite = '', [int64]$Now = (Get-AirsquatsNow))
    $m = ([string]$Method).ToUpperInvariant()
    $clear = $Path -eq '/api/airsquats/clear'
    if (-not $clear -and $Path -ne '/api/airsquats') { return @{ Status = 404; Reason = 'Not Found'; Body = '{"error":"not found"}' } }
    if ($clear -and $m -ne 'POST') { return @{ Status = 405; Reason = 'Method Not Allowed'; Body = '{"error":"POST only"}'; Allow = 'POST' } }
    if (-not $clear -and $m -ne 'GET' -and $m -ne 'HEAD') { return @{ Status = 405; Reason = 'Method Not Allowed'; Body = '{"error":"GET only"}'; Allow = 'GET, HEAD' } }
    if ($clear) {
        $site = ([string]$SecFetchSite).Trim().ToLowerInvariant()
        if ($site -and $site -ne 'same-origin') { return @{ Status = 403; Reason = 'Forbidden'; Body = '{"error":"only this hub may clear the box"}' } }
    }
    # Flags the -Change block sets: it runs two scopes down, inside Use-AirsquatsFile, so it writes into this table.
    $flags = @{ Announce = $false; Changed = $false }
    try {
        $state = Use-AirsquatsFile -Change {
            param($s)
            $before = Get-AirsquatsShared $s
            if ($clear) { $s.clearedAt = [Math]::Max($s.clearedAt, $Now); $s.hours = @(Limit-AirsquatsHours -Hours $s.hours -ClearedAt $s.clearedAt) }
            else { $s = Add-AirsquatsSeen -State $s -Now $Now }
            $live = @(Limit-AirsquatsHours -Hours $s.hours -ClearedAt $s.clearedAt)
            if ($live.Count) {
                $top = $live[-1]
                if ($top -gt $s.announced) {
                    $s.announced = $top
                    if (($Now - $top * $script:AirsquatsHourMs) -lt $script:AirsquatsAwayMs) { $flags.Announce = $true }
                }
            }
            if ((Get-AirsquatsShared $s) -ne $before) { $flags.Changed = $true }
            return $s
        }
    } catch {
        return @{ Status = 503; Reason = 'Service Unavailable'; Body = '{"error":"the airsquats state could not be read"}' }
    }
    [void](Start-AirsquatsSync -Due ($flags.Changed -or ($Now - $state.syncedAt) -ge $script:AirsquatsSyncEveryMs) -Changed $flags.Changed -Now $Now)
    $err = ($state.syncError -replace '[^\x20-\x7E]', '' -replace '["\\]', '')
    if ($err.Length -gt 160) { $err = $err.Substring(0, 160) }
    $body = '{"owed":' + (Get-AirsquatsOwedHours $state) + ',"per":' + $script:AirsquatsPer + ',"announce":' + $(if ($flags.Announce) { 'true' } else { 'false' }) +
        ',"synced":' + $state.syncedAt + ',"syncError":"' + $err + '"}'
    return @{ Status = 200; Reason = 'OK'; Body = $body }
}

function Sync-AirsquatsGist {
    <#
        One sync of the machine's file with the gist, through -Gh: a scriptblock taking gh's arguments and returning
        @{ ExitCode; Out } (the tests pass a fake). syncedAt records the ATTEMPT, failed or not, so an offline machine
        tries again every AirsquatsSyncEveryMs rather than at every poll; syncError says whether it landed.
        Only on an opt-in (Get-AirsquatsGistSetting, #3439): with DKJ_HUB_AIRSQUATS_GIST unset it calls no gh and
        writes nothing, not even syncedAt. Pinned, it uses that gist id and no other; 'auto' takes the id the file
        remembers, else the gist by its description among this account's gists, else creates it (private). Reads
        it, merges it into the file under the lock, and writes it back only where the merge changed it. Returns
        @{ Ok; Error; Gist; Pushed }. Never throws.
    #>
    param([scriptblock]$Gh)
    $result = @{ Ok = $false; Error = ''; Gist = ''; Pushed = $false }
    $setting = Get-AirsquatsGistSetting
    if ($setting.Mode -eq 'off') { return $result }
    try {
        if ($setting.Mode -eq 'invalid') { throw "DKJ_HUB_AIRSQUATS_GIST is neither 'auto' nor a gist id" }
        $local = Use-AirsquatsFile -Change { param($s) $s }
        $gist = if ($setting.Mode -eq 'pinned') { $setting.Id } else { $local.gist }
        if ($gist -notmatch '^[0-9a-fA-F]{8,64}\z') { $gist = '' }
        $remote = $null
        if ($gist) {
            $r = & $Gh @('api', "gists/$gist")
            if ($r.ExitCode -eq 0) { $remote = $r.Out | ConvertFrom-Json } elseif ($setting.Mode -eq 'auto') { $gist = '' } else { throw "gh could not read gist $gist" }
        }
        if (-not $gist) {
            # Every page of the account's gists, filtered by gh itself: one id per line, the id held to its shape.
            $filter = '.[] | select(.description == "' + $script:AirsquatsGistDescription + '") | select(.files["' + $script:AirsquatsGistFile + '"]) | .id'
            $r = & $Gh @('api', '--paginate', 'gists?per_page=100', '--jq', $filter)
            if ($r.ExitCode -ne 0) { throw 'gh could not list the gists (is gh logged in?)' }
            $found = @(([string]$r.Out -split "`r?`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^[0-9a-fA-F]{8,64}\z' } | Select-Object -First 1)
            if ($found.Count) {
                $gist = [string]$found[0]
                $r = & $Gh @('api', "gists/$gist")
                if ($r.ExitCode -ne 0) { throw "gh could not read gist $gist" }
                $remote = $r.Out | ConvertFrom-Json
            }
        }
        $remoteState = $null
        if ($remote) {
            $content = $remote.files.$($script:AirsquatsGistFile).content
            if ($content) { try { $remoteState = ConvertTo-AirsquatsState ($content | ConvertFrom-Json) } catch { $remoteState = $null } }
        }
        $merged = Use-AirsquatsFile -Change { param($s) if ($remoteState) { Merge-AirsquatsState -Into $s -From $remoteState } else { $s } }
        $text = Get-AirsquatsShared $merged
        $remoteText = if ($remoteState) { Get-AirsquatsShared $remoteState } else { '' }
        if ($text -ne $remoteText) {
            $payload = @{ description = $script:AirsquatsGistDescription; files = @{ $script:AirsquatsGistFile = @{ content = $text } } }
            if (-not $gist) { $payload['public'] = $false }
            $tmp = Join-Path (Get-AirsquatsDir) ('gist-' + [guid]::NewGuid().ToString('N') + '.json')
            [System.IO.File]::WriteAllText($tmp, ($payload | ConvertTo-Json -Depth 5 -Compress), (New-Object System.Text.UTF8Encoding($false)))
            try {
                $r = if ($gist) { & $Gh @('api', '-X', 'PATCH', "gists/$gist", '--input', $tmp) } else { & $Gh @('api', '-X', 'POST', 'gists', '--input', $tmp) }
            } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
            if ($r.ExitCode -ne 0) { throw 'gh could not write the gist' }
            if (-not $gist) { $gist = [string]($r.Out | ConvertFrom-Json).id }
            $result.Pushed = $true
        }
        $result.Ok = $true
        $result.Gist = $gist
    } catch {
        $result.Error = ([string]$_.Exception.Message -replace '\s+', ' ')
    }
    $g = $result.Gist; $e = $result.Error
    try { [void](Use-AirsquatsFile -Change { param($s) if ($g) { $s.gist = $g }; $s.syncError = $e; $s.syncedAt = Get-AirsquatsNow; $s }) } catch { }
    return $result
}
