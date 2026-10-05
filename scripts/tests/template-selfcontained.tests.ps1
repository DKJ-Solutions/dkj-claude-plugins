<#
.SYNOPSIS
    Every function a shipped TEMPLATE calls is one it defines, one PowerShell provides, or one it
    guards with Get-Command before calling.

.DESCRIPTION
    Dependency-free: no Pester, only PowerShell. Exit 0 if everything passes, 1 on a failure.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/template-selfcontained.tests.ps1

    WHY A TEMPLATE AND NOT EVERY SCRIPT. A template is copied wholesale into a consumer's .github/
    and run there by CI. It dot-sources none of this repo's libraries -- it cannot, because none of
    them travel with it -- so a call to a helper it does not define is unresolvable by construction.
    Every other .ps1 here loads scripts/lib/*, and flagging their imported functions would be noise.

    WHAT IT COST TO NOT HAVE THIS, inbound #1556. A rename in fa3a4e55 turned Get-IssueClosure into
    Get-IssueLinkState and updated the event call site but not the sweep's, and the sweep is the half
    that only reaches the call WHEN IT HAS SOMETHING TO SAY. So the consumer's Actions tab filled with
    green event runs and green empty sweeps, and the first sweep with real work to do died on it --
    taking the prio-label and stage sweeps down with it, since Invoke-ReconcileMode aborts at the
    first crash. Nothing executes the template end to end during its own release, which is why a
    parse-time check is the only thing that could have caught it here rather than there.

    THE Get-Command GUARD IS THE DECLARATION OF AN EXTERNAL SEAM, and reading it is what keeps this
    check free of an allowlist. The retired asana-mirror.ps1 (its subject until October 5, 2026; the suite came back with asana-closed-message.ps1, #2818) legitimately called Get-AsanaStageMap and
    Get-GithubStatusMap, which live in the CONSUMER's scripts/repo-config.ps1 and are dot-sourced at
    run time -- and it tests for each with `Get-Command -Name '<name>'` immediately before calling it,
    because a consumer that defines neither must still get a working run. That guard is already the
    template's own discipline; this check simply believes it. A hand-maintained exemption list would
    go stale the first time a seam was added, in exactly the silent direction.

    ONLY HYPHENATED NAMES ARE JUDGED. `gh` and `git` are external executables whose presence says
    nothing about the template's correctness, and resolving them would make the suite fail on a
    machine that merely lacks the CLI. Every function this defect class can produce is Verb-Noun.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path

$script:pass = 0
$script:fail = 0

function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    if ($Expected -eq $Actual) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red
    }
}

function Get-UnresolvedTemplateCall {
    <#
        The names a script calls that nothing can answer: not defined in the file, not a command this
        PowerShell has, and not guarded by a Get-Command test in the file itself. Returns a sorted
        array of names -- empty is the passing answer. Never throws on a parse error; a file that does
        not parse returns $null, which the caller reports as its own failure rather than as zero
        findings.
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        (Resolve-Path -LiteralPath $Path).Path, [ref]$null, [ref]$errors)
    if ($errors -and $errors.Count -gt 0) { return $null }

    $defined = @($ast.FindAll({
        param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
        ForEach-Object { $_.Name })

    $commands = @($ast.FindAll({
        param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true))

    # The seams the file declares by testing for them. A `Get-Command -Name 'X'` anywhere in the file
    # covers X everywhere in it: the guard and the call it protects are frequently in different
    # functions, and pairing them would be a dataflow analysis for no extra safety.
    $guarded = @($commands | Where-Object { $_.GetCommandName() -eq 'Get-Command' } | ForEach-Object {
        $_.CommandElements | Where-Object {
            $_ -is [System.Management.Automation.Language.StringConstantExpressionAst] } |
            ForEach-Object { $_.Value }
    })

    $called = @($commands | ForEach-Object { $_.GetCommandName() } |
        Where-Object { $_ -and $_ -like '*-*' } | Sort-Object -Unique)

    # `,@(...)`, not `@(...)`: PowerShell unrolls a returned empty array to nothing, so a clean file
    # would hand the caller $null -- indistinguishable from the parse failure above, and in the
    # direction that turns a passing template into a reported one.
    return ,@($called | Where-Object {
        $defined -notcontains $_ -and
        $guarded -notcontains $_ -and
        -not (Get-Command -Name $_ -ErrorAction SilentlyContinue)
    })
}

Write-Host "== template-selfcontained ==" -ForegroundColor Cyan

# --- the checker itself, on fixtures -------------------------------------------------------------
# Asserted before the tree, so a green run on the real templates is evidence rather than a tautology:
# a checker that found nothing anywhere would pass the section below in silence.
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("tmpl-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
    $bad = Join-Path $tmp 'bad.ps1'
    Set-Content -LiteralPath $bad -Encoding ASCII -Value @(
        'function Invoke-Thing { Get-VanishedHelper -Repo x }'
        'Invoke-Thing')
    Assert-Equal 'Get-VanishedHelper' ((Get-UnresolvedTemplateCall -Path $bad) -join ',') `
        'a call to a helper nothing defines is reported -- inbound #1556 in miniature'

    $good = Join-Path $tmp 'good.ps1'
    Set-Content -LiteralPath $good -Encoding ASCII -Value @(
        'function Invoke-Thing { Get-Item . | Out-Null; Invoke-Helper }'
        'function Invoke-Helper { }'
        'Invoke-Thing')
    Assert-Equal '' ((Get-UnresolvedTemplateCall -Path $good) -join ',') `
        'a helper the file defines, and a real cmdlet, are both resolved'

    $seam = Join-Path $tmp 'seam.ps1'
    Set-Content -LiteralPath $seam -Encoding ASCII -Value @(
        '. "$PSScriptRoot/repo-config.ps1"'
        "if (Get-Command -Name 'Get-RepoSeam' -ErrorAction SilentlyContinue) { Get-RepoSeam }")
    Assert-Equal '' ((Get-UnresolvedTemplateCall -Path $seam) -join ',') `
        'a seam the file guards with Get-Command is declared external, not missing'

    $split = Join-Path $tmp 'split.ps1'
    Set-Content -LiteralPath $split -Encoding ASCII -Value @(
        "function Test-Seam { return [bool](Get-Command -Name 'Get-RepoSeam' -ErrorAction SilentlyContinue) }"
        'function Use-Seam { if (Test-Seam) { Get-RepoSeam } }'
        'Use-Seam')
    Assert-Equal '' ((Get-UnresolvedTemplateCall -Path $split) -join ',') `
        'and the guard covers the call even from another function -- file-wide, by design'

    $broken = Join-Path $tmp 'broken.ps1'
    Set-Content -LiteralPath $broken -Encoding ASCII -Value 'function Oops { '
    Assert-True ($null -eq (Get-UnresolvedTemplateCall -Path $broken)) `
        'a file that does not parse returns $null, so it can never read as zero findings'
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

# --- every template this repo ships --------------------------------------------------------------
$templates = @(Get-ChildItem -Path (Join-Path $RepoRoot 'plugins') -Recurse -Filter '*.ps1' -File |
    Where-Object { $_.DirectoryName -like '*\templates' } | Sort-Object FullName)

# The glob is asserted, not assumed. A templates/ folder that is renamed or moved would otherwise turn
# this whole suite into a no-op that keeps reporting green.
Assert-True ($templates.Count -ge 1) "at least one shipped template is found ($($templates.Count))"

foreach ($t in $templates) {
    $rel = $t.FullName.Substring($RepoRoot.Length + 1).Replace('\', '/')
    $unresolved = Get-UnresolvedTemplateCall -Path $t.FullName
    # `$null -eq`, never `$null -ne`: with a COLLECTION on the left, PowerShell's comparison operators
    # filter instead of comparing, so `$null -ne @()` yields an empty array -- which is $false, and a
    # clean template would report itself as unparseable.
    $parsed = -not ($null -eq $unresolved)
    Assert-True $parsed "$rel parses"
    if ($parsed) {
        Assert-Equal '' ($unresolved -join ', ') "$rel calls nothing it cannot answer for"
    }
}

# --- done ----------------------------------------------------------------------------------------
Write-Host ""
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
