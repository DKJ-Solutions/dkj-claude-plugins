<#
.SYNOPSIS
    A verdict a SessionStart hook may compute ONCE per session instead of on every firing: the
    session id the harness hands the hook on stdin, and a small cache under temp keyed on it.

.DESCRIPTION
    Dot-source this file:

        . (Join-Path $PSScriptRoot '..\scripts\lib\session-cache-lib.ps1')

    WHY THIS EXISTS (issue #1605). The SessionStart hooks in this family are matched on
    "startup|resume|clear|compact", not on "startup" alone, because a SessionStart hook's injected
    stdout does not survive a compaction by itself -- a startup-only matcher made every report go
    silent after the first /compact and never return. That matcher is right and must not be narrowed.
    What it costs is that every firing re-runs the check, and connector-sessioncheck's #1591 fallback
    is the expensive one: two nested powershell bring-ups plus git in the marketplace clone, measured
    at 1.1-1.8s, of which ~750ms is the process spawn alone. A session with four compactions paid it
    five times for an answer that was identical each time.

    WHAT THIS CACHE STANDS ON, AND THE ARGUMENT IT DOES *NOT* MAKE. #1605 justified it as "nothing
    the fallback reads changes for the life of a session", citing the hook's own closing line ("then
    restart the session -- a skill or hook that arrives with an update is not in a session that
    started before it"). That citation proves something narrower than it looks: a running hook's CODE
    is pinned for the session, which is true and is why the restart line exists. It says nothing about
    the two files the verdict is actually about -- the install record keyed on this checkout's path,
    and the marketplace clone -- and those are ordinary mutable files. A sibling terminal running
    `claude plugin update` or `claude plugin marketplace update` changes them immediately, with no
    restart of this session involved (Victor, on the branch that built this).

    SO THE HONEST CLAIM IS A BOUND, NOT AN INVARIANT: a replay is the same answer unless the machine
    changed under it, and where it did, the change surfaces at most -MaxAgeHours late instead of at
    the next firing. That is a real cost and it is why the default is ONE hour rather than the four
    this started with -- long enough that a working session's compaction cycle almost never
    re-measures, short enough that "silent until you restart" is not a state this can produce.

    AND THE DIRECTION THAT MATTERS SELF-HEALS. The reading a reader acts on is "you are behind", and
    acting on it means an update, after which this hook tells them to restart -- which is a new
    session id and therefore a bypass of this cache, not a wait for it to expire. What the bound
    covers is the other direction: a clone advanced from elsewhere while this session ran, which was
    reported at the next compaction before #1605 and is now reported within the hour.

    THE KEY IS THE HARNESS'S OWN session_id, NOT A PAIR OF FILE TIMESTAMPS. The issue proposed
    keying on the install record's mtime plus the clone's .git/FETCH_HEAD mtime, on the ground that
    the script already reads both -- but it is the ENGINE that reads them, in the child process this
    cache exists to avoid starting. Keying on FETCH_HEAD would mean the hook resolving the clone
    directories itself, which is engine logic copied into a caller, and it argues against the
    invariant above at the same time: if nothing can change within a session, an mtime key guards a
    case the premise says cannot occur. The session id expresses exactly the invariant, needs no
    knowledge of the engine, and falls out of the payload the harness already sends.

    AND IT SORTS THE FIRING KINDS FOR FREE, which is the second reason to prefer it. A compaction
    keeps the session id, so the answer is replayed -- which is the whole point. A startup and a
    /clear arrive with a NEW id, so both re-measure without this file having to read the payload's
    'source' field or hold a list of which kinds may trust a cache.

    A RESUME IS THE SECOND REASON FOR -MaxAgeHours, and it is the one the id cannot cover at all.
    Resuming reuses the session id, so a session resumed days later would replay a verdict measured
    before whatever happened in between: the id says "the same session" and says nothing about WHEN.
    Entries older than the reap window are additionally deleted on the next write, rather than left
    to accumulate one file per session forever.

    THE CACHE IS ADVISORY IN BOTH DIRECTIONS, and every function here fails towards MEASURING. No
    session id, an unparseable payload, an unwritable temp directory, a corrupt entry, a shape this
    lib does not recognise: each returns "no cached answer" and the caller does what it did before
    this file existed. A cache that can break a session start would be a worse defect than the cost
    it saves.

    WHAT IS AND IS NOT VERIFIED ABOUT AN ENTRY, since a reader will ask. Shape, key and age are
    checked; PROVENANCE is not -- an entry is trusted because it is in this directory under this
    session's id, not because anything proves who wrote it. So a local actor able to write into that
    directory, who also knows the live session id, could make this hook print a fabricated verdict
    into a session's context (Sebastian, on the branch that built this). Two things bound that and
    both pre-date this file: reaching it already needs local execution as this same user, and every
    line the hook prints from here is framed as data rather than instructions, with the summary
    picked by -Last precisely so a shadowing line cannot displace a real finding. It is written down
    because it is NEW -- before this there was no hook-trusted artefact on disk at all -- not because
    anything here defends against it.

    ONE IDIOM, TWO PLACES, and a note for whoever next touches either. gate-lib.ps1's evidence
    record (Get-GateEvidencePath / Read-GateEvidence / Save-GateEvidence) carries the same small
    pattern: an age-bounded JSON record, the negative-age guard below, and a best-effort BOM-less
    write. The two were not merged, and that was a decision rather than an oversight -- gate-lib
    keeps ONE fixed-key record per repo under .git/, keyed on a content fingerprint, while this is a
    multi-entry cache under temp keyed on a session id from outside the process. If a third caller
    ever wants the idiom, that is the moment to factor it, not now (Victor, on the branch that built
    this).

    Read-only outside its own directory in the per-user cache location -- LOCALAPPDATA, else
    XDG_CACHE_HOME, else ~/.cache; see Get-SessionCacheRoot for why it is deliberately NOT the shared
    temp root every other scratch path in this layer uses. It never writes into a repo, into
    ~/.claude, or anywhere a check reads state from.

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script.
    Pure ASCII (repo convention for .ps1).
#>

# THE SHA-256 RENDERING Get-SessionCacheFileName cuts a cache file name out of (issue #2058). A leaf
# with no dependencies of its own, and loaded UNGUARDED: the file name cannot be composed without it,
# so a payload missing this file must fail at LOAD rather than one call deeper, where the error would
# no longer name what is absent. It is registered in the shared-scripts registry for dkj-policy, the
# plugin this file is mirrored into, so the mirror always carries it.
. (Join-Path $PSScriptRoot 'hash-hex-lib.ps1')

function Get-HookPayloadRaw {
    <#
    .SYNOPSIS
        The hook's own stdin payload, as text -- bounded, and only where there is one to read.

    .DESCRIPTION
        A SessionStart hook receives a JSON payload on stdin carrying session_id, transcript_path,
        cwd and source. dkj-subagents-shopify's guard-live-theme.ps1 already reads its own payload this
        way ([Console]::In.ReadToEnd() + ConvertFrom-Json, with an explicit fallback on an
        unparseable one), and this is that pattern with two guards it does not need and this one does.

        TWO GUARDS, BOTH ABOUT NOT HANGING A SESSION START. First, stdin is read only when it is
        REDIRECTED: an unredirected [Console]::In is a live console, and reading it to the end blocks
        until somebody types EOF -- which is exactly what happens when this hook is run by hand or by
        a test suite from a terminal. Second, the read is bounded by a timeout even when redirected,
        because a redirected handle that nobody closes blocks just as completely as a console does.
        The normal case pays neither: the harness writes the payload and closes the handle, so the
        text is already buffered and the wait returns immediately.

        A hook that cannot read its payload gets '' and therefore no cache -- the failing-towards-
        measuring rule in this file's header.
    #>
    param([int]$TimeoutMs = 250)

    try {
        if (-not [Console]::IsInputRedirected) { return '' }
        $task = [Console]::In.ReadToEndAsync()
        if (-not $task.Wait($TimeoutMs)) { return '' }
        return [string]$task.Result
    } catch {
        return ''
    }
}

function Test-SessionIdShape {
    <#
    .SYNOPSIS
        Is this string safe to use as a session key AND as part of a file name?

    .DESCRIPTION
        The session id arrives from outside this process and is used to compose a path, so it is
        validated rather than escaped: letters, digits, dot, dash and underscore only, 8 to 128
        characters. Anything else -- a separator, a traversal segment, a colon, a control character,
        anything empty or absurdly long -- is refused and the caller falls back to measuring.

        WHITELIST RATHER THAN A SANITISER, deliberately. A sanitiser has to be right about every
        character it strips and about what the remainder then collides with; a shape check has to be
        right about the one shape the harness actually sends (a UUID), and every real session id
        passes it. The cost of being wrong is one re-measured verdict; the cost of being wrong the
        other way is a path this process composes out of somebody else's string.
    #>
    param([string]$SessionId)

    if ([string]::IsNullOrWhiteSpace($SessionId)) { return $false }
    return ($SessionId -cmatch '^[A-Za-z0-9._-]{8,128}$')
}

function Get-SessionIdFromPayload {
    <#
    .SYNOPSIS
        The session_id out of a hook payload, or '' when there is not a usable one.

    .DESCRIPTION
        Pure: it takes the text and returns a string, so the suite can walk every shape a payload
        arrives in -- empty, not JSON, JSON without the field, a field of the wrong type, a field
        whose value fails the shape check -- without a hook, a harness or a temp directory.

        NOT A FALLBACK TO THE RAW TEXT, unlike guard-live-theme.ps1's own read. That hook falls back
        because its subject is a command it must inspect, so an unrecognised payload has to fail
        towards CHECKING. Here the subject is a cache key, and an unrecognised payload has to fail
        towards MEASURING -- which is what no key means.
    #>
    param([string]$Payload)

    if ([string]::IsNullOrWhiteSpace($Payload)) { return '' }
    try {
        $j = $Payload | ConvertFrom-Json
    } catch {
        return ''
    }
    if (-not $j) { return '' }
    if ($j -isnot [pscustomobject]) { return '' }
    if (-not ($j.PSObject.Properties.Name -contains 'session_id')) { return '' }
    $id = $j.session_id
    # A non-scalar field (an array, a nested object) stringifies into something that is not an id at
    # all, so it is refused here rather than allowed to pass the shape check by accident.
    if ($id -is [array] -or $id -is [pscustomobject] -or $id -is [hashtable]) { return '' }
    $id = ([string]$id).Trim()
    if (-not (Test-SessionIdShape -SessionId $id)) { return '' }
    return $id
}

function Get-HookSessionId {
    <#
    .SYNOPSIS
        The two above in one call: read this hook's payload and return its session id, or ''.
    #>
    param([int]$TimeoutMs = 250)

    return (Get-SessionIdFromPayload -Payload (Get-HookPayloadRaw -TimeoutMs $TimeoutMs))
}

function Get-SessionCacheRoot {
    <#
    .SYNOPSIS
        The directory session-scoped verdicts live in.

    .DESCRIPTION
        THE PER-USER CACHE DIRECTORY, AND NOT THE SHARED SCRATCH ROOT -- which is a change of address
        forced by #1659 and is the right answer rather than a way around its gate. Every other
        scratch path in this script layer goes through New-ScratchPath in native-capture-lib.ps1,
        which composes '<label>-<pid>-<guid>' under the OS temp directory: unpredictable by
        construction, so nothing can be pre-planted at a name that does not exist until it is used.

        THAT COMPOSER CANNOT SERVE THIS FILE, and the reason is the whole point of the file. A cache
        is read by a LATER process than the one that wrote it -- the hook firing at the fourth
        compaction has to find what the hook firing at startup left -- so its path must be derivable
        twice. A guid is exactly what a second process cannot re-derive. The composer's own docstring
        is about per-run scratch and does not reach this case.

        SO THE EXPOSURE IS REMOVED BY LEAVING THE SHARED ROOT, not by hardening a predictable name
        inside it. The temp root is shared on some platforms (/tmp), which is what made a predictable
        leaf there worth closing; LOCALAPPDATA and XDG_CACHE_HOME are per-user by construction, and a
        stable name inside a directory only this user can write is not the same subject. That is also
        why the temp-path scan in native-capture.tests.ps1 does not need a third exemption for this
        line: it names no temp root, because it is not in one.

        NOT UNDER ~/.claude either: that tree is the plugin administration this family's checks READ,
        and claude-home-sessioncheck snapshots it -- writing a cache into a directory whose contents
        another check reports on is how a diagnostic starts describing itself.

        -Override exists for the suite, so a scenario writes into its own fixture and can assert on
        what is and is not there afterwards. Nothing in the shipped hooks passes it.
    #>
    param([string]$Override = '')

    if ($Override) { return $Override }

    # Windows first because that is what these hooks run on today, then the XDG spelling, then the
    # convention it defaults to. HOME rather than USERPROFILE at the end: on the platforms that reach
    # this line, that is the variable that exists.
    $base = ''
    foreach ($candidate in @($env:LOCALAPPDATA, $env:XDG_CACHE_HOME)) {
        if ($candidate) { $base = $candidate; break }
    }
    if (-not $base -and $env:HOME) { $base = Join-Path $env:HOME '.cache' }
    # LAST RESORT, AND IT IS THE ONE CASE THAT HAS NO GOOD ANSWER: no per-user directory is nameable,
    # so the caller gets a path under the module itself rather than a guess at somebody's home. A
    # write there will normally fail, which under this file's contract means "no cache" and therefore
    # the measured answer -- the correct degradation, not a silent one.
    if (-not $base) { $base = $PSScriptRoot }
    return (Join-Path $base 'dkj-session-cache')
}

function Get-SessionCacheFileName {
    <#
    .SYNOPSIS
        The file one (session, subject) pair is stored in.

    .DESCRIPTION
        '<session id>-<16 hex of SHA256(key)>.json'. The session id is in the name in the clear --
        it has passed the shape check, so it is already file-name-safe -- which is what lets the reap
        and a human reading the directory see whose entries these are. The SUBJECT is hashed rather
        than spelled out because it carries paths: a key naming an engine under a plugin cache and a
        checkout root would blow past the path limit and would put a machine's directory layout in a
        file name for no gain.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$SessionId,
        [Parameter(Mandatory = $true)][string]$Key
    )

    return ("$SessionId-" + (Get-Sha256Hex -Text $Key -Chars 16) + '.json')
}

