<#
.SYNOPSIS
    The judgement behind publish-background-run.ps1: what, if anything, a backgrounded shell call should
    publish to the progress record -- issue #2104.

.DESCRIPTION
    Dot-source this file:

        . (Join-Path $PSScriptRoot '..\lib\background-run-lib.ps1')

    WHY THE JUDGEMENT IS HERE AND NOT IN THE HOOK. A hook is a process with a payload on stdin, so a
    decision left inside it can only be tested by starting one -- which is how guard-working-copy.ps1
    came to keep its own judgement in a lib beside it, and this follows that. Get-BackgroundRunPublishPlan
    is a pure function of the payload text: no process, no CIM query, no clock. The one step that does
    touch the live machine, Get-BackgroundShellProcessId, is separated out for exactly that reason.

    THE PLAN IS A DECISION, NOT A FORMAT. It answers "should anything be published, and under what name
    and label" -- and every reason for publishing nothing is a $false rather than a throw, because the
    hook's whole contract is that a bar it cannot draw costs the tool call nothing.

    Pure ASCII (repo convention for .ps1).
#>

function Get-BackgroundRunPublishPlan {
    <#
        Read a PostToolUse payload and decide what this backgrounded call should publish.

        RETURNS a plan with ShouldPublish, and where that is $true: RepoRoot, Name, Label, Note and
        Command. Where it is $false the rest is still present and empty, so a caller never has to
        null-check before reading -- the same shape Invoke-NativeCapture uses for the fields only one
        of its arms can fill.

        backgroundTaskId IS A STRUCTURED FIELD, measured rather than parsed out of result text: the
        PostToolUse payload carries tool_response.backgroundTaskId (e.g. "b972u1th4") alongside stdout,
        stderr, interrupted, isImage and noOutputExpected. #2104 recorded recovering the task id as
        unmeasured; this is the measurement, and it lands in the favourable direction.

        THE ID IS KEYED ON THAT TASK ID rather than on the command, because two backgrounded runs at
        once is ordinary -- a ship in one lane and a gate in another -- and a shared key would have the
        second overwrite the first's record with nothing saying so. Get-RunProgressId appends the
        writer's pid on top, which is the shell's here rather than the hook's.

        THE LABEL PREFERS THE DESCRIPTION, because a person wrote it about this call and the command is
        a shell line that may be a hundred characters of pipeline. The command is the fallback and the
        formatter's own ceiling trims whichever arrives.
    #>
    # AllowEmptyString BESIDE AllowNull: Mandatory refuses '' on its own, and '' is a state this has a
    # verdict for rather than an error -- a hook whose stdin read came back empty must get "publish
    # nothing", not an exception it then has to catch.
    param([Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][string]$Payload)

    $plan = [ordered]@{
        ShouldPublish = $false
        RepoRoot      = ''
        Name          = ''
        Label         = ''
        # DELIBERATELY EMPTY, and measured rather than assumed. Format-RunProgressLine renders the note
        # after the label and trims the pair to a ceiling, so a note here is spent from the label's own
        # budget: with 'backgrounded' the first end-to-end run rendered as
        # "... Second end-to-end backgrounded run (bac...  +9s" -- the note truncated mid-word and the
        # label robbed to pay for it. It also says nothing a reader needs: every record this hook writes
        # is a backgrounded call, and the label already names which one.
        Note          = ''
        Command       = ''
    }

    if (-not $Payload) { return [pscustomobject]$plan }

    $parsed = $null
    # A PAYLOAD THIS CANNOT READ PUBLISHES NOTHING. There is no safe half-answer here: the whole record
    # is built out of fields, so a shape this does not recognise is a hook that stays quiet rather than
    # one that invents a label.
    try { $parsed = $Payload | ConvertFrom-Json } catch { return [pscustomobject]$plan }
    if ($null -eq $parsed) { return [pscustomobject]$plan }

    # The gate, read properly this time rather than as the raw-string pre-gate the hook uses to get here.
    $isBackground = $false
    if ($parsed.PSObject.Properties['tool_input'] -and $parsed.tool_input) {
        if ($parsed.tool_input.PSObject.Properties['run_in_background']) {
            $isBackground = [bool]$parsed.tool_input.run_in_background
        }
    }
    if (-not $isBackground) { return [pscustomobject]$plan }

    $taskId = ''
    if ($parsed.PSObject.Properties['tool_response'] -and $parsed.tool_response) {
        if ($parsed.tool_response.PSObject.Properties['backgroundTaskId']) {
            $taskId = "$($parsed.tool_response.backgroundTaskId)"
        }
    }
    # NO TASK ID, NO RECORD. Without it two concurrent runs cannot be told apart, and a bar that jumps
    # between two unrelated runs with nothing saying so is worse than no bar -- run-progress-lib's own
    # argument for putting the pid in the id in the first place.
    if (-not $taskId.Trim()) { return [pscustomobject]$plan }

    if ($parsed.tool_input.PSObject.Properties['command']) { $plan.Command = "$($parsed.tool_input.command)" }
    $label = ''
    if ($parsed.tool_input.PSObject.Properties['description']) { $label = "$($parsed.tool_input.description)" }
    if (-not $label.Trim()) { $label = $plan.Command }
    if (-not $label.Trim()) { $label = 'background run' }

    # THE REPO ROOT COMES FROM THE PAYLOAD FIRST. cwd is what the session is actually standing in, which
    # is the tree whose scripts/lib the caller then looks in; CLAUDE_PROJECT_DIR is the fallback for a
    # payload shape that does not carry it. Neither is validated here -- the caller's Test-Path on the
    # lib is the real check, and it fails closed into "publish nothing".
    $root = ''
    if ($parsed.PSObject.Properties['cwd']) { $root = "$($parsed.cwd)" }
    if (-not $root.Trim() -and $env:CLAUDE_PROJECT_DIR) { $root = "$($env:CLAUDE_PROJECT_DIR)" }
    if (-not $root.Trim()) { return [pscustomobject]$plan }

    $plan.RepoRoot = $root
    $plan.Name = "bg-$taskId"
    $plan.Label = $label
    $plan.ShouldPublish = $true
    return [pscustomobject]$plan
}

