<#
.SYNOPSIS
    The decisions behind the go-live half of the paste-ready block -- which day the next release
    falls on, which version it is currently on course for, and the text the block becomes. Pure: no
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
    facts: the next release day, the version that release will carry, and the live storefront URLs.

    EVERY ONE OF THE THREE IS A PROJECTION, AND THE WORDING SAYS SO. A tier-1 entry landing on the
    Friday turns a predicted patch into a minor; a release can slip. 'Het staat gepland' / 'planned
    to go live' is therefore the wording, never 'will' -- this block is the one surface a colleague quotes back, so
    a cadence must not read there as a commitment anybody made.

    AND A FACT THAT CANNOT BE DERIVED IS LEFT OUT, NEVER GUESSED. No version resolves to a sentence
    with no number in it, not to a plausible one; no live URLs resolve to no list at all. That is
    the same reasoning that makes the RESULT link a person's answer rather than a derived one
    (WORKFLOW-portable.md's own paragraph on the backstop's [ADD LINK] placeholder), applied one
    paragraph further down.

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

function Get-GoLiveBlockText {
    <#
        Pure: the fixed words of the pasted block, in the language it is written in (#2507).

        THE BLOCK IS WRITTEN IN THE COLLEAGUE'S LANGUAGE, BECAUSE IT IS ADDRESSED TO THEM.
        WORKFLOW-portable.md step 2 turns the language over at exactly this boundary -- English on
        GitHub, the colleague's own language on the board -- and the paste block was the one
        colleague-facing text whose words a script had fixed in English. Measured on
        BWJ-Development/smartwatchbanden#769 (September 25, 2026): the English printout was rejected by
        the owner, pointing at the Dutch block BWJ had actually sent a colleague, and rewritten by hand.

        THE SHAPE IS THAT BLOCK'S: an opening line saying where the message comes from, then five
        fixed headings. The Dutch words are the reference comment's own; the English ones are its
        translation, for a task written in English.

        Non-ASCII characters are composed from code points, because this file is read by Windows
        PowerShell 5.1 as the system ANSI code page (language-layers.md).
    #>
    param([ValidateSet('nl', 'en')][string]$Language = 'nl')

    $dash = [string][char]0x2014
    $e    = [string][char]0x00E9

    if ($Language -eq 'en') {
        return @{
            Header       = "$dash automated message from GitHub #{0}"
            Changed      = 'WHAT IS DIFFERENT NOW'
            Where        = 'WHERE TO LOOK'
            When         = 'WHEN IT GOES LIVE'
            NotIncluded  = 'WHAT IS DELIBERATELY NOT IN IT'
            Ask          = 'WHAT WE ASK OF YOU'
            ResultLink   = 'You can view the result here: {0}'
            ReleaseDay   = 'It is planned to go live with the release of {0}.'
            ReleaseVer   = 'It is planned to go live with the release of {0}, as version v{1}.'
            LivePinned   = "Until then, these links show what is live now, to compare against $dash and once it is live, you can see the change here:"
            LiveNoLink   = 'Once it is live you can see it here:'
            LiveBare     = 'Once it is live you can see it here. Before then, open these in a private window: a browser that has opened the result link keeps showing the result on these pages, not what is live.'
            AskLook      = 'Look at the result yourself, at the link above. It goes live with that release either way, so this is the last moment something can still change before a customer sees it.'
            AskYes       = 'Is it right? Say so, and tick off this task.'
            AskNo        = 'Is it not? Then we would like to hear two things: what is not right yet, and what exactly should change. The issue is then reopened for a new round.'
        }
    }
    return @{
        Header       = "$dash automatisch bericht vanuit GitHub #{0}"
        Changed      = 'WAT ER NU ANDERS IS'
        Where        = 'TE BEKIJKEN OP'
        When         = 'WANNEER HET LIVE KOMT'
        NotIncluded  = 'WAT ER BEWUST NIET IN ZIT'
        Ask          = 'WAT WE VAN JE VRAGEN'
        ResultLink   = 'Het resultaat is hier te bekijken: {0}'
        ReleaseDay   = 'Het staat gepland voor de release van {0}.'
        ReleaseVer   = 'Het staat gepland voor de release van {0}, als versie v{1}.'
        LivePinned   = "Tot die tijd laten deze links zien wat er nu live staat, om mee te vergelijken $dash en zodra het live is, zie je de wijziging hier:"
        LiveNoLink   = 'Zodra het live is, zie je het hier:'
        LiveBare     = "Zodra het live is, zie je het hier. Open ze tot die tijd in een priv${e}venster: een browser die de link hierboven al heeft geopend, blijft op deze pagina's het resultaat tonen en niet wat er live staat."
        AskLook      = 'Bekijk het resultaat zelf, via de link hierboven. Het gaat hoe dan ook mee met die release, dus dit is het laatste moment waarop er nog iets aan te passen valt voordat een klant het ziet.'
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

        THE FORMAT: a line '[changed]', '[where]' or '[not-included]' opens a section; the lines under
        it, up to the next such line, are its text. Paragraphs are separated by a blank line and kept
        as written. Text above the first section line, and a section line this function does not know,
        are refused -- a misspelled heading that silently dropped a paragraph would ship a block
        missing the part the session wrote.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)

    $known   = @{ 'changed' = 'Changed'; 'where' = 'WhereToLook'; 'not-included' = 'NotIncluded' }
    $buckets = @{ Changed = @(); WhereToLook = @(); NotIncluded = @() }
    $current = $null
    $lineNo  = 0
    foreach ($line in ($Text -split "`r?`n")) {
        $lineNo++
        if ($line -match '^\s*\[([^\]]+)\]\s*$') {
            $name = $Matches[1].Trim().ToLowerInvariant()
            if (-not $known.ContainsKey($name)) {
                throw "Prose line ${lineNo}: unknown section '[$name]'. Known: [changed], [where], [not-included]."
            }
            $current = $known[$name]
            continue
        }
        if (-not $current) {
            if ($line.Trim()) { throw "Prose line ${lineNo}: text before the first section line ([changed], [where] or [not-included])." }
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
    #>
    param(
        [string]$ResultLink,
        [ValidateSet('nl', 'en')][string]$Language = 'nl'
    )
    if (-not $ResultLink) { return @() }
    $t = Get-GoLiveBlockText -Language $Language
    return @('', $t.Ask, '', $t.AskLook, '', $t.AskYes, '', $t.AskNo)
}

function Format-GoLiveBlock {
    <#
        Pure: the whole GitHub comment -- the marker, the framing sentence that stays on GitHub, and
        the block between the two '---' rules that travels into the Asana task.

        THE BLOCK HAS THE SHAPE BWJ ACTUALLY SENDS (#2507): an opening line naming where it comes from,
        then up to five sections under fixed headings -- what changed, where to look, when it goes live,
        what is deliberately not in it, and what we ask. The words follow -Language, which is the
        colleague's (Get-GoLiveBlockText). The framing sentence above the rules stays English: it is
        read on GitHub, not pasted.

        THE MARKER SITS OUTSIDE THE BLOCK. Everything between the rules is pasted into a colleague's
        ticket, so a marker in there would arrive as visible junk. It is passed IN rather than
        hard-coded, so this file and asana-mirror.ps1's backstop cannot end up holding two spellings
        of one string -- the driver reads Get-AsanaPasteBlockMarker and hands it over. The backstop's
        de-duplication matches that marker and nothing inside the rules, so the block's own words are
        free to follow the colleague.

        WHAT IS OPTIONAL, AND WHAT HAPPENS WHERE IT IS ABSENT -- a section with nothing to say is not
        written, heading included, never placeholdered:

          -Changed      the session's prose. Omitted -> no 'what changed' section (the driver warns).
          -ResultLink   omitted -> no link sentence. This function never writes the backstop's
                        [ADD LINK] placeholder: that placeholder exists because CI cannot know the
                        link, and a session running this script can.
          -WhereToLook  the session's prose under the link: steps, what to look for. With neither it
                        nor -ResultLink, the 'where to look' section is not written.
          -Version      omitted -> the release sentence names the day and no number.
          -LiveUrl      empty   -> no live-URL list. A repo that has declared no storefront markets
                        has nothing truthful to put there.
          -LivePinned   whether the -LiveUrl rows name the live theme id. It decides the list's label,
                        and the label is the repair of issue #2477 (see below).
          -NotIncluded  the session's prose. Omitted -> no 'deliberately not in it' section.

        The 'when it goes live' section is always written: the date is always derivable.

        THE LIVE LIST IS READ BEFORE THE RELEASE, AND A BARE URL LIES THEN (#2477). The result link is
        normally a storefront PREVIEW, which sets a per-domain cookie, and a bare storefront URL keeps
        rendering that preview once it has been opened -- the trap PREVIEW-portable.md measured. So a
        requester who opens the result and then a live URL sees the change in both tabs and can
        conclude it is already live. Pinned to the live id, the same URL is a true comparison now and
        the live page after the release (a live push keeps the theme's id), so it is labelled as both.
        Unpinned, the list says when it cannot be trusted, and how to read it anyway.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Marker,
        [Parameter(Mandatory = $true)][string]$IssueRef,
        [Parameter(Mandatory = $true)][string]$GoLiveDate,
        [string]$ResultLink,
        [string]$Version,
        [object[]]$LiveUrl = @(),
        [switch]$LivePinned,
        [ValidateSet('nl', 'en')][string]$Language = 'nl',
        [string[]]$Changed = @(),
        [string[]]$WhereToLook = @(),
        [string[]]$NotIncluded = @()
    )

    $t      = Get-GoLiveBlockText -Language $Language
    $number = if ($IssueRef -match '#(\d+)\s*$') { $Matches[1] } else { $IssueRef }
    $dash   = [string][char]0x2014

    $lines = @(
        $Marker,
        '',
        'Paste the block into the Asana task, so the requester knows where to look and when it lands:',
        '',
        '---',
        ($t.Header -f $number)
    )

    # One section: a blank line, the heading, a blank line, then its paragraphs a blank line apart.
    $addSection = {
        param([string]$Heading, [string[]]$Paragraphs)
        $out = @('', $Heading)
        foreach ($p in $Paragraphs) { $out += ''; $out += $p }
        return , $out
    }

    $changedParas = @($Changed | Where-Object { $_ -and $_.Trim() })
    if ($changedParas.Count -gt 0) { $lines += & $addSection $t.Changed $changedParas }

    $whereParas = @()
    if ($ResultLink) { $whereParas += ($t.ResultLink -f $ResultLink) }
    $whereParas += @($WhereToLook | Where-Object { $_ -and $_.Trim() })
    if ($whereParas.Count -gt 0) { $lines += & $addSection $t.Where $whereParas }

    $whenParas = @(if ($Version) { $t.ReleaseVer -f $GoLiveDate, $Version } else { $t.ReleaseDay -f $GoLiveDate })
    $rows = @($LiveUrl | Where-Object { $_ })
    if ($rows.Count -gt 0) {
        $label = if ($LivePinned) { $t.LivePinned } elseif (-not $ResultLink) { $t.LiveNoLink } else { $t.LiveBare }
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

    $lines += Get-GoLiveBlockAsk -ResultLink $ResultLink -Language $Language
    $lines += '---'

    return ($lines -join "`n")
}
