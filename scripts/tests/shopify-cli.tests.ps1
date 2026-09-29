<#
.SYNOPSIS
    Contract tests for scripts/lib/shopify-cli-lib.ps1 -- Invoke-ShopifyCli, the one place dkj-subagents-shopify's
    scripts invoke the Shopify CLI (inbound #1183).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Exit code 0 if everything passes, 1 on a failure.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/shopify-cli.tests.ps1

    WHAT THIS GUARDS. Under $ErrorActionPreference = 'Stop' a stderr line from a native command is a
    TERMINATING ErrorRecord in Windows PowerShell 5.1, so a bare CLI call dies on the line AFTER it and
    the caller's $LASTEXITCODE check -- the block that cleans up and reports -- never runs. The wrapper
    lowers the preference for the duration of the call; these cases pin that it does, that the caller
    gets its own preference back, and that the exit code survives.

    THE STUB IS A .ps1, AND THAT IS THE WHOLE POINT OF THE FIXTURE. On Windows 'shopify' is not an .exe:
    it is npm's generated PowerShell shim, %APPDATA%\npm\shopify.ps1, whose line 24 is the bare
    '& "node$exe" ... $args' that the consumer's stack trace names. '& shopify' runs that script
    IN-PROCESS, so it inherits the caller's preference variables -- which is why lowering the preference
    around the call reaches the frame that raises the ErrorRecord, and why a try/catch at the call site
    would not. The stub reproduces that shape (a .ps1 on PATH that starts a real child and exits with a
    code), and the headline case reads the preference back out of it.

    WHAT IS DELIBERATELY NOT ASSERTED: that a bare call DIES. Whether the ErrorRecord is raised at all
    depends on how the host's own stderr handle is set up, and it did not reproduce synthetically on the
    machine this was written on. The evidence for the death is the consumer's stack trace
    (BWJ-ecommerce/smartwatchbanden#433); the evidence for the CAUSE is the inherited preference, which
    is what these cases measure. Asserting a death that only reproduces in some hosts would be a suite
    that goes red for the wrong reason.

    Fixture paths carry $PID (repo convention): the test gate is a throttled parallel scheduler, so two
    runs overlapping is ordinary, and two runs sharing one fixed temp path tear down each other's stub.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $RepoRoot 'scripts\lib\shopify-cli-lib.ps1')

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}
function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    if ($Expected -eq $Actual) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}

# --- the fixture: a 'shopify' on PATH shaped like npm's shim ----------------------------------------
# Three modes, so each case asks for exactly the output it is about:
#   eap    -- print the preference the shim INHERITED, and nothing else
#   plain  -- print parseable JSON on stdout, and nothing on stderr
#   stderr -- print that same JSON, then have a real child write to stderr while succeeding, which is
#             what the CLI does under Claude Code. TWO LINES, one with text and one EMPTY, because the
#             empty one is where an ErrorRecord's ToString() stops agreeing with the line it carries --
#             see Get-ShopifyLineText, and the case below that pins it
$stubDir = Join-Path ([System.IO.Path]::GetTempPath()) "shopify-cli-tests-$PID-$([guid]::NewGuid().ToString('n'))"
New-Item -ItemType Directory -Path $stubDir -Force | Out-Null
$stub = @'
$mode = if ($args.Count -gt 1) { [string]$args[1] } else { 'plain' }
if ($mode -eq 'eap') {
    Write-Output ('EAP=' + $ErrorActionPreference)
} else {
    Write-Output '{"themes":[{"id":123}]}'
    if ($mode -eq 'stderr') { & cmd.exe /c "echo hint-line-on-stderr 1>&2& echo. 1>&2" }
}
exit ([int]$args[0])
'@
Set-Content -LiteralPath (Join-Path $stubDir 'shopify.ps1') -Encoding Ascii -Value $stub

