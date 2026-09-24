<#
.SYNOPSIS
    Guards the trusted-tree ship (issue #2437): no lib in ship-pr.ps1's or open-pr.ps1's dot-source
    closure reads a .ps1 off $repoRoot/$RepoRoot except through the one sanctioned seam ($seamRoot),
    and the wiring that makes -TrustedRoot/-SeamRoot mean what they say is present in both scripts.

.DESCRIPTION
    CONDITION (b) OF SEBASTIAN #23's DESIGN REVIEW ON #2437, MADE STRUCTURAL. Before this branch,
    ship-pr.ps1 and open-pr.ps1 dot-sourced two REPO-OWNED files -- scripts/repo-config.ps1 and
    scripts/lib/branch-info.ps1 -- from $repoRoot: the checked-out branch, unconditionally. That is
    exactly the exposure merge-on-green.yml's OLD single-checkout shape had (issue #2338): a runner
    executing branch PowerShell in a process carrying FOLD_PUSH_TOKEN. This branch repointed both
    dot-sources at a resolved $seamRoot (ship-pr.ps1's own -TrustedRoot, open-pr.ps1's own -SeamRoot;
    $repoRoot when neither is given, unchanged from before), so a THIRD such dot-source reappearing
    later -- via a copy-pasted lib, a hasty repair, a merge from a stale branch -- would silently
    reopen the same class of hole. This suite is what makes that reappearance loud instead of silent.

    THE CLOSURE IS DISCOVERED, NOT HAND-LISTED. Hand-enumerating "every lib ship-pr.ps1 loads" goes
    stale the moment a new one is added and nobody remembers to extend the list -- the exact failure
    mode this guard exists to prevent, one level up. So this walks the real dot-source graph: starting
    from ship-pr.ps1 and open-pr.ps1, it follows every `. (Join-Path $PSScriptRoot '...')` line
    (guarded or not) to the file it names, recursively, and scans the WHOLE resulting set. A future lib
    added to either script's dot-source list is picked up automatically; nothing here has to be told
    about it by name.

    WHAT COUNTS AS A HIT: a live (non-comment-only) line matching a dot-source of the form
    `. (Join-Path $repoRoot '...')` or `. (Join-Path $RepoRoot '...')`, case either way -- the exact
    shape both retired call sites used. `$seamRoot` is a different identifier, so the two rewritten
    call sites do not match and the assertion is that NOTHING ELSE in the closure does either.

    NOT A CLAIM ABOUT EVERY .ps1 IN THE REPO -- deliberately scoped to the closure ship-pr.ps1 and
    open-pr.ps1 actually dot-source. A script only ever run as a CHILD PROCESS (fold-changelog-entry.ps1,
    verify-resolved-issues.ps1) resolves its own root independently and is out of scope here; each of
    those already receives an explicit -RepoRoot/-Branch from its caller rather than inheriting one, and
    fold-changelog-entry.ps1's own -RepoRoot only ever names a tree already standing on 'main' (the
    in-place checkout, the throwaway worktree, or -TrustedRoot) -- never the PR branch -- which is a
    fact about ITS callers, verified there, not restated as a rule this suite enforces.

    Dependency-free (no Pester), same style as the rest of the suite. Pure ASCII.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$ShipPath = Join-Path $RepoRoot 'scripts\release\ship-pr.ps1'
$OpenPath = Join-Path $RepoRoot 'scripts\release\open-pr.ps1'

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}

Write-Host 'Discovering ship-pr.ps1 + open-pr.ps1''s dot-source closure' -ForegroundColor Cyan

# THE WALK. $PSScriptRoot resolves per-FILE (each script's own directory), so a discovered target is
# resolved relative to the file that named it, not to $RepoRoot or to this suite's own location.
function Get-DotSourceClosure {
    param([string[]]$Seeds)
    $visited = @{}
    $queue = New-Object System.Collections.Generic.Queue[string]
    foreach ($s in $Seeds) { $queue.Enqueue((Resolve-Path -LiteralPath $s).Path) }
    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        $key = $current.ToLowerInvariant()
        if ($visited.ContainsKey($key)) { continue }
        if (-not (Test-Path -LiteralPath $current -PathType Leaf)) { continue }
        $visited[$key] = $current
        $text = Get-Content -LiteralPath $current -Raw
        $dir = Split-Path -Parent $current
        foreach ($m in [regex]::Matches($text, "(?m)^\s*\.\s*\(Join-Path\s+\`$PSScriptRoot\s+'([^']+)'\)")) {
            $target = Join-Path $dir $m.Groups[1].Value
            try { $resolved = (Resolve-Path -LiteralPath $target -ErrorAction Stop).Path } catch { continue }
            if (-not $visited.ContainsKey($resolved.ToLowerInvariant())) { $queue.Enqueue($resolved) }
        }
    }
    return @($visited.Values)
}

