<#
.SYNOPSIS
    Keep a BWJ store repo and its Asana board in step -- the CI half of the dkj-policy-bwj rule. It posts
    an update on the Asana task mirrored from a GitHub issue, moves that task to the board section
    its GitHub state has reached, and carries the task's prio score back the other way as a label on
    the issue. Copied into a BWJ store repo as .github/scripts/asana-mirror.ps1 and driven by
    .github/workflows/asana-mirror.yml.

.DESCRIPTION
    IT NEVER COMPLETES A TASK, AND THERE IS NO CODE PATH THAT CAN (Dave, September 1, 2026). Closing
    a GitHub issue says the work is built; it does not say the colleague who asked for it has seen it
    work. Only that person resolves their own ticket, after testing. So this script writes two kinds
    of thing into Asana -- a comment, and which section a task sits in -- and the 'completed' field is
    not written anywhere in it.

    THE SECTION MOVE IS THAT SAME GUARANTEE IN THE BOARD'S OWN CURRENCY, so it carries its own
    ceiling: the two ends of the board are never written. 'Requests' is the submitter's untriaged
    inbox and 'Completed' is their verdict that the work is good -- Test-StageIsWritable is the pure
    guard that says so.

    AND TWO SECTIONS ARE TERMINAL, not just one (Dave, September 2, 2026): a card sitting in
    'ReadyToTest' or 'Completed' is never moved out of it by this script, because both mean the
    submitter is holding the card. That outranks even the reopen, which everywhere else earns a
    backward move -- if the work turns out not to be done, the person holding it moves it, and having
    it pulled back out from under them by the next sweep is the failure this guard names. See
    Test-StageIsTerminal.

    THE THREE MIDDLE STAGES ARE THE GITHUB PROJECT'S THREE STATUSES, and always in sync with them
    (Dave, September 2, 2026). Filed / InDevelopment / InReview are Todo / In Progress / Done, read
    off the project board rather than re-derived from the issue and its pull requests -- GitHub's own
    built-in project workflows already write that field, and deriving it twice made two writers of
    one fact. Get-GithubStatusMap is the seam; Get-DefaultGithubStatusMap is the fallback.

    READYTOTEST IS THE ONE STAGE NO STATUS CAN REACH, and it is entered on FEEDBACK instead: the
    issue is closed AND the submitter named in the task's notes has actually been told, which is this
    script's own close update. Where a ticket has no submitter -- nobody else asked for it -- stage 6
    is skipped entirely and the owner accepts it into Completed by hand. A repo that names no
    SubmitterPattern can never tell, so there the promotion never fires at all, which is the
    fail-safe direction.

    WHICH NUMBERED SECTION EACH STAGE IS comes from the repo, not from this file: Get-AsanaStageMap in
    scripts/repo-config.ps1, with Get-DefaultAsanaStageMap as the fallback. That seam exists because
    the meanings were literals here for exactly one afternoon (September 2, 2026) and the board they
    were written against grew a section the same day, shifting every stage above it by one. Nothing
    failed loudly; every card would have been filed a column early. A section the map does not name is
    now a hold -- not a target, and not a source.

    MOVES ARE FORWARD, so a card a session advanced by hand is never dragged back by a sweep that can
    see less than the session could. Exactly two answers may go backward, and both are a person
    saying something rather than CI inferring it: the needs-info label, which declares the work
    blocked on the submitter and outranks whatever the branch and the pull request are doing, and the
    reopen event, which is a real state change.

    The one thing it writes OUTSIDE Asana is a prio label on a GitHub issue -- sweep (c) below. That
    is a different system and a different claim, and it leaves the guarantee above exactly where it
    was: nothing about a label says anybody has tested anything.

    Two modes:

      -Mode event      One issue changed. -Event is 'closed', 'reopened', 'labeled' or 'unlabeled';
                       -IssueBody is the issue body (the Asana task is resolved from it, see below);
                       -IssueRef is 'owner/repo#n'.

                       'closed' and 'reopened' COMMENT and move the card. The comment on 'closed'
                       names the pull request(s) that closed the issue and says the work is ready to
                       test; 'reopened' says to hold off. Neither de-duplicates -- an event is a real
                       state change, and a second close after a reopen is news again.

                       'labeled' and 'unlabeled' ONLY move the card, deliberately: a label going on
                       or off is a change in our state, and narrating it would put a comment on the
                       submitter's ticket every time somebody triaged the issue.

      -Mode reconcile  Four sweeps, for events that never arrived, and the only place de-duplication
                       applies:
                       (a) Asana -> GitHub: the project's incomplete tasks, reading a GitHub issue
                           URL from each task's notes and commenting when that issue is closed.
                       (b) GitHub -> Asana: this repo's issues closed in the last -SinceDays days,
                           resolving each body's Asana task and commenting on it. Covers a ticket
                           that came the other way -- imported FROM Asana, whose task carries no
                           back-link for (a) to find.
                       Both skip a task that is already complete (a person resolved it -- leave it
                       alone) and a task that already carries this issue's close update.
                       (c) Asana -> GitHub, LABELS: this repo's OPEN issues, each given the one prio
                           label that matches its task's Prio-Score. Walks GitHub rather than the
                           project, so it reaches an imported ticket too and needs no
                           ASANA_PROJECT_GID at all.
                       (d) GitHub -> Asana, SECTIONS: this repo's issues, open and recently closed,
                           each card moved to the stage its issue's state has reached. This one is
                           not a backstop like (a) and (b): stages 2, 3 and 4 have no GitHub event
                           this workflow subscribes to, so for three of the four writable stages the
                           daily sweep IS the mechanism. It needs no ASANA_PROJECT_GID either -- the
                           board is read off the task's own memberships, see below.

    How the Asana task is found -- Resolve-AsanaTaskRef, three matchers tried in this order:

      1. marker      the machine marker '<!-- asana-task: <digits> -->' the report-issue skill
                     writes. Authoritative: an issue that carries one is never matched any other way.
      2. header-row  the header row of an imported ticket -- a markdown table row whose first cell
                     is '**Asana**' -- carrying an Asana task URL. This is the intake shape: a
                     ticket copied out of Asana links its task for a reader, not for a machine.
      3. sole-url    exactly one Asana task URL anywhere else in the body.

    More than one DIFFERENT task in matcher 3 is reported as 'ambiguous' and skipped: the script never
    guesses which ticket an issue belongs to. Add a marker to settle it.

    How the BOARD is found -- Select-StageMembership, and it is deliberately not a configured GID.
    A task carries one section per project it is in, so the script reads the task's memberships and
    takes the one whose section name begins with a stage number ('3. ...'). The number is the
    machine-readable half and the words after it are the board's own, so renaming a section changes
    nothing here. A task on no numbered section is on no pipeline, and nothing is written to it --
    which is how a board that has not adopted the convention is left alone rather than guessed at.
    Two different numbered boards is 'ambiguous' and skipped, the same refusal to guess as above.

    Auth: -AsanaPat (from the ASANA_PAT secret). Project: -ProjectGid (from the ASANA_PROJECT_GID
    variable), read by sweep (a) alone. Sweep (c) reads the score field by name (-PrioFieldName,
    default 'Prio-Score'). There is deliberately NO workspace parameter: every call this
    script makes addresses a task, a project or a section by GID. BOTH modes need `gh` on PATH with
    GH_TOKEN set -- a close update asks GitHub which pull request closed the issue -- and sweeps (b),
    (c) and (d) additionally need -Repo (GITHUB_REPOSITORY). Where `gh` cannot answer, the update
    still goes out and simply names no pull request, and sweep (d) derives no stage rather than
    guessing one.

    AND THE STAGE SWEEP NEEDS A SECOND TOKEN, in GH_PROJECT_TOKEN -- WHERE THERE IS A BOARD.
    `GITHUB_TOKEN` cannot read an organization's Projects v2 -- there is no `permissions:` key that
    grants it -- so with the workflow's own token the status field comes back as an error rather than a
    value. That failure is contained rather than fatal: the query retries once without projectItems, so
    the close update goes out exactly as before and only the staging goes quiet, naming the missing
    token. Set GH_PROJECT_TOKEN to a PAT that can read the org's projects to turn staging back on.

    A REPO WITH NO PROJECT BOARD SAYS SO AND NEEDS NEITHER (inbound #1536). Give Get-GithubStatusMap an
    empty FieldName and no Statuses: the projectItems query is then never sent, so GH_PROJECT_TOKEN is
    not read at all, and Get-StageFloorForIssue derives the floor from the issue itself -- closed means
    InReview, an open issue with a linked pull request means InDevelopment, an open one without means
    Filed. Everything above still holds for a repo that HAS a board; nothing on that path changed.

    THAT DECLARATION EXISTS BECAUSE ITS ABSENCE WAS SILENT AND COST FOUR STAGES, not three. Advising
    GH_PROJECT_TOKEN is no answer where there is no board to read, and a $null floor also disabled the
    ReadyToTest promotion -- which is reached from a floor of InReview and is the one stage no column
    names. So closing an issue told the submitter the work was ready and left their card where it was.
    The sweep now says in one line when a whole run derived nothing, whichever of the three reasons it
    was, so the same failure cannot be quiet again -- see Invoke-StageSweep.

    The comment text is English, like everything else this repo ships. It is the workflow speaking,
    not the subject -- the same boundary a BWJ store repo already draws when it keeps its ticket
    headings English while the analysis under them follows whoever filed the ticket.

    The pure helpers (Resolve-AsanaTaskRef, Get-AsanaTaskGid, Get-AsanaGidsFromText,
    New-MirrorComment, Get-MirrorCommentMarker, New-AsanaCommentRequest, Get-IssueRefFromNotes,
    Get-StageFromSectionName, Select-StageMembership, Get-DefaultAsanaStageMap, Get-StageMapNumbers,
    Get-WritableStages, Test-StageIsWritable, Test-StageIsTerminal, Test-AsanaStageMap,
    Get-DefaultGithubStatusMap, Test-GithubStatusMap, Select-ProjectStatus, Get-StageForProjectStatus,
    Get-SubmitterFromNotes, Get-StageFloorForIssue,
    Resolve-TargetStage, New-AsanaSectionMoveRequest) take no network and are what the source repo's
    scripts/tests/dkj-policy-bwj.tests.ps1 exercises -- including against a board numbered some other way,
    so the map cannot quietly become decoration over literals. The script runs its main flow only when
    invoked directly; dot-sourcing it loads the helpers and does nothing else.

    Pure ASCII (repo convention for .ps1).
#>
[CmdletBinding()]
param(
    [ValidateSet('event', 'reconcile')]
    [string]$Mode = 'event',

    # 'closed' and 'reopened' comment AND move the card; 'labeled'/'unlabeled' only move it.
    [ValidateSet('closed', 'reopened', 'labeled', 'unlabeled')]
    [string]$Event = 'closed',

    [string]$IssueBody = '',
    [string]$IssueRef = '',
    [string]$Repo = $env:GITHUB_REPOSITORY,

    # Sweep (b) lookback, in days. 0 = every closed issue the listing returns.
    [int]$SinceDays = 30,

    [string]$AsanaPat = $env:ASANA_PAT,
    [string]$ProjectGid = $env:ASANA_PROJECT_GID,

    # The Asana number field the prio label is read from, by NAME: its GID differs per workspace, so
    # a name needs no repo variable of its own. A rename does not fail silently -- the label sweep
    # prints how many issues carried a score, and a sudden 0 there is the signal.
    [string]$PrioFieldName = 'Prio-Score',

    # Where to look for scripts/repo-config.ps1, whose Get-AsanaStageMap states which numbered
    # section each stage of the cycle is. Defaults to the checkout the workflow runs in.
    [string]$RepoRoot = '.'
)

$ErrorActionPreference = 'Stop'

$script:AsanaApiBase = 'https://app.asana.com/api/1.0'

# The four prio labels, low to high. EXACTLY ONE of these belongs on an issue at a time, which is
# what Set-IssuePrioLabel enforces by removing the other three. Named here rather than inline so the
# mapping helper and the enforcer cannot drift apart.
$script:PrioLabels = @('prio-1', 'prio-2', 'prio-3', 'prio-4')

# The stage map, resolved once per run from the repo's own seam -- see Resolve-AsanaStageMap.
$script:StageMap = $null

# And which project status means which of those stages -- see Resolve-GithubStatusMap. Two maps and
# not one, because they answer to two different boards: this one is keyed on GitHub's column names.
$script:StatusMap = $null

# Stage -> section-GID map per project, filled on first use. A sweep over fifty issues on one board
# asks Asana for that board's sections once.
$script:StageSectionCache = @{}

function Get-AsanaGidsFromText {
    <#
        Return the distinct task GIDs of every Asana task URL in a piece of text, in the order they
        first appear. Both URL shapes Asana hands out are read:

            https://app.asana.com/1/<workspace>/project/<project>/task/<task>
            https://app.asana.com/0/<project>/<task>

        A URL that names no task (a project or portfolio link) contributes nothing.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)

    $gids = @()
    foreach ($m in [regex]::Matches($Text, 'https://app\.asana\.com/[^\s)>\]]*')) {
        $url = $m.Value
        $t = [regex]::Match($url, '/task/([0-9]+)')
        if (-not $t.Success) { $t = [regex]::Match($url, '^https://app\.asana\.com/0/[0-9]+/([0-9]+)') }
        if ($t.Success) { $gids += $t.Groups[1].Value }
    }
    return @($gids | Select-Object -Unique)
}

