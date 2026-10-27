<#
.SYNOPSIS
    This repo's PRODUCT (#3540): the home page on '/' and its own pages -- Connectors and Specialists.
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

function Format-DevPageHtml {
    <#
        The whole page around -Body, for this repo's own pages (Connectors, Specialists): the
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

function Format-SpecialistsPageHtml {
    <#
        The Specialists pages. -Rows is ConvertTo-SpecialistRow's shape; -CharsPerToken the calibrated
        factor (measure-context-lib's Get-CalibratedCharsPerToken). The bytes are measured, the tokens an
        estimate at that factor, and the page says which is which.

        TWO LEVELS (#3550, the owner: the cards must link to a deeper page). Without -Plugin it is /specialists:
        the tiles over every specialist and one card per specialist plugin, three to a row in the hub's card
        form, each linking its plugin's page. With -Plugin (a Short from Get-SpecialistPlugins) it is
        /specialists/<plugin>: a three-crumb trail, the tiles over that plugin and its specialists' table. A
        -Plugin the rows do not name returns $null, so the server answers 404 rather than an empty page.
        A plugin not enabled here keeps its card, muted, and its page says what being off means here.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Rows,
        [Parameter(Mandatory = $true)][double]$CharsPerToken,
        [AllowEmptyString()][string]$ReadError = '',
        [AllowEmptyString()][string]$Plugin = ''
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
    $enabled = @($rows | Where-Object { $_.Enabled })
    $listingHere = [int64]0
    foreach ($r in $enabled) { $listingHere += [int64]$r.ListingBytes }
    $max = if ($rows.Count) { [double]$rows[0].TotalBytes } else { 0 }
    $largest = @{ L = 'Largest full read'; V = $(if ($rows.Count) { $rows[0].Name + ' ' + (& $tok $rows[0].TotalBytes) } else { '--' }) }

    $body = New-Object System.Text.StringBuilder
    if ($pick) {
        [void]$body.Append((Format-DevTiles @(
            @{ L = 'Specialists'; V = $rows.Count },
            @{ L = 'Here'; V = $(if ($pick.Enabled) { 'Enabled' } else { 'Off' }) },
            @{ L = $(if ($pick.Enabled) { 'Listing, every session here' } else { 'Listing, if enabled' }); V = (& $tok $pick.ListingBytes) },
            @{ L = 'Full read, all of them'; V = (& $tok $pick.TotalBytes) },
            $largest)))
    } else {
        [void]$body.Append((Format-DevTiles @(
            @{ L = 'Specialists'; V = $rows.Count },
            @{ L = 'Plugins'; V = $plugins.Count },
            @{ L = 'Enabled here'; V = $enabled.Count },
            @{ L = 'Listing, every session here'; V = (& $tok $listingHere) },
            $largest)))
    }
    if ($ReadError) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">The specialists could not all be read: ' + (& $e $ReadError) + '.</p>')
    }

    if (-not $pick) {
        # /specialists: one card per plugin in the hub's card form, its label an h2 and its summary under it, the
        # whole card the link (as /connectors does its owner groups). An off plugin keeps its card, muted.
        [void]$body.AppendLine('<div class="grid-3" id="plugins">')
        [void]$body.AppendLine('<div class="grid__head"><h2>Plugins</h2><p class="card__sub">One card per specialist plugin, the core team first. Open one for its specialists and what each costs</p></div>')
        foreach ($p in $plugins) {
            $sub = @($p.Kind, $(if ($p.Enabled) { 'enabled here' } else { 'off here' }),
                ([string]$p.Rows.Count + ' specialist' + $(if ($p.Rows.Count -ne 1) { 's' } else { '' })),
                ('listing ' + (& $tok $p.ListingBytes)), ('full read ' + (& $tok $p.TotalBytes))) -join ' &middot; '
            [void]$body.AppendLine('<section class="card card--link sp-card' + $(if ($p.Enabled) { '' } else { ' sp-card--off' }) + '" id="plugin-' + (& $e $p.Short) + '">' +
                '<nav class="menu-list" aria-label="' + (& $e $p.Short) + '"><a class="menu-item" href="/specialists/' + (& $e $p.Short) + '">' +
                '<div class="menu-item__label"><h2 class="sp-card-title">' + (& $e $p.Short) + '</h2><span class="menu-item__sub">' + $sub + '</span></div>' +
                $script:RepoHubChevron + '</a></nav></section>')
        }
        if (-not $plugins.Count) {
            [void]$body.AppendLine('<section class="card grid__full"><p class="note">No specialist was found.</p></section>')
        }
        [void]$body.AppendLine('</div>')
    } else {
        if (-not $pick.Enabled) {
            [void]$body.AppendLine('<p class="msg" role="status">Not enabled in this repo''s <code>.claude/settings.json</code>: no session here carries its listing, and its specialists have no lens here.</p>')
        }
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
            [void]$body.AppendLine('<tr><td class="dp-left"><strong>' + $label + '</strong> <span class="note">#' + (& $e $r.Number) +
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
    }
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
    # The card title sits flush in its card (as /connectors' do); an off plugin's card is muted, never hidden.
    $style = $script:DevBarStyle + "`n" + '.sp-card-title { margin: 0; }' + "`n" + '.sp-card--off { opacity: 0.7; }'
    $footer = 'Read from this checkout''s <code>plugins/dkj-subagents/</code> and <code>.claude/specialists/lenses/</code> on every request, so it is the tree, not the installed release. Bytes are measured (hover a cell); tokens are an estimate at ' + $factor + ' characters per token, the factor in <code>scripts/lib/measure-context-lib.ps1</code>.'
    if ($pick) {
        return Format-DevPageHtml -Title $pick.Short -Style $style -Body $body.ToString() -FooterNote $footer `
            -ParentCrumbs @(@{ Label = 'Specialists'; Href = '/specialists' }) `
            -Lead ('The specialists the <code>' + (& $e $pick.Plugin) + '</code> plugin ships, the ' + (& $e $pick.Kind) + ', and how much context each one brings along.')
    }
    return Format-DevPageHtml -Title 'Specialists' -Style $style -Body $body.ToString() -FooterNote $footer `
        -Lead 'Every specialist the dkj-subagents plugins ship, one card per plugin, and how much context each one brings along: what every session pays for it, what it costs when it is called, and what its manual and lens add.'
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
