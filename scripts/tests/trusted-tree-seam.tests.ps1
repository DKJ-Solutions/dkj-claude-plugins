<#
.SYNOPSIS
    Guards the trusted-tree ship (issue #2437): no lib in ship-pr.ps1's or open-pr.ps1's dot-source
    closure reads a .ps1 off $repoRoot/$RepoRoot except through the one sanctioned seam ($seamRoot),
    and the wiring that makes -TrustedRoot/-SeamRoot mean what they say is present in both scripts.
    And (issue #2452) no file the token-bearing process runs, child scripts included, turns a string
    into code outside a named allowance.

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

    THE WALK ALSO FOLLOWS THE GUARDED, TWO-STEP IDIOM (code review finding): `ship-pr.ps1` and
    `open-pr.ps1` both dot-source `source-repo-guard-lib.ps1` as

        $guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
        if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy ... }

    which is TWO lines, not one -- an assignment, then a dot-source of the VARIABLE. The original
    single-regex walk (`. (Join-Path $PSScriptRoot '...')`) never matches the second line, so
    `source-repo-guard-lib.ps1` -- and everything IT dot-sources the same way (11 more files, measured
    against this tree: `git-identity-lib.ps1`, `claim-issue-lib.ps1`, `closeout-lib.ps1` and its own
    closure, `always-on-budget-lib.ps1`, `run-progress-lib.ps1`, `branch-info.ps1`) -- was never added
    to `$closure` at all, so the forbidden-pattern scan below never read a byte of it. PROVEN rather
    than assumed: a line `. (Join-Path $repoRoot 'scripts\evil-payload.ps1')` planted inside
    `source-repo-guard-lib.ps1` left the ORIGINAL (single-pattern) version of this suite fully green,
    because the file carrying it was never discovered. The regression case near the end of this file
    reproduces that proof against a throwaway fixture (never against the real file) and pins that the
    CURRENT walker catches it.

    HOW THE VARIABLE FORM IS RESOLVED: for each file, every `$var = Join-Path $PSScriptRoot '...'`
    assignment is collected first (line-anchored, so a `#`-comment mentioning the same shape is never
    mistaken for code -- the same reason the literal-form regex below is line-anchored too). A later
    `. $var` (bare, or wrapped in `if (...) { ... }`) is then resolved through that table. Two more
    tables are collected the same way and read for the OPPOSITE reason: `$var = Join-Path $repoRoot
    '...'` (or `$RepoRoot`) marks `. $var` as the exact forbidden shape the section below refuses, just
    reached through a variable instead of an inline call; `$var = Join-Path $seamRoot '...'` marks it as
    the SANCTIONED seam (ship-pr.ps1's own `$configPath`) -- known, and skipped rather than flagged.

    FAIL CLOSED ON A `. $var` THIS WALK CANNOT EXPLAIN. A variable dot-sourced without a matching
    entry in any of the three tables -- built some other way, or built on a line this walk's own
    assignment regex does not match -- is not silently skipped: it is recorded as UNRESOLVED, and the
    suite refuses on a non-empty list. The alternative (skip and say nothing) is exactly the shape of
    hole the guarded idiom above turned out to be: a file this suite believes it scanned, and does not.

    WHAT COUNTS AS A HIT: a live (non-comment-only) line matching a dot-source of the form
    `. (Join-Path $repoRoot '...')` or `. (Join-Path $RepoRoot '...')`, case either way -- the exact
    shape both retired call sites used -- OR a variable dot-source resolved through the forbidden table
    above. `$seamRoot` is a different identifier, so the two rewritten call sites do not match and the
    assertion is that NOTHING ELSE in the closure does either, in either form.

    NOT A CLAIM ABOUT EVERY .ps1 IN THE REPO -- deliberately scoped to the closure ship-pr.ps1 and
    open-pr.ps1 actually dot-source. A script only ever run as a CHILD PROCESS (fold-changelog-entry.ps1,
    verify-resolved-issues.ps1) resolves its own root independently and is out of scope here; each of
    those already receives an explicit -RepoRoot/-Branch from its caller rather than inheriting one, and
    fold-changelog-entry.ps1's own -RepoRoot only ever names a tree already standing on 'main' (the
    in-place checkout, the throwaway worktree, or -TrustedRoot) -- never the PR branch -- which is a
    fact about ITS callers, verified there, not restated as a rule this suite enforces.

    THE SECOND GUARD, AND IT IS WIDER (issue #2452, Dave's option 3). The dot-source rule above keeps
    PR-controlled CODE out of merge-on-green's "Ship it" step. What stays in that step is PR-controlled
    DATA -- the branch document, the PR title and body -- read as text by a process holding
    FOLD_PUSH_TOKEN. Splitting the step into two jobs was measured and refused on #2452 (there is no cut
    point where every data read precedes every write), so the guard that holds instead is "never add a
    primitive that turns that text into code". Its scope is the TOKEN PROCESS, not the dot-source
    closure: the same walk, plus every child script a file in it spawns with `powershell -File` (today
    fold-changelog-entry.ps1, verify-resolved-issues.ps1 and check-always-on-budget.ps1), plus each
    child's own dot-source closure, to a fixpoint. The children resolve their own root, so the
    $repoRoot rule above stays scoped to the dot-source closure; the primitive scan covers both.

    THE PRIMITIVES ARE FOUND ON THE AST, so a comment or a string literal naming one never counts:
    Invoke-Expression/iex/Invoke-Command/icm; Add-Type given source (anything but -AssemblyName);
    [scriptblock]::Create, .NewScriptBlock, .InvokeScript, .AddScript; powershell/pwsh with -Command or
    -EncodedCommand, directly or as a '-Command' argument-list string. `& $var` IS DELIBERATELY NOT ONE:
    the closure invokes scriptblock seams that way dozens of times (gate-lib, entry-scaffold-lib,
    check-report-lib), and a scriptblock value is code the file already holds, not text made into code.
    The allowances (the gate runners, which -TrustedRoot structurally skips) are keyed on file +
    function + kind, carry their reason, and are refused once they match nothing.

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

function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    if ("$Expected" -eq "$Actual") { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}

Write-Host 'Discovering ship-pr.ps1 + open-pr.ps1''s dot-source closure' -ForegroundColor Cyan

# THE WALK. $PSScriptRoot resolves per-FILE (each script's own directory), so a discovered target is
# resolved relative to the file that named it, not to $RepoRoot or to this suite's own location.
#
# RETURNS Closure (the file set, same shape as before), Unresolved (a `. $var` this walk could not
# explain -- the suite refuses on a non-empty list, see below) and ForbiddenVar (a `. $var` resolved to
# a $repoRoot/$RepoRoot-rooted assignment -- the variable-form twin of the literal-form scan further
# down this file). See this file's own header for why all three exist.
function Get-DotSourceClosure {
    param([string[]]$Seeds)
    $visited = @{}
    $unresolved = @()
    $forbiddenVar = @()
    $queue = New-Object System.Collections.Generic.Queue[string]
    foreach ($s in $Seeds) { $queue.Enqueue((Resolve-Path -LiteralPath $s).Path) }
    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        $key = $current.ToLowerInvariant()
        if ($visited.ContainsKey($key)) { continue }
        if (-not (Test-Path -LiteralPath $current -PathType Leaf)) { continue }
        $visited[$key] = $current
        $text = Get-Content -LiteralPath $current -Raw
        $dir  = Split-Path -Parent $current
        $name = Split-Path -Leaf $current

        # THREE ASSIGNMENT TABLES, LINE-ANCHORED (the same reason the literal-form regex below is
        # anchored to the start of a line): a comment merely discussing this shape has '#' as its first
        # non-space character, never '$', so it can never populate one of these tables.
        $psrVars = @{}
        foreach ($m in [regex]::Matches($text, "(?m)^[ \t]*\`$(\w+)\s*=\s*Join-Path\s+\`$PSScriptRoot\s+'([^']+)'")) {
            $psrVars[$m.Groups[1].Value] = $m.Groups[2].Value
        }
        $forbidVars = @{}
        foreach ($m in [regex]::Matches($text, "(?m)^[ \t]*\`$(\w+)\s*=\s*Join-Path\s+\`$(repoRoot|RepoRoot)\s+'([^']+)'")) {
            $forbidVars[$m.Groups[1].Value] = $m.Groups[2].Value
        }
        $seamVars = @{}
        foreach ($m in [regex]::Matches($text, "(?m)^[ \t]*\`$(\w+)\s*=\s*Join-Path\s+\`$seamRoot\s+'([^']+)'")) {
            $seamVars[$m.Groups[1].Value] = $true
        }

        # THE LITERAL-INLINE FORM, unchanged from before.
        foreach ($m in [regex]::Matches($text, "(?m)^[ \t]*\.\s*\(Join-Path\s+\`$PSScriptRoot\s+'([^']+)'\)")) {
            $target = Join-Path $dir $m.Groups[1].Value
            try { $resolved = (Resolve-Path -LiteralPath $target -ErrorAction Stop).Path } catch { continue }
            if (-not $visited.ContainsKey($resolved.ToLowerInvariant())) { $queue.Enqueue($resolved) }
        }

        # THE GUARDED, TWO-STEP FORM: a bare '. $var' at the start of a line, or one immediately after
        # an open brace on the same line ('if (...) { . $var; ... }') -- both real shapes in this
        # closure today, neither reachable from inside a '#'-comment.
        foreach ($m in [regex]::Matches($text, '(?m)(?:^[ \t]*|\{[ \t]*)\.[ \t]+\$(\w+)\b')) {
            $v = $m.Groups[1].Value
            $lineNo = ($text.Substring(0, $m.Index) -split "`n").Count
            if ($psrVars.ContainsKey($v)) {
                $target = Join-Path $dir $psrVars[$v]
                try { $resolved = (Resolve-Path -LiteralPath $target -ErrorAction Stop).Path } catch {
                    $unresolved += "$($name):$lineNo -> `$$v (resolved to '$target', which does not exist)"
                    continue
                }
                if (-not $visited.ContainsKey($resolved.ToLowerInvariant())) { $queue.Enqueue($resolved) }
            } elseif ($forbidVars.ContainsKey($v)) {
                $forbiddenVar += "$($name):$lineNo -> `$$v (assigned via Join-Path `$$($forbidVars[$v]) ...)"
            } elseif ($seamVars.ContainsKey($v)) {
                # The sanctioned seam (ship-pr.ps1's own $configPath) -- known and asserted on
                # separately below. Not a target to recurse into: it is the seam file itself.
            } else {
                # FAIL CLOSED: a '. $var' this walk cannot explain is not silently skipped.
                $unresolved += "$($name):$lineNo -> `$$v (no matching assignment found by this walk)"
            }
        }
    }
    return [pscustomobject]@{ Closure = @($visited.Values); Unresolved = $unresolved; ForbiddenVar = $forbiddenVar }
}

