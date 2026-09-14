<#
.SYNOPSIS
    Publish a built HTML page to the shared BWJ pages worker -- one Cloudflare Worker serving BOTH
    store repos, with each page held in KV under its own unguessable path token.

.DESCRIPTION
    Issue #1977. The two BWJ stores must publish through ONE worker, and dkj-policy's own worker
    cannot be that one: build-release-notes-page.ps1 -Worker writes the page into the bundle as a
    literal, and `wrangler deploy` replaces the whole script -- so whichever store deploys last
    erases the other store's page, silently, while both runs report success.

    THE FIX IS THAT THE WORKER CARRIES NO CONTENT. It reads KV, one key per (kind, token). This
    script puts a page there. A redeploy of the worker from either store re-uploads byte-identical
    code and cannot touch what the other store published, which is what makes "the same worker"
    true rather than a race.

    IT DOES NOT BUILD THE PAGE. Building is somebody else's step and stays that way -- the notes
    page is dkj-policy's build-release-notes-page.ps1 run WITHOUT -Worker, which leaves
    release-notes.html in the page directory this script reads from. This script takes an HTML file
    and publishes it, so a second kind of page needs a builder and no change here.

    WHAT IT WRITES, AND WHERE. Nothing in the repo's tracked tree. The page directory is derived
    from Get-ReleaseNoteRoot exactly as dkj-policy's builder derives it -- <note root>/../page --
    because that seam already states where this repo keeps its release documents, and a second seam
    would be the same decision written twice. The path tokens live there, one file per kind.

    THE TOKEN IS AN INPUT, NEVER INVENTED. A token made up on the fly does not mean "a new path", it
    means every link already sent now 404s -- while the publish reports success. So a missing token
    is an error with a recovery instruction, and -InitToken is the separate, explicit way to make
    the first one. Same doctrine as dkj-policy's page token, for the same reason.

    AND HERE THE TOKEN IS ALSO WHAT SEPARATES THE TWO STORES. Both stores answer the same four seam
    values -- one account, one namespace, one worker, one origin -- so the token is the only thing
    that makes one store's URL not the other's. That is why it is per kind and per repo, and why a
    store repo (private, unlike the marketplace this ships from) COMMITS its tokens rather than
    gitignoring them: a tracked token is what survives a lost machine.

    THE API TOKEN IS READ FROM THE ENVIRONMENT AND FROM NOWHERE ELSE. CLOUDFLARE_API_TOKEN, never a
    seam answer and never a file in the repo, because a seam answer is committed by construction.
    It needs Workers KV Storage: Edit on the one namespace and nothing else.

    IT VERIFIES BY READING THE VALUE BACK, not by believing the upload's own response. That is the
    same lesson dkj-policy's page carries one layer up -- "verify the bytes the URL serves, never
    the deploy command's output" -- applied where it can actually be automated. Two honest limits:
    the read-back proves the write reached KV, and KV is eventually consistent, so an edge that
    already held the old value may keep serving it for up to a minute; and a reader who wants to
    know what the URL serves still has to fetch the URL.

    Pure ASCII (repo convention for .ps1).

.PARAMETER Kind
    Which page: 'notes' or 'backlog'. See page-publish-rules.ps1 for what each carries.

.PARAMETER Html
    The built page to publish. Defaults to the kind's own file in the page directory.

.PARAMETER InitToken
    Create this kind's path token when there is none. Refuses to replace one: that is the
    destructive half, and it 404s every link already sent.

.PARAMETER EmitWorker
    Write worker.js and (only when absent) wrangler.toml into the page directory, for the one-time
    `npx wrangler deploy` that puts the shared worker up. Deploys nothing itself.

.PARAMETER ShowUrl
    Print this kind's link and stop. Publishes nothing.

.PARAMETER DryRun
    Do everything except the upload -- resolve the seam, read the page, name the key and the URL.

.PARAMETER RootOverride
    The repo root, when this is not run from inside the checkout.

.EXAMPLE
    ./publish-page.ps1 -Kind notes
    Publishes the release-notes page the dkj-policy builder left in the page directory.

.EXAMPLE
    ./publish-page.ps1 -EmitWorker
    Writes the shared worker's bundle and names the deploy command.
