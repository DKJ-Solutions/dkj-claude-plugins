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

    ONE FUNCTION HERE TOUCHES THE DISK: Resolve-ConnectorCheckout asks whether a candidate folder exists,
    because the server and scripts/dashboard/repo-session.ps1 (#3231) must resolve a checkout the same way.

    EVERY VALUE THAT REACHES THE PAGE IS ESCAPED. Manifest fields and git subjects come from other
    repositories, so they are text, never markup.

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/connector-dashboard.tests.ps1 --
    change one, run the other.
#>

# The plugin's page shell, for the house site header (Format-SiteHeaderHtml): this repo is its source, so it is read here.
. (Join-Path $PSScriptRoot '..\..\plugins\dkj-policy\hub\lib\general-pages-lib.ps1')

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

function Resolve-ConnectorCheckout {
    <#
        The first of a manifest's localCheckout candidates that is a folder on this machine, as a full path, or
        $null. The manifest is data from a public repo and git runs in the folder it names, so a candidate is
        held to check-connectors' own bound: relative to -Root, and resolving under -ScopeRoot.
    #>
    param([Parameter(Mandatory = $true)][string]$Root, [AllowNull()]$LocalCheckout, [Parameter(Mandatory = $true)][string]$ScopeRoot)
    foreach ($cand in @(Get-ConnectorCheckoutCandidates $LocalCheckout)) {
        if ([System.IO.Path]::IsPathRooted($cand)) { continue }
        $full = [System.IO.Path]::GetFullPath((Join-Path $Root $cand))
        if (-not (Test-DashboardCheckoutInScope -Full $full -ScopeRoot $ScopeRoot)) { continue }
        if (Test-Path -LiteralPath $full -PathType Container) { return $full }
    }
    return $null
}

function Resolve-ConnectorRepo {
    <#
        The registered repos a person means by -Name (#3231): the full 'owner/name', the name alone, the name
        without its 'dkj-' prefix, or the manifest's file name -- compared without case and without
        punctuation, so 'lifehub', 'life-hub' and 'dkj-lifehub' all name DKJ-Solutions/dkj-lifehub. Where no
        name matches whole, a name that CONTAINS it does. -Connectors are @{ Repo; File }; returns every match,
        so a caller can refuse an ambiguous one rather than guess.
    #>
    param([AllowEmptyCollection()][Parameter(Mandatory = $true)][object[]]$Connectors, [Parameter(Mandatory = $true)][string]$Name)
    $norm = { param($s) ((([string]$s).ToLowerInvariant() -replace '\.json$', '') -replace '[^a-z0-9]', '') }
    $want = & $norm $Name
    if (-not $want) { return @() }
    $keys = {
        param($c)
        $short = ([string]$c.Repo -split '/')[-1]
        @((& $norm $c.Repo), (& $norm $short), (& $norm ($short -replace '^dkj-', '')), (& $norm $c.File)) | Where-Object { $_ }
    }
    $all = @($Connectors | Where-Object { $_ })
    $exact = @($all | Where-Object { @(& $keys $_) -contains $want })
    if ($exact.Count) { return $exact }
    return @($all | Where-Object { @(& $keys $_ | Where-Object { $_.Contains($want) }).Count })
}

function ConvertTo-PowerShellLiteral {
    <#
        -Value as a single-quoted PowerShell string. PowerShell reads the typographic quotes U+2018 to U+201B as
        single quotes too, so each of them is doubled as well -- a Dutch prompt with "dossier's" written with a
        curly apostrophe would otherwise end the string there and run the rest as code.
    #>
    param([AllowEmptyString()][Parameter(Mandatory = $true)][string]$Value)
    $quotes = "['" + [char]0x2018 + [char]0x2019 + [char]0x201A + [char]0x201B + ']'
    return "'" + ([regex]::Replace($Value, $quotes, { param($m) $m.Value + $m.Value })) + "'"
}

function Format-RepoSessionCommand {
    <#
        The PowerShell line that opens Claude Code in one checkout (#3231), with -Prompt as its first message
        when one is given. The DKJ repos page shows it to copy; repo-session.ps1 runs it in a window of its own.
    #>
    param([Parameter(Mandatory = $true)][string]$Path, [AllowEmptyString()][string]$Prompt = '')
    $line = 'Set-Location -LiteralPath ' + (ConvertTo-PowerShellLiteral $Path) + '; claude'
    if ($Prompt) { $line += ' ' + (ConvertTo-PowerShellLiteral $Prompt) }
    return $line
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
    <#
        The groups in page order (DKJ, BWJ, Other; owner, October 26, 2026): each with its card label on /connectors,
        the heading of its own page at /connectors/<Key>, and whose repos it holds.
    #>
    return @(
        @{ Key = 'dkj';   Label = 'DKJ';   Title = 'DKJ repos';   Owner = 'owned by DKJ-Solutions' },
        @{ Key = 'bwj';   Label = 'BWJ';   Title = 'BWJ repos';   Owner = 'owned by BWJ-Development' },
        @{ Key = 'other'; Label = 'Other'; Title = 'Other repos'; Owner = 'owned by anyone else, a personal account included' })
}

function Format-DashboardGroupSummary {
    <# One line for a group: how many repos, then how many in each status, worst first -- '3 repos &#183; 1 needs action &#183; 2 in sync'. #>
    param([AllowEmptyCollection()][AllowNull()][object[]]$Members)
    $all = @($Members | Where-Object { $_ })
    $parts = @("$($all.Count) repo" + $(if ($all.Count -ne 1) { 's' } else { '' }))
    foreach ($s in @(
            @{ Key = 'bad';  One = 'needs action';        Many = 'need action' },
            @{ Key = 'warn'; One = 'has notes';           Many = 'have notes' },
            @{ Key = 'skip'; One = 'not on this machine'; Many = 'not on this machine' },
            @{ Key = 'good'; One = 'in sync';             Many = 'in sync' })) {
        $n = @($all | Where-Object { $(if ([string]$_.Status -in @('bad', 'warn', 'skip')) { [string]$_.Status } else { 'good' }) -eq $s.Key }).Count
        if ($n) { $parts += "$n " + $(if ($n -eq 1) { $s.One } else { $s.Many }) }
    }
    return ($parts -join ' &#183; ')
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

function Test-LensFilled {
    <#
        True when a repo lens says something beyond its scaffold: a line is left once the frontmatter, the HTML
        comments, the headings, the blockquotes and the blank lines are taken away. The VUL-IN marker cannot
        answer this, because a lens that has been filled in still carries it now and then (measured October 28,
        2026: xoxowildhearts' 05-06 lens holds 13 KB under a 'Specific to this repo (VUL-IN)' heading).
    #>
    param([AllowNull()][AllowEmptyString()][string]$Text)
    if (-not $Text) { return $false }
    $body = ($Text -replace '(?s)\A---\r?\n.*?\r?\n---\r?\n', '') -replace '(?s)<!--.*?-->', ''
    return [bool](@($body -split '\r?\n' | Where-Object { $_.Trim() -and $_ -notmatch '^\s*[#>]' }).Count)
}

function Format-DashboardBytes {
    <# A size as the page prints it: bytes under 1 KB, else whole KB. #>
    param([int64]$Bytes)
    if ($Bytes -lt 1024) { return "$Bytes B" }
    return ([math]::Round($Bytes / 1024)).ToString([Globalization.CultureInfo]::InvariantCulture) + ' KB'
}

function Get-CheckoutLenses {
    <#
        A DKJ repo page's Lenses (Maikel, October 28, 2026): each specialist-<id>-lens.md in -Path's
        .claude/specialists/lenses/ with its size, whether it is filled in (Test-LensFilled) and whether it still
        carries VUL-IN; $null where -Path is empty or holds no lens folder. A lens that cannot be read counts as a
        scaffold. The server reads it on every request -- one folder of small files -- and hands the answer to
        Format-RepoLensesCardHtml. THIS FUNCTION READS THE DISK, unlike the formatters beside it.
    #>
    param([AllowEmptyString()][string]$Path)
    if (-not $Path) { return $null }
    $dir = Join-Path $Path '.claude\specialists\lenses'
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { return $null }
    $lenses = @()
    foreach ($f in @(Get-ChildItem -LiteralPath $dir -File -Filter 'specialist-*-lens.md' -ErrorAction SilentlyContinue | Sort-Object Name)) {
        if ($f.Name -notmatch '^specialist-(\d\d-\d\d)-lens\.md\z') { continue }
        $id = $Matches[1]
        $text = ''
        try { $text = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8) } catch { $text = '' }
        $lenses += @{ Id = $id; Bytes = [int64]$f.Length; Filled = (Test-LensFilled $text); Marked = $text.Contains('VUL-IN') }
    }
    # The comma keeps an empty folder an empty list rather than $null, which would read as no folder at all.
    return , $lenses
}

function Format-RepoLensesCardHtml {
    <#
        The Lenses card on a DKJ repo's own page, /connectors/dkj/<name> (Maikel, October 28, 2026): what the
        checkout's .claude/specialists/lenses/ holds. -Lenses is a list of @{ Id; Bytes; Filled; Marked }, or
        $null where there is no checkout here or it has no lens folder; -Names maps an id to its specialist's
        name, and an id it lacks is shown bare. The filled-in lenses (Test-LensFilled) are a table, big to
        small (Maikel, the same day), and a lens filled in yet still marked VUL-IN is tagged; the scaffolds
        are one line under it. Returns @{ Html; Style }, the server reading the disk so this stays a pure
        function.
    #>
    param(
        [AllowNull()][AllowEmptyCollection()][object[]]$Lenses,
        [hashtable]$Names = @{}
    )
    $e = { param($v) ConvertTo-DashboardText $v }
    $nameOf = { param($id) if ($Names.ContainsKey($id) -and $Names[$id]) { [string]$Names[$id] } else { '' } }
    $all = @($Lenses | Where-Object { $_ })
    $filled = @($all | Where-Object { $_.Filled } | Sort-Object @{ Expression = { [int64]$_.Bytes }; Descending = $true }, @{ Expression = { [string]$_.Id } })
    $scaffolds = @($all | Where-Object { -not $_.Filled } | Sort-Object @{ Expression = { [string]$_.Id } })
    # Summed by hand: Measure-Object -Property reads no hashtable key in Windows PowerShell 5.1.
    $bytes = [int64]0; foreach ($l in $filled) { $bytes += [int64]$l.Bytes }
    $summary = if ($null -eq $Lenses) { 'Not read on this machine' }
               else { "$($all.Count) lens" + $(if ($all.Count -ne 1) { 'es' } else { '' }) + " &#183; $($filled.Count) filled in" + $(if ($filled.Count) { ' &#183; ' + (Format-DashboardBytes $bytes) } else { '' }) }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<div class="grid-2" id="lenses">')
    [void]$sb.AppendLine('<div class="grid__head"><h2>Lenses</h2><p class="card__sub">' + $summary + '</p></div>')
    [void]$sb.AppendLine('<section class="card grid__full">')
    [void]$sb.AppendLine('<div>')
    if ($null -eq $Lenses) {
        [void]$sb.AppendLine('<p class="note">No checkout of this repo on this machine holds <code>.claude/specialists/lenses/</code>.</p>')
    } elseif (-not $all.Count) {
        [void]$sb.AppendLine('<p class="note">Its <code>.claude/specialists/lenses/</code> holds no lens.</p>')
    } else {
        if ($filled.Count) {
            [void]$sb.AppendLine('<div class="table-wrap cd-table-gap"><table class="table cd-lenses"><colgroup><col class="cd-col-id"><col><col class="cd-col-size"></colgroup><thead class="cd-thead"><tr><th class="cd-left">Lens</th><th class="cd-left">Specialist</th><th>Size</th></tr></thead><tbody>')
            foreach ($l in $filled) {
                $mark = if ($l.Marked) { ' <span class="tag tag--warn" title="Filled in, and still marked VUL-IN">VUL-IN</span>' } else { '' }
                [void]$sb.AppendLine('<tr><td class="cd-left"><code>' + (& $e $l.Id) + '</code></td><td class="cd-left">' + (& $e (& $nameOf ([string]$l.Id))) + $mark + '</td><td>' + (Format-DashboardBytes ([int64]$l.Bytes)) + '</td></tr>')
            }
            [void]$sb.AppendLine('</tbody></table></div>')
        } else {
            [void]$sb.AppendLine('<p class="note">Every lens is still its scaffold.</p>')
        }
        if ($filled.Count -and $scaffolds.Count) {
            $list = ($scaffolds | ForEach-Object { $n = & $nameOf ([string]$_.Id); '<code>' + (& $e $_.Id) + '</code>' + $(if ($n) { ' ' + (& $e $n) } else { '' }) }) -join ', '
            [void]$sb.AppendLine('<p class="meta cd-scaffolds">Scaffolds only (' + $scaffolds.Count + '): ' + $list + '</p>')
        }
    }
    [void]$sb.AppendLine('</div>')
    [void]$sb.AppendLine('</section>')
    [void]$sb.AppendLine('</div>')

    $style = @(
        '.cd-lenses { table-layout: fixed; width: 100%; max-width: 640px; }',
        '.cd-col-id { width: 6rem; } .cd-col-size { width: 6rem; }',
        '.cd-lenses td:last-child { font-variant-numeric: tabular-nums; }',
        '.cd-scaffolds { white-space: normal; margin-top: var(--spacing-3); }') -join "`r`n"
    return @{ Html = $sb.ToString(); Style = $style }
}

function Format-ConnectorPageStart {
    <#
        A connector page up to and including its h1: the head with the repo layer's style (-Style added to it),
        the hub's banner, the site header, the trail from Home through -Trail (a list of @{ Href; Label }) to
        -PageName, and the intro holding the h1. Format-ConnectorPageEnd closes it.
    #>
    param([Parameter(Mandatory = $true)][string]$PageName, [AllowEmptyCollection()][object[]]$Trail = @(), [AllowEmptyString()][string]$Style = '')
    $e = { param($v) ConvertTo-DashboardText $v }
    $name = & $e $PageName
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<!doctype html>')
    [void]$sb.AppendLine('<html lang="en" data-theme-default="lilac" data-width-default="full" data-theme-key="general-pages">')
    [void]$sb.AppendLine('<head>')
    [void]$sb.AppendLine('<meta charset="utf-8">')
    [void]$sb.AppendLine('<meta name="viewport" content="width=device-width, initial-scale=1">')
    [void]$sb.AppendLine('<title>dkj-claude-plugins -- ' + $name + '</title>')
    [void]$sb.AppendLine('<link rel="stylesheet" href="/house-style.css">')
    [void]$sb.AppendLine('<script src="/house-theme.js"></script>')
    # The repo layer: only names the house file does not define (.cd-*), spaced from the house scale.
    # The page keeps the hub's frame (breadcrumb bar, settings button, intro, page column; #3066), so
    # this layer styles only what is inside its cards, never the blocks the house style fixes.
    [void]$sb.AppendLine('<style>')
    # The links take the house highlight (--primary), the tinted head and the lines --paper-3, and the notes --muted.
    [void]$sb.AppendLine('.cd-link { color: var(--primary); text-underline-offset: 2px; }')
    [void]$sb.AppendLine('.cd-thead th { background: var(--paper-3); }')
    [void]$sb.AppendLine('.cd-table-gap { margin-top: var(--spacing-4); }')
    [void]$sb.AppendLine('.cd-repo-card { margin-top: var(--spacing-3); background: var(--paper-1); }')
    [void]$sb.AppendLine('.cd-group-summary { margin: 0 0 var(--spacing-1); }')
    [void]$sb.AppendLine('.cd-repo { display: flex; align-items: center; gap: var(--spacing-2); }')
    [void]$sb.AppendLine('.cd-repo__name { margin: 0; font-weight: 600; }')
    [void]$sb.AppendLine('.cd-signals { list-style: none; padding: 0; margin: var(--spacing-2) 0 0; }')
    [void]$sb.AppendLine('.cd-signals li { display: flex; gap: var(--spacing-2); align-items: flex-start; padding: var(--spacing-1-5) 0; border-top: 1px solid var(--paper-3); font-size: var(--text-sm); }')
    [void]$sb.AppendLine('.cd-signals li .badge { margin-top: 1px; }')
    [void]$sb.AppendLine('.cd-signals code, .cd-plugins code { font-size: var(--text-xs); }')
    [void]$sb.AppendLine('.cd-plugins { display: flex; flex-wrap: wrap; gap: var(--spacing-1-5) var(--spacing-4); margin-top: var(--spacing-2); font-size: var(--text-sm); color: var(--muted); }')
    [void]$sb.AppendLine('.cd-status { display: inline-flex; align-items: center; gap: var(--spacing-1-5); }')
    [void]$sb.AppendLine('.table td.cd-left, .table th.cd-left { text-align: left; }')
    # Fixed layout, so the table takes these widths rather than sizing to its own content; the min-width keeps them readable, scrolling inside .table-wrap on a narrow screen.
    [void]$sb.AppendLine('.cd-overview { table-layout: fixed; width: 100%; min-width: 860px; }')
    [void]$sb.AppendLine('.cd-overview td { overflow-wrap: anywhere; }')
    if ($Style) { [void]$sb.AppendLine($Style) }
    [void]$sb.AppendLine('.cd-col-repo { width: 36%; } .cd-col-status { width: 24%; } .cd-col-vis { width: 14%; } .cd-col-num { width: 10%; } .cd-col-ver { width: 16%; }')
    [void]$sb.AppendLine('</style>')
    [void]$sb.AppendLine('</head>')
    [void]$sb.AppendLine('<body>')
    # The hub's general banner first, above the site header, as on every other hub page (#3297, #3356; owner, October 24, 2026).
    [void]$sb.AppendLine((Format-RepoHubBanner))
    # The house site header, holding the settings button, then the breadcrumb bar under it: its trail from Home to this page.
    # Tagged 'product': this page is the product's, beside the plugin's hub (#3540).
    [void]$sb.Append((Format-SiteHeaderHtml -Name 'dkj-claude-plugins' -Href '/' -Tag 'product'))
    [void]$sb.AppendLine('<div class="breadcrumbs-bar"><div class="container"><nav class="breadcrumbs" aria-label="Breadcrumb"><ol>')
    $sep = '<span class="breadcrumbs__sep" aria-hidden="true"><svg viewBox="0 0 24 24"><path fill="currentColor" fill-rule="evenodd" d="M9.793 16.707a1 1 0 0 1 0-1.414L13.086 12 9.793 8.707a1 1 0 0 1 1.414-1.414l4 4a1 1 0 0 1 0 1.414l-4 4a1 1 0 0 1-1.414 0" clip-rule="evenodd"/></svg></span>'
    [void]$sb.AppendLine('<li><a href="/">Home</a></li>')
    foreach ($t in @($Trail | Where-Object { $_ })) { [void]$sb.AppendLine('<li>' + $sep + '<a href="' + (& $e $t.Href) + '">' + (& $e $t.Label) + '</a></li>') }
    [void]$sb.AppendLine('<li>' + $sep + '<span aria-current="page">' + $name + '</span></li>')
    [void]$sb.AppendLine('</ol></nav></div></div>')
    [void]$sb.AppendLine('<main class="page-column">')

    # The intro is a <div>, never a <header>, which the house style lays out as a flex row.
    [void]$sb.AppendLine('<div>')
    # The h1 alone: no lead and no tiles, on the overview or a group's page (owner, October 26, 2026). The cards and
    # the group summary lines carry the counts.
    [void]$sb.AppendLine('<h1>' + $name + '</h1>')
    [void]$sb.AppendLine('</div>')
    return $sb.ToString()
}

function Format-ConnectorPageEnd {
    <# A connector page's closing lines, after Format-ConnectorPageStart: -FooterHtml (the caller's own markup) as its footer note. #>
    param([AllowEmptyString()][string]$FooterHtml = '')
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<p class="footer-note">' + $FooterHtml + '</p>')
    [void]$sb.AppendLine('</main>')
    [void]$sb.AppendLine('<script>DKJTheme.settings(document.getElementById("settings"), { label: "Settings", title: "Settings", theme: "Theme", reset: "Reset theme", light: "Light", dark: "Dark", width: "Width", fluid: "Fluid", phone: "Phone", full: "Full" });</script>')
    # The fit alarm, as the plugin's page shell closes every hub page (#3558).
    [void]$sb.AppendLine((Format-FitAlarmHtml))
    [void]$sb.AppendLine('</body>')
    [void]$sb.AppendLine('</html>')
    return $sb.ToString()
}

function Format-ConnectorRepoMiniCardHtml {
    <#
        One registered repo's details as a house mini-card: its status, visibility, checkout, GitHub link and
        manifest, and what the check says about it (Format-ConnectorRepoDetailsHtml). A group's Issues card holds one
        per repo, and a DKJ repo's own page holds its own (Format-DkjRepoPageHtml). -Connector is one of
        Format-ConnectorDashboardHtml's -Connectors.
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Connector)
    $e = { param($v) ConvertTo-DashboardText $v }
    $c = $Connector
    $sb = New-Object System.Text.StringBuilder
    $b = Get-DashboardStatusBadge ([string]$c.Status)
    $anchor = 'repo-' + (([string]$c.Repo) -replace '[^A-Za-z0-9]+', '-').ToLowerInvariant()
    [void]$sb.AppendLine('<section class="mini-card cd-repo-card" id="' + $anchor + '">')
    [void]$sb.AppendLine('<div class="cd-repo"><span class="badge ' + $b.Class + '" aria-hidden="true">' + $b.Mark + '</span><p class="cd-repo__name">' + (& $e $c.Repo) + '</p></div>')
    $where = (@(Get-ConnectorCheckoutCandidates $c.Checkout) | ForEach-Object { '<code>' + (& $e $_) + '</code>' }) -join ' or '
    $ghUrl = 'https://github.com/' + (& $e $c.Repo)
    [void]$sb.AppendLine('<p class="sub">' + $b.Word + ' &#183; ' + (& $e $c.Visibility) + ' &#183; checkout ' + $where +
        ' &#183; <a class="cd-link" href="' + $ghUrl + '">GitHub</a> &#183; <code>connectors/' + (& $e $c.File) + '</code></p>')
    [void]$sb.Append((Format-ConnectorRepoDetailsHtml -Connector $c))
    [void]$sb.AppendLine('</section>')
    return $sb.ToString()
}

function Format-ConnectorRepoDetailsHtml {
    <#
        What the register's check says about one repo, under the line that names it: its trunk's last commit, its
        plugins with their lens counts, the drift, and the check's findings (or that every check passes). The register's
        notes are not shown: they are the register's own log, for whoever keeps it (connectors/README.md), and run to
        tens of kilobytes a repo (Maikel, October 28, 2026). A group's mini-card (Format-ConnectorRepoMiniCardHtml) and a DKJ repo's own Repo
        card (Format-DkjRepoCardHtml, Maikel, October 28, 2026) both hold it.
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Connector)
    $e = { param($v) ConvertTo-DashboardText $v }
    $c = $Connector
    $sb = New-Object System.Text.StringBuilder
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
    return $sb.ToString()
}

function Format-ConnectorDashboardHtml {
    <#
        The whole page. -Connectors is a list of @{ Repo; Visibility; File; Checkout; Present; Plugins
        (list of @{ Id; Extensions }); Signals; Drift (see ConvertFrom-ConnectorCheckOutput, or $null); Status; Git (@{ Branch; Trunk; Subject; When }
        or $null) }. -Meta is @{ GeneratedAt; Seconds; CheckFailed }.
        It is the Connectors page under the hub on '/' (#3097): a two-crumb trail and its own h1. The
        facts card belongs to the hub, so this page ends on its footer note.

        -Group splits it in two (owner, October 26, 2026). Empty, it is /connectors: the tiles over every repo and
        one card per owner group (Get-DashboardOwnerGroups), each linking that group's page. A group's Key, it is
        /connectors/<Key>: a three-crumb trail, the tiles over that group, its overview table and its repo cards.

        The server serves the DKJ group its own page instead (Format-DkjReposPageHtml, Maikel, October 28, 2026):
        a card per DKJ repo, each opening that repo's page. -Group 'dkj' still renders here, as any group does.
        The frame -- head, banner, header, trail, h1 and the closing lines -- is Format-ConnectorPageStart and
        Format-ConnectorPageEnd, which the DKJ pages share. A repo's mini-card is Format-ConnectorRepoMiniCardHtml.
    #>
    param(
        [AllowEmptyCollection()][Parameter(Mandatory = $true)][object[]]$Connectors,
        [Parameter(Mandatory = $true)][hashtable]$Meta,
        [ValidateSet('', 'dkj', 'bwj', 'other')][AllowEmptyString()][string]$Group = ''
    )
    $groupDef = if ($Group) { @(Get-DashboardOwnerGroups | Where-Object { $_.Key -eq $Group })[0] } else { $null }
    $pageName = if ($groupDef) { $groupDef.Title } else { 'Connectors' }
    $e = { param($v) ConvertTo-DashboardText $v }
    $everyone = @($Connectors | Where-Object { $_ })
    $all = if ($groupDef) { @($everyone | Where-Object { (Get-ConnectorOwnerGroup ([string]$_.Repo)) -eq $Group }) } else { $everyone }

    $sb = New-Object System.Text.StringBuilder
    $trail = if ($groupDef) { @(@{ Href = '/connectors'; Label = 'Connectors' }) } else { @() }
    [void]$sb.Append((Format-ConnectorPageStart -PageName $pageName -Trail $trail))

    # The warning that the signals could not be read.
    if ($Meta.CheckFailed) {
        [void]$sb.AppendLine('<p class="msg msg--warn" role="alert">check-connectors.ps1 could not be run: ' + (& $e $Meta.CheckFailed) + '. The register is shown without its signals.</p>')
    }

    # /connectors: one card per owner group, three to a row in the hub's card form (Format-HubCardLinkHtml), each
    # linking its group's page with that group's summary under the label. An empty group keeps its card ('0 repos').
    if (-not $groupDef) {
        [void]$sb.AppendLine('<div class="grid-3" id="groups">')
        foreach ($g in @(Get-DashboardOwnerGroups)) {
            $members = @($all | Where-Object { (Get-ConnectorOwnerGroup ([string]$_.Repo)) -eq $g.Key })
            # The hub's card (Format-HubCardLinkHtml), its label an h2 (owner, October 26, 2026). The summary is this
            # file's own markup.
            [void]$sb.AppendLine((Format-HubCardLinkHtml -Href ('/connectors/' + $g.Key) -Label $g.Label -SubHtml (Format-DashboardGroupSummary $members) -Heading 2))
        }
        [void]$sb.AppendLine('</div>')
    } else {
        # A group's page: worst first, then by name.
        $rank = @{ bad = 0; warn = 1; skip = 2; good = 3 }
        $members = @($all | Sort-Object @{ Expression = { $rank[[string]$_.Status] } }, @{ Expression = { [string]$_.Repo } })
        $g = $groupDef

        # The overview (headed Connected repos): one card holding the group's table, the group named in its first column head.
        [void]$sb.AppendLine('<div class="grid-2" id="overview">')
        [void]$sb.AppendLine('<div class="grid__head"><h2>Connected repos</h2><p class="card__sub">Worst first</p></div>')
        [void]$sb.AppendLine('<section class="card grid__full">')
        [void]$sb.AppendLine('<div>')
        if (-not $members.Count) {
            [void]$sb.AppendLine('<p class="note">No repo ' + $g.Owner + ' is registered under <code>connectors/</code>.</p>')
        } else {
            # A fixed column set, so the widths hold whatever the repo names are.
            [void]$sb.AppendLine('<div class="table-wrap cd-table-gap"><table class="table cd-overview" id="overview-' + $g.Key + '"><colgroup><col class="cd-col-repo"><col class="cd-col-status"><col class="cd-col-vis"><col class="cd-col-num"><col class="cd-col-ver"></colgroup><thead class="cd-thead"><tr><th>' + $g.Title + '</th><th class="cd-left">Status</th><th>Visibility</th><th>Plugins</th><th class="cd-left">Installed</th></tr></thead><tbody>')
            foreach ($c in $members) {
                $b = Get-DashboardStatusBadge ([string]$c.Status)
                $anchor = 'repo-' + (([string]$c.Repo) -replace '[^A-Za-z0-9]+', '-').ToLowerInvariant()
                [void]$sb.AppendLine('<tr><td><a class="cd-link" href="#' + $anchor + '">' + (& $e $c.Repo) + '</a></td>' +
                    '<td class="cd-left"><span class="cd-status"><span class="badge badge--sm ' + $b.Class + '" aria-hidden="true">' + $b.Mark + '</span>' + $b.Word + '</span></td>' +
                    '<td>' + (& $e $c.Visibility) + '</td>' +
                    '<td>' + @($c.Plugins).Count + '</td>' +
                    '<td class="cd-left">' + (Format-DashboardInstalledVersion $c) + '</td></tr>')
            }
            [void]$sb.AppendLine('</tbody></table></div>')
        }
        [void]$sb.AppendLine('</div>')
        [void]$sb.AppendLine('</section>')
        [void]$sb.AppendLine('</div>')

        # The per-repo details, a card of their own beside Connected repos, headed Issues: an h2, the group's summary line,
        # and a house mini-card per repo (a card inside a card). The overview links down to it, so its head carries the way
        # back. A group with no repo has no details.
        if ($members.Count) {
            [void]$sb.AppendLine('<div class="grid-2" id="issues">')
            [void]$sb.AppendLine('<div class="grid__head"><h2>Issues</h2><p class="card__sub">What the check reports per repo</p><a class="btn" href="#overview">Back to overview</a></div>')
            [void]$sb.AppendLine('<section class="card grid__full">')
            [void]$sb.AppendLine('<div id="group-' + $g.Key + '">')
            [void]$sb.AppendLine('<p class="sub cd-group-summary">' + (Format-DashboardGroupSummary $members) + '</p>')
            foreach ($c in $members) { [void]$sb.Append((Format-ConnectorRepoMiniCardHtml -Connector $c)) }
            [void]$sb.AppendLine('</div>')
            [void]$sb.AppendLine('</section>')
            [void]$sb.AppendLine('</div>')
        }
    }

    # Where the data comes from, with the way to read it again: the refresh comes back to this same page.
    $secs = if ($null -ne $Meta.Seconds) { ' in ' + ([double]$Meta.Seconds).ToString('0.0', [Globalization.CultureInfo]::InvariantCulture) + 's' } else { '' }
    $back = if ($groupDef) { 'connectors/' + $Group } else { 'connectors' }
    [void]$sb.Append((Format-ConnectorPageEnd -FooterHtml ('Read from <code>check-connectors.ps1</code>, checked ' + (& $e $Meta.GeneratedAt) + $secs + ' (<a class="cd-link" href="/refresh?page=' + $back + '">re-run the check</a>). Served on 127.0.0.1 only, by <code>scripts/dashboard/serve-connector-dashboard.ps1</code>.')))
    return $sb.ToString()
}
