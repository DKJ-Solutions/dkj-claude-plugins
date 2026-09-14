<#
.SYNOPSIS
    Regression tests for the shared BWJ pages worker that dkj-policy-bwj ships -- its route, its
    publish rules and the script that drives them (issue #1977).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/bwj-page-publish.tests.ps1

    WHY A SUITE HERE FOR A MECHANISM NOBODY IN THIS REPO RUNS -- the same answer
    bwj-market-urls.tests.ps1 gives. The thing being protected is a design property rather than an
    output: ONE worker serves two store repos, and it can only do that while it carries no page
    content of its own. An edit that bakes a page back into the bundle restores exactly the defect
    #1977 was filed about, and it would look like a simplification.

    WHAT IT HOLDS, and each is a way the design comes undone:

      1. THE CROSS-LANGUAGE SEAM. The kinds live in a .ps1 list and in a .js Set, and nothing but
         this suite can hold them together. A kind known to only one side publishes successfully to
         a key nothing ever serves -- a green run and a 404 somebody else finds.
      2. THE ROUTE. The worker's own regex is lifted out of the bundle and run against the cases
         that matter, so "32 lowercase hex and nothing else" is asserted against the shipped
         characters rather than against a description of them. It is what keeps a request from
         steering the KV lookup at a key of its own choosing.
      3. THE WORKER HOLDS NO CONTENT AND NO IDENTIFIERS. No page baked in, and no account id,
         namespace id or token -- this plugin ships from a PUBLIC repository.
      4. THE REFUSALS. A missing seam, a missing token, a second -InitToken. Each of the three is a
         way to publish a page nobody can reach, or to 404 every link already sent, while the run
         reports success.
      5. THE LANGUAGE. English and pure ASCII, the repo convention.

    THE SCRIPT CASES RUN IN A CHILD PROCESS against a FIXTURE REPO, never against this checkout:
    they are about what a store repo's seam answers, and this repo is not a store. Nothing in them
    reaches the network -- -DryRun and the refusals stop before the upload, which is the whole
    testable surface of a script whose remaining half is HTTP against somebody's account.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$PluginRoot = Join-Path $RepoRoot 'plugins\dkj-policy\dkj-policy-bwj'
$LibPath    = Join-Path $PluginRoot 'scripts\lib\page-publish-rules.ps1'
$ScriptPath = Join-Path $PluginRoot 'scripts\task\publish-page.ps1'
$WorkerPath = Join-Path $PluginRoot 'worker\bwj-pages-worker.js'
$Fixture    = Join-Path ([System.IO.Path]::GetTempPath()) "bwj-page-publish-fixture-$PID-$([guid]::NewGuid().ToString('n'))"

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Label)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label" -ForegroundColor Red }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Label)
    if ("$Expected" -eq "$Actual") { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}

function Assert-Throws {
    param([scriptblock]$Action, [string]$Label, [string]$MessageLike = '')
    try {
        & $Action | Out-Null
        $script:fail++; Write-Host "  [FAIL] $Label -- nothing was thrown" -ForegroundColor Red
    } catch {
        if ($MessageLike -and ($_.Exception.Message -notlike $MessageLike)) {
            $script:fail++
            Write-Host "  [FAIL] $Label -- thrown, but the message does not match '$MessageLike'`n         got: $($_.Exception.Message)" -ForegroundColor Red
        } else {
            $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green
        }
    }
}

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$HexA = 'a' * 32
$HexB = 'b' * 32

Write-Host ''
Write-Host 'The shared BWJ pages worker -- what the plugin ships (#1977)' -ForegroundColor Cyan

Assert-True (Test-Path -LiteralPath $WorkerPath) 'dkj-policy-bwj ships worker/bwj-pages-worker.js'
Assert-True (Test-Path -LiteralPath $LibPath)    'dkj-policy-bwj ships scripts/lib/page-publish-rules.ps1'
Assert-True (Test-Path -LiteralPath $ScriptPath) 'dkj-policy-bwj ships scripts/task/publish-page.ps1'

