<#
.SYNOPSIS
    Tests for Invoke-TestSuiteGate in scripts/lib/native-capture-lib.ps1 -- the gate open-pr.ps1,
    cut-release.ps1 and CI all run.

.DESCRIPTION
    The function had wiring-level coverage only: cut-release-guardrail.tests.ps1 asserts that both release
    scripts CALL it and that it is defined once. Nothing asserted what it DOES, which was tolerable while
    it was a fifteen-line foreach and stopped being tolerable on August 7, 2026, when issue #512 turned it
    into a throttled parallel scheduler. Three of its properties can now break silently:

      1. IT MUST ACTUALLY RUN THEM IN PARALLEL. A scheduler with an off-by-one that leaves the throttle at
         1 is indistinguishable from the old loop except by how long the run takes, and a gate that quietly
         went back to sequential would be read as "the machine is busy today". Proven by OVERLAP rather
         than by the clock -- see the comment above case 4, which is where the first version of this suite
         went wrong and had to be repaired against CI rather than against a local run.
      2. ATTRIBUTION MOVED FROM POSITION TO HEADER. Sequentially, a suite's output followed its own
         '== name ==' line because nothing else could be printed in between. In parallel that is only true
         because each child's output is buffered to its own files and flushed as one block. An interleaving
         bug produces output that still LOOKS right -- 26 headers, all the lines present -- with the lines
         under the wrong headers, which is worse than no attribution at all.
      3. THE CHILD'S WORKING DIRECTORY. Start-Process starts a child in [Environment]::CurrentDirectory,
         which does not follow Set-Location, so dropping -WorkingDirectory would hand every suite a
         different vantage point than '& powershell -File' did. roster-sync.tests.ps1 asserts against the
         tree it runs in and would go red for a reason nobody would look for in this file.

    WHY EVERY CASE GOES THROUGH A CHILD PROCESS. The gate reports through Write-Host, which writes to the
    host and never enters the pipeline -- an in-process '$out = Invoke-TestSuiteGate ...' would capture the
    return value and NOT one line of the output these assertions are about, so every assertion on that
    output would pass by being unable to see anything (Sylvester's lens, July 29, 2026). The driver script
    below dot-sources the real lib and prints the verdict, and the suite reads it back the way open-pr's
    console does.

    Dependency-free (no Pester), same style as the rest of the suite.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$LibPath  = Join-Path $RepoRoot 'scripts\lib\native-capture-lib.ps1'

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

function Test-Says {
    <# Does captured child output contain this phrase, whatever the console did to it?

       Strips ALL whitespace from both sides. Normalizing '\s+' to a single space -- which this file
       does to the captured text -- repairs a wrap BETWEEN words and does nothing for a wrap INSIDE
       one, and the child's formatter breaks at whatever character sits at the buffer column. Which
       asserts straddle a break is decided by the width, so a green run is not evidence (issue #1512;
       the worked measurement is in verify-resolved-issues.tests.ps1).

       Literal (IndexOf), so a phrase carrying '(', ')', '.', '[' or ']' needs no escaping;
       OrdinalIgnoreCase keeps the case-insensitivity that -match had at these call sites. #>
    param([string]$Text, [string]$Phrase)
    $haystack = ($Text -replace '\s', '')
    $needle = ($Phrase -replace '\s', '')
    return ($haystack.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
}

function Assert-Says {
    param([string]$Text, [string]$Phrase, [string]$Label)
    if (Test-Says -Text $Text -Phrase $Phrase) {
        $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Label`n         wanted to find: '$Phrase'`n         in:             '$Text'" -ForegroundColor Red
    }
}

$Fixture   = Join-Path ([System.IO.Path]::GetTempPath()) "test-suite-gate-test-$PID-$([guid]::NewGuid().ToString('n'))"
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

# THE CAPTURE DIRECTORIES A RED FIXTURE RUN DELIBERATELY LEAVES BEHIND (issue #1636), removed in this
# suite's own finally. They sit outside $Fixture -- the gate names them off ITS process id, not off any
# path a caller hands it -- so the existing teardown cannot reach them, and a suite that proves the gate
# keeps litter must not become the reason the temp folder fills up.
$script:KeptCaptureDirs = @()

function New-FakeSuite {
    param([string]$Dir, [string]$Name, [string]$Body)
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $Dir $Name), $Body, $Utf8NoBom)
}

# Returns the gate's console output as a line array plus how long the run took. The elapsed time is
# measured around the CHILD, so it includes one powershell start-up (~0.2s) on top of the gate itself --
# irrelevant against the multi-second margins the timing cases work with.
function Invoke-Gate {
    param([string]$TestsDir, [int]$MaxParallel = 0, [string]$WorkDir = '', [string]$CommandsFile = '', [int]$ResidentCount = -1,
          [int]$SuiteTimeoutSeconds = 0, [string]$FocusSuite = '', [int]$FocusRepeat = 0)
    # NOT $args: that is an automatic variable holding a function's unbound arguments, and splatting it
    # after assignment is the kind of collision this repo already documents for $script:-owned names.
    $psArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script:Driver, '-TestsDir', $TestsDir, '-MaxParallel', "$MaxParallel")
    # 0 (the default) means "pass nothing", so every existing case still drives the gate through exactly
    # the parameter set it drove before -- which is what makes a regression in those cases a regression in
    # the gate and not in this helper (issues #1941, #1944).
    if ($SuiteTimeoutSeconds -ne 0) { $psArgs += @('-SuiteTimeoutSeconds', "$SuiteTimeoutSeconds") }
    if ($FocusSuite) { $psArgs += @('-FocusSuite', $FocusSuite, '-FocusRepeat', "$FocusRepeat") }
    if ($WorkDir) { $psArgs += @('-WorkDir', $WorkDir) }
    if ($CommandsFile) { $psArgs += @('-CommandsFile', $CommandsFile) }
    # -1 (the default) means "let the real Get-Process answer" -- OS-wide process state is not
    # something this suite controls, so a case that cares about the count stubs it explicitly instead.
    if ($ResidentCount -ge 0) { $psArgs += @('-ResidentCount', "$ResidentCount") }
    # THE CHILD RUNS AT THE TOP LEVEL, WHATEVER THIS SUITE IS RUNNING UNDER -- issue #1717. The gate
    # sets DKJ_TEST_GATE_DEPTH for its children, and THIS SUITE IS ONE OF THEM whenever it runs under
    # the pool: without this, every driver run inherits depth 1 and reports depth 2, while the gate a
    # fixture suite drives reports 3. Measured on #1717's own branch -- nine asserts holding a literal
    # depth passed standalone twice and failed under the 30-lane pool, which is the same class the
    # SetConsoleOutputCP case (inbound #821) is written up for: shared state a fixture must own rather
    # than inherit. Removed rather than pinned to a value, so the driver's depth is the one an operator
    # actually sees on their own gate run.
    $depthHeldByCaller = [Environment]::GetEnvironmentVariable('DKJ_TEST_GATE_DEPTH', 'Process')
    [Environment]::SetEnvironmentVariable('DKJ_TEST_GATE_DEPTH', $null, 'Process')
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $out = & powershell @psArgs 2>&1
    } finally {
        $sw.Stop()
        [Environment]::SetEnvironmentVariable('DKJ_TEST_GATE_DEPTH', $depthHeldByCaller, 'Process')
    }
    $lines = @($out | ForEach-Object { "$_" })
    $text  = ($lines -join "`n")
    return [pscustomobject]@{
        Lines   = $lines
        Text    = $text
        # Write-Host writes its string through untouched, but Write-Warning goes through the formatter,
        # which HARD-WRAPS at the console width of a redirected child -- and a fixture path is long
        # enough that the break lands mid-sentence. The first version of the missing-dir assert failed
        # for exactly that, on a gate that was behaving correctly.
        #
        # .Flat IS FOR READING, NOT FOR MATCHING, and this comment used to claim otherwise ("makes a
        # wrapped line and an unwrapped one read the same"). Collapsing every run of whitespace to one
        # space makes that true of a break BETWEEN words and false of a break INSIDE one, which the
        # formatter produces just as readily -- it breaks at whatever sits at the column. Prose asserts
        # therefore go through Assert-Says, which strips ALL whitespace from both sides (#1512); .Flat
        # stays so a FAILING assert prints one readable line.
        Flat    = ($text -replace '\s+', ' ')
        Seconds = $sw.Elapsed.TotalSeconds
        # The child's own PID, printed by the driver -- issue #1636. It is what makes the two capture
        # cases ask about THIS run rather than about whichever other gate run happens to be alive.
        CapturePid = $(
            $m = [regex]::Match($text, 'GATE-PID:\s*(\d+)')
            if ($m.Success) { $m.Groups[1].Value } else { '' }
        )
        # The capture directory this run LEFT BEHIND, or '' where it left none -- which is the green
        # case's whole assertion. Found rather than composed since #1659: the leaf is
        # "test-suite-gate-<pid>-<guid>" now, so the PID narrows it to this run and nothing else can,
        # while the guid is what a pre-planted junction has no name to sit at. A green run matches zero
        # and a red run exactly one; more than one would mean the PID was reused inside this run's own
        # lifetime, which cannot happen while that process is still alive to print it.
        CaptureDir = $(
            $m = [regex]::Match($text, 'GATE-PID:\s*(\d+)')
            if ($m.Success) {
                $hit = @(Get-ChildItem -LiteralPath ([System.IO.Path]::GetTempPath()) -Directory `
                                       -Filter ("test-suite-gate-" + $m.Groups[1].Value + "-*") -ErrorAction SilentlyContinue)
                if ($hit.Count -eq 1) { $hit[0].FullName } else { '' }
            } else { '' }
        )
    }
}

# Folds PowerShell backtick continuations into one logical statement, so a scan judges a statement
# rather than a physical line. Issue #1326: a fixture path whose discriminator ($PID, a fresh GUID)
# sits after a `-continuation is still per-process, but a physical-line scan reads only its first line
# and reports a correct path as an offender. A line whose last non-whitespace character is a backtick
# is glued to the next -- exactly how the parser treats it -- and the returned object keeps the
# STARTING physical line number so an offender is still named at a place you can open.
function Join-BacktickContinuation {
    param([string[]]$Lines)
    $out = New-Object System.Collections.Generic.List[pscustomobject]
    $i = 0
    while ($i -lt $Lines.Count) {
        $start = $i + 1
        $stmt  = $Lines[$i]
        while ($stmt -match '`[ \t]*$' -and ($i + 1) -lt $Lines.Count) {
            $i++
            $stmt = ($stmt -replace '`[ \t]*$', ' ') + $Lines[$i].Trim()
        }
        $i++
        $out.Add([pscustomobject]@{ Line = $start; Text = $stmt })
    }
    ,$out
}

function Get-FakeFreshAssignment {
    <#
        Every place a suite gives one of the "holds a fresh value" variable names a value that is NOT a
        fresh guid of usable width. Returns 'file:line' strings, empty when the file is clean.

        WHY THIS READS THE PARSED SYNTAX AND NOT THE LINE TEXT. The rule above accepts '$tag' in a fixture
        path BY NAME, so this is the check that makes the name mean something -- and a start-of-line regex
        was the first shape, which Sebastian broke three ways on the branch that introduced it (#1664):

            param([string]$tag = 'fixed-value')       a parameter default -- idiomatic, and not an
                                                      assignment statement at all
            if (-not $tag) { $tag = 'literal' }       an assignment inside a one-line block
            $x = 1; $tag = 'literal'                  a semicolon-joined statement

        None of the three starts its physical line with the assignment, so none was seen, while the outer
        rule went on calling the resulting path safe because the text '$tag' appeared on it. That is the
        same class of defect this tree has twice repaired elsewhere by moving a guard onto the AST -- see
        source-repo-guard.tests.ps1, where a whole-file match on a lib's NAME could not tell loading it
        from talking about it. The parser has no start-of-line notion, so all three forms are ordinary
        nodes to it and the evasions are not evasions.

        AND THE WIDTH IS BOUNDED, because 'contains NewGuid' is not the same claim as 'is unguessable'.
        [Guid]::NewGuid().ToString('N').Substring(0, 1) names a guid and yields four bits, which a
        neighbour pre-plants sixteen times. The two real call sites take 8 hex characters (32 bits), which
        is far beyond a blind local pre-plant, so the floor sits there rather than at the full 32.

        THE NAME IS READ FROM UserPath AND THE SCOPE STRIPPED HERE, not from UnqualifiedPath, which is the
        property that obviously ought to serve and returns an EMPTY STRING on Windows PowerShell 5.1 --
        measured on this machine, 5.1.26100.9278, for '$tag', '$script:tag' and '[string]$Guid' alike. The
        first version of this function used it and therefore matched nothing at all: every one of the six
        cases below reported 0, while the AST walk around it was already correct. It is worth naming
        because the failure is silent in the dangerous direction -- a guard that finds nothing looks
        exactly like a tree with nothing to find, and the only reason it was caught is that these cases
        assert a positive count rather than merely asserting the suite stays green.
    #>
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string[]]$Names)

    $MinHexWidth = 8
    $found = @()
    $leaf  = Split-Path -Leaf $Path

    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    # A suite that does not parse is a separate, louder problem than this one, and every suite in this
    # tree parses (the gate runs them). Returning nothing is right: reporting a parse error here would
    # attribute it to the fixture convention.
    if ($errors -and $errors.Count) { return $found }

    # UserPath carries the scope ('script:tag'); take what follows the last colon. Empty for a plain name.
    function Get-BareVarName {
        param($VariablePath)
        $u = "$($VariablePath.UserPath)"
        if ($u -match '^[A-Za-z]+:(.*)$') { return $Matches[1] }
        return $u
    }

    function Test-FreshEnough {
        param($ValueAst, [int]$MinWidth)
        if ($null -eq $ValueAst) { return $false }
        $text = $ValueAst.Extent.Text
        if ($text -notmatch 'NewGuid') { return $false }
        # A truncation narrows it; anything else keeps the full guid.
        foreach ($m in [regex]::Matches($text, 'Substring\(\s*\d+\s*,\s*(\d+)\s*\)')) {
            if ([int]$m.Groups[1].Value -lt $MinWidth) { return $false }
        }
        return $true
    }

    # (a) ordinary assignments -- wherever they sit: inside a block, after a semicolon, in a loop body.
    foreach ($node in $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true)) {
        $left = $node.Left
        # '$tag = ...' and '[string]$tag = ...' both reach the variable through a convert expression.
        while ($left -is [System.Management.Automation.Language.ConvertExpressionAst]) { $left = $left.Child }
        if ($left -isnot [System.Management.Automation.Language.VariableExpressionAst]) { continue }
        if ($Names -notcontains (Get-BareVarName -VariablePath $left.VariablePath)) { continue }
        if (Test-FreshEnough -ValueAst $node.Right -MinWidth $MinHexWidth) { continue }
        $found += ('{0}:{1}' -f $leaf, $node.Extent.StartLineNumber)
    }

    # (b) parameter defaults -- not assignment statements, and the form a regex on '^\s*$tag\s*=' can
    # never see. A default is a value the variable holds whenever the caller omits it.
    foreach ($node in $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.ParameterAst] }, $true)) {
        if ($Names -notcontains (Get-BareVarName -VariablePath $node.Name.VariablePath)) { continue }
        if ($null -eq $node.DefaultValue) { continue }
        if (Test-FreshEnough -ValueAst $node.DefaultValue -MinWidth $MinHexWidth) { continue }
        $found += ('{0}:{1}' -f $leaf, $node.Extent.StartLineNumber)
    }

    return $found
}

