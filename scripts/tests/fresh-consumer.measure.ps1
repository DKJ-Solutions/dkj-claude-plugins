<#
.SYNOPSIS
    Measures what a consumer LITERALLY sees at session start, before and after the bootstrap.

.DESCRIPTION
    Builds a synthetic consumer in the state a real one is in right after enabling the plugin and
    restarting -- its own CLAUDE.md, no lenses, no repo-config, no orchestrator import -- then runs
    the three SessionStart hooks against it exactly as the harness does: cwd on the consumer,
    CLAUDE_PLUGIN_ROOT on the plugin. With -WithBootstrap it runs specialists-init's bootstrap.ps1
    first, which is the "happy path" comparison.

    Deliberately a MEASUREMENT, not a test suite -- hence the .measure.ps1 suffix rather than
    .tests.ps1, so CI's `scripts/tests/*.tests.ps1` glob does not pick it up. It reports counts and
    verbatim output for a human to read; it asserts nothing and passes/fails nothing. Turning the
    install/uninstall round-trip into a real asserting suite is tracked separately -- see the
    lifecycle issues referenced from Tycho #18's lens.

    Why it exists as a committed script instead of an ad-hoc run: the whole point is that round two
    is comparable to round one. A measurement performed by hand cannot be repeated identically, so
    the numbers could not be trusted as a before/after.

    Read-only with respect to this repo: it writes only inside -FixtureRoot, which it recreates from
    scratch on every run.

.PARAMETER FixtureRoot
    Where to build the synthetic consumer. Recreated (deleted first) on every run, so point it at a
    scratch location and never at a real repo.

.PARAMETER PluginRoot
    The plugin to measure against. Defaults to this repo's own plugin source. Point it at an
    installed plugin cache (~/.claude/plugins/cache/...) to measure what a released version does,
    which is what a real consumer actually runs.

.PARAMETER WithBootstrap
    Run specialists-init's bootstrap.ps1 before measuring -- the post-install state.

.EXAMPLE
    # Before: what a fresh consumer sees
    ./scripts/tests/fresh-consumer.measure.ps1 -FixtureRoot $env:TEMP\fresh-consumer

.EXAMPLE
    # After: the same fixture once the documented bootstrap has run
    ./scripts/tests/fresh-consumer.measure.ps1 -FixtureRoot $env:TEMP\fresh-consumer -WithBootstrap
#>
param(
    [Parameter(Mandatory = $true)][string]$FixtureRoot,
    [string]$PluginRoot = '',
    [switch]$WithBootstrap
)
$ErrorActionPreference = 'Stop'

# JUDGING THIS SCRIPT'S OWN FIXTURE git CALL -- issue #1635. The stake is the same one the lib describes
# for a suite, and arguably plainer here: this script MEASURES a fresh consumer, so a fixture repo that
# was never built yields a measurement of something other than what the run claims to have measured.
. (Join-Path $PSScriptRoot '..\lib\fixture-git-lib.ps1')

# Repo root -- same dual-context resolution the shared scripts use.
# JUDGED (#1917): Resolve-RepoRootOrFail is check-report-lib's refusing sibling of Resolve-CheckRoot
# -- same precedence, but it names git's exit code and stderr instead of dying on $null.Trim().
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$repoRoot = Resolve-RepoRootOrFail -ScriptName 'fresh-consumer.measure.ps1'
if (-not $PluginRoot) {
    $PluginRoot = Join-Path $repoRoot 'plugins\dkj-subagents\dkj-subagents-alpha'
}
$hooks = Join-Path $PluginRoot 'hooks'

if (-not (Test-Path -LiteralPath $hooks)) {
    throw "No hooks directory under '$PluginRoot' -- is that a plugin root?"
}

# --- build the fixture consumer -------------------------------------------------------------
# Deliberately NOT an empty repo: a real consumer already has its own CLAUDE.md with its own
# content and no idea specialists exist. An empty repo would be the easy case and would hide how
# the hooks read against pre-existing content.
if (Test-Path -LiteralPath $FixtureRoot) { Remove-Item -LiteralPath $FixtureRoot -Recurse -Force }
New-Item -ItemType Directory -Path (Join-Path $FixtureRoot '.claude') -Force | Out-Null

@'
{
  "extraKnownMarketplaces": {
    "dkj-claude-plugins": {
      "source": { "source": "github", "repo": "DKJ-Solutions/claude-code-specialists" }
    }
  },
  "enabledPlugins": { "dkj-subagents-alpha@dkj-claude-plugins": true }
}
'@ | Set-Content -LiteralPath (Join-Path $FixtureRoot '.claude\settings.json') -Encoding utf8

@'
# CLAUDE.md - my-own-project

## About

A perfectly ordinary project. Build with `npm run build`, test with `npm test`.

## Conventions

