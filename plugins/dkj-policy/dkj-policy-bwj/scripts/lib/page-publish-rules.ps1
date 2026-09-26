<#
.SYNOPSIS
    The decisions behind publishing a page to the shared BWJ pages worker -- which kinds exist, what
    a path token is, which KV key a page lands on, which URL a colleague receives, and which of the
    seam answers a store got wrong. Pure: no network, no filesystem, no repo-config.

.DESCRIPTION
    Dot-sourced by publish-page.ps1 beside it. Split out for the same reason sync-rules.ps1 and
    theme-archive-rules.ps1 are: the script around these is all HTTP against somebody's Cloudflare
    account, which a suite cannot reach, while the parts that can be WRONG are pure functions over a
    kind, a token, four seam values and a byte count.

    ISSUE #1977. The two BWJ stores must publish through ONE worker. dkj-policy's own worker cannot
    be that one: build-release-notes-page.ps1 -Worker writes the page into the bundle as a literal
    and `wrangler deploy` replaces the whole script, so whichever store deploys last erases the
    other store's page while both runs report success. The shared worker carries no content -- the
    pages sit in KV, one key per (kind, token) -- and these functions are the half of that design
    that decides.

    WHAT IS MECHANISM HERE AND WHAT IS DATA IN THE STORE. Everything in this file is mechanism and
    is identical for both stores. The four seam values are the ACCOUNT's, and they are identical in
    both stores too -- one account, one namespace, one worker, one origin. What actually differs per
    store, and the only thing that does, is the PATH TOKEN per page: the token is what makes one
    store's URL not the other store's URL, and it is why two stores can share a namespace without
    being able to read or overwrite each other's pages by accident.

    SO WHY IS THE ACCOUNT A SEAM AT ALL, if both answers are the same? Because this plugin ships from
    a PUBLIC repository. An account id, a namespace id and a workers.dev origin written as literals
    here would be published to everyone who can read the marketplace; answered in each private store
    repo's own scripts/repo-config.ps1, they are not. The seam is a confidentiality boundary rather
    than a configurability one, which is the opposite of Get-StorefrontMarkets one folder over.

    THE API TOKEN IS NOT A SEAM AND MUST NEVER BECOME ONE. It is read from the environment
    (CLOUDFLARE_API_TOKEN) by the script, never from a file in a repo and never from repo-config.
    A seam answer is committed by construction, and a committed write token to a Cloudflare account
    is a different class of thing from an id that only identifies one.

    EVERY VALIDATOR REFUSES BY NAME rather than correcting or defaulting. A kind this worker does
    not route, a token that is not 32 hex, an account id that is not an id: each of those produces a
    page nobody can reach, or an API call against a namespace nobody meant, and both of those fail
    in the same shape as success -- a green run and a 404 somebody else finds.

    Pure ASCII (repo convention for .ps1).
#>

# The kinds the shared worker routes. KEPT IN STEP WITH worker/bwj-pages-worker.js BY HAND, and that
# is a real seam between two languages: a kind added here and not there publishes to a key the
# worker will never look up, which reads as a successful publish and a 404. The suite asserts the
# two lists agree, which is the only thing that can hold them together.
$script:BwjPageKinds = @(
    [pscustomobject]@{
        Kind = 'notes'
        What = "the release notes, built by dkj-policy's build-release-notes-page.ps1 (without -Worker)"
    },
    [pscustomobject]@{
        Kind = 'backlog'
        What = 'the minor backlog -- the open issues carrying the reach label, with their Asana tasks'
    }
)

# Cloudflare's own value ceiling for a KV entry. Stated rather than discovered: the release-notes
# page measured 352 KB when it was last built in the source repo, so a page that approaches this is
# a page that has stopped being a page, and saying so before the upload beats a 413 from the API.
$script:BwjPageMaxBytes = 25MB

function Get-BwjPageKinds {
    <# The kinds the shared worker routes, each with what it carries. #>
    return $script:BwjPageKinds
}

function Get-BwjPageMaxBytes {
    <# Cloudflare's ceiling on a single KV value, in bytes. #>
    return $script:BwjPageMaxBytes
}

function Test-BwjPageKind {
    <# Is this one of the kinds the shared worker routes? #>
    param([string]$Kind)
    if ([string]::IsNullOrWhiteSpace($Kind)) { return $false }
    return ($script:BwjPageKinds.Kind -ccontains $Kind)
}

