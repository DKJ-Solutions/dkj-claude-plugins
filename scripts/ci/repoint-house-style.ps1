<#
.SYNOPSIS
    Issue #3100: repoint the house-style skill at the brand book's latest release -- the links, the commit,
    both checksums, the retired-name list and the two vendored copies -- or say that nothing is due.

.DESCRIPTION
    Run by .github/workflows/house-style-repoint.yml, which builds the branch and opens the pull request;
    this script decides and rewrites, and touches neither git nor the tracker. It runs the same way by
    hand, from the root of a checkout on a repoint branch.

    WHAT IT ANSWERS FIRST. The tag the skill pins (read from its checksum table, the one place it is
    written) against the brand book's latest release, or -Tag. Due only when the release is NEWER: an
    older or equal tag is reported and nothing is written, so a release the brand book withdraws never
    walks the pin backwards.

    FAIL-CLOSED. A fetch that fails, a commit that does not resolve, a file that trips the skill page's
    safety reads, or a page whose shape the rewrite does not recognise is exit 1 with nothing written --
    the runner then opens no pull request, and the red run is the signal.

    Inside GitHub Actions it writes due, tag, from, branch and title to $env:GITHUB_OUTPUT.

.PARAMETER Tag
    The release to repoint at. Default: the brand book's latest release.

.PARAMETER BranchDocument
    The branch document new-branch.ps1 scaffolded; filled for the repoint when given.

.PARAMETER CheckOnly
    Report whether a repoint is due and write nothing.

.PARAMETER RepoRoot
    The tree to rewrite. Default: the checkout this script sits in.
#>
[CmdletBinding()]
param(
    [string]$Tag = '',
    [string]$BranchDocument = '',
    [switch]$CheckOnly,
    [string]$RepoRoot = ''
)

$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) { $RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path }
$plugin = Join-Path $RepoRoot 'plugins/dkj-policy/dkj-solutions'
. (Join-Path $plugin 'scripts/lib/house-style-rules.ps1')
. (Join-Path $RepoRoot 'scripts/lib/house-style-repoint-lib.ps1')

$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
$repo      = Get-HouseStyleBrandbookRepo
$skillPath = Join-Path $plugin 'skills/house-style/SKILL.md'
$rulesPath = Join-Path $plugin 'scripts/lib/house-style-rules.ps1'
$copyDirs  = @((Join-Path $RepoRoot 'scripts/dashboard/house-style'), (Join-Path $plugin 'assets/house-style'))

function Write-RepointOutput {
    param([hashtable]$Values)
    if (-not $env:GITHUB_OUTPUT) { return }
    foreach ($k in $Values.Keys) { Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "$k=$($Values[$k])" }
}

function Invoke-RepointGh {
    <#
        One gh call: its trimmed stdout and its exit code. ErrorActionPreference is Continue in here, because
        under Stop a native command that writes to stderr throws in Windows PowerShell 5.1 before its exit
        code can be read -- the pitfall shared-scripts.tests.ps1 holds the tree to.
    #>
    param([Parameter(Mandatory)][string[]]$Arguments)
    $ErrorActionPreference = 'Continue'
    $out = (& gh @Arguments 2>$null | Out-String).Trim()
    return @{ Out = $out; Code = $LASTEXITCODE }
}

function Stop-Repoint {
    param([string]$Reason)
    Write-Host "repoint-house-style: REFUSED -- $Reason" -ForegroundColor Red
    Write-RepointOutput @{ due = 'false' }
    exit 1
}

$skillText = [System.IO.File]::ReadAllText($skillPath)
$pin = Get-HouseStylePin -SkillText $skillText
if ($null -eq $pin -or -not (Test-HouseStyleReleaseTag $pin.Tag)) { Stop-Repoint 'the skill page carries no complete checksum table with a vX.Y.Z tag' }

if (-not $Tag) {
    $r = Invoke-RepointGh @('release', 'view', '-R', $repo, '--json', 'tagName', '--jq', '.tagName')
    $Tag = $r.Out
    if ($r.Code -ne 0) { Stop-Repoint "gh could not read the latest release of $repo" }
}
if (-not (Test-HouseStyleReleaseTag $Tag)) { Stop-Repoint "'$Tag' is not a vX.Y.Z release tag" }

# A PUBLISHED RELEASE, NOT JUST A TAG. A dispatch can name any tag, and a tag nobody released (or a draft,
# or a pre-release) is not something the brand book has said every app should take.
$r = Invoke-RepointGh @('release', 'view', $Tag, '-R', $repo, '--json', 'isDraft,isPrerelease')
$release = $r.Out
if ($r.Code -ne 0 -or -not $release) { Stop-Repoint "$Tag is not a release of $repo" }
$release = $release | ConvertFrom-Json
if ($release.isDraft -or $release.isPrerelease) { Stop-Repoint "$Tag is a draft or a pre-release" }

if ([version]$Tag.Substring(1) -le [version]$pin.Tag.Substring(1)) {
    Write-Host "repoint-house-style: nothing due -- the skill pins $($pin.Tag), the release is $Tag."
    Write-RepointOutput @{ due = 'false'; tag = $Tag; from = $pin.Tag }
    exit 0
}

