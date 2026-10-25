<#
.SYNOPSIS
    The I/O half of the state-file contract between a checkout's two servers (#3119): read and write
    %TEMP%\dkj-repo-hub-<leaf>-<hash>.json, and ask whether the general pages server named in it answers.

.DESCRIPTION
    The rules -- the path, the shape, what is believed -- are in dev-preview-rules.ps1 (no I/O), which this
    file dot-sources. What is here touches the disk and one loopback socket, and is shared by the three
    things that need it: the dev-preview hook (writes), the general pages server (reads, to render the hub
    or send '/hub' on to the repo's own, #3245) and a repo's own hub (reads, to render its General card). A
    state file that is absent, unreadable or about another root reads as nothing, never as an error: a hub
    then shows the card's "not running" form. Beside it,
    Test-DkjSolutionsEnabled: whether the repo enables dkj-solutions, which the dev-preview hook asks.

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/dev-preview-sessionstart.tests.ps1 in the source repo.
#>

. (Join-Path $PSScriptRoot 'dev-preview-rules.ps1')

function Read-RepoHubState {
    <# @{ Hub; Pages; Product; Mode; Theme } for the checkout at -Root: every url and Theme '' and Mode 'none' when the file is absent, unreadable or not this root's. #>
    param([Parameter(Mandatory = $true)][string]$Root)
    $path = Get-RepoHubStatePath -Root $Root
    try {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @{ Hub = ''; Pages = ''; Product = ''; Mode = 'none'; Theme = '' } }
        return (ConvertFrom-RepoHubState -Text ([System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)) -Root $Root)
    } catch {
        return @{ Hub = ''; Pages = ''; Product = ''; Mode = 'none'; Theme = '' }
    }
}

function Write-RepoHubState {
    <# Writes the state file for -Root. Throws on a write failure; the hook wraps it, since it never fails a session. #>
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [AllowEmptyString()][string]$Hub = '',
        [AllowEmptyString()][string]$Pages = '',
        [AllowEmptyString()][string]$Product = '',
        [ValidateSet('none', 'product', 'ownhub')][string]$Mode = 'none',
        [AllowEmptyString()][string]$Theme = ''
    )
    $text = Format-RepoHubState -Root $Root -Hub $Hub -Pages $Pages -Product $Product -Mode $Mode -Theme $Theme
    [System.IO.File]::WriteAllText((Get-RepoHubStatePath -Root $Root), $text, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-LoopbackWhoami {
    <#
        What the general pages server on 127.0.0.1:-Port says it serves: the text body of its /whoami, which is
        the hash of the repo root it was started in (Get-DevPreviewRootHash), or '' when nothing answers it
        within -TimeoutMs (one deadline for the connect and the read). An open port proves only that
        something listens; this is what proves whose server it is.
    #>
    param([int]$Port, [int]$TimeoutMs = 500)
    $c = New-Object System.Net.Sockets.TcpClient
    try {
        $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMs)
        $wait = $c.BeginConnect('127.0.0.1', $Port, $null, $null)
        if (-not $wait.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) { return '' }
        $c.EndConnect($wait)
        $left = [int]($deadline - [DateTime]::UtcNow).TotalMilliseconds
        if ($left -le 0) { return '' }
        $c.ReceiveTimeout = $left
        $c.SendTimeout = $left
        $stream = $c.GetStream()
        $req = [System.Text.Encoding]::ASCII.GetBytes("GET /whoami HTTP/1.1`r`nHost: localhost:$Port`r`nConnection: close`r`n`r`n")
        $stream.Write($req, 0, $req.Length)
        $text = (New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII)).ReadToEnd()
        if ($text -notmatch '^HTTP/1\.1 200 ') { return '' }
        $at = $text.IndexOf("`r`n`r`n")
        if ($at -lt 0) { return '' }
        $body = $text.Substring($at + 4).Trim()
        if ($body -cmatch '^[0-9a-f]{8}\z') { return $body }
        return ''
    } catch {
        return ''
    } finally {
        $c.Close()
    }
}

function Get-GeneralPagesUrl {
    <#
        The general pages server's base url for the checkout at -Root, for a hub's General card: the one the
        state file names, and only when the server there says it is THIS checkout's (its /whoami is this
        root's hash) within -TimeoutMs; '' otherwise, which is the card's "not running" form. A bare connect
        is not enough: two checkouts race for the same ports, and a stale file can name a port another
        checkout's server has taken since.
    #>
    param([Parameter(Mandatory = $true)][string]$Root, [int]$TimeoutMs = 500)
    $state = Read-RepoHubState -Root $Root
    if (-not $state.Pages) { return '' }
    $port = ([uri]$state.Pages).Port
    if ((Get-LoopbackWhoami -Port $port -TimeoutMs $TimeoutMs) -eq (Get-DevPreviewRootHash -Root $Root)) { return $state.Pages }
    return ''
}

function Test-DkjSolutionsEnabled {
    <#
        True when the checkout at -Root enables the dkj-solutions plugin: an enabledPlugins key
        'dkj-solutions@<marketplace>' set to true in its .claude/settings.json, or in .claude/settings.local.json,
        which wins where it names the plugin too. The dev-preview hook asks it, to name the hub roll-out drift
        only in a DKJ-Solutions repo; it decided the hub's Brand book card too, until #3475 took that off every
        consumer hub. A file that is absent or not valid JSON says nothing, so the answer is then the other
        file's, else false.
    #>
    param([Parameter(Mandatory = $true)][string]$Root)
    $enabled = $false
    foreach ($name in 'settings.json', 'settings.local.json') {
        $path = Join-Path $Root ".claude\$name"
        try {
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
            $plugins = (ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8))).enabledPlugins
            if ($null -eq $plugins) { continue }
            foreach ($p in @($plugins.PSObject.Properties | Where-Object { $_.Name -like 'dkj-solutions@*' })) { $enabled = ($p.Value -eq $true) }
        } catch { }
    }
    return $enabled
}
