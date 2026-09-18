<#
.SYNOPSIS
    The storefront URLs a BWJ store serves, and the preview URLs per market -- one mechanism for the
    two stores, with the market table staying each store's own seam answer.

.DESCRIPTION
    Dot-source this from a script that has to point somebody at a page:

        . (Join-Path $PSScriptRoot '..\lib\market-urls.ps1')   # via the forwarder, see ADOPTING IT
        Write-MarketPreviewUrls -ThemeId 197885264213 -Path '/products/foo,/collections/bar'

    WHY IT SHIPS HERE (issue #1886 candidate 1, under Dave's ruling of September 11, 2026 on issue
    #1881: ANYTHING THE TWO STORES SHARE GOES TO dkj-policy-bwj UNLESS IT IS OBVIOUSLY UNIVERSAL).
    Both BWJ stores had built this, and neither could find the other's: smartwatchbanden called it
    scripts/lib/market-domains.ps1 and xoxowildhearts called it scripts/lib/market-urls.ps1. Only the
    exported function names matched -- Get-MarketPreviewUrls and Write-MarketPreviewUrls -- which is
    why no grep in either repo would ever have surfaced the other, and why the sibling check
    (scripts/sync/check-consumer-siblings.ps1 in the marketplace) had to report it as an ALIASED
    finding rather than as a drifted file. It is the flagship instance of that class.

    ONE CAPABILITY, TWO STOREFRONT TOPOLOGIES, AND THAT IS THE WHOLE DESIGN PROBLEM. smartwatchbanden
    runs five markets on five SEPARATE DOMAINS (smartwatchbanden.nl, smartwatcharmbaender.de, ...), so
    its table mapped market -> domain. xoxowildhearts runs ONE domain with LOCALE-PREFIXED PATHS
    (www.xoxowildhearts.com, /de, /fr, /nl-gb, ...), so its table mapped label -> path. Copying either
    shape onto the other store produces URLs that do not exist, which is exactly what kept these two
    apart. So the shared table carries BOTH axes per row -- Market, Domain, PathPrefix -- and each
    store's shape falls out of it:

        smartwatchbanden   five rows, a different Domain each, PathPrefix '' on every one
        xoxowildhearts     eight rows, the same Domain on every one, a different PathPrefix each

    A third store with two domains and locales under each needs no change here.

    WHAT CONVERGING ACTUALLY MOVED, because a merge of two unequal copies is a decision and not a
    diff. xoxowildhearts' copy was far the more developed and everything it carried is here: the
    path normalisation and its comma split, the git-bash mangled-path refusal, the preview query
    parameters, the applied-theme-id reader. smartwatchbanden had none of those, so for that store
    this is not a move but a repair:

      - THE PREVIEW PARAMETERS. Without _ab=0&_fd=0&_sc=1 a preview holds only through the cookie and
        is lost at the first internal link -- and then the reviewer is looking at LIVE while believing
        they are looking at the preview. smartwatchbanden lost a whole review to that on
        August 5, 2026 and its own builder still did not carry them.
      - THE MANGLED-PATH REFUSAL. Run from git-bash, MSYS rewrites an absolute POSIX argument into a
        Windows path before powershell.exe sees it, so -Path arrives as 'C:/Program Files/Git/...'.
        Nothing about such a run reads as wrong: the summary line is green and one 404 sits among
        correct URLs. It is a refusal rather than a note because a note had already been tried.
      - MORE THAN ONE PAGE PER RUN. A change touching two page types got one joined 404 out of the
        script whose whole job is to hand links over.

    WHAT IS DATA AND STAYS YOURS. The market table itself, and nothing else. Answer
    Get-StorefrontMarkets in your own scripts/repo-config.ps1 -- the same seam file dkj-policy already
    dot-sources -- and the mechanism above serves your brand. Read the table off the live storefront
    rather than from memory when a market is added or removed; the hreflang set is public and needs no
    admin token:

        curl -s https://<your storefront>/ | grep -o 'hreflang="[^"]*"'

    ADOPTING IT, in a store repo. Replace the local market table file with a forwarder that dot-sources
    this one out of the plugin cache, resolved through that repo's scripts/lib/plugin-scripts.ps1 --
    the shape prune-merged.ps1 already uses there. KEEP THE FILE NAME the callers in your repo already
    use (market-domains.ps1 or market-urls.ps1), because a forwarder then costs one file and no caller
    changes. Two adoption notes that are real work rather than a rename:

      1. Get-StorefrontMarkets has to exist in your scripts/repo-config.ps1 before anything here runs,
         and the row shape is stated under Get-MarketTable below.
      2. Get-PreviewPrimeUrl (SINGULAR) is gone and Get-PreviewPrimeUrls (PLURAL) replaces it. A
         preview cookie is set per DOMAIN, so a single prime URL is correct for a one-domain store and
         silently wrong for a five-domain one -- it would prime one domain and leave the other four
         reading live. xoxowildhearts' scripts/theme/verify-preview.ps1 is the one caller, and it has
         to prime once per returned row.

    THE OUTPUT IS MATERIAL AND NOT THE HANDOVER. What a preview handover owes, and how it reaches the
    reviewer, is chapter three of this plugin -- PREVIEW-portable.md, one folder up. It is deliberately
    NOT restated here: smartwatchbanden's copy carried that rule inline as an explicitly temporary
    bridge whose removal trigger was this page shipping with a plugin release, and this is that
    release.

    No Set-StrictMode here: dot-sourcing would modify the calling script's strict mode.
    Pure ASCII (repo convention for .ps1).
#>

# The three parameters the Shopify admin itself hangs on a preview link. Mechanism and not data: this
# is a fact about Shopify's preview, identical in every store, so it is deliberately not a seam answer.
$script:PreviewExtraQuery = '_ab=0&_fd=0&_sc=1'

# A storefront path can never contain a drive letter. This is what MSYS makes of one -- see
# Test-MangledStorefrontPath.
$script:MangledPathPattern = '[A-Za-z]:[\\/]'

function Get-MarketTable {
    <#
        The store's markets, normalised and validated, in the order the store listed them.

        THE ROW SHAPE, which is what a store answers Get-StorefrontMarkets with -- an array of objects
        or hashtables, one per market:

            @{ Market = 'DE'; Domain = 'smartwatcharmbaender.de'; PathPrefix = '' }
            @{ Market = 'DE'; Domain = 'www.xoxowildhearts.com';  PathPrefix = '/de' }

          Market      the label the reader scans down. Required, unique within the table.
          Domain      the host, with no scheme and no trailing slash. Required.
          PathPrefix  '' for a market served at the domain root, otherwise a leading-slash prefix with
                      no trailing slash. Optional; '' is the default.

        ORDER IS THE STORE'S AND IS PRESERVED -- it is the display order of every function below, and
        the first row is the primary market.

        IT VALIDATES RATHER THAN REPAIRS, and that is the lesson of the two copies it replaces: both
        of them wrote their table as a literal that nobody checked, and the failure mode of a wrong
        table is a URL that looks right and 404s. A scheme in Domain, or a trailing slash, produces
        exactly that -- so it is refused here, once, where every caller passes.

        -Markets overrides the seam entirely. That is what the suites use, and what a caller that
        already holds a table uses; it is never a way to skip declaring the seam in a store repo.
    #>
    param([object[]]$Markets = $null)

    $rows = $Markets
    if ($null -eq $rows) {
        # THE SEAM PROBE IS NOT Get-Command, and the expression is inline rather than dot-sourced.
        # `Get-Command <bare name>` routes through the command searcher's wildcard matcher and, on a
        # MISS -- which is the common case for an optional seam -- falls through to a full PATH scan
        # that nothing caches; the marketplace measured 32.5 ms against 0.084 ms per probe and moved
        # every site behind Test-FunctionDefined (issue #1729). That helper lives in `dkj-policy`, and
        # reaching it from here would mean resolving a SECOND plugin's path -- which is the one thing
        # a store's forwarder cannot do, because the lookup that resolves a plugin is itself the file
        # it has to keep locally. So the one expression is written out here rather than depended on.
        if (-not [bool](@($ExecutionContext.InvokeCommand.GetCommands('Get-StorefrontMarkets', 'Function', $false)).Count)) {
            throw ("market-urls: this store has not declared its markets. Add Get-StorefrontMarkets " +
                   "to scripts/repo-config.ps1, returning one row per market with Market, Domain and " +
                   "PathPrefix -- see Get-MarketTable in the shared lib for the shape. Until it is " +
                   "there, no storefront URL can be built.")
        }
        $rows = @(Get-StorefrontMarkets)
    }

    $rows = @($rows | Where-Object { $_ })
    if ($rows.Count -eq 0) {
        throw "market-urls: Get-StorefrontMarkets returned no markets -- a store serves at least one."
    }

    $seen = @{}
    $out  = foreach ($row in $rows) {
        # A hashtable and a pscustomobject both have to work: a seam answer is hand-written, and
        # insisting on one of the two would be a rule about typing rather than about markets.
        $market = [string](Get-MarketRowField -Row $row -Name 'Market')
        $domain = [string](Get-MarketRowField -Row $row -Name 'Domain')
        $prefix = [string](Get-MarketRowField -Row $row -Name 'PathPrefix')

        if (-not $market) { throw "market-urls: a market row has no Market label." }
        if (-not $domain) { throw "market-urls: market '$market' has no Domain." }
        if ($domain -match '^[a-zA-Z][a-zA-Z0-9+.-]*://') {
            throw ("market-urls: market '$market' has Domain '$domain', which carries a scheme. " +
                   "Give the host alone -- the scheme is this lib's.")
        }
        if ($domain -match '/') {
            throw ("market-urls: market '$market' has Domain '$domain', which carries a path. " +
                   "The host belongs in Domain and the rest in PathPrefix.")
        }
        if ($seen.ContainsKey($market)) {
            throw "market-urls: market '$market' is listed twice -- a label names one market."
        }
        $seen[$market] = $true

        if ($prefix) {
            if (-not $prefix.StartsWith('/')) { $prefix = "/$prefix" }
            # A trailing slash here would produce '//products/x' one line down in Get-MarketUrls.
            $prefix = $prefix.TrimEnd('/')
        }

        [pscustomobject]@{ Market = $market; Domain = $domain; PathPrefix = $prefix }
    }
    return @($out)
}

function Get-MarketRowField {
    <# One field out of a market row, whichever of the two hand-written shapes it is. Returns '' when
       the field is absent, so PathPrefix can simply be left off a row that has none.

       IT IS A FUNCTION AND NOT A DOTTED READ for the reason a store repo already learned one layer
       down: a dotted read of an absent property returns $null while nobody has Set-StrictMode on and
       THROWS the moment a caller does, and this lib deliberately does not set that mode itself -- so
       whether a dotted read survives depends entirely on who dot-sources us. #>
    param(
        [Parameter(Mandatory = $true)][AllowNull()]$Row,
        [Parameter(Mandatory = $true)][string]$Name
    )
    if ($null -eq $Row) { return '' }
    if ($Row -is [System.Collections.IDictionary]) {
        if ($Row.Contains($Name)) { return $Row[$Name] }
        return ''
    }
    $prop = $Row.PSObject.Properties[$Name]
    if (-not $prop) { return '' }
    if ($null -eq $prop.Value) { return '' }
    return $prop.Value
}

function Get-MarketDomains {
    <# The market -> domain table, as an ordered hashtable. Kept because smartwatchbanden's callers
       build their own URLs from it; derived from Get-MarketTable so it cannot disagree with it. #>
    param([object[]]$Markets = $null)
    $out = [ordered]@{}
    foreach ($row in (Get-MarketTable -Markets $Markets)) { $out[$row.Market] = $row.Domain }
    return $out
}

function Get-MarketPaths {
    <# The market -> path-prefix table, as an ordered hashtable. Kept for xoxowildhearts' callers, and
       derived from the same source as Get-MarketDomains for the same reason. #>
    param([object[]]$Markets = $null)
    $out = [ordered]@{}
    foreach ($row in (Get-MarketTable -Markets $Markets)) { $out[$row.Market] = $row.PathPrefix }
    return $out
}

function Test-MangledStorefrontPath {
    <# True when a path element carries a Windows drive letter, which means git-bash rewrote it.

       WHY IT IS A REFUSAL AND NOT A NOTE. The documented invocation route runs these scripts through
       powershell.exe with -File. Run from git-bash, MSYS rewrites any argument that looks like an
       absolute POSIX path into a Windows path BEFORE powershell.exe sees it, so -Path arrives as
       'C:/Program Files/Git/products/foo'. With a comma-separated list it mangles only the LEADING
       element, because the whole list is one argument and only its first character is a '/'. Nothing
       in such a run reads as wrong -- the theme pushes, the summary line is green, and the correct
       URLs sit under one that 404s. Those URLs are the script's whole deliverable.

       WHY THE DRIVE LETTER AND NOT "does not start with /". Refusing a missing leading slash would
       remove a documented convenience -- 'products/x' is accepted and prefixed -- while catching
       nothing this does not. A drive letter is the mangling's own fingerprint and cannot occur in a
       real storefront path. #>
    param([string]$Path)
    return ([bool]("$Path" -match $script:MangledPathPattern))
}

function Get-NormalizedPaths {
    <# Turn whatever a caller passed for -Path into a clean list of storefront paths.

       IT SPLITS ON ',' AND THAT SPLIT IS THE POINT, not the array parameter beside it. The documented
       invocation route runs through powershell.exe with -File, and -File binds its arguments as
       LITERAL strings -- so -Path '/a','/b' arrives as ONE element '/a,/b' even when the parameter is
       declared [string[]]. Declaring the array is necessary and NOT sufficient.

       SPLITTING ON ',' IS SAFE FOR THESE STORES, and that is a judgement rather than a law. A comma is
       a legal URI path character (RFC 3986 sub-delims), but a Shopify handle is lowercase
       alphanumerics and hyphens, so no product, collection, page or blog path this is ever pointed at
       can hold one. A caller who genuinely needs a comma dot-sources this lib and passes a real array
       element that already starts with '/'.

       IT THROWS ON A MANGLED PATH. This is the single funnel every caller reaches, so refusing once is
       refusing everywhere. #>
    param([string[]]$Path = @('/'))
    $seen = @{}
    $out  = foreach ($raw in @($Path)) {
        foreach ($part in ("$raw" -split ',')) {
            $p = $part.Trim()
            if (-not $p) { continue }
            # Before the leading slash is added, not after: prefixing turns 'C:/Program Files/Git/...'
            # into '/C:/Program Files/Git/...', which is what silently reached the printed URL.
            if (Test-MangledStorefrontPath -Path $p) {
                throw ("-Path holds '$p', which is not a storefront path -- git-bash (MSYS) rewrote " +
                       "it into a Windows path before powershell.exe saw it. With a comma-separated " +
                       "list only the FIRST page is mangled, so the rest of the run looks correct. " +
                       "Re-run from PowerShell, or prefix the command with MSYS_NO_PATHCONV=1.")
            }
            if (-not $p.StartsWith('/')) { $p = "/$p" }
            # Order is the caller's, so dedupe by remembering what has been seen rather than by sorting.
            if ($seen.ContainsKey($p)) { continue }
            $seen[$p] = $true
            $p
        }
    }
    # An all-blank -Path is a caller who meant the home page, not one who meant no page at all.
    if (-not @($out).Count) { return @('/') }
    return @($out)
}

function Get-MarketUrls {
    <# Full storefront URLs, one per market PER PATH -- the LIVE pages, with no preview parameters.
       -Path defaults to the home page and accepts more than one page; Get-NormalizedPaths has the
       forms it takes. #>
    param(
        [string[]]$Path = @('/'),
        [object[]]$Markets = $null
    )
    $paths = Get-NormalizedPaths -Path $Path
    # Market outer, path inner: the reader picks one market and then looks at its pages, so the market
    # label is what they scan down.
    $out = foreach ($row in (Get-MarketTable -Markets $Markets)) {
        foreach ($p in $paths) {
            # A market served at the domain ROOT keeps the trailing slash on its home page; a market
            # served under a prefix does not ('/de', never '/de/').
            $suffix = if ($p -eq '/') { if ($row.PathPrefix) { '' } else { '/' } } else { $p }
            [pscustomobject]@{
                Market = $row.Market
                Path   = $p
                Url    = "https://$($row.Domain)$($row.PathPrefix)$suffix"
            }
        }
    }
    return @($out)
}

function Add-PreviewQuery {
    <# The preview parameters on one storefront URL.

       .Contains and not '-like "*?*"': in -like a '?' is a WILDCARD for any single character, so that
       test is true for every non-empty string. One of the two source copies shipped an '&' where a '?'
       belonged that way -- a URL that looks right and does nothing. #>
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$ThemeId
    )
    $sep = if ($Url.Contains('?')) { '&' } else { '?' }
    return "$Url$sep" + "preview_theme_id=$ThemeId&$($script:PreviewExtraQuery)"
}

