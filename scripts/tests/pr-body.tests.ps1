<#
.SYNOPSIS
    Regression tests for scripts/lib/pr-body-lib.ps1 (the PR-body description refresh).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Exit code 0 if everything passes, 1 on a
    failure -- so usable as a CI gate.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/pr-body.tests.ps1

    What this suite is for. open-pr.ps1 -RefreshBody rewrites the description of an ALREADY OPEN PR from
    the changelog entry. That is a write against a live PR body, so the failure that matters is not a
    crash but a WRONG REWRITE: half the old text left behind, an unrelated section swallowed, or -- the
    one measured on August 4, 2026 while doing this by hand -- an empty body published because a string
    operation silently produced $null. Every assert below exists to make one of those impossible.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\pr-body-lib.ps1')

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

Write-Host "Get-EntryDescription" -ForegroundColor Cyan

$entry = @'
### Some title - Feat - 2026-08-04

**The first paragraph.** With detail.

**The second paragraph.**
'@
Assert-Equal "**The first paragraph.** With detail.`n`n**The second paragraph.**" (Get-EntryDescription -EntryText $entry) 'everything after the heading, trimmed'

# Only the FIRST '###' is the heading. An entry whose prose carries further headings must not be cut
# short at one of them -- that returns something plausible instead of failing, the worst shape.
$deep = @'
### Title - Docs - 2026-08-04

Opening line.

### A heading inside the prose

Still part of the description.
'@
Assert-True ((Get-EntryDescription -EntryText $deep) -match 'Still part of the description') 'a later ### stays inside the description'
Assert-True ((Get-EntryDescription -EntryText $deep) -match 'A heading inside the prose') 'and the later heading itself is kept'

Assert-Equal '' (Get-EntryDescription -EntryText '') 'empty input -> empty string'
Assert-Equal '' (Get-EntryDescription -EntryText "No heading here at all.`nJust prose.") 'no heading -> empty string, so the caller can keep the placeholder'
Assert-Equal '' (Get-EntryDescription -EntryText '### Heading with nothing after it') 'a heading with no body -> empty string'
# CRLF is what a file read on Windows hands over; splitting on "`n" alone would leave a trailing "`r".
Assert-Equal 'Body line.' (Get-EntryDescription -EntryText "### T - Feat - 2026-08-04`r`n`r`nBody line.`r`n") 'CRLF input does not leave carriage returns behind'

Write-Host ""
Write-Host "Update-PrBodySection" -ForegroundColor Cyan

$body = @'
## What does this change do?
The old description.

## Type of change
- [x] `docs/` something

## Checklist
- [x] Entry created
'@

$changed = $false
$out = Update-PrBodySection -Body $body -Heading '## What does this change do?' -Content 'The NEW description.' -Changed ([ref]$changed)
Assert-True $changed                                  'a real change is reported as changed'
Assert-True ($out -match 'The NEW description\.')     'the new content is in'
Assert-True ($out -notmatch 'The old description')    'the old content is gone'
Assert-True ($out -match '(?m)^- \[x\] `docs/` something') 'the Type of change section survives untouched'
Assert-True ($out -match '(?m)^- \[x\] Entry created')     'the Checklist section survives untouched'
Assert-True ($out -match '(?ms)NEW description\.\s*\n## Type of change') 'exactly one blank line before the next section'

# The boundary is same-level-or-higher, NOT the next heading of any kind. A description containing its
# own deeper heading must be replaced whole; stopping at the deeper one would strand half the old text
# below the new -- a body that reads as though it says two different things.
$deepBody = @'
## What does this change do?
Old opening.

### An old sub-heading
Old detail that must also go.

## Type of change
- [x] `feat/`
'@
$changed = $false
$out2 = Update-PrBodySection -Body $deepBody -Heading '## What does this change do?' -Content 'Replacement.' -Changed ([ref]$changed)
Assert-True ($out2 -notmatch 'An old sub-heading')        'a deeper heading inside the section is replaced too'
Assert-True ($out2 -notmatch 'Old detail that must also go') 'and so is the text under it'
Assert-True ($out2 -match '(?m)^- \[x\] `feat/`')         'while the next same-level section is kept'

# A '##' inside a fence is not a boundary. Not hypothetical: an entry documenting this very feature
# writes the heading it is explaining.
$fenced = @'
## What does this change do?
Old.

## Type of change
- [x] `feat/`
'@
$withFence = @"
Replacement that explains itself:

``````markdown
## Type of change
``````

Done.
"@
$changed = $false
$out3 = Update-PrBodySection -Body $fenced -Heading '## What does this change do?' -Content $withFence -Changed ([ref]$changed)
Assert-True ($out3 -match '(?m)^- \[x\] `feat/`')  'the real Type of change section is still there after a fenced copy of its heading'
Assert-True ($out3 -match 'Done\.')               'the content after the fence is kept'

# A body that already says exactly this must not be rewritten -- the caller skips the API call, so a
# rerun produces no PR activity at all.
$same = Update-PrBodySection -Body $body -Heading '## What does this change do?' -Content 'The old description.' -Changed ([ref]$changed)
Assert-Equal $body $same 'identical content leaves the body byte-identical'
Assert-True (-not $changed) 'and reports no change, so no pr edit is sent'

# A heading that is not present is not an error: the body comes back untouched and unchanged.
$changed = $false
$absent = Update-PrBodySection -Body $body -Heading '## Not in this template' -Content 'x' -Changed ([ref]$changed)
Assert-Equal $body $absent 'an absent heading leaves the body alone'
Assert-True (-not $changed) 'and reports no change'

# THE MEASURED FAILURE, asserted directly: on August 4, 2026 a hand-written refresh published an EMPTY
# body because a failed string operation passed $null on. Whatever else these functions do, they must
# never turn a non-empty body into nothing.
$changed = $false
Assert-Equal $body (Update-PrBodySection -Body $body -Heading '## What does this change do?' -Content '' -Changed ([ref]$changed)) 'empty replacement content leaves the body untouched rather than emptying the section'
Assert-True (-not $changed) 'and is reported as no change, so nothing is sent'
Assert-Equal '' (Update-PrBodySection -Body '' -Heading '## Any' -Content 'x') 'an empty body in stays empty out (nothing to update)'

# The last section in the body has no following heading, so it must not gain a trailing blank line.
$tail = "## Intro`nkeep`n`n## Last section`nold tail"
$changed = $false
$outTail = Update-PrBodySection -Body $tail -Heading '## Last section' -Content 'new tail' -Changed ([ref]$changed)
Assert-Equal "## Intro`nkeep`n`n## Last section`nnew tail" $outTail 'replacing the final section adds no trailing blank line'

# CRLF bodies keep their line endings: gh returns whatever the PR has, and rewriting a CRLF body with LF
# would show up as a whole-body diff on GitHub.
# NB the section text below carries no backtick on purpose: inside a double-quoted PowerShell string a
# backtick starts an escape, and '`f' is a FORM FEED -- which is a parse error here, not a literal.
$crlf = "## What does this change do?`r`nOld.`r`n`r`n## Type of change`r`n- [x] feat branch"
$outCrlf = Update-PrBodySection -Body $crlf -Heading '## What does this change do?' -Content 'New.'
Assert-True ($outCrlf.Contains("`r`n")) 'a CRLF body stays CRLF'
Assert-True (-not ($outCrlf -match "[^`r]`n")) 'and gains no bare LF line endings'

# --- -StopAtHeading: an H1 description must not swallow the form below it (inbound #598) -----------
Write-Host "-StopAtHeading (the H1 description's missing boundary)" -ForegroundColor Cyan
# THE MEASURED FAILURE. Since the PR template was promoted to an H1, the description heading is level 1 --
# and "the next heading at the same level or shallower" can only ever match another H1. So every '##'
# section below it was inside the description, and -RefreshBody replaced the lot while reporting that it
# had updated the description. A consumer lost its one repo-specific section, heading, guidance comment and
# a ticked checkbox, on every run, on a repo whose CLAUDE.md requires that box to be answered before merge.
$h1Body = @'
# What does the change on this branch bring to main?

The old description.

## Preview - specific to this repo

<!-- Tick one before merging. -->
- [x] n/a - this branch touches no theme file
'@
$h1Heading = '# What does the change on this branch bring to main?'
$h1Stop    = '## Preview - specific to this repo'

