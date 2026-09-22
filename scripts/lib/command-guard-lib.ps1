<#
.SYNOPSIS
    The false-positive machinery a PreToolUse command guard needs: read the payload, find the parts of
    a command string that will actually RUN, and hand them back as segments to match.

.DESCRIPTION
    Dot-source this file from a hook or a script:

        . (Join-Path $PSScriptRoot '..\lib\command-guard-lib.ps1')

    Supplies Get-HookCommandPayload (the stdin contract), Get-GuardSegments (the whole pipeline) and
    the pieces under it -- Remove-HeredocBodies, Remove-HereStringBodies, Test-CommandExecutesText,
    Get-LeadingCommand, Split-CommandSegments, Get-InterpreterScriptBody.

    WHY THIS EXISTS RATHER THAN A SECOND GUARD LEARNING IT AGAIN (issue #1669). This repo already
    ships a PreToolUse command guard -- dkj-subagents-shopify's guard-live-theme.ps1 -- and its header
    records what its own first version cost: matching the forbidden words anywhere in the command
    string blocked the heredoc that wrote the rule into a CLAUDE.md, and then the one-liner that later
    edited that sentence. Neither touched the store. #1669's whole premise is that a guard for the
    working-copy boundary has exactly that shape, so the answer is reused from here instead of
    rediscovered at the same price.

    THE EXEMPT SET IS THE CALLER'S, AND THAT IS THE WHOLE REASON THIS IS PARAMETERISED. The two guards
    need the same machinery and disagree about one command: `git` is EXEMPT in guard-live-theme, because
    a segment led by it is handling text rather than running the store CLI -- and it is the SUBJECT of
    the working-copy guard, where exempting it would exempt everything the guard is for. A shared
    default list would therefore be wrong for one of its two callers, so there is none: -TextTools is
    required, and each caller states its own.

    WHAT THE MACHINERY ANSWERS, in the order it applies:

      - HEREDOC BODIES are stripped. 'cat > file <<EOF ... EOF' writes data and the body never runs.
        UNLESS an interpreter is consuming it ('bash <<EOF'), in which case the body IS a script and
        nothing is stripped.
      - HERE-STRING BODIES are stripped for the same reason. A PowerShell '@'' ... ''@' body is
        assigned or piped somewhere and nothing in it runs. UNLESS the command also shows an execution
        vector (Invoke-Expression, iex, [scriptblock]::Create, or the eval/xargs/pipe-into-a-shell
        forms), in which case nothing is stripped.
      - TEXT TOOLS are skipped, per the caller's own list. UNLESS the command pipes into an interpreter
        or uses eval/xargs/iex -- 'echo "..." | bash' really does execute, and that override is what
        makes the exemption safe to have.
      - INTERPRETER WRAPPERS ARE RE-SCANNED rather than waved through. 'bash -c "<script>"' and
        'powershell -Command "<script>"' put a whole command inside a string, and a guard that reads
        only the leading command of a segment sees the interpreter and stops. That is the wrapper
        vector guard-live-theme's header names as the thing a permission rule cannot close, and it is
        closed here by splitting the body and matching its segments too, to a bounded depth.

    THIS IS THE SOURCE COPY. The twins under plugins/dkj-policy/scripts/lib/ and
    plugins/dkj-subagents/dkj-subagents-shopify/scripts/lib/ are its released mirrors, and the
    shared-scripts drift lint holds all three identical.

    guard-live-theme USED TO CARRY ITS OWN COPY OF THIS LOGIC, and #1734 retired it. #1669 extracted
    this lib and deliberately left that copy standing: a plugin must not reach into another plugin's
    tree -- they are separately versioned and separately installed -- so the route was always a second
    registry entry rather than a rewrite, the way check-report-lib is mirrored into every plugin that
    reads it. That reader count is deliberately not stated here: this sentence has already carried a
    stale one. Putting the refactor in the branch that introduced a brand-new hook would have doubled
    the review surface of both, and the half with money behind it would have got the less careful
    attention. #1734 took that route: the second entry is 'command-guard-lib-shopify' in
    Get-SharedScriptPairs, and guard-live-theme.ps1 dot-sources this file as a $PSScriptRoot-relative
    sibling. So the two guards are the two callers this file is parameterised for -- which is what the
    -TextTools block above is about -- and there is no third copy of this logic left to reconcile.

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script.
    Pure ASCII (repo convention for .ps1): Windows PowerShell 5.1 reads a BOM-less script as ANSI.
    Tested by scripts/tests/command-guard-lib.tests.ps1 -- change one, run the other.
#>

# Interpreters: a heredoc they read is a script, a pipe into them executes what came before, and a
# '-c'/'-Command' string handed to them is a command in its own right.
$script:GuardInterpreters = 'bash|sh|zsh|dash|ksh|pwsh|powershell|python|python3|node|ruby|perl'

function Get-HookCommandPayload {
    <#
    .SYNOPSIS
        Read a PreToolUse payload: the command to judge, and who is running it.

    .DESCRIPTION
        Takes the raw stdin text and returns @{ Command; AgentId; AgentType; Parsed }.

        AGENT_ID IS THE FIELD THAT SAYS "THIS IS A DISPATCHED SUBAGENT", and it is the vendor's own
        instruction rather than this repo's inference. Claude Code's shipped hook-input schema
        documents it: "Subagent identifier. Present only when the hook fires from within a subagent
        (e.g., a tool called by an AgentTool worker). Absent for the main thread, even in --agent
        sessions. Use this field (not agent_type) to distinguish subagent calls from main-thread
        calls."

        SO AGENT_TYPE IS RETURNED AND MUST NOT BE GATED ON, which is why it is here at all: the same
        schema says it is "Present when the hook fires from within a subagent (alongside agent_id), or
        on the main thread of a session started with --agent (without agent_id)". A guard keyed on it
        would refuse the main thread of every --agent session. It is returned for reports -- naming
        WHICH specialist was stopped is the difference between a refusal a reader can act on and one
        they cannot -- and never for the decision.

        AN UNPARSEABLE PAYLOAD FALLS BACK TO THE RAW TEXT for the command, so a hook contract that
        changes shape fails towards CHECKING instead of towards allowing. The same fallback is
        deliberately NOT applied to AgentId: there is no raw text that could stand in for a structured
        field, and inventing one would either block the main thread or open the gate. It comes back
        empty, and it is the CALLER that decides what an unreadable payload means -- see the guard,
        which treats "cannot tell who this is" as not-a-subagent because the alternative is a guard
        that blocks the orchestrator whenever the payload shape moves.
    #>
    param([string]$Raw)

    $result = @{ Command = ''; AgentId = ''; AgentType = ''; Cwd = ''; Parsed = $false }
    if ($null -eq $Raw) { $Raw = '' }

    try {
        $json = $Raw | ConvertFrom-Json
        if ($json) {
            $result.Parsed = $true
            if ($json.tool_input -and $json.tool_input.command) { $result.Command = [string]$json.tool_input.command }
            if ($json.PSObject.Properties.Name -contains 'agent_id'   -and $json.agent_id)   { $result.AgentId   = ([string]$json.agent_id).Trim() }
            if ($json.PSObject.Properties.Name -contains 'agent_type' -and $json.agent_type) { $result.AgentType = ([string]$json.agent_type).Trim() }
            # Cwd is where the command STARTS, and it is not the project root: an agent granted
            # worktree isolation runs with its cwd already inside its own worktree. A caller that
            # cares about which tree is being touched needs both.
            if ($json.PSObject.Properties.Name -contains 'cwd' -and $json.cwd) { $result.Cwd = ([string]$json.cwd).Trim() }
        }
    } catch { }

    if (-not $result.Command) { $result.Command = [string]$Raw }
    return $result
}

function Remove-HeredocBodies {
    <# A heredoc body is data: it is written somewhere and never runs. Unless an interpreter is
       consuming it, in which case the body IS a script and the whole text is returned untouched. #>
    param([string]$Text)

    if ($Text -notmatch '<<') { return $Text }

    $lines = $Text -split "`r?`n"
    $out = New-Object System.Collections.Generic.List[string]
    $terminator = $null

    foreach ($line in $lines) {
        if ($null -ne $terminator) {
            if ($line.Trim() -eq $terminator) { $terminator = $null }
            continue
        }

        $out.Add($line)

        # An opener looks like:  <<EOF | <<-EOF | <<'EOF' | <<"EOF"
        $m = [regex]::Match($line, '<<-?\s*(?:''([^'']+)''|"([^"]+)"|([A-Za-z_][A-Za-z0-9_]*))')
        if (-not $m.Success) { continue }

        $before = $line.Substring(0, $m.Index)
        if ($before -match "(^|[;&|]|\s)($script:GuardInterpreters|eval)\b") { return $Text }

        $terminator = ($m.Groups[1].Value + $m.Groups[2].Value + $m.Groups[3].Value)
    }

    return ($out -join "`n")
}

function Remove-HereStringBodies {
    <#
        The PowerShell twin of Remove-HeredocBodies. A here-string body is data for exactly the reason
        a heredoc body is: it is assigned or piped somewhere and nothing in it runs.

        THE CALLER GATES THIS ON -not (Test-CommandExecutesText), and that is what keeps it from being
        a hole. A body handed to Invoke-Expression, iex or [scriptblock]::Create IS a script, and then
        nothing is stripped -- the same override 'bash <<EOF' gets one function up.

        AN UNCLOSED BODY IS PUT BACK rather than dropped: without the buffer, an opener with no closer
        strips every line after it to the end of the command, so a real invocation could hide behind
        one. PowerShell would refuse to PARSE that command, and that is exactly the argument not to
        rely on -- the exemption would rest on a claim about somebody else's parser instead of on what
        this file can see.
    #>
    param([string]$Text)

    if ($Text -notmatch '@[''"]') { return $Text }

    $lines = $Text -split "`r?`n"
    $out = New-Object System.Collections.Generic.List[string]
    $held = New-Object System.Collections.Generic.List[string]
    $terminator = $null

    foreach ($line in $lines) {
        if ($null -ne $terminator) {
            # The language requires the closer at the START of a line. Leading whitespace is tolerated
            # anyway, because tolerating it can only end a body EARLY -- which scans MORE text, never
            # less, and therefore fails towards checking.
            if ($line -match ('^\s*' + $terminator + '@')) { $terminator = $null; $held.Clear() }
            else { $held.Add($line) }
            continue
        }

        $out.Add($line)

        # An opener is @' or @" with nothing after it but whitespace -- the language's own rule, which
        # keeps a quote-at-sign inside an expression from being mistaken for one.
        $m = [regex]::Match($line, '@([''"])\s*$')
        if (-not $m.Success) { continue }
        $terminator = [regex]::Escape($m.Groups[1].Value)
    }

    if ($null -ne $terminator) { $out.AddRange($held) }
    return ($out -join "`n")
}

function Test-CommandExecutesText {
    <# Does this command put text somewhere that will execute it? A pipe into an interpreter, an eval,
       an xargs, or PowerShell's Invoke-Expression / iex / [scriptblock]::Create. When any of those is
       in play no segment gets the text-tool exemption and no body is stripped. #>
    param([string]$Text)

    if (-not $Text) { return $false }
    return ($Text -match "\|\s*($script:GuardInterpreters)\b") -or
           ($Text -match '\beval\b') -or
           ($Text -match '\bxargs\b') -or
           ($Text -match '\b(invoke-expression|iex)\b') -or
           ($Text -match '\[scriptblock\]::create')
}

function Get-LeadingCommand {
    <# The command a segment is led by, lowercased and stripped of its path: leading env assignments
       (FOO=bar cmd) and a subshell/brace opener are dropped first. #>
    param([string]$Segment)

    $s = [string]$Segment
    $s = $s.Trim()
    while ($s -match '^\(?\{?\s*[A-Za-z_][A-Za-z0-9_]*=[^\s]*\s+(.*)$') { $s = $Matches[1].Trim() }
    $s = $s -replace '^[\(\{\s]+', ''
    if ($s -match '^([^\s]+)') { return ($Matches[1] -replace '.*[\\/]', '').ToLower() }
    return ''
}

function Split-CommandSegments {
    <# Split into shell segments, so a real command next to a harmless one is still seen. Newlines
       count, which is what makes an unstripped body's every line its own segment -- the reason
       Remove-HereStringBodies has to run before this and not after. #>
    param([string]$Text)

    if (-not $Text) { return @() }
    return [regex]::Split($Text, '(?:\|\||&&|[;|\r\n])')
}

function Get-InterpreterScriptBody {
    <#
    .SYNOPSIS
        If this segment is an interpreter handed a command STRING, return that string. Otherwise $null.

    .DESCRIPTION
        'bash -c "git checkout main"' and 'powershell -Command "git reset --hard"' are one command
        wearing another's leading word. guard-live-theme.ps1's header names this vector as the thing a
        permission rule cannot close, because a deny entry matches a command PREFIX and never sees the
        same command wrapped.

        A guard that reads the SUBCOMMAND POSITION -- which is how a working-copy guard avoids refusing
        `git commit -m "never run git checkout"` -- is blind to it for the same reason: the leading word
        is the interpreter. So the body is handed back for the caller to split and match in its own
        right.

        ONLY A -c / -Command / -EncodedCommand-shaped invocation qualifies. 'bash script.sh' runs a
        FILE, whose contents this hook cannot see and must not pretend to; that is a residual limit
        stated in the caller rather than a case handled badly here.

        THE QUOTES ARE THE BOUNDARY AND NOTHING ELSE IS ASSUMED. Whatever follows the flag is taken as
        the body: a matching quote pair when there is one, otherwise the rest of the segment. Taking
        the rest can only scan MORE text than the shell would run, never less, so it fails towards
        checking.
    #>
    param([string]$Segment)

    $s = ([string]$Segment).Trim()
    if (-not $s) { return $null }

    $lead = Get-LeadingCommand $s
    if ($lead -notmatch "^($script:GuardInterpreters)$") { return $null }

    # -c (posix), -Command/-c (powershell). -EncodedCommand is base64 and is deliberately NOT decoded:
    # see the caller's residual-limits note.
    $m = [regex]::Match($s, '(?:^|\s)(?:-c|-Command|-command|/c)\s+(.+)$')
    if (-not $m.Success) { return $null }

    $body = $m.Groups[1].Value.Trim()
    if ($body.Length -ge 2) {
        $first = $body[0]
        if (($first -eq '"' -or $first -eq "'") -and $body[$body.Length - 1] -eq $first) {
            return $body.Substring(1, $body.Length - 2)
        }
    }
    return $body
}

function Get-GuardSegments {
    <#
    .SYNOPSIS
        The whole pipeline: from a raw command string to the segments a guard should match.

    .DESCRIPTION
        -TextTools is REQUIRED and has no default: the two guards in this repo disagree about `git`,
        and a shared default would be wrong for one of them. See this file's header.

        -MaxDepth bounds the wrapper recursion. Two is enough for every real form ('bash -c "pwsh
        -Command ..."') and the bound exists because a crafted string could otherwise nest without
        end; a hook has a timeout and must return.

        Returns the segments to match. A caller matches its own patterns against each; everything the
        pipeline has exempted is simply absent.
    #>
    param(
        [string]$Command,
        [Parameter(Mandatory = $true)][string[]]$TextTools,
        [int]$MaxDepth = 2
    )

    if (-not $Command) { return @() }

    $scan = Remove-HeredocBodies $Command
    $executesText = Test-CommandExecutesText $scan
    if (-not $executesText) { $scan = Remove-HereStringBodies $scan }

    $out = New-Object System.Collections.Generic.List[string]
    $pending = New-Object System.Collections.Generic.List[object]
    $pending.Add(@{ Text = $scan; Depth = 0; ExecutesText = $executesText })

    while ($pending.Count -gt 0) {
        $current = $pending[0]
        $pending.RemoveAt(0)

        foreach ($segment in (Split-CommandSegments $current.Text)) {
            if (-not $segment.Trim()) { continue }

            # A wrapper is expanded BEFORE the exemption is considered, so an interpreter that also
            # appears in somebody's text-tool list (perl is in guard-live-theme's) cannot smuggle a
            # command through inside a -c string.
            if ($current.Depth -lt $MaxDepth) {
                $body = Get-InterpreterScriptBody $segment
                if ($body) {
                    $inner = Remove-HeredocBodies $body
                    $innerExecutes = Test-CommandExecutesText $inner
                    if (-not $innerExecutes) { $inner = Remove-HereStringBodies $inner }
                    $pending.Add(@{ Text = $inner; Depth = $current.Depth + 1; ExecutesText = $innerExecutes })
                    continue
                }
            }

            if (-not $current.ExecutesText) {
                $lead = Get-LeadingCommand $segment
                if ($TextTools -contains $lead) { continue }
            }

            $out.Add($segment)
        }
    }

    return $out.ToArray()
}
