<#
.SYNOPSIS
    Counts the status column(s) of a test round's step table(s) and prints the totals as markdown,
    so a round's headline figures are an output rather than a hand count.

.DESCRIPTION
    The sibling of round-baseline.measure.ps1, for the table next door. That script was written
    because round v12 typed a baseline figure by hand and got it wrong (issue #371); the repair
    covered the baseline table and not the step table beside it, which was still counted by hand --
    and was wrong in exactly the same way. Round v13 measured it (inbound #387): the v12 totals line
    read "0 geblokkeerd, 3 wrijving, 38 groen, 2 niet gemeten" while its own column held 0, 4, 39 and
    3 across 46 rows. One short in every category, i.e. three rows added without the totals line
    following -- and the round's assignment then inherited the error, naming three friction rows where
    the column had four.

    Those figures are not decorative: a round is hung on them ("v12 stood at 0 blocked, 3 friction,
    38 green -- do those three go green?"). A reader who counts the column cannot line their total up
    against the previous round's without first discovering that the basis is wrong.

    WHAT IT ASSUMES ABOUT THE TABLE, AND WHAT IT DOES NOT.
    It assumes only the shape: a markdown table whose header has one column per round. It has NO
    vocabulary of its own -- no hardcoded status names, no hardcoded language, no hardcoded emoji.
    The categories are DISCOVERED from the cells: a cell that opens with a non-ASCII text element is
    read as carrying that marker, and the words after it are that marker's label. So the same script
    serves a round scored in any set of markers, in whatever language the papers are written in, and
    it cannot silently miscount because its idea of "green" drifted from the table's.

    A cell that opens with plain text carries no marker and is reported as UNCLASSIFIED, by row, never
    dropped: older columns in a long-running table hold bare prose like "niet gemeten", and a counter
    that quietly skipped them would produce a total that looks complete and is not. Same rule as the
    teardown's audit and the release notes -- a bounded count says what it bounded.

    Deliberately a MEASUREMENT, not a test suite -- hence .measure.ps1, so CI's *.tests.ps1 glob does
    not pick it up. It asserts nothing about whether a round SHOULD have four friction rows; it
    reports how many it has. Its own correctness is pinned by scripts/tests/round-tally.tests.ps1,
    which does run in CI.

    Read-only: it reads the file and writes nothing unless -OutFile is passed.

.PARAMETER Path
    The markdown file holding the step table(s) -- a round's RESULTATEN.md or OPDRACHT.md. Every
    qualifying table in the file is counted, and the totals are the sum across them: a step table
    split over several sections (before step 1, test A, test B) is one tally, which is how the papers
    already read it.

.PARAMETER ColumnPattern
    Regex identifying which header cells are round columns. Default '^v\d+$', matching v10, v11, ...
    Header cells that do not match are left alone, which is what keeps the label column, the class
    column and the issue column out of the count -- and what keeps unrelated tables in the same file
    from being counted at all.

.PARAMETER OutFile
    Write the block to this file as UTF-8 without BOM instead of to stdout.

    Not a convenience. On Windows PowerShell 5.1 a redirect (`> file`) re-encodes stdout in the
    console codepage, which turns discovered markers into mojibake in the very file a reader pastes
    from -- and this repo lints for exactly that. Pass -OutFile when the output is going anywhere
    other than a terminal you are only looking at.

.EXAMPLE
    # Count a round's papers and see the block
    ./scripts/tests/round-tally.measure.ps1 -Path C:\tmp\fixture\tests\v13\RESULTATEN.md

.EXAMPLE
    # Capture it for pasting, without codepage damage
    ./scripts/tests/round-tally.measure.ps1 -Path .\RESULTATEN.md -OutFile .\tally.md
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Path,
    [string]$ColumnPattern = '^v\d+$',
    [string]$OutFile = ''
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    Write-Error "No such file: '$Path'."
    exit 1
}

# Read as UTF-8 explicitly rather than via Get-Content: the markers are outside ASCII and the default
# reader on 5.1 would decode them in the console codepage.
$text  = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path, [System.Text.Encoding]::UTF8)
$lines = $text -split "`r?`n"

function Split-Row {
    <# Cells of a markdown table row, with the empty leading/trailing field dropped.

       Splitting on a bare '|' is enough for the tables this counts and would not be for markdown in
       general: a pipe inside a code span or an escaped pipe would split a cell in two. Stated rather
       than silently assumed -- if a round ever writes one, the unclassified list is where it shows
       up, as a cell whose text starts somewhere unexpected. #>
    param([string]$Line)
    $t = $Line.Trim()
    if ($t.StartsWith('|')) { $t = $t.Substring(1) }
    if ($t.EndsWith('|'))   { $t = $t.Substring(0, $t.Length - 1) }
    return @($t -split '\|' | ForEach-Object { $_.Trim() })
}

function Get-FirstTextElement {
    <# The first grapheme of a string, so a marker that is a surrogate pair (most emoji are) comes
       back whole instead of as half a character. #>
    param([string]$Value)
    if ([string]::IsNullOrEmpty($Value)) { return '' }
    $e = [System.Globalization.StringInfo]::GetTextElementEnumerator($Value)
    if ($e.MoveNext()) { return [string]$e.Current }
    return ''
}

function Test-IsMarker {
    param([string]$Element)
    if ([string]::IsNullOrEmpty($Element)) { return $false }
    # ASCII opens prose; anything else opens a marker. Deliberately this crude: the script must not
    # hold an opinion about WHICH symbols a round is allowed to score with.
    return ([int][char]$Element[0] -gt 127)
}

# --- find the tables -------------------------------------------------------------------------------
# A table is a run of consecutive '|' lines whose second line is a separator. Anything else that
# happens to start with '|' is not a table and is skipped without comment.
$tables = @()
$i = 0
while ($i -lt $lines.Count) {
    if ($lines[$i].Trim().StartsWith('|')) {
        $start = $i
        while ($i -lt $lines.Count -and $lines[$i].Trim().StartsWith('|')) { $i++ }
        $block = @($lines[$start..($i - 1)])
        if ($block.Count -ge 3 -and (($block[1] -replace '[\s\|:-]', '') -eq '')) {
            $tables += ,[pscustomobject]@{ Start = $start; Lines = $block }
        }
    } else { $i++ }
}

# --- count -----------------------------------------------------------------------------------------
$columns      = [ordered]@{}   # column name -> ordered map of marker -> count
$labels       = @{}            # marker -> hashtable of label -> times seen
$markerOrder  = @()
$unclassified = @()
$rowCount     = 0
$tablesUsed   = 0

foreach ($table in $tables) {
    $header  = Split-Row -Line $table.Lines[0]
    $roundAt = @()
    for ($c = 0; $c -lt $header.Count; $c++) {
        if ($header[$c] -match $ColumnPattern) { $roundAt += $c }
    }
    if ($roundAt.Count -eq 0) { continue }
    $tablesUsed++

    foreach ($c in $roundAt) {
        if (-not $columns.Contains($header[$c])) { $columns[$header[$c]] = [ordered]@{} }
    }

    foreach ($row in @($table.Lines[2..($table.Lines.Count - 1)])) {
        $cells = Split-Row -Line $row
        $rowCount++
        # The row's own name, for the unclassified report: whatever is in the first column, stripped
        # of the emphasis the papers put on the rows a round turned on.
        $rowLabel = if ($cells.Count -gt 0) { ($cells[0] -replace '\*', '').Trim() } else { '' }

        foreach ($c in $roundAt) {
            $cell = if ($c -lt $cells.Count) { $cells[$c] } else { '' }
            $name = $header[$c]
            # Emphasis is stripped before the cell is read, and this is not cosmetic: the papers bold
            # exactly the cells a round turned around, so a counter that took '**' as the opening
            # character would push every row the round is ABOUT into the unclassified list -- the four
            # that mattered most in v13. The raw cell is kept for the report.
            $bare  = ($cell -replace '^[\*_\s]+', '' -replace '[\*_\s]+$', '')
            $first = Get-FirstTextElement -Value $bare
            if (-not (Test-IsMarker -Element $first)) {
                $unclassified += ,[pscustomobject]@{ Column = $name; Row = $rowLabel; Cell = $cell }
                continue
            }
            if ($markerOrder -notcontains $first) { $markerOrder += $first }
            if (-not $columns[$name].Contains($first)) { $columns[$name][$first] = 0 }
            $columns[$name][$first] = $columns[$name][$first] + 1

            # The label is the table's own word for this marker, minus a qualifier in parentheses:
            # "groen" and "groen (tekst)" are one category scored with one marker, and the papers
            # total them together.
            $label = ($bare.Substring($first.Length).Trim() -replace '\s*\(.*\)\s*$', '').Trim()
            if ($label) {
                if (-not $labels.ContainsKey($first)) { $labels[$first] = @{} }
                if (-not $labels[$first].ContainsKey($label)) { $labels[$first][$label] = 0 }
                $labels[$first][$label] = $labels[$first][$label] + 1
            }
        }
    }
}

if ($tablesUsed -eq 0) {
    Write-Error "No table in '$Path' has a header cell matching '$ColumnPattern' -- nothing to count. Pass -ColumnPattern if this round names its columns differently."
    exit 1
}

# --- report ----------------------------------------------------------------------------------------
$warnings = @()
if ($unclassified.Count -gt 0) {
    $byCol = @($unclassified | Group-Object Column | Sort-Object Name)
    $warnings += ("$($unclassified.Count) cell(s) carry no marker and are counted in NO category: " +
                  (($byCol | ForEach-Object { "$($_.Name) $($_.Count)" }) -join ', ') +
                  '. They are listed under the table so the total says what it left out.')
}
foreach ($m in $markerOrder) {
    if ($labels.ContainsKey($m) -and $labels[$m].Keys.Count -gt 1) {
        $warnings += ("marker '$m' is used with more than one label (" + (($labels[$m].Keys | Sort-Object) -join ', ') +
                      ') -- the most frequent one heads its column, but check that they really are one category.')
    }
}
foreach ($w in $warnings) { Write-Warning $w }

function Get-MarkerHeading {
    param([string]$Marker)
    if (-not $labels.ContainsKey($Marker)) { return $Marker }
    $best = @($labels[$Marker].GetEnumerator() | Sort-Object -Property @{E = { $_.Value }; Descending = $true }, Name)[0]
    return "$Marker $($best.Key)"
}

$stamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$out   = @()
$out += "<!-- generated by scripts/tests/round-tally.measure.ps1 on $stamp -- regenerate, do not retype -->"
$out += ''
$out += ("Counted over $tablesUsed table(s) and $rowCount row(s) in ``$(Split-Path -Leaf $Path)``, " +
         "on the header cells matching ``$ColumnPattern``.")
$out += ''
$out += ('| column | ' + (@($markerOrder | ForEach-Object { Get-MarkerHeading -Marker $_ }) -join ' | ') + ' | counted | rows |')
$out += ('|---|' + ('---|' * ($markerOrder.Count + 2)))
foreach ($name in $columns.Keys) {
    $cells   = @($markerOrder | ForEach-Object { if ($columns[$name].Contains($_)) { "$($columns[$name][$_])" } else { '0' } })
    $counted = 0
    foreach ($m in $markerOrder) { if ($columns[$name].Contains($m)) { $counted += $columns[$name][$m] } }
    $out += ("| **$name** | " + ($cells -join ' | ') + " | $counted | $rowCount |")
}

if ($unclassified.Count -gt 0) {
    $out += ''
    $out += "Not counted in any category above -- $($unclassified.Count) cell(s) that open with plain text rather than a marker:"
    $out += ''
    $out += '| column | row | cell |'
    $out += '|---|---|---|'
    foreach ($u in $unclassified) {
        $shown = if ($u.Cell) { $u.Cell } else { '*(empty)*' }
        $out += "| $($u.Column) | $($u.Row) | $shown |"
    }
}

if ($OutFile) {
    [System.IO.File]::WriteAllText($OutFile, (($out -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding $false))
    Write-Host "Written: $OutFile" -ForegroundColor Green
} else {
    foreach ($line in $out) { Write-Output $line }
}

exit 0
