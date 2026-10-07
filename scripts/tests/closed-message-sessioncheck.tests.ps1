<#
.SYNOPSIS
    Tests for plugins/dkj-policy/bwj-development/hooks/closed-message-sessioncheck.ps1 -- the session check
    that reports a store whose asana-closed-message copy is missing, stale, or has no ASANA_PAT (#2871).

.DESCRIPTION
    What is pinned is WHEN it speaks: only in the two store repos, once per kind of gap, never on a secret
    list it could not read, and never when everything is in place. Each case runs the hook as a child
    process against a scratch fixture, with the repo slug and the secret names passed in, so nothing here
    reads a real origin or calls gh.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Continue'

$RepoRoot  = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Hook      = Join-Path $RepoRoot 'plugins\dkj-policy\bwj-development\hooks\closed-message-sessioncheck.ps1'
$Templates = Join-Path $RepoRoot 'plugins\dkj-policy\bwj-development\templates'
# $PID and a guid in the fixture path: the test gate runs suites in parallel.
$Fixture   = Join-Path ([System.IO.Path]::GetTempPath()) "closed-message-sessioncheck-$PID-$([guid]::NewGuid().ToString('n'))"

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
    else            { $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}

function New-Store {
    <# A store checkout: -Copy places both templates, -Crlf writes them with CRLF, -Stale edits the script. #>
    param([string]$Label, [switch]$Copy, [switch]$Crlf, [switch]$Stale)
    $root = Join-Path $Fixture $Label
    New-Item -ItemType Directory -Force -Path (Join-Path $root '.github\workflows'), (Join-Path $root '.github\scripts') | Out-Null
    if ($Copy) {
        foreach ($p in @(@('asana-closed-message.yml', '.github\workflows'), @('asana-closed-message.ps1', '.github\scripts'))) {
            $text = [System.IO.File]::ReadAllText((Join-Path $Templates $p[0])) -replace "`r`n", "`n"
            if ($Crlf) { $text = $text -replace "`n", "`r`n" }
            if ($Stale -and $p[0] -like '*.ps1') { $text += "`n# an older copy`n" }
            [System.IO.File]::WriteAllText((Join-Path (Join-Path $root $p[1]) $p[0]), $text)
        }
    }
    return $root
}

function Invoke-Hook {
    <# ONE secret name: -File does not split a comma list into a [string[]], so two names would arrive as one. #>
    param([string]$Root, [string]$Slug, [string]$Secret)
    $hookArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Hook,
        '-RepoRootOverride', $Root, '-TemplateRootOverride', $Templates, '-RepoSlugOverride', $Slug,
        '-SecretNamesOverride', $Secret)
    $out = & powershell @hookArgs 2>&1 | ForEach-Object { "$_" }
    return [pscustomobject]@{ Text = ($out -join "`n"); Code = $LASTEXITCODE }
}

try {
    $ok = New-Store -Label 'ok' -Copy
    $r = Invoke-Hook -Root $ok -Slug 'BWJ-Development/smartwatchbanden' -Secret 'ASANA_PAT'
    Assert-True ($r.Text.Trim() -eq '') 'a store with both copies and the secret is silent'
    Assert-True ($r.Code -eq 0) 'and exits 0'

    $crlf = New-Store -Label 'crlf' -Copy -Crlf
    $r = Invoke-Hook -Root $crlf -Slug 'BWJ-Development/smartwatchbanden' -Secret 'ASANA_PAT'
    Assert-True ($r.Text.Trim() -eq '') 'a copy checked out with CRLF is not stale'

    $none = New-Store -Label 'none'
    $r = Invoke-Hook -Root $none -Slug 'BWJ-Development/smartwatchbanden' -Secret 'CLAUDE_CODE_OATH_TOKEN'
    Assert-True ($r.Text -match '\[ERROR\] bwj-development: BWJ-Development/smartwatchbanden has no \.github/workflows/asana-closed-message\.yml and \.github/scripts/asana-closed-message\.ps1') 'the measured case (#2871): both files missing is one finding naming both'
    Assert-True ($r.Text -match 'has no ASANA_PAT secret') 'and the missing secret is its own finding'
    Assert-True ($r.Code -eq 0) 'a finding still exits 0'

    $stale = New-Store -Label 'stale' -Copy -Stale
    $r = Invoke-Hook -Root $stale -Slug 'BWJ-Development/xoxowildhearts' -Secret 'ASANA_PAT'
    Assert-True ($r.Text -match '\.github/scripts/asana-closed-message\.ps1 in BWJ-Development/xoxowildhearts differs from the template') 'a copy that differs from the template is reported'
    Assert-True ($r.Text -notmatch 'workflows/asana-closed-message\.yml in') 'and only the file that differs is named'

    $r = Invoke-Hook -Root $none -Slug 'BWJ-Development/smartwatchbanden' -Secret '<unreadable>'
    Assert-True ($r.Text -notmatch 'ASANA_PAT') 'a secret list it could not read is not reported as a missing secret'

    foreach ($slug in @('DKJ-Solutions/dkj-claude-plugins', 'BWJ-Development/phone-factory', 'someone/else')) {
        # A real list without ASANA_PAT, so silence here can only come from the repo name.
        $r = Invoke-Hook -Root $none -Slug $slug -Secret 'CLAUDE_CODE_OATH_TOKEN'
        Assert-True ($r.Text.Trim() -eq '') "silent outside the two stores: $slug"
    }

    # THE REAL ORIGIN READ, no slug override: an ssh origin naming a store is recognised as that store.
    $ssh = New-Store -Label 'ssh'
    & git -C $ssh init -q 2>$null | Out-Null
    & git -C $ssh remote add origin 'git@github.com:BWJ-Development/smartwatchbanden.git' 2>$null | Out-Null
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Hook -RepoRootOverride $ssh `
        -TemplateRootOverride $Templates -SecretNamesOverride 'ASANA_PAT' 2>&1 | ForEach-Object { "$_" }
    Assert-True (($out -join "`n") -match 'BWJ-Development/smartwatchbanden has no \.github/workflows') 'an ssh origin is read as owner/name and checked as a store'
} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host "closed-message-sessioncheck: $script:pass passed, $script:fail failed"
if ($script:fail -gt 0) { exit 1 }
exit 0
