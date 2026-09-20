<#
.SYNOPSIS
    Direct unit tests for Get-ConsumerLensPaths in scripts/lib/entry-scaffold-lib.ps1 -- the shared
    lens-discovery ASSEMBLY issue #2199 promoted from check-policy-drift.ps1's RANK 2 and
    Get-ConsumerProseDocuments's kind-3 walk. Both callers already carry their own integration
    coverage (policy-drift-report.tests.ps1, consumer-prose-gate.tests.ps1); this suite pins the
    function's OWN contract directly, at the two seams the #2199 review pass touched and neither
    existing suite exercises on the function itself.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/consumer-lens-paths.tests.ps1

    1. THE FAIL-CLOSED SLUG GUARD (#2199 review, Victor #19 and Sebastian #23, independently). Written
       first with '-and', a missing Test-PluginNameSlug made the whole guard test false, so its
       'continue' never fired and an unvalidated plugin name reached Get-LensDirCandidates as a path
       segment -- fail-OPEN. The repair splits the guard into two conditions so a caller too old to
       carry Test-PluginNameSlug EXCLUDES the name instead. The interesting case is the degraded
       payload the docstring names: Get-SeamPaths, Get-LensDirCandidates and Get-SpecialistFiles all
       present, Test-PluginNameSlug absent. That state is constructed here rather than merely asserted
       about, by removing the one function from an otherwise fully loaded session --
       'Remove-Item function:Test-PluginNameSlug' -- the same technique entry-scaffold.tests.ps1 already
       uses to simulate a seam a caller has not grown yet ('Remove-Item function:Get-ReleaseAudienceTier').
       Verified live, on this machine, before trusting it here: Test-FunctionDefined answers $false
       immediately after the removal and $true again after the lib is re-dot-sourced. The function is
       restored in a 'finally' around the one call made while it is missing, so a throw there cannot
       leave the removal standing for whatever the parallel test gate schedules into this same process
       next.

    2. THE -Seen MUTATE-IN-PLACE CONTRACT (#2199 review, Nolan #25). -Seen is not a copy-in,
       merge-back parameter: a caller's own HashSet is read from AND written to directly, which is what
       removed the second pass the promotion had cost (+6 to +7 ms per call, +11-12%, on the always-on
       path). The first two attempts at this parameter were both wrong and both caught by
       consumer-prose-gate.tests.ps1 (4 of 91 asserts failed), through Get-ConsumerProseDocuments's own
       use of it -- real teeth, but an EMERGENT proof: that suite's caller does its own bookkeeping
       around the call, so a regression has to survive being read back through another function's logic
       before it is visible. The asserts below add the direct proof instead: they perform no merge of
       their own after calling Get-ConsumerLensPaths, so a private-set-plus-return-array shape (the
       two-pass regression, or either of the two broken single-pass attempts before it) would leave the
       caller's own HashSet exactly as this suite left it, with nothing the function did visible in it
       at all.

    Fixture paths carry $PID (repo convention): the test gate is a throttled parallel scheduler, so two
    runs overlapping is ordinary and two sharing one fixed temp path tear down each other's tree.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $RepoRoot 'scripts\lib\check-report-lib.ps1')
. (Join-Path $RepoRoot 'scripts\lib\entry-scaffold-lib.ps1')

$script:pass  = 0
$script:fail  = 0
$script:trees = @()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor DarkGreen }
    else { $script:fail++; Write-Host "  [FAIL] $Message" -ForegroundColor Red }
}

function New-Tree {
    param([Parameter(Mandatory = $true)][string]$Label)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("lenspaths-$PID-$Label-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $script:trees += $dir
    return $dir
}

function Set-Text {
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][string]$Rel,
        [Parameter(Mandatory = $true)][string]$Text
    )
    $target = Join-Path $Dir ($Rel -replace '/', '\')
    $parent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [System.IO.File]::WriteAllText($target, $Text + "`n", (New-Object System.Text.UTF8Encoding($false)))
}