$prevPath = $env:PATH
$env:PATH = "$stubDir;$prevPath"
try {
    Write-Host ''
    Write-Host 'the preference the CLI actually runs under'

    # THE HEADLINE CASE. The shim reports the preference it inherited, so this reads the repair from the
    # only place that matters: the frame where the ErrorRecord would be raised.
    $eap = Invoke-ShopifyCli -Arguments @('0', 'eap') -Quiet
    Assert-Equal 'EAP=Continue' (($eap.Output | Out-String).Trim()) 'the CLI runs at Continue when it goes through the wrapper'

    # AND THE OTHER HALF, which is what makes the first one mean anything: bare, the same shim runs at
    # this script's own 'Stop'. Safe to run here because mode 'eap' writes nothing to stderr.
    $bare = & shopify 0 eap
    Assert-Equal 'EAP=Stop' (($bare | Out-String).Trim()) 'and at the caller Stop when it is invoked bare -- the shim inherits, so the wrapper is the fix'

    Assert-Equal 'Stop' $ErrorActionPreference 'the caller gets its own preference back afterwards'

    Write-Host ''
    Write-Host 'the exit code, which a caller judges first'

    # THE DEFECT, STATED AS A TEST: the line after the call has to be REACHED, with the code in hand.
    $bad = Invoke-ShopifyCli -Arguments @('3', 'stderr') -Quiet
    Assert-Equal 3 $bad.ExitCode 'a non-zero exit comes back as ExitCode, from a call that also wrote to stderr'
    Assert-Equal 'Stop' $ErrorActionPreference 'and the preference is restored on the failing path too'

    $ok = Invoke-ShopifyCli -Arguments @('0', 'plain') -Quiet
    Assert-Equal 0 $ok.ExitCode 'a clean run reports 0'

    Write-Host ''
    Write-Host 'what lands in Output'

    # -DiscardStderr IS REQUIRED WHEREVER Output IS PARSED, and this is the case that says why: the hint
    # line the CLI writes while succeeding is not JSON, and ConvertFrom-Json refuses the whole document.
    $json = Invoke-ShopifyCli -Arguments @('0', 'stderr') -Quiet -DiscardStderr
    $parsed = $null
    try { $parsed = ($json.Output | Out-String) | ConvertFrom-Json } catch { $parsed = $null }
    Assert-Equal 123 $(if ($parsed) { $parsed.themes[0].id } else { 'did not parse' }) '-DiscardStderr keeps the stderr hint line out of a --json capture'

    $merged = Invoke-ShopifyCli -Arguments @('0', 'stderr') -Quiet
    Assert-True (($merged.Output | Out-String) -match 'hint-line-on-stderr') 'without it that same line IS in Output, so the switch is doing the work'

    # OUTPUT IS STRINGS, NEVER ErrorRecords -- found in review, against the real CLI. A merged stderr
    # line arrives as an ErrorRecord, and for an EMPTY one its ToString() has no message to defer to and
    # returns the TYPE NAME instead: 'System.Management.Automation.RemoteException', printed to the
    # console in the middle of the CLI's error box and captured by anything that parses Output. The CLI
    # draws blank lines inside that box, so this is the common case rather than the exotic one.
    Assert-True (-not (($merged.Output | Out-String) -match 'RemoteException')) 'an empty stderr line comes back as an empty string, not as a type name'
    Assert-True (@($merged.Output | Where-Object { $_ -isnot [string] }).Count -eq 0) 'and every element of Output is a string, so a caller can parse it without unwrapping'

    # THE STREAM IS A TEE, not an either/or: a caller that shows progress can still read the output back.
    $teed = Invoke-ShopifyCli -Arguments @('0', 'plain')
    Assert-True (($teed.Output | Out-String) -match '"id"\s*:\s*123') 'the streaming default still fills Output'
}
finally {
    $env:PATH = $prevPath
    Remove-Item -LiteralPath $stubDir -Recurse -Force -ErrorAction SilentlyContinue
}

# --- the wiring, which no stub can reach ------------------------------------------------------------
Write-Host ''
Write-Host 'the wiring'

# NO BARE CALL LEFT IN EITHER SCRIPT. The lint gate owns the tree-wide version of this (check 31, read
# through the PowerShell parser); these asserts are here so the suite that owns the wrapper goes red when
# its own callers regress, rather than only the gate.
foreach ($rel in @('scripts\task\sync-main.ps1', 'scripts\task\push-preview.ps1')) {
    $text = Get-Content -LiteralPath (Join-Path $RepoRoot $rel) -Raw
    $leaf = Split-Path $rel -Leaf
    Assert-True ($text -notmatch '(?m)^\s*(\$\w+\s*=\s*)?&\s*shopify\b') "no bare '& shopify' call left in $leaf"
    # UNGUARDED, unlike the source-repo guard beside it: a payload missing the lib must fail at load
    # rather than run a call whose failure path cannot be reached.
    Assert-True ($text -match [regex]::Escape('. (Join-Path $PSScriptRoot ''..\lib\shopify-cli-lib.ps1'')')) "$leaf dot-sources the wrapper"
    Assert-True ($text -notmatch 'Test-Path[^\n]*shopify-cli-lib') "and unguarded, so $leaf fails at load without it"
}

# THE LIB TRAVELS IN dkj-subagents-shopify's OWN PAYLOAD. Without the registry entry the mirrored scripts
# dot-source a file that is not in the mirror, and both fail at load in every consumer that installed
# dkj-subagents-shopify. build-shared-scripts -Check cannot catch that: it compares the pairs the registry
# declares, so a missing entry is a pair it never looks at.
. (Join-Path $RepoRoot 'scripts\lib\shared-scripts-lib.ps1')
$pair = @(Get-SharedScriptPairs -RepoRoot $RepoRoot |
    Where-Object { $_.Plugin -eq 'dkj-subagents-shopify' -and $_.SourceRel -eq 'scripts\lib\shopify-cli-lib.ps1' })
Assert-Equal 1 $pair.Count 'the registry mirrors the wrapper into dkj-subagents-shopify'
Assert-True ($pair.Count -eq 1 -and (Test-Path -LiteralPath $pair[0].MirrorPath -PathType Leaf)) 'and that mirror is present beside the mirrored scripts'

Write-Host ""
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
