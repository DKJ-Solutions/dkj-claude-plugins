<#
.SYNOPSIS
    Shared assert helpers for the suites in a BWJ store repo's scripts/tests -- one source of truth for
    the two stores, instead of one drifted copy each.

.DESCRIPTION
    Dot-source this file at the top of a suite. A store repo reaches it through the plugin cache rather
    than through a copy of its own -- see ADOPTING IT below.

    Provides Assert-Equal / Assert-True / Assert-False / Assert-Match / Assert-NoMatch, plus
    Write-SuiteHeader, Write-Case and Complete-Suite. Dependency-free: no Pester, only PowerShell.

    Also provides Add-SuiteFault: the target of the one-line trap each suite installs right after the
    dot-source, so a terminating error inside a case is COUNTED as a failure instead of scrolling past
    while the suite still prints OK. See its own comment for why the trap cannot live here and has to be
    a line in every suite.

    Also provides ConvertTo-CapturedText, for the suites that run a child process and assert on what it
    wrote. It is here for the same reason the asserts are: what counts as 'the text a child produced'
    must not differ per suite -- and the two suites that had rolled their own disagreed, one of them
    wrongly. See its own comment for the measurement.

    And Assert-PluginLoadedForProject: the three legs that have to be true before the harness loads a
    plugin for a repo, as one assert set rather than as a paragraph each suite re-derives.

    WHY IT SHIPS HERE, AND WHAT IT CONVERGES (issue #1881, Dave's ruling of September 11, 2026:
    ANYTHING THE TWO STORES SHARE GOES TO bwj-development UNLESS IT IS OBVIOUSLY UNIVERSAL). Both stores
    carried their own copy of this file, and the sibling check
    (scripts/sync/check-consumer-siblings.ps1 in the marketplace) reported it DRIFTED -- each copy ahead
    of the other on something different, which is the shape that makes a merge a decision rather than a
    diff:

      - one repo had ConvertTo-CapturedText and Add-SuiteFault, both born from a false GREEN in the very
        gate these suites are read by;
      - the other had Assert-PluginLoadedForProject, born from a plugin administration that pointed at a
        folder which no longer existed;
      - and the second was still in the language the first had been translated out of a month earlier.

    What ships here is the superset, in English. Nothing was dropped: where the two disagreed only in
    wording, the clearer wording won, and every measurement either copy carried is still written down
    beside the code it explains.

    THIS IS MECHANISM IN A PLUGIN THAT USED TO SAY IT CARRIED NONE, and that is the ruling above rather
    than an oversight. The README's "policy, never mechanism" line was written when the only thing here
    besides prose was templates/, which the consumer COPIES; a lib the consumer DOT-SOURCES is a second
    kind of payload, and the ruling is what admits it. The alternative -- a universal home in dkj-policy
    -- was weighed and declined: this harness is used by two Shopify store repos and by nothing else
    Dave runs, and a mechanism that reaches every consumer of this marketplace for the benefit of two is
    the larger blast radius.

    ADOPTING IT, in a store repo. Replace the local scripts/tests/test-lib.ps1 with a forwarder that
    dot-sources this one out of the plugin cache -- the same shape prune-merged.ps1 already uses there,
    resolved through that repo's scripts/lib/plugin-scripts.ps1. Keep the file name: every suite already
    dot-sources 'test-lib.ps1' from its own folder, so a forwarder costs one file and no suite changes.
    A suite that needs Assert-PluginLoadedForProject must dot-source scripts/lib/plugin-scripts.ps1
    itself, for Get-PluginProjectRegistration -- see that function.

    THE FILE IS DELIBERATELY NOT NAMED *.tests.ps1. The test gate in the shared open-pr.ps1 runs
    everything matching that pattern, and a lib is not a suite: it would report zero asserts and pass
    vacuously, which is worse than not running.

    The counters live in the script scope of the CALLING suite (dot-sourcing runs the code in the
    caller's scope), so each suite counts its own asserts.

    Exit-code contract of a suite: 0 = all green, 1 = at least one failed assert. That is what the test
    gate reads.

    Pure ASCII (repo convention for .ps1): Windows PowerShell 5.1 reads a BOM-less script as ANSI, so a
    literal non-ASCII character in the source is decoded wrongly.
#>

$script:Pass = 0
$script:Fail = 0

function Write-SuiteHeader {
    param([Parameter(Mandatory = $true)][string]$Name)
    Write-Host ""
    Write-Host "== $Name ==" -ForegroundColor Cyan
}

function Write-Case {
    param([Parameter(Mandatory = $true)][string]$Name)
    Write-Host "-- $Name" -ForegroundColor DarkCyan
}

function Assert-Equal {
    param($Expected, $Actual, [Parameter(Mandatory = $true)][string]$Name)
    if ($Expected -eq $Actual) {
        $script:Pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:Fail++
        Write-Host "  [FAIL] $Name" -ForegroundColor Red
        Write-Host "         expected: '$Expected'" -ForegroundColor Red
        Write-Host "         got:      '$Actual'" -ForegroundColor Red
    }
}

function Assert-True {
    param([bool]$Condition, [Parameter(Mandatory = $true)][string]$Name)
    if ($Condition) {
        $script:Pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:Fail++; Write-Host "  [FAIL] $Name (expected true, got false)" -ForegroundColor Red
    }
}

function Assert-False {
    param([bool]$Condition, [Parameter(Mandatory = $true)][string]$Name)
    Assert-True -Condition (-not $Condition) -Name $Name
}

# Substring assert, NOT a regex: most checks here compare a lint message against a piece of expected
# text, and then regex-escaping paths and quotes is only a source of mistakes.
function Assert-Match {
    param(
        [AllowEmptyString()][string]$Text,
        [Parameter(Mandatory = $true)][string]$Needle,
        [Parameter(Mandatory = $true)][string]$Name
    )
    if ($Text -and $Text.Contains($Needle)) {
        $script:Pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:Fail++
        Write-Host "  [FAIL] $Name" -ForegroundColor Red
        Write-Host "         expected the text: '$Needle'" -ForegroundColor Red
        Write-Host "         in:" -ForegroundColor Red
        foreach ($l in ($Text -split "`n" | Select-Object -First 25)) { Write-Host "           $($l.TrimEnd())" -ForegroundColor DarkGray }
    }
}

function Assert-NoMatch {
    param(
        [AllowEmptyString()][string]$Text,
        [Parameter(Mandatory = $true)][string]$Needle,
        [Parameter(Mandatory = $true)][string]$Name
    )
    if (-not ($Text -and $Text.Contains($Needle))) {
        $script:Pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:Fail++
        Write-Host "  [FAIL] $Name" -ForegroundColor Red
        Write-Host "         the text '$Needle' should NOT have been there" -ForegroundColor Red
    }
}

# Turn what a child process wrote -- stdout strings and, under '2>&1', stderr ErrorRecords -- into
# plain text, WITHOUT letting the console decide where the lines break. Use it on the captured pipeline
# rather than piping to a formatter:
#
#     $captured = $payload | & powershell -NoProfile -ExecutionPolicy Bypass -File $script 2>&1
#     $text     = ConvertTo-CapturedText $captured     # read $LASTEXITCODE before anything else runs
#
# WHY THIS EXISTS RATHER THAN Out-String. Out-String formats for a host, so with no -Width it wraps at
# the console's width. Measured 2026-08-28: on a 79-column window the path
# 'scripts/task/sync-main.ps1' in the sync-skill guard's refusal was split across two lines, so the
# substring assert looking for it failed -- while the same tree was green on a wide window. The suites
# are a GATE, not a report: the shared open-pr.ps1 runs every scripts/tests/*.tests.ps1, so whether a
# PR could be opened at all depended on the width of the window the session happened to run in.
#
# 'Out-String -Width 4096' cures the wrap and leaves the rest of the problem standing. A rendered
# ErrorRecord also carries 'powershell.exe :', an 'At <script>:<line> char:<col>' block, and an echo of
# the CALLING line -- so the capture contains the test's own source text, and a needle that happened to
# occur there would pass for the wrong reason. That is a false green in a suite whose entire job is
# refusing one. Reading each object's own text takes the console, and the test's source, out of it.
function ConvertTo-CapturedText {
    param([AllowNull()][AllowEmptyCollection()][object[]]$Captured)
    if (-not $Captured) { return '' }
    $lines = foreach ($o in $Captured) {
        if ($o -is [System.Management.Automation.ErrorRecord]) {
            # NOT ToString(): a BLANK stderr line arrives as an ErrorRecord whose message is empty, and
            # ToString() on that falls through to the exception's TYPE NAME -- so every empty line in a
            # child's message came back as 'System.Management.Automation.RemoteException'. Measured on
            # the sync-skill guard, whose refusal has four of them.
            [string]$o.Exception.Message
        } else {
            [string]$o
        }
    }
    return ($lines -join "`n")
}

# A suite runs its cases as top-level script code, so a TERMINATING error inside a case body -- a
# parameter-binding failure (NamedParameterNotFound, the shape a stale call signature takes), a
# strict-mode violation, an explicit throw -- is only STATEMENT-terminating at top level:
# $ErrorActionPreference lets the script resume at the next statement, Complete-Suite still sees
# $script:Fail -eq 0, and the suite prints OK and exits 0 with the rest of that case silently skipped.
# That is how a defect sat undetected -- two asserts skipped on every run, suite still green, in the
# gate open-pr.ps1 / ship-pr.ps1 read.
#
# The defence is one line in every suite, right after the dot-source:
#
#     . (Join-Path $PSScriptRoot 'test-lib.ps1')
#     trap { Add-SuiteFault $_ ; continue }
#
# It cannot be installed from here: a trap in a dot-sourced file does NOT register in the caller's
# scope (measured on 5.1 -- the file's code runs in the caller, the trap does not). 'continue' resumes
# at the next TOP-LEVEL statement, after any pending finally has run, so the tail of the failing case
# is lost -- but the suite now goes RED instead of a false green, which is the whole point. A try/catch
# inside a case still wins over the trap, so the suites that provoke an error and assert on its message
# are unaffected. A store repo's scripts/tests/test-harness.tests.ps1 checks every sibling suite
# carries the line.
function Add-SuiteFault {
    param([Parameter(Mandatory = $true)][System.Management.Automation.ErrorRecord]$ErrorRecord)
    $script:Fail++
    $ii = $ErrorRecord.InvocationInfo
    Write-Host "  [FAIL] unhandled terminating error -- a case stopped part-way, suite marked failed" -ForegroundColor Red
    Write-Host "         $($ErrorRecord.FullyQualifiedErrorId): $($ErrorRecord.Exception.Message)" -ForegroundColor Red
    if ($ii -and $ii.ScriptName) {
        Write-Host "         at $(Split-Path -Leaf $ii.ScriptName):$($ii.ScriptLineNumber)" -ForegroundColor Red
    }
}

# --- Is a plugin LOADED for THIS project, rather than merely present on disk? ----------------------
#
# THE THREE LEGS, AS A DEFINITION. This was written for the live-theme guard's suite and then wanted,
# word for word, by a second suite asking the same question about the WORKFLOW plugin -- the one
# Resolve-PluginScript points at by default, and therefore where open-pr, ship-pr, the fold and the
# release cut come from. A second copy of this reasoning in a second suite is the duplication that
# drifts the moment one of the two is updated, so it lives here once and is called twice.
#
# WHAT IS MEASURED IS A PROXY, and that belongs in the open: a script cannot ask the harness what it
# loaded. What CAN be measured is the three things that must all be true before the harness loads this
# plugin for this repo -- and they fail INDEPENDENTLY of one another, so they are three asserts and not
# one.
#
# THE CALLER MUST HAVE DOT-SOURCED scripts/lib/plugin-scripts.ps1: Get-PluginProjectRegistration comes
# from there. Dot-sourcing runs the code in the caller's scope, so that function is then in the same
# scope as this one.
function Assert-PluginLoadedForProject {
    param(
        # The plugin id. Pass it from the SEAM ($script:PluginDefaultName) wherever you can, never as a
        # literal string: these ids have been renamed three times.
        [Parameter(Mandatory = $true)][string]$PluginId,
        # The marketplace, from the seam for the same reason ($script:PluginDefaultMarketplace). That
        # name has been renamed twice, and the second time became an issue of its own.
        [Parameter(Mandatory = $true)][string]$Marketplace,
        # The full text of .claude/settings.json (tracked in the repo).
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$SettingsText,
        # The repo root the registration is compared against.
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        # Optional: the path the suite actually measured. Given one, leg 3 holds THAT path to being this
        # project's installation.
        [AllowEmptyString()][string]$ResolvedRoot = ''
    )

    # LEG 1 -- the INTENT, and it lives in the repo. settings.json is tracked, so this half travels with
    # a clone and is the same on every machine. With the plugin switched off here, no machine loads it,
    # however tidy the registration is.
    #
    # AND THIS IS THE LEG THAT CATCHES A RENAMED MARKETPLACE DIRECTLY. The id and the marketplace name
    # come from the seam; the expectation comes from the tracked settings.json. A seam that disagrees
    # with what this repo switches on -- exactly the state where the lookup still named a retired
    # marketplace while settings.json named the current one -- is red here, on every machine, with
    # nothing needing to be installed.
    Assert-True ($SettingsText -match [regex]::Escape("`"$PluginId@$Marketplace`": true")) `
        "settings.json enables $PluginId@$Marketplace (the intent, tracked in the repo)"

    # LEG 2 -- the INSTALLATION, and it is PER MACHINE. This is the half that was false when this check
    # was written: the administration named, for all five plugins, a local folder that no longer
    # existed. No tracked file can stand in for it.
    $reg = Get-PluginProjectRegistration -Plugin $PluginId -Marketplace $Marketplace -RepoRoot $RepoRoot

    # THE MESSAGE ALSO NAMES THE WAY BACK, and that is not comfort but the closing of a measured detour:
    # the first attempt fails SILENTLY on a default. `claude plugin install` installs at scope 'user',
    # and a user entry writes NO projectPath -- so the command reports success while this assert stays
    # red. Only --scope project writes the entry this line reads.
    #
    # THE PLUGIN LIST COMES FROM settings.json and is deliberately not a literal here: that roster has
    # changed three times, and a transcript of it would, after the fourth, propose a repair command that
    # skips some of the plugins -- a recovery route that runs and does not recover.
    $enabledPlugins = @()
    try {
        $enabledPlugins = @((ConvertFrom-Json $SettingsText).enabledPlugins.PSObject.Properties.Name |
            ForEach-Object { ($_ -split '@')[0] })
    } catch { }
    if (-not $enabledPlugins.Count) { $enabledPlugins = @($PluginId) }
    $pluginListLiteral = ($enabledPlugins | ForEach-Object { "'$_'" }) -join ','

    $regDetail = if ($reg.Registered) { '' } else {
        " (reason: $($reg.Reason); registered are: " +
        $(if ($reg.KnownPaths.Count) { $reg.KnownPaths -join ', ' } else { '<nothing>' }) +
        "; this repo is: $RepoRoot)" +
        "`n         REPAIR -- run this FROM THE REPO ROOT, and mind --scope project: the default is" +
        "`n         'user', which writes no projectPath, so the install reports success and this" +
        "`n         assert stays red." +
        "`n           foreach (`$p in $pluginListLiteral) {" +
        "`n               claude plugin install `"`$p@$Marketplace`" --scope project -y" +
        "`n           }" +
        "`n         Restart Claude Code afterwards (a freshly registered plugin loads in a new session," +
        "`n         not this one), and then restore the tracked .claude/settings.json with" +
        "`n         'git checkout -- .claude/settings.json': the install rewrites that file. Formatting" +
        "`n         only, but it destroys the deliberate grouping of the deny list."
    }
    Assert-True $reg.Registered `
        "installed_plugins.json links $PluginId to THIS repo root$regDetail"

    # LEG 3 -- the IDENTITY. The two above can both be right while the suite measured a DIFFERENT tree:
    # Get-PluginRoot may have landed on the marketplace clone, or on another project's cache. Without
    # this assert the suite is then measuring a plugin this session does not have -- green, and about
    # the wrong file. That is precisely the complaint that produced this leg: the suite tests against
    # the tree the LOOKUP picks instead of the tree the SESSION loaded.
    if ($reg.Registered -and $ResolvedRoot) {
        $normalize = { param([string]$P) if ($P) { ($P -replace '/', '\').TrimEnd('\') } else { '' } }
        Assert-Equal (& $normalize $reg.InstallPath) (& $normalize $ResolvedRoot) `
            "the $PluginId this suite measured IS the installation attached to this project"
    }

    return $reg
}

function Complete-Suite {
    Write-Host ""
    if ($script:Fail -gt 0) {
        Write-Host "FAILS: $($script:Fail) failed, $($script:Pass) passed." -ForegroundColor Red
        exit 1
    }
    Write-Host "OK: all $($script:Pass) asserts passed." -ForegroundColor Green
    exit 0
}
