<#
.SYNOPSIS
    Build the paste-ready block for a GitHub issue, including its go-live half: where the result can
    be seen, when it is planned to go live, which version it is on course for, and the live
    storefront URLs per market.

.DESCRIPTION
    Issue #2100 (Dave, September 18, 2026). WORKFLOW-portable.md's paste-ready block answered 'where
    can I see it' and stopped there; the requester's next question is always 'and when do I actually
    see it'. This script writes the whole block -- the marker, the framing sentence that stays on
    GitHub, and the paragraph between the two '---' rules that a person pastes into the Asana task.

    IT IS THE ROUTE, NOT THE BACKSTOP. asana-mirror.ps1 still posts a placeholder block where an
    Asana-linked issue closed without one, and it writes [ADD LINK] because CI genuinely cannot know
    the link. This script runs in the session that shipped the work, which does know it -- so it
    never writes a placeholder: a link it was not given is a sentence it does not write.

    WHAT IT NEVER DOES: touch Asana. The block reaches the task because a person pastes it, and
    closing the issue is their confirmation that it landed there -- the one decision this chapter
    deliberately keeps with the colleague who asked for the work. A script also cannot reach the
    Asana MCP, so the alternative was never on offer.

    THE THREE GO-LIVE FACTS AND WHERE EACH COMES FROM:

      the date     the next release day, strictly after today. BWJ cuts on a Monday, which is the
                   default; -ReleaseDay is there for a repo on another cadence.
      the version  the newest vX.Y.Z tag, stepped by the bump the changelog's pending tally already
                   names. Not re-derived from the entries: the fold computes that number and writes
                   it into the document, and the tier parser that produces it lives in dkj-policy's
                   libs, which this plugin's scripts may not reach.
      the URLs     Get-MarketUrls over the pages -Path names, from the same market table a preview
                   pair is built from -- PINNED TO THE LIVE THEME ID where one resolves (#2477), since
                   a bare URL renders the preview in any browser that opened the result link first.

    THE BLOCK IS WRITTEN IN THE COLLEAGUE'S LANGUAGE, IN THE SHAPE BWJ SENDS (#2507). -Language picks
    the words (Dutch by default: BWJ's board is Dutch); the sections are the reference block's -- what
    changed, where to look, when it goes live, what is deliberately not in it, what we ask. The facts
    above are the script's; the prose sections are the session's, handed in through -ProseFile.

    AND IT KEEPS THOSE CHARACTERS INTACT ON THE WAY OUT. Windows PowerShell 5.1 pipes a string into a
    native command through $OutputEncoding, which is ASCII there, so piping the block into gh turned
    every accent and dash into '?'. The post therefore goes through a UTF-8 file, and -OutFile writes
    the same bytes for a caller that embeds the block elsewhere -- the console printout is for reading,
    and a console code page may not carry every character.

    EVERY ONE OF THEM IS A PROJECTION AND THE BLOCK SAYS 'Planned to', never 'will'. A tier-1 entry
    landing on the Friday turns a predicted patch into a minor, and a release can slip. Where a fact
    cannot be derived it is left out rather than guessed -- see golive-block-rules.ps1's header.

    WHY IT DOT-SOURCES templates/asana-mirror.ps1. For Get-AsanaPasteBlockMarker and
    Test-AsanaPasteBlockPosted alone -- the marker the backstop's de-duplication matches on, and the
    read that answers whether a block is already there. Holding a second spelling of that marker here
    is exactly how the backstop would start posting a duplicate under a block this script had already
    written. That file documents itself as safe to dot-source for its pure helpers (its main flow runs
    only when invoked directly), which the source repo's suite already relies on. Its own parameters
    are captured out of the way first, the same guard build-backlog-page.ps1 states.

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

.PARAMETER LiveThemeId
    The live theme's id, to pin the live URLs to. Defaults to the repo's Get-ShopifyLiveThemeId seam
    (Get-ControlThemeId in market-urls.ps1). Where neither answers, the URLs stay bare and the block's
    label says how to read them before the release.

.PARAMETER Version
    Override the predicted version, or supply one where it cannot be derived (no v* tag, a changelog
    whose tally has been translated, a major somebody has decided to cut).

.PARAMETER ReleaseDay
    The weekday releases are cut on. Monday, which is BWJ's cadence.

.PARAMETER From
    The day the next release day is counted from. Today, unless a test or a caller says otherwise.

.PARAMETER Language
    The language of the Asana task, which is the language of the block between the rules: 'nl' (the
    default) or 'en'. The framing sentence above the rules stays English -- it is read on GitHub.

.PARAMETER ProseFile
    A UTF-8 text file with the session's own prose for the block, under section lines '[changed]',
    '[where]' and '[not-included]' (ConvertFrom-GoLiveProse). Omitted, those sections are not written,
    and the run warns that the block does not say what changed.

.PARAMETER OutFile
    Also write the whole comment to this path as UTF-8 -- the faithful copy for a page that embeds the
    block, where the console printout may have lost characters to its code page.

.PARAMETER Post
    Also post the block as a comment on the issue. Without it the block is printed and nothing is
    written anywhere.

.PARAMETER Force
    Post even though a paste-ready block already appears to be on the issue, or the check could not
    read its comments.

.PARAMETER RootOverride
    The repo root, when this is not run from inside the checkout.

.EXAMPLE
    ./build-golive-block.ps1 -Issue 412 -Link "https://store.example/products/foo?preview_theme_id=123&_ab=0&_fd=0&_sc=1"
    Prints the block for issue 412, with the date and version derived from this repo.

.EXAMPLE
    ./build-golive-block.ps1 -Issue 412 -Link https://... -Path /collections/straps -Post
    Adds one live URL per market for that page, and posts the block on the issue.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Issue,
    [string]$Repo,
    [string]$Link,
    [string[]]$Path,
    [string]$LiveThemeId,
    [string]$Version,
    [System.DayOfWeek]$ReleaseDay = [System.DayOfWeek]::Monday,
    [datetime]$From = (Get-Date),
    [ValidateSet('nl', 'en')][string]$Language = 'nl',
    [string]$ProseFile,
    [string]$OutFile,
    [switch]$Post,
    [switch]$Force,
    [switch]$AllowPrivateLink,
    [string]$RootOverride
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Captured BEFORE the template dot-source below rebinds $Repo to its own default -- see the
# .DESCRIPTION's "WHY IT DOT-SOURCES" paragraph, and build-backlog-page.ps1's identical guard.
$StoreRepo   = if ($Repo) { $Repo } else { $env:GITHUB_REPOSITORY }
$IssueArg    = $Issue
$LinkArg     = $Link
$PathArg     = $Path
$LiveThemeIdArg = $LiveThemeId
$VersionArg  = $Version
$ReleaseDayArg = $ReleaseDay
$FromArg     = $From
$LanguageArg = $Language
$ProseArg    = $ProseFile
$OutFileArg  = $OutFile
$PostArg     = [bool]$Post
$ForceArg    = [bool]$Force
$RootArg     = $RootOverride

. (Join-Path $PSScriptRoot '..\..\templates\asana-mirror.ps1')
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
# pasted into the Asana task, so a warning under it would travel nowhere the requester looks (#2341).
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
$prose = @{ Changed = @(); WhereToLook = @(); NotIncluded = @() }
if ($ProseArg) {
    if (-not (Test-Path -LiteralPath $ProseArg -PathType Leaf)) {
        Write-Host "[ERROR] -ProseFile '$ProseArg' does not exist. Nothing written." -ForegroundColor Red
        exit 1
    }
    try {
        $prose = ConvertFrom-GoLiveProse -Text ([System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $ProseArg).ProviderPath, [System.Text.Encoding]::UTF8))
    } catch {
        Write-Host "[ERROR] -ProseFile: $($_.Exception.Message) Nothing written." -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "== build-golive-block $targetRef ==" -ForegroundColor Cyan

# --- The date ---------------------------------------------------------------------------------------
$goLive     = Get-NextReleaseDate -From $FromArg -ReleaseDay $ReleaseDayArg
$goLiveText = Format-GoLiveDate -Date $goLive -Language $LanguageArg
Write-Host "  go live  : $goLiveText" -ForegroundColor DarkGray

# --- The version ------------------------------------------------------------------------------------
# THE TAG IS THE RECORD OF THE LAST CUT IN EVERY REPO RUNNING THIS WORKFLOW, whether or not it
# publishes plugins -- cut-release always tags. The lockstep read that script also makes exists to PROVE
# the manifests agree, which is a release gate's question and not a message generator's.
$resolvedVersion = $VersionArg
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
        $resolvedVersion = Step-SemVer -Current ($latestTag -replace '^v', '') -Bump $bump
        $versionWhy      = "$latestTag stepped by the '$bump' the pending tally names"
    } else {
        # NAMED RATHER THAN SUMMARISED, because the two causes have two different remedies: cut a tag,
        # or answer -Version because the tally cannot be read.
        $missing = @()
        if (-not $latestTag) { $missing += 'no v* tag' }
        if (-not $bump)      { $missing += 'no readable pending tally' }
        $versionWhy = 'not derived -- ' + ($missing -join ', ')
    }
}
Write-Host "  version  : $(if ($resolvedVersion) { "v$resolvedVersion" } else { '(none)' })  [$versionWhy]" -ForegroundColor DarkGray

# --- The live URLs ----------------------------------------------------------------------------------
# ONLY WHERE -Path SAYS SO. A block with no pages named carries no list, which is the correct answer in
# a repo that serves no storefront -- and Get-MarketUrls is left unloaded there rather than being called
# and caught, so a repo with no markets is never asked a question it has no answer to.
#
# PINNED TO THE LIVE THEME ID WHERE ONE RESOLVES (#2477). The result link is normally a storefront
# preview, and the bare URL renders that preview on any domain where it was opened first -- so a
# requester comparing the two tabs before the release can conclude the change is already live. A URL
# naming the live id is a true comparison now and the live page after the release, because a live push
# keeps the theme's id. Get-ControlThemeId throws rather than guess; that throw is caught HERE only,
# because an unpinned list is still a correct list once it is live -- the block's label says the rest.
$liveUrls   = @()
$livePinned = $false
if ($PathArg -and @($PathArg).Count -gt 0) {
    . (Join-Path $PSScriptRoot '..\lib\market-urls.ps1')
    # THE CAUGHT MESSAGE IS PRINTED, NOT REPLACED. A seam that exists and throws -- an expired token, a
    # bug in the store's own function -- is a different fault from a seam nobody declared, and one
    # generic hint would name the wrong remedy for it.
    $liveId    = ''
    $liveError = ''
    try { $liveId = Get-ControlThemeId -LiveThemeId $LiveThemeIdArg } catch { $liveError = $_.Exception.Message }
    if ($liveId) {
        $liveUrls   = @(Get-MarketPreviewUrls -ThemeId $liveId -Path $PathArg)
        $livePinned = $true
    } else {
        $liveUrls = @(Get-MarketUrls -Path $PathArg)
    }
    $pinNote = if ($livePinned) { "pinned to live theme $liveId" } else { 'bare -- no live theme id' }
    Write-Host "  live urls: $($liveUrls.Count) ($(@($PathArg).Count) page(s) x markets), $pinNote" -ForegroundColor DarkGray
    if ($liveError) {
        Write-Host "[WARNING] The live URLs are not pinned: $liveError" -ForegroundColor Yellow
        Write-Host "          The block labels them for that, so it stays correct -- but a bare URL is the weaker link." -ForegroundColor Yellow
    }
} else {
    Write-Host "  live urls: none -- no -Path given" -ForegroundColor DarkGray
}

# --- The block ----------------------------------------------------------------------------------------
$block = Format-GoLiveBlock -Marker (Get-AsanaPasteBlockMarker) -IssueRef $targetRef `
    -GoLiveDate $goLiveText -ResultLink $LinkArg -Version $resolvedVersion -LiveUrl $liveUrls -LivePinned:$livePinned `
    -Language $LanguageArg -Changed $prose.Changed -WhereToLook $prose.WhereToLook -NotIncluded $prose.NotIncluded

Write-Host ""
Write-Host $block
Write-Host ""

# UTF-8 WITHOUT A BOM, for both files below: the block is the colleague's language, and a BOM would
# arrive in a pasted comment as an invisible first character.
$utf8 = New-Object System.Text.UTF8Encoding $false
if ($OutFileArg) {
    [System.IO.File]::WriteAllText([System.IO.Path]::GetFullPath($OutFileArg), $block, $utf8)
    Write-Host "  written  : $OutFileArg (UTF-8 -- the faithful copy; the console above may have lost characters)" -ForegroundColor DarkGray
}

if (@($prose.Changed).Count -eq 0) {
    Write-Host "[WARNING] No [changed] section in -ProseFile, so the block does not say what changed -- the" -ForegroundColor Yellow
    Write-Host "          first thing its reader looks for. That prose is the session's to write, not the script's." -ForegroundColor Yellow
}
if (-not $LinkArg) {
    Write-Host "[WARNING] No -Link given, so the block names no result to look at. It writes no" -ForegroundColor Yellow
    Write-Host "          placeholder on purpose -- pass -Link once you know where the result can be seen." -ForegroundColor Yellow
}

if (-not $PostArg) {
    Write-Host "Printed only. Re-run with -Post to put it on $targetRef, then paste the block between the" -ForegroundColor DarkGray
    Write-Host "'---' rules into the Asana task -- and close the issue once it is there." -ForegroundColor DarkGray
    return
}

# --- Posting ------------------------------------------------------------------------------------------
# THE STATE CHECK IS A WARNING, NOT A REFUSAL. The rule is that the block goes on while the issue is
# still open, because nobody returns to a closed one -- but a session that got there late is better off
# posting than not, and the backstop's own placeholder copy is what it would otherwise be left with.
$stateRun = Invoke-Native { gh issue view $issueNumber --repo $StoreRepo --json state -q .state }
if ($stateRun.Code -eq 0 -and $stateRun.Output.Count -gt 0 -and ([string]$stateRun.Output[0]).Trim() -eq 'CLOSED') {
    Write-Host "[WARNING] $targetRef is already closed. The block belongs on it while it is OPEN -- nobody" -ForegroundColor Yellow
    Write-Host "          returns to a closed issue, which is why the order is the rule. Posting anyway." -ForegroundColor Yellow
}

# Test-AsanaPasteBlockPosted answers TRUE where it cannot READ the comments -- the safe default for the
# CI backstop, whose mistake would be a blind duplicate. Here the cost runs the other way, so an
# unreadable issue is reported as exactly that and -Force is the way past it.
if ((Test-AsanaPasteBlockPosted -IssueRef $targetRef) -and -not $ForceArg) {
    Write-Host "[ERROR] A paste-ready block already appears to be on $targetRef -- or its comments could" -ForegroundColor Red
    Write-Host "        not be read, which answers the same way. Nothing posted. Re-run with -Force." -ForegroundColor Red
    exit 1
}

# Body through a FILE, never as an inline argument -- a shell mangles embedded newlines and quoting
# silently rather than loudly -- and not through stdin either (#2507): Windows PowerShell 5.1 encodes a
# pipe into a native command with $OutputEncoding, ASCII there, so every accent and dash in the
# colleague's language arrived on the issue as '?'. A UTF-8 file is read by gh byte for byte.
# Add-GithubIssueComment beside it is not reused because its own success line is the backstop's
# ("the session that shipped the work did not"), and this IS that session.
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
Write-Host "     Now paste the block between the '---' rules into the Asana task, and close the issue" -ForegroundColor DarkGray
Write-Host "     once it is there -- that close is your confirmation that it reached the requester." -ForegroundColor DarkGray