$closure = @(Get-DotSourceClosure -Seeds @($ShipPath, $OpenPath))
# A FLOOR, NOT A CEILING (issue #1145's own lesson on brittle counts applied here): this asserts the
# walk actually found something rather than silently scanning zero files -- a regex that stopped
# matching would make every assertion below vacuously true. 20 is comfortably under the 25 measured
# when this suite was written (September 24, 2026); a repo that trims dependencies is not a failure
# here, a walk that finds almost nothing is.
Assert-True ($closure.Count -ge 20) "the closure discovery found a plausible number of files ($($closure.Count))"
Assert-True (@($closure | Where-Object { $_ -ieq $ShipPath }).Count -gt 0) 'ship-pr.ps1 is in its own closure'
Assert-True (@($closure | Where-Object { $_ -ieq $OpenPath }).Count -gt 0) 'open-pr.ps1 is in its own closure'

Write-Host ''
Write-Host 'No file in the closure dot-sources via $repoRoot/$RepoRoot -- only via $seamRoot' -ForegroundColor Cyan

# THE FORBIDDEN SHAPE: a dot-source Join-Path'd off $repoRoot or $RepoRoot, either case, anywhere in
# the closure. The two sanctioned call sites use a DIFFERENT identifier ($seamRoot), so this is not an
# allowlist of exact lines to skip -- it is a flat "zero occurrences" assertion, which is what makes a
# THIRD such line, added anywhere in the closure without anyone touching this suite, fail loudly.
$forbidden = '\.\s*\(Join-Path\s+\$(repoRoot|RepoRoot)\b'
$hits = @()
foreach ($file in $closure) {
    $text = Get-Content -LiteralPath $file -Raw
    foreach ($m in [regex]::Matches($text, $forbidden)) {
        $lineNo = ($text.Substring(0, $m.Index) -split "`n").Count
        $hits += "$(Get-Item -LiteralPath $file | ForEach-Object { $_.Name }):$lineNo"
    }
}
Assert-True ($hits.Count -eq 0) 'no dot-source anywhere in the closure loads a .ps1 off $repoRoot/$RepoRoot directly'
if ($hits.Count -gt 0) {
    foreach ($h in $hits) { Write-Host "         found: $h" -ForegroundColor Red }
}

Write-Host ''
Write-Host 'The sanctioned seam -- $seamRoot repoints exactly the two repo-owned files' -ForegroundColor Cyan

$shipRaw = Get-Content -LiteralPath $ShipPath -Raw
$openRaw = Get-Content -LiteralPath $OpenPath -Raw

Assert-True ($shipRaw -match '\$seamRoot\s*=\s*if\s*\(\$TrustedRoot\)') `
    'ship-pr.ps1 derives $seamRoot from -TrustedRoot (falling back to $repoRoot)'
Assert-True ($shipRaw -match "Join-Path\s+\`$seamRoot\s+'scripts\\repo-config\.ps1'") `
    'ship-pr.ps1 dot-sources scripts\repo-config.ps1 via $seamRoot, not $repoRoot'
Assert-True ($openRaw -match '\$seamRoot\s*=\s*if\s*\(\$SeamRoot\)') `
    'open-pr.ps1 derives $seamRoot from -SeamRoot (falling back to $repoRoot)'
Assert-True ($openRaw -match "Join-Path\s+\`$seamRoot\s+'scripts\\repo-config\.ps1'") `
    'open-pr.ps1 dot-sources scripts\repo-config.ps1 via $seamRoot'
