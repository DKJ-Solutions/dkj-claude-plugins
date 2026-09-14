<#
.SYNOPSIS
    Resolve the repo root, the one piece of self-contained mechanism every task script in this
    plugin needs before it can read scripts\repo-config.ps1. Shared so the trap it avoids -- and the
    reasoning for avoiding it -- exists in one place rather than in every script that resolves a
    root.

.DESCRIPTION
    Pulled out of publish-page.ps1 and build-backlog-page.ps1 (issue #1979's review chain), which had
    carried the identical function under two different names. Both scripts already dot-source
    sibling files from scripts\lib\ for their own pure logic (page-publish-rules.ps1,
    backlog-page-rules.ps1); this fits the same pattern rather than being a new kind of dependency.

    `2>$null` ON A NATIVE COMMAND IS A TRAP UNDER EAP=Stop, and every task script in this plugin runs
    under it. `git rev-parse --show-toplevel` writes to stderr in the ordinary case this handles -- a
    run started outside a work tree -- and PowerShell turns each of those lines into a terminating
    error, so the fallback below would never be reached unless the redirect is protected first. The
    repo-wide guard in scripts/tests/shared-scripts.tests.ps1 refuses an unprotected redirect
    anywhere in this repo and exonerates exactly the try/finally shape used here.

    STILL SELF-CONTAINED: this file lives inside dkj-policy-bwj's own scripts\lib\, so a script that
    dot-sources it is not reaching into a second plugin's libs -- the same boundary
    publish-page.ps1's own header states.

    Pure ASCII (repo convention for .ps1).
#>

function Resolve-BwjRepoRoot {
    <#
        The repo root: -Override if given (validated to be a directory), else `git rev-parse
        --show-toplevel`, else the current location. Never throws on a failed git call -- a repo with
        no git available at all still resolves to somewhere, exactly as before this was shared.
    #>
    param([string]$Override)
    if ($Override) {
        if (-not (Test-Path -LiteralPath $Override -PathType Container)) {
            throw "-RootOverride is not a directory: $Override"
        }
        return (Resolve-Path -LiteralPath $Override).Path
    }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $top  = & git rev-parse --show-toplevel 2>$null
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prev
    }
    if ($code -eq 0 -and $top) { return ((@($top)[0]) -replace '/', '\').Trim() }
    return (Get-Location).Path
}