$discovery = Get-DotSourceClosure -Seeds @($ShipPath, $OpenPath)
$closure = $discovery.Closure
# A FLOOR, NOT A CEILING (issue #1145's own lesson on brittle counts applied here): this asserts the
# walk actually found something rather than silently scanning zero files -- a regex that stopped
# matching would make every assertion below vacuously true. 30 is comfortably under the 36 measured
# once the guarded two-step idiom joined the walk (September 24, 2026); a repo that trims dependencies
# is not a failure here, a walk that finds almost nothing is.
Assert-True ($closure.Count -ge 30) "the closure discovery found a plausible number of files ($($closure.Count))"
Assert-True (@($closure | Where-Object { $_ -ieq $ShipPath }).Count -gt 0) 'ship-pr.ps1 is in its own closure'
Assert-True (@($closure | Where-Object { $_ -ieq $OpenPath }).Count -gt 0) 'open-pr.ps1 is in its own closure'
Assert-True (@($closure | Where-Object { $_ -match '[\\/]source-repo-guard-lib\.ps1$' }).Count -gt 0) `
    'the GUARDED dot-source is followed too -- source-repo-guard-lib.ps1 is in the closure'

Write-Host ''
Write-Host 'The walk explains every guarded dot-source it meets, or refuses (fail closed)' -ForegroundColor Cyan

Assert-True ($discovery.Unresolved.Count -eq 0) `
    "every '. `$var' dot-source in the closure is explained by a Join-Path assignment this walk found ($($discovery.Unresolved.Count) unresolved)"
