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

function ConvertTo-BacklogHtmlText {
    <# Escape a string for placement in HTML text content. The same three characters every other
       page builder in this repo escapes, and no more -- this function never receives markup, only
       plain text off a GitHub label or an Asana task. #>
    param([string]$Value)
    return ($Value -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;')
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
            $paragraphs += "    <p>$escaped</p>"
        }
    }
    $body = if ($paragraphs.Count -gt 0) { ($paragraphs -join "`n") } else { '' }
    return (@("  <article class=`"entry`">", "    <h2>$safeTitle</h2>", $body, "  </article>") |
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
