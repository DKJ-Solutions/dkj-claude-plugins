<#
.SYNOPSIS
    The one fence tracker of the tree: is this line inside a fenced code block? Issue #2536.

.DESCRIPTION
    #2534 gave the always-on walk a CommonMark fence tracker (Get-NextFenceState, then in
    measure-context-lib.ps1). Every other markdown reader in the tree still carried its own plain toggle,
    flipping a boolean on every delimiter line, so a four-backtick block wrapping a three-backtick example
    closed at the inner fence there, and the rest of the example was read as structure. This lib is the one definition
    they all load, and it moved here out of measure-context-lib so a reader that needs the fence state
    alone -- a PR-body lib, the roster check -- does not pull a 36 KB measuring lib in with it.

    A LEAF WITH NO DEPENDENCIES, mirrored into every plugin that carries one of its readers --
    dkj-policy, dkj-policy-bwj and dkj-subagents-alpha -- because a script may only dot-source a lib
    that ships in its own plugin.

    Pure ASCII, per this repo's script-layer convention.
#>

function Get-NextFenceState {
    <#
        The fence state AFTER one line, given the state before it: '' outside a fenced code block, or the
        run that opened the block ('```', '````', '~~~', ...) while inside one.

        Tracked because a fenced block in these documents routinely CONTAINS lines that start with '#',
        '@' or '## ' -- a skill page showing a document's shape, a README showing a heading tree, a page
        quoting an import line, a PR body quoting an entry. Read as structure those invent sections,
        imports and entry boundaries.

        CommonMark, not a toggle (#2534). An opener is three or more backticks or tildes after at most
        three leading spaces; a backtick opener's info string may not itself contain a backtick. A block
        closes ONLY on a run of the SAME character at least as long as its opener, with nothing after it
        but whitespace. A plain toggle read the inner fence of a four-backtick block wrapping a
        three-backtick example as the end of the block, and walked the rest of the example as structure.
        An unclosed block runs to the end of the document, as it does in CommonMark.

        -AnyIndent LIFTS THE THREE-SPACE LIMIT on both opener and closer (#2536). CommonMark counts that
        limit from the enclosing CONTAINER, and this function sees no containers: a fence inside a list
        item sits at the item's indent plus up to three. Measured on the #2536 branch:
        plugins/dkj-policy/skills/cut-release/SKILL.md fences a '### DEPLOY:' example at five spaces
        inside a numbered item, and without the switch that line reads as a heading. The readers #2536
        moved here always accepted any indent, so they pass it and keep that; the always-on walk does not,
        and keeps #2534's rule that a four-space line is an indented code block rather than a fence.

        AND A DEEP OPENER ENDS WHEN ITS CONTAINER DOES (#2542). Lifting the limit alone let a line such as
        four spaces and three backticks -- pasted terminal output under a paragraph, an INDENTED code
        block on GitHub that ends when the indentation drops -- open a fence that never closed, so the
        rest of the document read as quoted and a real '## Gate bypass' section below it went unread. A
        fence opened at N > 3 spaces can only sit in a container whose content starts at N-3 or deeper,
        and a non-blank line indented LESS than that has left every such container, so the block is over.
        The state carries N for that test: a deep opener's state is its indent in spaces plus its run
        (e.g. '     ```'), still non-empty, and a shallow one's is the bare run as before. The bound is
        the loosest one the line allows, not the container's real indent, which this function cannot see
        -- so a column-0 line always ends a deep block, and a line at 1-3 spaces may not.
        A line that is a valid closer for the open block closes it even when it sits below that bound.
        CommonMark would read it as the container ending and the line opening a NEW, unclosed block; that
        is the same swallow-the-rest failure this rule exists to remove, so where the two readings
        disagree the one that does not swallow the document wins.

        The caller skips a line when the state before OR after it is non-empty -- that covers the opener,
        the body and the closer in one test. The state BEFORE is read through Resolve-FenceState, so the
        line that ends a deep block by its indent is not itself counted as inside it:
            $was = Resolve-FenceState -Line $text -Fence $fence; $fence = Get-NextFenceState -Line $text -Fence $fence
            if ($was -or $fence) { continue }
        Without -AnyIndent no state is ever deep, and '$was = $fence' is the same thing.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Line,
        [AllowEmptyString()][string]$Fence = '',
        [switch]$AnyIndent
    )
    $Fence = Resolve-FenceState -Line $Line -Fence $Fence
    $pattern = if ($AnyIndent -or $Fence.StartsWith(' ')) { '^(\s*)(`{3,}|~{3,})(.*)$' } else { '^(\s{0,3})(`{3,}|~{3,})(.*)$' }
    if ($Line -notmatch $pattern) { return $Fence }
    $indent = Get-FenceIndentWidth -Text $Matches[1]
    $run    = $Matches[2]
    $rest   = $Matches[3]
    if ($Fence) {
        $open = $Fence.TrimStart(' ')
        if ($run[0] -eq $open[0] -and $run.Length -ge $open.Length -and $rest.Trim().Length -eq 0) { return '' }
        return $Fence
    }
    if ($run[0] -eq '`' -and $rest.Contains('`')) { return '' }
    if ($indent -gt 3) { return ((' ' * $indent) + $run) }
    return $run
}

function Resolve-FenceState {
    <#
        The fence state that holds AT this line, before the line's own delimiter is read: '' where the
        line ends a deep block by its indent (see Get-NextFenceState, #2542), and -Fence unchanged
        otherwise. A caller reads its 'state before' through this, so the ending line is not skipped as
        part of the block it ended. Only a deep state (one that starts with a space) can end this way.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Line,
        [AllowEmptyString()][string]$Fence = ''
    )
    if (-not $Fence.StartsWith(' ') -or -not $Line.Trim()) { return $Fence }
    $open  = $Fence.TrimStart(' ')
    $depth = $Fence.Length - $open.Length
    $lead  = [regex]::Match($Line, '^\s*').Value
    if ((Get-FenceIndentWidth -Text $lead) -ge ($depth - 3)) { return $Fence }
    # Below every container the opener could sit in -- unless the line is this block's own closer.
    $m = [regex]::Match($Line, '^\s*(`{3,}|~{3,})\s*$')
    if ($m.Success -and $m.Groups[1].Value[0] -eq $open[0] -and $m.Groups[1].Value.Length -ge $open.Length) { return $Fence }
    return ''
}

function Get-FenceIndentWidth {
    # Leading whitespace as columns, a tab advancing to the next multiple of four as CommonMark counts it.
    param([AllowEmptyString()][string]$Text)
    $w = 0
    foreach ($c in $Text.ToCharArray()) { if ($c -eq "`t") { $w += 4 - ($w % 4) } else { $w++ } }
    return $w
}
