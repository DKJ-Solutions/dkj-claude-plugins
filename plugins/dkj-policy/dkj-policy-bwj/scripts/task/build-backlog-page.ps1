<#
.SYNOPSIS
    Build the minor-backlog page: the open issues carrying the reach label, with the colleague-facing
    text their mirrored Asana tasks already carry, rendered into one HTML file.

.DESCRIPTION
    Issue #1979, the builder split out of #1977 (the shared BWJ pages worker). publish-page.ps1
    already routes and publishes the 'backlog' kind -- what was missing was the thing that writes
    minor-backlog.html in the first place. This script is that thing, and it stops at the file: a
    second, separate, non-model-invocable step (publish-page.ps1 -Kind backlog) sends it out.

    WHOSE TEXT RENDERS -- decided on the issue before this was written (Dave, September 14, 2026):
    the ASANA VARIANT, never the raw GitHub issue. The issue is written for a developer; the mirrored
    Asana task is the colleague-facing translation report-issue's skeleton already produces. So this
    script reads, per open issue carrying the reach label, which Asana task the marker
    ('<!-- asana-task: <gid> -->') names, and shows that task's Name and Notes -- not the issue's own
    title and body. An issue with no mirrored task yet contributes nothing to the page rather than
    falling back to its own (wrong-register) text; see backlog-page-rules.ps1's header for the second
    half of that decision (a completed or unreadable task is dropped, never shown broken).

    WHY THIS PLUGIN'S FUNCTIONS AND NOT A FRESH COPY. Resolving which Asana task an issue body names,
    and reading that task's fields, are exactly what report-issue's own marker and the asana-mirror CI
    sweep already do -- so this script dot-sources ../../templates/asana-mirror.ps1 for
    Resolve-AsanaTaskRef and Get-AsanaTaskState rather than re-implementing either. That file
    documents itself as safe to dot-source for its pure helpers alone (its main flow runs only when
    invoked directly, guarded by $MyInvocation.InvocationName), which is exactly what
    scripts/tests/dkj-policy-bwj.tests.ps1 already relies on to exercise it.

    THE ASANA-MIRROR TEMPLATE'S OWN PARAMETERS ARE NOT THIS SCRIPT'S. Dot-sourcing a param()-bearing
    file binds its parameters fresh in the CALLING scope, so this script's own -Repo and -AsanaPat
    values are captured into differently-named local variables BEFORE that dot-source runs -- $StoreRepo
    and $Pat -- so the template's own defaults (empty $Repo, $env:ASANA_PAT again into $AsanaPat, '.'
    into $RepoRoot) cannot silently overwrite anything this script already resolved.

    WHAT IT NEVER DOES: write to GitHub or to Asana. Every gh call is a read (repo view, issue list);
    every Asana call is a read (GET a task). The one write in this whole flow is the local HTML file,
    which is why -- unlike publish-page.ps1, which sends that file out from behind a private repo's
    walls -- this script is left model-invocable: nothing here leaves the checkout.

    A FAILED ISSUE LISTING THROWS RATHER THAN PRODUCING AN EMPTY PAGE. asana-mirror.ps1's own
    Get-OpenIssues returns @() on a gh failure, correctly, because it drives a best-effort CI sweep
    where a skipped run costs nothing. This script produces the one artifact a colleague reads, and an
    empty page from a broken 'gh issue list' reads as "nothing outstanding" -- which is the one answer
    this script must never give by accident. So Get-BacklogOpenIssues throws instead of swallowing.

    Pure ASCII (repo convention for .ps1).

.PARAMETER Repo
    The store repo, 'owner/repo'. Defaults to GITHUB_REPOSITORY, then to what 'gh repo view' resolves
    from the current checkout.

.PARAMETER AsanaPat
    Read from ASANA_PAT by default. Needed only when at least one issue carries a mirrored Asana task
    to read -- an empty backlog, or one where every issue still lacks its marker, never asks for it.

.PARAMETER Html
    Where to write the page. Defaults to minor-backlog.html in the page directory
    publish-page.ps1 already derives from Get-ReleaseNoteRoot (<note root>/../page) -- the same file
    that script's own 'backlog' default reads.

.PARAMETER DryRun
    Resolve everything, print what would be written and how many entries it holds -- write nothing.
    Still reads gh and Asana: previewing what would be built means actually building it, unlike
    publish-page.ps1's own -DryRun, which stops before the network half (the upload) and needs none
    of it.

.PARAMETER RootOverride
    The repo root, when this is not run from inside the checkout.

