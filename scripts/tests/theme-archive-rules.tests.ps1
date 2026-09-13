<#
.SYNOPSIS
    Regression tests for scripts/lib/theme-archive-rules.ps1 -- the decisions dkj-subagents-shopify's
    theme archive is built on (issue #1886 candidate 4).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/theme-archive-rules.tests.ps1

    WHY THESE FUNCTIONS HAVE A SUITE AND THE SCRIPT AROUND THEM DOES NOT. Every path in
    scripts/task/archive-theme.ps1 either invokes the Shopify CLI against a real store or reads a
    consumer's own repo-config, and a suite must reach neither. What is left is pure, and it is exactly
    where the measured defects were:

      * Expand-ThemeIdList not splitting commas made a six-theme run archive NOTHING and report
        "Skipped: 1" -- success-shaped output for work never attempted.
      * Get-ThemeArchiveVerdict is the only thing standing between a wholesale pull and the live theme,
        and it is doubled on purpose: repo-config's answer and the store's role can disagree.
      * Get-ArchiveFolderName meets theme names carrying slashes, leading spaces and trailing spaces.
        On Windows a slash scatters one theme across nested directories and a trailing space is DROPPED
        silently, so the "does this archive exist" check misses and every run re-pulls.
      * Get-ThemeArchiveFileRecords' sort was written four times and three of those were silently
        wrong. The discriminating case is 'B' before 'a' -- ordinal one way, cultural the other -- which
        is why an ordinary pair of theme paths cannot see it.
      * Merge-ThemeArchiveEvent's 'kept' branch is the whole of the receipt repair: every run on a
        machine that did not already hold the archive used to rewrite the one field the receipt exists
        to record.
      * Format-ThemeDeleteCommand replaced a format string whose three defects survived a repair pass
        over the very file it lived in, and whose failure mode is a guard refusal that reads as the rule
        rather than as a typo.
      * Get-ExternalThemeWarning is this convergence's own addition and the one place NEITHER converged
        copy was right -- see its asserts.

    THE ROUND TRIP IS THE HEADLINE, and it is here because the units cannot see what it sees: a
    phantom blank event was folded into every first receipt while every unit assert passed, because the
    unroll happened at a PARAMETER BOUNDARY rather than inside the expression the unit measured.

    Fixture paths carry $PID (repo convention): the test gate is a throttled parallel scheduler, so two
    runs overlapping is ordinary, and two runs sharing one fixed temp path tear down each other's tree
    mid-assert.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $RepoRoot 'scripts\lib\theme-archive-rules.ps1')

$script:pass = 0
$script:fail = 0
$script:trees = @()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor DarkGreen }
    else { $script:fail++; Write-Host "  [FAIL] $Message" -ForegroundColor Red }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message)
    if ($Expected -eq $Actual) { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor DarkGreen }
    else { $script:fail++; Write-Host "  [FAIL] $Message -- expected '$Expected', got '$Actual'" -ForegroundColor Red }
}

