<#
.SYNOPSIS
    PreToolUse hook on the shell tools: refuses to ship a pull request that will close an issue whose
    newest go-live block was posted before the issue's last reopen -- and refuses to close an
    Asana-linked issue as completed by hand ('gh issue close') while it carries no block for this
    round (#3004).

.DESCRIPTION
    INBOUND #2968, MEASURED IN BWJ-Development/xoxowildhearts#414. The issue closed after round 1 and the
    asana-closed-message workflow carried the go-live block into the Asana task. It was reopened, round 2
    was built, and PR #426 merged and closed it again -- and the second closed message carried round 1's
    block, because the session had built the right block (with -OutFile) but posted it only after the
    merge. The block is read at the close, so by then the mistake had already reached the requester.
    This hook is the layer before the merge; the workflow's own check (templates/asana-closed-message.ps1)
    is the backstop for a merge this hook never sees -- the GitHub merge button, a merge queue.

    THE CLOSE GUARD, INBOUND #3004, MEASURED IN BWJ-Development/smartwatchbanden#943. A research ticket
    was closed as completed with 'gh issue close', with no pull request and no block, and the closed
    message told the requester only that the issue was closed. A close by hand never passes through a
    ship, so the guard above never saw it. So a command running 'gh issue close' as completed
    (Get-IssueCloseInvocation; 'not planned' and 'duplicate' post no block and are skipped) is judged
    too: an issue whose body links one Asana task (Resolve-AsanaTaskRef, the workflow's own matcher)
    must carry a block posted after its last reopen -- a result block, or the research block
    build-golive-block.ps1 -Research writes for a ticket that changed nothing on the store, or the
    measurement block -Measure writes for a result that is a number (#3179). 'none' and
    'stale' are refused, with both commands on the refusal; an issue linking no task, or several, is let
    through, because the closed message posts nothing for it. The same read serves both guards: the one
    GraphQL call also returns the issue body. The same fail-open applies, and the workflow is the
    backstop again -- a close it receives without a block says the result message follows.

    WHERE IT LIVES, AND WHY NOT IN THE SHIP SCRIPTS. ship-pr.ps1 and open-pr.ps1 belong to the core
    workflow and know nothing about Asana; the paste block is an extension concept of this plugin. So the
    rule is a PreToolUse hook on Bash|PowerShell that fires on a command RUNNING one of those scripts
    (Get-ShipPrInvocation: an invocation, not a mention; -GatesOnly opens no PR and is skipped).

    AN ACCIDENT GUARD, NOT AN ADVERSARIAL ONE. It reads a command the way a session writes it (the
    quote-aware parser is in stale-paste-block-rules.ps1, with what it leaves out: pwsh -Command "...",
    values from $env or a variable, wrappers, obfuscation). A ship that slips past is caught at the
    close by the workflow's own check, which is the backstop.

    WHICH ISSUES. The numbers the command passes to -Resolves, plus the closing issues of the PR already
    open for the current branch (gh pr view --json closingIssuesReferences, same repo only) -- a re-ship
    carries no -Resolves and still closes what the PR body says. -NoResolves is the declared "closes no
    issue", so the existing PR is not consulted then.

    THE PASS IS NOT PROOF. The hook judges every comment that carries a block, trusted author or not,
    where the workflow carries only a trusted author's (Select-TrustedCommentBodies). An untrusted newer
    block can make this hook pass while the workflow, which is the authority at the close, still holds
    the older one back.

    WHAT IT BLOCKS: an issue whose newest block (Get-AsanaPasteBlockVerdict) is 'stale', i.e. posted at
    or before its last reopen. Silent where the issue was never reopened, has no block, or has one newer
    than the reopen. The refusal names the fix on one line.

    HOW IT READS: Read-AsanaIssueBlockState, ONE bounded gh api graphql call per issue that returns the
    last REOPENED_EVENT and the last 100 comments together, instead of the two paginated REST reads the
    same answer would take. The Actions runner reads through REST (#2875); this hook runs in a session
    where GraphQL is what build-golive-block.ps1 already uses.

    IT FAILS OPEN, and that direction is chosen. Unlike the workflow, which can fall back to a message
    that withholds the block, a hook has only two answers, and refusing on a read it could not make would
    stop every ship while GitHub is unreachable -- for a check whose cost of a miss is bounded: the
    workflow's backstop catches the stale block at the close and the requester is delayed, not
    misinformed. So when gh cannot answer (absent, logged out, a timeout, an unparseable reply), or an
    issue has more comments than one read returns and none of those read is a block, the ship passes with
    a warning on stderr naming what was not checked. The same reasoning covers PowerShell failing to
    start, so hooks.json carries no fail-closed wrapper.

    AND A FAIL-OPEN IS SAID TO THE SESSION, NOT ONLY TO STDERR (#3058). Claude Code shows the model no
    stderr from a hook that exits 0, and the transcript keeps none, so the 'Confirm by hand' each warning
    asks for reached nobody: measured in BWJ-Development/smartwatchbanden#946, a close went through with
    no block and nothing in the session said the check had been skipped. So every warning is collected,
    and the allow is printed as PreToolUse JSON: additionalContext for the model, and -- where a CLOSE
    was not checked -- permissionDecision 'ask', so a person sees the reason before the close runs. A
    close has no backstop that can still stop it; a ship has the workflow's check at the close, so a
    ship's fail-open only informs. stderr keeps the same lines for a debug log.

    ONE TIME BUDGET for every read, 25s under hooks.json's 30s ceiling, so the harness never decides in
    this file's place; a read the budget can no longer cover is 'unknown' and takes the warned fail-open.

    WHAT IT PRINTS is its own text, issue numbers and an owner/name pair gh resolved and the regex below
    re-checked -- never a comment, a title or a body.

    Exit codes (PreToolUse contract): 2 = block and send stderr to Claude; 0 = allow, with the JSON
    above on stdout whenever something was not checked.

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/guard-stale-paste-block.tests.ps1 in
    the source repo -- change one, run the other.
#>
$ErrorActionPreference = 'Stop'

# READ STDIN ONLY WHERE THERE IS A HANDLE, the guard every hook in this tree carries (#2264).
$raw = ''
if ([Console]::IsInputRedirected) { $raw = [Console]::In.ReadToEnd() }

# THE CHEAP PRE-GATE. Neither script nor a close named, nothing to judge: no lib load and no gh call is
# spent. The same test hooks.json makes in shell first, repeated for a run that reaches this file another way.
if ($raw -notmatch '(ship-pr|open-pr)\.ps1|gh(\.exe)?\s+issue\s+close') { exit 0 }

# THE FAIL-OPEN, SAID WHERE THE SESSION SEES IT (#3058). Until the payload is parsed, the pre-gate's own
# match is the best reading of whether a close is at stake; the close guard sets it for certain below.
$script:notChecked = New-Object System.Collections.Generic.List[string]
$script:closeUnchecked = $raw -match 'gh(\.exe)?\s+issue\s+close'
function Add-NotChecked {
    <# One fail-open warning: to stderr for a debug log, and kept for the JSON Exit-Allow prints. #>
    param([string]$Message, [switch]$Close)
    [Console]::Error.WriteLine($Message)
    $script:notChecked.Add($Message)
    if ($Close) { $script:closeUnchecked = $true }
}
function Exit-Allow {
    <# exit 0. Where something was not checked, the allow says so: additionalContext for the model, and
       'ask' where a close is about to run unchecked, so a person reads the reason first. #>
    if ($script:notChecked.Count -gt 0) {
        $text = ($script:notChecked -join "`n")
        $out = @{ hookEventName = 'PreToolUse'; additionalContext = $text }
        if ($script:closeUnchecked) {
            $out.permissionDecision = 'ask'
            $out.permissionDecisionReason = "$text`nThe close would post the Asana closed message without this check -- allow it only once the issue carries this round's go-live block."
        }
        [Console]::Out.WriteLine((@{ hookSpecificOutput = $out } | ConvertTo-Json -Compress))
    }
    exit 0
}

$libs = @('asana-task-lib.ps1', 'stale-paste-block-rules.ps1')
foreach ($lib in $libs) {
    $libPath = Join-Path $PSScriptRoot "..\scripts\lib\$lib"
    if (-not (Test-Path -LiteralPath $libPath -PathType Leaf)) {
        Add-NotChecked "guard-stale-paste-block: $lib not found beside this hook -- the stale go-live block check is OFF for this call. Reinstall or update the bwj-development plugin."
        Exit-Allow
    }
    . $libPath
}

# ANY UNEXPECTED THROW FROM HERE ON IS THE DELIBERATE FAIL-OPEN, NOT A CRASH (see guard-asana-mirror).
trap {
    Add-NotChecked 'guard-stale-paste-block: an unexpected error stopped the check -- the go-live blocks were NOT checked. Confirm by hand that each issue carries a block newer than its last reopen.'
    Exit-Allow
}

# A BYTE-ORDER MARK IS NOT PART OF THE PAYLOAD. A writer whose console input code page is UTF-8 prefixes
# one, and ConvertFrom-Json then fails -- which used to end the run silently, as an unparseable payload
# does: measured under the test gate, where a sibling suite held the shared console on UTF-8 and every
# hook-as-process case passed with no verdict at all. It is stripped, and a payload that still does not
# parse says so on stderr, since this pre-gate already saw one of the two scripts named in it.
$command = ''
# Whatever precedes the first '{' is that mark -- U+FEFF where stdin is read as UTF-8, three stray
# characters where it is read as a legacy code page -- and is dropped either way.
$jsonText = [string]$raw
$brace = $jsonText.IndexOf('{')
if ($brace -gt 0) { $jsonText = $jsonText.Substring($brace) }
try { $command = [string](($jsonText | ConvertFrom-Json).tool_input.command) } catch {
    Add-NotChecked 'guard-stale-paste-block: the hook payload did not parse as JSON -- the go-live blocks were NOT checked.'
    Exit-Allow
}
$ship  = Get-ShipPrInvocation -Command $command
$close = Get-IssueCloseInvocation -Command $command
if ($null -eq $ship -and $null -eq $close) { exit 0 }
# Parsed now, so a close is at stake only where one is invoked -- a mention the pre-gate matched is not.
$script:closeUnchecked = $false

$projectDir = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
$deadline = [DateTime]::UtcNow.AddSeconds(25)

function Invoke-GhBounded {
    <# gh in the project directory within the shared budget: Ok, Out, Err. Ok is $false on a non-zero
       exit, a timeout, no time left, or a failure to start. #>
    param([string]$Arguments, [int]$MaxMs = 8000)
    $leftMs = [int]($deadline - [DateTime]::UtcNow).TotalMilliseconds
    if ($leftMs -le 1000) { return [pscustomobject]@{ Ok = $false; Out = ''; Err = '' } }
    $run = Invoke-AsanaGhBounded -Arguments $Arguments -TimeoutMs ([Math]::Min($MaxMs, $leftMs)) -WorkingDirectory $projectDir
    return [pscustomobject]@{ Ok = ($run.Started -and -not $run.TimedOut -and $run.ExitCode -eq 0); Out = $run.Out; Err = $run.Err }
}

# --- The close guard (#3004) ----------------------------------------------------------------------------
# A completed close by hand of an Asana-linked issue needs a block for this round, result or research.
if ($close) {
    $currentRepo = $null
    $missing = @()
    $old     = @()
    $unread  = @()
    foreach ($c in $close.Closes) {
        $nwo = [string]$c.Repo
        if (-not $nwo) {
            if ($null -eq $currentRepo) {
                $repoRun = Invoke-GhBounded -Arguments 'repo view --json nameWithOwner -q .nameWithOwner'
                $currentRepo = if ($repoRun.Ok) { ([string]$repoRun.Out).Trim() } else { '' }
            }
            $nwo = $currentRepo
        }
        if ($nwo -notmatch '\A([A-Za-z0-9][A-Za-z0-9-]*)/([A-Za-z0-9._-]+)\z') { $unread += "#$($c.Number)"; continue }
        $cOwner = $Matches[1]
        $cRepo  = $Matches[2]
        $ref    = "$nwo#$($c.Number)"
        $leftMs = [int]($deadline - [DateTime]::UtcNow).TotalMilliseconds
        if ($leftMs -le 1000) { $unread += $ref; continue }
        $state = Read-AsanaIssueBlockState -Owner $cOwner -Repo $cRepo -Number $c.Number -TimeoutMs ([Math]::Min(20000, $leftMs)) -WorkingDirectory $projectDir
        if (-not $state.Ok) { $unread += $ref; continue }
        # NO SINGLE LINKED TASK, NOTHING TO GUARD: the closed message posts nothing for such an issue.
        if (-not (Resolve-AsanaTaskRef -IssueBody ([string]$state.Body)).Gid) { continue }
        switch (Get-AsanaPasteBlockVerdict -Comments $state.Comments -LastReopenedAt $state.LastReopenedAt) {
            'none'    { if ($state.Truncated) { $unread += $ref } else { $missing += $ref } }
            'stale'   { $old += $ref }
            'unknown' { $unread += $ref }
        }
    }
    if ($unread.Count -gt 0) {
        Add-NotChecked -Close "guard-stale-paste-block: could not judge the go-live block of $($unread -join ', ') -- the close was NOT checked. Confirm by hand that each Asana-linked issue carries a block for this round."
    }
    if ($missing.Count -gt 0 -or $old.Count -gt 0) {
        # THE FIX NAMES THE REPO where the close named one (-R or a URL), so the hint never points at the
        # checkout's own issue of that number.
        $firstRef = @($missing + $old)[0]
        $first    = $firstRef -replace '^.*#', ''
        $repoHint = if ($firstRef -ne "$currentRepo#$first") { " -Repo $($firstRef -replace '#\d+$', '')" } else { '' }
        $closeHint = if ($repoHint) { "$first -R $($firstRef -replace '#\d+$', '')" } else { $first }
        $why = @()
        if ($missing.Count -gt 0) { $why += "no go-live block on $($missing -join ', ')" }
        if ($old.Count -gt 0) { $why += "only a block from before the last reopen on $($old -join ', ')" }
        [Console]::Error.WriteLine("BLOCKED (guard-stale-paste-block): $($why -join '; and ') -- closed as completed, the Asana task would hear that the issue is closed and that a result message follows, and nothing about how to view the result (#3004).")
        [Console]::Error.WriteLine(@(
            '  Post the block on the issue first, then close it:',
            "    a result to look at:         build-golive-block.ps1 -Issue $first$repoHint -Link <result url> -ProseFile <prose> -Post  (add -Force while no PR names the issue)",
            "    research, a test, a decision: build-golive-block.ps1 -Issue $first$repoHint -Research -ProseFile <the outcome under [outcome]> -Post",
            "    a number to measure again:   build-golive-block.ps1 -Issue $first$repoHint -Measure -ProseFile <[measure] and [targets]> -Post",
            "  Nothing was done and nothing found? Close it as not planned instead: gh issue close $closeHint --reason `"not planned`"."
        ) -join "`n")
        exit 2
    }
}
if ($null -eq $ship) { Exit-Allow }

# --- Which repo, and which issues ---------------------------------------------------------------------
# A ship that names no issue and may not consult the open PR needs no read at all.
$numbers = New-Object System.Collections.Generic.List[int]
foreach ($n in $ship.Resolves) { $numbers.Add([int]$n) }
$needRepo = $numbers.Count -gt 0 -or -not $ship.NoResolves
if (-not $needRepo) { Exit-Allow }

$repoRun = Invoke-GhBounded -Arguments 'repo view --json nameWithOwner -q .nameWithOwner'
$nameWithOwner = ([string]$repoRun.Out).Trim()
if (-not $repoRun.Ok -or $nameWithOwner -notmatch '\A([A-Za-z0-9][A-Za-z0-9-]*)/([A-Za-z0-9._-]+)\z') {
    Add-NotChecked 'guard-stale-paste-block: could not resolve which repo this is -- the go-live blocks of the issues this PR closes were NOT checked against their last reopen.'
    Exit-Allow
}
$owner = $Matches[1]
$repo  = $Matches[2]

if (-not $ship.NoResolves) {
    $prRun = Invoke-GhBounded -Arguments 'pr view --json closingIssuesReferences'
    if ($prRun.Ok) {
        try {
            foreach ($ref in @((ConvertFrom-Json -InputObject $prRun.Out).closingIssuesReferences)) {
                $sameRepo = $ref.repository -and $ref.repository.name -eq $repo -and $ref.repository.owner.login -eq $owner
                $n = [int]$ref.number
                if ($sameRepo -and $n -gt 0 -and -not $numbers.Contains($n)) { $numbers.Add($n) }
            }
        } catch {
            Add-NotChecked 'guard-stale-paste-block: the closing issues of the open pull request did not parse -- only the issues named with -Resolves were checked.'
        }
    } elseif ($prRun.Err -notmatch 'no pull requests? found') {
        Add-NotChecked 'guard-stale-paste-block: the closing issues of the open pull request could not be read -- only the issues named with -Resolves were checked.'
    }
}
if ($numbers.Count -eq 0) { Exit-Allow }

# --- Ask the tracker, bounded -------------------------------------------------------------------------
$stale   = @()
$unknown = @()
# THE CAP IS THE PARSER'S (20); what the open PR adds beyond it is named in the warning, never dropped silently.
$checkNumbers = @($numbers | Select-Object -First 20)
foreach ($n in @($numbers | Select-Object -Skip 20)) { $unknown += $n }
foreach ($n in $checkNumbers) {
    $leftMs = [int]($deadline - [DateTime]::UtcNow).TotalMilliseconds
    if ($leftMs -le 1000) { $unknown += $n; continue }
    $state = Read-AsanaIssueBlockState -Owner $owner -Repo $repo -Number $n -TimeoutMs ([Math]::Min(20000, $leftMs)) -WorkingDirectory $projectDir
    if (-not $state.Ok) { $unknown += $n; continue }
    switch (Get-AsanaPasteBlockVerdict -Comments $state.Comments -LastReopenedAt $state.LastReopenedAt) {
        'stale'   { $stale += $n }
        'unknown' { $unknown += $n }
        'none'    { if ($state.Truncated) { $unknown += $n } }
    }
}

if ($unknown.Count -gt 0) {
    Add-NotChecked "guard-stale-paste-block: could not judge the go-live block of #$($unknown -join ', #') -- not checked against the issue's last reopen. Confirm by hand that its block is newer than the reopen."
}
if ($stale.Count -eq 0) { Exit-Allow }

$staleRefs = ($stale | ForEach-Object { "$owner/$repo#$_" }) -join ', '
$first     = $stale[0]
$what      = if ($stale.Count -eq 1) { "$staleRefs carries a go-live block from before its last reopen, so the closed message would send" } else { "$staleRefs each carry a go-live block from before their last reopen, so the closed message would send" }
[Console]::Error.WriteLine("BLOCKED (guard-stale-paste-block): $what an earlier round's result to the Asana task.")
[Console]::Error.WriteLine(@(
    "  Post this round's block first: build-golive-block.ps1 -Issue $first -Link <result url> -ProseFile <prose> -Post  (add -Force while no PR names the issue yet, which -Post otherwise waits for), then ship again.",
    '  Where several issues are listed, each needs its own block. A newer block is judged against the reopen; the old one stays on the issue and is simply no longer the newest.',
    '  A merge that bypasses this hook is still caught at the close: the workflow then posts the closed line and says the result message follows, instead of carrying the old block.'
) -join "`n")
exit 2
