<#
.SYNOPSIS
    Tests for plugins/dkj-policy/bwj-development/hooks/guard-stale-paste-block.ps1 and its lib,
    scripts/lib/stale-paste-block-rules.ps1 -- the PreToolUse hook that refuses to ship a pull request
    closing an issue whose go-live block predates the issue's last reopen (inbound #2968), and to close an
    Asana-linked issue as completed by hand while it carries no block for this round (inbound #3004).

.DESCRIPTION
    FOUR GROUPS.
      1. THE COMMAND PARSER, in-process: which shell commands ship a PR, and which issues they name.
         An invocation counts and a mention does not; -GatesOnly is not a ship.
      2. THE FRESHNESS JUDGEMENT the hook asks (Get-AsanaPasteBlockVerdict in asana-task-lib.ps1) is
         asserted in bwj-development.tests.ps1 beside its copy in the closed-message template, so it
         is not repeated here.
      3. THE HOOK, as a process, against a FAKE gh.exe compiled into a temp directory and put first on
         the PATH. The fake answers 'repo view', 'pr view' and 'api graphql' (per issue number) from files,
         so every verdict path runs without a tracker: stale refused, fresh / never reopened / no block
         silent, and each way a read can fail passing with its warning. The fake is started once before
         the cases, and rebuilt where Smart App Control refuses that build (#2991).
      4. THE REGISTRATION: hooks.json matches the shell tools, greps the payload for the two scripts
         before it starts PowerShell, and names the file.

    Windows PowerShell 5.1 and Windows only, as guard-asana-mirror.tests.ps1 is: it starts 'powershell'
    and compiles the fake with Add-Type.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Continue'
$RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$PluginRoot = Join-Path $RepoRoot 'plugins\dkj-policy\bwj-development'
$Hook       = Join-Path $PluginRoot 'hooks\guard-stale-paste-block.ps1'
$HooksJson  = Join-Path $PluginRoot 'hooks\hooks.json'

. (Join-Path $PluginRoot 'scripts\lib\asana-task-lib.ps1')
. (Join-Path $PluginRoot 'scripts\lib\stale-paste-block-rules.ps1')

$script:pass = 0
$script:fail = 0
function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    if ($Expected -eq $Actual) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}
function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}

# --- 1. The command parser --------------------------------------------------------------------------
Write-Host 'the command parser' -ForegroundColor Cyan

$s = Get-ShipPrInvocation -Command "./scripts/release/ship-pr.ps1 -Resolves '331,332'"
Assert-Equal '331,332' (@($s.Resolves) -join ',') 'a quoted, comma-separated -Resolves names every issue'
$s = Get-ShipPrInvocation -Command 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\release\ship-pr.ps1 -Resolves 12'
Assert-Equal '12' (@($s.Resolves) -join ',') 'a powershell -File start is an invocation, with a bare number'
$s = Get-ShipPrInvocation -Command '& "C:\repo\scripts\release\open-pr.ps1" -Resolves "#7 #8"'
Assert-Equal '7,8' (@($s.Resolves) -join ',') 'the call operator and a double-quoted list of #numbers read the same'
$s = Get-ShipPrInvocation -Command 'git status; ./scripts/release/ship-pr.ps1 -Resolves 5 && echo done'
Assert-Equal '5' (@($s.Resolves) -join ',') 'a ship after another command in the line is found, and only its own segment is read'
$s = Get-ShipPrInvocation -Command './scripts/release/ship-pr.ps1 -Resolves 5,5,6'
Assert-Equal '5,6' (@($s.Resolves) -join ',') 'a number named twice is one'
$s = Get-ShipPrInvocation -Command './scripts/release/ship-pr.ps1'
Assert-True ($null -ne $s -and @($s.Resolves).Count -eq 0 -and -not $s.NoResolves) 'a ship with no -Resolves names no issue (the open PR may still close some)'
$s = Get-ShipPrInvocation -Command './scripts/release/ship-pr.ps1 -NoResolves'
Assert-True ($null -ne $s -and $s.NoResolves) '-NoResolves is the declared "closes no issue"'
Assert-True ($null -eq (Get-ShipPrInvocation -Command './scripts/release/open-pr.ps1 -GatesOnly')) '-GatesOnly opens no PR and merges nothing, so it is not a ship'
Assert-True ($null -eq (Get-ShipPrInvocation -Command 'git commit -m "touch ship-pr.ps1 -Resolves 5"')) 'a commit message that names the script is a mention, not an invocation'
Assert-True ($null -eq (Get-ShipPrInvocation -Command 'grep -n Resolves scripts/release/ship-pr.ps1')) 'and so is a grep'
Assert-True ($null -eq (Get-ShipPrInvocation -Command 'Get-Content scripts/release/open-pr.ps1')) 'and so is reading the file'
Assert-True ($null -eq (Get-ShipPrInvocation -Command '')) 'an empty command is nothing'
Assert-True ($null -eq (Get-ShipPrInvocation -Command './scripts/release/ship-pr.ps1.bak -Resolves 1')) 'a file that only starts with the name is not the script'
$many = Get-ShipPrInvocation -Command ('./scripts/release/ship-pr.ps1 -Resolves ' + ((1..40) -join ','))
Assert-Equal 20 @($many.Resolves).Count 'the issue list is bounded at 20'

