<#
.SYNOPSIS
    Regression tests for scripts/lib/pr-issues-lib.ps1 (the resolves gate's decision table).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Dot-sources the lib and runs a series of
    asserts. Exit code 0 if everything passes, 1 on a failure -- so usable as a CI gate.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/pr-issues.tests.ps1

    What this suite is for: PRs #341, #342 and #343 each repaired issues and each referenced them
    with a PLAIN mention instead of a closing keyword, so eight repaired findings stayed OPEN after
    the merge. The gate in open-pr.ps1 exists to make that unrepeatable, and these asserts are what
    keep the gate honest. Two properties are load-bearing and asserted in BOTH directions:

      1. One closing keyword PER issue. GitHub does not distribute a keyword over a comma list, so a
         'Closes #331, #332' form would close the first and silently leave the second open -- the
         very failure being gated. The block's shape is asserted, not just its content.
      2. PR references are NOT issue mentions. A changelog entry routinely cites the PR it follows
         on from ('as PR #341 established'), and counting those would make the gate cry wolf on
         nearly every branch -- a gate that always fires gets bypassed, which is how it would
         quietly stop working.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\pr-issues-lib.ps1')

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

function Assert-Set {
    <# Compares two int sets order-insensitively, reported as a readable list. #>
    param([int[]]$Expected, [int[]]$Actual, [string]$Name)
    $e = (@($Expected | Sort-Object -Unique) -join ',')
    $a = (@($Actual   | Sort-Object -Unique) -join ',')
    Assert-Equal $e $a $Name
}

function Assert-NameSet {
    <#
        The same comparison for CHECK NAMES rather than issue numbers, and a separate function because
        Assert-Set is [int[]] on purpose: handed 'claude-review' it does not fail the assert, it throws
        a parameter-transformation error mid-suite. Names are compared order-insensitively too -- the
        verdict sorts its lists, and an assert that also pinned the order would fail on a resort that
        changed nothing.
    #>
    param([string[]]$Expected, [string[]]$Actual, [string]$Name)
    $e = (@($Expected | Sort-Object -Unique) -join ',')
    $a = (@($Actual   | Sort-Object -Unique) -join ',')
    Assert-Equal $e $a $Name
}

Write-Host "ConvertTo-IssueNumberList" -ForegroundColor Cyan
# This function exists because `powershell -File` cannot bind an [int[]]: '332,340' arrives as one
# string and casts to 332340, reading the comma as a THOUSANDS SEPARATOR -- silently, no error.
# Measured on Windows PowerShell 5.1 while building the gate; these asserts pin the parser that
# replaced that binding.
Assert-Set @()          (ConvertTo-IssueNumberList -Value '')            'empty string -> no numbers'
Assert-Set @()          (ConvertTo-IssueNumberList -Value $null)         'null -> no numbers'
Assert-Set @(332)       (ConvertTo-IssueNumberList -Value '332')         'single number'
Assert-Set @(332, 340)  (ConvertTo-IssueNumberList -Value '332,340')     'comma list -> BOTH numbers (not 332340)'
Assert-Set @(332, 340)  (ConvertTo-IssueNumberList -Value '332, 340')    'comma + space'
Assert-Set @(332, 340)  (ConvertTo-IssueNumberList -Value '332 340')     'space separated'
Assert-Set @(332, 340)  (ConvertTo-IssueNumberList -Value '332;340')     'semicolon separated'
Assert-Set @(332, 340)  (ConvertTo-IssueNumberList -Value '#332, #340')  'leading # tolerated'
Assert-Set @(332)       (ConvertTo-IssueNumberList -Value '332,332')     'duplicates collapse'
Assert-Set @(331, 332)  (ConvertTo-IssueNumberList -Value '332,331')     'result is sorted'
Assert-Set @()          (ConvertTo-IssueNumberList -Value 'none')        'a word yields nothing (never issue 0)'
Assert-Set @(332)       (ConvertTo-IssueNumberList -Value 'issue 332')   'a number inside prose is still found'

Write-Host "Get-IssueMentions" -ForegroundColor Cyan
Assert-Set @()          (Get-IssueMentions -Text '')                       'empty text -> no mentions'
Assert-Set @()          (Get-IssueMentions -Text $null)                    'null text -> no mentions'
Assert-Set @(332)       (Get-IssueMentions -Text 'fixes the thing in #332') 'a bare #332 is a mention'
Assert-Set @(331, 332)  (Get-IssueMentions -Text '#331 and #332')          'two mentions, both found'
Assert-Set @(332)       (Get-IssueMentions -Text '#332 and again #332')    'duplicates collapse'
Assert-Set @(331, 332)  (Get-IssueMentions -Text '#332 then #331')         'result is sorted'
Assert-Set @(340)       (Get-IssueMentions -Text 'see https://github.com/o/r/issues/340') 'issue LINK is a mention'

# Property 2 -- the anti-cry-wolf direction.
Assert-Set @()  (Get-IssueMentions -Text 'as PR #341 established for this class')       'PR #341 is not an issue mention'
Assert-Set @()  (Get-IssueMentions -Text 'as PRs #341-#343 showed')                     'PRs #341-#343 RANGE form excluded'
Assert-Set @()  (Get-IssueMentions -Text 'PRs #341, #342 and #343 each did it')         'PRs list form excluded across commas and "and"'
Assert-Set @()  (Get-IssueMentions -Text 'pull requests #341 through #343')             'pull requests ... through ... excluded'
# The range scrub must not swallow a following, unrelated mention -- it has to stop at the end of
# the PR list, not run on through the sentence.
Assert-Set @(332) (Get-IssueMentions -Text 'PRs #341-#343 each left #332 open')          'the range scrub stops at the list, #332 still found'
Assert-Set @()  (Get-IssueMentions -Text 'see pull request #341 for the shape')         'pull request #341 excluded'
Assert-Set @()  (Get-IssueMentions -Text '[PR #343](https://github.com/o/r/pull/343)')  'a /pull/ link is not an issue mention'
Assert-Set @(332) (Get-IssueMentions -Text 'PR #341 fixed #332')                        'a real mention alongside a PR reference still counts'

# THE EN AND EM DASH RANGES, which nothing exercised until August 23, 2026. The dash class in
# Get-IssueMentions has carried all three characters since it was written, and only the ASCII hyphen
# was ever asserted -- so the two typographic dashes were live, unmeasured behaviour. That became
# load-bearing the day the class stopped being a literal and started being composed from code points
# ($dashes, for the repo's ASCII rule on .ps1): a composition that silently produced the wrong two
# characters would still match every hyphen assert above and change nothing a suite could see.
# A range written with a real en dash is not exotic -- it is what a word processor and most editors
# produce from '#341-#343' on their own, so a changelog entry pasted from anywhere reaches this path.
# Built from code points here too, for the same reason the lib is.
$enDash = [char]0x2013
$emDash = [char]0x2014
Assert-Set @()    (Get-IssueMentions -Text "as PRs #341$enDash#343 showed")   'PRs #341<en dash>#343 RANGE form excluded'
Assert-Set @()    (Get-IssueMentions -Text "as PRs #341$emDash#343 showed")   'PRs #341<em dash>#343 RANGE form excluded'
Assert-Set @()    (Get-IssueMentions -Text "PR #341$enDash#343 covered it")   'singular PR + en-dash RANGE -> excluded (unambiguous)'
Assert-Set @(332) (Get-IssueMentions -Text "PRs #341$enDash#343 each left #332 open") 'the en-dash range scrub stops at the list, #332 still found'

# --- Three false negatives found in review, each of which defeated the gate silently --------------
# 1. A slash-separated list. The lookbehind used to exclude '#N' after '/', so only the first number
#    in '#334/#329/#335' survived -- on a branch whose entry lists issues that way, the gate would
#    simply not fire for the rest.
Assert-Set @(329, 334, 335, 338) (Get-IssueMentions -Text '#334/#329/#335/#338') 'slash-separated list -> ALL four numbers'
Assert-Set @(326, 340)           (Get-IssueMentions -Text 'the round dossiers #326/#340') 'slash pair -> both numbers'
# 2. A genuine issue right after a SINGULAR PR reference. 'PR #341 and #332' says nothing about #332
#    being a PR, and swallowing it hid a real open issue. A missed mention is the bug the gate exists
#    to prevent; a surplus one only asks a question. So the list scrub needs a PLURAL head.
Assert-Set @(332) (Get-IssueMentions -Text 'This continues the work from PR #341 and #332, an open bug.') 'singular PR + "and #332" -> #332 survives'
Assert-Set @(332) (Get-IssueMentions -Text 'Fixed alongside PR #341, #332 in the same release.')          'singular PR + ", #332" -> #332 survives'
# ...while the plural list form stays excluded, and an unambiguous range does too.
Assert-Set @()    (Get-IssueMentions -Text 'PRs #341, #342 and #343 each did it')  'plural PRs + list -> still excluded'
Assert-Set @()    (Get-IssueMentions -Text 'PR #341-#343 covered it')              'singular PR + dash RANGE -> excluded (unambiguous)'
# 3. Code spans. A doc explaining this gate writes the pattern it explains; GitHub does not link a
#    reference inside backticks, so it is not a mention there either.
Assert-Set @()    (Get-IssueMentions -Text 'the example `#332` is prose')           'a backticked reference is not a mention'
Assert-Set @(340) (Get-IssueMentions -Text 'see `#332` but really #340')            'only the live reference counts'

Write-Host "Remove-MarkdownCodeSpans" -ForegroundColor Cyan
Assert-Equal '' (Remove-MarkdownCodeSpans -Text '')   'empty text -> empty'
Assert-True ((Remove-MarkdownCodeSpans -Text 'a `#332` b') -notmatch '#332') 'inline span blanked'
Assert-True ((Remove-MarkdownCodeSpans -Text 'a `#332` b') -match 'a')       'text around it survives'
Assert-True ((Remove-MarkdownCodeSpans -Text 'a ``#332`` b') -notmatch '#332') 'double-backtick span blanked'
$fencedText = "before`n" + '```' + "`nCloses #332`n" + '```' + "`nafter"
Assert-True ((Remove-MarkdownCodeSpans -Text $fencedText) -notmatch '#332') 'fenced block blanked'
Assert-True ((Remove-MarkdownCodeSpans -Text $fencedText) -match 'before')  'text before the fence survives'
Assert-True ((Remove-MarkdownCodeSpans -Text $fencedText) -match 'after')   'text after the fence survives'
# The filler is deliberately NOT whitespace. With spaces, 'Closes `x` #332' would blank to
# 'Closes     #332' and read as a live declaration -- while GitHub, which needs the keyword directly
# before the reference, closes nothing there. So the filler must break that adjacency...
Assert-True ((Remove-MarkdownCodeSpans -Text 'Closes `x` #332') -notmatch 'Closes\s+#332') 'a span does not leave keyword and reference looking adjacent'
Assert-Equal $false (Test-HasClosingKeyword -Text 'Closes `x` #332') 'a span between keyword and reference -> not a declaration (as on GitHub)'
# ...while still not hiding a reference that follows a span directly (the filler is not a word
# character either, so the mention lookbehind still lets it through).
Assert-Set @(332) (Get-IssueMentions -Text 'see `x`#332') 'a reference straight after a span is still a mention'
Assert-Equal 'a || b' (Remove-MarkdownCodeSpans -Text 'a `` b') 'length is preserved (offsets stay usable)'

Write-Host "Test-HasClosingKeyword" -ForegroundColor Cyan
Assert-Equal $false (Test-HasClosingKeyword -Text 'mentions #332 only')      'a plain mention does NOT count as closing'
Assert-Equal $false (Test-HasClosingKeyword -Text '')                        'empty body closes nothing'
Assert-Equal $true  (Test-HasClosingKeyword -Text 'Closes #332')             'Closes #332 counts'
Assert-Equal $true  (Test-HasClosingKeyword -Text 'closes #332')             'lowercase counts'
Assert-Equal $true  (Test-HasClosingKeyword -Text 'Fixes #332')              'Fixes counts'
Assert-Equal $true  (Test-HasClosingKeyword -Text 'Resolved #332')           'Resolved counts'
Assert-Equal $true  (Test-HasClosingKeyword -Text 'Closes: #332')            'the colon form counts'
Assert-Equal $true  (Test-HasClosingKeyword -Text 'Closes https://github.com/o/r/issues/332') 'the URL form counts'
# The word alone is not a keyword unless it is bound to a reference -- otherwise prose like
# "this closes the gap in #332" would read as a closing declaration GitHub will not honour.
Assert-Equal $false (Test-HasClosingKeyword -Text 'this closes the gap described in issue 332') 'a keyword with no #reference does not count'
# The critical review finding: prose explaining the gate must not trigger it. GitHub does not link a
# reference inside a code span, so a keyword there closes nothing on GitHub either.
Assert-Equal $false (Test-HasClosingKeyword -Text 'GitHub closes only the first: `Closes #331, #332`') 'a backticked keyword does NOT count'
Assert-Equal $true  (Test-HasClosingKeyword -Text 'Closes #331 -- see `#332` too')                     'a live keyword still counts next to a backticked one'

Write-Host "Get-ClosedIssueNumbers" -ForegroundColor Cyan
Assert-Set @()         (Get-ClosedIssueNumbers -Text 'mentions #332 only')          'plain mention -> closes nothing'
Assert-Set @(332)      (Get-ClosedIssueNumbers -Text 'Closes #332')                 'single keyword -> that number'
Assert-Set @(331, 332) (Get-ClosedIssueNumbers -Text "Closes #331`nCloses #332")    'one per line -> both'
Assert-Set @(340)      (Get-ClosedIssueNumbers -Text 'Fixes https://github.com/o/r/issues/340') 'URL form -> that number'
# Property 1, the false-green direction: the comma form GitHub does NOT honour must not be reported
# as closing the trailing numbers, or the ship-pr verification would pass on a wrong set.
Assert-Set @(331)      (Get-ClosedIssueNumbers -Text 'Closes #331, #332')           'comma form closes ONLY the first (as GitHub does)'
# This decides what ship-pr force-closes after a merge, so a prose example reaching it would close an
# unrelated issue and credit the wrong PR -- the critical review finding, reproduced on this repo's
# own changelog entry before the fix.
Assert-Set @()         (Get-ClosedIssueNumbers -Text 'so `Closes #331, #332` closes the first') 'a backticked example declares NOTHING'
$fencedBody = "text`n" + '```' + "`nCloses #331`n" + '```' + "`nmore text"
Assert-Set @()         (Get-ClosedIssueNumbers -Text $fencedBody)                    'a fenced example declares NOTHING'
Assert-Set @(331)      (Get-ClosedIssueNumbers -Text "Closes #331`n`nExample: ``Closes #999``") 'the live keyword counts, the fenced one does not'

Write-Host "New-ResolvesBlock" -ForegroundColor Cyan
Assert-Equal '' (New-ResolvesBlock -Issues @())        'no issues -> empty block (safe to append)'
Assert-Equal '' (New-ResolvesBlock -Issues @(0))       'a non-positive number is ignored'

$block = New-ResolvesBlock -Issues @(332, 331)
Assert-True ($block -match '(?m)^Closes #331$') 'block has its own line for #331'
Assert-True ($block -match '(?m)^Closes #332$') 'block has its own line for #332'
Assert-True ($block -notmatch ',')              'block contains NO comma list (GitHub would close only the first)'
Assert-Equal 2 (@([regex]::Matches($block, '(?m)^Closes #\d+$')).Count) 'one closing line PER issue'
Assert-True ($block -match '## Resolved issues')  'block carries its heading, at H2 by default -- what every consumer body still uses'

# THE LEVEL IS A PARAMETER, AND THAT IS A CORRECTNESS FIX RATHER THAN STYLING (August 9, 2026). The
# block must be a SIBLING of the description: -RefreshBody replaces the description by scanning to the
# next heading at its level or shallower, so a block DEEPER than the description sits inside it and is
# deleted by the next refresh -- taking the closing keywords with it. GitHub would then close nothing at
# the merge, which is the #341-#343 failure walking back in through the door built to stop it.
$blockH1 = New-ResolvesBlock -Issues @(7) -Level 1
Assert-True ($blockH1 -match '(?m)^# Resolved issues$')  'the level is honoured: H1 for a body whose description is H1'
Assert-True ($blockH1 -match '(?m)^Closes #7$')          'and the closing keyword is unaffected by the level'
Assert-Set @(7) (Get-ClosedIssueNumbers -Text $blockH1)  'the reader is keyword-based, so it reads an H1 block exactly as it reads an H2 one'

# Add-ResolvesBlock DERIVES the level from the body it is appending to, so no caller has to remember.
$h1Body = "# What does the change on this branch bring to main?`n`nSome text."
Assert-True ((Add-ResolvesBlock -Body $h1Body -Issues @(9)) -match '(?m)^# Resolved issues$') 'an H1 body gets an H1 block'
$h2Body = "## What does this change do?`n`nSome text."
Assert-True ((Add-ResolvesBlock -Body $h2Body -Issues @(9)) -match '(?m)^## Resolved issues$') "a consumer's H2 body still gets an H2 block"
$noHeading = 'just a paragraph'
Assert-True ((Add-ResolvesBlock -Body $noHeading -Issues @(9)) -match '(?m)^## Resolved issues$') 'a body with no heading falls back to H2, the level every body carried before this'
# A fenced heading is sample text and must not decide the level of a real section.
$fencedFirst = "``````text`n# not a heading`n```````n`n## Real heading`n`ntext"
Assert-True ((Add-ResolvesBlock -Body $fencedFirst -Issues @(9)) -match '(?m)^## Resolved issues$') 'a heading inside a fence does not set the level'
# Round trip: what the writer produces is exactly what the recogniser reads back.
Assert-Set @(331, 332) (Get-ClosedIssueNumbers -Text $block) 'round trip: writer output reads back as both issues'

$dupBlock = New-ResolvesBlock -Issues @(332, 332, 331)
Assert-Equal 2 (@([regex]::Matches($dupBlock, '(?m)^Closes #\d+$')).Count) 'duplicate input -> one line each'

Write-Host "Add-ResolvesBlock" -ForegroundColor Cyan
Assert-Equal 'body text' (Add-ResolvesBlock -Body 'body text' -Issues @()) 'no issues -> body unchanged'
$appended = Add-ResolvesBlock -Body '## What does this change do?' -Issues @(332)
Assert-True ($appended -match '## What does this change do') 'the original body survives'
Assert-True ($appended -match '(?m)^Closes #332$')           'the closing line is appended'
# Idempotence: re-running must not stack a second block (the accumulation-bug shape this repo keeps
# finding -- #275's preview/apply drift and #331's second pruning pass).
$twice = Add-ResolvesBlock -Body $appended -Issues @(332)
Assert-Equal 1 (@([regex]::Matches($twice, '(?m)^Closes #332$')).Count) 'idempotent: #332 is not closed twice'
$mixed = Add-ResolvesBlock -Body $appended -Issues @(332, 331)
Assert-Equal 1 (@([regex]::Matches($mixed, '(?m)^Closes #332$')).Count) 'already-closed number not repeated'
Assert-Equal 1 (@([regex]::Matches($mixed, '(?m)^Closes #331$')).Count) 'the new number IS added'
$fromEmpty = Add-ResolvesBlock -Body '' -Issues @(332)
Assert-True ($fromEmpty -match '(?m)^Closes #332$') 'an empty body still gets the block'

Write-Host "Get-ResolvesDecision -- the gate's whole table" -ForegroundColor Cyan

$explicit = Get-ResolvesDecision -Resolves @(331, 332) -OpenMentions @(340)
Assert-Equal $true      $explicit.Allowed 'explicit -Resolves -> allowed'
Assert-Set  @(331, 332) $explicit.Issues  'explicit -Resolves -> those issues'

$no = Get-ResolvesDecision -NoResolves -OpenMentions @(340)
Assert-Equal $true $no.Allowed  '-NoResolves -> allowed even with an open mention'
Assert-Set  @()    $no.Issues   '-NoResolves -> closes nothing'

$viaBody = Get-ResolvesDecision -Body 'Closes #332' -OpenMentions @(332)
Assert-Equal $true  $viaBody.Allowed 'a body with a closing keyword satisfies the gate'
Assert-Set  @(332)  $viaBody.Issues  'the issues come from the body'

$blocked = Get-ResolvesDecision -Body 'this fixes the thing from #332' -OpenMentions @(332)
Assert-Equal $false $blocked.Allowed 'open mention + no decision -> BLOCKED'
Assert-Set  @(332)  $blocked.Blocked 'the blocked verdict names the issue'
Assert-Set  @()     $blocked.Issues  'a blocked verdict closes nothing'

$closedOnly = Get-ResolvesDecision -Body 'context from #300' -OpenMentions @()
Assert-Equal $true $closedOnly.Allowed 'mentions that are not open issues -> allowed'
Assert-Set  @()    $closedOnly.Issues  'nothing to close'

# The deliberate escape hatch: an unknown open/closed state must NOT block. A gate that wedges the
# PR flow on a network hiccup is worse than the bookkeeping slip it guards against.
$unknown = Get-ResolvesDecision -Body 'mentions #332' -OpenMentions $null
Assert-Equal $true $unknown.Allowed 'undeterminable state -> allowed (warn, never wedge)'
Assert-True ($unknown.Reason -match 'could not be determined') 'and the reason says so'

# -Resolves wins over -NoResolves when both are passed: an explicit list is a more specific
# statement than a blanket "nothing", so it must not be silently discarded.
$both = Get-ResolvesDecision -Resolves @(331) -NoResolves
Assert-Equal $true $both.Allowed  'both flags -> allowed'
Assert-Set  @(331) $both.Issues   '-Resolves wins over -NoResolves'

Write-Host "Get-ResolvesDecision -- Undeclared (review finding: a partial -Resolves went silent)" -ForegroundColor Cyan
# -Resolves naming one of two open mentions used to leave the second invisible: allowed, unclosed, and
# unreported -- a partial recurrence of the very failure this gate was built for. It must not BLOCK
# (closing one of two is legitimate) but it must be SAID.
$partial = Get-ResolvesDecision -Resolves @(332) -OpenMentions @(332, 400)
Assert-Equal $true  $partial.Allowed    'partial -Resolves is still allowed (not a block)'
Assert-Set  @(332)  $partial.Issues     'only the declared issue is closed'
Assert-Set  @(400)  $partial.Undeclared 'the undeclared open mention IS reported'

$full = Get-ResolvesDecision -Resolves @(332, 400) -OpenMentions @(332, 400)
Assert-Set  @()     $full.Undeclared    'declaring all of them reports nothing'

# -NoResolves answers for every mentioned issue, so repeating them would turn a decision into a nag.
$noNag = Get-ResolvesDecision -NoResolves -OpenMentions @(332, 400)
Assert-Set  @()     $noNag.Undeclared   '-NoResolves reports no undeclared issues'

# A body-carried keyword is a declaration like any other, so the same reporting applies to it.
$bodyPartial = Get-ResolvesDecision -Body 'Closes #332' -OpenMentions @(332, 400)
Assert-Set  @(332)  $bodyPartial.Issues     'the body declaration is honoured'
Assert-Set  @(400)  $bodyPartial.Undeclared 'and the rest is still reported'

# Unknown state -> nothing to compare against, so nothing is claimed.
$unknownUndeclared = Get-ResolvesDecision -Resolves @(332) -OpenMentions $null
Assert-Set  @()     $unknownUndeclared.Undeclared 'an undeterminable state reports no undeclared issues'

Write-Host ""

Write-Host ""
Write-Host "The -NoResolves marker -- the decision that used to evaporate (issue #1912)" -ForegroundColor Cyan
# A -Resolves survived a run because it became a closing keyword the next run read back off the open
# PR; -NoResolves wrote nothing, so the same branch was asked again by ship-pr's step 1 re-running
# open-pr. These asserts are that asymmetry closed: the answer is written down, recognised, idempotent,
# and removed the moment it stops being true.

$marker = Get-NoResolvesMarker
Assert-True ($marker -match '^<!--.*-->$') 'the marker is an HTML comment (invisible to a reader, durable to the gate)'

Assert-Equal $false (Test-NoResolvesMarker -Text '')                  'an empty body carries no marker'
Assert-Equal $false (Test-NoResolvesMarker -Text 'nothing here')      'ordinary prose carries no marker'
Assert-Equal $true  (Test-NoResolvesMarker -Text $marker)             'the marker recognises itself'
Assert-Equal $true  (Test-NoResolvesMarker -Text "text`n<!--  RESOLVES:   none  -->`nmore") 'whitespace and case are tolerated'

# The measured reason Remove-MarkdownCodeSpans exists, one function over: a document explaining the
# marker necessarily writes the marker, and #1912's own changelog entry does. open-pr copies an entry
# body verbatim into the PR body, so without the stripping that entry would answer the gate on behalf
# of a branch that declared nothing.
Assert-Equal $false (Test-NoResolvesMarker -Text ('the marker is `' + $marker + '`')) 'a marker inside a code SPAN is not a declaration'
Assert-Equal $false (Test-NoResolvesMarker -Text ("prose`n" + '```' + "`n$marker`n" + '```' + "`nmore")) 'a marker inside a FENCE is not a declaration'

$markedEmpty = Add-NoResolvesMarker -Body ''
Assert-Equal $true (Test-NoResolvesMarker -Text $markedEmpty) 'an empty body still gets the marker'
$marked = Add-NoResolvesMarker -Body "## Description`n`nsome prose"
Assert-Equal $true  (Test-NoResolvesMarker -Text $marked) 'a real body gets the marker'
Assert-True ($marked -match '(?s)some prose.*resolves: none') 'and it goes at the END, below the body'
$markedTwice = Add-NoResolvesMarker -Body $marked
Assert-Equal 1 (@([regex]::Matches($markedTwice, '(?i)<!--\s*resolves:\s*none\s*-->')).Count) 'idempotent: the marker is not stacked'

# Idempotent in the other direction too, because open-pr strips unconditionally on every -Resolves run.
$stripped = Remove-NoResolvesMarker -Body $marked
Assert-Equal $false (Test-NoResolvesMarker -Text $stripped) 'the marker is removed'
Assert-True ($stripped -match 'some prose') 'and the body around it survives'
$strippedTwice = Remove-NoResolvesMarker -Body $stripped
Assert-Equal $strippedTwice $stripped 'removing a marker that is not there changes nothing'
# Repeated add/remove must not grow the foot of the body -- this runs on every re-push of a branch.
Assert-Equal $stripped (Remove-NoResolvesMarker -Body (Add-NoResolvesMarker -Body (Remove-NoResolvesMarker -Body (Add-NoResolvesMarker -Body $stripped)))) 'add/remove cycles do not accumulate whitespace'


# Remove is a TRUE no-op where there is no live marker: the caller runs it on every -Resolves run and
# announces a body edit by comparing before with after, so a version that tidied trailing whitespace
# would report removing a marker from a body that never carried one -- and send a PR update for it.
$untouched = "## Description`n`nprose with no marker   "
Assert-Equal $untouched (Remove-NoResolvesMarker -Body $untouched) 'a body with no marker comes back byte for byte'

# And a body can carry BOTH -- this repo's own entry for #1912 writes the marker as prose, and open-pr
# copies an entry into the PR body verbatim. The live one goes; the example stays.
$bodyWithBoth = "the marker is ``$marker`` in prose`n`n$marker"
$afterStrip = Remove-NoResolvesMarker -Body $bodyWithBoth
Assert-Equal $false (Test-NoResolvesMarker -Text $afterStrip) 'the LIVE marker is removed'
Assert-True ($afterStrip -match 'the marker is') 'and the documented example survives the removal'
Assert-Equal 1 (@([regex]::Matches($afterStrip, '(?i)<!--\s*resolves:\s*none\s*-->')).Count) 'exactly the quoted one is left'

Write-Host "Get-ResolvesDecision -- the marker is read the way a closing keyword is" -ForegroundColor Cyan
# THE WHOLE POINT: this is the run that used to be refused. The flag is gone (a second command does not
# repeat it), the open mention is still there, and the body carries what the first run wrote.
$viaMarker = Get-ResolvesDecision -Body ("## Description`n`nwork`n`n" + $marker) -OpenMentions @(1843, 1904)
Assert-Equal $true  $viaMarker.Allowed    'a published "closes nothing" satisfies the gate on a later run'
Assert-Set  @()     $viaMarker.Issues     'and it closes nothing'
Assert-Set  @()     $viaMarker.Undeclared 'the marker answers for every mention, so nothing is nagged about'
Assert-True ($viaMarker.Reason -match 'closes nothing') 'and the reason names what it read'

# The precedence that keeps this function agreeing with GitHub: a body carrying both is judged by the
# keywords, because those are what actually fire at the merge.
$bodyBoth = Get-ResolvesDecision -Body ("Closes #332`n`n" + $marker) -OpenMentions @(332)
Assert-Set @(332) $bodyBoth.Issues 'closing keywords win over a stale marker'

# DeclaredNone is what open-pr reads to decide whether to write the marker down. True on exactly the
# two answers that SAY "closes nothing" -- never on an absence of a question.
Assert-Equal $true  $no.DeclaredNone         '-NoResolves declares none'
Assert-Equal $true  $viaMarker.DeclaredNone  'the published marker declares none'
Assert-Equal $false $explicit.DeclaredNone   'an explicit -Resolves does not'
Assert-Equal $false $closedOnly.DeclaredNone '"nothing open is mentioned" is an absence, not a declaration'
Assert-Equal $false $unknown.DeclaredNone    'an undeterminable state declares nothing'
Assert-Equal $false $blocked.DeclaredNone    'a blocked verdict declares nothing'
Assert-Equal $false $viaBody.DeclaredNone    'a body that closes an issue does not declare none'

Write-Host "Get-TargetIssueWarnings -- the already-done check (issue #1282)" -ForegroundColor Cyan
# The gap #1282 measured: the resolves gate blocks only on a mentioned issue that is still OPEN, so a
# branch targeting an issue that has since been CLOSED, or one another open/merged PR already resolves,
# reaches a gate-green PR and is found at the merge conflict. This helper is the facts behind the
# warning; it never blocks.

Assert-Equal 0 (@(Get-TargetIssueWarnings -TargetIssues @()).Count) 'no target issues -> nothing to say'

# Target still open, no rival PR -> nothing to say.
$stillOpen = @(Get-TargetIssueWarnings -TargetIssues @(1270) -OpenIssues @(1270, 42))
Assert-Equal 0 $stillOpen.Count 'an open target with no rival PR produces no warning'

# Target CLOSED (the open list is known and does not contain it).
$closed = @(Get-TargetIssueWarnings -TargetIssues @(1270) -OpenIssues @(42, 99))
Assert-Equal 1     $closed.Count       'a closed target produces one record'
Assert-Equal 1270  $closed[0].Issue    'the record names the issue'
Assert-True  $closed[0].IsClosed       'and marks it closed'
Assert-Equal 0     @($closed[0].ClaimingPrs).Count 'with no claiming PR when none was supplied'

# Open list undeterminable -> IsClosed is never asserted (the not-blocking treatment).
$noList = @(Get-TargetIssueWarnings -TargetIssues @(1270) -OpenIssues $null)
Assert-Equal 0 $noList.Count 'an undeterminable open-issue state claims nothing'

# A rival OPEN PR whose body closes the number.
$rivalJson = '[{"number":1276,"state":"OPEN","headRefName":"fix/other-v1","body":"Closes #1270"}]'
$rival = @(Get-TargetIssueWarnings -TargetIssues @(1270) -OpenIssues @(1270) -OtherPrsJson $rivalJson -CurrentBranch 'fix/mine-v1')
Assert-Equal 1     $rival.Count                  'a rival PR that closes the number produces a record'
Assert-Equal $false $rival[0].IsClosed           'the issue itself is still open here'
Assert-Equal 1276  @($rival[0].ClaimingPrs)[0].Number 'the claiming PR number comes through'
Assert-Equal 'OPEN' @($rival[0].ClaimingPrs)[0].State 'and its state'

# A MERGED rival counts too -- that is the exact #1282 case.
$mergedJson = '[{"number":1276,"state":"MERGED","headRefName":"fix/other-v1","body":"Closes #1270"}]'
$merged = @(Get-TargetIssueWarnings -TargetIssues @(1270) -OpenIssues @(1270) -OtherPrsJson $mergedJson -CurrentBranch 'fix/mine-v1')
Assert-Equal 'MERGED' @($merged[0].ClaimingPrs)[0].State 'a merged rival is reported'

# A CLOSED rival PR is an abandoned attempt (in #1282, the duplicate itself) -- NOT evidence the work is done.
$closedRivalJson = '[{"number":1281,"state":"CLOSED","headRefName":"fix/other-v1","body":"Closes #1270"}]'
$closedRival = @(Get-TargetIssueWarnings -TargetIssues @(1270) -OpenIssues @(1270) -OtherPrsJson $closedRivalJson -CurrentBranch 'fix/mine-v1')
Assert-Equal 0 $closedRival.Count 'a CLOSED rival PR is not reported'

# This branch's OWN open PR carries the keyword by design on a resumed run -- not a rival.
$ownJson = '[{"number":500,"state":"OPEN","headRefName":"fix/mine-v1","body":"Closes #1270"}]'
$own = @(Get-TargetIssueWarnings -TargetIssues @(1270) -OpenIssues @(1270) -OtherPrsJson $ownJson -CurrentBranch 'fix/mine-v1')
Assert-Equal 0 $own.Count "this branch's own PR is never reported as a rival claimant"

# A rival PR that only MENTIONS the number (no closing keyword) does not count -- same reader as the gate.
$mentionOnlyJson = '[{"number":1276,"state":"MERGED","headRefName":"fix/other-v1","body":"context from #1270, unrelated"}]'
$mentionOnly = @(Get-TargetIssueWarnings -TargetIssues @(1270) -OpenIssues @(1270) -OtherPrsJson $mentionOnlyJson -CurrentBranch 'fix/mine-v1')
Assert-Equal 0 $mentionOnly.Count 'a bare mention in a rival PR body is not a claim'

# Unparseable PR JSON -> no claiming PRs, and IsClosed is still evaluated from the open list.
$badJson = @(Get-TargetIssueWarnings -TargetIssues @(1270) -OpenIssues @(42) -OtherPrsJson 'not json' -CurrentBranch 'fix/mine-v1')
Assert-Equal 1 $badJson.Count            'unparseable PR JSON does not throw'
Assert-True  $badJson[0].IsClosed        'and the closed-target signal still fires'
Assert-Equal 0 @($badJson[0].ClaimingPrs).Count 'with no claiming PR from JSON that would not parse'

# The whole #1282 scenario in one call: target #1270, closed; PR #1276 merged resolving it; PR #1281
# closed on this branch also carrying the keyword. One record: closed, claimed by #1276 alone.
$scenarioJson = '[{"number":1276,"state":"MERGED","headRefName":"fix/unfolded-entry-on-main-unguarded-v1","body":"Closes #1270"},{"number":1281,"state":"CLOSED","headRefName":"fix/unfolded-entry-on-main-sessioncheck-v1","body":"Closes #1270"}]'
$scenario = @(Get-TargetIssueWarnings -TargetIssues @(1270) -OpenIssues @(42, 99) -OtherPrsJson $scenarioJson -CurrentBranch 'fix/unfolded-entry-on-main-sessioncheck-v1')
Assert-Equal 1     $scenario.Count       'the #1282 scenario produces exactly one record'
Assert-True  $scenario[0].IsClosed       'the target is reported closed'
Assert-Equal 1     @($scenario[0].ClaimingPrs).Count 'and exactly one claiming PR (the merged one, not the abandoned duplicate)'
Assert-Equal 1276  @($scenario[0].ClaimingPrs)[0].Number 'which is #1276'

# Two target issues, one closed and one open+claimed -> a record for each, with the right signal.
$twoJson = '[{"number":90,"state":"OPEN","headRefName":"fix/other-v1","body":"Closes #401"}]'
$two = @(Get-TargetIssueWarnings -TargetIssues @(400, 401) -OpenIssues @(401) -OtherPrsJson $twoJson -CurrentBranch 'fix/mine-v1')
Assert-Equal 2 $two.Count 'both targets that have something to say are reported'
$rec400 = $two | Where-Object { $_.Issue -eq 400 }
$rec401 = $two | Where-Object { $_.Issue -eq 401 }
Assert-True  $rec400.IsClosed                       '#400 is closed'
Assert-Equal 0 @($rec400.ClaimingPrs).Count         'and has no claiming PR'
Assert-Equal $false $rec401.IsClosed                '#401 is still open'
Assert-Equal 90 @($rec401.ClaimingPrs)[0].Number    'but is claimed by PR #90'

Write-Host ""
Write-Host "Get-ExistingPrRecord" -ForegroundColor Cyan

# What open-pr.ps1 does with the answer: an existing PR means the gates and the push still run but
# `gh pr create` is skipped, and the existing body's closing keywords count as a declaration. So a
# WRONG answer here is not a crash -- it silently opens a duplicate or blocks a resumable branch.

# The empty list is the ordinary "no PR yet" answer and MUST read as $null, not as a record. In 5.1
# indexing the parsed result with [0] also yields $null here, which is why this is asserted rather
# than assumed: the two forms agree on this case and disagree on the next one.
Assert-True ($null -eq (Get-ExistingPrRecord -Json '[]')) 'an empty list means no existing PR'

# One record -- the case that matters, and the one where the 5.1 pitfall bites: with `@(... |
# ConvertFrom-Json)` the single collected element IS the whole Object[], so .number would be an
# array member-enumeration rather than the number.
$one = Get-ExistingPrRecord -Json '[{"number":457,"url":"https://github.com/o/r/pull/457","body":"Closes #123"}]'
Assert-True ($null -ne $one)                'a single record is found'
Assert-Equal 457 $one.number                'the number is the record field, not an enumerated array'
Assert-Equal 'https://github.com/o/r/pull/457' $one.url 'the url comes through'
Assert-Equal 'Closes #123' $one.body        'the body comes through, so the gate can read it'

# The body of a found record has to satisfy the resolves gate on its own -- otherwise resuming the
# branch would demand a decision that is already published on the PR and cannot be changed by
# declaring it again here.
Assert-True (Test-HasClosingKeyword -Text $one.body) "a found record's body satisfies the resolves gate"
$fromExisting = Get-ResolvesDecision -Body $one.body -OpenMentions @(123)
Assert-True $fromExisting.Allowed           'and the gate therefore allows the resumed PR'
Assert-Set  @(123) $fromExisting.Issues     'crediting the issue the existing body declares'

# --limit 1 is what open-pr passes, but the parser must not depend on gh honouring it.
$first = Get-ExistingPrRecord -Json '[{"number":10,"body":"a"},{"number":11,"body":"b"}]'
Assert-Equal 10 $first.number               'the FIRST record wins when gh returns several'

# Every unreadable answer collapses to "no existing PR". That is deliberate and not an oversight: the
# caller then behaves exactly as it did before this feature existed -- a duplicate `gh pr create` that
# gh refuses with its own message -- instead of wedging the PR flow on a bad payload.
Assert-True ($null -eq (Get-ExistingPrRecord -Json 'not json at all')) 'unparseable JSON means no existing PR'
Assert-True ($null -eq (Get-ExistingPrRecord -Json ''))                'empty input means no existing PR'
Assert-True ($null -eq (Get-ExistingPrRecord -Json '   '))             'whitespace means no existing PR'
Assert-True ($null -eq (Get-ExistingPrRecord -Json '[{"url":"https://x/1"}]')) 'a record without a number is not believed'

# THE SHAPE THIS FUNCTION REPLACED, asserted as wrong on purpose. ship-pr.ps1's step 2 used
#     $prs = @($prList.Output | ConvertFrom-Json); $pr = $prs[0].number
# and both halves fail in 5.1: the count is 1 even for an empty list, so its `-lt 1` guard was dead
# code, and $prs[0] is the whole Object[], whose .number member-enumerates to the EMPTY STRING when
# there is nothing. The script then ran `gh pr merge ''`. These two asserts exist so a future
# simplification back to that form fails here instead of on main.
$oldShapeEmpty = @('[]' | ConvertFrom-Json)
Assert-Equal 1  $oldShapeEmpty.Count      'the replaced @(text | ConvertFrom-Json) shape counts 1 for an empty list'
Assert-Equal '' "$($oldShapeEmpty[0].number)" 'and yields the empty string as a PR number'
Assert-True ($null -eq (Get-ExistingPrRecord -Json '[]')) 'Get-ExistingPrRecord answers $null there, so the guard can fire'

# The append path: what open-pr writes back when this run declares an issue the existing body lacks.
# Idempotent per issue, so a rerun does not stack duplicate blocks -- asserted here because the caller
# decides whether to call `gh pr edit` by comparing against the original string.
$appended = Add-ResolvesBlock -Body $one.body -Issues @(123, 456)
Assert-Set  @(123, 456) (Get-ClosedIssueNumbers -Text $appended) 'the missing issue is appended, the present one kept'
Assert-Equal $appended (Add-ResolvesBlock -Body $appended -Issues @(123, 456)) 'appending twice changes nothing'
Assert-Equal $one.body (Add-ResolvesBlock -Body $one.body -Issues @(123)) 'nothing to add leaves the body identical (no pr edit call)'


# --- Get-CheckWaitReport: which check governed the merge wait (issue #831) ------------------------
# The SELECTION is what a suite can reach; the gh call is not. So every assert here is about the
# payload -> line mapping, and the shapes that must NOT produce a line are asserted as loudly as the
# ones that must: a fabricated ordering is worse than a missing one, which is the whole reason #831
# exists -- it was opened because two readings from a sample of three had been quoted as a tendency.
Write-Host ""
Write-Host "Get-CheckWaitReport -- which check governed the wait" -ForegroundColor Cyan

Assert-Equal '0s'      (Format-CheckDuration -Seconds 0)    'duration: zero reads as 0s -- the median answer here, not an unmeasured one'
Assert-Equal '59s'     (Format-CheckDuration -Seconds 59)   'duration: below a minute stays in seconds'
Assert-Equal '1m 00s'  (Format-CheckDuration -Seconds 60)   'duration: a whole minute pads the seconds'
Assert-Equal '9m 08s'  (Format-CheckDuration -Seconds 548)  'duration: seconds are zero-padded so a column lines up'
Assert-Equal '14m 05s' (Format-CheckDuration -Seconds 845)  'duration: matches the shape the release notes already use'
Assert-Equal ''        (Format-CheckDuration -Seconds -1)   'duration: unmeasured returns empty, so a caller can concatenate'

# Both timestamp shapes must land on the same answer: 5.1's ConvertFrom-Json hands back a [datetime],
# other editions can hand back the string. A reader of only one of them would mis-order on the other.
$asText = ConvertTo-CheckTimestamp -Value '2026-08-24T09:14:05Z'
$asDate = ConvertTo-CheckTimestamp -Value ([datetime]::Parse('2026-08-24T09:14:05Z').ToUniversalTime())
Assert-Equal $asDate.Ticks $asText.Ticks 'timestamp: a string and an already-parsed [datetime] agree'
Assert-True ($null -eq (ConvertTo-CheckTimestamp -Value $null)) 'timestamp: absent is $null, not the epoch'
Assert-True ($null -eq (ConvertTo-CheckTimestamp -Value ''))    'timestamp: empty is $null'
Assert-True ($null -eq (ConvertTo-CheckTimestamp -Value 'soon')) 'timestamp: unreadable is $null rather than a throw'

$twoChecks = @'
[
  {"name":"lint-en-tests","startedAt":"2026-08-24T09:00:00Z","completedAt":"2026-08-24T09:09:58Z"},
  {"name":"claude-review","startedAt":"2026-08-24T09:00:00Z","completedAt":"2026-08-24T09:14:05Z"}
]
'@
$requiredOnly = '[{"name":"lint-en-tests"}]'

$line = Get-CheckWaitReport -ChecksJson $twoChecks -RequiredNamesJson $requiredOnly -WaitedSeconds 845
Assert-True ($line -like "*'claude-review' finished last*")        'the check that finished LAST is the one named as governing'
Assert-True ($line -like '*NOT required*')                         'and it is labelled against the ruleset, never against a hardcoded name'
Assert-True ($line -like '*14m 05s*')                              'its own duration is reported'
Assert-True ($line -like '*4m 07s after the last required check*') 'the excess over the last required check is what this run actually paid'
Assert-True ($line -like '*waited 14m 05s*')                       'the wall-clock the script itself spent is stated separately'

# The ordinary case, and the one nobody could see before: the required check governs and the
# non-required one finished long ago. Measured at 77 of 100 runs -- so this is the line that must not
# invent a cost out of an ordering it does not have.
$requiredGoverns = @'
[
  {"name":"lint-en-tests","startedAt":"2026-08-24T09:00:00Z","completedAt":"2026-08-24T09:08:37Z"},
  {"name":"claude-review","startedAt":"2026-08-24T09:00:00Z","completedAt":"2026-08-24T09:03:02Z"}
]
'@
$line2 = Get-CheckWaitReport -ChecksJson $requiredGoverns -RequiredNamesJson $requiredOnly -WaitedSeconds 517
Assert-True ($line2 -like "*'lint-en-tests' finished last*") 'the required check governing is reported as plainly as the other way round'
Assert-True ($line2 -like '*, required*')                    'and labelled required'
Assert-True (-not ($line2 -like '*after the last required check*')) 'no excess is stated when the required check governed -- there is none'

# Without the required set the line still says which check governed, and says NOTHING about required.
$line3 = Get-CheckWaitReport -ChecksJson $twoChecks -WaitedSeconds 845
Assert-True ($line3 -like "*'claude-review' finished last*") 'an unknown ruleset does not cost the reader the ordering'
Assert-True (-not ($line3 -like '*required*'))               'but an unknown answer is left unstated rather than guessed'

# A ruleset payload that does not parse must behave exactly as an absent one, never as "not required".
$line4 = Get-CheckWaitReport -ChecksJson $twoChecks -RequiredNamesJson 'not json at all' -WaitedSeconds 845
Assert-True (-not ($line4 -like '*required*')) 'an unparseable ruleset payload degrades to silence, not to a wrong label'

# Unmeasured wall-clock is omitted rather than printed as zero -- 0s is a real, common answer here.
$line5 = Get-CheckWaitReport -ChecksJson $twoChecks -RequiredNamesJson $requiredOnly
Assert-True (-not ($line5 -like '*waited*'))                 'an unmeasured wait is left out, so it cannot be read as 0s'
Assert-True ($line5 -like "*'claude-review' finished last*") 'while the ordering is still reported'

# Every shape that cannot answer the question returns $null, so the caller prints its own fallback.
Assert-True ($null -eq (Get-CheckWaitReport -ChecksJson ''))     'empty payload: no line'
Assert-True ($null -eq (Get-CheckWaitReport -ChecksJson '   '))  'whitespace payload: no line'
Assert-True ($null -eq (Get-CheckWaitReport -ChecksJson '[]'))   'empty list: no line -- the 5.1 array trap that bit Get-ExistingPrRecord'
Assert-True ($null -eq (Get-CheckWaitReport -ChecksJson 'nope')) 'unparseable payload: no line'
Assert-True ($null -eq (Get-CheckWaitReport -ChecksJson '[{"name":"x"}]')) 'a check with no completedAt cannot have finished last'
Assert-True ($null -eq (Get-CheckWaitReport -ChecksJson '[{"completedAt":"2026-08-24T09:00:00Z"}]')) 'a nameless record cannot be named'

# A check with no startedAt still finished, and still governed. Report the ordering, not a duration.
$noStart = '[{"name":"claude-review","completedAt":"2026-08-24T09:14:05Z"}]'
$line6 = Get-CheckWaitReport -ChecksJson $noStart -WaitedSeconds 845
Assert-True ($line6 -like "*'claude-review' finished last*") 'a missing startedAt does not cost the ordering'
Assert-True ($line6 -like '*duration unknown*')              'and the duration says so instead of being computed from nothing'

# A single check is the common shape in a repo with one workflow, and it governs by definition.
$onlyOne = '[{"name":"lint-en-tests","startedAt":"2026-08-24T09:00:00Z","completedAt":"2026-08-24T09:09:58Z"}]'
$line7 = Get-CheckWaitReport -ChecksJson $onlyOne -RequiredNamesJson $requiredOnly -WaitedSeconds 598
Assert-True ($line7 -like "*'lint-en-tests' finished last*") 'one check governs its own wait -- Sort-Object over a single item still answers'
Assert-True ($line7 -like '*, required*')                    'and is still labelled from the ruleset'

# --- THE ZERO TIMESTAMP: a check that has NOT finished yet (issue #977) ---------------------------
#
# `gh pr checks --json` serialises an unfinished check's completedAt as `0001-01-01T00:00:00Z` -- the
# THIRD shape, alongside a real stamp and an absent field, and the one nothing above reached. Every
# assert in this suite fed it stamps that were either real or missing, so the report was only ever
# exercised on payloads where the race had already resolved. It cost a live run in a consumer repo: the
# [int] cast overflowed on -63,923,427,029 seconds AFTER `CI green.` was printed and BEFORE the merge,
# leaving the PR unmerged and the entry unfolded with every check green.
#
# THE CRASH IS THE SMALLER HALF. An unfinished check did not govern the wait, so the fix has to produce
# the RIGHT line and not merely a surviving one -- which is what the first two asserts below pin.
$zeroCompleted = @'
[
  {"name":"lint-en-tests","startedAt":"2026-08-24T09:00:00Z","completedAt":"2026-08-24T09:09:58Z"},
  {"name":"claude-review","startedAt":"2026-08-24T09:09:00Z","completedAt":"0001-01-01T00:00:00Z"}
]
'@
$line8 = Get-CheckWaitReport -ChecksJson $zeroCompleted -RequiredNamesJson $requiredOnly -WaitedSeconds 598
Assert-True ($line8 -like "*'lint-en-tests' finished last*") 'a check that has not finished cannot have finished last'
Assert-True (-not ($line8 -like '*claude-review*'))          'so it takes no part in the ordering at all'
Assert-True ($line8 -like '*9m 58s*')                        'and the check that DID finish still reports its own duration'

# Both timestamp shapes carry it, and only one of them was proposed for repair in #977. In 5.1 which one
# arrives depends on the edition rather than the payload, so a guard on either alone works on one
# machine and overflows on the next -- measured: this machine hands the zero date through as a STRING.
Assert-True ($null -eq (ConvertTo-CheckTimestamp -Value '0001-01-01T00:00:00Z')) 'timestamp: gh zero time as a string is unreadable, not the floor of the type'
Assert-True ($null -eq (ConvertTo-CheckTimestamp -Value ([datetime]::MinValue)))  'timestamp: and as an already-parsed [datetime] too'
Assert-True ($null -eq (Get-CheckWaitReport -ChecksJson '[{"name":"x","completedAt":"0001-01-01T00:00:00Z"}]')) 'a payload of nothing but unfinished checks answers nothing -- no line, no throw'

# The zero date on startedAt costs the duration and nothing else: the check finished, so it still orders.
$zeroStarted = '[{"name":"lint-en-tests","startedAt":"0001-01-01T00:00:00Z","completedAt":"2026-08-24T09:09:58Z"}]'
$line9 = Get-CheckWaitReport -ChecksJson $zeroStarted -RequiredNamesJson $requiredOnly -WaitedSeconds 598
Assert-True ($line9 -like "*'lint-en-tests' finished last*") 'a zero startedAt does not cost the ordering'
Assert-True ($line9 -like '*duration unknown*')              'and the duration says so rather than being computed from the floor of the type'

# THE CLASS, not just the door #977 came through. A readable but absurd stamp is a span no [int] holds,
# from the same untrusted field, and it would reach the same cast -- at BOTH arithmetic sites. The second
# is only reachable when a non-required check governs, which is why the excess payload is asserted too.
$farFuture = '[{"name":"lint-en-tests","startedAt":"2026-08-24T09:00:00Z","completedAt":"9999-12-31T23:59:59Z"}]'
$line10 = Get-CheckWaitReport -ChecksJson $farFuture -RequiredNamesJson $requiredOnly -WaitedSeconds 598
Assert-True ($line10 -like '*duration unknown*') 'a duration too large for an [int] is unmeasured, not a throw'
$farFutureExcess = @'
[
  {"name":"lint-en-tests","startedAt":"2026-08-24T09:00:00Z","completedAt":"2026-08-24T09:09:58Z"},
  {"name":"claude-review","startedAt":"2026-08-24T09:00:00Z","completedAt":"9999-12-31T23:59:59Z"}
]
'@
$line11 = Get-CheckWaitReport -ChecksJson $farFutureExcess -RequiredNamesJson $requiredOnly -WaitedSeconds 598
Assert-True ($line11 -like "*'claude-review' finished last*")         'the excess site survives the same input'
Assert-True (-not ($line11 -like '*after the last required check*'))  'and an excess it cannot measure is left out rather than stated wrong'

# The helper itself, so the ordering of round-check-cast is pinned rather than inferred from the lines
# above. -1 is the vocabulary both callers already read as unmeasured, which Format-CheckDuration turns
# into '' -- so an unrenderable duration concatenates away instead of aborting the run printing it.
Assert-Equal 598 (ConvertTo-CheckSeconds -Span ([timespan]::FromSeconds(598)))     'seconds: an ordinary span is a whole number of seconds'
Assert-Equal 1   (ConvertTo-CheckSeconds -Span ([timespan]::FromMilliseconds(501))) 'seconds: rounded, not truncated'
Assert-Equal -1  (ConvertTo-CheckSeconds -Span ([timespan]::FromSeconds(-5)))      'seconds: a negative span is unmeasured, which is what the guard was always meant to catch'
Assert-Equal -1  (ConvertTo-CheckSeconds -Span ([timespan]::FromDays(100000)))     'seconds: and so is one no [int] holds -- range-checked BEFORE the cast, or the cast throws first'
# --- -Resolves TOGETHER WITH -RefreshBody: the block must survive the refresh (#919) -----------------
#
# THE #341-#343 FAILURE REACHED THROUGH THE DOOR BUILT TO PREVENT IT. Everything above asserts that the
# closing block is COMPOSED correctly; nothing asserted that it still reaches GitHub. On PR #916,
# 'open-pr.ps1 -Resolves 913 -RefreshBody' published a body closing nothing: the two body edits run
# SEQUENTIALLY on one variable, the block was appended first, and the refresh then replaced it. The run
# printed a lost-section warning and exited 0, which is why it read as a success.
#
# WHY THE REFRESH CAN REACH THAT FAR is local to a heading-less PR template, which is this repo's shape:
# with no heading above the placeholder the description is the body's LEADING section, and with no
# heading below it there is no stop -- so the leading section is the whole body. Both halves are
# Update-PrBodySection's documented behaviour, and both are right on their own. It is the ORDER that
# loses the block, which is why this section asserts the composition rather than either lib.
Write-Host "-Resolves survives -RefreshBody (#919)" -ForegroundColor Cyan

# Dot-sourced HERE rather than beside the lib at the top, deliberately: this is the one section that
# needs the other PR lib, and the reason it needs it IS the finding -- each lib was correct alone.
. (Join-Path $PSScriptRoot '..\lib\pr-body-lib.ps1')

# The published body of an open PR in this repo: the pasted DEPLOY section, then the block open-pr
# appended on an earlier run. No heading precedes it, exactly as the template produces.
$publishedBody = @'
### DEPLOY: `fix/refresh-body-drops-the-resolves-block-v1`

The description as it was published, which the refresh is about to rewrite.

### Resolved issues

Closes #919
'@
$entryDescription = @'
### DEPLOY: `fix/refresh-body-drops-the-resolves-block-v1`

The description as the changelog entry now words it.
'@

Assert-Set @(919) (Get-ClosedIssueNumbers -Text $publishedBody) 'setup: the published body closes #919 before either edit runs'

# THE MECHANISM, PINNED. A leading-section refresh with no stops replaces the whole body -- so the old
# order really did lose the block, and this assert is what would notice if that ever stopped being true
# (a template gaining a heading changes the answer, and this section would then need re-reading).
$oldOrder = Add-ResolvesBlock -Body $publishedBody -Issues @(919)
$oldOrder = Update-PrBodySection -Body $oldOrder -Heading '' -Content $entryDescription -StopAtHeading @()
Assert-Set @() (Get-ClosedIssueNumbers -Text $oldOrder) 'append-then-refresh loses the closing keyword -- the shape measured on PR #916'

# THE ORDER open-pr.ps1 RUNS SINCE #919: refresh first, append last. No new knowledge of stops or
# heading levels is needed for it -- the append is idempotent per issue, so it restores what the
# rewrite took and is a no-op where nothing was taken.
$newOrder = Update-PrBodySection -Body $publishedBody -Heading '' -Content $entryDescription -StopAtHeading @()
$newOrder = Add-ResolvesBlock -Body $newOrder -Issues @(919)
Assert-Set @(919) (Get-ClosedIssueNumbers -Text $newOrder) 'refresh-then-append keeps the closing keyword -- GitHub still closes #919 at the merge'
Assert-True ($newOrder -like '*the changelog entry now words it*') 'and the refresh still did its own job'

# ONE BLOCK, NOT TWO. The append runs on every -Resolves run, so a body the refresh did NOT eat must
# come back unchanged -- a second 'Closes #919' would be a duplicate section on every push.
$survived = Add-ResolvesBlock -Body $publishedBody -Issues @(919)
Assert-Equal $publishedBody $survived 'appending to a body that already closes the issue is a no-op, so a surviving block is not doubled'
Assert-Equal 1 ([regex]::Matches($newOrder, '(?m)^\s*Closes\s+#919\b').Count) 'exactly one closing keyword in the assembled body'

# AND THE SCRIPT ITSELF STILL RUNS THEM IN THAT ORDER. The asserts above prove the composition; this one
# proves open-pr.ps1 uses it, which is the half that was wrong. Read from the source for the same reason
# the placeholder coupling in pr-body.tests.ps1 is: nothing else can see a re-swap, and it fails silently.
$openPrPath = Join-Path $PSScriptRoot '..\release\open-pr.ps1'
Assert-True (Test-Path -LiteralPath $openPrPath) 'open-pr.ps1 exists where this suite looks for it'
$openPrText  = [System.IO.File]::ReadAllText((Resolve-Path $openPrPath).Path, [System.Text.Encoding]::UTF8)
$idxExisting = $openPrText.IndexOf('if ($existingPr) {')
$idxRefresh  = if ($idxExisting -ge 0) { $openPrText.IndexOf('if ($RefreshBody) {', $idxExisting) } else { -1 }
$idxAppend   = if ($idxExisting -ge 0) { $openPrText.IndexOf('Add-ResolvesBlock -Body $newBody', $idxExisting) } else { -1 }
Assert-True ($idxExisting -ge 0) 'the existing-PR path is still recognisable in open-pr.ps1'
Assert-True ($idxRefresh -gt $idxExisting) 'the -RefreshBody block sits on the existing-PR path'
Assert-True ($idxAppend -gt $idxRefresh)   'open-pr.ps1 appends the closing block AFTER the refresh, not before it (#919)'

# --- The merge verdict: which check failing actually blocks a merge (issue #943) ------------------
#
# WHY THIS SUITE EXISTS. ship-pr.ps1 read the exit code of `gh pr checks --watch` as its merge verdict.
# That exit code is non-zero when ANY check fails, so one broken advisory workflow refused every merge:
# on August 26, 2026 `claude-review` was red on every PR (#942) while `lint-en-tests` -- the only check
# the `main` ruleset requires -- was green, and GitHub itself called those PRs MERGEABLE / UNSTABLE.
# The live remote no suite can reach is the query; the SELECTION is what is asserted here.
#
# The payloads below are the real ones, read off PR #937 that day:
#   gh pr checks 937 --json name,bucket,state           -> claude-review fail, branch-entry + lint pass
#   gh pr checks 937 --required --json name,bucket,state -> lint-en-tests pass
# Both returned EXIT 0. That is the reason every assert here feeds a payload rather than an exit code:
# in --json mode gh reports the outcome in the records and not in its exit status.

Assert-Equal 'pass'    (Get-CheckOutcome -Record ([pscustomobject]@{ name = 'a'; bucket = 'pass' }))     'bucket pass -> pass'
Assert-Equal 'fail'    (Get-CheckOutcome -Record ([pscustomobject]@{ name = 'a'; bucket = 'fail' }))     'bucket fail -> fail'
Assert-Equal 'pending' (Get-CheckOutcome -Record ([pscustomobject]@{ name = 'a'; bucket = 'pending' }))  'bucket pending -> pending'
Assert-Equal 'pass'    (Get-CheckOutcome -Record ([pscustomobject]@{ name = 'a'; bucket = 'skipping' })) 'a SKIPPED check does not block a merge on GitHub either -> pass'
Assert-Equal 'fail'    (Get-CheckOutcome -Record ([pscustomobject]@{ name = 'a'; bucket = 'cancel' }))   'a CANCELLED check never went green -> fail, not pass'
Assert-Equal 'fail'    (Get-CheckOutcome -Record ([pscustomobject]@{ name = 'a'; state = 'STARTUP_FAILURE' })) 'state fallback: a workflow that never started -> fail'
Assert-Equal 'fail'    (Get-CheckOutcome -Record ([pscustomobject]@{ name = 'a'; state = 'TIMED_OUT' }))       'state fallback: timed out -> fail'
Assert-Equal 'pending' (Get-CheckOutcome -Record ([pscustomobject]@{ name = 'a'; state = 'IN_PROGRESS' }))     'state fallback: in progress -> pending'
Assert-Equal 'pass'    (Get-CheckOutcome -Record ([pscustomobject]@{ name = 'a'; state = 'SUCCESS' }))         'state fallback: success -> pass'

# 'unknown' is NOT a synonym for 'pass', and this is the assert that keeps it that way: the only caller
# is deciding whether a merge is safe, so a record it cannot read must not read as green.
Assert-Equal 'unknown' (Get-CheckOutcome -Record ([pscustomobject]@{ name = 'a' }))                   'no bucket and no state -> unknown, never pass'
Assert-Equal 'unknown' (Get-CheckOutcome -Record ([pscustomobject]@{ name = 'a'; bucket = 'wat' }))   'an unrecognised bucket with no state -> unknown'
Assert-Equal 'unknown' (Get-CheckOutcome -Record $null)                                              'a null record -> unknown'

$pr937All      = '[{"bucket":"fail","completedAt":"2026-08-26T16:07:10Z","name":"claude-review","state":"FAILURE"},{"bucket":"pass","completedAt":"2026-08-26T16:06:58Z","name":"branch-entry","state":"SUCCESS"},{"bucket":"pass","completedAt":"2026-08-26T16:15:43Z","name":"lint-en-tests","state":"SUCCESS"}]'
$pr937Required = '[{"bucket":"pass","name":"lint-en-tests","state":"SUCCESS"}]'

# THE CASE THE ISSUE IS ABOUT, in the exact shape it was measured in.
$v = Get-MergeBlockVerdict -RequiredChecksJson $pr937Required -ChecksJson $pr937All
Assert-True (-not $v.Blocked) 'PR #937 shape: required green, advisory red -> the merge is NOT blocked'
Assert-NameSet @('claude-review') $v.FailedOther 'and the run can NAME the not-required check that failed'
Assert-NameSet @() $v.FailedRequired 'nothing required failed'
Assert-True ($v.Reason -like '*claude-review*') 'the reason names it too, so the transcript says which check was merged past'

# The other direction, which must keep behaving exactly as it did before the change.
$vReq = Get-MergeBlockVerdict -RequiredChecksJson '[{"bucket":"fail","name":"lint-en-tests","state":"FAILURE"}]' -ChecksJson $pr937All
Assert-True $vReq.Blocked 'a REQUIRED check failing still blocks the merge'
Assert-NameSet @('lint-en-tests') $vReq.FailedRequired 'and it is named'
Assert-True ($vReq.Reason -like '*REQUIRES*') 'the refusal says the ruleset requires it -- the whole basis of the decision'

# Not-green is broader than failing: a required check still running, or one whose state cannot be read,
# is not something to merge past either. After --watch neither should occur; both are asserted anyway,
# because "cannot happen" is how the premise this suite replaces was justified.
$vPend = Get-MergeBlockVerdict -RequiredChecksJson '[{"bucket":"pending","name":"lint-en-tests","state":"IN_PROGRESS"}]' -ChecksJson $pr937All
Assert-True $vPend.Blocked 'a required check that has not finished blocks the merge'
$vUnk = Get-MergeBlockVerdict -RequiredChecksJson '[{"name":"lint-en-tests"}]' -ChecksJson $pr937All
Assert-True $vUnk.Blocked 'a required check whose state cannot be read blocks the merge'

# THE CONSERVATIVE HALF, and the one that keeps this fix from being a regression: with no readable
# required list there is no way to tell a ruleset that requires nothing from one whose required checks
# have not reported, so it refuses -- which is precisely what the script did before #943.
foreach ($bad in @('', '   ', 'not json at all', '[]', '[{"noname":1}]')) {
    $vBad = Get-MergeBlockVerdict -RequiredChecksJson $bad -ChecksJson $pr937All
    Assert-True $vBad.Blocked "an unreadable required list ('$bad') keeps refusing, exactly as before #943"
}

# ChecksJson is presentation only. Absent, the verdict must not move.
$vNoAll = Get-MergeBlockVerdict -RequiredChecksJson $pr937Required
Assert-True (-not $vNoAll.Blocked) 'the verdict is made from the required list alone -- no ChecksJson needed'
Assert-NameSet @() $vNoAll.FailedOther 'with nothing to read, nothing is named'
$vJunkAll = Get-MergeBlockVerdict -RequiredChecksJson $pr937Required -ChecksJson 'not json'
Assert-True (-not $vJunkAll.Blocked) 'an unreadable ChecksJson costs a name and cannot change the verdict'

# TWO OR MORE REQUIRED CHECKS -- the 5.1 array-flattening pitfall, which this file already warns about
# at step 2 of ship-pr.ps1 and which both parses here walked into anyway. `@(@($json | ConvertFrom-Json))`
# hands back ONE element holding the whole array, whose .name member-enumerates to every name at once:
# two required checks became the single string 'a b'. Measured on 2026-08-26 -- with exactly one required
# check it works by accident, because a one-element array is handed through as the object itself, and one
# required check is all this repo's ruleset has ever had.
$twoRequiredGreen = '[{"bucket":"pass","name":"lint-en-tests","state":"SUCCESS"},{"bucket":"pass","name":"branch-entry","state":"SUCCESS"}]'
$vTwo = Get-MergeBlockVerdict -RequiredChecksJson $twoRequiredGreen -ChecksJson $pr937All
Assert-True (-not $vTwo.Blocked) 'two required checks, both green -> not blocked'
Assert-NameSet @('claude-review') $vTwo.FailedOther 'and branch-entry is recognised as required, so it is not listed as an other failure'
$vTwoBad = Get-MergeBlockVerdict -RequiredChecksJson '[{"bucket":"pass","name":"lint-en-tests","state":"SUCCESS"},{"bucket":"fail","name":"branch-entry","state":"FAILURE"}]'
Assert-NameSet @('branch-entry') $vTwoBad.FailedRequired 'the SECOND of two required checks failing is still seen'
Assert-True $vTwoBad.Blocked 'and it blocks'

# --- UnfinishedRequired: the pending list, returned rather than only spoken (inbound #1549) -------
# This function already computed which required checks had not concluded and only ever handed it to the
# caller as prose inside Reason. The one caller that had to ACT on it -- ship-pr's green path, deciding
# whether a green `--watch` exit really means every required check finished -- had no field to read, and
# so read nothing. Measured September 7, 2026 in a consumer (`dkj-policy` 4.31.0,
# BWJ-Development/smartwatchbanden PR #529): `.github/dependabot.yml` passed in 1s, ship-pr called CI
# green after 5s, and the merge was refused by the base branch policy while required `Shopify theme
# check` (2m1s) was still pending.
#
# THE ASSERTS BELOW PIN THE FIELD, NEVER THE VERDICT. Every Blocked value above is unchanged and stays
# unchanged: a caller reading this field can only ever WAIT longer, which is why the fail-open assert is
# the load-bearing one here rather than an edge case.
$pr529Required = '[{"bucket":"pending","name":"Shopify theme check","state":"PENDING"}]'
$pr529All      = '[{"bucket":"pass","completedAt":"2026-09-07T12:00:01Z","name":".github/dependabot.yml","state":"SUCCESS"},{"bucket":"pending","name":"Shopify theme check","state":"PENDING"},{"bucket":"pending","name":"branch-entry","state":"PENDING"}]'
$v529 = Get-MergeBlockVerdict -RequiredChecksJson $pr529Required -ChecksJson $pr529All
Assert-NameSet @('Shopify theme check') $v529.UnfinishedRequired 'PR #529 shape: the pending REQUIRED check is named in the field, not only in the reason'
Assert-True $v529.Blocked 'and the verdict it always gave is unchanged'

# THE FAIL-OPEN HALF, and the assert this whole change stands or falls on. An unreadable required list
# still BLOCKS -- that is #943's conservative half and must not move -- but it reports NO unfinished
# names, because nothing was read. The green path waits only on a non-empty list, so this is what keeps
# the invariant intact: an unreadable payload can never turn a GREEN run red, and a repo with no ruleset
# at all (GitHub Free, nothing required) never enters that wait.
foreach ($bad in @('', '   ', 'not json at all', '[]', '[{"noname":1}]')) {
    $vBadU = Get-MergeBlockVerdict -RequiredChecksJson $bad -ChecksJson $pr529All
    Assert-True $vBadU.Blocked "an unreadable required list ('$bad') still refuses on a FAILING run"
    Assert-NameSet @() $vBadU.UnfinishedRequired "and reports no unfinished names, so a GREEN run is left green ('$bad')"
}

# Every required check green -> nothing to wait for. Without this the green path would spin forever on
# the ordinary case, which is the one way this change could have broken every ship in the repo.
Assert-NameSet @() $v.UnfinishedRequired 'PR #937 shape: required green -> nothing unfinished, so the green path breaks out as before'
Assert-NameSet @() $vTwo.UnfinishedRequired 'two required checks, both green -> nothing unfinished'

# Not-green is broader than pending, exactly as the Blocked asserts above already require: a required
# record whose state cannot be read is a check nobody has proved green, so the green path waits on it
# too rather than merging past it.
Assert-NameSet @('lint-en-tests') $vPend.UnfinishedRequired 'a pending required check is unfinished'
Assert-NameSet @('lint-en-tests') $vUnk.UnfinishedRequired 'so is one whose state cannot be read -- unknown is not a synonym for pass here either'

# Only the unfinished ones, and the 5.1 flattening pitfall the block above measured applies here too.
$vMixed = Get-MergeBlockVerdict -RequiredChecksJson '[{"bucket":"pass","name":"lint-en-tests","state":"SUCCESS"},{"bucket":"pending","name":"branch-entry","state":"IN_PROGRESS"}]' -ChecksJson $pr529All
Assert-NameSet @('branch-entry') $vMixed.UnfinishedRequired 'one of two required checks pending -> only that one is named'
Assert-True $vMixed.Blocked 'and a half-finished required list is not a green merge'

# THE FIELD IS ON EVERY SHAPE, so a caller reading it does not have to know which branch produced the
# verdict. A missing property reads as $null under StrictMode and @($null).Count is 1 -- i.e. a shape
# that forgot the field would send the green path into a wait on a name that does not exist.
foreach ($shape in @($v, $vReq, $vPend, $vUnk, $v529, $vMixed, $vTwo, $vTwoBad, $vNoAll)) {
    Assert-True ($null -ne $shape.PSObject.Properties['UnfinishedRequired']) 'every verdict shape carries UnfinishedRequired, including the ones that cannot have any'
}
Assert-NameSet @() $vReq.UnfinishedRequired 'a required check that FAILED is failed, not unfinished -- it belongs in FailedRequired'

# The same pitfall in Get-CheckWaitReport's required-name parse, which had been there since #831 and
# mislabelled every wait in any repo with more than one required check.
$twoChecks = '[{"name":"a","startedAt":"2026-08-26T16:00:00Z","completedAt":"2026-08-26T16:07:10Z"},{"name":"b","startedAt":"2026-08-26T16:00:00Z","completedAt":"2026-08-26T16:15:43Z"}]'
$reportTwo = Get-CheckWaitReport -ChecksJson $twoChecks -RequiredNamesJson '[{"name":"a"},{"name":"b"}]' -WaitedSeconds 10
Assert-True ($reportTwo -like '*, required)*') "two required names: 'b' governed and IS required -- the label must say so"
Assert-True ($reportTwo -notlike '*NOT required*') 'and must not say the opposite'
$reportOne = Get-CheckWaitReport -ChecksJson $twoChecks -RequiredNamesJson '[{"name":"a"}]' -WaitedSeconds 10
Assert-True ($reportOne -like '*NOT required*') 'one required name: the not-required label still works'
Assert-True ($reportOne -like "*after the last required check ('a')*") 'and the excess-wait clause still fires'

# --- -PostMerge: the report is printed after the merge too, and must not claim causation (#1602) ---
# ship-pr's step 8 prints this same report AFTER the merge and the fold, once the non-required checks
# have finally reported. There "governed the merge" inverts the fact the report carries: on a lap where
# the non-required check finishes last, the merge went minutes EARLIER precisely because it no longer
# waits for it. Measured on PR #1614's own successful ship, where the phrase was correct only because
# `lint-en-tests` happened to finish last that lap.
Write-Host ""
Write-Host "Get-CheckWaitReport -PostMerge -- no causation claim once the merge has happened" -ForegroundColor Cyan

$pmChecks   = '[{"name":"lint-en-tests","startedAt":"2026-09-08T16:00:00Z","completedAt":"2026-09-08T16:06:00Z"},{"name":"claude-review","startedAt":"2026-09-08T16:00:00Z","completedAt":"2026-09-08T16:12:00Z"}]'
$pmRequired = '[{"name":"lint-en-tests"}]'

$pmBefore = Get-CheckWaitReport -ChecksJson $pmChecks -RequiredNamesJson $pmRequired -WaitedSeconds 360
Assert-True ($pmBefore -like '*finished last and governed the merge*') 'without the switch the line is byte-for-byte the one #831 shipped'

$pmAfter = Get-CheckWaitReport -ChecksJson $pmChecks -RequiredNamesJson $pmRequired -WaitedSeconds 360 -PostMerge
Assert-True ($pmAfter -notlike '*governed the merge*') 'with it, the causation claim is gone -- nothing after the merge governed it'
Assert-True ($pmAfter -like "*'claude-review' finished last*") 'while the check that finished last is still named, which is #831''s actual question'

# EVERYTHING ELSE ON THE LINE IS WANTED AFTER THE MERGE TOO, which is why this is a wording switch
# rather than a second report. Asserted individually, because a switch that quietly dropped the
# not-required label or the excess clause would take the report's whole value with it.
Assert-True ($pmAfter -like '*NOT required*') 'the required/not-required label survives'
Assert-True ($pmAfter -like "*after the last required check ('lint-en-tests')*") 'and so does the excess clause -- the number that sizes the tail'
Assert-True ($pmAfter -like '*6m 00s*') 'and the excess is still measured, not merely mentioned'
Assert-True ($pmAfter -like '*waited*') 'and the wall-clock the step itself spent is still reported'

# THE SWITCH CHANGES NOTHING ELSE, asserted by comparing the two lines with the phrase removed.
$pmBeforeNormalised = $pmBefore -replace 'finished last and governed the merge', 'finished last'
Assert-Equal $pmBeforeNormalised $pmAfter 'the two lines differ in exactly that phrase and nowhere else'

# AND A REQUIRED CHECK FINISHING LAST READS CORRECTLY BOTH WAYS -- the case PR #1614 happened to hit,
# which is why the defect survived its own successful ship.
$pmReqLast = Get-CheckWaitReport -ChecksJson '[{"name":"claude-review","startedAt":"2026-09-08T16:00:00Z","completedAt":"2026-09-08T16:03:00Z"},{"name":"lint-en-tests","startedAt":"2026-09-08T16:00:00Z","completedAt":"2026-09-08T16:06:00Z"}]' -RequiredNamesJson $pmRequired -WaitedSeconds 360 -PostMerge
Assert-True ($pmReqLast -like "*'lint-en-tests' finished last*") 'the required check finishing last is named the same way'
Assert-True ($pmReqLast -like '*, required)*') 'and labelled required'
Assert-True ($pmReqLast -notlike '*after the last required check*') 'with no excess clause, there being no tail to size'

# The call-site pins for this switch live in the ship-pr section below, where $shipText exists.
# They were first written HERE, above its assignment, and the failure mode is worth stating exactly
# because it cuts both ways: `$null -like '*x*'` is FALSE, so a positive assert placed too early
# fails loudly and gets found -- which is what happened. `$null -notlike '*x*'` is TRUE, so a
# NEGATIVE one would have passed silently forever. Audited on the way past: every -notlike in this
# suite reads a locally computed value, not a source-text variable assigned further down.

# --- Get-RequiredCheckNames: the shared walk over the required payload (issue #1602) --------------
# THE ONE-CHECK RULESET IS WHY THIS SUITE EXISTS AT ALL. This repo requires exactly one check, and a
# one-element JSON array is handed through by 5.1 as the object itself -- so the collapse that
# mislabelled every wait in a two-required-check repo (asserted directly above) is invisible to any
# fixture that mirrors this repo's own ruleset. Every shape below therefore includes the two-name
# case, which is the shape nobody here runs and the one a consumer may.
Write-Host ""
Write-Host "Get-RequiredCheckNames -- the shared required-check walk" -ForegroundColor Cyan

Assert-NameSet @('lint-en-tests') (Get-RequiredCheckNames -RequiredChecksJson '[{"name":"lint-en-tests","bucket":"pass","state":"SUCCESS"}]') `
    'one required check: the ordinary shape in this repo'
Assert-NameSet @('a','b') (Get-RequiredCheckNames -RequiredChecksJson '[{"name":"a"},{"name":"b"}]') `
    'TWO required checks: the 5.1 member-enumeration collapse would answer with the single string "a b"'
Assert-Equal 2 (@(Get-RequiredCheckNames -RequiredChecksJson '[{"name":"a"},{"name":"b"}]')).Count `
    'and the count is 2 rather than 1 -- the collapse is a count bug before it is a name bug'
Assert-NameSet @('a','b','c') (Get-RequiredCheckNames -RequiredChecksJson '[{"name":"c"},{"name":"a"},{"name":"b"}]') `
    'three required checks, unsorted in: sorted out, so a caller may compare two readings for equality'
Assert-NameSet @('a') (Get-RequiredCheckNames -RequiredChecksJson '[{"name":"a"},{"name":"a"}]') `
    'a duplicated name collapses to one -- Sort-Object -Unique, so a re-read cannot look like a change'

# EMPTY IS A STATE, NOT A FAILURE. Every one of these is a legitimate reading -- a ruleset that
# requires nothing, a required workflow that has not registered yet, a gh that answered nothing -- and
# each caller breaks the tie itself: the wait falls back to watching every check, step 3b warns and
# skips, and the merge verdict refuses on the failure path only.
Assert-Equal 0 (@(Get-RequiredCheckNames -RequiredChecksJson '')).Count            'empty payload: no names, no throw'
Assert-Equal 0 (@(Get-RequiredCheckNames -RequiredChecksJson '   ')).Count         'whitespace payload: no names'
Assert-Equal 0 (@(Get-RequiredCheckNames -RequiredChecksJson '[]')).Count          'empty list: no names -- the 5.1 array trap again'
Assert-Equal 0 (@(Get-RequiredCheckNames -RequiredChecksJson 'not json')).Count    'unparseable payload: no names rather than an exception'
Assert-Equal 0 (@(Get-RequiredCheckNames -RequiredChecksJson '[{"bucket":"pass"}]')).Count `
    'a nameless record names nothing -- the field the whole walk is about is the one that may be absent'
Assert-NameSet @('a') (Get-RequiredCheckNames -RequiredChecksJson '[{"name":"a"},{"name":""},{"name":null}]') `
    'blank and null names are dropped rather than returned as empty strings a caller would watch on'
Assert-NameSet @('lint en tests') (Get-RequiredCheckNames -RequiredChecksJson '[{"name":"lint en tests"}]') `
    'a name containing a space stays ONE name -- the shape a space-splitting parse silently doubles'

# --- Get-RequiredCheckContexts: the required contexts, off the RULESET (issue #1602) --------------
# WHY A SECOND READER OF "WHAT IS REQUIRED" EXISTS AT ALL, since Get-RequiredCheckNames above already
# answers it: they read different sources, and only one of them has a registration race. The PR's
# check list reports the required checks THAT HAVE REGISTERED; the ruleset states the contexts whether
# or not anything has. Measured on PR #1614, where the probe ran seconds after open-pr's push, found
# nothing, and made the whole change inert.
Write-Host ""
Write-Host "Get-RequiredCheckContexts -- the required contexts off the trunk's ruleset" -ForegroundColor Cyan

$rulesOne = '[{"type":"pull_request"},{"type":"required_status_checks","parameters":{"strict_required_status_checks_policy":false,"required_status_checks":[{"context":"lint-en-tests","integration_id":15368}]}}]'
$ctxOne = Get-RequiredCheckContexts -BranchRulesJson $rulesOne
Assert-True $ctxOne.Readable 'a readable ruleset says so'
Assert-NameSet @('lint-en-tests') $ctxOne.Names 'and names the one context this repo''s own ruleset requires'

$rulesTwo = '[{"type":"required_status_checks","parameters":{"required_status_checks":[{"context":"a"},{"context":"b"}]}}]'
$ctxTwo = Get-RequiredCheckContexts -BranchRulesJson $rulesTwo
Assert-NameSet @('a','b') $ctxTwo.Names 'TWO contexts: the 5.1 collapse would answer with one bogus string, and this repo cannot produce that shape'
Assert-Equal 2 (@($ctxTwo.Names)).Count 'and the count is 2 -- the collapse is a count bug before it is a name bug'

# READABLE-AND-EMPTY IS A POSITIVE ANSWER, and it is the whole reason this returns two fields. "This
# trunk requires nothing" (GitHub Free, or a ruleset with no such rule) must be distinguishable from
# "the question was not answered", because the caller watches every check in the first case and falls
# back to the probe in the second.
$ctxNoRule = Get-RequiredCheckContexts -BranchRulesJson '[{"type":"pull_request"},{"type":"deletion"}]'
Assert-True $ctxNoRule.Readable 'a ruleset with no required-checks rule is READABLE'
Assert-Equal 0 (@($ctxNoRule.Names)).Count 'and requires nothing -- a positive answer, not a failure to read'
$ctxNull = Get-RequiredCheckContexts -BranchRulesJson '[]'
Assert-True $ctxNull.Readable 'an EMPTY rules array is readable too -- 5.1 parses it to $null, the trap the parse beside it documents'
Assert-Equal 0 (@($ctxNull.Names)).Count 'and it means the trunk has no rules at all'

foreach ($bad in @('', '   ', 'not json')) {
    $ctxBad = Get-RequiredCheckContexts -BranchRulesJson $bad
    Assert-True (-not $ctxBad.Readable) "an unreadable payload ('$bad') reports Readable = false rather than 'requires nothing'"
    Assert-Equal 0 (@($ctxBad.Names)).Count "and names nothing with it"
}

# MALFORMED SHAPES FAIL TO 'NO NAMES' WITHOUT CLAIMING UNREADABLE -- the payload parsed, so the
# question WAS answered; what it answered is that nothing matched.
Assert-Equal 0 (@((Get-RequiredCheckContexts -BranchRulesJson '[{"type":"required_status_checks"}]').Names)).Count 'a required-checks rule with no parameters names nothing'
Assert-Equal 0 (@((Get-RequiredCheckContexts -BranchRulesJson '[{"type":"required_status_checks","parameters":{}}]').Names)).Count 'nor one whose parameters carry no check list'
Assert-Equal 0 (@((Get-RequiredCheckContexts -BranchRulesJson '[{"type":"required_status_checks","parameters":{"required_status_checks":[{"integration_id":1}]}}]').Names)).Count 'nor an entry with no context field -- the field the whole read is about is the one that may be absent'
Assert-NameSet @('a') (Get-RequiredCheckContexts -BranchRulesJson '[{"type":"required_status_checks","parameters":{"required_status_checks":[{"context":"a"},{"context":"  "},{"context":""}]}}]').Names 'blank contexts are dropped rather than watched on'
Assert-NameSet @('lint-en-tests') (Get-RequiredCheckContexts -BranchRulesJson '[{"type":"REQUIRED_STATUS_CHECKS","parameters":{"required_status_checks":[{"context":"lint-en-tests"}]}}]').Names 'the rule type is matched case-insensitively, as every other read of this payload does'

# AND THE TWO CALLERS THAT SHARE IT MUST AGREE WITH IT, or the refactor moved a bug rather than a
# duplicate: Get-MergeBlockVerdict reads the same payload for its own verdict, and a payload this
# function reads as naming nothing is exactly the one the verdict must treat as unreadable.
Assert-True (Get-MergeBlockVerdict -RequiredChecksJson '[{"bucket":"pass"}]').Blocked `
    'a payload Get-RequiredCheckNames finds no name in is the payload the verdict refuses on'
Assert-True (Get-MergeBlockVerdict -RequiredChecksJson 'not json').Blocked `
    'and the same for one neither of them can parse'

# The prose helper. Quoted per name, so a check name containing a space cannot read as two.
Assert-Equal ''                     (Format-CheckNameList -Names @())                'no names -> empty, so a caller can concatenate unconditionally'
Assert-Equal "'a'"                  (Format-CheckNameList -Names @('a'))             'one name'
Assert-Equal "'a' and 'b'"          (Format-CheckNameList -Names @('a','b'))         'two names joined with and'
Assert-Equal "'a', 'b' and 'c'"     (Format-CheckNameList -Names @('a','b','c'))     'three names: commas then and'
Assert-Equal "'lint en tests'"      (Format-CheckNameList -Names @('lint en tests')) 'a name with spaces stays one quoted item'
Assert-Equal "'a'"                  (Format-CheckNameList -Names @('a','',$null))    'blanks are dropped rather than quoted as empty'

# INBOUND #1044 -- A RUN THAT NEVER STARTED IS NOT A CHECK THAT WENT RED.
# Measured August 28, 2026 in a consumer repo: Actions refused to start jobs because an account
# payment had failed, every run ended in ~4s with zero steps, and ship-pr reported "CI did not pass
# ... Fix CI and re-run". Both halves true, and together they send the reader into their own code for
# a state no branch can repair -- it cost a hand-merge. The verdict above is deliberately untouched;
# what these asserts pin is the DIAGNOSIS printed beside the refusal.

# The lookup key: only the failing records, only their Actions run, deduped, in order.
$linkChecks = '[{"bucket":"fail","name":"lint-en-tests","state":"FAILURE","link":"https://github.com/o/r/actions/runs/123/job/456"},{"bucket":"pass","name":"branch-entry","state":"SUCCESS","link":"https://github.com/o/r/actions/runs/999/job/1"},{"bucket":"fail","name":"claude-review","state":"FAILURE","link":"https://github.com/o/r/actions/runs/123/job/789"}]'
Assert-NameSet @('123') (Get-FailedCheckRunIds -ChecksJson $linkChecks) 'two failing checks from ONE run yield that run once, and the green check is not asked about'
$extChecks = '[{"bucket":"fail","name":"ext","state":"FAILURE","link":"https://ci.example.com/build/7"}]'
Assert-NameSet @() (Get-FailedCheckRunIds -ChecksJson $extChecks) 'a failing status with no Actions run is skipped -- it has no jobs to ask about'
Assert-NameSet @() (Get-FailedCheckRunIds -ChecksJson $pr937All) 'a payload without the link field yields nothing rather than throwing'
foreach ($bad in @('', '   ', 'not json', '[]')) {
    Assert-NameSet @() (Get-FailedCheckRunIds -ChecksJson $bad) "an unreadable checks payload ('$bad') yields no run ids"
}

# The diagnosis itself. Both shapes the report measured count as "nothing ran".
$runNoJobs  = '{"conclusion":"failure","status":"completed","url":"https://github.com/o/r/actions/runs/123","jobs":[]}'
$runNoSteps = '{"conclusion":"failure","status":"completed","url":"https://github.com/o/r/actions/runs/123","jobs":[{"name":"lint-en-tests","steps":[]}]}'
$runRan     = '{"conclusion":"failure","status":"completed","url":"https://github.com/o/r/actions/runs/123","jobs":[{"name":"lint-en-tests","steps":[{"name":"Set up job","conclusion":"success"}]}]}'

$noteA = Get-StalledRunNote -RunJson $runNoJobs -RunId '123'
Assert-True ($noteA -ne '') 'a run with an empty jobs array is recognised as never having started'
Assert-True ($noteA -like '*never started*') 'and the note says so in those words -- the whole point of the repair'
Assert-True ($noteA -like '*not a check that went red*') 'it states the negative too, since that is the reading being corrected'
Assert-True ($noteA -like '*gh run view 123*') 'and names the one command that prints the reason, which the run page does not show'

$noteB = Get-StalledRunNote -RunJson $runNoSteps -RunId '123'
Assert-True ($noteB -ne '') 'a run whose only job executed no step is the same state'
Assert-True ($noteB -like '*one job executed no step*') 'and the note distinguishes it from "no job at all"'

# THE ASSERT THAT KEEPS THIS FROM CRYING WOLF. An ordinary red check runs steps, and on those the
# operator must keep reading the old wording -- "fix CI and re-run" is correct there.
Assert-Equal '' (Get-StalledRunNote -RunJson $runRan -RunId '123') 'a job that executed even one step is an ordinary failure -- no note'
$runMixed = '{"status":"completed","jobs":[{"name":"a","steps":[]},{"name":"b","steps":[{"name":"Set up job"}]}]}'
Assert-Equal '' (Get-StalledRunNote -RunJson $runMixed) 'one job of two having run is still "something ran"'
$runTwoIdle = '{"status":"completed","jobs":[{"name":"a","steps":[]},{"name":"b","steps":[]}]}'
Assert-True ((Get-StalledRunNote -RunJson $runTwoIdle) -like '*none of its 2 jobs executed a step*') 'two idle jobs are counted rather than described in the singular'

# A run that has not finished has no steps either. ship-pr only reaches this after --watch, so it
# cannot happen there -- asserted anyway, because "cannot happen" is how the premise #943 replaced
# was justified.
Assert-Equal '' (Get-StalledRunNote -RunJson '{"status":"in_progress","jobs":[{"name":"a","steps":[]}]}') 'a run still in progress is not stalled'
Assert-Equal '' (Get-StalledRunNote -RunJson '{"status":"queued","jobs":[]}') 'a queued run is not stalled either'

# Unreadable in, empty out: a diagnostic must never be the reason a refusal cannot be printed.
foreach ($bad in @('', '   ', 'not json', 'null', '{}', '{"status":"completed"}')) {
    Assert-Equal '' (Get-StalledRunNote -RunJson $bad) "an unreadable run payload ('$bad') costs the note and nothing else"
}

# Without a run id the note still stands and falls back to the URL the payload carried.
$noteNoId = Get-StalledRunNote -RunJson $runNoJobs
Assert-True ($noteNoId -like '*https://github.com/o/r/actions/runs/123*') 'no run id: the note points at the run URL instead'
Assert-True ($noteNoId -notlike '*gh run view *') 'and does not print a command with a missing argument'

# AND SHIP-PR ITSELF STILL USES IT. The asserts above prove the decision; this one proves the caller
# asks for it -- the same reasoning as the open-pr ordering assert above, and the same failure mode: a
# reverted call site would leave every assert here green while the merge refused as before.
$shipPrPath = Join-Path $PSScriptRoot '..\release\ship-pr.ps1'
Assert-True (Test-Path -LiteralPath $shipPrPath) 'ship-pr.ps1 exists where this suite looks for it'
$shipText = [System.IO.File]::ReadAllText((Resolve-Path $shipPrPath).Path, [System.Text.Encoding]::UTF8)
Assert-True ($shipText -like '*Get-MergeBlockVerdict -RequiredChecksJson*') 'ship-pr.ps1 consults the verdict rather than the --watch exit code alone'
Assert-True ($shipText -like '*--required*name,bucket,state*') 'and asks gh for the required checks WITH their state, since --json mode does not carry it in the exit code'
Assert-True ($shipText -like '*Get-FailedCheckRunIds -ChecksJson*') 'ship-pr.ps1 asks which runs failed before it words the refusal (#1044)'
Assert-True ($shipText -like '*Get-StalledRunNote -RunJson*') 'and asks whether those runs ever started'
Assert-True ($shipText -like '*startedAt,completedAt,link*') 'which needs the link field, the only one naming the run behind a check'
Assert-True ($shipText -like '*CI never RAN for PR*') 'and a stalled run gets its own lead sentence rather than "CI did not pass"'
Assert-True ($shipText -like '*Fix CI and re-run, or merge manually once green.*') 'while an ordinary red check keeps the wording that is correct for it'
$idxWatch   = $shipText.IndexOf("'--watch'")
$idxVerdict = $shipText.IndexOf('Get-MergeBlockVerdict')
Assert-True ($idxWatch -ge 0 -and $idxVerdict -gt $idxWatch) 'the wait still happens FIRST and the verdict second -- #831 kept the wait, #943 changed only the verdict'

# AND THE GREEN PATH READS THE PENDING LIST (inbound #1549). The field asserts above prove the function
# reports it; these prove the caller acts on it. Same failure mode as the pins above and worse here,
# because the defect being closed is precisely a call site that had the facts in hand and broke past
# them: reverting this one line would leave every assert in this suite green while ship-pr merged past
# a pending required check again.
Assert-True ($shipText -like '*.UnfinishedRequired*') 'ship-pr.ps1 reads the pending-required list, not just the --watch exit code, before calling CI green'
$idxGreenBreak = $shipText.IndexOf('$pendingRequired.Count -eq 0')
Assert-True ($idxGreenBreak -gt $idxVerdict -or $shipText -like '*$pendingRequired.Count -eq 0*') 'and it breaks out of the wait only when that list is EMPTY'
Assert-True ($shipText -like '*went green off a NOT-required check*') 'a green watch over a pending required check re-enters the wait, in a sentence that says which reading was wrong'
Assert-True ($shipText -like '*still not finished after*') 'and the bounded case refuses rather than merging into the base-branch policy'
# The fail-open direction, pinned as text because it is a decision rather than a behaviour this suite can
# drive: the caller must spin on a NON-EMPTY list, so an unreadable payload (empty list, per the asserts
# above) leaves a green run green.
Assert-True ($shipText -like '*FAIL-OPEN ON AN UNREADABLE PAYLOAD*') 'and the call site records that an unreadable required list does not start a wait'

# THE FALLBACK LINE IS ABOUT THE PAYLOAD, NOT ABOUT THE RULESET (inbound #1083). $line3 above already
# proves a repo that requires NOTHING still gets a rendered report -- so the fallback is not that repo's
# line, and wording it as one would send a reader with no ruleset looking for a setting they cannot have.
Assert-True ($shipText -like '*no readable check facts*') 'ship-pr''s wait-report fallback names the payload it could not read'
Assert-True ($shipText -notmatch 'which check governed could not be read') 'and no longer words that as a fault about the wait itself'


# --- Get-LostWatchNote: the watch dropped, CI did not (issue #1219) -------------------------------
# Measured on PR #1218, September 2, 2026: `gh pr checks --watch` died after nine clean poll cycles on
# `wsarecv: An existing connection was forcibly closed by the remote host`, exited non-zero, and
# ship-pr said "CI did not pass ... Fix CI and re-run" about a run that went green minutes later. The
# third case of the distinction #943 and #1044 already drew twice -- and the verdict is untouched for
# the third time: these asserts pin the DIAGNOSIS and the RETRY DECISION, never the merge.

# The measured payload, read seconds after the drop: one check green, two still running, none failed.
$dropped = '[{"bucket":"pass","name":"branch-entry","state":"SUCCESS"},{"bucket":"pending","name":"lint-en-tests","state":"IN_PROGRESS"},{"bucket":"pending","name":"claude-review","state":"PENDING"}]'
$lostNote = Get-LostWatchNote -ChecksJson $dropped -PrNumber '1218'
Assert-True ($lostNote -ne '') 'nothing failed while two checks are still running -- the exit code is contradicted by the payload'
Assert-True ($lostNote -like '*WATCH dropped*') 'and the note names the watch as what broke, which is the whole reading being corrected'
Assert-True ($lostNote -like '*nothing to re-run*') 'it states the negative too: there is no branch-side repair for a healthy run'
Assert-True ($lostNote -like "*'claude-review' and 'lint-en-tests' are still running*") 'the pending checks are named and read as prose, not as System.Object[]'
Assert-True ($lostNote -like '*gh pr checks 1218 --watch*') 'and it names the one command that re-enters the wait'

$lostNoteOne = Get-LostWatchNote -ChecksJson '[{"bucket":"pending","name":"lint-en-tests","state":"QUEUED"}]' -PrNumber '7'
Assert-True ($lostNoteOne -like "*'lint-en-tests' is still running*") 'one pending check is described in the singular'

# THE ASSERT THAT KEEPS THIS FROM MIS-NARRATING A REAL FAILURE, and it is the mirror of the
# cry-wolf assert Get-StalledRunNote carries. ONE failing check makes the non-zero exit a verdict,
# whatever else is still pending, and there the old wording is the correct one.
$redPlusPending = '[{"bucket":"fail","name":"lint-en-tests","state":"FAILURE"},{"bucket":"pending","name":"claude-review","state":"PENDING"}]'
Assert-Equal '' (Get-LostWatchNote -ChecksJson $redPlusPending) 'a failing check beside a pending one is a verdict -- no note, so "Fix CI and re-run" still prints'
Assert-Equal '' (Get-LostWatchNote -ChecksJson $pr937All) 'the #943 payload (claude-review red, lint-en-tests green) is a verdict too'
foreach ($state in @('CANCELLED', 'TIMED_OUT', 'STARTUP_FAILURE')) {
    $cj = "[{`"bucket`":`"fail`",`"name`":`"a`",`"state`":`"$state`"},{`"bucket`":`"pending`",`"name`":`"b`",`"state`":`"PENDING`"}]"
    Assert-Equal '' (Get-LostWatchNote -ChecksJson $cj) "a $state check is read through Get-CheckOutcome and is not a socket either"
}

# NOTHING PENDING, NOTHING SAID. A payload in which everything passed does not reach this -- the
# verdict is not Blocked there, so the caller takes its merge-proceeds path -- and "all green and the
# watch exited non-zero" wants a different sentence from this one.
Assert-Equal '' (Get-LostWatchNote -ChecksJson '[{"bucket":"pass","name":"a","state":"SUCCESS"}]') 'every check passed: not this note''s case'
Assert-Equal '' (Get-LostWatchNote -ChecksJson '[{"bucket":"weird","name":"a","state":"HUH"}]') 'an unrecognised state is not proof anything is running, so nothing is claimed'

# UNREADABLE IN, EMPTY OUT -- the OPPOSITE of Get-MergeBlockVerdict's answer to the same input, and
# right in both places. There silence must refuse, because it guards a merge; here silence must not
# narrate, because a "CI is still running" in front of a red check is worse than the old wording.
foreach ($bad in @('', '   ', 'not json', 'null', '[]', '{}', '[{"bucket":"pending"}]')) {
    Assert-Equal '' (Get-LostWatchNote -ChecksJson $bad) "an unreadable checks payload ('$bad') costs the note and the retry, and claims nothing"
}

# Without a PR number the note still stands and simply stops after the state it read.
$lostNoId = Get-LostWatchNote -ChecksJson $dropped
Assert-True ($lostNoId -like '*WATCH dropped*') 'no PR number: the diagnosis is unchanged'
Assert-True ($lostNoId -notlike '*gh pr checks  --watch*') 'and no command is printed with a missing argument'

# AND SHIP-PR ACTUALLY RETRIES ON IT. The asserts above prove the decision; these prove the caller
# both asks for it and acts on it -- the same reasoning as the #1044 call-site asserts above, and the
# same failure mode: a reverted call site would leave every assert here green while a dropped watch
# still cost a re-checkout and a duplicate gate run.
Assert-True ($shipText -like '*Get-LostWatchNote -ChecksJson*') 'ship-pr.ps1 asks whether a non-zero watch was the connection rather than a check (#1219)'
Assert-True ($shipText -like '*maxWatchAttempts*') 'and the retry is BOUNDED rather than a loop with no ceiling'
Assert-True ($shipText -like '*CI is still RUNNING for PR*') 'a dropped watch gets its own lead sentence, beside "CI never RAN" and "CI did not pass"'
$idxWatchCall = $shipText.IndexOf("'--watch'")
$idxLost      = $shipText.IndexOf('Get-LostWatchNote -ChecksJson')
Assert-True ($idxLost -gt $idxWatchCall) 'the read happens AFTER the watch it is diagnosing'
# The retry needs the check payload, so the fact-pair read moved inside the loop -- and the loop has to
# close after it, or the second attempt would judge the first attempt's payload.
$idxLoopHead  = $shipText.IndexOf('$watchAttempt++')
Assert-True ($idxLoopHead -ge 0 -and $idxLoopHead -lt $idxWatchCall) 'the watch call sits inside the attempt loop rather than before it'
$idxFacts     = $shipText.IndexOf('startedAt,completedAt,link')
Assert-True ($idxFacts -gt $idxWatchCall -and $idxFacts -lt $idxLost) 'and the check facts are re-read per attempt, which is what the decision is made from'


# --- issue #1350: the watch started BEFORE the checks registered ---------------------------------
# Observed on PR #1348, September 3, 2026: `gh pr checks --watch` ran seconds after open-pr pushed a
# new head, printed `no checks reported` in its own output and exited non-zero -- and ship-pr read
# that transient as a CI verdict ("Fix CI and re-run"), because none of the three wording guards
# covers "nothing is registered". The fix reuses step 3's registration wait: it is a function now
# (Wait-CheckRegistration), so the watch loop can fall back into the SAME wait rather than through to
# Get-MergeBlockVerdict. Text asserts, like the #1044 / #1219 call-site pins above -- the function is
# script-local and dot-sourcing ship-pr.ps1 to reach it would run the whole ship.
Write-Host "ship-pr.ps1 -- the watch re-enters the registration wait when it starts too early (#1350)" -ForegroundColor Cyan
Assert-True ($shipText -like '*function Wait-CheckRegistration*') 'step 3''s registration wait is a function, so it can be re-entered (#1350)'
# THE WORDING WIDENED AT #1602 (gh says `no required checks reported` on a narrowed watch), and the
# claim is unchanged: the poll breaks out on the TEXT, not on the exit code.
Assert-True ($shipText -like "*-notmatch 'no (required )?checks reported'*") 'and it still breaks out on the TEXT, not the exit code, exactly as the inline loop did'
$idxFn       = $shipText.IndexOf('function Wait-CheckRegistration')
$idxFirstUse = $shipText.IndexOf('Wait-CheckRegistration -Pr')
$idxReentry  = $shipText.LastIndexOf('Wait-CheckRegistration -Pr')
Assert-True ($idxFn -ge 0 -and $idxFirstUse -gt $idxFn) 'the function is defined before it is called'
Assert-True ($idxFirstUse -lt $idxWatchCall) 'step 3 runs the wait before the --watch call, as the inline loop did'
Assert-True ($idxReentry -gt $idxWatchCall) 'and the watch loop re-enters that SAME wait after --watch (#1350)'
Assert-True ($shipText -like '*back to the registration wait (#1350)*') 'the fallback says what it is doing, rather than wording the transient as a CI failure'
$idxGuard = $shipText.IndexOf("-match 'no (required )?checks reported'")
Assert-True ($idxGuard -gt $idxWatchCall -and $idxGuard -lt $idxReentry) 'the re-entry is guarded by the watch''s own no-checks output -- a real red check (a table, not that phrase) still falls through to the verdict'
Assert-True ($shipText -like '*-AlreadyWaited $waited*') 'and it shares the 180s budget rather than restarting it, so a race that will not settle still ends in the #1234 refusal'
$countSuiteNote = ([regex]::Matches($shipText, 'Get-MissingCheckSuiteNote -SuitesJson')).Count
Assert-Equal 1 $countSuiteNote 'the #1234 / #1247 timeout diagnostic moved WITH the loop into the function -- written once, not duplicated at the watch site'


# --- Get-MissingCheckSuiteNote: no Actions suite was ever created (issue #1234) --------------------
# Measured on PR #1233, September 2, 2026, head b09c71b2: the step-3 probe ran its full 180s and
# refused with "Check the workflow", while `gh run list` was empty and the commit's check-suite list
# held netlify and claude and NO github-actions suite -- Actions demonstrably healthy elsewhere in the
# repo the same minute. The fourth case of the distinction #943, #1044 and #1219 already drew three
# times, and the refusal is untouched for the fourth time: these asserts pin the DIAGNOSIS, never the
# merge decision.
Write-Host "Get-MissingCheckSuiteNote -- no Actions suite for this commit" -ForegroundColor Cyan

# The measured payload: two suites from other providers, none from Actions.
$suitesNoActions = '{"total_count":2,"check_suites":[{"status":"queued","app":{"slug":"netlify"}},{"status":"queued","app":{"slug":"claude"}}]}'
$missNote = Get-MissingCheckSuiteNote -SuitesJson $suitesNoActions -PrNumber '1233'
Assert-True ($missNote -ne '') 'two suites and none from Actions is recognised as "no workflow was ever asked to run"'
Assert-True ($missNote -like '*no Actions check suite*') 'and the note names what is MISSING rather than sending the reader to the workflow files'
Assert-True ($missNote -like "*only 'netlify' and 'claude' registered*") 'the suites that DO exist are named, so the reader sees what was asked and what was not'
Assert-True ($missNote -like '*NOT a paths: filter*') 'it states the negative too, since "check the workflow" is the reading being corrected'
Assert-True ($missNote -like '*gh pr close 1233 && gh pr reopen 1233*') 'and it names the remedy, which is not a thing an operator guesses'
Assert-True ($missNote -like '*not a diagnosis*') 'while saying plainly that the reopen is the cheapest thing to TRY, not a cause it has established'

# THE ASSERT THAT KEEPS THIS FROM CRYING WOLF, the same one its three siblings carry. An Actions suite
# that exists and has not reported is exactly the case the OLD wording is correct for -- there the
# workflow really may be why -- so this note must stay out of the way whatever that suite is doing.
$suitesWithActions = '{"check_suites":[{"status":"queued","app":{"slug":"netlify"}},{"status":"in_progress","app":{"slug":"github-actions"}}]}'
Assert-Equal '' (Get-MissingCheckSuiteNote -SuitesJson $suitesWithActions -PrNumber '1233') 'an Actions suite that exists is not this note''s case'
Assert-Equal '' (Get-MissingCheckSuiteNote -SuitesJson '{"check_suites":[{"status":"completed","app":{"slug":"github-actions"}}]}') 'a completed Actions suite is not it either -- the question is existence, not outcome'

# An empty suite list is the same finding said differently, and gets its own clause rather than a
# sentence naming an empty list, which reads as a bug in the note.
$missEmpty = Get-MissingCheckSuiteNote -SuitesJson '{"total_count":0,"check_suites":[]}' -PrNumber '7'
Assert-True ($missEmpty -like '*nothing registered for it at all*') 'a commit carrying no suite whatsoever says so'
Assert-True ($missEmpty -like '*gh pr close 7 && gh pr reopen 7*') 'and still gets the remedy -- the finding is the same one'

# Singular where one other provider registered, plural where several did.
$missOne = Get-MissingCheckSuiteNote -SuitesJson '{"check_suites":[{"app":{"slug":"netlify"}}]}'
Assert-True ($missOne -like "*only 'netlify' registered*") 'one foreign suite reads the same way -- the clause takes no grammatical number'
Assert-True ($missNote -notlike '*commit -- the commit*') 'and the sentence names the commit once, not twice'

# A suite whose app gh did not return is skipped rather than throwing -- absent is not empty under
# Set-StrictMode, the trap every reader in this lib guards against.
$missAppless = Get-MissingCheckSuiteNote -SuitesJson '{"check_suites":[{"status":"queued"},{"app":null},{"app":{"slug":"netlify"}}]}'
Assert-True ($missAppless -like "*'netlify'*") 'a suite with no readable app is skipped and the readable one still counted'
Assert-True ($missAppless -notlike '*and*registered*') 'and the unreadable ones are not listed beside it'

# The same slug twice is one provider, not two -- GitHub lists a suite per app INSTALLATION, and #1233
# itself came back with three github-actions rows once the reopen had fired.
$missDupe = Get-MissingCheckSuiteNote -SuitesJson '{"check_suites":[{"app":{"slug":"netlify"}},{"app":{"slug":"netlify"}}]}'
Assert-True ($missDupe -like "*only 'netlify' registered*") 'a repeated slug is deduped rather than listed twice'

# UNREADABLE IN, EMPTY OUT: a diagnostic must never be the reason a refusal cannot be printed. The
# refusal prints with or without this note, which is what makes attempting the read safe at all.
foreach ($bad in @('', '   ', 'not json', 'null', '{}', '[]', '{"total_count":0}')) {
    Assert-Equal '' (Get-MissingCheckSuiteNote -SuitesJson $bad) "an unreadable check-suites payload ('$bad') costs the note and nothing else"
}

# Without a PR number the diagnosis still stands and simply stops before the command.
$missNoId = Get-MissingCheckSuiteNote -SuitesJson $suitesNoActions
Assert-True ($missNoId -like '*no Actions check suite*') 'no PR number: the diagnosis is unchanged'
Assert-True ($missNoId -notlike '*gh pr close *') 'and no command is printed with a missing argument'

# --- The conflicting PR: the one cause that is checkable rather than guessed (issue #1247) ---------
# Measured September 2, 2026. A pull_request workflow runs against refs/pull/<n>/merge, which a
# conflicting PR does not have -- so no suite is created for it, and #1247 read that as an Actions
# outage across the whole org. PR #1243 (CONFLICTING) had no merge ref and 0 suites, and stayed at 0
# through a close/reopen AND a freshly pushed head; #1240 and #1249, opened either side of it, each had
# a merge ref and three suites. These asserts pin the DIAGNOSIS; the refusal is untouched, again.
Write-Host "Get-MissingCheckSuiteNote -- the conflicting PR (#1247)" -ForegroundColor Cyan

$missConflict = Get-MissingCheckSuiteNote -SuitesJson $suitesNoActions -PrNumber '1243' -Mergeable 'CONFLICTING'
Assert-True ($missConflict -like '*CONFLICTING*') 'a conflicting PR is named as such, in GitHub''s own word'
Assert-True ($missConflict -like '*refs/pull/*') 'and the note says WHICH commit does not exist, since that is the whole mechanism'
Assert-True ($missConflict -like '*Resolve the conflict*') 'the repair named is the one that works -- resolve, then push'
# THE POINT OF THE BRANCH, not a nicety: the reopen is measured to do nothing here, and printing it
# beside the real repair leaves the reader to choose between them with the cheap one listed first.
Assert-True ($missConflict -notlike '*gh pr close 1243 && gh pr reopen 1243*') 'and the reopen is WITHHELD rather than offered beside it'
Assert-True ($missConflict -like '*measured*') 'while saying the reopen was measured doing nothing, so the reader does not try it anyway'
Assert-True ($missConflict -like '*no Actions check suite*') 'the #1234 finding still leads -- the conflict explains it, it does not replace it'

# EVERY OTHER ANSWER LEAVES THE #1234 WORDING EXACTLY AS IT WAS. UNKNOWN is GitHub still computing the
# merge, and reading it as a conflict would be this function guessing at a cause -- the failure it
# exists to end. An absent argument is the back-compat path every existing caller takes.
foreach ($state in @('MERGEABLE', 'UNKNOWN', '', '   ')) {
    $missOther = Get-MissingCheckSuiteNote -SuitesJson $suitesNoActions -PrNumber '1233' -Mergeable $state
    Assert-True ($missOther -like '*gh pr close 1233 && gh pr reopen 1233*') "mergeable '$state' still gets the reopen -- only CONFLICTING is decisive"
    Assert-True ($missOther -notlike '*Resolve the conflict*') "mergeable '$state' is never told to resolve a conflict it may not have"
}
Assert-Equal $missNote (Get-MissingCheckSuiteNote -SuitesJson $suitesNoActions -PrNumber '1233') 'and the note is byte-identical to the pre-#1247 one when nothing is passed'

# gh's answer arrives as JSON text through Invoke-NativeCapture, so tolerate what that hands back.
Assert-True ((Get-MissingCheckSuiteNote -SuitesJson $suitesNoActions -PrNumber '9' -Mergeable ' conflicting ') -like '*Resolve the conflict*') 'the state is matched case-insensitively and trimmed, as gh output reaches it'

# An Actions suite that EXISTS is still not this note's case, conflict or no conflict: there the
# ordinary "the check has not reported yet" wording is the correct one and this must stay out of it.
Assert-Equal '' (Get-MissingCheckSuiteNote -SuitesJson $suitesWithActions -PrNumber '1243' -Mergeable 'CONFLICTING') 'a conflicting PR that DOES have an Actions suite is not this note''s case either'

# AND SHIP-PR'S PROBE ACTUALLY ASKS. Same reasoning and same failure mode as the #1044 and #1219
# call-site asserts above: a reverted call site leaves every assert here green while the refusal goes
# on sending the reader to YAML that is fine.
Assert-True ($shipText -like '*Get-MissingCheckSuiteNote -SuitesJson*') 'ship-pr.ps1 asks whether an Actions suite exists before it words the step-3 refusal (#1234)'
Assert-True ($shipText -like '*commits/$sha/check-suites*') 'and reads it for the commit the PR actually carries'
Assert-True ($shipText -like '*Check the workflow, or merge manually once it is green.*') 'while the old wording survives for the one case it is correct for'
# The #1247 half of the same guard: the conflict branch above is unreachable in production unless the
# call site actually reads the state and passes it, and nothing else in this suite would notice.
Assert-True ($shipText -like '*-Mergeable $mergeable*') 'ship-pr.ps1 passes the PR''s mergeable state, so the conflict branch is reachable at all (#1247)'
Assert-True ($shipText -like "*'--json', 'mergeable'*") 'and reads it from gh rather than inferring it from the checkout'
$idxSuiteNote = $shipText.IndexOf('Get-MissingCheckSuiteNote')
$idxWatchArg  = $shipText.IndexOf("'--watch'")
Assert-True ($idxSuiteNote -ge 0 -and $idxSuiteNote -lt $idxWatchArg) 'the read sits in the PRE-watch probe it diagnoses, not beside the post-watch notes'


# --- issue #1584: a CONFLICTING PR is refused BEFORE the 180s wait, not inside its timeout ---------
# Measured on PR #1582: ship-pr waited the full 180s and then handed #1234's close/reopen remedy for a
# PR whose mergeStateStatus was DIRTY -- a conflict, which reopening cannot fix and which #1247's
# branch of Get-MissingCheckSuiteNote already words correctly. The conflict is knowable the instant the
# PR exists, so the wait itself was avoidable. The #1234 / #1247 note-building block moved into a
# shared function (Get-MissingCheckSuiteRefusalNote) so the early exit and the timeout refusal word
# from the same builder; text asserts, like every other call-site pin in this suite.
Write-Host "ship-pr.ps1 -- a CONFLICTING PR is refused up front, not after 180s (#1584)" -ForegroundColor Cyan
$idxWaitFn   = $shipText.IndexOf('function Wait-CheckRegistration')
$idxWaitLoop = $shipText.IndexOf('while ($true) {', $idxWaitFn)
Assert-True ($idxWaitFn -ge 0 -and $idxWaitLoop -gt $idxWaitFn) 'the registration poll loop is found inside Wait-CheckRegistration'

Assert-True ($shipText -like '*function Get-MissingCheckSuiteRefusalNote*') 'the #1234 / #1247 note-building read is a function now, shared by the early exit and the timeout'
$countRefusalBuilder = ([regex]::Matches($shipText, 'Get-MissingCheckSuiteRefusalNote -Pr')).Count
Assert-Equal 2 $countRefusalBuilder 'and it is CALLED twice -- once before the wait on a known conflict, once inside the timeout as before'

$idxEarlyBlock = $shipText.IndexOf('EARLY EXIT ON A CONFLICTING PR -- issue #1584')
Assert-True ($idxEarlyBlock -ge 0 -and $idxEarlyBlock -lt $idxWaitLoop) 'ship-pr reads the mergeable state BEFORE the poll loop, so a conflict never costs a poll interval'
Assert-True ($shipText -like "*`$mergeNow.ToUpperInvariant() -eq 'CONFLICTING'*") 'only a definitive CONFLICTING short-circuits -- UNKNOWN (GitHub still computing) falls through to the wait'
$idxConflictExit = $shipText.IndexOf('NOT merged (CONFLICTING).')
Assert-True ($idxConflictExit -ge 0 -and $idxConflictExit -lt $idxWaitLoop) 'and the refusal is written before the loop, not from inside its 180s timeout'

# The folded-entry sub-case: the reporter's PR #1582 conflicted because its branch entry had already
# folded (deleting dkj-policy/<branch>.md on main), which "resolve the conflict / rebase" does not fix.
Assert-True ($shipText -like '*function Test-BranchEntryAlreadyFolded*') 'ship-pr can tell the folded-entry conflict from an ordinary one'
Assert-True (($shipText -like '*--diff-filter=D*') -and ($shipText -like '*refs/remotes/origin/main*')) 'and it decides that on a DELETE commit in the trunk history, not on "file absent from main" (true for every fresh branch)'
Assert-True ($shipText -match "fresh branch off 'main' \(#1584\)") 'so a spent branch is told to move the follow-up work, not to resolve an unresolvable conflict'
$idxFoldedTest = $shipText.IndexOf('Test-BranchEntryAlreadyFolded -Branch')
Assert-True ($idxFoldedTest -gt $idxEarlyBlock -and $idxFoldedTest -lt $idxWaitLoop) 'the folded-entry note augments the early conflict refusal -- it is not a second code path'


# --- Get-PrCreateFailureReason: gh's own answer, not a guess (inbound #1077) -----------------------
# open-pr replaced gh's message with "Creating the PR failed (is gh logged in?)" on a run where gh had
# just listed PRs, pushed and read the issue list -- so the loudest line on screen named the one thing
# that was demonstrably fine, and sent the reader to gh auth status, then to their token, then to their
# network, for a branch that was in fact completely finished.
Write-Host "Get-PrCreateFailureReason -- the reason gh actually gave" -ForegroundColor Cyan
$ghFail = @(
    'Creating pull request for docs/audience-note-v1 into main in DaveKJohn/thumbnail-generator',
    '',
    'pull request create failed: GraphQL: No commits between main and docs/audience-note-v1 (createPullRequest)'
)
Assert-Equal 'pull request create failed: GraphQL: No commits between main and docs/audience-note-v1 (createPullRequest)' `
    (Get-PrCreateFailureReason -OutputLines $ghFail) 'create failure: the reason is gh''s last line, not its progress line'
Assert-Equal 'boom' (Get-PrCreateFailureReason -OutputLines @('boom', '', '   ')) 'create failure: trailing blank lines are not the reason'
Assert-Equal 'trimmed' (Get-PrCreateFailureReason -OutputLines @('  trimmed  ')) 'create failure: the line comes back trimmed'
# EMPTY IS THE ONE CASE THE OLD MESSAGE WAS RIGHT FOR, so it has to be distinguishable: a gh that printed
# nothing leaves the caller with nothing better than a hint about the environment.
Assert-Equal '' (Get-PrCreateFailureReason -OutputLines @()) 'create failure: no output yields no reason'
Assert-Equal '' (Get-PrCreateFailureReason -OutputLines @('', '  ')) 'create failure: blank output yields no reason either'
Assert-Equal '' (Get-PrCreateFailureReason -OutputLines $null) 'create failure: and $null is not a crash'

# AND OPEN-PR ASKS FOR IT, plus the merged lookup that stops the run ever reaching that failure. Both are
# call-site asserts for the same reason the ship-pr ones below are: a reverted caller leaves every assert
# above green while the script behaves exactly as it did before.
$openPrPath = Join-Path $PSScriptRoot '..\release\open-pr.ps1'
Assert-True (Test-Path -LiteralPath $openPrPath) 'open-pr.ps1 exists where this suite looks for it'
$openText = [System.IO.File]::ReadAllText((Resolve-Path $openPrPath).Path, [System.Text.Encoding]::UTF8)
Assert-True ($openText -like '*Get-PrCreateFailureReason -OutputLines $create.Output*') 'open-pr reports gh''s own reason for a failed create'
Assert-True ($openText -like "*'--state', 'merged'*") 'open-pr asks whether the branch has an ALREADY-MERGED PR'
Assert-True ($openText -like '*is already merged -- nothing to open*') 'and says so as its own outcome rather than failing'
$idxOpenLookup = $openText.IndexOf("'--state', 'open'")
$idxMergedLookup = $openText.IndexOf("'--state', 'merged'")
Assert-True ($idxOpenLookup -ge 0 -and $idxMergedLookup -gt $idxOpenLookup) 'the merged lookup is the FALLBACK -- an open PR is still the first answer'
$idxCreate = $openText.IndexOf("'pr', 'create'")
Assert-True ($idxCreate -gt $idxMergedLookup) 'and it sits above the create, which is the path it exists to keep the run off'

$shipMergedText = [System.IO.File]::ReadAllText((Resolve-Path (Join-Path $PSScriptRoot '..\release\ship-pr.ps1')).Path, [System.Text.Encoding]::UTF8)
Assert-True ($shipMergedText -like '*is already merged -- nothing to ship*') 'ship-pr reads the same state for itself, since it is runnable on its own'

# --- Test-GhMutationTransient: a 5xx/transport failure is not proof the mutation failed (inbound #1916) --
# Measured in a consumer (BWJ-Development/smartwatchbanden, dkj-policy 5.1.0): a PR create that answered
# GraphQL's 500-shaped message, two more that answered a bare 'HTTP 502', and a merge that answered
# 'non-200 OK status code: 502 Bad Gateway' had each actually landed, while open-pr and ship-pr reported
# every one of them as a hard failure and stopped.
Write-Host "Test-GhMutationTransient -- a 5xx/transport failure is not a refusal" -ForegroundColor Cyan

# The three answers actually measured in #1916, verbatim.
Assert-True (Test-GhMutationTransient -OutputLines @(
    'Creating pull request for fix/x into main in BWJ-Development/smartwatchbanden',
    '',
    'pull request create failed: GraphQL: Something went wrong while executing your query. Please include `F98B:215E9B:123AE48E:11BFEC4B:6AA66673` when reporting this issue.'
)) '#1916: the GraphQL 500-shaped answer is transient'
Assert-True (Test-GhMutationTransient -OutputLines @('HTTP 502: 502 Bad Gateway (https://api.github.com/graphql)')) '#1916: a bare HTTP 502 is transient'
Assert-True (Test-GhMutationTransient -OutputLines @('failed to merge pull request: non-200 OK status code: 502 Bad Gateway')) '#1916: the merge''s 502 is transient too, in gh''s own different wording for it'

# Every 5xx-shaped wording the function claims to recognise, each on its own.
Assert-True (Test-GhMutationTransient -OutputLines @('HTTP 503: Service Unavailable')) '503 is transient'
Assert-True (Test-GhMutationTransient -OutputLines @('gh: Internal Server Error')) '500 spelled out in words is transient'
Assert-True (Test-GhMutationTransient -OutputLines @('Gateway Timeout')) 'a gateway timeout is transient'
Assert-True (Test-GhMutationTransient -OutputLines @('some prose, non-200 OK status code: 500 , more prose')) 'a mid-sentence status code reads too'

# A 4xx is a REAL refusal from GitHub, not a request that never landed, and must stay a hard failure.
Assert-Equal $false (Test-GhMutationTransient -OutputLines @('pull request create failed: GraphQL: No commits between main and docs/x (createPullRequest)')) 'a semantic refusal (4xx-shaped) is not transient'
Assert-Equal $false (Test-GhMutationTransient -OutputLines @('HTTP 404: Not Found (https://api.github.com/repos/x/y/pulls)')) 'a 404 is not transient'
Assert-Equal $false (Test-GhMutationTransient -OutputLines @('HTTP 401: Bad credentials')) 'an auth refusal is not transient'
Assert-Equal $false (Test-GhMutationTransient -OutputLines @('pull request create failed: GraphQL: A pull request already exists for x:branch.')) 'a duplicate refusal is not transient'

# A BARE THREE-DIGIT NUMBER STARTING WITH 5 IS NOT ENOUGH ON ITS OWN -- issue and PR numbers read the
# same way, and this function must not fire on 'closes #512' or similar prose.
Assert-Equal $false (Test-GhMutationTransient -OutputLines @('gh pr create failed: label ''prio-502'' not found')) 'a bare 5xx-shaped number with no server-error wording beside it is not transient'

# Boundary cases, same shape as Get-PrCreateFailureReason's own asserts just above.
Assert-Equal $false (Test-GhMutationTransient -OutputLines @()) 'no output is not transient'
Assert-Equal $false (Test-GhMutationTransient -OutputLines @('', '  ')) 'blank output is not transient'
Assert-Equal $false (Test-GhMutationTransient -OutputLines $null) '$null is not a crash and not transient'

# AND BOTH CALLERS ACTUALLY USE IT -- call-site asserts, same reason as the ones above: a reverted
# caller leaves every unit assert above green while the script behaves exactly as it did before #1916.
Assert-True ($openText -like '*Test-GhMutationTransient -OutputLines $create.Output*') 'open-pr classifies a failed create before reporting it as failed'
$idxCreateFail = $openText.IndexOf("if (`$create.ExitCode -ne 0) {")
$idxTransientCheck = $openText.IndexOf('Test-GhMutationTransient -OutputLines $create.Output')
Assert-True ($idxCreateFail -ge 0 -and $idxTransientCheck -gt $idxCreateFail) 'the classification runs INSIDE the failure branch, not before gh has actually failed'
Assert-True ($openText -like "*'--state', 'open', '--json', 'number,url', '--limit', '1'*") 'open-pr re-checks for the landed PR the same way it checks for an existing one'
Assert-True ($openText -like '*this may have landed anyway*') 'and says so rather than a flat "failed"'

Assert-True ($shipMergedText -like '*Test-GhMutationTransient -OutputLines $merge.Output*') 'ship-pr classifies a failed merge before reporting it as failed'
Assert-True ($shipMergedText -like '*$mergeTransientRecovery = $true*') 'and records the recovery so the read-back below can tell it apart from an ordinary exit 0'
$idxRecoveryFlag = $shipMergedText.IndexOf('$mergeTransientRecovery = $false')
$idxQueueRecoveryGuard = $shipMergedText.IndexOf('$mergeTransientRecovery -and $mergedState -ne ''MERGED''')
$idxNoQueueRecoveryGuard = $shipMergedText.IndexOf('if ($mergeTransientRecovery) {')
Assert-True ($idxRecoveryFlag -ge 0 -and $idxQueueRecoveryGuard -gt $idxRecoveryFlag -and $idxNoQueueRecoveryGuard -gt $idxRecoveryFlag) 'the recovery flag is read by BOTH the queue and the no-queue read-back, not just one'
Assert-True ($shipMergedText -like '*this run does not know whether the merge happened*') 'an unreadable state after a recovered failure is reported as unknown, not silently folded through'

# --- Get-FailedCheckRunRefs / Get-AuthoredFailureNote: the reason, relayed (#1103) ---------------
#
# Eight issues have been filed here against a red `claude-review` whose own diagnostic step had
# already printed the cause -- the last of them #1103, and #966 concluded from the same silence that
# a secret needed rotating. ship-pr merges past that check by the ruleset and says so; what these
# asserts pin is the SENTENCE printed beside it.

# The refs are the run read widened by one key, so the run answer above must not have moved.
$refs = @(Get-FailedCheckRunRefs -ChecksJson $linkChecks)
Assert-Equal 2 $refs.Count 'both failing checks are returned, and the green one is not'
Assert-NameSet @('lint-en-tests', 'claude-review') @($refs | ForEach-Object { $_.Name }) 'each ref names its check, which is what the note is titled with'
Assert-NameSet @('456', '789') @($refs | ForEach-Object { $_.JobId }) 'and its JOB, the key annotations are addressed by -- not the run'
Assert-NameSet @('123') @($refs | ForEach-Object { $_.RunId } | Sort-Object -Unique) 'while the run id is still read from the same link'
$runOnly = '[{"bucket":"fail","name":"a","state":"FAILURE","link":"https://github.com/o/r/actions/runs/55"}]'
Assert-NameSet @('55') (Get-FailedCheckRunIds -ChecksJson $runOnly) 'a link naming a run but no job still answers the run question'
Assert-Equal '' (@(Get-FailedCheckRunRefs -ChecksJson $runOnly)[0].JobId) 'and simply has no job to ask annotations of'
Assert-NameSet @() (Get-FailedCheckRunRefs -ChecksJson $extChecks) 'an external status is skipped here too -- it has no annotations either'
foreach ($bad in @('', '   ', 'not json', '[]')) {
    Assert-NameSet @() (Get-FailedCheckRunRefs -ChecksJson $bad) "an unreadable checks payload ('$bad') yields no refs"
}

# The real payload, trimmed: this is what run 33267175141's job answered on August 29, 2026 -- the
# authored diagnostic sitting among the runner's own untitled noise and a deprecation warning.
# KEPT VERBATIM, including a headline the workflow no longer writes. #1112 repaired that sentence --
# it vouched for the reset time this same payload got wrong by 2.5 days -- but what is under test
# here is the SELECTION rule, not the wording, and a real captured payload is worth more to it than
# a re-typed current one. The current headline lives in .github/workflows/claude-code-review.yml.
$annReal = '[' +
  '{"annotation_level":"warning","title":"","message":"Node.js 20 is deprecated."},' +
  '{"annotation_level":"failure","title":"claude-review -- out of quota -- the review did not run",' +
  '"message":"The review did not run: the account behind CLAUDE_CODE_OAUTH_TOKEN is out of quota. It resets on the clock and not on a re-run; the reason below names WHICH limit it is and when it comes back, which is hours for a session window and days for a weekly one. Nothing to do with this diff. You have hit your weekly limit - resets Aug 31, 7am (UTC)"},' +
  '{"annotation_level":"failure","title":"","message":"Process completed with exit code 1."},' +
  '{"annotation_level":"failure","title":"","message":"Action failed with error: Claude execution failed: result is_error:true"}]'
$noteQuota = Get-AuthoredFailureNote -AnnotationsJson $annReal -CheckName 'claude-review'
Assert-True ($noteQuota -like 'claude-review*') 'the note names the check it belongs to'
Assert-True ($noteQuota -notlike '*claude-review: claude-review*') 'ONCE -- this repo titles its own annotation with the job name, and prefixing it again stutters'
Assert-True ((Get-AuthoredFailureNote -AnnotationsJson $annReal -CheckName 'other') -like 'other: *') 'a title that does NOT carry the name is prefixed, which is what the parameter is for'
Assert-True ($noteQuota -like '*out of quota*') 'and carries the title the workflow authored'
Assert-True ($noteQuota -like '*resets Aug 31*') 'and the message, which is where upstream states a reset time -- relayed, not vouched for (#1112)'
Assert-True ($noteQuota -notlike '*exit code 1*') 'the runner exit noise is not what gets relayed'
Assert-True ($noteQuota -notlike '*Node.js 20*') 'and neither is a WARNING -- the run went red, and a deprecation is not why'

# THE ASSERT THAT KEEPS THIS FROM CRYING WOLF, the same one Get-StalledRunNote carries: a job that
# left no authored sentence must produce no line at all, so the operator's transcript does not gain a
# reassuring-looking note that says nothing.
$annBare = '[{"annotation_level":"failure","title":"","message":"Process completed with exit code 1."}]'
Assert-Equal '' (Get-AuthoredFailureNote -AnnotationsJson $annBare -CheckName 'x') 'untitled failures only: no note, and the old wording stands alone'
$annWarnOnly = '[{"annotation_level":"warning","title":"Something","message":"m"}]'
Assert-Equal '' (Get-AuthoredFailureNote -AnnotationsJson $annWarnOnly -CheckName 'x') 'a titled WARNING is not a red run explaining itself'

# Order, bounds, and the optional name.
$annTwo = '[{"annotation_level":"failure","title":"first","message":"a"},{"annotation_level":"failure","title":"second","message":"b"}]'
Assert-True ((Get-AuthoredFailureNote -AnnotationsJson $annTwo) -like 'first*') 'the FIRST titled failure wins -- a workflow diagnoses itself before the runner exits'
Assert-True ((Get-AuthoredFailureNote -AnnotationsJson $annTwo) -notlike '*claude*') 'without a check name the note is the authored sentence alone'
$annLong = '[{"annotation_level":"failure","title":"t","message":"' + ('x' * 700) + '"}]'
Assert-True ((Get-AuthoredFailureNote -AnnotationsJson $annLong).Length -lt 540) 'the message is capped -- free text from a workflow, going into a console'
Assert-True ((Get-AuthoredFailureNote -AnnotationsJson $annReal).Length -gt 400) 'but not at the 300 the annotation itself uses: that cut off "resets Aug 31", the one actionable word'
$annMulti = '[{"annotation_level":"failure","title":"t","message":"line one\nline two"}]'
Assert-True ((Get-AuthoredFailureNote -AnnotationsJson $annMulti) -notlike '*line two*') 'and cut to its first line, since this is pasted into a console'

# --- The relayed text is STRIPPED, not only bounded (#1612) ---------------------------------------
#
# The cut above removes the NEWLINE tricks and nothing else: an in-line ESC[, an OSC string or an RTL
# override survives Trim() and the 500 untouched, and this note is printed under ship-pr's own warning
# prefix -- read by a terminal that an escape repaints and by an agent session that an override lies to.
# The sibling relay (Get-RemoteAheadNote, remote-ahead-lib.ps1) has guarded the same class since it was
# extracted, on the same reasoning; these asserts are what stop the two from disagreeing.
#
# The JSON carries \u escapes, so this file stays pure ASCII (repo convention for .ps1) while the parse
# hands the function the real characters.
$annEsc = '[{"annotation_level":"failure","title":"claude-review -- \u001b[2Jwiped",' +
          '"message":"a\u001b]0;pwned\u0007 b\u202egnitfarc"}]'
$noteEsc = Get-AuthoredFailureNote -AnnotationsJson $annEsc -CheckName 'claude-review'
Assert-Equal $false ($noteEsc.Contains([char]27))    'no ESC survives into the console: an ANSI/OSC introducer repaints the terminal it lands in'
Assert-Equal $false ($noteEsc.Contains([char]7))     'and neither does the BEL that terminates an OSC string'
Assert-Equal $false ($noteEsc.Contains([char]0x202E)) 'nor an RTL override, which makes the line read as something other than what it says'
Assert-True  ($noteEsc -like '*wiped*')              'the WORDS stay -- the note only has to be readable, and quoting would keep the payload and add noise'
Assert-True  ($noteEsc -like '*gnitfarc*')           'including the ones the override was wrapped around, in the order they were actually written'
Assert-Equal 0 ([regex]::Matches($noteEsc, '  ').Count) 'runs of spaces collapse, so a stripped escape leaves no gap for the next reader to wonder about'

# A "title" made only of format characters is not a workflow diagnosing itself. It has to fall through
# like any untitled annotation -- which is why the strip runs BEFORE the emptiness test, not after it.
$annBlankTitle = '[{"annotation_level":"failure","title":"\u200b\u202e","message":"m"},' +
                 '{"annotation_level":"failure","title":"real","message":"r"}]'
Assert-True ((Get-AuthoredFailureNote -AnnotationsJson $annBlankTitle) -like 'real*') 'a title of nothing but format characters is untitled, and the next annotation wins'
Assert-Equal '' (Get-AuthoredFailureNote -AnnotationsJson '[{"annotation_level":"failure","title":"\u202e","message":"m"}]') 'and on its own it produces no note at all, not an empty-titled one'

# THE DRIFT PIN, ACROSS EVERY LIB THAT TYPES THE CLASS. It was three until #1623, two until #1858, and
# it is three again: here, ref-print-lib.ps1, which since #1623 owns the one definition of the prose
# strip (Get-DisplayRef) as well as the note printed when a ref is refused (#1594), and
# claim-issue-lib.ps1, whose Format-ForConsole was ASCII-only until #1858 and now types the same class.
# remote-ahead-lib.ps1 typed the FIRST copy (a commit's %an and %s, #1439) and no longer does -- #1623
# gave it a caller's reason to load ref-print-lib for its own sake, and once the lib was loaded a
# private copy was pure drift surface.
#
# THE ARGUMENT FOR THE THREE IS UNCHANGED and is not laziness: they share nothing else -- different
# bounds (500, none and none), different source processes, and no lib among them is loaded by another's
# callers -- so lifting this one would cost a dot-source in every caller and a Copy-Item in every
# fixture suite to save one regex. #1858's copy has a SECOND reason on top of that one, and it is the
# stronger of the two: neither existing function fits its contract. Get-DisplayRef collapses runs of
# spaces and trims, and an issue title is quoted evidence that must not be re-spaced; Get-DisplayPath
# answers the all-stripped case with '(no printable path)', which is the wrong noun for a title. So
# reuse there would have meant a fourth function in ref-print-lib, not one fewer regex.
#
# What the copies may not do is DISAGREE, so the character class itself is compared rather than
# described -- and WHICH libs carry it is asserted too, because #1612's second half was a stale claim
# about exactly this.
$prIssuesLibText  = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot '..\lib\pr-issues-lib.ps1'))
$remoteAheadText  = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot '..\lib\remote-ahead-lib.ps1'))
$refPrintText     = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot '..\lib\ref-print-lib.ps1'))
$claimIssueText   = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot '..\lib\claim-issue-lib.ps1'))
Assert-True ($prIssuesLibText -match ([regex]::Escape('[\p{Cc}\p{Cf}]'))) 'this lib carries the strip pattern'
Assert-True ($refPrintText -match ([regex]::Escape('[\p{Cc}\p{Cf}]'))) 'and so does ref-print-lib, which re-typed it deliberately (#1594) and now owns the prose strip too (#1623)'
Assert-True ($claimIssueText -match ([regex]::Escape('[\p{Cc}\p{Cf}]'))) 'and so does claim-issue-lib, whose Format-ForConsole reached only the ASCII control range until #1858'
Assert-True (-not ($claimIssueText -match ([regex]::Escape("'[\x00-\x1F\x7F]', ' '")))) 'and the ASCII-only class it replaced no longer STRIPS anything -- naming it in the docstring is the record, a second live strip beside the first is the drift this pin exists to refuse'
Assert-True (-not ($remoteAheadText -match ([regex]::Escape('[\p{Cc}\p{Cf}]')))) 'while the sibling relay it was copied FROM no longer does -- it reads Get-DisplayRef instead (#1623)'
Assert-True ($remoteAheadText -match 'ref-print-lib\.ps1') 'because it dot-sources the lib that owns the definition'
$classSites = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '..\lib') -Filter '*.ps1' |
                Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match ([regex]::Escape('[\p{Cc}\p{Cf}]')) } |
                ForEach-Object { $_.Name } | Sort-Object)