# First the defect itself, asserted so nobody "simplifies" the parameter away later: WITHOUT the stops the
# old behaviour is still there, and it is still wrong. This assert is the bug, kept executable.
$changed = $false
$unbounded = Update-PrBodySection -Body $h1Body -Heading $h1Heading -Content 'The new description.' -Changed ([ref]$changed)
Assert-True ($unbounded -notmatch 'Preview - specific') 'H1: the level rule ALONE still loses the section -- which is why the boundary has to be passed in'

$changed = $false
$bounded = Update-PrBodySection -Body $h1Body -Heading $h1Heading -Content 'The new description.' -StopAtHeading @($h1Stop) -Changed ([ref]$changed)
Assert-True ($bounded -match 'The new description\.')       'H1: the description is replaced'
Assert-True ($bounded -notmatch 'The old description\.')    'H1: and the old text is gone'
Assert-True ($bounded -match [regex]::Escape($h1Stop))      'H1: while the form section below it survives -- the whole point'
Assert-True ($bounded -match '\[x\] n/a')                   'H1: including the answer somebody had ticked by hand'
Assert-True ($bounded -match 'Tick one before merging')     'H1: and its guidance comment'
Assert-True $changed                                        'H1: and the edit is reported, so it is actually sent'

# NARROWING ONLY, which is what makes the parameter safe to add to a function three paths already call.
# Passing nothing, passing an empty list, and passing a heading the body does not contain must all be
# byte-identical to the behaviour before this parameter existed.
$base = Update-PrBodySection -Body $deepBody -Heading '## What does this change do?' -Content 'Replacement.'
Assert-Equal $base (Update-PrBodySection -Body $deepBody -Heading '## What does this change do?' -Content 'Replacement.' -StopAtHeading @()) 'narrowing-only: an empty stop list changes nothing'
Assert-Equal $base (Update-PrBodySection -Body $deepBody -Heading '## What does this change do?' -Content 'Replacement.' -StopAtHeading @('## Nowhere in this body')) 'narrowing-only: a stop heading the body lacks changes nothing'
Assert-Equal $base (Update-PrBodySection -Body $deepBody -Heading '## What does this change do?' -Content 'Replacement.' -StopAtHeading @('', '   ', $null)) 'narrowing-only: blank entries in the list are ignored rather than matching a blank line'

# THE ORIGINAL REASONING MUST STILL HOLD, and this is the assert that stops the fix overshooting into
# "stop at the next heading of any kind": a description legitimately contains its own deeper headings, and
# stopping at the first of those would strand half the old description below the new one.
$changed = $false
$nested = Update-PrBodySection -Body $deepBody -Heading '## What does this change do?' -Content 'Replacement.' -StopAtHeading @('## Type of change') -Changed ([ref]$changed)
Assert-True ($nested -notmatch 'An old sub-heading')  'stops: a deeper heading that is NOT a stop is still part of the section'
Assert-True ($nested -notmatch 'Old detail')          'stops: and so is the text under it'
Assert-True ($nested -match '(?m)^- \[x\] `feat/`')   'stops: while the named stop section is kept'

# Fence-aware like every other boundary here: a description explaining the form quotes the form's headings.
$fencedStop = "# Desc`n`nExplaining the form:`n`n``````text`n$h1Stop`n``````" + "`n`nStill description.`n`n$h1Stop`n`n- [x] done`n"
$changed = $false
$outFencedStop = Update-PrBodySection -Body $fencedStop -Heading '# Desc' -Content 'New desc.' -StopAtHeading @($h1Stop) -Changed ([ref]$changed)
Assert-True ($outFencedStop -notmatch 'Still description') 'stops: a quoted stop heading inside a fence is not the boundary'
Assert-True ($outFencedStop -match '\[x\] done')           'stops: the real section after the fence is still kept'

# The earliest boundary wins, whichever kind it is -- so a same-level heading before a named stop still ends
# the section, and a named stop before a same-level heading does too.
$order = "# Desc`n`nold`n`n## Stop B`n`nb`n`n# Another H1`n`nc`n"
$outOrder = Update-PrBodySection -Body $order -Heading '# Desc' -Content 'new' -StopAtHeading @('## Stop B')
Assert-True ($outOrder -match '(?m)^## Stop B')     'earliest boundary: the named stop wins when it comes first'
Assert-True ($outOrder -match '(?m)^# Another H1')  'earliest boundary: and the later H1 is untouched'

# --- Get-LostBodyHeadings: a section loss is said out loud (inbound #598) --------------------------
Write-Host "Get-LostBodyHeadings (the tripwire for a silent section loss)" -ForegroundColor Cyan
Assert-Equal 1 @(Get-LostBodyHeadings -Before $h1Body -After $unbounded).Count 'a swallowed section is reported as lost'
Assert-Equal $h1Stop @(Get-LostBodyHeadings -Before $h1Body -After $unbounded)[0] 'and the finding names it, which is what the reporter could not get from the output'
Assert-Equal 0 @(Get-LostBodyHeadings -Before $h1Body -After $bounded).Count 'the FIXED refresh loses nothing -- so this stays quiet in the normal case'

# A SHORTER BODY IS NOT A LOST SECTION, which is the whole reason the subject is headings rather than size.
# Every refresh whose new description is shorter than the old one shrinks the body, and a rule that fired on
# that would be switched off inside a week.
$shorter = Update-PrBodySection -Body $h1Body -Heading $h1Heading -Content 'Tiny.' -StopAtHeading @($h1Stop)
Assert-True ($shorter.Length -lt $h1Body.Length) 'a shorter description really does shrink the body'
Assert-Equal 0 @(Get-LostBodyHeadings -Before $h1Body -After $shorter).Count 'and that is not reported -- the subject is a missing heading, not a smaller body'

# Fence-aware on both sides, so a heading only ever QUOTED in the old body is not mourned as lost.
$quoted = "# Desc`n`n``````text`n## Never a real section`n``````" + "`n"
Assert-Equal 0 @(Get-LostBodyHeadings -Before $quoted -After "# Desc`n`nnew").Count 'a heading that was only quoted inside a fence was never a section'

# The degenerate inputs, since this runs immediately before a live 'gh pr edit'.
Assert-Equal 0 @(Get-LostBodyHeadings -Before '' -After '').Count 'two empty bodies lose nothing'
Assert-Equal 0 @(Get-LostBodyHeadings -Before 'no headings at all' -After '').Count 'a body with no headings cannot lose one'
Assert-Equal 1 @(Get-LostBodyHeadings -Before "## Only`ntext" -After '').Count 'and losing everything is still one lost heading, not a crash'

# --- The LEADING section: a body whose description has no heading (issue #865) ---------------------
#
# WHAT THIS IS FOR. The PR template lost its H1 on August 24, 2026, because the DEPLOY section it
# mirrored had stopped naming its own answer the day before. -RefreshBody anchored on that heading, so
# without this shape the switch degrades to its warning branch on every run -- the whole feature lost and
# reported as "the description was left as it is", which reads like a decision rather than a miss. That
# degradation is the one this suite has caught twice before (the '^##' pattern in August 2026, then the
# missing boundary in #598), so it is asserted directly rather than left to open-pr.
Write-Host ""
Write-Host "Update-PrBodySection -- the leading section, for a template with no heading" -ForegroundColor Cyan

# NO FORM HEADINGS AT ALL: the leading section is the whole body. That is this repo's own template, and
# it is byte-identical in effect to what the H1 anchor did, since nothing followed it.
$leadChanged = $false
$leadOut = Update-PrBodySection -Body "old description`nover two lines" -Heading '' -Content 'the new answer' -Changed ([ref]$leadChanged)
Assert-True $leadChanged 'a heading-less body is rewritable, which is the whole point of the shape'
Assert-Equal 'the new answer' $leadOut 'and with no form heading the leading section is the entire body'

