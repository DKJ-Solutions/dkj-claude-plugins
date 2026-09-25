<#
.SYNOPSIS
    Pure release helpers (version determination + CHANGELOG transformation + release-notes
    building), separate from git/filesystem orchestration.

.DESCRIPTION
    Dot-source this file:

        . (Join-Path $PSScriptRoot '..\lib\release-lib.ps1')

    Supplies Get-NextVersion, Get-BumpType, Get-LockstepVersion, Get-PluginManifestPaths,
    Get-PullRequestEntries, Get-PullRequestEntriesByTier, Convert-ChangelogForRelease,
    Build-ReleaseNotes, Get-ReleaseTierHeading, Test-ReleaseBumpEarned, Get-EntryPlugins and
    Get-MarketplaceName. These functions are deliberately pure (string/value in, string/value out)
    so they can be tested separately without running a release -- scripts/release/cut-release.ps1
    uses them, and the tests cover them.

    The per-plugin CHANGELOG and RELEASE.md builders were retired on August 8, 2026; the retirement
    note further down says why. Get-EntryPlugins survives them: the `Plugins:` line still records
    which plugins an entry touched, and the release notes still read it.

    THE FLAT CHANGELOG (Dave, August 5, 2026). CHANGELOG.md is an intro followed by ONE ENTRY PER CHANGE,
    with no section headings at all -- the three '## Tier N - Pull Requests' sections and the
    '## Latest Release' block are gone. Four things follow from it in this file, and they are the whole
    of this change:

      * Split-Changelog parses no sections. The head is everything above the first entry heading; the
        entries are the blocks at that level below it. There is no seam left to ask which headings count.
      * The TIER COMES FROM THE ENTRY, not from the heading above it. Get-PullRequestEntriesByTier reads
        each entry's impact table (falling back to the older 'Tier: N' line), which is why the fold stopped
        consuming either -- the entry is the only carrier now.
      * THE CATEGORY GROUPING IS GONE, and with it Format-CategorizedEntries, the category labels and the
        Get-ReleaseCategoryTitles seam. A release document is a ranked list of changes, exactly as the
        changelog is; the type of each change is stated inside it, under its own '### Type of change'
        section, rather than inferred from a heading field and turned into a heading of its own.
      * A CUT WRITES NO RELEASE BLOCK. It empties the changelog down to its intro, and that intro's
        pointer to the repo's release history is the only thing left saying where releases live. Which
        also moved the internal note's inbound link: it is now the Version cell of the history overview's
        row -- see Set-ReleaseInternalNoteLink.

    A CONSUMER MID-MIGRATION HAS A MIXED DOCUMENT, and this file reads only the new shape's structure.
    That is deliberate rather than an oversight: an entry's own sections sit exactly one level below its
    heading, so a parser widened to accept that level too would read every entry as several. Depth alone
    also stopped telling a PRE-FORMAT entry heading from a current one at the August 26, 2026 shift --
    both are '### ' -- which is why that discrimination lives in Get-PreFlatChangelogRefusal, on whether
    a block declares an entry's named sections. The tier DECLARATION is still read in both shapes (table
    or 'Tier: N'), which is the half that can be recognised without ambiguity.

    ENTRY HEADINGS ARE RE-LEVELLED AS A WHOLE, not on their first line. An entry now carries H4 sections
    of its own, so shifting only the heading would leave those sections at the level the entry itself
    sits at -- one entry rendering as several. Format-RankedEntries shifts every non-fenced heading in
    the block by the same delta.

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script.

    Note: this file is deliberately pure ASCII (repo convention for .ps1). Non-ASCII output
    characters (middot, em-dash) are built via [char]0x.. rather than as a literal -- Windows
    PowerShell 5.1 reads a BOM-less script as ANSI and would otherwise mangle a literal.

    NOTE (Sylvester, English script-layer sweep, #114 follow-up): the DOCUMENT-GENERATING template
    strings in this file (the catTitle category labels, the "See [...] for the full release notes"
    reference line, the ## Releases / plugin-CHANGELOG intro texts, the **Date:** label) now produce
    ENGLISH CHANGELOG.md / release-notes / per-plugin-CHANGELOG content, per Dave's follow-up
    decision to also migrate this generated-content language (not just comments/console output).
    Existing history is the deliberate exception and is left untouched: already-folded CHANGELOG.md
    sections and the releases/** notes stay in whatever language they were written in -- only
    FUTURE output from these templates changed, so a mix of Dutch history and English new content is
    expected and fine.

    SHARPENED August 3, 2026 -- "only future output changed" is true of every template here EXCEPT
    one, and the exception cost four consumer-facing files. A template that appends (a release
    section, a reference line) reaches its file again on the next release, so editing it does
    propagate. The per-plugin CHANGELOG INTRO was the one that did not: it was written only for a
    file that did not exist yet, so the four existing CHANGELOGs kept an intro naming the retired
    marketplace long after the rename had swept it out of 59 files. "Leave history alone" was the
    right instinct applied to the wrong text -- the entries below the intro were history, the intro
    was a live statement about the present mechanism.

    THE RULE OUTLIVES THE FILES IT WAS LEARNED ON, which is why it stays here after those documents
    were retired on August 8, 2026: for the next template added below, ask whether the string is
    rewritten on every release, and if it is not, it needs a gate rather than a good intention.
#>

# The branch types (Feat/Fix/Docs/Chore) have a single source in branch-info.ps1; Build-ReleaseNotes
# reads them via Get-BranchTypes instead of its own copy.
#
# DOT-SOURCED FROM THE SAME FOLDER ONLY WHEN THAT FOLDER HAS IT, and that condition is the whole point
# since this lib became shared (#417). branch-info.ps1 is REPO-OWNED -- the prefix table differs per
# repo -- so it does not travel into the plugin mirror, while this file does. In the workshop root the
# two are siblings and this dot-source is what it always was; from the mirror the sibling is absent and
# the caller (cut-release.ps1) has already dot-sourced the CONSUMER's branch-info from its repo root,
# which puts Get-BranchTypes in scope for the functions below.
#
# Guarded rather than removed, because release-lib is also loaded directly by its own tests and by
# callers that never resolve a repo root. Get-ReleaseChangeTypes probes for the function instead of
# assuming it, and states its fallback -- see there.
$branchInfoSibling = Join-Path $PSScriptRoot 'branch-info.ps1'
if (Test-Path -LiteralPath $branchInfoSibling) { . $branchInfoSibling }

# THE ENTRY FORMAT (the flat changelog, August 5, 2026): Get-EntryHeadingLevel and Get-EntrySectionLevel
# for the heading levels this file parses and re-levels, Resolve-EntryImpact + Get-EntryImpactScore for the
# tier and the significance it reads out of each entry, and Remove-EntryImpactTable +
# Remove-EntryTierLine for the documents that travel outward. Unlike branch-info above, this sibling is
# NOT repo-owned -- it travels in the same mirror as this file -- so the dot-source is unconditional in
# every location it can run from.
#
# WHY THE FORMAT LIVES THERE AND NOT HERE. The fold needs the same answers, and it reaches this lib only
# where the repo happens to have a copy in its own root (see that script's guarded dot-source), while it
# always has entry-scaffold-lib. Defining the format here would have meant two definitions of one fact --
# the exact thing this repo keeps repairing -- so it lives in the lib both scripts can reach and this one
# reads it from there. Get-ChangelogTierSections used to be read here too and is retired: a flat document
# has no sections, so there is no map left to agree about.
. (Join-Path $PSScriptRoot 'entry-scaffold-lib.ps1')

# THE PLUGIN SET: which plugins this repo publishes, and where each one's folder is. Unconditional for
# the same reason as the sibling above -- it travels in this mirror, so it is present wherever this file
# is. Get-PluginManifestPaths below is a thin wrapper over it, and Get-TouchedPlugins reads the same
# roots rather than matching a path shape.
. (Join-Path $PSScriptRoot 'plugin-tree-lib.ps1')

function Get-NextVersion {
    <# Bumps a SemVer X.Y.Z according to $BumpKind (major|minor|patch). #>
    param(
        [Parameter(Mandatory)][string]$Current,
        [Parameter(Mandatory)][ValidateSet('major', 'minor', 'patch')][string]$BumpKind
    )
    if ($Current -notmatch '^\d+\.\d+\.\d+$') { throw "Current version '$Current' is not a valid X.Y.Z." }
    $p = $Current -split '\.'
    [int]$maj = $p[0]; [int]$min = $p[1]; [int]$pat = $p[2]
    switch ($BumpKind) {
        'major' { $maj++; $min = 0; $pat = 0 }
        'minor' { $min++; $pat = 0 }
        'patch' { $pat++ }
    }
    return "$maj.$min.$pat"
}

function Get-BumpType {
    <# Determines the bump type (major/minor/patch) from an old and new SemVer. #>
    param(
        [Parameter(Mandatory)][string]$From,
        [Parameter(Mandatory)][string]$To
    )
    if ($From -notmatch '^\d+\.\d+\.\d+$' -or $To -notmatch '^\d+\.\d+\.\d+$') { throw "From/To must be X.Y.Z." }
    $f = $From -split '\.'; $t = $To -split '\.'
    if ([int]$t[0] -ne [int]$f[0]) { return 'major' }
    if ([int]$t[1] -ne [int]$f[1]) { return 'minor' }
    return 'patch'
}

function Get-LockstepVersion {
    <#
        Determines the shared (lockstep) version from a set of plugin.json contents. Input is a
        hashtable of name/path -> raw JSON text. Throws if a version is missing or if they are not
        equal.
    #>
    param([Parameter(Mandatory)][hashtable]$ManifestContents)
    if ($ManifestContents.Count -eq 0) { throw "No plugin manifests given." }
    $versions = @{}
    foreach ($key in $ManifestContents.Keys) {
        if ($ManifestContents[$key] -match '"version"\s*:\s*"(\d+\.\d+\.\d+)"') {
            $versions[$key] = $matches[1]
        } else {
            throw "Could not find a valid 'version' (X.Y.Z) in '$key'."
        }
    }
    $distinct = @($versions.Values | Sort-Object -Unique)
    if ($distinct.Count -ne 1) {
        $detail = ($versions.GetEnumerator() | ForEach-Object { "  $($_.Key): $($_.Value)" }) -join "`n"
        throw "Plugin versions are not in lockstep (must be equal for a repo-wide release):`n$detail"
    }
    return $distinct[0]
}

function Test-ReleaseBumpEarned {
    <#
        Pure: does the pending work justify the bump being asked for? Returns an object with

          Earned          $true when the bump may be cut
          EarnedBump      the bump the pending tiers WARRANT: 'minor', 'patch', or $null when nothing
                          may be released at all. Never 'major' -- see below.
          MajorAvailable  $true when this major line has had enough minors for a major to be allowed
          Reason          why not, ready to print; '' when Earned
          Counts          tier -> number of pending entries, for the message
          Active          $false when no pending entry declared its impact at all, so nothing was judged

        EarnedBump DELIBERATELY NEVER SAYS 'major', even when one would be permitted. The pending
        entries cannot warrant a major -- what earns it is the ten minors behind it, which is a
        milestone somebody decides to mark rather than a size the work adds up to. Reporting 'major'
        as the bump this work warrants would nudge a routine tier-1 change into one. So the two facts
        are reported separately: what the work warrants, and whether a major is available at all.

        THE RULES (Dave, August 5, 2026), and each answers a question the version number was already
        supposed to answer but nothing enforced:

          any release   nothing. A release made entirely of tier-0 work is a PATCH -- publishing to no
                        audience is what a patch is for (Dave, August 7, 2026). This used to refuse
                        outright, on the grounds that such a release "has nobody to announce it to";
                        the answer is that it announces nothing, which is allowed.
          minor         at least one entry of TIER 1 or higher -- something an audience beyond this
                        repo's own developers gets out of it. It used to demand a tier-2 entry, so tier-1 work
                        earned only a patch. Loosened deliberately: the version here speaks to all
                        stakeholders, not to consumers alone. What keeps it honest is that the DOCUMENTS
                        follow the tier and not the bump -- a tier-1-only minor writes the internal note
                        and no consumer document, so nobody outside is handed an empty document.
          major         at least $MinMinorsForMajor minors cut in the current major line, on top of the
                        general minimum. A major is a RECAP of those minors, so what earns it is their
                        accumulation rather than any single pending change -- which is why a tier-2 entry
                        is deliberately NOT required here. Read off the minor component of
                        $CurrentVersion: within major 3 the minors are 3.1 .. 3.10, so the component IS
                        the count of minors cut in that line.

        OFF WHEN NO PENDING ENTRY DECLARED ITS IMPACT, and that is what keeps this safe to share. A repo
        that never adopted the model writes entries with no impact table and no 'Tier:' line; every one of
        them reads as tier 0, so a gate would refuse every release that repo ever cuts -- a shared script
        silently imposing a model nobody there chose.

        THE TEST USED TO BE THE NUMBER OF TIER SECTIONS, and it had to change with them (August 5, 2026).
        Counting groups worked while the changelog declared its tiers as headings: one section meant no tier
        information. A flat changelog has no sections, so an unadopted repo and an adopting one both produce
        exactly one group -- tier 0 -- and the old line would have read every repo as not adopting, silently
        switching the gate off in the same change that made the tier the document's primary ordering.

        SO THE SIGNAL IS 'Declared', WHICH IS A MEASUREMENT RATHER THAN A FLAG. Get-PullRequestEntriesByTier
        counts, per group, how many entries actually STATED their reach. None anywhere means nothing was
        adopted, and nothing is judged. At least one means the repo is using the model, and an all-tier-0
        release is then refused on purpose -- which is the whole point of the gate, and is why "declared
        tier 0" must not be confused with "declared nothing". -SkipTierGate in cut-release.ps1 is the escape
        valve for the repo mid-adoption whose one declared entry happens to be tier 0.
    #>
    param(
        [Parameter(Mandatory)][ValidateSet('major', 'minor', 'patch')][string]$BumpType,
        # Array of objects with Tier, Entries and Declared -- what Get-PullRequestEntriesByTier returns.
        [AllowEmptyCollection()]$TierGroups = @(),
        [Parameter(Mandatory)][string]$CurrentVersion,
        [int]$MinMinorsForMajor = 10
    )
    $groups = @($TierGroups)
    $counts = @{}
    $anyDeclared = $false
    foreach ($g in $groups) {
        $counts[[int]$g.Tier] = @($g.Entries | Where-Object { $_ -and $_.Trim() }).Count
        # PSObject.Properties, not a bare property read: a caller (or a test) building groups by hand
        # without the Declared field would otherwise make this throw under a strict caller, or read $null
        # as 0 and switch the gate off -- the silent direction.
        if ($g.PSObject.Properties['Declared'] -and [int]$g.Declared -gt 0) { $anyDeclared = $true }
    }

    $result = [pscustomobject]@{
        Earned         = $true
        EarnedBump     = $BumpType
        MajorAvailable = $false
        Reason         = ''
        Counts         = $counts
        Active         = $anyDeclared
    }
    if (-not $result.Active) { return $result }

    # TIER 1 OR HIGHER, counted as one number rather than per tier. A separate tier-2 count stood here
    # until August 12, 2026, assigned and read nowhere: it was load-bearing while a minor REQUIRED a
    # tier-2 entry, and the rule became "tier 1 or higher -> minor" on August 7 without the variable
    # going with it. Written as >= 1 rather than against the audience tier deliberately, so this reads
    # correctly in a tier-1 repo and a tier-2 repo alike with neither having to translate it.
    #
    # THE LOOP AND THE 'minor'/'patch' CHOICE BELOW MOVED TO Get-EntryEarnedBump, in entry-scaffold-lib,
    # on September 7, 2026 (issue #1545). It is called and not restated: the changelog's pending tally
    # names the earned bump now, and the tally is written by the FOLD, which loads entry-scaffold-lib
    # standalone and never this file. Defining it there and calling it here is what keeps that one rule
    # one rule -- the alternative was a second copy of this arithmetic inside the document this gate then
    # reads. Everything this function still owns is below: whether the bump ASKED for is the one earned,
    # and whether a major is available at all.
    $earned  = Get-EntryEarnedBump -ByTier $counts
    $notable = $earned.Notable

    if ($CurrentVersion -notmatch '^\d+\.(\d+)\.\d+$') { throw "CurrentVersion '$CurrentVersion' is not X.Y.Z." }
    $minorsSoFar = [int]$Matches[1]

    # What the pending set warrants, computed once and reported whether or not it matches what was asked
    # -- so a refusal can name the bump that WOULD work instead of only what will not.
    # THE BUMP FOLLOWS THE HIGHEST TIER PENDING (Dave, August 7, 2026), and the rule is one sentence:
    #
    #   tier 0 only            -> patch. Nobody outside this repo notices, which is what a patch IS.
    #   tier 1 or higher       -> minor. Something beyond this repo's own developers got something.
    #
    # TWO THINGS CHANGED HERE, AND BOTH LOOSEN THE LADDER BY ONE STEP.
    #
    # A TIER-0-ONLY RELEASE IS NOW ALLOWED, where it used to be refused outright ("nothing pending reaches
    # beyond this repo... a release needs at least one tier-1 entry"). That refusal read the absence of an
    # audience as a reason not to publish; Dave's answer is that publishing to no audience is precisely what
    # a patch is for. The version still moves, the record is still written, and no announcement is owed.
    #
    # AND TIER 1 NOW EARNS A MINOR, where it used to earn a patch and a minor demanded tier 2. Weighed
    # explicitly: it means a release can bump the minor with nothing in it for a consumer, which is the
    # opposite of what a minor usually promises. Dave chose it knowing that -- the version speaks to ALL
    # stakeholders here, colleagues included, not to consumers alone. What keeps that honest is that the
    # DOCUMENTS still follow the tier rather than the bump: a tier-1-only release writes the internal note
    # and no consumer document, so nobody outside is handed a document with nothing in it. See the tier-2
    # trigger in cut-release.ps1, which keys on a tier-2 entry rather than on this bump type for exactly
    # that reason.
    $result.MajorAvailable = ($minorsSoFar -ge $MinMinorsForMajor)
    $result.EarnedBump = $earned.Bump

    # BOTH minor AND major, and that second one is a defect this file's own suite caught on the first run.
    # The refusal was written for 'minor' alone, which let a MAJOR through on tier-0-only work -- a bigger
    # claim than the one being refused beside it. A major recaps the minors behind it, but it still has to
    # be a release, and a release of nothing but repo-internal work is a patch whatever its history.
    $tier0 = if ($counts.ContainsKey(0)) { $counts[0] } else { 0 }
    if (@('minor', 'major') -contains $BumpType -and $notable -eq 0) {
        $result.Earned = $false
        $result.Reason = "a $BumpType is what somebody outside this repo's own developers gets something out of, and everything pending is tier 0 ($tier0 entry/entries). Cut a patch, or raise the tier of the entry that a colleague or a consumer does notice."
        return $result
    }
    # AND THE REFUSAL NAMES THE SEAM, NOT ONLY THE NUMBER (inbound #1151, August 30, 2026). It answered
    # two of a reader's three questions well -- the threshold, and how many minors this line has had --
    # and left the third with two routes, of which the legitimate one was absent. "Cut the minor instead"
    # is right where the bump was simply wrong; -SkipTierGate is the bypass, named in full by cut-release.ps1,
    # which prints this Reason inside its own refusal. Get-ReleaseMajorMinMinors appeared in neither, so the
    # repo this threshold was NOT measured for -- the one the seam exists to serve, whose own blueprint record
    # says "a repo that cuts minors rarely sets this lower" -- met a hard refusal with no configuration-shaped
    # answer on offer and the bypass as the nearest thing to one. That is the worse of the two outcomes: it
    # overrules a content judgement that was correct, where answering the seam produces a correct release.
    #
    # MEASURED IN A FRESH CONSUMER (DaveKJohn/ccs-testrun-4, at v0.1.0 against v4.26.0), not argued. The seam
    # is discoverable in CONTRIBUTING-portable.md, the cut-release skill page and the contract registry --
    # and a person meeting a refusal reads the refusal. This is the one class of refusal in this workflow
    # whose remedy is a configuration value rather than an act on the branch, which is why it is the one
    # that has to carry the seam's name in the message itself.
    #
    # AND THE CLAUSE ITSELF STAYS FLAT. Its first draft nested two --...-- asides inside the sentence and
    # closed on "to the number that is", which asks a reader meeting a hard refusal to hold a clause from
    # several words back. The tier-0 refusal directly above stays flat, and so does this one now.
    if ($BumpType -eq 'major' -and $minorsSoFar -lt $MinMinorsForMajor) {
        $result.Earned = $false
        $result.Reason = "a major recaps the minors before it, and this major line has had $minorsSoFar of them (v$CurrentVersion) -- $MinMinorsForMajor is the threshold. Cut the minor this work earns instead, or, if this repo cuts minors rarely, set Get-ReleaseMajorMinMinors in scripts/repo-config.ps1 to its own cadence."
        return $result
    }
    return $result
}

function Get-MarketplaceName {
    <#
        The marketplace's own name, read from 'name' in the marketplace JSON. Pure (does not touch
        disk): input is the raw JSON text.

        Exists so that the two places needing this name -- cut-release.ps1, which writes it into a
        new per-plugin CHANGELOG intro, and check 17 of check-plugin-integrity.ps1, which holds the
        existing intros against that same text -- read one field through one function instead of
        each carrying a literal. A literal in either place is what let the retired name survive the
        rename in four consumer-facing files.

        PARSES THROUGH ConvertFrom-MarketplaceJson (plugin-tree-lib.ps1, dot-sourced above) rather than
        ConvertFrom-Json, for the reason written at that function: 5.1's own reader cannot represent a
        manifest carrying two keys that differ only in case. cut-release.ps1 calls Get-PluginRoots and
        this function on the SAME document text, four lines apart in one function, so routing only the
        first would have moved #1993's symptom rather than removed it (Victor, on that branch).
    #>
    param([Parameter(Mandatory)][string]$MarketplaceJson)
    $marketplace = ConvertFrom-MarketplaceJson -MarketplaceJson $MarketplaceJson
    if (-not ($marketplace.PSObject.Properties.Name -contains 'name') -or -not $marketplace.name) {
        throw "marketplace.json has no non-empty 'name'."
    }
    return [string]$marketplace.name
}

function Get-PluginManifestPaths {
    <#
        The plugin manifest paths, derived from plugins[].source in the marketplace JSON. Pure (does
        not touch disk): input is the raw JSON text + the repo root, output is an array of full
        manifest paths.

        A WRAPPER SINCE plugin-tree-lib.ps1 EXISTS, and kept under this name because it is what the
        release cut and the lint gate call. The derivation itself -- including the containment check
        that stops a source pointing outside the repo -- moved to Get-PluginRoots, which answers the
        same question with the plugin's NAME and ROOT alongside the manifest path. Four other places
        needed those two fields and were each deriving them from a path shape instead.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$MarketplaceJson
    )
    foreach ($p in (Get-PluginRoots -RepoRoot $RepoRoot -MarketplaceJson $MarketplaceJson)) {
        $p.ManifestPath
    }
}

# --- MOVED, NOT DELETED: Get-FencedLineFlags now lives in entry-scaffold-lib.ps1 -------------------
#
# The three readers below (Split-EntryBlocks, Split-Changelog, Set-EntryHeadingLevel) still call it by
# exactly that name, and it is in scope here because this file dot-sources entry-scaffold-lib
# unconditionally, at the top.
#
# WHY IT MOVED DOWN A LAYER RATHER THAN THE OTHER ONE MOVING UP. There were four fence walks in the two
# libs -- this named function, a second named one in entry-scaffold-lib, and two inline walks inside its
# removers -- and they were not equivalent: only this one recognised '~~~' fences. So an entry using tilde
# fences had its quoted content read as STRUCTURE by every reader in that file while the readers here
# handled it correctly. One question, one answer, and it has to sit in the lib that owns the entry format,
# because the dependency can only run this way: the fold and entry-scaffold-lib's own suite load that lib
# standalone, while nothing loads this one without it.
#
# The name deliberately did not gain an 'Entry' prefix on the way down: the readers here scan a whole
# CHANGELOG rather than one entry, so a name claiming otherwise would be wrong at three call sites -- and
# keeping it meant the move changed no call site in either lib.

# --- MOVED, NOT DELETED: Get-EntryHeadingPattern and Split-EntryBlocks -----------------------------
#
# Both now live in entry-scaffold-lib.ps1, on August 10, 2026, and the readers below still call them by
# exactly those names -- they are in scope because this file dot-sources that lib unconditionally, at the
# top, exactly as with Get-FencedLineFlags above.
#
# WHY THEY MOVED DOWN A LAYER. The fold needs the entry-boundary rule too, and it deliberately does not
# load this file: its header rejects pulling this lib -- and the thousands of lines of entry-scaffold-lib
# behind it -- into a script that runs immediately after a merge and directly on the trunk. The dependency can only run one way -- the
# fold and entry-scaffold-lib's own suite load that lib standalone, while nothing loads this one without
# it -- so a rule both the cut and the fold read has to sit down there. Inbound #561 is the defect that
# forced the question: the two scripts shared an assumption about what an H2 means and only one of them
# checked it.

function Split-Changelog {
    <#
        Private helper: parses CHANGELOG.md into its parts. Returns an object with

          Nl       the newline style the document uses
          Head     everything above the first entry heading -- the title and the intro
          Entries  every entry block, in document order

        Throws when the document holds no entry: a cut with no entries produces a release note
        describing nothing.

        NO SECTIONS AT ALL (Dave, August 5, 2026). This parsed two sections, then N of them, and now none.
        The document is an intro followed by one entry per change, so the only boundary is the first entry
        heading -- and that is derived STRUCTURALLY rather than read from a seam. Everything the seam
        version needed goes with it: the '## Releases' / '## Latest Release' lookup and its fatal throw,
        the per-section intro, the section index that let either order be valid, and the "which headings
        count" question itself. There is no name to look up, so there is nothing to mismatch.

        THE ORDER OF THE ENTRIES IS THE FOLD'S RANKING, and this function must not sort. The fold placed
        each entry at its ranked position when it landed, because that is the only moment it could -- the
        cut empties this list, so document order at cut time IS the order the release documents inherit.
        Re-sorting here would be a second opinion formed from the same numbers, and one that could differ
        (PowerShell's Sort-Object is not stable), which is exactly the reproducibility the two-moment
        design exists to guarantee.

        TRAILING BLANKS ARE STRIPPED FROM THE HEAD, and that is a correctness fix rather than tidiness. The
        head as read ends with the blank line separating it from the first heading; the caller adds its own
        separator, so each cut left one more blank than the last. Measured over three consecutive cuts:
        2, 3, 4. It renders identically in markdown, which is exactly why it would have gone on growing --
        nothing looks wrong until a reader opens the raw file years in.
    #>
    param([Parameter(Mandatory)][string]$Content)

    $nl = Get-DocumentNewline -Content $Content
    $lines = $Content -split "`r?`n"

    # Fence-aware: an intro that quotes an entry heading inside a fence -- this repo's own changelog
    # documents the entry format, so it does -- would otherwise put the intro/entries boundary in the
    # middle of a code block.
    $headingRx = Get-EntryHeadingPattern
    $fenced = Get-FencedLineFlags -Lines $lines
    $firstEntry = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ((-not $fenced[$i]) -and $lines[$i] -match $headingRx) { $firstEntry = $i; break }
    }

    if ($firstEntry -lt 0) {
        throw "No changelog entries in CHANGELOG.md -- nothing to release. (An entry is an H$(Get-EntryHeadingLevel) block below the intro; the fold puts them there.)"
    }

    $head = if ($firstEntry -gt 0) { @($lines[0..($firstEntry - 1)]) } else { @() }
    while ($head.Count -gt 0 -and $head[-1].Trim() -eq '') { $head = @($head[0..($head.Count - 2)]) }

    $entries = @(Split-EntryBlocks -Lines @($lines[$firstEntry..($lines.Count - 1)]) -Nl $nl)
    if ($entries.Count -eq 0) {
        throw "No changelog entries in CHANGELOG.md -- nothing to release."
    }

    # A LEFTOVER SECTION HEADING IS NOT AN ENTRY, AND THIS REFUSAL IS WHY (August 5, 2026). Every '## '
    # below the intro is read as one change now, and a document still carrying the pre-flat shape has
    # headings at exactly that level. Measured on both of them before this guard existed: a consumer's
    # '## Pull Requests' parsed as ONE entry swallowing all of their real ones and '## Releases' as a
    # second, so their whole release history was published outward as a "change" and then deleted from
    # CHANGELOG.md -- and nothing refused, because blocks like that declare no impact and the bump gate
    # therefore reads the repo as never having adopted the model and reports itself inactive. Silent,
    # correct-looking, and it loses data on a repo that never asked for the change; a shared script reaches
    # a consumer through a plugin update rather than by their choosing.
    #
    # THE TEXT IS SHARED WITH THE FOLD SINCE AUGUST 10, 2026 (inbound #561). It was written here first,
    # and the fold -- which makes the same assumption about what an H2 means -- had no check at all: it
    # wrote the entry above the section heading and reported success. Get-PreFlatChangelogRefusal in
    # entry-scaffold-lib.ps1 now owns the diagnosis and the migration advice; this call supplies only the
    # clause that differs, which is what each script is about to DO to a block it cannot read.
    #
    # Still named per offending block, and still BEFORE anything is written, so a cut stops with the
    # document intact.
    $refusal = Get-PreFlatChangelogRefusal -Content $Content -Consequence 'these would be released as changes -- and the cut empties this file, which would remove them'
    if ($refusal) { throw $refusal }

    return [pscustomobject]@{
        Nl      = $nl
        Head    = $head
        Entries = @($entries)
    }
}

function Get-PullRequestEntries {
    <# Returns the entry blocks to be released, in document order (which is the fold's ranked order). Use
       Get-PullRequestEntriesByTier where the tier matters. #>
    param([Parameter(Mandatory)][string]$Content)
    return @((Split-Changelog -Content $Content).Entries)
}

function Get-PullRequestEntriesByTier {
    <#
        The pending entries PER TIER, highest tier first: an array of objects with

          Tier      the tier as an int
          Heading   the tier's audience wording ('Tier 2 - consumers'). NO GENERATED DOCUMENT PRINTS IT
                    ANY MORE since #881 (August 25, 2026) -- the development notes render at
                    CHANGELOG.md's own levels, with no grouping heading. Kept rather than deleted: it is
                    the single source of that wording, every development note ever cut carries it, and
                    removing a published field of this contract is a separate decision from the level
                    defect this change repaired. Same answer, and for the same reason, as the one v4.8.0
                    already recorded for this heading.
          Entries   its entry blocks, in document order
          Declared  how many of those entries actually DECLARED their impact

        Its own function beside the flat Get-PullRequestEntries because the two callers want genuinely
        different things and neither should derive the other:

          the flat list  -- the per-plugin CHANGELOGs and the RELEASE.md cards, which select on the
                            'Plugins:' line and do not care how far a change reaches;
          per tier       -- the release notes (which order and rank on it), the consumer document (tier 2
                            only) and the cut's bump gate (which tiers are pending at all).

        THE TIER NOW COMES FROM THE ENTRY, which is the reversal this change is about. It used to come from
        the changelog SECTION an entry sat in, and this function's own header said deriving it from the
        entry was "impossible on purpose" because the fold removed the 'Tier:' line the moment the section
        took over stating it. With the sections gone that sentence inverted: the fold consumes nothing, the
        entry carries its impact table (or the older line) into the changelog, and Resolve-EntryImpact reads
        it here.

        GROUPED ON THE HIGHEST TIER AN ENTRY CLAIMS, so the groups stay DISJOINT -- exactly as the sections
        were. The ladder is cumulative in terms of which DOCUMENTS an entry reaches, and that is the
        caller's business: the development note renders every group, the consumer document takes tier 2 only. An
        entry appearing in two groups here would put it twice in the record.

        Declared IS NOT BOOKKEEPING -- it is what tells an adopting repo from one that never heard of tiers.
        An entry with no table and no 'Tier:' line reads as tier 0 exactly like a declared tier-0 entry, and
        Test-ReleaseBumpEarned has to be able to tell those apart or it refuses every release a
        non-adopting consumer ever cuts. Counted here because this is where the resolve already happens.
    #>
    param([Parameter(Mandatory)][string]$Content)

    $entries = @((Split-Changelog -Content $Content).Entries)
    $byTier = @{}
    $declared = @{}
    foreach ($e in $entries) {
        $impact = Resolve-EntryImpact -EntryText $e
        $tier = [int]$impact.Tier
        if (-not $byTier.ContainsKey($tier)) {
            $byTier[$tier] = New-Object System.Collections.Generic.List[string]
            $declared[$tier] = 0
        }
        $byTier[$tier].Add($e)
        if ($impact.Declared) { $declared[$tier]++ }
    }

    # Highest tier first: the order the model reads in, and the order the release notes are written in.
    # Sorted rather than trusted to the hashtable, which has no order of its own.
    $out = @()
    foreach ($tier in @($byTier.Keys | Sort-Object -Descending)) {
        $out += [pscustomobject]@{
            Tier     = $tier
            Heading  = (Get-ReleaseTierHeading -Tier $tier)
            Entries  = @($byTier[$tier].ToArray())
            Declared = $declared[$tier]
        }
    }
    return @($out)
}

# --- RETIRED, AUGUST 5, 2026: the release block's wording (inbound #462) --------------------------
#
# $script:ChangelogReleaseWordingDefaults and Get-ChangelogReleaseWordingLines held four strings a
# release wrote into CHANGELOG.md: the two intros for the release section, the "see the full notes"
# pointer line, and the sentence repointing that line at the internal note. All four described the
# release BLOCK, and CHANGELOG.md no longer has one -- a cut now empties the document down to its intro
# and writes nothing else. Four strings with nothing to write them into is not a seam, it is dead config,
# which this repo's own rule says to remove rather than leave returning values nothing reads.
#
# WHAT THE CONSUMER WHO ASKED FOR #462 LOSES, stated rather than glossed over: that inbound issue was
# from a non-English repo, and it made these strings repo-owned precisely because they were the most
# visible generated output in the file. The capability is not being taken away from them -- the OUTPUT is
# gone. What replaced it, the intro paragraph's own pointer to the release history, is hand-written prose
# in a file the repo owns outright, so it needs no seam to be in their language: it simply is.
#
# The Get-ChangelogReleaseWording seam in scripts/repo-config.ps1 retires with them. A consumer that
# still defines it is unaffected -- nothing calls it, so it is dead code in that repo's seam, and its
# next cut behaves exactly as this repo's does.

function Convert-ChangelogForRelease {
    <#
        Empties CHANGELOG.md down to its intro: the head is kept, every entry block the release just
        consumed is removed, and nothing is written in their place. Pure string in/out.

        IT WRITES NO RELEASE BLOCK, and that is the change rather than a simplification of it (Dave,
        August 5, 2026). This function used to rebuild one section per tier plus a '## Releases' or
        '## Latest Release' block carrying the version, the date, the type and a pointer to the notes. All
        of it is gone, and with it $Version, $Date, $Type, $NotesRelPath, $LiveMarker, $HistoryMode,
        $HistoryRelPath, $TierSections and $Wording -- the whole parameter list except the content, because
        every one of them existed to describe a block that no longer exists.

        THE MEASURED REASON, and it is worth keeping because the first half of it has already been acted on
        once. The accumulating section had grown to 434 of the changelog's 1,062 lines -- 41% -- across 72
        blocks that each said no more than "see the notes", while releases/README.md listed every one of
        those 72 versions with a date, a type and a descriptive title: the same coverage, verified in both
        directions, and richer per row. 'latest' mode cut that to a single block in August 2026; this
        removes the last one. What answers "which version is current" is the release history itself, which
        the intro points at in one line -- hand-written prose in a file the repo owns, so it needs no seam
        and cannot go stale at a cut that no longer touches it.

        THE HEAD IS THE FIXED ONE, NOT THE REPO'S OWN (issue #2486, September 25, 2026). This used to pass
        the intro through verbatim, so whatever a repo wrote about itself survived every cut -- which is
        exactly how the intros of the consumers came to say different things about one mechanism. It is
        now re-applied by Set-ChangelogCanonicalHead, the same function the fold and the scaffold use, so a
        cut leaves the head byte-identical to every other repo's. The pending heading and the tally line
        beneath it are kept; the caller re-derives the tally.
    #>
    param([Parameter(Mandatory)][string]$Content)
    $s = Split-Changelog -Content $Content
    return (Set-ChangelogCanonicalHead -Content ((@($s.Head) -join $s.Nl).TrimEnd() + $s.Nl))
}

function Set-ReleaseInternalNoteLink {
    <#
        Point the release history overview's row for $Version at the INTERNAL note. Pure string in/out,
        and idempotent: run twice and the second call changes nothing.

        WHY THIS IS A SEPARATE STEP RATHER THAN PART OF THE CUT (August 4, 2026). The internal note does
        not exist when cut-release.ps1 runs: that script commits AND tags in one motion, while the internal
        note needs the developer notes as its input and is therefore written afterwards, by hand, landing
        through a branch + PR. A cut that linked straight to it would put a DEAD RELATIVE LINK inside the
        release tag -- caught by the lint gate's dead-link scan, and uncorrectable afterwards because the
        tag is immutable. Generating an empty skeleton at cut time was considered and rejected earlier for
        the mirror-image reason: that puts an empty document inside the tag instead.

        So the cut writes the DEVELOPER link, which always exists, and new-internal-note.ps1 calls this the
        moment the real note is created -- in the same PR that adds it, so the two never disagree.

        WHAT MOVED (Dave, August 5, 2026): the target document, not the mechanism. This used to rewrite the
        notes line inside CHANGELOG.md's release block, and that block is gone -- which would have left the
        internal note with no inbound link anywhere, since the history overview's rows point at the
        development notes. Left alone it would not have ERRORED either: this function returns its input
        unchanged when it finds nothing, so the step would simply have gone quiet, which is the failure
        shape this repo keeps paying for. The link therefore moved to the one place that still lists
        releases -- the overview's Version cell.

        WHY THE VERSION CELL RATHER THAN A FOURTH COLUMN. The row's reader is a colleague looking for what a
        release was worth, which is tier 1's audience and therefore the internal note's. A new column would
        have changed the table's shape, and that shape is matched by $script:OverviewTableHeaderRe, which
        three readers share -- including cut-release.ps1's row inserter and the new-major guardrail. One
        cell, only on new rows, and 72 existing rows keep pointing where they always did.

        Returns the content unchanged (no throw) when the row cannot be found: this runs after a successful
        release, and failing there would make a completed release look broken over a link. The caller
        reports what happened.
    #>
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$Version,
        # Both paths are relative to the overview file's own folder, exactly as the rows are written --
        # 'internal/3.x/3.6.0.md', not 'releases/internal/...'. $DevRelPath is what the cut wrote and is
        # accepted so the caller does not have to reconstruct it; it is only used to recognise the row.
        [Parameter(Mandatory)][string]$InternalRelPath,
        [string]$DevRelPath = ''
    )

    $nl = Get-DocumentNewline -Content $Content

    # The row's own shape: '| [3.6.0](<target>) | <date> | <type> | <title> |'. Anchored on the VERSION
    # inside the link text, so an overview holding every release ever cut cannot have an older row
    # rewritten by a call meant for the newest -- the same anchoring the changelog version needed.
    #
    # THE TARGET IS MATCHED AS 'anything', not as $DevRelPath, and that is what makes this idempotent
    # rather than once-only: a second call finds the row already pointing at the internal note and the
    # comparison below returns early. Matching only the dev path would make the second call a no-op by
    # accident (nothing matched) instead of by decision, and those two look identical from the outside.
    $v = [regex]::Escape($Version)
    $rowRx = '(?m)^(\|\s*)\[' + $v + '\]\(([^)]*)\)'
    $m = [regex]::Match($Content, $rowRx)
    if (-not $m.Success) { return $Content }
    if ($m.Groups[2].Value -eq $InternalRelPath) { return $Content }   # already pointed there

    $replacement = $m.Groups[1].Value + '[' + $Version + '](' + $InternalRelPath + ')'
    # Replace exactly the ONE match, by offset, rather than with a regex replace: a version string can
    # legitimately appear again further down (a row in an older major line, a sentence in the prose), and
    # a global replace would rewrite those too.
    $out = $Content.Substring(0, $m.Index) + $replacement + $Content.Substring($m.Index + $m.Length)
    return ($out.TrimEnd() + $nl)
}

# --- MOVED, NOT DELETED: Get-TouchedPlugins now lives in plugin-tree-lib.ps1 ------------------------
#
# It is in scope here regardless, because this file dot-sources that lib unconditionally at the top --
# so release-lib's own callers and its test suite reach it under exactly the same name as before.
#
# WHY IT MOVED. It went from matching a path shape to reading the plugin roots, which made it a function
# about the plugin tree rather than about a release. Keeping it here would have forced the fold script to
# dot-source THIS file to reach it -- and this file pulls in entry-scaffold-lib, thousands of lines,
# for a function that walks a list of strings. The fold runs immediately after a merge, directly on the
# trunk, so what it loads is worth being deliberate about. Moving one pure function down a layer costs
# nothing and lets the fold depend on a dependency-free lib instead.
#
# NO LINE COUNT IN THAT SENTENCE, DELIBERATELY (issue #1779). It read "three thousand lines" from the day
# this function moved, and entry-scaffold-lib measured 8,289 when anybody first checked -- 2.7x under, in
# the one sentence that carries the whole argument for the layer this function now sits in. A size written
# into prose drifts with every commit to the file it describes, and here it drifts in the direction that
# WEAKENS the argument: the stale figure invites a reader to reconsider a decision the real number settles
# harder. It also gets copied rather than re-measured -- check-connectors.ps1 declined to call into this
# lib and cited THIS docstring as its evidence (#1775), so one stale number became two. "thousands" cannot
# go stale upward, which is the only direction that file has ever moved.

function Get-EntryPlugins {
    <#
        Reads the optional 'Plugins: a, b' line from an entry block (derived by
        fold-changelog-entry.ps1 from the PR files). Returns an array of plugin names; empty = the
        entry does not touch plugin content (workshop-internal).
    #>
    param([Parameter(Mandatory)][string]$EntryText)
    $m = [regex]::Match($EntryText, '(?m)^Plugins:\s*(.+?)\s*$')
    if (-not $m.Success) { return @() }
    return @($m.Groups[1].Value -split '\s*,\s*' | Where-Object { $_ })
}

function Get-EntryRetracts {
    <#
        Reads the optional 'Retracts: a, b' line from an entry block -- the branch names of EARLIER
        entries in the same pending set that this one undoes (inbound #2230). Returns an array of branch
        names, in the order written; empty = the entry retracts nothing.

        SAME SHAPE AS Get-EntryPlugins, deliberately: a hand-written, comma-separated metadata line, read
        by its own line start rather than nested under a section, so an author writes it once beside the
        heading and every reader that cares finds it the same way. Unlike 'Plugins:' this line is the
        AUTHOR's to write, never the fold's -- there is nothing here for a merge to derive.

        THE CHANGELOG STAYS THE RECORD (the issue's own framing): this function only READS the line. What
        a caller does with what it reads -- withholding retracted work from the one hand-written document
        that narrates delivered work -- is Resolve-ReleaseRetractions' job, not this one's.
    #>
    param([Parameter(Mandatory)][string]$EntryText)
    $m = [regex]::Match($EntryText, '(?m)^Retracts:\s*(.+?)\s*$')
    if (-not $m.Success) { return @() }
    return @($m.Groups[1].Value -split '\s*,\s*' | ForEach-Object { $_.Trim('`', ' ') } | Where-Object { $_ })
}

# --- MOVED, NOT DELETED: Remove-EntryPluginsLine now lives in entry-scaffold-lib.ps1 ---------------
#
# In scope here regardless, because this file dot-sources that lib unconditionally at the top -- so
# Format-RankedEntries below (under -StripAdminSections) reaches it under exactly the same name.
#
# WHY IT MOVED (issue #1015, August 28, 2026). It gained a second caller that cannot depend on this
# file: fold-changelog-entry.ps1 writes the ONE authoritative 'Plugins:' line from the PR's touched
# files, and an entry that already carried a hand-written one ended up with two -- 22 of them shipped.
# The fold needs to strip before it appends, and its dot-source was narrowed to the small libs on
# August 9, 2026, so the helper went down to the lib that owns the entry format. Same move as
# Get-ReleaseChangeTypes and Set-EntryHeadingLevel, same reason.

# --- RENAMED, NOT DELETED: Convert-RootRelativeLinks is now Convert-EntryRelativeLinks -------------
#
# The old name asserted the base -- repo-root-relative -- and that assertion is exactly what stopped
# being true, so keeping it would have left the one line a reader checks first saying the wrong thing.
# Nothing outside this file called it by either name: it is a lib function behind Build-ReleaseNotes
# and Build-ReleaseNoteDraft, and a consumer runs the SCRIPTS rather than the lib.

function Convert-EntryRelativeLinks {
    <#
        Rewrites the relative markdown links in an entry so they still resolve from a document that sits
        at a DIFFERENT depth than the changelog the entry's text lives in. $Prefix is the path from that
        document's own directory to the CHANGELOG's directory -- see Get-EntryLinkPrefix, which derives
        it. External (http/mailto), anchor (#) and absolute (/) links are left alone: none of them is
        resolved against a directory, so none of them can be broken by the text moving. So is anything
        inside a code fence, an inline code span or an html comment: that is an illustration of a link
        rather than one, and it is the same set open-pr's link gate excludes (inbound #1052).

        THE BASE IS THE CHANGELOG'S DIRECTORY, NOT THE REPO ROOT (inbound #1047, August 28, 2026), and
        that is not a preference -- it is what the fold does. The fold copies an entry VERBATIM into
        CHANGELOG.md, so whatever directory that file sits in IS the base every relative link in an entry
        is written against. open-pr's link gate has judged them from exactly there since #967
        (Get-EntryLinkFindings -DestDirRel); this function was still prefixing as though the answer were
        the repo root, which is the same answer only while the changelog sits AT the root. It stopped
        sitting there when #914 made the changelog isolate-by-default, and in this repo when CHANGELOG.md
        moved into contributing-davekjohn/ on August 27, 2026.

        The two hops therefore disagreed, and no relative link satisfied both: the form the gate demanded
        (`CONTRIBUTING.md`) was rebased one directory too far and landed in the release record pointing at
        a root CONTRIBUTING.md this repo does not have, while the form that survived the cut was refused
        before the PR was ever opened. The measured workaround was to write no relative links at all.

        AND '../' IS REWRITTEN NOW, WHICH IS THE HALF THE REPORT DID NOT SEE. It used to be exempt, on the
        reasoning that a link already climbing out of a directory was one the author had aimed by hand.
        With the changelog inside the workflow folder, '../' is no longer the exception but the ORDINARY
        form for every target outside that folder -- and it is the form the gate itself hands the author,
        because Get-PathRelativeToDirectory emits it. Leaving it alone meant the cut silently skipped
        precisely the links the gate had just dictated. Prefixing is enough to move one: '../../../' +
        '../scripts/x' resolves through its own '..' segments to the same file, in every markdown renderer
        and on GitHub.

        Exempting it cost this repo nothing to keep only because nothing in the entry file used it while
        the changelog was at the root -- there, a '../' link points outside the repo and open-pr refuses
        it. So the exemption never protected a working link; it protected a broken one.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$EntryText,
        # Empty is a real answer: a repo whose notes sit in the changelog's OWN directory needs no
        # rewriting at all, and Get-EntryLinkPrefix returns '' for exactly that case.
        [Parameter(Mandatory)][AllowEmptyString()][string]$Prefix
    )
    if (-not $Prefix) { return $EntryText }
    # CODE AND COMMENTS ARE LEFT ALONE (inbound #1052, August 28, 2026). A markdown link written inside a
    # fence, an inline code span or an html comment is an ILLUSTRATION -- a sample entry, a quoted path,
    # a line a gate prints -- and open-pr's link gate has excluded exactly that set since it existed. This
    # function did not, so the two halves of one rule disagreed: a link the gate never judged was rewritten
    # anyway, and the result is a silently mangled illustration inside a tagged, immutable release document.
    # #1047 widened the gap by one class when it stopped exempting '../', which is the ordinary shape for a
    # quoted example. Get-EntryCodeSpans is now the single answer both halves read.
    $codeSpans = @(Get-EntryCodeSpans -EntryText $EntryText)
    # THE MATCH IS THE WHOLE LINK, LABEL INCLUDED, AND THAT IS THE HALF THAT MAKES THE SPANS USABLE. This
    # matched from the ']' while Get-EntryLinkTargets matches from the '[', and the offset test reads the
    # START of a match -- so a link whose LABEL sat inside a code span but whose '](target)' did not was
    # excluded by the gate and rewritten here, which is the very disagreement this change exists to end.
    # Matching the gate's shape is what puts both halves on the same offset; found in review, before it
    # shipped. The prefix is then INSERTED at the target group's own index, so the label is never rebuilt.
    $sb = New-Object System.Text.StringBuilder
    $cursor = 0
    foreach ($m in [regex]::Matches($EntryText, '\[(?:[^\]]*)\]\((?!https?:|mailto:|#|/)([^)]+)\)')) {
        if (Test-EntryOffsetInCodeSpans -Offset $m.Index -Spans $codeSpans) { continue }
        $at = $m.Groups[1].Index
        [void]$sb.Append($EntryText.Substring($cursor, $at - $cursor))
        [void]$sb.Append($Prefix)
        $cursor = $at
    }
    [void]$sb.Append($EntryText.Substring($cursor))
    return $sb.ToString()
}

function Get-EntryLinkPrefix {
    <#
        Pure: the prefix that moves an entry's relative links from the CHANGELOG's directory to the
        directory a generated release document sits in -- '../../../' for a note at
        dkj-policy/releases/changelog/4.x/ whose changelog is dkj-policy/CHANGELOG.md.
        Both arguments are repo-relative paths to FILES; either separator is accepted. Returns '' where
        the two documents share a directory, which is Convert-EntryRelativeLinks' no-op.

        IT EXISTS SO THE TWO CALL SITES CANNOT DRIFT (inbound #1047). cut-release.ps1 derives this twice --
        once for the tier-0 notes, once for the hand-written draft -- and both used to count the note's own
        segments back to the repo root, which is the derivation the report measured as wrong. One owner, so
        a repo that repoints Get-ChangelogPath gets both documents right or neither.

        A CHANGELOG AT THE REPO ROOT PRODUCES THE OLD ANSWER, BYTE FOR BYTE: the destination directory is
        then '' and the prefix is one '../' per segment of the note's own directory, which is what
        `('../' * $notesDepth)` computed. So nothing changes for a repo that never moved its changelog.
    #>
    param(
        # The generated document, repo-relative -- e.g. 'dkj-policy/releases/changelog/4.x/4.23.0.md'.
        [Parameter(Mandatory)][string]$NoteRelPath,
        # The changelog the entry text is copied out of, repo-relative -- what Get-ChangelogPath answers.
        [Parameter(Mandatory)][string]$ChangelogRelPath
    )
    $noteDir = ((Split-Path $NoteRelPath -Parent) -replace '\\', '/').Trim('/')
    $destDir = ((Split-Path $ChangelogRelPath -Parent) -replace '\\', '/').Trim('/')
    $rel = Get-RelativeLinkPath -FromDir $noteDir -To $destDir
    if (-not $rel) { return '' }
    return "$rel/"
}

# --- MOVED, NOT DELETED: Get-ReleaseChangeTypes now lives in entry-scaffold-lib.ps1 ----------------
#
# Convert-EntryHeadingToTitle below still calls it by exactly that name, and it is in scope because this
# file dot-sources entry-scaffold-lib unconditionally, at the top.
#
# IT MOVED FOR THE SAME REASON THE FENCE READER DID, and the same way: Resolve-EntryType in that lib needs
# it to RECOGNISE a type field in a pre-format heading, and the dependency can only run downward. Leaving
# it here meant that function had to make do with Get-BranchTypes alone -- which is repo-owned and
# therefore absent from the plugin mirror, so in a consumer the known-type list was EMPTY and every bullet
# new-internal-note.ps1 took from a historical heading silently lost its type.
#
# Recognition and validation are different questions and now use different lists: this one (the repo's
# table, or the canonical four) recognises, while only the repo's own table may accuse an author of a
# wrong type. See Resolve-EntryType's header.

# Set-EntryHeadingLevel MOVED DOWN into entry-scaffold-lib.ps1 (inbound #953, August 27, 2026), which this
# file dot-sources -- so every caller here reaches it unchanged. It went where the entry FORMAT is defined
# because the FOLD needed it and cannot depend on this lib: fold-changelog-entry.ps1's dot-source was
# deliberately narrowed to the small libs on August 9, 2026, and being unable to call the re-leveller is
# what left it promoting a legacy entry's first line by hand. Same move as Get-FencedLineFlags, same reason:
# one owner, reachable from the lower lib.

function Format-RankedEntries {
    <#
        Pure: renders entry blocks as ONE FLAT LIST, separated by '---', each re-levelled so its heading
        sits at $EntryLevel. Output is pure LF; $Entries may arrive CRLF (from the root CHANGELOG) and are
        normalized here.

        IT REPLACES Format-CategorizedEntries, AND THE DELETION IS THE POINT (Dave, August 5, 2026). That
        function grouped entries under category headings -- 'Features', 'Fixes', 'Documentation',
        'Maintenance', 'Other' -- derived from the branch type it parsed out of each entry's heading. Three
        things were wrong with that, and they compounded:

          * the branch prefix does not predict what a change is worth, which this repo measured: the single
            most consequential change for a consumer at v3.2.0 arrived on a chore/ branch;
          * so the grouping put a document's most important change third, under whichever label its prefix
            produced -- and the ranking added in #467 could only reorder the categories, not escape them;
          * and the type was INFERRED from a heading field, which is exactly the positional parse that
            silently broke when the merge date left the heading.

        The type is now STATED inside each entry, under its own section, so nothing is lost by not grouping
        on it -- and the reader meets the changes in the order they matter instead of in alphabetical-ish
        category order. Get-ReleaseCategories' label map and the Get-ReleaseCategoryTitles seam retire.

        $RankByTier: which tier's row orders the output. 0 -- the default -- means keep the arrival order,
        which for entries read out of CHANGELOG.md is the ranked order the FOLD already left there. A
        document is ordered by what ITS OWN reader gets out of each change, and the reader is named by the
        tier, so this is a tier number rather than an audience word: the internal note ranks on tier 1, the
        consumer document on tier 2.

        $BareTitles reduces each entry heading to its title (Convert-EntryHeadingToTitle) -- for the
        consumer document, whose reader has no branch and no PR number.

        $StripSignificance removes the impact table AND the older 'Tier: N' line. For the documents that
        travel OUTWARD only; the record keeps both. See Remove-EntryImpactTable for why the two differ.

        $StripAdminSections removes the four branch-administration sections and the 'Plugins:' line. It is
        the same objection as $BareTitles -- this reader has no branch and no PR number -- applied to where
        that metadata actually lives since August 6, 2026. Deliberately a SECOND switch rather than folded
        into $BareTitles: that one reduces a heading and is safe on any document, while this deletes named
        sections and must never reach the record.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Entries,
        [int]$EntryLevel = 2,
        [switch]$BareTitles,
        [int]$RankByTier = 0,
        [switch]$StripSignificance,
        [switch]$StripAdminSections
    )
    $items = @()
    $index = -1
    foreach ($e in $Entries) {
        $index++
        # THE SCORE IS READ BEFORE ANYTHING IS STRIPPED, because the strip below deletes the table it lives
        # in. That is what lets -StripSignificance and -RankByTier compose -- the consumer document needs both, and
        # in the other order they would rank an unscored pile. The same trap the retired renderer was
        # measured on with -BareTitles and the type.
        $rank = 0
        if ($RankByTier -gt 0) {
            $rank = Get-EntryImpactScore -Impact (Resolve-EntryImpact -EntryText $e) -Tier $RankByTier
        }
        $text = if ($BareTitles) { Convert-EntryHeadingToTitle -EntryText $e } else { $e }
        if ($StripSignificance) {
            # BOTH declarations, and the second is new here. While the changelog had tier sections the fold
            # consumed the 'Tier: N' line, so it could never reach a rendered document; the fold now carries
            # it, which puts a self-assigned tier on the path to a consumer's plugin cache unless it is
            # dropped here -- the same class of thing as a self-assigned score.
            $text = Remove-EntrySignificanceDeclaration -EntryText $text
            $text = Remove-EntryTierLine -EntryText $text
        }
        # STRICTLY AFTER Convert-EntryHeadingToTitle ABOVE, and that order is the whole trick: the heading
        # rewrite READS the 'Branch title' section this strip deletes. Reversed, the consumer document would
        # list every change as '`fix/x` changelog' -- the same read-before-strip trap -RankByTier and
        # -StripSignificance already document one case of, met a third time.
        if ($StripAdminSections) {
            $text = Remove-EntryAdminSections -EntryText $text
            # ITS FIRST PRODUCTION CALLER SINCE AUGUST 8, 2026, when the per-plugin CHANGELOG it was written
            # for was retired and the function was deliberately kept. Its own header names this reader: the
            # line is repo administration that drives the cut's plugin selection, and the record shows it.
            $text = Remove-EntryPluginsLine -EntryText $text
        }
        $items += [pscustomobject]@{
            Text  = (Set-EntryHeadingLevel -EntryText $text.Trim() -EntryLevel $EntryLevel)
            Rank  = $rank
            Order = $index
        }
    }

    if ($RankByTier -gt 0) {
        # SORTED ON (score desc, arrival asc) -- the second key is not decoration. PowerShell's Sort-Object
        # is NOT a stable sort, so on a five-point scale, where ties are the common case, sorting on the
        # score alone would let equal-scoring entries come out in a different order from one run to the
        # next. That would make a regenerated release document differ from the one already published, with
        # nothing having changed. The arrival index makes the result total.
        $items = @($items | Sort-Object -Property @{Expression = 'Rank'; Descending = $true}, @{Expression = 'Order'; Descending = $false})
    }

    return (@($items | ForEach-Object { $_.Text }) -join "`n`n---`n`n")
}

# RETIRED, AUGUST 8, 2026: Build-PluginChangelogSection, Build-PluginChangelogIntro,
# Add-PluginChangelogSection and Build-PluginReleaseCard -- the four builders of the per-plugin
# CHANGELOG.md and RELEASE.md card.
#
# They existed to give a consumer a history and a version card INSIDE the plugin cache, on the
# reasoning that the cache is all a consumer has. Measured before removing them: the marketplace
# source is a git clone of the WHOLE repo, so every consumer already holds the root CHANGELOG.md
# and the full releases/ tree at ~/.claude/plugins/marketplaces/<marketplace>/. The ten files these
# functions wrote came to 11,684 lines of second copy -- and a copy that could disagree with the
# original, which is precisely what lint checks 9 and 17 were built to police. Both checks are gone
# with the functions: there is nothing left to hold against anything.
#
# One repository, one product, one changelog. Decision by Dave, August 8, 2026.
#
# Convert-EntryLinksForPluginChangelog went with them (its only callers were these), while
# Format-RankedEntries did NOT -- the release notes and the consumer document still uses it.

# The two patterns that define where a release row lands, in ONE place because three readers depend on
# them agreeing: Get-OverviewTargetMajor and Get-OverviewSectionHeading below, and the inserter in
# cut-release.ps1. A hand-copied second instance of either is how this repo's accumulation bugs start.
$script:OverviewTableHeaderRe = [regex]"(?m)^\| Version \| Date \| Type \| Title \|\r?\n\|[-| ]+\|\r?\n"
$script:OverviewMajorHeadingRe = '(?m)^(#{3,4})\s+(\d+)\.x\s*$'

# --- THE RELEASE LIST'S HEAD IS FIXED, AND IT CARRIES NO PROSE (issue #2489) ----------------------
#
# The same drift #2486 removed from CHANGELOG.md, one file over. No script wrote the text above the first
# '<n>.x' section: adopt-workflow-folder.ps1 told each consumer to create the file by hand and the cut only
# inserted rows, so every repo's head was its own. Measured in the source repo at 2790c757: about 85 lines
# of prose, one sentence of it already false (it described a release block the cut stopped writing on
# August 5, 2026) and one link with an empty target. The repair is that there is no prose there at all,
# and the cut -- the one writer every repo's list has -- re-applies the head where it inserts the row.
#
# WHAT IT KEEPS. Everything from the first '<n>.x' heading down: the sections, their tables, and anything a
# repo put BETWEEN sections, which is below the head and so not this function's business. The heading level
# is kept too -- '###' and '####' are both valid (Get-OverviewTargetMajor explains why), and rewriting one to
# the other would be a layout decision this function has no business making.
#
# AND WHAT IT LEAVES ALONE. A list with no '<n>.x' heading is returned unchanged. The guardrail is off for
# that file anyway, and the part below the head cannot be located, so the head cannot be either -- replacing
# the whole document, as the changelog's version does, would delete rows here, where the changelog's has
# nothing below its head to lose.
#
# The head's own lines are Get-ReleaseHistoryHeadLines in entry-scaffold-lib.ps1, beside the changelog's,
# because adopt-workflow-folder.ps1 prints them and loads that lib rather than this one.
function Set-ReleaseHistoryCanonicalHead {
    <#
        Pure: the release list with everything above its first '<n>.x' section heading replaced by the fixed
        head. Content in, content out; nothing is written and nothing is thrown.

        The boundary is the first heading OverviewMajorHeadingRe matches -- the pattern the two readers use,
        so the head ends exactly where their view of the list begins. FENCE-AWARE, because the prose it
        replaces may quote a '<n>.x' heading inside a fence to document the format, and the boundary must
        not land there. Unchanged where no such heading exists (see the header above).
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Content)

    $nl = Get-DocumentNewline -Content $Content
    $lines = @($Content -split "`r?`n")
    $fenced = Get-FencedLineFlags -Lines $lines
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($fenced[$i]) { continue }
        if ($lines[$i] -match $script:OverviewMajorHeadingRe) {
            return ((@(Get-ReleaseHistoryHeadLines) + @($lines[$i..($lines.Count - 1)])) -join $nl)
        }
    }
    return $Content
}

function Get-OverviewSectionHeading {
    <# The literal major-section heading a new row would land under ('#### 3.x'), or $null when the
       overview carries no table. Pure string in, string out.

       Exists so a caller can QUOTE that heading back at the reader -- cut-release.ps1's new-major refusal
       shows the section to add, and it must be shown at the level the document actually uses. Before this,
       that message hardcoded '###' twice, which was already wrong for a page nesting its list one deeper.
       Same match as Get-OverviewTargetMajor, from the same shared pattern, so the level and the number
       can never disagree. #>
    param([Parameter(Mandatory)][string]$ReadmeContent)
    $hm = $script:OverviewTableHeaderRe.Match($ReadmeContent)
    if (-not $hm.Success) { return $null }
    $sections = [regex]::Matches($ReadmeContent.Substring(0, $hm.Index), $script:OverviewMajorHeadingRe)
    if ($sections.Count -eq 0) { return $null }
    $last = $sections[$sections.Count - 1]
    return ($last.Groups[1].Value + ' ' + $last.Groups[2].Value + '.x')
}

function Get-OverviewTargetMajor {
    <# Which '<n>.x' section of the release history a new row would land in, or $null when the
       overview carries no table at all. Pure string in, string out.

       WHY THIS EXISTS. The row inserter finds the FIRST '| Version | Date | Type | Title |' header and
       inserts directly after it -- correct for every minor and patch, because the current major's table
       sits at the top. A NEW MAJOR has no table yet, so its row lands under the PREVIOUS major's
       heading: a v3.0.0 row filed under '### 2.x'. Not a crash -- a quietly wrong overview, in the one
       document whose whole job is to say which release is which.

       Never caught before because it cannot have been: the grouping-by-major was introduced in v2.0.1,
       one release AFTER the only major this repo ever cut. So a major has never met this structure.

       The answer is the LAST section heading before the first table header, not simply the first
       heading in the file: that is precisely the section the inserter will write into, and deriving it
       any other way would be a second, drifting definition of the same thing.

       BOTH '###' AND '####' ARE ACCEPTED, and that tolerance is the point rather than laxness. The
       heading level is a function of how deeply the release list is nested in its page, which is a
       LAYOUT decision the repo owns: a flat page puts the list at '###', while a page that files it
       under a repo-specific section heading nests it one deeper. This repo moved from the first shape to
       the second on August 4, 2026. Pinning one level would mean a purely cosmetic edit silently
       DISABLES the guardrail -- this function would find nothing, return $null, and cut-release.ps1's
       check is written as "if a target was found and it differs", so no target means no refusal. A
       guardrail that switches itself off when a heading gains a '#' is worse than none, because the
       document still reads as though it is protected. #>
    param([Parameter(Mandatory)][string]$ReadmeContent)
    $hm = $script:OverviewTableHeaderRe.Match($ReadmeContent)
    if (-not $hm.Success) { return $null }
    $before = $ReadmeContent.Substring(0, $hm.Index)
    $sections = [regex]::Matches($before, $script:OverviewMajorHeadingRe)
    if ($sections.Count -eq 0) { return $null }
    # Group 2, not 1: group 1 is the '#' run (see Get-OverviewSectionHeading, which needs it).
    return $sections[$sections.Count - 1].Groups[2].Value
}

function Get-OverviewLatestVersion {
    <# The version this repo has RECORDED as its most recent release: the first data row of the first
       table in the release overview that carries one. $null where the overview has no table, or no
       table's first row names a version. Pure string in, string out.

       WHY THIS EXISTS. cut-release.ps1 derives the baseline it bumps FROM somewhere else entirely --
       the lockstep plugin manifests, or failing those the highest 'v*' git tag -- and neither of those
       is the document that says which release is which. Where one of them disagrees with this table,
       everything downstream of the baseline is wrong at once and in silence: the '**Type:**' line in the
       generated notes, the Type cell of this very table, the question the tier gate asks
       (Test-ReleaseBumpEarned judges a bump type that is not the one being cut), and whether the
       hand-written consumer document is drafted at all. Reported from a consumer as inbound #802, where
       a deliberately lagging tag line -- tags left alone while the documents were renumbered -- turned a
       patch into a 'Minor' in four places and nothing warned.

       ONE STRAY TAG IS ENOUGH, which is why this is not a check for an exotic repo policy: '--sort=-v:refname'
       takes the highest 'v*' tag in the repo, so a single mistyped 'v99.0.0' makes every later release
       read as a Major.

       THE FIRST ROW OF A TABLE, for the same reason Get-OverviewTargetMajor reads the last heading
       before one: that is where the row inserter writes, so this is the row the next cut lands on top
       of. Reading every row and sorting would be a second, drifting definition of 'newest'.

       IT WALKS ON TO THE NEXT TABLE WHERE THE FIRST IS EMPTY, and that case is not hypothetical -- it is
       exactly the state a freshly opened major section is in, which is the highest-stakes cut there is.
       Stopping at the first table would switch this check off precisely there.

       BOTH ROW SHAPES ARE ACCEPTED -- '| [4.17.0](path) |' and a bare '| 4.17.0 |', backticked or not --
       because the link target is a repo-owned layout decision (this repo's own rows point at three
       different roots across their history) while the version is the fact being read. #>
    param([Parameter(Mandatory)][string]$ReadmeContent)
    foreach ($hm in $script:OverviewTableHeaderRe.Matches($ReadmeContent)) {
        $after = $ReadmeContent.Substring($hm.Index + $hm.Length)
        $firstRow = ($after -split "`r?`n", 2)[0]
        # The first CELL, then the version inside it: the cell may be a link, a backticked literal or
        # bare, and matching the version anywhere in the row would happily read the Title column of a
        # row whose version cell is malformed.
        if ($firstRow -match '^\|([^|]*)\|') {
            $cell = $Matches[1]
            if ($cell -match '(\d+\.\d+\.\d+)') { return $Matches[1] }
        }
    }
    return $null
}

# The audience each tier is named after in a generated document. ONE MAP, so the release notes and any
# later reader of a tier number agree about what it means.
#
# HARDCODED ENGLISH, deliberately, and not a new seam. This file already writes English prose into the
# documents it generates -- the per-plugin CHANGELOG intro, the "no changes to this plugin" line, the
# card's footer labels, the '**Date:**' label -- and none of those is configurable. Adding a knob for
# these three words while five other strings stay fixed would be arbitrary; translating this file's
# generated prose is one question with one answer, and the day a consumer needs it, it is that whole
# question that gets a seam rather than the three words that happened to be added last.
$script:ReleaseTierAudience = @{
    2 = 'consumers'
    1 = 'colleagues'
    0 = 'developers'
}

function Get-ReleaseTierHeading {
    <# The audience wording for a tier, e.g. 'Tier 2 - consumers'. A tier with no audience word in the map
       degrades to 'Tier <n>' rather than to a blank -- an unfamiliar number is readable, a dangling
       separator is not.

       NOTHING RENDERS IT SINCE #881 (August 25, 2026): it was the development notes' grouping heading, and
       those notes now render at CHANGELOG.md's own levels. It stays for the reason the Heading field above
       states -- the wording every note ever cut carries, in one place. #>
    param([Parameter(Mandatory)][int]$Tier)
    $audience = $script:ReleaseTierAudience[$Tier]
    if ($audience) { return "Tier $Tier - $audience" }
    return "Tier $Tier"
}

function Get-RelativeLinkPath {
    <#
        Pure: the relative link from one repo-relative directory to a repo-relative file, both with
        forward slashes -- 'changelog/4.x/4.9.0.md' from 'dkj-policy/releases' to
        'dkj-policy/releases/changelog/4.x/4.9.0.md', and the same file reached from 'releases'
        as '../dkj-policy/releases/changelog/4.x/4.9.0.md' -- which is the shape this repo's own
        overview rows have carried since #914.

        WHY IT EXISTS (August 14, 2026). cut-release.ps1 built the history-table row with
        `-replace '^releases/'`, which is correct only while the history README sits directly in
        releases/ -- its own comment said a repo answering the seam with a root outside that directory
        "would need a '../' here, which no repo has yet asked for". The workflow folder was that ask:
        between August 14 and 19, 2026 this repo's own history sat at contributing-davekjohn/releases/README.md
        while the generated development notes stayed at the repo root. Same class as the v4.6.0 dead-row
        bug, caught before shipping this time rather than after.

        The source's history moved back to releases/README.md on August 19, and the handling stayed --
        deliberately, because a correction kept only while it is being used is a correction that breaks the
        next time somebody needs it. It never actually went unused: the note-carrying rows had pointed at
        contributing-davekjohn/releases/audience/ since August 14, so they were '../' rows all along. #914
        moved the remaining two note trees in beside it, which makes every row in the overview a '../' row --
        all 102 of them, where before it was the 30 that pointed at a hand-written note.

        [System.IO.Path]::GetRelativePath does not exist on the .NET Framework Windows PowerShell 5.1
        runs on -- the same reason cut-release's collision guard keeps repo-relative strings.
    #>
    param(
        [AllowEmptyString()][string]$FromDir = '',
        # EMPTY IS A REAL DESTINATION -- the repo root (inbound #1047). $FromDir has always allowed it for
        # the mirror-image reason, and Get-EntryLinkPrefix asks this question of a repo whose changelog
        # sits AT the root, where the answer is one '..' per segment of $FromDir and nothing else.
        [Parameter(Mandatory)][AllowEmptyString()][string]$To
    )
    # NOT $from/$to: PowerShell variable names are case-INsensitive, so '$to = @(...)' would assign to
    # the [string]-typed parameter $To itself -- and the type constraint coerces the segment array back
    # into one space-joined string, whose [0] is then a single character. Measured on this function's
    # first test run.
    $fromParts = @($FromDir -split '/' | Where-Object { $_ })
    $toParts   = @($To -split '/' | Where-Object { $_ })
    $i = 0
    while ($i -lt $fromParts.Count -and $i -lt $toParts.Count -and $fromParts[$i] -ceq $toParts[$i]) { $i++ }
    $parts = @()
    for ($u = $i; $u -lt $fromParts.Count; $u++) { $parts += '..' }
    if ($i -lt $toParts.Count) { $parts += @($toParts[$i..($toParts.Count - 1)]) }
    return ($parts -join '/')
}

function Format-ReleaseVersionHeading {
    <#
        Pure: the heading a release note's entries sit under -- 'Version 4.29.0 (Sep 04, 2026)' from
        '4.29.0' and '2026-09-04'.

        WHY THIS HEADING EXISTS AT ALL (Dave, issue #1369). An entry is written at H3 and has been since
        August 26, 2026; this document promoted it to H2, so the record a reader arrives at contradicted
        the changelog the entry was copied out of. Putting the entries back at their written level leaves
        an H1 with H3 children unless something occupies H2 -- and what belongs there is the release the
        entries landed in. That is the shape CHANGELOG.md itself has, which is the comparison the issue was
        filed on: a generic H1, a container H2, the entry at H3.

        THE WORDING IS DAVE'S AND HOLDS FOR EVERY NOTE -- 'Version 4.29.0 (Sep 04, 2026)'. The date is
        parsed EXACTLY and with the invariant culture, so a heading in a published record cannot change
        with the locale of the machine that cut it; one that does not parse is passed through untouched
        rather than guessed at, since a caller may hand a form this has never seen. The same two rules
        Format-ReleaseDate applies in the page builder, for the same reason -- and that function is not
        reused because it renders a different shape ('14 Aug 2026') and lives in a script this lib must
        not depend on.

        A CALL WITH NO DATE gets the version alone rather than an empty bracket.
    #>
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Date
    )
    $raw = $Date.Trim()
    if (-not $raw) { return "Version $Version" }
    $parsed = [datetime]::MinValue
    $ok = [datetime]::TryParseExact($raw, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::None, [ref]$parsed)
    $shown = if ($ok) { $parsed.ToString('MMM dd, yyyy', [System.Globalization.CultureInfo]::InvariantCulture) } else { $raw }
    return "Version $Version ($shown)"
}

function Build-ReleaseNotes {
    <#
        Builds the full changelog notes -- the tier-0 <changelog root>/<X>.x/<X.Y.Z>.md file, which is
        dkj-policy/releases/changelog/ in this repo since #914 -- from the
        entry blocks. Pure string out -- DELIBERATELY hard LF, because this is a NEW, standalone file
        with no existing newline style of its own, unlike the root CHANGELOG.md which detects and
        keeps its CRLF style via $nl. The entries come from that CRLF root CHANGELOG -- so here they
        are explicitly normalized to LF (#103, Victor #5), alongside the link rewriting below.

        TWO SHAPES, ONE FUNCTION (the tier model, August 5, 2026) -- AND SINCE #881 THEY DIFFER ONLY IN
        ORDER, NOT IN LEVEL. Both render entries at Get-EntryHeadingLevel and their sections one below it,
        which is exactly what CHANGELOG.md writes, so an entry copied out of this document pastes at the
        level it was written at:

          -TierGroups  the pending entries grouped by tier. Renders each tier's entries IN THE ORDER GIVEN,
                       ranked within the tier, as one continuous flat list -- no grouping heading. A tier
                       with no entries contributes nothing.
          -Entries     one flat list in arrival order. For a repo whose entries declare no tier at all:
                       every one reads as tier 0, so there is no order for a tier to impose.

        Give one or the other; -TierGroups wins if both arrive.

        THE GROUPING HEADING IS GONE ON PURPOSE (Dave, #881, August 25, 2026). It was the last thing in the
        pipeline that demoted this document a level relative to its own source, and the reason it was
        accepted -- that it marked the boundary between what reached a consumer and what stayed internal --
        is a claim about ATTRIBUTION, which the repo's own documentation is the right place for. The record
        stays a record: what changed, at the levels it was written at.

        AND THE LEVEL IS NOW ASKED FOR RATHER THAN SPELLED OUT (Dave, issue #1369, September 4, 2026), which
        is what #881 was always about and what a literal could not keep. #881 set these entries to '##'
        because that was the level CHANGELOG.md wrote them at; three weeks later, on August 26, 2026,
        CHANGELOG.md gained its '## [Unreleased]' heading and every entry moved to H3 -- and this renderer,
        holding a number instead of the question, went on promoting them. Nothing errored and no gate fired:
        the document simply started contradicting its own source again, in exactly the way #881 had repaired,
        with the comment above it and its own test both still asserting the old claim was true. Reading
        Get-EntryHeadingLevel means the next move of that pair carries this document with it.

        THE VERSION HEADING IS THE OTHER HALF (see Format-ReleaseVersionHeading). Entries at H3 under an H1
        would skip a level, so the release they landed in occupies H2 -- and the document's own H1 becomes
        the constant it always effectively was, since the version is now stated by the heading that owns it
        rather than twice in four lines. The metadata pair below it STAYS: new-internal-note.ps1 reads
        '**Date:**' and '**Type:**' out of this document to build the internal note, so dropping them would
        degrade a consumer's two-document flow to '(fill in)' and a warning.
    #>
    param(
        [AllowEmptyCollection()][string[]]$Entries = @(),
        # Array of objects with Tier and Entries -- what Get-PullRequestEntriesByTier returns.
        $TierGroups = $null,
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$Date,
        [Parameter(Mandatory)][string]$Type,
        [string]$Title = '',
        # An AUTHORED block placed between the one-line title and the generated entries -- for a
        # milestone release whose point is the arc across many releases rather than the diff since the
        # last one. $Title is one sentence and the entries are per-PR; neither can carry "here is what
        # changed between 2.2.0 and 2.16.0", and hand-editing a generated file is not a repeatable
        # release. Empty by default, so an ordinary release is byte-identical to before.
        [string]$Summary = '',
        # Prefix that moves an entry body's relative links from the CHANGELOG's directory -- the base they
        # are written against, because the fold copies them there verbatim -- to the notes file's own.
        # THE DEFAULT IS THE SHALLOWEST SHAPE ANY REPO HAS -- a root directly under releases/, three
        # folders deep, with the changelog at the repo root. cut-release.ps1 does not rely on it: it asks
        # Get-EntryLinkPrefix, because a notes root one level deeper (this repo since #914) needs a fourth
        # '../' and a changelog that is NOT at the root needs one fewer, and nothing would error either way.
        [string]$LinkPrefix = '../../../'
    )
    # Entries are written relative to the CHANGELOG's own directory; rewrite them so they resolve from the
    # notes file, at whatever offset the caller says it sits (see the LinkPrefix note above). External
    # (http/mailto), anchor (#) and absolute (/) links are left alone; '../' links are NOT, since inbound
    # #1047 -- they are the ordinary form for a target outside an isolated changelog's folder, and the one
    # open-pr's gate hands the author. Format-RankedEntries then re-levels the entries and normalizes to
    # LF, so the CRLF of the source CHANGELOG does not cross the pure-LF output.
    if ($TierGroups) {
        $sections = @()
        foreach ($group in @($TierGroups)) {
            $groupEntries = @($group.Entries | Where-Object { $_ -and $_.Trim() })
            if ($groupEntries.Count -eq 0) { continue }
            $linked = @($groupEntries | ForEach-Object { Convert-EntryRelativeLinks -EntryText $_ -Prefix $LinkPrefix })
            # NO TIER HEADING, AND THE ENTRIES SIT AT '##' -- EXACTLY CHANGELOG.md'S LEVELS (Dave, #881,
            # August 25, 2026). This group used to render as '## Tier 2 - consumers' with its entries one
            # level under it, which put every heading in this document one level DEEPER than the changelog
            # the entries were copied out of: 35 entries at '###' where the source had written them at
            # '##'. The changelog is what a release note is copied FROM, so the copy has to paste at the
            # level it was written at. The tier still decides the ORDER -- the groups arrive highest-first
            # and each is ranked below -- it simply no longer prints a heading to say so.
            #
            # RANKED FROM TIER 1 UP, AND DELIBERATELY NOT AT TIER 0 (issue #467). Tier 0 is the RECORD --
            # complete and chronological, which is what a record is for -- and its entries are never asked
            # for a score in the first place. Unranked here means DOCUMENT ORDER, which is the order the
            # fold left CHANGELOG.md in, so tier 0 inherits a defined order rather than losing one.
            #
            # THE SCORES ARE NOT STRIPPED HERE, and this is the one document where they survive. The cut
            # EMPTIES the changelog, so these notes are the last place holding the reason behind each
            # ranking; deleting it would leave every order asserted with its justification thrown away. The
            # document that travels outward strips it -- see Build-ReleaseNoteDraft. What does NOT survive the
            # heading's removal is the tier NUMBER: an entry states its scores and never names its tier, so
            # that heading was carrying the attribution alone. Dropping it is the deliberate half of #881 --
            # this document is the record of WHAT CHANGED, and where each change reached is answered by the
            # repo's own documentation rather than by a wrapper around the record.
            $rankByTier = if ([int]$group.Tier -ge 1) { [int]$group.Tier } else { 0 }
            $sections += (Format-RankedEntries -Entries $linked -EntryLevel (Get-EntryHeadingLevel) -RankByTier $rankByTier)
        }
        # THE SAME SEPARATOR BETWEEN GROUPS AS WITHIN ONE. Format-RankedEntries joins its own entries with
        # '---'; with the heading gone, joining the groups on a bare blank line would make the tier seam
        # visible by the ABSENCE of a rule -- the single boundary in the document where two entries are not
        # divided, which is a heading in all but name. Every entry boundary now reads identically.
        $body = ($sections -join "`n`n---`n`n")
    } else {
        $linked = @($Entries | ForEach-Object { Convert-EntryRelativeLinks -EntryText $_ -Prefix $LinkPrefix })
        $body = Format-RankedEntries -Entries $linked -EntryLevel (Get-EntryHeadingLevel)
    }

    $titleLine = if ($Title) { "$Title`n`n" } else { '' }
    # Normalized to LF like everything else that enters this file, and separated from the generated
    # entries by a horizontal rule -- so a reader can see where the authored part stops and the
    # per-PR record begins. Without that boundary a milestone summary reads as if it were generated,
    # which is the one thing it must not be mistaken for.
    $summaryBlock = if ($Summary) {
        (($Summary -replace "`r`n", "`n").TrimEnd() + "`n`n---`n`n")
    } else { '' }
    # THE H1 IS A CONSTANT AND THE VERSION SITS IN THE H2 (Dave, #1369) -- 'Changelog Releases', the wording
    # from the issue, chosen to mirror CHANGELOG.md's own '# Changelog'. It reads as the name of the document
    # FAMILY rather than of one release, which is what lets the version be stated once, by the heading that
    # owns the entries beneath it, instead of in an H1 and a date line four lines above it.
    #
    # THE HARD BREAK IS A BACKSLASH, NOT TWO SPACES (inbound #1100) -- see Build-AudienceNote below for the
    # measurement and why the break itself is kept.
    $header = "# Changelog Releases`n`n**Date:** $Date\`n**Type:** $Type`n`n$titleLine$summaryBlock"
    # The container the entries hang under, so H1 -> H3 does not skip a level. Written even for a release
    # with no pending entry at all: the heading states which release this document IS, which is exactly the
    # question an empty one still has to answer.
    $versionHeading = ('#' * ((Get-EntryHeadingLevel) - 1)) + ' ' + (Format-ReleaseVersionHeading -Version $Version -Date $Date)
    return ($header + $versionHeading + "`n`n" + $body + "`n")
}

# ==================================================================================================
# THE HIGHLIGHTS TIER (#417 phase 2)
# ==================================================================================================
#
# A SECOND, STAKEHOLDER-FACING RENDERING OF THE SAME RELEASE -- not a second changelog. The tier was
# built in a consumer repo and stayed there while cut-release.ps1 was two files; phase 1 shared the
# script, phase 2 shared this half. The rule it carries is older than the sharing (Dave, July 13,
# 2026): HIGHLIGHTS IS WRITTEN FOR NON-DEVELOPERS.
#
# THE MARKER IS GONE, AND WITH IT THE GUESS IT EXISTED FOR (August 5, 2026). Until now this document
# rendered EVERY category, put the branch types a seam called "stakeholder-facing" above a "remove
# before publishing" marker, and left the release manager to delete the rest. That marker was
# explicitly a PROPOSAL rather than a verdict, because the branch prefix does not predict impact -- held
# against the 19 entries pending at v3.2.0, the single most consequential change for a consumer
# (renaming the marketplace, which breaks every existing install) arrived on a chore/ branch and landed
# below the marker.
#
# The tier model asks the author of the entry instead, at the moment they know: 'Tier: 2' means a
# consumer notices. So this document is now simply the tier-2 entries, and the two knobs that
# configured the marker (Get-ReleaseHighlightsStakeholderTypes, Get-ReleaseHighlightsWording) are
# retired. That is a smaller document AND a better-founded one: what used to be a hint for the release
# manager to correct is now a claim the entry's own author made and a reviewer saw on the PR.
#
# STILL A DRAFT TO BE EDITED, for the reason that never depended on the marker: entry bodies are
# written for developers even when the change reaches a consumer, so the selection is right and the
# prose still needs rewriting. What is gone is the deleting, not the writing.
#
# MARKDOWN ONLY -- THE TIER PRODUCES NO HTML, AND THAT IS A DECISION RATHER THAN AN OMISSION (Dave,
# August 3, 2026, the same day it was ported). The source generated a self-contained, print-ready
# .html beside the .md, and ConvertTo-ReleaseHtml + Format-InlineMarkdown were ported with it and then
# removed the same day: it is not wanted anywhere. The renderer was also the weakest part of the port --
# a partial markdown subset that passed links through as literal '[text](url)' -- so the thing that
# needed the most explaining is now simply gone. A reader who wants a PDF renders the markdown with a
# tool built for it. Do not reintroduce an HTML step here without asking.

function Convert-EntryHeadingToTitle {
    <#
        Reduces a folded entry's heading to its bare title: '### #426 <md> Some title <md> Feat <md>
        2026-08-03' -> '### Some title'. Pure string in, string out; a heading that does not carry the
        metadata shape is returned unchanged.

        FOR THE HIGHLIGHTS TIER ONLY, and that is the whole reason it exists as a separate function
        rather than an option on the renderers. The PR number, the branch type and the merge date are
        internal administration: precise, useful in the developer notes, and noise in a document whose
        reader does not have a branch. The developer notes keep them, so this never runs there.

        A leading '#NN' field and the trailing administrative fields are dropped; everything between
        them is the title and is rejoined with the middot, so a title that legitimately contains one
        survives. Only the FIRST line is touched -- the body may contain anything.

        WHICH TRAILING FIELDS, DECIDED BY CONTENT RATHER THAN BY COUNT (August 5, 2026). This used to
        drop exactly two -- the (type, date) pair the scaffold always wrote. Since the merge date moved
        out of the heading onto the entry's closing line, a heading has ONE trailing administrative
        field, while every entry already in this repo's history has two. Dropping a fixed number would
        have to pick which era to be right about; recognising a field by its shape -- a known branch
        type, or an ISO date -- is right for both, which is also why nothing had to be migrated.

        AND SINCE THE TYPE LEFT THE HEADING ALTOGETHER, THE COMMON CASE IS NO TRAILING FIELD AT ALL:
        '## #475 <md> A significance score per entry' carries only the leading '#NN'. That case USED TO
        RETURN THE HEADING UNCHANGED -- the guard below asked whether any trailing field had been dropped,
        which is a different question from whether anything had been dropped, and with the tail empty the
        answer was no. So the consumer document, whose whole reason for calling this is that its reader
        has no PR numbers, would have kept every one of them. Caught by this file's own suite; the guard
        now asks about both ends.
    #>
    param([Parameter(Mandatory)][string]$EntryText)
    $md = [char]0x00B7
    $lines = $EntryText -split "(`r?`n)", 2
    $heading = $lines[0]
    $hm = [regex]::Match($heading, '^(#+)\s+(.*)$')
    if (-not $hm.Success) { return $EntryText }

    # THE DOSSIER HEADING NAMES THE BRANCH, AND THIS DOCUMENT'S READER HAS NO BRANCH. Since August 6, 2026
    # an entry opens with '## `feat/x` changelog' and its human-readable name lives in 'Branch title'
    # -- so for the consumer document the title IS that section. Without this the tier-2 document, the one written
    # for consumers, would list its changes as "`feat/x` changelog": no middot and no '#NN' in that heading,
    # so the field-dropping below leaves it exactly as it found it.
    #
    # SAME RULE AS THE REST OF THIS FUNCTION, applied to a new shape rather than a new rule -- the PR number,
    # the type and the date are dropped here for being internal administration, and a branch name is the
    # purest example of it. The developer notes and CHANGELOG.md keep the heading, as they keep the others.
    # TWO SHAPES OF BRANCH HEADING, both matched here. It was '`feat/x` changelog' until August 16, 2026 and
    # is 'Branch `feat/x` changelog <sep> <timestamp>' since -- an optional lead word before the backticks and an
    # optional trailing stamp after the title. A pattern that knew only the old one would leave every new
    # entry's branch slug standing in the document written for someone outside this repo, which is exactly
    # the publishing defect this rewrite exists to prevent.
    $branchHeading = [regex]::Match($hm.Groups[2].Value, '^(?:[^`\s]+\s+)?`([^`]+)`\s+\S+(?:\s+.*)?$')
    if ($branchHeading.Success) {
        $described = Get-EntryPrTitle -EntryText $EntryText
        # No description, no rewrite: an entry that never filled it in keeps the branch heading, which is
        # ugly and TRUE. Inventing a title from the branch name would publish a slug as a change name.
        if ($described) {
            $title = @($described -split '\r?\n' | Where-Object { $_.Trim() })[0].Trim()
            if ($title) {
                $rest = if ($lines.Count -gt 1) { ($lines[1] + $lines[2]) } else { '' }
                return $hm.Groups[1].Value + ' ' + $title + $rest
            }
        }
        return $EntryText
    }

    $parts = @($hm.Groups[2].Value -split "\s*$md\s*")
    $types = Get-ReleaseChangeTypes
    $first = if ($parts[0] -match '^#\d+$') { 1 } else { 0 }

    # THE TAIL HAS A GRAMMAR, so it is matched rather than walked: at most one date, and before it at
    # most one type. Anything else is title. A greedy "keep eating administrative-looking fields" loop
    # was written first and this file's own suite caught it -- on '### #12 <md> Fix <md> Fix', an entry
    # whose title IS a type name, it ate both and returned the heading unchanged. Two types in a row
    # cannot both be the type; the grammar says so and the loop could not.
    #
    # 'Other' no longer needs excluding: Get-ReleaseChangeTypes returns what the branch table produces and
    # nothing else, where the retired Get-ReleaseCategories appended the catch-all LABEL this repo prints.
    # A field reading 'Other' is therefore a title by construction rather than by a special case.
    $isMeta = {
        param($f, $kind)
        if ($kind -eq 'date') { return $f -match '^\d{4}-\d{2}-\d{2}$' }
        return ($types -contains $f)
    }
    $last = $parts.Count - 1
    if ($last -ge $first -and (& $isMeta $parts[$last].Trim() 'date')) { $last-- }
    if ($last -ge $first -and (& $isMeta $parts[$last].Trim() 'type')) { $last-- }

    # NOTHING WAS ADMINISTRATION AT EITHER END -- so there is no (metadata + title) shape here and the
    # heading is left exactly as it was rather than guessed at. Both ends are tested, which is the fix:
    # asking only about the tail ($last -eq $parts.Count - 1) called a heading untouched whenever it had no
    # trailing field, which since the type moved into its own section is EVERY current entry -- so the
    # leading '#NN' this function exists to drop survived.
    if (($first -eq 0 -and $last -eq ($parts.Count - 1)) -or $last -lt $first) { return $EntryText }
    $title = (@($parts[$first..$last]) -join " $md ").Trim()
    if (-not $title) { return $EntryText }

    $rest = if ($lines.Count -gt 1) { ($lines[1] + $lines[2]) } else { '' }
    return "$($hm.Groups[1].Value) $title$rest"
}

# --- DELETED: Build-ConsumerNotes, the tier-2 renderer of the retired two-document flow -----------
#
# It built releases/consumer/<dir>/<X.Y.Z>.md from a release's tier-2 entries, back when a cut wrote
# TWO hand-written documents -- a consumer one and an internal one. Those became ONE on August 11,
# 2026 (commit f239ed57): Build-ReleaseNoteDraft below, a named section per reader, on the measurement
# that 38% of the internal note was material the consumer document already carried in a second
# register. That commit dropped the CALL and left the FUNCTION, with no note saying why -- so unlike
# the two records above this was left behind rather than kept.
#
# WHY IT WENT NOW (issue #1370, September 4, 2026). #1369 repaired the hard-coded '-EntryLevel 2' out
# of Build-ReleaseNotes, an entry having been written at H3 since August 26, 2026. This function still
# passed the literal 2, so release-lib held two answers to one question and the one left behind was the
# stale one -- and its own test pinned that answer ("at ##"), which is why the repair could not reach
# it. Measured before removing it: no caller anywhere in this repo or in the shipped dkj-policy
# mirror, and releases/consumer/ does not exist here.
#
# AND WHY DELETED RATHER THAN LEVELLED, which is the choice #1370 left open. Levelling alone would have
# left the entries hanging under this document's H1 with H2 empty -- the same skip the version heading
# was added to Build-ReleaseNotes to close -- so the honest repair needed a container heading too: a
# design decision about a document nothing generates, for a reader nothing writes to. Deleting removes
# the second answer instead of correcting it.
#
# WHAT STILL COVERS A CONSUMER WHO HAS ONE OF THESE DOCUMENTS. check-plugin-integrity.ps1 reads
# releases/consumer/ as an ARCHIVE and holds it to the same link rule as the current note tree -- it
# reads FILES, so nothing there depended on this function. A consumer pinned to a pre-August-12
# plugin version has the old lib AND the old cut-release together, so this removal cannot reach them.
#
# ITS OTHER ROLE PASSED TO Build-ReleaseNoteDraft. Four comments cited it as the renderer that "always
# ranks at tier 2" while Build-ReleaseNotes ranks from 1 up -- the pair that showed the changelog's own
# order was not load-bearing (issue #467). The draft ranks at a fixed tier too (-RankByTier
# $AudienceTier), so the argument survives under a name that still exists, and those comments now say so.

function Resolve-ReleaseRetractions {
    <#
        Pure: reads every pending entry's 'Retracts:' line (Get-EntryRetracts) and answers, across the
        WHOLE pending set, which branches are retracted and which entries themselves only retract --
        so a caller can withhold both from the one document that narrates delivered work, while
        CHANGELOG.md and the generated GitHub Release body stay untouched (inbound #2230: a build that
        reached the trunk and was then reverted before the cut was drafted as delivered work, in the
        author's own confident words, because Build-ReleaseNoteDraft selected by tier and had no way to
        see that a later entry in the same release retracted an earlier one).

        Returns:
          RetractedBranches   string[], unique -- every branch a Retracts: line names and that resolves.
          RetractingBranches  string[], unique -- every entry's OWN branch that carries a Retracts: line.
          Withheld            one object per retracting entry that resolved at least one target:
                               RetractingBranch, RetractedBranches (only the ones actually found).
          Errors               one string per Retracts: target that names no pending entry.

        RESOLVED AGAINST THE FULL PENDING SET, NOT ONE TIER'S ENTRIES -- the entry that retracts and the
        entry it retracts are not guaranteed to share a tier (the revert itself is ordinarily
        repo-internal, tier 0, exactly like PR #723 in the issue's own measured instance), and a typo in
        the target name is exactly as real whichever tier it would have reached. A caller that wants to
        know what a SPECIFIC document actually lost intersects Withheld/RetractedBranches with that
        document's own entries -- Format-RetractionWithheldNote's $Removed does exactly that.

        WHAT THIS DOES NOT DO, BY DESIGN (the issue's own "honest objection"): it does not INFER a
        retraction from prose, a diff, or git-revert provenance. That is a semantic claim, and guessing at
        it would produce both false positives and a silently dropped real feature -- worse than the defect
        this answers. An entry retracts another only by saying so, in its own 'Retracts:' line.

        AN UNRESOLVABLE TARGET IS AN ERROR, NOT A SILENT NO-OP (the issue's point 5): a typo must not read
        as "nothing to withhold". The caller is expected to stop the cut on $Errors rather than proceed --
        this function only reports, because the pure/orchestration split in this file's own header keeps
        every refusal ("nothing was written") in cut-release.ps1, never in here.
    #>
    param([AllowEmptyCollection()][string[]]$Entries = @())

    $real = @($Entries | Where-Object { $_ -and $_.Trim() })
    $byBranch = @{}
    foreach ($e in $real) {
        $b = Get-EntryDeclaredBranch -EntryText $e
        if ($b) { $byBranch[$b] = $e }
    }

    $retractedBranches  = New-Object System.Collections.Generic.List[string]
    $retractingBranches = New-Object System.Collections.Generic.List[string]
    $withheld = New-Object System.Collections.Generic.List[object]
    $errors   = New-Object System.Collections.Generic.List[string]

    foreach ($e in $real) {
        $targets = @(Get-EntryRetracts -EntryText $e)
        if ($targets.Count -eq 0) { continue }
        $own = Get-EntryDeclaredBranch -EntryText $e
        $ownLabel = if ($own) { $own } else { '(an entry with no declared branch)' }
        if ($own) { $retractingBranches.Add($own) }
        $found = New-Object System.Collections.Generic.List[string]
        foreach ($t in $targets) {
            if ($byBranch.ContainsKey($t)) {
                $retractedBranches.Add($t)
                $found.Add($t)
            } else {
                $errors.Add("'$ownLabel' names '$t' in its Retracts: line, and no pending entry declares that branch.")
            }
        }
        if ($found.Count -gt 0) {
            $withheld.Add([pscustomobject]@{ RetractingBranch = $own; RetractedBranches = @($found.ToArray()) })
        }
    }

    return [pscustomobject]@{
        RetractedBranches  = @($retractedBranches.ToArray()  | Select-Object -Unique)
        RetractingBranches = @($retractingBranches.ToArray() | Select-Object -Unique)
        Withheld           = @($withheld.ToArray())
        Errors             = @($errors.ToArray())
    }
}

function Format-RetractionWithheldNote {
    <#
        Pure: the HTML comment naming what was withheld from ONE document and why (inbound #2230, point
        4) -- so the person finishing the draft sees the decision instead of wondering at a gap. '' when
        nothing in THIS document was affected, so a caller can add it unconditionally on every release.

        $Removed IS THIS DOCUMENT'S OWN BRANCH LIST, not the whole pending set's. Resolve-ReleaseRetractions
        answers what retracts what across every tier; a retraction that never reached this document's own
        tier has nothing to withhold here and nothing to explain here -- reporting it anyway would name a
        branch the reader never expected to see in the first place.
    #>
    param(
        [Parameter(Mandatory)]$Retractions,
        [AllowEmptyCollection()][string[]]$Removed = @()
    )
    $removedSet = @($Removed | Where-Object { $_ })
    if ($removedSet.Count -eq 0) { return '' }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('Withheld from this section, retracted before the cut -- CHANGELOG.md keeps the full record:')
    foreach ($w in @($Retractions.Withheld)) {
        $relevant = @($w.RetractedBranches | Where-Object { $removedSet -contains $_ })
        foreach ($r in $relevant) { $lines.Add("  - $r (retracted by $($w.RetractingBranch))") }
        if ($relevant.Count -eq 0 -and $w.RetractingBranch -and ($removedSet -contains $w.RetractingBranch)) {
            $lines.Add("  - $($w.RetractingBranch) -- names no work of its own here, only a retraction")
        }
    }
    return "<!-- $($lines -join "`n     ") -->"
}

function Build-ReleaseNoteDraft {
    <#
        The ONE hand-written release document, as a draft: a named section per reader. Pure string out.

        WHAT THIS REPLACED, AND THE MEASUREMENT THAT CHOSE THE SHAPE (Dave, August 10, 2026). There were
        two hand-written documents per release -- an internal note for the organisation and a consumer
        document -- and at every one of the twelve releases since the internal tier existed, BOTH were
        written, about the same changes. Dave proposed one. The question was whether one document can serve
        both readers, and it was answered by measuring v4.2.0's internal note (962 words) against the
        consumer writing norm's test 2 (does this describe our effort or their outcome):

          ~365 words (38%)  could appear in a consumer-facing section -- and were, in the other document,
                            rewritten in a second register. THAT is the duplication.
          ~597 words (62%)  could not, and the largest block of it -- 'what it is worth', 316 words -- is
                            not an outlier but the entire reason the organisational tier exists.

        So a BLENDED document was refused: it would have to drop the 62% or break the norm. A document with
        a NAMED SECTION PER READER keeps each register intact, writes the shared 38% once, and is one file,
        one editing pass, one publish. The consumer section is what 'what is different now' used to be, so
        that heading is gone rather than moved -- it was the duplicated half.

        THE CONSUMER SECTION IS PRE-FILLED AND THE ORGANISATIONAL ONE CANNOT BE. The tier-2 entries are a
        selection the entry authors already made, rendered exactly as the consumer document rendered them
        (bare titles, ranked on tier 2, significance and branch administration stripped). What the work is
        worth cannot be derived from a changelog, so those headings arrive empty, with the guidance in an
        HTML comment the writer deletes.

        NO AUDIENCE SECTION WHERE NO ENTRY REACHED THAT TIER, and that is the tier-1-only minor in a tier-2
        repo: the version moves for everyone and nobody outside is handed a section about work they cannot
        see. A heading with nothing under it is worse than no heading -- measured on the shape this replaces,
        where an empty named question shipped into every document that travelled outward.

        $AudienceTier IS WHICH TIER THAT SECTION IS FOR, and reading it from the repo rather than assuming 2
        is inbound #747. The gate above is right about an empty section and was aimed at the tier-1-only
        release in a TIER-2 repo; in a repo whose audience IS tier 1 it read completely differently, because
        no entry there can ever declare tier 2. The section was suppressed not rarely but always, so the one
        hand-written document that travels outward could be finished and published while never saying what
        shipped. Measured from a consumer against 4.13.0.

        THE SECTION IS STILL PRE-FILLED, WHICH THE REPORT DID NOT EXPECT. #747 proposed an empty heading plus
        a hint, reasoning that a tier-1 repo has no generatable source. It has exactly the same source a
        tier-2 repo has: its tier-1 entries, which the grouper already returns and which render through these
        identical switches. So the fix is symmetric rather than special-cased -- the audience section draws on
        the audience tier's entries, whichever tier that is -- and a tier-1 repo gets the list pre-filled
        instead of merely asked for. Verified by rendering a synthetic tier-1 changelog before building.

        THE DEFAULT IS 2 SO EVERY EXISTING CALLER IS BYTE-IDENTICAL. This repo answers 2, so its documents do
        not move; the change is visible only where the answer is 1.

        $WithheldNote IS THE CALLER'S DECISION, ALREADY MADE (inbound #2230). This function still renders
        exactly the $Entries it is given -- it does not read 'Retracts:' lines or filter anything itself,
        because it cannot see the rest of the pending set that Resolve-ReleaseRetractions needs. The caller
        filters $Entries and hands the already-built HTML comment (Format-RetractionWithheldNote, or '' for
        an ordinary release) in here, so it renders even where the whole audience section would otherwise
        be suppressed for having nothing left in it -- a retraction is exactly the kind of gap a silently
        empty section would hide.
    #>
    param(
        [AllowEmptyCollection()][string[]]$Entries = @(),
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$Date,
        [Parameter(Mandatory)][string]$Type,
        [string]$Title = '',
        [hashtable]$Wording = @{},
        [string]$LinkPrefix = '../../../',
        [int]$AudienceTier = 2,
        [string]$WithheldNote = ''
    )
    # Merged over the defaults rather than replacing them, so a repo that renames one heading does not
    # have to restate the rest -- the same contract the note script's wording seam already had.
    $w = @{
        Title             = 'Release notes'
        AudienceLabel     = 'For whom'
        # 'WHAT CHANGED' AT BOTH TIERS, and the tier-2 default used to be 'For consumers' (Dave,
        # August 21, 2026, reading the built release-notes page). A heading that names the reader tells
        # that reader nothing they do not already know -- they are the one holding the document -- while
        # the section BELOW it does carry a reader in its name, because that one is deliberately the half
        # the consumer's section may not contain. So the pair now reads 'what changed' then 'what it is
        # worth, to the organisation', and only the heading that separates two readers names one.
        #
        # THIS DOES NOT REVERT #747, it completes it: that finding was that 'For consumers' names the
        # WRONG reader at tier 1, which is why the key became tier-dependent. Both tiers answering the
        # same thing is what lets it stop being tier-dependent at all -- the branch below keeps the two
        # keys that genuinely differ.
        SectionAudience   = 'What changed'
        SectionOpen       = 'What was still open at this release'
        HintOpen          = @(
            'What was deliberately left, and with whom the next step sits. "Nothing" is also an answer',
            '-- leave the heading standing with that one line.',
            'Write it as a SNAPSHOT of this release, not as a claim about the present: a document that is',
            'published does not move with reality, so a line here goes stale in hours rather than months.'
        ) -join "`n     "
    }
    # THREE DEFAULTS FOLLOW THE AUDIENCE TIER, because at tier 1 the tier-2 wording is not merely unhelpful
    # but false -- and #747's second finding is exactly that. 'consumers of this product, and colleagues in
    # the organisation -- one section each' promises two readers and one section each in a document that
    # renders one reader and two sections, and the same function guarantees the promise cannot be kept. A
    # repo should not have to override a string to stop shipping a sentence its generator knows is untrue.
    #
    # SectionValue's hint moves for the same reason. At tier 2 it earns its keep by naming who the section
    # is NOT for, since the section above it belongs to somebody else; at tier 1 both sections are for the
    # same reader, so that sentence would deny the audience its own document. What survives the move is the
    # part that is true at either tier: this is the half a changelog cannot produce.
    if ($AudienceTier -eq 2) {
        $w.Audience        = 'consumers of this product, and colleagues in the organisation -- one section each'
        $w.HintAudience    = @(
            'DRAFT. These are the tier-2 entries, still in the words their authors wrote for someone',
            'reviewing a diff. Rewrite them for someone deciding whether to update: what they can now do,',
            'in the second person, most urgent first, and say plainly whether they must act. The seven',
            'tests are in the cut-release skill. Delete this comment when you are done.'
        ) -join "`n     "
        $w.HintValue       = @(
            'FOR THE ORGANISATION, not for the consumer -- this is the section the consumer half is not',
            'allowed to contain. The only part that cannot be generated. Think in time, risk and reduced',
            'dependence on a developer. For example: "changing an amount took five edits in code and can',
            'now be done by the team itself".'
        ) -join "`n     "
    } else {
        $w.Audience        = 'colleagues in the organisation -- what changed, and what it is worth'
        $w.HintAudience    = @(
            "DRAFT. These are the tier-$AudienceTier entries, still in the words their authors wrote for",
            'someone reviewing a diff. Rewrite them for the reader who authorises the work: what is now',
            'possible, most consequential first, and say plainly whether anything is expected of them.',
            'Delete this comment when you are done.'
        ) -join "`n     "
        # 'the changes above' would be a dangling reference in the one state where the section above is
        # suppressed -- rare at tier 1, since a bump that writes this document needs a tier-1 entry, but
        # reachable by hand and by a repo that names 'patch' in Get-ReleaseConsumerBumps. Phrased against
        # the release rather than against a neighbouring section, so it is true either way.
        $w.HintValue       = @(
            'WHAT THIS RELEASE BOUGHT, which a list of changes cannot say -- the only part of this document',
            'that cannot be generated. Think in time, risk and reduced dependence on a developer. For',
            'example: "changing an amount took five edits in code and can now be done by the team itself".'
        ) -join "`n     "
    }
    $w.SectionValue = 'What it is worth'
    foreach ($k in @($Wording.Keys)) { if ($Wording[$k]) { $w[$k] = $Wording[$k] } }
    # THE RETIRED KEY NAMES, read second rather than dropped -- the standing "recognise both, write one"
    # rule, and load-bearing here for the same reason it is on Get-ReleaseConsumerBumps: this wording comes
    # from a CONSUMER-OWNED seam, so a repo that named the section under the old key receives the rename
    # through a plugin update rather than by choosing to. Without this, their override would silently stop
    # being read and the heading would revert to a default they had deliberately replaced.
    #
    # The rename itself is not cosmetic. 'SectionConsumers' was accurate while the section could only ever
    # be a consumer's; at tier 1 a key by that name would hand the organisation a heading whose own
    # identifier says it is for somebody else, which is the class of false name this repo removes rather
    # than inherits.
    if ($Wording['SectionConsumers'] -and -not $Wording['SectionAudience']) { $w.SectionAudience = $Wording['SectionConsumers'] }
    if ($Wording['HintConsumers']    -and -not $Wording['HintAudience'])    { $w.HintAudience    = $Wording['HintConsumers'] }

    $real = @($Entries | Where-Object { $_ -and $_.Trim() })

    $rocket = [char]::ConvertFromUtf32(0x1F680)
    $out = New-Object System.Collections.Generic.List[string]
    $out.Add("# $($w.Title) v$Version $rocket")
    $out.Add('')
    # THE MARKDOWN HARD BREAK IS A BACKSLASH HERE AND IN THE TWO HEADERS ABOVE (inbound #1100), and the
    # break itself is deliberately KEPT. Two trailing spaces are the older spelling of the same thing, and
    # they made every generated release document fail an ordinary "no trailing whitespace" lint rule --
    # measured in a consumer whose trunk went red on the next PR, on files it had not written, at the one
    # moment the tree is least inspectable: after the release was committed, tagged and pushed. The cut runs
    # its lint gate BEFORE these documents exist, so it cannot catch its own output and everything it prints
    # is green; the failure then surfaces on the next branch, reading as that branch's problem.
    #
    # DROPPING THE BREAK WOULD NOT HAVE BEEN FREE, which is the part worth writing down because the report
    # proposed it as costing nothing. '**Date:** x' and '**Type:** y' are separated by a single newline, and
    # a single newline inside a markdown paragraph is a SOFT break -- so removing the two spaces renders the
    # two labels on one line rather than two. The backslash is the CommonMark spelling of the same hard
    # break, every renderer GitHub included accepts it, and no trailing-whitespace rule can see it.
    #
    # WHAT IT COSTS ON THE READING SIDE, so the next person does not have to find out: Get-MetaLine in
    # new-internal-note.ps1 reads these two lines back out, and its pattern now tolerates BOTH spellings --
    # every note already published carries the two-space form and those are records, not files to rewrite.
    $out.Add("**Date:** $Date\")
    $out.Add("**Type:** $Type\")
    $out.Add("**$($w.AudienceLabel):** $($w.Audience)")
    $out.Add('')
    if ($Title) { $out.Add($Title); $out.Add('') }

    # $WithheldNote CAN HOLD THIS SECTION OPEN ON ITS OWN (inbound #2230): a release cut down to nothing
    # but a retraction would otherwise fall through the "no audience section where no entry reached that
    # tier" rule above and say nothing at all about the withholding -- the exact silence the rule was
    # written to avoid, aimed at the one case it had not been asked about yet.
    if ($real.Count -gt 0 -or $WithheldNote) {
        $out.Add("## $($w.SectionAudience)")
        $out.Add('')
        if ($real.Count -gt 0) {
            $out.Add("<!-- $($w.HintAudience) -->")
            $out.Add('')
        }
        if ($WithheldNote) {
            $out.Add($WithheldNote)
            $out.Add('')
        }
        if ($real.Count -gt 0) {
            $linked = @($real | ForEach-Object { Convert-EntryRelativeLinks -EntryText $_ -Prefix $LinkPrefix })
            # THE SAME SWITCHES THE CONSUMER DOCUMENT USED, called rather than re-derived: the score orders the
            # section and is then stripped, and the branch administration goes. Entries sit one level deeper
            # than before because they now live under a section heading rather than under the H1.
            # THE LEVEL IS ASKED FOR RATHER THAN SPELLED OUT (#1369). It was the literal 3, which happens to be
            # the right answer today and is right for the same reason Build-ReleaseNotes' 2 was wrong: an entry
            # belongs at the level it was WRITTEN at, and that level moved once already without either renderer
            # noticing. Same value, no change to any note -- the literal simply stops being a second statement
            # of a fact entry-scaffold-lib.ps1 owns.
            # RANKED ON THE AUDIENCE TIER, not on 2. This is a sort key rather than a filter -- what an entry
            # is worth to THIS document's reader decides where it sits -- so ranking a tier-1 repo's entries on
            # a tier they never scored would read every score as absent and collapse the order to arrival.
            $body = Format-RankedEntries -Entries $linked -EntryLevel (Get-EntryHeadingLevel) -BareTitles -RankByTier $AudienceTier `
                -StripSignificance -StripAdminSections
            $out.Add($body)
            $out.Add('')
        }
    }

    $out.Add("## $($w.SectionValue)")
    $out.Add('')
    $out.Add("<!-- $($w.HintValue) -->")
    $out.Add('')
    $out.Add("## $($w.SectionOpen)")
    $out.Add('')
    $out.Add("<!-- $($w.HintOpen) -->")

    return (($out -join "`n") + "`n")
}

function Build-GitHubReleaseBody {
    <#
        The body of a GitHub Release: the release title, an optional pointer at the attached document,
        and one linked line per change that landed. Pure string out, hard LF.

        WHY THIS IS GENERATED AND THE OTHER DOCUMENTS ARE NOT (Dave, August 10, 2026). The body used to be
        a hand-written tier document, and that coupled the Release page to which tier happened to exist:
        the internal note is the body precisely BECAUSE it was the only tier written at every release,
        which is the reasoning that made a note mandatory at a patch nobody needed one for. A generated
        body cuts the dependency -- the page can be published at any release, including one with no
        hand-written document at all, and the hand-written documents become attachments rather than the
        page itself.

        THE COMPLETE LIST, EVERY TIER. This answers "what landed", which is the one question a Release
        page is read for by someone who arrived from a tag or a diff, and the tier ladder does not apply:
        a repo-internal change is still a change that landed. The tiers decide which DOCUMENT a change
        appears in; this is not one of those documents.

        AN ENTRY WITH NO PR LINK IS LISTED WITHOUT ONE, never dropped. A hand-filed entry, or one whose
        fold could not reach the PR, would otherwise vanish from the only complete list -- and it would
        vanish silently, which is the failure mode this repo keeps meeting. Same reason the title falls
        back to the entry's own heading rather than to nothing.

        IT MUST BE BUILT AT CUT TIME, which is not a preference. The cut EMPTIES CHANGELOG.md, so the
        entries this reads do not exist a moment later; there is no way to regenerate this body after the
        fact from anything but the archived notes.
    #>
    param(
        [AllowEmptyCollection()][string[]]$Entries = @(),
        [Parameter(Mandatory)][string]$Version,
        [string]$Title = '',
        [string]$NotePointer = ''
    )
    $real = @($Entries | Where-Object { $_ -and $_.Trim() })

    $items = @()
    foreach ($e in $real) {
        # The readable name, from the section that owns it -- with the entry's own heading as the fallback
        # so a nameless entry is still listed. Retired section names come along via Get-EntrySectionBody.
        $name = ''
        $described = Get-EntryPrTitle -EntryText $e
        if ($described) { $name = @($described -split '\r?\n' | Where-Object { $_.Trim() })[0].Trim() }
        if (-not $name) {
            $hm = [regex]::Match($e, '^\s*#+\s+(.*)$', 'Multiline')
            if ($hm.Success) { $name = $hm.Groups[1].Value.Trim() }
        }
        if (-not $name) { $name = 'untitled change' }

        # The link the FOLD wrote, read out of the section that holds it rather than off the whole entry:
        # an entry body may quote a PR link of its own, and the first match tree-wide would take that one.
        $url = ''
        $prBody = Get-EntrySectionBody -EntryText $e -Key 'PullRequest'
        if ($prBody) {
            $lm = [regex]::Match($prBody, '\[PR #(\d+)\]\(([^)]+)\)')
            if ($lm.Success) { $url = $lm.Groups[2].Value }
        }

        $items += if ($url) { "- [$name]($url)" } else { "- $name" }
    }

    $out = @()
    if ($Title) { $out += @($Title, '') }
    if ($NotePointer) { $out += @($NotePointer, '') }
    $out += '## What landed'
    $out += ''
    if ($items.Count -gt 0) { $out += $items } else { $out += '_No changes were pending at this release._' }

    return (($out -join "`n") + "`n")
}
