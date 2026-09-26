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

        The caller skips a line when the state before OR after it is non-empty -- that covers the opener,
        the body and the closer in one test:
            $was = $fence; $fence = Get-NextFenceState -Line $text -Fence $fence
            if ($was -or $fence) { continue }
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Line,
        [AllowEmptyString()][string]$Fence = '',
        [switch]$AnyIndent
    )
    $pattern = if ($AnyIndent) { '^\s*(`{3,}|~{3,})(.*)$' } else { '^\s{0,3}(`{3,}|~{3,})(.*)$' }
    if ($Line -notmatch $pattern) { return $Fence }
    $run  = $Matches[1]
    $rest = $Matches[2]
    if ($Fence) {
        if ($run[0] -eq $Fence[0] -and $run.Length -ge $Fence.Length -and $rest.Trim().Length -eq 0) { return '' }
        return $Fence
    }
    if ($run[0] -eq '`' -and $rest.Contains('`')) { return '' }
    return $run
}