function Test-BwjPageToken {
    <#
        Is this a path token? Exactly 32 LOWERCASE hex characters -- the same shape dkj-policy's
        worker uses, and the same shape bwj-pages-worker.js matches in its route. Uppercase is
        refused rather than folded: the worker's regex is lowercase-only, so a token that differs
        only in case builds a key nothing will ever look up.
    #>
    param([string]$Token)
    if ([string]::IsNullOrWhiteSpace($Token)) { return $false }
    return ($Token -cmatch '^[0-9a-f]{32}$')
}

function New-BwjPageToken {
    <#
        A fresh path token. DELIBERATELY CALLED FROM ONE PLACE ONLY -- publish-page.ps1 -InitToken:
        a token invented on the fly does not mean "a new path", it means every link already sent
        now 404s, while the publish reports success. Same doctrine as dkj-policy's page token.
    #>
    return [guid]::NewGuid().ToString('N')
}

function Get-BwjPageTokenFileName {
    <# The file a kind's path token lives in, inside the page directory. #>
    param([Parameter(Mandatory)][string]$Kind)
    if (-not (Test-BwjPageKind -Kind $Kind)) {
        throw "'$Kind' is not a kind this worker routes."
    }
    return "page-token-$Kind.txt"
}

function Find-BwjStrayPageToken {
    <#
        Every token file for THIS kind that sits somewhere in the tree other than where this run
        expects it.

        WHY IT LOOKS AT ALL -- and the answer is not general caution, it is one measured failure that
        this design is exposed to by construction. The page directory is derived from the note root
        and is gitignored: two good decisions that combine into one hazard. Rename or repoint the
        folder holding the release documents and every TRACKED file travels with it, while the token
        stays behind in a folder nothing points at any more -- `git mv` cannot see an ignored sibling,
        so nothing reports the miss on the day it happens. What is left reads like rename debris, one
        Remove-Item away from 404ing every link already sent. dkj-policy's own page learned this as
        issue #1444, after its contributing-davekjohn/ -> dkj-policy/ rename left exactly that orphan.

        AND IT IS WHAT MAKES -InitToken's REFUSAL MEAN WHAT IT SAYS. That guard reads the expected
        path and nothing else, so after a move it finds no token and mints a second one happily --
        the one act the whole design exists to prevent. "Is there a token SOMEWHERE" is the question
        worth asking; "is there a token HERE" was only ever a cheap approximation of it.

        A STORE REPO COMMITS ITS TOKENS, which weakens the hazard here and does not remove it. The
        tracked copy survives a machine, so a moved folder is recoverable from git rather than gone --
        but a run that mints a second token beside the first still 404s the live link, and recovering
        afterwards means knowing which of the two was live. That is the same repair either way, and
        the refusal is what makes it unnecessary.

        SCOPED TO ONE KIND, deliberately. Every kind keeps its token in the same directory, so a
        search over `page-token-*.txt` would report a sibling kind's perfectly correct token as a
        stray -- on the very run that is minting the second kind for the first time.

        .git is skipped: nothing writes a token there, and walking it is the expensive half of the
        search. Cheap enough to sit on the two failure paths because that is the only place it runs.
    #>
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Kind,
        [Parameter(Mandatory)][string]$ExpectedPath
    )
    if (-not (Test-Path -LiteralPath $Root)) { return @() }
    $hits = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter (Get-BwjPageTokenFileName -Kind $Kind) -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -ne $ExpectedPath -and $_.FullName -notlike '*\.git\*' }
    return @($hits | ForEach-Object { $_.FullName })
}

function Get-BwjPageKvKey {
    <#
        The KV key a page lands on: '<kind>:<token>'. Both halves are validated first, because this
        string is what the worker looks up and what the API call addresses -- an unvalidated one is
        a key nobody reads and, in the API URL, a path segment somebody else chose.
    #>
    param(
        [Parameter(Mandatory)][string]$Kind,
        [Parameter(Mandatory)][string]$Token
    )
    if (-not (Test-BwjPageKind -Kind $Kind)) {
        throw ("'$Kind' is not a kind this worker routes. The kinds are: " +
               ($script:BwjPageKinds.Kind -join ', ') + ". Adding one means adding it here AND in " +
               "worker/bwj-pages-worker.js, then redeploying -- a kind known to only one of the two " +
               "publishes successfully to a key nothing ever serves.")
    }
    if (-not (Test-BwjPageToken -Token $Token)) {
        throw ("The path token is not 32 lowercase hex characters: '$Token'. The worker's route " +
               "matches nothing else, so a token of any other shape is a page no link can reach.")
    }
    return "${Kind}:${Token}"
}

function Get-BwjPageUrl {
    <# The link a colleague receives: <base>/<kind>/<token>. #>
    param(
        [Parameter(Mandatory)][string]$BaseUrl,
        [Parameter(Mandatory)][string]$Kind,
        [Parameter(Mandatory)][string]$Token
    )
    $null = Get-BwjPageKvKey -Kind $Kind -Token $Token
    return ($BaseUrl.TrimEnd('/') + "/$Kind/$Token")
}

