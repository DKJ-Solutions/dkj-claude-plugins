<#
.SYNOPSIS
    Tests for scripts/lib/session-cache-lib.ps1 (issue #1605): the session id a SessionStart hook
    reads off its own stdin payload, and the per-session cache keyed on it.

.DESCRIPTION
    WHY A LIB SUITE BESIDE connector-sessioncheck.tests.ps1 RATHER THAN ONLY SCENARIOS THERE. That
    file answers "what does a session SEE", by driving the real hook against a real engine, and the
    two new scenarios it gained for this change answer the only question that needs a hook: does a
    second firing spawn the engine again. Everything else about this cache is a set of decisions with
    no hook in them -- which strings may be a key, when a replay is too old to be trusted, what a
    corrupt entry does, what the reap removes -- and each of them fails SILENTLY towards the same
    place: a cache that never hits looks exactly like no cache at all, which is the pre-#1605
    behaviour. So they are pinned here, where a scenario is three lines instead of a fixture tree.

    THE SHAPE CHECK IS THE ONE WITH A SECOND SUBJECT, and it gets the most cases: the session id
    arrives from outside this process and is composed into a file name, so a string that passes it
    also decides where a file is written. Traversal segments, separators and control characters are
    asserted refused individually rather than as a group, because a whitelist that is quietly widened
    by one character is the failure mode here and a group assertion would still pass.

    Dependency-free (no Pester), same style as connector-sessioncheck.tests.ps1 /
    plugin-versions.tests.ps1. Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Lib      = Join-Path $RepoRoot 'scripts\lib\session-cache-lib.ps1'
$Fixture  = Join-Path ([System.IO.Path]::GetTempPath()) "session-cache-lib-test-$PID-$([guid]::NewGuid().ToString('n'))"
$Utf8     = New-Object System.Text.UTF8Encoding $false

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

$VALID = 'a1b2c3d4-e5f6-4789-abcd-0123456789ab'   # the shape a harness session id actually has

try {
    Write-Host '== session-cache-lib.tests: the per-session verdict cache (#1605) ==' -ForegroundColor Cyan
    Assert-True (Test-Path -LiteralPath $Lib -PathType Leaf) 'session-cache-lib.ps1 exists at its canonical path'
    . $Lib

    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture }
    New-Item -ItemType Directory -Path $Fixture -Force | Out-Null

    # --- 1. the shape check -------------------------------------------------------------------------
    Write-Host '1. Test-SessionIdShape -- a whitelist, asserted one refusal at a time' -ForegroundColor Cyan
    Assert-True (Test-SessionIdShape -SessionId $VALID) '1: a real harness session id (uuid) passes'
    Assert-True (Test-SessionIdShape -SessionId 'abc_def.12-34') '1: dot, dash and underscore are all admitted'
    Assert-True (-not (Test-SessionIdShape -SessionId '')) '1: empty is refused'
    Assert-True (-not (Test-SessionIdShape -SessionId '   ')) '1: whitespace only is refused'
    Assert-True (-not (Test-SessionIdShape -SessionId 'abc1234')) '1: seven characters is refused -- eight is the floor'
    Assert-True (-not (Test-SessionIdShape -SessionId ('a' * 129))) '1: 129 characters is refused'
    Assert-True (Test-SessionIdShape -SessionId ('a' * 128)) '1: 128 characters is the ceiling and passes'
    Assert-True (-not (Test-SessionIdShape -SessionId '../../etc/passwd')) '1: a traversal is refused'
    Assert-True (-not (Test-SessionIdShape -SessionId '..\..\windows')) '1: a backslash traversal is refused'
    Assert-True (-not (Test-SessionIdShape -SessionId 'abcdefgh/ijkl')) '1: a forward separator is refused'
    Assert-True (-not (Test-SessionIdShape -SessionId 'C:abcdefgh')) '1: a colon is refused -- it is a drive or a stream'
    Assert-True (-not (Test-SessionIdShape -SessionId "abcdefgh`n1234")) '1: a newline is refused'
    Assert-True (-not (Test-SessionIdShape -SessionId 'abcdefgh 1234')) '1: an embedded space is refused'
    Assert-True (-not (Test-SessionIdShape -SessionId 'abcdefgh*1234')) '1: a wildcard is refused'

    # --- 2. the payload reader (pure half) ----------------------------------------------------------
    Write-Host '2. Get-SessionIdFromPayload -- every shape a payload arrives in' -ForegroundColor Cyan
    Assert-Equal $VALID (Get-SessionIdFromPayload -Payload (@{ session_id = $VALID; source = 'compact' } | ConvertTo-Json)) '2: the id is read out of a real payload'
    Assert-Equal '' (Get-SessionIdFromPayload -Payload '') '2: an empty payload yields no id'
    Assert-Equal '' (Get-SessionIdFromPayload -Payload 'not json at all') '2: an unparseable payload yields no id -- it fails towards MEASURING, unlike guard-live-theme'
    Assert-Equal '' (Get-SessionIdFromPayload -Payload '{ "source": "startup" }') '2: a payload without the field yields no id'
    Assert-Equal '' (Get-SessionIdFromPayload -Payload '{ "session_id": ["a","b"] }') '2: an array field yields no id rather than stringifying into one'
    Assert-Equal '' (Get-SessionIdFromPayload -Payload '{ "session_id": { "x": 1 } }') '2: an object field yields no id'
    Assert-Equal '' (Get-SessionIdFromPayload -Payload '{ "session_id": "../../x" }') '2: a field failing the shape check yields no id'
    Assert-Equal $VALID (Get-SessionIdFromPayload -Payload "{ `"session_id`": `"  $VALID  `" }") '2: surrounding whitespace is trimmed rather than refused'

    # --- 3. the payload reader over REAL stdin ------------------------------------------------------
    # The only part of this lib that cannot be exercised in-process: [Console]::IsInputRedirected and
    # the standard input handle itself are properties of the PROCESS, so this runs a child with the
    # payload piped into it exactly as the harness pipes one into a hook. Worth one spawn -- the guard
    # it proves is what keeps a hand-run hook from blocking on a console that will never send EOF.
    Write-Host '3. Get-HookSessionId -- over a real redirected stdin, and over one with nothing on it' -ForegroundColor Cyan
    $probe = Join-Path $Fixture 'probe.ps1'
    [System.IO.File]::WriteAllText($probe, ". `"$Lib`"`r`nWrite-Host ('[' + (Get-HookSessionId) + ']')`r`n", $Utf8)
    $piped = (@{ session_id = $VALID; source = 'compact' } | ConvertTo-Json -Compress) | & powershell -NoProfile -ExecutionPolicy Bypass -File $probe
    Assert-Equal "[$VALID]" ($piped -join '') '3: a piped payload is read off stdin and its id returned'
    $empty = '' | & powershell -NoProfile -ExecutionPolicy Bypass -File $probe
    Assert-Equal '[]' ($empty -join '') '3: a redirected stdin carrying nothing usable returns no id instead of blocking'

    # --- 3b. the bound actually binds (issue #2249) -------------------------------------------------
    # THE ONE CASE NOTHING ELSE IN THIS SUITE CAN REACH, and the one the guard exists for. Section 3
    # pipes a payload and closes the handle, so the text is already buffered and the read returns at
    # once -- which is why the bound stood for two weeks without binding. This spawns a child with
    # stdin REDIRECTED and then never writes to it and never closes it: the shape a harness leaves
    # behind when it hands a hook a handle it forgets about, and the shape #2233 reported from the
    # other end.
    #
    # IT ASSERTS TERMINATION, NOT A DURATION, and deliberately so. The failure this pins is infinite
    # -- before the repair the child was still alive after 15 s at 0.14 s of CPU -- so any finite wall
    # is evidence and a tight one would only make the suite flaky on a loaded runner. The elapsed time
    # is PRINTED for whoever is reading the log, and not asserted on.
    Write-Host '3b. a redirected stdin nobody writes to or closes -- the read is bounded, not forever' -ForegroundColor Cyan
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName               = 'powershell.exe'
    $psi.Arguments              = "-NoProfile -ExecutionPolicy Bypass -File `"$probe`""
    $psi.RedirectStandardInput  = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute        = $false
    $child = [System.Diagnostics.Process]::Start($psi)
    # Drained asynchronously so a child that DOES print cannot fill its pipe and block against the
    # very wait this is timing.
    $childOut = $child.StandardOutput.ReadToEndAsync()
    $wall = [System.Diagnostics.Stopwatch]::StartNew()
    $exited = $child.WaitForExit(30000)
    $wall.Stop()
    if (-not $exited) { try { $child.Kill() } catch { } }
    Write-Host ("     (child " + $(if ($exited) { "exited after $($wall.ElapsedMilliseconds) ms" } else { 'WEDGED -- killed' }) + ')') -ForegroundColor DarkGray
    Assert-True $exited '3b: the child returns instead of blocking forever on a handle nobody closes'
    if ($exited) { Assert-Equal '[]' ($childOut.Result.Trim()) '3b: and it reports no id rather than a partial read' }

    # --- 3c. the payload is decoded as UTF-8, not as the console codepage (issue #2249) --------------
    # A SECOND REPAIR IN THE SAME CHANGE, pinned because it is invisible in the field. [Console]::In
    # decodes with Console.InputEncoding -- the OEM console codepage on Windows, cp850 where this was
    # measured -- so every non-ASCII byte in a payload was mangled before it reached ConvertFrom-Json.
    # A session_id is a UUID and never noticed; the cwd field the sibling readers in this family take a
    # repo root from is not.
    #
    # THE BYTES ARE COMPOSED AND WRITTEN TO THE CHILD'S RAW STDIN, for two reasons. This file is pure
    # ASCII by repo convention, so the character cannot be typed; and piping through PowerShell would
    # re-encode it with the parent's own output encoding, which is the very thing under test.
    Write-Host '3c. a non-ASCII payload is decoded as UTF-8, not as the console codepage' -ForegroundColor Cyan
    $accentProbe = Join-Path $Fixture 'accent-probe.ps1'
    [System.IO.File]::WriteAllText($accentProbe, ". `"$Lib`"`r`n`$raw = Get-HookPayloadRaw`r`nWrite-Host ((`$raw.ToCharArray() | ForEach-Object { [int]`$_ }) -join ',')`r`n", $Utf8)
    $api = New-Object System.Diagnostics.ProcessStartInfo
    $api.FileName               = 'powershell.exe'
    $api.Arguments              = "-NoProfile -ExecutionPolicy Bypass -File `"$accentProbe`""
    $api.RedirectStandardInput  = $true
    $api.RedirectStandardOutput = $true
    $api.RedirectStandardError  = $true
    $api.UseShellExecute        = $false
    $ac = [System.Diagnostics.Process]::Start($api)
    $acOut = $ac.StandardOutput.ReadToEndAsync()
    # {"cwd":"Ren<U+00E9>"} as UTF-8 bytes, no BOM.
    $acBytes = $Utf8.GetBytes('{"cwd":"Ren' + [char]0x00E9 + '"}')
    $ac.StandardInput.BaseStream.Write($acBytes, 0, $acBytes.Length)
    $ac.StandardInput.BaseStream.Flush()
    $ac.StandardInput.Close()
    if (-not $ac.WaitForExit(30000)) { try { $ac.Kill() } catch { } }
    $acText = $acOut.Result.Trim()
    Assert-True ($acText -match '(^|,)233(,|$)') '3c: a UTF-8 e-acute arrives as U+00E9 (233), not as two console-codepage characters'
    Assert-True ($acText -notmatch '(^|,)9500(,|$)') '3c: and the cp850 mojibake the old read produced (U+251C) is gone'

    # --- 4. the round trip --------------------------------------------------------------------------
    Write-Host '4. Set/Get -- the round trip, and every reason a read is a MISS' -ForegroundColor Cyan
    $root = Join-Path $Fixture 'cache'
    Assert-True (Set-SessionCacheEntry -SessionId $VALID -Key 'subject|one' -Output @('[SUMMARY] a', '[ERROR] b') -ExitCode 3 -Root $root) '4: a write into a directory that does not exist yet creates it and reports true'
    $hit = Get-SessionCacheEntry -SessionId $VALID -Key 'subject|one' -Root $root
    Assert-True ($null -ne $hit) '4: the entry reads back'
    Assert-Equal 2 $hit.Output.Count '4: both output lines survive'
    Assert-Equal '[SUMMARY] a' $hit.Output[0] '4: line order is preserved'
    Assert-Equal '[ERROR] b' $hit.Output[1] '4: and so is the second line'
    Assert-Equal 3 $hit.ExitCode '4: the engine exit code is carried, not normalised to 0'

    Assert-True ($null -eq (Get-SessionCacheEntry -SessionId $VALID -Key 'subject|two' -Root $root)) '4: another subject is a miss'
    Assert-True ($null -eq (Get-SessionCacheEntry -SessionId 'zzzzzzzz-9999' -Key 'subject|one' -Root $root)) '4: another session is a miss'
    Assert-True ($null -eq (Get-SessionCacheEntry -SessionId '../../etc/passwd' -Key 'subject|one' -Root $root)) '4: an id failing the shape check is a miss before any path is composed'
    Assert-True ($null -eq (Get-SessionCacheEntry -SessionId $VALID -Key 'subject|one' -Root $root -MaxAgeHours 0)) '4: an age bound of zero refuses even an entry written a moment ago'
    Assert-True (-not (Set-SessionCacheEntry -SessionId 'sh' -Key 'k' -Root $root)) '4: a write under an id failing the shape check reports false and writes nothing'

    # A SINGLE OUTPUT LINE, because ConvertTo-Json unrolls a one-element array and ConvertFrom-Json
    # then hands back a bare string -- the shape that would make .Count read 1 on a 12-character line
    # and forward one character per "line". The writer's @() and the reader's @() are what stop it.
    Assert-True (Set-SessionCacheEntry -SessionId $VALID -Key 'one-liner' -Output @('[SUMMARY] alone') -Root $root) '4: a one-line verdict is stored'
    $solo = Get-SessionCacheEntry -SessionId $VALID -Key 'one-liner' -Root $root
    Assert-Equal 1 $solo.Output.Count '4: and reads back as ONE line, not as fifteen characters'
    Assert-Equal '[SUMMARY] alone' $solo.Output[0] '4: with its text intact'

    # An empty verdict is a real state (an engine that printed nothing at all) and must not throw.
    Assert-True (Set-SessionCacheEntry -SessionId $VALID -Key 'silent' -Output @() -Root $root) '4: an empty output set is storable'
    $none = Get-SessionCacheEntry -SessionId $VALID -Key 'silent' -Root $root
    Assert-True ($null -ne $none) '4: and reads back'
    Assert-Equal 0 $none.Output.Count '4: as zero lines'

    # --- 5. entries this lib must not trust ---------------------------------------------------------
    Write-Host '5. a corrupt, incomplete or future-dated entry is a MISS, never an error' -ForegroundColor Cyan
    $corruptRoot = Join-Path $Fixture 'corrupt'
    New-Item -ItemType Directory -Path $corruptRoot -Force | Out-Null
    $name = Get-SessionCacheFileName -SessionId $VALID -Key 'subject|one'
    [System.IO.File]::WriteAllText((Join-Path $corruptRoot $name), '{ this is not json', $Utf8)
    Assert-True ($null -eq (Get-SessionCacheEntry -SessionId $VALID -Key 'subject|one' -Root $corruptRoot)) '5: an unparseable entry is a miss'
    [System.IO.File]::WriteAllText((Join-Path $corruptRoot $name), (@{ sessionId = $VALID; key = 'subject|one' } | ConvertTo-Json), $Utf8)
    Assert-True ($null -eq (Get-SessionCacheEntry -SessionId $VALID -Key 'subject|one' -Root $corruptRoot)) '5: an entry missing writtenAt/exitCode/output is a miss'
    [System.IO.File]::WriteAllText((Join-Path $corruptRoot $name),
        (@{ sessionId = $VALID; key = 'a different subject'; writtenAt = ([datetime]::UtcNow.ToString('o')); exitCode = 0; output = @('x') } | ConvertTo-Json), $Utf8)
    Assert-True ($null -eq (Get-SessionCacheEntry -SessionId $VALID -Key 'subject|one' -Root $corruptRoot)) '5: an entry whose stored key disagrees with the one asked for is a miss -- a digest collision cannot answer'
    [System.IO.File]::WriteAllText((Join-Path $corruptRoot $name),
        (@{ sessionId = $VALID; key = 'subject|one'; writtenAt = ([datetime]::UtcNow.AddHours(2).ToString('o')); exitCode = 0; output = @('x') } | ConvertTo-Json), $Utf8)
    Assert-True ($null -eq (Get-SessionCacheEntry -SessionId $VALID -Key 'subject|one' -Root $corruptRoot)) '5: a future-dated entry is a miss -- a clock that moved would otherwise stay valid for the skew'
    # AN EXPLICIT JSON null IS THE ONE SHAPE THAT DOES NOT ANNOUNCE ITSELF (Victor, on the branch that
    # built this). Every case above fails a check and returns a miss; this one used to PASS every
    # check and then read back as one empty line, because piping $null through ForEach-Object
    # iterates once with $_ = $null. A blank verdict printed into a session start is the wrong kind of
    # wrong: it looks like something the engine said. Written as raw JSON on purpose -- ConvertTo-Json
    # over @{ output = $null } is not guaranteed to produce the literal this needs.
    [System.IO.File]::WriteAllText((Join-Path $corruptRoot $name),
        ('{ "sessionId": "' + $VALID + '", "key": "subject|one", "writtenAt": "' + ([datetime]::UtcNow.ToString('o')) + '", "exitCode": 0, "output": null }'), $Utf8)
    Assert-True ($null -eq (Get-SessionCacheEntry -SessionId $VALID -Key 'subject|one' -Root $corruptRoot)) '5: an entry whose output is JSON null is a miss, NOT one blank line'
    Assert-True ($null -eq (Get-SessionCacheEntry -SessionId $VALID -Key 'nothing here' -Root (Join-Path $Fixture 'no-such-dir'))) '5: a cache root that does not exist is a miss, not an error'

    # --- 6. the reap --------------------------------------------------------------------------------
    Write-Host '6. Remove-StaleSessionCacheEntry -- what the sweep takes, and what it leaves' -ForegroundColor Cyan
    $reapRoot = Join-Path $Fixture 'reap'
    New-Item -ItemType Directory -Path $reapRoot -Force | Out-Null
    $oldA   = "$VALID-0123456789abcdef.json"
    $oldB   = "$VALID-fedcba9876543210.json"
    $fresh  = "$VALID-1111111111111111.json"
    # NOT this lib's name shape, and old enough to be swept if the filter were extension-only. Both
    # were named 'old-1.json'/'fresh.json' until the filter went in, which is precisely why the
    # docstring could promise a shape check that did not exist (Victor and Sebastian).
    $alien  = 'someone-elses-cache.json'
    foreach ($n in @($oldA, $oldB, $alien)) {
        [System.IO.File]::WriteAllText((Join-Path $reapRoot $n), '{}', $Utf8)
        (Get-Item -LiteralPath (Join-Path $reapRoot $n)).LastWriteTimeUtc = [datetime]::UtcNow.AddHours(-48)
    }
    [System.IO.File]::WriteAllText((Join-Path $reapRoot $fresh), '{}', $Utf8)
    [System.IO.File]::WriteAllText((Join-Path $reapRoot 'keep.txt'), 'not mine', $Utf8)
    (Get-Item -LiteralPath (Join-Path $reapRoot 'keep.txt')).LastWriteTimeUtc = [datetime]::UtcNow.AddHours(-48)
    Assert-Equal 2 (Remove-StaleSessionCacheEntry -Root $reapRoot -OlderThanHours 24) '6: both stale entries go, and the count says so'
    Assert-True (Test-Path -LiteralPath (Join-Path $reapRoot $fresh)) '6: a fresh entry stays'
    Assert-True (Test-Path -LiteralPath (Join-Path $reapRoot $alien)) '6: a stale .json that is NOT this libs name shape is left alone -- the docstring promised this before the code did it'
    Assert-True (Test-Path -LiteralPath (Join-Path $reapRoot 'keep.txt')) '6: a file this lib did not write is never touched, however old'
    Assert-Equal 0 (Remove-StaleSessionCacheEntry -Root (Join-Path $Fixture 'no-such-dir') -OlderThanHours 24) '6: a root that does not exist reaps nothing and does not throw'

    # A write reaps before it stores -- which is what keeps the directory from growing one file per
    # session forever, and the only thing that ever calls the sweep on a real machine.
    $sweepRoot = Join-Path $Fixture 'sweep'
    New-Item -ItemType Directory -Path $sweepRoot -Force | Out-Null
    $ancient  = "$VALID-2222222222222222.json"
    $ancient2 = "$VALID-3333333333333333.json"
    [System.IO.File]::WriteAllText((Join-Path $sweepRoot $ancient), '{}', $Utf8)
    (Get-Item -LiteralPath (Join-Path $sweepRoot $ancient)).LastWriteTimeUtc = [datetime]::UtcNow.AddHours(-48)
    Set-SessionCacheEntry -SessionId $VALID -Key 'k' -Output @('x') -Root $sweepRoot | Out-Null
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $sweepRoot $ancient))) '6: a write sweeps the stale entries it finds beside it'
    Assert-True ($null -ne (Get-SessionCacheEntry -SessionId $VALID -Key 'k' -Root $sweepRoot)) '6: and the entry it came to write is there'
    [System.IO.File]::WriteAllText((Join-Path $sweepRoot $ancient2), '{}', $Utf8)
    (Get-Item -LiteralPath (Join-Path $sweepRoot $ancient2)).LastWriteTimeUtc = [datetime]::UtcNow.AddHours(-48)
    Set-SessionCacheEntry -SessionId $VALID -Key 'k' -Output @('x') -Root $sweepRoot -ReapOlderThanHours 0 | Out-Null
    Assert-True (Test-Path -LiteralPath (Join-Path $sweepRoot $ancient2)) '6: -ReapOlderThanHours 0 turns the sweep off'

    # --- 7. the file name ---------------------------------------------------------------------------
    Write-Host '7. Get-SessionCacheFileName -- deterministic, per subject, and readable' -ForegroundColor Cyan
    $n1 = Get-SessionCacheFileName -SessionId $VALID -Key 'subject|one'
    $n2 = Get-SessionCacheFileName -SessionId $VALID -Key 'subject|one'
    $n3 = Get-SessionCacheFileName -SessionId $VALID -Key 'subject|two'
    $n4 = Get-SessionCacheFileName -SessionId 'zzzzzzzz-9999' -Key 'subject|one'
    Assert-Equal $n1 $n2 '7: the same session and subject always name the same file'
    Assert-True ($n1 -cne $n3) '7: a different subject names a different file'
    Assert-True ($n1 -cne $n4) '7: a different session names a different file'
    Assert-True ($n1.StartsWith($VALID)) '7: the session id is in the name in the clear -- that is what the reap and a reader can see'
    Assert-True ($n1 -cmatch '^[A-Za-z0-9._-]+\.json$') '7: and the whole name is file-name-safe, since the subject is hashed rather than spelled out'
    Assert-True (-not $n1.Contains('subject')) '7: the subject itself never reaches the name -- it carries machine paths'

    # --- 8. the default root ------------------------------------------------------------------------
    # THE ADDRESS IS PART OF THE CONTRACT, not an implementation detail (#1659). A cache read by a
    # LATER process cannot use New-ScratchPath's guid, so the exposure a predictable leaf in a SHARED
    # temp root carries is removed by leaving that root rather than by hardening a name inside it --
    # which is also what keeps this file out of the temp-path scan's exemption count.
    Write-Host '8. Get-SessionCacheRoot -- the per-user cache directory, not the shared temp root' -ForegroundColor Cyan
    $default = Get-SessionCacheRoot
    Assert-True (-not ($default.StartsWith([System.IO.Path]::GetTempPath()))) '8: the default root is NOT under the shared temp root'
    Assert-True (-not ($default -match '\.claude')) '8: and never under ~/.claude, which is the tree these checks READ'
    Assert-True ($default.EndsWith('dkj-session-cache')) '8: it is one named directory rather than a path composed per call'
    $prevL = $env:LOCALAPPDATA
    try {
        $env:LOCALAPPDATA = Join-Path $Fixture 'localappdata'
        Assert-Equal (Join-Path $env:LOCALAPPDATA 'dkj-session-cache') (Get-SessionCacheRoot) '8: LOCALAPPDATA is the first candidate, which is what these hooks run under today'
    } finally {
        $env:LOCALAPPDATA = $prevL
    }
    Assert-Equal 'C:\somewhere\else' (Get-SessionCacheRoot -Override 'C:\somewhere\else') '8: -Override wins, which is the seam the suite uses'
}
finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
