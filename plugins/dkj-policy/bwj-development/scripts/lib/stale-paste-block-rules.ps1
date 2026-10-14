<#
.SYNOPSIS
    The pure half of hooks/guard-stale-paste-block.ps1: whether a shell command ships a pull request, and
    which issues that command says the PR will close (Get-ShipPrInvocation) -- and whether it closes an
    issue as completed by hand, with 'gh issue close' (Get-IssueCloseInvocation, #3004).

.DESCRIPTION
    INBOUND #2968. The go-live block an issue carries is what the asana-closed-message workflow forwards
    into the Asana task when the issue closes. An issue closed after round 1, reopened, and closed again
    by round 2's PR carried round 1's block into the task as round 2's result, because the session
    posted the corrected block only after the merge. The hook refuses the ship while the block predates
    the reopen; the judgement of 'predates' is Get-AsanaPasteBlockVerdict in asana-task-lib.ps1, and
    this file only reads the command line.

    WHY THE COMMAND IS PARSED HERE AND NOT BY THE CORE LIB. dkj-policy's pr-issues-lib.ps1 owns
    ConvertTo-IssueNumberList, but a bwj-development script reaches into no second plugin's libs, so
    the same liberal reading (comma, space, semicolon, a leading '#') is written again, smaller: only
    the numbers, only after -Resolves.

    AN ACCIDENT GUARD, NOT AN ADVERSARIAL ONE. It reads the command the way a session writes it and no
    further. Out of reach, on purpose: pwsh -Command "..." and any other string that is itself a command
    line, values taken from $env or a variable, a script reached through an alias or a wrapper, and
    deliberate obfuscation. A ship that slips past is not lost: the workflow's own check at the close
    (templates/asana-closed-message.ps1) is the backstop.

    WHAT IT RECOGNISES. A QUOTE-AWARE TOKENISER splits the command into segments at an unquoted ';', '&&',
    '||', '|', a lone '&' that is not the call operator, or a newline, and drops an unquoted '# comment'.
    A quoted string is one token, so '-Title "a; b" -Resolves 5' keeps its 5. A segment ships when its
    first token (after '&' or '.') is ship-pr.ps1 / open-pr.ps1 -- by its leaf name, a path with spaces
    in quotes included -- or is powershell / pwsh whose arguments reach one of those leaves, with or
    without -File. A mention (a commit message, a grep, reading the file, 'ship-pr.ps1.bak') is not a
    ship. After the script, '-GatesOnly' (no PR, no merge: not a ship), '-NoResolves' and '-Resolves
    <list>' count only as BARE tokens: the same text inside a quoted string, or after a '#', is a value.

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/guard-stale-paste-block.tests.ps1 in
    the source repo -- change one, run the other.
#>

function ConvertTo-ShellSegments {
    <#
        Pure: -Command split into segments, each a list of tokens (Text, Quoted). Quote-aware over ' and ",
        so a separator inside a string stays in it; an unquoted '#' that opens a token starts a comment to
        the end of the line. A lone '&' at the head of a segment is the call operator and stays as a token.
    #>
    param([AllowEmptyString()][string]$Command = '')

    $segments = @()
    $tokens   = New-Object System.Collections.Generic.List[object]
    $cur      = New-Object System.Text.StringBuilder
    $started  = $false
    $quoted   = $false
    $quote    = [char]0
    $text     = [string]$Command
    $i = 0
    while ($i -lt $text.Length) {
        $c = $text[$i]
        if ($quote -ne [char]0) {
            if ($c -eq $quote) { $quote = [char]0 } else { [void]$cur.Append($c) }
            $i++; continue
        }
        if ($c -eq '''' -or $c -eq '"') { $quote = $c; $started = $true; $quoted = $true; $i++; continue }
        if ($c -eq '#' -and -not $started) {
            while ($i -lt $text.Length -and $text[$i] -ne "`n") { $i++ }
            continue
        }
        $isSep = $false
        if ($c -eq ';' -or $c -eq '|' -or $c -eq "`n") { $isSep = $true }
        elseif ($c -eq '&') {
            if ($i + 1 -lt $text.Length -and $text[$i + 1] -eq '&') { $isSep = $true; $i++ }
            elseif ($started -or $tokens.Count -gt 0) { $isSep = $true }
            else { [void]$cur.Append($c); $started = $true; $i++; continue }
        }
        if ($isSep) {
            if ($started) { $tokens.Add([pscustomobject]@{ Text = $cur.ToString(); Quoted = $quoted }) }
            [void]$cur.Clear(); $started = $false; $quoted = $false
            if ($c -eq '|' -and $i + 1 -lt $text.Length -and $text[$i + 1] -eq '|') { $i++ }
            if ($tokens.Count -gt 0) { $segments += ,@($tokens.ToArray()); $tokens.Clear() }
            $i++; continue
        }
        if ([char]::IsWhiteSpace($c)) {
            if ($started) { $tokens.Add([pscustomobject]@{ Text = $cur.ToString(); Quoted = $quoted }) }
            [void]$cur.Clear(); $started = $false; $quoted = $false
            $i++; continue
        }
        [void]$cur.Append($c); $started = $true; $i++
    }
    if ($started) { $tokens.Add([pscustomobject]@{ Text = $cur.ToString(); Quoted = $quoted }) }
    if ($tokens.Count -gt 0) { $segments += ,@($tokens.ToArray()) }
    return @($segments)
}

function Get-ShipPrInvocation {
    <#
        Pure: $null where -Command does not run ship-pr.ps1 or open-pr.ps1 as a shipping run; else
        Resolves (the issue numbers -Resolves names, distinct, at most 20, in order) and NoResolves ($true
        where -NoResolves is passed, the declared "this PR closes no issue"). Where several segments ship,
        every one's numbers are returned together. See the file header for what is, and is not, read.
    #>
    param([AllowEmptyString()][string]$Command = '')

    $leaf = '(?i)\A(?:ship-pr|open-pr)\.ps1\z'
    $found      = $false
    $noResolves = $false
    $numbers    = New-Object System.Collections.Generic.List[int]
    foreach ($segment in @(ConvertTo-ShellSegments -Command $Command)) {
        $tok = @($segment)
        $at = 0
        while ($at -lt $tok.Count -and -not $tok[$at].Quoted -and ($tok[$at].Text -eq '&' -or $tok[$at].Text -eq '.')) { $at++ }
        if ($at -ge $tok.Count) { continue }

        # Where is the script token? At the head, or among a powershell/pwsh start's arguments.
        $scriptAt = -1
        $head = ($tok[$at].Text -split '[\\/]')[-1]
        if ($head -match $leaf) { $scriptAt = $at }
        elseif ($head -match '(?i)\A(?:powershell|pwsh)(?:\.exe)?\z') {
            for ($k = $at + 1; $k -lt $tok.Count; $k++) {
                if (-not $tok[$k].Quoted -and $tok[$k].Text -match '(?i)\A-(?:c|command|encodedcommand|e|ec)\z') { break }
                if (($tok[$k].Text -split '[\\/]')[-1] -match $leaf) { $scriptAt = $k; break }
            }
        }
        if ($scriptAt -lt 0) { continue }

        $gatesOnly = $false
        $seg = New-Object System.Collections.Generic.List[int]
        for ($k = $scriptAt + 1; $k -lt $tok.Count; $k++) {
            if ($tok[$k].Quoted) { continue }
            $t = $tok[$k].Text
            if ($t -match '(?i)\A-GatesOnly(?::.*)?\z') { $gatesOnly = $true; continue }
            if ($t -match '(?i)\A-NoResolves(?::.*)?\z') { $noResolves = $true; continue }
            if ($t -match '(?i)\A-Resolves(?:[:=](.*))?\z') {
                $value = $Matches[1]
                if ($null -eq $value -or $value -eq '') { if ($k + 1 -lt $tok.Count) { $value = $tok[$k + 1].Text; $k++ } else { $value = '' } }
                foreach ($d in [regex]::Matches($value, '\d+')) {
                    $n = 0
                    if ([int]::TryParse($d.Value, [ref]$n) -and $n -gt 0 -and -not $seg.Contains($n)) { $seg.Add($n) }
                }
            }
        }
        if ($gatesOnly) { continue }
        $found = $true
        foreach ($n in $seg) { if (-not $numbers.Contains($n) -and $numbers.Count -lt 20) { $numbers.Add($n) } }
    }
    if (-not $found) { return $null }
    return [pscustomobject]@{ Resolves = @($numbers); NoResolves = $noResolves }
}

function ConvertTo-IssueCloseTarget {
    <#
        Pure: one positional argument of 'gh issue close' as Number and Repo ('' for the current repo), or
        $null where it names no issue. The three spellings gh itself accepts: a number, '#<n>', and the
        issue's URL, whose owner/name then becomes the repo.
    #>
    param([AllowEmptyString()][string]$Text = '')

    if ($Text -match '\A#?(\d+)\z') { return [pscustomobject]@{ Number = [int]$Matches[1]; Repo = '' } }
    if ($Text -match '\Ahttps://github\.com/([A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9._-]+)/issues/(\d+)/?\z') {
        return [pscustomobject]@{ Number = [int]$Matches[2]; Repo = $Matches[1] }
    }
    return $null
}

function Get-IssueCloseInvocation {
    <#
        Pure: $null where -Command closes no issue AS COMPLETED with 'gh issue close'; else Closes -- the
        issues it closes that way, each Number and Repo ('' for the current repo, else the owner/name of
        --repo/-R or of an issue URL), distinct, at most 20 (#3004).

        THE CLOSE GUARD'S HALF. A research, test or decision ticket is closed by hand, with no pull
        request, so the ship guard never sees it: smartwatchbanden#943 was closed this way with no block,
        and the requester got a bare 'is now closed'. The hook refuses such a close until the issue
        carries a block for this round.

        WHAT COUNTS AS COMPLETED: no --reason/-r, or 'completed'. 'not planned' (also written
        'not_planned') and 'duplicate', or --duplicate-of, are skipped: the closed message posts no block
        for those, so there is nothing to guard. The reason is read as a bare or quoted token, and
        --reason=<value> too. A segment is a close when its first token (after '&' or '.') is gh or
        gh.exe, by its leaf name, followed by the bare tokens 'issue' and 'close'.

        AN ACCIDENT GUARD, with the same reach as Get-ShipPrInvocation: the tokeniser above, so a
        mention is not a close, and 'gh api ... state=closed', a value from a variable or a wrapper is out
        of reach. The workflow's own message is the backstop: a close without a block says the result
        message follows.
    #>
    param([AllowEmptyString()][string]$Command = '')

    $closes = New-Object System.Collections.Generic.List[object]
    foreach ($segment in @(ConvertTo-ShellSegments -Command $Command)) {
        $tok = @($segment)
        $at = 0
        while ($at -lt $tok.Count -and -not $tok[$at].Quoted -and ($tok[$at].Text -eq '&' -or $tok[$at].Text -eq '.')) { $at++ }
        if ($at + 2 -ge $tok.Count) { continue }
        if (($tok[$at].Text -split '[\\/]')[-1] -notmatch '(?i)\Agh(?:\.exe)?\z') { continue }
        if ($tok[$at + 1].Quoted -or $tok[$at + 1].Text -ne 'issue' -or $tok[$at + 2].Quoted -or $tok[$at + 2].Text -ne 'close') { continue }

        $reason  = ''
        $repo    = ''
        $targets = @()
        for ($k = $at + 3; $k -lt $tok.Count; $k++) {
            $t = $tok[$k].Text
            # CASE-SENSITIVE THROUGHOUT: gh's -r is the reason and its -R the repo.
            if (-not $tok[$k].Quoted -and $t -cmatch '\A(--reason|-r|--repo|-R|--comment|-c|--duplicate-of)(?:=(.*))?\z') {
                $flag  = $Matches[1]
                $value = $Matches[2]
                if ($null -eq $value) { if ($k + 1 -lt $tok.Count) { $k++; $value = $tok[$k].Text } else { $value = '' } }
                if ($flag -ceq '--reason' -or $flag -ceq '-r') { $reason = ([string]$value).Trim().ToLowerInvariant() }
                elseif ($flag -ceq '--repo' -or $flag -ceq '-R') { $repo = ([string]$value).Trim() }
                elseif ($flag -ceq '--duplicate-of') { $reason = 'duplicate' }
                continue
            }
            if (-not $tok[$k].Quoted -and $t.StartsWith('-')) { continue }
            $target = ConvertTo-IssueCloseTarget -Text $t
            if ($target) { $targets += $target }
        }
        if ($reason -and $reason -ne 'completed') { continue }
        foreach ($target in $targets) {
            $r = if ($target.Repo) { $target.Repo } else { $repo }
            if ($r -and $r -notmatch '\A[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9._-]+\z') { continue }
            $dup = @($closes | Where-Object { $_.Number -eq $target.Number -and $_.Repo -eq $r }).Count -gt 0
            if (-not $dup -and $closes.Count -lt 20) { $closes.Add([pscustomobject]@{ Number = $target.Number; Repo = $r }) }
        }
    }
    if ($closes.Count -eq 0) { return $null }
    return [pscustomobject]@{ Closes = @($closes.ToArray()) }
}