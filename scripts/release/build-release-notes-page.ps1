<#
.SYNOPSIS
    Builds a browsable page from the hand-written release notes, and optionally the Cloudflare
    Worker that serves it.

.DESCRIPTION
    THE PROBLEM THIS SOLVES. The hand-written note per release is the one release document written
    for somebody outside the development work, and it lives as markdown inside the repository --
    which is the right home for it and the wrong place to read it. A reader who is not a developer
    has to find a directory, pick a version, and read raw markdown in a code host. This builds those
    same documents into one page with a picker per release, and puts that page somewhere they can
    open.

    GENERATED, NOT EDITED, and that is the design decision to know before changing anything here.
    The consumer this was ported from (smartwatchbanden) keeps TWO pages: a generated archive of
    every written document, and a hand-edited management edition with its own headline per release.
    The hand-edited one earns its keep there because its notes are per-PR records that need
    summarising. Here the note is already a written document for that reader, so summarising it a
    second time would be a second thing to keep true. If a repo ever needs the edited form, that is
    a different page and not a mode of this script.

    WHERE THE HISTORY COMES FROM. The release list in Get-ReleaseHistoryPath, not the filenames
    under the note root. Only the table knows the ORDER, the date, the type, the title, and which
    release is live -- a directory listing knows none of that and sorts 4.10.0 before 4.9.0.

    THE LIVE MARKER IS MATCHED CASE-SENSITIVELY (-cmatch), and that is a bug this script was born
    without because the consumer it came from had already paid for it: PowerShell compares
    case-insensitively by default, so every release whose TITLE contains the word "live" marked
    itself as the live one. Two of their forty did, and their page pointed at three live versions.

    TWO MEASUREMENTS THAT MOVED THE DESIGN AWAY FROM THAT CONSUMER'S SCRIPT, taken here on
    August 15, 2026 against this repo's 21 notes (187,039 characters):

      - ConvertTo-Json returns in 47 ms on Windows PowerShell 5.1, on exactly the nested shape this
        script builds. Their script hand-writes a JSON serializer because theirs "does not return
        within five minutes" on 52 documents. Whatever their pathology was, it is not size at this
        order of magnitude, so a hand-written serializer here would be a hundred lines carrying a
        risk (a JSON bug in a page nobody validates) to buy nothing.
      - ConvertTo-Json ESCAPES the angle brackets into their JSON unicode form. So a note
        containing a closing script tag cannot end the data block early -- which is the failure
        their hand-written escaper exists to prevent. Asserted below rather than trusted, because
        it is the serializer's behaviour and not a documented guarantee, and the failure is silent:
        the page renders empty.

    WHAT IT WRITES. The page always. With -Worker, also worker.js and (only when absent) a
    wrangler.toml beside it, in a 'page' directory next to the note root. None of the output belongs
    in version control -- it is a derivative of documents that are already tracked.

    AND AN ABSENT wrangler.toml IS REPORTED RATHER THAN WRITTEN IN SILENCE. It shares the gitignored
    page directory with the path token and is lost by the same mechanisms, so "it is not here" is as
    likely to mean the directory was rebuilt from nothing as it is to mean a first run -- and the
    fresh one carries none of what a consumer had edited into the old one (an account id, a custom
    domain, a route). Reported, not refused: a first-ever deploy looks identical from here. Measured
    on issue #1479, which found the write reporting itself in green during the very run that had
    just restored a token belonging to an existing deployment.

    THE PATH TOKEN IS AN INPUT, NEVER INVENTED. The worker serves the page at /notes/<token> and
    that path is the only lock on it: no login, anyone with the link can read. So a token this
    script made up on the fly would not mean "a new path", it would mean "every link already sent
    now 404s" -- while the build and the deploy both report success. Missing token is therefore an
    error with a recovery instruction, and -InitToken is the separate, explicit way to create the
    first one.

    AND A LOST TOKEN IS NOT THE SAME AS A LOST URL, which is the half both refusals below used to
    leave out. This script writes the route into the bundle as a LITERAL -- const ROUTE =
    "/notes/<token>" -- so a worker that is still deployed is itself a copy of the token, held by
    Cloudflare rather than by any machine here. That is the recovery route to try before concluding
    the URL is gone: read it off the deployment (the worker's code view in the Cloudflare dashboard,
    or the Workers script API, both of which return the deployed source). Measured on issue #1453,
    where the local token was genuinely absent everywhere and the conclusion drawn from that was
    "every link already sent is unrecoverable" -- which does not follow while the worker is up.

    IT DEPLOYS NOTHING. `npx wrangler deploy` is the deploy, run by hand, because publishing is
    outward-facing. Verify a redeploy against the BYTES the URL serves, never against the deploy
    command's own output: the consumer this came from measured that once wrangler has created a
    deployment on a worker, the Cloudflare API upload path only creates INACTIVE versions -- with
    no error, while the live page stays the old one.

.PARAMETER OutFile
    Where the page lands. Defaults to release-notes.html in the page directory beside the note root.
    The output is a derivative and is deliberately not tracked.

.PARAMETER Worker
    Also write worker.js (and wrangler.toml, if it is not there yet) for `npx wrangler deploy`.
    Requires Get-ReleasePageWorkerName in the repo's own scripts/repo-config.ps1 and a path token.

.PARAMETER InitToken
    Create the path token when there is none. Deliberately explicit: see the token note above.
    Refuses to overwrite an existing token, because that is the destructive half.

.PARAMETER RootOverride
    Test seam -- the repo root to read instead of this one. A consumer never types it.

.EXAMPLE
    ./scripts/release/build-release-notes-page.ps1
    Builds the page and reports where it is.

.EXAMPLE
    ./scripts/release/build-release-notes-page.ps1 -Worker
    Builds the page and the worker bundle, then names the deploy command.

    Pure ASCII (repo convention for .ps1).
#>
param(
    [string]$OutFile,
    [switch]$Worker,
    [switch]$InitToken,
    [string]$RootOverride
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# Test-FunctionDefined (issue #1729): the seam probes below read the function table directly rather
# than through Get-Command, which parses the name as a wildcard pattern and pays a full PATH scan on
# every miss -- and a miss is the normal case for an optional seam. $PSScriptRoot-relative, so it
# resolves in the plugin mirror as well as here.
. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')

# JUDGED (#1917): Resolve-RepoRootOrFail is check-report-lib's refusing sibling of Resolve-CheckRoot
# -- same three-source precedence, but it names git's exit code and stderr instead of dying on
# $null.Trim() where git answers nothing.
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$repoRoot = Resolve-RepoRootOrFail -Override $RootOverride -ScriptName 'build-release-notes-page.ps1' -OverrideName '-RootOverride'

$templatePath = Join-Path $PSScriptRoot 'release-notes-page-template.html'
if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
    throw "The page template is missing: $templatePath"
}

