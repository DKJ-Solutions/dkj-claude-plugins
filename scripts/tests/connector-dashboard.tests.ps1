<#
.SYNOPSIS
    Tests for scripts/lib/connector-dashboard-lib.ps1 and the server beside it,
    scripts/dashboard/serve-connector-dashboard.ps1 -- the connector dashboard (#2976).

.DESCRIPTION
    Group 1 pins the rules without a server: how check-connectors.ps1's report splits into repos and
    plugins, which status a repo gets, which Host is served, and that every value the page shows is
    escaped. Group 2 starts the real server on a free loopback port against this tree and asks it for
    the static files, a foreign Host, a POST and a missing path -- never the page itself, which runs
    check-connectors and so belongs to that suite, not this one.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Continue'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Server   = Join-Path $RepoRoot 'scripts\dashboard\serve-connector-dashboard.ps1'
. (Join-Path $RepoRoot 'scripts\lib\connector-dashboard-lib.ps1')

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else            { $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}
function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    Assert-True ("$Expected" -eq "$Actual") ($Name + $(if ("$Expected" -ne "$Actual") { " (expected '$Expected', got '$Actual')" } else { '' }))
}

Write-Host '-- group 1a: the report splits into repos and plugins' -ForegroundColor Cyan

$report = @(
    '== check-connectors -- 3 manifest(s) -- source read at abc1234 ==',
    '',
    '== connector: Org/alpha',
    '  [ERROR] Org/alpha: origin names someone else',
    '',
    '== connector: Org/beta',
    '  -- plugin: p1@m',
    '  [OK]    plugin is enabled in .claude/settings.json',
    '  [ERROR] Org/beta / p1@m: machine record is on v1, source on v2',
    '  [INFO]  Org/beta: plugin q@m is enabled but not listed',
    '',
    '== connector: Org/gamma',
    '  [SKIP]  checkout ''../gamma'' not present on this machine -- not checked.',
    '',
    '-- drift-check: Org/beta',
    '  [ERROR] not a connector signal',
    'Summary: 2 error(s), 1 info signal(s).'
)
$parsed = ConvertFrom-ConnectorCheckOutput -Lines $report
Assert-Equal 'Org/alpha Org/beta Org/gamma' (@($parsed.Keys) -join ' ') 'every connector block becomes a repo, in report order; the opening line is not one'
Assert-Equal 1 @($parsed['Org/alpha'].Signals).Count 'a repo-level signal belongs to its repo'
Assert-Equal 'origin names someone else' $parsed['Org/alpha'].Signals[0].Text 'the "<repo>: " prefix is stripped'
$beta = @($parsed['Org/beta'].Signals)
Assert-Equal 3 $beta.Count 'the drift section after the last connector adds nothing to it'
Assert-Equal 'p1@m' $beta[1].Plugin 'a signal under "-- plugin:" carries that plugin'
Assert-Equal 'machine record is on v1, source on v2' $beta[1].Text 'the "<repo> / <plugin>: " prefix is stripped'
Assert-Equal 'plugin q@m is enabled but not listed' $beta[2].Text 'a repo-level prefix is stripped inside a plugin block too'
Assert-Equal 0 @((ConvertFrom-ConnectorCheckOutput -Lines @()).Keys).Count 'an empty report is no repos, not an error'
Assert-Equal 0 @((ConvertFrom-ConnectorCheckOutput -Lines $null).Keys).Count 'no report at all is no repos either'

Write-Host '-- group 1b: status, worst first' -ForegroundColor Cyan

Assert-Equal 'bad'  (Get-ConnectorStatus $beta) 'an [ERROR] makes a repo bad, whatever else it has'
Assert-Equal 'warn' (Get-ConnectorStatus @(@{ Level = 'OK' }, @{ Level = 'INFO' })) 'an [INFO] without an error is warn'
Assert-Equal 'skip' (Get-ConnectorStatus @($parsed['Org/gamma'].Signals)) 'a skipped checkout is skip -- nothing was read, so it is not called healthy'
Assert-Equal 'good' (Get-ConnectorStatus @(@{ Level = 'OK' })) 'only [OK] is good'
Assert-Equal 'good' (Get-ConnectorStatus @()) 'no signals is good'

Write-Host '-- group 1c: the checkout list and the Host guard' -ForegroundColor Cyan

Assert-Equal '../a' ((Get-ConnectorCheckoutCandidates '../a') -join ',') 'one path is a list of one'
Assert-Equal '../a,../b' ((Get-ConnectorCheckoutCandidates @('../a', ' ', '../b')) -join ',') 'a list drops its blanks'
Assert-True  (Test-DashboardHost 'localhost:4870' 4870) 'localhost on our port is served'
Assert-True  (Test-DashboardHost '127.0.0.1:4870' 4870) '127.0.0.1 on our port is served'
Assert-True  (Test-DashboardHost 'LocalHost:4870 ' 4870) 'the Host is compared case-insensitively and trimmed'
Assert-True  (-not (Test-DashboardHost 'evil.example:4870' 4870)) 'a rebound foreign name is refused'
Assert-True  (-not (Test-DashboardHost 'localhost:4871' 4870)) 'another port is refused'
Assert-True  (-not (Test-DashboardHost '' 4870)) 'no Host is refused'