. $LibPath
$workerJs = [System.IO.File]::ReadAllText($WorkerPath, [System.Text.Encoding]::UTF8)

Write-Host ''
Write-Host 'The worker carries no content and no identifiers' -ForegroundColor Cyan

# THE DEFECT #1977 WAS FILED ABOUT, asserted as an absence. dkj-policy's worker writes
# `const HTML = "<!doctype html>..."` into the bundle, which is exactly why two repos cannot share
# it: wrangler deploy replaces the whole script.
Assert-True ($workerJs -cnotmatch '(?m)^const\s+HTML\s*=') 'no page is baked into the bundle -- that is what lets both stores deploy it'
Assert-True ($workerJs -notmatch '<!doctype|</html>')      '...and no markup of any kind sits in the shipped source'
Assert-True ($workerJs -match 'BWJ_PAGES')                    '...because it reads the pages out of KV instead'
Assert-True ($workerJs -notmatch '[0-9a-f]{32}')              'no 32-hex identifier is in the shipped source -- no account id, namespace id or token'
Assert-True ($workerJs -match 'x-robots-tag')                 'the response carries noindex, like dkj-policy page worker'
Assert-True ($workerJs -match 'no-store')                     'and no-store, because the page is a snapshot of documents that move'

Write-Host ''
Write-Host 'The route -- lifted out of the shipped bundle and run' -ForegroundColor Cyan

$routeMatch = [regex]::Match($workerJs, '(?m)^const\s+ROUTE\s*=\s*/(.+)/;\s*$')
Assert-True $routeMatch.Success 'the worker declares its route as one regex literal this suite can read'
$route = [regex]::new($routeMatch.Groups[1].Value)

Assert-True  ($route.IsMatch("/notes/$HexA"))          'the route matches /<kind>/<32 hex>'
Assert-True  ($route.IsMatch("/notes/$HexA/"))         '...and tolerates one trailing slash'
Assert-True  (-not $route.IsMatch("/notes/$($HexA.ToUpperInvariant())")) 'UPPERCASE hex is not a token -- the key it would build is one nothing serves'
Assert-True  (-not $route.IsMatch("/notes/$($HexA.Substring(1))"))       '31 characters is not a token'
Assert-True  (-not $route.IsMatch("/notes/${HexA}a"))                    '33 characters is not a token'
Assert-True  (-not $route.IsMatch('/notes/'))                            'a bare kind reaches no key at all'
Assert-True  (-not $route.IsMatch("/notes/$HexA?x=1"))                   'a query string is not part of the path the worker matches'
Assert-True  (-not $route.IsMatch("/notes/../$HexA"))                    'nothing traversal-shaped survives the route'
Assert-True  (-not $route.IsMatch("/$HexA"))                             'and a token without a kind is not a route'

Write-Host ''
Write-Host 'The cross-language seam -- the kinds the two sides know' -ForegroundColor Cyan

$jsKinds = ([regex]::Match($workerJs, 'const\s+KINDS\s*=\s*new\s+Set\(\[([^\]]*)\]\)')).Groups[1].Value
$jsKindList = @([regex]::Matches($jsKinds, '"([a-z]+)"') | ForEach-Object { $_.Groups[1].Value }) | Sort-Object
$psKindList = @((Get-BwjPageKinds).Kind) | Sort-Object
Assert-True ($jsKindList.Count -gt 0) 'the worker declares its kinds as one readable Set'
Assert-Equal ($psKindList -join ',') ($jsKindList -join ',') 'the lib and the worker route exactly the same kinds -- nothing else holds these two files together'
Assert-True ($psKindList -contains 'notes')   'the release notes are a kind'
Assert-True ($psKindList -contains 'backlog') 'the minor backlog is a kind'

Write-Host ''
Write-Host 'Tokens, keys and URLs' -ForegroundColor Cyan

