<#
.SYNOPSIS
    The hub's Plugins page (#3482): every plugin enabled in the repo, and whether it is healthy on this machine.

.DESCRIPTION
    ONE READING, NOT TWO. The page reads nothing itself: the server runs plugin-versions.ps1 -Json in a child
    process (the repo's own copy first, then this plugin's, Get-DkjPolicyScriptCandidates) and hands its one
    line in here. So the page and the plugin-versions skill can never disagree about a plugin: the verdict, its
    code and the paste-ready command are that script's.

    WHAT COUNTS AS A PROBLEM is Get-PluginRowStatus: an install behind its clone or missing for this checkout,
    or an install folder gone from disk, is an error; a stale clone, a retired name or a verdict that could not
    be reached is a warning; up to date, or on the released version with unreleased commits in the clone, is
    fine. The overview is a card per plugin, problems first (Format-PluginsPageHtml), and each plugin has its own
    page on /plugins/<name> (Format-PluginPageHtml), routed by Resolve-PluginsPageRequest.

    Read-PluginsPageModel is the one function here that starts a process; the rest has no I/O, so every rule
    is tested without a server (dev-pages.tests.ps1). Every value that reaches the page is escaped. Pure ASCII
    (repo convention for .ps1).
#>

function Read-PluginsPageModel {
    <#
        Runs -Script (plugin-versions.ps1) with -Json -RootOverride -RepoRoot in a child powershell.exe, bounded
        at -TimeoutSeconds, and returns @{ Model; Error }. The child, not this server, because the script
        dot-sources a chain of libs whose functions must not land in a server's scope. It takes under a second.
    #>
    param(
        [AllowEmptyString()][string]$Script = '',
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [int]$TimeoutSeconds = 30
    )
    $empty = ConvertFrom-PluginVersionsJson -Text ''
    if (-not $Script -or -not (Test-Path -LiteralPath $Script -PathType Leaf)) {
        return @{ Model = $empty; Error = 'plugin-versions.ps1 was not found in the repo or in the dkj-policy plugin' }
    }
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = Join-Path $PSHOME 'powershell.exe'
        $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $Script + '" -Json -RootOverride "' + $RepoRoot + '"'
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.WorkingDirectory = $RepoRoot
        $p = [System.Diagnostics.Process]::Start($psi)
        try {
            # Both pipes read at once, so a full one never stalls the child.
            $out = $p.StandardOutput.ReadToEndAsync()
            $err = $p.StandardError.ReadToEndAsync()
            if (-not $p.WaitForExit($TimeoutSeconds * 1000)) {
                try { $p.Kill() } catch { }
                return @{ Model = $empty; Error = "plugin-versions.ps1 did not finish within $TimeoutSeconds s" }
            }
            $p.WaitForExit()
            $model = ConvertFrom-PluginVersionsJson -Text ([string]$out.Result)
            if ($model.Error) {
                $first = @(([string]$err.Result + "`n" + [string]$out.Result) -split "`r?`n" | Where-Object { $_.Trim() }) | Select-Object -First 1
                $why = "plugin-versions.ps1 exited $($p.ExitCode)" + $(if ($first) { ': ' + ($first.Trim() -replace '\s+', ' ') } else { '' })
                return @{ Model = $empty; Error = $why }
            }
            return @{ Model = $model; Error = '' }
        } finally { $p.Dispose() }
    } catch {
        return @{ Model = $empty; Error = (([string]$_.Exception.Message) -replace '\s+', ' ') }
    }
}