Assert-True ($openRaw -match "Join-Path\s+\`$seamRoot\s+'scripts\\lib\\branch-info\.ps1'") `
    'open-pr.ps1 dot-sources scripts\lib\branch-info.ps1 via $seamRoot'

Write-Host ''
Write-Host '-TrustedRoot/-SeamRoot structurally force -SkipLint/-SkipTests (condition (c))' -ForegroundColor Cyan

Assert-True ($shipRaw -match '(?s)if\s*\(\$TrustedRoot\)\s*\{.*?\$SkipLint\s*=\s*\$true.*?\$SkipTests\s*=\s*\$true') `
    'ship-pr.ps1 forces both skips when -TrustedRoot is set'
Assert-True ($openRaw -match '(?s)if\s*\(\$SeamRoot\)\s*\{.*?\$SkipLint\s*=\s*\$true.*?\$SkipTests\s*=\s*\$true') `
    'open-pr.ps1 forces both skips when -SeamRoot is set'
# THIS RUNS BEFORE EITHER GATE CALL SITE, textually -- a forcing block placed after a gate call would
# compile but arrive too late to matter. An ACTUAL invocation (`Invoke-WorkflowGates -RepoRoot`), not
# merely the function's name in prose -- both scripts' own docstrings mention it by name well before
# either the param block or the forcing logic, which a bare IndexOf('Invoke-WorkflowGates') would catch.
$shipForceIdx = $shipRaw.IndexOf('if ($TrustedRoot) {')
Assert-True ($shipForceIdx -ge 0 -and $shipRaw -notmatch 'Invoke-WorkflowGates\s+-RepoRoot') `
    'ship-pr.ps1 forces the skips (it calls Invoke-WorkflowGates nowhere itself -- only open-pr.ps1 does)'
$openGateMatch = [regex]::Match($openRaw, 'Invoke-WorkflowGates\s+-RepoRoot')
$openForceIdx = $openRaw.IndexOf('if ($SeamRoot) {')
Assert-True ($openForceIdx -ge 0 -and $openGateMatch.Success -and $openForceIdx -lt $openGateMatch.Index) `
    'open-pr.ps1 forces the skips before its first actual Invoke-WorkflowGates call'

Write-Host ''
Write-Host 'ship-pr.ps1 forwards -TrustedRoot to open-pr.ps1 as -SeamRoot' -ForegroundColor Cyan

Assert-True ($shipRaw -match "if\s*\(\`$TrustedRoot\)\s*\{\s*\`$openArgs\s*\+=\s*@\('-SeamRoot',\s*\`$TrustedRoot\)") `
    'the child open-pr.ps1 invocation receives -SeamRoot $TrustedRoot when -TrustedRoot is set'

Write-Host ''
Write-Host 'The fold, in trusted-tree mode, uses $TrustedRoot directly -- never a new worktree' -ForegroundColor Cyan

Assert-True ($shipRaw -match '(?s)if\s*\(\$TrustedRoot\)\s*\{\s*\$trustedResolved') `
    'the fold step has a -TrustedRoot arm that resolves the caller''s tree'
# THE WORKTREE-CREATING LINE MUST SIT STRICTLY AFTER THE -TrustedRoot ARM'S OWN CLOSING BRACE, i.e.
# inside the "else" that only runs when -TrustedRoot was NOT given -- not merely present somewhere in
# the file, which a textual match alone cannot rule out.
$wtAddIdx = $shipRaw.IndexOf("'worktree', 'add', `$foldTree, 'main'")
$trustedArmIdx = $shipRaw.IndexOf('if ($TrustedRoot) {')
Assert-True ($wtAddIdx -gt 0 -and $trustedArmIdx -gt 0 -and $wtAddIdx -gt $trustedArmIdx) `
    'git worktree add is textually reachable only past the -TrustedRoot short-circuit'
Assert-True ($shipRaw -match 'function Remove-ShipFoldWorktree[\s\S]{0,600}\[switch\]\$NotOwned') `
    'Remove-ShipFoldWorktree accepts -NotOwned, so a run never removes a tree it did not create'
Assert-True ($shipRaw -match '\$foldTreeIsOwned\s*=\s*\$true') `
    'only the worktree-creating arm marks $foldTree as owned by this run'
$notOwnedCallCount = @([regex]::Matches($shipRaw, 'Remove-ShipFoldWorktree\s+-Path\s+\$foldTree\s+-NotOwned:')).Count
Assert-True ($notOwnedCallCount -ge 4) "every Remove-ShipFoldWorktree call site passes -NotOwned ($notOwnedCallCount found)"

Write-Host ''
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
