<#
.SYNOPSIS
    Regression tests for scripts/lib/command-probe-lib.ps1's Test-FunctionDefined -- the function-table
    probe that replaced 98 inline Get-Command guards (issue #1729) -- AND the tree-wide gate that keeps
    the idiom from coming back.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Exit 0 if everything passes, 1 on a failure.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/command-probe-lib.tests.ps1

    WHAT IS ASSERTED, and why each one is here rather than assumed:

      1. IT FINDS A FUNCTION FROM EVERY SCOPE A CALLER CAN BE IN -- global, script, inside a nested
         function, and inside a child scope created by '& { }'. This is the substitution's load-bearing
         claim: the probes it replaced sit in dot-sourced libs called from nested functions, and a
         lookup narrower than Get-Command's would have gone wrong SILENTLY -- answering "no" and
         falling through to a default. Nothing downstream would have failed loudly.
      2. IT DOES NOT FIND A CMDLET OR AN ALIAS. That is the deliberate narrowing, so it is pinned
         rather than left as an accident of the implementation: a probe for an EXTERNAL command is a
         different question, and the sites that ask it (gh, git) rightly kept Get-Command.
      3. THE NAME IS A LITERAL, NEVER A PATTERN. Get-Command misses a genuinely defined function whose
         name contains '[' and ']', because it reads them as a character class. That assert is the
         cheap, reproducible evidence that the replaced idiom really did go through the wildcard
         matcher -- the machinery whose access violation in #1723 is what got #1729 filed. That fault
         has ONE sighting and was never reproduced, so it is deliberately NOT what this suite tests;
         this is the part that can be proven on any machine, on any run.
      4. DEGENERATE INPUT IS TOTAL: '', whitespace and $null return $false instead of throwing. A probe
         is asked in order to decide whether to call something, so a caller handed an empty seam name
         wants "no" rather than a terminating error two frames further down.
      5. THE TREE-WIDE GATE (section 5): no .ps1 under scripts/ probes for a HYPHENATED name with
         `Get-Command ... -ErrorAction SilentlyContinue` any more, outside a named exception list.

    WHY THE GATE READS THE AST AND NOT THE TEXT. The idiom is quoted in prose in at least two
    docstrings -- this lib's own, and seam-lib.ps1's record of the three sites that used to probe
    inline -- and both are correct as history that must not be rewritten. A grep-based gate would have
    to special-case them by line number, which goes stale the moment either file is edited. Parsing
    means a comment is not a call site, with no list to maintain for that.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# THE REPO ROOT, judged and ANCHORED (#1917). -From pins the git call to this file's own directory
# instead of the inherited working directory: this suite tree stands up throwaway git repos and
# changes into them, so a cwd-relative answer can name the wrong repo. Resolve-RepoRootOrFail
# refuses with git's exit code and stderr where the old (git rev-parse ...).Trim() died on
# $null.Trim() -- which here meant a suite testing the wrong file, or none.
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$RepoRoot = Resolve-RepoRootOrFail -From $PSScriptRoot -ScriptName 'command-probe-lib.tests.ps1'
. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')

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

Write-Host "`n1. it finds a function from every scope a caller can be in" -ForegroundColor Cyan

function Get-ProbeScriptScopedSeam { 'script' }
Invoke-Expression 'function global:Get-ProbeGlobalScopedSeam { "global" }'

Assert-True (Test-FunctionDefined 'Get-ProbeScriptScopedSeam') 'a script-scoped function is found at top level'
Assert-True (Test-FunctionDefined 'Get-ProbeGlobalScopedSeam') 'a global function is found at top level'

function Test-ProbeOuter {
    function Test-ProbeInner {
        [pscustomobject]@{
            Script = Test-FunctionDefined 'Get-ProbeScriptScopedSeam'
            Global = Test-FunctionDefined 'Get-ProbeGlobalScopedSeam'
            Self   = Test-FunctionDefined 'Test-ProbeInner'
            Absent = Test-FunctionDefined 'Get-ProbeNoSuchSeamAnywhere'
        }
    }
    Test-ProbeInner
}
$nested = Test-ProbeOuter
Assert-Equal $true  $nested.Script 'a script-scoped function is found from inside a nested function'
Assert-Equal $true  $nested.Global 'a global function is found from inside a nested function'
Assert-Equal $true  $nested.Self   'a function finds itself'
Assert-Equal $false $nested.Absent 'an undefined name is $false rather than an error'

$child = & { Test-FunctionDefined 'Get-ProbeScriptScopedSeam' }
Assert-Equal $true $child 'a script-scoped function is found from inside a child scope'

Write-Host "`n2. it answers about FUNCTIONS only -- the deliberate narrowing" -ForegroundColor Cyan

Assert-Equal $false (Test-FunctionDefined 'Get-ChildItem') 'a cmdlet is not a function, so the probe says no'
Assert-Equal $false (Test-FunctionDefined 'ls')            'an alias is not a function either'
# The contrast, so the narrowing is pinned as a DIFFERENCE rather than as this probe merely being wrong:
# the call it replaced answers yes to the same name. This one is a hit, which is Get-Command's cheap
# direction, so asserting it costs the suite nothing.
Assert-True ([bool](Get-Command 'Get-ChildItem' -ErrorAction SilentlyContinue)) 'and Get-Command does say yes to that cmdlet -- the narrowing is real'

Write-Host "`n3. the name is a literal, never a wildcard pattern (the #1723 machinery)" -ForegroundColor Cyan

Invoke-Expression 'function global:Get-ProbeWeird[x] { "bracketed" }'
Assert-True (Test-FunctionDefined 'Get-ProbeWeird[x]') 'a function whose name contains [ ] is found by its literal name'
Assert-Equal $false ([bool](Get-Command 'Get-ProbeWeird[x]' -ErrorAction SilentlyContinue)) 'while Get-Command MISSES it -- it reads the name as a character class, which is the wildcard path #1723 faulted inside'

Write-Host "`n4. degenerate input is total" -ForegroundColor Cyan

foreach ($bad in @(@{ v = ''; l = 'the empty string' }, @{ v = '   '; l = 'whitespace' })) {
    $got = try { Test-FunctionDefined $bad.v } catch { "THREW $($_.Exception.GetType().Name)" }
    Assert-Equal $false $got "$($bad.l) is `$false rather than a throw"
}
$gotNull = try { Test-FunctionDefined $null } catch { "THREW $($_.Exception.GetType().Name)" }
Assert-Equal $false $gotNull '$null is $false rather than a throw'

Write-Host "`n5. the gate: no .ps1 under scripts/ still probes a hyphenated name with Get-Command" -ForegroundColor Cyan

# THE EXCEPTIONS, each one asking a DIFFERENT QUESTION rather than being a site nobody got to. Keyed on
# the repo-relative path, with the reason on the line -- the same shape as every other allow-list here.
$Exceptions = @{
    # Asks WHICH FILE defines the function: it reads .ScriptBlock.File off the returned CommandInfo,
    # which a boolean cannot carry. The note above that call says the same.
    'scripts\tests\release-lib.tests.ps1'            = 'reads .ScriptBlock.File off the CommandInfo'
    # Asks whether a name resolves to ANY command. A template legitimately calls cmdlets, and the
    # fixture strings there are simulated TEMPLATE source, which cannot dot-source a lib at all.
    'scripts\tests\template-selfcontained.tests.ps1' = 'judges any command type, and carries template fixture text'
    # THIS FILE, because sections 2 and 3 call the replaced idiom ON PURPOSE: each is one half of a
    # contrast that has no meaning unless the old call is really made. Exempting the gate's own suite
    # looks like the exemption that swallows the rule, so it is worth being exact about why it does not
    # -- these two calls are the EVIDENCE for the rule, and a gate that refused them would be refusing
    # the proof that it is worth having. The first assert of each pair covers the replacement; the
    # Get-Command half is what shows the two answers differ.
    'scripts\tests\command-probe-lib.tests.ps1'      = 'calls the replaced idiom deliberately, as the contrast half of sections 2 and 3'
}

$findings = @()
Get-ChildItem -Path (Join-Path $RepoRoot 'scripts') -Recurse -Filter *.ps1 | ForEach-Object {
    $rel = $_.FullName.Substring($RepoRoot.Length + 1)
    if ($Exceptions.ContainsKey($rel)) { return }
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$null)
    $calls = $ast.FindAll({
            param($n)
            $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Get-Command'
        }, $true)
    foreach ($call in $calls) {
        $text = $call.Extent.Text
        if ($text -notmatch '-E(rrorAction|A)\s+SilentlyContinue') { continue }
        # -CommandType means the caller wants the CommandInfo's shape, not a yes/no.
        if ($text -match '-CommandType') { continue }
        # The name it asks about: a hyphenated literal, or a variable, which can hold one.
        $named = @($call.CommandElements | Select-Object -Skip 1 |
                Where-Object { $_ -isnot [System.Management.Automation.Language.CommandParameterAst] })
        foreach ($a in $named) {
            $probe = $a.Extent.Text.Trim(@("'", '"'))
            if ($probe -match '^\$' -or $probe -match '^[A-Za-z][A-Za-z0-9]*-[A-Za-z0-9-]+$') {
                $findings += "$rel line $($call.Extent.StartLineNumber): $($text -replace '\s+', ' ')"
            }
        }
    }
}
if ($findings.Count -gt 0) {
    Write-Host '  the function-table probe belongs behind Test-FunctionDefined (issue #1729):' -ForegroundColor Red
    $findings | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
}
# The label names no COUNT of exceptions, deliberately: this tree has been bitten repeatedly by a figure
# in prose drifting from the structure beside it (seam-lib.ps1's own census went wrong at three different
# values in nine days). $Exceptions is the inventory and it cannot go stale against itself.
Assert-Equal 0 $findings.Count 'no Get-Command function probe survives outside the named exceptions'

Remove-Item -Force -LiteralPath 'Function:\Get-ProbeGlobalScopedSeam' -ErrorAction SilentlyContinue
Remove-Item -Force -LiteralPath 'Function:\Get-ProbeWeird[x]' -ErrorAction SilentlyContinue

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