function ConvertFrom-PluginVersionsJson {
    <#
        plugin-versions.ps1 -Json's output as the page's model: @{ Plugins; Clones; Consulted; Error }. -Text is the
        child's whole stdout; the LAST line that parses as an object is taken, so a stray line before it is
        harmless. Never throws: what cannot be read is the Error, and Plugins is empty.
    #>
    param([AllowNull()][AllowEmptyString()][string]$Text)
    $model = @{ Plugins = @(); Clones = @(); Consulted = ''; Error = '' }
    $line = @(([string]$Text) -split "`r?`n" | Where-Object { $_.TrimStart().StartsWith('{') }) | Select-Object -Last 1
    if (-not $line) { $model.Error = 'plugin-versions.ps1 returned no JSON'; return $model }
    try { $o = $line | ConvertFrom-Json } catch { $model.Error = 'plugin-versions.ps1 returned JSON that does not parse'; return $model }
    $model.Consulted = [string]$o.Consulted
    $model.Plugins = @(@($o.Plugins) | Where-Object { $_ } | ForEach-Object {
        @{
            Id = [string]$_.Id; Name = [string]$_.Name; Marketplace = [string]$_.Marketplace
            InstVersion = [string]$_.InstVersion; InstSha = [string]$_.InstSha; InstScope = [string]$_.InstScope; InstText = [string]$_.InstText
            InstallPathMissing = [bool]$_.InstallPathMissing
            CloneVer = [string]$_.CloneVer; CloneText = [string]$_.CloneText; Description = [string]$_.Description
            Code = [string]$_.Code; Verdict = [string]$_.Verdict; Action = [string]$_.Action
        }
    })
    $model.Clones = @(@($o.Clones) | Where-Object { $_ } | ForEach-Object {
        @{ Marketplace = [string]$_.Marketplace; Dir = [string]$_.Dir; Exists = [bool]$_.Exists; Head = [string]$_.Head
           HeadDate = [string]$_.HeadDate; FetchTime = [string]$_.FetchTime; IsShallow = [bool]$_.IsShallow; Error = [string]$_.Error }
    })
    return $model
}

function Get-PluginRowStatus {
    <#
        One plugin's state on the page: @{ Level = 'ok' | 'warn' | 'error'; Label }. -Code is plugin-versions'
        verdict code; -InstallPathMissing wins over every code, since a folder gone from disk loads nothing.
    #>
    param([AllowEmptyString()][string]$Code = '', [bool]$InstallPathMissing = $false)
    if ($InstallPathMissing) { return @{ Level = 'error'; Label = 'Install folder missing' } }
    switch ($Code) {
        'match'         { return @{ Level = 'ok'; Label = 'Up to date' } }
        'ver-match'     { return @{ Level = 'ok'; Label = 'Up to date' } }
        'unreleased'    { return @{ Level = 'ok'; Label = 'Up to date' } }
        'behind'        { return @{ Level = 'error'; Label = 'Behind' } }
        'not-installed' { return @{ Level = 'error'; Label = 'Not installed here' } }
        'clone-behind'  { return @{ Level = 'warn'; Label = 'Clone behind' } }
        'retired'       { return @{ Level = 'warn'; Label = 'Retired' } }
        default         { return @{ Level = 'warn'; Label = 'Undetermined' } }
    }
}

function Resolve-PluginsPageRequest {
    <#
        Which Plugins page -Path asks for: @{ Name = ''; Page = '' } for the overview on /plugins, @{ Name = '<plugin>';
        Page = '' } for one plugin's page on /plugins/<plugin>, @{ Name = 'dkj-solutions'; Page = 'house-style' } for
        the house style's specimens under the plugin that ships them (#3493), or $null for a path that is none of
        these. The name is held to a plugin slug, so nothing else reaches a lookup; whether a plugin of that name is
        enabled is the page's question (a 404 when not).
    #>
    param([AllowEmptyString()][string]$Path = '')
    if ($Path -eq '/plugins' -or $Path -eq '/plugins/') { return @{ Name = ''; Page = '' } }
    if ($Path -cmatch '^/plugins/([a-z0-9][a-z0-9-]{0,63})/?$') { return @{ Name = $Matches[1]; Page = '' } }
    if ($Path -cmatch '^/plugins/dkj-solutions/house-style/?$') { return @{ Name = 'dkj-solutions'; Page = 'house-style' } }
    return $null
}

function Find-PluginsPageRow {
    <# The row of -Model whose Name is -Name, with its Status set, or $null. #>
    param([Parameter(Mandatory = $true)][hashtable]$Model, [Parameter(Mandatory = $true)][string]$Name)
    $r = @($Model.Plugins | Where-Object { $_ -and $_.Name -ceq $Name }) | Select-Object -First 1
    if ($r) { $r.Status = Get-PluginRowStatus -Code $r.Code -InstallPathMissing $r.InstallPathMissing }
    return $r
}