# A FORM HEADING STILL BOUNDS IT, passed in exactly as open-pr passes the template's own later headings.
# This is the half that #598 was filed about, arrived at from the other side: the level rule cannot help
# here at all, because nothing is shallower than no heading.
$boundChanged = $false
$boundOut = Update-PrBodySection -Body "old description`n`n## Checklist`n- [ ] a box" -Heading '' `
    -Content 'the new answer' -StopAtHeading @('## Checklist') -Changed ([ref]$boundChanged)
Assert-True $boundChanged 'the leading section is rewritten with a form section below it'
Assert-True ($boundOut -match '(?m)^the new answer$')     'and the description is replaced'
Assert-True ($boundOut -match '(?m)^## Checklist$')       'while the form heading survives'
Assert-True ($boundOut -match '(?m)^- \[ \] a box$')      'and so does what a reviewer answered under it'
Assert-True (-not ($boundOut -match 'old description'))   'and the old description is gone rather than left above it'

# NO HEADING IS WRITTEN BACK. The description carries its own sections (the significance sub-heading is
# one), and inventing a heading over them would put a level in the body that no document asked for.
Assert-True (-not ($boundOut -match '(?m)^#{1,6}\s+the new answer')) 'no heading line is invented over the leading section'

# A LEGACY BODY NEEDS NO LEGACY STRING, which is the reasoning behind open-pr adding none for #865: an
# old H1 sits inside the leading section, so it is replaced along with everything else.
$legacyLead = $false
$legacyOut = Update-PrBodySection -Body "# What does the change on this branch deploy to main?`n`nold text" `
    -Heading '' -Content 'the new answer' -Changed ([ref]$legacyLead)
Assert-True $legacyLead 'a PR opened under the retired H1 is still refreshable'
Assert-True (-not ($legacyOut -match 'deploy to main')) 'and the retired heading goes with the text it introduced'

# THE GUARDS STILL HOLD IN THIS MODE, both of them, because this is the path that runs straight into a
# live 'gh pr edit'. Empty content is a no-op rather than an instruction to clear the body -- the
# August 4, 2026 measurement -- and an empty body has nothing to rewrite.
$noopChanged = $true
Assert-Equal 'keep me' (Update-PrBodySection -Body 'keep me' -Heading '' -Content '' -Changed ([ref]$noopChanged)) 'empty content leaves a heading-less body alone'
Assert-True (-not $noopChanged) 'and reports no change, so no pr edit is sent'
Assert-Equal '' (Update-PrBodySection -Body '' -Heading '' -Content 'anything') 'an empty body is returned as it is'

# AND A NON-EMPTY HEADING WITH NO '#' IS STILL REFUSED. That is a caller mistake rather than the leading
# section, and conflating the two would make every typo silently rewrite the top of the body.
Assert-Equal "text`nmore" (Update-PrBodySection -Body "text`nmore" -Heading 'not a heading' -Content 'new') 'a heading with no hash is still refused rather than read as leading'

# --- Get-PrTitle: the PR title is composed, not typed (#506 + #505) -------------------------------
# The whole point of the change is that these two facts cannot drift apart, so the asserts are about
# COMPOSITION and about the shapes that would produce a nameless or malformed PR.
Write-Host ""
Write-Host "Get-PrTitle -- the type from the branch, the words from the entry" -ForegroundColor Cyan

Assert-Equal 'fix: the release runs the suites' (Get-PrTitle -Prefix 'fix' -TitleWords 'the release runs the suites') 'the prefix and the words are joined with one colon and one space'
Assert-Equal 'feat: a thing' (Get-PrTitle -Prefix 'feat' -TitleWords "  a thing  ") 'surrounding whitespace is trimmed off both halves'

# A title reaches `gh pr create --title` as ONE argument; a newline in it is not a formatting nicety.
Assert-Equal 'docs: first line only' (Get-PrTitle -Prefix 'docs' -TitleWords "first line only`nand a second paragraph") 'a multi-line section yields the first non-empty line'
Assert-Equal 'docs: after the blanks' (Get-PrTitle -Prefix 'docs' -TitleWords "`n`n  after the blanks`nmore") 'leading blank lines are skipped rather than winning'
Assert-Equal 'fix: two spaces collapse' (Get-PrTitle -Prefix 'fix' -TitleWords "two   spaces collapse") 'inner whitespace is collapsed to single spaces'

# '' is how open-pr says "this branch prefix is not in the table". Inventing a type there would state
# something no table backs -- the PR is labelled 'question' for exactly that reason.
Assert-Equal 'words alone' (Get-PrTitle -Prefix '' -TitleWords 'words alone') 'an empty prefix yields the words without a type'

# EMPTY IN, EMPTY OUT -- and open-pr turns that into a refusal naming the entry, rather than handing
# `gh` a bare '--title ""' to complain about a flag.
Assert-Equal '' (Get-PrTitle -Prefix 'fix' -TitleWords '') 'no words means no title, not a bare prefix'
Assert-Equal '' (Get-PrTitle -Prefix 'fix' -TitleWords "   `n  `n") 'a whitespace-only section is no title either'

# THE COMPOSER STILL DOUBLES, PINNED ON PURPOSE (#936). This is the defect PR #934 shipped, and the repair
# is a refusal in open-pr rather than a strip here -- so an assert that the doubling still happens is what
# stops somebody "fixing" it in this function and leaving the entry, which is the copy CHANGELOG.md keeps,
# quietly wrong. Delete this assert only together with the title gate.
Assert-Equal 'fix: fix: the fallback drops the paragraph' (Get-PrTitle -Prefix 'fix' -TitleWords 'fix: the fallback drops the paragraph') 'a prefixed title still composes to a doubled one -- the gate refuses it, this function does not strip it'

# --- Get-PrTitlePrefixFinding: the title gate's reader (#936) --------------------------------------
# Nothing fed Get-PrTitle words that already carried a prefix until PR #934 did it in production, which
# is the gap these asserts close. The finding is the matched text, so the refusal can quote it back.
Write-Host ""
Write-Host "Get-PrTitlePrefixFinding -- the entry's title already carries the branch's type" -ForegroundColor Cyan

Assert-Equal 'fix:' (Get-PrTitlePrefixFinding -Prefix 'fix' -TitleWords 'fix: the fallback drops the paragraph') 'the branch prefix on the title is reported, as the text that was matched'
Assert-Equal 'fix:' (Get-PrTitlePrefixFinding -Prefix 'fix' -TitleWords 'fix:no space after the colon') 'the space after the colon is not what makes it a prefix'
Assert-Equal 'fix :' (Get-PrTitlePrefixFinding -Prefix 'fix' -TitleWords 'fix : spaced out') 'whitespace before the colon does not hide it either'
Assert-Equal 'Fix:' (Get-PrTitlePrefixFinding -Prefix 'fix' -TitleWords 'Fix: capitalised like a sentence') 'the match is case-insensitive -- a capitalised first word is the same mistake'

# BOUNDED TO THE BRANCH'S OWN PREFIX, which is the whole reason this is safe to refuse on. A stripper
# guessing at any '<word>:' is what the composer above deliberately did not build, and these three are the
# titles it would have mangled.
Assert-Equal '' (Get-PrTitlePrefixFinding -Prefix 'fix' -TitleWords 'sync-roster: the ignore list is empty') 'a legitimate colon-carrying title is not a finding'
Assert-Equal '' (Get-PrTitlePrefixFinding -Prefix 'fix' -TitleWords 'docs: written on the wrong branch') 'ANOTHER type prefix is not this branch prefix -- the gate reports only what would be doubled'
Assert-Equal '' (Get-PrTitlePrefixFinding -Prefix 'fix' -TitleWords 'fixture loading is broken') 'a word that merely STARTS with the prefix is not a prefix -- the colon is required'

# THE SAME NORMALISATION AS THE TITLE, because the gate must judge the string that ships. These two shapes
# are what Get-PrTitle would pick, and the finding has to see them the same way.
Assert-Equal 'feat:' (Get-PrTitlePrefixFinding -Prefix 'feat' -TitleWords "`n`n  feat: after the blanks`nmore") 'the first non-empty line is judged, not the raw section'
Assert-Equal 'feat:' (Get-PrTitlePrefixFinding -Prefix '  feat  ' -TitleWords 'feat: a padded prefix argument') 'the prefix argument is trimmed, as the composer trims it'

# NO PREFIX, NO DOUBLING, NO FINDING. open-pr passes '' for a branch whose prefix the table does not know,
# and the composer then writes the words alone -- so there is nothing to report even when they carry a colon.
Assert-Equal '' (Get-PrTitlePrefixFinding -Prefix '' -TitleWords 'fix: on an unknown branch prefix') 'an empty prefix is never a finding, because nothing is composed in front'
Assert-Equal '' (Get-PrTitlePrefixFinding -Prefix 'fix' -TitleWords '') 'no words is no finding -- the empty title is the scaffold gate to report, not this one'
Assert-Equal '' (Get-PrTitlePrefixFinding -Prefix 'fix' -TitleWords "   `n  `n") 'a whitespace-only section is no finding either'