# THE QUOTE-AWARE READING (an accident guard: see the lib's header for what stays out of reach).
$s = Get-ShipPrInvocation -Command 'pwsh -NoProfile ./scripts/release/ship-pr.ps1 -Resolves 5'
Assert-Equal '5' (@($s.Resolves) -join ',') 'a bare pwsh start with no -File is an invocation'
$s = Get-ShipPrInvocation -Command 'powershell.exe -NoProfile -ExecutionPolicy Bypass scripts\release\open-pr.ps1 -Resolves "#7"'
Assert-Equal '7' (@($s.Resolves) -join ',') 'and so is powershell.exe with options before the path'
$s = Get-ShipPrInvocation -Command '& "C:\My Repo\scripts\release\ship-pr.ps1" -Resolves 5'
Assert-Equal '5' (@($s.Resolves) -join ',') 'a quoted path with a space is one token'
$s = Get-ShipPrInvocation -Command './scripts/release/ship-pr.ps1 -Title "a; b | c" -Resolves 5'
Assert-Equal '5' (@($s.Resolves) -join ',') 'a separator inside a quoted string does not cut the command (-Resolves 5 survives)'
$s = Get-ShipPrInvocation -Command './scripts/release/ship-pr.ps1 -Title "-GatesOnly" -Resolves 5'
Assert-True ($null -ne $s -and @($s.Resolves).Count -eq 1) '-GatesOnly inside a quoted string is a value, not the flag'
$s = Get-ShipPrInvocation -Command './scripts/release/ship-pr.ps1 -Resolves 5 # -GatesOnly'
Assert-True ($null -ne $s -and @($s.Resolves).Count -eq 1) 'nor is it one after a # comment'
$s = Get-ShipPrInvocation -Command './scripts/release/ship-pr.ps1 -Title "fix -NoResolves" -Resolves 5'
Assert-True ($null -ne $s -and -not $s.NoResolves -and @($s.Resolves).Count -eq 1) 'and -NoResolves inside a quoted string is a value too'
$s = Get-ShipPrInvocation -Command './scripts/release/ship-pr.ps1 -Resolves:5,6'
Assert-Equal '5,6' (@($s.Resolves) -join ',') '-Resolves:5,6 reads like -Resolves 5,6'
Assert-True ($null -eq (Get-ShipPrInvocation -Command 'pwsh -Command "./scripts/release/ship-pr.ps1 -Resolves 5"')) 'pwsh -Command "..." is out of reach, by design: the workflow is the backstop'
Assert-True ($null -eq (Get-ShipPrInvocation -Command 'echo "ship-pr.ps1 -Resolves 5"')) 'a quoted mention is not an invocation'
Assert-True ($null -eq (Get-ShipPrInvocation -Command '# ./scripts/release/ship-pr.ps1 -Resolves 5')) 'and neither is a comment'

