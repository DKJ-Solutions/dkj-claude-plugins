<#
.SYNOPSIS
    Measures the CLOSE-OUT against its stated ceiling, across every recorded session on this machine --
    so the sixth repair to Chris's step 6 can be evaluated instead of guessed at (inbound #2048).

.DESCRIPTION
    WHY IT EXISTS, AND IT IS NOT THE REASON THE REPORT GAVE. The close-out rule has now been repaired
    five times and lost five times:

        #849   August 24, 2026    the three permitted shapes (A done / B one decision / C parked)
        --     August 27, 2026    "THE CLOSE-OUT IS A RECEIPT, NOT THE REPORT"
        #1402  September 4, 2026  the filing line bounded to a number and at most a short clause
        #1408  September 4, 2026  the order: duplication filters first, then a ceiling of 2-3 lines
        #1884  September 11, 2026 the mechanism: closeout-lib.ps1 prints the shape at the chain's end
        #2043  September 17, 2026 the print hands over a fillable template instead of describing one

    Every one of those correctly diagnosed the PREVIOUS failure and did not prevent the next, and #2048
    asks why. The answer this script exists to supply is that NONE OF THEM WAS EVER MEASURED. Each was
    evaluated by waiting to see whether Dave complained again -- a sample of one, arriving weeks later,
    from whichever repo he happened to be in. A repair judged that way cannot be told from a repair that
    did nothing, and five rounds of exactly that is the pattern #2048 identified as "itself the finding".

    WHAT IT MEASURES, AND THE TWO POPULATIONS IT REFUSES TO CONFLATE. A transcript's last assistant
    message is not automatically a close-out: most sessions end wherever the person walked away, in the
    middle of an explanation or a question, and holding those to a receipt's ceiling would manufacture a
    violation rate out of nothing. So two populations are reported and never added together:

        ALL    every session's final assistant message. CONTEXT ONLY.
        CHAIN  the final assistant message AFTER the session's last chain-ending script -- the five
               named by Get-ChainEndingScripts in closeout-lib.ps1, read from there rather than
               restated here (issue #2060). That IS a close-out: it is exactly the set where
               Write-CloseOutReceipt prints its template, so it is the set the ceiling governs and
               the only set any verdict may be read off.

    WHAT IT FOUND ON THE DAY IT WAS WRITTEN (September 17, 2026; 10 project directories, 328 sessions,
    263 of them in the governed population):

        over the 3-line ceiling  222 / 263   84%
        over 6 lines             146 / 263   56%
        median / mean / p90 / max lines      7 / 8.5 / 16 / 76

    AND THOSE FIGURES WERE COMPUTED THROUGH A FILTER THAT WAS WRONG IN BOTH DIRECTIONS (issue #2060,
    the same day). The five were hand-typed in this file: it named park-cycle.ps1, which prints no receipt,
    and omitted park-branch.ps1, which prints one. RE-MEASURED over one frozen snapshot of this machine's
    corpus, old filter against new, the population did not move at all -- n=252 both -- and one session's
    close-out anchor did: over-ceiling 193 -> 192 (77% -> 76%), over-six 120 -> 119. The reason it is that
    small is worth keeping, because it is the opposite of what the report predicted: park-cycle reaches a
    transcript almost never, since the cycle-autopark Stop hook runs it rather than a tool call, and every
    park-branch session in this corpus had already run another chain ender. So the defect was real, the
    baseline it produced is very nearly the baseline it should have produced, and NOTHING HERE RE-STATES
    THE COMMITTED BASELINE ON ITS ACCOUNT -- the figures above stand as the day's record.

    SO THE RULE HAS NEVER BEEN IN FORCE. Five complaints are five of two hundred and twenty-two, which
    reframes every previous repair: they were not guardrails that kept slipping, they were advice
    against an 84% baseline that nobody had ever counted. That number is the finding, and producing it
    again after a change is the whole job of this file.

    AND IT SETTLES THE REPORT'S LEADING HYPOTHESIS, WHICH WAS THAT THE TRIGGER IS VOLUME OF WORK.
    Measured rather than argued: r(tool calls, close-out lines) = 0.207 over n=263. With that n it IS
    statistically significant, and it explains about 4% of the variance -- so the honest verdict is
    PARTIALLY TRUE AND NOT THE CAUSE. The quartile means say it plainest: the smallest quarter of
    sessions (9-58 tool calls) still averages 5.8 lines against a ceiling of 3. Removing the volume
    effect entirely would leave the rule broken. A repair aimed at "long sessions" would therefore have
    been the sixth correct diagnosis of the wrong thing, which is why this number is printed by default.

    IT IS A MEASUREMENT AND MUST NOT BECOME A GATE. It always exits 0, reads only, and reaches no
    verdict about any single close-out -- same boundary, and for the same reason, as measure-always-on.ps1
    beside it. The verdict on one close-out belongs to whatever mechanism is chosen next; what was
    missing was never the judgement, it was the number.

    THE TRANSCRIPTS IT READS ARE THIS MACHINE'S OWN, under ~/.claude/projects, and they are read
    in place and never written to. Nothing is copied out of them: only line counts, character counts and
    tool-call counts leave this script, which is what makes it safe to run in a repo whose measurements
    are published while the sessions they came from are private.

.PARAMETER TranscriptRoot
    Where the session transcripts live. Defaults to ~/.claude/projects.

.PARAMETER Ceiling
    The stated ceiling in non-empty lines. Defaults to 3 ("two or three lines", Chris's persona body).

.PARAMETER Project
    Limit to project directories whose name matches this wildcard. Default: all of them.

.PARAMETER UpdateBaseline
    Write the CHAIN population's headline figures to baselines/closeout-ceiling.json, so the next run
    after a repair prints the delta instead of a bare number. Off by default: a baseline overwritten by
    accident is how a regression becomes the new normal without anybody deciding it.

.PARAMETER BaselinePath
    Where -UpdateBaseline reads and writes. It has a correct default in BOTH copies and is an override
    rather than something a consumer has to remember: run from inside the repo being measured -- the
    repo this file is maintained in -- it is baselines/closeout-ceiling.json beside this script, which is
    where the committed baseline already sits. Run from the plugin mirror, where $PSScriptRoot is the
    version-scoped plugin cache that the next `claude plugin update` replaces, it is instead
    dkj-policy/baselines/closeout-ceiling.json in the consumer's own repo. Pass this to put it anywhere
    else; the parent directory is created if it does not exist.

.PARAMETER Json
    Emit the result as JSON on stdout instead of the human report, for a caller that wants the figures.
#>
[CmdletBinding()]
param(
    [string]$TranscriptRoot = (Join-Path $HOME '.claude\projects'),
    [int]$Ceiling = 3,
    [string]$Project = '*',
    [switch]$UpdateBaseline,
    [string]$BaselinePath = '',
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# THE NUMBERS ARE FORMATTED INVARIANT, AND THIS IS NOT COSMETIC. Every figure this script produces is
# meant to be QUOTED -- in an issue, in a changelog entry, in the header of the file it measures -- and
# on a Dutch-locale machine the default culture renders r as '0,207'. The same run on a US machine
# renders '0.207', so the same measurement arrives in two spellings and a reader comparing a fresh run
# with a quoted one cannot tell a locale from a regression. Measured here: the first run of this script
# printed '0,207' and '8,5'. ConvertTo-Json is already invariant, so without this the JSON and the
# console report of ONE run disagreed with each other.
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture

# THE SOURCE-REPO GUARD, carried for the same reason measure-always-on.ps1 beside it carries one, and
# it matters most on a MEASUREMENT. A stale copy of a gate fails loudly; a stale copy of an instrument
# reports -- it hands back a plausible number that nobody can tell from a fresh one. Every skill page
# prints '${CLAUDE_PLUGIN_ROOT}/scripts/...' because that is the only path a consumer can resolve, so in
# the repo this file is maintained in the command in front of you points at the last RELEASED mirror and
# lags this tree by however many merges have landed since. Assert-OwnCopy refuses exactly that case and
# is silent for a consumer, who holds no copy of their own and is therefore never refused.
#
# $PSScriptRoot-relative and guarded with Test-Path, like every other caller: the lib is mirrored beside
# this script into the plugin, and a tree that does not carry it degrades to the behaviour of the day
# before rather than throwing.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# THE CHAIN-ENDING SCRIPTS, READ FROM THE LIB RATHER THAN RESTATED (issue #2060). This was a hand-typed
# regex here, under a comment claiming it was "exactly the callers closeout-lib.ps1's own suite pins" --
# and it was wrong in BOTH directions: it named park-cycle.ps1, which the cycle-autopark Stop hook runs
# after every turn and which never prints a receipt, and it omitted park-branch.ps1, which prints two.
# So close-out shape C -- the parked blocker, and plausibly the longest shape there is -- was absent
# from the governed population while every ordinary turn was a candidate for it. The committed N=263
# baseline and every figure quoted from it in #2048 and #2050 were computed through that filter.
#
# The one definition is Get-ChainEndingScripts in closeout-lib.ps1, the file those callers themselves
# dot-source; that lib's own suite greps the tree and refuses to pass unless the callers it finds are
# exactly that list, so a sixth chain ender cannot be added without going red.
#
# $PSScriptRoot-relative and guarded with Test-Path, like every other caller: the lib is mirrored beside
# this script into the plugin, one folder over in both copies. THE CALL IS TRIED RATHER THAN PROBED FOR
# -- a bare-name Get-Command is the idiom #1729 retired tree-wide, and a try/catch answers the same
# question here without loading a second lib to ask it.
$chainEnders = @()
$closeoutLib = Join-Path $PSScriptRoot '..\lib\closeout-lib.ps1'
if (Test-Path -LiteralPath $closeoutLib -PathType Leaf) {
    . $closeoutLib
    try { $chainEnders = @(Get-ChainEndingScripts) } catch { $chainEnders = @() }
}

# AND A TREE THAT CANNOT ANSWER IS NOT MEASURED, which is the opposite of what every other guarded
# dot-source in this workflow does. Those degrade to the behaviour of the day before; an instrument
# cannot, because a plausible number computed over a population nobody could name is exactly the defect
# #2060 is about, and it is indistinguishable from a fresh one once quoted. Exit 0 all the same: this
# is a measurement and never a gate.
if ($chainEnders.Count -eq 0) {
    Write-Host "[SKIP] closeout-lib.ps1 does not answer Get-ChainEndingScripts here, so the population" -ForegroundColor Yellow
    Write-Host "       this script measures cannot be named. Nothing measured -- see issue #2060." -ForegroundColor Yellow
    exit 0
}

# A turn that ran one of these ended a work chain, so the assistant message after it is a close-out
# rather than whatever the session happened to be saying. Escaped and joined into the alternation the
# serialised tool input is searched with below.
$script:ChainEndingScripts = (@($chainEnders | ForEach-Object { [regex]::Escape($_) })) -join '|'

# THE REPO ROOT, RESOLVED DUAL-CONTEXT, and it exists for the baseline alone. Everything this script
# MEASURES comes from ~/.claude/projects, which is machine state and needs no repo -- but the baseline is
# a committed artefact, and where it lands is the one question that differs between the two copies.
# CLAUDE_PROJECT_DIR for a consumer (the mirror runs from the plugin cache, where a git root would be
# either wrong or absent), otherwise the git root. The try/catch is the exonerated form: outside a
# repository git errors and the catch leaves this null, which the baseline rule below tolerates.
$repoRoot = $null
if ($env:CLAUDE_PROJECT_DIR) { $repoRoot = $env:CLAUDE_PROJECT_DIR }
else { try { $repoRoot = (git rev-parse --show-toplevel) } catch { $repoRoot = $null } }
if ($repoRoot) { $repoRoot = [System.IO.Path]::GetFullPath($repoRoot.Trim()) }

# WHERE THE BASELINE LIVES, and the rule is one question: is this script INSIDE the repo being measured?
# In the repo this file is maintained in it is, and the baseline belongs beside it, committed, where it
# already sits. Run from the plugin mirror it is not -- $PSScriptRoot is then the version-scoped plugin
# cache, which the next `claude plugin update` replaces, so a baseline written there would be lost
# without anybody being told. That copy writes into the consumer's own workflow folder instead.
# An explicit -BaselinePath overrides both.
if ($BaselinePath) {
    $script:BaselinePath = [System.IO.Path]::GetFullPath($BaselinePath)
} elseif ($repoRoot -and -not $PSScriptRoot.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    $script:BaselinePath = Join-Path $repoRoot 'dkj-policy\baselines\closeout-ceiling.json'
} else {
    $script:BaselinePath = Join-Path $PSScriptRoot 'baselines\closeout-ceiling.json'
}

function Get-NonEmptyLineCount {
    <#
    .SYNOPSIS
        The line count the ceiling is stated in: non-empty lines, blank separators excluded.

    .DESCRIPTION
        BLANKS ARE EXCLUDED DELIBERATELY. The ceiling is about how much a person has to READ, and a
        close-out written as three one-line paragraphs is three lines to a reader and five to a naive
        split. Counting the blanks would let a sixth repair be declared a success by reformatting.
    #>
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return 0 }
    return @($Text -split "`r?`n" | Where-Object { $_.Trim() -ne '' }).Count
}

function Get-TranscriptRecords {
    <#
    .SYNOPSIS
        The parseable records of one .jsonl transcript, in order.

    .DESCRIPTION
        A LINE THAT DOES NOT PARSE IS SKIPPED RATHER THAN FATAL. These files are written by a harness
        this repo does not control, they are appended to while sessions run, and a half-written final
        line is ordinary rather than exceptional. A measurement that refuses the whole file over one
        such line would report a violation rate for whichever transcripts happened to be closed, which
        is a selection bias dressed as rigour.
    #>
    param([string]$Path)

    $out = New-Object System.Collections.Generic.List[object]
    $lines = @(Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue)
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try { $obj = $line | ConvertFrom-Json } catch { continue }
        if ($obj.PSObject.Properties.Name -contains 'type') { $out.Add($obj) }
    }
    return $out
}

function Get-AssistantTextAt {
    <#
    .SYNOPSIS
        The last assistant message carrying visible text, at or after $From -- or '' when there is none.

    .DESCRIPTION
        TEXT BLOCKS ONLY. A record's content also carries tool_use blocks and, depending on the harness
        version, thinking; neither is what the reader met, so neither is counted. Several text blocks in
        one message are joined, because that is one message on screen.
    #>
    param($Records, [int]$From)

    for ($i = $Records.Count - 1; $i -ge $From; $i--) {
        $rec = $Records[$i]
        if ($rec.type -ne 'assistant') { continue }
        if (-not $rec.message) { continue }
        if (-not ($rec.message.PSObject.Properties.Name -contains 'content')) { continue }
        if (-not $rec.message.content) { continue }
        $parts = @()
        foreach ($block in $rec.message.content) {
            if ($block.type -eq 'text' -and -not [string]::IsNullOrWhiteSpace($block.text)) { $parts += $block.text }
        }
        if ($parts.Count -gt 0) { return ($parts -join "`n") }
    }
    return ''
}

function Measure-OneTranscript {
    <#
    .SYNOPSIS
        One session's tool-call volume, its final message, and its close-out where it has one.
    #>
    param([string]$Path, [string]$ProjectName)

    # @(...) around the CALL is safe and necessary: the function's return enumerates its list into the
    # output stream, so what arrives here is object[], a single object, or $null -- and the last of those
    # would fail .Count under StrictMode. This is not the @()-around-a-List case guarded further down.
    $records = @(Get-TranscriptRecords -Path $Path)
    if ($records.Count -eq 0) { return $null }

    $tools = 0
    $lastChainIndex = -1
    for ($i = 0; $i -lt $records.Count; $i++) {
        $rec = $records[$i]
        if ($rec.type -ne 'assistant') { continue }
        if (-not $rec.message) { continue }
        if (-not ($rec.message.PSObject.Properties.Name -contains 'content')) { continue }
        if (-not $rec.message.content) { continue }
        foreach ($block in $rec.message.content) {
            if ($block.type -ne 'tool_use') { continue }
            $tools++
            # The invocation is matched on the SERIALISED input rather than on a single field: the same
            # script reaches a transcript as a Bash command line, as a PowerShell one, and inside a
            # skill's arguments, and a matcher pinned to one of those shapes would silently under-count
            # exactly the sessions that used the others.
            $serialised = ''
            try { $serialised = ($block.input | ConvertTo-Json -Depth 6 -Compress) } catch { $serialised = '' }
            if ($serialised -and $serialised -match $script:ChainEndingScripts) { $lastChainIndex = $i }
        }
    }

    $final = Get-AssistantTextAt -Records $records -From 0
    if ([string]::IsNullOrWhiteSpace($final)) { return $null }

    $closeOut = ''
    if ($lastChainIndex -ge 0) { $closeOut = Get-AssistantTextAt -Records $records -From $lastChainIndex }

    return [pscustomobject]@{
        Project       = $ProjectName
        Tools         = $tools
        FinalLines    = Get-NonEmptyLineCount -Text $final
        FinalChars    = $final.Length
        IsCloseOut    = (-not [string]::IsNullOrWhiteSpace($closeOut))
        CloseOutLines = if ($closeOut) { Get-NonEmptyLineCount -Text $closeOut } else { 0 }
        CloseOutChars = if ($closeOut) { $closeOut.Length } else { 0 }
    }
}

function Get-Pearson {
    <#
    .SYNOPSIS
        Pearson's r for two equal-length series -- 'n/a' below three points.

    .DESCRIPTION
        HAND-ROLLED because Windows PowerShell 5.1 ships no correlation cmdlet and this repo's scripts
        take no module dependency. A zero variance in either series returns 0 rather than dividing by
        it: a corpus where every close-out is the same length has no correlation to report, which is a
        fact about the corpus and not an error.
    #>
    param([double[]]$X, [double[]]$Y)

    $n = $X.Count
    if ($n -lt 3 -or $Y.Count -ne $n) { return 'n/a' }
    $mx = ($X | Measure-Object -Average).Average
    $my = ($Y | Measure-Object -Average).Average
    $num = 0.0; $dx = 0.0; $dy = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        $num += ($X[$i] - $mx) * ($Y[$i] - $my)
        $dx  += [math]::Pow($X[$i] - $mx, 2)
        $dy  += [math]::Pow($Y[$i] - $my, 2)
    }
    if ($dx -eq 0 -or $dy -eq 0) { return 0 }
    return [math]::Round($num / [math]::Sqrt($dx * $dy), 3)
}

