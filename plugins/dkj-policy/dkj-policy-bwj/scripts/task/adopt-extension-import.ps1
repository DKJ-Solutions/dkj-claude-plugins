<#
.SYNOPSIS
    Write the dkj-policy-bwj extension import into this repo's CLAUDE.md, directly below the dkj-policy
    constitution import -- step 6 of adopt-dkj-policy-bwj. Dry run by default.

.DESCRIPTION
    Issue #2532. Step 6 used to ask a person to add the line by hand. #2531 measured what that costs for
    the constitution import: a consumer ran for weeks without it, because a step on a skill page changes
    nothing a session knows. The extension line has the identical shape and is the identical line in
    every BWJ repo, so the adoption writes it too, with the same writer: Add-ClaudeMdImportLine in
    claude-md-import-lib.ps1, shared with dkj-policy's adopt-workflow-folder.ps1 so the two cannot drift.

    WHERE IT GOES: directly below the constitution import when CLAUDE.md has one, outside a fence.
    Without one it goes where the constitution would -- above the first '@'-import, or appended -- so a
    later adopt-dkj-policy run still lands the constitution above it. A CLAUDE.md that does not exist is
    created holding only this line. Line endings, mixed or not, and a byte-order mark are kept.

    ALREADY THERE is the line on an '@'-line of CLAUDE.md outside a fence, under any marketplace name, or
    anywhere in the '@'-import closure (Get-AlwaysOnDocuments). Then nothing is written.

    NEVER THROUGH A SYMLINK OR JUNCTION (#2533): when CLAUDE.md is one, nothing is written and the run
    prints the line to add by hand.

    WHAT IT DOES NOT DO: remove an older line that pointed at WORKFLOW-portable.md directly. Deleting a
    line from somebody's governance file is a person's act; step 6 on the skill page says so.

    Pure ASCII (repo convention for .ps1).

.PARAMETER Apply
    Write the line. Without it the run reports what it would do and writes nothing.

.PARAMETER RootOverride
    The repo root, for tests. Defaults to the checkout this runs in.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/adopt-extension-import.ps1"
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/adopt-extension-import.ps1" -Apply
#>
[CmdletBinding()]
param(
    [switch]$Apply,
    [string]$RootOverride = ''
)
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\lib\repo-root-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\measure-context-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\claude-md-import-lib.ps1')

$root = Resolve-BwjRepoRoot -Override $RootOverride
$claudeMd = Join-Path $root 'CLAUDE.md'
$line = Get-BwjExtensionImportLine

Write-Host "== adopt-extension-import$(if (-not $Apply) { ' (dry run)' }) -- $root ==" -ForegroundColor Cyan

$elsewhere = (Test-Path -LiteralPath $claudeMd -PathType Leaf) -and
    (Test-BwjExtensionImported -Documents @(Get-AlwaysOnDocuments -RootDocument $claudeMd -RepoRoot $root))
$action = Add-ClaudeMdImportLine -Path $claudeMd -Root $root -Line $line `
    -ImportedPattern '^\s*@\S*/dkj-policy/dkj-policy-bwj/CLAUDE\.md\s*$' `
    -AfterPattern '^\s*@\S*/plugins/dkj-policy/CLAUDE\.md\s*$' `
    -ImportedElsewhere:$elsewhere -Apply:$Apply

switch ($action) {
    'kept'   { Write-Host '  [keep]     CLAUDE.md already imports the dkj-policy-bwj extension -- left as it is' -ForegroundColor DarkGray }
    'refused' { Write-Host "  [refused]  CLAUDE.md is a symlink or junction, so the extension import was NOT written -- add it by hand: $line" -ForegroundColor Yellow }
    'create' { $verb = if ($Apply) { '[created]' } else { '[create] ' }
               Write-Host "  $verb  CLAUDE.md, holding the extension import: $line" -ForegroundColor Green }
    default  { $verb = if ($Apply) { '[added]  ' } else { '[add]    ' }
               Write-Host "  $verb  the extension import to CLAUDE.md: $line" -ForegroundColor Green }
}
if (-not $Apply -and $action -notin @('kept', 'refused')) {
    Write-Host 'Dry run: nothing written. Re-run with -Apply.' -ForegroundColor Yellow
}