# --- Get-PrDescription: the PR body is the answer onwards, not the whole dossier --------------------
#
# The three sections it drops are answered by the PAGE around the body -- Branch title IS the PR title,
# Branch ID is a creation timestamp, Branch type is the label -- and the one it drops at the end is
# filled by the FOLD, so it is empty in every PR body by construction. Kept: the answer and Significance,
# because how far a change reaches and what it is worth is what a reviewer is deciding about.
Write-Host "Get-PrDescription -- the PR body starts at the answer" -ForegroundColor Cyan
$dossier = @'
## `fix/x` changelog

### Branch title

A short title

### Branch ID

20260809-113542

### Branch type

fix

### What does the change on this branch bring to main?

The real answer.

### Significance

#### Tier 0

Because of this.

**Score:** 3

### Pull Request

'@
$prDesc = Get-PrDescription -EntryText $dossier
Assert-True ($prDesc -match '(?m)^The real answer\.$')      'the answer is carried'
Assert-True ($prDesc -match '(?m)^## Significance$')        'Significance is kept -- it is what a reviewer decides about'
Assert-True ($prDesc -match '(?m)^\*\*Score:\*\* 3$')       'and its scores come with it'
Assert-True ($prDesc -notmatch 'A short title')             'the Branch title is dropped -- it IS the PR title, shown above the body'
Assert-True ($prDesc -notmatch '20260809-113542')           'the Branch ID is dropped -- a timestamp a reviewer cannot act on'
Assert-True ($prDesc -notmatch '(?m)^### Branch type$')     'the Branch type section is dropped -- it is the PR label'
Assert-True ($prDesc -notmatch '(?m)^### Pull Request$')    'the Pull Request section is dropped -- the fold fills it, so it is always empty here'
Assert-True ($prDesc -notmatch 'What does the change on this branch bring to main') 'the heading itself is dropped -- the template carries it, so it cannot appear twice'

# PROMOTED ONE LEVEL (Dave, August 9, 2026). The entry's sections are H3 and its tiers H4 because the
# entry is an H2 inside CHANGELOG.md; a PR body is a document of its own, whose title GitHub prints
# above it. Carried across unchanged, a body started at H2 with tiers at H4 -- the shape of a fragment.
Assert-True ($prDesc -match '(?m)^## Significance$')  'Significance is promoted from H3 to H2'
Assert-True ($prDesc -match '(?m)^### Tier 0$')       'and the tier from H4 to H3'
Assert-True ($prDesc -notmatch '(?m)^### Significance$') 'the original H3 level is gone, not merely duplicated'
Assert-True ($prDesc -notmatch '(?m)^#### ')          'nothing in the body is left at H4'

# THE FENCE CASE, which is not hypothetical: the entry documenting this change quotes these headings
# inside a fence. Cutting at a fenced heading would return plausible half-output rather than failing.
$fenced = @'
## `fix/y` changelog

### What does the change on this branch bring to main?

Before the fence.

```text
### Pull Request
### Significance
```

After the fence.

### Pull Request

'@
$fencedDesc = Get-PrDescription -EntryText $fenced
Assert-True ($fencedDesc -match '(?m)^After the fence\.$') 'a fenced heading does not end the description'
Assert-True ($fencedDesc -match '(?m)^### Pull Request$')  'and the fenced quote itself survives inside the body'
# The promotion must not reach inside a fence either: a fenced heading is SAMPLE TEXT, and an entry
# explaining this format would have its own example silently rewritten to say something else.
Assert-True ($fencedDesc -match '(?m)^### Significance$')  'a heading inside a fence keeps its level -- it is a quote, not a section'

# BACK-COMPAT: a pre-dossier entry has no such section, and '' is how this says so -- open-pr then falls
# back to Get-EntryDescription, which is the behaviour every consumer with a branch in flight has today.
$preDossier = "### Old entry - Feat - 2026-07-01`n`nJust a paragraph.`n"
Assert-Equal '' (Get-PrDescription -EntryText $preDossier) 'a pre-dossier entry yields "" so the caller can fall back'
Assert-True ((Get-EntryDescription -EntryText $preDossier) -match 'Just a paragraph') 'and the fallback still reads it whole'
Assert-Equal '' (Get-PrDescription -EntryText '') 'empty in, empty out -- no throw'

# The retired heading is read too, for the standing reason: entries carrying it exist in every consumer.
$retired = "## ``fix/z`` changelog`n`n### What does this change do?`n`nOld-style answer.`n"
Assert-True ((Get-PrDescription -EntryText $retired) -match 'Old-style answer') 'the retired section name is still recognised'

# THE MERGED FORMAT: the entry's opening text sits under the DEPLOY heading with no 'What' section at
# all, so the DEPLOY heading IS the start of the answer (inbound #853). Before this, the function
# returned '' here and the caller fell back to Get-EntryDescription -- whose "first '### '" heuristic
# lands INSIDE the body under this shape and returned about a quarter of it, opening argument gone,
# in a PR body that looked complete and passed every gate. So the assert that matters is not only that
# the opening survives, but that it beats what the fallback would have produced.
$merged = @"
## DEPLOY: ``fix/thing-v1`` * 20260824-101500

The opening argument, which is the substance a reviewer decides on.

**Score:** 3

### What makes this PR extra special

The tier-2 answer.

**Score:** 2

### Pull Request

The PR title line
"@
$mergedDesc = Get-PrDescription -EntryText $merged
Assert-True ($mergedDesc -match 'The opening argument')      'the merged format keeps the entry opening text -- the defect #853 reported'
Assert-True ($mergedDesc -match 'The tier-2 answer')         'and the significance section, which is what a reviewer is deciding about'
Assert-True (-not ($mergedDesc -match 'The PR title line'))  'and still stops at the Pull Request section, which the fold fills'
# THE HEADING TRAVELS AND NOTHING IS PROMOTED, on this path (Dave, issue #884, August 25, 2026). Both
# asserts are the previous two INVERTED rather than deleted, which is the honest record of a reversal:
# until this issue the heading was dropped and every remaining one moved up a level, on the reasoning
# that a PR body is a document of its own and needs a title. It has one now -- its own -- and the lock
# needs body and document to be the same text rather than two renderings of it.
Assert-True ($mergedDesc -match '(?m)^## DEPLOY: `fix/thing-v1` \* 20260824-101500$') 'the DEPLOY heading travels with its section, verbatim'
Assert-True ($mergedDesc -match '(?m)^### What makes this PR extra special$') 'and the sections keep the levels the document gave them -- nothing is promoted here'
Assert-True (-not ($mergedDesc -match '(?m)^## What makes')) 'so no section is flattened up into the heading above it'
Assert-True ($mergedDesc.Length -gt (Get-EntryDescription -EntryText $merged).Length) 'and it carries MORE than the fallback would have, which is the whole finding'

# The legacy DEPLOY shape -- branch first, title last -- is matched by the same pattern, so a consumer
# with a branch in flight under the previous heading gets the repair too rather than the old tail.
$legacyDeploy = @"
## ``fix/legacy-v1`` DEPLOY

Legacy-shaped opening text.

### What makes this deploy extra special

Tier two.

### Pull Request
"@
Assert-True ((Get-PrDescription -EntryText $legacyDeploy) -match 'Legacy-shaped opening text') 'the previous DEPLOY heading shape starts the answer too'

# WHERE BOTH SHAPES ARE PRESENT the author's own 'What' heading wins, because a merged-format entry
# still carrying that section is hand-edited or transitional -- and the heading a person wrote is a
# better answer than the one the scaffolder did.
$both = @"
## DEPLOY: ``fix/both-v1`` * 20260824-101500

Scaffolded opening, not the author's answer.

### What does the change on this branch deploy to main?

The author's own answer.
"@
$bothDesc = Get-PrDescription -EntryText $both
Assert-True ($bothDesc -match "The author's own answer")            'a What section present in a merged entry still wins'
Assert-True (-not ($bothDesc -match 'Scaffolded opening'))          'and the text above it is not swept in'

# THE LEGACY PATH STILL PROMOTES, which is the half of the August 9, 2026 transform #884 did NOT reverse.
# Its argument is untouched here: an entry found by its 'What' heading leaves its own H2 behind, so its H3
# sections really would arrive in a PR body as a fragment of something larger. Consumers have branches in
# flight under this shape and meet this code through a plugin update rather than by choosing to.
$legacyPromote = @"
## ``fix/promote-v1`` changelog

### What does this change do?

The answer.

