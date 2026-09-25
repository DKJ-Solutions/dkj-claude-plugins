# TEMPORARY MEASUREMENT FOR #2488 -- see .github/workflows/linux-runner-probe.yml. Removed before the PR.
param([Parameter(Mandatory)][string]$Pass)

$suites = @(
    'unfolded-entry-gate', 'fold-changelog', 'verify-pushed-merges', 'repo-settings-gate',
    'merge-on-green-lib', 'ship-pr-trusted-root', 'verify-resolved-issues', 'native-capture',
    'adopt-ci-floor'
)
$rows = foreach ($s in $suites) {
    $path = "scripts/tests/$s.tests.ps1"
    Write-Host "::group::[$Pass] $s"
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $out = & pwsh -NoProfile -File $path 2>&1 | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
    $sw.Stop()
    $out | Write-Host
    Write-Host '::endgroup::'
    $fails = @($out | Where-Object { $_ -match '^\s*(\[FAIL\]|FAIL\b)' })
    [pscustomobject]@{ Suite = $s; Exit = $code; Fails = $fails.Count; Seconds = [int]$sw.Elapsed.TotalSeconds; First = ($fails | Select-Object -First 3) -join ' | ' }
}
$rows | Format-Table -AutoSize -Wrap | Out-String -Width 400 | Write-Host
if ($env:GITHUB_STEP_SUMMARY) {
    "### Pass $Pass" | Add-Content $env:GITHUB_STEP_SUMMARY
    '| suite | exit | fails | s | first failures |' | Add-Content $env:GITHUB_STEP_SUMMARY
    '|---|---|---|---|---|' | Add-Content $env:GITHUB_STEP_SUMMARY
    foreach ($r in $rows) { "| $($r.Suite) | $($r.Exit) | $($r.Fails) | $($r.Seconds) | $($r.First -replace '\|','/') |" | Add-Content $env:GITHUB_STEP_SUMMARY }
}
