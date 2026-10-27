<#
.SYNOPSIS
    The judgement behind the dev-preview SessionStart hook: what a repo's Get-DevPreview seam says, and
    whether a port's listener is THIS checkout's server. No I/O -- the hook reads the sockets and the
    process table and hands them in, so every rule here is tested without a server.

.DESCRIPTION
    INBOUND #2967. Three DKJ-Solutions repos each carried their own copy of a hook that starts (or reuses)
    the repo's local dev server at session start and hands out its localhost link: dkj-brandbook (Vite,
    ports 5173-5180), dkj-etf-tracker (python http.server, 8765) and life-hub (Next.js, 3000). What they
    shared is here and in the hook; what differs is the repo's own answer to Get-DevPreview, a function in
    its scripts/repo-config.ps1 that returns one hashtable:

        function Get-DevPreview {
            @{
                Command      = 'npm run dev -- --port {port} --strictPort'   # required; {port} is filled in
                Ports        = 5173..5180       # required: one port or a list, tried in order
                Path         = '/'              # optional: the URL path after the port (default '/')
                Requires     = 'node_modules'   # optional: path(s) under the repo root that must exist
                WaitSeconds  = 20               # optional: how long to wait for the server to listen (1-45)
                OpenInVsCode = $false           # optional: also hand the URL to VS Code (see the hook)
                OwnHub       = $false           # optional: this server IS the repo's hub, so the plugin's is not used (#3245)
                DefaultTheme = 'teal'           # optional: the house theme the plugin's hub and general pages open in
                                                #   while the visitor has picked none; lilac where unstated (#3390)
                Product      = @{ ... }         # optional, only with OwnHub = $true: a product beside that hub, stating
                                                #   Command, Ports, Path, Requires and WaitSeconds as above (#3283)
            }
        }

    THE LINE HAS ONE WORD IN EVERY REPO, 'Hub' (INBOUND #3064, October 16, 2026): the line the hook prints
    opens with it. It read 'Repo dashboard' until dkj-brandbook v0.3.0 (#3097), 'Repo hub' until #3285 and
    'Repository' until #3291 gave that name to the GitHub repo's own page (/repository) and called the port
    hub. A repo once chose its own
    word through a Name key, and three repos said Showcase, connector dashboard and dev-preview for the
    same page. A Name a repo still states is ignored rather than refused, so a config that predates this
    keeps working; the word "dev-preview" stays the MECHANISM's, on the hook's lines about its own setup
    (skipped, config unreadable, a config it cannot run), which are printed before any config is read.

    THE PLUGIN SERVES THE REPOSITORY IN EVERY REPO (#3245, the owner's decision of October 21, 2026), whether
    or not the repo states Get-DevPreview: the general pages server answers '/' with the hub, and a server
    the repo states is its PRODUCT, one link on that Repository. A repo that wants its own Repository keeps that option
    through OwnHub = $true: its server is then the hub, as it was before. This replaces #3047's placeholder,
    whose own server on 4880-4889 is retired: the hub IS the general pages server.

    OWNERSHIP IS READ OFF THE PROCESS TABLE, NOT OFF THE PORT. brandbook's rule, generalised: a listener
    is ours when its own command line, or one of its nearest ancestors' (the hook starts every server under
    a cmd.exe whose command line names the repo root), names THIS checkout's root. etf-tracker's HTTP probe
    and life-hub's "anything listening" both took a foreign process, or the same repo's server in another
    worktree, for their own. The ancestor walk is what lets a server whose own command line names no path
    at all (python -m http.server with a relative directory) still be recognised.

    A ROOT IS NAMED ONLY AT A PATH BOUNDARY. 'C:\x\repo' is not named by 'C:\x\repo-lanes\...' (the
    worktree-lane sibling) or by 'C:\x\repo2', and a nested Claude Code worktree under
    '<root>\.claude\worktrees\' is a different checkout, so a server started there is not ours either.

    THE GENERAL PAGES SERVER AND THE STATE FILE (#3119). Beside the repo's own server the hook starts the
    plugin's general pages server (hub/pages/serve-general-pages.ps1: Artifacts, Issues, Release notes,
    SessionStart), on the first free port of 4890-4899 under the same ownership rule. The two servers learn
    of each other through ONE file per checkout, %TEMP%\dkj-repo-hub-<leaf>-<hash>.json, which the hook
    writes at every session start: { root, hub, pages, product, mode, theme }, the Repository's url, the general
    server's base url, the repo's own server url, what the repo states (#3245) and its DefaultTheme (#3390). Get-RepoHubStatePath names
    it, Format-RepoHubState writes it, ConvertFrom-RepoHubState reads it and believes it only when it names
    this root and carries plain loopback urls. The hash is the one the hook's
    log paths use (Get-DevPreviewRootHash), so a checkout's files sit together in %TEMP%.

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/dev-preview-sessionstart.tests.ps1 in
    the source repo -- change one, run the other.
#>

$script:DevPreviewMaxAncestors = 4
# How long a started product must keep listening after its first answer before it reads as started (#3404).
$script:DevPreviewSettleSeconds = 2
# The word the session-start line opens with, in every repo (#3064): 'Hub', since the page called Repository is /repository on it.
$script:DevPreviewLabel = 'Hub'
# The general pages server, which is the Repository (#3119, #3245). Fixed, so a .vscode route can name them; ten,
# so ten checkouts open side by side each get their own. Clear of the ranges the repos measured in #2967 and
# #2976 use (3000, 4870-4879, 5173-5180, 8765).
$script:GeneralPagesPorts = 4890..4899

function Get-GeneralPagesPortRange {
    <#
        The ports the general pages server may take, and so the only ports a state file's pages url is
        believed on: 4890-4899. DKJ_GENERAL_PAGES_PORTS (comma-separated ports) replaces them -- the TEST
        override, read from the environment of the process the hook, the servers and the hubs all start in,
        so a test run never meets a real server. A value that is not a plain port list is ignored.
    #>
    $o = [string]$env:DKJ_GENERAL_PAGES_PORTS
    if ($o -match '^[0-9]{4,5}(,[0-9]{4,5})*$') {
        $ports = @($o -split ',' | ForEach-Object { [int]$_ } | Where-Object { $_ -ge 1024 -and $_ -le 65535 })
        if ($ports.Count) { return $ports }
    }
    return $script:GeneralPagesPorts
}

function Test-DevPreviewVsCodeRoute {
    <#
        True when -SettingsText (a .vscode/settings.json, comments allowed) routes localhost:<Port> to VS
        Code's Simple Browser through workbench.externalUriOpeners. A pattern, not a JSON parse: the file is
        JSONC, and a key spelled exactly so is the only form VS Code's own UI writes.
    #>
    param([AllowNull()][AllowEmptyString()][string]$SettingsText, [int]$Port)
    if (-not $SettingsText) { return $false }
    # A line commented out with // is no route (Victor's review, #3047).
    $live = ($SettingsText -split "`n" | Where-Object { $_ -notmatch '^\s*//' }) -join "`n"
    return [bool]($live -match ('"(localhost|127\.0\.0\.1):' + $Port + '"\s*:\s*"simpleBrowser\.open"'))
}

function Test-DevPreviewThemeId {
    <# True when -Theme has the shape of a house theme id (#3390): a lowercase letter, then lowercase letters, digits or hyphens, 32 at most. #>
    param([AllowNull()][AllowEmptyString()][string]$Theme)
    return [bool]($Theme -cmatch '^[a-z][a-z0-9-]{0,31}\z')
}

function ConvertTo-DevPreviewConfig {
    <#
        Validates Get-DevPreview's answer and fills the defaults. Returns @{ Ok; Config; Problem }:
        Ok $false with no Problem means the repo stated nothing (the silent no-op); with a Problem, the
        repo stated something the hook cannot run, and the Problem says what, in one clause.
    #>
    param([AllowNull()]$Raw)
    $result = @{ Ok = $false; Config = $null; Problem = $null }
    if ($null -eq $Raw) { return $result }
    if ($Raw -isnot [System.Collections.IDictionary]) {
        $result.Problem = 'Get-DevPreview must return a hashtable'
        return $result
    }

    $command = [string]$Raw['Command']
    if (-not $command.Trim()) { $result.Problem = 'Get-DevPreview states no Command'; return $result }
    if ($command -notmatch '\{port\}') {
        $result.Problem = 'the Command carries no {port}, so the server it starts cannot be told which port to take'
        return $result
    }

    $ports = @()
    foreach ($p in @($Raw['Ports'])) {
        if ($null -eq $p) { continue }
        $n = 0
        if (-not [int]::TryParse([string]$p, [ref]$n) -or $n -lt 1024 -or $n -gt 65535) {
            $result.Problem = "the port '$p' is not a number from 1024 to 65535"
            return $result
        }
        $ports += $n
    }
    if ($ports.Count -eq 0) { $result.Problem = 'Get-DevPreview states no Ports'; return $result }
    if ($ports.Count -gt 32) { $result.Problem = 'more than 32 Ports -- name a narrower range'; return $result }

    $path = [string]$Raw['Path']
    if (-not $path) { $path = '/' }
    if (-not $path.StartsWith('/')) { $path = '/' + $path }
    if ($path -notmatch '^/[A-Za-z0-9._~/%?=&#+-]*$' -or $path.Length -gt 200) {
        $result.Problem = 'the Path is not a plain URL path (letters, digits and ._~/%?=&#+- only, at most 200)'
        return $result
    }

    $requires = @()
    foreach ($r in @($Raw['Requires'])) {
        if ($null -eq $r -or -not ([string]$r).Trim()) { continue }
        $rel = ([string]$r).Trim()
        if ($rel -match '[\p{C}"<>|*?]' -or $rel.Length -gt 200) {
            $result.Problem = 'a Requires entry carries a character no path may hold'
            return $result
        }
        if ([System.IO.Path]::IsPathRooted($rel) -or $rel -match '(^|[\\/])\.\.([\\/]|$)') {
            $result.Problem = "Requires names '$rel', which is not a path inside the repo"
            return $result
        }
        $requires += $rel
    }

    $wait = 20
    if ($null -ne $Raw['WaitSeconds']) {
        $w = 0
        if (-not [int]::TryParse([string]$Raw['WaitSeconds'], [ref]$w) -or $w -lt 1 -or $w -gt 45) {
            $result.Problem = 'WaitSeconds must be a whole number from 1 to 45'
            return $result
        }
        $wait = $w
    }

    # OwnHub is the repo's opt-out of the plugin's hub (#3245): a real boolean, so a typo is a problem and not
    # a silent default.
    $ownHub = $false
    if ($null -ne $Raw['OwnHub']) {
        if ($Raw['OwnHub'] -isnot [bool]) {
            $result.Problem = 'OwnHub must be $true or $false'
            return $result
        }
        $ownHub = [bool]$Raw['OwnHub']
    }

    # The theme the plugin's hub and general pages open in (#3390): a theme id, the shape house-theme.js names its
    # themes in, so it can be written into an attribute as it stands. One the house style does not know falls
    # back in the browser, the way a stored choice naming a retired theme does.
    $theme = ''
    if ($null -ne $Raw['DefaultTheme']) {
        $theme = [string]$Raw['DefaultTheme']
        if (-not (Test-DevPreviewThemeId $theme)) {
            $result.Problem = 'DefaultTheme must be a theme id: a lowercase letter, then lowercase letters, digits or hyphens, at most 32'
            return $result
        }
    }

    # A product BESIDE the repo's own hub (#3283): only where OwnHub is on, because without it the server
    # itself is already the product. It states the same fields as the server and is held to the same rules,
    # except the three that belong to the hub alone (OwnHub, OpenInVsCode and a Product of its own). A Product
    # stated without OwnHub fails the whole answer, since the hub is then the plugin's and nothing is lost; any
    # other fault in it costs the product alone, carried as ProductProblem, so a typo there never costs the
    # repo its own hub (Victor's review).
    $product = $null
    $productProblem = $null
    if ($null -ne $Raw['Product']) {
        if (-not $ownHub) {
            $result.Problem = 'a Product is stated without OwnHub = $true, where the server itself is the product'
            return $result
        }
        if ($Raw['Product'] -isnot [System.Collections.IDictionary]) {
            $productProblem = 'the Product must be a hashtable'
        } else {
            foreach ($k in 'OwnHub', 'OpenInVsCode', 'DefaultTheme', 'Product') {
                if (-not $productProblem -and $Raw['Product'].Contains($k)) { $productProblem = "the Product states $k, which belongs to the hub alone" }
            }
        }
        if (-not $productProblem) {
            $inner = ConvertTo-DevPreviewConfig -Raw $Raw['Product']
            if (-not $inner.Ok) {
                $productProblem = "the Product: $($inner.Problem)"
            } else {
                $shared = @($inner.Config.Ports | Where-Object { $ports -contains $_ })
                if ($shared.Count) { $productProblem = "the Product's ports overlap the hub's ($(Format-DevPreviewPorts -Ports $shared))" }
                else { $product = $inner.Config }
            }
        }
    }

    $result.Ok = $true
    $result.Config = @{
        Command      = $command
        Ports        = $ports
        Path         = $path
        Requires     = $requires
        Name         = $script:DevPreviewLabel   # fixed: a repo's own Name is not read (#3064)
        NameStated   = $Raw.Contains('Name')     # ...but one still stated is named as drift (#3463)
        WaitSeconds  = $wait
        OpenInVsCode = [bool]$Raw['OpenInVsCode']
        OwnHub       = $ownHub
        DefaultTheme = $theme
        Product      = $product
        ProductProblem = $productProblem
    }
    return $result
}

function Get-DevPreviewDriftClauses {
    <#
        The clauses that name what keeps a DKJ-Solutions repo from following a hub change (#3463), in the
        order they print; empty where nothing does. -Config is ConvertTo-DevPreviewConfig's, -Mode what the
        repo states, -SettingsText its .vscode/settings.json, -HubPorts the plugin hub's range.

        THREE KINDS, AND ONE IS NOT A DEFECT (the owner's decision, October 25, 2026). OwnHub is a supported
        opt-out, so it is named as a plain fact, never as something to repair; the source repo's own OwnHub
        (-SourceTree) is not named at all, since it runs the hub from its own tree and is ahead of every
        release rather than behind. OpenInVsCode with no hub port routed, and a Name still stated, are defects
        in the repo's config: since #3245 OpenInVsCode hands out the HUB's url, so a route written for the
        product alone sends it to the system browser, and Name has been ignored since #3064.
        Outside a DKJ-Solutions repo (-DkjSolutions false) nothing is named: the roll-out is theirs.
    #>
    param(
        [bool]$DkjSolutions,
        [bool]$SourceTree,
        [AllowEmptyString()][string]$Mode = 'none',
        [AllowNull()]$Config,
        [AllowNull()][AllowEmptyString()][string]$SettingsText,
        [int[]]$HubPorts = @(Get-GeneralPagesPortRange)
    )
    # TERSE ON PURPOSE (Victor's review): they close a line ConvertTo-DevPreviewLine cuts at 300 characters, so
    # every word here is one the product's url and words cannot use.
    $clauses = @()
    if (-not $DkjSolutions -or -not $Config) { return $clauses }
    if ($Mode -eq 'ownhub' -and -not $SourceTree) { $clauses += 'own hub (OwnHub): hub releases do not reach it' }
    $defects = @()
    if ($Mode -eq 'product' -and $Config.OpenInVsCode -and -not @($HubPorts | Where-Object { Test-DevPreviewVsCodeRoute -SettingsText $SettingsText -Port $_ }).Count) {
        $defects += "OpenInVsCode but no hub port ($((Format-DevPreviewPorts -Ports $HubPorts) -replace '^ports? ', '')) routed in .vscode"
    }
    if ($Config.NameStated) { $defects += 'Get-DevPreview states Name: delete it' }
    if ($defects.Count) { $clauses += 'config drift: ' + ($defects -join '; ') }
    return $clauses
}

function Test-CommandLineNamesRoot {
    <#
        True when -CommandLine names the checkout at -Root at a path boundary, case-insensitively and
        whichever slash either side uses. A path under <root>\.claude\worktrees\ is another checkout.
    #>
    param([AllowNull()][AllowEmptyString()][string]$CommandLine, [Parameter(Mandatory = $true)][string]$Root)
    if (-not $CommandLine) { return $false }
    $cl = $CommandLine.Replace('/', '\')
    $r = $Root.Replace('/', '\').TrimEnd('\')
    if (-not $r) { return $false }
    $at = 0
    while (($i = $cl.IndexOf($r, $at, [StringComparison]::OrdinalIgnoreCase)) -ge 0) {
        $at = $i + 1
        $next = $i + $r.Length
        if ($next -ge $cl.Length) { return $true }
        $c = $cl[$next]
        if ($c -eq '"' -or $c -eq "'" -or [char]::IsWhiteSpace($c)) { return $true }
        if ($c -eq '\') {
            $rest = $cl.Substring($next)
            if ($rest.StartsWith('\.claude\worktrees\', [StringComparison]::OrdinalIgnoreCase)) { continue }
            return $true
        }
    }
    return $false
}

function Test-ProcessIsOurs {
    <#
        True when the process -ProcessId, or one of its nearest ancestors, names -Root. -Processes maps a
        process id to @{ CommandLine; ParentId }. The walk stops at an unknown id, at a cycle (a reused id
        can point a parent back at its child) and after $DevPreviewMaxAncestors ancestors: far enough to
        reach the hook's cmd.exe over npm's own cmd and node, and short of the terminal and editor
        processes above it, which may name the folder without having started this server.
    #>
    param([int]$ProcessId, [Parameter(Mandatory = $true)][hashtable]$Processes, [Parameter(Mandatory = $true)][string]$Root)
    $seen = @{}
    $id = $ProcessId
    for ($depth = 0; $depth -le $script:DevPreviewMaxAncestors; $depth++) {
        if ($seen.ContainsKey($id) -or -not $Processes.ContainsKey($id)) { return $false }
        $seen[$id] = $true
        $p = $Processes[$id]
        if (Test-CommandLineNamesRoot -CommandLine ([string]$p.CommandLine) -Root $Root) { return $true }
        $id = [int]$p.ParentId
    }
    return $false
}

function Get-DevPreviewPortState {
    <#
        'free', 'ours' or 'other' for -Port, from one snapshot. -Listeners is a list of objects with
        LocalPort and OwningProcess (Get-NetTCPConnection -State Listen); a port can carry two (IPv4 and
        IPv6), and it is ours when any of them is.
    #>
    param(
        [int]$Port,
        [AllowEmptyCollection()][object[]]$Listeners,
        [Parameter(Mandatory = $true)][hashtable]$Processes,
        [Parameter(Mandatory = $true)][string]$Root
    )
    $owners = @($Listeners | Where-Object { $_ -and [int]$_.LocalPort -eq $Port } | ForEach-Object { [int]$_.OwningProcess })
    if ($owners.Count -eq 0) { return 'free' }
    foreach ($o in $owners) {
        if (Test-ProcessIsOurs -ProcessId $o -Processes $Processes -Root $Root) { return 'ours' }
    }
    return 'other'
}

function Get-DevPreviewWaitOutcome {
    <#
        One step of the hook's wait for a server it started: 'ok', 'exited', 'lost' or 'pending', from the
        port's state (Get-DevPreviewPortState) and whether the started process has exited.

        'LOST' IS ITS OWN OUTCOME (#3378). The wait read the exit only while nobody listened on the port, so
        a start that lost its bind to another process -- measured: HttpListener.Start() threw 'only one usage
        of each socket address', while a listener whose command line read back empty held the port -- waited
        out the whole deadline and reported "not listening" about a port that was listening. Ours wins over
        an exit: a server whose own listener is up has started, whatever its launcher did.
    #>
    param([Parameter(Mandatory = $true)][string]$State, [bool]$Exited)
    if ($State -eq 'ours') { return 'ok' }
    if (-not $Exited) { return 'pending' }
    if ($State -eq 'other') { return 'lost' }
    return 'exited'
}

function Get-DevPreviewSettleOutcome {
    <#
        One step of the settle that follows a started product's first 'ok': 'ok', 'stopped', 'lost' or
        'pending', from the port's state and whether -SettleUntil has passed. INBOUND #3404: Next.js 16.4.0
        under an agent printed Ready, bound its port, then exited to show an upgrade nudge, and the line said
        '(started)' about a port nobody listened on seconds later. The launcher's exit says nothing here (a
        Command may hand its server off), so the port decides: still ours at the end is 'ok', free is
        'stopped', another process's is 'lost'. -HolderGone is a listener whose process is no longer in the
        table: a socket outliving its process for a moment as the server exits, so it is 'stopped' too
        (measured in the suite: read as 'other', it reported the server's own exit as a lost port).
    #>
    param([Parameter(Mandatory = $true)][string]$State, [bool]$Due, [bool]$HolderGone)
    if ($State -eq 'free' -or ($State -eq 'other' -and $HolderGone)) { return 'stopped' }
    if ($State -eq 'other') { return 'lost' }
    if ($Due) { return 'ok' }
    return 'pending'
}

function Get-DevPreviewStaleInstall {
    <#
        The first -Requires entry that is a node_modules folder older than the package-lock.json beside it,
        or '' where none is. INBOUND #3404: Requires checked only that the folder exists, so a pull that
        moved the lock (next 16.4.0 -> 16.4.3) on another machine left this one starting the old install.
        Older is read from npm's own record of its last install, node_modules\.package-lock.json (npm 7+);
        where that file is absent (another package manager, an older npm) nothing is claimed.

        BY CONTENT, WITH THE TIME AS A FILTER ONLY (#3419). A lock newer than the install record was claimed stale
        on its time alone, and git rewrites the lock on any commit or checkout that touches it: measured on this
        repo's brandbook/, a lock written 18 minutes after the install, with `npm ls` clean. So the time only picks
        which locks are read, and Test-DevPreviewLockMatchesInstall decides.
    #>
    param([Parameter(Mandatory = $true)][string]$Root, [AllowEmptyCollection()][string[]]$Requires)
    foreach ($rel in @($Requires)) {
        if (-not $rel -or (Split-Path -Leaf $rel.TrimEnd('\', '/')) -ne 'node_modules') { continue }
        $dir = Join-Path $Root $rel
        $lock = Join-Path (Split-Path -Parent $dir.TrimEnd('\', '/')) 'package-lock.json'
        $marker = Join-Path $dir '.package-lock.json'
        if (-not (Test-Path -LiteralPath $lock -PathType Leaf) -or -not (Test-Path -LiteralPath $marker -PathType Leaf)) { continue }
        if ((Get-Item -LiteralPath $lock).LastWriteTimeUtc -le (Get-Item -LiteralPath $marker).LastWriteTimeUtc) { continue }
        if ((Test-DevPreviewLockMatchesInstall -LockPath $lock -InstalledPath $marker) -eq $false) { return $rel }
    }
    return ''
}

function ConvertFrom-DevPreviewLockJson {
    <#
        A lock file's 'packages' map as a dictionary, or $null where it cannot be read. JavaScriptSerializer rather
        than ConvertFrom-Json: Windows PowerShell 5.1's ConvertFrom-Json refuses the root package's empty key ("")
        that every package-lock.json carries (measured). The length cap is the document's own, as in
        plugin-tree-lib.ps1.
    #>
    param([Parameter(Mandatory = $true)][string]$Path)
    try {
        $text = [System.IO.File]::ReadAllText($Path)
        Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
        $reader = New-Object System.Web.Script.Serialization.JavaScriptSerializer
        $reader.MaxJsonLength = [Math]::Max(1, $text.Length)
        $doc = $reader.DeserializeObject($text)
        if ($doc -isnot [System.Collections.IDictionary] -or $doc['packages'] -isnot [System.Collections.IDictionary]) { return $null }
        return $doc['packages']
    } catch { return $null }
}

function Test-DevPreviewLockMatchesInstall {
    <#
        $true where every package -LockPath pins is installed at that version according to -InstalledPath (npm's
        node_modules\.package-lock.json), $false where one is not, and $null where either cannot be read -- which
        the caller reads as no claim (#3419). A package the lock marks optional, devOptional or peer may be absent
        without counting (another platform's binaries are never installed), and a link has no version to compare.
    #>
    param([Parameter(Mandatory = $true)][string]$LockPath, [Parameter(Mandatory = $true)][string]$InstalledPath)
    $want = ConvertFrom-DevPreviewLockJson -Path $LockPath
    $have = ConvertFrom-DevPreviewLockJson -Path $InstalledPath
    if ($null -eq $want -or $null -eq $have) { return $null }
    foreach ($key in @($want.Keys)) {
        if (-not ([string]$key).StartsWith('node_modules/')) { continue }
        $w = $want[$key]
        if ($w -isnot [System.Collections.IDictionary] -or $w['link']) { continue }
        # ContainsKey: the serializer hands back a generic Dictionary, whose IDictionary.Contains PowerShell cannot call.
        if (-not $have.ContainsKey($key)) {
            if ($w['optional'] -or $w['devOptional'] -or $w['peer']) { continue }
            return $false
        }
        $h = $have[$key]
        if ($h -is [System.Collections.IDictionary] -and [string]$h['version'] -ne [string]$w['version']) { return $false }
    }
    return $true
}

function Select-DevPreviewPort {
    <#
        Over -Ports in order: the first that is ours wins outright (reuse, never a second server);
        otherwise the first free one is where to start. Returns @{ Action = 'reuse'|'start'|'none'; Port }.
    #>
    param(
        [Parameter(Mandatory = $true)][int[]]$Ports,
        [AllowEmptyCollection()][object[]]$Listeners,
        [Parameter(Mandatory = $true)][hashtable]$Processes,
        [Parameter(Mandatory = $true)][string]$Root
    )
    $free = $null
    foreach ($port in $Ports) {
        $state = Get-DevPreviewPortState -Port $port -Listeners $Listeners -Processes $Processes -Root $Root
        if ($state -eq 'ours') { return @{ Action = 'reuse'; Port = $port } }
        if ($state -eq 'free' -and $null -eq $free) { $free = $port }
    }
    if ($null -ne $free) { return @{ Action = 'start'; Port = $free } }
    return @{ Action = 'none'; Port = $null }
}

function Get-DevPreviewStaleHubOwners {
    <#
        The process ids listening on -Port whose own command line runs a serve-general-pages.ps1 from an
        absolute path other than -Server: a hub this checkout started under ANOTHER plugin version. INBOUND
        #3275: ownership is read from the checkout the command line names, not from the payload it runs, so
        after an update the hook reused a v5.26.0 server whose '/' answered with a 303 to the state file's hub
        -- itself, since #3245 made the hub this server's own page. Empty where the listener runs -Server,
        or a relative path (a server somebody started by hand from a tree), which is left alone.
    #>
    param(
        [int]$Port,
        [AllowEmptyCollection()][object[]]$Listeners,
        [Parameter(Mandatory = $true)][hashtable]$Processes,
        [Parameter(Mandatory = $true)][string]$Server
    )
    $own = [System.IO.Path]::GetFullPath($Server)
    $stale = @()
    foreach ($o in @($Listeners | Where-Object { $_ -and [int]$_.LocalPort -eq $Port } | ForEach-Object { [int]$_.OwningProcess } | Select-Object -Unique)) {
        if (-not $Processes.ContainsKey($o)) { continue }
        $cl = ([string]$Processes[$o].CommandLine).Replace('/', '\')
        if ($cl -notmatch '(?i)([A-Za-z]:\\[^"]*?\\hub\\pages\\serve-general-pages\.ps1)') { continue }
        if (-not [string]::Equals([System.IO.Path]::GetFullPath($Matches[1]), $own, [StringComparison]::OrdinalIgnoreCase)) { $stale += $o }
    }
    return $stale
}

function Get-DevPreviewOwnedTreeRoots {
    <#
        The process ids whose trees are THIS checkout's servers on -Ports: for each listener that is ours
        (Test-ProcessIsOurs), the NEAREST process in the same walk whose command line names -Root -- the
        hook's cmd.exe, so stopping that tree takes npm, node and the esbuild a Vite server runs with it. The
        nearest, not the outermost: an editor or terminal further up may name the folder too (Code.exe
        <root>), and its tree is the session's, not the server's.
        INBOUND #3462: a release build refused at every cut because the session's own product dev server held
        its node_modules binaries, and the cut can stop exactly that tree where it recognises it. A listener
        that is not ours contributes nothing, so a foreign holder keeps the refusal.
    #>
    param(
        [Parameter(Mandatory = $true)][int[]]$Ports,
        [AllowEmptyCollection()][object[]]$Listeners,
        [Parameter(Mandatory = $true)][hashtable]$Processes,
        [Parameter(Mandatory = $true)][string]$Root
    )
    $roots = @()
    foreach ($o in @($Listeners | Where-Object { $_ -and $Ports -contains [int]$_.LocalPort } | ForEach-Object { [int]$_.OwningProcess } | Select-Object -Unique)) {
        $seen = @{}
        $id = $o
        $top = $null
        for ($depth = 0; $depth -le $script:DevPreviewMaxAncestors; $depth++) {
            if ($seen.ContainsKey($id) -or -not $Processes.ContainsKey($id)) { break }
            $seen[$id] = $true
            if (Test-CommandLineNamesRoot -CommandLine ([string]$Processes[$id].CommandLine) -Root $Root) { $top = $id; break }
            $id = [int]$Processes[$id].ParentId
        }
        if ($null -ne $top -and $roots -notcontains $top) { $roots += $top }
    }
    return $roots
}

function Get-DevPreviewHolderName {
    <#
        The name a person recognises for the process -ProcessId, or '' where none can be read. INBOUND
        #3244: 'taken by other processes' left the owner a netstat and a CIM lookup by hand, while the hook
        had already read the process table. Walks the same ancestors Test-ProcessIsOurs walks, and the
        first command line that names a checkout wins -- the folder above 'node_modules', or the folder a
        'cd /d' changes into (the hook's own start line; read after the slash swap, so as 'cd \d'). Without
        one, the listener's own executable.

        HELD TO A NARROW ALPHABET (#3258): the name comes from ANOTHER process's command line and reaches the
        session's context through the hook's line, so a folder named in free words would be free text of that
        process's choosing. A name outside [A-Za-z0-9._@-], or longer than 40 characters, reads as '', and the
        line falls back to the pid alone.
    #>
    param([int]$ProcessId, [Parameter(Mandatory = $true)][hashtable]$Processes)
    $seen = @{}
    $id = $ProcessId
    $name = ''
    for ($depth = 0; $depth -le $script:DevPreviewMaxAncestors; $depth++) {
        if ($seen.ContainsKey($id) -or -not $Processes.ContainsKey($id)) { break }
        $seen[$id] = $true
        $cl = ([string]$Processes[$id].CommandLine).Replace('/', '\')
        if ($cl -match '([^\\"'' ]+)\\node_modules\\') { $name = $Matches[1]; break }
        if ($cl -match '(?i)\bcd \\d "([^"]+)"') { $name = Split-Path -Leaf $Matches[1].TrimEnd('\'); break }
        if ($depth -eq 0 -and $cl -match '^\s*(?:"([^"]+)"|(\S+))') {
            $first = if ($Matches[1]) { $Matches[1] } else { $Matches[2] }
            $name = Split-Path -Leaf $first
        }
        $id = [int]$Processes[$id].ParentId
    }
    if ($name -cmatch '^[A-Za-z0-9._@-]{1,40}\z') { return $name }
    return ''
}

function Format-DevPreviewPortHolders {
    <#
        Who holds each of -Ports, as '3000 by dkj-lifehub (pid 19544)' joined with '; ', or '' when no
        listener on them is known. One entry per port: its first listener names it.

        AN UNREADABLE HOLDER SAYS WHY (INBOUND #3401). A listener in another Windows logon session of the
        same account reads back with an empty command line, so it can never be named or recognised as ours,
        and the bare pid sent the owner hunting for a foreign app -- measured: it was this checkout's own
        product, started from the other session. Where the listener's command line is empty, the entry says
        so, and names the other logon session where the table's SessionId differs from -SessionId (the
        hook's own, by default). A pid absent from the table is a process that is gone, and stays bare.

        AND THE OTHER SESSION'S HOLDER CARRIES ITS REMEDY (INBOUND #3569): measured cross-account, where this
        session cannot stop it at all, so the entry names the session and the two elevated commands that
        free the port. A server this hook starts now stops itself once its session stays disconnected (the
        watcher, hub/pages/dev-preview-watch.ps1), so this is for the holders started before that.
    #>
    param(
        [Parameter(Mandatory = $true)][int[]]$Ports,
        [AllowEmptyCollection()][object[]]$Listeners,
        [Parameter(Mandatory = $true)][hashtable]$Processes,
        [int]$SessionId = [Diagnostics.Process]::GetCurrentProcess().SessionId
    )
    $parts = @(foreach ($port in $Ports) {
        $l = @($Listeners | Where-Object { $_ -and [int]$_.LocalPort -eq $port }) | Select-Object -First 1
        if (-not $l) { continue }
        $procId = [int]$l.OwningProcess
        $name = Get-DevPreviewHolderName -ProcessId $procId -Processes $Processes
        if ($name) { "$port by $name (pid $procId)"; continue }
        $p = $Processes[$procId]
        if ($p -and -not ([string]$p.CommandLine).Trim()) {
            if ($null -ne $p.SessionId -and [int]$p.SessionId -ne $SessionId) {
                $sid = [int]$p.SessionId
                "$port by pid $procId (another logon session, $sid -- its command line cannot be read; free it from an elevated shell: logoff $sid, or Stop-Process -Id $procId)"
            } else {
                "$port by pid $procId (its command line cannot be read)"
            }
        } else {
            "$port by pid $procId"
        }
    })
    return ($parts -join '; ')
}

function Test-DevPreviewCommandIsLoopback {
    <#
        True when -Command names a loopback host (127.0.0.1, localhost or ::1) as a whole token -- the
        repo's own statement that its server must not be reachable from the network.
    #>
    param([AllowNull()][AllowEmptyString()][string]$Command)
    if (-not $Command) { return $false }
    return [bool]($Command -match '(?<![\w.:-])(127\.0\.0\.1|localhost|\[?::1\]?)(?![\w.-])')
}

function Test-DevPreviewListensOnAll {
    <#
        True when any listener on -Port is bound to every interface (0.0.0.0 or ::). INBOUND #3041: a
        server started by hand in the checkout (`npm run dev` without -H) is reused as ours, so the
        repo's loopback Command never ran -- this is what tells the hook to say so.
    #>
    param([int]$Port, [AllowEmptyCollection()][object[]]$Listeners)
    foreach ($l in @($Listeners)) {
        if (-not $l -or [int]$l.LocalPort -ne $Port) { continue }
        if (@('0.0.0.0', '::') -contains [string]$l.LocalAddress) { return $true }
    }
    return $false
}

function Get-DevPreviewStartLine {
    <#
        The single argument string for cmd.exe that starts the server: it changes into the root FIRST, so
        the root is on this cmd.exe's own command line -- the ancestor Test-ProcessIsOurs finds -- and then
        runs the repo's Command with {port} filled in, its output to -LogPath.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Command,
        [int]$Port,
        [Parameter(Mandatory = $true)][string]$LogPath
    )
    $cmd = $Command.Replace('{port}', [string]$Port)
    return ('/d /s /c "cd /d "{0}" && {1} > "{2}" 2>&1"' -f $Root, $cmd, $LogPath)
}

$script:DevPreviewWatchGraceSeconds = 60
$script:DevPreviewWatchPollSeconds = 15

function Test-DevPreviewSessionWatchable {
    <#
        True when a server started from logon session -SessionId gets a watcher (INBOUND #3569). Session 0 is
        the services session, which reads as disconnected for as long as the machine runs, so a server
        started there (an ssh shell, a scheduled task) would be stopped by the watcher one grace after it
        started.
    #>
    param([int]$SessionId)
    return $SessionId -gt 0
}

function Get-DevPreviewWatchStep {
    <#
        One poll of the watcher (INBOUND #3569): from the logon session's connect state -State (the
        WTS_CONNECTSTATE_CLASS value; 4 is WTSDisconnected, -1 an unreadable state) and since when it has been
        disconnected (-Since, $null when it was not), returns @{ Stop; Since }. The server is stopped only
        once the session has been disconnected for -GraceSeconds without a break: a brief Remote Desktop drop
        or a quick switch back keeps it. Any other state, an unreadable one included, resets the clock, so
        an uncertain read never stops a server.
    #>
    param(
        [int]$State,
        [AllowNull()]$Since,
        [Parameter(Mandatory = $true)][datetime]$Now,
        [int]$GraceSeconds = $script:DevPreviewWatchGraceSeconds
    )
    if ($State -ne 4) { return @{ Stop = $false; Since = $null } }
    $from = if ($null -ne $Since) { [datetime]$Since } else { $Now }
    return @{ Stop = (($Now - $from).TotalSeconds -ge $GraceSeconds); Since = $from }
}

function Get-DevPreviewWatchArgs {
    <#
        The argument list for powershell.exe that starts the watcher for the started server -ProcessId (the
        cmd.exe the hook launched): the server's whole tree is what it stops. -StartTicks is that process's
        start time as FILETIME UTC, so a pid reused before the watcher reads it is never taken for the server.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Watcher,
        [Parameter(Mandatory = $true)][int]$ProcessId,
        [long]$StartTicks = 0
    )
    return ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -ProcessId {1} -StartTicks {2}' -f $Watcher, $ProcessId, $StartTicks)
}

function Format-DevPreviewPorts {
    <# 'port 3000', 'ports 5173-5180' for a contiguous run, else 'ports 3000, 8080'. #>
    param([Parameter(Mandatory = $true)][int[]]$Ports)
    if ($Ports.Count -eq 1) { return "port $($Ports[0])" }
    $contiguous = $true
    for ($i = 1; $i -lt $Ports.Count; $i++) { if ($Ports[$i] -ne $Ports[$i - 1] + 1) { $contiguous = $false; break } }
    if ($contiguous) { return "ports $($Ports[0])-$($Ports[-1])" }
    return 'ports ' + ($Ports -join ', ')
}

function ConvertTo-DevPreviewLine {
    <#
        The one line the hook prints, made safe for the session's context: control characters become
        spaces and it is cut at 300 characters. Every value in it is the hook's own text or a validated
        seam field, so this is the second fence, not the first.
    #>
    param([AllowEmptyString()][string]$Text)
    $t = ($Text -replace '[\p{C}]', ' ').Trim()
    if ($t.Length -gt 300) { $t = $t.Substring(0, 297) + '...' }
    return $t
}

function Get-DevPreviewUrl {
    param([int]$Port, [string]$Path = '/')
    return "http://localhost:$Port$Path"
}

function Get-DevPreviewRootHash {
    <# The first four bytes of the SHA1 of the lowercased root, as eight hex digits: the checkout's tag in %TEMP% file names. #>
    param([Parameter(Mandatory = $true)][string]$Root)
    $sha = [System.Security.Cryptography.SHA1]::Create()
    return -join ($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Root.ToLowerInvariant()))[0..3] | ForEach-Object { $_.ToString('x2') })
}

function Get-DevPreviewLogPath {
    <# %TEMP%\<Name>-<leaf>-<hash>.log: the hook's log for one server of one checkout ('dev-preview' is the repo's own, 'dev-preview-general' the general pages server). #>
    param([Parameter(Mandatory = $true)][string]$Root, [string]$Name = 'dev-preview')
    $leaf = Split-Path -Leaf $Root
    return Join-Path ([System.IO.Path]::GetTempPath()) ("$Name-$leaf-$(Get-DevPreviewRootHash -Root $Root).log")
}

function Get-RepoHubStatePath {
    <# %TEMP%\dkj-repo-hub-<leaf>-<hash>.json: where the two servers of one checkout find each other (#3119). #>
    param([Parameter(Mandatory = $true)][string]$Root)
    $leaf = Split-Path -Leaf $Root
    return Join-Path ([System.IO.Path]::GetTempPath()) ("dkj-repo-hub-$leaf-$(Get-DevPreviewRootHash -Root $Root).json")
}

function ConvertTo-DevPreviewRootKey {
    <# A root as the hook normalises it, then compared the way a path is: slashes unified, trailing one cut, lowercase. #>
    param([AllowNull()][AllowEmptyString()][string]$Root)
    if (-not $Root) { return '' }
    return $Root.Replace('/', '\').TrimEnd('\').ToLowerInvariant()
}

function Test-RepoHubLocalUrl {
    <#
        True when -Url is a plain loopback url: http://localhost:<port> and an optional path of the characters
        Get-DevPreview's Path allows, at most 240 characters, the port 1024-65535, the path not opening with '//'. The one believe-rule for a state-file url that is
        a link or a redirect target (the hub's, the product's), so a file another process can write cannot
        point a link at another host, another scheme or a control character (#3245).
    #>
    param([AllowNull()][AllowEmptyString()][string]$Url)
    if (-not ($Url -cmatch '^http://localhost:([0-9]{4,5})(/[A-Za-z0-9._~/%?=&#+-]*)?\z') -or $Url.Length -gt 240) { return $false }
    # A real unprivileged port, and no path that opens with '//' (a protocol-relative look-alike).
    $port = [int]$Matches[1]
    if ($port -lt 1024 -or $port -gt 65535) { return $false }
    return -not ([string]$Matches[2]).StartsWith('//')
}

function Format-RepoHubState {
    <#
        The state file's text (#3245). -Hub is the Repository's url: the general server's own base plus '/' where
        the plugin serves the hub, the repo's own server where the repo opted out. -Pages is the general
        server's base url, '' where none is running. -Product is the repo's own server url, or ''. -Mode is
        what the repo states: 'none' (no Get-DevPreview, so the hub carries the setup cards), 'product' (a
        server of its own, one link on the plugin's hub) or 'ownhub' (OwnHub: its server is the hub, and the
        general server sends '/hub' there instead of rendering one). -Theme is the repo's DefaultTheme, or '' (#3390).
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [AllowEmptyString()][string]$Hub = '',
        [AllowEmptyString()][string]$Pages = '',
        [AllowEmptyString()][string]$Product = '',
        [ValidateSet('none', 'product', 'ownhub')][string]$Mode = 'none',
        [AllowEmptyString()][string]$Theme = ''
    )
    return ([ordered]@{ root = $Root; hub = $Hub; pages = $Pages; product = $Product; mode = $Mode; theme = $Theme } | ConvertTo-Json -Compress)
}

function ConvertFrom-RepoHubState {
    <#
        @{ Hub; Pages; Product; Mode; Theme } from the state file's -Text, each '' (Mode 'none') unless it can be
        believed: the file is JSON, its root is -Root (compared the way paths are), and each url is a plain
        loopback url -- the hub's and the product's with an optional path of the characters Get-DevPreview's
        Path allows (Test-RepoHubLocalUrl), the pages' a bare base on one of the general pages ports
        (Get-GeneralPagesPortRange), so a file another process can write cannot point a hub's links at any
        other local service. The urls are redirect targets and link hrefs, so a state file that names anything
        else is ignored. Mode is believed only as one of its three words; a file written before #3245 has
        none, and reads as 'none': the plugin's own hub. Theme is believed only in a theme id's shape
        (Test-DevPreviewThemeId), since every page writes it into its <html> (#3390).
    #>
    param([AllowNull()][AllowEmptyString()][string]$Text, [Parameter(Mandatory = $true)][string]$Root)
    $state = @{ Hub = ''; Pages = ''; Product = ''; Mode = 'none'; Theme = '' }
    if (-not $Text) { return $state }
    try { $s = $Text | ConvertFrom-Json } catch { return $state }
    if (-not $s -or -not $s.PSObject.Properties['root']) { return $state }
    if ((ConvertTo-DevPreviewRootKey ([string]$s.root)) -ne (ConvertTo-DevPreviewRootKey $Root)) { return $state }
    $h = if ($s.PSObject.Properties['hub']) { [string]$s.hub } else { '' }
    $p = if ($s.PSObject.Properties['pages']) { [string]$s.pages } else { '' }
    $q = if ($s.PSObject.Properties['product']) { [string]$s.product } else { '' }
    $m = if ($s.PSObject.Properties['mode']) { [string]$s.mode } else { '' }
    if (Test-RepoHubLocalUrl $h) { $state.Hub = $h }
    if (Test-RepoHubLocalUrl $q) { $state.Product = $q }
    if ($p -cmatch '^http://localhost:([0-9]{4,5})/?\z' -and (@(Get-GeneralPagesPortRange) -contains [int]$Matches[1])) { $state.Pages = $p.TrimEnd('/') }
    if ($m -cmatch '^(none|product|ownhub)\z') { $state.Mode = $m }
    $t = if ($s.PSObject.Properties['theme']) { [string]$s.theme } else { '' }
    if (Test-DevPreviewThemeId $t) { $state.Theme = $t }
    return $state
}
