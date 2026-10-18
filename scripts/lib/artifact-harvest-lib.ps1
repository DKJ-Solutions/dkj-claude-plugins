<#
.SYNOPSIS
    Finds the claude.ai Artifacts a session in this repo published, in this machine's session transcripts,
    and merges them into scripts/dashboard/artifacts.json -- the register the dev server's /artifacts page
    reads (#3112). The script around it is scripts/maintenance/harvest-artifacts.ps1, documented in the
    repo-local harvest-artifacts skill.

.DESCRIPTION
    THE TRANSCRIPTS ARE THE SOURCE, NOT THE ACCOUNT LISTING. The claude.ai listing holds Artifacts from
    several repos and carries no repo field; a transcript record carries the cwd it ran in, so a publish
    call is attributed to this repo by where its session stood.

    WHAT COUNTS AS A PUBLISH. An Artifact call whose action is publish (or omitted) and which is no asset
    upload, and a Claude Docs batch that creates a doc. The url is read from the call's RESULT, never its
    input: a first publish has no url in its input, and a refused publish has none in its result, so a
    call that did not publish adds nothing.

    THE MERGE ONLY ADDS. A url the register lacks becomes a row; a url it holds only has its dates widened
    (created moved earlier, updated moved later). A title, kind or about line already in the register is
    never rewritten, because a person may have corrected it there. Urls are compared without their query
    string, so a share link (?sk=...) and the plain link are one Artifact.

    No I/O in the merge; Read-ArtifactPublishes reads one transcript. Pure ASCII (repo convention for
    .ps1). Tested by scripts/tests/dev-pages.tests.ps1.
#>

function Get-ArtifactUrlKey {
    <# The url an Artifact is recorded under: the link without a query string or a fragment. #>
    param([AllowEmptyString()][string]$Url)
    return ($Url -replace '[?#].*$', '')
}

function Get-ArtifactPublishUrl {
    <#
        The Artifact a tool result names as published, or '' when it names none. -Docs reads a Claude Docs
        create result, which carries the doc's code/artifact link; otherwise the Artifact tool's own wording
        ("Published <file> at <url>", "Created a new Artifact at <url>", "Updated the Artifact at <url>"),
        where the first "at <url>" is the Artifact itself -- a typed create names its type after it.
    #>
    param([AllowEmptyString()][string]$Text, [switch]$Docs)
    $m = if ($Docs) { [regex]::Match($Text, 'https://claude\.ai/code/artifact/[0-9a-f-]+') }
         else       { [regex]::Match($Text, '\bat (https://claude\.ai/(?:code/)?artifact/[A-Za-z0-9-]+)') }
    if (-not $m.Success) { return '' }
    if ($Docs) { return $m.Value }
    return $m.Groups[1].Value
}

function Test-PathUnderRoot {
    <# True when -Path is -Root or lies under it, compared case-insensitively with either slash. #>
    param([AllowEmptyString()][string]$Path, [string[]]$Root)
    if (-not $Path) { return $false }
    $p = ($Path -replace '/', '\').TrimEnd('\')
    foreach ($r in $Root) {
        if (-not $r) { continue }
        $q = ($r -replace '/', '\').TrimEnd('\')
        if ($p -ieq $q -or $p.StartsWith($q + '\', [StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function Get-ArtifactPublishTitle {
    <# A publish call's title: its own -title, else the <title> of the page it sent if that file still exists, else the file's name. #>
    param($ToolInput)
    if ($ToolInput.title) { return [string]$ToolInput.title }
    $file = [string]$ToolInput.file_path
    if (-not $file) { return '' }
    if (Test-Path -LiteralPath $file -PathType Leaf) {
        $m = [regex]::Match([IO.File]::ReadAllText($file), '<title>\s*([^<]+?)\s*</title>', 'IgnoreCase')
        if ($m.Success) { return $m.Groups[1].Value }
    }
    return [IO.Path]::GetFileNameWithoutExtension($file)
}

function Read-ArtifactPublishes {
    <#
        Every publish in one transcript (-Path, a .jsonl) whose session stood in one of -Root. Returns a list
        of @{ Url; Kind; Title; About; Date }, Date the UTC day of the call. Only lines that can hold a call or
        its result are parsed, so a 50 MB transcript costs one read and a handful of ConvertFrom-Json calls.
        A line that is not JSON is skipped: a transcript being written is cut mid-line at its end.
    #>
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string[]]$Root)
    $pending = @{}
    $found = New-Object System.Collections.ArrayList
    foreach ($line in [IO.File]::ReadLines($Path)) {
        $isCall = $line.Contains('"name":"Artifact"') -or $line.Contains('Claude_Docs__batch"')
        $isResult = $pending.Count -and $line.Contains('"tool_use_id"') -and $line.Contains('claude.ai/')
        if (-not ($isCall -or $isResult)) { continue }
        try { $rec = $line | ConvertFrom-Json } catch { continue }
        if (-not $rec.message -or $rec.message.content -isnot [array]) { continue }
        foreach ($c in $rec.message.content) {
            if ($c.type -eq 'tool_use') {
                if (-not (Test-PathUnderRoot $rec.cwd $Root)) { continue }
                $in = $c.input
                if ($c.name -eq 'Artifact') {
                    if (($in.action -and $in.action -ne 'publish') -or $in.asset) { continue }
                    $pending[$c.id] = @{
                        Docs  = $false
                        Kind  = $(if ($in.type_url) { 'typed' } else { 'page' })
                        Title = (Get-ArtifactPublishTitle $in)
                        About = [string]$in.description
                        Date  = ([string]$rec.timestamp).Substring(0, [Math]::Min(10, ([string]$rec.timestamp).Length))
                    }
                } elseif ($c.name -like '*Claude_Docs__batch' -and $in.container -and $in.container.create) {
                    $pending[$c.id] = @{
                        Docs  = $true
                        Kind  = 'document'
                        Title = [string]$in.container.create.name
                        About = ''
                        Date  = ([string]$rec.timestamp).Substring(0, [Math]::Min(10, ([string]$rec.timestamp).Length))
                    }
                }
            } elseif ($c.type -eq 'tool_result' -and $pending.ContainsKey([string]$c.tool_use_id)) {
                $call = $pending[[string]$c.tool_use_id]
                $pending.Remove([string]$c.tool_use_id)
                $text = if ($c.content -is [string]) { $c.content } else { (@($c.content) | ForEach-Object { [string]$_.text }) -join "`n" }
                $url = Get-ArtifactPublishUrl $text -Docs:$call.Docs
                if ($url) {
                    [void]$found.Add(@{ Url = $url; Kind = $call.Kind; Title = $call.Title; About = $call.About; Date = $call.Date })
                }
            }
        }
    }
    # Unrolled on purpose: callers collect with @(...), and a comma-wrapped empty array would count as one publish.
    return $found.ToArray()
}

function Merge-ArtifactRegister {
    <#
        The register (-Register, the parsed artifacts.json; $null for none) with -Found merged in. Returns
        @{ Artifacts (rows in register order, new ones appended oldest first); Added (urls); Widened (urls whose
        dates moved) }. A new row takes its title and kind from the first publish that names them and its about
        line from the last, since a later description is the one written against the finished page.
    #>
    param($Register, [object[]]$Found = @())
    $rows = New-Object System.Collections.ArrayList
    $byKey = @{}
    if ($Register -and $Register.artifacts) {
        foreach ($a in @($Register.artifacts)) {
            if (-not $a) { continue }
            $row = [ordered]@{ title = [string]$a.title; url = [string]$a.url; kind = [string]$a.kind
                               created = [string]$a.created; updated = [string]$a.updated; about = [string]$a.about }
            [void]$rows.Add($row)
            $byKey[(Get-ArtifactUrlKey $row.url)] = $row
        }
    }
    $added = New-Object System.Collections.ArrayList
    $widened = New-Object System.Collections.ArrayList
    foreach ($f in @($Found | Where-Object { $_ } | Sort-Object { $_.Date })) {
        $key = Get-ArtifactUrlKey $f.Url
        $row = $byKey[$key]
        if (-not $row) {
            $row = [ordered]@{ title = $f.Title; url = $key; kind = $f.Kind; created = $f.Date; updated = $f.Date; about = $f.About }
            [void]$rows.Add($row)
            $byKey[$key] = $row
            [void]$added.Add($key)
            continue
        }
        $isNew = $added -contains $key
        if ($isNew) {
            if (-not $row.title -and $f.Title) { $row.title = $f.Title }
            if ($f.About) { $row.about = $f.About }
        }
        $moved = $false
        if ($f.Date -and (-not $row.created -or $f.Date -lt $row.created)) { $row.created = $f.Date; $moved = $true }
        if ($f.Date -and (-not $row.updated -or $f.Date -gt $row.updated)) { $row.updated = $f.Date; $moved = $true }
        if ($moved -and -not $isNew -and $widened -notcontains $key) { [void]$widened.Add($key) }
    }
    return @{ Artifacts = $rows.ToArray(); Added = $added.ToArray(); Widened = $widened.ToArray() }
}

function ConvertTo-ArtifactRegisterJson {
    <#
        The register file's text: two-space indented, one key per line, in the order the file has always had.
        Windows PowerShell 5.1's ConvertTo-Json indents unevenly, so the shape is written here and only each
        string goes through it.
    #>
    param([string]$About, [string]$Date, [string]$Method, [object[]]$Artifacts = @())
    # Only what JSON requires is escaped: 5.1's ConvertTo-Json also turns ' < > & into \u00xx, which is valid
    # and makes every title with an apostrophe unreadable in a diff.
    $q = { param($s)
        $t = ([string]$s).Replace('\', '\\').Replace('"', '\"')
        '"' + [regex]::Replace($t, '[\x00-\x1f]', { param($m) '\u{0:x4}' -f [int][char]$m.Value }) + '"' }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append("{`n  `"about`": " + (& $q $About) + ",`n")
    [void]$sb.Append("  `"recordedFrom`": {`n    `"date`": " + (& $q $Date) + ",`n    `"method`": " + (& $q $Method) + "`n  },`n")
    [void]$sb.Append("  `"artifacts`": [")
    $first = $true
    foreach ($a in $Artifacts) {
        [void]$sb.Append($(if ($first) { "`n" } else { ",`n" }))
        $first = $false
        $fields = foreach ($k in 'title', 'url', 'kind', 'created', 'updated', 'about') { "      `"$k`": " + (& $q $a[$k]) }
        [void]$sb.Append("    {`n" + ($fields -join ",`n") + "`n    }")
    }
    [void]$sb.Append($(if ($first) { "]`n}`n" } else { "`n  ]`n}`n" }))
    return $sb.ToString()
}
