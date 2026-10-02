<#
.SYNOPSIS
    The '@'-import lines an adoption writes into a consumer's CLAUDE.md, and the one writer that puts
    them there. Issue #2532, extracted from #2531's constitution-import write.

.DESCRIPTION
    THE LINES, ONE WRITER. adopt-workflow-folder.ps1 (dkj-policy) writes the constitution import and,
    below it, the import of every dkj-policy extension the repo enables (#2697); dkj-policy-bwj's
    adopt-extension-import.ps1 writes its own. All of them have the same shape and the same failure when
    missing: a consumer runs for weeks without the rules in context, because a warning or a step on a
    skill page changes nothing a session knows (#2531). Two copies of the insertion would drift, so
    Add-ClaudeMdImportLine is the one definition.

    ANY EXTENSION, NOT A LIST (#2697). An extension is a plugin named 'dkj-policy-<slug>'
    (Test-PolicyExtensionName), and its line, its pattern and its detector are built from that name, so
    dkj-policy-dkjs needed no function of its own and the next extension will not either.

    WHAT IS HERE:
      * Get-ConstitutionImportLine / Get-ExtensionImportLine -- the lines, marketplace segment read off
        this file's own location (Get-DkjMarketplaceSegment).
      * Test-PolicyExtensionName / Get-PolicyExtensionNames / Get-ExtensionImportPattern -- which plugins
        are extensions, and the '@'-line pattern for one.
      * Test-ConstitutionImported / Test-ExtensionImported -- is the line already in the '@'-import
        closure, judged on the rows Get-AlwaysOnDocuments returns.
      * Add-ClaudeMdImportLine -- the fence-aware scan and the byte-preserving insert.

    MIRRORED INTO dkj-policy AND dkj-policy-bwj, because a script may only dot-source a lib that ships
    in its own plugin. consumer-check-lib.ps1 loads this file at file scope, so its callers keep
    reaching Get-ConstitutionImportLine and Test-ConstitutionImported through it as before.

    TWO DEPENDENCIES, LOADED WHERE THEY ARE USED: Add-ClaudeMdImportLine dot-sources
    write-target-lib.ps1 (#2533) and measure-context-lib.ps1 (Get-NextFenceState, #2534) from its own
    directory, inside the function, so loading this file costs nothing and defines nothing else.

    Dot-source it $PSScriptRoot-relative:

        . (Join-Path $PSScriptRoot 'claude-md-import-lib.ps1')

    Pure ASCII, per this repo's script-layer convention.
#>

function Get-DkjMarketplaceSegment {
    <#
        The name the marketplace clone sits under, read off a plugin payload's lib directory where it
        can be. A consumer runs these libs from
        '~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/scripts/lib', and <marketplace> is not
        always the canonical name: a consumer registered before the September 10, 2026 rename still has
        'claude-code-specialists'. Anywhere else (the source tree, a test) the canonical name is used.

        A SLUG OR NOTHING. The segment is the name a repo's own committed settings.json registered the
        marketplace under, and the line built from it is forwarded into session context by a hook -- so
        anything but a plain slug falls back to the canonical name rather than being printed.
    #>
    param([string]$LibDir = $PSScriptRoot)
    $parts = @(($LibDir -replace '\\', '/').Split('/') | Where-Object { $_ })
    for ($i = 0; $i -lt $parts.Count - 2; $i++) {
        if ($parts[$i] -ieq 'cache' -and $i -gt 0 -and $parts[$i - 1] -ieq 'plugins' -and $parts[$i + 2] -imatch '^dkj-policy(-[a-z0-9]+)*$') {
            if ($parts[$i + 1] -cmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}\z') { return $parts[$i + 1] }
            break
        }
    }
    return 'dkj-claude-plugins'
}

function Get-ConstitutionImportLine {
    <#
        The '@'-line a consumer's CLAUDE.md carries to load the dkj-policy constitution (issue #2374):
        one ABSOLUTE path into the marketplace clone, never into the version-pinned cache -- the same
        reasoning bootstrap.ps1's Get-DurablePersonaDir gives for the orchestrator import (an '@'-import
        takes no variable, and the cache directory is purged after an update).
    #>
    param([string]$LibDir = $PSScriptRoot)
    return "@~/.claude/plugins/marketplaces/$(Get-DkjMarketplaceSegment -LibDir $LibDir)/plugins/dkj-policy/CLAUDE.md"
}

function Test-PolicyExtensionName {
    <#
        Is this the name of a dkj-policy extension -- 'dkj-policy-<slug>', such as dkj-policy-bwj or
        dkj-policy-dkjs (#2697)? Every plugin under plugins/dkj-policy/ named that way extends the
        constitution with a CLAUDE.md of its own, which a repo enabling it imports directly below the
        constitution. A slug and nothing else, because the name is built into a line a hook prints.
    #>
    param([string]$Name)
    return [bool]($Name -cmatch '^dkj-policy-[a-z0-9]+(-[a-z0-9]+)*\z')
}

function Get-PolicyExtensionNames {
    <#
        The dkj-policy extensions among a list of plugin ids ('<name>@<marketplace>' or a bare name),
        sorted and de-duplicated -- the set a repo has to import, derived from what it enables rather than
        from a list kept here, so a new extension needs no edit to this file (#2697).
    #>
    param([AllowNull()][AllowEmptyCollection()][string[]]$PluginIds)
    return [string[]]@(@($PluginIds) | Where-Object { $_ } | ForEach-Object { ($_ -split '@', 2)[0] } |
        Where-Object { Test-PolicyExtensionName $_ } | Sort-Object -Unique)
}

function Get-ExtensionImportLine {
    <#
        The '@'-line that loads a dkj-policy extension of the constitution (#2374, #2697), which a repo
        enabling that extension carries directly below the constitution import. Same absolute-clone form,
        same marketplace segment. Throws on a name Test-PolicyExtensionName refuses.
    #>
    param([Parameter(Mandatory)][string]$Extension, [string]$LibDir = $PSScriptRoot)
    if (-not (Test-PolicyExtensionName $Extension)) { throw "not a dkj-policy extension name: '$Extension'" }
    return "@~/.claude/plugins/marketplaces/$(Get-DkjMarketplaceSegment -LibDir $LibDir)/plugins/dkj-policy/$Extension/CLAUDE.md"
}

function Get-ExtensionImportPattern {
    <# The regex Add-ClaudeMdImportLine's -ImportedPattern takes for one extension's line, under any marketplace name. #>
    param([Parameter(Mandatory)][string]$Extension)
    if (-not (Test-PolicyExtensionName $Extension)) { throw "not a dkj-policy extension name: '$Extension'" }
    return "^\s*@\S*/dkj-policy/$Extension/CLAUDE\.md\s*$"
}

function Test-ConstitutionImported {
    <#
        Does this always-on closure '@'-import the dkj-policy constitution (issue #2374)? Matched on the
        tail of the resolved path -- '.../plugins/dkj-policy/CLAUDE.md' -- so the absolute marketplace
        form, any marketplace name, and the source repo's relative form all count. A row that does NOT
        resolve (Exists = $false) still counts: the line is written, and a clone that has not refreshed
        yet is a lag the next 'claude plugin marketplace update' closes, not a missing import.
    #>
    param([AllowNull()][AllowEmptyCollection()][object[]]$Documents)
    foreach ($d in @($Documents)) {
        if ($null -eq $d) { continue }
        if ((([string]$d.Path) -replace '\\', '/') -imatch '/plugins/dkj-policy/CLAUDE\.md$') { return $true }
    }
    return $false
}

function Test-ExtensionImported {
    <# Test-ConstitutionImported's rule, for one extension's tail '.../dkj-policy/<extension>/CLAUDE.md'. #>
    param(
        [Parameter(Mandatory)][string]$Extension,
        [AllowNull()][AllowEmptyCollection()][object[]]$Documents
    )
    if (-not (Test-PolicyExtensionName $Extension)) { throw "not a dkj-policy extension name: '$Extension'" }
    foreach ($d in @($Documents)) {
        if ($null -eq $d) { continue }
        if ((([string]$d.Path) -replace '\\', '/') -imatch "/dkj-policy/$Extension/CLAUDE\.md$") { return $true }
    }
    return $false
}

function Add-ClaudeMdImportLine {
    <#
        Puts one '@'-import line into a consumer's CLAUDE.md, or reports that it is already there.
        Returns the action as a word: 'kept', 'create', 'insert', 'append' or 'refused'. Writes only with -Apply, so
        a dry run gets the same answer without a byte changing.

        ALREADY THERE is -ImportedPattern matched on an '@'-line of the file outside a fence, OR
        -ImportedElsewhere, the caller's verdict over the whole '@'-import closure (a line sitting in a
        file CLAUDE.md imports counts too). The file scan is ORed in because the closure walk degrades to
        @() where the measure lib is missing, and reading that as "not imported" would write the line a
        second time.

        AN '@'-LINE IS A COLUMN-0 ONE, through Get-ImportLinePath -- the rule the closure walk applies, so
        an indented look-alike can never read as imported here while the walk says it is not loaded.

        FENCE-AWARE, through Get-NextFenceState (measure-context-lib.ps1, #2534). A fenced block is quoted
        text: the adoption skill pages show these very lines inside one, so a consumer quoting a line must
        not read as having imported it, and a line must never be inserted into a quoted example.

        WHERE THE LINE GOES: directly BELOW the first '@'-line matching -AfterPattern, when one is given
        and found -- the extension sits under the constitution; otherwise directly ABOVE the first
        '@'-import -- the constitution names its own import first; with no import at all, appended. A
        CLAUDE.md that does not exist is created holding only this line.

        INSERTED, NEVER REWRITTEN. The file is split with each line KEEPING its own terminator and joined
        back with nothing, so not one existing byte changes -- a file that mixes LF and CRLF keeps both.
        The new line takes the terminator of the line it lands beside (or the file's first one when
        appended), and a byte-order mark is kept.

        NEVER THROUGH A SYMLINK OR JUNCTION (#2533). When -Path, or a directory between it and -Root, is a
        reparse point, the answer is 'refused' and nothing is read or written: the write would land
        outside the repo. Checked before the existence test, because a symlink to a missing file reads as
        "no CLAUDE.md" and creating it would create the link's target. Get-WriteTargetReparsePoint
        (write-target-lib.ps1) is loaded from this file's own directory, like measure-context-lib.
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Line,
        [Parameter(Mandatory)][string]$ImportedPattern,
        [string]$AfterPattern = '',
        [switch]$ImportedElsewhere,
        [switch]$Apply
    )

    . (Join-Path $PSScriptRoot 'write-target-lib.ps1')
    if (Get-WriteTargetReparsePoint -Path $Path -Root $Root) { return 'refused' }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        if ($Apply) { [System.IO.File]::WriteAllText($Path, ($Line + "`n"), $utf8NoBom) }
        return 'create'
    }

    . (Join-Path $PSScriptRoot 'measure-context-lib.ps1')

    $text  = [System.IO.File]::ReadAllText($Path)
    $lines = [System.Collections.Generic.List[string]]::new([string[]]@($text -split '(?<=\n)' | Where-Object { $_ -ne '' }))
    $firstImport = -1
    $anchor = -1
    $fence = ''
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $bare = $lines[$i].TrimEnd("`r", "`n")
        $wasFence = $fence
        $fence = Get-NextFenceState -Line $bare -Fence $fence
        # Get-ImportLinePath, not a looser pattern: Claude Code reads only a column-0 '@' as an import, so
        # an indented look-alike (a bullet, a blockquote) is prose -- neither "already there" nor an anchor.
        if ($wasFence -or $fence -or -not (Get-ImportLinePath -Line $bare)) { continue }
        if ($bare -imatch $ImportedPattern) { return 'kept' }
        if ($firstImport -lt 0) { $firstImport = $i }
        if ($AfterPattern -and $anchor -lt 0 -and $bare -imatch $AfterPattern) { $anchor = $i }
    }
    if ($ImportedElsewhere) { return 'kept' }

    $firstEol = if ($text -match '\r?\n') { $Matches[0] } else { "`n" }
    if ($anchor -ge 0) {
        $action = 'insert'
        if ($lines[$anchor] -match '\r?\n$') {
            $lines.Insert($anchor + 1, $Line + $Matches[0])
        } else {
            # The anchor is the last line and has no terminator: give it one, and the new line none.
            $lines[$anchor] = $lines[$anchor] + $firstEol
            $lines.Insert($anchor + 1, $Line)
        }
        $new = $lines -join ''
    } elseif ($firstImport -ge 0) {
        $action = 'insert'
        $eol = if ($lines[$firstImport] -match '\r?\n$') { $Matches[0] } else { $firstEol }
        $lines.Insert($firstImport, $Line + $eol)
        $new = $lines -join ''
    } elseif ($text.Trim().Length -eq 0) {
        $action = 'append'
        $new = $Line + $firstEol
    } else {
        $action = 'append'
        $lead = if ($text -match '\n$') { $firstEol } else { $firstEol + $firstEol }
        $new = $text + $lead + $Line + $firstEol
    }

    if ($Apply) {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
        [System.IO.File]::WriteAllText($Path, $new, (New-Object System.Text.UTF8Encoding($bom)))
    }
    return $action
}
