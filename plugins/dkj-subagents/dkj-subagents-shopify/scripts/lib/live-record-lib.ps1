<#
.SYNOPSIS
    The LIVE-PUSH RECORD: which of a release range's theme files are on the live target after the push,
    written by live-preflight and read by cut-release. Plus the rules both documents of a cut apply to it:
    which merge commit carries an entry, whether that entry is live, and how a solved task is rendered in
    the audience note. Pure -- no git, no gh, no seam read, no file IO.

.DESCRIPTION
    Dot-source this file from a sibling of the script that needs it, relative to $PSScriptRoot:

        . (Join-Path $PSScriptRoot '..\lib\live-record-lib.ps1')

    ------------------------------------------------------------------------------------------------
    WHY THIS EXISTS (#2570 and #2586, built together, Dave, September 28, 2026). A cut in a repo with a
    live stage produces two documents about the same release, and neither could see what the live push
    actually carried:

      THE GITHUB BODY listed every merged entry under 'What landed'. Measured in a BWJ store at v1.3.0:
      PR #295's only theme file was deliberately held back from the push, so the fix was not in front of
      customers while the Release page said it had landed. The owner read "landed" as live, which is what
      a release MEANS in a repo whose Get-LiveStage is a theme push.

      THE AUDIENCE NOTE listed a solved task (consumer #190, via PR #282) whose removal the per-file
      `--only` push did not carry -- 21 files were still on the live theme. The same release's GitHub
      body, hand-corrected, listed #282 as not live. Two documents, one release, opposite answers.

    ONE INPUT DECIDES BOTH, which is the whole argument for this file. Built twice, the two can disagree,
    and at v1.3.0 they did. So the record has one format, one parser and one "is this entry live" rule,
    here, and both plugins that touch it -- dkj-subagents-shopify writes it, dkj-policy reads it -- carry
    this file as a byte-identical mirror.
    ------------------------------------------------------------------------------------------------

    THE FORMAT, AND WHY IT IS THIS SMALL. One line per theme file the range changed:

        live  sections/header.liquid
        hold  snippets/product-info.liquid

    'live' means the range's change to the file is on the live target after this push: the push
    carries it, a sync mirrored it FROM live, or -- for a file the range deletes -- the deletion command
    removes it (#2641). 'hold' means it is not: a person held it back, or the range deletes it and no
    deletion command was composed. '#' starts a comment line. Paths not in the
    record are no concern of the live target (scripts, docs, CI), which is also how the record answers
    "is this a storefront change": an entry that touched none of its paths did not change the store.

    WHY A PERSON EDITS IT RATHER THAN THE PREFLIGHT KNOWING. The v1.3.0 hold-back was decided AFTER the
    preflight ran, by the person composing the push. No script sees that decision unless somebody writes
    it down, so the record is the place to write it: change 'live' to 'hold' on the line you held back.

    No Set-StrictMode here: dot-sourcing would change the strict mode of the calling script.
    Pure ASCII (repo convention for .ps1).
#>

function ConvertTo-LiveRecordKey {
    <# One path's comparison key: forward slashes, trimmed. Compared case-insensitively by every caller. #>
    param([AllowNull()][string]$Path)
    if ($null -eq $Path) { return '' }
    return (([string]$Path).Trim() -replace '\\', '/')
}

function Format-LivePushRecord {
    <#
    .SYNOPSIS
        The record's text, from live-push-rules' Get-LivePushRows. Hard LF, ending in one newline.

    .DESCRIPTION
        THREE KINDS OF ROW BECOME A LINE, ONE DOES NOT:

          theme-file        live -- the push carries it.
          sync-owned        live -- a sync mirrored it FROM live, so it is there whether or not it is pushed.
          deleted           live with -DeletionsCarried, hold without it. An `--only` push of a path
                            missing from the checkout REMOVES it from live (#2641), so the deletion is
                            live exactly when the caller composed that command; without the switch
                            nothing removes the old version, and it is still on live.
          not-a-theme-path  no line. It does not exist on a theme, so it cannot be live or held there.

        THE HEADER SAYS WHAT TO DO WITH THE FILE, because the person who reads it is holding a push
        command and is about to decide what goes into it. It names the range, so a record left over
        from an earlier release is recognisable as one.
    #>
    param(
        [AllowNull()][AllowEmptyCollection()][object[]]$Rows = @(),
        [string]$Range = '',
        [switch]$DeletionsCarried
    )
    $deletedVerb = if ($DeletionsCarried) { 'live' } else { 'hold' }
    $out = New-Object System.Collections.Generic.List[string]
    $out.Add('# live-push record -- written by live-preflight' + $(if ($Range) { " for $Range" } else { '' }))
    $out.Add('# One line per theme file in the range: "live <path>" means its change is on the live theme after this push,')
    $out.Add('# "hold <path>" means it is not. If you hold a file back from the push, change its "live" to "hold".')
    if ($DeletionsCarried) {
        $out.Add('# A file the range deletes is "live" once the deletion command removes it; skip that command, and mark it "hold".')
    } else {
        $out.Add('# A file the range deletes is "hold": no deletion command was composed, so it is still on live.')
    }
    $out.Add('# cut-release reads this file (-LivePushRecord) for the GitHub body and the audience note.')
    foreach ($r in @($Rows)) {
        if ($null -eq $r) { continue }
        $path = ([string]$r.Path).Trim()
        if (-not $path) { continue }
        switch ([string]$r.Kind) {
            'theme-file' { $out.Add("live $path") }
            'sync-owned' { $out.Add("live $path") }
            'deleted'    { $out.Add("$deletedVerb $path") }
            default      { }
        }
    }
    return (($out -join "`n") + "`n")
}

function ConvertFrom-LivePushRecord {
    <#
    .SYNOPSIS
        Parse a record into { Live = string[]; Hold = string[] }. Throws on a line it cannot read.

    .DESCRIPTION
        REFUSED RATHER THAN SKIPPED: a line that is neither a comment, blank, 'live <path>' nor
        'hold <path>'. The record exists to be edited by hand, so a typo ('hodl') is the expected
        failure, and skipping that line would read the file as live, which is exactly the claim the
        record exists to stop. The line number is in the message so the person can find it.

        A PATH ON BOTH VERBS IS REFUSED TOO. A 'hold' added under a 'live' that was not removed is the
        second likely edit, and silently letting either one win decides the question for the person.
    #>
    param([AllowNull()][AllowEmptyString()][string]$Text)
    $live = New-Object System.Collections.Generic.List[string]
    $hold = New-Object System.Collections.Generic.List[string]
    $seen = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $n = 0
    foreach ($raw in @(([string]$Text -replace "`r`n", "`n") -split "`n")) {
        $n++
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        $m = [regex]::Match($line, '^(live|hold)\s+(\S.*)$')
        if (-not $m.Success) {
            throw "live-push record, line ${n}: expected 'live <path>' or 'hold <path>', found something else."
        }
        $verb = $m.Groups[1].Value
        $key = ConvertTo-LiveRecordKey $m.Groups[2].Value
        if ($seen.ContainsKey($key)) {
            if ($seen[$key] -ne $verb) { throw "live-push record, line ${n}: the same path is listed as both 'live' and 'hold'. Keep one line for it." }
            continue
        }
        $seen[$key] = $verb
        if ($verb -eq 'live') { $live.Add($key) } else { $hold.Add($key) }
    }
    return [pscustomobject]@{ Live = @($live); Hold = @($hold) }
}

function Find-BranchMergeCommit {
    <#
    .SYNOPSIS
        The sha of the 'merge: <branch> (#NN)' commit that landed $Branch, from first-parent log lines
        shaped '<sha><TAB><subject>'. '' when there is none.

    .DESCRIPTION
        THE SUBJECT SHIP-PR WRITES, matched exactly: 'merge: ', the branch, ' (#', digits, ')'. It is
        the one trace a merged entry leaves that names its branch and lets the cut read which files the
        branch changed (the merge's diff against its first parent), without asking GitHub. A squash
        merge, a merge through the GitHub UI, or an entry with no branch leaves no such line, and the
        caller reports that entry as UNKNOWN rather than guessing.

        THE NEWEST MATCH WINS: a branch merged twice in one range (a revert and a re-land) is live or
        not by its last landing. git log prints newest first, so that is the first line that matches.
    #>
    param(
        [AllowNull()][AllowEmptyCollection()][string[]]$LogLines = @(),
        [AllowNull()][string]$Branch
    )
    $b = ([string]$Branch).Trim()
    if (-not $b) { return '' }
    $rx = [regex]('^merge:\s+' + [regex]::Escape($b) + '\s+\(#\d+\)\s*$')
    foreach ($l in @($LogLines)) {
        if ($null -eq $l) { continue }
        $parts = ([string]$l) -split "`t", 2
        if ($parts.Count -lt 2) { continue }
        if ($rx.IsMatch($parts[1].Trim())) { return $parts[0].Trim() }
    }
    return ''
}

function Get-EntryLiveState {
    <#
    .SYNOPSIS
        Whether one entry is live, given the paths its merge changed and a parsed record.
        { State = 'live' | 'not-live' | 'unknown'; Storefront = bool; RecordPaths; HeldPaths }

    .DESCRIPTION
        THREE STATES, AND UNKNOWN IS NOT LIVE. $ChangedPaths is $null when the caller could not find the
        entry's merge commit, and then nothing about it can be said -- reporting it as live would be the
        v1.3.0 claim again, reached by a different road. Each caller decides what an unknown costs in its
        own document.

        NOT LIVE IS ONE HELD PATH. An entry is a change a reader checks as a whole: a fix whose template
        is live and whose snippet is held is not a fix they can see, so a single 'hold' path decides it.

        STOREFRONT IS 'TOUCHED ANY PATH THE RECORD NAMES'. The record lists every theme file of the range
        and nothing else, so an entry that touched none of them changed nothing a store visitor meets --
        the Asana board moving its own cards (consumer #271/#259) is the measured case. Such an entry is
        live in the trivial sense (nothing of it is held), and Storefront says why it is still no item
        for the audience note.
    #>
    param(
        [AllowNull()][AllowEmptyCollection()][string[]]$ChangedPaths,
        [Parameter(Mandatory)]$Record
    )
    if ($null -eq $ChangedPaths) {
        return [pscustomobject]@{ State = 'unknown'; Storefront = $false; RecordPaths = @(); HeldPaths = @() }
    }
    $liveSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($p in @($Record.Live)) { if ($p) { [void]$liveSet.Add((ConvertTo-LiveRecordKey $p)) } }
    $holdSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($p in @($Record.Hold)) { if ($p) { [void]$holdSet.Add((ConvertTo-LiveRecordKey $p)) } }

    $recordPaths = @()
    $held = @()
    foreach ($raw in @($ChangedPaths)) {
        $k = ConvertTo-LiveRecordKey $raw
        if (-not $k) { continue }
        if ($holdSet.Contains($k)) { $recordPaths += $k; $held += $k }
        elseif ($liveSet.Contains($k)) { $recordPaths += $k }
    }
    $state = if ($held.Count -gt 0) { 'not-live' } else { 'live' }
    return [pscustomobject]@{ State = $state; Storefront = ($recordPaths.Count -gt 0); RecordPaths = @($recordPaths); HeldPaths = @($held) }
}

function Get-TaskMarkerId {
    <#
    .SYNOPSIS
        The id an issue body's '<!-- <marker>: <id> -->' comment carries, '' when it has none.

    .DESCRIPTION
        THE MARKER IS THE AUTHORITATIVE LINK (#2567, and dkj-policy-bwj's WORKFLOW-portable.md, which
        calls it that): report-issue writes it at filing, and the asana-mirror workflow reads it at
        closing. A link in the issue's prose may point at a card that has since moved, so it is not
        read here. The id is held to letters, digits, '_' and '-', because it is spliced into a URL
        that a published document carries.
    #>
    param(
        [AllowNull()][AllowEmptyString()][string]$Body,
        [Parameter(Mandatory)][string]$Marker
    )
    if (-not $Body) { return '' }
    $m = [regex]::Match($Body, '<!--\s*' + [regex]::Escape($Marker) + ':\s*([0-9A-Za-z_-]+)\s*-->')
    if ($m.Success) { return $m.Groups[1].Value }
    return ''
}

function Format-ReleaseTaskItems {
    <#
    .SYNOPSIS
        The audience section's body in task form: one '### <title>' per solved task, with its link and
        nothing else. '' for no items.

    .DESCRIPTION
        THE SHAPE THE OWNER REWROTE THE v1.3.0 NOTE INTO, by hand, after it was published (#2564's
        comments): a recognisable title, one or two plain sentences, and a link to the task. No PR link,
        because "de audience is niet de developer". The sentences are the one part a person writes; the
        title and the link are what the tracker already knows.

        THE TITLE IS FOREIGN TEXT -- an issue title anybody who can open an issue wrote, and on a public
        tracker that is anybody. It is folded to one line, so it cannot open a second heading, and every
        markdown and HTML metacharacter in it is backslash-escaped, so '[click](https://evil)' renders as
        the literal text rather than as a link in a document that reads as official. The security review of
        #2586 measured the unescaped form producing a working injected link. Escaped rather than stripped,
        so the person rewriting the title still sees what the filer wrote.

        THE LINK IS NOT FOREIGN IN THE SAME WAY: its URL is the consumer's own seam answer with an id
        Get-TaskMarkerId holds to [0-9A-Za-z_-]. A marker in an issue body can be typed by whoever wrote
        the body, so a forged one can point the link at a different task in the SAME tracker -- and only
        for an issue a maintainer's merged PR closed. That is stated here rather than guarded, because the
        marker is this workflow's authoritative link everywhere else too (asana-mirror reads it the same way).
    #>
    param(
        [AllowNull()][AllowEmptyCollection()][object[]]$Items = @(),
        [Parameter(Mandatory)][string]$Label,
        [int]$EntryLevel = 3
    )
    $hashes = '#' * [Math]::Max(1, $EntryLevel)
    $blocks = @()
    foreach ($it in @($Items)) {
        if ($null -eq $it) { continue }
        $title = ((([string]$it.Title) -replace '[\r\n\t]+', ' ') -replace '\s{2,}', ' ').Trim()
        if (-not $title) { $title = 'untitled task' }
        # Every markdown/HTML metacharacter, escaped with a backslash (CommonMark's own escape set).
        $title = [regex]::Replace($title, '[\\`*_{}\[\]()<>#+!|~&]', { param($c) '\' + $c.Value })
        $blocks += "$hashes $title`n`n[$Label]($([string]$it.Url))"
    }
    return ($blocks -join "`n`n")
}
