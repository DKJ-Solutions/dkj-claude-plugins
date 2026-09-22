<#
.SYNOPSIS
    Regression tests for scripts/lib/native-capture-lib.ps1 -- the -Utf8 capture path (issue #907),
    the non-interactive environment + bounded wait (inbound #1179), the shared read of the capture
    files while a killed grandchild still holds a handle (#1252), that this read REPORTS that hold
    instead of leaving a caller to guess what an empty capture on exit 0 meant (#1679), and that an
    unmeasurable exit code is reported (ExitCodeUnknown) and turned into a refusal rather than a
    silent wrong answer at the one caller in this file that would otherwise skip a merge-time gate
    on it (#1931), and that a captured refusal renders as the command's own words rather than as the
    ErrorRecord PowerShell wrapped them in (#2154).

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
    Write-Host 'open-pr passes a PR TITLE through the arm that quotes it (issue #1963)' -ForegroundColor Cyan

    # THE REGRESSION THIS GUARDS. $prTitle is free text -- a changelog heading, or since #1962 a bare
    # commit subject -- and it is the one argument of `gh pr create` a person writes. On the & arm
    # Windows PowerShell 5.1 mis-delivers three shapes, and a title can carry all of them: measured
    # against a real argv parser, 'a b\' + 'next' arrives as the single argument [a b" next], so
    # --body-file, --repo and every label are swallowed into the title. The round-trip block below
    # proves the -Utf8 arm delivers those same shapes intact; this asserts that the call site USES it.
    #
    # A SOURCE ASSERT RATHER THAN A LIVE CALL, deliberately: the alternative is creating a real pull
    # request. The two facts it needs -- which flag the line carries, and that the title is on that
    # same line -- are both readable, and this suite already reads other scripts' source this way.
    $openPr = Join-Path $PSScriptRoot '..\release\open-pr.ps1'
    Assert-True (Test-Path -LiteralPath $openPr) 'open-pr.ps1 is where this suite expects it'
    $createLine = @(Get-Content -LiteralPath $openPr | Where-Object { $_ -match "'pr',\s*'create'" })
    Assert-Equal 1 $createLine.Count               'exactly one `gh pr create` invocation, so the assert below cannot read the wrong one'
    Assert-True  ($createLine[0] -match '-Utf8')   'that invocation carries -Utf8, so a title with a quote or a trailing backslash cannot swallow --body-file, --repo and the labels'
    Assert-True  ($createLine[0] -match '\$prTitle') '...and it is still the line that passes the title, so the assert above is about the right call'

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
    Write-Host 'Get-NativeArgumentDefect -- the exact predicate behind the & arm refusal (issue #1966)' -ForegroundColor Cyan

    # THE NEAR-MISSES ARE THE HALF THAT MATTERS. A guard that over-refuses makes the & arm unusable for
    # ordinary text, so every shape that LOOKS dangerous and is not is pinned here explicitly -- a bare
    # trailing backslash above all, because 'C:\repo\' is an everyday argument and a "refuse every
    # backslash" reading would take it out.
    Assert-Equal 'empty'              (Get-NativeArgumentDefect -Value '')            'the empty string is refused -- the & arm DROPS it, shifting every later argument left'
    Assert-Equal 'quote'              (Get-NativeArgumentDefect -Value 'has"quote')   'a quote is refused wherever it sits'
    Assert-Equal 'quote'              (Get-NativeArgumentDefect -Value 'a "b" c')     '...including one already surrounded by whitespace'
    Assert-Equal 'trailing-backslash' (Get-NativeArgumentDefect -Value 'a b\')        'whitespace plus a trailing backslash is refused -- it escapes the closing quote'
    Assert-Equal 'trailing-backslash' (Get-NativeArgumentDefect -Value 'a b\\')       '...and so is a trailing RUN of them'
    Assert-Equal ''                   (Get-NativeArgumentDefect -Value 'plain')       'a plain value is deliverable'
    Assert-Equal ''                   (Get-NativeArgumentDefect -Value 'a b')         'whitespace alone is deliverable -- PowerShell quotes it correctly'
    Assert-Equal ''                   (Get-NativeArgumentDefect -Value 'trailing\')   'a trailing backslash WITHOUT whitespace is deliverable -- nothing quotes it, so nothing mis-escapes it'
    Assert-Equal ''                   (Get-NativeArgumentDefect -Value 'C:\repo\')    '...which is the everyday case that clause exists to protect'
    Assert-Equal ''                   (Get-NativeArgumentDefect -Value "it's fine")   'a single quote is deliverable'
    Assert-Equal ''                   (Get-NativeArgumentDefect -Value 'a>b&c|d')     'shell metacharacters are deliverable -- CreateProcess has no shell to interpret them'

    # ---------------------------------------------------------------------------------------------
    Write-Host 'Get-NativeArgumentRefusal -- what the message says, and what it must never say' -ForegroundColor Cyan

    Assert-Equal '' (Get-NativeArgumentRefusal -Arguments @('pr', 'create', '--title', 'a normal title')) 'a deliverable list produces no refusal'
    Assert-Equal '' (Get-NativeArgumentRefusal -Arguments @())                                            'an empty LIST is not an empty ARGUMENT -- nothing to refuse'

    $secret = 'https://user:s3cr3t-token@example.invalid/o/r.git"'
    $msg = Get-NativeArgumentRefusal -Arguments @('push', $secret, 'next')
    Assert-True ([bool]$msg)                        'a list carrying an undeliverable argument produces a refusal'
    Assert-True ($msg.Contains('index 1'))          '...naming the INDEX, so the caller can find it in their own code'
    Assert-True ($msg.Contains('quote'))            '...and the SHAPE, so they know what to change'
    Assert-True (-not $msg.Contains('s3cr3t'))      '...and never the VALUE: an argument here can carry a token or a remote URL (#1313)'
    Assert-True (-not $msg.Contains('example.invalid')) '...not even the harmless-looking half of it'
    Assert-True ($msg.Contains('-Utf8'))            '...and it names the way out rather than only the problem'

    $multi = Get-NativeArgumentRefusal -Arguments @('', 'ok', 'a b\')
    Assert-True ($multi.Contains('index 0') -and $multi.Contains('index 2')) 'every undeliverable argument is named, not just the first'
    Assert-True (-not $multi.Contains('index 1'))                            '...and the deliverable one in between is not'

    # ---------------------------------------------------------------------------------------------
    Write-Host 'The & arm refuses the three shapes, and -Utf8 still carries them (issue #1966)' -ForegroundColor Cyan

    function Test-AmpArmThrows {
        param([string]$Value)
        try {
            Invoke-NativeCapture -FilePath 'powershell' -Arguments @('-NoProfile', '-File', $argProbe, $Value) | Out-Null
            return ''
        } catch {
            return [string]$_.Exception.Message
        }
    }

    foreach ($shape in @(
        @{ Value = '';           Label = 'the empty string' },
        @{ Value = 'has"quote';  Label = 'a value carrying a quote' },
        @{ Value = 'a b\';       Label = 'whitespace plus a trailing backslash' }
    )) {
        $thrown = Test-AmpArmThrows -Value $shape.Value
        Assert-True ([bool]$thrown) ("the & arm refuses " + $shape.Label + " rather than mis-delivering it")
        # THE ESCAPE ROUTE IS ASSERTED BESIDE EACH REFUSAL, because a guard whose remedy does not work is
        # a wall. The round-trip block above already proves -Utf8 delivers these; this proves the SAME
        # value that was just refused goes through it.
        $viaUtf8 = Invoke-ArgProbe -Values @($shape.Value, 'next')
        Assert-Equal ('[' + $shape.Value + '] [next]') $viaUtf8 ("...and -Utf8 carries " + $shape.Label + " intact, so the refusal names a remedy that works")
    }

    # NO FALSE NEGATIVES, MEASURED AGAINST A REAL ARGV PARSER RATHER THAN AGAINST THE PREDICATE ITSELF.
    # This is the assert that would catch a shape the predicate misses: every value it calls deliverable
    # is put through the & arm for real and must come back byte-identical. The mirror-image direction --
    # no false positives -- cannot be measured here by construction, because the arm now throws on
    # exactly those; the classification table above is what pins it.
    foreach ($fine in @('plain', 'a b', 'trailing\', 'C:\repo\', "it's fine", 'a>b&c|d', 'a b c d', '--flag=value')) {
        Assert-Equal '' (Get-NativeArgumentDefect -Value $fine) "the predicate calls '$fine' deliverable"
        $r = Invoke-NativeCapture -FilePath 'powershell' -Arguments @('-NoProfile', '-File', $argProbe, $fine, 'next')
        Assert-Equal ('[' + $fine + '] [next]') ((@($r.Output) | ForEach-Object { [string]$_ }) -join ' ') "...and the & arm really does deliver '$fine' intact"
    }

    # ---------------------------------------------------------------------------------------------
    Write-Host 'The & arm returns PLAIN TEXT, and keeps its container (issue #2155)' -ForegroundColor Cyan

    # THE CHILD WRITES THREE STDERR LINES AND THE MIDDLE ONE IS EMPTY, which is the whole measurement.
    # With 2>&1 each arrives as an ErrorRecord, and an ErrorRecord's ToString() falls back to the TYPE
    # NAME when its exception message is empty -- so before #2155 a caller doing 'Output | Out-String'
    # captured a literal 'System.Management.Automation.RemoteException' in the middle of the command's
    # own words. A file rather than an inline -Command, so the bytes written to stderr are known exactly.
    $stderrProbe = Join-Path $sandbox 'stderr3.ps1'
    [System.IO.File]::WriteAllText($stderrProbe,
        "[Console]::Error.WriteLine('error: something went wrong')`r`n" +
        "[Console]::Error.WriteLine('')`r`n" +
        "[Console]::Error.WriteLine('hint: try again')`r`n" +
        "exit 1`r`n",
        (New-Object System.Text.UTF8Encoding $false))

    $merged3 = Invoke-NativeCapture -FilePath 'powershell' -Arguments @('-NoProfile', '-File', $stderrProbe)
    Assert-Equal 1 $merged3.ExitCode 'the exit code still comes back through the normalising pipeline'
    Assert-Equal 3 (@($merged3.Output).Count) 'three stderr lines arrive as three entries'
    foreach ($el in @($merged3.Output)) {
        Assert-True ($el -is [string]) 'every element of Output is a string, never an ErrorRecord'
    }
    Assert-Equal '' (@($merged3.Output)[1]) 'an EMPTY stderr line stays empty -- TargetObject is read, not ToString()'

    # THE RENDER IS WHAT #2154 REPORTED AND WHAT 60-ODD CALL SITES DO, so it is asserted as text rather
    # than only per element. FIVE TELLS, and the list below is the whole of them: the type name
    # RemoteException (what an EMPTY line used to stringify as, which is the half #2154 never saw), the
    # lib file's own name, CategoryInfo, FullyQualifiedErrorId, and the tilde run under the offending
    # statement.
    $rendered = ($merged3.Output | Out-String)
    Assert-True ($rendered.Contains('error: something went wrong')) "the caller's render carries the command's own first line"
    Assert-True ($rendered.Contains('hint: try again'))             '...and its last one'
    foreach ($tell in @('RemoteException', 'native-capture-lib.ps1', 'CategoryInfo', 'FullyQualifiedErrorId', '~~~')) {
        Assert-True (-not $rendered.Contains($tell)) "...and none of PowerShell's own wrapper noise: '$tell'"
    }

    # THE CONTAINER IS DELIBERATELY NOT TOUCHED. Wrapping the pipeline in @() would have been the
    # obvious spelling and would have turned every single-line capture into a 1-element array -- a
    # second behaviour change, riding along on a decision that was only about the element type. These
    # three asserts are what refuse that spelling.
    $noneOut = Invoke-NativeCapture -FilePath 'cmd' -Arguments @('/c', 'exit', '3')
    $oneOut  = Invoke-NativeCapture -FilePath 'cmd' -Arguments @('/c', 'echo hello')
    $manyOut = Invoke-NativeCapture -FilePath 'cmd' -Arguments @('/c', 'echo a& echo b')
    Assert-True ($null -eq $noneOut.Output)      'a command that writes nothing still leaves Output $null, not an empty array'
    # AND ITS EXIT CODE IS ASSERTED BESIDE IT, because this is the one shape where the pipeline carries
    # ZERO objects -- the case where a reader would most expect $LASTEXITCODE to have been lost between
    # the native call and the assignment. It is not, and nothing else in this suite pins that.
    Assert-Equal 3 $noneOut.ExitCode             '...and its exit code survives a pipeline that carried nothing at all'
    Assert-True ($oneOut.Output -is [string])    'a ONE-line capture is still a bare string, not a 1-element array'
    Assert-Equal 2 (@($manyOut.Output).Count)    'a many-line capture is still an array, one entry per line'

    # -DiscardStderr GOES THROUGH THE SAME NORMALISER even though it can never see a record, so a caller
    # reads one shape whichever flag it passed. The assert that matters is that it still DROPS stderr:
    # piping the redirect is where that would break silently.
    $dropped = Invoke-NativeCapture -DiscardStderr -FilePath 'powershell' -Arguments @('-NoProfile', '-File', $stderrProbe)
    Assert-True ($null -eq $dropped.Output) '-DiscardStderr still drops stderr entirely through the pipeline'
    Assert-Equal 1 $dropped.ExitCode        '...and still reports the exit code'

    # ---------------------------------------------------------------------------------------------
    Write-Host 'Get-NativeLineText -- the normaliser itself (issue #2155)' -ForegroundColor Cyan

    Assert-Equal ''      (Get-NativeLineText $null)   'a null line is the empty string, not a null reference'
    Assert-Equal 'plain' (Get-NativeLineText 'plain') 'a string passes through unchanged'

    # TargetObject FIRST, AND THIS IS THE ASSERT THAT PINS THE ORDER. A RemoteException with an empty
    # message is exactly the shape a blank stderr line produces; its ToString() is the type name, so a
    # normaliser reaching for the record itself would return that.
    $blankRec = New-Object System.Management.Automation.ErrorRecord `
        (New-Object System.Management.Automation.RemoteException ''), 'x', 'NotSpecified', ''
    Assert-Equal '' (Get-NativeLineText $blankRec) 'a record wrapping an empty message comes back empty, not as its type name'

    # AND THE FALLBACK IS REACHABLE: a record whose TargetObject is not a string at all -- which is
    # every record that is not a native stderr line -- is read through the exception instead.
    $objRec = New-Object System.Management.Automation.ErrorRecord `
        (New-Object System.Exception 'from the exception'), 'x', 'NotSpecified', 42
    Assert-Equal 'from the exception' (Get-NativeLineText $objRec) 'a non-string TargetObject falls back to the exception message'

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
    Write-Host 'Invoke-TestSuiteGate -- a lane is never handed the gate''s own stdin (#2233)' -ForegroundColor Cyan

    # WHAT WENT WRONG. The pool redirected stdout and stderr and said nothing about stdin, so a lane
    # INHERITED the gate's handle and every grandchild a suite started inherited it in turn. Where the
    # gate itself runs under a pipe nobody closes, a child that reads stdin to end-of-stream blocks
    # forever -- zero CPU, no output, no error -- and #1941's deadline then converts it into a
    # 30-minute red naming a timeout rather than the defect. Measured on DAVE-KOK-BWJ: three suites,
    # four gate runs, four lane counts, every one of the three children hook-shaped and reading a
    # payload from stdin by design; all three passed standalone in seconds.
    #
    # PINNED ON THE SOURCE FIRST, because the behavioural assert below can only reach the spawn sites
    # that exist today. The gate has had two since #1723 added the crash re-run, and that re-run is the
    # dangerous one -- it waits UNBOUNDED, so a wedge there has no deadline to convert it into anything
    # at all. A third site added later fails here rather than being found by nobody.
    $gateSpawns = @([regex]::Matches($gateBody, '(?s)Start-Process -FilePath ''powershell''.*?(?=\r?\n\s*\$null = \$)'))
    Assert-True ($gateSpawns.Count -ge 2) 'the gate still has both of its spawn sites -- the pool and the crash re-run'
    $withoutStdin = @($gateSpawns | Where-Object { $_.Value -notmatch '-RedirectStandardInput' })
    Assert-Equal 0 $withoutStdin.Count 'every Start-Process in the gate redirects stdin, so no lane can inherit the gate''s own handle'

    # AND THEN THE MECHANISM ITSELF, because the source assert only proves the flag is typed. This runs
    # the real pool over a fixture suite whose GRANDCHILD reads stdin to end-of-stream -- the shape that
    # was measured, and strictly stronger than a suite reading it directly, since it also proves the
    # empty handle is inherited down the tree. The gate is started from a parent holding stdin OPEN and
    # never closing it: that is the condition, and without it the fixture reaches EOF for the wrong
    # reason and the test passes while proving nothing.
    $stdinFx = New-ScratchPath -Label 'gate-stdin-2233' -Directory
    Set-Content -LiteralPath (Join-Path $stdinFx 'grandchild.ps1') -Encoding UTF8 -Value @'
if ([Console]::IsInputRedirected) { $null = [Console]::In.ReadToEnd() }
exit 0
'@
    Set-Content -LiteralPath (Join-Path $stdinFx 'stdin.tests.ps1') -Encoding UTF8 -Value @'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'grandchild.ps1')
exit $LASTEXITCODE
'@
    $stdinRunner = Join-Path $stdinFx 'run-gate.ps1'
    Set-Content -LiteralPath $stdinRunner -Encoding UTF8 -Value @"
. '$((Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1'))'
`$ok = Invoke-TestSuiteGate -TestsDir '$stdinFx' -Context 'the #2233 fixture' -MaxParallel 1 -SuiteTimeoutSeconds 25
Write-Output "GATE-VERDICT=`$ok"
"@

    # A BOUND ON THE OUTER WAIT TOO. The fixture's own suite bound is 25s, so a regression shows up as a
    # red gate at ~25s; this only has to outlast that. A kill on the way out, because a wedged tree left
    # behind is the very thing this suite is about.
    $stdinPsi = New-Object System.Diagnostics.ProcessStartInfo
    $stdinPsi.FileName  = 'powershell'
    $stdinPsi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$stdinRunner`""
    $stdinPsi.UseShellExecute        = $false
    $stdinPsi.RedirectStandardInput  = $true    # opened, written to by nobody, and never closed
    $stdinPsi.RedirectStandardOutput = $true
    $stdinPsi.RedirectStandardError  = $true
    $stdinProc = [System.Diagnostics.Process]::Start($stdinPsi)
    $stdinOut  = $stdinProc.StandardOutput.ReadToEndAsync()
    $stdinExited = $stdinProc.WaitForExit(120000)
    if (-not $stdinExited) { Stop-NativeProcessTree -ProcessId $stdinProc.Id | Out-Null }
    Assert-True $stdinExited 'the gate returns at all when its own stdin is an open handle nobody closes'
    Assert-True ($stdinExited -and ($stdinOut.Result -match 'GATE-VERDICT=True')) `
                'and it goes GREEN -- the lane''s grandchild read an empty stdin and exited instead of blocking on the gate''s handle'

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
    Write-Host 'Invoke-NativeCapture -- ExitCodeUnknown is present on BOTH arms (#1931)' -ForegroundColor Cyan

    # SAME PROMISE AS ShortRead AND TimedOut: a caller reads one field whichever arm answered it. An
    # ordinary clean child on either arm must not cry ExitCodeUnknown any more than it cries ShortRead.
    Assert-True ($null -ne $ampRun.PSObject.Properties['ExitCodeUnknown']) 'the & arm returns an ExitCodeUnknown field'
    Assert-True (-not $ampRun.ExitCodeUnknown) 'and it is false on an ordinary git call -- $LASTEXITCODE needs no OS process handle, so this arm is not exposed to the race'
    Assert-True ($null -ne $utf8Run.PSObject.Properties['ExitCodeUnknown']) 'the -Utf8 arm returns an ExitCodeUnknown field'
    Assert-True (-not $utf8Run.ExitCodeUnknown) 'and an ordinary clean child is not an unknown exit either -- the probe must not cry wolf on the normal case'

    # A TIMED-OUT CALL IS NEVER ExitCodeUnknown, even though its own ExitCode is a SUBSTITUTED number
    # rather than a measurement of the child (issue #1179's own timeout code). Substituted-on-purpose
    # and unmeasured are different states, and TimedOut already says which one a caller has -- so this
    # field must not double-report the same fact under a different name.
    $timeoutHang = Join-Path $sandbox 'unknown-hang.ps1'
    Set-Content -LiteralPath $timeoutHang -Encoding Ascii -Value 'Start-Sleep -Seconds 30'
    $timeoutRun = Invoke-NativeCapture -FilePath 'powershell' -Arguments @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $timeoutHang) -TimeoutSeconds 1
    Assert-True $timeoutRun.TimedOut 'the fixture actually timed out, so the assert below is about the field and not about a fluke'
    Assert-True ($null -ne $timeoutRun.PSObject.Properties['ExitCodeUnknown']) 'a timed-out call still returns an ExitCodeUnknown field'
    Assert-True (-not $timeoutRun.ExitCodeUnknown) 'and it is false -- the substituted timeout code is a verdict this function chose, not an unmeasured read'

    # ---------------------------------------------------------------------------------------------
    Write-Host 'Invoke-NativeCapture -- a MISSING EXECUTABLE is a verdict, not an exception (#2234)' -ForegroundColor Cyan

    # THE DEFECT, AND WHY IT IS ASSERTED ON BOTH ARMS RATHER THAN ON THE ONE #2234 MEASURED. The report
    # measured Start-Process raising InvalidOperationException. The & arm threw too, earlier and for a
    # different reason -- CommandNotFoundException out of command DISCOVERY, which is terminating
    # regardless of $ErrorActionPreference, so this function's own EAP dance never reached it. A repair
    # on one arm would have left the other fatal, so both are pinned.
    #
    # THE NAME IS UNRUNNABLE BY CONSTRUCTION, not merely unlikely: a guid suffix cannot collide with
    # something a developer happens to have installed, which is the one way this block could go green
    # for the wrong reason on somebody else's machine.
    $missingExe = 'no-such-exe-2234-' + [guid]::NewGuid().ToString('n')

    foreach ($shape in @(
        @{ Name = 'the & arm';        Args = @{} }
        @{ Name = 'the -Utf8 arm';    Args = @{ Utf8 = $true } }
        @{ Name = 'a bounded call';   Args = @{ TimeoutSeconds = 5 } }
        @{ Name = '-DiscardStderr';   Args = @{ DiscardStderr = $true } }
    )) {
        # SPLATTED THROUGH A NAMED VARIABLE, because @($shape.Args) is an array subexpression rather than
        # a splat -- it passes the hashtable as a positional ARGUMENT, which this function rejects with a
        # parameter-transformation error that looks exactly like the throw this block is testing for.
        # Caught while probing the repair, which is the only reason it is not in the diff as a false green.
        $shapeArgs = $shape.Args
        $notStarted = $null
        $threw = $false
        try {
            $notStarted = Invoke-NativeCapture -FilePath $missingExe -Arguments @('x') @shapeArgs
        } catch { $threw = $true }

        Assert-True (-not $threw) "$($shape.Name) returns instead of throwing on a missing executable -- the whole point of #2234, since a caller's EAP='Stop' turned this into a dead run"
        Assert-True ($null -ne $notStarted.PSObject.Properties['NotStarted']) "$($shape.Name) returns a NotStarted field"
        Assert-True $notStarted.NotStarted "...and it is true, which is the only field that says the child never ran"
        Assert-True ($null -eq $notStarted.ExitCode) "...with a NULL ExitCode: there is no exit code, and a substituted number would be a verdict this lib invented"
        Assert-True $notStarted.ExitCodeUnknown "...and ExitCodeUnknown SET, deliberately -- that is what keeps the 56 sites audited under #2081 correct without being touched"
        Assert-True (-not $notStarted.TimedOut) "...and TimedOut false: nothing was waited on"
        Assert-True (-not $notStarted.ShortRead) "...and ShortRead false: no capture file was read"
        Assert-True ((@($notStarted.Output) -join "`n") -match '\[not-started\]') "...and the diagnosis is in Output, where every existing caller already looks"
        Assert-True ((@($notStarted.Output) -join "`n") -match [regex]::Escape($missingExe)) "...naming the command, so console scrollback alone identifies which call it was"
    }

    # THE PREFERENCE IS RESTORED, which the early return out of the catch could easily have skipped --
    # both arms return from INSIDE the try whose finally does the restoring, and a reader cannot tell
    # from the diff that PowerShell runs it. This is the assert that says so.
    $eapBefore = $ErrorActionPreference
    $null = Invoke-NativeCapture -FilePath $missingExe -Arguments @('x')
    Assert-Equal $eapBefore $ErrorActionPreference 'a not-started call restores $ErrorActionPreference -- the finally still runs on the early return'

    # AND AN ORDINARY CALL IS UNTOUCHED ON BOTH ARMS. The guard catches ONE named exception type each;
    # a bare catch would have handed back "not started" for a child's own terminating failures, which is
    # a wrong answer arriving as a plausible value.
    Assert-True ($null -ne $ampRun.PSObject.Properties['NotStarted']) 'the & arm reports NotStarted on an ordinary call too -- one field whichever arm answered'
    Assert-True (-not $ampRun.NotStarted) '...and it is false there'
    Assert-True ($null -ne $utf8Run.PSObject.Properties['NotStarted']) 'the -Utf8 arm reports NotStarted on an ordinary call too'
    Assert-True (-not $utf8Run.NotStarted) '...and it is false there'
    Assert-True (-not $timeoutRun.NotStarted) 'a TIMED-OUT call started fine -- a stall is the opposite of a launch failure, and must not be reported as one'

    # A FILE THAT IS FOUND AND CANNOT BE LAUNCHED IS THE SECOND LAUNCH FAILURE, and it is pinned because
    # the two arms reached it by different exceptions and only one of them was caught at first. The & arm
    # raises ApplicationFailedException (command discovery SUCCEEDS, the Win32 loader then refuses the
    # image); Start-Process raises InvalidOperationException for this exactly as it does for a missing
    # file. So the -Utf8 arm returned a verdict here while the & arm still threw -- against a docstring
    # promising both. Caught in review, then measured, then repaired.
    #
    # NOT A HYPOTHETICAL SHAPE: Resolve-NativeApplicationPath exists because npm drops an extensionless
    # shim beside its '.cmd', and handing that to the loader fails in exactly this way.
    $bogusExe = Join-Path $sandbox 'bogus-2234.exe'
    Set-Content -LiteralPath $bogusExe -Encoding Ascii -Value 'this is not a PE image'
    foreach ($shape in @(
        @{ Name = 'the & arm';     Args = @{} }
        @{ Name = 'the -Utf8 arm'; Args = @{ Utf8 = $true } }
    )) {
        $shapeArgs = $shape.Args
        $unlaunchable = $null
        $threw = $false
        try { $unlaunchable = Invoke-NativeCapture -FilePath $bogusExe @shapeArgs } catch { $threw = $true }
        Assert-True (-not $threw) "$($shape.Name) returns on a file that is FOUND but cannot be launched -- a different exception from a missing one, and the arms raise different types for it"
        Assert-True $unlaunchable.NotStarted "...and reports it as NotStarted, because the child still never ran"
    }

    # A COMMAND THAT EXISTS AND FAILS IS NOT A LAUNCH FAILURE. The distinction this whole state rests on
    # is "never ran" against "ran and failed", so the second one is pinned rather than assumed.
    $ranAndFailed = Invoke-NativeCapture -FilePath 'git' -Arguments @('rev-parse', '--verify', 'no-such-ref-2234') -DiscardStderr
    Assert-True (-not $ranAndFailed.NotStarted) 'a command that RAN and returned non-zero is not NotStarted -- the field is about the launch, not about success'
    Assert-True ($ranAndFailed.ExitCode -ne 0) '...and the fixture really did fail, so the assert above is about the field and not about a fluke'

    # ---------------------------------------------------------------------------------------------
    Write-Host 'Get-NativeOutputText -- a refusal reads as the COMMAND said it (issue #2154)' -ForegroundColor Cyan

    # THE DEFECT. On the & arm every stderr line arrives as an ErrorRecord wrapping a RemoteException,
    # and under PowerShell 5.1 that record carries its own positional info. Out-String renders all of
    # it, so prune-merged's refused-delete verdict printed git's single line followed by a
    # CategoryInfo/FullyQualifiedErrorId block and a source-line caret pointing into
    # native-capture-lib.ps1 -- naming a file the operator did not run and cannot act on.
    #
    # A REAL REFUSED DELETE RATHER THAN A HAND-BUILT ErrorRecord, because the wrapping is the subject:
    # a fixture that constructs the record itself would assert this suite's idea of the shape, not the
    # one PowerShell actually produces at the call site.
    $refRepo = Join-Path $sandbox 'refusal-repo'
    New-Item -ItemType Directory -Path $refRepo -Force | Out-Null
    Invoke-NativeCapture -FilePath 'git' -Arguments @('init', '-q', $refRepo) | Out-Null
    $gitIn = @('-C', $refRepo)
    Invoke-NativeCapture -FilePath 'git' -Arguments ($gitIn + @('config', 'user.email', 'tests@example.invalid')) | Out-Null
    Invoke-NativeCapture -FilePath 'git' -Arguments ($gitIn + @('config', 'user.name', 'tests')) | Out-Null
    Set-Content -LiteralPath (Join-Path $refRepo 'a.txt') -Encoding Ascii -Value 'a'
    Invoke-NativeCapture -FilePath 'git' -Arguments ($gitIn + @('add', '-A')) | Out-Null
    Invoke-NativeCapture -FilePath 'git' -Arguments ($gitIn + @('commit', '-qm', 'one')) | Out-Null
    $baseRef = (Get-NativeOutputText (Invoke-NativeCapture -FilePath 'git' -Arguments ($gitIn + @('rev-parse', '--abbrev-ref', 'HEAD'))).Output)
    Invoke-NativeCapture -FilePath 'git' -Arguments ($gitIn + @('checkout', '-qb', 'unmerged-fixture')) | Out-Null
    Set-Content -LiteralPath (Join-Path $refRepo 'b.txt') -Encoding Ascii -Value 'b'
    Invoke-NativeCapture -FilePath 'git' -Arguments ($gitIn + @('add', '-A')) | Out-Null
    Invoke-NativeCapture -FilePath 'git' -Arguments ($gitIn + @('commit', '-qm', 'two')) | Out-Null
    Invoke-NativeCapture -FilePath 'git' -Arguments ($gitIn + @('checkout', '-q', $baseRef)) | Out-Null

    $refusal = Invoke-NativeCapture -FilePath 'git' -Arguments ($gitIn + @('branch', '-d', 'unmerged-fixture'))
    Assert-True ($refusal.ExitCode -ne 0) 'the fixture really was refused, so everything below is about a refusal and not about a fluke'

    $new = Get-NativeOutputText $refusal.Output

    # THE OLD RENDER IS PINNED TOO, and it is the assert that keeps the rest honest: without it, a
    # future PowerShell that stopped wrapping stderr would turn this whole section green while proving
    # nothing.
    #
    # IT IS SOURCED FROM A RAW '&' RATHER THAN FROM $refusal SINCE #2155, and the move is the point
    # rather than a workaround. Invoke-NativeCapture's & arm now normalises, so a capture no longer
    # carries records and this contrast reproduced nothing off one -- which read as "the defect is
    # gone" when what had gone was only this lib's own exposure to it. PowerShell still wraps stderr
    # exactly as before for anybody calling '&' directly, and that is the shape Get-NativeOutputText
    # still has a job on: an Output handed across from a CONSUMER on an older plugin release, where
    # the & arm had not been repaired yet. So the fixture is now that shape, deliberately.
    $rawPrev = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $rawRefusal = & git @gitIn branch -d unmerged-fixture 2>&1
    } finally { $ErrorActionPreference = $rawPrev }

    Assert-True (@($rawRefusal | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count -gt 0) `
        'a raw & call still wraps stderr in ErrorRecords -- the shape the helper exists for has not gone away'
    $old = ($rawRefusal | Out-String).Trim()
    Assert-True ($old -match 'CategoryInfo')            'Out-String really does render the exception block -- the defect reproduces on a raw call'
    Assert-True ($old -match 'native-capture-lib\.ps1|\.tests\.ps1') '...including a caret naming the file that ran the command'
    Assert-True ((Get-NativeOutputText $rawRefusal) -notmatch 'CategoryInfo') `
        '...and the helper strips it off THAT Output too, which is the older-consumer case in one assert'

    # AND THE CAPTURE ITSELF NO LONGER CARRIES RECORDS, which is #2155 measured from this block's side.
    Assert-True (@(@($refusal.Output) | Where-Object { $_ -isnot [string] }).Count -eq 0) `
        "the same refusal through Invoke-NativeCapture holds only strings -- #2155 closed this defect at the source, and this section's subject is now what reaches the helper from ELSEWHERE"

    Assert-True ($new -match 'not fully merged')          "the helper keeps git's own reason, which is the whole of what the reader needed"
    Assert-True ($new -notmatch 'CategoryInfo')           'and drops the CategoryInfo line'
    Assert-True ($new -notmatch 'FullyQualifiedErrorId')  '...the FullyQualifiedErrorId line'
    Assert-True ($new -notmatch 'NativeCommandError')     '...the wrapper exception id'
    Assert-True ($new -notmatch 'native-capture-lib')     '...and the source-line caret pointing into this lib'
    Assert-True ($new -match "git branch -D unmerged-fixture") "git's own hint survives -- the repair must not trade an exception dump for a truncation"

    # THE SUCCESS PATH IS UNCHANGED, which is what makes this safe to use at a site that renders both.
    $plain = Invoke-NativeCapture -FilePath 'git' -Arguments @('--version')
    Assert-Equal (($plain.Output | Out-String).Trim()) (Get-NativeOutputText $plain.Output) 'on plain stdout the helper agrees with Out-String exactly -- it normalises the wrapper, not the text'

    Assert-Equal ''      (Get-NativeOutputText $null)          'a null Output is the empty string rather than a throw -- a caller renders a reason without first testing for one'
    Assert-Equal 'solo'  (Get-NativeOutputText 'solo')         'a single string that never went through the pipeline is passed through'
    Assert-Equal "a`nb"  (Get-NativeOutputText @('a', 'b'))    'an array is joined on newlines, so a multi-line reason stays multi-line'

    # AND THE MEASURED CALL SITE USES IT. Same source-assert shape as the open-pr block above, and for
    # the same reason: the property that matters is which spelling the call site carries, and asserting
    # it live would mean driving prune-merged against a real checkout with a branch it would refuse.
    $pruneSrc = Join-Path $PSScriptRoot '..\task\prune-merged.ps1'
    Assert-True (Test-Path -LiteralPath $pruneSrc) 'prune-merged.ps1 is where this suite expects it'
    $refusedLine = @(Get-Content -LiteralPath $pruneSrc | Where-Object { $_ -match 'git branch \$flag refused' })
    Assert-Equal 1 $refusedLine.Count                                'exactly one refused-delete verdict, so the assert below cannot read the wrong one'
    Assert-True  ($refusedLine[0] -match 'Get-NativeOutputText')     'and it renders the reason through the helper rather than through Out-String'

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

    # ---------------------------------------------------------------------------------------------
    Write-Host 'Get-GitFileTextAtRef -- an unmeasurable exit code THROWS rather than reading as absent (#1931)' -ForegroundColor Cyan

    # WHY THIS THROWS AND Get-TrunkGap/Get-GitPorcelainStatus DO NOT (documented at length on the
    # function itself): this function's own return shape already conflates "path absent" and "could
    # not tell" into one $null, and its one caller (ship-pr.ps1's step-list gate + DEPLOY lock) reads
    # that $null as "nothing to check" and SKIPS BOTH GATES. A silent skip of a merge-time content
    # gate is worse than a hard stop, so ExitCodeUnknown is turned into a throw here rather than into
    # a third return state nothing downstream is built to read.
    #
    # SHADOWED AFTER THE DOT-SOURCE, the pattern this lib documents for itself and
    # remote-ahead-lib.tests.ps1 already uses: a plain function can be redefined in the scope that
    # dot-sourced it, and Get-GitFileTextAtRef resolves Invoke-NativeCapture's name at call time. Only
    # the 'show' call is stubbed; everything else this suite has already run through it (the fixture's
    # own `git` calls above) went through the real one.
    $script:realNativeCaptureForRef = (Get-Command Invoke-NativeCapture -CommandType Function).ScriptBlock
    $script:stubShowUnknown = $false
    function Invoke-NativeCapture {
        param(
            [Parameter(Mandatory = $true)][string]$FilePath,
            [string[]]$Arguments = @(),
            [switch]$DiscardStderr,
            [switch]$Utf8,
            [int]$TimeoutSeconds = 0
        )
        if ($script:stubShowUnknown -and $Arguments -contains 'show') {
            return [pscustomobject]@{ Output = @(); ExitCode = $null; TimedOut = $false; ShortRead = $false; ExitCodeUnknown = $true }
        }
        return & $script:realNativeCaptureForRef -FilePath $FilePath -Arguments $Arguments `
                                                  -DiscardStderr:$DiscardStderr -Utf8:$Utf8 -TimeoutSeconds $TimeoutSeconds
    }
    try {
        $script:stubShowUnknown = $true
        $threw = $false
        $threwMessage = ''
        try {
            Get-GitFileTextAtRef -Ref 'refs/heads/main' -Path 'cycle.md' -RepoRoot $gitFx | Out-Null
        } catch {
            $threw = $true
            $threwMessage = $_.Exception.Message
        }
        Assert-True $threw 'an unmeasurable exit code throws instead of returning a value'
        Assert-True ($threwMessage -match '1931') 'and the message names the issue, for a reader who catches it two frames up'
        Assert-True ($threwMessage -match 'measurable exit code') 'and says WHAT could not be measured, not just that something failed'
    } finally {
        # RESTORED IMMEDIATELY, so a later suite failure does not leave the real capture stubbed for
        # whatever runs after this file in the same process (the test gate reuses no process across
        # suites, but a developer running this file interactively from a shared shell might).
        $script:stubShowUnknown = $false
        Remove-Item Function:\Invoke-NativeCapture -ErrorAction SilentlyContinue
        . (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')
    }

    # THE REAL FUNCTION IS BACK, so the ordinary (measured) case still reads a real answer -- proof the
    # restore above worked rather than merely not-erroring.
    Assert-Equal $committed.TrimEnd("`n") (Get-GitFileTextAtRef -Ref 'refs/heads/main' -Path 'cycle.md' -RepoRoot $gitFx) 'and the ordinary read is unaffected once the stub is gone'

    # ---------------------------------------------------------------------------------------------
    Write-Host "Resolve-NativeApplicationPath -- npm's three-shim layout on Windows (#1988)" -ForegroundColor Cyan

    # REPRODUCED RATHER THAN MOCKED. npm's global install on Windows drops three files for one bin --
    # an extensionless POSIX script, a '.cmd', and a '.ps1' -- all in the same PATH entry. Start-Process
    # resolves a bare name via CreateProcess's own search, which matches the extensionless file FIRST
    # and hands it to the Win32 loader, which fails with "%1 is not a valid Win32 application". This is
    # the same three-file shape 'Get-Command claude -All' shows on the machine this issue was filed
    # from -- confirmed by direct inspection before this fix, not assumed.
    $shimDir = Join-Path $sandbox 'npm-shim-1988'
    New-Item -ItemType Directory -Path $shimDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $shimDir 'probe1988')     -Value "#!/bin/sh`necho posix-shim" -NoNewline
    Set-Content -LiteralPath (Join-Path $shimDir 'probe1988.ps1') -Value "Write-Output 'ps1-shim'" -NoNewline
    Set-Content -LiteralPath (Join-Path $shimDir 'probe1988.cmd') -Value "@echo off`r`necho cmd-shim`r`n" -NoNewline

    $prevPath = $env:PATH
    try {
        $env:PATH = "$shimDir;$env:PATH"
        $r = Invoke-NativeCapture -Utf8 -FilePath 'probe1988' -Arguments @()
        Assert-Equal 0      $r.ExitCode  'the .cmd shim launches -- not the Win32-loader failure on the extensionless file'
        Assert-Equal $false $r.TimedOut  'and it is not read as a timeout either'
        Assert-True ((@($r.Output) -join '') -like '*cmd-shim*') 'and its own output is captured -- proof Start-Process got the .cmd, not the .ps1 or the bare file'
    } finally {
        $env:PATH = $prevPath
    }

    # A NAME THAT ALREADY NAMES A SPECIFIC FILE IS NEVER RESOLVED FURTHER -- the resolver only widens
    # the pool for a bare, PATH-searched name.
    $cmdPath = Join-Path $shimDir 'probe1988.cmd'
    Assert-Equal $cmdPath (Resolve-NativeApplicationPath -FilePath $cmdPath) 'a path that already names a file is left untouched'

    # A GENUINELY MISSING COMMAND IS STILL REPORTED AS MISSING -- the resolver hands the name back
    # unchanged rather than silently matching something else, so Start-Process fails exactly as before.
    Assert-Equal 'a-command-that-does-not-exist-1988' (Resolve-NativeApplicationPath -FilePath 'a-command-that-does-not-exist-1988') 'nothing to resolve to -- unchanged, not swallowed'
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

# --- THE HOOK NETWORK BUDGET (issue #1958) --------------------------------------------------------
# The four functions exist so a script running under a hook's ceiling can give each network call what is
# LEFT of one deadline rather than the shared per-call bound -- three calls bounded at 120 s apiece
# cannot fit under a 60 s ceiling however honest each of them is.
#
# THE NO-BUDGET SHAPE IS ASSERTED FIRST AND HARDEST, because it is what every by-hand run gets: if it
# ever stopped resolving to the standing bound, park-branch, new-branch and a typed park-cycle would all
# quietly acquire a deadline nobody asked them to finish inside.
Write-Host "== hook network budget ==" -ForegroundColor Cyan

$noBudget = New-NativeCaptureBudget
Assert-True (-not (Test-NativeCaptureBudgetSet -Budget $noBudget))        'no budget: an unspecified budget is not set'
Assert-True (Test-NativeCaptureBudgetHasRoom -Budget $noBudget)           'no budget: every call has room'
Assert-Equal (Get-NativeCaptureBudgetBound -Budget $noBudget) $NativeCaptureNetworkTimeoutSeconds 'no budget: the bound is the standing per-call number'
Assert-Equal (Get-NativeCaptureBudgetBound -Budget $null)     $NativeCaptureNetworkTimeoutSeconds '$null is treated as no budget, not as a spent one'
Assert-True (Test-NativeCaptureBudgetHasRoom -Budget $null)              '$null has room -- a missing budget must never block a call'

# A LIVE BUDGET, GENEROUS. Larger than the standing bound, so the standing bound is what caps the call:
# a budget is a ceiling on the RUN, never a licence to exceed the per-call number.
$wide = New-NativeCaptureBudget -TotalSeconds ($NativeCaptureNetworkTimeoutSeconds + 60)
Assert-True (Test-NativeCaptureBudgetSet -Budget $wide)                  'live budget: it is set'
Assert-True (Test-NativeCaptureBudgetHasRoom -Budget $wide)              'live budget: it has room'
Assert-Equal (Get-NativeCaptureBudgetBound -Budget $wide) $NativeCaptureNetworkTimeoutSeconds 'live budget: a budget wider than the per-call bound does not raise it'

# A LIVE BUDGET, NARROWER THAN THE PER-CALL BOUND -- the hook's own case, where the budget is what caps.
$narrow = New-NativeCaptureBudget -TotalSeconds 30
Assert-True ((Get-NativeCaptureBudgetBound -Budget $narrow) -le 30)      'narrow budget: the bound is no more than what is left'
Assert-True ((Get-NativeCaptureBudgetBound -Budget $narrow) -ge 25)      'narrow budget: and it is very nearly all of it'

# A SPENT BUDGET, BUILT BY HAND RATHER THAN WAITED FOR. The object is a plain expiry instant precisely so
# a test can reach this arm without sleeping through it.
$spent = [pscustomobject]@{ TotalSeconds = 45; Expires = (Get-Date).ToUniversalTime().AddSeconds(-5) }
Assert-True (Test-NativeCaptureBudgetSet -Budget $spent)                 'spent budget: it is still a budget'
Assert-Equal (Get-NativeCaptureBudgetSecondsLeft -Budget $spent) 0       'spent budget: nothing is left, and it is not negative'
Assert-True (-not (Test-NativeCaptureBudgetHasRoom -Budget $spent))      'spent budget: there is no room, so the caller skips the call'

# AND THE BOUND IT WOULD HAND OUT IS NEVER 0. 0 is Invoke-NativeCapture's UNBOUNDED value, so a guard
# failing open here would turn a spent budget into the unbounded call the whole mechanism exists to stop.
Assert-True ((Get-NativeCaptureBudgetBound -Budget $spent) -gt 0)        'spent budget: the bound is never 0 -- 0 means unbounded'
Assert-Equal (Get-NativeCaptureBudgetBound -Budget $spent) $NativeCaptureHookNetworkFloorSeconds 'spent budget: it falls back to the floor'

# --- THE DEADLINE STATED ABSOLUTELY (issue #2077) -------------------------------------------------
# A duration is measured from whenever the factory was called, which for a script under a hook is after
# its start-up and its dot-sources -- time the hook's ceiling has already spent. -ExpiresUtc lets a
# caller that KNOWS when the turn falls due say so, and it is what makes a budget's behaviour independent
# of how loaded the machine was between launch and that line.
#
# THE LOWER BOUND IS DERIVED FROM A STOPWATCH, NOT A FIXED CONSTANT (issue #2318). A 25s floor on a 30s
# budget is a 5-second allowance for four cheap calls that should cost microseconds -- so on a loaded
# shared runner it measured the runner's responsiveness for those four lines, not whether SecondsLeft
# reports the budget's own remaining time correctly. Bracketing the same window with a Stopwatch (the
# idiom already used above for $sw/$flushWatch/$calWatch) makes the assert self-relative: whatever the
# runner actually cost between building the budget and reading it is exactly what this floor allows for,
# so it passes under any load and still catches a wrong calculation.
$absoluteWatch = [System.Diagnostics.Stopwatch]::StartNew()
$absolute = New-NativeCaptureBudget -ExpiresUtc ((Get-Date).ToUniversalTime().AddSeconds(30))
Assert-True (Test-NativeCaptureBudgetSet -Budget $absolute)             'absolute deadline: it is a set budget'
Assert-True (Test-NativeCaptureBudgetHasRoom -Budget $absolute)         'absolute deadline: 30s out, it has room'
$absoluteSecondsLeft = Get-NativeCaptureBudgetSecondsLeft -Budget $absolute
$absoluteWatch.Stop()
$absoluteFloor = 30 - [int][Math]::Ceiling($absoluteWatch.Elapsed.TotalSeconds) - 1
Assert-True ($absoluteSecondsLeft -le 30) 'absolute deadline: no more is left than the instant allows'
Assert-True ($absoluteSecondsLeft -ge $absoluteFloor) "absolute deadline: within the $($absoluteWatch.Elapsed.TotalSeconds.ToString('0.00'))s this run actually spent building and reading it (left=$absoluteSecondsLeft, floor=$absoluteFloor)"

# IT WINS OVER -TotalSeconds where both are given -- the most specific of the knobs, which is the same
# ordering park-cycle.ps1 states for its three. Asserted because the precedence is the whole contract:
# silently preferring the duration would put the budget back on the clock this repair took it off.
$bothGiven = New-NativeCaptureBudget -TotalSeconds 600 -ExpiresUtc ((Get-Date).ToUniversalTime().AddSeconds(10))
Assert-True ((Get-NativeCaptureBudgetSecondsLeft -Budget $bothGiven) -le 10) 'absolute deadline: it wins over -TotalSeconds, it does not lose to it'

# A DEADLINE ALREADY PAST IS SET AND SPENT, never "no budget". The two mean opposite things at the call
# site -- no budget lets every call through -- so a turn whose ceiling has already fallen due must land
# on the refusal and not on the open door.
$past = New-NativeCaptureBudget -ExpiresUtc ((Get-Date).ToUniversalTime().AddSeconds(-5))
Assert-True (Test-NativeCaptureBudgetSet -Budget $past)                  'a past deadline is still a budget, not the no-budget shape'
Assert-True (-not (Test-NativeCaptureBudgetHasRoom -Budget $past))       'and it has no room -- the call is skipped, not let through'
Assert-Equal $past.TotalSeconds 0                                       'its TotalSeconds is floored at 0, so the object never reports a negative budget'

# AND THE DEFAULT IS UNTOUCHED: no -ExpiresUtc means the duration path, byte for byte as before.
Assert-True (-not (Test-NativeCaptureBudgetSet -Budget (New-NativeCaptureBudget))) 'no -ExpiresUtc and no -TotalSeconds is still the no-budget shape'

# A BUDGET INSIDE THE FLOOR HAS NO ROOM EITHER -- the half the issue asked about: a call given two
# seconds reports no more than a call never made, and it spends the margin the kill and the report need.
$sliver = [pscustomobject]@{ TotalSeconds = 45; Expires = (Get-Date).ToUniversalTime().AddSeconds($NativeCaptureHookNetworkFloorSeconds - 1) }
Assert-True (-not (Test-NativeCaptureBudgetHasRoom -Budget $sliver))     'sliver budget: under the floor there is no room'

# A MALFORMED BUDGET COSTS THE BOUND, NEVER THE RUN. Set-StrictMode -Version Latest throws on a property
# an object does not carry, and these functions are loaded by scripts whose whole contract is never to
# fail -- so an object with no Expires must read as "no budget" rather than as an exception.
$malformed = [pscustomobject]@{ TotalSeconds = 45 }
Assert-True (-not (Test-NativeCaptureBudgetSet -Budget $malformed))      'malformed budget: it reads as unset rather than throwing'
Assert-Equal (Get-NativeCaptureBudgetBound -Budget $malformed) $NativeCaptureNetworkTimeoutSeconds 'malformed budget: and the call keeps the standing bound'

# --- THE DEADLINE STATED IN A FILE, RE-READ AS THE RUN GOES (issue #2307) -------------------------
# -ExpiresUtc above fixes the instant at birth, which is what a hook wants and what a SUITE cannot use:
# proving that the second network call gets what the first one left needs a budget healthy at one call
# and spent at the next, and with a fixed deadline the only way to get from one to the other is to WAIT.
# That wait is also the case's tolerance for start-up, so the two are one number -- measured red twice on
# a loaded runner. -ExpiresFile makes the instant restatable, so the transition costs no wall clock.
$deadlineFile = New-ScratchPath -Label 'budget-deadline' -Extension '.txt'
try {
    [System.IO.File]::WriteAllText($deadlineFile, "$([System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + 3600)")
    $lateBound = New-NativeCaptureBudget -ExpiresFile $deadlineFile
    Assert-True (Test-NativeCaptureBudgetSet -Budget $lateBound)          'deadline file: it is a set budget'
    Assert-True (Test-NativeCaptureBudgetHasRoom -Budget $lateBound)      'deadline file: an hour out, it has room'

    # THE WHOLE POINT, IN ONE ASSERT: the SAME object answers differently once the file moves, with no
    # clock having advanced. This is what a fixed deadline can only reach by waiting.
    [System.IO.File]::WriteAllText($deadlineFile, "$([System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + 3)")
    Assert-True ((Get-NativeCaptureBudgetSecondsLeft -Budget $lateBound) -le 3) 'deadline file: restating it mid-run is read on the next question'
    Assert-True (-not (Test-NativeCaptureBudgetHasRoom -Budget $lateBound))     'deadline file: and under the floor there is no room, without anything having slept'

    # A READ THAT FAILS MID-RUN KEEPS THE INSTANT THE BUDGET WAS BORN WITH -- it must not fail open into
    # "no budget" (an unbounded call inside a hook) nor closed into a spent one (a run that skips every
    # remaining call over a transient read). Garbage here, because a deleted file and unreadable content
    # are the same answer to this function and the content is the half a test can pin exactly.
    [System.IO.File]::WriteAllText($deadlineFile, 'not an instant')
    Assert-True (Test-NativeCaptureBudgetHasRoom -Budget $lateBound)      'deadline file: an unreadable restatement falls back to the instant it was born with'

    # PRECEDENCE: the file wins over both knobs above it, which is the ladder park-cycle.ps1 states for
    # its four. Asserted because silently preferring either would put the budget back on the clock.
    [System.IO.File]::WriteAllText($deadlineFile, "$([System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + 3600)")
    $ladder = New-NativeCaptureBudget -TotalSeconds 10 -ExpiresUtc ((Get-Date).ToUniversalTime().AddSeconds(10)) -ExpiresFile $deadlineFile
    Assert-True ((Get-NativeCaptureBudgetSecondsLeft -Budget $ladder) -gt 60) 'deadline file: it wins over -ExpiresUtc and -TotalSeconds alike'
} finally {
    Remove-Item -LiteralPath $deadlineFile -Force -ErrorAction SilentlyContinue
}

# A PATH THAT CANNOT BE READ AT BIRTH IS THE NO-BUDGET SHAPE, not a spent one: a budget that was never
# established must cost the standing bound rather than the run, which is this lib's standing direction
# for a malformed one. And it cannot be revived by a later write -- Expires is $null, so every reader
# above stops at Test-NativeCaptureBudgetSet.
$absentFile = New-ScratchPath -Label 'budget-deadline-absent' -Extension '.txt'
$noSuchBudget = New-NativeCaptureBudget -ExpiresFile $absentFile
Assert-True (-not (Test-NativeCaptureBudgetSet -Budget $noSuchBudget))   'deadline file: a path with no file is the no-budget shape'
Assert-Equal (Get-NativeCaptureBudgetBound -Budget $noSuchBudget) $NativeCaptureNetworkTimeoutSeconds 'deadline file: so the call keeps the standing bound'

# THE READER ITSELF ANSWERS $null FOR EVERY WAY IT CAN FAIL, one value for all of them, because every
# caller does the same thing with a deadline it could not read.
Assert-True ($null -eq (Get-NativeCaptureBudgetFileDeadline -Path ''))         'deadline file: no path is $null'
Assert-True ($null -eq (Get-NativeCaptureBudgetFileDeadline -Path $absentFile)) 'deadline file: a missing file is $null'
$garbageFile = New-ScratchPath -Label 'budget-deadline-garbage' -Extension '.txt'
try {
    [System.IO.File]::WriteAllText($garbageFile, "2026-09-22T10:00:00Z`r`n")
    Assert-True ($null -eq (Get-NativeCaptureBudgetFileDeadline -Path $garbageFile)) 'deadline file: content that is not an integer is $null rather than a throw'
    [System.IO.File]::WriteAllText($garbageFile, "  1758484800`r`n")
    Assert-True ($null -ne (Get-NativeCaptureBudgetFileDeadline -Path $garbageFile)) 'deadline file: surrounding whitespace and a newline are tolerated'
} finally {
    Remove-Item -LiteralPath $garbageFile -Force -ErrorAction SilentlyContinue
}

# THE CALLERS, PINNED. park-cycle.ps1 is the reason all of this exists, and an edit that dropped the
# budget from one of its network calls would leave every assert above green.
#
# THE PIN IS SEMANTIC, NOT A TEXT SHAPE, and the first attempt at it is why that is written down. It
# asserted that one exact spelling of the old unbounded call was absent, anchored with `\s*$` -- and
# PowerShell's -match has no Multiline option by default, so that `$` anchored to the end of the whole
# FILE rather than to end-of-line. The assert therefore returned true unconditionally: run against
# `git show main:scripts/task/park-cycle.ps1`, which still CONTAINS the unbounded call, it passes.
# A regression guard that goes green on the very defect it names is worse than no guard, because its
# message asserts coverage nobody has. Caught in review, not by the suite -- which is the point.
#
# SO IT ASKS THE QUESTION INSTEAD: does EVERY call in this script that reaches the network carry a
# bound? Line continuations are joined first, because the bound sits on the second physical line of the
# call it belongs to and a per-line scan would read the call as unbounded.
$parkCycleText = Get-Content -Raw -LiteralPath (Join-Path $scriptsRoot 'task\park-cycle.ps1')
$parkCycleJoined = $parkCycleText -replace '`\r?\n\s*', ' '
$parkNetCalls = @($parkCycleJoined -split '\r?\n' | Where-Object {
    $_ -match 'Invoke-NativeCapture' -and $_ -match "'gh'|'fetch'"
})
Assert-True ($parkNetCalls.Count -ge 2) "park-cycle still makes the network calls this is about (found $($parkNetCalls.Count))"
$parkUnbounded = @($parkNetCalls | Where-Object { $_ -notmatch '-TimeoutSeconds' })
Assert-True ($parkUnbounded.Count -eq 0) `
    ('every network call in park-cycle carries a bound -- the unbounded `gh pr list` is what #1958 found' + $(if ($parkUnbounded.Count) { ' -- unbounded: ' + (($parkUnbounded | ForEach-Object { $_.Trim() }) -join ' | ') } else { '' }))
$parkBudgeted = @($parkNetCalls | Where-Object { $_ -match 'Get-NativeCaptureBudgetBound' })
Assert-Equal $parkBudgeted.Count $parkNetCalls.Count 'and every one of them takes what is LEFT of the run budget, not a fresh per-call bound'

# AND THE ROOM CHECK IS COUNTED OVER CODE ONLY. An earlier form counted matches over the raw file with
# `-ge`, which the file's own comments inflate: four mentions of a name where three are calls means the
# pin tolerates losing one call and still passes. Comments are stripped and the count is exact, so a
# dropped guard is a red rather than a silently weaker promise.
$parkCycleCode = ($parkCycleJoined -split '\r?\n' | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
# FIVE SINCE #2068, NOT FOUR. The PR check gained a conditional SECOND gh call -- it re-asks once when
# the first answer came back with an exit code that is not a measurement (ExitCodeUnknown, #1931) --
# and a retry that can reach the network is a call like any other, so it owes the same room check.
# The pin is exact on purpose (see the paragraph above), so adding the call without the guard is red
# and adding the guard without updating this number is red too. Both are the intended behaviour.
Assert-Equal (@([regex]::Matches($parkCycleCode, 'Test-NativeCaptureBudgetHasRoom')).Count) 5 `
    'park-cycle asks whether there is room before each call it might make -- the PR check, its re-ask, the open-PR look, the push, and the refused-push look'


# ---------------------------------------------------------------------------------------------
Write-Host 'Test-NativeExitMeasured / Get-NativeExitLabel -- the consumers #1931 asked for (#2081)' -ForegroundColor Cyan

# THE POINT OF THE FUNCTION IS THE DIRECTION, so both spellings of the trap are asserted here rather
# than left to the call sites: $null is not 0 AND $null is not -ne 0's false, so a caller reading the
# NUMBER lands on its failure branch whichever way round it writes the comparison.
Assert-True ($null -ne 0) 'the trap itself: an unmeasurable code satisfies -ne 0, which is why a refusing site refuses'
Assert-True (-not ($null -eq 0)) '...and fails -eq 0, which is why a site requiring success reads it as failure'
Assert-Equal '' "$($null)" '...and interpolates as the EMPTY STRING, which is what produced "(exit )" at twelve sites'

$fxMeasured   = [pscustomobject]@{ Output = @(); ExitCode = 3;     TimedOut = $false; ShortRead = $false; ExitCodeUnknown = $false }
$fxUnknown    = [pscustomobject]@{ Output = @(); ExitCode = $null; TimedOut = $false; ShortRead = $false; ExitCodeUnknown = $true }
$fxTimedOut   = [pscustomobject]@{ Output = @(); ExitCode = 124;   TimedOut = $true;  ShortRead = $false; ExitCodeUnknown = $false }
$fxNoField    = [pscustomobject]@{ Output = @(); ExitCode = 0;     TimedOut = $false }

Assert-True (Test-NativeExitMeasured -Capture $fxMeasured)        'a measured non-zero is measured -- the function is not a failure test'
Assert-True (-not (Test-NativeExitMeasured -Capture $fxUnknown))  'an ExitCodeUnknown capture is not'
Assert-True (Test-NativeExitMeasured -Capture $fxTimedOut)        'a TIMED-OUT capture IS measured: 124 is a verdict this lib chose, and TimedOut is the field that reports it'
Assert-True (Test-NativeExitMeasured -Capture $fxNoField)         'a capture from an OLDER copy of this lib answers $true -- the pre-field behaviour, not a new refusal'
Assert-True (-not (Test-NativeExitMeasured -Capture $null))       'and no capture at all is the strongest statement that nothing was measured'

Assert-Equal 'exit 3' (Get-NativeExitLabel -Capture $fxMeasured)  'the label is the plain sentence where there is a number to print'
Assert-True ((Get-NativeExitLabel -Capture $fxUnknown) -match '1931') '...and names the issue where there is not, because the reader will not find this race in their own script'
Assert-True ((Get-NativeExitLabel -Capture $fxUnknown) -notmatch 'exit\s*$') '...and never trails off after the word "exit", which is the defect it replaces'


# ---------------------------------------------------------------------------------------------
Write-Host 'Test-NativeCommandStarted / the not-started label -- the third state (#2234)' -ForegroundColor Cyan

# THE FIXTURE CARRIES ExitCodeUnknown TOO, because that is what the lib really returns and a fixture
# that quietly disagreed with it would pin the wrong contract. The whole subtlety of this state is that
# it is a SUBSET of "not measured": every existing consumer keeps working precisely because of that, and
# the only thing NotStarted adds is which of the two reasons it is.
$fxNotStarted   = [pscustomobject]@{ Output = @('[not-started] ...'); ExitCode = $null; TimedOut = $false; ShortRead = $false; ExitCodeUnknown = $true; NotStarted = $true }
$fxStarted      = [pscustomobject]@{ Output = @(); ExitCode = 0; TimedOut = $false; ShortRead = $false; ExitCodeUnknown = $false; NotStarted = $false }

Assert-True (-not (Test-NativeCommandStarted -Capture $fxNotStarted)) 'a not-started capture answers $false'
Assert-True (Test-NativeCommandStarted -Capture $fxStarted)           'an ordinary one answers $true'
Assert-True (Test-NativeCommandStarted -Capture $fxNoField)           'a capture from an OLDER copy of this lib answers $true -- and that degrade is EXACT rather than merely safe: before this field, a launch failure threw, so a capture object existing at all really does mean the child started'
Assert-True (-not (Test-NativeCommandStarted -Capture $null))         'and no capture at all is the strongest statement that nothing was started'

# THE FIELD IS A SUBSET OF "NOT MEASURED", asserted rather than left to the reader -- this is the line
# that says the 56 audited sites need no change.
Assert-True (-not (Test-NativeExitMeasured -Capture $fxNotStarted)) 'a not-started capture is also not MEASURED, which is what keeps every site audited under #2081 correct without being touched'

# THE WORDING IS THE ONE THING NotStarted BUYS THAT ExitCodeUnknown CANNOT, and both halves of the
# general sentence are wrong about it: "the child ran" is exactly what did not happen, and "this
# normally settles on a re-run" is false advice -- a command that is not installed does not settle.
$notStartedLabel = Get-NativeExitLabel -Capture $fxNotStarted
Assert-True ($notStartedLabel -match '2234')            'the not-started label names its own issue, not the race in #1931'
Assert-True ($notStartedLabel -notmatch 'the child ran') '...and does not claim the child ran'
Assert-True ($notStartedLabel -notmatch 're-run')        '...and does not advise a re-run, which would spend a retry to learn nothing'
Assert-True ($notStartedLabel -notmatch 'exit\s*$')      '...and keeps the noun-phrase contract, so it still drops into "(exit ...)" at every existing call site'

# THE ORDER INSIDE Get-NativeExitLabel IS THE WHOLE MECHANISM: reversed, the broader measured-test would
# answer first and the not-started branch would be unreachable. This assert is what makes that visible.
Assert-True ($notStartedLabel -ne (Get-NativeExitLabel -Capture $fxUnknown)) 'the two unmeasured states get DIFFERENT sentences -- if they ever match, the not-started branch has become unreachable'


# ---------------------------------------------------------------------------------------------
Write-Host 'the audited family, read through the PARSER -- every bounded site, per capture (#2081)' -ForegroundColor Cyan

# THE PIN THAT REPLACED A WEAKER ONE, AND WHY THE WEAKER ONE HAD TO GO. The first version of this
# block asked, per FILE, whether Test-NativeExitMeasured appeared anywhere in it. sync-main.ps1 passed
# it with two repaired sites and six unrepaired siblings -- including a `gh pr create` and a
# `gh pr merge`, both writes, both telling the operator to redo work that may already have landed. A
# file-level pin cannot see that, because one repair satisfies it forever.
#
# AND THE ENUMERATION ITSELF IS THE PARSER'S, not a regex's, for the reason this repo already writes
# down at check 18 of the lint gate. The regex that first measured this family counted 48 bounded sites;
# the parser counts 56. The eight it missed are the calls that open `@(` with no trailing backtick, so
# the continuation heuristic stopped at line one and never saw the -Utf8/-TimeoutSeconds that makes a
# site bounded. Two of the eight were the writes above.
$auditRoot = Split-Path -Parent $PSScriptRoot

# DECLARED EXEMPTIONS, EACH WITH ITS REASON, and a name is exempt only in the file that declares it.
# This is the half the audit was missing entirely: a site left alone on purpose and a site nobody looked
# at are indistinguishable from the outside, which is exactly how the six siblings survived a review.
$auditExempt = @{
    'task\sync-main.ps1|pull'          = 'refuses and prints no number -- "Could not fast-forward" is true of a pull this run could not judge'
    'task\sync-main.ps1|post'          = 'same, after the merge: the sentence names the state, not a cause or a code'
    'task\sync-main.ps1|prView'        = 'refuses and prints no number; the PR is open and the operator merges by hand either way'
    'task\claim-issue.ps1|contains'    = 'warn-only scan: an unjudged commit is skipped, which under-reports inside a report that states its own caps'
    'task\claim-issue.ps1|allBranchesCapture' = 'same scan, same direction -- it prints "title-overlap scan skipped" with no number'
    'release\ship-pr.ps1|diffRead'     = 'fail-closed: the commit stays COUNTED in the staleness verdict, so a third state would be a no-op'
    'task\park-cycle.ps1|prList'       = 'repaired on fix/2068-park-cycle-unknown-exit-code, which is the worked instance #2081 was split out of'
    'ci\get-merge-suite-skip.ps1|diffRead' = 'the SAME site as ship-pr.ps1''s own diffRead one row up, re-derived after the merge instead of before it (#2303): an unreadable diff leaves the commit COUNTED in the staleness verdict, the identical fail-closed direction'
}

$auditFiles = Get-ChildItem -Path $auditRoot -Recurse -Filter *.ps1 |
    Where-Object { $_.FullName.Replace([char]92, '/') -notmatch '/tests/' -and $_.Name -ne 'native-capture-lib.ps1' }

$boundedTotal = 0
$unguarded = @()
foreach ($af in $auditFiles) {
    $atok = $null; $aerr = $null
    $aast = [System.Management.Automation.Language.Parser]::ParseFile($af.FullName, [ref]$atok, [ref]$aerr)
    if ($aerr -and $aerr.Count) { continue }
    $rel = $af.FullName.Substring($auditRoot.Length + 1)

    # Which capture variables in this file come off a BOUNDED call.
    $boundedVars = @{}
    foreach ($c in $aast.FindAll({
            param($n) $n -is [System.Management.Automation.Language.CommandAst] -and
                      $n.GetCommandName() -eq 'Invoke-NativeCapture' }, $true)) {
        $pnames = @($c.CommandElements |
            Where-Object { $_ -is [System.Management.Automation.Language.CommandParameterAst] } |
            ForEach-Object { $_.ParameterName })
        if (-not (($pnames -contains 'Utf8') -or ($pnames -contains 'TimeoutSeconds'))) { continue }
        $boundedTotal++
        $assign = $c.Parent
        while ($assign -and -not ($assign -is [System.Management.Automation.Language.AssignmentStatementAst])) { $assign = $assign.Parent }
        if ($assign -and $assign.Left -is [System.Management.Automation.Language.VariableExpressionAst]) {
            $boundedVars[$assign.Left.VariablePath.UserPath] = $true
        }
    }
    if ($boundedVars.Count -eq 0) { continue }

    # Which of those the file judges with a NEGATIVE test -- the spelling $null satisfies.
    $negative = @{}
    foreach ($b in $aast.FindAll({
            param($n) $n -is [System.Management.Automation.Language.BinaryExpressionAst] -and
                      $n.Operator -eq [System.Management.Automation.Language.TokenKind]::Ine }, $true)) {
        $l = $b.Left
        if (-not ($l -is [System.Management.Automation.Language.MemberExpressionAst])) { continue }
        if ("$($l.Member)" -ne 'ExitCode') { continue }
        if (-not ($l.Expression -is [System.Management.Automation.Language.VariableExpressionAst])) { continue }
        $vn = $l.Expression.VariablePath.UserPath
        if ($boundedVars.ContainsKey($vn)) { $negative[$vn] = $true }
    }
    if ($negative.Count -eq 0) { continue }

    # Which of those the file ALSO asks the question about, by name.
    $asked = @{}
    foreach ($c in $aast.FindAll({
            param($n) $n -is [System.Management.Automation.Language.CommandAst] -and
                      @('Test-NativeExitMeasured', 'Get-NativeExitLabel') -contains $n.GetCommandName() }, $true)) {
        foreach ($e in $c.CommandElements) {
            if ($e -is [System.Management.Automation.Language.VariableExpressionAst]) { $asked[$e.VariablePath.UserPath] = $true }
        }
    }

    foreach ($vn in $negative.Keys) {
        if ($asked.ContainsKey($vn)) { continue }
        if ($auditExempt.ContainsKey("$rel|$vn")) { continue }
        $unguarded += "$rel -- `$$vn"
    }
}

# MOVED 56 -> 57 ON THIS BRANCH, DELIBERATELY, WHICH IS THE WHOLE POINT OF THIS ASSERT. The new
# bounded site is park-cycle.ps1's RE-ASK -- the repair this branch exists for: a second `gh pr list`
# taken ONLY when the first came back with an exit code .NET could not measure (#1931). It is not a
# new round trip in the general case, and it carries every guard the one it retries carries:
#   * reachable only on $prList.ExitCodeUnknown -and -not $prList.TimedOut -- never after a timeout,
#   * gated on Test-NativeCaptureBudgetHasRoom, so a Stop hook cannot spend an unbounded extra call
#     (#1958's own defect, one call over), and
#   * bounded by Get-NativeCaptureBudgetBound, the same bound as the original.
# The exempt list above ALREADY ANTICIPATED IT: 'task\park-cycle.ps1|prList' names this branch by
# name as the worked instance #2081 was split out of. The companion assert below stayed green through
# the change, which is the half that matters -- the new site is judged, not merely counted.
#
# MOVED 57 -> 58 ON THE #2120 BRANCH, DELIBERATELY AND AUDITED. The new bounded site is
# Get-IssueBodySet's `gh issue view --json body` in scripts\lib\issue-state-lib.ps1 -- the impure half of
# the resolves-exempt gate, sitting beside Get-ClosedIssueSet and built to its shape:
#   * bounded by the same -TimeoutSeconds the caller passes, the workflow's standard network bound,
#   * capped by the same $script:IssueStateResolveLimit, so a branch citing many numbers cannot turn one
#     gate into an unbounded fan of round trips, and
#   * reached only when the repo ANSWERS Get-ResolvesExemptMatchers -- the seam is read before any fetch,
#     so a repo with no second tracker pays nothing for a rule that is not theirs.
# It asks Test-NativeExitMeasured about that capture BEFORE testing the code against 0 (#1931), which is
# why the companion assert below stayed green through the change -- the new site is judged, not merely
# counted, and that remains the half that matters.
#
# MOVED 58 -> 63 ON THE #2228 BRANCH, DELIBERATELY AND AUDITED. All five new sites are
# scripts\task\live-preflight.ps1's, the live-push preflight, and they are five rather than one because
# that script drives four different children plus a git wrapper:
#   * Invoke-Git, the wrapper every git read in the script goes through -- bounded at 120s by default,
#     which is the one call in it that can reach a network (the `fetch` in step 1),
#   * the repo's own lint gate ($lint, 1,800s) and each of its Get-TestCommands lines ($run, 3,600s),
#     both spawned as `powershell -File`/`-Command` and both somebody else's process by definition,
#   * backup-live-theme.ps1 ($backup, 2,700s) -- the step that polls until a theme duplicate is provably
#     complete, measured at roughly eight minutes in the consumer that specified it, and
#   * sweep-preview-themes.ps1 ($sweep, 600s), the aftercare preview.
# EVERY ONE OF THE FIVE ASKS Test-NativeExitMeasured ABOUT ITS OWN CAPTURE BEFORE TESTING THE CODE
# against 0, and the four that compose a sentence around the number use Get-NativeExitLabel (#1931,
# #2081) -- which is why the companion assert below stayed green through the change. That remains the
# half that matters: the new sites are judged, not merely counted. The direction each one fails in is
# deliberate too -- an unmeasurable gate, diff or backup is treated as a refusal, because the thing this
# script stands in front of is a push to a live storefront.
#
# MOVED 63 -> 69 ON THE #2243 BRANCH, DELIBERATELY AND AUDITED. All six new sites are
# scripts\task\claim-issue.ps1's, the claim-by-TAG mode, and they are six because that mode drives one
# more read and three more writes than the assignee claim does:
#   * $hostCapture, `hostname` -- the machine half of the tag where $env:COMPUTERNAME is empty. Bounded
#     at 10s rather than at the network bound: it reaches no network, and a machine that cannot name
#     itself must refuse quickly rather than hold the claim step open,
#   * $list, `gh issue list` for -Candidates -- one read for the whole board rather than one per issue,
#   * $comment, `gh issue comment` -- THE CLAIM ITSELF, and the one write whose failure means the issue
#     is not claimed at all,
#   * $del, the GraphQL deleteIssueComment behind -Release, and $unassign beside it, and
#   * $raceRead, the read-back that settles a two-machine race on the tracker's timestamps.
# EVERY ONE OF THE SIX ASKS Test-NativeExitMeasured ABOUT ITS OWN CAPTURE before it tests the code
# against 0, which is why the companion assert below stayed green through the change -- the new sites
# are judged, not merely counted. The direction each fails in is the claim's own: an unmeasurable READ
# refuses ($list, because an unread backlog reading as empty would hand out claims on work six machines
# already hold; $raceRead, because a race nobody could settle is not a race won), and an unmeasurable
# WRITE stops without asserting what it could not measure -- re-running is safe, since a marker that did
# land comes back as 'already-yours'.
Assert-Equal 70 $boundedTotal 'the parser still counts 70 bounded Invoke-NativeCapture sites outside scripts/tests/ -- a new one is not a failure, but it has to be audited and this number moved deliberately'
Assert-Equal 0 $unguarded.Count `
    ('every bounded capture judged with a NEGATIVE exit-code test either asks Test-NativeExitMeasured/Get-NativeExitLabel about THAT capture or is exempt with a reason (#2081)' +
     $(if ($unguarded.Count) { ' -- unguarded: ' + ($unguarded -join ' | ') } else { '' }))

# AND THE EXEMPTION LIST CANNOT GO STALE QUIETLY: a name that no longer needs exempting is a line
# claiming a decision nobody is making any more, which is the accumulation shape this repo keeps
# removing. Each entry has to still name a bounded capture in the file it names.
foreach ($k in $auditExempt.Keys) {
    $parts = $k -split '\|'
    Assert-True (Test-Path -LiteralPath (Join-Path $auditRoot $parts[0])) "the exemption for `$$($parts[1]) still names a file that exists: $($parts[0])"
}
if ($script:fail -eq 0) {
    Write-Host "Result: $($script:pass) pass, 0 fail." -ForegroundColor Green
    exit 0
}
Write-Host "Result: $($script:pass) pass, $($script:fail) fail." -ForegroundColor Red
exit 1
