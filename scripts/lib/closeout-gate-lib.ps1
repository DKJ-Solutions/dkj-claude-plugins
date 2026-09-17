<#
.SYNOPSIS
    The close-out GATE: the band a receipt may not exceed, the marker that says a chain ended this
    turn, and the verdict a Stop hook acts on. closeout-lib.ps1 prints the shape; this refuses one.

.DESCRIPTION
    Dot-source this file:

        . (Join-Path $PSScriptRoot 'closeout-gate-lib.ps1')

    WHY THIS EXISTS (issue #2050, September 17, 2026). Step 6 of Chris's ritual has been repaired six
    times -- #849, the August 27 receipt rule, #1402, #1408, #1884, #2043 -- and every one of the six
    was ADVICE: better wording, then a better-placed print, then a fillable template. #2048 built the
    instrument the six had never had, and the first number it produced is why this file is not a
    seventh:

        over the 3-line ceiling   222 / 263   84%
        over 6 lines              146 / 263   56%
        median / mean / p90 / max            7 / 8.5 / 16 / 76

    SO THE RULE HAS NEVER BEEN IN FORCE ANYWHERE. Five complaints are five of two hundred and
    twenty-two, which reframes the whole history: those were not guardrails that kept slipping, they
    were advice against a baseline nobody had counted. The workflow refuses elsewhere on far less --
    open-pr will not push with an unresolved step, and there is no -Force.

    WHY A BLOCKING HOOK IS THE ONLY SHAPE THAT CAN WORK, verified rather than assumed. #1884 declined
    a Stop hook because it "has to parse a transcript shape that differs across the harness versions
    consumers run". That objection has expired on its facts: the harness hands a Stop hook the
    close-out directly in last_assistant_message, and the reference says hooks needing the final
    assistant text "should use last_assistant_message on Stop and SubagentStop instead of reading the
    transcript". #1884's SECOND objection stands and settles the shape -- a hook that merely reports
    arrives after the close-out is written, and a Stop hook exiting 0 puts plain stdout in the debug
    log, where neither the reader nor the model sees it. systemMessage reaches the reader after the
    fact, which is the "second report to read" being complained about; additionalContext reaches the
    model a turn too late. Exit 2 is the only channel that reaches the writer before the writing
    stands.

    IT CONTRADICTS cycle-autopark.ps1 DELIBERATELY, AND THE CONTRADICTION IS BOUNDED. That file's
    header says "ALWAYS EXITS 0, and never blocks. A Stop hook that fails is a hook that interrupts
    the work it was added to protect." That reasoning is exactly right for a hook whose worst outcome
    is a document one turn stale on the remote, and it does not transfer to one whose subject is the
    thing the owner has complained about five times. What DOES transfer is the half about failing:
    every path in this file that cannot answer its question returns "no gate", so a broken install, an
    unreadable payload, an absent seam or an unwritable cache all end in exit 0. The gate blocks on a
    MEASURED over-run and on nothing else.

    THE BAND IS 6 AND IT WAS CHOSEN FROM THE DISTRIBUTION, not from the ceiling. Gating at the stated
    ceiling of 3 would fire on 73-84% of close-outs, which is a gate nobody would leave on for a week.
    Measured over this machine's 83 real close-outs: over 6 is 27%, over 8 is 17%, over 12 is 7%.
    Six is double the stated ceiling -- far enough out that a close-out reaching it is a runaway rather
    than a long-ish receipt, close enough in that the median (5) and the shape the receipt asks for are
    both comfortably inside. Dave's answer, September 17, 2026.

    IT IS OPT-IN PER REPO, through the Get-CloseOutGateBand seam in scripts/repo-config.ps1 -- the
    shape Get-AlwaysOnBudget and Get-ShopifyRepoHasNoStore already use here. THE DEFAULT IS OFF, which
    is the one place this deliberately differs from Get-AlwaysOnBudget: that seam's absence falls back
    to a built-in ceiling, because a budget nobody answered still ought to be bounded. A turn-blocking
    hook is not something to arrive in a consumer's session because they updated a plugin. A repo turns
    it on by answering the seam, and the answer is then visible and arguable in a tracked file.

    WHAT IS NOT CLAIMED. That the gate works. It has not been tried, and six confident repairs preceded
    it. What is different is that #2048 left an instrument and a recorded baseline behind, so this one
    can be MEASURED -- re-run scripts/maintenance/measure-closeouts.ps1 -- rather than judged by
    whether a complaint arrives.

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script.
    Pure ASCII (repo convention for .ps1).
#>

# $PSScriptRoot-relative, so it resolves in the source tree, in the plugin mirror and in a consumer's
# plugin cache alike. session-cache-lib carries the storage this file's marker is one entry in, and it
# is needed on EVERY turn -- the marker check is the first thing the hook does.
. (Join-Path $PSScriptRoot 'session-cache-lib.ps1')

# seam-lib IS DELIBERATELY NOT LOADED HERE, and it is the only lib in this workflow deferred into a
# function body. This file is dot-sourced by a Stop hook that fires on every turn, while the seam it
# needs is read only on a turn that ended a work chain -- a small minority of them. Measured on this
# machine, Windows PowerShell 5.1, median of 5-7 in-process dot-sources: seam-lib costs 96 ms with
# command-probe-lib underneath it and session-cache-lib 44 ms, and deferring the first took THIS file
# from 162 ms to 40 ms. That is more than the 102 ms #1641 removed a whole interpreter start-up to buy,
# on a hook that fires just as often.
#
# WHAT IT DOES NOT BUY, stated because the honest figure is the one that gets quoted back. End to end
# the hook still costs ~340 ms per turn against ~155 ms for a bare `powershell` launch on the same
# machine (median of 9, interleaved), so ~185 ms is its own and the rest is the process the harness
# starts for any command hook at all. The deferral moved the lib load; it did not and could not move
# the launch, and a second Stop hook is a second launch. If that per-turn cost is ever judged too high,
# the answer is NOT to fold this into cycle-autopark.ps1 -- that file's contract is that it never
# blocks, which is the whole of what this one does -- but to switch the gate off at the seam.
#
# THE DEFERRED LOAD IS INSIDE Resolve-CloseOutGateBand, which is the one function that needs it, so the
# functions it defines land in that call's own scope and nothing outside can come to depend on them
# having been loaded as a side effect. A caller that wants Get-SeamValue loads seam-lib itself, exactly
# as it did before this file existed.

# THE BAND, in non-empty lines. See the header for where 6 comes from. A repo states its own through
# the seam; this is what the seam's own documentation and the tests are written against.
$script:CloseOutGateBandDefault = 6

# THE SYNTHETIC SESSION ID THE MARKER IS FILED UNDER. Set-SessionCacheEntry keys on (session, subject)
# and validates the session against Test-SessionIdShape, so the marker borrows that storage with a
# fixed name in the session slot and the REPO in the subject slot -- which is the pair that actually
# identifies it, since the writer is a child process that never sees the harness's session id.
# Deliberately shaped to match Remove-StaleSessionCacheEntry's filename pattern, so the marker is
# reaped by the sweep that is already there rather than by a second one written for it.
$script:CloseOutMarkerSessionId = 'closeout-chain'

# HOW LONG A MARKER MAY SIT BEFORE IT STOPS MEANING ANYTHING. The real bound is that the very next Stop
# consumes it, so this only covers the case where there IS no next Stop -- a session quit between the
# script and the close-out. Six hours is long enough that a ship waiting on CI still gates, and short
# enough that tomorrow morning's first turn in the same checkout is not judged against last night's
# chain.
$script:CloseOutMarkerMaxAgeHours = 6

function Get-CloseOutGateBandDefault {
    <# The band a repo gets when it answers the seam with nothing usable but has opted in. #>
    return $script:CloseOutGateBandDefault
}

function Get-CloseOutLineCount {
    <#
    .SYNOPSIS
        The count the band is stated in: non-empty lines, blank separators excluded.

    .DESCRIPTION
        BLANKS ARE EXCLUDED DELIBERATELY. The band is about how much a reader has to READ, and a
        close-out written as three one-line paragraphs is three lines to a reader and five to a naive
        split. Counting the blanks would let a receipt pass or fail on its formatting.
    #>
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return 0 }
    return @($Text -split "`r?`n" | Where-Object { $_.Trim() -ne '' }).Count
}

