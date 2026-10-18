<#
.SYNOPSIS
    The pure half of the house-style repoint (#3100): given what the brand book serves at a new release
    tag, the text of every file in this tree the repoint rewrites. No network, no git, no file writes --
    scripts/ci/repoint-house-style.ps1 does those and calls these.

.DESCRIPTION
    WHY IT EXISTS. A release of DKJ-Solutions/dkj-brandbook reached the apps only after a session repointed
    the house-style skill by hand: every link to the previous tag, the commit, both sha256 checksums, the
    retired-name list and the two vendored copies. Measured on #3100: four times in five days (#2986, #3033,
    #3089, and the v0.1.0 consolidation in #3084). The runner (.github/workflows/house-style-repoint.yml)
    now does it on a schedule and opens one pull request; a person still judges and ships it.

    WHAT IS REWRITTEN, AND WHAT IS NOT. Only the tag in a brand-book URL (`/<tag>/`) and in the phrase
    "release tag `<tag>`" is replaced, never every occurrence of the string: the skill page also names
    tags as history ("Its first, `v0.1.0`"), and those stay what they were.

    THE RETIRED NAMES ARE DERIVED, NOT TRANSCRIBED. The list grows by every token the previous pinned
    stylesheet defined that the new one does not, plus every name in the `Was` column of the README's
    rename tables at the new tag, and it shrinks by every name the new stylesheet defines again. That is
    the rule house-style-rules.ps1's header states for the hand-kept list, applied mechanically.

    THE SAFETY READS ARE A SPELLING DENYLIST, AND THEY ARE NOT THE GATE. They refuse the spellings the
    skill page names (#2954), which catches an accident; no denylist can prove executable JavaScript
    harmless -- `window['fe'+'tch']` passes any of them (the security review of #3100). So a release that
    changes house-theme.js gets an OPEN step in the branch document, reading its diff, and the step-list
    gate holds the ship on it until a person has done that. The denylist only decides whether a pull
    request opens at all.

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/house-style-repoint.tests.ps1.
#>

Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'document-newline-lib.ps1')

function Get-HouseStyleBrandbookRepo {
    <# The repo the house style is released from. #>
    return 'DKJ-Solutions/dkj-brandbook'
}

function Test-HouseStyleReleaseTag {
    <#
        A release tag this runner accepts: vX.Y.Z and nothing else. The tag travels into a branch name, a
        commit message and a URL, so anything outside that shape is refused rather than escaped.
    #>
    param([AllowEmptyString()][string]$Tag)
    # \z, not $: `$` also matches before a trailing newline, which would carry one into the branch name.
    return [bool]($Tag -cmatch '^v\d+\.\d+\.\d+\z')
}

function Get-HouseStyleRepointBranch {
    <# The branch a repoint to this tag is built on: feat/house-style-v0-3-0 for v0.3.0. #>
    param([Parameter(Mandatory)][string]$Tag)
    return 'feat/house-style-' + ($Tag -replace '\.', '-')
}

function Get-HouseStyleSafetyFindings {
    <#
        What the skill page forbids in a fetched copy. Returns one string per finding; empty means clean.
        house-theme.js: no network call, no eval, no cookie, and storage only through localStorage under a
        single key (the theme choice). house-style.css: no @import and no remote url().
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$CssText,
        [Parameter(Mandatory)][AllowEmptyString()][string]$JsText
    )

    $findings = New-Object System.Collections.Generic.List[string]
    $jsForbidden = [ordered]@{
        'fetch('          = '(?<![\w$])fetch\s*\('
        'XMLHttpRequest'  = 'XMLHttpRequest'
        'WebSocket'       = 'WebSocket'
        'sendBeacon'      = 'sendBeacon'
        'import('         = '(?<![\w$])import\s*\('
        'eval'            = '(?<![\w$])eval\s*\('
        'Function'        = '(?<![\w$])Function\s*\('
        'document.cookie' = 'document\s*\.\s*cookie'
        'sessionStorage'  = 'sessionStorage'
        'indexedDB'       = 'indexedDB'
    }
    foreach ($name in $jsForbidden.Keys) {
        if ([regex]::IsMatch($JsText, $jsForbidden[$name])) { $findings.Add("house-theme.js uses $name") }
    }
    $keys = @([regex]::Matches($JsText, '\.\s*setItem\s*\(\s*([^,)]+)') |
        ForEach-Object { $_.Groups[1].Value.Trim() } | Sort-Object -Unique)
    if ($keys.Count -gt 1) { $findings.Add("house-theme.js stores under more than one key: $($keys -join ', ')") }

    $css = [regex]::Replace($CssText, '/\*[\s\S]*?\*/', ' ')
    if ([regex]::IsMatch($css, '@import\b', 'IgnoreCase')) { $findings.Add('house-style.css carries an @import') }
    if ([regex]::IsMatch($css, 'url\(\s*[''"]?\s*(https?:)?//', 'IgnoreCase')) { $findings.Add('house-style.css carries a remote url()') }
    return [string[]]$findings.ToArray()
}

function Get-HouseStyleRenamedNames {
    <# Every token name in the `Was` column of the README's rename tables. #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$ReadmeText)

    $names = New-Object System.Collections.Generic.HashSet[string]
    $inTable = $false
    foreach ($line in ($ReadmeText -split "`r?`n")) {
        $t = $line.TrimStart('>', ' ')
        if ($t -match '^\|\s*Was\s*\|') { $inTable = $true; continue }
        if (-not $t.StartsWith('|')) { $inTable = $false; continue }
        if (-not $inTable -or $t -match '^\|[\s|:-]+\|?$') { continue }
        $was = ($t.Trim('|') -split '\|')[0]
        foreach ($m in [regex]::Matches($was, '`(--[A-Za-z0-9_-]+)`')) { [void]$names.Add($m.Groups[1].Value) }
    }
    return [string[]]@($names | Sort-Object)
}

function Get-HouseStyleNextRetired {
    <#
        The retired-name list after a repoint: the current list, plus what the old stylesheet defined and
        the new one does not, plus the README's renamed names -- minus everything the new one defines.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Current,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$OldTokens,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$NewTokens,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Renamed
    )
    $live = [System.Collections.Generic.HashSet[string]]::new([string[]]$NewTokens, [StringComparer]::Ordinal)
    $set = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($n in (@($Current) + @($OldTokens) + @($Renamed))) { if ($n -and -not $live.Contains($n)) { [void]$set.Add($n) } }
    # Ordinal, because a culture sort ignores the hyphens these names are made of.
    $out = [string[]]@($set)
    [Array]::Sort($out, [StringComparer]::Ordinal)
    return $out
}