try {
    Write-Host "== test-suite-gate.tests: the gate every PR and every release runs ==" -ForegroundColor Cyan
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture }
    New-Item -ItemType Directory -Path $Fixture -Force | Out-Null

    # --- 0. The elapsed figure is formatted INVARIANTLY (issue #1159) ------------------------------
    #
    # '-f' formats in the current culture: on a Dutch machine '{0:N0}' renders 2182 as '2.182', which an
    # English reader of this repo reads as 2.182 seconds -- a factor of a thousand off and still
    # plausible. It only misformats above 1000s, i.e. exactly the slow runs worth noticing, so a bare
    # -f went unnoticed for the gate's whole life. Format-GateSeconds routes through InvariantCulture;
    # this asserts it under nl-NL, where a regression would go green in en-US (measure-skill's lesson).
    Write-Host "the elapsed figure does not shift meaning with the operator's locale" -ForegroundColor Cyan
    . $LibPath
    $prevCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
    try {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('nl-NL')
        Assert-Equal '2,182' (Format-GateSeconds 2182.4) 'Format-GateSeconds: 2182s is 2,182 even under nl-NL (not 2.182)'
        Assert-Equal '249'   (Format-GateSeconds 249)    'Format-GateSeconds: a sub-1000 figure carries no separator'
        Assert-Equal '0'     (Format-GateSeconds 0.4)    'Format-GateSeconds: rounds to whole seconds'
        # -Decimals arrived with the per-suite table (#1358), where most suites finish under a second and
        # a column of '0s' rows records nothing. Asserted under nl-NL for the same reason as the rows
        # above: there the decimal separator is a COMMA, so a culture leak would print '1,2' and an
        # English reader gets a thousands separator instead of a decimal point -- #1159's defect one digit
        # further down. The default must stay 0, because every pre-#1358 caller relies on it.
        Assert-Equal '1.2'   (Format-GateSeconds 1.24 -Decimals 1) 'Format-GateSeconds: -Decimals 1 keeps the invariant DOT under nl-NL'
        Assert-Equal '2,182.4' (Format-GateSeconds 2182.44 -Decimals 1) 'Format-GateSeconds: and still groups thousands invariantly'
        Assert-Equal '0'     (Format-GateSeconds 0.4)    'Format-GateSeconds: the default is unchanged -- whole seconds'
    } finally {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = $prevCulture
    }

    # The driver dot-sources the REAL lib -- not a copy. A fixture copy would let the lib change without
    # this suite noticing, which is the whole failure mode it exists to catch.
    $script:Driver = Join-Path $Fixture 'drive-gate.ps1'
    $driverBody = @"
param([string]`$TestsDir, [int]`$MaxParallel = 0, [string]`$WorkDir = '', [string]`$CommandsFile = '', [int]`$ResidentCount = -1,
      [int]`$SuiteTimeoutSeconds = 0, [string]`$FocusSuite = '', [int]`$FocusRepeat = 0)
