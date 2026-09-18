<#
.SYNOPSIS
    The tree-wide gate that keeps a mistyped flag from running a script for real -- every .ps1 with a
    top-level param block declares [CmdletBinding()] (issue #2092) -- plus the driven proof of WHY
    that attribute is the thing that decides it.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Exit 0 if everything passes, 1 on a failure.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/param-binding-strictness.tests.ps1

    THE DEFECT THIS EXISTS FOR. Every script in this workflow is run as
    'powershell -NoProfile -ExecutionPolicy Bypass -File <script> ...'. A script whose param block is
    a PLAIN one does not refuse an unrecognised named parameter: PowerShell drops it into $args and
    the script RUNS WITH ITS DEFAULTS. So fold-changelog-entry.ps1 -DryRun -- a flag that script has
    never declared -- did not print what it would do and did not refuse. It folded: it deleted the
    branch document from the working tree and rewrote CHANGELOG.md. Measured September 17, 2026 on
    branch fix/2090-anchor-ordering-asserts, where the only reason nothing was lost is that the
    document happened to have been committed minutes earlier.

    WHAT IS ASSERTED, and why each one is here rather than assumed:

      1. THE MECHANISM, DRIVEN (section 1). Two fixture scripts with identical param blocks, one bare
         and one carrying [CmdletBinding()], are each run through the real '-File' entry point with an
         undeclared flag. The bare one prints its marker and exits 0; the bound one prints nothing and
         exits 1. This is pinned rather than described because the REASON was the half that got
         reported wrong, and a gate whose reason nobody can re-run degrades into a style rule the next
         reader deletes.
      2. THE UNDECLARED FLAG SWALLOWS THE VALUE BEHIND IT (section 2). '-Nope foo' binds nothing: the
         first declared [string] stays EMPTY and both tokens land in $args. Worth its own assert
         because the original report explained the defect as the flag being bound AS the value of the
         first positional parameter, which would have left a caller's real argument in place. It does
         the opposite -- a preceding unknown flag can eat an argument the caller did supply -- so a
         repair built on the reported reason would have guarded the wrong thing.
      3. THE FIRST PARAMETER'S TYPE IS NOT THE AXIS (section 3). A bare param block whose first
         parameter is a [switch], not a [string], swallows the undeclared flag exactly the same way.
         The report scoped the hazard to the 33 scripts taking a [string] first; that count measures
         nothing, and pinning the counter-case is what stops it being reinstated as the gate's filter.
      4. THE TREE-WIDE GATE (section 4): every .ps1 under scripts/ and plugins/ that has a top-level
         param block declares [CmdletBinding()]. There is deliberately NO exception list. An empty
         carve-out is the whole strength of this gate -- the defect is that a script silently accepts
         what it does not understand, and an exempt script is one that still does.

    WHY THE GATE READS THE AST AND NOT THE TEXT. '[CmdletBinding()]' is quoted in prose in this file's
    own banner and in the changelog entry for #2092; a grep-based gate would count those as
    compliance, and would also miss a param block that carries the attribute on the same line. Parsing
    asks the question the runtime asks -- does the param block carry this attribute -- which is the
    only reading that predicts what '-File' will do. Same reasoning, and the same shape, as
    document-newline.tests.ps1's own gate.

    A LIB IS HELD TO IT TOO, and that is not over-reach. A dot-sourced lib with a top-level param
    block is still a file somebody runs directly while working on it, and holding the whole tree to
    one rule is what makes the exception list empty.

    Pure ASCII (repo convention for .ps1).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# The repo root, judged and ANCHORED -- this suite writes fixtures under its own temp dir and must not
# resolve the root from an inherited working directory. Same seam every other suite here uses.
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$RepoRoot = Resolve-RepoRootOrFail -From $PSScriptRoot -ScriptName 'param-binding-strictness.tests.ps1'
# EVERY FIXTURE RUN GOES THROUGH Invoke-NativeCapture, and it has to. A refused binding writes to
# stderr, and under $ErrorActionPreference = 'Stop' PowerShell 5.1 promotes a native command's stderr
# to a terminating NativeCommandError -- so a plain '& powershell ... 2>&1' would kill this suite on
# exactly the assert it exists to make. That is the #96/#97/#107 lesson, already centralized.
. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')

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

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("param-binding-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

function New-Fixture {
    param([string]$Name, [string]$Body)
    $p = Join-Path $tmp $Name
    [System.IO.File]::WriteAllText($p, $Body, (New-Object System.Text.UTF8Encoding($false)))
    return $p
}

# Runs a fixture through the REAL entry point every script in this workflow is launched with, so the
# behaviour under test is the runtime's own binding rather than an in-process call.
function Invoke-Fixture {
    param([string]$Path, [string[]]$Arguments)
    $r = Invoke-NativeCapture -FilePath 'powershell' -Arguments (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Path) + $Arguments)
    $text = ($r.Output | Out-String)
    return [pscustomobject]@{
        ExitCode = $r.ExitCode
        Text     = $text
        # THE SAME TEXT WITH EVERY RUN OF WHITESPACE COLLAPSED. A child PowerShell hard-wraps its own
        # error records at the console width, and it wraps MID-WORD -- the measured capture reads
        # 'matches paramet er name', with the break inside 'parameter'. So no assert here may quote the
        # refusal's sentence, however it is normalized; what it may quote is a token short enough to
        # survive, which is why section 1 keys on the flag name and on the FullyQualifiedErrorId
        # instead. Asserts about a marker the fixture printed itself read Text.
        Flat     = ($text -replace '\s+', ' ')
    }
}

try {
    Write-Host ''
    Write-Host '== 1. the mechanism: a bare param block runs, a bound one refuses ==' -ForegroundColor Cyan

    $bareBody = @'
param(
    [string]$Branch,
    [switch]$Commit
)
Write-Host "RAN-FOR-REAL Branch=[$Branch]"
'@
    $boundBody = "[CmdletBinding()]`r`n" + $bareBody

    $bare = New-Fixture -Name 'bare.ps1' -Body $bareBody
    $bound = New-Fixture -Name 'bound.ps1' -Body $boundBody

    $r = Invoke-Fixture -Path $bare -Arguments @('-DryRun')
    Assert-True ($r.Text -match 'RAN-FOR-REAL') 'a BARE param block runs its body when handed an undeclared -DryRun'
    Assert-Equal 0 $r.ExitCode 'and it exits 0 -- nothing in the run reports that the flag was not understood'

    $r = Invoke-Fixture -Path $bound -Arguments @('-DryRun')
    Assert-True ($r.Text -notmatch 'RAN-FOR-REAL') '[CmdletBinding()] refuses BEFORE the body runs -- the marker never prints'
    Assert-Equal 1 $r.ExitCode 'and it exits 1'
    Assert-True ($r.Flat -match "'DryRun'") 'the refusal NAMES the flag, so the caller can see what was wrong'
    Assert-True ($r.Flat -match 'NamedParameterNotFound') 'and it is the binder that refused -- NamedParameterNotFound, not something the body threw'

    $r = Invoke-Fixture -Path $bound -Arguments @('-Branch', 'x')
    Assert-True ($r.Text -match 'RAN-FOR-REAL Branch=\[x\]') 'a DECLARED parameter still binds normally once the attribute is there'
    Assert-Equal 0 $r.ExitCode 'and a valid call still exits 0'

    Write-Host ''
    Write-Host '== 2. an undeclared flag swallows the value behind it ==' -ForegroundColor Cyan

    $argsBody = @'
param(
    [string]$Branch,
    [switch]$Commit
)
Write-Host "Branch=[$Branch] argsCount=$($args.Count) args=[$($args -join '|')]"
'@
    $argsFix = New-Fixture -Name 'args.ps1' -Body $argsBody

    $r = Invoke-Fixture -Path $argsFix -Arguments @('-Nope', 'foo')
    Assert-True ($r.Text -match 'Branch=\[\]') 'the first declared [string] stays EMPTY -- the flag is NOT bound as its value'
    Assert-True ($r.Text -match 'argsCount=2') 'both tokens land in $args -- so the value behind an unknown flag is swallowed too'

    $r = Invoke-Fixture -Path $argsFix -Arguments @('mybranch', '-Nope')
    Assert-True ($r.Text -match 'Branch=\[mybranch\]') 'a positional value still binds when the unknown flag follows it'

    Write-Host ''
    Write-Host '== 3. the first parameter type is not the axis ==' -ForegroundColor Cyan

    $switchFirstBody = @'
param(
    [switch]$Commit,
    [string]$Branch
)
Write-Host "RAN-FOR-REAL Commit=$Commit"
'@
    $switchFirst = New-Fixture -Name 'switch-first.ps1' -Body $switchFirstBody

    $r = Invoke-Fixture -Path $switchFirst -Arguments @('-DryRun')
    Assert-True ($r.Text -match 'RAN-FOR-REAL') 'a bare param block whose FIRST parameter is a [switch] runs for real too'
    Assert-Equal 0 $r.ExitCode 'so "takes a [string] first" measures nothing -- the attribute is the whole axis'

    Write-Host ''
    Write-Host '== 4. the tree-wide gate: every param block declares it ==' -ForegroundColor Cyan

    $findings = @()
    $checked = 0
    foreach ($dir in @('scripts', 'plugins')) {
        $base = Join-Path $RepoRoot $dir
        if (-not (Test-Path -LiteralPath $base)) { continue }
        Get-ChildItem -Path $base -Recurse -Filter *.ps1 -File | ForEach-Object {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$null)
            if ($null -eq $ast.ParamBlock) { return }
            $script:checked++
            $isBound = @($ast.ParamBlock.Attributes | Where-Object { $_.TypeName.Name -eq 'CmdletBinding' }).Count -gt 0
            if (-not $isBound) {
                $rel = $_.FullName.Substring($RepoRoot.Length + 1)
                $script:findings += "$rel line $($ast.ParamBlock.Extent.StartLineNumber)"
            }
        }
    }

    Assert-True ($checked -gt 0) "the gate actually walked the tree ($checked files with a top-level param block)"
    if ($findings.Count -gt 0) {
        Write-Host '  a param block with no [CmdletBinding()] accepts any flag and runs for real (issue #2092):' -ForegroundColor Red
        $findings | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    }
    # No count of exceptions is named because there are none, and there is deliberately no list to
    # name -- see the banner.
    Assert-Equal 0 $findings.Count 'every .ps1 with a top-level param block declares [CmdletBinding()]'
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