Assert-NameSet @('claim-issue-lib.ps1', 'pr-issues-lib.ps1', 'ref-print-lib.ps1') $classSites 'THREE libs type this class and no more -- a fourth has to update Format-AuthoredText, Format-ForConsole and the new-branch skill page, which is the claim #1612 was filed about'
Assert-Equal 1 ([regex]::Matches($prIssuesLibText, [regex]::Escape("-replace '[\p{Cc}\p{Cf}]', ' '")).Count) 'ONE definition inside this lib -- Format-AuthoredText, which both the title and the message go through'

# --- The two caps that bound the SAME string, pinned so neither moves alone (#1116) ---------------
#
# `claude-code-review.yml` writes `headline + ' ' + reason` into one annotation and this function
# relays that annotation to the operator. Both bound it and neither can see the other: a
# 296-character headline plus a 300-character reason is 597 against a relay that cuts at 500, and
# the part the relay drops is the TAIL of the reason -- where "resets Aug 31, 7am (UTC)" lives.
#
# #1116 MEASURED THAT OVERLAP AND LEFT IT STANDING, which is why this pins the numbers instead of
# asserting the sum fits. 500 - 296 - 1 = 203, so the console shows 203 characters of reason
# whichever end owns the cut; lowering the workflow's 300 to 203 would hand that reader the same
# text, drop the "..." that marks the loss, and cost the GitHub annotation up to 97 characters no
# 500 bounds. Sampled traffic makes it hypothetical anyway -- 45 titled failure annotations over
# August 27-29, 2026 with reasons of 51 to 55 characters, and the longest since (#1164's spend-limit
# string, August 31) at 121 -- all against 203 of room.
#
# So what must not happen silently is a MOVE. A longer headline, a raised reason cap or a lowered
# relay cap each change that arithmetic, and each is reasonable on its own terms while being wrong
# against the other file. These asserts fail on any of the three and name the reasoning to read.
$wfPath = (Join-Path $PSScriptRoot '..\..\.github\workflows\claude-code-review.yml')
Assert-True (Test-Path -LiteralPath $wfPath) 'the reviewed workflow is where these asserts expect it -- a rename must fail here, not silently pass'
$wfText = Get-Content -LiteralPath $wfPath -Raw