#### A sub-heading inside the body
"@
$legacyPromoteDesc = Get-PrDescription -EntryText $legacyPromote
Assert-True ($legacyPromoteDesc -match '(?m)^### A sub-heading inside the body$') 'the legacy path still promotes one level -- H4 arrives as H3'
Assert-True (-not ($legacyPromoteDesc -match 'DEPLOY')) 'and it carries no heading of its own, because there was none to carry'

# --- Test-DeployLock: is the open PR body still carrying this document's DEPLOY section? --------------
# THE LOCK (Dave, issue #884). The section is fixed when the PR opens, because the PR body is what the
# review approved and the fold turns the document into CHANGELOG.md. These asserts are the contract both
# callers depend on -- ship-pr before the merge, and check-branch-entry in CI.
$lockEntry = @"
## DEPLOY: ``fix/lock-v1`` * 20260825-120000

The opening argument.

**Score:** 3

### What makes this deploy extra special

Tier two.

**Score:** 2

### Pull Request

A title
"@
$lockPublished = Get-PrDescription -EntryText $lockEntry

$lockSame = Test-DeployLock -EntryText $lockEntry -PrBody $lockPublished
Assert-True $lockSame.Applicable      'a merged-format entry with a published body is something the lock can judge'
Assert-True $lockSame.Locked          'and an unchanged section is locked'
Assert-Equal '' $lockSame.FirstDrift  'with no drift line to report'

# CONTAINMENT, NOT EQUALITY, because a consumer's PR template may wrap the section -- open-pr splices the
# description into that template rather than replacing the whole body.
$lockWrapped = Test-DeployLock -EntryText $lockEntry -PrBody ("Some template preamble.`n`n" + $lockPublished + "`n`nA template footer.")
Assert-True $lockWrapped.Locked 'a section wrapped by a template is still locked -- the test is containment'

# CRLF IS WHAT A ROUND TRIP THROUGH GITHUB ACTUALLY RETURNS, so it is normalised. Nothing else is: case,
# punctuation and heading levels are all real edits to a section that is supposed to be closed.
$lockCrlf = Test-DeployLock -EntryText $lockEntry -PrBody ($lockPublished -replace "`n", "`r`n")
Assert-True $lockCrlf.Locked 'a body that came back CRLF is still the same section'

# ONE EDITED LINE IS THE CASE THE MESSAGE EXISTS FOR: "the section is gone" and "somebody rewrote its
# second paragraph" need different answers, which is why the search anchors on the heading first.
$lockEdited = Test-DeployLock -EntryText ($lockEntry -replace 'The opening argument\.', 'A different argument entirely.') -PrBody $lockPublished
Assert-True (-not $lockEdited.Locked) 'a document edited after the PR opened is not locked'
Assert-Equal 'A different argument entirely.' $lockEdited.FirstDrift 'and the finding names the first line the body does not have'

$lockGone = Test-DeployLock -EntryText $lockEntry -PrBody 'A body with no section in it at all.'
Assert-True (-not $lockGone.Locked) 'a body that does not carry the section is not locked'
Assert-Equal $lockGone.Heading $lockGone.FirstDrift 'and the drift line IS the heading, which is how a caller tells the two cases apart'

# NOT APPLICABLE IS A THIRD ANSWER, and both callers treat it as no finding. Locked stays $true on those
# so a caller that reads only that field cannot refuse a merge over a question that was never asked.
$lockLegacy = Test-DeployLock -EntryText $legacyPromote -PrBody $legacyPromoteDesc
Assert-True (-not $lockLegacy.Applicable) 'an entry with no DEPLOY heading has no section to lock'
Assert-True $lockLegacy.Locked            'and reports Locked so a caller reading one field cannot refuse over it'

Assert-True (-not (Test-DeployLock -EntryText $lockEntry -PrBody '').Applicable)  'an empty body is nothing to hold the document against yet'
Assert-True (-not (Test-DeployLock -EntryText '' -PrBody $lockPublished).Applicable) 'and an empty document is nothing to hold'

# THE TWO HALVES OF #884 MEET HERE, which is the assert worth having above all the others: the lock is a
# plain containment test ONLY because Get-PrDescription stopped transforming the section. Had the heading
# promotion stayed, this comparison would have had to reproduce it -- so this asserts the property rather
# than the implementation, and it fails the moment either half is reverted alone.
Assert-True ($lockPublished -match '(?m)^## DEPLOY: `fix/lock-v1` \* 20260825-120000$') 'what the PR publishes opens with the document own heading'
Assert-True ($lockEntry -match [regex]::Escape(($lockPublished -split "`n")[0])) 'and that heading is the document own line, verbatim, not a rendering of it'

# A DEPLOY heading inside a FENCE is a quote, not the start of the answer -- this very entry format is
# documented by entries that quote it, and firing there would return the explanation as the description.
$fencedDeploy = @"
### What does the change on this branch deploy to main?

Real answer.

``````markdown
## DEPLOY: ``fix/quoted-v1`` * 20260824-101500
``````
"@
Assert-True ((Get-PrDescription -EntryText $fencedDeploy) -match 'Real answer') 'a fenced DEPLOY heading is a quote and does not start the answer'

# --- The template and open-pr must agree on the description placeholder (#538) ----------------------
#
# THE ONE COUPLING IN THIS MECHANISM THAT FAILS SILENTLY. open-pr fills the PR body by replacing a
# placeholder LINE from .github/pull_request_template.md with the changelog entry, matched by exact
# string equality against a list inside open-pr.ps1. If someone edits the template's comment -- a
# typo fix, a reworded hint, a stray trailing space -- the match stops firing and the PR is opened
# with the placeholder still in it and no description at all. Nothing errors: the template is valid
# markdown, the script exits 0, and the loss is visible only to whoever reads the published body.
#
# Measured need: the template was rewritten on 2026-08-09 (#538) down to a single section, which is
# exactly the kind of edit that breaks this without anyone looking. Asserted from BOTH files rather
# than from a constant here, so this suite cannot agree with itself while the repo disagrees.
Write-Host "template <-> open-pr placeholder agreement" -ForegroundColor Cyan
$repoRootForTemplate = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$templateFile = Join-Path $repoRootForTemplate '.github\pull_request_template.md'
$openPrFile   = Join-Path $repoRootForTemplate 'scripts\release\open-pr.ps1'

Assert-True (Test-Path -LiteralPath $templateFile) 'the PR template exists where open-pr looks for it'
Assert-True (Test-Path -LiteralPath $openPrFile)   'open-pr.ps1 exists where this suite looks for it'

$templateLinesForTest = @(Get-Content -LiteralPath $templateFile -Encoding UTF8)
$openPrText           = [System.IO.File]::ReadAllText($openPrFile, [System.Text.Encoding]::UTF8)

# A placeholder is an HTML comment on its own line -- the shape open-pr replaces wholesale.
$placeholderLines = @($templateLinesForTest | Where-Object { $_.Trim() -match '^<!--.*-->$' })
Assert-True ($placeholderLines.Count -ge 1) 'the template carries at least one comment line to substitute'

# The load-bearing assert: at least one of them is VERBATIM in the recognised list. This was a substring
# search over open-pr.ps1's own text until August 10, 2026, because the three literals lived inline in
# that script and there was nothing else to ask. Since #573 moved them into this lib the assert can call
# the list instead of grepping for it -- the same test, now performing the same whole-line comparison
# open-pr performs rather than an approximation of it.
$matched = @($placeholderLines | Where-Object { @(Get-PrDescriptionPlaceholderDefaults) -contains $_.Trim() })
Assert-True ($matched.Count -ge 1) 'open-pr recognises the template placeholder verbatim -- otherwise every PR body loses its description, silently'

