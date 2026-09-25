<#
.SYNOPSIS
    Regression tests for scripts/release/new-internal-note.ps1 -- the third release tier's skeleton
    generator (releases/internal/<dir>/<X.Y.Z>.md, for colleagues and management).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Integration style: the REAL script runs against a
    throwaway fixture repo, so nothing here touches a real release. Run as a CHILD PROCESS, because the
    script calls 'exit' on its refusal paths and would otherwise abort this runner.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/internal-note.tests.ps1

    What is asserted, in the order a failure is most usefully diagnosed:
      1. the refusals (no developer notes, an existing note without -Force) -- both are the paths that
         protect written text, so they matter more than the happy path;
      2. the skeleton's shape: the metadata copied from the developer notes, the three fixed headings,
         and the entry titles carried over WITHOUT their internal metadata;
      3. the folder scheme, which must follow Get-ReleaseNotesGrouping rather than a scheme of its own;
      4. the wording seam -- the document is read by a given repo's colleagues, so every string in it
         must be overridable (#410 class).

    Pure ASCII (repo convention for .ps1); the middot in an entry heading is built from its codepoint.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot  = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$ScriptSrc = Join-Path $RepoRoot 'scripts\release\new-internal-note.ps1'

# JUDGING THIS SUITE'S OWN FIXTURE CHILD -- issues #1934 and #1954. This suite copies new-internal-note.ps1
# and the libs it dot-sources into a fixture tree, so a copy list that has gone stale kills the child
# during LOAD and the asserts below then read a note nothing wrote.
. (Join-Path $PSScriptRoot '..\lib\fixture-script-lib.ps1')

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

$midDot = [char]0x00B7
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

function New-Fixture {
    <#
        A throwaway repo root with the script copied in, optionally carrying developer notes and an
        optional repo-config.ps1. Not a git repo on purpose: -RepoRoot is passed explicitly, which is
        exactly the path the script documents for the test suite, and it keeps the fixture cheap.
    #>
    param(
        [Parameter(Mandatory)][string]$Label,
        [string]$NotesDir = '3.x',
        [string]$Version = '3.2.0',
        # DELIBERATELY UNTYPED, both of them. A [string] parameter converts $null to '', so
        # '$null -ne $NotesContent' would be TRUE for an omitted argument and this fixture would write an
        # EMPTY notes file -- which made the "no developer notes" refusal look broken while the script was
        # correct (measured: run by hand it exits 1 and writes nothing). The absent case has to stay
        # distinguishable from the empty-string case, so no type constraint here.
        $NotesContent = $null,
        $RepoConfig = $null,
        # Where the tier-0 notes are PLANTED, repo-root-relative with forward slashes. Defaults to the
        # computed answer every other fixture here relies on. A test that repoints the seam has to plant
        # the notes where it repointed them, or it asserts the refusal rather than the seam (issue #947).
        [string]$NotesRoot = 'dkj-policy/releases/changelog'
    )
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) "internal-note-test-$PID-$Label-$([guid]::NewGuid().ToString('n'))"
    if (Test-Path -LiteralPath $dir) { Remove-Item -Recurse -Force -LiteralPath $dir }
    New-Item -ItemType Directory -Path (Join-Path $dir 'scripts\release') -Force | Out-Null
    Copy-Item -LiteralPath $ScriptSrc -Destination (Join-Path $dir 'scripts\release\new-internal-note.ps1') -Force
    # release-lib.ps1 travels along because the script dot-sources it for Set-ReleaseInternalNoteLink
    # (August 4, 2026), which repoints the changelog's release block at the note this script creates.
    # Copied rather than made optional in the script: a missing lib must fail loudly, not silently skip
    # the changelog update and leave the release pointing at the developer notes forever.
    New-Item -ItemType Directory -Path (Join-Path $dir 'scripts\lib') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\release-lib.ps1') `
        -Destination (Join-Path $dir 'scripts\lib\release-lib.ps1') -Force
    # entry-scaffold-lib.ps1 travels along because release-lib dot-sources it for the changelog's tier
    # sections (August 5, 2026). Copied for the same reason as release-lib itself: a missing sibling must
    # fail loudly here rather than in someone's release.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\entry-scaffold-lib.ps1') `
        -Destination (Join-Path $dir 'scripts\lib\entry-scaffold-lib.ps1') -Force
    # ref-print-lib.ps1 is one layer further again, and it arrived on #1650: entry-scaffold-lib.ps1
    # dot-sources it for Get-DisplayRef, so the sentence above applies to it verbatim -- a missing sibling
    # fails loudly here rather than in someone's release, and this is what loudly looked like.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\ref-print-lib.ps1') `
        -Destination (Join-Path $dir 'scripts\lib\ref-print-lib.ps1') -Force
    # plugin-tree-lib.ps1 travels along for the same reason one layer further: release-lib dot-sources it
    # for the plugin set (August 9, 2026), so it is a sibling of a sibling and the fixture owes it too.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\plugin-tree-lib.ps1') `
        -Destination (Join-Path $dir 'scripts\lib\plugin-tree-lib.ps1') -Force
    # seam-lib.ps1 (issue #885, group A/E): the script now dot-sources this unconditionally, the same way
    # it already does for release-lib.ps1 and its own siblings above -- a missing copy must fail loudly
    # here, not silently in someone's release.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\seam-lib.ps1') `
        -Destination (Join-Path $dir 'scripts\lib\seam-lib.ps1') -Force
    # command-probe-lib.ps1 is a sibling of a sibling (#1729): the three libs above dot-source it for
    # Test-FunctionDefined, so the fixture owes it exactly as it owes ref-print-lib.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\command-probe-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\command-probe-lib.ps1') -Force
    # repo-root-lib.ps1 likewise (#2115): check-report-lib.ps1 resolves the repo root through
    # Get-GitTopLevelPath, which lives there. UNGUARDED in that lib, deliberately -- it is mirrored
    # beside it into every plugin that carries it, so a payload missing it is broken rather than old.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\repo-root-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\repo-root-lib.ps1') -Force
    # check-report-lib.ps1 likewise (#2271): the script now dot-sources it unconditionally for
    # Format-SafeProseToken, which strips the foreign text out of the exception message its
    # repo-config catch PRINTS. It dot-sources repo-root-lib.ps1 and nothing else, and that one is
    # already copied just above -- for this very lib, on #2115.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\check-report-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\check-report-lib.ps1') -Force
    # document-newline-lib.ps1 likewise (#1832): entry-scaffold-lib.ps1 and pr-body-lib.ps1 dot-source it
    # for Get-DocumentNewline, unconditionally and for the same reason -- so the fixture owes it too.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\document-newline-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\document-newline-lib.ps1') -Force
    # fetch-attempt-lib.ps1 likewise (#1860): entry-scaffold-lib.ps1 dot-sources it for
    # Invoke-RecordedRemoteFetch, which Get-TrunkGap's fetch runs through -- so the fixture owes it too.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\fetch-attempt-lib.ps1') -Destination (Join-Path $dir 'scripts\lib\fetch-attempt-lib.ps1') -Force
    # .claude-plugin/marketplace.json (issue #885) is still written, but it no longer decides where the
    # note LANDS. Get-DefaultReleaseInternalNotesRoot branched on it until issue #998 (August 27, 2026),
    # which retired the source branch from this default the same way #914 retired it from the tier-0
    # one -- so both the note this fixture WRITES and the changelog notes it READS now sit inside
    # dkj-policy/, and the assertions below say so. THE MIXED SHAPE IS GONE, and its absence
    # is the point: the fixture matches this repo's own tree, which states this seam at
    # dkj-policy/releases/internal. The manifest stays because the fixture is still a source
    # repo for every other purpose, and because a fixture that quietly stops being one would hide which
    # of these behaviours actually depends on it -- the answer, since #998, being none of them.
    New-Item -ItemType Directory -Path (Join-Path $dir '.claude-plugin') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $dir '.claude-plugin\marketplace.json'), '{}', $Utf8NoBom)
    if ($null -ne $NotesContent) {
        $notesPath = Join-Path $dir (($NotesRoot -replace '/', '\') + "\$NotesDir\$Version.md")
        New-Item -ItemType Directory -Path (Split-Path -Parent $notesPath) -Force | Out-Null
        [System.IO.File]::WriteAllText($notesPath, $NotesContent, $Utf8NoBom)
    }
    if ($null -ne $RepoConfig) {
        [System.IO.File]::WriteAllText((Join-Path $dir 'scripts\repo-config.ps1'), $RepoConfig, $Utf8NoBom)
    }
    return $dir
}

function Invoke-Script {
    param([string]$Dir, [string[]]$ExtraArgs = @(), [string]$Version = '3.2.0')
    # $psArgs, NOT $args: inside a function $args is an AUTOMATIC variable holding the caller's own
    # arguments, so assigning to it and splatting the result silently passes something else entirely --
    # measured here as the no-notes refusal appearing to exit 0. Costs nothing to avoid, invisible if not.
    $psArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
        (Join-Path $Dir 'scripts\release\new-internal-note.ps1'),
        '-Version', $Version, '-RepoRoot', $Dir) + $ExtraArgs
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        # Kept as records, so both readings are available: Out preserves the line structure, Flat is
        # the wrap-proof one every phrase assert in this suite uses.
        $captured = @(& powershell @psArgs 2>&1)
        $code = $LASTEXITCODE
        # #1934: a load failure is not a refusal -- say so before the asserts read a note nothing wrote.
        Assert-FixtureScriptLoaded -Code $code -Script (Join-Path $Dir 'scripts\release\new-internal-note.ps1') -Output $captured
        return [pscustomobject]@{
            Out  = ($captured | Out-String)
            Flat = (Get-FlatOutput $captured)
            Code = $code
        }
    } finally { $ErrorActionPreference = $prevEap }
}

