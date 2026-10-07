<#
.SYNOPSIS
    SessionStart hook of bwj-development: in a store repo, says when the asana-closed-message workflow
    is missing, differs from the template this plugin ships, or has no ASANA_PAT secret to run with.

.DESCRIPTION
    WHY THIS EXISTS (inbound #2871, October 7, 2026). The closed and reopened messages on the Asana task
    are posted by a CI workflow the store COPIES from templates/ (adopt-bwj-development step 1), because
    GitHub runs a workflow only from the repo's own .github/. A copy is the one delivery a plugin update
    cannot make: measured in BWJ-Development/smartwatchbanden, the two files had never been copied and
    the repo had no ASANA_PAT, so from the retirement of asana-mirror (#2804) onwards neither message
    posted there, and nothing said so until a reopen went unanswered. The same gap opens again after
    every template change (#2870) for a store that does not re-copy.

    WHAT IT CHECKS, in the two Shopify store repos only (smartwatchbanden, xoxowildhearts -- the list
    adopt-bwj-development copies the workflow into; matched on the origin's repo NAME for the reason
    report-issue gives, the two stores are not in one organisation):
      1. .github/workflows/asana-closed-message.yml and .github/scripts/asana-closed-message.ps1 exist;
      2. each is identical to its template, line endings aside -- git may check a file out with CRLF;
      3. an ASANA_PAT secret is visible to the repo, as a repo secret or an organisation secret.
    Anywhere else it is silent: dkj-claude-plugins and phone-factory run the ticket chapter without
    this workflow.

    A SECRET IT CANNOT READ IS NOT A MISSING SECRET. Listing secrets needs more than read access, and
    gh may be absent or offline. Any failed read leaves finding 3 out, rather than reporting a gap
    that may not exist.

    IT NEVER BLOCKS. Always exit 0, and silent when everything is in place, like every session check in
    this family. A finding is an [ERROR] line because that is what the family forwards to the transcript.

    Read-only: it reads two files, two templates, the origin URL and (through gh) two secret NAME lists.

.PARAMETER RepoRootOverride
    (For tests) The repo root to check instead of CLAUDE_PROJECT_DIR or the working directory.

.PARAMETER TemplateRootOverride
    (For tests) The folder holding the two templates instead of ${CLAUDE_PLUGIN_ROOT}/templates.

.PARAMETER RepoSlugOverride
    (For tests) 'owner/name' instead of the one read from the origin URL.

.PARAMETER SecretNamesOverride
    (For tests) The secret names visible to the repo, instead of asking gh. Pass the single value
    '<unreadable>' to stand for a read that failed.

    Pure ASCII (repo convention for .ps1).
#>
[CmdletBinding()]
param(
    [string]$RepoRootOverride = '',
    [string]$TemplateRootOverride = '',
    [string]$RepoSlugOverride = '',
    [string[]]$SecretNamesOverride = $null
)

Set-StrictMode -Version Latest

$StoreRepos = @('smartwatchbanden', 'xoxowildhearts')
$Unreadable = '<unreadable>'

function Get-OriginSlug {
    param([string]$Root)
    # Captured whole, never piped into Select-Object -First: that stops the pipeline, which can end git
    # before it exits and leave a non-zero $LASTEXITCODE beside a good URL. Measured in this hook's own
    # suite, where the store went unrecognised on one run in two.
    $out = @(& git -C $Root remote get-url origin 2>$null)
    if ($LASTEXITCODE -ne 0 -or $out.Count -lt 1) { return '' }
    $url = [string]$out[0]
    $m = [regex]::Match([string]$url, 'github\.com[:/]([A-Za-z0-9-]+)/([A-Za-z0-9._-]+?)(\.git)?/?$')
    if (-not $m.Success) { return '' }
    return "$($m.Groups[1].Value)/$($m.Groups[2].Value)"
}

function Get-VisibleSecretNames {
    <# Repo secrets plus the organisation secrets shared with the repo, or $null when either read fails. #>
    param([string]$Slug)
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { return $null }
    $names = @()
    foreach ($path in @("repos/$Slug/actions/secrets", "repos/$Slug/actions/organization-secrets")) {
        $out = & gh api $path --jq '.secrets[].name' 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
        $names += @($out | Where-Object { $_ })
    }
    return , $names
}

function Get-NormalizedText {
    param([string]$Path)
    return ([System.IO.File]::ReadAllText($Path) -replace "`r`n", "`n")
}

try {
    $root = if ($RepoRootOverride) { $RepoRootOverride }
            elseif ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR }
            else { (Get-Location).Path }
    $templates = if ($TemplateRootOverride) { $TemplateRootOverride }
                 elseif ($env:CLAUDE_PLUGIN_ROOT) { Join-Path $env:CLAUDE_PLUGIN_ROOT 'templates' }
                 else { Join-Path $PSScriptRoot '..\templates' }

    $slug = if ($RepoSlugOverride) { $RepoSlugOverride } else { Get-OriginSlug -Root $root }
    if (-not $slug) { exit 0 }
    $name = ($slug -split '/')[-1].ToLowerInvariant()
    if ($StoreRepos -notcontains $name) { exit 0 }

    $remedy = "Run the 'adopt-bwj-development' skill"
    $pairs = @(
        @{ Repo = '.github/workflows/asana-closed-message.yml'; Template = 'asana-closed-message.yml' },
        @{ Repo = '.github/scripts/asana-closed-message.ps1';   Template = 'asana-closed-message.ps1' }
    )
    $missing = @()
    $stale = @()
    foreach ($p in $pairs) {
        $repoFile = Join-Path $root $p.Repo
        $templateFile = Join-Path $templates $p.Template
        if (-not (Test-Path -LiteralPath $repoFile -PathType Leaf)) { $missing += $p.Repo; continue }
        # A template missing from the plugin install is that install's problem, not this repo's: no
        # comparison, and no line blaming the store for it.
        if (-not (Test-Path -LiteralPath $templateFile -PathType Leaf)) { continue }
        if ((Get-NormalizedText $repoFile) -cne (Get-NormalizedText $templateFile)) { $stale += $p.Repo }
    }

    if ($missing.Count -gt 0) {
        Write-Host ("[ERROR] bwj-development: $slug has no $($missing -join ' and '), so closing or " +
            "reopening an issue posts nothing on its Asana task. $remedy (step 1 copies the files).")
    }
    if ($stale.Count -gt 0) {
        Write-Host ("[ERROR] bwj-development: $($stale -join ' and ') in $slug differs from the template " +
            "this plugin version ships, so the Asana task gets an outdated closed or reopened message. " +
            "$remedy (step 1 diffs an existing copy against the template, and taking the difference is " +
            "the maintainer's call).")
    }

    $secrets = if ($null -ne $SecretNamesOverride) { , @($SecretNamesOverride) } else { Get-VisibleSecretNames -Slug $slug }
    $readable = ($null -ne $secrets) -and -not (@($secrets) -contains $Unreadable)
    if ($readable -and -not (@($secrets) -contains 'ASANA_PAT')) {
        Write-Host ("[ERROR] bwj-development: $slug has no ASANA_PAT secret, so the asana-closed-message " +
            "workflow cannot post on the Asana task. The repo's maintainer sets it -- see step 3 of the " +
            "'adopt-bwj-development' skill.")
    }
} catch {
    $safe = (((($_.Exception.Message) -replace '\s+', ' ') -replace '\p{C}', '') -replace '\[', '(') -replace '\]', ')'
    Write-Host ('closed-message-sessioncheck skipped due to an error: ' + $safe.Trim())
}
exit 0