function Get-Percentile {
    param([int[]]$Values, [double]$P)
    $sorted = @($Values | Sort-Object)
    if ($sorted.Count -eq 0) { return 0 }
    $idx = [int][math]::Floor($P * ($sorted.Count - 1))
    return $sorted[$idx]
}

function Get-PopulationStats {
    param($Rows, [string]$LineField, [string]$CharField)

    $n = @($Rows).Count
    if ($n -eq 0) { return $null }
    $lines = @($Rows | ForEach-Object { [int]$_.$LineField })
    $chars = @($Rows | ForEach-Object { [int]$_.$CharField })
    $tools = @($Rows | ForEach-Object { [int]$_.Tools })
    $over  = @($Rows | Where-Object { [int]$_.$LineField -gt $Ceiling }).Count
    $over6 = @($Rows | Where-Object { [int]$_.$LineField -gt 6 }).Count

    return [pscustomobject]@{
        N              = $n
        OverCeiling    = $over
        OverCeilingPct = [math]::Round(100 * $over / $n)
        OverSix        = $over6
        OverSixPct     = [math]::Round(100 * $over6 / $n)
        MedianLines    = Get-Percentile -Values $lines -P 0.5
        MeanLines      = [math]::Round(($lines | Measure-Object -Average).Average, 1)
        P90Lines       = Get-Percentile -Values $lines -P 0.9
        MaxLines       = ($lines | Measure-Object -Maximum).Maximum
        MeanChars      = [math]::Round(($chars | Measure-Object -Average).Average)
        RToolsLines    = Get-Pearson -X $tools -Y $lines
        RToolsChars    = Get-Pearson -X $tools -Y $chars
    }
}

