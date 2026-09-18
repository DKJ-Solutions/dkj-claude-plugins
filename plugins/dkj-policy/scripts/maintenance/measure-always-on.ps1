<#
.SYNOPSIS
    Measures the ALWAYS-ON DOCUMENT PATH -- CLAUDE.md plus everything it '@'-imports -- per document and
    per section, so the figure stops being hand-produced.

.DESCRIPTION
    WHY IT EXISTS. This path is paid by every session before a single assignment is given, and until this
    script the number came from `wc -c` typed by hand. It had been produced that way four times (July 28,
    August 14, August 15 and August 24, 2026) and the performance lens records the consequence three
    separate times in its own words: A MEASUREMENT IN A DOCUMENT THAT NOTHING REGENERATES GOES STALE
    SILENTLY. It did, in the worst available way -- the conversion factor was inherited unexamined at
    3.70 through three re-measurements and was ~19% too generous, so every derived token figure was
    under-stated while looking precise.

    WHAT IT REFUSES TO DO. It reaches no verdict about what should go. That boundary is the outcome of
    issue #861: a skill that would have judged an instruction document block by block was argued down and
    the verdict accepted, because the judgement is one already-written sentence -- the decision belongs on
    the always-on path, the evidence for it does not -- while a portable skill would have put always-on
    cost into three consumer repos that do not share this repo's condition. What was missing was never the
    judgement. It was the measurement, and this is that.

    SO IT IS NOT A GATE, AND MUST NOT BECOME ONE. It always exits 0. The two things it can find that ARE
    defects rather than measurements -- an import that does not resolve, and sections that fail to sum to
    their file -- are printed loudly and adjudicated by nobody here. The verdict on a dead import belongs
    to the lint gate, and since check 28 it has one -- for a target IN THE TREE (issue #874). A target in
    the marketplace clone stays outside that gate's reach, because CI is a machine with no clone, so this
    script remains the only place such an import is reported at all. The sum check is an assertion about
    this script's own arithmetic, and it failing means the report is wrong, not the repo.

    THE ONE DISTINCTION THE OUTPUT MUST CARRY. Bytes are a MEASUREMENT. Tokens are an ESTIMATE at a
    calibrated factor, because no API prices a document -- `measure-skill` owns the authoritative figure
    for the subject the count_tokens API does price, and its standing rule is "do not estimate from file
    sizes". That rule is about that subject. Here an estimate is the only answer available, so the honest
    move is to label it, every time, in the output itself rather than in a docstring nobody reads at 2am.

.PARAMETER RepoRoot
    The repo to measure. Defaults to the git root of the working directory.

.PARAMETER Root
    The root document of the path. Defaults to CLAUDE.md in the repo root.

.PARAMETER Depth
    The deepest heading level that still opens a section of its own (1-6, default 3). Both useful
    readings of this repo happened at different depths: reading shallow found that one section was 80% of
    CLAUDE.md, reading deep found that one sub-item of a two-item list was 56% of it.

.PARAMETER Top
    How many sections to list per document (default 8). 0 lists all of them.

.PARAMETER Documents
    Skip the section breakdown and print only the per-document table.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/maintenance/measure-always-on.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/maintenance/measure-always-on.ps1 -Depth 4 -Top 0
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$Root,
    [ValidateRange(1, 6)][int]$Depth = 3,
    [ValidateRange(0, 500)][int]$Top = 8,
    [switch]$Documents
)

$ErrorActionPreference = 'Stop'

# WHERE THE REPO ROOT COMES FROM (issue #2115). $PSScriptRoot-relative, so it resolves in the plugin
# mirror as well as here, and loaded BEFORE the block below because that block is what reads it.
. (Join-Path $PSScriptRoot '..\lib\repo-root-lib.ps1')