Assert-True  (Test-BwjPageToken -Token $HexA)                     'a 32-hex string is a token'
Assert-True  (-not (Test-BwjPageToken -Token $HexA.ToUpperInvariant())) 'uppercase is refused rather than folded -- the worker matches lowercase only'
Assert-True  (-not (Test-BwjPageToken -Token ''))                 'an empty string is not a token'
Assert-True  (-not (Test-BwjPageToken -Token ('g' * 32)))         'non-hex is not a token'
Assert-True  (Test-BwjPageToken -Token (New-BwjPageToken))        'a freshly minted token is one this worker can route'

Assert-Equal "notes:$HexA" (Get-BwjPageKvKey -Kind 'notes' -Token $HexA) 'the KV key is <kind>:<token>'
Assert-Throws { Get-BwjPageKvKey -Kind 'invoices' -Token $HexA } 'a kind the worker does not route is refused' '*not a kind this worker routes*'
Assert-Throws { Get-BwjPageKvKey -Kind 'notes' -Token 'nope' }   'a token of the wrong shape is refused'      '*32 lowercase hex*'

Assert-Equal "https://p.workers.dev/notes/$HexA" (Get-BwjPageUrl -BaseUrl 'https://p.workers.dev' -Kind 'notes' -Token $HexA) 'the URL is the origin plus the route'
Assert-Equal "https://p.workers.dev/notes/$HexA" (Get-BwjPageUrl -BaseUrl 'https://p.workers.dev/' -Kind 'notes' -Token $HexA) '...and a trailing slash on the origin costs nothing'

$apiUrl = Get-BwjPageKvApiUrl -AccountId $HexA -NamespaceId $HexB -Key "notes:$HexA"
Assert-True ($apiUrl -like "https://api.cloudflare.com/client/v4/accounts/$HexA/storage/kv/namespaces/$HexB/values/*") 'the API URL addresses the account and the namespace by id'
Assert-True ($apiUrl -like '*notes%3A*') '...and the key is escaped in the path rather than pasted into it'

Write-Host ''
Write-Host 'The seam -- the four values both stores answer identically' -ForegroundColor Cyan

$good = @{ Worker = 'bwj-pages'; AccountId = $HexA; NamespaceId = $HexB; BaseUrl = 'https://bwj-pages.acme.workers.dev' }
$ok = Resolve-BwjPagesConfig -Config $good
Assert-Equal 'bwj-pages' $ok.Worker 'a complete answer resolves'
Assert-Equal $HexB $ok.NamespaceId  '...carrying the namespace the worker binds'

Assert-Throws { Resolve-BwjPagesConfig -Config $null } 'an unanswered seam is refused by name' '*Get-BwjPagesConfig is not answered*'
Assert-Throws { Resolve-BwjPagesConfig -Config @{ Worker = 'BWJ Pages'; AccountId = $HexA; NamespaceId = $HexB; BaseUrl = 'https://x.dev' } } 'a worker name that is not one is refused' '*not a Cloudflare Worker name*'
Assert-Throws { Resolve-BwjPagesConfig -Config @{ Worker = 'bwj-pages'; AccountId = 'nope'; NamespaceId = $HexB; BaseUrl = 'https://x.dev' } } 'an account id that is not an id is refused' '*not a Cloudflare id*'
Assert-Throws { Resolve-BwjPagesConfig -Config @{ Worker = 'bwj-pages'; AccountId = $HexA; NamespaceId = 'nope'; BaseUrl = 'https://x.dev' } } 'a namespace id that is not an id is refused' '*not a Cloudflare id*'
Assert-Throws { Resolve-BwjPagesConfig -Config @{ Worker = 'bwj-pages'; AccountId = $HexA; NamespaceId = $HexB; BaseUrl = 'http://x.dev' } } 'http is refused -- the token in the path is the lock' '*https is not negotiable*'
Assert-Throws { Resolve-BwjPagesConfig -Config @{ Worker = 'bwj-pages'; AccountId = $HexA; NamespaceId = $HexB; BaseUrl = 'https://x.dev/notes' } } 'an origin carrying a path is refused -- the path is the lib to build' '*no path*'

