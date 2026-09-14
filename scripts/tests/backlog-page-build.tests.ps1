<#
.SYNOPSIS
    Regression tests for the minor-backlog page builder dkj-policy-bwj ships (issue #1979).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/backlog-page-build.tests.ps1

    WHAT IT HOLDS. The builder splits into a pure lib (backlog-page-rules.ps1 -- ranking, ordering,
    escaping, the HTML shape) and a driver (build-backlog-page.ps1 -- gh, Asana, the filesystem). This
    suite exercises the pure half completely, in-process, and the driver's two refusals that are
    reachable WITHOUT a network call: a fixture with no scripts\repo-config.ps1, and a -RootOverride
    that is not a directory. Everything past config resolution is 'gh issue list' and an Asana GET --
    the same remaining, untestable-without-a-live-account half bwj-page-publish.tests.ps1 already
    states for publish-page.ps1's own upload.

    THE ONE DECISION WORTH RE-STATING HERE: the page shows the ASANA TASK's Name and Notes, never the
    GitHub issue's own title and body (Dave, September 14, 2026, on the issue itself) -- so an issue
    with no mirrored task contributes nothing, and Get-BacklogPageHtml is tested against exactly that
    shape: entries that already carry the colleague-facing text, never an issue object.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$PluginRoot = Join-Path $RepoRoot 'plugins\dkj-policy\dkj-policy-bwj'
$LibPath    = Join-Path $PluginRoot 'scripts\lib\backlog-page-rules.ps1'
$ScriptPath = Join-Path $PluginRoot 'scripts\task\build-backlog-page.ps1'
$Fixture    = Join-Path ([System.IO.Path]::GetTempPath()) "backlog-page-build-fixture-$PID-$([guid]::NewGuid().ToString('n'))"

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Label)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label" -ForegroundColor Red }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Label)
    if ("$Expected" -eq "$Actual") { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}

Write-Host ''
Write-Host 'The shared BWJ pages worker -- the backlog builder (#1979)' -ForegroundColor Cyan

Assert-True (Test-Path -LiteralPath $LibPath)    'dkj-policy-bwj ships scripts/lib/backlog-page-rules.ps1'
Assert-True (Test-Path -LiteralPath $ScriptPath) 'dkj-policy-bwj ships scripts/task/build-backlog-page.ps1'

. $LibPath

Write-Host ''
Write-Host 'ConvertTo-BacklogHtmlText -- escaping' -ForegroundColor Cyan

Assert-Equal '&lt;a&gt; &amp; b' (ConvertTo-BacklogHtmlText -Value '<a> & b') 'the three characters HTML text needs escaped are escaped'
Assert-Equal 'plain'             (ConvertTo-BacklogHtmlText -Value 'plain')  'plain text is unchanged'
Assert-Equal ''                  (ConvertTo-BacklogHtmlText -Value '')      'an empty string stays empty'

Write-Host ''
Write-Host 'Get-IssuePrioRank -- the priority axis read for ORDER ONLY (#1686 keeps it disjoint from reach)' -ForegroundColor Cyan

Assert-Equal 0 (Get-IssuePrioRank -Labels @())                        'no labels at all is rank 0'
Assert-Equal 0 (Get-IssuePrioRank -Labels @('minor', 'documentation')) 'labels with no prio-* rung is rank 0'
Assert-Equal 1 (Get-IssuePrioRank -Labels @('prio-1'))                'prio-1 is rank 1'
Assert-Equal 4 (Get-IssuePrioRank -Labels @('prio-4', 'minor'))       'prio-4 among other labels is rank 4'
Assert-Equal 3 (Get-IssuePrioRank -Labels @('prio-1', 'prio-3'))      'two prio-* labels take the HIGHER one -- the fail-safe direction for a backlog page'
Assert-Equal 0 (Get-IssuePrioRank -Labels @('prio-0', 'prio-5'))      'a rung outside 1-4 does not match at all'

Write-Host ''
Write-Host 'Sort-BacklogEntries -- highest priority first, then issue number ascending' -ForegroundColor Cyan

$unsorted = @(
    [pscustomobject]@{ Number = 20; PrioRank = 1 }
    [pscustomobject]@{ Number = 5;  PrioRank = 4 }
    [pscustomobject]@{ Number = 7;  PrioRank = 4 }
    [pscustomobject]@{ Number = 1;  PrioRank = 0 }
)
$sorted = Sort-BacklogEntries -Entries $unsorted
Assert-Equal '5,7,20,1' (($sorted | ForEach-Object { $_.Number }) -join ',') 'rank descending, then number ascending within a tied rank'
Assert-Equal 0 (@(Sort-BacklogEntries -Entries @()).Count) 'an empty list sorts to an empty list, not an error'

Write-Host ''
Write-Host 'Format-BacklogEntryHtml -- one entry, blank-line paragraphs, escaped throughout' -ForegroundColor Cyan