# --- 1. The repo's own answers --------------------------------------------------------------------
# Dot-sourced and probed in a CHILD scope with StrictMode explicitly OFF: this script runs under
# Set-StrictMode -Version Latest, while repo-config.ps1 is written on the assumption that its runtime
# callers do not. Every value has a fallback, so a repo without the file still gets a page.
$config = & {
    Set-StrictMode -Off
    $answers = @{
        NoteRoot    = 'releases/notes'
        Grouping    = 'major'
        HistoryPath = 'releases/README.md'
        Title       = ''
        WorkerName  = ''
        Theme       = $null
        Masthead    = $null
    }
    $configPath = Join-Path $args[0] 'scripts\repo-config.ps1'
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { return $answers }
    try { . $configPath } catch {
        Write-Warning "scripts\repo-config.ps1 could not be loaded ($($_.Exception.Message)) -- using the built-in defaults."
        return $answers
    }
    if (Test-FunctionDefined 'Get-ReleaseNoteRoot') { $answers.NoteRoot    = Get-ReleaseNoteRoot }
    if (Test-FunctionDefined 'Get-ReleaseNotesGrouping') { $answers.Grouping    = Get-ReleaseNotesGrouping }
    if (Test-FunctionDefined 'Get-ReleaseHistoryPath') { $answers.HistoryPath = Get-ReleaseHistoryPath }
    if (Test-FunctionDefined 'Get-ReleasePageTitle') { $answers.Title       = Get-ReleasePageTitle }
    if (Test-FunctionDefined 'Get-ReleasePageWorkerName') { $answers.WorkerName  = Get-ReleasePageWorkerName }
    if (Test-FunctionDefined 'Get-ReleasePageTheme') { $answers.Theme       = Get-ReleasePageTheme }
    if (Test-FunctionDefined 'Get-ReleasePageMasthead') { $answers.Masthead    = Get-ReleasePageMasthead }
    # The page title falls back to the repo's own name rather than to a generic label, so a page
    # built in a repo that never answered still says whose releases it carries.
    if (-not $answers.Title -and (Test-FunctionDefined 'Get-RepoName')) {
        $answers.Title = ((Get-RepoName) -split '/')[-1]
    }
    return $answers
} $repoRoot

if (-not $config.Title) { $config.Title = 'Release notes' }