$branch = Get-HouseStyleRepointBranch -Tag $Tag
$title  = "house-style skill: repoint at dkj-brandbook $Tag"
Write-Host "repoint-house-style: due -- the skill pins $($pin.Tag), $repo released $Tag."
if ($CheckOnly) {
    Write-RepointOutput @{ due = 'true'; tag = $Tag; from = $pin.Tag; branch = $branch; title = $title }
    exit 0
}

# THE COMMIT FIRST, THEN THE BYTES AT THAT COMMIT. A tag can be moved; fetching at the tag and resolving it
# separately could pin one commit and hash another's bytes. raw.githubusercontent.com rather than the
# contents API, because that is the host every session fetches from when it checks the copy.
$r = Invoke-RepointGh @('api', "repos/$repo/commits/$Tag", '--jq', '.sha')
$commit = $r.Out
if ($r.Code -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$') { Stop-Repoint "the commit behind $Tag did not resolve" }

$scratch = Join-Path ([System.IO.Path]::GetTempPath()) "house-style-repoint-$PID-$([guid]::NewGuid().ToString('n'))"
New-Item -ItemType Directory -Path $scratch | Out-Null
try {
    $bytes = @{}
    foreach ($leaf in @((Get-HouseStyleCopyNames) + 'README.md')) {
        $url = "https://raw.githubusercontent.com/$repo/$commit/house-style/$leaf"
        $dest = Join-Path $scratch $leaf
        try { Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing }
        catch { Stop-Repoint "could not fetch $url ($($_.Exception.Message))" }
        $bytes[$leaf] = [System.IO.File]::ReadAllBytes($dest)
    }
} finally { Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue }

$cssText    = $Utf8NoBom.GetString($bytes['house-style.css'])
$jsText     = $Utf8NoBom.GetString($bytes['house-theme.js'])
$readmeText = $Utf8NoBom.GetString($bytes['README.md'])
$findings = @(Get-HouseStyleSafetyFindings -CssText $cssText -JsText $jsText)
if ($findings.Count) { Stop-Repoint ("the files at $Tag fail the skill page's denylist: " + ($findings -join '; ')) }

$hashes = @{}
foreach ($leaf in (Get-HouseStyleCopyNames)) { $hashes[$leaf] = @(Get-HouseStyleSha256 -Bytes $bytes[$leaf])[0] }
$filesChanged = $false
foreach ($leaf in (Get-HouseStyleCopyNames)) { if ($hashes[$leaf] -ne $pin.Hashes[$leaf]) { $filesChanged = $true } }
$jsChanged = $hashes['house-theme.js'] -ne $pin.Hashes['house-theme.js']

# THE OLD STYLESHEET IS THE VENDORED COPY, which the house-style gate holds to the old pin.
$oldCss = [System.IO.File]::ReadAllText((Join-Path $copyDirs[0] 'house-style.css'))
$current = @(Get-HouseStyleRetiredTokens)
$next = @(Get-HouseStyleNextRetired -Current $current `
    -OldTokens (Get-HouseStyleDefinitions -CssText $oldCss).Tokens `
    -NewTokens (Get-HouseStyleDefinitions -CssText $cssText).Tokens `
    -Renamed (Get-HouseStyleRenamedNames -ReadmeText $readmeText))
$added   = @($next | Where-Object { $current -cnotcontains $_ })
$removed = @($current | Where-Object { $next -cnotcontains $_ })

# EVERY TEXT IS COMPUTED BEFORE THE FIRST WRITE, so a shape the rewrite does not recognise (a throw) leaves
# the tree exactly as it was.
try {
    $newSkill = Set-HouseStyleSkillPin -Text $skillText -From $pin.Tag -To $Tag -Commit $commit -Hashes $hashes
    $newRules = Set-HouseStyleRetiredList -Text ([System.IO.File]::ReadAllText($rulesPath)) -Tag $Tag -Names $next
    $newDoc = if ($BranchDocument) {
        Set-HouseStyleRepointDocument -Text ([System.IO.File]::ReadAllText($BranchDocument)) -From $pin.Tag -To $Tag `
            -Commit $commit -FilesChanged $filesChanged -JsChanged $jsChanged -Added $added -Removed $removed
    }
} catch { Stop-Repoint $_.Exception.Message }

[System.IO.File]::WriteAllText($skillPath, $newSkill, $Utf8NoBom)
[System.IO.File]::WriteAllText($rulesPath, $newRules, $Utf8NoBom)
foreach ($dir in $copyDirs) {
    foreach ($leaf in (Get-HouseStyleCopyNames)) { [System.IO.File]::WriteAllBytes((Join-Path $dir $leaf), $bytes[$leaf]) }
}
if ($BranchDocument) { [System.IO.File]::WriteAllText($BranchDocument, $newDoc, $Utf8NoBom) }

Write-Host "repoint-house-style: repointed $($pin.Tag) -> $Tag (commit $($commit.Substring(0, 8)); files changed: $filesChanged; retired +$($added.Count) -$($removed.Count))."
Write-RepointOutput @{ due = 'true'; tag = $Tag; from = $pin.Tag; branch = $branch; title = $title }
exit 0