# A pscustomobject answer works as well as a hashtable: a store writes whichever its own repo-config
# already uses, and a seam that accepted only one shape would be a trap nobody could see.
Assert-Equal 'bwj-pages' (Resolve-BwjPagesConfig -Config ([pscustomobject]$good)).Worker 'a pscustomobject answer is read the same way as a hashtable'

Write-Host ''
Write-Host 'The size ceiling' -ForegroundColor Cyan

Assert-True (Test-BwjPageSize -Bytes 360000) 'a page the size of a real release-notes page passes'
Assert-Throws { Test-BwjPageSize -Bytes 0 } 'an empty page is refused -- publishing it would replace a good page with nothing' '*empty*'
Assert-Throws { Test-BwjPageSize -Bytes ((Get-BwjPageMaxBytes) + 1) } 'a page past Cloudflare KV value ceiling is refused before the upload' '*ceiling*'

Write-Host ''
Write-Host 'The script, against a fixture store repo' -ForegroundColor Cyan

New-Item -ItemType Directory -Path (Join-Path $Fixture 'scripts') -Force | Out-Null

function Set-FixtureConfig {
    param([string]$Body)
    [System.IO.File]::WriteAllText((Join-Path $Fixture 'scripts\repo-config.ps1'), $Body, $Utf8NoBom)
}

# STDERR GOES TO A FILE RATHER THAN INTO THE SUCCESS STREAM. Windows PowerShell wraps a native
# command's stderr into an ErrorRecord per line, which under this suite's ErrorActionPreference
# terminates the run on the very cases that are supposed to fail -- and it re-wraps the text at the
# console width, which breaks every -like over a refusal message. The file keeps the bytes as the
# script wrote them; the whitespace is then collapsed so an assertion can quote one sentence of a
# refusal without also having to reproduce where the script chose to break its lines.
function Invoke-PublishPage {
    param([string[]]$ScriptArgs)
    $errFile = Join-Path $Fixture "stderr-$([guid]::NewGuid().ToString('n')).txt"
    $all = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath, '-RootOverride', $Fixture) + $ScriptArgs
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out  = & powershell @all 2>$errFile
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prev
    }
    $err = ''
    if (Test-Path -LiteralPath $errFile) {
        $err = [System.IO.File]::ReadAllText($errFile)
        Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
    }
    $text = ((@($out) -join "`n") + "`n" + $err) -replace '\s+', ' '
    return [pscustomobject]@{ Text = $text; ExitCode = $code }
}

Set-FixtureConfig "function Get-ReleaseNoteRoot { return 'releases/notes' }"
$noSeam = Invoke-PublishPage -ScriptArgs @('-Kind', 'notes', '-ShowUrl')
Assert-True ($noSeam.ExitCode -ne 0) 'a store that has not answered Get-BwjPagesConfig cannot publish'
Assert-True ($noSeam.Text -like '*Get-BwjPagesConfig is not answered*') '...and the refusal names the function and the four values'
Assert-True ($noSeam.Text -like '*SAME four values in both*') '...and says they are the same in both stores, which is what one worker means'

Set-FixtureConfig @"
function Get-ReleaseNoteRoot { return 'releases/notes' }
function Get-BwjPagesConfig {
    return @{ Worker = 'bwj-pages'; AccountId = '$HexA'; NamespaceId = '$HexB'; BaseUrl = 'https://bwj-pages.acme.workers.dev' }
}
"@

$noToken = Invoke-PublishPage -ScriptArgs @('-Kind', 'notes', '-ShowUrl')
Assert-True ($noToken.ExitCode -ne 0) 'a kind with no path token cannot be published'
Assert-True ($noToken.Text -like '*does NOT invent one*') '...and the refusal says why a token is never invented'
Assert-True ($noToken.Text -like '*restore the 32 hex characters from the URL you have*') '...and names the ways back in the order worth trying'

