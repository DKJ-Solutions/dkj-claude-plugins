<#
.SYNOPSIS
    Generates the config blueprint: the source's own answers to the script contract, shipped to
    consumers so adopt-config.ps1 can offer them (issue #456).

.DESCRIPTION
    The shared workflow scripts are repo-agnostic and dot-source two REPO-OWNED libs from the
    consumer: scripts/lib/branch-info.ps1 and scripts/repo-config.ps1. check-script-contract.ps1
    reports which of those functions a consumer is missing and what the shared script FALLS BACK TO --
    never what this repo chose, and never why. That gap is what this blueprint closes.

    The blueprint is DERIVED, never hand-written. It reads:

      - the contract registry (scripts/lib/script-contract-lib.ps1) for the function list plus the
        Adopt marker and its reason;
      - this repo's own libs for the actual answer, taken as the function's SOURCE TEXT rather than
        its return value.

    TEXT, NOT VALUE, and that is the load-bearing choice. A value has to be serialized and
    reconstructed, which loses a hashtable's shape, a script-block's logic and every comment above it
    -- and the comments are the half a consumer actually needs, since the blueprint's worth is the
    reasoning rather than the answer. Text is also exact: what the consumer adopts is byte-for-byte
    what this repo runs.

    NO TIMESTAMP AND NO VERSION STAMP IN THE ARTEFACT, deliberately. The lint gate holds the committed
    file against a fresh generation, so anything that changes on every run would report drift on every
    run -- a check that is always red is a check that gets skipped.

.PARAMETER Check
    Generate in memory and compare against the committed artefact instead of writing it. Exits 1 on
    drift. This is what the lint gate and CI run.

.PARAMETER OutputPath
    Where to write the artefact, repo-root-relative. Left empty it is DERIVED: the blueprint belongs to
    the workflow plugin, and where that plugin's folder sits is a question the marketplace already
    answers. A test points this at a throwaway file.

    It was a literal until August 9, 2026, and that literal is the reason this parameter is documented
    at all: it had to be edited when the plugins were renamed, and again when the tree was grouped into
    teams/ and workflows/. Two edits for a fact the repo states in one place.
#>

[CmdletBinding()]
param(
    [switch]$Check,
    [string]$OutputPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# JUDGED (#1917): Resolve-RepoRootOrFail is check-report-lib's refusing sibling of Resolve-CheckRoot
# -- same precedence, but it names git's exit code and stderr instead of dying on $null.Trim().
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$repoRoot = Resolve-RepoRootOrFail -ScriptName 'build-config-blueprint.ps1'

. (Join-Path $PSScriptRoot '..\lib\script-contract-lib.ps1')
. (Join-Path $PSScriptRoot '..\repo-config.ps1')
# Which plugins this repo publishes, for resolving where the blueprint belongs (see $OutputPath below).
# This generator is the SOURCE's own tool and is deliberately not mirrored, so the sibling is always here.
. (Join-Path $PSScriptRoot '..\lib\plugin-tree-lib.ps1')

function Get-ScriptVarNames {
    <#
        The bare '$script:' variable names appearing anywhere under an AST node ('LiveStage'), sorted
        and unique.

        AN ASSIGNMENT TARGET COUNTS AS AN OCCURRENCE, because the parser draws no distinction: the left
        of '$script:X = 1' is a VariableExpressionAst exactly like the '$script:X' in a return. That is
        not a defect to work around here -- it is why the CALLER has to be careful which node it hands
        in, and Get-FunctionBlock is where that matters.
    #>
    param([Parameter(Mandatory = $true)][System.Management.Automation.Language.Ast]$Ast)

    $vars = $Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] }, $true)
    return @($vars |
        Where-Object { $_.VariablePath.UserPath -like 'script:*' } |
        ForEach-Object { $_.VariablePath.UserPath.Substring('script:'.Length) } |
        Sort-Object -Unique)
}

function Get-ScriptVarReferences {
    <#
        The '$script:' variables a piece of PowerShell actually READS, via the parser -- comments and
        docstrings excluded, because they are not AST nodes. Returns bare names ('LiveStage'), sorted
        and unique. Falls back to an empty list if the fragment does not parse on its own, which is the
        safe direction: nothing extra is pulled in.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$tokens, [ref]$errors)
    if ($errors -and $errors.Count -gt 0) { return @() }

    return (Get-ScriptVarNames -Ast $ast)
}

