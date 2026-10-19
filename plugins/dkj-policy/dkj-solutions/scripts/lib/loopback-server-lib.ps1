<#
.SYNOPSIS
    What the plugin's two small servers (scripts/preview/serve-placeholder.ps1 and
    scripts/pages/serve-general-pages.ps1) share: reading one request head off a TcpClient, writing one
    response, and the two refusals every request meets first (a Host that is not loopback, a browser
    request from another site). One copy, so a fix to either rule lands in both servers (#3119).

.DESCRIPTION
    The reader and the writer touch only the client's stream, which the caller hands in; the two tests
    are pure. Nothing here knows a page, a route or a repo.

    A SAME-SITE REQUEST IS NOT ALWAYS FOREIGN. Browsers do not count the port toward "site", so the hub
    on localhost:4876 and the general pages on localhost:4890 are the same site, and a user clicking the
    hub's General link sends Sec-Fetch-Site: same-site -- as does the 303 hop from the repo server's
    /issues to the general server, and the "Repo hub" crumb back. That is a top-level navigation, a GET the
    user made, and it is served. What stays refused is cross-site always, and same-site for anything that
    is not a navigation (a fetch, an image, a form post): the loop is single-threaded, and a page on
    another port of this machine must not be able to keep it busy. A missing header (curl, an old browser)
    is allowed, as is same-origin and none (a typed or bookmarked URL).

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/dev-preview-sessionstart.tests.ps1 in
    the source repo.
#>

function Read-LoopbackRequest {
    <#
        The request line and the headers the servers read, or $null. ONE deadline for the whole head
        (-ReadTimeoutMs), not one per read, and at most 8 KB: a client that sends nothing, drips a byte at a
        time or never ends its line is dropped, so it cannot hold the single-threaded loop.
    #>
    param($Client, [int]$ReadTimeoutMs = 1000)
    $stream = $Client.GetStream()
    $buffer = New-Object byte[] 1024
    $head = New-Object System.IO.MemoryStream
    $deadline = [DateTime]::UtcNow.AddMilliseconds($ReadTimeoutMs)
    while ($true) {
        $left = [int]($deadline - [DateTime]::UtcNow).TotalMilliseconds
        if ($left -le 0) { return $null }
        $Client.ReceiveTimeout = $left
        $n = $stream.Read($buffer, 0, $buffer.Length)
        if ($n -le 0) { return $null }
        $head.Write($buffer, 0, $n)
        if ($head.Length -gt 8192) { return $null }
        $text = [System.Text.Encoding]::ASCII.GetString($head.ToArray())
        $end = $text.IndexOf("`r`n`r`n")
        if ($end -ge 0) { break }
    }
    $lines = $text.Substring(0, $end) -split "`r`n"
    $result = @{ RequestLine = $lines[0]; Host = ''; SecFetchSite = ''; SecFetchMode = '' }
    foreach ($h in @($lines | Select-Object -Skip 1)) {
        if ($h -match '^Host:\s*(.*)$') { $result.Host = $Matches[1] }
        elseif ($h -match '^Sec-Fetch-Site:\s*(.*)$') { $result.SecFetchSite = $Matches[1] }
        elseif ($h -match '^Sec-Fetch-Mode:\s*(.*)$') { $result.SecFetchMode = $Matches[1] }
    }
    return $result
}

function Send-LoopbackResponse {
    <#
        One response, Connection: close. -Headers are extra header lines (the caller's own fixed values).
        A -Method HEAD gets the same headers as a GET, the real Content-Length included, and no body
        (RFC 9110, #3161) -- dropped here once rather than by each route.
    #>
    param($Stream, [int]$Status, [string]$Reason, [string]$Type, [byte[]]$Body, [hashtable]$Headers = @{}, [string]$Method = 'GET')
    $head = "HTTP/1.1 $Status $Reason`r`nContent-Type: $Type`r`nContent-Length: $($Body.Length)`r`n" +
        "Cache-Control: no-store`r`nX-Content-Type-Options: nosniff`r`nConnection: close`r`n"
    foreach ($k in $Headers.Keys) { $head += "$k`: $($Headers[$k])`r`n" }
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($head + "`r`n")
    $Stream.Write($bytes, 0, $bytes.Length)
    if ($Body.Length -and $Method -ne 'HEAD') { $Stream.Write($Body, 0, $Body.Length) }
    $Stream.Flush()
}

function Test-LoopbackHost {
    <#
        True when the request's Host header names this server on loopback. A page elsewhere that rebinds
        its DNS name to 127.0.0.1 arrives with its own name, so it is refused (DNS rebinding).
    #>
    param([AllowNull()][AllowEmptyString()][string]$HostHeader, [int]$Port)
    if (-not $HostHeader) { return $false }
    $h = $HostHeader.Trim().ToLowerInvariant()
    return ($h -eq "localhost:$Port" -or $h -eq "127.0.0.1:$Port")
}

function Test-LoopbackCrossSite {
    <#
        True when the request is to be refused for where it comes from. 'cross-site' always. 'same-site'
        (another port or subdomain of this machine) unless it is a top-level navigation: Sec-Fetch-Mode
        'navigate' on a GET, which is a user following a link, and a redirect hop of one. 'same-origin',
        'none' and a missing header are allowed. -SecFetchMode and -Method default to empty, which makes a
        same-site request a non-navigation: the old behaviour, for a caller that does not know them.
    #>
    param(
        [AllowNull()][AllowEmptyString()][string]$SecFetchSite,
        [AllowNull()][AllowEmptyString()][string]$SecFetchMode = '',
        [AllowNull()][AllowEmptyString()][string]$Method = ''
    )
    if (-not $SecFetchSite) { return $false }
    $v = $SecFetchSite.Trim().ToLowerInvariant()
    if ($v -eq 'cross-site') { return $true }
    if ($v -eq 'same-site') {
        $navigation = ([string]$SecFetchMode).Trim().ToLowerInvariant() -eq 'navigate' -and ([string]$Method).Trim().ToUpperInvariant() -eq 'GET'
        return (-not $navigation)
    }
    return $false
}