if (-not $RepoRoot) {
    # DUAL-CONTEXT, because this script is mirrored into the plugin: in a consumer the harness sets
    # CLAUDE_PROJECT_DIR and the mirror runs from the plugin cache, where a git root would be either
    # absent or the wrong repository. In the source repo nothing sets it and the git root is right.
    #
    # NO '2>$null' HERE, and the repo-wide guard in shared-scripts.tests.ps1 is what caught the first
    # draft writing one. Redirecting a native command's stderr into the PowerShell stream wraps each
    # line in a NativeCommandError, which is TERMINATING under EAP=Stop even when git exits 0 -- so the
    # redirect meant to silence a failure would instead have killed the script on a warning. A
    # try/catch is the exonerated form: outside a repository git errors, the catch leaves $RepoRoot
    # empty, and the throw below says something a reader can act on.
    #
    # Invoke-NativeCapture is the house helper for the CAPTURE and is still not used here: it lives
    # beside this script and the dot-source below runs after this line. The READ, though, is now one
    # definition (issue #2115) and is loaded above precisely so it can be -- `rev-parse --show-toplevel`
    # returns a raw path that Windows PowerShell 5.1 decodes with [Console]::OutputEncoding, so in a
    # consumer whose checkout sits under an accented directory name this resolved a root that the
    # GetFullPath below turned into a path pointing at nothing.
    if ($env:CLAUDE_PROJECT_DIR) { $RepoRoot = $env:CLAUDE_PROJECT_DIR }
    else { $RepoRoot = (Get-GitTopLevelPath).Path }
}
if (-not $RepoRoot) { throw 'Not inside a git repository, and -RepoRoot was not given.' }
$RepoRoot = [System.IO.Path]::GetFullPath($RepoRoot.Trim())

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before.
#
# ADDED LATE, AND THE REASON IS WORTH KEEPING (August 26, 2026, issue #897). This script joined the
# shared registry on August 25 without the guard, and scripts/README.md meanwhile claimed every shared
# entry point but two carried it -- both of those SessionStart hooks, exempt because a refusal there
# would fail every session start. This one is no hook: its skill page prints
# '${CLAUDE_PLUGIN_ROOT}/scripts/maintenance/measure-always-on.ps1' and then says to run the local copy
# instead, which is exactly the situation the guard exists to enforce rather than to request. Nothing
# detected the omission because the guard's suite tested whether the guard DECIDES correctly and never
# whether it is CALLED; it now asserts coverage off the registry.
#
# It matters most here, of all scripts. A stale copy of a MEASUREMENT tool does not fail -- it reports,
# and this file's own docstring is a record of what a plausible wrong number costs: the chars-per-token
# factor was inherited unexamined through three hand measurements and was ~19% too generous, so every
# derived figure was under-stated while looking precise.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# $PSScriptRoot-relative, NOT $RepoRoot-relative, and that is the whole difference between a script
# that travels and one that does not. The lib is mirrored beside this script into the plugin; the
# repo being MEASURED is a consumer's, which has no scripts/lib of its own.
. (Join-Path $PSScriptRoot '..\lib\measure-context-lib.ps1')

if (-not $Root) { $Root = Join-Path $RepoRoot 'CLAUDE.md' }
if (-not (Test-Path -LiteralPath $Root -PathType Leaf)) {
    throw "Root document not found: $Root"
}

$factor = Get-CalibratedCharsPerToken
$docs = @(Get-AlwaysOnDocuments -RootDocument $Root -RepoRoot $RepoRoot)

# Padding is applied to the INVARIANTLY formatted string, never by a culture-aware ':N0' inside the
# format specifier -- see the note in the lib for what the culture-aware version printed.
function Format-Bytes { param([int64]$B) return (Format-MeasuredBytes $B).PadLeft(9) }
function Format-Tokens { param([int64]$B) return (Format-MeasuredBytes (ConvertTo-EstimatedTokens -Bytes $B -CharsPerToken $factor.Value)).PadLeft(8) }
function Format-Share { param($Pct) return (Format-MeasuredShare $Pct).PadLeft(5) }

Write-Host ''
Write-Host 'The always-on document path' -ForegroundColor Cyan
Write-Host ("  root : {0}" -f ($Root.Replace($RepoRoot, '.') -replace '\\', '/')) -ForegroundColor DarkGray
Write-Host ("  repo : {0}" -f $RepoRoot) -ForegroundColor DarkGray
Write-Host ''

# ---------------------------------------------------------------- the documents

$present = @($docs | Where-Object { $_.Exists })
$missing = @($docs | Where-Object { -not $_.Exists })
$total = ($present | Measure-Object -Property Bytes -Sum).Sum
if (-not $total) { $total = 0 }

Write-Host '  hop        bytes   ~tokens   share  document' -ForegroundColor DarkGray
foreach ($d in $docs) {
    if (-not $d.Exists) {
        Write-Host ("  {0,3}  {1}  {2}          MISSING  {3}" -f $d.Hop, (Format-Bytes 0), ('{0,8}' -f '-'), $d.Display) -ForegroundColor Red
        continue
    }
    $share = 0
    if ($total -gt 0) { $share = 100 * $d.Bytes / $total }
    $colour = 'Gray'
    if ($d.Source -eq 'external') { $colour = 'Yellow' }
    Write-Host ("  {0,3}  {1}  {2}  {3}%  {4}" -f $d.Hop, (Format-Bytes $d.Bytes), (Format-Tokens $d.Bytes), (Format-Share $share), $d.Display) -ForegroundColor $colour
}
Write-Host ('  ---  {0}  {1}' -f (Format-Bytes $total), (Format-Tokens $total)) -ForegroundColor DarkGray
Write-Host ("       {0} document(s) on the path" -f $present.Count) -ForegroundColor DarkGray
Write-Host ''

