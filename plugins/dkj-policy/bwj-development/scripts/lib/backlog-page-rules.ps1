<#
.SYNOPSIS
    The decisions behind the minor-backlog page -- which text renders (the Asana variant, not the
    GitHub issue), how entries are ordered, and the HTML they land in. Pure: no network, no
    filesystem, no repo-config, no gh, no Asana.

.DESCRIPTION
    Dot-sourced by build-backlog-page.ps1 beside it, for the same split page-publish-rules.ps1
    already makes: everything that touches gh, Asana or the filesystem cannot be exercised by a
    suite, while the parts that can be WRONG -- how an entry is ranked, what text reaches the page,
    how it is escaped -- are pure functions over already-fetched data.

    ISSUE #1979. The builder's job is to turn a set of GitHub issues carrying the reach label into
    one page a colleague who never opens a repository can read. Two decisions were settled before
    writing it (Dave, September 14, 2026, on the issue itself):

      1. WHOSE TEXT RENDERS -- the Asana task's, never the GitHub issue's. The issue is written for
         a developer; the mirrored Asana task is the colleague-facing translation report-issue's
         skeleton already produces ("What is wrong / Where / How urgent / Tracked on GitHub"). So
         this page shows a task's Name and Notes verbatim, whatever shape they carry -- the fixed
         skeleton for a ticket filed the GitHub-first way, a colleague's own words for one imported
         the other way round. Re-parsing the skeleton into three fields was considered and dropped:
         it would refuse a shape it does not recognise, on a page whose only source of the "colleague
         reads what was written for them" guarantee is showing what actually sits in Asana.
      2. NO REPO JARGON, NO LINK BACK -- so a completed or unreadable task is DROPPED rather than
         shown with a broken or a GitHub-facing substitute. A colleague reading this page has no
         GitHub login; a link they cannot follow is worse than no link, and issue-number jargon (#N,
         "closed", "PR") means nothing to the reader it is written for.

    WHAT IS MECHANISM HERE AND WHAT IS FETCHED BY THE CALLER. The driver script resolves, per open
    issue carrying the reach label, which Asana task mirrors it (Resolve-AsanaTaskRef, dot-sourced
    from ../../templates/asana-mirror.ps1 -- the same pure helper report-issue's own marker and the
    CI sweep both resolve against) and reads that task's Name/Notes/Completed
    (Get-AsanaTaskState, same file). Everything past that point -- which entries survive, what order
    they render in, what markup they become -- is this file.

    Pure ASCII (repo convention for .ps1).
#>

$script:BacklogKeptInvisibleCodePoints = @(
    0x09, 0x0A, 0x0D,   # tab, LF, CR -- Format-BacklogEntryHtml's paragraph split and <br> read these
    0x200C,             # ZERO WIDTH NON-JOINER -- word shaping in Persian and the Indic scripts
    0x200D,             # ZERO WIDTH JOINER     -- the same, plus every joined emoji sequence
    0x200E, 0x200F,     # LEFT-TO-RIGHT MARK, RIGHT-TO-LEFT MARK
    0x061C              # ARABIC LETTER MARK
)

