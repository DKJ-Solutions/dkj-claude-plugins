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
      - KEPT-ALWAYS: of the suites that walk the live tree (the selection's Walkers set, 40 on
        October 22, 2026), the ones it can read a changed asset through:
          - A walker that DECLARES its walk scope ('# gate-selection: walks <roots>', and no undeclared
            walk anywhere it reaches -- every walker outside the selection's Always set) is kept only when
            a changed path falls in that scope (the selection's Scoped set). The declaration is
            authoritative for dropping it, open walk or not, whatever its text says (#3392). Before that,
            CI judged every walker by its own text, and on PR #3391 a one-line CSS comment kept three
            ~70-80s suites that mention `css` only in fixture strings or copy a folder holding no
            stylesheet. What makes the trust safe is the scope guard in affected-suites.tests.ps1: every
            declaration is held against the roots and types of the walks the reading can see,
            Copy-Item sources included, so a walk added outside its suite's scope fails there first.
          - A walker that declares nothing (the Always set) is judged as before (#3309, #3316): kept when
            its walk is OPEN, returning a file of any type, when its source mentions a changed path's
            extension (`css`, `svg`, ...), or when it cannot be read. A future typed walk that can enumerate
            a stylesheet has to name the extension to filter on it, and naming it keeps the suite in. The
            guard is crude on purpose: it errs toward running a suite, never toward skipping one.

    WHAT A MISS COSTS IS DIFFERENT FROM THE LOCAL GATE, and that is the trade the owner accepted. Locally a
    missed suite costs a red CI run. Here nothing runs behind the selection, so a missed suite is an ungated
    merge of an asset-only PR. Trusting a declaration to drop a walker is part of that trade, accepted on
    October 24, 2026 with the scope guard as its condition (#3392). What the guard cannot see rests on the
    declaration alone: a walk done inside a script the suite runs against the live tree, and a lib function
    that enumerates the root it is handed and is missing from Get-SuiteReferenceSet's list. A root piped into Get-ChildItem, handed to a function parameter, read through Invoke-GitRead or
    globbed by Select-String has been followed since #3397. The lint job still runs in full on every PR, and that includes its encoding
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

function Remove-BranchDocumentPath {
    <#
    .SYNOPSIS
        The changed paths without the branch's own development document. Issue #3370.

    .DESCRIPTION
        EVERY PR CARRIES ONE, SO WITHOUT THIS THE ASSET-ONLY LANE NEVER OPENS. new-branch writes
        dkj-policy/<branch>.md and only the fold after the merge removes it, so every PR diff holds one
        .md, and Get-StaticAssetVerdict answered 'full' for all of them. Measured on PR #3369, a one-line
        CSS comment: the whole pool over five shards, 'first: dkj-policy/docs-stopwatch-css-comment-v4.md'.

        ONE PATH, EXACTLY, and only the one the caller resolved. The document is the workflow's own
        scaffolding, not a change to anything a suite runs, and the branch-entry gate reads it as a
        workflow of its own. Any other .md still makes the change not asset-only. An empty
        -BranchDocument removes nothing, which is the fail-closed direction: the document stays in, and
        the verdict stays 'full'.
    #>
    param(
        [AllowNull()][AllowEmptyCollection()][string[]]$ChangedPaths,
        [AllowNull()][AllowEmptyString()][string]$BranchDocument
    )

    $doc = "$BranchDocument".Trim().Replace('\', '/')
    if (-not $doc) { return @($ChangedPaths) }
    return @($ChangedPaths | Where-Object { -not [string]::Equals("$_".Trim().Replace('\', '/'), $doc, [System.StringComparison]::Ordinal) })
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
    foreach ($suite in @($selection.Walkers)) {
        # A DECLARED walker runs exactly when its scope admits a changed path (#3392).
        if (@($selection.Always) -notcontains $suite) {
            if (@($selection.Scoped) -contains $suite) { [void]$kept.Add($suite) }
            continue
        }
        # An OPEN undeclared walker is never dropped by type (#3316): its walk can return a file of any
        # type, so its text need not name the changed extension for the walk to read it.
        if (@($selection.Open) -contains $suite) { [void]$kept.Add($suite); continue }
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
