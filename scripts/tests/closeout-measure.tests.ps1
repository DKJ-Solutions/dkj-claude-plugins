<#
.SYNOPSIS
    Tests for scripts/maintenance/measure-closeouts.ps1 -- the close-out ceiling instrument (#2048).

.DESCRIPTION
    WHAT THIS SUITE IS PROTECTING. The script's whole value is that a number it produces can be QUOTED
    and then re-produced after a change. Two things would destroy that silently:

      1. THE TWO POPULATIONS DRIFTING INTO ONE. 'the last message of every session' and 'the close-out
         after a chain-ending script' differ by ~65 sessions in the real corpus, and every one of those
         is a message the ceiling was never about. A refactor that quietly counted the wrong set would
         raise the violation rate and look like a finding. So the fixture below contains one session of
         each kind and the asserts pin which population each lands in.
      2. THE FORMATTING GOING CULTURE-DEPENDENT. The first run of this script on this machine printed
         'r = 0,207'. A figure that renders differently per machine cannot be compared with a quoted
         one, so the invariant-culture line is asserted in the source rather than trusted.

    THE FIXTURE IS SYNTHETIC AND SELF-CONTAINED. It builds its own transcript root in the temp area and
    never reads ~/.claude/projects -- a suite whose numbers came from the machine's real sessions would
    change every day and assert nothing. It is removed in a finally, including when an assert throws.

    IT ASSERTS THE SCRIPT ALWAYS EXITS 0, which is the doctrine boundary it shares with
    measure-always-on.ps1: this is a measurement and must never become a gate. A future change that
    made it exit non-zero on a bad reading would put a verdict about one close-out into a script whose
    header says it reaches none.

    Dependency-free (no Pester), same style as the rest of the suite.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$ScriptPath = Join-Path $RepoRoot 'scripts\maintenance\measure-closeouts.ps1'

$script:pass = 0
$script:fail = 0

function Assert-Equal {
    param($Expected, $Actual, [string]$Label)
    if ("$Expected" -eq "$Actual") { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}

function Assert-True {
    param($Condition, [string]$Label)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label" -ForegroundColor Red }
}

Write-Host ''
Write-Host 'The script is present and shaped as a measurement' -ForegroundColor Cyan

Assert-True (Test-Path -LiteralPath $ScriptPath) 'measure-closeouts.ps1 exists'
$src = Get-Content -LiteralPath $ScriptPath -Raw

Assert-True (-not ($src -cmatch '[^\x00-\x7F]')) 'measure-closeouts.ps1 is pure ASCII'
Assert-True ($src -match 'InvariantCulture') 'it pins the number formatting to the invariant culture'
Assert-True ($src -match '(?m)^exit 0\s*$') 'it ends on an unconditional exit 0'
# The doctrine, asserted as text because it is the boundary a later change would cross without noticing.
Assert-True ($src -match 'measurement, not a gate') 'it states the measurement-not-a-gate boundary'

# ---------------------------------------------------------------------------------------------------
# A synthetic transcript root
# ---------------------------------------------------------------------------------------------------

function New-Record {
    <#
    .SYNOPSIS
        One assistant record carrying either text blocks or one tool_use, as a single JSONL line.
    #>
    param([string[]]$Text, [string]$ToolCommand)

    $blocks = @()
    if ($ToolCommand) {
        $blocks += @{ type = 'tool_use'; name = 'Bash'; input = @{ command = $ToolCommand } }
    }
    foreach ($t in $Text) { $blocks += @{ type = 'text'; text = $t } }
    return (@{ type = 'assistant'; message = @{ content = $blocks } } | ConvertTo-Json -Depth 8 -Compress)
}

$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("closeout-measure-" + [guid]::NewGuid().ToString('N'))

try {
    $projA = Join-Path $fixtureRoot 'C--Users-Someone-Documents-GitHub-org-alpha'
    $projB = Join-Path $fixtureRoot 'C--Users-Someone-Documents-GitHub-org-beta'
    New-Item -ItemType Directory -Path $projA -Force | Out-Null
    New-Item -ItemType Directory -Path $projB -Force | Out-Null

    # SESSION 1 -- a chain ended, and the close-out runs five non-empty lines (over the ceiling of 3).
    # The blank line in the middle is deliberate: the ceiling counts what a reader reads, so a close-out
    # written as paragraphs must not be able to buy headroom by adding separators.
    @(
        (New-Record -Text @('Working on it.'))
        (New-Record -ToolCommand 'powershell -File scripts/release/ship-pr.ps1')
        (New-Record -Text @("one`ntwo`n`nthree`nfour`nfive"))
    ) | Set-Content -LiteralPath (Join-Path $projA 'aaaa1111.jsonl') -Encoding ascii

    # SESSION 2 -- no chain-ending script anywhere. It belongs to ALL and must NOT reach the close-out
    # population, however short or long its final message is. This is the assert that keeps the two
    # populations apart.
    @(
        (New-Record -ToolCommand 'git status')
        (New-Record -Text @("just an answer`nsecond line"))
    ) | Set-Content -LiteralPath (Join-Path $projA 'aaaa2222.jsonl') -Encoding ascii

    # SESSION 3 -- a chain ended and the close-out obeys the ceiling. Without a compliant one in the
    # fixture the over-ceiling percentage would be 100 whatever the code did.
    @(
        (New-Record -ToolCommand 'powershell -File scripts/release/open-pr.ps1')
        (New-Record -Text @("Done: PR #12 shipped -- see PR #12. Session can be cleared."))
    ) | Set-Content -LiteralPath (Join-Path $projB 'bbbb3333.jsonl') -Encoding ascii

    # SESSION 4 -- a half-written line and no assistant text at all. Must be skipped without failing the
    # run: these files are appended to while sessions are live, so a truncated last line is ordinary.
    @(
        '{"type":"user","message":{"content":"hello"}}'
        '{"type":"assistant","message":{"content":[{"type":"tex'
    ) | Set-Content -LiteralPath (Join-Path $projB 'bbbb4444.jsonl') -Encoding ascii

    Write-Host ''
    Write-Host 'It separates the two populations' -ForegroundColor Cyan

    $json = & $ScriptPath -TranscriptRoot $fixtureRoot -Json
    Assert-Equal 0 $LASTEXITCODE 'the run exits 0'

    $result = ($json | Out-String) | ConvertFrom-Json

    Assert-Equal 3 $result.All.N              'ALL counts the three sessions that have assistant text'
    Assert-Equal 2 $result.CloseOuts.N        'CLOSE-OUTS counts only the two that ran a chain-ending script'
    Assert-Equal 1 $result.CloseOuts.OverCeiling 'one of the two close-outs is over the ceiling'
    Assert-Equal 50 $result.CloseOuts.OverCeilingPct 'so the violation rate is 50%'

    # Five non-empty lines out of six physical ones -- the blank is not counted.
    Assert-Equal 5 $result.CloseOuts.MaxLines 'the blank separator line is not counted towards the ceiling'

    Write-Host ''
    Write-Host 'The ceiling is a parameter, not a constant' -ForegroundColor Cyan

    $loose = (& $ScriptPath -TranscriptRoot $fixtureRoot -Ceiling 5 -Json | Out-String) | ConvertFrom-Json
    Assert-Equal 0 $loose.CloseOuts.OverCeiling 'at a ceiling of 5 nothing in the fixture is over it'

    Write-Host ''
    Write-Host 'The project filter selects a subset' -ForegroundColor Cyan

    $onlyBeta = (& $ScriptPath -TranscriptRoot $fixtureRoot -Project 'org-beta' -Json | Out-String) | ConvertFrom-Json
    Assert-Equal 1 $onlyBeta.CloseOuts.N 'one close-out in org-beta'
    Assert-Equal 0 $onlyBeta.CloseOuts.OverCeiling '...and it is within the ceiling'

    Write-Host ''
    Write-Host 'A missing transcript root is reported, not fatal' -ForegroundColor Cyan

    $absent = Join-Path $fixtureRoot 'does-not-exist'
    # *>&1, NOT 2>&1. The [SKIP] notice is a Write-Host, which since PowerShell 5 goes to the
    # INFORMATION stream rather than to stdout or stderr -- so 2>&1 captures nothing and the assert
    # below failed against a line that was plainly on screen.
    $out = & $ScriptPath -TranscriptRoot $absent *>&1
    Assert-Equal 0 $LASTEXITCODE 'a missing root still exits 0'
    Assert-True (($out | Out-String) -match '\[SKIP\]') '...and says so rather than reporting a rate of nothing'

    Write-Host ''
    Write-Host 'The baseline: an explicit path is honoured, and the committed one is left alone' -ForegroundColor Cyan

    # -BaselinePath is asserted by RUNNING it rather than by reading the source, because what would break
    # is the write landing somewhere else -- and the somewhere else it would land is this repo's own
    # committed baseline. A suite that overwrote that file would BE the regression it is here to catch,
    # so the untouched-timestamp assert below is part of the subject and not politeness.
    $blPath          = Join-Path $fixtureRoot 'baseline\closeout-ceiling.json'
    $committed       = Join-Path $RepoRoot 'scripts\maintenance\baselines\closeout-ceiling.json'
    $committedBefore = if (Test-Path -LiteralPath $committed) { (Get-Item -LiteralPath $committed).LastWriteTimeUtc } else { '(absent)' }

    & $ScriptPath -TranscriptRoot $fixtureRoot -UpdateBaseline -BaselinePath $blPath *>&1 | Out-Null
    Assert-Equal 0 $LASTEXITCODE '-UpdateBaseline with an explicit -BaselinePath still exits 0'
    Assert-True (Test-Path -LiteralPath $blPath) '...and the baseline lands where it was told, parent directory created'

    $committedAfter = if (Test-Path -LiteralPath $committed) { (Get-Item -LiteralPath $committed).LastWriteTimeUtc } else { '(absent)' }
    Assert-Equal "$committedBefore" "$committedAfter" "...and this repo's committed baseline was not touched"

    Write-Host ''
    Write-Host 'The two copies disagree about WHERE the baseline lives, on purpose' -ForegroundColor Cyan

    $src = Get-Content -LiteralPath $ScriptPath -Raw

    # THE ONE CLASS A BYTE-IDENTICAL MIRROR CAN STILL GET WRONG (#2051). Both copies run this same line;
    # $PSScriptRoot is what differs. In the repo this file is maintained in it sits inside the repo and the
    # baseline belongs beside the script, where the committed one already is. In the plugin mirror it is the
    # version-scoped plugin cache, which the next `claude plugin update` replaces -- so a baseline written
    # there is lost without anybody being told. Pinned in the SOURCE because the mirror is held byte-identical
    # to it by check 8, and a run from a real plugin cache cannot be staged from here.
    Assert-True ($src -match 'repoRoot .dkj-policy.baselines.closeout-ceiling') 'the mirror copy writes its baseline into the consumer repo, not into the plugin cache'
    Assert-True ($src -match '\$env:CLAUDE_PROJECT_DIR') '...resolved dual-context, which is what makes that answer right in a consumer'

    # The guard matters MORE on an instrument than on a gate: a stale gate fails loudly, a stale measurement
    # hands back a plausible number nobody can tell from a fresh one.
    Assert-True ($src -match 'Assert-OwnCopy') 'the source-repo guard is carried, so a stale mirror run in the source repo is refused rather than reporting'
}
finally {
    if (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ''
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