# WHERE THE DESCRIPTION LIVES IS DECIDED BY THE PLACEHOLDER'S POSITION, NOT BY THE FIRST HEADING
# (issue #865). Until August 24, 2026 this asserted that the template HAD a heading, because -RefreshBody
# replaced the description under the first one and a template with none degraded to "the description was
# left as it is" on every run -- a silent loss of the whole feature, worded as a decision. That heading is
# gone: the DEPLOY section it mirrored stopped naming its own answer, so the description is the body's
# LEADING section here. The assert is therefore inverted rather than deleted -- this template must have no
# heading ABOVE its placeholder, which is what makes the leading path the one open-pr takes.
$tplPlaceholderAt = -1
$tplHeadingAboveAt = -1
for ($i = 0; $i -lt $templateLinesForTest.Count; $i++) {
    if ($tplPlaceholderAt -lt 0 -and (@(Get-PrDescriptionPlaceholderDefaults) -contains $templateLinesForTest[$i].Trim())) { $tplPlaceholderAt = $i }
    if ($tplPlaceholderAt -lt 0 -and $tplHeadingAboveAt -lt 0 -and $templateLinesForTest[$i] -match '^#{1,6}\s+\S') { $tplHeadingAboveAt = $i }
}
Assert-True ($tplPlaceholderAt -ge 0)   'the placeholder is found by the same whole-line comparison open-pr uses'
Assert-True ($tplHeadingAboveAt -lt 0)  'and no heading sits above it, so this template hands open-pr the leading-section path'
# KEYED ON THE PATTERN, NOT ON HOW THE LINES ARE ENUMERATED. This asserted the whole
# "Where-Object { $_ -match ... }" expression until inbound #598 made the read fence-aware and multi-heading,
# at which point a correct change failed a test that was watching the wrapper instead of the rule. The rule
# is that the level is not fixed; the loop around it is open-pr's business.
Assert-True ($openPrText -match "'\^#\{1,6\}\\s\+\\S'") 'and open-pr looks for a heading at any level, not just H2'
# AND THAT IT SPLITS THEM ON THE PLACEHOLDER. Two variables carry the answer -- what sits above it is the
# description's heading, what sits below it is the form's boundary -- and a refactor that dropped either
# would put the description back under whatever heading came first, which for a heading-less template
# means overwriting the form's own first section on every refresh.
Assert-True ($openPrText -match '\$tplSeenPlaceholder') 'and it decides the split on where the placeholder sits'
# THE SECOND HALF OF THE SAME READ (inbound #598): the headings AFTER the first are the description's
# boundary, and open-pr must pass them on. Without this the H1 description has no boundary at all and every
# later section is replaced along with it -- which is exactly what shipped.
Assert-True ($openPrText -match 'StopAtHeading \$templateStops') 'and it hands the template''s later headings to the section writer as the boundary'

# THE FALLBACK THAT KEEPS OLDER PRs REFRESHABLE. -RefreshBody targets whatever heading the template
# names today; a PR opened before a rename carries the previous one in its published body, and
# Update-PrBodySection returns the body untouched when it cannot find a heading -- so without a
# fallback such a PR reports "already matches the entry" while matching nothing. Pinned here because
# the strings are the whole mechanism: they are not derivable from anything, only remembered.
Assert-True ($openPrText.Contains('## What does this change do?')) 'open-pr still recognises the pre-#538 description heading, so a PR opened under it stays refreshable'
Assert-True ($openPrText.Contains('## Changelog entry')) 'and the one-day-old heading between them, for PRs opened on August 9, 2026'
Assert-True ($openPrText.Contains('## What does the change on this branch bring to main?')) 'and the H2 form of the current wording, which was live for a single day'
foreach ($legacy in @('## What does the change on this branch bring to main?', '## Changelog entry', '## What does this change do?', '## Wat doet deze wijziging?')) {
    $legacyBody = "$legacy`nold text`n`n## Resolved issues`nCloses #1"
    $didChange = $false
    $out = Update-PrBodySection -Body $legacyBody -Heading $legacy -Content 'new text' -Changed ([ref]$didChange)
    Assert-True $didChange "a body under '$legacy' is rewritable"
    Assert-True ($out -match '(?m)^new text$') "and the new description lands under '$legacy'"
    Assert-True ($out -match '(?m)^Closes #1$') "while the resolved-issues block below '$legacy' is untouched"
}

# ---------------------------------------------------------------------------------------------------
Write-Host "The placeholder list and the reference template cannot disagree (#573)" -ForegroundColor Cyan
#      The whole reason those two moved into this lib: while the strings lived inline in open-pr.ps1,
#      nothing else could read them, so the reference template the plugin ships could not be held against
#      the list that has to recognise it. These asserts are that guarantee, stated rather than assumed.
$known = @(Get-PrDescriptionPlaceholderDefaults)
Assert-True ($known.Count -ge 3) 'the recognised placeholder list still carries the legacy strings, not just the current one'
Assert-True ($known -contains '<!-- Korte beschrijving van wat er verandert en waarom. -->') `
    'the Dutch legacy placeholder is still recognised -- consumer templates carry it right now'
Assert-True ($known -contains '<!-- Short description of what changes and why. -->') `
    'the English legacy placeholder is still recognised'

# THE PRE-RENAME FOLDER NAME, AND THIS IS THE ASSERT #952 WAS MISSING. The rename in #886 rewrote the
# four strings carrying the folder name rather than appending to them, which inverted the list: an
# UNMIGRATED consumer is by definition still carrying 'workflow-davekjohn' in their template, so the
# strings kept for them were the four that stopped matching them. Measured in smartwatchbanden before
# migration: 0 hits. Nothing asserted it -- the issue named branch-info.tests.ps1 as the suite that
# caught it, and that suite has no placeholder assert at all; this file's asserts above cover only the
# two pre-folder strings, which the rename did not touch. So the guarantee is stated per rename, on the
# form actually shipped in a template, rather than on the list as a whole.
foreach ($legacyFolderForm in @(
    "<!-- Filled from workflow-davekjohn/branch/branch-changelog.md. Opening a PR by hand? Paste that file's body here. -->",
    "<!-- Filled from workflow-davekjohn/branch/branch-deployment.md. Opening a PR by hand? Paste that file's body here. -->",
    "<!-- Filled from the DEPLOY section of workflow-davekjohn/development-cycle.md. Opening a PR by hand? Paste that section's body here. -->",
    "<!-- Filled from the DEPLOY section of workflow-davekjohn/development-cycle.md, heading and all. Opening a PR by hand? Paste that whole section here, starting at its '## DEPLOY:' line. -->"
)) {
    Assert-True ($known -contains $legacyFolderForm) `
        "the pre-#886 folder name is still recognised, so an unmigrated consumer's template is still filled in: '$legacyFolderForm'"
}

# AND THE RULE THE ABOVE IS AN INSTANCE OF, asserted structurally so the NEXT rename cannot pass by
# substitution either. The list is append-only, so a form that exists under the OLD folder name must
# still exist under the new one: that is the direction #886 broke.
#
# ONE DIRECTION ONLY, AND THIS ASSERT LEARNED IT THE DAY AFTER IT WAS WRITTEN. It was symmetric for a
# few hours -- every folder-naming form had to exist under BOTH names -- and #963/#958 broke it
# immediately and correctly: renaming the document to development.md appends
# 'contributing-davekjohn/development.md', and there is no 'workflow-davekjohn/development.md' to pair
# it with, because the folder was renamed on August 26 and the document on August 27. That pair never
# existed, so demanding it would force a name into the list that nothing can ever have written -- which
# is a different way of making the list lie about history. The asymmetry IS the rule: old implies new,
# never the reverse.
$oldFolderForms = @($known | Where-Object { $_ -match 'workflow-davekjohn' })
Assert-True ($oldFolderForms.Count -ge 4) 'the pre-#886 folder name still carries all four of its forms'
foreach ($f in $oldFolderForms) {
    $migrated = $f -replace 'workflow-davekjohn', 'contributing-davekjohn'
    Assert-True ($known -contains $migrated) `
        "and each has its counterpart under the current folder name -- a rename appends, it never replaces: '$migrated'"
}