if ($discovery.Unresolved.Count -gt 0) {
    foreach ($u in $discovery.Unresolved) { Write-Host "         unresolved: $u" -ForegroundColor Red }
}

Write-Host ''
Write-Host 'No file in the closure dot-sources via $repoRoot/$RepoRoot -- only via $seamRoot' -ForegroundColor Cyan

# THE FORBIDDEN SHAPE: a dot-source Join-Path'd off $repoRoot or $RepoRoot, either case, anywhere in
# the closure. The two sanctioned call sites use a DIFFERENT identifier ($seamRoot), so this is not an
# allowlist of exact lines to skip -- it is a flat "zero occurrences" assertion, which is what makes a
# THIRD such line, added anywhere in the closure without anyone touching this suite, fail loudly.
$forbidden = '(?m)^[ \t]*\.\s*\(Join-Path\s+\$(repoRoot|RepoRoot)\b'
$hits = @()
foreach ($file in $closure) {
    $text = Get-Content -LiteralPath $file -Raw
    foreach ($m in [regex]::Matches($text, $forbidden)) {
        $lineNo = ($text.Substring(0, $m.Index) -split "`n").Count
        $hits += "$(Get-Item -LiteralPath $file | ForEach-Object { $_.Name }):$lineNo"
    }
}
# THE VARIABLE-FORM TWIN, from the SAME walk that built $closure -- a $repoRoot/$RepoRoot dot-source
# reached through '$var = Join-Path $repoRoot ...; . $var' is exactly as forbidden as the literal form
# above, and the walk already found every instance of it while discovering the closure itself.
Assert-True ($hits.Count -eq 0) 'no dot-source anywhere in the closure loads a .ps1 off $repoRoot/$RepoRoot directly (literal form)'
if ($hits.Count -gt 0) {
    foreach ($h in $hits) { Write-Host "         found: $h" -ForegroundColor Red }
}
Assert-True ($discovery.ForbiddenVar.Count -eq 0) `
    'no dot-source anywhere in the closure loads a .ps1 off $repoRoot/$RepoRoot through a variable either (guarded form)'
if ($discovery.ForbiddenVar.Count -gt 0) {
    foreach ($h in $discovery.ForbiddenVar) { Write-Host "         found: $h" -ForegroundColor Red }
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
Write-Host 'Regression: the widened walk actually follows the guarded idiom into an injected line' -ForegroundColor Cyan

# REPRODUCES THE PROOF FROM THIS FILE'S OWN HEADER, AGAINST A THROWAWAY FIXTURE -- never against the
# real source-repo-guard-lib.ps1. Two files: a caller using the EXACT guarded two-step idiom
# ship-pr.ps1/open-pr.ps1 use, and a "lib" it reaches that way carrying one forbidden line. Before the
# widened walk this suite could not see past the caller at all; after it, both the closure membership
# and the forbidden-pattern scan have to catch the injected line, or this section fails.
$seamFixtureDir = Join-Path ([System.IO.Path]::GetTempPath()) ("trusted-tree-seam-fixture-$PID-$([guid]::NewGuid().ToString('n'))")
New-Item -ItemType Directory -Path $seamFixtureDir -Force | Out-Null
try {
    $fixtureCaller  = Join-Path $seamFixtureDir 'fixture-caller.ps1'
    $fixtureGuarded = Join-Path $seamFixtureDir 'fixture-guarded-lib.ps1'
    [System.IO.File]::WriteAllText($fixtureCaller, @'
# The exact shape ship-pr.ps1:479 and open-pr.ps1:543 use -- an assignment, then a guarded dot-source
# of the VARIABLE, never the literal-inline form the original (pre-widened) walk matched.
$guardLib = Join-Path $PSScriptRoot 'fixture-guarded-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib }
'@, (New-Object System.Text.UTF8Encoding $false))
    [System.IO.File]::WriteAllText($fixtureGuarded, @'
# An otherwise innocuous guarded lib -- EXCEPT for the line below, which is reachable only through the
# guarded caller above. A walker that never follows '. $var' would build a closure that never contains
# this file at all, so the forbidden-pattern scan below would never read this line either.
. (Join-Path $repoRoot 'scripts\evil-payload.ps1')
'@, (New-Object System.Text.UTF8Encoding $false))

    $fixtureDiscovery = Get-DotSourceClosure -Seeds @($fixtureCaller)
    $fixtureGuardedResolved = (Resolve-Path -LiteralPath $fixtureGuarded).Path
    Assert-True (@($fixtureDiscovery.Closure | Where-Object { $_ -ieq $fixtureGuardedResolved }).Count -gt 0) `
        'the guarded lib IS discovered -- the walk followed the two-step idiom into it'
    Assert-Equal 0 $fixtureDiscovery.Unresolved.Count 'nothing in this clean fixture is unresolved'

    $fixtureHits = @()
    foreach ($f in $fixtureDiscovery.Closure) {
        foreach ($m in [regex]::Matches((Get-Content -LiteralPath $f -Raw), $forbidden)) { $fixtureHits += $f }
    }
    Assert-True (($fixtureHits.Count -gt 0) -or ($fixtureDiscovery.ForbiddenVar.Count -gt 0)) `
        'the injected $repoRoot dot-source, reachable only through the guarded lib, IS flagged'
} finally {
    Remove-Item -Recurse -Force -LiteralPath $seamFixtureDir -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------------------------------
# THE EXECUTION-PRIMITIVE GUARD (issue #2452, Dave's option 3). See this file's header for the why.
# ---------------------------------------------------------------------------------------------------

# THE ALLOWANCES, NAMED AND REASONED -- keyed on file + enclosing function + kind, never on a line number,
# and each one must still MATCH something (a stale allowance is refused below, so a moved or deleted
# call site cannot leave a blanket exemption behind). Every entry here sits in a GATE RUNNER, which
# -TrustedRoot/-SeamRoot structurally skip -- the section above asserts that forcing -- so none of them
# runs in the token-bearing step at all. A new entry needs the same argument, written in its Reason.
$script:ExecAllowances = @(
    [pscustomobject]@{ File = 'native-capture-lib.ps1'; Function = 'Invoke-TestSuiteGate'; Kind = 'powershell-command'
        Reason = 'runs Get-TestCommands (repo-config seam, loaded from trusted-main) inside the test gate, which -TrustedRoot force-skips' }
    [pscustomobject]@{ File = 'native-capture-lib.ps1'; Function = 'Invoke-TestSuiteGate'; Kind = 'unresolved-spawn'
        Reason = 'spawns each *.tests.ps1 suite inside the test gate, which -TrustedRoot force-skips' }
    [pscustomobject]@{ File = 'gate-lib.ps1'; Function = 'Invoke-WorkflowGates'; Kind = 'unresolved-spawn'
        Reason = 'spawns the lint script off $RepoRoot inside the lint gate, which -TrustedRoot force-skips' }
)

function Get-EnclosingFunctionName {
    param($Ast)
    for ($p = $Ast.Parent; $p; $p = $p.Parent) {
        if ($p -is [System.Management.Automation.Language.FunctionDefinitionAst]) { return $p.Name }
    }
    return '<script>'
}

# THE CHILD SPAWNS OF ONE FILE: every `-File <target>` handed to a new powershell process, in either
# shape the closure uses -- an array element (`@(..., '-File', (Join-Path $PSScriptRoot 'x.ps1'))`,
# splatted or given to Start-Process) or a parameter on a direct `& powershell ... -File ...` call.
# The target resolves through `Join-Path $PSScriptRoot '...'` inline or through a variable assigned that
# way (the same table the dot-source walk builds); anything else is UNRESOLVED -- fail closed, as the walk.
function Get-ChildSpawns {
    param([string]$Path)
    $tok = $null; $err = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tok, [ref]$err)
    $text = Get-Content -LiteralPath $Path -Raw
    $dir = Split-Path -Parent $Path
    $name = Split-Path -Leaf $Path
    $psrVars = @{}
    foreach ($m in [regex]::Matches($text, "(?m)^[ \t]*\`$(\w+)\s*=\s*Join-Path\s+\`$PSScriptRoot\s+'([^']+)'")) {
        $psrVars[$m.Groups[1].Value] = $m.Groups[2].Value
    }
    $targets = @()
    foreach ($s in $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $args[0].Value -eq '-File' }, $true)) {
        if ($s.Parent -is [System.Management.Automation.Language.ArrayLiteralAst]) {
            $els = @($s.Parent.Elements)
            $i = [array]::IndexOf($els, $s)
            if ($i -ge 0 -and $i + 1 -lt $els.Count) { $targets += [pscustomobject]@{ Anchor = $s; Target = $els[$i + 1] } }
        }
    }
    foreach ($c in $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] -and $args[0].GetCommandName() -match '^(powershell|pwsh)(\.exe)?$' }, $true)) {
        $els = @($c.CommandElements)
        for ($i = 0; $i -lt $els.Count - 1; $i++) {
            if ($els[$i] -is [System.Management.Automation.Language.CommandParameterAst] -and $els[$i].ParameterName -eq 'File') {
                $targets += [pscustomobject]@{ Anchor = $c; Target = $els[$i + 1] }
            }
        }
    }
    $resolved = @(); $unresolved = @()
    foreach ($t in $targets) {
        $tt = $t.Target.Extent.Text
        $rel = $null
        $m = [regex]::Match($tt, "Join-Path\s+\`$PSScriptRoot\s+'([^']+)'")
        if ($m.Success) { $rel = $m.Groups[1].Value }
        else {
            $m = [regex]::Match($tt, "^\(?\s*(?:'`"'\s*\+\s*)?\`$(\w+)\s*(?:\+\s*'`"'\s*)?\)?$")
            if ($m.Success -and $psrVars.ContainsKey($m.Groups[1].Value)) { $rel = $psrVars[$m.Groups[1].Value] }
        }
        $where = [pscustomobject]@{ File = $name; Function = (Get-EnclosingFunctionName $t.Anchor); Line = $t.Anchor.Extent.StartLineNumber; Text = $tt }
        $full = if ($rel) { Join-Path $dir $rel } else { $null }
        if ($full -and (Test-Path -LiteralPath $full -PathType Leaf)) { $resolved += (Resolve-Path -LiteralPath $full).Path }
        else { $unresolved += $where }
    }
    return [pscustomobject]@{ Resolved = $resolved; Unresolved = $unresolved }
}

