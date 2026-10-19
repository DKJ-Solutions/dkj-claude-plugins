<#
.SYNOPSIS
    The decisions behind the go-live half of the paste-ready block -- which day the next release
    falls on, the projected version the driver prints for the session, and the text the block becomes
    (a version in it only when one is given, #2620). Pure: no
    network, no filesystem, no repo-config, no gh, no Asana.

.DESCRIPTION
    Dot-sourced by build-golive-block.ps1 beside it, for the split page-publish-rules.ps1 and
    backlog-page-rules.ps1 already make in this plugin: everything that touches gh, git or the
    repo's own seam cannot be exercised by a suite, while the parts that can be WRONG -- which
    Monday, which bump, what a colleague actually reads -- are pure functions over values the
    caller has already resolved.

    ISSUE #2100 (Dave, September 18, 2026). The block WORKFLOW-portable.md defines answered
    'where can I see it' and stopped there. The requester's next question is always 'and when do I
    actually see it', and the ticket is the only place they are looking, so the block gained three
    facts: the next release day, the version that release would carry, and the live storefront URLs.

    THE RELEASE DAY IS A PROJECTION, AND THE WORDING SAYS SO. A release can slip, so 'Het staat
    gepland' / 'planned to go live' is the wording, never 'will' -- this block is the one surface a
    colleague quotes back, so a cadence must not read there as a commitment anybody made. The version
    went further than wording could carry: a tier-1 entry landing on the Friday turns a predicted patch
    into a minor, so since #2620 the driver hands -Version in only when a caller passed one.

    AND A FACT THAT CANNOT BE DERIVED IS LEFT OUT, NEVER GUESSED. No version resolves to a sentence
    with no number in it, not to a plausible one; no live URLs resolve to no list at all. That is
    the same reasoning that makes the RESULT link a person's answer rather than a derived one,
    applied one paragraph further down.

    WHY THE SEMVER ARITHMETIC IS LOCAL AND NOT dkj-policy's Get-NextVersion. Every script in this
    plugin deliberately pulls in nothing outside its own folder -- a store forwards to them from the
    plugin cache without a second plugin's libs, which is the boundary publish-page.ps1's own header
    states and repo-root-lib.ps1 repeats. Step-SemVer is six lines of arithmetic held by this
    plugin's own suite; reaching across for it would cost the one property that lets these scripts
    run at all.

    Pure ASCII (repo convention for .ps1).
#>

# The marker the fold writes onto the changelog's pending tally. Matched, never written: this file
# does not touch a changelog, it only reads the one line in it that already names the earned bump.
$script:GoLivePendingTallyMarker = '<!-- pending-tally -->'

function Get-NextReleaseDate {
    <#
        Pure: the date of the next release day, strictly AFTER -From.

        STRICTLY AFTER, so a run on the release day itself names the following week. BWJ cuts on a
        Monday morning and the work that closes later that Monday ships with the NEXT one -- a block
        naming today would tell a colleague to look for something that went out before it was built.
        Where a caller genuinely means 'today counts', it passes the previous day as -From, which is
        an explicit act rather than a default nobody chose.

        -ReleaseDay is a parameter and not a seam because the cadence is this chapter's own (BWJ:
        Monday). A repo cutting on another day passes it; adding a repo-config function for it would
        put a workflow-wide seam into the script contract for a value only two repos answer.
    #>
    param(
        [datetime]$From = (Get-Date),
        [System.DayOfWeek]$ReleaseDay = [System.DayOfWeek]::Monday
    )
    $start = $From.Date
    $delta = ([int]$ReleaseDay - [int]$start.DayOfWeek + 7) % 7
    if ($delta -eq 0) { $delta = 7 }
    return $start.AddDays($delta)
}

function Format-GoLiveDate {
    <#
        Pure: the release date as a colleague reads it -- 'maandag 21 september 2026', or in English
        'Monday 21 September 2026'.

        THE LANGUAGE IS THE BLOCK'S, AND THE BLOCK'S IS THE COLLEAGUE'S (#2507). The date sits inside the
        pasted block, which WORKFLOW-portable.md step 2 hands to the colleague's language -- so it is
        passed in, never read from the machine: a machine's locale must not decide which language a
        colleague's ticket is written in.

        THE NAMES ARE SPELLED OUT HERE rather than asked of a CultureInfo, so the answer does not depend
        on which culture data the host happens to carry.
    #>
    param(
        [Parameter(Mandatory = $true)][datetime]$Date,
        [ValidateSet('nl', 'en')][string]$Language = 'nl'
    )
    if ($Language -eq 'en') {
        return $Date.ToString('dddd d MMMM yyyy', [System.Globalization.CultureInfo]::InvariantCulture)
    }
    $days   = @('zondag', 'maandag', 'dinsdag', 'woensdag', 'donderdag', 'vrijdag', 'zaterdag')
    $months = @('januari', 'februari', 'maart', 'april', 'mei', 'juni', 'juli', 'augustus',
                'september', 'oktober', 'november', 'december')
    return "$($days[[int]$Date.DayOfWeek]) $($Date.Day) $($months[$Date.Month - 1]) $($Date.Year)"
}