try {
    # --- 1. THE FAIL-CLOSED SLUG GUARD --------------------------------------------------------------
    Write-Host 'Get-ConsumerLensPaths -- the fail-closed slug guard (#2199 review)'

    $guardTree = New-Tree -Label 'guard'
    # Reachable ONLY through a -PluginNames candidate -- the pre-seam per-plugin layout
    # Get-LensDirCandidates composes from a plugin NAME, which is exactly what the guard stands in
    # front of.
    $preSeamRel = ".claude/plugins/$(Get-LensFamily)/dkj-policy/05-15-extension.md"
    Set-Text -Dir $guardTree -Rel $preSeamRel -Text '# A pre-seam lens, reachable only through a PluginName candidate'
    # Reachable with NO -PluginNames at all -- added unconditionally from Get-SeamPaths, outside the
    # loop the guard sits in. This is what proves the degradation is narrow rather than total.
    $seamRel = '.claude/specialists/lenses/specialist-05-05-lens.md'
    Set-Text -Dir $guardTree -Rel $seamRel -Text '# A seam lens, reachable with no PluginNames at all'

    $before = @(Get-ConsumerLensPaths -RepoRoot $guardTree -PluginNames @('dkj-policy'))
    Assert-True (@($before | Where-Object { $_ -eq $preSeamRel }).Count -eq 1) `
        'with Test-PluginNameSlug present, the pre-seam candidate IS reached -- the fixture proves what the guard is about to remove'
    Assert-True (@($before | Where-Object { $_ -eq $seamRel }).Count -eq 1) `
        'and the seam lens is found too, as the baseline for the next assert'

    # Simulate a mirror that carries Get-SeamPaths, Get-LensDirCandidates and Get-SpecialistFiles
    # whole but has not yet grown Test-PluginNameSlug -- constructed by removing the one function from
    # an otherwise fully loaded session, not asserted about code that never actually runs.
    Remove-Item function:Test-PluginNameSlug
    try {
        $degraded = @(Get-ConsumerLensPaths -RepoRoot $guardTree -PluginNames @('dkj-policy'))
        Assert-True (@($degraded | Where-Object { $_ -eq $preSeamRel }).Count -eq 0) `
            'with Test-PluginNameSlug undefined, the plugin name is EXCLUDED -- fail-closed, not the fail-open the first attempt shipped with'
        Assert-True (@($degraded | Where-Object { $_ -eq $seamRel }).Count -eq 1) `
            'the seam lens is unaffected -- the guard narrows only the PluginNames loop, not the whole function'
    } finally {
        . (Join-Path $RepoRoot 'scripts\lib\check-report-lib.ps1')
    }

    Assert-True (Test-FunctionDefined 'Test-PluginNameSlug') `
        'Test-PluginNameSlug is restored before anything later in this process relies on it'
    $restored = @(Get-ConsumerLensPaths -RepoRoot $guardTree -PluginNames @('dkj-policy'))
    Assert-True (@($restored | Where-Object { $_ -eq $preSeamRel }).Count -eq 1) `
        'restoring the function restores the pre-seam candidate -- the exclusion was live, not cached'

    # --- 2. THE -Seen MUTATE-IN-PLACE CONTRACT ------------------------------------------------------
    Write-Host ''
    Write-Host 'Get-ConsumerLensPaths -- the -Seen contract (#2199 review)'

    $seenTree = New-Tree -Label 'seen'
    $seenRel = '.claude/specialists/lenses/specialist-06-16-lens.md'
    Set-Text -Dir $seenTree -Rel $seenRel -Text '# One lens, for the -Seen contract'

    # 2a. THE WRITE SIDE. No merge of the return value happens here, on purpose: a private-set-plus-
    # return-array shape would leave $written exactly as created, because nothing but the function
    # itself ever touches it.
    $written = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $out = @(Get-ConsumerLensPaths -RepoRoot $seenTree -Seen $written)
    Assert-True (@($out | Where-Object { $_ -eq $seenRel }).Count -eq 1) 'the lens is in the returned list (sanity)'
    Assert-True ($written.Contains($seenRel)) `
        "the caller's OWN HashSet carries the path afterward, with no merge step run by this suite -- mutate-in-place, not copy-out"

    # 2b. THE READ SIDE. A path the caller already has is honoured rather than re-discovered, which is
    # what proves the SAME object is read from as well as written to.
    $preSeeded = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    [void]$preSeeded.Add($seenRel)
    $out2 = @(Get-ConsumerLensPaths -RepoRoot $seenTree -Seen $preSeeded)
    Assert-True ($out2.Count -eq 0) `
        "a path already in the caller's -Seen is not returned again -- the walk reads the SAME set it writes to, not a private one"

    # 2c. NO -Seen AT ALL. A private set is still built: neither a throw nor a loss of the function's
    # own de-duplication with nothing supplied to lean on.
    $bare = @(Get-ConsumerLensPaths -RepoRoot $seenTree)
    Assert-True (@($bare | Where-Object { $_ -eq $seenRel }).Count -eq 1) `
        'with no -Seen at all, the function still finds the lens -- a private set is built when the caller has none to share'

    # 2d. SELF-DEDUP WITH NO -Seen, the docstring's own named case: a duplicated -PluginNames entry
    # must not produce a duplicated finding even with nothing to dedupe against but the function's own
    # fresh set.
    $dupTree = New-Tree -Label 'dup'
    $dupRel = ".claude/plugins/$(Get-LensFamily)/dkj-policy/05-06-extension.md"
    Set-Text -Dir $dupTree -Rel $dupRel -Text '# reachable via one plugin name, given twice'
    $dupOut = @(Get-ConsumerLensPaths -RepoRoot $dupTree -PluginNames @('dkj-policy', 'dkj-policy'))
    Assert-True (@($dupOut | Where-Object { $_ -eq $dupRel }).Count -eq 1) `
        'a duplicated -PluginNames entry produces the path exactly once, not once per repetition'
}
finally {
    foreach ($t in $script:trees) {
        if ($t -and (Test-Path -LiteralPath $t)) { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host "FAIL: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