function Resolve-CloseOutGateBand {
    <#
    .SYNOPSIS
        The band this repo runs under -- 0 when the repo has not opted in, which means no gate.

    .DESCRIPTION
        NAMED Resolve- AND NOT Get-CloseOutGateBand, WHICH IS THE OBVIOUS NAME AND WOULD HANG. The
        seam this reads is itself called Get-CloseOutGateBand, and a repo's repo-config.ps1 and this
        lib are dot-sourced into ONE session: whichever loads last wins the name. With the obvious
        name, a load order that put this lib second would have Get-SeamValue find THIS function, call
        it, and recurse until the process died. always-on-budget-lib.ps1 carries the same note for the
        same reason -- it is the one trap this seam idiom has.

        ABSENT MEANS OFF, and that is the opposite of Get-AlwaysOnBudget's fallback. See the header:
        a ceiling on a document is worth defaulting, a hook that blocks a turn is not.

        A NON-NUMERIC OR NON-POSITIVE ANSWER ALSO MEANS OFF, rather than falling back to the default
        band. The direction matters and it is the safe one: a repo whose seam is malformed gets the
        behaviour it had before this file existed, never a turn-blocking hook it did not ask for.
        Zero is therefore a real answer -- it is how a repo that once opted in switches the gate off
        without deleting the function.
    #>
    # Loaded HERE rather than at file scope -- see the note beside session-cache-lib's dot-source for
    # the measurement. Guarded, because a mirror that predates it must leave the gate off rather than
    # throw inside a hook.
    $seamLib = Join-Path $PSScriptRoot 'seam-lib.ps1'
    if (-not (Test-Path -LiteralPath $seamLib -PathType Leaf)) { return 0 }
    . $seamLib

    $raw = Get-SeamValue -Name 'Get-CloseOutGateBand' -Default $null
    if ($null -eq $raw) { return 0 }
    $parsed = 0
    if (-not [int]::TryParse([string]$raw, [ref]$parsed)) { return 0 }
    if ($parsed -le 0) { return 0 }
    return $parsed
}

