<#
.SYNOPSIS
    Upload one file to a published GitHub Release, replacing an asset of the same name BY ID, and
    verify afterwards that the published asset carries the file's exact byte count.

.DESCRIPTION
    THE GAP THIS CLOSES (issue #2347). The cut-release skill's second pass edits a hand-written release
    document after step 5 has already attached it, so the attachment has to be uploaded again (#1897).
    The page prescribed `gh release upload <tag> <file> --clobber` for that. Measured at the v5.7.0 cut
    on gh 2.101.0: that command returned `HTTP 422: Validation Failed ... ReleaseAsset.name already
    exists` and left the stale asset in place, and the fallback a reader reaches for next --
    `gh release delete-asset <tag> <name>` -- reported the asset `not found` while the REST API listed
    it by exactly that name. Both resolve the existing asset BY NAME before acting; the route that
    worked was deleting it BY ID through the API and uploading without --clobber. That route is this
    script.

    SO IT NEVER ASKS gh TO FIND AN ASSET BY NAME. It reads the release's asset list from the REST API
    itself (repos/{repo}/releases/tags/{tag}), matches the name here, and deletes by the id it read.
    --clobber is deliberately not passed: after the delete there is nothing to clobber, and a name that
    somehow still exists should fail loudly rather than be resolved by the lookup that already failed.

    THE BYTE COUNT IS THE PROOF, NOT THE EXIT CODE. #1897's stale asset was caught only because
    somebody watched the size, and #2347's was a 15,071 B asset against a 15,864 B document. So after
    the upload the asset list is read again and the asset must exist with exactly the file's length;
    anything else exits 1 and says which of the two it found.

    WHAT IT DOES NOT DO. It does not create a Release, publish one, or touch the Release body -- the tag
    must already carry a Release. It does not copy the document to its unique filename either: the file
    passed IS the asset, and its leaf name is the asset name, exactly as the skill's upload lines have
    always worked.

    Pure ASCII (repo convention for .ps1).

.PARAMETER Tag
    The tag whose Release receives the file, e.g. v5.7.0.

.PARAMETER Path
    The file to upload. Its leaf name is the asset name, so copy the document to its unique release
    filename (e.g. v5.7.0-notes-for-users.md) first.

.PARAMETER Repo
    (Optional) 'owner/name'. Defaults to Get-RepoName from scripts/repo-config.ps1 where that seam
    exists, and otherwise to gh's own resolution of the current checkout.

.EXAMPLE
    ./scripts/release/upload-release-asset.ps1 -Tag v5.7.0 -Path ./v5.7.0-notes-for-users.md
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Tag,
    [Parameter(Mandatory = $true)][string]$Path,
    [string]$Repo = ''
)
$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before. Why: the lib's header.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$repoRoot = Resolve-RepoRootOrFail -ScriptName 'upload-release-asset.ps1'

. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    Write-Host "[ERROR] no file at '$Path' -- nothing was uploaded." -ForegroundColor Red
    exit 1
}
$file = Get-Item -LiteralPath $Path
$assetName = $file.Name
$expectedBytes = [long]$file.Length

# -Repo wins, so a test fixture needs no repo-config. The seam is read defensively: a consumer without
# Get-RepoName falls back to gh's own resolution of the checkout, which is what --repo omitted means.
if (-not $Repo) {
    $repoConfig = Join-Path $repoRoot 'scripts\repo-config.ps1'
    if (Test-Path -LiteralPath $repoConfig -PathType Leaf) {
        . $repoConfig
        if (Test-FunctionDefined 'Get-RepoName') { $Repo = Get-RepoName }
    }
}
$repoArgs = @()
$apiRepo = '{owner}/{repo}'  # gh api expands these placeholders from the current checkout
if ($Repo) { $repoArgs = @('--repo', $Repo); $apiRepo = $Repo }

