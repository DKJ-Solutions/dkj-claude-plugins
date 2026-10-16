<#
.SYNOPSIS
    Build the paste-ready block for a GitHub issue, including its go-live half: where the result can
    be seen, when it is planned to go live, and the live storefront URLs per market.

.DESCRIPTION
    Issue #2100 (Dave, September 18, 2026). WORKFLOW-portable.md's paste-ready block answered 'where
    can I see it' and stopped there; the requester's next question is always 'and when do I actually
    see it'. This script writes the whole block -- the marker, the framing sentence that stays on
    GitHub, and the paragraph between the two '---' rules that a colleague can paste into the Asana task.

    IT NEVER WRITES A PLACEHOLDER. This script runs in the session that shipped the work, which knows
    where the result can be seen -- so a link it was not given is a sentence it does not write.

    WHAT IT NEVER DOES: touch Asana. It writes the block on the GitHub issue, and the asana-closed-message
    CI workflow carries it into the task as its closed message when the issue closes as completed (#2818,
    Dave, October 5, 2026; the shape is #2700/#2703's). Nobody pastes it.

    THE THREE GO-LIVE FACTS AND WHERE EACH COMES FROM:

      the date     the next release day, strictly after today. BWJ cuts on a Monday, which is the
                   default; -ReleaseDay is there for a repo on another cadence. Where the change is
                   ALREADY live, -LiveSince names that day instead and the block says so (#2943).
      the version  ONLY WHAT -Version SAYS (#2620). The newest vX.Y.Z tag stepped by the bump the
                   changelog's pending tally names today is printed on the console as a projection,
                   and never written into the block: every entry that lands before release day can
                   raise it, and a colleague quotes the block back as a fact. The tally is read, not
                   re-derived -- the tier parser lives in dkj-policy's libs, out of this plugin's reach.
      the URLs     Get-MarketUrls over the pages -Path names, from the same market table a preview
                   pair is built from -- BARE, with a private-window caveat in the label (#2619): a
                   bare URL renders the preview in any browser that opened the result link first
                   (#2477), and a URL pinned to the live id reads as a preview link to a colleague.

    THE BLOCK IS WRITTEN IN THE COLLEAGUE'S LANGUAGE, IN THE SHAPE BWJ SENDS (#2507). -Language picks
    the words (Dutch by default: BWJ's board is Dutch); the sections are the reference block's -- what
    changed, where to look, when it goes live, what is deliberately not in it, what we ask. The facts
    above are the script's; the prose sections are the session's, handed in through -ProseFile.

    AND IT KEEPS THOSE CHARACTERS INTACT ON THE WAY OUT. Windows PowerShell 5.1 pipes a string into a
    native command through $OutputEncoding, which is ASCII there, so piping the block into gh turned
    every accent and dash into '?'. The post therefore goes through a UTF-8 file, and -OutFile writes
    the same bytes for a caller that embeds the block elsewhere -- the console printout is for reading,
    and a console code page may not carry every character.

    THE DATE IS A PROJECTION AND THE BLOCK SAYS 'Planned to', never 'will': a release can slip. The
    version was one too until #2620 -- a tier-1 entry landing on the Friday turns a predicted patch into
    a minor -- which is why it left the block. Where a fact cannot be derived it is left out rather than
    guessed -- see golive-block-rules.ps1's header.

    AND IT HOLDS THE POST BACK WHILE THE STORE IS NOT READY (#2885). A change can need work on the store
    rather than in the theme -- a metafield definition, a menu, a setting -- and the issue then carries a
    checklist under Get-StoreAdminPrerequisiteMarker. -Post refuses while a box on it is open (-Force past
    it); -OutFile, which the preview handover page embeds, warns. A print-only run reads nothing.

    AND IT CHECKS THAT THE CLOSE HAS A TASK TO CARRY THE BLOCK TO (#2918). The same issue read resolves
    the body's Asana link with Resolve-AsanaTaskRef, the matcher asana-closed-message uses. On 'none' or
    'ambiguous' the lead stops promising 'no paste needed', -OutFile warns, and -Post refuses (-Force for
    an issue that is deliberately GitHub-only).

    AND ONLY A BLOCK FROM THE CURRENT ROUND COUNTS AS A DUPLICATE (#2968). An issue reopened after its
    first close carries the first round's block, and refusing a second one made the corrected block the
    awkward route while the stale one went on to the requester: xoxowildhearts#414's second closed
    message carried round 1's block. The duplicate check now counts only blocks posted after the issue's
    last reopen, so the corrected block posts without -Force; every other check below is unchanged. The
    PreToolUse hook hooks/guard-stale-paste-block.ps1 refuses a ship while the newest block is older than
    the reopen, and names this command as the fix.

    AND A TICKET WITHOUT A STOREFRONT RESULT GETS A BLOCK TOO: -Research (#3004, Maikel, October 14,
    2026). A research, test or decision ticket changes nothing on the store, so it has no link, no
    release day, no live URLs and no pull request -- and it was closed by hand with no block at all,
    which sent the requester of smartwatchbanden#943 a bare 'is now closed'. -Research writes the
    research form instead (Format-GoLiveResearchBlock): the intro every completed close shares ('is now
    closed: this Asana task is now in review.'), 'Nothing has changed. Read the outcome below.' (#3069)
    and one section, OUTCOME, as
    bullets from the prose file's [outcome] section ([found] before #3017, still read), which it then
    requires. It refuses the go-live
    parameters, which have nothing to describe, and skips the pull-request check, since there is none.
    The block carries Get-AsanaResearchBlockMarker beside its marker, so the closed message writes the
    research form. The close guard (hooks/guard-stale-paste-block.ps1) refuses a hand close of an
    Asana-linked issue until a block like this one is on it.

    -Research ONLY WHEN NOTHING CHANGED, ON THE STORE OR IN THE REPO (#3069, Maikel, October 16, 2026).
    A store-admin act that is already live -- a metaobject, a metafield value, a setting -- changed the
    store, so it takes the go-live form with -LiveSince, even though no repo file changed. Measured on
    smartwatchbanden#395: a metaobject that changed the live structured data was closed with -Research,
    and the requester rejected it. And the [outcome] names the NEW information and why it is valuable,
    not what was done or where to look.

    A RESULT BLOCK WITHOUT -LiveSince CARRIES Get-AsanaReleaseBlockMarker (#3069): it names a planned
    release day, so its result is visible only once that release is out, and the closed line -- in the
    block and in the closed message -- says so under the intro.

    WHY IT DOT-SOURCES scripts/lib/asana-task-lib.ps1. For Get-AsanaPasteBlockMarker and
    Test-AsanaPasteBlockPosted -- the marker the block's comment carries, and the read that answers
    whether a block is already there -- and Resolve-AsanaTaskRef for the link check above, plus
    ConvertTo-ConsoleStrippedText through ref-print-lib.ps1.
    Until October 5, 2026 these came from templates/asana-mirror.ps1, retired with the workflow.

    Pure ASCII (repo convention for .ps1).

.PARAMETER Issue
    The issue the block belongs to: a bare number, '#123', or the issue's URL.

.PARAMETER Repo
    'owner/repo'. Defaults to GITHUB_REPOSITORY, then to what 'gh repo view' resolves from the
    checkout.

.PARAMETER Link
    Where the result can be seen, openable by the requester WITHOUT an account -- a storefront preview
    URL (Get-MarketPreviewUrls), a live page, whatever the ticket was about. NOT the preview handover
    page: a claude.ai Artifact is private to its owner, so it is refused (issue #2341) unless
    -AllowPrivateLink says it has been shared. Omitted, the block simply does not carry that sentence;
    it is never replaced by a placeholder.

.PARAMETER AllowPrivateLink
    Accept a claude.ai Artifact URL as -Link anyway -- for a page that has actually been shared with the
    requester. Deliberately not -Force: that valve answers the duplicate-block check, and passing it to
    post a second block must not also wave a private link through.

.PARAMETER Path
    The storefront pages the change touched, as paths ('/products/foo'). Each becomes one live URL
    per market. Omitted, the block carries no live-URL list -- which is the right answer in a repo
    that serves no storefront.
    Pages separate on ','. A page whose handle differs per market (issue #2627: a collection is
    /collections/apple-watch-bandjes on NL and /collections/apple-watch-straps on UK, and one plain
    path is a 404 on the other markets) takes a per-market form: '|' separates segments, a bare
    segment is the default and 'LABEL=/path' overrides it for that market. Labels are the market
    table's, case-insensitive. Refused: an unknown label, a label twice, two defaults, an empty
    'LABEL=', and a page with no default that leaves a market unnamed.

.PARAMETER Version
    The version to name in the block. Omitted, the block names the release day and no number (#2620);
    pass it once the number can no longer change -- the cut is prepared, or a major has been decided.

.PARAMETER ReleaseDay
    The weekday releases are cut on. Monday, which is BWJ's cadence.

.PARAMETER From
    The day the next release day is counted from. Today, unless a test or a caller says otherwise.

.PARAMETER LiveSince
    The day the change WENT live, for an issue that closes after its release -- the normal case for one
    parked awaiting-release, or work pushed live on its own (#2943). The block then says 'live since'
    that day instead of naming the next release day, and drops the sentences that only hold before a
    release. A day after today is refused, and so is passing -From or -ReleaseDay beside it.

.PARAMETER Language
    The language of the Asana task, which is the language of the block between the rules: 'nl' (the
    default) or 'en'. The framing sentence above the rules stays English -- it is read on GitHub.
    Omitted, the repo's own answer is used where scripts/repo-config.ps1 defines
    Get-GoLiveBlockLanguage (returning 'nl' or 'en'), so a store states its language once (#2830).

.PARAMETER ProseFile
    A UTF-8 text file with the session's own prose for the block, under section lines '[changed]',
    '[where]' and '[not-included]' (ConvertFrom-GoLiveProse). Omitted, those sections are not written,
    and the run warns that the block does not say what changed.

.PARAMETER Research
    Write the research form (#3004) for a ticket without a storefront result: research, a test, a
    decision. Requires a -ProseFile with an [outcome] section, and refuses its other sections and -Link,
    -Path, -Version, -LiveSince, -From and -ReleaseDay. -Post skips the pull-request check, since such a
    ticket has none; every other check stays.

.PARAMETER OutFile
    Also write the whole comment to this path as UTF-8 -- the faithful copy for a page that embeds the
    block, where the console printout may have lost characters to its code page.

.PARAMETER Post
    Also post the block as a comment on the issue. Without it the block is printed and nothing is
    written anywhere.

.PARAMETER Force
    Post even though a paste-ready block already appears to be on the issue FOR THIS ROUND (one from
    before the issue's last reopen does not count, #2968), a store-admin prerequisite
    on it is still unticked (#2885), its body links no single Asana task (#2918), or a check could not
    read the issue.

.PARAMETER RootOverride
    The repo root, when this is not run from inside the checkout.

.EXAMPLE
    ./build-golive-block.ps1 -Issue 412 -Link "https://store.example/products/foo?preview_theme_id=123&_ab=0&_fd=0&_sc=1"
    Prints the block for issue 412, with the date derived from this repo and the projected version on
    the console only.

.EXAMPLE
    ./build-golive-block.ps1 -Issue 412 -Link https://... -Path /collections/straps -Post
    Adds one live URL per market for that page, and posts the block on the issue.

.EXAMPLE
    ./build-golive-block.ps1 -Issue 412 -Link https://... -Path "/collections/apple-watch-straps|NL=/collections/apple-watch-bandjes|DE=/collections/apple-watch-armbaender|FR=/collections/bracelets-apple-watch|ES=/collections/correas-apple-watch"
    One page with its own handle on each market; the bare segment covers any market not named.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Issue,
    [string]$Repo,
    [string]$Link,
    [string[]]$Path,
    [string]$Version,
    [System.DayOfWeek]$ReleaseDay = [System.DayOfWeek]::Monday,
    [datetime]$From = (Get-Date),
    [Nullable[datetime]]$LiveSince,
    [ValidateSet('nl', 'en')][string]$Language = 'nl',
    [string]$ProseFile,
    [switch]$Research,
    [string]$OutFile,
    [switch]$Post,
    [switch]$Force,
    [switch]$AllowPrivateLink,
    [string]$RootOverride
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# The parameters, captured under names of their own before the libs below are dot-sourced.
$StoreRepo   = if ($Repo) { $Repo } else { $env:GITHUB_REPOSITORY }
$IssueArg    = $Issue
$LinkArg     = $Link
$PathArg     = $Path
$VersionArg  = $Version
$ReleaseDayArg = $ReleaseDay
$FromArg     = $From
$LiveSinceArg = $LiveSince
$LiveSinceConflict = $PSBoundParameters.ContainsKey('LiveSince') -and ($PSBoundParameters.ContainsKey('From') -or $PSBoundParameters.ContainsKey('ReleaseDay'))
$LanguageArg = $Language
$ProseArg    = $ProseFile
$ResearchArg = [bool]$Research
# THE GO-LIVE PARAMETERS A RESEARCH BLOCK REFUSES (#3004): each describes a result on the store, and a
# research ticket has none, so a value passed for one is a sign the wrong form was asked for.
# A foreach statement, not Where-Object: a scriptblock has a $PSBoundParameters of its own.
$ResearchConflicts = @(foreach ($name in @('Link', 'Path', 'Version', 'LiveSince', 'From', 'ReleaseDay')) { if ($PSBoundParameters.ContainsKey($name)) { $name } })
$OutFileArg  = $OutFile
$PostArg     = [bool]$Post
$ForceArg    = [bool]$Force
$RootArg     = $RootOverride

. (Join-Path $PSScriptRoot '..\lib\asana-task-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\golive-block-rules.ps1')
. (Join-Path $PSScriptRoot '..\lib\repo-root-lib.ps1')

$repoRoot = Resolve-BwjRepoRoot -Override $RootArg

# THE REPO'S SEAMS ARE LOADED ONCE, AT SCRIPT SCOPE -- issue #2339. Two halves below read them:
# Get-ChangelogPath for the version, and Get-StorefrontMarkets, which market-urls.ps1 looks up by name
# when -Path is given. This used to dot-source the config inside a '& { }' scriptblock for the first
# half only, so every function it defined died with that scope and the live-URL half then refused with
# "this store has not declared its markets" in a store that had -- naming the wrong remedy. It worked
# only for a caller who had dot-sourced the config into the session first, which the skill's own '-File'
# invocation never does. An 'if' opens no scope, so the functions defined here survive it.
# StrictMode is off for the read only: repo-config.ps1 is written on the assumption that it is (the same
# note build-backlog-page.ps1 makes). The parameters were captured above, because the file is the
# consumer's own and may bind any name it likes.
$configPath = Join-Path $repoRoot 'scripts\repo-config.ps1'
if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    Set-StrictMode -Off
    $resolvedRoot = $repoRoot
    . $configPath
    Set-StrictMode -Version Latest
    $repoRoot = $resolvedRoot
}

# THE REPO MAY STATE ITS LANGUAGE ONCE (#2830). A store that writes GitHub in English otherwise had to
# remember '-Language en' on every call, and a session running this from the skill page alone wrote a
# Dutch block. An explicit -Language still wins; without the seam the default stays 'nl'.
if (-not $PSBoundParameters.ContainsKey('Language') -and (Test-Path -LiteralPath 'function:Get-GoLiveBlockLanguage')) {
    $seamLanguage = [string](Get-GoLiveBlockLanguage)
    if (@('nl', 'en') -notcontains $seamLanguage) {
        throw "Get-GoLiveBlockLanguage in scripts/repo-config.ps1 answers '$seamLanguage'; it must be 'nl' or 'en'."
    }
    $LanguageArg = $seamLanguage
}

function Invoke-Native {
    <# A native command whose stderr and exit code are read rather than thrown on. '2>$null' under
       EAP=Stop turns every stderr line into a terminating error, which is the trap repo-root-lib.ps1
       documents; the same try/finally shape is used here, and the repo-wide guard in
       scripts/tests/shared-scripts.tests.ps1 exonerates it. #>
    param([Parameter(Mandatory = $true)][scriptblock]$Command)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out  = & $Command 2>$null
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prev
    }
    return [pscustomobject]@{ Output = @($out); Code = $code }
}

# --- Which issue, on which repo ---------------------------------------------------------------------
# THE THREE SPELLINGS A PERSON ACTUALLY HAS IN HAND -- a bare number, '#123', or the URL they just
# copied out of the browser. claim-issue.ps1 makes the same argument for accepting all three: requiring
# one spelling only teaches the caller to strip characters this script can strip itself.
$issueNumber = if ($IssueArg -match '(\d+)\s*$') { $Matches[1] } else { '' }
if (-not $issueNumber) { throw "-Issue '$IssueArg' carries no issue number." }

if (-not $StoreRepo) {
    $probe = Invoke-Native { gh repo view --json nameWithOwner -q .nameWithOwner }
    if ($probe.Code -eq 0 -and $probe.Output.Count -gt 0) { $StoreRepo = ([string]$probe.Output[0]).Trim() }
}
if (-not $StoreRepo) {
    throw "Could not resolve which repo this issue is on. Pass -Repo <owner/repo>, or set GITHUB_REPOSITORY."
}
# ASSIGNED AFTER THE DOT-SOURCE ABOVE, AND THAT ORDER MATTERS. The template's own param() binds
# $IssueRef in this scope, PowerShell variable names are case-insensitive, and its default is ''.
$targetRef = "$StoreRepo#$issueNumber"

# --- The link its reader can open -------------------------------------------------------------------
# A REFUSAL AND NOT A WARNING, and it applies to printing as much as posting: the printout IS what gets
# carried into the Asana task, so a warning under it would travel nowhere the requester looks (#2341).
if ((Test-PrivateResultLink -Link $LinkArg) -and -not $AllowPrivateLink) {
    Write-Host "[ERROR] -Link is a claude.ai Artifact ($LinkArg) -- private to its owner, so the requester" -ForegroundColor Red
    Write-Host "        reading the Asana task cannot open it. The handover page is the reviewer's surface." -ForegroundColor Red
    Write-Host "        Pass a storefront preview URL instead (Get-MarketPreviewUrls in market-urls.ps1), or" -ForegroundColor Red
    Write-Host "        -AllowPrivateLink once the page has actually been shared with them. Nothing written." -ForegroundColor Red
    exit 1
}

# --- The session's prose ----------------------------------------------------------------------------
# READ AS UTF-8 AND REFUSED WHOLE ON A FORMAT ERROR: a section line the parser does not know would
# otherwise drop the paragraph under it, and the block would ship without the part the session wrote.
$prose = @{ Changed = @(); WhereToLook = @(); NotIncluded = @(); Outcome = @() }
if ($ProseArg) {
    if (-not (Test-Path -LiteralPath $ProseArg -PathType Leaf)) {
        Write-Host "[ERROR] -ProseFile '$ProseArg' does not exist. Nothing written." -ForegroundColor Red
        exit 1
    }
    try {
        $prose = ConvertFrom-GoLiveProse -Text ([System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $ProseArg).ProviderPath, [System.Text.Encoding]::UTF8))
    } catch {
        Write-Host "[ERROR] -ProseFile: $(ConvertTo-ConsoleStrippedText -Text $_.Exception.Message) Nothing written." -ForegroundColor Red
        exit 1
    }
}

# --- Which form: a result to look at, or an outcome (#3004, #3017) -------------------------------------------
# EACH FORM REFUSES THE OTHER'S PROSE, so a section the session wrote is never silently left out of the
# block: [outcome] has no place in a result block, and a research block carries nothing but [outcome].
if ($ResearchArg) {
    if ($ResearchConflicts.Count -gt 0) {
        Write-Host "[ERROR] -Research writes a block for a ticket that changed nothing on the store, so -$($ResearchConflicts -join ', -') has nothing to describe. Nothing written." -ForegroundColor Red
        exit 1
    }
    $resultProse = @(@('Changed', 'WhereToLook', 'NotIncluded') | Where-Object { @($prose[$_]).Count -gt 0 })
    if ($resultProse.Count -gt 0) {
        Write-Host "[ERROR] -Research carries the [outcome] section only; -ProseFile also has a result section ([changed], [where] or [not-included]). Move it under [outcome]. Nothing written." -ForegroundColor Red
        exit 1
    }
    if (@($prose.Outcome).Count -eq 0) {
        Write-Host "[ERROR] -Research needs the outcome: a -ProseFile with an [outcome] section, written for the requester. A link to the issue is no substitute -- not every requester can open it. Nothing written." -ForegroundColor Red
        exit 1
    }
} elseif (@($prose.Outcome).Count -gt 0) {
    Write-Host "[ERROR] -ProseFile has an [outcome] section, which only a research block carries. Pass -Research for a ticket that changed nothing on the store. Nothing written." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "== build-golive-block $targetRef ==" -ForegroundColor Cyan

# A RESEARCH BLOCK HAS NO GO-LIVE HALF (#3004): nothing changed on the store, so there is no day it goes
# live, no version and no page to list, and none of the three is worked out or printed.
if (-not $ResearchArg) {
    # --- The date ---------------------------------------------------------------------------------------
    # ALREADY LIVE IS A FACT THE SESSION STATES, NOT ONE THIS SCRIPT DERIVES (#2943). The next release day is
    # computed strictly after today, so an issue closing after its release -- or after a separate live push --
    # was told it goes live next Monday. -LiveSince names the day; a future one is a planned date, which is
    # what the default already says, and -From/-ReleaseDay beside it would be a second answer to one question.
    if ($LiveSinceConflict) {
        Write-Host "[ERROR] -LiveSince names the day it went live; -From and -ReleaseDay plan a release day. Pass one or the other. Nothing written." -ForegroundColor Red
        exit 1
    }
    if ($null -ne $LiveSinceArg -and ([datetime]$LiveSinceArg).Date -gt (Get-Date).Date) {
        Write-Host "[ERROR] -LiveSince $(([datetime]$LiveSinceArg).ToString('yyyy-MM-dd')) is after today -- a day it has not gone live yet. Leave it off for a planned date. Nothing written." -ForegroundColor Red
        exit 1
    }
    $isLive     = $null -ne $LiveSinceArg
    $goLive     = if ($isLive) { ([datetime]$LiveSinceArg).Date } else { Get-NextReleaseDate -From $FromArg -ReleaseDay $ReleaseDayArg }
    $goLiveText = Format-GoLiveDate -Date $goLive -Language $LanguageArg
    Write-Host "  go live  : $goLiveText$(if ($isLive) { ' (already live -- -LiveSince)' })" -ForegroundColor DarkGray

    # --- The version ------------------------------------------------------------------------------------
    # THE TAG IS THE RECORD OF THE LAST CUT IN EVERY REPO RUNNING THIS WORKFLOW, whether or not it
    # publishes plugins -- cut-release always tags. The lockstep read that script also makes exists to PROVE
    # the manifests agree, which is a release gate's question and not a message generator's.
    #
    # THE PROJECTION IS THE SESSION'S, AND ONLY -Version REACHES THE BLOCK (#2620). The tally is the entries
    # folded so far, and every entry that lands before release day can still raise it, so the stepped number
    # is a guess -- one a colleague quotes back as a fact. It is still worked out and printed here, where the
    # session can weigh it; the block names a version only when somebody passes one on purpose.
    $resolvedVersion = $VersionArg
    $projected       = ''
    $versionWhy      = 'given with -Version'
    if (-not $resolvedVersion) {
        $tagRun = Invoke-Native { git -C $repoRoot tag --list 'v*' --sort=-v:refname }
        $latestTag = if ($tagRun.Code -eq 0 -and $tagRun.Output.Count -gt 0) { ([string]$tagRun.Output[0]).Trim() } else { '' }

        # The config itself was read at script scope above (#2339). NOT Get-Command: a bare name is parsed as
        # a wildcard and a MISS -- the normal case for an optional seam -- pays a full PATH scan. The same
        # inline probe publish-page.ps1 writes out.
        $changelogRel = 'CHANGELOG.md'
        if ([bool](@($ExecutionContext.InvokeCommand.GetCommands('Get-ChangelogPath', 'Function', $false)).Count)) {
            $changelogRel = Get-ChangelogPath
        }

        $changelogPath = Join-Path $repoRoot ($changelogRel -replace '/', '\')
        $bump = $null
        if (Test-Path -LiteralPath $changelogPath -PathType Leaf) {
            $bump = Get-PendingBumpFromTally -Changelog ([System.IO.File]::ReadAllText($changelogPath))
        }

        if ($latestTag -and $bump) {
            $projected  = Step-SemVer -Current ($latestTag -replace '^v', '') -Bump $bump
            $versionWhy = "$latestTag stepped by the '$bump' the pending tally names today -- NOT in the block; pass -Version to put a number there"
        } else {
            # NAMED RATHER THAN SUMMARISED, because the two causes have two different remedies: cut a tag,
            # or answer -Version because the tally cannot be read.
            $missing = @()
            if (-not $latestTag) { $missing += 'no v* tag' }
            if (-not $bump)      { $missing += 'no readable pending tally' }
            $versionWhy = 'not derived -- ' + ($missing -join ', ')
        }
    }
    $versionShown = if ($resolvedVersion) { "v$resolvedVersion" } elseif ($projected) { "(none; projected v$projected)" } else { '(none)' }
    Write-Host "  version  : $versionShown  [$versionWhy]" -ForegroundColor DarkGray

    # --- The live URLs ----------------------------------------------------------------------------------
    # ONLY WHERE -Path SAYS SO. A block with no pages named carries no list, which is the correct answer in
    # a repo that serves no storefront -- and Get-MarketUrls is left unloaded there rather than being called
    # and caught, so a repo with no markets is never asked a question it has no answer to.
    #
    # BARE, NEVER PINNED TO THE LIVE THEME ID (#2619). The cookie trap is real (#2477): the result link is
    # normally a storefront preview, and a bare URL keeps rendering it on any domain where it was opened
    # first. But the first repair, ?preview_theme_id=<live id> on every row, put a preview-shaped URL under
    # a label saying 'live', and the block's reader is a colleague who checks the URL's shape and not its
    # id. So the URL stays one they recognise, and the label beside a result link carries the caveat in
    # words: before the release, open these in a private window.
    $liveUrls = @()
    if ($PathArg -and @($PathArg).Count -gt 0) {
        . (Join-Path $PSScriptRoot '..\lib\market-urls.ps1')
        $liveUrls = @(Get-MarketUrls -Path $PathArg)
        Write-Host "  live urls: $($liveUrls.Count) ($(@($PathArg).Count) page(s) x markets), bare" -ForegroundColor DarkGray
    } else {
        Write-Host "  live urls: none -- no -Path given" -ForegroundColor DarkGray
    }
} else {
    Write-Host "  research : nothing goes live -- no release day, version or live URLs (-Research)" -ForegroundColor DarkGray
}

# --- The issue: store-admin prerequisites and the Asana link ------------------------------------------
# THE CHECKLIST IS READ FROM THE ISSUE, ITS BODY AND ITS COMMENTS (#2885, Dave, October 7, 2026): the one
# record that still exists at the close, after the fold has removed the branch document. Read only where
# the block is about to leave this console -- -OutFile, which the preview handover page embeds, and -Post
# -- so a print-only run stays the local, offline thing it has always been. Each moment does what the
# owner decided for it: the handover warns, the post refuses.
#
# THE SAME READ ANSWERS WHETHER THE CLOSE WILL CARRY THE BLOCK AT ALL (#2918), so it comes before the block
# is built: the lead sentence depends on it. asana-closed-message finds the task with Resolve-AsanaTaskRef
# on the issue BODY and posts nothing on 'none' or 'ambiguous', so the same matcher on the same field is
# asked here. Measured on BWJ-Development/xoxowildhearts#404, an Asana-originated issue whose body named
# the task only in prose: the block promised 'no paste needed', and the requester would have heard nothing.
#
# The item text is the issue's, so it is printed through ConvertTo-ConsoleStrippedText; it is decoded with
# the console code page here, which can cost an accent on screen and never the tick state, which is ASCII.
$prereqOpen   = @()
$prereqUnread = $false
$asanaRef     = $null
if ($PostArg -or $OutFileArg) {
    # A gh that is missing or throws is an unreadable issue, not a dead run: -OutFile must still write.
    $issueJson = $null
    try { $issueRun = Invoke-Native { gh issue view $issueNumber --repo $StoreRepo --json body,comments } }
    catch { $issueRun = [pscustomobject]@{ Output = @(); Code = 1 } }
    if ($issueRun.Code -eq 0 -and $issueRun.Output.Count -gt 0) {
        try { $issueJson = ($issueRun.Output -join "`n") | ConvertFrom-Json } catch { $issueJson = $null }
    }
    if ($issueJson) {
        $issueTexts = @([string]$issueJson.body) + @(@($issueJson.comments) | ForEach-Object { [string]$_.body })
        $prereqOpen = @(Get-StoreAdminPrerequisites -Text $issueTexts | Where-Object { -not $_.Done })
        $asanaRef   = Resolve-AsanaTaskRef -IssueBody ([string]$issueJson.body)
    } else {
        $prereqUnread = $true
    }
}

# 'linked' on a print-only run, which reads nothing and leaves the console as its only reader; 'unchecked'
# on an issue that could not be read, whose post only -Force reaches, so the lead it posts promises nothing
# it has no evidence for.
$asanaLink = 'linked'
if ($prereqUnread) { $asanaLink = 'unchecked' }
if ($asanaRef -and @('none', 'ambiguous') -contains $asanaRef.Source) { $asanaLink = $asanaRef.Source }
if ($asanaRef -and $asanaLink -eq 'linked') {
    Write-Host "  asana    : task $($asanaRef.Gid) (found by $($asanaRef.Source)) -- the closed message will carry the block" -ForegroundColor DarkGray
} elseif ($asanaRef) {
    Write-Host "  asana    : $($asanaRef.Source.ToUpper()) -- the closed message will carry nothing into Asana" -ForegroundColor Yellow
} elseif ($prereqUnread) {
    Write-Host "  asana    : not checked -- the issue could not be read" -ForegroundColor DarkGray
} else {
    Write-Host "  asana    : not checked -- a print-only run reads nothing; -OutFile and -Post check the link" -ForegroundColor DarkGray
}

# --- The block ----------------------------------------------------------------------------------------
if ($ResearchArg) {
    $block = Format-GoLiveResearchBlock -Marker (Get-AsanaPasteBlockMarker) -ResearchMarker (Get-AsanaResearchBlockMarker) `
        -IssueRef $targetRef -Outcome $prose.Outcome -Language $LanguageArg -AsanaLink $asanaLink
} else {
    $block = Format-GoLiveBlock -Marker (Get-AsanaPasteBlockMarker) -IssueRef $targetRef `
        -GoLiveDate $goLiveText -ResultLink $LinkArg -Version $resolvedVersion -LiveUrl $liveUrls `
        -Language $LanguageArg -Changed $prose.Changed -WhereToLook $prose.WhereToLook -NotIncluded $prose.NotIncluded `
        -AsanaLink $asanaLink -Live:$isLive -ReleaseMarker (Get-AsanaReleaseBlockMarker)
}

Write-Host ""
Write-Host $block
Write-Host ""

# What an unlinked issue is told, in both the warning and the refusal: the two remedies, by name.
$asanaRemedy = if ($asanaLink -eq 'ambiguous') {
    "it links $(@($asanaRef.Candidates).Count) Asana tasks ($(@($asanaRef.Candidates) -join ', ')) and the closed message will not guess. Put '<!-- asana-task: <gid> -->' for the right one in the issue body"
} else {
    "its body carries no '<!-- asana-task: <gid> -->' marker, '| **Asana** |' row or Asana task URL. Add the marker (report-issue step 3)"
}

# UTF-8 WITHOUT A BOM, for both files below: the block is the colleague's language, and a BOM would
# arrive in a pasted comment as an invisible first character.
$utf8 = New-Object System.Text.UTF8Encoding $false
if ($OutFileArg) {
    try {
        [System.IO.File]::WriteAllText([System.IO.Path]::GetFullPath($OutFileArg), $block, $utf8)
    } catch {
        Write-Host "[ERROR] -OutFile '$OutFileArg' could not be written: $(ConvertTo-ConsoleStrippedText -Text $_.Exception.Message) Nothing posted." -ForegroundColor Red
        exit 1
    }
    Write-Host "  written  : $OutFileArg (UTF-8 -- the faithful copy; the console above may have lost characters)" -ForegroundColor DarkGray
    # THE HANDOVER WARNS, AND DOES NOT REFUSE: a reviewer may well look before the store is set up, and
    # the page then says so above the cards (PREVIEW-portable.md, the shape of the handover).
    if ($prereqOpen.Count -gt 0) {
        Write-Host "[WARNING] $($prereqOpen.Count) store-admin prerequisite(s) on $targetRef still open -- put them on the" -ForegroundColor Yellow
        Write-Host "          handover page above the cards; -Post refuses until each is ticked on the issue:" -ForegroundColor Yellow
        foreach ($p in $prereqOpen) { Write-Host "            - [ ] $(ConvertTo-ConsoleStrippedText -Text $p.Item)" -ForegroundColor Yellow }
    } elseif ($prereqUnread) {
        Write-Host "[WARNING] Could not read $targetRef, so its store-admin prerequisites are unchecked." -ForegroundColor Yellow
    }
    if ($asanaLink -ne 'linked') {
        Write-Host "[WARNING] $targetRef will carry nothing into Asana when it closes: $asanaRemedy," -ForegroundColor Yellow
        Write-Host "          or decide the issue is GitHub-only. -Post refuses until then." -ForegroundColor Yellow
    }
}

if (-not $ResearchArg -and @($prose.Changed).Count -eq 0) {
    Write-Host "[WARNING] No [changed] section in -ProseFile, so the block does not say what changed -- the" -ForegroundColor Yellow
    Write-Host "          first thing its reader looks for. That prose is the session's to write, not the script's." -ForegroundColor Yellow
}
if (-not $ResearchArg -and -not $LinkArg) {
    Write-Host "[WARNING] No -Link given, so the block names no result to look at. It writes no" -ForegroundColor Yellow
    Write-Host "          placeholder on purpose -- pass -Link once you know where the result can be seen." -ForegroundColor Yellow
}

if (-not $PostArg) {
    Write-Host "Printed only. Re-run with -Post to put it on $targetRef, then close the issue." -ForegroundColor DarkGray
    return
}

# --- Posting ------------------------------------------------------------------------------------------
# THE STATE CHECK IS A WARNING, NOT A REFUSAL. The rule is that the block goes on while the issue is
# still open, because nobody returns to a closed one -- but a session that got there late is better off
# posting than not.
$stateRun = Invoke-Native { gh issue view $issueNumber --repo $StoreRepo --json state -q .state }
if ($stateRun.Code -eq 0 -and $stateRun.Output.Count -gt 0 -and ([string]$stateRun.Output[0]).Trim() -eq 'CLOSED') {
    Write-Host "[WARNING] $targetRef is already closed. The block belongs on it while it is OPEN -- nobody" -ForegroundColor Yellow
    Write-Host "          returns to a closed issue, which is why the order is the rule. Posting anyway." -ForegroundColor Yellow
}

# AN OPEN STORE-ADMIN PREREQUISITE REFUSES THE POST (#2885): the block tells a colleague to go and look,
# and what they would look at is not there yet. An unreadable issue refuses too, for the duplicate check's
# reason -- a run that cannot check does not post blindly. -Force is the one valve, as it is below.
if (-not $ForceArg -and ($prereqUnread -or $prereqOpen.Count -gt 0)) {
    if ($prereqUnread) {
        Write-Host "[ERROR] Could not read $targetRef, so its store-admin prerequisites are unchecked." -ForegroundColor Red
    } else {
        Write-Host "[ERROR] $targetRef has $($prereqOpen.Count) store-admin prerequisite(s) still open:" -ForegroundColor Red
        foreach ($p in $prereqOpen) { Write-Host "          - [ ] $(ConvertTo-ConsoleStrippedText -Text $p.Item)" -ForegroundColor Red }
        Write-Host "        Do them on the store and tick them on the issue first." -ForegroundColor Red
    }
    Write-Host "        Nothing posted. Re-run with -Force to post regardless." -ForegroundColor Red
    exit 1
}

# AN ISSUE THAT LINKS NO TASK REFUSES THE POST (#2918): this is the last tool to touch the issue before it
# closes, so it is the cheapest point to catch a link that would otherwise turn into a silent drop on the
# Asana side. -Force is for an issue that is deliberately GitHub-only; the lead already says so truthfully.
if (-not $ForceArg -and $asanaLink -ne 'linked') {
    Write-Host "[ERROR] $targetRef will carry nothing into Asana when it closes: $asanaRemedy," -ForegroundColor Red
    Write-Host "        then run this again. Nothing posted. Re-run with -Force for an issue that is GitHub-only." -ForegroundColor Red
    exit 1
}

# THE WORK MUST BE IN A PULL REQUEST BEFORE THE BLOCK IS POSTED (#2930). The block says 'is now closed' and
# names a release day, so it is true only once the work is on its way to the trunk; at the preview it is a
# closed message on an unfinished issue. -OutFile is not held back -- the handover page embeds the block --
# only the post is. Read through GraphQL, because 'gh issue view' gives the closing PRs without their state.
# A PR that only REFERENCES the issue counts as well (#2957): an Asana-linked issue ships with -NoResolves by
# this plugin's own rule, so its PR never closes it. Get-GoLiveLandingNodes reads both, same repo only.
# An unreadable answer refuses too, for the reason the checks above do; -Force is the deliberate early post.
# A RESEARCH BLOCK SKIPS IT (#3004): a ticket that changed nothing has no pull request to wait for, and its
# block says 'nothing has changed' rather than naming a release day.
if (-not $ForceArg -and -not $ResearchArg) {
    $landingState = 'unread'
    $repoParts = $StoreRepo -split '/', 2
    if ($repoParts.Count -eq 2) {
        $landingQuery = 'query($owner:String!,$name:String!,$num:Int!){repository(owner:$owner,name:$name){issue(number:$num){' +
            'closedByPullRequestsReferences(first:20,includeClosedPrs:true){nodes{number state}} ' +
            'timelineItems(itemTypes:[CROSS_REFERENCED_EVENT],last:50){nodes{... on CrossReferencedEvent{source{... on PullRequest{number state repository{nameWithOwner}}}}}}}}}'
        $landingRun = Invoke-Native { gh api graphql -f "query=$landingQuery" -f "owner=$($repoParts[0])" -f "name=$($repoParts[1])" -F "num=$issueNumber" }
        if ($landingRun.Code -eq 0 -and $landingRun.Output.Count -gt 0) {
            try {
                $landingJson = ($landingRun.Output -join "`n") | ConvertFrom-Json
                $landingState = Get-GoLivePostReadiness -Nodes @(Get-GoLiveLandingNodes -IssueData $landingJson.data.repository.issue -Repo $StoreRepo)
            } catch { $landingState = 'unread' }
        }
    }
    if ($landingState -eq 'none' -or $landingState -eq 'unread') {
        if ($landingState -eq 'unread') {
            Write-Host "[ERROR] Could not read which pull requests close or reference $targetRef, so whether its work has landed is unchecked." -ForegroundColor Red
        } else {
            Write-Host "[ERROR] No open or merged pull request closes or references $targetRef, so the block's 'is now closed' and its" -ForegroundColor Red
            Write-Host "        release day would not be true yet. Post it at the PR step: after the owner's look on a visible result, once" -ForegroundColor Red
            Write-Host "        the PR naming #$issueNumber is open -- 'Closes #$issueNumber', or the issue cited under -NoResolves for an" -ForegroundColor Red
            Write-Host "        Asana-linked one. At the preview, -OutFile gives the handover page its copy." -ForegroundColor Red
        }
        Write-Host "        Nothing posted. Re-run with -Force for a deliberate early post." -ForegroundColor Red
        exit 1
    }
    Write-Host "  landing  : a pull request closing or referencing $targetRef is $landingState" -ForegroundColor DarkGray
}

# Test-AsanaPasteBlockPosted answers TRUE where it cannot READ the comments, so a blind duplicate is
# never posted; an unreadable issue is reported as exactly that and -Force is the way past it. It counts
# only blocks posted after the issue's last reopen (#2968): the one the previous round left is not a
# duplicate of this round's block, it is the stale block this post replaces.
if ((Test-AsanaPasteBlockPosted -IssueRef $targetRef) -and -not $ForceArg) {
    Write-Host "[ERROR] A paste-ready block already appears to be on $targetRef for the current round -- or its" -ForegroundColor Red
    Write-Host "        comments could not be read, which answers the same way. Nothing posted. Re-run with -Force." -ForegroundColor Red
    exit 1
}

# Body through a FILE, never as an inline argument -- a shell mangles embedded newlines and quoting
# silently rather than loudly -- and not through stdin either (#2507): Windows PowerShell 5.1 encodes a
# pipe into a native command with $OutputEncoding, ASCII there, so every accent and dash in the
# colleague's language arrived on the issue as '?'. A UTF-8 file is read by gh byte for byte.
$bodyFile = Join-Path ([System.IO.Path]::GetTempPath()) "golive-block-$PID-$([guid]::NewGuid().ToString('n')).md"
$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    [System.IO.File]::WriteAllText($bodyFile, $block, $utf8)
    & gh issue comment $issueNumber --repo $StoreRepo --body-file $bodyFile 2>$null | Out-Null
    $postCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $prevEap
    Remove-Item -LiteralPath $bodyFile -Force -ErrorAction SilentlyContinue
}
if ($postCode -ne 0) {
    Write-Host "[ERROR] Posting the comment on $targetRef failed (gh exit $postCode)." -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Block posted on $targetRef." -ForegroundColor Green
if ($asanaLink -eq 'linked') {
    Write-Host "     Now close the issue as completed. The closed message carries the block into the Asana task -- no paste needed." -ForegroundColor DarkGray
} elseif ($asanaLink -eq 'unchecked') {
    Write-Host "     Now close the issue as completed. Its Asana link could not be checked -- confirm the body carries the asana-task marker first." -ForegroundColor DarkGray
} else {
    Write-Host "     Now close the issue as completed. It links no single Asana task, so nothing reaches Asana -- paste it there by hand if anyone waits on it." -ForegroundColor DarkGray
}
