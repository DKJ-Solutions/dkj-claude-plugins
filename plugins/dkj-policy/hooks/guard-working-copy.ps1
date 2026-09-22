<#
.SYNOPSIS
    PreToolUse hook: stops a DISPATCHED SUBAGENT from running the git commands that discard the
    working copy it was dispatched into. The main thread is untouched.

.DESCRIPTION
    Reads the hook JSON from stdin. Blocks (exit 2) when ALL of these hold:

      1. the payload carries agent_id -- i.e. the call comes from within a dispatched subagent; and
      2. a segment of the command that will actually RUN is led by git; and
      3. that segment's SUBCOMMAND mutates the working tree, the index or a ref.

    Point 1 is this file's own gate. Points 2 and 3 are Get-WorkingCopyViolation in
    scripts/lib/working-copy-guard-lib.ps1, which is where the whole judgement lives so that it can be
    tested and MEASURED without a payload and a process per case -- #1669 asks for a measured
    false-positive rate, and that measurement has to run the same decision this hook makes rather than
    a second copy of it.

    WHY hooks.json WRAPS THIS FILE IN A SHELL COMMAND (issue #2217). Everything above is what this script
    decides once it RUNS. When PowerShell cannot start at all, no line of this file executes and the
    harness reads every exit code other than 2 as a NON-blocking error, so the command goes through --
    the guard fails OPEN when a machine is least healthy. No hooks.json field declares a hook
    fail-closed and a start failure's exit code is arbitrary (127, 45, 66 and 1 were measured), so the
    hooks.json command is a bash wrapper: it runs this file, passes 0 and 2 through, and on any other
    exit code refuses ONLY a payload that carries agent_id and names git -- this file's own point 1 and
    the subject of points 2 and 3, read coarsely. Any other call passes the failure through as before.
    hook-fail-closed.tests.ps1 holds both halves. It assumes the hook shell is bash, the documented
    default wherever Git Bash is installed.

    WHY THIS SHIPS AS A HOOK RATHER THAN STAYING PROSE (issue #1669). Issue #1665 measured a dispatched
    review specialist running `git stash` and then `git checkout HEAD -- <file>` in the orchestrator's
    checkout, discarding three files of uncommitted work belonging to the session that dispatched it.
    No error, no notice, no refusal, and a clean `git status` afterwards -- the reviewer even cited that
    cleanliness as proof it had changed nothing. #1665 was repaired with an INSTRUCTION: the shared
    block `working-copy-boundary`, carried by every agent def that holds Bash. Nothing enforced it.

    This repo already shipped the counter-argument, verbatim, in the header of
    dkj-subagents-shopify/hooks/guard-live-theme.ps1: "The plugin stated the rule in prose in three manuals;
    prose does not stop a command." #1669 held that against #1665's repair, and this is the answer.

    IT SITS IN THIS PLUGIN BECAUSE DETECTION ALREADY DOES. #1670's Compare-WorkingCopySnapshot, which
    watches the same working copy for shrinkage while a fan-out runs, is scripts/lib/fanout-lib.ps1
    here. The two are explicitly not substitutes -- #1670 watches for the loss, this refuses the
    command -- so the two halves of one hazard live in one plugin.

    THE OBJECTION THIS HAD TO ANSWER, AND HOW IT DISSOLVES. #1669 raised it against itself: a hook
    cannot tell the DevOps specialist's legitimate `git checkout <branch>` from a dispatched
    reviewer's illegitimate one, because both arrive through the same tool layer. They do -- and the
    payload says which is which. Claude Code's shipped hook-input schema documents agent_id as
    "Present only when the hook fires from within a subagent (e.g., a tool called by an AgentTool
    worker). Absent for the main thread, even in --agent sessions. Use this field (not agent_type) to
    distinguish subagent calls from main-thread calls." So the gate is exactly the distinction the
    prose block draws, and the orchestrator, Derek and Rendall never meet this hook at all.

    AND agent_type IS NOT THE GATE, which is worth stating because it is the field one reaches for
    first. The same schema: it is present "on the main thread of a session started with --agent
    (without agent_id)". Gating on it would refuse the main thread of every --agent session. It is read
    only to NAME who was stopped in the refusal.

    NO ESCAPE MARKER, and that asymmetry with guard-live-theme is deliberate. That guard has one
    because a deliberate live push is a real, authorised act somebody performs. Here the boundary block
    already states the alternative: "if your work genuinely cannot be done without the checkout in
    another state, that is a sentence in your deliverable, not a command you run". There is nothing for
    a marker to authorise, and adding one would create the erosion guard-live-theme's own refusal text
    had to be repaired for teaching.

    A PAYLOAD IT CANNOT READ IS TREATED AS THE MAIN THREAD, which is the one place this guard
    deliberately fails OPEN. Everywhere else it fails towards checking. The reason is the blast radius:
    agent_id is a structured field with no raw-text stand-in, so an unreadable payload means "cannot
    tell who this is" -- and answering that with a block would refuse the orchestrator's own git
    commands the moment the hook contract changes shape. A missing lib is handled the same way and for
    the same reason, with a warning on stderr: the lib ships in this plugin beside this file, so its
    absence is a broken install rather than an attack, and bricking every shell command in a consumer
    is the worse failure. The prose block still stands underneath either case.

    Exit codes (PreToolUse contract): 2 = block and send stderr to Claude; 0 = allow.

    Pure ASCII (repo convention for .ps1): Windows PowerShell 5.1 reads a BOM-less script as ANSI.
    Tested by scripts/tests/guard-working-copy.tests.ps1 in the source repo -- change one, run the
    other.
#>
$ErrorActionPreference = 'Stop'

# READ STDIN ONLY WHERE THERE IS A HANDLE TO READ, which is the guard five other members of this
# family already carry (closeout-gate.ps1, publish-background-run.ps1, adopt-statusline.ps1,
# show-progress.ps1, and Get-HookPayloadRaw in scripts/lib/session-cache-lib.ps1) and this one did
# not until #2264. An UNREDIRECTED [Console]::In is a live
# console, and ReadToEnd on one waits for a Ctrl+Z that is never coming -- so running this hook by
# hand from a terminal, which is what anybody debugging a refusal does first, hangs on line one with
# nothing printed. show-progress.ps1's own comment states the cost: a thing that hangs the first time
# somebody looks at it by hand is a thing nobody will look at twice.
#
# THE COST IS A PROPERTY READ, which is why this is separable from the timeout half of #2264. The
# bound belongs to the unbounded-handle case; this belongs to the no-handle case, and only the bound
# has a per-firing price worth weighing on a hook that fires 9084 times in this repo's transcripts.
#
# AND DELIBERATELY NO try/catch AROUND IT, unlike the two sibling hooks that have one. Under
# $ErrorActionPreference = 'Stop' a throw here exits non-zero, and the bash wrapper #2217 put in
# hooks.json reads any exit code other than 0 or 2 as a start failure and refuses a payload that
# carries agent_id and names git. Swallowing the throw into an empty payload would turn that
# fail-CLOSED path into a fail-open one -- a change to the guarantee #2217 exists for, not a
# tidying-up of this line. Where there is genuinely no handle there is no throw either, so the guard
# below reaches the documented main-thread path without touching that contract.
$raw = ''
if ([Console]::IsInputRedirected) { $raw = [Console]::In.ReadToEnd() }

# THE CHEAP PRE-GATE, AND IT IS HERE FOR A MEASURED REASON. This hook fires on EVERY Bash and
# PowerShell call, not once per session, and the overwhelming majority of those calls are the main
# thread's -- 8089 of the 9084 in this repo's own transcripts, 89%. Measured on this machine, 5 runs
# each: the hook costs 675 ms on the main-thread path, of which 398 ms is the bare `powershell` launch
# a command hook cannot avoid and 278 ms is dot-sourcing two libs. On that 89% the libs are never
# used, because the gate below exits first.
#
# SO THE GATE IS ASKED BEFORE THE LIBS ARE LOADED, and asked as a string test rather than a JSON
# parse. A payload carrying agent_id always contains that key literally, so this cannot miss a
# subagent; a command whose own text happens to contain the string merely costs a lib load that is
# then thrown away. The direction of the imprecision is the safe one -- it can only make this hook do
# MORE work, never less.
#
# WHAT THE FIELD MEANS is still stated in exactly one place, Get-HookCommandPayload, and that is what
# decides. This is a fast path in front of it, not a second opinion.
if ($raw -notmatch '"agent_id"\s*:') { exit 0 }

# $PSScriptRoot-relative, so it resolves the same in the source tree, in the plugin mirror and in a
# consumer's plugin cache -- the same rule the sibling session checks state for hook-check-lib.ps1.
$libPath = Join-Path $PSScriptRoot '..\scripts\lib\working-copy-guard-lib.ps1'
if (-not (Test-Path -LiteralPath $libPath -PathType Leaf)) {
    [Console]::Error.WriteLine("guard-working-copy: working-copy-guard-lib.ps1 not found beside this hook -- the working-copy guard is OFF for this call. Reinstall or update the dkj-policy plugin.")
    exit 0
}
try { . $libPath } catch {
    [Console]::Error.WriteLine("guard-working-copy: working-copy-guard-lib.ps1 could not be loaded -- the working-copy guard is OFF for this call. $($_.Exception.Message)")
    exit 0
}

$payload = Get-HookCommandPayload $raw

# THE GATE. No agent_id means the main thread, and the main thread owns this checkout.
if (-not $payload.AgentId) { exit 0 }

# WHICH TREE IS BEING PROTECTED, and where the command starts. They differ in the case that matters:
# an agent granted worktree isolation runs with its cwd already inside .claude/worktrees/agent-<id>,
# which is its own tree and not the dispatching session's. CLAUDE_PROJECT_DIR is the session's project
# and is what the guard protects; the payload's cwd is where this particular command begins. With
# neither available the directory rule is skipped entirely and every git invocation is judged, which
# is the failing-towards-checking direction.
$projectRoot = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { $payload.Cwd }

$violation = Get-WorkingCopyViolation -Command $payload.Command -ProjectRoot $projectRoot -Cwd $payload.Cwd
if ($null -eq $violation) { exit 0 }

$who = if ($payload.AgentType) { "the dispatched '$($payload.AgentType)' subagent" } else { 'a dispatched subagent' }

[Console]::Error.WriteLine("BLOCKED (guard-working-copy): $($violation.Reason)")
[Console]::Error.WriteLine(@(
    "  This checkout belongs to the session that dispatched you ($who), and it may hold uncommitted",
    '  work you cannot see. A clean `git status` afterwards is not evidence that you changed nothing --',
    '  it is what the damage looks like.',
    '',
    '  READ ANOTHER REF WITHOUT TOUCHING THE TREE: `git diff <ref>...HEAD` for the branch diff,',
    '  `git diff <ref> -- <path>` for one file, `git show <ref>:<path>` for that file as a commit',
    '  records it, `git log`/`git show <ref>` for history. A second checkout goes OUTSIDE the repo via',
    '  `git worktree add`, which is not blocked.',
    '',
    '  IF THE WORK GENUINELY NEEDS THE CHECKOUT IN ANOTHER STATE, that is a sentence in your',
    '  deliverable, not a command you run: say what you need and stop. There is no marker or flag that',
    '  authorises this -- deliberately, because there is no authorised version of it.',
    '',
    '  WRITING THIS RULE INTO A FILE RATHER THAN RUNNING IT? That is already exempt (heredoc and',
    "  here-string bodies, text-tool segments, and git's own non-mutating subcommands), so reach for",
    "  the harness's Edit/Write tool if a shell is fighting you."
) -join "`n")
exit 2
