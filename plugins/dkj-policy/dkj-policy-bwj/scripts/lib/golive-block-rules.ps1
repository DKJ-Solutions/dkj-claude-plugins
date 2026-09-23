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
    Friday turns a predicted patch into a minor; a release can slip. 'Planned to go live' is
    therefore the wording, never 'will' -- this block is the one surface a colleague quotes back, so
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
        Pure: the release date as a colleague reads it -- 'Monday 22 September 2026'.

        INVARIANT CULTURE, DELIBERATELY. Everything this workflow writes into a ticket is English --
        it is the workflow speaking, not the subject, which is the boundary asana-mirror.ps1's own
        header already draws -- and a machine's locale must not decide which language a colleague's
        ticket is written in.
    #>
    param([Parameter(Mandatory = $true)][datetime]$Date)
    return $Date.ToString('dddd d MMMM yyyy', [System.Globalization.CultureInfo]::InvariantCulture)
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

function Get-GoLiveBlockAsk {
    <#
        Pure: the closing section of the pasted block -- what it asks of the requester (#2352).

        THE REQUESTER JUDGES THE RESULT, AND THEIR ANSWER CLOSES THE TASK. Not the gates, not the
        merge, not the session that built it: no gate proves that something looks right, so the block
        asks for the look instead of assuming it.

        A REJECTION ASKS FOR TWO THINGS -- what is not right yet AND what should change -- because the
        first alone hands the next round a guess. It then reopens the issue.

        THE RELEASE IS NOT THE REWARD FOR AN APPROVAL. The work is already on the trunk, so it goes
        along either way; what the look buys is time, and the section says that rather than dangling a
        key the reader does not hold.

        ONLY WITH A LINK. Without one there is nothing to look at before the release, and an ask to
        judge a result the block cannot point at is noise -- the same rule as the omitted sentence.
    #>
    param([string]$ResultLink)
    if (-not $ResultLink) { return @() }
    return @(
        '',
        'What we ask of you:',
        'Look at the result yourself, at the link above. It goes live with that release either way, so this is the last moment something can still change before a customer sees it.',
        '- Is it right? Say so, and tick off this task.',
        '- Is it not? Tell us two things: what is not right yet, and what exactly should change. The issue is then reopened for a new round.'
    )
}

function Format-GoLiveBlock {
    <#
        Pure: the whole GitHub comment -- the marker, the framing sentence that stays on GitHub, and
        the block between the two '---' rules that travels into the Asana task.

        THE MARKER SITS OUTSIDE THE BLOCK. Everything between the rules is pasted into a colleague's
        ticket, so a marker in there would arrive as visible junk. It is passed IN rather than
        hard-coded, so this file and asana-mirror.ps1's backstop cannot end up holding two spellings
        of one string -- the driver reads Get-AsanaPasteBlockMarker and hands it over.

        WHAT IS OPTIONAL, AND WHAT HAPPENS WHERE IT IS ABSENT:

          -ResultLink   omitted -> the 'you can view the result here' sentence is not written at
                        all. This function never writes the backstop's [ADD LINK] placeholder: that
                        placeholder exists because CI cannot know the link, and a session running
                        this script can.
          -Version      omitted -> the release sentence names the day and no number.
          -LiveUrl      empty   -> no live-URL list. A repo that has declared no storefront markets
                        has nothing truthful to put there.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Marker,
        [Parameter(Mandatory = $true)][string]$IssueRef,
        [Parameter(Mandatory = $true)][string]$GoLiveDate,
        [string]$ResultLink,
        [string]$Version,
        [object[]]$LiveUrl = @()
    )

    $release = if ($Version) {
        "Planned to go live with the release of $GoLiveDate, as version v$Version."
    } else {
        "Planned to go live with the release of $GoLiveDate."
    }

    $lines = @(
        $Marker,
        '',
        'Paste the block into the Asana task, so the requester knows where to look and when it lands:',
        '',
        '---'
    )
    $lines += if ($ResultLink) {
        "The fix for $IssueRef is done. You can view the result here: $ResultLink"
    } else {
        "The fix for $IssueRef is done."
    }
    $lines += ''
    $lines += $release

    $rows = @($LiveUrl | Where-Object { $_ })
    if ($rows.Count -gt 0) {
        $lines += 'Once it is live you can see it here:'
        $lines += ''
        foreach ($row in $rows) {
            $label = if ($row.PSObject.Properties['Market'] -and $row.Market) { [string]$row.Market } else { 'live' }
            $lines += "- $label -- $($row.Url)"
        }
    }
    $lines += Get-GoLiveBlockAsk -ResultLink $ResultLink
    $lines += '---'

    return ($lines -join "`n")
}
