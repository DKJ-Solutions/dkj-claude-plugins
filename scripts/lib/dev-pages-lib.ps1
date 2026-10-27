<#
.SYNOPSIS
    This repo's PRODUCT (#3540): the home page on '/' and its own pages -- Connectors, Specialists and Plugins.
    The hub is the dkj-policy plugin's, as in every other repo (#3245): this repo states its dev server as
    its product and no longer opts out with OwnHub, so the general pages -- Repository, Artifacts, Issues,
    Release notes, SessionStart, Test gate, Stopwatch, Logbook and Plugins -- are the plugin hub's, and the
    product's home page links back to it. No I/O -- the server (scripts/dashboard/serve-connector-dashboard.ps1)
    measures and reads, and hands the results in, so every rule here is tested without a server.

.DESCRIPTION
    EVERY REPO HAS A PRODUCT PORT (Maikel, October 26, 2026, #3540). Retiring the brandbook/ app (#3493) took
    the product port with it and made this server the hub again, with the product's pages on it. The app
    could go; the port could not. So this server is the product once more, as it was from #3283 to #3493 for
    Connectors, Specialists and DKJ repos, and the hub is the plugin's: the same form as every consumer
    (#3464), so a hub change reaches this repo with a plugin update too.

    THE HOME PAGE is the house hub form (#3383): the general banner, the site header naming the repo with
    'product' after it, the bar with its one crumb, Home, and one .grid-3 of card links -- the Hub first,
    where the plugin's hub is known, then this repo's own pages (Get-ProductPages) -- and a footer note.

    ONE SHELL FOR EVERY PAGE BELOW THE HOME PAGE. Each page opens with the house breadcrumb bar, its trail
    starting at the home page on '/' and ending at the page itself, unlinked ("Every page: the breadcrumb
    bar"); then the settings button, an intro (eyebrow, h1, lead), the page's own blocks and a footer
    note naming where the data comes from. Format-DevPageHtml is this repo's call of the plugin's
    Format-GeneralPageHtml, which this file dot-sources for the page shell, the number formats and the tile
    and bar helpers, so nothing is written twice.

    THE DKJ REPOS ON GITHUB (#3231): every DKJ-Solutions repo, its checkout beside this repo, and the command that
    opens Claude Code there -- a section of the DKJ group's connector page, /connectors/dkj, since #3549, not a page
    of its own. Find-DkjCheckouts is the one function in this file that reads the disk.

    EVERY VALUE THAT REACHES THE PAGE IS ESCAPED, through connector-dashboard-lib's ConvertTo-DashboardText
    here and the plugin lib's own escape there (the two are the same five replacements).

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/dev-pages.tests.ps1.
#>

. (Join-Path $PSScriptRoot 'connector-dashboard-lib.ps1')
# The plugin's lib: this repo is its source, so it reads it from its own tree -- dkj-policy's page shell and
# card (#3198).
. (Join-Path $PSScriptRoot '..\..\plugins\dkj-policy\hub\lib\general-pages-lib.ps1')
# And the hub's Plugins page lib, for ConvertTo-PluginDescriptionHtml: a plugin's description as paragraphs.
. (Join-Path $PSScriptRoot '..\..\plugins\dkj-policy\hub\lib\plugins-page-lib.ps1')

function Format-DevPageHtml {
    <#
        The whole page around -Body, for this repo's own pages (Connectors, Specialists, Plugins): the
        plugin's page shell with this repo's site header, tagged 'product' (#3540), its title and theme key,
        and the Home crumb on '/', the product's home page.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Lead,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Body,
        [AllowEmptyString()][string]$Style = '',
        [AllowEmptyString()][string]$FooterNote = '',
        [string]$ThemeKey = 'general-pages',
        [switch]$Bare,
        [AllowEmptyCollection()][object[]]$ParentCrumbs = @()
    )
    # -Bare: no h1 or lead above the body, the general banner still on top (Format-GeneralPageHtml's own switch, #3356), for a page that opens on its content.
    return Format-GeneralPageHtml -Title $Title -Lead $Lead -Body $Body -Style $Style -FooterNote $FooterNote -ThemeKey $ThemeKey `
        -Brand 'dkj-claude-plugins' -BrandTag 'product' -SiteName 'dkj-claude-plugins' -HubHref '/' -Bare:$Bare -ParentCrumbs $ParentCrumbs
}

function Get-ProductPages {
    <#
        The pages the product's home page links, in the order it lists them: each a route on this server, its
        label the page's own name as its breadcrumb reads it, and one line on what it shows. The general pages
        are the plugin hub's, which the home page links as one card (#3540).
    #>
    @(
        @{ Href = '/connectors';  Label = 'Connectors';  Sub = 'Every repo registered under connectors/, as check-connectors.ps1 reports it on this machine'; Icon = 'connectors' }
        @{ Href = '/specialists'; Label = 'Specialists'; Sub = 'Every specialist the plugins ship, and how much context each one costs'; Icon = 'specialists' }
        @{ Href = '/plugins';     Label = 'Plugins';     Sub = 'Every plugin this marketplace ships, its version and what it holds'; Icon = 'plugins' }
    )
}

function Format-ProductHomeHtml {
    <#
        The product's home page on '/' (#3540). -Pages is Get-ProductPages' shape. -HubUrl is the plugin hub's
        url from the state file the dev-preview hook writes, or empty: only a plain loopback url is linked, as
        the Hub card that opens the grid; without one, a card says the hub starts at the next session start.
        -SourceCommit is the short sha the server loaded, or empty.
    #>
    param(
        [AllowEmptyCollection()][object[]]$Pages = @(Get-ProductPages),
        [AllowEmptyString()][string]$HubUrl = '',
        [AllowEmptyString()][string]$SourceCommit = ''
    )
    $e = { param($v) ConvertTo-DashboardText $v }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<!doctype html>')
    [void]$sb.AppendLine('<html lang="en" data-theme-default="lilac" data-width-default="full" data-theme-key="general-pages">')
    [void]$sb.AppendLine('<head>')
    [void]$sb.AppendLine('<meta charset="utf-8">')
    [void]$sb.AppendLine('<meta name="viewport" content="width=device-width, initial-scale=1">')
    [void]$sb.AppendLine('<title>dkj-claude-plugins -- Home</title>')
    [void]$sb.AppendLine('<link rel="stylesheet" href="/house-style.css">')
    [void]$sb.AppendLine('<script src="/house-theme.js"></script>')
    [void]$sb.AppendLine('</head>')
    [void]$sb.AppendLine('<body>')
    [void]$sb.Append((Format-RepoHomeHeadHtml -RepoName 'dkj-claude-plugins' -Brand 'dkj-claude-plugins' -BrandTag 'product' -Lead 'The source of the Claude Specialists plugins: the marketplace, its agent definitions, manuals and skills, and the scripts and gates that ship them.'))
    # Every page a card of its own, three to a row, with no heading above them (the house hub form, #3383): the
    # hub first, so the way back is where the eye starts, then this repo's own pages.
    [void]$sb.AppendLine('<div class="grid-3">')
    if ($HubUrl -cmatch '^http://localhost:[0-9]{4,5}/?\z') {
        [void]$sb.AppendLine((Format-HubCardLinkHtml -Href $HubUrl -Label 'Hub' -Sub 'The dkj-policy hub: Repository, Issues, Release notes, the Test gate and every other general page' -Icon 'repository'))
    } else {
        [void]$sb.AppendLine('<section class="card"><p class="msg" role="status">The hub is not running. The dkj-policy dev-preview hook starts it at the next session start.</p></section>')
    }
    foreach ($p in @($Pages)) { [void]$sb.AppendLine((Format-HubCardLinkHtml -Href $p.Href -Label $p.Label -Sub $p.Sub -Icon $p.Icon)) }
    [void]$sb.AppendLine('</div>')
    $at = if ($SourceCommit) { ', from <code>' + (& $e $SourceCommit) + '</code>' } else { '' }
    [void]$sb.AppendLine('<p class="footer-note">Each page names its own source. Served on 127.0.0.1 only, by <code>scripts/dashboard/serve-connector-dashboard.ps1</code>' + $at + '.</p>')
    [void]$sb.AppendLine('</main>')
    [void]$sb.AppendLine('<script>DKJTheme.settings(document.getElementById("settings"), { label: "Settings", title: "Settings", theme: "Theme", reset: "Reset theme", light: "Light", dark: "Dark", width: "Width", fluid: "Fluid", phone: "Phone", full: "Full" });</script>')
    # The fit alarm, as the plugin's page shell closes every hub page (#3558).
    [void]$sb.AppendLine((Format-FitAlarmHtml))
    [void]$sb.AppendLine('</body>')
    [void]$sb.AppendLine('</html>')
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

        THE DETAIL PAGE'S PARTS (#3551) ride along: Slug, the name lowercased, which is the route segment of
        /specialists/<plugin>/<slug> (the id where the name is not a plain word); Description and Body, the
        listing and the definition as text; and -DefinitionPath, -ManualPath and -LensPath, repo-relative paths
        the page names ('' where there is no such file).
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Plugin,
        [Parameter(Mandatory = $true)][ValidateSet('subagent', 'persona')][string]$Form,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
        [AllowNull()]$ManualBytes,
        [AllowNull()]$LensBytes,
        [bool]$Enabled = $false,
        [AllowEmptyString()][string]$DefinitionPath = '',
        [AllowEmptyString()][string]$ManualPath = '',
        [AllowEmptyString()][string]$LensPath = ''
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
        Slug = $(if ($name -cmatch '^[A-Za-z][A-Za-z0-9-]*$') { $name.ToLowerInvariant() } else { $Id })
        Description = $desc; Body = $body.Trim()
        DefinitionPath = $DefinitionPath
        ManualPath = $(if ($null -ne $ManualBytes) { $ManualPath } else { '' })
        LensPath = $(if ($null -ne $LensBytes) { $LensPath } else { '' })
    }
}

function Get-SpecialistPlugins {
    <#
        The specialist plugins -Rows names, each @{ Plugin; Short; Kind; Enabled; Rows; ListingBytes; TotalBytes }, in
        the order the Specialists page lists them (#3550): the core team first, then the add-on teams enabled here,
        then those that are not, by name. Short is the plugin's name without 'dkj-subagents-', the detail page's
        route segment; Rows keeps the order it was handed.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Rows)
    $rows = @($Rows | Where-Object { $_ })
    $out = @()
    foreach ($pl in @($rows | ForEach-Object { $_.Plugin } | Select-Object -Unique)) {
        $mine = @($rows | Where-Object { $_.Plugin -eq $pl })
        # Summed by hand: 5.1's Measure-Object -Property does not read a hashtable's keys.
        $listing = [int64]0; $full = [int64]0
        foreach ($r in $mine) { $listing += [int64]$r.ListingBytes; $full += [int64]$r.TotalBytes }
        $out += @{
            Plugin = $pl; Short = ($pl -replace '^dkj-subagents-', '')
            Kind = $(if ($pl -eq 'dkj-subagents-alpha') { 'core team' } else { 'add-on team' })
            Enabled = [bool]@($mine | Where-Object { $_.Enabled }).Count
            Rows = $mine; ListingBytes = $listing; TotalBytes = $full
        }
    }
    return @($out | Sort-Object @{ Expression = { $_.Plugin -ne 'dkj-subagents-alpha' } }, @{ Expression = { -not $_.Enabled } }, @{ Expression = { $_.Plugin } })
}

function Format-SpecialistPageHtml {
    <#
        One specialist's own page, /specialists/<plugin>/<slug> (#3551): the trail Home > Specialists > plugin >
        name; the specialist's tiles (its four parts and the full read, in tokens); a facts card saying what it
        is, when it loads and where each of its files is; its listing; and its definition, folded, because it
        runs to pages. -Row is ConvertTo-SpecialistRow's shape, -Pick Get-SpecialistPlugins' entry for its plugin.
    #>
    param(
        [Parameter(Mandatory = $true)]$Row,
        [Parameter(Mandatory = $true)]$Pick,
        [Parameter(Mandatory = $true)][double]$CharsPerToken,
        [AllowEmptyString()][string]$ReadError = ''
    )
    $e = { param($v) ConvertTo-DashboardText $v }
    $tok = { param($b) if ($null -eq $b) { '--' } elseif ([int64]$b -eq 0) { '--' } else { '~' + (Format-DevNumber ([Math]::Round([double]$b / $CharsPerToken))) } }
    $path = { param($p) if ($p) { '<code>' + (& $e $p) + '</code>' } else { '<span class="note">none</span>' } }
    $r = $Row
    $label = $r.Name + $(if ($r.Emoji) { ' ' + $r.Emoji } else { '' })
    $loads = if ($r.AlwaysOn) { 'Imported on every turn: the orchestrator is always loaded.' }
        elseif ($r.Form -eq 'subagent') { 'Its listing is in every session that enables the plugin; its definition each time it is spawned.' }
        else { 'Read on demand, when a turn hands it the work: a persona has no listing.' }

    $body = New-Object System.Text.StringBuilder
    [void]$body.Append((Format-DevTiles @(
        @{ L = 'Listing'; V = (& $tok $r.ListingBytes) },
        @{ L = 'Definition'; V = (& $tok $r.DefinitionBytes) },
        @{ L = 'Manual'; V = (& $tok $r.ManualBytes) },
        @{ L = 'Lens'; V = (& $tok $r.LensBytes) },
        @{ L = 'Full read'; V = (& $tok $r.TotalBytes) })))
    if ($ReadError) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">The specialists could not all be read: ' + (& $e $ReadError) + '.</p>')
    }
    if (-not $Pick.Enabled) {
        [void]$body.AppendLine('<p class="msg" role="status">Its plugin is not enabled in this repo''s <code>.claude/settings.json</code>: no session here carries its listing, and it has no lens here.</p>')
    }
    [void]$body.AppendLine('<div class="grid-2" id="about">')
    [void]$body.AppendLine('<section class="card"><div class="card__head"><h2>What it is</h2></div><dl class="facts">')
    [void]$body.AppendLine('<div><dt>Number</dt><dd>#' + (& $e $r.Number) + ' <span class="note">(' + (& $e $r.Id) + ')</span></dd></div>')
    if ($r.Title) { [void]$body.AppendLine('<div><dt>Title</dt><dd>' + (& $e $r.Title) + '</dd></div>') }
    [void]$body.AppendLine('<div><dt>Plugin</dt><dd><code>' + (& $e $Pick.Plugin) + '</code>, the ' + (& $e $Pick.Kind) + '</dd></div>')
    [void]$body.AppendLine('<div><dt>Form</dt><dd>' + (& $e $r.Form) + '</dd></div>')
    [void]$body.AppendLine('<div><dt>Loads</dt><dd>' + $loads + '</dd></div>')
    [void]$body.AppendLine('</dl></section>')
    [void]$body.AppendLine('<section class="card"><div class="card__head"><h2>Its files</h2></div><dl class="facts">')
    [void]$body.AppendLine('<div><dt>Definition</dt><dd>' + (& $path $r.DefinitionPath) + '</dd></div>')
    [void]$body.AppendLine('<div><dt>Manual</dt><dd>' + (& $path $r.ManualPath) + '</dd></div>')
    [void]$body.AppendLine('<div><dt>Lens</dt><dd>' + (& $path $r.LensPath) + '</dd></div>')
    [void]$body.AppendLine('</dl></section>')
    [void]$body.AppendLine('</div>')
    [void]$body.AppendLine('<div class="grid-2" id="text">')
    [void]$body.AppendLine('<section class="card grid__full"><div class="card__head"><h2>Listing</h2><p class="card__sub">' +
        $(if ($r.Form -eq 'subagent') { 'The description Claude Code puts in every session that enables the plugin' } else { 'A persona has none' }) + '</p></div>' +
        $(if ($r.Description) { '<p>' + (& $e $r.Description) + '</p>' } else { '<p class="note">None.</p>' }) + '</section>')
    [void]$body.AppendLine('<section class="card grid__full"><div class="card__head"><h2>Definition</h2><p class="card__sub">The file without its frontmatter, as the tree holds it now</p></div>' +
        '<details class="more"><summary>Show the definition</summary><pre class="sp-text">' + (& $e $r.Body) + '</pre></details></section>')
    [void]$body.AppendLine('</div>')

    $style = $script:DevBarStyle + "`n" + '.sp-text { margin: 0; padding: var(--spacing-3); background: var(--paper-2); color: var(--fg-1); border-radius: var(--spacing-2); font-family: ui-monospace, Consolas, monospace; font-size: var(--text-sm); white-space: pre-wrap; overflow-wrap: anywhere; }'
    $factor = $CharsPerToken.ToString('0.00', [Globalization.CultureInfo]::InvariantCulture)
    $footer = 'Read from this checkout''s <code>plugins/dkj-subagents/</code> and <code>.claude/specialists/lenses/</code> on every request, so it is the tree, not the installed release. Tokens are an estimate at ' + $factor + ' characters per token, the factor in <code>scripts/lib/measure-context-lib.ps1</code>.'
    return Format-DevPageHtml -Title $label -Style $style -Body $body.ToString() -FooterNote $footer `
        -ParentCrumbs @(@{ Label = 'Specialists'; Href = '/specialists' }, @{ Label = $Pick.Short; Href = '/specialists/' + $Pick.Short }) `
        -Lead ((& $e $r.Title) + $(if ($r.Title) { ' &middot; ' } else { '' }) + 'a ' + (& $e $r.Form) + ' in the <code>' + (& $e $Pick.Plugin) + '</code> plugin.')
}

function Format-SpecialistsPageHtml {
    <#
        The Specialists pages. -Rows is ConvertTo-SpecialistRow's shape; -CharsPerToken the calibrated
        factor (measure-context-lib's Get-CalibratedCharsPerToken). The bytes are measured, the tokens an
        estimate at that factor, and the page says which is which.

        TWO LEVELS (#3550, the owner: the cards must link to a deeper page). Without -Plugin it is /specialists:
        one card per specialist plugin and nothing above them but the h1, three to a row in the hub's card
        form, each linking its plugin's page. With -Plugin (a Short from Get-SpecialistPlugins) it is
        /specialists/<plugin>: a three-crumb trail, the tiles over that plugin and its specialists' table. A
        -Plugin the rows do not name returns $null, so the server answers 404 rather than an empty page.
        A plugin not enabled here keeps its card, muted, and its page says what being off means here.

        AND A THIRD LEVEL (#3551; Maikel: the pages nest as deep as the structure needs). A plugin's page opens on
        one card per specialist, in roster order, above the table that compares them; each card links
        /specialists/<plugin>/<slug>. With -Specialist as well it is that page: a four-crumb trail, the
        specialist's own tiles, what it is and where its files are, its listing and its definition. A
        -Specialist the plugin does not ship returns $null too.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Rows,
        [Parameter(Mandatory = $true)][double]$CharsPerToken,
        [AllowEmptyString()][string]$ReadError = '',
        [AllowEmptyString()][string]$Plugin = '',
        [AllowEmptyString()][string]$Specialist = ''
    )
    $e = { param($v) ConvertTo-DashboardText $v }
    $inv = [Globalization.CultureInfo]::InvariantCulture
    $tok = { param($b) if ($null -eq $b) { '--' } elseif ([int64]$b -eq 0) { '--' } else { '~' + (Format-DevNumber ([Math]::Round([double]$b / $CharsPerToken))) } }
    $rows = @($Rows | Where-Object { $_ } | Sort-Object @{ Expression = { [int64]$_.TotalBytes }; Descending = $true }, @{ Expression = { $_.Id } })
    $plugins = @(Get-SpecialistPlugins -Rows $rows)
    $pick = $null
    if ($Plugin) {
        $pick = @($plugins | Where-Object { $_.Short -ceq $Plugin })[0]
        if (-not $pick) { return $null }
        $rows = @($pick.Rows)
    }
    if ($Specialist) {
        $one = if ($pick) { @($rows | Where-Object { $_.Slug -ceq $Specialist })[0] } else { $null }
        if (-not $one) { return $null }
        return Format-SpecialistPageHtml -Row $one -Pick $pick -CharsPerToken $CharsPerToken -ReadError $ReadError
    }
    $max = if ($rows.Count) { [double]$rows[0].TotalBytes } else { 0 }
    $body = New-Object System.Text.StringBuilder
    # Both levels open on their cards: no tiles, no heading over the grid and no lead (the owner, #3550; on a
    # plugin's page too since October 27, 2026, #3551).
    if ($ReadError) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">The specialists could not all be read: ' + (& $e $ReadError) + '.</p>')
    }

    if (-not $pick) {
        # /specialists: one card per plugin in the hub's card form, its label an h2 and its summary under it, the
        # whole card the link (as /connectors does its owner groups). An off plugin keeps its card, muted.
        [void]$body.AppendLine('<div class="grid-3" id="plugins">')
        foreach ($p in $plugins) {
            $sub = @($p.Kind, $(if ($p.Enabled) { 'enabled here' } else { 'off here' }),
                ([string]$p.Rows.Count + ' specialist' + $(if ($p.Rows.Count -ne 1) { 's' } else { '' })),
                ('listing ' + (& $tok $p.ListingBytes)), ('full read ' + (& $tok $p.TotalBytes))) -join ' &middot; '
            [void]$body.AppendLine((Format-HubCardLinkHtml -Href ('/specialists/' + $p.Short) -Label $p.Short -SubHtml $sub -Heading 2 -Id ('plugin-' + $p.Short) `
                -Class ('sp-card' + $(if ($p.Enabled) { '' } else { ' sp-card--off' }))))
        }
        if (-not $plugins.Count) {
            [void]$body.AppendLine('<section class="card grid__full"><p class="note">No specialist was found.</p></section>')
        }
        [void]$body.AppendLine('</div>')
    } else {
        if (-not $pick.Enabled) {
            [void]$body.AppendLine('<p class="msg" role="status">Not enabled in this repo''s <code>.claude/settings.json</code>: no session here carries its listing, and its specialists have no lens here.</p>')
        }
        # One card per specialist, in roster order, each the link to its own page (#3551), four to a row (the
        # owner, October 27, 2026), in a grid of its own: the house .grid-3 is never restyled here.
        [void]$body.AppendLine('<div class="sp-grid" id="cards">')
        foreach ($r in @($rows | Sort-Object @{ Expression = { $_.Id } })) {
            $sub = @(('#' + (& $e $r.Number)), $(if ($r.Title) { & $e $r.Title }), (& $e $r.Form), ('full read ' + (& $tok $r.TotalBytes))) |
                Where-Object { $_ }
            [void]$body.AppendLine((Format-HubCardLinkHtml -Href ('/specialists/' + $pick.Short + '/' + $r.Slug) -SubHtml ($sub -join ' &middot; ') -Heading 2 `
                -Label ($r.Name + $(if ($r.Emoji) { ' ' + $r.Emoji } else { '' })) -Id ('specialist-' + $r.Slug) -Class 'sp-card'))
        }
        [void]$body.AppendLine('</div>')
        [void]$body.AppendLine('<div class="grid-2" id="specialists">')
        [void]$body.AppendLine('<div class="grid__head"><h2>Context per specialist</h2><p class="card__sub">' + (& $e $pick.Kind) + ' &middot; <code>' + (& $e $pick.Plugin) + '</code>. Estimated tokens, largest full read first; the bar is the full read against the largest one</p></div>')
        [void]$body.AppendLine('<section class="card grid__full">')
        [void]$body.AppendLine('<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">Specialist</th><th>Listing</th><th>Definition</th><th>Manual</th><th>Lens</th><th>Full read</th><th class="dp-left">Against the largest</th></tr></thead><tbody>')
        foreach ($r in $rows) {
            # Muted text, not .badge: the house badge is an 18px circle for one character, and a word in it
            # spills over the text beside it.
            $badges = ' <span class="note">&middot; ' + (& $e $r.Form) + $(if ($r.AlwaysOn) { ' &middot; always-on' } else { '' }) + '</span>'
            $w = $(if ($max -gt 0) { [Math]::Min(100.0, 100.0 * [double]$r.TotalBytes / $max) } else { 0.0 }).ToString('0.##', $inv)
            $label = (& $e $r.Name) + $(if ($r.Emoji) { ' ' + (& $e $r.Emoji) } else { '' })
            # One line per specialist: the title and the badges follow the name inline, where a block-level
            # title and badge row gave every specialist three lines.
            [void]$body.AppendLine('<tr><td class="dp-left"><strong><a href="/specialists/' + (& $e $pick.Short) + '/' + (& $e $r.Slug) + '">' + $label + '</a></strong> <span class="note">#' + (& $e $r.Number) +
                $(if ($r.Title) { ' &middot; ' + (& $e $r.Title) } else { '' }) + '</span>' + $badges + '</td>' +
                '<td class="num" title="' + (Format-DevNumber $r.ListingBytes) + ' B">' + (& $tok $r.ListingBytes) + '</td>' +
                '<td class="num" title="' + (Format-DevNumber $r.DefinitionBytes) + ' B">' + (& $tok $r.DefinitionBytes) + '</td>' +
                '<td class="num" title="' + (Format-DevNumber $r.ManualBytes) + ' B">' + (& $tok $r.ManualBytes) + '</td>' +
                '<td class="num" title="' + (Format-DevNumber $r.LensBytes) + ' B">' + (& $tok $r.LensBytes) + '</td>' +
                '<td class="num"><strong>' + (& $tok $r.TotalBytes) + '</strong></td>' +
                '<td class="dp-left"><span class="dp-bar" aria-hidden="true"><span style="width: ' + $w + '%"></span></span></td></tr>')
        }
        [void]$body.AppendLine('</tbody></table></div>')
        [void]$body.AppendLine('</section>')
        [void]$body.AppendLine('</div>')
        # What each column means, under the table it explains; the overview has no table, so it has none (#3550).
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
    }
    $factor = $CharsPerToken.ToString('0.00', $inv)
    # An off plugin's card is muted, never hidden. The specialist grid is its own, four to a row and stepping
    # down 4 -> 3 -> 2 -> 1, in .grid-3's gap and breakpoints (as the DKJ repos' .dr-grid is).
    $style = $script:DevBarStyle + "`n" + '.sp-card--off { opacity: 0.7; }' + "`n" +
        (@(
            '.sp-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: var(--spacing-4); }',
            '@media (max-width: 1200px) { .sp-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); } }',
            '@media (max-width: 1000px) { .sp-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); } }',
            '@media (max-width: 760px) { .sp-grid { grid-template-columns: 1fr; } }',
            '.sp-grid > .card { margin-top: 0; }'
        ) -join "`n")
    $footer = 'Read from this checkout''s <code>plugins/dkj-subagents/</code> and <code>.claude/specialists/lenses/</code> on every request, so it is the tree, not the installed release. Bytes are measured (hover a cell); tokens are an estimate at ' + $factor + ' characters per token, the factor in <code>scripts/lib/measure-context-lib.ps1</code>.'
    if ($pick) {
        return Format-DevPageHtml -Title $pick.Short -Style $style -Body $body.ToString() -FooterNote $footer `
            -ParentCrumbs @(@{ Label = 'Specialists'; Href = '/specialists' }) -Lead ''
    }
    return Format-DevPageHtml -Title 'Specialists' -Style $style -Body $body.ToString() -FooterNote $footer -Lead ''
}

function Get-MarketplacePluginKind {
    <#
        What kind of plugin -Name is, from its name and its -Source path in marketplace.json: a team (the core
        team or an add-on team), the workflow, or an add-on to that workflow -- the split the marketplace's own
        description draws.
    #>
    param([Parameter(Mandatory = $true)][string]$Name, [AllowEmptyString()][string]$Source = '')
    if ($Name -eq 'dkj-subagents-alpha') { return 'core team' }
    if ($Name -like 'dkj-subagents-*') { return 'add-on team' }
    if ($Name -eq 'dkj-policy') { return 'workflow' }
    if ($Source -like './plugins/dkj-policy/*') { return 'add-on to dkj-policy' }
    return 'plugin'
}

function Format-MarketplacePluginsPageHtml {
    <#
        The Plugins pages: every plugin this marketplace ships. -Plugins is the server's model, in
        marketplace.json's order, each @{ Name; Kind; Source; Version; Enabled; Summary; Description; Subagents;
        Personas; Skills; Hooks }: Summary is the marketplace's own line, Description the plugin.json's. Where the
        hub's Plugins page shows what THIS checkout enables, these show what the repo OFFERS, enabled here or not.

        THE LEVELS (the owner, October 27, 2026: the cards were crammed, so the detail goes a level deeper, as on
        the Specialists pages; and the four specialist teams share one card). Without -Plugin or -Group it is
        /plugins: one link card per plugin saying what it is, its version and whether it is on here -- except the
        teams (dkj-subagents-*), which stand as ONE card, 'dkj-subagents', in the place of the first of them. With
        -Group 'dkj-subagents' alone it is that card's page, one link card per team. With -Plugin it is one
        plugin's page -- /plugins/<name>, or /plugins/dkj-subagents/<name> for a team, so a team is reachable only
        under its group: the marketplace's line as the lead, a facts card and the full description as paragraphs
        (the hub's ConvertTo-PluginDescriptionHtml). A -Group or -Plugin that names nothing, or a plugin under the
        wrong level, returns $null, so the server answers 404 rather than an empty page.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Plugins,
        [AllowEmptyString()][string]$ReadError = '',
        [AllowEmptyString()][string]$Group = '',
        [AllowEmptyString()][string]$Plugin = ''
    )
    $e = { param($v) ConvertTo-DashboardText $v }
    $all = @($Plugins | Where-Object { $_ })
    $teamGroup = 'dkj-subagents'
    $isTeam = { param($p) [string]$p.Name -like ($teamGroup + '-*') }
    $teams = @($all | Where-Object { & $isTeam $_ })
    if ($Group -and $Group -cne $teamGroup) { return $null }
    $state = { param($p) @((& $e $p.Kind), $(if ($p.Version) { 'v' + (& $e $p.Version) }), $(if ($p.Enabled) { 'enabled here' } else { 'off here' })) | Where-Object { $_ } }
    $card = { param($p, $href) Format-HubCardLinkHtml -Href $href -Label $p.Name -SubHtml ((& $state $p) -join ' &middot; ') -Heading 2 `
        -Id ('plugin-' + $p.Name) -Class ('pl-card' + $(if ($p.Enabled) { '' } else { ' pl-card--off' })) }
    $body = New-Object System.Text.StringBuilder
    if ($ReadError) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">The plugins could not all be read: ' + (& $e $ReadError) + '.</p>')
    }
    $footer = 'Read from this checkout''s <code>.claude-plugin/marketplace.json</code> and each plugin''s <code>.claude-plugin/plugin.json</code> on every request, so it is the tree, not the installed release; enabled or off is <code>.claude/settings.json</code>. What this checkout loads, and any problem with it, is on the hub''s own Plugins page.'
    # An off plugin's card is muted, never hidden, as on the Specialists pages.
    $style = '.pl-card--off { opacity: 0.7; }'

    if (-not $Plugin -and -not $Group) {
        [void]$body.AppendLine('<div class="grid-3" id="plugins">')
        $teamsDone = $false
        foreach ($p in $all) {
            if (& $isTeam $p) {
                if ($teamsDone) { continue }
                $teamsDone = $true
                $on = @($teams | Where-Object { $_.Enabled }).Count
                $sub = [string]$teams.Count + ' specialist team' + $(if ($teams.Count -ne 1) { 's' } else { '' }) + ' &middot; ' + $on + ' enabled here'
                [void]$body.AppendLine((Format-HubCardLinkHtml -Href ('/plugins/' + $teamGroup) -Label $teamGroup -SubHtml $sub -Heading 2 `
                    -Id ('group-' + $teamGroup) -Class ('pl-card' + $(if ($on) { '' } else { ' pl-card--off' }))))
                continue
            }
            [void]$body.AppendLine((& $card $p ('/plugins/' + $p.Name)))
        }
        if (-not $all.Count) {
            [void]$body.AppendLine('<section class="card grid__full"><p class="note">No plugin was found.</p></section>')
        }
        [void]$body.AppendLine('</div>')
        return Format-DevPageHtml -Title 'Plugins' -Style $style -Body $body.ToString() -FooterNote $footer -Lead ''
    }

    if (-not $Plugin) {
        # The teams' own page: one card per team, in the marketplace's order.
        if (-not $teams.Count) { return $null }
        [void]$body.AppendLine('<div class="grid-3" id="teams">')
        foreach ($p in $teams) { [void]$body.AppendLine((& $card $p ('/plugins/' + $teamGroup + '/' + $p.Name))) }
        [void]$body.AppendLine('</div>')
        return Format-DevPageHtml -Title $teamGroup -Style $style -Body $body.ToString() -FooterNote $footer `
            -ParentCrumbs @(@{ Label = 'Plugins'; Href = '/plugins' }) -Lead ''
    }

    $p = @($all | Where-Object { $_.Name -ceq $Plugin })[0]
    if (-not $p -or [bool]$Group -ne [bool](& $isTeam $p)) { return $null }
    $crumbs = @(@{ Label = 'Plugins'; Href = '/plugins' })
    if ($Group) { $crumbs += @{ Label = $teamGroup; Href = '/plugins/' + $teamGroup } }
    # '' rather than no output for a zero: in 5.1 a call that writes nothing empties the whole @(a, b, ...) it stands in.
    $count = { param($n, $word) if ([int]$n -gt 0) { [string]$n + ' ' + $word + $(if ([int]$n -ne 1) { 's' } else { '' }) } else { '' } }
    $holds = @((& $count $p.Subagents 'subagent'), (& $count $p.Personas 'persona'), (& $count $p.Skills 'skill'), (& $count $p.Hooks 'hook')) | Where-Object { $_ }
    # The lead is the marketplace's line up to its first sentence: some run to paragraphs, which the description card holds.
    $lead = if ([string]$p.Summary -cmatch '^(.+?[.!?])\s+[A-Z]') { $Matches[1] } else { [string]$p.Summary }
    if (-not $p.Enabled) {
        [void]$body.AppendLine('<p class="msg" role="status">Not enabled in this repo''s <code>.claude/settings.json</code>: no session here loads it.</p>')
    }
    [void]$body.AppendLine('<div class="grid-2" id="about">')
    [void]$body.AppendLine('<section class="card grid__full"><div class="card__head"><h2>What it is</h2></div><dl class="facts">')
    [void]$body.AppendLine('<div><dt>Kind</dt><dd>' + (& $e $p.Kind) + '</dd></div>')
    [void]$body.AppendLine('<div><dt>Version</dt><dd>' + $(if ($p.Version) { 'v' + (& $e $p.Version) } else { '<span class="note">none stated</span>' }) + '</dd></div>')
    [void]$body.AppendLine('<div><dt>Here</dt><dd>' + $(if ($p.Enabled) { 'enabled' } else { 'off' }) + '</dd></div>')
    [void]$body.AppendLine('<div><dt>Holds</dt><dd>' + $(if ($holds) { $holds -join ' &middot; ' } else { '<span class="note">nothing counted</span>' }) + '</dd></div>')
    [void]$body.AppendLine('<div><dt>Source</dt><dd><code>' + (& $e $p.Source) + '</code></dd></div>')
    [void]$body.AppendLine('</dl></section>')
    [void]$body.AppendLine('<section class="card grid__full"><div class="card__head"><h2>Description</h2><p class="card__sub">From its <code>.claude-plugin/plugin.json</code></p></div>' +
        $(if ($p.Description) { ConvertTo-PluginDescriptionHtml -Text $p.Description } else { '<p class="note">None.</p>' }) + '</section>')
    [void]$body.AppendLine('</div>')
    return Format-DevPageHtml -Title $p.Name -Style $style -Body $body.ToString() -FooterNote $footer -Lead (& $e $lead) `
        -ParentCrumbs $crumbs
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
        The one GraphQL query the DKJ repos section asks: every repo of the organisation named by the variable
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

function Format-DkjReposSectionHtml {
    <#
        The DKJ repos on GitHub (#3231), as a section of the DKJ group's connector page (#3549): the old
        /dkj-repos page and /connectors/dkj both covered the DKJ repos under one title, so the cards moved onto
        the connector page, between its Connected repos table and its Issues card. Returns @{ Html; Style;
        FooterNote } for Format-ConnectorDashboardHtml's -Section* parameters.
        -Query is ConvertFrom-DkjRepoQuery's result; -Checkouts is Find-DkjCheckouts' list; -Meta is
        @{ GeneratedAt; Seconds }. A checkout whose repo GitHub did not list (the query failed, a repo outside
        the first hundred, or an archived one, marked so) still gets its card, so the page never hides a
        folder on disk.
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

    # One card per repo, newest push first, in the Stopwatch overview's three-column grid (the owner, October 26,
    # 2026): no tiles and no table, and a checkout's session command in its own repo's card rather than a list of
    # its own. Its h2 heads the grid as Connected repos and Issues head theirs. The server starts nothing (#3231).
    $body = New-Object System.Text.StringBuilder
    [void]$body.AppendLine('<div class="dr-grid" id="repos">')
    [void]$body.AppendLine('<div class="grid__head"><h2>On GitHub</h2><p class="card__sub">Every DKJ-Solutions repo, its checkout here, and a session to open there</p></div>')
    if ($Query.Error) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">GitHub could not be read: ' + (& $e $Query.Error) + '. The checkouts on this machine are shown without their issues.</p>')
    }
    foreach ($r in $rows) {
        # The link is built from the repo's owner/name, never taken from the answer's url field (Sebastian, #3231).
        $url = 'https://github.com/' + (& $e $r.Repo)
        $count = { param($n, $path, $noun) if ($null -eq $n) { '-- ' + $noun } elseif ($n -gt 0) { '<a class="dr-link" href="' + $url + $path + '">' + $n + '</a> ' + $noun } else { '0 ' + $noun } }
        $facts = @()
        if ($r.Visibility) { $facts += (& $e $r.Visibility) }
        $facts += (& $count $r.Issues '/issues' 'issues')
        $facts += (& $count $r.Pulls '/pulls' 'PRs')
        if ($r.PushedAt -match '^(\d{4}-\d{2}-\d{2})') { $facts += $Matches[1] }
        [void]$body.Append('<section class="card dr-card"><h3><a href="' + $url + '">' + (& $e $r.Name) + '</a></h3>')
        if ($r.Description) { [void]$body.Append('<p class="dr-desc" title="' + (& $e $r.Description) + '">' + (& $e $r.Description) + '</p>') }
        [void]$body.Append('<p class="dr-line">' + ($facts -join ' &middot; ') + '</p>')
        $c = $byRepo[$r.Repo]
        if ($c) {
            $state = if ($c.Dirty) { [string]$c.Dirty + ' uncommitted' } else { 'clean' }
            $cmd = Format-RepoSessionCommand -Path ([string]$c.Path)
            [void]$body.Append('<p class="dr-line"><code>' + (& $e $c.Branch) + '</code> <span class="dr-muted">' + $state + '</span></p>')
            [void]$body.Append('<p class="dr-session"><button type="button" class="btn" data-copy="' + (& $e $cmd) + '">Copy</button><code title="' + (& $e $cmd) + '">' + (& $e $cmd) + '</code></p>')
        } else {
            [void]$body.Append('<p class="dr-line dr-muted">Not checked out here</p>')
        }
        [void]$body.AppendLine('</section>')
    }
    [void]$body.AppendLine('</div>')
    $nArch = @(@($Query.Archived) | Where-Object { $_ -and -not $byRepo.ContainsKey($_) }).Count
    if ($nArch) { [void]$body.AppendLine('<p class="note">' + $nArch + ' archived repo' + $(if ($nArch -ne 1) { 's are' } else { ' is' }) + ' left out.</p>') }
    if (-not $byRepo.Count) { [void]$body.AppendLine('<p class="note">No DKJ-Solutions checkout was found beside this repo.</p>') }
    [void]$body.AppendLine((Get-CopyButtonScript))

    $style = @(
        '.dr-link { color: var(--primary); text-underline-offset: 2px; }',
        '.dr-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: var(--spacing-4); }',
        '@media (max-width: 1000px) { .dr-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); } }',
        '@media (max-width: 760px) { .dr-grid { grid-template-columns: 1fr; } }',
        '.dr-grid > .grid__head, .dr-grid > .msg { grid-column: 1 / -1; }',
        '.dr-grid > .msg { margin: 0; }',
        '.dr-grid > .card { margin-top: 0; }',
        '.dr-card > h3 { margin: 0 0 var(--spacing-1); }',
        '.dr-card > h3 a { color: inherit; text-decoration: none; }',
        '.dr-card > p { margin: 0; }',
        '.dr-card > p + p { margin-top: var(--spacing-1); }',
        # A card's lines in the Stopwatch card's sizes: the description one muted line ending in an ellipsis, its
        # whole text on hover, and the session command likewise, copied whole by its button.
        '.dr-desc { font-size: var(--text-sm); color: var(--muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }',
        '.dr-line { font-size: var(--text-sm); }',
        '.dr-muted { color: var(--muted); }',
        '.dr-card > .dr-session { display: flex; align-items: center; gap: var(--spacing-2); margin-top: var(--spacing-3); }',
        '.dr-session code { flex: 1 1 auto; min-width: 0; font-size: var(--text-xs); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }'
    ) -join "`n"
    $secs = if ($null -ne $Meta.Seconds) { ' in ' + ([double]$Meta.Seconds).ToString('0.0', [Globalization.CultureInfo]::InvariantCulture) + 's' } else { '' }
    # The page's one refresh link re-reads both, so this note names its source and time and offers no link of its own.
    return @{ Html = $body.ToString(); Style = $style
              FooterNote = 'On GitHub: read with one <code>gh api graphql</code> call and from the checkouts beside this repo, ' + (& $e $Meta.GeneratedAt) + $secs + '.' }
}