# ---------------------------------------------------------------------------------------------------
# Collect
# ---------------------------------------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $TranscriptRoot -PathType Container)) {
    Write-Host "[SKIP] No transcript root at '$TranscriptRoot' -- nothing to measure." -ForegroundColor Yellow
    exit 0
}

$rows = New-Object System.Collections.Generic.List[object]
$unreadable = 0

foreach ($dir in Get-ChildItem -LiteralPath $TranscriptRoot -Directory -ErrorAction SilentlyContinue) {
    $projectName = $dir.Name -replace '^C--Users-[^-]+-Documents-GitHub-', ''
    if ($projectName -notlike $Project) { continue }
    foreach ($file in Get-ChildItem -LiteralPath $dir.FullName -Filter *.jsonl -ErrorAction SilentlyContinue) {
        try {
            $row = Measure-OneTranscript -Path $file.FullName -ProjectName $projectName
            if ($row) { $rows.Add($row) } else { $unreadable++ }
        } catch {
            $unreadable++
        }
    }
}

# .ToArray() RATHER THAN @($rows). Under Set-StrictMode -Version Latest on Windows PowerShell 5.1,
# wrapping a System.Collections.Generic.List[object] in @() throws ArgumentException ("argument types do
# not match") instead of copying it -- reproduced in isolation on this machine. The pipeline form two
# lines down is unaffected, because there the list is enumerated rather than converted, which is exactly
# why only one of these two lines ever failed.
$all   = $rows.ToArray()
$chain = @($rows | Where-Object { $_.IsCloseOut })