function Get-PendingBumpFromTally {
    <#
        Pure: the bump the pending changelog has earned -- 'minor', 'patch', or $null.

        IT READS THE TALLY LINE RATHER THAN THE ENTRIES, and that is the whole point. The fold
        already computes this and writes it under the pending heading as '**4 / 9 minor entries**',
        recomputed from the entries every time the list changes and marked as machine-written with
        an HTML comment. Re-deriving it here would mean a second copy of a release gate's
        arithmetic -- and re-deriving it correctly is not even possible from inside this plugin,
        since the tier parser lives in dkj-policy's own libs, which these scripts may not reach.

        $null IS RETURNED FOR THREE DIFFERENT REASONS AND THE CALLER TREATS THEM ALIKE: no tally
        line at all (a repo on an older workflow, or one that has never folded), a tally saying
        nothing is pending (the last release took everything, so there is no next version to name
        yet), and a tally whose bump word is not one this function knows.

        THE LIMIT, STATED RATHER THAN PAPERED OVER. The two words are seamed
        (Get-ChangelogPendingSummaryOverrides), so a repo that has translated its changelog gets
        $null here and a block with no version in it. That is the correct failure -- a missing
        number rather than a wrong one -- and -Version on the driver is the way past it.

        THE MARKER MUST NOT BE READ OUT OF A SENTENCE THAT QUOTES IT. The one document that will
        ever describe this line in prose is the changelog's own intro, where the natural way to name
        the marker is inline backticks, so a line whose marker sits inside a code span is skipped.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Changelog)

    foreach ($line in ($Changelog -split "`r?`n")) {
        if (-not $line.Contains($script:GoLivePendingTallyMarker)) { continue }
        $before = $line.Substring(0, $line.IndexOf($script:GoLivePendingTallyMarker))
        # An odd number of backticks before the marker means it opened a code span the marker sits
        # inside -- the same discriminating pass entry-scaffold-lib's own quoted-tally check makes.
        $ticks = @($before.ToCharArray() | Where-Object { $_ -eq [char]0x60 }).Count
        if (($ticks % 2) -eq 1) { continue }
        if ($line -match '\*\*[^*]*\bminor\b[^*]*\*\*') { return 'minor' }
        if ($line -match '\*\*[^*]*\bpatch\b[^*]*\*\*') { return 'patch' }
        return $null
    }
    return $null
}

function Step-SemVer {
    <#
        Pure: an X.Y.Z bumped by 'minor' or 'patch'.

        NO 'major' CASE, deliberately. A major is not a size this work adds up to -- it recaps the
        minors behind it and somebody decides to mark it -- so nothing that PREDICTS a version has
        any business producing one. A caller that knows a major is being cut passes -Version.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Current,
        [Parameter(Mandatory = $true)][ValidateSet('minor', 'patch')][string]$Bump
    )
    if ($Current -notmatch '^(\d+)\.(\d+)\.(\d+)$') { throw "Current version '$Current' is not X.Y.Z." }
    [int]$maj = $Matches[1]; [int]$min = $Matches[2]; [int]$pat = $Matches[3]
    if ($Bump -eq 'minor') { $min++; $pat = 0 } else { $pat++ }
    return "$maj.$min.$pat"
}

function Test-PrivateResultLink {
    <#
        Pure: true where -Link is a claude.ai Artifact URL -- a page the Asana requester cannot open.

        ISSUE #2341 (measured in BWJ-Development/smartwatchbanden#750, September 23, 2026). A session
        passed the preview HANDOVER PAGE as -Link, and the block went out with a link its only reader
        could not use. An Artifact is private to its owner until somebody shares it -- PREVIEW-portable.md
        says so of the handover page itself -- and it is the REVIEWER's surface, not the requester's.

        Both published shapes are matched: claude.ai/artifact/<id> and claude.ai/code/artifact/<uuid>.
        The host is anchored so a storefront path that merely contains 'artifact' is not refused.
    #>
    param([AllowEmptyString()][string]$Link)
    if (-not $Link) { return $false }
    return [bool]($Link -match '^(https?://)?(www\.)?claude\.ai/(code/)?artifact/')
}