function Get-FlatOutput {
    <#
        Captured child output as ONE line: every record read as text, then joined with nothing between.
        FOR PHRASE ASSERTS ONLY -- it deliberately glues genuinely separate lines together, which is
        harmless for a substring match (it can only create a match spanning two real lines, never
        destroy one) and wrong for anything that cares about line structure. Test-Line below is the
        other half of this pair: whole-line asserts go through it, against the generated document.

        WHY THIS SUITE NEEDS IT (issue #959). new-internal-note.ps1 reports through Write-Warning, and
        the child WRAPS those at its own host width -- a point that moves with the console width AND
        with the length of the fixture's temp path, which is interpolated into the message and which
        neither this suite nor the script decides. So 'fill in the date by hand' arrives split as
        'the da + te by hand' and the regex misses: red on a developer console, green in CI, for a
        script that is correct in both places. Measured red here at 300 columns and green at 120, so
        the wrap point is not a margin anybody can stay ahead of by keeping the message short.

        Read as text rather than rendered with Out-String, and joined with '' rather than a space --
        both are load-bearing, and prune-merged.tests.ps1's copy carries the full reasoning: Out-String
        FORMATS each record, landing a paragraph of PowerShell decoration between the two halves of a
        wrapped sentence, and the wrap is a HARD break at a column, so the halves reconstruct exactly
        ('da' + 'te by hand') while a space between them would re-break the very word the wrap broke.
    #>
    param($Captured)
    return (($Captured | ForEach-Object { [string]$_ }) -join '')
}

function Test-Line {
    <#
        A whole-line match against the generated document. The skeleton is written with CRLF (it is a
        Windows-authored document, unlike the pure-LF generated notes), so a '(?m)^...$' pattern does NOT
        match: in .NET multiline mode '$' sits before the '\n' and the '\r' is still in the way. Rather
        than sprinkle '\r?$' through twenty asserts -- and have the next person wonder which ones need it
        -- every whole-line assert goes through here.
    #>
    param([string]$Text, [string]$Pattern)
    return ($Text -match ('(?m)^' + $Pattern + '\r?$'))
}

# The developer notes as release-lib.ps1 really writes them: '**Date:**  ' / '**Type:**', categories at
# H2, entries at H3 carrying the compact middot heading, and an H4 inside one body -- the shape that
# proves only H3 is read.
$notes = @"
# Release notes v3.2.0

**Date:** 2026-08-03
**Type:** Minor

## Features

### #428 $midDot Turn the highlights tier on $midDot Feat $midDot 2026-08-03

Body text.

#### A subheading inside the entry

More body.

---

### #427 $midDot The highlights tier moves to the shared cut $midDot Feat $midDot 2026-08-03

Body text.

## Fixes

### #425 $midDot The teardown audit walks every file $midDot Fix $midDot 2026-08-03

Body text.
"@

# --- 1. The refusals ------------------------------------------------------------------------------
Write-Host "new-internal-note -- the refusals (they protect written text)" -ForegroundColor Cyan
$noNotes = New-Fixture -Label 'nonotes'
$r = Invoke-Script -Dir $noNotes
Assert-Equal 1 $r.Code 'no developer notes: exits 1 rather than writing a note with nothing in it'
Assert-True ($r.Flat -match 'Developer notes not found') 'no developer notes: says what is missing'
Assert-True ($r.Flat -match 'cut-release') 'no developer notes: names the script that produces them'
Assert-True (-not (Test-Path (Join-Path $noNotes 'dkj-policy\releases\internal'))) 'no developer notes: nothing was created'
Remove-Item -Recurse -Force -LiteralPath $noNotes -ErrorAction SilentlyContinue

$existing = New-Fixture -Label 'existing' -NotesContent $notes
$r = Invoke-Script -Dir $existing
Assert-Equal 0 $r.Code 'first run: creates the skeleton'
$intPath = Join-Path $existing 'dkj-policy\releases\internal\3.x\3.2.0.md'
Assert-True (Test-Path -LiteralPath $intPath) 'first run: the note exists'
# THE ASSERT THAT MATTERS MOST IN THIS FILE. Overwriting an edited note back to a skeleton destroys the
# only content in the three tiers that cannot be regenerated from anything.
[System.IO.File]::WriteAllText($intPath, "# hand-written, do not lose me`n", $Utf8NoBom)
$r = Invoke-Script -Dir $existing
Assert-Equal 1 $r.Code 'second run without -Force: refuses'
Assert-True ($r.Flat -match '-Force') 'second run: names the flag that would overwrite'
Assert-True ([System.IO.File]::ReadAllText($intPath) -match 'do not lose me') 'second run: the written text is untouched'
$r = Invoke-Script -Dir $existing -ExtraArgs @('-Force')
Assert-Equal 0 $r.Code '-Force: overwrites'
Assert-True ([System.IO.File]::ReadAllText($intPath) -notmatch 'do not lose me') '-Force: really replaced the file'
Remove-Item -Recurse -Force -LiteralPath $existing -ErrorAction SilentlyContinue

Write-Host "new-internal-note -- an invalid version is refused before any IO" -ForegroundColor Cyan
$bad = New-Fixture -Label 'badver' -NotesContent $notes
$r = Invoke-Script -Dir $bad -Version 'not-a-version'
Assert-Equal 1 $r.Code 'a non X.Y.Z version exits 1'
Assert-True (-not (Test-Path (Join-Path $bad 'dkj-policy\releases\internal'))) 'and wrote nothing'
# A leading v is accepted: the tag form and the bare form are the same release.
$r = Invoke-Script -Dir $bad -Version 'v3.2.0'
Assert-Equal 0 $r.Code 'a leading v is accepted (tag form)'
Assert-True (Test-Path (Join-Path $bad 'dkj-policy\releases\internal\3.x\3.2.0.md')) 'and lands under the bare number'
Remove-Item -Recurse -Force -LiteralPath $bad -ErrorAction SilentlyContinue

# --- 2. The skeleton's shape ----------------------------------------------------------------------
Write-Host "new-internal-note -- the skeleton" -ForegroundColor Cyan
$happy = New-Fixture -Label 'happy' -NotesContent $notes
$r = Invoke-Script -Dir $happy
Assert-Equal 0 $r.Code 'happy path: exit 0'
$doc = [System.IO.File]::ReadAllText((Join-Path $happy 'dkj-policy\releases\internal\3.x\3.2.0.md'))
Assert-True (Test-Line -Text $doc -Pattern '# Internal summary v3\.2\.0') 'the title names the version'
Assert-True (Test-Line -Text $doc -Pattern '\*\*Date:\*\* 2026-08-03\\') 'the date is copied from the developer notes, and its line ends in a hard break'
Assert-True (Test-Line -Text $doc -Pattern '\*\*Type:\*\* Minor\\') 'the type is copied too, with the same break'
Assert-True ($doc -match '(?m)^\*\*For whom:\*\* colleagues and management') 'the audience line states who it is for'
# THE THREE LABELS EACH GET THEIR OWN RENDERED LINE (inbound #1101, completing inbound #1100). A single
# newline inside a markdown paragraph is a SOFT break, so without a hard break after the first two the
# block renders as "Date: ... Type: ... For whom: ..." on ONE line -- while the changelog note, the
# GitHub Release body and the audience note all render three. The backslash is CommonMark's spelling of
# that break, chosen over two trailing spaces because the older spelling made every generated release
# document fail an ordinary no-trailing-whitespace rule (inbound #1100).
#
# THE BREAK RIDES ON THE TWO ASSERTS ABOVE rather than getting a pair of its own: Test-Line matches a
# WHOLE line, so '**Date:** 2026-08-03\' already fails the moment the break is dropped. A separate assert
# would be the same regex twice.
#
# THE LAST LABEL TAKES NO BREAK, and that is the shape rather than an omission -- a blank line follows and
# ends the paragraph on its own. Asserted, because "add the break to all three" is the natural
# over-correction and it would put a stray backslash in the rendered output. Build-AudienceNote writes
# exactly these three lines with exactly these two breaks.
Assert-True (Test-Line -Text $doc -Pattern '\*\*For whom:\*\* colleagues and management -- what the organisation gets out of this release') 'the last label carries no break -- the blank line already ends the paragraph'
# The same whole-document guard release-lib.tests.ps1 runs over its three documents, for the same reason:
# the defect it prevents is a property of the OUTPUT, not of one label.
# SPLIT ON CRLF, and the '\r' trimmed: this document is written with CRLF (see Test-Line), so
# splitting on "`n" alone leaves a '\r' at the end of every element and '[ \t]+$' can then never
# match -- the guard would pass on a document full of trailing spaces. Written the wrong way first.
$internalDirty = @(($doc -split "`r?`n") | Where-Object { $_ -match '[ \t]+$' })
Assert-Equal 0 $internalDirty.Count 'no generated line in the internal note ends in whitespace'
foreach ($h in @('What is different now', 'What it is worth', 'What was still open at this release')) {
    Assert-True (Test-Line -Text $doc -Pattern ('## ' + [regex]::Escape($h))) "the fixed heading '$h' is present"
}
Assert-True ($doc -match '(?s)What is different now.*What it is worth.*What was still open at this release') 'the three headings are in order'
# The third heading is PAST TENSE and names the release, and that is the fix rather than a wording
# preference: this document is a PUBLISHED record of one release, so it does not move with reality. A
# NOT THE GITHUB RELEASE BODY, corrected with inbound #1101. That line stood here until the one-document
# reorganisation (Dave, August 10-12, 2026) moved the generated body into its own root, and cut-release
# has passed 'releases/github/<dir>/<X.Y.Z>.md' to 'gh release create --notes-file' ever since; nothing
# calls this script in a repo running that flow. The stale claim is worth naming rather than just
# deleting, because it was repeated verbatim in inbound #1101 as the stake of the repair -- "the one of
# the three a reader outside the repo actually opens" -- and a wrong reason attached to a correct symptom
# is exactly what this repo checks for before repairing a report. The repair still stands on its other
# leg: three documents of one release should not differ in shape.
# present-tense heading invites lines that go stale in hours -- measured three times on August 4, 2026,
# once by a line stating the previous release had no public page, published minutes before it got one.
# Asserted as a negative too, because the old wording is the natural thing to type back in.
Assert-True ($doc -notmatch '(?m)^## What is still open') 'the open heading is not present tense (it would date the published body)'
# Not Test-Line: the hint sits mid-line inside the skeleton comment block, so a whole-line match is the
# wrong tool here even though every heading assert above uses one.
Assert-True ($doc -match 'SNAPSHOT of this release') 'the skeleton hint tells the writer to write a snapshot, not a claim about the present'
# The titles carry over WITHOUT the PR number and date -- this document has a reader with no branch.
Assert-True (Test-Line -Text $doc -Pattern '- \[Feat\] Turn the highlights tier on') 'an entry becomes a [type] bullet with a bare title'
Assert-True (Test-Line -Text $doc -Pattern '- \[Fix\] The teardown audit walks every file') 'and so does one from another category'
Assert-True ($doc -notmatch '#428') 'the PR number is not carried into the document'
Assert-True ($doc -notmatch '2026-08-03 *$' -or $true) 'the per-entry date is not carried into the bullets'
Assert-Equal 3 (@([regex]::Matches($doc, '(?m)^- \[')).Count) 'exactly three bullets -- only H3 entries count, not the H2 categories or the H4 inside a body'
Assert-True ($doc -notmatch 'A subheading inside the entry') 'an H4 inside an entry body is not read as an entry'
# The skeleton says it is a skeleton, and points back at its source.
Assert-True ($doc -match 'SKELETON') 'the document announces itself as a skeleton'
Assert-True ($doc -match 'releases/changelog/3\.x/3\.2\.0\.md') 'and names the notes it was built from'
Assert-True ($r.Flat -match 'Step 1') 'the run prints the next step'
Assert-True ($r.Flat -match 'branch') 'and says it ships via a branch (the release commit is already tagged)'
Remove-Item -Recurse -Force -LiteralPath $happy -ErrorAction SilentlyContinue

Write-Host "new-internal-note -- notes without the metadata lines" -ForegroundColor Cyan
# A repo whose notes use other labels must get a visible '(fill in)' rather than a blank line that
# nobody notices until the document is being read by someone else.
$noMeta = New-Fixture -Label 'nometa' -NotesContent "# Release notes v3.2.0`n`nNo metadata lines here.`n`n### #1 $midDot A title $midDot Feat $midDot 2026-08-03`n`nBody.`n"
$r = Invoke-Script -Dir $noMeta
Assert-Equal 0 $r.Code 'missing metadata does not stop the run'
$doc = [System.IO.File]::ReadAllText((Join-Path $noMeta 'dkj-policy\releases\internal\3.x\3.2.0.md'))
Assert-True ($doc -match '\*\*Date:\*\* \(fill in\)') 'a missing date becomes a visible placeholder'
Assert-True ($doc -match '\*\*Type:\*\* \(fill in\)') 'and so does a missing type'
Assert-True ($r.Flat -match 'fill in the date by hand') 'and the run warns about it out loud'
Remove-Item -Recurse -Force -LiteralPath $noMeta -ErrorAction SilentlyContinue

Write-Host "new-internal-note -- BOTH spellings of the markdown hard break (inbound #1100)" -ForegroundColor Cyan
# release-lib.ps1 ended those two lines with TWO TRAILING SPACES until inbound #1100 and ends them with a
# BACKSLASH now -- the same markdown hard break, spelled the way no trailing-whitespace lint rule can see.
# Both have to read, and the failure mode of getting it wrong is the quiet one: Get-MetaLine's old pattern
# trims whitespace only, so the backslash would have been carried into the published document as part of
# the date ('2026-08-03\') rather than raising anything. The two-space fixture is asserted a few lines
# below in the no-entries case; this is the new form, and the old notes it must not stop reading are
# every note this repo has already published.
$hardBreak = New-Fixture -Label 'hardbreak' -NotesContent "# Release notes v3.2.0`n`n**Date:** 2026-08-03\`n**Type:** Minor\`n`n### #1 $midDot A title $midDot Feat $midDot 2026-08-03`n`nBody.`n"
$r = Invoke-Script -Dir $hardBreak
Assert-Equal 0 $r.Code 'a backslash hard break does not stop the run'
$doc = [System.IO.File]::ReadAllText((Join-Path $hardBreak 'dkj-policy\releases\internal\3.x\3.2.0.md'))
# THE SOURCE'S BREAK MUST NOT REACH THE VALUE -- and since inbound #1101 this document ends those two
# lines with a break of its OWN, so "no backslash anywhere on the line" is no longer the test. What the
# regression would look like is a DOUBLE one: Get-MetaLine carries the source's '\' into the value, the
# skeleton appends its own, and the line reads '**Date:** 2026-08-03\\'. That is what is asserted, and it
# is the reason these three asserts had to change with #1101 rather than simply pass.
Assert-True (Test-Line -Text $doc -Pattern '\*\*Date:\*\* 2026-08-03\\') 'the date reads back WITHOUT the source''s backslash (one break, its own)'
Assert-True (Test-Line -Text $doc -Pattern '\*\*Type:\*\* Minor\\') 'and so does the type'
Assert-True ($doc -notmatch '2026-08-03\\\\') 'the break marker is not carried into the value on top of the emitted one'
Assert-True ($r.Flat -notmatch 'fill in the date by hand') 'and nothing falls back to the placeholder'
Remove-Item -Recurse -Force -LiteralPath $hardBreak -ErrorAction SilentlyContinue

Write-Host "new-internal-note -- notes with no entries at all" -ForegroundColor Cyan
$noEntries = New-Fixture -Label 'noentries' -NotesContent "# Release notes v3.2.0`n`n**Date:** 2026-08-03  `n**Type:** Patch`n`nNothing structured here.`n"
$r = Invoke-Script -Dir $noEntries
Assert-Equal 0 $r.Code 'no entries does not stop the run'
$doc = [System.IO.File]::ReadAllText((Join-Path $noEntries 'dkj-policy\releases\internal\3.x\3.2.0.md'))
Assert-True ($doc -match 'no entries found') 'the list says so instead of being silently empty'
Remove-Item -Recurse -Force -LiteralPath $noEntries -ErrorAction SilentlyContinue

# --- 3. The folder scheme follows the repo's one answer -------------------------------------------
Write-Host "new-internal-note -- the folder scheme comes from Get-ReleaseNotesGrouping" -ForegroundColor Cyan
# Per MINOR: the note must land beside its developer notes, not in a scheme of its own. This is the assert
# that would catch the tier drifting away from the other two.
$minorCfg = "function Get-ReleaseNotesGrouping { return 'minor' }`n"
$perMinor = New-Fixture -Label 'perminor' -NotesDir '3.2' -NotesContent $notes -RepoConfig $minorCfg
$r = Invoke-Script -Dir $perMinor
Assert-Equal 0 $r.Code 'per-minor grouping: exit 0'
Assert-True (Test-Path (Join-Path $perMinor 'dkj-policy\releases\internal\3.2\3.2.0.md')) 'per-minor grouping: the note lands in releases/internal/3.2/'
Assert-True (-not (Test-Path (Join-Path $perMinor 'dkj-policy\releases\internal\3.x'))) 'per-minor grouping: and NOT in a 3.x folder'
Remove-Item -Recurse -Force -LiteralPath $perMinor -ErrorAction SilentlyContinue

# --- 4. The wording seam (#410 class) -------------------------------------------------------------
Write-Host "new-internal-note -- every string in the document is overridable" -ForegroundColor Cyan
$nlCfg = @'
function Get-InternalNoteWording {
    return @{
        Title          = 'Interne samenvatting'
        AudienceLabel  = 'Voor wie'
        Audience       = 'werkgevers en management'
        SectionChanged = 'Wat er nu anders is'
        SectionValue   = 'Wat het oplevert'
        SectionOpen    = 'Wat er nog open staat'
    }
}
'@
$translated = New-Fixture -Label 'nl' -NotesContent $notes -RepoConfig $nlCfg
$r = Invoke-Script -Dir $translated
Assert-Equal 0 $r.Code 'translated wording: exit 0'
$doc = [System.IO.File]::ReadAllText((Join-Path $translated 'dkj-policy\releases\internal\3.x\3.2.0.md'))
Assert-True (Test-Line -Text $doc -Pattern '# Interne samenvatting v3\.2\.0') 'the title is overridden'
Assert-True (Test-Line -Text $doc -Pattern '\*\*Voor wie:\*\* werkgevers en management') 'the audience label AND its text are overridden'
foreach ($h in @('Wat er nu anders is', 'Wat het oplevert', 'Wat er nog open staat')) {
    Assert-True (Test-Line -Text $doc -Pattern ('## ' + [regex]::Escape($h))) "the heading '$h' is overridden"
}
Assert-True ($doc -notmatch 'What is different now') 'no English heading survives alongside the override'
# MERGED, not substituted: a key the override does not mention keeps its English default rather than
# vanishing. Without this, a consumer translating three headings would silently lose the fill-in hints.
Assert-True ($doc -match 'SKELETON') 'an unmentioned key keeps its default -- the map is merged'
Assert-True ($doc -match 'cannot be generated') 'the value hint survives untranslated rather than disappearing'
Remove-Item -Recurse -Force -LiteralPath $translated -ErrorAction SilentlyContinue

# ===================================================================================================
# THE TIER SELECTION (August 5, 2026): tier 1 and 2 are carried over, tier 0 is not
# ===================================================================================================
Write-Host "Tiered developer notes: tier 1 and 2 come over, tier 0 stays behind" -ForegroundColor Cyan
# The developer notes are now nested one level deeper -- '## Tier <n>' -> '### <Category>' ->
# '#### <entry>' -- so an entry is recognised by its metadata SHAPE rather than by its heading level. A
# level-based match would have collected the CATEGORY headings instead and put the words 'Features' and
# 'Fixes' in a document written for colleagues.
$tieredNotes = @"
# Release notes v3.2.0

**Date:** 2026-08-03
**Type:** Minor

## Tier 2 - consumers

### Features

#### #470 $midDot A consumer-facing feature $midDot Feat $midDot 2026-08-05

Body text.

### Fixes

#### #469 $midDot A consumer-facing fix $midDot Fix $midDot 2026-08-05

Body text.

## Tier 1 - colleagues

### Documentation

#### #468 $midDot Something for colleagues $midDot Docs $midDot 2026-08-04

Body text.

## Tier 0 - developers

### Maintenance

#### #467 $midDot Repo-internal housekeeping $midDot Chore $midDot 2026-08-04

Body text.
"@
$tiered = New-Fixture -Label 'tiered' -NotesContent $tieredNotes
$r = Invoke-Script -Dir $tiered
Assert-Equal 0 $r.Code 'tiered notes: exit 0'
$doc = [System.IO.File]::ReadAllText((Join-Path $tiered 'dkj-policy\releases\internal\3.x\3.2.0.md'))
Assert-True ($doc -match '- \[Feat\] A consumer-facing feature') 'tiered notes: a tier-2 entry is carried over -- the ladder is cumulative'
Assert-True ($doc -match '- \[Fix\] A consumer-facing fix')      'tiered notes: and the second one in that tier'
Assert-True ($doc -match '- \[Docs\] Something for colleagues')  'tiered notes: the tier-1 entry is carried over'
Assert-True ($doc -notmatch 'Repo-internal housekeeping')        'tiered notes: the tier-0 entry is NOT -- the developer notes are its record'
# The category headings must not be mistaken for entries. Asserted as bullets specifically: the words do
# appear in the document's own prose, so a bare -notmatch would be satisfied by the wrong thing.
foreach ($cat in 'Features', 'Fixes', 'Documentation', 'Maintenance') {
    Assert-True ($doc -notmatch "(?m)^- (\[[^\]]+\] )?$cat`$") "tiered notes: the '$cat' category heading is not carried over as a bullet"
}
Assert-True ($doc -notmatch '#470') 'tiered notes: the PR number is stripped, as before'
Remove-Item -Recurse -Force -LiteralPath $tiered -ErrorAction SilentlyContinue

Write-Host "The CURRENT note shape: entries recognised by their named sections" -ForegroundColor Cyan
# THE GAP THAT LET A DEFECT LIVE: every fixture above is the shape the notes had BEFORE the flat changelog,
# and they all still pass -- which is right, because a note can be regenerated for any release ever cut. But
# nothing here described what release-lib writes TODAY, so nobody noticed that the recogniser had stopped
# finding anything at all. It matched '>= 3 middot fields in the heading' with the type as the second-to-last;
# the format took those fields away one at a time (the date to the closing line, the type into its own
# section, then the PR number), and at two fields every real entry fell below the threshold.
#
# MEASURED AGAINST A NOTE BUILT FROM THE LIVE CHANGELOG, before rewriting it: 46 headings skipped, all ten
# entries among them, and the ONE heading that still matched was a QUOTED example inside a fenced code block
# in an entry body -- which became the note's only bullet, with the illustration's own words as its type.
# That case is the last assert in this block, so it cannot come back.
$currentNotes = @"
# Release notes v3.6.0

**Date:** 2026-08-05
**Type:** Minor

## Tier 2 - consumers

### A consumer-facing feature

#### What does this change do?

Body text.

#### Who is this for

| Tier | Significance | Why |
|---|---|---|
| 2 | 4 | consumers notice |
| 1 | 3 | colleagues too |

#### Type of change

Feat

---

### A consumer-facing fix

#### What does this change do?

Body text, and it quotes the older heading shape while documenting it:

``````text
#### #469 $midDot An old-shape heading $midDot Fix $midDot 2026-08-05
``````

#### Who is this for

| Tier | Significance | Why |
|---|---|---|
| 2 | 2 | small |
| 1 | 2 | small |

#### Type of change

Fix

## Tier 1 - colleagues

### Something for colleagues

#### What does this change do?

Body text.

#### Who is this for

| Tier | Significance | Why |
|---|---|---|
| 1 | 3 | useful |

#### Type of change

Docs

## Tier 0 - developers

### Repo-internal housekeeping

#### What does this change do?

Body text.

#### Who is this for

| Tier | Significance | Why |
|---|---|---|
| 0 | - | - |

#### Type of change

Chore
"@
$cur = New-Fixture -Label 'current-shape' -NotesContent $currentNotes -Version '3.6.0'
$rc = Invoke-Script -Dir $cur -Version '3.6.0'
Assert-Equal 0 $rc.Code 'current shape: exit 0'
$curDoc = [System.IO.File]::ReadAllText((Join-Path $cur 'dkj-policy\releases\internal\3.x\3.6.0.md'))
# The type comes from the '#### Type of change' SECTION now, not from a heading field.
Assert-True ($curDoc -match '- \[Feat\] A consumer-facing feature') 'current shape: a tier-2 entry becomes a bullet, its type read from the Type section'
Assert-True ($curDoc -match '- \[Fix\] A consumer-facing fix')      'current shape: and the second one in that tier'
Assert-True ($curDoc -match '- \[Docs\] Something for colleagues')  'current shape: the tier-1 entry is carried over'
Assert-True ($curDoc -notmatch 'Repo-internal housekeeping')        'current shape: the tier-0 entry is not -- the developer notes are its record'
# The three section headings sit one level under every entry; reading them as entries would put the same
# four words in the document once per change. Asserted as bullets, since the words appear in prose too.
foreach ($sec in 'What does this change do\?', 'Who is this for', 'Type of change') {
    Assert-True ($curDoc -notmatch "(?m)^- (\[[^\]]+\] )?$sec`$") "current shape: the '$sec' section heading is not carried over as a bullet"
}
# And the tier headings themselves, which sit one level ABOVE the entries.
foreach ($tierWord in 'Tier 2 - consumers', 'Tier 1 - colleagues') {
    Assert-True ($curDoc -notmatch "(?m)^- (\[[^\]]+\] )?$tierWord`$") "current shape: the '$tierWord' heading is not an entry either"
}
# THE FABRICATED BULLET, as a standing check. The quoted heading inside the second entry's body is the exact
# shape the old recogniser matched, and it is the only thing it found in the real document.
Assert-True ($curDoc -notmatch 'An old-shape heading') 'current shape: a heading quoted inside a fenced block is not read as an entry'
Assert-True ($curDoc -notmatch '#469') 'current shape: so its number does not reach the document either'
Assert-Equal 3 (@([regex]::Matches($curDoc, '(?m)^- \[')).Count) 'current shape: exactly three bullets -- the tier-2 pair and the tier-1 one, nothing else'
Remove-Item -Recurse -Force -LiteralPath $cur -ErrorAction SilentlyContinue

# ===================================================================================================
# THE FLAT SHAPE (#881, August 25, 2026): no tier heading, so the ENTRY's declaration is the filter
# ===================================================================================================
Write-Host "The flat shape: no tier heading, the entry's own declaration decides" -ForegroundColor Cyan
# What release-lib wrote from #881 (August 25, 2026) until #1369 -- entries at '##' and their sections at
# '###', with no '## Tier <n>' wrapper above them. Those were CHANGELOG.md's levels on the day, and both
# moved one deeper the next day; the block after this one is the shape written today. The container heading this script used
# to filter on is gone, and the fallback it had ("no tier headings, take everything") would have carried
# the tier-0 entry into a document written for colleagues. Silent, plausible, and wrong in the direction
# that publishes repo-internal work: the same failure shape as the fabricated bullet above.
$flatNotes = @"
# Release notes v3.7.0

**Date:** 2026-08-25
**Type:** Minor

## A consumer-facing feature

### What does this change do?

Body text.

### Who is this for

| Tier | Significance | Why |
|---|---|---|
| 2 | 4 | consumers notice |
| 1 | 3 | colleagues too |

### Type of change

Feat

---

## Something for colleagues

### What does this change do?

Body text.

### Who is this for

| Tier | Significance | Why |
|---|---|---|
| 1 | 3 | useful |

### Type of change

Docs

---

## Repo-internal housekeeping

### What does this change do?

Body text.

### Who is this for

| Tier | Significance | Why |
|---|---|---|
| 0 | - | - |

### Type of change

Chore
"@
$flat = New-Fixture -Label 'flat-shape' -NotesContent $flatNotes -Version '3.7.0'
$rf = Invoke-Script -Dir $flat -Version '3.7.0'
Assert-Equal 0 $rf.Code 'flat shape: exit 0'
$flatDoc = [System.IO.File]::ReadAllText((Join-Path $flat 'dkj-policy\releases\internal\3.x\3.7.0.md'))
Assert-True ($flatDoc -match '- \[Feat\] A consumer-facing feature') 'flat shape: the tier-2 entry becomes a bullet'
Assert-True ($flatDoc -match '- \[Docs\] Something for colleagues')  'flat shape: and so does the tier-1 entry'
Assert-True ($flatDoc -notmatch 'Repo-internal housekeeping') `
    'flat shape: the tier-0 entry is filtered out on ITS OWN declaration, with no heading to read it from'
Assert-Equal 2 (@([regex]::Matches($flatDoc, '(?m)^- \[')).Count) 'flat shape: exactly two bullets'
Remove-Item -Recurse -Force -LiteralPath $flat -ErrorAction SilentlyContinue

# ===================================================================================================
# THE SHAPE WRITTEN TODAY (#1369, September 4, 2026): a constant H1, a version H2, entries at H3
# ===================================================================================================
Write-Host "Today's shape: entries at H3 under a version heading" -ForegroundColor Cyan
# WHY THIS BLOCK EXISTS, and it is the same gap the 'current shape' block above was written to close: every
# fixture before it described a note release-lib no longer writes, so nothing here would have noticed the
# recogniser going blind. The levels moved twice -- once on August 26, 2026 when CHANGELOG.md gained
# '## [Unreleased]' and an entry became an H3, and once here when the release note stopped promoting it
# back to H2 -- and the note now carries a '## Version <X.Y.Z> (<Mon DD, YYYY>)' heading that did not exist
# in any earlier shape. Two things have to hold: the entries are still FOUND one level deeper, and that new
# H2 is NOT read as an entry. The second is the one that fails quietly -- an unrecognised container heading
# used to become a bullet with a fabricated type, which is the failure this suite already carries a standing
# check for.
#
# THE H1 NO LONGER NAMES THE VERSION EITHER, so this also proves nothing here was reading it. The metadata
# pair below it is the shape every note published before #2491 carries, and it is still read first; the
# block after this one covers the notes cut since, which carry no pair at all.
$todayNotes = @"
# Changelog Releases

**Date:** 2026-09-04\
**Type:** Minor

A one-line release title

## Version 4.30.0 (Sep 04, 2026)

### A consumer-facing feature

#### What does this change do?

Body text.

#### Who is this for

| Tier | Significance | Why |
|---|---|---|
| 2 | 4 | consumers notice |
| 1 | 3 | colleagues too |

#### Type of change

Feat

---

### Something for colleagues

#### What does this change do?

Body text.

#### Who is this for

| Tier | Significance | Why |
|---|---|---|
| 1 | 3 | useful |

#### Type of change

Docs

---

### Repo-internal housekeeping

#### What does this change do?

Body text.

#### Who is this for

| Tier | Significance | Why |
|---|---|---|
| 0 | - | - |

#### Type of change

Chore
"@
$today = New-Fixture -Label 'today-shape' -NotesContent $todayNotes -Version '4.30.0' -NotesDir '4.x'
$rt = Invoke-Script -Dir $today -Version '4.30.0'
Assert-Equal 0 $rt.Code "today's shape: exit 0"
$todayDoc = [System.IO.File]::ReadAllText((Join-Path $today 'dkj-policy\releases\internal\4.x\4.30.0.md'))
Assert-True ($todayDoc -match '- \[Feat\] A consumer-facing feature') "today's shape: an H3 entry is still found -- the walk is level-agnostic"
Assert-True ($todayDoc -match '- \[Docs\] Something for colleagues')  "today's shape: and so is the tier-1 one"
Assert-True ($todayDoc -notmatch 'Repo-internal housekeeping') `
    "today's shape: the tier-0 entry is still filtered out on its own declaration"
# THE NEW CONTAINER HEADING IS NOT AN ENTRY. It has no named section directly beneath it (its children are
# the entries themselves) and no middot metadata, so both recognisers reject it -- but a bullet reading
# 'Version 4.30.0 (Sep 04, 2026)' in a document written for colleagues is exactly the shape that got
# through last time, so it is asserted rather than reasoned about.
Assert-True ($todayDoc -notmatch "(?m)^- (\[[^\]]+\] )?Version 4\.30\.0") "today's shape: the version heading is not carried over as a bullet"
Assert-True ($todayDoc -notmatch 'Changelog Releases') "today's shape: nor is the constant H1"
Assert-Equal 2 (@([regex]::Matches($todayDoc, '(?m)^- \[')).Count) "today's shape: exactly two bullets"
# Where the pair is present it is what the date and type are read from -- a published note's internal note
# comes out as it always did.
Assert-True ($todayDoc -match '2026-09-04') "today's shape: the date is carried over from the '**Date:**' line"
Assert-True ($todayDoc -match 'Minor')      "today's shape: and the type from the '**Type:**' line"
Remove-Item -Recurse -Force -LiteralPath $today -ErrorAction SilentlyContinue

Write-Host "Today's shape without the metadata pair (#2491): date and type come from the version heading" -ForegroundColor Cyan
# release-lib stopped writing '**Date:**'/'**Type:**' on September 25, 2026, because the version heading
# already states both. So a note cut from then on carries only the heading, and the internal note has to
# come out exactly as complete as before -- no '(fill in)', no warning. The type is the version's SHAPE, so
# a patch-shaped version is asserted too: 'Minor' alone could pass on a hard-coded default.
$noPairNotes = $todayNotes -replace "\*\*Date:\*\* 2026-09-04\\\r?\n\*\*Type:\*\* Minor\r?\n\r?\n", ''
Assert-True ($noPairNotes -notmatch '\*\*(Date|Type):\*\*') 'no-pair fixture: the pair really is gone from it'
$noPair = New-Fixture -Label 'no-pair' -NotesContent $noPairNotes -Version '4.30.0' -NotesDir '4.x'
$rn = Invoke-Script -Dir $noPair -Version '4.30.0'
Assert-Equal 0 $rn.Code 'no pair: exit 0'
$noPairDoc = [System.IO.File]::ReadAllText((Join-Path $noPair 'dkj-policy\releases\internal\4.x\4.30.0.md'))
Assert-True ($noPairDoc -match '\*\*Date:\*\* 2026-09-04\\') 'no pair: the date is read back out of the version heading, in ISO form'
Assert-True ($noPairDoc -match '\*\*Type:\*\* Minor\\')      'no pair: and the type from the version number'
Assert-True ($noPairDoc -notmatch '\(fill in\)')             'no pair: nothing is left as a placeholder'
Assert-True ($rn.Flat -notmatch 'fill in the (date|type) by hand') 'no pair: and no warning is printed'
Remove-Item -Recurse -Force -LiteralPath $noPair -ErrorAction SilentlyContinue

$patchNotes = $noPairNotes -replace 'Version 4\.30\.0 \(Sep 04, 2026\)', 'Version 4.30.2 (Sep 06, 2026)'
$patch = New-Fixture -Label 'no-pair-patch' -NotesContent $patchNotes -Version '4.30.2' -NotesDir '4.x'
$rp = Invoke-Script -Dir $patch -Version '4.30.2'
Assert-Equal 0 $rp.Code 'no pair, patch: exit 0'
$patchDoc = [System.IO.File]::ReadAllText((Join-Path $patch 'dkj-policy\releases\internal\4.x\4.30.2.md'))
Assert-True ($patchDoc -match '\*\*Date:\*\* 2026-09-06\\') 'no pair, patch: the date follows the heading'
Assert-True ($patchDoc -match '\*\*Type:\*\* Patch\\')      'no pair, patch: and a patch-shaped version reads as Patch'
Remove-Item -Recurse -Force -LiteralPath $patch -ErrorAction SilentlyContinue

# A STATED TYPE BEATS THE SHAPE. 'cut-release.ps1 -Version 4.30.0 -Type patch' is legal where a repo's
# numbering diverges, and the version heading alone would read 4.30.0 as a Minor. The release history's row
# is what the cut writes from the stated type, so it is asked first; this row disagrees with the shape on
# purpose, which is the only way the assert can tell which of the two was read.
$stated = New-Fixture -Label 'no-pair-stated' -NotesContent $noPairNotes -Version '4.30.0' -NotesDir '4.x'
New-Item -ItemType Directory -Path (Join-Path $stated 'releases') -Force | Out-Null
[System.IO.File]::WriteAllText((Join-Path $stated 'releases\README.md'),
    "# Releases`n`n### 4.x`n`n| Version | Date | Type | Title |`n|---|---|---|---|`n| [4.30.0](changelog/4.x/4.30.0.md) | 2026-09-04 | Patch | Stated |`n",
    $Utf8NoBom)
$rs = Invoke-Script -Dir $stated -Version '4.30.0'
Assert-Equal 0 $rs.Code 'stated type: exit 0'
$statedDoc = [System.IO.File]::ReadAllText((Join-Path $stated 'dkj-policy\releases\internal\4.x\4.30.0.md'))
Assert-True ($statedDoc -match '\*\*Type:\*\* Patch\\') "stated type: the history row's Type wins over the version's shape"
Remove-Item -Recurse -Force -LiteralPath $stated -ErrorAction SilentlyContinue

# And the all-tier-0 case in the flat shape: the warning still names the reason rather than reporting a
# parse failure, which is the one thing the container heading used to be needed for.
$flatZeroNotes = @"
# Release notes v3.8.0

**Date:** 2026-08-25
**Type:** Patch

## Only housekeeping

### What does this change do?

Body text.

### Who is this for

| Tier | Significance | Why |
|---|---|---|
| 0 | - | - |

### Type of change

Chore
"@
$flatZero = New-Fixture -Label 'flat-allzero' -NotesContent $flatZeroNotes -Version '3.8.0'
$rfz = Invoke-Script -Dir $flatZero -Version '3.8.0'
Assert-Equal 0 $rfz.Code 'flat shape, all tier 0: exit 0'
Assert-True ($rfz.Flat -match 'is tier 0') 'flat shape, all tier 0: the warning names the tier, not a parse failure'
Remove-Item -Recurse -Force -LiteralPath $flatZero -ErrorAction SilentlyContinue

Write-Host "Notes whose every entry is tier 0: an empty list, with the reason" -ForegroundColor Cyan
# Reachable only through -SkipTierGate (the cut refuses such a release), which is exactly why the message
# has to distinguish it from "the notes did not parse" -- one is a bypassed judgement, the other a defect.
$allZeroNotes = @"
# Release notes v3.2.0

**Date:** 2026-08-03
**Type:** Patch

## Tier 0 - developers

### Maintenance

#### #467 $midDot Only housekeeping $midDot Chore $midDot 2026-08-04

Body text.
"@
$allZero = New-Fixture -Label 'allzero' -NotesContent $allZeroNotes
$r = Invoke-Script -Dir $allZero
Assert-Equal 0 $r.Code 'all tier 0: exit 0 -- a thin release is not a failure'
Assert-True ($r.Flat -match 'is tier 0') 'all tier 0: the warning says every entry was tier 0'
Assert-True ($r.Flat -notmatch 'No entry titles found') 'all tier 0: and does NOT report it as a parse failure'
$doc = [System.IO.File]::ReadAllText((Join-Path $allZero 'dkj-policy\releases\internal\3.x\3.2.0.md'))
Assert-True ($doc -match 'no entries found') 'all tier 0: the skeleton carries the fill-in-by-hand placeholder'
Remove-Item -Recurse -Force -LiteralPath $allZero -ErrorAction SilentlyContinue

Write-Host "Untiered developer notes still carry everything" -ForegroundColor Cyan
# A repo with no tier split has no tier information to filter on, so filtering would EMPTY the document
# rather than focus it. The pre-tier fixture at the top of this file is that case; asserted explicitly
# here so the fallback is a stated guarantee rather than a side effect.
$flat = New-Fixture -Label 'flat-still-works' -NotesContent "# Release notes v3.2.0`n`n**Date:** 2026-08-03`n**Type:** Patch`n`n## Maintenance`n`n### #1 $midDot An untiered entry $midDot Chore $midDot 2026-08-03`n`nBody.`n"
$r = Invoke-Script -Dir $flat
Assert-Equal 0 $r.Code 'untiered notes: exit 0'
$doc = [System.IO.File]::ReadAllText((Join-Path $flat 'dkj-policy\releases\internal\3.x\3.2.0.md'))
Assert-True ($doc -match '- \[Chore\] An untiered entry') 'untiered notes: every entry is carried over, tier filter or not'
Remove-Item -Recurse -Force -LiteralPath $flat -ErrorAction SilentlyContinue

Write-Host "The tier-0 root answers under BOTH seam names" -ForegroundColor Cyan
# THE RENAME'S FALLBACK, ASSERTED AS BEHAVIOUR RATHER THAN AS TEXT (issue #947, August 26, 2026). The seam
# THE PATH SITS INSIDE THE WORKFLOW FOLDER SINCE ISSUE #998 (August 27, 2026) -- it was 'legacy/devnotes'
# at the repo root, which Assert-WorkflowIsolatedSeamPath refused the moment the source exemption came off.
# The SUBJECT here is the retired seam NAME, not where it points, so the path moves and the test is intact.
# was Get-ReleaseDevelopmentNotesRoot until the directory rename of #914 caught up with it, and a consumer
# receives that rename through a plugin update rather than by choosing to. Get-SeamValue takes an array of
# names precisely so the retired one keeps answering -- so this plants the notes somewhere only the OLD
# name points at and requires the script to find them. Drop the fallback and this fixture falls through to
# the computed default, finds nothing there, and refuses: the exact silent break the array exists to
# prevent, except here it is loud, because reading is a precondition of this script rather than an option.
$oldNameCfg = "function Get-ReleaseDevelopmentNotesRoot { return 'dkj-policy/legacy/devnotes' }`n"
$retired = New-Fixture -Label 'seam-retired-name' -NotesContent $notes -RepoConfig $oldNameCfg -NotesRoot 'dkj-policy/legacy/devnotes'
$r = Invoke-Script -Dir $retired
Assert-Equal 0 $r.Code 'retired seam name: the notes are found under the name a consumer already defined'
Assert-True ($r.Flat -match 'dkj-policy/legacy/devnotes') 'retired seam name: and it is the retired seam''s path that was read'
Remove-Item -Recurse -Force -LiteralPath $retired -ErrorAction SilentlyContinue

# AND THE CURRENT NAME WINS WHERE BOTH ARE DEFINED, which is exactly the mid-migration state: a consumer
# who adds the new name without deleting the old one must move, not stay. Asserted by pointing the two at
# DIFFERENT directories and planting the notes only under the current one -- so a reader that preferred the
# retired name would refuse rather than quietly pass.
$bothCfg = "function Get-ReleaseChangelogNotesRoot { return 'dkj-policy/legacy/current' }`n" +
           "function Get-ReleaseDevelopmentNotesRoot { return 'dkj-policy/legacy/stale' }`n"
$both = New-Fixture -Label 'seam-both-names' -NotesContent $notes -RepoConfig $bothCfg -NotesRoot 'dkj-policy/legacy/current'
$r = Invoke-Script -Dir $both
Assert-Equal 0 $r.Code 'both seam names defined: the CURRENT one is tried first'
Assert-True ($r.Flat -match 'dkj-policy/legacy/current') 'both seam names defined: and it is the current name''s path that was read'
Assert-True ($r.Flat -notmatch 'dkj-policy/legacy/stale') 'both seam names defined: the retired name is not consulted at all'
Remove-Item -Recurse -Force -LiteralPath $both -ErrorAction SilentlyContinue

Write-Host ""
# ABOVE THE VERDICT AND EVEN ON A GREEN RUN (issues #1934 and #1954): a child that never reached its
# first statement wrote no note, so the asserts measured the fixture rather than the script.
$loadBroken = Write-FixtureScriptSummary -Subject 'new-internal-note.ps1'
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
if ($loadBroken) {
    Write-Host "FAILED: $(Get-FixtureScriptLoadFailureCount) child script(s) died on load -- this run measured a fixture, not the script." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