function Get-CommandMatchKey {
    <#
        Reduce a command string to something comparable across the shell's own quoting.

        MEASURED, NOT ANTICIPATED (issue #2104, 18 September 2026). The payload's tool_input.command is
        what the caller wrote -- `echo "E2E-2104 start"; sleep 40` -- while the shell Claude Code
        launches carries it re-quoted inside a larger line:

            ... && eval 'echo \"E2E-2104 start\"; sleep 40; echo \"E2E-2104 end\"' < /dev/null && pwd ...

        so a plain Contains() matched NOTHING for any command containing a double quote, which is most
        of them. The first end-to-end run of this hook published no record at all for exactly that
        reason, and nothing in the unit tests could have shown it: both sides were fixtures.

        DROPPING BOTH QUOTES AND BACKSLASHES rather than inverting the one escape measured. `\"` -> `"`
        is the exact inverse of what was seen, and it is also a guess that this is the only re-quoting
        any shell on any platform applies. Both sides go through the SAME reduction, so a Windows path
        or an inner quote is stripped from the needle and the haystack alike and they still meet.

        THE COST IS A WIDER MATCH, and it is bounded by what the caller does with it: the process must
        not be this one, the newest match wins, and the record is keyed on backgroundTaskId, so the
        worst case is one bar attributed to the wrong shell rather than a corrupted record.
    #>
    param([Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][string]$Text)
    if (-not $Text) { return '' }
    return ($Text -replace '[\\"]', '')
}

function Get-BackgroundShellProcessId {
    <#
        The pid of the shell running a backgrounded command, or 0.

        THIS IS THE ONE FUNCTION THAT TOUCHES THE LIVE MACHINE, which is why it is separated from the
        plan above: everything else in this file can be driven from a string.

        MATCHED ON THE COMMAND TEXT, and the cost of that is stated rather than hidden. Claude Code
        launches a backgrounded call through a shell whose command line carries a long prefix -- a
        shell-snapshot source and a run of exports -- and then the command itself, so the command text
        is a substring rather than the whole line. Measured 18 September 2026: the shell is visible
        829 ms after launch as a bash.exe parented by the Claude Code process, and one Win32_Process
        query costs 589 ms.

        THE YOUNGEST MATCH WINS, because two identical commands backgrounded at the same instant are
        indistinguishable by text and the one just launched is the one this payload is about. That is a
        real limit and not a solved problem: it is the reason the record is keyed on backgroundTaskId,
        so a wrong pid costs one bar rather than corrupting another run's.

        0 ON EVERY FAILURE -- an unreadable query, no match, an empty command. The caller publishes
        nothing on 0, deliberately: a record naming a process that is not the run either vanishes at the
        next read or outlives the run, and both are worse than the absence of a bar.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][string]$CommandText,
        [int]$SelfPid = $PID
    )

    if (-not $CommandText -or -not $CommandText.Trim()) { return 0 }

    # BOTH SIDES THROUGH THE SAME REDUCTION -- see Get-CommandMatchKey for the measurement that forced
    # it. A raw Contains() here matched nothing for any command carrying a double quote.
    $needle = Get-CommandMatchKey -Text $CommandText
    if (-not $needle.Trim()) { return 0 }

    # NOT $matches: that is a PowerShell AUTOMATIC variable, written by every -match this scope runs.
    # Assigning to it works and then something else silently overwrites it -- the well-formed wrong
    # output this repo keeps a trap list for.
    $found = @()
    try {
        $found = @(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {
            $_.CommandLine -and $_.ProcessId -ne $SelfPid -and
            (Get-CommandMatchKey -Text $_.CommandLine).Contains($needle)
        })
    } catch { return 0 }

    if ($found.Count -eq 0) { return 0 }
    $newest = @($found | Sort-Object -Property CreationDate -Descending)[0]
    if (-not $newest) { return 0 }
    return [int]$newest.ProcessId
}
