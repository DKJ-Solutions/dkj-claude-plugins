<#
.SYNOPSIS
    The judgement behind the connector dashboard (#2976): read check-connectors.ps1's report into one
    record per connected repo, decide each repo's status, and render the page. No I/O -- the server
    (scripts/dashboard/serve-connector-dashboard.ps1) reads the manifests, runs the check and asks git,
    and hands the results in, so every rule here is tested without a server.

.DESCRIPTION
    THE REPORT IS PARSED, NOT RE-IMPLEMENTED. check-connectors.ps1 is the one place that knows what a
    connector's health means, and a second reading of the manifests would drift from it the day a check
    is added. So the dashboard runs it and splits its output on the block headers it already prints:
    '== connector: <repo>' opens a repo, '-- plugin: <id>' opens a plugin inside it, and a line opening
    with a bracketed tag is a signal. The summary after the last block is not per-repo, so the parse
    stops at it.

    A DRIFT BLOCK BELONGS TO THE REPO ITS HEADER NAMES (#2997). '-- drift-check: <repo>' reopens that
    repo, and its two summary lines become the repo's Drift record: dead copies and drifted agent defs,
    and persona drift with how many were compared. Only an [ERROR] in it -- the check's own verdict on
    agent-def drift -- becomes a signal; the per-file [DRIFTED]/[IDENTICAL] lines carry local paths and
    are already counted in the summary. Persona drift stays informational, as in the check, so it never
    changes a status on its own.

    ANY TAG IS A SIGNAL, NOT A FIXED LIST (#2995). Besides [ERROR], [INFO], [OK] and [SKIP] the check
    prints non-counting markers inside a connector block -- [INVENTORY], [UNLISTED], [UNREGISTERED],
    [NOT-INSTALLED-HERE] -- and a parser that named four tags dropped them, so such a repo read as in
    sync. Every tag other than ERROR, OK and SKIP is read as INFO: a note, never an error, which is how
    the check itself counts them.

    STATUS, worst first: 'bad' (an [ERROR]), 'warn' (an [INFO]), 'skip' (the checkout is not on this
    machine, so nothing was checked) and 'good'. A skipped repo is not called healthy: nothing was read.

    EVERY VALUE THAT REACHES THE PAGE IS ESCAPED. Manifest fields and git subjects come from other
    repositories, so they are text, never markup.

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/connector-dashboard.tests.ps1 --
    change one, run the other.
#>

function ConvertFrom-ConnectorCheckOutput {
    <#
        Splits check-connectors.ps1's text report into @{ <repo> = @{ Signals = list; Drift } }. Each
        signal is @{ Level; Plugin; Text }, with Plugin '' for a repo-level signal and Text stripped of the
        '<repo>: ' or '<repo> / <plugin>: ' prefix the check repeats on every line. Drift is $null, or
        @{ Dead; Drifted; PersonaDrifted; PersonaCompared } from the repo's drift block.
    #>
    param([AllowEmptyCollection()][AllowNull()][string[]]$Lines)
    $result = [ordered]@{}
    $repo = $null
    $plugin = ''
    $inDrift = $false
    foreach ($raw in @($Lines)) {
        if ($null -eq $raw) { continue }
        $line = [string]$raw
        $opens = if ($line -match '^== connector: (\S+)\s*$') { 'connector' } elseif ($line -match '^-- drift-check: (\S+)\s*$') { 'drift' } else { '' }
        if ($opens) {
            $repo = $Matches[1]
            $plugin = ''
            $inDrift = ($opens -eq 'drift')
            if (-not $result.Contains($repo)) { $result[$repo] = @{ Signals = New-Object System.Collections.ArrayList; Drift = $null } }
            if ($inDrift) { $result[$repo].Drift = @{ Dead = $null; Drifted = $null; PersonaDrifted = $null; PersonaCompared = $null } }
            continue
        }
        if ($line -match '^Summary:') { $repo = $null; continue }
        if ($null -eq $repo) { continue }
        if ($inDrift) {
            $d = $result[$repo].Drift
            if ($line -match 'Agent-def summary: \d+ missing, (\d+) identical \(dead copies\), (\d+) drifted') {
                $d.Dead = [int]$Matches[1]; $d.Drifted = [int]$Matches[2]; continue
            }
            if ($line -match 'Persona drift is INFORMATIONAL.*: (\d+) drifted of (\d+) compared') {
                $d.PersonaDrifted = [int]$Matches[1]; $d.PersonaCompared = [int]$Matches[2]; continue
            }
            if ($line -notmatch '^\s+\[ERROR\]\s') { continue }
        }
        if ($line -match '^\s+-- plugin: (\S+)\s*$') { $plugin = $Matches[1]; continue }
        if ($line -match '^\s+\[([A-Z][A-Z-]*)\]\s+(.*)$') {
            $level = $Matches[1]
            if ($level -notin @('ERROR', 'OK', 'SKIP')) { $level = 'INFO' }
            $text = $Matches[2].Trim()
            $prefixes = @()
            if ($plugin) { $prefixes += "$repo / $plugin`: " }
            $prefixes += "$repo`: "
            foreach ($p in $prefixes) {
                if ($text.StartsWith($p, [StringComparison]::Ordinal)) { $text = $text.Substring($p.Length); break }
            }
            [void]$result[$repo].Signals.Add(@{ Level = $level; Plugin = $plugin; Text = $text })
        }
    }
    return $result
}

function Get-ConnectorStatus {
    <# 'bad', 'warn', 'skip' or 'good' for one repo's signals, worst first. #>
    param([AllowEmptyCollection()][AllowNull()][object[]]$Signals)
    $levels = @(@($Signals) | Where-Object { $_ } | ForEach-Object { [string]$_.Level })
    if ($levels -contains 'ERROR') { return 'bad' }
    if ($levels -contains 'INFO') { return 'warn' }
    if ($levels -contains 'SKIP') { return 'skip' }
    return 'good'
}

function Get-ConnectorInstalledVersion {
    <#
        The installed plugin version for one repo, read from the check's own per-plugin line ('machine
        record is on the source version (vX)' or 'machine record is on vA, source on vB') -- by its text,
        whatever its tag, so no tag list is hard-coded here (#2996). Returns @{ Version; Plugin; Mixed }
        for the LOWEST version, Mixed when the plugins disagree, or $null when no plugin reported one.
    #>
    param([AllowEmptyCollection()][AllowNull()][object[]]$Signals)
    $found = @()
    foreach ($s in @($Signals | Where-Object { $_ -and $_.Plugin })) {
        if ([string]$s.Text -match 'machine record is on (?:the source version \()?v(\d+(?:\.\d+){1,3})\b') {
            $found += @{ Version = [version]$Matches[1]; Plugin = [string]$s.Plugin }
        }
    }
    if (-not $found.Count) { return $null }
    $lowest = @($found | Sort-Object { $_.Version }, { $_.Plugin })[0]
    $mixed = @($found | ForEach-Object { [string]$_.Version } | Select-Object -Unique).Count -gt 1
    return @{ Version = [string]$lowest.Version; Plugin = $lowest.Plugin; Mixed = $mixed }
}

function Format-DashboardInstalledVersion {
    <# The Overview cell: '-' when the checkout is not here, the version, and the plugin when they differ. #>
    param([AllowNull()]$Connector)
    if (-not $Connector.Present) { return '-' }
    $v = Get-ConnectorInstalledVersion $Connector.Signals
    if ($null -eq $v) { return 'no record' }
    $cell = 'v' + (ConvertTo-DashboardText $v.Version)
    if ($v.Mixed) { $cell += ' <code>' + (ConvertTo-DashboardText $v.Plugin) + '</code>' }
    return $cell
}

function Format-DashboardDrift {
    <#
        One short line for a repo's Drift record (#2997), or '' when it has none: dead copies, drifted
        agent defs, and drifted personas of those compared. A count the check did not print reads '?'.
    #>
    param([AllowNull()]$Drift)
    if ($null -eq $Drift) { return '' }
    $n = { param($v) if ($null -eq $v) { '?' } else { [string][int]$v } }
    return 'Drift: ' + (& $n $Drift.Dead) + ' dead copies &#183; ' + (& $n $Drift.Drifted) + ' drifted agent defs &#183; ' +
        (& $n $Drift.PersonaDrifted) + ' of ' + (& $n $Drift.PersonaCompared) + ' personas drifted (informational)'
}

function Get-ConnectorCheckoutCandidates {
    <# The manifest's localCheckout as a list: one relative path, or several (#1524). #>
    param([AllowNull()]$LocalCheckout)
    return @(@($LocalCheckout) | Where-Object { $_ -and ([string]$_).Trim() } | ForEach-Object { ([string]$_).Trim() })
}

function ConvertTo-DashboardText {
    <# HTML-escapes one value for text or a quoted attribute. #>
    param([AllowNull()][AllowEmptyString()]$Value)
    if ($null -eq $Value) { return '' }
    return ([string]$Value).Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;').Replace("'", '&#39;')
}

function Test-DashboardHost {
    <#
        True when the request's Host header names this server on the loopback interface. A page on any
        other origin that rebinds its DNS name to 127.0.0.1 arrives with its own name here, so it is
        refused rather than served (DNS rebinding).
    #>
    param([AllowNull()][AllowEmptyString()][string]$HostHeader, [int]$Port)
    if (-not $HostHeader) { return $false }
    $h = $HostHeader.Trim().ToLowerInvariant()
    return ($h -eq "localhost:$Port" -or $h -eq "127.0.0.1:$Port")
}

function Test-DashboardCrossSite {
    <#
        True when the browser says the request comes from another site (Sec-Fetch-Site 'cross-site' or
        'same-site'). The Host check cannot catch this: a page elsewhere that links or fetches here sends
        localhost as the Host. It cannot read the answer, but every page load runs check-connectors, so
        it could keep the single-threaded loop busy. A missing header (curl, an old browser) is allowed.
    #>
    param([AllowNull()][AllowEmptyString()][string]$SecFetchSite)
    if (-not $SecFetchSite) { return $false }
    $v = $SecFetchSite.Trim().ToLowerInvariant()
    return ($v -eq 'cross-site' -or $v -eq 'same-site')
}

function Test-DashboardCheckoutInScope {
    <#
        True when the resolved checkout -Full lies under -ScopeRoot at a path boundary -- the same bound
        check-connectors.ps1 sets (two levels above this repo). A manifest is data from a public repo, and
        the server runs git in the folder it names, so a relative '..\..\..' must not leave that root.
    #>
    param([Parameter(Mandatory = $true)][string]$Full, [Parameter(Mandatory = $true)][string]$ScopeRoot)
    $f = $Full.Replace('/', '\').TrimEnd('\')
    $r = $ScopeRoot.Replace('/', '\').TrimEnd('\')
    if (-not $r) { return $false }
    return $f.StartsWith($r + '\', [StringComparison]::OrdinalIgnoreCase)
}

function Get-ConnectorOwnerGroup {
    <#
        The group a repo is shown under, by the owner in its 'owner/name' slug: 'bwj' (BWJ-Development),
        'dkj' (DKJ-Solutions) or 'other' for any other owner, a personal account included. Read from the
        slug so a newly registered repo lands in its group without an edit here.
    #>
    param([AllowNull()][AllowEmptyString()][string]$Repo)
    $owner = if ($Repo -and $Repo.Contains('/')) { $Repo.Split('/')[0].ToLowerInvariant() } else { '' }
    switch ($owner) {
        'bwj-development' { return 'bwj' }
        'dkj-solutions'   { return 'dkj' }
        default           { return 'other' }
    }
}

function Get-DashboardOwnerGroups {
    <# The groups in page order, each with its heading. #>
    return @(
        @{ Key = 'bwj';   Title = 'BWJ repos' },
        @{ Key = 'dkj';   Title = 'DKJ repos' },
        @{ Key = 'other'; Title = 'Other repos' })
}

function Get-DashboardStatusBadge {
    <# The house-style badge and the word for a status. #>
    param([string]$Status)
    switch ($Status) {
        'bad'  { return @{ Class = 'badge--bad';     Mark = '!'; Word = 'Needs action' } }
        'warn' { return @{ Class = 'badge--warn';    Mark = 'i'; Word = 'Has notes' } }
        'skip' { return @{ Class = 'badge--neutral'; Mark = '-'; Word = 'Not on this machine' } }
        default { return @{ Class = 'badge--good';   Mark = '&#10003;'; Word = 'In sync' } }
    }
}

function Format-ConnectorDashboardHtml {
    <#
        The whole page. -Connectors is a list of @{ Repo; Visibility; File; Checkout; Present; Plugins
        (list of @{ Id; Extensions }); Signals; Drift (see ConvertFrom-ConnectorCheckOutput, or $null); Status; Git (@{ Branch; Trunk; Subject; When }
        or $null); Notes }. -Meta is @{ GeneratedAt; SourceCommit; Seconds; CheckFailed }.
    #>
    param(
        [AllowEmptyCollection()][Parameter(Mandatory = $true)][object[]]$Connectors,
        [Parameter(Mandatory = $true)][hashtable]$Meta
    )
    $e = { param($v) ConvertTo-DashboardText $v }
    $all = @($Connectors | Where-Object { $_ })
    $present = @($all | Where-Object { $_.Present }).Count
    $errors = 0; $infos = 0
    foreach ($c in $all) {
        $errors += @($c.Signals | Where-Object { $_.Level -eq 'ERROR' }).Count
        $infos  += @($c.Signals | Where-Object { $_.Level -eq 'INFO' }).Count
    }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<!doctype html>')
    [void]$sb.AppendLine('<html lang="en" data-theme-light="teal" data-theme-dark="sky" data-theme-key="connector-dashboard">')
    [void]$sb.AppendLine('<head>')
    [void]$sb.AppendLine('<meta charset="utf-8">')
    [void]$sb.AppendLine('<meta name="viewport" content="width=device-width, initial-scale=1">')
    [void]$sb.AppendLine('<title>dkj-claude-plugins &#183; Connected repos</title>')
    [void]$sb.AppendLine('<link rel="stylesheet" href="/house-style.css">')
    [void]$sb.AppendLine('<script src="/house-theme.js"></script>')
    # The repo layer: only names the house file does not define (.cd-*), spaced from the house scale.
    [void]$sb.AppendLine('<style>')
    # The accents take the house highlight (--primary-7), the tinted head and the lines --primary-3, and the notes --primary-6 (house-style-v3 roles).
    [void]$sb.AppendLine('.cd-band { position: fixed; top: 0; left: 0; right: 0; height: var(--spacing-1); background: var(--primary-7); }')
    [void]$sb.AppendLine('.cd-head { padding-bottom: var(--spacing-3); border-bottom: 2px solid var(--primary-7); }')
    [void]$sb.AppendLine('.cd-accent { border-top: 3px solid var(--primary-7); }')
    [void]$sb.AppendLine('.cd-figure { color: var(--primary-7); }')
    [void]$sb.AppendLine('.cd-link { color: var(--primary-7); text-underline-offset: 2px; }')
    [void]$sb.AppendLine('.cd-thead th { background: var(--primary-3); }')
    [void]$sb.AppendLine('.cd-table-gap { margin-top: var(--spacing-4); }')
    [void]$sb.AppendLine('.cd-repo-card { margin-top: var(--spacing-3); background: var(--primary-1); }')
    [void]$sb.AppendLine('.cd-subgroup { margin: var(--spacing-5) 0 var(--spacing-2); }')
    [void]$sb.AppendLine('.cd-group-count { font-size: var(--text-sm); color: var(--primary-6); }')
    [void]$sb.AppendLine('.cd-repo { display: flex; align-items: center; gap: var(--spacing-2); }')
    [void]$sb.AppendLine('.cd-repo h4 { margin: 0; }')
    [void]$sb.AppendLine('.cd-signals { list-style: none; padding: 0; margin: var(--spacing-2) 0 0; }')
    [void]$sb.AppendLine('.cd-signals li { display: flex; gap: var(--spacing-2); align-items: flex-start; padding: var(--spacing-1-5) 0; border-top: 1px solid var(--primary-3); font-size: var(--text-sm); }')
    [void]$sb.AppendLine('.cd-signals li .badge { margin-top: 1px; }')
    [void]$sb.AppendLine('.cd-signals code, .cd-plugins code { font-size: var(--text-xs); }')
    [void]$sb.AppendLine('.cd-plugins { display: flex; flex-wrap: wrap; gap: var(--spacing-1-5) var(--spacing-4); margin-top: var(--spacing-2); font-size: var(--text-sm); color: var(--primary-6); }')
    [void]$sb.AppendLine('.cd-notes { white-space: pre-wrap; font-size: var(--text-xs); color: var(--primary-6); max-height: 320px; overflow: auto; }')
    [void]$sb.AppendLine('.cd-status { display: inline-flex; align-items: center; gap: var(--spacing-1-5); }')
    [void]$sb.AppendLine('.table td.cd-left, .table th.cd-left { text-align: left; }')
    # Fixed layout, so each group's table takes these widths rather than sizing to its own content; the min-width keeps them readable, scrolling inside .table-wrap on a narrow screen.
    [void]$sb.AppendLine('.cd-overview { table-layout: fixed; width: 100%; min-width: 860px; }')
    [void]$sb.AppendLine('.cd-overview td { overflow-wrap: anywhere; }')
    [void]$sb.AppendLine('.cd-col-repo { width: 30%; } .cd-col-status { width: 20%; } .cd-col-vis { width: 12%; } .cd-col-num { width: 8%; } .cd-col-ver { width: 14%; }')
    [void]$sb.AppendLine('@media (max-width: 760px) { main { padding-left: var(--spacing-4); padding-right: var(--spacing-4); } }')
    [void]$sb.AppendLine('</style>')
    [void]$sb.AppendLine('</head>')
    [void]$sb.AppendLine('<body>')
    [void]$sb.AppendLine('<div class="cd-band" aria-hidden="true"></div>')
    [void]$sb.AppendLine('<main>')
    [void]$sb.AppendLine('<header class="cd-head">')
    [void]$sb.AppendLine('<div><h1>dkj-claude-plugins</h1>')
    $commit = if ($Meta.SourceCommit) { ' &#183; source at <code>' + (& $e $Meta.SourceCommit) + '</code>' } else { '' }
    [void]$sb.AppendLine('<p class="sub">Every repo registered under <code>connectors/</code>, as <code>check-connectors.ps1</code> reports it on this machine' + $commit + '.</p></div>')
    [void]$sb.AppendLine('<div class="controls"><a class="btn btn--primary" href="/refresh">Re-run the check</a></div>')
    [void]$sb.AppendLine('</header>')
    [void]$sb.AppendLine('<div id="settings" class="theme-settings--floating"></div>')

    if ($Meta.CheckFailed) {
        [void]$sb.AppendLine('<div class="notice">check-connectors.ps1 could not be run: ' + (& $e $Meta.CheckFailed) + '. The register is shown without its signals.</div>')
    }

    [void]$sb.AppendLine('<div class="tiles">')
    foreach ($t in @(
            @{ L = 'Registered repos'; V = $all.Count },
            @{ L = 'Checked out here'; V = $present },
            @{ L = 'Errors'; V = $errors },
            @{ L = 'Notes'; V = $infos })) {
        [void]$sb.AppendLine('<div class="tile"><div class="label">' + $t.L + '</div><div class="v num cd-figure">' + $t.V + '</div></div>')
    }
    [void]$sb.AppendLine('</div>')

    # Grouped by owner (BWJ, DKJ, other); inside a group worst first, then by name. An empty group is left out.
    $rank = @{ bad = 0; warn = 1; skip = 2; good = 3 }
    $sorted = @($all | Sort-Object @{ Expression = { $rank[[string]$_.Status] } }, @{ Expression = { [string]$_.Repo } })
    $groups = @(foreach ($g in @(Get-DashboardOwnerGroups)) {
            $members = @($sorted | Where-Object { (Get-ConnectorOwnerGroup ([string]$_.Repo)) -eq $g.Key })
            if ($members.Count) { @{ Key = $g.Key; Title = $g.Title; Members = $members } }
        })

    # The overview (headed Connected repos): one card, one table per group, the group named in its first column head.
    [void]$sb.AppendLine('<div class="card cd-accent"><h2>Connected repos</h2>')
    foreach ($g in $groups) {
        $members = $g.Members
        # One fixed column set for every group's table, so the columns line up from table to table.
        [void]$sb.AppendLine('<div class="table-wrap cd-table-gap"><table class="table cd-overview" id="overview-' + $g.Key + '"><colgroup><col class="cd-col-repo"><col class="cd-col-status"><col class="cd-col-vis"><col class="cd-col-num"><col class="cd-col-ver"><col class="cd-col-num"><col class="cd-col-num"></colgroup><thead class="cd-thead"><tr><th>' + $g.Title + '</th><th class="cd-left">Status</th><th>Visibility</th><th>Plugins</th><th class="cd-left">Installed</th><th>Errors</th><th>Notes</th></tr></thead><tbody>')
        foreach ($c in $members) {
            $b = Get-DashboardStatusBadge ([string]$c.Status)
            $anchor = 'repo-' + (([string]$c.Repo) -replace '[^A-Za-z0-9]+', '-').ToLowerInvariant()
            $nErr = @($c.Signals | Where-Object { $_.Level -eq 'ERROR' }).Count
            $nInf = @($c.Signals | Where-Object { $_.Level -eq 'INFO' }).Count
            [void]$sb.AppendLine('<tr><td><a class="cd-link" href="#' + $anchor + '">' + (& $e $c.Repo) + '</a></td>' +
                '<td class="cd-left"><span class="cd-status"><span class="badge badge--sm ' + $b.Class + '" aria-hidden="true">' + $b.Mark + '</span>' + $b.Word + '</span></td>' +
                '<td>' + (& $e $c.Visibility) + '</td>' +
                '<td>' + @($c.Plugins).Count + '</td>' +
                '<td class="cd-left">' + (Format-DashboardInstalledVersion $c) + '</td>' +
                '<td>' + $nErr + '</td><td>' + $nInf + '</td></tr>')
        }
        [void]$sb.AppendLine('</tbody></table></div>')
    }
    [void]$sb.AppendLine('</div>')

    # The per-repo details, a card of their own beside Connected repos, headed Issues: an h2, an h3 per group, and a house
    # mini-card per repo (a card inside a card).
    [void]$sb.AppendLine('<div class="card cd-accent" id="issues"><h2>Issues</h2>')
    foreach ($g in $groups) {
        $members = $g.Members
        [void]$sb.AppendLine('<h3 class="cd-subgroup" id="group-' + $g.Key + '">' + $g.Title + ' <span class="cd-group-count">' + $members.Count + '</span></h3>')
        foreach ($c in $members) {
            $b = Get-DashboardStatusBadge ([string]$c.Status)
            $anchor = 'repo-' + (([string]$c.Repo) -replace '[^A-Za-z0-9]+', '-').ToLowerInvariant()
            [void]$sb.AppendLine('<section class="mini-card cd-accent cd-repo-card" id="' + $anchor + '">')
            [void]$sb.AppendLine('<div class="cd-repo"><span class="badge ' + $b.Class + '" aria-hidden="true">' + $b.Mark + '</span><h4>' + (& $e $c.Repo) + '</h4></div>')
            $where = (@(Get-ConnectorCheckoutCandidates $c.Checkout) | ForEach-Object { '<code>' + (& $e $_) + '</code>' }) -join ' or '
            $ghUrl = 'https://github.com/' + (& $e $c.Repo)
            [void]$sb.AppendLine('<p class="sub">' + $b.Word + ' &#183; ' + (& $e $c.Visibility) + ' &#183; checkout ' + $where +
                ' &#183; <a class="cd-link" href="' + $ghUrl + '">GitHub</a> &#183; <code>connectors/' + (& $e $c.File) + '</code></p>')
            if ($c.Git -and $c.Git.Subject) {
                [void]$sb.AppendLine('<p class="meta" style="white-space: normal">Last commit on ' + (& $e $c.Git.Trunk) + ' ' + (& $e $c.Git.When) + ': ' + (& $e $c.Git.Subject) + '</p>')
            }
            [void]$sb.AppendLine('<div class="cd-plugins">')
            foreach ($p in @($c.Plugins)) {
                $n = @($p.Extensions).Count
                [void]$sb.AppendLine('<span><code>' + (& $e $p.Id) + '</code> &#183; ' + $n + ' lens' + $(if ($n -ne 1) { 'es' } else { '' }) + '</span>')
            }
            [void]$sb.AppendLine('</div>')
            $drift = Format-DashboardDrift $c.Drift
            if ($drift) { [void]$sb.AppendLine('<p class="meta" style="white-space: normal">' + $drift + '</p>') }
            $shown =@($c.Signals | Where-Object { $_.Level -eq 'ERROR' -or $_.Level -eq 'INFO' -or $_.Level -eq 'SKIP' })
            if ($shown.Count) {
                [void]$sb.AppendLine('<ul class="cd-signals">')
                foreach ($s in $shown) {
                    $cls = switch ($s.Level) { 'ERROR' { 'badge--bad' } 'INFO' { 'badge--warn' } default { 'badge--neutral' } }
                    $mk = switch ($s.Level) { 'ERROR' { '!' } 'INFO' { 'i' } default { '-' } }
                    $who = if ($s.Plugin) { '<code>' + (& $e $s.Plugin) + '</code> ' } else { '' }
                    [void]$sb.AppendLine('<li><span class="badge badge--sm ' + $cls + '" aria-label="' + $s.Level + '">' + $mk + '</span><span>' + $who + (& $e $s.Text) + '</span></li>')
                }
                [void]$sb.AppendLine('</ul>')
            } elseif ($c.Present) {
                $nOk = @($c.Signals | Where-Object { $_.Level -eq 'OK' }).Count
                [void]$sb.AppendLine('<p class="note">All ' + $nOk + ' checks pass.</p>')
            }
            if ($c.Notes) {
                [void]$sb.AppendLine('<details class="more"><summary>Register notes</summary><div class="cd-notes">' + (& $e $c.Notes) + '</div></details>')
            }
            [void]$sb.AppendLine('</section>')
        }
    }
    [void]$sb.AppendLine('</div>')

    $secs = if ($null -ne $Meta.Seconds) { ' in ' + ([double]$Meta.Seconds).ToString('0.0', [Globalization.CultureInfo]::InvariantCulture) + 's' } else { '' }
    [void]$sb.AppendLine('<p class="footer-note">Checked ' + (& $e $Meta.GeneratedAt) + $secs + '. Served on 127.0.0.1 only, by <code>scripts/dashboard/serve-connector-dashboard.ps1</code>.</p>')
    [void]$sb.AppendLine('</main>')
    [void]$sb.AppendLine('<script>DKJTheme.settings(document.getElementById("settings"), { label: "Settings", title: "Settings", theme: "Theme", reset: "Reset theme", light: "Light", dark: "Dark" });</script>')
    [void]$sb.AppendLine('</body>')
    [void]$sb.AppendLine('</html>')
    return $sb.ToString()
}
