<#
.SYNOPSIS
    Helpers for assembling and updating a Pull Request body from a changelog entry.

.DESCRIPTION
    Dot-source this file:

        . (Join-Path $PSScriptRoot '..\lib\pr-body-lib.ps1')

    Why this exists: open-pr.ps1 fills a fresh PR body by replacing the TEMPLATE PLACEHOLDER with the
    changelog entry's description. That works exactly once. On a resumed branch -- one whose PR is
    already open -- the placeholder is long gone, replaced by the previous description, so refreshing a
    rewritten entry needs a different operation: replace the section under a heading, leaving every
    other part of the body alone.

    Both functions here are PURE functions of their input -- no git, no gh, no filesystem -- so the
    suite (scripts/tests/pr-body.tests.ps1) can assert them without a remote. That split is not a
    nicety: open-pr.ps1 drives a live remote and carries a documented test gap, and the defect found in
    ship-pr.ps1 on August 4, 2026 was in an inline parse rather than in the orchestration the gap note
    excused. Anything in those scripts that is a pure function of text belongs here for that reason.

    Shared with the plugin mirror (registered in scripts/lib/shared-scripts-lib.ps1), because
    open-pr.ps1 is itself mirrored and dot-sources this file.

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script.
    Pure ASCII (repo convention for .ps1).
#>

# Test-FunctionDefined (issue #1729): the seam probes below read the function table directly rather
# than through Get-Command, which parses the name as a wildcard pattern and pays a full PATH scan on
# every miss -- and a miss is the normal case for an optional seam. $PSScriptRoot-relative, so it
# resolves in the plugin mirror as well as here.
. (Join-Path $PSScriptRoot 'command-probe-lib.ps1')

# Get-DocumentNewline (issue #1832): the newline style of the body being edited, read off the body rather
# than hand-typed here. $PSScriptRoot-relative for the same reason as the line above -- it resolves in the
# plugin mirror as well as here.
. (Join-Path $PSScriptRoot 'document-newline-lib.ps1')

function Get-EntryDescription {
    <#
    .SYNOPSIS
        The body of a changelog entry: everything after its compact '### title - type - date' heading.

    .DESCRIPTION
        The description open-pr.ps1 puts under "What does this change do?", extracted here so the fresh
        path and the refresh path read it the SAME way. It lived inline in open-pr.ps1 until August 4,
        2026; adding a second reader would have meant a second copy of the same rule, which is how this
        repo's accumulation bugs start.

        Only the FIRST '### ' line counts as the heading. An entry routinely contains further '###' or
        deeper headings in its own prose, and treating a later one as the boundary would silently cut the
        description short -- returning something plausible rather than failing, which is the worst shape.

        THIS IS A PRE-MERGED-FORMAT READER, AND ITS HEURISTIC IS WHY. The rule above holds only while the
        entry's own heading IS the first '### ' line. In the merged development format as it stood between
        August 23 and 26, 2026 that heading was an H2 (`## DEPLOY: ...`), so the first '### ' line was a
        section INSIDE the body and this function returned the tail from there -- exactly the
        plausible-rather-than-failing shape the paragraph above warns about, arrived at from the other
        direction (inbound https://github.com/DaveKJohn/claude-code-specialists/issues/853). The August 26
        shift moved DEPLOY back to '### ' and its sections to '#### ', so the collision is gone for now --
        by where the levels happen to sit, not by anything this function knows: the '###' below is written
        out rather than read from Get-EntryHeadingLevel. It is not repaired here on
        purpose: Get-PrDescription now recognises that heading itself, so the merged format never reaches
        this fallback, and widening this function would change what a pre-dossier entry returns -- the one
        shape it exists for. If you find yourself needing it for a newer format, that is a sign the caller
        should be reading the heading, not that this heuristic should grow.

        Returns '' when there is no heading, or nothing after it. The caller decides what that means:
        open-pr.ps1 leaves the placeholder in place rather than writing an empty description.
    #>
    param([string]$EntryText)

    if (-not $EntryText) { return '' }

    $lines = $EntryText -split "\r?\n"
    $h3 = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^###\s') { $h3 = $i; break }
    }
    if ($h3 -lt 0 -or ($h3 + 1) -ge $lines.Count) { return '' }

    return (($lines[($h3 + 1)..($lines.Count - 1)]) -join "`n").Trim()
}