function ConvertTo-BacklogVisibleText {
    <#
        .SYNOPSIS
            Remove the invisible characters an Asana task can carry into the page, keeping the ones
            that carry meaning in a document a browser renders.

        .DESCRIPTION
            An Asana Name and Notes are free text written by anybody with board access -- no push
            access to any repository needed. Escaping &, < and > stops markup injection and does
            nothing at all about a character that is invisible or that REORDERS what is around it:
            U+202E RIGHT-TO-LEFT OVERRIDE, an unterminated U+2066 isolate, a zero-width run, a
            plane-14 tag sequence. A browser renders those the same way a terminal does -- the
            printed text reads as something other than what it says -- and the reader this page is
            written for is a colleague with no GitHub login, holding no second copy to check it
            against.

            AN ALLOWLIST, NOT A LIST OF THE DECEPTIVE ONES. Everything in Cc and Cf goes except the
            eight code points above, so a format character assigned in a future Unicode version is
            stripped on the day it exists rather than on the day somebody remembers to add it here.
            The eight that stay are the ones this page's own content needs: the three whitespace
            controls the paragraph splitter reads, the two joiners that shape Persian and Indic words
            and every joined emoji, and the three bidi MARKS. A mark nudges the direction of the
            neutral character beside it and cannot open a scope; an OVERRIDE, an EMBEDDING and an
            ISOLATE each open one that runs until it is closed -- or to the end of the text if it
            never is, which is the whole of the Trojan-Source shape. So the marks stay and those
            three classes go.

            NOT Format-ForConsole, WHICH IS THE QUESTION #2025 LEFT OPEN. That function (dkj-policy's
            claim-issue-lib.ps1) spaces out EVERY Cc and Cf, and its own docstring accepts the cost:
            a title in Arabic or Hebrew loses the marks that order it, an emoji sequence prints as
            its parts. That is the right contract for one console line, which has no direction of its
            own and cannot be told one. An HTML document CAN be told, and is -- see the dir="auto" on
            the elements Format-BacklogEntryHtml writes -- so flattening here would destroy text this
            page is able to render correctly, in the name of a spoof the strip has already removed.

            AND IT DOES NOT TYPE THAT CLASS EITHER, because on this runtime the class is wrong twice.
            Both were measured under Windows PowerShell 5.1 (.NET Framework) while #2025 was being
            repaired, and both are silent: the regex matches, strips less than it reads as, and
            reports nothing.

              1. U+00AD SOFT HYPHEN is Cf in the runtime's Unicode table and Pd to the REGEX engine,
                 whose category tables predate Unicode 4.0, so \p{Cf} does not match it. It is the
                 ONLY such divergence in the whole BMP -- all 65,536 were compared one by one.
              2. Every format character above the BMP is invisible to \p{Cf} outright, because a .NET
                 character class matches one UTF-16 code unit and those are surrogate pairs. That is
                 the U+E0020..U+E007F TAG block -- the invisible-text channel -- plus U+E0001,
                 U+1D173..U+1D17A and U+110BD/U+110CD.

            So the category is read from [CharUnicodeInfo], which uses the current table and resolves
            a surrogate pair to the single code point it is. A code point at a time rather than one
            regex: a backlog page is a handful of entries, and a strip that silently misses the tag
            block is not cheaper than a loop, only faster at being wrong.

            A SPACE, NOT A DELETION -- the same answer Format-ForConsole gives, for the same reason:
            deleting the separator between two words joins them, so a sentence could be made to read
            as a different one by the very act of cleaning it. The cost of that choice is lower here
            than on a console, because runs of whitespace collapse when the page renders.
    #>
    param([string]$Value)
    if (-not $Value) { return '' }

    $sb = New-Object System.Text.StringBuilder
    $i  = 0
    while ($i -lt $Value.Length) {
        # GetUnicodeCategory(string, index) resolves a surrogate PAIR to its code point's own
        # category; on an UNPAIRED surrogate it answers Surrogate, which is neither Cc nor Cf, so a
        # broken pair is copied through rather than silently eaten.
        $category = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($Value, $i)
        $paired   = ([char]::IsHighSurrogate($Value[$i]) -and ($i + 1) -lt $Value.Length -and
                     [char]::IsLowSurrogate($Value[$i + 1]))
        $width    = if ($paired) { 2 } else { 1 }

        $invisible = ($category -eq [System.Globalization.UnicodeCategory]::Control -or
                      $category -eq [System.Globalization.UnicodeCategory]::Format)
        $kept = $false
        if ($invisible -and $width -eq 1) {
            $kept = $script:BacklogKeptInvisibleCodePoints -contains [int]$Value[$i]
        }

        if ($invisible -and -not $kept) { [void]$sb.Append(' ') }
        else                            { [void]$sb.Append($Value.Substring($i, $width)) }
        $i += $width
    }
    return $sb.ToString()
}