# Read with .Contains, not -like: the needle carries '[', which -like takes as a character class.
$libText = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\lib\pr-issues-lib.ps1') -Raw
$libCaps = @([regex]::Matches($libText, '\$message\.Length -gt (\d+)\)|\$message\.Substring\(0, (\d+)\)') |
    ForEach-Object { if ($_.Groups[1].Success) { [int]$_.Groups[1].Value } else { [int]$_.Groups[2].Value } })
Assert-Equal 2 $libCaps.Count 'the relay states its bound twice -- the test and the cut -- and both are read'
Assert-Equal $libCaps[0] $libCaps[1] 'and they agree with each other: a message cut at one number must be the one tested against it'
$relayCap = $libCaps[0]
Assert-Equal 500 $relayCap 'the relay still cuts at the 500 #1116 did its arithmetic against'

# THE NEEDLE BINDS TO THE FIELD, not to the shape -- because the edge this comment used to merely
# predict has since happened. It read: "the needle occurs exactly once in the file today; a SECOND jq
# slice added elsewhere would go unread here rather than caught." #1118 added that second slice, to
# `status` one line above, and the outcome was worse than unread: the new slice sits EARLIER in the
# file, so `Match` returned 32 and this assert went red against a `reason` cap nobody had touched.
# Anchoring on `.result` is what makes the two independent, and the status cap gets its own assert
# below rather than sharing this one.
$wfReason = [regex]::Match($wfText, '\(\.result // ""\)[^\r\n]*\| \.\[0:(\d+)\]')
Assert-True $wfReason.Success 'the workflow still caps the reason it appends, and this is where'
Assert-Equal 300 ([int]$wfReason.Groups[1].Value) 'at the same 300 -- raising it widens an overlap that was measured, not overlooked'