function Get-PluginProblemText {
    <# What is wrong with one plugin, in a sentence: the missing folder where that is the case, else the verdict. #>
    param([Parameter(Mandatory = $true)][hashtable]$Row)
    if ($Row.InstallPathMissing) { return 'its install record names a folder that is no longer on disk, so it loads nothing; reinstall it' }
    return $Row.Verdict
}

function ConvertTo-PluginDescriptionHtml {
    <#
        A plugin's description as paragraphs rather than one block (the owner, October 26, 2026): a manifest
        description runs to a dozen sentences and marks its chapters with a lead-in in capitals ("THE HOUSE STYLE:"),
        so each such lead-in becomes an h3 in sentence case ("The house style") over the paragraph it opens. The text is
        escaped first; a lead-in is two or more capital letters, spaces or hyphens before a colon, after a sentence end.
    #>
    param([AllowNull()][AllowEmptyString()][string]$Text)
    $html = ConvertTo-GeneralPageText ([string]$Text)
    $parts = @([regex]::Split($html, '(?<=[.!?])\s+(?=[A-Z][A-Z -]*[A-Z]:)') | Where-Object { $_.Trim() })
    return (@($parts | ForEach-Object {
        $part = $_.Trim()
        if ($part -cmatch '^([A-Z][A-Z -]*[A-Z]):\s*(.*)$') {
            $head = $Matches[1].Substring(0, 1) + $Matches[1].Substring(1).ToLowerInvariant()
            '<h3>' + $head + '</h3>' + $(if ($Matches[2]) { '<p>' + $Matches[2] + '</p>' })
        } else { '<p>' + $part + '</p>' }
    }) -join '')
}

function Format-PluginBadgeHtml {
    <#
        The status badge for -Level: the house .badge is an 18px round icon, so it holds a mark -- a check, a '!' or a
        cross -- and never the label, and it is decorative (aria-hidden); the text beside it says the status (the
        owner, October 25, 2026; the house rule for a badge before a title).
    #>
    param([Parameter(Mandatory = $true)][string]$Level)
    $badge = @{ ok = @('badge--good', '&#10003;'); warn = @('badge--warn', '!'); error = @('badge--bad', '&#10007;') }[$Level]
    return '<span class="badge badge--sm ' + $badge[0] + '" aria-hidden="true">' + $badge[1] + '</span>'
}

function Format-PluginsPageHtml {
    <#
        The Plugins overview, as compact as the Stopwatch's (the owner, October 25, 2026): no tiles, lead or status
        line, only a card per plugin -- its state as a badge, its name as the card's one link to
        its own page (Format-PluginPageHtml), and its installed version or what is wrong. Problems first, then by
        name. Everything else -- the description, the command, the clone -- is on the plugin's page. -Model is
        ConvertFrom-PluginVersionsJson's; -ReadError is set when the script could not be found or run. -RepoName
        names the repo; -HubHref is the Home crumb's target ('/hub' on the general server, '/' on a hub that serves
        the page itself).
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Model,
        [AllowEmptyString()][string]$ReadError = '',
        [AllowEmptyString()][string]$RepoName = '',
        [string]$HubHref = '/hub'
    )
    $e = { param($v) ConvertTo-GeneralPageText $v }
    $rows = @($Model.Plugins | Where-Object { $_ })
    foreach ($r in $rows) { $r.Status = Get-PluginRowStatus -Code $r.Code -InstallPathMissing $r.InstallPathMissing }
    $rank = @{ error = 0; warn = 1; ok = 2 }
    $rows = @($rows | Sort-Object @{ Expression = { $rank[$_.Status.Level] } }, @{ Expression = { $_.Name } })

    # No tile row, no lead and no status line (the owner, October 25, 2026): the cards' badges already say it. A
    # message is drawn only where there are no cards to say anything: a failed read, or no plugin enabled.
    $body = New-Object System.Text.StringBuilder
    if ($ReadError -or $Model.Error) {
        $why = if ($ReadError) { $ReadError } else { $Model.Error }
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">The plugins could not be read: ' + (& $e $why) + '.</p>')
    } elseif (-not $rows.Count) {
        [void]$body.AppendLine('<p class="msg" role="status">No plugin is enabled in this repo. Consulted: ' + (& $e $Model.Consulted) + '.</p>')
    }
    if ($rows.Count) {
        [void]$body.AppendLine('<div class="grid-3" id="plugins">')
        foreach ($r in $rows) {
            # The sub line says the status in words, since the badge is only its mark.
            $sub = (& $e $r.Status.Label) + ': ' + $(if ($r.Status.Level -ne 'ok') { & $e (Get-PluginProblemText $r) }
                   elseif ($r.InstVersion) { (& $e $r.InstVersion) + $(if ($r.InstScope) { ', ' + (& $e $r.InstScope) + ' scope' } else { '' }) }
                   else { & $e $r.InstText })
            [void]$body.AppendLine('<section class="card card--link"><h3 class="card__title">' + (Format-PluginBadgeHtml $r.Status.Level) +
                '<a href="/plugins/' + (& $e $r.Name) + '">' + (& $e $r.Name) + '</a></h3><p class="card__sub">' + $sub + '</p></section>')
        }
        [void]$body.AppendLine('</div>')
    }
    return Format-GeneralPageHtml -Title 'Plugins' -Body $body.ToString() -Eyebrow $RepoName -SiteName $RepoName -HubHref $HubHref `
        -Lead '' `
        -FooterNote 'Read on every request by the plugin-versions skill''s own script, <code>plugin-versions.ps1 -Json</code>: the enable state from the settings files, the install record from <code>~/.claude/plugins/installed_plugins.json</code>, and the marketplace clone under <code>~/.claude/plugins/marketplaces</code>.'
}