function Set-HouseStyleSkillPin {
    <#
        The skill page repointed: every brand-book URL segment `/<From>/` and the phrase "release tag
        `<From>`" to the new tag, the commit, and the two checksum cells. Throws when a piece it must
        replace is not there, so a reshaped page fails the run instead of half-repointing.
    #>
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$From,
        [Parameter(Mandatory)][string]$To,
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][hashtable]$Hashes
    )

    $segment = '(?<=dkj-brandbook/(?:(?:tree|blob)/)?)' + [regex]::Escape($From) + '(?=/)'
    if (-not [regex]::IsMatch($Text, $segment)) { throw "the skill page carries no brand-book link at $From" }
    $out = [regex]::Replace($Text, $segment, $To)
    $phrase = "release tag ``$From``"
    if (-not $out.Contains($phrase)) { throw "the skill page does not name $phrase" }
    $out = $out.Replace($phrase, "release tag ``$To``")

    $commitPattern = '(?<=points at commit `)[0-9a-f]{40}(?=`)'
    if (-not [regex]::IsMatch($out, $commitPattern)) { throw 'the skill page names no commit to replace' }
    $out = [regex]::Replace($out, $commitPattern, $Commit)

    foreach ($leaf in $Hashes.Keys) {
        $row = '(?m)(^\|\s*`' + [regex]::Escape($leaf) + '`\s*\|[^|]*\|\s*`)[0-9a-f]{64}(`)'
        if (-not [regex]::IsMatch($out, $row)) { throw "the skill page has no checksum row for $leaf" }
        $out = [regex]::Replace($out, $row, '${1}' + $Hashes[$leaf] + '${2}')
    }
    return $out
}

