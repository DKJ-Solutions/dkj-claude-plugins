<#
.SYNOPSIS
    Tests for scripts/release/build-release-notes-page.ps1 -- the browsable page built from the
    hand-written release notes, and the Cloudflare Worker that serves it.

.DESCRIPTION
    IT TESTS THE GENERATED PAGE, NOT THE SCRIPT'S INTERNALS, and that is deliberate rather than
    stylistic. The consumer this capability was ported from found its live-marker bug exactly that
    way: the script was internally consistent and the page pointed at three live versions. So the
    asserts here parse the data block out of the output and ask it questions a reader would ask.

    What is covered, and why these:
      1. the page is built from the HISTORY TABLE -- order, date, type and title come from there,
         which is the only thing that knows them;
      2. the live marker is matched case-sensitively, the bug that consumer paid for: a release
         whose TITLE merely contains the word 'live' must not mark itself;
      3. a release with no note is skipped rather than rendered empty, and the two kinds of absence
         are reported differently (a gap inside the covered range is named, older ones are counted);
      4. a note containing a closing script tag cannot end the page's data block early -- the
         failure that renders an empty page with nothing erroring;
      5. the grouping seam really is read, so a repo foldering per minor is not silently given an
         empty page;
      6. the path token is an INPUT: -Worker refuses without one instead of inventing one, and
         -InitToken refuses to replace one. That refusal is the whole safety property, because an
         invented token means every link already sent 404s while everything reports success;
      7. wrangler.toml is written once and never overwritten, since a consumer edits it -- and the
         one write that CANNOT honour that promise, because there was nothing there to overwrite,
         says so instead of reporting itself as routine (issue #1479).

    Fixture paths carry $PID: the test gate is a throttled PARALLEL scheduler, so two runs at one
    fixed temp path tear down each other's tree mid-assert.

    EVERY ASSERT ON A REFUSAL GOES THROUGH Assert-Says, NEVER Assert-Match (issue #1723). A `throw`
    and a `Write-Warning` reach the capture through PowerShell's error formatter, which hard-wraps at
    the host's buffer column -- inside a word, not at a space -- so the phrase the script composed is
    not the phrase the capture carries. That is what made case 7's ordering assert red under a
    30-lane gate and green standalone, and it is the same mechanism issue #1512 recorded for the
    suites that already had this helper. `Write-Host` is unaffected and those asserts are left alone;
    which is which is decided by reading the emitting call, not by guessing from the wording.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Script   = Join-Path $RepoRoot 'scripts\release\build-release-notes-page.ps1'
$Fixture  = Join-Path ([System.IO.Path]::GetTempPath()) "release-notes-page-test-fixture-$PID-$([guid]::NewGuid().ToString('n'))"

. (Join-Path $RepoRoot 'scripts\lib\native-capture-lib.ps1')

$script:pass = 0
$script:fail = 0
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Assert-Equal {
    param($Expected, $Actual, [string]$Name)
    if ($Expected -eq $Actual) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if ($Condition) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name" -ForegroundColor Red
    }
}

function Assert-Match {
    param([string]$Pattern, [string]$Text, [string]$Name)
    if ($Text -match $Pattern) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         pattern not found: '$Pattern'" -ForegroundColor Red
    }
}

function Test-Says {
    <# Does captured child output contain this phrase, whatever the console did to it?

       THE SAME MECHANISM AS ISSUE #1512, AT A SITE THAT NEVER GOT IT (issue #1723). Every refusal
       this suite asserts on reaches the capture through PowerShell's error formatter -- a `throw` or
       a `Write-Warning` -- and that formatter HARD-WRAPS at the host's buffer column, breaking
       INSIDE a word rather than at a space. Measured at width 120, this script's -Worker refusal
       came back as '... exhausted, -InitToken fo' + newline + 'r a fresh path ...', so the assert
       for that phrase was reading a text the phrase is not in. It passed anyway, on the
       FullyQualifiedErrorId echo further down the same rendering, which is a coincidence of
       arithmetic between the width and the length of a temp path. `Write-Host` is NOT affected: a 295-character line came
       back whole, which is why the Write-Host-fed asserts here are left as Assert-Match.

       THE COINCIDENCE IS MEASURED, NOT ARGUED, because "it depends on the width" is the kind of
       explanation that sounds sufficient and proves nothing. Holding the width fixed and sweeping the
       ONE quantity this suite actually varies -- the length of the interpolated token path, which
       moves with $PID's digit count here and with $env:TEMP on another machine -- over 130 values:
       9 of them fail the old assert, in ONE CONTIGUOUS BAND. A band is the signature; it is a wrap
       boundary sliding through a 27-character phrase, and it is why a green run on this machine was
       never evidence about a run on any other.

       WHAT IS NOT CLAIMED: that this is what tripped the one run in issue #1723. WHICH length that
       run hit was never identified -- $PID digit counts 3 to 7 all pass here at this width -- so
       something still unnamed differed (another machine's $env:TEMP, another width, a ship-pr run
       with no console of its own). The repair does not rest on it: an assert whose verdict moves
       with a temp path's length is broken whether or not that run is the one that proved it. Said
       out loud because the tempting sentence -- "so THAT is what went red" -- is one step further
       than the measurement goes, and a repair carrying a citation it has not earned is worse than
       one carrying none.

       Strips ALL whitespace from both sides. Normalizing '\s+' to a single space repairs a wrap
       BETWEEN words and does nothing for a wrap INSIDE one. Which asserts straddle a break is
       decided by the width, so a green run is not evidence.

       Literal (IndexOf), so a phrase carrying '(', ')', '.', '[' or ']' needs no escaping;
       OrdinalIgnoreCase keeps the case-insensitivity that -match had at these call sites. #>
    param([string]$Text, [string]$Phrase)
    return ((Get-SaysIndex -Text $Text -Phrase $Phrase) -ge 0)
}

function Get-SaysIndex {
    <# WHERE the phrase starts, in the whitespace-stripped text -- or -1.

       Two phrases' indexes are comparable because both are measured in that same stripped text, which
       is what the ordering assert in case 7 needs: the console's line breaks move every raw index and
       must not be allowed to decide which route the refusal names first. #>
    param([string]$Text, [string]$Phrase)
    $haystack = ($Text -replace '\s', '')
    $needle   = ($Phrase -replace '\s', '')
    return $haystack.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase)
}

function Assert-Says {
    param([string]$Text, [string]$Phrase, [string]$Name)
    if (Test-Says -Text $Text -Phrase $Phrase) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         wanted to find: '$Phrase'" -ForegroundColor Red
    }
}

