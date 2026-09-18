<#
.SYNOPSIS
    Stop hook of the contributing plugin: after every turn, put the branch's development cycle on
    origin -- unless a PR has already published it.

.DESCRIPTION
    WHY A HOOK AND NOT A SKILL (issue #900). What another device needs from a branch in flight is the
    PLAN, which phase is running and where the last session stopped, and all three live in
    development.md. Keeping that document current on the remote is not a thing anybody remembers
    to do: `park` and `new-branch -Park` between them produced SIX commits in the whole history, while
    the median merged branch sat invisible on origin for 22 minutes and the worst for 365. By this
    repo's own rule -- what has to happen without anyone asking for it is a hook, what somebody invokes
    is a script in a skill -- the creation push belongs in new-branch and this belongs here.

    THE HOOK IS DELIBERATELY THIN. Every bound, every refusal and every measurement lives in
    park-cycle.ps1, which this invokes with -Quiet: the DEPLOY-lock check that makes it a no-op once a
    PR exists, the trunk guard, the one-document pathspec, and the no-amend/no-force rule. Same shape
    as the two SessionStart hooks beside it, and for the same reason -- a hook that reimplemented any
    of that would be a second answer to a question that already has one.

    -Quiet IS WHAT KEEPS THIS INVISIBLE. A turn that did not touch the document prints nothing at all,
    so the common case adds no line to the session; a push reports itself, because a commit made on
    somebody's behalf should be visible in the transcript that caused it.

    AND EVERY STREAM park-cycle WRITES IS PART OF THE REPORT (issue #1600). This captured stdout only,
    which is the ordinary shape and was wrong here for one reason: a refused push is this workflow's
    earliest signal that a second session is on the same branch, and the sentence naming that --
    Get-GitPushFailureMessage's, written through Write-Error by Invoke-GitPark -- is on stderr. So the one
    turn where this hook has something urgent to say was the one turn whose most useful line it dropped.
    park-cycle.ps1 now says it on stdout as well, in its own voice and with the other side's author and
    subject; this capture is the second half of that repair, so no future line of park-cycle's can be lost
    to the stream it chose. Measured on feat/plugin-version-overview, September 8, 2026: two sessions ran
    the same pre-PR review in full, each finding real defects the other missed.

    AND IT RUNS park-cycle IN THIS INTERPRETER, NOT A SECOND ONE (issue #1641). This spawned a whole
    `powershell.exe` to run one script, on EVERY turn -- so the avoidable start-up the SessionStart family
    pays per session, this paid per turn. It now goes through the same Invoke-CheckScript those six use
    since #1625, with -MergeAllStreams for the capture the paragraph above is about. MEASURED here on the
    real park-cycle on an ORDINARY turn -- branch in sync with origin, so park-cycle finds nothing to push,
    which is what most turns look like -- Windows PowerShell 5.1, 7 runs each, median: 666 ms spawning
    against 564 ms in-process. ~102 ms back per turn, which is one interpreter start-up exactly: the same
    102 ms a bare `powershell -File <script that only exits>` costs on this machine, measured separately.

    A RUNSPACE WAS BUILT FIRST AND THROWN AWAY, and the reason is worth keeping because it is the trap this
    file would otherwise invite back. The premise was that park-cycle.ps1 calls `exit` at fourteen
    top-level places and `exit` would take the hook with it. That is true of DOT-SOURCING and of a script
    BLOCK invoked with `&`; it is NOT true of a .ps1 FILE invoked with `&`, which gets its own scope, ends
    at its own `exit`, and hands back $LASTEXITCODE. Verified rather than assumed, on both sides. The
    runspace worked and cost ~45 ms of the ~102 ms it saved, so the honest answer was the cheaper one that
    the six sibling hooks were already using.

    THE CAPTURE WIDENS FROM `2>&1` TO `*>&1`, which is what -MergeAllStreams asks the lib for: every stream
    -- Write-Host, the pipeline, error, warning, verbose, debug -- in ONE ordered sequence, so the safety
    net the #1600 paragraph describes now covers streams the old redirect never read. The lib defaults the
    other way for the session checks, because merging stderr would put non-findings in front of their
    [ERROR] filter; this hook has no filter and relays park-cycle verbatim, which is exactly why the switch
    exists rather than a second capture helper.

    NO ToString() AND NO SPLIT HERE ANY MORE: the lib returns string[], already stringified and already
    split on newlines -- its traps 2 and 3, which this file used to answer for itself.

    ONE PROPERTY IS GIVEN UP KNOWINGLY: the child ran with -ExecutionPolicy Bypass, and an in-process call
    is subject to the host's own policy, so on a machine at AllSigned this reports nothing instead of
    parking. That is the whole SessionStart family's position since #1625 rather than something new here,
    the failure is caught by the catch below and is silent by design, and buying the flag back would mean
    keeping the second process this issue exists to remove.

    $ErrorActionPreference is still left alone in THIS file, and the reason has changed rather than gone.
    There is no child process any more, so the NativeCommandError that redirect could raise (the
    #96/#97/#107 pitfall) cannot arise here at all. park-cycle sets its own StrictMode and EAP on its first
    two statements, and `&` gives it a child scope, so neither reaches this file.

    ALWAYS EXITS 0, and never blocks. A Stop hook that fails is a hook that interrupts the work it was
    added to protect, and nothing this does is important enough to strand a turn: the worst outcome of
    a silent failure is a document one turn stale on the remote.

    AND THE CEILING IS WHAT MAKES THAT PROMISE KEEPABLE (issue #1958, September 13, 2026). This hook is
    registered at "timeout": 60 in hooks.json, and past it the harness kills the process from OUTSIDE --
    where an always-exits-0 contract is worth nothing, because no arm of park-cycle.ps1 runs and no line
    it had already written is delivered. park-cycle made up to three sequential network calls, two of
    them bounded at the shared PER-CALL 120s and one (`gh pr list`) not bounded at all, so the ceiling
    was outrunnable by a factor of four on the honest path and without limit on the other.
    THE DECLARATION IS PASSED FROM HERE AND THE NUMBER IS NOT: this file knows there IS a ceiling, which
    is the fact JSON cannot carry a comment about, and -UnderHook says exactly that. The share of the
    ceiling a run may spend is $NativeCaptureHookNetworkBudgetSeconds in native-capture-lib.ps1, which
    holds the reasoning beside it, and cycle-autopark.tests.ps1 pins that number against the "timeout"
    above so the two cannot be raised apart. A script somebody types has no ceiling and passes neither,
    which is why this is a parameter rather than park-cycle's default.

    Read-only with respect to the working tree: it commits and pushes the one document park-cycle
    resolves, and changes nothing else.

    Matcher note: no matcher -- Stop carries none, unlike the SessionStart hooks beside it, which match
    "startup|resume|clear|compact" so their report survives a compaction.

.PARAMETER ScriptOverride
    (Optional, for tests) Use this park-cycle path instead of the ${CLAUDE_PLUGIN_ROOT} one.

.PARAMETER RepoRootOverride
    (Optional, for tests) Passed through to park-cycle.ps1 as the tree to act on.
#>
[CmdletBinding()]
param(
    [string]$ScriptOverride = '',
    [string]$RepoRootOverride = ''
)

Set-StrictMode -Version Latest

try {
    if ($ScriptOverride) {
        $parkScript = $ScriptOverride
    } elseif ($env:CLAUDE_PLUGIN_ROOT) {
        $parkScript = Join-Path $env:CLAUDE_PLUGIN_ROOT 'scripts\task\park-cycle.ps1'
    } else {
        $parkScript = $null
    }

    # Silent when the script is not there, unlike the session checks, which say so. Those run once at a
    # session start and their notice is the only sign the plugin is half-installed; this runs on every
    # turn, so the same notice would become a line per turn saying nothing new.
    if (-not $parkScript -or -not (Test-Path -LiteralPath $parkScript -PathType Leaf)) { exit 0 }

    # Unguarded and inside this try, exactly as the SessionStart hooks dot-source it: lib and hook travel
    # in one payload, so a payload missing it is swallowed by the catch below rather than failing at load.
    . (Join-Path $PSScriptRoot '..\scripts\lib\hook-check-lib.ps1')

    # A HASHTABLE, NEVER AN ARRAY. In-process an array splats POSITIONALLY, so the string '-Quiet' would
    # bind to park-cycle's -RepoRoot and -Quiet would stay false -- a hook printing park-cycle's entire
    # report on every turn, with nothing anywhere failing to say so. Trap 1 in hook-check-lib.ps1's header.
    # -UnderHook SAYS WHAT THIS FILE KNOWS AND NOTHING MORE (#1958): that there is a ceiling. The share of
    # it a run may spend is $NativeCaptureHookNetworkBudgetSeconds, which park-cycle reads from the lib it
    # already loads. Passing the NUMBER from here was written first and thrown away: it meant dot-sourcing
    # native-capture-lib.ps1 in this file as well, ~28 ms of parse per turn measured on this machine, to
    # carry one integer into a script that has the constant in scope anyway -- in a hook where #1641 went
    # to the trouble of removing a whole interpreter start-up for 102 ms. A switch costs nothing and the
    # number still lives in exactly one place.
    $parkArgs = @{ Quiet = $true; UnderHook = $true }
    if ($RepoRootOverride) { $parkArgs['RepoRoot'] = $RepoRootOverride }

    # -MergeAllStreams because this hook RELAYS park-cycle rather than filtering it; see the header.
    # -OutputTo because a park-cycle that THROWS leaves no return value, and the lines it managed to
    # write before falling over are exactly the diagnosis this hook exists to deliver. The list is read
    # in the finally, so the ordinary path and the crash path print through one route.
    # The exit code is deliberately not read: park-cycle always exits 0, and this hook reports whatever
    # it said either way.
    $relay = New-Object System.Collections.Generic.List[string]
    try {
        $null = Invoke-CheckScript -Path $parkScript -Arguments $parkArgs -MergeAllStreams -OutputTo $relay
    } finally {
        foreach ($line in $relay) {
            if ($null -eq $line) { continue }
            if ($line.Trim()) { Write-Host $line }
        }
    }
} catch {
    # Swallowed on purpose -- see the always-exits-0 paragraph. The message is dropped rather than
    # printed: a hook that reports its own plumbing on every turn is noise, and park-cycle run by hand
    # says everything this could.
}

exit 0