function Get-SessionCacheEntry {
    <#
    .SYNOPSIS
        The cached verdict for this session and subject, or $null when there is not a usable one.

    .DESCRIPTION
        Returns a pscustomobject with Output (string[]) and ExitCode (int) -- the shape
        Set-SessionCacheEntry was given -- and $null in every other case: no file, an unreadable
        file, JSON this lib does not recognise, an entry whose stored session/key disagree with the
        ones asked for, or one older than -MaxAgeHours.

        THE STORED KEY IS COMPARED, not just the file name it hashed into. The file name is a
        16-hex-character digest, so two subjects can in principle land on one name; comparing the
        key the writer recorded makes a collision a miss rather than a wrong answer.

        THE AGE BOUND CARRIES BOTH ARGUMENTS IN THIS FILE'S HEADER -- the resume that reuses an id,
        and the mid-session change the id cannot see -- and it is checked against the WrittenAt the
        writer recorded rather than the file's mtime, because an mtime is changed by anything that
        touches the file and the question here is when the measurement was taken.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$SessionId,
        [Parameter(Mandatory = $true)][string]$Key,
        [string]$Root = '',
        [double]$MaxAgeHours = 1
    )

    if (-not (Test-SessionIdShape -SessionId $SessionId)) { return $null }

    try {
        $path = Join-Path (Get-SessionCacheRoot -Override $Root) (Get-SessionCacheFileName -SessionId $SessionId -Key $Key)
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
        $j = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not $j) { return $null }
        foreach ($field in @('sessionId', 'key', 'writtenAt', 'exitCode', 'output')) {
            if (-not ($j.PSObject.Properties.Name -contains $field)) { return $null }
        }
        if ([string]$j.sessionId -cne $SessionId) { return $null }
        if ([string]$j.key -cne $Key) { return $null }

        $written = [datetime]::MinValue
        if (-not [datetime]::TryParse([string]$j.writtenAt, [ref]$written)) { return $null }
        $ageHours = ([datetime]::UtcNow - $written.ToUniversalTime()).TotalHours
        # A NEGATIVE AGE IS A MISS, not a fresh entry. A clock moved backwards (or an entry written by
        # a machine whose clock is ahead) would otherwise read as valid for as long as the skew lasts.
        if ($ageHours -lt 0 -or $ageHours -gt $MaxAgeHours) { return $null }

        # AN EXPLICIT JSON null IS A MISS, and it is not the same shape as an empty list. The writer
        # never produces one -- a hand-edited or truncated file can -- and piping $null through
        # ForEach-Object iterates ONCE with $_ = $null, so the entry would read back as a single
        # empty line rather than as no lines: a verdict of one blank line, printed into a session.
        # 'output: []' is a real state (an engine that printed nothing) and survives this, because
        # ConvertFrom-Json hands back an empty Object[] there and not $null (verified, not assumed).
        $outRaw = $j.output
        if ($null -eq $outRaw) { return $null }

        return [pscustomobject]@{
            Output   = @($outRaw | ForEach-Object { [string]$_ })
            ExitCode = [int]$j.exitCode
        }
    } catch {
        return $null
    }
}

