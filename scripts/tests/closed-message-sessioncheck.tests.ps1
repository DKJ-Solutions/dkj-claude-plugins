<#
.SYNOPSIS
    Tests for plugins/dkj-policy/bwj-development/hooks/closed-message-sessioncheck.ps1 -- the session check
    that reports a store whose asana-closed-message copy is missing, stale, or has no ASANA_PAT (#2871),
    and a store config that states no Get-ResolvesExemptMatchers (#2959).

.DESCRIPTION
    What is pinned is WHEN it speaks: only in the two store repos and, for asana-closed-message alone,
    phone-factory (#3518), once per kind of gap, never on a secret
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

. (Join-Path $PSScriptRoot '..\lib\fixture-git-lib.ps1')

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
        foreach ($p in @(@('asana-closed-message.yml', '.github\workflows'), @('asana-closed-message.ps1', '.github\scripts'),
                         @('asana-prio-label.yml', '.github\workflows'), @('asana-prio-label.ps1', '.github\scripts'))) {
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

    # THE PRIO PAIR (#2945): reported on its own line, and the closed-message pair is not blamed for it.
    $noPrio = New-Store -Label 'no-prio' -Copy
    Remove-Item -LiteralPath (Join-Path $noPrio '.github\workflows\asana-prio-label.yml'), (Join-Path $noPrio '.github\scripts\asana-prio-label.ps1')
    $r = Invoke-Hook -Root $noPrio -Slug 'BWJ-Development/smartwatchbanden' -Secret 'ASANA_PAT'
    Assert-True ($r.Text -match '\[ERROR\] bwj-development: BWJ-Development/smartwatchbanden has no \.github/workflows/asana-prio-label\.yml and \.github/scripts/asana-prio-label\.ps1') 'a store missing only the prio pair is reported, naming that pair'
    Assert-True ($r.Text -notmatch 'asana-closed-message') 'and the closed-message pair, which is in place, is not named'
    Assert-True ($r.Code -eq 0) 'a finding still exits 0'

    $stalePrio = New-Store -Label 'stale-prio' -Copy
    [System.IO.File]::AppendAllText((Join-Path $stalePrio '.github\scripts\asana-prio-label.ps1'), "`n# an older copy`n")
    $r = Invoke-Hook -Root $stalePrio -Slug 'BWJ-Development/xoxowildhearts' -Secret 'ASANA_PAT'
    Assert-True ($r.Text -match '\.github/scripts/asana-prio-label\.ps1 in BWJ-Development/xoxowildhearts differs from the template') 'a prio script that differs from the template is reported'
    Assert-True ($r.Text -notmatch 'asana-closed-message' -and $r.Text -notmatch 'workflows/asana-prio-label\.yml in') 'and only that file is named'

    # THE RESOLVES-EXEMPT SEAM (#2959): a store config without Get-ResolvesExemptMatchers is reported; one
    # that defines it, or a store with no repo-config at all (every case above), is not.
    $noSeam = New-Store -Label 'no-seam' -Copy
    New-Item -ItemType Directory -Force -Path (Join-Path $noSeam 'scripts') | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $noSeam 'scripts\repo-config.ps1'),
        "function Get-RepoName { 'BWJ-Development/xoxowildhearts' }`n# function Get-ResolvesExemptMatchers { @() }`n")
    $r = Invoke-Hook -Root $noSeam -Slug 'BWJ-Development/xoxowildhearts' -Secret 'ASANA_PAT'
    Assert-True ($r.Text -match '\[ERROR\] bwj-development: BWJ-Development/xoxowildhearts states no Get-ResolvesExemptMatchers') 'the measured case (#2959): a store config without the seam is reported'
    Assert-True ($r.Text -match 'step 2 proposes the two matchers') 'and the finding names the adopt step that proposes it'
    Assert-True (@($r.Text -split "`n" | Where-Object { $_ -match '\[ERROR\]' }).Count -eq 1) 'a commented-out definition does not count, and nothing else is blamed'
    Assert-True ($r.Code -eq 0) 'a finding still exits 0'

    $seam = New-Store -Label 'seam' -Copy
    New-Item -ItemType Directory -Force -Path (Join-Path $seam 'scripts') | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $seam 'scripts\repo-config.ps1'),
        "function Get-RepoName { 'BWJ-Development/smartwatchbanden' }`r`n    function Get-ResolvesExemptMatchers {`r`n    return @()`r`n}`r`n")
    $r = Invoke-Hook -Root $seam -Slug 'BWJ-Development/smartwatchbanden' -Secret 'ASANA_PAT'
    Assert-True ($r.Text.Trim() -eq '') 'a store config that defines the seam (indented, CRLF) is silent'

    [System.IO.File]::WriteAllText((Join-Path $seam 'scripts\repo-config.ps1'), "function global:Get-ResolvesExemptMatchers { @() }`n")
    $r = Invoke-Hook -Root $seam -Slug 'BWJ-Development/smartwatchbanden' -Secret 'ASANA_PAT'
    Assert-True ($r.Text.Trim() -eq '') 'a scope-prefixed definition counts as stated'

    [System.IO.File]::WriteAllText((Join-Path $seam 'scripts\repo-config.ps1'), "function Get-ResolvesExemptMatchers-Old { @() }`n")
    $r = Invoke-Hook -Root $seam -Slug 'BWJ-Development/smartwatchbanden' -Secret 'ASANA_PAT'
    Assert-True ($r.Text -match 'states no Get-ResolvesExemptMatchers') 'a longer name that merely starts with the seam''s does not'

    $r = Invoke-Hook -Root $noSeam -Slug 'DKJ-Solutions/dkj-claude-plugins' -Secret 'ASANA_PAT'
    Assert-True ($r.Text.Trim() -eq '') 'and the seam is not asked of a repo that copies no workflow'

    $r = Invoke-Hook -Root $none -Slug 'BWJ-Development/smartwatchbanden' -Secret '<unreadable>'
    Assert-True ($r.Text -notmatch 'ASANA_PAT') 'a secret list it could not read is not reported as a missing secret'

    foreach ($slug in @('DKJ-Solutions/dkj-claude-plugins', 'someone/else')) {
        # A real list without ASANA_PAT, so silence here can only come from the repo name.
        $r = Invoke-Hook -Root $none -Slug $slug -Secret 'CLAUDE_CODE_OATH_TOKEN'
        Assert-True ($r.Text.Trim() -eq '') "silent outside the repos that copy a workflow: $slug"
    }

    # PHONE-FACTORY (#3518): adopted asana-closed-message alone, so that pair, the secret and the seam are
    # checked there, and the prio pair, which was not decided there, never is.
    $r = Invoke-Hook -Root $none -Slug 'BWJ-Development/phone-factory' -Secret 'CLAUDE_CODE_OATH_TOKEN'
    Assert-True ($r.Text -match 'phone-factory has no \.github/workflows/asana-closed-message\.yml and \.github/scripts/asana-closed-message\.ps1') 'phone-factory without the closed-message pair is reported'
    Assert-True ($r.Text -match 'phone-factory has no ASANA_PAT secret, so the asana-closed-message workflow cannot post on the Asana task\.') 'and its missing secret names the closed-message workflow alone'
    Assert-True ($r.Text -notmatch 'asana-prio-label') 'and the prio pair is never asked of it'

    $pf = New-Store -Label 'phone-factory' -Copy
    Remove-Item -LiteralPath (Join-Path $pf '.github\workflows\asana-prio-label.yml'), (Join-Path $pf '.github\scripts\asana-prio-label.ps1')
    $r = Invoke-Hook -Root $pf -Slug 'BWJ-Development/phone-factory' -Secret 'ASANA_PAT'
    Assert-True ($r.Text.Trim() -eq '') 'phone-factory with the closed-message pair and the secret is silent'

    $r = Invoke-Hook -Root $noSeam -Slug 'BWJ-Development/phone-factory' -Secret 'ASANA_PAT'
    Assert-True ($r.Text -match 'phone-factory states no Get-ResolvesExemptMatchers') 'and a phone-factory config without the seam is reported'
    Assert-True ($r.Text -notmatch 'asana-prio-label') 'without blaming the prio pair the fixture also holds'

    # THE REAL ORIGIN READ, no slug override: an ssh origin naming a store is recognised as that store.
    $ssh = New-Store -Label 'ssh'
    Invoke-FixtureGitIn $ssh init -q
    Invoke-FixtureGitIn $ssh remote add origin 'git@github.com:BWJ-Development/smartwatchbanden.git'
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Hook -RepoRootOverride $ssh `
        -TemplateRootOverride $Templates -SecretNamesOverride 'ASANA_PAT' 2>&1 | ForEach-Object { "$_" }
    Assert-True (($out -join "`n") -match 'BWJ-Development/smartwatchbanden has no \.github/workflows') 'an ssh origin is read as owner/name and checked as a store'
} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host "closed-message-sessioncheck: $script:pass passed, $script:fail failed"
# A BROKEN FIXTURE FAILS THE RUN (#1635): the ssh case reads a repo git init had to build.
$fixtureBroken = Write-FixtureGitSummary -Subject 'closed-message-sessioncheck.ps1'
if ($script:fail -gt 0 -or $fixtureBroken) { exit 1 }
exit 0
