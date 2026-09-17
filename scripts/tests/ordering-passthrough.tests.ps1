<#
.SYNOPSIS
    Tests for issue #2044 -- a narrating child process's output must not be able to arrive AFTER
    everything its parent printed.

.DESCRIPTION
    THE DEFECT, IN ONE SENTENCE. A child started with `& powershell -File ...` writes its narration to ITS
    stdout, which PowerShell hands to the PARENT SCRIPT'S SUCCESS STREAM -- the script's return value --
    while everything the parent says itself goes to the information stream via Write-Host. Those two reach
    one console in the printed order only for as long as nobody touches the success stream. Pipe the
    parent, capture it into a variable, or Tee it, and the information stream still prints live while the
    success stream is collected and replayed at the END.

    WHAT THAT LOOKS LIKE, AND WHY IT WAS HARD TO READ AS A BUG. The result is not scrambled -- it is
    every line the parent printed, in file order, followed by every line all of its children printed, in
    file order. Well-formed, plausible, and wrong. Measured on a consumer shipping PR #683: ship-pr's
    closing receipt -- deliberately the last statement in that file -- appeared ABOVE `PR created for ...`
    from the child spawned hundreds of lines earlier, and step 6's child had the last word on screen.

    WHY IT IS WORTH A SUITE RATHER THAN A COMMENT. The cost is not the ordering itself but that PLACEMENT
    STOPS BEING A MECHANISM: anything this workflow prints where it will be read last is only last for an
    unpiped caller. That reasoning is invisible at the call site, so the one-token `| Out-Host` that
    carries it is exactly the kind of thing a later tidy-up removes as noise.

    TWO HALVES, AND THE FIRST IS WHAT MAKES THE SECOND MEAN ANYTHING.

      - THE BEHAVIOURAL HALF proves the mechanism is real against a fixture: the same two-child parent is
        run in both shapes, and the leaky one is asserted to REORDER while the fixed one is asserted to
        hold. A guard whose defect cannot be demonstrated is a guard nobody can safely delete, and an
        assert that would pass on the broken code too is worse than none.
      - THE STRUCTURAL HALF asserts every narrating spawn in scripts/release/ actually carries the fix,
        in BOTH the source and the plugin mirror. That is what would catch the sixth site somebody adds
        next year -- the failure mode the issue itself had, which reported one script while three carried
        the same defect.

    $LASTEXITCODE IS ASSERTED ACROSS THE PIPE, because that is the one thing the fix could plausibly have
    broken: every call site reads it on the very next line to decide whether to carry on.

    Dependency-free (no Pester), same style as the rest of the suite.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

$script:pass = 0
$script:fail = 0