function Set-SessionCacheEntry {
    <#
    .SYNOPSIS
        Store a verdict for this session and subject. Returns $true when it landed, $false otherwise.

    .DESCRIPTION
        Best-effort by contract: a failure to write is not a failure of the check that called it, so
        every path here is inside a try and the return value is the only report. The caller has the
        answer in hand either way -- it has just measured it.

        IT REAPS BEFORE IT WRITES, and the window is deliberately much wider than -MaxAgeHours: an
        entry older than the replay bound is dead weight rather than a hazard, and deleting it on the
        first write of the next session is enough to keep the directory from growing one file per
        session forever. -ReapOlderThanHours 0 turns the sweep off, which only the suite does.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$SessionId,
        [Parameter(Mandatory = $true)][string]$Key,
        [AllowEmptyCollection()][string[]]$Output = @(),
        [int]$ExitCode = 0,
        [string]$Root = '',
        [double]$ReapOlderThanHours = 24
    )

    if (-not (Test-SessionIdShape -SessionId $SessionId)) { return $false }

    try {
        $dir = Get-SessionCacheRoot -Override $Root
        if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        if ($ReapOlderThanHours -gt 0) { Remove-StaleSessionCacheEntry -Root $dir -OlderThanHours $ReapOlderThanHours | Out-Null }

        $payload = [ordered]@{
            sessionId = $SessionId
            key       = $Key
            writtenAt = ([datetime]::UtcNow.ToString('o'))
            exitCode  = $ExitCode
            output    = @($Output)
        }
        $path = Join-Path $dir (Get-SessionCacheFileName -SessionId $SessionId -Key $Key)
        $json = ($payload | ConvertTo-Json -Depth 6)
        [System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding $false))
        return $true
    } catch {
        return $false
    }
}

