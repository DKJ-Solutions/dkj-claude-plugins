<#
.SYNOPSIS
    The rules behind check-house-style (#3035): is every vendored copy of the house style the copy the
    house-style skill pins, does the repo's own layer leave the house tokens and classes alone, and does
    it still use a token name the brand book retired.

.DESCRIPTION
    WHY IT EXISTS. Measured October 15, 2026 across the DKJ-Solutions org, nothing checked a consumer's
    copy: dkj-lifehub vendored a stylesheet matching no released tag, four repos had no copy and still
    used the retired names, and this repo's own connector dashboard used four tokens house-style-v3 no
    longer defines (#3033). Without a gate the migration to one design system drifts again after it
    lands, so this is phase 1 of that plan.

    THE THREE CHECKS, and the decisions behind their shape (owner, October 15, 2026, on #3035):

      1. pin      -- every tracked file named house-style.css or house-theme.js hashes to the sha256 the
                     skill page pins. The copies are FOUND (a discovery over the tracked files), not
                     declared, so no repo falls outside the gate by leaving a seam unfilled. A repo with
                     no house-style.css at all is a finding too: a repo running this gate renders a UI.
      2. redefine -- the repo's own layer defines no house token (`--x:`) and styles no house class as
                     the subject of its own rule. The house set is read from the verified copy itself,
                     so it follows the pinned tag without a second list to maintain.
      3. retired  -- the repo's own layer neither defines nor reads (`var(--x)`) a token name the brand
                     book retired.

    PATTERN GREP, NOT A PARSE. Checks 2 and 3 match patterns rather than parse CSS or SCSS: no runtime
    dependency, and a bare Windows PowerShell 5.1 runs it. The price is the occasional false positive,
    which the repo answers in its own allowlist (Get-HouseStyleAllowlist, below) with a reason per entry.

    EMBEDDED CSS IS IN SCOPE. The grep runs over every tracked text file of the kinds a page is built in
    (.py, .html, .js, .ps1 and the rest of Get-HouseStyleScanExtensions), not only .css/.scss, because
    dkj-etf-tracker builds its page in a Python string and this repo builds its dashboard in PowerShell.
    Markdown is not scanned: it is where these names are DOCUMENTED, and a rename table is not a use.

    ONLY CSS CONTEXT COUNTS. A token is matched as a definition (`--x:`, also quoted as a JS key) or as
    a read (`var(--x`), never as a bare word. `--page`, `--grid` and `--up` are also command-line
    flags, and an argparse line naming one is not a stylesheet.

    A CLASS COUNTS WHEN THE RULE RESTYLES IT EVERYWHERE. A house class is a finding where it is the
    SUBJECT of a selector -- in the last compound -- and the selector names no class of the repo's own.
    `.card`, `.card:hover` and `main .card` restyle every house card in the app. `.card .my-row` styles
    the repo's row, and `.my-thing.card` or `.my-panel .card` place a house component inside a domain
    one, so none of those is a finding: the connector dashboard's `.cd-signals li .badge` nudges a badge
    by a pixel in its own list, which is composition, not a second definition of the badge.

    THE RETIRED NAMES are every token an earlier released tag defined (house-style-v1, -v2) and every
    name in the `Was` column of the rename tables in house-style/README.md at the pinned tag, minus
    every name that tag's stylesheet defines again (`--primary-3` was renamed and is live with a new
    meaning). The rename tables alone miss `--gain`, which v1 and v2 defined and v3 dropped without a
    row. They are listed here rather than fetched, so the gate needs no network; a
    repoint of the skill to a new tag updates this list in the same change, and the suite holds the
    list to the vendored copy so a live name can never be listed as retired.

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/check-house-style.tests.ps1 in the
    source repo -- change one, run the other.
#>

Set-StrictMode -Version Latest

function Get-HouseStyleRetiredTokens {
    <# The token names the brand book retired, as of the tag the skill pins (v0.4.0). #>
    return [string[]]@(
        '--axis', '--bad', '--border', '--border-base', '--down', '--gain', '--good', '--grid', '--grid-base',
        '--ink', '--ink-2', '--loss', '--muted', '--neutral-1', '--neutral-2', '--neutral-3', '--neutral-4',
        '--neutral-5', '--on-primary', '--on-warn', '--page', '--page-base', '--primary', '--primary-ink',
        '--primary-soft', '--status-mark', '--surface', '--surface-base', '--up', '--warn', '--warn-bg'
    )
}

function Get-HouseStyleCopyNames {
    <# The leaf names a vendored copy carries. A renamed copy is not found, and is not a copy. #>
    return [string[]]@('house-style.css', 'house-theme.js')
}

function Get-HouseStyleScanExtensions {
    <# The file kinds checks 2 and 3 read: every kind a page or its styles is written in. #>
    return [string[]]@(
        '.css', '.scss', '.sass', '.less', '.styl', '.pcss',
        '.html', '.htm', '.xhtml', '.svg',
        '.js', '.mjs', '.cjs', '.ts', '.mts', '.cts', '.jsx', '.tsx', '.vue', '.svelte', '.astro',
        '.py', '.ps1', '.psm1', '.php', '.rb', '.erb',
        '.liquid', '.njk', '.hbs', '.ejs', '.jinja', '.jinja2', '.j2', '.twig', '.cshtml', '.razor'
    )
}

function Get-HouseStyleElementNames {
    <#
        The element names a type selector can match: HTML's and SVG's common ones. A word that is none
        of them and carries no hyphen (a custom element's mark) is prose, not a selector (#3120).
    #>
    return [string[]]@(
        'a', 'abbr', 'address', 'area', 'article', 'aside', 'audio', 'b', 'base', 'bdi', 'bdo', 'blockquote',
        'body', 'br', 'button', 'canvas', 'caption', 'cite', 'code', 'col', 'colgroup', 'data', 'datalist',
        'dd', 'del', 'details', 'dfn', 'dialog', 'div', 'dl', 'dt', 'em', 'embed', 'fieldset', 'figcaption',
        'figure', 'footer', 'form', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'head', 'header', 'hgroup', 'hr',
        'html', 'i', 'iframe', 'img', 'input', 'ins', 'kbd', 'label', 'legend', 'li', 'link', 'main', 'map',
        'mark', 'math', 'menu', 'meta', 'meter', 'nav', 'noscript', 'object', 'ol', 'optgroup', 'option',
        'output', 'p', 'picture', 'pre', 'progress', 'q', 'rp', 'rt', 'ruby', 's', 'samp', 'script',
        'search', 'section', 'select', 'slot', 'small', 'source', 'span', 'strong', 'style', 'sub',
        'summary', 'sup', 'table', 'tbody', 'td', 'template', 'textarea', 'tfoot', 'th', 'thead', 'time',
        'title', 'tr', 'track', 'u', 'ul', 'var', 'video', 'wbr',
        'svg', 'g', 'path', 'circle', 'rect', 'line', 'polyline', 'polygon', 'ellipse', 'text', 'tspan',
        'defs', 'symbol', 'marker', 'pattern', 'image', 'stop', 'mask', 'clippath', 'lineargradient',
        'radialgradient', 'foreignobject', 'use', 'filter', 'animate', 'center', 'font'
    )
}

function Get-HouseStylePin {
    <#
        The pinned tag and the sha256 per file, read from the skill page's table -- the one place they
        are written. Returns @{ Tag; Hashes = @{ '<leaf>' = '<sha256>' } }, or $null when the page
        carries no complete table.
    #>
    param([Parameter(Mandatory)][string]$SkillText)

    $hashes = @{}
    $tag = $null
    foreach ($line in ($SkillText -split "`r?`n")) {
        $m = [regex]::Match($line, '^\|\s*`(?<file>house-style\.css|house-theme\.js)`\s*\|\s*`(?<url>[^`]+)`\s*\|\s*`(?<sha>[0-9a-f]{64})`\s*\|')
        if (-not $m.Success) { continue }
        $hashes[$m.Groups['file'].Value] = $m.Groups['sha'].Value
        $t = [regex]::Match($m.Groups['url'].Value, '/dkj-brandbook/(?<tag>[^/]+)/house-style/')
        if ($t.Success) { $tag = $t.Groups['tag'].Value }
    }
    foreach ($name in (Get-HouseStyleCopyNames)) { if (-not $hashes.ContainsKey($name)) { return $null } }
    return @{ Tag = $tag; Hashes = $hashes }
}

function Get-HouseStyleSha256 {
    <#
        The sha256 of a file's bytes, and -- where they differ -- of the same bytes with CRLF turned
        into LF. The tag serves LF, and a Windows checkout under core.autocrlf rewrites a text file to
        CRLF on disk without the commit changing, so that copy is still the pinned file.
    #>
    param([Parameter(Mandatory)][byte[]]$Bytes)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $raw = ([System.BitConverter]::ToString($sha.ComputeHash($Bytes)) -replace '-', '').ToLowerInvariant()
        $lf = New-Object System.Collections.Generic.List[byte] $Bytes.Length
        for ($i = 0; $i -lt $Bytes.Length; $i++) {
            if ($Bytes[$i] -eq 13 -and ($i + 1) -lt $Bytes.Length -and $Bytes[$i + 1] -eq 10) { continue }
            $lf.Add($Bytes[$i])
        }
        $norm = ([System.BitConverter]::ToString($sha.ComputeHash($lf.ToArray())) -replace '-', '').ToLowerInvariant()
        return [string[]]@($raw, $norm | Select-Object -Unique)
    } finally { $sha.Dispose() }
}

function Get-HouseStyleDefinitions {
    <#
        The house tokens and classes, read from the text of a verified house-style.css:
        @{ Tokens = string[]; Classes = string[] }. A token is any `--x:` the file defines; a class is
        any `.x` in a selector prelude (an at-rule's prelude is not a selector).
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$CssText)

    $css = [regex]::Replace($CssText, '/\*[\s\S]*?\*/', ' ')
    $tokens = @([regex]::Matches($css, '(?<![\w-])(--[A-Za-z0-9_-]+)\s*:') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    $classes = New-Object System.Collections.Generic.HashSet[string]
    foreach ($m in [regex]::Matches($css, '(?<=^|[{}])(?<pre>[^{}]+)\{')) {
        $pre = $m.Groups['pre'].Value
        $semi = $pre.LastIndexOf(';')
        if ($semi -ge 0) { $pre = $pre.Substring($semi + 1) }
        if ($pre.Trim().StartsWith('@')) { continue }
        foreach ($c in [regex]::Matches($pre, '(?<![\w-])\.(-?[A-Za-z_][\w-]*)')) { [void]$classes.Add($c.Groups[1].Value) }
    }
    return @{ Tokens = [string[]]$tokens; Classes = [string[]]@($classes | Sort-Object) }
}

function New-HouseStyleLineMap {
    <# The offsets of every newline in $Text, so a hit's line number is a binary search, not a walk. #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    $map = New-Object System.Collections.Generic.List[int]
    $i = $Text.IndexOf("`n")
    while ($i -ge 0) { $map.Add($i); $i = $Text.IndexOf("`n", $i + 1) }
    return , $map
}

function Get-HouseStyleLineNumber {
    param([Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[int]]$Map, [Parameter(Mandatory)][int]$Index)
    $at = $Map.BinarySearch($Index)
    if ($at -lt 0) { $at = -bnot $at }
    return $at + 1
}

function Find-HouseStyleTokenHit {
    <#
        Every CSS-context occurrence of a name in $Names: a definition (`--x:`, also `'--x':`) and,
        with -IncludeReads, a read (`var(--x`). Returns @{ Name; Kind = 'defines'|'reads'; Line }.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Names,
        [switch]$IncludeReads
    )

    $set = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::Ordinal)
    foreach ($n in $Names) { [void]$set.Add($n) }
    if ($set.Count -eq 0) { return }
    $map = New-HouseStyleLineMap -Text $Text

    foreach ($m in [regex]::Matches($Text, '(?<![\w-])(?<name>--[A-Za-z0-9_-]+)[''"]?\s*:')) {
        if ($set.Contains($m.Groups['name'].Value)) {
            @{ Name = $m.Groups['name'].Value; Kind = 'defines'; Line = (Get-HouseStyleLineNumber -Map $map -Index $m.Index) }
        }
    }
    if ($IncludeReads) {
        foreach ($m in [regex]::Matches($Text, 'var\(\s*(?<name>--[A-Za-z0-9_-]+)(?![\w-])')) {
            if ($set.Contains($m.Groups['name'].Value)) {
                @{ Name = $m.Groups['name'].Value; Kind = 'reads'; Line = (Get-HouseStyleLineNumber -Map $map -Index $m.Index) }
            }
        }
    }
}

function Find-HouseStyleClassHit {
    <#
        Every rule whose selector has a house class as its subject and names no class of the repo's own
        anywhere. Returns @{ Name; Kind = 'styles'; Line }, one per selector.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Classes
    )

    $set = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::Ordinal)
    foreach ($c in $Classes) { [void]$set.Add($c) }
    if ($set.Count -eq 0) { return }
    # Most files name no house class at all, and walking every `{` of a script is the expensive part
    # (19s of 22s on this repo before this line), so one alternation decides first whether to walk.
    $any = '(?<![\w''"-])\.(' + ((@($Classes) | Sort-Object Length -Descending | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')(?![\w-])'
    if (-not [regex]::IsMatch($Text, $any)) { return }
    $map = New-HouseStyleLineMap -Text $Text
    # A quote before the dot is a string such as querySelector('.card'), never a stylesheet selector.
    # Nor is a dot before it -- an object spread, `...meta` -- or a `(` straight after the name, which
    # is a method call such as `.sort(` and never CSS (#3040). `[x].card` and `:not(.a).card` are
    # selectors, so a `]` or `)` before the dot stays allowed.
    $classPattern = '(?<![\w''".-])\.(-?[A-Za-z_][\w-]*)(?![\w-]|\()'
    # A comment inside a prelude -- `/* */`, or a whole line opened by `# ` or `//` (an id selector has
    # no space after its `#`) -- is blanked to spaces, so a line number still lands where it did (#3120).
    $comment = [regex]'(?m)/\*[\s\S]*?\*/|^[ \t]*(#(?=[ \t\r]|$)|//).*$'
    $blank = [System.Text.RegularExpressions.MatchEvaluator] { param($c) $c.Value -replace '[^\n]', ' ' }
    $elements = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($e in (Get-HouseStyleElementNames)) { [void]$elements.Add($e) }

    foreach ($m in [regex]::Matches($Text, '(?<=^|[{};])(?<pre>[^{};]+)\{')) {
        $pre = $comment.Replace($m.Groups['pre'].Value, $blank)
        if ($pre.Trim().StartsWith('@')) { continue }
        foreach ($selector in ($pre -split ',')) {
            # Bracket and paren contents first: `[data-x='a b']` and `:is(.a .b)` hold spaces that are
            # no combinator. Parens fold innermost-out, to `[]` so the next pass does not re-match them.
            $flat = [regex]::Replace($selector, '\[[^\]]*\]', '[]')
            do { $before = $flat; $flat = [regex]::Replace($flat, '\([^()]*\)', '[]') } while ($flat -ne $before)
            # A paren left over is unbalanced, and a selector never is: `, OPTIONS).sort).toEqual(` is
            # the tail of a call whose argument held an object literal (#3095).
            if ($flat.IndexOfAny([char[]]'()') -ge 0) { continue }
            $parts = @($flat.Trim() -split '[\s>+~]+' | Where-Object { $_ })
            if ($parts.Count -eq 0) { continue }
            # Prose before a comma is no selector (#3120): `in the house .grid-2, closed ...` in a string.
            # Read on the subject's own line, after the last string quote (attribute values are folded
            # already), so the code before a rule -- `css = """` -- is not read as part of it: a bare word
            # there that names no element and carries no hyphen (a custom element's mark) is prose.
            $sel = @(($flat -split "`n") | Where-Object { $_.Trim() })
            $sel = if ($sel.Count) { $sel[-1] } else { '' }
            $q = $sel.LastIndexOfAny([char[]]"'`"``")
            if ($q -ge 0) { $sel = $sel.Substring($q + 1) }
            $words = @($sel.Trim() -split '[\s>+~]+' | Where-Object { $_ -match '^[A-Za-z][A-Za-z0-9]*$' -and -not $elements.Contains($_) })
            if ($words.Count) { continue }
            $house = @([regex]::Matches($parts[-1], $classPattern) | ForEach-Object { $_.Groups[1].Value } | Where-Object { $set.Contains($_) })
            if ($house.Count -eq 0) { continue }
            # A class of the repo's own anywhere in the selector scopes the rule to its own component.
            # Counted without the quote rule: a page built in a string opens its first selector after a quote.
            $own = @([regex]::Matches($flat, '(?<![\w.-])\.(-?[A-Za-z_][\w-]*)(?![\w-]|\()') | Where-Object { -not $set.Contains($_.Groups[1].Value) })
            if ($own.Count) { continue }
            $at = $m.Index + $pre.IndexOf($selector.Trim())
            @{ Name = ('.' + $house[0]); Kind = 'styles'; Line = (Get-HouseStyleLineNumber -Map $map -Index ([Math]::Max($m.Index, $at))) }
        }
    }
}

function ConvertFrom-GitQuotedPathHs {
    <#
        One path line from `git -c core.quotePath=true ls-files`, decoded. Git quotes a path with a
        non-ASCII byte as a C string with octal escapes, so the wire stays ASCII whatever the console
        code page, and the bytes are decoded here as UTF-8.
    #>
    param([Parameter(Mandatory)][string]$Line)
    if (-not ($Line.Length -ge 2 -and $Line.StartsWith('"') -and $Line.EndsWith('"'))) { return $Line }
    $s = $Line.Substring(1, $Line.Length - 2)
    $bytes = New-Object System.Collections.Generic.List[byte]
    for ($i = 0; $i -lt $s.Length; $i++) {
        $ch = $s[$i]
        if ($ch -ne '\' -or ($i + 1) -ge $s.Length) { $bytes.Add([byte][int][char]$ch); continue }
        $next = $s[$i + 1]
        if (($i + 3) -lt $s.Length -and $s.Substring($i + 1, 3) -match '^[0-7]{3}$') {
            $bytes.Add([Convert]::ToByte($s.Substring($i + 1, 3), 8)); $i += 3; continue
        }
        switch ($next) {
            'n' { $bytes.Add(10) } 't' { $bytes.Add(9) } 'r' { $bytes.Add(13) }
            default { $bytes.Add([byte][int][char]$next) }
        }
        $i++
    }
    return [System.Text.Encoding]::UTF8.GetString($bytes.ToArray())
}

function Get-HouseStyleTrackedFiles {
    <# Every tracked file of the repo, as a forward-slash path relative to its root. #>
    param([Parameter(Mandatory)][string]$RepoRoot)
    $out = & git -C $RepoRoot -c core.quotePath=true ls-files 2>$null
    if ($LASTEXITCODE -ne 0) { throw "git ls-files failed in $RepoRoot -- is it a git checkout?" }
    return [string[]]@($out | Where-Object { $_ } | ForEach-Object { ConvertFrom-GitQuotedPathHs -Line $_ })
}

function Test-HouseStyleAllowed {
    <# Is this finding answered by an allowlist entry: @{ Path = '<-like glob>'; Name = '<name or *>'; Reason } #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [AllowEmptyCollection()][object[]]$Allow = @()
    )
    foreach ($a in $Allow) {
        $glob = [string]$a.Path
        $nm = if ($a.ContainsKey('Name') -and $a.Name) { [string]$a.Name } else { '*' }
        if ($Path -like $glob -and ($nm -eq '*' -or $nm -ceq $Name)) { return $true }
    }
    return $false
}

function ConvertTo-HouseStyleAllowlist {
    <#
        The repo's answer to Get-HouseStyleAllowlist, checked: @{ Ok; Entries; Problem }. Every entry
        names a Path and a Reason -- an exception nobody can explain is one nobody can retire.
    #>
    param($Raw)
    if ($null -eq $Raw) { return @{ Ok = $true; Entries = @(); Problem = $null } }
    $entries = @()
    foreach ($e in @($Raw)) {
        if ($e -isnot [hashtable]) { return @{ Ok = $false; Entries = @(); Problem = 'every Get-HouseStyleAllowlist entry is a hashtable: @{ Path; Name; Reason }' } }
        if (-not $e.ContainsKey('Path') -or [string]::IsNullOrWhiteSpace([string]$e.Path)) { return @{ Ok = $false; Entries = @(); Problem = 'a Get-HouseStyleAllowlist entry has no Path' } }
        if (-not $e.ContainsKey('Reason') -or [string]::IsNullOrWhiteSpace([string]$e.Reason)) { return @{ Ok = $false; Entries = @(); Problem = "the Get-HouseStyleAllowlist entry for '$($e.Path)' has no Reason" } }
        $entries += $e
    }
    return @{ Ok = $true; Entries = $entries; Problem = $null }
}

function Read-HouseStyleAllowlist {
    <#
        The repo's Get-HouseStyleAllowlist from its scripts/repo-config.ps1, checked by
        ConvertTo-HouseStyleAllowlist. Read in a child scope with StrictMode off, the way the dev-preview
        hook reads Get-DevPreview; a repo that states nothing has an empty allowlist.
    #>
    param([Parameter(Mandatory)][string]$RepoRoot)
    # A forward slash: the CI runner is Linux, where a backslash is part of a file name.
    $configPath = Join-Path $RepoRoot 'scripts/repo-config.ps1'
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { return (ConvertTo-HouseStyleAllowlist -Raw $null) }
    $raw = & {
        Set-StrictMode -Off
        $null = . $args[0] 6>$null
        if (@($ExecutionContext.InvokeCommand.GetCommands('Get-HouseStyleAllowlist', 'Function', $false)).Count) { ,@(Get-HouseStyleAllowlist 6>$null) }
    } $configPath
    return (ConvertTo-HouseStyleAllowlist -Raw $raw)
}

function Invoke-HouseStyleCheck {
    <#
        Run the three checks over a checkout. Returns
        @{ Tag; Copies = @(@{ Path; Ok }); Findings = @(@{ Check; Path; Line; Name; Text }); Allowed; Notes }.
        $Files defaults to the checkout's tracked files; tests pass their own.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][hashtable]$Pin,
        [AllowEmptyCollection()][object[]]$Allow = @(),
        [string[]]$Files
    )

    if (-not $PSBoundParameters.ContainsKey('Files')) { $Files = Get-HouseStyleTrackedFiles -RepoRoot $RepoRoot }
    $findings = New-Object System.Collections.Generic.List[object]
    $notes = New-Object System.Collections.Generic.List[string]
    $copies = @()
    $allowed = 0
    $copyNames = Get-HouseStyleCopyNames

    # --- 1. pin --------------------------------------------------------------------------------------
    $verifiedCss = $null
    $copyPaths = @($Files | Where-Object { $copyNames -contains ([System.IO.Path]::GetFileName($_)).ToLowerInvariant() })
    foreach ($rel in $copyPaths) {
        $leaf = ([System.IO.Path]::GetFileName($rel)).ToLowerInvariant()
        $full = Join-Path $RepoRoot $rel
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
        $bytes = [System.IO.File]::ReadAllBytes($full)
        $ok = @(Get-HouseStyleSha256 -Bytes $bytes) -contains $Pin.Hashes[$leaf]
        $copies += @{ Path = $rel; Ok = $ok }
        if ($ok) {
            if ($leaf -eq 'house-style.css' -and -not $verifiedCss) { $verifiedCss = [System.Text.Encoding]::UTF8.GetString($bytes) }
        } else {
            $findings.Add(@{ Check = 'pin'; Path = $rel; Line = 0; Name = $leaf; Text = "is not the copy the house-style skill pins at $($Pin.Tag) -- replace it with the file served at that tag, unchanged" })
        }
    }
    if (-not @($copies | Where-Object { ([System.IO.Path]::GetFileName($_.Path)).ToLowerInvariant() -eq 'house-style.css' }).Count) {
        $findings.Add(@{ Check = 'missing'; Path = '.'; Line = 0; Name = 'house-style.css'; Text = "no vendored house-style.css in the tracked files -- vendor the copy the house-style skill pins at $($Pin.Tag)" })
    }

    # --- 2 and 3: the repo's own layer ---------------------------------------------------------------
    $houseTokens = @(); $houseClasses = @()
    if ($verifiedCss) {
        $defs = Get-HouseStyleDefinitions -CssText $verifiedCss
        $houseTokens = $defs.Tokens; $houseClasses = $defs.Classes
    } else {
        $notes.Add('check 2 (redefine) did not run: no verified house-style.css to read the house tokens and classes from')
    }
    $retired = Get-HouseStyleRetiredTokens
    $exts = Get-HouseStyleScanExtensions
    $copySet = @($copyPaths)
    $skipped = 0

    foreach ($rel in $Files) {
        if ($copySet -contains $rel) { continue }
        $ext = ([System.IO.Path]::GetExtension($rel)).ToLowerInvariant()
        if ($exts -notcontains $ext) { continue }
        $full = Join-Path $RepoRoot $rel
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
        if ((Get-Item -LiteralPath $full).Length -gt 2MB) { $skipped++; continue }
        $text = [System.IO.File]::ReadAllText($full, [System.Text.Encoding]::UTF8)
        if ($text.IndexOf([char]0) -ge 0) { $skipped++; continue }

        $hits = @()
        foreach ($h in @(Find-HouseStyleTokenHit -Text $text -Names $houseTokens)) {
            $hits += @{ Check = 'redefine'; Path = $rel; Line = $h.Line; Name = $h.Name; Text = "defines the house token $($h.Name) -- add a domain token under a name of its own, or fix the value upstream in dkj-brandbook" }
        }
        foreach ($h in @(Find-HouseStyleClassHit -Text $text -Classes $houseClasses)) {
            $hits += @{ Check = 'redefine'; Path = $rel; Line = $h.Line; Name = $h.Name; Text = "styles the house class $($h.Name) -- give the element a domain class of its own, or fix the class upstream in dkj-brandbook" }
        }
        foreach ($h in @(Find-HouseStyleTokenHit -Text $text -Names $retired -IncludeReads)) {
            $hits += @{ Check = 'retired'; Path = $rel; Line = $h.Line; Name = $h.Name; Text = "$($h.Kind) $($h.Name), a token name the brand book retired -- rename it per the rename tables in house-style/README.md at $($Pin.Tag)" }
        }
        foreach ($f in $hits) {
            if (Test-HouseStyleAllowed -Path $rel -Name $f.Name -Allow $Allow) { $allowed++ } else { $findings.Add($f) }
        }
    }

    if ($skipped) { $notes.Add("checks 2 and 3 skipped $skipped file(s) over 2 MB or holding a NUL byte -- a bundle there is not read") }
    # ToArray, not @(): Windows PowerShell 5.1 throws "argument types do not match" on @() over a List.
    return @{ Tag = $Pin.Tag; Copies = $copies; Findings = $findings.ToArray(); Allowed = $allowed; Notes = $notes.ToArray() }
}