function Get-MarketPreviewUrls {
    <# The same URLs as Get-MarketUrls, carrying the preview parameters for a given theme id. #>
    param(
        [Parameter(Mandatory = $true)][string]$ThemeId,
        [string[]]$Path = @('/'),
        [object[]]$Markets = $null
    )
    $out = foreach ($row in (Get-MarketUrls -Path $Path -Markets $Markets)) {
        [pscustomobject]@{
            Market = $row.Market
            Path   = $row.Path
            Url    = Add-PreviewQuery -Url $row.Url -ThemeId $ThemeId
        }
    }
    return @($out)
}

function Get-ControlThemeId {
    <#
        The theme id a CONTROL url must name -- the store's live theme.

        -LiveThemeId wins where a caller holds one; otherwise this reads the consuming repo's own
        Get-ShopifyLiveThemeId, which is the seam dkj-subagents-shopify's live-theme guard already
        reads, so a store that republishes under a new id keeps ONE place to correct. The seam probe
        is the inline GetCommands expression for the reason written out in Get-MarketTable.

        IT THROWS RATHER THAN FALLING BACK, and that is the whole point of it. The bare URL is a
        syntactically perfect control that renders the PREVIEW theme on any domain where the preview
        link was opened first -- so a fallback would reproduce, silently, the exact defect this
        function exists to close (issue #2052).
    #>
    param([string]$LiveThemeId = '')

    if ($LiveThemeId) { return $LiveThemeId }

    if (-not [bool](@($ExecutionContext.InvokeCommand.GetCommands('Get-ShopifyLiveThemeId', 'Function', $false)).Count)) {
        throw ("market-urls: no live theme id, so no control URL can be built. Either pass " +
               "-LiveThemeId, or add Get-ShopifyLiveThemeId to scripts/repo-config.ps1 -- the same " +
               "seam dkj-subagents-shopify's live-theme guard reads. A control without it would be " +
               "the bare URL, which renders the PREVIEW theme once the preview link has been opened " +
               "on that domain.")
    }

    $id = [string](Get-ShopifyLiveThemeId)
    if (-not $id) {
        throw ("market-urls: Get-ShopifyLiveThemeId answered nothing. A control URL names the live " +
               "theme explicitly; there is no safe default for it.")
    }
    return $id
}

function Get-MarketHandoverPairs {
    <# Per market and per path, the PREVIEW url beside the LIVE one.

       WHY THE PAIR IS A FUNCTION AND NOT SOMETHING A CALLER ZIPS TOGETHER. Chapter three of this
       plugin (PREVIEW-portable.md) states that a handover is a PAIR per market -- the preview, and the
       same page on the live theme as the control -- so the difference is one tab-switch rather than a
       recollection. Neither store could build that from its own copy: smartwatchbanden's produced
       preview URLs only, and both left the pairing to whoever was writing the handover page. This is
       the smallest expression of what that chapter asks for, and it is the input a handover page
       takes.

       THE CONTROL HALF NAMES THE LIVE THEME ID, and this function got that wrong until issue #2052.
       It returned the bare storefront URL -- precisely the form that chapter spends a measured table
       ruling out, because preview_theme_id sets a per-domain COOKIE and the bare URL keeps rendering
       the preview once the preview link has been opened. Both tabs then agree and the reviewer
       concludes the change is not visible. The docstring above is why that mattered more than an
       ordinary mismatch: this function is named as the answer to the recollection problem, so a
       consumer trusting it got the half the chapter proves. #>
    param(
        [Parameter(Mandatory = $true)][string]$ThemeId,
        [string[]]$Path = @('/'),
        [object[]]$Markets = $null,
        [string]$LiveThemeId = ''
    )
    # Resolved ONCE, before the loop, so a store with no seam fails on the first call rather than
    # per market -- and so the throw lands before any half-built pair is handed back.
    $liveId = Get-ControlThemeId -LiveThemeId $LiveThemeId
    $out = foreach ($row in (Get-MarketUrls -Path $Path -Markets $Markets)) {
        [pscustomobject]@{
            Market     = $row.Market
            Path       = $row.Path
            PreviewUrl = Add-PreviewQuery -Url $row.Url -ThemeId $ThemeId
            LiveUrl    = Add-PreviewQuery -Url $row.Url -ThemeId $liveId
        }
    }
    return @($out)
}

function Get-PreviewPrimeUrls {
    <#
        The URLs a cookie jar must be primed on before any scripted preview fetch: one per DISTINCT
        DOMAIN in the table, each the home page of the first market on that domain, carrying the
        preview parameters.

        WHY THIS EXISTS AT ALL. A cookie-less fetch of a ?preview_theme_id URL returns the LIVE theme:
        HTTP 200, a full page, and nothing in the response saying the preview was not applied. The
        preview parameters keep a BROWSER on the preview because the browser holds the cookie; a
        scripted curl or fetch has no cookie jar unless it is told to carry one. A session comparing
        such a fetch against live is comparing live against live.

        WHY IT IS PLURAL, and this is the one place where converging two stores CHANGED an answer
        rather than merged one. The preview cookie is set per domain. For a store on one domain with
        locale paths, priming once covers every locale -- which is what the single-URL version this
        replaces assumed. For a store on five separate domains that same assumption primes one domain
        and leaves the other four returning live, silently, in the exact check that exists to prove the
        reader is not looking at live. So the shape follows the table rather than the caller's habit.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$ThemeId,
        [object[]]$Markets = $null
    )
    # Resolve the table ONCE. Reading it inside the loop would re-run the store's seam function per
    # market, which is the shape that turns a cheap lookup into a surprise.
    $byMarket = Get-MarketDomains -Markets $Markets
    $seen = @{}
    $out  = foreach ($row in (Get-MarketUrls -Path '/' -Markets $Markets)) {
        # Domain is not carried on a Get-MarketUrls row, so read it back off the table by market.
        $domain = $byMarket[$row.Market]
        if ($seen.ContainsKey($domain)) { continue }
        $seen[$domain] = $true
        [pscustomobject]@{
            Market = $row.Market
            Domain = $domain
            Url    = Add-PreviewQuery -Url $row.Url -ThemeId $ThemeId
        }
    }
    return @($out)
}

