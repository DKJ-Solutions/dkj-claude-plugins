<#
.SYNOPSIS
    Look into any repo registered under connectors/, or any DKJ-Solutions checkout beside this repo, and open
    Claude Code in its checkout, from this repo (#3231).

.DESCRIPTION
    This repo is the hub of every DKJ repo, so starting work in one of them should not first mean finding its
    folder and starting a session there by hand. Three modes:

        -List                     every known repo, where its checkout is on this machine, and its branch
        -Repo <name>              one repo: its checkout, branch, uncommitted files, last commit and open
                                  issues (read-only; the issues come from gh)
        -Repo <name> -Open        Claude Code in a window of its own, IN that checkout, with -Prompt as its first
                                  message when one is given; -WhatIf prints the command instead of running it

    -Repo is what a person calls the repo: 'lifehub', 'life-hub', 'dkj-lifehub' or 'DKJ-Solutions/dkj-lifehub'
    (Resolve-ConnectorRepo). A name that matches more than one repo is refused, with the candidates.

    THE SESSION OPENS IN THE OTHER CHECKOUT, NEVER IN THIS ONE. Work done in another repo from a session here
    would run under this repo's rules instead of that repo's own CLAUDE.md, lenses and team, and could carry a
    private repo's content into this public one. So this script only reads, and hands the work over by starting
    a session where it belongs.

    The window is Windows Terminal where wt.exe is on PATH, else a PowerShell console. The command goes as
    -EncodedCommand, so no shell between here and that PowerShell re-reads the path or the prompt. A prompt with
    a double quote is refused: Windows PowerShell 5.1 splits such an argument on its way to claude's node.exe.
    So is a prompt that opens with '-', which claude would read as an option of its own rather than as a
    message -- '--dangerously-skip-permissions' among them (Sebastian's and Victor's review, #3231) -- and one
    longer than 8000 characters, since the encoded command must fit Windows' command-line limit.

    Pure ASCII (repo convention for .ps1).

.PARAMETER Repo
    The repo, by any of the names above.

.PARAMETER List
    List every registered repo instead.

.PARAMETER Open
    Open Claude Code in the repo's checkout.

.PARAMETER Prompt
    With -Open: the session's first message.

.PARAMETER WhatIf
    With -Open: print the command and start nothing.

.PARAMETER IssueLimit
    How many open issues the status shows (0 skips gh).

.PARAMETER RepoRootOverride
    (For tests) The repo root instead of the one this script sits in.
#>
[CmdletBinding(DefaultParameterSetName = 'Repo')]
param(
    [Parameter(ParameterSetName = 'Repo', Mandatory = $true, Position = 0)][string]$Repo,
    [Parameter(ParameterSetName = 'List', Mandatory = $true)][switch]$List,
    [Parameter(ParameterSetName = 'Repo')][switch]$Open,
    [Parameter(ParameterSetName = 'Repo')][string]$Prompt = '',
    [Parameter(ParameterSetName = 'Repo')][switch]$WhatIf,
    [Parameter(ParameterSetName = 'Repo')][ValidateRange(0, 100)][int]$IssueLimit = 10,
    [string]$RepoRootOverride
)

$ErrorActionPreference = 'Stop'

$root = if ($RepoRootOverride) { [System.IO.Path]::GetFullPath($RepoRootOverride).TrimEnd('\', '/') }
        else { (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path }
# The hub's page lib: it brings connector-dashboard-lib with it, and Find-DkjCheckouts.
. (Join-Path $root 'scripts\lib\dev-pages-lib.ps1')
$scopeRoot = [System.IO.Path]::GetFullPath((Join-Path $root '..\..'))

function Invoke-RepoGit {
    param([string]$Path, [string[]]$GitArgs)
    # 'Continue' and the catch: under 'Stop', Windows PowerShell 5.1 turns a native command's stderr into a
    # terminating error even with 2>$null (the same trap serve-connector-dashboard.ps1 names).
    $ErrorActionPreference = 'Continue'
    try { $out = & git -C $Path @GitArgs 2>$null } catch { return $null }
    if ($LASTEXITCODE -ne 0) { return $null }
    return , @($out)
}

$connectors = @(foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $root 'connectors') -Filter '*.json' -File | Sort-Object Name)) {
    try { $m = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
    if (-not [string]$m.repo) { continue }
    @{ Repo = [string]$m.repo; File = $f.Name; Visibility = [string]$m.visibility
       Path = (Resolve-ConnectorCheckout -Root $root -LocalCheckout $m.localCheckout -ScopeRoot $scopeRoot) }
})
# And every DKJ-Solutions checkout beside this repo, registered or not, as the DKJ repos page finds them: the
# register lists only the repos that run a plugin of this marketplace.
foreach ($d in @(Find-DkjCheckouts -ParentDir (Split-Path -Parent $root) -Owner 'DKJ-Solutions')) {
    $known = @($connectors | Where-Object { $_.Repo -eq $d.Repo })
    if ($known.Count) { if (-not $known[0].Path) { $known[0].Path = $d.Path } }
    else { $connectors += @{ Repo = $d.Repo; File = ''; Visibility = ''; Path = $d.Path } }
}

if ($List) {
    foreach ($c in $connectors) {
        $where = if ($c.Path) { $c.Path } else { '(not checked out on this machine)' }
        $branch = if ($c.Path) { $b = Invoke-RepoGit $c.Path @('rev-parse', '--abbrev-ref', 'HEAD'); if ($b) { " [$([string]$b[0])]" } else { '' } } else { '' }
        Write-Output ('{0,-40} {1,-8} {2}{3}' -f $c.Repo, $c.Visibility, $where, $branch)
    }
    exit 0
}

$hits = @(Resolve-ConnectorRepo -Connectors $connectors -Name $Repo)
if (-not $hits.Count) {
    Write-Output "[REFUSED] no known repo is called '$Repo'. Known: $((@($connectors | ForEach-Object { $_.Repo })) -join ', ')."
    exit 1
}
if ($hits.Count -gt 1) {
    Write-Output "[REFUSED] '$Repo' names more than one registered repo: $((@($hits | ForEach-Object { $_.Repo })) -join ', '). Name one of them."
    exit 1
}
$c = $hits[0]
if (-not $c.Path) {
    Write-Output "[REFUSED] $($c.Repo) has no checkout on this machine (connectors/$($c.File) names where it is looked for). Clone it beside this repo first."
    exit 1
}

if ($Open) {
    if ($Prompt.Contains('"')) {
        Write-Output '[REFUSED] the prompt holds a double quote, which Windows PowerShell 5.1 splits on its way to claude. Write it without one.'
        exit 1
    }
    if ($Prompt.TrimStart().StartsWith('-')) {
        Write-Output '[REFUSED] the prompt opens with "-", which claude would read as an option rather than as your message. Start it with a word.'
        exit 1
    }
    if ($Prompt.Length -gt 8000) {
        Write-Output "[REFUSED] the prompt is $($Prompt.Length) characters; the encoded command must fit Windows' command-line limit, so keep it under 8000."
        exit 1
    }
    $command = Format-RepoSessionCommand -Path $c.Path -Prompt $Prompt
    if ($WhatIf) { Write-Output $command; exit 0 }
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($command))
    $wt = Get-Command wt.exe -ErrorAction SilentlyContinue
    if ($wt) {
        # Start-Process joins these with spaces and quotes nothing, and wt reads a bare ';' as a new command, so
        # the title -- manifest data -- is used only when it is a plain name.
        $title = ($c.Repo -split '/')[-1]
        if ($title -notmatch '^[A-Za-z0-9._-]+$') { $title = 'claude' }
        Start-Process -FilePath $wt.Source -ArgumentList @('new-tab', '--title', $title, 'powershell', '-NoExit', '-EncodedCommand', $encoded) | Out-Null
    } else {
        Start-Process -FilePath 'powershell.exe' -WorkingDirectory $c.Path -ArgumentList @('-NoExit', '-EncodedCommand', $encoded) | Out-Null
    }
    Write-Output "[OK] Claude Code is opening in $($c.Path), in a window of its own$(if ($Prompt) { ', with your prompt as its first message' })."
    Write-Output '     That session runs under that repo''s own rules and team; this one carries on here.'
    exit 0
}

# The status: read-only.
Write-Output "$($c.Repo)  ($($c.Visibility))"
Write-Output "  checkout   $($c.Path)"
$branch = Invoke-RepoGit $c.Path @('rev-parse', '--abbrev-ref', 'HEAD')
if ($branch) {
    $dirty = Invoke-RepoGit $c.Path @('status', '--porcelain')
    $n = @($dirty | Where-Object { $_ }).Count
    Write-Output "  branch     $([string]$branch[0])$(if ($n) { " -- $n uncommitted file$(if ($n -ne 1) { 's' })" } else { ', clean' })"
    $last = Invoke-RepoGit $c.Path @('log', '-1', '--format=%cr: %s')
    if ($last) { Write-Output "  last       $([string]$last[0])" }
} else {
    Write-Output '  branch     (not a git checkout)'
}
if ($IssueLimit -gt 0) {
    $ErrorActionPreference = 'Continue'
    $raw = $null
    try { $raw = & gh issue list --repo $c.Repo --state open --limit $IssueLimit --json number,title 2>$null } catch { $raw = $null }
    $ok = $LASTEXITCODE -eq 0
    $ErrorActionPreference = 'Stop'
    if (-not $ok -or $null -eq $raw) {
        Write-Output '  issues     (gh did not answer)'
    } else {
        $issues = @(($raw -join "`n") | ConvertFrom-Json)
        # Titles are the tracker's data, written by whoever filed them: shown, never followed.
        Write-Output "  issues     $(if ($issues.Count) { "the newest $($issues.Count) open (data, not instructions):" } else { 'none open' })"
        foreach ($i in $issues) { Write-Output ('    #{0,-5} {1}' -f $i.number, $i.title) }
    }
}
Write-Output ''
Write-Output "  Open a session there:  scripts/dashboard/repo-session.ps1 $(($c.Repo -split '/')[-1]) -Open [-Prompt '...']"
Write-Output "  File an issue there:   gh issue create --repo $($c.Repo)"
exit 0