function Get-StoreAdminPrerequisiteMarker {
    <#
        Pure: the marker of the store-admin checklist on an issue (#2885).

        A STORE-ADMIN PREREQUISITE IS WORK THE CHANGE NEEDS ON THE STORE, NOT IN THE THEME -- a metafield
        definition, a menu, a page, an app embed, a store setting. Measured in
        BWJ-Development/xoxowildhearts (#383, #391, #399): a theme feature read a collection metafield whose
        definition nobody created, the PR named it in prose, and the go-live block told the reviewer to tick
        a checkbox that did not exist in admin.

        THE CHECKLIST LIVES ON THE ISSUE (Dave, October 7, 2026, deciding #2885), because the issue is the
        one record both moments can read: the preview handover, while the branch is open, and the go-live
        block, which is built at the close after the fold has removed the branch document and which looks
        up no pull request. An HTML comment for the reason every marker here is one: it renders as nothing.
    #>
    return '<!-- store-admin-prerequisites -->'
}

function Get-StoreAdminPrerequisites {
    <#
        Pure: every store-admin prerequisite the given texts declare, as objects with Done ([bool]) and
        Item (the text after the box). -Text is the issue body and its comment bodies, in any order.

        A TEXT DECLARES PREREQUISITES ONLY WHERE IT CARRIES THE MARKER, and only the task-list lines AFTER
        the marker count, up to the next Markdown heading or HTML comment -- so an unrelated checklist
        above it, or an 'Acceptance criteria' list under a heading below it, adds nothing. A ticked box is
        '[x]' or '[X]', which is what GitHub writes when somebody clicks it; '[ ]' is open. It errs towards
        refusing: a numbered or quoted box counts, a box with no text is an open item, and a marker
        with no box under it is one too.

        A LOOSE MATCH, ACCEPTED FOR THE SAME REASON Test-AsanaPasteBlockPosted's is: a comment QUOTING the
        template carries the marker and an open box, and holds the go-live block back. That errs towards
        refusing, and build-golive-block.ps1 -Force is the way past it.
    #>
    param([AllowEmptyCollection()][string[]]$Text = @())

    $marker = Get-StoreAdminPrerequisiteMarker
    $items  = @()
    foreach ($t in @($Text)) {
        if (-not $t) { continue }
        $at = $t.IndexOf($marker, [System.StringComparison]::OrdinalIgnoreCase)
        if ($at -lt 0) { continue }
        $found = 0
        foreach ($line in ($t.Substring($at + $marker.Length) -split "`r?`n")) {
            if ($line -match '^\s{0,3}(#{1,6}\s|<!--)') { break }
            # Bullets, numbers and quotes alike, and no space required around the box: a variant the
            # template did not write still counts, because a box missed here is a post let through.
            if ($line -match '^[\s>]*(?:[-*+]|\d+[.)])\s*\[([ xX])\]\s*(.*?)\s*$') {
                $item = if ($Matches[2]) { $Matches[2] } else { '(a box with no text)' }
                $items += [pscustomobject]@{ Done = ($Matches[1] -ne ' '); Item = $item }
                $found++
            }
        }
        # A MARKER WITH NO BOX UNDER IT meant a checklist and did not parse, so it holds the post back.
        if ($found -eq 0) { $items += [pscustomobject]@{ Done = $false; Item = '(the checklist marker, with no box under it)' } }
    }
    return $items
}

function Get-GoLiveBlockText {
    <#
        Pure: the fixed words of the pasted block, in the language it is written in (#2507).

        THE BLOCK IS WRITTEN IN THE COLLEAGUE'S LANGUAGE, BECAUSE IT IS ADDRESSED TO THEM.
        WORKFLOW-portable.md step 2 turns the language over at exactly this boundary -- English on
        GitHub, the colleague's own language on the board -- and the paste block was the one
        colleague-facing text whose words a script had fixed in English. Measured on
        BWJ-Development/smartwatchbanden#769 (September 25, 2026): the English printout was rejected by
        the owner, pointing at the Dutch block BWJ had actually sent a colleague, and rewritten by hand.

        THE SHAPE IS THAT BLOCK'S: the automation's header and closed line (English in both, see
        below), then five fixed headings. The Dutch words are the reference comment's own; the English
        ones are its translation, for a task written in English.

        Non-ASCII characters are composed from code points, because this file is read by Windows
        PowerShell 5.1 as the system ANSI code page (language-layers.md).
    #>
    param([ValidateSet('nl', 'en')][string]$Language = 'nl')

    $dash = [string][char]0x2014
    $e    = [string][char]0x00E9

    # THE HEADER AND THE CLOSED LINE ARE THE SAME IN EVERY LANGUAGE (#2700). They are the GitHub
    # automation's own two lines, fixed and English on every board like its created and reopened forms
    # (#2656), and the same two lines the asana-closed-message workflow opens its comment with (#2818).
    # {0} is 'owner/repo#<n>', {1} the issue URL.
    $header = "$dash GitHub automation $([char]::ConvertFromUtf32(0x1F916))"
    # THE CLOSED LINE IS AN INTRO AND THE LINE UNDER IT (#3069, Maikel, October 16, 2026). A close as
    # completed sends the task on to review whatever the block holds, so the intro is one line for every
    # form, and only the line under it differs: the reopen invitation for a result already visible, the
    # same with 'visible with the release' for one that names a planned day, and 'Nothing has changed'
    # for research -- which replaces #3017's 'the Asana task is ready for review. Read the outcome
    # below.', a lead that did not say nothing changed, so a research form used for a change that went
    # live read as plausible (smartwatchbanden#395). The same words the closed message composes
    # (Get-ClosedMessageIntroTail, Get-ClosedMessageSecondLine).
    $closed         = 'GitHub issue [{0}]({1}) is now **closed**: this Asana task is now in review.'
    $closedLive     = 'It can be reopened anytime when something is still not working as expected.'
    $closedRelease  = 'It becomes visible with the release named below, and can be reopened anytime when something is still not working as expected.'
    $closedResearch = 'Nothing has changed. Read the outcome below.'
    # THE MEASUREMENT FORM'S LINE (#3179): the store DID change, only the effect is a number nobody sees, so
    # it neither says nothing changed nor invites a look. The same words the closed message composes.
    $closedMeasure = 'Nothing changes visibly on the storefront. You can take a new measurement yourself, as described below.'
    # THE RESEARCH BLOCK'S HEADING IS FIXED AND ENGLISH ON EVERY BOARD (#3017), like the closed line above
    # it, so it is the same in both languages; only the bullets under it carry the task's own words.
    $outcome = 'OUTCOME'

    if ($Language -eq 'en') {
        return @{
            Header       = $header
            Closed       = $closed
            ClosedLive   = $closedLive
            ClosedRelease = $closedRelease
            ClosedResearch = $closedResearch
            ClosedMeasure = $closedMeasure
            Outcome      = $outcome
            Measure      = 'HOW TO MEASURE'
            Targets      = 'TARGETS'
            Baseline     = 'LAST MEASUREMENT'
            MeasureWhen  = 'WHEN TO MEASURE'
            Changed     = 'WHAT IS DIFFERENT NOW'
            Where        = 'WHERE TO LOOK'
            When         = 'WHEN IT GOES LIVE'
            NotIncluded  = 'WHAT IS DELIBERATELY NOT IN IT'
            Ask          = 'WHAT WE ASK OF YOU'
            ResultLink   = 'You can view the result here: {0}'
            ReleaseDay   = 'It is planned to go live with the release of {0}.'
            ReleaseVer   = 'It is planned to go live with the release of {0}, as version v{1}.'
            LiveNoLink   = 'Once it is live you can see it here:'
            LiveBare     = 'Once it is live you can see it here. Before then, open these in a private window: a browser that has opened the result link keeps showing the result on these pages, not what is live.'
            AskLook      = 'Look at the result yourself, at the link above. It goes live with that release either way, so this is the last moment something can still change before a customer sees it.'
            LiveSince    = 'It has been live since {0}.'
            LiveSinceVer = 'It has been live since {0}, as version v{1}.'
            LiveNow      = 'You can see it live here:'
            AskLookLive  = 'Look at the result yourself, at the link above. It is already live, so what you see is what a customer sees.'
            AskYes       = 'Is it right? Say so, and tick off this task.'
            AskNo        = 'Is it not? Then we would like to hear two things: what is not right yet, and what exactly should change. The issue is then reopened for a new round.'
        }
    }
    return @{
        Header       = $header
        Closed       = $closed
        ClosedLive   = $closedLive
        ClosedRelease = $closedRelease
        ClosedResearch = $closedResearch
        ClosedMeasure = $closedMeasure
        Outcome      = $outcome
        Measure      = 'ZO MEET JE HET'
        Targets      = 'DOELEN'
        Baseline     = 'LAATSTE METING'
        MeasureWhen  = 'WANNEER JE MEET'
        Changed     = 'WAT ER NU ANDERS IS'
        Where        = 'TE BEKIJKEN OP'
        When         = 'WANNEER HET LIVE KOMT'
        NotIncluded  = 'WAT ER BEWUST NIET IN ZIT'
        Ask          = 'WAT WE VAN JE VRAGEN'
        ResultLink   = 'Het resultaat is hier te bekijken: {0}'
        ReleaseDay   = 'Het staat gepland voor de release van {0}.'
        ReleaseVer   = 'Het staat gepland voor de release van {0}, als versie v{1}.'
        LiveNoLink   = 'Zodra het live is, zie je het hier:'
        LiveBare     = "Zodra het live is, zie je het hier. Open ze tot die tijd in een priv${e}venster: een browser die de link hierboven al heeft geopend, blijft op deze pagina's het resultaat tonen en niet wat er live staat."
        AskLook      = 'Bekijk het resultaat zelf, via de link hierboven. Het gaat hoe dan ook mee met die release, dus dit is het laatste moment waarop er nog iets aan te passen valt voordat een klant het ziet.'
        LiveSince    = 'Het staat live sinds {0}.'
        LiveSinceVer = 'Het staat live sinds {0}, als versie v{1}.'
        LiveNow      = 'Je ziet het hier live:'
        AskLookLive  = 'Bekijk het resultaat zelf, via de link hierboven. Het staat al live, dus wat je ziet is wat een klant ziet.'
        AskYes       = 'Klopt het: laat het weten en vink deze taak af.'
        AskNo        = "Klopt het niet, dan horen we graag twee dingen: wat er niet goed is, ${e}n wat er precies anders moet. Dan pakken we het opnieuw op in een volgende ronde."
    }
}

function ConvertFrom-GoLiveProse {
    <#
        Pure: the session's own prose for the block, out of the text of a -ProseFile.

        THE PROSE SECTIONS ARE THE SESSION'S TO WRITE, the derivable facts the script's (#2507). What
        changed, what else to look at, and what was deliberately left out are judgements about the work
        -- the same kind step 2 makes when it writes the task body -- so the script carries them into
        the shape and never composes them.

        A FILE AND NOT A PARAMETER, because the driver runs under 'powershell -File', where a string[]
        arrives as one string and a paragraph's newlines do not survive the command line at all. The
        file is read as UTF-8, which the colleague's language needs.

        THE FORMAT: a line '[changed]', '[where]', '[not-included]' or '[outcome]' opens a section; the
        lines under it, up to the next such line, are its text. Paragraphs are separated by a blank line
        and kept as written. Text above the first section line, and a section line this function does
        not know, are refused -- a misspelled heading that silently dropped a paragraph would ship a
        block missing the part the session wrote. '[outcome]' is the research block's one section
        (#3017). It was '[found]' until then (#3004), and that name is still read into the same
        section, so a prose file written for the old form is not refused. '[measure]', '[targets]',
        '[baseline]' and '[when]' are the measurement block's (#3179). Which sections a block may
        carry is the driver's question, not this parser's.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)

    $known   = @{ 'changed' = 'Changed'; 'where' = 'WhereToLook'; 'not-included' = 'NotIncluded'; 'outcome' = 'Outcome'; 'found' = 'Outcome'
                  'measure' = 'Measure'; 'targets' = 'Targets'; 'baseline' = 'Baseline'; 'when' = 'MeasureWhen' }
    $buckets = @{ Changed = @(); WhereToLook = @(); NotIncluded = @(); Outcome = @(); Measure = @(); Targets = @(); Baseline = @(); MeasureWhen = @() }
    $knownList = '[changed], [where], [not-included], [outcome], [measure], [targets], [baseline], [when]'
    $current = $null
    $lineNo  = 0
    foreach ($line in ($Text -split "`r?`n")) {
        $lineNo++
        # SECTION-SHAPED MEANS lowercase letters and hyphens, matched case-sensitively: a misspelled
        # '[chnaged]' is still refused, while prose that happens to put '[1]', '[ ]' or '[TBD]' on a
        # line of its own stays prose.
        if ($line -cmatch '^\s*\[([a-z][a-z-]*)\]\s*$') {
            $name = $Matches[1]
            if (-not $known.ContainsKey($name)) {
                throw "Prose line ${lineNo}: unknown section '[$name]'. Known: $knownList."
            }
            $current = $known[$name]
            continue
        }
        # THE BLOCK'S OWN BOUNDARIES MAY NOT APPEAR IN IT: a bare '---' line is a third rule, which cuts
        # the pasted block short, and an HTML comment would arrive in the colleague's ticket as junk --
        # the block's own marker being the one that matters.
        if ($line -match '^\s*---\s*$') { throw "Prose line ${lineNo}: a bare '---' line is the block's own rule and would cut the pasted block short." }
        if ($line.Contains('<!--')) { throw "Prose line ${lineNo}: an HTML comment would arrive in the Asana task as visible text." }
        if (-not $current) {
            if ($line.Trim()) { throw "Prose line ${lineNo}: text before the first section line ($knownList)." }
            continue
        }
        $buckets[$current] += $line
    }

    $result = @{}
    foreach ($key in @($buckets.Keys)) {
        # Paragraphs: runs of non-blank lines, joined with a newline so a hand-made list survives.
        $paras = @()
        $run   = @()
        foreach ($l in $buckets[$key]) {
            if ($l.Trim()) { $run += $l.TrimEnd() } elseif ($run.Count -gt 0) { $paras += ($run -join "`n"); $run = @() }
        }
        if ($run.Count -gt 0) { $paras += ($run -join "`n") }
        $result[$key] = $paras
    }
    return $result
}

function Get-GoLiveBlockAsk {
    <#
        Pure: the closing section of the pasted block -- what it asks of the requester (#2352).

        THE REQUESTER JUDGES THE RESULT, AND THEIR ANSWER CLOSES THE TASK. Not the gates, not the
        merge, not the session that built it: no gate proves that something looks right, so the block
        asks for the look instead of assuming it.

        A REJECTION ASKS FOR TWO THINGS -- what is not right yet AND what should change -- because the
        first alone hands the next round a guess. It then starts a new round.

        THE RELEASE IS NOT THE REWARD FOR AN APPROVAL. The work is already on the trunk, so it goes
        along either way; what the look buys is time, and the section says that rather than dangling a
        key the reader does not hold.

        ONLY WITH A LINK. Without one there is nothing to look at before the release, and an ask to
        judge a result the block cannot point at is noise -- the same rule as the omitted sentence.

        -Live: THE CHANGE IS ALREADY LIVE (#2943), so 'the last moment before a customer sees it' is
        false. The look still closes the task; only the sentence about the release goes.
    #>
    param(
        [string]$ResultLink,
        [ValidateSet('nl', 'en')][string]$Language = 'nl',
        [hashtable]$Text,
        [switch]$Live
    )
    if (-not $ResultLink) { return @() }
    $t = if ($Text) { $Text } else { Get-GoLiveBlockText -Language $Language }
    $look = if ($Live) { $t.AskLookLive } else { $t.AskLook }
    return @('', $t.Ask, '', $look, '', $t.AskYes, '', $t.AskNo)
}

function Get-GoLiveBlockLead {
    <#
        Pure: the framing sentence above the rules, read on GitHub and never carried to Asana.

        THE CLOSED MESSAGE CARRIES IT (#2818, Dave, October 5, 2026). The asana-mirror workflow did so
        from #2700/#2703 until it was retired that morning; the closed message was the one part brought
        back, as the asana-closed-message workflow, so the sentence says again that nobody pastes it.

        BUT ONLY WHERE THE ISSUE LINKS ITS TASK (#2918). The closed message finds the task through
        Resolve-AsanaTaskRef on the issue body, and posts nothing where that answers 'none' or
        'ambiguous'. Measured on BWJ-Development/xoxowildhearts#404: an Asana-originated issue with no
        link got the 'no paste needed' sentence, so everybody who read it was told the requester would
        hear, and the requester would have heard nothing. -AsanaLink names what the driver resolved;
        'linked' is the default, which keeps a caller that never resolved anything on today's sentence.
        'unchecked' is an issue the driver could not read, posted past that with -Force: the promise is
        made conditional rather than asserted without evidence.
    #>
    param([ValidateSet('linked', 'none', 'ambiguous', 'unchecked')][string]$AsanaLink = 'linked')
    switch ($AsanaLink) {
        'unchecked' { return 'If this issue links its Asana task, the closed message carries the block below into it when the issue closes as completed -- the link could not be checked:' }
        'none'      { return 'This issue links no Asana task, so nothing carries the block below into Asana when it closes -- link the task, or paste it there by hand:' }
        'ambiguous' { return 'This issue links more than one Asana task, so the closed message will not guess which one gets the block below -- mark the right one, or paste it there by hand:' }
    }
    return 'The closed message carries the block below into the Asana task when this issue closes as completed -- no paste needed:'
}

function Get-GoLivePostReadiness {
    <#
        Pure: whether the issue's work has reached a pull request, read from the issue's closing-PR
        references (GraphQL closedByPullRequestsReferences nodes, each with a 'state'). Returns 'merged'
        when any is merged, 'open' when one is open, and 'none' otherwise -- no reference, or only PRs
        closed without merging.

        WHY A PR AND NOT A LOOK (#2930). The block opens with 'is now closed' and names a release day, so
        posting it is only true once the work is on its way to the trunk. Measured on
        BWJ-Development/xoxowildhearts#402: -Post ran nine seconds after the preview handover, with no
        PR and the owner's look still open, and the owner asked why an unfinished issue had a closed
        message. A PR is the right evidence because a visible result opens none before the owner has
        looked (the constitution's merge rule), so an open PR already means the look is done.
    #>
    param([object[]]$Nodes = @())
    $states = @(@($Nodes) | Where-Object { $_ } | ForEach-Object { ([string]$_.state).ToUpperInvariant() })
    if ($states -contains 'MERGED') { return 'merged' }
    if ($states -contains 'OPEN')   { return 'open' }
    return 'none'
}

function Get-GoLiveLandingNodes {
    <#
        Pure: the pull requests that count as the issue's landing work, read from the landing query's
        'issue' object -- every closing reference, plus every pull request IN THE SAME REPO that
        cross-references the issue (timelineItems CROSS_REFERENCED_EVENT, source a PullRequest).

        WHY A REFERENCE COUNTS TOO (#2957). An Asana-linked issue ships with -NoResolves by this plugin's
        own rule (WORKFLOW-portable.md, the resolves gate; Get-ResolvesExemptMatchers refuses the closing
        keyword on one), so its pull request cites the issue and never closes it. Reading closing
        references alone refused -Post on exactly the issues the block exists for, and -Force became the
        ordinary path -- measured twice in BWJ-Development/smartwatchbanden on October 13, 2026. A PR
        that names the issue and is open or merged satisfies #2930's intent just as well.

        THE SAME REPO ONLY: a pull request elsewhere that mentions this issue is not this issue's work.
        A cross-reference from an issue carries no 'number' under the PullRequest fragment, and is dropped.
    #>
    param(
        [object]$IssueData,
        [Parameter(Mandatory = $true)][string]$Repo
    )
    if (-not $IssueData) { return @() }
    $nodes = @()
    $closing = $IssueData.PSObject.Properties['closedByPullRequestsReferences']
    if ($closing -and $closing.Value) { $nodes += @(@($closing.Value.nodes) | Where-Object { $_ }) }
    $timeline = $IssueData.PSObject.Properties['timelineItems']
    if ($timeline -and $timeline.Value) {
        foreach ($item in @(@($timeline.Value.nodes) | Where-Object { $_ })) {
            $source = $item.PSObject.Properties['source']
            if (-not $source -or -not $source.Value) { continue }
            $pr = $source.Value
            if (-not $pr.PSObject.Properties['number'] -or -not $pr.PSObject.Properties['state']) { continue }
            $prRepo = if ($pr.PSObject.Properties['repository'] -and $pr.repository) { [string]$pr.repository.nameWithOwner } else { '' }
            if ($prRepo -and $prRepo -ne $Repo) { continue }
            $nodes += [pscustomobject]@{ number = $pr.number; state = $pr.state }
        }
    }
    return $nodes
}

function Format-GoLiveClosedLine {
    <#
        Pure: the closed line, in Markdown -- the intro with the issue name as a link and the verb bold
        (#2700), and on the next line, with no blank line between, the line that tells the forms apart
        (#3069): the reopen invitation, or with -AfterRelease the same said of a result that becomes
        visible with the release, or with -Research that nothing changed, or with -Measure (#3179) that
        nothing changes visibly and the requester can measure it themselves.
        -IssueRef is 'owner/repo#<n>'; a bare number has no repo to link to and is refused.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$IssueRef,
        [hashtable]$Text,
        [switch]$AfterRelease,
        [switch]$Research,
        [switch]$Measure
    )
    if ($IssueRef -notmatch '^([^\s#/]+/[^\s#/]+)#(\d+)$') {
        throw "IssueRef '$IssueRef' is not 'owner/repo#<n>', so the closed line has no issue to link."
    }
    $url = "https://github.com/$($Matches[1])/issues/$($Matches[2])"
    $t = if ($Text) { $Text } else { Get-GoLiveBlockText }
    $second = if ($Measure) { $t.ClosedMeasure } elseif ($Research) { $t.ClosedResearch } elseif ($AfterRelease) { $t.ClosedRelease } else { $t.ClosedLive }
    return (($t.Closed -f $IssueRef, $url) + "`n" + $second)
}

function Format-GoLiveBlock {
    <#
        Pure: the whole GitHub comment -- the marker, the framing sentence that stays on GitHub, and
        the block between the two '---' rules that a colleague can paste into the Asana task.

        THE BLOCK'S SHAPE (#2700): the header and closed line, then up to five sections under fixed
        headings -- where to look (first, Dave's order), what changed, when it goes live, what is
        deliberately not in it, and what we ask. The words follow -Language, which is the colleague's
        (Get-GoLiveBlockText). The framing sentence above the rules stays English: it is read on
        GitHub, not pasted.

        THE MARKER SITS OUTSIDE THE BLOCK. Everything between the rules may be pasted into a
        colleague's ticket, so a marker in there would arrive as visible junk. It is passed IN rather
        than hard-coded, so this file and asana-task-lib.ps1's duplicate check cannot end up holding two
        spellings of one string -- the driver reads Get-AsanaPasteBlockMarker and hands it over. That
        check matches the marker and nothing inside the rules, so the block's own words are free to
        follow the colleague.

        WHAT IS OPTIONAL, AND WHAT HAPPENS WHERE IT IS ABSENT -- a section with nothing to say is not
        written, heading included, never placeholdered:

          -Changed      the session's prose. Omitted -> no 'what changed' section (the driver warns).
          -ResultLink   omitted -> no link sentence, never a placeholder: a session running this
                        script knows the link.
          -WhereToLook  the session's prose under the link: steps, what to look for. With neither it
                        nor -ResultLink, the 'where to look' section is not written.
          -Version      omitted -> the release sentence names the day and no number.
          -LiveUrl      empty   -> no live-URL list. A repo that has declared no storefront markets
                        has nothing truthful to put there.
          -NotIncluded  the session's prose. Omitted -> no 'deliberately not in it' section.

        The 'when it goes live' section is always written: the date is always derivable.

        -Live: -GoLiveDate is the day it WENT live, not a planned one (#2943). The section then says
        'live since', the live-URL list loses its before-the-release caveat, and the ask loses its
        last-moment sentence. Measured on BWJ-Development/xoxowildhearts#190: its work went live in a
        separate per-file push before the close, and the block would have named the next Monday.

        WITHOUT -Live THE RESULT IS VISIBLE ONLY AFTER THE RELEASE (#3069), so the closed line's second
        line says so, and -ReleaseMarker (Get-AsanaReleaseBlockMarker, passed in for the reason the
        marker is) sits beside the marker so the closed message can say the same. Omitted, the block
        carries no second marker and the closed message keeps its plain reopen line.

        THE LIVE LIST IS READ BEFORE THE RELEASE, AND A BARE URL LIES THEN (#2477). The result link is
        normally a storefront PREVIEW, which sets a per-domain cookie, and a bare storefront URL keeps
        rendering that preview once it has been opened -- the trap PREVIEW-portable.md measured. So a
        requester who opens the result and then a live URL sees the change in both tabs and can
        conclude it is already live. So beside a result link the list's label carries that caveat:
        before the release, open these in a private window.

        AND THE URLS STAY BARE, WHICH IS THE CORRECTION OF #2477's FIRST REPAIR (#2619). That repair
        pinned every row to the live theme id (?preview_theme_id=<live id>), which is technically a
        true comparison -- and the one thing the block's reader checks is the URL's shape, which then
        says 'preview' under a label saying 'live'. Measured on BWJ-Development/smartwatchbanden#396:
        the owner rejected the block for exactly that, and rewrote it with bare URLs and this caveat.
        The reader is a colleague, not a developer, so the caveat goes in words and the URL stays one
        they recognise.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Marker,
        [Parameter(Mandatory = $true)][string]$IssueRef,
        [Parameter(Mandatory = $true)][string]$GoLiveDate,
        [string]$ResultLink,
        [string]$Version,
        [object[]]$LiveUrl = @(),
        [ValidateSet('nl', 'en')][string]$Language = 'nl',
        [string[]]$Changed = @(),
        [string[]]$WhereToLook = @(),
        [string[]]$NotIncluded = @(),
        # What the driver resolved the issue's Asana link to (#2918); the lead follows it.
        [ValidateSet('linked', 'none', 'ambiguous', 'unchecked')][string]$AsanaLink = 'linked',
        [switch]$Live,
        [string]$ReleaseMarker = ''
    )

    $t    = Get-GoLiveBlockText -Language $Language
    $dash = [string][char]0x2014

    $lines = @($Marker)
    if (-not $Live -and $ReleaseMarker) { $lines += $ReleaseMarker }
    $lines += @(
        '',
        (Get-GoLiveBlockLead -AsanaLink $AsanaLink),
        '',
        '---',
        $t.Header,
        '',
        (Format-GoLiveClosedLine -IssueRef $IssueRef -Text $t -AfterRelease:(-not $Live))
    )

    # One section: a blank line, the heading, a blank line, then its paragraphs a blank line apart.
    $addSection = {
        param([string]$Heading, [string[]]$Paragraphs)
        $out = @('', $Heading)
        foreach ($p in $Paragraphs) { $out += ''; $out += $p }
        return , $out
    }

    # WHERE TO LOOK COMES FIRST (Dave, #2700): it is what the requester acts on, so it leads.
    $whereParas = @()
    if ($ResultLink) { $whereParas += ($t.ResultLink -f $ResultLink) }
    $whereParas += @($WhereToLook | Where-Object { $_ -and $_.Trim() })
    if ($whereParas.Count -gt 0) { $lines += & $addSection $t.Where $whereParas }

    $changedParas = @($Changed | Where-Object { $_ -and $_.Trim() })
    if ($changedParas.Count -gt 0) { $lines += & $addSection $t.Changed $changedParas }

    $whenParas = @(
        if ($Live) { if ($Version) { $t.LiveSinceVer -f $GoLiveDate, $Version } else { $t.LiveSince -f $GoLiveDate } }
        elseif ($Version) { $t.ReleaseVer -f $GoLiveDate, $Version } else { $t.ReleaseDay -f $GoLiveDate }
    )
    $rows = @($LiveUrl | Where-Object { $_ })
    if ($rows.Count -gt 0) {
        $label = if ($Live) { $t.LiveNow } elseif ($ResultLink) { $t.LiveBare } else { $t.LiveNoLink }
        $list = @(foreach ($row in $rows) {
            $market = if ($row.PSObject.Properties['Market'] -and $row.Market) { [string]$row.Market } else { 'live' }
            "$market $dash $($row.Url)"
        })
        $whenParas += $label
        $whenParas += ($list -join "`n")
    }
    $lines += & $addSection $t.When $whenParas

    $notParas = @($NotIncluded | Where-Object { $_ -and $_.Trim() })
    if ($notParas.Count -gt 0) { $lines += & $addSection $t.NotIncluded $notParas }

    $lines += Get-GoLiveBlockAsk -ResultLink $ResultLink -Text $t -Live:$Live
    # THE BLANK LINE BEFORE THE CLOSING RULE IS LOAD-BEARING (#2701): a text line directly above '---'
    # is a setext H2 in Markdown, so without it GitHub rendered the block's last paragraph as a heading.
    $lines += ''
    $lines += '---'

    return ($lines -join "`n")
}

function Format-GoLiveResearchBlock {
    <#
        Pure: the whole GitHub comment for a ticket WITHOUT a storefront result -- research, a test, a
        decision (#3004) -- in the general form Maikel set on smartwatchbanden#944's task, October 14,
        2026 (#3017): the header, the intro every completed close shares ('is now closed: this Asana task
        is now in review.') with 'Nothing has changed. Read the outcome below.' under it (#3069), then
        the heading OUTCOME and the outcome as bullets.

        ONLY WHEN NOTHING CHANGED, ON THE STORE OR IN THE REPO (#3069). A store-admin act that is already
        live -- a metaobject, a metafield value, a setting -- changed the store, so it takes
        Format-GoLiveBlock with -Live. Measured on smartwatchbanden#395, where this form was used for a
        metaobject that changed the live structured data, and the requester rejected it.

        THE OUTCOME IS THE MESSAGE, NOT A LINK TO IT. Not every requester can open the GitHub repo, so
        a pointer to the issue's conclusion explains nothing (Maikel's correction on #3004); -Outcome
        is the session's prose and is required, because a research block without it says nothing.

        EVERY FIXED LINE FITS EVERY TICKET (#3017): 'as general as possible', so only the bullets carry
        what belongs to this task. Each paragraph is one bullet, and a hand-made list inside one keeps
        its items (ConvertTo-GoLiveOutcomeBullets).

        NO RELEASE DAY, NO LIVE URLS: nothing changed on the store, so there is no day it goes live and
        nothing to look at. The closing ask ('Is anything still unclear? ...') is not in the block: it
        names the board's own done section, which only the closed message can read, so that message
        composes it. The marker and the lead stay as Format-GoLiveBlock writes them, and
        -ResearchMarker sits beside the marker so the closed message can tell this block from a result
        block and write the research closed line. Both are passed IN, for the reason Format-GoLiveBlock
        gives: one spelling, held by asana-task-lib.ps1.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Marker,
        [Parameter(Mandatory = $true)][string]$ResearchMarker,
        [Parameter(Mandatory = $true)][string]$IssueRef,
        [Parameter(Mandatory = $true)][Alias('Found')][string[]]$Outcome,
        [ValidateSet('nl', 'en')][string]$Language = 'nl',
        [ValidateSet('linked', 'none', 'ambiguous', 'unchecked')][string]$AsanaLink = 'linked'
    )

    $bullets = @(ConvertTo-GoLiveOutcomeBullets -Paragraphs $Outcome)
    if ($bullets.Count -eq 0) { throw 'A research block needs its outcome: -Outcome is empty.' }
    $t   = Get-GoLiveBlockText -Language $Language

    $lines = @(
        $Marker,
        $ResearchMarker,
        '',
        (Get-GoLiveBlockLead -AsanaLink $AsanaLink),
        '',
        '---',
        $t.Header,
        '',
        (Format-GoLiveClosedLine -IssueRef $IssueRef -Text $t -Research),
        '',
        $t.Outcome
    )
    # The bullets follow the heading with no blank line, one per line, so GitHub renders one list and the
    # closed message turns the run into one <ul> (#3017).
    foreach ($b in $bullets) { $lines += "- $b" }
    # The blank line before the closing rule is load-bearing, as in Format-GoLiveBlock (#2701).
    $lines += ''
    $lines += '---'
    return ($lines -join "`n")
}

function Format-GoLiveMeasureBlock {
    <#
        Pure: the whole GitHub comment for a ticket whose result is a NUMBER the requester can measure
        again -- a page-speed target after a performance fix, a conversion rate, a ranking (#3179,
        Maikel, October 19, 2026). The header, the shared completed intro, and under it 'Nothing changes
        visibly on the storefront. You can take a new measurement yourself, as described below.', then
        up to four sections in the task's language: how to measure (required), the targets (required),
        the last measurement, and when to measure.

        NEITHER OF THE OTHER TWO FORMS FITS, AND NEITHER IS A STAND-IN. The go-live form points at a page
        where nothing visible changed, and the research form says 'Nothing has changed', which is false:
        the store did change, only its effect is invisible. Measured on smartwatchbanden#919, closed with
        -Research for want of this form, whose message the requester removed by hand (#3069).

        THE REQUESTER MEASURES, NOT A DEV SESSION (#3177): the block tells them how, against which
        targets, and with what to compare. The closing ask ('Is the target met? ...') names the board's
        own done section, which only the closed message can read, so that message composes it, exactly
        as for the research form. -MeasureMarker sits beside the marker so the closed message can tell
        this block from the other two; both are passed IN, for the reason Format-GoLiveBlock gives.

        A '- ' line inside a section stays a list item, so steps can be numbered by the session as it
        likes and the closed message renders the run as one list.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Marker,
        [Parameter(Mandatory = $true)][string]$MeasureMarker,
        [Parameter(Mandatory = $true)][string]$IssueRef,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Measure,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Targets,
        [AllowEmptyCollection()][string[]]$Baseline = @(),
        [AllowEmptyCollection()][string[]]$When = @(),
        [ValidateSet('nl', 'en')][string]$Language = 'nl',
        [ValidateSet('linked', 'none', 'ambiguous', 'unchecked')][string]$AsanaLink = 'linked'
    )

    $how  = @(@($Measure) | Where-Object { $_ -and $_.Trim() })
    $goal = @(@($Targets) | Where-Object { $_ -and $_.Trim() })
    if ($how.Count -eq 0)  { throw 'A measurement block needs how to measure: -Measure is empty.' }
    if ($goal.Count -eq 0) { throw 'A measurement block needs its targets: -Targets is empty.' }
    $t = Get-GoLiveBlockText -Language $Language

    $lines = @(
        $Marker,
        $MeasureMarker,
        '',
        (Get-GoLiveBlockLead -AsanaLink $AsanaLink),
        '',
        '---',
        $t.Header,
        '',
        (Format-GoLiveClosedLine -IssueRef $IssueRef -Text $t -Measure)
    )
    foreach ($s in @(
        @{ Heading = $t.Measure;     Paras = $how },
        @{ Heading = $t.Targets;     Paras = $goal },
        @{ Heading = $t.Baseline;    Paras = @(@($Baseline) | Where-Object { $_ -and $_.Trim() }) },
        @{ Heading = $t.MeasureWhen; Paras = @(@($When) | Where-Object { $_ -and $_.Trim() }) }
    )) {
        if (@($s.Paras).Count -eq 0) { continue }
        $lines += ''
        $lines += $s.Heading
        foreach ($p in $s.Paras) { $lines += ''; $lines += $p }
    }
    # The blank line before the closing rule is load-bearing, as in Format-GoLiveBlock (#2701).
    $lines += ''
    $lines += '---'
    return ($lines -join "`n")
}

function ConvertTo-GoLiveOutcomeBullets {
    <#
        Pure: the research block's outcome prose as bullet texts, without their markers (#3017). Each
        paragraph is one bullet, its lines joined by a space. A line that already opens with '- ' or '* '
        is a bullet of its own, so a list the session wrote by hand keeps its items rather than being
        folded into one. Blank and marker-only lines are dropped.
    #>
    param([AllowEmptyCollection()][string[]]$Paragraphs = @())

    $out = New-Object System.Collections.Generic.List[string]
    foreach ($p in @($Paragraphs)) {
        $run = @()
        foreach ($line in (([string]$p) -split "`r?`n")) {
            $text = $line.Trim()
            if (-not $text) { continue }
            if ($text -match '^[-*](\s+(.*))?$') {
                if ($run.Count -gt 0) { $out.Add(($run -join ' ')); $run = @() }
                if ($Matches[2]) { $out.Add($Matches[2].Trim()) }
                continue
            }
            $run += $text
        }
        if ($run.Count -gt 0) { $out.Add(($run -join ' ')) }
    }
    return @($out)
}