# And the status cap, which is a bound on a DIFFERENT thing: not an overlap with the relay, but the
# length of a value this repo does not own and cannot predict (#1118).
$wfStatus = [regex]::Match($wfText, '\(\.api_error_status // ""\)[^\r\n]*\| \.\[0:(\d+)\]')
Assert-True $wfStatus.Success 'and the status it interpolates is capped too, on the line that reads it'
Assert-True ([int]$wfStatus.Groups[1].Value -lt 300) 'well under the reason cap -- a status is three digits, and the rest is a field this repo does not own'

# THE HEADLINE IS THE THIRD NUMBER, and the one most likely to move: it is prose, and #974, #1055,
# #1112 and #1164 each rewrote it. Its length is what turns the other two into 203, so it is read
# from the file rather than trusted. 296 today; the assert is the arithmetic, not the constant, so a
# rewrite that keeps the sum honest passes and one that eats the reason's room does not.
$headlines = @([regex]::Matches($wfText, "(?m)^\s*headline='([^']*)'") | ForEach-Object { $_.Groups[1].Value })
Assert-True ($headlines.Count -ge 3) 'the literal headlines are readable -- the interpolated *) branch has no static length and needs none'
$longestMeasuredReason = 121  # #1164's spend-limit string, August 31 2026 -- the session/weekly ones ran 51-55
foreach ($h in $headlines) {
    $room = $relayCap - $h.Length - 1
    Assert-True ($room -ge $longestMeasuredReason) "the $($h.Length)-character headline leaves the console $room characters of reason -- more than the $longestMeasuredReason ever measured"
}