$noteRoot    = Join-Path $repoRoot ($config.NoteRoot -replace '/', '\')
$historyPath = Join-Path $repoRoot ($config.HistoryPath -replace '/', '\')

if (-not (Test-Path -LiteralPath $historyPath -PathType Leaf)) {
    throw ("The release history is missing: $($config.HistoryPath). That file is the ORDERED list of " +
           "releases -- this page cannot be built from the note filenames alone. Get-ReleaseHistoryPath " +
           "in scripts\repo-config.ps1 names it.")
}
if (-not (Test-Path -LiteralPath $noteRoot -PathType Container)) {
    throw ("The note root is missing: $($config.NoteRoot). Get-ReleaseNoteRoot in scripts\repo-config.ps1 " +
           "names it; a repo whose hand-written notes live elsewhere answers it there.")
}

# --- The pure rules this page is built from -------------------------------------------------------
# Defined ahead of the reading loop because PowerShell runs top to bottom: Remove-NoteMetadataHeader is
# called while the notes are read, which is before section 3. The rest are called after it and would
# have worked anywhere; they stay together because they are one set.
function Format-ReleaseMastheadMarks {
    <#
        Pure: the repo's own wordmark(s) above the page title, or '' where the seam is unanswered.

        FILED AS A PROPOSAL AND BUILT AS ONE (inbound #809). A consumer had a hand-edited management
        edition carrying two market wordmarks; the generated page took over its worker and its URL, and
        the imagery was the one thing that did not come across. Restyling the template in that consumer
        would fork the core's visual identity and leave every other consumer without it -- which is the
        fork they had just finished ending -- so the seam is the only correct home for it.

        DATA-URIs ONLY, AND THAT FOLLOWS FROM THE PAGE RATHER THAN FROM CAUTION. The template is
        deliberately self-contained because a request to a third party would leak who is reading the
        page, so a URL here would quietly break the one property the whole file is built around. A value
        that is not an inline image is therefore dropped with a named warning.

        BASE64 ONLY, WHICH IS NARROWER THAN 'data:' ALLOWS. A raw 'data:image/svg+xml,<svg ...>' is
        markup inside an attribute; escaping it would work, and not having to reason about whether the
        escaping is complete works better. Nothing is lost: base64 is what any tool that produces one of
        these writes.

        THREE LIMITS, EACH WITH ITS REASON, because 'a documented ceiling rather than trust' is what the
        report asked for:

          * TWO MARKS. That consumer's own editorial round tried five and cut back to two, because five
            read as a page about the brands rather than about the releases. The cap is the finding, not
            a technical bound -- so extras are dropped with a warning that says which.
          * 32 KB PER MARK and 64 KB IN TOTAL, measured as the length of the data URI, which is the cost
            the reader actually pays. Two wordmarks as base64 SVG sit far inside that; a photograph does
            not, and a photograph is not a wordmark.
          * A BAD VALUE COSTS THE IMAGE AND A WARNING, NEVER THE BUILD. The page is a reading copy of
            documents that are already correct; refusing to build it over a logo would be the wrong
            trade, and a warning is what the operator sees at the one moment they can fix it.

        ALT DEFAULTS TO EMPTY, deliberately. A wordmark beside a page title that already names the repo
        is decorative, and an empty alt is how that is stated to a screen reader -- inventing text would
        make it read the same fact twice. A consumer with something to say passes Alt.

        Returns a hashtable: Html (the marks block, or '') and Warnings (strings, possibly empty).
    #>
    param([AllowNull()][object]$Marks)

    $maxCount     = 2
    $maxPerMark   = 32KB
    $maxTotal     = 64KB
    $warnings     = New-Object System.Collections.Generic.List[string]
    $imgs         = New-Object System.Collections.Generic.List[string]
    $total        = 0

    if ($null -eq $Marks) { return @{ Html = ''; Warnings = @() } }

    # One mark or several, a string or an object with Alt: normalised here so the loop below has one
    # shape to read. A bare string is the common case and must not need a wrapper.
    $list = @()
    foreach ($m in @($Marks)) {
        if ($null -eq $m) { continue }
        if ($m -is [string]) { $list += ,@{ Src = $m; Alt = '' }; continue }
        $src = ''
        $alt = ''
        try { if ($m.Src)  { $src = [string]$m.Src } }  catch { }
        try { if ($m.src)  { $src = [string]$m.src } }  catch { }
        try { if ($m.Alt)  { $alt = [string]$m.Alt } }  catch { }
        try { if ($m.alt)  { $alt = [string]$m.alt } }  catch { }
        if (-not $src) {
            $warnings.Add('Get-ReleasePageMasthead returned an entry with no Src -- skipped.')
            continue
        }
        $list += ,@{ Src = $src; Alt = $alt }
    }

    foreach ($m in $list) {
        if ($imgs.Count -ge $maxCount) {
            $warnings.Add("Get-ReleasePageMasthead returned more than $maxCount mark(s); the rest are skipped. " +
                          'Two is the documented cap: more reads as a page about the brands rather than about the releases.')
            break
        }
        $src = ([string]$m.Src).Trim()
        if ($src -notmatch '^data:image/(png|jpe?g|gif|webp|svg\+xml);base64,[A-Za-z0-9+/=]+$') {
            $warnings.Add('Get-ReleasePageMasthead: not an inline base64 image, so it is skipped -- this page is ' +
                          'self-contained and must not fetch anything. Expected "data:image/<type>;base64,<payload>".')
            continue
        }
        if ($src.Length -gt $maxPerMark) {
            $warnings.Add("Get-ReleasePageMasthead: a mark is $([math]::Round($src.Length / 1KB)) KB, over the " +
                          "$($maxPerMark / 1KB) KB ceiling per mark -- skipped.")
            continue
        }
        if (($total + $src.Length) -gt $maxTotal) {
            $warnings.Add("Get-ReleasePageMasthead: the marks together would pass the $($maxTotal / 1KB) KB " +
                          'ceiling -- the rest are skipped.')
            break
        }
        $total += $src.Length
        $imgs.Add('      <img src="' + (ConvertTo-HtmlText $src) + '" alt="' + (ConvertTo-HtmlText ([string]$m.Alt)) + '">')
    }

    if ($imgs.Count -eq 0) { return @{ Html = ''; Warnings = @($warnings) } }
    $html = (@('    <div class="marks">') + $imgs + @('    </div>')) -join "`n"
    return @{ Html = $html; Warnings = @($warnings) }
}

function Get-ReleaseDominantType {
    <#
        Pure: the bump type that is ORDINARY on this page -- the most common one, or '' where the table
        names no type at all. Every row carrying it renders no type chip; every row that differs does.

        MEASURED IN A CONSUMER, WHICH IS WHY THIS IS DERIVED AND NOT A SEAM (inbound #811, ask 1). On a
        page of 40 releases the type chip read 'Minor' 38 times, 'Baseline' once, and was ABSENT on the
        one row a reader looks at first -- because 'live' and the type are mutually exclusive in one
        cell, so the newest release never showed its type at all. A field that is either constant or
        missing is not a field.

        AND 'IS THERE MORE THAN ONE VALUE' IS THE WRONG TEST, which is written down here because it was
        built first and shipped nothing. That page has TWO distinct types, so a variance test answers
        'varies' and leaves all 39 chips exactly where they were -- satisfying the report's wording while
        fixing nothing it measured. The report's own figure was 38 of 40, not 'two values'. Caught by Dave
        reading the built page and asking why the label was still there.

        SO THE CHIP MARKS WHAT IS UNUSUAL, which is the rule the 'live' chip already follows: its absence
        says 'not live', and the absence of a type chip now says 'the usual kind for this page'. One row
        in forty carrying 'Baseline' keeps its chip and tells a reader something; thirty-nine rows
        agreeing with each other do not. A page whose types are genuinely mixed still labels everything
        off the mode, so nothing is hidden from the consumer who gets information from this field.

        A repo whose every release is the same type therefore renders no type chip at all -- correct,
        and the version number already says whether a release was major or patch.

        TIES ARE BROKEN BY NAME so the page is reproducible: two types at equal counts is a genuinely
        mixed page, where labelling one half and not the other still reads as 'these are the unusual
        ones'. Reading the data rather than a seam needs no configuration, is right for a consumer that
        changes its bump policy later, and cannot go stale.
    #>
    param([Parameter(Mandatory)][AllowEmptyCollection()][array]$Releases)
    $types = @($Releases | ForEach-Object { ([string]$_.type).Trim() } | Where-Object { $_ })
    if ($types.Count -eq 0) { return '' }
    $ranked = @($types | Group-Object | Sort-Object -Property @{ Expression = 'Count'; Descending = $true }, @{ Expression = 'Name'; Descending = $false })
    return [string]$ranked[0].Name
}

function Get-ReleaseLiveFallbackVersion {
    <#
        Pure: the version that should carry the LIVE label when the history table marks none, or '' when
        it marks one.

        THE MARKER STAYS AUTHORITATIVE, and this is only what happens in its absence (Dave, August 21,
        2026). A row carrying '**LIVE**' is a deliberate statement, and it has to keep winning: in a
        Shopify repo the live theme is genuinely not always the newest release, which is the whole reason
        that marker exists rather than being derived.

        WHERE NOTHING IS MARKED, THE NEWEST RELEASE IS IT. The table is newest-first -- this script already
        depends on that for the whole index -- so it is the first row. Derived rather than marked because a
        marker has to be MOVED at every cut, by hand, in a file the cut itself writes into: the label would
        be right on the day it was set and wrong at the next release, silently, on a page management reads.
        Deriving it costs no maintenance and cannot go stale.

        THE COST, STATED: a repo whose live version is genuinely older and which has simply never marked it
        now gets a label that is wrong, where before it got none. That is the trade this fallback makes, and
        the override is the thing it defers to -- mark the row and the derivation stops.
    #>
    param([Parameter(Mandatory)][AllowEmptyCollection()][array]$Releases)
    if ($Releases.Count -eq 0) { return '' }
    if (@($Releases | Where-Object { $_.live }).Count -gt 0) { return '' }
    return [string]$Releases[0].version
}

function Test-ReleaseVersionTrimmable {
    <#
        Pure: does EVERY release on this page end in '.0', so the third digit says nothing?

        WHY IT IS ALWAYS ZERO IN PRACTICE (inbound #813). A release can be cut as a patch, but in a repo
        whose Get-ReleaseConsumerBumps names minor and major without naming patch, a patch gets no
        hand-written note -- cut-release drafts one only for the bumps that seam names -- and this page
        renders the NOTE root. So a patch is structurally absent from the page, and every version it can
        display therefore ends in '.0'. Measured on one consumer's built page: 40 rows, third digit '0'
        forty times; that consumer had answered the seam that way.

        AND THAT IS THE CONSUMER'S ANSWER, NOT A SHIPPED DEFAULT, which this docstring claimed until
        inbound #1070. cut-release's fallback for an unanswered seam is @() -- the tier switched off --
        so a repo that never answered it drafts a note for no bump at all, and a row here exists only
        where a note file does: that page has no rows rather than rows that happen to end in '.0'. Either
        way the conclusion holds, which is why nothing below changed -- the wrong premise sat in the
        paragraph explaining why the observation holds in practice, and the measurement it cites still
        stands.

        DERIVED FROM THE DATA RATHER THAN FROM THE SEAM, and that is the deciding property.
        Get-ReleaseConsumerBumps is consumer-overridable, so a repo that names 'patch' genuinely needs
        three digits -- and hardcoding two would break exactly the consumer who configured themselves
        differently. One pass over a list this script has already built is correct for a mixed consumer
        without reading any configuration at all.

        THE ID IS NOT TRIMMED. Only the visible label is: the id is the deep-link target in links people
        already hold, and quietly changing it would 404 every one of them while the build and the deploy
        both still reported success.
    #>
    param([Parameter(Mandatory)][AllowEmptyCollection()][array]$Releases)
    $versions = @($Releases | ForEach-Object { ([string]$_.version).Trim() } | Where-Object { $_ })
    if ($versions.Count -eq 0) { return $false }
    return -not (@($versions | Where-Object { $_ -notmatch '^\d+\.\d+\.0$' }).Count -gt 0)
}

function Format-ReleaseVersionLabel {
    <#
        Pure: the version as a reader sees it -- 'Version 2.39.0', or 'Version 2.39' where the page's third
        digit is a constant. See Test-ReleaseVersionTrimmable for why, and for why the id keeps the full
        number.

        'Version 2.39' RATHER THAN 'v2.39' (Dave, August 21, 2026, reading the built page). The short form
        is developer shorthand, and this page's reader is management and the commissioner -- for whom a
        lone 'v' is a convention they have no reason to know. It costs width in the one column that had
        just been narrowed, which is why the column it sits in is a stated number in the template rather
        than something the label can outgrow silently.

        THE ID IS UNAFFECTED and stays 'v2.39.0': it is the target of links people already hold, and it is
        a fragment rather than something a reader is asked to read.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Version,
        [bool]$Trim = $false
    )
    $v = $Version.Trim()
    if ($Trim -and $v -match '^(\d+\.\d+)\.0$') { return 'Version ' + $Matches[1] }
    return 'Version ' + $v
}

function Remove-NoteMetadataHeader {
    <#
        Pure: the note body with the opening block the ROW above it already states removed.

        WHAT IT REMOVES AND WHY (inbound #816). Every hand-written note opens with a heading and three
        bold labels:

            # Release notes v2.39.0 <rocket>

            **Date:** 2026-08-07
            **Type:** Minor
            **For whom:** employers and management -- what the organisation gets out of this release

        On this page the summary directly above already carries the version, the date and the type, so
        opening a note repeats all three -- the date in a second format, one visual unit apart from the
        first. Measured across one consumer's 40 notes: 'For whom' had exactly TWO distinct strings, and
        the only difference between them was '--' versus an em dash. One sentence, forty times, whose
        sole variation is dash style, telling the reader who they are.

        AND THE HEADING WAS THE HEAVIEST TYPE ON THE PAGE'S LEAST USEFUL LINE. It renders as 'article h1'
        while a note's real headings are 'h2', so the visual weight of an opened note landed on the line
        that adds least, forty times over, with a rocket on a page that goes to a commissioner.

        WHY THIS IS A RENDERING FIX AND NOT A CHANGE TO THE DOCUMENT. The note is read in two places and
        the block is only redundant in one of them: as markdown in the repository there is no row above
        it, and Date and Type earn their place. Suppressing it here keeps the note correct in both. It is
        also the only version of this fix that reaches the notes ALREADY published -- which are records,
        and are not rewritten.

        CONSERVATIVE BY CONSTRUCTION: it strips nothing at all unless the body opens with an H1 that
        names this release's own version. A note that opens some other way is left exactly as it is,
        because the alternative -- matching bold labels anywhere near the top -- would eventually eat a
        line somebody wrote on purpose. The labels themselves are matched by SHAPE ('**Anything:**') and
        not by name, so a repo whose wording seam translates them is covered too.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Body,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Version,
        [AllowEmptyString()][string]$Title = ''
    )

    if (-not $Body) { return $Body }
    $lines = $Body -replace "`r`n", "`n" -split "`n"
    $i = 0
    while ($i -lt $lines.Count -and -not $lines[$i].Trim()) { $i++ }
    if ($i -ge $lines.Count) { return $Body }

    # The gate: an H1 naming this version. Anything else and the body is returned untouched.
    if ($lines[$i] -notmatch '^#\s' -or $lines[$i] -notmatch [regex]::Escape($Version)) { return $Body }
    $i++

    while ($i -lt $lines.Count -and -not $lines[$i].Trim()) { $i++ }
    while ($i -lt $lines.Count -and $lines[$i] -match '^\*\*[^*]+:\*\*') { $i++ }
    while ($i -lt $lines.Count -and -not $lines[$i].Trim()) { $i++ }

    # THE TITLE LINE STAYS, and this parameter is the record of a decision that went both ways in one
    # afternoon. With the metadata block gone the note opened by repeating the sentence in the row above
    # it, so the line was suppressed here; the answer Dave settled on instead was to take the TITLE out of
    # the summary and leave it in the note, which removes the same duplication from the other side and
    # keeps the sentence where somebody reads it. -Title is still taken, because it is what a future
    # caller would need to suppress it again and because the row now carries the title only as an
    # accessible name -- so the two are no longer the same claim on the page.

    if ($i -ge $lines.Count) { return '' }
    return (($lines[$i..($lines.Count - 1)]) -join "`n")
}

# --- 2. The history table is the source of the order ----------------------------------------------
# Row shape: | [4.11.0](audience/4.x/4.11.0.md) | 2026-08-15 | Minor | Title |
# The link target is deliberately NOT read: where the document lives is the note root's and the
# grouping's answer, so reading it here would be a second statement of the same fact.
$rowPattern = '^\|\s*\[(?<version>\d+\.\d+\.\d+)\][^|]*\|\s*(?<date>[^|]+?)\s*\|\s*(?<type>[^|]+?)\s*\|\s*(?<title>.+?)\s*\|\s*$'

$releases = New-Object System.Collections.Generic.List[object]
# TWO KINDS OF ABSENCE, AND ONLY ONE OF THEM IS WORTH A READER'S ATTENTION. The table is newest-first,
# so a release with no note that sits ABOVE the oldest release that HAS one is a gap inside the covered
# range -- possibly a note nobody wrote. Everything below that point is simply older than the day this
# repo started writing them. Measured here on the day this was built: naming all of them printed
# seventy versions, which reads as a defect list and is history.
$gaps    = New-Object System.Collections.Generic.List[string]
$pending = New-Object System.Collections.Generic.List[string]

foreach ($line in [System.IO.File]::ReadAllLines($historyPath, [System.Text.Encoding]::UTF8)) {
    $m = [regex]::Match($line, $rowPattern)
    if (-not $m.Success) { continue }

    $version = $m.Groups['version'].Value
    $parts   = $version.Split('.')
    $folder  = if ($config.Grouping -eq 'minor') { "$($parts[0]).$($parts[1])" } else { "$($parts[0]).x" }
    $notePath = Join-Path $noteRoot (Join-Path $folder "$version.md")

    if (-not (Test-Path -LiteralPath $notePath -PathType Leaf)) {
        # Not an error: the hand-written note is written for some bumps only
        # (Get-ReleaseConsumerBumps), so a release without one is the ordinary case. Held back until
        # we know whether a note ever follows it further down the table.
        $pending.Add($version)
        continue
    }

    # A note was found, so everything held back above it sits inside the covered range.
    foreach ($p in $pending) { $gaps.Add($p) }
    $pending.Clear()

    # THE ROW ABOVE THE NOTE ALREADY SAYS THE VERSION, THE DATE AND THE TYPE, so the note's own opening
    # block is dropped HERE rather than in the browser -- server-side, testable in PowerShell, and it
    # leaves the document in the repository untouched. See Remove-NoteMetadataHeader.
    $body = Remove-NoteMetadataHeader -Body ([System.IO.File]::ReadAllText($notePath, [System.Text.Encoding]::UTF8)) `
        -Version $version -Title $m.Groups['title'].Value

    $releases.Add([ordered]@{
        version = $version
        date    = $m.Groups['date'].Value
        type    = $m.Groups['type'].Value
        title   = $m.Groups['title'].Value
        # -cmatch, not -match: see the header. A case-insensitive test marks every release whose
        # title merely contains the word as the live one.
        live    = $line -cmatch '\*\*LIVE\*\*'
        body    = $body
    })
}

$olderThanTheFirstNote = $pending.Count

if ($releases.Count -eq 0) {
    throw ("No release in $($config.HistoryPath) has a note under $($config.NoteRoot). Either the table " +
           "shape changed, or the grouping seam disagrees with the tree: Get-ReleaseNotesGrouping says " +
           "'$($config.Grouping)', so this looked for <root>\<$(if ($config.Grouping -eq 'minor') {'X.Y'} else {'X.x'})>\<version>.md.")
}

# --- 3. Into the template -------------------------------------------------------------------------
$json = ([ordered]@{ documentCount = $releases.Count; releases = $releases } | ConvertTo-Json -Depth 6 -Compress)

# ASSERTED, NOT TRUSTED. The data block is a <script> element, so an unescaped closing script tag
# inside any note would end it early and the page would render empty -- with nothing failing here.
# Windows PowerShell 5.1 escapes the angle brackets, and this is the assert that says so out loud
# for whoever changes the serializer.
if ($json -match '<') {
    throw ('The serialized release data contains a raw "<". That would let a note close the page' +
           ' data block early. Escape it before writing the page.')
}

$subtitle = "$($releases.Count) release$(if ($releases.Count -ne 1) {'s'}), newest first."
$stamp    = (Get-Date).ToString('yyyy-MM-dd')

$template = [System.IO.File]::ReadAllText($templatePath, [System.Text.Encoding]::UTF8)
foreach ($needle in @('@@PAGE_TITLE@@', '@@PAGE_SUBTITLE@@', '@@PAGE_MASTHEAD@@', '@@BUILD_STAMP@@', '@@RELEASE_DATA@@', '@@PAGE_STYLE@@', '@@RELEASE_ROWS@@')) {
    if ($template -notmatch [regex]::Escape($needle)) { throw "The template no longer carries $needle." }
}

# The three text placeholders are HTML-escaped; the data placeholder is JSON and is escaped already.
function ConvertTo-HtmlText {
    param([string]$Value)
    return ($Value -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;')
}

function Format-ReleasePageStyle {
    <#
        Pure: the repo's palette as one ':root' block, or '' when the repo answered nothing.

        A SEAM VALUE THAT REACHES A <style> ELEMENT IS NOT LIKE THE OTHER THREE. The text placeholders
        above are HTML-escaped, which is the whole defence they need. Escaping is exactly wrong here --
        an escaped '#' is not a colour -- so this validates instead, and it validates because the target
        is a raw markup context: a value carrying a closing style tag ends the element, and everything
        after it is markup rather than CSS. That is a script-injection vector, not a broken page. A
        stray '}' is the milder version and breaks out of the rule into the stylesheet.

        WHAT PASSES, deliberately narrow rather than a blocklist. A NAME is a custom property
        ('--accent') or the literal 'color-scheme', which is the one standard property a palette has to
        be able to set: a brand with no dark variant pins 'light' and keeps its colours on any
        background, and without that the seam could say "these colours" but not "no dark mode" (inbound
        #759 named exactly that case). A VALUE is hex, a colour function, a keyword or a short list of
        them -- letters, digits, '#', parentheses, commas, dots, percent, spaces, hyphens. Nothing else:
        no braces, semicolons, colons, angle brackets, quotes, backslashes, comment markers or 'url('.
        A repo needing a gradient or a font file is asking for the design pass, not for a wider regex.

        A REJECTION IS A WARNING AND A DROP, never a failure. This page is a report about releases; a
        malformed colour must not stop it being generated, and the shipped default for that key is a
        working answer. The warning NAMES the key, because a silently ignored setting is the failure
        this repo keeps paying for -- a consumer edits a value, sees no change and no error, and
        concludes the seam does not work.
    #>
    param($Theme)
    if ($null -eq $Theme) { return '' }
    # A hashtable, an ordered dictionary or a PSCustomObject: whichever shape the repo's function
    # returned. Probed rather than required, so the seam's own docstring can stay about colours.
    $pairs = @()
    if ($Theme -is [System.Collections.IDictionary]) {
        foreach ($k in $Theme.Keys) { $pairs += ,@("$k", "$($Theme[$k])") }
    } elseif ($Theme -is [psobject] -and @($Theme.PSObject.Properties).Count -gt 0) {
        foreach ($p in $Theme.PSObject.Properties) { $pairs += ,@("$($p.Name)", "$($p.Value)") }
    } else {
        Write-Warning "Get-ReleasePageTheme returned a $($Theme.GetType().Name), which carries no property/value pairs -- the shipped palette is used."
        return ''
    }

    $nameRx  = '^(?:--[A-Za-z0-9][A-Za-z0-9-]*|color-scheme)$'
    $valueRx = '^[A-Za-z0-9#(),.%\s-]+$'
    $lines = @()
    foreach ($pair in $pairs) {
        $name  = ([string]$pair[0]).Trim()
        $value = ([string]$pair[1]).Trim()
        if ($name -notmatch $nameRx) {
            Write-Warning "Get-ReleasePageTheme: '$name' is not a custom property or 'color-scheme' -- dropped."
            continue
        }
        if (-not $value -or $value -notmatch $valueRx) {
            Write-Warning "Get-ReleasePageTheme: the value for '$name' is empty or carries a character a stylesheet must not take from a config file -- dropped."
            continue
        }
        $lines += ('    ' + $name + ': ' + $value + ';')
    }
    if ($lines.Count -eq 0) { return '' }
    return (@("  /* This repo's own palette -- Get-ReleasePageTheme. */", '  :root {') + $lines + @('  }')) -join "`n"
}

function Format-ReleaseDate {
    <#
        Pure: the date a reader sees -- '14 Aug 2026' from the table's '2026-08-14'.

        REFORMATTED RATHER THAN PASSED THROUGH, because this page's audience is often not the team: an
        ISO date is a sorting key and reads as one. Parsed EXACTLY and with the invariant culture, so
        the output cannot change with the machine that built the page -- and anything that does not
        parse is passed through untouched rather than guessed at, since a repo may write its history
        table in a form this script has never seen.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Raw)
    $value = $Raw.Trim()
    if (-not $value) { return '' }
    $parsed = [datetime]::MinValue
    $ok = [datetime]::TryParseExact($value, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::None, [ref]$parsed)
    if (-not $ok) { return $value }
    return $parsed.ToString('d MMM yyyy', [System.Globalization.CultureInfo]::InvariantCulture)
}

function Format-ReleaseIndexRows {
    <#
        Pure: the index itself -- one collapsed 'details' element per release, as one string.

        BUILT HERE RATHER THAN IN THE BROWSER, and that is the design decision this function carries
        (inbound #759). Version, date, type and title all come from the history table, so the whole
        index can be static HTML -- which means it reads with JavaScript off or broken, where this page
        previously rendered nothing at all. Only the note BODIES still need the renderer in the
        template, and the noscript block on the page says so rather than leaving a reader to work it
        out from an empty panel.

        ONE CHIP PER ROW AT MOST: 'LIVE' where the history table marks it -- or, where it marks nothing,
        on the newest release -- and the bump type otherwise, never both. Forty rows carrying two chips each read as a table of metadata rather than as a
        list of changes, and the version number already says whether a release was major or patch.

        AND THE TYPE CHIP ONLY WHERE IT SAYS SOMETHING (inbound #811). -DominantType is the caller's
        answer from Get-ReleaseDominantType: a row whose type IS the page's ordinary one renders no chip,
        a row that differs does. Read that function for why 'more than one value' was measured and
        rejected as the test. The 'live' chip is never suppressed.

        THE TITLE IS NOT IN THE SUMMARY (Dave, August 21, 2026, reading the built page). The row is the
        version, the date, a chip where it says something, and the chevron; the release title lives in the
        note, which is where he asked for it. That also retired the two-span chip trick this function
        carried for one afternoon -- with no title cell to nest in, the chip is one span sitting in the
        flexible column, so no row pays for a track another row uses and no copy is hidden by CSS.

        THE ID IS THE DEEP-LINK TARGET and is written 'v4.11.0' verbatim rather than slugified,
        because it is what the fragment in a link people already hold has to match. The visible LABEL may
        be shorter -- see Format-ReleaseVersionLabel -- and the two are deliberately allowed to differ.

        EVERY FIELD IS ESCAPED. A title comes out of a markdown table in the repository and may
        legitimately carry an ampersand or a quote; unescaped, one of those ends an attribute or
        invents an entity. The body is NOT here -- it travels as JSON and is rendered client-side.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Releases,
        [AllowEmptyString()][string]$DominantType = '',
        [AllowEmptyString()][string]$LiveFallbackVersion = '',
        [bool]$TrimVersion = $false
    )

    $rows = New-Object System.Collections.Generic.List[string]
    foreach ($r in $Releases) {
        $id      = 'v' + [string]$r.version
        $version = ConvertTo-HtmlText (Format-ReleaseVersionLabel -Version ([string]$r.version) -Trim $TrimVersion)
        $title   = ConvertTo-HtmlText ([string]$r.title)
        $date    = ConvertTo-HtmlText (Format-ReleaseDate -Raw ([string]$r.date))

        $chipClass = ''
        $chipText  = ''
        # The marker where the table carries one, the newest release where it carries none -- see
        # Get-ReleaseLiveFallbackVersion for why the second half is derived and what it defers to.
        if ($r.live -or ($LiveFallbackVersion -and ([string]$r.version) -eq $LiveFallbackVersion)) {
            $chipClass = 'chip accent'
            $chipText  = 'LIVE'
        } elseif (([string]$r.type).Trim() -and ([string]$r.type).Trim() -ne $DominantType) {
            $chipClass = 'chip'
            $chipText  = ConvertTo-HtmlText ([string]$r.type)
        }
        $chip = if ($chipText) { '<span class="' + $chipClass + ' sc">' + $chipText + '</span>' } else { '' }

        # THE TITLE TRAVELS AS THE ROW'S ACCESSIBLE NAME, not as visible text. A summary reading only
        # 'Version 2.39' and a date is thin for anyone navigating by control rather than by eye, and the
        # title is the one string that says what the row is -- so it goes on the element as a title
        # attribute, where it costs no width and is still announced and shown on hover.
        $rows.Add('    <details class="fold" id="' + (ConvertTo-HtmlText $id) + '">')
        $rows.Add('      <summary title="' + $title + '"><span class="sv">' + $version + '</span>' +
                  $chip +
                  '<span class="sd">' + $date + '</span></summary>')
        $rows.Add('      <article data-version="' + (ConvertTo-HtmlText ([string]$r.version)) + '"></article>')
        $rows.Add('    </details>')
    }
    if ($rows.Count -eq 0) { return '    <p>No release on this page carries a note yet.</p>' }
    return ($rows -join "`n")
}

function Find-StrayPathToken {
    <#
        Every worker-path-token.txt in this tree that is NOT the one this run expects.

        WHY IT LOOKS AT ALL. The page directory is derived from the note root and gitignored -- two
        good decisions that combine into one hazard. Rename or repoint the folder holding the release
        documents and every tracked file moves with it, while the token stays behind in a folder
        nothing points at any more: git mv cannot see an ignored sibling by construction, so the miss
        is silent on the day it happens. In a public repo that file is the only copy of the live page's
        path and nothing in git remembers the URL, so the orphan reads as rename debris -- and deleting
        it 404s every link already sent (issue #1444, September 5, 2026, after this repo's own
        contributing-davekjohn/ -> dkj-policy/ rename left exactly that folder behind).

        AND IT IS WHAT MAKES -InitToken's REFUSAL MEAN WHAT IT SAYS. That guard reads the expected path
        and nothing else, so after a move it finds no token and mints a second one happily -- the one
        act the whole design exists to prevent. "Is there a token SOMEWHERE" is the question worth
        asking; "is there a token HERE" was only ever a cheap approximation of it.

        Cheap enough to sit on the two failure paths because that is the only place it runs. .git is
        skipped: nothing writes a token there, and walking it is the expensive half of the search.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$ExpectedPath
    )

    if (-not (Test-Path -LiteralPath $Root)) { return @() }
    $hits = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter 'worker-path-token.txt' -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -ne $ExpectedPath -and $_.FullName -notlike '*\.git\*' }
    return @($hits | ForEach-Object { $_.FullName })
}

# THE TWO PAGE-WIDE ANSWERS, DERIVED ONCE FROM THE LIST RATHER THAN PER ROW: whether the bump type
# carries information here at all, and whether every version on this page ends in '.0'. Both are
# properties of the SET, so neither can be decided inside the row loop -- and both are read off the data
# instead of a seam, which is what makes them right for a consumer whose bump policy differs or changes.
$dominantType = Get-ReleaseDominantType           -Releases $releases
$liveFallback = Get-ReleaseLiveFallbackVersion -Releases $releases
$trimVersion  = Test-ReleaseVersionTrimmable -Releases $releases

$masthead = Format-ReleaseMastheadMarks -Marks $config.Masthead
foreach ($w in $masthead.Warnings) { Write-Warning $w }

$page = $template.
    Replace('@@PAGE_TITLE@@',    (ConvertTo-HtmlText $config.Title)).
    Replace('@@PAGE_SUBTITLE@@', (ConvertTo-HtmlText $subtitle)).
    Replace('@@PAGE_MASTHEAD@@', $masthead.Html).
    Replace('@@BUILD_STAMP@@',   (ConvertTo-HtmlText $stamp)).
    Replace('@@PAGE_STYLE@@',    (Format-ReleasePageStyle -Theme $config.Theme)).
    Replace('@@RELEASE_ROWS@@', (Format-ReleaseIndexRows -Releases $releases -DominantType $dominantType -LiveFallbackVersion $liveFallback -TrimVersion $trimVersion)).
    Replace('@@RELEASE_DATA@@',  $json)

# --- 4. Where the output goes ---------------------------------------------------------------------
# A 'page' directory beside the note root, derived rather than configured: the note root already
# says where this repo keeps its release documents, and a second seam saying "and the page goes
# here" would be a second statement of the same decision.
$pageDir = Join-Path (Split-Path -Parent $noteRoot) 'page'
if (-not (Test-Path -LiteralPath $pageDir)) { New-Item -ItemType Directory -Force -Path $pageDir | Out-Null }

if (-not $OutFile) { $OutFile = Join-Path $pageDir 'release-notes.html' }
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($OutFile, $page, $Utf8NoBom)

Write-Host "== build-release-notes-page ==" -ForegroundColor Cyan
Write-Host "  releases : $($releases.Count)  (v$($releases[$releases.Count - 1].version) .. v$($releases[0].version))"
if ($gaps.Count -gt 0) {
    # NAMED, because each one sits between two releases that do have a note -- either a bump this repo
    # writes no note for, or a note nobody wrote. Both are answers a reader can check; a count is not.
    Write-Host "  no note  : $($gaps -join ', ')  (inside the covered range -- check these are bumps that get none)" -ForegroundColor Yellow
}
if ($olderThanTheFirstNote -gt 0) {
    # COUNTED, because they predate the first note this repo ever wrote and naming them would print a
    # defect list of releases that were never in scope.
    Write-Host "  earlier  : $olderThanTheFirstNote release(s) older than the first note -- not on the page" -ForegroundColor DarkGray
}
Write-Host "  page     : $OutFile ($([math]::Round((Get-Item -LiteralPath $OutFile).Length / 1KB)) KB)" -ForegroundColor Green

# --- 5. The worker bundle -------------------------------------------------------------------------
$tokenPath = Join-Path $pageDir 'worker-path-token.txt'

if ($InitToken) {
    if (Test-Path -LiteralPath $tokenPath -PathType Leaf) {
        throw ("A path token already exists at $tokenPath. This script does not replace one: the URL " +
               "carrying it has been sent, so a new token means every existing link 404s. Delete the " +
               "file deliberately if that is genuinely what you want.")
    }
    # AND A COPY ANYWHERE ELSE IN THE TREE IS AN EXISTING TOKEN TOO (issue #1444). The refusal above
    # asks whether one is HERE, which stops meaning what it says the moment the page directory moves --
    # see Find-StrayPathToken for why that move is silent by construction.
    # @( ) at the call site, not in the function: PowerShell unrolls a returned empty array to $null,
    # and Set-StrictMode -Version Latest then refuses .Count on it.
    $strays = @(Find-StrayPathToken -Root $repoRoot -ExpectedPath $tokenPath)
    if ($strays.Count -gt 0) {
        throw ("There is no token at $tokenPath, but this tree already holds one: $($strays -join ', '). " +
               "That is what a renamed or repointed release folder leaves behind -- the page directory " +
               "is gitignored, so it stayed where it was while everything tracked moved. MOVE that " +
               "folder here instead of creating a second token, which 404s every link already sent. " +
               "Delete the copy deliberately if it is genuinely dead.")
    }
    $newToken = [guid]::NewGuid().ToString('N')
    [System.IO.File]::WriteAllText($tokenPath, $newToken, $Utf8NoBom)
    Write-Host ""
    Write-Host "  A path token was created: $tokenPath" -ForegroundColor Yellow
    Write-Host "  IT IS THE ONLY LOCK ON THE PAGE. Record the finished URL somewhere you will find it" -ForegroundColor Yellow
    Write-Host "  again -- in a public repo this file is not committed, so nothing else remembers it." -ForegroundColor Yellow
    # A CONFIGURED WORKER NAME MEANS THIS REPO HAS HOSTED THE PAGE BEFORE, so "there is no token here"
    # is not evidence that there is no LIVE page -- the deployment holds its own copy of the old one.
    # Reported rather than refused: -InitToken is explicit, and a first-ever token is the legitimate
    # case that looks identical from here. See the token note in the header (issue #1453).
    if ($config.WorkerName) {
        Write-Host ""
        Write-Host "  NOTE: this repo names a worker ('$($config.WorkerName)'), so a page may already be live" -ForegroundColor Yellow
        Write-Host "  on the OLD token -- and deploying this one 404s every link already sent. The deployed" -ForegroundColor Yellow
        Write-Host "  bundle carries its route as a literal, so the old token is still readable from" -ForegroundColor Yellow
        Write-Host "  Cloudflare (the worker's code view, or the Workers script API). Check there before you" -ForegroundColor Yellow
        Write-Host "  deploy: if the old token comes back, delete this file and restore that one instead." -ForegroundColor Yellow
    }
}

if (-not $Worker) { exit 0 }

if (-not $config.WorkerName) {
    throw ("-Worker needs a worker name. Add Get-ReleasePageWorkerName to scripts\repo-config.ps1, " +
           "returning the Cloudflare Worker's name (e.g. 'my-repo-release-notes'); an empty answer " +
           "means this repo does not host the page and the page half above still runs on its own.")
}
if (-not (Test-Path -LiteralPath $tokenPath -PathType Leaf)) {
    # The missing token is worth ONE search before the refusal is printed, because the likeliest
    # reason it is missing here is that it is somewhere else -- see Find-StrayPathToken.
    $strays = @(Find-StrayPathToken -Root $repoRoot -ExpectedPath $tokenPath)
    $lead = if ($strays.Count -gt 0) {
        "This tree already holds one, at $($strays -join ', '). A page directory is gitignored, so it " +
        "did not travel with a renamed or repointed release folder: MOVE that folder here rather than " +
        "creating a second token. "
    } else {
        "If this repo's release folder was renamed or repointed, the only copy is still sitting in the " +
        "old one -- it is gitignored, so nothing moved it and nothing reported that. "
    }
    throw ("The path token is missing: $tokenPath. " + $lead + "This script does NOT invent one -- the " +
           "path is the only lock on a public page, so a fresh token means the reader's link 404s while " +
           "the build and the deploy both report success. THREE WAYS BACK, in the order worth trying: " +
           "(1) restore the 32 hex characters from the URL you have; (2) if the worker is still " +
           "deployed, read them off the DEPLOYMENT -- the bundle carries the route as a literal, so " +
           "Cloudflare still holds the token even when no copy survives on any machine here (the " +
           "worker's code view in the dashboard, or the Workers script API); (3) only once both of " +
           "those are exhausted, -InitToken for a fresh path -- which 404s every link already sent.")
}
$token = ([System.IO.File]::ReadAllText($tokenPath, [System.Text.Encoding]::UTF8)).Trim()
if ($token -notmatch '^[0-9a-f]{32}$') {
    throw "The path token is not 32 hex characters: $tokenPath"
}
$route = "/notes/$token"

# The page travels into the worker as ONE JSON string, which is why nothing here has to escape
# anything a second time.
$workerJs = @"
// GENERATED by scripts/release/build-release-notes-page.ps1 -Worker. Do not edit: rebuild instead.
const ROUTE = $(ConvertTo-Json -InputObject $route -Compress);
const HTML = $(ConvertTo-Json -InputObject $page -Compress);

export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname === ROUTE || url.pathname === ROUTE + "/") {
      return new Response(HTML, {
        headers: {
          "content-type": "text/html; charset=utf-8",
          "cache-control": "no-store",
          "x-robots-tag": "noindex, nofollow",
        },
      });
    }
    return new Response("Not found", { status: 404 });
  },
};
"@