.EXAMPLE
    ./build-backlog-page.ps1
    Builds minor-backlog.html from this repo's open, reach-labelled issues.

.EXAMPLE
    ./build-backlog-page.ps1 -DryRun
    Shows what would be built -- entry count, skips and their reasons, the output path -- without
    writing anything or requiring ASANA_PAT unless a task actually needs reading.
#>
[CmdletBinding()]
param(
    [string]$Repo,
    [string]$AsanaPat = $env:ASANA_PAT,
    [string]$Html,
    [switch]$DryRun,
    [string]$RootOverride
)

$ErrorActionPreference = 'Stop'

# Captured BEFORE the template dot-source below rebinds $Repo/$AsanaPat/$RepoRoot to its own defaults
# -- see the .DESCRIPTION's "THE ASANA-MIRROR TEMPLATE'S OWN PARAMETERS" paragraph.
$StoreRepo    = if ($Repo) { $Repo } else { $env:GITHUB_REPOSITORY }
$Pat          = $AsanaPat
$HtmlOverride = $Html
$RootArg      = $RootOverride

. (Join-Path $PSScriptRoot '..\..\templates\asana-mirror.ps1')
. (Join-Path $PSScriptRoot '..\lib\backlog-page-rules.ps1')
. (Join-Path $PSScriptRoot '..\lib\repo-root-lib.ps1')

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

try {
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch { }

# --- The repo root ----------------------------------------------------------------------------------
# Resolve-BwjRepoRoot, dot-sourced above from repo-root-lib.ps1 -- shared with publish-page.ps1
# rather than carried here as a second, private copy of the same function.
$root = Resolve-BwjRepoRoot -Override $RootArg

# --- The repo's own answers: Get-ReachLabel, Get-ReleaseNoteRoot -------------------------------------
# Read in a child scope with StrictMode explicitly off: repo-config.ps1 is written on the assumption
# its callers do not run under StrictMode Latest. This script never turns StrictMode on itself --
# unlike publish-page.ps1, which runs under -Version Latest throughout and only relaxes it here --
# because it dot-sources templates/asana-mirror.ps1 for Resolve-AsanaTaskRef/Get-AsanaTaskState, and
# that file was not written against strict mode. The explicit -Off here is kept anyway: it documents
# the same assumption about repo-config.ps1 that publish-page.ps1 states, rather than relying on it
# being ambient.
$config = & {
    Set-StrictMode -Off
    $answers = @{ ReachLabel = 'minor'; NoteRoot = 'releases/notes' }
    $configPath = Join-Path $args[0] 'scripts\repo-config.ps1'
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        throw ("This repo has no scripts\repo-config.ps1, so it has answered neither which label " +
               "marks the backlog nor where its release documents live. Run adopt-dkj-policy-bwj.")
    }
    . $configPath
    $defined = { param($Name) [bool](@($ExecutionContext.InvokeCommand.GetCommands($Name, 'Function', $false)).Count) }
    if (& $defined 'Get-ReachLabel')      { $answers.ReachLabel = Get-ReachLabel }
    if (& $defined 'Get-ReleaseNoteRoot') { $answers.NoteRoot   = Get-ReleaseNoteRoot }
    return $answers
} $root

# --- The store repo, 'owner/repo' ---------------------------------------------------------------------
function Get-BacklogRepoName {
    <# What 'gh repo view' resolves the current checkout to, or $null when it cannot. #>
    $ErrorActionPreference = 'Continue'
    $raw = (& gh repo view --json nameWithOwner --jq '.nameWithOwner') 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $raw) { return $null }
    return (@($raw)[0]).Trim()
}
if (-not $StoreRepo) { $StoreRepo = Get-BacklogRepoName }
if (-not $StoreRepo) {
    throw ("Could not resolve the store repo. Pass -Repo <owner/repo>, set GITHUB_REPOSITORY, or run " +
           "this from inside the store repo's checkout with 'gh' authenticated.")
}

Write-Host ""
Write-Host "== build-backlog-page ($StoreRepo) ==" -ForegroundColor Cyan
Write-Host "  reach label : $($config.ReachLabel)" -ForegroundColor DarkGray