function Get-StatementEndIndex {
    <#
        The index of the last line of the statement starting at $Start: follows it down until its
        brackets balance, so an array or hashtable literal is taken whole rather than by its first
        line. Falls back to the last line of the input when they never balance.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string[]]$Lines,
        [Parameter(Mandatory = $true)][int]$Start
    )

    $depth = 0
    for ($j = $Start; $j -lt $Lines.Count; $j++) {
        $line = $Lines[$j]
        $depth += ([regex]::Matches($line, '[\(\[\{]')).Count
        $depth -= ([regex]::Matches($line, '[\)\]\}]')).Count
        if ($depth -le 0) { return $j }
    }
    return ($Lines.Count - 1)
}

function Get-ScriptVarAssignment {
    <#
        The full text of a '$script:<Name> = ...' assignment, following it across lines until its
        brackets balance -- so an array or hashtable literal comes along whole rather than as its
        first line. Empty string when the file does not assign that variable.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string[]]$Lines,
        [Parameter(Mandatory = $true)][string]$Name
    )

    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -notmatch ('^\s*\$script:' + [regex]::Escape($Name) + '\s*=')) { continue }
        return (($Lines[$i..(Get-StatementEndIndex -Lines $Lines -Start $i)]) -join "`n")
    }
    return ''
}

function Remove-ForeignAssignments {
    <#
        Drops every '$script:X = ...' statement whose X is not in -Keep, taking each one whole (a
        hashtable literal included). Comments, blank lines and the function body are returned untouched:
        this removes VALUES that belong to somebody else, never reasoning.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string[]]$Lines,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Keep
    )

    $kept = @()
    $i = 0
    while ($i -lt $Lines.Count) {
        # -and short-circuits, so $Matches is only read on a line that actually matched.
        if ($Lines[$i] -match '^\s*\$script:([A-Za-z0-9_]+)\s*=' -and $Matches[1] -notin $Keep) {
            $i = (Get-StatementEndIndex -Lines $Lines -Start $i) + 1
            continue
        }
        $kept += $Lines[$i]
        $i++
    }
    # Comma, so a single surviving line comes back as a one-element array rather than a bare string.
    return ,$kept
}

