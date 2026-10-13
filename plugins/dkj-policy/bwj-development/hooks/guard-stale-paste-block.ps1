<#
.SYNOPSIS
    PreToolUse hook on the shell tools: refuses to ship a pull request that will close an issue whose
    newest go-live block was posted before the issue's last reopen.

.DESCRIPTION
    INBOUND #2968, MEASURED IN BWJ-Development/xoxowildhearts#414. The issue closed after round 1 and the
    asana-closed-message workflow carried the go-live block into the Asana task. It was reopened, round 2
    was built, and PR #426 merged and closed it again -- and the second closed message carried round 1's
    block, because the session had built the right block (with -OutFile) but posted it only after the
    merge. The block is read at the close, so by then the mistake had already reached the requester.
    This hook is the layer before the merge; the workflow's own check (templates/asana-closed-message.ps1)
    is the backstop for a merge this hook never sees -- the GitHub merge button, a merge queue.

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

    ONE TIME BUDGET for every read, 25s under hooks.json's 30s ceiling, so the harness never decides in
    this file's place; a read the budget can no longer cover is 'unknown' and takes the warned fail-open.

    WHAT IT PRINTS is its own text, issue numbers and an owner/name pair gh resolved and the regex below
    re-checked -- never a comment, a title or a body.

    Exit codes (PreToolUse contract): 2 = block and send stderr to Claude; 0 = allow.

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/guard-stale-paste-block.tests.ps1 in
    the source repo -- change one, run the other.
#>
$ErrorActionPreference = 'Stop'

# READ STDIN ONLY WHERE THERE IS A HANDLE, the guard every hook in this tree carries (#2264).
$raw = ''
if ([Console]::IsInputRedirected) { $raw = [Console]::In.ReadToEnd() }

# THE CHEAP PRE-GATE. Neither script named, nothing to judge: no lib load and no gh call is spent. The
# same test hooks.json makes in shell first, repeated for a run that reaches this file another way.
if ($raw -notmatch '(ship-pr|open-pr)\.ps1') { exit 0 }

$libs = @('asana-task-lib.ps1', 'stale-paste-block-rules.ps1')
foreach ($lib in $libs) {
    $libPath = Join-Path $PSScriptRoot "..\scripts\lib\$lib"
    if (-not (Test-Path -LiteralPath $libPath -PathType Leaf)) {
        [Console]::Error.WriteLine("guard-stale-paste-block: $lib not found beside this hook -- the stale go-live block check is OFF for this call. Reinstall or update the bwj-development plugin.")
        exit 0
    }
    . $libPath
}

# ANY UNEXPECTED THROW FROM HERE ON IS THE DELIBERATE FAIL-OPEN, NOT A CRASH (see guard-asana-mirror).
trap {
    [Console]::Error.WriteLine('guard-stale-paste-block: an unexpected error stopped the check -- the go-live blocks of the issues this PR closes were NOT checked. Confirm by hand that each is newer than the issue''s last reopen.')
    exit 0
}

$command = ''
try { $command = [string](($raw | ConvertFrom-Json).tool_input.command) } catch { exit 0 }
$ship = Get-ShipPrInvocation -Command $command
if ($null -eq $ship) { exit 0 }

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
# --- Which repo, and which issues ---------------------------------------------------------------------
# A ship that names no issue and may not consult the open PR needs no read at all.
$numbers = New-Object System.Collections.Generic.List[int]
foreach ($n in $ship.Resolves) { $numbers.Add([int]$n) }
$needRepo = $numbers.Count -gt 0 -or -not $ship.NoResolves
if (-not $needRepo) { exit 0 }

$repoRun = Invoke-GhBounded -Arguments 'repo view --json nameWithOwner -q .nameWithOwner'
$nameWithOwner = ([string]$repoRun.Out).Trim()
if (-not $repoRun.Ok -or $nameWithOwner -notmatch '\A([A-Za-z0-9][A-Za-z0-9-]*)/([A-Za-z0-9._-]+)\z') {
    [Console]::Error.WriteLine('guard-stale-paste-block: could not resolve which repo this is -- the go-live blocks of the issues this PR closes were NOT checked against their last reopen.')
    exit 0
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
            [Console]::Error.WriteLine('guard-stale-paste-block: the closing issues of the open pull request did not parse -- only the issues named with -Resolves were checked.')
        }
    } elseif ($prRun.Err -notmatch 'no pull requests? found') {
        [Console]::Error.WriteLine('guard-stale-paste-block: the closing issues of the open pull request could not be read -- only the issues named with -Resolves were checked.')
    }
}
if ($numbers.Count -eq 0) { exit 0 }

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
    [Console]::Error.WriteLine("guard-stale-paste-block: could not judge the go-live block of #$($unknown -join ', #') -- not checked against the issue's last reopen. Confirm by hand that its block is newer than the reopen.")
}
if ($stale.Count -eq 0) { exit 0 }

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
