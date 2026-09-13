<#
.SYNOPSIS
    Regression tests for scripts/lib/document-newline-lib.ps1's Get-DocumentNewline -- the one reading
    of a document's own newline style, which replaced nine hand-typed copies across six files
    (issue #1832) -- AND the tree-wide gate that keeps those copies from coming back.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Exit 0 if everything passes, 1 on a failure.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/document-newline.tests.ps1

    WHAT IS ASSERTED, and why each one is here rather than assumed:

      1. THE TWO ANSWERS, on the inputs the callers actually hand it: a CRLF document, an LF document,
         a document with no line break at all, and the empty string. The last two are the ones worth
         pinning rather than reading off the implementation -- there is no evidence for CRLF in either,
         and a caller handed one is writing the first content into the file, so "`n" is the answer that
         keeps a fresh page single-style.
      2. A MIXED DOCUMENT ANSWERS CRLF, whichever order the two styles appear in. This is the KNOWN
         LIMIT of the whole-file reading, not a bug, and it is asserted precisely because extracting
         the reading must not quietly change it: #1829 accepted the relocated mix on the argument that
         every document-editing script in this tree asks the same whole-file question, and a later
         "improvement" to a neighbourhood-local answer would break that argument for all nine sites at
         once. The assert is what makes that a decision rather than an accident.
      3. A LONE CR IS NOT CRLF. Old-Mac line endings are not a style anything here writes, and the
         reading keys on the PAIR -- so a document full of bare CR answers "`n" rather than "`r`n".
         Pinned because '.Contains' on a two-character string is easy to "simplify" into a search for
         "`r", which would answer CRLF for a file that has no CRLF in it.
      4. EVERY CALLER CAN REACH IT (section 4). The helper is dot-sourced in two places and the other
         four files reach it transitively, so a removed dot-source would break callers that name no lib
         at all. The three libs are loaded in a child scope and asked directly; the three scripts, which
         cannot be dot-sourced without running, are held to the dot-source line that gives them the
         reach.
      5. THE TREE-WIDE GATE (section 5): no .ps1 under scripts/ reads a newline style with an inline
         '.Contains("`r`n")' any more, outside a named exception list.

    WHY THE GATE READS THE AST AND NOT THE TEXT. The idiom is quoted in prose in this lib's own banner
    and in adopt-workflow-folder.ps1's record of #1829, and both are correct as history that must not
    be rewritten. A grep-based gate would have to special-case them by line number, which goes stale
    the moment either file is edited. Parsing means a comment is not a call site, with no list to
    maintain for that -- command-probe-lib.tests.ps1's gate is built the same way, for the same reason.

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
$RepoRoot = Resolve-RepoRootOrFail -From $PSScriptRoot -ScriptName 'document-newline.tests.ps1'
. (Join-Path $PSScriptRoot '..\lib\document-newline-lib.ps1')

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

$CRLF = "`r`n"
$LF   = "`n"

# --- 1. the two answers, on what the callers actually hand it ---------------------------------------
Write-Host ''
Write-Host '1. the two answers' -ForegroundColor Cyan
Assert-Equal $CRLF (Get-DocumentNewline -Content "## Title`r`n`r`nbody`r`n") 'a CRLF document answers CRLF'
Assert-Equal $LF   (Get-DocumentNewline -Content "## Title`n`nbody`n")       'an LF document answers LF'
Assert-Equal $LF   (Get-DocumentNewline -Content 'one line, no break')       'a document with no line break answers LF'
Assert-Equal $LF   (Get-DocumentNewline -Content '')                         'the empty string answers LF -- a fresh page is written single-style'

# --- 2. the known limit: a mixed document answers CRLF ----------------------------------------------
# See the banner. This is #1829's accepted trade, asserted so that extracting the reading cannot
# silently change it and a later local-answer "improvement" cannot land without reading this note.
Write-Host ''
Write-Host '2. the whole-file limit, pinned' -ForegroundColor Cyan
Assert-Equal $CRLF (Get-DocumentNewline -Content "mostly`nLF`nwith one`r`nstray") 'mostly LF with one CRLF answers CRLF (the mix is relocated, not removed)'
Assert-Equal $CRLF (Get-DocumentNewline -Content "one`r`nCRLF then`nall`nLF")     'the answer does not depend on which style comes first'

# --- 3. a lone CR is not CRLF -----------------------------------------------------------------------
Write-Host ''
Write-Host '3. the reading keys on the pair' -ForegroundColor Cyan
Assert-Equal $LF (Get-DocumentNewline -Content "old`rmac`rline`rendings") 'bare CR answers LF -- it is not a CRLF document'
Assert-Equal $LF (Get-DocumentNewline -Content "trailing CR only`r")     'a trailing bare CR answers LF'

# --- 4. every caller can reach it -------------------------------------------------------------------
# THE THREE LIBS ARE ASKED, NOT INFERRED: each is loaded in a child scope with nothing else present, so
# the assert fails if its dot-source line is removed or misspelled. A lib only defines functions, which
# is what makes this safe to do; the three SCRIPTS cannot be dot-sourced without running, so they are
# held to the one line that gives them the reach instead.
Write-Host ''
Write-Host '4. reachability from every caller' -ForegroundColor Cyan
$libRoot = Join-Path $RepoRoot 'scripts\lib'
foreach ($lib in @('entry-scaffold-lib', 'pr-body-lib', 'release-lib')) {
    $defined = & {
        . (Join-Path $libRoot "$lib.ps1")
        [bool](Get-Item -LiteralPath 'Function:\Get-DocumentNewline' -ErrorAction SilentlyContinue)
    }
    Assert-True $defined "$lib.ps1 defines Get-DocumentNewline once loaded"
}
# The reach for the three scripts is entry-scaffold-lib, asserted above. What can go wrong here is that
# a script stops loading it while still calling the helper, so the dot-source is what is read.
$scriptReach = @{
    'scripts\release\cut-release.ps1'           = 'entry-scaffold-lib.ps1'
    'scripts\release\fold-changelog-entry.ps1'  = 'entry-scaffold-lib.ps1'
    'scripts\task\adopt-workflow-folder.ps1'    = 'entry-scaffold-lib.ps1'
}
foreach ($rel in $scriptReach.Keys | Sort-Object) {
    $text = [System.IO.File]::ReadAllText((Join-Path $RepoRoot $rel))
    $via = $scriptReach[$rel]
    Assert-True ($text -match ('(?m)^\s*\.\s+\(Join-Path .*' + [regex]::Escape($via) + "'\)")) `
        "$rel reaches the helper by dot-sourcing $via"
    Assert-True ($text -match 'Get-DocumentNewline') "$rel calls Get-DocumentNewline"
}

# --- 5. the tree-wide gate --------------------------------------------------------------------------
# A '.Contains' whose argument is the CRLF pair is only ever asked for one of two reasons: to decide a
# newline style (which is this helper's job) or to assert one about an output (which is a test's job).
# The exceptions below are exactly the second kind, plus the helper that holds the one reading.
Write-Host ''
Write-Host '5. no inline newline reading survives' -ForegroundColor Cyan
$Exceptions = @{
    # THE ONE READING. Its body is the idiom, by definition.
    'scripts\lib\document-newline-lib.ps1'      = 'holds the one definition of the reading'
    # Asserts that a CRLF body came back CRLF -- a claim about an OUTPUT, not a reading of an input.
    # Removing it would delete the regression cover for pr-body-lib's half of #1829.
    'scripts\tests\pr-body.tests.ps1'           = 'asserts a style about an output, not a reading of an input'
    # THIS FILE, for the same reason: sections 1-3 ask about outputs, and section 5 quotes the idiom in
    # order to gate it. Exempting the gate's own suite looks like the exemption that swallows the rule,
    # so it is worth being exact -- nothing here decides how to compose a document.
    'scripts\tests\document-newline.tests.ps1'  = 'asserts styles about outputs, and quotes the idiom to gate it'
}
$findings = @()
Get-ChildItem -Path (Join-Path $RepoRoot 'scripts') -Recurse -Filter *.ps1 | ForEach-Object {
    $rel = $_.FullName.Substring($RepoRoot.Length + 1)
    if ($Exceptions.ContainsKey($rel)) { return }
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$null)
    $calls = $ast.FindAll({
            param($n)
            $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and
            "$($n.Member.Extent.Text)" -eq 'Contains'
        }, $true)
    foreach ($call in $calls) {
        if ($null -eq $call.Arguments -or $call.Arguments.Count -lt 1) { continue }
        $argText = $call.Arguments[0].Extent.Text
        # Either spelling of the pair: the escaped source form, or the two real characters.
        if ($argText -match '`r`n' -or $argText -match "\r\n") {
            $findings += "$rel line $($call.Extent.StartLineNumber): $($call.Extent.Text -replace '\s+', ' ')"
        }
    }
}
if ($findings.Count -gt 0) {
    Write-Host '  the newline reading belongs behind Get-DocumentNewline (issue #1832):' -ForegroundColor Red
    $findings | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
}
# The label names no COUNT of exceptions, deliberately -- $Exceptions is the inventory and it cannot go
# stale against itself. Same reasoning as command-probe-lib.tests.ps1's own gate label.
Assert-Equal 0 $findings.Count 'no inline CRLF newline reading survives outside the named exceptions'

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0