$allStats   = Get-PopulationStats -Rows $all   -LineField 'FinalLines'    -CharField 'FinalChars'
$chainStats = Get-PopulationStats -Rows $chain -LineField 'CloseOutLines' -CharField 'CloseOutChars'

# ---------------------------------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------------------------------

if ($Json) {
    [pscustomobject]@{
        MeasuredUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        Ceiling     = $Ceiling
        All         = $allStats
        CloseOuts   = $chainStats
    } | ConvertTo-Json -Depth 6
    exit 0
}

Write-Host ''
Write-Host "== close-out ceiling: $Ceiling non-empty lines ==" -ForegroundColor Cyan
Write-Host "   sessions read: $($all.Count)   with no assistant text: $unreadable" -ForegroundColor DarkGray

function Show-Stats {
    param([string]$Label, $Stats, [string]$Note)
    Write-Host ''
    Write-Host $Label -ForegroundColor Cyan
    if ($Note) { Write-Host "  $Note" -ForegroundColor DarkGray }
    if (-not $Stats) { Write-Host '  (nothing measured)' -ForegroundColor DarkGray; return }
    Write-Host ("  n                      : {0}" -f $Stats.N)
    Write-Host ("  over the ceiling       : {0} / {1}  ({2}%)" -f $Stats.OverCeiling, $Stats.N, $Stats.OverCeilingPct)
    Write-Host ("  over 6 lines           : {0} / {1}  ({2}%)" -f $Stats.OverSix, $Stats.N, $Stats.OverSixPct)
    Write-Host ("  lines median/mean/p90/max : {0} / {1} / {2} / {3}" -f $Stats.MedianLines, $Stats.MeanLines, $Stats.P90Lines, $Stats.MaxLines)
    Write-Host ("  mean characters        : {0}" -f $Stats.MeanChars)
    Write-Host ("  r(tool calls, lines)   : {0}   r(tool calls, chars): {1}" -f $Stats.RToolsLines, $Stats.RToolsChars)
}

