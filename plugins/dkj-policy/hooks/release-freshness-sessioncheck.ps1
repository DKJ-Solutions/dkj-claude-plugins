<#
.SYNOPSIS
    SessionStart hook of the workflow plugin: warns THE USER, visibly, when GitHub carries a newer
    release of the dkj plugins than the one this session is running (issue #2673).

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
        file. That is exactly the payload the session loaded -- no install record has to be resolved,
        and the plugins are versioned in lockstep, so one version speaks for all of them.
      - THE OTHER side is the highest vX.Y.Z tag on the marketplace clone's `origin`, read with
        `git ls-remote --tags --refs`, which writes nothing into the clone.
      - NOT the clone's HEAD against origin's HEAD: the clone tracks the trunk, which moves on every
        merge, while a plugin update only changes anything at a release (plugin-versions' #1772 note).
        A sha comparison would warn several times a day about work no update can deliver.

    ONCE PER SESSION. The network probe is held in session-cache-lib against the harness's session_id,
    so a compaction replays it and a startup or /clear measures afresh -- which is precisely "a check at
    the first prompt of every new session". The lib's one-hour bound applies, for the reasons its header
    gives. A failed probe is never cached, so the next firing simply tries again.

    SILENT UNLESS BEHIND, AND SILENT ON EVERY FAILURE. No clone, no git, no network, a timeout, a
    short read, an unparseable version, no tag at all: each prints NOTHING. A warning that fires on
    noise teaches the reader to skim, and "could not check" at every offline start is exactly that
    noise -- plugin-versions remains the explicit, on-demand answer. The probe is bounded
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

.PARAMETER TimeoutSeconds
    How long the remote probe gets. Default 5.
#>
[CmdletBinding()]
param(
    [string]$PluginJsonOverride = '',
    [string]$CloneOverride = '',
    [string]$CacheRootOverride = '',
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

try {
    # --- this side: the version of the payload that is running ------------------------------------
    $pluginJson = $(if ($PluginJsonOverride) { $PluginJsonOverride } else { Join-Path $PSScriptRoot '..\.claude-plugin\plugin.json' })
    if (-not (Test-Path -LiteralPath $pluginJson -PathType Leaf)) { exit 0 }
    $manifest = Get-Content -LiteralPath $pluginJson -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not ($manifest.PSObject.Properties.Name -contains 'version')) { exit 0 }
    $running = ConvertTo-ReleaseVersion -Text ([string]$manifest.version)
    if (-not $running) { exit 0 }

    # --- the other side: the clone whose origin is GitHub --------------------------------------------
    if ($CloneOverride) {
        $clone = $CloneOverride
    } else {
        $home_ = $(if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME })
        if (-not $home_) { exit 0 }
        $clone = Join-Path $home_ '.claude\plugins\marketplaces\dkj-claude-plugins'
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

    if (-not $newest -or $newest -le $running) { exit 0 }

    $user = "dkj plugins are out of date: this session runs v$running, GitHub has v$newest. Run /dkj-policy:update-plugins, then restart the session."
    $model = "release-freshness-sessioncheck: [BEHIND] this session runs dkj plugins v$running; the marketplace's origin has release v$newest. The user has been shown this warning; the update-plugins skill closes the gap, and the new release loads only in a session started after it."
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
