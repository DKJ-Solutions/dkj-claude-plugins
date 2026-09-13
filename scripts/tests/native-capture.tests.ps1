<#
.SYNOPSIS
    Regression tests for scripts/lib/native-capture-lib.ps1 -- the -Utf8 capture path (issue #907),
    the non-interactive environment + bounded wait (inbound #1179), the shared read of the capture
    files while a killed grandchild still holds a handle (#1252), and that this read REPORTS that
    hold instead of leaving a caller to guess what an empty capture on exit 0 meant (#1679).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Exit code 0 if everything passes, 1 on a
    failure -- so usable as a CI gate.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/native-capture.tests.ps1

    What this suite is for. Windows PowerShell 5.1 decodes a native child's stdout with
    [Console]::OutputEncoding, so the SAME command returns different strings depending on the console
    code page the run inherited. The DEPLOY lock compares a gh-read PR body against a file read as
    UTF-8; on a cp850 console the two sides were decoded differently and the lock refused a PR whose
    body was intact, naming a line that reads as correct -- in a gate with no -Force (issue #907,
    measured on PR #906).

    WHAT THE #1179 SECTIONS ARE FOR, since they test a different property of the same file. A git call
    the workflow makes can block on a credential helper that opens a prompt nothing will answer: on
    DAVE-KOK-BWJ a `git push` and the `git credential-manager get` it spawned were both still running
    fifteen minutes later, and the ship reported it as still shipping. Two guards answer that, and each
    is pinned separately because either one alone leaves a hole -- the environment closes the measured
    cause, the bound closes the class. The kill is asserted against a GRANDCHILD, because the process
    that actually blocked was the grandchild and a kill that misses it buys nothing.

    Those sections cost this suite roughly fifteen seconds of deliberate waiting. That is the subject:
    a bound can only be tested by outlasting it, and a fixture that stalls for less than the bound
    proves nothing. The suites run in parallel under the gate, so it costs wall-clock only if this is
    the slowest one.

    THE ENCODING ASSERTS RUN IN A CHILD PROCESS WITH ITS OWN CONSOLE, and that is the whole reason
    this suite is shaped the way it is. [Console]::OutputEncoding's setter is SetConsoleOutputCP,
    which is console-WIDE rather than per-process: the test gate starts every suite with
    -NoNewWindow on one shared console, so a suite that flips the code page flips it for every
    sibling scheduled beside it. That is exactly how inbound #821 stayed invisible for as long as it
    did -- an assert green under the gate and red on its own. Start-Process WITHOUT -NoNewWindow
    gives the child its own console, so the flip cannot leave this process.

    Note what is deliberately NOT asserted: that the default (non -Utf8) path mangles UTF-8 on cp850.
    It does, and that is the defect this switch exists to route around -- but pinning it would turn a
    future decision to change the default into a test failure rather than a decision. What is pinned
    is the property that matters: -Utf8 returns the same bytes on every code page.

    Pure ASCII (repo convention for .ps1) -- the em-dash under test is built from its code point.
#>
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')

$script:pass = 0
$script:fail = 0

function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    if ($Expected -eq $Actual) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red
    }
}

$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("native-capture-tests-$PID-$([guid]::NewGuid().ToString('n'))")
if (Test-Path -LiteralPath $sandbox) { Remove-Item -Recurse -Force -LiteralPath $sandbox }
New-Item -ItemType Directory -Path $sandbox -Force | Out-Null

try {
    # ---------------------------------------------------------------------------------------------
    Write-Host 'ConvertTo-NativeArgumentToken -- quoting for CreateProcess' -ForegroundColor Cyan

    Assert-Equal 'plain'          (ConvertTo-NativeArgumentToken -Value 'plain')        'an argument with nothing special is passed through unquoted'
    Assert-Equal '"hello world"'  (ConvertTo-NativeArgumentToken -Value 'hello world')  'a space forces quoting -- Start-Process joins on spaces and quotes nothing'
    Assert-Equal '""'             (ConvertTo-NativeArgumentToken -Value '')             'an empty string becomes a real empty argument, not nothing at all'
    Assert-True  ((ConvertTo-NativeArgumentToken -Value 'a"b') -like '*\"*')            'an embedded quote is escaped rather than left to terminate the token'
    # A trailing backslash only needs doubling when a closing quote follows it -- unquoted, it is an
    # ordinary character and is passed through. So the doubling case is a value that ALSO forces
    # quoting; asserting it on a bare 'ends\' would be asserting the wrong branch.
    Assert-Equal 'ends\'          (ConvertTo-NativeArgumentToken -Value 'ends\')        'a trailing backslash on an otherwise plain value is left alone -- nothing quotes it'
    Assert-Equal '"a b\\"'        (ConvertTo-NativeArgumentToken -Value 'a b\')         'a trailing backslash run IS doubled once quoting is forced, so it cannot escape the closing quote'

    # ---------------------------------------------------------------------------------------------
    Write-Host 'Invoke-NativeCapture -Utf8 -- argument round trip through a real argv parser' -ForegroundColor Cyan

    # cmd's echo prints its remainder verbatim, quotes included, so it cannot answer this question.
    # A PowerShell child receiving $args can: whatever comes out of it is what CreateProcess parsed.
    $argProbe = Join-Path $sandbox 'argprobe.ps1'
    Set-Content -LiteralPath $argProbe -Encoding Ascii -Value 'foreach ($a in $args) { Write-Output ("[" + $a + "]") }'

    function Invoke-ArgProbe {
        param([string[]]$Values)
        $r = Invoke-NativeCapture -Utf8 -FilePath 'powershell' -Arguments (@('-NoProfile', '-File', $argProbe) + $Values)
        return (@($r.Output) -join ' ')
    }

    Assert-Equal '[plain]'            (Invoke-ArgProbe -Values @('plain'))          'a plain argument arrives intact'
    Assert-Equal '[hello world]'      (Invoke-ArgProbe -Values @('hello world'))    'an argument with a space arrives as ONE argument'
    Assert-Equal '[a b] [c]'          (Invoke-ArgProbe -Values @('a b', 'c'))       'a spaced argument does not swallow the one after it'
    Assert-Equal '[has"quote]'        (Invoke-ArgProbe -Values @('has"quote'))      'an embedded quote survives the round trip'
    Assert-Equal '[trailing\]'        (Invoke-ArgProbe -Values @('trailing\'))      'a trailing backslash survives the round trip'
    # The two hard rules meeting in one value: this is the case the doubling exists for, and the only
    # one where getting it wrong swallows the NEXT argument rather than corrupting this one.
    Assert-Equal '[a b\] [next]'      (Invoke-ArgProbe -Values @('a b\', 'next'))   'a quoted argument ending in a backslash does not escape its own closing quote'

    # ---------------------------------------------------------------------------------------------
    Write-Host 'Invoke-NativeCapture -Utf8 -- exit codes and stderr' -ForegroundColor Cyan

    $ok  = Invoke-NativeCapture -Utf8 -FilePath 'cmd' -Arguments @('/c', 'exit', '0')
    $bad = Invoke-NativeCapture -Utf8 -FilePath 'cmd' -Arguments @('/c', 'exit', '3')
    Assert-Equal 0 $ok.ExitCode  'exit 0 is reported as 0'
    # Not merely "non-zero": Start-Process -PassThru without reading .Handle returns an EMPTY
    # ExitCode once the child has exited, and empty is not 3. This is the assert that catches it.
    Assert-Equal 3 $bad.ExitCode 'a non-zero exit code is reported exactly, not as empty'

    $merged    = Invoke-NativeCapture -Utf8 -FilePath 'cmd' -Arguments @('/c', 'echo oops 1>&2')
    $discarded = Invoke-NativeCapture -Utf8 -FilePath 'cmd' -Arguments @('/c', 'echo oops 1>&2') -DiscardStderr
    Assert-True  ((@($merged.Output) -join '').Contains('oops')) 'stderr is merged into Output by default'
    Assert-Equal 0 (@($discarded.Output).Count)                  '-DiscardStderr keeps stderr out, so it cannot pollute JSON'

    # ---------------------------------------------------------------------------------------------
    Write-Host 'Invoke-NativeCapture -Utf8 -- output shape' -ForegroundColor Cyan

    # A FILE rather than 'cmd /c echo a& echo b': echo's handling of its remainder inserts trailing
    # spaces around the separators, which would be asserting cmd's quirks instead of this function's
    # line splitting. The file's bytes are known exactly, including its single terminating newline.
    $lines3 = Join-Path $sandbox 'lines3.txt'
    [System.IO.File]::WriteAllText($lines3, "a`r`nb`r`nc`r`n", (New-Object System.Text.UTF8Encoding $false))
    $three = Invoke-NativeCapture -Utf8 -FilePath 'cmd' -Arguments @('/c', 'type', $lines3)
    Assert-Equal 3 (@($three.Output).Count) 'output comes back as one entry per line'
    Assert-Equal 'a' (@($three.Output)[0])  'the first line is the first line'
    # The newline that ENDS the last line is a terminator, not an empty line after it. A stray ''
    # here would become an extra element in every caller's -join.
    Assert-Equal 'c' (@($three.Output)[-1]) 'no phantom empty line is appended from the trailing newline'

    # ---------------------------------------------------------------------------------------------
    Write-Host 'Invoke-NativeCapture -- the child runs non-interactively (inbound #1179)' -ForegroundColor Cyan

    # THE ASSERTS BELOW MUTATE THIS PROCESS'S ENVIRONMENT, and that is safe here for the reason the
    # code-page asserts further down are NOT: Invoke-TestSuiteGate starts every suite as its own
    # Start-Process child, so a process-scope environment variable cannot reach a sibling suite. The
    # console is what is shared, not the environment.
    #
    # And every assert starts by DELETING both names rather than assuming they are unset. The machine
    # that produced #1179 may well carry them as a hand-placed bridge, and an assert that reads
    # "restored to absent" while the machine set it to '0' would pass on a laptop and fail in CI.
    function Reset-GuardEnv {
        foreach ($n in 'GIT_TERMINAL_PROMPT', 'GCM_INTERACTIVE') {
            [Environment]::SetEnvironmentVariable($n, $null, 'Process')
        }
    }

    Reset-GuardEnv
    $seen = Invoke-NativeCapture -FilePath 'cmd' -Arguments @('/c', 'echo GTP=%GIT_TERMINAL_PROMPT% GCM=%GCM_INTERACTIVE%')
    $seenText = (@($seen.Output) -join '')
    # BOTH NAMES, ASSERTED SEPARATELY. They stop different things -- git's own terminal prompt and the
    # credential manager's window -- and setting only GIT_TERMINAL_PROMPT leaves the measured hang
    # exactly in place, so an assert on the pair as one string would pass with the real defect present.
    Assert-True ($seenText -like '*GTP=0*')      'the child sees GIT_TERMINAL_PROMPT=0 -- git will not prompt on a terminal'
    Assert-True ($seenText -like '*GCM=never*')  'the child sees GCM_INTERACTIVE=never -- the credential manager fails instead of drawing a window'

    Reset-GuardEnv
    $seen8 = Invoke-NativeCapture -Utf8 -FilePath 'cmd' -Arguments @('/c', 'echo GTP=%GIT_TERMINAL_PROMPT% GCM=%GCM_INTERACTIVE%')
    # The Start-Process arm is a DIFFERENT launcher, so it inherits nothing from the assert above. Both
    # arms are exercised because ship-pr.ps1 reaches gh through one and git through the other.
    Assert-True ((@($seen8.Output) -join '') -like '*GTP=0*') 'the Start-Process arm guards its child too, not only the & arm'

    Reset-GuardEnv
    $null = Invoke-NativeCapture -FilePath 'cmd' -Arguments @('/c', 'exit', '0')
    # ABSENT IS NOT '': git reads a defined-but-empty GIT_TERMINAL_PROMPT differently from an undefined
    # one, so a restore that writes '' would leave every script that ran one git call in a state it did
    # not start in. This is the assert that catches `$env:NAME = $null`, which does exactly that.
    Assert-True ($null -eq [Environment]::GetEnvironmentVariable('GIT_TERMINAL_PROMPT', 'Process')) 'a variable that was ABSENT is restored to absent, not to the empty string'

    [Environment]::SetEnvironmentVariable('GIT_TERMINAL_PROMPT', 'callers-own', 'Process')
    $null = Invoke-NativeCapture -FilePath 'cmd' -Arguments @('/c', 'exit', '0')
    Assert-Equal 'callers-own' ([Environment]::GetEnvironmentVariable('GIT_TERMINAL_PROMPT', 'Process')) "a caller's own value is handed back, not ours"

    Reset-GuardEnv
    try { $null = Invoke-NativeCapture -FilePath 'a-command-that-does-not-exist-1179' -Arguments @() } catch { }
    # The restore is in a finally, and this is what proves it: a command that cannot even be launched
    # must not leave the guard behind for the rest of the script.
    Assert-True ($null -eq [Environment]::GetEnvironmentVariable('GIT_TERMINAL_PROMPT', 'Process')) 'the guard is restored even when the call throws instead of running'

    Reset-GuardEnv

    # ---------------------------------------------------------------------------------------------
    Write-Host 'Invoke-NativeCapture -TimeoutSeconds -- a stall fails loudly (inbound #1179)' -ForegroundColor Cyan

    # WHAT THIS PINS is the property the report asked for: the call RETURNS. Before the bound, a child
    # that never exits held the script forever and the workflow reported it as still working -- the
    # fifteen-minute hang on DAVE-KOK-BWJ. So the assert is on the elapsed time as much as on the
    # verdict: a wait that answered correctly after 30 seconds would be the defect, not the fix.
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $stalled = Invoke-NativeCapture -FilePath 'powershell' -Arguments @('-NoProfile', '-Command', 'Start-Sleep -Seconds 30') -TimeoutSeconds 2
    $sw.Stop()
    Assert-True  ($sw.Elapsed.TotalSeconds -lt 25)  'a child that would run for 30s is given up on, not waited out'
    Assert-True  $stalled.TimedOut                  'TimedOut says so, so a caller does not have to recognise an exit code'
    Assert-Equal 124 $stalled.ExitCode              'the exit code is the timeout code, not whatever the kill left behind'
    # THE DIAGNOSIS IS IN Output BECAUSE THAT IS WHERE CALLERS LOOK: every bounded site pipes Output to
    # Write-Host and then judges ExitCode. Without this line the three of them report a stall as a bare
    # non-zero exit, which is the "hang presented as something else" the report was about.
    Assert-True  ((@($stalled.Output) -join ' ') -like '*[[]timeout[]]*') 'Output carries a [timeout] line, so an unchanged caller still prints the reason'

    # A TIMED-OUT CAPTURE CAN CARRY THE CHILD'S OWN WORDS, AND THAT IS THE CONTRACT (#1852). The bound
    # firing says nothing about whether the capture is empty: this arm kills the tree and then reads
    # out.txt regardless, so everything the child had already flushed comes back in Output WITH
    # TimedOut = $true. Pinned here by a child that PRINTS BEFORE IT SLEEPS, because the property is
    # what the field exists for and a caller that judges a bounded call from Output's content alone is
    # reading a document the child never finished.
    #
    # IT IS PINNED RATHER THAN REPAIRED, deliberately. Discarding the flushed tail here would take the
    # evidence away from the callers that print it, which is exactly #1252's judgement at the read one
    # function down: for a stalled git push that tail IS the diagnosis. The half that was missing was
    # never in this lib -- it was a caller reading neither field. connector-sessioncheck.ps1 was that
    # caller, and CI is where it surfaced (run 34596638888): a killed version check reported as clean.
    # THE BOUND IS CALIBRATED, BECAUSE A FIXED 2s WAS RACING A QUANTITY NOTHING BOUNDS (#1939). The
    # assert above needs only that the bound EXPIRE, which any bound under the child's sleep delivers.
    # This one additionally needs the child to have REACHED Write-Host first -- so its bound has to
    # cover powershell.exe bring-up, and that is a property of the machine at this moment rather than
    # of this code. Measured September 13, 2026: green standalone, red inside the parallel gate at 16
    # lanes, same tree and same machine minutes apart. "No kill race involved" is what the comment
    # above used to claim, and it was true only on an idle machine.
    #
    # THE REPORT'S OWN FIGURE IS NOT THE QUANTITY THAT HAS TO FIT, which is worth stating because it
    # changes the size of the repair. #1939 read 0.5s standalone against 3.25s at 16 lanes, both out
    # of the Stop-NativeProcessTree calibration further down -- but that block times TWO cold startups
    # (the outer script, then the grandchild it Start-Processes), so the per-startup halves behind
    # those figures are roughly 0.25s and 1.6s. 1.6s against a 2s bound is thin margin that loses on a
    # bad sample rather than every time, which is exactly the shape a flake has; budgeting the
    # two-startup number here would have over-sized this bound by about 2x.
    #
    # SO IT IS MEASURED THE WAY THE GRANDCHILD BOUNDS BELOW ALREADY ARE, against ONE cold startup to
    # first output -- the quantity this case actually spends. The probe is the same child shape with
    # nothing to stall for, so what it times is bring-up plus Write-Host plus exit plus the capture's
    # own read: slightly MORE than the bound has to cover, which errs the safe way. It costs about a
    # quarter-second on an idle machine.
    #
    # FLOORED AT THE OLD 2s so an idle run pays exactly what it always paid, and CAPPED at 20s so a
    # pathological reading cannot hang the gate behind this one suite. The child's sleep is derived
    # from the bound rather than fixed at 30, so the first assert's property -- this is a timeout and
    # not a fast exit -- holds however wide the calibration goes.
    $flushWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $flushCal = Invoke-NativeCapture -FilePath 'powershell' `
        -Arguments @('-NoProfile', '-Command', "Write-Host 'STARTUP-CALIBRATION'") -TimeoutSeconds 120
    $flushWatch.Stop()
    $flushCalSeconds = [Math]::Round($flushWatch.Elapsed.TotalSeconds, 2)
    Assert-True ((@($flushCal.Output) -join ' ') -like '*STARTUP-CALIBRATION*') "the calibration child really ran and spoke (${flushCalSeconds}s) -- without this the bound below would be derived from a failure"
    $flushBound = [int][Math]::Min(20, [Math]::Max(2, [Math]::Ceiling($flushWatch.Elapsed.TotalSeconds * 4)))
    Write-Host "  cold powershell startup to first output measured at ${flushCalSeconds}s on this machine right now -- flush bound ${flushBound}s" -ForegroundColor DarkGray

    $flushed = Invoke-NativeCapture -FilePath 'powershell' `
        -Arguments @('-NoProfile', '-Command', "Write-Host 'FLUSHED-BEFORE-THE-KILL'; Start-Sleep -Seconds $($flushBound + 30)") -TimeoutSeconds $flushBound
    Assert-True $flushed.TimedOut 'the bound still fires on a child that spoke first, so this is a timeout and not a fast exit'
    Assert-Equal 124 $flushed.ExitCode 'and it is reported as one'
    Assert-True ((@($flushed.Output) -join ' ') -like '*FLUSHED-BEFORE-THE-KILL*') "yet Output carries what the child managed to say -- so Output is NOT evidence that the call completed, and TimedOut is the only field that answers that. Calibrated at ${flushCalSeconds}s and bounded at ${flushBound}s: a miss here is the MACHINE, not this code (#1939)"

    # A BOUND THAT DOES NOT EXPIRE CHANGES NOTHING. This is the assert that keeps the bound from
    # becoming a second failure mode of its own: the exit code still comes back exactly, which is the
    # #907 empty-ExitCode trap the Start-Process arm has to keep clearing.
    $inTime = Invoke-NativeCapture -FilePath 'cmd' -Arguments @('/c', 'exit', '7') -TimeoutSeconds 30
    Assert-Equal 7 $inTime.ExitCode   'a bounded call that finishes in time reports its own exit code'
    Assert-True  (-not $inTime.TimedOut) 'and does not claim to have timed out'

    # TimedOut IS PRESENT ON EVERY RETURN, from both arms, so no caller has to know which arm answered.
    $plain = Invoke-NativeCapture -FilePath 'cmd' -Arguments @('/c', 'exit', '0')
    Assert-True (-not $plain.TimedOut) 'an unbounded call on the & arm still carries TimedOut = $false'
    $plain8 = Invoke-NativeCapture -Utf8 -FilePath 'cmd' -Arguments @('/c', 'exit', '0')
    Assert-True (-not $plain8.TimedOut) 'and so does an unbounded call on the Start-Process arm'

    # A BOUND MUST NOT MOVE THE CHILD'S WORKING DIRECTORY (inbound #1181). This is the assumption every
    # bounded caller silently rests on, and it was worth measuring rather than reasoning about: passing
    # -TimeoutSeconds routes the call onto the Start-Process arm, and Set-Location changes PowerShell's
    # PROVIDER location without touching [Environment]::CurrentDirectory -- the classic 5.1 divergence.
    # Had Start-Process followed the .NET value, a bound would have run git in whatever directory the
    # session happened to start in. sync-main.ps1 is the caller that makes this load-bearing: it does
    # Set-Location to the repo root it resolved and then relies on every git call landing there.
    #
    # THE ASSERT IS AGAINST A DIVERGENCE IT CREATES ITSELF, so it cannot pass by accident on a session
    # where the two already agree -- which is how the first hand-check of this nearly proved nothing.
    $cwdProbe = Join-Path $sandbox 'cwd-probe'
    New-Item -ItemType Directory -Path $cwdProbe -Force | Out-Null
    $prevNetCurrent = [Environment]::CurrentDirectory
    Push-Location -LiteralPath $cwdProbe
    try {
        [Environment]::CurrentDirectory = $sandbox
        Assert-True ((Get-Location).Path -ne [Environment]::CurrentDirectory) 'the probe really did diverge the two notions of "here"'
        $whereBounded = Invoke-NativeCapture -FilePath 'cmd' -Arguments @('/c', 'cd') -TimeoutSeconds 30
        Assert-Equal $cwdProbe (@($whereBounded.Output) -join '').Trim() 'a bounded call runs in the PROVIDER location, not in [Environment]::CurrentDirectory'
    } finally {
        Pop-Location
        [Environment]::CurrentDirectory = $prevNetCurrent
    }

    # ---------------------------------------------------------------------------------------------
    Write-Host 'Stop-NativeProcessTree -- the GRANDCHILD dies too (inbound #1179)' -ForegroundColor Cyan

    # THIS IS THE MEASURED SHAPE, and it is the reason taskkill /T is used rather than Stop-Process. In
    # the report the process that blocked was not `git.exe push` (PID 11372) but the
    # `git credential-manager get` it spawned (PID 27176). Killing only the parent leaves that one
    # holding the prompt -- the hang survives the timeout, and the bound buys nothing.
    #
    # The fixture writes TWO markers: 'started' the moment the grandchild runs, 'survived' only after it
    # outlives the kill. Both are needed. Asserting the absence of 'survived' alone passes just as
    # happily when the grandchild never launched at all, which would be a test that cannot fail.
    #
    # BOTH HALVES OF THE FIXTURE ARE FILES, not -Command strings, and that is this suite's own subject
    # biting back: Start-Process joins -ArgumentList on spaces and quotes NOTHING, so a -Command string
    # carrying the sandbox path would arrive at the grandchild torn into pieces -- the grandchild would
    # never launch, and the survival assert would pass for the wrong reason. -File plus parameters means
    # the only quoting that has to be right is ConvertTo-NativeArgumentToken's, which is under test
    # sixty lines above.
    # ONE SANDBOX PATH PER ATTEMPT (see the retry note below): a kill is ALLOWED to fail, so a
    # grandchild that outlived its attempt must not be able to write into the next attempt's markers
    # and vouch for a launch that did not happen.
    $gcScript = Join-Path $sandbox 'grandchild.ps1'
    Set-Content -LiteralPath $gcScript -Encoding Ascii -Value @(
        'param([string]$Started, [string]$Survived, [int]$Sleep)'
        'Set-Content -LiteralPath $Started -Value started'
        'Start-Sleep -Seconds $Sleep'
        'Set-Content -LiteralPath $Survived -Value survived'
    )

    # The outer quotes the grandchild's arguments itself, for the same Start-Process reason.
    $outerScript = Join-Path $sandbox 'grandchild-parent.ps1'
    Set-Content -LiteralPath $outerScript -Encoding Ascii -Value @(
        'param([string]$Child, [string]$Started, [string]$Survived, [int]$Sleep, [int]$Stall)'
        '$quoted = @($Child, $Started, $Survived) | ForEach-Object { ''"'' + $_ + ''"'' }'
        'Start-Process -FilePath powershell -NoNewWindow -ArgumentList (@(''-NoProfile'', ''-ExecutionPolicy'', ''Bypass'', ''-File'') + $quoted + @("$Sleep"))'
        'Start-Sleep -Seconds $Stall'
    )

    # THE BOUND HAS TO COVER TWO COLD POWERSHELL 5.1 STARTUPS BEFORE THE GRANDCHILD CAN WRITE ITS
    # MARKER, and no FIXED number does (issues #1232 and #1700). Measured here on 18 cores, launch to
    # marker: 0.52s idle, 0.58s at half the cores busy, 2.67s with every core busy, 9.68s at twice
    # that -- so the failure arrives exactly when this suite is run the way it is meant to be run, in
    # a sweep of eighty-odd suites. The two startups split it roughly in half, and the OUTER half alone
    # (4.6s at twice the cores) already overruns 3s, so making only the grandchild cheaper would not
    # settle it.
    #
    # POLLING FOR THE MARKER AFTER THE RUN RETURNS CANNOT WORK, which is worth stating because it is
    # the obvious repair: Stop-NativeProcessTree kills with taskkill /T, the grandchild is inside that
    # tree, and whether it wrote its marker is therefore settled AT kill time and never changes after.
    #
    # SO THE BOUND IS MEASURED HERE, NOW, INSTEAD OF BEING GUESSED ONCE. #1232 answered this with a
    # ladder of 3s then 12s, sized AGAINST the table above rather than above it -- 9.68s against a 12s
    # bound is 2.3s of margin for two cold startups -- and #1700 measured both rungs losing inside one
    # gate run, then losing twice more standalone while the machine was still settling. A third fixed
    # rung would repeat the same mistake at a bigger number: the quantity is a property of the machine
    # AT THIS MOMENT, and the one thing this fixture can do that a constant cannot is ask it.
    #
    # THE CALIBRATION IS THE SAME LAUNCH, UNBOUNDED AND UNKILLED. It runs the same outer script with
    # nothing to stall for, then polls for the marker with a stopwatch, so what it times is exactly the
    # quantity the bound must cover -- two cold PowerShell 5.1 startups under whatever load is running
    # right now. It costs about half a second on an idle machine, which is less than the 3s rung it
    # replaces, and about ten seconds on a machine that would have failed both old rungs anyway.
    #
    # THE MARGIN IS 4x, FLOORED AT THE OLD FIRST RUNG AND CAPPED. A floor of 6s keeps an idle machine
    # paying roughly what this fixture always paid; a cap of 60s stops a pathological reading from
    # hanging the gate behind one suite. And the ladder SURVIVES, with one derived rung above the
    # calibrated one, because a calibration is itself a sample: the machine can be busier during the
    # attempt than it was during the measurement.
    #
    # A RUN WHERE EVEN THE WIDE BOUND CANNOT GET THE GRANDCHILD UP STILL FAILS -- the gate keeps a
    # verdict that means something, and by then the machine is the finding. What is different is that
    # the failure now names the calibrated figure, so the reader can tell a slow machine from a broken
    # launch instead of inferring it.
    #
    # The two derived numbers, per attempt. The grandchild must outlive the kill, so it sleeps
    # bound + 3. A SURVIVOR must have had time to write its second marker before that marker is
    # checked, so the wait after the run is bound + 6.
    $calStarted  = Join-Path $sandbox 'grandchild-started-calibration.txt'
    $calSurvived = Join-Path $sandbox 'grandchild-survived-calibration.txt'
    $calWatch    = [System.Diagnostics.Stopwatch]::StartNew()
    [void](Invoke-NativeCapture -FilePath 'powershell' -Arguments @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $outerScript,
        $gcScript, $calStarted, $calSurvived, '0', '0'
    ) -TimeoutSeconds 120)
    # The outer exits as soon as it has called Start-Process, which does NOT wait -- so the marker can
    # still be seconds away when the capture returns, and the poll is what actually times the launch.
    while (-not (Test-Path -LiteralPath $calStarted) -and $calWatch.Elapsed.TotalSeconds -lt 120) {
        Start-Sleep -Milliseconds 100
    }
    $calWatch.Stop()
    $calSeconds = [Math]::Round($calWatch.Elapsed.TotalSeconds, 2)
    $calLaunched = Test-Path -LiteralPath $calStarted
    Assert-True $calLaunched "the calibration launch reached the grandchild at all (${calSeconds}s) -- without this the bounds below would be derived from a failure"
    $boundFirst  = [int][Math]::Min(60, [Math]::Max(6, [Math]::Ceiling($calWatch.Elapsed.TotalSeconds * 4)))
    $boundSecond = [int][Math]::Min(90, $boundFirst * 3)
    Write-Host "  launch to marker measured at ${calSeconds}s on this machine right now -- bounds ${boundFirst}s then ${boundSecond}s" -ForegroundColor DarkGray

    $tree     = $null
    $started  = $null
    $survived = $null
    $afterRun = 0
    foreach ($bound in $boundFirst, $boundSecond) {
        $started  = Join-Path $sandbox "grandchild-started-$bound.txt"
        $survived = Join-Path $sandbox "grandchild-survived-$bound.txt"
        $afterRun = $bound + 6

        $tree = Invoke-NativeCapture -FilePath 'powershell' -Arguments @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $outerScript,
            $gcScript, $started, $survived, "$($bound + 3)", "$($bound + 30)"
        ) -TimeoutSeconds $bound

        if (Test-Path -LiteralPath $started) { break }
        Write-Host "  the grandchild did not launch inside ${bound}s -- loaded machine, retrying wider" -ForegroundColor DarkYellow
    }

    Assert-True $tree.TimedOut 'the fixture stalled as intended, so the kill under test actually ran'
    Assert-True (Test-Path -LiteralPath $started) "the grandchild really launched -- without this the next assert could not fail. Calibrated at ${calSeconds}s, attempted at ${boundFirst}s then ${boundSecond}s: a miss at both is the MACHINE, not this code (#1700)"

    # Long enough that a SURVIVING grandchild would have written its second marker (it sleeps from a
    # start that precedes the bound), with margin for a loaded machine.
    Start-Sleep -Seconds $afterRun
    Assert-True (-not (Test-Path -LiteralPath $survived)) 'the grandchild was killed with its parent -- taskkill /T, not Stop-Process'

    # ---------------------------------------------------------------------------------------------
    Write-Host 'Read-NativeCaptureFile -- a lingering write handle is not an IO error (#1252), and it is now REPORTED (#1679)' -ForegroundColor Cyan

    # THE OTHER HALF OF THE KILL ABOVE. The grandchild dies, but not synchronously: the bounded wait
    # after Stop-NativeProcessTree is on the DIRECT child only, so a grandchild that inherited the
    # redirected stdout handle can still hold out.txt when the read runs. The gap is wall-clock --
    # invisible locally (58 suites, 207s), a lost race on a CI runner four times slower (859s), where
    # it turned an unrelated branch's green red. [System.IO.File]::ReadAllText opens with
    # FileShare.Read, which cannot coexist with the writer handle still open, so it throws
    # "being used by another process". The fixture holds that handle for real rather than simulating
    # the window with a sleep.
    #
    # AND THE HANDLE IS WHAT MAKES THE FIXTURE DETERMINISTIC, which is why #1679's asserts live here
    # rather than against a real child. A grandchild race cannot be scheduled; a FileStream can, so
    # WriterHeld is pinned on a writer this suite owns.
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    $held = Join-Path $sandbox 'held-open.txt'
    [System.IO.File]::WriteAllText($held, "flushed output`n", $utf8NoBom)
    $writer = New-Object System.IO.FileStream(
        $held, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
    try {
        $threw = $false
        try { [void][System.IO.File]::ReadAllText($held) } catch { $threw = $true }
        Assert-True $threw 'the plain ReadAllText throws while the handle is held -- this is the bug the CI red was'

        $gotHeld = Read-NativeCaptureFile -Path $held -Encoding $utf8NoBom
        Assert-Equal "flushed output`n" $gotHeld.Text 'the shared read returns what was flushed instead of throwing'
        Assert-True $gotHeld.WriterHeld 'and it SAYS the writer still held the file -- the fact five callers used to have to guess (#1679)'

        # THE PROBE IS NOT SATISFIED BY A WAIT IT CANNOT WIN. The writer above is held for the whole
        # block, so the budget is spent in full and the verdict still comes back true -- which is the
        # correct answer for a holder that is alive rather than being reaped, and the reason the budget
        # is short. Asserted on elapsed as well as on the flag: a WriterHeld that arrived without
        # waiting would mean the settle parameter is being ignored.
        $waitClock = [System.Diagnostics.Stopwatch]::StartNew()
        $gotWaited = Read-NativeCaptureFile -Path $held -Encoding $utf8NoBom -SettleMilliseconds 300
        $waitClock.Stop()
        Assert-True $gotWaited.WriterHeld 'a holder that never releases is still reported as a short read after the budget'
        Assert-True ($waitClock.ElapsedMilliseconds -ge 300) "the settle budget was actually spent (waited $($waitClock.ElapsedMilliseconds)ms of 300)"
        Assert-Equal "flushed output`n" $gotWaited.Text 'and what was flushed still comes back -- #1252 is not weakened by #1679'
    } finally {
        $writer.Dispose()
    }

    # A SETTLED FILE IS THE OTHER HALF OF THE VERDICT, and without it WriterHeld could be hard-coded
    # true and every assert above would still pass.
    $settledFile = Join-Path $sandbox 'settled.txt'
    [System.IO.File]::WriteAllText($settledFile, "complete output`n", $utf8NoBom)
    $gotSettled = Read-NativeCaptureFile -Path $settledFile -Encoding $utf8NoBom
    Assert-Equal "complete output`n" $gotSettled.Text 'a file nobody holds reads whole'
    Assert-True (-not $gotSettled.WriterHeld) 'and reports no writer -- so WriterHeld discriminates rather than always answering yes'

    # AN EMPTY FILE NOBODY HOLDS IS THE CASE THE WHOLE ISSUE TURNS ON: empty AND settled means the
    # child genuinely wrote nothing, which is a legitimate answer at two of this repo's own call sites
    # (`git show --name-status --format=` on a commit that changed no files, and `gh --json body -q
    # .body` on a PR with an empty body). A caller may only treat empty as a failure when WriterHeld
    # says so, and this is the assert that keeps the two distinguishable.
    $emptyFile = Join-Path $sandbox 'empty-settled.txt'
    [System.IO.File]::WriteAllText($emptyFile, '', $utf8NoBom)
    $gotEmpty = Read-NativeCaptureFile -Path $emptyFile -Encoding $utf8NoBom
    Assert-Equal '' $gotEmpty.Text 'an empty capture reads as empty'
    Assert-True (-not $gotEmpty.WriterHeld) 'and as SETTLED -- "the child said nothing" is a different answer from "we read too early"'

    # A MISSING FILE IS NOT A SHARING VIOLATION AND IS NOT WAITED ON. FileNotFoundException derives
    # from IOException, so a retry loop that catches the base type would spend the entire budget before
    # failing with the error it started with. Pinned on elapsed, because the throw alone cannot tell a
    # prompt rethrow from a patient one.
    $missingClock = [System.Diagnostics.Stopwatch]::StartNew()
    $missingThrew = $false
    try {
        $null = Read-NativeCaptureFile -Path (Join-Path $sandbox 'not-there.txt') -Encoding $utf8NoBom -SettleMilliseconds 3000
    } catch {
        $missingThrew = $true
    }
    $missingClock.Stop()
    Assert-True $missingThrew 'a missing capture file still throws rather than returning an empty document'
    Assert-True ($missingClock.ElapsedMilliseconds -lt 1500) "and it throws at once rather than spending the settle budget (took $($missingClock.ElapsedMilliseconds)ms of a 3000ms budget)"

    # ---------------------------------------------------------------------------------------------
    Write-Host 'Write-GateCaptureBlock -- the test gate reads through the tolerant reader, and SAYS when a block may be short (#1731)' -ForegroundColor Cyan

    # THE GATE WAS THE ONE FUNCTION IN THIS FILE MOST EXPOSED TO THE HAZARD ABOVE AND THE ONE NOT USING
    # THE READER BUILT FOR IT: it read each suite's out.txt/err.txt with a plain Get-Content the moment
    # WaitForExit returned. And Get-Content does not fail on a held file -- the first assert below is
    # what makes that concrete, and it is the whole reason the defect was invisible. Where ReadAllText
    # throws (asserted above), Get-Content returns the flushed prefix and says nothing, so a truncated
    # suite block printed under a correct '== suite ==' header with the exit code intact.
    $gateHeld = Join-Path $sandbox 'gate-held.txt'
    [System.IO.File]::WriteAllText($gateHeld, "  [OK] first assertion`n", $utf8NoBom)
    $gateWriter = New-Object System.IO.FileStream(
        $gateHeld, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
    try {
        $lenient = Get-Content -LiteralPath $gateHeld -Raw -Encoding Oem
        Assert-True ($null -ne $lenient) 'Get-Content reads a HELD capture file without complaint -- which is why the short block had no symptom'

        # THE NOTE IS THE DELIVERABLE, so it is asserted on the console text rather than on a flag: the
        # only consumer of these blocks is the person reading them, and a returned field nobody prints
        # would be the same silence in a new place. 6>&1 captures Write-Host's information stream.
        $heldText = (@(Write-GateCaptureBlock -Path @($gateHeld) 6>&1 | ForEach-Object { [string]$_ }) -join "`n")
        Assert-True ($heldText -match '\[short read\]') 'a held capture file prints a visible [short read] note'
        Assert-True ($heldText -match 'gate-held\.txt') 'and the note names the file, so a reader knows which of the two captures was short'
        Assert-True ($heldText -match '\[OK\] first assertion') 'and what WAS flushed is still printed -- the note annotates the block, it does not replace it'
    } finally {
        $gateWriter.Dispose()
    }

    # THE NOTE SURVIVES AN EMPTY READ, which is the case it matters most in and the one an early
    # whitespace skip would swallow: a held file that has flushed nothing is exactly "the child said
    # nothing" against "we read before the flush".
    $gateEmptyHeld = Join-Path $sandbox 'gate-held-empty.txt'
    [System.IO.File]::WriteAllText($gateEmptyHeld, '', $utf8NoBom)
    $emptyWriter = New-Object System.IO.FileStream(
        $gateEmptyHeld, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
    try {
        $emptyHeldText = (@(Write-GateCaptureBlock -Path @($gateEmptyHeld) 6>&1 | ForEach-Object { [string]$_ }) -join "`n")
        Assert-True ($emptyHeldText -match '\[short read\]') 'an EMPTY held capture still prints the note rather than being skipped as blank'
    } finally {
        $emptyWriter.Dispose()
    }

    # AND IT DISCRIMINATES: without this, the note could be unconditional and every assert above would
    # still pass. A settled file prints its block and nothing else; an empty settled file prints
    # nothing at all, which is the behaviour the gate had before #1731 and must keep -- 85 suites with
    # no stderr must not add 85 blank lines to the run.
    $gateSettled = Join-Path $sandbox 'gate-settled.txt'
    [System.IO.File]::WriteAllText($gateSettled, "  [OK] whole suite`n", $utf8NoBom)
    $settledText = (@(Write-GateCaptureBlock -Path @($gateSettled) 6>&1 | ForEach-Object { [string]$_ }) -join "`n")
    Assert-True ($settledText -notmatch '\[short read\]') 'a settled capture prints NO note -- so the note discriminates rather than always firing'
    Assert-True ($settledText -match '\[OK\] whole suite') 'and its block is printed'

    $gateEmpty = Join-Path $sandbox 'gate-empty.txt'
    [System.IO.File]::WriteAllText($gateEmpty, '', $utf8NoBom)
    Assert-Equal 0 (@(Write-GateCaptureBlock -Path @($gateEmpty) 6>&1).Count) 'an empty SETTLED capture prints nothing -- a suite with no stderr adds no blank block'

    # A MISSING FILE IS SKIPPED RATHER THAN THROWN ON, unlike Read-NativeCaptureFile's own contract:
    # the gate's err.txt may legitimately not exist, and the Test-Path guard is what keeps the reader's
    # deliberate rethrow from turning that into a red gate.
    $missingSkipped = $true
    try { $null = Write-GateCaptureBlock -Path @((Join-Path $sandbox 'gate-not-there.txt')) 6>&1 }
    catch { $missingSkipped = $false }
    Assert-True $missingSkipped 'a capture file that was never created is skipped, not thrown on'

    # THE DECODE IS UNCHANGED BY THE SWAP, asserted rather than assumed -- the old site named the
    # encoding as Get-Content's own '-Encoding Oem' and the new one resolves the OEM code page itself.
    $oemHere = [System.Text.Encoding]::GetEncoding([System.Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage)
    $oemProbe = Join-Path $sandbox 'oem-decode.txt'
    [System.IO.File]::WriteAllBytes($oemProbe, [byte[]]@(0x61, 0x82, 0x62))   # 'a', a high byte, 'b'
    Assert-Equal (Get-Content -LiteralPath $oemProbe -Raw -Encoding Oem) `
                 (Read-NativeCaptureFile -Path $oemProbe -Encoding $oemHere).Text `
                 'the OEM code page this helper resolves decodes a high byte identically to Get-Content -Encoding Oem'

    # AND THE GATE HAS NO PLAIN READ LEFT, which is the inconsistency #1731 actually filed: the file
    # held a tolerant reader for a hazard and the function most exposed to it did not use it. Pinned on
    # the source so a later edit that copies the surrounding pattern back in -- which is exactly how
    # #1723 gave the exposure a second site -- fails here rather than being noticed by nobody.
    $libSource = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1') -Raw
    $gateBody = $libSource.Substring($libSource.IndexOf('function Invoke-TestSuiteGate'))
    Assert-True ($gateBody -notmatch 'Get-Content[^\r\n]*-Encoding Oem') 'Invoke-TestSuiteGate reads no capture file with a plain Get-Content'
    Assert-True (@([regex]::Matches($gateBody, 'Write-GateCaptureBlock')).Count -ge 2) 'both of its capture-printing sites -- the pool and the crash re-run -- go through the helper'

    # ---------------------------------------------------------------------------------------------
    Write-Host 'Invoke-NativeCapture -- ShortRead is present on BOTH arms (#1679)' -ForegroundColor Cyan

    # THE PROMISE IS THE ONE TimedOut ALREADY MAKES: a caller reads one field without knowing which
    # arm answered it. The & arm has no capture file at all, so its $false is a fact rather than a
    # default -- and a caller that has to test for the field's existence is back to guessing.
    $ampRun = Invoke-NativeCapture -FilePath 'git' -Arguments @('--version')
    Assert-True ($null -ne $ampRun.PSObject.Properties['ShortRead']) 'the & arm returns a ShortRead field'
    Assert-True (-not $ampRun.ShortRead) 'and it is false -- the & operator reads the pipeline directly, so there is no capture file to truncate'

    $utf8Run = Invoke-NativeCapture -FilePath 'git' -Arguments @('--version') -Utf8
    Assert-True ($null -ne $utf8Run.PSObject.Properties['ShortRead']) 'the -Utf8 arm returns a ShortRead field'
    Assert-True (-not $utf8Run.ShortRead) 'and an ordinary clean child is not a short read -- the probe must not cry wolf on the normal case'
    Assert-Equal 0 $utf8Run.ExitCode 'the fixture command really did succeed, so the assert above is about the read and not about a failure'

    # ---------------------------------------------------------------------------------------------
    Write-Host 'Invoke-NativeCapture -Utf8 -- the code page cannot reach the answer (issue #907)' -ForegroundColor Cyan

    # 'ory <em-dash> e' as gh would put it on the wire: UTF-8, e2 80 94 in the middle. Written as
    # bytes so this .ps1 stays ASCII, which the script layer requires.
    $wire = Join-Path $sandbox 'wire.txt'
    [System.IO.File]::WriteAllBytes($wire, [byte[]](0x6f, 0x72, 0x79, 0x20, 0xe2, 0x80, 0x94, 0x20, 0x65))

    # The child: set ITS console to $cp, capture the file through the lib, report the bytes it got.
    # Runs with its own console (no -NoNewWindow) so SetConsoleOutputCP cannot reach this process or
    # any sibling suite -- see the .DESCRIPTION.
    $cpProbe = Join-Path $sandbox 'cpprobe.ps1'
    $cpProbeBody = @'
param([int]$Cp, [string]$Lib, [string]$Wire, [string]$Out)
$ErrorActionPreference = 'Stop'
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding($Cp)
    . $Lib
    $r = Invoke-NativeCapture -Utf8 -FilePath 'cmd' -Arguments @('/c', 'type', $Wire)
    $text = (@($r.Output) -join '')
    $hex = ([System.Text.Encoding]::UTF8.GetBytes($text) | ForEach-Object { $_.ToString('x2') }) -join ' '
    Set-Content -LiteralPath $Out -Encoding Ascii -Value $hex
} catch {
    Set-Content -LiteralPath $Out -Encoding Ascii -Value ("ERROR: " + $_.Exception.Message)
}
'@
    Set-Content -LiteralPath $cpProbe -Encoding Ascii -Value $cpProbeBody

    $lib = (Resolve-Path (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')).Path
    $expectedHex = '6f 72 79 20 e2 80 94 20 65'
    $results = @{}
    foreach ($cp in @(65001, 850, 437)) {
        $outFile = Join-Path $sandbox "cp$cp.txt"
        $p = Start-Process -FilePath 'powershell' -WindowStyle Hidden -PassThru -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $cpProbe + '"'),
            '-Cp', $cp, '-Lib', ('"' + $lib + '"'), '-Wire', ('"' + $wire + '"'), '-Out', ('"' + $outFile + '"'))
        $null = $p.Handle
        $p.WaitForExit()
        $results[$cp] = if (Test-Path -LiteralPath $outFile) { (Get-Content -LiteralPath $outFile -Raw).Trim() } else { '<no output>' }
    }

    foreach ($cp in @(65001, 850, 437)) {
        Assert-Equal $expectedHex $results[$cp] "cp $cp decodes the UTF-8 em-dash to the bytes that were on the wire"
    }
    # Stated as its own assert because it is the property the DEPLOY lock actually depends on: not
    # that any one code page is right, but that they cannot disagree with each other.
    Assert-Equal 1 (@($results.Values | Sort-Object -Unique).Count) 'all three code pages agree -- the console cannot change the answer'

    # ---------------------------------------------------------------------------------------------
    Write-Host 'Test-DeployLock -- the defect end to end (issue #907)' -ForegroundColor Cyan

    . (Join-Path $PSScriptRoot '..\lib\pr-body-lib.ps1')

    $dash = [string][char]0x2014
    $section = "## DEPLOY: ``fix/x-v1``" + "`n`n" + "A line with an $dash em-dash in it." + "`n`n" + '**Score:** 2'

    # What a correct read produces: body and document identical, so the lock holds.
    $lockOk = Test-DeployLock -EntryText $section -PrBody $section
    Assert-True $lockOk.Applicable      'the lock applies to a section carrying its own heading'
    Assert-True $lockOk.Locked          'an intact body locks'

    # What a cp850 read produced: the em-dash arriving as the three characters it decodes to. This is
    # the exact shape #907 measured, and the assert says the lock was RIGHT to refuse it -- the defect
    # was never in the comparison, it was in handing it a mis-decoded string.
    $mojibake = $section.Replace($dash, ([string][char]0x00D4 + [string][char]0x00C7 + [string][char]0x00F6))
    $lockBad = Test-DeployLock -EntryText $section -PrBody $mojibake
    Assert-True $lockBad.Applicable     'the lock still applies -- the heading is ASCII and survived the mis-decode'
    Assert-True (-not $lockBad.Locked)  'a mis-decoded body does NOT lock, which is why #907 refused a correct PR'
    Assert-True ($lockBad.FirstDrift -like "*$dash*") 'and the line it names is the one carrying the em-dash'

    # ---------------------------------------------------------------------------------------------
    Write-Host 'Get-GitFileTextAtRef -- a COMMIT is not a checkout (issue #970)' -ForegroundColor Cyan

    # A REAL REPOSITORY RATHER THAN A MOCK, because every property under test is git's: which bytes a
    # blob holds, what `git show` does with a path a ref does not carry, and how its stderr behaves. A
    # fake that answered those would only pin what this suite already believes.
    #
    # A LOCAL FIXTURE RATHER THAN THIS REPO'S OWN HISTORY, deliberately: the divergence asserts below
    # need the working tree to differ from the commit and a second branch to exist, and arranging that
    # in the checkout the suite is running from would be editing the tree under the gate.
    $gitFx = Join-Path $sandbox 'ref-read'
    New-Item -ItemType Directory -Path $gitFx -Force | Out-Null
    function Invoke-FxGit {
        param([string[]]$GitArgs)
        # -c over `git config`: the fixture needs an identity to commit and nothing should depend on
        # whatever the machine running the gate has set globally.
        $r = Invoke-NativeCapture -FilePath 'git' -Arguments (@(
            '-C', $gitFx, '-c', 'user.name=fixture', '-c', 'user.email=fixture@example.invalid',
            '-c', 'commit.gpgsign=false') + $GitArgs)
        if ($r.ExitCode -ne 0) { throw "fixture git failed: $($GitArgs -join ' ')`n$($r.Output -join "`n")" }
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    # symbolic-ref rather than `init --initial-branch=main`: the flag is git 2.28 and later, and this
    # points the unborn HEAD at the same place on every version.
    Invoke-FxGit -GitArgs @('init', '--quiet')
    Invoke-FxGit -GitArgs @('symbolic-ref', 'HEAD', 'refs/heads/main')

    $committed = "# Development: ``feat/shipping-v1``" + "`n`nA line with an $dash em-dash." + "`n"
    [System.IO.File]::WriteAllText((Join-Path $gitFx 'cycle.md'), $committed, $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $gitFx 'empty.md'), '', $utf8NoBom)
    Invoke-FxGit -GitArgs @('add', 'cycle.md', 'empty.md')
    Invoke-FxGit -GitArgs @('commit', '--quiet', '-m', 'the shipping commit')

    Assert-Equal $committed.TrimEnd("`n") (Get-GitFileTextAtRef -Ref 'refs/heads/main' -Path 'cycle.md' -RepoRoot $gitFx) 'the ref hands back the committed text'
    Assert-True ((Get-GitFileTextAtRef -Ref 'refs/heads/main' -Path 'cycle.md' -RepoRoot $gitFx).Contains($dash)) 'and its em-dash survives, so a DEPLOY-lock comparison is not comparing a mis-decode'
    # ABSENT AND EMPTY ARE DIFFERENT ANSWERS, and this is the assert the resolver's fallback rests on:
    # both are falsy in PowerShell, so a caller that tested truthiness would read an empty document as
    # a missing one -- which is the silent-skip direction #970 is about.
    $absent = Get-GitFileTextAtRef -Ref 'refs/heads/main' -Path 'no/such/file.md' -RepoRoot $gitFx
    Assert-True ($null -eq $absent) 'a path the ref does not carry comes back as $null'
    $blank = Get-GitFileTextAtRef -Ref 'refs/heads/main' -Path 'empty.md' -RepoRoot $gitFx
    Assert-True ($null -ne $blank) 'an EMPTY committed file is not absent'
    Assert-Equal '' $blank 'it is the empty string -- so absent and empty cannot be confused'

    # git writes 'fatal: path ... does not exist' to stderr for the missing path above. -DiscardStderr
    # is what keeps that out of the returned document; without it a caller would have to RECOGNISE it.
    Assert-True (-not ([string]$absent).Contains('fatal')) "git's own error line never arrives inside the document"

    # THE DIVERGENCE THAT IS THE WHOLE POINT. The working tree is overwritten and a second branch is
    # created and checked out -- the #970 shape exactly: the run is shipping feat/shipping-v1 while the
    # checkout has moved on. The read must still answer for the commit.
    [System.IO.File]::WriteAllText((Join-Path $gitFx 'cycle.md'), "# Development: ``main```n", $utf8NoBom)
    Invoke-FxGit -GitArgs @('checkout', '--quiet', '-b', 'feat/the-next-thing')
    Invoke-FxGit -GitArgs @('add', 'cycle.md')
    Invoke-FxGit -GitArgs @('commit', '--quiet', '-m', 'the branch created during the CI wait')

    Assert-Equal $committed.TrimEnd("`n") (Get-GitFileTextAtRef -Ref 'refs/heads/main' -Path 'cycle.md' -RepoRoot $gitFx) 'the shipping ref still answers its own commit after the checkout moved'
    Assert-True ((Get-GitFileTextAtRef -Ref 'refs/heads/feat/the-next-thing' -Path 'cycle.md' -RepoRoot $gitFx) -notlike "*shipping*") 'and the other branch is a different answer -- which is what the working tree would have given'

    # A SLASH IN THE BRANCH NAME IS THE ORDINARY CASE HERE, so the ref form is asserted rather than
    # assumed: 'refs/heads/feat/the-next-thing' resolves, and that is why callers pass the full name.
    Assert-True ($null -ne (Get-GitFileTextAtRef -Ref 'refs/heads/feat/the-next-thing' -Path 'cycle.md' -RepoRoot $gitFx)) 'a prefixed branch name resolves as a ref'

    # Join-Path output is the likeliest input a caller has lying around, so a backslash path is
    # converted rather than refused.
    Assert-Equal $committed.TrimEnd("`n") (Get-GitFileTextAtRef -Ref 'refs/heads/main' -Path 'cycle.md' -RepoRoot $gitFx) 'a forward-slash path reads'
    New-Item -ItemType Directory -Path (Join-Path $gitFx 'sub') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $gitFx 'sub\nested.md'), "nested`n", $utf8NoBom)
    Invoke-FxGit -GitArgs @('add', 'sub/nested.md')
    Invoke-FxGit -GitArgs @('commit', '--quiet', '-m', 'a nested path')
    Assert-Equal 'nested' (Get-GitFileTextAtRef -Ref 'HEAD' -Path 'sub\nested.md' -RepoRoot $gitFx) 'and so does the same path written with backslashes'
} finally {
    if (Test-Path -LiteralPath $sandbox) { Remove-Item -Recurse -Force -LiteralPath $sandbox -ErrorAction SilentlyContinue }
}

# --- the shared bound describes itself accurately (#1639) -----------------------------------------
# THIS IS A COMMENT TEST, AND IT IS THE ROOT CAUSE RATHER THAN A STYLE POINT. The bound was documented
# as "THE BOUND A GIT NETWORK CALL PASSES" and enumerated three sites; by the time it was read back,
# six files passed the value and two of them passed it to `gh`. A reader comes to this one place to
# learn the policy, so a `gh`-only script found the policy described as being about git and did not
# pick it up -- which is the measured reason claim-issue.ps1 shipped three unbounded calls. An
# enumeration in a comment cannot be kept true by any gate, so the repair was to remove it and point
# at the tree; these asserts hold that repair, and the count assert is what makes a re-added list fail.
Write-Host ''
Write-Host 'The shared network bound -- how it describes itself (#1639)' -ForegroundColor Cyan

$ncLibText = [System.IO.File]::ReadAllText((Resolve-Path (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')).Path)

# THE ASSERT IS ABOUT THE DECLARATION, NOT ABOUT ANY MENTION, and getting that wrong once is why it is
# spelled this way. This repo's convention is that a correction records what the text used to say
# verbatim, so the paragraph below the heading QUOTES the old git-only wording on purpose -- and an
# assert that simply forbade the string would fail on the very sentence that documents the repair. The
# subject is the column-0 comment heading, which is the thing a reader takes as the policy.
Assert-True ($ncLibText -notmatch '(?m)^# THE BOUND A GIT NETWORK CALL PASSES') 'the bound no longer DECLARES itself git-only, which is what a gh-only script read and skipped'
Assert-True ($ncLibText -match [regex]::Escape('"THE BOUND A GIT NETWORK CALL PASSES"')) '...while still quoting that old wording as the history it is, rather than deleting the evidence'
Assert-True ($ncLibText -match 'git OR gh') 'it names both commands where a script author reads the policy'
Assert-True ($ncLibText -match [regex]::Escape('grep -rl NativeCaptureNetworkTimeoutSeconds')) 'and points at the tree for the site list, instead of carrying one that goes stale'
Assert-True ($ncLibText -notmatch 'the three sites that reach the network') 'the stale three-site enumeration is gone'
Assert-True ($ncLibText -match '1639') 'and the reason it went is citable from the file itself'

# THE NUMBER IS REUSED FOR gh RATHER THAN RE-DERIVED, and #1639 asked for that to be said out loud: the
# two-minute figure is sized off a git push, and a comment that presents it as a bound for every
# command would be asserting something nobody measured.
Assert-True ($ncLibText -match 'git-push ARGUMENT') 'the number still says which command it was sized off'
Assert-True ($ncLibText -match 'REUSED') '...and that it is reused rather than re-derived for a gh call'

# AND THE SITE COUNT IS MEASURED, so the paragraph's claim about the tree is a fact rather than prose.
# Read from the repo root, which is where the grep in that comment is meant to be run.
$scriptsRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$readers = @(Get-ChildItem -LiteralPath $scriptsRoot -Recurse -Filter '*.ps1' -File |
             Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match [regex]::Escape('NativeCaptureNetworkTimeoutSeconds') })
Assert-True ($readers.Count -gt 3) "more than three files read the bound, which is why the enumeration was removed (found $($readers.Count))"
Assert-True (@($readers | Where-Object { $_.Name -eq 'claim-issue.ps1' }).Count -eq 1) 'and claim-issue.ps1 is now among them (#1639)'

Write-Host ''
Write-Host ''
Write-Host 'New-ScratchPath -- a temp path nobody can name in advance (#1659)' -ForegroundColor Cyan

$tempRoot = ([System.IO.Path]::GetTempPath()).TrimEnd('\', '/')

$p1 = New-ScratchPath -Label 'ccs-scratch-test'
$p2 = New-ScratchPath -Label 'ccs-scratch-test'
Assert-True ($p1 -ne $p2) 'two calls with the SAME label return different paths -- there is no name to pre-plant a junction at'
Assert-True ((Split-Path -Parent $p1) -eq $tempRoot) 'the result is a direct child of the temp directory'
Assert-True ((Split-Path -Leaf $p1) -match "^ccs-scratch-test-$PID-[0-9a-f]{32}$") 'the leaf is <label>-<pid>-<32 hex>, so a leftover is still attributable to a run that is still alive'
Assert-True (-not (Test-Path -LiteralPath $p1)) 'nothing is created without -Directory -- ship-pr hands its path to `git worktree add`, which makes it'

Assert-True ((New-ScratchPath -Label 'ccs-scratch-test' -Extension '.md') -match '\.md$') '-Extension lands at the end, after the guid'

$pd = New-ScratchPath -Label 'ccs-scratch-test' -Directory
try {
    Assert-True (Test-Path -LiteralPath $pd -PathType Container) '-Directory creates the directory itself'
} finally { Remove-Item -Recurse -Force -LiteralPath $pd -ErrorAction SilentlyContinue }

# THE LABEL IS THE ONE HALF A CALLER COMPOSES -- ship-pr puts a PR number in it, verify-resolved-issues
# an issue number, sync-main a branch name. These pin that no value of it can walk out of the temp
# directory, which is the property the "direct child" assert above states and this one enforces.
function Test-ScratchThrows { param([scriptblock]$Body) try { & $Body | Out-Null; return $false } catch { return $true } }
Assert-True (Test-ScratchThrows { New-ScratchPath -Label '..' }) 'a label of ".." is refused'
Assert-True (Test-ScratchThrows { New-ScratchPath -Label 'a/../../b' }) 'and so is one carrying a separator, so no label can leave the temp directory'
Assert-True (Test-ScratchThrows { New-ScratchPath -Label 'ok' -Extension 'md' }) 'an extension missing its dot is refused rather than silently glued to the guid'

Write-Host ''
Write-Host 'Every temp path the SHIPPING scripts compose carries a guid (#1659)' -ForegroundColor Cyan

# THE SCAN, RATHER THAN A NOTE IN A DOC. #1659 was filed because seven sites had each hand-composed
# "<label>-$PID" and nothing stopped an eighth; a rule enforced by memory is one that gets skipped.
#
# THE RULE IS ON THE TEMP ROOT ITSELF, rather than on the
# join standing beside it. Requiring the two together on one line was the first shape, and it had a hole
# a reformat walks straight through: assign the root to a variable on one line, join to it on the next,
# and the composition is invisible to a line scan while being exactly what the rule forbids. So any
# non-comment line naming a temp root -- the .NET call, or the TEMP/TMP environment variables, which is
# the second spelling of the same hole -- must carry a guid or an explicit exemption marker. That also
# drops the "a mere READER of the temp root is not the subject" carve-out: a reader is now declared
# rather than inferred.
#
# THIS PARAGRAPH IS WORDED TO KEEP THE TWO TOKENS OFF ONE LINE, and that is not fussiness. The scanner in
# test-suite-gate.tests.ps1 reads every line of every file in this directory, comments and string
# literals included, and it flagged an earlier draft of this very comment as a predictable fixture path.
# A guard's own prose is inside the tree its sibling guard measures.
#
# THE EXEMPTION IS A MARKER AT THE SITE, not a match on the line's source text. Three lines cannot carry
# a guid honestly: New-ScratchPath's own composition (it USES the guid built one line above),
# check-claude-home's enumeration of the temp roots, and tidy-machine's walk of the same root -- the last
# two compose nothing at all. Pinning the first by its
# exact text was the first shape, and a rename of $leaf or a reflow of that one line would have turned
# the scan against its own composer. '# temp-path-exempt:' says so where a reader and a diff both see
# it, and the count below is what stops a fourth appearing quietly.
#
# THE COUNT WENT FROM TWO TO THREE ON SEPTEMBER 10, 2026, and the shape of the third is why that is not
# a weakening: tidy-machine.ps1's lane 10 ENUMERATES the temp root to attribute what is already standing
# there, and deletes nothing -- scripts/README.md having already settled that those trees stay standing
# (#1668) and named a pattern sweep as the very delete primitive New-ScratchPath exists to remove
# (#1659). A reader is exactly what this scan is not about. What the count still catches is a fourth
# line that WRITES.
#
# scripts/tests/ is out of scope because it is enforced NEXT DOOR, not because it is unenforced:
# test-suite-gate.tests.ps1 requires a fresh guid in every fixture path, which is the same bar this scan
# applies here. That was not true when this exclusion was written -- the fixture rule then accepted $PID
# ALONE, on the ground that it answered a different question (two concurrent runs tearing down each
# other's tree, not a hostile neighbour), and the measurement was 108 predictable fixture paths across 66
# files with 53 recursive deletes among them. #1664 closed that: 96 sites rewritten, the rule tightened to
# require the guid, and the exclusion is now a division of labour between two guards rather than the edge
# of what is guarded. Do NOT read it as scope this scan should grow into -- a fixture composes its guid
# inline rather than calling New-ScratchPath, for reasons #1664 measured, so extending this scan over
# tests/ would report every one of them.
# Built from fragments so this pattern does not itself read as one of the tokens it hunts -- see the
# paragraph above about a guard's prose living inside the tree its sibling guard measures.
$tempRootPattern = 'Get' + 'TempPath' + '|\$env:TEMP\b|\$env:TMP\b'
$tempOffenders = @()
$tempExempt    = @()
foreach ($f in @(Get-ChildItem -LiteralPath $scriptsRoot -Recurse -Filter '*.ps1' -File |
                 Where-Object { $_.Directory.Name -ne 'tests' })) {
    $n = 0
    foreach ($line in [System.IO.File]::ReadAllLines($f.FullName)) {
        $n++
        $t = $line.Trim()
        if ($t.StartsWith('#'))               { continue }
        if ($t -notmatch $tempRootPattern)    { continue }
        if ($t -match 'temp-path-exempt')     { $tempExempt += ('{0}:{1}' -f $f.Name, $n); continue }
        if ($t -match 'NewGuid')              { continue }
        $tempOffenders += ('{0}:{1}' -f $f.Name, $n)
    }
}
Assert-True ($tempOffenders.Count -eq 0) ('no shipping script composes a temp path without a guid' + $(if ($tempOffenders.Count) { ' -- ' + ($tempOffenders -join ', ') } else { '' }))
Assert-True ($tempExempt.Count -eq 3) ("exactly three lines are declared exempt -- the composer, and the two readers in check-claude-home and tidy-machine (found $($tempExempt.Count): " + ($tempExempt -join ', ') + ')')

# AND THE CONVERSION IS PINNED AT ITS CALL SITES, so a revert to a hand-composed path fails here rather
# than only in the scan above -- which a reverter could satisfy by adding a guid and leaving the class
# scattered again. FIVE CALLER FILES, not five sites: open-pr.ps1 holds two of the seven sites, which is
# why the two counts in this branch differ and why this comment says which unit it is using.
$scratchCallers = @(Get-ChildItem -LiteralPath $scriptsRoot -Recurse -Filter '*.ps1' -File |
                    Where-Object { $_.Directory.Name -ne 'tests' -and $_.Name -ne 'native-capture-lib.ps1' } |
                    Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match 'New-ScratchPath' })
Assert-True ($scratchCallers.Count -ge 5) "the composer is used across the script layer rather than in one place (found $($scratchCallers.Count) files)"
foreach ($expected in @('park-lib.ps1', 'open-pr.ps1', 'ship-pr.ps1', 'verify-resolved-issues.ps1', 'sync-main.ps1')) {
    Assert-True (@($scratchCallers | Where-Object { $_.Name -eq $expected }).Count -eq 1) "$expected composes its temp path through New-ScratchPath"
}

if ($script:fail -eq 0) {
    Write-Host "Result: $($script:pass) pass, 0 fail." -ForegroundColor Green
    exit 0
}
Write-Host "Result: $($script:pass) pass, $($script:fail) fail." -ForegroundColor Red
exit 1