Show-Stats -Label 'ALL final assistant messages' -Stats $allStats `
    -Note 'CONTEXT ONLY -- most of these are not close-outs and the ceiling does not govern them.'

Show-Stats -Label 'CLOSE-OUTS (after a chain-ending script)' -Stats $chainStats `
    -Note 'The governed population: exactly where Write-CloseOutReceipt prints its template.'

# THE QUARTILES ARE PRINTED BESIDE r BECAUSE r ALONE MISLEADS HERE. #2048's leading hypothesis was that
# the trigger is volume of work; a small-but-significant r would be read as confirming it. What answers
# the hypothesis is that the SMALLEST quartile is already over the ceiling -- so the effect is real and
# the cause is elsewhere, and only the quartile means show that at a glance.
if ($chain.Count -ge 8) {
    Write-Host ''
    Write-Host '  session size -> mean close-out lines (is the trigger volume of work?)' -ForegroundColor Cyan
    $byTools = @($chain | Sort-Object Tools)
    $q = [int]($byTools.Count / 4)
    for ($k = 1; $k -le 4; $k++) {
        $start = ($k - 1) * $q
        $len = if ($k -eq 4) { $byTools.Count - $start } else { $q }
        $slice = @($byTools[$start..($start + $len - 1)])
        $sliceTools = @($slice | ForEach-Object { [int]$_.Tools })
        $sliceLines = @($slice | ForEach-Object { [int]$_.CloseOutLines })
        Write-Host ("    Q{0}  tools {1,4}-{2,-5} n={3,-4} mean lines = {4}" -f $k,
            ($sliceTools | Measure-Object -Minimum).Minimum,
            ($sliceTools | Measure-Object -Maximum).Maximum,
            $slice.Count,
            [math]::Round(($sliceLines | Measure-Object -Average).Average, 1))
    }
}