# --- THE PRE-SDK FAILURE CLASS: a titled annotation where there was none (#1245) -----------------
#
# The asserts above all describe a failure the SDK lived long enough to REPORT. When the action dies
# before the SDK is reached, `execution_file` is empty, the *Why the review failed* step is skipped,
# and the workflow used to write no titled annotation at all -- so `Get-AuthoredFailureNote` selected
# nothing and ship-pr printed nothing beside the red mark. That is the #966 silence in a class the 429
# work never reached, and it is not hypothetical: run 33663986438 (September 2, 2026) failed the
# app-token exchange with a 401, and its only failure annotations were the runner's two UNTITLED ones.
#
# WHAT THESE PIN IS THE COVERAGE, not the wording. `failure()` has exactly two cases here and each
# needs a step, so the guard is that BOTH gates exist and that the second one authors a title. A
# rewrite of either sentence passes; deleting the second step, or renaming the output either gate
# reads, does not.
$wfGates = @([regex]::Matches($wfText, "steps\.claude-review\.outputs\.execution_file (!=|==) ''") |
    ForEach-Object { $_.Groups[1].Value })
Assert-NameSet @('!=', '==') $wfGates 'both halves of failure() are diagnosed -- a result message to read, and none'
Assert-Equal 2 $wfGates.Count 'and exactly once each: two gates on the same output, so neither class falls between them'

# The literals are read out of the workflow rather than re-typed, so this cannot drift from the file
# it describes -- the same reason the headline loop above reads its own.
$wfPreSdk = [regex]::Match($wfText, "(?s)- name: Why the review never started.*?\z")
Assert-True $wfPreSdk.Success 'the pre-SDK step is still named as these asserts address it'
$preShort = [regex]::Match($wfPreSdk.Value, "(?m)^\s*short='([^']*)'").Groups[1].Value
$preHead  = [regex]::Match($wfPreSdk.Value, "(?m)^\s*headline='([^']*)'").Groups[1].Value
Assert-True ($preShort -and $preHead) 'and still builds its annotation from a short title and a headline'
Assert-True ($wfPreSdk.Value.Contains('::error title=claude-review -- ${short}::')) 'which it writes as a TITLED failure annotation -- the one field the relay reads'
foreach ($punct in @(',', '::')) {
    Assert-True (-not $preShort.Contains($punct)) "the title carries no '$punct' -- both are annotation-command syntax, as the step above notes"
}

# END TO END, through the function ship-pr actually calls: the annotation this step writes must come
# back out as a sentence, where the runner's untitled 401 came back as ''.
$annPreSdk = '[' +
  '{"annotation_level":"warning","title":"","message":"Node.js 20 is deprecated."},' +
  '{"annotation_level":"failure","title":"claude-review -- ' + $preShort + '","message":"' + $preHead + '"},' +
  '{"annotation_level":"failure","title":"","message":"Process completed with exit code 1."},' +
  '{"annotation_level":"failure","title":"","message":"Action failed with error: Claude Code is not installed on this repository. Please install the Claude Code GitHub App at https://github.com/apps/claude"}]'
$notePreSdk = Get-AuthoredFailureNote -AnnotationsJson $annPreSdk -CheckName 'claude-review'
Assert-True ($notePreSdk -like 'claude-review*') 'the pre-SDK note names its check'
Assert-True ($notePreSdk -notlike '*claude-review: claude-review*') 'once, like the quota note -- the title already carries the job name'
Assert-True ($notePreSdk.Contains($preShort)) 'and carries the title the workflow authored'
Assert-True ($notePreSdk -notlike '*exit code 1*') 'not the runner exit noise'
Assert-True ($notePreSdk -notlike '*not installed on this repository*') 'and not the runner UNTITLED error either -- relaying that is the lib change #1112 ruled out, so the workflow states its own case'

# THE CAP, AND WHY THIS ONE IS AN ABSOLUTE RATHER THAN #1116's ARITHMETIC. The quota headlines leave
# room for a reason the relay may cut; this one has NO reason appended -- there is no result message
# to take one from -- so its whole note is literals from this repo and must arrive intact. If it ever
# does not, the fix is a shorter sentence here, not a wider cap there.
Assert-True ($notePreSdk.Length -lt $relayCap) "the pre-SDK note is $($notePreSdk.Length) characters against the relay's $relayCap -- it carries no reason, so it must arrive whole"
Assert-True ($notePreSdk -notlike '*...') 'and therefore unmarked by the truncation ellipsis'

# The claims it makes are bounded to what an EMPTY output proves, which is the standing rule of that
# workflow after #974, #1055, #1112 and #1164. A quota status cannot be among them: a 429 or 529
# arrives WITH a result message, so it is the other step's business and naming it here would be the
# over-claim those four issues each repaired.
foreach ($overclaim in @('429', '529', 'quota', 'resets')) {
    Assert-True (-not $preHead.Contains($overclaim)) "the pre-SDK headline does not mention '$overclaim' -- that class arrives with a result message and is diagnosed by the other step"
}

# Unreadable in, empty out -- a diagnostic must never be the reason the warning beside it cannot print.
foreach ($bad in @('', '   ', 'not json', 'null', '[]', '[{}]', '[{"annotation_level":"failure"}]')) {
    Assert-Equal '' (Get-AuthoredFailureNote -AnnotationsJson $bad -CheckName 'x') "an unreadable annotations payload ('$bad') costs the note and nothing else"
}

# AND SHIP-PR ASKS FOR IT, on the path where the merge PROCEEDS. Same reasoning as the #1044 call-site
# assert above: without this, a reverted call site leaves every assert here green while the operator
# reads the red mark with no reason beside it, which is the whole defect.
Assert-True ($shipText -like '*Get-AuthoredFailureNote -AnnotationsJson*') 'ship-pr relays what the failing workflow said about itself (#1103)'
Assert-True ($shipText -like '*check-runs/*/annotations*') 'reading it from the check run, which is where an authored annotation lives'
# THE RELAY MOVED INTO A SHARED FUNCTION AT #1602 (step 8 needed the same loop), so these two asserts
# now pin the CALL rather than the loop body -- the claims themselves are unchanged. The filter is the
# argument step 3 passes; the ordering is where that call sits, not where the function is defined,
# which is near the top of the file with the other script-local helpers.
Assert-True ($shipText -like '*$filter.Count -gt 0 -and $filter -notcontains $ref.Name*') 'the relay filters on the names it is given -- an empty list means no filter, which is step 8''s case'
Assert-True ($shipText -like '*Write-FailedCheckReasons -ChecksJson $checkFactsJson -Repo $repo -OnlyNames $verdict.FailedOther*') 'and step 3 gives it only the NOT-REQUIRED failures -- a required one is a refusal, not a merge that walks past'
$idxProceed = $shipText.IndexOf('a check FAILED but the merge is not blocked')
$idxSpoken  = $shipText.IndexOf('Write-FailedCheckReasons -ChecksJson $checkFactsJson')
Assert-True ($idxProceed -ge 0 -and $idxSpoken -gt $idxProceed) 'the reason is printed under that warning, where the reader has just landed'
Write-Host ""
# --- The PRODUCER of the annotation everything above relays (issue #1118) -------------------------
# Asserted on the workflow text for exactly the reason cut-release-guardrail gives for asserting on
# ci.yml: a workflow is the one caller no suite gets to run. Everything above this line tests the
# CONSUMER -- Get-AuthoredFailureNote reading what the check left behind -- so a regression in what
# claude-code-review.yml is allowed to PUT there would leave every assert in this file green.
#
# Three properties, one per way `status` could reach a workflow command unescaped. It is upstream's
# field, this repo cannot measure its domain, and #1112 is the standing reminder not to claim
# otherwise -- so these pin the SHAPE that needs no claim rather than a belief about the value.
$reviewYmlPath = Join-Path $PSScriptRoot '..\..\.github\workflows\claude-code-review.yml'
Assert-True (Test-Path -LiteralPath $reviewYmlPath) 'claude-code-review.yml exists where this suite looks for it'
$reviewYml = [System.IO.File]::ReadAllText((Resolve-Path $reviewYmlPath).Path, [System.Text.Encoding]::UTF8)

Write-Host ""
Write-Host "claude-code-review.yml -- what may reach the annotation (#1118)" -ForegroundColor Cyan

# 1. The newline axis. A command substitution strips TRAILING newlines and keeps internal ones, and a
#    workflow command counts at the START of a line -- so an unsplit status is a forgery surface.
Assert-True ($reviewYml -like '*(.api_error_status // "") | tostring | split(*') 'the status is single-lined where it is read, the same treatment the reason beside it gets'

# 2. The title axis. The comment above the case block states that the annotation TITLE may hold
#    neither a comma nor a '::' -- and until #1118 the one branch that could not know what it was
#    putting there was the only one putting a variable there.
$shortLines = @($reviewYml -split "`r?`n" | Where-Object { $_ -match '\bshort=' })
Assert-True ($shortLines.Count -ge 4) 'every case branch still sets a short form'
Assert-True (-not ($shortLines | Where-Object { $_ -like '*$status*' })) 'and none interpolates the status into it -- the short form IS the title, where a comma or a :: is command syntax'

# 3. The percent axis. The runner percent-DECODES a command's data, so an unescaped %0A renders as a
#    newline. `reason` was escaped from the start; `headline` needs it too now that it carries status.
#
#    AND THE COUNT IS PART OF THE PROPERTY, not bookkeeping around it -- which #1245 is why. That
#    issue added a THIRD emission site, for the pre-SDK class whose headline is pure literal and so
#    needs no escaping on today's text. Exempting it is the #1118 shape exactly: the branch nobody
#    escaped was the branch nobody had interpolated into YET, and it was the one that broke. So the
#    invariant is every site, and a new site raises this number deliberately rather than passing
#    under a `-ge`.
$errLines = @($reviewYml -split "`r?`n" | Where-Object { $_ -like '*::error title=claude-review*' })
Assert-True ($errLines.Count -eq 3) 'the annotation is emitted from exactly three places -- with a reason, without one, and the pre-SDK step that has none to take (#1245)'
Assert-True (-not ($errLines | Where-Object { $_ -notlike '*${headline//%/%25}*' })) 'and EVERY ONE escapes the headline -- the variable the case block interpolates the status into, and the one a literal-only site is tempted to leave bare (#1245)'
Assert-True (($errLines | Where-Object { $_ -like '*${reason//%/%25}*' }).Count -eq 1) 'while the reason keeps its own escape on the one line that carries it'


Write-Host ""
Write-Host "The label gate: does the label this PR would be given exist? (inbound #1221)" -ForegroundColor Cyan

# THE PAYLOAD IS THE REAL SHAPE of `gh label list --json name`, which is a flat array of {name}.
$labelJson = '[{"name":"documentation"},{"name":"question"},{"name":"inbound"}]'
$labelNames = @(Get-LabelNames -Json $labelJson)
Assert-Equal 3 $labelNames.Count 'every label name is read out of a gh label list payload'
Assert-Equal 'documentation' $labelNames[0] 'and in the order gh gave them'

