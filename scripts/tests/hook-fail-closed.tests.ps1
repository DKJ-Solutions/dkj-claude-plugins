<#
.SYNOPSIS
    Tests for the fail-closed wrapper around the two PreToolUse guards this workflow ships --
    guard-live-theme.ps1 (dkj-subagents-shopify) and guard-working-copy.ps1 (dkj-policy) -- as their
    hooks.json entries wire them (issue #2217).

.DESCRIPTION
    THE PROBLEM THIS HOLDS. A guard exits 2 to block, and the harness treats every other non-zero exit as
    a NON-blocking error: the tool call proceeds. So when PowerShell cannot start -- out of memory, a
    failed type initializer, a missing file -- the guard never runs a line, the harness reads the failure
    as non-blocking, and the command the guard exists to stop goes through. Measured September 20, 2026
    in the smartwatchbanden transcripts, on a sibling guard: four recorded start failures, exit codes
    127, 45, 66 and 1, none of them 2 -- so the failure cannot be told from the exit code alone, and no
    hooks.json field declares a hook fail-closed (the hooks documentation says a crashed or timed-out
    hook does not block, and that nothing configures otherwise).

    THE ONLY PLACE A START FAILURE IS VISIBLE is the layer above the interpreter, so the hooks.json
    command is a small bash wrapper: it runs the guard, passes 0 and 2 through untouched, and on any
    other exit code refuses (exit 2) ONLY when the payload looks like the guard's subject -- a Shopify
    theme command for the live-theme guard, a subagent running git for the working-copy guard. Any other
    call passes the failure through as it always did. That narrowness is the decision: a blanket refusal
    would block every Bash call on a machine whose PowerShell is unwell, to protect two rules that
    concern a small fraction of them.

    WHAT THIS SUITE PROVES, AND WHAT IT CANNOT. It runs the REAL command string from each hooks.json
    under Git Bash, with a stub `powershell` first on PATH that exits with a chosen code -- which is how
    a start failure looks from the wrapper's side. It cannot prove that Claude Code hands the string to
    bash on a given machine (the hooks documentation says bash by default, PowerShell only where Git
    Bash is not installed), and on a machine WITHOUT Git Bash the string is not valid in the shell it
    lands in, so the guard does not run there at all. That cost was stated and accepted when the
    wrapper was chosen; this suite does not hide it.

    Pure ASCII (repo convention for .ps1).
#>
# 'Continue', not 'Stop': the wrapper writes its refusal to stderr, and PowerShell 5.1 turns native
# stderr from a child process into a terminating NativeCommandError under 'Stop'. That stderr IS the
# expected output of a refusing case.
$ErrorActionPreference = 'Continue'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Fixture  = Join-Path ([System.IO.Path]::GetTempPath()) "hook-fail-closed-fixture-$PID-$([guid]::NewGuid().ToString('n'))"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
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

Write-Host "== hook-fail-closed.tests: the PreToolUse guards refuse when PowerShell cannot start ==" -ForegroundColor Cyan

# GIT'S bash, not whatever `bash` resolves to: on a Windows machine with WSL installed, System32\bash.exe
# comes first on PATH and reads a C:\ path as something else entirely. The harness launches Git's.
#
# WALKED UP FROM git.exe rather than taken one level: git sits at Git\cmd\git.exe when PowerShell launched
# it and at Git\mingw64\bin\git.exe when a Git Bash session did, and a fixed depth found bash in only one
# of them -- the other read as "no Git Bash" and the whole suite skipped, silently green. The standard
# install path is the last resort.
$bash = $null
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
$probe = if ($gitCmd) { Split-Path $gitCmd.Source } else { $null }
for ($i = 0; $probe -and $i -lt 4 -and -not $bash; $i++) {
    foreach ($rel in 'bin\bash.exe', 'usr\bin\bash.exe') {
        $cand = Join-Path $probe $rel
        if (Test-Path -LiteralPath $cand) { $bash = $cand; break }
    }
    $probe = Split-Path $probe
}
if (-not $bash) {
    $std = Join-Path $env:ProgramFiles 'Git\bin\bash.exe'
    if (Test-Path -LiteralPath $std) { $bash = $std }
}
if (-not $bash) {
    Write-Host "  [SKIP] no Git Bash found -- the wrapper is a bash command and cannot be exercised here" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Summary: 0 passed, 0 failed (skipped)" -ForegroundColor Green
    exit 0
}
$gitUsrBin = Join-Path (Split-Path (Split-Path $bash)) 'usr\bin'
if (-not (Test-Path -LiteralPath (Join-Path $gitUsrBin 'grep.exe'))) { $gitUsrBin = Split-Path $bash }

New-Item -ItemType Directory -Force -Path $Fixture | Out-Null
$stubDir = Join-Path $Fixture 'stub'
New-Item -ItemType Directory -Force -Path $stubDir | Out-Null
$stdinFile = Join-Path $Fixture 'stub-stdin.txt'

# THE STUB IS WHAT A START FAILURE LOOKS LIKE FROM THE WRAPPER'S SIDE: a `powershell` that returns the
# exit code the case chose and never reads the guard. It records its stdin so a case can prove the
# payload still reaches the interpreter intact through the wrapper.
[System.IO.File]::WriteAllText((Join-Path $stubDir 'powershell'),
    ("#!/bin/sh`ncat > `"`$STUB_STDIN`"`necho 'stub powershell' >&2`nexit `${STUB_RC:-0}`n"), $Utf8NoBom)
& $bash -c ("chmod +x '" + ((Join-Path $stubDir 'powershell') -replace '\\', '/') + "'") | Out-Null

function Get-WrapperCommand {
    param([string]$HooksJson)
    $entries = @((Get-Content -Raw -LiteralPath $HooksJson | ConvertFrom-Json).hooks.PreToolUse.hooks |
        Where-Object { $_.command -match 'guard-' })
    Assert-Equal 1 $entries.Count "$(Split-Path (Split-Path (Split-Path $HooksJson)) -Leaf): exactly one PreToolUse guard entry"
    return [string]$entries[0].command
}

function Invoke-Wrapper {
    <# Runs a hooks.json command string under Git Bash, payload on stdin. Returns @{ Code; Out }. #>
    param([string]$Command, [string]$Payload, [string]$PluginRoot, [string]$Path, [hashtable]$Env = @{})
    $script = Join-Path $Fixture ("run-" + [guid]::NewGuid().ToString('n') + '.sh')
    [System.IO.File]::WriteAllText($script, ($Command + "`n"), $Utf8NoBom)
    $saved = @{}
    $vars = @{ CLAUDE_PLUGIN_ROOT = $PluginRoot; PATH = $Path } + $Env
    foreach ($k in $vars.Keys) { $saved[$k] = [Environment]::GetEnvironmentVariable($k); [Environment]::SetEnvironmentVariable($k, $vars[$k]) }
    try {
        $out = $Payload | & $bash ($script -replace '\\', '/') 2>&1
        return @{ Code = $LASTEXITCODE; Out = (($out | ForEach-Object { "$_" }) -join "`n") }
    } finally {
        foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
    }
}

function Invoke-Stubbed {
    param([string]$Command, [string]$Payload, [int]$StubRc)
    Remove-Item -LiteralPath $stdinFile -ErrorAction SilentlyContinue
    return Invoke-Wrapper -Command $Command -Payload $Payload -PluginRoot $Fixture `
        -Path ($stubDir + ';' + $env:PATH) `
        -Env @{ STUB_RC = "$StubRc"; STUB_STDIN = ($stdinFile -replace '\\', '/') }
}

function Get-Json { param([string]$Cmd, [switch]$Agent)
    $o = [ordered]@{}
    if ($Agent) { $o.agent_id = 'agent-1'; $o.agent_type = 'general-purpose' }
    $o.tool_name = 'Bash'
    $o.tool_input = @{ command = $Cmd }
    return ($o | ConvertTo-Json -Compress -Depth 5)
}

try {
    $guards = @(
        @{
            Name = 'guard-live-theme'
            Json = Join-Path $RepoRoot 'plugins\dkj-subagents\dkj-subagents-shopify\hooks\hooks.json'
            Root = Join-Path $RepoRoot 'plugins\dkj-subagents\dkj-subagents-shopify'
            Subject = (Get-Json 'shopify theme push --live --theme 1')
            SubjectDesc = 'a Shopify theme command'
            Other = @(
                @{ Desc = 'an unrelated command'; Payload = (Get-Json 'ls -la') },
                @{ Desc = 'a shopify command that is not about themes'; Payload = (Get-Json 'shopify app dev') }
            )
            RealBlock = (Get-Json 'shopify theme publish --theme 1')
            RealAllow = (Get-Json 'ls -la')
        },
        @{
            Name = 'guard-working-copy'
            Json = Join-Path $RepoRoot 'plugins\dkj-policy\hooks\hooks.json'
            Root = Join-Path $RepoRoot 'plugins\dkj-policy'
            Subject = (Get-Json 'git checkout main' -Agent)
            SubjectDesc = 'a subagent running git'
            Other = @(
                @{ Desc = 'the main thread running git (the guard exempts it)'; Payload = (Get-Json 'git checkout main') },
                @{ Desc = 'a subagent running something that is not git'; Payload = (Get-Json 'ls -la' -Agent) },
                @{ Desc = 'a subagent whose command only CONTAINS the letters g-i-t (digital)'; Payload = (Get-Json 'echo digital' -Agent) }
            )
            RealBlock = (Get-Json 'git checkout main' -Agent)
            RealAllow = (Get-Json 'git checkout main')
        }
    )

    foreach ($g in $guards) {
        Write-Host ""
        Write-Host "-- $($g.Name) --" -ForegroundColor Cyan
        $cmd = Get-WrapperCommand -HooksJson $g.Json
        Assert-True ($cmd -match [regex]::Escape("hooks/$($g.Name).ps1")) "the wrapper still names $($g.Name).ps1 -- it is registered, not dead"
        Assert-True ($cmd -match '-ExecutionPolicy Bypass') 'and still passes -ExecutionPolicy Bypass, which the lint holds every hook invocation to'

        # 1. The guard's own verdicts are passed through untouched -- the wrapper adds nothing to a
        #    guard that ran.
        $r = Invoke-Stubbed -Command $cmd -Payload $g.Subject -StubRc 0
        Assert-Equal 0 $r.Code 'guard ran and allowed (exit 0): passes through as 0'
        $r = Invoke-Stubbed -Command $cmd -Payload $g.Subject -StubRc 2
        Assert-Equal 2 $r.Code 'guard ran and blocked (exit 2): passes through as 2'
        Assert-True ($r.Out -match 'stub powershell') 'and the guard''s own stderr still reaches the harness'

        # 2. THE POINT: an interpreter that did not run the guard, on a call the guard exists for.
        foreach ($rc in 1, 45, 66, 127) {
            $r = Invoke-Stubbed -Command $cmd -Payload $g.Subject -StubRc $rc
            Assert-Equal 2 $r.Code "start failure (exit $rc) on $($g.SubjectDesc): REFUSED -- fails closed"
        }
        $r = Invoke-Stubbed -Command $cmd -Payload $g.Subject -StubRc 45
        Assert-True ($r.Out -match "BLOCKED \($($g.Name)\)") 'the refusal names the guard'
        Assert-True ($r.Out -match 'exit 45') 'and the exit code the interpreter returned, so a reader can tell what failed'
        Assert-True ($r.Out -match 'Retry') 'and says what to do next'

        # 3. THE PAYLOAD STILL REACHES THE INTERPRETER. The wrapper reads stdin to judge it, so it has to
        #    hand it on -- a guard that runs on an empty stdin allows everything.
        Assert-Equal $g.Subject (([System.IO.File]::ReadAllText($stdinFile)).TrimEnd()) 'the payload arrives at powershell intact through the wrapper'

        # 4. THE NARROWNESS, which is the decision. A failure on any other call is passed through exactly
        #    as before: a non-blocking error, the call proceeds.
        foreach ($o in $g.Other) {
            $r = Invoke-Stubbed -Command $cmd -Payload $o.Payload -StubRc 45
            Assert-Equal 45 $r.Code "start failure on $($o.Desc): NOT refused -- the failure passes through unchanged"
        }

        # 5. NO POWERSHELL AT ALL is a platform without one, not a machine that is unwell: nothing to
        #    refuse on, and the exit is the 127 the hook has always produced there.
        $r = Invoke-Wrapper -Command $cmd -Payload $g.Subject -PluginRoot $g.Root -Path $gitUsrBin
        Assert-Equal 127 $r.Code 'no powershell on PATH: exit 127 as before, never a refusal'

        # 6. END TO END with the real interpreter and the real guard: the wrapper must not disturb a guard
        #    that runs.
        $r = Invoke-Wrapper -Command $cmd -Payload $g.RealBlock -PluginRoot $g.Root -Path $env:PATH `
            -Env @{ CLAUDE_PROJECT_DIR = $RepoRoot }
        Assert-Equal 2 $r.Code 'real guard, real payload it blocks: exit 2'
        Assert-True ($r.Out -match "BLOCKED \($($g.Name)\)") 'with the GUARD''s own refusal'
        Assert-True ($r.Out -notmatch 'could not run this guard') 'and not the wrapper''s -- the guard ran, so the wrapper stayed out of it'
        $r = Invoke-Wrapper -Command $cmd -Payload $g.RealAllow -PluginRoot $g.Root -Path $env:PATH `
            -Env @{ CLAUDE_PROJECT_DIR = $RepoRoot }
        Assert-Equal 0 $r.Code 'real guard, real payload it allows: exit 0'
    }
} finally {
    Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Summary: $script:pass passed, $script:fail failed" -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
