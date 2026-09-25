<#
.SYNOPSIS
    The judgement behind hooks/guard-asana-mirror.ps1: which GitHub issues an Asana create-task call
    mirrors, and whether each one carries the reach label that admits it to the board.

.DESCRIPTION
    WHY THIS EXISTS (inbound #2482). report-issue's step 2 opens with "Only for an issue carrying the
    reach label" since #2360, and that sentence was the whole of the gate: report-issue has no script,
    and the Asana create-task tool is available to a session whatever step 1 decided. Measured
    September 25, 2026, on the fixed plugin version: BWJ-Development/smartwatchbanden#770 was filed
    with only `documentation` -- a developer-only lint fix -- and still got a card, whose marker then
    made the PR that fixed it unable to close it on merge. The second measured miss of one rule, so
    the rule moves from memory to a hook.

    Split from the hook so the decision is testable without a payload on stdin and a process per case,
    the same split guard-working-copy.ps1 makes with working-copy-guard-lib.ps1.

    WHAT COUNTS AS A MIRROR is a GitHub issue URL anywhere in the call's tool_input, on a repo this
    procedure is admitted in. report-issue writes that URL twice -- the `Tracked on GitHub:` line and
    the optional `Github Issue` custom field -- so a mirror carries it by construction, and a task that
    cites no issue of an admitted repo is not a mirror and is none of this gate's business. The repo
    list is report-issue's own "Before you start" list, matched on the NAME for the reason stated there:
    the two stores are no longer in one organisation.

    Pure ASCII (repo convention for .ps1).
#>

# The repos report-issue admits, by NAME -- see "Before you start" in skills/report-issue/SKILL.md.
$script:AsanaMirrorAdmittedRepos = @('smartwatchbanden', 'xoxowildhearts', 'dkj-claude-plugins')

function Get-MirroredIssueRefs {
    <#
        Every distinct GitHub issue on an admitted repo that $Text cites as a URL, as objects with
        Owner, Repo, Number and Ref ('owner/repo#n'). The character classes are GitHub's own for an
        owner and a repo name, so nothing outside them reaches a gh argument or a printed line.
    #>
    param([string]$Text)
    $refs = [ordered]@{}
    if (-not $Text) { return @() }
    $pattern = 'github\.com/([A-Za-z0-9-]+)/([A-Za-z0-9._-]+)/issues/([0-9]+)'
    foreach ($m in [regex]::Matches($Text, $pattern)) {
        $owner = $m.Groups[1].Value
        $repo  = $m.Groups[2].Value
        if ($script:AsanaMirrorAdmittedRepos -notcontains $repo.ToLowerInvariant()) { continue }
        $ref = "$owner/$repo#$($m.Groups[3].Value)"
        if (-not $refs.Contains($ref.ToLowerInvariant())) {
            $refs[$ref.ToLowerInvariant()] = [pscustomobject]@{
                Owner = $owner; Repo = $repo; Number = [int]$m.Groups[3].Value; Ref = $ref
            }
        }
    }
    return @($refs.Values)
}

function Get-AsanaMirrorToolInputText {
    <#
        The tool_input of a PreToolUse payload as one string to search, or '' when the payload does not
        parse. Re-serialised rather than searched raw, so the URL is matched in its decoded form
        whichever way the harness escaped it.
    #>
    param([string]$Raw)
    if (-not $Raw) { return '' }
    try { $payload = $Raw | ConvertFrom-Json } catch { return '' }
    if ($null -eq $payload -or $null -eq $payload.tool_input) { return '' }
    return ($payload.tool_input | ConvertTo-Json -Depth 20 -Compress)
}

function Get-AsanaMirrorVerdict {
    <#
        One issue's verdict from its labels. $Labels is $null when they could not be read -- which is
        'unknown', never 'missing': a failed read is not evidence that the label is absent.

        Returns 'admit' (the reach label is on it), 'refuse' (read, and not on it) or 'unknown'.
        The comparison is case-insensitive, as GitHub's own label matching is.
    #>
    param([AllowNull()][string[]]$Labels, [Parameter(Mandatory = $true)][string]$ReachLabel)
    if ($null -eq $Labels) { return 'unknown' }
    foreach ($l in $Labels) { if ($l -and $l.Trim() -ieq $ReachLabel) { return 'admit' } }
    return 'refuse'
}

function ConvertFrom-GhIssueLabels {
    <#
        The label names out of `gh issue view --json labels` output, or $null when it is not that
        shape. An issue with no labels is an EMPTY array, which is a real answer, not $null.
    #>
    param([string]$Json)
    if (-not $Json) { return $null }
    try { $obj = $Json | ConvertFrom-Json } catch { return $null }
    if ($null -eq $obj -or -not ($obj.PSObject.Properties.Name -contains 'labels')) { return $null }
    return ,([string[]]@($obj.labels | ForEach-Object { [string]$_.name }))
}
