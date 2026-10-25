<#
.SYNOPSIS
    The Stopwatch's shared copy (#3349): every machine publishes its finished runs to a ref of its own on origin,
    refs/stopwatch/<machine id>, and reads every other machine's from there, so each machine's /stopwatch shows them
    all.

.DESCRIPTION
    WHY A REF AND NOT A FILE IN THE TREE. The store is outside the checkout because a file in it would dirty the
    workflow it times, and the scripts that ship a branch refuse a dirty tree (stopwatch-lib.ps1). A ref is written
    with git plumbing alone -- hash-object, a throwaway index file, write-tree, commit-tree, push -- so the
    checkout's index, working tree and branches are never touched. The namespace is outside refs/heads, so no
    branch, branch listing or default fetch ever sees it.

    ONE REF PER MACHINE, so two machines never write the same ref and every push is a fast-forward of the copy
    this machine last fetched of its own ref. The machine id is random (New-StopwatchMachineId), kept beside the
    store in stopwatch-machine.txt, so no computer name reaches this public repo. Origin's refs are fetched into
    refs/stopwatch-origin/*, never into refs/stopwatch/*, so a local ref can never shadow what origin holds.

    WHAT IS PUBLISHED: this machine's FINISHED runs, and the transcript phases this machine computed for them, since
    the transcripts they are read from exist only here. A run still going is not published: it ends on this
    machine, and a copy elsewhere could only go stale.

    THE PAYLOAD IS ASCII. Every character above 0x7E is written as a \uXXXX escape (ConvertTo-StopwatchAsciiJson),
    so the blob reads the same under whatever code page a native git call's output is decoded with, and a label
    with an accent reaches the other machine intact.

    WHO CALLS IT: scripts/dashboard/stopwatch-sync.ps1, started in the background by the Stop hook once a run has
    ended and by the hub at most every few minutes (Test-StopwatchSyncDue). Neither waits on it, so no turn and no
    page load waits on the network. Everything that reads or writes a ref runs git; every failure is returned,
    never thrown.

    HIDING A RUN OR A LABEL (#3446). A run cannot be deleted from another machine's ref: that machine owns it and
    would publish it back on its next sync. So a machine hides it instead, with an entry in stopwatch-hidden.json
    beside its own store, published in its OWN payload and honoured by every reader (Select-StopwatchVisibleRuns).
    An entry names one run id or a whole label, and carries the time it was written and whether it hides or shows.
    A label entry hides every finished run of that label, a run finished after it included, until it is shown again;
    a run still going is never hidden.
    Per run id or label the newest entry across all machines wins, so a hide written on one machine is undone from
    any other by a newer show entry. Nothing is erased from any store, so every hide is undoable. The entries are
    written by scripts/dashboard/stopwatch-hide.ps1 (the stopwatch-hide skill); the pages stay read-only (#3323).

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/stopwatch-sync.tests.ps1.
#>

$script:StopwatchRefPrefix = 'refs/stopwatch/'
$script:StopwatchHiddenFile = 'stopwatch-hidden.json'
$script:StopwatchSharedMaxHidden = 2000
$script:StopwatchOriginRefPrefix = 'refs/stopwatch-origin/'
$script:StopwatchSharedFile = 'stopwatch.json'
$script:StopwatchSyncIntervalMinutes = 5
# The bounds on what another machine's payload may make this machine read (ConvertFrom-StopwatchSharedJson).
$script:StopwatchSharedMaxBytes = 1048576
$script:StopwatchSharedMaxRuns = 2000
$script:StopwatchSharedMaxPhases = 20
# Who the shared commits name: nobody's own name or address reaches this public repo through them.
$script:StopwatchCommitIdentity = @{ Name = 'stopwatch'; Email = 'stopwatch@noreply.invalid' }
# A fetch or push that moves under 1 KB/s for 30 seconds gives up, so a stalled connection ends the sync.
$script:StopwatchGitNetworkBounds = @('-c', 'http.lowSpeedLimit=1000', '-c', 'http.lowSpeedTime=30')

function New-StopwatchMachineId {
    <# A machine's id: eight random hex. #>
    return ([guid]::NewGuid().ToString('N').Substring(0, 8))
}

function Get-StopwatchMachineId {
    <# This machine's id, from stopwatch-machine.txt in -StoreDir, written there the first time it is asked for. '' when it can be neither read nor written. #>
    param([Parameter(Mandatory = $true)][string]$StoreDir)
    $path = Join-Path $StoreDir 'stopwatch-machine.txt'
    try {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $id = ([System.IO.File]::ReadAllText($path)).Trim()
            if ($id -cmatch '^[0-9a-f]{8}\z') { return $id }
        }
        $id = New-StopwatchMachineId
        if (-not (Test-Path -LiteralPath $StoreDir -PathType Container)) { [void](New-Item -ItemType Directory -Path $StoreDir -Force) }
        [System.IO.File]::WriteAllText($path, $id, (New-Object System.Text.UTF8Encoding($false)))
        return $id
    } catch { return '' }
}

function ConvertTo-StopwatchAsciiJson {
    <# -Value as JSON with every character above 0x7E escaped as \uXXXX, so the text is pure ASCII, and LF line ends, as git hands a blob back. Pure. #>
    param($Value)
    $json = ($Value | ConvertTo-Json -Depth 8) -replace "`r`n", "`n"
    return [regex]::Replace($json, '[^\x00-\x7E]', { param($m) '\u' + ([int][char]$m.Value).ToString('x4') })
}

function ConvertTo-StopwatchHiddenEntry {
    <#
        One hide entry (#3446) as @{ Kind; Value; At; Hidden }, or $null when it does not parse: Kind 'run' (Value a
        run id) or 'label' (Value a label, cut to the label maximum), At a readable time. Pure.
    #>
    param($Raw)
    if ($null -eq $Raw) { return $null }
    $kind = [string]$Raw.kind; $value = ([string]$Raw.value).Trim()
    $at = ConvertTo-StopwatchTime $Raw.at
    if (-not $at) { return $null }
    if ($kind -ceq 'run') { if ($value -cnotmatch '^[0-9A-Za-z-]{1,40}\z') { return $null } }
    elseif ($kind -ceq 'label') {
        $value = ($value -replace ('[' + [char]0 + '-' + [char]31 + [char]127 + ']'), ' ').Trim()
        if ($value.Length -gt $script:StopwatchLabelMax) { $value = $value.Substring(0, $script:StopwatchLabelMax).Trim() }
        if (-not $value) { return $null }
    } else { return $null }
    return @{ Kind = $kind; Value = $value; At = $at; Hidden = [bool]$Raw.hidden }
}

function ConvertTo-StopwatchHiddenRaw {
    <# -Entries as the plain objects the hide file and the payload hold, sorted by kind and value so the same entries always give the same text. Pure. #>
    param([AllowEmptyCollection()][object[]]$Entries = @())
    return [object[]]@(foreach ($e in @($Entries | Where-Object { $_ } | Sort-Object { $_.Kind }, { $_.Value })) {
            [ordered]@{ kind = $e.Kind; value = $e.Value; at = (Format-StopwatchStamp $e.At); hidden = [bool]$e.Hidden }
        })
}

function Get-StopwatchHiddenPath {
    <# The hide file beside the store at -StorePath. #>
    param([Parameter(Mandatory = $true)][string]$StorePath)
    return (Join-Path (Split-Path -Parent $StorePath) $script:StopwatchHiddenFile)
}

function Read-StopwatchHidden {
    <# This machine's hide entries from -Path, as @{ Entries; Error }. A missing file is no entries; an entry that does not parse is skipped. #>
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @{ Entries = @(); Error = '' } }
    try {
        $text = [System.IO.File]::ReadAllText($Path, (New-Object System.Text.UTF8Encoding($false)))
        $json = if ($text.Trim()) { $text | ConvertFrom-Json } else { $null }
    } catch { return @{ Entries = @(); Error = 'it is not valid JSON' } }
    $entries = @(foreach ($r in @($(if ($json) { $json.hidden } else { @() }))) { $e = ConvertTo-StopwatchHiddenEntry $r; if ($e) { $e } })
    return @{ Entries = $entries; Error = '' }
}

function Save-StopwatchHidden {
    <# Writes -Entries to -Path through a file beside it, as ASCII JSON. #>
    param([Parameter(Mandatory = $true)][string]$Path, [AllowEmptyCollection()][object[]]$Entries = @())
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
    $tmp = "$Path.tmp"
    [System.IO.File]::WriteAllText($tmp, (ConvertTo-StopwatchAsciiJson ([ordered]@{ hidden = (ConvertTo-StopwatchHiddenRaw $Entries) })), (New-Object System.Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function Set-StopwatchHiddenEntry {
    <# -Entries with this machine's entry for -Kind/-Value replaced by one written at -Now that hides (-Hidden) or shows it. Pure. #>
    param([AllowEmptyCollection()][object[]]$Entries = @(), [Parameter(Mandatory = $true)][string]$Kind, [Parameter(Mandatory = $true)][string]$Value,
        [bool]$Hidden = $true, [datetime]$Now = [datetime]::UtcNow)
    $new = ConvertTo-StopwatchHiddenEntry ([pscustomobject]@{ kind = $Kind; value = $Value; at = (Format-StopwatchStamp $Now); hidden = $Hidden })
    if (-not $new) { return $null }
    $kept = @($Entries | Where-Object { $_ -and -not ($_.Kind -ceq $new.Kind -and $_.Value -ceq $new.Value) })
    return [object[]]@($kept + $new)
}

function Get-StopwatchHiddenState {
    <#
        What -Entries (from every machine) hide, as @{ Runs; Labels }, each a hashtable of the hidden run ids or
        labels. Per kind and value the newest entry wins; at the same time a hide wins over a show. Pure.
    #>
    param([AllowEmptyCollection()][object[]]$Entries = @())
    $win = @{}
    foreach ($e in @($Entries | Where-Object { $_ })) {
        $key = $e.Kind + [char]0 + $e.Value
        $cur = $win[$key]
        if (-not $cur -or $e.At -gt $cur.At -or ($e.At -eq $cur.At -and $e.Hidden -and -not $cur.Hidden)) { $win[$key] = $e }
    }
    $runs = @{}; $labels = New-Object System.Collections.Hashtable ([StringComparer]::Ordinal)
    foreach ($e in $win.Values) {
        if (-not $e.Hidden) { continue }
        if ($e.Kind -ceq 'run') { $runs[$e.Value] = $true } else { $labels[$e.Value] = $true }
    }
    return @{ Runs = $runs; Labels = $labels }
}

function Select-StopwatchVisibleRuns {
    <# -Runs without the ones -Entries hide, by run id or by label (Get-StopwatchHiddenState). A run still going is never hidden: it ends on its own machine. Pure. #>
    param([AllowEmptyCollection()][object[]]$Runs = @(), [AllowEmptyCollection()][object[]]$Entries = @())
    $state = Get-StopwatchHiddenState -Entries $Entries
    return @($Runs | Where-Object { $_ -and (-not $_.End -or -not ($state.Runs.ContainsKey($_.Id) -or $state.Labels.ContainsKey($_.Label))) })
}

function ConvertTo-StopwatchSharedJson {
    <#
        The payload this machine publishes: its id, its finished -Runs, and for each the phases from -Phases (by run
        id, as Get-StopwatchTranscriptCache returns them), as ASCII JSON, and its hide entries -Hidden (#3446) when
        it has any. Runs are sorted by start, so the same runs always give the same text and an unchanged store is
        never pushed again. Pure.
    #>
    param([Parameter(Mandatory = $true)][string]$MachineId, [AllowEmptyCollection()][object[]]$Runs = @(), [hashtable]$Phases = @{},
        [AllowEmptyCollection()][object[]]$Hidden = @())
    $done = @($Runs | Where-Object { $_ -and $_.End } | Sort-Object { $_.Start }, { $_.Id })
    $doc = [ordered]@{
        machine = $MachineId
        runs    = @(foreach ($r in $done) {
                $p = $Phases[$r.Id]
                # Assigned, not returned from $(if ...): a subexpression unrolls a one-phase array into a bare object (Victor, #3349).
                $list = $null; $sessions = $null
                if ($p) {
                    $sessions = [int]$p.Sessions
                    $list = [object[]]@(foreach ($x in @($p.Phases)) { if ($x) { [ordered]@{ name = $x.Name; seconds = [Math]::Round([double]$x.Seconds, 3) } } })
                }
                [ordered]@{
                    id       = $r.Id
                    label    = $r.Label
                    start    = (Format-StopwatchStamp $r.Start)
                    end      = (Format-StopwatchStamp $r.End)
                    sessions = $sessions
                    phases   = $list
                }
            })
    }
    # Only when there are any, so a machine that never hid anything publishes the same text as before #3446.
    $raw = ConvertTo-StopwatchHiddenRaw $Hidden
    if ($raw.Count) { $doc.hidden = $raw }
    return (ConvertTo-StopwatchAsciiJson $doc)
}

function ConvertFrom-StopwatchSharedJson {
    <#
        One machine's payload as @{ Machine; Runs; Phases; Hidden }: its finished runs, parsed as the store's own are
        (ConvertTo-StopwatchRun; a run without an end, or that does not parse, is dropped), their phases by run
        id where the payload carried them, and its hide entries (ConvertTo-StopwatchHiddenEntry, bounded in number).
        $null when -Text is not a payload. Pure.
    #>
    param([AllowEmptyString()][string]$Text = '')
    try { $json = $Text | ConvertFrom-Json } catch { return $null }
    if ($null -eq $json -or -not ([string]$json.machine -cmatch '^[0-9a-f]{8}\z')) { return $null }
    # ANOTHER MACHINE'S TEXT IS UNTRUSTED: anyone who can push to origin can write a ref (Sebastian, #3349). So a run
    # that does not parse is skipped rather than allowed to throw and take the page down, and every value is
    # bounded: the runs per machine, the label as the hook cuts it, the phases per run, and the numbers.
    $runs = @(); $phases = @{}
    foreach ($r in @(@($json.runs) | Select-Object -First $script:StopwatchSharedMaxRuns)) {
        if ($null -eq $r) { continue }
        try {
            $run = ConvertTo-StopwatchRun $r
            if (-not $run -or -not $run.End -or $run.End -lt $run.Start) { continue }
            if ($run.Label.Length -gt $script:StopwatchLabelMax) { $run.Label = $run.Label.Substring(0, $script:StopwatchLabelMax).Trim() }
            $run.Auto = $true
            $run.Machine = [string]$json.machine
            $entry = $null
            if ($null -ne $r.phases) {
                $span = ($run.End - $run.Start).TotalSeconds
                $entry = @{ End = (Format-StopwatchStamp $run.End); Sessions = [Math]::Max(0, [Math]::Min(1000, [int]$r.sessions))
                    Phases = @(foreach ($x in @(@($r.phases) | Select-Object -First $script:StopwatchSharedMaxPhases)) {
                            if ($x) { @{ Name = ([string]$x.name).Substring(0, [Math]::Min(80, ([string]$x.name).Length)); Seconds = [Math]::Max(0, [Math]::Min($span, [double]$x.seconds)) } } }) }
            }
            $runs += $run
            if ($entry) { $phases[$run.Id] = $entry }
        } catch { continue }
    }
    $hidden = @(foreach ($h in @(@($json.hidden) | Select-Object -First $script:StopwatchSharedMaxHidden)) {
            $e = $null
            try { $e = ConvertTo-StopwatchHiddenEntry $h } catch { $e = $null }
            if ($e) { $e }
        })
    return @{ Machine = [string]$json.machine; Runs = $runs; Phases = $phases; Hidden = $hidden }
}

function Merge-StopwatchRuns {
    <# -Local and -Shared runs in one list, oldest first; a shared run with the id of a local one is dropped, so this machine's own copy always wins. Pure. #>
    param([AllowEmptyCollection()][object[]]$Local = @(), [AllowEmptyCollection()][object[]]$Shared = @())
    $ids = @{}
    foreach ($r in @($Local | Where-Object { $_ })) { $ids[$r.Id] = $true }
    $all = @($Local | Where-Object { $_ }) + @($Shared | Where-Object { $_ -and -not $ids.ContainsKey($_.Id) })
    return @($all | Sort-Object { $_.Start })
}

function Test-StopwatchSyncDue {
    <# Whether a sync is due: the stamp file at -StampPath is missing or older than the interval at -Now. Reads only the stamp file's modification time. #>
    param([Parameter(Mandatory = $true)][string]$StampPath, [datetime]$Now = [datetime]::UtcNow, [int]$Minutes = $script:StopwatchSyncIntervalMinutes)
    if (-not (Test-Path -LiteralPath $StampPath -PathType Leaf)) { return $true }
    return (($Now.ToUniversalTime() - (Get-Item -LiteralPath $StampPath).LastWriteTimeUtc).TotalMinutes -ge $Minutes)
}

function Test-StopwatchSyncRunning {
    <#
        Whether a sync looks under way (#3377): the stamp at -StampPath is younger than -Minutes at -Now, and the log at
        -LogPath, which a sync writes as it ends, is missing or older than that stamp. A sync that died without its log
        stops counting once the stamp has aged past -Minutes. Reads only the two files' modification times.
    #>
    param([Parameter(Mandatory = $true)][string]$StampPath, [Parameter(Mandatory = $true)][string]$LogPath,
        [datetime]$Now = [datetime]::UtcNow, [int]$Minutes = $script:StopwatchSyncIntervalMinutes)
    if (-not (Test-Path -LiteralPath $StampPath -PathType Leaf)) { return $false }
    $stamped = (Get-Item -LiteralPath $StampPath).LastWriteTimeUtc
    if (($Now.ToUniversalTime() - $stamped).TotalMinutes -ge $Minutes) { return $false }
    if (-not (Test-Path -LiteralPath $LogPath -PathType Leaf)) { return $true }
    return ((Get-Item -LiteralPath $LogPath).LastWriteTimeUtc -lt $stamped)
}

function Start-StopwatchSync {
    <#
        Starts scripts/dashboard/stopwatch-sync.ps1 of -RepoRoot as a hidden process of its own and returns at once;
        nothing waits on it. Returns whether it started. A caller that must not reach the network (a test) does not call it.
    #>
    param([Parameter(Mandatory = $true)][string]$RepoRoot)
    $script = Join-Path $RepoRoot 'scripts\dashboard\stopwatch-sync.ps1'
    if (-not (Test-Path -LiteralPath $script -PathType Leaf)) { return $false }
    try {
        Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -WorkingDirectory $RepoRoot `
            -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $script + '"')) | Out-Null
        return $true
    } catch { return $false }
}

function Invoke-StopwatchGit {
    <#
        One git call in -RepoRoot, under 'Continue' (5.1 turns a native stderr line into a terminating error
        under 'Stop') and with no terminal prompt, so a missing credential fails instead of waiting. Returns
        @{ Ok; Out } with Out the stdout lines. -Env sets environment variables for this call only.
    #>
    param([Parameter(Mandatory = $true)][string]$RepoRoot, [Parameter(Mandatory = $true)][string[]]$Arguments, [hashtable]$Env = @{})
    $saved = @{}
    $keys = @('GIT_TERMINAL_PROMPT', 'GCM_INTERACTIVE') + @($Env.Keys)
    foreach ($k in $keys) { $saved[$k] = [Environment]::GetEnvironmentVariable($k) }
    $eap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        # Neither a terminal prompt nor Git Credential Manager's window: the sync runs hidden, so a prompt would wait forever.
        [Environment]::SetEnvironmentVariable('GIT_TERMINAL_PROMPT', '0')
        [Environment]::SetEnvironmentVariable('GCM_INTERACTIVE', 'never')
        foreach ($k in $Env.Keys) { [Environment]::SetEnvironmentVariable($k, [string]$Env[$k]) }
        $out = @(& git -C $RepoRoot @Arguments 2>$null)
        return @{ Ok = ($LASTEXITCODE -eq 0); Out = @($out | ForEach-Object { [string]$_ }) }
    } finally {
        foreach ($k in $keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
        $ErrorActionPreference = $eap
    }
}

function Receive-StopwatchShared {
    <# Fetches every machine's ref from -Remote into refs/stopwatch-origin/*, pruning the ones origin no longer has. Returns whether the fetch answered. #>
    param([Parameter(Mandatory = $true)][string]$RepoRoot, [string]$Remote = 'origin')
    $spec = '+' + $script:StopwatchRefPrefix + '*:' + $script:StopwatchOriginRefPrefix + '*'
    return (Invoke-StopwatchGit -RepoRoot $RepoRoot -Arguments (@($script:StopwatchGitNetworkBounds) + @('fetch', '--quiet', '--prune', '--no-tags', $Remote, $spec))).Ok
}

function Read-StopwatchShared {
    <#
        Every OTHER machine's runs, from the refs last fetched into refs/stopwatch-origin/* (no network): @{ Runs;
        Phases (by run id); Hidden (their hide entries, #3446); Machines (how many machines had a payload) }.
        -MachineId is this machine's, whose own copy is skipped because the local store is newer. A ref whose
        payload does not parse is skipped.
    #>
    param([Parameter(Mandatory = $true)][string]$RepoRoot, [AllowEmptyString()][string]$MachineId = '')
    $none = @{ Runs = @(); Phases = @{}; Hidden = @(); Machines = 0 }
    $refs = Invoke-StopwatchGit -RepoRoot $RepoRoot -Arguments @('for-each-ref', '--format=%(refname)', $script:StopwatchOriginRefPrefix.TrimEnd('/'))
    if (-not $refs.Ok) { return $none }
    $runs = @(); $phases = @{}; $hidden = @(); $machines = 0
    foreach ($ref in @($refs.Out | Where-Object { $_ })) {
        $id = $ref.Substring($script:StopwatchOriginRefPrefix.Length)
        if (-not ($id -cmatch '^[0-9a-f]{8}\z') -or $id -ceq $MachineId) { continue }
        $path = $ref + ':' + $script:StopwatchSharedFile
        $size = Invoke-StopwatchGit -RepoRoot $RepoRoot -Arguments @('cat-file', '-s', $path)
        if (-not $size.Ok -or -not $size.Out.Count -or [int64]$size.Out[0] -gt $script:StopwatchSharedMaxBytes) { continue }
        $blob = Invoke-StopwatchGit -RepoRoot $RepoRoot -Arguments @('cat-file', 'blob', $path)
        if (-not $blob.Ok) { continue }
        $p = $null
        try { $p = ConvertFrom-StopwatchSharedJson -Text ($blob.Out -join "`n") } catch { $p = $null }
        if (-not $p -or $p.Machine -cne $id) { continue }
        $machines++
        $runs += @($p.Runs)
        $hidden += @($p.Hidden)
        foreach ($k in $p.Phases.Keys) { $phases[$k] = $p.Phases[$k] }
    }
    return @{ Runs = $runs; Phases = $phases; Hidden = $hidden; Machines = $machines }
}

function Publish-StopwatchShared {
    <#
        Writes -Json (ConvertTo-StopwatchSharedJson) as refs/stopwatch/<-MachineId> on -Remote: a commit holding the
        one file, on top of the copy of that ref last fetched, pushed as a fast-forward. Run Receive-StopwatchShared
        first. Returns @{ Status; Message }, Status one of 'unchanged' (origin already holds this text), 'pushed'
        or 'failed'. Touches neither the index nor the working tree: the blob is hashed from a file in -TempDir, and
        the tree is written through a throwaway index file there.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$MachineId,
        [Parameter(Mandatory = $true)][string]$Json,
        [Parameter(Mandatory = $true)][string]$TempDir,
        [string]$Remote = 'origin'
    )
    if (-not ($MachineId -cmatch '^[0-9a-f]{8}\z')) { return @{ Status = 'failed'; Message = 'no machine id' } }
    $originRef = $script:StopwatchOriginRefPrefix + $MachineId
    $parent = ''
    $r = Invoke-StopwatchGit -RepoRoot $RepoRoot -Arguments @('rev-parse', '--verify', '--quiet', ($originRef + '^{commit}'))
    if ($r.Ok -and $r.Out.Count) { $parent = $r.Out[0].Trim() }
    if ($parent) {
        $old = Invoke-StopwatchGit -RepoRoot $RepoRoot -Arguments @('cat-file', 'blob', ($parent + ':' + $script:StopwatchSharedFile))
        if ($old.Ok -and (($old.Out -join "`n").Trim() -ceq $Json.Trim())) { return @{ Status = 'unchanged'; Message = '' } }
    }
    if (-not (Test-Path -LiteralPath $TempDir -PathType Container)) { [void](New-Item -ItemType Directory -Path $TempDir -Force) }
    $file = Join-Path $TempDir ('stopwatch-sync-' + [guid]::NewGuid().ToString('N') + '.json')
    $index = Join-Path $TempDir ('stopwatch-sync-' + [guid]::NewGuid().ToString('N') + '.index')
    try {
        [System.IO.File]::WriteAllText($file, $Json, (New-Object System.Text.UTF8Encoding($false)))
        $b = Invoke-StopwatchGit -RepoRoot $RepoRoot -Arguments @('hash-object', '-w', '--', $file)
        if (-not $b.Ok -or -not $b.Out.Count) { return @{ Status = 'failed'; Message = 'hash-object did not answer' } }
        $blob = $b.Out[0].Trim()
        $envIndex = @{ GIT_INDEX_FILE = $index }
        $u = Invoke-StopwatchGit -RepoRoot $RepoRoot -Arguments @('update-index', '--add', '--cacheinfo', ('100644,' + $blob + ',' + $script:StopwatchSharedFile)) -Env $envIndex
        $t = Invoke-StopwatchGit -RepoRoot $RepoRoot -Arguments @('write-tree') -Env $envIndex
        if (-not $u.Ok -or -not $t.Ok -or -not $t.Out.Count) { return @{ Status = 'failed'; Message = 'the tree could not be written' } }
        $commitArgs = @('commit-tree', $t.Out[0].Trim(), '-m', ('stopwatch: runs of machine ' + $MachineId))
        if ($parent) { $commitArgs += @('-p', $parent) }
        # A neutral identity and a UTC date, so the commit carries neither this machine's git name and address nor its time zone.
        $when = '@' + [int64]([datetime]::UtcNow - [datetime]::new(1970, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)).TotalSeconds + ' +0000'
        $who = @{ GIT_AUTHOR_NAME = $script:StopwatchCommitIdentity.Name; GIT_AUTHOR_EMAIL = $script:StopwatchCommitIdentity.Email; GIT_AUTHOR_DATE = $when
            GIT_COMMITTER_NAME = $script:StopwatchCommitIdentity.Name; GIT_COMMITTER_EMAIL = $script:StopwatchCommitIdentity.Email; GIT_COMMITTER_DATE = $when }
        $c = Invoke-StopwatchGit -RepoRoot $RepoRoot -Arguments $commitArgs -Env $who
        if (-not $c.Ok -or -not $c.Out.Count) { return @{ Status = 'failed'; Message = 'commit-tree did not answer' } }
        $commit = $c.Out[0].Trim()
        $p = Invoke-StopwatchGit -RepoRoot $RepoRoot -Arguments (@($script:StopwatchGitNetworkBounds) + @('push', '--quiet', $Remote, ($commit + ':' + $script:StopwatchRefPrefix + $MachineId)))
        if (-not $p.Ok) { return @{ Status = 'failed'; Message = 'the push was refused or did not answer' } }
        [void](Invoke-StopwatchGit -RepoRoot $RepoRoot -Arguments @('update-ref', $originRef, $commit))
        return @{ Status = 'pushed'; Message = $commit }
    } finally {
        Remove-Item -LiteralPath $file, $index -Force -ErrorAction SilentlyContinue
    }
}