`$ErrorActionPreference = 'Stop'
. '$LibPath'
if (`$WorkDir) { Set-Location -LiteralPath `$WorkDir }
# Models a consumer's repo-config defining the optional seam: the gate reads it via Get-Command, the
# way open-pr and cut-release have it in scope after their own dot-source of repo-config.ps1.
if (`$CommandsFile) {
    `$script:GateCommands = @(Get-Content -LiteralPath `$CommandsFile)
    function Get-TestCommands { return `$script:GateCommands }
}
# Shadows the real OS query (issue #1464): redefining the function AFTER the dot-source above wins,
# because a fixture cannot control how many powershell.exe processes are actually on this machine.
if (`$ResidentCount -ge 0) {
    `$script:GateResidentCount = `$ResidentCount
    function Get-ResidentPowerShellCount { return `$script:GateResidentCount }
}
# THE CHILD'S OWN PID, printed so the retention cases (issue #1636) can find the capture directory of
# THIS run rather than diffing the temp folder for one. \$captureDir is "test-suite-gate-\$PID-<guid>"
# (New-ScratchPath, #1659) of the process that runs the gate, which is this child -- the guid is why the
# driver cannot compose the path, and the PID is why a search for it cannot be answered by whichever
# other gate run happened to be alive, this suite's own outer gate included.
Write-Host "GATE-PID: `$PID"
# SPLATTED, so the two newer parameters are only ever PASSED when a case asked for them -- an explicit
# -SuiteTimeoutSeconds 0 means "resolve the module default" and is not the same call as omitting it
# (issues #1941, #1944). A refusal is caught and printed rather than thrown, because these cases assert on
# what the gate SAYS and a driver that died would report nothing at all.
`$gateArgs = @{ TestsDir = `$TestsDir; Context = 'the fixture'; MaxParallel = `$MaxParallel }
if (`$SuiteTimeoutSeconds -ne 0) { `$gateArgs['SuiteTimeoutSeconds'] = `$SuiteTimeoutSeconds }
if (`$FocusSuite) { `$gateArgs['FocusSuite'] = `$FocusSuite; `$gateArgs['FocusRepeat'] = `$FocusRepeat }
try {
    `$r = Invoke-TestSuiteGate @gateArgs
    Write-Host "GATE-RESULT: `$r"
} catch {
    Write-Host "GATE-REFUSED: `$(`$_.Exception.Message)"
}
"@
    [System.IO.File]::WriteAllText($script:Driver, $driverBody, $Utf8NoBom)

    # --- 1. The empty-input contract: a repo without suites is not a failing repo -------------------
    Write-Host "the two empty cases -- nothing to run is not a red gate" -ForegroundColor Cyan
    $missing = Join-Path $Fixture 'no-such-dir'
    $r = Invoke-Gate -TestsDir $missing
    Assert-True ($r.Text -match 'GATE-RESULT: True') 'a missing tests dir returns true'
    Assert-Says $r.Flat 'test gate skipped' 'and says so instead of passing in silence'

    $empty = Join-Path $Fixture 'empty-suites'
    New-Item -ItemType Directory -Path $empty -Force | Out-Null
    $r = Invoke-Gate -TestsDir $empty
    Assert-True ($r.Text -match 'GATE-RESULT: True') 'a dir with no suites returns true'
    Assert-Says $r.Flat 'had nothing to run' 'and says that too'

    # --- 2. All-pass: the count, the filter, the blocks, the summary --------------------------------
    Write-Host "an all-passing run -- attribution comes from the header, not the position" -ForegroundColor Cyan
    $ok = Join-Path $Fixture 'suites-ok'
    New-FakeSuite -Dir $ok -Name 'a-first.tests.ps1'  -Body "Write-Host 'MARKER-A'`r`nexit 0`r`n"
    New-FakeSuite -Dir $ok -Name 'b-second.tests.ps1' -Body "Write-Host 'MARKER-B'`r`nexit 0`r`n"
    # Writes on BOTH streams. Start-Process cannot redirect stdout and stderr to one file, so the two are
    # captured apart and printed one after the other -- a suite whose only diagnostic went to stderr would
    # otherwise vanish, and the gate would report a failure with no visible reason.
    New-FakeSuite -Dir $ok -Name 'c-noisy.tests.ps1'  -Body "Write-Host 'MARKER-C'`r`n[Console]::Error.WriteLine('STDERR-MARKER-C')`r`nexit 0`r`n"
    # Not a suite: pins the *.tests.ps1 filter, which the count line would otherwise report as 4.
    New-FakeSuite -Dir $ok -Name 'helper.ps1'         -Body "Write-Host 'MARKER-HELPER'`r`nexit 1`r`n"

    $r = Invoke-Gate -TestsDir $ok
    Assert-True ($r.Text -match 'GATE-RESULT: True') 'three passing suites: the gate returns true'
    Assert-True ($r.Text -match 'running all 3 test suites for the fixture') 'the count names 3 -- helper.ps1 is not a suite'
    Assert-True ($r.Text -notmatch 'MARKER-HELPER') 'and it was never run'
    Assert-True ($r.Text -match 'test gate: all 3 suites passed in \d') 'the summary states the verdict and the elapsed time'
    # THE LANE COUNT IS ON THE SUMMARY LINE (issue #1318). The count line at :674 already carried it, but
    # nobody quotes that line -- the summary is the one that reaches a branch doc or a changelog entry, and
    # the seconds without the lanes are a draw from a 4.5x spread. The number is the resolved $MaxParallel
    # (clamped to the suite count here), so it is machine-dependent -- assert its shape, not its value.
    Assert-True ($r.Text -match 'test gate: all 3 suites passed in \d+s \(\d+ lanes?\)\.') 'the summary names the lane count the seconds depend on'

    # THE ATOMIC-BLOCK ASSERT. Not "both lines are present somewhere" -- an interleaving bug satisfies
    # that. Each marker must sit on the line directly after its OWN header, which is exactly the property
    # buffering per child buys and the property a switch back to live streaming would lose.
    foreach ($pair in @(
        @{ Suite = 'a-first.tests.ps1';  Marker = 'MARKER-A' },
        @{ Suite = 'b-second.tests.ps1'; Marker = 'MARKER-B' },
        @{ Suite = 'c-noisy.tests.ps1';  Marker = 'MARKER-C' }
    )) {
        $h = [Array]::IndexOf($r.Lines, "== $($pair.Suite) ==")
        Assert-True ($h -ge 0) "$($pair.Suite): its header is printed"
        Assert-True ($h -ge 0 -and $r.Lines[$h + 1] -eq $pair.Marker) "$($pair.Suite): its own output is the very next line"
    }
    $hc = [Array]::IndexOf($r.Lines, '== c-noisy.tests.ps1 ==')
    Assert-True ($hc -ge 0 -and $r.Lines[$hc + 2] -eq 'STDERR-MARKER-C') 'a suite stderr line lands inside that same block, right behind its stdout'

    # A GREEN RUN KEEPS NOTHING -- the half of #1636 that must not regress into litter. The retention is
    # for evidence of a failure, so a passing gate has to leave the temp folder exactly as it found it.
    Assert-True ($r.CapturePid -ne '') 'the driver reported its own PID, so this run''s capture directory is findable'
    Assert-True ($r.CaptureDir -eq '') 'a green run deletes its capture directory -- no litter'
    Assert-True ($r.Flat -notmatch 'output kept at') 'and says nothing about kept output'

    # --- 3. A failing suite: the exit code, the marked header, the named summary --------------------
    Write-Host "a failing run -- the verdict must survive 25 green siblings" -ForegroundColor Cyan
    $bad = Join-Path $Fixture 'suites-bad'
    New-FakeSuite -Dir $bad -Name 'a-first.tests.ps1' -Body "Write-Host 'MARKER-A'`r`nexit 0`r`n"
    New-FakeSuite -Dir $bad -Name 'z-broken.tests.ps1' -Body "Write-Host 'MARKER-Z'`r`nexit 3`r`n"

    $r = Invoke-Gate -TestsDir $bad
    Assert-True ($r.Text -match 'GATE-RESULT: False') 'one failing suite fails the whole gate'
    Assert-True ($r.Text -match '== z-broken\.tests\.ps1 == FAILED \(exit 3\)') 'its header carries the failure AND the real exit code'
    Assert-True ($r.Text -match '== a-first\.tests\.ps1 ==\r?\n') 'the passing sibling keeps its plain header'
    Assert-True ($r.Text -match 'test gate: 1 of 2 suites FAILED in \d+s \(\d+ lanes?\): z-broken\.tests\.ps1') 'and the closing summary carries the lane count and names it (issue #1318 -- the red line too)'
    Assert-True ($r.Text -match 'MARKER-Z') 'the failing suite still prints its own output -- attributable without a second run'

    # A RED RUN KEEPS THE FAILING SUITE'S CAPTURE, AND ONLY THAT SUITE'S -- issue #1636. The console block
    # asserted on the line above was always printed; what was missing is a second copy that survives a pipe
    # through 'tail', a scrollback limit or a truncated CI log. So three things are asserted: the directory
    # is still there, it holds the FAILING suite's stdout with its marker in it, and it does NOT hold the
    # passing sibling's -- otherwise a red run over 79 suites leaves 78 files of green noise behind.
    # A STAND-IN WHERE NOTHING WAS FOUND, so a regression here FAILS the asserts below instead of
    # throwing on Test-Path/Join-Path with an empty string and taking the rest of this suite with it.
    if (-not $r.CaptureDir) { $r.CaptureDir = Join-Path $Fixture 'no-capture-directory-was-kept' }
    $script:KeptCaptureDirs += $r.CaptureDir
    Assert-True (Test-Path -LiteralPath $r.CaptureDir) 'a red run KEEPS its capture directory'
    Assert-Says $r.Flat "output kept at $($r.CaptureDir)" 'and the verdict names the path, the line a session copies'
    $keptZ = Join-Path $r.CaptureDir 'z-broken.tests.out.txt'
    Assert-True (Test-Path -LiteralPath $keptZ) "the failing suite's stdout capture survives"
    Assert-True ((Test-Path -LiteralPath $keptZ) -and ((Get-Content -LiteralPath $keptZ -Raw) -match 'MARKER-Z')) 'and it holds what the console printed'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $r.CaptureDir 'a-first.tests.out.txt'))) 'the passing sibling''s capture is deleted -- only the evidence is kept'
    # The empty half of the failing pair goes too: z-broken writes no stderr, so keeping a 0-byte
    # .err.txt would only pad a directory the verdict line has just recommended reading.
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $r.CaptureDir 'z-broken.tests.err.txt'))) 'and an empty capture file is not kept either'

    # --- 4. It really is parallel, and -MaxParallel 1 really is the way back ------------------------
    #
    # ASSERTED ON OVERLAP, NOT ON THE CLOCK -- and the first version of this suite got that wrong in a way
    # worth keeping written down. It asserted that six 2s suites finish "well under" their 12s serial sum,
    # which passed locally at 2.8s and FAILED IN CI at 9.3s: a four-core runner, this suite itself running
    # alongside three others, and six Start-Process launches competing with all of it. The ratio assert
    # that was supposed to be the load-independent backstop failed with it, because an inflated parallel
    # figure sits in its denominator.
    #
    # THE RULE THAT FALLS OUT OF IT: a timing FLOOR is a testable property, because Start-Sleep guarantees
    # it; a timing CEILING is not, because nothing bounds how slow a shared machine can be. So the question
    # "did these run at the same time?" is answered by asking whether their lifetimes OVERLAP, which is
    # what the word means and is immune to how long each one took. Each fake suite stamps its own start and
    # end; parallel must produce at least one intersecting pair, serial exactly none. That is a stronger
    # claim than any stopwatch bound, and it let the sleeps shrink from 2s to 1.2s.
    Write-Host "the point of the exercise -- do the suites overlap in time, or queue behind each other" -ForegroundColor Cyan
    $slow   = Join-Path $Fixture 'suites-slow'
    $stamps = Join-Path $Fixture 'stamps'
    New-Item -ItemType Directory -Path $stamps -Force | Out-Null
    1..6 | ForEach-Object {
        $body = "`$s = [DateTime]::UtcNow.Ticks`r`n" +
                "Start-Sleep -Milliseconds 1200`r`n" +
                "Set-Content -LiteralPath '$stamps\s$_.txt' -Value (`"`$s `" + [DateTime]::UtcNow.Ticks) -Encoding Ascii`r`n" +
                "Write-Host 'SLEPT-$_'`r`nexit 0`r`n"
        New-FakeSuite -Dir $slow -Name "s$_.tests.ps1" -Body $body
    }

    # Counts pairs of [start,end] intervals that intersect. Reads the stamp files the fake suites wrote.
    function Get-OverlapCount {
        param([string]$StampDir)
        $iv = @(Get-ChildItem -Path $StampDir -Filter '*.txt' -File | ForEach-Object {
            $parts = (Get-Content -LiteralPath $_.FullName -Raw).Trim() -split '\s+'
            [pscustomobject]@{ Start = [long]$parts[0]; End = [long]$parts[1] }
        })
        $n = 0
        for ($a = 0; $a -lt $iv.Count; $a++) {
            for ($b = $a + 1; $b -lt $iv.Count; $b++) {
                if ($iv[$a].Start -lt $iv[$b].End -and $iv[$b].Start -lt $iv[$a].End) { $n++ }
            }
        }
        return $n
    }

    $par = Invoke-Gate -TestsDir $slow
    Assert-True ($par.Text -match 'GATE-RESULT: True') 'all six slow suites pass'
    Assert-Equal 6 (@($par.Lines | Where-Object { $_ -match '^SLEPT-\d$' }).Count) 'and all six actually ran'
    Assert-Equal 6 (@(Get-ChildItem -Path $stamps -Filter '*.txt' -File).Count) 'and all six stamped their own lifetime'
    $parOverlap = Get-OverlapCount -StampDir $stamps
    Assert-True ($parOverlap -ge 1) "their lifetimes overlap -- they ran at the same time ($parOverlap intersecting pair(s) of 15)"

    Get-ChildItem -Path $stamps -Filter '*.txt' -File | Remove-Item -Force
    $ser = Invoke-Gate -TestsDir $slow -MaxParallel 1
    Assert-True ($ser.Text -match 'GATE-RESULT: True') '-MaxParallel 1 still passes them'
    Assert-Says $ser.Flat 'one at a time' 'and says which mode it is in'
    # -MaxParallel 1 is the one deterministic lane count, so it is the one the summary can be asserted on
    # exactly: singular 'lane', not 'lanes' (issue #1318).
    Assert-True ($ser.Text -match 'test gate: all 6 suites passed in \d+s \(1 lane\)\.') 'the summary says one lane, singular, when the valve is closed'
    Assert-Equal 0 (Get-OverlapCount -StampDir $stamps) 'serially NOTHING overlaps -- the valve really queues them'
    # The one timing assert that is safe, because it is a floor the sleeps guarantee: six 1.2s suites in
    # sequence cannot come in under 7.2s of sleeping, however fast the machine is.
    Assert-True ($ser.Seconds -ge 6) "and it costs their sum (took $([math]::Round($ser.Seconds,1))s)"

    # --- 4b. The per-suite table records a DURATION, not a finish time (issue #1358) ----------------
    #
    # THIS IS THE ASSERT THAT WOULD HAVE CAUGHT THE DEFECT. The gate used to time only the pool, and it
    # buffers a suite's output until that suite exits -- so the only per-suite figure derivable from a log
    # was a FINISH time, and subtracting the pool's start from it is a duration only for a suite that
    # started at t0. A five-file plateau reported off the real pool turned out to have four members
    # because the method was extended to two suites sitting 5th and 9th in a 4-lane queue.
    #
    # THE SERIAL RUN IS THE PERFECT DISCRIMINATOR and it is why this rides scenario 4's fixture rather
    # than building its own: with -MaxParallel 1, suite six starts around +6s and runs for ~1.2s. A
    # duration column holding finish times would read ~7.2s for it. So the two readings differ by 6x
    # here, which no timing noise can bridge -- and the assert is a FLOOR on the largest offset plus a
    # comparison of the largest duration AGAINST that offset, which together say "these are runtimes and
    # the queueing really happened".
    Write-Host "per-suite durations are recorded, and a queued suite is not charged for its wait" -ForegroundColor Cyan
    $rows = @($ser.Lines | ForEach-Object {
        if ($_ -match '^\s+([\d.,]+)s\s+(\S+\.tests\.ps1)\s+started \+([\d.,]+)s') {
            [pscustomobject]@{
                Duration = [double](($matches[1] -replace ',', ''))
                Name     = $matches[2]
                Offset   = [double](($matches[3] -replace ',', ''))
                Makespan = ($_ -match 'set the makespan')
            }
        }
    })
    Assert-Equal 6 $rows.Count 'the table carries one row per suite'
    Assert-Says $ser.Flat 'per-suite durations, slowest first' 'and says what it is and how it is ordered'
    Assert-Says $ser.Flat 'recorded, not reconstructed' 'and that it is recorded rather than derived from timestamps'

    $maxOffset = ($rows | Measure-Object -Property Offset -Maximum).Maximum
    Assert-True ($maxOffset -ge 5) "serially the last lane really opened late (largest offset +$([math]::Round($maxOffset,1))s)"
    $maxDuration = ($rows | Measure-Object -Property Duration -Maximum).Maximum
    # THE COMPARISON IS AGAINST THE QUEUE, NOT AGAINST A SECOND-COUNT (issue #1401). This read
    # `$maxDuration -lt 4` until September 4, 2026 -- and a 4s ceiling is the very thing the rule at the
    # top of this scenario forbids: a timing FLOOR is guaranteed by Start-Sleep, a timing CEILING is
    # guaranteed by nothing, because nothing bounds how slow a shared machine can be. Measured: one of
    # these 1.2s sleeps came in at 5.1s during a 65-suite gate run and the gate refused the push, for a
    # race the branch under test had no part in; standalone on the same tree, moments later, 3.3s.
    #
    # WIDENING THE CEILING WAS THE OBVIOUS REPAIR AND IS THE WRONG ONE. It keeps the fragile shape, and it
    # discriminates WORSE the more load there is: contention inflates the defect's reading too, so the gap
    # a fixed number has to sit inside moves out from under it. 6-7s also lands within noise of the ~7.2s
    # a finish-time column would report at rest, which is the one figure this assert must stay below.
    #
    # WHAT IS LOAD-INVARIANT IS THE RATIO THE FIXTURE ITSELF BUILDS. Serially the last lane opens only
    # after the five before it have run, so $maxOffset is the SUM of five runtimes while a true duration is
    # ONE of them -- the same 6x gap, now expressed as a comparison rather than as a constant. A duration
    # column holding finish times reads offset + runtime for that row, which exceeds $maxOffset BY
    # CONSTRUCTION, whatever the machine was doing. Contention scales both sides together, so this survives
    # a loaded box in a way no second-count can, and it still FAILS for the defect it was written to catch.
    Assert-True ($maxDuration -lt $maxOffset) "yet NO row is charged for that wait -- the largest duration ($([math]::Round($maxDuration,1))s) is one runtime, still under the last lane's own wait (+$([math]::Round($maxOffset,1))s), where a finish time would have to exceed it"

    # Sorted slowest first, which is the whole reason to print it: the makespan-setter is findable.
    $sortedDesc = $true
    for ($i = 1; $i -lt $rows.Count; $i++) { if ($rows[$i].Duration -gt $rows[$i - 1].Duration + 0.001) { $sortedDesc = $false } }
    Assert-True $sortedDesc 'the rows are ordered slowest first'

    # Exactly one, because it is the claim '#714 proved: only the last-finishing suite's cost moves the
    # pool's total. Two markers would mean the comparison is against the wrong end.
    Assert-Equal 1 (@($rows | Where-Object { $_.Makespan }).Count) 'exactly one row is marked as having set the makespan'
    Assert-Says $ser.Flat 'a late start is lane wait, not runtime' 'the header warns the reader what the offset is, since that is the trap'

    # --- 5. The working directory the child is handed ----------------------------------------------
    Write-Host "-WorkingDirectory -- the child inherits PowerShell's location, not the process's" -ForegroundColor Cyan
    # THIS CASE ONLY PROVES ANYTHING BECAUSE THE TWO DIFFER. The driver starts in whatever directory this
    # suite was launched from and then Set-Location's into $wdHome, which moves PowerShell's location and
    # leaves [Environment]::CurrentDirectory where it was. A gate that omitted -WorkingDirectory would
    # report the launch directory here and pass every other assert in this file.
    $wdHome   = Join-Path $Fixture 'wd-home'
    $wdSuites = Join-Path $Fixture 'wd-suites'
    New-Item -ItemType Directory -Path $wdHome -Force | Out-Null
    New-FakeSuite -Dir $wdSuites -Name 'cwd.tests.ps1' -Body "Write-Host ('CWD:' + (Get-Location).Path)`r`nexit 0`r`n"
    $r = Invoke-Gate -TestsDir $wdSuites -WorkDir $wdHome
    $reported = @($r.Lines | Where-Object { $_ -match '^CWD:' } | ForEach-Object { $_.Substring(4) })
    Assert-Equal 1 $reported.Count 'the probe suite reported its location'
    Assert-Equal $wdHome $reported[0] 'the suite ran in the gate caller''s location, not in the process working directory'

    # --- 6. Get-TestCommands: the repo's own commands join the gate (inbound #644) -------------------
    #
    # The seam is read INSIDE the gate via Get-Command, so the driver models a consumer by defining the
    # function before the call -- exactly what open-pr/cut-release's dot-source of repo-config.ps1 does.
    # The exit-code case uses cmd /c exit 7, a NATIVE exit code: the child powershell must propagate it
    # rather than report its own did-it-parse verdict, which is what the trailing 'exit $LASTEXITCODE'
    # buys and what this assert would catch losing.
    Write-Host "Get-TestCommands -- a consumer's own test commands run and are judged like suites" -ForegroundColor Cyan
    $cmdOk = Join-Path $Fixture 'commands-ok.txt'
    [System.IO.File]::WriteAllText($cmdOk, "Write-Host 'CMD-MARKER-OK'`r`n", $Utf8NoBom)
    $r = Invoke-Gate -TestsDir $ok -CommandsFile $cmdOk
    Assert-True ($r.Text -match 'GATE-RESULT: True') 'three suites plus a passing command: the gate returns true'
    Assert-Says $r.Flat 'running 1 repo test command' 'and it announces the command half separately'
    Assert-True ($r.Text -match 'CMD-MARKER-OK') 'the command''s own output is printed'
    Assert-True ($r.Text -match 'test gate: all 4 suites passed in \d+s \(\d+ lanes?\)\.') 'the summary counts the command with the suites and still names the lane count (issue #1318)'

    $cmdBad = Join-Path $Fixture 'commands-bad.txt'
    [System.IO.File]::WriteAllText($cmdBad, "cmd /c exit 7`r`n", $Utf8NoBom)
    $r = Invoke-Gate -TestsDir $ok -CommandsFile $cmdBad
    Assert-True ($r.Text -match 'GATE-RESULT: False') 'a failing command fails the whole gate'
    Assert-True ($r.Text -match '== cmd /c exit 7 == FAILED \(exit 7\)') 'its header carries the NATIVE exit code, propagated through the child'
    Assert-True ($r.Text -match 'test gate: 1 of 4 suites FAILED in \d+s \(\d+ lanes?\): cmd /c exit 7') 'and the closing summary carries the lane count and names the command'

    # A repo whose whole suite is Get-TestCommands: no scripts\tests at all, and the gate still runs.
    $r = Invoke-Gate -TestsDir (Join-Path $Fixture 'no-such-dir') -CommandsFile $cmdOk
    Assert-True ($r.Text -match 'GATE-RESULT: True') 'commands-only: a missing suites dir does not skip the gate'
    Assert-True ($r.Flat -notmatch 'test gate skipped') 'and it does not claim to have skipped'
    Assert-True ($r.Text -match 'test gate: all 1 suites passed in \d') 'the verdict counts the one command'
    # THE EDGE THE LANE NOTE HAS TO RESPECT (issue #1318): a commands-only gate never resolves $MaxParallel
    # -- its commands run one at a time -- so there is no pool count to state and the summary carries none.
    Assert-True ($r.Flat -notmatch 'test gate: all 1 suites passed in \d+s \(') 'a commands-only gate states no lane count -- the pool never ran'

    # The two silent-success shapes the judging suffix exists to close (found in review). A bare
    # 'exit $LASTEXITCODE' coerced both to exit 0: the pure-PowerShell failure sets no native exit
    # code at all, and the unterminated quote swallowed the suffix into its own string literal.
    $cmdPsFail = Join-Path $Fixture 'commands-psfail.txt'
    [System.IO.File]::WriteAllText($cmdPsFail, "Write-Error 'red but native-exit-code-less'`r`n", $Utf8NoBom)
    $r = Invoke-Gate -TestsDir $ok -CommandsFile $cmdPsFail
    Assert-True ($r.Text -match 'GATE-RESULT: False') 'a pure-PowerShell failure with no native exit code still fails the gate'

    $cmdNoParse = Join-Path $Fixture 'commands-noparse.txt'
    [System.IO.File]::WriteAllText($cmdNoParse, "Write-Host `"unterminated`r`n", $Utf8NoBom)
    $r = Invoke-Gate -TestsDir $ok -CommandsFile $cmdNoParse
    Assert-True ($r.Text -match 'GATE-RESULT: False') 'a command that does not parse is refused, not run truncated'
    Assert-True ($r.Text -match 'FAILED \(does not parse') 'and the header says why'

    # --- 7. The resident-powershell warning (issue #1464) -------------------------------------------
    #
    # A killed run's Start-Process children outlive it, and this suite cannot reproduce that without
    # actually killing a gate mid-run -- so what is asserted is the SIGNAL this function derives from a
    # resident count, not the orphaning itself. The real Get-Process is shadowed (see the driver above)
    # because OS-wide process state is not a fixture's to set, and this is advisory-only: it must never
    # change GATE-RESULT, whichever way the count points.
    Write-Host "the resident-powershell warning -- advisory, and only when the count looks anomalous" -ForegroundColor Cyan
    $r = Invoke-Gate -TestsDir $ok -ResidentCount 3
    Assert-True ($r.Text -match 'GATE-RESULT: True') 'a low resident count: the gate still passes'
    Assert-True ($r.Flat -notmatch 'powershell processes already resident') 'and stays silent about it'

    $r = Invoke-Gate -TestsDir $ok -ResidentCount 25
    Assert-True ($r.Text -match 'GATE-RESULT: True') 'a high resident count: still just a warning -- the gate still passes'
    Assert-Says $r.Flat '25 powershell processes already resident' 'and names the count'
    Assert-Says $r.Flat '-MaxParallel' 'and suggests the same knob the report asked for'

    # The real (unshadowed) path: whatever this machine's own Get-Process says, it must not be able to
    # fail the gate. -ResidentCount is omitted entirely here (Invoke-Gate's -1 default), so the driver
    # never defines the shadow and Get-ResidentPowerShellCount runs its real Get-Process body.
    $r = Invoke-Gate -TestsDir $ok
    Assert-True ($r.Text -match 'GATE-RESULT: True') 'the real, unshadowed resident-count path still passes suites'

    # --- 8. A CRASHED suite is not a FAILED one (issue #1723) ---------------------------------------
    #
    # WHAT WENT WRONG. The gate judged a suite on its exit code alone, so a child killed by an
    # unhandled AccessViolationException inside the PowerShell engine was reported as
    # 'FAILED (exit -1073741819)'. That reads as a suite that ran and said no. It did not run: it wrote
    # no [FAIL] line and no summary, so every minute a reader then spent looking for the failing assert
    # was spent on an assert that does not exist. Measured September 9, 2026 on a 30-lane pool --
    # branch-entry-gate.tests.ps1 ended mid-suite on a [PASS] line, its .err file carrying
    # WildcardPatternMatcher.PatternPositionsVisitor.Add under CommandSearcher.SearchForFunctions, and
    # it passed 49/49 on its own re-run.
    #
    # THE FIXTURE EXITS WITH THE CRASH CODE RATHER THAN CRASHING. An access violation cannot be raised
    # on demand from PowerShell, and it does not need to be: what the gate reads is the exit code, and
    # `exit -1073741819` produces exactly the value the OS leaves behind for 0xC0000005. What is under
    # test is the discriminator and the lone re-run, not the engine fault.
    Write-Host "a crashed suite -- no verdict, so it is re-run alone instead of being called a failure" -ForegroundColor Cyan

    # 8a. Crashes once, passes on the re-run: the gate must go GREEN and still say what happened.
    $crashOnce = Join-Path $Fixture 'suites-crash-once'
    $marker    = Join-Path $Fixture 'crash-once.marker'
    New-FakeSuite -Dir $crashOnce -Name 'flaky.tests.ps1' -Body @"
if (Test-Path -LiteralPath '$marker') { Write-Host 'MARKER-RETRY-RAN'; exit 0 }
Set-Content -LiteralPath '$marker' -Value 'seen'
Write-Host 'MARKER-FIRST-RUN'
exit -1073741819
"@
    New-FakeSuite -Dir $crashOnce -Name 'z-good.tests.ps1' -Body "Write-Host 'MARKER-GOOD'`r`nexit 0`r`n"
    $r = Invoke-Gate -TestsDir $crashOnce
    if ($r.CaptureDir) { $script:KeptCaptureDirs += $r.CaptureDir }
    Assert-True ($r.Text -match 'GATE-RESULT: True') 'a crash cleared by its lone re-run does not fail the gate'
    Assert-Says $r.Flat 'CRASHED (exit 0xC0000005)' 'the pool run says CRASHED, with the code as hex a reader can look up'
    Assert-Says $r.Flat 'the process died' 'and says that is what happened, rather than naming an assert'
    Assert-True ($r.Flat -notmatch 'FAILED \(exit -1073741819\)') 'and never reports the crash as a failed verdict'
    Assert-Says $r.Flat 're-ran ALONE and PASSED' 'the re-run is reported, not silently swallowed'
    Assert-Says $r.Text 'MARKER-RETRY-RAN' "and the re-run's own output is printed"
    Assert-Says $r.Flat 'crashed in the pool and passed alone: flaky.tests.ps1' 'the GREEN verdict names it -- that is the line a session quotes'

    # 8b. Crashes every time: red, and still called a crash rather than dressed up as a verdict.
    $crashAlways = Join-Path $Fixture 'suites-crash-always'
    New-FakeSuite -Dir $crashAlways -Name 'dead.tests.ps1' -Body "Write-Host 'MARKER-DEAD'`r`nexit -1073741819`r`n"
    $r = Invoke-Gate -TestsDir $crashAlways
    if ($r.CaptureDir) { $script:KeptCaptureDirs += $r.CaptureDir }
    Assert-True ($r.Text -match 'GATE-RESULT: False') 'a suite that crashes alone as well fails the gate -- nothing merges on a crash'
    Assert-Says $r.Flat 'CRASHED AGAIN alone' 'and the second crash is named as a crash'
    Assert-Says $r.Flat 'dead.tests.ps1' 'the verdict names the suite'

    # 8c. THE GUARD THAT MATTERS MOST: an ordinary failure is NOT retried. A suite that exits 1 has
    # measured the tree and said no; re-running that would mask a verdict, which is the whole reason
    # the discriminator is the sign bit and not "the suite went red".
    $failOnce = Join-Path $Fixture 'suites-fail-counted'
    $counter  = Join-Path $Fixture 'fail-runs.txt'
    New-FakeSuite -Dir $failOnce -Name 'honest-red.tests.ps1' -Body @"
Add-Content -LiteralPath '$counter' -Value 'run'
Write-Host 'MARKER-RED'
exit 1
"@
    $r = Invoke-Gate -TestsDir $failOnce
    if ($r.CaptureDir) { $script:KeptCaptureDirs += $r.CaptureDir }
    Assert-True ($r.Text -match 'GATE-RESULT: False') 'an ordinary failure still fails the gate'
    Assert-Equal 1 (@(Get-Content -LiteralPath $counter)).Count 'and it ran exactly ONCE -- a failure is a verdict, never a retry'
    Assert-Says $r.Flat 'FAILED (exit 1)' 'and is reported as a failure, not as a crash'
    Assert-True ($r.Flat -notmatch 'CRASHED') 'with no crash wording anywhere in the run'

    # 8e. A NEGATIVE EXIT CODE IS NOT ENOUGH -- the window is NTSTATUS's, not the sign bit's.
    #
    # WHY THIS CASE EXISTS (Sebastian's security review of #1723). The first version of the
    # discriminator tested the sign bit alone, and `exit -1` is a line any .tests.ps1 may write: it
    # arrives as 0xFFFFFFFF, so under that test a suite could hand ITSELF the free re-run that the
    # neighbouring promise -- an ordinary verdict is never retried -- exists to deny it. The fixture
    # below is that exact suite, and it must be treated as an honest red.
    $negOne  = Join-Path $Fixture 'suites-exit-minus-one'
    $negRuns = Join-Path $Fixture 'neg-runs.txt'
    New-FakeSuite -Dir $negOne -Name 'sneaky.tests.ps1' -Body @"
Add-Content -LiteralPath '$negRuns' -Value 'run'
if ((@(Get-Content -LiteralPath '$negRuns')).Count -ge 2) { Write-Host 'MARKER-SECOND-CHANCE'; exit 0 }
Write-Host 'MARKER-NEGATIVE-ONE'
exit -1
"@
    $r = Invoke-Gate -TestsDir $negOne
    if ($r.CaptureDir) { $script:KeptCaptureDirs += $r.CaptureDir }
    Assert-True ($r.Text -match 'GATE-RESULT: False') 'a suite exiting -1 fails the gate -- a negative code is not a crash claim'
    Assert-Equal 1 (@(Get-Content -LiteralPath $negRuns)).Count 'and it got NO second chance, so a suite cannot hand itself one'
    Assert-True ($r.Flat -notmatch 'CRASHED') 'and nothing calls it a crash'
    Assert-True ($r.Text -notmatch 'MARKER-SECOND-CHANCE') 'the pass it had waiting was never reached'

    # 8f. The discriminator itself, in-process: the NTSTATUS window, not a list of known codes.
    . $LibPath
    Assert-True (Test-GateSuiteCrashed -ExitCode -1073741819) '0xC0000005 (access violation) reads as a crash'
    Assert-True (Test-GateSuiteCrashed -ExitCode -1073741571) '0xC00000FD (stack overflow) reads as one too -- no code is enumerated'
    Assert-True (Test-GateSuiteCrashed -ExitCode -1073740791) '0xC0000409 (stack buffer overrun) as well -- the whole facility, not four literals'
    Assert-True (-not (Test-GateSuiteCrashed -ExitCode -1)) '0xFFFFFFFF is NOT a crash: severity ERROR, but not NT'"'"'s own facility'
    Assert-True (-not (Test-GateSuiteCrashed -ExitCode -2)) 'nor is any other small negative a script would choose'
    Assert-True (-not (Test-GateSuiteCrashed -ExitCode -2147483648)) 'nor 0x80000000, whose severity is WARNING'
    # CTRL+C IS INSIDE THE WINDOW AND IS NOT A CRASH (Marlowe's red-team of #1723). Every suite child
    # shares one console via -NoNewWindow, so interrupting a stuck 30-lane run delivers CTRL_C_EVENT to
    # all of them at once -- and without this exclusion the gate would answer a deliberate stop by
    # re-running everything it had just been told to abandon.
    Assert-True (-not (Test-GateSuiteCrashed -ExitCode 0xC000013A)) 'nor STATUS_CONTROL_C_EXIT -- Ctrl+C is a stop, not a fault'
    Assert-True (Test-GateSuiteCrashed -ExitCode 0xC0000139)  'while its neighbours in the window still are (0xC0000139)'
    Assert-True (Test-GateSuiteCrashed -ExitCode 0xC000013B)  'on both sides of it (0xC000013B) -- one status is excluded, not a range'
    Assert-True (-not (Test-GateSuiteCrashed -ExitCode 1)) "a suite's own 'exit 1' is a verdict"
    Assert-True (-not (Test-GateSuiteCrashed -ExitCode 0)) 'and so is exit 0'
    Assert-True (-not (Test-GateSuiteCrashed -ExitCode $null)) 'an empty exit code is not claimed as a crash'
    Assert-Equal '0xC0000005' (Format-GateExitCode -ExitCode -1073741819) 'a crash code is printed as hex'
    Assert-Equal '0xFFFFFFFF' (Format-GateExitCode -ExitCode -1) 'a negative that is not a crash still prints as hex -- the formatter judges nothing'
    Assert-Equal '1' (Format-GateExitCode -ExitCode 1) 'an ordinary one is printed as itself'

    # AND THE REPO ITSELF MUST NOT HOLD ONE, which is the measurement the docstring cites. A suite or
    # lib exiting negative would land in the window's blind spot by accident rather than by design.
    $negOffenders = @()
    foreach ($f in @(Get-ChildItem (Join-Path $RepoRoot 'scripts') -Recurse -Filter *.ps1 -File)) {
        if ($f.FullName -eq $PSCommandPath) { continue }   # this file's own fixtures say `exit -1` on purpose
        foreach ($m in [regex]::Matches((Get-Content -LiteralPath $f.FullName -Raw), '(?m)^\s*exit\s+-\d')) {
            $negOffenders += $f.Name
        }
    }
    Assert-Equal 0 $negOffenders.Count ("no script under scripts/ exits negative (offenders: " + ($negOffenders -join ', ') + ")")

    # --- 9. The progress signal: started, done, and the depth that separates a nested run ----------
    #
    # WHAT THIS PINS, AND WHY EACH HALF IS HERE (issue #1717). The gate printed one line naming the lane
    # count and then nothing until a suite exited, so a 15-30 minute run gave no way to tell 20/84 from
    # 70/84 -- and no way to tell a slow run from a wedged one, which matters because #1443 (an OOM) and
    # #1701 (a bound exceeded under load) both look exactly like a slow one from outside.
    #
    # THE THREE EXTERNAL DERIVATIONS #1717 TRIED ALL FAILED, and the third is what 9d exists for: the
    # gate's own suite drives the gate over a fixture, so a watcher that counted every 'test gate' line
    # in a log counted a fixture's run as the real one. That is not an accident this suite could remove --
    # a suite that tests the gate necessarily behaves like the gate -- so the depth is what makes the two
    # separable, and this file is the one place where a nested run genuinely occurs.
    Write-Host "the progress signal -- and a nested gate run that must not be mistaken for this one" -ForegroundColor Cyan
    . $LibPath

    # 9a. The line's shape, and its figure under a comma-decimal locale. Same reasoning as case 0: the
    # elapsed figure goes through Format-GateSeconds, and a culture leak here would print '+1,2s' where
    # an English reader takes the comma for a thousands separator.
    $prevCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
    try {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('nl-NL')
        Assert-Equal 'test gate: progress [depth 1] 37/84 started, 30 done, 7 running (+1.2s) -- started roster-sync.tests.ps1' `
            (Format-GateProgressLine -Action 'started' -Suite 'roster-sync.tests.ps1' -Started 37 -Done 30 -Running 7 -Total 84 -Elapsed 1.24 -Depth 1) `
            'Format-GateProgressLine: the whole line, and its seconds keep the invariant DOT under nl-NL'
        Assert-Equal 'test gate: progress [depth 2] 1/1 started, 1 done, 0 running (+2,182.4s) -- done a.tests.ps1' `
            (Format-GateProgressLine -Action 'done' -Suite 'a.tests.ps1' -Started 1 -Done 1 -Running 0 -Total 1 -Elapsed 2182.44 -Depth 2) `
            'and a nested run says depth 2, with the thousands grouped invariantly too'
    } finally {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = $prevCulture
    }

    # 9b. The depth itself. It crosses a process boundary into a variable anybody can set, so the
    # malformed cases are the point: each must fall back to the top level rather than fail a gate over a
    # diagnostic, and 'absent' and 'garbage' must not be distinguishable in the result.
    $depthVar  = 'DKJ_TEST_GATE_DEPTH'
    $depthHeld = [Environment]::GetEnvironmentVariable($depthVar, 'Process')
    try {
        [Environment]::SetEnvironmentVariable($depthVar, $null, 'Process')
        Assert-Equal 1 (Get-GateNestingDepth) 'Get-GateNestingDepth: an unset variable is the top level'
        [Environment]::SetEnvironmentVariable($depthVar, '1', 'Process')
        Assert-Equal 2 (Get-GateNestingDepth) 'a gate started inside a depth-1 run reports 2'
        [Environment]::SetEnvironmentVariable($depthVar, '3', 'Process')
        Assert-Equal 4 (Get-GateNestingDepth) 'and it counts rather than saturating'
        [Environment]::SetEnvironmentVariable($depthVar, 'deep', 'Process')
        Assert-Equal 1 (Get-GateNestingDepth) 'a non-numeric value is treated as absent, not as an error'
        [Environment]::SetEnvironmentVariable($depthVar, '-2', 'Process')
        Assert-Equal 1 (Get-GateNestingDepth) 'and so is a negative one -- there is no depth 0 to be one below'
        [Environment]::SetEnvironmentVariable($depthVar, '', 'Process')
        Assert-Equal 1 (Get-GateNestingDepth) 'an empty value too: empty is not a number'
    } finally {
        [Environment]::SetEnvironmentVariable($depthVar, $depthHeld, 'Process')
    }

    # 9c. A real run: every suite is announced twice, the counters arrive at the total, and the 'done'
    # line sits DIRECTLY above the block header it announces. That adjacency is the whole reason the
    # header itself was left untouched -- the line reads as the index #1717 asked for while
    # '== <suite> ==' stays byte for byte what every matcher already expects.
    $prog = Join-Path $Fixture 'suites-progress'
    New-FakeSuite -Dir $prog -Name 'p-one.tests.ps1'   -Body "Write-Host 'MARKER-P1'`r`nexit 0`r`n"
    New-FakeSuite -Dir $prog -Name 'p-two.tests.ps1'   -Body "Write-Host 'MARKER-P2'`r`nexit 0`r`n"
    New-FakeSuite -Dir $prog -Name 'p-three.tests.ps1' -Body "Write-Host 'MARKER-P3'`r`nexit 0`r`n"
    $r = Invoke-Gate -TestsDir $prog -MaxParallel 1
    Assert-True ($r.Text -match 'GATE-RESULT: True') 'three passing suites: the gate still returns true with the progress lines in it'
    $startedLines = @($r.Lines | Where-Object { $_ -match 'progress \[depth 1\].+-- started ' })
    $doneLines    = @($r.Lines | Where-Object { $_ -match 'progress \[depth 1\].+-- done ' })
    Assert-Equal 3 $startedLines.Count 'one started line per suite -- the signal that exists before anything COMPLETES'
    Assert-Equal 3 $doneLines.Count    'and one done line per suite'
    Assert-True ($r.Text -match 'progress \[depth 1\] 1/3 started, 0 done, 1 running') 'the first line reports 1/3 started with nothing done yet'
    Assert-True ($r.Text -match 'progress \[depth 1\] 3/3 started, 3 done, 0 running') 'and the last reports the pool drained: 3/3 started, 3 done, 0 running'
    foreach ($s in @('p-one.tests.ps1', 'p-two.tests.ps1', 'p-three.tests.ps1')) {
        $h = [Array]::IndexOf($r.Lines, "== $s ==")
        Assert-True ($h -ge 1 -and $r.Lines[$h - 1] -match ('progress \[depth 1\].+-- done ' + [regex]::Escape($s) + '$')) `
            "${s}: its done line is the line directly ABOVE its header, so the header itself needed no index"
    }
    $hp = [Array]::IndexOf($r.Lines, '== p-one.tests.ps1 ==')
    Assert-True ($hp -ge 0 -and $r.Lines[$hp + 1] -eq 'MARKER-P1') 'and the suite output is STILL the very next line after the header (case 2 property, unbroken)'

    # 9d. THE NESTED RUN, which is this suite's own doing and cannot be removed. A fixture suite drives
    # the gate itself; its lines must say depth 2, and filtering on depth 1 must leave exactly the outer
    # run's own two -- the dedup that every external derivation in #1717 got wrong.
    $nest      = Join-Path $Fixture 'suites-nested'
    $nestInner = Join-Path $Fixture 'suites-nested-inner'
    New-FakeSuite -Dir $nestInner -Name 'i-inner.tests.ps1' -Body "Write-Host 'MARKER-INNER'`r`nexit 0`r`n"
    New-FakeSuite -Dir $nest -Name 'n-drives-a-gate.tests.ps1' -Body (
        ". '$LibPath'`r`n" +
        "`$null = Invoke-TestSuiteGate -TestsDir '$nestInner' -Context 'the nested fixture' -MaxParallel 1`r`n" +
        "exit 0`r`n")
    $r = Invoke-Gate -TestsDir $nest -MaxParallel 1
    Assert-True ($r.Text -match 'GATE-RESULT: True') 'a suite that runs a gate of its own still passes'
    Assert-True ($r.Text -match 'progress \[depth 2\].+-- done i-inner\.tests\.ps1') 'the inner gate reports depth 2'
    Assert-Equal 2 (@($r.Lines | Where-Object { $_ -match 'progress \[depth 1\]' })).Count `
        'and filtering on depth 1 leaves exactly the outer run two lines -- one suite, started and done'
    Assert-Equal 2 (@($r.Lines | Where-Object { $_ -match 'progress \[depth 2\]' })).Count `
        'while the fixture own run is separable rather than merely present'

    # 9e. The variable does not outlive the run. It is process state the caller owns, and a gate that
    # left it set would make the caller's NEXT gate report depth 2 -- a wrong number that survives the
    # run that caused it.
    $leakHeld = [Environment]::GetEnvironmentVariable($depthVar, 'Process')
    $leakDir  = Join-Path $Fixture 'suites-leak'
    New-FakeSuite -Dir $leakDir -Name 'l-one.tests.ps1' -Body "exit 0`r`n"
    $null = Invoke-TestSuiteGate -TestsDir $leakDir -Context 'the leak check' -MaxParallel 1
    Assert-Equal "$leakHeld" "$([Environment]::GetEnvironmentVariable($depthVar, 'Process'))" `
        'the depth variable is exactly what it was before the run -- restored, not merely cleared'

    # --- 10. A suite that never returns is BOUNDED, not waited out (issue #1941) --------------------
    #
    # THE DEFECT THIS PROVES CLOSED. Before #1941 this loop had no deadline of any kind: it slept 100 ms
    # and went round again for as long as a lane took. One wedged suite therefore wedged the whole gate,
    # silently -- the pool buffers a suite's output until that suite exits, so a suite that never exits
    # prints nothing at all. Measured on DAVE-KOK-BWJ at 141 minutes with 90 processes alive and 0.23 s
    # of CPU between 29 of them.
    #
    # THE ASSERT THAT CARRIES THE WHOLE CASE IS THE WALL CLOCK. Every other line here would also pass if
    # the gate had simply waited the sleeping suite out and then called it a failure; only the elapsed
    # time distinguishes a bound that fired from one that did not. The margin is deliberately enormous --
    # a 60s sleeper under a 3s bound, asserted under 30s -- because this suite runs under a 16-to-30-lane
    # pool where a child's own bring-up has been measured at 3.25s (#1939), and a tight margin here would
    # be exactly the flaky-under-contention class this branch's other half exists to reproduce.
    Write-Host "the deadline: a suite that never returns is killed, named, and does not hold the pool" -ForegroundColor Cyan
    $slowDir = Join-Path $Fixture 'suites-slow'
    New-FakeSuite -Dir $slowDir -Name 's-quick.tests.ps1' -Body "Write-Host 'MARKER-QUICK'`r`nexit 0`r`n"
    New-FakeSuite -Dir $slowDir -Name 's-wedged.tests.ps1' -Body "Write-Host 'MARKER-WEDGED'`r`nStart-Sleep -Seconds 60`r`nexit 0`r`n"
    $to = Invoke-Gate -TestsDir $slowDir -MaxParallel 2 -SuiteTimeoutSeconds 3
    $script:KeptCaptureDirs += $to.CaptureDir
    Assert-True ($to.Text -match 'GATE-RESULT: False') 'a suite that outlives its bound fails the gate'
    Assert-True ($to.Seconds -lt 30) `
        "and the run does not wait it out -- it took $([math]::Round($to.Seconds,1))s against a 60s sleeper"
    Assert-True ($to.Text -match '== s-wedged\.tests\.ps1 == TIMED OUT') 'its header says TIMED OUT'
    Assert-Says $to.Flat 'its process tree was killed' 'and reports that the tree was killed, not merely the process'
    Assert-True ($to.Text -match '== s-quick\.tests\.ps1 ==\r?\n') 'the sibling that finished keeps its plain header'
    Assert-Says $to.Flat 'did not finish within the 3s bound: s-wedged.tests.ps1' `
        'the verdict tells a suite that never answered apart from one that asserted and said no'
    # NOT A CRASH, AND THEREFORE NOT RE-RUN. The whole judgement in #1941's branch: re-running a wedged
    # suite alone removes the contention that is the likeliest cause, passes, and leaves the gate green
    # over a run that cost the machine 90 processes.
    Assert-True ($to.Flat -notmatch 're-ran ALONE') 'and it is NOT re-run alone -- a timeout is a verdict, unlike a crash'
    Assert-True ($to.Flat -notmatch 'CRASHED') 'nor reported as a crash'
    # The evidence survives, the same promise #1636 made for a failing suite.
    Assert-True ($to.CaptureDir -ne '' -and (Test-Path -LiteralPath $to.CaptureDir)) `
        'a timed-out run keeps its capture directory'
    $wedgedOut = Join-Path $to.CaptureDir 's-wedged.tests.out.txt'
    Assert-True ((Test-Path -LiteralPath $wedgedOut) -and ((Get-Content -LiteralPath $wedgedOut -Raw) -match 'MARKER-WEDGED')) `
        'and it holds what the suite managed to print before it was killed'
    # The per-suite table must not report the bound as the file's cost.
    Assert-Says $to.Flat "TIMED OUT -- this is the bound, not the file's cost" `
        'the per-suite table says the number is the bound rather than a measurement'

    # 10b. The bound is announced, and a negative value turns it off. The second half cannot be asserted
    # by running something infinite -- that is the case the bound exists for -- so what is asserted is
    # that the gate stops CLAIMING a bound and still judges an ordinary suite correctly.
    Assert-Says $to.Flat 'each suite is bounded at 3s' 'the run states the bound it is holding suites to'
    $noBoundDir = Join-Path $Fixture 'suites-unbounded'
    New-FakeSuite -Dir $noBoundDir -Name 'u-one.tests.ps1' -Body "Write-Host 'MARKER-U'`r`nexit 0`r`n"
    $unbounded = Invoke-Gate -TestsDir $noBoundDir -MaxParallel 1 -SuiteTimeoutSeconds -1
    Assert-True ($unbounded.Text -match 'GATE-RESULT: True') '-SuiteTimeoutSeconds -1 still runs the suites'
    Assert-True ($unbounded.Flat -notmatch 'each suite is bounded at') 'and says nothing about a bound, because there is none'

    # --- 11. A focus run: one suite under the pool's real contention (issue #1944) ------------------
    #
    # WHAT IT IS FOR. This repo has a class of defect visible only under the pool -- #1915 and #1939,
    # three days apart, different files, identical discovery path: the gate refusing a push on a branch
    # that touched neither suite. Reproducing one meant running the whole ~19-minute gate, because a
    # standalone run is green BY DEFINITION OF THE BUG.
    Write-Host "focus mode: one suite, repeatedly, under real sibling load" -ForegroundColor Cyan
    $focusDir = Join-Path $Fixture 'suites-focus'
    New-FakeSuite -Dir $focusDir -Name 'f-target.tests.ps1' -Body "Write-Host 'MARKER-TARGET'`r`nexit 0`r`n"
    New-FakeSuite -Dir $focusDir -Name 'f-load-a.tests.ps1' -Body "Write-Host 'MARKER-LOAD-A'`r`nexit 0`r`n"
    New-FakeSuite -Dir $focusDir -Name 'f-load-b.tests.ps1' -Body "Write-Host 'MARKER-LOAD-B'`r`nexit 0`r`n"
    $fo = Invoke-Gate -TestsDir $focusDir -MaxParallel 2 -FocusSuite 'f-target' -FocusRepeat 3
    Assert-True ($fo.Text -match 'GATE-RESULT: True') 'a focus run whose target passes every repeat is green'
    Assert-Equal 3 (@($fo.Lines | Where-Object { $_ -match '^== f-target\.tests\.ps1 \[focus \d/3\] ==' }).Count) `
        'the target ran exactly -FocusRepeat times, each with its own header'
    Assert-Equal 3 (@($fo.Lines | Where-Object { $_ -eq 'MARKER-TARGET' }).Count) 'and each repeat really ran the file'
    Assert-Says $fo.Flat 'load -- does not decide this focus run' 'the load suites say on their own headers what they are for'
    Assert-Says $fo.Flat '3 focus repeat(s) of f-target passed' 'the verdict counts repeats, not suites'
    Assert-Says $fo.Flat 'FOCUS RUN -- f-target x 3, not a gate' `
        'and the line a session copies says this measured one suite rather than the tree'
    Assert-Says $fo.Flat '3/3 passed under load' 'the focus table states the draw count'
    Assert-Says $fo.Flat 'EVIDENCE OF ABSENCE ONLY AS FAR AS THE DRAW COUNT GOES' `
        'and refuses to let a green focus run read as proof the defect is gone'
    # The name is matched three ways, because all three are what a person has in hand.
    $foFull = Invoke-Gate -TestsDir $focusDir -MaxParallel 2 -FocusSuite 'f-target.tests.ps1' -FocusRepeat 1
    Assert-True ($foFull.Text -match 'GATE-RESULT: True') 'the full file name selects the same target'

    # 11b. WHOSE VERDICT DECIDES. The load is there to contend, not to be judged -- a focus run that went
    # red because an unrelated suite failed would report the target as broken when it is not.
    New-FakeSuite -Dir $focusDir -Name 'f-load-b.tests.ps1' -Body "Write-Host 'MARKER-LOAD-B'`r`nexit 9`r`n"
    $foBadLoad = Invoke-Gate -TestsDir $focusDir -MaxParallel 2 -FocusSuite 'f-target' -FocusRepeat 2
    $script:KeptCaptureDirs += $foBadLoad.CaptureDir
    Assert-True ($foBadLoad.Text -match 'GATE-RESULT: True') 'a FAILING LOAD suite does not fail the focus run'
    Assert-True ($foBadLoad.Text -match '== f-load-b\.tests\.ps1 == FAILED \(exit 9\)') 'though its failure is still printed in full'
    $foBadTarget = Invoke-Gate -TestsDir $focusDir -MaxParallel 2 -FocusSuite 'f-load-b' -FocusRepeat 2
    $script:KeptCaptureDirs += $foBadTarget.CaptureDir
    Assert-True ($foBadTarget.Text -match 'GATE-RESULT: False') 'while the SAME suite as the target does fail it'
    Assert-Says $foBadTarget.Flat '2/2 did NOT pass under load -- reproduced' 'and the focus table says it reproduced'

    # 11c. The refusals. Every wrong input here has a plausible-looking silent reading, and a focus run
    # that quietly measured nothing is the shape of a green gate that proved nothing.
    $foGone = Invoke-Gate -TestsDir $focusDir -MaxParallel 2 -FocusSuite 'f-nothing' -FocusRepeat 1
    Assert-True ($foGone.Text -match 'GATE-REFUSED:') 'a -FocusSuite matching nothing is refused, not silently ignored'
    Assert-Says $foGone.Flat 'no suite matches -FocusSuite' 'and the refusal says so in those words'
    Assert-True ($foGone.Flat -notmatch 'Did you mean') 'with no suggestion where there is genuinely nothing close'
    # A HALF-REMEMBERED NAME IS THE COMMONEST CAUSE, so a refusal that only says no sends the reader to
    # Get-ChildItem. 'target' is the shape that keeps happening: the distinctive half of the file name
    # without the prefix it actually carries.
    $foNear = Invoke-Gate -TestsDir $focusDir -MaxParallel 2 -FocusSuite 'target' -FocusRepeat 1
    Assert-True ($foNear.Text -match 'GATE-REFUSED:') 'a partial name is refused rather than guessed at'
    Assert-Says $foNear.Flat 'Did you mean: f-target.tests.ps1' 'and the refusal names the near miss'

    # 11d. Capture stems are per-ITEM, not per-file. Five lanes running one file would otherwise write
    # one pair of capture files between them, and the retention block would keep whichever finished last.
    New-FakeSuite -Dir $focusDir -Name 'f-target.tests.ps1' -Body "Write-Host 'MARKER-TARGET'`r`nexit 5`r`n"
    $foStems = Invoke-Gate -TestsDir $focusDir -MaxParallel 2 -FocusSuite 'f-target' -FocusRepeat 3
    $script:KeptCaptureDirs += $foStems.CaptureDir
    Assert-True ($foStems.Text -match 'GATE-RESULT: False') 'a failing target fails every repeat'
    Assert-True ($foStems.CaptureDir -ne '' -and (Test-Path -LiteralPath $foStems.CaptureDir)) 'and the run keeps its captures'
    $stemFiles = @(Get-ChildItem -LiteralPath $foStems.CaptureDir -File -Filter 'f-target.tests*.out.txt' -ErrorAction SilentlyContinue)
    Assert-Equal 3 $stemFiles.Count 'each repeat kept its OWN capture file -- three copies of one file, three stems'
}
finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
    foreach ($d in @($script:KeptCaptureDirs)) {
        if ($d -and (Test-Path -LiteralPath $d)) { Remove-Item -Recurse -Force -LiteralPath $d -ErrorAction SilentlyContinue }
    }
}

# --- Every suite's temp fixture must be UNGUESSABLE, not merely per-process -----------------------
#
# THE FAILURE THIS PREVENTS, measured on August 11, 2026. Running one suite by hand while the gate was
# running produced TWO failing asserts in connectors.tests.ps1 -- a suite that passes on its own. Nothing
# was wrong with the code under test: both runs built a fixture at the same fixed temp path, and each
# tore down the other's tree mid-assert. The visible result is a red gate naming a subject that is fine,
# which is the most expensive kind of false failure because the obvious next move is to go and read the
# subject.
#
# AND SINCE #1664 IT PREVENTS A SECOND, LARGER ONE -- which is why the rule asks for a guid and no longer
# accepts $PID alone. $PID is neither secret nor large, so a composed fixture leaf is a name a local actor
# can reach FIRST: New-Item -ItemType Directory -Force and Remove-Item -Recurse -Force both follow a
# reparse point, so a symlink or junction pre-planted at that exact path redirects the write AND the
# teardown. Measured September 8, 2026 across these suites, this guard excluded from both counts: 100
# guid-less composed paths, and 114 recursive deletes standing at one of them across 49 files. That is
# the same class #1659 closed in the shipping layer, and the delete half is the part #1659 had almost
# none of -- one site of its seven.
#
# THE TWO QUESTIONS ARE NOT THE SAME QUESTION, and conflating them is what left the exposure standing for
# a month. $PID answers "will two concurrent runs tear down each other's tree" -- correctly, and it is
# still required for the reason below. It says nothing about whether somebody who can write to the temp
# directory can be there first, because it is not a secret. Only a value nobody can name in advance
# answers that, and nothing can be pre-planted at a name that does not exist until the moment it is used.
#
# $PID STAYS IN FRONT OF THE GUID, exactly as New-ScratchPath composes it (scripts/lib/native-capture-lib.ps1).
# It buys nothing against an attacker and is not there for that: it is what makes a leftover attributable
# to a run that is still alive, which is what this suite's own retained-capture note (#1636) prints for a
# reader -- and what its gate-capture lookup at the top of this file GLOBS on ('<label>-<pid>-*'). That
# lookup is the one place in scripts/tests that reads a temp leaf back by name, and it already tolerates a
# guid suffix, which is what established that the $PID spelling was nowhere load-bearing (#1664).
#
# WHY THIS SUITE OWNS THE RULE. Since #512 the gate is a throttled PARALLEL scheduler, so concurrency is
# this file's subject. There is no collision WITHIN one gate run -- each fixture name is unique per suite
# -- but two gate runs, or a gate run beside a developer running one suite, share every fixed name. The
# gate being parallel is what makes that an ordinary situation rather than an exotic one.
#
# MEASURED BEFORE BEING WRITTEN: 38 of the temp paths in these suites already carried $PID or a GUID and
# 14 did not, across 11 files. So this asserts a convention the suites had already chosen, rather than
# imposing a new one -- which is also why the 14 repaired sites carry no explanatory comment: the 38 that
# were already right do not either, and a comment on half of them would read as the odd case. The same
# reasoning is why the 96 sites #1664 rewrote carry none: after it, EVERY site is guid-keyed, so a comment
# would mark the ordinary case.
#
# THE SUBJECT IS THE DISCRIMINATOR, NOT THE SPELLING. A fresh GUID inline, or a variable holding one, or a
# per-case label built on top of either, all pass; $PID alone and a bare literal do not. The two accepted
# variable names are pinned by the assert below, so the by-name allowance cannot decay into a fixed value.
#
# And the spelling includes the LINE BREAKS. Backtick continuations are folded first, so the unit judged
# is a statement rather than a physical line: a discriminator on the far side of a `-continuation is in
# view, and a path split so that GetTempPath() and Join-Path land on different lines is still seen (#1326).
Write-Host ''
Write-Host 'every suite keeps its temp fixture unguessable' -ForegroundColor Cyan
# This file is the guard, not a fixture-building suite -- it carries GetTempPath()/Join-Path in its
# own prose and in the #1326 fold cases below, which are test DATA rather than paths a run creates.
# Its one real fixture ($Fixture, at the top) is guid-keyed like every other. A guard scanning itself
# only re-checks its own example strings, so it is left out.
$self = 'test-suite-gate.tests.ps1'
$suiteFiles = @(Get-ChildItem -Path (Join-Path $RepoRoot 'scripts\tests') -Filter '*.ps1' -File |
    Where-Object { $_.Name -ne $self })
Assert-True ($suiteFiles.Count -gt 20) "the scan found the suites (saw $($suiteFiles.Count) files)"

# The two accepted variable names, declared before the scan because BOTH checks below read them: the
# discriminator is built from them, and the second check reads their assignments.
#
# A path is safe when its name carries a value NOBODY CAN NAME IN ADVANCE: a fresh guid inline, or one of
# these two variables holding one. $PID is no longer enough on its own (#1664) and neither is $Label --
# the latter varies within a run and repeats across them, which is exactly the case that was wrong in
# bootstrap-drift.
$FreshValueVars = @('tag', 'Guid')
$discriminator = 'NewGuid|' + (($FreshValueVars | ForEach-Object { '\$' + $_ + '\b' }) -join '|')

# ONE PASS, AND THE EXPENSIVE HALF IS GATED ON THE CHEAP ONE. Reading and folding these ~84 files costs
# ~0.55s and the matching is noise beside it, so both checks share the walk -- #1664 first added the
# second one as a second identical walk, which Nolan measured at 0.64s of pure duplication.
#
# The AST parse is the part that had to be bounded rather than merely shared. Parsing all 84 files costs
# ~5.5s, which would have made the fix for that 0.64s duplicate eight times worse than the duplicate; but
# only THREE files in this tree so much as name one of these variables, and parsing those three costs
# ~1.5s. So the fold above -- already paid for -- decides whether the parse happens at all. A file naming
# neither name has no assignment to either and nothing for the parser to find, so the gate cannot hide an
# offender: the token it screens on is the same one the offending assignment must contain.
$nameProbe = '\$(?:[A-Za-z]+:)?(?:' + ($FreshValueVars -join '|') + ')\b'
$tempLines = New-Object System.Collections.Generic.List[pscustomobject]
$fakeFresh = @()
foreach ($sf in $suiteFiles) {
    $folded = Join-BacktickContinuation ([System.IO.File]::ReadAllLines($sf.FullName))
    $namesFreshVar = $false
    foreach ($stmt in $folded) {
        if (-not $namesFreshVar -and $stmt.Text -match $nameProbe) { $namesFreshVar = $true }
        if ($stmt.Text -notmatch 'GetTempPath\(\)') { continue }
        # This file's own guard quotes the API in prose above; only statements that BUILD a path count.
        if ($stmt.Text -notmatch 'Join-Path') { continue }
        $tempLines.Add([pscustomobject]@{ File = $sf.Name; Line = $stmt.Line; Text = $stmt.Text.Trim() })
    }
    if ($namesFreshVar) { $fakeFresh += @(Get-FakeFreshAssignment -Path $sf.FullName -Names $FreshValueVars) }
}
Assert-True ($tempLines.Count -gt 40) "the scan really read the temp paths (found $($tempLines.Count))"

$unsafe = @($tempLines | Where-Object { $_.Text -notmatch $discriminator })
Assert-Equal 0 $unsafe.Count ("every temp fixture path is unguessable (offenders: " +
    (@($unsafe | ForEach-Object { "$($_.File):$($_.Line)" }) -join ', ') + ')')

Assert-Equal 0 $fakeFresh.Count ("every `$tag/`$Guid is assigned from a fresh guid of usable width " +
    "(offenders: " + ($fakeFresh -join ', ') + ')')

# --- The continuation fold, exercised directly (#1326) ---------------------------------------------
#
# The scan above trusted the discriminator to sit on the same physical line as the GetTempPath()/
# Join-Path pair. A backtick continuation puts it on the next line, and the assert then reported a
# path that is in fact per-process -- measured on fix/guard-coverage-comment-counts (#1321), where a
# helper carrying both $PID and a fresh GUID was named as an offender. These three cases pin the fold:
# a split SAFE path must fold to one statement with its discriminator visible, and a split BARE
# literal must still be caught -- as must a split $PID-ONLY path, since #1664.
#
# THEY MATCH ON $discriminator RATHER THAN ON A COPY OF IT. Spelling the pattern out a second time here
# is what let the two halves drift apart: these cases were still asserting the pre-#1664 alternation
# (which accepted $PID) after the rule above had stopped accepting it, so the file would have gone on
# proving a rule it no longer enforced -- green, and about nothing.
Write-Host ''
Write-Host 'a backtick continuation does not hide the discriminator' -ForegroundColor Cyan
$splitSafe = Join-BacktickContinuation @(
    '    $p = Join-Path ([System.IO.Path]::GetTempPath()) `',
    '        ("srguard-$PID-$Label-" + [guid]::NewGuid().ToString(''N'').Substring(0, 6) + ''.ps1'')'
)
Assert-Equal 1 $splitSafe.Count 'a backtick continuation folds to a single statement'
Assert-True (($splitSafe[0].Text -match 'GetTempPath\(\)') -and ($splitSafe[0].Text -match 'Join-Path')) `
    'the folded statement still carries both path markers'
Assert-True ($splitSafe[0].Text -match $discriminator) `
    'and the discriminator after the continuation is now in view'

$splitBare = Join-BacktickContinuation @(
    '    $p = Join-Path ([System.IO.Path]::GetTempPath()) `',
    '        "fixed-fixture-name.ps1"'
)
Assert-True ($splitBare[0].Text -notmatch $discriminator) `
    'a bare literal split across a continuation is still reported'

# THE CASE #1664 ADDED, and the only one that separates the new rule from the old. A $PID-keyed path is
# still per-process, so the pre-#1664 alternation called it safe; it is guessable, so this rule does not.
# Without this case the tightening is asserted nowhere -- every other case here passes under both
# patterns, which is exactly how a regex change can look proven while nothing tests it.
$splitPidOnly = Join-BacktickContinuation @(
    '    $p = Join-Path ([System.IO.Path]::GetTempPath()) `',
    '        "srguard-$PID-$Label.ps1"'
)
Assert-True ($splitPidOnly[0].Text -notmatch $discriminator) `
    'a $PID-only path is reported now, per-process though it is (#1664)'
Assert-True ($splitPidOnly[0].Text -match '\$PID') `
    'and it is reported BECAUSE of the guid, not because $PID went missing'

