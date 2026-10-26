<#
.SYNOPSIS
    The plugin's own hub (#3245): the repo's home page, which the general pages server answers on '/',
    '/index.html' and '/hub' -- and '/about' sends there (#3289) -- and its Repository page on '/repository'
    (#3383), in every repo that has not opted out with OwnHub. No I/O -- hub/pages/serve-general-pages.ps1
    reads the state file and hands the values in, so every rule here is tested without a server.

.DESCRIPTION
    INBOUND #3245. The owner decided (October 21, 2026) that the plugin serves the hub in EVERY repo,
    whether or not it states Get-DevPreview: the general pages server is the hub, so the hub and its General
    pages share one origin, and a server the repo states becomes its PRODUCT, one link on the hub. This page
    replaces #3047's placeholder, whose own server and ports (4880-4889) are retired; what of that page
    survived is here: the setup cards, the facts and the repo-name handling.

    THE HOUSE HUB FORM (#3383, the owner, October 24, 2026), which the source repo's own hub took first: under
    the site header the home page is ONE .grid-3 of card links with no heading above them -- the product, the
    Repository page and the General pages but Issues -- each a .card.card--link (Format-HubCardLinkHtml). A repo that states no product gets the two setup
    cards under the grid. The facts and the Issues page are the Repository page's (Format-PluginRepoRepositoryHtml),
    not the home page's: the home page only gets you somewhere.

    THE PAGE STARTS FROM THE HOUSE STYLE: it loads /house-style.css and /house-theme.js, which the general
    server serves from the canonical copy inside dkj-policy's payload (assets/house-style/,
    which Get-HouseStyleDir names), in every repo, and its own layer uses only names the house file does not
    define (.ph-*). The form, its blocks and their order are laid down in the plugin's
    assets/house-style/README.md, "The hub".

    ONE ORIGIN: every card links its page by bare path, because this page is served by the same server, so the
    visitor keeps one origin and one stored theme choice.

    THE REPO NAME, THE SLUG AND THE PRODUCT URL ARE THE ONLY VALUES FROM OUTSIDE. The name is a repo name or a
    folder name, so it is HTML-escaped and cut at 80 characters; the url comes out of the state file, which the
    reader believes only as a plain loopback url, and it is HTML-escaped again here and linked only when it
    still has that shape; the slug is linked to GitHub only when it is a plain owner/name.

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/dev-preview-sessionstart.tests.ps1 in
    the source repo -- change one, run the other.
#>

. (Join-Path $PSScriptRoot 'dev-preview-rules.ps1')
. (Join-Path $PSScriptRoot 'general-pages-lib.ps1')

function ConvertTo-PluginRepoHubName {
    <#
        A repo or folder name as both pages show it, NOT yet escaped: control characters blanked, cut at 80,
        'this repo' when empty. Each caller escapes it where it is used, once.
    #>
    param([AllowNull()][AllowEmptyString()][string]$Name)
    $t = ([string]$Name) -replace '[\p{C}]', ' '
    if ($t.Length -gt 80) { $t = $t.Substring(0, 80) }
    if (-not $t.Trim()) { $t = 'this repo' }
    return $t.Trim()
}

function Format-PluginRepoHubHtml {
    <#
        The home page for the repo named -RepoName. -Mode is what the repo states: 'none' (no Get-DevPreview:
        the setup cards show) or 'product' (a server of its own: the first card links it). -ProductUrl is that
        server's url, or empty where it is not running (its card says so). -PagesUrl is this server's own base
        url; it is always the general server that serves this page, so every card links by bare path, and
        without one the General cards give way to a line saying the server is not running. -Folder is kept for
        the callers: the facts it named are the Repository page's now. No Brand book card: the brand book is the
        source repo's product, and a consumer hub neither links nor serves it (#3475).
    #>
    param(
        [AllowNull()][AllowEmptyString()][string]$RepoName,
        [AllowNull()][AllowEmptyString()][string]$Folder = '',
        [ValidateSet('none', 'product')][string]$Mode = 'none',
        [AllowEmptyString()][string]$ProductUrl = '',
        [AllowEmptyString()][string]$PagesUrl = ''
    )
    $n =ConvertTo-GeneralPageText (ConvertTo-PluginRepoHubName $RepoName)
    $product = if (Test-RepoHubLocalUrl $ProductUrl) { $ProductUrl } else { '' }
    $general = $PagesUrl -cmatch '^http://localhost:[0-9]{4,5}/?\z'
    $e = { param($v) ConvertTo-GeneralPageText $v }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<!doctype html>')
    # With no choice stored it falls back to the default every other dev page uses (#3166, #3390). The theme key is
    # the general pages' own: the hub and its pages are one origin now, so a theme picked on one holds on the others.
    [void]$sb.AppendLine('<html lang="en" data-theme-default="' + (& $e (Get-GeneralPagesThemeDefault)) + '" data-width-default="full" data-theme-key="general-pages">')
    [void]$sb.AppendLine('<head>')
    [void]$sb.AppendLine('<meta charset="utf-8">')
    [void]$sb.AppendLine('<meta name="viewport" content="width=device-width, initial-scale=1">')
    [void]$sb.AppendLine('<title>' + $n + ' -- Home</title>')
    [void]$sb.AppendLine('<link rel="stylesheet" href="/house-style.css">')
    [void]$sb.AppendLine('<script src="/house-theme.js"></script>')
    # The repo layer: one name the house file does not define (.ph-code), for the code samples.
    [void]$sb.AppendLine('<style>')
    [void]$sb.AppendLine('.ph-code { margin: var(--spacing-3) 0 0; padding: var(--spacing-3) var(--spacing-4); background: var(--paper-1); border: 1px solid var(--paper-3); border-radius: 8px; overflow-x: auto; font-size: var(--text-xs); line-height: 1.6; }')
    [void]$sb.AppendLine('</style>')
    [void]$sb.AppendLine('</head>')
    [void]$sb.AppendLine('<body>')
    $lead = if ($Mode -eq 'product') { 'The way in to what this repo offers: its product, its pages and its facts.' }
            else { 'The way in to this repo. It states no dev server of its own yet, so there is no product to link.' }
    # The site header on the home page too (October 22, 2026): it names the repo, so the page has no intro of its own.
    [void]$sb.Append((Format-RepoHomeHeadHtml -RepoName $n -Lead $lead -Brand (ConvertTo-SiteHeaderName -RepoName (ConvertTo-PluginRepoHubName $RepoName)) -BrandTag 'hub'))

    # Every page a card of its own, three to a row, with no heading above them (#3383): the product first, then
    # the Repository page, and the General pages but Issues (the Repository page's).
    [void]$sb.AppendLine('<div class="grid-3">')
    if ($Mode -eq 'product') {
        if ($product) {
            [void]$sb.AppendLine((Format-HubCardLinkHtml -Href $product -Label 'Product' -Sub ($product + ' -- the server this repo states in Get-DevPreview') -Icon 'product'))
        } else {
            [void]$sb.AppendLine('<section class="card"><p class="msg" role="status">This repo''s own server is not running. The session-start line says why, and it is started again at the next session start.</p></section>')
        }
    }
    [void]$sb.AppendLine((Format-HubCardLinkHtml -Href '/repository' -Label 'Repository' -Sub 'This repo''s facts and its open issues' -Icon 'repository'))
    if ($general) {
        foreach ($p in @(Get-GeneralPages | Where-Object { $_.Href -ne '/issues' })) { [void]$sb.AppendLine((Format-HubCardLinkHtml -Href $p.Href -Label $p.Label -Sub $p.Sub -Icon $p.Icon)) }
    } else {
        [void]$sb.AppendLine('<section class="card grid__full"><p class="msg" role="status">The general pages server is not running. It starts at the next session start, and its pages are linked here from then on.</p></section>')
    }
    [void]$sb.AppendLine('</div>')

    # Where the repo states no product, the two setup cards stand under the grid, under one h2 of their own and
    # each titled with an h3 (#3175): they are instructions, not links, so they are no card in the grid.
    if ($Mode -ne 'product') {
        [void]$sb.AppendLine('<div class="grid-2">')
        [void]$sb.AppendLine('<div class="grid__head"><h2>Set up a product</h2><p class="card__sub">Two steps, both in this repo''s own files</p></div>')
        [void]$sb.AppendLine('<section class="card grid__full">')
        [void]$sb.AppendLine('<div class="card__head"><h3 class="card__title">Add a dev server of your own</h3><p class="card__sub">From the next session on, it is the product on this page</p></div>')
        [void]$sb.AppendLine('<div>')
        [void]$sb.AppendLine('<p>State <code>Get-DevPreview</code> in this repo''s <code>scripts/repo-config.ps1</code>. The hook then starts that server, or reuses the one already running, and hands out its link beside this hub''s.</p>')
        [void]$sb.AppendLine('<pre class="ph-code"><code>function Get-DevPreview {')
        [void]$sb.AppendLine('    @{')
        [void]$sb.AppendLine('        Command = ''npm run dev -- --host 127.0.0.1 --port {port} --strictPort''')
        [void]$sb.AppendLine('        Ports   = 5173..5180')
        [void]$sb.AppendLine('    }')
        [void]$sb.AppendLine('}</code></pre>')
        [void]$sb.AppendLine('<p class="muted">Every field, and the rules for <code>Command</code>, are in the dkj-policy plugin''s <code>hub/README.md</code>, under &quot;The dev-preview hook&quot;. A repo that serves its own hub (the home page on <code>/</code>) adds <code>OwnHub = $true</code>.</p>')
        [void]$sb.AppendLine('</div>')
        [void]$sb.AppendLine('</section>')
        [void]$sb.AppendLine('<section class="card grid__full">')
        [void]$sb.AppendLine('<div class="card__head"><h3 class="card__title">Open it in VS Code</h3><p class="card__sub">In the Simple Browser rather than the system browser</p></div>')
        [void]$sb.AppendLine('<div>')
        [void]$sb.AppendLine('<p>Route the hub''s port in this repo''s <code>.vscode/settings.json</code>:</p>')
        [void]$sb.AppendLine('<pre class="ph-code"><code>"workbench.externalUriOpeners": {')
        [void]$sb.AppendLine('    "localhost:4890": "simpleBrowser.open"')
        [void]$sb.AppendLine('}</code></pre>')
        [void]$sb.AppendLine('<p class="muted">The hub takes the first free port from 4890 to 4899, so a repo opened beside others may get a later one; the session-start line names the port it got.</p>')
        [void]$sb.AppendLine('</div>')
        [void]$sb.AppendLine('</section>')
        [void]$sb.AppendLine('</div>')
    }

    [void]$sb.AppendLine('<p class="footer-note">Each page names its own source. Served on 127.0.0.1 only, by the dkj-policy plugin''s <code>hub/pages/serve-general-pages.ps1</code>.</p>')
    [void]$sb.AppendLine('</main>')
    [void]$sb.AppendLine('<script>DKJTheme.settings(document.getElementById("settings"), { label: "Settings", title: "Settings", theme: "Theme", reset: "Reset theme", light: "Light", dark: "Dark", width: "Width", fluid: "Fluid", phone: "Phone", full: "Full" });</script>')
    [void]$sb.AppendLine('</body>')
    [void]$sb.AppendLine('</html>')
    return $sb.ToString()
}

function Format-PluginRepoRepositoryHtml {
    <#
        The Repository page on '/repository' (#3383): everything about the repo itself. Its facts as a .facts--row
        (label over value, no card, since the cards on these pages are links), then its pages a card each in a
        .grid-3: Issues (this server's, by bare path) and, where -Slug is a plain GitHub owner/name, its pull
        requests and CI runs on GitHub. -RepoName, -Folder, -Mode, -ProductUrl and -PagesUrl are
        Format-PluginRepoHubHtml's; -Slug is owner/name from the origin remote, or empty.
    #>
    param(
        [AllowNull()][AllowEmptyString()][string]$RepoName,
        [AllowNull()][AllowEmptyString()][string]$Folder = '',
        [AllowNull()][AllowEmptyString()][string]$Slug = '',
        [ValidateSet('none', 'product')][string]$Mode = 'none',
        [AllowEmptyString()][string]$ProductUrl = '',
        [AllowEmptyString()][string]$PagesUrl = ''
    )
    $e = { param($v) ConvertTo-GeneralPageText $v }
    $name = ConvertTo-PluginRepoHubName $RepoName
    $f = if ($Folder) { & $e (ConvertTo-PluginRepoHubName $Folder) } else { & $e $name }
    $product = if (Test-RepoHubLocalUrl $ProductUrl) { $ProductUrl } else { '' }
    $gh = if ($Slug -cmatch '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+\z') { 'https://github.com/' + $Slug } else { '' }
    $devPreview = if ($Mode -ne 'product') { 'none stated yet' } elseif ($product) { & $e $product } else { 'stated, not running' }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<dl class="facts facts--row">')
    if ($gh) { [void]$sb.AppendLine('<div><dt>GitHub</dt><dd><a href="' + (& $e $gh) + '">' + (& $e $Slug) + '</a></dd></div>') }
    [void]$sb.AppendLine('<div><dt>Folder</dt><dd>' + $f + '</dd></div>')
    [void]$sb.AppendLine('<div><dt>Dev preview</dt><dd>' + $devPreview + '</dd></div>')
    [void]$sb.AppendLine('<div><dt>Stated in</dt><dd>scripts/repo-config.ps1</dd></div>')
    [void]$sb.AppendLine('<div><dt>Hub served by</dt><dd>the dkj-policy plugin, on a port from 4890 to 4899</dd></div>')
    [void]$sb.AppendLine('</dl>')
    [void]$sb.AppendLine('<div class="grid-3">')
    if ($PagesUrl -cmatch '^http://localhost:[0-9]{4,5}/?\z') {
        [void]$sb.AppendLine((Format-HubCardLinkHtml -Href '/issues' -Label 'Issues' -Sub 'The open issues, grouped by what they wait on' -Icon 'issues'))
    } else {
        [void]$sb.AppendLine('<section class="card"><p class="msg" role="status">Issues is a general page, and the general pages server is not running. It starts at the next session start.</p></section>')
    }
    if ($gh) {
        [void]$sb.AppendLine((Format-HubCardLinkHtml -Href "$gh/pulls" -Label 'Pull requests' -Sub 'On GitHub' -Icon 'pull-request'))
        [void]$sb.AppendLine((Format-HubCardLinkHtml -Href "$gh/actions" -Label 'Actions' -Sub 'The CI runs, on GitHub' -Icon 'actions'))
    }
    [void]$sb.AppendLine('</div>')
    return Format-GeneralPageHtml -Title 'Repository' -SiteName $name -Body $sb.ToString() `
        -Lead 'The repo this hub serves: its facts, its open issues and its pull requests.' `
        -FooterNote 'The facts are what the hub knows about this folder; Issues is read with <code>gh</code>.'
}