function Get-CloseOutGateScopeKey {
    <#
    .SYNOPSIS
        Which repo a marker belongs to, in the one spelling both sides of the gate can compute.

    .DESCRIPTION
        THE WRITER AND THE READER ARE DIFFERENT PROCESSES AND ONLY ONE OF THEM HAS A PAYLOAD. The
        marker is written by a chain-ending script the operator invoked; it is read by a Stop hook the
        harness invoked. The only identifier both can name is the project directory, which the harness
        exports as CLAUDE_PROJECT_DIR to script and hook alike -- so that is the key, with the hook's
        own payload cwd as the fallback for a hook that is handed one and no variable.

        NORMALISED, because the two sides can spell the same directory differently: a trailing
        separator, a different drive-letter case, forward slashes from a shell. A mismatch here is not
        a wrong block -- it is a marker nobody claims and therefore a gate that silently never fires,
        which is the failure mode that would be hardest to notice.

        AN EMPTY KEY IS A REAL KEY, not an error. A chain-ending script run outside a session has no
        CLAUDE_PROJECT_DIR, and so does the hook in the same situation; both land on '' and agree.
    #>
    param([string]$Cwd = '')

    $root = if ($env:CLAUDE_PROJECT_DIR) { [string]$env:CLAUDE_PROJECT_DIR } else { [string]$Cwd }
    if ([string]::IsNullOrWhiteSpace($root)) { return '' }
    $root = $root.Trim().Replace('/', '\').TrimEnd('\')
    return $root.ToLowerInvariant()
}

function Get-CloseOutMarkerPath {
    <# Where the marker for one repo lives. One formula, used by the writer and the reader. #>
    param(
        [string]$ScopeKey = '',
        [string]$Root = ''
    )

    $dir = Get-SessionCacheRoot -Override $Root
    return (Join-Path $dir (Get-SessionCacheFileName -SessionId $script:CloseOutMarkerSessionId -Key $ScopeKey))
}

function Write-CloseOutMarker {
    <#
    .SYNOPSIS
        Record that a work chain ended in this repo. Returns $true when it landed.

    .DESCRIPTION
        Called from Write-CloseOutReceipt, so the marker and the printed shape have exactly one
        trigger between them and no future caller has to remember to do both.

        IT IS WRITTEN WHETHER OR NOT THE REPO HAS OPTED IN, and the band is resolved by the HOOK
        instead. That was the other way round first and it was wrong: the seam lives in the repo's
        scripts/repo-config.ps1, which a chain-ending script loads only if it happens to need it, so a
        marker conditioned on the seam would be written by some chain-ending scripts and not others --
        a gate that fires after a ship and not after a fold, with nothing anywhere saying so. The hook
        resolves the repo root itself and loads that file deliberately, which is the one place the
        answer is reliable. The cost of the other order is one small file per chain end, reaped at 24
        hours by the sweep session-cache-lib already runs.

        BEST-EFFORT BY CONTRACT, like everything else that writes into this cache: a marker that
        cannot be written means no gate on that chain, never a chain-ending script that fails.
    #>
    param(
        [string]$Cwd = '',
        [string]$Root = ''
    )

    try {
        return (Set-SessionCacheEntry -SessionId $script:CloseOutMarkerSessionId `
                                      -Key (Get-CloseOutGateScopeKey -Cwd $Cwd) `
                                      -Output @() -ExitCode 0 -Root $Root)
    } catch {
        return $false
    }
}

function Pop-CloseOutMarker {
    <#
    .SYNOPSIS
        Did a work chain end in this repo? Answers once: the marker is removed as it is read.

    .DESCRIPTION
        CONSUMING IT IS THE LOOP GUARD, and it is why this is a Pop rather than a Get. A Stop hook
        that blocks fires again on the message the block produced; with the marker already gone, that
        second firing finds no chain and exits 0. So the gate can refuse a close-out at most once, by
        construction, rather than by trusting stop_hook_active -- which is also checked, but is a
        field whose availability this repo could not confirm from the reference and therefore does not
        rest on.

        IT ALSO ANSWERS THE SCOPE QUESTION #2050 RAISED. A Stop hook fires on every turn, including
        ones that are not close-outs at all -- a question to the reader, a mid-work answer -- and
        gating those would be actively wrong. A marker exists only where Write-CloseOutReceipt ran,
        which is exactly the definition of a chain-ending turn that closeout-lib.ps1 and
        measure-closeouts.ps1 already use.

        AN UNREADABLE OR STALE MARKER IS NO MARKER, and the file is still removed: a marker that
        cannot be claimed is dead weight, and leaving it would have the NEXT turn judged against a
        chain that ended hours ago.
    #>
    param(
        [string]$Cwd = '',
        [string]$Root = ''
    )

    $key = Get-CloseOutGateScopeKey -Cwd $Cwd
    $found = $false
    try {
        $entry = Get-SessionCacheEntry -SessionId $script:CloseOutMarkerSessionId -Key $key `
                                       -Root $Root -MaxAgeHours $script:CloseOutMarkerMaxAgeHours
        $found = ($null -ne $entry)
    } catch {
        $found = $false
    }

    try {
        $path = Get-CloseOutMarkerPath -ScopeKey $key -Root $Root
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }
    } catch { }

    return $found
}

function Get-CloseOutGatePayload {
    <#
    .SYNOPSIS
        Read a Stop payload: the close-out just written, and the two fields that decide whether to look
        at it.

    .DESCRIPTION
        Takes the raw stdin text and returns @{ LastAssistantMessage; StopHookActive; Cwd; Parsed }.

        last_assistant_message IS THE VENDOR'S OWN ANSWER to the objection that killed this in #1884.
        The reference says a hook needing the final assistant text "should use last_assistant_message
        on Stop and SubagentStop instead of reading the transcript", so there is no transcript shape to
        parse and no lag behind the message being judged.

        AN UNPARSEABLE PAYLOAD FAILS TOWARDS ALLOWING, which is the opposite of Get-HookCommandPayload's
        fallback and right for the opposite reason. That one guards a checkout against a destructive
        command, so an unreadable payload has to fail towards CHECKING. This one decides whether to
        block a person's turn over a writing convention, and a hook contract that moves shape must not
        be able to strand a session. No message means no measurement means no gate.
    #>
    param([string]$Raw)

    $result = @{ LastAssistantMessage = ''; StopHookActive = $false; Cwd = ''; Parsed = $false }
    if ($null -eq $Raw) { $Raw = '' }

    try {
        $json = $Raw | ConvertFrom-Json
        if ($json -and $json -is [pscustomobject]) {
            $result.Parsed = $true
            $names = $json.PSObject.Properties.Name
            if ($names -contains 'last_assistant_message' -and $json.last_assistant_message) {
                $result.LastAssistantMessage = [string]$json.last_assistant_message
            }
            # Read as a value rather than cast: the field is a JSON boolean, and [bool] on the string
            # 'False' is $true in PowerShell -- the classic way a loop guard reads as permanently on.
            if ($names -contains 'stop_hook_active') {
                $result.StopHookActive = ($json.stop_hook_active -eq $true)
            }
            if ($names -contains 'cwd' -and $json.cwd) { $result.Cwd = ([string]$json.cwd).Trim() }
        }
    } catch { }

    return $result
}

function Get-CloseOutGateVerdict {
    <#
    .SYNOPSIS
        Pure: given a close-out and a band, should this turn be refused?

    .DESCRIPTION
        Returns @{ Blocked; Lines; Band; Reason }. Everything the hook decides is here, so the suite can
        walk every shape without a harness, a temp directory or a marker -- the hook itself is left with
        reading stdin, claiming the marker and printing.

        THE BAND IS AN UPPER BOUND, INCLUSIVE. A close-out of exactly the band passes; the gate is
        about the run-away, and an off-by-one here would make the printed band a lie.
    #>
    param(
        [string]$Message = '',
        [int]$Band = 0
    )

    $lines = Get-CloseOutLineCount -Text $Message
    $verdict = @{ Blocked = $false; Lines = $lines; Band = $Band; Reason = '' }

    if ($Band -le 0) { return $verdict }
    if ($lines -le $Band) { return $verdict }

    $verdict.Blocked = $true
    $verdict.Reason = "this close-out is $lines non-empty lines against a band of $Band."
    return $verdict
}

function Get-CloseOutGateRefusal {
    <#
    .SYNOPSIS
        What the blocked turn is told, as lines -- the one thing the model reads before rewriting.

    .DESCRIPTION
        IT OBEYS ITS OWN BAND, and that is not decoration. A refusal about length that runs fifteen
        lines teaches the opposite of what it refuses, and it is the first thing in context when the
        replacement close-out is composed.

        IT NAMES THE REHOUSING RATHER THAN THE CUTTING, because the ceiling was never a word budget:
        what does not fit goes into the branch document, the pull request body, or an issue the receipt
        cites by number. A refusal that only said "shorter" would be answered by deleting the part the
        reader most needed.
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Verdict
    )

    return @(
        "BLOCKED (closeout-gate): $($Verdict.Reason)",
        '  A close-out is a receipt, not the report: what happened, where to read it, and that the',
        '  session can be cleared. Rewrite it inside the band.',
        '  What does not fit is REHOUSED, not cut -- into the branch document, the PR body, or an',
        '  issue the receipt cites by number. This fires once per chain, so the next message stands.'
    )
}