# --------------------------------------------------- provenance, stated up front

Write-Host '  The byte column is a MEASUREMENT of the working copy on disk. The token column is an ESTIMATE.' -ForegroundColor DarkGray
$fx = Format-MeasuredNumber -Value $factor.Value -Format '{0:0.00}'
Write-Host ("    factor {0} chars/token, calibrated {1} -- {2}" -f $fx, $factor.Calibrated, $factor.Basis) -ForegroundColor DarkGray
Write-Host ("    n={0}, min {1}, median {2}, max {3}. {4}" -f `
    $factor.SampleSize,
    (Format-MeasuredNumber -Value $factor.Min -Format '{0:0.00}'),
    (Format-MeasuredNumber -Value $factor.Median -Format '{0:0.00}'),
    (Format-MeasuredNumber -Value $factor.Max -Format '{0:0.00}'),
    $factor.Caveat) -ForegroundColor DarkGray
Write-Host '    This omits the plugin listings, which ARE API-priced -- run measure-skill for those.' -ForegroundColor DarkGray
Write-Host ''

# ------------------------------------------- the unit of the byte column: CRLF vs LF

# Bytes above are the working copy on disk -- correct, it is what the session loads. But on a CRLF
# checkout (Windows, core.autocrlf, a consumer with no .gitattributes pinning eol=lf) that is one byte
# per line above the LF form the repository stores, and a series that mixes a fresh-checkout baseline
# with an editor-rewritten reading is off by exactly that. Named, not smoothed away -- inbound #1162.
$crlf = @($docs | Where-Object { $_.Exists -and $_.CrlfLines -gt 0 })
if ($crlf.Count -gt 0) {
    Write-Host '  The byte column is the working copy AS IT SITS ON DISK -- and it is CRLF here' -ForegroundColor Cyan
    foreach ($d in $crlf) {
        Write-Host ("    {0}" -f $d.Display) -ForegroundColor Yellow
        Write-Host ("      {0} B on disk, {1} B stored LF -- {2} CRLF line-ends, {2} B over" -f `
            (Format-MeasuredBytes $d.Bytes), (Format-MeasuredBytes $d.LfBytes), (Format-MeasuredBytes $d.CrlfLines)) -ForegroundColor Yellow
    }
    if ($crlf.Count -gt 1) {
        $crlfDisk = ($crlf | Measure-Object -Property Bytes -Sum).Sum
        $crlfLf = ($crlf | Measure-Object -Property LfBytes -Sum).Sum
        Write-Host ('      across those {0}: {1} B on disk, {2} B stored LF' -f `
            $crlf.Count, (Format-MeasuredBytes $crlfDisk), (Format-MeasuredBytes $crlfLf)) -ForegroundColor DarkGray
    }
    Write-Host '    Reading the working copy is CORRECT -- it is the copy the session loads. But the' -ForegroundColor DarkGray
    Write-Host '    repository stores LF, so compare like with like: a fresh-checkout baseline is CRLF, an' -ForegroundColor DarkGray
    Write-Host '    editor-rewritten file is often LF, and mixing the two overstates a step by one byte per' -ForegroundColor DarkGray
    Write-Host '    line. The LF column above is the number the next reader will compare against.' -ForegroundColor DarkGray
    Write-Host ''
}

# ------------------------------------------- the copy that loads, and what is queued

$external = @($docs | Where-Object { $_.Exists -and $_.Source -eq 'external' })
if ($external.Count -gt 0) {
    Write-Host '  The copy that LOADS is not always the copy in the tree' -ForegroundColor Cyan
    foreach ($d in $external) {
        Write-Host ("    {0}" -f $d.Display) -ForegroundColor Yellow
        Write-Host ("      imported by {0} as '{1}'" -f (($d.ImportedBy.Replace($RepoRoot, '.')) -replace '\\', '/'), $d.Target) -ForegroundColor DarkGray
        if ($null -eq $d.TreeBytes) {
            Write-Host '      no counterpart in this tree, so nothing is queued.' -ForegroundColor DarkGray
            continue
        }
        $delta = $d.TreeBytes - $d.Bytes
        if ($delta -eq 0) {
            Write-Host ('      tree copy is identical in size ({0} B) -- nothing queued.' -f (Format-MeasuredBytes $d.TreeBytes)) -ForegroundColor DarkGray
        } else {
            $verb = 'arriving at'
            if ($delta -lt 0) { $verb = 'released at' }
            $absDelta = [int64][math]::Abs($delta)
            $deltaTokens = ConvertTo-EstimatedTokens -Bytes $absDelta -CharsPerToken $factor.Value
            $line = '      loaded {0} B, tree {1} B -- {2} B (~{3} tokens) {4} the next plugin update.'
            Write-Host ($line -f (Format-MeasuredBytes $d.Bytes), (Format-MeasuredBytes $d.TreeBytes), `
                (Format-MeasuredBytes $absDelta), (Format-MeasuredBytes $deltaTokens), $verb) -ForegroundColor Yellow
        }
    }
    Write-Host '    This difference is queued cost, not error to smooth away: the session reads the' -ForegroundColor DarkGray
    Write-Host '    last PUSHED plugin, and the clone advances on a marketplace update, not on a push.' -ForegroundColor DarkGray
    Write-Host ''
}

