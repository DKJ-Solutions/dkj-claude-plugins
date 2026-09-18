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
    under it. `git rev-parse` writes to stderr in the ordinary case this handles -- a
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
        # NOT --show-toplevel (issue #2115). Its output is a RAW path, and Windows PowerShell 5.1
        # decodes a native child's stdout with [Console]::OutputEncoding -- so in a store checkout
        # under an accented directory name this returned a well-formed string that matched nothing,
        # and every page path composed from it pointed at a file that was not there.
        #
        # --show-cdup reports the root RELATIVE to here, which is a run of '../' segments and no
        # filename at all, so there is nothing in it for a code page to corrupt; the base it is joined
        # onto is a string PowerShell already holds. --is-inside-work-tree rides along in the same
        # call because --show-cdup alone exits 0 inside the .git directory and prints nothing, where
        # --show-toplevel exited 128 -- without it this would resolve .git itself as the root.
        #
        # INLINE RATHER THAN SHARED, deliberately: scripts\lib\repo-root-lib.ps1 in the workshop root
        # carries the same mechanism with its full measurement, but it mirrors into dkj-policy,
        # dkj-subagents-alpha and dkj-subagents-shopify -- not into this plugin -- and reaching for it
        # would cross exactly the plugin boundary this file's own header keeps.
        $raw  = & git rev-parse --is-inside-work-tree --show-cdup 2>$null
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prev
    }
    $lines = @(@($raw) | ForEach-Object { "$_".Trim() })
    if ($code -eq 0 -and $lines.Count -ge 1 -and $lines[0] -eq 'true') {
        $cdup = $(if ($lines.Count -ge 2) { $lines[1] } else { '' })
        $base = $PWD.ProviderPath
        $full = $(if ($cdup) { [System.IO.Path]::GetFullPath((Join-Path $base $cdup)) }
                  else       { [System.IO.Path]::GetFullPath($base) })
        if ($full.Length -gt 3 -and ($full.EndsWith('\') -or $full.EndsWith('/'))) { $full = $full.TrimEnd('\', '/') }
        return $full
    }
    return (Get-Location).Path
}