function Write-FixtureFile {
    param([string]$Path, [string]$Content)
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

function New-FixtureRepo {
    <#
        A minimal consuming repo: a seam file, a history table and a note per release. The notes are
        deliberately small -- what is under test is the assembly, and the renderer runs in a browser
        rather than here.
    #>
    param(
        [string]$Label,
        [string]$Grouping = 'major',
        [string]$WorkerName = '',
        [switch]$OmitTitle,
        [switch]$NoteWithScriptTag,
        [string]$ThemeBody = '',
        [string]$MastheadBody = '',
        # The three shapes the second pass (inbound #811, #813, #816) has to be measured against, each
        # of which is a property of the SET rather than of one row: a page whose type never varies, a
        # page carrying a real patch note, and a note that does not open the way the generator writes.
        [switch]$UniformType,
        [switch]$WithPatchNote,
        [switch]$PlainNote,
        [switch]$TitleLineDrifted,
        [switch]$NoLiveMarker,
        # A consumer that leaves Get-ReleaseHistoryPath unanswered, so its history sits at the computed
        # default the cut writes to (#3243).
        [switch]$NoHistorySeam
    )
    $root = Join-Path $Fixture "repo-$Label"
    if (Test-Path -LiteralPath $root) { Remove-Item -Recurse -Force -LiteralPath $root }
    New-Item -ItemType Directory -Force -Path $root | Out-Null

    $titleFn = if ($OmitTitle) { '' } else { "function Get-ReleasePageTitle { return 'Fixture Product' }" }
    $config = @"
function Get-RepoName { return 'fixture-owner/fixture-repo' }
function Get-ReleaseNoteRoot { return 'releases/audience' }
function Get-ReleaseNotesGrouping { return '$Grouping' }
$(if ($NoHistorySeam) { '' } else { "function Get-ReleaseHistoryPath { return 'releases/README.md' }" })
function Get-ReleasePageWorkerName { return '$WorkerName' }
$titleFn
$(if ($ThemeBody) { "function Get-ReleasePageTheme { $ThemeBody }" } else { '' })
$(if ($MastheadBody) { "function Get-ReleasePageMasthead { $MastheadBody }" } else { '' })
"@
    Write-FixtureFile (Join-Path $root 'scripts\repo-config.ps1') $config

    # 2.1.0 has no note on purpose: it sits BETWEEN two releases that do, so it is the gap case.
    # 1.0.0 is older than every note, so it is the counted case.
    $history = @"
# Releases

#### 2.x

| Version | Date | Type | Title |
|---|---|---|---|
| [2.2.0](audience/2.x/2.2.0.md) | 2026-08-14 | Minor | The live push moved to a new stage |
| [$(if ($WithPatchNote) { '2.1.1' } else { '2.1.0' })](audience/2.x/$(if ($WithPatchNote) { '2.1.1' } else { '2.1.0' }).md) | 2026-08-12 | $(if ($UniformType) { 'Minor' } else { 'Patch' }) | A release with no note |
| [2.0.0](audience/2.x/2.0.0.md)$(if ($NoLiveMarker) { '' } else { ' <- **LIVE**' }) | 2026-08-10 | $(if ($UniformType) { 'Minor' } else { 'Major' }) | The first one |

#### 1.x

| Version | Date | Type | Title |
|---|---|---|---|
| [1.0.0](audience/1.x/1.0.0.md) | 2026-07-01 | Major | Older than any note |
"@
    $historyRel = if ($NoHistorySeam) { 'dkj-policy\releases\history.md' } else { 'releases\README.md' }
    Write-FixtureFile (Join-Path $root $historyRel) $history

    $folder = { param($v) if ($Grouping -eq 'minor') { ($v.Split('.')[0..1] -join '.') } else { "$($v.Split('.')[0]).x" } }
    $extra = if ($NoteWithScriptTag) { "`n`nA literal closing script tag follows: </script> and the page must survive it." } else { '' }
    # 2.1.1, not 2.1.0: the point of this variant is a version whose third digit is NOT zero, and a
    # x.y.0 would be trimmed exactly like the others.
    $noteVersions = if ($WithPatchNote) { @('2.2.0', '2.1.1', '2.0.0') } else { @('2.2.0', '2.0.0') }
    # The titles exactly as the history table above states them: the suppression matches on equality, so a
    # fixture that paraphrased them would assert the opposite of what it claims.
    $titles = @{ '2.2.0' = 'The live push moved to a new stage'; '2.1.1' = 'A release with no note'; '2.0.0' = 'The first one' }
    foreach ($v in $noteVersions) {
        # The generator's own shape: an H1 naming the version, then bold labels, then the body. -PlainNote
        # writes a note that opens some other way, which is the case the suppression must NOT touch.
        # THE TITLE LINE IS PART OF THE SHAPE, and the fixture has to carry it or the suppression of it is
        # asserted against a note that never had one. The generator writes the release title as a bare
        # paragraph under the metadata block, verbatim from the same table the row is built from.
        $noteTitle = $titles[$v]
        $note = if ($PlainNote) {
            "Body of $v.$extra"
        } elseif ($TitleLineDrifted) {
            "# Release notes v$v`n`n**Date:** x  `n**Type:** Minor  `n**For whom:** the organisation`n`nA title somebody edited by hand`n`nBody of $v.$extra"
        } else {
            "# Release notes v$v`n`n**Date:** x  `n**Type:** Minor  `n**For whom:** the organisation`n`n$noteTitle`n`nBody of $v.$extra"
        }
        Write-FixtureFile (Join-Path $root "releases\audience\$(& $folder $v)\$v.md") $note
    }
    return $root
}

function Invoke-Build {
    param([string]$Root, [string[]]$ScriptArgs = @())
    $all = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Script, '-RootOverride', $Root) + $ScriptArgs
    $r = Invoke-NativeCapture -FilePath 'powershell' -Arguments $all
    return [pscustomobject]@{ Code = $r.ExitCode; Out = (($r.Output | ForEach-Object { "$_" }) -join "`n") }
}

function Get-PageData {
    <# The data block the page carries, parsed -- the questions below are a reader's, not the script's. #>
    param([string]$PagePath)
    $html = [System.IO.File]::ReadAllText($PagePath, [System.Text.Encoding]::UTF8)
    $m = [regex]::Match($html, '(?s)<script type="application/json" id="release-data">(.*?)</script>')
    if (-not $m.Success) { throw "no data block in $PagePath" }
    return [pscustomobject]@{ Html = $html; Json = $m.Groups[1].Value; Data = ($m.Groups[1].Value | ConvertFrom-Json) }
}

function Get-ReleasePageData {
    <# One release's own page, parsed the same way: release-notes\v<version>.html beside the index. #>
    param([string]$Root, [string]$Version)
    return Get-PageData -PagePath (Join-Path $Root "releases\page\release-notes\v$Version.html")
}

