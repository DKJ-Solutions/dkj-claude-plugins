<#
.SYNOPSIS
    Lays down the skeleton for the internal release summary: releases/internal/<dir>/<X.Y.Z>.md.

.DESCRIPTION
    THE TIER-1 release document, for colleagues, employers and management. It exists at EVERY release,
    patch included, and fills the gap between the other two:

      <changelog root>/<dir>/<X.Y.Z>.md        tier 0   developers   -- always, complete and long
      releases/internal/<dir>/<X.Y.Z>.md      tier 1   colleagues   -- always, what the work is worth
      releases/consumer/<dir>/<X.Y.Z>.md    tier 2   consumers    -- minor/major, what they notice

    THE DISTINCTION THAT KEEPS THE TIERS WORKABLE: consumer = WHAT THE CONSUMER NOTICES, internal =
    WHAT THE ORGANISATION GETS OUT OF IT. They come apart most clearly on a patch, which is where this
    tier was first needed: a release with nothing for a consumer -- correctly a patch, therefore no
    consumer document -- can still be the release where a team stopped needing a developer for a routine change.

    WHICH ENTRIES IT CARRIES OVER: tier 1 AND tier 2, because the ladder is cumulative. Something a
    consumer notices is something a colleague should hear about too, so a tier-2 entry appears in this
    document as well as in the consumer document. Tier-0 entries do not: they are repo-internal by definition,
    the developer notes are their record, and copying them here would rebuild the document this tier
    exists to avoid.

    IT GENERATES ONLY HALF, AND THAT IS THE POINT. Version, date, type and the entry titles come from the
    developer notes; "what it is worth" cannot be derived from a changelog. So what you get is a SKELETON
    with the titles as bullets and three fixed headings to fill in -- the same "edit it afterwards" shape
    the consumer tier has. The three headings are fixed on purpose: without that boundary this tier
    grows back into the developer notes it was created to avoid.

    WHY THIS IS ITS OWN SCRIPT RATHER THAN PART OF cut-release.ps1. In the repo this was ported from the
    reason was that cut-release was marked "temporarily diverged" and must not be extended; that reason is
    gone (#417 made it shared). The reason it still holds is different and better: cut-release COMMITS AND
    TAGS in one motion, so a skeleton generated there would put an empty document inside the release tag
    and the written version would land afterwards anyway. Keeping it separate means the release commit
    stays what it is -- purely generated artefacts -- while the one document that is human-written from
    beginning to end travels the normal reviewed route.

    SHARED, WITH THE DOCUMENT'S WORDING IN THE SEAM. This script is mirrored into the plugin. Its console
    output and errors are English like every shared script here, but the DOCUMENT it writes is read by a
    given repo's own colleagues -- so every string that lands in the file comes from the optional
    Get-InternalNoteWording in scripts/repo-config.ps1, falling back to the English text below. Same
    #410 reasoning as the entry stubs and the remove-before-publishing marker.

    Pure ASCII (repo convention for .ps1): Windows PowerShell 5.1 reads a BOM-less script using the system
    ANSI codepage, so a literal non-ASCII character in the source is decoded wrongly. The middot that
    separates the entry heading fields is therefore built from its codepoint.

.PARAMETER Version
    The release, as X.Y.Z or vX.Y.Z (e.g. 3.2.0).

.PARAMETER RepoRoot
    Alternative repo root. Defaults to CLAUDE_PROJECT_DIR, then the git toplevel. Exists so the test
    suite can run against a fixture without touching a real release, and so the script works from any
    directory.

.PARAMETER Force
    Overwrite an existing internal note. Without this flag the script refuses -- resetting an already
    written note back to a skeleton is a loss you do not want to make by accident.

.EXAMPLE
    ./scripts/release/new-internal-note.ps1 -Version 3.2.0
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Version,

    [string]$RepoRoot = '',

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before. Why: the lib's header.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# --- Anchor the repo root -------------------------------------------------------------------------
# Every path below is absolute and derived from this root. Deliberately no Set-Location: then a
# divergent process cwd cannot write into the wrong repo (the pitfall cut-release.ps1 has to close with
# an explicit anchor). Dual context first, the same contract every shared script here follows (#81).
if (-not $RepoRoot) {
    $RepoRoot = if ($env:CLAUDE_PROJECT_DIR) {
        $env:CLAUDE_PROJECT_DIR
    } else {
        $topLevel = git rev-parse --show-toplevel | Select-Object -First 1
        if (-not $topLevel) { Write-Error "No git repo found. Run this from the repo, or pass -RepoRoot."; exit 1 }
        $topLevel.Trim()
    }
}
if (-not (Test-Path -LiteralPath $RepoRoot -PathType Container)) {
    Write-Error "RepoRoot does not exist: $RepoRoot"; exit 1
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

# Set-ReleaseInternalNoteLink, for repointing the release history's row at this note once it exists
# (see the call near the end). $PSScriptRoot-relative, like every other shared script's dot-source, so
# the plugin mirror resolves its own copy rather than the consumer's repo root.
. (Join-Path $PSScriptRoot '..\lib\release-lib.ps1')
# Get-SeamValue (issue #885, group A): this used to be a private single-name copy defined below; it is
# now the one array-capable definition every seam reader in this workflow shares.
. (Join-Path $PSScriptRoot '..\lib\seam-lib.ps1')

# --- Parse the version --------------------------------------------------------------------------
$verNum = ($Version.Trim() -replace '^[vV]', '')
if ($verNum -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
    Write-Error "Version '$Version' is not X.Y.Z (e.g. 3.2.0)."; exit 1
}
$major = $Matches[1]
$minor = $Matches[2]

# --- The repo's own answers ----------------------------------------------------------------------
# Optional, all of them, each falling back to the English text below -- so a consumer that defines
# nothing still gets a working skeleton in this script's own language. Get-SeamValue itself now lives
# in seam-lib.ps1, dot-sourced above.

$configPath = Join-Path $RepoRoot 'scripts\repo-config.ps1'
if (Test-Path -LiteralPath $configPath) {
    try {
        . $configPath
    } catch {
        Write-Warning "scripts\repo-config.ps1 could not be loaded ($($_.Exception.Message)) -- writing the skeleton with the built-in English wording."
    }
}

# The notes folder scheme is answered ONCE for the whole repo (#417) and every tier reads it, so the
# internal note lands beside its developer notes rather than in a scheme of its own.
$grouping = Get-SeamValue -Name 'Get-ReleaseNotesGrouping' -Default 'major'
$notesDir = if ($grouping -eq 'minor') { "$major.$minor" } else { "$major.x" }

# THE DOCUMENT'S OWN WORDING (#410 class). Merged over these defaults rather than replacing them, so a
# consumer that renames one heading does not have to restate the rest.
$w = @{
    Title          = 'Internal summary'
    AudienceLabel  = 'For whom'
    Audience       = 'colleagues and management -- what the organisation gets out of this release'
    SkeletonNote   = @(
        'SKELETON. Edit this file and delete these comment blocks afterwards.',
        'The bullets below are the tier-1 and tier-2 entries of the developer notes -- tier 0 is',
        'repo-internal and deliberately absent. The [type] marker is a hint about what is',
        'worth keeping, and belongs gone once you rewrite the line. Keep it to one page at most:',
        '1-3 lines per subject, no file names, no code. Anything that means nothing to someone',
        'outside the team, remove -- this tier is not complete, it is readable.'
    ) -join "`n     "
    SectionChanged = 'What is different now'
    SectionValue   = 'What it is worth'
    HintValue      = @(
        'This is the core of this tier and the only part that cannot be generated. Think in time,',
        'risk and reduced dependence on a developer. For example: "changing an amount took five',
        'edits in code and can now be done by the team itself".'
    ) -join "`n     "
    SectionOpen    = 'What was still open at this release'
    HintOpen       = @(
        'What was deliberately left, and with whom the next step sits. "Nothing" is also an answer',
        '-- leave the heading standing with that one line.',
        'Write it as a SNAPSHOT of this release, not as a claim about the present. Where this note is',
        'the published release body it does not move with reality, so a line here goes stale in hours',
        'rather than months -- measured three times in one day, once by a line stating that the',
        'previous release had no public page, which its own author then published.'
    ) -join "`n     "
    NoEntries      = '(no entries found -- fill in by hand)'
    Unknown        = '(fill in)'
}
$override = Get-SeamValue -Name 'Get-InternalNoteWording' -Default @{}
if ($override) { foreach ($k in $override.Keys) { $w[$k] = $override[$k] } }

# SEAMED (issue #885, group E), and MUST AGREE WITH cut-release.ps1's OWN READ of the same two roots --
# both are Get-SeamValue reads of the same seam names, falling back to the same computed defaults, so a
# repo that configures either seam is read the same way by both scripts. That agreement is why the
# tier-0 root's retired name is listed HERE too and in the same order (issue #947): a repo still
# carrying Get-ReleaseDevelopmentNotesRoot must be answered identically by both, or the cut writes its
# note in one tree and this script looks for it in another.
$devRootRel = Get-SeamValue -Name 'Get-ReleaseChangelogNotesRoot', 'Get-ReleaseDevelopmentNotesRoot' -Default (Get-DefaultReleaseChangelogNotesRoot -RepoRoot $RepoRoot)
Assert-WorkflowIsolatedSeamPath -RepoRoot $RepoRoot -RelativePath $devRootRel -SeamName 'Get-ReleaseChangelogNotesRoot'
$intRootRel = Get-SeamValue -Name 'Get-ReleaseInternalNotesRoot' -Default (Get-DefaultReleaseInternalNotesRoot -RepoRoot $RepoRoot)
Assert-WorkflowIsolatedSeamPath -RepoRoot $RepoRoot -RelativePath $intRootRel -SeamName 'Get-ReleaseInternalNotesRoot'
$devRel = "$devRootRel/$notesDir/$verNum.md"
$intRel = "$intRootRel/$notesDir/$verNum.md"
$devFile = Join-Path $RepoRoot ($devRel -replace '/', '\')
$intFile = Join-Path $RepoRoot ($intRel -replace '/', '\')

# --- Refuse where nothing sensible can be done ----------------------------------------------------
# The developer notes are the INPUT: without them there is no title to carry over and no date/type to
# copy. So this is a hard precondition rather than a precaution -- cut the release first.
if (-not (Test-Path -LiteralPath $devFile -PathType Leaf)) {
    Write-Error ("Developer notes not found: $devRel`n" +
                 "Cut the release first with scripts/release/cut-release.ps1, or check the version.")
    exit 1
}
if ((Test-Path -LiteralPath $intFile) -and -not $Force) {
    Write-Error "$intRel already exists. Use -Force to overwrite it (you lose the text you filled in)."
    exit 1
}

# --- Read the developer notes ---------------------------------------------------------------------
$dev = [System.IO.File]::ReadAllText($devFile, [System.Text.Encoding]::UTF8)

function Get-MetaLine {
    param([string]$Text, [string]$Label)
    # BOTH SPELLINGS OF THE MARKDOWN HARD BREAK ARE TRIMMED (inbound #1100): release-lib.ps1 wrote two
    # trailing spaces until that repair and writes a trailing backslash now, and every note already
    # published carries the old form. Without the backslash in this class the date would be carried into
    # the internal note as '2026-08-29\' -- a silently wrong value rather than a loud failure, which is
    # exactly the shape a parser change has to be checked for.
    $m = [regex]::Match($Text, "(?m)^\*\*${Label}:\*\*\s*(.+?)[\s\\]*$")
    if ($m.Success) { return $m.Groups[1].Value }
    return ''
}

# Read against the label release-lib.ps1 actually writes ('**Date:**' / '**Type:**'). A repo whose notes
# use different labels gets the '(fill in)' fallback and a warning rather than a silently blank line.
$date = Get-MetaLine -Text $dev -Label 'Date'
$typeLabel = Get-MetaLine -Text $dev -Label 'Type'
if (-not $date) {
    Write-Warning "No '**Date:**' line in $devRel -- fill in the date by hand."
    $date = $w.Unknown
}
if (-not $typeLabel) {
    Write-Warning "No '**Type:**' line in $devRel -- fill in the type by hand."
    $typeLabel = $w.Unknown
}

# --- Carry over the entry titles, TIER 1 AND UP ----------------------------------------------------
# AN ENTRY IS RECOGNISED BY ITS STRUCTURE -- the named sections it contains -- and its type is read from
# the section that states it. That is the second rewrite of this recogniser, and the first one is the
# reason the rule is now structural rather than lexical.
#
# IT USED TO MATCH THE HEADING'S METADATA FIELDS: '#NN <midDot> title <midDot> type <midDot> date', with
# "three or more middot fields" as the test for "this is an entry" and the second-to-last field as the
# type. That was correct while a heading carried metadata, and the format took it apart in two steps --
# the merge date moved to the closing line, then the type moved into its own section, and finally the PR
# number followed the date. Each step removed a field, and at two fields every real entry fell below the
# threshold.
#
# MEASURED BEFORE REWRITING IT, against a note generated from the live changelog: 46 headings skipped, all
# ten entries among them, and the ONE heading that still matched the old shape was a QUOTED example inside
# a fenced code block in an entry body -- which became the note's only bullet, with the illustration's own
# words as its type. A document written for colleagues, listing one line that describes nothing. It failed
# in the direction this repo keeps paying for: no error, plausible output, and a warning that said the
# opposite of what had happened.
#
# SO THE TEST IS: a heading is an ENTRY heading when the headings ONE LEVEL BELOW it, inside its own block,
# include one of the format's named sections. That is level-independent by construction, which matters
# because the level genuinely differs per document -- entries sit at H3 under the tier headings here, and
# at H2 in the untiered shape. It also cannot confuse a heading with its container: one level below a tier
# heading are the entry headings, and one level below the H1 are the tier headings. Neither is a section.
#
# THE TYPE COMES FROM Resolve-EntryType, on the block re-levelled back to canonical depth with
# Set-EntryHeadingLevel. Both already exist and both already handle the pre-format shape (the type as a
# heading field), so history keeps parsing through the same path rather than through a second branch here.
# The title goes through Convert-EntryHeadingToTitle for the same reason: a historical heading still
# carries '#NN' and a type and a date, and this document's reader wants none of them.
#
# FENCE-AWARE, which the old walk was not -- and that is exactly how a quoted example became a bullet.
#
# ONLY TIER 1 AND ABOVE REACH THIS DOCUMENT. Under the cumulative ladder the notes this script reads
# were written under (pre-#620), tier 2 implied tier 1, so a tier-2 entry belongs here as well as in the
# consumer document -- and that inclusion is kept, because every existing note carries such entries. Tier 0 is repo-internal by definition -- it is in the developer notes, which is where the
# record belongs, and putting it here would rebuild exactly the document this tier exists to avoid.
#
# WHERE THAT TIER IS READ FROM: THE ENTRY, AND ONLY THEN ITS CONTAINER (#881, August 25, 2026). This used
# to be answered by the '## Tier <n>' heading the developer notes grouped their entries under, and that
# heading is gone -- the notes render at CHANGELOG.md's own levels now. Falling back to "no tier headings
# means take everything" would have carried every tier-0 entry into the document tier 0 exists to stay out
# of, with no error and plausible output: the failure mode this file already pays for twice.
#
# So the entry's OWN declaration decides, via Resolve-EntryImpact -- the same reader
# Get-PullRequestEntriesByTier groups on, so the two cannot disagree about what an entry claims. The
# container heading stays as the FALLBACK, because it is the only tier information an archived note carries
# whose entries pre-date the declaration entirely, and this script takes a VERSION: it can be run against
# any release ever cut.
#
# NOTES WITH NO TIER INFORMATION AT ALL take everything, which is the repo-without-a-tier-split case: there
# is nothing to filter on, so filtering would empty the document rather than focus it. Read from BOTH
# sources -- a declared entry anywhere, or a tier heading anywhere -- because either one alone would answer
# 'untiered' for a document the other can read.
$bullets = New-Object System.Collections.Generic.List[string]

$hasTierHeadings = [regex]::IsMatch($dev, '(?m)^##\s+Tier\s+\d+\b')
$skippedTier0 = 0

$devLines = @($dev -split "`r?`n")
$devFenced = Get-FencedLineFlags -Lines $devLines
# Current names plus retired ones: this reads the DEVELOPMENT NOTES, which are the archive, so most of
# what it walks was written under an older set of headings. See Get-EntryRetiredSectionHeadings.
$sectionNames = @((Get-EntrySectionHeadings).Values) + @(Get-EntryRetiredSectionHeadings)

# Every heading outside a fence, with its level -- one pass, so the scans below agree about what a heading is.
$heads = @()
for ($i = 0; $i -lt $devLines.Count; $i++) {
    if ($devFenced[$i]) { continue }
    $m = [regex]::Match($devLines[$i], '^(#{1,6})\s+(.+?)\s*$')
    if ($m.Success) {
        $heads += [pscustomobject]@{
            Index = $i
            Level = $m.Groups[1].Value.Length
            Text  = $m.Groups[2].Value.Trim()
        }
    }
}

$currentTier = $null
$found = New-Object System.Collections.Generic.List[pscustomobject]
for ($h = 0; $h -lt $heads.Count; $h++) {
    $head = $heads[$h]

    $tierMatch = [regex]::Match($devLines[$head.Index], '^##\s+Tier\s+(\d+)\b')
    if ($tierMatch.Success) { $currentTier = [int]$tierMatch.Groups[1].Value; continue }

    # The block: everything up to the next heading at this level or shallower.
    $blockEnd = $devLines.Count - 1
    for ($k = $h + 1; $k -lt $heads.Count; $k++) {
        if ($heads[$k].Level -le $head.Level) { $blockEnd = $heads[$k].Index - 1; break }
    }
    # Is one of the headings directly under it a named section? That is what makes it an entry.
    $isEntry = $false
    for ($k = $h + 1; $k -lt $heads.Count; $k++) {
        if ($heads[$k].Index -gt $blockEnd) { break }
        if ($heads[$k].Level -eq ($head.Level + 1) -and ($sectionNames -ccontains $heads[$k].Text)) { $isEntry = $true; break }
    }

    # RECOGNISE BOTH, WRITE ONE -- the rule this format has already applied to the tier declaration and to
    # the entry heading, and it applies here for a reason that is easy to miss: this script takes a VERSION
    # and reads that release's development notes off disk, so it can be run against any release ever cut.
    # Every note written before the named sections existed has entries with no sections at all, and the
    # structural test above cannot see them -- so a note regenerated for an older release would come back
    # empty. The pre-format shape is therefore still recognised, by the metadata triple its headings carry.
    #
    # TWO GUARDS, EACH ENOUGH ON ITS OWN, because this is the shape that produced the fabricated bullet:
    # the walk is fence-aware now (a quoted illustration is not a heading at all), AND the type field must
    # be a type this repo's branch table actually produces. The illustration that got through read
    # '#NNN <midDot> Short strong title <midDot> Feat' -- three fields, but the second-to-last is a title,
    # so a known-type check rejects it even without the fence.
    if (-not $isEntry) {
        $parts = @($head.Text -split "\s*$([char]0x00B7)\s*")
        if ($parts.Count -ge 3) {
            $candidate = $parts[$parts.Count - 2].Trim()
            if ((Get-ReleaseChangeTypes) -ccontains $candidate) { $isEntry = $true }
        }
    }
    if (-not $isEntry) { continue }

    $block = (@($devLines[$head.Index..$blockEnd]) -join "`n")
    # Re-levelled to the format's own depth so the section readers find what they look for, whatever depth
    # this document renders at.
    $canonical = Set-EntryHeadingLevel -EntryText $block -EntryLevel (Get-EntryHeadingLevel)
    $type = (Resolve-EntryType -EntryText $canonical).Type
    # The whole heading LINE goes in, hashes included, and the hashes come off after: that function matches
    # '^(#+)\s+' and returns its input untouched without them -- so passing the bare text would silently stop
    # stripping the metadata a historical heading still carries, which is the one case it exists for.
    $title = (((Convert-EntryHeadingToTitle -EntryText $devLines[$head.Index]) -split "`r?`n")[0] -replace '^#+\s+', '').Trim()

    if (-not $title) { continue }

    # THE ENTRY'S OWN REACH FIRST, ITS CONTAINER SECOND -- collected rather than filtered here, because
    # whether this note is tiered at all is a property of the WHOLE document and cannot be known until
    # every entry has been read.
    $impact = Resolve-EntryImpact -EntryText $canonical
    $found.Add([pscustomobject]@{
        Tier     = if ($impact.Declared) { [int]$impact.Tier } else { $currentTier }
        Declared = [bool]$impact.Declared
        Bullet   = if ($type) { "- [$type] $title" } else { "- $title" }
    })
}

# A tiered note is one where SOMETHING declares a tier: an entry, or a grouping heading. Where nothing
# does, every entry comes over -- see the comment above the walk.
$hasTierInfo = $hasTierHeadings -or (@($found | Where-Object { $_.Declared }).Count -gt 0)
foreach ($item in $found) {
    if ($hasTierInfo -and ($null -eq $item.Tier -or [int]$item.Tier -lt 1)) {
        if ($null -ne $item.Tier -and [int]$item.Tier -eq 0) { $skippedTier0++ }
        continue
    }
    $bullets.Add($item.Bullet)
}

if ($bullets.Count -eq 0) {
    # Distinguished on purpose: "this release was all repo-internal" is a different situation from "the
    # notes did not parse", and the second is a defect while the first is a release that legitimately has
    # little to say to a colleague.
    if ($skippedTier0 -gt 0) {
        Write-Warning "Every entry in $devRel is tier 0 ($skippedTier0 of them) -- nothing in this release reaches beyond this repo's own developers, so the list is empty. Write the note from what you know, or reconsider whether those tiers are right."
    } else {
        Write-Warning "No entry titles found in $devRel -- the skeleton gets an empty list."
    }
    $bullets.Add("- $($w.NoEntries)")
}

# --- Write the skeleton ---------------------------------------------------------------------------
$nl = "`r`n"
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

$skeleton =
    # Blank line after the H1, matching what release-lib.ps1 writes for the other two tiers -- three
    # documents of one release sitting side by side should not differ in shape, or the difference becomes
    # something a later reader "fixes" in the wrong place. It is also what markdown linters expect.
    "# $($w.Title) v$verNum$nl$nl" +
    # THE BACKSLASH IS A MARKDOWN HARD BREAK, and these two lines carry it for the same reason
    # release-lib.ps1's three documents do (inbound #1101, completing inbound #1100). A single newline
    # inside a markdown paragraph is a SOFT break, so without it the three labels render as ONE visual
    # line -- "Date: ... Type: ... For whom: ..." -- while the changelog note, the GitHub Release body
    # and the audience note render three. That is precisely the difference the comment above says these
    # documents must not have, sitting four lines below it.
    #
    # THE THIRD LABEL TAKES NO BREAK, and that is the shape rather than an omission: it is the last line
    # of the block and a blank line follows, which ends the paragraph on its own. Build-AudienceNote
    # writes exactly the same three lines with exactly the same two breaks.
    #
    # WHY THE BACKSLASH AND NOT TWO TRAILING SPACES: the older spelling of the same break made every
    # generated release document fail an ordinary "no trailing whitespace" lint rule, measured in a
    # consumer whose trunk went red on files it had not written (inbound #1100). Get-MetaLine above
    # already tolerates both spellings on the way back in.
    "**Date:** $date\$nl" +
    "**Type:** $typeLabel\$nl" +
    "**$($w.AudienceLabel):** $($w.Audience)$nl" +
    $nl +
    "<!-- $($w.SkeletonNote)$nl" +
    "     Source: $devRel -->$nl" +
    $nl +
    "## $($w.SectionChanged)$nl" +
    $nl +
    ($bullets -join $nl) + $nl +
    $nl +
    "## $($w.SectionValue)$nl" +
    $nl +
    "<!-- $($w.HintValue) -->$nl" +
    $nl +
    "## $($w.SectionOpen)$nl" +
    $nl +
    "<!-- $($w.HintOpen) -->$nl"

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $intFile) | Out-Null
[System.IO.File]::WriteAllText($intFile, $skeleton, $Utf8NoBom)

# --- Point the release history's row at this note --------------------------------------------------
# The cut wrote the DEVELOPER link, because that is the only one that exists while it runs: it commits
# and tags in one motion, and this note is written afterwards. So the moment the note exists is the
# moment the link can be corrected -- here, in the same change that adds the file, so the two cannot
# disagree. Doing it at cut time would have put a dead relative link inside an immutable tag.
#
# THE TARGET FILE MOVED, NOT THE MECHANISM (Dave, August 5, 2026). This used to rewrite the notes line
# inside CHANGELOG.md's release block, and that block is gone: a cut now empties the changelog down to its
# intro. Left pointed at the changelog this step would not have ERRORED either -- the function returns its
# input unchanged when it finds nothing -- it would simply have gone quiet, and the internal note would
# have had no inbound link anywhere. So it repoints the Version cell of the release history's row, which
# is the one place that still lists releases.
#
# Best-effort by design: a release that has already succeeded must not be reported as failed over a
# link. Set-ReleaseInternalNoteLink returns the content untouched when it finds nothing to change, and
# it is idempotent, so a second run is harmless.
#
# THE PATHS ARE RELATIVE TO THE HISTORY FILE'S OWN FOLDER, not to the repo root, because that is how its
# rows are written ('development/3.x/3.6.0.md'). $intRel/$devRel are repo-root-relative, so the
# 'releases/' prefix comes off here -- derived from the seam's own path rather than hardcoded, so a repo
# that keeps its history somewhere else is not silently mis-linked.
$historyRelPath = Get-SeamValue -Name 'Get-ReleaseHistoryPath' -Default 'releases/README.md'
$historyFile = Join-Path $RepoRoot ($historyRelPath -replace '/', '\')
$historyDirPrefix = (Split-Path -Parent ($historyRelPath -replace '\\', '/')) -replace '\\', '/'
if ($historyDirPrefix) { $historyDirPrefix = $historyDirPrefix.TrimEnd('/') + '/' }
$historyTouched = $false
if (Test-Path -LiteralPath $historyFile -PathType Leaf) {
    $hBefore = [System.IO.File]::ReadAllText($historyFile, [System.Text.Encoding]::UTF8)
    $intForRow = if ($historyDirPrefix -and $intRel.StartsWith($historyDirPrefix)) { $intRel.Substring($historyDirPrefix.Length) } else { $intRel }
    $devForRow = if ($historyDirPrefix -and $devRel.StartsWith($historyDirPrefix)) { $devRel.Substring($historyDirPrefix.Length) } else { $devRel }
    $hAfter = Set-ReleaseInternalNoteLink -Content $hBefore -Version $verNum `
        -InternalRelPath $intForRow -DevRelPath $devForRow
    if ($hAfter -ne $hBefore) {
        [System.IO.File]::WriteAllText($historyFile, $hAfter, $Utf8NoBom)
        $historyTouched = $true
    }
}

Write-Host ""
Write-Host "read    :  $devRel  ($($bullets.Count) entry title(s))"
Write-Host "created :  $intRel  (skeleton -- edit it now)"
if ($historyTouched) {
    Write-Host "updated :  $historyRelPath  (the row for v$verNum now points at this note)"
} else {
    Write-Host "skipped :  $historyRelPath  (no row for v$verNum to repoint, or it already points here -- nothing changed)"
}
Write-Host ""
Write-Host "Step 1 -- fill in the note (the three headings stay):"
Write-Host "  code $intRel"
Write-Host ""
# Via a branch + PR, NOT appended to the release commit. cut-release.ps1 has already committed and
# tagged by the time this script can run (it needs the developer notes as input), so this file is a
# separate change -- and a hand-written document is exactly the kind that belongs in a reviewed PR.
Write-Host "Step 2 -- ship it like any other change (the release commit is already tagged):"
Write-Host "  the new-branch skill, then open-pr / ship-pr"
Write-Host ""