# THE CLOSE PARSER (#3004): a completed close by hand, the route smartwatchbanden#943 took past the ship guard.
Write-Host 'the close parser (#3004)' -ForegroundColor Cyan
function Format-Closes { param($c) if ($null -eq $c) { return '' } (@($c.Closes) | ForEach-Object { "$($_.Repo)#$($_.Number)" }) -join ',' }
Assert-Equal '#943' (Format-Closes (Get-IssueCloseInvocation -Command 'gh issue close 943')) 'a bare close is a close as completed'
Assert-Equal '#943' (Format-Closes (Get-IssueCloseInvocation -Command 'gh issue close 943 --reason completed --comment "done; see above"')) 'and so is --reason completed, a quoted comment with a separator in it read as one value'
Assert-Equal '#7,#8' (Format-Closes (Get-IssueCloseInvocation -Command 'gh issue close "#7" 8 -c x')) 'several issues, with #, are each named'
Assert-Equal 'BWJ-Development/smartwatchbanden#943' (Format-Closes (Get-IssueCloseInvocation -Command 'gh issue close 943 -R BWJ-Development/smartwatchbanden')) '-R names the repo'
Assert-Equal 'o/r#5' (Format-Closes (Get-IssueCloseInvocation -Command 'gh issue close --repo=o/r 5')) 'and so does --repo=, before the number'
Assert-Equal 'BWJ-Development/xoxowildhearts#414' (Format-Closes (Get-IssueCloseInvocation -Command 'gh issue close https://github.com/BWJ-Development/xoxowildhearts/issues/414')) 'an issue URL carries its own repo'
Assert-Equal '#9' (Format-Closes (Get-IssueCloseInvocation -Command 'git push; & "C:\Program Files\GitHub CLI\gh.exe" issue close 9')) 'gh.exe by a quoted path, after another command, is a close'
Assert-True ($null -eq (Get-IssueCloseInvocation -Command 'gh issue close 943 --reason "not planned"')) 'a close as not planned is not guarded: the closed message posts no block for it'
Assert-True ($null -eq (Get-IssueCloseInvocation -Command 'gh issue close 943 -r not_planned')) 'nor in its other spelling, under -r'
Assert-True ($null -eq (Get-IssueCloseInvocation -Command 'gh issue close 943 --reason=duplicate')) 'nor a duplicate'
Assert-True ($null -eq (Get-IssueCloseInvocation -Command 'gh issue close 943 --duplicate-of 12')) 'nor one closed with --duplicate-of'
Assert-True ($null -eq (Get-IssueCloseInvocation -Command 'gh issue view 943')) 'another gh issue command is not a close'
Assert-True ($null -eq (Get-IssueCloseInvocation -Command 'git commit -m "gh issue close 943"')) 'a mention in a commit message is not a close'
Assert-True ($null -eq (Get-IssueCloseInvocation -Command 'echo gh issue close 943')) 'and neither is an echo'
Assert-True ($null -eq (Get-IssueCloseInvocation -Command 'gh issue close')) 'a close that names no issue names nothing to judge'
Assert-True ($null -eq (Get-IssueCloseInvocation -Command 'gh issue close 5 -rnot_planned')) 'an attached short flag value is read, as gh reads it (-rnot_planned)'
Assert-Equal 'o/r#5' (Format-Closes (Get-IssueCloseInvocation -Command 'gh issue close 5 -Ro/r')) 'and so is -Ro/r'
Assert-Equal '#5' (Format-Closes (Get-IssueCloseInvocation -Command 'GH_TOKEN=x gh issue close 5')) 'an environment prefix does not hide the close'
Assert-Equal 20 @((Get-IssueCloseInvocation -Command ('gh issue close ' + ((1..40) -join ' '))).Closes).Count 'the list is bounded at 20'