try {
    Write-Host "== release-notes-page.tests: scripts/release/build-release-notes-page.ps1 ==" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $Fixture | Out-Null

    # --- 1. The page is built from the history table ----------------------------------------------
    Write-Host "build -- the history table is the source of order, date, type and title" -ForegroundColor Cyan
    $r1 = New-FixtureRepo -Label 'basic'
    $b1 = Invoke-Build -Root $r1
    Assert-Equal 0 $b1.Code 'basic: exit 0'

    $page1 = Join-Path $r1 'releases\page\release-notes.html'
    Assert-True (Test-Path -LiteralPath $page1) 'basic: the page is written beside the note root, in page/'
    $ignore1 = Join-Path $r1 'releases\page\.gitignore'
    Assert-True (Test-Path -LiteralPath $ignore1) 'basic: page/ carries a .gitignore of its own (#3431)'
    Assert-True (@(Get-Content -LiteralPath $ignore1) -contains '*') 'basic: and it ignores everything in page/'
    [System.IO.File]::WriteAllText($ignore1, "kept`n")
    $null = Invoke-Build -Root $r1
    Assert-Equal 'kept' ((Get-Content -LiteralPath $ignore1 -Raw).Trim()) 'basic: an existing page/.gitignore is left alone'

    $p1 = Get-PageData -PagePath $page1
    Assert-Equal 2 $p1.Data.documentCount 'basic: two releases carry a note'
    Assert-Equal '2.2.0' $p1.Data.releases[0].version 'basic: newest first, as the table reads'
    Assert-Equal '2.0.0' $p1.Data.releases[1].version 'basic: oldest last'
    Assert-Equal '2026-08-14' $p1.Data.releases[0].date 'basic: the date comes from the table'
    Assert-Equal 'Major' $p1.Data.releases[1].type 'basic: the type comes from the table'
    # THE BODY TRAVELS ON THE RELEASE'S OWN PAGE, not on the index (owner, October 25, 2026): every card
    # leads elsewhere, so a body on the index would be weight nobody reads.
    $rp1 = Get-ReleasePageData -Root $r1 -Version '2.2.0'
    Assert-Match 'Body of 2\.2\.0' $rp1.Data.releases[0].body 'basic: the note body travels into the release''s own page'
    Assert-Equal 1 $rp1.Data.documentCount 'basic: and that page carries its own note only'
    Assert-True ($p1.Json -notmatch '"body"') 'basic: the index carries no note body'
    Assert-Equal 2 @(Get-ChildItem -LiteralPath (Join-Path $r1 'releases\page\release-notes') -Filter 'v*.html').Count 'basic: one page per release that carries a note, in a folder named after the index'
    # THE SEAM IS THE EYEBROW AND HALF THE WINDOW TITLE; the heading is the template's own words (Dave,
    # August 21, 2026). It was the other way round for a day, and a repo whose title said what the page
    # was then printed those words twice -- which is what this repo's own answer did.
    Assert-Match '<span class="eyebrow">Fixture Product</span>' $p1.Html 'basic: Get-ReleasePageTitle is the eyebrow -- whose releases these are'
    Assert-Match '<h1>Release notes</h1>' $p1.Html 'basic: and the heading says what the document is, from the template'
    Assert-Match '<title>Fixture Product &middot; release notes</title>' $p1.Html 'basic: the window title joins them, where a tab has no duplication to make'
    Assert-True (-not ($p1.Html -match '@@[A-Z_]+@@')) 'basic: no template placeholder survives'

    # --- 2. The live marker, case-sensitively -----------------------------------------------------
    # THE BUG THE CONSUMER PAID FOR. 2.2.0's title is 'The live push moved to a new stage'; under
    # PowerShell's default case-insensitive -match it marks itself, and the page then claims two
    # live versions.
    Write-Host "build -- the live marker is matched case-sensitively" -ForegroundColor Cyan
    Assert-Equal $false $p1.Data.releases[0].live 'live: a title containing the word "live" does NOT mark itself'
    Assert-Equal $true  $p1.Data.releases[1].live 'live: the row carrying **LIVE** does'
    Assert-Equal 1 (@($p1.Data.releases | Where-Object { $_.live }).Count) 'live: exactly one release is live'

    # --- 3. A release without a note --------------------------------------------------------------
    Write-Host "build -- the two kinds of missing note are reported differently" -ForegroundColor Cyan
    Assert-True (-not (@($p1.Data.releases | Where-Object { $_.version -eq '2.1.0' }).Count)) 'skip: a release with no note is not on the page'
    Assert-Match '2\.1\.0' $b1.Out 'skip: a gap INSIDE the covered range is named'
    Assert-Match 'earlier\s*:\s*1 release' $b1.Out 'skip: releases older than the first note are counted, not named'

    # --- 4. A note that contains a closing script tag ---------------------------------------------
    # The silent failure: the data block ends early and the page renders empty, with nothing here
    # erroring. The script asserts on a raw '<' rather than trusting the serializer; this holds it to
    # that on real input.
    Write-Host "build -- a note cannot close the page's data block early" -ForegroundColor Cyan
    $r4 = New-FixtureRepo -Label 'scripttag' -NoteWithScriptTag
    $b4 = Invoke-Build -Root $r4
    Assert-Equal 0 $b4.Code 'scripttag: exit 0'
    $p4 = Get-PageData -PagePath (Join-Path $r4 'releases\page\release-notes.html')
    Assert-Equal 0 ([regex]::Matches($p4.Json, '<').Count) 'scripttag: no raw "<" survives into the data block'
    Assert-Equal 2 $p4.Data.documentCount 'scripttag: the page still parses and carries both releases'
    # The body is on the release's page, so that is the data block a closing script tag would end early.
    $rp4 = Get-ReleasePageData -Root $r4 -Version '2.2.0'
    Assert-Equal 0 ([regex]::Matches($rp4.Json, '<').Count) 'scripttag: no raw "<" survives into the release page''s data block either'
    Assert-Match 'closing script tag follows' $rp4.Data.releases[0].body 'scripttag: the text itself is preserved'

    # --- 5. The grouping seam is really read ------------------------------------------------------
    Write-Host "build -- Get-ReleaseNotesGrouping decides which folder is read" -ForegroundColor Cyan
    $r5 = New-FixtureRepo -Label 'minor' -Grouping 'minor'
    $b5 = Invoke-Build -Root $r5
    Assert-Equal 0 $b5.Code 'grouping: a repo foldering per minor builds'
    $p5 = Get-PageData -PagePath (Join-Path $r5 'releases\page\release-notes.html')
    Assert-Equal 2 $p5.Data.documentCount 'grouping: both notes found under <X.Y>/'

    # A repo whose seam disagrees with its tree finds nothing, and the error has to say which of the
    # two it looked for -- otherwise the reader is told only that something is empty.
    $r5b = New-FixtureRepo -Label 'mismatch'
    Write-FixtureFile (Join-Path $r5b 'scripts\repo-config.ps1') (
        ((Get-Content -LiteralPath (Join-Path $r5b 'scripts\repo-config.ps1') -Raw) -replace "return 'major'", "return 'minor'"))
    $b5b = Invoke-Build -Root $r5b
    Assert-Equal 1 $b5b.Code 'grouping mismatch: refuses rather than writing an empty page'
    Assert-Says $b5b.Out 'Get-ReleaseNotesGrouping' 'grouping mismatch: the error names the seam it read'

    # --- 6. The title fallback --------------------------------------------------------------------
    Write-Host "build -- the title falls back to the repo name" -ForegroundColor Cyan
    $r6 = New-FixtureRepo -Label 'notitle' -OmitTitle
    $b6 = Invoke-Build -Root $r6
    Assert-Equal 0 $b6.Code 'title fallback: exit 0'
    $p6 = Get-PageData -PagePath (Join-Path $r6 'releases\page\release-notes.html')
    Assert-Match '<title>fixture-repo &middot; release notes</title>' $p6.Html 'title fallback: the name half of Get-RepoName, not the owner/name pair'

    # --- 7. The path token is an input ------------------------------------------------------------
    # THE MATCHER FIRST, ON A STRING RATHER THAN ON A RUN (issue #1723). Every assert below reads a
    # `throw`, and a throw reaches the capture through PowerShell's error formatter, which breaks the
    # line MID-WORD at the host's width. That is what made the order assert further down red under the
    # 30-lane gate and green standalone. These three are deterministic and carry no console: the
    # wrapped literal is exactly what was measured coming back at width 120.
    Write-Host "worker -- the refusal is matched across a console wrap, not as the console laid it out" -ForegroundColor Cyan
    $wrapped = "rker's code view in the dashboard, or the Workers script API); (3) only once both of those are exhausted, -InitToken fo" + "`n" +
               "r a fresh path -- which 404s every link already sent."
    Assert-True ($wrapped.IndexOf('-InitToken for a fresh path') -lt 0) 'wrap: a mid-word break really does hide the phrase from IndexOf'
    Assert-Says $wrapped '-InitToken for a fresh path' 'wrap: and Test-Says reads it across the break'
    Assert-True (-not (Test-Says $wrapped 'a route this refusal never names')) 'wrap: while a phrase that is genuinely absent stays absent'

    Write-Host "worker -- the path token is never invented" -ForegroundColor Cyan
    $r7 = New-FixtureRepo -Label 'worker' -WorkerName 'fixture-release-notes'
    $pageDir7 = Join-Path $r7 'releases\page'

    $w1 = Invoke-Build -Root $r7 -ScriptArgs @('-Worker')
    Assert-Equal 1 $w1.Code 'token: -Worker without a token refuses'
    Assert-Says $w1.Out 'does NOT invent one' 'token: the refusal says why, not just that'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $pageDir7 'worker-path-token.txt'))) 'token: the refusal created no token'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $pageDir7 'worker.js'))) 'token: and no worker bundle'
    Assert-True (Test-Path -LiteralPath (Join-Path $pageDir7 'release-notes.html')) 'token: the page half still ran -- the refusal is the worker half only'

    $w2 = Invoke-Build -Root $r7 -ScriptArgs @('-Worker', '-InitToken')
    Assert-Equal 0 $w2.Code 'token: -InitToken creates one and the worker builds'
    # npx.cmd on Windows, where 'npx' resolves to npx.ps1 and the default execution policy blocks it;
    # and no '&&', which Windows PowerShell 5.1 cannot parse (#2651).
    $npx = if ($env:OS -eq 'Windows_NT') { 'npx.cmd' } else { 'npx' }
    Assert-Says $w2.Out "$npx wrangler deploy" "deploy: it names the deploy command as $npx"
    Assert-True ($w2.Out -notlike '*&&*') 'deploy: on lines of their own, not joined with && (a parse error in Windows PowerShell 5.1)'
    # A configured worker name means this repo has hosted the page before, so a fresh token may be
    # about to orphan a live one. Reported rather than refused: a first-ever token looks identical
    # from here, and -InitToken is explicit (issue #1453).
    Assert-Match 'a page may already be live' $w2.Out 'token: -InitToken warns when a worker is named'
    Assert-Match 'code view' $w2.Out 'token: and says where the old token is still readable'
    $token = ([System.IO.File]::ReadAllText((Join-Path $pageDir7 'worker-path-token.txt'), [System.Text.Encoding]::UTF8)).Trim()
    Assert-Match '^[0-9a-f]{32}$' $token 'token: 32 hex characters'

    $workerJs = [System.IO.File]::ReadAllText((Join-Path $pageDir7 'worker.js'), [System.Text.Encoding]::UTF8)
    Assert-Match ([regex]::Escape("/notes/$token")) $workerJs 'worker: the route carries the token'
    # EVERY RELEASE'S PAGE TRAVELS INTO THE WORKER, built again for the worker's own address so the cards
    # lead under the token rather than to the hub's '/release-notes'.
    Assert-Match '"/v2\.2\.0":' $workerJs 'worker: each release''s page is in the bundle, keyed under the route'
    Assert-Match ([regex]::Escape("href=\`"/notes/$token/v2.2.0\`"")) $workerJs 'worker: and the cards in it lead under the token'
    Assert-True ($workerJs -notmatch 'href=\\"/release-notes/') 'worker: never to the hub''s address'
    Assert-Match 'x-robots-tag' $workerJs 'worker: the response is marked noindex'
    Assert-Match 'status: 404' $workerJs 'worker: everything off the route is a 404'

    $w3 = Invoke-Build -Root $r7 -ScriptArgs @('-InitToken')
    Assert-Equal 1 $w3.Code 'token: a second -InitToken refuses'
    Assert-Equal $token ([System.IO.File]::ReadAllText((Join-Path $pageDir7 'worker-path-token.txt'), [System.Text.Encoding]::UTF8)).Trim() 'token: and leaves the existing one exactly as it was'

    # A copy the operator still HAS, in a folder nothing points at any more, is the likeliest reason
    # this one is missing -- so the refusal names that move even when it finds no copy (issue #1444).
    Assert-Says $w1.Out 'renamed or repointed' 'token: with no copy anywhere, the refusal still names the move that hides one'

    # AND THE DEPLOYMENT IS A COPY TOO (issue #1453). "No token on any machine here" was read as "the
    # URL is unrecoverable", which does not follow while the worker is up: the bundle carries its route
    # as a literal, so Cloudflare holds the token. The refusal has to name that BEFORE -InitToken,
    # because -InitToken is the step that makes the loss real.
    Assert-Says $w1.Out 'THREE WAYS BACK' 'token: the refusal enumerates the routes rather than naming two of three'
    Assert-Says $w1.Out 'read them off the DEPLOYMENT' 'token: and names the deployment as a copy of the token'
    # BOTH INDEXES ARE REQUIRED, because -1 -lt <any index> is $true: with 'DEPLOYMENT' missing this
    # assert used to report the order it never read (issue #1723).
    $iDeployment = Get-SaysIndex -Text $w1.Out -Phrase 'DEPLOYMENT'
    $iFreshPath  = Get-SaysIndex -Text $w1.Out -Phrase '-InitToken for a fresh path'
    Assert-True ($iDeployment -ge 0 -and $iFreshPath -gt $iDeployment) 'token: the recoverable route is named before the destructive one'

    # --- 7b. A token left behind by a folder move -------------------------------------------------
    # THE CASE THIS EXISTS FOR: the page directory is derived from the note root and gitignored, so
    # renaming the folder that holds the release documents moves every tracked file and leaves the
    # token where it was. Both refusals ask "is there a token anywhere in this tree", because "is
    # there one HERE" answers no on exactly the day that matters (issue #1444).
    Write-Host "worker -- a token left behind by a folder move is found, never overwritten" -ForegroundColor Cyan
    $r7b   = New-FixtureRepo -Label 'stray' -WorkerName 'fixture-release-notes'
    $stray = Join-Path $r7b 'old-releases\page'
    New-Item -ItemType Directory -Force -Path $stray | Out-Null
    $strayToken = Join-Path $stray 'worker-path-token.txt'
    [System.IO.File]::WriteAllText($strayToken, ('a' * 32), $Utf8NoBom)

    $s1 = Invoke-Build -Root $r7b -ScriptArgs @('-Worker')
    Assert-Equal 1 $s1.Code 'stray: -Worker still refuses -- the copy is named, never adopted'
    Assert-Says $s1.Out 'old-releases' 'stray: the refusal names where the copy actually is'
    Assert-Says $s1.Out 'MOVE that folder' 'stray: and says to move it, not to make a second token'

    $s2 = Invoke-Build -Root $r7b -ScriptArgs @('-Worker', '-InitToken')
    Assert-Equal 1 $s2.Code 'stray: -InitToken refuses too -- its guard asks whether a token exists ANYWHERE'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $r7b 'releases\page\worker-path-token.txt'))) 'stray: and no second token was minted'
    Assert-Equal ('a' * 32) ([System.IO.File]::ReadAllText($strayToken, [System.Text.Encoding]::UTF8)).Trim() 'stray: the copy it found is left exactly as it was'

    # --- 7c. The -InitToken warning is about a LIVE page, so an unhosted repo never sees it --------
    # Most consumers build the page and host it nowhere. Warning them about orphaning a deployment
    # they do not have is the noise that teaches people to skim the yellow block (issue #1453).
    Write-Host "worker -- the -InitToken warning stays silent where nothing is hosted" -ForegroundColor Cyan
    $r7c = New-FixtureRepo -Label 'inittoken-unhosted'
    $i1  = Invoke-Build -Root $r7c -ScriptArgs @('-InitToken')
    Assert-Equal 0 $i1.Code 'unhosted: -InitToken alone still succeeds without a worker name'
    Assert-Match '^[0-9a-f]{32}$' ([System.IO.File]::ReadAllText((Join-Path $r7c 'releases\page\worker-path-token.txt'), [System.Text.Encoding]::UTF8)).Trim() 'unhosted: and writes a real token'
    Assert-True (-not ($i1.Out -match 'a page may already be live')) 'unhosted: but says nothing about a deployment this repo does not have'

    # --- 8. -Worker without the seam --------------------------------------------------------------
    Write-Host "worker -- hosting needs the worker name" -ForegroundColor Cyan
    $w4 = Invoke-Build -Root $r1 -ScriptArgs @('-Worker')
    Assert-Equal 1 $w4.Code 'worker name: an empty seam refuses -Worker'
    Assert-Says $w4.Out 'Get-ReleasePageWorkerName' 'worker name: the error names the function to add'

    # --- 9. wrangler.toml is written once ---------------------------------------------------------
    Write-Host "worker -- wrangler.toml is the consumer's file after the first write" -ForegroundColor Cyan
    $wrangler = Join-Path $pageDir7 'wrangler.toml'
    Assert-True (Test-Path -LiteralPath $wrangler) 'wrangler: written on the first -Worker run'
    Assert-Match 'name = "fixture-release-notes"' ([System.IO.File]::ReadAllText($wrangler, [System.Text.Encoding]::UTF8)) 'wrangler: carries the seam name'

    # The write is the one branch that cannot honour "never overwritten" -- there was nothing to
    # overwrite -- and the file is lost by the same mechanisms as the token beside it, so it is
    # reported rather than passed off as routine (issue #1479). $w2 is the run that wrote it.
    Assert-Match 'may well have stood here' $w2.Out 'wrangler: the first write says the old file may have been lost, not just that a new one exists'
    Assert-Match 'account id, a custom domain, a route' $w2.Out 'wrangler: and names what a lost one would have carried'
    Assert-True (-not ($w1.Out -match 'may well have stood here')) 'wrangler: the refused run wrote no wrangler.toml and says nothing about one'
    [System.IO.File]::WriteAllText($wrangler, "name = `"fixture-release-notes`"`nmain = `"worker.js`"`n# EDITED BY HAND", $Utf8NoBom)
    $w5 = Invoke-Build -Root $r7 -ScriptArgs @('-Worker')
    Assert-Equal 0 $w5.Code 'wrangler: a later run succeeds'
    Assert-Match 'EDITED BY HAND' ([System.IO.File]::ReadAllText($wrangler, [System.Text.Encoding]::UTF8)) 'wrangler: a hand edit survives the rebuild'
    Assert-True (-not ($w5.Out -match 'may well have stood here')) 'wrangler: and the note belongs to the WRITE -- a run that found the file says nothing'

    # A name that has drifted from the seam is reported rather than corrected: which of the two is
    # wrong is not the script's to decide.
    [System.IO.File]::WriteAllText($wrangler, "name = `"something-else`"`nmain = `"worker.js`"", $Utf8NoBom)
    $w6 = Invoke-Build -Root $r7 -ScriptArgs @('-Worker')
    Assert-Equal 0 $w6.Code 'wrangler: a drifted name does not fail the build'
    Assert-Says $w6.Out 'something-else' 'wrangler: but it is reported'

    # --- 10. A missing history file ----------------------------------------------------------------
    Write-Host "build -- the release history has to be there" -ForegroundColor Cyan
    $r10 = New-FixtureRepo -Label 'nohistory'
    Remove-Item -LiteralPath (Join-Path $r10 'releases\README.md') -Force
    $b10 = Invoke-Build -Root $r10
    Assert-Equal 1 $b10.Code 'no history: refuses'
    Assert-Says $b10.Out 'Get-ReleaseHistoryPath' 'no history: the error names the seam that points at it'

    # --- 10b. An unanswered history seam (#3243) ---------------------------------------------------
    # The page reads the history where the cut writes it: the computed default, not the pre-#885
    # 'releases/README.md' the builder's own fallback used to name.
    Write-Host "build -- an unanswered Get-ReleaseHistoryPath reads the computed default" -ForegroundColor Cyan
    $r10b = New-FixtureRepo -Label 'historydefault' -NoHistorySeam
    $b10b = Invoke-Build -Root $r10b
    Assert-Equal 0 $b10b.Code 'history default: builds from dkj-policy/releases/history.md'
    Assert-True (Test-Path -LiteralPath (Join-Path $r10b 'releases\page\release-notes.html') -PathType Leaf) 'history default: the page is written'

    # --- 11. The palette seam (inbound #759) -------------------------------------------------------
    # WHY THE ASSERTS ARE ABOUT POSITION AND NOT ONLY PRESENCE. The override has to beat the
    # '@media (prefers-color-scheme: dark)' block, which means being LATER in the stylesheet -- a
    # palette emitted above it is silently ignored on a dark-mode machine and correct everywhere else,
    # which is the worst kind of wrong: it works on the developer's screen.
    Write-Host "build -- the repo's own palette (Get-ReleasePageTheme)" -ForegroundColor Cyan
    # 'light dark' rather than 'light': this fixture is about position, and a light PIN removes the
    # dark block it is positioned against -- that half is 11c below.
    $r11 = New-FixtureRepo -Label 'theme' -ThemeBody "return @{ '--accent' = '#FF4F01'; 'color-scheme' = 'light dark' }"
    $b11 = Invoke-Build -Root $r11
    Assert-Equal 0 $b11.Code 'theme: exit 0'
    $p11 = Get-PageData -PagePath (Join-Path $r11 'releases\page\release-notes.html')
    Assert-Match '--accent:\s*#FF4F01;' $p11.Html 'theme: the custom property reaches the page'
    Assert-Match 'color-scheme:\s*light dark;' $p11.Html "theme: 'color-scheme' is accepted as a name"
    Assert-True (-not ($p11.Html -match '@@[A-Z_]+@@')) 'theme: no template placeholder survives'
    # The position assert: the LAST occurrence of the override must come after the media query.
    $darkAt  = $p11.Html.IndexOf('prefers-color-scheme: dark')
    $themeAt = $p11.Html.IndexOf('#FF4F01')
    Assert-True ($darkAt -ge 0 -and $themeAt -gt $darkAt) 'theme: the palette is written AFTER the dark-mode block, so it wins on a dark machine too'
    # EXACTLY ONE OVERRIDE BLOCK, which is the assert that names the defect this pair caught: the
    # template's doc comment used to spell the placeholder in full, String.Replace hit that occurrence
    # too, and the palette was written twice -- once inside an HTML comment, above the dark-mode block.
    # The page still rendered correctly, so only position and count could see it.
    # ANCHORED ON THE LINE START, so the count measures CSS rules and not prose. The unanchored version
    # counted the comment three lines above this one, which QUOTES ':root { ... }' while explaining the
    # defect -- the mention-versus-use question this repo's lint has now answered four times, arriving
    # in a test.
    Assert-Equal 3 ([regex]::Matches($p11.Html, '(?m)^\s*:root \{').Count) 'theme: three :root blocks -- the two shipped ones plus this palette, written ONCE'

    # NO SEAM, NO BLOCK. The placeholder must vanish rather than leave an empty ':root {}' behind, and
    # the shipped palette must still be there -- a page whose accent went missing because a repo
    # declined to override it would be the seam breaking the default it exists to extend.
    $r11b = New-FixtureRepo -Label 'nopalette'
    $b11b = Invoke-Build -Root $r11b
    Assert-Equal 0 $b11b.Code 'no palette: exit 0'
    $p11c = Get-PageData -PagePath (Join-Path $r11b 'releases\page\release-notes.html')
    # COUNTED RATHER THAN MATCHED ON THE FUNCTION NAME, which is what the first version of this assert
    # did and could never pass: the template's own doc comment names the seam, so the string is in every
    # page whether a repo answered or not. Two ':root {' blocks is the shipped shape -- light, then the
    # dark override -- and a third is a palette.
    Assert-Equal 2 ([regex]::Matches($p11c.Html, '(?m)^\s*:root \{').Count) 'no palette: the page carries the two shipped :root blocks and no third'
    Assert-True (-not ($p11c.Html -match "own palette --")) 'no palette: and no override comment either'
    Assert-Match '--accent: #b8562f' $p11c.Html 'no palette: the shipped palette is untouched'

    # A LIGHT PIN HOLDS (inbound #2800). 'color-scheme: light' alone does not stop the dark media query
    # matching, so the consumer that named --ink but not --bg read near-black on near-black on a
    # dark-mode browser. The pin has to leave no dark override in the page at all, and the tokens the
    # repo did not name have to keep the template's LIGHT values.
    $r11d = New-FixtureRepo -Label 'lightpin' -ThemeBody "return @{ '--ink' = '#13191b'; 'color-scheme' = 'light' }"
    $b11d = Invoke-Build -Root $r11d
    Assert-Equal 0 $b11d.Code 'light pin: exit 0'
    $p11d = Get-PageData -PagePath (Join-Path $r11d 'releases\page\release-notes.html')
    Assert-True (-not ($p11d.Html -match '@media \(prefers-color-scheme: dark\)')) 'light pin: no dark-mode block survives in the page'
    Assert-True (-not ($p11d.Html -match '--bg: #191917')) 'light pin: the dark background is gone'
    Assert-Match '--bg: #fbfbfa' $p11d.Html 'light pin: an unnamed token keeps the template light value'
    Assert-Match '--ink:\s*#13191b;' $p11d.Html 'light pin: the named token still lands'
    Assert-Equal 2 ([regex]::Matches($p11d.Html, '(?m)^\s*:root \{').Count) 'light pin: the light :root plus the palette -- the dark one is removed, nothing else'
    Assert-True (-not ($b11d.Out -match 'not found in its expected shape')) 'light pin: the template dark block was found, so no warning'
    # 'light dark' (fixture 11) is NOT a pin: the dark block stays.
    Assert-Match '@media \(prefers-color-scheme: dark\)' $p11.Html "light dark: not a pin, so the dark block stays"

    # --- 12. The palette is validated, not escaped ------------------------------------------------
    # THE VECTOR THIS EXISTS FOR. These values land in a <style> element, so a value carrying a closing
    # style tag ends the element and everything after it is markup. Escaping is not the remedy here --
    # an escaped '#' is not a colour -- so the value is dropped, and the page is still built, because a
    # report about releases must not be stopped by one bad colour.
    Write-Host "build -- a palette value cannot reach the markup raw" -ForegroundColor Cyan
    $evil = "return @{ '--accent' = 'red</style><script>alert(1)</script>'; '--ink' = 'blue; }'; 'position' = 'fixed'; '--line' = '#123456' }"
    $r12 = New-FixtureRepo -Label 'evil' -ThemeBody $evil
    $b12 = Invoke-Build -Root $r12
    Assert-Equal 0 $b12.Code 'hostile palette: the page is still generated'
    $p12 = Get-PageData -PagePath (Join-Path $r12 'releases\page\release-notes.html')
    Assert-True (-not ($p12.Html -match 'alert\(1\)')) 'hostile palette: the injected script never reaches the page'
    Assert-True (-not ($p12.Html -match '(?m)^\s*--ink: blue;')) 'hostile palette: a value carrying a brace-escape is dropped'
    Assert-True (-not ($p12.Html -match '(?m)^\s*position: fixed;')) 'hostile palette: a name that is not a custom property is dropped'
    Assert-Match '--line:\s*#123456;' $p12.Html 'hostile palette: and the SOUND value in the same map still lands -- one bad key costs one colour'
    Assert-Says $b12.Out 'Get-ReleasePageTheme' 'hostile palette: each drop is warned about, naming the function'
    Assert-Says $b12.Out "'--accent'" 'hostile palette: and naming the key, so a silently ignored setting is impossible'

    # --- 13. The index is the page, and it is static (the design pass, inbound #759) --------------
    # THE SUITE SURVIVED THE REDESIGN UNTOUCHED, which is the reason this block exists. Every assert
    # above reads the DATA -- order, dates, types, the escaping -- so replacing a <select> picker with
    # a collapsible index changed nothing any of them could see. A design decision no test can fail is
    # a design decision the next change quietly reverts.
    # A CARD PER RELEASE AND A PAGE PER CARD (owner, October 25, 2026) replaced the collapsed rows, and
    # each claim below is the card's counterpart of one the rows were held to.
    Write-Host "build -- the index is one card per release, each leading to its own page" -ForegroundColor Cyan
    $r13 = New-FixtureRepo -Label 'index'
    $b13 = Invoke-Build -Root $r13
    Assert-Equal 0 $b13.Code 'index: exit 0'
    $p13 = Get-PageData -PagePath (Join-Path $r13 'releases\page\release-notes.html')

    # ONE CARD PER RELEASE WITH A NOTE, and the fixture has two of the four in its history table.
    Assert-Equal 2 ([regex]::Matches($p13.Html, '<a class="card"').Count) 'index: one card per release carrying a note'
    # THE ID STAYS THE VERSION VERBATIM: '#v2.2.0' is what a link somebody already holds has to match.
    Assert-True ($p13.Html -match '<a class="card" id="v2\.2\.0" href="/release-notes/v2\.2\.0">') 'index: the card keeps the old deep-link id, and leads to the release''s own page'

    # THE CARD IS STATIC HTML: version, title, date and chip are in the markup, so the index reads with
    # JavaScript off.
    $card = ([regex]::Match($p13.Html, '(?s)<a class="card" id="v2\.2\.0".*?</a>')).Value
    Assert-True ($card -match '<span class="sv">Version 2\.2</span>') 'index: the card carries the version as markup'
    # THE TITLE IS VISIBLE ON THE CARD. It left the row on August 21 because an opened row repeated it;
    # a card opens nothing in place, so here it is the one line that says what a release is.
    Assert-True ($card -match '<span class="ct">The live push moved to a new stage</span>') 'index: and the title, as visible text'
    Assert-True ($card -match '<span class="sd">14 Aug 2026</span>') 'index: and the date, REFORMATTED from the table ISO for a reader who is not the team'

    # AT MOST ONE CHIP PER CARD: live where the table marks it, the bump type otherwise, never both.
    Assert-Equal 1 ([regex]::Matches($card, '<span class="chip').Count) 'index: one chip on a non-live card'
    Assert-True ($card -match '<span class="chip sc">Minor</span>') 'index: and it is the bump type, since this card is not the live one'
    $liveCard = ([regex]::Match($p13.Html, '(?s)<a class="card" id="v2\.0\.0".*?</a>')).Value
    Assert-Equal 1 ([regex]::Matches($liveCard, '<span class="chip').Count) 'index: one chip on the live card too'
    Assert-True ($liveCard -match '<span class="chip accent sc">live</span>') 'index: and there it is the live marker, which is the fact a reader scans for'
    Assert-True ($liveCard -notmatch '>Major<') 'index: the live card states live and NOT its type -- one chip, one fact'

    # NO ROW AND NO PICKER SURVIVES. Measured with the comments stripped, because the template's own doc
    # comment names both things it replaced -- mention versus use. A check that cannot tell a document
    # discussing a thing from a document containing it accuses the explanation.
    $markup13 = [regex]::Replace($p13.Html, '(?s)<!--.*?-->', '')
    Assert-True (-not ($markup13 -match '<details')) 'index: no collapsed row survives -- the cards ARE the index'
    Assert-True (-not ($markup13 -match '<select')) 'index: nor the picker before them'
    Assert-True (-not ($markup13 -match '<article')) 'index: and no note: the index needs no JavaScript at all'

    # AN OLD LINK FORWARDS: '#v2.2.0' finds the card, and the script follows its link. Asserted as content,
    # since the forwarding itself needs a browser; replace(), so Back does not land on the bare index.
    Assert-Match 'location\.replace\(el\.href\)' $p13.Html 'index: an old #v link is forwarded to the release''s own page'

    # --- 13b. A release's own page ----------------------------------------------------------------
    Write-Host "build -- every release has a page of its own" -ForegroundColor Cyan
    $rp13 = Get-ReleasePageData -Root $r13 -Version '2.2.0'
    Assert-Match '<h1>Version 2\.2</h1>' $rp13.Html 'release page: the heading is the version'
    Assert-Match '<title>Version 2\.2 &middot; Fixture Product release notes</title>' $rp13.Html 'release page: and the tab names the version first'
    Assert-Match '<a class="back" href="/release-notes">&larr; All releases</a>' $rp13.Html 'release page: with the way back to the index'
    Assert-Match '<span class="sd">14 Aug 2026</span> <span class="chip sc">Minor</span>' $rp13.Html 'release page: the date and the same chip as its card'
    # THE BODY IS EMPTY IN THE MARKUP and the renderer fills it at once. The half-measure this design
    # states out loud: the page survives without JavaScript, the prose does not -- and the page SAYS so.
    Assert-Match '<article class="sheet note" data-version="2\.2\.0"></article>' $rp13.Html 'release page: the note is an empty article the renderer fills'
    Assert-Match '(?s)<noscript>.*?with JavaScript off it stays empty' $rp13.Html 'release page: and the page says why it would stay empty'
    # OLDER AND NEWER, and only the sides that exist: the newest release has no newer neighbour.
    Assert-Match '<a class="pager-older" href="/release-notes/v2\.0\.0">' $rp13.Html 'release page: the newest one leads to the release before it'
    Assert-True ($rp13.Html -notmatch 'class="pager-newer"') 'release page: and offers no newer one, because there is none'
    $rp13b = Get-ReleasePageData -Root $r13 -Version '2.0.0'
    Assert-Match '<a class="pager-newer" href="/release-notes/v2\.2\.0">' $rp13b.Html 'release page: the oldest one leads to the release after it'
    Assert-True ($rp13b.Html -notmatch 'class="pager-older"') 'release page: and offers no older one'
    Assert-True (-not ($rp13.Html -match '@@[A-Z_]+@@')) 'release page: no template placeholder survives'

    # A PAGE LEFT BY AN EARLIER BUILD IS REMOVED: a release taken out of the history must not stay reachable.
    $staleRelease = Join-Path $r13 'releases\page\release-notes\v9.9.9.html'
    [System.IO.File]::WriteAllText($staleRelease, 'old')
    $null = Invoke-Build -Root $r13
    Assert-True (-not (Test-Path -LiteralPath $staleRelease)) 'release page: a page no release in the history carries is removed by the next build'
    $foreign = Join-Path $r13 'releases\page\release-notes\very-own.html'
    [System.IO.File]::WriteAllText($foreign, 'mine')
    $null = Invoke-Build -Root $r13
    Assert-True (Test-Path -LiteralPath $foreign) 'release page: and only a name the builder writes is removed'

    # -LinkBase IS THE ADDRESS THE PAGES ARE SERVED FROM, and the links carry it.
    $b13c = Invoke-Build -Root $r13 -ScriptArgs @('-LinkBase', '/notes/abc')
    Assert-Equal 0 $b13c.Code 'link base: exit 0'
    Assert-Match 'href="/notes/abc/v2\.2\.0"' ([System.IO.File]::ReadAllText((Join-Path $r13 'releases\page\release-notes.html'))) 'link base: the cards lead under the address given'
    $b13d = Invoke-Build -Root $r13 -ScriptArgs @('-LinkBase', 'javascript:alert(1)')
    Assert-Equal 1 $b13d.Code 'link base: an address that is not a site-absolute path is refused'
    Assert-Equal 1 (Invoke-Build -Root $r13 -ScriptArgs @('-LinkBase', '//elsewhere.invalid/x')).Code 'link base: and so is //host, which a browser reads as another site'
    Assert-Equal 1 (Invoke-Build -Root $r13 -ScriptArgs @('-LinkBase', '/a/../b')).Code 'link base: and so is a .. segment'

    # A DATE THE SCRIPT CANNOT PARSE IS PASSED THROUGH rather than guessed at -- a repo may write its
    # history table in a form this script has never seen, and inventing a date is worse than showing
    # theirs.
    $oddDate = New-FixtureRepo -Label 'odddate'
    $histPath = Join-Path $oddDate 'releases\README.md'
    $hist = [System.IO.File]::ReadAllText($histPath, [System.Text.Encoding]::UTF8).Replace('2026-08-14', '14 thermidor')
    [System.IO.File]::WriteAllText($histPath, $hist, $Utf8NoBom)
    $b13b = Invoke-Build -Root $oddDate
    Assert-Equal 0 $b13b.Code 'odd date: the build does not fail over a date it cannot parse'
    $p13b = Get-PageData -PagePath (Join-Path $oddDate 'releases\page\release-notes.html')
    Assert-True ($p13b.Html -match '<span class="sd">14 thermidor</span>') 'odd date: and shows the repo its own value instead of inventing one'


    # --- 14. The note stops restating the row it is inside (inbound #816) --------------------------
    # THE SUPPRESSION IS SERVER-SIDE, so it is measurable here rather than only in a browser -- and it
    # reaches the notes ALREADY published, which are records and are not rewritten.
    Write-Host "row -- the note no longer repeats the version, the date and the type" -ForegroundColor Cyan
    $r14 = New-FixtureRepo -Label 'metadata'
    $b14 = Invoke-Build -Root $r14
    Assert-Equal 0 $b14.Code 'metadata: exit 0'
    $p14 = Get-PageData -PagePath (Join-Path $r14 'releases\page\release-notes.html')
    $body14 = [string](Get-ReleasePageData -Root $r14 -Version '2.2.0').Data.releases[0].body
    Assert-True ($body14 -notmatch '# Release notes') 'metadata: the H1 that names the version is gone -- the row above says it'
    Assert-True ($body14 -notmatch '\*\*Date:\*\*')   'metadata: and the date, which the row shows in a readable format'
    Assert-True ($body14 -notmatch '\*\*Type:\*\*')   'metadata: and the type'
    Assert-True ($body14 -notmatch '\*\*For whom:\*\*') 'metadata: and the constant sentence telling the reader who they are'
    # AND THE TITLE LINE, which is the row's own title verbatim. Reported by Dave reading the built page:
    # with the metadata block gone, an opened note began by repeating the sentence in the row he had just
    # clicked. This branch's entry had recorded it as a risk nobody had raised -- and then somebody did.
    # THE TITLE LINE STAYS IN THE NOTE, and the duplication was removed from the other side instead: the
    # summary no longer shows it, so the note is the one place it is read. That answer replaced suppressing
    # it here, which had been the first repair of the same complaint.
    Assert-Match '^The live push moved to a new stage' $body14 'title: the note opens on its own title, which the row no longer displays'
    Assert-Match 'Body of 2\.2\.0' $body14 'metadata: and what the note actually says follows it'

    # MATCHED ON EQUALITY WITH THE TABLE'S TITLE, never on 'the first paragraph'. Where a hand edit has
    # moved the two apart the line stays: prose the page cannot prove is a duplicate is prose it leaves.
    $r14c = New-FixtureRepo -Label 'titledrift' -TitleLineDrifted
    $b14c = Invoke-Build -Root $r14c
    Assert-Equal 0 $b14c.Code 'title/drift: exit 0'
    $p14c = Get-PageData -PagePath (Join-Path $r14c 'releases\page\release-notes.html')
    Assert-Match 'A title somebody edited by hand' ([string](Get-ReleasePageData -Root $r14c -Version '2.2.0').Data.releases[0].body) 'title/drift: a title line that differs from the table is kept'

    # CONSERVATIVE BY CONSTRUCTION: a note that does not open with an H1 naming its own version is left
    # exactly as it is. Matching bold labels near the top of any document would eventually eat a line
    # somebody wrote on purpose.
    $r14b = New-FixtureRepo -Label 'plainnote' -PlainNote
    $b14b = Invoke-Build -Root $r14b
    Assert-Equal 0 $b14b.Code 'metadata/plain: exit 0'
    $p14b = Get-PageData -PagePath (Join-Path $r14b 'releases\page\release-notes.html')
    Assert-Match 'Body of 2\.2\.0' ([string](Get-ReleasePageData -Root $r14b -Version '2.2.0').Data.releases[0].body) 'metadata/plain: a note opening some other way is untouched'

    # --- 15. The version label and the id are allowed to differ (inbound #813) --------------------
    # A patch never gets a hand-written note, so every version this page can display ends in '.0' and
    # the third digit is a constant. The LABEL drops it; the ID never does, because the id is the target
    # of links people already hold and changing it would 404 them all while the build reported success.
    Write-Host "row -- the third digit goes from the label and stays in the id" -ForegroundColor Cyan
    Assert-Match 'id="v2\.2\.0"' $p14.Html 'version: the id keeps the full semver'
    Assert-Match '<span class="sv">Version 2\.2</span>' $p14.Html 'version: the label drops a trailing .0 when every release has one, and reads ''Version'' rather than a lone v'
    Assert-Match 'id="v2\.0\.0"' $p14.Html 'version: including the release whose minor is itself 0'

    # AND NOT WHERE A RELEASE GENUINELY CARRIES A THIRD DIGIT. Get-ReleaseConsumerBumps is
    # consumer-overridable, so a repo that writes a note for a patch needs all three -- which is why this
    # is derived from the data rather than hardcoded or read off a seam.
    $r15 = New-FixtureRepo -Label 'withpatch' -WithPatchNote
    $b15 = Invoke-Build -Root $r15
    Assert-Equal 0 $b15.Code 'version/patch: exit 0'
    $p15 = Get-PageData -PagePath (Join-Path $r15 'releases\page\release-notes.html')
    Assert-Match '<span class="sv">Version 2\.1\.1</span>' $p15.Html 'version/patch: one release off the pattern keeps the third digit on ALL of them'
    Assert-True ($p15.Html -notmatch '<span class="sv">Version 2\.2</span>') 'version/patch: so nothing is trimmed here'

    # --- 16. The type chip only where the type varies (inbound #811, ask 1) -----------------------
    Write-Host "row -- the type chip earns its space or is not there" -ForegroundColor Cyan
    # THE CHIP MARKS WHAT IS UNUSUAL. In this fixture the two noted releases are one Minor and one Major,
    # so the mode is decided by name and 'Major' wins the tie -- which means the Minor row is the one that
    # differs from the page's ordinary type and keeps its chip.
    Assert-Match 'class="chip sc">Minor<' $p14.Html 'chip: a row whose type differs from the page''s ordinary one keeps it'
    # ONE SPAN, not two. It had to be written twice while the title held the middle column; taking the
    # title out of the summary retired that, so no copy is hidden by CSS and no row pays for another
    # row's track.
    Assert-Equal 0 ([regex]::Matches($p14.Html, 'sc-wide|sc-narrow').Count) 'chip: one span, not a shown copy and a hidden one'

    $r16 = New-FixtureRepo -Label 'uniform' -UniformType
    $b16 = Invoke-Build -Root $r16
    Assert-Equal 0 $b16.Code 'chip/uniform: exit 0'
    $p16 = Get-PageData -PagePath (Join-Path $r16 'releases\page\release-notes.html')
    Assert-True ($p16.Html -notmatch 'class="chip sc">Minor<') 'chip/uniform: a type every row shares carries no information and is not rendered'
    # THE TEST THAT WAS BUILT FIRST AND FIXED NOTHING, pinned so it cannot come back: 'is there more than
    # one distinct type' answers YES on a page of 38 Minor and 1 Baseline, so every one of those 38 chips
    # would have stayed. The dominant-type rule suppresses them and keeps the one that differs.
    $r16b = New-FixtureRepo -Label 'lopsided'
    $b16b = Invoke-Build -Root $r16b
    Assert-Equal 0 $b16b.Code 'chip/lopsided: exit 0'
    $p16b = Get-PageData -PagePath (Join-Path $r16b 'releases\page\release-notes.html')
    Assert-Equal 1 ([regex]::Matches($p16b.Html, 'class="chip sc">').Count) 'chip/lopsided: exactly ONE type chip on a page with two types, not one per row'

    # --- 16b. LIVE falls back to the newest release ------------------------------------------------
    # THE MARKER STILL WINS. In the fixtures above the table marks 2.0.0, which is NOT the newest, and that
    # is the case the marker exists for: a Shopify repo's live theme is genuinely not always the latest cut.
    Write-Host "row -- the LIVE label, marked or derived" -ForegroundColor Cyan
    $markedRow = ([regex]::Match($p14.Html, '(?s)<a class="card" id="v2.0.0".*?</a>')).Value
    $newestRow = ([regex]::Match($p14.Html, '(?s)<a class="card" id="v2.2.0".*?</a>')).Value
    Assert-Match 'chip accent sc">LIVE<' $markedRow 'live/marked: the row the table marks carries it'
    # ON THE CHIP MARKUP, not on the word: PowerShell's -notmatch is case-INSENSITIVE, and this row's own
    # title is 'The live push moved to a new stage'. The first version of this assert failed for that
    # reason and not because the page was wrong.
    Assert-True ($newestRow -notmatch 'chip accent') 'live/marked: and the NEWEST row does not, because the table says otherwise'

    # WHERE THE TABLE MARKS NOTHING, the newest release carries it -- derived, because a marker has to be
    # moved by hand at every cut in a file the cut itself writes into, so it is right on the day it is set
    # and silently wrong at the next release.
    $r16c = New-FixtureRepo -Label 'nolive' -NoLiveMarker
    $b16c = Invoke-Build -Root $r16c
    Assert-Equal 0 $b16c.Code 'live/derived: exit 0'
    $p16c = Get-PageData -PagePath (Join-Path $r16c 'releases\page\release-notes.html')
    $newestRowC = ([regex]::Match($p16c.Html, '(?s)<a class="card" id="v2.2.0".*?</a>')).Value
    $olderRowC  = ([regex]::Match($p16c.Html, '(?s)<a class="card" id="v2.0.0".*?</a>')).Value
    Assert-Match 'chip accent sc">LIVE<' $newestRowC 'live/derived: an unmarked table puts it on the newest release'
    Assert-True ($olderRowC -notmatch 'chip accent') 'live/derived: and on that one only'
    Assert-Equal 1 ([regex]::Matches($p16c.Html, 'chip accent sc">LIVE<').Count) 'live/derived: exactly one row carries it'
    # THE LIVE CHIP IS NEVER SUPPRESSED. It marks one row out of forty, which is the definition of a
    # field that is worth its space -- and it is the row a reader looks at first.
    Assert-Match 'class="chip accent sc">live<' $p16.Html 'chip/uniform: the live chip stays'

    # --- 17. The masthead marks (inbound #809) ----------------------------------------------------
    # A one-pixel transparent GIF: the smallest thing that is genuinely a base64 data image, so the test
    # measures the seam rather than an image library.
    Write-Host "masthead -- a consumer's own wordmark, and every way of getting it wrong" -ForegroundColor Cyan
    $pixel = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7'
    $r17 = New-FixtureRepo -Label 'masthead' -MastheadBody "return @(@{ Src = '$pixel'; Alt = 'Fixture UK' })"
    $b17 = Invoke-Build -Root $r17
    Assert-Equal 0 $b17.Code 'masthead: exit 0'
    $p17 = Get-PageData -PagePath (Join-Path $r17 'releases\page\release-notes.html')
    Assert-Match '<div class="marks">' $p17.Html 'masthead: the marks block is written'
    Assert-Match 'alt="Fixture UK"' $p17.Html 'masthead: with the alt text the seam gave'
    Assert-True ($p17.Html.IndexOf('<div class="marks">') -lt $p17.Html.IndexOf('<h1>')) 'masthead: above the title, which is where a wordmark belongs'

    # UNANSWERED IS THE DEFAULT AND WRITES NOTHING.
    Assert-True ($p14.Html -notmatch '<div class="marks">') 'masthead: a repo that has not answered gets no marks block at all'

    # A URL IS NOT AN INLINE IMAGE. The page is self-contained because a request to a third party leaks
    # who is reading it, so a URL is dropped with a named warning rather than fetched.
    $r17b = New-FixtureRepo -Label 'mastheadurl' -MastheadBody "return 'https://example.invalid/logo.svg'"
    $b17b = Invoke-Build -Root $r17b
    Assert-Equal 0 $b17b.Code 'masthead/url: a bad value costs the image, never the build'
    Assert-Says $b17b.Out 'Get-ReleasePageMasthead' 'masthead/url: and the warning names the seam'
    $p17b = Get-PageData -PagePath (Join-Path $r17b 'releases\page\release-notes.html')
    Assert-True ($p17b.Html -notmatch '<div class="marks">') 'masthead/url: nothing is written'
    Assert-True ($p17b.Html -notmatch 'example\.invalid') 'masthead/url: and the URL never reaches the page'

    # A RAW SVG PAYLOAD IS MARKUP INSIDE AN ATTRIBUTE, so base64 is required rather than escaped.
    $r17c = New-FixtureRepo -Label 'mastheadsvg' -MastheadBody "return 'data:image/svg+xml,<svg xmlns=`"http://www.w3.org/2000/svg`"></svg>'"
    $b17c = Invoke-Build -Root $r17c
    Assert-Equal 0 $b17c.Code 'masthead/rawsvg: still builds'
    $p17c = Get-PageData -PagePath (Join-Path $r17c 'releases\page\release-notes.html')
    Assert-True ($p17c.Html -notmatch '<div class="marks">') 'masthead/rawsvg: a non-base64 payload is refused'

    # THE CAP IS TWO, and it is a measurement rather than a technical bound: a consumer tried five and
    # cut back, because five read as a page about the brands rather than about the releases.
    $r17d = New-FixtureRepo -Label 'mastheadmany' -MastheadBody "return @('$pixel', '$pixel', '$pixel')"
    $b17d = Invoke-Build -Root $r17d
    Assert-Equal 0 $b17d.Code 'masthead/cap: still builds'
    $p17d = Get-PageData -PagePath (Join-Path $r17d 'releases\page\release-notes.html')
    Assert-Equal 2 ([regex]::Matches($p17d.Html, '<img src="data:image/gif').Count) 'masthead/cap: the third mark is dropped'
    Assert-Says $b17d.Out 'more than 2 mark' 'masthead/cap: and the warning says which cap was hit'
    # A BARE STRING IS ACCEPTED, which is the one-mark case, and its alt is empty on purpose: a mark
    # beside a title that already names the product is decorative.
    Assert-Match 'alt=""' $p17d.Html 'masthead/bare: a bare data: string works, with an empty alt'

    # OVER THE PER-MARK CEILING: skipped, named, and the page is still built.
    $fat = 'data:image/gif;base64,' + ('A' * 40000)
    $r17e = New-FixtureRepo -Label 'mastheadfat' -MastheadBody "return '$fat'"
    $b17e = Invoke-Build -Root $r17e
    Assert-Equal 0 $b17e.Code 'masthead/size: still builds'
    Assert-Says $b17e.Out 'ceiling per mark' 'masthead/size: the warning names the ceiling it hit'
    $p17e = Get-PageData -PagePath (Join-Path $r17e 'releases\page\release-notes.html')
    Assert-True ($p17e.Html -notmatch '<div class="marks">') 'masthead/size: and the oversized mark is not written'

    # --- 18. The layout claims, as CSS -------------------------------------------------------------
    # A CSS assert, like the palette-position one above, because these claims are about WHERE things are
    # rather than that they exist.
    Write-Host "layout -- the grid, the cards and the release page" -ForegroundColor Cyan
    # THE GRID FILLS WHATEVER WIDTH IT IS GIVEN, so the same rule is one column on a phone and several on a
    # desktop, and the width a reader picks needs nothing of its own.
    Assert-Match 'grid-template-columns: repeat\(auto-fill, minmax\(14rem, 1fr\)\)' $p14.Html 'cards: the grid fills the width with as many columns as fit'
    # THE TITLE TAKES THE SLACK, so the dates of cards side by side line up whatever their titles' lengths.
    Assert-Match '\.card \.ct \{ flex: 1;' $p14.Html 'cards: the title takes the slack, so every date sits at the foot'
    # A link already held still lands on its card where JavaScript is off.
    Assert-Match '\.card:target' $p14.Html 'cards: an old #v link marks the card it lands on'
    # ON THE ABSENCE OF THE OLD VALUE: the masthead's own bottom padding is the separation.
    Assert-True ($p14.Html -notmatch 'margin: 2rem 0 0') 'sheet: the 2rem of air above the list is gone at every width'
    # THE NEWER NEIGHBOUR IS ALWAYS ON THE RIGHT, and on a phone it stacks first.
    Assert-Match '\.pager-newer \{ grid-column: 2;' $p14.Html 'pager: the newer release always sits on the right'
    Assert-Match '\.pager-newer \{ grid-column: auto; grid-row: 1; \}' $p14.Html 'pager: and on a phone it stacks first'

} finally {
    Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Summary: $script:pass passed, $script:fail failed" -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
