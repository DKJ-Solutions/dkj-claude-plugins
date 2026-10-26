<#
.SYNOPSIS
    The GENERAL pages every repo's hub links -- Artifacts, Issues, Release notes and SessionStart, and since #3470 Test
    gate, Stopwatch and Logbook, whose pages are test-gate-lib.ps1's, stopwatch-lib.ps1's and logbook-lib.ps1's --
    and the page shell, formatters and rules behind them (#3119). No I/O: the server
    (hub/pages/serve-general-pages.ps1) measures and reads, and hands the results in, so every rule
    here is tested without a server.

.DESCRIPTION
    WHY THEY LIVE IN THE PLUGIN. These pages were this source repo's own, built into its dev server. A
    page that is meant to exist in every repo cannot be built into one repo's server, and the repos' own
    servers are not all PowerShell (Vite in dkj-brandbook, Next.js in life-hub). So the plugin ships them
    as a small server of its own, which the dev-preview hook starts beside the repo's own, and each
    repo's hub links to it (#3119, the owner's decision of October 18, 2026: two ports per repo).

    WHY THE PLUGIN IS DKJ-POLICY (#3198, the owner's decision of October 20, 2026). "General" means what
    every repo has, whichever organisation it belongs to, so these pages ship with the plugin every repo
    runs. They moved here from dkj-solutions, which BWJ-Development never enables. The one DKJ-Solutions
    page, the Brandbook, stayed in that plugin until #3475 (the owner, October 25, 2026) took it off every
    consumer hub: it is the source repo's product, and only that repo's own server shows it.

    THEY RENDER IN THE HOUSE STYLE IN EVERY REPO, BWJ-Development's included. They are this plugin's own
    tooling, not a repo's product, so they keep one look wherever they run; the stylesheet and theme script
    are read from the dkj-solutions folder inside this plugin's own payload (Get-HouseStyleDir), which every
    install of dkj-policy carries whether or not the repo enables dkj-solutions.

    NOTHING HERE IS A REPO'S. Every value that is the repo's -- its name, its issue links, the register
    and the notes it holds -- arrives as a parameter, and the lib depends on no other lib of any repo:
    it has its own HTML escape. The helpers a measurement page needs (the number formats, the tile row,
    the share bar) are here too, because the source repo's own Test gate page reuses them: that repo's
    scripts/lib/dev-pages-lib.ps1 dot-sources this file, so nothing is written twice.

    EVERY VALUE THAT REACHES A PAGE IS ESCAPED, through ConvertTo-GeneralPageText. A link built from
    data is given an href only when its url matches a fixed shape (an Artifact link, a GitHub issue
    link), so a register or a tracker cannot put a script url on a page.

    THE HUB'S CARDS are rendered here too (Format-HubCardLinkHtml), one per page, because every hub draws its
    home page as one grid of card links (#3383). The "General" card that grouped the general pages went with
    its last caller (#3478).

    THE DEFAULT THEME IS THE ONE VALUE THAT ARRIVES BY A SETTER, not a parameter (#3390): every page of the
    server opens in it, so threading it through each formatter would add one parameter to all of them for a
    value that is the same on every page. The server reads it from the hub's state file per request
    (DefaultTheme in the repo's Get-DevPreview) and hands it in with Set-GeneralPagesThemeDefault; where
    nothing is handed in, every page falls back to lilac (#3162).

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/dev-pages.tests.ps1 in the source repo -- change one, run the other.
#>

$script:GeneralPagesThemeDefault = ''

function Set-GeneralPagesThemeDefault {
    <# The theme every page opens in when the visitor has picked none (#3390); '' or $null restores lilac. #>
    param([AllowNull()][AllowEmptyString()][string]$Theme)
    $script:GeneralPagesThemeDefault = [string]$Theme
}

function Get-GeneralPagesThemeDefault {
    <# The theme Set-GeneralPagesThemeDefault handed in, or lilac (#3162) where it handed in nothing. #>
    $t = Get-Variable -Name GeneralPagesThemeDefault -Scope Script -ValueOnly -ErrorAction SilentlyContinue
    if ($t) { return [string]$t }
    return 'lilac'
}

function ConvertTo-GeneralPageText {
    <# HTML-escapes one value for text or a quoted attribute. #>
    param([AllowNull()][AllowEmptyString()]$Value)
    if ($null -eq $Value) { return '' }
    return ([string]$Value).Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;').Replace("'", '&#39;')
}

function Format-DevNumber {
    <# An integer with thousands separators, culture-independent: 58895 -> '58,895'. #>
    param([AllowNull()]$Value)
    if ($null -eq $Value) { return '--' }
    return ([int64]$Value).ToString('N0', [Globalization.CultureInfo]::InvariantCulture)
}

function Format-DevSeconds {
    <# Seconds as one decimal under a minute, m:ss under an hour, else h:mm:ss -- 7.6 -> '7.6s', 1402 -> '23:22', 5927 -> '1:38:47'. #>
    param([AllowNull()]$Seconds)
    if ($null -eq $Seconds) { return '--' }
    $s = [double]$Seconds
    if ($s -lt 60) { return $s.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture) + 's' }
    $whole = [int][Math]::Round($s)
    if ($whole -lt 3600) { return ('{0}:{1:00}' -f [int][Math]::Floor($whole / 60), ($whole % 60)) }
    return ('{0}:{1:00}:{2:00}' -f [int][Math]::Floor($whole / 3600), [int][Math]::Floor(($whole % 3600) / 60), ($whole % 60))
}

function Format-DevDuration {
    <# Hours as hours under two days, else days, one decimal -- 5.25 -> '5.3 h', 60 -> '2.5 d'. #>
    param([AllowNull()]$Hours)
    if ($null -eq $Hours) { return '--' }
    $h = [double]$Hours
    $inv = [Globalization.CultureInfo]::InvariantCulture
    if ($h -lt 48) { return $h.ToString('0.0', $inv) + ' h' }
    return ($h / 24).ToString('0.0', $inv) + ' d'
}

function Format-GeneralPageHtml {
    <#
        The whole page around -Body. -Title is the page's own name: the last crumb, the h1 and the
        <title> (after -SiteName). -Eyebrow is the line over the h1, the repo's name. -HubHref is where
        the first crumb, "Home" (#3270), goes: '/hub' on the general server, which answers it with the home page or, under OwnHub,
        sends the visitor on to the repo's own hub -- or, where a hub relays these pages from its own origin, '/hub' on that hub, which
        answers it itself (#3168). -Style is the page's own layer, names the house file does not define. -Lead and
        -FooterNote are markup the caller has escaped. -Brand opts into the house site header (Format-SiteHeaderHtml):
        the app's name on the primary above the bar, linking -HubHref, with the settings button in it; the eyebrow
        then goes, since the header already names the site. -BrandTag is the word after the name. A page that
        names -SiteName and no -Brand gets the header anyway (ConvertTo-SiteHeaderName), since October 22, 2026. Without it the page is as it always was.
        -Bare (a page's own choice, default off) leaves out the intro above -Body: the h1 and the lead, so the page
        opens on the general banner (the first block of every page, above the h1 where there is one) and then its own content; the crumbs, the site header and the banner stay (the
        banner is on every hub page without exception, #3356), and -Title still names the crumb and the <title>.
        -Lead may then be empty.
        -ParentCrumbs are the crumbs between Home and the page, in order, each @{ Label; Href }: a page nested under
        another (the Stopwatch's run pages) names its parent so the trail reads Home > parent > the page.
        -HeadAside is markup the caller has escaped, set at the far right of the h1's row: the intro is then the house
        page-header row (main > header, a flex row with the title on the left), as a plugin's page does with its state.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Lead,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Body,
        [AllowEmptyString()][string]$Style = '',
        [AllowEmptyString()][string]$FooterNote = '',
        [string]$ThemeKey = 'general-pages',
        [AllowEmptyString()][string]$Eyebrow = '',
        [AllowEmptyString()][string]$SiteName = '',
        [string]$HubHref = '/hub',
        [AllowEmptyString()][string]$Brand = '',
        [AllowEmptyString()][string]$BrandTag = '',
        [switch]$Bare,
        [AllowEmptyCollection()][object[]]$ParentCrumbs = @(),
        [AllowEmptyString()][string]$HeadAside = ''
    )
    # EVERY NAMED PAGE CARRIES THE SITE HEADER (owner, October 22, 2026): a caller that names its site and passes no
    # -Brand gets the repo's short name in it, with 'hub' after it, since these are the hub's pages.
    if (-not $Brand -and $SiteName) { $Brand = ConvertTo-SiteHeaderName -RepoName $SiteName; if (-not $BrandTag) { $BrandTag = 'hub' } }
    $e = { param($v) ConvertTo-GeneralPageText $v }
    $site = if ($SiteName) { (& $e $SiteName) + ' -- ' } else { '' }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<!doctype html>')
    # The theme key is shared by every page of one server, so a theme picked on one page holds on the next.
    # With no width picked yet the pages open full width: a hub is tables and cards, not a reading column.
    [void]$sb.AppendLine('<html lang="en" data-theme-default="' + (& $e (Get-GeneralPagesThemeDefault)) + '" data-width-default="full" data-theme-key="' + (& $e $ThemeKey) + '">')
    [void]$sb.AppendLine('<head>')
    [void]$sb.AppendLine('<meta charset="utf-8">')
    [void]$sb.AppendLine('<meta name="viewport" content="width=device-width, initial-scale=1">')
    [void]$sb.AppendLine('<title>' + $site + (& $e $Title) + '</title>')
    [void]$sb.AppendLine('<link rel="stylesheet" href="/house-style.css">')
    [void]$sb.AppendLine('<script src="/house-theme.js"></script>')
    # The page layer: only names the house file does not define (.dp-*).
    [void]$sb.AppendLine('<style>')
    [void]$sb.AppendLine('.dp-link { color: var(--fg-3); text-decoration: none; text-underline-offset: 2px; }')
    [void]$sb.AppendLine('.dp-link:hover, .dp-link:focus-visible { text-decoration: underline; }')
    [void]$sb.AppendLine('.dp-thead th { background: var(--paper-3); }')
    [void]$sb.AppendLine('.table td.dp-left, .table th.dp-left { text-align: left; }')
    if ($Style) { [void]$sb.AppendLine($Style) }
    [void]$sb.AppendLine('</style>')
    [void]$sb.AppendLine('</head>')
    [void]$sb.AppendLine('<body>')
    # The general banner on every page, not only the home page (#3297), and a bare one too (#3356): ALWAYS the first
    # thing in <body>, above the site header (owner, October 24, 2026).
    [void]$sb.AppendLine((Format-RepoHubBanner))
    if ($Brand) { [void]$sb.Append((Format-SiteHeaderHtml -Name $Brand -Href $HubHref -Tag $BrandTag)) }
    [void]$sb.AppendLine('<div class="breadcrumbs-bar"><div class="container"><nav class="breadcrumbs" aria-label="Breadcrumb"><ol>')
    [void]$sb.AppendLine('<li><a href="' + (& $e $HubHref) + '">Home</a></li>')
    $sep = '<span class="breadcrumbs__sep" aria-hidden="true"><svg viewBox="0 0 24 24"><path fill="currentColor" fill-rule="evenodd" d="M9.793 16.707a1 1 0 0 1 0-1.414L13.086 12 9.793 8.707a1 1 0 0 1 1.414-1.414l4 4a1 1 0 0 1 0 1.414l-4 4a1 1 0 0 1-1.414 0" clip-rule="evenodd"/></svg></span>'
    foreach ($c in @($ParentCrumbs)) { if ($c) { [void]$sb.AppendLine('<li>' + $sep + '<a href="' + (& $e $c.Href) + '">' + (& $e $c.Label) + '</a></li>') } }
    [void]$sb.AppendLine('<li>' + $sep + '<span aria-current="page">' + (& $e $Title) + '</span></li>')
    [void]$sb.AppendLine('</ol></nav></div></div>')
    if (-not $Brand) { [void]$sb.AppendLine('<div id="settings" class="theme-settings--floating"></div>') }
    [void]$sb.AppendLine('<main class="page-column">')
    if (-not $Bare) {
        if ($HeadAside) { [void]$sb.AppendLine('<header>') }
        [void]$sb.AppendLine('<div>')
        if ($Eyebrow -and -not $Brand) { [void]$sb.AppendLine('<p class="eyebrow">' + (& $e $Eyebrow) + '</p>') }
        [void]$sb.AppendLine('<h1>' + (& $e $Title) + '</h1>')
        # An empty -Lead draws no empty paragraph (the Plugins overview, #3482).
        if ($Lead) { [void]$sb.AppendLine('<p class="lead">' + $Lead + '</p>') }
        [void]$sb.AppendLine('</div>')
        if ($HeadAside) { [void]$sb.AppendLine($HeadAside); [void]$sb.AppendLine('</header>') }
    }
    [void]$sb.Append($Body)
    if ($FooterNote) { [void]$sb.AppendLine('<p class="footer-note">' + $FooterNote + '</p>') }
    [void]$sb.AppendLine('</main>')
    [void]$sb.AppendLine('<script>DKJTheme.settings(document.getElementById("settings"), { label: "Settings", title: "Settings", theme: "Theme", reset: "Reset theme", light: "Light", dark: "Dark", width: "Width", fluid: "Fluid", phone: "Phone", full: "Full" });</script>')
    [void]$sb.AppendLine('</body>')
    [void]$sb.AppendLine('</html>')
    return $sb.ToString()
}

function Format-RepoHubBanner {
    <#
        stopwatch test run 2026-10-25 10:27

        The hub's general banner (#3250, Dave, October 21, 2026): a countdown to the next full hour,
        and once an hour has passed a checkbox for the 10 airsquats due, with a short tone when it comes due.
        The countdown keeps running whether or not the box is ticked, and every hour that passes unticked
        adds another 10, so the box shows the total owed; ticking it clears the total.

        ONE FUNCTION, ON EVERY HUB PAGE (#3297): both home pages (through Format-RepoHomeHeadHtml), every page
        Format-GeneralPageHtml draws, a -Bare one included (#3356), the Connectors page (Format-ConnectorDashboardHtml), and the release notes (Format-ReleaseNotesDevPage), so the hubs carry the
        same banner wherever the visitor is. It is the first thing in <body>, ABOVE the site header (owner,
        October 24, 2026; it was the first block of <main>, under the breadcrumb bar), so every caller writes it
        straight after '<body>'. It stands there with no margin, border or radius of its own, a bare strip flush against the
        header (owner, October 24, 2026), and otherwise uses house classes only (.notice, .msg, .num), because
        the hub restyles nothing.

        ONE ROW, ALWAYS (Dave, October 24, 2026): the countdown and the box owed share a single .msg line,
        the box an inline span after the timer rather than a paragraph of its own, and its label is short
        ('30 due') so the line still fits a phone's column.

        THE STATE IS THE SERVER'S, AND EVERY MACHINE'S (#3438, Dave, October 25, 2026). It lived in localStorage
        until then, one count per origin, so two repo hubs on one machine already disagreed. Now the page asks its
        own server, GET /api/airsquats every 15 s and at the turn of the hour, and ticking the box is a POST to
        /api/airsquats/clear; the server answers from one file per machine, which a child merges with a private
        gist every machine shares. The rules are in airsquats-lib.ps1. The countdown is the page's own and needs
        nothing. An hour still counts only where a hub saw it begin, so a night with every hub closed adds nothing,
        and the server says when to play the tone: once per machine, within two minutes of the hour. A page on a
        server without the API (a request that fails) keeps the countdown and shows no box. A browser may hold the
        tone back until the page has had a click, which is its rule, not this page's.

        THE ROW ENDS ON THE ACCOUNT THE HUB RUNS UNDER (#3476): the server's "account", filled in by textContent
        once the first answer arrives. On a machine with several Windows accounts logged on, localhost ports
        are shared between them, so the hub a browser opens may be another account's, and this is where that
        shows. A server that names no account leaves the row as it was.
    #>
    return @'
<div class="notice" id="hub-banner" role="region" aria-label="Airsquats" style="margin: 0; border: 0; border-radius: 0">
<p class="msg">Next airsquats in <strong class="num" data-hub-timer>--:--</strong><span class="msg--warn" data-hub-due hidden> &middot; <label><input type="checkbox" data-hub-done> <span data-hub-count>10</span> due</label></span><span data-hub-owner hidden title="The Windows account this hub runs under"> &middot; <span data-hub-account></span></span></p>
</div>
<script>
(function () {
  var box = document.getElementById("hub-banner");
  if (!box) { return; }
  var API = "/api/airsquats", HOUR = 3600000, POLL = 15000;
  var timer = box.querySelector("[data-hub-timer]"), due = box.querySelector("[data-hub-due]");
  var done = box.querySelector("[data-hub-done]"), count = box.querySelector("[data-hub-count]");
  var owner = box.querySelector("[data-hub-owner]"), account = box.querySelector("[data-hub-account]");
  var asked = 0, hour = Math.floor(Date.now() / HOUR);
  function tone() {
    try {
      var C = window.AudioContext || window.webkitAudioContext, a = new C(), o = a.createOscillator(), g = a.createGain();
      o.frequency.value = 880; g.gain.value = 0.15; o.connect(g); g.connect(a.destination);
      o.start(); o.stop(a.currentTime + 0.4);
    } catch (e) { }
  }
  function show(s) {
    if (!s || typeof s.owed !== "number") { return; }
    if (typeof s.account === "string" && s.account) { account.textContent = s.account; owner.hidden = false; }
    due.hidden = s.owed < 1;
    count.textContent = String((s.per || 10) * s.owed);
    if (s.announce) { tone(); }
  }
  function ask(method, path) {
    if (!window.fetch) { return; }
    fetch(path, { method: method, cache: "no-store", credentials: "same-origin" })
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(show, function () { });
  }
  done.addEventListener("change", function () {
    if (!done.checked) { return; }
    done.checked = false; due.hidden = true; asked = Date.now();
    ask("POST", API + "/clear");
  });
  function step() {
    var now = Date.now(), left = HOUR - (now % HOUR), m = Math.floor(left / 60000), sec = Math.floor(left / 1000) % 60;
    timer.textContent = m + ":" + (sec < 10 ? "0" : "") + sec;
    var h = Math.floor(now / HOUR);
    if (h !== hour || now - asked >= POLL) { hour = h; asked = now; ask("GET", API); }
  }
  step();
  setInterval(step, 1000);
})();
</script>
'@
}

# The Pages row's chevron, the brand book's own svg (patterns/repo-dashboard.html at v0.3.0).
$script:RepoHubChevron = '<svg class="menu-item__chevron" viewBox="0 0 24 24" width="20" height="20" aria-hidden="true" focusable="false"><path d="M9 6l6 6-6 6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>'

# The hub cards' icons: each a line drawing on a 24-unit grid, stroked in the text colour like the chevron. A card
# names one by its key (-Icon on Format-HubCardLinkHtml); the svg wrapper is Get-HubIconSvg's.
$script:HubIcons = @{
    'product'       = '<rect x="3" y="4" width="18" height="12" rx="2"/><path d="M8 20h8M12 16v4"/>'
    'repository'    = '<circle cx="6" cy="6" r="2"/><circle cx="6" cy="18" r="2"/><circle cx="18" cy="8" r="2"/><path d="M6 8v8M18 10v1a5 5 0 0 1-5 5H8"/>'
    'issues'        = '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="1.5"/>'
    'pull-request'  = '<circle cx="6" cy="6" r="2"/><circle cx="6" cy="18" r="2"/><circle cx="18" cy="18" r="2"/><path d="M6 8v8M18 16V9a3 3 0 0 0-3-3h-4M13 4l-2 2 2 2"/>'
    'actions'       = '<path d="M13 3L5 14h6l-1 7 8-11h-6z"/>'
    'artifacts'     = '<path d="M12 3l9 5-9 5-9-5z"/><path d="M3 13l9 5 9-5"/>'
    'release-notes' = '<path d="M3 12V4h8l10 10-8 8z"/><circle cx="7.5" cy="8.5" r="1.5"/>'
    'sessionstart'  = '<circle cx="12" cy="12" r="9"/><path d="M10 8l6 4-6 4z"/>'
    'test-gate'     = '<path d="M12 3l7 3v5c0 4.5-3 8.3-7 10-4-1.7-7-5.5-7-10V6z"/><path d="M9 12l2 2 4-4"/>'
    'stopwatch'     = '<circle cx="12" cy="14" r="7"/><path d="M12 14v-4M10 3h4M12 3v4"/>'
    'logbook'       = '<path d="M5 4h11a3 3 0 0 1 3 3v13H8a3 3 0 0 1-3-3z"/><path d="M5 17a3 3 0 0 1 3-3h11"/>'
    'plugins'       = '<path d="M9 3v4M15 3v4M7 7h10v4a5 5 0 0 1-10 0z"/><path d="M12 16v5"/>'
}

function Get-HubIconSvg {
    <# The hub card icon -Name names, as a .menu-item__icon svg; '' for no name or a name $script:HubIcons lacks. #>
    param([AllowEmptyString()][string]$Name = '')
    if (-not $Name -or -not $script:HubIcons.ContainsKey($Name)) { return '' }
    return '<svg class="menu-item__icon" viewBox="0 0 24 24" width="24" height="24" aria-hidden="true" focusable="false" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' +
        $script:HubIcons[$Name] + '</svg>'
}

function Get-GeneralPages {
    <#
        The general pages, in the order the hub lists them: each a route on the general server (Href,
        relative), its Label the page's own name as its breadcrumb reads it, one line on what it shows, and the
        key of its card's icon ($script:HubIcons).
    #>
    @(
        @{ Href = '/artifacts';     Label = 'Artifacts';     Sub = 'Every claude.ai Artifact published from a session in this repo'; Icon = 'artifacts' },
        @{ Href = '/issues';        Label = 'Issues';        Sub = 'The open GitHub issues and where they stand, and the flow of the last four weeks'; Icon = 'issues' },
        @{ Href = '/release-notes'; Label = 'Release notes'; Sub = 'What each released version of the plugins changed'; Icon = 'release-notes' },
        @{ Href = '/sessionstart';  Label = 'SessionStart';  Sub = 'The always-on path every session loads before its first turn'; Icon = 'sessionstart' },
        # Every repo's since #3470 (the owner, October 25, 2026): the source repo's own pages until then.
        @{ Href = '/test-gate';     Label = 'Test gate';     Sub = 'What each test suite costs on CI'; Icon = 'test-gate' },
        @{ Href = '/stopwatch';     Label = 'Stopwatch';     Sub = 'How long an assignment takes, timed from a stopwatch: prompt to back on the trunk, with the transcript phases'; Icon = 'stopwatch' },
        @{ Href = '/logbook';       Label = 'Logbook';       Sub = 'Every assignment of a clean session, timed by itself: first prompt to back on the trunk, with the transcript phases'; Icon = 'logbook' },
        # #3482: plugin-versions' verdict per enabled plugin, so a problem with one is visible from the hub.
        @{ Href = '/plugins';       Label = 'Plugins';       Sub = 'Every plugin this repo enables, and any problem with one on this machine'; Icon = 'plugins' }
    )
}

function Format-HubCardLinkHtml {
    <#
        One page as a hub card (#3383, the house hub form since the owner's decision of October 24, 2026): a
        .card.card--link holding the page's one .menu-item row, so a click anywhere on the card follows it. -Href,
        -Label and -Sub (optional, one line) are escaped here; -Icon (optional) is a key of $script:HubIcons, drawn
        before the label. The hubs set these cards three to a row, in a .grid-3 with no heading above them.
    #>
    param([Parameter(Mandatory = $true)][string]$Href, [Parameter(Mandatory = $true)][string]$Label, [AllowEmptyString()][string]$Sub = '',
        [AllowEmptyString()][string]$Icon = '')
    $e = { param($v) ConvertTo-GeneralPageText $v }
    $s = if ($Sub) { '<span class="menu-item__sub">' + (& $e $Sub) + '</span>' } else { '' }
    return '<section class="card card--link"><nav class="menu-list" aria-label="' + (& $e $Label) + '"><a class="menu-item" href="' + (& $e $Href) +
        '">' + (Get-HubIconSvg -Name $Icon) + '<span class="menu-item__label">' + (& $e $Label) + $s + '</span>' + $script:RepoHubChevron + '</a></nav></section>'
}

function ConvertTo-SiteHeaderName {
    <# The name a site header shows for -RepoName: a GitHub slug without its 'Owner/' (DKJ-Solutions/x -> x); any other
       name as it is, so a folder name with a slash in it is not cut. #>
    param([AllowEmptyString()][string]$RepoName = '')
    if ($RepoName -cmatch '^[A-Za-z0-9._-]+/([A-Za-z0-9._-]+)\z') { return $Matches[1] }
    return $RepoName
}

function Format-SiteHeaderHtml {
    <#
        The house site header (house-style.css, "Site header"): the app's mark and -Name on the primary, linking -Href
        (home), and the settings button's mount (#settings) on the far right. The mark is a wordmark, the
        organisation's initials, until the app has a logo of its own. -Tag is the quieter word after the name
        ('hub', 'product'), left out when empty. Both are escaped here.
    #>
    param([Parameter(Mandatory = $true)][string]$Name, [string]$Href = '/', [AllowEmptyString()][string]$Tag = '')
    $e = { param($v) ConvertTo-GeneralPageText $v }
    $label = if ($Tag) { "$Name $Tag" } else { $Name }
    $tagHtml = if ($Tag) { ' <span class="site-header__tag">' + (& $e $Tag) + '</span>' } else { '' }
    return '<header class="site-header"><div class="container"><a class="site-header__brand" href="' + (& $e $Href) + '" aria-label="' +
        (& $e $label) + ', home"><span class="site-header__mark" aria-hidden="true">DKJ</span><span class="site-header__name">' + (& $e $Name) +
        $tagHtml + '</span></a><div id="settings"></div></div></header>' + "`n"
}

function Format-RepoHomeHeadHtml {
    <#
        The top of a repo's home page on '/' (#3270), the same in every hub: the breadcrumb bar with its one
        crumb, Home; the settings button; and the opening of <main> with the intro, whose h1 is the repo's
        name (-RepoName, escaped by the caller) and whose lead (-Lead, markup the caller escaped) is what the
        repo is for. No eyebrow: the h1 already names the repo. The general banner (#3250) opens it, above the
        site header. With -Brand the site header stands above the bar and there is no intro: <main> opens on the
        sections. The caller writes the <head> and '<body>' before it and the sections and </main> after it.
    #>
    param([Parameter(Mandatory = $true)][string]$RepoName, [Parameter(Mandatory = $true)][string]$Lead, [AllowEmptyString()][string]$Brand = '',
        [AllowEmptyString()][string]$BrandTag = '')
    $sb = New-Object System.Text.StringBuilder
    # The general banner first, above the site header, as on every hub page (owner, October 24, 2026).
    [void]$sb.AppendLine((Format-RepoHubBanner))
    # -Brand: the house site header above the bar, as Format-GeneralPageHtml draws it, holding the settings button.
    if ($Brand) { [void]$sb.Append((Format-SiteHeaderHtml -Name $Brand -Href '/' -Tag $BrandTag)) }
    [void]$sb.AppendLine('<div class="breadcrumbs-bar"><div class="container"><nav class="breadcrumbs" aria-label="Breadcrumb"><ol>')
    [void]$sb.AppendLine('<li><span aria-current="page">Home</span></li>')
    [void]$sb.AppendLine('</ol></nav></div></div>')
    if (-not $Brand) { [void]$sb.AppendLine('<div id="settings" class="theme-settings--floating"></div>') }
    [void]$sb.AppendLine('<main class="page-column">')
    # Under a site header there is no intro at all (owner, October 22, 2026): the header names the repo, and the
    # page goes straight to its sections. Without one, the intro is a <div>, never a <header>, which the house
    # style lays out as a flex row.
    if (-not $Brand) {
        [void]$sb.AppendLine('<div>')
        [void]$sb.AppendLine('<h1>' + $RepoName + '</h1>')
        [void]$sb.AppendLine('<p class="lead">' + $Lead + '</p>')
        [void]$sb.AppendLine('</div>')
    }
    return $sb.ToString()
}

function Format-DevTiles {
    <# The house tile row: -Tiles is a list of @{ L = label; V = value (already text) }. #>
    param([Parameter(Mandatory = $true)][object[]]$Tiles)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<div class="tiles">')
    foreach ($t in $Tiles) {
        [void]$sb.AppendLine('<div class="tile"><div class="label">' + (ConvertTo-GeneralPageText $t.L) + '</div><div class="v num">' + (ConvertTo-GeneralPageText $t.V) + '</div></div>')
    }
    [void]$sb.AppendLine('</div>')
    return $sb.ToString()
}

# The share bar every table draws: a track in --paper-3 and a fill in the house highlight.
$script:DevBarStyle = '.dp-bar { display: block; height: 8px; border-radius: 4px; background: var(--paper-3); min-width: 80px; }' + "`n" +
    '.dp-bar > span { display: block; height: 100%; border-radius: 4px; background: var(--primary); }'

function Format-DevShareCell {
    <#
        Two cells: a bar, and the share of -Whole as a percentage. The bar is drawn against -BarOf where
        given (the largest row), so a long table of small shares still reads; otherwise against -Whole.
    #>
    param([double]$Part, [double]$Whole, [double]$BarOf = 0)
    $pct = if ($Whole -gt 0) { 100.0 * $Part / $Whole } else { 0 }
    $txt = $pct.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture)
    $scale = if ($BarOf -gt 0) { $BarOf } else { $Whole }
    $bar = if ($scale -gt 0) { 100.0 * $Part / $scale } else { 0 }
    # Double literals: with an int 0 or 100, PowerShell picks Math's int overload and truncates the width.
    $w = [Math]::Min(100.0, [Math]::Max(0.0, $bar)).ToString('0.##', [Globalization.CultureInfo]::InvariantCulture)
    return '<td class="dp-left"><span class="sr-only">' + $txt + '%</span><span class="dp-bar" aria-hidden="true"><span style="width: ' + $w + '%"></span></span></td><td>' + $txt + '%</td>'
}

function ConvertFrom-GitRemoteUrl {
    <#
        'owner/name' from a git remote url on github.com (https, scp-style ssh or ssh://), else ''. Each
        segment is held to letters, digits and ._- so the name is safe on a command line and in a page.
    #>
    param([AllowNull()][AllowEmptyString()][string]$Url)
    if (-not $Url) { return '' }
    $u = $Url.Trim()
    $m = [regex]::Match($u, '^(?:https://(?:[^@/]+@)?github\.com/|git@github\.com:|ssh://git@github\.com/)([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+?)(?:\.git)?/?\z')
    if (-not $m.Success) { return '' }
    $owner = $m.Groups[1].Value; $name = $m.Groups[2].Value
    if ($owner -eq '.' -or $owner -eq '..' -or $name -eq '.' -or $name -eq '..') { return '' }
    return "$owner/$name"
}

function Get-DkjPolicyScriptCandidates {
    <#
        Where a page may find one of dkj-policy's scripts (-RelativePath, from dkj-policy's root), in the
        order it is tried: the repo's own copy (a repo that carries the workflow, the source repo first), then
        the copy in -PluginRoot, the dkj-policy folder this server runs from -- the same release as the
        server, in the source tree and in the plugin cache alike (#3198: before the pages moved into
        dkj-policy this searched the cache for the highest dkj-policy version beside another plugin). A script
        found this way dot-sources its neighbours from its own folder, so they resolve wherever it is found.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$PluginRoot,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )
    return @(
        (Join-Path $RepoRoot $RelativePath),
        (Join-Path $PluginRoot.TrimEnd('\', '/') $RelativePath)
    )
}

function Get-AlwaysOnBudgetLibCandidates {
    <# Where the SessionStart page may find always-on-budget-lib.ps1: Get-DkjPolicyScriptCandidates for that lib. #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$PluginRoot
    )
    return Get-DkjPolicyScriptCandidates -RepoRoot $RepoRoot -PluginRoot $PluginRoot -RelativePath 'scripts\lib\always-on-budget-lib.ps1'
}

function Get-HouseStyleDir {
    <#
        The house style's folder (house-style.css, house-theme.js) the two plugin servers serve: the
        dkj-solutions extension's assets/house-style/ inside -PluginRoot, the dkj-policy folder they run from.
        Every dkj-policy install carries that folder, whether or not the repo enables dkj-solutions, so the
        pages keep one look in every repo (#3198).
    #>
    param([Parameter(Mandatory = $true)][string]$PluginRoot)
    return Join-Path $PluginRoot.TrimEnd('\', '/') 'dkj-solutions\assets\house-style'
}

function Get-ReleaseNotesPageNeed {
    <#
        Whether /release-notes has to build its page first (#3189): 'absent' where there is no page, 'stale'
        where a release document under -ReleasesDir changed after it was built, else ''. The page is a
        gitignored snapshot that nothing else builds -- not a fresh clone, not a second machine, not a cut --
        so the server that links it is the one place that can keep it there and current.

        -PageTime is the page's last write ($null: absent); -NewestInputTime is the newest last write of the
        files under the releases folder outside the page folder ($null: none). That folder holds the history
        and the notes in a repo laid out the way this server reads the page; a file there that is neither
        costs one rebuild of about a second, which is cheaper than knowing the repo's seams here.
    #>
    param(
        [AllowNull()][Nullable[datetime]]$PageTime,
        [AllowNull()][Nullable[datetime]]$NewestInputTime
    )
    if ($null -eq $PageTime) { return 'absent' }
    if ($null -ne $NewestInputTime -and $NewestInputTime -gt $PageTime) { return 'stale' }
    return ''
}

function Get-ReleaseNotesBuiltTime {
    <#
        The -PageTime Get-ReleaseNotesPageNeed takes: the index's last write, or $null where the site is not
        all there. Since every release has a page of its own (owner, October 25, 2026), the builder writes
        them into a folder named after the index -- release-notes\v2.39.0.html beside release-notes.html.
        An index built before that has no such folder, and nothing about the release documents changes when
        the plugin is updated, so without this the old index would be served as current and every card's
        page would be a 404 until the next release.
    #>
    param([Parameter(Mandatory = $true)][string]$IndexFile)
    if (-not (Test-Path -LiteralPath $IndexFile -PathType Leaf)) { return $null }
    if (-not (Test-Path -LiteralPath (Get-ReleaseNotesPageDir -IndexFile $IndexFile) -PathType Container)) { return $null }
    return (Get-Item -LiteralPath $IndexFile).LastWriteTimeUtc
}

function Get-ReleaseNotesPageDir {
    <# The folder holding one page per release: the index's own name, beside it. #>
    param([Parameter(Mandatory = $true)][string]$IndexFile)
    return Join-Path (Split-Path -Parent $IndexFile) ([System.IO.Path]::GetFileNameWithoutExtension($IndexFile))
}

function Resolve-ReleaseNotesRequest {
    <#
        Pure: what a request path asks of the release notes, or $null where it is not theirs.

        '/release-notes' is the index (File = -IndexFile, Version = ''). '/release-notes/v2.39.0' is that
        release's own page, in Get-ReleaseNotesPageDir; 'v2.39' is accepted for it too, because that is how
        the page shows the version. Only a version is ever joined onto a path, so a request cannot name a
        file outside that folder. A trailing slash is ignored.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Path,
        [Parameter(Mandatory = $true)][string]$IndexFile
    )
    $p = if ($Path.Length -gt 1) { $Path.TrimEnd('/') } else { $Path }
    if ($p -eq '/release-notes') { return @{ File = $IndexFile; Version = '' } }
    $m = [regex]::Match($p, '^/release-notes/v(\d+\.\d+)(\.\d+)?$')
    if (-not $m.Success) { return $null }
    $version = $m.Groups[1].Value + $(if ($m.Groups[2].Success) { $m.Groups[2].Value } else { '.0' })
    return @{ File = (Join-Path (Get-ReleaseNotesPageDir -IndexFile $IndexFile) "v$version.html"); Version = $version }
}

function Test-ArtifactUrl {
    <#
        True for a claude.ai Artifact link and nothing else: claude.ai/artifact/<id> or
        claude.ai/code/artifact/<uuid>, over https. The register is data in a public repo and the page
        renders each url as a link, so anything else is never given an href.
    #>
    param([AllowEmptyString()][string]$Url)
    return $Url -cmatch '^https://claude\.ai/(artifact/[A-Za-z0-9]+|code/artifact/[0-9a-f-]+)\z'
}

function ConvertFrom-ArtifactRegister {
    <#
        The Artifacts page model from the parsed scripts/dashboard/artifacts.json (-Register, $null when the
        file is missing or unreadable). Returns @{ Artifacts (list of @{ Title; Url; Kind; Created; Updated;
        About; Linked }, newest first); Date; Method }. A row whose url is not a claude.ai Artifact link is
        kept, with Linked false, so a typo shows on the page instead of a row going missing.
    #>
    param($Register)
    $rows = @()
    if ($Register -and $Register.artifacts) {
        foreach ($a in @($Register.artifacts)) {
            if (-not $a) { continue }
            $url = [string]$a.url
            $rows += @{
                Title   = [string]$a.title
                Url     = $url
                Kind    = [string]$a.kind
                Created = [string]$a.created
                Updated = [string]$a.updated
                About   = [string]$a.about
                Linked  = (Test-ArtifactUrl $url)
            }
        }
    }
    # ISO dates sort as text -- Windows PowerShell 5.1's ConvertFrom-Json leaves them strings, where 7 would
    # make them DateTime, and the server runs under powershell.exe. The title breaks a tie so two of one day keep a stable order.
    $rows = @($rows | Sort-Object @{ Expression = { $_.Created }; Descending = $true }, @{ Expression = { $_.Title } })
    $from = if ($Register) { $Register.recordedFrom } else { $null }
    return @{
        Artifacts = $rows
        Date      = if ($from) { [string]$from.date } else { '' }
        Method    = if ($from) { [string]$from.method } else { '' }
    }
}

function Format-ArtifactsPageHtml {
    <#
        The Artifacts page from ConvertFrom-ArtifactRegister's model. -ReadError is set when the file could
        not be read or is not there. -RepoName is the repo's name, for the eyebrow and the title.
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Model,
        [AllowEmptyString()][string]$ReadError = '',
        [AllowEmptyString()][string]$RepoName = ''
    )
    $e = { param($v) ConvertTo-GeneralPageText $v }
    $rows = @($Model.Artifacts)
    $unlinked = @($rows | Where-Object { -not $_.Linked })
    $kinds = @($rows | ForEach-Object { $_.Kind } | Where-Object { $_ } | Sort-Object -Unique)
    $body = New-Object System.Text.StringBuilder
    [void]$body.Append((Format-DevTiles @(
        @{ L = 'Artifacts'; V = $rows.Count },
        @{ L = 'Kinds'; V = $kinds.Count },
        @{ L = 'Most recent'; V = $(if ($rows.Count -and $rows[0].Created) { $rows[0].Created } else { '--' }) },
        @{ L = 'Without a link'; V = $unlinked.Count })))
    if ($ReadError) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">scripts/dashboard/artifacts.json could not be read: ' + (& $e $ReadError) + '.</p>')
    }
    if ($unlinked.Count) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="status">Not a claude.ai Artifact link, so shown without one: ' +
            (($unlinked | ForEach-Object { '<code>' + (& $e $_.Title) + '</code>' }) -join ', ') + '.</p>')
    }
    [void]$body.AppendLine('<div class="grid-2" id="artifacts">')
    [void]$body.AppendLine('<div class="grid__head"><h2>Artifacts</h2><p class="card__sub">Newest first. Each opens on claude.ai, for an account it is shared with</p></div>')
    [void]$body.AppendLine('<section class="card grid__full">')
    if ($rows.Count) {
        [void]$body.AppendLine('<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">Artifact</th><th class="dp-left">Kind</th><th class="dp-left">Created</th><th class="dp-left">Last published</th></tr></thead><tbody>')
        foreach ($a in $rows) {
            $name = if ($a.Title) { & $e $a.Title } else { '(untitled)' }
            $title = if ($a.Linked) { '<a class="dp-link" href="' + (& $e $a.Url) + '" target="_blank" rel="noopener noreferrer">' + $name + '</a>' } else { $name }
            $about = if ($a.About) { '<p class="note">' + (& $e $a.About) + '</p>' } else { '' }
            $kind = if ($a.Kind) { '<span class="badge badge--sm badge--neutral">' + (& $e $a.Kind) + '</span>' } else { '--' }
            [void]$body.AppendLine('<tr><td class="dp-left">' + $title + $about + '</td><td class="dp-left">' + $kind + '</td><td class="dp-left num">' +
                $(if ($a.Created) { & $e $a.Created } else { '--' }) + '</td><td class="dp-left num">' + $(if ($a.Updated) { & $e $a.Updated } else { '--' }) + '</td></tr>')
        }
        [void]$body.AppendLine('</tbody></table></div>')
    } else {
        [void]$body.AppendLine('<p class="note">No Artifact is recorded.</p>')
    }
    [void]$body.AppendLine('</section>')
    [void]$body.AppendLine('</div>')
    [void]$body.AppendLine('<div class="grid-2" id="recorded">')
    [void]$body.AppendLine('<div class="grid__head"><h2>Where the list comes from</h2></div>')
    [void]$body.AppendLine('<section class="card grid__full">')
    [void]$body.AppendLine('<dl class="facts">')
    [void]$body.AppendLine('<div><dt>Recorded</dt><dd>' + $(if ($Model.Date) { & $e $Model.Date } else { '--' }) + '</dd></div>')
    [void]$body.AppendLine('<div><dt>Method</dt><dd>' + $(if ($Model.Method) { & $e $Model.Method } else { '--' }) + '</dd></div>')
    [void]$body.AppendLine('</dl>')
    [void]$body.AppendLine('</section>')
    [void]$body.AppendLine('</div>')
    return Format-GeneralPageHtml -Title 'Artifacts' -Body $body.ToString() -Eyebrow $RepoName -SiteName $RepoName `
        -Lead 'Every claude.ai Artifact a session in this repo has published: pages, decks and documents. An Artifact is private to the account that made it until it is shared, so a link may not open for everyone.' `
        -FooterNote 'Read from the repo''s <code>scripts/dashboard/artifacts.json</code>, on every request. The register is the repo''s own to keep; where it is absent the page says so.'
}

function ConvertTo-IssueRow {
    <#
        One issue from gh issue list --json (number,title,state,stateReason,labels,assignees,createdAt,closedAt,url)
        as the page reads it: its priority (prio-N, 0 for none), its parking label (awaiting-*), its kind (the
        first of the tracker's type labels it carries), its state on the board -- Parked over Claimed over Free
        -- and its url, which is kept only when it is a GitHub issue link (else empty, and the page gives no href).
    #>
    param([Parameter(Mandatory = $true)]$Issue)
    $labels = @(@($Issue.labels) | Where-Object { $_ } | ForEach-Object { [string]$_.name })
    $assignees = @(@($Issue.assignees) | Where-Object { $_ } | ForEach-Object { [string]$_.login })
    $prio = 0
    foreach ($l in $labels) { if ($l -match '^prio-([1-4])$') { $prio = [int]$Matches[1] } }
    $parked = @($labels | Where-Object { $_ -like 'awaiting-*' } | Select-Object -First 1)
    $kind = 'other'
    foreach ($k in 'bug-inbound', 'feature-inbound', 'bug', 'feature', 'documentation') {
        if ($labels -contains $k) { $kind = $k; break }
    }
    $parse = { param($v) if ($v) { [DateTime]::Parse([string]$v, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AdjustToUniversal -bor [Globalization.DateTimeStyles]::AssumeUniversal) } else { $null } }
    $board = if ($parked.Count) { 'Parked' } elseif ($assignees.Count) { 'Claimed' } else { 'Free' }
    $url = ''
    if ($Issue.PSObject.Properties['url']) {
        $candidate = [string]$Issue.url
        if ($candidate -cmatch '^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/issues/[0-9]+\z') { $url = $candidate }
    }
    return @{
        Number    = [int]$Issue.number
        Title     = [string]$Issue.title
        Url       = $url
        Open      = ([string]$Issue.state -eq 'OPEN')
        Reason    = [string]$Issue.stateReason
        Labels    = $labels
        Assignees = $assignees
        Prio      = $prio
        Parked    = if ($parked.Count) { $parked[0] } else { '' }
        Kind      = $kind
        Board     = $board
        Created   = (& $parse $Issue.createdAt)
        Closed    = (& $parse $Issue.closedAt)
    }
}

function ConvertFrom-IssueList {
    <#
        The Issues page model. -Open is every open issue; -Recent the issues created or closed inside the
        window (the two searches the server makes, so a number may arrive twice and is counted once). -Now
        is the moment the window ends, -Days its length. Returns @{ Open; Opened; Closed; MedianCloseHours;
        Weeks (list of @{ From; To; Opened; Closed }, oldest first); Matrix ('4'..'0' -> @{ Free; Parked;
        Claimed }); ClosedBy (@{ Kind; Prio; Reason }, each a list of @{ Name; Count }, largest first); Days; Now }.
    #>
    param(
        [AllowEmptyCollection()][object[]]$Open = @(),
        [AllowEmptyCollection()][object[]]$Recent = @(),
        [Parameter(Mandatory = $true)][datetime]$Now,
        [ValidateRange(7, 365)][int]$Days = 28
    )
    $now = $Now.ToUniversalTime()
    $start = $now.AddDays(-$Days)
    $byNumber = @{}
    foreach ($i in @(@($Open) + @($Recent))) {
        if (-not $i) { continue }
        $r = ConvertTo-IssueRow $i
        $byNumber[$r.Number] = $r
    }
    $rows = @($byNumber.Values)
    $open = @($rows | Where-Object { $_.Open } | Sort-Object @{ Expression = { $_.Prio }; Descending = $true }, @{ Expression = { $_.Number } })
    # Bounded at -Now on both ends, so the tiles and the weekly rows count the same issues.
    $opened = @($rows | Where-Object { $_.Created -and $_.Created -ge $start -and $_.Created -lt $now })
    $closed = @($rows | Where-Object { -not $_.Open -and $_.Closed -and $_.Closed -ge $start -and $_.Closed -lt $now })

    $hours = @($closed | Where-Object { $_.Created } | ForEach-Object { ($_.Closed - $_.Created).TotalHours } | Sort-Object)
    $median = $null
    if ($hours.Count) {
        $mid = [int][Math]::Floor($hours.Count / 2)
        $median = if ($hours.Count % 2) { [double]$hours[$mid] } else { ([double]$hours[$mid - 1] + [double]$hours[$mid]) / 2 }
    }

    $weeks = @()
    for ($w = [int][Math]::Ceiling($Days / 7) - 1; $w -ge 0; $w--) {
        $to = $now.AddDays(-7 * $w)
        $from = $to.AddDays(-7)
        if ($from -lt $start) { $from = $start }
        $weeks += @{
            From   = $from
            To     = $to
            Opened = @($opened | Where-Object { $_.Created -ge $from -and $_.Created -lt $to }).Count
            Closed = @($closed | Where-Object { $_.Closed -ge $from -and $_.Closed -lt $to }).Count
        }
    }

    $matrix = [ordered]@{}
    foreach ($p in 4, 3, 2, 1, 0) {
        $at = @($open | Where-Object { $_.Prio -eq $p })
        # String keys: an [ordered] dictionary indexed by an int reads by POSITION, not by key.
        $matrix[[string]$p] = @{
            Free    = @($at | Where-Object { $_.Board -eq 'Free' }).Count
            Parked  = @($at | Where-Object { $_.Board -eq 'Parked' }).Count
            Claimed = @($at | Where-Object { $_.Board -eq 'Claimed' }).Count
        }
    }

    $group = { param($items, $key)
        @($items | Group-Object -Property { & $key $_ } | Sort-Object @{ Expression = { $_.Count }; Descending = $true }, @{ Expression = { $_.Name } } |
            ForEach-Object { @{ Name = [string]$_.Name; Count = [int]$_.Count } })
    }
    return @{
        Open             = $open
        Opened           = $opened.Count
        Closed           = $closed.Count
        MedianCloseHours = $median
        Weeks            = $weeks
        Matrix           = $matrix
        ClosedBy         = @{
            Kind   = (& $group $closed { param($r) $r.Kind })
            Prio   = (& $group $closed { param($r) if ($r.Prio) { 'prio-' + $r.Prio } else { 'no priority' } })
            Reason = (& $group $closed { param($r) if ($r.Reason) { $r.Reason.ToLowerInvariant().Replace('_', ' ') } else { 'unknown' } })
        }
        Days             = $Days
        Now              = $now
    }
}

function Format-IssueGroupCard {
    <#
        One card of the closed-in-the-window breakdown: -Groups is a list of @{ Name; Count }. The cards stand
        under one h2 of their own, so each is titled with an h3 (#3175); -Full spans the row.
    #>
    param([string]$Title, [AllowEmptyCollection()][object[]]$Groups, [int]$Total, [switch]$Full)
    $e = { param($v) ConvertTo-GeneralPageText $v }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine($(if ($Full) { '<section class="card grid__full">' } else { '<section class="card">' }))
    [void]$sb.AppendLine('<div class="card__head"><h3 class="card__title">' + (& $e $Title) + '</h3></div>')
    if (@($Groups).Count) {
        $max = [double](@($Groups)[0].Count)
        [void]$sb.AppendLine('<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">' + (& $e $Title) + '</th><th>Issues</th><th class="dp-left">Against the largest</th><th>Share</th></tr></thead><tbody>')
        foreach ($g in @($Groups)) {
            [void]$sb.AppendLine('<tr><td class="dp-left">' + (& $e $g.Name) + '</td><td class="num">' + (Format-DevNumber $g.Count) + '</td>' + (Format-DevShareCell ([double]$g.Count) ([double]$Total) $max) + '</tr>')
        }
        [void]$sb.AppendLine('</tbody></table></div>')
    } else {
        [void]$sb.AppendLine('<p class="note">No issue was closed in the window.</p>')
    }
    [void]$sb.AppendLine('</section>')
    return $sb.ToString()
}

function Format-IssuesPageHtml {
    <#
        The Issues page from ConvertFrom-IssueList's model. -ReadError is set when gh could not be read;
        -GeneratedAt and -Seconds say when and how long the read took; -RepoName is the repo's name. Each
        open issue links to its own url from the model, and to nothing where that was not a GitHub issue link.
    #>
    param(
        $Model,
        [AllowEmptyString()][string]$ReadError = '',
        [AllowEmptyString()][string]$GeneratedAt = '',
        [AllowNull()]$Seconds = $null,
        [AllowEmptyString()][string]$RepoName = ''
    )
    $e = { param($v) ConvertTo-GeneralPageText $v }
    $inv = [Globalization.CultureInfo]::InvariantCulture
    $open = if ($Model) { @($Model.Open) } else { @() }
    $days = if ($Model) { [int]$Model.Days } else { 28 }
    $body = New-Object System.Text.StringBuilder
    [void]$body.Append((Format-DevTiles @(
        @{ L = 'Open now'; V = $(if ($Model) { $open.Count } else { '--' }) },
        @{ L = "Opened, last $days days"; V = $(if ($Model) { Format-DevNumber $Model.Opened } else { '--' }) },
        @{ L = "Closed, last $days days"; V = $(if ($Model) { Format-DevNumber $Model.Closed } else { '--' }) },
        @{ L = 'Median time to close'; V = $(if ($Model) { Format-DevDuration $Model.MedianCloseHours } else { '--' }) })))
    if ($ReadError) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">The issues could not be read from GitHub: ' + (& $e $ReadError) + '.</p>')
    }

    if ($Model) {
        # The open issues: where they stand, then each one.
        [void]$body.AppendLine('<div class="grid-2" id="open">')
        [void]$body.AppendLine('<div class="grid__head"><h2>Open issues</h2><p class="card__sub">Free is work nobody holds, parked waits on an awaiting-* label, claimed has an assignee</p></div>')
        [void]$body.AppendLine('<section class="card grid__full">')
        if ($open.Count) {
            [void]$body.AppendLine('<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">Priority</th><th>Free</th><th>Parked</th><th>Claimed</th><th>Total</th></tr></thead><tbody>')
            foreach ($p in $Model.Matrix.Keys) {
                $m = $Model.Matrix[$p]
                $sum = $m.Free + $m.Parked + $m.Claimed
                if (-not $sum) { continue }
                $name = if ($p -ne '0') { 'prio-' + $p } else { 'no priority' }
                [void]$body.AppendLine('<tr><td class="dp-left">' + $name + '</td><td class="num">' + $m.Free + '</td><td class="num">' + $m.Parked + '</td><td class="num">' + $m.Claimed + '</td><td class="num">' + $sum + '</td></tr>')
            }
            [void]$body.AppendLine('</tbody></table></div>')
            [void]$body.AppendLine('<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">Issue</th><th class="dp-left">Priority</th><th class="dp-left">State</th><th class="dp-left">Kind</th><th>Age</th></tr></thead><tbody>')
            foreach ($i in $open) {
                $tone = switch ($i.Board) { 'Free' { 'good' } 'Parked' { 'warn' } default { 'info' } }
                $state = '<span class="badge badge--sm badge--' + $tone + '">' + $i.Board + '</span>'
                if ($i.Parked) { $state += ' <code>' + (& $e $i.Parked) + '</code>' }
                if ($i.Assignees.Count) { $state += ' ' + (& $e ($i.Assignees -join ', ')) }
                $age = if ($i.Created -and $Model.Now) { Format-DevDuration (($Model.Now - $i.Created).TotalHours) } else { '--' }
                $ref = if ($i.Url) { '<a class="dp-link" href="' + (& $e $i.Url) + '" target="_blank" rel="noopener noreferrer">#' + [int]$i.Number + '</a>' } else { '#' + [int]$i.Number }
                [void]$body.AppendLine('<tr><td class="dp-left">' + $ref + ' ' + (& $e $i.Title) + '</td><td class="dp-left">' +
                    $(if ($i.Prio) { 'prio-' + $i.Prio } else { '--' }) + '</td><td class="dp-left">' + $state + '</td><td class="dp-left">' + (& $e $i.Kind) + '</td><td class="num">' + $age + '</td></tr>')
            }
            [void]$body.AppendLine('</tbody></table></div>')
        } else {
            [void]$body.AppendLine('<p class="msg" role="status">No open issue: everything filed has been closed.</p>')
        }
        [void]$body.AppendLine('</section>')
        [void]$body.AppendLine('</div>')

        # The flow: opened against closed, per week of the window.
        $weeks = @($Model.Weeks)
        $peak = [double](@($weeks | ForEach-Object { $_.Opened; $_.Closed } | Measure-Object -Maximum).Maximum)
        $bar = { param($n) $w = if ($peak -gt 0) { [Math]::Min(100.0, 100.0 * $n / $peak) } else { 0.0 }
            '<span class="dp-bar" aria-hidden="true"><span style="width: ' + $w.ToString('0.##', $inv) + '%"></span></span>' }
        [void]$body.AppendLine('<div class="grid-2" id="flow">')
        [void]$body.AppendLine('<div class="grid__head"><h2>Opened and closed</h2><p class="card__sub">Per week of the last ' + $days + ' days, oldest first</p></div>')
        [void]$body.AppendLine('<section class="card grid__full">')
        [void]$body.AppendLine('<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">Week</th><th>Opened</th><th class="dp-left"></th><th>Closed</th><th class="dp-left"></th><th>Net</th></tr></thead><tbody>')
        foreach ($w in $weeks) {
            $net = $w.Opened - $w.Closed
            $netTxt = if ($net -gt 0) { '+' + $net } else { [string]$net }
            [void]$body.AppendLine('<tr><td class="dp-left num">' + $w.From.ToString('yyyy-MM-dd', $inv) + ' to ' + $w.To.ToString('yyyy-MM-dd', $inv) + '</td><td class="num">' + $w.Opened + '</td><td class="dp-left">' + (& $bar $w.Opened) +
                '</td><td class="num">' + $w.Closed + '</td><td class="dp-left">' + (& $bar $w.Closed) + '</td><td class="num">' + $netTxt + '</td></tr>')
        }
        [void]$body.AppendLine('</tbody></table></div>')
        [void]$body.AppendLine('</section>')
        [void]$body.AppendLine('</div>')

        # What was closed in the window, three ways: three cards under one h2.
        [void]$body.AppendLine('<div class="grid-2" id="closed">')
        [void]$body.AppendLine('<div class="grid__head"><h2>Closed</h2><p class="card__sub">What was closed in the last ' + $days + ' days, three ways</p></div>')
        [void]$body.Append((Format-IssueGroupCard -Title 'Kind' -Groups $Model.ClosedBy.Kind -Total $Model.Closed))
        [void]$body.Append((Format-IssueGroupCard -Title 'Priority' -Groups $Model.ClosedBy.Prio -Total $Model.Closed))
        [void]$body.Append((Format-IssueGroupCard -Title 'Closed as' -Groups $Model.ClosedBy.Reason -Total $Model.Closed -Full))
        [void]$body.AppendLine('</div>')
    }

    $when = if ($GeneratedAt) {
        $secs = if ($null -ne $Seconds) { ' in ' + ([double]$Seconds).ToString('0.0', $inv) + 's' } else { '' }
        ', read ' + (& $e $GeneratedAt) + $secs
    } else { '' }
    $whose = if ($RepoName) { 'The GitHub issues of <code>' + (& $e $RepoName) + '</code>' } else { 'This repo''s GitHub issues' }
    return Format-GeneralPageHtml -Title 'Issues' -Style $script:DevBarStyle -Body $body.ToString() -Eyebrow $RepoName -SiteName $RepoName `
        -Lead ($whose + ': what is open and where it stands, and what came in and went out over the last ' + $days + ' days.') `
        -FooterNote ('Read from GitHub with <code>gh issue list</code>, as the account <code>gh</code> is logged in as on this machine' + $when + ' (<a class="dp-link" href="/refresh?page=issues">read again</a>). The window is bounded because a GitHub search returns at most 1,000 issues.')
}

function ConvertTo-DevInlineText {
    <# Escapes -Value, then renders the two marks a session-start text may carry: **bold** and `code`. #>
    param([AllowNull()][AllowEmptyString()]$Value)
    $t = ConvertTo-GeneralPageText $Value
    $t = [regex]::Replace($t, '`([^`]+)`', '<code>$1</code>')
    return [regex]::Replace($t, '\*\*([^*]+)\*\*', '<strong>$1</strong>')
}

# Each influence of a session-start layer: its badge tone, its mark and its word.
$script:DevInfluence = @{
    direct  = @{ Tone = 'info';    Mark = 'D'; Word = 'Direct' }
    setting = @{ Tone = 'warn';    Mark = 'S'; Word = 'Via a setting' }
    none    = @{ Tone = 'neutral'; Mark = '-'; Word = 'No influence' }
}

function Format-DevInfluence {
    <# The badge row for one influence, or for a done action when -Done. #>
    param([AllowEmptyString()][string]$Influence, [switch]$Done)
    if ($Done) { return '<span class="badge-row"><span class="badge badge--sm badge--good" aria-hidden="true">&#10003;</span>Done</span>' }
    $i = $script:DevInfluence[$Influence]
    if (-not $i) { $i = $script:DevInfluence['none'] }
    return '<span class="badge-row"><span class="badge badge--sm badge--' + $i.Tone + '" aria-hidden="true">' + $i.Mark + '</span>' + $i.Word + '</span>'
}

function Get-SessionStartScore {
    <#
        The efficiency score the session-start artifact shows: the no-influence share of the whole start,
        1-100, with 100 kept for a start that adds nothing. $null without a total.
    #>
    param([double]$None, [double]$Total)
    if ($Total -le 0) { return $null }
    $cap = if ($None -lt $Total) { 99 } else { 100 }
    return [int][Math]::Max(1, [Math]::Min($cap, [Math]::Round(100.0 * $None / $Total, [MidpointRounding]::AwayFromZero)))
}

function Format-SessionStartSnapshotHtml {
    <#
        The last full measurement, from scripts/dashboard/session-start-snapshot.json: the data block of the
        session-start Artifact the measure-session-start skill publishes, copied into the repo. -Snapshot
        is the parsed file, $null when it is missing; -ReadError is set when it could not be read. Its
        always-on documents are left out: the live table above measures them on every request.
    #>
    param($Snapshot, [AllowEmptyString()][string]$ReadError = '')
    $e = { param($v) ConvertTo-GeneralPageText $v }
    $md = { param($v) ConvertTo-DevInlineText $v }
    $sb = New-Object System.Text.StringBuilder
    if ($ReadError) {
        [void]$sb.AppendLine('<p class="msg msg--warn" role="alert">scripts/dashboard/session-start-snapshot.json could not be read: ' + (& $e $ReadError) + '.</p>')
    }
    if (-not $Snapshot) { return $sb.ToString() }

    $items = @(@($Snapshot.items) | Where-Object { $_ })
    $sum = @{ direct = 0.0; setting = 0.0; none = 0.0 }
    foreach ($x in $items) { if ($sum.ContainsKey([string]$x.influence)) { $sum[[string]$x.influence] += [double]$x.tokens } }
    $all = $sum.direct + $sum.setting + $sum.none
    $score = Get-SessionStartScore $sum.none $all
    $prev = $Snapshot.previous
    $prevScore = if ($prev -and $prev.totalTokens) { Get-SessionStartScore ([double]$prev.noneTokens) ([double]$prev.totalTokens) } else { $null }
    $pct = { param($v) if ($all -gt 0) { ' (' + [Math]::Round(100.0 * $v / $all) + '%)' } else { '' } }

    [void]$sb.AppendLine('<div class="grid-2" id="last-measurement">')
    $h = $Snapshot.header
    [void]$sb.AppendLine('<div class="grid__head"><h2>The last full measurement</h2><p class="card__sub">' +
        (& $e $(if ($h) { $h.eyebrow } else { $Snapshot.asOf })) + '</p></div>')
    [void]$sb.AppendLine('<section class="card grid__full">')
    if ($h -and $h.lede) { [void]$sb.AppendLine('<p>' + (& $md $h.lede) + '</p>') }
    $scoreText = if ($null -ne $score) { "$score / 100" + $(if ($null -ne $prevScore -and $prevScore -ne $score) { ' (was ' + $prevScore + ')' } else { '' }) } else { '--' }
    [void]$sb.Append((Format-DevTiles @(
        @{ L = 'Efficiency score'; V = $scoreText },
        @{ L = 'Direct (tokens)'; V = ('~' + (Format-DevNumber $sum.direct) + (& $pct $sum.direct)) },
        @{ L = 'Via a setting (tokens)'; V = ('~' + (Format-DevNumber $sum.setting) + (& $pct $sum.setting)) },
        @{ L = 'No influence (tokens)'; V = ('~' + (Format-DevNumber $sum.none) + (& $pct $sum.none)) })))
    [void]$sb.AppendLine('<p class="note">The score is the share of the start that Claude Code itself brings, against everything this repo and this account add on top. Only a start that adds nothing scores 100.</p>')
    [void]$sb.AppendLine('</section>')
    [void]$sb.AppendLine('</div>')

    [void]$sb.AppendLine('<div class="grid-2" id="layers">')
    [void]$sb.AppendLine('<div class="grid__head"><h2>Every layer, by influence</h2><p class="card__sub">Direct is changed in this repo through a branch and a PR, a setting on the machine or in claude.ai; no influence ships with Claude Code itself</p></div>')
    [void]$sb.AppendLine('<section class="card grid__full">')
    if ($items.Count) {
        $sorted = @($items | Sort-Object @{ Expression = { @('direct', 'setting', 'none').IndexOf([string]$_.influence) } }, @{ Expression = { [double]$_.tokens }; Descending = $true })
        $largest = [double](($items | ForEach-Object { [double]$_.tokens } | Measure-Object -Maximum).Maximum)
        [void]$sb.AppendLine('<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">Layer</th><th class="dp-left">Influence</th><th>Tokens</th><th class="dp-left">Share of the start</th><th>Share</th><th>Change</th><th class="dp-left">How</th></tr></thead><tbody>')
        foreach ($x in $sorted) {
            $tok = [double]$x.tokens
            $delta = if ($null -ne $x.previousTokens -and [double]$x.previousTokens -ne $tok) {
                $d = $tok - [double]$x.previousTokens
                $(if ($d -gt 0) { '+' } else { '-' }) + (Format-DevNumber ([Math]::Abs($d)))
            } else { '' }
            $how = if ($x.measured) { 'measured' } else { 'estimated' }
            [void]$sb.AppendLine('<tr><td class="dp-left">' + (& $e $x.name) + $(if ($x.sub) { '<p class="note">' + (& $e $x.sub) + '</p>' } else { '' }) +
                '</td><td class="dp-left">' + (Format-DevInfluence ([string]$x.influence)) + '</td><td class="num">' + $(if ($x.measured) { '' } else { '~' }) + (Format-DevNumber $tok) + '</td>' +
                (Format-DevShareCell $tok $all $largest) + '<td class="num">' + $delta + '</td><td class="dp-left" title="' + (& $e $x.source) + '">' + $how + '</td></tr>')
        }
        [void]$sb.AppendLine('</tbody></table></div>')
    } else {
        [void]$sb.AppendLine('<p class="note">The snapshot holds no layers.</p>')
    }
    [void]$sb.AppendLine('</section>')
    [void]$sb.AppendLine('</div>')

    $acts = if ($Snapshot.actions -is [array]) { @($Snapshot.actions) } elseif ($Snapshot.actions) { @($Snapshot.actions.items) } else { @() }
    $acts = @($acts | Where-Object { $_ })
    if ($acts.Count) {
        $lede = if ($Snapshot.actions -isnot [array] -and $Snapshot.actions.lede) { $Snapshot.actions.lede } else { 'Ranked by tokens saved per session. Done is already done.' }
        [void]$sb.AppendLine('<div class="grid-2" id="actions">')
        [void]$sb.AppendLine('<div class="grid__head"><h2>What you can do, biggest gain first</h2><p class="card__sub">' + (& $md $lede) + '</p></div>')
        [void]$sb.AppendLine('<section class="card grid__full">')
        [void]$sb.AppendLine('<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th>Gain (tokens)</th><th class="dp-left">Action</th><th class="dp-left">Status</th></tr></thead><tbody>')
        foreach ($a in @(@($acts | Where-Object { -not $_.done }) + @($acts | Where-Object { $_.done }))) {
            $gain = if ($null -ne $a.save) { & $e $a.save } elseif ($null -ne $a.tokens) { '~' + (Format-DevNumber $a.tokens) } else { '--' }
            $what = '<strong>' + (& $md $a.title) + '</strong>'
            foreach ($part in @($a.text, $a.how)) { if ($part) { $what += '<p class="note">' + (& $md $part) + '</p>' } }
            if ($a.caveat) { $what += '<p class="note"><em>Caveat:</em> ' + (& $md $a.caveat) + '</p>' }
            [void]$sb.AppendLine('<tr><td class="num">' + $gain + $(if ($a.saveSub) { '<p class="note">' + (& $e $a.saveSub) + '</p>' } else { '' }) +
                '</td><td class="dp-left">' + $what + '</td><td class="dp-left">' + (Format-DevInfluence ([string]$a.influence) -Done:([bool]$a.done)) + '</td></tr>')
        }
        [void]$sb.AppendLine('</tbody></table></div>')
        [void]$sb.AppendLine('</section>')
        [void]$sb.AppendLine('</div>')
    }

    $none = @(if ($Snapshot.none) { @($Snapshot.none.items) | Where-Object { $_ } })
    if ($none.Count) {
        [void]$sb.AppendLine('<div class="grid-2" id="no-influence">')
        [void]$sb.AppendLine('<div class="grid__head"><h2>What you cannot change</h2><p class="card__sub">Claude Code ships this itself, in every repo</p></div>')
        [void]$sb.AppendLine('<section class="card grid__full">')
        [void]$sb.AppendLine('<dl class="facts">')
        foreach ($n in $none) { [void]$sb.AppendLine('<div><dt>' + (& $e $n.title) + '</dt><dd>' + (& $md $n.text) + '</dd></div>') }
        [void]$sb.AppendLine('</dl>')
        [void]$sb.AppendLine('</section>')
        [void]$sb.AppendLine('</div>')
    }

    $adv = $Snapshot.advice
    if ($adv) {
        [void]$sb.AppendLine('<div class="grid-2" id="advice">')
        [void]$sb.AppendLine('<div class="grid__head"><h2>' + (& $e $(if ($adv.heading) { $adv.heading } else { 'Advice' })) + '</h2><p class="card__sub">Advice</p></div>')
        [void]$sb.AppendLine('<section class="card grid__full">')
        if ($adv.lede) { [void]$sb.AppendLine('<p>' + (& $md $adv.lede) + '</p>') }
        $steps = @(@($adv.steps) | Where-Object { $_ })
        if ($steps.Count) {
            [void]$sb.AppendLine('<ol>')
            foreach ($s in $steps) { [void]$sb.AppendLine('<li><strong>' + (& $md $s.title) + '</strong> ' + (& $md $s.text) + '</li>') }
            [void]$sb.AppendLine('</ol>')
        }
        if ($adv.dont -and $adv.dont.text) {
            [void]$sb.AppendLine('<p class="msg" role="note"><strong>' + (& $e $(if ($adv.dont.label) { $adv.dont.label } else { 'Do not' })) + ':</strong> ' + (& $md $adv.dont.text) + '</p>')
        }
        [void]$sb.AppendLine('</section>')
        [void]$sb.AppendLine('</div>')
    }

    if ($Snapshot.footer) {
        [void]$sb.AppendLine('<div class="grid-2" id="method">')
        [void]$sb.AppendLine('<div class="grid__head"><h2>How it was measured</h2></div>')
        [void]$sb.AppendLine('<section class="card grid__full">')
        [void]$sb.AppendLine('<p class="note">' + (& $md $Snapshot.footer) + '</p>')
        $src = $Snapshot.source
        if ($src -and (Test-ArtifactUrl ([string]$src.artifact))) {
            [void]$sb.AppendLine('<p class="note">Copied from the Artifact <a class="dp-link" href="' + (& $e $src.artifact) + '" target="_blank" rel="noopener noreferrer">' +
                (& $e $src.title) + '</a>' + $(if ($src.copied) { ' on ' + (& $e $src.copied) } else { '' }) + '.</p>')
        }
        [void]$sb.AppendLine('</section>')
        [void]$sb.AppendLine('</div>')
    }
    return $sb.ToString()
}

function Format-SessionStartPageHtml {
    <#
        The SessionStart page. -Model is @{ Total; DiskBytes; Tokens; Budget; State; Ok; Documents (list of
        @{ Display; Bytes; Source = 'measured'|'carried'|'unmeasured' }); GeneratedAt; Seconds }, or
        $null with -ReadError when the measurement failed. -RepoName is the repo's name. -Snapshot and
        -SnapshotError are Format-SessionStartSnapshotHtml's: the repo's last full session-start measurement
        (scripts/dashboard/session-start-snapshot.json, where it has one), rendered below the live table.
    #>
    param(
        $Model,
        [AllowEmptyString()][string]$ReadError = '',
        [AllowEmptyString()][string]$RepoName = '',
        $Snapshot = $null,
        [AllowEmptyString()][string]$SnapshotError = ''
    )
    $e = { param($v) ConvertTo-GeneralPageText $v }
    $docs = if ($Model) { @($Model.Documents | Where-Object { $_ } | Sort-Object @{ Expression = { [int64]$_.Bytes }; Descending = $true }) } else { @() }
    $total = if ($Model) { [int64]$Model.Total } else { $null }
    $budget = if ($Model) { [int64]$Model.Budget } else { $null }
    $room = if ($Model) { $budget - $total } else { $null }
    $body = New-Object System.Text.StringBuilder
    [void]$body.Append((Format-DevTiles @(
        @{ L = 'Always-on path (B)'; V = (Format-DevNumber $total) },
        @{ L = 'Estimated tokens'; V = $(if ($Model) { '~' + (Format-DevNumber $Model.Tokens) } else { '--' }) },
        @{ L = 'Budget (B)'; V = (Format-DevNumber $budget) },
        @{ L = $(if ($null -ne $room -and $room -lt 0) { 'Over the budget (B)' } else { 'Headroom (B)' }); V = $(if ($null -ne $room) { Format-DevNumber ([Math]::Abs($room)) } else { '--' }) })))
    if ($ReadError) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">The always-on path could not be measured: ' + (& $e $ReadError) + '.</p>')
    } elseif ($Model -and -not $Model.Ok) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">The always-on path is over its limit (' + (& $e $Model.State) + '): every session pays it, and the gate refuses a branch that grows it.</p>')
    }
    $unmeasured = @($docs | Where-Object { $_.Source -eq 'unmeasured' })
    if ($unmeasured.Count) {
        [void]$body.AppendLine('<p class="msg" role="status">Not counted, because neither this machine nor the baseline has a size for it: ' +
            (($unmeasured | ForEach-Object { '<code>' + (& $e $_.Display) + '</code>' }) -join ', ') + '.</p>')
    }
    [void]$body.AppendLine('<div class="grid-2" id="documents">')
    [void]$body.AppendLine('<div class="grid__head"><h2>Always-on documents</h2><p class="card__sub"><code>CLAUDE.md</code> and every file it imports, largest first</p></div>')
    [void]$body.AppendLine('<section class="card grid__full">')
    $counted = @($docs | Where-Object { $_.Source -ne 'unmeasured' })
    if ($counted.Count) {
        [void]$body.AppendLine('<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">Document</th><th>Bytes</th><th class="dp-left">Share of the path</th><th>Share</th><th class="dp-left">Measured</th></tr></thead><tbody>')
        foreach ($d in $counted) {
            $src = if ($d.Source -eq 'carried') { 'from the baseline' } else { 'on this machine' }
            [void]$body.AppendLine('<tr><td class="dp-left"><code>' + (& $e $d.Display) + '</code></td><td class="num">' + (Format-DevNumber $d.Bytes) + '</td>' +
                (Format-DevShareCell ([double]$d.Bytes) ([double]$total)) + '<td class="dp-left">' + $src + '</td></tr>')
        }
        [void]$body.AppendLine('</tbody></table></div>')
    } else {
        [void]$body.AppendLine('<p class="note">No always-on document was measured.</p>')
    }
    [void]$body.AppendLine('</section>')
    [void]$body.AppendLine('</div>')
    [void]$body.Append((Format-SessionStartSnapshotHtml -Snapshot $Snapshot -ReadError $SnapshotError))
    $when = if ($Model -and $Model.GeneratedAt) {
        $secs = if ($null -ne $Model.Seconds) { ' in ' + ([double]$Model.Seconds).ToString('0.0', [Globalization.CultureInfo]::InvariantCulture) + 's' } else { '' }
        ', measured ' + (& $e $Model.GeneratedAt) + $secs
    } else { '' }
    $whose = if ($RepoName) { 'every session in <code>' + (& $e $RepoName) + '</code>' } else { 'every session in this repo' }
    return Format-GeneralPageHtml -Title 'SessionStart' -Style $script:DevBarStyle -Body $body.ToString() -Eyebrow $RepoName -SiteName $RepoName `
        -Lead ('What ' + $whose + ' loads before its first turn: the always-on document path that <code>always-on-sessioncheck</code> reports at session start, against the budget the gate holds it to. Below it, where the repo keeps one, the last full measurement of everything else a session loads, with what can be done about it.') `
        -FooterNote ('Measured by <code>always-on-budget-lib.ps1</code>, in LF bytes, the unit the gate judges' + $when + ' (<a class="dp-link" href="/refresh?page=sessionstart">measure again</a>).')
}

function Format-ReleaseNotesDevPage {
    <#
        The built release-notes page (#3108), as a dev server serves it: the house stylesheet and theme
        script, the breadcrumb bar and the settings button, put around the page build-release-notes-page.ps1
        leaves in dkj-policy/releases/page/. -HubHref is where the "Home" crumb goes ('/hub' on the
        general server). -RepoName puts the site header above the bar (October 22, 2026).

        ONLY THIS COPY, NOT THE TEMPLATE. The template is dkj-policy's, shared with every consumer --
        BWJ-Development repos included, which do not take the house style -- and it is deliberately
        self-contained, because a Worker serves it as one string and a request to another origin would leak
        who reads it. So the page is dressed here, on the way out, and the file on disk stays the template's.

        THE ORDER IS THE MECHANISM. The house file goes in AFTER the template's own <style>, so the house
        body (surface, ink, font) wins on equal specificity; then a layer that points the template's own
        tokens at house tokens, so its panel, lines and accent follow whichever theme is picked. Those token
        names are the template's, none of them a house name, so nothing in the house file is redefined.
        The same layer gives the template's column, masthead, sheet and colophon the Stopwatch page's
        measures (owner, October 25, 2026): the page column's width, padding and gap, the house h1, a
        .card's border and radius, and a .footer-note's ink. Its width rules keep winning on specificity.

        A page that is not the template's shape (no <html>, </style>, <body> or </body>) is returned as it
        came: it is still the release notes, and dev-pages.tests.ps1 holds the real template to that shape.

        A RELEASE'S OWN PAGE (owner, October 25, 2026) takes -Release: the crumbs then read
        Home > Release notes > Version 2.39 -- the last one read off the page's own h1, which the builder
        has already escaped -- with 'Release notes' a link, and the page's own '<- All releases' link is
        taken out because that crumb already is the way back.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Html,
        [string]$ThemeKey = 'general-pages',
        [string]$HubHref = '/hub',
        [AllowEmptyString()][string]$RepoName = '',
        [switch]$Release
    )
    $htmlRx = [regex]'<html\b[^>]*>'
    $styleEnd = $Html.IndexOf('</style>')
    $bodyRx = [regex]'<body\b[^>]*>'
    $bodyEnd = $Html.LastIndexOf('</body>')
    if (-not $htmlRx.IsMatch($Html) -or $styleEnd -lt 0 -or -not $bodyRx.IsMatch($Html) -or $bodyEnd -lt 0) { return $Html }

    $e = { param($v) ConvertTo-GeneralPageText $v }
    $head = @(
        '<link rel="stylesheet" href="/house-style.css">'
        '<script src="/house-theme.js"></script>'
        '<style>'
        '/* The template''s tokens, read from the house ones (#3108). */'
        ':root { --bg: var(--paper-1); --panel: var(--paper-2); --ink: var(--fg-1); --ink-soft: var(--fg-2); --ink-faint: var(--muted);'
        '  --line: var(--paper-3); --accent: var(--primary); --accent-soft: var(--paper-2); --code-bg: var(--paper-1); }'
        '/* The template''s layout, read as the Stopwatch page''s: main.page-column, a house h1, a .card, a .footer-note. */'
        '.wrap { max-width: 1080px; display: grid; gap: var(--spacing-5); align-content: start; padding: var(--spacing-4) var(--spacing-4) var(--spacing-12); }'
        'header.masthead { padding: 0; }'
        'header.masthead h1 { font-family: inherit; font-size: var(--text-h1); font-weight: 700; letter-spacing: -0.01em; line-height: normal; text-transform: none; color: var(--primary); }'
        'header.masthead p { margin: var(--spacing-1) 0 0; color: var(--muted); font-size: var(--text-sm); }'
        '.sheet { border: 1px solid var(--paper-3); border-radius: 12px; padding: var(--spacing-2) var(--spacing-6) var(--spacing-4); }'
        '.noscript { margin: 0; }'
        '/* The release cards carry no icon, so they take a tighter padding than the house .card the hub''s icon cards keep (owner, October 25, 2026); the grid''s gap is their spacing. */'
        '.cards > .card { padding: var(--spacing-3) var(--spacing-4); margin-top: 0; }'
        'footer.colophon { margin: 0; padding: 0; border: 0; color: var(--muted); font-size: var(--text-sm); }'
        'footer.colophon p { margin: 0; max-width: none; }'
        'footer.colophon p + p { margin-top: var(--spacing-1); }'
        '@media (max-width: 38rem) { .wrap { padding: var(--spacing-4) var(--spacing-4) var(--spacing-12); } header.masthead { padding-top: 0; } header.masthead h1 { font-size: var(--text-h1); } .sheet { padding: var(--spacing-1) var(--spacing-4) var(--spacing-3); border-radius: 12px; } }'
        '</style>'
    ) -join "`n"
    $sep = '<span class="breadcrumbs__sep" aria-hidden="true"><svg viewBox="0 0 24 24"><path fill="currentColor" fill-rule="evenodd" d="M9.793 16.707a1 1 0 0 1 0-1.414L13.086 12 9.793 8.707a1 1 0 0 1 1.414-1.414l4 4a1 1 0 0 1 0 1.414l-4 4a1 1 0 0 1-1.414 0" clip-rule="evenodd"/></svg></span>'
    $crumbs = if ($Release) {
        # Only a label of the builder's own shape is placed, so the crumb never depends on what else an h1 might hold.
        $label = ([regex]'<h1>([^<]*)</h1>').Match($Html).Groups[1].Value
        if ($label -notmatch '^Version [0-9.]+$') { $label = 'Release' }
        @(('<li>' + $sep + '<a href="/release-notes">Release notes</a></li>'), ('<li>' + $sep + '<span aria-current="page">' + $label + '</span></li>'))
    } else {
        @('<li>' + $sep + '<span aria-current="page">Release notes</span></li>')
    }
    $bar = @(
        '<div class="breadcrumbs-bar"><div class="container"><nav class="breadcrumbs" aria-label="Breadcrumb"><ol>'
        ('<li><a href="' + (& $e $HubHref) + '">Home</a></li>')
        $crumbs
        '</ol></nav></div></div>'
    ) -join "`n"
    if ($Release) { $Html = ([regex]'<a class="back" href="[^"]*">[^<]*</a>\s*').Replace($Html, '', 1) }
    # The site header above the bar, holding the settings button, when the repo is named; else the button floats.
    $bar = if ($RepoName) { (Format-SiteHeaderHtml -Name (ConvertTo-SiteHeaderName -RepoName $RepoName) -Href $HubHref -Tag 'hub') + $bar }
            else { $bar + "`n" + '<div id="settings" class="theme-settings--floating"></div>' }
    # Under that header the masthead opens with its h1 (#3423): the house page pattern has no eyebrow under a
    # site header, which already names the site. Only here -- the Worker's page has no header, and there the
    # eyebrow is the one line naming whose releases these are.
    if ($RepoName) { $Html = ([regex]'<span class="eyebrow">[^<]*</span>\s*').Replace($Html, '', 1) }
    $bodyEnd = $Html.LastIndexOf('</body>')
    # The general banner above the site header, as on every other hub page (#3297; owner, October 24, 2026). It
    # stands outside the template's layout, so that is left alone.
    $bar = (Format-RepoHubBanner) + $bar
    $settings = '<script>DKJTheme.settings(document.getElementById("settings"), { label: "Settings", title: "Settings", theme: "Theme", reset: "Reset theme", light: "Light", dark: "Dark", width: "Width", fluid: "Fluid", phone: "Phone", full: "Full" });</script>'

    # Back to front, so each index still points where it was read.
    $out = $Html.Substring(0, $bodyEnd) + $settings + "`n" + $Html.Substring($bodyEnd)
    $out = $bodyRx.Replace($out, { param($m) $m.Value + "`n" + $bar }, 1)
    $styleEnd = $out.IndexOf('</style>') + '</style>'.Length
    $out = $out.Substring(0, $styleEnd) + "`n" + $head + $out.Substring($styleEnd)
    # The theme key is the server's, so a theme picked on one page holds on this one too, and with no
    # choice stored it falls back to the defaults every other dev page uses: the repo's stated theme or lilac
    # (#3162, #3390) and full width.
    $out = $htmlRx.Replace($out, ('<html lang="en" data-theme-default="' + (& $e (Get-GeneralPagesThemeDefault)) + '" data-width-default="full" data-theme-key="' + (& $e $ThemeKey) + '">'), 1)
    return $out
}
