<#
.SYNOPSIS
    The DKJ-SOLUTIONS pages of a Repo hub -- the Brandbook, and the hub's "DKJ-Solutions" card that links
    it (#3132, #3198). No I/O: the general pages server reads the two house-style files and hands their
    text in, so every rule here is tested without a server.

.DESCRIPTION
    WHY THIS IS NOT IN DKJ-POLICY WITH THE REST. The general pages server, the placeholder and the
    dev-preview hook live in dkj-policy, which every repo runs (#3198, the owner's decision of October 20,
    2026). The house style belongs to the DKJ-Solutions repos alone, so its page and its card stay in this
    plugin, and a hub shows them only in a repo that enables dkj-solutions (Test-DkjSolutionsEnabled in
    dkj-policy's hub/lib/general-pages-state.ps1 decides that).

    IT IS LOADED, NOT LOADING. Its callers -- dkj-policy's hub/pages/serve-general-pages.ps1 and
    hub/lib/dev-preview-placeholder.ps1, and the source repo's scripts/lib/dev-pages-lib.ps1 -- dot-source
    dkj-policy's general-pages-lib.ps1 first, and this file then uses its page shell (Format-GeneralPageHtml,
    Format-GeneralPagesCardHtml, Format-DevTiles, ConvertTo-GeneralPageText and $script:DevBarStyle). It
    dot-sources nothing itself: in the plugin cache this plugin's own folder has no dkj-policy beside it.

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/dev-pages.tests.ps1 in the source repo --
    change one, run the other.
#>
function Get-DkjSolutionsPages {
    <#
        The pages only the DKJ-Solutions repos share, in Get-GeneralPages' shape: served by the same general
        server, listed in a card of their own because a repo of another organisation has none of them.
    #>
    @(
        @{ Href = '/brandbook'; Label = 'Brandbook'; Sub = 'The house style: its tokens, its twelve themes and its components, as the dkj-solutions plugin ships them' }
    )
}

function Format-DkjSolutionsPagesCardHtml {
    <# The hub's "DKJ-Solutions" card: Format-GeneralPagesCardHtml with the DKJ-Solutions pages, heading and sub line. #>
    param([AllowEmptyString()][string]$PagesUrl = '', [bool]$InRow = $true, [switch]$SameOrigin)
    return Format-GeneralPagesCardHtml -PagesUrl $PagesUrl -InRow $InRow -SameOrigin:$SameOrigin -Pages @(Get-DkjSolutionsPages) `
        -Heading 'DKJ-Solutions' -HeadSub 'Shared by every DKJ-Solutions repo: the house style they are all built from'
}

function ConvertFrom-HouseStyleAssets {
    <#
        The Brandbook model (#3132) from the text of house-style.css (-Css) and house-theme.js (-Js), as the
        dkj-solutions plugin ships them in assets/house-style/. Returns @{ Tokens (list of @{ Name; Value;
        Group }, in the stylesheet's order); Themes (list of @{ Id; Name; Mode; Hex; Steps; Extra; Default },
        in the picker's order); Sections (list of @{ Title; Classes }) }.

        WHERE EACH PART COMES FROM. The tokens are the light :root block, the house default, so each value
        is Blauw's. The themes are house-theme.js's THEMES list and HOUSE_DEFAULT, each with the twelve
        --primary-* the stylesheet's own block for that theme sets (Steps) and any other token it moves
        (Extra, the warning colour on Roest and Geel). The components are the stylesheet's "/* ---- Name"
        sections, each with every class its selectors name. A pattern read, not a CSS parse: the file keeps
        one shape, and a section the read misses shows as missing on the page rather than failing it.
    #>
    param([AllowEmptyString()][string]$Css = '', [AllowEmptyString()][string]$Js = '')
    $plain = [regex]::Replace($Css, '/\*.*?\*/', '', 'Singleline')

    $tokens = @()
    $light = [regex]::Match($plain, ':root\s*\{([^}]*)\}')
    if ($light.Success) {
        foreach ($t in [regex]::Matches($light.Groups[1].Value, '--([a-z0-9-]+)\s*:\s*([^;]+);')) {
            $name = $t.Groups[1].Value
            $group = switch -Regex ($name) {
                '^primary-' { 'Theme steps' }
                '^cat-' { 'Categorical' }
                '^(positive|negative|warning)-' { 'Status' }
                '^(text|font)-' { 'Type' }
                '^spacing-' { 'Spacing' }
                default { 'App shell' }
            }
            $tokens += @{ Name = '--' + $name; Value = ($t.Groups[2].Value -replace '\s+', ' ').Trim(); Group = $group }
        }
    }

    $blocks = @{}
    foreach ($b in [regex]::Matches($plain, ':root\[data-theme="([a-z]+)"\]\s*,\s*\.theme-swatch\[data-id="\1"\]\s*\{([^}]*)\}')) {
        $props = [ordered]@{}
        foreach ($p in [regex]::Matches($b.Groups[2].Value, '--([a-z0-9-]+)\s*:\s*(#[0-9a-fA-F]{3,8})\s*;')) { $props[$p.Groups[1].Value] = $p.Groups[2].Value }
        $blocks[$b.Groups[1].Value] = $props
    }
    $def = [regex]::Match($Js, "HOUSE_DEFAULT\s*=\s*\{\s*light:\s*'([a-z]+)',\s*dark:\s*'([a-z]+)'\s*\}")
    $defaults = if ($def.Success) { @($def.Groups[1].Value, $def.Groups[2].Value) } else { @() }
    $themes = @()
    foreach ($t in [regex]::Matches($Js, "\{\s*id:\s*'([a-z]+)',\s*name:\s*'([^']+)',\s*mode:\s*'(light|dark)',\s*hex:\s*'(#[0-9a-fA-F]{6})'\s*\}")) {
        $id = $t.Groups[1].Value
        $props = if ($blocks.ContainsKey($id)) { $blocks[$id] } else { [ordered]@{} }
        $steps = @(1..12 | ForEach-Object { if ($props.Contains("primary-$_")) { $props["primary-$_"] } else { $null } })
        $extra = @($props.Keys | Where-Object { $_ -notmatch '^primary-([1-9]|1[0-2])$' } | ForEach-Object { @{ Name = '--' + $_; Value = $props[$_] } })
        $themes += @{ Id = $id; Name = $t.Groups[2].Value; Mode = $t.Groups[3].Value; Hex = $t.Groups[4].Value; Steps = $steps; Extra = $extra; Default = ($defaults -contains $id) }
    }

    $sections = @()
    $heads = @([regex]::Matches($Css, '/\* -{4} (.+?)\s+-+ \*/'))
    for ($i = 0; $i -lt $heads.Count; $i++) {
        $from = $heads[$i].Index + $heads[$i].Length
        $to = if ($i + 1 -lt $heads.Count) { $heads[$i + 1].Index } else { $Css.Length }
        $text = [regex]::Replace($Css.Substring($from, $to - $from), '/\*.*?\*/', '', 'Singleline')
        # The declaration blocks go -- one pass, innermost only, then the braces -- so the selectors inside an
        # @media block stay, and what is left is selectors and at-rule preludes.
        $text = [regex]::Replace([regex]::Replace($text, '\{[^{}]*\}', ' '), '[{}]', ' ')
        $classes = @([regex]::Matches($text, '(?<![\w-])\.([a-z][a-z0-9_-]*)') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
        if ($classes.Count) { $sections += @{ Title = $heads[$i].Groups[1].Value; Classes = $classes } }
    }
    return @{ Tokens = $tokens; Themes = $themes; Sections = $sections }
}

function Format-BrandbookPageHtml {
    <#
        The Brandbook page (#3132) from ConvertFrom-HouseStyleAssets' model. -ReadError is set when a file
        could not be read; -AppPresent says whether the repo's brandbook/ holds the full brand book app
        (#3131), and the page then names the command that serves it. -RepoName is the repo's name, for the
        eyebrow and the title; -Source is the escaped markup the footer opens with, naming the folder the
        two files were read from (the general server's own plugin copy, or the source repo's tree).

        A DKJ-SOLUTIONS PAGE: the house style is every DKJ-Solutions repo's, not one repo's, so the page
        is built here and listed in the hub's DKJ-Solutions card. The general server serves it from the
        plugin copy it runs from, in a repo that enables dkj-solutions.

        THE SWATCHES FOLLOW THE THEME. A token's swatch is drawn with var(--name), so picking a theme under
        Settings recolours the token table, and the components below are the house classes themselves. The
        theme table draws each theme's own twelve steps from the stylesheet's values, whatever is picked.
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Model,
        [AllowEmptyString()][string]$ReadError = '',
        [bool]$AppPresent = $false,
        [AllowEmptyString()][string]$RepoName = '',
        [AllowEmptyString()][string]$Source = 'the dkj-solutions plugin''s <code>assets/house-style/</code>'
    )
    $e = { param($v) ConvertTo-GeneralPageText $v }
    $chip = { param($hex) if ($hex -match '^#[0-9a-fA-F]{3,8}$') { '<span class="bb-chip" style="background: ' + $hex + '" title="' + $hex + '"></span>' } else { '<span class="note">--</span>' } }
    $tokens = @($Model.Tokens); $themes = @($Model.Themes); $sections = @($Model.Sections)
    $classCount = @($sections | ForEach-Object { $_.Classes } | Select-Object -Unique).Count

    $body = New-Object System.Text.StringBuilder
    [void]$body.Append((Format-DevTiles @(
        @{ L = 'Tokens'; V = $tokens.Count },
        @{ L = 'Themes'; V = ('{0} light, {1} dark' -f @($themes | Where-Object { $_.Mode -eq 'light' }).Count, @($themes | Where-Object { $_.Mode -eq 'dark' }).Count) },
        @{ L = 'Component sections'; V = $sections.Count },
        @{ L = 'House classes'; V = $classCount })))
    if ($ReadError) {
        [void]$body.AppendLine('<p class="msg msg--warn" role="alert">The house style could not be read: ' + (& $e $ReadError) + '.</p>')
    }
    if ($AppPresent) {
        [void]$body.AppendLine('<p class="msg" role="status">The full brand book app, with its showcase, runs from this checkout: <code>npm run dev</code> in <code>brandbook/</code>.</p>')
    }

    [void]$body.AppendLine('<div class="grid-2" id="themes">')
    [void]$body.AppendLine('<div class="grid__head"><h2>Themes</h2><p class="card__sub">The twelve the user picks from under Settings, each with its twelve steps, from the ground end to the far end</p></div>')
    [void]$body.AppendLine('<section class="card grid__full">')
    if ($themes.Count) {
        [void]$body.AppendLine('<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">Theme</th><th class="dp-left">Mode</th>' +
            ((1..12 | ForEach-Object { '<th class="dp-left">-' + $_ + '</th>' }) -join '') + '</tr></thead><tbody>')
        foreach ($t in $themes) {
            $notes = @()
            if ($t.Default) { $notes += 'the house default for ' + $t.Mode }
            foreach ($x in @($t.Extra)) { $notes += 'also sets ' + $x.Name + ' ' + $x.Value }
            $noteHtml = if ($notes.Count) { '<p class="note">' + (& $e ($notes -join '; ')) + '</p>' } else { '' }
            [void]$body.AppendLine('<tr><td class="dp-left"><strong>' + (& $e $t.Name) + '</strong> <code>' + (& $e $t.Id) + '</code>' + $noteHtml + '</td>' +
                '<td class="dp-left">' + $(if ($t.Mode -eq 'dark') { 'Dark' } else { 'Light' }) + '</td>' +
                ((@($t.Steps) | ForEach-Object { '<td class="dp-left">' + (& $chip $_) + '</td>' }) -join '') + '</tr>')
        }
        [void]$body.AppendLine('</tbody></table></div>')
    } else {
        [void]$body.AppendLine('<p class="note">No theme was found in house-theme.js.</p>')
    }
    [void]$body.AppendLine('</section>')
    [void]$body.AppendLine('</div>')

    [void]$body.AppendLine('<div class="grid-2" id="tokens">')
    [void]$body.AppendLine('<div class="grid__head"><h2>Tokens</h2><p class="card__sub">The value is the light default, Blauw; the sample is drawn in the theme picked under Settings</p></div>')
    [void]$body.AppendLine('<section class="card grid__full">')
    if ($tokens.Count) {
        foreach ($g in 'Theme steps', 'Categorical', 'Status', 'Type', 'Spacing', 'App shell') {
            $rows = @($tokens | Where-Object { $_.Group -eq $g })
            if (-not $rows.Count) { continue }
            [void]$body.AppendLine('<h3>' + $g + '</h3>')
            [void]$body.AppendLine('<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">Token</th><th class="dp-left">Value in Blauw</th><th class="dp-left">Sample in the picked theme</th></tr></thead><tbody>')
            foreach ($t in $rows) {
                # The name is [a-z0-9-] by the read's own pattern, so var() of it is safe in an attribute.
                $var = 'var(' + $t.Name + ')'
                $sample = if ($t.Value -match '^#[0-9a-fA-F]{3,8}$') { '<span class="bb-chip" style="background: ' + $var + '"></span>' }
                          elseif ($t.Name -like '--spacing-*') { '<span class="bb-space" style="width: ' + $var + '"></span>' }
                          elseif ($t.Name -like '--text-*') { '<span class="bb-type" style="font-size: ' + $var + '">Aa</span>' }
                          elseif ($t.Name -eq '--font-serif') { '<span class="bb-type" style="font-family: ' + $var + '">Aa</span>' }
                          else { '' }
                [void]$body.AppendLine('<tr><td class="dp-left"><code>' + (& $e $t.Name) + '</code></td><td class="dp-left"><code>' + (& $e $t.Value) + '</code></td><td class="dp-left">' + $sample + '</td></tr>')
            }
            [void]$body.AppendLine('</tbody></table></div>')
        }
    } else {
        [void]$body.AppendLine('<p class="note">No token was found in house-style.css.</p>')
    }
    [void]$body.AppendLine('</section>')
    [void]$body.AppendLine('</div>')

    [void]$body.AppendLine('<div class="grid-2" id="specimens">')
    [void]$body.AppendLine('<div class="grid__head"><h2>Specimens</h2><p class="card__sub">A few house components, drawn by the stylesheet itself</p></div>')
    [void]$body.AppendLine('<section class="card grid__full">')
    [void]$body.AppendLine('<div class="bb-row"><button type="button" class="btn">Button</button><button type="button" class="btn btn--primary">Primary</button><button type="button" class="btn" disabled>Disabled</button>' +
        '<span class="seg" role="group" aria-label="A segmented switch"><button type="button" aria-pressed="true">Day</button><button type="button" aria-pressed="false">Week</button><button type="button" aria-pressed="false">Month</button></span></div>')
    [void]$body.AppendLine('<ul class="badge-list">')
    foreach ($b in @(@('good', '+', 'good'), @('warn', '!', 'warn'), @('bad', 'x', 'bad'), @('info', 'i', 'info'), @('neutral', '-', 'neutral'))) {
        [void]$body.AppendLine('<li class="badge-row"><span class="badge badge--' + $b[0] + '" aria-hidden="true">' + $b[1] + '</span><span><code>.badge--' + $b[2] + '</code></span></li>')
    }
    [void]$body.AppendLine('</ul>')
    foreach ($m in @(@('good', 80), @('warn', 55), @('bad', 30), @('info', 65))) {
        [void]$body.AppendLine('<p class="note"><code>.meter--' + $m[0] + '</code></p><div class="meter meter--' + $m[0] + '"><span style="width: ' + $m[1] + '%"></span></div>')
    }
    [void]$body.AppendLine('<p class="msg msg--warn">A <code>.msg--warn</code> line: a warning in text.</p>')
    [void]$body.AppendLine('</section>')
    [void]$body.AppendLine('</div>')

    [void]$body.AppendLine('<div class="grid-2" id="components">')
    [void]$body.AppendLine('<div class="grid__head"><h2>Components</h2><p class="card__sub">Every class the stylesheet defines, by its section. A repo''s own layer never restyles one of these</p></div>')
    [void]$body.AppendLine('<section class="card grid__full">')
    if ($sections.Count) {
        [void]$body.AppendLine('<div class="table-wrap"><table class="table"><thead class="dp-thead"><tr><th class="dp-left">Section</th><th class="dp-left">Classes</th></tr></thead><tbody>')
        foreach ($s in $sections) {
            [void]$body.AppendLine('<tr><td class="dp-left">' + (& $e $s.Title) + '</td><td class="dp-left bb-classes">' + ((@($s.Classes) | ForEach-Object { '<code>.' + (& $e $_) + '</code>' }) -join ' ') + '</td></tr>')
        }
        [void]$body.AppendLine('</tbody></table></div>')
    } else {
        [void]$body.AppendLine('<p class="note">No component section was found in house-style.css.</p>')
    }
    [void]$body.AppendLine('</section>')
    [void]$body.AppendLine('</div>')

    $style = $script:DevBarStyle + "`n" +
        '.bb-chip { display: inline-block; width: 24px; height: 24px; border-radius: 6px; border: 1px solid var(--primary-3); vertical-align: middle; }' + "`n" +
        '.bb-space { display: inline-block; height: 8px; border-radius: 2px; background: var(--primary-6); vertical-align: middle; }' + "`n" +
        '.bb-type { line-height: 1; color: var(--primary-12); }' + "`n" +
        '.bb-row { display: flex; flex-wrap: wrap; align-items: center; gap: var(--spacing-2); }' + "`n" +
        '.table td.bb-classes { white-space: normal; line-height: 1.8; }'
    return Format-GeneralPageHtml -Title 'Brandbook' -Style $style -Body $body.ToString() -Eyebrow $RepoName -SiteName $RepoName `
        -Lead 'The DKJ-Solutions house style every DKJ-Solutions page is built from: its themes, its tokens and its components, as the dkj-solutions plugin ships them.' `
        -FooterNote ('Read from ' + $Source + ' (<code>house-style.css</code> and <code>house-theme.js</code>) on every request. The rules behind them are in that folder''s <code>README.md</code>.')
}