# --- The by-name allowance cannot be faked (#1664, after Sebastian's review) -----------------------
#
# The rule above accepts '$tag' in a fixture path by NAME, so Get-FakeFreshAssignment is what stops that
# name being given a predictable value. These cases are the three forms that defeated its first,
# regex-on-the-line shape, plus the width floor -- each written to a real file, because the subject is a
# parser and a parser needs something to parse.
Write-Host ''
Write-Host 'the $tag/$Guid allowance cannot be faked' -ForegroundColor Cyan
$astProbe = Join-Path $Fixture 'astprobe'
New-Item -ItemType Directory -Path $astProbe -Force | Out-Null

function Test-FakeFresh {
    param([string]$Label, [string]$Body)
    $p = Join-Path $astProbe ("$Label.ps1")
    [System.IO.File]::WriteAllText($p, $Body, $Utf8NoBom)
    return @(Get-FakeFreshAssignment -Path $p -Names @('tag', 'Guid'))
}

Assert-Equal 1 (Test-FakeFresh 'paramdefault' "function F {`n    param([string]`$tag = 'fixed-value')`n}`n").Count `
    'a parameter default holding a literal is reported -- the form no line regex can see'
Assert-Equal 1 (Test-FakeFresh 'inblock'      "if (-not `$tag) { `$tag = 'literal' }`n").Count `
    'an assignment inside a one-line block is reported'
Assert-Equal 1 (Test-FakeFresh 'semicolon'    "`$x = 1; `$tag = 'literal'`n").Count `
    'an assignment after a semicolon is reported'
Assert-Equal 1 (Test-FakeFresh 'scoped'       "`$script:tag = `$PID`n").Count `
    'a scope prefix does not hide it, and `$PID is not a fresh value'
Assert-Equal 1 (Test-FakeFresh 'narrow'       "`$tag = [Guid]::NewGuid().ToString('N').Substring(0, 1)`n").Count `
    'a guid truncated to four bits is reported -- naming NewGuid is not the same claim as being unguessable'
Assert-Equal 1 (Test-FakeFresh 'typed'        "[string]`$tag = 'literal'`n").Count `
    'a type constraint on the left does not hide it'

# And the honest forms stay silent, so the check is not simply refusing the name.
Assert-Equal 0 (Test-FakeFresh 'okfull'   "`$tag = [guid]::NewGuid().ToString('n')`n").Count `
    'a full fresh guid passes'
Assert-Equal 0 (Test-FakeFresh 'okwidth'  "`$tag = [Guid]::NewGuid().ToString('N').Substring(0, 8)`n").Count `
    'and so does the 8-character slice the two real call sites use'
Assert-Equal 0 (Test-FakeFresh 'okother'  "`$other = 'literal'`n").Count `
    'a variable outside the allowance is not this check subject'

# --- Get-TestSuiteFocusOrder, in-process (issue #1944) ---------------------------------------------
#
# WHY IN-PROCESS WHERE EVERY CASE ABOVE GOES THROUGH A CHILD. The cases above assert on what the gate
# PRINTS, and the gate prints through Write-Host, which never enters the pipeline -- so they have to read
# a child's console. This function returns a value, so driving it through a child would be reading a
# formatted table back as text to learn something the object already says. Same split the shard packer's
# own coverage uses.
Write-Host "the focus queue, composed directly" -ForegroundColor Cyan
. $LibPath

function New-FakeSuiteObject {
    param([string]$Name)
    return [pscustomobject]@{ Name = $Name; BaseName = ($Name -replace '\.ps1$', ''); FullName = "X:\tests\$Name" }
}
$fakePool = @('alpha.tests.ps1', 'beta.tests.ps1', 'gamma.tests.ps1') | ForEach-Object { New-FakeSuiteObject $_ }

# THE THREE SPELLINGS. All three are what a person has in their hand at that moment, and requiring one
# would only teach the caller to strip characters the function strips itself.
foreach ($spelling in @('beta', 'beta.tests', 'beta.tests.ps1')) {
    $q = @(Get-TestSuiteFocusOrder -Suites $fakePool -FocusSuite $spelling -Repeat 2 -Lanes 3)
    Assert-Equal 2 (@($q | Where-Object { $_.IsTarget }).Count) "'$spelling' selects beta, twice"
    Assert-True (@($q | Where-Object { $_.IsTarget } | ForEach-Object { $_.File.Name }) -notcontains 'alpha.tests.ps1') `
        "'$spelling' did not select a near neighbour"
}

