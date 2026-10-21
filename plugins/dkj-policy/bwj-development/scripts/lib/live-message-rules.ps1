<#
.SYNOPSIS
    The decisions behind the LIVE MESSAGE -- the one Asana comment that tells a requester their work
    has actually gone out with a release (#3070). Which issues a release carries, which of them are
    owed the message, which language its ask is in, and the message itself. Pure: no network, no
    filesystem, no git, no gh, no Asana.

.DESCRIPTION
    Dot-sourced by notify-live.ps1 beside it, for the split every other task script in this plugin
    makes: the driver reads git and gh and posts to Asana, and what can be WRONG -- which issue is told,
    what it is told -- is a pure function over values the driver has already read.

    THE GAP IT CLOSES (#3070, Maikel, October 16, 2026). An issue built but visible only after a release
    closes as completed at the PR step, and its closed message says it becomes visible with the release
    named below (#3069). Nothing told the task when that release had actually gone out: the closed
    message posts once, before the release, and the cut posts nothing on a task. So the requester read
    "visible on <release day>" and had to work out for themselves whether that day's release carried
    their work.

    WHY A STEP A PERSON RUNS, AND NOT THE CUT OR A RELEASE WORKFLOW (Maikel's decision on #3070). In
    this procedure the live push is never run by a script -- it is printed for a person to run -- so
    nothing automated knows the moment a release IS live, and that moment is what the message claims.
    A step in the cut, or a 'release: published' workflow, would post "live" whenever it runs, and the
    store could still be showing the old theme. A step run after the push and the cut is the one whose
    timing is true by construction. prepare-release's runbook prints it as the step after the cut, so
    it is not forgotten.

    WHO IS OWED IT: AN ISSUE TOLD "VISIBLE WITH THE RELEASE", AND NO OTHER. The newest go-live block
    on the issue (the one the closed message carried, Test-AsanaPasteBlockBody) must carry
    Get-AsanaReleaseBlockMarker. That one marker is what made the closed message say the result becomes
    visible with the release, so it is exactly the set of requesters waiting for this message. It skips
    the rest by construction: a -LiveSince block (already told 'live' at the close, 1a), a research
    block (nothing changed), and a block from before the marker existed.

    WHOSE BLOCK IT JUDGES (security review, #3070). Any commenter's, unlike the closed message, which
    carries a block only from a trusted author: the session-side read (Read-AsanaIssueBlockState) returns
    no author. That is accepted because NOTHING FROM THE BLOCK IS POSTED -- the live message is fixed text
    plus the issue's number and the version -- so the worst a forged block can do is send that fixed
    "is now live" to a task of an issue the release really did close. The dry run lists every issue
    before -Post, and the task is still the one the issue body's own marker names.

    Pure ASCII (repo convention for .ps1).
#>

function Get-LiveMessageMarker {
    <#
        The marker notify-live.ps1 -Post leaves on the GITHUB issue once the live message is posted on
        its task. Pure. A second run over the same release finds it and skips that issue, so the
        requester is told once. An HTML comment, for the reason every other marker here is one: it
        renders as nothing and cannot be misread.

        ANYBODY WHO CAN COMMENT CAN SUPPRESS THE MESSAGE WITH IT, and that is accepted, as
        Test-AsanaPasteBlockPosted accepts it for the block: a person who can comment can equally well
        delete the block the message depends on, and the cost of a suppressed message is a requester
        who asks, never one who is told something false.
    #>
    return '<!-- asana-live-message -->'
}

function Get-ReleaseRangePullNumbers {
    <#
        Pure: the pull-request numbers named in the subjects of a release range's commits, distinct, in
        the order first seen. A CANDIDATE list, never the answer: the driver keeps a number only where
        that PR is merged and its merge commit is in the range, because a subject can name any number
        ('fixes the regression from #12'). Every '#<n>' is read, so a merge commit's '(#NN)', GitHub's
        'Merge pull request #NN' and a squash title's '(#NN)' are all found whatever form a store merges in.
    #>
    param([AllowNull()][AllowEmptyCollection()][string[]]$Subjects)
    $seen = New-Object 'System.Collections.Generic.List[int]'
    foreach ($s in @($Subjects)) {
        if ($null -eq $s) { continue }
        foreach ($m in [regex]::Matches([string]$s, '#(\d{1,9})\b')) {
            $n = [int]$m.Groups[1].Value
            if ($n -gt 0 -and -not $seen.Contains($n)) { $seen.Add($n) }
        }
    }
    return @($seen)
}

function Get-PullChangedPaths {
    <#
        Pure: the paths one merged PR changed, for the live-push record (#3190), as @{ Paths; Complete }.
        -DiffPaths is `git diff <merge>^1 <merge>`, -PullFiles and -ChangedFiles are gh's `files` and
        `changedFiles` for the PR, -ParentCount is the merge commit's number of parents.

        THE DIFF ALONE MISSES A REBASE-MERGE. It is the whole PR for a merge commit and for a squash, but a
        rebase-merge's merge commit is the LAST rebased commit only, so a path an earlier commit of the PR
        touched is not in it -- and a held path that is not seen tells the requester 'live'. gh's file list
        is the PR's whole change whatever the method, but it is capped (100 files), so neither source alone
        is the answer: the union is, and where gh's list is short of changedFiles and the merge is not a
        two-parent merge commit, the paths are not Complete and the driver reads the PR as unread.
    #>
    param(
        [AllowNull()][AllowEmptyCollection()][string[]]$DiffPaths,
        [AllowNull()][AllowEmptyCollection()][string[]]$PullFiles,
        [int]$ChangedFiles = 0,
        [int]$ParentCount = 1
    )
    $set = New-Object 'System.Collections.Generic.List[string]'
    foreach ($p in @(@($DiffPaths) + @($PullFiles))) {
        if (-not $p -or -not ([string]$p).Trim()) { continue }
        $t = ([string]$p).Trim()
        if (-not $set.Contains($t)) { $set.Add($t) }
    }
    $pullCount = @(@($PullFiles) | Where-Object { $_ -and ([string]$_).Trim() }).Count
    $complete = ($ParentCount -ge 2) -or ($pullCount -ge $ChangedFiles)
    return @{ Paths = @($set); Complete = [bool]$complete }
}

function Get-PreviousReleaseTag {
    <#
        Pure: the highest vX.Y.Z tag BELOW -Version, compared as versions (the reason
        Get-HighestReleaseTag is a function: lexically, v2.9.0 sorts above v2.44.0). '' where there is
        none -- the first release, whose range has no start this script would guess at.
    #>
    param(
        [AllowNull()][AllowEmptyCollection()][string[]]$Tags,
        [Parameter(Mandatory = $true)][string]$Version
    )
    if ($Version -notmatch '^v(\d+)\.(\d+)\.(\d+)$') { return '' }
    $target = [version]"$($Matches[1]).$($Matches[2]).$($Matches[3])"
    $below = @(foreach ($t in @($Tags)) {
        if ($null -eq $t) { continue }
        $tag = ([string]$t).Trim()
        if ($tag -match '^v(\d+)\.(\d+)\.(\d+)$' -and [version]"$($Matches[1]).$($Matches[2]).$($Matches[3])" -lt $target) { $tag }
    })
    return (Get-HighestReleaseTag -Tags $below)
}

function Get-LiveMessageLanguage {
    <#
        Pure: the language of the go-live block's sections -- 'nl' or 'en' -- read from the headings
        Get-GoLiveBlockText writes, so the live message's ask is in the language the requester's closed
        message already was. -Default where neither heading set is there.
    #>
    param(
        [AllowEmptyString()][string]$Sections,
        [ValidateSet('nl', 'en')][string]$Default = 'nl'
    )
    foreach ($lang in @('nl', 'en')) {
        $t = Get-GoLiveBlockText -Language $lang
        foreach ($h in @($t.Ask, $t.When, $t.WhenLive, $t.Where, $t.Changed)) {
            if (([string]$Sections) -cmatch "(?m)^\s*$([regex]::Escape($h))\s*$") { return $lang }
        }
    }
    return $Default
}

function Get-LiveMessageVerdict {
    <#
        Pure: is this issue owed the live message? Returns { Owed; Gid; Language; Reason }. -Issue is an
        object with Number, State ('OPEN'/'CLOSED'), StateReason ('COMPLETED', 'NOT_PLANNED', ...),
        Body, Comments (Body, CreatedAt, oldest first) and LastReopenedAt, as the driver read them.

        IN ORDER, AND EACH REFUSAL NAMES ITS REASON so the dry run reads as a list a person can check:
          - not closed as completed: an issue reopened since is back in development, and one closed as
            not planned was never built;
          - no single task: the same Resolve-AsanaTaskRef the closed message found the task with, so the
            live message goes to the task that message went to, and never to a guessed one;
          - already told: Get-LiveMessageMarker is on the issue after its last reopen;
          - no block, or a block from before the last reopen: the closed message carried no block for
            this round, so what the requester was told cannot be read here;
          - a block without the after-release marker: a -LiveSince block was told 'live' at the close,
            a research block changed nothing, and an older block never said it was waiting on a release.
    #>
    param([Parameter(Mandatory = $true)]$Issue)

    $no = { param($why) [pscustomobject]@{ Owed = $false; Gid = $null; Language = ''; Reason = $why } }

    if ([string]$Issue.State -ne 'CLOSED' -or ([string]$Issue.StateReason -and [string]$Issue.StateReason -ne 'COMPLETED')) {
        return (& $no 'not closed as completed')
    }
    $ref = Resolve-AsanaTaskRef -IssueBody ([string]$Issue.Body)
    if (-not $ref.Gid) { return (& $no $(if ($ref.Source -eq 'ambiguous') { 'links more than one Asana task' } else { 'links no Asana task' })) }

    $comments = @($Issue.Comments | Where-Object { $null -ne $_ })
    $reopen = if ($null -ne $Issue.LastReopenedAt) { ConvertTo-AsanaInstant -Value $Issue.LastReopenedAt } else { $null }
    $marker = Get-LiveMessageMarker
    foreach ($c in $comments) {
        if (-not ([string]$c.Body).Contains($marker)) { continue }
        $at = ConvertTo-AsanaInstant -Value $c.CreatedAt
        # A time that cannot be read counts as this round's: the cautious answer for a duplicate check.
        if ($null -eq $reopen -or $null -eq $at -or $at -gt $reopen) { return (& $no 'already told it is live') }
    }

    $verdict = Get-AsanaPasteBlockVerdict -Comments $comments -LastReopenedAt $Issue.LastReopenedAt
    if ($verdict -eq 'none') { return (& $no 'carries no go-live block') }
    if ($verdict -ne 'fresh' -and $verdict -ne 'not-reopened') { return (& $no "its newest go-live block is not this round's ($verdict)") }

    $chosen = $null
    foreach ($c in $comments) { if (Test-AsanaPasteBlockBody -Body ([string]$c.Body)) { $chosen = $c } }
    $body = [string]$chosen.Body
    if (-not $body.Contains((Get-AsanaReleaseBlockMarker))) {
        $why = if ($body.Contains((Get-AsanaHandBlockMarker))) { 'by-hand record -- its messages are written by hand (#3183)' } elseif ($body.Contains((Get-AsanaResearchBlockMarker))) { 'research block -- nothing went live' } elseif ($body.Contains((Get-AsanaMeasureBlockMarker))) { 'measurement block -- the requester measures it, nothing is told live (#3179)' } else { 'its block was not waiting on a release (-LiveSince, or written before #3069)' }
        return (& $no $why)
    }
    $lang = Get-LiveMessageLanguage -Sections (Get-PasteBlockSections -Body $body)
    return [pscustomobject]@{ Owed = $true; Gid = $ref.Gid; Language = $lang; Reason = 'told it becomes visible with the release' }
}

function Get-LiveMessageLines {
    <#
        Pure: the live message as plain lines -- the automation's header, the live line, and the go-live
        block's own closing ask. The header and the live line are fixed and English on every board, like
        the closed line (#2656, #2700); only the state word is bold (#2909). The ask is the block's
        heading and its yes and no sentences, in the block's language, because it is the same question
        the requester was asked: the look-sentence is left out, since it points at 'the link above' and
        this message carries none -- the live line says the review can start.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$IssueRef,
        [Parameter(Mandatory = $true)][string]$Version,
        [ValidateSet('nl', 'en')][string]$Language = 'nl'
    )
    $t = Get-GoLiveBlockText -Language $Language
    $ver = if ($Version -match '^v') { $Version } else { "v$Version" }
    return @(
        $t.Header,
        '',
        "GitHub issue $IssueRef is now **live**, as version ${ver}: the review can start now.",
        '',
        $t.Ask,
        $t.AskYes,
        '',
        $t.AskNo
    )
}

function New-LiveMessageHtml {
    <#
        Pure: the live message as Asana html_text -- the closed message's form (New-ClosedMessageHtml):
        the issue name as a link, only the state word in <strong>, the ask's heading in <strong>, every
        other character XML-escaped, because a malformed body is answered 400 and the requester is told
        nothing. Only <body>, <a> and <strong>, all on Asana's allow-list for a story.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$IssueRef,
        [Parameter(Mandatory = $true)][string]$Version,
        [ValidateSet('nl', 'en')][string]$Language = 'nl'
    )
    if ($IssueRef -notmatch '\A([A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9._-]+)#(\d+)\z') { throw "New-LiveMessageHtml: '$IssueRef' is not owner/repo#<n>." }
    $url = "https://github.com/$($Matches[1])/issues/$($Matches[2])"
    $esc = { param($s) ConvertTo-AsanaXmlText -Text $s }
    $t   = Get-GoLiveBlockText -Language $Language
    $ver = if ($Version -match '^v') { $Version } else { "v$Version" }
    $html = "<body>$(& $esc $t.Header)`n`nGitHub issue <a href=`"$(& $esc $url)`">$(& $esc $IssueRef)</a> is now <strong>live</strong>$(& $esc ", as version ${ver}: the review can start now.")" +
        "`n`n<strong>$(& $esc $t.Ask)</strong>`n$(& $esc $t.AskYes)`n`n$(& $esc $t.AskNo)</body>"
    return $html
}

function ConvertTo-AsanaXmlText {
    <#
        Pure: text made safe for Asana html_text -- the C0 controls XML forbids dropped, then &, <, > and
        " escaped. The same rule as templates/asana-closed-message.ps1's function of this name, which
        ships standalone and so cannot be loaded from here.
    #>
    param([AllowEmptyString()][string]$Text)
    $clean = [regex]::Replace([string]$Text, '[\x00-\x08\x0B\x0C\x0E-\x1F]', '')
    return $clean.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;')
}

function Format-LiveMessageIssueComment {
    <#
        Pure: the GitHub comment notify-live.ps1 -Post leaves on the issue once its task was told --
        the marker, and one sentence a reader of the issue can check against the task.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Version,
        [Parameter(Mandatory = $true)][string]$Gid
    )
    if ($Gid -notmatch '\A[0-9]+\z') { throw "Format-LiveMessageIssueComment: non-numeric task GID." }
    $ver = if ($Version -match '^v') { $Version } else { "v$Version" }
    return "$(Get-LiveMessageMarker)`nThe Asana task (https://app.asana.com/0/0/$Gid) was told this is live as of $ver (notify-live)."
}
