<#
.SYNOPSIS
    Tests for scripts/lib/live-record-lib.ps1 -- the live-push record's format, its parser, and the
    rules both documents of a cut apply to it (#2570, #2586).

.DESCRIPTION
    WHAT THIS SUITE IS ACTUALLY GUARDING. One record decides two documents -- the GitHub Release body's
    'What landed' / 'Not live yet' split, and the audience note's solved-task list -- and at a BWJ
    store's v1.3.0 the two disagreed, because each was built from its own separate reading of what the
    live push actually carried. So the asserts below weight the REFUSALS as heavily as the happy path: a
    line the parser cannot read, a path listed as both live and hold, a merge commit that cannot be
    found -- because a silently wrong answer here reproduces the exact defect this file exists to close.

    Pure -- no git, no gh, no file IO in the lib itself -- so nothing here touches a network, a process
    or the repo's own tree. Dependency-free (no Pester), same style as the rest of the suite.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/live-record-lib.tests.ps1

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$LibPath  = Join-Path $RepoRoot 'scripts\lib\live-record-lib.ps1'

$script:pass = 0
$script:fail = 0

function Assert-Equal {
    param($Expected, $Actual, [string]$Label)
    if ("$Expected" -eq "$Actual") { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}
function Assert-True {
    param([bool]$Condition, [string]$Label)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label" -ForegroundColor Red }
}
function Assert-Throws {
    param([scriptblock]$Action, [string]$Label, [string]$Contains = '')
    try {
        & $Action | Out-Null
        $script:fail++; Write-Host "  [FAIL] $Label (nothing was thrown)" -ForegroundColor Red
    } catch {
        if ($Contains -and -not ([string]$_.Exception.Message).Contains($Contains)) {
            $script:fail++; Write-Host "  [FAIL] $Label (thrown, but the message does not carry '$Contains')`n         got: $($_.Exception.Message)" -ForegroundColor Red
        } else {
            $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green
        }
    }
}

Assert-True (Test-Path -LiteralPath $LibPath) 'live-record-lib.ps1 exists at its registered source path'
. $LibPath

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'ConvertTo-LiveRecordKey -- the one comparison key every reader below shares' -ForegroundColor Cyan

Assert-Equal 'sections/header.liquid' (ConvertTo-LiveRecordKey 'sections\header.liquid') 'a backslash path is normalised to forward slashes'
Assert-Equal 'sections/header.liquid' (ConvertTo-LiveRecordKey '  sections/header.liquid  ') 'and trimmed'
Assert-Equal '' (ConvertTo-LiveRecordKey $null) 'a null path is the empty key'
Assert-Equal '' (ConvertTo-LiveRecordKey '') 'and so is an empty one'

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'Format-LivePushRecord -- one line per theme file, from Get-LivePushRows-shaped rows' -ForegroundColor Cyan

$rows = @(
    [pscustomobject]@{ Path = 'sections/header.liquid';        Kind = 'theme-file' },
    [pscustomobject]@{ Path = 'sections/media-with-text.liquid'; Kind = 'sync-owned' },
    [pscustomobject]@{ Path = 'locales/es.json';                Kind = 'deleted' },
    [pscustomobject]@{ Path = 'scripts/x.ps1';                  Kind = 'not-a-theme-path' }
)
$record = Format-LivePushRecord -Rows $rows -Range 'v1.3.0..HEAD'
$expectedLines = @(
    '# live-push record -- written by live-preflight for v1.3.0..HEAD',
    '# One line per theme file in the range: "live <path>" is on the live theme after this push,',
    '# "hold <path>" is not. If you hold a file back from the push, change its "live" to "hold".',
    '# A deleted file is "hold" from the start: a push cannot remove a file from live.',
    '# cut-release reads this file (-LivePushRecord) for the GitHub body and the audience note.',
    'live sections/header.liquid',
    'live sections/media-with-text.liquid',
    'hold locales/es.json'
)
Assert-Equal (($expectedLines -join "`n") + "`n") $record `
    'the record is exactly the header plus one line per theme-file/sync-owned/deleted row, in order -- not-a-theme-path gets no line'

# THE HEADER NAMES THE RANGE ONLY WHEN ONE WAS GIVEN, because a record left over from an earlier release
# should be recognisable as one -- a header with no range at all is not that claim.
$noRange = Format-LivePushRecord -Rows @([pscustomobject]@{ Path = 'assets/theme.css'; Kind = 'theme-file' })
Assert-True $noRange.StartsWith("# live-push record -- written by live-preflight`n") 'an empty -Range leaves the header without " for ..."'

# NO ROWS AT ALL still produces the five header lines and nothing else -- a record is always a valid,
# readable (if empty) document.
$emptyRecord = Format-LivePushRecord
Assert-Equal 5 (@(($emptyRecord -split "`n") | Where-Object { $_ })).Count 'no rows at all still produces the five header lines and nothing else'
Assert-True $emptyRecord.EndsWith("`n") 'and ends in exactly one newline'
Assert-Equal 5 (@(($emptyRecord -split "`n") | Where-Object { $_ })).Count 'and a null -Rows reads the same as no rows' # (default parameter)

# A NULL ROW AND A BLANK PATH ARE BOTH SKIPPED, silently -- neither is a theme file to report on.
$skipRows = @($null, [pscustomobject]@{ Path = ''; Kind = 'theme-file' }, [pscustomobject]@{ Path = '  '; Kind = 'theme-file' }, [pscustomobject]@{ Path = 'assets/x.css'; Kind = 'theme-file' })
$skipped = Format-LivePushRecord -Rows $skipRows
Assert-Equal 1 (@(($skipped -split "`n") | Where-Object { $_ -match '^(live|hold) ' })).Count 'a null row and two blank paths are skipped -- only the real one becomes a line'

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'ConvertFrom-LivePushRecord -- the record parsed back, and refused rather than skipped on a bad line' -ForegroundColor Cyan

$parsed = ConvertFrom-LivePushRecord -Text $record
Assert-Equal 2 (@($parsed.Live)).Count 'two live paths'
Assert-Equal 'sections/header.liquid' $parsed.Live[0] 'first live path, in document order'
Assert-Equal 'sections/media-with-text.liquid' $parsed.Live[1] 'second live path'
Assert-Equal 1 (@($parsed.Hold)).Count 'one hold path'
Assert-Equal 'locales/es.json' $parsed.Hold[0] 'the hold path'

# COMMENTS AND BLANK LINES ARE IGNORED, exactly as the writer's own header intends.
$withBlanks = "# a comment`n`nlive a.liquid`n`n# another`nhold b.liquid`n"
$parsedBlanks = ConvertFrom-LivePushRecord -Text $withBlanks
Assert-Equal 1 (@($parsedBlanks.Live)).Count 'a comment and a blank line are not entries'
Assert-Equal 1 (@($parsedBlanks.Hold)).Count 'and the real lines around them are still read'

# BACKSLASHES AND CASE: normalised on the way in, exactly as on the way out.
$mixedSep = ConvertFrom-LivePushRecord -Text "live sections\header.liquid`n"
Assert-Equal 'sections/header.liquid' $mixedSep.Live[0] 'a backslash path is normalised on parse, like on write'

# DUPLICATES OF THE SAME VERB COLLAPSE rather than double-counting -- a record hand-edited twice for the
# same path under the same verb is not two facts.
$dup = ConvertFrom-LivePushRecord -Text "live a.liquid`nlive a.liquid`n"
Assert-Equal 1 (@($dup.Live)).Count 'the same path repeated under the same verb is one entry'

# A PATH ON BOTH VERBS IS REFUSED, not resolved either way -- a 'hold' added under a 'live' that was not
# removed is the second likely hand-edit, and letting either one silently win decides the question for
# the person instead of asking them.
Assert-Throws -Action { ConvertFrom-LivePushRecord -Text "live a.liquid`nhold a.liquid`n" } `
    -Label 'a path listed as both live and hold is refused' -Contains 'both'

# A LINE THAT IS NEITHER A COMMENT, BLANK, ''live'' NOR ''hold'' IS REFUSED BY LINE NUMBER, not skipped
# -- skipping it would read the file as live, exactly the claim the record exists to stop.
Assert-Throws -Action { ConvertFrom-LivePushRecord -Text "live a.liquid`nhodl b.liquid`n" } `
    -Label 'a typo''d verb is refused rather than silently skipped' -Contains 'line 2'
Assert-Throws -Action { ConvertFrom-LivePushRecord -Text 'not a valid line at all' } `
    -Label 'a document with only an unreadable line is refused too' -Contains 'line 1'

Assert-Equal 0 (@((ConvertFrom-LivePushRecord -Text '').Live)).Count 'empty text parses to nothing, not a throw'
Assert-Equal 0 (@((ConvertFrom-LivePushRecord -Text $null).Live)).Count 'and neither does a null one'

# CRLF IS ACCEPTED, same as LF -- a record hand-edited on Windows must still parse.
$crlf = ConvertFrom-LivePushRecord -Text "live a.liquid`r`nhold b.liquid`r`n"
Assert-Equal 1 (@($crlf.Live)).Count 'CRLF line endings parse the same as LF, for Live'
Assert-Equal 1 (@($crlf.Hold)).Count '...and for Hold'

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'Find-BranchMergeCommit -- the sha of the merge that landed a branch, newest match wins' -ForegroundColor Cyan

$logLines = @(
    "sha3`tmerge: fix/b (#20)",
    "sha2`tmerge: fix/a (#11)",
    "sha1`tfeat: unrelated work",
    "sha0`tmerge: fix/a (#5)"
)
Assert-Equal 'sha2' (Find-BranchMergeCommit -LogLines $logLines -Branch 'fix/a') 'the newest matching merge wins -- git log prints newest first, and the first match is the newest'
Assert-Equal 'sha3' (Find-BranchMergeCommit -LogLines $logLines -Branch 'fix/b') 'a different branch is matched independently'
Assert-Equal '' (Find-BranchMergeCommit -LogLines $logLines -Branch 'fix/c') 'no merge for this branch at all -> empty, not a guess'
Assert-Equal '' (Find-BranchMergeCommit -LogLines $logLines -Branch '') 'an empty branch name matches nothing'
Assert-Equal '' (Find-BranchMergeCommit -LogLines $logLines -Branch $null) 'nor does a null one'
Assert-Equal '' (Find-BranchMergeCommit -LogLines @() -Branch 'fix/a') 'no log lines at all -> empty'
Assert-Equal '' (Find-BranchMergeCommit -LogLines $null -Branch 'fix/a') 'and neither does a null log-lines list'

# A DIFFERENT BRANCH SHARING A PREFIX MUST NOT MATCH -- the docstring's own warning, pinned.
$prefixLines = @("shaX`tmerge: fix/a-longer (#7)")
Assert-Equal '' (Find-BranchMergeCommit -LogLines $prefixLines -Branch 'fix/a') 'a branch that only shares a prefix with another is not matched'

# A LINE WITH NO TAB, OR A NULL LINE, IS SKIPPED RATHER THAN FATAL.
$malformedLine = @('no-tab-here', "sha9`tmerge: fix/a (#1)")
Assert-Equal 'sha9' (Find-BranchMergeCommit -LogLines $malformedLine -Branch 'fix/a') 'a line with no tab is skipped, not fatal'
Assert-Equal 'sha9' (Find-BranchMergeCommit -LogLines @($null, "sha9`tmerge: fix/a (#1)") -Branch 'fix/a') 'a null log line is skipped too'

# A SUBJECT THAT ONLY RESEMBLES THE SHAPE does not match -- the exact shape ship-pr writes, or nothing.
$nearMiss = @("shaN`tmerge:fix/a (#1)", "shaM`tmerge: fix/a (#1) extra")
Assert-Equal '' (Find-BranchMergeCommit -LogLines $nearMiss -Branch 'fix/a') 'the subject must match the exact shape ship-pr writes, not a near miss'

# WHITESPACE AROUND THE SUBJECT AND THE SHA IS TRIMMED before either is compared or returned.
Assert-Equal 'sha7' (Find-BranchMergeCommit -LogLines @("  sha7  `t  merge: fix/a (#9)  ") -Branch 'fix/a') 'leading/trailing whitespace on either field is trimmed'

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'Get-EntryLiveState -- whether one entry is live, from its changed paths against a parsed record' -ForegroundColor Cyan

$liveRecordParsed = ConvertFrom-LivePushRecord -Text "live sections/header.liquid`nhold snippets/footer.liquid`n"

$unknown = Get-EntryLiveState -ChangedPaths $null -Record $liveRecordParsed
Assert-Equal 'unknown' $unknown.State '$null changed paths -- the merge commit could not be found -- reads as unknown, not live'
Assert-Equal $false $unknown.Storefront 'an unknown entry is not reported as a storefront change either'
Assert-Equal 0 (@($unknown.RecordPaths)).Count 'and carries no record paths'
Assert-Equal 0 (@($unknown.HeldPaths)).Count 'nor any held paths'

$liveState = Get-EntryLiveState -ChangedPaths @('sections/header.liquid') -Record $liveRecordParsed
Assert-Equal 'live' $liveState.State 'a path the record lists as live -> live'
Assert-Equal $true $liveState.Storefront 'and it touched a path the record names, so it is a storefront change'
Assert-Equal 0 (@($liveState.HeldPaths)).Count 'nothing held'

$heldState = Get-EntryLiveState -ChangedPaths @('sections/header.liquid', 'snippets/footer.liquid') -Record $liveRecordParsed
Assert-Equal 'not-live' $heldState.State 'ONE held path decides it -- an entry is a change a reader checks as a whole'
Assert-Equal 1 (@($heldState.HeldPaths)).Count 'the held path is named'
Assert-Equal 'snippets/footer.liquid' $heldState.HeldPaths[0] 'and it is the one that was actually held'
Assert-Equal 2 (@($heldState.RecordPaths)).Count 'both record-known paths are reported, live and held alike'

$noStorefront = Get-EntryLiveState -ChangedPaths @('scripts/task/build.ps1') -Record $liveRecordParsed
Assert-Equal 'live' $noStorefront.State 'a path the record does not name is live in the trivial sense -- nothing of it is held'
Assert-Equal $false $noStorefront.Storefront 'but it is not a storefront change -- the record does not know this path at all'
Assert-Equal 0 (@($noStorefront.RecordPaths)).Count 'and it contributes no record path'

# CASE-INSENSITIVE AND SEPARATOR-NORMALISED comparison, like every other reader of this record.
$caseState = Get-EntryLiveState -ChangedPaths @('SECTIONS/HEADER.LIQUID') -Record $liveRecordParsed
Assert-Equal 'live' $caseState.State 'matched case-insensitively'
$backslashState = Get-EntryLiveState -ChangedPaths @('snippets\footer.liquid') -Record $liveRecordParsed
Assert-Equal 'not-live' $backslashState.State 'and with backslash separators normalised before comparison'

# AN EMPTY (BUT NON-NULL) CHANGED-PATHS LIST IS A REAL ANSWER: the merge WAS found and it touched
# nothing the record names -- still 'live', never 'unknown'.
$emptyPaths = Get-EntryLiveState -ChangedPaths @() -Record $liveRecordParsed
Assert-Equal 'live' $emptyPaths.State 'an empty (but non-null) changed-paths list is live, not unknown -- the merge was found'
Assert-Equal $false $emptyPaths.Storefront 'and touched nothing the record names'

# A BLANK PATH IN THE CHANGED-PATHS LIST IS IGNORED, same as everywhere else in this lib.
$blankPathState = Get-EntryLiveState -ChangedPaths @('', 'sections/header.liquid') -Record $liveRecordParsed
Assert-Equal 1 (@($blankPathState.RecordPaths)).Count 'a blank changed path contributes nothing'

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'Get-TaskMarkerId -- the id an issue body carries, from its own marker comment' -ForegroundColor Cyan

Assert-Equal 'abc-123' (Get-TaskMarkerId -Body "Some text.`n`n<!-- asana-task: abc-123 -->`n" -Marker 'asana-task') 'the id is read out of the marker comment'
Assert-Equal '' (Get-TaskMarkerId -Body 'No marker here at all.' -Marker 'asana-task') 'no marker at all -> empty'
Assert-Equal '' (Get-TaskMarkerId -Body $null -Marker 'asana-task') 'a null body -> empty, not a throw'
Assert-Equal '' (Get-TaskMarkerId -Body '' -Marker 'asana-task') 'and neither does an empty one'
Assert-Equal '' (Get-TaskMarkerId -Body '<!-- other-marker: abc-123 -->' -Marker 'asana-task') 'a DIFFERENT marker''s comment does not match'
# Extra whitespace inside the comment is tolerated -- a hand-typed marker is exactly where that occurs.
Assert-Equal 'xyz' (Get-TaskMarkerId -Body '<!--   asana-task:    xyz   -->' -Marker 'asana-task') 'extra whitespace around the id is tolerated'
# The id charset is held to letters, digits, '_' and '-' -- it is spliced into a published URL.
Assert-Equal '1234567890' (Get-TaskMarkerId -Body '<!-- asana-task: 1234567890 -->' -Marker 'asana-task') 'a numeric id is read back whole'
Assert-Equal '12345-abcXYZ_9' (Get-TaskMarkerId -Body '<!-- asana-task: 12345-abcXYZ_9 -->' -Marker 'asana-task') 'letters, digits, underscore and hyphen all survive in one id'
Assert-Equal '' (Get-TaskMarkerId -Body '<!-- asana-task: abc; DROP TABLE -->' -Marker 'asana-task') 'a character outside the allowed set before the comment closes means no match at all'

# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host 'Format-ReleaseTaskItems -- one heading + link per solved task, folded to a single-line title' -ForegroundColor Cyan

$items = @(
    [pscustomobject]@{ Title = 'Fix the checkout button'; Url = 'https://example.test/task/1' },
    [pscustomobject]@{ Title = "Multi`nLine`tTitle";      Url = 'https://example.test/task/2' }
)
$formatted = Format-ReleaseTaskItems -Items $items -Label 'Task'
$expectedTaskBody = "### Fix the checkout button`n`n[Task](https://example.test/task/1)`n`n### Multi Line Title`n`n[Task](https://example.test/task/2)"
Assert-Equal $expectedTaskBody $formatted 'one heading and one link line per item, folded to a single line, items joined by a blank line'

Assert-Equal '' (Format-ReleaseTaskItems -Items @() -Label 'Task') 'no items -> empty string'
Assert-Equal '' (Format-ReleaseTaskItems -Items $null -Label 'Task') 'a null item list -> empty string too'

# A FOREIGN TITLE CANNOT INJECT A LINK OR HTML (#2586's security review): an issue title on a public
# tracker is anybody's text, and this one reached a heading verbatim as a working link before the escape.
$hostile = Format-ReleaseTaskItems -Items @([pscustomobject]@{ Title = 'Go to [evil](https://evil.test) <b>'; Url = 'https://x.test' }) -Label 'Task'
Assert-Equal '### Go to \[evil\]\(https://evil.test\) \<b\>' (($hostile -split "`n")[0]) 'markdown and HTML metacharacters in a title are backslash-escaped'
Assert-Equal '[Task](https://x.test)' (($hostile -split "`n")[2]) 'and the link line itself is untouched'

# A NULL ITEM IN THE ARRAY IS SKIPPED rather than fatal.
$withNull = Format-ReleaseTaskItems -Items @($null, [pscustomobject]@{ Title = 'Real one'; Url = 'https://x.test' }) -Label 'Task'
Assert-Equal "### Real one`n`n[Task](https://x.test)" $withNull 'a null item is skipped'

# AN UNTITLED ITEM STILL GETS A HEADING, never an empty one -- the fold's own fallback.
$untitled = Format-ReleaseTaskItems -Items @([pscustomobject]@{ Title = ''; Url = 'https://x.test' }) -Label 'Task'
Assert-Equal "### untitled task`n`n[Task](https://x.test)" $untitled 'a blank title falls back to a named placeholder rather than an empty heading'

# -ENTRYLEVEL CONTROLS THE HEADING DEPTH, and is floored at one hash even if asked for zero or less.
$deep = Format-ReleaseTaskItems -Items @([pscustomobject]@{ Title = 'Deep'; Url = 'https://x.test' }) -Label 'Task' -EntryLevel 4
Assert-Equal "#### Deep`n`n[Task](https://x.test)" $deep '-EntryLevel controls the heading depth'
$floor = Format-ReleaseTaskItems -Items @([pscustomobject]@{ Title = 'Floor'; Url = 'https://x.test' }) -Label 'Task' -EntryLevel 0
Assert-Equal "# Floor`n`n[Task](https://x.test)" $floor '-EntryLevel is floored at one hash even if asked for zero'
$default = Format-ReleaseTaskItems -Items @([pscustomobject]@{ Title = 'Default'; Url = 'https://x.test' }) -Label 'Task'
Assert-Equal "### Default`n`n[Task](https://x.test)" $default 'the default -EntryLevel is 3, matching an entry''s own section level'

# THE LABEL IS WHAT THE LINK TEXT READS -- a repo's own tracker word, not a fixed 'Task'.
$labelled = Format-ReleaseTaskItems -Items @([pscustomobject]@{ Title = 'Labelled'; Url = 'https://x.test' }) -Label 'Asana'
Assert-Equal "### Labelled`n`n[Asana](https://x.test)" $labelled 'the -Label parameter is what the link text reads'

Write-Host ''
if ($script:fail -eq 0) {
    Write-Host "Result: $($script:pass) pass, 0 fail." -ForegroundColor Green
    exit 0
}
Write-Host "Result: $($script:pass) pass, $($script:fail) fail." -ForegroundColor Red
exit 1