function New-Tree {
    param([Parameter(Mandatory = $true)][string]$Label)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("themearchive-$PID-$Label-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $script:trees += $dir
    return $dir
}

function New-File {
    param([string]$Root, [string]$Rel, [string]$Content)
    $full = Join-Path $Root $Rel
    New-Item -ItemType Directory -Path (Split-Path -Parent $full) -Force | Out-Null
    # -Encoding ascii and -NoNewline: the byte count is asserted, so the encoding must not add a BOM
    # and the newline must not be the platform's.
    Set-Content -LiteralPath $full -Value $Content -Encoding ascii -NoNewline
    return $full
}

try {

# --------------------------------------------------------------------------------------------------
Write-Host "`nExpand-ThemeIdList -- what the caller actually asked for" -ForegroundColor Cyan
# --------------------------------------------------------------------------------------------------
# THE MEASURED DEFECT. Under '-File' PowerShell splits arguments on whitespace and never evaluates
# them, so '-ThemeId a,b,c' binds ONE element holding the literal text. Under '-Command' the same text
# binds three. A [string[]] that does not split commas itself works in one invocation style and fails
# silently in the other -- and every gate in this workflow runs with -File.
$one = Expand-ThemeIdList -ThemeId @('183398957397,184636047701,184381800789')
Assert-Equal 3 @($one).Count 'a comma-joined single string becomes three ids (the -File shape)'
Assert-Equal '183398957397' @($one)[0] 'first id of the split'
Assert-Equal '184381800789' @($one)[2] 'last id of the split'

$many = Expand-ThemeIdList -ThemeId @('111', '222')
Assert-Equal 2 @($many).Count 'already-split elements pass through (the -Command shape)'

$mixed = Expand-ThemeIdList -ThemeId @('111, 222', ' 333 ')
Assert-Equal 3 @($mixed).Count 'a mix of both shapes flattens'
Assert-Equal '222' @($mixed)[1] 'whitespace around a split part is trimmed'
Assert-Equal '333' @($mixed)[2] 'whitespace around a whole element is trimmed'

$dupes = Expand-ThemeIdList -ThemeId @('111,222,111')
Assert-Equal 2 @($dupes).Count 'duplicates collapse -- -Refresh would otherwise re-pull the same theme twice'

Assert-Equal 0 @(Expand-ThemeIdList -ThemeId @()).Count 'an empty list gives no ids'
Assert-Equal 0 @(Expand-ThemeIdList -ThemeId $null).Count 'a null list gives no ids'
Assert-Equal 0 @(Expand-ThemeIdList -ThemeId @(',', ' ')).Count 'separators and blanks alone give no ids'

# --------------------------------------------------------------------------------------------------
Write-Host "`nGet-ThemeArchiveVerdict -- may this theme be archived at all" -ForegroundColor Cyan
# --------------------------------------------------------------------------------------------------
$v = Get-ThemeArchiveVerdict -Id '' -LiveThemeId '999'
Assert-Equal $false $v.Allowed 'an empty id is refused'

# AN UNANSWERED SEAM IS REFUSED RATHER THAN READ AS "NOTHING IS LIVE". The caller reads it from
# Get-ShopifyLiveThemeId, and a repo-config fault must not quietly widen what may be pulled.
$v = Get-ThemeArchiveVerdict -Id '123' -Role 'unpublished' -LiveThemeId ''
Assert-Equal $false $v.Allowed 'no live theme id known -> refused, never "nothing is live"'
Assert-True ($v.Reason -like '*refusing to guess*') 'and the reason says it is refusing to guess'

# THE DOUBLED CHECK, HALF ONE: repo-config's answer.
$v = Get-ThemeArchiveVerdict -Id '190793613653' -Role 'unpublished' -LiveThemeId '190793613653'
Assert-Equal $false $v.Allowed 'the id repo-config calls live is refused even when the store calls it unpublished'

# THE DOUBLED CHECK, HALF TWO: the store's own role. This is the half that catches a third party
# publishing a theme without touching the repo, which is what a stale repo-config looks like from here.
$v = Get-ThemeArchiveVerdict -Id '123' -Role 'live' -LiveThemeId '999'
Assert-Equal $false $v.Allowed "role 'live' is refused even when repo-config names another id"
$v = Get-ThemeArchiveVerdict -Id '123' -Role 'main' -LiveThemeId '999'
Assert-Equal $false $v.Allowed "role 'main' is refused too -- the CLI has used both spellings"
$v = Get-ThemeArchiveVerdict -Id '123' -Role 'LIVE' -LiveThemeId '999'
Assert-Equal $false $v.Allowed 'the role comparison is case-insensitive'

$v = Get-ThemeArchiveVerdict -Id '123' -Name 'feat/upsell' -Role 'unpublished' -LiveThemeId '999'
Assert-Equal $true $v.Allowed 'an ordinary unpublished theme is allowed'
Assert-Equal '' $v.Reason 'and carries no reason'

# --------------------------------------------------------------------------------------------------
Write-Host "`nGet-ArchiveFolderName -- what a theme is called on disk" -ForegroundColor Cyan
# --------------------------------------------------------------------------------------------------
# THE THREE SHAPES BELOW ARE REAL THEME NAMES measured on a store, not invented edge cases.
Assert-Equal 'theme-vendor-feat-upsell-options-123' (Get-ArchiveFolderName -Name 'theme-vendor/feat/upsell-options' -Id '123') `
    'slashes become dashes -- on Windows a slash is a path, not a rename, and would scatter one theme across three directories'
Assert-Equal 'Kopie store 9-7-2021 - DO NOT DELETE-123' (Get-ArchiveFolderName -Name 'Kopie store 9-7-2021 - DO NOT DELETE ' -Id '123') `
    'a trailing space is trimmed -- Windows DROPS it silently, so the folder would not round-trip and every run would re-pull'
Assert-Equal 'STORE THEME Live 15-5-2023 (no testing)-123' (Get-ArchiveFolderName -Name ' STORE THEME Live 15-5-2023 (no testing)' -Id '123') `
    'a leading space is trimmed'

Assert-Equal 'name-123' (Get-ArchiveFolderName -Name 'name. ' -Id '123') `
    'a trailing dot AND a trailing space both go, in that order -- a trailing dot is dropped by Windows too'
Assert-Equal 'theme-123' (Get-ArchiveFolderName -Name '' -Id '123') 'an empty name falls back to "theme" rather than a bare dash'
Assert-Equal 'theme-123' (Get-ArchiveFolderName -Name '   ' -Id '123') 'a whitespace-only name does the same'

# THE ID IS NEVER SANITISED AWAY, so two themes that sanitise to the same name still get their own
# folder -- which is the property that keeps one archive from overwriting another.
$a = Get-ArchiveFolderName -Name 'a/b' -Id '111'
$b = Get-ArchiveFolderName -Name 'a\b' -Id '222'
Assert-True ($a -ne $b) 'two names that sanitise identically still differ, because the id is appended'
Assert-True ($a.EndsWith('-111')) 'and the id is the suffix'

# --------------------------------------------------------------------------------------------------
Write-Host "`nTest-ThemeArchive -- did the pull actually land a theme" -ForegroundColor Cyan
# --------------------------------------------------------------------------------------------------
# "THE DIRECTORY EXISTS" IS NOT THE QUESTION: archive-theme.ps1 CREATES the directory before it pulls,
# because 'theme pull --path' requires that. A pull failing on the first file leaves an empty existing
# folder, and a Test-Path check would call that archived and then print a removal command for a theme
# with no backup -- the one failure here that is not recoverable.
$root = New-Tree 'archive'
Assert-Equal $false (Test-ThemeArchive -Path (Join-Path $root 'nope')) 'an absent path is not an archive'
$empty = Join-Path $root 'empty'
New-Item -ItemType Directory -Path $empty -Force | Out-Null
Assert-Equal $false (Test-ThemeArchive -Path $empty) 'an EMPTY but existing directory is not an archive -- the failed-pull shape'
$partial = Join-Path $root 'partial'
New-File -Root $partial -Rel 'sections\header.liquid' -Content 'x' | Out-Null
Assert-Equal $true (Test-ThemeArchive -Path $partial) 'one recognised theme directory is enough'
$wrong = Join-Path $root 'wrong'
New-File -Root $wrong -Rel 'docs\readme.md' -Content 'x' | Out-Null
Assert-Equal $false (Test-ThemeArchive -Path $wrong) 'files that are not a theme directory do not count'

# --------------------------------------------------------------------------------------------------
Write-Host "`nGet-ArchiveManifestFileName -- the receipt's name" -ForegroundColor Cyan
# --------------------------------------------------------------------------------------------------
# DERIVED FROM THE FOLDER NAME rather than rebuilt from name and id, so the two can never disagree
# about which receipt describes which folder. The folder is the thing that vanishes; the receipt stays.
$folder = Get-ArchiveFolderName -Name 'theme-vendor/feat/x ' -Id '55'
Assert-Equal ($folder + '.txt') (Get-ArchiveManifestFileName -Folder $folder) 'the receipt is the folder name plus .txt'
Assert-True ((Get-ArchiveManifestFileName -Folder $folder) -notmatch '/') 'so every hazard the folder name handled is already handled'

# --------------------------------------------------------------------------------------------------
Write-Host "`nGet-ThemeArchiveFileRecords -- the walk, and the sort that was wrong three times" -ForegroundColor Cyan
# --------------------------------------------------------------------------------------------------
Assert-Equal 0 @(Get-ThemeArchiveFileRecords -Path (Join-Path $root 'absent')).Count `
    'a missing directory returns empty rather than throwing -- the receipt must never fail a run whose archive is fine'

$walk = New-Tree 'walk'
New-File -Root $walk -Rel 'sections\header.liquid' -Content 'abc'   | Out-Null
New-File -Root $walk -Rel 'layout\theme.liquid'    -Content 'defgh' | Out-Null
$recs = Get-ThemeArchiveFileRecords -Path $walk
Assert-Equal 2 @($recs).Count 'both files are walked'
Assert-True (@($recs | Where-Object { $_.RelativePath -eq 'sections/header.liquid' }).Count -eq 1) `
    'paths use FORWARD slashes -- the receipt is committed and a Shopify theme''s own paths look like this'
Assert-Equal 3 (@($recs | Where-Object { $_.RelativePath -eq 'sections/header.liquid' })[0].Bytes) 'the byte count is the file length'
Assert-True ((@($recs)[0].Sha256) -match '^[0-9a-f]{64}$') 'the digest is a lowercase 64-character SHA-256'

# THE DISCRIMINATING CASE, and the reason an ordinary pair of theme paths cannot stand in for it:
# 'layout' before 'sections' is the same answer under all four spellings that were tried. Ordinal puts
# uppercase first; most cultural collations do not.
$ordinal = New-Tree 'ordinal'
New-File -Root $ordinal -Rel 'layout\a.liquid' -Content 'x' | Out-Null
New-File -Root $ordinal -Rel 'layout\B.liquid' -Content 'x' | Out-Null
$sorted = Get-ThemeArchiveFileRecords -Path $ordinal
Assert-Equal 'layout/B.liquid' (@($sorted)[0].RelativePath) `
    "the sort is ORDINAL -- 'B' before 'a'. Culture-aware sorting answers the other way, and the property needed is that two machines render byte-identical receipts"

# THE FOURTH SPELLING WAS GREEN UNDER A SUITE'S 'Continue' AND FATAL UNDER THE CALLER'S 'Stop':
# '@(...)' over a generic List of PSCustomObjects raises a non-terminating error that Continue swallows.
# So the preference is flipped here on purpose -- a unit green on a path the caller cannot execute is
# the one failure a unit suite is supposed to be immune to.
$prevEap = $ErrorActionPreference
try {
    $ErrorActionPreference = 'Stop'
    $underStop = Get-ThemeArchiveFileRecords -Path $ordinal
    Assert-Equal 2 @($underStop).Count "the walk survives the caller's own EAP of 'Stop'"
} catch {
    Assert-True $false "the walk survives the caller's own EAP of 'Stop' -- it threw: $($_.Exception.Message)"
} finally {
    $ErrorActionPreference = $prevEap
}

# --------------------------------------------------------------------------------------------------
Write-Host "`nGet-ThemeArchiveContentDigest -- one name for a whole file list" -ForegroundColor Cyan
# --------------------------------------------------------------------------------------------------
Assert-Equal '' (Get-ThemeArchiveContentDigest -Records @()) `
    'empty in, EMPTY OUT -- deliberately not the SHA-256 of nothing, which would read like a fingerprint of something'
Assert-Equal '' (Get-ThemeArchiveContentDigest -Records $null) 'and a null list does the same'

$d1 = Get-ThemeArchiveContentDigest -Records $recs
$d2 = Get-ThemeArchiveContentDigest -Records $recs
Assert-Equal $d1 $d2 'the digest is deterministic over the same records'
Assert-True ($d1 -match '^[0-9a-f]{64}$') 'and is a lowercase SHA-256'

$changedRecs = @(
    [pscustomobject]@{ RelativePath = 'layout/theme.liquid'; Bytes = 5; Sha256 = 'a' * 64 }
)
Assert-True ($d1 -ne (Get-ThemeArchiveContentDigest -Records $changedRecs)) 'different content gives a different digest'

# REPRODUCIBLE BY HAND FROM A COMMITTED RECEIPT, with no access to the bytes -- which is the property
# the whole event log leans on. The input is the same '<sha>  <bytes>  <path>' text the formatter writes,
# folded over LF rather than the platform's newline.
$byHandLines = @()
foreach ($r in $recs) { $byHandLines += ('{0}  {1}  {2}' -f $r.Sha256, $r.Bytes, $r.RelativePath) }
$byHandText = ($byHandLines -join "`n") + "`n"
$sha = [System.Security.Cryptography.SHA256]::Create()
try {
    $byHand = (($sha.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($byHandText)) | ForEach-Object { $_.ToString('x2') }) -join '')
} finally { $sha.Dispose() }
Assert-Equal $byHand $d1 'and it is reproducible by hand from the rendered lines -- a reader in five months can check it'

# --------------------------------------------------------------------------------------------------
Write-Host "`nGet-ThemeArchiveEvents -- reading a receipt back" -ForegroundColor Cyan
# --------------------------------------------------------------------------------------------------
Assert-Equal 0 @(Get-ThemeArchiveEvents -Text '').Count 'empty text yields no events'
Assert-Equal 0 @(Get-ThemeArchiveEvents -Text $null).Count 'null text yields no events'

$twoEvents = @(
    '# a header comment mentioning folder and machine',
    'theme-id:     123',
    'archived: 2026-08-21T10:00:00Z  MACHINE-A  12  3400  ' + ('a' * 64),
    'archived: 2026-08-28T11:00:00Z  MACHINE-B  12  3400  ' + ('b' * 64),
    '# sha256  bytes  path'
) -join "`n"
$ev = Get-ThemeArchiveEvents -Text $twoEvents
Assert-Equal 2 @($ev).Count 'two event lines are read'
Assert-Equal 'MACHINE-A' @($ev)[0].Machine 'the machine is read'
Assert-Equal 12 @($ev)[0].Files 'the file count is read'
Assert-Equal 3400 @($ev)[0].Bytes 'the byte total is read'

# THE '-' ALTERNATION. Without it a pre-digest event rendered as '-' failed to match, and the event
# VANISHED on the next run -- the lost-machine failure the log exists to prevent, one migration later.
$dashEvent = 'archived: 2026-08-21T10:00:00Z  MACHINE-A  12  3400  -'
$ev = Get-ThemeArchiveEvents -Text $dashEvent
Assert-Equal 1 @($ev).Count "a digest of '-' still parses -- without this the event vanished on the next run"
Assert-Equal '' @($ev)[0].ContentSha "and '-' is read as NO digest rather than as a digest spelled '-'"

$noDigest = 'archived: 2026-08-21T10:00:00Z  MACHINE-A  12  3400'
Assert-Equal 1 @(Get-ThemeArchiveEvents -Text $noDigest).Count 'a hand-written line with no digest field at all is still read'

# THE v1 FALLBACK, and it only runs when NO event line was found -- so a v2 file's own 'files:' and
# 'bytes:' body totals can never be mistaken for an event.
$v1 = @(
    'theme-id:     123',
    'archived-utc: 2026-08-21T10:00:00Z',
    'machine:      OLD-MACHINE',
    'files:        7',
    'bytes:        900'
) -join "`n"
$ev = Get-ThemeArchiveEvents -Text $v1
Assert-Equal 1 @($ev).Count 'a pre-log receipt is read as exactly one event -- the migration needs no conversion script'
Assert-Equal 'OLD-MACHINE' @($ev)[0].Machine 'with its recorded machine'
Assert-Equal '' @($ev)[0].ContentSha 'and no digest, because v1 recorded none'

$v2WithTotals = @(
    'files:        99',
    'bytes:        9999',
    'archived: 2026-08-28T11:00:00Z  MACHINE-B  12  3400  ' + ('b' * 64)
) -join "`n"
$ev = Get-ThemeArchiveEvents -Text $v2WithTotals
Assert-Equal 1 @($ev).Count "a v2 file's body totals are NOT read as a second event"
Assert-Equal 12 @($ev)[0].Files 'and the event read is the real one'

Assert-Equal 0 @(Get-ThemeArchiveEvents -Text 'nothing here at all').Count 'text with neither shape yields nothing'

# --------------------------------------------------------------------------------------------------
Write-Host "`nMerge-ThemeArchiveEvent -- the repair, branch by branch" -ForegroundColor Cyan
# --------------------------------------------------------------------------------------------------
$shaA = 'a' * 64
$shaB = 'b' * 64

$m = Merge-ThemeArchiveEvent -Events @() -ArchivedUtc '2026-09-01T00:00:00Z' -Machine 'M1' -Files 5 -Bytes 100 -ContentSha $shaA
Assert-Equal 'added' $m.Change 'no prior events -> added'
Assert-Equal 1 @($m.Events).Count 'and one event is recorded'

# THE PHANTOM. 'Get-ThemeArchiveEvents -Text ""' returns an EMPTY pipeline, which binds to the
# parameter as $null, and '@($null)' is a ONE-element array holding $null. Every unit passed and the
# first receipt of every theme carried a blank 'archived:' line.
$m = Merge-ThemeArchiveEvent -Events (Get-ThemeArchiveEvents -Text '') -ArchivedUtc '2026-09-01T00:00:00Z' -Machine 'M1' -Files 5 -Bytes 100 -ContentSha $shaA
Assert-Equal 1 @($m.Events).Count 'an empty parse result does not fold a PHANTOM blank event in -- the defect no unit assert could see'
Assert-Equal 'M1' @($m.Events)[0].Machine 'and the one event is this run''s'

$existing = @([pscustomobject]@{ ArchivedUtc = '2026-08-21T10:00:00Z'; Machine = 'M1'; Files = 5; Bytes = 100; ContentSha = $shaA })

# THE WHOLE OF THE REPAIR IS THIS BRANCH: unchanged content leaves the recorded day alone.
$m = Merge-ThemeArchiveEvent -Events $existing -ArchivedUtc '2026-09-01T00:00:00Z' -Machine 'M1' -Files 5 -Bytes 100 -ContentSha $shaA
Assert-Equal 'kept' $m.Change 'same machine, same content -> kept'
Assert-Equal '2026-08-21T10:00:00Z' @($m.Events)[0].ArchivedUtc 'and the recorded day is STILL the day those bytes landed'

$m = Merge-ThemeArchiveEvent -Events $existing -ArchivedUtc '2026-09-01T00:00:00Z' -Machine 'M1' -Files 6 -Bytes 120 -ContentSha $shaB
Assert-Equal 'replaced' $m.Change 'same machine, different content -> replaced'
Assert-Equal '2026-09-01T00:00:00Z' @($m.Events)[0].ArchivedUtc 'and the day moves, because the old event described bytes that are gone'

$m = Merge-ThemeArchiveEvent -Events $existing -ArchivedUtc '2026-09-01T00:00:00Z' -Machine 'M2' -Files 5 -Bytes 100 -ContentSha $shaA
Assert-Equal 'added' $m.Change 'a DIFFERENT machine -> added, and this is the answer the receipt exists to grow'
Assert-Equal 2 @($m.Events).Count 'two machines, two events'

# MIGRATION: a pre-digest event gains one and KEEPS ITS DAY, but only when the available evidence --
# file count and byte total -- says the content is the same content.
$v1Event = @([pscustomobject]@{ ArchivedUtc = '2026-08-21T10:00:00Z'; Machine = 'M1'; Files = 5; Bytes = 100; ContentSha = '' })
$m = Merge-ThemeArchiveEvent -Events $v1Event -ArchivedUtc '2026-09-01T00:00:00Z' -Machine 'M1' -Files 5 -Bytes 100 -ContentSha $shaA
Assert-Equal 'migrated' $m.Change 'a digest-less event with matching counts -> migrated'
Assert-Equal '2026-08-21T10:00:00Z' @($m.Events)[0].ArchivedUtc 'and it KEEPS its recorded day'
Assert-Equal $shaA @($m.Events)[0].ContentSha 'while gaining the digest it never recorded'

$m = Merge-ThemeArchiveEvent -Events $v1Event -ArchivedUtc '2026-09-01T00:00:00Z' -Machine 'M1' -Files 9 -Bytes 400 -ContentSha $shaA
Assert-Equal 'replaced' $m.Change 'a digest-less event whose counts DIFFER is replaced, not migrated -- the day is no longer the day those bytes landed'

# MACHINE NAMES ARE CASE-INSENSITIVE ON WINDOWS, so two spellings must not become two events claiming
# two copies -- and the spelling already in the file wins, so a receipt does not churn over nothing.
$m = Merge-ThemeArchiveEvent -Events $existing -ArchivedUtc '2026-09-01T00:00:00Z' -Machine 'm1' -Files 5 -Bytes 100 -ContentSha $shaA
Assert-Equal 1 @($m.Events).Count 'a differently-cased machine name is the SAME machine'
Assert-Equal 'M1' @($m.Events)[0].Machine 'and the recorded spelling is kept'

$unsorted = @(
    [pscustomobject]@{ ArchivedUtc = '2026-09-05T00:00:00Z'; Machine = 'M3'; Files = 1; Bytes = 1; ContentSha = $shaB },
    [pscustomobject]@{ ArchivedUtc = '2026-08-01T00:00:00Z'; Machine = 'M2'; Files = 1; Bytes = 1; ContentSha = $shaB }
)
$m = Merge-ThemeArchiveEvent -Events $unsorted -ArchivedUtc '2026-09-01T00:00:00Z' -Machine 'M1' -Files 1 -Bytes 1 -ContentSha $shaA
Assert-Equal '2026-08-01T00:00:00Z' @($m.Events)[0].ArchivedUtc 'events come back oldest-first, whatever order they arrived in'
Assert-Equal '2026-09-05T00:00:00Z' @($m.Events)[2].ArchivedUtc 'and newest last -- ISO-8601 UTC sorts lexically as it sorts chronologically'

# --------------------------------------------------------------------------------------------------
Write-Host "`nFormat-ThemeArchiveManifest -- every byte of the receipt" -ForegroundColor Cyan
# --------------------------------------------------------------------------------------------------
$fmtRecords = @(
    [pscustomobject]@{ RelativePath = 'layout/theme.liquid';   Bytes = 5;  Sha256 = $shaA },
    [pscustomobject]@{ RelativePath = 'sections/header.liquid'; Bytes = 10; Sha256 = $shaB }
)
$fmtEvents = @([pscustomobject]@{ ArchivedUtc = '2026-08-21T10:00:00Z'; Machine = 'M1'; Files = 2; Bytes = 15; ContentSha = (Get-ThemeArchiveContentDigest -Records $fmtRecords) })

$text = Format-ThemeArchiveManifest -ThemeId '123' -ThemeName 'Impact' -Role 'unpublished' -Store 'x.myshopify.com' `
    -Folder 'Impact-123' -Events $fmtEvents -Records $fmtRecords

Assert-True ($text -match '(?m)^theme-id:     123$')   'the theme id is a header field'
Assert-True ($text -match '(?m)^folder:       Impact-123$') 'so is the folder'
Assert-True ($text -match '(?m)^files:        2$')     'so is the file count'
Assert-True ($text -match '(?m)^bytes:        15$')    'and the byte total is the sum of the records'
Assert-True ($text -match [regex]::Escape('archived: 2026-08-21T10:00:00Z  M1  2  15  ')) 'the event renders with its five fields'
Assert-True ($text -match [regex]::Escape('a' * 64 + '  5  layout/theme.liquid')) 'and each file renders as sha, bytes, path'

# THE DIGEST NAMES THE BODY WRITTEN DIRECTLY BELOW IT, which is why it is computed here from the
# records this call renders rather than accepted as a parameter -- the two cannot then disagree.
Assert-True ($text -match ('(?m)^content-sha256: ' + (Get-ThemeArchiveContentDigest -Records $fmtRecords) + '$')) `
    'the header digest is the digest of the body this same call rendered'

Assert-True ($text -notmatch "`r") 'newlines are LF, never CRLF -- a digest folded over CRLF would differ between two checkouts'
Assert-True ($text.EndsWith("`n")) 'and the text ends with one'
Assert-True ($text -notmatch '(?m)^archived-utc:') 'there is NO single archived-utc field beside the log -- the single field WAS the bug'
Assert-True ($text -notmatch '(?m)^machine:') 'and no single machine field either'

# PURE: no clock, no environment. Same facts in, same bytes out -- which is what lets a genuine no-op
# write byte-identical content and leave no diff.
$again = Format-ThemeArchiveManifest -ThemeId '123' -ThemeName 'Impact' -Role 'unpublished' -Store 'x.myshopify.com' `
    -Folder 'Impact-123' -Events $fmtEvents -Records $fmtRecords
Assert-Equal $text $again 'the render is deterministic -- a re-run over unchanged facts leaves no diff'

$withNull = Format-ThemeArchiveManifest -ThemeId '123' -Folder 'Impact-123' -Events @($null) -Records $fmtRecords
Assert-True ($withNull -notmatch '(?m)^archived:\s*$') 'a null event is skipped rather than rendered as a machine nobody can name'

# THE SAME UNROLL ON THE RECORDS SIDE. An empty walk binds as $null, '@($null)' unrolls to one blank
# element, and without the filter the receipt asserted one file that is nowhere -- in a COMMITTED file
# whose whole job is saying what an archive held.
$nullRecords = Format-ThemeArchiveManifest -ThemeId '123' -Folder 'Impact-123' -Events $fmtEvents -Records @($null)
Assert-True ($nullRecords -match '(?m)^files:        0$') 'a phantom null record does not count itself into the file total'
Assert-True ($nullRecords -match '(?m)^bytes:        0$') 'nor into the byte total'
Assert-True ($nullRecords -match '(?m)^content-sha256: $') 'and the digest stays empty -- an unverified archive must not acquire a fingerprint'

# THE VERIFIER IS NAMED ONLY WHERE A CALLER SAYS IT HAS ONE. A receipt pointing at a script that does
# not exist in this repo is a receipt a reader stops trusting.
$noVerifier = Format-ThemeArchiveManifest -ThemeId '123' -Folder 'Impact-123' -Events $fmtEvents -Records $fmtRecords
Assert-True ($noVerifier -notmatch 'verify-archive') 'with no verifier seam the receipt names no tool'
$withVerifier = Format-ThemeArchiveManifest -ThemeId '123' -Folder 'Impact-123' -Events $fmtEvents -Records $fmtRecords -VerifierPath 'scripts/theme/verify-archive.ps1'
Assert-True ($withVerifier -match [regex]::Escape('scripts/theme/verify-archive.ps1')) 'and names it where the consumer answered one'

# --------------------------------------------------------------------------------------------------
Write-Host "`nThe round trip -- render, read back, re-merge" -ForegroundColor Cyan
# --------------------------------------------------------------------------------------------------
# THIS IS THE CASE THE UNITS CANNOT SEE. The phantom-event defect had every unit green: the unroll
# happened at a PARAMETER BOUNDARY, not inside the expression the unit measured. Only rendering,
# reading back and merging again catches a composition that is wrong in the middle.
$digest = Get-ThemeArchiveContentDigest -Records $fmtRecords
$first  = Merge-ThemeArchiveEvent -Events (Get-ThemeArchiveEvents -Text '') -ArchivedUtc '2026-08-21T10:00:00Z' -Machine 'M1' -Files 2 -Bytes 15 -ContentSha $digest
$round1 = Format-ThemeArchiveManifest -ThemeId '123' -ThemeName 'Impact' -Folder 'Impact-123' -Events $first.Events -Records $fmtRecords

$readBack = Get-ThemeArchiveEvents -Text $round1
Assert-Equal 1 @($readBack).Count 'the rendered receipt reads back as exactly one event'
Assert-Equal 'M1' @($readBack)[0].Machine 'with its machine intact'
Assert-Equal $digest @($readBack)[0].ContentSha 'and its digest intact'

$second = Merge-ThemeArchiveEvent -Events $readBack -ArchivedUtc '2026-09-13T00:00:00Z' -Machine 'M1' -Files 2 -Bytes 15 -ContentSha $digest
Assert-Equal 'kept' $second.Change 'a second run over unchanged content is KEPT'
$round2 = Format-ThemeArchiveManifest -ThemeId '123' -ThemeName 'Impact' -Folder 'Impact-123' -Events $second.Events -Records $fmtRecords
Assert-Equal $round1 $round2 'and renders byte-identical -- the property that makes the receipt readable at all'

# AND THE MIGRATION ROUND TRIP: a pre-digest receipt rendered with '-' must survive being read back.
$v1Rendered = Format-ThemeArchiveManifest -ThemeId '123' -Folder 'Impact-123' `
    -Events @([pscustomobject]@{ ArchivedUtc = '2026-08-21T10:00:00Z'; Machine = 'M1'; Files = 2; Bytes = 15; ContentSha = '' }) -Records $fmtRecords
Assert-True ($v1Rendered -match [regex]::Escape('  15  -')) "a digest-less event renders its digest as '-'"
$v1Read = Get-ThemeArchiveEvents -Text $v1Rendered
Assert-Equal 1 @($v1Read).Count 'and reads back rather than vanishing'
$migrated = Merge-ThemeArchiveEvent -Events $v1Read -ArchivedUtc '2026-09-13T00:00:00Z' -Machine 'M1' -Files 2 -Bytes 15 -ContentSha $digest
Assert-Equal 'migrated' $migrated.Change 'then migrates on the next ordinary run'
Assert-Equal '2026-08-21T10:00:00Z' @($migrated.Events)[0].ArchivedUtc 'keeping the day it was written'

# --------------------------------------------------------------------------------------------------
Write-Host "`nFormat-ThemeDeleteCommand -- the line a caller actually pastes" -ForegroundColor Cyan
# --------------------------------------------------------------------------------------------------
# WHY THIS IS TESTED AT ALL: it replaced a format string whose three defects -- no marker, no --force,
# and a false sentence above them -- survived a repair pass over the very file it lived in. Its failure
# mode is a GUARD refusal, which reads as the rule rather than as a typo, so somebody meeting it goes
# editing config that was already correct.
$cmd = Format-ThemeDeleteCommand -Store 's.myshopify.com' -ThemeId '123' -ThemeName 'Impact' -DeleteMarker 'STORE-THEME-DELETE-AUTHORIZED'
Assert-True ($cmd -match '--force') '--force is ALWAYS present -- without it the CLI prompts, and a session cannot answer a prompt'
Assert-True ($cmd -match [regex]::Escape('STORE-THEME-DELETE-AUTHORIZED')) 'the marker is present when the seam is answered'
Assert-True ($cmd.IndexOf('STORE-THEME-DELETE-AUTHORIZED') -lt $cmd.IndexOf('Impact')) `
    'and the NAME trails the marker -- it used to BE the comment, which is how the marker went missing'
Assert-True ($cmd -match [regex]::Escape('--store s.myshopify.com')) 'the store is passed'
Assert-True ($cmd -match [regex]::Escape('--theme 123')) 'and the theme id'

$noName = Format-ThemeDeleteCommand -Store 's.myshopify.com' -ThemeId '123' -DeleteMarker 'MARKER'
Assert-True ($noName -match [regex]::Escape('# MARKER')) 'with no name the comment holds the marker alone'
Assert-True ($noName -notmatch '\(\)') 'and no empty parentheses are left dangling'

$noMarker = Format-ThemeDeleteCommand -Store 's.myshopify.com' -ThemeId '123' -ThemeName 'Impact'
Assert-True ($noMarker -match [regex]::Escape('# (Impact)')) 'with the seam UNANSWERED the comment holds the name alone'
Assert-True ($noMarker -match '--force') 'and --force is still printed -- two spellings of the same command is how they drift apart again'

$bare = Format-ThemeDeleteCommand -Store 's.myshopify.com' -ThemeId '123'
Assert-True ($bare -notmatch '#') 'with neither, there is no dangling "# " at all'

# A COMMENT IS TERMINATED BY A LINE BREAK, so a name carrying one would split the command in two and
# leave the caller pasting the garbage half. Real theme names already carry slashes and stray spaces,
# so "no theme is named like that" is not an assumption this may make.
$multiline = Format-ThemeDeleteCommand -Store 's.myshopify.com' -ThemeId '123' -ThemeName "Impact`r`n rm -rf" -DeleteMarker 'MARKER'
Assert-True ($multiline -notmatch "`n") 'a newline in the theme name collapses -- the command comes back as exactly ONE line'
Assert-True ($multiline -match [regex]::Escape('Impact rm -rf')) 'with the whitespace run collapsed to a single space'

# --------------------------------------------------------------------------------------------------
Write-Host "`nGet-ExternalThemeWarning -- the one place neither converged copy was right" -ForegroundColor Cyan
# --------------------------------------------------------------------------------------------------
# ONE COPY REFUSED THE ARCHIVE for a third party's theme, which is strictness with no subject: it never
# removed anything, and a local read-only backup harms nobody. The OTHER dropped the gate and printed
# the removal command for such a theme without a word -- which is the command that breaks a live
# integration. So: the archive is never gated, the command is never suppressed, and the caller is told.
Assert-Equal '' (Get-ExternalThemeWarning -Name 'theme-vendor/feat/x' -ExternalPrefixes @()) `
    'with no prefixes declared -- the ordinary case -- nothing is warned about'
Assert-Equal '' (Get-ExternalThemeWarning -Name 'theme-vendor/feat/x' -ExternalPrefixes $null) 'and a null seam answer does the same'

$warn = Get-ExternalThemeWarning -Name 'theme-vendor/feat/x' -ExternalPrefixes @('theme-vendor/')
Assert-True ($warn -ne '') 'a theme whose name starts with a declared prefix warns'
Assert-True ($warn -match [regex]::Escape('theme-vendor/')) 'and the warning names the prefix that matched'
Assert-True ($warn -match 'integration') 'and says what is at risk, which is the integration rather than the files'

Assert-True ((Get-ExternalThemeWarning -Name 'THEME-VENDOR/feat/x' -ExternalPrefixes @('theme-vendor/')) -ne '') `
    'the match is case-insensitive -- theme names are typed by people'
Assert-Equal '' (Get-ExternalThemeWarning -Name 'Impact' -ExternalPrefixes @('theme-vendor/')) 'an unrelated theme does not warn'
Assert-Equal '' (Get-ExternalThemeWarning -Name 'x-theme-vendor/feat' -ExternalPrefixes @('theme-vendor/')) `
    'the match is a PREFIX, not a substring -- that is the shape a Shopify git integration produces'
Assert-Equal '' (Get-ExternalThemeWarning -Name '' -ExternalPrefixes @('theme-vendor/')) 'an empty theme name does not warn'
Assert-True ((Get-ExternalThemeWarning -Name 'theme-vendor/x' -ExternalPrefixes @($null, '', 'theme-vendor/')) -ne '') `
    'nulls and blanks in the seam answer are skipped rather than matching everything'

# --------------------------------------------------------------------------------------------------
Write-Host "`nReading a receipt back -- the three rules with no caller in this plugin" -ForegroundColor Cyan
# --------------------------------------------------------------------------------------------------
Assert-Equal '123' (Get-ThemeArchiveManifestField -Text $text -Name 'theme-id') 'a header field is read'
Assert-Equal 'Impact-123' (Get-ThemeArchiveManifestField -Text $text -Name 'folder') 'and so is another'
Assert-Equal '' (Get-ThemeArchiveManifestField -Text $text -Name 'nosuchfield') 'an absent field is the empty string, not an error'
# THE ANCHOR IS WHAT KEEPS THE HEADER PROSE OUT: every comment line starts with '#', which '^' excludes,
# and the header prose contains the word 'folder' several times.
Assert-Equal '' (Get-ThemeArchiveManifestField -Text '# folder: not-this' -Name 'folder') 'a COMMENT line can never satisfy the field match'

$parsed = Get-ThemeArchiveManifestFileRecords -Text $text
Assert-Equal 2 @($parsed).Count 'the file list parses back out of a rendered receipt'
Assert-Equal 'layout/theme.liquid' (@($parsed)[0].RelativePath) 'with its path'
Assert-Equal 5 (@($parsed)[0].Bytes) 'and its byte count'
Assert-Equal $shaA (@($parsed)[0].Sha256) 'and its digest'

$spaced = ('c' * 64) + '  12  assets/my file name.png'
Assert-Equal 'assets/my file name.png' (@(Get-ThemeArchiveManifestFileRecords -Text $spaced)[0].RelativePath) `
    'a path with SPACES survives -- the path is everything after the byte count, not a third whitespace field'
# THE ARGUMENT IS BUILT IN A VARIABLE FIRST, and that is not style. Written inline as
# '-Text 'archived: ...  ' + ('a' * 64)' PowerShell parses the '+' and the digest as two further
# ARGUMENTS rather than as a concatenation -- and because this function is a simple function, they land
# silently in $args. The assert then passes while measuring a line with no digest in it at all, which is
# the one thing it exists to discriminate on.
$eventLine = 'archived: 2026-08-21T10:00:00Z  M1  2  15  ' + ('a' * 64)
Assert-Equal 0 @(Get-ThemeArchiveManifestFileRecords -Text $eventLine).Count `
    'an EVENT line carrying a real 64-character digest is still not a file record -- the digest has to be the FIRST field'
$headerLine = '# sha256  bytes  path'
Assert-Equal 0 @(Get-ThemeArchiveManifestFileRecords -Text $headerLine).Count 'and the header comment is not one either'

# --------------------------------------------------------------------------------------------------
Write-Host "`nCompare-ThemeArchiveWithManifest -- is a recovered copy intact" -ForegroundColor Cyan
# --------------------------------------------------------------------------------------------------
$expected = @(
    [pscustomobject]@{ RelativePath = 'layout/theme.liquid';    Bytes = 5;  Sha256 = $shaA },
    [pscustomobject]@{ RelativePath = 'sections/header.liquid'; Bytes = 10; Sha256 = $shaB }
)

$r = Compare-ThemeArchiveWithManifest -Expected $expected -Actual $expected
Assert-Equal 'clean' $r.Verdict 'an identical folder is clean'
Assert-Equal 2 $r.Matched 'and both files matched'

$missingOne = @($expected[0])
$r = Compare-ThemeArchiveWithManifest -Expected $expected -Actual $missingOne
Assert-Equal 'damaged' $r.Verdict 'a missing file is DAMAGED -- an archive that has lost part of itself while still looking like a backup'
Assert-Equal 1 @($r.Missing).Count 'and it is named'

$changedOne = @(
    $expected[0],
    [pscustomobject]@{ RelativePath = 'sections/header.liquid'; Bytes = 0; Sha256 = 'c' * 64 }
)
$r = Compare-ThemeArchiveWithManifest -Expected $expected -Actual $changedOne
Assert-Equal 'damaged' $r.Verdict 'a changed file is damaged too -- worse than missing, because a restore from it would SUCCEED and be wrong'
Assert-Equal 10 (@($r.Changed)[0].ExpectedBytes) 'and the reason printed carries the expected size'
Assert-Equal 0 (@($r.Changed)[0].ActualBytes) 'beside what is actually there'

$withExtra = @($expected) + @([pscustomobject]@{ RelativePath = 'stray.tmp'; Bytes = 1; Sha256 = 'd' * 64 })
$r = Compare-ThemeArchiveWithManifest -Expected $expected -Actual $withExtra
Assert-Equal 'clean' $r.Verdict 'an EXTRA file is reported and is not a failure -- a check red on a folder that has everything it promised cries wolf'
Assert-Equal 1 @($r.Extra).Count 'but it is reported'

$r = Compare-ThemeArchiveWithManifest -Expected @() -Actual $expected
Assert-Equal 'unknown' $r.Verdict 'an empty receipt is UNKNOWN, never a clean verdict -- there was nothing to have verified'

$caseOnly = @([pscustomobject]@{ RelativePath = 'Layout/theme.liquid'; Bytes = 5; Sha256 = $shaA })
$r = Compare-ThemeArchiveWithManifest -Expected @($expected[0]) -Actual $caseOnly
Assert-Equal 'damaged' $r.Verdict 'a path differing only in CASE is not the same file -- ordinal and case-sensitive, matching git'
Assert-Equal 1 @($r.Missing).Count 'reported loudly as one missing'
Assert-Equal 1 @($r.Extra).Count 'and one extra, rather than quietly treated as a match'

} finally {
    foreach ($d in $script:trees) {
        if ($d -and (Test-Path -LiteralPath $d)) {
            Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host "FAILED: $($script:fail) of $($script:pass + $script:fail) asserts." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