function Get-PrDescription {
    <#
    .SYNOPSIS
        What a PR body should carry from an entry: on today's shape the DEPLOY section verbatim, heading and
        all; on the older shape the answer onwards, without the entry's front matter.

    .DESCRIPTION
        THE PR BODY IS NOT THE WHOLE DOSSIER (Dave, August 9, 2026). Get-EntryDescription returns
        everything after the entry's own heading, which is right for the fold -- CHANGELOG.md receives the
        dossier verbatim, front matter and all, and that was chosen deliberately. It is wrong for a PR,
        where the first three sections are answered by the page around the body:

          Branch title  -> IS the PR title, composed from this same section and shown above the body
          Branch ID     -> a creation timestamp; nothing a reviewer can act on
          Branch type   -> the PR's label, and the prefix of the title one line up

        So a reviewer opened a PR and met three restatements before the first sentence about the change.
        The trailing 'Pull Request' section goes for the mirror-image reason: the FOLD fills it, from the
        merge -- in a PR body it is a heading with nothing under it, every time, by construction.

        WHAT IS KEPT is the answer and the Significance sections. Significance is not front matter: it is
        the author saying how far the change reaches and what it is worth to each audience, which is
        exactly what a reviewer is deciding about.

        TWO SHAPES START THE ANSWER, and the second one is why this function no longer bails out when the
        'What' section is missing. In the merged development format (August 23, 2026) the entry has
        no 'What' heading at all: its opening text -- the tier-0 body, the substance -- sits directly under
        the DEPLOY heading. So this reads that heading as the start, via
        Get-DevelopmentEntryPattern, which is the same matcher the fold and both gates use.

        SO ON TODAY'S SHAPE THE RETURN IS THE SECTION ITSELF, HEADING INCLUDED AND NOTHING PROMOTED
        (Dave, issue #884, August 25, 2026). The DEPLOY section must be one thing in all four places it
        lands -- this document, the PR body, CHANGELOG.md, the release notes -- and locked once the PR
        opens, which is what Test-DeployLock checks. Dropping its heading and shifting the rest produced a
        rendering rather than a copy, and two renderings cannot be compared without first agreeing on the
        transform. The legacy path below still promotes, because there the H2 really does stay behind; the
        reasoning for both sits at the two branches in the body.

        WHAT THAT REPAIRS, measured in a consumer and reproduced here (inbound
        https://github.com/DaveKJohn/claude-code-specialists/issues/853): returning '' sent the caller to
        Get-EntryDescription, whose contract is "everything after the entry's compact '### ' heading". That
        was right while the entry's own heading WAS an H3. Under the merged format as it then stood the
        first '### ' line was a section INSIDE the body -- 'What makes this deploy extra special' -- so
        the fallback returned the
        tail from there: about a quarter of the entry, with the opening argument silently gone. The fold was
        unaffected (CHANGELOG.md received the entry complete), so nothing was lost permanently; what was
        lost is the review moment, in a body that looked complete and passed every gate.

        RETURNS '' ONLY WHEN NEITHER SHAPE IS PRESENT, and the caller still falls back to
        Get-EntryDescription there. That is the remaining back-compat story and it is unchanged: a
        pre-dossier entry has no 'What' section and no DEPLOY heading either (its description sat straight
        under an H3 heading), and a consumer with such a branch in flight reaches this code through a
        plugin update rather than by choosing to. Returning '' rather than guessing keeps that path exactly
        as it was.

        FENCE-AWARE, like every reader of this format: an entry documenting the entry format quotes these
        headings inside a fence, and the entry for this very change does. A fenced '### Significance'
        would otherwise cut the description off mid-sentence -- plausible output rather than a failure,
        which is the worst shape.

        Section names come from Get-EntrySectionHeadings / Get-EntrySectionRetiredNames when the
        scaffold lib is loaded (open-pr dot-sources both), so a repo that renamed or translated a heading
        is read by its own names. Probed with Get-Command rather than required, because this file is
        dot-sourced on its own by its suite -- the English defaults are the fallback, not a second
        definition: they are the same strings that lib ships.

    .PARAMETER EntryText
        The full text of the changelog entry file.
    #>
    param([string]$EntryText)

    if (-not $EntryText) { return '' }

    $whatNames = @('What does the change on this branch deploy to main?',
                   'What does the change on this branch bring to main?', 'What does this change do?')
    $endNames  = @('Pull Request')
    if (Test-FunctionDefined 'Get-EntrySectionHeadings') {
        $headings = Get-EntrySectionHeadings
        $whatNames = @($headings['What'])
        $endNames  = @($headings['PullRequest'])
        if (Test-FunctionDefined 'Get-EntrySectionRetiredNames') {
            $whatNames += @(Get-EntrySectionRetiredNames -Key 'What')
            $endNames  += @(Get-EntrySectionRetiredNames -Key 'PullRequest')
        }
    }
    $whatNames = @($whatNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $endNames  = @($endNames  | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    $toPattern = {
        param($names)
        '^#{2,4}\s+(?:' + ((@($names) | ForEach-Object { [regex]::Escape([string]$_) }) -join '|') + ')\s*$'
    }
    $whatRx = if ($whatNames.Count -gt 0) { & $toPattern $whatNames } else { $null }
    $endRx  = if ($endNames.Count -gt 0) { & $toPattern $endNames } else { $null }

    # The merged format's start line, from the one matcher that owns it -- Get-DevelopmentEntryPattern,
    # the same one the fold and both gates use, so a repo that translated the title word is read by its own.
    #
    # Probed with Get-Command and backed by a local default, exactly as the heading names above are and for
    # the same reason: this file is dot-sourced ON ITS OWN by its suite, so a required call would make the
    # suite fail on a function it deliberately does not load. The default is not a second definition of the
    # rule -- it is the same two shapes with the same English words that lib ships, and a repo that renamed
    # the title reaches this code with the lib loaded, which is where its own answer comes from.
    $deployRx = if (Test-FunctionDefined 'Get-DevelopmentEntryPattern') {
        Get-DevelopmentEntryPattern
    } else {
        # Today's shape leads with the title and a colon; every entry written before August 23, 2026 puts
        # the branch first and the title last. Both are matched, and 'changelog' is in the list because
        # entries carrying it exist in every consumer right now.
        '(?:^#{2}\s+(?:[^`]*\s)?(?:DEPLOY|deployment|changelog):\s*`[^`]+`)' +
        '|(?:^#{2}\s+(?:[^`\s]+\s+)?`[^`]+`\s+(?:DEPLOY|deployment|changelog)\s*$)'
    }
    if (-not $whatRx -and -not $deployRx) { return '' }

    # ONE fence-aware pass, then choose -- rather than a scan per shape. Both candidates are collected
    # because the 'What' heading WINS where both are present: an entry in the merged format that still
    # carries a 'What' section is a hand-edited or transitional one, and its author's heading is a better
    # answer than a heading the scaffolder wrote. The end boundary is the first 'Pull Request' heading
    # AFTER the chosen start, which is why it cannot be resolved in the same pass.
    $lines = $EntryText -split "\r?\n"
    $whatAt = -1
    $deployAt = -1
    $inFence = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*(```|~~~)') { $inFence = -not $inFence; continue }
        if ($inFence) { continue }
        $line = $lines[$i].TrimEnd()
        if ($whatAt -lt 0 -and $whatRx -and $line -match $whatRx) { $whatAt = $i }
        if ($deployAt -lt 0 -and $deployRx -and $line -match $deployRx) { $deployAt = $i }
        if ($whatAt -ge 0) { break }
    }
    $start = if ($whatAt -ge 0) { $whatAt } else { $deployAt }
    if ($start -lt 0) { return '' }

    $end = $lines.Count
    $inFence = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*(```|~~~)') { $inFence = -not $inFence; continue }
        if ($inFence -or $i -le $start) { continue }
        if ($endRx -and $lines[$i].TrimEnd() -match $endRx) { $end = $i; break }
    }

    if (($start + 1) -ge $end) { return '' }

    # THE DEPLOY HEADING TRAVELS WITH ITS SECTION, AND THAT PATH PROMOTES NOTHING (Dave, issue #884,
    # August 25, 2026). Which of the two shapes started the answer decides both questions at once, so they
    # are answered together here rather than as two independent flags.
    #
    # ON TODAY'S SHAPE the start line IS '### DEPLOY: `<branch>`', and it is included. #884's requirement is
    # that the section is ONE THING in all four places it lands -- the branch's development document, the PR body,
    # CHANGELOG.md, the release notes -- and is locked once the PR opens. A copy that drops its own heading
    # and shifts every remaining one is not that thing: it is a rendering of it, and two renderings cannot
    # be compared without agreeing on the transform first. Carried verbatim, the PR body IS the section, so
    # Test-DeployLock below is string equality rather than a normalising diff.
    #
    # WHICH REVERSES THE PROMOTION OF AUGUST 9, 2026, ON THIS PATH ONLY, and the reason that promotion
    # existed is the reason it can go. It read:
    #
    #   in the entry / CHANGELOG.md          in a PR body
    #   ## `fix/x` changelog                 (the PR title, not part of the body)
    #   ### What does the change...          # What does the change...
    #   ### What makes this change...        ## What makes this change...
    #
    # -- the entry's sections are H3 because the entry is an H2 block inside CHANGELOG.md, while a PR body
    # is a document of its own, and carrying H3s across left it reading as a fragment of something larger.
    # That was right while the H2 stayed behind. It no longer does, so the body has its own title again and
    # the levels below it are already correct: promoting now would push the DEPLOY heading to H1 and flatten
    # its sections into it.
    #
    # THE LEGACY PATH KEEPS THE PROMOTION, unchanged, because its argument is untouched: an entry found by
    # its 'What does the change...' heading has no H2 to carry, so its H3s really would arrive as a
    # fragment. Consumers have such branches in flight right now and meet this code through a plugin update
    # rather than by choosing to.
    #
    # CHANGELOG.md AND THE RELEASE DOCUMENTS ARE UNTOUCHED, exactly as the August 9 note said of itself:
    # this shifts the COPY that goes into the PR, at the one point where that copy is made.
    $carriesHeading = ($whatAt -lt 0)
    $slice = if ($carriesHeading) {
        @($lines[$start..($end - 1)])
    } else {
        @($lines[($start + 1)..($end - 1)])
    }
    if ($carriesHeading) { return ((@($slice)) -join "`n").Trim() }

    # PROMOTED ONE LEVEL, ON THE LEGACY PATH ONLY (Dave, August 9, 2026; scoped to this path by #884 on
    # August 25). Reached only when the answer started at a 'What does the change...' heading -- the block
    # above returns before here whenever the DEPLOY heading was the start, and explains why. In an entry of
    # that older shape the sections are H3 and the tiers H4, because the entry itself is an H2 -- one block
    # among many in CHANGELOG.md. A PR body is not: it is a document of its own, whose own title is the
    # heading GitHub prints above it. Carrying those levels across left the body starting at H2 with tiers
    # at H4, which reads as a fragment of something larger, and it is:
    #
    #   in the entry / CHANGELOG.md          in a PR body
    #   ## `fix/x` changelog                 (the PR title, not part of the body)
    #   ### What does the change...          # What does the change...
    #   ### What makes this change...        ## What makes this change...
    #   #### a sub-heading in a body         ### a sub-heading in a body
    #
    # THAT ARGUMENT STILL HOLDS HERE, AND ONLY HERE, because on this path the H2 genuinely stays behind:
    # the 'What' heading is a section INSIDE the entry, so there is no title to carry and something has to
    # supply one. Today's shape has its own, which is what let #884 drop the transform there.
    #
    # CHANGELOG.md and the release documents are untouched: this shifts the COPY that goes into the PR,
    # at the one point where that copy is made. The record keeps the levels the fold and the renderers
    # depend on.
    #
    # Fence-aware for the reason the boundary search above is, and floored at 1 -- a heading cannot be
    # promoted past H1, and a body that already starts at H1 is returned as it is rather than mangled.
    $inFence = $false
    $promoted = foreach ($line in $slice) {
        if ($line -match '^\s*(```|~~~)') { $inFence = -not $inFence; $line; continue }
        if ($inFence) { $line; continue }
        $m = [regex]::Match($line, '^(#+)(\s+\S.*)$')
        if ($m.Success -and $m.Groups[1].Value.Length -gt 1) {
            ('#' * ($m.Groups[1].Value.Length - 1)) + $m.Groups[2].Value
        } else {
            $line
        }
    }

    return ((@($promoted)) -join "`n").Trim()
}

function Get-PrTitle {
    <#
    .SYNOPSIS
        The PR title, composed: '<branch type>: <the entry's Branch title>'. '' when there are no words.

    .DESCRIPTION
        THE TITLE IS DERIVED, NOT TYPED (Dave, #506 + #505, August 7, 2026). It used to be given twice --
        once to new-branch.ps1, which writes it into the entry, and again to open-pr.ps1 -Title at the end
        of the branch -- with nothing holding the two together. One of them is what CHANGELOG.md and the
        release documents carry; the other is what the PR is called; and which one a reader met depended on
        where they were standing.

        The type half is the same repair from the other side. Derek's manual has always said the title reads
        '<branch-type>: ...', and measured on August 7, 2026 the last FIVE merged PRs (#499-#503) all
        violated it -- a rule that lives in a document, is never measured, and is therefore silently broken.
        Composing it here means it cannot be omitted and cannot contradict the branch: the type comes off the
        branch prefix, which is the same source as the PR's label and the entry's own type section.

        PURE, and given the words rather than the entry text, so this stays a function of two strings. The
        caller reads the section (Get-EntrySectionAnswer -Key 'Description'), which is the reader that
        already knows about retired heading names -- duplicating that here would be a second definition of
        where the title lives.

        THE FIRST NON-EMPTY LINE WINS, with its inner whitespace collapsed. A title is one line by nature and
        the section is free-form markdown; a two-line answer would otherwise reach `gh pr create --title`
        with a newline in it.

        NO PREFIX IS STRIPPED, deliberately -- AND IT HAPPENED (#936, August 26, 2026). This paragraph used
        to close with "if it ever does happen, this is the note to come back to", on the premise that of every
        entry in CHANGELOG.md and the release record NOT ONE title carried a type prefix. That premise expired
        on PR #934, which opened as 'fix: fix: the no-tier fallback drops the whole audience paragraph': the
        title was handed to new-branch.ps1 with a 'fix: ' already on it and this function put the branch type
        in front of it again. Coming back to the note, as asked.

        THE STRIP STILL DOES NOT LIVE HERE, and that is the repair rather than the absence of one. The doubled
        title is not merely what the PR is called: the same line travels verbatim into CHANGELOG.md as the
        folded entry's 'Pull Request' section, so the artefact that survives the merge is the ENTRY. Stripping
        here would quietly correct the PR title and leave that entry wrong -- the fault repaired where it is
        visible and kept where it lasts. So the guard is a REFUSAL in open-pr.ps1's title gate, which sends the
        author back to the entry; Get-PrTitlePrefixFinding below is what that gate reads, and it is bounded to
        exactly the branch's own prefix so a legitimate title like 'sync-roster: ...' cannot be accused.

        THE WORDS MAY COME FROM A PRE-SPLIT ENTRY'S HEADING, which is why the caller passes them rather than
        this reading the section itself. An entry written before the dossier form has NO title section at
        all -- its title WAS the heading -- and every consumer with such a branch in flight receives these
        scripts through a plugin update rather than by choosing to. Refusing them would turn a branch that worked
        yesterday into a stop at the PR. Recognise both, write one.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Prefix,
        [Parameter(Mandatory)][AllowEmptyString()][string]$TitleWords
    )

    $words = ''
    foreach ($line in ($TitleWords -split "\r?\n")) {
        if (-not [string]::IsNullOrWhiteSpace($line)) { $words = $line.Trim(); break }
    }
    $words = [regex]::Replace($words, '\s+', ' ')
    if (-not $words) { return '' }

    # AN EMPTY PREFIX YIELDS THE WORDS ALONE, which is how the caller says "this branch's prefix is not one
    # of ours": open-pr passes '' for an unknown prefix, warns about it, and labels the PR 'question'.
    # Putting that unknown word in front of the title would state a type no table backs.
    if ([string]::IsNullOrWhiteSpace($Prefix)) { return $words }
    return ($Prefix.Trim() + ': ' + $words)
}

function Get-ExemptBranchTitleWords {
    <#
    .SYNOPSIS
        The title words for a branch that owes no entry: an explicit title, else its own commit subject.

    .DESCRIPTION
        WHY AN EXEMPT BRANCH NEEDS ITS OWN SOURCE (issue #1962, September 13, 2026). Since #506 the PR
        title is composed from the entry and nothing else, which is right for every branch that HAS one.
        A branch whose prefix is entry-exempt has none by design -- Get-BranchEntryExemptPrefix says so,
        and the CI gate passes it for exactly that reason -- so composing from the entry leaves open-pr
        with an empty title and no way to be given one. Measured in a consumer: a sync/ branch got through
        the lint gate, all 27 suites and the push, and could not open its PR.

        THE COMMIT SUBJECT IS THE THING THAT EXISTS. A mirror branch's work arrived as a commit, and the
        script that made it wrote a descriptive subject ('sync: mirror in-flight third-party edits from
        live (47 file(s))'). That is the branch's own statement of what it carries, so the PR is named
        from it rather than from a placeholder or the branch slug.

        THE OLDEST SUBJECT WINS, which is why the caller passes them oldest-first. The opening commit is
        what the branch was cut for; anything after it is a follow-up, and a park commit -- empty by
        design -- would name the PR after the bookkeeping instead of the work.

        -Title IS HONOURED HERE AND NOWHERE ELSE, and that bound is the whole of #506 kept intact. What
        that change removed was a SECOND source of truth: a title typed at the PR that could contradict
        the one CHANGELOG.md and the release documents carry. An exempt branch has no entry to be a second
        source OF, so there is nothing here to contradict -- and a caller wrapping this script (a
        consumer's sync-main does) may well know a better name than the commit subject.

        PURE, and it composes nothing: the type prefix, the first-non-empty-line rule and the whitespace
        collapse all stay in Get-PrTitle, which the caller applies to this answer. Returns '' when there
        is neither a title nor a usable subject, which the caller reports as its own refusal.
    #>
    param(
        [AllowEmptyString()][string]$Title = '',
        [AllowEmptyCollection()][string[]]$CommitSubjects = @()
    )

    if (-not [string]::IsNullOrWhiteSpace($Title)) { return $Title.Trim() }
    foreach ($subject in @($CommitSubjects)) {
        if (-not [string]::IsNullOrWhiteSpace($subject)) { return ([string]$subject).Trim() }
    }
    return ''
}

function Get-PrTitlePrefixFinding {
    <#
    .SYNOPSIS
        The type prefix the entry's title ALREADY carries, when it is this branch's own. '' when there is none.

    .DESCRIPTION
        WHAT THIS EXISTS FOR (#936, August 26, 2026). Get-PrTitle above composes '<branch type>: <words>' and
        strips nothing, so a title written as 'fix: the fallback drops ...' on a fix/ branch composes to
        'fix: fix: the fallback drops ...'. That shipped on PR #934. The convention is documented -- the
        new-branch skill says to write the words WITHOUT a prefix -- and a documented convention nothing
        measures is one this repo has watched break before.

        A FINDING, NOT A REPAIR, and the caller refuses on it. The doubled line is not only the PR title: the
        fold copies the same words into CHANGELOG.md, and from there the release documents carry them to
        consumers. Silently stripping would fix the copy that is visible for a day and leave the copy that
        lasts, so the author is sent back to the entry instead.

        BOUNDED TO THE BRANCH'S OWN PREFIX, which is what makes the check safe to refuse on. It is NOT
        '^\w+:' -- that would mangle a legitimate title like 'sync-roster: the ignore list is empty', and the
        fear of exactly that is why the strip was left out in the first place. Only the word the branch table
        already handed us counts, so a title can collide with this only by beginning with this repo's own type
        name followed by a colon.

        AN EMPTY PREFIX IS NO FINDING. open-pr passes '' for a branch whose prefix the table does not know,
        and Get-PrTitle then composes the words alone -- nothing is doubled, so there is nothing to report.

        CASE-INSENSITIVE, because 'Fix: ...' doubles just as visibly as 'fix: ...' and an author who
        capitalised the first word of their sentence made the same mistake.

        PURE, and it normalises by CALLING Get-PrTitle with no prefix rather than repeating its rules. Which
        line of a free-form section is the title, and what happens to its inner whitespace, is defined once
        above; a second copy here would be free to judge a different string than the one that ships.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Prefix,
        [Parameter(Mandatory)][AllowEmptyString()][string]$TitleWords
    )

    if ([string]::IsNullOrWhiteSpace($Prefix)) { return '' }
    $words = Get-PrTitle -Prefix '' -TitleWords $TitleWords
    if (-not $words) { return '' }

    $match = [regex]::Match($words, '^' + [regex]::Escape($Prefix.Trim()) + '\s*:', 'IgnoreCase')
    if (-not $match.Success) { return '' }
    return $match.Value
}

function Update-PrBodySection {
    <#
    .SYNOPSIS
        Replaces the content under one heading of a PR body, leaving the rest of the body untouched.

    .DESCRIPTION
        The section runs from the heading line to the next heading AT THE SAME LEVEL OR HIGHER, or to the
        end of the body. Same-level-or-higher rather than "the next heading of any kind" is the whole
        subtlety: a description may contain its own deeper headings, and stopping at the first of those
        would leave half the old description stranded below the new one -- a body that reads as though it
        says two things.

        THE LEVEL RULE ALONE IS NOT ENOUGH WHEN THE SECTION IS AN H1 (inbound #598), and that is what
        -StopAtHeading is for. At level 1 "the same level or higher" can only ever match another H1, so
        every '##' section that follows is by definition nested inside the description and gets replaced
        along with it. Measured in a consumer: a template whose description sits under an H1 lost its one
        repo-specific section -- heading, guidance and both checkboxes -- on every -RefreshBody, reported
        as "updated the description" and nothing else.

        The reasoning above stays right, which is why this is an extra boundary rather than a different
        one: a description CAN contain its own deeper headings, so the level rule cannot simply be
        loosened to "the next heading of any kind". What the caller knows and this function cannot is
        which headings belong to the FORM rather than to the description -- so it passes them in.

        Fenced code is skipped when looking for the boundary, because a description explaining this
        mechanism will contain a '##' inside a fence. Not hypothetical: this repo's own entry for this
        feature does.

        AN EMPTY -Heading ADDRESSES THE BODY'S LEADING SECTION (issue #865), which is what a PR template
        that carries no heading produces: the description starts at the top of the body and no heading
        line is written back. The level rule cannot apply there -- a section with no heading has no level
        to compare another against -- so -StopAtHeading is the ONLY boundary, and where the form carries
        none the leading section is the whole body. That is the right answer rather than a fallback: a
        template with no headings has nothing below the description to protect.

        AND IT IS WHY A LEGACY BODY NEEDS NO LEGACY HEADING HERE. A PR opened while the template still
        led with an H1 keeps that heading in its published body -- above the first form heading, so the
        leading section covers it and it is replaced along with everything else. The caller's legacy list
        is for the other case, a template that still HAS a heading.

        Returns the body UNCHANGED and reports it via -Changed when the heading is absent or the content
        already matches, so a caller can skip the API call entirely rather than publishing a no-op edit.

    .PARAMETER Body
        The current PR body.

    .PARAMETER Heading
        The literal heading line, e.g. '## What does this change do?'. Matched at the start of a line,
        whole-line, so a heading quoted mid-sentence elsewhere in the body cannot be mistaken for it.
        EMPTY means the leading section -- everything from the top of the body to the first boundary.

    .PARAMETER Content
        The replacement content for that section, without the heading.

    .PARAMETER StopAtHeading
        Extra literal heading lines that also end the section, whatever their level -- the form's own
        later headings. NARROWING ONLY: the section ends at the EARLIEST of these and the level rule, so
        passing them can shorten what is replaced and never lengthen it. That is what makes the parameter
        safe to add to a shared function -- a caller that passes nothing gets byte-identical behaviour to
        before, and one that passes a heading the body does not contain gets the same.

    .PARAMETER Changed
        [ref] set to $true when the returned body differs from the input.
    #>
    param(
        [string]$Body,
        # AllowEmptyString, because empty is a MEANING here and not a missing argument: it addresses the
        # body's leading section. Mandatory alone refuses '' for a [string], which is what made a
        # heading-less PR template unrefreshable before issue #865.
        [Parameter(Mandatory)][AllowEmptyString()][string]$Heading,
        [string]$Content,
        [string[]]$StopAtHeading = @(),
        [ref]$Changed
    )

    if ($null -ne $Changed) { $Changed.Value = $false }
    if (-not $Body) { return $Body }

    # EMPTY CONTENT IS A NO-OP, NOT AN INSTRUCTION TO CLEAR THE SECTION. There is no reason to want a
    # blank description, while there are several ways to arrive here with nothing: an entry with no body,
    # a heading that did not parse, or a failed read upstream. On August 4, 2026 exactly that shape --
    # a string operation quietly yielding nothing -- published an EMPTY PR body by hand, so the rule is
    # that this function cannot be the thing that removes text without putting text back. Caught by its
    # own suite before it shipped.
    if (-not $Content -or -not $Content.Trim()) { return $Body }

    $nl = Get-DocumentNewline -Content $Body
    $lines = $Body -split "\r?\n"

    # THE LEADING SECTION has no heading line and therefore no level. $start stays at -1, which the
    # boundary search below reads as "begin at line 0" and the reassembly reads as "nothing before it",
    # both of which they already did for a heading on the first line.
    $leading = [string]::IsNullOrWhiteSpace($Heading)

    # The heading's own level, so the boundary search knows what counts as "the next section". A level of
    # 0 makes the level rule below unsatisfiable -- no heading has fewer than one '#' -- which is exactly
    # the leading section's rule: -StopAtHeading is its only boundary.
    $level = ([regex]::Match($Heading, '^(#+)')).Groups[1].Value.Length
    if (-not $leading -and $level -eq 0) { return $Body }

    $start = -1
    if (-not $leading) {
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i].TrimEnd() -eq $Heading.TrimEnd()) { $start = $i; break }
        }
        if ($start -lt 0) { return $Body }
    }

    # Where the section ends: the EARLIEST of two boundaries, ignoring anything inside a fence --
    #   1. the next heading at $level or shallower (the original rule, right for a nested description);
    #   2. any heading the caller named in -StopAtHeading, at whatever level (the form's own sections,
    #      which an H1 description would otherwise swallow whole -- inbound #598).
    # Whichever comes first wins, so the second can only ever shorten the section.
    $stops = @(@($StopAtHeading) | Where-Object { $_ -and $_.Trim() } | ForEach-Object { $_.TrimEnd() })
    $end = $lines.Count
    $inFence = $false
    for ($i = $start + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*(```|~~~)') { $inFence = -not $inFence; continue }
        if ($inFence) { continue }
        $m = [regex]::Match($lines[$i], '^(#+)\s')
        if (-not $m.Success) { continue }
        if ($m.Groups[1].Value.Length -le $level) { $end = $i; break }
        if ($stops -contains $lines[$i].TrimEnd()) { $end = $i; break }
    }

    $before = if ($start -gt 0) { $lines[0..($start - 1)] } else { @() }
    $after  = if ($end -lt $lines.Count) { $lines[$end..($lines.Count - 1)] } else { @() }

    # BUILT WITH @() AND +=, NOT `$middle = if (...) {...}`. An if-statement's value is unwrapped, so the
    # one-heading branch would assign a [string] and every += below it would CONCATENATE rather than append
    # -- well-formed output, wrong document. Caught by this file's own suite.
    $middle = @()
    if (-not $leading) { $middle += $Heading.TrimEnd() }
    if ($Content) { $middle += ($Content.Trim() -split "\r?\n") }
    # One blank line before the next section, and only when there IS a next section.
    if ($after.Count -gt 0) { $middle += '' }

    $rebuilt = (@($before) + $middle + @($after)) -join $nl
    if ($rebuilt -ne $Body -and $null -ne $Changed) { $Changed.Value = $true }
    return $rebuilt
}

function Get-LostBodyHeadings {
    <#
    .SYNOPSIS
        The headings present in a PR body that are absent from the version about to replace it.

    .DESCRIPTION
        THE SIGNAL A SILENT SECTION LOSS NEEDS (inbound #598). -RefreshBody deleted a whole template
        section along with the description and reported only "the description was updated" -- so the
        recovery depended on somebody running 'gh pr view' days later and noticing. A green PR with a
        complete-LOOKING body is exactly the state in which nobody re-reads the form.

        THE SUBJECT IS A HEADING THAT DISAPPEARED, NOT A BODY THAT GOT SHORTER, and that choice is the
        whole reason this is checkable rather than noisy. A refresh legitimately shrinks a body every time
        the new description is shorter than the old one, so a size rule would fire on the common case and
        be switched off within a week. A section that was there and is now gone is never something this
        script intends.

        Pure and level-agnostic, and fence-aware for the same reason every other reader here is: a body
        explaining the form quotes the form's headings, and a quotation is not a section.

        Returns an array of the lost heading lines, in the order the old body had them. Empty means
        nothing was lost -- which after #598's fix is the expected answer, so this survives as a tripwire
        for the next shape nobody predicted rather than as a routine condition.
    #>
    param(
        [AllowEmptyString()][string]$Before,
        [AllowEmptyString()][string]$After
    )

    $headings = {
        param([string]$text)
        if (-not $text) { return @() }
        $inFence = $false
        return @($text -split "\r?\n" | ForEach-Object {
            if ($_ -match '^\s*(```|~~~)') { $inFence = -not $inFence; return }
            if (-not $inFence -and $_ -match '^#{1,6}\s+\S') { $_.TrimEnd() }
        })
    }

    $kept = @(& $headings $After)
    return @(@(& $headings $Before) | Where-Object { $kept -notcontains $_ })
}

function Test-DeployLock {
    <#
    .SYNOPSIS
        Does the open PR body still carry the DEPLOY section this document would produce?

    .DESCRIPTION
        THE LOCK (Dave, issue #884, August 25, 2026). The DEPLOY section travels four times --
        the branch's development document -> the PR body -> CHANGELOG.md -> the developer release notes -- and it has to
        be the same thing at every stop. So it is fixed at the moment the PR opens: after that the document
        may not diverge from what the PR published, because the PR is what reviewers approved and
        CHANGELOG.md is what the fold will take.

        THE PR IS THE RECORDED COPY, WHICH IS WHY THIS NEEDS NO STATE. Three mechanisms were weighed
        (Dave chose the first): compare against the open PR; stamp a fingerprint into the document; or
        silently re-sync at merge time. The second adds an artefact to the file the fold consumes and has to
        be stripped again on the way out. The third refuses nothing, so it is not a lock. The first stores
        nothing at all -- open-pr already published the section, and reading it back is the comparison.

        WHY THIS IS CONTAINMENT AND NOT EQUALITY. A repo's PR template may wrap the section (this repo's is
        a single placeholder comment, so the body IS the section; a consumer's need not be), and open-pr
        splices the description into that template. So the question is whether the body still CONTAINS the
        section, not whether it equals it. That is only checkable at all because Get-PrDescription now
        carries the section verbatim -- while it promoted headings, body and document were two renderings
        and this comparison would have had to reproduce the transform to make it.

        NORMALISED ON THE TWO THINGS A ROUND TRIP THROUGH GITHUB CHANGES AND NOTHING ELSE: line endings
        (a body fetched with `gh pr view --json body` comes back CRLF) and trailing whitespace per line.
        Deliberately NOT normalised: case, blank lines between paragraphs, punctuation, heading levels. Each
        of those is a real edit to a section that is supposed to be closed, and a comparison that forgave
        them would report a lock it is not holding.

        NOT APPLICABLE IS A THIRD ANSWER, not a failure. An entry with no DEPLOY heading is the pre-August
        23 shape, which has no section to lock -- every consumer has such branches in flight and meets this
        code through a plugin update rather than by choosing to. An empty PR body is the same answer for the
        opposite reason: there is nothing published to hold the document against yet. Both come back
        Applicable = $false, and the gates treat that as no finding -- the same tolerance the step-list gate
        gives a branch with no step list.

        Pure: it reads no file, runs no gh, and returns a record rather than writing or exiting. The gate
        script and ship-pr both call it, so there is one definition of "diverged" rather than two.

        RETURNS a PSCustomObject:
          Applicable  $false when there is nothing to compare (see above); the callers stop there
          Locked      $true when the body still carries the section
          Heading     the section's own heading line, for the message
          FirstDrift  the first document line the body does not have at that point, or '' -- the one line
                      an author needs in order to find the edit
    #>
    param(
        [AllowEmptyString()][string]$EntryText,
        [AllowEmptyString()][string]$PrBody
    )

    $na = [PSCustomObject]@{ Applicable = $false; Locked = $true; Heading = ''; FirstDrift = '' }

    if ([string]::IsNullOrWhiteSpace($EntryText) -or [string]::IsNullOrWhiteSpace($PrBody)) { return $na }

    # THE EXPECTED SECTION COMES OUT OF THE FUNCTION THAT WROTE IT, never out of a second slicer here. A
    # copy of that slicing would be free to disagree with what open-pr published, and the gate would then
    # refuse over its own reading rather than over an edit.
    $expected = Get-PrDescription -EntryText $EntryText
    if (-not $expected) { return $na }

    # ONLY TODAY'S SHAPE IS LOCKED, and the heading is what says which shape this is: Get-PrDescription
    # carries it on the merged format and cannot produce it on the legacy one.
    # THE LEVEL COMES FROM THE FORMAT, not from a literal here. It was '^#{2}' until August 26, 2026, when the
    # cycle file shifted one level down and the DEPLOY heading became an H3 -- and both levels have to pass,
    # because a PR opened from a document scaffolded before the shift publishes the old one. Read off the
    # entry heading level so a future re-level cannot leave this test locking a shape nothing writes.
    $lockLevel = if (Test-FunctionDefined 'Get-EntryHeadingLevel') { Get-EntryHeadingLevel } else { 3 }
    $lockRx = '^#{' + ($lockLevel - 1) + ',' + $lockLevel + '}\s+\S'
    $expectedLines = @($expected -split "\r?\n" | ForEach-Object { $_.TrimEnd() })
    if ($expectedLines.Count -eq 0 -or $expectedLines[0] -notmatch $lockRx) { return $na }
    $heading = $expectedLines[0]

    $bodyLines = @($PrBody -split "\r?\n" | ForEach-Object { $_.TrimEnd() })

    # ANCHORED ON THE HEADING RATHER THAN SCANNED FOR THE WHOLE BLOCK, so a body that carries the section
    # with ONE line edited reports that line instead of "not found anywhere". Which is the whole value of
    # the check: "the section is gone" and "somebody rewrote its third paragraph" need different answers.
    $at = -1
    for ($i = 0; $i -lt $bodyLines.Count; $i++) {
        if ($bodyLines[$i] -eq $heading) { $at = $i; break }
    }
    if ($at -lt 0) {
        return [PSCustomObject]@{ Applicable = $true; Locked = $false; Heading = $heading; FirstDrift = $heading }
    }

    for ($k = 0; $k -lt $expectedLines.Count; $k++) {
        $b = $at + $k
        $have = if ($b -lt $bodyLines.Count) { $bodyLines[$b] } else { $null }
        if ($have -ne $expectedLines[$k]) {
            return [PSCustomObject]@{
                Applicable = $true; Locked = $false; Heading = $heading; FirstDrift = $expectedLines[$k]
            }
        }
    }

    return [PSCustomObject]@{ Applicable = $true; Locked = $true; Heading = $heading; FirstDrift = '' }
}

# --- The gate-bypass section (issue #2361) --------------------------------------------------------------
# THE WORKFLOW ASKED FOR A RECORD THE TOOLING COULD NOT WRITE. A deliberate -SkipLint/-SkipTests "belongs in
# the PR body, with a clause in the receipt" -- the receipt printed that sentence -- but -Body replaces the
# template the entry fills and -RefreshBody rewrites the body from the document, so the only route was a
# hand edit of the one file the DEPLOY lock reads. Measured on PR #2357: `gh pr view --json body -q .body`
# hands PowerShell an ARRAY of lines, an array written with WriteAllText comes out space-joined, the body
# collapsed to three lines, and ship-pr's lock refused the merge only after a full CI wait. So open-pr writes
# the section itself, as a sibling of the description like the closing block, and carries it across a
# refresh rather than asking anybody to re-add it.

function Get-GateBypassHeadingText {
    <#
    .SYNOPSIS
        The heading text of the gate-bypass section, without its hashes. One definition, read by the
        writer and the reader alike, for the reason Get-NoResolvesMarker is one.
    #>
    return 'Gate bypass'
}

function New-GateBypassLine {
    <#
    .SYNOPSIS
        One line of the gate-bypass section: what was skipped, and why -- '' when nothing was skipped.

    .DESCRIPTION
        -Skipped is Get-GateBypassNote's output ('-SkipTests', '-SkipLint and -SkipTests'), so the
        section names the switches in the words the operator typed, the same words the receipt uses.
        A missing reason is SAID rather than left blank: a bypass nobody explained is itself the thing a
        reviewer needs to see, and the line names the parameter that would have recorded one.
    #>
    param(
        [AllowEmptyString()][string]$Skipped,
        [AllowEmptyString()][string]$Reason
    )
    if ([string]::IsNullOrWhiteSpace($Skipped)) { return '' }
    $why = if ([string]::IsNullOrWhiteSpace($Reason)) {
        'no reason recorded (pass -BypassNote to give one)'
    } else {
        # One line, always: a newline in the reason would forge a second bullet or a heading.
        ($Reason -replace '\s+', ' ').Trim()
    }
    return ('- `' + ($Skipped.Trim() -replace ' and ', '` and `') + '` -- ' + $why)
}

function Get-GateBypassLines {
    <#
    .SYNOPSIS
        The lines a PR body's gate-bypass section already carries, in order -- empty when it has none.

    .DESCRIPTION
        Read so that -RefreshBody can put them back: a refresh of a body whose description is its leading
        section rewrites everything below the description, and a record of an EARLIER run's bypass must
        not be lost to a later run that skipped nothing. Fence-aware and level-agnostic, like every other
        reader of a PR body here; the section ends at the next heading of any level.

        ONLY LIST ITEMS ARE ITS LINES. Every line the writer puts there is a '- ' bullet, and the section
        can be the LAST one in a body, where the next heading never comes -- so a reader taking every
        non-blank line would sweep up whatever headingless text sits below it. The no-resolves marker is
        exactly that: Add-NoResolvesMarker appends it at the foot with no heading, a -SkipTests -NoResolves
        run leaves it directly under this section, and the next refresh would then weld it in as a
        bypass line (found in review on #2361's branch).
    #>
    param([AllowEmptyString()][string]$Body)
    if (-not $Body) { return @() }
    $title = [regex]::Escape((Get-GateBypassHeadingText))
    $inFence = $false
    $inSection = $false
    $lines = @()
    foreach ($line in ($Body -split "\r?\n")) {
        if ($line -match '^\s*(```|~~~)') { $inFence = -not $inFence; continue }
        if ($inFence) { continue }
        if ($line -match '^#{1,6}\s+\S') {
            $inSection = [bool]($line -match ('^#{1,6}\s+' + $title + '\s*$'))
            continue
        }
        if ($inSection -and $line -match '^\s*[-*]\s+\S') { $lines += $line.TrimEnd() }
    }
    return @($lines)
}

function Add-GateBypassLines {
    <#
    .SYNOPSIS
        Adds lines to a PR body's gate-bypass section, creating the section where there is none.
        Idempotent per line.

    .DESCRIPTION
        A line the section already carries is not added again, so re-running a skipped gate on the same
        branch does not grow the section, while a different skip or reason on a later run is appended
        beneath the first -- each bypass the PR went through stays on record.

        THE SECTION MATCHES THE BODY'S OWN TOP LEVEL, read off its first heading outside a fence, exactly
        as Add-ResolvesBlock reads it and for the same reason (see New-ResolvesBlock's -Level): a section
        deeper than the description sits inside it and is deleted by the next -RefreshBody.

        A BODY WITH NOTHING TO ADD IS RETURNED UNTOUCHED, byte for byte, so a caller comparing before with
        after announces an edit only when it made one.
    #>
    param(
        [AllowEmptyString()][string]$Body,
        [string[]]$Lines
    )
    $wanted = @($Lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.TrimEnd() })
    $have = @(Get-GateBypassLines -Body $Body)
    $missing = @()
    foreach ($l in $wanted) { if ($have -notcontains $l -and $missing -notcontains $l) { $missing += $l } }
    if ($missing.Count -eq 0) { return $Body }

    $title = Get-GateBypassHeadingText
    if ($have.Count -eq 0 -and -not ($Body -match ('(?m)^#{1,6}\s+' + [regex]::Escape($title) + '\s*$'))) {
        $level = 2
        $inFence = $false
        foreach ($line in (([string]$Body) -split "\r?\n")) {
            if ($line -match '^\s*(```|~~~)') { $inFence = -not $inFence; continue }
            if ($inFence) { continue }
            $m = [regex]::Match($line, '^(#+)\s+\S')
            if ($m.Success) { $level = [Math]::Min(6, $m.Groups[1].Value.Length); break }
        }
        $block = ((@((('#' * $level) + ' ' + $title), '') + $missing) -join "`n")
        if (-not $Body -or -not $Body.Trim()) { return $block }
        return ($Body.TrimEnd() + "`n`n" + $block + "`n")
    }

    # The section exists: insert the new lines after its last bullet, before the next heading. The body's
    # own newline is kept -- a CRLF body stays CRLF -- so an insert touches only the lines it adds, as the
    # append branch above and Add-ResolvesBlock do.
    $nl = if (([string]$Body).Contains("`r`n")) { "`r`n" } else { "`n" }
    $src = ([string]$Body) -split "\r?\n"
    $out = New-Object System.Collections.Generic.List[string]
    $inFence = $false
    $inSection = $false
    $lastInSection = -1
    for ($i = 0; $i -lt $src.Count; $i++) {
        $line = $src[$i]
        if ($line -match '^\s*(```|~~~)') { $inFence = -not $inFence }
        elseif (-not $inFence -and $line -match '^#{1,6}\s+\S') {
            $inSection = [bool]($line -match ('^#{1,6}\s+' + [regex]::Escape($title) + '\s*$'))
            if ($inSection) { $lastInSection = $i; continue }
        }
        # Bullets only, for Get-GateBypassLines' reason: a headingless marker below the section is not in it.
        if ($inSection -and -not $inFence -and $line -match '^\s*[-*]\s+\S') { $lastInSection = $i }
    }
    for ($i = 0; $i -lt $src.Count; $i++) {
        $out.Add($src[$i])
        if ($i -eq $lastInSection) {
            if ($src[$i] -match '^#{1,6}\s+') { $out.Add('') }
            foreach ($l in $missing) { $out.Add($l) }
            # A heading straight after keeps its blank line above it, as everywhere else in this file.
            if ($i + 1 -lt $src.Count -and $src[$i + 1] -match '^#{1,6}\s+\S') { $out.Add('') }
        }
    }
    return ($out -join $nl)
}

function Get-PrDescriptionPlaceholderDefaults {
    <#
    .SYNOPSIS
        The template placeholder lines open-pr.ps1 replaces with the entry's description, when the repo
        defines no Get-PrDescriptionPlaceholder of its own.

    .DESCRIPTION
        RECOGNISE ALL, WRITE ONE -- and deliberately no count here, because this list only grows and a
        tally of it goes stale silently. The last is what this family's template carries now (the entry path
        moved under the workflow's own folder on August 14, 2026, the file was renamed branch-deployment.md
        on August 19, on August 23 it became the DEPLOY section of development.md, on August 25 that
        section started travelling WITH its heading -- issue #884 -- on August 26 the folder itself was
        renamed workflow-davekjohn -> contributing-davekjohn, issue #886, on August 27 the document was
        renamed development-cycle.md -> development.md, issues #963/#958, and on September 3 that one
        shared document became one per branch, development-<branch>.md, issue #1255, and later that same
        day the 'development-' prefix went, leaving <branch>.md, issue #1335, and on September 5 the folder
        was renamed a second time, contributing-davekjohn -> dkj-policy, issue #1437); the older
        strings stay because a consumer's PR template is THEIR file, and this script must not silently
        stop filling it in because the template it ships beside moved on. An unrecognised placeholder is
        a PR body with no description at all -- the outcome this list exists to prevent.

        WHICH IS WHY THE FOLDER RENAME APPEARS TWICE HERE RATHER THAN ONCE (issue #952, August 27, 2026).
        The rename commit REWROTE the four strings that carried the folder name instead of appending to
        them, which inverted the list's whole purpose: a consumer who has not migrated is by definition
        still carrying 'workflow-davekjohn' in their template, so the four strings kept for them became
        the four that no longer matched them, and the list tolerated only paths a migrated repo would
        have -- the one case that needs no tolerance. Measured in smartwatchbanden on the 4.20.0 update,
        before any migration: 0 matches. Append-only means append: a rename adds a form, it never
        replaces one, and the pre-rename forms below are recovered verbatim from commit 8797f7a5^.

        The forms for the RETIRED filenames are kept under every folder name as well, even though no
        template ever carried one -- those filenames were gone before the folder was renamed. Recognising
        a string nobody carries costs nothing, and removing entries is the move this defect was made of.
        MOVED OUT OF open-pr.ps1 ON AUGUST 10, 2026, and the move is the point rather than tidiness
        (#573). While the list lived inline in the script, nothing else in the repo could read it -- so
        the reference template shipped with the plugin could not be held against it, and a reference
        whose placeholder open-pr does not recognise is exactly the defect that issue reported from a
        consumer: twelve merged PRs with no description, found by diffing templates months later.
        A gate needs the list; the list therefore lives where a gate can reach it.

        Ordered oldest first, with the written one last, so Get-PrTemplateCanonicalPlaceholder can take
        it from the end rather than by repeating the string.
    #>
    return @(
        '<!-- Korte beschrijving van wat er verandert en waarom. -->',
        '<!-- Short description of what changes and why. -->',
        "<!-- Filled from branch/branch-changelog.md. Opening a PR by hand? Paste that file's body here. -->",
        "<!-- Filled from workflow-davekjohn/branch/branch-changelog.md. Opening a PR by hand? Paste that file's body here. -->",
        "<!-- Filled from workflow-davekjohn/branch/branch-deployment.md. Opening a PR by hand? Paste that file's body here. -->",
        "<!-- Filled from the DEPLOY section of workflow-davekjohn/development-cycle.md. Opening a PR by hand? Paste that section's body here. -->",
        "<!-- Filled from the DEPLOY section of workflow-davekjohn/development-cycle.md, heading and all. Opening a PR by hand? Paste that whole section here, starting at its '## DEPLOY:' line. -->",
        "<!-- Filled from contributing-davekjohn/branch/branch-changelog.md. Opening a PR by hand? Paste that file's body here. -->",
        "<!-- Filled from contributing-davekjohn/branch/branch-deployment.md. Opening a PR by hand? Paste that file's body here. -->",
        "<!-- Filled from the DEPLOY section of contributing-davekjohn/development-cycle.md. Opening a PR by hand? Paste that section's body here. -->",
        "<!-- Filled from the DEPLOY section of contributing-davekjohn/development-cycle.md, heading and all. Opening a PR by hand? Paste that whole section here, starting at its '## DEPLOY:' line. -->",
        "<!-- Filled from the DEPLOY section of contributing-davekjohn/development.md, heading and all. Opening a PR by hand? Paste that whole section here, starting at its '## DEPLOY:' line. -->",
        "<!-- Filled from the DEPLOY section of contributing-davekjohn/development-<branch>.md, heading and all. Opening a PR by hand? Paste that whole section here, starting at its '## DEPLOY:' line. -->",
        "<!-- Filled from the DEPLOY section of contributing-davekjohn/<branch>.md, heading and all. Opening a PR by hand? Paste that whole section here, starting at its '## DEPLOY:' line. -->",
        # THE LEVEL IN THE QUOTED HEADING WAS STALE, NOT THE PATH (#1338, September 3, 2026). Every form
        # above quotes '## DEPLOY:', which is the level the DEPLOY heading carried until the August 26, 2026
        # shift moved the branch document's phases to H3 -- so this family's own template told a reader
        # opening a PR by hand to paste from a line their document does not have. Appended rather than
        # rewritten, for exactly the reason #952 is written up above: a consumer's template is THEIR file and
        # still carries the old wording, and dropping the form they hold is how twelve PRs got no
        # description. The level here is the one Get-BranchCycleSectionLevel writes and is not derived --
        # this list is matched verbatim, so a computed level would make the strings unrecognisable to it.
        "<!-- Filled from the DEPLOY section of contributing-davekjohn/<branch>.md, heading and all. Opening a PR by hand? Paste that whole section here, starting at its '### DEPLOY:' line. -->",
        # AND THE FOLDER RENAMED A SECOND TIME (#1437, September 5, 2026): 'contributing-davekjohn/' ->
        # 'dkj-policy/', when the plugin it is named after did. APPENDED, never substituted -- that is the
        # whole of #952's lesson and the rename above is the instance it was measured on. Every form for the
        # RETIRED filenames is mirrored here too, on the same reasoning the contributing-davekjohn block
        # already carries: no template ever wrote one, recognising a string nobody holds costs nothing, and
        # removing entries is the move the defect was made of. The last line is the one that is WRITTEN.
        "<!-- Filled from dkj-policy/branch/branch-changelog.md. Opening a PR by hand? Paste that file's body here. -->",
        "<!-- Filled from dkj-policy/branch/branch-deployment.md. Opening a PR by hand? Paste that file's body here. -->",
        "<!-- Filled from the DEPLOY section of dkj-policy/development-cycle.md. Opening a PR by hand? Paste that section's body here. -->",
        "<!-- Filled from the DEPLOY section of dkj-policy/development-cycle.md, heading and all. Opening a PR by hand? Paste that whole section here, starting at its '## DEPLOY:' line. -->",
        "<!-- Filled from the DEPLOY section of dkj-policy/development.md, heading and all. Opening a PR by hand? Paste that whole section here, starting at its '## DEPLOY:' line. -->",
        "<!-- Filled from the DEPLOY section of dkj-policy/development-<branch>.md, heading and all. Opening a PR by hand? Paste that whole section here, starting at its '## DEPLOY:' line. -->",
        "<!-- Filled from the DEPLOY section of dkj-policy/<branch>.md, heading and all. Opening a PR by hand? Paste that whole section here, starting at its '## DEPLOY:' line. -->",
        "<!-- Filled from the DEPLOY section of dkj-policy/<branch>.md, heading and all. Opening a PR by hand? Paste that whole section here, starting at its '### DEPLOY:' line. -->"
    )
}

function Get-PrTemplateCanonicalPlaceholder {
    <#
    .SYNOPSIS
        The single placeholder line a NEW template should carry -- the one of the recognised set that is
        written rather than merely accepted.

    .DESCRIPTION
        Taken from the end of the recognised list rather than written out again here, so the reference
        template and the matcher cannot disagree about it. That is the whole mechanism: a second literal
        would be free to drift, and drift between those two is the defect #573 was filed about.
    #>
    $defaults = @(Get-PrDescriptionPlaceholderDefaults)
    return $defaults[$defaults.Count - 1]
}

function Get-PrTemplateReference {
    <#
    .SYNOPSIS
        The canonical PR-template body this family ships as a reference, as an array of lines.

    .DESCRIPTION
        ONE LINE, AND IT IS THE WHOLE CONTRACT. Everything open-pr.ps1 needs from a PR template is a
        placeholder line the matcher recognises, taken from Get-PrTemplateCanonicalPlaceholder rather
        than written out, so the reference cannot ship a line the matcher would walk past.

        IT WAS TWO LINES UNTIL AUGUST 24, 2026, and the first was a heading -- 'What does the change on
        this branch deploy to main?', the question the entry's opening section used to carry. It went
        with issue #865: since August 23 the DEPLOY section names that answer with no heading of its
        own (the text sits straight under '### DEPLOY: <branch>'), so a template still asking the
        question was the last place in the system doing so, and every PR body opened here led with a
        heading whose own document had dropped it.

        WHAT THE HEADING WAS LOAD-BEARING FOR, because deleting it was not enough on its own:
        -RefreshBody replaced the description under the template's FIRST heading, so a template with
        none would have degraded to its warning branch on every run -- the whole switch lost, reported
        as "the description was left as it is", which reads like a decision. Update-PrBodySection
        therefore learned the LEADING section: no heading, start at the top of the body, and take the
        boundary from the form's own later headings alone. That is the shape a template like this one
        produces, and it is what open-pr now hands it.

        WHY IT IS SO SHORT, kept here because the next repo to ask should re-run the measurement
        rather than inherit the answer. This family's template carried a "Type of change" block and a
        six-item checklist until August 9, 2026. Measured over 60 PRs before anything was removed:
        "Type of change" had exactly one of four boxes ticked every single time -- a fact the entry
        already states under '### Branch type', and which the GitHub label takes from Get-BranchInfo
        rather than from the tick -- while of the checklist two items were ticked 60/60 (by this script)
        and two were ticked 0/60 by anyone, ever, though both were already enforced by gates that block
        the PR. A box that is always ticked and a box that is never ticked carry the same information.
        So the rule is "keep what is neither restated by the entry nor proven by a gate", and in this
        repo nothing survived it. IN YOURS SOMETHING MAY: the consumer that reported #573 re-ran the
        same measurement over their own 60 PRs and found one box of eight that genuinely varied -- a
        preview-URL approval, on a repo whose result has to be judged by eye, which no gate can prove.
        They kept it, correctly. The measurement travels; the answer does not.

        NO '## Specific to this repo' SLOT IS PRE-WRITTEN, unlike CONTRIBUTING-portable.md, and the
        difference is what the file is: a contributing guide is read once, while every heading in a PR
        template is repeated in every PR body forever. An empty slot would be a permanent empty section
        in your PR list. Add one when you have something to put in it -- BELOW the placeholder, where
        open-pr reads it as the form's own and hands it to Update-PrBodySection as the boundary the
        description stops at. A heading ABOVE the placeholder means the opposite: that the description
        lives under it, and open-pr anchors there instead.

        SO A REPO MAY STILL LEAD WITH A HEADING, and nothing here refuses one: such a template gets
        exactly the behaviour it had before. What changed is that the absence of one is now a shape
        rather than a failure.
    #>
    return @(
        (Get-PrTemplateCanonicalPlaceholder)
    )
}