function Get-AsanaHeaderRowText {
    <#
        Return the contents of an imported ticket's '| **Asana** | ... |' header row, or '' when the
        body has no such row. Anchored on the row label, so a link to a sibling ticket elsewhere in
        the body cannot be mistaken for this ticket's own task.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$IssueBody)

    $m = [regex]::Match($IssueBody, '(?m)^\|\s*\*{0,2}Asana\*{0,2}\s*\|(.*)$')
    if (-not $m.Success) { return '' }
    return $m.Groups[1].Value
}

function Resolve-AsanaTaskRef {
    <#
        Resolve which Asana task an issue body belongs to. Returns an object with:

            Gid         the numeric task GID as a string, or $null
            Source      'marker' | 'header-row' | 'sole-url' | 'ambiguous' | 'none'
            Candidates  the distinct GIDs seen, for the 'ambiguous' report

        Pure -- no network. Non-numeric content never matches, so it can never reach a request URL.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$IssueBody)

    $marker = [regex]::Match($IssueBody, '<!--\s*asana-task:\s*([0-9]+)\s*-->')
    if ($marker.Success) {
        return [pscustomobject]@{ Gid = $marker.Groups[1].Value; Source = 'marker'; Candidates = @($marker.Groups[1].Value) }
    }

    $row = Get-AsanaHeaderRowText -IssueBody $IssueBody
    if ($row) {
        $rowGids = @(Get-AsanaGidsFromText -Text $row)
        if ($rowGids.Count -ge 1) {
            return [pscustomobject]@{ Gid = $rowGids[0]; Source = 'header-row'; Candidates = $rowGids }
        }
    }

    $all = @(Get-AsanaGidsFromText -Text $IssueBody)
    if ($all.Count -eq 1) { return [pscustomobject]@{ Gid = $all[0]; Source = 'sole-url'; Candidates = $all } }
    if ($all.Count -gt 1) { return [pscustomobject]@{ Gid = $null; Source = 'ambiguous'; Candidates = $all } }
    return [pscustomobject]@{ Gid = $null; Source = 'none'; Candidates = @() }
}

function Get-AsanaTaskGid {
    <#
        The GID Resolve-AsanaTaskRef settled on, or $null. Kept as its own name because it is the
        one thing most callers want.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$IssueBody)

    return (Resolve-AsanaTaskRef -IssueBody $IssueBody).Gid
}

function Get-IssueRefFromNotes {
    <#
        Pull an 'owner/repo#n' reference out of a GitHub issue URL in an Asana task's notes.
        Returns $null when the notes carry no github.com issue URL.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Notes)

    $m = [regex]::Match($Notes, 'https://github\.com/([^/\s]+/[^/\s]+)/issues/([0-9]+)')
    if (-not $m.Success) { return $null }
    return ('{0}#{1}' -f $m.Groups[1].Value, $m.Groups[2].Value)
}

function Get-MirrorCommentMarker {
    <#
        The opening sentence of a close update, which doubles as its de-duplication key. It names the
        issue, so two issues mirrored onto the same task never mask each other. Pure.

        Deliberately a readable sentence rather than an invisible token: this comment is read by a
        colleague, and a machine marker in it would be clutter they cannot act on.
    #>
    param([Parameter(Mandatory = $true)][string]$IssueRef)

    return "GitHub issue $IssueRef is closed"
}

function New-MirrorComment {
    <#
        The comment text for one event. Pure -- no network.

        'closed'   the work is built and ready for the person who asked for it to test. -ClosedBy
                   carries the pull request(s) that closed the issue, so the update names WHERE the
                   change was made and links straight to it: that is the first thing a colleague
                   wants when they are about to test, and GitHub itself says it that way
                   ("closed this as completed in #434"). Empty means the issue was closed by hand,
                   and the update then says so rather than implying a PR that does not exist.
        'reopened' it is being worked on again; do not test yet.

        -StateReason 'not_planned' turns the close update into its opposite: nothing was built, so
        asking somebody to test it would be worse than saying nothing.

        No text here claims the ticket is done, and none asks anybody to hurry: this script has no
        say over when a ticket is resolved.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$IssueRef,
        [Parameter(Mandatory = $true)][ValidateSet('closed', 'reopened')][string]$Event,
        [pscustomobject[]]$ClosedBy = @(),
        [string]$StateReason = ''
    )

    $parts = $IssueRef -split '#'
    $url = "https://github.com/$($parts[0])/issues/$($parts[1])"

    if ($Event -eq 'reopened') {
        return @(
            "GitHub issue $IssueRef has been reopened: it is being worked on again, so hold off on testing.",
            $url
        ) -join "`n"
    }

    $marker = Get-MirrorCommentMarker -IssueRef $IssueRef

    if ($StateReason -eq 'not_planned') {
        return @(
            "$marker, as not planned: this is not going to be built.",
            $url,
            '',
            'There is nothing to test. The reason is on the issue; reply there or here if you disagree with it.'
        ) -join "`n"
    }

    $lines = @("$marker`: the work behind this ticket is built and ready to test.", $url, '')

    if ($ClosedBy.Count -gt 0) {
        $lines += if ($ClosedBy.Count -eq 1) { 'Closed by pull request:' } else { 'Closed by pull requests:' }
        foreach ($pr in $ClosedBy) {
            $lines += "  #$($pr.number) $($pr.title)"
            $lines += "  $($pr.url)"
        }
        $lines += ''
    } else {
        $lines += 'Closed by hand -- no pull request is linked to it.'
        $lines += ''
    }

    $lines += 'This ticket stays open on purpose. Tick it off yourself once you have checked that it does what you meant.'
    return ($lines -join "`n")
}

function Get-StageFromSectionName {
    <#
        The stage number a section's name declares, or $null when it declares none. Pure.

        A pipeline section is named '<N>. <whatever the board likes>'. The NUMBER is the
        machine-readable half and the words after it belong to the board, which is the same split the
        cross-link already uses: a marker for the machine, prose for the reader. So renaming
        '3. In development' to '3. Building it' changes nothing here, and no repo has to keep six
        section GIDs correct in its config.

        It is also the whole containment. A section with no leading number yields $null, and a task
        whose sections all yield $null is on no pipeline and is never written to -- so pointing this
        script at a workspace full of other boards costs nothing.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Name)

    $m = [regex]::Match($Name, '^\s*([0-9]+)\s*\.')
    if (-not $m.Success) { return $null }
    return [int]$m.Groups[1].Value
}

function Get-DefaultAsanaStageMap {
    <#
        Which numbered section each stage of the cycle IS, when a repo states nothing. Pure.

        The number convention says how a section is recognised; this says what each one MEANS, and the
        two are separate questions. They were one question until September 2, 2026, with the meanings
        written as literals in the derivation -- and the board they were written against grew a
        section the same afternoon, which shifted every stage from 'Filed' upward by one. Nothing
        failed loudly: the sweep would simply have filed every card one column early.

        So the meaning lives in the repo's own scripts/repo-config.ps1, as Get-AsanaStageMap, and this
        is the fallback. Semantic keys and not GIDs, deliberately: a rebuilt column keeps its number
        and loses its GID, which is the failure mode a GID map is born with.
    #>
    return @{
        Requests       = 1   # the requester's inbox -- never a target, though cards do leave it
        NeedsInfo      = 2   # blocked on the submitter -- set by a label, see Resolve-TargetStage
        Filed          = 3   # the GitHub issue exists; nothing is being built yet
        InDevelopment  = 4   # a branch is open -- the session's own hop, never derived by CI
        InReview       = 5   # a pull request is open OR merged, and the issue is not closed yet
        ReadyToTest    = 6   # the issue is closed as completed -- the submitter's turn
        Completed      = 7   # the submitter says it is good -- never a target, never moved OUT of
        NeedsInfoLabel = 'needs-info'
    }
}

