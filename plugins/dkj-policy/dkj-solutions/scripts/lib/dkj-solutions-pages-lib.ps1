<#
.SYNOPSIS
    The DKJ-SOLUTIONS pages of each repo's hub (its dev server's home page) -- the Brandbook, and the hub's "DKJ-Solutions" card that links
    it (#3132, #3198). No I/O: the general pages server reads the files and hands their paths or text in, so
    every rule here is tested without a server.

.DESCRIPTION
    WHY THIS IS NOT IN DKJ-POLICY WITH THE REST. The general pages server, which is every repo's hub
    (#3245), and the dev-preview hook live in dkj-policy, which every repo runs (#3198, the owner's decision of October 20,
    2026). The house style belongs to the DKJ-Solutions repos alone, so its page and its card stay in this
    plugin, and a hub shows them only in a repo that enables dkj-solutions (Test-DkjSolutionsEnabled in
    dkj-policy's hub/lib/general-pages-state.ps1 decides that).

    ONE BRAND BOOK, AND IT IS THE brandbook/ APP (#3210). The Brandbook was a PowerShell page of its own here
    (#3132), read from the house-style files, beside the source repo's brandbook/ React app (#3131): two
    renderings of one house style, which drifted apart within a day. The owner chose the app (October 20, 2026):
    the source repo's cut builds it and copies the build into this plugin's assets/brandbook/
    (Get-ReleaseBuilds), and the general server serves that folder under /brandbook/, the base the app is
    built for. So a consumer sees the brand book of the release it runs, and the page is the app's alone.

    THE SOURCE REPO'S OWN HUB DOES NOT SHOW IT. There the brand book is the product, on a port of its own
    (#3283), so its hub neither links nor serves /brandbook (October 22, 2026).

    IT IS LOADED, NOT LOADING. Its callers -- dkj-policy's hub/pages/serve-general-pages.ps1 and
    hub/lib/repo-hub-page.ps1 -- dot-source
    dkj-policy's general-pages-lib.ps1 first, and this file then uses its page shell (Format-GeneralPageHtml,
    Format-GeneralPagesCardHtml, ConvertTo-GeneralPageText and $script:DevBarStyle). It dot-sources nothing
    itself: in the plugin cache this plugin's own folder has no dkj-policy beside it.

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/dev-pages.tests.ps1 in the source repo --
    change one, run the other.
#>
function Get-DkjSolutionsPages {
    <#
        The pages only the DKJ-Solutions repos share, in Get-GeneralPages' shape: served by the same general
        server, listed in a card of their own because a repo of another organisation has none of them.
    #>
    @(
        @{ Href = '/brandbook'; Label = 'Brandbook'; Sub = 'The house style: its tokens, its twelve themes and its components, as the dkj-solutions plugin ships them'; Icon = 'brandbook' }
    )
}

function Format-DkjSolutionsPagesCardHtml {
    <#
        The hub's "DKJ-Solutions" card: Format-GeneralPagesCardHtml with the DKJ-Solutions pages, heading and sub
        line. -LocalPages are DKJ-Solutions pages the calling hub serves itself (the source repo's DKJ repos
        page, #3231); a hub without any passes none and draws the card as it always was. On a repo's home page
        the card stands alone as its Brand book section (#3270), so it is titled 'Brand book'.
    #>
    param([AllowEmptyString()][string]$PagesUrl = '', [bool]$InRow = $true, [switch]$SameOrigin, [object[]]$LocalPages = @())
    $headSub = if (@($LocalPages | Where-Object { $_ }).Count) { 'Shared by every DKJ-Solutions repo, and the pages only this hub has' }
               else { 'Shared by every DKJ-Solutions repo: the house style they are all built from' }
    return Format-GeneralPagesCardHtml -PagesUrl $PagesUrl -InRow $InRow -SameOrigin:$SameOrigin -Pages @(Get-DkjSolutionsPages) `
        -Heading 'DKJ-Solutions' -HeadSub $headSub -LocalPages @($LocalPages) -Title 'Brand book'
}

function Get-BrandbookBuildDir {
    <#
        The brand book's build that ships in this plugin: assets/brandbook/ of the dkj-solutions extension inside
        -PluginRoot, the dkj-policy folder the general server runs from. The source repo's cut writes it
        (#3210); a payload from before that release has no such folder.
    #>
    param([Parameter(Mandatory = $true)][string]$PluginRoot)
    return Join-Path $PluginRoot.TrimEnd('\', '/') 'dkj-solutions\assets\brandbook'
}

function ConvertTo-BrandbookRelPath {
    <#
        The file under the brand book's build that a request for -Path asks for, relative and with forward
        slashes, or $null when the path is not the brand book's or is not safe to join to a directory.
        '/brandbook/' is 'index.html'. The server checks that the file is there; a path without one that names
        no file (no dot in its last segment) is one of the app's own routes, and the server answers it with
        index.html too.

        THE BASE IS /brandbook/, the one vite.config.ts builds the app for, so a link means the same thing on the
        general server, on the source repo's hub and on the dev server. Nothing is decoded: the build's file
        names are plain ASCII, so a '%', a backslash, a colon or a '..' segment is refused rather than read.
    #>
    param([AllowEmptyString()][string]$Path = '')
    if (-not $Path.StartsWith('/brandbook/')) { return $null }
    # A route may end in a slash (/brandbook/dashboards/); a file never does.
    $rel = $Path.Substring('/brandbook/'.Length).TrimEnd('/')
    if ($rel -eq '') { return 'index.html' }
    if ($rel -match '[%\\:]' -or $rel.StartsWith('/') -or @($rel -split '/' | Where-Object { $_ -eq '..' -or $_ -eq '.' -or $_ -eq '' }).Count) { return $null }
    return $rel
}

function Resolve-BrandbookFile {
    <#
        Which file of the build in -BuildDir answers a request for -Path: @{ Rel; File }, or $null when the
        path is not the brand book's or is not safe. A path naming no file (no dot in its last segment) that the
        build does not hold is one of the app's own routes, and its file is index.html. Whether File exists is
        the caller's to check: the build may be missing altogether.
    #>
    param([AllowEmptyString()][string]$Path = '', [Parameter(Mandatory = $true)][string]$BuildDir)
    $rel = ConvertTo-BrandbookRelPath -Path $Path
    if (-not $rel) { return $null }
    $file = Join-Path $BuildDir ($rel -replace '/', '\')
    if (-not (Test-Path -LiteralPath $file -PathType Leaf) -and ($rel -split '/')[-1] -notmatch '\.') {
        $rel = 'index.html'; $file = Join-Path $BuildDir 'index.html'
    }
    return @{ Rel = $rel; File = $file }
}

function Get-BrandbookContentType {
    <# The Content-Type for a file of the brand book's build, by its extension; an unknown one is served as bytes. #>
    param([Parameter(Mandatory = $true)][string]$RelPath)
    switch -Regex ($RelPath) {
        '\.html$' { return 'text/html; charset=utf-8' }
        '\.js$' { return 'text/javascript; charset=utf-8' }
        '\.css$' { return 'text/css; charset=utf-8' }
        '\.svg$' { return 'image/svg+xml' }
        '\.png$' { return 'image/png' }
        '\.(jpg|jpeg)$' { return 'image/jpeg' }
        '\.woff2$' { return 'font/woff2' }
        '\.json$' { return 'application/json; charset=utf-8' }
        default { return 'application/octet-stream' }
    }
}

function Format-BrandbookMissingHtml {
    <#
        The page /brandbook/ answers with on the general server when this plugin carries no build of the brand
        book: a payload from before the release that first shipped it (#3210), or one whose assets/brandbook/
        lost its index.html. -RepoName is the eyebrow and the title, as on the other general pages.
    #>
    param([AllowEmptyString()][string]$RepoName = '')
    $body = '<p class="msg msg--warn" role="alert">This copy of the dkj-solutions plugin ships no build of the brand book. Update the plugins, and it is here.</p>'
    return Format-GeneralPageHtml -Title 'Brandbook' -Style $script:DevBarStyle -Body $body -Eyebrow $RepoName -SiteName $RepoName `
        -Lead 'The DKJ-Solutions brand book: the house style''s tokens, themes and components, as the dkj-solutions plugin ships them.' `
        -FooterNote 'The brand book is the source repo''s <code>brandbook/</code> app, built at every release into the plugin''s <code>assets/brandbook/</code>.'
}