function Get-FunctionBlock {
    <#
        The source text of one function, together with the comment block and any $script: assignment
        that sits directly above it -- which is where this repo keeps the reasoning and the value.

        WALKS BACK OVER ONE CONTIGUOUS BLOCK, stopping at the first blank line above it, and that
        boundary is a bug fix rather than a simplification. A structural walk that stopped only at the
        previous '}' swept up whatever else sat between two functions -- measured on the first run:
        Get-LiveStage came out carrying the RETIREMENT NOTE of Get-ChangelogTierHeadings, a comment
        block about a different, deleted function, and Get-ReleaseNotesGrouping carried the whole
        six-knob preamble of issue #417. Both would have been shipped to consumers as that function's
        reasoning. In this file a function's own block is always contiguous -- comment lines, then the
        '$script:X = ...' value, then the function -- and anything before it is separated by a blank.

        A comment-only scan would not do either: the value lives in the assignment line BETWEEN the
        comment and the function, so stopping at the first non-comment line ships the reasoning without
        the answer.

        THE WALK IS THEN TRIMMED BACK TO THE VALUES THIS FUNCTION READS, which is the other half of the
        same problem and was measured separately (inbound #1126). See the comment at the trim below.
    #>
    param(
        # AllowEmptyString, because the array IS the file and a file has blank lines: PowerShell's
        # mandatory validation rejects an empty element inside a [string[]] without it.
        [Parameter(Mandatory = $true)][AllowEmptyString()][string[]]$Lines,
        [Parameter(Mandatory = $true)][System.Management.Automation.Language.FunctionDefinitionAst]$FunctionAst
    )

    $StartLine = $FunctionAst.Extent.StartLineNumber   # 1-based, from the parser
    $EndLine   = $FunctionAst.Extent.EndLineNumber     # 1-based, inclusive

    $first = $StartLine - 1   # to 0-based
    $i = $first - 1

    # Step over blank lines directly above the function, then take the contiguous run above it.
    while ($i -ge 0 -and $Lines[$i].Trim() -eq '') { $i-- }
    while ($i -ge 0) {
        $line = $Lines[$i]
        if ($line.Trim() -eq '') { break }                  # the block boundary
        if ($line -eq '}') { break }                        # end of the previous function
        if ($line -match '^\s*function\s') { break }         # start of another one
        $i--
    }
    $blockStart = $i + 1
    while ($blockStart -lt $first -and $Lines[$blockStart].Trim() -eq '') { $blockStart++ }

    # TRIM THE BLOCK BACK TO THE VALUES THIS FUNCTION READS. The contiguous walk is exactly right for a
    # function with its own value directly above it, and OVER-INCLUSIVE for the first of several that
    # share one assignment block: repo-config.ps1 puts all four entry-scaffold assignments above
    # Get-EntryTitlePlaceholder, so that record shipped the other three as well -- while each of those
    # three also ships its own, via the back-fill below. In the repo-config.ps1 that adopt-config then
    # writes, three variables end up assigned twice, the second assignment silently winning.
    #
    # Nothing errors and the placed file is correct until somebody EDITS it, which is what makes it
    # worth repairing: these four strings exist to be translated (inbound #410), and a consumer doing
    # exactly that changes them under the comment that explains them, only for an assignment further
    # down -- one they had no reason to read past -- to put the English back. new-branch then writes
    # English stubs and open-pr's body-heading gate goes on recognising only the English marker, with
    # nothing anywhere saying why. Measured in ccs-testrun-3 (inbound #1126).
    #
    # ASKED OF THE FUNCTION'S OWN AST, not of the assembled block. In the block a preamble assignment
    # appears as a VariableExpressionAst exactly like a genuine read does, so a scan of the whole thing
    # cannot tell "this function uses this value" from "this line happens to sit above it". The extent
    # the file parser already handed us carries no such ambiguity, and needs no parse of its own -- so
    # there is no failure mode in which a fragment does not parse and every value is dropped. A variable
    # the function assigns in its OWN body sits under that same extent, so it is kept too.
    $used  = @(Get-ScriptVarNames -Ast $FunctionAst)
    $block = ((Remove-ForeignAssignments -Lines @($Lines[$blockStart..($EndLine - 1)]) -Keep $used) -join "`n")

    # COMPLETE THE BLOCK WITH THE VALUES IT READS BUT DOES NOT CARRY -- the mirror image of the trim
    # above, and the reason both are needed. Four of this file's functions share one assignment block
    # (the entry-scaffold wording), so the contiguous run above the FIRST of them carries the values and
    # the other three carry none. Copied on its own, such a function returns $null in the consumer -- a
    # silent wrong answer where an absent function would have got the documented fallback. So any
    # $script: variable the block reads without assigning is pulled in.
    # READ THROUGH THE PARSER, NOT BY REGEX, for the same reason check 19 was rewritten that way: a
    # text scan cannot tell code from prose. Measured here -- Get-EntryTitlePlaceholder's comment block
    # points the reader at '$script:EntryScaffoldDefaults in entry-scaffold-lib.ps1', a variable that
    # lives in a different file entirely, and a regex reported it as a value this function reads.
    $needed = @(Get-ScriptVarReferences -Text $block)
    $prefix = @()
    foreach ($name in $needed) {
        # (?m) so '^' means start-of-LINE: $block is a multi-line string, and without it this would
        # only ever match an assignment on the block's very first line.
        if ($block -match ('(?m)^\s*\$script:' + [regex]::Escape($name) + '\s*=')) { continue }
        $assignment = Get-ScriptVarAssignment -Lines $Lines -Name $name
        if ($assignment) { $prefix += $assignment }
    }
    if ($prefix.Count -gt 0) {
        $block = (($prefix -join "`n") + "`n" + $block)
    }

    return $block
}

function Get-LibFunctions {
    <# Every function definition in a file, by name, as its parser AST -- read through the PowerShell
       parser rather than by regex. A regex over 'function X' matches the word in a docstring too,
       which is how check 19 was first measured wrong.

       THE AST RATHER THAN ONLY ITS TWO LINE NUMBERS, because Get-FunctionBlock has to ask what the
       function itself reads, and the node it needs for that has already been parsed here. #>
    param([Parameter(Mandatory = $true)][string]$Path)

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if ($errors -and $errors.Count -gt 0) {
        throw "cannot parse '$Path': $($errors[0].Message)"
    }

    $map = @{}
    foreach ($fn in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
        $map[$fn.Name] = $fn
    }
    return $map
}

# --- Build ----------------------------------------------------------------------------------------

$contract = Get-ScriptContract
$libCache = @{}
$records  = @()

foreach ($rec in $contract) {
    $libRel  = $rec.Lib
    $libPath = Join-Path $repoRoot $libRel

    if (-not $libCache.ContainsKey($libRel)) {
        if (-not (Test-Path -LiteralPath $libPath -PathType Leaf)) {
            throw "the blueprint cannot be built: this repo is missing '$libRel', which the contract declares. The source must answer its own contract before it can offer the answers to anyone else."
        }
        $libCache[$libRel] = @{
            Lines     = @(Get-Content -LiteralPath $libPath)
            Functions = Get-LibFunctions -Path $libPath
        }
    }

    $lib      = $libCache[$libRel]
    $declared = $lib.Functions.ContainsKey($rec.Function)

    # A record the SOURCE itself leaves at the fallback. Recorded as declared=false with no text rather
    # than skipped: "this repo does not state it either" is an answer a consumer can act on, and a
    # silently shorter blueprint is not.
    $text = ''
    if ($declared) {
        $text = Get-FunctionBlock -Lines $lib.Lines -FunctionAst $lib.Functions[$rec.Function]
    }

    $records += [ordered]@{
        lib       = $libRel
        function  = $rec.Function
        adopt     = $rec.Adopt
        adoptWhy  = $rec.AdoptWhy
        optional  = [bool]($rec.ContainsKey('Optional') -and $rec.Optional)
        default   = $(if ($rec.ContainsKey('Default')) { $rec.Default } else { '' })
        returns   = $(if ($rec.ContainsKey('Returns')) { $rec.Returns } else { '' })
        declared  = $declared
        text      = $text
    }
}

$blueprint = [ordered]@{
    schema     = 1
    sourceRepo = Get-RepoName
    note       = 'Generated by scripts/sync/build-config-blueprint.ps1 from the source repo own libs. Do not edit by hand: the lint gate regenerates this file and reports any difference.'
    records    = $records
}

$json = ($blueprint | ConvertTo-Json -Depth 6)
# LF, and a trailing newline -- the same normalization the shared-scripts mirror uses, so a checkout
# with autocrlf does not read as drift.
$json = ($json -replace "`r`n", "`n")
if (-not $json.EndsWith("`n")) { $json += "`n" }

# THE DESTINATION, ASKED OF THE MARKETPLACE when the caller did not name one. The blueprint lives in
# whichever plugin already ships one; that is a fact about the tree, and the tree is described in
# .claude-plugin/marketplace.json rather than in this parameter's default. Refuses rather than guessing
# if no plugin carries a blueprint/ directory -- writing one into a folder chosen by fallback would
# produce an artefact no consumer ever receives, silently.
if (-not $OutputPath) {
    $bpPlugin = @(Get-RepoPluginRoots -RepoRoot $repoRoot |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.Root 'blueprint') -PathType Container })
    if ($bpPlugin.Count -ne 1) {
        Write-Error "cannot decide where the config blueprint belongs: $($bpPlugin.Count) published plugin(s) carry a blueprint/ directory, expected exactly 1. Pass -OutputPath explicitly."
        exit 1
    }
    $OutputPath = Join-Path $bpPlugin[0].RelativeRoot 'blueprint\config-blueprint.json'
}
$outPath = Join-Path $repoRoot $OutputPath