function Get-DefaultGithubStatusMap {
    <#
        Which stage of the cycle each GitHub Project Status MEANS, when a repo states nothing. Pure.

        Stages Filed, InDevelopment and InReview are linked to the three statuses of the project
        board and are always in sync with them (Dave, September 2, 2026). GitHub is the source: its
        own built-in project workflows write that field -- 'Item added to project' sets Todo,
        'Pull request linked to issue' sets In Progress, 'Item closed' sets Done -- so reading it
        instead of re-deriving the same thing from the issue and its pull requests is what makes the
        two boards agree rather than race.

        THE STATUS NAMES ARE THE KEYS because they are what the API returns, and a board may rename
        them. The VALUES are stage keys of Get-AsanaStageMap, never section numbers: a repo that
        renumbers its board states that once, in the stage map, and this map keeps working.

        The stages outside those three are deliberately unreachable from a status, and Test-GithubStatusMap
        refuses a map that tries. Requests and NeedsInfo answer to a person and a label; Completed is the
        submitter's verdict; and ReadyToTest is reached by the RULE BELOW rather than by any column of the
        project board, because no GitHub status means 'the submitter has been told'.

        READYTOTEST IS ENTERED ON FEEDBACK, NOT ON A STATUS (Dave, September 2, 2026). A card advances
        from InReview to ReadyToTest once two things are true: the issue is closed, and the submitter of
        the Asana ticket has actually been told -- which is this script's own close update, the comment
        carrying Get-MirrorCommentMarker. So InReview means 'closed on GitHub, nobody has been told yet'
        and ReadyToTest means 'it is the submitter's turn', which is the distinction the column is named
        for.

        AND WHERE THERE IS NO SUBMITTER, STAGE 6 IS SKIPPED ENTIRELY (Dave, same day). A ticket nobody
        else asked for has nobody to hand it to: it stays in InReview until the person who owns it accepts
        it into Completed by hand. SubmitterPattern is how a repo says where the submitter's name is
        written, and '' -- the default -- means this script can never tell, so ReadyToTest is never
        entered automatically at all. That is the fail-safe direction: a card held one column short is
        visible and a person can move it, where a card pushed into the submitter's column claims a
        handover that never happened.

        Measured on the BWJ board the day this shipped: `created_by` is NOT the submitter -- the intake
        form creates every card as its own owner, so it reads the same on a colleague's request and on
        one filed by a session. The submitter is the name the form writes into the notes, and is added
        as a follower when it can find them in Asana.
    #>
    return @{
        # The project field the three middle stages are read off. EMPTY means this repo has no project
        # board at all, and then the floor is derived from the issue instead -- see Get-StageFloorForIssue
        # and Test-GithubStatusMap (inbound #1536). Leave Statuses empty when you say that.
        FieldName        = 'Status'
        Statuses         = @{
            'Todo'        = 'Filed'          # on the board, nothing linked yet
            'In Progress' = 'InDevelopment'  # a pull request is linked to the issue
            'Done'        = 'InReview'       # the issue is closed
        }

        # A regex over the task's notes whose first capture group is the submitter's name. Empty means
        # the repo has not said, and then ReadyToTest is never entered automatically -- see above.
        SubmitterPattern = ''
    }
}

function Get-StageMapNumbers {
    <# The seven stage numbers a map names, in cycle order. Pure. #>
    param([Parameter(Mandatory = $true)]$Map)
    return @($Map.Requests, $Map.NeedsInfo, $Map.Filed, $Map.InDevelopment,
             $Map.InReview, $Map.ReadyToTest, $Map.Completed) | ForEach-Object { [int]$_ }
}

function Get-WritableStages {
    <#
        The stages this script may put a card in: the five pipeline stages. Pure.

        Requests and Completed are excluded, and they are excluded for two different reasons worth
        keeping apart. Requests is never a TARGET -- a card leaves it the moment the issue is filed,
        which is the whole of inbound #1217 -- while Completed is never a target AND never moved out
        of, because a card is only there because a person put it there.
    #>
    param([Parameter(Mandatory = $true)]$Map)
    return @($Map.NeedsInfo, $Map.Filed, $Map.InDevelopment, $Map.InReview, $Map.ReadyToTest) |
        ForEach-Object { [int]$_ }
}

function Test-StageIsWritable {
    <#
        Is this a stage this script may put a card in? Pure, and the code-level twin of the rule that
        the board's two ends belong to the requester.

        It is belt and braces on purpose. Resolve-TargetStage cannot return Requests or Completed
        either, so this guard should never fire -- exactly the property the 'no code path can complete
        a task' guarantee has, and the reason both are asserted rather than assumed.
    #>
    param(
        [AllowNull()]$Stage,
        [Parameter(Mandatory = $true)]$Map
    )

    if ($null -eq $Stage) { return $false }
    return ((Get-WritableStages -Map $Map) -contains [int]$Stage)
}

