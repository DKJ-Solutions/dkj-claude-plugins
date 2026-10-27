<#
.SYNOPSIS
    The Test gate page of every repo's hub (#3097; in dkj-policy since #3470): what each test suite costs on CI,
    grouped by the workflow step it guards, read from the repo's own scripts/tests/suite-durations.json.

.DESCRIPTION
    NO I/O BUT Read-TestGateModel, which reads the repo's files for either server (serve-general-pages.ps1 in every
    repo, the source repo's own hub there) and hands the parsed JSON to the pure functions, so every rule is tested
    without a server.

    THE DATA IS THE REPO'S OWN, NOT A SECOND MEASUREMENT: scripts/tests/suite-durations.json, and where the repo keeps
    one, scripts/tests/suite-groups.json to group the suites by the workflow step each guards. Any repo writes the
    first with the plugin's record-suite-durations.ps1 from CI runs (its record-suite-durations skill, #3474). A repo without that file
    gets the page anyway, saying no test gate has been measured here yet: every hub has the card, the owner's choice
    on #3470.

    A SECTION ONLY THE SOURCE REPO HAS: what this checkout's change selects (-Selection), built by its own hub from
    the affected-suite selection open-pr and its CI check run. The plugin's server passes none, and the page leaves
    the section out.

    Every value that reaches the page is escaped through the general pages' ConvertTo-GeneralPageText, and the shell
    is theirs (Format-GeneralPageHtml), so a caller loads general-pages-lib.ps1, beside this file, first. Pure ASCII
    (repo convention for .ps1). Tested by scripts/tests/dev-pages.tests.ps1 in the source repo.
#>
function Get-SuiteSynopsis {
    <#
        What a suite protects, in its own words: the paragraph under '.SYNOPSIS' in its header, on one line
        and capped at -Max characters. '' when the file has no synopsis. Every suite here has one (#3309,
        lever 3: the per-suite overview reads it rather than keeping a second description that would drift).
    #>
    param([AllowEmptyString()][string]$Text, [int]$Max = 260)
    $m = [regex]::Match($Text, '(?ms)^\s*\.SYNOPSIS[ \t]*\r?\n(.*?)(?:\r?\n[ \t]*\r?\n|\r?\n\s*\.[A-Z]+|\r?\n\s*#>)')
    if (-not $m.Success) { return '' }
    $one = ($m.Groups[1].Value -replace '\s+', ' ').Trim()
    if ($one.Length -gt $Max) { $one = $one.Substring(0, $Max - 3).TrimEnd() + '...' }
    return $one
}

