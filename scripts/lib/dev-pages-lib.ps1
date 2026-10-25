<#
.SYNOPSIS
    The hub of this repo's dev server -- the home page on '/', which holds what was About this repo (#3270;
    '/about' sends there since October 22, 2026) -- and its own pages: the Connectors and Specialists pages (the
    product's since October 22, 2026: its dev server links and relays them, so the hub lists neither) and the DKJ
    repos page, the product's too. The Test gate (#3097), the Stopwatch (#3315) and the Logbook (#3364) began here
    and are the dkj-policy plugin's since #3470, so every repo's hub has them: this hub links them with the other
    general pages (Get-GeneralPages) and still serves them itself, from the plugin's libs in this tree, the Test gate
    with this checkout's suite selection, which only this repo has. No I/O -- the server
    (scripts/dashboard/serve-connector-dashboard.ps1) measures and reads, and hands the results in, so every rule here is tested without a server.

.DESCRIPTION
    THE HUB IS ONE PAGE (owner, October 22, 2026), the house form since #3289, which this hub took first: before
    it the house hub was a home page linking an About this repo page (#3270). Its grid of card links with a
    separate Repository page, which this hub also took first, is the house form too since #3383 (October 24, 2026). Here the site header names the repo and
    holds the settings button, the bar has its one crumb, Home, and the page goes straight to what About held: the
    Pages block (the 'This repo' card linking the repo's own pages, then the General card), the facts and a
    footer note, so it fits on one screen. This repo is no
    product and keeps no in-flight lists, so it has no Products section and no lists. The pages it links are Get-RepoHubPages, the
    ones only this repo has. The GENERAL pages -- Artifacts, Issues, Release notes and SessionStart, which
    every repo has -- are no longer built here (#3119), and the Test gate, Stopwatch and Logbook are built from the
    plugin's libs (see above): the dkj-policy plugin ships them (since #3198) as
    a server of its own, and the hub links each of its pages as a card of its own, through the plugin's
    shared Format-HubCardLinkHtml, after this repo's own, so a page that is this repo's own is never read as
    one every repo has. This file dot-sources the plugin's general-pages-lib.ps1 for the page shell, the number formats and
    the tile and bar helpers this hub's own pages share with those pages, so nothing is written twice.

    NO BRAND BOOK HERE. The brand book is this repo's product: the brandbook/ app's Vite dev server, which
    the dev-preview hook starts beside this hub on a port of its own (#3283) and which shows the tree as it
    is edited. The hub served a build of the same app at /brandbook and linked it from its home page, so
    one brand book was visible on two ports; the owner put it on the product port alone (October 22, 2026).
    So the hub does not serve it, and links it only as the product: its first card is the product port,
    read from the hook's state file, as on the plugin's hub every consumer runs (#3468). Every other
    DKJ-Solutions repo still gets the brand book from the dkj-solutions plugin, through the general server.

    ONE SHELL FOR EVERY PAGE BELOW THE HUB. Each page opens with the house breadcrumb bar, its trail
    starting at the hub on '/' and ending at the page itself, unlinked ("Every page: the breadcrumb
    bar"); then the settings button, an intro (eyebrow, h1, lead), the page's own blocks and a footer
    note naming where the data comes from. Format-DevPageHtml is this repo's call of the plugin's
    Format-GeneralPageHtml.


    THE DKJ REPOS PAGE (#3231) is built here and is the product's, like Connectors and Specialists: the product's
    root page links it and its dev server relays it (October 22, 2026). Every DKJ-Solutions repo on GitHub, its
    checkout beside this repo, and the command that opens Claude Code there. Find-DkjCheckouts is the one function in this file that reads the disk.

    EVERY VALUE THAT REACHES THE PAGE IS ESCAPED, through connector-dashboard-lib's ConvertTo-DashboardText
    here and the plugin lib's own escape there (the two are the same five replacements).

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/dev-pages.tests.ps1.
#>

. (Join-Path $PSScriptRoot 'connector-dashboard-lib.ps1')
# The plugin's lib: this repo is its source, so it reads it from its own tree -- dkj-policy's page shell and
# General card (#3198).
. (Join-Path $PSScriptRoot '..\..\plugins\dkj-policy\hub\lib\general-pages-lib.ps1')
# And its believe-rule for a state-file url (Test-RepoHubLocalUrl), for the Product card (#3468). No I/O.
. (Join-Path $PSScriptRoot '..\..\plugins\dkj-policy\hub\lib\dev-preview-rules.ps1')
# The Test gate page, every repo's since #3470: the plugin's lib, which this repo's hub serves with its selection.
. (Join-Path $PSScriptRoot '..\..\plugins\dkj-policy\hub\lib\test-gate-lib.ps1')

# The general pages this repo's hub answers itself rather than relays (#3470): every repo's since they moved into the
# dkj-policy plugin, built here from its libs in this tree.
$script:RepoHubOwnGeneralRoutes = @('/test-gate', '/stopwatch', '/logbook')

function Format-DevPageHtml {
    <#
        The whole page around -Body, for this repo's own pages (Specialists, DKJ repos): the plugin's page shell with
        this repo's site header and title, its theme key (the general pages' own, so a theme picked on one page
        holds on every page this server serves, the general pages it relays included, #3168) and the Repo
        hub crumb on '/'. -BrandTag is the word after the name in the header: 'hub' for the hub's own
        pages, 'product' for the pages the product port relays (Specialists, DKJ repos), so it names the port
        they are seen on.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Lead,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Body,
        [AllowEmptyString()][string]$Style = '',
        [AllowEmptyString()][string]$FooterNote = '',
        [string]$ThemeKey = 'general-pages',
        [ValidateSet('hub', 'product')][string]$BrandTag = 'hub',
        [switch]$Bare,
        [AllowEmptyCollection()][object[]]$ParentCrumbs = @()
    )
    # -Bare: no h1 or lead above the body, the general banner still on top (Format-GeneralPageHtml's own switch, #3356), for a page that opens on its content.
    return Format-GeneralPageHtml -Title $Title -Lead $Lead -Body $Body -Style $Style -FooterNote $FooterNote -ThemeKey $ThemeKey `
        -Brand 'dkj-claude-plugins' -BrandTag $BrandTag -SiteName 'dkj-claude-plugins' -HubHref '/' -Bare:$Bare -ParentCrumbs $ParentCrumbs
}

function Get-RepoHubPages {
    <#
        The pages the hub links in its "This repo" card, in the order it lists them: each a route on this
        server, its label the page's own name as its breadcrumb reads it, and one line on what it shows. The
        general pages are the plugin's (Get-GeneralPages), on a server of their own. Connectors and Specialists
        are built here and are the product's pages (October 22, 2026): its root page links them, so they are
        not listed here.
    #>
    @(
        @{ Href = '/repository';  Label = 'Repository';  Sub = 'The GitHub repo: its facts, its open issues and its pull requests'; Icon = 'repository' }
    )
}

function Format-RepoGitHubPageHtml {
    <#
        The Repository page on '/repository' (owner, October 22, 2026): everything about the GitHub repo. Its facts, as
        a .facts--row (label over value, no card, since the cards on these pages are links), then its pages on GitHub
        and the Issues page, a card each. -SourceCommit is the short sha the server reads, or empty;
        -GeneralPagesUrl is the general pages server's base url when it answers, or empty: Issues is that server's
        page, relayed by bare path (#3168), so without one a card says it is not running.
    #>
    param([AllowEmptyString()][string]$SourceCommit = '', [AllowEmptyString()][string]$GeneralPagesUrl = '')
    $e = { param($v) ConvertTo-DashboardText $v }
    $gh = 'https://github.com/DKJ-Solutions/dkj-claude-plugins'
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<dl class="facts facts--row">')
    [void]$sb.AppendLine('<div><dt>GitHub</dt><dd><a href="' + $gh + '">DKJ-Solutions/dkj-claude-plugins</a></dd></div>')
    [void]$sb.AppendLine('<div><dt>Marketplace</dt><dd>dkj-claude-plugins</dd></div>')
    [void]$sb.AppendLine('<div><dt>Trunk</dt><dd>main</dd></div>')
    [void]$sb.AppendLine('<div><dt>Visibility</dt><dd>public</dd></div>')
    [void]$sb.AppendLine('<div><dt>Required check</dt><dd>lint-en-tests</dd></div>')
    if ($SourceCommit) { [void]$sb.AppendLine('<div><dt>Source at</dt><dd><code>' + (& $e $SourceCommit) + '</code></dd></div>') }
    [void]$sb.AppendLine('</dl>')
    # Each page a card of its own: the plugin's Format-HubCardLinkHtml, the house hub card (#3383).
    $card = { param($href, $label, $sub, $icon) Format-HubCardLinkHtml -Href $href -Label $label -Sub $sub -Icon $icon }
    [void]$sb.AppendLine('<div class="grid-3">')
    if ($GeneralPagesUrl -cmatch '^http://localhost:[0-9]{4,5}/?\z') {
        [void]$sb.AppendLine((& $card '/issues' 'Issues' 'The open issues, grouped by what they wait on' 'issues'))
    } else {
        [void]$sb.AppendLine('<section class="card"><p class="msg" role="status">Issues is a general page, and the general pages server is not running. It starts at the next session start.</p></section>')
    }
    [void]$sb.AppendLine((& $card "$gh/pulls" 'Pull requests' 'On GitHub' 'pull-request'))
    [void]$sb.AppendLine((& $card "$gh/actions" 'Actions' 'The CI runs, on GitHub' 'actions'))
    [void]$sb.AppendLine('</div>')
    return Format-DevPageHtml -Title 'Repository' -Body $sb.ToString() `
        -Lead 'The GitHub repo this hub serves: its facts, its open issues and its pull requests.' `
        -FooterNote 'The facts are this repo''s own; Issues is the dkj-policy general pages server''s page, relayed here.'
}
function Format-RepoHubHtml {
    <#
        The repo's home page on '/' (#3270): under the site header and the bar, everything that was About this
        repo (Format-RepoAboutBodyHtml: the Pages block and the facts) and its footer note; '/about' now sends
        here (owner, October 22, 2026). The brand book, Connectors, Specialists and DKJ repos are the product
        port's, so they are not here -- but the product port itself is, as the first card (#3468). The parameters
        are Format-RepoAboutBodyHtml's.
    #>
    param(
        [AllowEmptyCollection()][object[]]$Pages = @(Get-RepoHubPages),
        [AllowEmptyString()][string]$SourceCommit = '',
        [AllowEmptyString()][string]$GeneralPagesUrl = '',
        [AllowEmptyString()][string]$ProductUrl = ''
    )
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<!doctype html>')
    [void]$sb.AppendLine('<html lang="en" data-theme-default="lilac" data-width-default="full" data-theme-key="general-pages">')
    [void]$sb.AppendLine('<head>')
    [void]$sb.AppendLine('<meta charset="utf-8">')
    [void]$sb.AppendLine('<meta name="viewport" content="width=device-width, initial-scale=1">')
    [void]$sb.AppendLine('<title>dkj-claude-plugins -- Home</title>')
    [void]$sb.AppendLine('<link rel="stylesheet" href="/house-style.css">')
    [void]$sb.AppendLine('<script src="/house-theme.js"></script>')
    # No page layer of its own: the heading above a group of cards (.grid__head), a card that takes the whole
    # row (.grid__full) and a card's margin inside a .grid-2 are the house style's own since #3133.
    [void]$sb.AppendLine('</head>')
    [void]$sb.AppendLine('<body>')
    [void]$sb.Append((Format-RepoHomeHeadHtml -RepoName 'dkj-claude-plugins' -Brand 'dkj-claude-plugins' -BrandTag 'hub' -Lead 'The source of the Claude Specialists plugins: the marketplace, its agent definitions, manuals and skills, and the scripts and gates that ship them.'))
    # Everything that was About this repo, on the home page itself (owner, October 22, 2026).
    [void]$sb.Append((Format-RepoAboutBodyHtml -Pages $Pages -SourceCommit $SourceCommit -GeneralPagesUrl $GeneralPagesUrl -ProductUrl $ProductUrl))
    [void]$sb.AppendLine('<p class="footer-note">Each page names its own source. Served on 127.0.0.1 only, by <code>scripts/dashboard/serve-connector-dashboard.ps1</code>.</p>')
    [void]$sb.AppendLine('</main>')
    [void]$sb.AppendLine('<script>DKJTheme.settings(document.getElementById("settings"), { label: "Settings", title: "Settings", theme: "Theme", reset: "Reset theme", light: "Light", dark: "Dark", width: "Width", fluid: "Fluid", phone: "Phone", full: "Full" });</script>')
    [void]$sb.AppendLine('</body>')
    [void]$sb.AppendLine('</html>')
    return $sb.ToString()
}

function Format-RepoAboutBodyHtml {
    <#
        What was the About this repo page (#3270) and is the home page's body since October 22, 2026: the Pages
        block: every page a card of its own, this repo's then the general ones but Issues, with no heading above
        them. The facts and Issues are the Repository page's (Format-RepoGitHubPageHtml). -Pages is
        Get-RepoHubPages' shape; -SourceCommit is unused here and kept for the callers; -GeneralPagesUrl is the general pages server's base url when it answers, or
        empty (one card then says it is not running). -ProductUrl is the product port's url from the state file
        the hook writes (the brand book's dev server, #3468), believed only as a plain loopback url
        (Test-RepoHubLocalUrl, the plugin hub's own rule), so the first card links it as the plugin's hub does;
        empty, that card says the server is not running, since this repo always states one.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Pages,
        [AllowEmptyString()][string]$SourceCommit = '',
        [AllowEmptyString()][string]$GeneralPagesUrl = '',
        [AllowEmptyString()][string]$ProductUrl = ''
    )
    $sb = New-Object System.Text.StringBuilder
    # Pages: every page a card of its own, three to a row (.grid-3), with no heading above them (owner, October 22,
    # 2026; the house hub form since #3383): this repo's own first, then the general ones. A card holds the page's one
    # menu-item row (the plugin's Format-HubCardLinkHtml). The general pages are linked by bare path, since this hub
    # relays them (#3168), and only when a plain loopback server answers; otherwise one card says the server is not
    # running.
    $pageCard = { param($p) Format-HubCardLinkHtml -Href $p.Href -Label $p.Label -Sub $p.Sub -Icon $p.Icon }
    $general = $GeneralPagesUrl -cmatch '^http://localhost:[0-9]{4,5}/?\z'
    [void]$sb.AppendLine('<div class="grid-3">')
    # The product first, as on the plugin's hub (#3468): the card and its not-running line are that hub's.
    if (Test-RepoHubLocalUrl $ProductUrl) {
        [void]$sb.AppendLine((Format-HubCardLinkHtml -Href $ProductUrl -Label 'Product' -Sub ($ProductUrl + ' -- the server this repo states in Get-DevPreview') -Icon 'product'))
    } else {
        [void]$sb.AppendLine('<section class="card"><p class="msg" role="status">This repo''s own server is not running. The session-start line says why, and it is started again at the next session start.</p></section>')
    }
    foreach ($p in @($Pages)) { [void]$sb.AppendLine((& $pageCard $p)) }
    if ($general) {
        # Issues is the Repository page's (owner, October 22, 2026), so the home page links the other three.
        foreach ($p in @(Get-GeneralPages | Where-Object { $_.Href -ne '/issues' })) { [void]$sb.AppendLine((& $pageCard $p)) }
    } else {
        # The general pages this hub serves itself (#3470) stay linked: only the relayed ones need that server.
        foreach ($p in @(Get-GeneralPages | Where-Object { $script:RepoHubOwnGeneralRoutes -contains $_.Href })) { [void]$sb.AppendLine((& $pageCard $p)) }
        [void]$sb.AppendLine('<section class="card grid__full"><p class="msg" role="status">The general pages server is not running. It starts at the next session start, and its pages are linked here from then on.</p></section>')
    }
    [void]$sb.AppendLine('</div>')
    return $sb.ToString()
}


function ConvertTo-SpecialistRow {
    <#
        One specialist from its definition file. -Text is the file as read (a subagent definition or a
        persona); -ManualBytes and -LensBytes are the sizes of its manual and this repo's lens, $null where
        there is none. Returns @{ Id; Number; Name; Emoji; Title; Plugin; Form; Enabled; ListingBytes;
        DefinitionBytes; ManualBytes; LensBytes; TotalBytes; AlwaysOn }.

        WHAT EACH PART IS. The listing is a subagent's frontmatter description, which Claude Code puts in
        every session that enables its plugin; a persona has none. The definition is the file without its
        frontmatter: a subagent's system prompt when it is spawned, or a persona's body when it is read --
        and the orchestrator's persona (01-01) is imported on every turn, which is what AlwaysOn says. The
        manual and the lens are read on demand.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Plugin,
        [Parameter(Mandatory = $true)][ValidateSet('subagent', 'persona')][string]$Form,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
        [AllowNull()]$ManualBytes,
        [AllowNull()]$LensBytes,
        [bool]$Enabled = $false
    )
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $lines = @($Text.Replace("`r`n", "`n").Split("`n"))
    $front = @(); $bodyFrom = 0
    if ($lines.Count -gt 1 -and $lines[0].TrimStart([char]0xFEFF) -eq '---') {
        for ($j = 1; $j -lt $lines.Count; $j++) {
            # An empty block ($j = 1) would make 1..0 a descending range, so it is guarded.
            if ($lines[$j] -eq '---') { if ($j -gt 1) { $front = @($lines[1..($j - 1)]) }; $bodyFrom = $j + 1; break }
        }
    }
    $body = if ($bodyFrom -lt $lines.Count) { ($lines[$bodyFrom..($lines.Count - 1)]) -join "`n" } else { '' }

    # The description: an inline value, or a folded/literal block of the indented lines below it.
    $desc = ''
    for ($k = 0; $k -lt $front.Count; $k++) {
        if ($front[$k] -match '^description:\s*(.*)$') {
            $v = $Matches[1].Trim()
            if ($v -match '^[>|][-+]?$') {
                $parts = @()
                for ($m = $k + 1; $m -lt $front.Count -and $front[$m] -match '^\s+\S|^\s*$'; $m++) { $parts += $front[$m].Trim() }
                $desc = ($parts | Where-Object { $_ }) -join ' '
            } else { $desc = $v.Trim('"', "'") }
            break
        }
    }

    # The name, emoji and title: a subagent says "You are **Name E**, the Title."; a persona's h1 is
    # "# Name E -- the Title (*...*)", with an em dash.
    $who = ''; $title = ''
    if ($Form -eq 'subagent' -and $body -match '(?m)^You are \*\*(.+?)\*\*,\s+(?:the\s+)?([^.]+?)\.') {
        $who = $Matches[1]; $title = $Matches[2]
    } elseif ($body -match ('(?m)^#\s+(.+?)\s+' + [char]0x2014 + '\s+(?:the\s+)?(.+?)\s*$')) {
        $who = $Matches[1]; $title = $Matches[2] -replace '\s*\(\*[^)]*\*\)\s*$', ''
    }
    $title = ($title -replace '\s+', ' ').Trim()
    $name = ($who -split '\s+', 2)[0]
    $emoji = if ($who -match '^\S+\s+(.+)$') { $Matches[1].Trim() } else { '' }
    if (-not $name) { $name = $Id }

    $listing = if ($desc) { [int64]$utf8.GetByteCount($desc) } else { [int64]0 }
    $definition = [int64]$utf8.GetByteCount($body)
    $total = $listing + $definition + $(if ($null -ne $ManualBytes) { [int64]$ManualBytes } else { 0 }) + $(if ($null -ne $LensBytes) { [int64]$LensBytes } else { 0 })
    return @{
        Id = $Id; Number = ($Id -split '-')[-1]; Name = $name; Emoji = $emoji; Title = $title
        Plugin = $Plugin; Form = $Form; Enabled = $Enabled
        ListingBytes = $listing; DefinitionBytes = $definition
        ManualBytes = $(if ($null -ne $ManualBytes) { [int64]$ManualBytes } else { $null })
        LensBytes = $(if ($null -ne $LensBytes) { [int64]$LensBytes } else { $null })
        TotalBytes = $total; AlwaysOn = ($Id -eq '01-01')
    }
}

function Format-SpecialistsPageHtml {
    <#
        The Specialists page. -Rows is ConvertTo-SpecialistRow's shape; -CharsPerToken the calibrated
        factor (measure-context-lib's Get-CalibratedCharsPerToken). The bytes are measured, the tokens an
        estimate at that factor, and the page says which is which.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Rows,
        [Parameter(Mandatory = $true)][double]$CharsPerToken,
        [AllowEmptyString()][string]$ReadError = ''
    )
    $e = { param($v) ConvertTo-DashboardText $v }
    $inv = [Globalization.CultureInfo]::InvariantCulture
    $tok = { param($b) if ($null -eq $b) { '--' } elseif ([int64]$b -eq 0) { '--' } else { '~' + (Format-DevNumber ([Math]::Round([double]$b / $CharsPerToken))) } }
    $rows = @($Rows | Where-Object { $_ } | Sort-Object @{ Expression = { [int64]$_.TotalBytes }; Descending = $true }, @{ Expression = { $_.Id } })
    $enabled = @($rows | Where-Object { $_.Enabled })
    # Summed by hand: 5.1's Measure-Object -Property does not read a hashtable's keys.
    $listingHere = [int64]0
    foreach ($r in $enabled) { $listingHere += [int64]$r.ListingBytes }
    $max = if ($rows.Count) { [double]$rows[0].TotalBytes } else { 0 }

    $body = New-Object System.Text.StringBuilder
    [void]$body.Append((Format-DevTiles @(
        @{ L = 'Specialists'; V = $rows.Count },
        @{ L = 'Enabled here'; V = $enabled.Count },
        @{ L = 'Listing, every session here'; V = (& $tok $listingHere) },
        @{ L = 'Largest full read'; V = $(if ($rows.Count) { $rows[0].Name + ' ' + (& $tok $rows[0].TotalBytes) } else { '--' }) })))
    if ($ReadError) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">The specialists could not all be read: ' + (& $e $ReadError) + '.</p>')
    }
    [void]$body.AppendLine('<div class="grid-2" id="specialists">')
    [void]$body.AppendLine('<div class="grid__head"><h2>Context per specialist</h2><p class="card__sub">Estimated tokens, largest full read first. The bar is the full read against the largest one</p></div>')
    [void]$body.AppendLine('<section class="card grid__full">')
    if ($rows.Count) {
        [void]$body.AppendLine('<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">Specialist</th><th class="dp-left">Plugin</th><th>Listing</th><th>Definition</th><th>Manual</th><th>Lens</th><th>Full read</th><th class="dp-left">Against the largest</th></tr></thead><tbody>')
        foreach ($r in $rows) {
            # Muted text, not .badge: the house badge is an 18px circle for one character, and a word in it
            # spills over the text beside it.
            $badges = '<span class="note">&middot; ' + (& $e $r.Form) + $(if ($r.AlwaysOn) { ' &middot; always-on' } else { '' }) + '</span>'
            $plugin = (& $e ($r.Plugin -replace '^dkj-subagents-', '')) + $(if ($r.Enabled) { '' } else { ' <span class="note">(off here)</span>' })
            $w = $(if ($max -gt 0) { [Math]::Min(100.0, 100.0 * [double]$r.TotalBytes / $max) } else { 0.0 }).ToString('0.##', $inv)
            $label = (& $e $r.Name) + $(if ($r.Emoji) { ' ' + (& $e $r.Emoji) } else { '' })
            # One line per specialist: the title follows the name inline and the badges sit with the plugin,
            # where a block-level title and badge row gave every specialist three lines.
            [void]$body.AppendLine('<tr><td class="dp-left"><strong>' + $label + '</strong> <span class="note">#' + (& $e $r.Number) +
                $(if ($r.Title) { ' &middot; ' + (& $e $r.Title) } else { '' }) + '</span></td>' +
                '<td class="dp-left">' + $plugin + ' ' + $badges + '</td>' +
                '<td class="num" title="' + (Format-DevNumber $r.ListingBytes) + ' B">' + (& $tok $r.ListingBytes) + '</td>' +
                '<td class="num" title="' + (Format-DevNumber $r.DefinitionBytes) + ' B">' + (& $tok $r.DefinitionBytes) + '</td>' +
                '<td class="num" title="' + (Format-DevNumber $r.ManualBytes) + ' B">' + (& $tok $r.ManualBytes) + '</td>' +
                '<td class="num" title="' + (Format-DevNumber $r.LensBytes) + ' B">' + (& $tok $r.LensBytes) + '</td>' +
                '<td class="num"><strong>' + (& $tok $r.TotalBytes) + '</strong></td>' +
                '<td class="dp-left"><span class="dp-bar" aria-hidden="true"><span style="width: ' + $w + '%"></span></span></td></tr>')
        }
        [void]$body.AppendLine('</tbody></table></div>')
    } else {
        [void]$body.AppendLine('<p class="note">No specialist was found.</p>')
    }
    [void]$body.AppendLine('</section>')
    [void]$body.AppendLine('</div>')
    [void]$body.AppendLine('<div class="grid-2" id="when">')
    [void]$body.AppendLine('<div class="grid__head"><h2>When each part loads</h2></div>')
    [void]$body.AppendLine('<section class="card grid__full">')
    [void]$body.AppendLine('<dl class="facts">')
    [void]$body.AppendLine('<div><dt>Listing</dt><dd>A subagent''s description. Every session of a repo that enables its plugin carries it, whether the specialist is called or not. A persona has none.</dd></div>')
    [void]$body.AppendLine('<div><dt>Definition</dt><dd>The file without its frontmatter: a subagent''s system prompt each time it is spawned, or a persona''s body when it is read. The orchestrator''s persona is imported on every turn.</dd></div>')
    [void]$body.AppendLine('<div><dt>Manual</dt><dd>The portable playbook, read on demand.</dd></div>')
    [void]$body.AppendLine('<div><dt>Lens</dt><dd>This repo''s own lens, read on demand. A plugin not enabled here has none.</dd></div>')
    [void]$body.AppendLine('<div><dt>Full read</dt><dd>All four together: what a specialist costs when everything about it is in context.</dd></div>')
    [void]$body.AppendLine('</dl>')
    [void]$body.AppendLine('</section>')
    [void]$body.AppendLine('</div>')
    $factor = $CharsPerToken.ToString('0.00', $inv)
    return Format-DevPageHtml -Title 'Specialists' -BrandTag 'product' -Style $script:DevBarStyle -Body $body.ToString() `
        -Lead 'Every specialist the dkj-subagents plugins ship, and how much context each one brings along: what every session pays for it, what it costs when it is called, and what its manual and lens add.' `
        -FooterNote ('Read from this checkout''s <code>plugins/dkj-subagents/</code> and <code>.claude/specialists/lenses/</code> on every request, so it is the tree, not the installed release. Bytes are measured (hover a cell); tokens are an estimate at ' + $factor + ' characters per token, the factor in <code>scripts/lib/measure-context-lib.ps1</code>.')
}

function Find-DkjCheckouts {
    <#
        Every checkout of an -Owner repo directly under -ParentDir (#3231): a folder whose .git is a DIRECTORY
        and whose origin is github.com/<Owner>/<name>. A worktree's .git is a file, so a lane of a repo never
        stands in for its checkout. Returns @{ Repo; Path; Branch; Dirty } per checkout; Branch is '' where git
        does not answer, Dirty the count of uncommitted paths. THIS FUNCTION READS THE DISK AND RUNS GIT, the one
        that does in this file, because the server and repo-session.ps1 must find a checkout the same way.
    #>
    param([Parameter(Mandatory = $true)][string]$ParentDir, [string]$Owner = 'DKJ-Solutions')
    $git = {
        param([string]$Path, [string[]]$GitArgs)
        # 'Continue' and the catch: under 'Stop', Windows PowerShell 5.1 turns a native command's stderr into a
        # terminating error even with 2>$null.
        $ErrorActionPreference = 'Continue'
        # The folders are found by a scan, not named by anybody, so git reads nothing from them that could run
        # code (core.fsmonitor) and writes nothing (--no-optional-locks: status would refresh the index).
        try { $out = & git --no-optional-locks -c core.fsmonitor=false -C $Path @GitArgs 2>$null } catch { return $null }
        if ($LASTEXITCODE -ne 0) { return $null }
        return , @($out)
    }
    $found = @()
    foreach ($d in @(Get-ChildItem -LiteralPath $ParentDir -Directory -ErrorAction SilentlyContinue | Sort-Object Name)) {
        if (-not (Test-Path -LiteralPath (Join-Path $d.FullName '.git') -PathType Container)) { continue }
        $url = & $git $d.FullName @('remote', 'get-url', 'origin')
        if (-not $url) { continue }
        $repo = ConvertFrom-GitRemoteUrl ([string]$url[0])
        if (-not $repo -or ($repo -split '/')[0] -ne $Owner) { continue }
        $branch = & $git $d.FullName @('rev-parse', '--abbrev-ref', 'HEAD')
        $status = & $git $d.FullName @('status', '--porcelain')
        $found += @{ Repo = $repo; Path = $d.FullName; Branch = $(if ($branch) { [string]$branch[0] } else { '' }); Dirty = @($status | Where-Object { $_ }).Count }
    }
    return $found
}

function Get-DkjRepoQuery {
    <#
        The one GraphQL query the DKJ repos page asks: every repo of the organisation named by the variable
        $owner (gh api graphql -f owner=...), newest push first, with its open issue and pull request counts.
        The name goes as a variable, not inline: the query then holds no double quote, which Windows PowerShell
        5.1 would split on its way to gh.
    #>
    return 'query($owner: String!) { organization(login: $owner) { repositories(first: 100, orderBy: {field: PUSHED_AT, direction: DESC}) { nodes { name nameWithOwner url description visibility isArchived pushedAt issues(states: OPEN) { totalCount } pullRequests(states: OPEN) { totalCount } } } } }'
}

function ConvertFrom-DkjRepoQuery {
    <#
        Get-DkjRepoQuery's answer, as text, into @{ Repos; Archived; Error }: Repos the live repos in the order
        GitHub gave them, each @{ Repo; Name; Url; Description; Visibility; PushedAt; Issues; Pulls }; Archived
        the 'owner/name' of each one left out. An answer that is not that shape is an Error, never an empty organisation.
    #>
    param([AllowNull()][AllowEmptyString()][string]$Json)
    $none = @{ Repos = @(); Archived = @(); Error = '' }
    if (-not $Json) { $none.Error = 'gh gave no answer'; return $none }
    try { $doc = $Json | ConvertFrom-Json } catch { $none.Error = 'the answer is not JSON'; return $none }
    if ($doc.errors) { $none.Error = 'GitHub answered with an error: ' + ([string]@($doc.errors)[0].message); return $none }
    $nodes = $doc.data.organization.repositories.nodes
    if ($null -eq $nodes) { $none.Error = 'the answer holds no repository list'; return $none }
    $repos = @(); $archived = @()
    foreach ($n in @($nodes)) {
        if (-not $n) { continue }
        if ($n.isArchived) { $archived += [string]$n.nameWithOwner; continue }
        $repos += @{
            Repo = [string]$n.nameWithOwner; Name = [string]$n.name; Url = [string]$n.url; Description = [string]$n.description
            Visibility = ([string]$n.visibility).ToLowerInvariant(); PushedAt = [string]$n.pushedAt
            Issues = [int]$n.issues.totalCount; Pulls = [int]$n.pullRequests.totalCount
        }
    }
    return @{ Repos = $repos; Archived = $archived; Error = '' }
}

function Get-CopyButtonScript {
    <#
        The script behind every [data-copy] button. The clipboard API first; then execCommand on a hidden
        textarea, because VS Code's Simple Browser serves the page in an iframe without clipboard-write, where
        the API is refused (the owner's own browser, #3231); and where both fail, the first <code> beside the
        button is selected for Ctrl+C.
    #>
    return '<script>(function () {' + "`n" +
        'function label(b, t) { b.textContent = t; setTimeout(function () { b.textContent = "Copy"; }, 2000); }' + "`n" +
        'function fallback(b, text) { var ta = document.createElement("textarea"); ta.value = text; ta.setAttribute("readonly", ""); ta.style.position = "fixed"; ta.style.opacity = "0"; document.body.appendChild(ta); ta.select(); var ok = false; try { ok = document.execCommand("copy"); } catch (e) { ok = false; } document.body.removeChild(ta);' + "`n" +
        '  if (ok) { label(b, "Copied"); return; } var code = b.parentNode.querySelector("code"); if (code) { var r = document.createRange(); r.selectNodeContents(code); var sel = window.getSelection(); sel.removeAllRanges(); sel.addRange(r); } label(b, "Press Ctrl+C"); }' + "`n" +
        'document.addEventListener("click", function (ev) { var b = ev.target.closest("[data-copy]"); if (!b) return; var text = b.getAttribute("data-copy");' + "`n" +
        '  if (navigator.clipboard && window.isSecureContext) { navigator.clipboard.writeText(text).then(function () { label(b, "Copied"); }, function () { fallback(b, text); }); } else { fallback(b, text); } });' + "`n" +
        '})();</script>'
}

function Format-DkjReposPageHtml {
    <#
        The DKJ repos page (#3231). -Query is ConvertFrom-DkjRepoQuery's result; -Checkouts is Find-DkjCheckouts'
        list; -Meta is @{ GeneratedAt; Seconds }. A checkout whose repo GitHub did not list (the query failed,
        a repo outside the first hundred, or an archived one, marked so) still gets its row, so the page never
        hides a folder on disk.
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Query,
        [AllowEmptyCollection()][Parameter(Mandatory = $true)][object[]]$Checkouts,
        [Parameter(Mandatory = $true)][hashtable]$Meta
    )
    $e = { param($v) ConvertTo-DashboardText $v }
    $byRepo = @{}
    foreach ($c in @($Checkouts | Where-Object { $_ })) { if (-not $byRepo.ContainsKey($c.Repo)) { $byRepo[$c.Repo] = $c } }
    $rows = @(@($Query.Repos) | Where-Object { $_ })
    $listed = @{}; foreach ($r in $rows) { $listed[$r.Repo] = $true }
    foreach ($c in @($byRepo.Values | Sort-Object { $_.Repo })) {
        if (-not $listed.ContainsKey($c.Repo)) {
            $vis = if (@($Query.Archived) -contains $c.Repo) { 'archived' } else { '' }
            $rows += @{ Repo = $c.Repo; Name = ($c.Repo -split '/')[-1]; Url = 'https://github.com/' + $c.Repo; Description = ''; Visibility = $vis; PushedAt = ''; Issues = $null; Pulls = $null }
        }
    }
    $sum = { param($k) $t = 0; foreach ($r in $rows) { if ($null -ne $r[$k]) { $t += [int]$r[$k] } }; $t }

    $body = New-Object System.Text.StringBuilder
    [void]$body.Append((Format-DevTiles @(
        @{ L = 'Repos'; V = $rows.Count },
        @{ L = 'Checked out here'; V = $byRepo.Count },
        @{ L = 'Open issues'; V = (& $sum 'Issues') },
        @{ L = 'Open pull requests'; V = (& $sum 'Pulls') })))
    if ($Query.Error) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">GitHub could not be read: ' + (& $e $Query.Error) + '. The checkouts on this machine are shown without their issues.</p>')
    }

    [void]$body.AppendLine('<div class="grid-2" id="repos">')
    [void]$body.AppendLine('<div class="grid__head"><h2>Repos</h2><p class="card__sub">Newest push first</p></div>')
    [void]$body.AppendLine('<section class="card grid__full">')
    [void]$body.AppendLine('<div class="table-wrap"><table class="table dr-table"><thead class="dr-thead"><tr><th class="dr-left">Repo</th><th>Visibility</th><th>Issues</th><th>Pull requests</th><th class="dr-left">Checkout here</th><th>Last push</th></tr></thead><tbody>')
    foreach ($r in $rows) {
        # The link is built from the repo's owner/name, never taken from the answer's url field (Sebastian, #3231).
        $url = 'https://github.com/' + (& $e $r.Repo)
        $desc = if ($r.Description) { '<span class="dr-desc">' + (& $e $r.Description) + '</span>' } else { '' }
        $count = { param($n, $path) if ($null -eq $n) { '--' } elseif ($n -gt 0) { '<a class="dr-link" href="' + $url + $path + '">' + $n + '</a>' } else { '0' } }
        $c = $byRepo[$r.Repo]
        $where = if (-not $c) { '<span class="note">not here</span>' }
                 else {
                     $state = if ($c.Dirty) { [string]$c.Dirty + ' uncommitted' } else { 'clean' }
                     '<code>' + (& $e $c.Branch) + '</code> <span class="note">' + $state + '</span>'
                 }
        $pushed = if ($r.PushedAt -match '^(\d{4}-\d{2}-\d{2})') { $Matches[1] } else { '--' }
        [void]$body.AppendLine('<tr><td class="dr-left"><a class="dr-link" href="' + $url + '">' + (& $e $r.Name) + '</a>' + $desc + '</td>' +
            '<td>' + $(if ($r.Visibility) { & $e $r.Visibility } else { '--' }) + '</td>' +
            '<td class="num">' + (& $count $r.Issues '/issues') + '</td><td class="num">' + (& $count $r.Pulls '/pulls') + '</td>' +
            '<td class="dr-left">' + $where + '</td><td>' + $pushed + '</td></tr>')
    }
    [void]$body.AppendLine('</tbody></table></div>')
    $nArch = @(@($Query.Archived) | Where-Object { $_ -and -not $byRepo.ContainsKey($_) }).Count
    if ($nArch) { [void]$body.AppendLine('<p class="note">' + $nArch + ' archived repo' + $(if ($nArch -ne 1) { 's are' } else { ' is' }) + ' left out.</p>') }
    [void]$body.AppendLine('</section>')
    [void]$body.AppendLine('</div>')

    # The sessions: one row per checkout, the command to copy. The server starts nothing (#3231).
    [void]$body.AppendLine('<div class="grid-2" id="sessions">')
    [void]$body.AppendLine('<div class="grid__head"><h2>Open a session</h2><p class="card__sub">Claude Code in that checkout, under that repo''s own rules. Paste the command in a terminal, or ask a session here: "open a session in lifehub"</p></div>')
    [void]$body.AppendLine('<section class="card grid__full">')
    if ($byRepo.Count) {
        [void]$body.AppendLine('<ul class="dr-sessions">')
        foreach ($c in @($byRepo.Values | Sort-Object { $_.Repo })) {
            $cmd = Format-RepoSessionCommand -Path ([string]$c.Path)
            [void]$body.AppendLine('<li><strong>' + (& $e (($c.Repo -split '/')[-1])) + '</strong><code>' + (& $e $cmd) + '</code><button type="button" class="btn" data-copy="' + (& $e $cmd) + '">Copy</button></li>')
        }
        [void]$body.AppendLine('</ul>')
    } else {
        [void]$body.AppendLine('<p class="note">No DKJ-Solutions checkout was found beside this repo.</p>')
    }
    [void]$body.AppendLine('</section>')
    [void]$body.AppendLine('</div>')
    [void]$body.AppendLine((Get-CopyButtonScript))

    $style = @(
        '.dr-link { color: var(--primary); text-underline-offset: 2px; }',
        '.dr-thead th { background: var(--paper-3); }',
        '.table td.dr-left, .table th.dr-left { text-align: left; }',
        '.dr-desc { display: block; font-size: var(--text-xs); color: var(--muted); }',
        '.dr-sessions { list-style: none; padding: 0; margin: 0; }',
        '.dr-sessions li { display: flex; flex-wrap: wrap; align-items: center; gap: var(--spacing-1-5) var(--spacing-3); padding: var(--spacing-2) 0; border-top: 1px solid var(--paper-3); }',
        '.dr-sessions li:first-child { border-top: 0; }',
        '.dr-sessions strong { min-width: 12ch; }',
        '.dr-sessions code { flex: 1 1 24ch; font-size: var(--text-xs); overflow-wrap: anywhere; }'
    ) -join "`n"
    $secs = if ($null -ne $Meta.Seconds) { ' in ' + ([double]$Meta.Seconds).ToString('0.0', [Globalization.CultureInfo]::InvariantCulture) + 's' } else { '' }
    return Format-DevPageHtml -Title 'DKJ repos' -BrandTag 'product' -Style $style -Body $body.ToString() `
        -Lead 'Every DKJ-Solutions repo on GitHub, where it is checked out on this machine, and a Claude Code session to open there. Work in a repo runs in that repo, and an issue for it is filed there.' `
        -FooterNote ('Read from GitHub (one <code>gh api graphql</code> call) and from the checkouts beside this repo, ' + (& $e $Meta.GeneratedAt) + $secs + ' (<a class="dr-link" href="/refresh?page=dkj-repos">read again</a>). Nothing here is written to this repo.')
}