# THE TOKEN-PROCESS CLOSURE: the dot-source closure of the seeds, plus every child script any file in it
# spawns, plus THAT child's dot-source closure, to a fixpoint. Discovered, never hand-listed -- the same
# rule the dot-source walk above obeys, for the same reason.
function Get-TokenProcessClosure {
    param([string[]]$Seeds)
    $seedSet = @{}
    foreach ($s in $Seeds) { $seedSet[(Resolve-Path -LiteralPath $s).Path.ToLowerInvariant()] = (Resolve-Path -LiteralPath $s).Path }
    while ($true) {
        $walk = Get-DotSourceClosure -Seeds @($seedSet.Values)
        $spawnUnresolved = @(); $added = $false
        foreach ($f in $walk.Closure) {
            $sp = Get-ChildSpawns -Path $f
            $spawnUnresolved += $sp.Unresolved
            foreach ($r in $sp.Resolved) {
                if (-not $seedSet.ContainsKey($r.ToLowerInvariant())) { $seedSet[$r.ToLowerInvariant()] = $r; $added = $true }
            }
        }
        if (-not $added) {
            return [pscustomobject]@{ Closure = $walk.Closure; Children = @($seedSet.Values); DotUnresolved = $walk.Unresolved; SpawnUnresolved = $spawnUnresolved }
        }
    }
}

