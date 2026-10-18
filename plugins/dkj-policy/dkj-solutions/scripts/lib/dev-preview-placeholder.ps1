<#
.SYNOPSIS
    The page and the request rules of the placeholder preview: what the dev-preview hook serves in a
    DKJ-Solutions repo that states no Get-DevPreview. No I/O -- scripts/preview/serve-placeholder.ps1 reads
    the sockets and hands the request in, so every rule here is tested without a server.

.DESCRIPTION
    INBOUND #3047. The owner reversed #2967's silent no-op (October 15, 2026): every DKJ-Solutions repo
    opens a dev preview at session start, and a repo with nothing to serve yet gets this page as the floor.
    It names the repo, says that it states no preview yet, and shows how to state one -- the same
    Get-DevPreview seam the plugin README documents.

    THE PAGE STARTS FROM THE HOUSE STYLE: it loads /house-style.css and /house-theme.js, which the server
    serves from the plugin's own vendored copy (assets/house-style/), and its own layer uses only names the
    house file does not define (.ph-*).

    AND IT TAKES THE REPO HUB FORM (#3066, #3097): the blocks and their order laid down in the brand book's
    house-style/README.md, "The Repo hub", at the tag the house-style skill pins. The repo name is the
    eyebrow and the h1 is "Repo hub", word for word. A placeholder has no in-flight lists to
    count, so the tiles and the loading line are left out and its two setup cards take the data cards'
    place.

    THE REPO NAME IS THE ONLY VALUE FROM OUTSIDE, and it is a folder name, so it is HTML-escaped and cut
    at 80 characters before it reaches the page.

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/dev-preview-sessionstart.tests.ps1 in
    the source repo -- change one, run the other.
#>

function ConvertTo-DevPreviewPlaceholderText {
    <# HTML-escapes one value for text or a quoted attribute. #>
    param([AllowNull()][AllowEmptyString()]$Value)
    if ($null -eq $Value) { return '' }
    return ([string]$Value).Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;').Replace("'", '&#39;')
}

function Test-DevPreviewPlaceholderHost {
    <#
        True when the request's Host header names this server on loopback. A page elsewhere that rebinds
        its DNS name to 127.0.0.1 arrives with its own name, so it is refused (DNS rebinding).
    #>
    param([AllowNull()][AllowEmptyString()][string]$HostHeader, [int]$Port)
    if (-not $HostHeader) { return $false }
    $h = $HostHeader.Trim().ToLowerInvariant()
    return ($h -eq "localhost:$Port" -or $h -eq "127.0.0.1:$Port")
}

function Test-DevPreviewPlaceholderCrossSite {
    <# True when the browser marks the request as coming from another site. A missing header is allowed. #>
    param([AllowNull()][AllowEmptyString()][string]$SecFetchSite)
    if (-not $SecFetchSite) { return $false }
    $v = $SecFetchSite.Trim().ToLowerInvariant()
    return ($v -eq 'cross-site' -or $v -eq 'same-site')
}

function Format-DevPreviewPlaceholderHtml {
    <# The whole page for the repo named -RepoName (a folder name). #>
    param([AllowNull()][AllowEmptyString()][string]$RepoName)
    $name = ([string]$RepoName) -replace '[\p{C}]', ' '
    if ($name.Length -gt 80) { $name = $name.Substring(0, 80) }
    if (-not $name.Trim()) { $name = 'this repo' }
    $n = ConvertTo-DevPreviewPlaceholderText $name.Trim()

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<!doctype html>')
    [void]$sb.AppendLine('<html lang="en" data-theme-light="teal" data-theme-dark="sky" data-theme-key="dev-preview-placeholder">')
    [void]$sb.AppendLine('<head>')
    [void]$sb.AppendLine('<meta charset="utf-8">')
    [void]$sb.AppendLine('<meta name="viewport" content="width=device-width, initial-scale=1">')
    [void]$sb.AppendLine('<title>' + $n + ' -- Repo hub</title>')
    [void]$sb.AppendLine('<link rel="stylesheet" href="/house-style.css">')
    [void]$sb.AppendLine('<script src="/house-theme.js"></script>')
    # The repo layer: one name the house file does not define (.ph-code), for the code samples.
    [void]$sb.AppendLine('<style>')
    [void]$sb.AppendLine('.ph-code { margin: var(--spacing-3) 0 0; padding: var(--spacing-3) var(--spacing-4); background: var(--primary-1); border: 1px solid var(--primary-3); border-radius: 8px; overflow-x: auto; font-size: var(--text-xs); line-height: 1.6; }')
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
    [void]$sb.AppendLine('<p class="lead">This repo states no dev preview of its own yet, so the dev-preview hook serves this placeholder in its place.</p>')
    [void]$sb.AppendLine('</div>')

    # Block 10's place: the two setup cards.
    [void]$sb.AppendLine('<section class="card">')
    [void]$sb.AppendLine('<div class="card__head"><h2 class="card__title">Add a preview of your own</h2><p class="card__sub">From the next session on, it replaces this page</p></div>')
    [void]$sb.AppendLine('<div>')
    [void]$sb.AppendLine('<p>State <code>Get-DevPreview</code> in this repo''s <code>scripts/repo-config.ps1</code>. The hook then starts that server, or reuses the one already running, and hands out its link instead of this page. Its index is this repo''s own Repo hub, in the same form as this page.</p>')
    [void]$sb.AppendLine('<pre class="ph-code"><code>function Get-DevPreview {')
    [void]$sb.AppendLine('    @{')
    [void]$sb.AppendLine('        Command = ''npm run dev -- --host 127.0.0.1 --port {port} --strictPort''')
    [void]$sb.AppendLine('        Ports   = 5173..5180')
    [void]$sb.AppendLine('    }')
    [void]$sb.AppendLine('}</code></pre>')
    [void]$sb.AppendLine('<p class="muted">Every field, and the rules for <code>Command</code>, are in the dkj-solutions plugin README, under &quot;The dev-preview hook&quot;.</p>')
    [void]$sb.AppendLine('</div>')
    [void]$sb.AppendLine('</section>')

    [void]$sb.AppendLine('<section class="card">')
    [void]$sb.AppendLine('<div class="card__head"><h2 class="card__title">Open it in VS Code</h2><p class="card__sub">In the Simple Browser rather than the system browser</p></div>')
    [void]$sb.AppendLine('<div>')
    [void]$sb.AppendLine('<p>Route the preview''s port in this repo''s <code>.vscode/settings.json</code>:</p>')
    [void]$sb.AppendLine('<pre class="ph-code"><code>"workbench.externalUriOpeners": {')
    [void]$sb.AppendLine('    "localhost:4880": "simpleBrowser.open"')
    [void]$sb.AppendLine('}</code></pre>')
    [void]$sb.AppendLine('<p class="muted">The placeholder takes the first free port from 4880 to 4889, so a repo opened beside others may get a later one; the session-start line names the port it got.</p>')
    [void]$sb.AppendLine('</div>')
    [void]$sb.AppendLine('</section>')

    # Block 11: About this repo, the fixed title, with what the placeholder knows.
    [void]$sb.AppendLine('<section class="card">')
    [void]$sb.AppendLine('<div class="card__head"><h2 class="card__title">About this repo</h2></div>')
    [void]$sb.AppendLine('<dl class="facts">')
    [void]$sb.AppendLine('<div><dt>Folder</dt><dd>' + $n + '</dd></div>')
    [void]$sb.AppendLine('<div><dt>Dev preview</dt><dd>none stated yet</dd></div>')
    [void]$sb.AppendLine('<div><dt>Stated in</dt><dd>scripts/repo-config.ps1</dd></div>')
    [void]$sb.AppendLine('<div><dt>Placeholder ports</dt><dd>4880 to 4889</dd></div>')
    [void]$sb.AppendLine('</dl>')
    [void]$sb.AppendLine('</section>')

    # Block 12: where the page comes from.
    [void]$sb.AppendLine('<p class="footer-note">Served on 127.0.0.1 only, by the dkj-solutions plugin''s <code>scripts/preview/serve-placeholder.ps1</code>.</p>')
    [void]$sb.AppendLine('</main>')
    [void]$sb.AppendLine('<script>DKJTheme.settings(document.getElementById("settings"), { label: "Settings", title: "Settings", theme: "Theme", reset: "Reset theme", light: "Light", dark: "Dark", width: "Width", fluid: "Fluid", phone: "Phone", full: "Full" });</script>')
    [void]$sb.AppendLine('</body>')
    [void]$sb.AppendLine('</html>')
    return $sb.ToString()
}
