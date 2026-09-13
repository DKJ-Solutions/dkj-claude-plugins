<#
.SYNOPSIS
    The changelog entry's own format, in one place: the scaffold strings new-branch.ps1
    WRITES and open-pr.ps1 REFUSES TO SHIP, the entry's heading levels and named sections, the impact
    table declaring how far a change reaches and what it weighs at each reach, and the ranked offset the
    fold inserts it at.

.DESCRIPTION
    Dot-source it:

        . (Join-Path $PSScriptRoot '..\lib\entry-scaffold-lib.ps1')

    WHY THIS FILE EXISTS AT ALL, given it holds three strings. Those three had to be known by two
    scripts that must never disagree about them: one writes the scaffold, the other blocks a PR whose
    entry still carries it. A copy in each would make the gate silently miss whatever the writer
    changed -- a drift guard that drifts, which is worse than no guard because it reports success. So
    the wording became a single source the moment the second reader appeared, exactly as CLAUDE.md
    requires for a rule living in two places.

    THE IMPACT DECLARATION JOINED IT FOR THE SAME REASON, WITH ONE MORE READER (the tier model, August 5,
    2026). How far a change reaches is written by new-branch.ps1, validated by open-pr.ps1 before a
    PR can ship, read by fold-changelog-entry.ps1 to decide where in CHANGELOG.md the entry lands, and read
    again by the release cut to decide which documents it appears in. Four scripts, one format: a copy in
    each is how a fold starts filing tier-2 work as repo-internal without anything erroring.

    THE DECLARATION IS NOW A TABLE, AND THE OLDER 'Tier: N' LINE IS STILL RECOGNISED -- this repo's standing
    "recognise both, write one" rule, because every entry already merged and every entry in a consumer's tree
    predates the table.

    REPO-OWNED, WITH BUILT-IN DEFAULTS (#410). Each string comes from an OPTIONAL function in the
    consumer's scripts/repo-config.ps1 -- Get-EntryTitlePlaceholder, Get-EntryBodyHeading,
    Get-EntryBodyPlaceholder -- probed with Get-Command and falling back to the English value
    new-branch.ps1 used to hardcode. A consumer that defines none of them is unaffected.
    (Get-EntryFallbackType is deliberately NOT here: it is a changelog TYPE, not scaffold prose --
    'Chore' is a legitimate final value, so it can never be evidence of an unedited entry.)

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script. Depends on
    Get-DisplayRef (ref-print-lib.ps1), which it loads itself -- see the dot-source below.

    Pure ASCII (repo convention for .ps1).
#>

# THE STRIP HAS ONE DEFINITION, AND IT IS NOT HERE (issue #1623 settled that, #1650 brought the third
# caller). Get-DevelopmentShapeFindings prints a line of somebody's branch document back to a console and to
# a public CI log, which is the one kind of text this repo treats as an injection surface rather than a
# display question: an ANSI or OSC escape in it repaints the terminal it lands in, and a zero-width run
# makes the printed line read as something other than what it says -- by the very line that exists to tell
# the reader what is wrong. Unconditional, and $PSScriptRoot-relative rather than repo-relative, so it
# resolves in the plugin mirror as well as here; remote-ahead-lib.ps1 and release-lib.ps1 load their
# siblings the same way. ref-print-lib.ps1 is a leaf with no dependencies of its own, which is what makes
# it safe to load first.
. (Join-Path $PSScriptRoot 'ref-print-lib.ps1')

# THE FUNCTION-TABLE PROBE (issue #1729). Same unconditional, $PSScriptRoot-relative shape as
# ref-print-lib above and for the same reason -- it has to resolve in the plugin mirror as well as
# here -- and it is likewise a leaf with no dependencies of its own. This lib carries ten seam probes,
# more than any other file in the tree, and Get-ReleaseAudienceTier's is the frame #1723 faulted in.
. (Join-Path $PSScriptRoot 'command-probe-lib.ps1')

# THE DOCUMENT-NEWLINE READING (issue #1832): Get-DocumentNewline, where the two sites below hand-typed
# it. Same unconditional, $PSScriptRoot-relative shape as the two leaves above and for the same reason --
# it has to resolve in the plugin mirror as well as here -- and it is likewise a leaf with no dependencies
# of its own. Loaded HERE rather than in each caller because release-lib, cut-release,
# fold-changelog-entry and adopt-workflow-folder all already load this file, so they reach the helper
# without gaining a dependency.
. (Join-Path $PSScriptRoot 'document-newline-lib.ps1')

# THE FETCH-FRESHNESS SEAM (issue #1860): Invoke-RecordedRemoteFetch, which Get-TrunkGap's fetch now runs
# through so that claim-issue.ps1 and this file do not each buy the same network call at the opening of
# an assignment. Same unconditional, $PSScriptRoot-relative shape as the three leaves above and for the
# same reason -- it has to resolve in the plugin mirror as well as here -- and it is likewise a leaf with
# no dependencies of its own, Invoke-NativeCapture excepted, which Get-TrunkGap has always required of
# its caller anyway.
. (Join-Path $PSScriptRoot 'fetch-attempt-lib.ps1')

# The English fallbacks, and the ONLY copy of them. new-branch.ps1 held these literals until
# the gate needed the same list; it now reads them from here.
#
# TWO OF THESE ARE NO LONGER WRITTEN, ONLY RECOGNISED (Dave, August 6, 2026). Until the branch/ split the
# entry file was also the branch's to-do list, so new-branch.ps1 scaffolded it with a
# '**To do / where I left off:**' heading over a matching placeholder. branch-cycle.md holds that job
# now, and an entry that still asked for a to-do list would re-create the exact confusion the split
# removes. So the writer stops writing them and the GATE KEEPS REFUSING THEM -- "recognise both, write
# one", the same rule the tier line gets. This is not politeness towards history: every consumer with a
# branch in flight has an entry carrying these strings right now, and they reach the new scripts through
# a plugin update rather than by choosing to. A gate that forgot them would wave those entries through
# into CHANGELOG.md, silently, which is the one failure mode a guard must not have.
$script:EntryScaffoldDefaults = [ordered]@{
    Title         = 'TODO: title'
    BodyHeading   = '**To do / where I left off:**'
    BodyPlaceholder = 'TODO: what this change does, for whoever reads CHANGELOG.md later.'
}

# Recognised by the gate, never written by anything, and deliberately NOT repo-configurable: it is a
# historical string, so there is nothing for a consumer to choose about it. Kept separate from the map
# above rather than folded into BodyPlaceholder because that one IS seamed -- a repo that overrode the
# placeholder would otherwise lose the legacy marker along with the default it replaced.
$script:EntryScaffoldLegacyMarkers = @(
    'TODO: what still needs to happen on this branch, and where you left off.',
    # Retired with the dossier form (August 6, 2026): the tier sub-sections were scaffolded with a visible
    # why-placeholder under their guidance comment, and now carry the comment alone. Still refused, for the
    # reason all of these are -- every branch in flight, here and in every consumer, has one in its entry
    # right now, and a gate that forgot it would wave exactly those into CHANGELOG.md.
    'TODO: why this change matters at this reach.'
)

function Get-EntryScaffoldWording {
    <#
        Returns the scaffold wording as an object with Title, BodyHeading and BodyPlaceholder --
        this repo's answers where repo-config.ps1 gives them, the English defaults otherwise.

        The caller is expected to have dot-sourced repo-config.ps1 already (both callers do, for other
        reasons); this function only PROBES, it does not load it. That keeps it usable from a test that
        wants the bare defaults, by simply not defining the getters.

        An override that is present but EMPTY is ignored rather than honoured. A getter returning ''
        would otherwise blank a marker, and a blank marker matches every entry ever written -- so the
        gate would refuse every PR in the repo, which is the worst possible failure for a guard whose
        whole job is to be trusted.
    #>
    $out = [ordered]@{}
    $map = @{
        Title           = 'Get-EntryTitlePlaceholder'
        BodyHeading     = 'Get-EntryBodyHeading'
        BodyPlaceholder = 'Get-EntryBodyPlaceholder'
    }
    foreach ($key in @('Title', 'BodyHeading', 'BodyPlaceholder')) {
        $value = $script:EntryScaffoldDefaults[$key]
        $getter = $map[$key]
        if (Test-FunctionDefined $getter) {
            $v = & $getter
            if ($v) { $value = $v }
        }
        $out[$key] = $value
    }
    return [pscustomobject]$out
}

function Get-FencedLineFlags {
    <#
        Returns a bool per input line: is that line inside a fenced code block? The fence MARKER itself is
        reported as fenced ($true), so a caller that skips fenced lines keeps the markers with their content
        rather than stripping them and leaving the body inside rendered as prose.

        THE ONE FENCE READER OF THIS FORMAT, and it lives here because this is the lower lib. Every markdown
        structure test in the entry format has to ask this question -- '^## ' for an entry boundary, '^---$'
        for a separator, 'Tier:' for a declaration, the impact table's header row, the three section
        headings -- and every one of them must NOT fire on text an entry body QUOTES. An entry may
        legitimately show a broken heading structure, a YAML frontmatter example, or the very format it
        introduces, and treating that as structure is the defect class this system has now paid for at
        least five times:

          * cutting v2.13.3 produced a third entry from two PRs, split a fence open, and duplicated a
            category heading in the release notes;
          * the fold would have deleted a 'Tier: 0' line out of the fence that was explaining it;
          * a quoted impact table would have disabled the reader that met it first;
          * and on the fold of PR #478 a quoted entry heading split a real entry in two, so the fragment
            above its impact table read as tier 0 and a tier-1 entry was inserted at the top of a list
            whose next six entries were tier 2.

        SO THERE IS ONE ANSWER AND ONE PLACE THAT GIVES IT. Until this change there were two named
        functions with this job -- this one and Get-FencedLineFlags in release-lib.ps1 -- plus two inline
        walks in this file. Four walks, and they were NOT equivalent: the release-lib one recognised '~~~'
        fences and the three here did not, so an entry using tilde fences had its quoted content read as
        structure by every reader in this file while release-lib's readers handled it correctly. That
        difference is exactly what "two answers that can drift" means, found by comparing them rather than
        by anything failing. The union rule wins, so the tilde form is now honoured everywhere.

        Deliberately simple: a line whose first non-space characters are ``` or ~~~ toggles the state.
        That is CommonMark's own rule for the common cases and needs no parser. Nested fences of the same
        kind are not a thing in CommonMark, and an unclosed fence leaves the tail flagged as fenced --
        which is the safe direction for every caller here, since it can only cause a missed finding, never
        a false accusation against text somebody did write.

        The name is deliberately NOT entry-specific: release-lib's readers scan a whole CHANGELOG rather
        than one entry, and they call this by exactly this name -- so moving the owner down a layer changed
        no call site in either lib.
    #>
    # Not Mandatory, and both Allow* attributes: a changelog section can legitimately be a single empty
    # line, and a Mandatory [string[]] rejects '' outright (ParameterArgumentValidationError).
    param([AllowEmptyString()][AllowEmptyCollection()][string[]]$Lines = @())
    if ($null -eq $Lines) { return @() }
    $flags = New-Object 'bool[]' $Lines.Count
    $inFence = $false
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '^\s*(```|~~~)') {
            $flags[$i] = $true          # the marker belongs to the block
            $inFence = -not $inFence
        } else {
            $flags[$i] = $inFence
        }
    }
    return $flags
}

function Get-EntryLineFlagPairs {
    <#
        Private helper: an entry split so that a caller can rewrite it line by line WITHOUT losing the
        original line endings, with the fence state already resolved. Returns an object with

          Parts   the [regex]::Split result, separators kept (odd indices are the separators)
          Fenced  one bool per CONTENT line, in order, from Get-FencedLineFlags

        WHY THIS EXISTS: the two removers below (Remove-EntryTierLine, Remove-EntryImpactTable) each used
        to walk the fences themselves while deciding what to drop. That is where two of this file's four
        fence walks lived, and it is why neither recognised '~~~'. They need the flags AND the separators,
        which is an awkward pair to derive twice -- so it is derived once, here, and both read it.

        The separators are preserved rather than normalised because the caller has already matched its
        document's own style; rewriting them would put CRLF and LF in one entry.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$EntryText)
    $parts = [regex]::Split($EntryText, '(\r?\n)')
    $contents = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $parts.Count; $i += 2) { $contents.Add($parts[$i]) }
    return [pscustomobject]@{
        Parts  = $parts
        Fenced = @(Get-FencedLineFlags -Lines @($contents.ToArray()))
    }
}

function Get-EntryTextOutsideFences {
    <#
        Pure: the entry's text with every fenced code block removed, for a caller that wants to match
        STRUCTURE rather than a mention of it.

        ITS OWN FUNCTION BECAUSE TWO READERS NEEDED THE SAME STRIPPING. The scaffold gate needs it
        because an entry may legitimately quote the scaffold while documenting this very mechanism --
        this repo's own docs do -- and the tier reader needs it for exactly the same reason, one
        mechanism later. This repo has measured the cost of the alternative four times in one day: a
        matcher satisfied by a MENTION rather than a use.

        Deliberately simple: pair up ``` runs and drop what is between them. An unclosed fence
        swallows the tail, which is the safe direction for both callers -- it can only cause a missed
        finding, never a false accusation against text somebody did write.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$EntryText)
    # Read off the shared flags rather than walking the fences again, so this and every other reader of the
    # format agree about where a block starts. A marker line is flagged, so it is dropped exactly as the
    # old inline 'continue' dropped it -- and a '~~~' fence is now recognised too, which it was not.
    $lines = @($EntryText -split '\r?\n')
    $fenced = Get-FencedLineFlags -Lines $lines
    $kept = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if (-not $fenced[$i]) { $kept.Add($lines[$i]) }
    }
    return ($kept -join "`n")
}

function Get-EntryCodeSpans {
    <#
        Pure: where the CODE and the COMMENTS sit in an entry, as spans over the text exactly as it was
        given -- an array of objects with Start and Length, ordered by Start. Three
        kinds, in the order they are resolved: fenced blocks (``` and ~~~, off the shared flags), inline
        code spans, and html comments. That is the same set, in the same order, that Get-EntryLinkTargets
        has excluded since it existed.

        IT EXISTS BECAUSE A STRIPPER ONLY SERVES A READER (inbound #1052, August 28, 2026). The exclusion
        was written as three successive deletions, which is everything a reader needs -- it looks at what
        is left and never has to hand the text back. A REWRITER cannot use that shape at all: it has to
        return the entry with the illustrations still in it, so it needs to know WHERE the code is rather
        than to be handed the text without it. So the two halves of one rule were a stripper and nothing,
        and the cut rewrote markdown links inside fences that the gate judging those links never saw.
        Offsets are the form both can use: the reader deletes them (Remove-EntryCodeSpans below), the
        rewriter skips any match that begins inside one.

        MASKED, NOT STRIPPED, BETWEEN THE PASSES, which is what keeps the offsets true. Each pass blanks
        what it found before the next one runs, so a stray backtick inside a fence cannot pair with one in
        the prose after it, and a comment inside a fence costs nothing -- the same ordering the stripper
        had, for the same reasons, with the character positions preserved.

        An unclosed fence swallows the tail, exactly as Get-FencedLineFlags does. For a reader that can
        only cost a missed finding; for the rewriter it can only leave a link alone, which is the same
        safe direction -- a link that resolves against the wrong directory is visible, and a mangled
        illustration in a tagged release document is not.

        AND THE SPANS CAN OVERLAP, which is why nothing here claims otherwise. Two stray single backticks
        on either side of a fenced block pair with each other across it and yield one span containing the
        fenced ones, because the masking blanks a fence rather than closing it off. That is not new and it
        is not this function's to decide: the three strippers it replaced behaved identically, so the link
        gate has read that shape the same way for as long as it has existed, and changing it here would
        change what the gate finds rather than what the cut rewrites. Both readers below tolerate it --
        Remove-EntryCodeSpans advances its cursor monotonically and Test-EntryOffsetInCodeSpans asks each
        span independently -- and the two halves still agree, which is the invariant that matters.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$EntryText)
    if (-not $EntryText) { return @() }
    $spans = New-Object System.Collections.Generic.List[object]
    $chars = $EntryText.ToCharArray()

    # 1. Fenced blocks, line by line: the shared pair gives the flags AND the separators, so the offset
    #    walks the original text rather than a rejoined copy that may have normalised the line endings.
    $pair = Get-EntryLineFlagPairs -EntryText $EntryText
    $offset = 0
    $lineIndex = 0
    for ($i = 0; $i -lt $pair.Parts.Count; $i++) {
        $part = [string]$pair.Parts[$i]
        if ($i % 2 -eq 0) {
            if ($part.Length -gt 0 -and $pair.Fenced[$lineIndex]) {
                $spans.Add([pscustomobject]@{ Start = $offset; Length = $part.Length })
                for ($k = 0; $k -lt $part.Length; $k++) { $chars[$offset + $k] = ' ' }
            }
            $lineIndex++
        }
        $offset += $part.Length
    }

    # 2. Inline code spans, matching a run of backticks with the same run closing it, so '``a`b``' is one
    #    span rather than two. Non-greedy, and (?s) because a span may legitimately wrap a line in prose.
    foreach ($m in [regex]::Matches((-join $chars), '(?s)(`+).*?\1')) {
        $spans.Add([pscustomobject]@{ Start = $m.Index; Length = $m.Length })
        for ($k = 0; $k -lt $m.Length; $k++) { $chars[$m.Index + $k] = ' ' }
    }

    # 3. HTML comments last: the guidance blocks the scaffolder writes are comments, and one of them shows
    #    the fold's closing line.
    foreach ($m in [regex]::Matches((-join $chars), '(?s)<!--.*?-->')) {
        $spans.Add([pscustomobject]@{ Start = $m.Index; Length = $m.Length })
    }

    return @($spans | Sort-Object -Property Start)
}

function Remove-EntryCodeSpans {
    <#
        Pure: the entry with every code span and html comment cut out -- the reader's half of
        Get-EntryCodeSpans, for a caller that wants to match PROSE and never has to give the text back.

        It is not Get-EntryTextOutsideFences: that one drops whole fenced LINES and answers only the first
        of the three questions. This drops exactly the spans, so a fenced line leaves its line break behind
        and an inline span leaves the prose around it intact -- which is what a scanner wants and what a
        line-oriented reader must not have.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$EntryText)
    $spans = @(Get-EntryCodeSpans -EntryText $EntryText)
    if ($spans.Count -eq 0) { return $EntryText }
    $sb = New-Object System.Text.StringBuilder
    $cursor = 0
    foreach ($span in $spans) {
        if ($span.Start -gt $cursor) { [void]$sb.Append($EntryText.Substring($cursor, $span.Start - $cursor)) }
        $cursor = [Math]::Max($cursor, $span.Start + $span.Length)
    }
    if ($cursor -lt $EntryText.Length) { [void]$sb.Append($EntryText.Substring($cursor)) }
    return $sb.ToString()
}

function Test-EntryOffsetInCodeSpans {
    <#
        Pure: does $Offset fall inside one of $Spans (as Get-EntryCodeSpans returns them)? The rewriter's
        half -- it walks the entry's link matches and leaves alone any that begins inside code.

        The test is on the START of a match rather than on any overlap: a link that begins in prose and
        runs into a fence is malformed markdown either way, and rewriting it is the same answer the whole
        entry gets.
    #>
    param(
        [Parameter(Mandatory)][int]$Offset,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Spans
    )
    foreach ($span in $Spans) {
        if ($Offset -ge $span.Start -and $Offset -lt ($span.Start + $span.Length)) { return $true }
    }
    return $false
}

# --- The tier line -------------------------------------------------------------------------------
#
# 'Tier: N' declares how far an entry reaches. It was superseded by the impact table below on the day it
# shipped and is kept because every entry written before that carries it; it is also the FIRST key the fold
# orders CHANGELOG.md's flat list on, since August 5, 2026. The ladder as it stood then (Dave, August 5,
# 2026 -- tiers 1 and 2 REDEFINED on August 12, 2026 by the ONE AUDIENCE TIER block below, which wins
# wherever the two disagree):
#
#   Tier 0 -- nobody outside this repo's own developers notices. Docs, config, repo-internal work.
#   Tier 1 -- then "a colleague working on this project"; NOW management and the employer/commissioner.
#             A colleague maintaining the repo is tier 0's audience, not tier 1's.
#   Tier 2 -- then "a consumer of the product"; NOW the subscriber of a service. The webshop worked
#             example separates them: its customers buy a product and never read a release note, so the
#             old wording sent that repo to 2 and the current model sends it to 1.
#
# The ladder was CUMULATIVE then -- tier 2 implied tier 1, so a tier-2 entry appeared in both documents.
# Since August 12, 2026 no tier implies another; the cumulative reading survives only in entries written
# before that date, which every parser here must still read.
#
# THE LABEL IS NOT REPO-OWNED, unlike the four scaffold strings above, and that is deliberate rather
# than an omission. 'Tier:' is a machine-read metadata key -- the same class as the 'Plugins:' line
# the fold writes, and the same class the language rule calls a technical identifier that keeps its
# original form. The three scripts that read it must agree on the literal; a translated key would
# make an entry unreadable to the fold in the repo that translated it.
#
# THE DEFAULT IS THE HARMLESS END, AND THAT IS THE WHOLE SAFETY ARGUMENT. An entry with no tier line
# is tier 0, so forgetting to classify cannot promote work into a consumer-facing document. It has a
# cost -- a release cannot be cut out of tier-0 work alone -- but that cost is LOUD: the cut refuses
# and names the entries. The reverse default would be silent, and would be wrong in the one direction
# that reaches people outside this repo.
# The type an entry gets when its branch prefix is not one the table knows -- 'wip/x', a consumer's own
# convention. It lived in new-branch.ps1 as $stubFallbackType and was written INTO the entry; with the
# 'Branch type' section retired on August 16, 2026 it is resolved on READ instead, so it had to move to the
# lib both readers share. Get-EntryFallbackType (#410) still overrides it where a repo defines one.
#
# 'Chore' is safe as a default for the reason that seam's own comment gives: it is a legitimate final value,
# so it can never be mistaken for evidence of an unedited entry.
$script:EntryFallbackTypeDefault = 'Chore'

$script:EntryTierLabel   = 'Tier'
$script:EntryTierDefault = 0
$script:EntryTierMax     = 2

function Get-EntryTierLabel {
    <# The literal metadata key ('Tier'), so no caller writes it out for itself. #>
    return $script:EntryTierLabel
}

function Get-EntryTierMax {
    <# The highest tier the model has (2). Read by the writer, the validator and the fold. #>
    return $script:EntryTierMax
}

# --- ONE AUDIENCE TIER PER REPO (Dave, August 12, 2026; inbound #620) -----------------------------
#
# Tier 1 and tier 2 stopped being two rungs of one ladder and became two KINDS of audience, of which a
# repo has exactly one: 1 is management and the employer/commissioner, 2 is the subscriber of a service.
# A webshop's customers buy a product and never read a release note, so its audience is 1; a repo that IS
# the service somebody subscribes to answers 2. Tier 0 -- the people maintaining the repo -- is always
# asked for, in every repo, and is not part of this question.
#
# WHAT THIS DOES *NOT* CHANGE: Get-EntryTierMax stays 2, and every validator above and below keeps using
# it. That separation is the whole safety of the change. The MAX says which tier NUMBERS are valid to
# READ -- and a tier-1 repo must still read a tier-2 entry, because 97 entries in this repo's record and
# every entry in a consumer's tree were written under the cumulative model. The AUDIENCE says which tiers
# this repo ASKS ABOUT when it scaffolds and when it judges completeness. Collapsing the two would make
# one repo's history unreadable to the other, silently, which is the direction that empties a release.
function Get-EntryAudienceTier {
    <#
        The one audience tier this repo asks its entries about -- Get-ReleaseAudienceTier's answer -- or
        $null where the repo has stated none.

        PROBED, NEVER REQUIRED, and $null is a real answer rather than a failure: it means "ask about every
        tier the model has", which is exactly what this system did before the knob existed. That default is
        deliberate and it is the opposite of the reading the policy invites. "The correct tier is enabled
        once the audience is clear" is about a repo's own preparation, not about what an unconfigured script
        should do -- and treating absence as "enable nothing" would switch the audience tier off in every
        consumer the moment they take the plugin update, with nothing erroring and a release document going
        out empty. Absent therefore means UNCHANGED.

        A value outside the model is ignored rather than honoured, for the reason every override here is:
        a seam returning 7 would otherwise have the scaffolder write a section no validator accepts, and a
        gate that refuses every entry in the repo is worse than a gate nobody configured.
    #>
    if (-not (Test-FunctionDefined 'Get-ReleaseAudienceTier')) { return $null }
    $v = & Get-ReleaseAudienceTier
    if ($null -eq $v) { return $null }
    if ("$v" -notmatch '^\d+$') { return $null }
    $t = [int]$v
    # 1 is the floor, not 0: tier 0 is asked for unconditionally, so naming it here would say nothing.
    if ($t -lt 1 -or $t -gt $script:EntryTierMax) { return $null }
    return $t
}

function Get-EntryAskedTiers {
    <#
        The tiers an entry in THIS repo is asked to answer, lowest first: tier 0 plus the audience tier --
        or every tier the model has, where no audience is stated.

        ONE ANSWER, THREE READERS, which is why it is a function rather than three inline expressions. The
        scaffolder writes these sections, the routing question under each one points at the NEXT of them,
        and the completeness gate asks for exactly these. Three copies of that arithmetic is how a
        scaffolder starts writing a section its own gate does not ask about.
    #>
    $audience = Get-EntryAudienceTier
    if ($null -eq $audience) { return @(0..$script:EntryTierMax) }
    return @(0, $audience)
}

function Get-EntryEarnedBump {
    <#
        Pure: what a pending set of entries EARNS, from a tier -> count map. Returns

          Notable  how many entries sit at tier 1 or higher
          Bump     'minor' where Notable is above zero, else 'patch'

        THE RULE (Dave, August 7, 2026): tier 0 only earns a PATCH -- publishing to no audience is what a
        patch is for -- and one entry at tier 1 or higher earns a MINOR, because somebody beyond this
        repo's own developers got something out of it. 'major' is deliberately not reachable from here:
        what earns one is the ten minors behind it, a milestone somebody decides to mark rather than a
        size this work adds up to. Test-ReleaseBumpEarned answers that second question and this one does
        not.

        TIER 1 OR HIGHER, NOT 'AT OR ABOVE THE AUDIENCE TIER', and the difference is load-bearing. This is
        written as '>= 1' so it reads correctly in a tier-1 repo and a tier-2 repo alike with neither
        having to translate it -- the same reason Get-ChangelogPendingCounts writes its own Reaching that
        way. So the two numbers on the tally line answer different questions and may differ: Reaching is
        who NOTICES, and this is what the version OWES them.

        IT LIVES HERE, IN THE LOWER LIB, BECAUSE TWO CALLERS AT DIFFERENT DEPTHS NEED IT. It was inline in
        Test-ReleaseBumpEarned in release-lib until September 7, 2026, and the tally line one lib down had
        no way to reach it: release-lib dot-sources THIS file, never the reverse, so the fold -- which
        loads entry-scaffold-lib standalone -- cannot see anything defined up there. The tally's own
        comment block named that and declined to name a bump at all rather than copy the arithmetic, on
        the ground that a second copy of a release gate's rule, inside the document that gate then reads,
        is the shape this repo keeps getting bitten by. That reasoning was right about the copy and wrong
        about the conclusion: the answer is one definition in the layer both callers already share, which
        is what this is. Test-ReleaseBumpEarned calls it and keeps the questions only it can answer --
        whether the bump ASKED for is the one earned, and whether a major is available.
    #>
    param([Parameter(Mandatory)]$ByTier)

    $notable = 0
    foreach ($tier in @($ByTier.Keys)) {
        # ContainsKey rather than a bare read for the reason Test-ReleaseBumpEarned's own loop gives: a
        # caller (or a test) handing over a map built by hand must not make this throw under StrictMode.
        if ([int]$tier -ge 1) { $notable += [int]$ByTier[$tier] }
    }

    return [pscustomobject]@{
        Notable = $notable
        Bump    = if ($notable -gt 0) { 'minor' } else { 'patch' }
    }
}

# --- WHO EACH AUDIENCE TIER IS, IN ONE PLACE (August 19, 2026) ------------------------------------
#
# The heading over the audience tier's section stopped naming a number, so the guidance underneath it is
# where the reader is told who they are writing for. That needs the tier written out in words, and until now
# those words existed only inside the routing questions ('...relevant to management and the
# employer/commissioner?'), which is prose about MOVING to a tier rather than a name for it.
#
# WHY THE SENTENCE IS ASSEMBLED RATHER THAN STORED. Storing 'For tier 2 audiences: the subscriber of a
# service.' as a finished line would make it wrong in every repo whose audience is 1 -- which is the repo the
# whole knob exists for, and the one that filed #620. The tier resolves per repo, so the sentence has to.
#
# THE DEFINITIONS MATCH Get-ReleaseAudienceTier's OWN, deliberately word for word: a consumer answering that
# knob reads those two descriptions in their repo-config, and meeting a third wording here would leave them
# deciding which one the scaffolder meant. Overridable through Get-EntryGuidanceOverrides like every other
# piece of form prose -- a repo that translated its entry template translates this with it.
# STRING KEYS, AND THAT IS THE BUG THIS FILE ALREADY DOCUMENTS ONE SCREEN DOWN, walked into again here on the
# first run. An [ordered]@{ 1 = '...' } is an OrderedDictionary whose indexer takes a key OR A POSITIONAL
# INDEX, and the positional overload wins for an integer -- so $descriptions[2] asks for the THIRD entry of a
# two-entry map and comes back empty. .Contains(2) says yes and the lookup beside it returns nothing, which
# is why the template rendered 'For tier 2 audiences.' with the reader's name silently missing. Keyed and
# looked up as strings, there is no integer for the indexer to misread.
$script:EntryAudienceDescriptions = [ordered]@{
    '1' = 'management and the employer/commissioner'
    '2' = 'the subscriber of a service'
}

function Get-EntryAudienceDescription {
    <# Who one audience tier is, in words -- '' for a tier this model has no description for, which keeps the
       guidance a sentence short rather than a sentence with a hole in it. #>
    param([Parameter(Mandatory)][int]$Tier)
    $key = [string]$Tier
    if ($script:EntryAudienceDescriptions.Contains($key)) { return [string]$script:EntryAudienceDescriptions[$key] }
    return ''
}

function Format-EntryAudienceGuidance {
    <#
        The audience tier's guidance block with '{0}' resolved to the sentence naming that tier and its
        reader. A block carrying no '{0}' comes back untouched, which is what makes this safe over an
        override: a repo that replaced the wording with its own prose gets exactly its own prose.

        NOT -f, AND THAT IS A BUG THIS AVOIDS RATHER THAN A STYLE CHOICE. These lines are form text that
        legitimately contains braces -- a repo documenting a placeholder, a '{0}' inside an example -- and
        the format operator throws on an unmatched brace instead of leaving it alone. A plain replace of the
        one token cannot fail on anybody's prose.
    #>
    param(
        [AllowEmptyCollection()][string[]]$Lines = @(),
        [Parameter(Mandatory)][int]$Tier
    )
    $who = Get-EntryAudienceDescription -Tier $Tier
    $sentence = if ($who) { "For tier $Tier audiences: $who." } else { "For tier $Tier audiences." }
    return @($Lines | ForEach-Object { [string]$_ -replace '\{0\}', $sentence })
}

function Format-EntryLinkGuidance {
    <#
        The guidance block with '{1}' resolved to the sentence naming WHERE the entry's relative links have
        to resolve from -- the directory the fold writes the changelog into. A block carrying no '{1}' comes
        back untouched, which is the same contract as its '{0}' sibling above and what makes it safe over an
        override: a repo that replaced the wording with its own prose gets exactly its own prose.

        IT EXISTS BECAUSE THE BASE IS A SEAM AND THE SENTENCE WAS A CONSTANT (inbound #967). The block said
        'resolve FROM THE REPO ROOT ... write scripts/x.ps1, never ../../scripts/x.ps1' in every repo, and
        since #914 a consumer's CHANGELOG.md sits in the workflow folder -- the same directory this document
        is in, where that advice is exactly backwards. So the one line is composed from the destination that
        actually applies, from the same value open-pr's link gate resolves against.

        IT MAY RETURN MORE LINES THAN IT WAS GIVEN, unlike Format-EntryAudienceGuidance, and that is why it
        is a second function rather than a second token in the first. The sentence is two lines wide in the
        root case and one in the isolated case, so the token line is repeated once per fragment with the
        fragment substituted -- which keeps the '> ' of a blockquote, and any other prefix an override put
        there, on every line it produces.

        NOT -f, for the reason the sibling gives: these lines are form text that legitimately contains
        braces, and the format operator throws on an unmatched one instead of leaving it alone.
    #>
    param(
        [AllowEmptyCollection()][string[]]$Lines = @(),
        # Repo-root-relative directory the entry's text lands in; '' is the repo root.
        [string]$DestDirRel = '',
        # Repo-root-relative directory the entry itself sits in. Defaults to this format's own.
        [string]$EntryDirRel = ''
    )
    if (-not $EntryDirRel) { $EntryDirRel = (Get-BranchFilePaths).Directory }
    $destNorm  = ($DestDirRel  -replace '\\', '/').Trim('/')
    $entryNorm = ($EntryDirRel -replace '\\', '/').Trim('/')
    $fragments = if (-not $destNorm) {
        # The root, which is this repo's own answer and every consumer's before #914. Word for word what the
        # block said when the base was a constant, so a repo whose changelog is at the root sees no change.
        @('Relative links in that text resolve FROM THE REPO ROOT, not from this directory:',
          'write `scripts/x.ps1`, never `../../scripts/x.ps1`.')
    } elseif ([string]::Equals($destNorm, $entryNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
        # The isolated default: the changelog is in this very directory, so the link that reads correctly in
        # front of the author IS the correct one. Said plainly, because the opposite was said here for weeks.
        @('Relative links in that text resolve FROM THIS DIRECTORY -- `CHANGELOG.md` sits here too, so',
          'write each path exactly as it reads in this file.')
    } else {
        @(('Relative links in that text resolve FROM `' + $destNorm + '/`, where `CHANGELOG.md` sits --'),
          'not from this directory.')
    }
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($line in @($Lines)) {
        $s = [string]$line
        if ($s -notmatch '\{1\}') { $out.Add($s); continue }
        foreach ($fragment in $fragments) { $out.Add(($s -replace '\{1\}', $fragment)) }
    }
    return @($out)
}

function Remove-EntryAudienceGuidance {
    <#
        The counterpart of Format-EntryAudienceGuidance, for a repo that states NO audience tier:
        Get-EntryAudienceTier returns $null there, so nothing can fill '{0}' and the sentence has to go.

        IT REMOVES THE WHOLE PARAGRAPH, NOT THE LINE (issue #928, August 26, 2026). The call site used to
        filter `$_ -notmatch '{0}'`, which is right about the seam and wrong about the sentence: the seam
        opens a paragraph whose remaining lines finish it. In StepsGuidance that is three lines, so every
        no-tier consumer's branch document carried a paragraph beginning mid-sentence, referring to "that
        reader" after the clause naming that reader had been dropped. Not measurable here -- this repo's
        scripts/repo-config.ps1 states tier 2 -- which is why it reached consumers only.

        BY SHAPE, NOT BY WORDING, so it survives a consumer's translation. A paragraph ends at a SEPARATOR:
        a line that is empty once a leading '>' is stripped. That is the same move check-branch-entry.ps1
        makes for the #899 preamble check and for the same reason -- the wording is a seam and the shape is
        not. Marking the paragraph in the wording instead would have put the burden on whoever translates it.

        A BLOCK CARRYING NO '{0}' COMES BACK UNTOUCHED, exactly as its sibling above does, and for the same
        reason: a repo that replaced the wording with its own prose gets exactly its own prose.

        AND ONE ADJACENT SEPARATOR GOES WITH IT, or removing an interior paragraph would leave the two
        separators that fenced it back to back -- a doubled '>' line in the middle of the block. The one
        BEFORE is preferred, so the paragraph that followed keeps the blank line above it; where the seam
        opens the block and has none, the one after is taken instead.

        THE BOUND IS ONE SEAM PARAGRAPH, which is what the wording has and all it is built for. Two
        seam-carrying paragraphs ADJACENT to each other, the first of them opening the block, would leave
        one separator standing: the first falls back to taking the one after it, and the second then reads
        that as its own "before" and takes nothing. Named rather than repaired -- StepsGuidance carries a
        single '{0}' and no consumer override has ever carried two, so the repair would be built for a
        shape nobody has. Found by Victor in review, August 26, 2026.
    #>
    param([AllowEmptyCollection()][string[]]$Lines = @())

    $all = @($Lines | ForEach-Object { [string]$_ })
    if ($all.Count -eq 0) { return @() }

    # A separator is what fences one paragraph from the next: blank, or a blockquote marker with nothing
    # after it. Anything else is prose and belongs to the paragraph it sits in.
    $isSeparator = {
        param([string]$line)
        return ([string]($line -replace '^\s*>', '')).Trim() -eq ''
    }

    $drop = New-Object 'System.Collections.Generic.HashSet[int]'
    for ($i = 0; $i -lt $all.Count; $i++) {
        if ($all[$i] -notmatch '\{0\}') { continue }
        if ($drop.Contains($i)) { continue }

        # Expand to the paragraph's own bounds. The seam is not necessarily its first line: a translation
        # may need the tier sentence in a different position than English does.
        $start = $i
        while ($start -gt 0 -and -not (& $isSeparator $all[$start - 1])) { $start-- }
        $end = $i
        while ($end -lt ($all.Count - 1) -and -not (& $isSeparator $all[$end + 1])) { $end++ }

        for ($j = $start; $j -le $end; $j++) { [void]$drop.Add($j) }

        if ($start -gt 0 -and (& $isSeparator $all[$start - 1])) {
            [void]$drop.Add($start - 1)
        } elseif ($end -lt ($all.Count - 1) -and (& $isSeparator $all[$end + 1])) {
            [void]$drop.Add($end + 1)
        }
    }

    if ($drop.Count -eq 0) { return $all }
    return @(0..($all.Count - 1) | Where-Object { -not $drop.Contains($_) } | ForEach-Object { $all[$_] })
}

function Format-EntryTierLine {
    <# The single line an entry carries, e.g. 'Tier: 0'. One formatter, so the writer and the parser
       below cannot disagree about the spacing. #>
    param([int]$Tier = $script:EntryTierDefault)
    return "$($script:EntryTierLabel): $Tier"
}

function Format-EntryFoldFooter {
    <#
        Pure: the closing line the FOLD appends to an entry -- the clickable PR, which does not exist
        until the merge. '[PR #468](https://...)'.

        THE MERGE DATE IS NOT ON THIS LINE ANY MORE (Dave, August 19, 2026). It sat here from August 5,
        as ' <middot> merged 2026-08-05', and it moved to the 'Pull Request' heading directly above --
        Set-EntryMergeStamp writes it there, from the same PR field this line's number comes from. Dave's
        call when the stamp arrived, and the reason is that the alternative was the same fact twice in one
        section: the heading says when it landed, the line says which PR it was.

        WHICH IS WHY $MergedStamp EXISTS, AND WHY IT IS NORMALLY EMPTY. That reasoning holds only while
        there IS a heading to hold the date, and one shape has none: a PRE-DOSSIER entry, whose title was
        its heading and which carries no named sections at all. Every branch in flight from before
        August 6, 2026 is one -- here and in every consumer, who meet this change through a plugin update
        rather than by choosing to -- and the fold explicitly still folds them. Set-EntryMergeStamp finds
        nothing to stamp in such an entry and returns it unchanged, silently, so the date would simply be
        gone: the same entry folded a day earlier always carried one, in the one document whose subject is
        when things landed. So the caller asks whether the section is there (Test-EntryHasSection) and
        passes the stamp only when it is not. One fact, one place, wherever that place happens to be.

        WHY THE PR'S TIMESTAMP AND NOT THE CLOCK (Dave, August 5, 2026), which is still the rule and now
        lives on the stamp: the date used to be scaffolded into the entry's HEADING when the branch was
        created, making it the branch's birth date rather than the landing date -- wrong by however many
        days the branch lived, in the one document whose subject is when things landed. Reading it off the
        PR fixes the remainder, because the fold does not always run seconds after the merge. This repo has
        measured that gap: unfolded entry files were once found in the repo root the morning after their
        merge. See Format-EntryMergeStamp, which carries the fallback that reasoning needs.

        WHY A FUNCTION RATHER THAN ONE LINE IN THE FOLD. The fold drives a live remote, so its own
        suite deliberately does not depend on a PR existing -- which would have left this path untested.
        Same move, same reason as Get-ExistingPrRecord in pr-issues-lib.ps1: the
        part that is a pure function of an API answer becomes one, so it can be asserted without the API.
    #>
    param(
        [Parameter(Mandatory)][int]$Number,
        [Parameter(Mandatory)][string]$Url,
        [AllowEmptyString()][string]$MergedStamp = ''
    )
    $line = "[PR #$Number]($Url)"
    if ($MergedStamp) { $line += ' ' + $script:EntryIdSeparator + ' merged ' + $MergedStamp }
    return $line
}

function Format-EntryMergeStamp {
    <#
        Pure: the merge moment as it is written into the 'Pull Request' heading -- '20260819-171500'.

        RENDERED IN UTC, deliberately (inbound #1542): since #1280 Get-EntryInsertOffset derives the
        entry's INSERT POSITION from this stamp -- it walks to the first entry in the list whose own stamp
        is older -- so the stamp is a sort key, not only a display string. A sort key cannot be local
        time: once adopt-ci-floor.ps1 ships fold-on-merge.yml, a repo folds both from a UTC GitHub
        runner and from a maintainer's laptop, and ToLocalTime() on the laptop would offset every
        locally-written stamp from every CI-written one by the maintainer's UTC offset -- dropping entries
        out of chronological order in the very TIER 0 section #1280 fixed to be chronological. It carries
        the TIME and not only the date, which is what the closing line has always shown alongside the link,
        and which the insert walk needs to order two entries that landed on the same day.

        $MergedAt is gh's own ISO 8601 timestamp; empty or unparseable falls back to $FallbackNow, for the
        same reason Format-EntryFoldFooter has a fallback -- a cosmetic field must not turn a completed
        fold into a failure. That fallback is a UTC stamp too (fold-changelog-entry.ps1), or a local-time
        fallback would reintroduce the skew this rendering exists to remove.
    #>
    param(
        [string]$MergedAt = '',
        [Parameter(Mandatory)][string]$FallbackNow
    )
    if (-not $MergedAt) { return $FallbackNow }
    try { return ([datetime]$MergedAt).ToUniversalTime().ToString('yyyyMMdd-HHmmss') } catch { return $FallbackNow }
}

function Set-EntryMergeStamp {
    <#
        Pure: the entry with its 'Pull Request' heading restamped -- '### Pull Request <middot> 20260819-171500'.
        Unchanged when the stamp is empty, when the entry has no such section, or where the heading sits
        inside a fence.

        THE FOLD WRITES INTO A HEADING AGAIN, which reverses nothing (August 19, 2026). What was retired on
        August 5 was the DATE IN THE ENTRY'S OWN HEADING, and it was retired because the scaffolder wrote it
        at creation -- making it the branch's birth date in the one document whose subject is when things
        landed. This is a section heading, written by the fold, from the PR's own merge timestamp. Same
        fact, right source, right moment.

        AN ALREADY-STAMPED HEADING IS RESTAMPED RATHER THAN APPENDED TO, so folding twice cannot grow a
        line of timestamps -- and so a heading still carrying the TEMPLATE's placeholder (an entry someone
        copied from the trunk's own reset state) comes out with a real one.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$EntryText,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Stamp
    )
    if (-not $Stamp) { return $EntryText }
    # THE ENTRY'S OWN HEADING TAKES THE STAMP SINCE AUGUST 23, 2026 (Dave), where the 'Pull Request' section
    # heading took it. The reason is that the entry is now the development cycle's DEPLOY phase, and its
    # heading is the line a reader meets first -- so when the change landed sits beside what landed, in the
    # heading that says so, rather than three sections further down.
    #
    # IT IS THE FIRST HEADING AT THE ENTRY'S OWN LEVEL, which is a stronger anchor than a section NAME and
    # the reason this rewrite simplifies rather than complicates. There is exactly one such heading in an
    # entry, in every shape this format has ever had -- today's title-first DEPLOY line, the branch-first
    # 'deployment' and 'changelog' forms, and the pre-dossier entry whose heading was its own title and which
    # had no named sections at all to stamp. That last one is the case the old code had to detect and hand to
    # the footer instead; it needs no special handling here.
    #
    # AN ALREADY-STAMPED HEADING IS RESTAMPED RATHER THAN APPENDED TO -- the tail is part of the match -- so
    # folding twice cannot grow a line of timestamps, and a heading still carrying the reset state's
    # placeholder comes out with a real one.
    $rx = '^(#{' + $script:EntryHeadingLevel + '}\s+.*?)' + (Get-EntrySectionHeadingTail)

    $pair = Get-EntryLineFlagPairs -EntryText $EntryText
    $parts = $pair.Parts
    $line = -1
    for ($i = 0; $i -lt $parts.Count; $i += 2) {
        $line++
        if ($pair.Fenced[$line]) { continue }
        $m = [regex]::Match([string]$parts[$i], $rx)
        if (-not $m.Success) { continue }
        $parts[$i] = $m.Groups[1].Value.TrimEnd() + (Format-EntrySectionHeadingSuffix -Stamp $Stamp)
        break
    }
    return ($parts -join '')
}

function Resolve-EntryTier {
    <#
        Pure: reads the tier an entry declares. Returns an object with

          Tier      the tier as an int -- the default (0) when nothing is declared OR when what is
                    declared cannot be honoured, so a caller that ignores Error still fails safe
                    towards the harmless end rather than crashing.
          Declared  $true when a 'Tier:' line was found outside fenced code.
          Raw       exactly what stood after the colon, for quoting back at the author.
          Error     $null when all is well; otherwise the reason, ready to print.

        AN OBJECT RATHER THAN AN INT, and the reason is the failure this has to make impossible. A
        'Tier: 5' or a 'Tier: two' that silently read back as 0 would file the change as repo-internal
        -- correct-looking output, wrong document, and nothing to notice. So the malformed case is
        reported instead of absorbed, and open-pr.ps1 refuses the PR over it while the branch is still
        the only thing affected.

        FENCE-AWARE, and the FIRST match outside a fence wins. An entry documenting the tier model
        writes 'Tier: 2' inside a fence -- this file's own repo does it in the docs shipped with this
        change -- and a parser that cannot tell a quote from a declaration gets disabled by whoever
        hits it first.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$EntryText)

    $result = [pscustomobject]@{
        Tier     = $script:EntryTierDefault
        Declared = $false
        Raw      = ''
        Error    = $null
    }

    $body = Get-EntryTextOutsideFences -EntryText $EntryText
    $rx = '(?m)^' + [regex]::Escape($script:EntryTierLabel) + ':[ \t]*(.*?)[ \t]*$'
    $m = [regex]::Match($body, $rx)
    if (-not $m.Success) { return $result }

    $result.Declared = $true
    $result.Raw = $m.Groups[1].Value

    if ($result.Raw -notmatch '^\d+$') {
        $result.Error = "'$($script:EntryTierLabel): $($result.Raw)' is not a tier -- write a whole number from 0 to $($script:EntryTierMax)."
        return $result
    }
    $value = [int]$result.Raw
    if ($value -lt 0 -or $value -gt $script:EntryTierMax) {
        $result.Error = "tier $value does not exist -- the tiers are 0 to $($script:EntryTierMax)."
        return $result
    }
    $result.Tier = $value
    return $result
}

function Remove-EntryTierLine {
    <#
        Removes the 'Tier:' line (and the blank line it leaves behind) from an entry block.

        ITS CALLER MOVED, AND THAT IS THE WHOLE STORY OF THIS FUNCTION (August 5, 2026). It was written for
        the FOLD: once an entry sat under '## Tier 2 - Pull Requests', the section stated the tier, so a line
        inside the entry restating it was the same fact in two places -- the drift shape this repo has paid
        for three times. The sections are gone, so there is nothing above a folded entry stating its reach,
        and the fold now KEEPS the line: consuming it would leave the entry declaring nothing, and every
        downstream reader would take that as tier 0.

        What did not change is that the line must never travel OUTWARD. A self-assigned tier printed at a
        consumer is the same class of thing as a self-assigned score, and the line now reaches CHANGELOG.md
        where it never used to -- so this belongs on the same stripping path as Remove-EntryImpactTable, in
        the renderers that build the consumer document, the per-plugin CHANGELOGs and the release cards. That wiring
        is the release side's to make; this function is unchanged and waiting for it.

        Same shape as Remove-EntryPluginsLine in release-lib.ps1, deliberately: both strip one
        bookkeeping line and collapse the double blank it leaves. It lives HERE rather than there
        because the fold reaches release-lib only when the repo happens to have it (see that
        dot-source's guard), while this lib travels with the fold itself.

        FENCE-AWARE, AND ONLY THE FIRST DECLARATION IS REMOVED -- which is not symmetry with the reader
        for its own sake but the case that arrived immediately. The changelog entry for the change that
        introduced this model quotes 'Tier: 0' inside a fence to explain the format; a blind regex would
        have deleted that line out of the fence while folding, silently damaging the one entry that
        documents the mechanism. Removing exactly what Resolve-EntryTier READ is the only behaviour
        that cannot surprise: what the fold consumed is what the fold acted on.

        The line ending is preserved rather than normalised: the caller has already matched the
        changelog's own style, and rewriting it here would put CRLF and LF in one entry.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$EntryText)
    $label = [regex]::Escape($script:EntryTierLabel)
    # The fence state comes from the one reader (Get-FencedLineFlags, via the pair helper) rather than from
    # a walk of its own -- this used to be one of this file's four separate fence walks, and the one that
    # did not recognise '~~~'. The separators are kept so the original CRLF/LF of every line survives.
    $pair = Get-EntryLineFlagPairs -EntryText $EntryText
    $parts = $pair.Parts
    $out = New-Object System.Collections.Generic.List[string]
    $removed = $false
    $n = -1
    for ($i = 0; $i -lt $parts.Count; $i++) {
        # Odd indices are the captured separators; only even ones are line content.
        if ($i % 2 -eq 1) { continue }
        $n++
        $line = $parts[$i]
        $sep = if ($i + 1 -lt $parts.Count) { $parts[$i + 1] } else { '' }
        # A fenced line (the markers included) is content, never a declaration.
        if ((-not $pair.Fenced[$n]) -and (-not $removed) -and $line -match "^$label`:") {
            $removed = $true
            continue
        }
        $out.Add($line + $sep)
    }
    $t = ($out -join '')
    if (-not $removed) { return $t }
    return [regex]::Replace($t, '(\r?\n)\1\1+', '$1$1')
}

# --- The impact table: how far a change reaches, and how much it weighs at each reach --------------
#
# ONE TABLE INSTEAD OF THREE METADATA LINES (Dave, August 5, 2026; issue #467). An entry declares its
# impact as a markdown table with THE TIER AS THE ROW and the significance as a column:
#
#     | Tier | Significance | Why |
#     |---|---|---|
#     | 2 | 5 | consumers must re-add the marketplace under its new name; installs break without it |
#     | 1 | 4 | the routine version bump stops needing a developer |
#
# WHAT THE SHAPE BUYS, beyond reading better than three colon-separated keys. The tier ladder is
# CUMULATIVE -- tier 2 implies tier 1, so a tier-2 change appears in the consumer document AND in the internal
# note -- and until now that was implied by two differently-suffixed keys ('Significance' and
# 'SignificanceConsumer') that a reader had to know were audiences. As rows it is literal: the rows an
# entry has ARE the documents it appears in, and each row's number is that document's reader answering
# their own question. Filling in two rows is no longer a second judgement bolted on; it is saying out loud
# that the change reaches two audiences, which is what tier 2 already meant.
#
# IT REPLACES THE 'Tier: N' LINE rather than joining it, because the row states the tier and the same fact
# in two places is the drift this repo has paid for repeatedly. THE TIER COLUMN IS NOT THAT DUPLICATION:
# once folded, the changelog SECTION states how far the change reaches, while the column says which
# audience each SCORE belongs to. Two different jobs on the same number, which is why the table survives
# the fold whole where the old 'Tier:' line was consumed by it.
#
# 'Tier: N' IS STILL READ, AND ALWAYS WILL BE -- "recognise both, write one", this repo's standing rule
# for a format change. Entries written before this table exist are already in CHANGELOG.md and in every
# consumer's tree, and a parser that only knew the new shape would read every one of them as tier 0:
# silent, correct-looking, and wrong in the direction that empties a release. So an entry with no table
# falls back to the old line, with no score -- which is exactly what those entries have.
#
# THE FORWARD-LOOKING FRAMEWORKS DELIBERATELY DO NOT APPLY HERE, and it is worth saying so, because they
# are the first thing anyone reaches for. RICE and WSJF price work BEFORE it is done and carry effort in
# the denominator -- they answer "what do we build next". Everything scored here is already merged, so
# effort is spent and irrelevant; the only open question is how much the reader of a finished release
# document gets out of what landed. That is a magnitude, not a priority. Reach and significance is the
# same decomposition incident practice makes when it derives a priority from impact and urgency rather
# than asking for one number.
#
# IT WAS CALLED 'Happiness' FOR ONE AFTERNOON (Dave, August 5, 2026). He rejected the word as
# unprofessional and he was right about more than the word: 'happiness' names an EMOTION in the reader,
# which is not something an entry's author is in any position to assert. What they can judge is the weight
# of the change for that audience, which is what the field always measured. Renamed before it shipped;
# nothing carries the old key.
#
# 1 TO 5 AGAINST A WRITTEN RUBRIC (Get-EntrySignificanceRubric below), and the rubric is what makes this a
# measurement rather than a mood. An unanchored ordinal scale invites false precision -- the difference
# between a 3 and a 4 becomes whatever the author felt that morning -- and this repo asked for the
# opposite. Every level therefore has a definition, in the same shape severity levels, CVSS qualitative
# bands and ITIL impact levels use: a test a reader can apply to somebody else's entry and get the same
# answer. That also makes the number COMPARABLE ACROSS RELEASES, which an unanchored one could not be: a 5
# means "the reader must act" in August and in June alike, because the rubric says so rather than the
# release's own spread.
#
# Dave chose the rubric over an unanchored scale on August 5, 2026, reversing his own earlier answer the
# same day once the naming question exposed what was behind it. Recorded because the reversal IS the
# reasoning: the first answer avoided calibration on the grounds that every anchor is a second judgement
# that can drift, which is true and is the price. Without anchors there is no judgement to drift and also
# nothing to check, and an unauditable ranking published beside a release is the thing being avoided.
#
# THE 'Why' COLUMN IS REQUIRED, and the rubric does not replace it. The level says which band the change
# falls in; the why says why THIS change is in that band, which is the half a later reader can disagree
# with. It travels into the record and is never published outward -- see Remove-EntryImpactTable.
#
# NO SCAFFOLDED NUMBER, WHICH IS THE OPPOSITE CHOICE FROM THE OLD TIER DEFAULT, AND DELIBERATE. 'Tier: 0'
# had a default because 0 is a legitimate, harmless final answer -- forgetting it under-promotes, which is
# loud at the cut. A significance score has no harmless value: any number written for the author would be
# a GUESS, and this repo has measured what a guessed ranking costs. The retired remove-before-publishing marker guessed
# from the branch prefix which changes a consumer would notice and put v3.2.0's single most consequential
# change -- renaming the marketplace, which breaks every existing install -- below the line, because it
# arrived on a chore/ branch. So the scaffold writes the tier-0 row and nothing else, and the cut refuses a
# release whose entries have not answered.
#
# THE HEADERS ARE NOT REPO-OWNED, for the reason the old labels were not: they are the machine-read keys
# four scripts must agree on, the same class as 'Plugins:', and the language rule keeps a technical
# identifier in its original form. WHETHER a repo ranks at all IS repo-owned (Test-EntrySignificanceActive),
# and so is the RUBRIC's wording (Get-EntrySignificanceRubric) -- the editorial half, not the key.
$script:EntryImpactHeaders   = @('Tier', 'Significance', 'Why')
$script:EntryImpactEmptyCell = '-'
$script:EntrySignificanceMin = 1
$script:EntrySignificanceMax = 5

# --- THE SHAPE THAT REPLACED THE TABLE (Dave, August 6, 2026) -------------------------------------
#
# One '#### Tier N' sub-section per reach the change claims, each carrying why it matters at that reach
# and then its score. The table is gone because it forced a rectangle onto something that is not always
# rectangular: not every change HAS a tier 1 or a tier 2, and a missing row reads as an omission while a
# missing section reads as an answer.
#
# THE KEYS STAY FIXED while the prose around them is repo-owned, exactly as the table's column headers
# were. 'Tier' in the sub-heading and 'Score:' on its own line are what four scripts parse; the routing
# question underneath is editorial and comes from Get-EntrySignificanceWording.
#
# 'Score:' ECHOES THE RETIRED 'Tier: N' LINE ON PURPOSE -- same shape, same position, one fact per line.
# A reader who knows one knows the other, and a parser for either is the same three characters of regex.
# AN H3 SINCE AUGUST 23, 2026 (Dave), WHERE IT WAS AN H4. The two branch files merged into one development
# cycle, and the entry became a SECTION of that document rather than a document of its own: its heading is
# the cycle file's own '## `<branch>` DEPLOY' phase heading. Tier 0's text sits directly under that heading,
# so the audience tier's sub-heading is the entry's FIRST inner heading and belongs at the entry's section
# level -- the same level 'Pull Request' has always carried, which is what makes the entry two H3 sections
# again instead of one H3 and one H4 nested under a heading that no longer exists.
# DERIVED, NOT STATED, SINCE AUGUST 26, 2026 -- and the paragraph above is the argument for it. It says this
# heading "belongs at the entry's section level", and it was written as a literal 3 that happened to equal
# that level. When both level pairs shifted one down, the section level became 4 and this stayed at 3: the
# audience tier's heading was then one level SHALLOWER than the sections it sits beside, which closed the
# opening question's section instead of sitting next to it. The symptom was exactly the one measured when this
# level last moved, three days earlier -- a fixture with no audience tier going from four scaffold findings to
# five, the fifth being the opening question its own tiers had orphaned. Reading it off the section level
# means the next re-level cannot reproduce that.
# RESOLVED IN THE GETTER, NOT HERE, and that is not style -- it is the only place it works. This constant is
# declared some two thousand lines ABOVE $script:EntrySectionLevel, so reading that variable at this point
# yields nothing. Assigning it here failed loudly and immediately ("the variable cannot be retrieved because
# it has not been set") the moment any script dot-sourced this lib, which is the good direction for a
# load-order mistake to fail in. The value below is the fallback for a caller that somehow reaches it before
# the section level exists; Get-EntryTierSubLevel is what every reader actually goes through.
$script:EntryTierSubLevel   = 4
# THE RETIRED LEVEL, RECOGNISED AND NEVER WRITTEN. Every regex matching a tier sub-heading is built as a
# RANGE spanning this value, the written one and the entry's section level -- read every level, write one, the
# same rule this file gives every retired string. A reader that forgot an old level would read those entries
# as declaring tier 0 alone, which is the silent direction that empties a release.
#
# IT IS 3 SINCE AUGUST 26, 2026, WHERE IT WAS 4, and the swap is not a correction of the old value -- it is
# what keeps the range spanning BOTH. The numbered shape wrote '#### Tier N' and the named shape that replaced
# it on August 23 wrote it at H3; three days later the level pairs shifted one down and the written level
# became 4 again. So 4 is now covered by the WRITTEN value and 3 is the one that would otherwise fall out of
# the range, which is where it has to be stated. Every entry sitting in CHANGELOG.md right now carries this
# heading at H3, so getting this backwards would misread the whole pending list.
$script:EntryTierSubLevelRetired = 3
$script:EntryTierSubPrefix  = 'Tier'
# BOLD SINCE THE DOSSIER FORM (Dave, August 6, 2026), and the plain form is still read. 'Score:' sat as bare
# prose in a section that is otherwise all prose, so it did not read as the field it is; '**Score:**' does.
# The KEY did not change -- only its decoration -- which is why the pattern below strips the asterisks
# rather than listing two labels: every entry in CHANGELOG.md and in every consumer's tree carries the
# plain form right now, and they meet the new parser through a plugin update rather than by choosing to.
$script:EntryScoreKey       = 'Score'
$script:EntryScoreLabel     = '**Score:**'

function Get-EntryTierSubLevel {
    <#
        The level a tier sub-heading is WRITTEN at, which depends on which shape this repo writes.

        THREE IN THE NAMED SHAPE, FOUR IN THE NUMBERED ONE, and that is not a cosmetic split. In the named
        shape tier 0 has no heading at all -- the entry's own heading is its section -- so the audience
        tier's heading is the entry's FIRST inner heading and belongs beside 'Pull Request' at the section
        level. In the numbered shape the tiers are sub-sections OF the entry's opening question, so they have
        to sit one level DEEPER than it: at the section level they would close that question's section
        instead of nesting inside it, and the gate would then report the question itself as unanswered on
        every freshly scaffolded entry.
        Measured the moment the level moved: a fixture stating no audience tier went from four scaffold
        findings to five, the fifth being the opening question its own tiers had just orphaned.

        SO AN UNCONFIGURED CONSUMER SEES NO CHANGE, which is the direction every conditional in this file
        takes. A repo that has stated no audience tier keeps the document it had yesterday, byte for byte.
    #>
    # BOTH SHAPES ARE DERIVED FROM THE SECTION LEVEL, not stated (August 26, 2026). The paragraphs above say
    # what each shape needs -- the named tier BESIDE the entry sections, the numbered ones one level INSIDE
    # the opening question -- and both were written as literals that happened to match. When the section level
    # moved they stopped matching, and the symptom was the one measured above: the opening question reported
    # as unanswered on every freshly scaffolded entry, because its own tiers had closed its section.
    if (Test-EntryTierSectionsAreNamed) { return (Get-EntrySectionLevel) }
    return ((Get-EntrySectionLevel) + 1)
}

function Get-EntryTierSubLevelRange {
    <#
        The '#{min,max}' fragment matching a tier sub-heading at the level it is WRITTEN at or at any level
        it HAS BEEN written at.

        ONE BUILDER, because every regex in this file that meets a tier sub-heading needs the same range --
        the numbered '#### Tier N' shape, the audience tier's named heading, and the section-end boundary --
        and a fourth that hardcoded the current level is exactly how a retired shape stops being read. The
        entry's own section level is folded in for the same reason: the audience tier's heading has sat at
        both, and the range has to span whatever the two constants happen to be rather than assuming which
        of them is the smaller.
    #>
    # BOTH SHAPES' WRITTEN LEVELS ARE ASKED FOR RATHER THAN ASSUMED, and the retired floor is folded in
    # alongside them. After August 26, 2026 there are three levels this heading has ever been written at:
    # H3 (the named shape before the shift), H4 (the numbered shape before it, and the named shape after) and
    # H5 (the numbered shape after). A range that only spanned today's two would stop reading every entry
    # sitting in CHANGELOG.md right now -- and misreading those is the silent direction that empties a
    # release, which is why this builder exists at all.
    $named    = (Get-EntrySectionLevel)
    $numbered = (Get-EntrySectionLevel) + 1
    $levels = @($named, $numbered, $script:EntryTierSubLevelRetired, $script:EntrySectionLevel)
    $min = ($levels | Measure-Object -Minimum).Minimum
    $max = ($levels | Measure-Object -Maximum).Maximum
    return '#{' + $min + ',' + $max + '}'
}

# ALL THREE TIERS ARE ALWAYS IN THE DOCUMENT, AND 'N/A' IS HOW A TIER SAYS IT IS NOT REACHED (Dave,
# August 7, 2026). This replaces "the sections an entry has ARE the documents it appears in": tier 1 and
# tier 2 used to be commented out and uncommenting one was the claim. They are now always present, each
# answered -- a score from the rubric, or 'N/A' with a line saying why the change reaches nobody there.
#
# WHY THE ANSWER IS BETTER THAN THE ABSENCE, which is the whole trade. An absent section and an unfinished
# one look identical, so the gate could not tell "this change reaches no consumer" from "nobody has got to
# tier 2 yet" -- and those need opposite responses. An N/A with a reason is a decision on the page; a blank
# is a question nobody answered. It also leaves the reasoning behind a NEGATIVE claim in the record, which
# the absence model threw away entirely.
#
# A 'Yes/No' FIELD WAS WEIGHED AND DROPPED the same day. Dave's own draft carried
# '**Significant to this tier as well?** Yes/No | **Score:**', and it says the reach twice: a score and a
# yes are one fact, free to contradict each other, which is the drift this file exists to prevent. The
# score alone answers it -- a number means yes, N/A means no.
$script:EntryScoreNotApplicable = 'N/A'

function Get-EntryScoreLabel {
    <# The label a WRITER puts on the score line ('**Score:**'). #>
    return $script:EntryScoreLabel
}

function Get-EntryScoreNotApplicable {
    <# The literal a tier writes when the change does not reach it ('N/A'). Machine-read by four scripts,
       so it is stated once and is deliberately NOT repo-configurable -- the same class as 'Tier' and
       'Plugins:'. A repo that translated it would make its own entries unreadable to its own fold. #>
    return $script:EntryScoreNotApplicable
}

function Get-EntryTierSectionMarker {
    <#
        The heading one tier's section is written under ('#### Tier 2').

        A HELPER RATHER THAN A THIRD HAND-BUILT STRING. The formatter that WRITES the section, the scaffold
        gate that points AT one, and the ranking-gate refusal that asks for a missing one all need the same
        heading -- and a refusal telling an author to add a heading the formatter spells differently is
        worse than no advice at all. The regex readers build their own pattern from the same two variables,
        which is as close to one source as a matcher and a writer can get.
    #>
    param([Parameter(Mandatory)][int]$Tier)
    # TIER 0 HAS NO HEADING AT ALL SINCE AUGUST 23, 2026, and this function says so by returning ''. The
    # entry's own heading -- '## `<branch>` DEPLOY', the development cycle's fourth phase -- IS tier 0's
    # section, and it is written by the formatter that opens the entry rather than by the one that writes the
    # tiers. Returning that heading here instead would need the branch name, which this function has no
    # business knowing, and emitting it from the tier writer would put it in the document twice.
    #
    # SO EVERY CALLER HAS TO HANDLE '': the writer skips the line, and a REFUSAL that names a heading uses
    # Get-EntryTierSectionLabel below, which turns the empty marker back into words a person can act on. That
    # is the whole reason the empty string is safe -- a gate telling an author to add a heading that does not
    # exist is worse than no advice at all, which is what this helper was created to prevent.
    #
    # Between August 19 and 23, 2026 tier 0's marker was the entry's opening question, one level down. A tier
    # that is neither 0 nor the audience tier -- a migration rendering tier 1 in a tier-2 repo, or any tier in
    # a repo that has stated no audience -- still falls through to the numbered sub-heading, which is the
    # shape those entries were written in and the one their reader knows.
    if (Test-EntryTierSectionsAreNamed) {
        if ($Tier -eq 0) { return '' }
        if ($Tier -eq (Get-EntryAudienceTier)) {
            return ('#' * (Get-EntryTierSubLevel)) + " $($script:EntryTierHigherHeading)"
        }
    }
    return ('#' * (Get-EntryTierSubLevel)) + " $($script:EntryTierSubPrefix) $Tier"
}

function Get-EntryTierSectionLabel {
    <#
        How to NAME one tier's section to a person -- the heading where it has one, and a description of the
        place where it does not.

        THIS EXISTS BECAUSE TIER 0 STOPPED HAVING A HEADING (August 23, 2026). Every refusal that points at a
        missing tier used to be able to quote its heading, and tier 0's is now the entry's own -- which the
        marker deliberately does not return. A refusal reading "add a '' section" is worse than the defect it
        reports, so the one place that turns a marker into advice is here rather than in each gate.
    #>
    param([Parameter(Mandatory)][int]$Tier)
    $marker = Get-EntryTierSectionMarker -Tier $Tier
    if ($marker) { return $marker }
    # UNQUOTED, like every Marker value in this file: the gates that print one wrap it in single quotes
    # themselves, and a label that quoted itself would arrive doubled in the one message a reader is already
    # struggling with. So this reads as a heading would in that slot -- a place rather than a string.
    return "the entry's opening text, directly under its own heading"
}

# --- 'Higher than tier 0?' -- THE AUDIENCE TIER'S HEADING (Dave, August 16, 2026) ------------------
#
# The second tier section is headed with the QUESTION instead of with its number. Two things that buys, and
# the second is why it is worth a special case in a file that otherwise keeps its keys literal:
#
#   * the routing comment underneath it disappears, because the heading is the question;
#   * the TEMPLATE stops naming a tier this repo happens to have. It used to read '#### Tier 2', which is
#     only right for a repo whose audience is 2 -- a document shipped to consumers, telling a tier-1 repo
#     the wrong number.
#
# IT RESOLVES TO A NUMBER ON READ, from Get-EntryAudienceTier, which is why this is safe at all: the repo
# states its one audience tier and the heading means that tier. A repo that has stated NONE gets the
# numbered headings exactly as before -- there is no single tier for the question to resolve to, and a
# heading that resolved to nothing would silently read as tier 0 and empty every release. That is what
# Test-EntryTierSectionsAreNamed guards, and it is deliberately the conservative direction: an
# unconfigured consumer taking this plugin update sees no change at all.
#
# READ ALWAYS, WRITTEN CONDITIONALLY -- the standing rule. Read-EntryTierSections recognises this heading
# in every repo, configured or not, because an entry carrying it may have been written anywhere and folded
# here; only the WRITER asks whether this repo has an audience tier to mean by it.
# RETEXTED ON AUGUST 19, 2026, SAME LEVEL, SAME MECHANISM. Everything the block above says still holds -- it
# resolves to a number on read, it is recognised in every repo and written only where one audience tier is
# stated. What changed is the words: the heading stopped naming the mechanism ("higher than tier 0") and
# started naming what is being asked of the author. It stays a '####' sub-heading of the question's section
# (Dave), so the entry still has two '###' sections and this string is not one of them.
# RETEXTED AGAIN ON AUGUST 24, 2026 (Dave, issue #865): 'deploy' became 'PR'. The same issue removed the PR
# template's heading, so the document the section travels into is read as the PR it opens rather than as the
# deploy it describes, and the heading followed the reader.
# REVERSED ON AUGUST 25, 2026 (Dave, issue #884), AFTER ONE DAY, AND THIS TIME THE REASON IS THE SECTION'S
# WHOLE JOURNEY RATHER THAN ITS FIRST STOP. #865 optimised for the reader of the document the section opens.
# But the section travels four times -- the branch's development document -> the PR body -> CHANGELOG.md -> the developer
# release notes -- and #865's own comment named that tension itself, one word wide, and shipped anyway. Two
# of those four readers are not looking at a PR, and the two that come last are the ones a release is read
# from. #884 asks for one thing in all four places, so the wording follows the SECTION rather than any one
# of its readers, and 'deploy' is the only word that is true at every stop.
#
# RECENCY WAS NOT THE ARGUMENT, IN EITHER DIRECTION. #865's reasoning was reread before this was reversed,
# and the half of it that holds is kept: it removed the PR template's heading, so the section stands on its
# own wherever it lands, and that is what makes carrying its own '## DEPLOY:' heading into the PR body
# possible at all (see Get-PrDescription). What it got wrong is which reader the wording serves.
#
# THE COST OF A ONE-DAY WORDING IS PAID BY THE READER LIST BELOW, NOT BY THE WRITER. 'PR' was written from
# August 24 to 25, 2026 -- one day, which is long enough for a branch to be in flight here and in every
# consumer, and CHANGELOG.md was holding entries written under it at the moment it was retired. That is now
# twice this heading has been retired after a single day, which is an argument for the recognise-all rule
# rather than against reversing: a reversal costs two lines below and nothing anywhere else, because the
# READERS are the union of this constant and that list. The list itself is not append-only -- this reversal
# is the first time a member has left it, and the block below is where that case is worked out.
$script:EntryTierHigherHeading = 'What makes this deploy extra special'

# THE RETIRED WORDINGS, RECOGNISED AND NEVER WRITTEN. 'Higher than tier 0?' was written for three days,
# August 16 to 19, 2026, which is long enough to reach CHANGELOG.md, the branches in flight and -- through a
# release -- every consumer's tree. A parser that forgot it would read every one of those entries as declaring
# tier 0 alone, which is the silent direction that empties a release. Recognise all, write one.
# 'What makes this change extra special' JOINED IT ON AUGUST 23, 2026 (Dave), when the entry became the
# development cycle's DEPLOY section: the document says 'deploy' throughout, so the heading asks about the
# deploy rather than about the change. It was written from August 19 to 23, 2026 -- which is every entry
# pending in CHANGELOG.md and every branch in flight, here and in every consumer.
# 'What makes this PR extra special' JOINED IT ON AUGUST 25, 2026 (Dave, issue #884) after ONE DAY -- the
# shortest life any of these has had, and the second one-day wording in a row. It is written from August 24
# to 25, 2026, which is long enough for a branch to be in flight here and in every consumer, and
# CHANGELOG.md was holding entries under it at the moment it was retired.
#
# AND ON THE SAME DAY 'What makes this deploy extra special' LEFT THIS LIST, which is the first time a
# wording has come back, and the one case worth writing down because getting it wrong is silent in both
# directions. THIS LIST MEANS "NEVER WRITTEN", so a heading that is written again cannot stay on it: the
# scaffold would then emit a string its own suite asserts is absent (entry-scaffold.tests.ps1 loops this
# array against the scaffold), and the invariant that makes the list safe to trust would be gone.
#
# NOTHING STOPS BEING READ BY LEAVING, and that is why removing it is not the mistake it looks like. Every
# reader unions the WRITTEN heading with this list -- Read-EntryTierSections here, and both entry checks in
# check-plugin-integrity.ps1 -- so an entry written under 'deploy' between August 23 and 24 is recognised by
# the written constant above rather than by this array. The rule is unchanged and now runs in both
# directions: a wording leaves the WRITER and never the READER, and a wording that returns to the writer
# leaves this list without ever leaving the reader.
$script:EntryTierHigherRetiredHeadings = @('What makes this PR extra special',
                                           'What makes this change extra special', 'Higher than tier 0?')

function Get-EntryTierHigherHeading {
    <# The heading text the audience tier's sub-section carries. Deliberately not quoted here: the wording has
       been retexted repeatedly and a docstring restating it goes stale silently. A COUNT OF HOW OFTEN GOES
       STALE JUST AS SILENTLY, which is why this sentence carries none -- read the constant above, where each
       retext is dated.
       Machine-read by the parser, so it is stated once and is deliberately not repo-configurable -- the same
       class as 'Tier' and 'Score'. A repo that translated it would make its own entries unreadable to its own
       fold. #>
    return $script:EntryTierHigherHeading
}

function Get-EntryTierHigherRetiredHeadings {
    <# Every heading the audience tier's section has carried and is still recognised under, newest first. A
       WRITER must never use one. #>
    return @($script:EntryTierHigherRetiredHeadings)
}

function Test-EntryTierSectionsAreNamed {
    <# Does THIS repo write the tiers under headings that NAME THE QUESTION rather than the tier -- the
       entry's opening section for tier 0, and Get-EntryTierHigherHeading's wording inside it for the
       audience tier? Only where it has stated one audience tier, which is the tier that second heading then
       means. Where it has not, the numbered '#### Tier N' sub-headings stay -- tier 0 among them, so it keeps
       a heading there -- and so does the routing comment between them; see the block above for why that
       fallback is the safe direction.
       Called Test-EntryTierHeadingAsksRoute until August 19, 2026, when the same condition came to govern
       both headings rather than only the audience tier's; the name follows what it decides. #>
    return ($null -ne (Get-EntryAudienceTier))
}

function Get-EntryScorePattern {
    <#
        The regex that reads a score line, capturing the value: '**Score:** 3' and the plain 'Score: 3'
        alike, with or without a value after it.

        ONE PATTERN, BUILT FROM THE KEY, so the two decorations can never become two separately-maintained
        literals. The asterisks are optional on each side independently rather than as a pair -- a
        half-bolded '**Score:' costs the entry its ranking if it is not read, and reading it costs nothing.

        TWO GROUPS: the value is the FIRST non-whitespace token, and anything after it on the line is a
        second, optional group -- a reason the author trailed on the score line instead of writing it
        above (issue #1172). The value used to be '(\S*)' immediately before '\s*$', so a line carrying
        a trailing reason -- '**Score:** N/A -- <reason>' -- matched nothing at all, and the tier read
        back as unanswered rather than as the N/A it declared. Reading the first token keeps the score,
        and Read-EntryTierSections routes group 2 to the below-score bucket so the #596 diagnostic names
        it as misplaced. '(\S*)' still allows an empty value, so a freshly scaffolded '**Score:**' with
        nothing after it matches exactly as before.
    #>
    return '^\s*(?:\*\*)?' + [regex]::Escape($script:EntryScoreKey) + ':(?:\*\*)?\s*(\S*)(?:\s+(\S.*?))?\s*$'
}

$script:EntrySignificanceWordingDefaults = [ordered]@{
    # One question per tier, printed under that tier's score, sending the author to the next one. Written
    # as a QUESTION with both answers spelled out, because the failure it prevents is silence: an author
    # who simply stops after tier 0 has not decided that colleagues get nothing out of the change, they
    # have not been asked. Tier 2 has no successor, so it carries none.
    #
    # LINE ARRAYS, NOT SENTENCES, because these are rendered into a comment block whose width is part of the
    # form -- see Format-EntryGuidanceComment. A single long string produced one 130-column line in a file
    # whose every other comment line stops around 78, which is exactly the sort of difference that gets
    # "tidied" by hand and then reported as template drift by the lint. The break is stated here, once.
    # THE 'IF NOT' HALF NAMES AN ACTION NOW (Dave, August 7, 2026). It used to say "stop here", then
    # briefly "leave tier 1 and 2 empty" -- and that second wording contradicted the tier guidance below,
    # which asked for a reason and an N/A. One instruction per case: an unreached tier is ANSWERED, because
    # a blank cannot be told apart from an unfinished one and the gate has to tell those apart.
    # THE QUESTIONS STATE THE POST-#620 DEFINITION (inbound #640, August 13, 2026). They used to ask about
    # "colleagues and employers" (tier 1) and "customers and users" (tier 2) -- the pre-#620 ladder, which
    # inverts the answer for exactly the case the audience model is built on: a webshop's customers are
    # literally "customers and users", yet its audience is 1, because they buy a product and never read a
    # release note. One consumer answered the knob wrong from these strings before they were repaired.
    Route0 = @(
        'Is this change also relevant to management and the employer/commissioner? Then continue to Tier 1.',
        'If not, say so there in one line and put N/A in its Score.'
    )
    Route1 = @(
        'Is this change also relevant to a subscriber of the service? Then continue to Tier 2.',
        'If not, say so there in one line and put N/A in its Score.'
    )
    # The two openers of the template's commented-out tiers. Template-only prose, kept beside the questions
    # they follow rather than inside Add-TemplateTierPrompt, so a repo that translates the form translates
    # all of it from one place.
    Uncomment1 = 'UNCOMMENT Tier 1 if management and the employer/commissioner get something out of this change.'
    Uncomment2 = 'UNCOMMENT Tier 2 as well if a subscriber of the service notices it.'
}

# RECOGNISED, NEVER WRITTEN -- the one-line forms of the two questions above, as they stood for the day
# between the sub-sections shipping and the dossier form breaking them over two lines. Read-EntryTierSections
# filters them out of the Why for the reason it filters the current ones: this repo's own form text must
# never be read back as the author's reason and published as it. Deliberately not repo-configurable, like
# every other historical string here -- a repo that translated the questions translated the CURRENT ones.
$script:EntrySignificanceRetiredRoutes = @(
    'Is this change also relevant to colleagues and employers? Then continue to Tier 1. If not, stop here and move on to the next section.',
    'Is this change also relevant to the people who consume this product? Then continue to Tier 2. If not, stop here and move on to the next section.',
    # The pre-#640 first lines (retired August 13, 2026): they carried the pre-#620 audience definition.
    # Their second line is unchanged and still current, so only the questions themselves retire here.
    'Is this change also relevant to colleagues and employers? Then continue to Tier 1.',
    'Is this change also relevant to customers and users? Then continue to Tier 2.'
)

$script:EntryGuidanceDefaults = [ordered]@{
    # One block per field, written as an HTML comment ABOVE the place the answer goes. Borrowed from this
    # repo's own .github/ISSUE_TEMPLATE/inbound-improvement.md, whose fields each say what a good answer
    # looks like without occupying the line the answer is written on (Dave, August 6, 2026).
    #
    # THE VISIBLE 'TODO:' STAYS UNDERNEATH, and that is the half deliberately NOT borrowed. Replacing it
    # with a comment would make an unfinished entry render as an EMPTY section rather than as a visible
    # TODO -- the gate still catches it in the source, but the gate has a -Force, and past that point the
    # defect ships invisibly instead of obviously. Guidance goes in the comment; the prompt stays in view.
    # THE THREE BRANCH FIELDS WERE SHARED BY BOTH FILES, which is why they live here rather than in
    # Get-BranchFileWording beside the rest of the document's prose. The dossier form briefly put the same
    # three sections at the top of branch-deployment.md AND branch-cycle.md; two copies of the heading and
    # the hint is the drift shape this repo keeps paying for, and there it was visible on every branch --
    # two files, side by side, free to disagree about what to write in the same box. There is one document
    # now, so the case cannot arise; these stay here because the entry's own sections read them.
    #
    # WRITTEN AS COMPLETE COMMENT LINES rather than as text to be wrapped in one. Format-EntryGuidanceComment
    # passes a block through untouched when it is already a comment, because these four are Dave's own
    # one-liners and their spacing is not derivable from a rule -- '<!-- Short' has a space after the marker
    # and '<!--unique' does not. The templates are the spec, so the literal is the honest representation.
    # THE HINT FOLLOWED THE SECTION'S JOB (#506, August 7, 2026). It read '<!-- Short description of
    # branch-->' while the section was called 'Branch description'; it is the PR title now, and a hint that
    # still said "description" would send the next author to write a paragraph into a field that becomes a
    # one-line title. Dave's one-liners are the spec here, so this stays one line in the same register --
    # and the templates are REGENERATED from it rather than edited beside it.
    Description = @('<!-- Short title of the change -- also the PR title, so no feat:/fix:/docs: prefix-->')
    Id          = @('<!--unique ID for branch like a timestamp of the moment this branch is created-->')
    Type        = @('<!-- options for type are: feat, fix or docs-->')
    # Translated on Dave's word (August 7, 2026): it closed in Dutch, and this line is script-generated
    # document content that travels to consumers in the plugin cache -- the one layer .claude/rules/
    # language-layers.md is explicit about. The template followed from here rather than the other way
    # round, which is the sanctioned direction: change the format here and every document written from it
    # follows, because there is no second copy of the form to update.
    # TWO LINES SINCE AUGUST 16, 2026, because the section gained the PR title. The first line says what the
    # author writes here at creation, the second what the fold writes underneath at the merge -- one hint per
    # fact, in the order the two arrive. Written as complete comment lines for the reason the four above are:
    # this is Dave's own spacing, and the document he hand-merged on August 23, 2026 is the spec.
    # EMPTY SINCE AUGUST 23, 2026 (Dave): no comment may stand inside the DEPLOY section, which is the
    # part that travels into CHANGELOG.md. The PR-title rule moved into the visible block above.
    PullRequest = @()
    What = @(
        'What the change DOES, for someone reading CHANGELOG.md months from now --',
        'not a report of what you did on the branch. Name what is different afterwards,',
        'and where a decision was measured rather than assumed, say what was measured.'
    )
    # 'ABOVE the Score line' IS LOAD-BEARING, NOT STYLE (inbound #596). The parser takes everything up to
    # the score as the reason and discards what follows, and the scaffold leaves one blank line on EACH side
    # of that line -- so the two places read identically and only one is read. Measured in a consumer: three
    # tiers answered, all three written underneath, all three refused, and finding out why took reading
    # entry-scaffold-lib.ps1 line by line. The gate names the misplacement now; this is the half that gets
    # said BEFORE the author writes rather than after, which is the same argument new-branch already makes
    # for printing the rubric at scaffold time.
    # AND THE LINK CONVENTION, which is the one field-level rule that CANNOT be derived from the file in
    # front of you (inbound #806). This text folds verbatim into the CHANGELOG, so a relative link in it has
    # to resolve FROM WHERE THAT FILE SITS rather than from here. Nothing said so, and the natural instinct
    # produced the broken form: a consumer merged two '../../scripts/...' links that landed at the root
    # pointing outside the repo, with every gate green. Said HERE and not only in the gate that refuses it,
    # for the same reason the line above says 'ABOVE the Score line' -- guidance that arrives before the
    # author writes is worth more than a refusal afterwards.
    # WHICH DIRECTORY THAT IS, IS A SEAM AND NOT THE ROOT (inbound #967). It was the root in every repo until
    # #914 made the changelog isolate-by-default, and a consumer's now sits in the workflow folder -- the same
    # directory this document is in, where the correct link is the one that already reads correctly here. So
    # the sentence is composed per repo by Format-EntryLinkGuidance rather than typed, and open-pr's gate
    # resolves from the same value: a rule stated as a fact about the root was wrong in exactly the repos it
    # was shipped to.
    #
    # IN THIS BLOCK AND NOT IN 'What', which is where it went first and would have been invisible: the
    # two-section entry renders 'Tier' above the section the body is written in, and 'What' is no longer
    # rendered by that shape at all. Nor in 'TierOptional', which is the SECOND section's block -- one
    # sentence, above the field the links actually appear in.
    # EMPTY SINCE AUGUST 23, 2026 (Dave), same reason as PullRequest above. The two rules with a SILENT
    # failure mode -- the Score line and the root-relative link -- were hoisted into StepsGuidance.
    Tier = @()
    # TIER 0 IS THE ONE TIER THAT IS ALWAYS REACHED -- every change matters to the people maintaining this
    # repo, if only a little -- so it is the only one with no N/A to offer. Tiers 1 and 2 get the extra
    # paragraph, which is why this is a second block rather than a longer version of the one above.
    # SHORTER THAN THE TIER 0 BLOCK ABOVE IT SINCE AUGUST 16, 2026, and the difference is deliberate rather
    # than an oversight. This block sits one screen below that one, so the three sentences about the Score
    # line and the rubric were being read twice on the way down a form whose whole revision was about
    # length. What only this tier needs -- the way out when the change reaches nobody here -- is what stays.
    # '{0}' IS THE AUDIENCE SENTENCE, resolved per repo by Format-EntryAudienceGuidance (August 19, 2026).
    # The heading above this block stopped naming a tier number when it started naming what is being asked,
    # so this line is where the author is told which reader they are writing for -- and it has to
    # say the repo's own tier rather than list both, because tier 1 and tier 2 are two kinds of audience and
    # a repo has exactly one. The token used to be a trailing space: the sentence was cut on August 16 and
    # its space stayed behind, which is the shape that reads as "something was deleted here".
    # AND IT NOW SAYS THAT 'NOTHING' IS A WHOLE ANSWER (inbound #810, August 21, 2026). The heading above
    # this block asks what makes the change extra special and names no reader, so an author with nothing to
    # tell that reader reads it as a general 'anything else notable' slot and fills it anyway. Measured in
    # the reporting repo, twice in one afternoon: 240 and 192 words under a score of N/A, against 28 to 78
    # words in the seven neighbouring entries that answered the same tier the same way. So the norm exists
    # and is followed -- and the only thing contradicting those two pages of text was the N/A underneath
    # them. Neither the rubric nor the score was wrong; what was missing is that the short answer is the
    # normal one. THE HEADING IS DELIBERATELY LEFT ALONE: it was retexted three days earlier for a reason
    # that still holds, and the reporter named this block as the cheaper of the two places.
    # WHERE THE AUTHOR MEETS THIS TEXT IS THE TEMPLATE, NOT THE ENTRY, which the report had the other way
    # around -- checked rather than inherited. -WithGuidance has been off for the working file since
    # August 7, 2026, so this block rendered into branch/templates/branch_template_deployment.md -- the file
    # BESIDE the one the author writes in, which is the arrangement the report was really about.
    # AND THAT IS REPAIRED AS OF AUGUST 23, 2026: guidance is unconditional, so this block renders into the
    # document a branch is actually handed. The report named the right layer and the wrong file; both are now
    # the same file.
    # EMPTY SINCE AUGUST 23, 2026 (Dave), same reason. Format-EntryAudienceGuidance returns @() on empty
    # input, so the {0} audience seam simply has nothing to fill in and no caller changes.
    TierOptional = @()
}

function Get-OverrideMapValue {
    <#
        The value a consumer's override map carries for one key, or $null where it carries none.

        TWO CONTAINERS TO SUPPORT, because a seam is hand-written: a hashtable is what a consumer reaches
        for, an ordered dictionary is what copying a defaults block produces, and a pscustomobject is what
        a repo returning a literal object hands back. A pscustomobject CANNOT BE INDEXED BY STRING in
        PS 5.1 -- $o['Key'] returns $null silently, which would read as "override absent" for every key a
        consumer set -- so that shape is read through PSObject.Properties instead.

        ABSENT AND PRESENT-BUT-NULL ARE THE SAME ANSWER HERE, deliberately: every caller skips both, so
        collapsing them costs nothing and saves the sentinel that a separate "was it there" flag would
        need.

        WHAT COUNTS AS AN ANSWER IS NOT THIS FUNCTION'S QUESTION (#941). Three getters in this file read a
        map this way, and they do NOT agree on the line that follows: the two wording getters ignore an
        empty value and keep their default, while Get-EntryGuidance takes it, because a repo that wants no
        guidance says so by returning nothing. Folding those two rules into one helper would have made an
        empty guidance block unreachable -- so the READ is shared and the VERDICT stays with the caller.
    #>
    param(
        [AllowNull()]$Map,
        [Parameter(Mandatory)][string]$Key
    )
    # EVERY RETURN IS COMMA-WRAPPED, AND THAT IS LOAD-BEARING. A function returning @() emits NOTHING,
    # so the caller's variable is $null rather than an empty array -- and a one-element list is UNROLLED
    # to the bare element, so a consumer's single-item override would come back a string. The two loops
    # this was promoted out of read the value INLINE and never met either. The regression was caught by
    # entry-scaffold.tests.ps1 asserting that an empty guidance block survives the seam, which is what
    # Get-EntryGuidance documents a repo may say. ',$x' returns the object itself, whatever shape it has.
    if ($Map -is [System.Collections.IDictionary]) {
        if (-not $Map.Contains($Key)) { return $null }
        return ,$Map[$Key]
    }
    if ($Map -and $Map.PSObject.Properties[$Key]) { return ,$Map.PSObject.Properties[$Key].Value }
    return $null
}

function Merge-WordingOverrides {
    <#
        A consumer's wording overrides merged over a defaults map, as a pscustomobject -- the whole body
        of both Get-EntrySignificanceWording and Get-BranchFileWording.

        IT WAS THE SAME LOOP TWICE, thirty-three hundred lines apart in this file, and what it cost was
        measured rather than predicted (#941). #927 was a hole in the second fail-safe below; repairing it
        meant writing the identical guard line into BOTH loops, and noticing the second one at all was
        luck -- the report named StepPhases, while Route0 and Route1 in the significance defaults are
        list-valued for exactly the same reason. A repair aimed at the reported key alone would have
        shipped with the same bug one key over, in the same file.

        NOT Get-EntryScaffoldWording'S THREE SEPARATE GETTERS, which stay exactly as they are: each of
        those is read by a GATE that must match the writer string-for-string, so each is its own contract
        with its own name. These two were one mechanism copied, and that is what makes them promotable
        where those three are not.

        WHAT COUNTS AS AN ANSWER FROM A CONSUMER is the rule this function states, once:

          - A KEY PRESENT BUT EMPTY IS IGNORED, the same fail-safe Get-EntryScaffoldWording uses: an empty
            heading would produce a document with a blank line where its title should be, and nothing
            would report it. An empty string is falsy, so a consumer who empties a key keeps the default.
          - AND A LIST THAT LEAVES NOTHING USABLE BEHIND IS IGNORED TOO (#927, August 26, 2026). The
            truthiness test measures the CONTAINER, and for every scalar that is the right question; an
            empty array is falsy too, so that state is not reachable through it either. A list of BLANKS
            is a third object and the one that got through -- two empty strings make a two-element array,
            which is TRUTHY -- so it passed the test and was emptied AFTERWARDS, downstream, where every
            reader of a list here filters the blanks out. StepPhases showed what that cost:
            Format-Development was left with no phase heading to write the scaffolded step under,
            wrote it bare, and the step landed in the region check-branch-entry.ps1's #899 check calls the
            preamble -- so that consumer's EVERY branch was refused, with no way through but deleting the
            step the scaffolder had just written for them. The two sides of the seam disagreed about one
            word: this one asked whether anything was THERE, the readers asked whether anything was
            USABLE. It asks the readers' question now, so 'empty' means the same thing on both sides.

        ONLY KEYS THE DEFAULTS ALREADY CARRY ARE READ, so a consumer inventing a key of their own gets it
        ignored rather than added -- which is what keeps the map a contract instead of a bag.

    .PARAMETER Defaults
        The English defaults map: $script:EntrySignificanceWordingDefaults, $script:BranchFileDefaults.

    .PARAMETER OverrideCommand
        The NAME of the consumer's seam function. A name rather than a value, so "is it defined at all"
        has one answer here instead of one per caller; an undefined seam simply returns the defaults.
    #>
    param(
        [Parameter(Mandatory)]$Defaults,
        [Parameter(Mandatory)][string]$OverrideCommand
    )
    $out = [ordered]@{}
    foreach ($key in $Defaults.Keys) { $out[$key] = $Defaults[$key] }

    if (-not (Test-FunctionDefined $OverrideCommand)) { return [pscustomobject]$out }
    $overrides = & $OverrideCommand
    if (-not $overrides) { return [pscustomobject]$out }

    foreach ($key in @($out.Keys)) {
        $v = Get-OverrideMapValue -Map $overrides -Key $key
        if (($v -is [Array]) -and @($v | Where-Object { $_ }).Count -eq 0) { continue }
        if ($v) { $out[$key] = $v }
    }
    return [pscustomobject]$out
}

function Get-EntryGuidance {
    <#
        The per-field guidance blocks, as an object of string arrays -- this repo's answers where
        scripts/repo-config.ps1 supplies them via Get-EntryGuidanceOverrides.

        A repo that wants none can return empty arrays: Format-EntryGuidanceComment renders nothing for an
        empty block, so the scaffold is exactly what it was before this existed.
    #>
    $out = [ordered]@{}
    foreach ($key in $script:EntryGuidanceDefaults.Keys) { $out[$key] = $script:EntryGuidanceDefaults[$key] }
    if (Test-FunctionDefined 'Get-EntryGuidanceOverrides') {
        $override = Get-EntryGuidanceOverrides
        foreach ($key in @($out.Keys)) {
            # THE READ IS SHARED, THE ANSWER RULE IS NOT (#941). Get-OverrideMapValue is the same container
            # walk the two wording getters use -- the hashtable/pscustomobject split and the PS 5.1
            # string-indexing pitfall live there now. What differs is the line below it: there an empty
            # value means "no answer, keep the default", here it means "this repo wants no guidance", which
            # is a documented answer. So anything PRESENT is taken, empty included.
            $v = Get-OverrideMapValue -Map $override -Key $key
            if ($null -ne $v) { $out[$key] = @($v) }
        }
    }
    return [pscustomobject]$out
}

function Format-EntryGuidanceComment {
    <#
        One guidance block as HTML comment LINES, or @() when the block is empty.

        MULTI-LINE WITH THE MARKERS ON THEIR OWN LINES, deliberately: the stripper below removes whole
        lines, so a comment sharing a line with content would either survive with its content or take the
        content with it. Keeping the two apart is what makes the removal exact rather than clever.

        A BLOCK THAT IS ALREADY A COMPLETE ONE-LINE COMMENT IS PASSED THROUGH UNTOUCHED. Four of the fields
        carry Dave's own hand-written one-liners, whose spacing is not derivable from any rule -- one has a
        space after the marker and the next does not -- so wrapping them again would both double the markers
        and normalise away the exact bytes the templates are held to. Remove-EntryHtmlComments strips a
        single-line comment just as happily as a block, so nothing downstream can tell the two apart.
    #>
    param([AllowEmptyCollection()][string[]]$Lines = @())
    $body = @($Lines | Where-Object { $null -ne $_ })
    if ($body.Count -eq 0) { return @() }
    # ALREADY A COMPLETE COMMENT -> UNTOUCHED, whether it is one line or several. The single-line case is
    # Dave's four hand-written one-liners; the multi-line case arrived with the Pull Request hint on
    # August 16, 2026, which opens on its marker and closes two lines down. Both are the same rule --
    # the templates are the spec, so a block that already spells its own markers keeps its exact bytes
    # rather than being wrapped a second time.
    $first = ([string]$body[0]).TrimStart()
    $last  = ([string]$body[$body.Count - 1]).TrimEnd()
    if ($first.StartsWith('<!--') -and $last.EndsWith('-->')) { return @($body | ForEach-Object { [string]$_ }) }
    $out = @('<!--')
    # An empty guidance line stays EMPTY rather than becoming five spaces: trailing whitespace is
    # invisible in an editor, survives every diff, and is the kind of thing a byte-exact template check
    # then reports as drift for a reason nobody can see.
    foreach ($line in $body) { $out += $(if ($line) { '     ' + $line } else { '' }) }
    $out += '-->'
    return $out
}

function Remove-EntryHtmlComments {
    <#
        Removes whole-line HTML comments from an entry block -- the guidance the scaffold writes above each
        field -- leaving everything else, including the line endings, exactly as it was.

        THE FOLD CALLS THIS, WHICH IS WHY THE GUIDANCE CAN BE GENEROUS. An author who replaces the TODO
        underneath and leaves the comment standing has done nothing wrong: the comment is the form, not the
        answer, and the form does not belong in CHANGELOG.md. Stripping it at the fold means nobody has to
        remember to delete it, which is the whole reason this is safe to add -- a guidance block that had to
        be tidied by hand would just be a second thing the scaffold gate has to police.

        FENCE-AWARE, for the reason every reader here is: an entry documenting this mechanism shows a
        comment inside a fence, and this very entry does.

        ONLY WHOLE-LINE COMMENTS. A comment sharing a line with prose is somebody's inline note in their own
        sentence; removing the line would take their sentence with it, and removing only the comment would
        leave a dangling fragment. Multi-line blocks are handled by tracking the open marker, so the shape
        Format-EntryGuidanceComment writes is removed entirely.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$EntryText)

    $pair = Get-EntryLineFlagPairs -EntryText $EntryText
    $parts = $pair.Parts
    $out = New-Object System.Collections.Generic.List[string]
    $inComment = $false
    $any = $false
    $n = -1
    for ($i = 0; $i -lt $parts.Count; $i++) {
        if ($i % 2 -eq 1) { continue }
        $n++
        $line = $parts[$i]
        $sep = if ($i + 1 -lt $parts.Count) { $parts[$i + 1] } else { '' }
        $t = $line.Trim()

        if ($pair.Fenced[$n]) {
            $inComment = $false
        } elseif ($inComment) {
            $any = $true
            if ($t.EndsWith('-->')) { $inComment = $false }
            continue
        } elseif ($t.StartsWith('<!--')) {
            $any = $true
            # A single-line comment opens and closes on the same line; anything else opens a block.
            if (-not $t.EndsWith('-->')) { $inComment = $true }
            continue
        }
        $out.Add($line + $sep)
    }
    $t = ($out -join '')
    if (-not $any) { return $t }
    return [regex]::Replace($t, '(\r?\n)\1\1+', '$1$1')
}

function Get-EntrySignificanceWording {
    <#
        The editorial half of the Significance section -- the routing questions and the why-placeholder --
        with this repo's answers where scripts/repo-config.ps1 supplies them.

        One getter returning a map rather than three, for the reason Get-BranchFileWording gives: these are
        document prose read by a human, not markers a gate matches string-for-string, and a repo that
        translates one translates all of them.

        THE MERGE ITSELF IS Merge-WordingOverrides, shared with Get-BranchFileWording since #941. Route0
        and Route1 are list-valued here, so the list fail-safe #927 measured on StepPhases governs this map
        for exactly the same reason -- which is the whole argument for stating it in one place.
    #>
    return Merge-WordingOverrides -Defaults $script:EntrySignificanceWordingDefaults `
        -OverrideCommand 'Get-EntrySignificanceWordingOverrides'
}

function Format-EntrySignificanceSections {
    <#
        The Significance section's body as an array of LINES: one '#### Tier N' block per row, LOWEST tier
        first, each with its why, its 'Score: N' line and -- for every tier except the LAST one written --
        the question routing the author to the next tier.

        LOWEST FIRST, which is the opposite of the table it replaces. The table listed the furthest reach
        at the top because that is what decided the entry's position in the changelog. These sections are
        walked by a person filling them in, and that walk starts at tier 0: it is the one every change can
        answer, and each answer decides whether there is a next one. Ordering the document against the
        order it is written in would put the routing questions in reverse.

        Called with no rows it renders the SCAFFOLD: the tiers Get-EntryAskedTiers names -- tier 0 plus this
        repo's one audience tier, or every tier the model has where no audience is stated -- each with its
        guidance comment standing where the why goes and its score EMPTY. Tier 0 is the honest default claim
        -- reaches nobody outside this repo
        -- while a scaffolded SCORE would be a guess at a ranking, which is the failure the retired
        remove-before-publishing marker was measured on.

        THE VISIBLE 'TODO:' UNDER THE GUIDANCE IS GONE (Dave, August 6, 2026), which reverses the rule this
        format carried the day before -- "guidance in the comment, the prompt stays in view". It went because
        the dossier form removed every other visible placeholder with it, and one lone TODO in a file of
        comment blocks reads as leftover rather than as a prompt. What replaces it as the gate is not a
        string but a MEASUREMENT: Get-EntryScaffoldFindings now reports a section that is still EMPTY once
        the comments are stripped, which catches the untouched entry the placeholder used to catch AND the
        one whose placeholder was deleted rather than answered. Strictly more, and nothing to keep in sync.

        One formatter for the writer and any migration, so the parser below can never meet a shape nothing
        here produced.
    #>
    param(
        $Rows = @(),
        [switch]$WithGuidance,
        # Prose that belongs at the TOP of tier 0's section, above whatever that row carries -- a migration's
        # old free-text paragraph, which in the named shape has no section of its own to go in any more.
        # Empty for every other caller, and ignored outside the named shape, where Format-EntryBlock still
        # writes it under the question itself.
        [AllowEmptyString()][string]$Tier0Preamble = ''
    )
    $w = Get-EntrySignificanceWording
    # EVERY TIER THIS REPO ASKS ABOUT IS WRITTEN, AND EACH IS ANSWERED (Dave, August 7, 2026; narrowed to
    # one audience tier on August 12, 2026). The scaffold once emitted tier 0 alone with 1 and 2 offered as a
    # commented-out block; then all three as real sections; now tier 0 plus the ONE audience tier this repo
    # has, because tier 1 and tier 2 are two kinds of reader rather than two rungs. Get-EntryAskedTiers is
    # the single answer to "which ones", and where a repo has stated no audience it returns all of them --
    # so an unconfigured consumer gets exactly the file it got yesterday.
    #
    # A caller passing rows (a migration, a rewrite) gets exactly its own rows back, so nothing invents a
    # tier for an entry written under an older model and nothing DROPS one either: an entry that answered
    # all three keeps all three, which is what makes 97 existing entries re-renderable.
    $ordered = @(@($Rows) | Sort-Object -Property @{Expression = { [int]$_.Tier }; Descending = $false})
    if ($ordered.Count -eq 0) {
        $ordered = @(Get-EntryAskedTiers | ForEach-Object {
            [pscustomobject]@{ Tier = $_; Score = 0; Why = '' }
        })
    }

    # THE ROUTING QUESTIONS GO WITH THE GUIDANCE (Dave, August 7, 2026), which is the half of this worth
    # stating out loud, because it reverses his own decision of the day before. They were added so an author
    # who stops at tier 0 has DECIDED there is nothing above it rather than never having been asked -- and
    # they are comments, so the working file is where they did that work. Taking them out means the ladder
    # was then something you learned from branch/templates/ or from CONTRIBUTING.md rather than from the file
    # in front of you. He was shown both shapes side by side and chose this one; recorded here so the next
    # reader meets the trade rather than only the result -- and note that the trade EXPIRED on August 23,
    # 2026, when the guidance moved into the document and the templates went. The questions are back in front
    # of the author, which is what the comment above them says.
    #
    # KEYED ON WHAT IS ACTUALLY WRITTEN, NOT ON A FIXED PAIR, and that had to change with the audience knob
    # (August 12, 2026). It used to be the literal @{ 0 = Route0; 1 = Route1 }, which in a tier-2 repo would
    # print "continue to Tier 1" above a file whose next section is Tier 2 -- form text sending the author to
    # a heading that is not there. Each written tier except the LAST gets the question that routes to its
    # successor, and the wording key follows the TARGET: Route0's own text says "continue to Tier 1" and
    # Route1's says "continue to Tier 2", so the question routing to tier T is Route<T-1>. The names stay as
    # they are for that reason -- they are a consumer-overridable seam, and every repo that has translated
    # one translated it by these keys.
    $routes = @{}
    if ($WithGuidance) {
        for ($r = 0; $r -lt $ordered.Count - 1; $r++) {
            $target = [int]$ordered[$r + 1].Tier
            $key = "Route$($target - 1)"
            if ($w.PSObject.Properties[$key] -and $w.$key) { $routes[[int]$ordered[$r].Tier] = $w.$key }
        }
    }

    $lines = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $ordered.Count; $i++) {
        $row  = $ordered[$i]
        $tier = [int]$row.Tier
        if ($i -gt 0) { $lines.Add('') }
        # AN EMPTY MARKER MEANS THIS TIER HAS NO HEADING OF ITS OWN, which is tier 0 since August 23, 2026:
        # the entry's own '## `<branch>` DEPLOY' heading is its section, and Format-EntryBlock has already
        # written it. Adding a blank line here instead of a heading would leave a gap where a heading used to
        # be, so the whole line is simply not emitted.
        $marker = Get-EntryTierSectionMarker -Tier $tier
        if ($marker) { $lines.Add($marker) }
        # THE GUIDANCE COMMENT STANDS WHERE THE WHY GOES on an unanswered section, and nothing else does --
        # no placeholder line underneath it. A row that already carries a why is a migration or a rewrite of
        # a finished entry, and prefixing somebody's written answer with a form instruction would be noise
        # in exactly the document they just finished, so there the comment is what goes.
        #
        # THE BLANK AFTER THE HEADING BELONGS TO THE ANSWER, not to the heading (August 16, 2026). Where the
        # guidance comment follows, it opens directly under the heading -- the hand-designed template says
        # so, and a blank line above a comment block reads as a gap somebody left rather than as a form.
        # Where there is no comment, the blank stays: it is the space the reason is written into.
        $preamble = if ($tier -eq 0) { [string]$Tier0Preamble } else { '' }
        $answered = [bool](($row.PSObject.Properties['Why'] -and $row.Why) -or $preamble)
        if ($answered) {
            $lines.Add('')
            foreach ($line in @($preamble, [string]$row.Why | Where-Object { $_ })) {
                foreach ($ln in ($line -split '\r?\n')) { $lines.Add($ln) }
                $lines.Add('')
            }
        } elseif (-not $WithGuidance) {
            $lines.Add('')
        }
        if ((-not $answered) -and $WithGuidance) {
            # Tier 0 cannot be N/A -- see $script:EntryGuidanceDefaults.TierOptional -- so it gets the
            # block without that paragraph, and every tier above it gets the one that offers the way out.
            $g = Get-EntryGuidance
            $block = if ($tier -eq 0) { @($g.Tier) } else { @(Format-EntryAudienceGuidance -Lines @($g.TierOptional) -Tier $tier) }
            foreach ($line in (Format-EntryGuidanceComment -Lines $block)) { $lines.Add($line) }
        }
        # THE BLANK BELONGS TO A HEADING THIS LOOP WROTE, SINCE AUGUST 23, 2026. It used to ride on the
        # guidance block, which is empty now. Tier 0 has no marker of its own -- Format-EntryBlock wrote
        # '## DEPLOY: `<branch>`' AND the blank under it -- so adding one here gave that section two, the
        # shape the comment below calls "something was deleted here". Every tier above it writes its own
        # heading and therefore owns the blank that follows it.
        if ($marker) { $lines.Add('') }
        # An unanswered section in a WORKING file is the heading, one blank line, and the score label -- the
        # blank is where the reason goes. Not two blanks: the guidance used to occupy that space, and leaving
        # its surrounding whitespace behind is the shape that reads as "something was deleted here".
        # THREE THINGS THIS LINE CAN SAY, matching what the parser reads back: a number, 'N/A' for a tier
        # the change reaches nobody at, or nothing at all -- a question left standing rather than a number
        # nobody chose. Get-EntryImpactFindings is what refuses the third before the PR.
        $score = ''
        if ($row.PSObject.Properties['NotApplicable'] -and $row.NotApplicable) {
            $score = ' ' + $script:EntryScoreNotApplicable
        } elseif ($row.PSObject.Properties['Score'] -and [int]$row.Score -gt 0) {
            $score = ' ' + [string][int]$row.Score
        }
        $lines.Add($script:EntryScoreLabel + $score)
        # EVERY SECTION THAT HAS A SUCCESSOR CLOSES WITH IT, including one whose successor is already
        # answered below it (Dave: "het kopje sluit altijd af met"). An earlier draft wrote it only under the
        # last section, on the grounds that a tier whose successor exists has already been answered. That is
        # true of the author and false of the reader: the entry is walked again at the fold, at the cut and
        # in the record, and a question that disappears once answered leaves the next reader unable to see
        # that it WAS asked. The LAST written tier has no successor and therefore carries none -- which used
        # to be a statement about tier 2 specifically, and is now about whichever audience tier this repo
        # asked for.
        #
        # AS AN HTML COMMENT (Dave, August 6, 2026). It is form text, not the author's answer, and it was
        # the last piece of form that travelled all the way into CHANGELOG.md and the development notes.
        # The fold strips comments, so the writer still sees it and the record never does.
        #
        # AND THE HEADING ASKS IT NOW, SO THE COMMENT IS GONE (Dave, August 16, 2026). The section above the
        # last one is headed 'Higher than tier 0?' -- the routing question, in the place a reader cannot skip,
        # costing no lines at all. A comment underneath repeating it was the same question twice, and the
        # form text this file has been steadily taking out of the author's way. $routes is still computed
        # above and still honoured for a repo that overrides the wording; where it is left at the default the
        # heading carries it.
        if ($routes.ContainsKey($tier) -and -not (Test-EntryTierSectionsAreNamed)) {
            $lines.Add('')
            foreach ($line in (Format-EntryGuidanceComment -Lines @($routes[$tier]))) { $lines.Add($line) }
        }
    }
    return @($lines.ToArray())
}

# THE RUBRIC -- the definition of each level, and the reason the number is a measurement. Every band is
# written as a TEST rather than a feeling ("must act", "noticed within a day"), so two people scoring the
# same change land on the same band and a reviewer can disagree with a specific claim instead of with a
# vibe.
#
# AN ARRAY OF PAIRS, NOT A MAP KEYED BY THE SCORE, and that is a bug this shape prevents rather than a
# style choice -- the very bug the retired Resolve-ChangelogTierSections was measured on, walked
# into again here on the first run. [ordered]@{ 5 = '...' } is an OrderedDictionary, whose indexer takes
# BOTH a key and a POSITIONAL INDEX, and the positional overload WINS for an integer. So $rubric[5] asks
# for the sixth element of a five-element map and throws -- and on a map with more levels than that it
# would not throw at all, it would silently return a neighbouring band's text. Pairs have no indexer to
# reach for.
$script:EntrySignificanceRubricDefaults = @(
    [pscustomobject]@{ Score = 5; Test = 'the reader must act -- a breaking change, a required migration, or a long-standing blocker that is now gone' }
    [pscustomobject]@{ Score = 4; Test = 'materially changes how they work; they notice within a day without being told' }
    [pscustomobject]@{ Score = 3; Test = 'a clear improvement, noticed the moment they touch that part' }
    [pscustomobject]@{ Score = 2; Test = 'small; noticed if somebody points it out' }
    # BAND 1 ASKS WHAT IS PREVENTED (Dave, #509, August 7, 2026). It read 'cosmetic or preventative --
    # nothing changes for them today', and the second half invited the sentence the rubric exists to
    # prevent: PR #503's entry scored its tier 0 with "Nothing changes here" -- technically inside the band,
    # and worth nothing to a reader a year later. A preventative change is the one case where the value is
    # ENTIRELY in what did not happen, so that is the one thing the band has to ask for. The other four
    # bands describe something the reader can observe; this one describes an absence, and an absence has to
    # be named or it is indistinguishable from having nothing to say.
    #
    # THE OBVIOUS ALTERNATIVE WAS REJECTED, and it is worth knowing why before anyone builds it. Dave asked
    # whether tier 0 scoring below tier 1 should be refused at all -- if nothing changes for this repo's own
    # developers, how can it change for anyone further out? The general claim does not hold, and PR #503 is
    # the counterexample: the defect existed ONLY outside this repo (consumers had no branch/templates/;
    # this repo always did), so it was worth 4 to a consumer and almost nothing here. The tiers are not
    # nested audiences -- a consumer is not a colleague of this project. That gate would have refused a
    # correct entry. The instinct behind it IS already encoded, correctly, one level down: tier 0 is the one
    # tier that cannot be N/A, because every change reaches this repo's own developers at least a little.
    # The floor is a score of 1, not nothing -- and band 1 now asks what that 1 buys.
    [pscustomobject]@{ Score = 1; Test = 'cosmetic, or prevents a failure that has not happened yet -- then name the failure, because that is the only part a later reader can use' }
)

function Get-EntrySignificanceRange {
    <# The scale, as an object with Min and Max (1 and 5). Read by the writer, the validator and the
       gates, so the bounds are stated once. #>
    return [pscustomobject]@{ Min = $script:EntrySignificanceMin; Max = $script:EntrySignificanceMax }
}

function Get-EntrySignificanceRubric {
    <#
        The scale's definitions: an array of objects with Score (int) and Test (string), highest first --
        the order it reads in and the order the gates print it in.

        REPO-OWNED VIA Get-EntrySignificanceRubricLevels, probed with Get-Command like every other prose
        knob in this file (#410's class). A rubric is the one part of this mechanism a repo genuinely
        might have to differ on: "the reader must act" means something different to a marketplace than to
        a storefront, and a repo whose consumers are non-technical needs its own wording. The HEADERS stay
        fixed while the rubric moves, which is the right split -- the key is machine-read, the definition
        is editorial.

        WHATEVER A REPO REWORDS, A BAND STAYS A TEST ABOUT THE READER (inbound #810, August 21, 2026).
        Every built-in level describes something the reader can observe -- "they notice within a day",
        "noticed the moment they touch that part" -- and that property is the whole reason one change can
        score differently at each tier at all. The paragraph above invites a rewording and every example it
        gives is about audience wording, so it read as licence to say anything; it never said what has to
        survive. The measured override added a clause about the DIFF instead -- "or changes what a customer
        sees or can do in the storefront" -- which is true or false regardless of who is reading, and it
        duly produced a 4 at tier 1 for a PreToolUse hook that reader cannot see anywhere. Reword the
        audience as freely as the repo needs; keep the sentence something the named reader could notice.
        A CONTRACT CHECK FOR IT WAS CONSIDERED AND NOT BUILT, on the reporter's own reasoning: flagging an
        override that drops every reader pronoun is a heuristic, and a band can be reader-relative without
        one ("cosmetic" is). This docstring is the layer that was actually missing.

        The override is accepted as a hashtable or ordered dictionary keyed by score, because that is the
        natural way to write one in a config file -- but it is read with GetEnumerator, never the indexer,
        for the reason in the comment above the defaults. A level the override omits keeps its built-in
        text rather than leaving a hole, so a repo can retune one band without restating five; a level
        whose override is empty is ignored, the same fail-safe Get-EntryScaffoldWording uses, because a
        blank rubric would make a gate print nothing exactly where it promises the definitions.
    #>
    $levels = [ordered]@{}
    foreach ($pair in $script:EntrySignificanceRubricDefaults) {
        # String keys throughout: an OrderedDictionary keyed by [int] is the trap documented above.
        $levels[[string]$pair.Score] = $pair.Test
    }
    if (Test-FunctionDefined 'Get-EntrySignificanceRubricLevels') {
        $override = Get-EntrySignificanceRubricLevels
        if ($override) {
            foreach ($entry in $override.GetEnumerator()) {
                $text = [string]$entry.Value
                if ($text) { $levels[[string]$entry.Key] = $text }
            }
        }
    }
    $out = @()
    foreach ($entry in $levels.GetEnumerator()) {
        $out += [pscustomobject]@{ Score = [int]$entry.Key; Test = [string]$entry.Value }
    }
    # Sorted rather than trusted: an override may introduce a level the defaults did not have, and it
    # arrives at the end of the dictionary regardless of its number.
    return @($out | Sort-Object Score -Descending)
}

function Format-EntrySignificanceRubricLines {
    <#
        The rubric as printable lines ('  5  the reader must act -- ...'), highest first.

        ITS OWN FUNCTION BECAUSE THREE READERS PRINT IT: the scaffold writer (so the author sees the scale
        at the moment the entry is created), open-pr.ps1 and cut-release.ps1 (so a refusal states the test
        the entry failed rather than only that it failed). A gate that says "write a number from 1 to 5"
        without saying what the numbers mean is asking for the guess this model exists to avoid.
    #>
    return @(Get-EntrySignificanceRubric | ForEach-Object { '  ' + $_.Score + '  ' + $_.Test })
}

function Test-EntrySignificanceActive {
    <#
        Does this repo rank its entries at all? $true unless it says otherwise.

        THE SECTION-COUNT HEURISTIC DIED WITH THE SECTIONS (August 5, 2026), and replacing it was not
        optional. This used to answer "off where there is no tier split", reading the changelog's section map
        and treating one section as "this repo never adopted tiers". That test had a real basis while the map
        existed -- the sections WERE the repo's declaration of which tiers it files. The flat changelog has no
        map -- and the resolver that read it is retired further down this file -- so keeping the old line
        would have read every repo as not ranking: the scaffold's table, both validators
        and the cut's significance gate would all have switched themselves off, silently, in the same commit
        that made the ranking the document's only ordering. Nothing would have errored.

        SO THE DEFAULT IS ON, WITH AN EXPLICIT OPT-OUT, which is also the consistent answer: the entry's
        section structure became unconditional in the same change, on the grounds that two entry shapes in one
        system need both paths in every reader forever. A repo that has not adopted the model is not harmed by
        being on -- its entries are tier 0, and tier 0 is asked for no score (Get-EntryImpactFindings), so
        every gate stays quiet by itself rather than by a flag.

        The seam is Get-EntrySignificanceEnabled in the consumer's scripts/repo-config.ps1, probed with
        Get-Command like every other optional knob. Returning $false there switches off the scaffold's table,
        both validators and the cut's gate together, because a half-adopted ranking (required but never read)
        is worse than neither. It does NOT switch off the fold's ORDERING: with the sections gone that
        ordering is what the three headings used to say, so it is structure rather than a preference.

        Test-ReleaseBumpEarned's own Active flag in release-lib.ps1 keys off the same retired section map and
        needs the same repair; it is left to the change that reworks the release side, because the answer
        there is about which release documents exist rather than about scoring.
    #>
    if (Test-FunctionDefined 'Get-EntrySignificanceEnabled') {
        return [bool](Get-EntrySignificanceEnabled)
    }
    return $true
}

function Format-EntryImpactTable {
    <#
        The impact table as an array of LINES -- header, separator, then one row per entry in $Rows
        (objects with Tier, and optionally Score and Why), highest tier first.

        Called with no rows it renders the SCAFFOLD: the header and a single tier-0 row with both value
        cells empty ('-'). That is the unedited entry's honest claim -- reaches nobody outside this repo,
        nothing to rank -- and it is exactly what the old 'Tier: 0' default said, in the shape that now
        carries it. RAISING THE TIER IS ADDING A ROW, so the rows an entry has are the claims it makes and
        there is no way to claim a reach without also saying what it is worth there.

        One formatter, so the writer, the parser and the gates cannot disagree about the cell padding.
    #>
    param($Rows = @())
    $empty = $script:EntryImpactEmptyCell
    $lines = @('| ' + ($script:EntryImpactHeaders -join ' | ') + ' |')
    $lines += '|' + (@($script:EntryImpactHeaders | ForEach-Object { '---' }) -join '|') + '|'
    $ordered = @(@($Rows) | Sort-Object -Property @{Expression = { [int]$_.Tier }; Descending = $true})
    if ($ordered.Count -eq 0) {
        $ordered = @([pscustomobject]@{ Tier = 0; Score = 0; Why = '' })
    }
    foreach ($row in $ordered) {
        $score = if ($row.PSObject.Properties['Score'] -and [int]$row.Score -gt 0) { [string][int]$row.Score } else { $empty }
        $why = if ($row.PSObject.Properties['Why'] -and $row.Why) { [string]$row.Why } else { $empty }
        $lines += "| $([int]$row.Tier) | $score | $why |"
    }
    return $lines
}

function Get-EntryTierReasonText {
    <#
        Private: the author's own reason out of a tier section's raw lines -- this format's guidance
        comments and its retired routing questions removed, whatever survives trimmed.

        THE GUIDANCE AND THE ROUTING QUESTION ARE THIS FORMAT'S OWN PROSE, not the author's answer, so
        neither may become the Why -- it would otherwise be published as the reason the change matters.

        BOTH FORMS ARE FILTERED. They are HTML comments since August 6, 2026 (stripped here by the shared
        remover), and they were bare prose before that -- so an entry written on either side of that change
        reads back the same. Same "recognise both" rule the three declaration shapes get.

        AND BOTH LINE-BREAKINGS OF THEM. The questions became two-line arrays when the dossier form fixed
        the comment width, so the one-line sentences they replaced no longer appear in the wording at all --
        and an entry carrying one as bare prose would have had this repo's own form text read back as the
        author's reason and published as it. @() flattens the arrays into individual lines, which is exactly
        the granularity the comparison needs.

        ONE HELPER FOR BOTH SIDES OF THE SCORE LINE, and that is why it exists rather than staying inline
        (inbound #596). Read-EntryTierSections collects the lines above '**Score:**' into Why and the lines
        below it into WhyBelowScore, and both need exactly the filtering above: a guidance comment sitting
        below the score would otherwise read back as a misplaced reason, and the gate would accuse an entry
        nobody had written in yet of having put its answer in the wrong place -- on every consumer, from
        their first branch. Two copies of the filter is how that divergence starts.
    #>
    param([AllowEmptyString()][AllowEmptyCollection()][string[]]$Lines = @())

    $w = Get-EntrySignificanceWording
    $routes = @(@($w.Route0) + @($w.Route1) + @($script:EntrySignificanceRetiredRoutes)) |
        Where-Object { $_ }
    $text = Remove-EntryHtmlComments -EntryText (@($Lines) -join "`n")
    return (@(($text -split '\r?\n') | Where-Object {
        $t = $_.Trim()
        if (-not $t) { return $false }
        foreach ($r in $routes) { if ($t -eq ([string]$r).Trim()) { return $false } }
        return $true
    }) -join "`n").Trim()
}

function Read-EntryTierSections {
    <#
        Private: the '#### Tier N' sub-sections in an already-defenced, already-split entry. Returns an
        object with Rows (the shape the table produces -- Tier, Score, Why, Raw, Error -- plus
        NotApplicable and WhyBelowScore, which only the section shape can carry) and Errors.
        Both empty means the entry carries no sections at all, which is what sends Resolve-EntryImpact on
        to the older shapes.

        AN OBJECT RATHER THAN A [ref] PARAMETER, and that is a bug fix rather than taste. The first version
        took `[ref]$result.Errors` -- a reference to a property of a pscustomobject -- and assigning through
        it silently wrote to a copy: every malformed section parsed, reported nothing, and the entry fell
        through to the legacy reader as an undeclared tier 0. Exactly the class of failure this parser
        exists to prevent, in the parser itself. Caught by the three malformed-input tests on their first
        run; a [ref] over a plain variable would have worked, but returning the pair cannot go wrong at all.

        Reporting the faults rather than absorbing them keeps the symmetry with the table: the gates above
        were written against ITS failures, and a shape that reported its own differently would slip past
        every one of them.

        WHAT COUNTS AS A FAULT, and each of these is a way to be silently wrong rather than merely untidy:

          * a heading that is not a whole number ('#### Tier two', '#### Tier 1a') -- it would otherwise be
            no section at all, so the reach it states would vanish;
          * a score outside the rubric's range, or one that is not a number;
          * the same tier declared twice, which leaves two different answers to one question.

        A MISSING SCORE IS NOT A FAULT HERE. It is a row with Score 0, exactly as an empty table cell was,
        and Get-EntryImpactFindings is what decides whether that blocks -- one place, so the fold can go
        ahead and say so out loud while the release cut refuses.
    #>
    param(
        # BOTH Allow* attributes, like Get-FencedLineFlags: the array is a document split on newlines, so
        # most of it is blank lines, and a [string[]] without AllowEmptyString rejects the whole call on
        # the first one (ParameterArgumentValidationErrorEmptyStringNotAllowed). Measured on the first run.
        [AllowEmptyString()][AllowEmptyCollection()][string[]]$Lines = @()
    )
    # A LEVEL RANGE RATHER THAN THE WRITTEN LEVEL, since August 23, 2026, and for the numbered shape it is
    # the whole of what keeps hundreds of entries readable: every '#### Tier N' ever written sits one level
    # deeper than the level this repo writes today. Get-EntryTierSubLevelRange spans both.
    $headRx  = '^\s*' + (Get-EntryTierSubLevelRange) + '\s+' + [regex]::Escape($script:EntryTierSubPrefix) + '\s+(\S+)\s*$'
    # The audience tier's section is headed with the question rather than with its number since August 16,
    # 2026. Recognised in EVERY repo, configured or not -- an entry carrying it may have been written
    # anywhere -- and resolved to a number below, where the repo that has stated no audience tier reports
    # the heading as unreadable instead of silently dropping the reach it declares.
    #
    # EVERY NAME IT HAS CARRIED, AND A LEVEL RANGE RATHER THAN THE SUB-LEVEL (August 19, 2026). Both wordings
    # were written at '####' and that is where the current one stays, so the range buys nothing today -- it is
    # here because this heading was briefly a '###' named section during the same day's work, and an entry
    # written against that intermediate shape would otherwise read as tier 0 alone. Costs one character in a
    # regex; the alternative is a silent misread of somebody's finished entry.
    $higherNames = @(@(Get-EntryTierHigherHeading) + @(Get-EntryTierHigherRetiredHeadings) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $levelRange = Get-EntryTierSubLevelRange
    $higherRx = '^\s*' + $levelRange + '\s+(?:' +
        ((@($higherNames) | ForEach-Object { [regex]::Escape([string]$_) }) -join '|') + ')\s*$'
    # --- TIER 0 HAS NO HEADING OF ITS OWN ANY MORE, so the ENTRY'S OPENING QUESTION is its heading -------
    #
    # Recognised under its current name and every retired one, for the reason every reader in this file is:
    # 'What does the change on this branch bring to main?' was written until August 19, 2026 and 'What does
    # this change do?' before that, and both are all over CHANGELOG.md and every consumer's tree.
    #
    # AND IT IS ONLY TIER 0 WHERE THE SECTION ACTUALLY CARRIES A SCORE LINE -- the guard below. Without it
    # this pattern is a silent catastrophe rather than a feature: EVERY entry ever written carries this
    # heading, including the ones declaring their reach in an impact table or in a 'Tier: N' line. A row
    # produced from one of those would make Read-EntryTierSections return rows for an entry that has no
    # sections, Resolve-EntryImpact would report Shape 'sections', and the table and line readers below it
    # would never run -- so hundreds of entries would read as an unscored tier 0 and every release document
    # built from them would empty out. The score LABEL is what separates the shapes, and it is the label
    # rather than a value: a freshly scaffolded entry has '**Score:**' with nothing after it and is still
    # unmistakably this shape.
    $zeroNames = @(@((Get-EntrySectionHeadings)['What']) + @(Get-EntrySectionRetiredNames -Key 'What') |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $zeroRx = '^\s*' + (Get-EntrySectionLevelRange) + '\s+(?:' +
        ((@($zeroNames) | ForEach-Object { [regex]::Escape([string]$_) }) -join '|') + ')\s*$'
    # --- AND SINCE AUGUST 23, 2026 THE ENTRY'S OWN HEADING IS TIER 0'S SECTION ------------------------
    #
    # The two branch files merged into one development document and the entry became its DEPLOY section, so the
    # question that used to head tier 0 is gone: its text sits directly under '## `<branch>` DEPLOY'. There
    # is exactly one heading at the entry's own level inside one entry -- its own -- which is what makes this
    # pattern safe to add beside the named one rather than in place of it.
    #
    # THE SAME SCORE-LABEL GUARD COVERS IT, and here it is doing even more work than it does above. Every
    # entry ever written opens with a heading at this level, so without the guard every impact-table entry
    # and every 'Tier: N' entry in CHANGELOG.md would produce an unscored tier-0 row, Resolve-EntryImpact
    # would report Shape 'sections', and the readers that CAN read those entries would never run. The label
    # is what separates the shapes -- a freshly scaffolded DEPLOY section has '**Score:**' with nothing after
    # it and is still unmistakably this shape.
    $zeroEntryRx = '^\s*#{' + $script:EntryHeadingLevel + '}\s+\S'
    # A NUMBERED SUB-HEADING ANYWHERE IN THE ENTRY MEANS THE OLD SHAPE, and then the question above is just a
    # question again. This is the discriminator, and it is exact rather than a heuristic: an entry writes its
    # tiers either as numbered sub-headings or as the two named sections, never as a mix. An entry carrying
    # both -- a migration, or one documenting this very change outside a fence -- is read as the numbered
    # shape it IS rather than as the one it describes, which is the same precedence Resolve-EntryImpact
    # already gives the sections over the table.
    $hasNumbered = [bool](@($Lines | Where-Object { $_ -match $headRx }).Count)
    $scoreRx = Get-EntryScorePattern
    $range   = Get-EntrySignificanceRange

    $rows = New-Object System.Collections.Generic.List[pscustomobject]
    $errs = @()
    $seen = @{}

    $i = 0
    while ($i -lt $Lines.Count) {
        $isHigher = $false
        $isZero   = $false
        if ($Lines[$i] -match $headRx) {
            $tierCell = $Matches[1]
        } elseif ((-not $hasNumbered) -and ($Lines[$i] -match $zeroRx -or $Lines[$i] -match $zeroEntryRx)) {
            # The entry's opening section IS tier 0 in the named shape -- its own heading since August 23,
            # 2026, and the retired question before that. Confirmed by the score line below before a row is
            # produced -- see $zeroRx and $zeroEntryRx for what that guard prevents.
            $isZero = $true
            $tierCell = '0'
        } elseif ($Lines[$i] -match $higherRx) {
            $isHigher = $true
            # Resolved from the repo's own audience tier, not from the document. Where none is stated the
            # cell is left unreadable on purpose, so the error path below reports it -- the alternative,
            # guessing a tier, files the change under an audience nobody chose.
            $audience = Get-EntryAudienceTier
            $tierCell = if ($null -ne $audience) { [string]$audience } else { $script:EntryTierHigherHeading }
        } else { $i++; continue }
        $raw = $Lines[$i].Trim()
        # THE BOUNDARY FOLLOWS THE LEVEL THIS SECTION OPENED AT, since August 23, 2026, and a single constant
        # cannot answer it any more because three levels are now in play at once: a tier section written today
        # opens at '###', every one already written opens at '####', and tier 0 opens at the entry's own '##'.
        # A fixed '#{1,4}' would let the next '####' tier close a '###' section early; a fixed '#{1,3}' would
        # stop a '####' tier from closing the '####' tier before it, merging two answers into one. Read from
        # the heading in hand, both are right.
        #
        # FLOORED AT THE ENTRY'S SECTION LEVEL, which is what tier 0 needs: it opens at '##', and a boundary
        # of '#{1,2}' would run its section straight through the '###' heading below it and swallow the
        # audience tier's answer into tier 0's reason.
        $openLevel = ($raw -replace '^\s*(#+).*$', '$1').Length
        $boundary = '^\s*#{1,' + ([Math]::Max($openLevel, $script:EntrySectionLevel)) + '}\s'
        $i++

        # The section runs to the next heading of ANY level -- the next tier, the next '###' section, or the
        # next entry. Anything deeper than this level would be a sub-heading of this section and is kept.
        # TWO LISTS, BECAUSE THE SCORE LINE SPLITS THE SECTION AND ONLY ONE SIDE IS THE REASON. The lines
        # below '**Score:**' were read and discarded until inbound #596: the loop runs to the next heading
        # either way, so the text was already in hand at the point the gate said there was none. Keeping it
        # is what lets the refusal tell "you wrote nothing" apart from "you wrote it one line too low" --
        # the second is the easy mistake, because the scaffold leaves a single blank line on BOTH sides of
        # the score and nothing says which one is read.
        # A REASON THAT TRAILS ON THE SCORE LINE ITSELF goes in the same bucket (issue #1172). The pattern's
        # second group is whatever followed the value; it is text on the wrong side of the score exactly as
        # a line written under it is, so the #596 diagnostic reads it from the same place and gives the same
        # advice -- move it above the line.
        $whyLines = New-Object System.Collections.Generic.List[string]
        $belowScoreLines = New-Object System.Collections.Generic.List[string]
        $scoreCell = $null
        while ($i -lt $Lines.Count) {
            $line = $Lines[$i]
            if ($line -match $boundary) { break }
            if ($null -eq $scoreCell -and $line -match $scoreRx) {
                $scoreCell = $Matches[1]
                if ($Matches[2]) { $belowScoreLines.Add([string]$Matches[2]) }
            }
            elseif ($null -eq $scoreCell) { $whyLines.Add($line) }
            else { $belowScoreLines.Add($line) }
            $i++
        }

        # THE GUARD $zeroRx EXISTS FOR. No score label under the opening question means this entry declares
        # its reach some other way -- an impact table, a 'Tier: N' line, or not at all -- so it is not a
        # tier-0 section, and saying so here is what lets Resolve-EntryImpact fall through to the reader that
        # can read it. Silently, and correctly: nothing was declared here to report on.
        if ($isZero -and $null -eq $scoreCell) { continue }

        if ($tierCell -notmatch '^\d+$') {
            if ($isHigher) {
                # The heading is well-formed and this repo has nothing to resolve it against. Said out loud
                # rather than absorbed, because the absorbed version reads as "no tier above 0" -- a claim
                # about the change, made by a missing setting.
                $numbered = ('#' * (Get-EntryTierSubLevel)) + ' ' + $script:EntryTierSubPrefix + ' N'
                $errs += "significance section '$raw' means this repo's audience tier, and this repo has stated none -- set Get-ReleaseAudienceTier in scripts/repo-config.ps1, or head the section '$numbered' with the tier written out."
            } else {
                $errs += "significance section '$raw' does not name a tier -- write a whole number from 0 to $(Get-EntryTierMax)."
            }
            continue
        }
        $tier = [int]$tierCell
        if ($tier -gt (Get-EntryTierMax)) {
            $errs += "significance section '$raw' names tier $tier, which this model has no meaning for -- the highest is $(Get-EntryTierMax)."
            continue
        }
        if ($seen.ContainsKey($tier)) {
            $errs += "significance section '$raw' declares tier $tier a second time -- one section per tier, or two answers stand for one question."
            continue
        }
        $seen[$tier] = $true

        # THREE STATES, NOT TWO. A tier is scored (a number), declared unreached ('N/A'), or unanswered
        # (nothing) -- and the last two must not collapse into one, because a blank is a question nobody
        # answered while an N/A is a decision somebody made. NotApplicable carries that apart; Score stays 0
        # for both so every existing caller that only reads the number keeps its fail-safe behaviour.
        $score = 0
        $notApplicable = $false
        if ($scoreCell -and $scoreCell -ne $script:EntryImpactEmptyCell) {
            if ($scoreCell -eq $script:EntryScoreNotApplicable) {
                $notApplicable = $true
            } elseif ($scoreCell -notmatch '^\d+$') {
                $errs += "'$($script:EntryScoreLabel) $scoreCell' under tier $tier is neither a number nor '$($script:EntryScoreNotApplicable)' -- write $($range.Min) to $($range.Max), or '$($script:EntryScoreNotApplicable)' with a line saying why the change reaches nobody there."
            } elseif ([int]$scoreCell -lt $range.Min -or [int]$scoreCell -gt $range.Max) {
                $errs += "'$($script:EntryScoreLabel) $scoreCell' under tier $tier is outside the rubric -- write $($range.Min) to $($range.Max)."
            } else {
                $score = [int]$scoreCell
            }
        }

        # What the filtering itself is for, and why it is a shared helper, is written at
        # Get-EntryTierReasonText -- the reasoning moved there with the code, so whoever edits it next
        # reads it rather than finding it at a call site.
        $why = Get-EntryTierReasonText -Lines @($whyLines)

        # WhyBelowScore is diagnosis, never content. Nothing publishes it and nothing counts it as an
        # answer -- the gates read it only to name the actual defect, and the reason still has to move
        # above the score line before the entry passes. Additive, so every existing reader keeps taking
        # the properties it already names; the legacy table path below sets no such property at all,
        # which is why both gates ask whether it is there before reading it.
        $whyBelowScore = Get-EntryTierReasonText -Lines @($belowScoreLines)

        $rows.Add([pscustomobject]@{
            Tier          = $tier
            Score         = $score
            NotApplicable = $notApplicable
            Why           = $why
            WhyBelowScore = $whyBelowScore
            Raw           = $raw
            Error         = $null
        })
    }

    return [pscustomobject]@{ Rows = @($rows.ToArray()); Errors = @($errs) }
}

function Resolve-EntryImpact {
    <#
        Pure: reads an entry's impact declaration. Returns an object with

          Table     $true when an impact table was found outside fenced code.
          Rows      one object per data row -- Tier (int), Score (int, 0 when the cell is empty or '-'),
                    Why (string, '' when empty), Raw (the row as written), Error ($null or the reason).
                    From the section shape only, two more: NotApplicable, and WhyBelowScore -- text found
                    UNDER the score line, which is a misplaced reason rather than an answer. A caller that
                    reads either must ask whether the property is there: the table and 'Tier: N' shapes
                    cannot produce them.
          Tier      the highest tier any row declares -- the entry's reach, and the same number the old
                    'Tier: N' line carried. 0 when nothing usable is declared, so a caller that ignores
                    Error still fails safe towards the harmless end rather than crashing.
          Declared  $true when the reach was actually stated (a table with rows, or a 'Tier:' line).
          Errors    every row-level complaint, ready to print; empty when the table parses.
          Shape     WHICH of the three shapes was read: 'sections', 'table', 'line', or 'none' when the
                    entry declares no impact at all. Table stays $true for the first two, because every
                    existing caller asks it "is there a declaration" rather than "which one".

        WHY THE SHAPE IS RECORDED AND NOT MERELY DETECTED. A gate that reads three shapes has to give
        advice in ONE of them, and until this property existed it could not tell which one it was looking
        at: Get-EntryImpactFindings asked a section-shaped entry to "fill in the third column" of a table
        that this very shape replaced. WhyBelowScore was the nearest thing to a discriminator and does not
        reach far enough -- it lives on a ROW, so the one refusal that fires when a tier has no row at all
        had nothing to read. The property is additive, so nothing that already ignores it changes.

        THREE SHAPES ARE READ, ONE IS WRITTEN. In order: the '#### Tier N' sub-sections (current), the
        impact table (August 5-6, 2026), and the 'Tier: N' line (before that). That is not legacy
        tolerance, it is correctness for the entries that already exist -- CHANGELOG.md holds all three
        right now, every consumer's tree holds at least one, and they reach each new parser through a
        plugin update rather than by choosing to. A parser that knew only the newest shape would read all
        the others as tier 0: silent, correct-looking, and wrong in the direction that empties a release.

        FENCE-AWARE, AND THE FIRST TABLE OUTSIDE A FENCE WINS. An entry documenting this mechanism quotes
        the table inside a fence -- the entry for this very change does, and so does this file -- and a
        parser that cannot tell a quote from a declaration gets disabled by whoever hits it first.

        A ROW'S FAULTS ARE REPORTED, NOT ABSORBED, the same choice Resolve-EntryTier made and for the same
        failure: a '| 2 | 9 | ... |' that silently read back as unscored would sink the entry to the bottom
        of the document it matters most in, with correct-looking output and nothing to notice.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$EntryText)

    $result = [pscustomobject]@{
        Table    = $false
        Rows     = @()
        Tier     = 0
        Declared = $false
        Errors   = @()
        Shape    = 'none'
    }

    $body = Get-EntryTextOutsideFences -EntryText $EntryText
    $lines = @($body -split '\r?\n')

    # SHAPE 1, the current one: '#### Tier N' sub-sections. Tried first, so an entry that carries both --
    # a migration, or an entry documenting the change from one to the other outside a fence -- is read as
    # what it IS rather than as what it describes.
    $sections = Read-EntryTierSections -Lines $lines
    # ERRORS COUNT AS "this entry used the section shape" just as rows do. An entry whose every section is
    # malformed has zero rows, and falling through on that would send it to the legacy reader, which finds
    # nothing and returns an undeclared tier 0 -- the complaints discarded, the defect invisible.
    if (@($sections.Rows).Count -gt 0 -or @($sections.Errors).Count -gt 0) {
        $result.Table = $true
        $result.Shape = 'sections'
        $result.Rows = @($sections.Rows)
        $result.Errors = @($sections.Errors)
        $declared = @($sections.Rows | Where-Object { $null -eq $_.Error })
        if ($declared.Count -gt 0) {
            $result.Declared = $true
            # THE REACH IS THE HIGHEST TIER THAT IS ACTUALLY SCORED (Dave, August 7, 2026). It used to be
            # the highest tier with a SECTION, which was right while tier 1 and 2 were commented out and
            # uncommenting one was the claim. All three sections are always present now, so their presence
            # says nothing -- an 'N/A' row is a tier explicitly declaring it reaches nobody, and counting it
            # would file every entry as tier 2 and publish repo-internal work to consumers.
            #
            # An UNANSWERED row (no score, no N/A) does not count either, and that is the fail-safe
            # direction: forgetting to answer under-promotes, which Get-EntryImpactFindings then reports by
            # name, while the reverse would be silent and would reach people outside this repo.
            $reaching = @($declared | Where-Object { -not $_.NotApplicable -and [int]$_.Score -gt 0 })
            if ($reaching.Count -gt 0) {
                $result.Tier = (@($reaching | ForEach-Object { [int]$_.Tier }) | Measure-Object -Maximum).Maximum
            }
        }
        return $result
    }

    $headerPattern = '^\s*\|\s*' + [regex]::Escape($script:EntryImpactHeaders[0]) + '\s*\|\s*' +
        [regex]::Escape($script:EntryImpactHeaders[1]) + '\s*\|'

    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $headerPattern) { $start = $i; break }
    }

    if ($start -lt 0) {
        # Neither shape: the pre-table one. Read what those entries do carry.
        $legacy = Resolve-EntryTier -EntryText $EntryText
        $result.Tier = $legacy.Tier
        $result.Declared = $legacy.Declared
        # 'line' only where a 'Tier: N' line was actually found -- an entry with no declaration of any kind
        # keeps 'none', so a caller can tell "wrote it the old way" from "wrote nothing".
        if ($legacy.Declared) { $result.Shape = 'line' }
        if ($legacy.Error) { $result.Errors = @($legacy.Error) }
        return $result
    }

    $result.Table = $true
    $result.Shape = 'table'
    $range = Get-EntrySignificanceRange
    $rows = New-Object System.Collections.Generic.List[pscustomobject]
    $errors = @()
    for ($i = $start + 1; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].Trim()
        if ($line -notmatch '^\|') { break }
        # The separator row ('|---|---|---|'), in whatever dashes-and-colons form somebody wrote it.
        if ($line -match '^\|[\s\-:|]+\|?$') { continue }

        $cells = @($line.Trim('|') -split '\|' | ForEach-Object { $_.Trim() })
        $raw = $line
        if ($cells.Count -lt 2) {
            $errors += "impact row '$raw' has fewer than two columns -- write | <tier> | <significance> | <why> |."
            continue
        }
        $tierCell = $cells[0]
        if ($tierCell -notmatch '^\d+$') {
            $errors += "impact row '$raw' does not start with a tier -- write a whole number from 0 to $(Get-EntryTierMax)."
            continue
        }
        $tier = [int]$tierCell
        if ($tier -lt 0 -or $tier -gt (Get-EntryTierMax)) {
            $errors += "impact row '$raw' declares tier $tier, which does not exist -- the tiers are 0 to $(Get-EntryTierMax)."
            continue
        }

        $scoreCell = $cells[1]
        $score = 0
        if ($scoreCell -and $scoreCell -ne $script:EntryImpactEmptyCell) {
            if ($scoreCell -notmatch '^\d+$') {
                $errors += "tier $tier's significance '$scoreCell' is not a score -- write a whole number from $($range.Min) to $($range.Max) against the rubric."
            } elseif ([int]$scoreCell -lt $range.Min -or [int]$scoreCell -gt $range.Max) {
                $errors += "tier $tier's significance $scoreCell is off the scale -- it runs from $($range.Min) to $($range.Max)."
            } else {
                $score = [int]$scoreCell
            }
        }

        $why = if ($cells.Count -ge 3) { $cells[2] } else { '' }
        if ($why -eq $script:EntryImpactEmptyCell) { $why = '' }

        $rows.Add([pscustomobject]@{ Tier = $tier; Score = $score; Why = $why; Raw = $raw })
    }

    $result.Rows = @($rows.ToArray() | Sort-Object -Property @{Expression = 'Tier'; Descending = $true})
    $result.Errors = @($errors)
    if ($result.Rows.Count -gt 0) {
        $result.Declared = $true
        $max = 0
        foreach ($row in $result.Rows) { if ($row.Tier -gt $max) { $max = $row.Tier } }
        $result.Tier = $max
    }
    return $result
}

function Get-EntryImpactScore {
    <#
        The significance a resolved impact declares for one tier -- 0 when that tier has no row, or its
        cell was empty. A helper rather than a caller-side loop because four call sites want it and each
        one written by hand is a chance to reach for a row by position.
    #>
    param(
        [Parameter(Mandatory)]$Impact,
        [Parameter(Mandatory)][int]$Tier
    )
    foreach ($row in @($Impact.Rows)) {
        if ([int]$row.Tier -eq $Tier) { return [int]$row.Score }
    }
    return 0
}

function Get-EntryImpactFindings {
    <#
        Pure: what is wrong with an entry's impact declaration -- an array of strings, each ready to print.
        Empty means the entry has said everything its own reach commits it to.

        ONE FUNCTION FOR BOTH GATES, and that is the whole reason it exists rather than living in one of
        them. open-pr.ps1 needs it while the branch is still the only thing affected, and cut-release.ps1
        needs it because a missing score is Dave's chosen refusal point (August 5, 2026) -- the branch may
        merge without one, the release may not be cut. Two gates, one definition of "wrong", or they drift
        and the earlier one starts passing what the later one refuses.

        THE LADDER IS CHECKED AS A LADDER. An entry claiming tier 2 appears in the consumer document AND in the
        internal note, so it owes a row for tier 1 as well -- and being asked for it is the point rather
        than a chore, because "reaches consumers" without "and here is what colleagues get out of it" is
        half a claim. Every tier from 1 up to the declared reach needs a row, a score and a why.

        TIER 0 OWES NOTHING. It appears only in the record, which is complete and chronological and never
        sorted, so there is no position for a score to decide.

        AN ENTRY WITH NO TABLE AT ALL IS NOT FAULTED FOR THAT, only for what its tier then requires. That
        keeps every pre-table entry in CHANGELOG.md readable rather than retroactively broken -- but it does
        NOT excuse a tier-1 entry from having a score, because the ranking has to be able to place it.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$EntryText)

    $impact = Resolve-EntryImpact -EntryText $EntryText
    $findings = @(@($impact.Errors) | Where-Object { $_ })
    $range = Get-EntrySignificanceRange

    # A TABLE THAT DOES NOT PARSE IS REPORTED AND NOTHING ELSE IS, deliberately. A cell the scale has no
    # meaning for already reads back as unscored, so the completeness checks below would pile a second
    # complaint ("tier 2 has no significance") on top of the first ("tier 2's significance 9 is off the
    # scale") and describe one mistake twice. Measured on the first run of this function: a single bad cell
    # produced three findings. Fix what is unreadable, run again, then hear what is missing.
    if ($findings.Count -gt 0) { return $findings }

    # EVERY REFUSAL BELOW IS WORDED IN THE SHAPE THE ENTRY ACTUALLY USES (inbound: the gate telling a
    # section-shaped entry to "fill in the third column"). Three shapes are read and one is written, so
    # advice given in the wrong one sends an author looking for a table that this format replaced -- and
    # the author is the one person who cannot check the claim, because the file in front of them has no
    # columns to count.
    #
    # THE TEST IS "IS IT A TABLE", NOT "IS IT THE CURRENT SHAPE", and that asymmetry is deliberate. A real
    # table HAS the columns, so its own wording is the accurate one and keeps it -- "recognise both, write
    # one" applies to the advice as much as to the parsing. The 'Tier: N' line and an entry with no
    # declaration at all get the SECTION wording instead of a third variant: neither has anywhere to put a
    # score, so the only move that resolves the refusal is to write the shape this format writes.
    $isTable = ($impact.Shape -eq 'table')

    # THE TIERS AN ENTRY OWES ARE THE ONES THIS REPO ASKS ABOUT (August 12, 2026), and no longer every rung
    # from 1 up to the reach. Where a repo has named its one audience tier, that is the only one owed; where
    # it has named none, Get-EntryAskedTiers returns all of them and this is 1..$impact.Tier exactly as it
    # was. Tier 0 is excluded here for the reason stated above -- it is never ranked -- and its reason is
    # still required, by Get-EntryScaffoldFindings, which walks the rows rather than the ladder.
    #
    # TOLERANT IN THE ONE DIRECTION THAT MATTERS: a tier this repo does not ask about but the author
    # answered anyway is simply not examined here. That is not laxity, it is the only behaviour that does not
    # turn correct work into a blockage -- the 6 entries pending in this repo when the knob landed each
    # carried all three tiers, written under the cumulative model, and a gate that started refusing an EXTRA
    # answered tier would have converted six finished dossiers into six PRs that cannot be opened. Their
    # reasons are still checked; only the completeness ladder narrowed.
    foreach ($tier in @(Get-EntryAskedTiers | Where-Object { $_ -ge 1 -and $_ -le $impact.Tier })) {
        $row = @(@($impact.Rows) | Where-Object { [int]$_.Tier -eq $tier })
        # THE LADDER CANNOT BE SKIPPED, and 'N/A' is the new way to try (August 7, 2026). A tier declaring
        # it reaches nobody, UNDER one that is scored, says a change consumers notice gives this project's
        # colleagues nothing -- which is the half-claim the cumulative ladder exists to rule out. Reported
        # as its own finding rather than as "no significance", because the author did answer: they answered
        # something that cannot be true alongside the tier above it.
        if ($row.Count -gt 0 -and $row[0].NotApplicable) {
            $findings += "tier $tier says '$(Get-EntryScoreNotApplicable)' while tier $($impact.Tier) is scored -- the ladder is cumulative, so a change that reaches tier $($impact.Tier) reaches tier $tier too. Score it, or drop the claim at tier $($impact.Tier)."
            continue
        }
        if ($row.Count -eq 0) {
            # $($impact.Tier), not "$impact.Tier": the second interpolates the OBJECT and then appends the
            # literal '.Tier', so the message read "reaches tier @{Table=True; Rows=System.Object[]...}".
            # Caught by this file's own smoke test; it is the one PowerShell interpolation trap that
            # produces valid output nobody would ever write on purpose.
            $add = if ($isTable) {
                "add a '| $tier | <$($range.Min)-$($range.Max)> | <why> |' row"
            } else {
                "write '$(Get-EntryTierSectionLabel -Tier $tier)' with its reason and a '$($script:EntryScoreLabel) <$($range.Min)-$($range.Max)>' line"
            }
            $findings += "this entry reaches tier $($impact.Tier), so it also reaches tier $tier -- $add. The ladder is cumulative: a change consumers notice is also a change this project's colleagues get something out of."
            continue
        }
        if ([int]$row[0].Score -le 0) {
            $where = if ($isTable) { "in that row's second column" } else { "on that tier's $($script:EntryScoreLabel) line" }
            $findings += "tier $tier has no significance -- write a whole number from $($range.Min) to $($range.Max) against the rubric $where."
            continue
        }
        if (-not $row[0].Why) {
            # THE SAME MISDIAGNOSIS LIVES HERE, and this gate is the one that refuses a RELEASE. #596 was
            # reported against the scaffold gate, but the emptiness is read from the same row, so a reason
            # written below its score reaches the cut with the same unactionable wording -- days later,
            # when whoever wrote it is no longer the one reading the refusal. #1172 added the second
            # placement -- a reason trailing on the score line itself -- to the same bucket.
            $below = if ($row[0].PSObject.Properties['WhyBelowScore']) { [string]$row[0].WhyBelowScore } else { '' }
            if ($below) {
                $findings += "tier $tier scores $($row[0].Score) and its reason sits BELOW the $($script:EntryScoreLabel) line, or trails after the value on it -- either way nothing reads it. Move the text to its own line above the score. Everything up to the score is the reason; everything after it is discarded."
            } else {
                $fill = if ($isTable) { 'fill in the third column' } else { "write it above that tier's $($script:EntryScoreLabel) line" }
                $findings += "tier $tier scores $($row[0].Score) with no 'Why' -- $fill. The rubric says which band; the why says why THIS change is in it, and that is the half a later reader can check."
            }
        }
    }
    return $findings
}

function Remove-EntryImpactTable {
    <#
        Removes the impact table (and the blank line it leaves behind) from an entry block.

        WHERE THIS RUNS, AND WHERE IT DELIBERATELY DOES NOT. The table survives the FOLD whole whenever any
        row carries a score, because the cut EMPTIES the changelog's tier sections -- a score consumed at
        the fold would not exist when the release documents are built days later, and the ordering could not
        be reproduced without re-estimating it. The record therefore keeps the table, and the development
        notes are the last place each ranking's justification survives.

        THE DOCUMENTS THAT TRAVEL OUTWARD STRIP IT: the consumer document, the per-plugin CHANGELOGs and the
        release cards. A self-assigned number printed at a consumer is a marketing claim, and this repo has
        measured what a published guess costs -- the retired remove-before-publishing marker is in release-lib's history
        for exactly that. The number does its work by deciding the order and then gets out of the way.

        The fold also calls it for an UNSCORED table -- a tier-0 entry's scaffold row, which is a question
        nobody was asked rather than content -- so such an entry folds clean.

        Fence-aware, and only the FIRST table is removed, exactly like Remove-EntryTierLine and for the case
        that arrived immediately: the entry documenting this mechanism quotes the table inside a fence, and a
        blind matcher would delete it out of the fence while rendering.

        THE SECTION HEADING GOES WITH THE TABLE, and forgetting that shipped an empty section into every
        outward-facing entry (August 6, 2026). Under the pre-#467 format the declaration was a bare 'Tier: N'
        line with nothing above it, so removing the line was the whole job. The impact table lives under its
        own '### Who is this for' heading, and that heading exists to introduce the table -- the entry format
        is explicit that the table IS the answer rather than prose beside it, so a stripped table leaves a
        question with no answer under it. Measured while cutting v3.6.0 with -NoPush: 17 empty sections in
        each release card, 17 in the per-plugin CHANGELOG and 16 in the consumer draft, in exactly the
        documents that travel to consumers in the plugin cache. The record was correct throughout, which is
        why nothing upstream noticed -- the development notes keep the table, so they keep the heading too.

        THE HEADING ONLY GOES WHEN THE SECTION IS ACTUALLY EMPTY, checked rather than assumed. The convention
        says that section holds the table and nothing else, but a strip that deletes a heading on the
        strength of a convention would delete a reader's prose the first time somebody wrote some. So the
        lines between the heading and the next one must all be blank, and the heading text comes from
        Get-EntrySectionHeadings rather than a literal -- a repo that translates its section headings
        translates this behaviour with them.

        The line endings of everything kept are preserved rather than normalised -- the caller has already
        matched its document's style.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$EntryText)

    $headerPattern = '^\s*\|\s*' + [regex]::Escape($script:EntryImpactHeaders[0]) + '\s*\|\s*' +
        [regex]::Escape($script:EntryImpactHeaders[1]) + '\s*\|'

    # Fence state from the one reader, separators kept -- see Remove-EntryTierLine above for why this is no
    # longer a walk of its own.
    $pair = Get-EntryLineFlagPairs -EntryText $EntryText
    $parts = $pair.Parts
    $out = New-Object System.Collections.Generic.List[string]
    $inTable = $false
    $done = $false
    $any = $false
    $n = -1
    for ($i = 0; $i -lt $parts.Count; $i++) {
        if ($i % 2 -eq 1) { continue }
        $n++
        $line = $parts[$i]
        $sep = if ($i + 1 -lt $parts.Count) { $parts[$i + 1] } else { '' }

        if ($pair.Fenced[$n]) {
            # Entering or inside a fence: a table cannot continue across it, so a quoted block cannot be
            # read as the tail of a real one. Kept for the reason every fenced line is kept.
            $inTable = $false
        } elseif (-not $done) {
            if (-not $inTable -and $line -match $headerPattern) {
                $inTable = $true; $any = $true; continue
            }
            if ($inTable) {
                if ($line.Trim() -match '^\|') { continue }
                # First non-row line ends the table; it is kept, and no later table is touched.
                $inTable = $false
                $done = $true
            }
        }
        $out.Add($line + $sep)
    }
    $t = ($out -join '')
    if (-not $any) { return $t }
    $t = [regex]::Replace($t, '(\r?\n)\1\1+', '$1$1')
    return (Remove-EmptyImpactSection -EntryText $t)
}

function Remove-EmptyImpactSection {
    <#
        Removes the impact table's section heading once the table under it is gone, leaving the blank line
        that separated it from the paragraph above -- so '...text / blank / ### Who is this for / blank /
        ### Type of change' becomes '...text / blank / ### Type of change'.

        Only called by Remove-EntryImpactTable, and only when that function actually removed something. It is
        its own function for the reason the removers above are: the "what counts as this section" question
        has one answer, and a caller that re-derived it could disagree with the writer.

        A SECTION HOLDING ANYTHING BUT BLANK LINES IS LEFT ALONE, including the heading. That is the whole
        safety of this: the strip is entitled to remove what it put there, not to decide that somebody
        else's prose under the same heading was surplus.

        Fence-aware on both halves, for the same reason every reader in this file is: an entry that quotes
        the section heading inside a fence -- the entries documenting this format do -- must not have the
        quoted copy taken out of the fence, and a heading inside a fence must not be read as the boundary
        that ends the section either.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$EntryText)

    # THE CURRENT HEADING AND EVERY RETIRED ONE. The key was 'Who' until the section became 'Significance'
    # hours after this function was written, and an [ordered] lookup on a key that no longer exists returns
    # $null rather than throwing -- so the guard below took the early exit and this function silently did
    # nothing, restoring the empty-section defect it had just been written to fix. Caught by its own tests;
    # it would otherwise have reached a consumer's plugin cache exactly as the original did.
    #
    # The retired names matter for the same reason they matter to the lint: an entry written under the old
    # heading still carries a table, and stripping that table has to take the old heading with it or the
    # hole simply moves to the older entries.
    #
    # THIS SECTION'S RETIRED NAMES, NOT EVERY SECTION'S (August 7, 2026). It read the flattened list, which
    # answers "is this a heading we know" -- a different question from "does this heading open the
    # significance block". While every retired name happened to belong to a section no other document
    # carried, the two questions gave the same answer and the shortcut was invisible. Renaming
    # 'Branch description' to 'Branch title' broke that coincidence: this remover would have accepted an
    # entry's empty TITLE heading as the significance block's and deleted it. Ask the section, not the set.
    $headings = @((Get-EntrySectionHeadings)['Significance']) + @(Get-EntrySectionRetiredNames -Key 'Significance') |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if (@($headings).Count -eq 0) { return $EntryText }
    $headingRx = '^' + (Get-EntrySectionLevelRange) + '\s+(?:' +
        ((@($headings) | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')\s*$'

    $pair = Get-EntryLineFlagPairs -EntryText $EntryText
    $parts = $pair.Parts
    $lineAt = @()
    for ($i = 0; $i -lt $parts.Count; $i += 2) { $lineAt += $i }

    $start = -1
    for ($n = 0; $n -lt $lineAt.Count; $n++) {
        if ((-not $pair.Fenced[$n]) -and $parts[$lineAt[$n]] -match $headingRx) { $start = $n; break }
    }
    if ($start -lt 0) { return $EntryText }

    # Walk to the next heading of any level; anything non-blank on the way means the section has content.
    $end = $lineAt.Count
    for ($n = $start + 1; $n -lt $lineAt.Count; $n++) {
        $line = $parts[$lineAt[$n]]
        if ((-not $pair.Fenced[$n]) -and $line -match '^#{1,6}\s') { $end = $n; break }
        if ($line.Trim() -ne '') { return $EntryText }
    }

    $kept = New-Object System.Collections.Generic.List[string]
    for ($n = 0; $n -lt $lineAt.Count; $n++) {
        if ($n -ge $start -and $n -lt $end) { continue }
        $i = $lineAt[$n]
        $sep = if ($i + 1 -lt $parts.Count) { $parts[$i + 1] } else { '' }
        $kept.Add($parts[$i] + $sep)
    }
    return ($kept -join '')
}

function Remove-EntryTierSections {
    <#
        Removes the '#### Tier N' sub-sections -- heading, why, score and routing question -- from an entry
        block, leaving the '### Significance' heading above them standing.

        THE HEADING GOES TOO WHEN NOTHING IS LEFT UNDER IT, via the same Remove-EmptyImpactSection the
        table remover calls. That behaviour was measured on the shape this one replaces: leaving the heading
        standing shipped a named question with no answer under it into 17 sections per release card, 17 per
        per-plugin CHANGELOG and 16 in the consumer draft, in exactly the documents that travel to a
        consumer. The sub-sections inherit the finding because they inherit the position -- they ARE the
        section's content, so removing them empties it in precisely the same way.

        EVERY section is removed, not just the first -- unlike the table remover, which stops after one. A
        table appeared once by construction; tiers come in threes, and stopping at the first would publish
        the other two at a consumer, which is the exact thing this stripping exists to prevent.

        Fence-aware through the shared reader, for the reason every reader here is: an entry documenting
        this format quotes these headings, and this repo's own README does.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$EntryText)

    # THE RANGE, NOT THE WRITTEN LEVEL (August 23, 2026): the sections this strips were written at '####' for
    # as long as the format has existed, and this repo writes '###' from today. Both have to be removed, or a
    # consumer receives the tiers this function exists to keep out of their document.
    $headRx = '^\s*' + (Get-EntryTierSubLevelRange) + '\s+' + [regex]::Escape($script:EntryTierSubPrefix) + '\s+\S+\s*$'

    $pair = Get-EntryLineFlagPairs -EntryText $EntryText
    $parts = $pair.Parts
    $out = New-Object System.Collections.Generic.List[string]
    $inSection = $false
    # Initialised here rather than only on the first match: a caller may have Set-StrictMode on, and under it
    # an unassigned variable throws instead of reading as $null.
    $dropLevel = $script:EntrySectionLevel
    $any = $false
    $n = -1
    for ($i = 0; $i -lt $parts.Count; $i++) {
        if ($i % 2 -eq 1) { continue }
        $n++
        $line = $parts[$i]
        $sep = if ($i + 1 -lt $parts.Count) { $parts[$i + 1] } else { '' }

        if ($pair.Fenced[$n]) {
            # A fence cannot sit inside a section being dropped without its opening marker having been
            # dropped too, so reaching one means the section ended at a heading we already honoured.
            $inSection = $false
        } else {
            if ($line -match $headRx) {
                $inSection = $true
                $any = $true
                # The boundary follows the level THIS section opened at, for the reason Read-EntryTierSections
                # spells out: a '###' tier and a '####' tier can both appear, and one constant closes one of
                # them in the wrong place.
                $dropLevel = [Math]::Max(($line -replace '^\s*(#+).*$', '$1').Length, $script:EntrySectionLevel)
                continue
            }
            if ($inSection) {
                # Any heading at that level or shallower closes the section -- the next tier, the next
                # '###', or the next entry. It is kept; only the sub-sections themselves go.
                if ($line -match ('^\s*#{1,' + $dropLevel + '}\s')) { $inSection = $false }
                else { continue }
            }
        }
        $out.Add($line + $sep)
    }
    $t = ($out -join '')
    if (-not $any) { return $t }
    $t = [regex]::Replace($t, '(\r?\n)\1\1+', '$1$1')
    return (Remove-EmptyImpactSection -EntryText $t)
}

function Remove-EntrySignificanceDeclaration {
    <#
        Strips whatever shape this entry declared its significance in -- the '#### Tier N' sub-sections, the
        impact table, or both if a migrating entry carries both.

        ONE ENTRY POINT FOR THE OUTWARD-FACING RENDERERS, which is the whole reason it exists. Those
        renderers ask one question -- "take the self-assigned numbers out before a consumer sees them" --
        and they must not have to know which of three shapes this particular entry used. release-lib calls
        this; the two removers underneath it stay separate because each is independently testable and the
        table one is still the only thing that understands a table.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$EntryText)
    return (Remove-EntryImpactTable -EntryText (Remove-EntryTierSections -EntryText $EntryText))
}

# THE SECTIONS THAT ARE ADMINISTRATION RATHER THAN CONTENT, for a reader who has no branch. Four of the
# six: the title (which IS the heading by the time a renderer gets here), the creation timestamp, the
# prefix, and the PR link. 'What' is the substance and 'Significance' has its own remover above -- a
# self-assigned score is a different objection from branch administration, and collapsing the two would
# make one switch answer two questions.
$script:EntryAdminSectionKeys = @('Description', 'Id', 'Type', 'PullRequest')

function Get-EntryAdminSectionKeys {
    <# The section keys a document written for someone outside this repo drops. Stated once so the remover
       and its suite cannot disagree about which four, and so adding a seventh section forces a decision
       here rather than silently defaulting to "publish it". #>
    return @($script:EntryAdminSectionKeys)
}

function Remove-EntryAdminSections {
    <#
        Removes the branch-administration sections -- heading and body -- from an entry block, leaving the
        substance and the entry's own heading standing.

        WHY THIS EXISTS AT ALL, because the stripping it completes was never absent: it was aimed one level
        up. Convert-EntryHeadingToTitle drops the PR number, the type and the date from an entry's HEADING,
        which is where all three lived until August 6, 2026. The branch dossier then moved that metadata into
        named '###' sections, and nothing followed it down. So the heading rewrite kept working perfectly and
        the same facts arrived one line lower: measured on the v4.2.0 consumer draft, 133 of 396 lines -- 34%
        -- were these four sections, with 'Branch title' printed directly beneath the heading it had just
        become. Duplicated, in the one document written for someone who is paying for the product.

        The intent was never in doubt, which is what makes this a defect rather than a change of mind:
        Convert-EntryHeadingToTitle's own header says this document's reader "has no PR numbers", and the
        draft shipped seven.

        RETIRED NAMES ARE REMOVED TOO, and here that matters more than it does for a reader. A reader that
        misses an old name returns nothing and the caller usually notices; a REMOVER that misses one leaves
        the section standing in the document that travels outward -- silent, and in front of the wrong
        audience. CHANGELOG.md and every consumer's tree are full of 'Type of change' and
        'Branch description' right now. Recognise both, write one.

        Fence-aware through the shared reader, and this function needs it more than most: the entry that
        introduces it quotes these very headings inside a fence to show what is dropped. Same inherited
        assumption as Remove-EntryTierSections about a fence INSIDE a dropped section -- none of these four
        sections holds one by construction (a title, a timestamp, one word, a link).
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$EntryText)

    $headings = Get-EntrySectionHeadings
    $names = @()
    foreach ($key in (Get-EntryAdminSectionKeys)) {
        $names += @($headings[$key]) + @(Get-EntrySectionRetiredNames -Key $key)
    }
    $names = @($names | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() })
    if ($names.Count -eq 0) { return $EntryText }

    # THE RANGE, NOT THE WRITTEN LEVEL, and this function is the one that paid for the difference. The four
    # admin sections it strips exist almost exclusively in LEGACY entries -- that is what makes them admin --
    # so a pattern pinned to the level entries are written at today matches the shape that needs stripping
    # least. Pinned exactly, it went blind the moment the section level shifted on August 26, 2026, which is
    # the same defect its own header describes from the other direction: a stripper aimed one level away from
    # the sections it is meant to remove, and 125 of 396 lines of a consumer's release draft made of the four
    # sections nobody stripped.
    $headRx = '^\s*' + (Get-EntrySectionLevelRange) + '\s+(' +
        ((@($names | ForEach-Object { [regex]::Escape($_) })) -join '|') + ')' +
        (Get-EntrySectionHeadingTail)
    # Any heading at the section level or shallower closes the section: the next sibling, or the next entry.
    $closeRx = '^\s*#{1,' + $script:EntrySectionLevel + '}\s'

    $pair = Get-EntryLineFlagPairs -EntryText $EntryText
    $parts = $pair.Parts
    $out = New-Object System.Collections.Generic.List[string]
    $inSection = $false
    $any = $false
    $n = -1
    for ($i = 0; $i -lt $parts.Count; $i++) {
        if ($i % 2 -eq 1) { continue }
        $n++
        $line = $parts[$i]
        $sep = if ($i + 1 -lt $parts.Count) { $parts[$i + 1] } else { '' }

        if ($pair.Fenced[$n]) {
            $inSection = $false
        } else {
            if ($line -match $headRx) { $inSection = $true; $any = $true; continue }
            if ($inSection) {
                if ($line -match $closeRx) { $inSection = $false }
                else { continue }
            }
        }
        $out.Add($line + $sep)
    }
    $t = ($out -join '')
    if (-not $any) { return $t }
    return [regex]::Replace($t, '(\r?\n)\1\1+', '$1$1')
}

function Get-EntryInsertOffset {
    <#
        Pure: where in CHANGELOG.md's list a newly folded entry belongs -- a character offset into
        $SectionText, always at an entry boundary ('## ' at line start) or at its very end.

        NEWEST FIRST, FULL STOP (Dave, August 16, 2026), AND SINCE SEPTEMBER 3, 2026 THAT IS MEASURED
        RATHER THAN ASSUMED (issue #1280). The rule is unchanged -- the list is a chronological record and
        reads like one -- but the answer used to be the literal TOP for every input, on the premise that
        "the entry being folded is the most recently merged one". A LATE fold is exactly what breaks that
        premise, and a late fold is not exotic: the fold is a direct push to the trunk under one of this
        repo's named exceptions, so a push it cannot make leaves the entry held while later branches merge
        and fold ahead of it. Both halves of the premise came from different sources and nothing compared
        them -- the POSITION was assumed here, while the STAMP on the entry's own heading is read off the
        PR's mergedAt by Format-EntryMergeStamp -- so a held fold wrote a stamp that contradicted the place
        it wrote it in. Measured in this repo's own CHANGELOG.md, where '20260903-102422' sat above
        '20260903-103107' because #1274 merged after #1271 and folded first -- twice over, in fact: an
        older pair had gone unnoticed. Both were repaired on the branch that made this change.

        SO THE POSITION IS NOW DERIVED FROM THAT SAME STAMP: the first entry in the list whose own stamp is
        OLDER than $Stamp. The list stays newest-first, and for the ordinary fold-seconds-after-the-merge
        case the answer is still the top -- it is simply the answer rather than the assumption. Passing no
        $Stamp restores the old behaviour exactly, which is what a fold with no PR to read a moment off
        gets: there is nothing to place by, so it leads.

        WHY IT IS NOT COSMETIC. The changelog is the cut's input. Build-ReleaseNotes and Build-ReleaseNoteDraft
        re-rank from the scores and inherit nothing, so the ranked documents were never affected -- but the
        development notes' TIER 0 section inherits document order deliberately ("complete and
        chronological, which is what a record is for", the comment #467 was written to make true). A late
        fold put a wrong order into precisely the section that had been fixed to be chronological.

        AN ENTRY WHOSE HEADING CARRIES NO READABLE STAMP STOPS THE WALK, which is the safe direction rather
        than a gap. Such an entry is either legacy -- the fold has stamped every heading since August 19,
        2026, so anything without one is older than anything with one -- or it was folded with no PR to
        read a moment off, in which case there is nothing to compare and the pre-#1280 answer was the top
        anyway. Stopping there is the HIGHEST position consistent with what can actually be read, so an
        unreadable stamp degrades to "the top of what I can order" rather than sinking a new entry past a
        boundary it could not compare against. Note which claim that is and which it is not: the walk
        deliberately places an entry lower than the old always-top answer -- that is the fix -- and what it
        will not do is go one step further down on a comparison it never made.

        EQUAL STAMPS KEEP THE ENTRY THAT WAS FOLDED FIRST ON TOP: the walk stops on strictly older, so a tie
        continues past. Two changes landing in the same second have no chronological order to get right, and
        this makes the choice stable rather than arbitrary.

        IT RANKED ON (TIER, SIGNIFICANCE) UNTIL AUGUST 16, 2026, and the reason that went is worth keeping, because
        the ranking looked load-bearing and was not. The argument for it was that the cut EMPTIES this list,
        so document order at cut time IS the order the release documents inherit -- which turned out to be
        true of exactly one section. Build-ReleaseNotes passes -RankByTier for every tier from 1 up and
        Build-ReleaseNoteDraft ranks at the repo's own audience tier, so both re-rank from the scores and inherit
        nothing. The one place that does inherit is the development notes' TIER 0 section, whose own comment
        asks for "complete and chronological, which is what a record is for" -- and which was getting
        score-descending order instead. So this change makes that comment true rather than breaking it.
        The significance scores are untouched and still decide the release documents' order and the version
        bump; they simply stopped deciding this one.

        INSERT-ONLY, NEVER A RE-SORT, and that is unchanged and still a safety property rather than an
        optimisation -- including under #1280, which is why that change derives a POSITION and does not
        sort. This function serves a commit that lands DIRECTLY ON THE MAIN BRANCH under one of this
        repo's named exceptions. A re-sort would have the fold rewrite the position of entries it did
        not write, so a bug could scramble the list; an insert can only ever misplace the one entry being
        folded, which is visible in the diff and one edit to repair. So the stamps of the entries already in
        the list are READ and never rewritten: the walk below moves nothing, and an out-of-order pair a
        pre-#1280 fold already left behind stays exactly where it is until somebody repairs it on a branch.

        $Score and $Tier are still accepted and deliberately ignored. The fold computes both for the console
        line and for the bump, and dropping them from this signature would only move that call's edit into
        a script that lands on the trunk -- see the parameter block for the fuller reason.

        $EntryPattern is the heading shape an entry starts with -- '(?m)^## ' for the current format. It is a
        parameter rather than a constant because a document mid-migration still holds pre-format '### '
        entries, and the caller knows which it is looking at.

        $Stamp is the moment the entry being folded LANDED, in Format-EntryMergeStamp's shape. Optional, and
        omitting it is a supported answer rather than a caller's oversight -- see above.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$SectionText,
        # ACCEPTED AND IGNORED SINCE AUGUST 16, 2026. Kept rather than removed because every caller in every
        # consumer's plugin cache passes them today, and they arrive at the new lib through a plugin update
        # rather than by choosing to -- a removed parameter would make the fold throw on the trunk, straight
        # after a merge, which is the worst place this repo has to fail. Same "recognise both" reasoning the
        # retired section headings get, applied to a signature.
        [int]$Score = 0,
        [int]$Tier = 0,
        # DEFAULTED TO EMPTY AND RESOLVED IN THE BODY, because a parameter default cannot call a function in
        # this scope and a LITERAL default is how this went wrong (August 26, 2026). It read '(?m)^## ' -- the
        # entry level of the day it was written -- so when the level shifted, every caller relying on the
        # default saw a document with no entries in it. The fold then ranked a new entry against an empty
        # list and appended it, which reverses the ranked order without erroring: three entries folded
        # low-then-high came out exactly backwards, and the only thing that noticed was this suite.
        [string]$EntryPattern = '',
        # OPTIONAL, AND ITS ABSENCE IS THE PRE-#1280 BEHAVIOUR RATHER THAN AN ERROR (September 3, 2026).
        # Same reasoning as $Score and $Tier above, in the other direction: this lib reaches every consumer
        # through a plugin update, and a fold script one release behind calls this function without the
        # parameter. That call has to keep working -- it runs on the trunk, straight after a merge -- so a
        # missing stamp means "place it at the top", which is exactly what that older fold expected.
        [string]$Stamp = ''
    )
    # The default, resolved where a function call is legal. An explicit pattern from a caller still wins --
    # a document mid-migration is read by passing its own level in.
    if ([string]::IsNullOrEmpty($EntryPattern)) {
        $EntryPattern = '(?m)^' + ('#' * (Get-EntryHeadingLevel)) + ' '
    }

    # FENCE-AWARE, LIKE EVERY OTHER READER OF THIS FORMAT -- and this function was the one that was not.
    # Measured on the fold of PR #477, in the document PR #476 had just created: that entry quotes
    # '## #475 <midDot> ...' inside a ```text fence, as the worked example of the format it introduces. A
    # plain regex over the text reads that quoted heading as an entry boundary, which does two things and
    # neither errors:
    #
    #   * it SPLITS the real entry in two. The fragment above the fence holds no impact table -- the table
    #     sits further down, under '### Who is this for' -- so it reads as tier 0, score 0;
    #   * the loop below then meets that tier-0 fragment FIRST, and any entry of tier 1 or higher is
    #     inserted above it: at the very top of the document. Which is what happened -- a tier-1 entry led
    #     a list whose next six entries were tier 2.
    #
    # Well-formed markdown either way, and the console line even reported it ("placed above 8 existing
    # entries" in a document that had 7). The fourth-plus instance of one defect class in this file's
    # history: a matcher satisfied by a MENTION rather than a use. Split-EntryBlocks in release-lib.ps1
    # already handled it; this ranker did not, because it was written when entries could not contain
    # headings of their own.
    #
    # Done by LINE rather than by character offset, because Get-FencedLineFlags answers per line and the
    # offsets have to be rebuilt from the same split to stay in step with it. The newline width is added
    # back per line from the original text, so a CRLF document is not silently shifted by one byte per
    # line -- the root CHANGELOG is CRLF here.
    $rxLine = [regex]($EntryPattern -replace '^\(\?m\)', '')
    $srcLines = @($SectionText -split "`r?`n")
    $fenced = Get-FencedLineFlags -Lines $srcLines
    $entryStarts = @()
    # The heading LINE beside its offset, because #1280 needs what the heading SAYS and not only where it
    # is. Collected in the same pass and from the same fence walk, so the two arrays cannot disagree about
    # which boundaries are real -- a second walk is how a fence-blind reader gets re-introduced.
    $entryHeadings = @()
    $offset = 0
    for ($i = 0; $i -lt $srcLines.Count; $i++) {
        if ((-not $fenced[$i]) -and $rxLine.IsMatch($srcLines[$i])) {
            $entryStarts += $offset
            $entryHeadings += $srcLines[$i]
        }
        $offset += $srcLines[$i].Length
        # The separator this line ended with, taken from the source rather than assumed.
        if ($offset -lt $SectionText.Length) {
            if ($SectionText.Substring($offset, 1) -eq "`r") { $offset += 2 } else { $offset += 1 }
        }
    }
    # An empty list appends at the end, which for an empty string is the same position as the top -- stated
    # as its own case anyway, because a list with a head note and no entries yet is not empty text.
    if ($entryStarts.Count -eq 0) { return $SectionText.Length }

    # THE ENTRY'S OWN STAMP, ROUND-TRIPPED THROUGH THE FORMATTER rather than shape-tested a second time
    # here. Format-EntrySectionHeadingSuffix builds exactly what a stamped heading ends with and
    # Get-EntryHeadingStamp reads exactly that back, so this one line validates $Stamp, rejects the
    # template's placeholder, and proves the writer and the reader agree -- with no copy of the pattern in
    # this function to go stale. Empty in, empty out, which is the no-stamp case below.
    $mine = Get-EntryHeadingStamp -HeadingLine (Format-EntrySectionHeadingSuffix -Stamp $Stamp)

    # NOTHING TO PLACE BY -> THE FIRST ENTRY BOUNDARY, which is what "newest first" meant as an offset for
    # every input between August 16, 2026 and #1280, and still means for a fold with no PR to read a moment
    # off. The fence walk above is what makes it correct rather than trivially `IndexOf('## ')`: an entry
    # may QUOTE a heading inside a fence -- the entry introducing this very format does -- and inserting at
    # a quoted heading would split somebody else's fenced block in two. Measured on the fold of PR #477,
    # back when this function ranked.
    if (-not $mine) { return $entryStarts[0] }

    # WHERE IT LANDED, AGAINST WHERE THE OTHERS LANDED (#1280). The first entry that is strictly OLDER is
    # the one this entry goes above; equal stamps continue, so a tie leaves the entry folded first on top.
    # CompareOrdinal rather than -lt because these are fixed-width big-endian stamps and the comparison has
    # to be by code point -- PowerShell's -lt on strings is CULTURE-aware, which is a different question
    # asked of the same two values.
    for ($k = 0; $k -lt $entryStarts.Count; $k++) {
        $theirs = Get-EntryHeadingStamp -HeadingLine $entryHeadings[$k]
        # No readable stamp stops the walk, and the docstring carries why that is the safe direction: it can
        # only ever place this entry HIGHER than the pre-#1280 answer would have, never lower.
        if (-not $theirs) { return $entryStarts[$k] }
        if ([string]::CompareOrdinal($theirs, $mine) -lt 0) { return $entryStarts[$k] }
    }
    # Older than everything already in the list -- the oldest held fold there is. The slice's end, which the
    # caller's tail normalisation has guaranteed sits after a line break; see the fold's note on why that
    # guarantee is load-bearing exactly here.
    return $SectionText.Length
}
# --- The entry's own shape: one H3 per change, with named sections ---------------------------------
#
# ONE HEADING PER CHANGE, AND THE DOCUMENT HAS NO OTHERS (Dave, August 5, 2026). CHANGELOG.md used to open
# with '## Latest Release' and three '## Tier N - Pull Requests' sections, with each change an '### ' inside
# one of them. All four are gone. A change IS the '## ' heading now -- '## #475 <midDot> A significance score
# per entry' -- and inside it three named '### ' sections answer the three questions a reader actually
# arrives with:
#
#   ### What does this change do?    the description, which used to be a bare paragraph under the heading
#   ### Who is this for              the impact table -- the tiers this change reaches, each with a score
#   ### Type of change               Feat / Fix / Docs / Chore, which used to be a middot field in the heading
#
# WHY THE TYPE MOVED OUT OF THE HEADING. It was the second-to-last middot field, then (when the merge date
# left) a field matched by content against the known branch types. Both were parses of a heading that was
# doing three jobs at once. As its own section it is stated rather than inferred, and the heading is reduced
# to what a reader scans: the PR number and the title.
#
# 'Significance', AND IT IS SUB-SECTIONS RATHER THAN A TABLE (Dave, August 6, 2026). It was
# 'Who is this for' holding an impact table, one row per tier. The table went because it forced a shape onto
# something that is not always rectangular: NOT EVERY CHANGE HAS A TIER 1 OR A TIER 2, and a table makes the
# absence of a row look like an omission rather than an answer. As '#### Tier N' sub-sections, a change that
# reaches nobody outside this repo simply has one section -- which is a complete statement, not a gap.
#
# The heading also stopped naming an audience, because the section no longer answers "who": each sub-section
# names its own audience by its number, and what the section as a whole carries is how much the change WEIGHS
# for each of them.
#
# THE HEADINGS ARE REPO-OWNED, unlike the impact table's column keys. That split follows the one this file
# already makes: a machine-read KEY stays fixed ('Tier', 'Significance', 'Plugins:'), while text a reader
# SEES belongs to the repo that owns the document -- the same #410 reasoning that made the entry stubs and
# the category labels configurable. These are read back by the parser, so a repo that translates them
# translates both halves at once, which is why they come from one resolver rather than being written twice.
# THE ENTRY IS THE BRANCH'S OWN DOSSIER, AND IT FOLDS INTO CHANGELOG.md AS IT STANDS (Dave, August 6,
# 2026). The file used to be the changelog block and nothing else: its H2 was the change's title, and three
# sections answered what it does, what it weighs and what type it is. It now opens with the BRANCH -- '##
# `feat/x` changelog' -- and carries the branch's own identity above the description, because the two files
# a branch works in are a matched pair and both say whose they are.
#
# THE SIX SECTIONS, IN THE ORDER THEY ARE WRITTEN:
#
#   Branch title         the human-readable name of the change -- what the heading used to carry
#   Branch ID            a unique stamp, written by the scaffolder at creation
#   Branch type          feat / fix / docs / chore, from the branch prefix
#   What does the ...    the description a reader of CHANGELOG.md arrives for
#   Significance         one '#### Tier N' sub-section per reach the change claims
#   Pull Request         filled by the fold, from the merge itself
#
# DAVE CHOSE THE VERBATIM ROUTE over having the fold derive a slimmer block from this one (August 6, 2026,
# asked and answered before any of it was built). So CHANGELOG.md receives exactly this shape, branch line
# and all, and the release documents inherit it. The alternative -- a fold that reads the dossier and emits
# a different document -- was declined: it would put a SECOND definition of the entry format inside the
# fold, which is the drift shape this repo has paid for in the fence readers, the scaffold wording and the
# tier sections. One shape, written once, read everywhere.
#
# THE ORDER IS LOAD-BEARING, not presentation. The lint's split-entry rule asks whether a block's FIRST
# named section is the first of these, which is how a stray heading at the entry's own level is caught --
# so a reordering here changes what that gate means. Get-EntryFirstSectionKey states it once.
# AND IT IS 'Branch title', NOT 'Branch description', SINCE AUGUST 7, 2026 (Dave, #506). The field is what
# the change is CALLED -- in this file, in CHANGELOG.md, in the release documents, and since the same day in
# the PR title, which open-pr.ps1 now composes from it rather than taking on the command line. "Description"
# undersold that, and it read as a synonym of the 'What does the change...' section two rows below it, which
# genuinely is the description. The KEY stays 'Description': it is machine-read, every caller names it, and
# renaming a key to match a heading is how a rename stops being cosmetic.
$script:EntrySectionDefaults = [ordered]@{
    Description  = 'Branch title'
    Id           = 'Branch ID'
    Type         = 'Branch type'
    What         = 'What does the change on this branch deploy to main?'
    Significance = 'Significance'
    PullRequest  = 'Pull Request'
}

# --- THE TIERS STOP NAMING THEMSELVES (Dave, August 19, 2026) -------------------------------------
#
# The entry used to carry the tiers as '#### Tier 0' and '#### Higher than tier 0?' underneath the question.
# Two things changed and the LEVELS DID NOT: tier 0 lost its heading altogether -- the question above IS its
# section now -- and the audience tier's sub-heading asks what is being asked of the author instead. So an
# entry is still two '###' sections, and no heading names a tier number. The wording of that sub-heading is
# NOT quoted here on purpose: it has been retexted repeatedly since this block was written, and this block is
# about the shape rather than the words. Get-EntryTierHigherHeading holds the live one.
#
# WHY THE NUMBER LEAVES THE DOCUMENT. A tier is a fact about the READER, and the author filling this in is
# not thinking about a tier -- they are answering whether anybody outside this repo would notice. The number
# is what the parser needs, and it resolves to one: tier 0 is the question every change answers, and the
# sub-heading under it means whichever single audience tier the repo has stated. That is the same resolution
# 'Higher than tier 0?' already did since August 16, 2026; what changes is that the heading stops naming the
# mechanism and starts naming the thing being asked.
#
# 'Significance' STAYS RETIRED, and this is worth saying because the shape invites the opposite reading. The
# audience tier's heading is a '####' SUB-heading inside the question's section, not a named section of the
# entry -- so it is Get-EntryTierHigherHeading's business, one screen down, and this map keeps answering only
# for the sections an entry actually has. It was briefly modelled as a revived 'Significance' section, at
# '###', which is the shape Dave looked at and asked to nest instead.
#
# WRITTEN ONLY WHERE THE REPO HAS STATED AN AUDIENCE TIER -- Test-EntryTierSectionsAreNamed, the same guard
# and the same conservative direction the audience heading already carried: a consumer who has answered
# nothing gets the numbered sub-sections exactly as it did yesterday, because a heading with no tier to
# resolve to would read as tier 0 and empty their release.

# RECOGNISED, NEVER WRITTEN -- the section headings this format has retired. Measured the moment
# 'Who is this for' became 'Significance': all 24 entries pending in CHANGELOG.md carry the old name, and
# the lint's section check reported every one of them as a MISSPELLED heading, which is its most alarming
# finding ("costs that entry its declaration silently"). Twenty-four false accusations is how a check gets
# switched off. Every consumer's changelog and every branch in flight is in the same position, and they
# reach the renamed heading through a plugin update rather than by choosing to.
#
# Deliberately not repo-configurable: these are historical strings, so there is nothing to choose about
# them, and a repo that translated the heading translated the CURRENT one -- their old name lives in their
# own documents, which is why a name-matcher accepts the seam's value AND these.
# KEYED BY SECTION, NOT A FLAT LIST, since the branch dossier renamed two more of them (August 6, 2026).
# A flat list answers "is this heading one we know", which is all the lint needs; a READER needs to know
# WHICH section an old name is the old name OF, or Get-EntrySectionBody -Key 'Type' finds nothing in the
# hundreds of entries that say 'Type of change'. Both questions are answered from this one map, so a name
# retired for one reader cannot be forgotten by the other.
# NEWEST RETIRED NAME FIRST, so a reader scanning this map meets the name it is most likely to find. 'What
# does the change on this branch bring to main?' was written from August 6 to August 19, 2026 -- which is
# every entry pending in CHANGELOG.md and every branch in flight, here and in every consumer.
$script:EntryRetiredSectionNames = [ordered]@{
    Description  = @('Branch description')
    What         = @('What does the change on this branch bring to main?', 'What does this change do?')
    Significance = @('Who is this for')
    Type         = @('Type of change')
}

function Get-EntrySectionRetiredNames {
    <# The retired headings of ONE section, oldest names included -- @() where that section never had one. #>
    param([Parameter(Mandatory)][string]$Key)
    if ($script:EntryRetiredSectionNames.Contains($Key)) { return @($script:EntryRetiredSectionNames[$Key]) }
    return @()
}

function Get-EntryRetiredSectionHeadings {
    <# Section headings that were once written and are still recognised, flattened across every section. A
       name-matcher accepts these alongside Get-EntrySectionHeadings' values; a WRITER must never use them. #>
    $out = @()
    foreach ($key in $script:EntryRetiredSectionNames.Keys) { $out += @($script:EntryRetiredSectionNames[$key]) }
    return @($out)
}

# --- WRITTEN VERSUS RECOGNISED (Dave, August 16, 2026) --------------------------------------------
#
# THE MAP ABOVE IS NOW THE RECOGNISED SET, AND THIS IS THE WRITTEN ONE. Four of those six sections are no
# longer scaffolded: 'Branch title' moved into the 'Pull Request' section (it was never a branch title --
# open-pr composes the PR title from it, which is what it has always been), 'Branch ID' became the
# timestamp in the entry's own heading, 'Branch type' is the prefix of the branch that heading already
# names, and 'Significance' dissolved into 'What does the change...' -- the tier reasons ARE the answer to
# that question, so a separate heading over them asked it twice.
#
# NOTHING IS DELETED FROM THE RECOGNISED SET, and that is the whole safety of this change. CHANGELOG.md,
# every release document, every consumer's tree and every branch in flight carry all six headings right
# now, and they meet these scripts through a plugin update rather than by choosing to. A reader that
# forgot 'Branch title' would publish nameless entries; one that forgot 'Branch type' would file the lot
# under a catch-all. Recognise both, write one -- the same rule this file already gives the 'Tier: N' line
# and the retired heading names.
#
# SO THE COUNT MOVED AND THE LOOKUP DID NOT. Get-EntrySectionHeadings still answers "which heading does
# key X have", for every key that ever existed; this answers "which ones does the scaffolder emit", which
# is what the writer walks and what the lint's entry-shape check holds a document's stated count to.
#
# STILL TWO AFTER AUGUST 19, 2026, and that is worth a line because that change moved both tier headings. It
# moved them WITHIN the question's section -- tier 0's heading went away, the audience tier's was renamed --
# so what a reader meets at '###' is unchanged: the question, and the PR.
$script:EntryWrittenSectionKeys = @('What', 'PullRequest')

# --- RETIRED, SEPTEMBER 3, 2026 (#1335): $script:EntryIdTemplatePlaceholder --------------------------
#
# It was what the reference copy of the development document showed where a real one carries its CREATION
# stamp -- '<timestamp of the moment this branch was created>'. The document's heading is the branch name
# and nothing else now, so there is no stamp on it in either state and nothing for a placeholder to stand
# in for. Removed rather than left defined and unread, which is this file's own rule.
#
# THE MERGE STAMP IS UNTOUCHED, and the pair the comment below describes is now a single: the entry's
# 'Pull Request' heading still carries the moment it landed, which is the stamp the changelog's own
# ordering reads (Get-EntryHeadingStamp).

# Its counterpart at the other end of the branch's life (Dave, August 19, 2026): what the template
# shows beside 'Pull Request', where a folded entry carries the moment it landed. The pair is the point --
# the cycle file's heading stamps the branch's first moment, this section's heading its last -- and each
# stamp sits in the document that owns that moment.
$script:EntryMergeStampTemplatePlaceholder = '<timestamp of the moment this branch was merged>'

# What stands between the entry's title and its creation stamp: '## Branch `feat/x` changelog <sep> 20260819...'.
# A MIDDLE DOT SINCE AUGUST 19, 2026 (Dave), where it was a hyphen. The hyphen read as a range or a
# continuation -- this document's own prose uses ' -- ' as a dash all over -- while the two halves are simply
# two facts about the same branch, which is the separator's whole job.
#
# NOT MACHINE-READ, WHICH IS WHY IT CAN CHANGE AT ALL. Nothing parses the stamp back out of the heading:
# Get-BranchFileDeclaredBranch reads the backticked branch name and stops, and Test-IsChangelogEntryFile
# keys on the level and the title word. So no entry already written becomes unreadable, which is not
# something the section headings beside it could claim.
#
# WRITTEN AS A CODE POINT, NOT AS THE CHARACTER, and that is a measured defect rather than fastidiousness.
# Typed literally it produced a two-character mis-decode in every generated document on the first run: Windows PowerShell 5.1 reads
# a .ps1 with no BOM as the system ANSI code page, so the two UTF-8 bytes of U+00B7 come back as two CP1252
# characters. The alternatives were a BOM on a file that two trees hold byte-identical, or this -- and this
# keeps the whole lib ASCII, which is the property that makes the encoding question not arise at all.
# It is also the exact damage scripts/maintenance/fix-mojibake.ps1 hunts, and Get-MojibakePaths already
# covers both this repo's entry files and branch/templates/ -- so the wrong version would have been caught
# downstream too, one gate later and after it had been copied into somebody's entry.
$script:EntryIdSeparator = [string][char]0x00B7

function Get-EntrySectionHeadingTail {
    <#
        Pure: the regex tail every section-heading matcher ends with -- what may legitimately follow a
        section's NAME on its own heading line. Nothing, or the separator and a stamp.

        WHY THIS EXISTS AT ALL (August 19, 2026). Until the 'Pull Request' heading gained the merge stamp,
        every one of these matchers ended in a bare '\s*$' and the name had to be the whole line. Six
        readers spread across this lib and the lint would each have had to grow the same exception, and the
        failure mode of missing one is silent: a section whose heading no longer matches is a section the
        reader reports as ABSENT, which the gates read as "not answered yet" and the fold as nothing to
        fill. So the exception is written once and imported six times.

        THE STAMP IS NOT CAPTURED, because nothing reads it back -- exactly what the separator's own note
        says about the entry heading. This tail is a tolerance, not a parser.
    #>
    return '(?:\s+' + [regex]::Escape($script:EntryIdSeparator) + '\s+\S.*?)?\s*$'
}

function Format-EntrySectionHeadingSuffix {
    <#
        Pure: what a stamp looks like appended to a section heading -- ' <sep> <stamp>', or '' for an empty
        stamp. One formatter, so the writer, the fold's restamp and the tail pattern above cannot disagree
        about the spacing.
    #>
    param([AllowEmptyString()][string]$Stamp = '')
    if (-not $Stamp) { return '' }
    return ' ' + $script:EntryIdSeparator + ' ' + $Stamp
}

function Get-EntryHeadingStamp {
    <#
        Pure: the stamp a heading line carries -- '20260903-103107' -- or '' when it carries none. The
        inverse of Format-EntrySectionHeadingSuffix, and placed beside it so the writer and the reader
        cannot drift apart about the spacing or the separator.

        STRICT ABOUT THE SHAPE, WHERE THE TAIL PATTERN IS DELIBERATELY LOOSE, and the difference is the
        reason this function exists rather than a capture group being added to Get-EntrySectionHeadingTail.
        That tail is a TOLERANCE -- '(?:\s<sep>\s\S.*?)?\s*$', anything non-blank -- and its own docstring
        says why: nothing read the stamp back, so a heading was allowed to say whatever it said. Something
        reads it back now, so this accepts only what Format-EntryMergeStamp writes. Anything else answers
        '' rather than being compared as if it were a moment, which is what keeps the template's own
        placeholder ('<timestamp of the moment this branch was merged>') out of an ordering decision: a
        placeholder that sorted as a date would be a silent wrong answer in the one document whose subject
        is when things landed.

        AND THE SHAPE IS WHY THE CALLER NEEDS NO [datetime]. 'yyyyMMdd-HHmmss' is fixed-width and
        big-endian, so an ORDINAL string comparison of two of these IS the chronological one. No parse
        means no unparseable-date path to handle -- the shape test above is the whole validation, and it
        happens once, here.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$HeadingLine)
    $m = [regex]::Match($HeadingLine, '\s' + [regex]::Escape($script:EntryIdSeparator) + '\s+(\d{8}-\d{6})\s*$')
    if ($m.Success) { return $m.Groups[1].Value }
    return ''
}

function Get-EntryIdSeparator {
    <# The separator between the entry's title and its creation stamp -- U+00B7 MIDDLE DOT. #>
    return $script:EntryIdSeparator
}

# --- RETIRED, SEPTEMBER 3, 2026 (#1335): Get-EntryIdTemplatePlaceholder ------------------------------
#
# The getter for the creation-stamp placeholder retired above. Its only caller was Format-Development's
# trunk state, and that heading carries no stamp any more.

function Get-EntryMergeStampTemplatePlaceholder {
    <# The same, for the 'Pull Request' heading: what the template shows where a folded entry carries the
       moment it landed. #>
    return $script:EntryMergeStampTemplatePlaceholder
}

function Get-EntryWrittenSectionKeys {
    <# The section keys a WRITER emits, in order. Read by Format-EntryBlock and by the lint's entry-shape
       check, so the shape a document claims and the shape the scaffolder produces have one source. #>
    return @($script:EntryWrittenSectionKeys)
}

# EVERY SECTION THAT HAS EVER LEGITIMATELY OPENED AN ENTRY, newest first. The lint's split-entry rule asks
# whether a block's first named section is an opener; a block that starts anywhere else has been cut in two
# by a stray heading at the entry's own level.
#
# IT IS A LIST BECAUSE THE OPENER HAS MOVED TWICE, AND EACH MOVE COST THE SAME BUG. When 'Who is this for'
# was renamed, all 24 pending entries were reported as split. When the dossier form put the title section
# in front on August 6, 2026, it happened again. It happened a THIRD time on August 16, 2026, the moment
# 'Branch title' stopped being written: every pending entry in CHANGELOG.md opens with it, and the gate
# read six correct entries as damaged. Twenty-four false accusations is how a check gets switched off, and
# this one has now had three chances to earn that.
#
# SO THE ANSWER LIVES HERE RATHER THAN IN THE GATE. The gate used to build the list itself, from the
# current first key plus that key's retired NAMES -- which is right until the first KEY changes, and then
# silently answers for the wrong section. This states the keys, and the caller adds each one's retired
# names; a future move means adding one entry here rather than rediscovering the bug.
$script:EntryOpeningSectionKeys = @('What', 'Description')

function Get-EntryOpeningSectionKeys {
    <# The section keys an entry may legitimately open with, newest first. See the block above for why
       this is a list and not Get-EntryFirstSectionKey. #>
    return @($script:EntryOpeningSectionKeys)
}

function Get-EntryFirstSectionKey {
    <# The key of the section an entry must OPEN with ('What'). Stated once because the lint's
       split-entry rule keys on it: a block whose first named section is not this one has been cut in two by
       a stray heading at the entry's own level. Read off the WRITTEN order rather than written out, so
       reordering the sections cannot leave that gate testing the wrong one -- and off the written set
       rather than the recognised one, because a retired section can no longer be an entry's first. #>
    return @($script:EntryWrittenSectionKeys)[0]
}

# The heading levels, stated once. An entry is an H3 and its sections are H4 -- in the entry FILE and in
# CHANGELOG.md alike, which is what makes the fold a verbatim paste: the file used to carry entries at a
# different level that the release renderers re-levelled per document. One level everywhere means the file a
# contributor writes looks exactly like the block that lands.
#
# WHY H3 AND NOT H2 (Dave, August 26, 2026). CHANGELOG.md now carries a '## [Unreleased]' heading that every
# pending entry sits under, so H2 is taken and an entry nests one level inside it. That heading is part of the
# document's HEAD as far as Split-Changelog is concerned -- it sits above the first entry -- which is what
# makes a cut leave it behind and a fold insert directly beneath it, with no boundary rule of its own.
#
# THE PAIR BELOW MOVES WITH THIS ONE, and the equality is the contract: BranchCycleSectionLevel must equal
# EntryHeadingLevel or the fold stops being a verbatim paste. release-lib.tests.ps1 asserts it directly.
$script:EntryHeadingLevel  = 3
$script:EntrySectionLevel  = 4

function Get-EntryHeadingLevel {
    <# The number of '#' an entry's own heading carries (3). Read by the writer, the fold's file test and
       the renderers, so no caller counts hashes for itself. #>
    return $script:EntryHeadingLevel
}

function Get-EntrySectionLevel {
    <# The number of '#' an entry's inner sections carry (4). #>
    return $script:EntrySectionLevel
}

# The shallowest level an entry's sections have ever been WRITTEN at. Stated rather than derived, because it
# is a fact about history and nothing in today's format implies it.
$script:EntrySectionLevelRetired = 3

function Get-EntrySectionLevelRange {
    <#
        The '#{min,max}' fragment matching an entry's section heading at the level it is written at OR at any
        level it HAS been written at. For READERS only -- Get-EntrySectionHeading writes the exact level.

        WHY EVERY READER NEEDS IT, measured on August 26, 2026 when the pair shifted one down. A legacy entry
        is a coherent document at the OLD pair: a retired entry heading at H2 with its sections at H3. Every
        reader that pinned the section level exactly went blind to those sections the moment the level moved
        -- and blind is the bad direction here, because a section that cannot be found reads as a section
        that is not there. The one that made it visible was Remove-EntryAdminSections: it stopped stripping
        the four admin sections out of legacy entries, which is how 125 of 396 lines of a consumer's release
        draft became 'Branch title' printed under the heading it had just become. Exactly the defect its own
        suite was written to prevent, re-entering through the level rather than through the stripper.

        THE SAME SHAPE AS Get-EntryTierSubLevelRange, deliberately: read every level, write one.
    #>
    $levels = @($script:EntrySectionLevel, $script:EntrySectionLevelRetired)
    $min = ($levels | Measure-Object -Minimum).Minimum
    $max = ($levels | Measure-Object -Maximum).Maximum
    return '#{' + $min + ',' + $max + '}'
}

# THE CYCLE FILE SITS ONE LEVEL SHALLOWER, because it is a whole document rather than a fragment (Dave,
# August 19, 2026, by hand in the template that is this format's spec). The entry is PASTED INTO
# CHANGELOG.md and has to arrive at that document's entry level, which is what fixes it at an H2 with H3
# sections. The cycle file travels nowhere: it is opened on its own, so its title is the document's H1 and
# its phases are the H2 sections of it. Stated as its own pair rather than derived as 'entry minus one', so
# a repo that re-levels its changelog does not silently re-level the file beside it.
#
# THE H1/H2 DISTINCTION THIS LOOKS LIKE IT BREAKS BELONGS TO THE OTHER FILE. Reset-H1-versus-written-H2 is
# what stops Test-IsChangelogEntryFile from folding an empty trunk file as a change, and only the entry is
# ever folded. The cycle file's idempotency test is Get-BranchFileDeclaredBranch, which compares the branch
# NAME the heading carries and reads both levels -- so a reset and a written cycle file sharing one level
# costs nothing, and the file now reads as one document in both states.
# SHIFTED ONE LEVEL DOWN ON AUGUST 26, 2026 (Dave), together with the entry pair above and
# CONTRIBUTING.md's own four sections. The relationship is unchanged and it is the relationship that
# matters: this file's SECTION level still equals the entry's HEADING level, which is what makes DEPLOY a
# verbatim paste. What moved is where both pairs sit, because '## [Unreleased]' now occupies H2 in
# CHANGELOG.md. The reading was Dave's: the edited spec on #894 asks for four '###' phases and a '##'
# title, and its dividers carry a '#'.
$script:BranchCycleHeadingLevel = 2
$script:BranchCycleSectionLevel = 3

# The same two levels as literal hash runs, for the guidance text that has to SHOW them to a reader. Derived
# here so the prose and the parser cannot disagree; see the note at StepsGuidance for why they are
# concatenated into that text rather than interpolated.
$script:BranchCyclePhaseHashes = '#' * $script:BranchCycleSectionLevel
$script:BranchCycleSubHashes   = '#' * ($script:BranchCycleSectionLevel + 1)

function Get-BranchCycleHeadingLevel {
    <# The number of '#' the cycle file's own heading carries (2). #>
    return $script:BranchCycleHeadingLevel
}

function Get-BranchCycleSectionLevel {
    <# The number of '#' the cycle file's sections -- the phases and 'Where I left off' -- carry (3). #>
    return $script:BranchCycleSectionLevel
}

# --- MOVED DOWN FROM release-lib.ps1: the entry-boundary readers ----------------------------------
#
# Get-EntryHeadingPattern and Split-EntryBlocks used to live in release-lib.ps1. They moved here on
# August 10, 2026 for the SAME reason Get-FencedLineFlags did, and that reason is a dependency
# direction rather than a preference: the fold and this file's own suite load this lib STANDALONE,
# while nothing loads release-lib without it. So an answer both the cut and the fold need can only
# live down here. release-lib calls both by exactly these names and is unchanged -- it dot-sources
# this file unconditionally, at the top.
#
# WHAT MADE THE MOVE NECESSARY rather than tidy: Get-PreFlatChangelogRefusal below is that shared
# answer (inbound #561), and it cannot be written without a splitter. Leaving the splitter up in
# release-lib would have meant either the fold loading release-lib -- and this file, thousands of lines,
# behind it -- immediately after a merge and directly on the trunk, which its own header rejects by
# name -- or a
# second boundary rule written beside the first, free to disagree with it about where the intro ends.
#
# The names deliberately did not gain an 'Entry' prefix on the way down: these readers scan a whole
# CHANGELOG rather than one entry, so a name claiming otherwise would be wrong at every call site --
# and keeping them meant the move changed no call site in either lib.

# --- THE PENDING SECTION: '## [Unreleased]' -------------------------------------------------------
#
# The heading every un-cut entry sits under (Dave, August 26, 2026), and the reason the entry pair moved to
# H3/H4. It reverses the flat shape of August 5, 2026 -- an intro followed directly by one entry per change --
# and the argument for reversing it is that the spec on #894 asks for a named pending section by name, three
# times, while the tree had no such heading anywhere outside CONTRIBUTING.md's own prose.
#
# IT IS PART OF THE DOCUMENT'S HEAD, NOT AN ENTRY, and that single fact is what makes the rest free. Because
# it sits one level SHALLOWER than an entry, Split-Changelog's boundary -- "the first entry heading" -- lands
# below it without knowing it exists. So a cut, which writes the head back and drops the entries, leaves a
# fresh empty '## [Unreleased]' behind on its own; and a fold, which inserts at the top of the entries,
# inserts directly beneath it on its own. Neither needed a rule about it.
#
# AND 'EVERY' IS TRUE OF A CONSUMER ONLY SINCE #1518, which is worth knowing before reading a document
# that has none as broken. adopt-workflow-folder.ps1 scaffolded a changelog without this heading until
# September 6, 2026, so an adoption older than that is the flat shape -- and that scaffolder is additive,
# so it never goes back and adds one. Nothing needs it: the fold inserts at the first entry heading or at
# the end of the content, the cut writes the head back whatever is in it, and the tally carries a third
# anchor for exactly those repos. The word is a claim about what this workflow WRITES, not a precondition
# any reader here enforces.
#
# THE LEVEL IS DERIVED rather than stated, so it cannot drift from the entry level it is defined against.
#
# THE LABEL IS A SINGLE CONSTANT AND DELIBERATELY NOT REPO-OWNED -- said here because this comment claimed the
# opposite until September 6, 2026 ('THE LABEL IS A SEAM because a consumer may translate it'), and nothing in
# the code ever agreed with it: this file's own vocabulary for a seam is a Get-Command probe on an optional
# getter (Get-EntryScaffoldWording's three, Merge-WordingOverrides' -OverrideCommand), and the label has
# neither shape, nor a line in script-contract-lib.ps1. Left standing, the next maintainer would have added
# the override the comment promised -- and the cheapest place to add it is the reader, Get-ChangelogUnreleasedPattern,
# which is half a seam and silently stops matching the document (issue #1517).
#
# THE REASON IT IS A CONSTANT IS THAT NOTHING MIGRATES THE DOCUMENT. Every function below derives from this
# one value, so writer and reader move together -- and what they would move AWAY from is the '## [Unreleased]'
# already committed in this repo's CHANGELOG.md and in every consumer's, which no script here rewrites. An
# override would take the pattern off the heading it is pointed at, and the fold's insertion point with it.
# Get-PreFlatChangelogRefusal makes that explicit from the other side: it hands a consumer migrating a
# pre-flat document the literal string to type.
#
# (That 'and in every consumer's' is what #1518 above made true of a FRESH adoption; in an older one the
# string is absent rather than different, which is the flat shape and not a second spelling. Either way
# there is nothing for an override to migrate away from -- the two findings landed the same day and point
# the same way.)
#
# AND IT IS AN ANCHOR, NOT PROSE -- matched by an anchored regex, never read. That is exactly what separates
# it from the tally one block down, whose wording IS seamed (Get-ChangelogPendingSummaryOverrides): that line
# is rendered fresh on every fold and a consumer reads it, so translating it costs nothing and gains a reader.
# Same distinction, same file, as $script:EntryScaffoldLegacyMarkers above -- a string with nothing for a
# consumer to choose about it is kept out of the seam rather than given one nobody asked for.
$script:ChangelogUnreleasedLabel = '[Unreleased]'

function Get-ChangelogUnreleasedLabel {
    <# The text of the pending section's heading, without its hashes ('[Unreleased]'). #>
    return $script:ChangelogUnreleasedLabel
}

function Get-ChangelogUnreleasedLevel {
    <# The number of '#' the pending heading carries -- exactly one shallower than an entry, which is what
       keeps it in the head rather than in the entry list. #>
    return ((Get-EntryHeadingLevel) - 1)
}

function Get-ChangelogUnreleasedHeading {
    <# The pending section's whole heading line ('## [Unreleased]'). #>
    return (('#' * (Get-ChangelogUnreleasedLevel)) + ' ' + (Get-ChangelogUnreleasedLabel))
}

function Get-ChangelogUnreleasedPattern {
    <# The anchored regex matching that heading and nothing else. Exact level, for the same reason
       Get-EntryHeadingPattern is exact: a range would match an entry below it. #>
    return ('^#{' + (Get-ChangelogUnreleasedLevel) + '}\s+' +
        [regex]::Escape((Get-ChangelogUnreleasedLabel)) + '\s*$')
}

# --- THE PENDING TALLY, WRITTEN UNDER THE PENDING HEADING (issue #1515) ---------------------------
#
# What Dave asked for is the one question CHANGELOG.md could not answer without counting by hand: how
# much is waiting for the next release, and how much of it reaches anybody outside this repo. Both
# numbers are already in the document -- Get-ChangelogEntryBlocks knows how many entries are pending
# and Resolve-EntryImpact knows each one's reach -- so the line below is a RENDERING of the list rather
# than a record kept beside it.
#
# WHICH IS THE WHOLE DESIGN, AND THE REASON IT NEEDS NO BOOKKEEPING. It is recomputed from the entries
# every time it is written, by the two scripts that change the list: the fold, which adds one entry, and
# the cut, which removes them all. Nothing increments a counter, so nothing can drift -- an entry
# hand-edited into or out of the file is simply re-measured on the next fold and comes out right. That
# is also what makes it safe on the trunk: the fold is a direct push under one of this repo's named
# exceptions, and a derived line can be wrong for exactly as long as it takes the next fold to run.
#
# IT CARRIES A MARKER, AND IS REPLACED ONLY WHERE THAT MARKER IS FOUND. Recognising the line
# structurally -- "the first paragraph under the pending heading" -- is what this file does everywhere
# else, and it is the wrong answer HERE: that region is a human's to write in as much as the fold's, and
# a note silently eaten by the next merge is precisely the class of failure a direct-to-trunk commit must
# not have. An HTML comment renders as nothing, survives a consumer translating every word around it,
# and cannot be produced by accident.
#
# IT IS THREE FACTS ON ONE LINE, AND IT USED TO BE A PER-TIER BREAKDOWN (Dave, September 7, 2026, issue
# #1545). It read '**9 entries pending** -- 5 at tier 0, 4 at tier 2. Tier 2 is this repo's audience: 4 of
# 9 reach it.' -- every number the document holds, none of them ranked, in a sentence long enough to push
# the first entry off the screen the tally exists to summarise. Dave's instruction was to keep it short
# and simple, and what survived the cut is the reach fraction plus the bump it earns: '**4 / 9 minor
# entries**'. The per-tier buckets are gone -- they are one 'grep' away in the entries themselves, which
# is where Resolve-EntryImpact reads them from anyway, so the line was spending its length on the one
# thing the document below it already spells out per entry.
#
# THE COUNT IT KEEPS IS STILL DISJOINT AND STILL SUMS, because Resolve-EntryImpact reports the HIGHEST
# tier an entry declares -- the same grouping Get-PullRequestEntriesByTier uses, so the tally cannot
# disagree with what the cut is about to read. That property mattered for the buckets and it still matters
# for the fraction: Reaching is a subset of Total by construction, never a second measurement of it.
#
# AND THE BUMP *IS* NAMED HERE NOW, which reverses a decision this comment used to state. It said: 'NO
# BUMP IS NAMED HERE, deliberately... that rule lives in Test-ReleaseBumpEarned, in release-lib, which the
# fold does not load and must not start loading for a console nicety -- and a second copy of a release
# gate's arithmetic, in the document that gate then reads, is the second-literal shape this repo keeps
# getting bitten by.' Both halves of that were true and the conclusion did not follow. The copy is the
# hazard, not the naming, and the fix for a copy is one definition rather than silence:
# Get-EntryEarnedBump now lives in THIS file, which release-lib dot-sources, so the fold reaches the rule
# without loading release-lib and Test-ReleaseBumpEarned reads the same function instead of its own inline
# loop. There is one copy where there were about to be two, and it sits in the layer both callers already
# share.
#
# THE TWO NUMBERS ANSWER DIFFERENT QUESTIONS AND MAY DIFFER, which is the one thing to know before reading
# the line. Reaching counts entries at or above the repo's AUDIENCE tier; the bump follows tier 1 OR
# HIGHER. In a repo whose audience is 2 those are not the same set, so '0 / 8 minor entries' is a
# reachable and correct sentence -- eight entries pending, none of them reaching a subscriber, and the
# version still owes a minor because some of them reach management. Reaching is who NOTICES; the bump is
# what the version OWES.
$script:ChangelogPendingSummaryMarker = '<!-- pending-tally -->'

# ENGLISH DEFAULTS, OVERRIDABLE, for the reason every string written into a consumer's changelog is: this
# is generated prose in a document a repo may keep in its own language, and the retired
# Get-ChangelogReleaseWording seam went only because the output it described stopped being written. This
# is new output into that same file, so the argument it was retired under does not cover it.
#
# THREE KEYS RETIRED WITH THE PER-TIER SHAPE (issue #1545): Lead, Bucket and AudienceShare are no longer
# written by anything. Merge-WordingOverrides reads only keys the defaults carry, so a consumer who had
# translated those three keeps a seam answer that is now INERT rather than one that errors -- there is no
# way for this file to tell them, which is why the changelog entry for #1545 says it in words. Share and
# NoShare are the two lines that replaced them, and a repo that translated nothing is unaffected.
$script:ChangelogPendingSummaryDefaults = [ordered]@{
    Empty   = '**Nothing pending.** The last release took every entry.'
    Share   = '**{0} / {1} {2} {3}**'
    NoShare = '**{0} {1} {2}**'
    Entry   = 'entry'
    Entries = 'entries'
    Minor   = 'minor'
    Patch   = 'patch'
}

function Get-ChangelogPendingSummaryMarker {
    <# The HTML comment that identifies a tally this system wrote, so nothing else in the pending
       heading's region is ever overwritten. #>
    return $script:ChangelogPendingSummaryMarker
}

function Test-ChangelogTallyIsQuoted {
    <#
        Pure: is the marker on this line being QUOTED rather than being the tally itself -- i.e. does it
        begin inside an inline code span?

        THE FENCE CHECK IS NOT ENOUGH ON ITS OWN, and this is the hazard it misses. The one document that
        will ever describe this line in prose is the changelog's own intro, and the natural way to name
        the marker there is inline backticks -- which Get-FencedLineFlags does not see, so the next fold
        would overwrite that sentence with a tally. A doc silently eaten by a commit that lands directly
        on the trunk is exactly what the marker exists to prevent, so the marker must not be able to cause
        it one paragraph up.

        NOT Get-EntryCodeSpans, which is the obvious reuse and is wrong here: its third pass treats HTML
        COMMENTS as spans, and this marker IS an html comment -- so every occurrence, real and quoted
        alike, would come back quoted. The backtick pass is the only one of its three that discriminates,
        and it is one line.

        PER LINE, which is a stated bound rather than an oversight: a marker split across a line break
        inside an inline span is not reachable from anything that writes this file, and the caller is
        walking lines because the tally is defined as one.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Line)

    $at = $Line.IndexOf((Get-ChangelogPendingSummaryMarker))
    if ($at -lt 0) { return $false }
    foreach ($m in [regex]::Matches($Line, '(`+).*?\1')) {
        if ($at -ge $m.Index -and $at -lt ($m.Index + $m.Length)) { return $true }
    }
    return $false
}

function Get-ChangelogPendingSummaryWording {
    <# The tally's wording, this repo's answers merged over the English defaults -- the same mechanism,
       and the same empty-is-ignored fail-safe, as Get-EntrySignificanceWording. #>
    return Merge-WordingOverrides -Defaults $script:ChangelogPendingSummaryDefaults `
        -OverrideCommand 'Get-ChangelogPendingSummaryOverrides'
}

function Get-ChangelogPendingCounts {
    <#
        Pure: what is pending in a CHANGELOG.md. Returns

          Total     how many entries sit under the pending heading
          ByTier    tier -> count, disjoint (an entry is counted at the highest tier it declares) and
                    always carrying every tier from 0 to Get-EntryTierMax, present or not
          Audience  the one tier this repo publishes to, or $null where it has stated none
          Reaching  how many entries reach that audience -- tier >= Audience, so it reads correctly in a
                    tier-1 and a tier-2 repo alike; 0 where no audience is stated

        AT OR ABOVE, not equal to, and that is the cumulative model rather than a looseness: an entry
        declaring tier 2 in a repo whose audience is 1 does reach that audience. Written as '>=' for the
        same reason Test-ReleaseBumpEarned writes its own count that way -- neither repo has to translate.

        AN EMPTY DOCUMENT IS A COUNT OF ZERO, NOT A FAILURE, which is why this reads
        Get-ChangelogEntryBlocks and not Split-Changelog: the second one throws on a changelog with no
        entries, and the moment right after a release cut is exactly when this has to answer.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Content)

    $blocks = @(Get-ChangelogEntryBlocks -Content $Content)
    $byTier = @{}
    foreach ($t in 0..(Get-EntryTierMax)) { $byTier[$t] = 0 }
    foreach ($b in $blocks) {
        $tier = [int](Resolve-EntryImpact -EntryText $b).Tier
        if (-not $byTier.ContainsKey($tier)) { $byTier[$tier] = 0 }
        $byTier[$tier] = $byTier[$tier] + 1
    }

    $audience = Get-EntryAudienceTier
    $reaching = 0
    if ($null -ne $audience) {
        foreach ($t in @($byTier.Keys)) { if ($t -ge $audience) { $reaching += $byTier[$t] } }
    }

    return [pscustomobject]@{
        Total    = $blocks.Count
        ByTier   = $byTier
        Audience = $audience
        Reaching = $reaching
    }
}

function Format-ChangelogPendingSummary {
    <#
        Pure: the tally line for a CHANGELOG.md, marker included. ONE line, always -- it sits directly
        under a heading, and a paragraph there would push the first entry off the screen the tally exists
        to summarise.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Content)

    $w = Get-ChangelogPendingSummaryWording
    $counts = Get-ChangelogPendingCounts -Content $Content
    $marker = Get-ChangelogPendingSummaryMarker

    if ($counts.Total -eq 0) { return ($w.Empty + ' ' + $marker) }

    $noun = if ($counts.Total -eq 1) { $w.Entry } else { $w.Entries }

    # ONE definition of the rule, called rather than restated -- see Get-EntryEarnedBump, which
    # Test-ReleaseBumpEarned reads too.
    $earned = Get-EntryEarnedBump -ByTier $counts.ByTier
    $bump = if ($earned.Bump -eq 'minor') { $w.Minor } else { $w.Patch }

    # NO FRACTION WHERE THE REPO HAS STATED NO AUDIENCE, because Reaching is 0 there for want of a
    # question rather than for want of entries -- and '0 / 9' would report the absence of a config value
    # as the absence of reach, which is the one reading a maintainer must not be given. Get-EntryAskedTiers
    # is asking about every tier in that repo, so the total is the honest number and the bump still stands.
    if ($null -eq $counts.Audience) {
        return (($w.NoShare -f $counts.Total, $bump, $noun) + ' ' + $marker)
    }
    return (($w.Share -f $counts.Reaching, $counts.Total, $bump, $noun) + ' ' + $marker)
}

function Set-ChangelogPendingSummary {
    <#
        Pure: a CHANGELOG.md with its tally line current -- replaced where one is already there, inserted
        where it is not. Content in, content out; nothing is written and nothing is thrown.

        THREE ANCHORS, IN THIS ORDER, because three shapes of this document exist right now:

          1. the marker          -- replace in place, wherever it sits. The position is not re-derived, so
                                    a repo that moved the line keeps it where they put it.
          2. the pending heading -- insert directly beneath it. This repo's shape, and since #1518 the
                                    shape adopt-workflow-folder.ps1 scaffolds as well.
          3. the first entry     -- insert directly above it. A consumer scaffolded BEFORE #1518 has NO
                                    pending heading: that scaffold wrote none, so their intro is followed
                                    straight by the entries -- and the scaffolder is additive, so it never
                                    goes back and adds one. Anchoring on the heading alone would have the
                                    tally silently never appear in those repos, which is the direction
                                    that ships a feature to nobody.

        And with none of the three -- an intro and nothing else -- the line is appended, which is the
        empty-list case and the one a freshly cut repo is in.

        FENCE-AWARE ON ALL THREE, for the reason every reader in this file is: this repo's changelog intro
        quotes an entry heading inside a fence to document the format, and a tally inserted into the
        middle of that fence would be both wrong and invisible to the next run's replace. The marker
        anchor takes one guard more -- Test-ChangelogTallyIsQuoted, for the inline backticks a fence check
        cannot see, which is how the intro will actually name it.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Content)

    $nl = Get-DocumentNewline -Content $Content
    $summary = Format-ChangelogPendingSummary -Content $Content
    $lines = @($Content -split "`r?`n")
    $fenced = Get-FencedLineFlags -Lines $lines
    $markerRx = [regex]::Escape((Get-ChangelogPendingSummaryMarker))

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($fenced[$i]) { continue }
        if ($lines[$i] -notmatch $markerRx) { continue }
        if (Test-ChangelogTallyIsQuoted -Line $lines[$i]) { continue }
        $lines[$i] = $summary
        return ($lines -join $nl)
    }

    $headingRx = Get-ChangelogUnreleasedPattern
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ((-not $fenced[$i]) -and $lines[$i] -match $headingRx) {
            $tail = @()
            if ($i + 1 -lt $lines.Count) { $tail = @($lines[($i + 1)..($lines.Count - 1)]) }
            # A blank line before AND after: the heading needs one or markdown reads the two as a single
            # paragraph, and whatever follows needs one for the same reason. The second is added only
            # where the document does not already have it, so a rerun cannot grow the gap.
            $block = @('', $summary)
            if ($tail.Count -eq 0 -or $tail[0].Trim() -ne '') { $block += '' }
            return ((@($lines[0..$i]) + $block + $tail) -join $nl)
        }
    }

    $entryRx = Get-EntryHeadingPattern
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ((-not $fenced[$i]) -and $lines[$i] -match $entryRx) {
            $head = @()
            if ($i -gt 0) { $head = @($lines[0..($i - 1)]) }
            return (($head + @($summary, '') + @($lines[$i..($lines.Count - 1)])) -join $nl)
        }
    }

    return ($Content.TrimEnd() + $nl + $nl + $summary + $nl)
}

function Get-EntryHeadingPattern {
    <#
        The anchored regex that matches an entry's OWN heading and nothing else -- '^###\s' while the entry
        level is 3. Built from Get-EntryHeadingLevel so the parser, the splitter and the re-leveller cannot
        end up looking for different things.

        THE EXACT LEVEL, NOT A RANGE, and that is the one decision in this whole file that cannot be
        loosened. An entry carries H4 sections of its own, so a pattern accepting the section level as well
        would read every entry as several. It is safe as an exact match for the mirror image of the same
        reason: '^###' followed by '\s' cannot match '#### ', because the fourth character is a '#'.
    #>
    return '^#{' + (Get-EntryHeadingLevel) + '}\s'
}

function Get-FoldedEntryForBranch {
    <#
        Pure: the entry ALREADY IN the changelog whose heading names $Branch, or $null when there is
        none. Returns Heading (the literal line) and PrNumber (the number on its '[PR #NN](url)' closing
        line, or 0 when it carries none).

        WHAT IT IS FOR. fold-changelog-entry.ps1 wrote a second entry for a branch that already had one
        and reported both folds as a success -- measured in a consumer, two entries with the same text
        and two different PR numbers (inbound #1082). The route in was #1077, and closing that closes
        this way in; what this function exists for is that the step which actually WRITES the record had
        nothing to say about writing it twice.

        THE BRANCH NAME IS THE KEY, AND THE STAMP IS NOT. The fold writes the stamp at fold time, so the
        duplicate carried a different one -- which is exactly why nothing matched. The branch name is
        sound instead: a second cycle on the same subject is '-v2' by convention -- typed by hand, since
        new-branch stopped completing the suffix -- so two entries naming one branch is not a state the
        cycle reaches legitimately. The entry TEXT is not a key either: two branches may describe the same change in
        the same words, and refusing that would refuse honest work.

        MATCHED AS A WHOLE NAME, NOT BY SUBSTRING. 'feat/a-v1' must not answer for 'feat/a', and a substring
        test says it does -- so the name is compared to what the heading actually delimits: the backticks
        where an entry has them, and the token after the title word's colon where it does not (#1335).
        Headings inside fenced code are skipped for the reason every other reader in this file skips
        them: a changelog entry quoting a heading in an example is describing one, not being one.

        AND AN ENTRY WHOSE HEADING NAMES NO BRANCH CANNOT BE MATCHED, which is a real limit rather than a
        gap to close: an entry written before the DEPLOY heading carried the branch has nothing to key on,
        so the fold folds it exactly as it always did. The guard is as good as the format that carries the
        name, and every entry written since that heading arrived carries it.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$ChangelogText,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Branch
    )

    if ([string]::IsNullOrWhiteSpace($ChangelogText) -or [string]::IsNullOrWhiteSpace($Branch)) { return $null }

    $wanted = $Branch.Trim()
    $lines = ($ChangelogText -replace "`r`n", "`n").Split("`n")
    $fenced = Get-FencedLineFlags -Lines $lines
    $headingRx = [regex](Get-EntryHeadingPattern)

    # Two passes in one walk: find the heading, then read forward to the next entry boundary for the PR
    # line. The first match wins -- the list is newest-first, so it is the most recent of a duplicated
    # pair, which is the one a reader would be told about.
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($fenced[$i]) { continue }
        if (-not $headingRx.IsMatch($lines[$i])) { continue }
        # BOTH DELIMITINGS (#1335). Every entry folded before September 3, 2026 names its branch between
        # backticks; every one after it names it bare, after the title word and before the optional merge
        # stamp. The name is still MATCHED rather than substring-tested in both -- 'feat/a-v1' must not
        # answer for 'feat/a' -- which for the bare shape means taking the whole token and comparing it.
        $names = @([regex]::Matches($lines[$i], '`([^`]+)`') | ForEach-Object { $_.Groups[1].Value })
        $bare = [regex]::Match($lines[$i], ':\s+([^\s`]+)')
        if ($bare.Success) { $names += $bare.Groups[1].Value }
        $isMine = $false
        foreach ($n in $names) { if (([string]$n).Trim() -eq $wanted) { $isMine = $true } }
        if (-not $isMine) { continue }

        $pr = 0
        for ($j = $i + 1; $j -lt $lines.Count; $j++) {
            if (-not $fenced[$j] -and $headingRx.IsMatch($lines[$j])) { break }
            $m = [regex]::Match($lines[$j], '\[PR #(\d+)\]')
            if ($m.Success) { $pr = [int]$m.Groups[1].Value; break }
        }
        return [pscustomobject]@{ Heading = $lines[$i]; PrNumber = $pr }
    }

    return $null
}

function Get-EntryBlocksForBranch {
    <#
        Every entry block in a changelog whose heading names $Branch, in document order -- an empty array
        when none does.

        WHY IT SITS BESIDE Get-FoldedEntryForBranch RATHER THAN INSIDE IT. That function answers "does
        this branch already have an entry", and it stops at the FIRST hit deliberately: the list is
        newest-first, so the first is the one a reader would be told about. Two questions need more than
        the first, and both are asked by the fold at the one moment it can no longer assume anything --
        when its push is rejected (inbound #1405). HOW MANY entries name the branch, because a duplicate
        proves itself by appearing twice and a single upstream entry proves the opposite. And WHAT each
        one says, because "the work is already upstream" is only safe to state once the upstream text has
        been compared to the local one.

        IT DEFINES NEITHER RULE ITSELF, which is the whole point of the shape. The entry BOUNDARY comes
        from Get-ChangelogEntryBlocks and the NAME MATCH from Get-FoldedEntryForBranch, applied one block
        at a time -- so the fence skipping, the backtick/bare delimiting and the whole-name test stay in
        exactly one place each, and what this reports can never drift from what the gate enforces.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$ChangelogText,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Branch
    )

    if ([string]::IsNullOrWhiteSpace($ChangelogText) -or [string]::IsNullOrWhiteSpace($Branch)) { return @() }
    return @(Get-ChangelogEntryBlocks -Content $ChangelogText |
        Where-Object { $null -ne (Get-FoldedEntryForBranch -ChangelogText $_ -Branch $Branch) })
}

function Get-EntryBlockHeadingLevel {
    <#
        Pure: the level of the heading an entry block OPENS with -- 2 for a block written in the flat
        window (August 5-26, 2026), 3 for one written at today's level -- or 0 for a block that carries
        no heading at all.

        MEASURED FROM THE BLOCK, WHICH IS THE WHOLE POINT OF NAMING IT. Every other answer to "what level
        is this entry at" in this system was DERIVED from the current level, and a derived answer is wrong
        for exactly the blocks that need one: an entry written before the level last moved. The measured
        instance is inbound #953 -- the fold built its legacy-promotion range as
        '#{level,level+1}', which said H3-or-H4 once the level reached 3. H4 is a level no entry has ever
        opened with, and H2 -- the level every flat-window entry carries -- fell outside it. A consumer
        folding a pending entry written before their plugin update therefore got it inserted unpromoted,
        as a sibling of '## [Unreleased]' rather than a child of it.

        FENCE-AWARE, like every structure reader in this file: an entry documenting the entry format quotes
        these headings inside a fence, and the quoted one must not be mistaken for the block's own.

        0 RATHER THAN A GUESS for a headingless block. There is nothing to measure, and a caller that
        needs to know can compare -- inventing a level would put a heading on prose.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$EntryText)
    $lines = @(($EntryText -replace "`r`n", "`n") -split "`n")
    $fenced = Get-FencedLineFlags -Lines $lines
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($fenced[$i]) { continue }
        $m = [regex]::Match($lines[$i], '^(#{1,6})\s')
        if ($m.Success) { return $m.Groups[1].Value.Length }
    }
    return 0
}

function Set-EntryHeadingLevel {
    <#
        Pure: shifts EVERY heading in an entry block so the entry's own heading sits at $EntryLevel, and
        its inner sections move with it. Returns the block with LF newlines.

        WHY THE WHOLE BLOCK AND NOT JUST THE FIRST LINE. Until August 5, 2026 an entry was a heading plus
        prose, so re-levelling meant rewriting one line -- and the renderer did exactly that, with a '^'
        anchored to the start of the block. An entry now carries two named H4 sections of its own (the
        'What' question and 'Pull Request'), so shifting only the heading would leave those sections at
        the level of the ENTRY above them: one entry rendering as several, in well-formed markdown that
        no parser would complain about.

        SHIFTED BY A DELTA, NOT SET TO A LEVEL. Every non-fenced heading moves by the same amount, which
        preserves the structure inside the entry whatever it is -- an H5 sub-heading in a body stays one
        level below the section it is in. Setting levels absolutely would need this function to know which
        headings are which, and it does not need to know.

        FENCE-AWARE, for the reason every parser in this file is: an entry documenting the entry format
        quotes these headings inside a fence -- this repo's own changelog does -- and shifting a quoted
        heading corrupts the example.

        A DELTA OF 0 RETURNS THE BLOCK UNCHANGED apart from the newline normalisation, so a document that
        renders entries at their native level pays nothing.

        THE DELTA IS MEASURED FROM THE BLOCK, NOT ASSUMED, and that is a repair rather than a refinement
        (August 5, 2026). It used to be '$EntryLevel - Get-EntryHeadingLevel' -- the shift needed by a block
        that is ALREADY at the canonical level, which every caller here happens to pass, since they read
        entries straight out of CHANGELOG.md. Handed a block that is already deeper the function therefore
        computed the wrong delta and, for the exact case of normalising one BACK to canonical, computed
        zero and silently returned the block untouched. Its own contract above promises "so the entry's own
        heading sits at $EntryLevel", which is what it now does.
        Measured on new-internal-note.ps1, which reads entries out of the developer notes (where they sit
        one level deeper, under the tier headings) and normalises them so the section readers can find
        anything: every bullet came out without its type, because the block handed to Resolve-EntryType had
        never been shifted and its sections were still one level below where that reader looks.

        A BLOCK WITH NO HEADING AT ALL is returned normalised and otherwise untouched -- there is nothing to
        measure from, and inventing a level would be worse than leaving prose alone.

        CLAMPED AT H6, which markdown has no level beyond. Reached only by a deeply nested body in a deeply
        nested document; clamping keeps the line a heading rather than turning it into literal '#######'
        text, which is what markdown renders past six.

        IT LIVES IN THIS LIB RATHER THAN IN release-lib.ps1 SINCE inbound #953 (August 27, 2026), and the
        move is what let the FOLD reuse it. fold-changelog-entry.ps1 deliberately depends only on the small
        libs -- release-lib pulls the whole plugin tree in behind it, and that dependency was cut on
        August 9, 2026 on purpose -- so the fold could not call this function and carried its own
        first-line-only promotion instead. Two answers to one question, and the fold's was the wrong one.
        Moving the function DOWN to where the format itself is defined keeps every existing caller
        working unchanged (release-lib dot-sources this file) and leaves one re-leveller in the system.
        Exactly the move Get-FencedLineFlags made, for the same reason.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$EntryText,
        [Parameter(Mandatory)][int]$EntryLevel
    )
    $lines = @(($EntryText -replace "`r`n", "`n") -split "`n")
    # The block's own level comes from the one reader that measures it, so this function and the fold's
    # report of what it did cannot disagree about what an entry was written at.
    $ownLevel = Get-EntryBlockHeadingLevel -EntryText $EntryText
    if ($ownLevel -eq 0) { return ($lines -join "`n") }
    $delta = $EntryLevel - $ownLevel
    if ($delta -eq 0) { return ($lines -join "`n") }

    $fenced = Get-FencedLineFlags -Lines $lines
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($fenced[$i]) { continue }
        $m = [regex]::Match($lines[$i], '^(#{1,6})(\s.*)$')
        if (-not $m.Success) { continue }
        $level = [Math]::Max(1, [Math]::Min(6, $m.Groups[1].Value.Length + $delta))
        $lines[$i] = ('#' * $level) + $m.Groups[2].Value
    }
    return ($lines -join "`n")
}

function Split-EntryBlocks {
    <#
        Turns a run of lines into entry blocks. A new block starts at every entry heading
        (Get-EntryHeadingPattern); '---' separators between entries are skipped.

        BOTH of those tests must ignore FENCED CODE BLOCKS. An entry body may legitimately quote markdown
        -- a broken heading structure, a YAML frontmatter example -- and without fence awareness the
        parser reads that quoted text as structure. Measured while cutting v2.13.3: an entry that quoted
        a '### #242 ...' line inside a ``` fence produced a THIRD entry from two PRs, split the fence
        open, and duplicated '## Fixes' in the generated notes. Caught by -NoPush before it shipped.
        Fourth instance of the same defect class in one day (#227, #235, and the teardown's VUL-IN test):
        a matcher satisfied by a MENTION rather than a use.

        Its own function since the changelog gained one section per tier, and kept now that the sections
        are gone: the entry-boundary rule and the fence handling are one answer and belong in one place.
        No longer private -- Get-PreFlatChangelogRefusal below and release-lib's Split-Changelog are both
        callers, which is what brought it down here.
    #>
    param(
        [AllowEmptyCollection()][string[]]$Lines = @(),
        [Parameter(Mandatory)][string]$Nl
    )
    $headingRx = Get-EntryHeadingPattern
    $fenced = Get-FencedLineFlags -Lines $Lines
    $entries = @()
    $cur = $null
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $ln = $Lines[$i]
        if ((-not $fenced[$i]) -and $ln -match $headingRx) {
            if ($null -ne $cur) { $entries += (($cur -join $Nl).Trim()) }
            $cur = @($ln)
        } elseif ($null -ne $cur) {
            if ((-not $fenced[$i]) -and $ln -match '^---\s*$') { continue }
            $cur += $ln
        }
    }
    if ($null -ne $cur) { $entries += (($cur -join $Nl).Trim()) }
    return @($entries)
}

function Get-ChangelogEntryBlocks {
    <#
        Every entry block in a CHANGELOG.md, in document order -- the intro above the first entry heading
        dropped. An empty array when the document holds no entry at all, which is a legitimate state here
        rather than a failure: a repo whose pending list is empty has an intro and nothing else, and the
        first fold after a release lands in exactly that document.

        THE BOUNDARY IS DERIVED, NOT CONFIGURED, and it is fence-aware for the reason every reader in this
        file is: this repo's own changelog intro QUOTES an entry heading inside a fence to document the
        format, so a boundary walk blind to fences puts the intro/list split in the middle of a code block.

        Split out of release-lib's Split-Changelog so the fold can ask the same question without loading
        release-lib. That function keeps its own richer answer (the newline style and the intro text, which
        only the cut needs) and now shares this one's boundary rule instead of restating it.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Content)

    $nl = Get-DocumentNewline -Content $Content
    $lines = @($Content -split "`r?`n")
    $headingRx = Get-EntryHeadingPattern
    $fenced = Get-FencedLineFlags -Lines $lines
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ((-not $fenced[$i]) -and $lines[$i] -match $headingRx) {
            return @(Split-EntryBlocks -Lines @($lines[$i..($lines.Count - 1)]) -Nl $nl)
        }
    }
    return @()
}

function Get-PreFlatChangelogRefusal {
    <#
        The refusal a script owes a consumer whose CHANGELOG.md still carries the PRE-FLAT shape, or '' when
        the document is fine. Pure: text in, text out, nothing written and nothing thrown -- the caller
        decides whether to throw it, print it, or exit on it.

        WHY IT IS SHARED, AND IT IS A MEASURED CONSUMER DEFECT (inbound #561, August 10, 2026). Two scripts
        make the same assumption -- that every H2 below the intro is one change -- and only ONE of them
        checked it. The cut refused, by name, before writing anything. The fold did not: it took the first
        '^## ' it found as the top of the list, which in a pre-flat document is the SECTION heading, and
        inserted the entry above it. Measured in a consumer on 2026-08-09, exit 0 and no warning:

            Folded and reset: workflow-davekjohn/development-cycle.md (tier 1, significance 3 -- placed above 2 existing entries)
            CHANGELOG.md updated.

        The "2 existing entries" were their two section headings, and the entry landed outside the section
        it belonged in -- visible only to somebody who opened the file afterwards. Two scripts with the same
        assumption owe their consumer the same guardrail, so the text lives once and both read it.

        THE CONSEQUENCE CLAUSE IS THE CALLER'S, and that is the only part that varies: the cut EMPTIES this
        file, so a section heading read as a change is published outward and then deleted, while the fold
        WRITES INTO it, so the entry lands in the wrong place. Same diagnosis, same migration advice,
        different thing about to go wrong -- so that one sentence is a parameter rather than a second copy
        of the whole message.

        Test-EntryDeclaresShape is the discriminator and it is exact rather than a heuristic -- see its
        header. A document with no entries at all yields no findings: there is nothing to misread.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content,
        # What this particular caller is about to do to the blocks it cannot read. One sentence, no
        # trailing period -- it is spliced into the sentence below.
        [Parameter(Mandatory)][string]$Consequence
    )

    $level = Get-EntryHeadingLevel
    $blocks = @(Get-ChangelogEntryBlocks -Content $Content)
    $notEntries = @($blocks | Where-Object { -not (Test-EntryDeclaresShape -EntryText $_) })

    # AND THE HEAD IS SCANNED TOO, SINCE AUGUST 26, 2026, because the entry level moved DOWN and took this
    # guard's reach with it. Measured as a red suite on the day of the shift, on the fixture that had proved
    # the guard worked: a pre-flat document whose tier sections are H2 and whose entries are H3 used to be
    # refused, because the tier headings sat at the entry level and declared nothing. With an entry at H3
    # those H2 headings are one level SHALLOWER than an entry, so Split-Changelog's boundary lands below them
    # and they disappear into the head -- unseen by the loop above, preserved by every cut, and the document
    # parses as one perfectly good entry. Quietly wrong output from a guard that exists to prevent exactly
    # that is worse than no guard, so the head gets the same treatment as the entries.
    #
    # THE PENDING HEADING IS THE ONE LEGITIMATE OCCUPANT of that level in the head, which is what makes the
    # test cheap: anything else at it is a leftover. Fence-aware, because this repo's own intro documents the
    # entry format and quotes these headings inside a fence.
    # THE WHOLE DOCUMENT, NOT ONLY THE HEAD, and stopping at the first entry was a measured miss rather than
    # a simplification. The consumer document this guard was built from has TWO leftover headings with a real
    # entry between them -- '## Pull Requests', the entry, then '## Releases' -- so a scan that broke at the
    # entry found the first and not the second. Both loops missed it: too shallow for the entry loop, too far
    # down for a head-only one. And half a diagnosis is the worst outcome here, because the consumer migrates
    # what they were told about and the cut deletes the rest. The suite asked for both from the start; the
    # assert had been passing on the example list inside the message text rather than on a finding.
    $unreleasedRx = Get-ChangelogUnreleasedPattern
    $headStrayRx  = '^#{' + (Get-ChangelogUnreleasedLevel) + '}\s+\S'
    $headStrays   = @()
    $headLines    = @($Content -split '\r?\n')
    $headFenced   = Get-FencedLineFlags -Lines $headLines
    $seenPending  = $false
    for ($h = 0; $h -lt $headLines.Count; $h++) {
        if ($headFenced[$h]) { continue }
        if ($headLines[$h] -notmatch $headStrayRx) { continue }
        # Exactly ONE pending heading is legitimate. A second is a leftover like any other -- two pending
        # sections mean the fold has been inserting into whichever it found first.
        if ((-not $seenPending) -and $headLines[$h] -match $unreleasedRx) { $seenPending = $true; continue }
        $headStrays += $headLines[$h]
    }

    if ($notEntries.Count -eq 0 -and $headStrays.Count -eq 0) { return '' }

    $names = @(@($notEntries | ForEach-Object { "'" + (($_ -split "`r?`n")[0]) + "'" }) +
        @($headStrays | ForEach-Object { "'" + $_ + "'" }))
    $notEntries = @($notEntries) + @($headStrays)
    $pending = Get-ChangelogUnreleasedHeading
    return ("CHANGELOG.md carries $($notEntries.Count) heading(s) that are neither an entry nor the " +
        "pending section: $($names -join ', '). An H$level below the pending heading is read as one " +
        "change, and an H$(Get-ChangelogUnreleasedLevel) above it is read as part of the intro, so " +
        "$Consequence. That is what a pre-flat CHANGELOG.md looks like to this parser: a section heading " +
        "('## Pull Requests', '## Tier N - Pull Requests', '## Releases') sits either at the level an " +
        "entry occupies or at the one the pending section does. Migrate the document first: drop the " +
        "section headings, put a single '$pending' under the intro, promote each entry to H$level, and " +
        "give it the three named sections. An entry written before this format is fine as it is -- it " +
        "declares its type in its heading.")
}

function Get-EntrySectionHeadings {
    <#
        The three section headings as an ordered map, key -> heading TEXT (no leading hashes): What, Who,
        Type. This repo's answers where repo-config.ps1 overrides them, the English defaults otherwise.

        REPO-OWNED VIA Get-EntrySectionHeadingOverrides, probed with Get-Command like every other prose knob
        here. The seam's name differs from this function's deliberately: repo-config backs each seam with a
        function of that name, and a same-named reader would be replaced by the config's version the moment
        it is dot-sourced -- the collision this file documents on $RepoRoot/$repoRoot, one scope up.

        An override that is present but EMPTY is ignored, the same fail-safe Get-EntryScaffoldWording uses.
        A blank heading would make the parser look for '### ' with nothing after it, which matches the start
        of every section in the document -- so the type reader would return the first section's body and the
        entry would be filed under a type nobody wrote.
    #>
    $out = [ordered]@{}
    foreach ($key in $script:EntrySectionDefaults.Keys) { $out[$key] = $script:EntrySectionDefaults[$key] }
    if (Test-FunctionDefined 'Get-EntrySectionHeadingOverrides') {
        $override = Get-EntrySectionHeadingOverrides
        if ($override) {
            foreach ($entry in $override.GetEnumerator()) {
                $text = [string]$entry.Value
                if ($text) { $out[[string]$entry.Key] = $text.Trim() }
            }
        }
    }
    return $out
}

function Get-EntrySectionHeading {
    <# One section's full heading line, e.g. '### Branch type'. One formatter, so the writer and the
       parser cannot disagree about the level or the spacing.

       -Stamp appends ' <sep> <stamp>' -- the merge moment on the 'Pull Request' heading, and the template's
       placeholder in the same slot. Empty for every other caller and every other section, so the bare
       heading is still what a marker or a gate compares against. #>
    param(
        [Parameter(Mandatory)][ValidateSet('Description', 'Id', 'Type', 'What', 'Significance', 'PullRequest')][string]$Key,
        [AllowEmptyString()][string]$Stamp = ''
    )
    $headings = Get-EntrySectionHeadings
    return ('#' * $script:EntrySectionLevel) + ' ' + $headings[$Key] + (Format-EntrySectionHeadingSuffix -Stamp $Stamp)
}

function Get-EntrySectionBody {
    <#
        Pure: the text under one of an entry's named sections, trimmed -- '' when the section is absent or
        empty.

        FENCE-AWARE, and the FIRST occurrence outside a fence wins, for the reason every reader in this file
        is: an entry documenting this format quotes these headings inside a fence, and the entry for this
        very change does. A section ends at the next heading AT ITS OWN LEVEL OR ABOVE, so a '##### '
        sub-heading inside a body is kept while the next '#### ' or '### ' closes it.

        THE SECTION'S RETIRED NAMES ARE ACCEPTED ALONGSIDE ITS CURRENT ONE, and that is not politeness
        towards history: 'Type of change' became 'Branch type' and 'What does this change do?' became the
        branch-facing question, while CHANGELOG.md and every consumer's tree are full of entries carrying the
        old names. A reader that knew only the new one would find no type on any of them and file the lot
        under nothing -- silent, correct-looking, and wrong. Recognise both, write one.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$EntryText,
        [Parameter(Mandatory)][ValidateSet('Description', 'Id', 'Type', 'What', 'Significance', 'PullRequest')][string]$Key
    )
    $names = @(@((Get-EntrySectionHeadings)[$Key]) + @(Get-EntrySectionRetiredNames -Key $Key) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($names.Count -eq 0) { return '' }
    $body = Get-EntryTextOutsideFences -EntryText $EntryText
    $lines = @($body -split '\r?\n')
    $rx = '^' + (Get-EntrySectionLevelRange) + '\s+(?:' +
        ((@($names) | ForEach-Object { [regex]::Escape([string]$_) }) -join '|') + ')' +
        (Get-EntrySectionHeadingTail)

    $from = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $rx) { $from = $i + 1; break }
    }
    if ($from -lt 0) { return '' }

    $kept = @()
    for ($i = $from; $i -lt $lines.Count; $i++) {
        # Any heading at this level or above closes the section; a deeper one is content.
        if ($lines[$i] -match ('^#{1,' + $script:EntrySectionLevel + '}\s')) { break }
        $kept += $lines[$i]
    }
    return (($kept -join "`n").Trim())
}

function Test-EntryHasSection {
    <#
        Pure: does this entry carry the named section at all, under its current heading or a retired one?

        ABSENT AND EMPTY ARE DIFFERENT QUESTIONS, and conflating them produced a false accusation on the
        first run of the emptiness gate. Get-EntrySectionAnswer returns '' for both, so a gate built on it
        alone reported the title section (then called 'Branch description') as unanswered on every
        pre-dossier entry -- entries that never
        had that section, because their title was the heading. Every branch in flight carries one, so that
        is two dozen refusals for writing an entry correctly under the format that was current at the time.

        A MISSING SECTION IS NOT THIS GATE'S BUSINESS. Whether an entry's structure is right is the lint's
        question (check 13, which knows both shapes); whether the author answered the questions in front of
        them is this one's.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$EntryText,
        [Parameter(Mandatory)][ValidateSet('Description', 'Id', 'Type', 'What', 'Significance', 'PullRequest')][string]$Key
    )
    $names = @(@((Get-EntrySectionHeadings)[$Key]) + @(Get-EntrySectionRetiredNames -Key $Key) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($names.Count -eq 0) { return $false }
    $rx = '(?m)^' + (Get-EntrySectionLevelRange) + '\s+(?:' +
        ((@($names) | ForEach-Object { [regex]::Escape([string]$_) }) -join '|') + ')' +
        (Get-EntrySectionHeadingTail)
    return [bool]([regex]::IsMatch((Get-EntryTextOutsideFences -EntryText $EntryText), $rx))
}

function Get-EntrySectionAnswer {
    <#
        Pure: what the AUTHOR wrote under a section -- its body with the guidance comments stripped and the
        result trimmed. '' means the section is still empty, whatever form text is standing in it.

        THE DISTINCTION IS THE WHOLE POINT, and it only became necessary with the dossier form. A scaffolded
        section is a heading with a comment under it and nothing else; Get-EntrySectionBody returns that
        comment, which is not nothing, so a caller asking "has this been answered" would get yes for every
        untouched entry in the repo. The fold strips those comments, so the section that looked answered
        lands in CHANGELOG.md blank -- found by asking the question the gate actually needs answered rather
        than the one the reader already had.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$EntryText,
        [Parameter(Mandatory)][ValidateSet('Description', 'Id', 'Type', 'What', 'Significance', 'PullRequest')][string]$Key
    )
    $raw = Get-EntrySectionBody -EntryText $EntryText -Key $Key
    if (-not $raw) { return '' }
    return (Remove-EntryHtmlComments -EntryText $raw).Trim()
}

function Get-EntryPrTitle {
    <#
        Pure: the PR title an entry declares -- the name the change is called by, in the PR, in
        CHANGELOG.md and in the release documents. '' when the entry states none.

        TWO PLACES, ONE ANSWER, and this function exists because there are now two. Until August 16, 2026
        the title had a section of its own, headed 'Branch title' (and 'Branch description' before #506);
        it is the first line of the 'Pull Request' section now, which is where a PR title belongs and where
        it had effectively always been -- open-pr composed the PR's title from that section under both
        names. CHANGELOG.md, every release document and every branch in flight carry the old shape, so the
        old shape is tried FIRST and wins where it is present. Recognise both, write one.

        THE FOLD WRITES UNDERNEATH IT, which is what makes "the first line" a safe rule rather than a
        fragile one. The title is written at creation; the 'Plugins:' line and the '[PR #N](...) - merged'
        footer are appended by the fold at the merge, below it. They are skipped by shape anyway -- a
        folded entry whose author never wrote a title would otherwise report its own PR link as the title,
        which is the kind of plausible-looking wrong answer this file keeps paying for.

        THE ANSWER, NOT THE BODY: Get-EntrySectionAnswer strips the guidance comments first, so a template
        or an untouched scaffold reports '' rather than reporting its own hint as the title.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$EntryText)

    $old = Get-EntrySectionAnswer -EntryText $EntryText -Key 'Description'
    if ($old) {
        foreach ($line in @($old -split '\r?\n')) { if ($line.Trim()) { return $line.Trim() } }
    }

    $pr = Get-EntrySectionAnswer -EntryText $EntryText -Key 'PullRequest'
    if (-not $pr) { return '' }
    foreach ($line in @($pr -split '\r?\n')) {
        $t = $line.Trim()
        if (-not $t) { continue }
        # The two lines the FOLD adds, never the author's title.
        if ($t -match '^\[' + [regex]::Escape('PR #') + '\d+\]') { continue }
        if ($t -match '^Plugins:\s') { continue }
        return $t
    }
    return ''
}

function Remove-EntryPluginsLine {
    <#
        Removes the 'Plugins: ...' metadata line (plus the blank line left behind by it) from an
        entry block. That line drives the per-plugin selection in cut-release.ps1, but is repo
        administration and should not be visible in a document written for a consumer; the root
        CHANGELOG and the development notes do show it.

        TWO CALLERS NOW, AND THEY WANT OPPOSITE THINGS FROM IT. Format-RankedEntries in release-lib.ps1
        (under -StripAdminSections) strips the line so a consumer document never carries it. The FOLD
        strips it so it can write the ONE authoritative line itself -- fold-changelog-entry.ps1 derives
        the line from the PR's touched files and appends it, and an entry that already carried a
        hand-written one (issue #1015) would otherwise end up with two.

        IT LIVES HERE, IN THE LIB THAT OWNS THE ENTRY FORMAT, for the same reason Get-ReleaseChangeTypes
        and Set-EntryHeadingLevel do: the fold needs it and cannot depend on release-lib.ps1, whose
        dot-source it narrowed to the small libs on August 9, 2026. It used to sit in release-lib.ps1,
        whose Format-RankedEntries still calls it by this same name through that file's dot-source of
        this one.
    #>
    param([Parameter(Mandatory)][string]$EntryText)
    $t = [regex]::Replace($EntryText, '(?m)^Plugins:[^\r\n]*(\r?\n)?', '')
    return [regex]::Replace($t, '(\r?\n)\1\1+', '$1$1')
}

function Get-ReleaseChangeTypes {
    <#
        The change types the repo's branch table produces -- 'Feat', 'Fix', 'Docs', 'Chore' here. Read from
        Get-BranchTypes in the consumer's own scripts/lib/branch-info.ps1 where the caller has dot-sourced
        it; absent, it falls back to the four canonical types.

        THE FALLBACK IS THE POINT, not a convenience. branch-info.ps1 is repo-owned and deliberately does
        not travel into the plugin mirror, so 'absent' is the ORDINARY case in a consumer rather than an
        edge one -- and the readers below need a list to recognise a type field with, not merely to validate
        against. Measured: while this returned only Get-BranchTypes' answer, new-internal-note.ps1 running
        in a consumer lost the type off every bullet it took from a historical heading, printing the title
        alone with no error.

        IT LIVES HERE, IN THE LIB THAT OWNS THE ENTRY FORMAT, because two of its three readers are here --
        Resolve-EntryType, for the pre-format heading fallback, and the internal note's recogniser through
        it -- and the dependency can only run downward: the fold and this file's own suite load this lib
        standalone. It used to sit in release-lib.ps1, whose Convert-EntryHeadingToTitle still calls it by
        this same name, unchanged, through that file's dot-source of this one.

        NO 'Other' HERE. That was the catch-all CATEGORY LABEL of the retired Get-ReleaseCategories -- a
        thing this repo printed, never a value a branch table produces -- so a heading field reading 'Other'
        is a title by construction rather than by a special case.

        Probed with Get-Command rather than taken as a parameter, the same pattern teardown.ps1 uses for
        Get-RosterIdTokenPattern.
    #>
    if (Test-FunctionDefined 'Get-BranchTypes') { return @(Get-BranchTypes) }
    return @('Feat', 'Fix', 'Docs', 'Chore')
}

function Resolve-EntryType {
    <#
        Pure: the changelog type an entry declares under '### Type of change'. Returns an object with

          Type      the type as written, trimmed -- '' when nothing usable is declared.
          Declared  $true when the section was found with a value.
          Raw       exactly what the section contained, for quoting back at the author.
          Error     $null when all is well; otherwise the reason, ready to print.

        VALIDATED AGAINST THE REPO'S OWN BRANCH TYPES where those are reachable (Get-BranchTypes, which the
        callers dot-source for other reasons). A type the repo does not produce is reported rather than
        absorbed: the release documents group nothing by it any more, but a typo'd type still reaches the
        record and the per-plugin changelogs, where nobody looks again.

        THE FIRST LINE IS THE TYPE, and anything after it is ignored rather than refused. 'Feat' with a
        sentence of justification under it is a reasonable thing to write, and refusing it would make the
        gate an editor.

        FALLS BACK TO THE HEADING for an entry written before this format -- '### Title <midDot> Feat' or the
        older '### Title <midDot> Feat <midDot> 2026-08-03'. Every entry in this repo's history and in every
        consumer's tree carries the type there, and reading them as typeless would file the lot under a
        catch-all. Recognise both, write one.

        RECOGNITION AND VALIDATION USE DIFFERENT LISTS, and conflating them was a measured defect. Both used
        to read Get-BranchTypes and nothing else, so where that function is absent the known-type list was
        EMPTY -- which is right for validation (with no table of its own, a repo has nothing to judge a type
        against) and wrong for recognition (with no list, no heading field can be identified as the type at
        all). branch-info.ps1 is repo-owned and therefore does NOT travel into the plugin mirror, so the
        absent case is the ordinary one in a consumer: new-internal-note.ps1 running there lost the type off
        every bullet it took from a historical heading, silently, printing the title alone. Recognition now
        uses Get-ReleaseChangeTypes -- which probes the repo's table and falls back to the canonical four --
        while validation still only fires where the repo's own table is reachable.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$EntryText)

    $result = [pscustomobject]@{
        Type     = ''
        Declared = $false
        Raw      = ''
        Error    = $null
    }

    # Two lists, two jobs -- see the header. $repoTypes is empty where the repo has no table of its own, and
    # only that list may accuse an author of a wrong type; $known always has something to recognise with.
    $repoTypes = @()
    if (Test-FunctionDefined 'Get-BranchTypes') { $repoTypes = @(Get-BranchTypes) }
    $known = @(Get-ReleaseChangeTypes)

    # THE ANSWER, NOT THE BODY, and the difference is the guidance comment sitting above it. Reading the raw
    # body made the FIRST non-empty line the type -- which since the dossier form is
    # '<!-- options for type are: feat, fix or docs-->', so every new entry declared its type to be that
    # sentence. It parsed, it was Declared, and the only thing that caught it was a test asserting the
    # canonical value: a repo without Get-BranchTypes reachable would have published the comment as a change
    # type into its release documents without a single complaint.
    $section = Get-EntrySectionAnswer -EntryText $EntryText -Key 'Type'
    if ($section) {
        $result.Raw = $section
        $result.Declared = $true
        # The first non-empty line, stripped of the bold/backtick decoration somebody may reasonably add.
        $first = @($section -split '\r?\n' | Where-Object { $_.Trim() })[0]
        $result.Type = ($first -replace '[*`_]', '').Trim()
        # CANONICALISED CASE-INSENSITIVELY, because the two shapes of this section disagree about case. The
        # dossier form's 'Branch type' holds the branch PREFIX ('feat') -- that is what its hint asks for and
        # what the scaffolder writes from Get-BranchInfo -- while 'Type of change' held the canonical type
        # ('Feat'), and CHANGELOG.md is full of those. Matching exactly would have reported every new entry
        # as carrying a type this repo does not produce, which is a refusal at the PR for writing down
        # exactly what the form asked for.
        $canonical = @($known | Where-Object {
            $_ -and ([string]$_).ToLowerInvariant() -eq $result.Type.ToLowerInvariant()
        })
        if ($canonical.Count -gt 0) { $result.Type = [string]$canonical[0] }
        if ($repoTypes.Count -gt 0 -and $repoTypes -notcontains $result.Type) {
            $result.Error = "'$($result.Type)' is not a change type this repo produces -- use one of: $($repoTypes -join ', ')."
        }
        return $result
    }

    $bodyOutside = Get-EntryTextOutsideFences -EntryText $EntryText
    $headingLine = @($bodyOutside -split '\r?\n' | Where-Object { $_ -match '^#{2,6}\s' })

    # THE BRANCH PREFIX IN THE HEADING, WHICH IS WHERE THE TYPE LIVES SINCE AUGUST 16, 2026. The 'Branch
    # type' section is no longer written: it held the prefix of the branch the heading beside it already
    # names, which is one fact in two places -- the shape this file exists to prevent. So the type is read
    # off '## Branch `feat/x` changelog' instead.
    #
    # THIS RUNS BEFORE THE MIDDOT FALLBACK AND AFTER THE SECTION, and that order is the whole compatibility
    # story. An entry that still declares the section wins on it (every entry in CHANGELOG.md and in every
    # consumer's tree does); an entry from the pre-dossier format falls through to its heading field. Only a
    # NEW entry, which has neither, reaches this. Getting the order wrong would not error -- it would file
    # entries under a type nobody wrote, which is the silent direction.
    #
    # Deliberately keyed on the PREFIX rather than on Get-BranchInfo: this lib is loaded standalone by the
    # fold, branch-info.ps1 is repo-owned and does not travel into the plugin mirror, and a consumer whose
    # table is unreachable must still get a type off its own entries. Get-ReleaseChangeTypes already falls
    # back to the canonical four for exactly this reason, and the match below is case-insensitive against
    # whichever list it returns.
    # ONLY OFF A CHANGELOG HEADING, AND THAT GUARD IS A MEASURED DEFECT RATHER THAN caution. The two branch
    # files open with the same shape and differ by one word -- '## Branch `feat/x` changelog' against
    # '## `feat/x` progress' -- so a prefix read off "any heading with a branch in it" reads a STEP LIST as
    # declaring a type. Test-EntryDeclaresShape ends on this function, so that made every step list an
    # entry: exactly the confusion the two-file split exists to remove, reintroduced from underneath.
    # Caught by that suite on the first run. The title word comes from the wording, so a repo that
    # translated it is matched by its own word rather than by the English one.
    # AND EVERY WORD THAT TITLE HAS EVER HAD, which is the same "recognise both, write one" rule the
    # section headings live by. It became 'deployment' on August 19, 2026, and 'changelog' is the word in
    # the heading of every entry in CHANGELOG.md, in every consumer's tree and on every branch in flight.
    # Reading only the current word would make all of those declare no type -- and since
    # Test-EntryDeclaresShape ends on this function, it would make them stop being entries at all.
    $clTitles = @(@([string](Get-BranchFileWording).ChangelogTitle) + @(Get-BranchFileRetiredChangelogTitles) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($headingLine.Count -gt 0 -and $known.Count -gt 0 -and $clTitles.Count -gt 0) {
        # TWO SHAPES, ONE WRITTEN, and the guard above survives both. Today's heading leads with the title
        # and a colon -- '## DEPLOY: `feat/x-v1`' -- while every entry written before August 23, 2026 puts
        # the branch first and the title last. What keeps a STEP LIST from reading as an entry is unchanged:
        # its own heading says 'Development', which is not one of these titles, in either position.
        # THREE SHAPES SINCE #1335, and the guard is still the title word. Today's heading is unbackticked
        # -- '### DEPLOY: feat/x' -- and the prefix is read up to the first slash exactly as before; the
        # backticked title-first form and the pre-August-23 branch-first form are both still read, because
        # every entry already in CHANGELOG.md and on every branch in flight carries one of them. What keeps
        # a STEP LIST from reading as an entry is what it always was: its own heading carries no title word
        # at all -- since #1335 it carries nothing but the branch name.
        $titleAlt = ((@($clTitles) | ForEach-Object { [regex]::Escape([string]$_) }) -join '|')
        $branchRx = '(?:(?:' + $titleAlt + '):\s+([^\s`/]+)/[^\s`]*)' +
            '|(?:(?:' + $titleAlt + '):\s*`([^`/]+)/[^`]*`)' +
            '|(?:`([^`/]+)/[^`]*`\s+(?:' + $titleAlt + ')\b)'
        if ($headingLine[0] -match $branchRx) {
            # Whichever of the three alternatives matched -- the unmatched groups are empty, not absent,
            # because all three are capture groups in one alternation.
            $prefix = (@($Matches[1], $Matches[2], $Matches[3]) | Where-Object { $_ } | Select-Object -First 1)
            $prefix = ([string]$prefix).Trim()
            $canonical = @($known | Where-Object {
                $_ -and ([string]$_).ToLowerInvariant() -eq $prefix.ToLowerInvariant()
            })
            if ($canonical.Count -gt 0) {
                $result.Type = [string]$canonical[0]
                $result.Declared = $true
                $result.Raw = $prefix
                return $result
            }
            # AN UNKNOWN PREFIX FALLS BACK TO THE REPO'S OWN ANSWER (#410), and this is where that seam went
            # when the 'Branch type' section was retired. The scaffolder used to write Get-EntryFallbackType
            # into that section for a branch whose prefix the table does not know -- 'wip/x', a consumer's
            # own convention -- and with the section gone the seam would have quietly stopped mattering:
            # every such entry would reach the release documents with no type at all. It is the READER's
            # answer now, which also makes it right for entries the scaffolder never touched.
            #
            # Declared stays TRUE, exactly as the written section made it: the repo has answered, it simply
            # answered by rule rather than by prefix. Raw keeps the prefix that was actually on the branch,
            # so a gate quoting it back names the thing the author typed.
            # WITH A BUILT-IN DEFAULT, because the seam is optional and this reader must not depend on it.
            # new-branch.ps1 held exactly this pair -- 'Chore' unless repo-config says otherwise -- and
            # baked the answer into the file. A reader that only honoured the seam would give a repo
            # without a repo-config.ps1 no type at all, which is every bare consumer and every fixture:
            # strictly less than the writer used to manage, and silent about it.
            $fallback = $script:EntryFallbackTypeDefault
            if (Test-FunctionDefined 'Get-EntryFallbackType') {
                $v = Get-EntryFallbackType
                if ($v) { $fallback = [string]$v }
            }
            if ($fallback) {
                $result.Type = [string]$fallback
                $result.Declared = $true
                $result.Raw = $prefix
                if ($repoTypes.Count -gt 0 -and $repoTypes -notcontains $result.Type) {
                    $result.Error = "'$($result.Type)' is not a change type this repo produces -- use one of: $($repoTypes -join ', ')."
                }
                return $result
            }
        }
    }

    # Pre-format fallback: the type as a middot field in the heading.
    $md = [char]0x00B7
    if ($headingLine.Count -gt 0 -and $known.Count -gt 0) {
        $fields = @(($headingLine[0] -replace '^#+\s+', '') -split "\s*$md\s*")
        # The LAST matching field wins, which resolves an entry whose title IS a type name
        # ('## #12 <midDot> Fix <midDot> Fix') -- the same rule the retired heading parser used.
        for ($i = $fields.Count - 1; $i -ge 0; $i--) {
            $candidate = $fields[$i].Trim()
            if ($known -contains $candidate) {
                $result.Type = $candidate
                $result.Declared = $true
                $result.Raw = $candidate
                return $result
            }
        }
    }
    return $result
}

function Add-EntrySection {
    <#
        Private: one section of the entry -- the H4 heading, its guidance comment directly underneath, and
        the value (if any) under that. Appends to the caller's list.

        THE COMMENT SITS TIGHT AGAINST THE HEADING, with no blank line between them, and that is the
        template's shape rather than a preference: a hint belongs to the heading it explains, and the blank
        line goes after the pair. The progress file spaces two of its sections the other way, which is why
        this is per-file layout stated at the call site rather than a rule derived here.

        A HELPER RATHER THAN SIX COPIES. The sections differ only in their three inputs, and the blank lines
        between them are exactly the kind of difference nobody notices until two of them disagree and a
        byte-exact template check reports drift for a reason no one can see.

        -WithGuidance IS OFF BY DEFAULT, AND ONLY THE TEMPLATE TURNS IT ON (Dave, August 7, 2026). The file
        a branch actually gets carried no comments at all: the templates under branch/templates/ were the
        reference you consulted, and duplicating that reference into every working file made the thing you
        write in mostly form text.

        THAT DECISION WAS REVERSED ON AUGUST 23, 2026, and the switch is gone with it: -WithGuidance is passed
        unconditionally now. Inbound #810 measured what the bare file cost -- an author met the guidance in
        the neighbouring file or not at all -- and the merge that removed the neighbour removed the choice.
        What still keeps a FINISHED entry clean is that the guidance renders only where a section is
        UNANSWERED, and that the fold strips comments on the way to CHANGELOG.md.
    #>
    param(
        [Parameter(Mandatory)]$Lines,
        [Parameter(Mandatory)][string]$Key,
        [AllowEmptyString()][string]$Value = '',
        [AllowEmptyString()][string]$Stamp = '',
        [switch]$WithGuidance
    )
    $Lines.Add((Get-EntrySectionHeading -Key $Key -Stamp $Stamp))
    if ($WithGuidance) {
        $all = Get-EntryGuidance
        $guidance = @()
        if ($all.PSObject.Properties[$Key]) { $guidance = @($all.PSObject.Properties[$Key].Value) }
        foreach ($line in (Format-EntryGuidanceComment -Lines $guidance)) { $Lines.Add($line) }
    }
    if ($Value) {
        $Lines.Add('')
        foreach ($line in ($Value -split '\r?\n')) { $Lines.Add($line) }
    }
    $Lines.Add('')
}

function Format-EntryBlock {
    <#
        The whole entry as an array of LINES: the H3 DEPLOY heading, then its H4 sections in order.

        IT IS A SECTION OF A DOCUMENT SINCE AUGUST 23, 2026, NOT A DOCUMENT. Format-Development writes
        the branch's plan and then calls this for its fourth phase -- so the entry is produced by one
        formatter and the file around it by another, which is what lets the fold take this block verbatim
        without holding a second definition of the entry format.

        THE HEADING NAMES THE BRANCH, NOT THE CHANGE (Dave, August 6, 2026) -- '## DEPLOY: `feat/x-v1`',
        title first since August 23 and the branch first before that. What the heading used to hold has its
        own section: the PR title, inside 'Pull Request'. This block is still pasted verbatim into
        CHANGELOG.md at the merge, so that is what lands there; Dave was offered a fold that derives a
        slimmer block instead and declined it, on the record, before this was built. See
        $script:EntrySectionDefaults for the reasoning.

        ONE FORMATTER FOR THE WRITER AND THE MIGRATION, which is why it takes pieces rather than assembling
        prose. new-branch.ps1 calls it with empty fields and no rows; a migration calls it with real
        ones. Two assemblers would drift, and the parser reads what this writes.

        $TitleSuffix is the MIGRATION path's way of putting something of its own beside the heading. Empty
        for the scaffolder and for the trunk copy, both of which are identified by the branch name the
        heading already carries.
    #>
    param(
        [AllowEmptyString()][string]$Branch = '',
        [string]$Description = '',
        [string]$Type = '',
        [string]$Body = '',
        $ImpactRows = @(),
        [string]$TitleSuffix = '',
        # PLACEHOLDER TEXT WHERE A FACT DOES NOT EXIST YET -- the merge stamp on the Pull Request heading.
        # It replaces -Template (August 23, 2026): the guidance comments are unconditional now, so the only
        # thing that separated the reference from a working file was which stamps it could honestly show.
        # True for the copy on the trunk, false for the file a branch is handed.
        [switch]$Placeholder
    )
    # THE CREATION STAMP IS NOT IN THIS HEADING ANY MORE (Dave, August 19, 2026). It moved here on
    # August 16 as the last remnant of the retired 'Branch ID' section, and moved on three days later to
    # the cycle file, which is the document the stamp is about: created with the branch, reset with the
    # merge. What this heading carries is the delivery, and the date a delivery has is the merge date the
    # fold writes into the Pull Request section -- so an entry stating two dates that mean different
    # things is one confusion fewer.
    #
    # THE '(template)' MARKER STAYS GONE, retired with the stamp's arrival and not revived by its
    # departure: the placeholder branch token '<prefix>/<short-name>' marks the template on its own, and
    # the reader who needs the word has the file's path.
    #
    # -Id IS GONE FROM THIS FUNCTION rather than left accepted and unread, so a caller still passing one
    # fails loudly instead of watching its stamp vanish. -TitleSuffix stays: it is the MIGRATION path's
    # way of putting something of its own beside a heading, and it is what the stamp used to fill.
    # Each line appended on its own statement, NOT as @(<expr>, '') -- the comma operator binds looser than
    # '+', so `@(('#'*2) + ' ' + $Title, '')` concatenates the string with the ARRAY ($Title, '') and joins
    # it with a space. That produced '## A real title ' with a trailing space and no blank line after it,
    # which is well-formed markdown and therefore invisible until a parser expecting the blank line fails.
    # Measured on this function's first run.
    $lines = New-Object System.Collections.Generic.List[string]
    $wording = Get-BranchFileWording
    # THE MERGE STAMP BELONGS TO THIS HEADING SINCE AUGUST 23, 2026 (Dave). It sat on the 'Pull Request'
    # section heading for four days; it is the date the change LANDED, and this is the line that says what
    # landed, so the two now stand together. A migration's -TitleSuffix still wins where it is given, because
    # that caller has something of its own to put there and no merge to date.
    $headingSuffix = if ($TitleSuffix) {
        $TitleSuffix
    } elseif ($Placeholder) {
        # The separator and the stamp, with NO leading space: Format-BranchFileHeadingLine puts the space in
        # front of whatever suffix it is given. Format-EntrySectionHeadingSuffix is the other convention --
        # it carries its own leading space, because Set-EntryMergeStamp appends straight onto a heading -- and
        # using it here produced a double space nobody would notice in a diff.
        "$($script:EntryIdSeparator) $(Get-EntryMergeStampTemplatePlaceholder)"
    } else { '' }
    $lines.Add((Format-BranchFileHeadingLine -Branch $Branch -Title $wording.ChangelogTitle `
        -Level $script:EntryHeadingLevel -Suffix $headingSuffix -Lead ([string]$wording.ChangelogHeadingLead)))
    $lines.Add('')

    # 'What does the change bring to main?' IS THE SIGNIFICANCE SECTION NOW (Dave, August 16, 2026). The
    # tier reasons were already the answer to this question -- each one says what the change brings AT ONE
    # REACH -- so the entry asked it twice: once as a heading with a paragraph under it, and again as a
    # heading with the same claim broken out per audience. The paragraph went and the tiers moved up.
    #
    # $Body still writes, and it is not a leftover: a MIGRATION rendering an entry from the older shape has
    # a paragraph in hand and nowhere else to put it. The scaffolder passes none, so a fresh entry opens on
    # its first tier heading exactly as the hand-designed template does.
    # AND SINCE AUGUST 19, 2026 THE QUESTION IS TIER 0'S OWN HEADING, so the significance formatter writes it
    # rather than this function -- Get-EntryTierSectionMarker -Tier 0 returns exactly this heading. Emitting
    # it here as well would put it in the document twice, with the second copy reading as a duplicate tier-0
    # declaration to the parser. Where the repo has stated no audience tier the old assembly stands: the
    # question is a heading of its own and the numbered sub-sections sit underneath it.
    # A MIGRATION'S PARAGRAPH IS HANDED TO THE FORMATTER IN THE NAMED SHAPE rather than written here, so one
    # function owns the spacing inside a section instead of two guessing at each other's. It becomes the
    # opening of tier 0's own text, which is what that paragraph always was: the answer to this question,
    # written before the tiers broke it out per reader.
    $named = Test-EntryTierSectionsAreNamed
    $preamble = ''
    if ($named) {
        $preamble = $Body
    } else {
        $lines.Add((Get-EntrySectionHeading -Key 'What'))
        $lines.Add('')
        if ($Body) {
            foreach ($line in @($Body -split '\r?\n')) { $lines.Add($line) }
            $lines.Add('')
        }
    }
    # -WithGuidance UNCONDITIONALLY, because the guidance only ever renders where a section is UNANSWERED --
    # see Format-EntrySignificanceSections. So a scaffold gets the comments and a migration re-rendering a
    # finished entry gets none of them, which is what -Template was really selecting for all along.
    foreach ($line in (Format-EntrySignificanceSections -Rows $ImpactRows -WithGuidance `
        -Tier0Preamble $preamble)) { $lines.Add($line) }
    $lines.Add('')

    # THE PR TITLE LIVES HERE SINCE AUGUST 16, 2026, WHICH IS WHERE IT ALWAYS BELONGED (Dave). The section
    # was called 'Branch title' and held no branch title: open-pr composes the PR's title from it, the
    # release documents print it, and #506 already renamed it once for saying the wrong thing. It is the PR
    # title, so it sits in the PR section -- above the PR link the fold writes underneath, and below the
    # landing stamp the fold puts on the heading.
    #
    # STILL WRITTEN EMPTY WHERE THE SCAFFOLDER CALLS. The title arrives from -Title at creation; the other
    # two facts do not exist until the merge, and a hand-written one would be a second copy of something
    # nobody has yet.
    # THE MERGE STAMP IS SHOWN ONLY IN THE TEMPLATE, as a placeholder (Dave, August 19, 2026). A real
    # entry's heading stays bare until the fold restamps it, because that moment does not exist yet -- the
    # same rule the creation stamp follows on the cycle file, one end of the branch's life later.
    # NO STAMP ON THIS HEADING ANY MORE -- it moved to the entry's own heading above (Dave, August 23, 2026).
    # Set-EntryMergeStamp writes there too, so the fold and the scaffolder agree about where the date lives.
    Add-EntrySection -Lines $lines -Key 'PullRequest' -Value $Description -WithGuidance
    return @($lines.ToArray())
}

# --- RETIRED, AUGUST 5, 2026: the changelog's tier sections ---------------------------------------
#
# $script:DefaultChangelogHeading, Resolve-ChangelogTierSections and Get-ChangelogTierSections answered
# one question -- which '## ' heading a merged entry is filed under -- for the three readers that had to
# agree about it: the fold, release-lib's parser and the release cut. CHANGELOG.md has no section
# headings any more. An entry IS an H3 and the document is an intro plus a ranked list of them, so the
# question has no subject: there is no heading to name, and therefore nothing for three readers to
# disagree about.
#
# WHAT REPLACED IT IS NOT A DIFFERENT ANSWER BUT A STRUCTURAL ONE. The fold derives the intro/list
# boundary from the first entry heading (Get-EntryHeadingLevel), and release-lib's Split-Changelog does
# the same. Both are exact-level matches, which is safe for the reason Get-EntryHeadingPattern there
# spells out: '^##' followed by whitespace cannot match an entry's own '### ' sections.
#
# THE SEAMS GO WITH THEM: Get-ChangelogTierHeadings and the older single-section Get-ChangelogHeading
# (issue #178) in the consumer's scripts/repo-config.ps1 are no longer read by anything. A consumer that
# still defines either is unaffected -- nothing calls them, so they are dead code in that repo's seam,
# and its next fold and cut behave exactly as this repo's do.
#
# Test-EntrySignificanceActive above used to infer "does this repo rank" from the number of sections this
# returned, and that is the one place the retirement was NOT a pure deletion; see its header for why the
# default had to become on rather than off.

function Test-EntryDeclaresShape {
    <#
        Pure: does this block actually look like an ENTRY? $true when it declares its named sections (any
        one of the three headings, outside fences) or a change type (the Type section, or the pre-format
        type field in its heading, via Resolve-EntryType).

        WHY THIS EXISTS, AND IT IS A MEASURED CONSUMER DEFECT RATHER THAN TIDINESS (August 5, 2026). With
        the changelog flat, every '## ' below the intro is read as one change. A consumer whose CHANGELOG.md
        still carries the pre-flat shape has section headings at exactly that level -- '## Pull Requests',
        '## Tier 2 - Pull Requests', '## Releases' -- and the updated shared scripts reach them through a
        plugin update rather than by their choosing. Measured against both shapes:

          * the single-section consumer: '## Pull Requests' parses as ONE entry swallowing all of their real
            entries, and '## Releases' as a second one -- so their entire release history is published into
            the release notes and the per-plugin CHANGELOGs as a "change", and then DELETED from
            CHANGELOG.md, because the cut keeps only the intro;
          * the consumer who had adopted the tier sections: three entries named after the three headings.

        AND NOTHING REFUSED. Every one of those blocks declares no impact, so Test-ReleaseBumpEarned reads
        the repo as never having adopted the model and reports itself INACTIVE -- correctly, by its own
        rule -- which means the release proceeds. Silent, correct-looking, and it loses data.

        SO THE PARSER REFUSES INSTEAD, and this predicate is the test it refuses on. The discriminator is
        exact rather than a heuristic: the format has two legitimate shapes and both declare something. A
        current entry carries the three named sections; a pre-format entry carries its type as a heading
        field, which is what new-branch.ps1 wrote for as long as that shape existed. A leftover
        section heading carries neither, and cannot -- it is a heading with prose under it.

        Deliberately NOT keyed on the '#NN' the fold prepends: the fold cannot reach gh on a manual merge
        and then writes a legitimate entry with no number, saying so on the console. A gate keying on the
        number would report the fold's own documented output as a defect.

        FENCE-AWARE through the readers it calls, for the reason every reader here is: an entry documenting
        this format quotes these headings inside a fence, and the entry for this very change does.

        THREE OF THE SIX SECTIONS PROVE NOTHING, AND THAT IS NEW (August 6, 2026). The dossier form gave
        branch-cycle.md the same title, 'Branch ID' and 'Branch type' headings the entry
        carries -- deliberately, they are one pair of files -- so a predicate matching ANY named section
        started answering $true for the step list. Measured immediately: the scaffold gate then judged a
        freshly written step list as an unfinished ENTRY and reported its empty description. That is the
        exact confusion the two-file split was made to remove, reappearing inside the discriminator.

        So only the sections an entry ALONE has count: the 'what does it bring' question, the significance
        block and the pull-request section -- WITH THEIR OWN RETIRED NAMES, and no others.

        THAT LAST CLAUSE IS A REPAIR, not a restatement (August 7, 2026). This read every retired name in the
        format's history, justified as "'Type of change' and the rest were written when there was one file,
        so a step list cannot be carrying one". True of every name in that list on the day it was written,
        and it stopped being true the moment 'Branch description' was retired in favour of 'Branch title':
        that name dates from AFTER the split, so the step lists of that fortnight -- on every branch in
        flight here and in every consumer -- carry it. A blanket retired list would have read those step
        lists as entries again. Retired names are inherited per section now, so a name can only ever prove
        what its own section proves. Nothing is lost by dropping 'Type of change' from this set: an entry old
        enough to carry it carries 'What does this change do?' and 'Who is this for' as well, both still here.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$EntryText)

    $body = Get-EntryTextOutsideFences -EntryText $EntryText
    $lines = @($body -split '\r?\n')
    $entryOnlyKeys = @('What', 'Significance', 'PullRequest')
    $headings = @($entryOnlyKeys | ForEach-Object {
        @((Get-EntrySectionHeadings)[$_]) + @(Get-EntrySectionRetiredNames -Key $_)
    })
    foreach ($heading in $headings) {
        if (-not $heading) { continue }
        # The tolerant tail, because 'Pull Request' carries the merge stamp once the fold has run -- and a
        # folded entry that stopped declaring its shape would be read as a leftover section heading.
        $rx = '^' + (Get-EntrySectionLevelRange) + '\s+' + [regex]::Escape([string]$heading) +
            (Get-EntrySectionHeadingTail)
        foreach ($line in $lines) {
            if ($line -match $rx) { return $true }
        }
    }
    # THE TYPE FALLBACK IS FOR THE HEADING FIELD, NOT FOR THE SECTION. Resolve-EntryType reads the section
    # first, and 'Branch type' is one of the three a step list also carries -- so on a step list it would
    # report Declared and undo the whole distinction above. Where that section is present its answer proves
    # nothing, and the entry-only sections have already had their say.
    $currentType = (Get-EntrySectionHeadings)['Type']
    if ($currentType) {
        $typeRx = '^' + (Get-EntrySectionLevelRange) + '\s+' + [regex]::Escape([string]$currentType) + '\s*$'
        foreach ($line in $lines) {
            if ($line -match $typeRx) { return $false }
        }
    }
    return [bool](Resolve-EntryType -EntryText $EntryText).Declared
}

# --- The entry's links, held against the destination its text lands at ---------------------------
#
# WHY THIS IS A QUESTION AT ALL. The entry is written as the DEPLOY section of
# dkj-policy/<branch>.md, and the fold moves its text VERBATIM into the changelog. So a
# relative link in it has to resolve from the CHANGELOG's OWN directory rather than from the one the author
# is typing in -- and where those two differ it looks wrong in front of them and only becomes right after it
# moves. The natural instinct produces the broken form, and nothing said so: reported from a consumer as
# inbound #806, where two links reading '../../scripts/...' landed at the root pointing outside the repo,
# with every gate green because their linter validated them where the file sat.
#
# AND THE DESTINATION IS A SEAM, WHICH IS THE HALF #806's REPAIR GOT WRONG BY ASSUMING (inbound #967). It
# hard-coded the repo root as the base, which was true of every repo at the time and stopped being true when
# #914 made Get-ChangelogPath isolate-by-default: a consumer's CHANGELOG.md sits in the workflow folder now,
# the SAME directory the entry is written in, so the root base demanded the one form that is dead after the
# fold and refused the form that is correct. Measured in BWJ-ecommerce/xoxowildhearts, whose own doc lint
# measures from the folder -- so the two gates disagreed and its entries avoided relative markdown links
# entirely. The base is a parameter now and the seam answers it; a repo that repoints the seam back to the
# root gets #806's behaviour unchanged, because the root is then genuinely where the text lands.
#
# THE REPORT'S REASON WAS WRONG, AND THAT CHANGED THE REPAIR. It argued that "a consumer-side linter
# structurally cannot [check this] -- it runs before the move", and proposed the fold as the only place
# that knows both paths. This repo's own lint has resolved the entry's links from the repo root since
# August 6, 2026 (check-plugin-integrity.ps1, the $entryRelsForLinks branch), and even names the base in
# its finding so the author does not "repair" a correct link by adding a '../'. So a linter can. What the
# reporting consumer lacked was not a mechanism but the RULE -- their linter is their own -- and a rule
# is what a plugin can ship.
#
# HENCE open-pr AND NOT THE FOLD, which is the opposite of what #806 asked for and the reason is the
# fold's own doctrine: a defect decidable before the merge is refused while the branch is still the only
# thing affected, because refusing an already-merged branch's fold leaves the silent half-state this repo
# has measured -- an unfolded entry on the trunk with main looking finished. The fold says exactly that
# about a missing significance score, in the same words, and this is the same kind of fault.
# A fold-time REWRITE was the report's preferred option and is declined for a second reason: the fold
# copies the entry verbatim on purpose (its own comment reads NOTHING IS STRIPPED FROM THE ENTRY HERE),
# and an author whose link is silently corrected writes the same link again into the next document --
# a release note, a PR body -- where nothing corrects it.

function Get-EntryLinkTargets {
    <#
        Pure: the relative markdown link targets in an entry, as written -- an array of strings, deduped,
        in the order they appear. External (http/https/mailto), pure-anchor ('#x') and absolute ('/x')
        targets are left out, because none of them is resolved against a directory and so none of them can
        be broken by the text moving.

        CODE AND COMMENTS ARE EXCLUDED, and this is the half that was measured rather than assumed. Over
        the last 80 revisions of this repo's own entry file a naive scan produces exactly ONE finding, and
        it is a false one: '`[PR #N](url)' inside INLINE backticks, in an entry explaining what the fold
        writes. So fences alone are not enough -- the repo's own link lint strips fenced code, inline code
        AND html comments, and its comment names this very '[PR #NN](url)' case as the finding that forced
        the third exclusion. One rule, one set -- and since #1052 one function, Get-EntryCodeSpans, which
        the cut's link rewriter reads too, so the gate that judges links and the rewriter that moves them
        cannot disagree about what counts as an illustration.

        THE ANCHOR IS DROPPED AND THE TITLE WITH IT: 'file.md#section' is judged as 'file.md', and
        'file.md "Title"' as 'file.md'. Whether the anchor exists is a different question with a different
        answer, and it is one the repo's own lint already asks; this function answers only "is there a file
        there at all", which is the question the move can change.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$EntryText)
    # The three exclusions are ONE function now (inbound #1052), because the cut needed the same set and
    # could not use a stripper -- it has to hand the entry back with the illustrations still in it.
    $scan = Remove-EntryCodeSpans -EntryText $EntryText

    $targets = New-Object System.Collections.Generic.List[string]
    foreach ($m in [regex]::Matches($scan, '\[(?:[^\]]*)\]\(([^)]+)\)')) {
        $target = $m.Groups[1].Value.Trim()
        # A markdown link may carry a title after the path: ](path "Title"). The path is the first field.
        $target = (($target -split '\s+', 2)[0]).Trim()
        if (-not $target) { continue }
        if ($target -match '^(https?:|mailto:|#|/)') { continue }
        # The anchor is a question about the target's contents, not about where the target is.
        $target = ($target -split '#', 2)[0]
        if (-not $target) { continue }
        if (-not $targets.Contains($target)) { $targets.Add($target) }
    }
    return @($targets)
}

function Get-PathRelativeToDirectory {
    <#
        Pure: $FullPath written as a forward-slashed relative path FROM $Directory, with '../' segments
        where the target lies beside that directory rather than under it. Both arguments are absolute
        filesystem paths. Returns '' where there is no relative form at all -- a different drive.

        WHY THIS IS NOT A SUBSTRING, which is what it replaced (inbound #967). While the destination was
        always the repo root, every target that resolved at all resolved UNDERNEATH it, so the answer was
        the tail of the path and a substring reached it. A destination that is a SUBDIRECTORY has a second
        case -- a target beside it rather than under it -- and there a substring silently produces nothing,
        which in this file means a finding reported with no suggested repair.
    #>
    param(
        [Parameter(Mandatory)][string]$FullPath,
        [Parameter(Mandatory)][string]$Directory
    )
    $dirFull  = [System.IO.Path]::GetFullPath($Directory).TrimEnd('\', '/')
    $fileFull = [System.IO.Path]::GetFullPath($FullPath)
    $dirParts  = @($dirFull  -split '[\\/]+' | Where-Object { $_ })
    $fileParts = @($fileFull -split '[\\/]+' | Where-Object { $_ })
    $i = 0
    while ($i -lt $dirParts.Count -and $i -lt $fileParts.Count -and
           [string]::Equals($dirParts[$i], $fileParts[$i], [System.StringComparison]::OrdinalIgnoreCase)) {
        $i++
    }
    # Nothing shared at all means two roots -- another drive, a UNC share -- and no number of '../' reaches
    # across that. '' is the same answer the caller gives for a target it cannot name a form for.
    if ($i -eq 0) { return '' }
    $segments = New-Object System.Collections.Generic.List[string]
    for ($u = $i; $u -lt $dirParts.Count;  $u++) { $segments.Add('..') }
    for ($d = $i; $d -lt $fileParts.Count; $d++) { $segments.Add($fileParts[$d]) }
    return ($segments -join '/')
}

function Get-EntryLinkFindings {
    <#
        The entry's relative links that do not resolve from the DESTINATION its text lands in -- an array of
        objects with Target (as written) and Suggested (the same link rewritten for that destination, or ''
        where that cannot be worked out). Empty array means every relative link in the entry will still
        point somewhere once the text sits in the changelog.

        -DestDirRel RATHER THAN THE ENTRY'S OWN DIRECTORY, and that IS the check: the destination is the
        base. A link validated where the file sits is the failure this exists to catch, not the check
        itself. It defaults to '' -- the repo root -- which is what this repo's own changelog is, and what
        every consumer's was until #914; the section note above carries why it is a parameter and not
        $RepoRoot any more.

        IT SUGGESTS THE REPAIR because the finding alone points the wrong way. An author told '../../scripts/x
        does not exist' reaches for another '../', which is how a correct link gets broken -- the repo's own
        link lint had to learn the same lesson on August 19, 2026 and now names the base it resolved from.

        AND IT TRIES TWO BASES FOR THAT GUESS, in likelihood order: the entry file's OWN directory, then the
        repo root. One base was enough while the destination was always the root -- the only mistake possible
        was writing the link as it read in front of you. With an isolated changelog there is a second, and it
        is the one this repo's own guidance asked for until #967: a ROOT-relative link, correct everywhere
        until the destination moved into the workflow folder. Offering no suggestion there would leave the
        consumer who actually followed the instruction with the one finding that names no way out.

        A target that resolves from neither base is simply a typo and gets no guess.

        AND ONLY WHERE THE TARGET IS INSIDE THE REPO, a bound kept from the original rather than a new one:
        a link resolving out of the tree gets no suggestion, because the form that would reach it from the
        destination is not one anybody should be told to write.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$EntryText,
        [Parameter(Mandatory)][string]$RepoRoot,
        # Where the entry file itself sits, repo-root-relative -- used ONLY to work out the suggestion.
        # Defaults to the branch directory this format uses, so a caller that has no reason to care does
        # not have to supply it.
        [string]$EntryDirRel = '',
        # Where the entry's TEXT lands, repo-root-relative: the directory of the changelog the fold writes
        # into. '' is the repo root, which is the answer for a repo that publishes plugins and for any repo
        # that repoints Get-ChangelogPath back there.
        [string]$DestDirRel = ''
    )
    if (-not $EntryDirRel) { $EntryDirRel = (Get-BranchFilePaths).Directory }
    $destDir = if ($DestDirRel) { Join-Path $RepoRoot ($DestDirRel -replace '/', '\') } else { $RepoRoot }
    $findings = @()
    foreach ($target in (Get-EntryLinkTargets -EntryText $EntryText)) {
        $fromDest = Join-Path $destDir ($target -replace '/', '\')
        if (Test-Path -LiteralPath $fromDest) { continue }
        # Does it resolve from somewhere an author plausibly meant? Then they wrote a link that is right by
        # one convention and wrong at the destination, which is the whole reported failure -- and the form the
        # destination needs is computable, so it is named instead of left to be worked out. The file's own
        # directory first, because that is the instinct the gate exists to catch; the repo root second,
        # because that is what this workflow's own guidance asked for until #967.
        $suggested = ''
        $rootFull = (Resolve-Path -LiteralPath $RepoRoot).Path
        $bases = New-Object System.Collections.Generic.List[string]
        $bases.Add((Join-Path $RepoRoot ($EntryDirRel -replace '/', '\')))
        if (-not $bases.Contains($RepoRoot)) { $bases.Add($RepoRoot) }
        foreach ($base in $bases) {
            $candidate = Join-Path $base ($target -replace '/', '\')
            if (-not (Test-Path -LiteralPath $candidate)) { continue }
            $full = (Resolve-Path -LiteralPath $candidate).Path
            # Outside the tree gets no suggestion -- the bound kept from the original, and the reason the
            # loop cannot simply take the first base that resolves.
            if (-not $full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
            $suggested = Get-PathRelativeToDirectory -FullPath $full -Directory $destDir
            if ($suggested) { break }
        }
        $findings += [pscustomobject]@{ Target = $target; Suggested = $suggested }
    }
    return @($findings)
}

function Get-EntryScaffoldFindings {
    <#
        Pure: given an entry file's text, returns the scaffold markers it still contains -- an array of
        objects with Marker (the literal string found) and Label (which of the three it is). Empty array
        means the entry has been written rather than merely scaffolded.

        WHY A SUBSTRING MATCH AND NOT A WHOLE-LINE ONE. The measured case (v3.2.0, three entries) was
        not an untouched scaffold: the author kept the body heading and appended a status behind it --
        "**To do / where I left off:** done -- lint gate green". That is a progress note, and it read as
        one in the release notes and in the per-plugin CHANGELOGs that travel to consumers. A whole-line
        match would have passed all three.

        FENCED CODE IS EXCLUDED, for the same reason the entry-heading check excludes it: an entry may
        legitimately quote the scaffold inside a fence while documenting this very mechanism -- this
        repo's own docs do -- and a guard that cannot tell a quote from the real thing gets disabled.

        AND SINCE THE DOSSIER FORM IT ALSO MEASURES EMPTINESS, which is the half that replaced the markers
        rather than joining them (Dave, August 6, 2026). The scaffold no longer writes a visible 'TODO:'
        anywhere: every field is a heading with a guidance COMMENT under it, so an untouched entry has empty
        sections rather than recognisable text. A gate that only matched strings would have gone quiet on
        exactly the entry it exists to stop -- silently, reporting success, which is this repo's worst
        failure mode for a guard.

        WHAT IS MEASURED IS STRICTLY MORE THAN WHAT THE MARKERS CAUGHT. An empty section is reported whether
        the author never touched it OR deleted the placeholder instead of answering it, and the comments are
        stripped first so leaving the guidance standing is not mistaken for an answer -- which it must not
        be, because the fold strips those comments and the section would land in CHANGELOG.md blank.

        THE STRING MARKERS STAY, and not out of sentiment: every branch in flight, here and in every
        consumer, carries an entry written by the older scaffolder right now, and those reach this gate
        through a plugin update rather than by choosing to. Recognise both, write one.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$EntryText,
        [Parameter(Mandatory)][pscustomobject]$Wording
    )
    $body = Get-EntryTextOutsideFences -EntryText $EntryText

    $checks = @(
        @{ Label = 'the placeholder title';   Marker = $Wording.Title },
        @{ Label = 'the scaffold body heading'; Marker = $Wording.BodyHeading },
        @{ Label = 'the fallback body';       Marker = $Wording.BodyPlaceholder }
    )
    # The strings the scaffolder used to write, still refused. See $script:EntryScaffoldLegacyMarkers.
    foreach ($legacy in $script:EntryScaffoldLegacyMarkers) {
        $checks += @{ Label = 'a retired scaffold placeholder'; Marker = $legacy }
    }

    $findings = @()
    foreach ($p in $checks) {
        if (-not $p.Marker) { continue }
        if ($body.Contains($p.Marker)) {
            $findings += [pscustomobject]@{ Label = $p.Label; Marker = $p.Marker }
        }
    }

    # A 'Plugins:' LINE IS THE FOLD'S TO WRITE, NEVER THE AUTHOR'S (issue #1015, August 28, 2026). It is
    # derived from the PR's touched files and appended by fold-changelog-entry.ps1 at the merge -- the
    # same model Get-EntryPrTitle already encodes by skipping this line and the '[PR #N]' footer when it
    # reads the title. An author who mirrored the folded-entry shape into the '#### Pull Request' section
    # left a second one behind, and the fold's unconditional append doubled it: 22 reached the changelog,
    # 8 in one cut. Refused on any entry shape -- it is wrong before the format existed too -- so it sits
    # here rather than under the shape-gated half below. The fold still strips a stray one as a net for a
    # branch opened before this gate; this is where the author is told.
    if ([regex]::IsMatch($body, '(?m)^Plugins:\s')) {
        $findings += [pscustomobject]@{
            Label  = "a 'Plugins:' line -- the fold writes this at the merge, delete it"
            Marker = ([regex]::Match($body, '(?m)^Plugins:[^\r\n]*')).Value
        }
    }

    # THE EMPTINESS HALF. Only judged on an entry that actually uses the named sections -- a pre-format entry
    # has none of them, and reporting all of it as unanswered would refuse every branch whose entry predates
    # this shape. Test-EntryDeclaresShape is the same discriminator the parser uses, so the two cannot
    # disagree about which shape they are looking at.
    if (Test-EntryDeclaresShape -EntryText $EntryText) {
        # PullRequest is deliberately absent: the fold fills it, so it is empty by design until the merge.
        # Id and Type are written by the scaffolder itself, so an empty one is a scaffolder fault rather
        # than an author's, and refusing the author for it would be pointing at the wrong person.
        # ONLY A SECTION THE ENTRY ACTUALLY HAS. An entry written before the dossier form carries no
        # title section at all -- its title WAS the heading -- and reporting the absence would refuse every
        # branch in flight for having been correct under the format of the day. See Test-EntryHasSection.
        # THE TITLE IS MEASURED WHEREVER IT LIVES (August 16, 2026). It had a section of its own until then,
        # and the loop below caught an empty one; it is the first line of 'Pull Request' now, and that
        # section is NOT empty by design any more -- so the old exclusion would have let an untitled entry
        # through, and open-pr would have opened a PR titled with nothing but its branch type. Asked through
        # Get-EntryPrTitle, which reads both homes and skips the two lines the fold writes underneath.
        #
        # ONLY WHERE THE ENTRY HAS NEITHER TITLE SECTION FILLED. An entry still carrying 'Branch title' is
        # judged by the loop below, on its own heading, so the author is pointed at the section they
        # actually have rather than at one their file does not contain.
        if ((-not (Test-EntryHasSection -EntryText $EntryText -Key 'Description')) -and
            (Test-EntryHasSection -EntryText $EntryText -Key 'PullRequest') -and
            (-not (Get-EntryPrTitle -EntryText $EntryText))) {
            $findings += [pscustomobject]@{
                Label  = 'an unanswered section'
                Marker = Get-EntrySectionHeading -Key 'PullRequest'
            }
        }
        foreach ($key in @('Description', 'What')) {
            if (-not (Test-EntryHasSection -EntryText $EntryText -Key $key)) { continue }
            if (-not (Get-EntrySectionAnswer -EntryText $EntryText -Key $key)) {
                $findings += [pscustomobject]@{
                    Label  = 'an unanswered section'
                    Marker = Get-EntrySectionHeading -Key $key
                }
            }
        }
        # Every tier the entry claims owes a reason, tier 0 included -- which is where the retired
        # why-placeholder used to be caught. Get-EntryImpactFindings asks this of tiers 1 and up only,
        # because its subject is the RANKING and tier 0 is never ranked; the reason is still content.
        $impact = Resolve-EntryImpact -EntryText $EntryText
        foreach ($row in @($impact.Rows)) {
            if ($row.Error) { continue }
            if (-not $row.Why) {
                # A REASON ON THE WRONG SIDE OF THE SCORE IS NOT A MISSING REASON (inbound #596), and
                # saying which of the two it is IS the repair. The refusal is correct either way -- the
                # fold would publish that tier empty -- but 'no reason' is the one thing an author looking
                # at three written paragraphs can see is untrue, so the natural next move is to distrust
                # the gate rather than to move the text. Measured there: three tiers, all three answered,
                # all three reported as unanswered, and it took reading this file line by line to find out
                # why. The data to tell them apart was already in hand; it just was not being kept.
                # #1172 folds in the second placement -- a reason trailing on the score line itself.
                $below = if ($row.PSObject.Properties['WhyBelowScore']) { [string]$row.WhyBelowScore } else { '' }
                $findings += [pscustomobject]@{
                    Label  = if ($below) {
                        "a tier whose reason sits BELOW its $($script:EntryScoreLabel) line, or trails on it -- move it above"
                    } else {
                        'a tier with no reason'
                    }
                    Marker = Get-EntryTierSectionLabel -Tier ([int]$row.Tier)
                }
            }
        }
    }
    return $findings
}

# --- THE BRANCH'S OWN DOCUMENT: one file, two halves, and a reset state --------------------------
#
# Dave, August 6, 2026 for the split; August 23, 2026 for the merge. A branch's working state lives in ONE
# known file instead of a file named after the branch in the repo root, and it answers two different
# questions for two different readers as two sections of that file:
#
#   ## PLAN / ## CREATE / ## TEST      what still MUST HAPPEN   -- for whoever is working on the branch
#   ## DEPLOY: `<branch>`              what the change DOES     -- for whoever reads CHANGELOG.md later
#
# WHAT THE SPLIT FIXED, AND WHAT IT THEN COST. The root entry file did both jobs at once: new-branch.ps1
# scaffolded it with a body heading that literally read '**To do / where I left off:**', and open-pr's
# scaffold gate refused to ship while that heading survived. So one file was today's to-do list AND
# tomorrow's changelog prose, which is why "replace this whole block before the PR" had to be a written
# instruction rather than something the format made obvious. Two files made it obvious -- and meant the plan
# a branch is working through and the claim it will make were never on one screen.
#
# THE MERGE IS SAFE BECAUSE THE SEPARATION IS STRUCTURAL NOW. The entry is a NAMED SECTION carrying the
# branch in its heading: Split-Development is the one place that finds the boundary, the fold takes
# that section, Get-BranchProgressFindings counts only above it, and Get-EntryScaffoldFindings reads only
# inside it. Nothing is doing two jobs at once, so nothing has to be replaced before the PR.
#
# ONE NAME PER BRANCH SINCE SEPTEMBER 3, 2026 (#1255), AND THE FIXED NAME IS WHY. This block used to argue
# the other way: "it cannot collide -- git already tracks this file per branch, so each branch carries its
# own version of the same path and a checkout swaps them." That is true of CHECKOUT and says nothing about
# MERGE, which is where the collision actually lives. Two branches that each write the same path are an
# add/add conflict the moment one of them lands, and every branch that has already merged the trunk once is
# a modify/delete conflict instead -- so the trunk's copy conflicts every OTHER open PR without anybody
# touching those branches.
#
# WHAT THAT COST, measured here on September 2, 2026 and the reason this reversed. A conflicting PR has no
# refs/pull/<n>/merge, so GitHub creates no check suite at all; lint-en-tests is a required check, and a
# check that was never created can never go green. The PR cannot merge, so it stays open, so the next merge
# conflicts it again. All four open PRs were conflicting and this document was the ONLY conflicting path in
# three of them. Resolving a lap by merging the trunk in does not end it: it moves the branch from add/add
# into modify/delete, which is why each lap bought another full CI cycle and never converged.
#
# AND THE FOLD IS NOT THE FIX, which was measured before this was written rather than assumed. Simulating a
# completed fold -- the trunk with this document deleted -- against all four open PRs cleared the two
# add/add cases and left the two modify/delete cases conflicting. Deleting the trunk copy changes the
# conflict's SHAPE, not its existence.
#
# THE HALF OF THE OLD REASONING THAT STILL HOLDS IS HONOURED HERE. "It cost a repo root that filled up with
# other people's work" was the real defect of the pre-August-2026 per-branch form, and it was about the
# ROOT, not about the filename. These documents live in the workflow's own folder, so the root is untouched.
#
# AND THE TRAP THE OLD FORM SET IS DELIBERATELY NOT REBUILT. That form coupled the FOLD to guessing the
# branch out of the filename, which is what once banned a '-v2' suffix (see Test-BranchName's docstring).
# Here the filename is a WRITE convention and a read CANDIDATE, never the authority: Resolve-BranchFilePath
# still resolves on which file DECLARES this branch, and it discovers the candidates by pattern rather than
# by trusting a name to be right. A renamed branch, or a document somebody wrote by hand under a name that
# does not match, still resolves -- and '-v2' still costs nothing.
#
# THE RESET STATE IS WHAT LIVES ON THE TRUNK, and it is load-bearing rather than cosmetic. It is the SAME
# document with the TRUNK's name in its heading -- which is what Test-BranchChangelogIsFilled reads, so the
# trunk state cannot be mistaken for an unfolded entry and folding twice is impossible rather than merely
# unlikely. That test used to be the heading LEVEL, and one document cannot use it: its '#' is its title in
# both states.
#
# AND THE ENTRY SECTION IS NOTHING BUT THE ENTRY BLOCK -- no preamble, no warning inside it. That is Dave's
# requirement restated: the block must be copy-pasteable into CHANGELOG.md in one go. Anything wrapped
# around it would have to be stripped by whoever pastes it, which is the manual step the format exists to
# remove.

$script:BranchFileDefaults = [ordered]@{
    # The branch name is prepended to these by Format-BranchFileHeader -- '# `feat/x` cycle' -- so they
    # are the suffix rather than the whole title. Lowercase for that reason.
    #
    # 'cycle' AND 'deployment' SINCE AUGUST 19, 2026 (Dave), where they were 'progress' and 'changelog'.
    # Each file now says what it IS rather than which file it ends up in: one carries the branch through
    # its cycle -- plan, create, test, and the deploy that belongs to the other document -- and the other
    # IS the deployment, the part that travels to main. 'changelog' named a destination, which is how the
    # entry kept being read as a fragment of CHANGELOG.md rather than as the claim this branch makes.
    # THE FILENAMES MOVED WITH THE WORDS; Get-BranchFilePaths says which old ones are still read.
    # 'DEPLOY' AND 'development cycle' SINCE AUGUST 23, 2026 (Dave), where they were 'deployment' and
    # 'cycle'. The two documents became one: 'development cycle' is what the file IS, and 'DEPLOY' is its
    # fourth phase -- the one that travels to main. UPPERCASE because it is a phase heading standing beside
    # PLAN, CREATE and TEST, which is the thing it now is; the three of them are the arc and this is its end.
    ChangelogTitle = 'DEPLOY'
    # CAPITALISED, because it now OPENS the heading rather than trailing after the branch name. 'DEPLOY'
    # stays uppercase for the same reason it was: it is a phase heading standing beside PLAN, CREATE and TEST.
    #
    # 'Development' SINCE AUGUST 27, 2026 (Dave, issues #963 and #958), where it was 'Development cycle'.
    # The fourth rename of these two words and the smallest: shorter, and 'cycle' was doing no work the
    # four phase headings underneath it were not already doing. The FILENAME MOVED WITH THE WORD again --
    # Get-BranchFilePaths says which old ones are still read -- and the heading needs no reader change,
    # because Get-BranchFileDeclaredBranch has matched anything up to the first backtick since August 23.
    #
    # #963 ASKED FOR TWO DIFFERENT WORDS and that is worth recording rather than smoothing over: its title
    # said 'Development', its body said 'Developing'. Dave settled it on 'Development' the same day, which
    # is also #958's word, so the file, the heading and the identifiers all say one thing.
    #
    # NO ProgressTitle ANY MORE (Dave, #1335, September 3, 2026). The document's heading is the branch name
    # and nothing else -- '## feat/x' -- so there is no title left to word. The key is GONE rather than set
    # to an empty string, which is this map's own rule for a retired setting: a consumer who overrode it
    # gets a script-contract failure naming it, instead of a translation that silently stops being printed.
    # ChangelogTitle above is untouched: the entry's heading still leads with 'DEPLOY:'.
    # The word before the backticked branch name in the ENTRY's heading only -- '## Branch `feat/x`
    # changelog'. EMPTY SINCE THE RENAME (Dave, August 19, 2026): the lead word existed to stop
    # '## `feat/x` changelog' reading as a changelog OF that branch, and '## `feat/x` deployment' says
    # what it is without help. Kept as a knob rather than deleted -- a repo whose word needs one sets it,
    # and Get-BranchFileDeclaredBranch reads both shapes.
    ChangelogHeadingLead = ''
    BranchLabel    = 'Branch'
    # NO StepsHeading ANY MORE (Dave, August 19, 2026). The steps used to sit under their own '### Steps'
    # heading with the phases as H4s beneath it. The phases ARE the sections now, at the cycle file's own
    # section level, and the guidance
    # that explained the list stands directly under the file's own heading. The wrapper bought nothing:
    # this file IS the step list, so a heading announcing one wrapped the whole document. The key is gone
    # rather than left pointing at nothing, so a consumer who overrode it gets a script-contract failure
    # instead of a silently ignored setting.
    # NO NotesHeading ANY MORE (Dave, August 23, 2026). 'Where I left off' asked the author to write down
    # what the step list already says: an unticked box IS where you left off, and a second account of it beside
    # the list is one that can disagree with the list. Removed rather than left pointing at nothing, so a
    # consumer who overrode it gets a script-contract failure instead of a silently ignored setting.
    #
    # WHAT IT WAS ALSO USED FOR IS PARKING, and that keeps working: new-branch -Park passed its status text
    # here as -Intent. The intent now goes where a reader of a parked branch actually looks -- see
    # Format-Development, which writes it under the phase the first step lives in.
    FirstStep      = 'TODO: the first step of this branch'
    # THE PHASES OF THE STEP LIST (Dave, August 14, 2026; issue #655). A branch moves through a
    # recognisable arc instead of an ad-hoc list. They are the file's own sections since August 19, 2026
    # -- H2s until the August 26 shift and H3s since -- where they were H4s under a '### Steps' wrapper,
    # which changes nothing mechanically:
    # Get-BranchProgressFindings reads lines beginning with a step mark, so a heading of any level is
    # invisible to the gate and the arc is drawn on top of an untouched mechanism.
    #
    # FOUR SINCE THAT SAME DAY, AND THE FOURTH CARRIES NO STEPS. The SDLC arc is PLAN / CREATE / TEST &
    # DEPLOY, and DEPLOY used to be absent here on the reasoning that it is not a step but the END RESULT
    # -- the part that travels to CHANGELOG.md, and therefore the other file's whole subject. That reading
    # still holds; what changed is that the arc now SHOWS the fourth phase and points at where it lives,
    # instead of leaving a reader to notice an absence. Its guidance (StepPhaseGuidance below) says to write
    # nothing under it.
    #
    # SO THE RULE THAT LOOKED ARBITRARY IS UNCHANGED: the step-list gate still refuses a step written for
    # after the merge. Post-merge is DEPLOY's territory, and DEPLOY is a different document. A DEPLOY
    # checkbox could only be unresolvable (blocking every PR, since the list must be clear before open-pr
    # will push) or a lie (ticked before it happened) -- which is exactly why the heading is a pointer and
    # not a phase you fill in.
    #
    # AN EMPTY PHASE IS NOT A FINDING. A branch with nothing to test says so by leaving that heading bare,
    # and refusing it would be exactly the ceremony CLAUDE.md warns about for the one-commit typo fix --
    # the same reason a branch with no step list at all is permitted.
    # THREE SINCE AUGUST 23, 2026, AND THE FOURTH IS STILL THERE -- it is just not written from here any
    # more. DEPLOY used to be a heading in this list with guidance telling you not to write under it, because
    # the thing it pointed at lived in the other file. There is no other file: the entry IS the DEPLOY
    # section, written by Format-EntryBlock right after these three, and it carries the branch name in its
    # heading the way an entry has to. So the arc is unchanged and one of its four phases is now produced by
    # the formatter that owns what goes in it.
    StepPhases     = @('PLAN', 'CREATE', 'TEST')
    # Which phase the scaffolded first step is written under. CREATE, because that is where a branch's
    # work actually starts once it has been planned -- and because a placeholder under PLAN would read as
    # "you have not thought about this yet", which is the one thing a fresh branch has just done.
    FirstStepPhase = 'CREATE'
    # GUIDANCE PER PHASE, for the phases that need one -- keyed by phase name, rendered in the TEMPLATE
    # only, like every other guidance block. DEPLOY is the one entry and the reason the map exists: it is
    # the phase you must NOT fill in, which is a thing the heading alone cannot say.
    #
    # Written as a complete comment block, markers and all, so Format-EntryGuidanceComment passes it
    # through byte-exact -- the same treatment the hand-written one-liners in the entry get, and for the
    # same reason: this is Dave's own spacing rather than something a rule derives.
    # EMPTY SINCE AUGUST 23, 2026, AND KEPT AS A SEAM. Its only entry was DEPLOY's 'Don't do anything here.
    # Just a link to branch-deployment' -- a pointer to a file that no longer exists, over a heading this
    # list no longer writes. The map stays because a consumer may legitimately want a hint over one of their
    # own phases, and removing the key would fail their script contract for a setting that still makes sense.
    StepPhaseGuidance = [ordered]@{}
    # NO TemplateMarker ANY MORE. The copies under branch/templates/ used to mark their heading
    # '(template)' so neither a reader nor a gate could mistake one for a real branch file. Both templates
    # now carry the placeholder branch token beside a placeholder stamp
    # ('<timestamp of the moment this branch was created>'), which marks the file at least as loudly as the
    # word did -- the entry's heading retired the marker on that reasoning on August 16, 2026, and the
    # cycle file followed it on August 19 when the stamp moved there. Gone rather than left unread, so an
    # override fails the script contract instead of doing nothing.
    # THE THREE BRANCH FIELDS ARE NOT HERE. They are sections of the entry now and both files write them
    # from Get-EntrySectionHeadings + Get-EntryGuidance -- see $script:EntryGuidanceDefaults for why one
    # source rather than two. The keys that used to hold them (TitleHeading, IdGuidance, ...) are gone
    # rather than left pointing at nothing, so a consumer overriding one gets a script-contract failure
    # instead of a silently ignored setting.
    # VISIBLE MARKDOWN, NOT A COMMENT, SINCE AUGUST 23, 2026 (Dave): comments belong in the template, and
    # the instantiated document should not restate them. So this block is a blockquote the reader actually
    # sees, and the three guidance blocks inside the DEPLOY section are EMPTY rather than moved here.
    #
    # WHY EMPTY AND NOT VISIBLE DOWN THERE, which was the first design and would have broken the gate:
    # Get-EntryScaffoldFindings strips comments and THEN measures emptiness, so guidance that is a comment
    # cannot be mistaken for an answer. Visible boilerplate inside a tier section would read as an answer,
    # and a tier nobody filled in would reach CHANGELOG.md blank with the gate reporting success -- this
    # repo's worst failure mode for a guard. Removing the blocks keeps that measure honest; hoisting the
    # rules that have a SILENT failure mode up here keeps them in front of the author.
    #
    # THE TWO THAT EARNED THE HOIST are the Score line (text below it is discarded without a word) and the
    # root-relative link (inbound #806: a consumer merged two '../../scripts/...' links that landed at the
    # root pointing outside the repo, with every gate green). The field PROMPTS did not come along -- a
    # heading plus the rubric new-branch prints is enough, and the portable page carries the long form.
    #
    # IT SITS ABOVE THE DEPLOY SECTION, which is what makes it safe: the fold takes that section and
    # nothing else, so none of this reaches CHANGELOG.md. Verified twice on August 23, 2026, when a filled
    # PLAN/CREATE/TEST reached neither entry.
    #
    # THE POINTER NAMES THE PAGE AND NOT A PATH, deliberately. That page ships with the plugin and is NOT
    # scaffolded into a consumer's tree, so a repo-relative link would resolve here and be dead in every
    # consumer -- the 'right owner, wrong reach' failure inbound #731 already cost this workflow once.
    StepsGuidance  = @(
        '> **How this file is read.** A step is `- [ ]` until it is resolved -- `- [x]` done, or',
        '> `- [~]` dropped with the reason, which exists so nobody ticks a box for work they did not do.',
        '> open-pr and ship-pr both refuse while one is still open, and there is no `-Force`.',
        '>',
        # THE LEVELS ARE COMPOSED FROM THE KNOBS, not typed (August 26, 2026). This guidance states the
        # document's own shape, so a literal '##' here is a second copy of BranchCycleSectionLevel that is
        # free to disagree with it -- and it did, for the length of one branch: the levels shifted and this
        # text went on telling every new branch to write the shape the scaffolder no longer produced.
        # Concatenated rather than interpolated because a backtick is PowerShell's escape character, so a
        # double-quoted string carrying markdown backticks reads them as escapes.
        #
        # AND THE PARENTHESES AROUND EACH CONCATENATION ARE LOAD-BEARING -- do not tidy them away
        # (#915, August 26, 2026). In PowerShell ',' binds TIGHTER than '+', so inside an array literal
        # an unparenthesised 'a' + $H + 'b' is not string concatenation at all: it parses as ARRAY
        # concatenation of its neighbours, ('...', 'a') + $H + ('b', '...'), turning one element into
        # three and dropping a bare '###' line into the guidance. That is what shipped: 38 elements
        # where 30 are written, four of them a naked marker, and check-branch-entry.ps1 then read those
        # markers as branch content in the generic region and refused every new branch document. It
        # fails into well-formed output rather than into an error, which is why it read as working code
        # and why the scaffold suite now asserts that no generated element is a bare marker.
        ('> **FOUR `' + $script:BranchCyclePhaseHashes + '` HEADINGS, AND NEVER A FIFTH** -- PLAN, CREATE, TEST, DEPLOY are the whole top'),
        ('> level. A section needing its own heading goes in as a `' + $script:BranchCycleSubHashes + '` UNDER whichever of the four owns'),
        '> it. No gate in YOUR repo reads a heading, so this half is on you -- only the repo that authors',
        '> this workflow refuses a fifth (Dave, August 26, 2026).',
        '>',
        # THE FIRST PHASE IS NAMED BY POSITION, NOT QUOTED AS A HEADING (#1654, September 8, 2026). This
        # line used to read '`### PLAN`', which put the exact heading string into every branch document
        # TWICE -- once as the real heading, and once here in the blockquote ABOVE it. Any edit anchoring
        # on that heading as a plain string therefore finds the wrong one first, and two documents shipped
        # through that door: #1632 (reduced to nothing but its truncated guidance, DEPLOY gone) and #1644
        # (cut mid-sentence at this very line, the body glued on below it).
        #
        # 'THE FIRST OF THOSE FOUR' IS NOT THE VAGUER HALF OF THAT TRADE, which is the objection worth
        # answering because it is what kept the literal here. The bullet directly above names PLAN, CREATE,
        # TEST and DEPLOY in order, so the antecedent is one line up -- a reader deciding where to put a
        # paragraph has just read the list. And it is MORE correct than the literal, not merely safer:
        # StepPhases is a seam, so a consumer who renamed their first phase was being told a rule about a
        # heading their own documents do not contain.
        #
        # THE TWO REFUSAL MESSAGES KEEP THE LITERAL, deliberately (open-pr.ps1's entry gate and
        # check-branch-entry.ps1's CI copy). There it is a DIAGNOSIS naming the string somebody's tool
        # matched on, not guidance -- and every document scaffolded BEFORE this change still carries the
        # collision, so it stays true for exactly the files that need it. Both say so in as many words.
        '> **AND NOTHING BRANCH-SPECIFIC ABOVE THE FIRST OF THOSE FOUR HEADINGS** -- everything between the',
        '> title and it is this guidance, which is identical in every branch document. A status line, a note about',
        ('> THIS branch or an instruction to a session belongs under one of the four, normally as a `' + $script:BranchCycleSubHashes + '`'),
        '> in PLAN. THIS half open-pr refuses, in every repo, before the push -- it reads the shape, so a',
        '> guidance block in your own language passes and your own paragraph here does not (Dave,',
        '> August 26, 2026; refused since #1650).',
        '>',
        '> **DEPLOY takes no steps of its own, and it is WRITTEN LAST** -- it is what the branch DID, once',
        '> TEST says so. Written while steps above it are still open it states an INTENTION, and no gate',
        '> holds it against what landed: the step gate splits this file at that heading and counts only',
        '> above it. The PR title is the one exception -- new-branch -Title writes it at creation, because',
        '> open-pr composes the PR title from it. It is the one part of this file that travels verbatim',
        '> into `CHANGELOG.md` at the merge. In each tier, write the reason',
        '> ABOVE the Score line -- anything below it is discarded.',
        '>',
        # '{1}' IS THE LINK SENTENCE, resolved per repo by Format-EntryLinkGuidance (inbound #967) -- the
        # same shape as '{0}' below, and for the same reason: the base it names is a seam. It was two typed
        # lines saying 'FROM THE REPO ROOT', which every consumer's changelog stopped being when #914 moved
        # it into the workflow folder. One token, because the sentence is two lines wide in one case and the
        # formatter repeats this line per fragment rather than the token spanning two of them.
        '> {1}',
        '>',
        '> {0} That reader and nobody else -- what matters only',
        '> inside this repo belongs under the first `**Score:**`. If the change reaches that reader',
        # ONE HOP AND NO FURTHER (#1896, September 12, 2026). '{0}' names the tier's reader as a ROLE --
        # 'the subscriber of a service' -- and a role does not say WHICH party fills it. Where that reader is
        # itself a business the author has two candidates in view, and the wrong one is the more vivid,
        # because it is a real customer somebody in the room can picture. Measured on v5.1.0: two entries
        # about issue labels in the same two store repos scored the same question N/A and 4, and the N/A one
        # named the right reader in its own first clause before scoring against the other. It cost a required
        # migration its place on the audience note. The rule is stated in RELEASES-portable.md; this is the
        # line the author meets while actually scoring, which is why it is repeated here rather than linked.
        #
        # IT CONTINUES THE SEAM PARAGRAPH AND MUST NOT BECOME ONE OF ITS OWN -- that is issue #928 exactly,
        # one clause further down the same sentence. Remove-EntryAudienceGuidance drops the whole PARAGRAPH
        # carrying '{0}' in a repo that states no audience tier, fenced by separator lines. A separate
        # paragraph here would survive that removal and open with 'that reader' after the clause naming that
        # reader had gone -- the mid-sentence paragraph #928 was filed for, reappearing in the consumers it
        # was fixed for and invisible here, where repo-config states tier 2. Kept inside the paragraph, it is
        # removed with it, which is also the right answer on the merits: a repo asked about every tier has no
        # single 'that reader' for this clause to qualify.
        # DELIBERATELY TIER-AGNOSTIC otherwise, so it is correct under '{0}' in a tier-1 repo too: a
        # commissioner who resells has customers of their own, one hop past this repo just the same.
        '> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that',
        '> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader',
        '> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score',
        '> against them.',
        '>',
        '> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships',
        '> with this workflow.'
    )

    # THE OPENING SENTENCE OF THE TRUNK WARNING, AND IT IS A SEAM BECAUSE IT WAS THE ONE FRAGMENT THAT WAS
    # NOT (inbound #562, August 10, 2026). Format-BranchFileHeader used to build this line itself, so a
    # consumer who had translated everything else got a document whose FIRST sentence was still English:
    #
    #   > **You are on `main`.** Schrijf hier nog niet -- maak eerst een branch.
    #
    # Exactly the case these knobs exist for -- the rest of the sentence is repo-owned language, and the
    # only way out was forking new-branch.ps1, which is the duplication #410 had just removed.
    #
    # '{0}' IS REPLACED BY THE TRUNK NAME, and by a plain string replace rather than -f / [string]::Format.
    # A seam value is hand-written, so a stray '{' in somebody's translation would make a format string
    # throw at scaffold time; a replace cannot fail. The placeholder is OPTIONAL for the same reason it is
    # useful: a translation needs the trunk name in a different position than English does, and one that
    # leaves it out simply does not repeat the name -- the heading directly above already carries it.
    #
    # AN EMPTY OVERRIDE KEEPS THIS DEFAULT, like every other key here -- see Get-BranchFileWording's
    # fail-safe. So there is no way to drop the sentence through the seam, only to replace it. The first
    # draft of this change claimed there was, and the test written to prove it is what disproved it.
    TrunkWarningLead = '**You are on `{0}`.**'
    TrunkWarning   = @(
        'Do not work in this file yet -- create a branch first.',
        'Anything written here on the trunk belongs to no branch, will not be folded, and is in the way',
        'of the next person who does create one.'
    )
    # NO ScaffoldNote EITHER. It was the '_(filled in when a branch is created)_' line under the reset
    # state's prose, and both are gone: the reset state IS the document now, phases and DEPLOY section and
    # all, with the trunk's name in its heading. A reader on the trunk sees exactly the file they will get,
    # empty -- which is what that sentence was trying to describe.
}

function Get-BranchTrunkName {
    <#
        The trunk this repo merges into, 'main' unless the consumer says otherwise via an OPTIONAL
        Get-TrunkBranchName in scripts/repo-config.ps1.

        It is here rather than inline because THREE things need the same answer and one of them writes
        it into a document: new-branch.ps1 refuses to scaffold on the trunk, the reset template
        below names the trunk in its warning, and the fold writes that template back. A literal 'main'
        in each is the shape where a consumer on 'master' gets a correct refusal and a document that
        tells them the wrong branch name.
    #>
    if (Test-FunctionDefined 'Get-TrunkBranchName') {
        $v = Get-TrunkBranchName
        if ($v) { return [string]$v }
    }
    return 'main'
}

function Get-TrunkGap {
    <#
        How far the tree at $RepoRoot is BEHIND the trunk on origin -- the one measurement, with the
        consequence left to the caller.

        WHY IT IS SHARED RATHER THAN INLINE. Two scripts meet the same hazard and owe two different
        answers to it: new-branch.ps1 WARNS that a base is behind (inbound #1046), while the fold
        REFUSES, because its commit lands directly on the trunk under a named exception and a stale
        trunk turns that commit into a duplicate the operator cannot cheaply undo (inbound #1405). Same
        diagnosis, different thing about to go wrong -- which is the shape Get-PreFlatChangelogRefusal
        already uses in this file, where the measurement is shared and the consequence is the caller's.

        THE LOCAL QUESTION GATES THE NETWORK ONE, which is what keeps this usable offline and inside a
        test fixture. refs/remotes/origin/<trunk> is read FIRST: no such ref means no origin, or a clone
        that has never fetched, and then there is nothing to compare against -- so no fetch is attempted
        and Measured comes back $false. A caller MUST NOT read "could not measure" as "behind": every
        fixture repo in this repo's own suite has no remote, and a caller that conflated the two would
        refuse every fold in it.

        HEAD..origin/<trunk> RATHER THAN A TRUNK-VS-ORIGIN COMPARISON, deliberately, and for the same
        reason new-branch.ps1 chose it: it answers "what is my checkout missing", which is the question,
        and it stays correct when HEAD is NOT the trunk. The fold runs detached at origin/<trunk> from a
        ship-pr lane, and there this reads 0 instead of complaining about a local trunk ref the worktree
        does not carry.

        FRESH SAYS WHICH REF THE COUNT CAME FROM, and it means "this call refreshed the ref" -- so it is
        $false under -NoFetch too, where the caller has already fetched and knows it, and $false on a
        retry skipped under -RecentFailureSeconds, where nothing was refreshed because the attempt being
        reported did not refresh anything either. "3 behind the origin/main you last saw" is a different
        sentence from "3 behind origin/main", and a reader who is offline has to be told which one they
        got.

        THE FETCH IS NARROWED TO THE TRUNK, AND -FetchAllRefs WIDENS IT FOR THE ONE CALLER THAT NEEDS
        THE REST (issue #1416). The fold wants the smallest network call that answers the question and
        nothing more. new-branch.ps1 wants the same answer AND reads refs/remotes/origin/<branch> moments
        later, to tell a resume of a branch parked from another device from a fresh cut (#1139) -- and a
        fetch narrowed to the trunk never brings that ref into existence, so the parked branch stays
        invisible and a second, unrelated branch of the same name is cut at the current base. That is
        exactly the bug #1139 closed, and it would come back silently. So the scope is the caller's to
        state rather than this function's to guess: narrowed by default, widened by the caller that
        knows it is reading more than the trunk off this fetch.

        AND THE FETCH ITSELF IS Invoke-RecordedRemoteFetch's SINCE #1860, which records every attempt and
        lets an opt-in caller report a recent FAILURE instead of waiting out a second one. Three things
        follow that are worth stating here rather than only there:

          - A SUCCESS NEVER EXCUSES A FETCH, however recent. The symmetric version of this seam was built
            first and this repo's own suite refused it: new-branch.tests.ps1 reproduces two runs seconds
            apart with another session's push between them -- cases (v) and (y1), #1139 and #1439 -- which
            is exactly the interval a freshness window covers and exactly the event those probes exist to
            see. The duplicated ~700ms #1860 reports is therefore still paid, deliberately.
          - THE RECORD IS UNCONDITIONAL, THE SKIP IS NOT. Every call through this function records what
            its fetch did, so a later opt-in caller can be let off; but only a caller passing
            -RecentFailureSeconds may itself be let off. That is what keeps this away from the fold, whose
            fetch backs a REFUSAL rather than an advisory warning -- a fold that refuses on a stale
            trunk must have looked itself, not been told by a record.
          - SCOPE IS PART OF THE RECORD, BECAUSE -FetchAllRefs IS. A narrow fetch can fail for a reason
            that says nothing about a wide one ("couldn't find remote ref main" is about that ref), so a
            narrow failure may never suppress a widened fetch.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        # Defaults to the repo's own trunk name, so a consumer on 'master' measures against theirs.
        [string]$Trunk,
        # Measure against the ref already on disk. For a caller that has just fetched itself and only
        # wants the count -- the fold's push-rejection path, which fetches once and then asks twice.
        [switch]$NoFetch,
        # Fetch EVERY ref from origin rather than only <trunk>. For a caller that reads ANOTHER
        # remote-tracking ref off the back of this same fetch -- see the header.
        [switch]$FetchAllRefs,
        # 0 leaves Invoke-NativeCapture on its own default; the fold passes the same network bound it
        # already puts on its push, so a hung fetch cannot turn a refusal into a stall.
        [int]$TimeoutSeconds = 0,
        # How recently an equivalent fetch must have FAILED for this call to report that failure rather
        # than wait out a second one (issue #1860). 0 -- the default -- never skips, which is every
        # caller except new-branch.ps1: see the header for why the fold in particular must look for
        # itself, and for why a recent SUCCESS never excuses a fetch under any value of this.
        [int]$RecentFailureSeconds = 0
    )

    if (-not $Trunk) { $Trunk = Get-BranchTrunkName }
    $ref = "refs/remotes/origin/$Trunk"
    $result = [pscustomobject]@{
        Measured = $false
        Fresh    = $false
        Behind   = 0
        Trunk    = $Trunk
        Ref      = $ref
        Output   = @()
        # The reason a SKIPPED fetch gives for the refs possibly being behind (issue #1860) -- empty
        # whenever this call made the fetch itself, and under -NoFetch.
        #
        # ONLY ON A SKIP, DELIBERATELY, because only a skip carries something a caller could not have
        # found out: "an attempt 12s ago failed and was not retried" is a different sentence from "this
        # fetch failed", and .Fresh alone collapses them. Where the call DID fetch, new-branch's own
        # note says the fetch failed and that the real gap may be larger, and the fold prints git's
        # lines from .Output -- so filling this in there would be a third copy of one fact.
        FetchNote = ''
    }

    $has = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $RepoRoot, 'rev-parse', '--verify', '--quiet', $ref) -DiscardStderr
    if ($has.ExitCode -ne 0) { return $result }

    if (-not $NoFetch) {
        # GIT'S OWN WORDS ARE KEPT HERE, not discarded. Issue #1313 measured that a failing fetch does not
        # leak a credential -- transport_anonymize_url strips userinfo from every "unable to access" line
        # -- and on that measurement DECLINED adding -DiscardStderr to three other fetches, for removing
        # the only diagnosis a reader gets. A caller of this function is about to refuse a fold, to
        # explain a rejected push or to warn about a stale base, so git's reason is precisely what the
        # operator needs -- whether it prints the lines or keeps them is then its own call.
        $refspec = if ($FetchAllRefs) { '' } else { $Trunk }
        $fetch = Invoke-RecordedRemoteFetch -RepoRoot $RepoRoot -Remote 'origin' -Refspec $refspec `
                                         -RecentFailureSeconds $RecentFailureSeconds -TimeoutSeconds $TimeoutSeconds
        $result.Fresh = [bool]$fetch.Fresh
        $result.Output = @($fetch.Output | Where-Object { $_ -and "$_".Trim() })
        if ($fetch.Skipped) { $result.FetchNote = "$($fetch.Note)" }
    }

    $count = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $RepoRoot, 'rev-list', '--count', "HEAD..$ref") -DiscardStderr
    if ($count.ExitCode -ne 0) { return $result }
    $n = 0
    if ([int]::TryParse((($count.Output -join '').Trim()), [ref]$n)) {
        $result.Measured = $true
        $result.Behind = $n
    }
    return $result
}

function Get-BranchFilePaths {
    <#
        The branch's own working document, its repo-relative path and the directory holding it, as ONE
        object.

        ONE FILE SINCE AUGUST 23, 2026 (Dave), WHERE THERE WERE TWO. 'workflow-davekjohn/branch/' held a
        step list and an entry side by side; both are sections of the branch's development document
        now -- PLAN, CREATE and TEST carry the steps, and the fourth phase, '## `<branch>` DEPLOY', IS the
        entry that folds into CHANGELOG.md at the merge. The split had been correct about one thing and wrong
        about another: the two jobs genuinely are different, and putting them in two documents meant the
        branch's own plan and the claim it makes were never on one screen.

        FORWARD SLASHES, deliberately: these strings are handed to git (pathspecs, ls-files comparison) as
        often as to Join-Path, and Join-Path on Windows accepts '/' while git's own output never uses '\'.
        The one place that needs the backslash form converts at the boundary, which is where the fold
        already does it for the legacy root entries.

        Not repo-configurable, and that is the same call CHANGELOG.md's own name gets: this is the FORMAT
        the shared scripts read, not prose about it. A consumer renaming the file would be renaming the
        interface between four scripts, which is what a fork is for. The WORDING inside it is configurable
        -- see Get-BranchFileWording -- because that is language, and language is the thing #410
        established a repo owns.

        IT EXISTS FOR THE LIFETIME OF A BRANCH AND NO LONGER (Dave, August 23, 2026). new-branch creates it,
        the fold REMOVES it, and the trunk carries no copy -- so the workflow's folder holds its three pages
        and its two directories on the trunk, and this file appears only while there is work to describe. It
        used to be rewritten to an empty state instead, which put a permanent placeholder in the one folder a
        consumer reads to learn the convention.

        WHAT THAT COSTS IS THE REFERENCE COPY, and it is paid elsewhere on purpose. The empty document on the
        trunk was also the thing a reader opened to see the whole form at once; the portable page
        DEVELOPMENT-portable.md is what carries that now, and unlike a file scaffolded into a consumer
        once it travels with every plugin update.

        UNDER dkj-policy/ SINCE AUGUST 14, 2026 (Dave): everything portable about the workflow
        gathers in that one root folder instead of scattering through the consumer's root. The 'branch/'
        subdirectory under it is gone with the merge -- a directory holding one file is a directory
        explaining itself.

        EVERY OLD NAME IS STILL READ, and that is the same call the August 19, 2026 rename made rather than
        the one the directory move made. The difference is what is in flight: a location can be tidied up
        once, while these files ARE the working state of every branch that exists right now -- here and in
        every consumer, who meet this change through a plugin update rather than by choosing to. Refusing to
        see the old pair would strand a half-finished branch with its entry unfolded and its step list
        unread, which is the silent half-state this repo keeps rediscovering.

        SO: recognise every predecessor, write one. Resolve-BranchFilePath is the reader; every WRITER uses
        File and nothing writes a legacy name again.

        THE FOLDER ITSELF RENAMED ON AUGUST 26, 2026 (#886): 'workflow-davekjohn/' ->
        'contributing-davekjohn/'. That is the same class of change as the two above and gets the same
        answer, for the reason already written down: a consumer meets it through a plugin update, and a
        branch half-finished inside the old folder must not be stranded with its entry unfolded. So the old
        FOLDER joins the list of names that are read -- both its current document and its four legacy
        filenames -- and nothing writes it again.

        AND THE DOCUMENT RENAMED ON AUGUST 27, 2026 (Dave, #963/#958): 'development-cycle.md' ->
        'development.md', following its own heading -- see ProgressTitle in $script:BranchFileDefaults.
        Fifth rename, same answer, and by now the answer is the pattern rather than a decision each time:
        the prior name joins the names that are READ and nothing writes it again. PriorNameFile is that
        entry.

        AND THE DOCUMENT BECAME ONE PER BRANCH ON SEPTEMBER 3, 2026 (#1255): 'development.md' ->
        'development-<slug>.md', the slug being the branch with its slashes flattened. Sixth rename, same
        answer -- SharedFile is the pre-#1255 shared name, read and never written, and every branch open on
        the day of the change is carrying it, here and in every consumer. What the fixed name actually cost
        is worth naming, because the reasoning for it said the wrong thing: it did not collide on CHECKOUT,
        which git handles per branch. It collided on MERGE. Every merge to the trunk left every other open
        PR conflicting on this one file, and a conflicting PR gets no check suite at all -- so it could
        never go green and could never merge.

        AND THE PREFIX WENT ON SEPTEMBER 3, 2026 (Dave, #1335): 'development-<slug>.md' -> '<slug>.md'. The
        seventh rename, the same answer as the six before it -- PriorPerBranchFile is the name every branch
        open on the day carries, read and never written. What it costs is the thing the prefix was quietly
        doing: it made 'development-*.md' a glob that could not reach this folder's own permanent pages, and
        with the prefix gone that narrowing has to be stated instead of assumed. ReservedNames below is where
        it is stated, and the block there says which page makes it load-bearing.

        AND THE FOLDER RENAMED A SECOND TIME ON SEPTEMBER 5, 2026 (#1437): 'contributing-davekjohn/' ->
        'dkj-policy/', following the plugin it is named after. The eighth rename, the same answer as the
        seven before it, and ContribFolder* is where the old folder's names are read. It differs from
        PriorFolder* in one way worth naming, because the difference is the whole reason the row set is
        larger: #886 landed while the document was still ONE shared file, so the pre-#886 folder can only
        ever hold 'development-cycle.md' and the branch/ pair. This rename lands three days after the
        documents went per-branch, so what a stranded branch is actually carrying is
        'contributing-davekjohn/<slug>.md' -- a name that exists in every open branch and every consumer on
        the day of the change, not a hypothetical one.

        PATTERN IS THE ONE ROW THAT IS NOT A NAME, and it arrived with that same change because a per-branch
        set cannot be listed in advance. Resolve-BranchFilePath sweeps this glob over Directory to find every
        OTHER per-branch document in the folder -- a branch renamed after new-branch ran, a document written
        by hand, a leftover from a fold that was blocked -- and then asks each hit which branch it DECLARES,
        which is what keeps the filename from becoming the authority (the trap the pre-August-2026
        per-branch form set, and the reason a '-v2' suffix was once forbidden). Test-IsPerBranchDocumentPath
        reads the same glob, for the mirror-image reason: the lint gate's two exclusion checks each held a
        fixed list, and a list cannot answer a pattern -- the moment the documents were named per branch,
        every one of them fell out of both checks silently.

        THE READ SET IS DELIBERATELY NOT COUNTED HERE ANY MORE. This narrative said 'four names' after the
        August 19 rename, 'seven' after #886 and 'eight' after #963, and #1255 then added SharedFile without
        touching the number -- a hand-maintained count in prose beside a table that grows once per rename.
        Since #1259 there is one ordered source to read instead: Get-BranchFileLegacyNames returns the legacy
        candidates for a given -Kind, Resolve-BranchFilePath tries this branch's own name and the Pattern
        sweep ahead of them, and new-branch's writer feeds that same list to its own target-picking so a
        rerun on an old name keeps writing there. The half that never changes is the half worth stating:
        one name is written, File, and nothing writes a legacy name again.

        WHY THERE IS NO 'workflow-davekjohn/development.md' IN THIS TABLE, since its absence looks like an
        omission next to the PriorFolder* rows: that pair never existed. The folder was renamed on
        August 26 and the document on August 27, so no branch was ever open on the new filename inside the
        old folder. A row for it would be a name to read that nothing can ever have written.
    #>
    param(
        # The branch whose document is being named. Optional, and what it changes is WHICH name File,
        # Cycle and Deployment answer: given a branch they answer that branch's own document, omitted they
        # answer the pre-#1255 shared name. Optional rather than mandatory because several callers ask this
        # function for the SHAPE of the layout -- the directory, the list of names to sweep -- and have no
        # branch to offer; making it mandatory would have forced a branch lookup into callers that do not
        # need one. Every WRITER passes it.
        [string]$Branch = ''
    )
    # THE SLUG IS THE BRANCH WITH ITS SLASHES FLATTENED, which is the same transform Get-BranchInfo's
    # SafeName has always applied and the same one the pre-split root entry '<SafeName>.md' was named with.
    # Done inline rather than by calling Get-BranchInfo on purpose: that function lives in the REPO-OWNED
    # branch-info.ps1, and this lib is shared and mirrored into every consumer. Reaching into the repo-owned
    # contract from here would add a mandatory function to it for a one-line string operation, and
    # check-branch-entry.ps1 already documents this exact expression as the fallback when Get-BranchInfo is
    # not loaded. A git branch name cannot contain the characters Windows forbids in a filename, so the
    # slash is the only one that has to go.
    $slug = if ($Branch) { $Branch -replace '/', '-' } else { '' }
    $perBranch = if ($slug) { "dkj-policy/$slug.md" } else { 'dkj-policy/development.md' }
    return [pscustomobject]@{
        Directory        = 'dkj-policy'
        File             = $perBranch
        # THE PATTERN EVERY PER-BRANCH DOCUMENT MATCHES, so a reader can discover one without being told the
        # branch. Resolve-BranchFilePath sweeps it and then asks each hit which branch it DECLARES, which is
        # what keeps the filename from becoming the authority -- see the block above on the trap the old
        # per-branch form set.
        #
        # IT IS EVERY MARKDOWN FILE IN THE FOLDER SINCE #1335, and that is why ReservedNames arrived with it.
        # 'development-*.md' carried its own guard: the prefix was a word no other page here begins with, so
        # the glob could not reach README.md, CONTRIBUTING.md or CHANGELOG.md. A bare '<slug>.md' has no
        # prefix left to be narrow about, so the narrowing moves from the glob to an explicit exclusion --
        # and it is NOT optional. CHANGELOG.md is the file that makes it load-bearing: it is full of folded
        # '### DEPLOY: <branch>' headings, so it DECLARES a branch by every test in this file. A sweep that
        # reached it would hand the fold the changelog as this branch's document, and the fold moves the
        # document into the changelog and then deletes it.
        Pattern          = '*.md'
        # THE FOLDER'S OWN PERMANENT PAGES, excluded from the sweep above. Fixed rather than read from the
        # seams, the same call Directory itself gets: Get-ChangelogPath may point anywhere, and a lib that
        # went looking for a repo root to resolve it is a lib that can find the wrong tree. What a fixed list
        # costs is a repo that renamed one of these three AND parked it in this folder -- which is the same
        # repo that would have to fork Get-BranchFilePaths anyway, since these names are the interface four
        # scripts read. Matched case-insensitively, because Windows will hand back 'Readme.md' for a file
        # committed as 'README.md'.
        ReservedNames    = @('README.md', 'CONTRIBUTING.md', 'CHANGELOG.md')
        # THE PRE-#1255 SHARED NAME, read and never written. Every branch open on September 3, 2026 carries
        # it, here and in every consumer, and they meet this change through a plugin update rather than by
        # choosing to -- the same answer the five renames before this one got.
        SharedFile       = 'dkj-policy/development.md'
        # Cycle and Deployment both answer the same path now, deliberately, so every caller that asks for
        # one of the two halves keeps working and gets the one document. They are kept as names rather than
        # collapsed into File alone because they still mean different THINGS -- the step list and the entry
        # -- and a gate reading the step list wants to say so where it prints a path.
        Cycle            = $perBranch
        Deployment       = $perBranch
        # The pre-#963 filename, read and never written. A branch open right now carries it -- including
        # the branch that performed this rename, which is what proved the dual-read still works.
        #
        # IT ALSO MATCHES Pattern, and that is harmless rather than an oversight worth repairing. The sweep
        # finds it, the declare-test then decides whether it is this branch's -- which is the same answer the
        # explicit candidate below gives. The reverse case, a branch whose slug is literally 'cycle', would
        # write to this exact name; the declare-test resolves that correctly too, because the file would
        # declare that branch.
        PriorNameFile    = 'dkj-policy/development-cycle.md'
        # THE PRE-#1335 PER-BRANCH NAME, read and never written -- 'development-<slug>.md'. Branch-dependent,
        # unlike every other legacy row here, which is why Get-BranchFileLegacyNames had to learn -Branch:
        # a caller on the -Reader arm cannot sweep a directory, so this name has to be NAMED for it. On the
        # tree arm the Pattern sweep would find it anyway; naming it costs one candidate and removes the
        # difference between the two arms.
        #
        # EMPTY WHERE NO BRANCH WAS GIVEN, not 'development-.md'. A caller asking for the SHAPE of the layout
        # has no branch to build this from, and a candidate list containing a path nothing can ever have
        # written is a path every reader still opens.
        PriorPerBranchFile = if ($slug) { "dkj-policy/development-$slug.md" } else { '' }
        LegacyCycle      = 'dkj-policy/branch/branch-cycle.md'
        LegacyDeployment = 'dkj-policy/branch/branch-deployment.md'
        OlderCycle       = 'dkj-policy/branch/branch-progress.md'
        OlderDeployment  = 'dkj-policy/branch/branch-changelog.md'
        # THE PRE-#1437 FOLDER, read and never written -- 'contributing-davekjohn/', which every branch open
        # on September 5, 2026 is standing in, here and in every consumer. ContribFolder* mirrors the whole
        # set above one directory over, PER-BRANCH NAME INCLUDED, and that last part is what makes it
        # different from PriorFolder* below: the #886 rename landed while the document was still one shared
        # file, so the old folder could only ever hold 'development-cycle.md' and the branch/ pair. This one
        # lands three days after the documents went per-branch, so the name a stranded branch is actually
        # carrying is 'contributing-davekjohn/<slug>.md' -- the newest predecessor in the whole table, and
        # the one row whose absence would strand a real branch rather than a hypothetical one.
        ContribFolderPerBranch        = if ($slug) { "contributing-davekjohn/$slug.md" } else { '' }
        ContribFolderPriorPerBranch   = if ($slug) { "contributing-davekjohn/development-$slug.md" } else { '' }
        ContribFolderShared           = 'contributing-davekjohn/development.md'
        ContribFolderFile             = 'contributing-davekjohn/development-cycle.md'
        ContribFolderLegacyCycle      = 'contributing-davekjohn/branch/branch-cycle.md'
        ContribFolderLegacyDeployment = 'contributing-davekjohn/branch/branch-deployment.md'
        ContribFolderOlderCycle       = 'contributing-davekjohn/branch/branch-progress.md'
        ContribFolderOlderDeployment  = 'contributing-davekjohn/branch/branch-changelog.md'
        # The pre-#886 folder, read and never written. PriorFolder* mirrors the five above one directory
        # over, so a branch left open in the old folder is still found, folded and cleared.
        PriorFolderFile             = 'workflow-davekjohn/development-cycle.md'
        PriorFolderLegacyCycle      = 'workflow-davekjohn/branch/branch-cycle.md'
        PriorFolderLegacyDeployment = 'workflow-davekjohn/branch/branch-deployment.md'
        PriorFolderOlderCycle       = 'workflow-davekjohn/branch/branch-progress.md'
        PriorFolderOlderDeployment  = 'workflow-davekjohn/branch/branch-changelog.md'
    }
}

function Test-IsPerBranchDocumentPath {
    <#
        Pure: does this repo-relative path name a PER-BRANCH development document (#1255)?

        ONE PREDICATE, TWO READERS, which is why it is a function and not an expression repeated twice. The
        lint gate asks this question in two unrelated checks -- which base a document's relative links
        resolve from, and whether a document is exempt from the lifecycle-command rule -- and each held its
        own literal list of branch-document names. A list cannot answer a PATTERN: the moment the documents
        were named per branch, every one of them fell out of both checks silently, which is the direction
        that costs the most (a check that reports nothing looks exactly like a check that found nothing).

        DELIBERATELY NARROW. It answers for the per-branch shape ALONE -- the fixed names each caller
        already listed are still listed there, because the two callers do not list the same set and
        collapsing them here would quietly widen one of them. This is the addition, not a replacement.

        SINCE #1335 THE PATTERN ALSO COVERS THE PRE-#1255 SHARED NAME, and that is accepted rather than
        excluded back out. 'development.md' fell outside 'development-*.md' -- the hyphen -- and falls inside
        '*.md'. It is a branch development document, both callers use this predicate to exempt exactly that
        kind of file, and both list the shared name themselves anyway, so nothing downstream changes. What
        does NOT fall inside is this folder's permanent pages: see ReservedNames.

        Separator-agnostic: callers build $rel from a Windows path in one check and from the seam's forward
        slashes in the other, and an exclusion that compares the two raw matches nothing -- the lesson
        check 20 in that gate already paid for once.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$RelativePath)
    if ([string]::IsNullOrWhiteSpace($RelativePath)) { return $false }
    $paths = Get-BranchFilePaths
    $norm  = ($RelativePath -replace '\\', '/').TrimStart('.', '/')
    $dir   = [string]$paths.Directory
    # The pattern is a filename glob; anchor it to the folder so a same-named file elsewhere in the tree is
    # not swept in. -like rather than a regex because Pattern is authored as a glob and stays readable as one.
    #
    # THE LEAF IS SPLIT OFF FIRST, AND IT HAS TO BE (#1335). '*' in -like matches a '/' as happily as any
    # other character, so the anchored form '<dir>/*.md' also matched '<dir>/releases/history.md' -- a
    # SUBDIRECTORY, waved through as a per-branch document. It never showed while the glob carried the word
    # 'development-'; the moment it became '*.md' the release history started resolving its links from the
    # wrong base and 26 of them were reported dead. Measured on this change's first gate run. So the
    # directory is matched as a whole segment and the glob is applied to the filename alone.
    $slash = $norm.LastIndexOf('/')
    if ($slash -lt 0) { return $false }
    if ($norm.Substring(0, $slash) -ne $dir) { return $false }
    if ($norm.Substring($slash + 1) -notlike ([string]$paths.Pattern)) { return $false }
    # AND THE FOLDER'S OWN PAGES ARE NOT PER-BRANCH DOCUMENTS (#1335). Since the glob became '*.md' this
    # predicate would otherwise answer true for CHANGELOG.md, README.md and CONTRIBUTING.md -- and both its
    # callers in the lint gate use it to EXEMPT a file from a check, so a wrong true is silence rather than
    # noise: exactly the direction this function's own docstring says costs the most.
    if (@($paths.ReservedNames) -contains $norm.Substring($slash + 1)) { return $false }
    return $true
}

function Get-PerBranchDocumentRels {
    <#
        Every per-branch development document actually present in $RepoRoot, repo-relative, forward slashes,
        sorted -- the folder's own permanent pages excluded.

        ONE SWEEP, FIVE CALLERS (#1335, #1497), and it is a function for the same reason
        Resolve-BranchFilePath is: Resolve-BranchFilePath discovers sibling documents, Get-UnfoldedTrunkEntry
        hunts leftovers on the trunk, check-plugin-integrity.ps1 sweeps twice -- for heading levels and for
        branch-type headings -- and fold-changelog-entry.ps1's fold-all mode discovers what to fold. All of
        them had the same three lines inline, which was survivable while the glob carried its own guard in
        the word 'development-'. It does not any more: the exclusion is now the only thing between this sweep
        and CHANGELOG.md, and a guard maintained in copies is a guard that will hold in all but one of them.

        THE FIFTH WAS FOUND THE HARD WAY (#1497, September 6, 2026), and it is why this paragraph now names
        its callers rather than counting them. #1335 converted four and missed the fold's own loop, so that
        loop kept the unguarded glob -- and #1437 then moved README.md, CONTRIBUTING.md and CHANGELOG.md INTO
        the swept folder. All three declare a branch and read as filled (CHANGELOG.md off its newest folded
        '### DEPLOY:' heading, the other two off an ordinary backtick-quoted path), so fold-all mode read
        each as an unfolded dossier: it spliced the page into the changelog and DELETED it. With the
        changelog outside the folder that even exits 0. The sentence above about copies was written before
        this happened and predicted it exactly; the count was the part that went stale, which is the argument
        for a named list over a number.

        NOT THE DECLARE-TEST. This answers "which files could be one", by name; every caller then asks each
        hit which branch it DECLARES, which is what keeps the filename from becoming the authority.

        A MISSING DIRECTORY IS AN EMPTY ANSWER, not an error: a consumer that has not run the workflow
        folder's adopter yet has no folder, and every caller here is a reader.
    #>
    param([Parameter(Mandatory)][string]$RepoRoot)
    $paths = Get-BranchFilePaths
    $dir = Join-Path $RepoRoot ([string]$paths.Directory -replace '/', '\')
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { return @() }
    $reserved = @($paths.ReservedNames)
    return @(
        Get-ChildItem -LiteralPath $dir -Filter ([string]$paths.Pattern) -File -ErrorAction SilentlyContinue |
            Where-Object { $reserved -notcontains $_.Name } |
            ForEach-Object { "$([string]$paths.Directory)/$($_.Name)" } |
            Sort-Object
    )
}

function Get-BranchFileLegacyNames {
    <#
        The ordered legacy candidate names for the branch's working document -- the names that are READ
        wherever a branch in flight still carries one, and never written again.

        ONE SOURCE, TWO CALLERS (#1259). Resolve-BranchFilePath sweeps this list, and new-branch.ps1's
        writer feeds the same list to its own Get-BranchFileTargetRel so a rerun on an old name keeps
        writing there instead of splitting the branch's work across two documents. Those two lists were
        maintained by hand in two files, and #886 (the workflow-davekjohn/ -> contributing-davekjohn/
        folder rename) and #963 (development-cycle.md -> development.md) grew the reader's copy and left
        the writer's at three names. This function is the single ordered source so the next rename cannot
        do that again.

        THE ORDER IS BY FOLDER GENERATION, NEWEST FIRST, AND NEWEST FILENAME FIRST WITHIN EACH. The current
        folder leads: PriorPerBranchFile is the pre-#1335 'development-<slug>.md', SharedFile the pre-#1255
        shared name, PriorNameFile the pre-#963 filename, then this folder's branch/ pair. None of those
        four can actually exist under 'dkj-policy/' -- every one of them was retired before the folder took
        that name -- and they cost nothing to look at, which is why they stay rather than being pruned into
        a shape that would need re-deriving at the next rename. Then the pre-#1437 contributing-davekjohn/
        set, which is where the REAL predecessors are: a branch open on September 5, 2026 is carrying
        'contributing-davekjohn/<slug>.md'. Then the whole pre-#886 workflow-davekjohn/ set, last and never
        written. Order is a preference rather than a correctness property -- the declare-test decides which
        candidate is this branch's -- so a name being early only means it is looked at early.

        $legacyKind FOLLOWS THE RESOLVER: 'File' and 'Cycle' both read the Cycle-named legacy files (the
        step list's history), 'Deployment' reads the Deployment-named ones (the entry's).

        ONE OF THEM IS BRANCH-DEPENDENT SINCE #1335, which is why -Branch arrived. Every other name here is a
        constant; 'development-<slug>.md' is not, and it is the newest predecessor of all -- every branch open
        on September 3, 2026 carries it. Omitted, -Branch simply leaves that candidate out, which is the right
        answer for a caller asking about the SHAPE of the layout rather than about a branch.
    #>
    param(
        [Parameter(Mandatory)][ValidateSet('File', 'Cycle', 'Deployment')][string]$Kind,
        [string]$Branch = ''
    )
    $paths = Get-BranchFilePaths -Branch $Branch
    $legacyKind = if ($Kind -eq 'File') { 'Cycle' } else { $Kind }
    return @(
        [string]$paths.PriorPerBranchFile,
        [string]$paths.SharedFile,
        [string]$paths.PriorNameFile,
        [string]$paths."Legacy$legacyKind",
        [string]$paths."Older$legacyKind",
        [string]$paths.ContribFolderPerBranch,
        [string]$paths.ContribFolderPriorPerBranch,
        [string]$paths.ContribFolderShared,
        [string]$paths.ContribFolderFile,
        [string]$paths."ContribFolderLegacy$legacyKind",
        [string]$paths."ContribFolderOlder$legacyKind",
        [string]$paths.PriorFolderFile,
        [string]$paths."PriorFolderLegacy$legacyKind",
        [string]$paths."PriorFolderOlder$legacyKind"
    )
}

function Resolve-BranchFilePath {
    <#
        The repo-relative path of the branch's working document AS IT EXISTS in $RepoRoot: today's single
        file where it holds this branch's work, an older name where only that one does, and today's file
        where neither does -- so a caller that goes on to WRITE creates the new name and a caller that
        READS finds the branch it is actually on.

        THE ONE PLACE THE DUAL-READ LIVES, on purpose. Four scripts and three gates ask where this file is;
        the fold's own history is what happens when each answers for itself -- root entries and branch/
        entries were recognised in two scripts by two different rules until they disagreed. One resolver
        means a branch created before the merge is either visible to all of them or to none.

        EXISTENCE IS NOT THE TEST, AND THE REASON OUTLIVED THE THING THAT CAUSED IT (August 23, 2026).
        Every rename before this one could resolve on Test-Path, because the new name did not exist until
        something wrote it. development.md broke that: it landed on the trunk in its reset state, so
        the moment a branch in flight merged the trunk it HAD the new file -- empty -- beside the pair that
        held its real work. Resolving on existence would hand every one of those branches an empty document
        and call their entry missing, which is precisely the stranded half-finished branch the dual-read
        exists to prevent. So the test is which file DECLARES this branch: Get-BranchFileDeclaredBranch reads
        the name out of the heading, and a file naming the trunk is a reset file whatever its path.

        THE TRUNK COPY IS GONE AND THE TEST STAYS, which is the deliberate half. Later the same day the
        document became branch-lifetime -- created by new-branch, REMOVED by the fold -- so a fresh checkout
        of the trunk carries nothing and Test-Path would discriminate again. Reverting to it would still be
        wrong: every branch cut before that change is carrying a trunk-declaring copy right now, here and in
        every consumer, and they meet this through a plugin update rather than by choosing to. The
        simplification is available on the day those branches are gone, and not before.

        THE ORDER IS NEW FIRST, THEN NEWEST-LEGACY, THEN OLDEST -- and since #886 that whole sequence runs
        again inside the PRE-RENAME FOLDER, after it. The fallback at the end is today's file, so a fresh
        repo, a repo mid-adoption and a repo with nothing written all send a writer to the same place.

        SINCE #1255 'TODAY'S FILE' IS THIS BRANCH'S OWN, and the sequence gained two entries at the front
        rather than changing shape. First the name this branch's document should have; then every OTHER
        per-branch document in the folder, because a filename is a convention and not a promise -- a renamed
        branch, or a document written by hand, still has to resolve. Then the pre-#1255 shared name, which is
        what every branch open on the day of the change is carrying, and only then the older names as before.

        WHAT DECIDES IS STILL THE DECLARE-TEST, on every one of those candidates, and that is the guard
        against rebuilding the trap the pre-August-2026 per-branch form set: it made the FOLD guess the branch
        out of the filename, which is why a '-v2' suffix was once forbidden. Nothing here trusts a name.

        Forward slashes out, like Get-BranchFilePaths, for the same reason: these strings go to git as often
        as to Join-Path.

        -Reader RESOLVES AGAINST A TREE THE CALLER IS NOT STANDING IN (issue #970, August 27, 2026). The
        default arm reads $RepoRoot; a caller that must answer for a COMMIT passes a scriptblock taking one
        repo-relative path and returning its text, or $null where that tree does not have it. ship-pr.ps1 is
        why: its gates before the merge judge the shipping branch's own commit, because a run that waits on
        CI may find the checkout moved by the time it looks.

        READING THE TEXT FROM A COMMIT IS NOT ENOUGH ON ITS OWN, which is why this is a parameter here rather
        than a detail of the caller. The choice between the candidate names is made by READING each of
        them, so a caller that resolves against the working tree and then reads the answer out of a commit
        gets the mismatch this parameter exists to remove -- and it fails in the dangerous direction: the
        resolver names a path that tree does not carry, the read comes back empty, and a gate reads that as
        'no document' and says nothing.

        EXISTENCE IS 'THE READER RETURNED TEXT', so both arms answer the two loops below identically -- and
        that is $null, tested explicitly, never falsiness: an empty document EXISTS and declares no branch,
        which is a different answer from a path that is not there.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Tree')]
    param(
        [Parameter(Mandatory)][ValidateSet('File', 'Cycle', 'Deployment')][string]$Kind,
        [Parameter(Mandatory, ParameterSetName = 'Tree')][string]$RepoRoot,
        [Parameter(Mandatory, ParameterSetName = 'Reader')][scriptblock]$Reader,
        # The branch being resolved for (#1255). Optional, and omitted it degrades to exactly the pre-#1255
        # behaviour: the shared name and the legacy names, chosen by the declare-test. Supplied, this
        # branch's OWN document is tried first and is what the fallback names, so a writer creates the
        # per-branch file. On the Tree arm it defaults to HEAD, because every caller there is asking about
        # the branch it is standing on; the Reader arm resolves against a tree the caller is NOT standing in,
        # so there it stays empty unless the caller says otherwise -- guessing HEAD for a commit on another
        # ref is the mismatch -Reader exists to remove.
        [string]$Branch = ''
    )
    if (-not $Branch -and $PSCmdlet.ParameterSetName -eq 'Tree') {
        # Best effort, and deliberately silent on failure: a tree that is not a git checkout, or a detached
        # HEAD, simply leaves $Branch empty and the resolver behaves as it did before this parameter existed.
        try {
            $headRef = (& git -C $RepoRoot rev-parse --abbrev-ref HEAD 2>$null)
            if ($LASTEXITCODE -eq 0 -and $headRef) {
                $headRef = ([string]$headRef).Trim()
                if ($headRef -and $headRef -ne 'HEAD') { $Branch = $headRef }
            }
        } catch { }
    }
    # The default reader, so the loops below have exactly one shape. A PLAIN scriptblock, deliberately not
    # .GetNewClosure(): a closure is a new dynamic module whose scope chain reaches the global scope rather
    # than this dot-sourced lib's, so a body calling a sibling lib function would stop resolving it. Plain
    # scriptblocks keep the session state they were created in and look their variables up dynamically, which
    # is what makes $RepoRoot visible here and the caller's own variables visible in a passed-in -Reader.
    if (-not $Reader) {
        $Reader = {
            param([string]$Rel)
            $full = Join-Path $RepoRoot ($Rel -replace '/', '\')
            if (-not (Test-Path -LiteralPath $full)) { return $null }
            return [System.IO.File]::ReadAllText($full, [System.Text.Encoding]::UTF8)
        }
    }
    $paths = Get-BranchFilePaths -Branch $Branch
    $trunk = Get-BranchTrunkName
    # 'File' is the name a caller uses when it means the document rather than one of its two jobs; Cycle and
    # Deployment resolve to the same path and are kept so a gate can still say WHICH half it was reading.
    $current = if ($Kind -eq 'File') { [string]$paths.File } else { [string]$paths.$Kind }
    # EVERY OTHER PER-BRANCH DOCUMENT IN THE FOLDER, so this resolver never trusts a filename to be right
    # (#1255). $current is the name this branch's document SHOULD have; these are the names one could
    # actually have -- a branch renamed after new-branch ran, a document written by hand, or a leftover from
    # a fold that was blocked. They go in AFTER $current and BEFORE the legacy names, and the declare-test
    # below is what admits or rejects each one, exactly as it does for every other candidate.
    #
    # TREE ARM ONLY, and that is a real bound rather than an oversight. Discovery means listing a directory;
    # the -Reader arm is handed a single scriptblock that reads ONE path out of a commit and cannot
    # enumerate. A caller on that arm knows its branch and passes it, so $current is the name it needs, and
    # the shared name below covers a branch that predates this change. Widening it would mean a second
    # scriptblock in every -Reader caller for a case none of them has.
    #
    # THE SWEEP ITSELF MOVED TO Get-PerBranchDocumentRels (#1335), with three other callers. It is the same
    # listing it always was, plus the exclusion the widened glob made necessary -- see ReservedNames in
    # Get-BranchFilePaths for why CHANGELOG.md is the file that makes it load-bearing here in particular:
    # the pass below returns the first candidate declaring a non-trunk branch, and every folded entry in the
    # changelog declares one.
    $discovered = @()
    if ($PSCmdlet.ParameterSetName -eq 'Tree') {
        $discovered = @(Get-PerBranchDocumentRels -RepoRoot $RepoRoot | Where-Object { $_ -ne $current })
    }
    # $current is this branch's own name; $discovered is every OTHER per-branch document in the folder
    # (tree arm only). Then the legacy names -- SharedFile, PriorNameFile, the branch/ pair, and the
    # whole pre-#886 workflow-davekjohn/ set -- from Get-BranchFileLegacyNames, the ONE ordered source
    # new-branch.ps1's writer reads too (#1259). The declare-test below admits or rejects each candidate;
    # a name being in the list only means it is looked at.
    #
    # BUILT WITH + RATHER THAN A COMMA LITERAL: @($a, $b, (Get-...)) leaves $discovered and the returned
    # list as nested Object[] elements -- an array subexpression does not flatten a sub-array reached
    # through a variable or a call -- and the foreach below would then hand a whole array to the reader as
    # one $rel. Concatenation flattens each operand one level, which is exactly the depth here.
    $candidates = @($current) + @($discovered) + @(Get-BranchFileLegacyNames -Kind $Kind -Branch $Branch)

    # Read once per candidate and remember it: the second loop asks the same question again, and on the
    # -Reader arm one question is a child process rather than a Test-Path.
    $texts = @{}
    $readCandidate = {
        param([string]$Rel)
        if (-not $texts.ContainsKey($Rel)) { $texts[$Rel] = & $Reader $Rel }
        return $texts[$Rel]
    }

    # AN EXACT MATCH WINS, WHERE THE CALLER NAMED A BRANCH (#1255), and this pass is what makes -Branch
    # authoritative rather than merely a hint. The pass below accepts ANY document declaring a non-trunk
    # branch, which was unambiguous while there was one shared path and is not any more: a trunk carrying
    # several per-branch documents -- the state a run of blocked folds leaves -- would otherwise hand the
    # fold whichever one sorted first and fold somebody else's entry under this branch's name. That is the
    # stranding hazard reported on #1255, and it is answered here rather than in each caller.
    if ($Branch) {
        foreach ($rel in $candidates) {
            if (-not $rel) { continue }
            $text = & $readCandidate $rel
            if ($null -eq $text) { continue }
            if ((Get-BranchFileDeclaredBranch -Text $text) -eq $Branch) { return $rel }
        }
    }
    # NO DOCUMENT NAMES THIS BRANCH, so fall back to the pre-#1255 question: which one names A branch. It
    # still has to be asked -- a branch RENAMED after its document was written declares its old name, and
    # refusing to see it would strand exactly the half-finished work the dual-read exists to protect.
    foreach ($rel in $candidates) {
        if (-not $rel) { continue }
        $text = & $readCandidate $rel
        if ($null -eq $text) { continue }
        $declared = Get-BranchFileDeclaredBranch -Text $text
        # A file declaring the trunk -- or declaring nothing at all -- is in its reset state and is not this
        # branch's work. Keep looking; if nothing claims the branch, the fallback below is today's file.
        if ($declared -and $declared -ne $trunk) { return $rel }
    }
    # NOTHING CLAIMS THIS BRANCH. Prefer a file that at least EXISTS over one that does not, so a reader
    # opening the result finds the reset document rather than a missing path -- and where none exists, the
    # writer's own name.
    foreach ($rel in $candidates) {
        if (-not $rel) { continue }
        if ($null -ne (& $readCandidate $rel)) { return $rel }
    }
    return $current
}

function Get-BranchFileRetiredChangelogTitles {
    <#
        The words the ENTRY's heading has carried before the current one -- 'changelog', retired on
        August 19, 2026 in favour of 'deployment'.

        NOT A SEAM, deliberately, and not merged into Get-BranchFileWording: a repo may translate the word
        it WRITES, but this list is the history of the English default, which is what every document
        already written carries. A consumer who translated 'changelog' has their own old files to read and
        can add nothing here -- so what this buys them is the same thing it buys this repo: entries written
        under the previous word keep declaring themselves as entries.

        THE STEP LIST'S OLD WORD IS NOT IN THIS LIST, and that is the whole point of keeping it separate:
        'progress' beside a branch name means the OTHER file, and admitting it here would make every step
        list ever written read as an entry -- the confusion the two-file split exists to remove.
    #>
    # 'deployment' JOINED IT ON AUGUST 23, 2026, when the entry became the development cycle's DEPLOY phase.
    # Written from August 19 to 23, 2026: every entry pending in CHANGELOG.md carries it, and so does every
    # branch in flight here and in every consumer.
    return @('deployment', 'changelog')
}

function Get-BranchFileWording {
    <#
        The prose inside the two branch files -- this repo's answers where repo-config.ps1 gives them,
        the English defaults otherwise.

        ONE GETTER RETURNING A MAP, unlike Get-EntryScaffoldWording's three separate ones, and the
        difference is deliberate rather than inconsistency. Those three are each read by a GATE that
        must match the writer string-for-string, so each is its own contract with its own name. These
        are document prose read by nobody but the reader of the file; a repo translating one translates
        all of them, and one seam function per string would be one script-contract entry per string for
        a single act. (This sentence said 'these nine' until August 10, 2026, when it was thirteen and
        gaining a fourteenth -- a count of the keys directly below it goes stale every time one is added,
        and buys a reader nothing that reading the map does not.)

        THE MERGE ITSELF IS Merge-WordingOverrides, shared with Get-EntrySignificanceWording since #941 --
        the two getters were the same loop line for line, thirty-three hundred lines apart. Both fail-safes
        are stated there, once: a key present but EMPTY is ignored, and so is a list override that leaves
        nothing usable behind (#927).
    #>
    return Merge-WordingOverrides -Defaults $script:BranchFileDefaults `
        -OverrideCommand 'Get-BranchFileWordingOverrides'
}

function Format-BranchFileHeadingLine {
    <#
        The heading line the development document and its DEPLOY section open with -- '## feat/x',
        '### DEPLOY: feat/x'.

        ONE FORMATTER FOR BOTH, because the document and its entry both write this line and
        Get-BranchFileDeclaredBranch READS it back. The branch name is the file's only machine-read fact
        outside the step marks, so the writer and the reader agreeing about the shape is not a nicety.

        THE BRANCH IS NAMED IN THE HEADING, not on a line below it (Dave, August 6, 2026). The heading has
        to say which branch this file belongs to anyway, so a separate '**Branch:**' line was the same fact
        written twice -- and Get-BranchFileDeclaredBranch reads the heading now, with the old line kept as a
        fallback for the branches already carrying one.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Branch,
        # EMPTY IS THE DOCUMENT'S OWN HEADING SINCE #1335 -- '## feat/x', the branch and nothing else. It was
        # mandatory-and-non-empty while both headings carried a title word; the entry's heading still does
        # ('### DEPLOY: feat/x'), so the parameter stays and only its floor moves.
        [Parameter(Mandatory)][AllowEmptyString()][string]$Title,
        [int]$Level = 2,
        [string]$Suffix = '',
        [string]$Lead = ''
    )
    # THE TITLE COMES FIRST, THEN A COLON, THEN THE BRANCH (Dave, August 23, 2026, by hand in the document
    # that is this format's spec): '# Development: `feat/x-v1`', '## DEPLOY: `feat/x-v1`'. It read
    # '# `feat/x` cycle' until then -- the branch first and the title trailing after it.
    #
    # WHAT THE FLIP BUYS IS THE SCANNED LINE. Both headings are read at a glance in a list -- a diff, a
    # search result, CHANGELOG.md -- and the branch name is the part that varies while the title is the part
    # that says what you are looking at. Leading with the title means the two documents announce themselves
    # in the same place every time, and the branch reads as the subject rather than as the label.
    #
    # $Lead SURVIVES AS THE WORD BEFORE THE TITLE. It was the word before the backticked branch ('Branch',
    # for three days in August 2026) and no caller sets it; it is kept rather than removed because a
    # consumer may have configured one, and a seam that silently stopped being read is worse than one that
    # still means something. Get-BranchFileDeclaredBranch reads past whatever stands here; see its regex.
    # NO BACKTICKS SINCE #1335 (Dave), AND NO TITLE ON THE DOCUMENT'S OWN HEADING: '## feat/x' and
    # '### DEPLOY: feat/x' where they read '## Development: `feat/x` * <stamp>' and '### DEPLOY: `feat/x`'.
    #
    # WHAT THE BACKTICKS WERE DOING IS THE PART THAT HAD TO BE REPLACED RATHER THAN DELETED. They were this
    # format's only delimiter, and four readers used them to find where the branch name starts and ends:
    # Get-BranchFileDeclaredBranch, Get-DevelopmentEntryPattern, Get-EntryDeclaredType and
    # Get-FoldedEntryForBranch. Each of the four now reads the bare shape too, and each does it with a
    # narrower anchor than 'a word in backticks somewhere on the line' -- the entry's heading by its title
    # word, the document's by the heading being nothing BUT a branch-shaped token. Every backticked shape is
    # still read: a branch open across this change carries one, here and in every consumer.
    $shown = if ($Branch) { $Branch } else { Get-BranchTrunkName }
    $line = ('#' * $Level) + ' '
    if ($Lead) { $line += $Lead + ' ' }
    if ($Title) { $line += $Title + ': ' }
    $line += $shown
    if ($Suffix) { $line += ' ' + $Suffix }
    return $line
}

function Format-BranchFileHeader {
    <#
        Private: the H1, the branch line and -- on the trunk only -- the warning under it. Both files
        open with exactly this, which is what makes them one recognisable pair rather than two documents
        that happen to live in a directory.

        THE WARNING IS KEYED ON THE BRANCH BEING THE TRUNK, not on the file being in its reset state,
        and those come apart in the case worth catching: someone runs `git checkout -b` by hand instead
        of new-branch, so the files are still reset while HEAD is on a real branch. Keying on the trunk
        keeps the warning off that person's screen -- they are allowed to work here -- while the empty
        step list still says the scaffold never ran.

        Returns a string ARRAY rather than the List it builds, and the callers append its lines to their
        own list. Returning the List itself does not work: PowerShell unrolls a returned collection, so
        `$lines = Format-BranchFileHeader ...` hands the caller an object[] -- fixed-size -- and every
        subsequent .Add() throws. Measured on this function's first run.
    #>
    param(
        # EMPTY SINCE #1335 for its one caller: the document's heading is the branch name alone.
        [Parameter(Mandatory)][AllowEmptyString()][string]$Title,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Branch,
        [Parameter(Mandatory)][pscustomobject]$Wording,
        # The creation stamp, already formatted with its separator. Here rather than composed by the caller
        # after the fact, because the heading is built in one place and a caller appending to the string it
        # gets back is the shape where two callers space it two ways.
        [AllowEmptyString()][string]$Suffix = ''
    )
    $trunk = Get-BranchTrunkName
    $shown = if ($Branch) { $Branch } else { $trunk }
    $lines = New-Object System.Collections.Generic.List[string]
    # THE CYCLE FILE CARRIES ITS OWN LEVEL IN BOTH STATES, and it loses nothing by that: it is never folded,
    # so no reader has to tell its two states apart by level. What does tell them apart is the branch NAME in
    # the heading -- the trunk's for a reset file, the branch's for a written one -- which
    # Get-BranchFileDeclaredBranch reads at every level.
    #
    # READ FROM THE KNOB SINCE AUGUST 26, 2026, WHERE IT WAS A LITERAL 1. The argument for the literal was
    # that Test-IsChangelogEntryFile decided "is there an entry here" on the LEVEL, so an H1 reset could never
    # be mistaken for a foldable entry. Shifting the cycle file to an H2 put it inside the range that test
    # accepts, so the guarantee had to move somewhere a re-level cannot reach: that function now answers on
    # the declared branch NAME, and returns false for the trunk before it ever looks at a heading depth. With
    # the guarantee anchored there, this line is free to follow the format.
    $lines.Add((Format-BranchFileHeadingLine -Branch $shown -Title $Title -Level (Get-BranchCycleHeadingLevel) -Suffix $Suffix))
    if ($shown -eq $trunk) {
        $lines.Add('')
        $lines.Add('')
        # THE LEAD COMES FROM THE WORDING TOO (inbound #562). It was built here, inline, which made it the
        # one fragment of these two documents a consumer could not translate. '{0}' is replaced rather than
        # formatted -- see the TrunkWarningLead default for why a hand-written seam value must not be handed
        # to a format string. A lead that is empty leaves the two warning lines standing on their own, which
        # is a legitimate answer: the heading above already names the trunk.
        $lead = [string]$Wording.TrunkWarningLead
        if ($lead) { $lead = $lead.Replace('{0}', $trunk) + ' ' }
        $lines.Add('> ' + $lead + $Wording.TrunkWarning[0])
        foreach ($line in @($Wording.TrunkWarning | Select-Object -Skip 1)) { $lines.Add('> ' + $line) }
    }
    return @($lines.ToArray())
}

# --- RETIRED, AUGUST 23, 2026: New-BranchFileLines ------------------------------------------------
#
# It handed a caller a fresh line list already carrying the shared header, and it existed because THREE
# formatters opened a file the same way -- the two resets and the progress scaffold -- and the blank line
# after the header was exactly the kind of detail that drifts between three copies.
#
# There is one formatter now. Format-Development writes the only branch document there is, and the reset
# state is that same function called with no branch, so there is nothing left for a shared opener to keep in
# agreement with. Removed rather than left standing unread, which is this file's own rule about a helper
# whose last caller has gone.

# --- RETIRED, AUGUST 23, 2026: Format-DevelopmentReset ---------------------------------------
#
# It was an alias for Format-Development with no branch, and it had three callers that each meant
# "the empty state that lives on the trunk": the fold wrote it back after folding, adopt-workflow-folder
# placed it, and this repo's lint held the trunk copy to it byte-for-byte.
#
# THERE IS NO TRUNK COPY ANY MORE (Dave, August 23, 2026). The document exists for the lifetime of a
# branch and no longer: new-branch creates it, the fold REMOVES it. So all three callers are gone -- the
# fold deletes instead of rewriting, the adopter places one file fewer, and the lint asserts absence
# instead of equality. A formatter alias with no writer left is the helper this file's own rule removes.
#
# THE STATE IT PRODUCED IS NOT RETIRED WITH IT, and that distinction is the one worth keeping. A branch
# created before this change still carries a trunk-declaring document, so Get-BranchFileDeclaredBranch
# must go on recognising one and Resolve-BranchFilePath must go on skipping it. What went is the name and
# its writers; a caller that needs such a document for a fixture calls Format-Development -Branch ''.

function Get-BranchFilesRereadNote {
    <#
        The one line a script prints after it has written or reset the two branch files: whoever had them
        open has to read them again before their next write.

        WHY THIS EXISTS (inbound #817, August 21, 2026). These two files are the only ones in a repo that a
        script and a session write ALTERNATELY, twice per branch cycle -- new-branch.ps1 creates them, the
        session writes the entry and the step list, fold-changelog-entry.ps1 resets both after the merge.
        Every one of those script writes invalidates whatever the session had tracked, so the editor's
        staleness guard refuses the next write until the file is read again. Measured in one session over
        three full cycles: 2 refused writes, 3 stale notices, 0 cases of anything actually lost. The
        refusal lands on the FIRST write after a script touched the file, which in practice means the
        second and later branches of a session rather than the first.

        AND WHAT IT DELIBERATELY DOES NOT DO. The refusal itself is the harness's, and it is correct: it is
        what stops a session overwriting an out-of-band change it never saw. Nothing in this tree, no seam
        and no hook can change when it fires, and a repo-side "fix" that suppressed it would be removing a
        working safety check to tidy up a log line. So the subject here is legibility, not correctness --
        the recovery was always automatic and cost one read; what it cost was reading as a broken tool in
        the one place a reader is already looking at those exact paths.

        ONE SOURCE BECAUSE TWO SCRIPTS PRINT IT. The doc half of the same report is in DEVELOPMENT-portable.md,
        which reaches the session that did NOT run the script; these are not alternatives.
    #>
    return 'Note: rewritten just now -- re-read these before editing them, or the next write is refused as stale.'
}

function Add-BranchProgressSection {
    <#
        Private: one of the cycle file's OWN sections -- a phase heading, or Where I left off. Heading,
        the guidance comment directly under it, then the body. Appends to the caller's list.

        THE COMMENT SITS TIGHT AGAINST ITS HEADING, exactly as the entry's sections do (Add-EntrySection).
        It used to take a blank line first, on the reasoning that a block of prose stands on its own while a
        one-line hint belongs to its heading -- and the two files then spaced the same construction two
        different ways. Dave settled it on August 19, 2026 by hand, in the templates that are this format's
        spec: tight, in both files. The one block that keeps a blank line above it is the guidance under the
        file's OWN heading, which explains the document rather than a section of it.

        THE HORIZONTAL RULES ARE GONE with the dossier form. They separated five H2 sections; the headings
        do that work themselves now, while a '---' between every pair turned a short file into a ruled form.

        THE LEVEL COMES FROM Get-BranchCycleSectionLevel, not from the entry's. The two were the same
        number until Dave promoted this file's whole structure by hand on August 19, 2026 -- an H1 title
        over H2 sections, because the cycle file is a document rather than a block waiting to be pasted
        into one. Sharing the entry's constant would have re-levelled the entry along with it.
    #>
    param(
        [Parameter(Mandatory)]$Lines,
        [Parameter(Mandatory)][string]$Heading,
        [AllowEmptyCollection()][string[]]$Guidance = @(),
        [AllowEmptyCollection()][string[]]$Body = @()
    )
    $Lines.Add(('#' * $script:BranchCycleSectionLevel) + ' ' + $Heading)
    $rendered = @(Format-EntryGuidanceComment -Lines $Guidance)
    foreach ($line in $rendered) { $Lines.Add($line) }
    $body = @(@($Body) | Where-Object { $null -ne $_ })
    if ($body.Count -gt 0) {
        $Lines.Add('')
        foreach ($line in $body) { $Lines.Add($line) }
    }
    $Lines.Add('')
}

function Format-Development {
    <#
        The branch's development document, whole: its heading, which since #1335 is the branch's own name
        and nothing else, the guidance that explains the marks and the arc, the three phases that carry the
        steps, and the DEPLOY section that IS the changelog entry.

        ONE DOCUMENT SINCE AUGUST 23, 2026 (Dave), REPLACING Format-BranchProgressScaffold AND
        Format-EntryBlock'S OWN FILE. The step list and the entry lived in two files under branch/; they are
        two sections of this one. What that buys is the thing neither file could give on its own: the plan a
        branch is working through and the claim it will make are on one screen, so an author who has ticked
        the last box is looking at the paragraph they have to write next.

        THE ENTRY IS STILL ITS OWN FORMATTER, and that separation is load-bearing rather than tidiness.
        Format-EntryBlock renders exactly the block the fold moves into CHANGELOG.md, so the fold can take a
        SECTION of this document verbatim without a second definition of the entry format living inside it --
        the drift shape this repo has paid for in the fence readers, the scaffold wording and the tier
        sections. One shape, written once, read everywhere.

        NO -Template SWITCH ANY MORE, and its disappearance is the point rather than a side effect. A
        template existed because the working file deliberately carried no guidance: the comments lived in
        branch/templates/, a file beside the one you write in. Inbound #810 is what that cost -- an author met
        the guidance in the neighbour or not at all, and wrote two pages of prose under a heading whose own
        hint said the short answer was normal. The guidance is in the document now, in both states, and the
        fold strips comments (Remove-EntryHtmlComments) so none of it ever reaches CHANGELOG.md.

        SO THE TRUNK STATE IS THE REFERENCE. What separates it from a branch's file is not guidance but
        FACTS: the trunk's name in the heading instead of a branch's, the warning under it, no scaffolded
        step, and placeholder text where the two stamps go. Everything a reader would have opened the
        template for is in the file already sitting on their trunk.

        -Intent IS THE PARKING NOTE, and it is a headingless paragraph leading the FIRST PHASE. The
        'Where I left off' heading went with the merge (Dave: an unticked box already says where you left
        off), and he is right about the ordinary case -- but a parked branch has something the step list
        genuinely cannot hold, which is what you decided and have not written down anywhere yet. So it keeps
        its place and loses its heading.

        ITS PLACE IS INSIDE PLAN, NOT ABOVE IT, SINCE #908 (August 26, 2026). It was a paragraph at the top
        of the document, which is the one region the guidance block a few lines above it declares generic --
        and check-branch-entry.ps1's #899 check reads that region in every repo, so a document carrying an
        intent was refused by CI as soon as its entry was written. See the block at the emission site for
        the measurement and for why the anchor is the first phase by position rather than the word 'PLAN'.
    #>
    param(
        [AllowEmptyString()][string]$Branch = '',
        [string]$Intent = '',
        # NO -Id ANY MORE (#1335). It was the branch's creation stamp and its only destination was the
        # heading suffix this document no longer carries. Removed rather than accepted and ignored, which is
        # this file's own rule for a knob whose last reader has gone: a caller still passing it now gets a
        # parameter-binding error instead of a stamp that silently goes nowhere.
        # Passed straight through to Format-EntryBlock -- a migration rendering a finished entry into this
        # document has all four in hand, and the scaffolder has none of them.
        [string]$Description = '',
        [string]$Type = '',
        [string]$Body = '',
        $ImpactRows = @(),
        # Where the entry's text lands, repo-root-relative -- the directory of the changelog the fold writes
        # into, '' being the repo root. It shapes ONE line of the guidance: the base a relative link in the
        # DEPLOY section has to resolve from.
        #
        # A PARAMETER RATHER THAN A SEAM READ IN HERE, deliberately (inbound #967). Every other reader of
        # Get-ChangelogPath in this workflow -- cut-release, fold-changelog-entry and
        # adopt-workflow-folder -- resolves it in the SCRIPT and passes the answer in, because the default needs a
        # repo root and a lib that goes looking for one is a lib that can find the wrong tree. new-branch
        # does the same; the default keeps every other caller, the suites included, on today's wording.
        [string]$LinkDestDirRel = ''
    )
    $w      = Get-BranchFileWording
    $trunk  = Get-BranchTrunkName
    $shown  = if ($Branch) { $Branch } else { $trunk }
    $onTrunk = ($shown -eq $trunk)

    # NO CREATION STAMP AND NO TITLE IN THE HEADING SINCE #1335 (Dave). It read
    # '## Development: `feat/x` * 20260903-152650'; it is '## feat/x'. The stamp was the branch's birth
    # moment, written here and read by nothing -- the changelog's own ordering keys on the MERGE stamp
    # (Get-EntryHeadingStamp, on the Pull Request heading), and the one place the creation stamp was ever
    # used was a measurement taken by hand over 38 merged branches. So it goes, and -Id goes with it rather
    # than being kept as a parameter no caller can spend.
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($line in (Format-BranchFileHeader -Title '' -Branch $shown -Wording $w)) {
        $lines.Add($line)
    }
    $lines.Add('')

    # THE GUIDANCE FOR THE LIST STANDS UNDER THE FILE'S OWN HEADING, not under a section of its own. It
    # explains the whole document -- the marks, the arc, why DEPLOY takes no steps -- and the '### Steps'
    # heading it used to hang from was a wrapper around everything below it. This is the one guidance block
    # in the file that keeps a blank line above it, for that reason: it belongs to the file, not to a heading.
    # EMITTED AS-IS, NOT WRAPPED IN A COMMENT (Dave, August 23, 2026). The block is visible markdown now --
    # see StepsGuidance for why the DEPLOY-section blocks went empty instead of coming along -- so it must
    # NOT go through Format-EntryGuidanceComment, whose whole job is to add the markers this block must not
    # have. A consumer override is emitted the same way, so a repo that translated it keeps its own prose.
    # THE AUDIENCE SENTENCE COMES ALONG, RESOLVED PER REPO (Dave, August 23, 2026). It used to live in the
    # TierOptional comment under the second tier's heading; that block is empty now, and dropping the sentence
    # with it would have cost the one line that names WHO this repo's audience tier is -- per repo, which is
    # the whole point of the seam. In a tier-1 consumer it is the only place their reader is named at all.
    #
    # SO THE SEAM STAYS ALIVE and is read here instead: the '{0}' line in StepsGuidance goes through
    # Format-EntryAudienceGuidance exactly as it did below, so a consumer's own Get-ReleaseAudienceDescription
    # still answers it and nothing about that contract changed. A repo that asks about NO audience tier gets
    # the WHOLE audience paragraph removed rather than a dangling '{0}' -- Get-EntryAudienceTier returns
    # $null there, and a placeholder nobody can fill is worse than a sentence nobody needs. Dropping only the
    # seam LINE was issue #928: its two continuation lines stayed behind and went on finishing a sentence
    # that was no longer there. Remove-EntryAudienceGuidance carries why the paragraph is found by shape.
    $audienceTier = Get-EntryAudienceTier
    $stepsBlock = if ($null -ne $audienceTier) {
        @(Format-EntryAudienceGuidance -Lines @($w.StepsGuidance) -Tier $audienceTier)
    } else {
        @(Remove-EntryAudienceGuidance -Lines @($w.StepsGuidance))
    }
    # AND THE LINK SENTENCE, from the destination this repo's fold actually writes to (inbound #967). After
    # the audience pass rather than before it, so an override that put both tokens on one line is resolved
    # whichever order they sit in -- each pass only touches its own token.
    $stepsBlock = @(Format-EntryLinkGuidance -Lines $stepsBlock -DestDirRel $LinkDestDirRel)
    foreach ($line in @($stepsBlock | Where-Object { $null -ne $_ })) { $lines.Add([string]$line) }
    $lines.Add('')

    # -INTENT IS WRITTEN INSIDE THE FIRST PHASE, NOT ABOVE IT (#908, August 26, 2026). It used to sit right
    # here, between the guidance and the phases -- and the guidance printed a few lines earlier says NOTHING
    # BRANCH-SPECIFIC ABOVE the first phase heading, naming "a note about THIS branch" as its own example and
    # "normally as a sub-heading in PLAN" as the destination. So the scaffolder stated the rule and broke it
    # in the same file, two screens apart.
    #
    # AND THE COST WAS NOT TIDINESS, which is why this is a fix rather than a polish. The #899 check in
    # check-branch-entry.ps1 READS that region, and unlike its heading-count sibling it is deliberately NOT
    # scoped to this repo -- it reads the SHAPE (a non-blank line that does not start with '>'), so it
    # survives translation and holds in every consumer. Measured on the real gate before this change, on a
    # document generated with -Intent and its entry filled in: exit 1, "carries branch content above the
    # first '##'", naming the intent line. The gate is silent on a FRESH scaffold only because the
    # unwritten-entry check refuses first -- so the failure surfaces the moment the entry is written, which
    # is at the PR. Every consumer that passed -Intent had a branch CI would not let through.
    #
    # THE FIRST PHASE BY POSITION, NOT THE LITERAL 'PLAN'. StepPhases is a seam a consumer may rename or
    # translate, and this file already reads phase names from the wording rather than typing them -- the same
    # reason check-branch-entry.ps1 names the arc from Get-BranchFileWording instead of from three literals.
    # Position is also the honest anchor: the planning phase is the one the preamble points at, and the one
    # that is otherwise EMPTY, because the scaffolded step goes under FirstStepPhase (CREATE).
    #
    # AND STILL NO HEADING OF ITS OWN (Dave, August 23, 2026). 'Where I left off' was retired that day --
    # an unticked box already says where you left off -- with the note that a parking record "keeps its place
    # and loses its heading". Its place is inside the first phase now; the headinglessness is unchanged, and
    # the preamble's "normally" leaves room for it, because the gate reads only the region ABOVE the first
    # phase heading and nothing below it.
    $intentLines = @()
    if ($Intent) { $intentLines = @($Intent -split '\r?\n') }

    # THE SCAFFOLDED STEP STAYS IN THE FILE A BRANCH ACTUALLY GETS (Dave, August 6, 2026). Without it a fresh
    # branch reaches a PR with no plan at all and the step-list gate has nothing to refuse --
    # Get-BranchProgressFindings reports only steps somebody wrote, and "no step list at all" is a
    # deliberately permitted state for the one-commit typo fix. One open step is what makes the gate bite on
    # the ordinary branch while leaving that case alone. The TRUNK copy carries none, for the reason the
    # template carried none: it is read as an example, and an example whose first line is somebody else's
    # TODO gets copied in.

    # THE ARC CANNOT BE EMPTIED, AND THIS IS THE OTHER HALF OF THAT (#927, August 26, 2026). The branch
    # retired from here wrote the scaffolded step with NO heading above it whenever the phase list came
    # back empty -- the pre-#655 shape -- and that put the step in the region check-branch-entry.ps1's
    # #899 check calls the preamble. Every branch in such a repo was refused with no way through but
    # deleting the step this function had just written. Get-BranchFileWording now ignores an override that
    # leaves no usable phase behind, so the seam cannot reach that state at all; this fallback covers the
    # caller who replaced the getter outright, which is how the case was measured.
    #
    # ZERO PHASES IS A BROKEN SETTING, NOT A CONFIGURATION, so it gets the answer the seam gives one layer
    # up: keep the default. The arc is not decoration -- it is the shape the gate reads and the fold folds --
    # so a document without it is refused wherever it goes. Writing the default three is visibly wrong in a
    # repo that renamed them, and visible is the point; writing nothing would silently DROP a parked
    # branch's intent, which is the one thing in this file nobody can reconstruct afterwards.
    #
    # AND THE STEP IS ANCHORED ON MEMBERSHIP, NOT ON A NAME, which is a defect of its own that predates
    # #927 and was found by its test. FirstStepPhase used to be compared straight against each phase, so a
    # value naming no phase in the arc -- a typo, a rename that moved one and not the other, or the arc
    # falling back to the defaults while this key kept a consumer's own word -- matched nothing and the
    # scaffolded step was DROPPED. Silently: the document is well-formed, every gate is green, and the
    # branch simply arrives with no plan in it. That is the worse failure of the two this block guards
    # against, because a refused document tells you what to fix.
    $phases = @($w.StepPhases | Where-Object { $_ })
    if ($phases.Count -eq 0) { $phases = @($script:BranchFileDefaults.StepPhases | Where-Object { $_ }) }
    $firstStepPhase = $w.FirstStepPhase
    if ($phases -notcontains $firstStepPhase) {
        # The default name where the arc carries it, and otherwise the arc's OWN first phase -- never a
        # heading this document does not have. A consumer who renamed the arc and forgot this key gets their
        # step in their own first phase, which is where a reader of a fresh branch looks anyway.
        $firstStepPhase = if ($phases -contains $script:BranchFileDefaults.FirstStepPhase) {
            $script:BranchFileDefaults.FirstStepPhase
        } else { $phases[0] }
    }
    foreach ($phase in $phases) {
        $phaseBody = @()
        if ((-not $onTrunk) -and $phase -eq $firstStepPhase) {
            $phaseBody = @((Get-BranchProgressMarks).Open + $w.FirstStep)
        }
        # The parking note LEADS the first phase. The blank line between it and a step is needed only
        # where both land in the same phase -- they do not by default, since FirstStepPhase is CREATE,
        # but a consumer may point both at one and a note glued to a checkbox reads as its label.
        if ($intentLines.Count -gt 0 -and $phase -eq $phases[0]) {
            $lead = if ($phaseBody.Count -gt 0) { @($intentLines) + @('') } else { @($intentLines) }
            $phaseBody = @($lead) + @($phaseBody)
        }
        $phaseGuidance = @()
        if ($w.StepPhaseGuidance -and $w.StepPhaseGuidance.Contains($phase)) {
            $phaseGuidance = @($w.StepPhaseGuidance[$phase])
        }
        Add-BranchProgressSection -Lines $lines -Heading $phase -Guidance $phaseGuidance -Body $phaseBody
    }

    # AND THE FOURTH PHASE, WRITTEN BY THE FORMATTER THAT OWNS WHAT GOES IN IT. Its heading carries the
    # branch name, which is what makes the block self-describing once it has been folded into CHANGELOG.md
    # and knows nothing about the document it came from.
    foreach ($line in (Format-EntryBlock -Branch $shown -Description $Description -Type $Type `
        -Body $Body -ImpactRows $ImpactRows -Placeholder:$onTrunk)) { $lines.Add($line) }

    return @($lines.ToArray())
}
function Get-BranchFileDeclaredBranch {
    <#
        Pure: the branch a branch file says it belongs to -- the name in its '**Branch:** `x`' line -- or
        '' when the file has no such line.

        THIS IS THE IDEMPOTENCY TEST, and it is why the branch line is in the document rather than only in
        the scaffolder's head. new-branch.ps1 may be run twice on the same branch (it is, by
        new-branch, which is itself idempotent), and the second run must not overwrite a step list somebody
        has been ticking off. Comparing the declared branch against HEAD answers that exactly: the trunk
        name means the file is still in its reset state and is ours to write, any other name means it is
        already someone's working file.

        The label is read from the wording rather than hardcoded, so a repo that translated it can still be
        recognised -- a predicate that only knows the English label would read every file in a translated
        repo as unscaffolded and overwrite it.

        -OpeningHeadingOnly STOPS THE HEADING SCAN AFTER THE DOCUMENT'S FIRST HEADING (inbound #1099), and it
        exists for exactly one caller: the release cut's scan of a repo's ROOT *.md files. That scan asks a
        different question from every other caller here. The others hand this function a document they already
        know is a branch document, at a fixed path, and want the branch out of it -- for which the widest
        possible reading is right, and the comments below say at length why narrowing it is the expensive
        direction. The root scan hands it an ARBITRARY document and asks whether it is one at all, and there
        the width is what breaks: any `##` heading carrying a backticked word -- '## Deploying `web`',
        '## The `build` step' -- reads as a branch declaration, so an ordinary run log or ADOPTION.md is
        reported as an unfolded entry. Measured in a live consumer, on a heading reading
        '## Step 3 -- `specialists-init` * **PASS**'.

        THE OPENING HEADING IS THE HONEST NARROWING, rather than anchoring a lead word. Every shape this
        predicate reads declares its branch in the document's OWN first heading -- '# `feat/x` progress',
        '## Branch `feat/x` changelog', '## Development: `feat/x-v1`' -- so nothing an entry can be is lost,
        while a document whose first heading is a plain '# Title' stops being read past it. A lead-word anchor
        would have been the narrowing this predicate's own comments forbid: the title is a wording seam, a repo
        may set it to anything, and branches open across a rename carry titles no list holds.

        THE '**Branch:**' FALLBACK IS NOT NARROWED, deliberately -- and WHICH FILE IT ANSWERS FOR was
        mis-stated here until September 8, 2026 (#1642). It is the shape the pre-split PER-BRANCH files
        carried: 'branch/branch-changelog.md' and 'branch/branch-progress.md', whose own titles were the
        H1s '# Branch changelog' and '# Branch progress', with '**Branch:** `feat/x`' on a line BELOW that
        title. That is why the opening-heading narrowing cannot see it and this fallback has to stay wide.

        IT IS NOT THE PRE-SPLIT ROOT ENTRY, which is what this claimed and what the two sibling comments
        below cited: of the 344 root entries in this repo's history, 0 carry a '**Branch:**' line and 0 open
        with an H1 (334 open at H3, 10 at H2) -- and the root scan is non-recursive, so 'branch/' was never
        in its reach either. THAT COUNT NEEDS NO DATE FILTER, which is worth saying because the sentence
        above hands you one: no root entry was ever added AFTER the split, so 344 is the whole population and
        a '--until' boundary removes nothing. A re-measurement that applies one splits the 10 H2 files across
        it -- they were written in the flat window itself -- and comes out disagreeing with this comment
        about the very numbers it cites. Measured that way once already, on this branch's own review.

        WHAT SURVIVES as the reason to leave the fallback un-narrowed for that scan is the regex alone: it
        is anchored end to end, so it cannot collide with ordinary prose the way the heading pattern can.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [switch]$OpeningHeadingOnly
    )

    # TWO SHAPES, ONE WRITTEN. The branch is named in the file's H1 -- '# `feat/x` progress' -- since
    # August 6, 2026, because that heading has to say which branch this is anyway and a second line
    # repeating it is one fact in two places. Before that it was a '**Branch:** `feat/x`' line, and every
    # branch in flight still carries one, here and in every consumer.
    #
    # The heading wins where both are present: it is the one a writer edits.
    #
    # BOTH LEVELS, because a reset file is an H1 while a written ENTRY is an H2 -- the difference the fold
    # keys on to tell an empty trunk file from an entry. This predicate must read them BOTH: it is the
    # idempotency test, and a scaffolded H2 file it could not read would come back as '' and be overwritten,
    # taking a step list somebody had been ticking off with it. An H1-only regex was correct for exactly the
    # few hours in which both files opened with one.
    #
    # AND PAST AN OPTIONAL LEAD WORD (August 16, 2026), because the changelog entry's heading gained one:
    # '## Branch `feat/x` changelog'. The progress file's did not, so both shapes have to read -- and
    # getting this wrong is the expensive direction rather than the loud one. A regex that could not see
    # past 'Branch ' would answer '' for every scaffolded entry, which reads as "still in its reset state"
    # and hands the next run permission to overwrite a file somebody has been writing in.
    # ANYTHING UP TO THE FIRST BACKTICK, since August 23, 2026, because the heading now leads with its title
    # and titles could be more than one word: '# Development cycle: `feat/x-v1`'. The regex allowed exactly
    # one optional word before the backtick, which read the one-word '## DEPLOY: `x`' and not the two-word
    # H1 -- and a predicate that cannot read the title line answers '' for every scaffolded document, which
    # is exactly the state that hands the next run permission to overwrite somebody's work.
    #
    # THAT EXAMPLE IS HISTORICAL SINCE AUGUST 27, 2026 AND THE WIDTH STAYS, which is the part worth writing
    # down. #963 renamed the title to the one-word 'Development', so today's heading would fit the old
    # one-word regex again -- and narrowing it back would be the same mistake in the other direction: the
    # title is a WORDING SEAM (BranchFileWording), a repo may set it to anything, and every branch open
    # across four days of renames still carries a two-word one. The rule is that the title's length is not
    # this predicate's business, and a rename that happens to shorten it does not make it so.
    #
    # EVERY LEVEL AND EVERY SHAPE, because this is the idempotency test and getting it wrong is the expensive
    # direction rather than the loud one. It reads '# `feat/x` cycle' (branch first, until August 23),
    # '## Branch `feat/x` changelog' (a lead word, for three days in August), and today's title-first form.
    #
    # THE RANGE IS 1..3 SINCE AUGUST 26, 2026, when both level pairs shifted one down. The levels it has to
    # cover, and none of them is optional: a cycle file's title is an H2 today and an H1 before the shift, an
    # entry's own heading is an H3 today and an H2 before it, and a reset file is an H1 in every era. A
    # document written on either side of the shift has to be read, because the fold that runs after THIS
    # branch merges will meet a cycle file scaffolded at the old levels -- and so will every consumer with a
    # branch in flight when the plugin updates under them.
    #
    # WIDENING IT COSTS NOTHING BECAUSE THE FIRST MATCH WINS. Every branch document and every entry block
    # opens with its own heading, so a deeper heading further down is never reached; callers pass a whole
    # file or a whole entry, never a fragment starting mid-document. That is also why this may be a range
    # while Get-EntryHeadingPattern must not be one -- that pattern scans a document for EVERY entry
    # boundary, so an entry's own inner sections would parse as siblings. This one stops at the first hit.
    $headingRx = '^#{1,3}\s+[^`]*`([^`]+)`'
    $anyHeadingRx = '^#{1,6}\s'
    $label = (Get-BranchFileWording).BranchLabel
    $lineRx = '^\*\*' + [regex]::Escape([string]$label) + ':\*\*\s*`([^`]+)`\s*$'

    # THE TWO UNBACKTICKED SHAPES (#1335), and they are separate patterns because they are separately safe.
    # The heading lost its delimiters, so "a word in backticks somewhere on this line" is not available any
    # more and each shape has to bring its own anchor.
    #
    #   $entryRx  -- '### DEPLOY: feat/x', optionally with the merge stamp after it. ANCHORED ON THE TITLE
    #                WORD, which is as narrow as the backticks were: an ordinary heading does not open with
    #                the entry's own title and a colon. Every word this title has carried is accepted, for
    #                the reason Get-BranchFileRetiredChangelogTitles exists.
    #   $bareRx   -- '## feat/x', the document's own heading: the whole heading is one token and nothing
    #                else. THE SLASH IS REQUIRED, and that is the honest narrowing rather than a guess about
    #                branch names. Without it this pattern reads '## Overview' as the branch 'Overview' --
    #                the exact class of false positive inbound #1099 was filed for, now reachable again
    #                because the format stopped delimiting. A prefixed branch is what this workflow's own
    #                branch table requires ('feat/', 'fix/', 'docs/'), and a repo whose branches carry no
    #                slash is NOT stranded: its document's DEPLOY heading still declares it through
    #                $entryRx a few lines further down, which is why the loop below keeps looking instead of
    #                stopping at the first heading it fails to read.
    $clTitles = @(@([string](Get-BranchFileWording).ChangelogTitle) + @(Get-BranchFileRetiredChangelogTitles) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $titleAlt = ((@($clTitles) | ForEach-Object { [regex]::Escape([string]$_) }) -join '|')
    # The tail is '<sep> anything', not '<sep> one token': the merge stamp is one token in a real entry and
    # a whole sentence in the reference state ('<timestamp of the moment this branch was merged>'). A tail
    # that only accepted the real one read the reference document as declaring no branch at all -- which is
    # the reset state, and reads as "ours to overwrite". Caught on this function's first run.
    $entryRx = if ($titleAlt) {
        '^#{1,3}\s+(?:[^`:]*\s)?(?:' + $titleAlt + '):\s+([^\s`]+)(?:\s+' +
            [regex]::Escape($script:EntryIdSeparator) + '\s+.*)?\s*$'
    } else { $null }
    $bareRx = '^#{1,3}\s+([^\s`]+/[^\s`]+)\s*$'

    $fallback = ''
    $sawHeading = $false
    foreach ($line in ($Text -split '\r?\n')) {
        if ($line -match $anyHeadingRx) {
            if (-not ($OpeningHeadingOnly -and $sawHeading)) {
                if ($line -match $headingRx) { return $Matches[1] }
                if ($entryRx -and $line -match $entryRx) { return $Matches[1] }
                if ($line -match $bareRx) { return $Matches[1] }
            }
            $sawHeading = $true
        }
        if ((-not $fallback) -and $line -match $lineRx) { $fallback = $Matches[1] }
    }
    return $fallback
}

$script:BranchProgressMarks = [ordered]@{
    Open    = '- [ ] '
    Done    = '- [x] '
    Dropped = '- [~] '
}

function Get-BranchProgressMarks {
    <# The three step marks, as one object: Open, Done, Dropped. One owner, because the writer of the
       scaffold, the gate that refuses an open step and the README that teaches the convention all have
       to mean the same three strings. #>
    return [pscustomobject]$script:BranchProgressMarks
}

function Get-BranchProgressStepLines {
    <#
        Pure: the lines of a branch document that MAY carry a step, left-trimmed, prepared once.

        THE PREPARATION IS THE SUBJECT, not a convenience. "What counts as a step" is three rules, and
        every one of them was learned from a false accusation:

          * ABOVE THE DEPLOY HEADING, AND ONLY THERE (August 23, 2026). The step list and the entry are
            sections of one document now, so a checkbox written into the entry's PROSE would otherwise
            hold up the PR -- and it cannot be resolved, because it is a sentence rather than a step. An
            entry legitimately describes work in that shape ("- [ ] not done yet" appears in this repo's
            own guidance). A legacy cycle file has no DEPLOY section, so Split-Development hands
            back the whole text and such a branch is read exactly as it always was.
          * FENCE-AWARE, like every reader of this format: a step list may quote the convention it
            follows -- this repo's own README does -- and a guard that cannot tell a quote from a real
            step gets switched off by the first person it accuses wrongly.
          * COMMENT-AWARE, and this is the sharper case. The Steps section's own guidance shows all three
            marks as examples, '- [ ] not done yet' among them, inside an HTML comment. Reading those as
            steps meant a freshly scaffolded list reported FOUR open steps: its own real one plus three
            the form was using to explain itself. Worse than noise, because the three cannot be resolved
            -- they come back with the next scaffold, so the only way past the gate is to delete the
            instructions.

        OWNED HERE RATHER THAN IN THE TWO READERS, and it used to live inside Get-BranchProgressFindings
        alone. Get-BranchProgressTally (#960) is the second reader, and a second copy of these three
        rules is the shape where a gate and a report disagree about what a plan says -- the gate refusing
        a step the report never counted, or the report calling a plan finished that the gate holds open.
        One preparation, two questions asked of it.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    $head = (Split-Development -Text $Text).Head
    $body = Remove-EntryHtmlComments -EntryText (Get-EntryTextOutsideFences -EntryText $head)
    return @(($body -split '\r?\n') | ForEach-Object { $_.TrimStart() })
}

function Get-BranchProgressTally {
    <#
        Pure: how the step list stands, as an object -- Open, Done, Dropped, Resolved (Done + Dropped)
        and Total. The counting half of the same question Get-BranchProgressFindings asks as a verdict,
        over the same prepared lines.

        WHY A COUNT AND NOT JUST THE VERDICT (issue #960). The gate needs one bit -- is anything still
        open -- and a REPORT needs the shape: 'seven of eight resolved' is what tells a reader on another
        device whether the plan in front of them claims to be finished. The park commit's backing note is
        the caller this exists for, and Total is what lets it say 'no steps in this document yet' rather
        than reporting a plan that has not been written as a plan with nothing done.

        A PLACEHOLDER STEP IS COUNTED BY ITS MARK, deliberately, and that is the one place this differs
        from the findings reader. There, a resolved step still carrying the scaffold's words is a
        FINDING -- it reports a plan as finished that was never written. Here it is a tick, because the
        note this feeds is about what is BEHIND the ticks: a document whose only step is the untouched
        stub, ticked, is exactly the misleading shape the note has to be able to describe. The gate
        refuses it; the report describes it. Both readings are correct for their own caller.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    $marks = Get-BranchProgressMarks
    $open = 0; $done = 0; $dropped = 0
    foreach ($line in (Get-BranchProgressStepLines -Text $Text)) {
        if ($line.StartsWith($marks.Open)) { $open++ }
        elseif ($line.StartsWith($marks.Done)) { $done++ }
        elseif ($line.StartsWith($marks.Dropped)) { $dropped++ }
    }
    return [pscustomobject]@{
        Open     = $open
        Done     = $done
        Dropped  = $dropped
        Resolved = $done + $dropped
        Total    = $open + $done + $dropped
    }
}

function Get-BranchProgressFindings {
    <#
        Pure: the reasons this step list is not finished, as objects with Label, Line and Remedy.
        Empty means every step has been resolved -- ticked or deliberately dropped.

        TWO KINDS OF FINDING, and the second is what stops the gate from being a formality:

          * an OPEN step ('- [ ] ') -- work that was written down and has not been resolved;
          * a step still carrying the SCAFFOLD's placeholder text, ticked or not. Ticking the
            scaffolded first step without replacing it is the exact shape the entry's own scaffold gate
            was measured on at v3.2.0 (author keeps the stub, appends a status), and here it would be
            worse: it reports a plan as finished that was never written.

        '- [~] ' IS THE SANCTIONED WAY PAST A STEP THAT TURNED OUT NOT TO BE NEEDED, and it exists
        because the alternative is worse than no gate. A plan legitimately grows items that stop making
        sense; with only two marks available the gate teaches people to tick boxes for work they did not
        do, and then it reports success. A dropped step keeps its line and its reason on the page, which
        is the half that is actually worth reading later.

        WHICH LINES COUNT AS STEPS AT ALL -- above the DEPLOY heading, outside fences, outside HTML
        comments -- is Get-BranchProgressStepLines's answer, not this function's, and each of those three
        rules was learned from a false accusation. Its docstring carries them; asking it rather than
        preparing the text here is what keeps this gate and the tally beside it from disagreeing about
        what a plan says.

        AND EACH FINDING CARRIES THE ACT THAT RESOLVES IT, in Remedy, because the two are resolved by
        DIFFERENT acts and both printers used to append one shared paragraph to both. Measured on a virgin
        repo walking the cycle for the first time (inbound #1081): the author hit 'still open' on the
        scaffolded line, followed the printed advice exactly -- '- [~]' plus a reason -- and was refused
        again by the same gate, printing the same four lines that had just failed. A mark is what resolves
        an open step; the placeholder is resolved by REPLACING the text or deleting the line, and no mark
        can do it. The advice was a loop, and on a fresh repo the one sentence it was emphatic about
        ("there is no -Force for this gate") reads as "you are stuck" rather than "you have used the wrong
        tool for this finding". The labels were already separate in the data; only the advice was shared.

        IT IS BUILT HERE RATHER THAN IN THE PRINTERS for the reason the labels are: two callers print
        these findings (open-pr's push gate and ship-pr's merge gate), and a remedy composed twice is a
        remedy that drifts. The marks come from the wording seam, so a repo that translated them gets its
        own characters back in the sentence.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    $marks = Get-BranchProgressMarks
    $placeholder = (Get-BranchFileWording).FirstStep

    $openRemedy = "Mark it '$($marks.Done.Trim())' when it is done, or '$($marks.Dropped.Trim())' with the reason it turned out not to be needed."
    # NOT 'delete it' ALONE, and not 'mark it' at all: the line is the scaffolder's sentence, so the act is
    # to say what this branch actually did there -- deleting is the answer only when the plan outgrew it.
    $scaffoldRemedy = "Not resolved by a mark: this line still says what the scaffolder wrote. Replace its text with the step you actually took, or delete the line if the plan grew past it."

    $findings = @()
    foreach ($trimmed in (Get-BranchProgressStepLines -Text $Text)) {
        if ($trimmed.StartsWith($marks.Open)) {
            $findings += [pscustomobject]@{ Label = 'still open'; Line = $trimmed; Remedy = $openRemedy }
        } elseif ($placeholder -and $trimmed.Contains($placeholder)) {
            # Reached only for a ticked or dropped line, since an open one is already reported above --
            # so this says "resolved, but it still says what the scaffold wrote", which is the lie.
            $findings += [pscustomobject]@{ Label = 'still the scaffolded step'; Line = $trimmed; Remedy = $scaffoldRemedy }
        }
    }
    return $findings
}

function Get-DevelopmentEntryPattern {
    <#
        The regex matching the DEPLOY heading -- the line where the development document stops being the
        branch's plan and starts being the entry that folds into CHANGELOG.md.

        IT IS NOT ENOUGH TO MATCH THE LEVEL, which is why this is a function rather than a constant. PLAN,
        CREATE and TEST sit at the cycle file's section level too; what separates the fourth is that it
        carries the entry's own title word, a colon and the BRANCH NAME. The title word comes from the wording seam, so a repo that translated
        'DEPLOY' is matched by its own word -- and every title this document has carried is accepted, because
        a branch created before a rename still has to be foldable.

        THE LEAD WORD IS OPTIONAL, for the same reason Get-BranchFileDeclaredBranch reads past one: the
        entry's heading briefly carried '## Branch `feat/x` changelog', and Get-BranchFileWording still
        offers ChangelogHeadingLead as a knob.
    #>
    $w = Get-BranchFileWording
    $titles = @(@([string]$w.ChangelogTitle) + @(Get-BranchFileRetiredChangelogTitles) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $titleRx = ($titles | ForEach-Object { [regex]::Escape([string]$_) }) -join '|'
    # A RANGE, AND THE DOCSTRING ABOVE IS WHY IT IS SAFE HERE. Matching the level is explicitly not enough --
    # the heading also has to carry the branch name in backticks and the entry's title word -- so accepting
    # one level shallower cannot pull in PLAN, CREATE or TEST, which carry neither. That is the difference
    # between this pattern and Get-EntryHeadingPattern, which is an exact level precisely because it has
    # nothing but the level to go on.
    #
    # IT HAS TO BE A RANGE SINCE AUGUST 26, 2026, and this branch is the proof: the document that folds THIS
    # change was scaffolded at the old levels, so a pattern pinned to the new one would fail to find its own
    # DEPLOY heading at the merge. Same for every consumer holding a branch when the plugin updates.
    $level = '^#{' + ($script:EntryHeadingLevel - 1) + ',' + $script:EntryHeadingLevel + '}\s+'
    # TWO SHAPES, ONE WRITTEN. Today's heading leads with the title and a colon and may close with the merge
    # stamp -- '## DEPLOY: `feat/x-v1` * 20260823-101500'. Every entry written before August 23, 2026 puts
    # the branch first and the title last, with nothing after it. A branch in flight carries the old shape
    # right now, here and in every consumer, so both are matched and only the first is produced.
    # THE BACKTICKS WENT ON SEPTEMBER 3, 2026 (#1335), so today's shape is '### DEPLOY: feat/x' -- and what
    # keeps this pattern narrow is unchanged, because it was never the backticks doing that work. The title
    # word and its colon are the anchor: PLAN, CREATE and TEST carry neither, at either level. The branch
    # name is matched as a bare token, and the optional tail is the merge stamp the fold appends.
    $backticked = $level + '(?:[^`]*\s)?(?:' + $titleRx + '):\s*`[^`]+`'
    $current    = $level + '(?:[^`:]*\s)?(?:' + $titleRx + '):\s+[^\s`]+'
    $legacy     = $level + '(?:[^`\s]+\s+)?`[^`]+`\s+(?:' + $titleRx + ')\s*$'
    return '(?:' + $current + ')|(?:' + $backticked + ')|(?:' + $legacy + ')'
}

function Split-Development {
    <#
        The development document in its two halves: Head -- the title, the guidance and the phases
        that carry the steps -- and Entry, the DEPLOY section from its heading to the end of the file.

        ONE SPLITTER FOR THE THREE READERS THAT NEED IT, and having one is the whole point. The fold takes
        Entry and moves it into CHANGELOG.md; the step-list gate reads Head, so a checkbox somebody wrote
        INSIDE the entry's prose cannot hold up a PR; the scaffold gate reads Entry, so the guidance in the
        head is not mistaken for an unfinished entry. Three rules asking "where does the entry begin" and
        answering it separately is the drift this file exists to prevent.

        FENCE-AWARE, like every reader of this format: an entry documenting this very mechanism quotes a
        DEPLOY heading inside a fence, and this one does. A splitter that fired on the quote would fold the
        explanation and leave the entry behind.

        NO ENTRY FOUND MEANS Entry IS EMPTY AND Head IS THE WHOLE TEXT, which is the honest answer for a
        legacy file: branch-cycle.md has no DEPLOY section, and branch-deployment.md IS one from its first
        line. The fold handles that pair by path rather than by this splitter -- see its own comments -- and
        a caller that reads Head off an old cycle file gets exactly the step list it wants.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    $rx = Get-DevelopmentEntryPattern
    $lines = @($Text -split '\r?\n')
    $fenced = @(Get-FencedLineFlags -Lines $lines)
    $at = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($i -lt $fenced.Count -and $fenced[$i]) { continue }
        if ($lines[$i] -match $rx) { $at = $i; break }
    }
    if ($at -lt 0) {
        return [pscustomobject]@{ Head = $Text; Entry = ''; Found = $false; Index = -1 }
    }
    $head  = if ($at -gt 0) { ($lines[0..($at - 1)] -join "`n") } else { '' }
    $entry = ($lines[$at..($lines.Count - 1)] -join "`n")
    # Index IS THE 0-BASED LINE THE ENTRY STARTS ON, and it is returned for one reader: a check that reports
    # a line NUMBER. The lint walks the entry's headings and prints 'file:line'; without the offset every
    # finding would point at a line the reader has to count back from the document's top, which is the shape
    # that gets a gate distrusted rather than obeyed.
    return [pscustomobject]@{ Head = $head; Entry = $entry.TrimEnd(); Found = $true; Index = $at }
}

function Get-DevelopmentEntryText {
    <#
        The ENTRY out of a branch document -- the DEPLOY section where the document has one, and the whole
        text where it does not.

        THE FALLBACK IS WHAT MAKES THIS SAFE TO CALL EVERYWHERE, and it covers two different callers with one
        rule. A legacy branch-deployment.md IS an entry from its first line, so there is no boundary to find
        and the whole file is the answer. And a block already sitting in CHANGELOG.md splits to itself -- its
        heading is the first line, so Head comes back empty -- which means a caller cannot break an entry by
        passing one through here twice.

        WHAT IT MUST NOT BE GIVEN IS A WHOLE CHANGELOG, and that is why this is a named helper rather than a
        split folded into every entry reader. CHANGELOG.md holds many entries; this would return the first
        one and silently discard the rest. The readers below stay entry-shaped on purpose, and the scripts
        that open a BRANCH document call this once, where the file is read.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    $split = Split-Development -Text $Text
    if ($split.Found) { return [string]$split.Entry }
    return $Text
}

function Test-DevelopmentEntryMissing {
    <#
        Pure: is this a development document whose DEPLOY section is GONE -- a file with no entry at all,
        rather than one whose entry is merely unwritten?

        WHY IT HAS TO BE ASKED SEPARATELY, AND WHY Get-DevelopmentEntryText CANNOT ANSWER IT (issue #1632).
        That function's fallback hands back the WHOLE TEXT when there is no DEPLOY heading, and the fallback
        is load-bearing -- a legacy branch-deployment.md IS an entry from its first line, so the whole file
        is the honest answer there. The same fallback hands back the guidance PREAMBLE for today's document
        with its DEPLOY section removed, and every reader downstream is entry-shaped: the scaffold gate
        looks for the wording the scaffolder left, finds none of it in a blockquote nobody scaffolded, and
        reports a written entry. Measured on a document reduced to nothing but its guidance -- no PLAN, no
        CREATE, no TEST, no DEPLOY, no entry text whatsoever -- which passed both of
        check-branch-entry.ps1's document checks and both of open-pr.ps1's.

        SO THE SCAFFOLD GATE PASSES BY ABSENCE, and that is the shape this predicate closes. That gate is
        built to refuse an entry still carrying the scaffolder's wording; delete the section that carried
        it and there is nothing left to match. It answers "does this text still look scaffolded?" where the
        reader needs "is there an entry?" -- two questions, which is why this is a second function rather
        than a widened one.

        HOW IT IS REACHED is what makes it worth a gate rather than a note. Not by hand-deleting a section
        on purpose: by a script edit meant to keep the guidance and replace the body, truncating at
        '### PLAN' -- which, in a document scaffolded before #1654, also occurs INSIDE the guidance
        blockquote, in the line forbidding branch-specific content above it. The cut lands there, the body
        glues onto that line, and the document comes out with its guidance truncated mid-sentence and no
        phase headings at all. The failure is silent and the file LOOKS plausible, because the guidance
        block is long and reads like content.

        #1654 CLOSED THAT DOOR FOR DOCUMENTS SCAFFOLDED SINCE, and this predicate is deliberately unchanged
        by it. StepsGuidance names the first phase by position now ("the first of those four headings")
        rather than quoting the heading, so the string occurs once. That removes the CAUSE above from new
        documents and removes nothing from this gate's job: every branch already open still carries the old
        wording, an anchor can be wrong for reasons that have nothing to do with a collision, and a hand
        deletion never needed one. A gate retired on the strength of its best-known cause is a gate that
        stops catching the causes nobody wrote down.

        THE DISCRIMINATOR IS THE PLAN, AND IT READS SHAPE RATHER THAN TEXT -- the same argument #899's
        preamble rule is built on, and it survives translation for the same reason. A development document
        carries a plan: the scaffolder's guidance, which is BLOCKQUOTED in whatever language a consumer
        translated it into, and/or the named phases that hold the step list. A legacy entry-only file
        carries neither -- it opens with its entry heading and goes straight into the entry's own sections.
        So no DEPLOY section AND no plan is the legacy shape, where the fallback stands; no DEPLOY section
        AND a plan is a document that has lost its entry.

        NOT A LEVEL TEST, and that is a repair rather than a preference. Today's document title is an H2
        and the flat-window entry heading (August 5-26, 2026) is an H2 too, so every level test in this
        file -- Test-IsChangelogEntryFile's, Test-BranchChangelogIsFilled's -- reads the broken document as
        an entry file. That collision is exactly why Test-BranchChangelogIsFilled moved to the name test,
        and a third reader keying on the level would inherit the same blindness.

        NOR THE DECLARED BRANCH, which was the near miss. A development document declares its branch in
        its title heading, which looks like a clean discriminator until Get-BranchFileDeclaredBranch's
        '**Branch:**' fallback -- deliberately un-narrowed, and sitting below the H1 title of a pre-split
        PER-BRANCH file ('branch/branch-changelog.md') -- answers for that legacy shape too. Refusing on it
        would refuse a file that is a perfectly good entry. The shape was named here as a pre-split ROOT
        entry until September 8, 2026, which no root entry ever was (#1642); the near miss is unaffected,
        because what makes the discriminator unsafe is that the fallback answers at all, not which file
        taught it to.

        THE PLAN TEST ITSELF LIVES NEXT DOOR, in Test-DevelopmentHasPlan, since September 8, 2026 (#1650):
        the shape rules need the same question, and asking it twice in two spellings is the drift this file
        exists to prevent. Its header carries the anchoring, the fence-awareness and what the extraction
        was measured against.

        AND IT ERRS TOWARD UNDER-REFUSAL. A document whose guidance AND phases have both gone along with
        its DEPLOY section is not recognised here, and that is the safe direction for a gate: a missed
        refusal is the state that already exists, while a false one stops a branch that worked yesterday.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    if ((Split-Development -Text $Text).Found) { return $false }
    return (Test-DevelopmentHasPlan -Text $Text)
}

function Test-DevelopmentHasPlan {
    <#
        Pure: does this text carry a development document's PLAN -- the scaffolder's guidance block under
        the title, or the named phases that hold the step list, or both?

        THE DISCRIMINATOR BETWEEN A DEVELOPMENT DOCUMENT AND A LEGACY ENTRY-ONLY FILE, and it was the arm
        inside Test-DevelopmentEntryMissing until September 8, 2026. It came out because the shape rules
        need exactly the same question (issue #1650): a legacy entry file IS an entry from its first line,
        so it has no document AROUND the entry to judge -- its own sub-sections would read as phases and
        its prose as a preamble stray. Asking that question twice, in two spellings, is the drift this file
        exists to prevent, and the two answers disagreeing would mean one gate refusing a file the other
        calls legitimate.

        IT READS SHAPE RATHER THAN TEXT, which is what makes it survive translation. The guidance block is
        BLOCKQUOTED in whatever language a consumer translated it into, and the phases come from the wording
        seam the scaffolder writes them from. A byte comparison against StepsGuidance could not: it carries
        a '{0}' seam the consumer answers themselves, and inbound #562 is the measured consumer who
        translated the block around it.

        THE GUIDANCE ARM IS ANCHORED TO THE TITLE, not merely 'somewhere before the second heading'. An
        entry BODY may legitimately quote something, and a blockquote in a legacy entry's prose must not
        read as guidance. The scaffolder writes the block directly under the document's own heading, so
        that is where this looks: blank lines are skipped, anything else ends the region.

        FENCE-AWARE, like every reader of this format: a document explaining this mechanism quotes the
        guidance block, and a predicate that fired on the quote would answer for the file documenting it.

        MEASURED THE DAY IT WAS EXTRACTED, and it is why this is a guard rather than a note. The shape
        rules shipped without it for one run of the test gate: seven suites went red, because the open-pr
        fixture in shared-scripts.tests.ps1 writes exactly this legacy shape -- '### <title> - Feat -
        <date>' and a paragraph -- and the shape gate refused it. The lib header had already written that
        misread down as a risk that had not bitten. It bit within the hour.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    $lines  = @($Text -split '\r?\n')
    $fenced = @(Get-FencedLineFlags -Lines $lines)

    # The phases by name, from the same wording seam the scaffolder writes them from, so a repo that
    # renamed one is read by its own name. DEPLOY is deliberately not among them: its absence is the thing
    # being detected. Two lines rather than one, and they are the SAME two Format-Development uses to
    # resolve its arc -- #927's fail-safe: an override present but leaving nothing usable behind falls back
    # to the defaults, because a phase list that came back empty would make this predicate blind to a
    # document whose guidance had also gone.
    $phases = @((Get-BranchFileWording).StepPhases | Where-Object { $_ })
    if ($phases.Count -eq 0) { $phases = @($script:BranchFileDefaults.StepPhases | Where-Object { $_ }) }

    $seenTitle = $false
    $inGuidance = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($i -lt $fenced.Count -and $fenced[$i]) { continue }
        $line = $lines[$i]
        if ($line -match '^#{1,6}\s+(\S.*)$') {
            # A named phase ANYWHERE below the title is a plan, whatever level it was written at -- the
            # levels shifted once already and a document written on either side has to be read.
            if ($seenTitle -and ($phases -contains $Matches[1].Trim())) { return $true }
            if ($seenTitle) { $inGuidance = $false } else { $seenTitle = $true; $inGuidance = $true }
            continue
        }
        if ($line.Trim() -eq '') { continue }
        if ($inGuidance) {
            # The first non-blank line under the title decides the region: a blockquote is the guidance
            # block, anything else is an entry's own prose and ends the probe.
            if ($line -match '^\s*>') { return $true }
            $inGuidance = $false
        }
    }
    return $false
}

function Get-DevelopmentShapeFindings {
    <#
        Pure: does this development document keep its SHAPE -- exactly the named phases and nothing else at
        that level, and nothing but generic guidance above the first of them?

        TWO RULES DAVE ENFORCED BY READING, on a document a session writes, with no signal in between. Both
        were caught by eye on August 26, 2026, on the same document, within one afternoon -- and the second
        one had been introduced by the session before, in the same position, which is what makes it a shape
        the document invites rather than a slip.

        THEY ARE SCOPED DIFFERENTLY, AND THAT ASYMMETRY IS THE DESIGN rather than an inconsistency. It is
        why the arc sits behind -EnforcePhaseArc and the preamble rule does not:

          #898, the heading count, is the SOURCE REPO's rule. DEVELOPMENT-portable.md states
          heading-blindness as a FEATURE -- "the gate reads step marks only, so a heading of any level is
          invisible to it" -- and the reason it is a feature is that a consumer may keep headings of their
          own in a document they adopted. Refusing those everywhere would break correct files in somebody
          else's repo, which is the shape this house declined once already at 124 findings, all false. The
          CALLER answers which repo this is (Test-IsWorkflowSourceRepo, in seam-lib.ps1) and passes the
          switch: this function is handed a text and has no repo root to ask the question with.

          #899, the preamble, holds EVERYWHERE, because it reads the SHAPE and not the text. The region
          between the title and the first phase heading is the scaffolder's guidance, which is blockquoted
          whatever language it has been translated into -- so "a non-blank line that does not start with
          '>'" survives translation. A byte comparison against StepsGuidance could not: it carries a '{0}'
          seam the consumer answers themselves, and inbound #562 is the measured consumer who translated
          the block around it.

        WHY THE PREAMBLE ONE IS NOT MERELY TIDINESS. The measured paragraph sat flush under the guidance
        with no heading between them, so it READ as guidance -- and guidance is generic by construction. A
        reader who finds one branch's status inside it learns to distrust the whole region, including the
        rules that do apply everywhere.

        A SHARED FUNCTION SINCE SEPTEMBER 8, 2026 (issue #1650), AND THAT MOVE IS THE WHOLE REPAIR. Both
        rules were inline in check-branch-entry.ps1, which runs in CI and only ADVISORILY, so nothing
        refused a malformed document before the push. PR #1644 shipped through push, the required check,
        the merge and the fold with its first phase heading and most of its guidance block gone; the one
        red check was this rule, and the fold then DELETED the file that check names. An advisory finding
        pointing at a path that no longer exists is a far weaker signal than an ordinary red, because
        there is nothing left to look at. As a function it is refused by open-pr.ps1 before the push --
        while the file still exists and the author is still holding it -- and CI reports exactly what it
        reported before, on the same text, from the same code.

        IT RE-DERIVES NOTHING, which is the reason it can be shared at all. Split-Development is not
        consulted because the scan walks the whole text: the entry's own sections sit one level below the
        phases and its own heading is one of them, so there is no boundary to find. The levels are read
        off the document (below), and the phase names come from the same wording seam the scaffolder
        writes them from, so a repo that renamed a phase is judged by its own names.

        A LEGACY ENTRY-ONLY FILE IS REFUSED ENTRY AT THE DOOR, by Test-DevelopmentHasPlan, and the first
        draft of this function did not do that. It read the misread correctly -- such a file IS an entry
        from its first line, so its own sub-sections read as phases and its prose as a preamble stray --
        and then declined to guard against it, on the ground that CI had reported on this text since
        August 26, 2026 without meeting one, which made it a risk that had not bitten. It bit on the first
        run of the test gate: SEVEN suites red, because the open-pr fixture in shared-scripts.tests.ps1
        writes exactly that shape. The lesson is not that the no-pre-emptive-fixes rule is wrong; it is
        that "has not bitten" was a claim about CI, where the rule only ever REPORTED, and this branch was
        turning it into a refusal. Widening what a check does resets its evidence.

        RETURNS the finding lines ready to print (empty when the document is sound), plus what was
        actually READ: PhaseCount, PhaseMark and SubMark. A caller reporting coverage quotes those rather
        than composing a level a second time -- see the [OK] line in check-branch-entry.ps1 for the day
        that cost. Every fragment of the DOCUMENT quoted in a finding is passed through Get-DisplayRef
        first -- the reason is at the dot-source at the top of this file -- while the structured members
        (PreambleStrays, StrayHeadings) carry the text as it stands, because a caller matching on it is
        reading and not printing.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [switch]$EnforcePhaseArc
    )

    # A DOCUMENT WITH NO PLAN HAS NO SHAPE TO JUDGE, and this is the first question rather than a special
    # case. Both rules are about the document AROUND the entry; a legacy entry-only file IS an entry from
    # its first line, so its own sub-sections would read as phases and its prose as a preamble stray. The
    # predicate is Test-DevelopmentEntryMissing's own, shared rather than re-derived -- its header carries
    # the measurement, including the seven suites that went red the one run this guard was missing.
    if (-not (Test-DevelopmentHasPlan -Text $Text)) {
        return [pscustomobject]@{
            Findings       = @()
            PhaseCount     = 0
            PhaseMark      = '#' * ((Get-BranchCycleHeadingLevel) + 1)
            SubMark        = '#' * ((Get-BranchCycleHeadingLevel) + 2)
            PhaseHeadings  = @()
            StrayHeadings  = @()
            PreambleStrays = @()
        }
    }

    # THE LEVELS ARE READ OFF THE DOCUMENT, NOT PINNED, and a range would be wrong rather than merely loose
    # (August 26, 2026). Both levels shifted one down that day: the title went H1 -> H2 and the phases
    # H2 -> H3. So the new TITLE level and the old PHASE level are the same number, and a gate accepting
    # '^#{2,3}' as a phase would read a post-shift title as a fifth phase -- refusing a correct document,
    # which is the one failure mode this must not have. Reading the first heading as the title and the
    # phases as exactly one level under it needs no era flag and no list of levels to maintain: it is the
    # invariant the format has always had, and the one the suite already asserts as "the sections sit
    # exactly one level under the title".
    #
    # Fence tracking throughout, so a quoted heading is illustration rather than a phase. Same rule check 4
    # of the lint gate argues for links and check 28 for imports.
    $titleLevel = 0
    $inTitleProbe = $false
    foreach ($probeLine in [regex]::Split($Text, '\r?\n')) {
        if ($probeLine -match '^\s{0,3}(?:`{3,}|~{3,})') { $inTitleProbe = -not $inTitleProbe; continue }
        if ($inTitleProbe) { continue }
        if ($probeLine -match '^(#{1,6})\s+\S') { $titleLevel = $Matches[1].Length; break }
    }
    # No heading at all: fall back to the written pair, so a malformed document is judged by today's shape
    # rather than skipping the check entirely.
    if ($titleLevel -le 0) { $titleLevel = Get-BranchCycleHeadingLevel }
    $phaseLevel = $titleLevel + 1
    $phaseRx    = '^#{' + $phaseLevel + '}\s+(\S.*)$'
    $titleRx    = '^#{1,' + $titleLevel + '}\s'
    # AND EVERY FINDING BELOW QUOTES THESE INSTEAD OF TYPING A LEVEL (#924, August 26, 2026). The reasoning
    # is the one at check-branch-entry.ps1's [OK] line -- "the level in this line is the one that was
    # actually READ, not a literal" -- and it held for that one line only. Six markers on the FAILURE path
    # were typed, so on the day the shape shifted one level down the gate refused a document for the new
    # levels while reporting the old ones: it told a reader to demote a '###' to a '###', and pointed at
    # "the first '##'" in a document whose phases are '###'. That is the worse way round of the two,
    # because the failure message is the one somebody reads while they cannot yet see what is wrong.
    $phaseMark = '#' * $phaseLevel
    $subMark   = '#' * ($phaseLevel + 1)

    $inShapeFence = $false
    $shapeLineNo = 0
    $topHeadings = @()
    $preambleStrays = @()
    $seenFirstTop = $false
    foreach ($shapeLine in [regex]::Split($Text, '\r?\n')) {
        $shapeLineNo++
        if ($shapeLine -match '^\s{0,3}(?:`{3,}|~{3,})') { $inShapeFence = -not $inShapeFence; continue }
        if ($inShapeFence) { continue }
        if ($shapeLine -match $phaseRx) {
            $seenFirstTop = $true
            $topHeadings += [pscustomobject]@{ Line = $shapeLineNo; Text = $Matches[1].Trim() }
            continue
        }
        if ($shapeLine -match $titleRx) { continue }
        # The preamble region: everything after the title and before the first phase heading. Blank lines and
        # blockquote lines are the guidance block; anything else is this branch's own content, sitting where
        # the text is supposed to be identical in every branch document in every repo.
        if (-not $seenFirstTop -and $shapeLine.Trim() -ne '' -and $shapeLine -notmatch '^\s*>') {
            $preambleStrays += [pscustomobject]@{ Line = $shapeLineNo; Text = $shapeLine.Trim() }
        }
    }

    # The arc is PLAN / CREATE / TEST / DEPLOY. Held only where the caller says so -- see the header.
    #
    # THE PHASES ARE NAMED, NOT COUNTED, and the first draft of this check got that wrong in a way worth
    # recording: it reported "everything past the fourth heading", which named the DEPLOY heading as the
    # extra the moment the stray sat ABOVE the first phase -- which is exactly where both measured
    # instances sat. A count cannot say WHICH heading does not belong; only the names can.
    #
    # Read from Get-BranchFileWording, the same source the scaffolder writes them from, with #927's
    # fail-safe under it: an override present but leaving nothing usable behind falls back to the defaults,
    # because a phase list that came back empty would report every phase in the document as a stray. Those
    # are the same two lines Test-DevelopmentEntryMissing resolves its arc with, rather than a third list
    # of literals typed here.
    $knownPhases = @((Get-BranchFileWording).StepPhases | Where-Object { $_ })
    if ($knownPhases.Count -eq 0) { $knownPhases = @($script:BranchFileDefaults.StepPhases | Where-Object { $_ }) }

    # DEPLOY is matched on its PREFIX, because its heading carries the branch name (DEPLOY: feat/x).
    $strayHeadings = @($topHeadings | Where-Object {
        ($knownPhases -notcontains $_.Text) -and ($_.Text -notmatch '^DEPLOY\b')
    })

    # EVERY QUOTED FRAGMENT BELOW GOES THROUGH Get-DisplayRef FIRST, and the reason is at the dot-source at
    # the top of this file: these are the only lines here made of text somebody else wrote, and they are
    # printed to a console and to a public CI log. STRIPPED BEFORE TRUNCATED, deliberately -- cutting at 72
    # characters can halve an escape sequence, so a strip afterwards would be working on a fragment.
    $findings = @()
    if ($strayHeadings.Count -gt 0 -and $EnforcePhaseArc) {
        $findings += "carries $($topHeadings.Count) '$phaseMark' headings, and the arc is $($knownPhases -join ' / ') / DEPLOY -- four, never a fifth."
        foreach ($h in $strayHeadings) {
            $findings += "  extra heading, line $($h.Line): '$phaseMark $(Get-DisplayRef -Ref $h.Text)'"
        }
        $findings += "  Demote it to '$subMark' under whichever of the four it belongs to."
    }

    if ($preambleStrays.Count -gt 0) {
        $findings += "carries branch content above the first '$phaseMark', where the block is generic guidance:"
        foreach ($s in $preambleStrays) {
            $shown = Get-DisplayRef -Ref $s.Text
            $trimmed = if ($shown.Length -gt 72) { $shown.Substring(0, 72) + '...' } else { $shown }
            $findings += "  line $($s.Line): $trimmed"
        }
        $findings += '  That region is identical in every branch document in every repo, so a status note'
        $findings += "  there reads as guidance. Move it under one of the '$phaseMark' phases, as a '$subMark'."
    }

    return [pscustomobject]@{
        Findings       = @($findings)
        PhaseCount     = $topHeadings.Count
        PhaseMark      = $phaseMark
        SubMark        = $subMark
        PhaseHeadings  = @($topHeadings)
        StrayHeadings  = @($strayHeadings)
        PreambleStrays = @($preambleStrays)
    }
}

function Get-DevelopmentBranchText {
    <#
        The branch's OWN text out of a development document -- everything from the first phase heading to
        the end of the file, with the title and the scaffolder's guidance block left behind.

        FOR THE ONE READER WHOSE SUBJECT IS THE BRANCH RATHER THAN THE ENTRY: open-pr.ps1's mention scan,
        which asks which issues THIS branch is about. It cannot use Split-Development, because a number
        named in a step is a mention of that issue and the entry is only the last of the four phases -- so
        it read the WHOLE file, guidance and all, and the guidance is where this workflow records why its
        shape rules exist. Every citation in it is therefore a mention on every branch, in every repo.

        MEASURED SEPTEMBER 9, 2026 ON feat/1703-test-gate-cost (issue #1718): the already-done check
        warned that '#1650 is already CLOSED, and it is already resolved by PR #1661 (merged)' on a branch
        that has nothing to do with #1650. The citation is StepsGuidance's own -- 'refused since #1650' --
        so the warning fires unconditionally, and the same run also warned about #1464, which WAS a
        deliberate context citation. A check whose false positives are indistinguishable from its findings
        has stopped being read. And it grows: each new rule the guidance cites adds a permanent warning to
        every branch that will ever be opened.

        AN IGNORE-LIST OF NUMBERS IS EXPLICITLY NOT THE FIX, and #1718 said so when it was filed. It would
        need editing every time the guidance cites a new issue, which is the same maintenance failure one
        file further along.

        THE SPLIT IS SAFE BECAUSE ANOTHER GATE ALREADY GUARANTEES IT. #899's preamble rule -- 'nothing
        branch-specific above the first of those four headings' -- is refused by open-pr before the push,
        in every repo, so the region this function drops is generic by construction: nothing citable by the
        author can be lost in it. That is why the boundary is the first phase heading and not, say, the
        end of the blockquote.

        IT RE-DERIVES NOTHING, which is the reason it is three lines. Get-DevelopmentShapeFindings already
        walks this text fence-aware, reads the title and phase levels OFF the document rather than pinning
        them, and reports each phase heading's line -- and it is the reader of the very rule quoted above.
        A second walk with its own level derivation is exactly the drift this file exists to prevent: the
        levels shifted once already (August 26, 2026), and a copy free to disagree did.

        NO PHASE HEADING MEANS THE WHOLE TEXT, and that fail-safe carries two cases on one rule. A legacy
        entry-only file has no document around its entry -- Test-DevelopmentHasPlan turns it away at that
        function's door, so PhaseHeadings comes back empty -- and a document whose phases have gone is one
        this function must not silently empty. Erring toward the whole text errs toward the surplus
        mention, which is the direction Get-IssueMentions itself chose: a mention too many asks the author
        one question, a mention missed is the silent open issue the gate exists to prevent.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    $first = @((Get-DevelopmentShapeFindings -Text $Text).PhaseHeadings)[0]
    if ($null -eq $first) { return $Text }
    # Line is 1-BASED, off the same '\r?\n' split as below, so the first phase heading is kept and
    # everything above it is dropped. A heading on line 1 leaves nothing above it to drop.
    $at = [int]$first.Line - 1
    if ($at -le 0) { return $Text }
    $lines = @($Text -split '\r?\n')
    return ($lines[$at..($lines.Count - 1)] -join "`n")
}

function Test-BranchChangelogIsFilled {
    <#
        Pure: does the development file hold a branch's work, or is it still (back) in the reset state
        the trunk carries? True means this document belongs to a branch.

        THE TEST IS THE BRANCH NAME, NOT THE HEADING LEVEL, since August 23, 2026 -- and the change was
        forced rather than chosen. Until the merge there were two files: the entry opened with an H2 when it
        was written and an H1 when it was reset, so one look at the first non-blank line answered this. One
        document cannot do that. Its title heading is its title in both states, and the heading below it is
        a section of it, so the level says nothing about whether anybody has been working here.

        WHAT DOES SAY SO is the name in the heading, which is the same fact new-branch already uses for
        idempotency: the trunk's name means nobody's branch, any other name means somebody's. One predicate
        for both questions, rather than two answering it two ways -- which is exactly how the fold and the
        release cut once came to disagree about whether work was pending.

        AND IT IS DELIBERATELY NOT "IS THE ENTRY ANSWERED". A branch whose DEPLOY section is still empty is
        filled in this sense and refused by Get-EntryScaffoldFindings, which is the gate that reads content.
        Keeping the two apart is what lets a refusal say WHICH of the two is wrong -- "there is no entry
        here" and "the entry is still the scaffold" send an author to different places.

        AND THE OLD LEVEL TEST IS STILL ONE OF THE TWO ANSWERS, which is a repair rather than politeness --
        caught by shared-scripts.tests.ps1 when the name test was the ONLY one. A PRE-SPLIT ROOT ENTRY
        (`feat-x.md`, from before August 6, 2026) opens with its own TITLE AT AN ENTRY LEVEL and names no
        branch anywhere, so the name test reads it as empty. Measured over the 344 in this repo's history
        (#1642): 334 open at H3 and 10 at H2 -- the flat window of August 5-6 -- and NONE names a branch,
        which is the half the name test cannot see. Both levels are ones this test accepts, so the shape is
        covered end to end; it read 'as an H2' until September 8, 2026, which was true of 10 of the 344.
        Every consumer with such a file still has one, and the consequences are the silent kind: open-pr
        would leave the changelog checklist item unticked, and the release cut -- whose guard is "no
        unfolded entry anywhere" -- would cut a release straight over it.
        So: filled if the first non-blank line is AT an entry level, OR if the document names a branch other
        than the trunk. Each shape is answered by the test that can see it.

        THE TWO CANNOT DISAGREE ON A SHAPE THAT MATTERS. The merged document opens with an H1 in both states,
        so only the name test speaks for it. A legacy pair or a root entry opens with an entry-level heading
        once written and an H1 while reset, so only the level test needs to speak for those -- and where both
        speak, they agree.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [switch]$OpeningHeadingOnly
    )
    # -OpeningHeadingOnly is passed straight through to the name test; what it means, and why only the
    # release cut's ROOT scan asks for it, is documented on Get-BranchFileDeclaredBranch (inbound #1099).
    # It is a pass-through rather than a second predicate on purpose: one predicate answering "is this an
    # entry" is the whole point of this function, and the fold and the cut once came to disagree exactly
    # because there were two.
    $declared = Get-BranchFileDeclaredBranch -Text $Text -OpeningHeadingOnly:$OpeningHeadingOnly
    if ($declared -and $declared -ne (Get-BranchTrunkName)) { return $true }

    # A DOCUMENT DECLARING THE TRUNK IS A RESET, AND THAT IS NOW THE ANSWER RATHER THAN A FALL-THROUGH
    # (August 26, 2026). It used to fall through to the level test below and be rejected there, because the
    # reset heading was an H1 and no entry level reached it. The cycle file's title is an H2 now, which the
    # level test accepts -- so the old arrangement would have called an empty trunk document an entry and
    # handed the fold an empty change to paste into CHANGELOG.md, on the trunk, unprompted.
    #
    # THE NAME IS THE RIGHT DISCRIMINATOR AND THE LEVEL NEVER WAS, which is the lesson worth keeping: an
    # entry always declares the branch it belongs to, a reset always declares the trunk, and neither fact
    # moves when somebody re-levels the document. The level test survives below only for documents that
    # declare no branch at all.
    if ($declared -eq (Get-BranchTrunkName)) { return $false }

    # The level test: two levels are accepted because an entry written before the current format is still an
    # entry. WHICH TWO CHANGED DIRECTION ON AUGUST 26, 2026, and reading it as 'entry level plus one' would
    # now be wrong in both halves. It used to mean the PRE-FLAT shape, which was one level DEEPER than the
    # flat entry it preceded (H3 against H2). After the shift the flat entry is itself an H3, so the level
    # still to cover is the one ABOVE: the H2 every entry written between August 5 and August 26 carries, and
    # every entry sitting in a consumer's un-cut CHANGELOG.md right now.
    #
    # THE PRE-FLAT SHAPE NEEDS NO SEPARATE SLOT ANY MORE, because it collided with the new canonical level:
    # both are H3. That collision is harmless HERE -- this function only asks "is this an entry file at all"
    # -- and it is discriminated where it matters, by Get-PreFlatChangelogRefusal, which keys on whether a
    # block declares an entry's named sections rather than on how deep its heading is.
    $entryLevel  = Get-EntryHeadingLevel
    $legacyLevel = $entryLevel - 1
    $rx = '^#{' + $legacyLevel + ',' + $entryLevel + '}\s'
    foreach ($line in ($Text -split '\r?\n')) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        return ($line -match $rx)
    }
    return $false
}

function Get-UnfoldedTrunkEntry {
    <#
        Every per-branch development document under dkj-policy/ that is a WRITTEN entry and
        does NOT belong to the branch the caller is on -- i.e. a fold that never ran after a merge,
        leaving the entry stranded on the trunk with nothing saying so. Issue #1270, the residual
        #1244 left behind: a PR merged from the GitHub UI (or any path that skips ship-pr.ps1) never
        folds, and no gate downstream catches the leftover.

        WHY THIS IS A FUNCTION AND NOT A ONE-LINER IN THE CHECK. Two callers need the identical answer
        with the identical exclusions: the CI workflow on push to main, and the SessionStart hook that
        ships in the workflow plugin. A second definition would be free to disagree about what "belongs
        to this branch" means -- the same drift Resolve-BranchFilePath exists to prevent for the
        sibling question.

        THE INVARIANT IT ENFORCES: on the trunk, dkj-policy/ carries no per-branch document at
        all. new-branch.ps1 creates one on a branch, the fold removes it at the merge (Dave,
        August 23, 2026 -- the document is branch-lifetime). So a WRITTEN one whose declared branch is
        not the branch under HEAD is a leftover: on the trunk that is every written one, on a feature
        branch it is every one except that branch's own -- a leftover rides into a checkout on the
        trunk's tree through an ordinary merge and then sits beside the working branch's document.

        NOT A gh CALL, deliberately. Whether the leftover's branch is merged, closed or still open does
        not change the answer: a written entry on the trunk is folded or it is a defect, and the fold
        is local. Staying offline is what lets the SessionStart hook run this in a consumer with no
        token and no network.

        THE ONE FALSE POSITIVE IT CAN RAISE is the ship window. ship-pr.ps1 pushes the merge commit and
        then, seconds later, the fold commit that clears the document. Between the two the just-merged
        document is on the trunk and this reports it -- correctly, because the trunk genuinely carries
        an unfolded entry at that instant. unfolded-entry.yml's own cancel-in-progress swallows the
        merge commit's run there -- ci.yml's does not, and since #1294 cannot: each push to the trunk
        runs in a group of its own. A session that starts in that window gets an accurate finding
        that the next commit resolves.

        WIDE READING OF THE DECLARED BRANCH, deliberately. Every file considered here sits at the fixed
        per-branch document path and is a known-shape branch document, so the -OpeningHeadingOnly narrowing
        the release cut's ROOT scan needs (inbound #1099) does not apply -- there is no arbitrary prose
        to misread here.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        # The branch whose own document is expected and therefore excluded. Empty -> resolve HEAD; on
        # the trunk that resolves to the trunk name, which no document declares, so nothing is excluded
        # and every written entry counts as a leftover.
        [string]$CurrentBranch = ''
    )
    if (-not $CurrentBranch) {
        # Best effort and silent on failure: a tree that is not a git checkout, or a detached HEAD,
        # leaves this empty and every written document is then treated as a leftover -- which is the
        # right default for a CI checkout of the trunk.
        try {
            $head = (& git -C $RepoRoot rev-parse --abbrev-ref HEAD 2>$null)
            if ($LASTEXITCODE -eq 0 -and $head) {
                $head = ([string]$head).Trim()
                if ($head -and $head -ne 'HEAD') { $CurrentBranch = $head }
            }
        } catch { }
    }

    $paths = Get-BranchFilePaths

    # The per-branch sweep, plus the pre-#1255 shared name explicitly. Since #1335 the glob is '*.md' and
    # Get-PerBranchDocumentRels is what keeps it off this folder's own pages -- CHANGELOG.md above all,
    # which declares a branch in every folded entry it holds and would otherwise be reported here as a
    # leftover to fold. 'development.md' is inside the glob now and named anyway, at no cost: Sort-Object
    # -Unique collapses the duplicate, and naming it keeps this list readable as the set it means.
    $candidateRels = @(Get-PerBranchDocumentRels -RepoRoot $RepoRoot) +
        @([string]$paths.SharedFile) | Sort-Object -Unique

    $findings = New-Object System.Collections.Generic.List[object]
    foreach ($rel in $candidateRels) {
        if (-not $rel) { continue }
        $full = Join-Path $RepoRoot ($rel -replace '/', '\')
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
        $text = [System.IO.File]::ReadAllText($full, [System.Text.Encoding]::UTF8)
        # A reset stub declares the trunk and Test-BranchChangelogIsFilled is false for it -- not a
        # leftover, just the shape the fold leaves on a shared-name branch mid-transition.
        if (-not (Test-BranchChangelogIsFilled -Text $text)) { continue }
        $declared = Get-BranchFileDeclaredBranch -Text $text
        if (-not $declared) { continue }
        if ($declared -eq $CurrentBranch) { continue }
        $findings.Add([pscustomobject]@{
            Rel            = $rel
            DeclaredBranch = $declared
        }) | Out-Null
    }
    return $findings.ToArray()
}

function Test-BranchFoldedOnRef {
    <#
        Has $Branch's entry ALREADY been folded on $Ref -- read off CHANGELOG.md at that ref through the
        one definition of a folded heading this file already carries. $true when the entry is there,
        $false when the changelog is readable and does not name the branch, and $null when the question
        could not be asked at all. Issue #1601.

        WHY IT IS THIS QUESTION AND NOT THE ABSENT DOCUMENT. check-unfolded-entry.ps1 used to answer
        "already folded upstream?" with 'git cat-file -e <ref>:<document>' -- the cheap half of the same
        fold commit, which REMOVES the document and ADDS the entry in one go. Absent-on-origin is the
        fold's signature only where absence can have no other cause, and #1585 secured that with a
        gap gate: ask only when the checkout is BEHIND. But a gap is not a direction. HEAD..origin/<trunk>
        is non-zero in a DIVERGED state too, and there a document committed locally and never pushed is
        also absent on origin -- so the cheap half answered "folded" about a fold that is still owed, and
        the reader was sent at a 'git pull --ff-only' that cannot fast-forward. Reproduced September 8,
        2026 on a fixture one ahead and one behind: [WARN] ... ALREADY been folded, exit 0.

        SO THE EXPENSIVE HALF IS READ INSTEAD, and it costs one blob. The entry's presence in the
        changelog has exactly one cause -- a fold -- whichever way the checkout has drifted, which is what
        makes the gap gate UNNECESSARY rather than merely sufficient. The check keeps measuring the gap,
        because a reader who is behind still needs to be told so; it no longer CLASSIFIES on it.

        NO SECOND DEFINITION OF A FOLDED ENTRY, which is the reason this is a function here rather than
        four lines in the check. Get-FoldedEntryForBranch is that definition, and it already matches the
        branch as a whole name across both heading shapes -- the backticked one every entry folded before
        September 3, 2026 carries, and the bare one written since (#1335). A regex in the check would be
        free to disagree with it, which is the drift Get-UnfoldedTrunkEntry exists to prevent for the
        sibling question.

        $null IS NOT $false, AND EVERY CALLER MUST KEEP THEM APART -- the same rule Get-TrunkGap's
        Measured field states. No ref, no changelog at that ref, no branch to key on, or no
        Invoke-NativeCapture in the session: each of those means "could not tell", and a caller that read
        it as "not folded" would report a skipped fold it never measured. The check treats it as NOT
        FOLDED deliberately and says so at its own call site: an unanswerable question there leaves the
        leftover reported, which is the pre-#1585 behaviour and the safe direction to fail in.

        AN ENTRY WHOSE HEADING NAMES NO BRANCH cannot be matched, and that limit is Get-FoldedEntryForBranch's
        own -- it predates this function and is documented there. Such an entry reads as $false here, so its
        document stays reported rather than silently waved through.

        THE CHANGELOG'S PATH DEFAULTS TO THE WORKFLOW FOLDER'S OWN, which is Get-DefaultChangelogPath's
        answer without reaching into seam-lib.ps1 from here -- Get-BranchFilePaths already names that
        folder, and ReservedNames already names CHANGELOG.md inside it. A repo that states
        Get-ChangelogPath passes the seam's answer in; the caller resolves it, because a lib that went
        looking for a repo root to resolve a seam is a lib that can find the wrong tree (the same call
        ReservedNames itself gets).
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        # The ref to read the changelog at -- 'refs/remotes/origin/main' from the caller's own gap
        # measurement, so nothing here fetches.
        [Parameter(Mandatory)][AllowEmptyString()][string]$Ref,
        # The branch the entry would name. Empty -> $null: there is nothing to key on.
        [Parameter(Mandatory)][AllowEmptyString()][string]$Branch,
        # The changelog's repo-relative path. Empty -> '<workflow folder>/CHANGELOG.md'.
        [string]$ChangelogRel = ''
    )

    if (-not $Ref -or [string]::IsNullOrWhiteSpace($Branch)) { return $null }
    if (-not (Test-FunctionDefined 'Invoke-NativeCapture')) { return $null }

    if (-not $ChangelogRel) {
        $paths = Get-BranchFilePaths
        $ChangelogRel = "$($paths.Directory)/CHANGELOG.md"
    }
    # A LITERAL Replace RATHER THAN -replace: git wants forward slashes in a pathspec, and a caller may
    # hand over a seam answer written the Windows way. -replace takes a REGEX, where a backslash is the
    # escape character rather than the thing being matched.
    $ChangelogRel = $ChangelogRel.Replace('\', '/')

    # -DiscardStderr because a missing path is git's own message and this function reports it as $null
    # rather than printing it: the caller is deciding how to word a finding, not diagnosing git.
    $show = Invoke-NativeCapture -FilePath 'git' -Arguments @('-C', $RepoRoot, 'show', "${Ref}:$ChangelogRel") -DiscardStderr
    if ($show.ExitCode -ne 0) { return $null }

    $text = ($show.Output -join "`n")
    if ([string]::IsNullOrWhiteSpace($text)) { return $false }

    return ($null -ne (Get-FoldedEntryForBranch -ChangelogText $text -Branch $Branch))
}

function Get-RetiredBranchDocNames {
    <#
        The RETIRED names of the branch's working document, as literal strings a prose page can carry --
        one row per name this layout has abandoned, plus the folder it abandoned. Issue #1389.

        WHY A CONSUMER'S PROSE NEEDS THIS AT ALL. The document has been renamed seven times, twice on
        September 3, 2026 alone, and the tooling was deliberately made rename-proof for it: every reader
        goes through Resolve-BranchFilePath, and the fold's bound in the source repo's constitution is
        named by that resolver rather than spelled out. THE PROSE DESCRIBING IT TO CONSUMERS WAS NOT.
        Nothing reads a consumer's CLAUDE.md, check-script-contract.ps1 covers functions rather than
        conventions, and #1273 caught the plugin's own pages while nobody was positioned to notice that
        both live consumers had the same defect. Measured: both BWJ consumers still restated the retired
        single 'development.md' in their always-on documents, one day and six days after the rename.

        IT IS DERIVED, NOT A LIST. The names come from Get-BranchFileLegacyNames, which is already the one
        ordered source the resolver and new-branch's writer share -- so the next rename adds this token by
        the same row it always adds, and there is no second list to leave at seven names. Both Kinds are
        unioned because the split-file era named the two halves differently and a prose page may carry
        either.

        LITERAL, AND THAT IS THE WHOLE LICENCE THIS CHECK HAS. The prose-contract framework (#1380) was
        measured at 12.5% precision and DECLINED (Dave, September 4, 2026); the decline recorded this as
        the alternative that is proportionate, in the source repo's system-administration lens: "one
        [grep] for the literal string 'development.md' outside the changelog and history paths". A
        filename is an exact string with a mechanical answer, which is the same distinction that
        separates this repo's accepted dead-link check (17 findings, 17 real) from its declined
        stale-path check (124 findings, none real). Anything fuzzier than a filename does not belong
        here.

        SO THE PER-BRANCH PREDECESSOR IS DELIBERATELY ABSENT, and it is a stated gap rather than an
        oversight. 'development-<slug>.md' (pre-#1335) has no literal form: a prose page names the SHAPE,
        'development-<branch>.md', and matching that needs a wildcard -- the exact step toward fuzzy that
        the decline above rules out. What survives of that era is 'development-cycle.md', a real literal
        and present below. A consumer restating only the shape is missed, and that is the price of the
        precision.

        THE FOLDER IS A NAME TOO -- TWO OF THEM (#886, 'workflow-davekjohn/' -> 'contributing-davekjohn/';
        #1437, 'contributing-davekjohn/' -> 'dkj-policy/'). Each is taken
        from the first segment of the pre-rename paths rather than written out, for the reason above.

        Each row carries the literal Name and a Since line naming what replaced it, because a finding
        whose remedy the reader has to derive is a finding they will work around.

        LONGEST FIRST, and the order is behaviour rather than presentation: Get-RetiredDocNameMention
        claims a span per line, so 'development-cycle.md' has to be tried before 'development.md' could
        be looked for inside it.
    #>
    $paths = Get-BranchFilePaths
    $current = $paths.Directory

    $names = New-Object System.Collections.Generic.List[object]
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

    # The retired FOLDERS, read off the first segment of the pre-rename paths rather than written out.
    # TWO OF THEM SINCE #1437: 'contributing-davekjohn' joined 'workflow-davekjohn' on September 5, 2026,
    # and the newer one is listed first so a consumer's prose is matched against the name it is most
    # likely to still be carrying.
    foreach ($rel in @([string]$paths.ContribFolderFile, [string]$paths.PriorFolderFile)) {
        if (-not $rel) { continue }
        $folder = ($rel -split '/')[0]
        if ($folder -and $folder -ne $current -and $seen.Add($folder)) {
            $names.Add([pscustomobject]@{
                Name  = $folder
                Kind  = 'folder'
                Since = "the folder is '$current/' since September 5, 2026 (#1437)"
            }) | Out-Null
        }
    }

    # The retired FILENAMES, both Kinds unioned. Basenames only: a prose page names the file far more
    # often than the whole path, and every path form contains the basename anyway.
    $currentFile = [System.IO.Path]::GetFileName(((Get-BranchFilePaths -Branch 'x').File -replace '/', '\'))
    foreach ($rel in (@(Get-BranchFileLegacyNames -Kind File) + @(Get-BranchFileLegacyNames -Kind Deployment))) {
        if (-not $rel) { continue }
        $leaf = [System.IO.Path]::GetFileName(($rel -replace '/', '\'))
        if (-not $leaf) { continue }
        # A belt-and-braces guard, not a live case: today's name is '<slug>.md' and no legacy row can
        # produce it. It costs one comparison, and it is what stops a future rename from shipping a check
        # that reports the name it has just introduced.
        if ($leaf -ieq $currentFile) { continue }
        if (-not $seen.Add($leaf)) { continue }
        $names.Add([pscustomobject]@{
            Name  = $leaf
            Kind  = 'file'
            Since = "the document is named after its branch, '$current/<branch>.md', since September 3, 2026 (#1255, #1335)"
        }) | Out-Null
    }

    return @($names | Sort-Object -Property @{ Expression = { $_.Name.Length }; Descending = $true }, Name)
}

function Get-ConsumerProseDocuments {
    <#
        The repo-relative paths of a CONSUMER's own law-bearing prose -- the #1380 corpus, as an
        INCLUSION list. One definition, shared by every check that asks "does this repo's own prose
        contradict the plugin": Get-RetiredDocNameMention (#1389) and Get-SupremacyDeclaration (#1415).

        IT IS SHARED BECAUSE THE CORPUS IS THE HALF THAT IS EASY TO GET SUBTLY WRONG. The detectors
        differ -- one looks for a filename, the other for a direction -- but which documents they are
        allowed to look in is one question with one answer, and the exclusions below are each load-bearing
        for a measured reason. Two copies of this would drift on the day a third exclusion is found, and
        the copy that missed it would report a document the other correctly ignores.

        Two kinds of page:

          1. the always-on closure -- CLAUDE.md and everything it '@'-imports -- passed in as -Documents,
             because that walk belongs to measure-context-lib.ps1 and a second walk here would be a second
             definition of the always-on path;
          2. the workflow folder's own permanent pages, MINUS its changelog.

        THE CHANGELOG EXCLUSION IS NOT OPTIONAL. A folded entry correctly names the file, and states the
        rule, that was current on the day it landed, so a check that read the changelog would be born red
        on its own past -- which this repo already names as a smell in itself, and which is the recorded
        reason #1380's declaration-based candidate was set aside at 88/88. releases/ is out by the same
        logic and needs no rule of its own: it is neither always-on nor a reserved page, so it never
        enters the set. Excluded by NAME out of ReservedNames rather than through Get-ChangelogPath, on
        that property's own reasoning -- a seam may point anywhere, and a lib that went looking for a repo
        root to resolve it is a lib that can find the wrong tree.

        PLUGIN-SHIPPED PAYLOAD IS EXCLUDED (Source -ne 'tree'). The orchestrator's persona is '@'-imported
        from the marketplace clone by every repo, so it is one file rather than one finding per consumer --
        and it is the plugin's own text, which is the thing a consumer is supposed to be pointing AT.
        Without this exclusion #1380's own corpus counted it three times.

        A PER-BRANCH DOCUMENT IS NOT IN THE SET EITHER, and it falls out for free: it is transient working
        prose, it is not always-on, and it is not a reserved page. A branch whose own plan discusses a
        rename or a supremacy rule would otherwise report itself.

        IT RETURNS PATHS, NOT CONTENT, and it does not check that they exist. The caller joins them to its
        own RepoRoot and skips what is missing -- which is what lets the same list describe a consumer that
        carries the workflow folder and one that does not.
    #>
    param(
        # The always-on rows from Get-AlwaysOnDocuments. Optional: a caller with no walk available still
        # gets the folder's own pages judged, which is where one of #1389's two measured instances sat.
        [object[]]$Documents = @()
    )

    $paths = Get-BranchFilePaths
    $rels = New-Object System.Collections.Generic.List[string]
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($doc in $Documents) {
        if (-not $doc) { continue }
        if (-not $doc.Exists) { continue }
        if ($doc.Source -ne 'tree') { continue }
        $rel = [string]$doc.Display
        if ($rel -and $seen.Add($rel)) { $rels.Add($rel) | Out-Null }
    }

    foreach ($reserved in @($paths.ReservedNames)) {
        if (-not $reserved) { continue }
        if ($reserved -ieq 'CHANGELOG.md') { continue }
        $rel = "$($paths.Directory)/$reserved"
        if ($seen.Add($rel)) { $rels.Add($rel) | Out-Null }
    }

    return $rels.ToArray()
}

function Get-RetiredDocNameMention {
    <#
        Every line in a CONSUMER's own law-bearing prose that carries a retired name from
        Get-RetiredBranchDocNames -- i.e. a document restating a convention the plugin has moved on
        from. Issue #1389.

        THE DOCUMENT SET IS THE #1380 CORPUS, and stating it as an INCLUSION list is the load-bearing
        half. Two kinds of page:

          1. the always-on closure -- CLAUDE.md and everything it '@'-imports -- passed in as
             -Documents, because that walk belongs to measure-context-lib.ps1 and a second walk here
             would be a second definition of the always-on path;
          2. the workflow folder's own permanent pages, MINUS its changelog.

        THE CHANGELOG EXCLUSION IS NOT OPTIONAL. A folded entry correctly names the file that was current
        on the day it landed, so a check that read the changelog would be born red on its own past --
        which this repo already names as a smell in itself, and which is the recorded reason #1380's
        declaration-based candidate was set aside at 88/88. releases/ is out by the same logic and needs
        no rule of its own: it is neither always-on nor a reserved page, so it never enters the set.
        Excluded by NAME out of ReservedNames rather than through Get-ChangelogPath, on that property's
        own reasoning -- a seam may point anywhere, and a lib that went looking for a repo root to
        resolve it is a lib that can find the wrong tree.

        PLUGIN-SHIPPED PAYLOAD IS EXCLUDED (Source -ne 'tree'). The orchestrator's persona is
        '@'-imported from the marketplace clone by every repo, so it is one file rather than one finding
        per consumer -- and it is the plugin's own text, which is the thing a consumer is supposed to be
        pointing AT. Without this exclusion #1380's own corpus counted it three times.

        A PER-BRANCH DOCUMENT IS NOT IN THE SET EITHER, and it falls out for free: it is transient
        working prose, it is not always-on, and it is not a reserved page. A branch whose own plan
        discusses the rename would otherwise report itself.

        WHAT IT DOES NOT DO is decide whether the restatement AGREES with the plugin. It cannot, and that
        is the whole finding of #1380: a test that reads nearby text for the source and calls that
        deference is structurally blind to cites-then-contradicts, measured there at 1 in 4. Here the
        question never arises -- a retired filename is wrong whether the sentence around it agrees or not.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        # The always-on rows from Get-AlwaysOnDocuments. Optional: a caller with no walk available still
        # gets the folder's own pages judged, which is where one of the two measured instances sat.
        [object[]]$Documents = @()
    )

    $retired = @(Get-RetiredBranchDocNames)
    if ($retired.Count -eq 0) { return @() }

    $rels = @(Get-ConsumerProseDocuments -Documents $Documents)

    $findings = New-Object System.Collections.Generic.List[object]
    foreach ($rel in $rels) {
        $full = Join-Path $RepoRoot ($rel -replace '/', '\')
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
        $text = [System.IO.File]::ReadAllText($full, [System.Text.Encoding]::UTF8)
        $lines = $text -split "(?:\r\n|\n|\r)"
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = [string]$lines[$i]
            if (-not $line) { continue }
            # SPANS, NOT TOKENS, and this one is anticipatory rather than measured: NO pair in today's
            # set overlaps, so nothing here double-reports right now. It is kept because the set is
            # DERIVED and gains a row on every rename -- the day a new name contains an older one, a
            # single line of prose would be reported twice for one thing to repair, and the claim above
            # is what stops it. Cheap, and the alternative is discovering it from a doubled finding.
            $claimed = New-Object System.Collections.Generic.List[object]
            foreach ($name in $retired) {
                $at = $line.IndexOf($name.Name, [System.StringComparison]::OrdinalIgnoreCase)
                while ($at -ge 0) {
                    $end = $at + $name.Name.Length
                    $overlaps = $false
                    foreach ($c in $claimed) { if ($at -lt $c.End -and $c.Start -lt $end) { $overlaps = $true; break } }
                    if (-not $overlaps) {
                        $claimed.Add([pscustomobject]@{ Start = $at; End = $end }) | Out-Null
                        $findings.Add([pscustomobject]@{
                            Rel   = $rel
                            Line  = $i + 1
                            Name  = $name.Name
                            Kind  = $name.Kind
                            Since = $name.Since
                            Text  = $line.Trim()
                        }) | Out-Null
                    }
                    if ($end -ge $line.Length) { break }
                    $at = $line.IndexOf($name.Name, $end, [System.StringComparison]::OrdinalIgnoreCase)
                }
            }
        }
    }

    return @($findings | Sort-Object -Property Rel, Line, Name)
}

function Get-ProseParagraphUnits {
    <#
        A document's lines regrouped into the units a READER sees: one entry per blank-line-separated
        paragraph, blockquote markers stripped, hard-wrapped continuation lines joined with a single
        space -- each carrying a map back to the source line every piece came from. Issue #1415.

        WHY THIS EXISTS, AND IT IS A MEASURED DEFECT RATHER THAN A REFINEMENT. Get-SupremacyDeclaration
        first matched per PHYSICAL line, and this repo's prose convention hard-wraps paragraphs at about
        100 columns -- so an ordinary sentence puts 'CLAUDE.md' at the end of one line and 'wins' at the
        start of the next, and an adjacency test that never sees the two together reports nothing. Found
        by review and reproduced before it was repaired, in both forms:

            On any real conflict between the two, `CLAUDE.md`
            wins, and the contributing page is simply wrong.        -> 0 findings

            > Bij tegenspraak wint
            > `CLAUDE.md`.                                          -> 0 findings

        THE BLOCKQUOTE HALF IS THE ONE THAT MATTERS MOST, because the single real instance this whole
        check exists for lives in a blockquote. It happens to sit on one physical line today, so the
        check found it -- one editor re-wrapping that paragraph would have silently emptied the gate
        while every test still passed.

        THE SAME SHAPE IS ALREADY SETTLED ONE FILE UP. Get-EntryCodeSpans runs '(?s)' over the whole
        joined text, with the reason written beside it -- "because a span may legitimately wrap a line in
        prose". This is that reasoning applied to the same file's newest reader.

        NOT A WHOLE-DOCUMENT JOIN, DELIBERATELY. Matching over the entire text would let a bounded gap
        bridge two unrelated paragraphs, and -- worse -- would let one unbalanced quotation mark swallow
        the rest of the document into a single "quoted" span and suppress every real finding after it.
        The paragraph is the largest unit where both a sentence and its quotation marks reliably close.

        The map is kept as one row per appended segment (its offset in the joined text, and the source
        line it came from) rather than per character: a caller resolves a match to its line by taking the
        last row at or before the match offset, which is what lets a finding still name a real line
        number in the file somebody has to go and edit.
    #>
    # AllowEmptyString/AllowEmptyCollection are load-bearing, not defensive: the blank lines that
    # SEPARATE the paragraphs are the input, and a Mandatory [string[]] validates every element -- so
    # without these the function refuses exactly the documents it exists to read.
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        [string[]]$Lines
    )

    $units = New-Object System.Collections.Generic.List[object]
    $buffer = New-Object System.Text.StringBuilder
    $segments = New-Object System.Collections.Generic.List[object]

    function Add-Unit {
        if ($buffer.Length -gt 0) {
            $units.Add([pscustomobject]@{ Text = $buffer.ToString(); Segments = $segments.ToArray() }) | Out-Null
        }
        $buffer.Clear() | Out-Null
        $segments.Clear()
    }

    for ($i = 0; $i -le $Lines.Count; $i++) {
        # One pass past the end, so a document whose last paragraph runs to EOF is still emitted.
        $raw = if ($i -lt $Lines.Count) { [string]$Lines[$i] } else { '' }

        # Blockquote markers are stripped, not treated as text: '>' is punctuation the reader does not
        # see, and leaving it in would break the adjacency it sits between on a wrapped quote.
        $stripped = ($raw -replace '^\s*>+\s?', '')

        if ($stripped.Trim() -eq '') { Add-Unit; continue }

        # A LIST ITEM STARTS A NEW UNIT, and this is a measured regression rather than a nicety. Tight
        # lists are written with no blank line between the items, so without this the join runs two
        # unrelated bullets together -- and '*' is BOTH a bullet marker and the bold/italic decoration
        # the gap class has to allow, so a '*'-bulleted pair bridges into a match that exists in neither
        # item:
        #
        #     * Read the constitution in `CLAUDE.md`
        #     * wins arguments only when they cite the correct rank order.
        #
        # matched '`CLAUDE.md` * wins' -- a declaration in no line of the document. Found by review of
        # the wrap repair itself, which is what introduced it: the per-line detector never attempted
        # cross-line adjacency, so it could not have this defect.
        #
        # EVERY marker shape breaks the unit, not only '*'. Today '-', '+' and '1.' cannot bridge anyway
        # because they are outside the gap class -- which is exactly why they are included here: the day
        # somebody widens that class for a new decoration, the bound should already hold rather than
        # produce this same defect a second time in a shape nobody is looking for.
        $isListItem = $stripped -match '^\s*(?:[\*\-\+]|\d+[\.\)])\s+\S'
        if ($isListItem) {
            Add-Unit
            # The marker itself is dropped for the reason the blockquote marker is: it is punctuation
            # structuring the page, not a word in the sentence the reader is judging.
            $stripped = $stripped -replace '^\s*(?:[\*\-\+]|\d+[\.\)])\s+', ''
        }

        if ($buffer.Length -gt 0) { $buffer.Append(' ') | Out-Null }
        $segments.Add([pscustomobject]@{ Start = $buffer.Length; Line = $i + 1 }) | Out-Null
        $buffer.Append($stripped) | Out-Null
    }

    return $units.ToArray()
}

function Resolve-ProseUnitLine {
    <#
        The source line a match at $Offset inside one Get-ProseParagraphUnits unit came from: the last
        segment starting at or before that offset. Issue #1415.

        THE MATCH ITSELF MAY SPAN TWO LINES -- that is the entire point of joining them -- so this
        answers with the line the match BEGINS on, which is the line a reader opens to repair it.
    #>
    param(
        [Parameter(Mandatory)][object]$Unit,
        [Parameter(Mandatory)][int]$Offset
    )

    $line = 1
    foreach ($seg in @($Unit.Segments)) {
        if ($seg.Start -le $Offset) { $line = $seg.Line } else { break }
    }
    return $line
}

function Get-SupremacyDeclaration {
    <#
        Every line in a CONSUMER's own law-bearing prose that declares its OWN 'CLAUDE.md' the winner
        over the workflow's contributing page -- i.e. a repo inverting LAW-THIRD-RANK-ORDER, which puts
        the plugin's portable pages above 'dkj-policy/CONTRIBUTING.md' and that above the
        floor. Issue #1415.

        THE HOLE THIS CLOSES. #1380's whole finding was that a pointer test is STRUCTURALLY blind to
        cites-then-contradicts: a flagged finding is by construction a section carrying no citation, so a
        section that names its source and then overrides it can only ever appear among the SUPPRESSED
        findings. The census there was 4 suppressed sections -- 1 contradiction, 3 correct deferrals --
        and the one is the defect below. Nothing in the tree could see it, which is why the decline
        recorded a narrow literal grep for it instead of reviving the framework.

        WHAT THE RECORDED GREP SAID, AND WHY THIS IS NOT IT. The decline recorded the alternative as
        "'wins'/'wint' plus 'CLAUDE.md' plus the contributing page's own filename, all three in the same
        sentence". #1415 asked for that shape to be MEASURED before it shipped, because it had never been
        run, and the measurement overturned it. Over the same 8-document corpus:

            scope         raw   true   precision   recall (of the standing instances)
            line            0      0      --           0 of 2
            sentence        0      0      --           0 of 2      <- the recorded shape
            paragraph       1      0      0%           0 of 2

        Zero, at the scope the decline actually named, on the one defect it was named to catch. The
        reason is exact and worth keeping: the real clause (smartwatchbanden/CLAUDE.md:22) carries
        'wint' beside `CLAUDE.md` and names the contributing page by a Dutch PROSE NOUN,
        'de contributor-pagina', not by its filename. The third term is
        precisely the term that is absent. Loosening the scope to a paragraph does find something, and
        what it finds is a false positive; loosening the third term to catch prose nouns is the step into
        fuzzy matching that #1380 already declined.

        WHAT IS SHIPPED INSTEAD: ADJACENCY, WHICH ENCODES DIRECTION. 'CLAUDE.md' and 'wins'/'wint' must
        sit NEXT TO each other, in either order, with nothing between them but whitespace and markdown
        markup. That is still a purely literal character test -- it never reads what a sentence means --
        but it answers the one question co-occurrence cannot: WHICH page is being declared the winner.
        Direction is the whole defect. 'this page wins' over CLAUDE.md is the law stated CORRECTLY, and a
        term list holding both words scores it identically to the inversion; adjacency separates them,
        because the subject of the verb is the token beside it. Measured on the same corpus:
        3 raw / 2 reported / 2 true / 100% precision, and it finds BOTH standing instances -- one more
        than #1380's census knew about.

        THE ONE SUPPRESSION, AND ITS ONE INSTANCE. A hit sitting wholly inside a '"..."' span is skipped.
        The instance is xoxowildhearts quoting the closing line of a page it RETIRED, in order to explain
        why it removed it -- somebody else's words, reported, not this document's own claim. That is the
        same class as the changelog exclusion in Get-ConsumerProseDocuments and it is literal in the same
        way: a character-span test, not a reading. STATED PLAINLY, IT RESTS ON A SINGLE INSTANCE -- one
        false positive is a thin basis for a rule, and it is kept because without it precision is 67% and
        with it 100%, against a bar this repo sets by its accepted dead-link check (17 findings, 17 real)
        and its declined stale-path check (124 findings, none real).

        WHAT IT DOES NOT DO is decide whether a repo is ALLOWED to invert the order. It is not: the third
        rank is the plugin's, and a consumer that wants its own constitution to lead states that as a seam
        answer rather than by overriding the page in prose. But the check reports rather than adjudicates,
        and its message says which line to repair rather than what the repo should have meant.

        THE TWO STANDING INSTANCES, both in BWJ-ecommerce/smartwatchbanden, measured September 4, 2026:
        'CLAUDE.md:22' (the preamble inversion, the one #1380 could not see) and
        'dkj-policy/CONTRIBUTING.md:306' (the SAME inversion stated from the other side, which
        the #1380 census never counted at all).

        BOTH ARE CITED BY REPO, FILE AND LINE, AND THE EXCERPT STOPS AT THE ADJACENCY. That consumer is
        private and this repository is public, so a measurement taken there quotes only what the finding
        reads -- 'wint'/'wins' beside `CLAUDE.md`, which is this check's own pattern rather than anybody's
        prose -- and the governance sentence around it stays in the consumer's tree. The rule is in
        CLAUDE.md's public-repo bullet (Dave, September 5, 2026, issue #1420) and it binds the fixtures in
        consumer-prose-gate.tests.ps1 too: a matcher reads structure, so a fixture needs the shape
        and not the remaining words. Nothing about the verbatim-citation convention itself is weakened --
        a bounded quote plus file:line is still re-verifiable, which a paraphrase is not.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        # The always-on rows from Get-AlwaysOnDocuments -- passed straight through to the shared corpus.
        [object[]]$Documents = @()
    )

    $rels = @(Get-ConsumerProseDocuments -Documents $Documents)

    # ADJACENT, EITHER ORDER. The gap class holds whitespace and the markdown that decorates a term --
    # backticks, bold/italic markers, link brackets -- and nothing else. A comma or a word in between
    # ends the adjacency, which is the point: 'CLAUDE.md, which the contributing page wins over' is a
    # different claim and must not match. The cap keeps a long decorated run from bridging two clauses.
    # Dutch 'wint' sits beside English 'wins' because a consumer's constitution may be in either -- the
    # two live consumers are one of each, which is how the Dutch instance was found.
    $gap = '[\s`\*_\[\]\(\)]{0,12}'
    $pattern = "(?i)(?:``?CLAUDE\.md``?$gap\b(?:wins|wint)\b|\b(?:wins|wint)\b$gap``?CLAUDE\.md``?)"

    $findings = New-Object System.Collections.Generic.List[object]
    foreach ($rel in $rels) {
        $full = Join-Path $RepoRoot ($rel -replace '/', '\')
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
        $text = [System.IO.File]::ReadAllText($full, [System.Text.Encoding]::UTF8)
        $lines = $text -split "(?:\r\n|\n|\r)"

        # PARAGRAPHS, NOT PHYSICAL LINES -- see Get-ProseParagraphUnits for the two reproduced false
        # negatives that forced this. Both the adjacency match and the quotation suppression run on the
        # joined unit, because a wrapped sentence and a wrapped quotation are the same problem.
        foreach ($unit in @(Get-ProseParagraphUnits -Lines $lines)) {
            $quotes = @([regex]::Matches($unit.Text, '"[^"]*"'))
            foreach ($m in ([regex]::Matches($unit.Text, $pattern))) {
                $quoted = $false
                foreach ($q in $quotes) {
                    if ($m.Index -ge $q.Index -and ($m.Index + $m.Length) -le ($q.Index + $q.Length)) { $quoted = $true; break }
                }
                if ($quoted) { continue }

                $lineNo = Resolve-ProseUnitLine -Unit $unit -Offset $m.Index
                $findings.Add([pscustomobject]@{
                    Rel   = $rel
                    Line  = $lineNo
                    # The match is reported from the JOINED text, so a declaration that wrapped reads as
                    # one phrase here even though the file breaks it in two -- which is the thing the
                    # reader needs to recognise. Text stays the physical line they will open.
                    Match = ($m.Value -replace '\s+', ' ').Trim()
                    Text  = ([string]$lines[$lineNo - 1]).Trim()
                }) | Out-Null
            }
        }
    }

    return @($findings | Sort-Object -Property Rel, Line)
}