# THE PRIMITIVES -- every way a STRING becomes CODE, found on the AST, so a comment or a string literal
# that merely NAMES one never counts. `& $var` is deliberately NOT one: the closure invokes scriptblock
# seams that way dozens of times (gate-lib, entry-scaffold-lib, check-report-lib), and a scriptblock
# value is code the file already holds, not text turned into code.
function Get-ExecPrimitiveFindings {
    param([string[]]$Files)
    $out = @()
    foreach ($f in $Files) {
        $tok = $null; $err = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$tok, [ref]$err)
        $name = Split-Path -Leaf $f
        $found = New-Object System.Collections.Generic.List[object]
        $add = { param($node, $kind) $found.Add([pscustomobject]@{ File = $name; Function = (Get-EnclosingFunctionName $node); Kind = $kind; Line = $node.Extent.StartLineNumber }) }
        foreach ($c in $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)) {
            $n = "$($c.GetCommandName())"
            if ($n -match '^(Invoke-Expression|iex|Invoke-Command|icm)$') { & $add $c 'invoke-expression' }
            elseif ($n -eq 'Add-Type') {
                # -AssemblyName loads a compiled assembly, which is not source; anything else hands Add-Type
                # text to compile -- a named source parameter, -Path, or a positional argument.
                $els = @($c.CommandElements); $bad = $false
                for ($i = 1; $i -lt $els.Count; $i++) {
                    $e = $els[$i]
                    if ($e -is [System.Management.Automation.Language.CommandParameterAst]) {
                        if ($e.ParameterName -notmatch '^(AssemblyName|ErrorAction|WarningAction|PassThru)$') { $bad = $true }
                        elseif ($e.ParameterName -ne 'PassThru' -and -not $e.Argument) { $i++ }
                    } else { $bad = $true }
                }
                if ($bad) { & $add $c 'add-type-source' }
            }
            elseif ($n -match '^(powershell|pwsh)(\.exe)?$') {
                foreach ($e in $c.CommandElements) {
                    if ($e -is [System.Management.Automation.Language.CommandParameterAst] -and $e.ParameterName -match '^(Command|c|EncodedCommand|enc|e|ec)$') { & $add $c 'powershell-command' }
                }
            }
        }
        foreach ($s in $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $args[0].Value -match '^-(Command|EncodedCommand)$' }, $true)) {
            & $add $s 'powershell-command'
        }
        foreach ($m in $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.InvokeMemberExpressionAst] }, $true)) {
            $mn = "$($m.Member.Extent.Text)"
            if ($mn -match '^(NewScriptBlock|InvokeScript|AddScript)$') { & $add $m 'scriptblock-from-text' }
            elseif ($mn -eq 'Create' -and $m.Expression -is [System.Management.Automation.Language.TypeExpressionAst] -and
                    $m.Expression.TypeName.FullName -match '^(System\.Management\.Automation\.)?scriptblock$') { & $add $m 'scriptblock-from-text' }
        }
        $out += $found.ToArray()
    }
    return $out
}