function Get-AppliedThemeId {
    <# The theme id the storefront HTML says rendered this page, or $null when the marker is absent.
       Matches  Shopify.theme = { ... "id": <digits> ... }  at any spacing and property order. The
       leading quote in '"id"' is what keeps it off 'theme_store_id"' (no quote before that 'id').

       This is the one reliable programmatic signal that a fetch actually reached the preview: read it
       back and compare it to the preview_theme_id that was asked for. #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Html)
    $m = [regex]::Match($Html, 'Shopify\.theme\s*=\s*\{[^}]*?"id"\s*:\s*(\d+)')
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

function Write-MarketPreviewUrls {
    <# Print the preview URLs per market and per path.

       THIS OUTPUT IS MATERIAL, NOT THE HANDOVER, and the rule it is material for is chapter three of
       this plugin rather than a paragraph repeated here. Both source copies carried a version of that
       rule inline; one of them said in its own docstring that doing so was a temporary bridge until
       the page shipped with a plugin release. #>
    param(
        [Parameter(Mandatory = $true)][string]$ThemeId,
        [string[]]$Path = @('/'),
        [object[]]$Markets = $null
    )
    # Build BEFORE printing the header. Get-NormalizedPaths refuses a git-bash-mangled path, and a
    # header printed above that refusal reads as a list of URLs that failed to appear rather than as a
    # run that never started.
    $rows = @(Get-MarketPreviewUrls -ThemeId $ThemeId -Path $Path -Markets $Markets)
    Write-Host ''
    Write-Host 'Preview URLs per market:' -ForegroundColor Cyan
    # ONE LINE PER MARKET PER PATH. The market label prints once per group, so a two-path run stays as
    # scannable as a one-path run.
    $last = ''
    foreach ($entry in $rows) {
        $label = if ($entry.Market -eq $last) { '' } else { $entry.Market }
        $last  = $entry.Market
        Write-Host ("  {0,-6} {1}" -f $label, $entry.Url)
    }
    Write-Host ''
    Write-Host 'This is the MATERIAL, not the handover.' -ForegroundColor Yellow
    Write-Host ('  A handover is ONE LINK to a published page, carrying the pages that ACTUALLY ' +
        'changed and the live control beside each one.')
    Write-Host '  The rule: PREVIEW-portable.md, which ships with dkj-policy-bwj.'
    # The caveat sits in the same output as the URLs it qualifies: a warning one scroll away is one
    # nobody reads on the day it matters.
    Write-Host ('Verifying one of these from a script? A bare curl/fetch of a ?preview_theme_id URL ' +
        'returns LIVE -- prime a cookie jar on every URL Get-PreviewPrimeUrls returns first.') -ForegroundColor Yellow
}
