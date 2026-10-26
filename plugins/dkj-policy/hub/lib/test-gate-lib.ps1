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

function Format-TestGatePageHtml {
    <#
        The test-gate page from ConvertFrom-SuiteDurations' model. -ReadError is set when suite-durations.json
        could not be read, -GroupsError when suite-groups.json could not be; without groups the page lists the
        suites in one table, slowest first, as it did before the groups existed.

        -RepoName names the site in the page's header, -HubHref is where its Home crumb goes ('/hub' on the general
        pages server), and -RepoSlug (owner/name) links each recorded CI run on GitHub; without it a run is its number.
        A -ReadError of 'the file is not there' is the empty state: no test gate measured in this repo yet.

        -Selection is what this checkout's change selects (#3309, lever 3), $null to leave the section out:
        @{ Base; Changed (paths); Proven; Reason; Selected (suite file names); Why (name -> sentence);
        PoolCount; CiText }. Built by the server from Get-AffectedSuiteSelection, the function open-pr runs,
        so the page shows the gate's own answer rather than a second reading of it.
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Model, [AllowEmptyString()][string]$ReadError = '', [AllowEmptyString()][string]$GroupsError = '', $Selection = $null,
        [AllowEmptyString()][string]$RepoName = '', [string]$HubHref = '/hub', [AllowEmptyString()][string]$RepoSlug = '')
    $e = { param($v) ConvertTo-GeneralPageText $v }
    $suites = @($Model.Suites)
    $slowest = if ($suites.Count) { $suites[0] } else { $null }
    $synopses = if ($Model.Synopses) { $Model.Synopses } else { @{} }
    # A suite's name, and under it what it protects when its header says so.
    $suiteCell = {
        param($Name)
        $what = if ($synopses.ContainsKey($Name) -and $synopses[$Name]) { '<br><span class="note">' + (& $e $synopses[$Name]) + '</span>' } else { '' }
        return '<code>' + (& $e $Name) + '</code>' + $what
    }
    $body = New-Object System.Text.StringBuilder
    [void]$body.Append((Format-DevTiles @(
        @{ L = 'Suites recorded'; V = $suites.Count },
        @{ L = 'Sum of all suites'; V = (Format-DevSeconds $(if ($suites.Count) { $Model.Total } else { $null })) },
        @{ L = 'Slowest suite'; V = (Format-DevSeconds $(if ($slowest) { $slowest.Seconds } else { $null })) },
        @{ L = 'Not recorded'; V = @($Model.Missing).Count })))
    # No file at all is a repo that has measured no test gate yet, not a fault (#3470): every hub has this page.
    $unmeasured = $ReadError -eq 'the file is not there'
    if ($unmeasured) {
        [void]$body.AppendLine('<p class="msg" role="status">No test gate has been measured in this repo yet. This page fills in once the repo records its suites'' CI durations in <code>scripts/tests/suite-durations.json</code>, which the dkj-policy plugin''s <code>record-suite-durations</code> skill writes from CI runs.</p>')
    } elseif ($ReadError) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">scripts/tests/suite-durations.json could not be read: ' + (& $e $ReadError) + '.</p>')
    }
    if (@($Model.Missing).Count -and -not $unmeasured) {
        [void]$body.AppendLine('<p class="msg" role="status">Not recorded yet, so the gate charges each the largest recorded value: ' +
            ((@($Model.Missing) | ForEach-Object { '<code>' + (& $e $_) + '</code>' }) -join ', ') + '.</p>')
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
    # One suite table: the same columns for the ungrouped list and for each group, each bar drawn against
    # the slowest suite of all and each share of the whole sum, so two groups' rows read on one scale.
    # A group's suites with no recorded duration close its table, so a group lists every suite it holds.
    $suiteTable = {
        param($Rows, $Unmeasured = @())
        $t = '<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">Suite</th><th>Seconds</th><th class="dp-left">Against the slowest</th><th>Share of the sum</th></tr></thead><tbody>' + "`n"
        foreach ($s in @($Rows)) {
            $stale = if (@($Model.Stale) -contains $s.Name) { ' <span class="badge badge--sm badge--neutral">no longer on disk</span>' } else { '' }
            $t += '<tr><td class="dp-left">' + (& $suiteCell $s.Name) + $stale + '</td><td class="num">' +
                ([double]$s.Seconds).ToString('0.0', [Globalization.CultureInfo]::InvariantCulture) + '</td>' + (Format-DevShareCell $s.Seconds $Model.Total $slowest.Seconds) + '</tr>' + "`n"
        }
        foreach ($n in @($Unmeasured)) {
            $t += '<tr><td class="dp-left">' + (& $suiteCell $n) + ' <span class="badge badge--sm badge--neutral">not recorded yet</span></td><td class="num">--</td><td class="dp-left"></td><td>--</td></tr>' + "`n"
        }
        $sum = [double]((@($Rows) | ForEach-Object { $_.Seconds } | Measure-Object -Sum).Sum)
        return $t + '</tbody>' + (& $totalRow $sum (@($Rows).Count + @($Unmeasured).Count) 2) + '</table></div>'
    }
    # The closing row of a table: the sum of its seconds, one after another, which is not what CI waits --
    # the gate spreads the suites over shards and lanes -- so the label says so. -Pad is the count of
    # columns between the label and the seconds.
    $totalRow = {
        param([double]$Sum, [int]$Count, [int]$Pad)
        $pct = if ($Model.Total -gt 0) { (100.0 * $Sum / $Model.Total).ToString('0.0', [Globalization.CultureInfo]::InvariantCulture) } else { '0.0' }
        $mid = if ($Pad -gt 2) { '<td class="num">' + $Count + '</td>' } else { '' }
        $what = if ($Pad -gt 2) { 'all groups' } else { "$Count suites" }
        return '<tfoot><tr class="row-total dp-total"><td class="dp-left">Total <span class="note">' + $what + ', run one after another; CI runs them in parallel</span></td>' + $mid +
            '<td class="num">' + (Format-DevSeconds $Sum) + '</td><td class="dp-left"></td><td>' + $pct + '%</td></tr></tfoot>'
    }
    # A section's points to note, closing the section below its card as a full grid row of their own:
    # nothing when there are none.
    $tipsBlock = {
        param($Tips)
        $items = @(@($Tips) | Where-Object { $_ })
        if (-not $items.Count) { return '' }
        return '<div class="grid__full dp-tips"><h3>Points to note</h3><ul>' + (($items | ForEach-Object { '<li>' + (& $e $_) + '</li>' }) -join '') + '</ul></div>'
    }
    # THIS CHECKOUT'S CHANGE, first, because it answers the question a reader arrives with: why am I
    # waiting on these suites. Each row is the gate's own reason (Get-AffectedSuiteSelection's Why).
    if ($null -ne $Selection) {
        $secondsOf = @{}
        foreach ($s in $suites) { $secondsOf[$s.Name] = $s.Seconds }
        $changed = @($Selection.Changed | Where-Object { $_ })
        [void]$body.AppendLine('<div class="grid-2" id="selection">')
        [void]$body.AppendLine('<div class="grid__head"><h2>This checkout''s change</h2><p class="card__sub">The suites the affected-suite selection picks for it' +
            $(if ($Selection.Base) { ', against ' + (& $e $Selection.Base) } else { '' }) + ', and why each one is in</p></div>')
        [void]$body.AppendLine('<section class="card grid__full">')
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
                # Keyed on the suite's path, which is unique; its file name is what the durations, the synopses
                # and the reader go by.
                $leafOf = { param($p) ($p -split '/')[-1] }
                $rows = @($Selection.Selected | Sort-Object @{ Expression = { $n = & $leafOf $_; if ($secondsOf.ContainsKey($n)) { $secondsOf[$n] } else { 0 } }; Descending = $true }, @{ Expression = { $_ } })
                $t = '<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">Suite</th><th class="dp-left">Why it runs</th><th>Seconds</th></tr></thead><tbody>' + "`n"
                foreach ($key in $rows) {
                    $n = & $leafOf $key
                    $reason = if ($Selection.Why -and $Selection.Why.ContainsKey($key)) { $Selection.Why[$key] } else { '' }
                    $sec = if ($secondsOf.ContainsKey($n)) { ([double]$secondsOf[$n]).ToString('0.0', [Globalization.CultureInfo]::InvariantCulture) } else { '--' }
                    $t += '<tr><td class="dp-left">' + (& $suiteCell $n) + '</td><td class="dp-left">' + (& $e $reason) + '</td><td class="num">' + $sec + '</td></tr>' + "`n"
                }
                [void]$body.AppendLine($t + '</tbody></table></div>')
            }
        }
        [void]$body.AppendLine('</section>')
        [void]$body.AppendLine((& $tipsBlock @(
            'A suite runs locally when the change reaches a file it runs or names, when its declared walk scope covers a changed path, or when it walks the live tree with no declared scope.',
            'open-pr -AllSuites runs every suite regardless.')))
        [void]$body.AppendLine('</div>')
    }

    $groups = @($Model.Groups)
    if ($groups.Count -and $suites.Count) {
        [void]$body.AppendLine('<div class="grid-2" id="groups">')
        [void]$body.AppendLine('<div class="grid__head"><h2>Groups</h2><p class="card__sub">What each group of suites guards, whichever of them a PR''s CI runs</p></div>')
        [void]$body.AppendLine('<section class="card grid__full">')
        [void]$body.AppendLine('<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">Group</th><th>Suites</th><th>Seconds</th><th class="dp-left">Against the slowest group</th><th>Share of the sum</th></tr></thead><tbody>')
        $heaviest = ($groups | ForEach-Object { $_.Total } | Measure-Object -Maximum).Maximum
        foreach ($g in $groups) {
            [void]$body.AppendLine('<tr><td class="dp-left"><a class="dp-link" href="#group-' + (& $e $g.Key) + '">' + (& $e $g.Title) + '</a><br><span class="note">' + (& $e $g.Guards) +
                '</span></td><td class="num">' + (@($g.Suites).Count + @($g.Unmeasured).Count) + '</td><td class="num">' + (Format-DevSeconds $g.Total) + '</td>' + (Format-DevShareCell $g.Total $Model.Total $heaviest) + '</tr>')
        }
        $allCount = ($groups | ForEach-Object { @($_.Suites).Count + @($_.Unmeasured).Count } | Measure-Object -Sum).Sum
        $allSum = [double](($groups | ForEach-Object { $_.Total } | Measure-Object -Sum).Sum)
        [void]$body.AppendLine('</tbody>' + (& $totalRow $allSum $allCount 3) + '</table></div>')
        [void]$body.AppendLine('</section>')
        # The split candidates are the groups suite-groups.json gives a split for, largest first: which ones
        # is a judgement written into that file, and the counts beside them are measured here.
        $candidates = @($groups | Where-Object { $_.Split } | Sort-Object @{ Expression = { $_.Total }; Descending = $true } | ForEach-Object {
                $_.Title + ' (' + (@($_.Suites).Count + @($_.Unmeasured).Count) + ' suites, ' +
                $(if ($Model.Total -gt 0) { (100.0 * $_.Total / $Model.Total).ToString('0', [Globalization.CultureInfo]::InvariantCulture) } else { '0' }) + '%)' })
        [void]$body.AppendLine((& $tipsBlock @(
            'The seconds are summed as if every suite ran one after another. CI may split the suites over shards that run side by side, so it waits for the slowest shard, not for this sum.',
            'A group''s name jumps to its own table below.',
            $(if ($candidates.Count) { 'Candidates to split, largest first: ' + ($candidates -join '; ') + '. Each one''s own notes say how. A split changes only how this page reads, never what runs.' }))))
        [void]$body.AppendLine('</div>')
        foreach ($g in $groups) {
            [void]$body.AppendLine('<div class="grid-2" id="group-' + (& $e $g.Key) + '">')
            [void]$body.AppendLine('<div class="grid__head"><h2>' + (& $e $g.Title) + '</h2><p class="card__sub">Guards ' + (& $e $g.Guards) + '</p></div>')
            [void]$body.AppendLine('<section class="card grid__full">')
            if (@($g.Suites).Count + @($g.Unmeasured).Count) { [void]$body.AppendLine((& $suiteTable $g.Suites $g.Unmeasured)) }
            else { [void]$body.AppendLine('<p class="note">No suite of this group is on disk.</p>') }
            [void]$body.AppendLine('</section>')
            [void]$body.AppendLine((& $tipsBlock (@($g.Tips) + @($(if ($g.Split) { 'Could be split into ' + $g.Split })))))
            [void]$body.AppendLine('</div>')
        }
        $loose = @($suites | Where-Object { @($Model.Ungrouped) -contains $_.Name })
        $looseUnmeasured = @(@($Model.Ungrouped) | Where-Object { @($Model.Missing) -contains $_ })
        if ($loose.Count + $looseUnmeasured.Count) {
            [void]$body.AppendLine('<div class="grid-2" id="ungrouped">')
            [void]$body.AppendLine('<div class="grid__head"><h2>Not grouped</h2><p class="card__sub">Suites no group holds yet</p></div>')
            [void]$body.AppendLine('<section class="card grid__full">')
            [void]$body.AppendLine((& $suiteTable $loose $looseUnmeasured))
            [void]$body.AppendLine('</section>')
            [void]$body.AppendLine((& $tipsBlock @('Add each one to the group whose workflow step it guards, in scripts/tests/suite-groups.json.')))
            [void]$body.AppendLine('</div>')
        }
    } else {
        [void]$body.AppendLine('<div class="grid-2" id="suites">')
        [void]$body.AppendLine('<div class="grid__head"><h2>Suites</h2><p class="card__sub">Mean CI duration per suite, slowest first</p></div>')
        [void]$body.AppendLine('<section class="card grid__full">')
        if ($suites.Count) { [void]$body.AppendLine((& $suiteTable $suites)) }
        elseif ($unmeasured) { [void]$body.AppendLine('<p class="note">No suite durations are recorded in this repo.</p>') }
        else { [void]$body.AppendLine('<p class="note">No suite durations are recorded.</p>') }
        [void]$body.AppendLine('</section>')
        [void]$body.AppendLine((& $tipsBlock @('Without scripts/tests/suite-groups.json the suites are listed in one table.')))
        [void]$body.AppendLine('</div>')
    }
    [void]$body.AppendLine('<div class="grid-2" id="recorded">')
    [void]$body.AppendLine('<div class="grid__head"><h2>Where it was measured</h2></div>')
    [void]$body.AppendLine('<section class="card grid__full">')
    [void]$body.AppendLine('<dl class="facts">')
    [void]$body.AppendLine('<div><dt>Recorded</dt><dd>' + $(if ($Model.Date) { & $e $Model.Date } else { '--' }) + '</dd></div>')
    [void]$body.AppendLine('<div><dt>Machine</dt><dd>' + $(if ($Model.Machine) { & $e $Model.Machine } else { '--' }) + '</dd></div>')
    [void]$body.AppendLine('<div><dt>Method</dt><dd>' + $(if ($Model.Method) { & $e $Model.Method } else { '--' }) + '</dd></div>')
    # A run links to the repo's own CI on GitHub, where the origin remote names it (owner/name), else it is its number.
    $slug = if ($RepoSlug -cmatch '^[A-Za-z0-9-]+/[A-Za-z0-9._-]+\z') { $RepoSlug } else { '' }
    $runs = (@($Model.Runs) | Where-Object { $_ -cmatch '^[0-9]+\z' } | ForEach-Object {
            if ($slug) { '<a class="dp-link" href="https://github.com/' + (& $e $slug) + '/actions/runs/' + $_ + '">' + $_ + '</a>' } else { $_ } }) -join ', '
    [void]$body.AppendLine('<div><dt>CI runs</dt><dd>' + $(if ($runs) { $runs } else { '--' }) + '</dd></div>')
    [void]$body.AppendLine('</dl>')
    [void]$body.AppendLine('</section>')
    [void]$body.AppendLine((& $tipsBlock @(
        'A suite not recorded yet is charged the largest recorded duration when the gate packs its shards, so a new suite starts early rather than last.',
        'Refresh the file from CI runs once a suite has been added or has grown, with the dkj-policy plugin''s record-suite-durations skill.')))
    [void]$body.AppendLine('</div>')
    # The house's .row-total sets the weight; the rule above it, heavier than a row's own, is this page's.
    $style = $script:DevBarStyle + "`n" + '.dp-total td { border-top: 2px solid var(--paper-4); }'
    return Format-GeneralPageHtml -Title 'Test gate' -Style $style -Body $body.ToString() -SiteName $RepoName -HubHref $HubHref `
        -Lead 'What each test suite costs on CI, grouped by the workflow step it guards. A group says what breaks when its suites go red, not when they run. Measured on CI runners, never on a workstation: a local reading does not convert.' `
        -FooterNote 'Read from the repo''s <code>scripts/tests/suite-durations.json</code>, on every request, grouped by its <code>scripts/tests/suite-groups.json</code> where it keeps one. Built by the dkj-policy plugin''s <code>hub/lib/test-gate-lib.ps1</code>.'
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
        try { $synopses[$f] = Get-SuiteSynopsis -Text ([System.IO.File]::ReadAllText((Join-Path $testsDir $f))) } catch { }
    }
    return @{ Model = (ConvertFrom-SuiteDurations -Durations $d.Json -SuiteFiles $files -Groups $groups -Synopses $synopses); Error = $d.Error; GroupsError = $g.Error }
}
