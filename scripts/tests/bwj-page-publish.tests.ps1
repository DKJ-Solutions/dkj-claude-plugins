<#
.SYNOPSIS
    Regression tests for the shared BWJ pages worker that bwj-development ships -- its route, its
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
    reaches the network -- -DryRun and the refusals stop before the upload, and the wrangler route
    (#2569) runs against an npx.cmd shim on PATH. The API route's HTTP half stays untested, because it
    runs against somebody's account.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$PluginRoot = Join-Path $RepoRoot 'plugins\dkj-policy\bwj-development'
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

Assert-True (Test-Path -LiteralPath $WorkerPath) 'bwj-development ships worker/bwj-pages-worker.js'
Assert-True (Test-Path -LiteralPath $LibPath)    'bwj-development ships scripts/lib/page-publish-rules.ps1'
Assert-True (Test-Path -LiteralPath $ScriptPath) 'bwj-development ships scripts/task/publish-page.ps1'

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

# A RELEASE'S OWN PAGE (#3500): the index links every card to /<kind>/<token>/v<x.y.z>.
$sub = $route.Match("/notes/$HexA/v2.48.0")
Assert-True  $sub.Success                                         'the route matches a release page under the token'
Assert-Equal 'v2.48.0' $sub.Groups[3].Value                       '...capturing the release as the third group, the key suffix'
Assert-True  ($route.IsMatch("/notes/$HexA/v2.48"))               '...and the short form the page shows, which the worker reads as .0'
Assert-True  (-not $route.IsMatch("/notes/$HexA/2.48.0"))          'a release without its v is not a page'
Assert-True  (-not $route.IsMatch("/notes/$HexA/v2.48.0/x"))       'nothing below a release page is a route'
Assert-True  (-not $route.IsMatch("/notes/$HexA/../backlog"))      'nothing traversal-shaped survives under the token either'
Assert-True  (-not $route.IsMatch("/notes/$HexA/release-notes/v2.48.0")) 'the hub''s address under the token is not a route -- one of the three 404s #3500 measured'

$jsPaged = ([regex]::Match($workerJs, 'const\s+PAGED\s*=\s*new\s+Set\(\[([^\]]*)\]\)')).Groups[1].Value
$jsPagedList = @([regex]::Matches($jsPaged, '"([a-z]+)"') | ForEach-Object { $_.Groups[1].Value }) | Sort-Object
$psPagedList = @((Get-BwjPageKinds) | Where-Object { $_.Paged } | ForEach-Object { $_.Kind }) | Sort-Object
Assert-Equal ($psPagedList -join ',') ($jsPagedList -join ',') 'the lib and the worker agree which kinds are a set of pages'
Assert-True  ($workerJs -match 'release && !PAGED\.has\(kind\)') 'the worker refuses a release page under a kind that is one page'
Assert-True  ($workerJs -match '\$\{kind\}:\$\{token\}\$\{page\}') '...and reads a release page under <kind>:<token>/v<x.y.z>, the key the lib writes'

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
Assert-Equal "notes:$HexA/v2.48.0" (Get-BwjPageKvKey -Kind 'notes' -Token $HexA -Release 'v2.48.0') 'a release page''s key is <kind>:<token>/v<x.y.z>'
Assert-Throws { Get-BwjPageKvKey -Kind 'backlog' -Token $HexA -Release 'v1.0.0' } 'a kind that is one page takes no release key' '*one page, not a set*'
Assert-Throws { Get-BwjPageKvKey -Kind 'notes' -Token $HexA -Release 'v2.48' }   'a key is only written under the full x.y.z'   '*full x.y.z*'
Assert-True  (-not (Test-BwjPageRelease -Release "v2.48.0`n")) 'a release name with a trailing newline is refused -- \z, not $'
Assert-Throws { Get-BwjPageWranglerArgs -Action get -Key "notes:$HexA`n" -NamespaceId $HexB } '...and so is a key with one, before it reaches the cmd.exe line'
Assert-Equal "wrangler kv key get notes:$HexA/v2.48.0 --namespace-id $HexB --remote" ((Get-BwjPageWranglerArgs -Action get -Key "notes:$HexA/v2.48.0" -NamespaceId $HexB) -join ' ') 'wrangler takes a release page''s key'

Write-Host ''
Write-Host 'The links of a set of pages (#3500)' -ForegroundColor Cyan

$r = "/notes/$HexA"
$hubPage = '<a class="back" href="/release-notes">x</a><a class="card" href="/release-notes/v2.48.0">y</a><a href="/release-notes-old">z</a><a href="https://e.com/release-notes">w</a>'
$moved = Convert-BwjPageLinks -Html $hubPage -FromBase '/release-notes' -ToBase $r
Assert-True ($moved -like "*href=`"$r`"*")           'the back link moves onto the route'
Assert-True ($moved -like "*href=`"$r/v2.48.0`"*")   '...and a card onto the release page under it'
Assert-True ($moved -like '*href="/release-notes-old"*') 'an address that only starts with the same characters is left alone'
Assert-True ($moved -like '*href="https://e.com/release-notes"*') '...and so is another site'
$dead = @(Find-BwjDeadPageLinks -Html $moved -Route $r -Releases @('v2.48.0'))
Assert-Equal '/release-notes-old' ($dead -join ',') 'the dead-link scan names the one site-absolute link the worker will not serve'
$deadMissing = @(Find-BwjDeadPageLinks -Html $moved.Replace('/release-notes-old', '/x') -Route $r -Releases @())
Assert-True ($deadMissing -contains "$r/v2.48.0") 'a card whose release page is not in the set is dead -- the 404 #3500 measured'
Assert-Equal 0 @(Find-BwjDeadPageLinks -Html '<a href="#top">t</a><a href="v1.html">r</a>' -Route $r -Releases @()).Count 'fragments and relative links are not its business'

Assert-Equal "https://p.workers.dev/notes/$HexA" (Get-BwjPageUrl -BaseUrl 'https://p.workers.dev' -Kind 'notes' -Token $HexA) 'the URL is the origin plus the route'
Assert-Equal "https://p.workers.dev/notes/$HexA" (Get-BwjPageUrl -BaseUrl 'https://p.workers.dev/' -Kind 'notes' -Token $HexA) '...and a trailing slash on the origin costs nothing'

# THE CUT'S CLOSE-OUT CARRIES THE NOTES LINK (#2913), printed on both verified exit paths, never on -DryRun.
$coUrl = "https://p.workers.dev/notes/$HexA"
Assert-True ((Format-BwjPageCloseOut -Kind 'notes' -Url $coUrl) -like "Close-out:*$coUrl") 'a verified notes publish prints the close-out line ending in the URL'
Assert-Equal '' (Format-BwjPageCloseOut -Kind 'backlog' -Url $coUrl) 'the backlog page is no cut''s receipt, so it prints none'
$ppSrc = Get-Content -LiteralPath (Join-Path $RepoRoot 'plugins\dkj-policy\bwj-development\scripts\task\publish-page.ps1') -Raw
Assert-Equal 1 ([regex]::Matches($ppSrc, 'Format-BwjPageCloseOut -Kind \$Kind -Url \$url')).Count 'one verified exit path, shared by wrangler and the KV API, prints it'

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

Write-Host ''
Write-Host 'The wrangler route, when CLOUDFLARE_API_TOKEN is absent (#2569)' -ForegroundColor Cyan

# The decision, as a pure function. The measured fact it rests on: whoami exits 0 logged in or not.
Assert-True (Test-BwjWranglerSession -WhoamiText "| Acct | $HexA |" -ExitCode 0 -AccountId $HexA) 'a whoami naming the seam''s account is a session for it'
Assert-True (-not (Test-BwjWranglerSession -WhoamiText 'You are not authenticated.' -ExitCode 0 -AccountId $HexA)) 'exit 0 without the account id is not a session -- whoami exits 0 logged out too'
Assert-True (-not (Test-BwjWranglerSession -WhoamiText "| Acct | $HexB |" -ExitCode 0 -AccountId $HexA)) 'a login to ANOTHER account is not a route to this one'
Assert-True (-not (Test-BwjWranglerSession -WhoamiText "| Acct | $HexA |" -ExitCode 1 -AccountId $HexA)) 'a failed whoami is not a session, whatever it printed'
Assert-True (-not (Test-BwjWranglerSession -WhoamiText $null -ExitCode $null -AccountId $HexA)) 'no answer at all is not a session'

$putArgs = Get-BwjPageWranglerArgs -Action put -Key "notes:$HexA" -NamespaceId $HexB -Path 'C:\x\p.html'
Assert-Equal "wrangler kv key put notes:$HexA --path C:\x\p.html --namespace-id $HexB --remote" ($putArgs -join ' ') 'the put names the file, the namespace and --remote'
$getArgs = Get-BwjPageWranglerArgs -Action get -Key "notes:$HexA" -NamespaceId $HexB
Assert-Equal "wrangler kv key get notes:$HexA --namespace-id $HexB --remote" ($getArgs -join ' ') 'the get reads raw bytes -- no --text, which would decode them before the hash'
Assert-Throws { Get-BwjPageWranglerArgs -Action get -Key 'notes:--oops' -NamespaceId $HexB } 'a key this lib did not build is refused before it reaches the CLI'

# END TO END, against an npx.cmd shim on PATH that plays wrangler: whoami prints an account table,
# put copies the --path file into a store, get types the store back. Every call is logged with the
# CLOUDFLARE_ACCOUNT_ID the child saw, so the route is asserted and not merely its summary line.
$shimDir = Join-Path $Fixture 'shim-bin'
New-Item -ItemType Directory -Path $shimDir -Force | Out-Null
$shimStore = Join-Path $Fixture 'shim-kv.bin'
$shimLog   = Join-Path $Fixture 'shim-log.txt'
$shimList  = Join-Path $Fixture 'shim-list.json'
$shim = "@echo off`r`n" +
        "echo %* [acct=%CLOUDFLARE_ACCOUNT_ID%]>>`"%FAKE_WRANGLER_LOG%`"`r`n" +
        "if `"%~3`"==`"whoami`" ( echo ^| Account ^| %FAKE_WRANGLER_ACCOUNT% ^| & exit /b 0 )`r`n" +
        "if `"%~5`"==`"put`" ( copy /y `"%~8`" `"%FAKE_WRANGLER_STORE%`" >nul & exit /b 0 )`r`n" +
        "if `"%~5`"==`"get`" goto get`r`n" +
        "if `"%~5`"==`"list`" ( type `"%FAKE_WRANGLER_LISTFILE%`" & exit /b 0 )`r`n" +
        "if `"%~5`"==`"delete`" goto del`r`n" +
        "exit /b 9`r`n" +
        ":get`r`n" +
        "if `"%FAKE_WRANGLER_TAMPER%`"==`"1`" ( echo tampered ) else ( type `"%FAKE_WRANGLER_STORE%`" )`r`n" +
        "exit /b 0`r`n" +
        ":del`r`n" +
        "if not `"%FAKE_WRANGLER_KEEP%`"==`"1`" echo []>`"%FAKE_WRANGLER_LISTFILE%`"`r`n" +
        "exit /b 0`r`n"
[System.IO.File]::WriteAllText((Join-Path $shimDir 'npx.cmd'), $shim, (New-Object System.Text.ASCIIEncoding))

function Invoke-WranglerRoute {
    # -ScriptArgs replaces the publish's own arguments, for the -RetireToken cases (#3506); -Keep makes the
    # shim's delete leave the listing as it was, the lagging-listing case.
    param([string]$Account, [string]$Tamper = '', [string]$HtmlPath = '', [string[]]$ScriptArgs = @(), [string]$Keep = '')
    $saved = @{}
    foreach ($n in 'PATH', 'CLOUDFLARE_API_TOKEN', 'FAKE_WRANGLER_ACCOUNT', 'FAKE_WRANGLER_STORE', 'FAKE_WRANGLER_LOG', 'FAKE_WRANGLER_TAMPER', 'FAKE_WRANGLER_LISTFILE', 'FAKE_WRANGLER_KEEP') {
        $saved[$n] = [Environment]::GetEnvironmentVariable($n, 'Process')
    }
    try {
        $env:PATH = "$shimDir;$($saved['PATH'])"
        [Environment]::SetEnvironmentVariable('CLOUDFLARE_API_TOKEN', $null, 'Process')
        $env:FAKE_WRANGLER_ACCOUNT = $Account
        $env:FAKE_WRANGLER_STORE = $shimStore
        $env:FAKE_WRANGLER_LOG = $shimLog
        $env:FAKE_WRANGLER_TAMPER = $Tamper
        $env:FAKE_WRANGLER_LISTFILE = $shimList
        $env:FAKE_WRANGLER_KEEP = $Keep
        if (Test-Path -LiteralPath $shimLog) { Remove-Item -LiteralPath $shimLog -Force }
        $a = @('-Kind', 'notes')
        if ($HtmlPath) { $a += @('-Html', $HtmlPath) }
        if ($ScriptArgs.Count) { $a = $ScriptArgs }
        return (Invoke-PublishPage -ScriptArgs $a)
    } finally {
        foreach ($n in $saved.Keys) { [Environment]::SetEnvironmentVariable($n, $saved[$n], 'Process') }
    }
}

$viaWrangler = Invoke-WranglerRoute -Account $HexA
$log = if (Test-Path -LiteralPath $shimLog) { [System.IO.File]::ReadAllText($shimLog) -replace '"', '' } else { '' }
Assert-Equal 0 $viaWrangler.ExitCode 'no API token, a wrangler login to this account: the page is published'
Assert-True ($viaWrangler.Text -like '*SHA-256 matches*') '...and the read-back proof still ran'
Assert-True ($log -like "*kv key put notes:$writtenToken --path *--namespace-id $HexB --remote*") '...the upload went through wrangler kv key put, --remote'
Assert-True ($log -like "*kv key get notes:$writtenToken --namespace-id $HexB --remote*") '...and the read-back through kv key get'
Assert-True ($log -like "*[acct=$HexA]*") '...with CLOUDFLARE_ACCOUNT_ID set to the seam''s account for the child'
Assert-Equal (Get-FileHash -LiteralPath $pageFile -Algorithm SHA256).Hash (Get-FileHash -LiteralPath $shimStore -Algorithm SHA256).Hash '...and the bytes that landed are the built page'

$wrongAccount = Invoke-WranglerRoute -Account $HexB
$log = if (Test-Path -LiteralPath $shimLog) { [System.IO.File]::ReadAllText($shimLog) -replace '"', '' } else { '' }
Assert-True ($wrongAccount.ExitCode -ne 0) 'a wrangler login to another account is refused'
Assert-True ($wrongAccount.Text -like '*Either route publishes*') '...and the refusal names both routes'
Assert-True ($log -notlike '*kv key put*') '...before anything was uploaded'

$tampered = Invoke-WranglerRoute -Account $HexA -Tamper '1'
Assert-True ($tampered.ExitCode -ne 0) 'a read-back through wrangler that differs from the upload fails the publish'
Assert-True ($tampered.Text -like '*different bytes than were uploaded*') '...naming both hashes, as the API route does'

# THE CMD.EXE LINE (Sebastian, on this branch): a legal file name with '&' and no space once ran a
# second command. Every argument is now quoted, so the publish from such a path must simply succeed.
$ampPage = Join-Path $Fixture 'releases\page\notes&x.html'
Copy-Item -LiteralPath $pageFile -Destination $ampPage
$amp = Invoke-WranglerRoute -Account $HexA -HtmlPath $ampPage
Assert-Equal 0 $amp.ExitCode "a page path carrying '&' and no space publishes as one argument, not as a second command"
Assert-True ($amp.Text -like '*SHA-256 matches*') '...and is verified like any other'
Assert-True (-not (Test-BwjWranglerSession -WhoamiText ('c' + $HexA + 'c') -ExitCode 0 -AccountId $HexA)) 'the account id inside a longer hex run is not a match'

Write-Host ''
Write-Host 'A set of pages, end to end (#3500)' -ForegroundColor Cyan

# A SET THROUGH THE WRANGLER ROUTE: every page is put and read back under its own key, the index last.
$setDir = Join-Path $Fixture 'set'
New-Item -ItemType Directory -Path (Join-Path $setDir 'release-notes') -Force | Out-Null
$setIndex = Join-Path $setDir 'release-notes.html'
[System.IO.File]::WriteAllText($setIndex, '<!doctype html><a class="card" href="/release-notes/v1.0.0">1.0</a>', $Utf8NoBom)
[System.IO.File]::WriteAllText((Join-Path $setDir 'release-notes\v1.0.0.html'), '<!doctype html><a class="back" href="/release-notes">All</a>', $Utf8NoBom)
$set = Invoke-WranglerRoute -Account $HexA -HtmlPath $setIndex
$log = if (Test-Path -LiteralPath $shimLog) { [System.IO.File]::ReadAllText($shimLog) -replace '"', '' } else { '' }
Assert-Equal 0 $set.ExitCode 'an index and its release page publish as one set'
Assert-True ($set.Text -like '*2 page(s)*SHA-256 matches*') '...both verified by their read-back'
$putPage  = $log.IndexOf("kv key put notes:$writtenToken/v1.0.0 ")
$putIndex = $log.IndexOf("kv key put notes:$writtenToken --path")
Assert-True ($putPage -ge 0 -and $putIndex -gt $putPage) '...the release page under <kind>:<token>/v1.0.0 first, the index last'
Assert-True ($log -like "*kv key get notes:$writtenToken/v1.0.0 --namespace-id*") '...each read back under its own key'
Assert-True ([System.IO.File]::ReadAllText($shimStore) -like "*href=`"/notes/$writtenToken/v1.0.0`"*") '...and what landed links to the worker''s route, not the hub''s'
Assert-True ([System.IO.File]::ReadAllText($setIndex) -like '*href="/release-notes/v1.0.0"*') 'the built page itself is left as the hub serves it'
$stages = @(Get-ChildItem -LiteralPath ([System.IO.Path]::GetTempPath()) -Directory -Filter 'bwj-page-stage-*' -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-2) -and (Test-Path (Join-Path $_.FullName 'v1.0.0.html')) })
Assert-Equal 0 $stages.Count '...and no staged copy of a private page is left in the temp directory'

Remove-Item -LiteralPath (Join-Path $setDir 'release-notes\v1.0.0.html') -Force
$broken = Invoke-WranglerRoute -Account $HexA -HtmlPath $setIndex
$log = if (Test-Path -LiteralPath $shimLog) { [System.IO.File]::ReadAllText($shimLog) } else { '' }
Assert-True ($broken.ExitCode -ne 0) 'an index whose release page is missing is refused -- the 404 #3500 measured'
Assert-True ($broken.Text -like "*/notes/$writtenToken/v1.0.0*") '...naming the link that would have led nowhere'
Assert-True ($log -notlike '*kv key put*') '...before anything was uploaded'

# WHAT THE BUILDER LINKS TO HAS TO BE SOMETHING THE WORKER SERVES -- asked for in #3500 itself. The real
# builder, over this repo's own release notes, into the fixture; then the publish's own guard, and the
# worker's own route over every link it would put live.
$builder = Join-Path $RepoRoot 'scripts\release\build-release-notes-page.ps1'
$builtIndex = Join-Path $Fixture 'built\release-notes.html'
$null = & powershell -NoProfile -ExecutionPolicy Bypass -File $builder -OutFile $builtIndex 2>&1
Assert-True (Test-Path -LiteralPath $builtIndex) 'the release-notes builder writes an index for the publish to read'
$builtPages = @(Get-ChildItem -LiteralPath (Join-Path $Fixture 'built\release-notes') -Filter 'v*.html' -File -ErrorAction SilentlyContinue)
Assert-True ($builtPages.Count -gt 0) '...and a page per release beside it'
$builtDry = Invoke-PublishPage -ScriptArgs @('-Kind', 'notes', '-Html', $builtIndex, '-DryRun')
Assert-Equal 0 $builtDry.ExitCode 'the builder''s own output passes the publish''s dead-link guard'
Assert-True ($builtDry.Text -like "*$($builtPages.Count) page(s), each under notes:$writtenToken/v<x.y.z>*") '...as the whole set, every release page counted'
$routeMisses = New-Object System.Collections.Generic.List[string]
foreach ($p in @($builtPages) + @(Get-Item -LiteralPath $builtIndex)) {
    $html = Convert-BwjPageLinks -Html ([System.IO.File]::ReadAllText($p.FullName)) -FromBase (Get-BwjNotesLinkBase) -ToBase "/notes/$HexA"
    foreach ($m in [regex]::Matches($html, 'href="(/(?!/)[^"]*)"')) {
        if (-not $route.IsMatch($m.Groups[1].Value)) { $routeMisses.Add($m.Groups[1].Value) }
    }
}
Assert-Equal '' (($routeMisses | Select-Object -Unique) -join ', ') 'every site-absolute link in the built set matches the worker''s own route'

# The default page per kind is the file the builder leaves behind, so the ordinary run takes no -Html.
$backlogInit = Invoke-PublishPage -ScriptArgs @('-Kind', 'backlog', '-InitToken')
Assert-Equal 0 $backlogInit.ExitCode 'the second kind gets a token of its own'
$backlogTokenFile = Join-Path $Fixture 'releases\page\page-token-backlog.txt'
$backlogToken = ([System.IO.File]::ReadAllText($backlogTokenFile)).Trim()
Assert-True ($backlogToken -ne $writtenToken) '...a DIFFERENT one, which is what keeps two pages on one worker apart'
$missingPage = Invoke-PublishPage -ScriptArgs @('-Kind', 'backlog', '-DryRun')
Assert-True ($missingPage.ExitCode -ne 0) 'a kind whose page has not been built yet is refused'
Assert-True ($missingPage.Text -like '*it does not build one*') '...and the refusal says this script publishes a page rather than building one'
[System.IO.File]::WriteAllText((Join-Path $Fixture 'releases\page\minor-backlog.html'), '<!doctype html><title>b</title>', $Utf8NoBom)
$backlogLinkBase = Invoke-PublishPage -ScriptArgs @('-Kind', 'backlog', '-LinkBase', '/x', '-DryRun')
Assert-True ($backlogLinkBase.ExitCode -ne 0 -and $backlogLinkBase.Text -like '*-LinkBase applies to a set of pages*') '-LinkBase on a kind that is one page is refused rather than ignored'

$emit = Invoke-PublishPage -ScriptArgs @('-EmitWorker')
Assert-Equal 0 $emit.ExitCode '-EmitWorker writes the bundle for the one-time deploy'
$emitted = Join-Path $Fixture 'releases\page\worker.js'
Assert-True (Test-Path -LiteralPath $emitted) '...copying the worker out of the plugin'
Assert-Equal (Get-FileHash -LiteralPath $WorkerPath -Algorithm SHA256).Hash (Get-FileHash -LiteralPath $emitted -Algorithm SHA256).Hash 'the emitted bundle is byte-identical to the shipped source -- nothing per-store is written into it'
$toml = [System.IO.File]::ReadAllText((Join-Path $Fixture 'releases\page\wrangler.toml'))
Assert-True ($toml -like '*name = "bwj-pages"*')  'the wrangler.toml deploys the worker the seam names'
Assert-True ($toml -like "*id = `"$HexB`"*")      '...and binds the namespace the seam names'
Assert-True ($toml -like '*binding = "BWJ_PAGES"*') '...under the binding the worker reads'
# npx.cmd on Windows, where 'npx' resolves to npx.ps1 and the default execution policy blocks it; and
# no '&&', which Windows PowerShell 5.1 cannot parse (#2651).
$npx = if ($env:OS -eq 'Windows_NT') { 'npx.cmd' } else { 'npx' }
Assert-True ($emit.Text -like "*$npx wrangler deploy*") "it names the deploy command, as $npx, and deploys nothing itself"
Assert-True ($emit.Text -notlike '*&&*') '...on lines of their own, not joined with && (a parse error in Windows PowerShell 5.1)'
Assert-True ($emit.Text -like '*neither deploy can disturb a page the other store published*') '...and states the property that makes the worker shareable'

Write-Host ''
Write-Host 'Retiring a leaked token (#3506)' -ForegroundColor Cyan

# THE HAZARD: a fresh token changes the URL the next publish prints, and every key under the old token
# goes on serving to whoever holds the leaked link. Retiring is deleting those keys.
$tok = $writtenToken
$listed = @("notes:$tok", "notes:$tok/v1.0.0", "notes:$tok/x", "notes:$HexA", "backlog:$tok")
Assert-Equal "notes:$tok,notes:$tok/v1.0.0" ((Select-BwjTokenKeys -Names $listed -Kind 'notes' -Token $tok) -join ',') 'a retirement takes the index and its release pages, and nothing a listing returned besides'
Assert-Equal "backlog:$tok" ((Select-BwjTokenKeys -Names $listed -Kind 'backlog' -Token $tok) -join ',') '...and a kind that is one page takes its one key'
Assert-Equal 'a,b' ((ConvertFrom-BwjWranglerKeyList -Text '[{"name":"a"},{"name":"b","metadata":{}}]') -join ',') 'wrangler''s listing is read as its key names'
Assert-Equal 0 @(ConvertFrom-BwjWranglerKeyList -Text "[]`r`n").Count '...and an empty one as none'
Assert-Equal 'a' ((ConvertFrom-BwjWranglerKeyList -Text "banner`n[{`"name`":`"a`"}]`n") -join ',') '...with a line around the array ignored'
Assert-Throws { ConvertFrom-BwjWranglerKeyList -Text 'You are not authenticated.' } 'an unreadable listing throws -- it must never read as "no keys left"' '*no JSON array*'
Assert-Equal "wrangler kv key list --prefix notes:$tok --namespace-id $HexB --remote" ((Get-BwjPageWranglerListArgs -Prefix "notes:$tok" -NamespaceId $HexB) -join ' ') 'the listing names the prefix, the namespace and --remote'
Assert-Throws { Get-BwjPageWranglerListArgs -Prefix 'notes:' -NamespaceId $HexB } 'a prefix shorter than one token is refused -- it would list every token''s keys'
Assert-Equal "wrangler kv key delete notes:$tok/v1.0.0 --namespace-id $HexB --remote" ((Get-BwjPageWranglerArgs -Action delete -Key "notes:$tok/v1.0.0" -NamespaceId $HexB) -join ' ') 'the delete names one key this lib builds'
$keysUrl = Get-BwjPageKvKeysApiUrl -AccountId $HexA -NamespaceId $HexB -Prefix "notes:$tok" -Cursor 'c/1'
Assert-True ($keysUrl -like "https://api.cloudflare.com/client/v4/accounts/$HexA/storage/kv/namespaces/$HexB/keys?limit=1000&prefix=notes%3A$tok&cursor=c%2F1") 'the API listing addresses the prefix and the cursor, escaped'

$alone = Invoke-PublishPage -ScriptArgs @('-Kind', 'notes', '-Token', $HexA)
Assert-True ($alone.ExitCode -ne 0 -and $alone.Text -like '*on its own it does nothing*') '-Token without -RetireToken is refused rather than ignored'

[System.IO.File]::WriteAllText($shimList, ('[' + (($listed | ForEach-Object { "{`"name`":`"$_`"}" }) -join ',') + ']'), $Utf8NoBom)
$retireDry = Invoke-WranglerRoute -Account $HexA -ScriptArgs @('-Kind', 'notes', '-RetireToken', '-DryRun')
$log = if (Test-Path -LiteralPath $shimLog) { [System.IO.File]::ReadAllText($shimLog) -replace '"', '' } else { '' }
Assert-Equal 0 $retireDry.ExitCode '-RetireToken -DryRun lists the keys and deletes nothing'
Assert-True ($retireDry.Text -like '*2 under notes:*') '...counting only the keys of this token'
Assert-True ($log -like "*kv key list --prefix notes:$tok --namespace-id $HexB --remote*") '...listed through wrangler, --remote'
Assert-True ($log -notlike '*kv key delete*') '...with no delete'
Assert-True (Test-Path -LiteralPath $tokenFile) '...and the token file as it was'

$lagging = Invoke-WranglerRoute -Account $HexA -ScriptArgs @('-Kind', 'notes', '-RetireToken') -Keep '1'
Assert-True ($lagging.ExitCode -ne 0) 'keys that still list after the deletes fail the retirement'
Assert-True ($lagging.Text -like '*still list*run -RetireToken again*') '...saying to run it again'
Assert-True (Test-Path -LiteralPath $tokenFile) '...and keeping the token file, so the rerun starts from the same token'

$retire = Invoke-WranglerRoute -Account $HexA -ScriptArgs @('-Kind', 'notes', '-RetireToken')
$log = if (Test-Path -LiteralPath $shimLog) { [System.IO.File]::ReadAllText($shimLog) -replace '"', '' } else { '' }
Assert-Equal 0 $retire.ExitCode '-RetireToken deletes every key under the token'
$delIndex = $log.IndexOf("kv key delete notes:$tok --namespace-id")
$delPage  = $log.IndexOf("kv key delete notes:$tok/v1.0.0 --namespace-id")
Assert-True ($delIndex -ge 0 -and $delPage -gt $delIndex) '...the index first, the page the leaked link opens on, then the release page'
Assert-True ($log -notlike "*kv key delete notes:$tok/x*" -and $log -notlike "*kv key delete notes:$HexA*" -and $log -notlike '*kv key delete backlog:*') '...and no key the lib did not write for this token'
Assert-True ($retire.Text -like '*no key lists under*') '...proved by listing again'
Assert-True (-not (Test-Path -LiteralPath $tokenFile)) '...and only then the token file is removed'
Assert-True ($retire.Text -like '*-InitToken for a fresh path*') '...naming the next step'

$nothing = Invoke-WranglerRoute -Account $HexA -ScriptArgs @('-Kind', 'notes', '-RetireToken')
Assert-True ($nothing.ExitCode -ne 0 -and $nothing.Text -like '*Name the leaked one with -Token*') 'with no token on file and none named, there is nothing to retire'

$reinit = Invoke-PublishPage -ScriptArgs @('-Kind', 'notes', '-InitToken')
Assert-Equal 0 $reinit.ExitCode 'after a retirement -InitToken mints the next token'

# THE TOKEN MINTED BEFORE THE OLD KEYS WERE DELETED -- the case the issue measured: -Token names the old one.
[System.IO.File]::WriteAllText($shimList, "[{`"name`":`"notes:$tok`"}]", $Utf8NoBom)
$old = Invoke-WranglerRoute -Account $HexA -ScriptArgs @('-Kind', 'notes', '-RetireToken', '-Token', $tok)
$log = if (Test-Path -LiteralPath $shimLog) { [System.IO.File]::ReadAllText($shimLog) -replace '"', '' } else { '' }
Assert-Equal 0 $old.ExitCode '-RetireToken -Token retires a token that is no longer the one on file'
Assert-True ($log -like "*kv key delete notes:$tok --namespace-id*") '...deleting its keys'
Assert-True (Test-Path -LiteralPath $tokenFile) '...and leaving the new token file alone'

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
