<#
.SYNOPSIS
    The register check's old name, kept as a forwarder: it runs check-consumers.ps1 with the same
    arguments and returns its exit code.

.DESCRIPTION
    THE CHECK WAS RENAMED WITH ITS FOLDER (#3675, October 30, 2026): connectors/ became consumers/,
    check-connectors.ps1 became check-consumers.ps1, and the SessionStart hook became
    consumer-sessioncheck.ps1.

    THIS FILE EXISTS FOR THE HOOKS ALREADY INSTALLED. A hook from a release before the rename finds the
    source checkout by testing for scripts\sync\check-connectors.ps1, then runs it. Without this file,
    every session start beside a source checkout on main would read that checkout as absent and fall
    back to the version-only path, until its plugins were updated. The output's header now reads
    '== check-consumers', so an old hook prints its summary without the 'source read at' stamp. That
    is the one thing it loses.

    It goes once every install runs a release that carries consumer-sessioncheck.ps1.
#>
param(
    [string]$Manifest = '',
    [string]$ConsumerPathOverride = '',
    [string]$OnlyConsumer = '',
    [switch]$SkipDrift,
    [switch]$SkipVersions,
    [switch]$RemoteRunners,
    [string]$UserHomeOverride = ''
)

& (Join-Path $PSScriptRoot 'check-consumers.ps1') @PSBoundParameters
exit $LASTEXITCODE
