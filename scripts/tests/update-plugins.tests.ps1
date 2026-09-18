<#
.SYNOPSIS
    Tests for scripts/task/update-plugins.ps1 -- #1890's "1 + N commands, run as one" wrapper.

.DESCRIPTION
    The script never talks to the real `claude` CLI or the real plugin-versions.ps1 receipt: a `claude`
    shim on PATH (a .cmd, for the reason park-cycle.tests.ps1's own gh.cmd shim states -- only an
    executable extension on PATHEXT is found by Invoke-NativeCapture's native resolution) ECHOES its
    own argument line, prefixed 'CLAUDE-SHIM-CALLED', so a scenario can tell "the CLI ran with these
    args" apart from "the -DryRun line merely PRINTED the same words" -- the echoed line only exists
    when the shim itself executed. A fixture receipt .ps1 stands in for plugin-versions.ps1 via
    -ReceiptScriptOverride and prints 'FIXTURE-RECEIPT root=... home=...' so a scenario can assert both
    that step 3 ran at all and that it received the same -RootOverride/-UserHomeOverride the caller
    passed to update-plugins.ps1 itself.

    Everything the script prints (the shim's echo included, since it is re-printed by the script's own
    Write-Host per output line, and the receipt's own stdout, since Start-Process -NoNewWindow with no
    redirection of its own inherits the SAME redirected-to-file handle the outer capture already set up)
    lands in one Invoke-NativeCapture -Utf8 result, so every scenario asserts on that one captured text
    exactly like plugin-versions.tests.ps1 already does.

    Scenarios:
      1  two plugins, one marketplace, no failures      -> one marketplace-update call, two
                                                             plugin-update calls (--scope project each),
                                                             the receipt ran with the SAME
                                                             -RootOverride/-UserHomeOverride, exit 0,
                                                             "0 failed"
      2  -DryRun                                        -> every command PRINTED, the shim never ran
                                                             (no CLAUDE-SHIM-CALLED line) and neither did
                                                             the receipt (no FIXTURE-RECEIPT line), exit 0
      3  no plugins enabled                             -> "Nothing to update", exit 0, shim/receipt
                                                             both silent
      4  one malformed id among two valid enables       -> a Skipped line names it, the two valid ids
                                                             still update normally, exit 0
      5  every enabled id is malformed                  -> "Nothing left to update", exit 1, shim/receipt
                                                             both silent (no marketplace call either --
                                                             there is no valid target to derive one from)
      6  the marketplace refresh fails                  -> a FAILED line under step 1, the plugin update
                                                             calls run ANYWAY (continues past a failure),
                                                             the receipt still runs, exit 1
      7  one of two plugin updates fails                -> a FAILED line under step 2 naming only that
                                                             plugin, the OTHER plugin's update still ran,
                                                             the receipt still runs, exit 1
      8  two distinct marketplaces                      -> both are refreshed, in ORDINAL sorted order
      9  a machine-wide (path-less) record beside a     -> '--scope user' and '--scope project'
         record for this checkout, in ONE run                respectively: the scope is per plugin,
                                                             read off the install record (#1986)
      10 -DryRun with a 'local' record                  -> the PRINTED command carries that scope too,
                                                             and stays paste-ready -- nothing is
                                                             appended to it
      11 a record stating no scope at all               -> falls back to project exactly as before, AND
                                                             says so, in a block printed ABOVE step 1
                                                             rather than inside step 2's own output

    Dependency-free (no Pester), same style as plugin-versions.tests.ps1. Pure ASCII (repo convention
    for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Script   = Join-Path $RepoRoot 'scripts\task\update-plugins.ps1'
$Fixture  = Join-Path ([System.IO.Path]::GetTempPath()) "update-plugins-test-$PID-$([guid]::NewGuid().ToString('n'))"
$Utf8Ascii = New-Object System.Text.ASCIIEncoding
$Utf8      = New-Object System.Text.UTF8Encoding $false

. (Join-Path $RepoRoot 'scripts\lib\native-capture-lib.ps1')

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
function Assert-Has {
    param([object]$Run, [string]$Needle, [string]$Label)
    Assert-True ($Run.Squish.Contains(($Needle -replace '\s', ''))) $Label
}
function Assert-Lacks {
    param([object]$Run, [string]$Needle, [string]$Label)
    Assert-True (-not $Run.Squish.Contains(($Needle -replace '\s', ''))) $Label
}
function Assert-Before {
    # $First's first occurrence comes before $Second's -- for the ordinal-sort scenario (8).
    param([object]$Run, [string]$First, [string]$Second, [string]$Label)
    $i1 = $Run.Text.IndexOf($First)
    $i2 = $Run.Text.IndexOf($Second)
    Assert-True (($i1 -ge 0) -and ($i2 -ge 0) -and ($i1 -lt $i2)) $Label
}

# Runs in which a capture came back with no measurable exit code -- see Assert-CleanExit (issue #2114).
$script:unmeasured = 0

function Assert-CleanExit {
    <#
        Assert that a run the script should finish cleanly exited 0 -- UNLESS a capture inside it came
        back with no measurable exit code, which the script is SPECIFIED to answer with exit 1.

        THE TWO STATEMENTS COULD NOT BOTH HOLD, and that is the whole of #2114. update-plugins.ps1
        drives the CLI through Invoke-NativeCapture's -Utf8 arm, and that arm can hand back an ExitCode
        which is literally $null -- the child ran, but the value is not a measurement of it (#1931). The
        script consults that state through Get-NativeExitLabel and DELIBERATELY counts it as a failure:
        #2081's audit argues the point at scripts/task/update-plugins.ps1:207 -- this script answers
        "did every update succeed", and for an updater the conservative answer to "I could not tell" is
        no. That decision stands. What could not stand beside it was a suite asserting exit 0 on eight
        scenarios regardless.

        AND THE ARITHMETIC IS WHY THIS IS NOT A RARE EDGE. #1931 measured the state at 2.8% PER CAPTURE
        under 16 lanes of fresh PowerShell children. A full run of this suite makes on the order of 30
        captures through that arm, so the chance of at least one landing in a run is roughly 50% -- not
        the 1-in-300 that the per-capture figure suggests to a quick reader. Measured on PR #2113: red
        in CI twice out of two, green standalone on the same tree, and NOT contention (the focus
        reproducer passed 4/4 under 30 lanes).

        SO THE RUN IS STILL ASSERTED ON, JUST NOT ON THE NUMBER THE RACE OWNS. Everything else in each
        scenario -- which commands ran, with which ids, at which scopes, in which order -- is unaffected
        by this state and is asserted exactly as before. Those are the assertions that carry the
        scenario's meaning; the exit code was the one field a documented race is allowed to move.

        IT IS NOT A BLANKET "0 OR 1". The marker has to be in the output: a run that exits 1 without one
        is a real failure and still fails here.
    #>
    param(
        [Parameter(Mandatory = $true)][object]$Run,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if ($Run.Code -eq 0) { Assert-Equal 0 $Run.Code $Label; return }

    # The phrase Get-NativeExitLabel emits for the unmeasurable case. Matched on its stable opening
    # rather than the whole sentence, which carries an issue number and a remedy clause.
    if ("$($Run.Text)" -match 'no measurable exit code') {
        $script:unmeasured++
        Write-Host "  [UNMEASURED] $Label -- a capture in this run had no measurable exit code (#1931), which this script is specified to answer with exit 1" -ForegroundColor Yellow
        return
    }

    Assert-Equal 0 $Run.Code $Label
}

# --- fixture builders --------------------------------------------------------------------------

function New-Case {
    param([Parameter(Mandatory = $true)][string]$Label)
    $repo = Join-Path $Fixture "$Label\repo"
    $homeDir = Join-Path $Fixture "$Label\home"
    $bin  = Join-Path $Fixture "$Label\bin"
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    New-Item -ItemType Directory -Path $homeDir -Force | Out-Null
    New-Item -ItemType Directory -Path $bin  -Force | Out-Null
    [pscustomobject]@{
        Repo    = $repo
        Home    = $homeDir
        Bin     = $bin
        Receipt = (Join-Path $Fixture "$Label\receipt.ps1")
    }
}

function Set-Enabled {
    param([string]$RepoDir, [string[]]$Ids = @())
    New-Item -ItemType Directory -Path (Join-Path $RepoDir '.claude') -Force | Out-Null
    $ep = @{}
    foreach ($i in $Ids) { $ep[$i] = $true }
    [System.IO.File]::WriteAllText((Join-Path $RepoDir '.claude\settings.json'),
        (@{ enabledPlugins = $ep } | ConvertTo-Json -Depth 5), $Utf8)
}

function Set-InstallRecords {
    <#
        Writes the fixture home's ~/.claude/plugins/installed_plugins.json -- the administration
        Get-InstallRecord reads, and therefore the file that decides every step-2 `--scope` (#1986).
        $Records is id -> array of hashtables; a record carrying no 'projectPath' is the PATHLESS
        (machine-wide) shape, and one carrying it is a record for this checkout.

        The path is written as given: Get-InstallRecord resolves both sides with Resolve-Path before
        comparing, so the caller hands over the fixture repo's real path and nothing here has to
        normalise it.
    #>
    param([Parameter(Mandatory = $true)][string]$HomeDir, [Parameter(Mandatory = $true)][hashtable]$Records)
    $dir = Join-Path $HomeDir '.claude\plugins'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $dir 'installed_plugins.json'),
        (@{ plugins = $Records } | ConvertTo-Json -Depth 6), $Utf8)
}

function New-ClaudeShim {
    <#
        A claude.cmd on PATH. ECHOES its own arg line prefixed 'CLAUDE-SHIM-CALLED' -- proof the CLI
        actually ran, as distinct from -DryRun merely printing the same words -- and exits 1 only when
        the arg line contains $FailNeedle (empty: never fails). A .cmd rather than a .ps1: Invoke-
        NativeCapture resolves 'claude' as a native command, found on PATHEXT only as an executable
        (same reasoning as park-cycle.tests.ps1's gh.cmd shim).
    #>
    param([Parameter(Mandatory = $true)][string]$BinDir, [string]$FailNeedle = '')
    $body = if ($FailNeedle) {
        "@echo off`r`necho CLAUDE-SHIM-CALLED %*`r`necho %* | findstr /C:`"$FailNeedle`" >nul`r`nif errorlevel 1 (exit /b 0) else (exit /b 1)`r`n"
    } else {
        "@echo off`r`necho CLAUDE-SHIM-CALLED %*`r`nexit /b 0`r`n"
    }
    [System.IO.File]::WriteAllText((Join-Path $BinDir 'claude.cmd'), $body, $Utf8Ascii)
}

function New-Receipt {
    # Stands in for plugin-versions.ps1 via -ReceiptScriptOverride. Prints its own two params so a
    # scenario can confirm update-plugins.ps1 forwarded the SAME -RootOverride/-UserHomeOverride it was
    # itself given, rather than the receipt silently reading a different pair (or none).
    param([Parameter(Mandatory = $true)][string]$Path)
    $body = "param([string]`$RootOverride = '', [string]`$UserHomeOverride = '')`r`nWrite-Host `"FIXTURE-RECEIPT root=`$RootOverride home=`$UserHomeOverride`"`r`nexit 0`r`n"
    [System.IO.File]::WriteAllText($Path, $body, $Utf8)
}

function Invoke-UP {
    <#
        Runs the real script end to end: PATH is prepended with the fixture's own bin dir (so 'claude'
        resolves to the shim, never a real install) for the duration of the call only, and restored in
        a finally exactly like Invoke-PV restores CLAUDE_PROJECT_DIR in plugin-versions.tests.ps1.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][string]$UserHome,
        [Parameter(Mandatory = $true)][string]$BinDir,
        [Parameter(Mandatory = $true)][string]$ReceiptPath,
        [switch]$DryRun
    )
    $prevPath = $env:PATH
    $prevProj = $env:CLAUDE_PROJECT_DIR
    $env:PATH = "$BinDir;$prevPath"
    $env:CLAUDE_PROJECT_DIR = $Repo
    try {
        $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Script,
               '-RootOverride', $Repo, '-UserHomeOverride', $UserHome,
               '-ReceiptScriptOverride', $ReceiptPath)
        if ($DryRun) { $a += '-DryRun' }
        $run = Invoke-NativeCapture -FilePath 'powershell' -Arguments $a -Utf8
        $joined = ($run.Output | ForEach-Object { "$_" }) -join "`n"
        return [pscustomobject]@{
            Code   = $run.ExitCode
            Text   = $joined
            Squish = ($joined -replace '\s', '')
        }
    } finally {
        $env:PATH = $prevPath
        if ($null -eq $prevProj) { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_PROJECT_DIR = $prevProj }
    }
}

$ID1 = 'dkj-subagents-alpha@ccs-fixture'
$ID2 = 'dkj-policy@ccs-fixture'

try {
    Write-Host "== update-plugins.tests: scripts/task/update-plugins.ps1 ==" -ForegroundColor Cyan
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture }
    New-Item -ItemType Directory -Path $Fixture -Force | Out-Null

    # --- 1. two plugins, one marketplace, no failures ------------------------------------------
    Write-Host "1. two plugins, one marketplace, no failures" -ForegroundColor Cyan
    $c = New-Case 'ok'
    New-ClaudeShim -BinDir $c.Bin
    New-Receipt -Path $c.Receipt
    Set-Enabled -RepoDir $c.Repo -Ids @($ID1, $ID2)
    $r = Invoke-UP -Repo $c.Repo -UserHome $c.Home -BinDir $c.Bin -ReceiptPath $c.Receipt
    Assert-CleanExit -Run $r -Label '1: exit 0'
    Assert-Has $r 'CLAUDE-SHIM-CALLED plugin marketplace update ccs-fixture' '1: the marketplace was refreshed'
    Assert-Has $r "CLAUDE-SHIM-CALLED plugin update $ID1 --scope project" '1: plugin 1 was updated, --scope project'
    Assert-Has $r "CLAUDE-SHIM-CALLED plugin update $ID2 --scope project" '1: plugin 2 was updated, --scope project'
    Assert-Has $r "FIXTURE-RECEIPT root=$($c.Repo) home=$($c.Home)" '1: the receipt ran with the SAME -RootOverride/-UserHomeOverride'
    Assert-Has $r '1 marketplace(s) refreshed' '1: summary counts one marketplace'
    Assert-Has $r '2 plugin(s) updated, 0 failed' '1: summary counts both plugins, zero failed'

    # --- 2. -DryRun: printed, never executed, no receipt ---------------------------------------
    Write-Host "2. -DryRun prints the commands and runs none of them" -ForegroundColor Cyan
    $c = New-Case 'dryrun'
    New-ClaudeShim -BinDir $c.Bin
    New-Receipt -Path $c.Receipt
    Set-Enabled -RepoDir $c.Repo -Ids @($ID1)
    $r = Invoke-UP -Repo $c.Repo -UserHome $c.Home -BinDir $c.Bin -ReceiptPath $c.Receipt -DryRun
    Assert-CleanExit -Run $r -Label '2: exit 0'
    Assert-Has   $r 'claude plugin marketplace update ccs-fixture' '2: the marketplace command is printed'
    Assert-Has   $r "claude plugin update $ID1 --scope project" '2: the plugin update command is printed'
    Assert-Lacks $r 'CLAUDE-SHIM-CALLED' '2: the shim never ran -- nothing was actually executed'
    Assert-Lacks $r 'FIXTURE-RECEIPT'    '2: no receipt either -- nothing changed for it to report on'

    # --- 3. no plugins enabled -------------------------------------------------------------------
    Write-Host "3. no plugins enabled" -ForegroundColor Cyan
    $c = New-Case 'none'
    New-ClaudeShim -BinDir $c.Bin
    New-Receipt -Path $c.Receipt
    Set-Enabled -RepoDir $c.Repo -Ids @()
    $r = Invoke-UP -Repo $c.Repo -UserHome $c.Home -BinDir $c.Bin -ReceiptPath $c.Receipt
    Assert-CleanExit -Run $r -Label '3: exit 0'
    Assert-Has   $r 'Nothing to update' '3: says so plainly'
    Assert-Lacks $r 'CLAUDE-SHIM-CALLED' '3: the shim never ran'
    Assert-Lacks $r 'FIXTURE-RECEIPT'    '3: no receipt either'

    # --- 4. one malformed id among two valid enables --------------------------------------------
    Write-Host "4. one malformed id is skipped, the valid ones still update" -ForegroundColor Cyan
    $c = New-Case 'badid'
    New-ClaudeShim -BinDir $c.Bin
    New-Receipt -Path $c.Receipt
    $bad = 'Not A Slug@ccs-fixture'
    Set-Enabled -RepoDir $c.Repo -Ids @($ID1, $bad)
    $r = Invoke-UP -Repo $c.Repo -UserHome $c.Home -BinDir $c.Bin -ReceiptPath $c.Receipt
    Assert-CleanExit -Run $r -Label '4: exit 0 -- the valid id still updated cleanly'
    Assert-Has $r 'Skipped' '4: a Skipped line is printed'
    Assert-Has $r "CLAUDE-SHIM-CALLED plugin update $ID1 --scope project" '4: the valid id was still updated'
    Assert-Lacks $r "plugin update $bad" '4: the malformed id was never handed to the CLI'

    # --- 5. every enabled id is malformed ----------------------------------------------------------
    Write-Host "5. every enabled id is malformed -> nothing left to update" -ForegroundColor Cyan
    $c = New-Case 'allbad'
    New-ClaudeShim -BinDir $c.Bin
    New-Receipt -Path $c.Receipt
    Set-Enabled -RepoDir $c.Repo -Ids @('Not A Slug@ccs-fixture')
    $r = Invoke-UP -Repo $c.Repo -UserHome $c.Home -BinDir $c.Bin -ReceiptPath $c.Receipt
    Assert-Equal 1 $r.Code '5: exit 1'
    Assert-Has   $r 'Nothing left to update' '5: says so plainly'
    Assert-Lacks $r 'CLAUDE-SHIM-CALLED' '5: the shim never ran -- there is no valid target, not even a marketplace refresh'
    Assert-Lacks $r 'FIXTURE-RECEIPT'    '5: no receipt either'

    # --- 6. the marketplace refresh fails, plugin updates run anyway ---------------------------
    Write-Host "6. the marketplace refresh fails -- plugin updates still run, receipt still runs" -ForegroundColor Cyan
    $c = New-Case 'mktfail'
    New-ClaudeShim -BinDir $c.Bin -FailNeedle 'marketplace update ccs-fixture'
    New-Receipt -Path $c.Receipt
    Set-Enabled -RepoDir $c.Repo -Ids @($ID1)
    $r = Invoke-UP -Repo $c.Repo -UserHome $c.Home -BinDir $c.Bin -ReceiptPath $c.Receipt
    Assert-Equal 1 $r.Code '6: exit 1'
    Assert-Has $r 'FAILED' '6: a FAILED line is printed for the marketplace refresh'
    Assert-Has $r "CLAUDE-SHIM-CALLED plugin update $ID1 --scope project" '6: the plugin update ran anyway -- one failure does not skip the rest'
    Assert-Has $r 'FIXTURE-RECEIPT' '6: the receipt still ran'
    Assert-Has $r '1 marketplace refresh(es) failed, 0 plugin update(s) failed' '6: the summary attributes the failure correctly'

    # --- 7. one of two plugin updates fails ------------------------------------------------------
    Write-Host "7. one plugin update fails -- the other still runs, receipt still runs" -ForegroundColor Cyan
    $c = New-Case 'updfail'
    New-ClaudeShim -BinDir $c.Bin -FailNeedle "plugin update $ID2"
    New-Receipt -Path $c.Receipt
    Set-Enabled -RepoDir $c.Repo -Ids @($ID1, $ID2)
    $r = Invoke-UP -Repo $c.Repo -UserHome $c.Home -BinDir $c.Bin -ReceiptPath $c.Receipt
    Assert-Equal 1 $r.Code '7: exit 1'
    Assert-Has $r "CLAUDE-SHIM-CALLED plugin update $ID1 --scope project" '7: the OTHER plugin still updated'
    Assert-Has $r 'FAILED' '7: a FAILED line names the failing update'
    Assert-Has $r 'FIXTURE-RECEIPT' '7: the receipt still ran'
    Assert-Has $r '0 marketplace refresh(es) failed, 1 plugin update(s) failed' '7: the summary attributes the failure correctly'

    # --- 8. two distinct marketplaces, refreshed in ordinal order -------------------------------
    Write-Host "8. two distinct marketplaces are both refreshed, in ordinal order" -ForegroundColor Cyan
    $c = New-Case 'twomkt'
    New-ClaudeShim -BinDir $c.Bin
    New-Receipt -Path $c.Receipt
    $idA = 'some-plugin@aaa-marketplace'
    $idB = 'some-plugin@zzz-marketplace'
    Set-Enabled -RepoDir $c.Repo -Ids @($idB, $idA)
    $r = Invoke-UP -Repo $c.Repo -UserHome $c.Home -BinDir $c.Bin -ReceiptPath $c.Receipt
    Assert-CleanExit -Run $r -Label '8: exit 0'
    Assert-Has    $r 'CLAUDE-SHIM-CALLED plugin marketplace update aaa-marketplace' '8: the first marketplace was refreshed'
    Assert-Has    $r 'CLAUDE-SHIM-CALLED plugin marketplace update zzz-marketplace' '8: the second marketplace was refreshed'
    Assert-Before $r 'update aaa-marketplace' 'update zzz-marketplace' '8: refreshed in ordinal order'

    # --- 9. the scope comes from the install record, per plugin (#1986) -------------------------
    #     THE SCENARIO THIS ISSUE WAS MEASURED IN, with both halves in ONE run so the per-plugin-ness
    #     is what is being asserted rather than a global switch: a machine-wide (pathless) record and a
    #     record for this checkout, side by side. Before #1986 both got '--scope project' and the
    #     machine-wide one was refused by the CLI -- never updated, and the run exited 1 with nothing
    #     actually wrong on the machine.
    Write-Host "9. the scope is read off the install record, per plugin" -ForegroundColor Cyan
    $c = New-Case 'scopes'
    New-ClaudeShim -BinDir $c.Bin
    New-Receipt -Path $c.Receipt
    Set-Enabled -RepoDir $c.Repo -Ids @($ID1, $ID2)
    Set-InstallRecords -HomeDir $c.Home -Records @{
        $ID1 = @( @{ scope = 'user' } )
        $ID2 = @( @{ scope = 'project'; projectPath = $c.Repo } )
    }
    $r = Invoke-UP -Repo $c.Repo -UserHome $c.Home -BinDir $c.Bin -ReceiptPath $c.Receipt
    Assert-CleanExit -Run $r -Label '9: exit 0'
    Assert-Has   $r "CLAUDE-SHIM-CALLED plugin update $ID1 --scope user" '9: the machine-wide plugin is updated at USER scope -- the command that can actually move it'
    Assert-Has   $r "CLAUDE-SHIM-CALLED plugin update $ID2 --scope project" '9: the plugin installed here keeps project scope'
    Assert-Lacks $r "plugin update $ID1 --scope project" '9: and the machine-wide plugin is NOT handed the scope it is not installed at'
    Assert-Lacks $r 'Scope could not be read' '9: both scopes were read, so no fallback block is printed'

    # --- 10. -DryRun prints the same per-plugin scopes ------------------------------------------
    #     The printed line is what a reader PASTES, so it has to carry the same scope the exec path
    #     would use -- a dry run that prints a command different from the one it would run is worse
    #     than no dry run. Nothing is appended to these lines either, which is why the assertion is on
    #     the exact command text.
    Write-Host "10. -DryRun prints the per-plugin scope, paste-ready" -ForegroundColor Cyan
    $c = New-Case 'scopes-dry'
    New-ClaudeShim -BinDir $c.Bin
    New-Receipt -Path $c.Receipt
    Set-Enabled -RepoDir $c.Repo -Ids @($ID1)
    Set-InstallRecords -HomeDir $c.Home -Records @{ $ID1 = @( @{ scope = 'local'; projectPath = $c.Repo } ) }
    $r = Invoke-UP -Repo $c.Repo -UserHome $c.Home -BinDir $c.Bin -ReceiptPath $c.Receipt -DryRun
    Assert-CleanExit -Run $r -Label '10: exit 0'
    Assert-Has   $r "claude plugin update $ID1 --scope local" '10: the printed command carries the record''s own scope'
    Assert-Lacks $r 'CLAUDE-SHIM-CALLED' '10: and still nothing ran'

    # --- 11. an administration that cannot answer: the fallback, and it SAYS so ------------------
    #     'project' is what this run has always used and still uses; what changed is that the reader is
    #     told it was a fallback rather than a reading. The block is printed ABOVE step 1, so it cannot
    #     scroll past inside step 2's own output -- which is where the #1986 failure was hiding.
    Write-Host "11. a record with no scope: project, with the reason stated" -ForegroundColor Cyan
    $c = New-Case 'scopes-silent'
    New-ClaudeShim -BinDir $c.Bin
    New-Receipt -Path $c.Receipt
    Set-Enabled -RepoDir $c.Repo -Ids @($ID1)
    Set-InstallRecords -HomeDir $c.Home -Records @{ $ID1 = @( @{ projectPath = $c.Repo } ) }
    $r = Invoke-UP -Repo $c.Repo -UserHome $c.Home -BinDir $c.Bin -ReceiptPath $c.Receipt
    Assert-CleanExit -Run $r -Label '11: exit 0'
    Assert-Has $r "CLAUDE-SHIM-CALLED plugin update $ID1 --scope project" '11: falls back to project, exactly as before'
    Assert-Has $r 'Scope could not be read from the install administration for 1 plugin(s)' '11: and the fallback is stated rather than silent'
    Assert-Has $r 'states no scope' '11: the line names what the administration failed to say'
    Assert-Before $r 'Scope could not be read' 'Step 1/3' '11: stated BEFORE step 1, so it cannot scroll past inside step 2'
}
finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

# --- the tolerance itself, DRIVEN (issue #2114) ---------------------------------------------------
# THE STATE IT EXISTS FOR CANNOT BE WAITED FOR -- it is a race at a few percent per capture, so a
# scenario that waited for it would be the flakiest thing in the tree. The three inputs are fabricated
# instead, and the counters are asserted rather than the console.
Write-Host ''
Write-Host 'Assert-CleanExit: the three inputs' -ForegroundColor Cyan

$unmeasuredBefore = $script:unmeasured
$passBefore = $script:pass
$failBefore = $script:fail

$label = 'no measurable exit code -- the child ran, and what came back was not a measurement of how it ended (issue #1931); this normally settles on a re-run'
Assert-CleanExit -Run ([pscustomobject]@{ Code = 1; Text = "  FAILED ($label)" }) -Label 'driven: tolerated'
$afterUnmeasured = $script:unmeasured
$afterPass = $script:pass
$afterFail = $script:fail

Assert-Equal ($unmeasuredBefore + 1) $afterUnmeasured 'driven: an exit 1 carrying the unmeasured marker is COUNTED as tolerated'
Assert-Equal $passBefore $afterPass 'driven: ...and is not recorded as a pass -- the scenario proved less than a green line would claim'
Assert-Equal $failBefore $afterFail 'driven: ...nor as a failure -- the script did what it is specified to do'

# A REAL FAILURE STILL FAILS. Without this the helper would be a blanket "0 or 1" and every scenario
# above would stop testing the thing it was written for.
$failBeforeReal = $script:fail
Assert-CleanExit -Run ([pscustomobject]@{ Code = 1; Text = '  FAILED (exit 3)' }) -Label 'driven: a real exit 1 -- THIS RED LINE IS THE ASSERT WORKING, and it is given back below'
Assert-Equal ($failBeforeReal + 1) $script:fail 'driven: an exit 1 WITHOUT the marker is still a failure, so this is no blanket tolerance'
# ...and that deliberate failure is given back, so this suite's own verdict stays honest.
$script:fail = $failBeforeReal
$script:unmeasured = $unmeasuredBefore

Assert-CleanExit -Run ([pscustomobject]@{ Code = 0; Text = 'all good' }) -Label 'driven: a clean exit 0 is asserted exactly as before'

Write-Host ''
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
# COUNTED AND PRINTED, NEVER FOLDED INTO EITHER FIGURE ABOVE. A tolerated exit is not a passed assert,
# and a run that quietly tolerated several is one where this suite proved less than its pass count
# suggests. It does not fail the run -- the script did what it is specified to do -- but a reader who
# sees this line knows which scenarios were waved through and why.
if ($script:unmeasured -gt 0) {
    Write-Host "         $script:unmeasured scenario(s) exited 1 on an UNMEASURED capture (#1931) and were tolerated rather than asserted -- see Assert-CleanExit." -ForegroundColor Yellow
}
if ($script:fail -gt 0) { exit 1 }
exit 0
