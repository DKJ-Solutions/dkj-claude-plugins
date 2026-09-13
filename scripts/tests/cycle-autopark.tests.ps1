<#
.SYNOPSIS
    Tests for plugins/dkj-policy/hooks/cycle-autopark.ps1 -- the Stop hook that runs park-cycle.ps1
    after every turn, and what it does with the two streams that come back.

.DESCRIPTION
    WHY THIS SUITE EXISTS (issue #1600, September 8, 2026). The hook had no coverage at all, on the
    reasonable ground that it is deliberately thin -- every bound, refusal and measurement lives in
    park-cycle.ps1, which park-cycle.tests.ps1 exercises in full. What that left untested was the one
    thing the hook does own: WHICH STREAMS OF THE CHILD REACH THE SESSION. It captured stdout only,
    and the single most urgent line park-cycle can produce -- the sentence naming a second session on
    the same branch, written through Write-Error by Invoke-GitPark -- is on stderr. So the one turn
    where this hook had something urgent to say was the turn whose most useful line it dropped.

    Measured on feat/plugin-version-overview: two sessions ran the same pre-PR review in full from one
    handoff note, each finding real defects the other missed, and the collision was not learned until
    open-pr refused the push roughly half an hour later.

    THE FIXTURES DO NOT USE park-cycle AT ALL, deliberately. -ScriptOverride lets the hook run a stub
    that writes exactly what each case is about, so what is pinned here is the hook's own contract --
    both streams captured, a merged ErrorRecord stringified rather than printed as an object, exit 0
    whatever the child did -- with no git, no origin and no gh anywhere near it. park-cycle's own
    behaviour is park-cycle.tests.ps1's subject, and duplicating it here would be a second answer to a
    question that already has one.

    THE STUB MUST ACCEPT -Quiet, -UnderHook AND -RepoRoot, because the hook passes them. A stub that did
    not would fail on parameter binding and every assert below would go green for the wrong reason -- so
    case (a) asserts a stdout line arrives, which is what proves the stub ran at all.

    AND SECTION (g) IS THE ONE ASSERT HERE THAT IS NOT ABOUT STREAMS (issue #1958, September 13, 2026).
    park-cycle.ps1 promises it ALWAYS EXITS 0, and that promise is worth nothing past this hook's
    "timeout" in hooks.json, where the harness kills the process from outside and no arm of the script
    runs. So the hook declares -UnderHook and park-cycle spends at most
    $NativeCaptureHookNetworkBudgetSeconds on the network -- two numbers in two files, one of which is
    JSON and can carry no comment saying what it implies. This suite is where they are held together:
    that the hook still passes the switch, and that the budget still leaves room under the registered
    ceiling for the timed-out child to be killed and its report printed.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Continue'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Hook     = Join-Path $RepoRoot 'plugins\dkj-policy\hooks\cycle-autopark.ps1'
# $PID in the fixture path: the gate is a throttled PARALLEL scheduler, so two runs at one fixed temp
# path tear down each other's tree mid-assert. Same reasoning as the sibling hook suites.
$Fixture  = Join-Path ([System.IO.Path]::GetTempPath()) "cycle-autopark-tests-$PID-$([guid]::NewGuid().ToString('n'))"

$Ascii = New-Object System.Text.ASCIIEncoding
$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else            { $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}

function Assert-Says {
    param([string]$Text, [string]$Phrase, [string]$Name)
    # ALL whitespace stripped, not collapsed -- the same treatment park-cycle.tests.ps1 applies (#1512),
    # and the stronger form is needed here rather than merely tidier. The child is its own powershell
    # process: it renders and WRAPS at its buffer width before we ever see the text, and a wrap lands
    # mid-word ('...THIS BR' / 'ANCH'), which collapsing runs of whitespace to one space does not repair.
    $flat = ($Text -replace '\s', '')
    if ($flat.Contains(($Phrase -replace '\s', ''))) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         wanted: '$Phrase'`n         in:     '$flat'" -ForegroundColor Red
    }
}

function New-Stub {
    <#
        A stand-in for park-cycle.ps1 that writes what the case is about and exits with $ExitCode. It
        takes the two parameters the hook passes, so a binding failure cannot be mistaken for silence.

        -Body appends raw lines after the two writes and before the exit, for the cases that need to say
        something this signature does not cover (a warning, an output object, a PID, a throw).
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [string]$StdOut = '',
        [string]$StdErr = '',
        [string]$Body = '',
        [int]$ExitCode = 0
    )
    $path = Join-Path $Fixture "stub-$Label.ps1"
    $body = @"
param([switch]`$Quiet, [switch]`$UnderHook, [string]`$RepoRoot = '')
`$ErrorActionPreference = 'Continue'
if (`$UnderHook) { Write-Host 'STUB-SAW-UNDERHOOK' }
if ('$StdOut') { Write-Host '$StdOut' }
if ('$StdErr') { Write-Error '$StdErr' -ErrorAction Continue }
$Body
exit $ExitCode
Write-Host 'AFTER-EXIT-MUST-NOT-APPEAR'
"@
    [System.IO.File]::WriteAllText($path, $body, $Ascii)
    return $path
}