function Format-PluginPageHtml {
    <#
        One plugin's page on /plugins/<name>, under the Plugins crumb: its state, what is wrong and the command that
        closes it where plugin-versions names one, its description, and the facts -- installed here, the marketplace
        clone and that clone's HEAD. -Row is Find-PluginsPageRow's; -Model the whole model, for the clone. -Cards are
        the hub's own pages below this plugin, each @{ Href; Label; Sub; Icon }, linked as cards after what the plugin
        ships itself: a hub that builds a page about a plugin hangs it here rather than on its own home page.
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Row,
        [Parameter(Mandatory = $true)][hashtable]$Model,
        [AllowEmptyString()][string]$RepoName = '',
        [string]$HubHref = '/hub',
        [AllowEmptyCollection()][object[]]$Cards = @()
    )
    $e = { param($v) ConvertTo-GeneralPageText $v }
    if (-not $Row.Status) { $Row.Status = Get-PluginRowStatus -Code $Row.Code -InstallPathMissing $Row.InstallPathMissing }
    # The house badge row: the mark, then the status in words (as the Issues page's Done row does), at the far
    # right of the h1's row (the owner, October 26, 2026).
    $badge = '<p class="badge-row">' + (Format-PluginBadgeHtml $Row.Status.Level) + (& $e $Row.Status.Label) + '</p>'
    $body = New-Object System.Text.StringBuilder
    # One screen, side by side (the owner, October 26, 2026; the house density rule): the description and the
    # state of this machine as two cards in one row, rather than a status block and two full-width groups stacked.
    [void]$body.AppendLine('<div class="grid-2">')
    if ($Row.Description) {
        [void]$body.AppendLine('<section class="card dp-about" id="about"><h2>What it is</h2>' + (ConvertTo-PluginDescriptionHtml $Row.Description) + '</section>')
    }
    [void]$body.AppendLine('<section class="card' + $(if (-not $Row.Description) { ' grid__full' }) + '" id="facts"><h2>On this machine</h2>')
    # A healthy plugin gets no verdict line: the badge beside the h1 already says it (the owner, October 26, 2026).
    if ($Row.Status.Level -ne 'ok') {
        [void]$body.AppendLine('<p class="msg msg--warn" role="status">' + (& $e (Get-PluginProblemText $Row)) + '.</p>')
        if ($Row.Action -and -not $Row.InstallPathMissing) { [void]$body.AppendLine('<p class="note">To close it: <code>' + (& $e $Row.Action) + '</code></p>') }
    }
    [void]$body.AppendLine('<dl class="facts">')
    [void]$body.AppendLine('<div><dt>Id</dt><dd><code>' + (& $e $Row.Id) + '</code></dd></div>')
    [void]$body.AppendLine('<div><dt>Installed here</dt><dd>' + (& $e $Row.InstText) + '</dd></div>')
    [void]$body.AppendLine('<div><dt>Marketplace clone</dt><dd>' + (& $e $Row.CloneText) + '</dd></div>')
    $c = @($Model.Clones | Where-Object { $_ -and $_.Marketplace -eq $Row.Marketplace }) | Select-Object -First 1
    if ($c) {
        $bits = if ($c.Exists) { @($(if ($c.HeadDate) { 'committed ' + $c.HeadDate }), $(if ($c.FetchTime) { 'last fetch ' + $c.FetchTime }), $(if ($c.IsShallow) { 'shallow clone' })) } else { @('not present') }
        [void]$body.AppendLine('<div><dt>Clone</dt><dd>' + (& $e ((@($bits) | Where-Object { $_ }) -join ', ')) + '</dd></div>')
    }
    [void]$body.AppendLine('<div><dt>Enabled in</dt><dd>' + $(if ($Model.Consulted) { & $e $Model.Consulted } else { '--' }) + '</dd></div>')
    [void]$body.AppendLine('</dl></section></div>')
    # What a plugin ships that can be looked at: dkj-solutions' house style, its specimens one page below (#3493),
    # then the hub's own pages about this plugin.
    $below = @()
    if ($Row.Name -ceq 'dkj-solutions') {
        $below += @{ Href = '/plugins/dkj-solutions/house-style'; Label = 'House style'; Sub = 'Every token, the twelve themes and every component, with their variants and states'; Icon = 'house-style' }
    }
    $below += @($Cards | Where-Object { $_ })
    if ($below.Count) {
        [void]$body.AppendLine('<div class="grid-3">')
        foreach ($c in $below) { [void]$body.AppendLine((Format-HubCardLinkHtml -Href $c.Href -Label $c.Label -Sub $c.Sub -Icon $c.Icon)) }
        [void]$body.AppendLine('</div>')
    }
    # No lead: the crumbs and the Id fact already say which plugin and marketplace this is (the density rule).
    return Format-GeneralPageHtml -Title ([string]$Row.Name) -Body $body.ToString() -Eyebrow $RepoName -SiteName $RepoName -HubHref $HubHref `
        -ParentCrumbs @(@{ Label = 'Plugins'; Href = '/plugins' }) -HeadAside $badge `
        -Style '.dp-about p { font-size: var(--text-base); }' `
        -Lead '' `
        -FooterNote 'Read on every request by <code>plugin-versions.ps1 -Json</code>, the plugin-versions skill''s own script.'
}