# --- 3. The hook, against a fake gh -----------------------------------------------------------------
Write-Host 'the hook, against a fake gh' -ForegroundColor Cyan

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("stale-block-hook-" + [guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Path $work | Out-Null
$fakeSrc = @'
using System;
using System.IO;
public static class FakeGh {
    public static int Main(string[] args) {
        string dir = Environment.GetEnvironmentVariable("FAKE_GH_DIR");
        string key = "other";
        if (args.Length > 0 && args[0] == "repo") key = "repo";
        else if (args.Length > 0 && args[0] == "pr") key = "pr";
        else if (args.Length > 1 && args[0] == "api" && args[1] == "graphql") {
            foreach (string a in args) { if (a.StartsWith("num=")) key = "issue-" + a.Substring(4); }
        }
        File.AppendAllText(Path.Combine(dir, "calls.log"), key + "\n");
        string outp = Path.Combine(dir, key + ".out");
        string code = Path.Combine(dir, key + ".code");
        string err = Path.Combine(dir, key + ".err");
        if (File.Exists(outp)) Console.Out.Write(File.ReadAllText(outp));
        if (File.Exists(err)) Console.Error.Write(File.ReadAllText(err));
        if (File.Exists(code)) return int.Parse(File.ReadAllText(code).Trim());
        return File.Exists(outp) ? 0 : 1;
    }
}
'@
$fakeBin = Join-Path $work 'bin'
New-Item -ItemType Directory -Path $fakeBin | Out-Null
# A COMPILED FAKE MAY NOT BE ALLOWED TO RUN (#2991). Smart App Control in enforce mode judges an unsigned
# exe by its hash, and every compile has a new one: measured October 14, 2026, about one build in four was
# refused ("blocked by an application control policy"), and a refused build stays refused. The hook then
# took its fail-open path on every case and the run read as 19 failures with "could not resolve which
# repo". So the fake is started once here, and a refused build is compiled again -- new hash, new verdict.
# A .cmd fake is no way out: the hook starts 'gh' with UseShellExecute off, which finds an .exe only.
$fakeExe = Join-Path $fakeBin 'gh.exe'
$built = $false
$blocked = 0
foreach ($attempt in 1..6) {
    Remove-Item -LiteralPath $fakeExe -Force -ErrorAction SilentlyContinue
    try { Add-Type -TypeDefinition $fakeSrc -OutputAssembly $fakeExe -OutputType ConsoleApplication -ErrorAction Stop } catch { break }
    try {
        $probe = New-Object System.Diagnostics.ProcessStartInfo
        $probe.FileName = $fakeExe
        $probe.UseShellExecute = $false
        $probe.RedirectStandardOutput = $true
        $probe.RedirectStandardError = $true
        $probe.CreateNoWindow = $true
        $probe.EnvironmentVariables['FAKE_GH_DIR'] = $work
        $pp = [System.Diagnostics.Process]::Start($probe)
        $null = $pp.StandardError.ReadToEndAsync()
        $null = $pp.StandardOutput.ReadToEnd()
        $pp.WaitForExit()
        $built = $true
        break
    } catch { $blocked++ }
}
Assert-True $built "the fake gh.exe compiles and is allowed to start ($blocked build(s) refused by application control first)"

$stBlock = "<!-- asana-paste-block -->`nFraming.`n---`nGitHub issue o/r#7 is now closed.`n`nTE BEKIJKEN OP`nhttps://x.invalid/r`n---"

function New-State {
    <# The GraphQL reply the hook reads: a reopen time (or none) and comments of (body, time). #>
    param([string]$Reopen = '', [object[]]$Comments = @(), [int]$Total = -1, [string]$Body = '')
    $nodes = @(foreach ($c in $Comments) { @{ body = $c[0]; createdAt = $c[1] } })
    $reopened = @(if ($Reopen) { @{ createdAt = $Reopen } })
    if ($Total -lt 0) { $Total = $nodes.Count }
    return (ConvertTo-Json -Compress -Depth 8 @{ data = @{ repository = @{ issue = @{
        body     = $Body
        reopened = @{ nodes = $reopened }
        comments = @{ totalCount = $Total; nodes = $nodes } } } } })
}

function Reset-Fake {
    Get-ChildItem -LiteralPath $work -File | Remove-Item -Force
    [System.IO.File]::WriteAllText((Join-Path $work 'repo.out'), "DKJ-Solutions/xoxo`n")
    [System.IO.File]::WriteAllText((Join-Path $work 'pr.code'), '1')
    [System.IO.File]::WriteAllText((Join-Path $work 'pr.err'), 'no pull requests found for branch "feat/x"')
}
function Set-Fake { param([string]$Name, [string]$Text) [System.IO.File]::WriteAllText((Join-Path $work $Name), $Text) }

function Invoke-Hook {
    <# Runs the hook with a shell command as the payload, the fake gh first on PATH; returns Code, Err, Calls. #>
    param([string]$Command, [string]$Payload, [switch]$Bom)
    if (-not $PSBoundParameters.ContainsKey('Payload')) { $Payload = ConvertTo-Json -Compress @{ tool_name = 'Bash'; tool_input = @{ command = $Command } } }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell'
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$Hook`""
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.EnvironmentVariables['PATH'] = "$fakeBin;" + $env:PATH
    $psi.EnvironmentVariables['FAKE_GH_DIR'] = $work
    $psi.EnvironmentVariables['CLAUDE_PROJECT_DIR'] = $RepoRoot
    $p = [System.Diagnostics.Process]::Start($psi)
    # BYTES, AND NO BOM: StandardInput.Write encodes with the PARENT's console input code page, and where a
    # sibling suite has put the shared console on UTF-8 that prefixes a byte-order mark -- which broke the
    # hook's JSON parse, so every case under the test gate got exit 0 and no verdict. -Bom sends one on
    # purpose, to hold the hook to ignoring it.
    $bytes = (New-Object System.Text.UTF8Encoding $Bom).GetBytes($Payload)
    if ($Bom) { $bytes = [byte[]](0xEF, 0xBB, 0xBF) + (New-Object System.Text.UTF8Encoding $false).GetBytes($Payload) }
    $p.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
    $p.StandardInput.Close()
    $errTask = $p.StandardError.ReadToEndAsync()
    $out = $p.StandardOutput.ReadToEnd()
    $p.WaitForExit()
    $calls = Join-Path $work 'calls.log'
    # Json: the PreToolUse decision a fail-open prints (#3058), or $null where stdout carries none.
    $json = $null
    if ($out.Trim()) { try { $json = (ConvertFrom-Json -InputObject $out).hookSpecificOutput } catch { $json = 'unparseable' } }
    return @{ Code = $p.ExitCode; Err = $errTask.Result; Out = $out; Json = $json; Calls = $(if (Test-Path -LiteralPath $calls) { @(Get-Content -LiteralPath $calls) } else { @() }) }
}

if ($built) {
    $ship = './scripts/release/ship-pr.ps1 -Resolves 7'

    Reset-Fake
    Set-Fake 'issue-7.out' (New-State -Reopen '2026-10-02T10:00:00Z' -Comments @(, @($stBlock, '2026-10-01T10:00:00Z')))
    $r = Invoke-Hook $ship
    Assert-Equal 2 $r.Code 'a block older than the last reopen refuses the ship'
    Assert-True ($r.Err -match 'BLOCKED \(guard-stale-paste-block\): DKJ-Solutions/xoxo#7 carries a go-live block from before its last reopen') 'and names the issue'
    Assert-True ($r.Err -match 'build-golive-block\.ps1 -Issue 7 .*-Post') 'and the fix, on one line, with the issue number filled in'
    Assert-True ($r.Err -notmatch 'TE BEKIJKEN|x\.invalid') 'no comment text reaches stderr'

    Reset-Fake
    Set-Fake 'issue-7.out' (New-State -Reopen '2026-10-02T10:00:00Z' -Comments @(, @($stBlock, '2026-10-01T10:00:00Z')))
    Set-Fake 'issue-8.out' (New-State -Reopen '2026-10-02T10:00:00Z' -Comments @(, @($stBlock, '2026-10-01T10:00:00Z')))
    $r = Invoke-Hook './scripts/release/ship-pr.ps1 -Resolves 7,8'
    Assert-Equal 2 $r.Code 'two stale issues refuse once'
    Assert-True ($r.Err -match '#7, DKJ-Solutions/xoxo#8 each carry' -and $r.Err -notmatch 'carries') 'and the message is plural'

    Reset-Fake
    Set-Fake 'issue-7.out' (New-State -Reopen '2026-10-02T10:00:00Z' -Comments @(@($stBlock, '2026-10-01T10:00:00Z'), @("<!-- asana-paste-block -->`n---`n---", '2026-10-03T10:00:00Z')))
    $r = Invoke-Hook $ship
    Assert-Equal 2 $r.Code 'a newer degenerate marker comment does not make the older block fresh (#2968)'

    Reset-Fake
    Set-Fake 'issue-7.out' (New-State -Reopen '2026-10-02T10:00:00Z' -Comments @(, @($stBlock, '2026-10-03T10:00:00Z')))
    $r = Invoke-Hook $ship
    Assert-Equal 0 $r.Code 'a block newer than the reopen passes'
    Assert-Equal '' $r.Err.Trim() 'silently'
    Assert-Equal '' $r.Out.Trim() 'and with nothing on stdout: a checked pass needs no decision (#3058)'

    Reset-Fake
    Set-Fake 'issue-7.out' (New-State -Comments @(, @($stBlock, '2026-10-01T10:00:00Z')))
    $r = Invoke-Hook $ship
    Assert-Equal 0 $r.Code 'an issue never reopened passes'
    Assert-Equal '' $r.Err.Trim() 'silently'

    Reset-Fake
    Set-Fake 'issue-7.out' (New-State -Reopen '2026-10-02T10:00:00Z' -Comments @(, @('just a comment', '2026-10-01T10:00:00Z')))
    $r = Invoke-Hook $ship
    Assert-Equal 0 $r.Code 'a reopened issue with no block at all passes'
    Assert-Equal '' $r.Err.Trim() 'silently'

    Reset-Fake
    Set-Fake 'issue-7.out' (New-State -Reopen '2026-10-02T10:00:00Z' -Comments @(, @("question`n<!-- asana-paste-block -->", '2026-10-03T10:00:00Z')))
    $r = Invoke-Hook $ship
    Assert-Equal 0 $r.Code 'a marker comment that is no block (a question) is no block either'

    Reset-Fake
    Set-Fake 'issue-7.out' (New-State -Reopen '2026-10-02T10:00:00Z' -Comments @(@($stBlock, '2026-10-01T10:00:00Z'), @($stBlock, '2026-10-02T10:00:00Z')))
    $r = Invoke-Hook $ship
    Assert-Equal 2 $r.Code 'several blocks, all at or before the reopen: still stale'

    Reset-Fake
    Set-Fake 'issue-7.code' '1'
    $r = Invoke-Hook $ship
    Assert-Equal 0 $r.Code 'an issue gh cannot read passes'
    Assert-True ($r.Err -match 'could not judge the go-live block of #7') 'with a warning that names it'
    # #3058: stderr on an exit 0 never reaches the model, so the warning is said as PreToolUse JSON too.
    Assert-True ($null -ne $r.Json -and $r.Json -ne 'unparseable' -and $r.Json.hookEventName -eq 'PreToolUse') 'the fail-open prints PreToolUse JSON (#3058)'
    Assert-True ([string]$r.Json.additionalContext -match 'could not judge the go-live block of #7') 'whose additionalContext tells the model what was not checked'
    Assert-True ($null -eq $r.Json.permissionDecision) 'and a ship only informs: the workflow is its backstop, so no ask'

    Reset-Fake
    Set-Fake 'issue-7.out' 'this is not json'
    $r = Invoke-Hook $ship
    Assert-Equal 0 $r.Code 'an unparseable reply passes'
    Assert-True ($r.Err -match 'could not judge') 'with the same warning'

    # The pre-gate matches a close by text; once parsed, a MENTION of one is no close to ask about (#3058).
    Reset-Fake
    Set-Fake 'issue-7.code' '1'
    $r = Invoke-Hook "git commit -m `"gh issue close 5`"; $ship"
    Assert-True ([string]$r.Json.additionalContext -match 'could not judge the go-live block of #7') 'a ship beside a mentioned close still informs (#3058)'
    Assert-True ($null -eq $r.Json.permissionDecision) 'and does not ask, because no close is invoked'

    Reset-Fake
    Set-Fake 'issue-7.out' (New-State -Comments @(, @('talk', '2026-10-01T10:00:00Z')) -Total 150)
    $r = Invoke-Hook $ship
    Assert-Equal 0 $r.Code 'an issue with more comments than one read returns and no block among them passes'
    Assert-True ($r.Err -match 'could not judge') 'with a warning, because an older comment was not read'

    Reset-Fake
    Remove-Item -LiteralPath (Join-Path $work 'repo.out')
    $r = Invoke-Hook $ship
    Assert-Equal 0 $r.Code 'a repo that cannot be resolved passes'
    Assert-True ($r.Err -match 'could not resolve which repo') 'with a warning'
    Assert-True ([string]$r.Json.additionalContext -match 'could not resolve which repo') 'said to the model as well (#3058)'
    Assert-True (-not ($r.Calls -match 'issue-')) 'and no issue is read'

    # WHICH ISSUES: -Resolves, plus the closing issues of the PR already open, same repo only.
    Reset-Fake
    Set-Fake 'pr.code' '0'
    Set-Fake 'pr.out' '{"closingIssuesReferences":[{"number":9,"repository":{"name":"xoxo","owner":{"login":"DKJ-Solutions"}}},{"number":10,"repository":{"name":"other","owner":{"login":"DKJ-Solutions"}}}]}'
    Set-Fake 'issue-9.out' (New-State -Reopen '2026-10-02T10:00:00Z' -Comments @(, @($stBlock, '2026-10-01T10:00:00Z')))
    $r = Invoke-Hook './scripts/release/ship-pr.ps1'
    Assert-Equal 2 $r.Code 'a re-ship with no -Resolves checks what the open PR closes'
    Assert-True ($r.Err -match 'xoxo#9') 'and names that issue'
    Assert-True (-not ($r.Calls -contains 'issue-10')) 'an issue of another repo is not read'

    Reset-Fake
    Set-Fake 'pr.code' '0'
    Set-Fake 'pr.out' '{"closingIssuesReferences":[{"number":9,"repository":{"name":"xoxo","owner":{"login":"DKJ-Solutions"}}}]}'
    Set-Fake 'issue-9.out' (New-State -Reopen '2026-10-02T10:00:00Z' -Comments @(, @($stBlock, '2026-10-01T10:00:00Z')))
    Set-Fake 'issue-7.out' (New-State -Comments @())
    $r = Invoke-Hook './scripts/release/ship-pr.ps1 -Resolves 7'
    Assert-Equal 2 $r.Code 'the union of -Resolves and the open PR is checked'
    Assert-True ($r.Err -match 'xoxo#9' -and $r.Err -notmatch 'xoxo#7') 'and only the stale one is named'

    Reset-Fake
    Set-Fake 'pr.code' '0'
    Set-Fake 'pr.out' '{"closingIssuesReferences":[{"number":9,"repository":{"name":"xoxo","owner":{"login":"DKJ-Solutions"}}}]}'
    Set-Fake 'issue-9.out' (New-State -Reopen '2026-10-02T10:00:00Z' -Comments @(, @($stBlock, '2026-10-01T10:00:00Z')))
    $r = Invoke-Hook './scripts/release/ship-pr.ps1 -NoResolves'
    Assert-Equal 0 $r.Code '-NoResolves does not consult the open PR'
    Assert-Equal 0 @($r.Calls).Count 'and makes no gh call at all'

    Reset-Fake
    Set-Fake 'pr.code' '1'
    Set-Fake 'pr.err' 'HTTP 502'
    $r = Invoke-Hook './scripts/release/ship-pr.ps1'
    Assert-Equal 0 $r.Code 'an open-PR read that failed passes'
    Assert-True ($r.Err -match 'could not be read') 'with a warning'

    # THE PATHS THAT MAKE NO GH CALL.
    Reset-Fake
    $r = Invoke-Hook './scripts/release/open-pr.ps1 -GatesOnly -Resolves 7'
    Assert-Equal 0 $r.Code '-GatesOnly passes'
    Assert-Equal 0 @($r.Calls).Count 'without asking gh anything'
    $r = Invoke-Hook 'git commit -m "mention ship-pr.ps1 -Resolves 7"'
    Assert-Equal 0 $r.Code 'a mention passes'
    Assert-Equal 0 @($r.Calls).Count 'without asking gh anything'
    $r = Invoke-Hook 'git status'
    Assert-Equal 0 $r.Code 'an unrelated command passes at the pre-gate'
    Reset-Fake
    Set-Fake 'issue-7.out' (New-State -Reopen '2026-10-02T10:00:00Z' -Comments @(, @($stBlock, '2026-10-01T10:00:00Z')))
    $r = Invoke-Hook $ship -Bom
    Assert-Equal 2 $r.Code 'a payload with a byte-order mark is judged like any other (the gate''s shared UTF-8 console, #2968)'
    $r = Invoke-Hook '' -Payload ''
    Assert-Equal 0 $r.Code 'an empty payload passes'
    $r = Invoke-Hook '' -Payload 'ship-pr.ps1 but not json'
    Assert-Equal 0 $r.Code 'an unparseable payload passes rather than blocking every shell call'
    Assert-True ([string]$r.Json.additionalContext -match 'did not parse as JSON') 'and says so to the model (#3058)'

    # THE CLOSE GUARD (#3004): a completed close by hand of an Asana-linked issue needs a block for this round.
    $linked   = "Body`n<!-- asana-task: 1234567890 -->"
    $research = "<!-- asana-paste-block -->`n<!-- asana-paste-block-kind: research -->`nFraming.`n---`nGitHub issue o/r#943 is now closed. Nothing has changed.`n`nWAT WE GEVONDEN HEBBEN`n`nNiets mis.`n---"
    $close    = 'gh issue close 943'

    Reset-Fake
    Set-Fake 'issue-943.out' (New-State -Body $linked -Comments @(, @('the conclusion, in a comment', '2026-10-14T10:00:00Z')))
    $r = Invoke-Hook $close
    Assert-Equal 2 $r.Code 'an Asana-linked issue with no block refuses the close -- smartwatchbanden#943''s route'
    Assert-True ($r.Err -match 'BLOCKED \(guard-stale-paste-block\): no go-live block on DKJ-Solutions/xoxo#943') 'and names the issue'
    Assert-True ($r.Err -notmatch '-Repo |-R ') 'and, for the checkout''s own issue, names no repo in the fix'
    Assert-True ($r.Err -match 'build-golive-block\.ps1 -Issue 943 -Research -ProseFile' -and $r.Err -match 'build-golive-block\.ps1 -Issue 943 -Link') 'with both fixes, the research block and the result block'
    Assert-True ($r.Err -match 'gh issue close 943 --reason "not planned"') 'and the close for a ticket where nothing was done'
    Assert-True ($r.Err -notmatch 'conclusion') 'no comment text reaches stderr'

    Reset-Fake
    Set-Fake 'issue-943.out' (New-State -Body $linked -Comments @(, @($research, '2026-10-14T10:00:00Z')))
    $r = Invoke-Hook $close
    Assert-Equal 0 $r.Code 'a research block on the issue lets the close through'
    Assert-Equal '' $r.Err.Trim() 'silently'

    Reset-Fake
    Set-Fake 'issue-943.out' (New-State -Body $linked -Reopen '2026-10-02T10:00:00Z' -Comments @(, @($stBlock, '2026-10-01T10:00:00Z')))
    $r = Invoke-Hook $close
    Assert-Equal 2 $r.Code 'a block from before the last reopen refuses the close too'
    Assert-True ($r.Err -match 'only a block from before the last reopen on DKJ-Solutions/xoxo#943') 'and says which of the two it is'

    Reset-Fake
    Set-Fake 'issue-943.out' (New-State -Body $linked -Reopen '2026-10-02T10:00:00Z' -Comments @(, @($stBlock, '2026-10-03T10:00:00Z')))
    $r = Invoke-Hook $close
    Assert-Equal 0 $r.Code 'a block of this round lets the close through'

    Reset-Fake
    Set-Fake 'issue-943.out' (New-State -Body 'no task linked here' -Comments @())
    $r = Invoke-Hook $close
    Assert-Equal 0 $r.Code 'an issue linking no Asana task closes freely: the closed message posts nothing for it'
    Assert-Equal '' $r.Err.Trim() 'silently'

    Reset-Fake
    Set-Fake 'issue-943.out' (New-State -Body $linked -Comments @())
    $r = Invoke-Hook 'gh issue close 943 --reason "not planned"'
    Assert-Equal 0 $r.Code 'a close as not planned is not judged'
    Assert-Equal 0 @($r.Calls).Count 'and costs no gh call'

    Reset-Fake
    Set-Fake 'issue-943.code' '1'
    $r = Invoke-Hook $close
    Assert-Equal 0 $r.Code 'an issue gh cannot read lets the close through'
    Assert-True ($r.Err -match 'could not judge the go-live block of DKJ-Solutions/xoxo#943 -- the close was NOT checked') 'with a warning that names it'
    # #3058, smartwatchbanden#946's route: a close has no backstop that can still stop it, so a person is asked.
    Assert-Equal 'ask' ([string]$r.Json.permissionDecision) 'an unchecked close asks before it runs (#3058)'
    Assert-True ([string]$r.Json.permissionDecisionReason -match 'xoxo#943 -- the close was NOT checked') 'with the reason, naming the issue'
    Assert-True ([string]$r.Json.additionalContext -match 'the close was NOT checked') 'and the model is told too'

    Reset-Fake
    Set-Fake 'issue-943.out' (New-State -Body $linked -Comments @(, @('talk', '2026-10-01T10:00:00Z')) -Total 150)
    $r = Invoke-Hook $close
    Assert-Equal 0 $r.Code 'more comments than one read returns, and no block among them: the close passes'
    Assert-True ($r.Err -match 'could not judge') 'with a warning, because an older comment was not read'

    Reset-Fake
    Set-Fake 'issue-943.out' (New-State -Body $linked -Comments @())
    $r = Invoke-Hook 'gh issue close 943 -R BWJ-Development/smartwatchbanden'
    Assert-Equal 2 $r.Code 'a close in another repo, named with -R, is judged there'
    Assert-True ($r.Err -match 'BWJ-Development/smartwatchbanden#943') 'and named by that repo'
    Assert-True ($r.Err -match '-Issue 943 -Repo BWJ-Development/smartwatchbanden -Research' -and $r.Err -match 'gh issue close 943 -R BWJ-Development/smartwatchbanden --reason') 'and the fix points at that repo''s issue, not the checkout''s'
    Assert-True (-not ($r.Calls -contains 'repo')) 'without asking which repo the checkout is'
}

Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue

# --- 4. The registration ------------------------------------------------------------------------------
Write-Host 'the registration' -ForegroundColor Cyan
$hooks = Get-Content -LiteralPath $HooksJson -Raw | ConvertFrom-Json
$entry = @($hooks.hooks.PreToolUse | Where-Object { $_.matcher -eq 'Bash|PowerShell' })
Assert-Equal 1 $entry.Count 'hooks.json has one PreToolUse entry on the shell tools'
$cmd = [string]$entry[0].hooks[0].command
Assert-True ($cmd.Contains('guard-stale-paste-block.ps1')) 'it runs this hook'
Assert-True ($cmd -match "grep -Eq '\(ship-pr\|open-pr\)\\\.ps1\|gh\(\\\.exe\)\?\[\[:space:\]\]\+issue\[\[:space:\]\]\+close' \|\| exit 0") 'behind a shell pre-gate on the two scripts and gh issue close (#3004), so no other command pays a PowerShell start'
Assert-True ($cmd.IndexOf('grep -Eq') -lt $cmd.IndexOf('powershell -NoProfile')) 'the pre-gate comes before PowerShell starts'
Assert-True ($cmd -notmatch 'fail-closed|exit 2') 'and carries no fail-closed wrapper: the hook fails open on purpose (its header says why)'
Assert-True ([int]$entry[0].hooks[0].timeout -ge 30) 'with the timeout the hook''s 25-second budget is sized for'
$guard = @($hooks.hooks.PreToolUse | Where-Object { $_.matcher -like 'mcp__*' })
Assert-Equal 1 $guard.Count 'and the Asana create-task guard is still registered beside it'

Write-Host ''
if ($script:fail -eq 0) { Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green; exit 0 }
Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
exit 1