if ($missing.Count -gt 0) {
    Write-Host '  An import on this path does not resolve' -ForegroundColor Red
    foreach ($d in $missing) {
        Write-Host ("    '{0}' imported by {1}" -f $d.Target, (($d.ImportedBy.Replace($RepoRoot, '.')) -replace '\\', '/')) -ForegroundColor Red
        Write-Host ("      resolved to: {0}" -f ($d.Path -replace '\\', '/')) -ForegroundColor DarkGray
    }
    Write-Host '    A dead @-import costs the session the WHOLE document, and nothing errors. The lint' -ForegroundColor DarkGray
    Write-Host '    gate refuses one whose target is IN THE TREE (check 28, issue #874). A target in the' -ForegroundColor DarkGray
    Write-Host '    marketplace clone is outside its reach -- CI has no clone -- so for that one this line' -ForegroundColor DarkGray
    Write-Host '    is the only report there is. Either way this script adjudicates nothing.' -ForegroundColor DarkGray
    Write-Host ''
}

if ($Documents) { exit 0 }

# ---------------------------------------------------------------- the sections

Write-Host ("  Where the mass sits, per document (headings to level {0})" -f $Depth) -ForegroundColor Cyan
foreach ($d in ($present | Sort-Object -Property Bytes -Descending)) {
    Write-Host ''
    $docTokens = ConvertTo-EstimatedTokens -Bytes $d.Bytes -CharsPerToken $factor.Value
    Write-Host ("  {0}  --  {1} B, ~{2} tokens" -f $d.Display, (Format-MeasuredBytes $d.Bytes), (Format-MeasuredBytes $docTokens)) -ForegroundColor White

    $sections = @(Get-DocumentSections -Path $d.Path -MaxLevel $Depth)
    $sum = ($sections | Measure-Object -Property Bytes -Sum).Sum
    if ($sum -ne $d.Bytes) {
        # An assertion about this script's own arithmetic, not about the repo. The sections tile the file
        # by construction, so a mismatch means the split is wrong and every share below it is wrong with
        # it -- which is worse than no table, the same reasoning measure-skill uses for its parse check.
        Write-Host ("    [ERROR] sections sum to {0} B, file is {1} B -- the split is wrong, so no table is printed." -f (Format-MeasuredBytes $sum), (Format-MeasuredBytes $d.Bytes)) -ForegroundColor Red
        continue
    }

    $ranked = @($sections | Sort-Object -Property Bytes -Descending)
    $shown = $ranked
    if ($Top -gt 0 -and $ranked.Count -gt $Top) { $shown = @($ranked[0..($Top - 1)]) }

    foreach ($s in $shown) {
        $share = 100 * $s.Bytes / $d.Bytes
        $indent = '  ' * [math]::Max(0, $s.Level - 1)
        Write-Host ("    {0}  {1}%  L{2}:{3,-5} {4}{5}" -f (Format-Bytes $s.Bytes), (Format-Share $share), $s.Level, $s.Line, $indent, $s.Heading)
    }
    if ($shown.Count -lt $ranked.Count) {
        $rest = $ranked.Count - $shown.Count
        $restBytes = ($ranked[$shown.Count..($ranked.Count - 1)] | Measure-Object -Property Bytes -Sum).Sum
        # Named rather than silently dropped: a truncated table reads as "this is everything".
        Write-Host ("    {0}  {1}%  and {2} smaller section(s) not listed -- raise -Top to see them." -f (Format-Bytes $restBytes), (Format-Share (100 * $restBytes / $d.Bytes)), $rest) -ForegroundColor DarkGray
    }
}

Write-Host ''
Write-Host '  This report reaches no verdict about what should move. That is the point: what recurs is' -ForegroundColor DarkGray
Write-Host '  noticing the path has grown and finding where the mass sits. The rule for what may then' -ForegroundColor DarkGray
Write-Host '  move is one sentence, and it is already written: the decision belongs on the always-on' -ForegroundColor DarkGray
Write-Host '  path, the evidence for it does not.' -ForegroundColor DarkGray
Write-Host ''

exit 0
