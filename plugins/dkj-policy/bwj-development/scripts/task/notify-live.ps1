<#
.SYNOPSIS
    Tell the Asana task of every issue a release carried that its work is now LIVE -- run by a person
    right after the live push and the cut. A dry run by default; -Post writes.

.DESCRIPTION
    INBOUND #3070 (Maikel, from BWJ-Development/smartwatchbanden, October 16, 2026). An issue built but
    visible only after a release closes at the PR step, and its closed message says the result becomes
    visible with the release named below (#3069). Until this script nothing told the task when that
    release had gone out. Maikel chose the owner of the step on #3070: a script a person runs after the
    live push, because nothing automated knows the moment a release IS live -- the push is printed for a
    person to run, never run by a script -- and that moment is what the message claims. prepare-release's
    runbook prints this script as the step after the cut, so it is not forgotten.

    FIVE STEPS:

      1 the release   -Version (default: the highest vX.Y.Z tag) and the tag below it, as versions.
      2 the PRs       every '#<n>' in the range's first-parent subjects, kept only where gh says that PR
                      is MERGED and its merge commit is inside the range -- a subject can name any number.
      3 the issues    the issues those PRs closed (closingIssuesReferences), each read with its comments
                      and its last reopen.
      4 the verdict   Get-LiveMessageVerdict: owed only where the issue is closed as completed, links one
                      task, has not been told yet, and its newest go-live block is this round's and
                      carries the after-release marker (#3069) -- the requesters told "visible with the
                      release", and no others. A -LiveSince block (told 'live' at the close) and a
                      research block are skipped by that same marker.
      5 the post      -Post only: one html_text comment per owed task, then the marker comment on the
                      issue (Get-LiveMessageMarker), so a second run tells nobody twice.

    WHAT IT NEVER DOES: push, publish, cut, tag, move a card, complete a task, or write a label. Its one
    Asana write is a comment, and its one GitHub write is the marker comment. A file held back from the
    push is not something this script can see -- the live-push record is dkj-policy's and
    dkj-subagents-shopify's, outside this plugin's folder -- so -SkipIssue holds an issue out by hand, and
    the dry run is the list a person reads before -Post.

    IT PRINTS NOTHING ANOTHER PERSON WROTE beyond an issue's number: a title, a body or an Asana error
    message is not printed, and a failed post reports its HTTP status alone -- the rule the closed
    message keeps (asana-closed-message.ps1).

    Auth: ASANA_PAT in the session's environment (or -AsanaPat), the personal token build-backlog-page
    reads too. Asked for only by -Post, and only when at least one task is owed the message.

    Pure ASCII (repo convention for .ps1).

.PARAMETER Version
    The release that just went live, as vX.Y.Z. Default: the highest vX.Y.Z tag.

.PARAMETER SinceTag
    The tag the release's range starts at, instead of the highest one below -Version.

.PARAMETER Post
    Post the live message on every owed task. Without it nothing is written.

.PARAMETER SkipIssue
    Issue numbers held out by hand -- a change whose files were held back from the push.

.PARAMETER Repo
    owner/repo, instead of Get-RepoName or the checkout's own.

.PARAMETER AsanaPat
    The Asana token, instead of ASANA_PAT.

.PARAMETER RootOverride
    The repo root, when this is not run from inside the checkout -- and the fixture root for a suite.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/notify-live.ps1"

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/notify-live.ps1" -Version v2.46.0 -Post
#>
[CmdletBinding()]
param(
    [string]$Version = '',
    [string]$SinceTag = '',
    [switch]$Post,
    [int[]]$SkipIssue = @(),
    [string]$Repo = '',
    [string]$AsanaPat = $env:ASANA_PAT,
    [string]$RootOverride = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Captured before the repo's own config is dot-sourced below: repo-config.ps1 is the consumer's, and it
# may bind any name it likes -- the guard prepare-release.ps1 keeps for the same reason.
$VersionArg = $Version; $SinceArg = $SinceTag; $PostArg = [bool]$Post; $SkipArg = @($SkipIssue)
$RepoArg = $Repo; $PatArg = $AsanaPat; $RootArg = $RootOverride

. (Join-Path $PSScriptRoot '..\lib\repo-root-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\live-push-rules.ps1')
. (Join-Path $PSScriptRoot '..\lib\asana-task-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\golive-block-rules.ps1')
. (Join-Path $PSScriptRoot '..\lib\live-message-rules.ps1')

$repoRoot = Resolve-BwjRepoRoot -Override $RootArg
# gh resolves its repo from the CURRENT directory, so a run started elsewhere would read another repo.
Set-Location -LiteralPath $repoRoot

# A repo that publishes plugins is this script's SOURCE, not a store -- the test prepare-release makes.
if (-not $RootArg -and (Test-Path -LiteralPath (Join-Path $repoRoot '.claude-plugin\marketplace.json') -PathType Leaf)) {
    Write-Host 'REFUSED: this repo publishes plugins, so it is this script''s source rather than a store.' -ForegroundColor Red
    Write-Host 'There is no release here to tell anybody about. Nothing was read or written.'
    exit 1
}

# THE SEAMS, AT SCRIPT SCOPE (#2339), and the exception's TYPE, never its message (#2509).
$configPath = Join-Path $repoRoot 'scripts\repo-config.ps1'
if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    Set-StrictMode -Off
    $resolvedRoot = $repoRoot
    try { . $configPath } catch { Write-Warning "scripts/repo-config.ps1 threw $($_.Exception.GetType().Name) while being read -- dot-source it directly to see the error." }
    Set-StrictMode -Version Latest
    $repoRoot = $resolvedRoot
}

function Invoke-Native {
    <# A native command whose stderr and exit code are read rather than thrown on -- the try/finally shape
       prepare-release.ps1 uses, with its catch for a missing executable. #>
    param([Parameter(Mandatory = $true)][scriptblock]$Command)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = @()
    try {
        $out  = & $Command 2>$null
        $code = $LASTEXITCODE
    } catch {
        $code = -1
    } finally {
        $ErrorActionPreference = $prev
    }
    return [pscustomobject]@{ Lines = @(@($out) | ForEach-Object { "$_" }); Code = $code }
}

$repoName = ([string]$RepoArg).Trim()
if (-not $repoName -and @($ExecutionContext.InvokeCommand.GetCommands('Get-RepoName', 'Function', $false)).Count -gt 0) {
    try { $repoName = ([string](Get-RepoName)).Trim() } catch { $repoName = '' }
}
if (-not $repoName) { $repoName = (@((Invoke-Native { gh repo view --json nameWithOwner -q .nameWithOwner }).Lines) | Select-Object -First 1) }
$repoName = ([string]$repoName).Trim()
if ($repoName -notmatch '\A[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9._-]+\z') {
    Write-Host '[ERROR] Could not resolve which repo this is (owner/repo). Pass -Repo. Nothing was read or written.' -ForegroundColor Red
    exit 1
}
$owner, $name = $repoName -split '/', 2

# === 1/5 -- the release ============================================================================
Write-Host "== notify-live -- $repoName ==" -ForegroundColor Cyan
Write-Host "   $(if ($PostArg) { 'POST: the live message goes to every task owed it.' } else { 'Dry run: nothing is written. Pass -Post to send.' })"
Write-Host ''

$tags = @((Invoke-Native { git -C $repoRoot tag --list }).Lines)
$version = ([string]$VersionArg).Trim()
if (-not $version) { $version = Get-HighestReleaseTag -Tags $tags }
if ($version -notmatch '^v\d+\.\d+\.\d+$') {
    Write-Host "[ERROR] No release to announce: '$version' is not a vX.Y.Z tag. Pass -Version. Nothing was written." -ForegroundColor Red
    exit 1
}
if (-not ($tags -contains $version)) {
    Write-Host "[ERROR] $version is not a tag in this checkout -- run it after the cut, or 'git fetch --tags'. Nothing was written." -ForegroundColor Red
    exit 1
}
$since = ([string]$SinceArg).Trim()
if (-not $since) { $since = Get-PreviousReleaseTag -Tags $tags -Version $version }
if (-not $since -or -not ($tags -contains $since)) {
    Write-Host "[ERROR] No release tag below $version to start the range at. Pass -SinceTag. Nothing was written." -ForegroundColor Red
    exit 1
}
Write-Host "[1/5] release -- $version, carrying $since..$version" -ForegroundColor Cyan

# === 2/5 -- the pull requests ======================================================================
$rangeShas = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
$revs = Invoke-Native { git -C $repoRoot rev-list "$since..$version" }
$subjects = Invoke-Native { git -C $repoRoot log --first-parent --format=%s "$since..$version" }
if ($revs.Code -ne 0 -or $subjects.Code -ne 0) {
    Write-Host "[ERROR] Could not read $since..$version from git. Nothing was written." -ForegroundColor Red
    exit 1
}
foreach ($s in $revs.Lines) { if ($s.Trim()) { [void]$rangeShas.Add($s.Trim()) } }

$readFailures = 0
$issueNumbers = New-Object 'System.Collections.Generic.List[int]'
$prsKept = 0
foreach ($n in @(Get-ReleaseRangePullNumbers -Subjects $subjects.Lines)) {
    $pr = Invoke-Native { gh pr view "$n" --repo $repoName --json number,state,mergeCommit,closingIssuesReferences }
    if ($pr.Code -ne 0) { continue }   # an issue's number, or a PR of another repo: not this release's PR
    try { $j = ($pr.Lines -join "`n") | ConvertFrom-Json } catch { $readFailures++; Write-Host "  PR #$n -- its reply did not parse" -ForegroundColor Yellow; continue }
    $oid = if ($j.mergeCommit) { [string]$j.mergeCommit.oid } else { '' }
    if ([string]$j.state -ne 'MERGED' -or -not $oid -or -not $rangeShas.Contains($oid)) { continue }
    $prsKept++
    foreach ($r in @($j.closingIssuesReferences | Where-Object { $_ })) {
        $num = [int]$r.number
        if (-not $issueNumbers.Contains($num)) { $issueNumbers.Add($num) }
    }
}
Write-Host "[2/5] pull requests -- $prsKept merged in the range, closing $($issueNumbers.Count) issue(s)" -ForegroundColor Cyan

# === 3/5 + 4/5 -- the issues and the verdict =======================================================
Write-Host '[3/5] issues, [4/5] verdict' -ForegroundColor Cyan
$owed = @()
foreach ($num in $issueNumbers) {
    if ($SkipArg -contains $num) { Write-Host "  #$num  held     -SkipIssue" -ForegroundColor DarkGray; continue }
    $iv = Invoke-Native { gh issue view "$num" --repo $repoName --json state,stateReason }
    $state = Read-AsanaIssueBlockState -Owner $owner -Repo $name -Number $num -WorkingDirectory $repoRoot
    if ($iv.Code -ne 0 -or -not $state.Ok) {
        $readFailures++
        Write-Host "  #$num  UNREAD   the issue or its comments could not be read -- not told" -ForegroundColor Yellow
        continue
    }
    if ($state.Truncated) {
        $readFailures++
        Write-Host "  #$num  UNREAD   more comments than one read returns, so its block cannot be judged -- not told" -ForegroundColor Yellow
        continue
    }
    $ij = ($iv.Lines -join "`n") | ConvertFrom-Json
    $verdict = Get-LiveMessageVerdict -Issue ([pscustomobject]@{
        Number = $num; State = [string]$ij.state; StateReason = [string]$ij.stateReason
        Body = $state.Body; Comments = $state.Comments; LastReopenedAt = $state.LastReopenedAt
    })
    if ($verdict.Owed) {
        $owed += [pscustomobject]@{ Number = $num; Gid = $verdict.Gid; Language = $verdict.Language }
        Write-Host "  #$num  OWED     $($verdict.Reason) ($($verdict.Language))" -ForegroundColor Green
    } else {
        Write-Host "  #$num  skipped  $($verdict.Reason)" -ForegroundColor DarkGray
    }
}

# === 5/5 -- the post ===============================================================================
Write-Host "[5/5] post -- $($owed.Count) task(s) owed the live message" -ForegroundColor Cyan
if ($owed.Count -gt 0 -and -not $PostArg) {
    Write-Host ''
    Write-Host '  It reads, for the first of them:' -ForegroundColor DarkGray
    foreach ($l in (Get-LiveMessageLines -IssueRef "$repoName#$($owed[0].Number)" -Version $version -Language $owed[0].Language)) { Write-Host "    $l" }
}

$postFailures = 0
if ($PostArg -and $owed.Count -gt 0) {
    if (-not $PatArg) {
        Write-Host '[ERROR] ASANA_PAT is not set (environment or -AsanaPat). Nothing was posted.' -ForegroundColor Red
        exit 1
    }
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "notify-live-$PID-$([guid]::NewGuid().ToString('n')).md"
    try {
        foreach ($o in $owed) {
            $ref = "$repoName#$($o.Number)"
            $html = New-LiveMessageHtml -IssueRef $ref -Version $version -Language $o.Language
            $body = ConvertTo-Json @{ data = @{ html_text = $html } } -Compress -Depth 5
            try {
                Invoke-RestMethod -Method POST -Uri "$script:AsanaApiBase/tasks/$($o.Gid)/stories" -Headers @{ Authorization = "Bearer $PatArg" } `
                    -ContentType 'application/json; charset=utf-8' -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
            } catch {
                $postFailures++
                $status = try { [int]$_.Exception.Response.StatusCode } catch { 0 }
                Write-Host "  #$($o.Number)  FAILED   Asana answered $(if ($status) { "HTTP $status" } else { 'no status' }) -- not told, and no marker written" -ForegroundColor Red
                continue
            }
            # THE MARKER AFTER THE POST, never before: a marker for a post that failed would hold the
            # requester out of every later run.
            [System.IO.File]::WriteAllText($tmp, (Format-LiveMessageIssueComment -Version $version -Gid $o.Gid), (New-Object System.Text.UTF8Encoding $false))
            $mark = Invoke-Native { gh issue comment "$($o.Number)" --repo $repoName --body-file $tmp }
            if ($mark.Code -ne 0) {
                $postFailures++
                Write-Host "  #$($o.Number)  TOLD     but the marker comment failed -- a second run would tell it again; comment it by hand" -ForegroundColor Yellow
            } else {
                Write-Host "  #$($o.Number)  TOLD     task $($o.Gid)" -ForegroundColor Green
            }
        }
    } finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    }
}

Write-Host ''
if ($readFailures -gt 0 -or $postFailures -gt 0) {
    Write-Host "$readFailures read(s) and $postFailures post(s) failed -- the issues named above were not told. Run it again once gh and Asana answer." -ForegroundColor Red
    exit 1
}
Write-Host $(if ($PostArg) { "Done: $($owed.Count) task(s) told $version is live." } else { "Dry run: $($owed.Count) task(s) would be told. Nothing was written." }) -ForegroundColor Green
exit 0