function ConvertFrom-SuiteDurations {
    <#
        The test-gate model from the parsed suite-durations.json (-Durations, $null when the file is
        missing or unreadable) and the suite file names in scripts/tests (-SuiteFiles). Returns
        @{ Suites (list of @{ Name; Seconds }, slowest first); Total; Missing (names on disk the file does
        not record); Stale (names the file records that are no longer on disk); Runs; Date; Machine; Method;
        Groups; Ungrouped; Unknown }.

        -Groups is the parsed groups array of suite-groups.json, $null when that file is missing or unreadable.
        Groups is then one @{ Key; Title; Guards; Tips; Split; Suites; Unmeasured; Total } per group, in the file's order,
        each holding its recorded suites slowest first and, in Unmeasured, its suites on disk with no recorded
        duration yet; Ungrouped names every suite on disk or recorded that no group holds, and Unknown every
        name a group holds that is not on disk. With no -Groups all three are empty.

        -Synopses maps a suite file name to what it protects (Get-SuiteSynopsis), passed through as Synopses.
    #>
    param($Durations, [AllowEmptyCollection()][string[]]$SuiteFiles = @(), $Groups = $null, [hashtable]$Synopses = @{})
    $suites = @()
    if ($Durations -and $Durations.seconds) {
        foreach ($p in $Durations.seconds.PSObject.Properties) {
            $suites += @{ Name = [string]$p.Name; Seconds = [double]$p.Value }
        }
    }
    $suites = @($suites | Sort-Object @{ Expression = { $_.Seconds }; Descending = $true }, @{ Expression = { $_.Name } })
    $recorded = @{}
    foreach ($s in $suites) { $recorded[$s.Name] = $true }
    $onDisk = @{}
    foreach ($f in @($SuiteFiles)) { if ($f) { $onDisk[$f] = $true } }
    $from = if ($Durations) { $Durations.recordedFrom } else { $null }
    $groupRows = @(); $grouped = @{}
    foreach ($g in @($Groups | Where-Object { $_ })) {
        $members = @{}
        foreach ($n in @($g.suites | Where-Object { $_ })) { $members[[string]$n] = $true; $grouped[[string]$n] = $true }
        $in = @($suites | Where-Object { $members.ContainsKey($_.Name) })
        $groupRows += @{
            Key      = [string]$g.key
            Title    = [string]$g.title
            Guards   = [string]$g.guards
            Tips     = @(@($g.tips) | Where-Object { $_ } | ForEach-Object { [string]$_ })
            Split    = [string]$g.split
            Suites   = $in
            Unmeasured = @(@($SuiteFiles) | Where-Object { $_ -and $members.ContainsKey($_) -and -not $recorded.ContainsKey($_) } | Sort-Object)
            Total  = [double](($in | ForEach-Object { $_.Seconds } | Measure-Object -Sum).Sum)
        }
    }
    $known = @(@($SuiteFiles | Where-Object { $_ }) + @($suites | ForEach-Object { $_.Name })) | Sort-Object -Unique
    return @{
        Groups    = $groupRows
        Ungrouped = @(if ($groupRows.Count) { $known | Where-Object { -not $grouped.ContainsKey($_) } })
        Unknown   = @(if ($onDisk.Count) { $grouped.Keys | Where-Object { -not $onDisk.ContainsKey($_) } | Sort-Object })
        Suites  = $suites
        Total   = [double](($suites | ForEach-Object { $_.Seconds } | Measure-Object -Sum).Sum)
        Missing = @(@($SuiteFiles) | Where-Object { $_ -and -not $recorded.ContainsKey($_) } | Sort-Object)
        Stale   = @(if ($onDisk.Count) { $suites | Where-Object { -not $onDisk.ContainsKey($_.Name) } | ForEach-Object { $_.Name } })
        Runs    = @(if ($from) { @($from.runs) | Where-Object { $_ } | ForEach-Object { [string]$_ } })
        Date    = if ($from) { [string]$from.date } else { '' }
        Machine = if ($from) { [string]$from.machine } else { '' }
        Method  = if ($from) { [string]$from.method } else { '' }
        Synopses = $Synopses
    }
}

function Get-TestGateLists {
    <#
        The suite lists the Test gate drills into, in order, each with a page of its own: one per group of the
        model, then 'ungrouped' for the suites no group holds; without groups one list, 'suites', of every
        recorded suite. Each is a group row as ConvertFrom-SuiteDurations builds it: @{ Key; Title; Guards;
        Tips; Split; Suites; Unmeasured; Total }. None when no suite is recorded.
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Model)
    $suites = @($Model.Suites)
    if (-not $suites.Count) { return @() }
    if (-not @($Model.Groups).Count) {
        return @(@{ Key = 'suites'; Title = 'All suites'; Guards = ''; Split = ''; Suites = $suites; Unmeasured = @($Model.Missing); Total = [double]$Model.Total
                Tips = @('Without scripts/tests/suite-groups.json the suites are listed in one list.') })
    }
    $lists = @($Model.Groups)
    $loose = @($suites | Where-Object { @($Model.Ungrouped) -contains $_.Name })
    $looseUnmeasured = @(@($Model.Ungrouped) | Where-Object { @($Model.Missing) -contains $_ })
    if ($loose.Count + $looseUnmeasured.Count) {
        $lists += @{ Key = 'ungrouped'; Title = 'Not grouped'; Guards = ''; Split = ''; Suites = $loose; Unmeasured = $looseUnmeasured
            Total = [double](($loose | ForEach-Object { $_.Seconds } | Measure-Object -Sum).Sum)
            Tips = @('Add each one to the group whose workflow step it guards, in scripts/tests/suite-groups.json.') }
    }
    return $lists
}