function Test-AsanaStageMap {
    <#
        Is this a usable stage map? Returns the list of complaints, empty when it is. Pure.

        Three ways a hand-written map goes wrong, and all three are silent at runtime rather than
        loud: a missing key reads as stage 0, a non-numeric one as stage 0 too, and a duplicate makes
        two stages the same column so a card can never leave one of them.
    #>
    param([AllowNull()]$Map)

    $keys = @('Requests', 'NeedsInfo', 'Filed', 'InDevelopment', 'InReview', 'ReadyToTest', 'Completed')
    if (-not $Map) { return @('the map is empty') }

    $bad = @()
    foreach ($k in $keys) {
        $v = $Map[$k]
        if ($null -eq $v)                       { $bad += "$k names no section"; continue }
        if ("$v" -notmatch '^[0-9]+$')          { $bad += "$k is '$v', which is not a section number" }
        elseif ([int]$v -lt 1)                  { $bad += "$k is $v, and a section number starts at 1" }
    }
    if ($bad.Count -gt 0) { return $bad }

    $nums = Get-StageMapNumbers -Map $Map
    $dupes = @($nums | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
    foreach ($d in $dupes) { $bad += "section $d is named by more than one stage" }
    return $bad
}

function Resolve-AsanaStageMap {
    <#
        The repo's own stage map, or the built-in one. Reads scripts/repo-config.ps1 -- the same file
        dkj-policy already dot-sources and report-issue already reads session-side -- and
        calls Get-AsanaStageMap if it defines one.

        It never throws and it always returns a usable map. A repo with no seam, a seam that fails to
        load, or a map that does not validate all fall back to the default WITH A LINE SAYING SO,
        because a silently wrong map is the exact failure this seam exists to end: every card one
        column early, and nothing in the log to say why.
    #>
    param([string]$RepoRoot = '.')

    $default = Get-DefaultAsanaStageMap
    $cfg = Join-Path $RepoRoot 'scripts/repo-config.ps1'
    if (-not (Test-Path -LiteralPath $cfg)) {
        Write-Host "  No scripts/repo-config.ps1 -- using the built-in stage map."
        return $default
    }

    try { . $cfg } catch {
        Write-Host "  scripts/repo-config.ps1 could not be loaded ($($_.Exception.Message)) -- using the built-in stage map."
        return $default
    }
    if (-not (Get-Command -Name 'Get-AsanaStageMap' -ErrorAction SilentlyContinue)) {
        Write-Host "  scripts/repo-config.ps1 defines no Get-AsanaStageMap -- using the built-in stage map."
        return $default
    }

    $own = $null
    try { $own = Get-AsanaStageMap } catch {
        Write-Host "  Get-AsanaStageMap threw ($($_.Exception.Message)) -- using the built-in stage map."
        return $default
    }

    $complaints = Test-AsanaStageMap -Map $own
    if ($complaints.Count -gt 0) {
        Write-Host "  Get-AsanaStageMap is not usable -- using the built-in stage map instead. $($complaints -join '; ')."
        return $default
    }

    # The label is the one optional key: a map that names none keeps the default, and a map that sets
    # it to '' switches the needs-info column off altogether, which is a real answer.
    if (-not $own.ContainsKey('NeedsInfoLabel')) { $own['NeedsInfoLabel'] = $default.NeedsInfoLabel }
    Write-Host "  Stage map from scripts/repo-config.ps1: $((Get-StageMapNumbers -Map $own) -join '/'), needs-info label '$($own.NeedsInfoLabel)'."
    return $own
}

function Test-GithubStatusMap {
    <#
        Is this a usable status map? Returns the list of complaints, empty when it is. Pure.

        It checks the shape and the stage KEYS, not the status names: a board is free to call its
        columns anything, but a value that is not a stage of the cycle can never be looked up in the
        stage map, and would read as stage 0 at runtime -- silently, which is the failure this
        validation exists to make loud.

        AN EMPTY FieldName IS A REAL ANSWER, NOT A GAP: 'this repo has no project board' (inbound
        #1536). It is the one declaration a repo could not make before, which is why the failure that
        issue reported was silent -- with no way to SAY there is no board, a board-less repo was
        indistinguishable from a misconfigured one, and Resolve-GithubStatusMap handed it the built-in
        map naming three columns it does not have. Get-StageFloorForIssue reads this same emptiness and
        derives the floor from the issue instead; Get-IssueLinkState already skips the projectItems
        query on an empty -StatusField, so such a repo needs no GH_PROJECT_TOKEN at all.

        SAYING BOTH IS REFUSED. An empty FieldName beside a Statuses table that still names columns is
        a half-finished edit, not a configuration: it reads as 'there is no board' and 'here are its
        columns' at once, and guessing which half was meant is how a board-less repo would silently
        get board behaviour back. One or the other, and the complaint says so.
    #>
    param([AllowNull()]$Map)

    if (-not $Map) { return @('the status map is empty') }

    $statuses = $Map.Statuses
    $named    = if ($statuses -is [System.Collections.IDictionary]) { @($statuses.Keys) } else { @() }

    if (-not ([string]$Map.FieldName)) {
        if ($named.Count -gt 0) {
            return @("FieldName names no project field -- which says this repo has no project board -- while Statuses still names $($named.Count) column(s) of one. Say either that there is a board or that there is none, not both.")
        }
        return @()
    }

    $bad = @()
    if (-not $statuses)            { return @($bad + 'Statuses names no status at all') }
    if (-not ($statuses -is [System.Collections.IDictionary])) {
        return @($bad + 'Statuses is not a name-to-stage table')
    }
    if ($named.Count -eq 0) { $bad += 'Statuses names no status at all' }

    # What a STATUS may name is narrower than what this script may write. ReadyToTest is writable, but
    # only the feedback rule may reach it -- a status that named it would hand a card to the submitter
    # on a column change instead of on an actual handover.
    $stageKeys = @('Requests', 'NeedsInfo', 'Filed', 'InDevelopment', 'InReview', 'ReadyToTest', 'Completed')
    $mappable  = @('NeedsInfo', 'Filed', 'InDevelopment', 'InReview')
    foreach ($k in $named) {
        $v = [string]$statuses[$k]
        if (-not $v)                    { $bad += "status '$k' names no stage"; continue }
        if ($stageKeys -notcontains $v) { $bad += "status '$k' names '$v', which is not a stage of the cycle"; continue }
        if ($mappable -notcontains $v)  { $bad += "status '$k' names '$v', which no project status may name -- it is reached by the feedback rule or by a person" }
    }
    return $bad
}

function Resolve-GithubStatusMap {
    <#
        The repo's own status map, or the built-in one. Same seam, same file and same never-throws
        contract as Resolve-AsanaStageMap -- scripts/repo-config.ps1, read once per run, and a line
        saying which map the run is using so a wrong one is never silent.
    #>
    param([string]$RepoRoot = '.')

    $default = Get-DefaultGithubStatusMap
    $cfg = Join-Path $RepoRoot 'scripts/repo-config.ps1'
    if (-not (Test-Path -LiteralPath $cfg)) {
        Write-Host "  No scripts/repo-config.ps1 -- using the built-in status map."
        return $default
    }

    try { . $cfg } catch {
        Write-Host "  scripts/repo-config.ps1 could not be loaded ($($_.Exception.Message)) -- using the built-in status map."
        return $default
    }
    if (-not (Get-Command -Name 'Get-GithubStatusMap' -ErrorAction SilentlyContinue)) {
        Write-Host "  scripts/repo-config.ps1 defines no Get-GithubStatusMap -- using the built-in status map."
        return $default
    }

    $own = $null
    try { $own = Get-GithubStatusMap } catch {
        Write-Host "  Get-GithubStatusMap threw ($($_.Exception.Message)) -- using the built-in status map."
        return $default
    }

    $complaints = Test-GithubStatusMap -Map $own
    if ($complaints.Count -gt 0) {
        Write-Host "  Get-GithubStatusMap is not usable -- using the built-in status map instead. $($complaints -join '; ')."
        return $default
    }

    $pairs = @(@($own.Statuses.Keys) | Sort-Object | ForEach-Object { "$_ -> $($own.Statuses[$_])" })
    Write-Host "  Status map from scripts/repo-config.ps1: field '$($own.FieldName)', $($pairs -join ', ')."
    return $own
}

function Select-ProjectStatus {
    <#
        The one project Status this issue carries, and where the answer came from. Pure -- no network.

            Source  'status' | 'none' | 'ambiguous'
            Status  the status name, or $null

        An issue may sit on several project boards, and two boards that both name a status are two
        answers -- so it gets neither, exactly as a card on two numbered Asana boards does. The
        candidates are named by the caller for the log and nothing moves. An issue on no board, or on
        one whose status field is empty, is 'none': a real answer meaning this issue is on no
        pipeline, and the safe one, because a missing status must never read as stage 0.
    #>
    param($ProjectItems = @())

    $named = @()
    foreach ($it in @($ProjectItems)) {
        $name = [string]$it.fieldValueByName.name
        if ($name) { $named += $name }
    }

    if ($named.Count -eq 0) { return [pscustomobject]@{ Source = 'none';      Status = $null } }
    if (@($named | Sort-Object -Unique).Count -gt 1) {
        return [pscustomobject]@{ Source = 'ambiguous'; Status = $null; Candidates = @($named | Sort-Object -Unique) }
    }
    return [pscustomobject]@{ Source = 'status'; Status = $named[0] }
}

function Get-StageForProjectStatus {
    <#
        The stage a project Status names, or $null when it names none. Pure.

        $null covers both ways this can fail to answer, and they are deliberately not distinguished
        here: no status at all, and a status the map has no entry for -- a board that has added a
        fourth column nobody has mapped yet. Both mean 'this run does not know where the card goes',
        and the answer to not knowing is to leave the card alone.
    #>
    param(
        [AllowNull()][AllowEmptyString()]$Status,
        [Parameter(Mandatory = $true)]$StatusMap,
        [Parameter(Mandatory = $true)]$Map
    )

    if (-not [string]$Status) { return $null }
    $stageKey = [string]$StatusMap.Statuses[[string]$Status]
    if (-not $stageKey) { return $null }
    $number = $Map[$stageKey]
    if ($null -eq $number) { return $null }
    return [int]$number
}

function Get-SubmitterFromNotes {
    <#
        The name of the person who asked for this ticket, or $null when the notes name nobody. Pure.

        The pattern comes from the repo, because where a submitter's name sits is a property of the
        intake form rather than of this workflow -- see Get-DefaultGithubStatusMap's SubmitterPattern.
        An empty pattern answers $null for everything, which is the fail-safe: no submitter means
        stage 6 is skipped, not that everyone is a submitter.

        A pattern that names a capture group takes group 1; one that names none takes the whole match,
        so a repo can point at a line without having to write a group it does not need.
    #>
    param(
        [AllowNull()][AllowEmptyString()][string]$Notes,
        [AllowNull()][AllowEmptyString()][string]$Pattern
    )

    if (-not $Pattern -or -not $Notes) { return $null }
    $m = $null
    try { $m = [regex]::Match($Notes, $Pattern) } catch { return $null }
    if (-not $m.Success) { return $null }

    $name = if ($m.Groups.Count -gt 1 -and $m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Value }
    $name = ([string]$name).Trim()
    if (-not $name) { return $null }
    return $name
}

function Test-StageIsTerminal {
    <#
        Is this a stage a card is never moved OUT of by this script? Pure.

        Two stages, and both belong to the submitter: ReadyToTest, which they are testing, and
        Completed, which is their verdict. Once a card is in either, this workflow is a spectator.

        THIS OUTRANKS -AllowBackward, which is the whole point of it (Dave, September 2, 2026): the
        reopen is a real state change and normally earns a backward move, but a card somebody has
        already been handed must not be pulled back out from under them by a later sweep. If the work
        turns out not to be done, the person holding the card moves it -- that is what holding it
        means. Before this, Completed alone was terminal and a card dragged to ReadyToTest by hand
        could be walked back to InReview on the next run.
    #>
    param(
        [AllowNull()]$Stage,
        [Parameter(Mandatory = $true)]$Map
    )

    if ($null -eq $Stage) { return $false }
    return (@([int]$Map.ReadyToTest, [int]$Map.Completed) -contains [int]$Stage)
}

function Select-StageMembership {
    <#
        Which pipeline board this task is on, read off the task's own memberships. Returns an object
        shaped like Resolve-AsanaTaskRef's, for the same reason -- the caller logs the Source:

            Source      'stage-section' | 'none' | 'ambiguous'
            Membership  ProjectGid / SectionGid / Stage, or $null
            Candidates  the distinct project GIDs seen, for the 'ambiguous' report

        Pure -- no network. Asana gives a task one section per project, so a single numbered project
        resolves to a single section. Two DIFFERENT numbered projects is two answers and this script
        takes neither: a card on two pipelines is a board question, not a script question.
    #>
    param($Memberships)

    $found = @()
    foreach ($m in @($Memberships)) {
        if (-not $m -or -not $m.section) { continue }
        $stage = Get-StageFromSectionName -Name ([string]$m.section.name)
        if ($null -eq $stage) { continue }
        $found += [pscustomobject]@{
            ProjectGid = [string]$m.project.gid
            SectionGid = [string]$m.section.gid
            Stage      = $stage
        }
    }

    $projects = @($found | ForEach-Object { $_.ProjectGid } | Sort-Object -Unique)
    if ($projects.Count -eq 0) { return [pscustomobject]@{ Source = 'none';      Membership = $null;     Candidates = @() } }
    if ($projects.Count -gt 1) { return [pscustomobject]@{ Source = 'ambiguous'; Membership = $null;     Candidates = $projects } }
    return                             [pscustomobject]@{ Source = 'stage-section'; Membership = $found[0]; Candidates = $projects }
}

function Get-StageFloorForIssue {
    <#
        The stage the GitHub side puts a floor under, or $null when it puts none. Pure.

            project status Todo                 Filed         on the board, nothing linked yet
            project status In Progress           InDevelopment a pull request is linked to the issue
            project status Done                  InReview      the issue is closed
            no status, or one the map misses     $null         this issue is on no pipeline
            closed as not planned                $null         nothing was built, so nothing to stage

        AND WHERE THE REPO HAS NO BOARD AT ALL, the issue itself is read instead:

            closed                               InReview      the work is done
            open, a pull request linked           InDevelopment somebody is building it
            open, nothing linked                  Filed         on the tracker, not started
            no state (GitHub could not be asked)  $null         nothing is derived from silence

        THE PROJECT STATUS IS THE SOURCE, and the issue's own state is no longer read for this (Dave,
        September 2, 2026). Stages Filed, InDevelopment and InReview are linked to the three statuses
        of the project board and must always be in sync with them -- so this reads that field instead
        of re-deriving the same answer from the issue and its pull requests. GitHub's own built-in
        project workflows already do that derivation ('Pull request linked to issue' sets In Progress,
        'Item closed' sets Done); doing it a second time here made two writers of one fact, which is a
        race rather than a sync.

        THAT RULE IS UNCHANGED WHEREVER THERE IS A BOARD, and the fallback below cannot weaken it
        (inbound #1536). The two-writers race it removed exists only when a board is present -- it IS
        GitHub's project workflow being the other writer -- so a derivation that fires only where there
        is no board has no second writer to race with. A repo naming a FieldName takes exactly the path
        it took before, to the line.

        WHAT THE MISSING FALLBACK COST, because it is not the three stages it looks like. With no board
        the floor was $null for every issue, and a $null floor also switched off the ONE promotion that
        is not a column at all: Resolve-TargetStage reaches ReadyToTest only from a floor already at
        InReview, so closing an issue stopped handing the card back to the submitter -- the transition
        the whole board model exists for. The close update still went out, so the person was told the
        work was ready while their card never moved, and no run failed. Four stages, not three, and the
        fourth was the one nobody had written down as depending on a board.

        IT IS THE REPO'S DECLARATION THAT SWITCHES THIS ON, never a missing status. Those are two
        different facts that both used to arrive as $null: 'this repo has no board' and 'this issue is
        not on the board'. Only the first may derive a stage -- deriving one from the second would stage
        every issue a board deliberately leaves off its pipeline, which is the failure Select-ProjectStatus
        refuses by design ('a missing status must never read as stage 0'). An empty FieldName is that
        declaration and is repo-wide, so within a board-less repo the second case cannot arise.

        THE not_planned GUARD SURVIVES THE CHANGE, and it has to. 'Item closed' sets Done whatever the
        reason, so a ticket closed as 'will not be built' arrives here looking exactly like a finished
        one. Nothing was built, so nothing is staged. It is checked FIRST, so it outranks the fallback
        too -- a board-less repo closing a ticket as not planned stages nothing either.

        A FLOOR, not a position, and that is what makes the daily sweep safe to run. Sync-AsanaTaskStage
        moves forward only, which is what protects the one hop CI cannot see: a session that opened a
        branch and moved the card to InDevelopment keeps it there while the status still reads Todo,
        because Filed is backward from where the card already is. That asymmetry is the deliberate
        exception to 'always in sync' -- syncing it would mean undoing a person's own move on the
        strength of a column GitHub has no event to update.

        Never Requests, never ReadyToTest and never Completed, whatever it is handed. The first is a
        person's, the last is their verdict, and the middle one is reached only by the feedback rule
        in Resolve-TargetStage -- Test-GithubStatusMap refuses a map that tries to name any of them.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$State,
        [AllowEmptyString()][string]$StateReason = '',
        [AllowNull()][AllowEmptyString()]$ProjectStatus = $null,
        [Parameter(Mandatory = $true)]$StatusMap,
        [Parameter(Mandatory = $true)]$Map,

        # Does a pull request close, or would it close, this issue? Get-IssueLinkState's PullRequests.
        # Read ONLY on the board-less path -- where there is a board, GitHub's own project workflow has
        # already turned this same fact into the 'In Progress' column and that column is the source.
        [switch]$HasLinkedPullRequest
    )

    if ($State -and $State.ToUpperInvariant() -eq 'CLOSED' -and
        $StateReason -and $StateReason.ToLowerInvariant() -eq 'not_planned') {
        return $null
    }

    if (-not ([string]$StatusMap.FieldName)) {
        if (-not $State)                             { return $null }
        if ($State.ToUpperInvariant() -eq 'CLOSED')  { return [int]$Map.InReview }
        if ($HasLinkedPullRequest)                   { return [int]$Map.InDevelopment }
        return [int]$Map.Filed
    }

    return Get-StageForProjectStatus -Status $ProjectStatus -StatusMap $StatusMap -Map $Map
}

function Resolve-TargetStage {
    <#
        Where this card belongs, and whether the answer may move it BACKWARD. Pure.

            Stage          the target, or $null when nothing derives one
            AllowBackward  $true only for the two answers that are a person's statement
            Why            one phrase for the log, so a move is always attributable

        TWO ANSWERS MAY GO BACKWARD, and both are somebody saying something rather than CI inferring
        it. The needs-info label is a person declaring the work cannot proceed; the reopen is a real
        state change. Everything else is a floor, and floors only rise.

        THE LABEL OUTRANKS THE ISSUE'S STATE, which is the point of it (Dave, September 2, 2026). A
        card blocked on the submitter stays blocked whatever the branch and the pull request are
        doing, because the person who set the label knows something the tracker does not. Removing
        the label hands the card straight back to its state-derived floor -- which is forward, so it
        needs no permission.

        A map whose NeedsInfoLabel is empty switches the column off: the label is then never looked
        for, and that is a real answer for a board without one.

        AND ONE ANSWER GOES ONE STAGE FURTHER THAN THE STATUS DOES: the feedback promotion (Dave,
        September 2, 2026). A card whose status floors it at InReview advances to ReadyToTest once BOTH
        of these hold -- the notes name a submitter, and that submitter has already been told, which is
        this script's own close update. Either one missing leaves the card at InReview, and where the
        repo names no SubmitterPattern at all the promotion can never fire, so stage 6 is skipped
        entirely and the person who owns the ticket accepts it into Completed by hand.

        The promotion never allows a backward move. It only ever fires one stage above where the status
        already puts the card, so it cannot pull anything down, and a card that has ALREADY reached
        ReadyToTest is held there by Test-StageIsTerminal rather than by anything here.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$State,
        [AllowEmptyString()][string]$StateReason = '',
        [AllowNull()][AllowEmptyString()]$ProjectStatus = $null,
        [string[]]$Labels = @(),
        [Parameter(Mandatory = $true)]$StatusMap,
        [Parameter(Mandatory = $true)]$Map,
        [switch]$Reopened,

        # The submitter's name, or empty when the notes name nobody -- Get-SubmitterFromNotes.
        [AllowNull()][AllowEmptyString()][string]$Submitter = '',

        # Has that submitter already been told the issue is closed? Test-MirrorUpdatePosted.
        [switch]$SubmitterTold,

        # Passed straight through to Get-StageFloorForIssue, which reads it only where the repo has
        # declared it has no project board. See its own docstring.
        [switch]$HasLinkedPullRequest
    )

    $label = [string]$Map.NeedsInfoLabel
    if ($label -and (@($Labels) -contains $label)) {
        return [pscustomobject]@{
            Stage         = [int]$Map.NeedsInfo
            AllowBackward = $true
            Why           = "the '$label' label"
        }
    }

    $floor = Get-StageFloorForIssue -State $State -StateReason $StateReason `
                 -ProjectStatus $ProjectStatus -StatusMap $StatusMap -Map $Map `
                 -HasLinkedPullRequest:$HasLinkedPullRequest

    if ($null -ne $floor -and [int]$floor -eq [int]$Map.InReview -and $Submitter -and $SubmitterTold) {
        return [pscustomobject]@{
            Stage         = [int]$Map.ReadyToTest
            AllowBackward = $false
            Why           = "$Submitter has been told"
        }
    }

    $why = if ($Reopened)                              { 'the reopen' }
           elseif ($ProjectStatus)                     { "the project status '$ProjectStatus'" }
           elseif (-not ([string]$StatusMap.FieldName)) { 'the issue itself -- this repo has no project board' }
           else                                        { 'the project status' }
    return [pscustomobject]@{
        Stage         = $floor
        AllowBackward = [bool]$Reopened
        Why           = $why
    }
}

