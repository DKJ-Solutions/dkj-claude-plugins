<#
.SYNOPSIS
    The pure half of hooks/guard-stale-paste-block.ps1: whether a shell command ships a pull request, and
    which issues that command says the PR will close (Get-ShipPrInvocation).

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