$frag = Format-BacklogEntryHtml -Title 'A <b> title' -Notes "First para.`n`nSecond para,`nwrapped."
Assert-True ($frag -match '<h2>A &lt;b&gt; title</h2>')      'the title is escaped, never raw markup'
Assert-True ($frag -match '<p>First para\.</p>')              'a blank line starts a new paragraph'
Assert-True ($frag -match '<p>Second para,<br>wrapped\.</p>') 'a single line break inside a paragraph becomes <br>, not a new paragraph'

$noNotes = Format-BacklogEntryHtml -Title 'Bare title' -Notes ''
Assert-True ($noNotes -match '<h2>Bare title</h2>')  'a title with no notes still renders'
Assert-True ($noNotes -notmatch '<p>')                'and renders no empty <p> -- nothing invented for a task with no notes'

$blankOnly = Format-BacklogEntryHtml -Title 'x' -Notes "`n`n   `n`n"
Assert-True ($blankOnly -notmatch '<p>') 'notes that are only whitespace render no paragraph either'

Write-Host ''
Write-Host 'Get-BacklogPageHtml -- the whole page' -ForegroundColor Cyan

$entries = @(
    [pscustomobject]@{ Number = 5; Title = 'High one'; Notes = 'body a'; PrioRank = 4 }
    [pscustomobject]@{ Number = 9; Title = 'Low one';  Notes = 'body b'; PrioRank = 1 }
)
$page = Get-BacklogPageHtml -Entries $entries -RepoLabel 'smartwatchbanden'
Assert-True ($page -match '(?s)High one.*Low one') 'entries render in ranked order, high first'
Assert-True ($page -match 'noindex, nofollow')      'noindex is on the page -- no login, no public path, no crawl'
Assert-True ($page -match '<title>smartwatchbanden -- backlog</title>') 'the repo label reaches the title'
Assert-True ($page -notmatch 'github\.com')         'no link back to the issue tracker -- the reader has no login for it'
Assert-True ($page -notmatch '#5')                  'no issue-number jargon on the page -- Number exists for sorting only, never rendered'
Assert-True ($page -match 'prefers-color-scheme|color-scheme')      'the page states a colour scheme so it is readable in light and dark'

$emptyPage = Get-BacklogPageHtml -Entries @() -RepoLabel 'smartwatchbanden'
Assert-True ($emptyPage -match 'Nothing outstanding right now') 'zero entries is a real, positive message, not a blank body'
Assert-True ($emptyPage -notmatch '<article')                    'and no entry markup renders for zero entries'

$noLabel = Get-BacklogPageHtml -Entries @() -RepoLabel ''
Assert-True ($noLabel -match '<title>Backlog</title>') 'an unnamed repo label still yields a usable title, not an empty one'

Write-Host ''
Write-Host 'The script, against a fixture store repo -- the refusals reachable without a network call' -ForegroundColor Cyan

New-Item -ItemType Directory -Path (Join-Path $Fixture 'scripts') -Force | Out-Null
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Set-FixtureConfig {
    param([string]$Body)
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'scripts\repo-config.ps1'), $Body, $Utf8NoBom)
}

# Same shape as bwj-page-publish.tests.ps1's Invoke-PublishPage: stderr to a file rather than the
# success stream, because Windows PowerShell wraps a native/terminating error per line into the
# console width, which breaks a -match over a refusal message that spans more than one wrapped line.
function Invoke-BuildBacklogPage {
    param([string[]]$ScriptArgs)
    $errFile = Join-Path $Fixture "stderr-$([guid]::NewGuid().ToString('n')).txt"
    $all = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath, '-RootOverride', $Fixture) + $ScriptArgs
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out  = & powershell @all 2>$errFile
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prev
    }
    $err = ''
    if (Test-Path -LiteralPath $errFile) {
        $err = [System.IO.File]::ReadAllText($errFile)
        Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
    }
    $text = ((@($out) -join "`n") + "`n" + $err) -replace '\s+', ' '
    return [pscustomobject]@{ Text = $text; ExitCode = $code }
}

try {
    $noConfig = Invoke-BuildBacklogPage -ScriptArgs @('-DryRun')
    Assert-True ($noConfig.ExitCode -ne 0) 'a fixture with no scripts\repo-config.ps1 cannot build'
    Assert-True ($noConfig.Text -like '*adopt-dkj-policy-bwj*') '...and says which skill answers the seams'

    # A dedicated call rather than Invoke-BuildBacklogPage: that helper always injects its own
    # -RootOverride pointing at the fixture, and a second one here would be a duplicate named
    # parameter -- a different (and less interesting) failure than the one this case tests.
    $badRootDir = Join-Path $Fixture 'does-not-exist'
    $errFile = Join-Path $Fixture "stderr-$([guid]::NewGuid().ToString('n')).txt"
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath -RootOverride $badRootDir -DryRun 2>$errFile | Out-Null
        $badRootCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEap
    }
    $badRootErr = if (Test-Path -LiteralPath $errFile) { [System.IO.File]::ReadAllText($errFile) } else { '' }
    Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
    Assert-True ($badRootCode -ne 0) '-RootOverride naming a directory that does not exist is refused'
    Assert-True ($badRootErr -like '*is not a directory*') '...and says so rather than failing on a path operation deeper in the script'
} finally {
    Remove-Item -LiteralPath $Fixture -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