$init = Invoke-PublishPage -ScriptArgs @('-Kind', 'notes', '-InitToken')
Assert-Equal 0 $init.ExitCode '-InitToken creates the first token'
$tokenFile = Join-Path $Fixture 'releases\page\page-token-notes.txt'
Assert-True (Test-Path -LiteralPath $tokenFile) '...in the page directory derived from the note root, beside the built page'
$writtenToken = ([System.IO.File]::ReadAllText($tokenFile)).Trim()
Assert-True (Test-BwjPageToken -Token $writtenToken) '...and what it wrote is a token this worker routes'
Assert-True ($init.Text -like "*https://bwj-pages.acme.workers.dev/notes/$writtenToken*") '...and the run prints the URL the token makes'
Assert-True ($init.Text -like '*COMMIT THIS FILE*') '...and says to commit it, because a store repo is private and nothing else remembers the URL'

$again = Invoke-PublishPage -ScriptArgs @('-Kind', 'notes', '-InitToken')
Assert-True ($again.ExitCode -ne 0) 'a second -InitToken is refused -- it would 404 every link already sent'
Assert-True ($again.Text -like '*already exists*') '...naming the file that already holds one'

$badKind = Invoke-PublishPage -ScriptArgs @('-Kind', 'invoices', '-ShowUrl')
Assert-True ($badKind.ExitCode -ne 0) 'a kind the worker does not route is refused before anything is written'
Assert-True ($badKind.Text -like '*notes --*') '...and the refusal lists the kinds that do exist, with what each carries'

# -DryRun is the whole of the publish path that can be asserted without an account: it resolves the
# seam, reads the page, names the key and the URL, and stops at the upload.
$pageFile = Join-Path $Fixture 'releases\page\release-notes.html'
[System.IO.File]::WriteAllText($pageFile, '<!doctype html><title>x</title>', $Utf8NoBom)
$dry = Invoke-PublishPage -ScriptArgs @('-Kind', 'notes', '-DryRun')
Assert-Equal 0 $dry.ExitCode '-DryRun resolves everything and uploads nothing'
Assert-True ($dry.Text -like "*notes:$writtenToken*") '...naming the KV key the page would land on'
Assert-True ($dry.Text -like '*nothing was uploaded*') '...and saying so'

# The default page per kind is the file the builder leaves behind, so the ordinary run takes no -Html.
$backlogInit = Invoke-PublishPage -ScriptArgs @('-Kind', 'backlog', '-InitToken')
Assert-Equal 0 $backlogInit.ExitCode 'the second kind gets a token of its own'
$backlogTokenFile = Join-Path $Fixture 'releases\page\page-token-backlog.txt'
$backlogToken = ([System.IO.File]::ReadAllText($backlogTokenFile)).Trim()
Assert-True ($backlogToken -ne $writtenToken) '...a DIFFERENT one, which is what keeps two pages on one worker apart'
$missingPage = Invoke-PublishPage -ScriptArgs @('-Kind', 'backlog', '-DryRun')
Assert-True ($missingPage.ExitCode -ne 0) 'a kind whose page has not been built yet is refused'
Assert-True ($missingPage.Text -like '*it does not build one*') '...and the refusal says this script publishes a page rather than building one'

