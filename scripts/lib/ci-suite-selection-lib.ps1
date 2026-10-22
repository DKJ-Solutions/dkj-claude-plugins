<#
.SYNOPSIS
    Issue #3309's CI-side suite selection: whether a pull request changes nothing but static assets
    (stylesheets, images, fonts), and if so, which suites the required check still has to run for it.

.DESCRIPTION
    WHY CI SELECTS AT ALL, AND WHY ONLY HERE. #3223 gave the local open-pr gate an affected-suite
    selection and left the whole pool to CI as the safety net, so a one-line CSS fix still waited on all
    ~164 suites over five shards. Maikel decided on October 22, 2026 to trade some of that net for time,
    and to make the trade NARROW: CI selects only for a PR whose every changed path is a static asset. Such
    a PR changes no PowerShell, no workflow, no manifest and no Markdown, so no script the suites run can
    behave differently. What can still differ is a suite that READS the asset, and those are what the
    selection keeps. Every other PR runs the whole pool exactly as before.

    WHAT IS KEPT FOR AN ASSET-ONLY PR, and why each half:
      - MATCHED: every suite Get-AffectedSuiteSelection (gate-lib.ps1) maps the changed paths to. That is
        the same reference graph the local gate trusts, so a suite that names the stylesheet runs.
      - KEPT-ALWAYS: of the suites that walk the live tree (the selection's Always set, 40 on
        October 22, 2026), the ones whose source mentions a changed path's extension (`css`, `svg`, ...).
        Every walk measured that day filters on `*.ps1`, `*.md`, `*.json`, `*.yml` or a named manifest, so
        none of them can enumerate a stylesheet. A future walk that does has to name the extension
        to filter on it, and naming it keeps the suite in. The guard is crude on purpose: it errs
        toward running a suite, never toward skipping one.

    WHAT A MISS COSTS IS DIFFERENT FROM THE LOCAL GATE, and that is the trade the owner accepted. Locally a
    missed suite costs a red CI run. Here nothing runs behind the selection, so a missed suite is an ungated
    merge of an asset-only PR. The lint job still runs in full on every PR, and that includes its encoding
    and text checks over `.css` and `.html`. The next PR that touches anything else runs the whole pool over
    the same tree.

    FAIL-CLOSED, as every CI skip in this repo is (#1300, #2303): a path that cannot be read, a quoted
    (non-ASCII) path, an empty change set or an unproven selection all answer "run the whole pool".

    PURE except Get-StaticAssetSuiteSelection, which reads the tree through Get-AffectedSuiteSelection; the
    caller loads gate-lib.ps1 first. The impure reads (git, the event) live in
    scripts/ci/get-pr-suite-selection.ps1.
#>

# THE ASSET SET. Binary images and fonts, plus CSS. Nothing a PowerShell script executes, and nothing the
# repo's text tooling treats as a document: .html, .js, .ts, .tsx, .json and .md all stay OUT, because
# suites and lint checks read or run them. Widening this set widens the trade, so it is the owner's call.
$script:StaticAssetExtensions = @('.css', '.svg', '.png', '.jpg', '.jpeg', '.gif', '.webp', '.ico', '.woff', '.woff2')

function Get-StaticAssetVerdict {
    <#
    .SYNOPSIS
        Whether every changed path is a static asset. Returns {AssetOnly, Extensions, Reason}: Extensions
        is the distinct extensions found (lower case, with the dot), Reason says why AssetOnly is $false.
    #>
    param([AllowNull()][AllowEmptyCollection()][string[]]$ChangedPaths)

    $verdict = [pscustomobject]@{ AssetOnly = $false; Extensions = @(); Reason = '' }
    $changed = @($ChangedPaths | ForEach-Object { "$_".Trim().Replace('\', '/') } | Where-Object { $_ })
    if ($changed.Count -eq 0) {
        $verdict.Reason = 'no changed path was read, so nothing proves the change is assets only'
        return $verdict
    }
    # A quoted path is git's escape for a non-ASCII name; its "extension" ends in a quote and fails below,
    # which is the safe direction. It is named here so the reason says what actually happened.
    $quoted = @($changed | Where-Object { $_.StartsWith('"') })
    if ($quoted.Count -gt 0) {
        $verdict.Reason = "$($quoted.Count) changed path(s) are not plain ASCII, and a quoted path is not judged"
        return $verdict
    }
    $others = @($changed | Where-Object { $script:StaticAssetExtensions -notcontains [System.IO.Path]::GetExtension($_).ToLowerInvariant() })
    if ($others.Count -gt 0) {
        $verdict.Reason = "$($others.Count) of $($changed.Count) changed path(s) are not static assets (first: $($others[0]))"
        return $verdict
    }
    $verdict.AssetOnly = $true
    $verdict.Extensions = @($changed | ForEach-Object { [System.IO.Path]::GetExtension($_).ToLowerInvariant() } | Sort-Object -Unique)
    return $verdict
}

function Get-StaticAssetSuiteSelection {
    <#
    .SYNOPSIS
        The suites an asset-only change still runs on CI. Returns {Proven, Suites, Matched, KeptAlways,
        PoolCount, Reason}; Proven is $false, with the Reason, whenever the caller must run the whole pool.
        Requires Get-AffectedSuiteSelection (gate-lib.ps1) to be loaded.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$ChangedPaths
    )

    $result = [pscustomobject]@{ Proven = $false; Suites = @(); Matched = @(); KeptAlways = @(); PoolCount = 0; Reason = '' }
    $assets = Get-StaticAssetVerdict -ChangedPaths $ChangedPaths
    if (-not $assets.AssetOnly) { $result.Reason = $assets.Reason; return $result }

    $selection = Get-AffectedSuiteSelection -RepoRoot $RepoRoot -ChangedPaths $ChangedPaths
    $result.PoolCount = $selection.PoolCount
    if (-not $selection.Proven) { $result.Reason = $selection.Reason; return $result }

    # The extension without its dot, as a whole word: 'css' matches '*.css' and "'.css'" alike.
    $tokens = @($assets.Extensions | ForEach-Object { [regex]::Escape($_.TrimStart('.')) })
    $pattern = '(?i)\b(' + ($tokens -join '|') + ')\b'
    $kept = New-Object System.Collections.ArrayList
    foreach ($suite in @($selection.Always)) {
        $full = Join-Path $RepoRoot $suite
        # An unreadable suite is kept: the guard only ever drops a suite it has read.
        $text = $null
        try { $text = [System.IO.File]::ReadAllText($full) } catch { }
        if ($null -eq $text -or $text -match $pattern) { [void]$kept.Add($suite) }
    }
    $result.Matched = @($selection.Matched)
    $result.KeptAlways = @($kept)
    $result.Suites = @(@($selection.Matched) + @($kept) | Sort-Object -Unique)
    $result.Proven = $true
    return $result
}
