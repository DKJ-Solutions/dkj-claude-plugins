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
    fine. The page leads with the problems, then lists every plugin.

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

function Format-PluginsPageHtml {
    <#
        The Plugins page. -Model is ConvertFrom-PluginVersionsJson's; -ReadError is set when the script could
        not be found or run (then the model is empty and the page says why). -RepoName names the repo;
        -HubHref is the Home crumb's target ('/hub' on the general server, '/' on a hub that serves the page itself).
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Model,
        [AllowEmptyString()][string]$ReadError = '',
        [AllowEmptyString()][string]$RepoName = '',
        [string]$HubHref = '/hub'
    )
    $e = { param($v) ConvertTo-GeneralPageText $v }
    $rows = @($Model.Plugins | Where-Object { $_ } | Sort-Object { $_.Id })
    foreach ($r in $rows) { $r.Status = Get-PluginRowStatus -Code $r.Code -InstallPathMissing $r.InstallPathMissing }
    $errors = @($rows | Where-Object { $_.Status.Level -eq 'error' })
    $warns = @($rows | Where-Object { $_.Status.Level -eq 'warn' })
    $versions = @($rows | ForEach-Object { $_.InstVersion } | Where-Object { $_ } | Sort-Object -Unique)
    $badge = @{ ok = 'badge--good'; warn = 'badge--warn'; error = 'badge--bad' }

    $body = New-Object System.Text.StringBuilder
    [void]$body.Append((Format-DevTiles @(
        @{ L = 'Enabled here'; V = $rows.Count },
        @{ L = 'Errors'; V = $errors.Count },
        @{ L = 'Warnings'; V = $warns.Count },
        @{ L = 'Installed version'; V = $(if ($versions.Count -eq 1) { $versions[0] } elseif ($versions.Count) { "$($versions.Count) different" } else { '--' }) })))
    $readFailed = [bool]($ReadError -or $Model.Error)
    if ($readFailed) {
        $why = if ($ReadError) { $ReadError } else { $Model.Error }
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">The plugins could not be read: ' + (& $e $why) + '.</p>')
    } elseif (-not $rows.Count) {
        [void]$body.AppendLine('<p class="msg" role="status">No plugin is enabled in this repo. Consulted: ' + (& $e $Model.Consulted) + '.</p>')
    } elseif ($errors.Count -or $warns.Count) {
        # The problems first, each with the one command that closes it where plugin-versions names one.
        [void]$body.AppendLine('<div class="grid-2" id="problems">')
        [void]$body.AppendLine('<div class="grid__head"><h2>Problems</h2><p class="card__sub">Errors first. The command is the one plugin-versions hands over</p></div>')
        foreach ($r in @($errors) + @($warns)) {
            $level = if ($r.Status.Level -eq 'error') { 'msg--warn' } else { '' }
            $what = if ($r.InstallPathMissing) { 'its install record names a folder that is no longer on disk, so it loads nothing; reinstall it' } else { $r.Verdict }
            [void]$body.AppendLine('<section class="card grid__full"><p class="msg ' + $level + '" role="status"><span class="badge badge--sm ' + $badge[$r.Status.Level] + '">' + (& $e $r.Status.Label) + '</span> <strong>' + (& $e $r.Id) + '</strong>: ' + (& $e $what) + '</p>' +
                $(if ($r.Action -and -not $r.InstallPathMissing) { '<p class="note"><code>' + (& $e $r.Action) + '</code></p>' } else { '' }) + '</section>')
        }
        [void]$body.AppendLine('</div>')
    } else {
        [void]$body.AppendLine('<p class="msg" role="status">Every plugin enabled here is installed and up to date on this machine.</p>')
    }

    if ($rows.Count) {
        [void]$body.AppendLine('<div class="grid-2" id="plugins">')
        [void]$body.AppendLine('<div class="grid__head"><h2>Plugins</h2><p class="card__sub">Every plugin this repo enables, with the version installed for this checkout and the one the marketplace clone holds</p></div>')
        [void]$body.AppendLine('<section class="card grid__full">')
        [void]$body.AppendLine('<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">Plugin</th><th class="dp-left">State</th><th class="dp-left">Installed here</th><th class="dp-left">Marketplace clone</th></tr></thead><tbody>')
        foreach ($r in $rows) {
            $about = if ($r.Description) { '<p class="note">' + (& $e $r.Description) + '</p>' } else { '' }
            $inst = if ($r.InstVersion) { (& $e $r.InstVersion) + $(if ($r.InstScope) { ' <span class="badge badge--sm badge--neutral">' + (& $e $r.InstScope) + '</span>' } else { '' }) } else { & $e $r.InstText }
            $clone = if ($r.CloneVer) { & $e $r.CloneVer } else { & $e $r.CloneText }
            [void]$body.AppendLine('<tr><td class="dp-left"><strong>' + (& $e $r.Name) + '</strong> <span class="note">@' + (& $e $r.Marketplace) + '</span>' + $about + '</td>' +
                '<td class="dp-left"><span class="badge badge--sm ' + $badge[$r.Status.Level] + '">' + (& $e $r.Status.Label) + '</span><p class="note">' + (& $e $r.Verdict) + '</p></td>' +
                '<td class="dp-left num">' + $inst + '</td><td class="dp-left num">' + $clone + '</td></tr>')
        }
        [void]$body.AppendLine('</tbody></table></div>')
        [void]$body.AppendLine('</section>')
        [void]$body.AppendLine('</div>')
    }

    if (-not $readFailed) {
        [void]$body.AppendLine('<div class="grid-2" id="source">')
        [void]$body.AppendLine('<div class="grid__head"><h2>Where this comes from</h2></div>')
        [void]$body.AppendLine('<section class="card grid__full">')
        [void]$body.AppendLine('<dl class="facts">')
        [void]$body.AppendLine('<div><dt>Enabled in</dt><dd>' + $(if ($Model.Consulted) { & $e $Model.Consulted } else { '--' }) + '</dd></div>')
        foreach ($c in @($Model.Clones)) {
            $bits = if ($c.Exists) { @('HEAD ' + $(if ($c.Head.Length -ge 12) { $c.Head.Substring(0, 12) } else { $c.Head })) + @($(if ($c.HeadDate) { 'committed ' + $c.HeadDate })) + @($(if ($c.FetchTime) { 'last fetch ' + $c.FetchTime })) } else { @('not present') }
            [void]$body.AppendLine('<div><dt>Clone ' + (& $e $c.Marketplace) + '</dt><dd>' + (& $e ((@($bits) | Where-Object { $_ }) -join ', ')) + '</dd></div>')
        }
        [void]$body.AppendLine('</dl>')
        [void]$body.AppendLine('</section>')
        [void]$body.AppendLine('</div>')
    }
    return Format-GeneralPageHtml -Title 'Plugins' -Body $body.ToString() -Eyebrow $RepoName -SiteName $RepoName -HubHref $HubHref `
        -Lead 'Every plugin this repo enables, and whether it is installed and current for this checkout on this machine. A problem with a plugin is named at the top, with the command that closes it.' `
        -FooterNote 'Read on every request by the plugin-versions skill''s own script, <code>plugin-versions.ps1 -Json</code>: the enable state from the settings files, the install record from <code>~/.claude/plugins/installed_plugins.json</code>, and the marketplace clone under <code>~/.claude/plugins/marketplaces</code>.'
}