$emit = Invoke-PublishPage -ScriptArgs @('-EmitWorker')
Assert-Equal 0 $emit.ExitCode '-EmitWorker writes the bundle for the one-time deploy'
$emitted = Join-Path $Fixture 'releases\page\worker.js'
Assert-True (Test-Path -LiteralPath $emitted) '...copying the worker out of the plugin'
Assert-Equal (Get-FileHash -LiteralPath $WorkerPath -Algorithm SHA256).Hash (Get-FileHash -LiteralPath $emitted -Algorithm SHA256).Hash 'the emitted bundle is byte-identical to the shipped source -- nothing per-store is written into it'
$toml = [System.IO.File]::ReadAllText((Join-Path $Fixture 'releases\page\wrangler.toml'))
Assert-True ($toml -like '*name = "bwj-pages"*')  'the wrangler.toml deploys the worker the seam names'
Assert-True ($toml -like "*id = `"$HexB`"*")      '...and binds the namespace the seam names'
Assert-True ($toml -like '*binding = "BWJ_PAGES"*') '...under the binding the worker reads'
Assert-True ($emit.Text -like '*npx wrangler deploy*') 'it names the deploy command and deploys nothing itself'
Assert-True ($emit.Text -like '*neither deploy can disturb a page the other store published*') '...and states the property that makes the worker shareable'

Write-Host ''
Write-Host 'The stray-token search -- #1444 lesson, ported from the sibling script' -ForegroundColor Cyan

# THE HAZARD THIS GUARDS, in one move: the page directory is derived from the note root and is
# gitignored, so repointing that folder leaves the token behind where nothing points at it. A guard
# that asks "is there a token HERE" then finds nothing and mints a second one happily -- which 404s
# every link already sent, while reporting success. dkj-policy's own page learned this as #1444; the
# new script derives its directory from the identical seam, so it inherits the identical hazard.
$strayDir = Join-Path $Fixture 'old-releases\page'
New-Item -ItemType Directory -Path $strayDir -Force | Out-Null
Move-Item -LiteralPath $tokenFile -Destination (Join-Path $strayDir 'page-token-notes.txt')

$strayInit = Invoke-PublishPage -ScriptArgs @('-Kind', 'notes', '-InitToken')
Assert-True ($strayInit.ExitCode -ne 0) '-InitToken refuses while this kind token sits elsewhere in the tree'
Assert-True ($strayInit.Text -like '*old-releases*') '...naming where it found it'
Assert-True ($strayInit.Text -like '*MOVE it here*') '...and saying to move it rather than mint a second one'

$strayPublish = Invoke-PublishPage -ScriptArgs @('-Kind', 'notes', '-DryRun')
Assert-True ($strayPublish.ExitCode -ne 0) 'the missing-token refusal runs the same search'
Assert-True ($strayPublish.Text -like '*This tree already holds one*') '...and leads with what it found rather than with the recovery list'

# SCOPED TO ONE KIND, and this is the case that decides it: every kind keeps its token in the same
# directory, so a search across all of them would report a sibling's perfectly correct token as a
# stray -- on the very run minting the second kind for the first time.
Remove-Item -LiteralPath $backlogTokenFile -Force
$otherKind = Invoke-PublishPage -ScriptArgs @('-Kind', 'backlog', '-InitToken')
Assert-Equal 0 $otherKind.ExitCode 'a stray token of ANOTHER kind is not this one -- the search is per kind'

Write-Host ''
Write-Host 'The language, and what may not be in a public repository' -ForegroundColor Cyan

foreach ($file in @($LibPath, $ScriptPath, $WorkerPath)) {
    $name  = Split-Path -Leaf $file
    $bytes = [System.IO.File]::ReadAllBytes($file)
    Assert-True (-not ($bytes | Where-Object { $_ -gt 127 })) "$name is pure ASCII (repo convention)"
}
$libText    = [System.IO.File]::ReadAllText($LibPath)
$scriptText = [System.IO.File]::ReadAllText($ScriptPath)
Assert-True ($scriptText -match 'CLOUDFLARE_API_TOKEN') 'the API token is read from the environment'
Assert-True ($scriptText -notmatch 'Get-BwjPagesApiToken') '...and there is no seam function for it -- a seam answer is committed by construction'
# A PS 5.1 trap with no visible symptom until it fires: without -UseBasicParsing, Invoke-WebRequest
# hands the body to the Internet Explorer engine to build a DOM, and the body here is a whole HTML
# page. It breaks the read-back -- the script's own correctness proof -- after the upload has landed.
Assert-True ($scriptText -match '-UseBasicParsing') 'the read-back does not route an HTML body through the IE parser'
foreach ($text in @($libText, $scriptText)) {
    Assert-True ($text -notmatch '(?<![0-9a-z])[0-9a-f]{32}(?![0-9a-z])') 'no 32-hex identifier is written into the shipped source'
}

if (Test-Path -LiteralPath $Fixture) { Remove-Item -LiteralPath $Fixture -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host ''
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