# THE TARGET IS NEVER LOAD FOR ITSELF. A repeat contending with another repeat is not the pool
# contending with it, which is the thing a focus run is asking about.
$q = @(Get-TestSuiteFocusOrder -Suites $fakePool -FocusSuite 'beta' -Repeat 2 -Lanes 3)
Assert-Equal 0 (@($q | Where-Object { -not $_.IsTarget -and $_.File.Name -eq 'beta.tests.ps1' }).Count) `
    'the suite under test never appears as its own load'
Assert-True ($q[0].IsTarget) 'the queue opens with a target, so repeat 1 gets a full pool of lanes behind it'

# THE REPEATS ARE SPREAD, not fired into the opening lanes together -- one at the head of each of
# $Repeat equal chunks of the load.
$spread = @(Get-TestSuiteFocusOrder -Suites $fakePool -FocusSuite 'beta' -Repeat 3 -Lanes 4)
$targetAt = @(0..($spread.Count - 1) | Where-Object { $spread[$_].IsTarget })
Assert-Equal 3 $targetAt.Count 'three repeats are queued'
Assert-True (($targetAt | Select-Object -Last 1) -gt 2) 'and the last one is NOT in the opening lanes -- they are spread through the load'

# EVERY STEM IS UNIQUE. This is the half a bare file list cannot carry: the pool names its capture files
# after the item, and three lanes running one file would otherwise share one pair.
$stems = @($spread | ForEach-Object { $_.Stem })
Assert-Equal $stems.Count (@($stems | Sort-Object -Unique).Count) 'every queue item has its own capture stem'
Assert-True (@($spread | Where-Object { $_.IsTarget } | ForEach-Object { $_.Label }) -contains 'beta.tests.ps1 [focus 2/3]') `
    'and a target copy is labelled with which repeat it is, so three headers for one file are readable'