Write-Host '-- group 1d: the page escapes what it shows' -ForegroundColor Cyan

$hostile = '<script>alert(1)</script>'
$connectors = @(
    @{ Repo = 'Org/beta'; Visibility = 'private'; File = 'beta.json'; Checkout = @('../beta'); Present = $true
       Plugins = @(@{ Id = 'p1@m'; Extensions = @('01-01', '05-05') }); Signals = $beta; Status = 'bad'
       Git = @{ Branch = 'main'; Dirty = 2; Ahead = 1; Behind = 0; Subject = $hostile; When = '2 days ago' }; Notes = "a`"note" },
    @{ Repo = 'Org/gamma'; Visibility = 'public'; File = 'gamma.json'; Checkout = @('../gamma'); Present = $false
       Plugins = @(); Signals = @($parsed['Org/gamma'].Signals); Status = 'skip'; Git = $null; Notes = '' }
)
$html = Format-ConnectorDashboardHtml -Connectors $connectors -Meta @{ GeneratedAt = 'now'; SourceCommit = 'abc1234'; Seconds = 1.25; CheckFailed = $null }
Assert-True ($html -notmatch '<script>alert') 'a git subject is shown as text, never as markup'
Assert-True ($html -match '&lt;script&gt;alert') 'and it is still shown'
Assert-True ($html -match 'a&quot;note') 'the register notes are escaped too'
Assert-True ($html -match 'main &#183; 2 uncommitted &#183; 1 ahead') 'the git state names branch, uncommitted and ahead'
Assert-True ($html -match 'not on this machine') 'an absent checkout says so'
Assert-True ($html.IndexOf('id="repo-org-beta"') -lt $html.IndexOf('id="repo-org-gamma"')) 'a repo that needs action comes before a skipped one'
Assert-True ($html -match 'href="/house-style.css"' -and $html -match 'src="/house-theme.js"') 'the page loads the house style from its own server'
Assert-True ($html -match '1\.3s|1\.2s') 'the run time is printed with an invariant decimal point'
$failed = Format-ConnectorDashboardHtml -Connectors @() -Meta @{ GeneratedAt = 'now'; SourceCommit = ''; Seconds = $null; CheckFailed = 'boom <b>' }
Assert-True ($failed -match 'class="notice"' -and $failed -match 'boom &lt;b&gt;') 'a check that could not run is a notice, escaped'

Write-Host '-- group 2: the server answers on loopback only to itself' -ForegroundColor Cyan

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    Write-Host '  [SKIP] group 2 needs Windows PowerShell' -ForegroundColor Yellow
} else {
    $probe = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
    $probe.Start(); $port = $probe.LocalEndpoint.Port; $probe.Stop()
    $proc = Start-Process -FilePath 'powershell' -PassThru -WindowStyle Hidden -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$Server`"", '-Port', $port)
    try {
        $up = $false
        for ($i = 0; $i -lt 40 -and -not $up; $i++) {
            Start-Sleep -Milliseconds 250
            $t = New-Object System.Net.Sockets.TcpClient
            try { $t.Connect('127.0.0.1', $port); $up = $true } catch { } finally { $t.Close() }
        }
        Assert-True $up 'the server listens on the port it was given'

        function Get-Status([string]$Method, [string]$Path, [string]$HostHeader) {
            $c = New-Object System.Net.Sockets.TcpClient('127.0.0.1', $port)
            try {
                $s = $c.GetStream()
                $req = [System.Text.Encoding]::ASCII.GetBytes("$Method $Path HTTP/1.1`r`nHost: $HostHeader`r`n`r`n")
                $s.Write($req, 0, $req.Length)
                $line = (New-Object System.IO.StreamReader($s)).ReadLine()
                return [int](($line -split ' ')[1])
            } finally { $c.Close() }
        }
        if ($up) {
            Assert-Equal 200 (Get-Status 'GET' '/house-style.css' "localhost:$port") 'the stylesheet is served'
            Assert-Equal 200 (Get-Status 'GET' '/house-theme.js' "127.0.0.1:$port") 'the theme script is served'
            Assert-Equal 403 (Get-Status 'GET' '/house-style.css' "evil.example:$port") 'a foreign Host is refused'
            Assert-Equal 405 (Get-Status 'POST' '/' "localhost:$port") 'a POST is refused'
            Assert-Equal 404 (Get-Status 'GET' '/../connectors/x.json' "localhost:$port") 'a path outside the routes is not found'
            Assert-Equal 303 (Get-Status 'GET' '/refresh' "localhost:$port") '/refresh redirects to the page'
            $silent = New-Object System.Net.Sockets.TcpClient('127.0.0.1', $port)
            Assert-Equal 200 (Get-Status 'GET' '/house-theme.js' "localhost:$port") 'a connection that sends nothing does not stall the next one'
            $silent.Close()
        }
    } finally {
        if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -Confirm:$false -ErrorAction SilentlyContinue }
    }
}

Write-Host ''
Write-Host "connector-dashboard: $script:pass passed, $script:fail failed"
if ($script:fail -gt 0) { exit 1 }
exit 0