if ($Check) {
    if (-not (Test-Path -LiteralPath $outPath -PathType Leaf)) {
        Write-Error "config blueprint missing: '$OutputPath' has never been generated. Run scripts/sync/build-config-blueprint.ps1 and commit the result."
        exit 1
    }
    $current = [System.IO.File]::ReadAllText($outPath) -replace "`r`n", "`n"
    if ($current -ne $json) {
        Write-Error "config blueprint is stale: '$OutputPath' does not match what the source's own libs and contract registry produce right now. Run scripts/sync/build-config-blueprint.ps1 and commit the result. This is the artefact consumers adopt from, so a stale one hands them last week's answers with this week's reasoning."
        exit 1
    }
    Write-Host "config blueprint: up to date ($($records.Count) records)." -ForegroundColor Green
    exit 0
}

$outDir = Split-Path -Parent $outPath
if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
[System.IO.File]::WriteAllText($outPath, $json)

$copyCount   = @($records | Where-Object { $_.adopt -eq 'copy' }).Count
$decideCount = @($records | Where-Object { $_.adopt -eq 'decide' }).Count
$undeclared  = @($records | Where-Object { -not $_.declared }).Count

Write-Host "config blueprint written: $OutputPath" -ForegroundColor Green
Write-Host "  $($records.Count) records -- $copyCount copy, $decideCount decide, $undeclared left at the built-in fallback by this repo too."