function Assert-Equal {
    param($Expected, $Actual, [string]$Label)
    if ("$Expected" -eq "$Actual") { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}
function Assert-True {
    param([bool]$Condition, [string]$Label)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label" -ForegroundColor Red }
}

# --- the fixture ---------------------------------------------------------------------------------
# A parent that narrates around TWO children, which is the smallest shape that tells the two orderings
# apart: with one child, "parent then child" and "correct" differ only in the trailing lines, and a
# single child's output could plausibly be flushed late for reasons that are nobody's defect.
$fixtureDir = Join-Path ([System.IO.Path]::GetTempPath()) ("ordering-passthrough-$PID-" + [guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Path $fixtureDir -Force | Out-Null

try {
    $childPath = Join-Path $fixtureDir 'child.ps1'
    Set-Content -LiteralPath $childPath -Encoding utf8 -Value @'
param([string]$Tag, [int]$Code = 0)
Write-Host "CHILD-$Tag-1"
Write-Warning "CHILD-$Tag-W"
Write-Host "CHILD-$Tag-2"
exit $Code
'@

    # THE TWO PARENTS DIFFER IN EXACTLY ONE TOKEN, deliberately -- `| Out-Host`. Anything else that
    # differed would leave the comparison below arguing about two programs rather than about the fix.
    $leakyBody = @'
Write-Host "PARENT-1"
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'child.ps1') -Tag A -Code 0{0}
Write-Host "PARENT-2 exit=$LASTEXITCODE"
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'child.ps1') -Tag B -Code 7{0}
Write-Host "PARENT-3 exit=$LASTEXITCODE"
Write-Host "PARENT-4-RECEIPT"
'@
    $leakyPath = Join-Path $fixtureDir 'parent-leaky.ps1'
    $fixedPath = Join-Path $fixtureDir 'parent-fixed.ps1'
    Set-Content -LiteralPath $leakyPath -Encoding utf8 -Value ($leakyBody -f '')
    Set-Content -LiteralPath $fixedPath -Encoding utf8 -Value ($leakyBody -f ' | Out-Host')

    # Run a fixture parent THROUGH A PIPE -- the shape that exposes the split. Tee-Object is used rather
    # than a bare capture because it is the least contrived of the three: a caller logging a run while
    # watching it is an ordinary thing to do, not a test-only construction.
    function Invoke-PipedFixture {
        param([string]$Path)
        $runner = @"
`$ErrorActionPreference = 'Continue'
& '$Path' | Tee-Object -Variable collected | Out-Null
foreach (`$line in `$collected) { Write-Host "COLLECTED: `$line" }
"@
        $runnerPath = Join-Path $fixtureDir ("run-" + [guid]::NewGuid().ToString('n') + ".ps1")
        Set-Content -LiteralPath $runnerPath -Encoding utf8 -Value $runner
        # 2>&1 is safe HERE (unlike at the call sites this suite guards) because nothing downstream reads
        # $? or $LASTEXITCODE from this call -- the assertions read the text.
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $runnerPath 2>&1
        Remove-Item -LiteralPath $runnerPath -Force -ErrorAction SilentlyContinue
        return @($out | ForEach-Object { "$_" })
    }

    function Get-LineIndex {
        param([string[]]$Lines, [string]$Needle)
        for ($i = 0; $i -lt $Lines.Count; $i++) { if ($Lines[$i] -match [regex]::Escape($Needle)) { return $i } }
        return -1
    }

    # --- the behavioural half: the defect is real ------------------------------------------------
    Write-Host ''
    Write-Host 'The leaky shape REORDERS under a pipe (the defect #2044 reported)' -ForegroundColor Cyan

    $leaky = Invoke-PipedFixture -Path $leakyPath
    $leakReceipt = Get-LineIndex -Lines $leaky -Needle 'PARENT-4-RECEIPT'
    $leakChildA1 = Get-LineIndex -Lines $leaky -Needle 'CHILD-A-1'
    $leakChildB2 = Get-LineIndex -Lines $leaky -Needle 'CHILD-B-2'

    Assert-True ($leakReceipt -ge 0) 'the leaky parent printed its receipt at all'
    Assert-True ($leakChildA1 -ge 0) 'the leaky parent relayed the first child at all'
    # THE FINDING ITSELF: the parent's LAST line lands above the first child's FIRST line.
    Assert-True ($leakReceipt -lt $leakChildA1) "the parent's closing receipt lands ABOVE the first child's first line"
    Assert-True ($leakReceipt -lt $leakChildB2) "...and above the last child's last line, so the receipt is not last"
    # And the child's warning travels with the child's Write-Host rather than with the parent's output --
    # the fact the issue used to rule out the obvious stdout-vs-stderr explanation.
    $leakChildAW = Get-LineIndex -Lines $leaky -Needle 'CHILD-A-W'
    Assert-True ($leakChildAW -gt $leakChildA1 -and $leakChildAW -lt $leakChildB2) "the child's warning travels with the child's own output, not with the parent's"

    # --- the behavioural half: the fix holds -----------------------------------------------------
    Write-Host ''
    Write-Host 'Out-Host restores the printed order under the same pipe' -ForegroundColor Cyan

    $fixed = Invoke-PipedFixture -Path $fixedPath
    $order = @('PARENT-1', 'CHILD-A-1', 'CHILD-A-W', 'CHILD-A-2', 'PARENT-2', 'CHILD-B-1', 'CHILD-B-W', 'CHILD-B-2', 'PARENT-3', 'PARENT-4-RECEIPT')
    $indices = @($order | ForEach-Object { Get-LineIndex -Lines $fixed -Needle $_ })

    for ($i = 0; $i -lt $order.Count; $i++) {
        Assert-True ($indices[$i] -ge 0) "the fixed parent printed '$($order[$i])'"
    }
    $ascending = $true
    for ($i = 1; $i -lt $indices.Count; $i++) { if ($indices[$i] -le $indices[$i - 1]) { $ascending = $false } }
    Assert-True $ascending 'every line appears in the order the two scripts print it -- parent and children interleaved'
    Assert-True ((Get-LineIndex -Lines $fixed -Needle 'PARENT-4-RECEIPT') -eq ($indices | Measure-Object -Maximum).Maximum) 'the closing receipt is the LAST of the fixture lines, which is what placement depends on'

    # NOTHING IS LEFT IN THE SUCCESS STREAM. This is the half that says the fix is right rather than
    # merely effective: a child's console narration was never the parent's return value, and the
    # collected pipe is now empty.
    Assert-True (-not ($fixed | Where-Object { $_ -match '^COLLECTED: ' })) 'the fixed parent returns nothing down the pipe -- its success stream is empty'
    Assert-True ([bool]($leaky | Where-Object { $_ -match '^COLLECTED: ' })) '...whereas the leaky parent returned its children down the pipe (the premise of the assert above)'

    # --- $LASTEXITCODE across the pipe -----------------------------------------------------------
    Write-Host ''
    Write-Host 'The pipe does not cost the exit code every call site reads on the next line' -ForegroundColor Cyan

    Assert-True ([bool]($fixed | Where-Object { $_ -match 'PARENT-2 exit=0' })) 'a child exiting 0 is still reported as 0 through Out-Host'
    Assert-True ([bool]($fixed | Where-Object { $_ -match 'PARENT-3 exit=7' })) 'a child exiting 7 is still reported as 7 through Out-Host'
}
finally {
    Remove-Item -LiteralPath $fixtureDir -Recurse -Force -ErrorAction SilentlyContinue
}

# --- the structural half -------------------------------------------------------------------------
# WHY THIS EXISTS. #2044 reported ship-pr.ps1; the same defect was sitting in cut-release.ps1 and
# verify-pushed-merges.ps1, found only because the repair went looking. A behavioural test on a fixture
# can never catch the next site, so this one reads the real scripts.
Write-Host ''
Write-Host 'Every narrating child spawn in scripts/release/ routes to the host' -ForegroundColor Cyan

$releaseRoots = @(
    @{ Label = 'source'; Path = (Join-Path $RepoRoot 'scripts\release') },
    @{ Label = 'plugin mirror'; Path = (Join-Path $RepoRoot 'plugins\dkj-policy\scripts\release') }
)

foreach ($root in $releaseRoots) {
    Assert-True (Test-Path -LiteralPath $root.Path) "the $($root.Label) release folder exists"
    if (-not (Test-Path -LiteralPath $root.Path)) { continue }

    $offenders = @()
    $guarded   = 0
    foreach ($file in Get-ChildItem -LiteralPath $root.Path -Filter '*.ps1' -File) {
        $lineNo = 0
        foreach ($line in (Get-Content -LiteralPath $file.FullName)) {
            $lineNo++
            # Executable spawns only. A comment describing `& powershell` is prose, and this repo's
            # scripts carry several -- counting those would make the check unfixable.
            if ($line -match '^\s*#') { continue }
            if ($line -notmatch '&\s*powershell') { continue }
            # A DELIBERATE CAPTURE IS NOT A LEAK. `$out = & powershell ...` wants the child's output as a
            # value and is the documented shape for a gate that inspects what its child said; the defect
            # is narration falling into the success stream by accident, which is the UNASSIGNED form.
            if ($line -match '^\s*(\[[^\]]+\])?\s*\$[\w:]+\s*=') { continue }
            if ($line -match '\|\s*Out-Host') { $guarded++; continue }
            # Piped into something that renders it is equally fine -- check-connectors' filter-then-
            # Write-Host shape is the existing precedent in this tree.
            if ($line -match '\|\s*(Where-Object|ForEach-Object|Select-String|Tee-Object|Out-Null)') { $guarded++; continue }
            $offenders += "$($file.Name):$lineNo"
        }
    }

    Assert-True ($offenders.Count -eq 0) "no unrouted '& powershell' narration in the $($root.Label) release scripts$(if ($offenders.Count) { ' -- ' + ($offenders -join ', ') })"
    # The guard must be measuring something. If a refactor moved every spawn out of this folder, the
    # assert above would pass vacuously and stop protecting anything.
    Assert-True ($guarded -ge 5) "the $($root.Label) scan actually found the routed spawns it is guarding (found $guarded, expect at least 5)"
}

# --- the two copies agree --------------------------------------------------------------------------
# The drift lint covers this repo-wide; asserted here too because a fix applied to one copy and not the
# other is the specific way THIS change could rot, and the failure would be silent in a consumer.
Write-Host ''
Write-Host 'The source and the plugin mirror carry the same repair' -ForegroundColor Cyan
foreach ($name in @('ship-pr.ps1', 'cut-release.ps1', 'verify-pushed-merges.ps1')) {
    $a = Join-Path $RepoRoot "scripts\release\$name"
    $b = Join-Path $RepoRoot "plugins\dkj-policy\scripts\release\$name"
    if ((Test-Path -LiteralPath $a) -and (Test-Path -LiteralPath $b)) {
        $ca = (Get-Content -LiteralPath $a -Raw)
        $cb = (Get-Content -LiteralPath $b -Raw)
        Assert-Equal $ca.Length $cb.Length "$name is byte-identical in both copies"
        Assert-True (([regex]::Matches($ca, '\|\s*Out-Host')).Count -eq ([regex]::Matches($cb, '\|\s*Out-Host')).Count) "$name carries the same number of host-routed spawns in both copies"
    } else {
        Assert-True $false "$name exists in both the source and the plugin mirror"
    }
}

Write-Host ''
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
