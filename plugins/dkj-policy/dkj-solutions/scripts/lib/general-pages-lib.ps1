<#
.SYNOPSIS
    The four GENERAL pages every DKJ-Solutions repo's Repo hub links -- Artifacts, Issues, Release notes
    and SessionStart -- and the page shell, formatters and rules behind them (#3119). No I/O: the server
    (scripts/pages/serve-general-pages.ps1) measures and reads, and hands the results in, so every rule
    here is tested without a server.

.DESCRIPTION
    WHY THEY LIVE IN THE PLUGIN. These pages were this source repo's own, built into its dev server. A
    page that is meant to exist in every repo cannot be built into one repo's server, and the repos' own
    servers are not all PowerShell (Vite in dkj-brandbook, Next.js in life-hub). So the plugin ships them
    as a small server of its own, which the dev-preview hook starts beside the repo's own, and each
    repo's hub links to it (#3119, the owner's decision of October 18, 2026: two ports per repo).

    NOTHING HERE IS A REPO'S. Every value that is the repo's -- its name, its issue links, the register
    and the notes it holds -- arrives as a parameter, and the lib depends on no other lib of any repo:
    it has its own HTML escape. The helpers a measurement page needs (the number formats, the tile row,
    the share bar) are here too, because the source repo's own Test gate page reuses them: that repo's
    scripts/lib/dev-pages-lib.ps1 dot-sources this file, so nothing is written twice.

    EVERY VALUE THAT REACHES A PAGE IS ESCAPED, through ConvertTo-GeneralPageText. A link built from
    data is given an href only when its url matches a fixed shape (an Artifact link, a GitHub issue
    link), so a register or a tracker cannot put a script url on a page.

    THE HUB'S "GENERAL" CARD is rendered here too (Format-GeneralPagesCardHtml), because two hubs show
    it: the source repo's own, and the placeholder's. Given the general server's base url it links the
    four pages there; given none it says the server is not running.

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/dev-pages.tests.ps1 in the source repo -- change one, run the other.
#>

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
    <# Seconds as one decimal under a minute, else m:ss -- 7.6 -> '7.6s', 1402 -> '23:22'. #>
    param([AllowNull()]$Seconds)
    if ($null -eq $Seconds) { return '--' }
    $s = [double]$Seconds
    if ($s -lt 60) { return $s.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture) + 's' }
    $whole = [int][Math]::Round($s)
    return ('{0}:{1:00}' -f [int][Math]::Floor($whole / 60), ($whole % 60))
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
        the first crumb, "Repo hub", goes: '/hub' on the general server, which sends the visitor on to the
        repo's own hub -- or, where a hub relays these pages from its own origin, '/hub' on that hub, which
        answers it itself (#3168). -Style is the page's own layer, names the house file does not define. -Lead and
        -FooterNote are markup the caller has escaped.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$Lead,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Body,
        [AllowEmptyString()][string]$Style = '',
        [AllowEmptyString()][string]$FooterNote = '',
        [string]$ThemeKey = 'general-pages',
        [AllowEmptyString()][string]$Eyebrow = '',
        [AllowEmptyString()][string]$SiteName = '',
        [string]$HubHref = '/hub'
    )
    $e = { param($v) ConvertTo-GeneralPageText $v }
    $site = if ($SiteName) { (& $e $SiteName) + ' -- ' } else { '' }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<!doctype html>')
    # The theme key is shared by every page of one server, so a theme picked on one page holds on the next.
    [void]$sb.AppendLine('<html lang="en" data-theme-default="lilac" data-theme-key="' + (& $e $ThemeKey) + '">')
    [void]$sb.AppendLine('<head>')
    [void]$sb.AppendLine('<meta charset="utf-8">')
    [void]$sb.AppendLine('<meta name="viewport" content="width=device-width, initial-scale=1">')
    [void]$sb.AppendLine('<title>' + $site + (& $e $Title) + '</title>')
    [void]$sb.AppendLine('<link rel="stylesheet" href="/house-style.css">')
    [void]$sb.AppendLine('<script src="/house-theme.js"></script>')
    # The page layer: only names the house file does not define (.dp-*).
    [void]$sb.AppendLine('<style>')
    [void]$sb.AppendLine('.dp-link { color: var(--primary-9); text-underline-offset: 2px; }')
    [void]$sb.AppendLine('.dp-thead th { background: var(--primary-3); }')
    [void]$sb.AppendLine('.table td.dp-left, .table th.dp-left { text-align: left; }')
    if ($Style) { [void]$sb.AppendLine($Style) }
    [void]$sb.AppendLine('</style>')
    [void]$sb.AppendLine('</head>')
    [void]$sb.AppendLine('<body>')
    [void]$sb.AppendLine('<div class="breadcrumbs-bar"><div class="container"><nav class="breadcrumbs" aria-label="Breadcrumb"><ol>')
    [void]$sb.AppendLine('<li><a href="' + (& $e $HubHref) + '">Repo hub</a></li>')
    [void]$sb.AppendLine('<li><span class="breadcrumbs__sep" aria-hidden="true">/</span><span aria-current="page">' + (& $e $Title) + '</span></li>')
    [void]$sb.AppendLine('</ol></nav></div></div>')
    [void]$sb.AppendLine('<div id="settings" class="theme-settings--floating"></div>')
    [void]$sb.AppendLine('<main class="page-column">')
    [void]$sb.AppendLine('<div>')
    if ($Eyebrow) { [void]$sb.AppendLine('<p class="eyebrow">' + (& $e $Eyebrow) + '</p>') }
    [void]$sb.AppendLine('<h1>' + (& $e $Title) + '</h1>')
    [void]$sb.AppendLine('<p class="lead">' + $Lead + '</p>')
    [void]$sb.AppendLine('</div>')
    [void]$sb.Append($Body)
    if ($FooterNote) { [void]$sb.AppendLine('<p class="footer-note">' + $FooterNote + '</p>') }
    [void]$sb.AppendLine('</main>')
    [void]$sb.AppendLine('<script>DKJTheme.settings(document.getElementById("settings"), { label: "Settings", title: "Settings", theme: "Theme", reset: "Reset theme", light: "Light", dark: "Dark", width: "Width", fluid: "Fluid", phone: "Phone", full: "Full" });</script>')
    [void]$sb.AppendLine('</body>')
    [void]$sb.AppendLine('</html>')
    return $sb.ToString()
}