# MORE LANES MEANS MORE LOAD, because the budget is lane-seconds: the whole point is that every OTHER
# lane is busy while the target runs.
$narrow = @(Get-TestSuiteFocusOrder -Suites $fakePool -FocusSuite 'beta' -Repeat 2 -Lanes 2)
$wide   = @(Get-TestSuiteFocusOrder -Suites $fakePool -FocusSuite 'beta' -Repeat 2 -Lanes 8)
Assert-True ($wide.Count -gt $narrow.Count) `
    "a wider pool is given more load to fill it ($($wide.Count) items at 8 lanes against $($narrow.Count) at 2)"

# THE FLOOR, WHICH THE SECONDS BUDGET ALONE DOES NOT GIVE. A cheap target beside expensive siblings meets
# its lane-seconds in two or three files; the queue is then shorter than the lane count and the gate's own
# clamp quietly lowers -MaxParallel to fit, so a run asked for at 8 lanes is measured at 3. Measured on
# this repo's real hints while building #1944: -MaxParallel 6 produced 3 load items and ran at 5 lanes.
$cheapTarget = @(Get-TestSuiteFocusOrder -Suites $fakePool `
    -Costs @{ 'beta.tests.ps1' = 1; 'alpha.tests.ps1' = 500; 'gamma.tests.ps1' = 500 } `
    -FocusSuite 'beta' -Repeat 2 -Lanes 8)
Assert-True ($cheapTarget.Count -ge 8) `
    "a cheap target beside dear load still fills the lanes it was asked for ($($cheapTarget.Count) items for 8 lanes)"
