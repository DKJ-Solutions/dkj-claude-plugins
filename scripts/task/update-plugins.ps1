<#
.SYNOPSIS
    The buildable half of #1890: 1 + N commands per checkout, run as one. Refreshes the marketplace
    clone once, then runs `claude plugin update <id> --scope project` for every plugin THIS checkout
    enables, then prints plugin-versions.ps1's receipt so the run's own result is verifiable.

.DESCRIPTION
    #1810 asked how updating stays workable across repos and machines; #1812 settled the mechanics
    (a session loads the extracted payload, the unit that moves it is a release, pulled per checkout
    per machine) and #1769 landed the flag day it was urgent for. What #1890 split out is the one
    piece still worth building: measured against `claude plugin update --help` / `install --help`,
    there is no `--all` and no repeatable `<plugin>` argument, so the act stays 1 + N commands unless
    something wraps it. This is that wrapper.

    THE BOUNDARY, NAMED IN #1890 ITSELF AND KEPT HERE ON PURPOSE: this checkout plus the machine-wide
    marketplace clone, never a walk into another checkout. Every `claude plugin update` call below is
    `--scope project` against $repoRoot alone, and `claude plugin install/update` rewrites the
    visited repo's .claude/settings.json -- so a sweeping updater would leave uncommitted diffs in
    repos nobody opened, possibly on a mid-work branch (#1810's second cost). Nothing here reads or
    writes any tree but this one.

    THREE STEPS, IN ONE RUN:
      1. `claude plugin marketplace update <marketplace>` once per DISTINCT marketplace this checkout's
         enabled plugins name (there is ordinarily one, but the loop does not assume it).
      2. `claude plugin update <id> --scope project` for every plugin id `Get-EnabledPlugins` reports
         for $repoRoot -- the full effective set after the settings-chain precedence, the same set
         plugin-versions.ps1 reports on, so step 3's receipt is never comparing against a different
         list than step 2 acted on.
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
        $targets.Add([pscustomobject]@{ Id = $id; Name = $name; Marketplace = $mp })
    } else {
        $skipped.Add((Format-SuspectToken -Value $id))
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

$marketplaces = [string[]]@($targets | ForEach-Object { $_.Marketplace } | Select-Object -Unique)
[array]::Sort($marketplaces, [System.StringComparer]::Ordinal)

if ($DryRun) {
    Write-Host ""
    Write-Host "-DryRun -- printing the commands this run would execute, none of them run:" -ForegroundColor Cyan
    foreach ($mp in $marketplaces) { Write-Host "  claude plugin marketplace update $mp" }
    foreach ($t in $targets) { Write-Host "  claude plugin update $($t.Id) --scope project" }
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
        Write-Host "    FAILED (exit $($r.ExitCode))$(if ($r.TimedOut) { ' -- timed out' })" -ForegroundColor Red
    }
}

# --- step 2: update every plugin this checkout enables, --scope project --------------------------

Write-Host ""
Write-Host "Step 2/3 -- updating $($targets.Count) plugin(s), --scope project:" -ForegroundColor Cyan
$updateFailures = 0
foreach ($t in $targets) {
    Write-Host ""
    Write-Host "  claude plugin update $($t.Id) --scope project"
    $r = Invoke-NativeCapture -FilePath 'claude' -Arguments @('plugin', 'update', $t.Id, '--scope', 'project') -Utf8 -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
    foreach ($line in @($r.Output)) { Write-Host "    $line" }
    if ($r.ExitCode -ne 0) {
        $updateFailures++
        Write-Host "    FAILED (exit $($r.ExitCode))$(if ($r.TimedOut) { ' -- timed out' })" -ForegroundColor Red
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
    Write-Host "update-plugins: $($marketplaces.Count) marketplace(s) refreshed, $($targets.Count) plugin(s) updated, 0 failed." -ForegroundColor Green
    exit 0
}
Write-Host "update-plugins: $marketplaceFailures marketplace refresh(es) failed, $updateFailures plugin update(s) failed -- see FAILED lines above." -ForegroundColor Red
exit 1
