<#
.SYNOPSIS
    SessionStart hook of the workflow plugin: tells THE USER, visibly, whether GitHub carries a newer
    release of the dkj plugins than the one this session is running (issues #2673, #2702).

.DESCRIPTION
    THE GAP IT CLOSES. connector-sessioncheck compares this checkout's install against the LOCAL
    marketplace clone, and deliberately says nothing when the clone itself is stale (#1591). The clone
    advances only on `claude plugin marketplace update`, so the one comparison that answers "should I
    run update-plugins?" -- the running release against GitHub's newest -- never ran at session start.
    Measured October 1, 2026: plugin-versions said "up to date" for 5.10.0 while GitHub had v5.11.0.

    AND THE SECOND GAP, WHICH IS WHY THIS IS A HOOK OF ITS OWN. Every other SessionStart hook in this
    family prints plain stdout, and plain stdout from a SessionStart hook reaches the MODEL'S context
    only -- "A successful hook's stdout is never shown in the transcript" (Claude Code hooks reference,
    read October 1, 2026). So even a perfect verdict would have been invisible to the person who has
    to act on it. This hook answers in JSON instead: `systemMessage` is shown to the user, and
    `hookSpecificOutput.additionalContext` tells the model the same fact. connector-sessioncheck could
    not carry it, because a hook's stdout is either one JSON object or plain text, and that hook's
    whole report is plain text.

    WHAT IS COMPARED, AND WHY NOT A SHA:
      - THIS side is the version in this plugin's own .claude-plugin/plugin.json, read relative to this
        file. That is exactly the payload of THIS plugin the session loaded, and the plugins are
        versioned in lockstep -- but lockstep is a property of a release, not of an install, so it is
        checked rather than assumed (next bullet).
      - THE MIX CHECK (#3273). Every enabled plugin of this marketplace is installed on its own, at its
        own scope, so one session can load them from different releases. Measured October 21, 2026: a
        consumer had dkj-policy at user scope on 5.27.0 and at project scope on 5.26.0, the session
        loaded the user-scope copy of this hook, and it printed "this session runs dkj plugins v5.27.0"
        while dkj-solutions and dkj-subagents-lifehub -- project scope only -- ran from the 5.26.0
        cache. So the install records that cover this checkout (Get-InstallRecord: this path's, plus
        the path-less ones) are read for every enabled id of the marketplace. Where they and the
        running version name more than one version, the verdict is [MIXED] and lists them per plugin.
        Which of two records for one plugin a session loads is not something a hook can see, so a
        plugin with two disagreeing records is itself named as mixed rather than resolved by guess.
        Reading the records is best-effort: where it fails, the lockstep reading above stands.
      - THE RESTART CHECK (#3547), WHICH OUTRANKS ALL OF THE ABOVE. A record names what the NEXT
        process loads, not what this one loaded: measured October 26, 2026 in a consumer, update-plugins
        moved every record to 5.33.0 inside a running process, /clear followed, and this hook said
        [CURRENT] while a 5.23.0 payload of another plugin still ran. So each record's lastUpdated is
        held against the Claude Code process's start (CLAUDE_PID, else the nearest claude ancestor);
        a record rewritten after it gives [RESTART], naming the plugins. Where no start time can be
        read, the check is left out and the verdicts below stand as they did.
      - THE OTHER side is the highest vX.Y.Z tag on the marketplace clone's `origin`, read with
        `git ls-remote --tags --refs`, which writes nothing into the clone.
      - NOT the clone's HEAD against origin's HEAD: the clone tracks the trunk, which moves on every
        merge, while a plugin update only changes anything at a release (plugin-versions' #1772 note).
        A sha comparison would warn several times a day about work no update can deliver.

    ONCE PER SESSION. The network probe is held in session-cache-lib against the harness's session_id,
    so a compaction replays it and a startup or /clear measures afresh -- which is precisely "a check at
    the first prompt of every new session". The lib's one-hour bound applies, for the reasons its header
    gives. A failed probe is never cached, so the next firing simply tries again.

    BEHIND WARNS, CURRENT CONFIRMS (#2702), AND EVERY FAILURE IS SILENT. #2673 shipped this silent
    when current, and that left silence meaning two things -- "current" and "could not check" -- so
    the user still could not tell whether update-plugins was due. A probe that read a tag now always
    speaks: a warning when behind, one confirmation line when current or ahead. No clone, no git, no
    network, a timeout, a short read, an unparseable version, no tag at all: each still prints
    NOTHING, because "could not check" at every offline start is noise that teaches the reader to
    skim -- plugin-versions remains the explicit, on-demand answer. The probe is bounded
    (-TimeoutSeconds, default 5) and runs with GIT_TERMINAL_PROMPT=0, so an origin that suddenly wants
    credentials fails instead of waiting for a prompt nobody can see.

    UNTRUSTED INPUT, NARROWED BY SHAPE. A tag name comes off a remote, so only a ref that matches
    ^refs/tags/v<int>.<int>.<int>$ exactly is read; anything else is ignored, and what reaches the
    printed message is therefore digits and dots built back up from a [version], never the raw ref.

    Read-only: nothing in any repo or clone is modified. Always exits 0.

    Matcher note: hooks.json matches "startup|resume|clear|compact" like its siblings -- see
    roster-sessioncheck.ps1's docstring for why a startup-only matcher goes silent after /compact.

.PARAMETER PluginJsonOverride
    (Optional, for tests) The plugin.json whose version counts as "this session's".

.PARAMETER CloneOverride
    (Optional, for tests) The marketplace clone whose origin is probed.

.PARAMETER CacheRootOverride
    (Optional, for tests) Passed to session-cache-lib as -Root.

.PARAMETER RootOverride
    (Optional, for tests) The checkout whose enable state and install records the mix check reads,
    instead of CLAUDE_PROJECT_DIR or the working directory.

.PARAMETER UserHomeOverride
    (Optional, for tests) The home directory '~/.claude' hangs off, for the mix check's two reads.

.PARAMETER ProcessStartOverride
    (Optional, for tests) An ISO-8601 time that counts as the Claude Code process's start, instead of
    the one read through CLAUDE_PID or the process tree.

.PARAMETER TimeoutSeconds
    How long the remote probe gets. Default 5.
#>
[CmdletBinding()]
param(
    [string]$PluginJsonOverride = '',
    [string]$CloneOverride = '',
    [string]$CacheRootOverride = '',
    [string]$RootOverride = '',
    [string]$UserHomeOverride = '',
    [string]$ProcessStartOverride = '',
    [int]$TimeoutSeconds = 5
)

Set-StrictMode -Version Latest

function ConvertTo-ReleaseVersion {
    <# A [version] from 'X.Y.Z' or 'vX.Y.Z', or $null for any other shape. #>
    param([string]$Text)
    if ($Text -cmatch '^v?(\d{1,6})\.(\d{1,6})\.(\d{1,6})$') {
        return [version]::new([int]$Matches[1], [int]$Matches[2], [int]$Matches[3])
    }
    return $null
}

function ConvertTo-UtcTime {
    <# A UTC [datetime] from a [datetime] or an ISO-8601 string, or $null. Windows PowerShell 5.1's
       ConvertFrom-Json leaves an ISO timestamp a string where PowerShell 7 makes it a [datetime]. #>
    param($Value)
    if ($Value -is [datetime]) { return $Value.ToUniversalTime() }
    $text = [string]$Value
    if (-not $text) { return $null }
    $styles = [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal
    $parsed = [datetime]::MinValue
    if ([datetime]::TryParse($text, [System.Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$parsed)) { return $parsed }
    return $null
}

function Get-ClaudeProcessStartUtc {
    <#
        When the Claude Code process running this session started, in UTC, or $null when that cannot be
        told (#3547). CLAUDE_PID first, which the harness sets for its children; failing that, the first
        ancestor named claude(.exe), at most eight steps up. A $null leaves the restart check out, so
        every verdict below reads as it did before it existed.
    #>
    param([string]$Override)
    if ($Override) { return (ConvertTo-UtcTime $Override) }
    if ($env:CLAUDE_PID -cmatch '^\d{1,9}$') {
        try { return (Get-Process -Id ([int]$env:CLAUDE_PID) -ErrorAction Stop).StartTime.ToUniversalTime() } catch { }
    }
    try {
        $id = $PID
        for ($i = 0; $i -lt 8 -and $id -gt 0; $i++) {
            $p = Get-CimInstance Win32_Process -Filter "ProcessId=$id" -Property ProcessId, ParentProcessId, Name, CreationDate -ErrorAction Stop
            if (-not $p) { break }
            if ([string]$p.Name -match '^claude(\.exe)?$' -and $p.CreationDate) { return ([datetime]$p.CreationDate).ToUniversalTime() }
            $id = [int]$p.ParentProcessId
        }
    } catch { }
    return $null
}

function Get-DkjInstallRecords {
    <#
        Every install record that covers -Root (Get-InstallRecord: this path's, plus the path-less ones)
        for an enabled plugin of -Marketplace, as @{ Name; Record }. Returns @() when the records cannot
        be read: both checks that use it are best-effort, and the lockstep reading stands without them.
    #>
    param([string]$Root, [string]$UserHome, [string]$Marketplace)
    $lib = Join-Path $PSScriptRoot '..\scripts\lib\check-report-lib.ps1'
    if (-not $Root -or -not (Test-Path -LiteralPath $lib -PathType Leaf)) { return @() }
    try {
        . $lib
        $enabled = Get-EnabledPlugins -RepoRoot $Root -UserHomeOverride $UserHome
        $install = Get-InstallRecord -RepoRoot $Root -UserHomeOverride $UserHome
    } catch { return @() }
    $out = @()
    foreach ($id in @($enabled.Ids)) {
        # The name is the one free-text value that reaches the model, and an opened repo's settings can
        # enable any id it likes: only a slug-shaped name of exactly this marketplace counts.
        $halves = $id -split '@'
        if ($halves.Count -ne 2 -or $halves[1] -cne $Marketplace -or -not $halves[0] -or -not (Test-PluginNameSlug $halves[0])) { continue }
        $recs = @()
        if ($install.RecordsById.ContainsKey($id)) { $recs += @($install.RecordsById[$id]) }
        if ($install.PathlessById.ContainsKey($id)) { $recs += @($install.PathlessById[$id]) }
        foreach ($rec in $recs) { $out += [pscustomobject]@{ Name = $halves[0]; Record = $rec } }
    }
    return $out
}

function Get-UpdatedSinceStart {
    <#
        The restart check (#3547): the ordinally sorted names of the plugins whose install record was
        updated after -StartUtc. A record names what the NEXT process loads, so a record rewritten while
        this process runs -- update-plugins inside the session, then /clear -- says nothing about the
        payload this process loaded at its start. @() when there is no start time to compare against.
    #>
    param([object[]]$Records, $StartUtc)
    if (-not $StartUtc) { return @() }
    $names = @{}
    foreach ($entry in @($Records)) {
        $at = ConvertTo-UtcTime $entry.Record.LastUpdated
        if ($at -and $at -gt $StartUtc) { $names[$entry.Name] = $true }
    }
    $sorted = [string[]]@($names.Keys)
    if ($sorted.Count -gt 1) { [array]::Sort($sorted, [System.StringComparer]::Ordinal) }
    return $sorted
}

function Get-LoadedVersionMix {
    <#
        The mix check (#3273): per enabled plugin of -Marketplace, the versions its install records
        carry (-Records, from Get-DkjInstallRecords). Returns @() when everything agrees with -Running,
        or when there are no records; otherwise one 'name vX.Y.Z (scope)[ and ...]' phrase per plugin,
        ordinally sorted.
    #>
    param([object[]]$Records, [version]$Running)
    $versions = @{ "$Running" = $true }
    $phrases = @()
    $byName = [ordered]@{}
    foreach ($entry in @($Records)) {
        if (-not $byName.Contains($entry.Name)) { $byName[$entry.Name] = @() }
        $byName[$entry.Name] += $entry.Record
    }
    foreach ($name in @($byName.Keys)) {
        $parts = @()
        foreach ($rec in @($byName[$name])) {
            $v = ConvertTo-ReleaseVersion -Text ([string]$rec.Version)
            if (-not $v) { continue }
            $versions["$v"] = $true
            $scope = $(if ($rec.Scope -cmatch '^[a-z]{1,16}$') { $rec.Scope } else { 'unknown scope' })
            $parts += "v$v ($scope)"
        }
        if ($parts.Count -gt 0) { $phrases += ($name + ' ' + ($parts -join ' and ')) }
    }
    if ($versions.Count -le 1) { return @() }
    $sorted = [string[]]@($phrases)
    if ($sorted.Count -gt 1) { [array]::Sort($sorted, [System.StringComparer]::Ordinal) }
    return [pscustomobject]@{
        Phrases = $sorted
        Lowest  = (@($versions.Keys | ForEach-Object { [version]$_ }) | Sort-Object | Select-Object -First 1)
    }
}

try {
    # --- this side: the version of the payload that is running ------------------------------------
    $pluginJson = $(if ($PluginJsonOverride) { $PluginJsonOverride } else { Join-Path $PSScriptRoot '..\.claude-plugin\plugin.json' })
    if (-not (Test-Path -LiteralPath $pluginJson -PathType Leaf)) { exit 0 }
    $manifest = Get-Content -LiteralPath $pluginJson -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not ($manifest.PSObject.Properties.Name -contains 'version')) { exit 0 }
    $running = ConvertTo-ReleaseVersion -Text ([string]$manifest.version)
    if (-not $running) { exit 0 }

    # --- the other side: the clone whose origin is GitHub --------------------------------------------
    $marketplace = 'dkj-claude-plugins'
    if ($CloneOverride) {
        $clone = $CloneOverride
    } else {
        $home_ = $(if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME })
        if (-not $home_) { exit 0 }
        $clone = Join-Path $home_ ('.claude\plugins\marketplaces\' + $marketplace)
    }
    if (-not (Test-Path -LiteralPath (Join-Path $clone '.git'))) { exit 0 }

    . (Join-Path $PSScriptRoot '..\scripts\lib\native-capture-lib.ps1')

    # GUARDED, like connector-sessioncheck's: the cache only saves a probe, so its absence or failure
    # must degrade to measuring rather than to the catch below.
    $sessionId = ''
    $cacheLib = Join-Path $PSScriptRoot '..\scripts\lib\session-cache-lib.ps1'
    if (Test-Path -LiteralPath $cacheLib -PathType Leaf) {
        try { . $cacheLib; $sessionId = Get-HookSessionId } catch { $sessionId = '' }
    }
    $cacheKey = 'release-freshness-sessioncheck|' + $clone

    $newest = $null
    $cached = $null
    if ($sessionId) { $cached = Get-SessionCacheEntry -SessionId $sessionId -Key $cacheKey -Root $CacheRootOverride }
    if ($cached) {
        $newest = ConvertTo-ReleaseVersion -Text (@($cached.Output) | Select-Object -First 1)
    } else {
        $env:GIT_TERMINAL_PROMPT = '0'
        $cap = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $clone, 'ls-remote', '--tags', '--refs', 'origin') -DiscardStderr -TimeoutSeconds $TimeoutSeconds
        if ($cap.TimedOut -or $cap.ShortRead -or $cap.ExitCode -ne 0) { exit 0 }
        foreach ($line in @($cap.Output)) {
            if ([string]$line -cmatch '^[0-9a-f]{40}\s+refs/tags/(v\d{1,6}\.\d{1,6}\.\d{1,6})$') {
                $v = ConvertTo-ReleaseVersion -Text $Matches[1]
                if ($v -and (-not $newest -or $v -gt $newest)) { $newest = $v }
            }
        }
        if ($sessionId -and $newest) {
            Set-SessionCacheEntry -SessionId $sessionId -Key $cacheKey -Root $CacheRootOverride -Output @("v$newest") | Out-Null
        }
    }

    if (-not $newest) { exit 0 }

    $root = $(if ($RootOverride) { $RootOverride } elseif ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path })
    $records = @(Get-DkjInstallRecords -Root $root -UserHome $UserHomeOverride -Marketplace $marketplace)
    $updated = @()
    if ($records.Count -gt 0) { $updated = @(Get-UpdatedSinceStart -Records $records -StartUtc (Get-ClaudeProcessStartUtc -Override $ProcessStartOverride)) }
    $mix = Get-LoadedVersionMix -Records $records -Running $running

    if ($updated.Count -gt 0) {
        # RESTART OUTRANKS EVERY VERDICT BELOW (#3547): all of them read the install records, and a record
        # rewritten after this process started describes the next process, not this one. Measured in a
        # consumer: update-plugins moved every record to 5.33.0 mid-session, /clear followed, and this hook
        # said [CURRENT] while a 5.23.0 payload of another plugin was still the one executing.
        $listed = ($updated -join ', ')
        $user = "dkj plugins were updated after this Claude Code process started ($listed), so this session may still run the copies it loaded before. Restart Claude Code to load them -- /clear is not enough. GitHub's newest release is v$newest."
        $model = "release-freshness-sessioncheck: [RESTART] the install records of $listed were updated after this Claude Code process started; the records name what the NEXT process loads, so this session may still run older payloads than they say. This hook's own copy runs v$running; the marketplace's origin's newest release is v$newest. The user has been shown this."
    } elseif ($mix) {
        # MIXED OUTRANKS BOTH VERDICTS BELOW (#3273): either one would name a single version for a
        # session that loaded several. The lowest is what an update has to close.
        $listed = ($mix.Phrases -join '; ')
        if ($mix.Lowest -lt $newest) {
            $user = "dkj plugins are on mixed versions in this session: $listed. GitHub's newest release is v$newest. Run /dkj-policy:update-plugins, then restart the session."
        } else {
            $user = "dkj plugins are on mixed versions in this session: $listed. GitHub's newest release is v$newest."
        }
        $model = "release-freshness-sessioncheck: [MIXED] the enabled dkj plugins load different versions for this checkout ($listed); this hook's own copy runs v$running, the lowest is v$($mix.Lowest), and the marketplace's origin's newest release is v$newest. A skill or hook can therefore run from an older release than this line's own version. The user has been shown this."
    } elseif ($newest -le $running) {
        # CURRENT SPEAKS TOO (#2702). #2673 shipped this as silent, and silence turned out to be two
        # facts the user could not tell apart -- "current" and "could not check" -- so the question it
        # was built to answer ("do I need update-plugins?") was still guesswork on every good start.
        # Only a probe that actually read a tag reaches here; every failure above still says nothing,
        # so this line never claims "up to date" about a check that did not happen.
        $user = "dkj plugins are up to date: this session runs v$running (GitHub's newest release: v$newest)."
        $model = "release-freshness-sessioncheck: [CURRENT] this session runs dkj plugins v$running; the marketplace's origin's newest release is v$newest. The user has been shown this confirmation."
    } else {
        $user = "dkj plugins are out of date: this session runs v$running, GitHub has v$newest. Run /dkj-policy:update-plugins, then restart the session."
        $model = "release-freshness-sessioncheck: [BEHIND] this session runs dkj plugins v$running; the marketplace's origin has release v$newest. The user has been shown this warning; the update-plugins skill closes the gap, and the new release loads only in a session started after it."
    }
    $payload = [ordered]@{
        systemMessage      = $user
        hookSpecificOutput = [ordered]@{
            hookEventName     = 'SessionStart'
            additionalContext = $model
        }
    }
    Write-Output ($payload | ConvertTo-Json -Depth 4 -Compress)
} catch {
    # INLINED STRIP, NOT A LIB CALL -- the reason is in stranded-sweep-sessioncheck.ps1's own catch
    # (#2271): the lib may be the thing that failed to load. Whitespace first, then control characters,
    # then brackets, so no forwarded line can forge a marker.
    $safe = (((($_.Exception.Message) -replace '\s+', ' ') -replace '\p{C}', '') -replace '\[', '(') -replace '\]', ')'
    Write-Host ('release-freshness-sessioncheck skipped due to an error: ' + $safe.Trim())
}
exit 0