# The Pages row's chevron, the brand book's own svg (patterns/repo-dashboard.html at v0.3.0).
$script:RepoHubChevron = '<svg class="menu-item__chevron" viewBox="0 0 24 24" width="20" height="20" aria-hidden="true" focusable="false"><path d="M9 6l6 6-6 6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>'

function Get-GeneralPages {
    <#
        The general pages, in the order the hub lists them: each a route on the general server (Href,
        relative), its Label the page's own name as its breadcrumb reads it, and one line on what it shows.
    #>
    @(
        @{ Href = '/artifacts';     Label = 'Artifacts';     Sub = 'Every claude.ai Artifact published from a session in this repo' },
        @{ Href = '/issues';        Label = 'Issues';        Sub = 'The open GitHub issues and where they stand, and the flow of the last four weeks' },
        @{ Href = '/release-notes'; Label = 'Release notes'; Sub = 'What each released version of the plugins changed' },
        @{ Href = '/sessionstart';  Label = 'SessionStart';  Sub = 'The always-on path every session loads before its first turn' }
    )
}

function Format-GeneralPagesCardHtml {
    <#
        The hub's "General" card, shared by every hub that shows it. -PagesUrl is the general server's base
        url ('http://localhost:4890'), or empty when the hub does not know a server that answers: then the
        card says the server is not running and starts at the next session start. -InRow is $true where the
        card stands beside another on the house .grid-2 (its title an h3, under the row's own h2), and
        $false where it stands alone: then it brings its own .grid-2 with the h2 above the card, because an
        h2 never stands inside a card (#3175). A url that is not a plain loopback base is treated as none,
        so a state file cannot point a hub's links elsewhere. -SameOrigin is for a hub that relays the
        general pages from its own origin (#3168): the card then links each page by its bare path, so the
        visitor stays on the hub's origin and its theme choice.
    #>
    param(
        [AllowEmptyString()][string]$PagesUrl = '',
        [bool]$InRow = $true,
        [object[]]$Pages = @(Get-GeneralPages),
        [switch]$SameOrigin
    )
    $e = { param($v) ConvertTo-GeneralPageText $v }
    $base = ''
    if ($PagesUrl -cmatch '^http://localhost:[0-9]{4,5}/?\z') { $base = $PagesUrl.TrimEnd('/') }
    $linkBase = if ($SameOrigin) { '' } else { $base }
    $headSub = '<p class="card__sub">Not specific to this repo: every DKJ-Solutions repo has them</p>'
    $sb = New-Object System.Text.StringBuilder
    if ($InRow) {
        [void]$sb.AppendLine('<section class="card">')
        [void]$sb.AppendLine('<div class="card__head"><h3>General</h3>' + $headSub + '</div>')
    } else {
        [void]$sb.AppendLine('<div class="grid-2">')
        [void]$sb.AppendLine('<div class="grid__head"><h2>General pages</h2>' + $headSub + '</div>')
        [void]$sb.AppendLine('<section class="card grid__full">')
    }
    if ($base) {
        [void]$sb.AppendLine('<nav class="menu-list" aria-label="General pages">')
        foreach ($p in @($Pages)) {
            $sub = if ($p.Sub) { '<span class="menu-item__sub">' + (& $e $p.Sub) + '</span>' } else { '' }
            [void]$sb.AppendLine('<a class="menu-item" href="' + (& $e ($linkBase + $p.Href)) + '"><span class="menu-item__label">' + (& $e $p.Label) + $sub + '</span>' + $script:RepoHubChevron + '</a>')
        }
        [void]$sb.AppendLine('</nav>')
    } else {
        [void]$sb.AppendLine('<p class="msg" role="status">The general pages server is not running. It starts at the next session start, and these pages are linked here from then on.</p>')
    }
    [void]$sb.AppendLine('</section>')
    if (-not $InRow) { [void]$sb.AppendLine('</div>') }
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

# The share bar every table draws: a track in --primary-3 and a fill in the house highlight.
$script:DevBarStyle = '.dp-bar { display: block; height: 8px; border-radius: 4px; background: var(--primary-3); min-width: 80px; }' + "`n" +
    '.dp-bar > span { display: block; height: 100%; border-radius: 4px; background: var(--primary-9); }'

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

function Select-HighestVersionDir {
    <# The highest of -Names read as versions ('5.22.0' over '5.9.0'); a name that is no version is skipped; '' for none. #>
    param([AllowEmptyCollection()][string[]]$Names = @())
    $best = $null; $bestName = ''
    foreach ($n in @($Names)) {
        $v = $null
        if (-not $n -or -not [version]::TryParse($n, [ref]$v)) { continue }
        if ($null -eq $best -or $v -gt $best) { $best = $v; $bestName = $n }
    }
    return $bestName
}

function Get-DkjPolicyCacheDir {
    <#
        Where dkj-policy's version folders sit when -PluginRoot is the plugin's folder in the plugin cache
        (cache/<marketplace>/<plugin>/<version>): cache/<marketplace>/dkj-policy. In the source layout the
        same derivation names a folder with no version folders in it, which the caller finds out by listing it.
    #>
    param([Parameter(Mandatory = $true)][string]$PluginRoot)
    $plugin = $PluginRoot.TrimEnd('\', '/')
    return Join-Path (Split-Path -Parent (Split-Path -Parent $plugin)) 'dkj-policy'
}

function Get-DkjPolicyScriptCandidates {
    <#
        Where a page may find one of dkj-policy's scripts (-RelativePath, from dkj-policy's root), in the
        order it is tried: the repo's own copy (a repo that carries the workflow); the source layout, where
        the plugin sits in plugins/dkj-policy/<plugin> and dkj-policy's scripts are its sibling; and the
        cache layout, where the plugin is cache/<marketplace>/<plugin>/<version> and dkj-policy is
        cache/<marketplace>/dkj-policy/<version>. -PolicyVersions are the version folder names found under
        the cache's dkj-policy folder (the caller lists them, under Get-DkjPolicyCacheDir; this function
        only picks the highest). A script found this way dot-sources its neighbours from its own folder, so
        they resolve wherever it is found.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$PluginRoot,
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [AllowEmptyCollection()][string[]]$PolicyVersions = @()
    )
    $rel = $RelativePath
    $plugin = $PluginRoot.TrimEnd('\', '/')
    $list = @(
        (Join-Path $RepoRoot $rel),
        (Join-Path (Split-Path -Parent $plugin) $rel)
    )
    $top = Select-HighestVersionDir -Names $PolicyVersions
    if ($top) {
        $list += (Join-Path (Join-Path (Get-DkjPolicyCacheDir -PluginRoot $plugin) $top) $rel)
    }
    return $list
}

function Get-AlwaysOnBudgetLibCandidates {
    <# Where the SessionStart page may find always-on-budget-lib.ps1: Get-DkjPolicyScriptCandidates for that lib. #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$PluginRoot,
        [AllowEmptyCollection()][string[]]$PolicyVersions = @()
    )
    return Get-DkjPolicyScriptCandidates -RepoRoot $RepoRoot -PluginRoot $PluginRoot -RelativePath 'scripts\lib\always-on-budget-lib.ps1' -PolicyVersions $PolicyVersions
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
        leaves in dkj-policy/releases/page/. -HubHref is where the "Repo hub" crumb goes ('/hub' on the
        general server).

        ONLY THIS COPY, NOT THE TEMPLATE. The template is dkj-policy's, shared with every consumer --
        BWJ-Development repos included, which do not take the house style -- and it is deliberately
        self-contained, because a Worker serves it as one string and a request to another origin would leak
        who reads it. So the page is dressed here, on the way out, and the file on disk stays the template's.

        THE ORDER IS THE MECHANISM. The house file goes in AFTER the template's own <style>, so the house
        body (surface, ink, font) wins on equal specificity; then a layer that points the template's own
        tokens at house tokens, so its panel, lines and accent follow whichever theme is picked. Those token
        names are the template's, none of them a house name, so nothing in the house file is redefined.

        A page that is not the template's shape (no <html>, </style>, <body> or </body>) is returned as it
        came: it is still the release notes, and dev-pages.tests.ps1 holds the real template to that shape.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Html,
        [string]$ThemeKey = 'general-pages',
        [string]$HubHref = '/hub'
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
        ':root { --bg: var(--primary-1); --panel: var(--primary-2); --ink: var(--primary-12); --ink-soft: var(--primary-10); --ink-faint: var(--primary-7);'
        '  --line: var(--primary-3); --accent: var(--primary-9); --accent-soft: var(--primary-2); --code-bg: var(--primary-1); }'
        'header.masthead h1 { font-family: var(--font-serif); font-weight: 600; color: var(--primary-9); }'
        '</style>'
    ) -join "`n"
    $bar = @(
        '<div class="breadcrumbs-bar"><div class="container"><nav class="breadcrumbs" aria-label="Breadcrumb"><ol>'
        ('<li><a href="' + (& $e $HubHref) + '">Repo hub</a></li>')
        '<li><span class="breadcrumbs__sep" aria-hidden="true">/</span><span aria-current="page">Release notes</span></li>'
        '</ol></nav></div></div>'
        '<div id="settings" class="theme-settings--floating"></div>'
    ) -join "`n"
    $settings = '<script>DKJTheme.settings(document.getElementById("settings"), { label: "Settings", title: "Settings", theme: "Theme", reset: "Reset theme", light: "Light", dark: "Dark", width: "Width", fluid: "Fluid", phone: "Phone", full: "Full" });</script>'

    # Back to front, so each index still points where it was read.
    $out = $Html.Substring(0, $bodyEnd) + $settings + "`n" + $Html.Substring($bodyEnd)
    $out = $bodyRx.Replace($out, { param($m) $m.Value + "`n" + $bar }, 1)
    $styleEnd = $out.IndexOf('</style>') + '</style>'.Length
    $out = $out.Substring(0, $styleEnd) + "`n" + $head + $out.Substring($styleEnd)
    # The theme key is the server's, so a theme picked on one page holds on this one too, and with no
    # choice stored it falls back to the default every other dev page uses (#3162).
    $out = $htmlRx.Replace($out, ('<html lang="en" data-theme-default="lilac" data-theme-key="' + (& $e $ThemeKey) + '">'), 1)
    return $out
}
