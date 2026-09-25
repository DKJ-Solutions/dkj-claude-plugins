<#
.SYNOPSIS
    PreToolUse hook on the Asana create-task tools: refuses a task that mirrors a GitHub issue which
    does not carry the reach label.

.DESCRIPTION
    THE RULE IS report-issue's STEP 2, AND UNTIL THIS HOOK NOTHING HELD IT (inbound #2482). "Only an
    issue carrying the reach label gets an Asana task" (#2360) was a sentence a session had to
    remember, and it was missed on the plugin version that carried it: smartwatchbanden#770, filed with
    only `documentation`, got a card -- and that card then stopped the PR fixing it from closing it on
    merge. The judgement is in scripts/lib/asana-mirror-gate.ps1; this file reads the payload, asks the
    tracker, and answers.

    WHAT IT BLOCKS: a create-task call whose tool_input cites a GitHub issue URL on a repo report-issue
    admits, where that issue's labels were READ and the reach label is not among them. Every other call
    passes, silently: a task citing no such issue is not a mirror. The two cases the rule itself leaves
    alone pass by construction -- a ticket that came FROM Asana already has its card and creates none,
    and an issue that gains the label later is mirrored after it has it.

    THE REACH LABEL'S NAME is the project's Get-ReachLabel from scripts/repo-config.ps1, defaulting to
    'minor' -- the same read, and the same default, report-issue's own "Before you start" prescribes.

    IT FAILS OPEN, and that direction is chosen, not inherited. When gh cannot answer (absent, logged
    out, a timeout, an unparseable reply) the call passes with a warning on stderr naming what was not
    checked. The cost of a wrong card is a card somebody deletes; the cost of a guard that refuses every
    Asana write while the tracker is unreachable is the colleague-facing half of report-issue, which is
    the half its own page says must degrade to a note rather than stop. The same reasoning covers
    PowerShell failing to start, so hooks.json carries no fail-closed wrapper here -- unlike
    guard-working-copy and guard-live-theme, whose subjects cannot be undone.

    WHAT IT PRINTS is its own text plus refs the lib's regex built from GitHub's owner/name character
    classes and the label name from this repo's own config -- no free text from the payload or the
    tracker reaches stderr.

    Exit codes (PreToolUse contract): 2 = block and send stderr to Claude; 0 = allow.

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/guard-asana-mirror.tests.ps1 in the
    source repo -- change one, run the other.
#>
$ErrorActionPreference = 'Stop'

# READ STDIN ONLY WHERE THERE IS A HANDLE, the guard every hook in this tree carries (#2264): an
# unredirected [Console]::In waits for a Ctrl+Z that never comes when somebody runs this by hand.
$raw = ''
if ([Console]::IsInputRedirected) { $raw = [Console]::In.ReadToEnd() }

# THE CHEAP PRE-GATE. No issue URL in the payload means no mirror, and no lib load or gh call is spent.
if ($raw -notmatch 'github\.com/[^/\s"]+/[^/\s"]+/issues/[0-9]+') { exit 0 }

$libPath = Join-Path $PSScriptRoot '..\scripts\lib\asana-mirror-gate.ps1'
if (-not (Test-Path -LiteralPath $libPath -PathType Leaf)) {
    [Console]::Error.WriteLine('guard-asana-mirror: asana-mirror-gate.ps1 not found beside this hook -- the reach-label gate is OFF for this call. Reinstall or update the dkj-policy-bwj plugin.')
    exit 0
}
. $libPath

$refs = @(Get-MirroredIssueRefs -Text (Get-AsanaMirrorToolInputText -Raw $raw))
if ($refs.Count -eq 0) { exit 0 }

# --- The reach label's name: the project's own answer, else the prescribed default -----------------
# Read in a child scope with StrictMode off, the way build-backlog-page.ps1 reads the same seam: the
# file is the consumer's own and is written on the assumption that StrictMode is off.
$reachLabel = 'minor'
$projectDir = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
$configPath = Join-Path $projectDir 'scripts\repo-config.ps1'
if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    try {
        $answer = & {
            Set-StrictMode -Off
            . $args[0]
            if (@($ExecutionContext.InvokeCommand.GetCommands('Get-ReachLabel', 'Function', $false)).Count) { Get-ReachLabel }
        } $configPath
        if ($answer -and ([string]$answer).Trim()) { $reachLabel = ([string]@($answer)[-1]).Trim() }
    } catch {
        [Console]::Error.WriteLine("guard-asana-mirror: scripts\repo-config.ps1 could not be read -- judging against the default reach label '$reachLabel'.")
    }
}

# --- Ask the tracker, bounded -----------------------------------------------------------------------
function Get-IssueLabelsBounded {
    <# The issue's label names, or $null when gh did not answer within the bound. #>
    param([int]$Number, [string]$Owner, [string]$Repo, [int]$TimeoutMs = 20000)
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'gh'
        $psi.Arguments = "issue view $Number --repo $Owner/$Repo --json labels"
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $p = [System.Diagnostics.Process]::Start($psi)
        $outTask = $p.StandardOutput.ReadToEndAsync()
        $null = $p.StandardError.ReadToEndAsync()
        if (-not $p.WaitForExit($TimeoutMs)) {
            try { $p.Kill() } catch { }
            return $null
        }
        if ($p.ExitCode -ne 0) { return $null }
        return (ConvertFrom-GhIssueLabels -Json $outTask.Result)
    } catch {
        return $null
    }
}

$refused = @()
$unknown = @()
foreach ($r in $refs) {
    $labels = Get-IssueLabelsBounded -Number $r.Number -Owner $r.Owner -Repo $r.Repo
    switch (Get-AsanaMirrorVerdict -Labels $labels -ReachLabel $reachLabel) {
        'refuse'  { $refused += $r.Ref }
        'unknown' { $unknown += $r.Ref }
    }
}

if ($unknown.Count -gt 0) {
    [Console]::Error.WriteLine("guard-asana-mirror: could not read the labels of $($unknown -join ', ') -- the reach-label gate did NOT check them. Confirm by hand that each carries '$reachLabel' before this card stays on the board.")
}
if ($refused.Count -eq 0) { exit 0 }

[Console]::Error.WriteLine("BLOCKED (guard-asana-mirror): $($refused -join ', ') does not carry the reach label '$reachLabel', so it gets no Asana task.")
[Console]::Error.WriteLine(@(
    '  Only an issue carrying the reach label is mirrored to the board (report-issue step 2, #2360).',
    '  Without it the issue is tier 0 -- developer-only, GitHub-only -- and the absence of a card IS',
    '  the answer: skip steps 2 and 3 of report-issue and say so in step 4.',
    '',
    "  IF A COLLEAGUE WILL GENUINELY NOTICE THIS, the label is what was missing, not the card: add it",
    "  first (gh issue edit <n> --repo <owner>/<repo> --add-label '$reachLabel') and create the task",
    '  again. Do not add it only to get past this gate -- the label also puts the issue on the',
    '  colleague-facing backlog, and a card on a tier-0 issue blocks its own auto-close at the merge.'
) -join "`n")
exit 2