function Get-ReleaseAssets {
    <# The release's assets as objects (id, name, size), read from the REST API -- never through a gh
       subcommand that looks an asset up by name, which is the half #2347 measured failing. Returns
       $null when the read itself failed, so "no assets" and "could not read" stay different answers. #>
    $r = Invoke-NativeCapture -Utf8 -FilePath 'gh' -Arguments @('api', "repos/$apiRepo/releases/tags/$Tag") `
        -DiscardStderr -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
    if (-not (Test-NativeExitMeasured -Capture $r) -or $r.ExitCode -ne 0) { return $null }
    try { $release = (($r.Output -join "`n") | ConvertFrom-Json) } catch { return $null }
    # The leading comma keeps an EMPTY list a list: returned bare, @() unrolls to $null, and a Release
    # with no attachments yet -- step 5's first upload -- would read as a Release that could not be read.
    return ,@($release.assets | Where-Object { $_ } | ForEach-Object {
        [pscustomobject]@{ Id = [string]$_.id; Name = [string]$_.name; Size = [long]$_.size }
    })
}

Write-Host "== upload-release-asset: $assetName -> $Tag ($expectedBytes B) ==" -ForegroundColor Cyan

$before = Get-ReleaseAssets
if ($null -eq $before) {
    Write-Host "[ERROR] could not read the Release for tag '$Tag' -- nothing was deleted or uploaded." -ForegroundColor Red
    Write-Host "        The tag needs a published Release first. Check: gh release view $Tag" -ForegroundColor Red
    exit 1
}

$stale = @($before | Where-Object { $_.Name -eq $assetName })
foreach ($asset in $stale) {
    if ($asset.Size -eq $expectedBytes) {
        Write-Host "  existing asset $($asset.Id) is already $expectedBytes B -- replacing it anyway, since equal size is not equal content." -ForegroundColor DarkGray
    }
    $del = Invoke-NativeCapture -FilePath 'gh' -Arguments @('api', '-X', 'DELETE', "repos/$apiRepo/releases/assets/$($asset.Id)") `
        -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
    if (-not (Test-NativeExitMeasured -Capture $del) -or $del.ExitCode -ne 0) {
        Write-Host "[ERROR] deleting asset $($asset.Id) ($assetName, $($asset.Size) B) failed ($(Get-NativeExitLabel -Capture $del)) -- nothing was uploaded, the old asset stands." -ForegroundColor Red
        foreach ($line in @($del.Output)) { if ("$line".Trim()) { Write-Host "        gh: $line" -ForegroundColor Red } }
        exit 1
    }
    Write-Host "  deleted stale asset $($asset.Id) ($($asset.Size) B), by id" -ForegroundColor DarkGray
}

$up = Invoke-NativeCapture -FilePath 'gh' -Arguments (@('release', 'upload', $Tag, $file.FullName) + $repoArgs) `
    -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
$uploadExit = Get-NativeExitLabel -Capture $up
# stderr is KEPT on both writes (not -DiscardStderr): nothing parses their output, so dropping it would
# only cost the reader gh's own diagnosis -- the HTTP status, an auth or permission refusal.
function Write-UploadOutput { foreach ($line in @($up.Output)) { if ("$line".Trim()) { Write-Host "        gh: $line" -ForegroundColor Red } } }

# Verified whatever the upload's exit said: a timed-out upload may have landed, and a clean exit is not
# the proof -- the byte count on the published asset is.
$after = Get-ReleaseAssets
if ($null -eq $after) {
    Write-Host "[WARNING] the upload ended with $uploadExit, and the Release could not be read back, so this run cannot say whether $assetName is published." -ForegroundColor Yellow
    Write-Host "          Check: gh release view $Tag --json assets" -ForegroundColor Yellow
    exit 1
}
$published = @($after | Where-Object { $_.Name -eq $assetName })
if ($published.Count -eq 0) {
    Write-Host "[ERROR] $assetName is NOT on the Release after the upload (the upload ended with $uploadExit)." -ForegroundColor Red
    Write-UploadOutput
    if ($stale.Count -gt 0) { Write-Host "        The stale copy WAS deleted, so the Release now lacks this attachment -- re-run this script." -ForegroundColor Red }
    exit 1
}
if ($published.Count -gt 1 -or $published[0].Size -ne $expectedBytes) {
    $sizes = ($published | ForEach-Object { "$($_.Size) B" }) -join ', '
    Write-Host "[ERROR] $assetName is published at $sizes against a file of $expectedBytes B -- the attachment is not the document." -ForegroundColor Red
    exit 1
}
Write-Host "[OK] $assetName is published on $Tag at $expectedBytes B, matching the file." -ForegroundColor Green
exit 0