function Get-BwjPageKvApiUrl {
    <#
        Cloudflare's KV value endpoint for one key. The key is escaped even though every key this
        lib builds is already [a-z]+:[0-9a-f]{32} -- escaping what is provably safe costs nothing,
        and the next caller to hand this an unvalidated key is the one it is written for.
    #>
    param(
        [Parameter(Mandatory)][string]$AccountId,
        [Parameter(Mandatory)][string]$NamespaceId,
        [Parameter(Mandatory)][string]$Key
    )
    return ("https://api.cloudflare.com/client/v4/accounts/$AccountId/storage/kv/namespaces/" +
            "$NamespaceId/values/" + [uri]::EscapeDataString($Key))
}

function Resolve-BwjPagesConfig {
    <#
        Validate and normalise the store's Get-BwjPagesConfig answer. Returns an object carrying
        Worker, AccountId, NamespaceId and BaseUrl; throws naming the key that is wrong.

        ALL FOUR ARE REQUIRED, and none has a default. A default account id does not exist, and a
        default worker name would point a publish at somebody else's deployment -- the one class of
        wrong value here that is only discovered by the person who receives the link.
    #>
    param($Config)

    if ($null -eq $Config) {
        throw ("Get-BwjPagesConfig is not answered in this repo's scripts\repo-config.ps1. It states " +
               "the shared BWJ pages worker: @{ Worker = '...'; AccountId = '<32 hex>'; " +
               "NamespaceId = '<32 hex>'; BaseUrl = 'https://...' }. The SAME four values in both " +
               "store repos -- that identity is what 'one worker for both stores' means. They are a " +
               "seam rather than literals in the plugin because the plugin ships from a public " +
               "repository and a store repo does not.")
    }

    $read = {
        param($Key)
        if ($Config -is [hashtable]) { return [string]$Config[$Key] }
        $prop = $Config.PSObject.Properties[$Key]
        if ($null -eq $prop) { return '' }
        return [string]$prop.Value
    }

    $worker      = (& $read 'Worker').Trim()
    $accountId   = (& $read 'AccountId').Trim()
    $namespaceId = (& $read 'NamespaceId').Trim()
    $baseUrl     = (& $read 'BaseUrl').Trim()

    if ($worker -cnotmatch '^[a-z0-9][a-z0-9-]{0,62}$') {
        throw ("Get-BwjPagesConfig's Worker is not a Cloudflare Worker name: '$worker'. Lowercase " +
               "letters, digits and hyphens, starting with a letter or a digit.")
    }
    $ids = [ordered]@{ AccountId = $accountId; NamespaceId = $namespaceId }
    foreach ($name in $ids.Keys) {
        $value = $ids[$name]
        if ($value -cnotmatch '^[0-9a-f]{32}$') {
            throw ("Get-BwjPagesConfig's $name is not a Cloudflare id: '$value'. Both the account id " +
                   "and the KV namespace id are 32 lowercase hex characters; read them off the " +
                   "dashboard rather than from memory.")
        }
    }
    if ($baseUrl -cnotmatch '^https://[A-Za-z0-9.-]+$') {
        throw ("Get-BwjPagesConfig's BaseUrl is not the worker's origin: '$baseUrl'. It is a scheme " +
               "and a host and nothing else -- no path, no query, no trailing slash -- because the " +
               "path is this lib's to build. https is not negotiable: the token in the path IS the " +
               "lock, and http puts it on the wire in clear.")
    }

    return [pscustomobject]@{
        Worker      = $worker
        AccountId   = $accountId
        NamespaceId = $namespaceId
        BaseUrl     = $baseUrl
    }
}

function Test-BwjPageSize {
    <#
        Is this page small enough for one KV value? Returns $true, or throws naming both numbers.
        A refusal rather than a truncation: half a page is the failure that looks most like success.
    #>
    param([Parameter(Mandatory)][int64]$Bytes)
    if ($Bytes -le 0) {
        throw 'The page is empty (0 bytes). Publishing it would replace a good page with nothing.'
    }
    if ($Bytes -gt $script:BwjPageMaxBytes) {
        throw ("The page is $([math]::Round($Bytes / 1MB, 1)) MB and Cloudflare's ceiling on one KV " +
               "value is $([math]::Round($script:BwjPageMaxBytes / 1MB)) MB. A page this size has " +
               "stopped being a page: check what the builder put in it before raising anything.")
    }
    return $true
}
