<#
.SYNOPSIS
    The I/O half of the state-file contract between a checkout's two servers (#3119): read and write
    %TEMP%\dkj-repo-hub-<leaf>-<hash>.json, and ask whether the general pages server named in it answers.

.DESCRIPTION
    The rules -- the path, the shape, what is believed -- are in dev-preview-rules.ps1 (no I/O), which this
    file dot-sources. What is here touches the disk and one loopback socket, and is shared by the three
    things that need it: the dev-preview hook (writes), the general pages server (reads, for /hub) and a
    repo hub (reads, to render its General card). A state file that is absent, unreadable or about another
    root reads as nothing, never as an error: a hub then shows the card's "not running" form.

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/dev-preview-sessionstart.tests.ps1 in the source repo.
#>

. (Join-Path $PSScriptRoot 'dev-preview-rules.ps1')

function Read-RepoHubState {
    <# @{ Hub; Pages } for the checkout at -Root, both '' when the file is absent, unreadable or not this root's. #>
    param([Parameter(Mandatory = $true)][string]$Root)
    $path = Get-RepoHubStatePath -Root $Root
    try {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @{ Hub = ''; Pages = '' } }
        return (ConvertFrom-RepoHubState -Text ([System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)) -Root $Root)
    } catch {
        return @{ Hub = ''; Pages = '' }
    }
}

function Write-RepoHubState {
    <# Writes the state file for -Root. Throws on a write failure; the hook wraps it, since it never fails a session. #>
    param([Parameter(Mandatory = $true)][string]$Root, [AllowEmptyString()][string]$Hub = '', [AllowEmptyString()][string]$Pages = '')
    $text = Format-RepoHubState -Root $Root -Hub $Hub -Pages $Pages
    [System.IO.File]::WriteAllText((Get-RepoHubStatePath -Root $Root), $text, (New-Object System.Text.UTF8Encoding($false)))
}

function Test-LoopbackPortOpen {
    <# True when something accepts a connection on 127.0.0.1:-Port within -TimeoutMs. A hub must not hang on a dead server. #>
    param([int]$Port, [int]$TimeoutMs = 300)
    $c = New-Object System.Net.Sockets.TcpClient
    try {
        $wait = $c.BeginConnect('127.0.0.1', $Port, $null, $null)
        if (-not $wait.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) { return $false }
        $c.EndConnect($wait)
        return $c.Connected
    } catch {
        return $false
    } finally {
        $c.Close()
    }
}

function Get-GeneralPagesUrl {
    <#
        The general pages server's base url for the checkout at -Root, for a hub's General card: the one the
        state file names, and only when it answers within -TimeoutMs; '' otherwise (the card's "not running"
        form).
    #>
    param([Parameter(Mandatory = $true)][string]$Root, [int]$TimeoutMs = 300)
    $state = Read-RepoHubState -Root $Root
    if (-not $state.Pages) { return '' }
    $port = ([uri]$state.Pages).Port
    if (Test-LoopbackPortOpen -Port $port -TimeoutMs $TimeoutMs) { return $state.Pages }
    return ''
}
