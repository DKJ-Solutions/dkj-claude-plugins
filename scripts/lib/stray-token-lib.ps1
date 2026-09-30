<#
.SYNOPSIS
    Find-StrayToken: every copy of a gitignored path-token file in this tree that is NOT the one a run
    expects -- the one guard behind both path-token scripts (issue #2644).

.DESCRIPTION
    Dot-source this file:

        . (Join-Path $PSScriptRoot '..\lib\stray-token-lib.ps1')

    ONE DEFINITION WHERE THERE WERE TWO. build-release-notes-page.ps1 (worker-path-token.txt) and
    issue-dashboard.ps1 (dashboard-path-token.txt, #2643) each carried a near-copy of this walk,
    differing only in the file name, so any change to the guard had to be made twice (#2644).

    WHY IT LOOKS AT ALL. Both tokens live in a directory that is derived from a tracked folder and
    gitignored -- two good decisions that combine into one hazard. Rename or repoint that folder and
    every tracked file moves with it, while the token stays behind in a folder nothing points at any
    more: git mv cannot see an ignored sibling by construction, so the miss is silent on the day it
    happens. That file is the only copy of the live page's path, and nothing in git remembers the URL,
    so the orphan reads as rename debris -- and deleting it 404s every link already sent (issue #1444,
    September 5, 2026, after this repo's own contributing-davekjohn/ -> dkj-policy/ rename left exactly
    that folder behind).

    AND IT IS WHAT MAKES AN -InitToken REFUSAL MEAN WHAT IT SAYS. A guard that reads only the expected
    path finds no token after a move and mints a second one happily -- the one act the token design
    exists to prevent. "Is there a token SOMEWHERE" is the question worth asking; "is there a token
    HERE" was only ever a cheap approximation of it.

    Cheap enough to sit on the failure paths because that is the only place its callers run it. .git
    is skipped: nothing writes a token there, and walking it is the expensive half of the search.

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script.
    Pure ASCII (repo convention for .ps1).
#>

function Find-StrayToken {
    <#
        The full paths of every file named -FileName under -Root, other than -ExpectedPath and
        anything inside a .git directory. An empty array when there are none or -Root does not exist.

        Wrap the call in @( ) at the call site: PowerShell unrolls a returned empty array to $null,
        and Set-StrictMode -Version Latest then refuses .Count on it.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$ExpectedPath,
        [Parameter(Mandatory = $true)][string]$FileName
    )

    if (-not (Test-Path -LiteralPath $Root)) { return @() }
    $hits = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $FileName -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -ne $ExpectedPath -and $_.FullName -notlike '*\.git\*' }
    return @($hits | ForEach-Object { $_.FullName })
}