function Format-HouseStyleSpecimensPageHtml {
    <#
        The house style's specimens on /plugins/dkj-solutions/house-style (#3493): every token, theme and component
        of the stylesheet, under the Plugins and dkj-solutions crumbs, because the house style is that plugin's rule
        (its files sit in dkj-policy since #3531) and not any one repo's page. -Body is assets/house-style/specimens.html
        from the same payload as house-style.css (Get-HouseStyleDir), a body fragment trusted as the plugin's own
        markup; -ReadError is why it could not be read, shown, escaped, in its place.
    #>
    param(
        [AllowEmptyString()][string]$Body = '',
        [AllowEmptyString()][string]$ReadError = '',
        [AllowEmptyString()][string]$RepoName = '',
        [string]$HubHref = '/hub'
    )
    $content = if ($ReadError) { '<section class="card"><p class="msg msg--warn" role="status">The specimens could not be read: ' + (ConvertTo-GeneralPageText $ReadError) + '</p></section>' } else { $Body }
    return Format-GeneralPageHtml -Title 'House style' -Body $content -Eyebrow $RepoName -SiteName $RepoName -HubHref $HubHref `
        -ParentCrumbs @(@{ Label = 'Plugins'; Href = '/plugins' }, @{ Label = 'dkj-solutions'; Href = '/plugins/dkj-solutions' }) `
        -Lead 'Every token, the twelve themes and every component of the DKJ-Solutions house style, with their variants and states.' `
        -FooterNote 'The stylesheet and these specimens are <code>assets/house-style/</code> in the dkj-policy plugin this hub runs from.'
}