function New-AsanaSectionMoveRequest {
    <#
        Pure: describe the POST that puts a task in a section. No network.

        Separated from the call for the same reason New-AsanaCommentRequest is -- the URL and the body
        are assertable without a network -- and it refuses a non-numeric GID on either side, so no
        text read out of an issue body or a section name can reach a request URL.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Gid,
        [Parameter(Mandatory = $true)][string]$SectionGid
    )
    if ($Gid -notmatch '^[0-9]+$')        { throw "Refusing to move a non-numeric task GID: '$Gid'." }
    if ($SectionGid -notmatch '^[0-9]+$') { throw "Refusing to move a task into a non-numeric section GID: '$SectionGid'." }
    [pscustomobject]@{
        Method = 'POST'
        Uri    = "$script:AsanaApiBase/sections/$SectionGid/addTask"
        Body   = (ConvertTo-Json @{ data = @{ task = $Gid } } -Compress -Depth 5)
    }
}

function New-AsanaCommentRequest {
    <#
        Pure: describe the POST that adds a comment to a task. No network. One of the two writes this
        script knows how to build -- the other is New-AsanaSectionMoveRequest.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Gid,
        [Parameter(Mandatory = $true)][string]$Text
    )
    if ($Gid -notmatch '^[0-9]+$') { throw "Refusing to build a request for a non-numeric task GID: '$Gid'." }
    [pscustomobject]@{
        Method = 'POST'
        Uri    = "$script:AsanaApiBase/tasks/$Gid/stories"
        Body   = (ConvertTo-Json @{ data = @{ text = $Text } } -Compress -Depth 5)
    }
}

function Invoke-AsanaRequest {
    param(
        [Parameter(Mandatory = $true)][pscustomobject]$Request,
        [Parameter(Mandatory = $true)][string]$Pat
    )
    $headers = @{ Authorization = "Bearer $Pat"; 'Content-Type' = 'application/json' }
    return Invoke-RestMethod -Method $Request.Method -Uri $Request.Uri -Headers $headers -Body $Request.Body
}

function Add-AsanaComment {
    param(
        [Parameter(Mandatory = $true)][string]$Gid,
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Pat
    )
    Invoke-AsanaRequest -Request (New-AsanaCommentRequest -Gid $Gid -Text $Text) -Pat $Pat | Out-Null
}

function Get-AsanaTaskState {
    <#
        Read a task's 'completed' flag. Returns $null when the task cannot be read -- it was deleted,
        or it lives in a workspace this PAT has no access to. That is reported and skipped rather
        than thrown, so one unreachable ticket cannot end a sweep over all of them.

        Read-only. The flag is never written back: see the .DESCRIPTION.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Gid,
        [Parameter(Mandatory = $true)][string]$Pat,

        # The fields to ask Asana for. The default keeps every existing caller unchanged; the label
        # sweep asks for the custom fields on top of it.
        [string]$OptFields = 'completed,name'
    )
    if ($Gid -notmatch '^[0-9]+$') { throw "Refusing to read a non-numeric task GID: '$Gid'." }
    $uri = "$script:AsanaApiBase/tasks/$Gid" + "?opt_fields=$OptFields"
    try {
        $resp = Invoke-RestMethod -Method GET -Uri $uri -Headers @{ Authorization = "Bearer $Pat" }
        return $resp.data
    } catch {
        Write-Host "  Asana task $Gid is not readable with this token ($($_.Exception.Message)) -- skipped."
        return $null
    }
}

function Test-MirrorUpdatePosted {
    <#
        Has this task already been told that this issue is closed? Reads the task's comments and
        looks for the marker sentence. Used by the sweeps only -- an event always comments.

        An unreadable task answers $true, so a sweep that cannot check does not comment blindly.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Gid,
        [Parameter(Mandatory = $true)][string]$IssueRef,
        [Parameter(Mandatory = $true)][string]$Pat
    )
    if ($Gid -notmatch '^[0-9]+$') { throw "Refusing to read a non-numeric task GID: '$Gid'." }
    $marker = Get-MirrorCommentMarker -IssueRef $IssueRef
    $uri = "$script:AsanaApiBase/tasks/$Gid/stories" + '?opt_fields=text,type&limit=100'
    try {
        $seen = $false
        while ($uri) {
            $resp = Invoke-RestMethod -Method GET -Uri $uri -Headers @{ Authorization = "Bearer $Pat" }
            foreach ($s in @($resp.data)) {
                if ([string]$s.text -and ([string]$s.text).Contains($marker)) { $seen = $true }
            }
            $uri = if ($resp.next_page -and $resp.next_page.uri) { $resp.next_page.uri } else { $null }
        }
        return $seen
    } catch {
        Write-Host "  Comments of Asana task $Gid are not readable ($($_.Exception.Message)) -- skipped rather than commented on blindly."
        return $true
    }
}

function Get-ProjectIncompleteTasks {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectGid,
        [Parameter(Mandatory = $true)][string]$Pat
    )
    $headers = @{ Authorization = "Bearer $Pat" }
    $uri = "$script:AsanaApiBase/projects/$ProjectGid/tasks?opt_fields=completed,notes,name&limit=100"
    $out = @()
    while ($uri) {
        $resp = Invoke-RestMethod -Method GET -Uri $uri -Headers $headers
        $out += @($resp.data | Where-Object { -not $_.completed })
        $uri = if ($resp.next_page -and $resp.next_page.uri) { $resp.next_page.uri } else { $null }
    }
    return $out
}

function Get-ProjectStageSections {
    <#
        One project's stage -> section-GID map, built from its section NAMES. Cached for the run.

        A project with no numbered section gives an empty map, and that is the answer for a board
        which has not adopted the convention -- nothing is created and nothing is guessed. Where two
        sections claim the same number the first one the board lists wins, which is a board defect
        this script reports rather than resolves.

        An unreadable project gives an empty map too, reported and not thrown: one board this PAT
        cannot see must not end a sweep over all the others.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$ProjectGid,
        [Parameter(Mandatory = $true)][string]$Pat
    )
    if ($ProjectGid -notmatch '^[0-9]+$') { throw "Refusing to read a non-numeric project GID: '$ProjectGid'." }
    if ($script:StageSectionCache.ContainsKey($ProjectGid)) { return $script:StageSectionCache[$ProjectGid] }

    $map = @{}
    $uri = "$script:AsanaApiBase/projects/$ProjectGid/sections?opt_fields=name&limit=100"
    try {
        while ($uri) {
            $resp = Invoke-RestMethod -Method GET -Uri $uri -Headers @{ Authorization = "Bearer $Pat" }
            foreach ($s in @($resp.data)) {
                $stage = Get-StageFromSectionName -Name ([string]$s.name)
                if ($null -eq $stage) { continue }
                if ($map.ContainsKey($stage)) {
                    Write-Host "  Asana project $ProjectGid has more than one section numbered $stage -- using the first one it lists."
                    continue
                }
                $map[$stage] = [string]$s.gid
            }
            $uri = if ($resp.next_page -and $resp.next_page.uri) { $resp.next_page.uri } else { $null }
        }
    } catch {
        Write-Host "  Sections of Asana project $ProjectGid are not readable ($($_.Exception.Message)) -- no card is moved on that board."
    }
    $script:StageSectionCache[$ProjectGid] = $map
    return $map
}