function Format-TestGatePageHtml {
    <#
        The Test gate pages from ConvertFrom-SuiteDurations' model, one screen each, drilled into by the crumbs
        (the owner, October 27, 2026: the one long page did not fit a screen of about 1300 x 900). -Path is the
        part after '/test-gate/', '' for the overview:

          ''                 the overview: the totals, and one card per suite list (Get-TestGateLists), plus the
                             change's card where -Selection is given and the measurement's card
          <list>             one list's page: its totals, its suites in tables of at most twelve rows side by side,
                             and its points to note
          <list>/<suite>     one suite's page: what it protects, what it costs, and where it ranks
          measured           where the durations were measured, and how to read them
          selection          what this checkout's change selects; only where -Selection is given

        $null for a path none of those names, which the server answers with a 404.

        -ReadError is set when suite-durations.json could not be read, -GroupsError when suite-groups.json could
        not be; without groups the suites are one list, 'suites'. A -ReadError of 'the file is not there' is the
        empty state: no test gate measured in this repo yet. -RepoName names the site in the page's header, -HubHref
        is where its Home crumb goes ('/hub' on the general pages server), and -RepoSlug (owner/name) links each
        recorded CI run on GitHub; without it a run is its number.

        -Selection is what this checkout's change selects (#3309, lever 3), $null to leave it out:
        @{ Base; Changed (paths); Proven; Reason; Selected (suite file names); Why (name -> sentence);
        PoolCount; CiText }. Built by the server from Get-AffectedSuiteSelection, the function open-pr runs,
        so the page shows the gate's own answer rather than a second reading of it.
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Model, [AllowEmptyString()][string]$ReadError = '', [AllowEmptyString()][string]$GroupsError = '', $Selection = $null,
        [AllowEmptyString()][string]$RepoName = '', [string]$HubHref = '/hub', [AllowEmptyString()][string]$RepoSlug = '', [AllowEmptyString()][string]$Path = '')
    $e = { param($v) ConvertTo-GeneralPageText $v }
    $inv = [Globalization.CultureInfo]::InvariantCulture
    $dot = ' ' + [char]0x00B7 + ' '
    $suites = @($Model.Suites)
    $slowest = if ($suites.Count) { $suites[0] } else { $null }
    $synopses = if ($Model.Synopses) { $Model.Synopses } else { @{} }
    $lists = @(Get-TestGateLists -Model $Model)
    $listOf = @{}
    foreach ($l in $lists) { foreach ($n in @(@($l.Suites | ForEach-Object { $_.Name }) + @($l.Unmeasured))) { if ($n -and -not $listOf.ContainsKey($n)) { $listOf[$n] = $l } } }
    $suiteHref = { param($List, $Name) '/test-gate/' + (& $e $List.Key) + '/' + (& $e $Name) }
    $pct = { param([double]$Part) if ($Model.Total -gt 0) { (100.0 * $Part / $Model.Total).ToString('0.0', $inv) + '%' } else { '0.0%' } }
    $bar = {
        param([double]$Part, [double]$Of)
        $w = if ($Of -gt 0) { [Math]::Min(100.0, [Math]::Max(0.0, 100.0 * $Part / $Of)).ToString('0.##', $inv) } else { '0' }
        '<span class="dp-bar" aria-hidden="true"><span style="width: ' + $w + '%"></span></span>'
    }
    $tipsCard = {
        param($Tips)
        $items = @(@($Tips) | Where-Object { $_ })
        if (-not $items.Count) { return '' }
        return '<section class="card tg-tips"><h3>Points to note</h3><ul>' + (($items | ForEach-Object { '<li>' + (& $e $_) + '</li>' }) -join '') + '</ul></section>'
    }
    $style = $script:DevBarStyle + "`n" +
        '.tg-cards { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: var(--spacing-4); }' + "`n" +
        # A list's page: its tables side by side (--tg-cols of them) at their own width, and its totals and notes in the
        # column beside them, which takes whatever width the tables leave, so long notes stay short in height.
        '.tg-list { display: grid; grid-template-columns: repeat(var(--tg-cols, 1), max-content) minmax(260px, 1fr); gap: var(--spacing-4); align-items: start; }' + "`n" +
        '.tg-list > .card { margin-top: 0; }' + "`n" +
        '.tg-list .table td:first-child { white-space: nowrap; }' + "`n" +
        '.tg-cols { display: grid; grid-template-columns: repeat(auto-fit, minmax(360px, 1fr)); gap: var(--spacing-4); align-items: start; }' + "`n" +
        ':is(.tg-cards, .tg-cols) > .card { margin-top: 0; }' + "`n" +
        '.tg-card { padding: var(--spacing-3) var(--spacing-4); }' + "`n" +
        '.tg-card > h2 { margin: 0; font-size: var(--text-base); }' + "`n" +
        '.tg-card > h2 a { color: inherit; text-decoration: none; }' + "`n" +
        '.tg-card > p { margin: var(--spacing-1) 0 var(--spacing-2); }' + "`n" +
        '.tg-tips > h3 { margin-top: 0; }' + "`n" +
        '.tg-guards { margin: 0 0 var(--spacing-3); }' + "`n" +
        '.tg-tips > ul { margin: 0; padding-left: var(--spacing-5); }' + "`n" +
        '@media (max-width: 1000px) { .tg-cards { grid-template-columns: repeat(2, minmax(0, 1fr)); } .tg-list { grid-template-columns: 1fr; } }'
    $footer = 'Read from the repo''s <code>scripts/tests/suite-durations.json</code> on every request, grouped by its <code>scripts/tests/suite-groups.json</code> where it keeps one. Built by the dkj-policy plugin''s <code>hub/lib/test-gate-lib.ps1</code>.'
    # Under the hub's Clock page, beside the Stopwatch and the Logbook (the owner, October 27, 2026), on every level.
    $clock = @(@{ Label = 'Clock'; Href = '/clock' })
    $crumbs = @($clock) + @(@{ Label = 'Test gate'; Href = '/test-gate' })
    $page = {
        # The source note closes the overview and the measurement's page only: a page further down spends its height on its own content.
        param([string]$Title, [string]$Body, [string]$Lead = '', [object[]]$Parents = $crumbs, [string]$Footer = '', [string]$Aside = '')
        Format-GeneralPageHtml -Title $Title -Style $style -Body $Body -Lead $Lead -SiteName $RepoName -HubHref $HubHref -ParentCrumbs $Parents -FooterNote $Footer -HeadAside $Aside
    }
    $unmeasured = $ReadError -eq 'the file is not there'
    $parts = @($Path.Trim('/') -split '/' | Where-Object { $_ })
    $body = New-Object System.Text.StringBuilder

    # WHERE IT WAS MEASURED, and how to read every number on these pages.
    if ($parts.Count -eq 1 -and $parts[0] -ceq 'measured') {
        [void]$body.AppendLine('<div class="tg-cols">')
        [void]$body.AppendLine('<section class="card"><dl class="facts">')
        [void]$body.AppendLine('<div><dt>Recorded</dt><dd>' + $(if ($Model.Date) { & $e $Model.Date } else { '--' }) + '</dd></div>')
        [void]$body.AppendLine('<div><dt>Machine</dt><dd>' + $(if ($Model.Machine) { & $e $Model.Machine } else { '--' }) + '</dd></div>')
        [void]$body.AppendLine('<div><dt>Method</dt><dd>' + $(if ($Model.Method) { & $e $Model.Method } else { '--' }) + '</dd></div>')
        # A run links to the repo's own CI on GitHub, where the origin remote names it (owner/name), else it is its number.
        $slug = if ($RepoSlug -cmatch '^[A-Za-z0-9-]+/[A-Za-z0-9._-]+\z') { $RepoSlug } else { '' }
        $runs = (@($Model.Runs) | Where-Object { $_ -cmatch '^[0-9]+\z' } | ForEach-Object {
                if ($slug) { '<a class="dp-link" href="https://github.com/' + (& $e $slug) + '/actions/runs/' + $_ + '">' + $_ + '</a>' } else { $_ } }) -join ', '
        [void]$body.AppendLine('<div><dt>CI runs</dt><dd>' + $(if ($runs) { $runs } else { '--' }) + '</dd></div>')
        # The overview counts them in a tile; this is where they are named.
        if (@($Model.Missing).Count) {
            [void]$body.AppendLine('<div><dt>Not recorded yet</dt><dd>' + ((@($Model.Missing) | ForEach-Object { '<code>' + (& $e $_) + '</code>' }) -join ', ') + '</dd></div>')
        }
        [void]$body.AppendLine('</dl></section>')
        # The split candidates are the groups suite-groups.json gives a split for, largest first: which ones
        # is a judgement written into that file, and the counts beside them are measured here.
        $candidates = @(@($Model.Groups) | Where-Object { $_.Split } | Sort-Object @{ Expression = { $_.Total }; Descending = $true } | ForEach-Object {
                $_.Title + ' (' + (@($_.Suites).Count + @($_.Unmeasured).Count) + ' suites, ' +
                $(if ($Model.Total -gt 0) { (100.0 * $_.Total / $Model.Total).ToString('0', $inv) } else { '0' }) + '%)' })
        [void]$body.AppendLine((& $tipsCard @(
            'Measured on CI runners, never on a workstation: a local reading does not convert.',
            'A group says what breaks when its suites go red, not when they run.',
            'The seconds are summed as if every suite ran one after another. CI may split the suites over shards that run side by side, so it waits for the slowest shard, not for this sum.',
            'A suite not recorded yet is charged the largest recorded duration when the gate packs its shards, so a new suite starts early rather than last.',
            'Refresh the file from CI runs once a suite has been added or has grown, with the dkj-policy plugin''s record-suite-durations skill.',
            $(if ($candidates.Count) { 'Candidates to split, largest first: ' + ($candidates -join '; ') + '. Each one''s own notes say how. A split changes only how these pages read, never what runs.' }))))
        [void]$body.AppendLine('</div>')
        return & $page 'Where it was measured' $body.ToString() '' $crumbs $footer
    }

    # THIS CHECKOUT'S CHANGE: why am I waiting on these suites. Each row is the gate's own reason
    # (Get-AffectedSuiteSelection's Why).
    if ($parts.Count -eq 1 -and $parts[0] -ceq 'selection') {
        if ($null -eq $Selection) { return $null }
        $secondsOf = @{}
        foreach ($s in $suites) { $secondsOf[$s.Name] = $s.Seconds }
        $changed = @($Selection.Changed | Where-Object { $_ })
        [void]$body.AppendLine('<div class="tg-cols" id="selection">')
        [void]$body.AppendLine('<section class="card">')
        if (-not $changed.Count) {
            [void]$body.AppendLine('<p class="note">' + $(if ($Selection.Reason) { (& $e $Selection.Reason) + '.' } else { 'Nothing differs from the trunk, so nothing is selected.' }) + '</p>')
        } else {
            $shown = @($changed | Select-Object -First 12)
            [void]$body.AppendLine('<dl class="facts">')
            [void]$body.AppendLine('<div><dt>Changed</dt><dd>' + (($shown | ForEach-Object { '<code>' + (& $e $_) + '</code>' }) -join ', ') +
                $(if ($changed.Count -gt $shown.Count) { ' and ' + ($changed.Count - $shown.Count) + ' more' } else { '' }) + '</dd></div>')
            $local = if (-not $Selection.Proven) { 'every suite -- ' + (& $e $Selection.Reason) }
                     elseif (@($Selection.Selected).Count -ge $Selection.PoolCount) { 'every suite -- the change can affect all ' + $Selection.PoolCount }
                     else { '' + @($Selection.Selected).Count + ' of ' + $Selection.PoolCount + ' suites' }
            [void]$body.AppendLine('<div><dt>Locally</dt><dd>' + $local + '</dd></div>')
            if ($Selection.CiText) { [void]$body.AppendLine('<div><dt>On CI</dt><dd>' + (& $e $Selection.CiText) + '</dd></div>') }
            [void]$body.AppendLine('</dl>')
            if ($Selection.Proven -and @($Selection.Selected).Count) {
                # Keyed on the suite's path, which is unique; its file name is what the durations and the reader go by.
                $leafOf = { param($p) ($p -split '/')[-1] }
                $rows = @($Selection.Selected | Sort-Object @{ Expression = { $n = & $leafOf $_; if ($secondsOf.ContainsKey($n)) { $secondsOf[$n] } else { 0 } }; Descending = $true }, @{ Expression = { $_ } })
                $t = '<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">Suite</th><th class="dp-left">Why it runs</th><th>Seconds</th></tr></thead><tbody>' + "`n"
                foreach ($key in $rows) {
                    $n = & $leafOf $key
                    $name = if ($listOf.ContainsKey($n)) { '<a class="dp-link" href="' + (& $suiteHref $listOf[$n] $n) + '"><code>' + (& $e $n) + '</code></a>' } else { '<code>' + (& $e $n) + '</code>' }
                    $reason = if ($Selection.Why -and $Selection.Why.ContainsKey($key)) { $Selection.Why[$key] } else { '' }
                    $sec = if ($secondsOf.ContainsKey($n)) { ([double]$secondsOf[$n]).ToString('0.0', $inv) } else { '--' }
                    $t += '<tr><td class="dp-left">' + $name + '</td><td class="dp-left">' + (& $e $reason) + '</td><td class="num">' + $sec + '</td></tr>' + "`n"
                }
                [void]$body.AppendLine($t + '</tbody></table></div>')
            }
        }
        [void]$body.AppendLine('</section>')
        [void]$body.AppendLine((& $tipsCard @(
            'A suite runs locally when the change reaches a file it runs or names, when its declared walk scope covers a changed path, or when it walks the live tree with no declared scope.',
            'open-pr -AllSuites runs every suite regardless.')))
        [void]$body.AppendLine('</div>')
        $lead = 'The suites the affected-suite selection picks for it' + $(if ($Selection.Base) { ', against ' + (& $e $Selection.Base) } else { '' }) + ', and why each one is in.'
        return & $page 'This checkout''s change' $body.ToString() $lead
    }

    if ($parts.Count -ge 1) {
        $list = @($lists | Where-Object { $_.Key -ceq $parts[0] }) | Select-Object -First 1
        if (-not $list -or $parts.Count -gt 2) { return $null }
        $listCrumbs = @($crumbs) + @(@{ Label = $list.Title; Href = '/test-gate/' + $list.Key })

        # ONE SUITE: what it protects, what it costs, where it ranks.
        if ($parts.Count -eq 2) {
            $name = $parts[1]
            $row = @($list.Suites | Where-Object { $_.Name -ceq $name }) | Select-Object -First 1
            if (-not $row -and @($list.Unmeasured) -cnotcontains $name) { return $null }
            [void]$body.AppendLine('<div class="tg-cols">')
            [void]$body.AppendLine('<section class="card"><dl class="facts">')
            [void]$body.AppendLine('<div><dt>File</dt><dd><code>scripts/tests/' + (& $e $name) + '</code></dd></div>')
            [void]$body.AppendLine('<div><dt>' + $(if ($list.Key -eq 'ungrouped' -or $list.Key -eq 'suites') { 'Listed under' } else { 'Group' }) + '</dt><dd><a class="dp-link" href="/test-gate/' + (& $e $list.Key) + '">' + (& $e $list.Title) + '</a></dd></div>')
            if ($row) {
                $rank = [array]::IndexOf(@($suites | ForEach-Object { $_.Name }), $name) + 1
                [void]$body.AppendLine('<div><dt>Seconds on CI</dt><dd class="num">' + (Format-DevSeconds $row.Seconds) + '</dd></div>')
                [void]$body.AppendLine('<div><dt>Share of the sum</dt><dd class="num">' + (& $pct $row.Seconds) + '</dd></div>')
                [void]$body.AppendLine('<div><dt>Against the slowest</dt><dd>' + (& $bar $row.Seconds $slowest.Seconds) + '</dd></div>')
                [void]$body.AppendLine('<div><dt>Rank</dt><dd class="num">' + $rank + ' of ' + $suites.Count + ', slowest first</dd></div>')
                if (@($Model.Stale) -contains $name) { [void]$body.AppendLine('<div><dt>State</dt><dd><span class="badge badge--sm badge--neutral">no longer on disk</span></dd></div>') }
            } else {
                [void]$body.AppendLine('<div><dt>State</dt><dd><span class="badge badge--sm badge--neutral">not recorded yet</span></dd></div>')
            }
            [void]$body.AppendLine('</dl></section>')
            if (-not $row) { [void]$body.AppendLine((& $tipsCard @('Until it is recorded, the gate charges it the largest recorded duration when it packs its shards.'))) }
            [void]$body.AppendLine('</div>')
            $what = if ($synopses.ContainsKey($name) -and $synopses[$name]) { & $e $synopses[$name] } else { '' }
            return & $page $name $body.ToString() $what $listCrumbs
        }

        # ONE LIST: its suites in tables of at most twelve rows side by side, and beside them its totals and notes.
        $count = @($list.Suites).Count + @($list.Unmeasured).Count
        $rows = @(@($list.Suites | ForEach-Object { @{ Name = $_.Name; Seconds = $_.Seconds } }) + @(@($list.Unmeasured) | ForEach-Object { @{ Name = $_; Seconds = $null } }))
        $cols = [int][Math]::Ceiling($rows.Count / 12.0)
        $per = if ($cols) { [int][Math]::Ceiling($rows.Count / [double]$cols) } else { 0 }
        [void]$body.AppendLine('<div class="tg-list" style="--tg-cols: ' + [Math]::Max(1, $cols) + '">')
        if (-not $rows.Count) { [void]$body.AppendLine('<section class="card"><p class="note">No suite of this group is on disk.</p></section>') }
        for ($c = 0; $c -lt $cols; $c++) {
            $t = '<section class="card"><div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">Suite</th><th>Seconds</th><th class="dp-left">vs. slowest</th></tr></thead><tbody>' + "`n"
            foreach ($r in @($rows | Select-Object -Skip ($c * $per) -First $per)) {
                # Every suite's name ends in .tests.ps1, so the table leaves it off; the suite's own page names it whole.
                $link = '<a class="dp-link" href="' + (& $suiteHref $list $r.Name) + '" title="' + (& $e $r.Name) + '"><code>' + (& $e ($r.Name -replace '\.tests\.ps1\z', '')) + '</code></a>'
                if ($null -eq $r.Seconds) {
                    $t += '<tr><td class="dp-left">' + $link + ' <span class="badge badge--sm badge--neutral">not recorded yet</span></td><td class="num">--</td><td class="dp-left"></td></tr>' + "`n"
                } else {
                    $stale = if (@($Model.Stale) -contains $r.Name) { ' <span class="badge badge--sm badge--neutral">no longer on disk</span>' } else { '' }
                    $t += '<tr><td class="dp-left">' + $link + $stale + '</td><td class="num">' + ([double]$r.Seconds).ToString('0.0', $inv) + '</td><td class="dp-left">' + (& $bar $r.Seconds $slowest.Seconds) + '</td></tr>' + "`n"
                }
            }
            [void]$body.AppendLine($t + '</tbody></table></div></section>')
        }
        # The list's totals stand at the right of its h1, and what it guards opens its notes: one column of cards
        # beside the tables would be the tallest thing on the page.
        $notes = @(@($list.Tips) + @($(if ($list.Split) { 'Could be split into ' + $list.Split })) | Where-Object { $_ })
        if ($list.Guards -or $notes.Count) {
            [void]$body.AppendLine('<section class="card tg-tips">' + $(if ($list.Guards) { '<p class="tg-guards">Guards ' + (& $e $list.Guards) + '.</p>' } else { '' }) +
                $(if ($notes.Count) { '<h3>Points to note</h3><ul>' + (($notes | ForEach-Object { '<li>' + (& $e $_) + '</li>' }) -join '') + '</ul>' } else { '' }) + '</section>')
        }
        [void]$body.AppendLine('</div>')
        $facts = '<dl class="facts facts--row">' +
            '<div><dt>Suites</dt><dd class="num">' + $count + '</dd></div>' +
            '<div><dt>Sum, one after another</dt><dd class="num">' + (Format-DevSeconds $list.Total) + '</dd></div>' +
            '<div><dt>Share of all suites</dt><dd class="num">' + (& $pct $list.Total) + '</dd></div>' +
            '<div><dt>Slowest here</dt><dd class="num">' + (Format-DevSeconds $(if (@($list.Suites).Count) { @($list.Suites)[0].Seconds } else { $null })) + '</dd></div></dl>'
        return & $page $list.Title $body.ToString() '' $crumbs '' $facts
    }

    # THE OVERVIEW: one card per list, the change's and the measurement's, and no tiles above them (the owner,
    # October 27, 2026): each card carries its own sum and share, and the measurement's counts the unrecorded suites.
    if ($unmeasured) {
        [void]$body.AppendLine('<p class="msg" role="status">No test gate has been measured in this repo yet. This page fills in once the repo records its suites'' CI durations in <code>scripts/tests/suite-durations.json</code>, which the dkj-policy plugin''s <code>record-suite-durations</code> skill writes from CI runs.</p>')
    } elseif ($ReadError) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">scripts/tests/suite-durations.json could not be read: ' + (& $e $ReadError) + '.</p>')
    }
    if ($GroupsError) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">scripts/tests/suite-groups.json could not be read: ' + (& $e $GroupsError) + ', so the suites are listed ungrouped.</p>')
    }
    if (@($Model.Ungrouped).Count) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">In no group of scripts/tests/suite-groups.json: ' +
            ((@($Model.Ungrouped) | ForEach-Object { '<code>' + (& $e $_) + '</code>' }) -join ', ') + '.</p>')
    }
    if (@($Model.Unknown).Count) {
        [void]$body.AppendLine('<p class="msg" role="status">Grouped but no longer on disk: ' +
            ((@($Model.Unknown) | ForEach-Object { '<code>' + (& $e $_) + '</code>' }) -join ', ') + '.</p>')
    }
    [void]$body.AppendLine('<div class="tg-cards" id="groups">')
    if (-not $lists.Count) {
        [void]$body.AppendLine('<section class="card"><p class="note">No suite durations are recorded' + $(if ($unmeasured) { ' in this repo' } else { '' }) + '.</p></section>')
    }
    $heaviest = [double](($lists | ForEach-Object { $_.Total } | Measure-Object -Maximum).Maximum)
    foreach ($l in $lists) {
        $n = @($l.Suites).Count + @($l.Unmeasured).Count
        [void]$body.AppendLine('<section class="card card--link tg-card" id="group-' + (& $e $l.Key) + '"><h2><a href="/test-gate/' + (& $e $l.Key) + '">' + (& $e $l.Title) + '</a></h2>' +
            '<p class="num">' + $n + ' suites' + $dot + (Format-DevSeconds $l.Total) + $dot + (& $pct $l.Total) + '</p>' + (& $bar $l.Total $heaviest) + '</section>')
    }
    if ($null -ne $Selection) {
        $picked = if (-not @($Selection.Changed | Where-Object { $_ }).Count) { 'nothing changed' }
                  elseif (-not $Selection.Proven -or @($Selection.Selected).Count -ge $Selection.PoolCount) { 'every suite' }
                  else { '' + @($Selection.Selected).Count + ' of ' + $Selection.PoolCount + ' suites' }
        [void]$body.AppendLine('<section class="card card--link tg-card" id="selection"><h2><a href="/test-gate/selection">This checkout''s change</a></h2><p class="num">' + $picked + '</p></section>')
    }
    [void]$body.AppendLine('<section class="card card--link tg-card" id="recorded"><h2><a href="/test-gate/measured">Where it was measured</a></h2><p class="num">' +
        $(if ($Model.Date) { & $e $Model.Date } else { '--' }) + $dot + @($Model.Runs).Count + ' CI runs' +
        $(if (@($Model.Missing).Count -and -not $unmeasured) { $dot + @($Model.Missing).Count + ' not recorded' } else { '' }) + '</p></section>')
    [void]$body.AppendLine('</div>')
    return & $page 'Test gate' $body.ToString() '' $clock $footer
}