if ($chain.Count -gt 0) {
    Write-Host ''
    Write-Host '  close-outs per project' -ForegroundColor Cyan
    foreach ($group in ($chain | Group-Object Project | Sort-Object Count -Descending)) {
        $g = @($group.Group)
        $gLines = @($g | ForEach-Object { [int]$_.CloseOutLines })
        $gOver = @($g | Where-Object { [int]$_.CloseOutLines -gt $Ceiling }).Count
        Write-Host ("    {0,-42} n={1,-5} median={2,-4} over={3}%" -f $group.Name, $g.Count,
            (Get-Percentile -Values $gLines -P 0.5), [math]::Round(100 * $gOver / $g.Count))
    }
}

# ---------------------------------------------------------------------------------------------------
# Baseline -- the whole point, since a repair judged against the next complaint is judged against n=1
# ---------------------------------------------------------------------------------------------------

Write-Host ''
if (Test-Path -LiteralPath $script:BaselinePath) {
    try {
        $base = Get-Content -LiteralPath $script:BaselinePath -Raw | ConvertFrom-Json
        if ($chainStats) {
            $deltaPct = $chainStats.OverCeilingPct - $base.OverCeilingPct
            $deltaMed = $chainStats.MedianLines - $base.MedianLines
            $sign = if ($deltaPct -gt 0) { '+' } else { '' }
            $signMed = if ($deltaMed -gt 0) { '+' } else { '' }
            Write-Host ("  vs baseline ({0}): over-ceiling {1}% -> {2}% ({3}{4}), median {5} -> {6} ({7}{8})" -f
                $base.MeasuredUtc, $base.OverCeilingPct, $chainStats.OverCeilingPct, $sign, $deltaPct,
                $base.MedianLines, $chainStats.MedianLines, $signMed, $deltaMed) -ForegroundColor Cyan
        }
    } catch {
        Write-Host '  (baseline present but unreadable -- ignored)' -ForegroundColor DarkGray
    }
} else {
    Write-Host '  No baseline recorded yet. Run with -UpdateBaseline to set one.' -ForegroundColor DarkGray
}

if ($UpdateBaseline -and $chainStats) {
    $dir = Split-Path -Parent $script:BaselinePath
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $payload = [pscustomobject]@{
        MeasuredUtc    = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        Ceiling        = $Ceiling
        N              = $chainStats.N
        OverCeiling    = $chainStats.OverCeiling
        OverCeilingPct = $chainStats.OverCeilingPct
        MedianLines    = $chainStats.MedianLines
        MeanLines      = $chainStats.MeanLines
        P90Lines       = $chainStats.P90Lines
        MeanChars      = $chainStats.MeanChars
        RToolsLines    = $chainStats.RToolsLines
    }
    $payload | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $script:BaselinePath -Encoding ascii
    Write-Host "  Baseline written: $script:BaselinePath" -ForegroundColor Green
}

Write-Host ''
# ALWAYS 0. See the header: this is a measurement, not a gate.
exit 0