# AND THE SAME RULE FOR EVERY OTHER RENAME, WHICH THE LOOP ABOVE CANNOT REACH (issue #1262,
# September 3, 2026). That loop keys on the FOLDER rename -- it derives the migrated form from the
# pre-#886 one -- so it can only speak for strings that have a 'workflow-davekjohn' partner. The
# DOCUMENT renames have none, by the asymmetry stated above, and #1255 walked straight through the
# gap: it REPLACED 'dkj-policy/development.md' with the per-branch form instead of
# appending, which is the #952 defect a second time, and every suite stayed green.
#
# So the history is pinned here as a set, and the assert is a superset test rather than an equality.
# Appending a form -- what a rename is supposed to do -- needs no edit here; REMOVING one is the only
# thing that fails, which is exactly the direction that keeps breaking. The strings are not derivable
# from anything, only remembered, so they are written out in full like the legacy headings above.
$publishedForms = @(
    '<!-- Korte beschrijving van wat er verandert en waarom. -->',
    '<!-- Short description of what changes and why. -->',
    "<!-- Filled from branch/branch-changelog.md. Opening a PR by hand? Paste that file's body here. -->",
    "<!-- Filled from workflow-davekjohn/branch/branch-changelog.md. Opening a PR by hand? Paste that file's body here. -->",
    "<!-- Filled from workflow-davekjohn/branch/branch-deployment.md. Opening a PR by hand? Paste that file's body here. -->",
    "<!-- Filled from the DEPLOY section of workflow-davekjohn/development-cycle.md. Opening a PR by hand? Paste that section's body here. -->",
    "<!-- Filled from the DEPLOY section of workflow-davekjohn/development-cycle.md, heading and all. Opening a PR by hand? Paste that whole section here, starting at its '## DEPLOY:' line. -->",
    "<!-- Filled from dkj-policy/branch/branch-changelog.md. Opening a PR by hand? Paste that file's body here. -->",
    "<!-- Filled from dkj-policy/branch/branch-deployment.md. Opening a PR by hand? Paste that file's body here. -->",
    "<!-- Filled from the DEPLOY section of dkj-policy/development-cycle.md. Opening a PR by hand? Paste that section's body here. -->",
    "<!-- Filled from the DEPLOY section of dkj-policy/development-cycle.md, heading and all. Opening a PR by hand? Paste that whole section here, starting at its '## DEPLOY:' line. -->",
    "<!-- Filled from the DEPLOY section of dkj-policy/development.md, heading and all. Opening a PR by hand? Paste that whole section here, starting at its '## DEPLOY:' line. -->"
)
foreach ($published in $publishedForms) {
    Assert-True ($known -contains $published) `
        "a form this family has published is still recognised -- the list is append-only: '$published'"
}
# THE ONE THE PER-BRANCH RENAME DROPPED, named on its own line as well, because a loop reports the
# string and not the reason. 'dkj-policy/development.md' was the WRITTEN placeholder from
# August 27 to September 3, 2026, so it is what every template scaffolded in that week carries right
# now -- in this repo and in every consumer that adopted a release in it. Unrecognised, their PR
# bodies lose their description silently, which is the outcome this whole list exists to prevent.
Assert-True ($known -contains "<!-- Filled from the DEPLOY section of dkj-policy/development.md, heading and all. Opening a PR by hand? Paste that whole section here, starting at its '## DEPLOY:' line. -->") `
    'the pre-#1255 shared-document form is still recognised, so a template scaffolded that week is still filled in'
# THE WRITTEN ONE IS THE LAST ONE, asserted here rather than trusted, because Get-PrTemplateCanonicalPlaceholder
# takes it by position and every rename appends. A form added in the wrong place silently changes which
# placeholder a fresh template is scaffolded with, and nothing else would notice.
Assert-Equal $known[$known.Count - 1] (Get-PrTemplateCanonicalPlaceholder) `
    'the canonical placeholder is the last entry, so an appended form did not land mid-list'
# THE CURRENT FILENAME CARRIES THE BRANCH SINCE #1255, so the placeholder names the SHAPE rather than a
# literal path -- a template is scaffolded once and read on every branch, so it cannot name one branch's
# document. The assert follows the shape for the same reason it followed the name before: to catch a
# placeholder left describing a document that no longer exists.
Assert-True ((Get-PrTemplateCanonicalPlaceholder) -match 'dkj-policy/<branch>\.md') `
    'and it names the document by its current filename shape'
# THE PRE-#1335 FORM IS STILL RECOGNISED, and that is the append-only rule this list exists for: a template
# scaffolded on the day the prefix went is still carrying it, and dropping the form is exactly the defect
# #952 measured -- a rewrite that left the tolerated set matching only the repos needing no tolerance.
Assert-True ($known -contains "<!-- Filled from the DEPLOY section of dkj-policy/development-<branch>.md, heading and all. Opening a PR by hand? Paste that whole section here, starting at its '## DEPLOY:' line. -->") `
    'the pre-#1335 prefixed form is still recognised'

$canonical = Get-PrTemplateCanonicalPlaceholder
Assert-True ($known -contains $canonical) `
    'the placeholder that gets WRITTEN is one of the ones that gets RECOGNISED'

$reference = @(Get-PrTemplateReference)
Assert-True (@($reference | Where-Object { $known -contains $_ }).Count -eq 1) `
    'the reference template carries exactly one recognised placeholder line -- the defect #573 reported was a template carrying none'
# AND IT CARRIES NO HEADING (issue #865). The reference is the answer this family hands a consumer, and
# the shape it hands out has to be the shape open-pr's leading path expects: a placeholder with nothing
# above it. Asserted in the negative on purpose -- the two asserts this replaces required a heading, which
# is exactly the contract #865 retired, so leaving them would have made the gate refuse the shipped answer.
Assert-True (@($reference | Where-Object { $_ -match '^#{1,6}\s+\S' }).Count -eq 0) `
    'the reference template carries no heading -- the description is the body leading section'
Assert-True ($reference[0] -eq (Get-PrTemplateCanonicalPlaceholder)) `
    'and its first line is the placeholder itself, so nothing precedes the description'

# The shipped file on disk, not just the function: a reference nobody can copy is not a reference. The
# lint gate holds these byte for byte; this asserts the file exists at the path the docs send people to.
$refOnDisk = Join-Path $PSScriptRoot '..\..\plugins\dkj-policy\templates\pull_request_template.md'
Assert-True (Test-Path -LiteralPath $refOnDisk) `
    'the reference template is actually shipped at the path the skill and CONTRIBUTING-portable name'
if (Test-Path -LiteralPath $refOnDisk) {
    $refText = ([System.IO.File]::ReadAllText($refOnDisk, [System.Text.Encoding]::UTF8)) -replace "`r`n", "`n"
    Assert-True ($refText.TrimEnd() -eq (($reference -join "`n").TrimEnd())) `
        'and its contents are what Get-PrTemplateReference says they are'
}

# --- Get-ExemptBranchTitleWords: the branch that owes no entry still needs a name (#1962) ----------
# The entry-exempt branch was the one shape open-pr could not name a PR for: the title came from the
# entry and nothing else (#506), and such a branch has no entry by design. These asserts pin the
# precedence, because getting it backwards would let -Title override an entry-bearing branch's title,
# which is exactly what #506 removed.
Write-Host ""
Write-Host "Get-ExemptBranchTitleWords -- an explicit title, else the branch's own commit subject" -ForegroundColor Cyan

Assert-Equal 'mirror the live theme' `
    (Get-ExemptBranchTitleWords -CommitSubjects @('mirror the live theme')) `
    'a single commit subject is the title words'
Assert-Equal 'sync: mirror in-flight third-party edits from live (47 file(s))' `
    (Get-ExemptBranchTitleWords -CommitSubjects @('sync: mirror in-flight third-party edits from live (47 file(s))', 'fix a typo in the mirror')) `
    'the OLDEST subject wins -- the caller passes them oldest-first, and the opening commit is what the branch was cut for'
Assert-Equal 'the real work' `
    (Get-ExemptBranchTitleWords -CommitSubjects @('   ', '', 'the real work')) `
    'blank subjects are skipped rather than winning as an empty title'
Assert-Equal 'told, not guessed' `
    (Get-ExemptBranchTitleWords -Title 'told, not guessed' -CommitSubjects @('mirror the live theme')) `
    '-Title beats the commit subject, which is the whole reason it is honoured here'
Assert-Equal 'trimmed' `
    (Get-ExemptBranchTitleWords -Title '   trimmed   ') `
    'an explicit title is trimmed'
Assert-Equal 'the commit' `
    (Get-ExemptBranchTitleWords -Title '   ' -CommitSubjects @('the commit')) `
    'a whitespace-only -Title is no title at all and falls through to the subject'
Assert-Equal '' (Get-ExemptBranchTitleWords) `
    'nothing to name it after yields the empty string, which the caller refuses on rather than shipping'
Assert-Equal '' (Get-ExemptBranchTitleWords -CommitSubjects @()) `
    'an empty commit list is the same answer -- a branch with no commit of its own off the trunk'

# COMPOSED, NOT COMPOSING. This function returns WORDS; Get-PrTitle still owns the type prefix and the
# first-line rule. A sync/ prefix is not in the branch table, so open-pr passes '' and the subject
# travels through unchanged -- including its own 'sync:' opener, which is not a doubling because no
# type was put in front of it.
Assert-Equal 'sync: mirror in-flight third-party edits from live' `
    (Get-PrTitle -Prefix '' -TitleWords (Get-ExemptBranchTitleWords -CommitSubjects @('sync: mirror in-flight third-party edits from live'))) `
    'an unknown prefix leaves the commit subject as the whole title'
Assert-Equal '' `
    (Get-PrTitlePrefixFinding -Prefix '' -TitleWords (Get-ExemptBranchTitleWords -CommitSubjects @('sync: mirror in-flight third-party edits from live'))) `
    'and the title gate cannot fire on it either, since there is no branch type for it to double'

# --- The local DEPLOY default and the real matcher must not drift apart ---------------------------
# Get-PrDescription reads the DEPLOY heading through Get-DevelopmentEntryPattern when the scaffold
# lib is loaded, and through a local default when it is not -- which is the state this suite runs in, on
# purpose. Two readers of one rule is how this repo's accumulation bugs start, so the two are held
# against each other here rather than trusted to stay equal.
#
# LOADED LAST, deliberately: dot-sourcing the scaffold lib replaces the heading-name defaults this whole
# file has been asserting against, so doing it earlier would change what every assert above measures.
Write-Host ""
Write-Host "the DEPLOY default agrees with the real matcher" -ForegroundColor Cyan

$defaultMerged = Get-PrDescription -EntryText $merged
$defaultLegacy = Get-PrDescription -EntryText $legacyDeploy
$defaultFenced = Get-PrDescription -EntryText $fencedDeploy

. (Join-Path $PSScriptRoot '..\lib\entry-scaffold-lib.ps1')
Assert-True (Test-FunctionDefined 'Get-DevelopmentEntryPattern') `
    'the real matcher is reachable once the scaffold lib is loaded'
Assert-Equal $defaultMerged (Get-PrDescription -EntryText $merged)       'the two readers agree on today DEPLOY shape'
Assert-Equal $defaultLegacy (Get-PrDescription -EntryText $legacyDeploy) 'and on the previous one'
Assert-Equal $defaultFenced (Get-PrDescription -EntryText $fencedDeploy) 'and on a fenced quote of it, which neither may fire on'

# --- The gate-bypass section (issue #2361) -------------------------------------------------------------
# The record a -SkipLint/-SkipTests run owes the PR body, written by open-pr instead of by a hand edit of
# the body the DEPLOY lock reads. Pinned: the line's shape, idempotence, a second bypass appended rather
# than replacing the first, the section's level following the body, a fenced quote not being the section,
# survival across a refresh that dropped it, and the lock still holding once the section is there.
# Lists are compared JOINED: Assert-Equal's -eq filters an array on its left rather than comparing it.
Write-Host ""
Write-Host "the gate-bypass section (#2361)" -ForegroundColor Cyan
$bpTick = [string][char]0x60
Assert-Equal '' (New-GateBypassLine -Skipped '' -Reason 'why') 'bypass: nothing skipped means no line, whatever the reason says'
$bpNoReason = New-GateBypassLine -Skipped '-SkipTests' -Reason ''
Assert-Equal ('- ' + $bpTick + '-SkipTests' + $bpTick + ' -- no reason recorded (pass -BypassNote to give one)') $bpNoReason 'bypass: a missing reason is said, and names the parameter that records one'
$bpTwo = New-GateBypassLine -Skipped '-SkipLint and -SkipTests' -Reason "suite hangs`n## forged"
Assert-Equal ('- ' + $bpTick + '-SkipLint' + $bpTick + ' and ' + $bpTick + '-SkipTests' + $bpTick + ' -- suite hangs ## forged') $bpTwo 'bypass: both switches named, and a newline in the reason cannot forge a heading'

$bpBody = "### DEPLOY: feat/x`n`nThe change.`n`n**Score:** 1"
$bp1 = Add-GateBypassLines -Body $bpBody -Lines @($bpNoReason)
Assert-True ($bp1 -match '(?m)^### Gate bypass$') 'bypass: the section takes the body''s own top level (H3 here), so a refresh cannot swallow it as a child'
Assert-True ($bp1.StartsWith($bpBody)) 'bypass: the body above the section is left exactly as it was'
Assert-Equal $bpNoReason (@(Get-GateBypassLines -Body $bp1) -join '|') 'bypass: the reader returns the line the writer wrote'
Assert-Equal $bp1 (Add-GateBypassLines -Body $bp1 -Lines @($bpNoReason)) 'bypass: the same line again is a no-op, byte for byte'
Assert-Equal $bpBody (Add-GateBypassLines -Body $bpBody -Lines @('', $null)) 'bypass: nothing to add returns the body untouched'

$bp2 = Add-GateBypassLines -Body $bp1 -Lines @($bpTwo)
Assert-Equal 1 ([regex]::Matches($bp2, '(?m)^#{1,6} Gate bypass$').Count) 'bypass: a second bypass does not open a second section'
Assert-Equal (@($bpNoReason, $bpTwo) -join '|') (@(Get-GateBypassLines -Body $bp2) -join '|') 'bypass: it is appended beneath the first, which stays on record'

$bpMid = "### DEPLOY: feat/x`n`nThe change.`n`n### Gate bypass`n`n$bpNoReason`n`n### Resolved issues`n`nCloses #1"
$bpMid2 = Add-GateBypassLines -Body $bpMid -Lines @($bpTwo)
Assert-Equal (@($bpNoReason, $bpTwo) -join '|') (@(Get-GateBypassLines -Body $bpMid2) -join '|') 'bypass: a section followed by another gets the new line inside it, above the next heading'
Assert-True ($bpMid2.IndexOf($bpTwo) -lt $bpMid2.IndexOf('### Resolved issues')) 'bypass: the new line lands before the next section, not at the foot of the body'
Assert-True ($bpMid2 -match '(?m)^Closes #1$') 'bypass: and the section below it is untouched'

$bpFence = $bpTick * 3
$bpFenced = "### DEPLOY: feat/x`n`n$bpFence" + "text`n### Gate bypass`n- quoted`n$bpFence"
Assert-Equal 0 @(Get-GateBypassLines -Body $bpFenced).Count 'bypass: a fenced quote of the section is not the section'

# A refresh that rewrote everything below a leading description: the caller reads the lines first and
# puts them back, which is what open-pr's existing-PR path does.
$bpPrior = @(Get-GateBypassLines -Body $bp2)
$bpRefreshed = Add-GateBypassLines -Body $bpBody -Lines $bpPrior
Assert-Equal (@($bpNoReason, $bpTwo) -join '|') (@(Get-GateBypassLines -Body $bpRefreshed) -join '|') 'bypass: lines read before a refresh are restored after it'

# FOUND IN REVIEW: a -SkipTests -NoResolves run leaves the headingless no-resolves marker directly under
# the section, and a reader running to the next heading swept it in -- so the next refresh would have
# welded it into the section as a bypass line.
. (Join-Path $PSScriptRoot '..\lib\pr-issues-lib.ps1')
$bpMarked = Add-NoResolvesMarker -Body $bp1
Assert-Equal $bpNoReason (@(Get-GateBypassLines -Body $bpMarked) -join '|') 'bypass: the no-resolves marker below a body-final section is not read as one of its lines'
$bpMarked2 = Add-GateBypassLines -Body $bpMarked -Lines (@(Get-GateBypassLines -Body $bpMarked) + @($bpTwo))
Assert-True ($bpMarked2.TrimEnd().EndsWith((Get-NoResolvesMarker))) 'bypass: and a later run inserts above the marker, which stays at the foot of the body'
Assert-Equal (@($bpNoReason, $bpTwo) -join '|') (@(Get-GateBypassLines -Body $bpMarked2) -join '|') 'bypass: with exactly the two bypass lines in the section'

$bpCrlf = $bpMid -replace "`n", "`r`n"
$bpCrlf2 = Add-GateBypassLines -Body $bpCrlf -Lines @($bpTwo)
Assert-Equal 0 ([regex]::Matches($bpCrlf2, "(?<!`r)`n").Count) 'bypass: an insert into a CRLF body keeps every line ending CRLF'
$bpTight = "### DEPLOY: feat/x`n`n### Gate bypass`n`n$bpNoReason`n### Resolved issues`n`nCloses #1"
Assert-True ((Add-GateBypassLines -Body $bpTight -Lines @($bpTwo)) -match ([regex]::Escape($bpTwo) + "`n`n### Resolved issues")) 'bypass: a heading straight after the section gets its blank line back'

$bpLockBody = Add-GateBypassLines -Body (Get-PrDescription -EntryText $merged) -Lines @($bpTwo)
$bpLock = Test-DeployLock -EntryText $merged -PrBody $bpLockBody
Assert-True ($bpLock.Applicable -and $bpLock.Locked) 'bypass: the DEPLOY lock still holds with the section appended -- it tests containment'

Write-Host ""
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