- Feature work goes on a branch.
- Keep the README current.
'@ | Set-Content -LiteralPath (Join-Path $FixtureRoot 'CLAUDE.md') -Encoding utf8

Push-Location $FixtureRoot
try { Invoke-FixtureGitJudged @('init', '-q') } finally { Pop-Location }

$state = if ($WithBootstrap) { 'AFTER bootstrap (the happy path)' } else { 'BEFORE bootstrap (plugin enabled, restarted, nothing else)' }
Write-Host "== fresh-consumer measurement -- $state ==" -ForegroundColor Cyan
Write-Host "  fixture: $FixtureRoot"
Write-Host "  plugin:  $PluginRoot"

$prevPlugin  = $env:CLAUDE_PLUGIN_ROOT
$prevProject = $env:CLAUDE_PROJECT_DIR
$env:CLAUDE_PLUGIN_ROOT = $PluginRoot
$env:CLAUDE_PROJECT_DIR = $FixtureRoot

Push-Location $FixtureRoot
try {
    if ($WithBootstrap) {
        Write-Host "`n-- running specialists-init bootstrap first --" -ForegroundColor Yellow
        # Capture in FULL before slicing. Piping a child process straight into `Select-Object -First N`
        # tears the pipeline down as soon as N items are in, which KILLS the still-running child: the
        # first version of this script did exactly that and silently measured an unbootstrapped repo
        # as if it were bootstrapped (0 lenses created, exit 255, no complaint). Note the asymmetry
        # that makes this so easy to miss -- `-Last N` has to drain the whole stream to know what the
        # last N are, so it is harmless, while `-First N` is not. Sibling of the $LASTEXITCODE pitfall
        # in Sylvester #15's lens.
        $bootOut  = & powershell -NoProfile -ExecutionPolicy Bypass `
            -File (Join-Path $PluginRoot 'skills\specialists-init\bootstrap.ps1') `
            -ConsumerRoot $FixtureRoot 2>&1
        $bootCode = $LASTEXITCODE
        Write-Host ("  bootstrap exit: $bootCode, " + @($bootOut).Count + ' output line(s)')
        if ($bootCode -ne 0) {
            # Never measure past a failed setup -- the numbers below would describe a half-installed
            # repo while claiming to describe the happy path.
            Write-Host '  bootstrap FAILED -- the comparison below would be meaningless:' -ForegroundColor Red
            foreach ($line in @($bootOut)) { Write-Host "  | $line" }
            throw "bootstrap exited $bootCode; aborting the measurement."
        }
    }

    # Each hook, run the way the harness runs it. The overrides exist for exactly this purpose:
    # connector needs to be told where the workshop is (a scratch fixture has no sibling checkout),
    # the other two take the consumer path directly.
    $runs = @(
        @{ Name = 'connector-sessioncheck';       Args = @('-WorkshopPathOverride', $repoRoot, '-SkipDrift') },
        @{ Name = 'roster-sessioncheck';          Args = @('-ConsumerPathOverride', $FixtureRoot) },
        @{ Name = 'script-contract-sessioncheck'; Args = @('-ConsumerPathOverride', $FixtureRoot) }
    )

    $totalErrors = 0
    $mentions    = 0
    foreach ($run in $runs) {
        $out = & powershell -NoProfile -ExecutionPolicy Bypass `
            -File (Join-Path $hooks "$($run.Name).ps1") @($run.Args) 2>&1
        $errs = @($out | Where-Object { $_ -cmatch '\[ERROR\]' }).Count
        $totalErrors += $errs
        # The one thing a consumer in this state actually needs to be told.
        $mentions += @($out | Where-Object { $_ -match 'specialists-init' }).Count

        Write-Host "`n-- $($run.Name): $errs [ERROR] line(s)" -ForegroundColor Yellow
        foreach ($line in $out) { Write-Host "  | $line" }
    }

    Write-Host "`n== summary ==" -ForegroundColor Cyan
    # ABOVE THE NUMBERS, so a reader never takes a figure from a half-built fixture (issue #1635).
    # This script prints rather than exits on a count: it is a measurement, not a gate, and the honest
    # answer to a broken fixture here is to say the figures below are not about a fresh consumer.
    Write-FixtureGitSummary -Subject 'a fresh consumer' | Out-Null
    Write-Host "  [ERROR] lines a session start shows: $totalErrors"
    Write-Host "  lines naming 'specialists-init':     $mentions"
    if ($mentions -eq 0 -and $totalErrors -gt 0) {
        Write-Host "  -> $totalErrors problem(s) reported, and nothing names the skill that resolves them." -ForegroundColor Red
    }
}
finally {
    Pop-Location
    $env:CLAUDE_PLUGIN_ROOT = $prevPlugin
    $env:CLAUDE_PROJECT_DIR = $prevProject
}
