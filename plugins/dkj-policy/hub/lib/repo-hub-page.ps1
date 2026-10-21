<#
.SYNOPSIS
    The plugin's own Repo hub page (#3245): what the general pages server answers on '/', '/index.html' and
    '/hub' in every repo that has not opted out with OwnHub. No I/O -- hub/pages/serve-general-pages.ps1 reads
    the state file and hands the values in, so every rule here is tested without a server.

.DESCRIPTION
    INBOUND #3245. The owner decided (October 21, 2026) that the plugin serves the Repo hub in EVERY repo,
    whether or not it states Get-DevPreview: the general pages server is the hub, so the hub and its General
    pages share one origin, and a server the repo states becomes its PRODUCT, one link on the hub. This page
    replaces #3047's placeholder, whose own server and ports (4880-4889) are retired; what of that page
    survived is here: the setup cards, the facts and the repo-name handling.

    THE PAGE STARTS FROM THE HOUSE STYLE: it loads /house-style.css and /house-theme.js, which the general
    server serves from the canonical copy inside dkj-policy's payload (dkj-solutions/assets/house-style/,
    which Get-HouseStyleDir names), in every repo, and its own layer uses only names the house file does not
    define (.ph-*).

    AND IT TAKES THE REPO HUB FORM (#3066, #3097): the blocks and their order laid down in the plugin's
    dkj-solutions/assets/house-style/README.md, "The Repo hub". The repo name is the eyebrow and the h1 is
    "Repo hub", word for word. This hub has no in-flight lists to count, so the tiles and the loading line
    are left out. Under the lead: the Product card where the repo states a server of its own, then the
    General card and, where the repo enables dkj-solutions (-DkjSolutions), the DKJ-Solutions card; the two
    setup cards take the data cards' place only where the repo states no Get-DevPreview at all.

    ONE ORIGIN: the General and DKJ-Solutions cards link their pages by bare path (-SameOrigin), because
    this page is served by the same server, so the visitor keeps one origin and one stored theme choice.

    THE REPO NAME AND THE PRODUCT URL ARE THE ONLY VALUES FROM OUTSIDE. The name is a repo name or a folder
    name, so it is HTML-escaped and cut at 80 characters; the url comes out of the state file, which the
    reader believes only as a plain loopback url, and it is HTML-escaped again here and linked only when it
    still has that shape.

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/dev-preview-sessionstart.tests.ps1 in
    the source repo -- change one, run the other.
#>

. (Join-Path $PSScriptRoot 'general-pages-lib.ps1')
$dkjSolutionsPagesLib = Get-DkjSolutionsPagesLibPath -PluginRoot (Join-Path $PSScriptRoot '..\..')
if (Test-Path -LiteralPath $dkjSolutionsPagesLib -PathType Leaf) { . $dkjSolutionsPagesLib }

function Format-PluginRepoHubHtml {
    <#
        The whole page for the repo named -RepoName. -Folder is the checkout's folder name (the facts card;
        defaults to the repo name). -Mode is what the repo states: 'none' (no Get-DevPreview: the setup cards
        show) or 'product' (a server of its own: the Product card shows). -ProductUrl is that server's url,
        or empty where it is not running (the card says so). -PagesUrl is this server's own base url; it is
        always the general server that serves this page, so the General card links by bare path.
        -DkjSolutions adds the DKJ-Solutions card, for a repo that enables that plugin.
    #>
    param(
        [AllowNull()][AllowEmptyString()][string]$RepoName,
        [AllowNull()][AllowEmptyString()][string]$Folder = '',
        [ValidateSet('none', 'product')][string]$Mode = 'none',
        [AllowEmptyString()][string]$ProductUrl = '',
        [AllowEmptyString()][string]$PagesUrl = '',
        [switch]$DkjSolutions
    )
    $cut = {
        param($v)
        $t = ([string]$v) -replace '[\p{C}]', ' '
        if ($t.Length -gt 80) { $t = $t.Substring(0, 80) }
        if (-not $t.Trim()) { $t = 'this repo' }
        return (ConvertTo-GeneralPageText $t.Trim())
    }
    $n = & $cut $RepoName
    $f = if ($Folder) { & $cut $Folder } else { $n }
    $product = if ($ProductUrl -cmatch '^http://localhost:[0-9]{4,5}(/[A-Za-z0-9._~/%?=&#+-]*)?\z' -and $ProductUrl.Length -le 240) { $ProductUrl } else { '' }
    $e = { param($v) ConvertTo-GeneralPageText $v }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<!doctype html>')
    # With no choice stored it falls back to the default every other dev page uses (#3166). The theme key is the
    # general pages' own: the hub and its pages are one origin now, so a theme picked on one holds on the others.
    [void]$sb.AppendLine('<html lang="en" data-theme-default="lilac" data-width-default="full" data-theme-key="general-pages">')
    [void]$sb.AppendLine('<head>')
    [void]$sb.AppendLine('<meta charset="utf-8">')
    [void]$sb.AppendLine('<meta name="viewport" content="width=device-width, initial-scale=1">')
    [void]$sb.AppendLine('<title>' + $n + ' -- Repo hub</title>')
    [void]$sb.AppendLine('<link rel="stylesheet" href="/house-style.css">')
    [void]$sb.AppendLine('<script src="/house-theme.js"></script>')
    # The repo layer: one name the house file does not define (.ph-code), for the code samples.
    [void]$sb.AppendLine('<style>')
    [void]$sb.AppendLine('.ph-code { margin: var(--spacing-3) 0 0; padding: var(--spacing-3) var(--spacing-4); background: var(--paper-1); border: 1px solid var(--paper-3); border-radius: 8px; overflow-x: auto; font-size: var(--text-xs); line-height: 1.6; }')
    [void]$sb.AppendLine('</style>')
    [void]$sb.AppendLine('</head>')
    [void]$sb.AppendLine('<body>')
    # Block 0, the breadcrumb bar: first in <body> on every dev-server page; on the Repo hub its trail is this one crumb.
    [void]$sb.AppendLine('<div class="breadcrumbs-bar"><div class="container"><nav class="breadcrumbs" aria-label="Breadcrumb"><ol>')
    [void]$sb.AppendLine('<li><span aria-current="page">Repo hub</span></li>')
    [void]$sb.AppendLine('</ol></nav></div></div>')
    # Block 1, the settings button, sits outside <main>.
    [void]$sb.AppendLine('<div id="settings" class="theme-settings--floating"></div>')
    [void]$sb.AppendLine('<main class="page-column">')
    # Blocks 2 to 5: the intro is a <div>, never a <header>, which the house style lays out as a flex row.
    [void]$sb.AppendLine('<div>')
    [void]$sb.AppendLine('<p class="eyebrow">' + $n + '</p>')
    [void]$sb.AppendLine('<h1>Repo hub</h1>')
    $lead = if ($Mode -eq 'product') { 'The way to every page about this repo, and to the dev server it states, its product.' }
            else { 'The way to every page about this repo. It states no dev server of its own yet, so there is no product to link.' }
    [void]$sb.AppendLine('<p class="lead">' + $lead + '</p>')
    [void]$sb.AppendLine('</div>')

    # Block 6's place: the product, the repo's own server, as one link row under an h2 of its own.
    if ($Mode -eq 'product') {
        [void]$sb.AppendLine('<div class="grid-2">')
        [void]$sb.AppendLine('<div class="grid__head"><h2>Product</h2><p class="card__sub">This repo''s own dev server</p></div>')
        [void]$sb.AppendLine('<section class="card grid__full">')
        if ($product) {
            [void]$sb.AppendLine('<nav class="menu-list" aria-label="Product">')
            [void]$sb.AppendLine('<a class="menu-item" href="' + (& $e $product) + '"><span class="menu-item__label">Open the product<span class="menu-item__sub">' + (& $e $product) + ' -- started from the Get-DevPreview this repo states</span></span>' + $script:RepoHubChevron + '</a>')
            [void]$sb.AppendLine('</nav>')
        } else {
            [void]$sb.AppendLine('<p class="msg" role="status">This repo''s own server is not running. The session-start line says why, and it is started again at the next session start.</p>')
        }
        [void]$sb.AppendLine('</section>')
        [void]$sb.AppendLine('</div>')
    }

    # Block 7, Pages: the general pages, and in a DKJ-Solutions repo the DKJ-Solutions ones beside them.
    [void]$sb.Append((Format-GeneralPagesCardHtml -PagesUrl $PagesUrl -InRow $false -SameOrigin))
    if ($DkjSolutions -and (Get-Command Format-DkjSolutionsPagesCardHtml -ErrorAction SilentlyContinue)) {
        [void]$sb.Append((Format-DkjSolutionsPagesCardHtml -PagesUrl $PagesUrl -InRow $false -SameOrigin))
    }

    # Block 10's place, only where the repo states no Get-DevPreview: the two setup cards, under one h2 of their
    # own and each titled with an h3 (#3175).
    if ($Mode -eq 'none') {
        [void]$sb.AppendLine('<div class="grid-2">')
        [void]$sb.AppendLine('<div class="grid__head"><h2>Set up a product</h2><p class="card__sub">Two steps, both in this repo''s own files</p></div>')
        [void]$sb.AppendLine('<section class="card grid__full">')
        [void]$sb.AppendLine('<div class="card__head"><h3 class="card__title">Add a dev server of your own</h3><p class="card__sub">From the next session on, it is the product on this hub</p></div>')
        [void]$sb.AppendLine('<div>')
        [void]$sb.AppendLine('<p>State <code>Get-DevPreview</code> in this repo''s <code>scripts/repo-config.ps1</code>. The hook then starts that server, or reuses the one already running, and hands out its link beside this hub''s.</p>')
        [void]$sb.AppendLine('<pre class="ph-code"><code>function Get-DevPreview {')
        [void]$sb.AppendLine('    @{')
        [void]$sb.AppendLine('        Command = ''npm run dev -- --host 127.0.0.1 --port {port} --strictPort''')
        [void]$sb.AppendLine('        Ports   = 5173..5180')
        [void]$sb.AppendLine('    }')
        [void]$sb.AppendLine('}</code></pre>')
        [void]$sb.AppendLine('<p class="muted">Every field, and the rules for <code>Command</code>, are in the dkj-policy plugin''s <code>hub/README.md</code>, under &quot;The dev-preview hook&quot;. A repo that serves a Repo hub of its own adds <code>OwnHub = $true</code>.</p>')
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

    # Block 11: About this repo, the fixed title, with what the hub knows.
    $devPreview = if ($Mode -ne 'product') { 'none stated yet' } elseif ($product) { & $e $product } else { 'stated, not running' }
    [void]$sb.AppendLine('<div class="grid-2">')
    [void]$sb.AppendLine('<div class="grid__head"><h2>About this repo</h2><p class="card__sub">What the hub knows about this folder</p></div>')
    [void]$sb.AppendLine('<section class="card grid__full">')
    [void]$sb.AppendLine('<dl class="facts">')
    [void]$sb.AppendLine('<div><dt>Folder</dt><dd>' + $f + '</dd></div>')
    [void]$sb.AppendLine('<div><dt>Dev preview</dt><dd>' + $devPreview + '</dd></div>')
    [void]$sb.AppendLine('<div><dt>Stated in</dt><dd>scripts/repo-config.ps1</dd></div>')
    [void]$sb.AppendLine('<div><dt>Hub served by</dt><dd>the dkj-policy plugin, on a port from 4890 to 4899</dd></div>')
    [void]$sb.AppendLine('</dl>')
    [void]$sb.AppendLine('</section>')
    [void]$sb.AppendLine('</div>')

    # Block 12: where the page comes from.
    [void]$sb.AppendLine('<p class="footer-note">Served on 127.0.0.1 only, by the dkj-policy plugin''s <code>hub/pages/serve-general-pages.ps1</code>.</p>')
    [void]$sb.AppendLine('</main>')
    [void]$sb.AppendLine('<script>DKJTheme.settings(document.getElementById("settings"), { label: "Settings", title: "Settings", theme: "Theme", reset: "Reset theme", light: "Light", dark: "Dark", width: "Width", fluid: "Fluid", phone: "Phone", full: "Full" });</script>')
    [void]$sb.AppendLine('</body>')
    [void]$sb.AppendLine('</html>')
    return $sb.ToString()
}