function Invoke-HookWithPid {
    <#
        Runs the hook through Start-Process so the test learns the HOOK's OWN process id, which is what
        case (f) compares the stub's $PID against. Invoke-Hook cannot answer that question: `&` gives back
        output and an exit code, never the child's id.

        Output is redirected to files rather than read from a pipe, because Start-Process offers no other
        route -- and stderr is redirected to its own file only so the console stays clean; nothing reads it.
        The hook relays everything it has to say on stdout by design.
    #>
    param([Parameter(Mandatory = $true)][string]$ScriptOverride)
    $outFile = Join-Path $Fixture 'pid-stdout.txt'
    $errFile = Join-Path $Fixture 'pid-stderr.txt'
    $prevPlugin = $env:CLAUDE_PLUGIN_ROOT
    try {
        Remove-Item Env:\CLAUDE_PLUGIN_ROOT -ErrorAction SilentlyContinue
        $p = Start-Process -FilePath 'powershell' `
                           -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Hook,
                                           '-ScriptOverride', $ScriptOverride) `
                           -NoNewWindow -Wait -PassThru `
                           -RedirectStandardOutput $outFile -RedirectStandardError $errFile
        $text = if (Test-Path -LiteralPath $outFile) { Get-Content -LiteralPath $outFile -Raw } else { '' }
        return [pscustomobject]@{ HookPid = $p.Id; Out = $text }
    } finally {
        if ($null -eq $prevPlugin) { Remove-Item Env:\CLAUDE_PLUGIN_ROOT -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_PLUGIN_ROOT = $prevPlugin }
    }
}

function Invoke-Hook {
    <# Runs the hook as a child, capturing stdout only -- which is what a Stop hook's own report is. #>
    param([string]$ScriptOverride = '', [string]$RepoRootOverride = '')
    $callArgs = @()
    if ($ScriptOverride)     { $callArgs += @('-ScriptOverride', $ScriptOverride) }
    if ($RepoRootOverride)   { $callArgs += @('-RepoRootOverride', $RepoRootOverride) }
    $prevPlugin = $env:CLAUDE_PLUGIN_ROOT
    try {
        # Cleared so a case that passes NO override really meets "no script found" rather than this
        # machine's installed plugin cache.
        Remove-Item Env:\CLAUDE_PLUGIN_ROOT -ErrorAction SilentlyContinue
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Hook @callArgs
        return [pscustomobject]@{ Code = $LASTEXITCODE; Out = (($out | Out-String)) }
    } finally {
        if ($null -eq $prevPlugin) { Remove-Item Env:\CLAUDE_PLUGIN_ROOT -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_PLUGIN_ROOT = $prevPlugin }
    }
}

Write-Host "== cycle-autopark.ps1 ==" -ForegroundColor Cyan
Assert-True (Test-Path -LiteralPath $Hook -PathType Leaf) 'the hook exists at its registered path'
if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture }
New-Item -ItemType Directory -Force -Path $Fixture | Out-Null

try {
    # --- (a) STDOUT IS RELAYED -- the pre-existing contract, and the proof the stub ran -------------
    Write-Host "cycle-autopark.ps1 -- a child's stdout reaches the session" -ForegroundColor Cyan
    $rA = Invoke-Hook -ScriptOverride (New-Stub -Label 'a' -StdOut 'park-cycle: pushed one document')
    Assert-True ($rA.Code -eq 0) 'stdout: exit 0'
    Assert-Says $rA.Out 'park-cycle: pushed one document' 'stdout: the line is relayed'

    # --- (b) STDERR IS RELAYED TOO -- the #1600 repair ---------------------------------------------
    # THE DEFECT: `$out = @(& powershell ...)` captures stdout alone, so Invoke-GitPark's push-failure
    # sentence -- the one naming another session on the branch -- never reached the hook's report.
    Write-Host "cycle-autopark.ps1 -- a child's stderr reaches it as well (#1600)" -ForegroundColor Cyan
    $rB = Invoke-Hook -ScriptOverride (New-Stub -Label 'b' -StdErr 'origin already has commits this branch does not')
    Assert-True ($rB.Code -eq 0) 'stderr: exit 0 -- the hook never fails a turn'
    Assert-Says $rB.Out 'origin already has commits this branch does not' 'stderr: the sentence is relayed, not dropped'

    # --- (c) THE WORDS SURVIVE THE TRIP, banner and console wrap included -------------------------
    # 2>&1 in Windows PowerShell 5.1 hands the merged stderr over as ErrorRecords rather than strings,
    # so the ToString() in the hook is load-bearing -- a bare Write-Host of a record prints its own
    # formatting instead of the text. What arrives is still the CHILD's rendering of its own error: a
    # 'stub-c.ps1 :' prefix, the message, and two trailing CategoryInfo/FullyQualifiedErrorId lines,
    # wrapped at that process's buffer width. That is acceptable for a safety net -- park-cycle passes
    # -NoFailureMessage now, so the sentence that matters arrives on stdout in its own voice -- and what
    # is pinned here is only that a line written to stderr is not LOST. The assert strips whitespace
    # entirely for the wrap; see Assert-Says.
    Write-Host "cycle-autopark.ps1 -- a line written to stderr is not lost" -ForegroundColor Cyan
    $rC = Invoke-Hook -ScriptOverride (New-Stub -Label 'c' -StdErr 'ANOTHER SESSION OR DEVICE IS WORKING THIS BRANCH')
    Assert-Says $rC.Out 'ANOTHER SESSION OR DEVICE IS WORKING THIS BRANCH' "stderr: the words survive the child's own rendering and wrap"

    # --- (d) BOTH STREAMS AT ONCE, and a non-zero child ------------------------------------------
    # The real shape of a refused push: git's plumbing on stdout, the interpretation on stderr. Neither
    # may cost the other, and the child's exit code may not reach the session -- a Stop hook that fails
    # interrupts the work it was added to protect.
    Write-Host "cycle-autopark.ps1 -- both streams survive, and a failing child still exits 0" -ForegroundColor Cyan
    $rD = Invoke-Hook -ScriptOverride (New-Stub -Label 'd' -StdOut '! [rejected] feat/x -> feat/x (fetch first)' -StdErr 'park: git push was rejected' -ExitCode 1)
    Assert-True ($rD.Code -eq 0) 'both streams: the hook exits 0 even though the child exited 1'
    Assert-Says $rD.Out '! [rejected] feat/x -> feat/x (fetch first)' 'both streams: git plumbing is there'
    Assert-Says $rD.Out 'park: git push was rejected' 'both streams: and the interpretation beside it'

    # --- (e) NO SCRIPT TO RUN -> silent, and still exit 0 ----------------------------------------
    # The existing bound, pinned so the stderr merge cannot turn a half-installed plugin into a line per
    # turn. Unlike the session checks, this one says nothing: it runs on EVERY turn.
    Write-Host "cycle-autopark.ps1 -- no park-cycle to run: silent, exit 0" -ForegroundColor Cyan
    $rE = Invoke-Hook
    Assert-True ($rE.Code -eq 0) 'no script: exit 0'
    Assert-True ([string]::IsNullOrWhiteSpace($rE.Out)) 'no script: and not one line printed'

    # --- (f) park-cycle RUNS IN THE HOOK'S OWN PROCESS -- the #1641 contract ----------------------
    # THE SUBJECT OF #1641: the hook spawned a whole second powershell.exe to run one script, on every
    # turn. Measured on the real park-cycle, ordinary turn, 7 runs each: 666 ms median spawning against
    # 564 ms in-process. Nothing above would notice a return to a child process -- every stream assert
    # passes either way, which is exactly why the saving needs an assert of its own rather than a comment.
    # $PID is the whole test: in-process it IS the hook's, and no spawn can fake that.
    Write-Host "cycle-autopark.ps1 -- park-cycle runs in-process, not in a second interpreter (#1641)" -ForegroundColor Cyan
    $rF = Invoke-HookWithPid -ScriptOverride (New-Stub -Label 'f' -Body 'Write-Host "child-pid=$PID"')
    Assert-Says $rF.Out "child-pid=$($rF.HookPid)" 'in-process: park-cycle reports the HOOK''s own process id'

    # --- (g) THE PARAMETERS BIND BY NAME ----------------------------------------------------------
    # The arguments are SPLATTED into the runspace, and a hashtable splats by name where an array splats
    # positionally. Got this wrong once while writing the change: as an array, the string '-Quiet' bound to
    # -RepoRoot and -Quiet stayed false -- a hook that prints park-cycle's entire report on every turn,
    # with nothing failing to say so. Only an assert on the VALUES catches that; every stream case above
    # stayed green through it.
    Write-Host "cycle-autopark.ps1 -- -Quiet and -RepoRoot arrive bound to the right parameters" -ForegroundColor Cyan
    $stubG = New-Stub -Label 'g' -Body 'Write-Host "bound quiet=$($Quiet.IsPresent) root=[$RepoRoot]"'
    $rG = Invoke-Hook -ScriptOverride $stubG -RepoRootOverride 'C:\some\where'
    Assert-Says $rG.Out 'bound quiet=True root=[C:\some\where]' 'binding: -Quiet is set and -RepoRoot is the path given, not each other'

    # --- (h) THE WIDER MERGE -- warning and output streams, which 2>&1 never read ------------------
    # The redirect is *>&1 now rather than 2>&1, so the safety net covers every stream park-cycle can
    # write to instead of stdout plus stderr. park-cycle uses Write-Host today; the point of the net is
    # the line somebody adds later through a stream nobody thought about.
    Write-Host "cycle-autopark.ps1 -- warning and output streams are relayed too" -ForegroundColor Cyan
    $rH = Invoke-Hook -ScriptOverride (New-Stub -Label 'h' -Body @'
Write-Warning 'a warning nobody used to see'
Write-Output 'an output object nobody used to see'
'@)
    Assert-Says $rH.Out 'a warning nobody used to see'       'wider merge: Write-Warning is relayed'
    Assert-Says $rH.Out 'an output object nobody used to see' 'wider merge: Write-Output is relayed'

    # --- (i) exit INSIDE park-cycle ENDS park-cycle, NOT THE HOOK ----------------------------------
    # THIS IS WHY IT IS A RUNSPACE AND NOT A DOT-SOURCE. park-cycle.ps1 calls `exit` at fourteen top-level
    # places, and `exit` inside a dot-sourced script terminates its CALLER -- so the cheapest-looking
    # in-process route would have taken the hook's own relay loop down with it. In a runspace `exit` ends
    # that runspace's pipeline: the lines before it arrive, the line after it never runs, the hook lives.
    Write-Host "cycle-autopark.ps1 -- a child's exit ends the child, not the hook (#1641)" -ForegroundColor Cyan
    $rI = Invoke-Hook -ScriptOverride (New-Stub -Label 'i' -StdOut 'written before the exit' -ExitCode 3)
    Assert-True ($rI.Code -eq 0) 'exit: the hook still exits 0 after a child that exited 3'
    Assert-Says $rI.Out 'written before the exit' 'exit: what was written before it still arrives'
    Assert-True (-not ($rI.Out -match 'AFTER-EXIT-MUST-NOT-APPEAR')) 'exit: and the line after it did not run'

    # --- (j) A TERMINATING ERROR DOES NOT SWALLOW WHAT CAME BEFORE IT ------------------------------
    # PARITY WITH THE CHILD PROCESS, and the reason the relay reads a PSDataCollection instead of
    # Invoke()'s return value: a child had already PRINTED its early lines before it died, while a thrown
    # Invoke() returns nothing at all. Taking the return value would have re-created #1600's loss --
    # park-cycle's most urgent lines going missing on the one turn it had something urgent to say -- by a
    # different route.
    Write-Host "cycle-autopark.ps1 -- a child that throws still delivers its earlier lines" -ForegroundColor Cyan
    $rJ = Invoke-Hook -ScriptOverride (New-Stub -Label 'j' -StdOut 'said before the throw' -Body 'throw "park-cycle fell over"')
    Assert-True ($rJ.Code -eq 0) 'throw: the hook exits 0 -- a Stop hook never fails a turn'
    Assert-Says $rJ.Out 'said before the throw' 'throw: the earlier line is not lost with the failure'

    # --- (k) THE NETWORK BUDGET AND THE REGISTERED CEILING, PINNED TOGETHER (issue #1958) ----------
    # WHY A SUITE AND NOT A COMMENT. The ceiling is "timeout" in hooks.json and the budget is a constant
    # in native-capture-lib.ps1: two files, one of them JSON, which carries no comment saying that the
    # other exists. Raise the budget past the ceiling and nothing anywhere reports it -- the hook simply
    # goes back to being killed from outside, which is invisible until a slow network, which is the exact
    # state #1958 was filed about. So the relationship is asserted rather than written down.
    #
    # THE MARGIN IS ASSERTED, NOT JUST THE ORDER. A budget EQUAL to the ceiling is the same defect one
    # layer in: Stop-NativeProcessTree is best-effort and is deliberately given time, the fail-safe arm
    # then has to run, and its report has to be printed and relayed -- all after the budget is spent. Ten
    # seconds is the floor on that margin, comfortably under the 15 the constant currently leaves.
    Write-Host "cycle-autopark.ps1 -- the network budget fits inside the registered hook timeout" -ForegroundColor Cyan
    . (Join-Path $RepoRoot 'scripts\lib\native-capture-lib.ps1')
    $hooksJson = Get-Content -Raw -LiteralPath (Join-Path $RepoRoot 'plugins\dkj-policy\hooks\hooks.json') | ConvertFrom-Json
    $stopEntry = @($hooksJson.hooks.Stop.hooks | Where-Object { $_.command -match 'cycle-autopark\.ps1' })
    Assert-True ($stopEntry.Count -eq 1) 'budget: cycle-autopark is registered exactly once as a Stop hook'
    $ceiling = [int]$stopEntry[0].timeout
    Assert-True ($ceiling -gt 0) "budget: that registration carries a timeout ($ceiling s)"
    Assert-True ($NativeCaptureHookNetworkBudgetSeconds -le ($ceiling - 10)) `
        "budget: $NativeCaptureHookNetworkBudgetSeconds s leaves at least 10 s under the $ceiling s ceiling to kill the child and print"
    Assert-True ($NativeCaptureHookNetworkFloorSeconds -gt 0 -and $NativeCaptureHookNetworkFloorSeconds -lt $NativeCaptureHookNetworkBudgetSeconds) `
        'budget: the floor is positive and smaller than the budget it is a floor on'

    # AND THE HOOK STILL DECLARES IT. The budget above is worth nothing if the switch carrying it is
    # dropped from $parkArgs, and nothing else in this suite would notice -- every other case here uses a
    # stub that ignores its parameters. The stub prints a line when it sees the switch, so this asserts
    # the declaration arrived rather than that the hook's source contains a word.
    $rK = Invoke-Hook -ScriptOverride (New-Stub -Label 'k' -StdOut 'the park ran')
    Assert-Says $rK.Out 'STUB-SAW-UNDERHOOK' 'budget: the hook passes -UnderHook to park-cycle'
} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Write-Host ""
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
