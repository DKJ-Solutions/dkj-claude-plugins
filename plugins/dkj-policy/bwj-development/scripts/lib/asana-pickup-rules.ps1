<#
.SYNOPSIS
    The judgement behind hooks/asana-link-pickupcheck.ps1: which issue a shell command just picked up,
    and whether that issue, when it came FROM Asana, links its task. Pure: no network, no git, no gh.

.DESCRIPTION
    INBOUND #2919 (from BWJ-Development/xoxowildhearts, October 12, 2026). A colleague's Asana bug became
    xoxowildhearts#404 through a plain `gh issue create`, with no `<!-- asana-task: <gid> -->` marker, no
    `| **Asana** |` header row and no task URL -- only the prose "Reported by Jordy via Asana". The issue
    then ran claim, branch, PR and go-live block, and nothing noticed: the one place the link for a
    ticket from Asana is written is report-issue's "On a ticket that came the other way", a sentence a
    session has to remember. guard-asana-mirror passes such a ticket by construction (it fires on a
    CREATE, and a ticket from Asana creates none), and dkj-policy's claim-issue and new-branch are
    repo-agnostic, so they cannot know what Asana is. So the check is this plugin's, at the moment the
    work is picked up -- the moment section 8 already has the session read the task.

    A WARNING, NOT A REFUSAL. The evidence that an issue came from Asana is a word in its title or body,
    and a word is not proof; a refusal on it would block a GitHub-only issue that merely mentions the
    board. The cost of a missed link is the requester hearing nothing at the close, and a loud warning
    at pickup is early enough to repair it. The close side -- build-golive-block checking the link
    before it promises the closed message -- is the companion inbound, #2918.

    THE LINK IS WHATEVER Resolve-AsanaTaskRef RESOLVES -- the marker, the header row, or a sole task URL
    -- because that is what asana-closed-message, build-backlog-page and the release note read. A second
    rule here about what counts as linked could only disagree with them.

    Pure ASCII (repo convention for .ps1).
#>

. (Join-Path $PSScriptRoot 'asana-task-lib.ps1')

function Get-PickupIssueNumber {
    <#
        The issue number a shell command picks up, or $null. Two commands count: claim-issue.ps1 with a
        number (a claim, a -Tag claim, a -Verify or a -TakeOver) and new-branch.ps1 with a branch named
        <prefix>/<n>-<name>. claim-issue's -Candidates, -Release and -ReleaseAll pick nothing up, so
        they answer $null -- a release is the moment a session lets go of the work.
    #>
    param([AllowEmptyString()][AllowNull()][string]$Command)

    $c = [string]$Command
    if ($c -match 'claim-issue\.ps1') {
        if ($c -match '(?i)\s-(Candidates|Release|ReleaseAll)\b') { return $null }
        $m = [regex]::Match($c, 'claim-issue\.ps1["'']?\s+#?([0-9]{1,9})\b')
        if ($m.Success) { return [int]$m.Groups[1].Value }
        return $null
    }
    if ($c -match 'new-branch\.ps1') {
        $m = [regex]::Match($c, '(?i)-Name\s+["'']?[a-z]+/([0-9]{1,9})-')
        if ($m.Success) { return [int]$m.Groups[1].Value }
    }
    return $null
}

function Get-AsanaPickupVerdict {
    <#
        What an issue says about its Asana task: 'linked' (Resolve-AsanaTaskRef finds one), 'ambiguous'
        (several task URLs and no marker or header row to choose between them), 'unlinked' (none, while
        the title or body names Asana) or 'github-only' (none, and no mention of Asana -- the ordinary
        issue, which stays silent).
    #>
    param(
        [AllowEmptyString()][AllowNull()][string]$Title,
        [AllowEmptyString()][AllowNull()][string]$IssueBody
    )

    $ref = Resolve-AsanaTaskRef -IssueBody ([string]$IssueBody)
    if ($ref.Source -eq 'ambiguous') { return 'ambiguous' }
    if ($ref.Gid) { return 'linked' }
    if ("$Title`n$IssueBody" -match '(?i)\basana\b') { return 'unlinked' }
    return 'github-only'
}

function Format-AsanaPickupWarning {
    <#
        The text the hook hands the session for a verdict, or '' where there is nothing to say. Only the
        number and fixed text: nothing from the issue's title or body is echoed, because anybody who can
        open an issue writes those.
    #>
    param(
        [Parameter(Mandatory = $true)][int]$Number,
        [Parameter(Mandatory = $true)][string]$Verdict
    )

    $why = switch ($Verdict) {
        'unlinked'  { "names Asana but links no Asana task" }
        'ambiguous' { "carries several Asana task URLs and no marker or '| **Asana** |' row saying which is its own" }
        default     { return '' }
    }
    return (@(
        "ASANA LINK MISSING (asana-link-pickupcheck, #2919): issue #$Number $why.",
        "If it came FROM an Asana task, link the two now, before any work: report-issue's 'On a ticket that",
        "came the other way' -- put <!-- asana-task: <gid> --> in the issue body, and 'Tracked on GitHub:",
        "<issue URL>' on top of the task's description. Without that the requester hears nothing when it",
        "ships: asana-closed-message, the backlog page and the release note all read this issue as unlinked.",
        "If it did not come from Asana, nothing is needed."
    ) -join "`n")
}