# UNREADABLE IN, EMPTY OUT -- and the CALLER must read empty as "could not be asked", never as "the
# label is missing". A single-record payload is in this list on purpose: 5.1 hands a one-element parsed
# array to the pipeline as the record itself, which is the trap the assign-first/wrap-second shape
# navigates.
foreach ($bad in @('', '   ', 'not json', 'null', '[]', '[{}]', '[{"colour":"red"}]')) {
    Assert-Equal 0 (@(Get-LabelNames -Json $bad)).Count "an unreadable label payload ('$bad') yields no names rather than a wrong answer"
}
Assert-Equal 1 (@(Get-LabelNames -Json '[{"name":"bug"}]')).Count 'a ONE-record payload is read as one name, not flattened away'
Assert-Equal 1 (@(Get-LabelNames -Json '[{"name":"bug"},{"name":"bug"}]')).Count 'a duplicated name is counted once'

# THE MEASURED CASE. 'bug' and 'enhancement' were deleted org-wide in BWJ-ecommerce/smartwatchbanden on
# September 1, 2026 because the issue TYPE now carries that classification, and the next PR died on
# "could not add label: 'bug' not found" -- after every gate had run and the branch had been pushed.
$missing = Get-MissingLabelNote -Labels $labelNames -Label 'bug' -Prefix 'fix' `
                                -SeamPath 'scripts\lib\branch-info.ps1' -Repo 'BWJ-ecommerce/smartwatchbanden'
Assert-True ($missing -ne '') "the measured case is caught: 'bug' is not among the repo's labels"
Assert-True ($missing -like "*'bug' is not a label in BWJ-ecommerce/smartwatchbanden*") 'the note names the label and the repository'
Assert-True ($missing -like "*'fix/'*") 'and the branch prefix that produced it'
Assert-True ($missing -like '*branch-info.ps1*') 'and the repo-owned seam file that maps them, so the reader is sent to the edit'
Assert-True ($missing -like '*before the push*') 'and says the refusal came before the push, which is the whole point of the gate'
Assert-True ($missing -like '*gh label create*') 'the first remedy is paste-ready'
Assert-True ($missing -like "*'documentation', 'question' and 'inbound'*") 'the labels that DO exist are named -- what turns the refusal into a repair when the answer is a rename'

# A LABEL THAT EXISTS COSTS NOTHING AND SAYS NOTHING.
Assert-Equal '' (Get-MissingLabelNote -Labels $labelNames -Label 'documentation' -Prefix 'docs' -Repo 'x/y') 'a label that exists produces no note'
# CASE-INSENSITIVE, because GitHub is: it refuses to create 'Bug' beside 'bug', and `--label bug`
# attaches the existing 'Bug'. Refusing a PR gh would have opened is the one direction this gate must
# never fail in.
Assert-Equal '' (Get-MissingLabelNote -Labels @('Bug') -Label 'bug' -Prefix 'fix' -Repo 'x/y') 'a label that differs only in case is the same label to GitHub, so it is not refused'

# NOTHING TO JUDGE AGAINST IS NOT A REFUSAL -- an old gh with no --json, a network hiccup, a repo with
# no labels at all. A diagnostic must never be the reason a PR cannot be opened.
Assert-Equal '' (Get-MissingLabelNote -Labels @() -Label 'bug' -Prefix 'fix' -Repo 'x/y') 'an empty label list is "unknowable" and not "absent"'
Assert-Equal '' (Get-MissingLabelNote -Labels $null -Label 'bug' -Prefix 'fix' -Repo 'x/y') 'and so is no list at all'
Assert-Equal '' (Get-MissingLabelNote -Labels $labelNames -Label '' -Prefix 'fix' -Repo 'x/y') 'and so is an empty label -- a repo that attaches none has nothing for this gate to judge (inbound #1395)'

# THE FALLBACK HAS THE SAME HOLE ONE LAYER DOWN, which the report named: open-pr substitutes 'question'
# for an unknown prefix, and that is a GitHub DEFAULT label a repo may equally have deleted. The check
# is on the label that would be SENT, whatever produced it.
$fallbackNote = Get-MissingLabelNote -Labels @('documentation') -Label 'question' -Prefix '' -Repo 'x/y'
Assert-True ($fallbackNote -ne '') "the unknown-prefix fallback is checked too, not trusted"
Assert-True ($fallbackNote -like '*unknown-prefix fallback*') 'and the note says that is where the label came from, since there is no prefix to name'
Assert-True ($fallbackNote -notlike "*''/*") 'and it never prints an empty prefix as if it were one'

# ABOVE TEN LABELS THE COUNT REPLACES THE LIST. A label set is unbounded in a way a commit's check
# suites are not, and this note is read once in a terminal.
$many = @(1..12 | ForEach-Object { "label-$_" })
$manyNote = Get-MissingLabelNote -Labels $many -Label 'bug' -Prefix 'fix' -Repo 'x/y'
Assert-True ($manyNote -like '*12 labels do exist*') 'a large label set is counted rather than listed'
Assert-True ($manyNote -like '*gh label list --repo x/y*') 'and the command that lists them is given instead'
Assert-True ($manyNote -notlike '*label-7*') 'so the refusal cannot become a wall of names'

# AND open-pr.ps1 ACTUALLY RUNS IT, BEFORE THE PUSH. Without this assert every check above stays green
# while the label is resolved one line before `gh pr create` again -- which IS the defect, not a
# regression in the helper. Same reasoning as the #919 ordering assert above and the #1044 call-site one
# below: the script is the one caller no suite gets to run.
$idxLabelGate = $openPrText.IndexOf('Get-MissingLabelNote -Labels')
$idxPush      = $openPrText.IndexOf("Invoke-NativeCapture -FilePath 'git' -Arguments @('push'")
# LastIndexOf BEFORE the push, not IndexOf: -GatesOnly calls Invoke-WorkflowGates near the top of the
# script and exits, so the first occurrence is not the one on the push path.
$idxGates     = if ($idxPush -ge 0) { $openPrText.LastIndexOf('Invoke-WorkflowGates -RepoRoot', $idxPush) } else { -1 }
$idxCreate    = $openPrText.IndexOf("@('pr', 'create'")
Assert-True ($idxLabelGate -ge 0) 'open-pr.ps1 asks whether the label exists (inbound #1221)'
Assert-True ($idxPush -gt $idxLabelGate) 'and it asks BEFORE the push, which is the whole repair -- a failed create after the push leaves a pushed branch with no PR'
Assert-True ($idxGates -gt $idxLabelGate) 'and before the lint and test gates, so the author hears it in seconds rather than after the suites'
Assert-True ($idxCreate -gt $idxLabelGate) 'and the create still gets the label that was checked'
Assert-True ($openPrText -like "*@('label', 'list', '--json', 'name', '--limit', '500'*") 'the query names --limit, because gh label list defaults to 30 and a truncated list would refuse a label that exists'
$idxResolve = $openPrText.IndexOf('$label = $info.Label')
Assert-True ($idxResolve -ge 0 -and $idxResolve -lt $idxPush) 'the label is RESOLVED before the push too -- a check on a label resolved later would be checking nothing'
Assert-True (([regex]::Matches($openPrText, '\$label = \$info\.Label')).Count -eq 1) 'and resolved in exactly one place, so the checked label and the sent label cannot differ'
Assert-True ($openPrText -like '*if (-not $existingPr) {*') 'the gate is on the create path only -- an existing PR keeps its own labels and is never sent one'

Write-Host ""
Write-Host "open-pr.ps1 sends NO --label when the seam answers none (inbound #1395)" -ForegroundColor Cyan
# THE MEASURED CASE. BWJ-ecommerce/smartwatchbanden abolished PR labels outright on September 4, 2026 --
# the issue TYPE carries the classification now -- so its prefix table answers Label = $null for every
# prefix it knows. Get-MissingLabelNote reads that as "nothing to check" (asserted above) and the create
# appended `--label ''` anyway, which gh reads as a label that does not exist: it refuses the WHOLE
# create, after the push, with every gate including the label gate green.
#
# TEXT ASSERTS, for the same reason the block above gives: the script is the one caller no suite gets to
# run, and the helper being right is exactly what was already true when this failed.
$idxCreateLine = $openPrText.IndexOf("@('pr', 'create'")
$createLine    = if ($idxCreateLine -ge 0) { ($openPrText.Substring($idxCreateLine) -split "`n")[0] } else { '' }
Assert-True ($createLine -notlike '*--label'', $label*') 'the create no longer interpolates the label into its fixed argument list -- an empty answer became `--label ''''`, a label gh cannot find'
Assert-True ($createLine -like '*+ $labelArgs*') 'it appends a composed $labelArgs instead, the way it already appends the optional assignee and milestone'
Assert-True (([regex]::Matches($openPrText, '\$labelArgs = if \(\$label\)')).Count -eq 1) 'and $labelArgs is composed in exactly one place, so the checked label and the sent label still cannot differ'
Assert-True ($openPrText -like '*$labelArgs = if ($label) { @(''--label'', $label) } else { @() }*') 'the flag travels only when there is a label to put behind it'

# THE NORMALISATION IS PART OF THE REPAIR, not tidiness: the seam is free to answer $null, and $null in a
# native argument list is an EMPTY ARGUMENT rather than an absent one. Trimmed too -- ' ' is not a label.
$idxTrim = $openPrText.IndexOf('$label = "$label".Trim()')
Assert-True ($idxTrim -ge 0) 'the resolved label is normalised to a trimmed string, so a $null or blank seam answer cannot reach gh as an argument'
Assert-True ($idxTrim -gt $idxResolve -and $idxTrim -lt $idxLabelGate) 'and it happens between the resolve and the gate, so both read the same value'

# THE QUERY IS SKIPPED, not merely the compare: a `gh label list` whose answer cannot change the outcome
# is the cheapest call in this script to leave out, and both of its failure warnings would otherwise name
# a label there is none of.
$idxEmptyBranch = $openPrText.IndexOf('if (-not $label) {')
$idxLabelList   = $openPrText.IndexOf("@('label', 'list', '--json'")
Assert-True ($idxEmptyBranch -ge 0) 'open-pr.ps1 recognises "this repo attaches no label" as an answer rather than a gap'
Assert-True ($idxEmptyBranch -lt $idxLabelList) 'and it recognises it BEFORE asking gh for a label list whose answer cannot matter'
Assert-True ($idxEmptyBranch -lt $idxLabelGate) 'and before the compare, so the success line can never announce that '''' exists in the repository'

Write-Host ""
Write-Host "open-pr.ps1 wires in the already-done check (issue #1282)" -ForegroundColor Cyan
# The helper is proven pure above; this proves the script actually calls it, and BEFORE the push --
# a warning that arrives after forty test suites and a push is the failure #1282 describes, not a fix.
$idxAlreadyDone = $openPrText.IndexOf('Get-TargetIssueWarnings -TargetIssues')
Assert-True ($idxAlreadyDone -ge 0) 'open-pr.ps1 calls Get-TargetIssueWarnings'
Assert-True ($idxAlreadyDone -lt $idxPush) 'and it runs before the push, so the author hears it in seconds'
Assert-True ($idxAlreadyDone -lt $idxGates) 'and before the lint and test gates'
Assert-True ($openPrText.Contains("'number,state,headRefName,body'")) 'the PR-body search asks for the four fields the helper reads'
Assert-True ($openPrText.Contains("'--state', 'all'")) "the search is --state all, so a MERGED claimant counts -- that is the #1282 case"
Assert-True ($openPrText -like '*-CurrentBranch $branch*') "the current branch is passed, so this branch's own PR is not read as a rival"