function Remove-StaleSessionCacheEntry {
    <#
    .SYNOPSIS
        Delete cache files last written more than -OlderThanHours ago. Returns how many went.

    .DESCRIPTION
        Reaping on the FILE's mtime rather than on the WrittenAt inside it, which is the opposite of
        what Get-SessionCacheEntry compares and is right for the opposite reason: this pass has to be
        able to remove a file it cannot parse, and a corrupt or truncated entry is exactly the one
        with no readable timestamp.

        IT DELETES ONLY WHAT THIS LIB'S OWN NAMES LOOK LIKE, matched against the shape
        Get-SessionCacheFileName composes -- a session id, a hyphen, sixteen hex characters, '.json'.
        It said so before it did so: the filter was '*.json' alone, which would sweep any stale JSON
        file that happened to sit in the directory (Victor and Sebastian both, on the branch that
        built this). Nothing writes there today, so nothing was lost -- but a docstring promising a
        check the code does not make is the half that would still read as true after the directory
        was shared with something else.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [double]$OlderThanHours = 24
    )

    $gone = 0
    try {
        if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return 0 }
        $cutoff = [datetime]::UtcNow.AddHours(-1 * $OlderThanHours)
        foreach ($f in @(Get-ChildItem -LiteralPath $Root -Filter '*.json' -File -ErrorAction SilentlyContinue)) {
            if ($f.Name -cnotmatch '^[A-Za-z0-9._-]{8,128}-[0-9a-f]{16}\.json$') { continue }
            if ($f.LastWriteTimeUtc -lt $cutoff) {
                Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
                if (-not (Test-Path -LiteralPath $f.FullName)) { $gone++ }
            }
        }
    } catch {
        return $gone
    }
    return $gone
}