function Sync-AsanaTaskStage {
    <#
        Put one card in the section its issue's state has reached. Returns $true when it moved.

        The guards, in the order they are checked. Every one of them is a case where the board is
        right and this script is not, which is why each returns quietly instead of failing:

            no target stage        nothing derived an opinion -- an issue closed as not planned
            not a writable stage   Requests and Completed are the submitter's (Test-StageIsWritable)
            task unreadable        deleted, or in a workspace this PAT is not a member of
            task completed         a person resolved it; leave it exactly where they left it
            on no numbered board   it is on no pipeline at all
            on two numbered boards two answers, so neither is taken
            in an UNMAPPED column  the board grew a section this repo's map does not name
            already in 6 or 7      the submitter is holding it; nothing here takes it back out
            already at or past     forward-only, unless the answer earned -AllowBackward
            board has no such      a board missing that section is not given one

        THE UNMAPPED-COLUMN GUARD IS THE ONE WITH SCAR TISSUE ON IT. Without it a card in a section
        the map does not name is read as a stage number like any other, so a board that grew a column
        gets its cards yanked into whatever the old numbering meant. That is not hypothetical: the
        board this was first written against gained a section within the afternoon (September 2,
        2026), and every stage above it shifted by one. An unnamed column is now a hold -- not a
        target and not a source.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Gid,
        [AllowNull()]$TargetStage,
        [Parameter(Mandatory = $true)][string]$Pat,
        [Parameter(Mandatory = $true)]$Map,

        # A label for the log line, normally 'owner/repo#n'.
        [string]$For = '',

        # Why the target was chosen, for the log -- Resolve-TargetStage's own phrase.
        [string]$Why = '',

        # Only the needs-info label and the reopen earn this; see Resolve-TargetStage.
        [switch]$AllowBackward
    )

    if ($null -eq $TargetStage) { return $false }
    $stage = [int]$TargetStage
    if (-not (Test-StageIsWritable -Stage $stage -Map $Map)) {
        Write-Host "  Refusing to move Asana task $Gid to stage $stage -- only $((Get-WritableStages -Map $Map) -join ', ') are this workflow's to write."
        return $false
    }

    $task = Get-AsanaTaskState -Gid $Gid -Pat $Pat `
                -OptFields 'completed,name,memberships.project.gid,memberships.section.gid,memberships.section.name'
    if ($null -eq $task) { return $false }
    if ($task.completed) { return $false }

    $ref = Select-StageMembership -Memberships $task.memberships
    if ($ref.Source -eq 'none') { return $false }
    if ($ref.Source -eq 'ambiguous') {
        Write-Host "  Asana task $Gid sits on two numbered boards ($($ref.Candidates -join ', ')) -- refusing to guess which pipeline it belongs to."
        return $false
    }

    $current = $ref.Membership.Stage
    $known = Get-StageMapNumbers -Map $Map
    if ($known -notcontains $current) {
        Write-Host "  Asana task $Gid sits in section $current, which this repo's stage map does not name -- left alone."
        return $false
    }
    # Terminal FIRST, and ahead of -AllowBackward on purpose: a card the submitter is already holding
    # is never taken back off them, not even by a reopen. See Test-StageIsTerminal.
    if (Test-StageIsTerminal -Stage $current -Map $Map) { return $false }
    if ($current -eq $stage) { return $false }
    if ($current -gt $stage -and -not $AllowBackward) { return $false }

    $sections = Get-ProjectStageSections -ProjectGid $ref.Membership.ProjectGid -Pat $Pat
    if (-not $sections.ContainsKey($stage)) {
        Write-Host "  Asana project $($ref.Membership.ProjectGid) has no section numbered $stage -- $($task.name) stays in $current."
        return $false
    }

    Invoke-AsanaRequest -Request (New-AsanaSectionMoveRequest -Gid $Gid -SectionGid $sections[$stage]) -Pat $Pat | Out-Null
    $what = if ($For) { "$For -> " } else { '' }
    $back = if ($current -gt $stage) { ' (back)' } else { '' }
    $why  = if ($Why) { " -- $Why" } else { '' }
    Write-Host "  $what$($task.name): stage $current -> $stage$back$why"
    return $true
}

function Test-GitHubIssueClosed {
    param([Parameter(Mandatory = $true)][string]$IssueRef)
    $parts = $IssueRef -split '#'
    # EAP=Continue for the redirect below: under 'Stop' a successful `gh` that writes any progress to
    # stderr raises a terminating NativeCommandError, so the 2>$null would throw instead of discard.
    # Reverts at function exit. This template ships standalone, so it cannot use Invoke-NativeCapture.
    $ErrorActionPreference = 'Continue'
    $state = (& gh issue view $parts[1] --repo $parts[0] --json state --jq '.state') 2>$null
    return ($LASTEXITCODE -eq 0 -and $state -eq 'CLOSED')
}

function Get-IssueLinkState {
    <#
        Where an issue stands and which pull requests are linked to it: its state, its state reason,
        and the pull request(s) that close or would close it -- the same thing GitHub itself shows as
        "closed this as completed in #434".

        Asked through the GraphQL field built for exactly this question
        (closedByPullRequestsReferences) rather than reconstructed from the timeline, where a merge
        commit, a manual close and a passing cross-reference all look similar enough to get wrong.
        That field answers for an OPEN issue too, which is what lets one query serve both callers:
        the close update, which wants the pull request's number and title, and the stage sweep, which
        wants to know whether that pull request is open or merged.

        A cross-reference is deliberately NOT read. A pull request that merely mentions an issue says
        nothing about whether anybody is building it, and stage 3 is a claim about work in progress.

        AND THE PROJECT STATUS, which is what the stage sweep actually steers on since September 2,
        2026 -- read through projectItems in the same round trip, so the common case stays one call.

        THAT FIELD NEEDS A TOKEN THE DEFAULT ONE IS NOT. `GITHUB_TOKEN` has no access to organization
        Projects v2 at all -- there is no `permissions:` key that grants it -- so the query carrying
        projectItems fails wholesale on a CI run that only has the workflow's own token. Rather than
        lose the close update along with the status, a failure RETRIES ONCE WITHOUT projectItems: the
        comment half then works exactly as before and only the staging goes quiet, with a line saying
        why. Set GH_PROJECT_TOKEN to a token that can read the org's projects to get it back.

        Never throws. An unreachable API, a missing `gh`, or an issue nobody linked a pull request to
        all give an empty PullRequests list -- the update then says the issue was closed by hand
        instead of inventing a reference, and the stage sweep reads no status rather than moving a
        card on a guess.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][int]$Number,

        # The project field to read the stage from -- Get-GithubStatusMap's FieldName. Empty skips it.
        [string]$StatusField = 'Status'
    )

    $empty = [pscustomobject]@{ State = ''; StateReason = ''; PullRequests = @(); Labels = @(); ProjectStatus = $null; ProjectStatusSource = 'none' }
    $parts = $Repo -split '/'
    if ($parts.Count -ne 2) { return $empty }

    $core = 'state stateReason labels(first:50){nodes{name}} closedByPullRequestsReferences(first:10,includeClosedPrs:true){nodes{number url title state merged}}'
    $withStatus = "query(`$owner:String!,`$name:String!,`$number:Int!,`$field:String!){repository(owner:`$owner,name:`$name){issue(number:`$number){$core projectItems(first:10){nodes{fieldValueByName(name:`$field){... on ProjectV2ItemFieldSingleSelectValue{name}}}}}}}"
    $plain      = "query(`$owner:String!,`$name:String!,`$number:Int!){repository(owner:`$owner,name:`$name){issue(number:`$number){$core}}}"

    $ErrorActionPreference = 'Continue'
    $raw = $null
    $askedForStatus = [bool]$StatusField

    if ($askedForStatus) {
        $prev = $env:GH_TOKEN
        if ($env:GH_PROJECT_TOKEN) { $env:GH_TOKEN = $env:GH_PROJECT_TOKEN }
        try {
            $raw = (& gh api graphql -f query=$withStatus -F "owner=$($parts[0])" -F "name=$($parts[1])" -F "number=$Number" -F "field=$StatusField") 2>$null
        } finally {
            $env:GH_TOKEN = $prev
        }
        if ($LASTEXITCODE -ne 0 -or -not $raw) {
            Write-Host "  Could not read the '$StatusField' project field of $Repo#$Number -- no card is staged from it. Set GH_PROJECT_TOKEN to a token that can read the organization's projects."
            $raw = $null
            $askedForStatus = $false
        }
    }

    if (-not $raw) {
        $raw = (& gh api graphql -f query=$plain -F "owner=$($parts[0])" -F "name=$($parts[1])" -F "number=$Number") 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $raw) {
            Write-Host "  Could not ask GitHub about $Repo#$Number -- no pull request is named and no card is moved."
            return $empty
        }
    }

    try {
        $issue = (($raw | Out-String) | ConvertFrom-Json).data.repository.issue
        if (-not $issue) { return $empty }
        $status = if ($askedForStatus) {
            Select-ProjectStatus -ProjectItems @($issue.projectItems.nodes)
        } else {
            [pscustomobject]@{ Source = 'none'; Status = $null }
        }
        if ($status.Source -eq 'ambiguous') {
            Write-Host "  $Repo#$Number sits on project boards naming two different statuses ($(@($status.Candidates) -join ', ')) -- refusing to guess which pipeline it belongs to."
        }
        return [pscustomobject]@{
            State               = ([string]$issue.state).ToUpperInvariant()
            StateReason         = ([string]$issue.stateReason).ToLowerInvariant()
            PullRequests        = @($issue.closedByPullRequestsReferences.nodes)
            Labels              = @($issue.labels.nodes | ForEach-Object { [string]$_.name })
            ProjectStatus       = $status.Status
            ProjectStatusSource = $status.Source
        }
    } catch {
        return $empty
    }
}

function Get-ClosedIssues {
    <#
        This repo's closed issues, newest first, optionally narrowed to the last -SinceDays days.
        Returns an empty list (not a throw) when `gh` is unavailable or fails, so sweep (a) still runs.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [int]$SinceDays = 30
    )
    $ErrorActionPreference = 'Continue'
    $raw = (& gh issue list --repo $Repo --state closed --limit 200 --json number,body,closedAt) 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $raw) {
        Write-Host "  Could not list the closed issues of $Repo with gh -- the GitHub-side sweep is skipped."
        return @()
    }
    $items = @(($raw | Out-String) | ConvertFrom-Json)
    if ($SinceDays -gt 0) {
        $cutoff = (Get-Date).ToUniversalTime().AddDays(-$SinceDays)
        $items = @($items | Where-Object { $_.closedAt -and ([datetime]$_.closedAt).ToUniversalTime() -ge $cutoff })
    }
    return $items
}

function Get-SubmitterHandoff {
    <#
        The two facts the feedback promotion needs: WHO the submitter is, and whether they have been
        TOLD. Returns both empty when stage 6 is not in play.

            Submitter  the name from the task's notes, or '' when the notes name nobody
            Told       $true when the close update is already on the task

        Not pure -- up to two Asana reads -- so every cheap reason to skip is checked first, in the
        order that costs least: a repo that named no SubmitterPattern, a card the status has not
        floored at InReview, and a card the needs-info label has claimed (which outranks the status,
        so the promotion could not fire anyway). Only what survives all three costs a round trip.

        TOLD IS MEASURED, NOT ASSUMED, in both modes. In event mode the close comment has just been
        posted, so reading the comments back is one redundant call on the happy path -- and it is the
        call that keeps a label event on an already-closed issue, or a run whose comment failed, from
        claiming a handover that never happened.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Gid,
        [Parameter(Mandatory = $true)][string]$IssueRef,
        [Parameter(Mandatory = $true)][string]$Pat,
        [AllowNull()]$Floor,
        [Parameter(Mandatory = $true)]$StatusMap,
        [Parameter(Mandatory = $true)]$Map,
        [string[]]$Labels = @()
    )

    $none = [pscustomobject]@{ Submitter = ''; Told = $false }

    if (-not [string]$StatusMap.SubmitterPattern) { return $none }
    if ($null -eq $Floor -or [int]$Floor -ne [int]$Map.InReview) { return $none }
    $label = [string]$Map.NeedsInfoLabel
    if ($label -and (@($Labels) -contains $label)) { return $none }

    $task = Get-AsanaTaskState -Gid $Gid -Pat $Pat -OptFields 'completed,name,notes'
    if ($null -eq $task -or $task.completed) { return $none }

    $who = [string](Get-SubmitterFromNotes -Notes ([string]$task.notes) -Pattern ([string]$StatusMap.SubmitterPattern))
    if (-not $who) { return $none }

    return [pscustomobject]@{
        Submitter = $who
        Told      = [bool](Test-MirrorUpdatePosted -Gid $Gid -IssueRef $IssueRef -Pat $Pat)
    }
}

function Invoke-EventMode {
    if (-not $AsanaPat) { throw 'ASANA_PAT is not set.' }
    $ref = Resolve-AsanaTaskRef -IssueBody $IssueBody
    if (-not $ref.Gid) {
        if ($ref.Source -eq 'ambiguous') {
            Write-Host "$IssueRef links several different Asana tasks ($($ref.Candidates -join ', ')) -- refusing to guess. Add an explicit <!-- asana-task: GID --> marker to settle it."
        } else {
            Write-Host "No Asana task is linked from $IssueRef -- nothing to mirror."
        }
        return
    }
    $link = Get-IssueLinkState -Repo ($IssueRef -split '#')[0] -Number ([int]($IssueRef -split '#')[1]) `
                -StatusField ([string]$script:StatusMap.FieldName)

    # A LABEL EVENT MOVES THE CARD AND SAYS NOTHING. 'closed' and 'reopened' are news for the person
    # waiting on the ticket; a label going on or off is a change in OUR state, and narrating it would
    # put a comment on the submitter's ticket every time somebody triaged it.
    if ($Event -in @('closed', 'reopened')) {
        # No de-duplication here on purpose: an event is a real state change, so a close after a
        # reopen is news again and gets said again.
        $text = if ($Event -eq 'closed') {
            New-MirrorComment -IssueRef $IssueRef -Event 'closed' -ClosedBy $link.PullRequests -StateReason $link.StateReason
        } else {
            New-MirrorComment -IssueRef $IssueRef -Event 'reopened'
        }
        Add-AsanaComment -Gid $ref.Gid -Text $text -Pat $AsanaPat
        Write-Host "Asana task $($ref.Gid) updated: $IssueRef $Event (matched by $($ref.Source)). The task was NOT completed -- that is the requester's call."
    }

    # And the card follows. The status comes from the query above rather than from -Event, so a close
    # the API has already superseded cannot move a card on a stale reading.
    $hasPr = (@($link.PullRequests).Count -gt 0)
    $floor = Get-StageFloorForIssue -State $link.State -StateReason $link.StateReason `
                 -ProjectStatus $link.ProjectStatus -StatusMap $script:StatusMap -Map $script:StageMap `
                 -HasLinkedPullRequest:$hasPr
    $hand = Get-SubmitterHandoff -Gid $ref.Gid -IssueRef $IssueRef -Pat $AsanaPat -Floor $floor `
                -StatusMap $script:StatusMap -Map $script:StageMap -Labels $link.Labels

    $target = Resolve-TargetStage -State $link.State -StateReason $link.StateReason `
                  -ProjectStatus $link.ProjectStatus -Labels $link.Labels `
                  -StatusMap $script:StatusMap -Map $script:StageMap `
                  -Submitter $hand.Submitter -SubmitterTold:$hand.Told `
                  -HasLinkedPullRequest:$hasPr `
                  -Reopened:($Event -eq 'reopened')
    Sync-AsanaTaskStage -Gid $ref.Gid -TargetStage $target.Stage -Pat $AsanaPat -Map $script:StageMap `
        -For $IssueRef -Why $target.Why -AllowBackward:$target.AllowBackward | Out-Null
}

function Update-MirroredTask {
    <#
        The sweeps' shared step: comment on a task for a closed issue, unless a person has already
        resolved it or the update is already there. Returns 1 when it commented, 0 otherwise.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Gid,
        [Parameter(Mandatory = $true)][string]$IssueRef,
        [string]$MatchedBy = ''
    )
    $task = Get-AsanaTaskState -Gid $Gid -Pat $AsanaPat
    if ($null -eq $task) { return 0 }
    if ($task.completed) { return 0 }
    if (Test-MirrorUpdatePosted -Gid $Gid -IssueRef $IssueRef -Pat $AsanaPat) { return 0 }

    # NO -StatusField, deliberately. This step writes a comment and moves no card, so the project
    # status is not its question -- the stage sweep is the caller that steers on it. Asking anyway
    # would spend the projectItems round trip on an answer nobody reads, and would print the
    # GH_PROJECT_TOKEN notice once per swept issue in a repo that has not set one.
    $closure = Get-IssueLinkState -Repo ($IssueRef -split '#')[0] -Number ([int]($IssueRef -split '#')[1]) `
                   -StatusField ''
    $text = New-MirrorComment -IssueRef $IssueRef -Event 'closed' -ClosedBy $closure.PullRequests -StateReason $closure.StateReason
    Add-AsanaComment -Gid $Gid -Text $text -Pat $AsanaPat
    $how = if ($MatchedBy) { " (matched by $MatchedBy)" } else { '' }
    Write-Host "  Updated: Asana task $Gid told that $IssueRef is closed$how."
    return 1
}

function Invoke-ReconcileFromAsana {
    <# Sweep (a): the project's incomplete tasks, matched back to GitHub through their notes. #>
    if (-not $ProjectGid) {
        Write-Host 'ASANA_PROJECT_GID is not set -- the Asana-side sweep is skipped.'
        return 0
    }
    $tasks = Get-ProjectIncompleteTasks -ProjectGid $ProjectGid -Pat $AsanaPat
    $done = 0
    foreach ($t in $tasks) {
        $ref = Get-IssueRefFromNotes -Notes ([string]$t.notes)
        if (-not $ref) { continue }
        if (-not (Test-GitHubIssueClosed -IssueRef $ref)) { continue }
        $done += Update-MirroredTask -Gid ([string]$t.gid) -IssueRef $ref
    }
    Write-Host "Asana-side sweep: $($tasks.Count) open task(s) examined, $done updated."
    return $done
}

function Invoke-ReconcileFromGitHub {
    <#
        Sweep (b): this repo's recently closed issues, matched forward to Asana through their bodies.
        This is the half that reaches a ticket imported FROM Asana -- its task was written by a
        colleague and carries no GitHub back-link for the Asana -> GitHub pass to find.
    #>
    if (-not $Repo) {
        Write-Host 'GITHUB_REPOSITORY is not set -- the GitHub-side sweep is skipped.'
        return 0
    }
    $issues = Get-ClosedIssues -Repo $Repo -SinceDays $SinceDays
    $done = 0
    foreach ($i in $issues) {
        $ref = Resolve-AsanaTaskRef -IssueBody ([string]$i.body)
        if (-not $ref.Gid) { continue }
        $done += Update-MirroredTask -Gid $ref.Gid -IssueRef "$Repo#$($i.number)" -MatchedBy $ref.Source
    }
    Write-Host "GitHub-side sweep: $($issues.Count) closed issue(s) examined, $done updated."
    return $done
}

function Get-PrioLabelForScore {
    <#
        The GitHub label for one Asana Prio-Score, or $null when the score names none. Pure.

            1.00-1.99  prio-1       3.00-3.99  prio-3
            2.00-2.99  prio-2       4.00-5.00  prio-4

        Dave's mapping, September 2, 2026; renamed onto the family's shared vocabulary on
        September 11, 2026 (#1842), with the bands themselves untouched -- the mapping is the same
        one, said in the other repos' words. There is deliberately no 'medium': four buckets, and each
        boundary is closed at the bottom and open at the top, so a precision-2 field can never land
        between two of them.

        $null for a task with no score AND for a score outside 1.00-5.00. Neither is guessed at and
        neither is an error: an unscored ticket simply carries no prio label, which is the common case
        rather than the exception -- measured on the BWJ board the day this was written, 28 of 96 open
        tasks had no score at all.
    #>
    param([AllowNull()]$Score)

    if ($null -eq $Score) { return $null }
    $s = [double]$Score
    if ($s -ge 1 -and $s -lt 2) { return 'prio-1' }
    if ($s -ge 2 -and $s -lt 3) { return 'prio-2' }
    if ($s -ge 3 -and $s -lt 4) { return 'prio-3' }
    if ($s -ge 4 -and $s -le 5) { return 'prio-4' }
    return $null
}

function Get-PrioScoreFromTask {
    <#
        The named number field's value from a task object, or $null when the task carries no such
        field or the field is empty. Pure -- no network.

        Asana returns every custom field the task has, each with its own name, so the lookup is a
        match on name rather than a position.

        A field is defined in ONE workspace and does not cross into another, which is what makes the
        name -- not a GID -- the only portable handle. The consequence is on the caller, not here: a
        task living in a project that does not carry this field carries no field by this name at all,
        so a ticket this workflow filed itself scores only when ASANA_PROJECT_GID names a project the
        field has actually been added to -- sitting in the board's workspace is not enough to
        guarantee that. Issue #1213, #1386.
    #>
    param(
        [AllowNull()]$Task,
        [Parameter(Mandatory = $true)][string]$FieldName
    )

    if (-not $Task -or -not $Task.custom_fields) { return $null }
    foreach ($f in $Task.custom_fields) {
        if ($f.name -eq $FieldName) { return $f.number_value }
    }
    return $null
}

function Get-OpenIssues {
    <#
        This repo's open issues with their bodies and their current labels. Returns an empty list
        (not a throw) when `gh` is unavailable or fails, so one broken listing cannot end the run.
    #>
    param([Parameter(Mandatory = $true)][string]$Repo)

    $ErrorActionPreference = 'Continue'
    $raw = (& gh issue list --repo $Repo --state open --limit 200 --json number,body,labels) 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $raw) {
        Write-Host "  Could not list the open issues of $Repo with gh -- the label sweep is skipped."
        return @()
    }
    return @(($raw | Out-String) | ConvertFrom-Json)
}

function Set-IssuePrioLabel {
    <#
        Put EXACTLY ONE prio label on an issue: add -Label if it is missing, and remove whichever of
        the other three the issue carries. That second half is the whole point -- a ticket rescored
        from 2.5 to 4.2 must lose 'prio-2' as it gains 'prio-4', or the issue ends up claiming two
        priorities at once.

        Seven, not three, since #1842: the four PRE-RENAME names are swept off too. Only the ones the
        issue actually carries are ever passed to `gh`, so on a migrated repo that half is free.

        Returns $true when it changed something, $false when the issue already read correctly or the
        edit failed. Nothing is done when there is nothing to do, so a re-run is quiet.

        `gh issue edit` fails outright on a label the repo does not have; adopt-dkj-policy-bwj creates
        all four, which is why that step and this function ship together. On a repo adopted before
        #1842 that step's rename line is what has to have been run: until it has, every add here is
        refused and the run says so per issue. The next daily reconcile repairs the lot, so the cost
        of getting the order wrong is one sweep, not a lost rung.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][int]$Number,
        [Parameter(Mandatory = $true)][string]$Label,
        [string[]]$Current = @()
    )

    $stale = @($script:PrioLabels |
                Where-Object { $_ -ne $Label -and $Current -contains $_ })
    $needsAdd = ($Current -notcontains $Label)
    if (-not $needsAdd -and $stale.Count -eq 0) { return $false }

    $ghArgs = @('issue', 'edit', "$Number", '--repo', $Repo)
    if ($needsAdd) { $ghArgs += @('--add-label', $Label) }
    foreach ($s in $stale) { $ghArgs += @('--remove-label', $s) }

    $ErrorActionPreference = 'Continue'
    & gh @ghArgs 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Could not set '$Label' on $Repo#$Number -- does the repo have all four prio labels?"
        return $false
    }
    $removed = if ($stale.Count) { " (removed $($stale -join ', '))" } else { '' }
    Write-Host "  $Repo#$Number -> $Label$removed"
    return $true
}

function Invoke-LabelSweep {
    <#
        Sweep (c): this repo's OPEN issues, each carrying its Asana task's Prio-Score as one label.

        It walks GITHUB and not the Asana project, deliberately, and that is what separates it from
        sweep (a). Two reasons. It reaches a ticket imported FROM Asana, whose task carries no GitHub
        back-link for a project walk to follow -- the same gap the header-row matcher was added for.
        And it needs no ASANA_PROJECT_GID, so a repo whose project GID is wrong or provisional still
        gets its labels right.

        Priority flows Asana -> GitHub, which is the one direction this system's 'GitHub first' rule
        does not cover and does not contradict: the business sets what matters in the window it looks
        through, and the workbench is where that has to be visible. Nothing here writes to Asana.
    #>
    if (-not $Repo) {
        Write-Host 'GITHUB_REPOSITORY is not set -- the label sweep is skipped.'
        return 0
    }
    $issues = Get-OpenIssues -Repo $Repo
    $scored = 0
    $done   = 0
    foreach ($i in $issues) {
        $ref = Resolve-AsanaTaskRef -IssueBody ([string]$i.body)
        if (-not $ref.Gid) { continue }
        $task = Get-AsanaTaskState -Gid $ref.Gid -Pat $AsanaPat `
                    -OptFields 'completed,name,custom_fields.name,custom_fields.number_value'
        if (-not $task) { continue }
        $label = Get-PrioLabelForScore -Score (Get-PrioScoreFromTask -Task $task -FieldName $PrioFieldName)
        if (-not $label) { continue }
        $scored++
        $current = @($i.labels | ForEach-Object { $_.name })
        if (Set-IssuePrioLabel -Repo $Repo -Number ([int]$i.number) -Label $label -Current $current) { $done++ }
    }
    Write-Host "Label sweep: $($issues.Count) open issue(s) examined, $scored carrying a '$PrioFieldName', $done relabelled."
    return $done
}

function Invoke-StageSweep {
    <#
        Sweep (d): this repo's issues -- open, and closed within the -SinceDays window -- each card
        moved to the stage its issue's state has reached.

        THIS ONE IS NOT A BACKSTOP, and that is what separates it from (a) and (b). A project status
        changes without any `issues:` event firing -- somebody drags a card to In Progress, or a
        built-in project workflow sets Done -- and this workflow subscribes to none of that. So for
        the statuses the daily run IS the mechanism rather than the safety net, and only the close and
        the reopen have an event of their own.

        THE FEEDBACK PROMOTION IS THIS SWEEP'S SAFETY NET RATHER THAN ITS MECHANISM, though. The close
        event posts the comment BEFORE it measures the handoff, so a card normally reaches ReadyToTest
        on the event itself; this sweep catches the ones where that did not happen -- a comment that
        failed, an event that never arrived, or a ticket closed while the board could not be read.
        Either way 'the submitter has been told' is measured from the task's own comments rather than
        assumed from having tried, so a failed comment never hands the card over.

        It walks GitHub rather than the Asana project, for the same two reasons sweep (c) does: it
        reaches a ticket imported FROM the board, whose task carries no GitHub back-link, and it needs
        no ASANA_PROJECT_GID -- the board comes off the task's own memberships.

        Two reads per issue that carries a task: one GraphQL for the issue's state, its linked pull
        requests AND its project status, one Asana GET for the card's current section. An issue with
        no task costs neither, because Resolve-AsanaTaskRef is pure and runs first. A card the status
        has floored at InReview costs two more -- the notes and the comments, for the handoff -- and
        Get-SubmitterHandoff checks every cheap reason to skip before spending either.
    #>
    if (-not $Repo) {
        Write-Host 'GITHUB_REPOSITORY is not set -- the stage sweep is skipped.'
        return 0
    }

    $issues   = @(Get-OpenIssues -Repo $Repo) + @(Get-ClosedIssues -Repo $Repo -SinceDays $SinceDays)
    $moved    = 0
    $carded   = 0
    $unstaged = 0
    foreach ($i in $issues) {
        $ref = Resolve-AsanaTaskRef -IssueBody ([string]$i.body)
        if (-not $ref.Gid) { continue }
        $carded++
        $link = Get-IssueLinkState -Repo $Repo -Number ([int]$i.number) `
                    -StatusField ([string]$script:StatusMap.FieldName)
        if (-not $link.State) { continue }
        $hasPr = (@($link.PullRequests).Count -gt 0)
        $floor = Get-StageFloorForIssue -State $link.State -StateReason $link.StateReason `
                     -ProjectStatus $link.ProjectStatus -StatusMap $script:StatusMap -Map $script:StageMap `
                     -HasLinkedPullRequest:$hasPr
        $hand = Get-SubmitterHandoff -Gid $ref.Gid -IssueRef "$Repo#$($i.number)" -Pat $AsanaPat -Floor $floor `
                    -StatusMap $script:StatusMap -Map $script:StageMap -Labels $link.Labels
        $target = Resolve-TargetStage -State $link.State -StateReason $link.StateReason `
                      -ProjectStatus $link.ProjectStatus -Labels $link.Labels `
                      -StatusMap $script:StatusMap -Map $script:StageMap `
                      -Submitter $hand.Submitter -SubmitterTold:$hand.Told `
                      -HasLinkedPullRequest:$hasPr
        if ($null -eq $target.Stage) { $unstaged++ }
        if (Sync-AsanaTaskStage -Gid $ref.Gid -TargetStage $target.Stage -Pat $AsanaPat `
                -Map $script:StageMap -For "$Repo#$($i.number)" -Why $target.Why `
                -AllowBackward:$target.AllowBackward) { $moved++ }
    }
    Write-Host "Stage sweep: $($issues.Count) issue(s) examined, $carded carrying an Asana task, $moved card(s) moved."

    # AND ONE LINE WHEN THE WHOLE RUN DERIVED NOTHING (inbound #1536). Silence is what made that issue
    # expensive: a per-issue note scrolls past, and 'N card(s) moved' reads the same on a quiet day as
    # on a run that could not answer for a single ticket. This says which of the two it was, once, and
    # only when every carded issue came back with no stage -- the shape of a configuration fault rather
    # than of a board that happens to be up to date. A partial figure is deliberately not reported: one
    # issue off the pipeline is the design working, and a line that fired on it would be noise daily.
    if ($carded -gt 0 -and $unstaged -eq $carded) {
        Write-Host "  NOTHING WAS STAGED: all $carded carded issue(s) derived no stage at all, so no card can move. That is a configuration fault, not a quiet day -- read the per-issue lines above for which of the three it is: the project field could not be read (set GH_PROJECT_TOKEN), the board's columns are not named in Get-GithubStatusMap, or this repo has no board and has not said so (an empty FieldName says it)."
    }
    return $moved
}

function Invoke-ReconcileMode {
    if (-not $AsanaPat) { throw 'ASANA_PAT is not set.' }
    $done = 0
    $done += Invoke-ReconcileFromAsana
    $done += Invoke-ReconcileFromGitHub
    Write-Host "Reconciliation done -- $done task(s) updated, 0 completed (this script completes nothing)."

    # Sweep (c) reports separately: it relabels ISSUES, where the two above update TASKS, and one
    # count covering both would say neither.
    $labelled = Invoke-LabelSweep
    Write-Host "Prio labels done -- $labelled issue(s) relabelled."

    # And (d) again separately: it moves CARDS. Three counts, three claims -- a single total would
    # let a quiet day and a broken sweep read the same.
    $staged = Invoke-StageSweep
    Write-Host "Stage sections done -- $staged card(s) moved, still 0 completed."
}

function Invoke-Main {
    # Resolved once, before either mode, so the run says which map it used exactly once and every
    # move afterwards is against the same answer.
    $script:StageMap  = Resolve-AsanaStageMap -RepoRoot $RepoRoot
    $script:StatusMap = Resolve-GithubStatusMap -RepoRoot $RepoRoot
    switch ($Mode) {
        'event'     { Invoke-EventMode }
        'reconcile' { Invoke-ReconcileMode }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Main
}