# AND THE SCAN'S OWN INPUT IS NARROWED (issue #1718). Get-TargetIssueWarnings is only as good as the
# numbers it is handed, and until September 9, 2026 those came off the WHOLE development document --
# guidance block included, which is where this workflow records why its shape rules exist. Every issue
# that block cites was therefore a mention on every branch: 'issue #1650 is already CLOSED' fired on
# feat/1703-test-gate-cost, which has nothing to do with #1650. The split itself is proven in
# entry-scaffold.tests.ps1; this is the assert that the script actually uses it.
Assert-True ($openPrText -match '\$mentionText = Get-DevelopmentBranchText -Text \(\[System\.IO\.File\]::ReadAllText\(\$entryPath') `
    'the mention text is the branch''s own content, not the whole file -- the guidance block cites issues of its own'
$idxBranchText = $openPrText.IndexOf('$mentionText = Get-DevelopmentBranchText')
Assert-True ($idxBranchText -ge 0 -and $idxBranchText -lt $idxAlreadyDone) 'and the narrowing happens before the already-done check reads it'
Assert-True ($openPrText -notmatch '\$mentionText = \[System\.IO\.File\]::ReadAllText') 'with no second, unnarrowed read left behind'

# --- Get-DirectPushBlockingRules / Get-FoldPushVerdict (issue #1278) ------------------------------
# WHY THIS BLOCK EXISTS. ship-pr merged PR #1271, checked out main, folded, committed -- and the push
# was refused with GH013, "Required status check 'lint-en-tests' is expected". The run ended
# merged-but-unfolded: the entry unfolded, the branch document still on the trunk, every gate green
# until a release trips over it. That is step 0's own failure mode reached by a second route, so the
# repair is step 0's answer -- refuse before the merge, where refusing costs nothing.
#
# THE TWO READS ARE INDEPENDENT, and that is the property the whole check rests on. Measured against
# the live API on September 3, 2026: `rules/branches/main` returns `required_status_checks` to an
# account whose `current_user_can_bypass` is `always`, so the rule list does NOT tell you whether this
# account is bound by it. A verdict made from the rule list alone would refuse every ship in this repo.
Write-Host "`nGet-DirectPushBlockingRules / Get-FoldPushVerdict (#1278)" -ForegroundColor Cyan

# The live shape, transcribed from `gh api repos/DKJ-Solutions/claude-code-specialists/rules/branches/main`
# on the day of the failure -- so the fixture is what GitHub actually sends, not what it might send.
$rulesMain = @'
[{"type":"deletion","ruleset_source_type":"Repository","ruleset_source":"DKJ-Solutions/claude-code-specialists","ruleset_id":19008062},
 {"type":"non_fast_forward","ruleset_source_type":"Repository","ruleset_source":"DKJ-Solutions/claude-code-specialists","ruleset_id":19008062},
 {"type":"required_status_checks","parameters":{"strict_required_status_checks_policy":false,"do_not_enforce_on_create":false,"required_status_checks":[{"context":"lint-en-tests","integration_id":15368}]},"ruleset_source_type":"Repository","ruleset_source":"DKJ-Solutions/claude-code-specialists","ruleset_id":19008062}]
'@

$blocking = Get-DirectPushBlockingRules -BranchRulesJson $rulesMain
Assert-True $blocking.Readable 'the live rules payload reads'
Assert-Equal 1 $blocking.Blocking.Count 'one ruleset carries a rule a direct push cannot satisfy'
Assert-Equal '19008062' $blocking.Blocking[0].RulesetId 'and it is named by id, which is what the bypass is looked up with'
Assert-Equal 'required_status_checks' ($blocking.Blocking[0].Rules -join ',') 'only the blocking rule is reported'
Assert-Equal 'lint-en-tests' ($blocking.Blocking[0].Contexts -join ',') 'and the check context, so the refusal can name what the remote names'

# THE THREE THAT DO NOT BLOCK, asserted by name. `deletion` and `non_fast_forward` sit in the SAME
# ruleset as the one that does, so a function that reported per-ruleset instead of per-rule would look
# identical on this repo and refuse a fold on a trunk that merely forbids force-pushes.
$harmless = Get-DirectPushBlockingRules -BranchRulesJson '[{"type":"deletion","ruleset_id":7},{"type":"non_fast_forward","ruleset_id":7},{"type":"required_linear_history","ruleset_id":7},{"type":"required_signatures","ruleset_id":7}]'
Assert-True $harmless.Readable 'a payload of only non-blocking rules still reads'
Assert-Equal 0 $harmless.Blocking.Count 'deletion, non_fast_forward, required_linear_history and required_signatures do not block a fold'

# The other two that DO, and they are the definition of each rule rather than a guess: `pull_request`
# demands the change arrive through a PR (a fold does not), and `update` restricts the ref update itself.
$pr = Get-DirectPushBlockingRules -BranchRulesJson '[{"type":"pull_request","ruleset_id":8}]'
Assert-Equal 1 $pr.Blocking.Count 'a pull_request rule blocks a fold -- the fold is not a pull request'
$upd = Get-DirectPushBlockingRules -BranchRulesJson '[{"type":"update","ruleset_id":9}]'
Assert-Equal 1 $upd.Blocking.Count 'an update rule blocks a fold -- it restricts the ref update itself'

# EMPTY IS NOT UNREADABLE, and 5.1 makes that worth an assert: '[]' parses to $null, which is exactly
# what a failed parse leaves behind. Read as unreadable, every consumer with an unprotected trunk would
# get a warning on every ship for a question that has a clean answer.
$none = Get-DirectPushBlockingRules -BranchRulesJson '[]'
Assert-True $none.Readable 'an empty rule list READS -- a trunk with no rules is an answer, not a failure'
Assert-Equal 0 $none.Blocking.Count 'and nothing blocks'

Assert-True (-not (Get-DirectPushBlockingRules -BranchRulesJson '').Readable) 'an empty payload is unreadable'
Assert-True (-not (Get-DirectPushBlockingRules -BranchRulesJson 'not json').Readable) 'and so is an unparseable one'

# THE VERDICT, and the case the issue is about. `maikel-bwj` is neither an OrganizationAdmin nor holder
# of the repo admin role, the two bypass actors main-ci-gate carries, so its current_user_can_bypass is
# 'never' -- and every ship-pr run from that account merged and then could not push the fold.
$blocked = Get-FoldPushVerdict -BranchRulesJson $rulesMain -BypassByRulesetId @{ '19008062' = 'never' } -NameByRulesetId @{ '19008062' = 'main-ci-gate' }
Assert-True $blocked.Blocked 'an account that cannot bypass the required status check is refused BEFORE the merge (#1278)'
Assert-True (-not $blocked.Unknown) 'and that is a decision, not an unknown'
Assert-True ($blocked.Reason -like '*main-ci-gate*') 'the reason names the ruleset, so the remedy has an address'
Assert-True ($blocked.Reason -like '*lint-en-tests*') 'and the check, so it is recognisably the same event as the GH013 text'

# THE OTHER HALF, and the one that must not regress: this repo's own owner ships many times a day
# through exactly this ruleset. A verdict that refused here would be worse than the defect.
$allowed = Get-FoldPushVerdict -BranchRulesJson $rulesMain -BypassByRulesetId @{ '19008062' = 'always' }
Assert-True (-not $allowed.Blocked) 'an account with bypass ships as before'
Assert-True (-not $allowed.Unknown) 'and says so rather than warning'

# 'pull_requests_only' IS NOT BYPASS HERE. GitHub's three values answer "may this actor bypass"; only
# 'always' answers yes for a DIRECT push, and the fold is a direct push by design. Asserted separately
# because the word 'bypass' in that value is exactly what invites reading it as a yes.
$prOnly = Get-FoldPushVerdict -BranchRulesJson $rulesMain -BypassByRulesetId @{ '19008062' = 'pull_requests_only' }
Assert-True $prOnly.Blocked 'pull_requests_only is not bypass for a fold -- the fold is not a pull request'

# UNKNOWN WARNS, IT DOES NOT REFUSE -- the opposite posture to Get-MergeBlockVerdict, and deliberately.
# There an unread required-check list could let red code onto the trunk. Here the thing at risk is a
# fold that can be redone by hand, while refusing on an unread ruleset would take ship-pr away from
# every consumer whose token cannot read one. Same answer as step 0's own unreadable-worktree arm.
$unknownBypass = Get-FoldPushVerdict -BranchRulesJson $rulesMain -BypassByRulesetId @{}
Assert-True (-not $unknownBypass.Blocked) 'an unread bypass never refuses a ship'
Assert-True $unknownBypass.Unknown 'but it does say the question was not answered'

$unknownRules = Get-FoldPushVerdict -BranchRulesJson 'not json'
Assert-True (-not $unknownRules.Blocked) 'an unread rule list never refuses a ship either'
Assert-True $unknownRules.Unknown 'and is likewise reported rather than swallowed'

$clean = Get-FoldPushVerdict -BranchRulesJson '[]'
Assert-True (-not $clean.Blocked) 'a trunk with no rules ships'
Assert-True (-not $clean.Unknown) 'silently -- there is nothing to warn about'

# A ruleset whose blocking rule is bypassable while a SECOND one is not: the verdict is per ruleset, and
# one bypassable ruleset must not clear another. Both live in the same payload, as they would on a repo
# carrying an org ruleset on top of its own.
$twoRulesets = '[{"type":"required_status_checks","parameters":{"required_status_checks":[{"context":"ci"}]},"ruleset_id":1,"ruleset_source_type":"Repository"},{"type":"pull_request","ruleset_id":2,"ruleset_source_type":"Organization","ruleset_source":"DKJ-Solutions"}]'
$mixed = Get-FoldPushVerdict -BranchRulesJson $twoRulesets -BypassByRulesetId @{ '1' = 'always'; '2' = 'never' }
Assert-True $mixed.Blocked 'bypass on one ruleset does not clear another that blocks'
Assert-True ($mixed.Reason -notlike '*ruleset_id*1*applies*') 'and the bypassed one is not named as a blocker'
$twoBlocking = Get-DirectPushBlockingRules -BranchRulesJson $twoRulesets
$orgRec = @($twoBlocking.Blocking | Where-Object { $_.RulesetId -eq '2' })[0]
Assert-Equal 'Organization' $orgRec.SourceType 'the source type travels, because an org ruleset is not under repos/<repo>/rulesets and asking for it there 404s'
Assert-Equal 'DKJ-Solutions' $orgRec.Source 'and so does the org name the detail read needs'

# AND ship-pr.ps1 ACTUALLY RUNS IT, BEFORE THE MERGE. Without this assert every check above stays green
# while the orchestrator merges first and folds into a rejection again -- which IS the defect, not a
# regression in the helper. Same reasoning as the open-pr ordering asserts above: this file is the one
# caller no suite gets to run.
$idxFoldGate = $shipText.IndexOf('Get-FoldPushVerdict -BranchRulesJson')
$idxOpenPr   = $shipText.IndexOf("'-File', (Join-Path `$PSScriptRoot 'open-pr.ps1')")
$idxMergeNow = $shipText.IndexOf("@('pr', 'merge'")
Assert-True ($idxFoldGate -ge 0) 'ship-pr.ps1 asks whether it can push the fold (#1278)'
Assert-True ($idxOpenPr -gt $idxFoldGate) 'and it asks BEFORE step 1, so nothing is pushed and no PR exists when it refuses'
Assert-True ($idxMergeNow -gt $idxFoldGate) 'and long before the merge, which is the whole repair'
$idxWorktree = $shipText.IndexOf("Get-WorktreeHoldingBranch -PorcelainLines")
Assert-True ($idxWorktree -ge 0 -and $idxWorktree -lt $idxFoldGate) 'the free local check still runs first -- a network read must not cost the one that needs no network'
Assert-True ($shipText -like '*rules/branches/main*') 'the trunk rules are read from the branch endpoint, which does NOT filter by bypass'
Assert-True ($shipText -like '*current_user_can_bypass*') 'and the bypass from the ruleset detail, which is the only endpoint carrying it'
Assert-True ($shipText -like '*orgs/$($rec.Source)/rulesets/*') 'an Organization ruleset is read from the org endpoint'
Assert-True ($shipText -like '*this is the cheap place to stop*') 'the refusal says nothing was merged, which is the fact the reader needs first'


# --- Get-MergeQueueVerdict: is the trunk behind a merge queue? (issue #1506) ----------------------
# WHY THIS BLOCK EXISTS. Under a queue `gh pr merge` ENQUEUES and exits 0; GitHub merges the PR
# minutes later on a gh-readonly-queue/** branch, in a process the shipping session never observes.
# Folding on that exit code writes the changelog entry onto the trunk ahead of the merge it describes
# (#1325), so ship-pr has to know which of the two worlds it is in BEFORE it decides to fold.
#
# THE PAYLOAD IS THE ONE STEP 0b ALREADY FETCHED, which is why this is a separate reader over the same
# JSON rather than a second gh call -- and why the assert below feeds it the live shape verbatim.
Write-Host ""
Write-Host "Get-MergeQueueVerdict -- the trunk behind a queue (#1506)" -ForegroundColor Cyan

# The live shape, transcribed from `gh api repos/DKJ-Solutions/claude-code-specialists/rules/branches/main`
# on September 6, 2026, the day the queue went live on main-ci-gate. Trimmed to the type/ruleset_id
# pairs this function reads; the parameters blocks are Get-DirectPushBlockingRules's business.
$rulesQueued = '[{"type":"deletion","ruleset_id":19008062},{"type":"non_fast_forward","ruleset_id":19008062},{"type":"required_status_checks","ruleset_id":19008062,"parameters":{"required_status_checks":[{"context":"lint-en-tests"}]}},{"type":"merge_queue","ruleset_id":19008062,"parameters":{"merge_method":"MERGE"}}]'

$q = Get-MergeQueueVerdict -BranchRulesJson $rulesQueued
Assert-True $q.Readable 'the live trunk payload is readable'
Assert-True $q.Active 'and a merge_queue rule in it reads as an active queue'

# The same trunk WITHOUT the queue rule -- this repo's own shape until September 6, 2026. Readable and
# not active is the answer that sends ship-pr down the direct-merge path, so it must be distinguishable
# from the unreadable case below by more than the Active flag alone.
$rulesNoQueue = '[{"type":"deletion","ruleset_id":19008062},{"type":"required_status_checks","ruleset_id":19008062}]'
$nq = Get-MergeQueueVerdict -BranchRulesJson $rulesNoQueue
Assert-True $nq.Readable 'a trunk with rules but no merge_queue is still readable'
Assert-True (-not $nq.Active) 'and reads as no queue'

# A trunk with NO rules at all -- the ordinary consumer. An empty JSON array parses to $null in 5.1,
# which is the legitimate "no rules" answer and must not be mistaken for unparseable.
$empty = Get-MergeQueueVerdict -BranchRulesJson '[]'
Assert-True $empty.Readable 'an empty rule list is readable, not unreadable -- 5.1 parses [] to $null'
Assert-True (-not $empty.Active) 'and reads as no queue'

# UNREADABLE IS NOT "NO QUEUE", and this pair is the assert that stops a later simplification from
# collapsing them. Both return Active = $false; only Readable tells the caller whether that $false was
# an answer or a shrug, and ship-pr keeps its OLD behaviour on a shrug.
Assert-True (-not (Get-MergeQueueVerdict -BranchRulesJson '').Readable) 'an empty payload is unreadable'
Assert-True (-not (Get-MergeQueueVerdict -BranchRulesJson 'not json').Readable) 'and so is an unparseable one'
Assert-True (-not (Get-MergeQueueVerdict -BranchRulesJson 'not json').Active) 'and an unreadable payload never claims a queue'

# The type is matched case- and whitespace-insensitively, like every other type read in this file.
Assert-True (Get-MergeQueueVerdict -BranchRulesJson '[{"type":" Merge_Queue "}]').Active `
    'the rule type is normalised before it is compared, as the sibling readers do'

# AND THE OMISSION IN Get-DirectPushBlockingRules IS DELIBERATE, so it is pinned rather than left to be
# "fixed" by a later sweep. A merge_queue rule DOES block a direct push -- both refusals appeared in the
# GH013 text of the fold-on-merge run carrying the #1504 merge -- but a caller reads this verdict first
# and never reaches the fold-push question, so listing the type there too would add an unreachable
# branch and a second answer to one question.
$mqOnly = Get-DirectPushBlockingRules -BranchRulesJson '[{"type":"merge_queue","ruleset_id":19008062}]'
Assert-True $mqOnly.Readable 'a merge_queue-only payload is readable'
Assert-Equal 0 $mqOnly.Blocking.Count 'and merge_queue is NOT a fold-push blocker -- Get-MergeQueueVerdict owns that question (#1506)'

# AND ship-pr.ps1 DEFERS THE TRUNK-HOLDER REFUSAL PAST THIS VERDICT (issue #1572). Step 0a reads whether
# another worktree holds 'main'; that refusal used to fire immediately, on the ground that "step 5 could
# not fold after the merge" -- which does not hold under a queue, where this session folds nothing (the
# queue's own push to main runs fold-on-merge.yml). It blocked the exact workflow the lane exists for,
# since step 2b (#1073) leaves the primary standing on the trunk on purpose. So the READ stays first --
# it is free and local, and a network read must not cost it -- the queue verdict is computed next, and
# the refusal fires only where -not $queueActive. Same shape and justification #1506 gave the fold-push
# verdict one block down. Without these asserts a later edit can slide the refusal back above the verdict
# and re-break the lane workflow with every helper test still green -- this file is ship-pr's only caller.
$idxTrunkRead   = $shipText.IndexOf('Get-WorktreeHoldingBranch -PorcelainLines')
$idxQueueRead   = $shipText.IndexOf('Get-MergeQueueVerdict -BranchRulesJson')
$idxTrunkRefuse = $shipText.IndexOf('if ($trunkHolder -and -not $queueActive)')
$idxTrunkNote   = $shipText.IndexOf('if ($trunkHolder -and $queueActive)')
Assert-True ($idxTrunkRead -ge 0) 'ship-pr.ps1 reads whether another worktree holds the trunk (#1069)'
Assert-True ($idxTrunkRefuse -ge 0) 'and its refusal is gated on -not $queueActive (#1572)'
Assert-True ($idxTrunkRead -lt $idxQueueRead) 'the free local worktree read runs before the network queue read -- the network read must not cost the local one'
Assert-True ($idxQueueRead -lt $idxTrunkRefuse) 'and the queue verdict is known BEFORE the trunk-holder refusal, so a lane ship is not refused on a queue where step 5 folds nothing'
Assert-True ($idxTrunkNote -ge 0 -and $idxTrunkNote -gt $idxQueueRead) 'under a queue the held trunk is noted, not refused'
Assert-True ($shipText -like '*not a blocker under a queue: step 5 folds nothing here (#1572)*') 'and the note says why, naming the issue'

# --- Get-RequiredCheckRunIds: which Actions run sits behind a named check? (issue #1292 re-anchor) ---
# THE RE-ANCHOR: the retired Get-CertifyingRunTimestamp read a check's own startedAt directly out of
# the checks payload -- a red-team caught that startedAt under-refuses (it can only be LATER than the
# true ref-fix moment, so a commit landing in that gap silently reads as tested when it was not). The
# repair instead finds the RUN behind a required check from its 'link', so the caller can ask that
# run's own created_at, which stays anchored across a re-run in a way startedAt does not (see
# Get-CertifyingRunCreatedAt's own header for the measured instance).
Write-Host ""
Write-Host "Get-RequiredCheckRunIds -- the run(s) behind named checks (issue #1292 re-anchor)" -ForegroundColor Cyan

$oneLinked = '[{"name":"lint-en-tests","link":"https://github.com/o/r/actions/runs/111/job/222"}]'
Assert-Equal '111' (@(Get-RequiredCheckRunIds -ChecksJson $oneLinked -Names @('lint-en-tests'))[0]) 'a single named check resolves its run id from the link'

# No names at all -- nothing to look up, so no read of the payload is even attempted.
Assert-Equal 0 @(Get-RequiredCheckRunIds -ChecksJson $oneLinked -Names @()).Count 'no names -> empty'
Assert-Equal 0 @(Get-RequiredCheckRunIds -ChecksJson $oneLinked).Count 'Names omitted (defaults to empty) -> empty'

# Every unreadable ChecksJson shape collapses to empty, same posture as every other reader in this file.
foreach ($bad in @('', '   ', 'not json', 'null', '[]', '{}')) {
    Assert-Equal 0 @(Get-RequiredCheckRunIds -ChecksJson $bad -Names @('lint-en-tests')).Count "unreadable ChecksJson ('$bad') -> empty"
}
Assert-Equal 0 @(Get-RequiredCheckRunIds -Names @('lint-en-tests')).Count 'ChecksJson omitted -> empty'

# A name absent from the checks payload -- nothing in the payload can answer for it.
Assert-Equal 0 @(Get-RequiredCheckRunIds -ChecksJson $oneLinked -Names @('claude-review')).Count 'a name matching no record -> empty'

# TWO NAMED CHECKS, DIFFERENT RUNS -- both ids come back, in payload order.
$twoLinked = @'
[
  {"name":"lint-en-tests","link":"https://github.com/o/r/actions/runs/111/job/222"},
  {"name":"claude-review","link":"https://github.com/o/r/actions/runs/333/job/444"}
]
'@
$twoIds = @(Get-RequiredCheckRunIds -ChecksJson $twoLinked -Names @('lint-en-tests', 'claude-review'))
Assert-Equal (('111', '333') -join ',') ($twoIds -join ',') 'two named checks -> both run ids, in payload order'

# TWO NAMED CHECKS, THE SAME RUN -- one id, not two: two jobs of one workflow run share a run id, and
# the caller must not ask gh for the same run's created_at twice.
$sameRun = @'
[
  {"name":"lint-en-tests","link":"https://github.com/o/r/actions/runs/111/job/222"},
  {"name":"claude-review","link":"https://github.com/o/r/actions/runs/111/job/555"}
]
'@
$dedupedIds = @(Get-RequiredCheckRunIds -ChecksJson $sameRun -Names @('lint-en-tests', 'claude-review'))
Assert-Equal 1 $dedupedIds.Count 'two checks from the SAME run -> one id, deduplicated'
Assert-Equal '111' $dedupedIds[0] 'and it is the shared run id'

# A LINK NAMING NO ACTIONS RUN IS SKIPPED, not a crash and not a bogus id -- an external status check
# (e.g. a third-party CI service) has no Actions run behind it at all.
$externalLink = '[{"name":"netlify","link":"https://app.netlify.com/deploy/abc123"}]'
Assert-Equal 0 @(Get-RequiredCheckRunIds -ChecksJson $externalLink -Names @('netlify')).Count 'a link naming no Actions run resolves nothing'

# NON-NAMED CHECKS ARE IGNORED even when they carry a resolvable run -- only the caller's own -Names
# take part, so a check outside the ruleset cannot smuggle its run in.
$withNonRequired = @'
[
  {"name":"lint-en-tests","link":"https://github.com/o/r/actions/runs/111/job/222"},
  {"name":"netlify","link":"https://github.com/o/r/actions/runs/999/job/888"}
]
'@
$onlyRequired = @(Get-RequiredCheckRunIds -ChecksJson $withNonRequired -Names @('lint-en-tests'))
Assert-Equal (@('111') -join ',') ($onlyRequired -join ',') "a non-required check's run id does not ride along"

# A record with no name is skipped rather than throwing, same as every other reader in this file.
Assert-Equal 0 @(Get-RequiredCheckRunIds -ChecksJson '[{"link":"https://github.com/o/r/actions/runs/111/job/222"}]' -Names @('lint-en-tests')).Count 'a nameless record cannot match a required name'


# --- Get-CertifyingRunCreatedAt: the earliest already-fetched created_at (issue #1292 re-anchor) -----
# PURE reduction over values the caller has already fetched (`gh api .../actions/runs/<id>
# --jq '.created_at'`) for each id Get-RequiredCheckRunIds named. Anchored on created_at rather than a
# check's startedAt specifically because created_at stays fixed across a re-run and startedAt does not
# -- verified on a genuine re-run in the source repo's own history; see the function's own header.
Write-Host ""
Write-Host "Get-CertifyingRunCreatedAt -- the earliest already-fetched created_at (issue #1292 re-anchor)" -ForegroundColor Cyan

Assert-Equal ([datetime]::Parse('2026-09-02T15:59:52Z').ToUniversalTime().Ticks) `
    ((Get-CertifyingRunCreatedAt -CreatedAtValues @('2026-09-02T15:59:52Z')).Ticks) `
    'a single value returns its own timestamp'

# THE EARLIEST WINS, because a ruleset can require checks from more than one distinct triggering run;
# the earliest is closest to when ANY of them fixed a ref this branch is being merged against.
$earliestCreated = Get-CertifyingRunCreatedAt -CreatedAtValues @('2026-09-02T15:59:52Z', '2026-09-02T10:00:00Z')
Assert-Equal ([datetime]::Parse('2026-09-02T10:00:00Z').ToUniversalTime().Ticks) $earliestCreated.Ticks 'two values -> the EARLIER one wins, not the first in the array'

# THE ZERO-TIME SHAPE (issue #977's `0001-01-01T00:00:00Z`) MUST STILL BE SKIPPED, NOT TREATED AS THE
# EARLIEST -- a zero anchor would otherwise always be the minimum and would void every certificate,
# exactly the failure the retired Get-CertifyingRunTimestamp's own asserts caught, carried over here.
$skippingZeroCreated = Get-CertifyingRunCreatedAt -CreatedAtValues @('0001-01-01T00:00:00Z', '2026-09-02T10:00:00Z')
Assert-Equal ([datetime]::Parse('2026-09-02T10:00:00Z').ToUniversalTime().Ticks) $skippingZeroCreated.Ticks 'a zero-time value is skipped rather than winning as the earliest'

# When EVERY value is zero-time, blank, unparseable, or absent, none can answer -- $null, never the
# floor of the type.
Assert-True ($null -eq (Get-CertifyingRunCreatedAt -CreatedAtValues @('0001-01-01T00:00:00Z'))) 'every value unstarted-shaped -> $null, never the epoch'
Assert-True ($null -eq (Get-CertifyingRunCreatedAt -CreatedAtValues @('', '   ', $null))) 'blank/whitespace/null values -> $null'
Assert-True ($null -eq (Get-CertifyingRunCreatedAt)) 'no values at all (default) -> $null'
Assert-True ($null -eq (Get-CertifyingRunCreatedAt -CreatedAtValues @())) 'an explicit empty array -> $null'
Assert-True ($null -eq (Get-CertifyingRunCreatedAt -CreatedAtValues @('not a date'))) 'an unparseable value -> $null'

# An unparseable value beside a real one costs nothing -- the real one still wins.
$mixedCreated = Get-CertifyingRunCreatedAt -CreatedAtValues @('not a date', '2026-09-02T10:00:00Z')
Assert-Equal ([datetime]::Parse('2026-09-02T10:00:00Z').ToUniversalTime().Ticks) $mixedCreated.Ticks 'an unparseable value beside a real one -> the real one wins'


# --- Get-StaleCertificateVerdict: has 'main' moved since the certifying run? (issue #1292) ----------
# PURE: the caller does the git reading (fetch + first-parent log since the certifying timestamp) and
# hands the resulting SHA list here. This is the whole decision table, without a live remote.
Write-Host ""
Write-Host "Get-StaleCertificateVerdict -- has 'main' moved since the certifying run? (issue #1292)" -ForegroundColor Cyan

$noCommits = Get-StaleCertificateVerdict -NewMainCommits @()
Assert-Equal $false $noCommits.Stale        'no new commits -> not stale'
Assert-Equal 0      $noCommits.Count        'and the count is zero'
Assert-Equal 0      @($noCommits.Commits).Count 'and the commit list is empty, not $null'

$defaulted = Get-StaleCertificateVerdict
Assert-Equal $false $defaulted.Stale 'the default (no -NewMainCommits at all) reads the same as an explicit empty list'

$nullPassed = Get-StaleCertificateVerdict -NewMainCommits $null
Assert-Equal $false $nullPassed.Stale 'an explicit $null is treated the same as no commits, not as a crash'

$oneCommit = Get-StaleCertificateVerdict -NewMainCommits @('aaaaaaaa1111111111111111111111111111aaaa')
Assert-Equal $true $oneCommit.Stale  'one commit -> stale'
Assert-Equal 1     $oneCommit.Count  'and the count is one'
Assert-Equal 'aaaaaaaa1111111111111111111111111111aaaa' $oneCommit.Commits[0] 'and the SHA itself comes through'

$shaA = 'a1111111111111111111111111111111111111a'
$shaB = 'b2222222222222222222222222222222222222b'
$shaC = 'c3333333333333333333333333333333333333c'
$severalCommits = Get-StaleCertificateVerdict -NewMainCommits @($shaA, $shaB, $shaC)
Assert-Equal $true $severalCommits.Stale 'several commits -> stale'
Assert-Equal 3     $severalCommits.Count 'with the right count'
Assert-Equal (($shaA, $shaB, $shaC) -join ',') (($severalCommits.Commits) -join ',') 'and the SHAs come through in the order git produced them'

# DUPLICATE SHAs ARE DE-DUPLICATED (piped through Select-Object -Unique), so a commit that shows up
# twice in the log read (e.g. a caller that re-queries) does not inflate the count.
$dupedCommits = Get-StaleCertificateVerdict -NewMainCommits @($shaA, $shaA, $shaB)
Assert-Equal $true $dupedCommits.Stale 'duplicates still read as stale'
Assert-Equal 2     $dupedCommits.Count 'but the duplicate is not counted twice'

# NULL/EMPTY/WHITESPACE ENTRIES ARE FILTERED OUT AND DO NOT INFLATE THE COUNT -- git's own output is
# newline-split by the caller and could hand through a blank line at the end.
$withBlanks = Get-StaleCertificateVerdict -NewMainCommits @($shaA, '', '   ', $null, $shaB)
Assert-Equal $true $withBlanks.Stale 'blank/whitespace/null entries beside real SHAs still read as stale'
Assert-Equal 2     $withBlanks.Count 'and they are not counted as commits themselves'

# Blanks alone -> no commits at all, not a stale verdict manufactured from nothing.
$onlyBlanks = Get-StaleCertificateVerdict -NewMainCommits @('', '   ', $null)
Assert-Equal $false $onlyBlanks.Stale 'only blank/whitespace/null entries -> not stale'
Assert-Equal 0      $onlyBlanks.Count 'with a count of zero'


# --- ship-pr.ps1's step 3b: the wiring, as far as a suite without a live remote can reach it --------
# THE ACTUAL git fetch/gh api/git log/refusal WIRING DRIVES A REAL REMOTE AND IS NOT COVERED HERE -- the
# same known gap this file's own header states for step 3's wait, step 4's merge, and every other live
# git/gh call in this script. What follows is what IS assertable without one: that step 3b calls the
# pure functions above with the arguments the re-anchor actually needs, that it reuses the check facts
# step 3 already fetched to find the run(s) rather than searching fresh, that -SkipStaleCheck actually
# gates the whole block, and that EVERY refusal path the re-anchor added -- not only the stale-certificate
# one -- prints a recognisable sentence and names the valve. Anchors are literal code fragments (a call
# with its actual argument names, an exact printed sentence) rather than a text-position ordering, per
# Sylvester's own caution: his FIRST build of this step broke an existing ordering assert in this file by
# mentioning a function name earlier in a doc comment, so a position-based assert here would carry the
# identical fragility on the very branch that pointed it out.
#
# THE FAIL-CLOSED LINE MOVED WITH THE RE-ANCHOR, AND BOTH SIDES OF IT ARE ASSERTED: no required check
# named still WARNS (nothing to protect there -- refusing would permanently block a repo with no
# ruleset), but once one IS named, every read that follows -- the run id, its created_at, the fetch, the
# log -- FAILS CLOSED rather than warning, which is the opposite of what the retired
# Get-CertifyingRunTimestamp build did.
Write-Host ""
Write-Host "ship-pr.ps1's step 3b -- what is assertable without a live remote (issue #1292 re-anchor)" -ForegroundColor Cyan

Assert-True ($shipText -like '*Get-RequiredCheckRunIds -ChecksJson $checkFactsJson -Names $staleCheckNames*') 'step 3b finds the run(s) behind the required check(s) from the check facts step 3 already fetched -- no fresh search'
Assert-True ($shipText -like '*Get-CertifyingRunCreatedAt -CreatedAtValues $createdAtValues*') 'and reduces the fetched created_at values with the re-anchored selector, not the retired startedAt one'
Assert-True ($shipText -like '*Get-StaleCertificateVerdict -NewMainCommits $newMainCommits*') 'and hands the freshly fetched main history to the verdict function, unchanged by the re-anchor'
# THE POINT OF THIS ASSERT IS THE SOURCE OF THE NAMES, NOT THE SPELLING OF THE PARSE (issue #1602).
# It pinned the inline `$requiredFactsJson | ConvertFrom-Json` until that walk was shared into
# Get-RequiredCheckNames, and the claim it exists to make is untouched: the names come from the
# payload step 3 has already fetched, so step 3b spends no gh call of its own on them.
Assert-True ($shipText -like '*Get-RequiredCheckNames -RequiredChecksJson $requiredFactsJson*') 'the required check names for the stale check come from the already-fetched required-checks payload, not a second gh call'
Assert-True ($shipText -notlike '*$parsedStaleNames*') 'and step 3b no longer carries its own copy of that walk -- the shape the one-required-check ruleset here cannot test'
Assert-True ($shipText -like '*''api'', "repos/$repo/actions/runs/$runId", ''--jq'', ''.created_at''*') 'the one NEW network call per certifying run asks for that run''s own created_at, not a check''s startedAt'

# -SkipStaleCheck actually gates the block: the whole read-and-refuse path sits behind the switch.
Assert-True ($shipText -like '*if ($SkipStaleCheck) {*') 'the escape valve is an if/else around the whole step, not a flag checked deep inside it'
Assert-True ($shipText -like '*-SkipStaleCheck set -- not checking whether*') 'and taking the escape valve says so out loud rather than silently skipping'

# NO REQUIRED CHECK NAMED -> WARN, NOT REFUSE. Nothing this predicate can protect in that repo (no
# ruleset, or an unreadable one -- indistinguishable here), so refusing would permanently block ship-pr
# on every repo without one.
Assert-True ($shipText -like '*if ($staleCheckNames.Count -eq 0) {*') 'an unknown required-check state is branched on explicitly, not folded into the refusal path'
Assert-True ($shipText -like '*no required check name is known -- not checked*') 'and it warns rather than refuses -- there is nothing here for the predicate to protect'

# ONCE A REQUIRED CHECK IS NAMED, EVERY SUBSEQUENT READ FAILS CLOSED -- the opposite posture from the
# retired build, which warned on an unresolved anchor. Each refusal below names the valve.
Assert-True ($shipText -like '*no GitHub Actions run could be found behind the required check(s)*') 'an unresolvable run behind a NAMED required check refuses -- known certificate, not verified'
Assert-True ($shipText -like '*could not read ''created_at'' for at least one run*') 'a failed created_at read refuses too, for the same reason'
Assert-True ($shipText -like '*reported no readable ''created_at''*') 'and an unparseable created_at across every run refuses as well'
Assert-True ($shipText -like '*''git fetch origin main'' failed -- NOT merged*') 'a failed fetch of ''main'' now refuses rather than warning'
Assert-True ($shipText -like '*could not read the history of ''origin/main'' -- NOT merged*') 'and so does a failed git log, for the same reason'

# The two SINGLE-LINE refusals (git fetch, git log) can be checked as one contiguous literal fragment
# spanning the refusal text AND the valve, safely -- there is no line wrap between them to reflow. The
# other two are here-strings whose wrap point is a formatting detail, not a fact worth pinning down to
# an exact line break, so for those the existence checks above are as far as this suite goes.
Assert-True ($shipText -like "*'git fetch origin main' failed -- NOT merged (issue #1292). -SkipStaleCheck ships on the old certificate anyway.*") 'the failed-fetch refusal names -SkipStaleCheck in the same single-line message'
Assert-True ($shipText -like "*could not read the history of 'origin/main' -- NOT merged (issue #1292). -SkipStaleCheck ships on the old certificate anyway.*") 'the failed-log refusal names -SkipStaleCheck in the same single-line message'

# --- ship-pr's step 3 blocks on the REQUIRED checks only (issue #1602) ----------------------------
# ORCHESTRATION, SO SOURCE TEXT IS WHAT A SUITE CAN REACH -- the same split every other ship-pr block
# in this file works under: the wait drives a live remote and the ORDER of its parts does not. What
# these asserts protect is the property the change rests on, which is an ordering claim: the merge
# happens on a certificate that has not been left to go stale by a wait on a check the ruleset does
# not require, and the report that wait used to print still happens, after the fold.
Write-Host ""
Write-Host "ship-pr.ps1's step 3 -- required-only wait, non-required reported after the fold (#1602)" -ForegroundColor Cyan

Assert-True ($shipText -like '*if ($watchNarrowed) { $watchArgs += ''--required'' }*') 'the watch narrows to the required checks when the ruleset names any'
Assert-True ($shipText -like '*$watchArgs = @(''pr'', ''checks'', "$pr", ''--watch'', ''--interval'', "$PollSeconds", ''--repo'', $repo)*') 'and the base arguments are otherwise the ones every ship before this used'
Assert-True ($shipText -notlike '*''--watch'', ''--interval'', "$PollSeconds", ''--repo'', $repo, ''--required''*') 'and --required is appended conditionally rather than baked into the call'

# THE MODE COMES FROM THE RULESET, NOT FROM THE PR'S CHECK LIST -- measured on PR #1614, this change's
# own first ship, where the registration race made the whole thing inert. These two asserts are the
# regression: the rules payload is asked FIRST, and the old probe survives only as the fall-back.
Assert-True ($shipText -like '*Get-RequiredCheckContexts -BranchRulesJson $foldRulesJson*') 'the wait mode is read from the branch-rules payload step 0b already fetched -- no registration race, no extra call'
Assert-True ($shipText -like '*Get-RequiredCheckNames -RequiredChecksJson $requiredWaitJson*') 'and the PR check list survives as the FALL-BACK, for a checkout that cannot read the trunk''s rules'
$idxCtx   = $shipText.IndexOf('Get-RequiredCheckContexts -BranchRulesJson $foldRulesJson')
$idxProbe = $shipText.IndexOf('Get-RequiredCheckNames -RequiredChecksJson $requiredWaitJson')
Assert-True ($idxCtx -ge 0 -and $idxProbe -gt $idxCtx) 'and the ruleset is asked BEFORE the probe -- the ordering is the fix, not merely having both'

# FAIL-OPEN IS THE HALF A CONSUMER FEELS, and the two reasons for it are now told apart, because the
# ruleset CAN say "requires nothing" definitively while the probe never could.
Assert-True ($shipText -like '*This trunk''s ruleset requires no check, so this waits on EVERY check, exactly as before*') 'a trunk that genuinely requires nothing is told so, and that this is not a finding'
Assert-True ($shipText -like '*The trunk''s rules could not be read, so this waits on EVERY check, exactly as before*') 'and an unreadable ruleset gets a DIFFERENT sentence -- the two states are no longer one message'

# WHAT THE WATCH DID vs WHAT THE RULESET SAYS. PR #1614 printed "every REQUIRED check is green. The
# rest are still watched" about a wait that had just watched everything, because one variable was
# asked both questions. $watchNarrowed is the repair, and these asserts are what keep them apart.
Assert-True ($shipText -like '*$watchNarrowed = ($requiredWaitNames.Count -gt 0)*') 'the flag is set from the names AT THE MOMENT the watch is built, per attempt'
Assert-True ($shipText -like '*} elseif ($watchNarrowed) {*') 'the "every REQUIRED check is green" line is gated on what the watch DID, not on what the ruleset says'
Assert-True ($shipText -like '*if ($watchNarrowed -and $requiredFactsJson) {*') 'and so is which payload the pre-merge wait report is handed'
Assert-True ($shipText -like '*if (-not $watchNarrowed) {*') 'and so is step 8, so it cannot re-report a wait that already covered everything'
Assert-True ($shipText -notlike '*if ($requiredWaitNames.Count -eq 0) {*') 'nothing downstream reads the ruleset answer as though it were the watch''s behaviour'

# THE MODE MAY NARROW MID-RUN BUT NEVER WIDEN. A required workflow that had not created its check run
# when the ruleset could not be read is found one watch later; an empty re-reading is not evidence
# that the ruleset requires nothing, and widening on it would undo the fix invisibly.
Assert-True ($shipText -like '*if ($requiredWaitRefresh.Count -gt 0) { $requiredWaitNames = $requiredWaitRefresh }*') 'the refresh only ever narrows the watch -- an unreadable re-read leaves the earlier names standing'

# --- the narrowed wait waits for a REQUIRED check, and gh has two wordings for "none" (#1602) ------
# BOTH HALVES MEASURED ON PR #1614, the second live ship of this change. `--watch --required` does NOT
# wait for a required check to appear: it reports `no required checks reported` and exits non-zero the
# moment it finds none. The registration wait had been satisfied by any check at all -- `branch-entry`
# and `claude-review` register before ci.yml's jobs -- and the loop's #1350 branch matched only the
# other wording, so this arrived as a DROPPED SOCKET: three attempts, then a refusal saying CI was
# still running about a run that was perfectly healthy.
Write-Host ""
Write-Host "ship-pr.ps1 -- the narrowed wait waits for a REQUIRED check (#1602, measured on PR #1614)" -ForegroundColor Cyan

Assert-True ($shipText -like "*-notmatch 'no (required )?checks reported'*") 'the registration poll accepts BOTH of gh''s wordings for "nothing is registered"'
Assert-True ($shipText -like "*-match 'no (required )?checks reported'*") 'and so does the watch loop''s #1350 branch, which is where the misclassification happened'
Assert-True ($shipText -notlike "*-match 'no checks reported'*") 'the narrow match that cost PR #1614 three watch attempts is gone'
Assert-True ($shipText -notlike "*-notmatch 'no checks reported'*") 'from the poll as well as from the loop'

# THE NARROWED POLL DECIDES THE QUESTION ITSELF rather than delegating it to `--required`, and that is
# about legibility: a required aggregator registers only once the jobs it needs finish, so `--required`
# could say nothing but "not yet" for seven minutes -- a blind counter where gh's live table used to
# run, which is the invisible wait #831 was filed about. Reading the full payload costs the same one
# call per poll and lets the line say what IS happening.
Assert-True ($shipText -like '*if ($waitNarrowed) { $probeArgs += @(''--json'', ''name,bucket,state'') }*') 'the narrowed poll reads the FULL payload, so it can report progress instead of only absence'
Assert-True ($shipText -like '*$missing = @($wanted | Where-Object { $seen -notcontains $_ })*') 'and decides "registered" on presence of every required name, not on gh''s --required filter'
Assert-True ($shipText -like '*if ($missing.Count -eq 0) { return $waited }*') 'ALL of them rather than any -- one registered while another is absent is the #1549 hole this wait closes'
Assert-True ($shipText -like '*to register -- $reported check(s) have reported so far*') 'the progress line names which required check is missing AND that the rest of CI is moving'
# .Contains RATHER THAN -like, and this suite walked into it: a `[` in a -like pattern opens a
# CHARACTER CLASS, so '*[string[]]$RequiredNames*' matches a single character out of {s,t,r,i,n,g,[}
# and never the literal type accelerator. The same trap Test-IsFoldOnlyCommit documents beside its own
# StartsWith, met from the other side.
Assert-True ($shipText.Contains('[string[]]$RequiredNames = @()')) 'Wait-CheckRegistration takes the required names -- empty leaves it the wait every ship made before #1602'
Assert-True ($shipText -like '*-RequiredNames $requiredWaitNames*') 'the call sites pass them -- including the #1350 re-entry, which would otherwise reintroduce the bug on the retry'

# TWO WAITS, TWO BUDGETS -- measured on PR #1614's THIRD ship, where one budget for both questions
# refused a healthy CI run. "Is there any CI at all" is answered in seconds and keeps #1234's 180s.
# "Has the REQUIRED check registered" can legitimately be minutes: in this repo `lint-en-tests` is an
# aggregator (needs: [lint, suites]), so GitHub creates its check run only once those finish.
Assert-True ($shipText -like '*$maxRequiredWaitSec = 1800*') 'the required-registration wait has a budget sized for CI, not for a registration race'
Assert-True ($shipText -like '*-MaxWaitSec $maxRequiredWaitSec -AlreadyWaited $waited*') 'and the second call uses it, sharing the seconds the first already spent'
Assert-True ($shipText -like '*$maxWaitSec = 180*') 'while the FIRST wait keeps #1234''s 180s -- a repo with no check suite still hears in seconds'
$idxAnyWait = $shipText.IndexOf('-PollSeconds $PollSeconds -MaxWaitSec $maxWaitSec' + "`r`n")
if ($idxAnyWait -lt 0) { $idxAnyWait = $shipText.IndexOf('-PollSeconds $PollSeconds -MaxWaitSec $maxWaitSec' + "`n") }
$idxReqWait = $shipText.IndexOf('-MaxWaitSec $maxRequiredWaitSec -AlreadyWaited $waited')
Assert-True ($idxAnyWait -ge 0 -and $idxReqWait -gt $idxAnyWait) 'the any-check wait runs BEFORE the required-check wait, so the narrowed refusal can say "CI is running, the required check is not there"'
Assert-True ($shipText -like '*$reentryMaxWaitSec = if ($requiredWaitNames.Count -gt 0) { $maxRequiredWaitSec } else { $maxWaitSec }*') 'and the #1350 re-entry inherits whichever budget its own question deserves'

# THE NARROWED TIMEOUT IS A DIFFERENT DIAGNOSIS, because reaching it means CI IS running and only the
# required check is missing -- so "Check the workflow" would be the wrong sentence.
Assert-True ($shipText -like '*never registered on PR #$Pr within*') 'the narrowed timeout names the required check rather than claiming no CI registered'
Assert-True ($shipText -like '*Other checks DID register, so CI is running*') 'and says so, since the first wait already proved it'
Assert-True ($shipText -like '*a rename or a typo in the*') 'and names the cause a reader can actually act on -- a required context no workflow produces'
$idxNarrowRefusal = $shipText.IndexOf('never registered on PR #$Pr within')
$idxSuiteNote = $shipText.IndexOf('$suiteNote = Get-MissingCheckSuiteRefusalNote')
Assert-True ($idxNarrowRefusal -ge 0 -and $idxSuiteNote -gt $idxNarrowRefusal) 'and it returns before the no-check-suite note, whose subject is already ruled out on this path'

# ORDER IS THE REPAIR, not tidiness: the wait cannot wait for the right thing before the mode is
# known. Asserted by offset, since that is the actual claim.
$idxMode = $shipText.IndexOf('Get-RequiredCheckContexts -BranchRulesJson $foldRulesJson')
$idxWait = $shipText.IndexOf('$waited = Wait-CheckRegistration -Pr')
Assert-True ($idxMode -ge 0 -and $idxWait -gt $idxMode) 'the mode is decided BEFORE the registration wait runs, so the wait knows what to wait for'

# AND THE REFUSAL AND PROGRESS LINES NAME WHAT THEY WAITED FOR, so a timeout on a narrowed wait does
# not read as "no CI at all" when the advisory checks were running the whole time.
Assert-True ($shipText -like '*$subject = if ($waitNarrowed) { ''required check'' } else { ''check'' }*') 'the wait names its own subject'
Assert-True ($shipText -like '*No CI $subject registered for PR #$Pr*') 'and the timeout refusal uses it'
Assert-True ($shipText -like '*(no $subject registered yet -- waited*') 'as does the progress line'

# THE REPORT IS NOT LOST, IT IS MOVED. This is the assert that would fail if step 8 were ever dropped
# as "the merge already happened": #831's whole finding was that an invisible wait turns two anecdotes
# into a policy question, and the report is what made it visible.
Assert-True ($shipText -like '*Step 8: what the NOT-required checks said (issue #1602)*') 'the moved report has a step of its own rather than being folded into an existing one'
Assert-True ($shipText -like '*Get-CheckWaitReport -ChecksJson $tailFactsJson*') 'and it is #831''s own report over the full payload, not a new summary invented here'
Assert-True ($shipText -like '*-WaitedSeconds $tailWaitedSec -PostMerge*') 'passed -PostMerge, so it does not claim a check governed a merge that has already happened'
Assert-True ($shipText -like '*-RequiredNamesJson $requiredFactsJson -WaitedSeconds $waitedSec*') 'while step 3, which runs BEFORE the merge, does not pass it'
$idxPost = $shipText.IndexOf('-WaitedSeconds $tailWaitedSec -PostMerge')
$idxPre  = $shipText.IndexOf('-RequiredNamesJson $requiredFactsJson -WaitedSeconds $waitedSec')
Assert-True ($idxPre -ge 0 -and $idxPost -gt $idxPre) 'and the un-switched call is the earlier one in the file, i.e. the pre-merge report'
Assert-True ($shipText -like '*Get-AuthoredFailureNote -AnnotationsJson*') 'the #1103 relay of what the failing check said about itself rides along -- it matters more here, being the only place the reader meets the failure'

# AND IT RUNS AFTER EVERYTHING OWED TO THE TRUNK. A wait on somebody else's CI placed above the fold
# would sit in the one gap nothing reports -- merged upstream, branch document still on the trunk
# (#1270). Asserted by offset rather than by prose, since that is the actual claim.
$foldIdx = $shipText.IndexOf('Step 5: main + fold + commit + push')
$tailIdx = $shipText.IndexOf('Step 8: what the NOT-required checks said')
Assert-True ($foldIdx -gt 0 -and $tailIdx -gt $foldIdx) 'step 8 sits BELOW the fold, so it can stall or be abandoned without leaving a half-state'
$verifyIdx = $shipText.IndexOf('Step 6: the issues the PR declared it closes')
Assert-True ($verifyIdx -gt 0 -and $tailIdx -gt $verifyIdx) 'and below the resolved-issues check, so nothing that mutates state outside this repo waits on it'

# THE QUEUE PATH MERGES NOTHING HERE, so it has no fold to report after and says where to read them.
Assert-True ($shipText -like '*The NOT-required checks were not waited for here (#1602)*') 'the enqueue exit names the report it cannot give rather than dropping it silently'

# BOUNDED, BECAUSE THIS IS THE POST-MERGE REGION #1179's RULE IS DRAWN FOR. Step 3's watch is
# unbounded on purpose -- a stall there blocks a merge that has not happened, so the PR shows it. A
# stall at step 8 leaves a finished ship holding a terminal with no prompt to come back to.
Assert-True ($shipText -like '*$tailMaxWaitSec = 1800*') 'step 8''s watch is bounded, unlike step 3''s -- the post-merge region is the worse place to hang (#1179)'
Assert-True ($shipText -like '*-TimeoutSeconds $tailMaxWaitSec*') 'and the bound is actually passed to the watch rather than only declared'

# A TIMEOUT IS NOT A FAILED CHECK, and exit code 124 is why this needs asserting: Invoke-NativeCapture
# substitutes it for a killed child so the number and TimedOut agree, which means a timed-out report
# reaches the failure branch as a non-zero exit unless TimedOut is read.
Assert-True ($shipText -like '*if ($tailChecks.ExitCode -ne 0 -and -not $tailChecks.TimedOut) {*') 'a timed-out report does not announce that a check failed -- TimedOut is read, not just the exit code'
Assert-True ($shipText -like '*} elseif (-not $tailChecks.TimedOut) {*') 'and it does not claim every check is green either -- neither arm fires on a timeout'
Assert-True ($shipText -like '*giving up on the REPORT, not on the ship (#1602)*') 'the timeout says what it gave up on, since the ship really is complete'

# THE MEASURED CLAIM THE BOUND RESTS ON, kept in the file rather than only in the issue: 1800s clears
# both populations this step waits on. If either figure is ever revised, this assert is what points at
# the number that has to move with it.
Assert-True ($shipText -like '*753s in #1602''s own n=99*') 'the bound cites the tail it was sized against'
Assert-True ($shipText -like '*23m 23s (1403s)*') 'and #831''s own worst case, which is the larger of the two'

# AND THE FAILED FETCH KEEPS GIT'S OWN DIAGNOSIS (issue #1334). The refusal above says the fetch failed;
# only git says WHY -- the auth error, the host, the reason. The flag that would drop it was added here on
# a credential argument #1330 had measured as false 23 minutes earlier (git anonymizes the URL itself via
# transport_anonymize_url), which is the fourth call site #1313 warned would copy that retired reasoning.
# The call is asserted WHOLE, as one literal fragment, so re-adding -DiscardStderr anywhere in it fails
# this suite -- an assert on the flag's absence would pass on a call that no longer exists.
Assert-True ($shipText -like "*Invoke-NativeCapture -FilePath 'git' -Arguments @('fetch', 'origin', 'main', '--quiet')*") 'step 3b''s fetch of main runs WITHOUT -DiscardStderr, so git''s own failure output survives'
Assert-True ($shipText -like '*$fetchMain.Output | Where-Object*') 'and the failure path prints that captured output before the refusal, rather than discarding it'
Assert-True ($shipText -like '*native-capture-lib.ps1*') 'the comment points at the seam holding the measurement, so the next reader meets it rather than the retired rule'

# THE git log THREE LINES BELOW KEEPS THE FLAG, on an independent reason: its output is PARSED into
# $newMainCommits, so a stray line becomes a fake SHA. That one is not the defect and must not be swept
# along with it.
Assert-True ($shipText -like "*-DiscardStderr -Arguments @('log', 'origin/main', '--first-parent'*") 'the PARSED git log keeps -DiscardStderr -- a different call with a different reason'

# The stale-certificate refusal itself names the commit count, the PR, and the remedy -- the facts a
# reader needs to act on it. Unchanged by the re-anchor, since Get-StaleCertificateVerdict did not move.
Assert-True ($shipText -like '*gained $($staleVerdict.Count) commit(s) after the run that certified PR*') 'the refusal states how many commits and which PR they voided the certificate for'
Assert-True ($shipText -like '*stale-CI certificate*') 'and leads with a recognisable, greppable name for the failure'
Assert-True ($shipText -like '*git merge origin/main*') 'the remedy tells the operator how to bring the branch forward'

# AND THE REMEDY LEADS WITH THE CHECKOUT (issue #1588). Step 2b has already handed this tree back to
# the trunk (#1073) by the time this gate fires -- past the whole CI wait -- so a remedy starting at
# `git fetch` acts on 'main': the merge fast-forwards the trunk, prints a diffstat that reads exactly
# like the branch being brought forward, and the push after it is a no-op. Nothing fails, so the first
# thing to say anything is the re-run of ship-pr, one full CI cycle later, and what it says is a
# message about the wrong problem. Measured on PR #1583 and, five days earlier, PR #1316.
#
# ASSERTED AS AN ORDER, not as three presences. The defect was never a missing string -- `git fetch`
# and `git merge` were both there and both wrong on their own -- so an assert on `git checkout`
# anywhere in the file would pass on a remedy that printed it last, or in a neighbouring message. The
# three IndexOf reads pin the sequence inside one refusal, which is the fact that repairs it. Each
# read is OFFSET from the one before it, so the two git lines are the remedy's own and not step 3b's
# unrelated single-line `'git fetch origin main' failed` refusal further up the same file -- the same
# offset-scoped technique open-pr's refresh/append ordering asserts use above (#919). The two-space
# indent does a second job here: that earlier refusal quotes the command, it does not lay it out.
# THE TOKEN, NOT THE RAW REF (issue #1594). The remedy prints $branchPaste.Token so a branch name
# carrying a shell metacharacter cannot enter a command the reader pastes; the ORDER this block exists to
# pin is unchanged, so only the string being located moved.
$idxCheckout = $shipText.IndexOf('  git checkout $($branchPaste.Token)')
$idxFetchRem = if ($idxCheckout -ge 0) { $shipText.IndexOf('  git fetch origin main', $idxCheckout) } else { -1 }
$idxMergeRem = if ($idxFetchRem -ge 0) { $shipText.IndexOf('  git merge origin/main', $idxFetchRem) } else { -1 }
Assert-True ($idxCheckout -ge 0) 'the stale-CI remedy names the branch to check out, using the branch the gate already read'
Assert-True ($idxFetchRem -gt $idxCheckout -and $idxMergeRem -gt $idxFetchRem) 'and it comes FIRST -- checkout, then fetch, then merge, in that order'
Assert-True ($shipText -like '*CHECKOUT IS THE FIRST STEP*') 'the refusal says why that line is there, so nobody reads it as a stray step'

Assert-True ($shipText -like '*-SkipStaleCheck ships on the old certificate anyway*') 'and the escape valve is documented right beside the refusal it bypasses'
Assert-True ($shipText -like '*exit 1*') 'a stale certificate is a hard refusal (an exit code), not a warning that lets the merge through'


# --- Test-IsFoldOnlyCommit: is one gained commit a fold, and nothing else? (issue #1592) ------------
# THE SHAPE IS THE WHOLE POINT. This function is what lets step 3b discount a commit, so every way of
# NOT being a fold is asserted as loudly as the fold itself -- a false positive here waves a genuinely
# untested commit past the very gate #1292 exists for.
Write-Host ""
Write-Host "Test-IsFoldOnlyCommit -- the fold's two-path shape, read off the diff (issue #1592)" -ForegroundColor Cyan

$clog = 'dkj-policy/CHANGELOG.md'
$edir = 'dkj-policy'
$reserved = @('README.md', 'CONTRIBUTING.md', 'CHANGELOG.md')
function Test-Fold {
    param([string[]]$Lines, [string]$Changelog = $clog, [string]$Dir = $edir)
    Test-IsFoldOnlyCommit -NameStatusLines $Lines -ChangelogPath $Changelog -EntryDirectory $Dir -ReservedNames $reserved
}

# The real thing: 4ea4f31b, one of the three commits that voided PR #1571's refused certificates.
$realFold = @("M`tdkj-policy/CHANGELOG.md", "D`tdkj-policy/feat-consumer-readme-update-topup.md")
Assert-Equal $true (Test-Fold -Lines $realFold) 'the measured fold commit (changelog modified + branch document deleted) reads as a fold'

# A multi-branch fold: fold-changelog-entry.ps1 folds several entries in one commit.
Assert-Equal $true (Test-Fold -Lines @("M`t$clog", "D`tdkj-policy/fix-a.md", "D`tdkj-policy/fix-b.md")) 'a fold of several branches at once still reads as a fold'

# A repo folding for the first time ADDS the changelog rather than modifying it.
Assert-Equal $true (Test-Fold -Lines @("A`t$clog", "D`tdkj-policy/fix-a.md")) 'an added changelog (a repo folding for the first time) still reads as a fold'

# THE DELETION IS THE SIGNATURE, and without it an ordinary changelog-only pull request would be
# exempted -- this repo's own suites assert on that file's intro, so its reach is not vouchable.
Assert-Equal $false (Test-Fold -Lines @("M`t$clog")) 'the changelog alone is NOT a fold -- no branch document was removed'
Assert-Equal $false (Test-Fold -Lines @("M`t$clog", "M`tdkj-policy/fix-a.md")) 'a changelog beside an EDITED branch document is not a fold either'

# And a branch document removed without the changelog being written is not the fold's shape.
Assert-Equal $false (Test-Fold -Lines @("D`tdkj-policy/fix-a.md")) 'a branch-document deletion alone is NOT a fold'

# THE BOUND IS TWO PATHS. Anything else in the diff disqualifies the commit, which is what keeps the
# exemption exactly the size the fold exception was granted at.
Assert-Equal $false (Test-Fold -Lines @("M`t$clog", "D`tdkj-policy/fix-a.md", "M`tscripts/lib/pr-issues-lib.ps1")) 'a script riding along disqualifies the commit -- this is the case #1292 was filed on'
Assert-Equal $false (Test-Fold -Lines @("M`t$clog", "D`tdkj-policy/fix-a.md", "M`tscripts/tests/new-branch.tests.ps1")) 'and so does a test file, which is #1292''s own instance verbatim'
Assert-Equal $false (Test-Fold -Lines @("M`t$clog", "D`tdkj-policy/fix-a.md", "M`tREADME.md")) 'a root doc riding along disqualifies it too -- the bound is the two paths, not "docs only"'

# AND THE BOUND HOLDS INSIDE THE FOLDER TOO -- the hole the pre-merge code review found. The three asserts
# above all disqualify on the PATH; these two disqualify on the STATUS, which the first build did not do:
# it set its flag on a 'D' and let any other status inside the folder through unremarked, so a fold-shaped
# commit with an extra add or edit beside the deletion classified as a fold. fold-changelog-entry.ps1
# cannot write that shape -- every path it names beside the changelog is one it has just removed -- and
# that is the point: this function's job is to PROVE the fold wrote a commit, so a shape it accepts
# without proof is the false positive it exists to refuse.
Assert-Equal $false (Test-Fold -Lines @("M`t$clog", "D`tdkj-policy/fix-a.md", "A`tdkj-policy/sneaky.md")) 'an ADDED markdown file in the entry folder riding along disqualifies the commit'
Assert-Equal $false (Test-Fold -Lines @("M`t$clog", "D`tdkj-policy/fix-a.md", "M`tdkj-policy/unrelated.md")) 'and so does an EDITED one -- every branch document in a fold is a deletion, not merely one of them'

# THE FOLDER'S OWN PERMANENT PAGES ARE NOT BRANCH DOCUMENTS, matched case-insensitively for the reason
# Get-BranchFilePaths.ReservedNames itself gives (Windows hands back 'Readme.md' for 'README.md').
Assert-Equal $false (Test-Fold -Lines @("M`t$clog", "D`tdkj-policy/README.md")) 'the folder''s README is not a branch document'
Assert-Equal $false (Test-Fold -Lines @("M`t$clog", "D`tdkj-policy/Contributing.md")) 'nor its contributing page, whatever its casing'

# A DELETED CHANGELOG IS NOT A FOLD -- reading it as one would exempt the single commit that could take
# the file this whole cycle depends on off the trunk.
Assert-Equal $false (Test-Fold -Lines @("D`t$clog", "D`tdkj-policy/fix-a.md")) 'a DELETED changelog is not a fold, however fold-shaped the rest looks'

# Structure the fold does not produce: a nested path, a non-markdown file, a rename or a copy.
Assert-Equal $false (Test-Fold -Lines @("M`t$clog", "D`tdkj-policy/releases/history.md")) 'a path NESTED below the entry folder is not a branch document'

# THE ONE KNOWN FALSE NEGATIVE, ASSERTED SO IT IS A DECISION AND NOT A SURPRISE. Folding a branch cut
# before the August 23, 2026 document merge can also remove Get-BranchFilePaths' LegacyCycle, which is
# nested -- so that fold is NOT exempted and its ship gets the ordinary pre-#1592 refusal. Left as it is
# on purpose: admitting a subfolder to buy back a vanishingly rare shape widens the bound for every
# commit, and the bound is the whole of what this function has to offer.
Assert-Equal $false (Test-Fold -Lines @("M`t$clog", "D`tdkj-policy/fix-a.md", "D`tdkj-policy/branch/branch-cycle.md")) 'a legacy fold that also removes the nested branch-cycle file is NOT exempted -- a false negative, which is the safe direction'
Assert-Equal $false (Test-Fold -Lines @("M`t$clog", "D`tdkj-policy/fix-a.txt")) 'a non-markdown file in the folder is not a branch document'
Assert-Equal $false (Test-Fold -Lines @("M`t$clog", "R100`tdkj-policy/fix-a.md`tdkj-policy/fix-b.md")) 'a rename (three fields) disqualifies rather than being half-read'
Assert-Equal $false (Test-Fold -Lines @("M`t$clog", "C`tdkj-policy/fix-a.md`tdkj-policy/fix-b.md")) 'and so does a copy'

# FAILS CLOSED ON EVERY MISSING INPUT. An unresolved seam must leave the commit counted exactly as it
# was before this function existed, never exempted by default.
Assert-Equal $false (Test-IsFoldOnlyCommit -NameStatusLines $realFold -ChangelogPath '' -EntryDirectory $edir) 'no changelog seam -> not a fold (fails closed)'
Assert-Equal $false (Test-IsFoldOnlyCommit -NameStatusLines $realFold -ChangelogPath $clog -EntryDirectory '') 'no entry directory -> not a fold (fails closed)'
Assert-Equal $false (Test-IsFoldOnlyCommit -ChangelogPath $clog -EntryDirectory $edir) 'no diff at all -> not a fold, never a vacuous yes'
Assert-Equal $false (Test-Fold -Lines @('', '   ', $null)) 'a diff of blank lines only -> not a fold'
Assert-Equal $false (Test-Fold -Lines @('M dkj-policy/CHANGELOG.md')) 'a SPACE-separated line (not git''s tab form) is not parsed into a fold'

# A repo still carrying a pre-rename folder name simply gets no exemption -- the same refusal it gets
# today, which is why the folder is a parameter rather than a literal.
Assert-Equal $false (Test-Fold -Lines @("M`tcontributing-davekjohn/CHANGELOG.md", "D`tcontributing-davekjohn/fix-a.md")) 'a pre-rename folder resolves to no exemption rather than to a guess'
Assert-Equal $true (Test-IsFoldOnlyCommit -NameStatusLines @("M`tcontributing-davekjohn/CHANGELOG.md", "D`tcontributing-davekjohn/fix-a.md") -ChangelogPath 'contributing-davekjohn/CHANGELOG.md' -EntryDirectory 'contributing-davekjohn' -ReservedNames $reserved) 'and a repo whose seams DO name that folder gets the exemption on its own answers'

# NORMALISATION: git reports forward slashes, a Windows seam may answer with backslashes. Comparing the
# two spellings is the one way this could silently drop a real path out of the fold's bound.
Assert-Equal $true (Test-IsFoldOnlyCommit -NameStatusLines $realFold -ChangelogPath 'dkj-policy\CHANGELOG.md' -EntryDirectory 'dkj-policy\' -ReservedNames $reserved) 'a backslash-spelled seam answer matches git''s forward-slash paths'


# --- Get-StaleCertificateVerdict: the fold exemption, subtracted (issue #1592) ---------------------
# THE ARITHMETIC IS DELIBERATELY DUMB HERE -- the judgement is Test-IsFoldOnlyCommit's, above, and this
# function is handed a list and subtracts it. Both halves are asserted so a caller cannot talk the
# verdict below zero, and so the pre-#1592 call shape keeps its old answer exactly.
Write-Host ""
Write-Host "Get-StaleCertificateVerdict -- the fold exemption (issue #1592)" -ForegroundColor Cyan

$shaD = 'd4444444444444444444444444444444444444d'
Assert-Equal 0 (Get-StaleCertificateVerdict -NewMainCommits @($shaA, $shaB)).ExemptCount 'no -ExemptCommits -> nothing exempt, and the verdict is exactly the pre-#1592 one'
Assert-Equal $true (Get-StaleCertificateVerdict -NewMainCommits @($shaA, $shaB)).Stale 'with the same stale answer as before'

# Every gained commit a fold -> the certificate holds. This is the measured case: both of PR #1571's
# refusals were on gained commits that were ALL folds.
$allFolds = Get-StaleCertificateVerdict -NewMainCommits @($shaA, $shaB) -ExemptCommits @($shaA, $shaB)
Assert-Equal $false $allFolds.Stale       'every gained commit exempt -> NOT stale (PR #1571''s two refusals, measured)'
Assert-Equal 0      $allFolds.Count       'with a count of zero'
Assert-Equal 0      @($allFolds.Commits).Count 'and an empty commit list, not $null'
Assert-Equal 2      $allFolds.ExemptCount 'while the exempt count still reports what was discounted'

# One fold beside one real commit -> still stale, and on the real commit only.
$mixed = Get-StaleCertificateVerdict -NewMainCommits @($shaA, $shaB, $shaC) -ExemptCommits @($shaB)
Assert-Equal $true  $mixed.Stale       'a non-fold commit beside a fold is still stale'
Assert-Equal 2      $mixed.Count       'and the count is of the NON-exempt commits only'
Assert-Equal (($shaA, $shaC) -join ',') (($mixed.Commits) -join ',') 'the reported commits are the ones that actually voided it, in git''s order'
Assert-Equal 1      $mixed.ExemptCount 'with the fold reported separately'
Assert-Equal $shaB  $mixed.ExemptCommits[0] 'and named, so the refusal can say what it discounted'

# A SHA exempted that was never gained is ignored, not subtracted -- a caller cannot drive the count
# below what the trunk actually shows.
$phantom = Get-StaleCertificateVerdict -NewMainCommits @($shaA) -ExemptCommits @($shaB, $shaC, $shaD)
Assert-Equal $true $phantom.Stale       'exempting SHAs that were never gained changes nothing'
Assert-Equal 1     $phantom.Count       'the count still reflects the commits that were'
Assert-Equal 0     $phantom.ExemptCount 'and nothing is claimed as discounted that was not there'

# Case-insensitive, because the SHA is read back out of two different git invocations (the first-parent
# log for the list, the diff for the classification) rather than one.
$casing = Get-StaleCertificateVerdict -NewMainCommits @($shaA.ToUpper()) -ExemptCommits @($shaA.ToLower())
Assert-Equal $false $casing.Stale 'a SHA exempted in different casing still matches'

Assert-Equal $false (Get-StaleCertificateVerdict -NewMainCommits @($shaA) -ExemptCommits @($shaA, '', '   ', $null)).Stale 'blank entries in -ExemptCommits are filtered rather than matching a blank SHA'


# --- ship-pr.ps1's step 3b: the fold exemption, wired (issue #1592) --------------------------------
# Same limits as the block above: the live git show is not driven here, so what is asserted is that the
# step calls the pure classifier with the arguments it needs, reads the seams rather than hard-coding a
# folder, fails closed, and says what it discounted.
Write-Host ""
Write-Host "ship-pr.ps1's step 3b -- the fold exemption, wired (issue #1592)" -ForegroundColor Cyan

Assert-True ($shipText -like '*Test-IsFoldOnlyCommit -NameStatusLines @($diffRead.Output) -ChangelogPath $changelogForFold*') 'step 3b classifies each gained commit with the pure function, off that commit''s own diff'
Assert-True ($shipText -like "*'show', '--name-status', '--format=', `$sha*") 'the diff read is name-status with an emptied header, so only the body is parsed'
Assert-True ($shipText -like '*-Utf8 -FilePath ''git'' -DiscardStderr -Arguments @(''show'', ''--name-status''*') 'and it carries -Utf8 AND -DiscardStderr: the paths are DATA (issue #907) and the output is PARSED'
Assert-True ($shipText -like '*Get-SeamValue -Name ''Get-ChangelogPath''*') 'the changelog half of the bound comes from the repo''s own seam, not from a literal in this script'
Assert-True ($shipText -like '*$branchPathsForFold = Get-BranchFilePaths*') 'and the folder half comes from Get-BranchFilePaths, read once and held, the same answer four other scripts read'
Assert-True ($shipText -like '*$branchPathsForFold.ReservedNames*') 'including the folder''s permanent pages, so a fold cannot be faked with its README'
Assert-True ($shipText -like '*seam-lib.ps1*') 'and seam-lib is dot-sourced, since Get-SeamValue does not travel with the other libs this script loads'

# FAILS CLOSED: a diff that will not read leaves the commit counted, and an unresolved seam exempts
# nothing at all.
Assert-True ($shipText -like '*if ($diffRead.ExitCode -ne 0) { continue }*') 'a diff that will not read leaves that commit counted -- it is never exempted by default'
Assert-True ($shipText -like '*if ($changelogForFold -and $entryDirForFold) {*') 'and an unresolved seam skips the whole classification rather than guessing at it'
Assert-True ($shipText -like '*if ($newMainCommits.Count -gt 0) {*') 'nothing is read at all when the trunk has not moved'

# The verdict is handed both lists, and what was discounted is said out loud -- in the dim line and in
# the refusal, because the operator's next move is to look at the trunk and count for themselves.
Assert-True ($shipText -like '*Get-StaleCertificateVerdict -NewMainCommits $newMainCommits -ExemptCommits $foldExemptCommits*') 'the verdict receives the exempt list beside the gained one'
Assert-True ($shipText -like '*are fold commits (changelog + branch document only) -- discounted (issue #1592).*') 'a discounted fold is reported even on the passing path, so the silence is never ambiguous'

Write-Host ""
Write-Host "Get-InterruptedShipCandidates -- what an interrupted ship leaves behind (issue #1620)" -ForegroundColor Cyan
# THE PAIR IS THE SIGNAL: an open PR whose head ref is a branch THIS checkout has. Neither half alone
# says anything, and the local half is what keeps the list quiet -- measured in this repo the day the
# function was written, 26 local branches against 1 open PR whose head ref was not here.
$candLocal = @('main', 'fix/1616-go-ahead', 'feat/other', 'docs/merged-leftover')
$candJson = '[{"headRefName":"fix/1616-go-ahead","number":1618},{"headRefName":"feat/other","number":1601},{"headRefName":"fix/elsewhere","number":1590}]'
$cands = @(Get-InterruptedShipCandidates -Json $candJson -LocalBranches $candLocal -TrunkBranch 'main')
Assert-Equal 2 $cands.Count 'only the PRs whose head branch is in this checkout are candidates'
Assert-Equal 1618 $cands[0].Number 'newest PR first -- the interrupted ship is the most recent thing this checkout did'
Assert-Equal 'fix/1616-go-ahead' $cands[0].Branch 'and the record carries the branch a resume would check out'
Assert-Equal 1601 $cands[1].Number 'the older candidate is kept rather than dropped'

Assert-Equal 0 @(Get-InterruptedShipCandidates -Json '[]' -LocalBranches $candLocal).Count 'no open PR -> no candidate'
Assert-Equal 0 @(Get-InterruptedShipCandidates -Json '' -LocalBranches $candLocal).Count 'empty payload -> no candidate (gh could not answer)'
Assert-Equal 0 @(Get-InterruptedShipCandidates -Json 'not json at all' -LocalBranches $candLocal).Count 'unparseable payload -> no candidate, never a throw beside a refusal'
Assert-Equal 0 @(Get-InterruptedShipCandidates -Json $candJson -LocalBranches @()).Count 'no local branch -> no candidate'
Assert-Equal 0 @(Get-InterruptedShipCandidates -Json $candJson -LocalBranches $null).Count 'and an unreadable branch list is the same answer'
# A field gh was never asked for is ABSENT, which is not empty under Set-StrictMode -- the shape that
# throws mid-refusal if it is read unguarded.
Assert-Equal 0 @(Get-InterruptedShipCandidates -Json '[{"number":1618}]' -LocalBranches $candLocal).Count 'a record with no headRefName is skipped, not read'
Assert-Equal 0 @(Get-InterruptedShipCandidates -Json '[{"headRefName":"feat/other"}]' -LocalBranches $candLocal).Count 'and one with no number cannot be named in a remedy, so it is skipped too'
Assert-Equal 0 @(Get-InterruptedShipCandidates -Json '[{"headRefName":"main","number":1618}]' -LocalBranches $candLocal -TrunkBranch 'main').Count 'a PR whose head IS the trunk is not a branch to check out'
# git ref names are case-sensitive, and a near-match is not the branch a resume would land on.
Assert-Equal 0 @(Get-InterruptedShipCandidates -Json '[{"headRefName":"FEAT/Other","number":1618}]' -LocalBranches $candLocal).Count 'the branch match is exact -- a differently-cased ref is a different ref'

Write-Host ""
Write-Host "Get-InterruptedShipResumeNote -- the wording the operator acts on (issue #1620)" -ForegroundColor Cyan
# THE DECISION AND ITS WORDING ARE SPLIT for the reason #1616 measured in ship-pr's go-ahead line: a
# sentence a reader is told to act on must be asserted, not trusted to a live ship.
Assert-Equal '' (Get-InterruptedShipResumeNote -Candidates @()) 'no candidate -> no note, so the refusal is the line it has always been'
Assert-Equal '' (Get-InterruptedShipResumeNote -Candidates $null) 'and a null list is the same answer'

$noteOne = Get-InterruptedShipResumeNote -Candidates @([pscustomobject]@{ Number = 1618; Branch = 'fix/1616-go-ahead'; Token = 'fix/1616-go-ahead'; Note = '' }) -TrunkBranch 'main'
Assert-True ($noteOne -like '*git checkout fix/1616-go-ahead*') 'the note prints the checkout that resumes the ship'
Assert-True ($noteOne -like '*PR #1618*') 'and names the PR the resume will land, so the reader can tell two candidates apart'
Assert-True ($noteOne -like '*issue #1073*') 'it names step 2b as the reason the checkout is on the trunk at all'
Assert-True ($noteOne -like '*RESUMES rather than starting over*') 'and says the re-run resumes, which is the fact that makes the command safe to run'
Assert-True ($noteOne -like "*'main'*") 'the trunk is named from the caller rather than assumed'
Assert-True ($noteOne.StartsWith("`n`n")) 'it opens with a blank line, so it cannot run into the refusal sentence it follows'
# NO FLAG IS PRESCRIBED. Whether a resume should skip the local gate is a separate question (#1620), and
# a remedy that answered it here would be this script deciding it by printing it.
Assert-True ($noteOne -notlike '*-SkipLint*') 'the remedy prescribes no gate skip -- that question is not this one'
Assert-True ($noteOne -notlike '*-SkipTests*') 'nor the test skip'

$noteTwo = Get-InterruptedShipResumeNote -Candidates @(
    [pscustomobject]@{ Number = 1618; Branch = 'fix/a'; Token = 'fix/a'; Note = '' },
    [pscustomobject]@{ Number = 1601; Branch = 'feat/b'; Token = 'feat/b'; Note = '' }
) -TrunkBranch 'main'
Assert-True ($noteTwo -like '*git checkout fix/a*') 'with two candidates both are listed -- the first'
Assert-True ($noteTwo -like '*git checkout feat/b*') 'and the second, because the note asks which one rather than picking'

# A REMEDY WHOSE FIRST LINE IS OFF THE SCREEN is the failure #1046 records for a warning printed at
# depth, so the list is capped and says how many it did not print.
# THE FIXTURE IS BUILT NEWEST-FIRST, which is what Get-InterruptedShipCandidates hands this function --
# this one does not re-sort, it takes the head of the list it was given. Built ascending, the assert
# below would be checking the wrong end of it.
$manyCands = @(7..1 | ForEach-Object { [pscustomobject]@{ Number = (1600 + $_); Branch = "fix/b$_"; Token = "fix/b$_"; Note = '' } })
$noteMany = Get-InterruptedShipResumeNote -Candidates $manyCands -MaxShown 5
Assert-True ($noteMany -like '*and 2 further open PR(s)*') 'over the cap, the note says how many candidates it did not list'
Assert-True ($noteMany -like '*git checkout fix/b7*') 'the newest candidate is listed'
Assert-True ($noteMany -notlike '*git checkout fix/b1*') 'and the ones it dropped are the tail of the list, not the head'

# THE PASTE VERDICT IS THE CALLER'S (ref-print-lib, #1594), and this note prints whatever token it was
# handed -- a head ref name is chosen by whoever opened the PR.
$notePaste = Get-InterruptedShipResumeNote -Candidates @([pscustomobject]@{ Number = 9; Branch = 'fix/evil;touch'; Token = '<branch>'; Note = '  NOTE: the branch name is not safe to paste' })
Assert-True ($notePaste -like '*git checkout <branch>*') 'a refused name reaches the command as the placeholder, never raw'
Assert-True ($notePaste -like '*not safe to paste*') 'and the note explaining it is printed under the whole list'
Assert-True ($notePaste -notlike '*checkout fix/evil;touch*') 'the raw name is never in a command line'
# A CALLER THAT FORGOT TO RESOLVE gets the placeholder too, rather than an unjudged ref in a command.
$noteNoToken = Get-InterruptedShipResumeNote -Candidates @([pscustomobject]@{ Number = 9; Branch = 'fix/x' })
Assert-True ($noteNoToken -like '*git checkout <branch>*') 'a record with no Token falls back to the placeholder, not to .Branch'

Write-Host ""
Write-Host "ship-pr.ps1's front door -- the refusal diagnoses instead of restating the rule (issue #1620)" -ForegroundColor Cyan
# The asserts above prove the two functions; these prove the caller asks for them. Same reasoning as the
# step-3b block below: a reverted call site leaves every assert above green while the refusal says
# nothing the operator can act on.
Assert-True ($shipText -like '*You are on main; ship-pr runs from a branch.$resumeNote*') 'the front-door refusal carries the resume note, and keeps the sentence it has always had'
Assert-True ($shipText -like '*Get-InterruptedShipCandidates -Json ($openPrList.Output -join*') 'it asks the tested function which open PR belongs to a branch in this checkout'
Assert-True ($shipText -like "*'--json', 'number,headRefName'*") 'asking gh for the two fields that function reads'
Assert-True ($shipText -like "*'for-each-ref', '--format=%(refname:short)', 'refs/heads'*") 'and git for the local half of the pair'
Assert-True ($shipText -like '*Get-PasteableRef -Ref $_.Branch*') 'each candidate name is judged before it reaches a printed command (#1594)'
Assert-True ($shipText -like '*Get-InterruptedShipResumeNote -Candidates $resumeCandidates*') 'and the wording comes from the tested function rather than a here-string here'
# BEST-EFFORT: an unreadable read yields no note, and the refusal is unchanged -- a diagnostic must never
# be the reason a refusal cannot be printed.
Assert-True ($shipText -like '*if ($openPrList.ExitCode -eq 0 -and $localHeads.ExitCode -eq 0) {*') 'both reads must succeed before anything is diagnosed'
Assert-True ($shipText -like '*$resumeNote = ''''*') 'and the note starts empty, so a gh that cannot answer leaves the original refusal'
Assert-True ($shipText -like '*further commit(s) landed in the same window and were discounted as folds*') 'and the refusal states the difference between its count and what git log shows'
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