Assert-True ((@($cheapTarget | Where-Object { -not $_.IsTarget }).Count) -ge 14) `
    'one load item per non-target lane per repeat, whatever the seconds budget says'

# COSTS ARE HINTS, AND A MISSING FILE IS NOT A FAILURE -- the same contract Get-TestSuiteCostHints
# already states. With hints, an expensive target buys a longer load list, which is the safe direction:
# over-charging the target makes the reproduction attempt more thorough, never less.
$cheap = @(Get-TestSuiteFocusOrder -Suites $fakePool -Costs @{ 'beta.tests.ps1' = 1; 'alpha.tests.ps1' = 10; 'gamma.tests.ps1' = 10 } `
             -FocusSuite 'beta' -Repeat 2 -Lanes 4)
$dear  = @(Get-TestSuiteFocusOrder -Suites $fakePool -Costs @{ 'beta.tests.ps1' = 100; 'alpha.tests.ps1' = 10; 'gamma.tests.ps1' = 10 } `
             -FocusSuite 'beta' -Repeat 2 -Lanes 4)
Assert-True ($dear.Count -gt $cheap.Count) 'a costlier target is given proportionally more load to outlast'

# A ONE-SUITE POOL IS NOT AN ERROR. There is nothing to contend against, and the honest answer is the
# repeats plus a lane count the summary states -- not a refusal.
$lonely = @(Get-TestSuiteFocusOrder -Suites @((New-FakeSuiteObject 'only.tests.ps1')) -FocusSuite 'only' -Repeat 4 -Lanes 8)
Assert-Equal 4 $lonely.Count 'a pool holding only the target yields exactly the repeats'
Assert-Equal 4 (@($lonely | Where-Object { $_.IsTarget }).Count) 'and all of them decide the verdict'

# THE REFUSALS, both of them. Refused rather than interpreted, on the same ground as -Shard's validation.
try {
    $null = Get-TestSuiteFocusOrder -Suites $fakePool -FocusSuite 'delta' -Repeat 1 -Lanes 2
    Assert-True $false 'a -FocusSuite matching nothing throws'
} catch {
    Assert-True ($_.Exception.Message -match 'no suite matches') 'a -FocusSuite matching nothing throws'
    Assert-True ($_.Exception.Message -match 'among the 3 in the pool') 'and says how large the pool it looked in was'
}
try {
    $null = Get-TestSuiteFocusOrder -Suites $fakePool -FocusSuite 'beta' -Repeat 0 -Lanes 2
    Assert-True $false '-Repeat below 1 throws'
} catch {
    Assert-True ($_.Exception.Message -match 'must be at least 1') '-Repeat below 1 throws rather than selecting nothing'
}

Write-Host ''
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