function Set-HouseStyleRetiredList {
    <#
        house-style-rules.ps1 with Get-HouseStyleRetiredTokens' docstring naming the new tag and its list
        replaced, wrapped the way the hand-written list was.
    #>
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Tag,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Names
    )

    $nl = Get-DocumentNewline -Content $Text
    $lines = New-Object System.Collections.Generic.List[string]
    $current = ''
    foreach ($n in $Names) {
        $item = "'$n'"
        if ($current -and ($current.Length + $item.Length + 2) -gt 104) { $lines.Add($current + ','); $current = '' }
        $current = if ($current) { "$current, $item" } else { $item }
    }
    if ($current) { $lines.Add($current) }
    $body = ($lines | ForEach-Object { '        ' + $_ }) -join $nl

    $pattern = '(?s)(function Get-HouseStyleRetiredTokens \{\r?\n\s*<# The token names the brand book retired, as of the tag the skill pins \()[^)]*(\)\. #>\r?\n\s*return \[string\[\]\]@\(\r?\n).*?(\r?\n\s*\)\r?\n\})'
    if (-not [regex]::IsMatch($Text, $pattern)) { throw 'house-style-rules.ps1 has no Get-HouseStyleRetiredTokens list in the expected shape' }
    $evaluator = [System.Text.RegularExpressions.MatchEvaluator] {
        param($m) $m.Groups[1].Value + $Tag + $m.Groups[2].Value + $body + $m.Groups[3].Value
    }
    return [regex]::Replace($Text, $pattern, $evaluator)
}

function Set-HouseStyleRepointDocument {
    <#
        The branch document new-branch.ps1 scaffolded, filled for a repoint: PLAN, the CREATE steps (done,
        because this run did them), TEST, and the DEPLOY text. The two **Score:** lines are left for the
        person who ships it: whether a release is small or noticed by every app is a judgement this runner
        cannot make, and the cut refuses an unscored entry, so it cannot be skipped by accident.
    #>
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$From,
        [Parameter(Mandatory)][string]$To,
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][bool]$FilesChanged,
        [Parameter(Mandatory)][bool]$JsChanged,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Added,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Removed
    )

    $repo = Get-HouseStyleBrandbookRepo
    $short = $Commit.Substring(0, 8)
    $files = if ($FilesChanged) {
        'Both files changed, so the two vendored copies move with the pin.'
    } else {
        'The two files are byte-identical to the previous tag, so the vendored copies stand.'
    }
    $retired = if ($Added.Count -or $Removed.Count) {
        $parts = @()
        if ($Added.Count)   { $parts += 'newly retired: ' + (($Added | ForEach-Object { "``$_``" }) -join ', ') }
        if ($Removed.Count) { $parts += 'live again: ' + (($Removed | ForEach-Object { "``$_``" }) -join ', ') }
        'The retired-name list changed (' + ($parts -join '; ') + ').'
    } else {
        'No token was renamed or removed, so the retired-name list stands.'
    }

    $nl = Get-DocumentNewline -Content $Text
    $phases = @(
        '### PLAN', '',
        "Opened by the house-style repoint runner (#3100): ``$repo`` released ``$To``, and the skill pinned ``$From``.",
        "The files served at ``$To`` passed the denylist of spellings the skill page forbids, which is not a",
        "review of the script. $files $retired",
        'Before shipping: read the release in the brand book, score the two DEPLOY tiers, and say there what an',
        'app that takes the new copy will notice.', '',
        '### CREATE', '',
        "- [x] Repoint every brand-book link in the ``house-style`` skill to ``$To``, its commit to ``$short`` and both checksums",
        '- [x] Replace the vendored copies under `scripts/dashboard/house-style/` and the plugin''s `assets/house-style/`',
        '- [x] `Get-HouseStyleRetiredTokens` follows the new tag', '',
        '### TEST', '',
        'The required check runs `check-house-style.tests.ps1`, which holds both vendored copies to the new checksums.'
    )
    if ($JsChanged) {
        $phases += @('', '- [ ] Read the `house-theme.js` diff in full: it is inlined into every app that takes the copy, and no check here can prove a script harmless')
    }
    $phases = (@($phases) + @('', '')) -join $nl

    $plan = '(?s)### PLAN\r?\n.*?(?=### DEPLOY:)'
    if (-not [regex]::IsMatch($Text, $plan)) { throw 'the branch document has no PLAN..DEPLOY span' }
    $out = [regex]::Replace($Text, $plan, [System.Text.RegularExpressions.MatchEvaluator] { param($m) $phases })

    $deploy = @(
        "The ``house-style`` skill now fetches from the brand book's ``$To`` release",
        "([$repo@$To](https://github.com/$repo/releases/tag/$To)). $files $retired", ''
    ) -join $nl
    $first = '(?m)(^### DEPLOY:[^\r\n]*\r?\n\r?\n)(?=\*\*Score:\*\*)'
    if (-not [regex]::IsMatch($out, $first)) { throw 'the branch document has no empty DEPLOY section' }
    return ([regex]$first).Replace($out, '${1}' + $deploy.Replace('$', '$$') + $nl, 1)
}