function Test-ExecAllowed {
    param($Finding)
    return @($script:ExecAllowances | Where-Object { $_.File -ieq $Finding.File -and $_.Function -eq $Finding.Function -and $_.Kind -eq $Finding.Kind }).Count -gt 0
}

Write-Host ''
Write-Host 'The token-bearing process runs no string-to-code primitive (#2452)' -ForegroundColor Cyan

$token = Get-TokenProcessClosure -Seeds @($ShipPath, $OpenPath)
$childLeaves = @($token.Children | ForEach-Object { Split-Path -Leaf $_ })
Assert-True ($token.Closure.Count -gt $closure.Count) `
    "the token-process closure is WIDER than the dot-source closure ($($token.Closure.Count) against $($closure.Count))"
foreach ($expected in @('fold-changelog-entry.ps1', 'verify-resolved-issues.ps1', 'check-always-on-budget.ps1')) {
    Assert-True ($childLeaves -contains $expected) "the child spawn $expected is discovered, not hand-listed"
}
Assert-Equal 0 $token.DotUnresolved.Count 'every dot-source in the children''s closures is explained too (fail closed)'
foreach ($u in $token.DotUnresolved) { Write-Host "         unresolved: $u" -ForegroundColor Red }

$spawnLeft = @($token.SpawnUnresolved | Where-Object { -not (Test-ExecAllowed ([pscustomobject]@{ File = $_.File; Function = $_.Function; Kind = 'unresolved-spawn' })) })
Assert-Equal 0 $spawnLeft.Count 'every child powershell -File the closure spawns resolves to a script this walk then scans, or is an allowed gate runner'
foreach ($u in $spawnLeft) { Write-Host "         unresolved spawn: $($u.File):$($u.Line) [$($u.Function)] $($u.Text)" -ForegroundColor Red }

$prims = @(Get-ExecPrimitiveFindings -Files $token.Closure)
$primLeft = @($prims | Where-Object { -not (Test-ExecAllowed $_) })
Assert-Equal 0 $primLeft.Count 'no file in the token-process closure turns a string into code outside a named allowance'
foreach ($p in $primLeft) { Write-Host "         found: $($p.File):$($p.Line) [$($p.Function)] $($p.Kind)" -ForegroundColor Red }

$observed = @($prims | ForEach-Object { "$($_.File)|$($_.Function)|$($_.Kind)" }) +
            @($token.SpawnUnresolved | ForEach-Object { "$($_.File)|$($_.Function)|unresolved-spawn" })
foreach ($a in $script:ExecAllowances) {
    Assert-True ($observed -contains "$($a.File)|$($a.Function)|$($a.Kind)") `
        "the allowance $($a.File) [$($a.Function)] $($a.Kind) still matches a call site (no stale exemption)"
}

