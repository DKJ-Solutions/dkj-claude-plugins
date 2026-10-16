<#
.SYNOPSIS
    PreToolUse hook on the shell tools: asks a person before 'gh issue reopen' reopens an issue that
    links an Asana task, so the reopen stops being automatic (#3076). Every other reopen passes untouched.

.DESCRIPTION
    INBOUND #3076, SPLIT OFF #3073. Reopening an Asana-linked issue posts a message on its task, and that
    message reaches the colleague who asked. A reopen is right only when repo code will change for the
    issue; research, a question or an answer belongs in a comment. The rule said so in prose (#2856, then
    #3073's sharper text), and a session on smartwatchbanden#395 still reopened. A hook cannot tell
    whether a repo file will change, so it does not refuse: it returns permissionDecision 'ask', and the
    person in the session confirms that code work is planned (Maikel's decision on #3076, October 16,
    2026: option 2, scoped to Asana-linked issues).

    WHICH ISSUES. The ones the command reopens (Get-IssueReopenInvocation in
    stale-paste-block-rules.ps1, an invocation and not a mention), read with Read-AsanaIssueBlockState --
    the same one bounded GraphQL call guard-stale-paste-block.ps1 makes, whose reply carries the issue
    body. An issue whose body links one Asana task (Resolve-AsanaTaskRef, the workflow's own matcher) is
    asked about -- including one listing several, where its asana-task marker or Asana header row names
    its own. One linking no task, or several bare task URLs with neither, passes silently, because the
    workflow posts nothing for it.

    AN UNREAD ISSUE IS ASKED ABOUT TOO. gh absent, logged out, slow, or a reply that does not parse: the
    hook cannot tell whether a task is linked, and asking costs one confirmation while a wrong pass costs
    the message. So the ask names what could not be read. A missing lib or an unexpected throw takes the
    same route.

    AN ACCIDENT GUARD, NOT AN ADVERSARIAL ONE, with the parser's reach (see its lib header): pwsh
    -Command "...", 'gh api ... state=open', a value from a variable or a wrapper are out of reach.

    WHAT IT PRINTS is its own text and issue refs the parser's regex built from GitHub's owner/name
    character classes -- never a title, a body or a comment.

    ONE TIME BUDGET for every read, 25s under hooks.json's 30s ceiling.

    Exit codes (PreToolUse contract): 0 always; the 'ask' is PreToolUse JSON on stdout.

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/guard-stale-paste-block.tests.ps1 in
    the source repo, beside the close guard whose parser and reader it shares -- change one, run the other.
#>
$ErrorActionPreference = 'Stop'

# READ STDIN ONLY WHERE THERE IS A HANDLE, the guard every hook in this tree carries (#2264).
$raw = ''
if ([Console]::IsInputRedirected) { $raw = [Console]::In.ReadToEnd() }

# THE CHEAP PRE-GATE, the same test hooks.json makes in shell first.
if ($raw -notmatch 'gh(\.exe)?\s+issue\s+reopen') { exit 0 }

function Exit-Ask {
    <# exit 0 with permissionDecision 'ask': the reason for the person, the same text for the model. #>
    param([string]$Reason)
    $out = @{ hookEventName = 'PreToolUse'; permissionDecision = 'ask'; permissionDecisionReason = $Reason; additionalContext = $Reason }
    [Console]::Out.WriteLine((@{ hookSpecificOutput = $out } | ConvertTo-Json -Compress))
    exit 0
}

$notRead = 'It could not tell whether the issue links an Asana task: confirm that repo code will change for it before reopening; research, a question or an answer belongs in a comment instead (#3076).'

foreach ($lib in @('asana-task-lib.ps1', 'stale-paste-block-rules.ps1')) {
    $libPath = Join-Path $PSScriptRoot "..\scripts\lib\$lib"
    if (-not (Test-Path -LiteralPath $libPath -PathType Leaf)) { Exit-Ask "guard-issue-reopen: $lib not found beside this hook. $notRead" }
    . $libPath
}

trap { Exit-Ask "guard-issue-reopen: an unexpected error stopped the check. $notRead" }

# A BYTE-ORDER MARK IS NOT PART OF THE PAYLOAD (see guard-stale-paste-block.ps1): whatever precedes the
# first '{' is dropped.
$jsonText = [string]$raw
$brace = $jsonText.IndexOf('{')
if ($brace -gt 0) { $jsonText = $jsonText.Substring($brace) }
$command = ''
try { $command = [string](($jsonText | ConvertFrom-Json).tool_input.command) } catch { Exit-Ask "guard-issue-reopen: the hook payload did not parse as JSON. $notRead" }

$reopen = Get-IssueReopenInvocation -Command $command
if ($null -eq $reopen) { exit 0 }

$projectDir = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
$deadline = [DateTime]::UtcNow.AddSeconds(25)

$currentRepo = $null
$linked = @()
$unread = @()
foreach ($r in $reopen.Reopens) {
    $nwo = [string]$r.Repo
    if (-not $nwo) {
        if ($null -eq $currentRepo) {
            $leftMs = [int]($deadline - [DateTime]::UtcNow).TotalMilliseconds
            $currentRepo = ''
            if ($leftMs -gt 1000) {
                $run = Invoke-AsanaGhBounded -Arguments 'repo view --json nameWithOwner -q .nameWithOwner' -TimeoutMs ([Math]::Min(8000, $leftMs)) -WorkingDirectory $projectDir
                if ($run.Started -and -not $run.TimedOut -and $run.ExitCode -eq 0) { $currentRepo = ([string]$run.Out).Trim() }
            }
        }
        $nwo = $currentRepo
    }
    if ($nwo -notmatch '\A([A-Za-z0-9][A-Za-z0-9-]*)/([A-Za-z0-9._-]+)\z') { $unread += "#$($r.Number)"; continue }
    $owner = $Matches[1]
    $name  = $Matches[2]
    $ref   = "$nwo#$($r.Number)"
    $leftMs = [int]($deadline - [DateTime]::UtcNow).TotalMilliseconds
    if ($leftMs -le 1000) { $unread += $ref; continue }
    $state = Read-AsanaIssueBlockState -Owner $owner -Repo $name -Number $r.Number -TimeoutMs ([Math]::Min(20000, $leftMs)) -WorkingDirectory $projectDir
    if (-not $state.Ok) { $unread += $ref; continue }
    if ((Resolve-AsanaTaskRef -IssueBody ([string]$state.Body)).Gid) { $linked += $ref }
}

if ($linked.Count -eq 0 -and $unread.Count -eq 0) { exit 0 }

$why = @()
if ($linked.Count -gt 0) {
    $why += "guard-issue-reopen: $($linked -join ', ') links an Asana task, so reopening it posts a message on that task to the colleague who asked. Reopen only when repo code will change for it; research, a question or an answer belongs in a comment on the issue instead (#3076)."
}
if ($unread.Count -gt 0) { $why += "guard-issue-reopen: $($unread -join ', ') could not be read. $notRead" }
Exit-Ask ($why -join "`n")