function ConvertTo-BacklogHtmlText {
    <# Escape a string for placement in HTML text content. The same three characters every other
       page builder in this repo escapes, and no more -- this function never receives markup, only
       plain text off a GitHub label or an Asana task.

       IT STRIPS BEFORE IT ESCAPES (#2025). This is the one chokepoint every piece of foreign text
       reaches -- a task's Name, each block of its Notes, the repo label in the title -- so the
       invisible-character policy sits here rather than at each of those call sites. The order is
       safe either way round, since nothing ConvertTo-BacklogVisibleText removes or emits is one of
       the three characters escaped below; strip-first is written because it is the order that keeps
       reading as correct if a fourth escape is ever added. #>
    param([string]$Value)
    $visible = ConvertTo-BacklogVisibleText -Value $Value
    return ($visible -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;')
}

function Get-IssuePrioRank {
    <#
        The priority an issue's labels declare, as a sortable integer: 'prio-4' (highest) is 4,
        'prio-1' is 1, no prio-* label at all is 0. Pure.

        THIS IS THE PRIORITY AXIS, NOT THE REACH AXIS, and the two stay disjoint on purpose --
        #1686 already settled that this repo's own reach label and its 'prio-*' rungs must never be
        read as meaning each other. This function reads the rungs ONLY to order a page that is
        already filtered by the reach label; it answers no other question.

        Two prio-* labels on one issue is a tracker inconsistency this function does not referee --
        it takes the HIGHEST, which is the fail-safe direction for a backlog page: a colleague sees
        an item too early rather than missing one that genuinely mattered.
    #>
    param([string[]]$Labels = @())
    $best = 0
    foreach ($label in @($Labels)) {
        $m = [regex]::Match([string]$label, '^prio-([1-4])$')
        if ($m.Success) {
            $n = [int]$m.Groups[1].Value
            if ($n -gt $best) { $best = $n }
        }
    }
    return $best
}

function Sort-BacklogEntries {
    <#
        Order entries for the page: highest priority first, then by issue number ascending so two
        items at the same priority render in a stable, predictable order run to run. Pure.

        Each entry is a pscustomobject carrying at least Number and PrioRank -- Get-BacklogPageHtml
        does not require sorted input, but the driver script always sorts through here rather than
        composing its own ordering, so there is exactly one place this decision is made.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Entries)
    return @($Entries | Sort-Object -Property @{ Expression = 'PrioRank'; Descending = $true }, @{ Expression = 'Number'; Descending = $false })
}

function Format-BacklogEntryHtml {
    <#
        One entry's HTML fragment: a heading and its notes, rendered as paragraphs. Pure -- Title
        and Notes are escaped here, so the caller passes raw text straight off Asana.

        NOTES BECOME PARAGRAPHS ON BLANK LINES, not on every line break -- Asana's own notes field
        is plain text a person wrote, wrapped however their editor wrapped it, and a <br> per line
        would reproduce that wrapping as if it were meaningful. A blank line is the one break a
        writer puts there on purpose.

        EMPTY NOTES RENDER NO BODY, not a placeholder sentence: a task mirrored before report-issue's
        skeleton existed, or one somebody cleared, has nothing to say, and inventing text here would
        be this script speaking for a colleague who filed nothing.

        dir="auto" ON EVERY ELEMENT THAT CARRIES ASANA TEXT (#2025), which is the other half of that
        issue's answer and the reason ConvertTo-BacklogVisibleText can afford to KEEP the bidi marks.
        It does two things at once. It resolves each field's direction from its own first strong
        character, so a task written in Hebrew or Arabic renders right-to-left inside a page whose
        <html lang="en"> says otherwise -- which is what the marks are for, and they are worth nothing
        if the element around them is forced the other way. And it isolates: a field's direction is
        settled within its own element and cannot reorder the heading or the entry beside it. The
        strip removes the characters that OPEN an unterminated scope; this bounds the damage of
        anything that resolves oddly inside one entry to that entry.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [string]$Notes = ''
    )
    $safeTitle = ConvertTo-BacklogHtmlText -Value $Title
    $paragraphs = @()
    if ($Notes) {
        $blocks = [regex]::Split($Notes.Trim(), '\r?\n\s*\r?\n')
        foreach ($block in $blocks) {
            $text = $block.Trim()
            if (-not $text) { continue }
            $escaped = (ConvertTo-BacklogHtmlText -Value $text) -replace '\r?\n', '<br>'
            $paragraphs += "    <p dir=`"auto`">$escaped</p>"
        }
    }
    $body = if ($paragraphs.Count -gt 0) { ($paragraphs -join "`n") } else { '' }
    return (@("  <article class=`"entry`">", "    <h2 dir=`"auto`">$safeTitle</h2>", $body, "  </article>") |
            Where-Object { $_ -ne '' }) -join "`n"
}

function Get-BacklogPageHtml {
    <#
        The whole page, from already-resolved entries. Pure -- no network, no filesystem.

        Each entry: Number (int, for Sort-BacklogEntries -- never rendered, it is repo jargon),
        Title (string), Notes (string, may be empty), PrioRank (int, from Get-IssuePrioRank).

        NOINDEX IN BOTH PLACES, same doctrine as dkj-policy's own release-notes page: the header and
        the meta tag, because a link nobody can guess is worth nothing once a crawler has published
        it, and a BWJ store repo's backlog is content that is not public anywhere else -- unlike
        dkj-policy's notes, which can point at a public repository if the crawl ever happens anyway.

        NO LINK OUT, ANYWHERE ON THE PAGE. See this file's own header for why: the reader has no
        GitHub login, and a page written to need no repository is the one property #1979 exists to
        keep.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Entries,
        [string]$RepoLabel = ''
    )
    $sorted = Sort-BacklogEntries -Entries $Entries
    $titleText = if ($RepoLabel) { (ConvertTo-BacklogHtmlText -Value $RepoLabel) + ' -- backlog' } else { 'Backlog' }

    $body = if ($sorted.Count -eq 0) {
        '  <p class="empty">Nothing outstanding right now.</p>'
    } else {
        ($sorted | ForEach-Object { Format-BacklogEntryHtml -Title $_.Title -Notes $_.Notes }) -join "`n"
    }

    return @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>$titleText</title>
<style>
  :root { color-scheme: light dark; }
  body {
    margin: 0; padding: 24px 16px 48px; background: Canvas; color: CanvasText;
    font: 16px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  }
  main { max-width: 640px; margin: 0 auto; }
  h1 { font-size: 1.4em; margin: 0 0 8px; }
  p.lede { opacity: .7; margin: 0 0 32px; }
  p.empty { opacity: .7; }
  article.entry {
    border-top: 1px solid color-mix(in srgb, CanvasText 15%, transparent);
    padding: 20px 0;
  }
  article.entry:first-of-type { border-top: none; }
  article.entry h2 { font-size: 1.05em; margin: 0 0 8px; }
  article.entry p { margin: 0 0 10px; }
  article.entry p:last-child { margin-bottom: 0; }
</style>
</head>
<body>
<main>
  <h1>$titleText</h1>
  <p class="lede">What is open and worth knowing about.</p>
$body
</main>
</body>
</html>
"@
}