Write-Host ''
Write-Host 'Regression: a primitive planted in a child-spawned lib is flagged; its look-alikes are not' -ForegroundColor Cyan

# A THROWAWAY FIXTURE, never the real tree: a caller spawning a child the way ship-pr.ps1 spawns the fold,
# the child reaching a lib through the guarded two-step dot-source, and that lib carrying one real
# primitive among the look-alikes the AST scan must NOT count -- a comment, a string, Add-Type
# -AssemblyName, and a non-scriptblock ::Create().
$execFixtureDir = Join-Path ([System.IO.Path]::GetTempPath()) ("trusted-tree-exec-fixture-$PID-$([guid]::NewGuid().ToString('n'))")
New-Item -ItemType Directory -Path $execFixtureDir -Force | Out-Null
try {
    $utf8 = New-Object System.Text.UTF8Encoding $false
    $fxCaller = Join-Path $execFixtureDir 'fixture-caller.ps1'
    [System.IO.File]::WriteAllText($fxCaller, @'
$childArgs = @('-NoProfile', '-File', (Join-Path $PSScriptRoot 'fixture-child.ps1'))
& powershell @childArgs
'@, $utf8)
    [System.IO.File]::WriteAllText((Join-Path $execFixtureDir 'fixture-child.ps1'), @'
$lib = Join-Path $PSScriptRoot 'fixture-lib.ps1'
if (Test-Path -LiteralPath $lib -PathType Leaf) { . $lib }
'@, $utf8)
    [System.IO.File]::WriteAllText((Join-Path $execFixtureDir 'fixture-lib.ps1'), @'
# Invoke-Expression in a comment is not a primitive.
$note = 'iex is only named here'
Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
$h = [System.Security.Cryptography.SHA256]::Create()
function Read-Planted { param($Body) Invoke-Expression $Body }
'@, $utf8)

    $fx = Get-TokenProcessClosure -Seeds @($fxCaller)
    Assert-True (@($fx.Children | Where-Object { $_ -match 'fixture-child\.ps1$' }).Count -gt 0) 'the child spawn is followed'
    Assert-True (@($fx.Closure | Where-Object { $_ -match 'fixture-lib\.ps1$' }).Count -gt 0) 'the child''s guarded dot-source is followed into the lib'
    $fxPrims = @(Get-ExecPrimitiveFindings -Files $fx.Closure)
    Assert-Equal 1 $fxPrims.Count 'exactly one primitive is flagged -- the planted one, none of its look-alikes'
    Assert-True (@($fxPrims | Where-Object { $_.Kind -eq 'invoke-expression' -and $_.Function -eq 'Read-Planted' }).Count -eq 1) `
        'the planted Invoke-Expression is the one flagged, inside its own function'
} finally {
    Remove-Item -Recurse -Force -LiteralPath $execFixtureDir -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
