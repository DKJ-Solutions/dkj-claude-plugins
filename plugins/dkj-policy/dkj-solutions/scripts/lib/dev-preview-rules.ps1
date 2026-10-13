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
                Name         = 'Showcase'       # optional: the word the message opens with
                WaitSeconds  = 20               # optional: how long to wait for the server to listen (1-45)
                OpenInVsCode = $false           # optional: also hand the URL to VS Code (see the hook)
            }
        }

    A repo that does not define it pays nothing: the hook prints nothing at all.

    OWNERSHIP IS READ OFF THE PROCESS TABLE, NOT OFF THE PORT. brandbook's rule, generalised: a listener
    is ours when its own command line, or one of its nearest ancestors' (the hook starts every server under
    a cmd.exe whose command line names the repo root), names THIS checkout's root. etf-tracker's HTTP probe
    and life-hub's "anything listening" both took a foreign process, or the same repo's server in another
    worktree, for their own. The ancestor walk is what lets a server whose own command line names no path
    at all (python -m http.server with a relative directory) still be recognised.

    A ROOT IS NAMED ONLY AT A PATH BOUNDARY. 'C:\x\repo' is not named by 'C:\x\repo-lanes\...' (the
    worktree-lane sibling) or by 'C:\x\repo2', and a nested Claude Code worktree under
    '<root>\.claude\worktrees\' is a different checkout, so a server started there is not ours either.

    Pure ASCII (repo convention for .ps1). Tested by scripts/tests/dev-preview-sessionstart.tests.ps1 in
    the source repo -- change one, run the other.
#>

$script:DevPreviewMaxAncestors = 4

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

    # THE NAME OPENS A LINE THAT REACHES THE SESSION'S CONTEXT, so it is held to a short plain label: no
    # control characters (a newline would start a line of the repo's choosing) and at most 40 characters.
    $name = ([string]$Raw['Name']) -replace '[\p{C}]', ' '
    if ($name.Length -gt 40) { $name = $name.Substring(0, 40) }
    if (-not $name.Trim()) { $name = 'dev-preview' }

    $result.Ok = $true
    $result.Config = @{
        Command      = $command
        Ports        = $ports
        Path         = $path
        Requires     = $requires
        Name         = $name.Trim()
        WaitSeconds  = $wait
        OpenInVsCode = [bool]$Raw['OpenInVsCode']
    }
    return $result
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
