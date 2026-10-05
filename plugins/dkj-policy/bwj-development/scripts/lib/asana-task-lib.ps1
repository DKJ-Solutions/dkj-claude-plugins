<#
.SYNOPSIS
    The Asana task helpers this plugin's task scripts still share now that the asana-mirror CI
    workflow is retired: which Asana task an issue body links (Resolve-AsanaTaskRef), reading that
    task (Get-AsanaTaskState), and the marker and lead of the go-live block an issue comment carries
    (Get-AsanaPasteBlockMarker, Get-AsanaPasteBlockLead, Test-AsanaPasteBlockPosted).

.DESCRIPTION
    MOVED OUT OF templates/asana-mirror.ps1 WHEN THAT TEMPLATE WAS RETIRED (Dave, October 5, 2026).
    build-backlog-page.ps1 and build-golive-block.ps1 used to dot-source the whole CI template for these
    few pure helpers; with the template gone they live here, beside the other libs those two scripts
    already load. Nothing in this file writes to Asana: Get-AsanaTaskState only reads, and the go-live
    block now stays on the GitHub issue -- a colleague who wants it in the Asana task pastes it there.

    Console text goes through ConvertTo-ConsoleStrippedText from ref-print-lib.ps1, dot-sourced below,
    rather than a private copy: the template carried its own copy only because it shipped standalone
    into a consumer's .github/scripts/, and this lib does not.

    STILL SELF-CONTAINED: this file lives inside bwj-development's own scripts\lib\, so a script that
    dot-sources it is not reaching into a second plugin's libs.

    Pure ASCII (repo convention for .ps1).
#>

. (Join-Path $PSScriptRoot 'ref-print-lib.ps1')

$script:AsanaApiBase = 'https://app.asana.com/api/1.0'

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

function Get-AsanaTaskState {
    <#
        Read a task's 'completed' flag. Returns $null when the task cannot be read -- it was deleted,
        or it lives in a workspace this PAT has no access to. That is reported and skipped rather
        than thrown, so one unreachable ticket cannot end a run over all of them.

        Read-only: nothing in this lib writes to Asana.
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
        Write-Host "  Asana task $Gid is not readable with this token ($(ConvertTo-ConsoleStrippedText -Text $_.Exception.Message)) -- skipped."
        return $null
    }
}

function Get-AsanaPasteBlockMarker {
    <#
        The machine marker build-golive-block.ps1 puts on the paste-ready block's GitHub comment. Pure.

        An HTML comment, for the same reason the asana-task link uses one: it is the only form that
        cannot be misread, and it renders as nothing. It sits in the FRAMING text and never inside
        the block itself, because the block is pasted into Asana and a marker that travelled with it
        would arrive there as visible junk.
    #>
    return '<!-- asana-paste-block -->'
}

function Get-AsanaPasteBlockLead {
    <#
        The block's own opening sentence -- the prose half of the de-duplication below, and the
        second matcher for a block a person typed rather than pasted. Pure.
    #>
    return 'Fill in the link below and paste the block into the Asana task'
}

function Test-AsanaPasteBlockPosted {
    <#
        Has a paste-ready block already been written on this issue? Reads the issue's comments and
        looks for the marker, or -- for a block somebody typed by hand -- the lead sentence this
        script writes. The same two-matcher shape, and the same ordering, as the task link itself:
        the machine marker first and unconditionally, prose second.

        AN UNREADABLE ISSUE ANSWERS $true, so a run that cannot check does not comment blindly. The
        cost of each mistake is what settles it: a skipped post can be repeated with -Force once the
        comments are readable again, while a blind post puts a second copy underneath a block that
        was already there.

        A LOOSE SUBSTRING MATCH, AND ANYBODY WHO CAN COMMENT CAN SUPPRESS THIS. Either matcher
        anywhere in any comment answers $true -- including a comment that QUOTES WORKFLOW-portable.md,
        which publishes both strings verbatim so a session can write the block by hand. That is
        accepted rather than tightened: build-golive-block.ps1 -Force posts regardless. Tightening
        it (an exact whole-comment compare, or an author check) would buy nothing against a person who can equally well delete
        the real block, and would cost the hand-written case the marker exists to serve.
    #>
    param([Parameter(Mandatory = $true)][string]$IssueRef)

    $parts = $IssueRef -split '#'
    $ErrorActionPreference = 'Continue'
    $raw = & gh issue view $parts[1] --repo $parts[0] --json comments 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $raw) {
        Write-Host "  Comments of $IssueRef are not readable -- no paste-ready block posted, rather than posting one blindly."
        return $true
    }
    try { $comments = (($raw | Out-String) | ConvertFrom-Json).comments } catch {
        Write-Host "  Comments of $IssueRef did not parse -- no paste-ready block posted, rather than posting one blindly."
        return $true
    }

    $marker = Get-AsanaPasteBlockMarker
    $lead   = Get-AsanaPasteBlockLead
    foreach ($c in @($comments)) {
        $body = [string]$c.body
        if (-not $body) { continue }
        if ($body.Contains($marker) -or $body.Contains($lead)) { return $true }
    }
    return $false
}
