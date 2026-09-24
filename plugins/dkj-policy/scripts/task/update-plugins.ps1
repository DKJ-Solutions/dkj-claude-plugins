<#
.SYNOPSIS
    The buildable half of #1890: 1 + N commands per checkout, run as one. Refreshes the marketplace
    clone once, then runs `claude plugin update <id> --scope <the scope it is installed at>` for every
    plugin THIS checkout enables, then prints plugin-versions.ps1's receipt so the run's own result is
    verifiable.

.DESCRIPTION
    #1810 asked how updating stays workable across repos and machines; #1812 settled the mechanics
    (a session loads the extracted payload, the unit that moves it is a release, pulled per checkout
    per machine) and #1769 landed the flag day it was urgent for. What #1890 split out is the one
    piece still worth building: measured against `claude plugin update --help` / `install --help`,
    there is no `--all` and no repeatable `<plugin>` argument, so the act stays 1 + N commands unless
    something wraps it. This is that wrapper.

    THE BOUNDARY, NAMED IN #1890 ITSELF AND KEPT HERE ON PURPOSE: this checkout plus the machine-wide
    marketplace clone, never a walk into another checkout. Every `claude plugin update` call below
    names $repoRoot alone, and `claude plugin install/update` rewrites the visited repo's
    .claude/settings.json -- so a sweeping updater would leave uncommitted diffs in repos nobody
    opened, possibly on a mid-work branch (#1810's second cost). Nothing here reads or writes any tree
    but this one.

    THE SCOPE IS READ OFF THE INSTALL RECORD, AND THAT DOES NOT WIDEN THAT BOUNDARY (issue #1986).
    Until then every call was hardcoded `--scope project`, and the CLI refuses a scope a plugin is not
    installed at -- so a machine-wide plugin was handed the one command that could have moved it and
    the run exited 1 on a healthy machine. Get-PluginUpdateScope answers it from the administration
    this run already reads; read its own block in check-report-lib.ps1 for why a 'local' or pathless
    'user' record is an ordinary state rather than an edge case. The boundary is about WHICH TREE gets
    written, and nothing here changes that: a user-scope update rewrites no repo's tree at all, and a
    'local'/'project' one rewrites exactly the checkout the caller is standing in.

    THREE STEPS, IN ONE RUN:
      1. `claude plugin marketplace update <marketplace>` once per DISTINCT marketplace this checkout's
         enabled plugins name (there is ordinarily one, but the loop does not assume it).
      2. `claude plugin update <id> --scope <scope>` for every plugin id `Get-EnabledPlugins` reports
         for $repoRoot -- the full effective set after the settings-chain precedence, the same set
         plugin-versions.ps1 reports on, so step 3's receipt is never comparing against a different
         list than step 2 acted on. The scope per id comes from Get-PluginUpdateScope (see the block
         above), so step 2 and the receipt's own prescriptions cannot disagree inside one run. Where a
         plugin ALSO has a path-less user-scope record beside this checkout's own, that record is
         updated too (#2459): it is a second install a session can load (#2442), and leaving it
         behind made the receipt call the run's own result behind.
      3. plugin-versions.ps1, run as a CHILD PROCESS (Start-Process, live console, exactly the pattern
         Invoke-TestSuiteGate and the lint gate already use) -- never dot-sourced, because that script
         ends in `exit 0` on every path and dot-sourcing it would exit THIS script too.

    WHY EXECUTE RATHER THAN ONLY PRINT (unlike plugin-versions.ps1's own paste-ready commands). Every
    `claude ...` call here reaches the CLI through Invoke-NativeCapture's argument ARRAY, never through
    a string a shell re-parses -- so the paste-into-a-terminal injection surface Format-SafeProseToken /
    the withhold doctrine exist for does not apply to the exec path itself. What an untrusted
    'enabledPlugins' KEY can still do is confuse the CLI's OWN argument parser (an id starting with '-'
    reads as a flag to `claude`, not to a shell) -- so a target is only ever built from an id that
    passes Test-PluginNameSlug / Test-PluginMarketplaceSlug; anything else is reported and skipped
    rather than handed to the CLI to misinterpret.

    CONTINUES PAST A FAILURE. One marketplace or one plugin failing to update is not a reason to skip
    the rest -- each call's own exit code is recorded and the run's own exit code is non-zero only if
    something failed, so a caller (or a person reading $LASTEXITCODE) can tell without parsing prose.

    Dual-context: run the root copy in this repo, the plugin mirror in a consumer. Pure ASCII, per
    this repo's script-layer convention.

.PARAMETER DryRun
    Print every command this run would execute -- the marketplace refresh(es) and the per-plugin
    update(s) -- and run none of them. No receipt either: nothing changed for plugin-versions.ps1 to
    report on. The paste-ready line for a target that fails its slug check is withheld exactly as
    plugin-versions.ps1 withholds one, and for the identical reason.

.PARAMETER RootOverride
    Repo root to resolve the enable state against, for the test suite. A consumer never types this.

.PARAMETER UserHomeOverride
    The home directory '~/.claude' hangs off, for the test suite. A consumer never types this.

.PARAMETER ReceiptScriptOverride
    The plugin-versions.ps1 path step 3 runs as a child process, for the test suite to point at a
    fixture double instead of the real script. A consumer never types this; the real run always
    resolves it as a sibling of this file.

.EXAMPLE
    ./scripts/task/update-plugins.ps1
.EXAMPLE
    ./scripts/task/update-plugins.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [string]$RootOverride = '',
    [string]$UserHomeOverride = '',
    [string]$ReceiptScriptOverride = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The source-repo guard, wired the way every shared entry point wires it -- see plugin-versions.ps1
# for the reasoning; it refuses a released copy run from inside the repo that maintains it.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# Repo root -- dual context, exactly as plugin-versions.ps1 resolves it.
# JUDGED (#1917): Resolve-RepoRootOrFail is check-report-lib's refusing sibling of Resolve-CheckRoot
# -- same precedence, but it names git's exit code and stderr instead of dying on $null.Trim().
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$repoRoot = Resolve-RepoRootOrFail -Override $RootOverride -ScriptName 'update-plugins.ps1' -OverrideName '-RootOverride'

. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')

Write-Host ""
Write-Host "update-plugins -- $repoRoot" -ForegroundColor Cyan

$enabled = Get-EnabledPlugins -RepoRoot $repoRoot -UserHomeOverride $UserHomeOverride
$ids = @($enabled.Ids)

if ($ids.Count -eq 0) {
    Write-Host ""
    Write-Host "No plugins are enabled for this checkout." -ForegroundColor Yellow
    Write-Host "  Consulted: $($enabled.Summary)."
    Write-Host "  Nothing to update."
    exit 0
}

# The install administration, for the SCOPE half of every step-2 command (#1986). Read once rather
# than per target: it is one file, and plugin-versions.ps1 -- this run's own step-3 receipt -- reads
# it exactly this way, with the same fixture knob, so the two halves of one run cannot end up
# consulting different administrations.
$install = Get-InstallRecord -RepoRoot $repoRoot -UserHomeOverride $UserHomeOverride

# One command safety check per id, same predicate plugin-versions.ps1 already applies to its OWN
# printed commands (Test-PluginNameSlug / Test-PluginMarketplaceSlug) -- see this file's own
# docstring for why the reason differs (the CLI's argument parser, not a shell) while the guard is
# the one already in the tree.
$targets = New-Object System.Collections.Generic.List[object]
$skipped = New-Object System.Collections.Generic.List[string]
foreach ($id in $ids) {
    $parts = $id -split '@'
    $name = $parts[0]
    $mp = $parts[-1]
    if ((Test-PluginNameSlug -Name $name) -and (Test-PluginMarketplaceSlug -Marketplace $mp)) {
        $sc = Get-PluginUpdateScope -InstallRecord $install -PluginId $id
        $targets.Add([pscustomobject]@{
            Id          = $id
            Name        = $name
            Marketplace = $mp
            Scope       = $sc.Scope
            ScopeSource = $sc.Source
            ScopeNote   = $sc.Note
        })
    } else {
        $skipped.Add((Format-SuspectToken -Value $id))
    }
}

# THE PATH-LESS USER-SCOPE SHADOW IS A SECOND INSTALL, SO IT IS A SECOND TARGET (issue #2459).
# Get-PluginUpdateScope answers ONE scope per plugin, the checkout's own record first -- so where a
# plugin has both a record for this checkout and a path-less user-scope record, the path-less one was
# never updated. Measured September 24, 2026, v5.7.0 -> v5.8.0: every project record moved, and this
# run's own step-3 receipt then reported 5 of 7 behind on exactly those path-less records (#2442's
# "a session can load the older one"), under a summary saying "0 failed".
#
# NOT GATED ON THE VERSION, and that is the point rather than a shortcut: in the measured run both
# records were at 5.7.0 BEFORE step 2, so a comparison taken here reads "nothing to do" and the shadow
# appears only after the checkout's record has moved. `claude plugin update` is idempotent, so a
# shadow already current costs one no-op call.
#
# ONLY 'user', never another path-less scope: 'managed' belongs to an administrator and is not this
# run's to move, and #1890's boundary is untouched because a user-scope update writes no repo tree.
$shadows = New-Object System.Collections.Generic.List[object]
foreach ($t in $targets) {
    if ($t.ScopeSource -ne 'record' -or $t.Scope -eq 'user') { continue }
    if ($null -eq $install -or -not $install.Readable -or $null -eq $install.PathlessById) { continue }
    if (-not $install.PathlessById.ContainsKey($t.Id)) { continue }
    $hasUser = @(@($install.PathlessById[$t.Id]) | Where-Object { [string]$_.Scope -ieq 'user' }).Count -gt 0
    if ($hasUser) {
        $shadows.Add([pscustomobject]@{ Id = $t.Id; Scope = 'user' })
    }
}

if ($skipped.Count -gt 0) {
    Write-Host ""
    Write-Host "Skipped (not a valid plugin id, so not handed to the CLI): $($skipped -join ', ')" -ForegroundColor Yellow
}

if ($targets.Count -eq 0) {
    Write-Host ""
    Write-Host "Nothing left to update after the id check above." -ForegroundColor Yellow
    exit 1
}

# WHY THE NOTES ARE PRINTED BEFORE ANYTHING RUNS, not beside the call they belong to. A note only ever
# exists where the administration could NOT answer and the run fell back to 'project' -- which is
# exactly the state #1986 was filed about, so it must not scroll past inside step 2's own output. The
# scope actually used is printed per call below regardless, so this block is the reason and that line
# is the act.
$scopeNotes = @($targets | Where-Object { $_.ScopeNote })
if ($scopeNotes.Count -gt 0) {
    Write-Host ""
    Write-Host "Scope could not be read from the install administration for $($scopeNotes.Count) plugin(s):" -ForegroundColor Yellow
    foreach ($t in $scopeNotes) { Write-Host "  $($t.Id) -- $($t.ScopeNote)" -ForegroundColor Yellow }
}

$marketplaces = [string[]]@($targets | ForEach-Object { $_.Marketplace } | Select-Object -Unique)
[array]::Sort($marketplaces, [System.StringComparer]::Ordinal)

if ($DryRun) {
    Write-Host ""
    Write-Host "-DryRun -- printing the commands this run would execute, none of them run:" -ForegroundColor Cyan
    foreach ($mp in $marketplaces) { Write-Host "  claude plugin marketplace update $mp" }
    # NOTHING IS APPENDED TO THESE LINES, not even the scope's provenance. -DryRun exists to be pasted
    # into a terminal, so a trailing '(from the install record)' would turn every line into one that
    # has to be edited first. The provenance that matters -- the administration failing to answer --
    # is the $scopeNotes block above, which is prose and does not pretend to be a command.
    foreach ($t in $targets) { Write-Host "  claude plugin update $($t.Id) --scope $($t.Scope)" }
    foreach ($t in $shadows) { Write-Host "  claude plugin update $($t.Id) --scope $($t.Scope)" }
    exit 0
}

# --- step 1: refresh each distinct marketplace clone, once ---------------------------------------

Write-Host ""
Write-Host "Step 1/3 -- refreshing the marketplace clone(s):" -ForegroundColor Cyan
$marketplaceFailures = 0
foreach ($mp in $marketplaces) {
    Write-Host ""
    Write-Host "  claude plugin marketplace update $mp"
    $r = Invoke-NativeCapture -FilePath 'claude' -Arguments @('plugin', 'marketplace', 'update', $mp) -Utf8 -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
    foreach ($line in @($r.Output)) { Write-Host "    $line" }
    if ($r.ExitCode -ne 0) {
        $marketplaceFailures++
        # THE REASON IS COMPOSED RATHER THAN INTERPOLATED (issue #1931, audited under #2081), at this
        # line and at its twin in step 2. An unmeasurable exit code satisfies `-ne 0` and prints as
        # nothing, so a lost code read "FAILED (exit )" -- and this script is the one a reader runs
        # BECAUSE something already looked wrong, so a failure with no reason in it is the worst shape
        # here.
        #
        # IT IS STILL COUNTED AS A FAILURE, AND THAT IS THE ONE PLACE IN THIS AUDIT WHERE AN UNKNOWN IS
        # DELIBERATELY REPORTED AS A FAILURE. The reason is the direction of the question: this script
        # answers "did every update succeed", and for an updater the conservative answer to "I could not
        # tell" is no. The seven WRITES elsewhere in this audit are the opposite case -- there the
        # conservative answer is to stop claiming a failure, because a reader acting on one re-does a
        # write that may have landed. Here re-running is the remedy anyway, and it is idempotent.
        #
        # SAID PRECISELY BECAUSE THE FIRST WORDING OVERCLAIMED (caught in review): step 3's receipt
        # prints the versions actually installed, so it corrects what the CONSOLE says -- it does not
        # touch this script's own exit code, and a caller reading that still gets the conservative
        # verdict above.
        Write-Host "    FAILED ($(Get-NativeExitLabel -Capture $r))$(if ($r.TimedOut) { ' -- timed out' })" -ForegroundColor Red
    }
}

# --- step 2: update every plugin this checkout enables, each at its own scope ---------------------

Write-Host ""
Write-Host "Step 2/3 -- updating $($targets.Count) plugin(s), each at the scope it is installed at:" -ForegroundColor Cyan
$updateFailures = 0
# ONE LOOP FOR BOTH: the path-less user-scope records beside a checkout record (#2459, see the block
# above $targets' skip report) go through the same call site as the targets, after them. They are the
# same question -- counted as update failures like any other call -- and one site is one audited
# bounded capture rather than two copies of it.
$firstShadow = if ($shadows.Count -gt 0) { $shadows[0] } else { $null }
# .ToArray() on both, not @(): Windows PowerShell 5.1 hands a generic List back from @() unchanged, and
# List + List throws "argument types do not match" rather than concatenating.
foreach ($t in ([object[]]$targets.ToArray() + [object[]]$shadows.ToArray())) {
    if ($null -ne $firstShadow -and [object]::ReferenceEquals($t, $firstShadow)) {
        Write-Host ""
        Write-Host "  ...and $($shadows.Count) path-less user-scope record(s) beside this checkout's own, which a session can load instead (#2442):" -ForegroundColor Cyan
    }
    Write-Host ""
    Write-Host "  claude plugin update $($t.Id) --scope $($t.Scope)"
    $r = Invoke-NativeCapture -FilePath 'claude' -Arguments @('plugin', 'update', $t.Id, '--scope', $t.Scope) -Utf8 -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
    foreach ($line in @($r.Output)) { Write-Host "    $line" }
    if ($r.ExitCode -ne 0) {
        $updateFailures++
        Write-Host "    FAILED ($(Get-NativeExitLabel -Capture $r))$(if ($r.TimedOut) { ' -- timed out' })" -ForegroundColor Red
    }
}

# --- step 3: the receipt -- plugin-versions.ps1, as a CHILD PROCESS ------------------------------
# Never dot-sourced: it ends in `exit 0` on every path, and dot-sourcing it would exit this script
# too. Start-Process -NoNewWindow -Wait is the pattern gate-lib.ps1 already uses for exactly this
# reason (live, coloured child output on the caller's own console rather than a buffered pipe).

Write-Host ""
Write-Host "Step 3/3 -- receipt:" -ForegroundColor Cyan
$receiptPath = if ($ReceiptScriptOverride) { $ReceiptScriptOverride } else { Join-Path $PSScriptRoot 'plugin-versions.ps1' }
$receiptArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $receiptPath + '"'))
if ($RootOverride) { $receiptArgs += @('-RootOverride', ('"' + $RootOverride + '"')) }
if ($UserHomeOverride) { $receiptArgs += @('-UserHomeOverride', ('"' + $UserHomeOverride + '"')) }
Start-Process -FilePath 'powershell' -ArgumentList $receiptArgs -NoNewWindow -Wait -WorkingDirectory (Get-Location).Path | Out-Null

Write-Host ""
$totalFailures = $marketplaceFailures + $updateFailures
if ($totalFailures -eq 0) {
    $shadowText = if ($shadows.Count -gt 0) { " (plus $($shadows.Count) path-less user-scope record(s))" } else { '' }
    Write-Host "update-plugins: $($marketplaces.Count) marketplace(s) refreshed, $($targets.Count) plugin(s) updated$shadowText, 0 failed." -ForegroundColor Green
    exit 0
}
Write-Host "update-plugins: $marketplaceFailures marketplace refresh(es) failed, $updateFailures plugin update(s) failed -- see FAILED lines above." -ForegroundColor Red
exit 1
