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
        [switch]$NoLiveMarker
    )
    $root = Join-Path $Fixture "repo-$Label"
    if (Test-Path -LiteralPath $root) { Remove-Item -Recurse -Force -LiteralPath $root }
    New-Item -ItemType Directory -Force -Path $root | Out-Null

    $titleFn = if ($OmitTitle) { '' } else { "function Get-ReleasePageTitle { return 'Fixture Product' }" }
    $config = @"
function Get-RepoName { return 'fixture-owner/fixture-repo' }
function Get-ReleaseNoteRoot { return 'releases/audience' }
function Get-ReleaseNotesGrouping { return '$Grouping' }
function Get-ReleaseHistoryPath { return 'releases/README.md' }
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
    Write-FixtureFile (Join-Path $root 'releases\README.md') $history

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

    $p1 = Get-PageData -PagePath $page1
    Assert-Equal 2 $p1.Data.documentCount 'basic: two releases carry a note'
    Assert-Equal '2.2.0' $p1.Data.releases[0].version 'basic: newest first, as the table reads'
    Assert-Equal '2.0.0' $p1.Data.releases[1].version 'basic: oldest last'
    Assert-Equal '2026-08-14' $p1.Data.releases[0].date 'basic: the date comes from the table'
    Assert-Equal 'Major' $p1.Data.releases[1].type 'basic: the type comes from the table'
    Assert-Match 'Body of 2\.2\.0' $p1.Data.releases[0].body 'basic: the note body travels into the page'
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
    Assert-Match 'closing script tag follows' $p4.Data.releases[0].body 'scripttag: the text itself is preserved'

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

    # --- 11. The palette seam (inbound #759) -------------------------------------------------------
    # WHY THE ASSERTS ARE ABOUT POSITION AND NOT ONLY PRESENCE. The override has to beat the
    # '@media (prefers-color-scheme: dark)' block, which means being LATER in the stylesheet -- a
    # palette emitted above it is silently ignored on a dark-mode machine and correct everywhere else,
    # which is the worst kind of wrong: it works on the developer's screen.
    Write-Host "build -- the repo's own palette (Get-ReleasePageTheme)" -ForegroundColor Cyan
    $r11 = New-FixtureRepo -Label 'theme' -ThemeBody "return @{ '--accent' = '#FF4F01'; 'color-scheme' = 'light' }"
    $b11 = Invoke-Build -Root $r11
    Assert-Equal 0 $b11.Code 'theme: exit 0'
    $p11 = Get-PageData -PagePath (Join-Path $r11 'releases\page\release-notes.html')
    Assert-Match '--accent:\s*#FF4F01;' $p11.Html 'theme: the custom property reaches the page'
    Assert-Match 'color-scheme:\s*light;' $p11.Html "theme: 'color-scheme' is accepted, which is how a brand with no dark variant says so"
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
    Write-Host "build -- the index is one collapsed row per release, built server-side" -ForegroundColor Cyan
    $r13 = New-FixtureRepo -Label 'index'
    $b13 = Invoke-Build -Root $r13
    Assert-Equal 0 $b13.Code 'index: exit 0'
    $p13 = Get-PageData -PagePath (Join-Path $r13 'releases\page\release-notes.html')

    # ONE ROW PER RELEASE WITH A NOTE, and the fixture has two of the four in its history table.
    Assert-Equal 2 ([regex]::Matches($p13.Html, '<details class="fold"').Count) 'index: one details row per release carrying a note'
    Assert-True ($p13.Html -match '<details class="fold" id="v2\.2\.0">') 'index: the id is the version verbatim, which is what a deep link in somebody hands has to match'

    # ALL OF THEM CLOSED. This was the reference edition's own last correction -- four expanded notes
    # at the top buried the other thirty-six -- so it is asserted rather than left to a default.
    Assert-Equal 0 ([regex]::Matches($p13.Html, '<details[^>]*\sopen').Count) 'index: every row starts CLOSED'

    # THE ROW IS STATIC HTML, which is the whole point: it reads with JavaScript off. Version, title
    # and date are in the markup rather than in the data block alone.
    $summary = ([regex]::Match($p13.Html, '(?s)<details class="fold" id="v2\.2\.0">.*?</summary>')).Value
    Assert-True ($summary -match '<span class="sv">Version 2\.2</span>') 'index: the row carries the version as markup'
    # THE TITLE IS THE ROW'S ACCESSIBLE NAME, not visible text (Dave, August 21, 2026): a summary of a
    # version and a date is thin for anyone navigating by control, and the title is the one string that
    # says what the row is -- so it rides on the element, where it costs no width.
    Assert-True ($summary -match 'title="The live push moved to a new stage"') 'index: and the title, as the row''s accessible name'
    Assert-True ($summary -notmatch '<span class="st"') 'index: but no longer as visible text in the summary'
    Assert-True ($summary -match '<span class="sd">14 Aug 2026</span>') 'index: and the date, REFORMATTED from the table ISO for a reader who is not the team'

    # AT MOST ONE CHIP PER ROW: live where the table marks it, the bump type otherwise, never both. Since
    # inbound #811 that one chip is written as TWO spans and the CSS shows exactly one of them -- the
    # desktop copy inline before the title, the narrow copy in its own cell on row 1 -- so the count here
    # is two per row rather than one. What has not changed is the rule the count was written for: the two
    # spans always carry the SAME text, so no row ever states both a type and a live marker.
    Assert-Equal 1 ([regex]::Matches($summary, '<span class="chip').Count) 'index: one chip on a non-live row'
    Assert-True ($summary -match '<span class="chip sc">Minor</span>') 'index: and it is the bump type, since this row is not the live one'
    $liveRow = ([regex]::Match($p13.Html, '(?s)<details class="fold" id="v2\.0\.0">.*?</summary>')).Value
    Assert-Equal 1 ([regex]::Matches($liveRow, '<span class="chip').Count) 'index: one chip on the live row too'
    Assert-True ($liveRow -match '<span class="chip accent sc">live</span>') 'index: and there it is the live marker, which is the fact a reader scans for'
    Assert-True ($liveRow -notmatch '>Major<') 'index: the live row states live and NOT its type -- one chip, one fact'

    # THE BODY IS EMPTY IN THE MARKUP and is filled by the renderer on first open. Asserted because it
    # is the half-measure this design states out loud: the index survives without JavaScript, the
    # prose does not.
    Assert-True ($p13.Html -match '<article data-version="2\.2\.0"></article>') 'index: the note body is an empty article the renderer fills on open'
    Assert-True ($p13.Html -match '(?s)<noscript>.*?index below reads without JavaScript') 'index: and the page SAYS so, rather than leaving an empty panel to be read as a failure'

    # THE PICKER IS GONE. Named explicitly, because "one release at a time behind a select" is the
    # thing being replaced and a half-reverted redesign would leave both.
    # MEASURED WITH THE COMMENTS STRIPPED, because the template's own doc comment names the '<select>'
    # it replaced -- mention versus use, for the third time in this page's history (the palette block
    # and the ':root' count were the other two). A check that cannot tell a document discussing a
    # thing from a document containing it accuses the explanation.
    $markup13 = [regex]::Replace($p13.Html, '(?s)<!--.*?-->', '')
    Assert-True (-not ($markup13 -match '<select')) 'index: no picker survives -- the list IS the index'
    Assert-True (-not ($markup13 -match 'id="picker"')) 'index: nor its controller hook'
    Assert-True ($p13.Html -match '<select') 'index: while the doc comment DOES still explain what was replaced -- the strip above is the reason this pair can be strict'

    # AND THE DATA BLOCK IS STILL THERE, carrying the bodies. The index being static does not mean the
    # page stopped needing the notes.
    Assert-Equal 2 $p13.Data.documentCount 'index: the data block still carries both notes for the renderer'

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
    $body14 = [string]$p14.Data.releases[0].body
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
    Assert-Match 'A title somebody edited by hand' ([string]$p14c.Data.releases[0].body) 'title/drift: a title line that differs from the table is kept'

    # CONSERVATIVE BY CONSTRUCTION: a note that does not open with an H1 naming its own version is left
    # exactly as it is. Matching bold labels near the top of any document would eventually eat a line
    # somebody wrote on purpose.
    $r14b = New-FixtureRepo -Label 'plainnote' -PlainNote
    $b14b = Invoke-Build -Root $r14b
    Assert-Equal 0 $b14b.Code 'metadata/plain: exit 0'
    $p14b = Get-PageData -PagePath (Join-Path $r14b 'releases\page\release-notes.html')
    Assert-Match 'Body of 2\.2\.0' ([string]$p14b.Data.releases[0].body) 'metadata/plain: a note opening some other way is untouched'

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
    $markedRow = ([regex]::Match($p14.Html, '(?s)<details class="fold" id="v2\.0\.0">.*?</summary>')).Value
    $newestRow = ([regex]::Match($p14.Html, '(?s)<details class="fold" id="v2\.2\.0">.*?</summary>')).Value
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
    $newestRowC = ([regex]::Match($p16c.Html, '(?s)<details class="fold" id="v2\.2\.0">.*?</summary>')).Value
    $olderRowC  = ([regex]::Match($p16c.Html, '(?s)<details class="fold" id="v2\.0\.0">.*?</summary>')).Value
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

    # --- 18. The chevron is trailing, and reserves nothing ahead of the text (#811, asks 2 and 3) --
    # A CSS assert, like the palette-position one above, because the layout claims in the issue are about
    # WHERE things are rather than that they exist. The gutter was 1.9rem on a 390px phone -- 9.4% of the
    # usable text width -- and the narrow query kept it.
    Write-Host "row -- the chevron moved to the trailing edge" -ForegroundColor Cyan
    Assert-Match '\.fold > summary::after' $p14.Html 'chevron: it is an ::after, so the grid puts it in the last column'
    Assert-True ($p14.Html -notmatch '\.fold > summary::before') 'chevron: and no longer a ::before reserving a column ahead of the version'
    Assert-Match '\.fold\[open\] > summary \{\s*\r?\n?\s*position: sticky' $p14.Html 'sticky: an open row keeps its own summary in reach, which is the only control that closes it'
    # ON THE ABSENCE OF THE OLD VALUE, not on the new one: the margin is gone from the base rule rather
    # than overridden in the narrow query, so there is no single-line declaration left to match. The
    # masthead's own bottom padding is the separation.
    Assert-True ($p14.Html -notmatch 'margin: 2rem 0 0') 'sheet: the 2rem of air above the list is gone at every width'
    # THE OTHER HALF OF THE STICKY SUMMARY: closing a note puts the reader back on the row they opened,
    # instead of leaving them wherever the text they were reading used to be. Asserted as content because
    # the behaviour itself needs a browser -- what can be measured here is that the handler is on the page
    # and that it is conditional, since an unconditional jump would move a row that is already in view.
    Assert-Match 'getBoundingClientRect\(\)\.top < 0' $p14.Html 'close: closing scrolls back to the row -- and only when the row has left the viewport'
    Assert-Match "scrollIntoView\(\{ block: 'start' \}\)" $p14.Html 'close: to the top of that row, which is where it was opened'
    # The note's breathing room sits on the ARTICLE, not on its first paragraph's margin, so it does not
    # depend on whether a note opens with a paragraph, a heading or a list.
    Assert-Match '\.fold article \{ padding: 1\.1rem' $p14.Html 'article: an opened note has room above its first block'

} finally {
    Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Summary: $script:pass passed, $script:fail failed" -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