function Read-TestGateModel {
    <#
        The repo at -RepoRoot's scripts/tests/suite-durations.json, suite-groups.json and the suite files beside them,
        read on every request: two small files, and each suite's header for what it protects (#3309, lever 3).
        Returns @{ Model (ConvertFrom-SuiteDurations); Error; GroupsError }. A repo without suite-groups.json lists
        its suites ungrouped and says nothing about it; one without suite-durations.json is the page's empty state.
    #>
    param([Parameter(Mandatory = $true)][string]$RepoRoot)
    $testsDir = Join-Path $RepoRoot 'scripts\tests'
    $files = @(Get-ChildItem -LiteralPath $testsDir -Filter '*.tests.ps1' -File -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    $read = {
        param($Name)
        $p = Join-Path $testsDir $Name
        if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return @{ Json = $null; Error = 'the file is not there' } }
        try { return @{ Json = (Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json); Error = '' } } catch { return @{ Json = $null; Error = 'it is not valid JSON' } }
    }
    $d = & $read 'suite-durations.json'
    $g = & $read 'suite-groups.json'
    # No groups file is no fault: a repo groups its suites only where it wants to (#3470).
    if ($g.Error -eq 'the file is not there') { $g.Error = '' }
    $groups = if ($g.Json) { $g.Json.groups } else { $null }
    if ($g.Json -and -not @($groups | Where-Object { $_ }).Count) { $g.Error = 'it holds no groups' }
    $synopses = @{}
    foreach ($f in $files) {
        try { $synopses[$f] = Get-SuiteSynopsis -Text ([System.IO.File]::ReadAllText((Join-Path $testsDir $f))) -Max 1200 } catch { }
    }
    return @{ Model = (ConvertFrom-SuiteDurations -Durations $d.Json -SuiteFiles $files -Groups $groups -Synopses $synopses); Error = $d.Error; GroupsError = $g.Error }
}
