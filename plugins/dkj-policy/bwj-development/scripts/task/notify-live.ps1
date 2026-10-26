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
      3 the issues    the issues those PRs carried, each read with its comments and its last reopen:
                      the ones they closed (closingIssuesReferences), plus the issue each head branch is
                      named after and every '#<n>' in its body that GitHub confirms is an issue
                      (Get-PullIssueCandidates, #3498) -- a -NoResolves PR closes nothing, and those are
                      the issues this message exists for. The verdict below decides; a surplus number
                      is a 'skipped' row, never a message.
      4 the verdict   Get-LiveMessageVerdict: owed only where the issue is closed as completed, links one
                      task, has not been told yet, and its newest go-live block is this round's and
                      carries the after-release marker (#3069) -- the requesters told "visible with the
                      release", and no others. A -LiveSince block (told 'live' at the close) and a
                      research block are skipped by that same marker.
      5 the post      -Post only: one html_text comment per owed task, then the marker comment on the
                      issue (Get-LiveMessageMarker), so a second run tells nobody twice.

    WHAT IT NEVER DOES: push, publish, cut, tag, move a card, complete a task, or write a label. Its one
    Asana write is a comment, and its one GitHub write is the marker comment.

    THE LIVE-PUSH RECORD DECIDES WHAT IS HELD (#3176). -LivePushRecord is the file live-preflight wrote
    and the cut read, and an issue is held -- not told -- when a PR that closed it changed a path the
    record marks 'hold': a theme file held back from the push, or an app file whose `shopify app deploy`
    was not run. Without the record nothing can see either, which is how an app-only change came to be
    announced with the release before its deploy ran. The record's format and its "is this entry live"
    rule are live-record-lib's, mirrored here byte-identical, so this script and the cut cannot read one
    record two ways. A PR whose merge's files cannot be read is UNREAD, never live. Without the record the
    run says so, and -SkipIssue is the hand hold-out it always was; the dry run is the list a person reads
    before -Post.

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
    Issue numbers held out by hand, beside or instead of -LivePushRecord.

.PARAMETER LivePushRecord
    The live-push record live-preflight wrote, as edited for what was held back. An issue whose PR changed
    a 'hold' path is not told.

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
    [string]$LivePushRecord = '',
    [string]$Repo = '',
    [string]$AsanaPat = $env:ASANA_PAT,
    [string]$RootOverride = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Captured before the repo's own config is dot-sourced below: repo-config.ps1 is the consumer's, and it
# may bind any name it likes -- the guard prepare-release.ps1 keeps for the same reason.
$VersionArg = $Version; $SinceArg = $SinceTag; $PostArg = [bool]$Post; $SkipArg = @($SkipIssue)
$RepoArg = $Repo; $PatArg = $AsanaPat; $RootArg = $RootOverride; $RecordArg = $LivePushRecord

. (Join-Path $PSScriptRoot '..\lib\repo-root-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\git-porcelain-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\live-push-rules.ps1')
. (Join-Path $PSScriptRoot '..\lib\live-record-lib.ps1')
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

# THE RECORD, READ BEFORE ANYTHING ELSE IS ASKED (#3176). A record that cannot be read is a refusal, not a
# run without it: the person passed it to hold something back, and a run that ignored it would tell them.
$record = $null
if (([string]$RecordArg).Trim()) {
    try {
        $record = ConvertFrom-LivePushRecord -Text ([System.IO.File]::ReadAllText(([string]$RecordArg).Trim()))
    } catch {
        Write-Host "[ERROR] The live-push record could not be read ($($_.Exception.GetType().Name)) -- fix it or pass the right file. Nothing was written." -ForegroundColor Red
        exit 1
    }
    Write-Host "      live-push record -- $(@($record.Live).Count) live, $(@($record.Hold).Count) held" -ForegroundColor Cyan
} else {
    Write-Host '      no -LivePushRecord: a file held back from the push, or an app deploy not run, is not seen -- hold its issue out with -SkipIssue' -ForegroundColor Yellow
}

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
# Per issue, from the record: how many of its PRs' paths are held, or -1 where a PR's files could not be read.
$heldCount = @{}
$prsKept = 0
# Per named number: $true an issue, $false a pull request, $null unread -- asked once per run.
$isIssue = @{}
foreach ($n in @(Get-ReleaseRangePullNumbers -Subjects $subjects.Lines)) {
    $pr = Invoke-Native { gh pr view "$n" --repo $repoName --json number,state,mergeCommit,closingIssuesReferences,files,changedFiles,headRefName,body }
    if ($pr.Code -ne 0) { continue }   # an issue's number, or a PR of another repo: not this release's PR
    try { $j = ($pr.Lines -join "`n") | ConvertFrom-Json } catch { $readFailures++; Write-Host "  PR #$n -- its reply did not parse" -ForegroundColor Yellow; continue }
    $oid = if ($j.mergeCommit) { [string]$j.mergeCommit.oid } else { '' }
    if ([string]$j.state -ne 'MERGED' -or -not $oid -or -not $rangeShas.Contains($oid)) { continue }
    $prsKept++
    $prHeld = 0
    if ($record) {
        # The merge against its first parent, joined with gh's file list for the PR: the diff alone is only the
        # last commit of a rebase-merge (#3190). Get-PullChangedPaths says when the two together are not whole.
        # core.quotePath forced on, so a path above 0x7F is decoded here rather than by the console code page.
        $diff = Invoke-Native { git -C $repoRoot -c core.quotePath=true diff --no-renames --name-only "$oid^1" $oid }
        $parents = Invoke-Native { git -C $repoRoot rev-list --parents -n 1 $oid }
        if ($diff.Code -ne 0 -or $parents.Code -ne 0) {
            $prHeld = -1
        } else {
            $changed = Get-PullChangedPaths `
                -DiffPaths @($diff.Lines | Where-Object { $_.Trim() } | ForEach-Object { Convert-GitQuotedPath -Path $_ }) `
                -PullFiles @(@($j.files) | Where-Object { $_ } | ForEach-Object { [string]$_.path }) `
                -ChangedFiles ([int]$j.changedFiles) `
                -ParentCount (@((@($parents.Lines) | Select-Object -First 1) -split '\s+' | Where-Object { $_ }).Count - 1)
            $prHeld = if ($changed.Complete) { @((Get-EntryLiveState -ChangedPaths $changed.Paths -Record $record).HeldPaths).Count } else { -1 }
        }
    }
    # THE ISSUES IT CARRIED, NOT ONLY THE ONES IT CLOSED (#3498): a -NoResolves PR closes nothing, so its
    # branch and its body are read too. A named number is kept only once GitHub says it is an issue.
    $cand = Get-PullIssueCandidates -PullNumber $n `
        -ClosingNumbers @(@($j.closingIssuesReferences | Where-Object { $_ }) | ForEach-Object { [int]$_.number }) `
        -HeadRefName ([string]$j.headRefName) -Body ([string]$j.body)
    $carried = @($cand.Closing)
    foreach ($m in @($cand.Named)) {
        if (-not $isIssue.ContainsKey($m)) {
            # The issues endpoint answers a PR too, with a pull_request field. A filter with no double
            # quote in it, so Windows PowerShell 5.1's native argument quoting has nothing to mangle.
            $kind = Invoke-Native { gh api "repos/$repoName/issues/$m" --jq '.pull_request == null' }
            $answer = (@($kind.Lines) -join '').Trim()
            $isIssue[$m] = if ($kind.Code -ne 0 -or $answer -notin @('true', 'false')) { $null } else { $answer -eq 'true' }
            if ($null -eq $isIssue[$m]) { $readFailures++; Write-Host "  #$m  UNREAD   PR #$n names it, and GitHub could not say whether it is an issue -- not told" -ForegroundColor Yellow }
        }
        if ($isIssue[$m]) { $carried += $m }
    }
    foreach ($num in $carried) {
        if (-not $issueNumbers.Contains($num)) { $issueNumbers.Add($num); $heldCount[$num] = 0 }
        if ($prHeld -lt 0 -or $heldCount[$num] -lt 0) { $heldCount[$num] = -1 } else { $heldCount[$num] += $prHeld }
    }
}
Write-Host "[2/5] pull requests -- $prsKept merged in the range, carrying $($issueNumbers.Count) issue(s)" -ForegroundColor Cyan

# === 3/5 + 4/5 -- the issues and the verdict =======================================================
Write-Host '[3/5] issues, [4/5] verdict' -ForegroundColor Cyan
$owed = @()
foreach ($num in $issueNumbers) {
    if ($SkipArg -contains $num) { Write-Host "  #$num  held     -SkipIssue" -ForegroundColor DarkGray; continue }
    if ($heldCount[$num] -lt 0) {
        $readFailures++
        Write-Host "  #$num  UNREAD   a merge that closed it could not be read against the live-push record -- not told" -ForegroundColor Yellow
        continue
    }
    if ($heldCount[$num] -gt 0) { Write-Host "  #$num  held     $($heldCount[$num]) of its file(s) are 'hold' in the live-push record" -ForegroundColor DarkGray; continue }
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