#>
[CmdletBinding()]
param(
    [string]$Kind = 'notes',
    [string]$Html,
    [switch]$InitToken,
    [switch]$EmitWorker,
    [switch]$ShowUrl,
    [switch]$DryRun,
    [string]$RootOverride
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\lib\page-publish-rules.ps1')

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# Windows PowerShell 5.1 still negotiates TLS 1.0 by default on some hosts, and api.cloudflare.com
# refuses it. Raised rather than replaced, so nothing a host already enabled is taken away.
try {
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch { }

# --- The repo root ---------------------------------------------------------------------------------
# Deliberately self-contained: this plugin's scripts dot-source nothing outside their own folder, so
# a store can forward to them from the plugin cache without pulling a second plugin's libs along.
function Resolve-RepoRoot {
    param([string]$Override)
    if ($Override) {
        if (-not (Test-Path -LiteralPath $Override -PathType Container)) {
            throw "-RootOverride is not a directory: $Override"
        }
        return (Resolve-Path -LiteralPath $Override).Path
    }
    # `2>$null` ON A NATIVE COMMAND IS A TRAP UNDER EAP=Stop, and this script runs under it: git
    # writes to stderr in the ordinary case here -- a run started outside a work tree -- and
    # PowerShell turns each of those lines into a terminating error, so the fallback below would
    # never be reached. The repo-wide guard in scripts/tests/shared-scripts.tests.ps1 refuses an
    # unprotected redirect and exonerates exactly this wrapper; it caught this line.
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $top  = & git rev-parse --show-toplevel 2>$null
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prev
    }
    if ($code -eq 0 -and $top) { return ((@($top)[0]) -replace '/', '\').Trim() }
    return (Get-Location).Path
}
$repoRoot = Resolve-RepoRoot -Override $RootOverride

# --- The repo's own answers ------------------------------------------------------------------------
# Read in a CHILD scope with StrictMode explicitly OFF, the same way dkj-policy's builder reads its
# seam: this script runs under StrictMode Latest while repo-config.ps1 is written on the assumption
# that its callers do not.
$config = & {
    Set-StrictMode -Off
    $answers = @{ NoteRoot = 'releases/notes'; Pages = $null }
    $configPath = Join-Path $args[0] 'scripts\repo-config.ps1'
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        throw ("This repo has no scripts\repo-config.ps1, so it has answered neither where its " +
               "release documents live nor which worker it publishes to. Run adopt-dkj-policy-bwj.")
    }
    . $configPath
    # NOT Get-Command: it parses the name as a wildcard pattern and pays a full PATH scan on every
    # miss -- and a miss is the normal case for an optional seam (source repo issue #1729, which
    # moved every probe in that tree onto this idiom). Written out here rather than dot-sourced from
    # command-probe-lib.ps1, because this plugin's scripts deliberately pull in nothing outside their
    # own folder: a store forwards to them from the plugin cache without a second plugin's libs.
    $defined = { param($Name) [bool](@($ExecutionContext.InvokeCommand.GetCommands($Name, 'Function', $false)).Count) }
    if (& $defined 'Get-ReleaseNoteRoot')  { $answers.NoteRoot = Get-ReleaseNoteRoot }
    if (& $defined 'Get-BwjPagesConfig')   { $answers.Pages    = Get-BwjPagesConfig }
    return $answers
} $repoRoot

$pages = Resolve-BwjPagesConfig -Config $config.Pages

$noteRoot = Join-Path $repoRoot ($config.NoteRoot -replace '/', '\')
$pageDir  = Join-Path (Split-Path -Parent $noteRoot) 'page'
if (-not (Test-Path -LiteralPath $pageDir)) { New-Item -ItemType Directory -Force -Path $pageDir | Out-Null }

Write-Host ""
Write-Host "== publish-page ($($pages.Worker)) ==" -ForegroundColor Cyan
Write-Host "  page dir : $pageDir" -ForegroundColor DarkGray

# --- -EmitWorker: the shared worker's bundle --------------------------------------------------------
if ($EmitWorker) {
    $source = Join-Path $PSScriptRoot '..\..\worker\bwj-pages-worker.js'
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "The worker source is missing from this plugin: $source"
    }
    $workerPath = Join-Path $pageDir 'worker.js'
    Copy-Item -LiteralPath $source -Destination $workerPath -Force
    Write-Host "  worker   : $workerPath (copied from the plugin -- it carries no page content)" -ForegroundColor Green

    # WRITTEN ONLY WHEN ABSENT, the same doctrine dkj-policy's builder states for its own: a consumer
    # edits this file -- an account id, a custom domain, a route -- and regenerating it every run
    # would silently discard that. A value that has drifted from the seam is reported, not corrected,
    # because which of the two is wrong is not this script's to decide.
    $wranglerPath = Join-Path $pageDir 'wrangler.toml'
    if (-not (Test-Path -LiteralPath $wranglerPath -PathType Leaf)) {
        $wrangler = @"
name = "$($pages.Worker)"
main = "worker.js"
compatibility_date = "2025-04-01"
workers_dev = true

# The pages themselves live here, one key per '<kind>:<token>'. The worker holds no content of its
# own, which is what lets BOTH BWJ store repos deploy this same worker without either one erasing
# the other's page.
[[kv_namespaces]]
binding = "BWJ_PAGES"
id = "$($pages.NamespaceId)"

# No account_id on purpose: one more identifier to keep out of a file, and wrangler resolves the
# account from CLOUDFLARE_ACCOUNT_ID or from the token when it has only one.
"@
        [System.IO.File]::WriteAllText($wranglerPath, $wrangler, $Utf8NoBom)
        Write-Host "  wrangler : $wranglerPath (written -- it is yours from now on, never overwritten)" -ForegroundColor Yellow
    } else {
        $text = [System.IO.File]::ReadAllText($wranglerPath, [System.Text.Encoding]::UTF8)
        $declaredName = [regex]::Match($text, '(?m)^\s*name\s*=\s*"([^"]+)"')
        if ($declaredName.Success -and $declaredName.Groups[1].Value -ne $pages.Worker) {
            Write-Warning ("wrangler.toml deploys '$($declaredName.Groups[1].Value)' while " +
                           "Get-BwjPagesConfig says '$($pages.Worker)'. One of the two is wrong -- " +
                           "this script does not pick. Deploying the wrong name puts a SECOND worker " +
                           "up, which is the one thing the shared design exists to avoid.")
        }
        if ($text -notmatch [regex]::Escape($pages.NamespaceId)) {
            Write-Warning ("wrangler.toml does not bind the namespace Get-BwjPagesConfig names " +
                           "($($pages.NamespaceId)). A worker bound to another namespace answers 404 " +
                           "for every page this script publishes.")
        }
        Write-Host "  wrangler : $wranglerPath (left as it is)" -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "  Next:  cd `"$pageDir`"  &&  npx wrangler deploy" -ForegroundColor Cyan
    Write-Host "  This is the SHARED worker: deploying it from either store repo is the same act, and" -ForegroundColor DarkGray
    Write-Host "  neither deploy can disturb a page the other store published -- the pages are in KV." -ForegroundColor DarkGray
    exit 0
}

# --- The kind, the token and the URL ----------------------------------------------------------------
if (-not (Test-BwjPageKind -Kind $Kind)) {
    $known = (Get-BwjPageKinds | ForEach-Object { "$($_.Kind) -- $($_.What)" }) -join "`n           "
    throw "'$Kind' is not a kind this worker routes. The kinds are:`n           $known"
}

$tokenPath = Join-Path $pageDir (Get-BwjPageTokenFileName -Kind $Kind)

if ($InitToken) {
    if (Test-Path -LiteralPath $tokenPath -PathType Leaf) {
        throw ("A path token for '$Kind' already exists at $tokenPath. This script does not replace " +
               "one: the URL carrying it has been sent, so a new token means every existing link " +
               "404s. Delete the file deliberately if that is really what you want.")
    }
    # THE GUARD ABOVE ASKS 'IS THERE A TOKEN HERE', WHICH IS THE WRONG QUESTION AFTER A FOLDER MOVE.
    # The page directory is derived and gitignored, so repointing the note root strands the token
    # where nothing points at it any more -- and then the check above finds nothing and mints a
    # second one happily. See Find-BwjStrayPageToken for the measurement behind that.
    $strays = @(Find-BwjStrayPageToken -Root $repoRoot -Kind $Kind -ExpectedPath $tokenPath)
    if ($strays.Count) {
        throw ("There is no token for '$Kind' at $tokenPath, but this tree already holds one: " +
               ($strays -join ', ') + ". That is almost certainly the live one, left behind by a move " +
               "of the folder this directory is derived from -- git cannot carry an ignored file along. " +
               "MOVE it here rather than minting a second token, which 404s every link already sent.")
    }
    $token = New-BwjPageToken
    [System.IO.File]::WriteAllText($tokenPath, $token, $Utf8NoBom)
    Write-Host "  token    : $tokenPath (created)" -ForegroundColor Yellow
    Write-Host "  url      : $(Get-BwjPageUrl -BaseUrl $pages.BaseUrl -Kind $Kind -Token $token)" -ForegroundColor Green
    Write-Host ""
    Write-Host "  COMMIT THIS FILE. A store repo is private, and a tracked token is what survives a" -ForegroundColor DarkGray
    Write-Host "  lost machine -- without it nothing anywhere remembers the URL you just created." -ForegroundColor DarkGray
    exit 0
}

if (-not (Test-Path -LiteralPath $tokenPath -PathType Leaf)) {
    # ONE SEARCH BEFORE THE REFUSAL IS PRINTED, because the likeliest reason it is missing HERE is
    # that it is somewhere else -- see Find-BwjStrayPageToken.
    $strays = @(Find-BwjStrayPageToken -Root $repoRoot -Kind $Kind -ExpectedPath $tokenPath)
    $lead = ''
    if ($strays.Count) {
        $lead = ("This tree already holds one, at " + ($strays -join ', ') + " -- almost certainly " +
                 "left behind by a move of the folder this directory is derived from. MOVE that file " +
                 "here; everything else in this directory rebuilds in a second and it does not. ")
    }
    throw ("The path token for '$Kind' is missing: $tokenPath. " + $lead + "This script does NOT " +
           "invent one -- the " +
           "path is the only lock on the page, so a fresh token means every link already sent 404s " +
           "while this run reports success. Three ways back, in the order worth trying: (1) restore " +
           "the 32 hex characters from the URL you have; (2) if the page is still up, the token is " +
           "readable from the KV namespace's key list in the Cloudflare dashboard, which holds " +
           "'${Kind}:<token>' for every page ever published; (3) only once both are exhausted, " +
           "-InitToken for a fresh path.")
}
$token = ([System.IO.File]::ReadAllText($tokenPath, [System.Text.Encoding]::UTF8)).Trim()
$key   = Get-BwjPageKvKey -Kind $Kind -Token $token
$url   = Get-BwjPageUrl -BaseUrl $pages.BaseUrl -Kind $Kind -Token $token

if ($ShowUrl) {
    Write-Host "  url      : $url" -ForegroundColor Green
    exit 0
}

# --- The page ----------------------------------------------------------------------------------------
if (-not $Html) {
    $default = @{ notes = 'release-notes.html'; backlog = 'minor-backlog.html' }
    $Html = Join-Path $pageDir $default[$Kind]
}
if (-not (Test-Path -LiteralPath $Html -PathType Leaf)) {
    throw ("The page to publish is missing: $Html. Build it first -- '$Kind' is built by " +
           "$((Get-BwjPageKinds | Where-Object { $_.Kind -eq $Kind }).What) -- or name another file " +
           "with -Html. This script publishes a page; it does not build one.")
}
$Html  = (Resolve-Path -LiteralPath $Html).Path
$bytes = (Get-Item -LiteralPath $Html).Length
$null  = Test-BwjPageSize -Bytes $bytes
$hash  = (Get-FileHash -LiteralPath $Html -Algorithm SHA256).Hash

Write-Host "  page     : $Html ($([math]::Round($bytes / 1KB)) KB)" -ForegroundColor DarkGray
Write-Host "  key      : $key" -ForegroundColor DarkGray
Write-Host "  url      : $url" -ForegroundColor Green

if ($DryRun) {
    Write-Host ""
    Write-Host "  -DryRun: nothing was uploaded." -ForegroundColor Yellow
    exit 0
}

# --- The upload, and the read-back that is the actual proof -------------------------------------------
$apiToken = $env:CLOUDFLARE_API_TOKEN
if ([string]::IsNullOrWhiteSpace($apiToken)) {
    throw ("CLOUDFLARE_API_TOKEN is not set. It is read from the environment and from nowhere else -- " +
           "never a seam answer, never a file in the repo, because both of those are committed by " +
           "construction. The token needs 'Workers KV Storage: Edit' on this account and nothing more.")
}
$headers  = @{ Authorization = "Bearer $apiToken" }
$valueUrl = Get-BwjPageKvApiUrl -AccountId $pages.AccountId -NamespaceId $pages.NamespaceId -Key $key

try {
    $put = Invoke-RestMethod -Method Put -Uri $valueUrl -Headers $headers -InFile $Html `
                             -ContentType 'text/plain; charset=utf-8' -TimeoutSec 120
} catch {
    # The message can carry the response body, which is Cloudflare's and safe; the token is only ever
    # in the request headers, which are not echoed here.
    throw "The upload to KV failed: $($_.Exception.Message)"
}
# READ DEFENSIVELY, because this runs under StrictMode Latest and the object comes off the network.
# A response without a 'success' field is not a success -- it is a shape nobody here has seen, and
# dying on a missing property would report it as a PowerShell fault rather than as an API answer.
$reported = $put.PSObject.Properties['success']
if ($null -eq $reported -or -not $reported.Value) {
    $why = 'the response carried no success field'
    $errs = $put.PSObject.Properties['errors']
    if ($null -ne $errs -and $errs.Value) { $why = ((@($errs.Value) | ForEach-Object { $_.message }) -join '; ') }
    throw "Cloudflare refused the upload: $why"
}
Write-Host "  upload   : accepted by the KV API" -ForegroundColor DarkGray

# THE READ-BACK IS THE PROOF, not the line above. An accepted upload and a stored value are different
# facts, and this is the one place the difference can be settled without asking a reader to open a URL.
$verifyPath = Join-Path ([System.IO.Path]::GetTempPath()) ("bwj-page-verify-" + [guid]::NewGuid().ToString('N') + '.tmp')
try {
    # -UseBasicParsing is not optional here. Without it Windows PowerShell hands the body to the
    # Internet Explorer engine to build a DOM -- and the body is a whole HTML page, which is exactly
    # the case that fails on a host where IE was never first-run ("the response content cannot be
    # parsed"). That would break the script's own correctness proof rather than the publish, which is
    # the worse half: the upload has already landed by then.
    Invoke-WebRequest -Method Get -Uri $valueUrl -Headers $headers -OutFile $verifyPath `
                      -UseBasicParsing -TimeoutSec 120 | Out-Null
    $back = (Get-FileHash -LiteralPath $verifyPath -Algorithm SHA256).Hash
    if ($back -ne $hash) {
        throw ("KV answered with different bytes than were uploaded (SHA-256 $back against $hash). " +
               "The page at the URL is NOT the file that was just built -- do not send the link on.")
    }
    Write-Host "  verified : KV holds the same $([math]::Round($bytes / 1KB)) KB that were built (SHA-256 matches)" -ForegroundColor Green
} finally {
    # THE FAILURE TO CLEAN UP IS REPORTED RATHER THAN SWALLOWED. This file is a copy of the page, and
    # in a store repo the page is private content sitting in a world-readable temp directory. A
    # locked or undeletable file is rare and is exactly the case nobody would otherwise learn about.
    Remove-Item -LiteralPath $verifyPath -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $verifyPath) {
        Write-Warning ("A copy of the published page could not be removed and is still at " +
                       "$verifyPath. Delete it: this page is not public, and that directory is.")
    }
}

Write-Host ""
Write-Host "  $url" -ForegroundColor Cyan
Write-Host "  KV is eventually consistent: an edge that already held the previous page can keep serving" -ForegroundColor DarkGray
Write-Host "  it for up to a minute. A stale first read is not a failed publish -- the read-back above" -ForegroundColor DarkGray
Write-Host "  already settled that -- so fetch again before concluding anything from one request." -ForegroundColor DarkGray
Write-Host "  The path is the ONLY lock on this page: no login, anyone with the link can read." -ForegroundColor DarkGray
exit 0