# --- The open issues carrying the reach label -----------------------------------------------------
function Get-BacklogOpenIssues {
    <#
        This repo's open issues carrying $Label, with title/url/body/labels. THROWS on a gh failure --
        see the .DESCRIPTION's "A FAILED ISSUE LISTING THROWS" paragraph for why this differs from
        asana-mirror.ps1's own best-effort Get-OpenIssues.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $ErrorActionPreference = 'Continue'
    $raw = (& gh issue list --repo $Repo --state open --label $Label `
                --json number,title,url,body,labels --limit 500) 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw ("'gh issue list --repo $Repo --label $Label' failed. Check 'gh auth status' and that " +
               "the '$Label' label exists in this repo.")
    }
    if (-not $raw) { return @() }
    return @(($raw | Out-String) | ConvertFrom-Json)
}
$issues = Get-BacklogOpenIssues -Repo $StoreRepo -Label $config.ReachLabel
Write-Host "  open, reach-labelled : $($issues.Count)" -ForegroundColor DarkGray

# --- Resolve each issue's mirrored Asana task and read its colleague-facing text --------------------
$entries = @()
$skipped = @()
foreach ($issue in $issues) {
    $ref = Resolve-AsanaTaskRef -IssueBody ([string]$issue.body)
    if (-not $ref.Gid) {
        $skipped += "#$($issue.number) -- $($ref.Source): no mirrored Asana task found"
        continue
    }
    if (-not $Pat) {
        throw ("ASANA_PAT is not set (environment or -AsanaPat), and issue #$($issue.number) has a " +
               "mirrored Asana task to read. It is read from the environment and from nowhere else, " +
               "the same rule publish-page.ps1 holds CLOUDFLARE_API_TOKEN to.")
    }
    $task = Get-AsanaTaskState -Gid $ref.Gid -Pat $Pat -OptFields 'name,notes,completed'
    if ($null -eq $task) {
        $skipped += "#$($issue.number) -- Asana task $($ref.Gid) is not readable with this token"
        continue
    }
    if ($task.completed) {
        $skipped += "#$($issue.number) -- Asana task $($ref.Gid) is already marked complete in Asana"
        continue
    }
    # NO FALLBACK TO $issue.title. An Asana task with an empty Name (an editable, API-permitted
    # state) is dropped exactly like an unreadable or completed one -- never patched with the
    # GitHub issue's own developer-facing title. That fallback existed here once and was the one
    # path this design's "never the issue's own text" rule did not actually hold; the review chain
    # caught it before it shipped.
    if (-not [string]$task.name) {
        $skipped += "#$($issue.number) -- Asana task $($ref.Gid) has no Name to show"
        continue
    }
    $labelNames = @($issue.labels | ForEach-Object { [string]$_.name })
    $entries += [pscustomobject]@{
        Number   = [int]$issue.number
        Title    = [string]$task.name
        Notes    = [string]$task.notes
        PrioRank = (Get-IssuePrioRank -Labels $labelNames)
    }
}

Write-Host "  entries on the page  : $($entries.Count)" -ForegroundColor DarkGray
if ($skipped.Count -gt 0) {
    Write-Host "  skipped ($($skipped.Count)):" -ForegroundColor Yellow
    foreach ($s in $skipped) { Write-Host "    $s" -ForegroundColor Yellow }
}

# --- The page -----------------------------------------------------------------------------------------
$repoLabel = ([string]$StoreRepo -split '/')[-1]
$html = Get-BacklogPageHtml -Entries $entries -RepoLabel $repoLabel

# --- Where it goes: the SAME page directory publish-page.ps1 derives (<note root>/../page), so a
# straight 'publish-page.ps1 -Kind backlog' afterwards finds it with no -Html needed on either side.
$noteRoot = Join-Path $root ($config.NoteRoot -replace '/', '\')
$pageDir  = Join-Path (Split-Path -Parent $noteRoot) 'page'
$outPath  = if ($HtmlOverride) { $HtmlOverride } else { Join-Path $pageDir 'minor-backlog.html' }

$bytes = $Utf8NoBom.GetByteCount($html)
if ($DryRun) {
    Write-Host ""
    Write-Host "  -DryRun: nothing was written. Would write $([math]::Round($bytes / 1KB)) KB to $outPath" -ForegroundColor Yellow
    exit 0
}

if (-not (Test-Path -LiteralPath $pageDir)) { New-Item -ItemType Directory -Force -Path $pageDir | Out-Null }
[System.IO.File]::WriteAllText($outPath, $html, $Utf8NoBom)

Write-Host ""
Write-Host "  page : $outPath ($([math]::Round($bytes / 1KB)) KB)" -ForegroundColor Green
Write-Host "  Next: publish-page.ps1 -Kind backlog" -ForegroundColor Cyan
exit 0