$workerPath = Join-Path $pageDir 'worker.js'
[System.IO.File]::WriteAllText($workerPath, $workerJs, $Utf8NoBom)

# WRITTEN ONLY WHEN ABSENT. A consumer edits this file -- an account id, a custom domain, a route --
# and regenerating it every run would silently discard that. A name that has drifted from the seam
# is reported instead of corrected, because which of the two is wrong is not this script's to decide.
#
# AND THE ABSENT BRANCH IS THE ONE THAT REPORTS (issue #1479), because it is the only one that cannot
# honour "never overwritten": there was nothing to overwrite. This file sits in the same gitignored
# directory as the path token and is lost by the same mechanisms, so an absent one is as likely to
# mean "the directory was rebuilt from nothing" as "first run here". Same shape as the -InitToken
# note above -- reported, not refused, since a first-ever deploy looks identical from here. There is
# deliberately NO second condition on it: -Worker has already refused an empty worker name, so
# reaching this line IS the evidence that this repo hosts the page.
$wranglerPath = Join-Path $pageDir 'wrangler.toml'
if (-not (Test-Path -LiteralPath $wranglerPath -PathType Leaf)) {
    $wrangler = @"
name = "$($config.WorkerName)"
main = "worker.js"
compatibility_date = "2025-04-01"
workers_dev = true

# No account_id on purpose: it is one more identifier to keep out of a public repo, and wrangler
# resolves the account from CLOUDFLARE_ACCOUNT_ID or from the token when it has only one. Add it
# here if you work across several accounts -- this file is written once and never overwritten.
"@
    [System.IO.File]::WriteAllText($wranglerPath, $wrangler, $Utf8NoBom)
    Write-Host "  wrangler : $wranglerPath (written -- it is yours from now on, never overwritten)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  NOTE: it was ABSENT -- the one case here that cannot honour 'never overwritten', because" -ForegroundColor Yellow
    Write-Host "  there was nothing to overwrite. Reaching this line means a worker name is configured" -ForegroundColor Yellow
    Write-Host "  ('$($config.WorkerName)'), so a wrangler.toml may well have stood here and been lost with the" -ForegroundColor Yellow
    Write-Host "  rest of this gitignored directory. Whatever it carried beyond the lines above -- an" -ForegroundColor Yellow
    Write-Host "  account id, a custom domain, a route -- is NOT in this one, and nothing here remembers" -ForegroundColor Yellow
    Write-Host "  what it said. Read it before you deploy: a first-ever deploy is the legitimate case and" -ForegroundColor Yellow
    Write-Host "  looks identical from here, which is why this is a note and not a refusal." -ForegroundColor Yellow
} else {
    $declared = [regex]::Match([System.IO.File]::ReadAllText($wranglerPath, [System.Text.Encoding]::UTF8), '(?m)^\s*name\s*=\s*"([^"]+)"')
    if ($declared.Success -and $declared.Groups[1].Value -ne $config.WorkerName) {
        Write-Warning ("wrangler.toml deploys '$($declared.Groups[1].Value)' while Get-ReleasePageWorkerName " +
                       "says '$($config.WorkerName)'. One of the two is wrong -- this script does not pick.")
    }
}

Write-Host "  worker   : $workerPath ($([math]::Round((Get-Item -LiteralPath $workerPath).Length / 1KB)) KB), route $route" -ForegroundColor Green
Write-Host ""
Write-Host "  Next:  cd `"$pageDir`"  &&  npx wrangler deploy" -ForegroundColor Cyan
Write-Host "  Then verify the BYTES the URL serves, not the deploy command's output -- once wrangler has" -ForegroundColor DarkGray
Write-Host "  deployed a worker, an API upload only creates inactive versions, silently. Fetch TWICE: a" -ForegroundColor DarkGray
Write-Host "  read seconds after a good deploy can still be a cached 200 with the old body, which looks" -ForegroundColor DarkGray
Write-Host "  exactly like that failure. Compare the second, cache-busted read against this file." -ForegroundColor DarkGray
exit 0
