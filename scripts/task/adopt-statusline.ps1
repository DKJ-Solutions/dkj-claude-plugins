<#
.SYNOPSIS
    Wires this repo's statusLine up to the workflow's progress bar -- issue #2103. Part 5 of
    'adopt-dkj-policy'.

.DESCRIPTION
    WHAT THE BAR IS FOR. A run this session backgrounds prints to nobody: a Bash call made with
    run_in_background streams no stdout to any visible surface at all, in the terminal CLI and in the
    VS Code extension alike. The statusLine is the one surface that keeps rendering while that is
    true, so the workflow's long runs PUBLISH a small record and the statusline DRAWS it. The whole
    argument is in run-progress-lib.ps1's own header; this command is only the wiring.

    WHY A COMMAND AND NOT PAYLOAD -- VERIFIED RATHER THAN ASSUMED (#2103's body asserted it, and it
    holds). Against the plugin reference: plugin.json carries no statusLine key; a plugin-root
    settings.json supports only 'agent' and 'subagentStatusLine'; and CLAUDE_PLUGIN_ROOT is not
    expanded in a statusLine command, nor exported to it. statusLine is a SETTINGS key, so nothing a
    plugin ships can place it and a command is the only route there is.

    IT PLACES A SHIM, NOT A PATH, AND THAT IS THE DECISION THIS COMMAND EXISTS AROUND (Dave,
    September 18, 2026). Three answers were on the table and two of them fail silently:

      - Write today's plugin-cache path into settings.json. The cache is keyed BY VERSION -- a
        machine holds dkj-policy 5.0.0 through 5.5.0 side by side -- so the next plugin update leaves
        the old payload exactly where it was and the statusline goes on rendering it. It keeps
        working, it renders stale code, and nothing reports it. That is the worst available failure:
        permanent, invisible, unmeasured.
      - Copy show-progress.ps1 and run-progress-lib.ps1 into the repo. Simplest, and it trades the
        staleness for two live copies drifting at every release with no lint over them -- which is
        the duplication the whole shared-scripts mechanism (#81) exists to prevent.
      - A SHIM: one small file that never changes, which resolves the CURRENT payload at run time and
        hands over to it. The path in settings.json is stable because the shim is stable; the logic
        stays in the plugin and travels by release like everything else.

    WHAT THE SHIM RESOLVES, AND WHY IT READS THE JSON ITSELF. It cannot dot-source check-report-lib's
    Get-InstallRecord, because that lib lives in the payload the shim is trying to find. So it reads
    ~/.claude/plugins/installed_plugins.json directly -- the same two fields plugin-versions.ps1
    reads (installPath, projectPath), and nothing else. That is the price of the stable path, and it
    is bounded: the shim's whole contract is "find the payload, hand over, never throw", so there is
    nothing in it that a release could need to change.

    STRICTLY ADDITIVE, AND REFUSE-AND-PRINT ON THE ONE KEY THAT IS SINGULAR. statusLine is one key per
    settings file, so a repo that already has one would have it REPLACED -- which every other adopt-*
    in this family refuses to do to anything. #2103's body left this open as "refuse-and-print vs.
    compose" and its own argument answers it: this run leaves an existing statusLine exactly as it is
    and prints the block for you to place by hand. Composing two statuslines is not on the table --
    there is one key, and merging two commands' output is a decision only the repo's owner can make.

    ADDITIVE MEANS THE BYTES, NOT ONLY THE KEYS (#2505). Until September 25, 2026 the key was added by
    a ConvertFrom-Json / ConvertTo-Json round trip. Every key survived -- which is what the suite
    asserted -- and every line did not: Windows PowerShell 5.1's serialiser column-pads each member and
    drops blank lines, so in BWJ-Development/xoxowildhearts a one-key addition to a 163-line file came
    back as a 164-line full-file diff nobody could review. So the member is now INSERTED as text before
    the root object's closing brace, in the file's own indent and line ending, with a BOM kept where
    there was one -- and the result is parsed back before it is written, so an insert that produced
    anything but the same keys plus statusLine writes nothing at all.

    AND IT SAYS SO WHEN GIT CANNOT SEE THE SHIM (#2505). A repo that ignores '.claude/*' with a list of
    exceptions -- the same consumer's shape -- hides the shim from 'git status' while the committed
    settings.json names it, so every other checkout gets a statusLine pointing at a file it never
    received. Nothing errors anywhere. 'git check-ignore' is asked about the shim's path on every run,
    dry runs included, and a hit prints the rule that matched and the exception line that fixes it. It
    warns and edits no .gitignore: the ignore file is the repo's own, and which exception it wants is
    not this command's to choose.

    REFUSED IN THE REPO THAT PUBLISHES THIS WORKFLOW. The source runs show-progress.ps1 from its own
    tree by a repo-relative path, which is the one arrangement the shim must not be written over: the
    source IS the payload, so resolving an install record to find itself would be a loop through the
    cache to reach a file two directories away.

.PARAMETER Apply
    Write. Without it this is a DRY RUN that prints exactly what it would place and touches nothing --
    the same default adopt-config, adopt-workflow-folder and adopt-ci-floor use, and for the same
    reason: the first run of a command that edits your settings should show you the edit.

.PARAMETER RootOverride
    Fixture seam: the repo to operate on. A consumer never types it.

    AND IT IS THE ONLY ONE, DELIBERATELY. There is no -UserHomeOverride here, which is worth saying
    because every sibling that touches the install administration has one: this command never reads
    it. Resolving the payload is the SHIM's job, at render time, which is the whole reason the shim
    exists -- so a home seam here would be a fixture knob over a read that does not happen.

.EXAMPLE
    .\scripts\task\adopt-statusline.ps1
    .\scripts\task\adopt-statusline.ps1 -Apply
#>

[CmdletBinding()]
param(
    [switch]$Apply,
    [string]$RootOverride = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The source-repo guard, wired the way every shared entry point wires it: a string literal names the
# lib (so scripts/tests/source-repo-guard.tests.ps1 can see the guard is present) and Assert-OwnCopy
# is called. It refuses a released copy run from inside the repo that maintains it.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# Repo root -- dual context: a consumer running the shared plugin mirror gets it from
# CLAUDE_PROJECT_DIR, a run inside this repo from git itself. RootOverride is the test seam.
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$repoRoot = Resolve-RepoRootOrFail -Override $RootOverride -ScriptName 'adopt-statusline.ps1' -OverrideName '-RootOverride'

# Test-IsWorkflowSourceRepo reads the marketplace manifest rather than merely testing for one, so only
# the repo that publishes THIS workflow is refused -- #998's narrowing, and the reason a consumer who
# publishes some other product is not turned away here.
. (Join-Path $PSScriptRoot '..\lib\seam-lib.ps1')
if (Test-IsWorkflowSourceRepo -RepoRoot $repoRoot) {
    Write-Host 'REFUSED: this repo publishes this workflow, so it is its source rather than a consumer.' -ForegroundColor Red
    Write-Host 'The source runs scripts/task/show-progress.ps1 from its own tree by a repo-relative path.'
    Write-Host 'A shim here would resolve an install record to find the very payload it is the source of.'
    Write-Host 'Nothing was written.'
    exit 1
}

$settingsRel = '.claude/settings.json'
$shimRel     = '.claude/statusline/dkj-progress.ps1'
$settingsAbs = Join-Path $repoRoot ($settingsRel -replace '/', '\')
$shimAbs     = Join-Path $repoRoot ($shimRel -replace '/', '\')

# FORWARD SLASHES IN THE COMMAND STRING, DELIBERATELY. The statusline documentation names this trap by
# itself: Git Bash treats unquoted backslashes as escape characters, so a Windows-style path reaches
# the script runner with its separators removed and the command fails with nothing visible to say so.
$statusLineCommand = 'powershell -NoProfile -ExecutionPolicy Bypass -File "' + $shimRel + '"'

# THE SHIM. Written once and never rewritten -- see the header for why that is the property the whole
# design turns on. It carries its own provenance line, so a reader who finds it in a repo can tell
# what put it there and which issue to read.
$shim = @'
<#
    dkj-policy statusline shim -- placed by adopt-statusline.ps1 (issue #2103). DO NOT EDIT.

    It exists so .claude/settings.json can name a path that never changes. The script it hands over to
    lives in the dkj-policy plugin payload, whose cache directory is keyed by VERSION -- so a path
    written straight into settings.json would go on rendering the version installed the day it was
    written, silently, forever. This file resolves the CURRENT payload instead, every time it runs.

    It reads the install administration itself rather than through check-report-lib's
    Get-InstallRecord, because that lib lives in the payload this file is looking for.

    IT NEVER THROWS AND ALWAYS EXITS 0. A status line runs every couple of seconds for as long as a
    session is open, so a failure here is not an error report -- it is a broken status line, repeated
    forever. Every failure path means "print nothing".
#>
$ErrorActionPreference = 'SilentlyContinue'

try {
    # Read the session payload HERE and hand it over as a parameter: the harness pipes it to this
    # process, so the script we call would otherwise find an already-drained stdin.
    #
    # BOUNDED, because a redirected handle nobody closes blocks forever and this runs every couple of
    # seconds -- one more wedged process per refresh, none of which prints anything (#2249). It is
    # written this way rather than with [Console]::In's own async methods because those belong to a
    # SyncTextReader, which overrides them to run synchronously on the calling thread, so a Wait()
    # after them is never reached. Get-HookPayloadRaw in the payload's session-cache-lib.ps1 is the
    # canonical copy and carries the measurement; the shim cannot dot-source it for the same reason it
    # reads installed_plugins.json itself -- that lib lives in the payload this file is looking for.
    $payload = ''
    if ([Console]::IsInputRedirected) {
        $sink = New-Object System.IO.MemoryStream
        if (([Console]::OpenStandardInput().CopyToAsync($sink)).Wait(1000)) {
            $sink.Position = 0
            $payload = (New-Object System.IO.StreamReader($sink, [System.Text.Encoding]::UTF8, $true)).ReadToEnd()
        }
    }

    $userHome = ''
    foreach ($candidate in @($env:USERPROFILE, $env:HOME)) {
        if ($candidate) { $userHome = $candidate; break }
    }
    if (-not $userHome) { exit 0 }

    $adminPath = Join-Path $userHome '.claude\plugins\installed_plugins.json'
    if (-not (Test-Path -LiteralPath $adminPath -PathType Leaf)) { exit 0 }

    $admin = Get-Content -LiteralPath $adminPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $admin -or -not $admin.plugins) { exit 0 }

    # This repo, normalized the way the records are, so a trailing separator or a different spelling
    # of the same path cannot make this repo's record look like somebody else's.
    $here = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path.TrimEnd('\', '/')

    # A PROJECT RECORD FOR THIS REPO FIRST, A PATHLESS ONE SECOND. A user-scope install carries no
    # projectPath and still serves this repo; a project record for SOMEBODY ELSE'S repo never does.
    #
    # THE MATCH IS ON THE PLUGIN NAME AND NOT ON THE WHOLE ID, DELIBERATELY. An id is
    # '<plugin>@<marketplace>', and the marketplace half is exactly the part that has changed under
    # this repo before -- so pinning the full id would strand every consumer whose marketplace is
    # named anything else, which is the staleness this whole file exists to avoid, arriving through
    # the matcher instead of through the path. ('dkj-policy-bwj@...' does not match: the character
    # after the name has to be the '@'.)
    #
    # WHICH MAKES SEVERAL MATCHES POSSIBLE, AND THAT IS THE CASE TO GET RIGHT. A marketplace rename
    # leaves a stale 'dkj-policy@<old>' record beside the current one, both naming this repo --
    # check-report-lib's Get-InstallRecord documents that exact pair as real and hands back ALL of
    # them so a caller can see the disagreement. This file cannot do that: its contract is to print
    # nothing and never report. So it collects every candidate and takes the most recently updated,
    # rather than whichever the enumeration happened to reach first -- an order nothing controls,
    # which is how a machine would render a stale payload permanently with no signal.
    $matched  = @()
    $pathless = @()
    foreach ($entry in @($admin.plugins.PSObject.Properties)) {
        if ("$($entry.Name)" -notlike 'dkj-policy@*') { continue }
        foreach ($record in @($entry.Value)) {
            if (-not $record -or -not $record.installPath) { continue }
            $projectPath = "$($record.projectPath)".TrimEnd('\', '/')
            if (-not $projectPath) { $pathless += $record; continue }
            if ($projectPath -eq $here) { $matched += $record }
        }
    }
    $candidates = @(if ($matched.Count) { $matched } else { $pathless })
    if (-not $candidates.Count) { exit 0 }

    $best = @($candidates | Sort-Object -Property @{ Expression = {
        # lastUpdated first, installedAt behind it: an update rewrites the first and leaves the
        # second at the original install. An unparseable or absent stamp sorts oldest, which is the
        # safe direction -- it loses a tie rather than winning one.
        $stamp = [datetime]::MinValue
        foreach ($field in @($_.lastUpdated, $_.installedAt)) {
            if ($field -and [datetime]::TryParse("$field", [ref]$stamp)) { break }
        }
        $stamp
    } } -Descending)[0]
    if (-not $best) { exit 0 }

    $target = Join-Path "$($best.installPath)" 'scripts\task\show-progress.ps1'
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { exit 0 }

    # IN-PROCESS, NOT A SUBPROCESS. show-progress.ps1's own header makes costing no process spawn the
    # point of the file, and a shim that spawned one would hand back exactly the cost it removed.
    & $target -Payload $payload
} catch { }

exit 0
'@

Write-Host ''
Write-Host "== adopt-statusline -- $repoRoot ==" -ForegroundColor Cyan
if (-not $Apply) {
    Write-Host 'DRY RUN -- nothing is written. Re-run with -Apply to place it.' -ForegroundColor Yellow
}
Write-Host ''

# --- 1. the shim ---------------------------------------------------------------------------------
# Additive, like every file this family places: one that is already there is left exactly as it is,
# whatever it contains. A re-run therefore finds nothing to do, which is what makes running this again
# after a plugin update harmless -- and correct, since the shim is the half that never needs updating.
if (Test-Path -LiteralPath $shimAbs -PathType Leaf) {
    Write-Host "  [keep]  $shimRel -- already here, left untouched"
} elseif ($Apply) {
    $shimDir = Split-Path -Parent $shimAbs
    if (-not (Test-Path -LiteralPath $shimDir -PathType Container)) {
        New-Item -ItemType Directory -Path $shimDir -Force | Out-Null
    }
    # BOM-less UTF-8, and the file is pure ASCII anyway: Set-Content -Encoding utf8 writes a BOM in
    # Windows PowerShell 5.1, and a BOM in front of a script is the sort of thing that reads fine here
    # and breaks something three tools downstream.
    [System.IO.File]::WriteAllText($shimAbs, ($shim -replace "`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "  [write] $shimRel" -ForegroundColor Green
} else {
    Write-Host "  [would write] $shimRel"
}

# --- 2. the settings key -------------------------------------------------------------------------
# REFUSE-AND-PRINT, NEVER REPLACE. statusLine is singular per settings file -- see the header.
$existingSettings = $null
$settingsReadable = $true
$settingsText     = ''
$settingsHadBom   = $false
if (Test-Path -LiteralPath $settingsAbs -PathType Leaf) {
    try {
        # BYTES, so a BOM can be written back exactly as it was found -- the insert below promises to
        # leave everything it did not add alone, and a BOM is part of everything.
        $bytes = [System.IO.File]::ReadAllBytes($settingsAbs)
        $settingsHadBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        $offset = $(if ($settingsHadBom) { 3 } else { 0 })
        $settingsText = (New-Object System.Text.UTF8Encoding($false)).GetString($bytes, $offset, $bytes.Length - $offset)
        if ($settingsText.Trim()) { $existingSettings = $settingsText | ConvertFrom-Json }
    } catch {
        $settingsReadable = $false
    }
}

function Get-MemberNames {
    <# The top-level member names of a parsed settings object -- none for $null and for '{}'. Callers
       wrap the call in @(), since a function returning @() hands back $null. Not
       '.PSObject.Properties.Name': under StrictMode that member enumeration THROWS on an object with
       no properties, which crashed -Apply on an empty settings file (#2505). #>
    param($Object)
    if ($null -eq $Object) { return @() }
    return @($Object.PSObject.Properties | ForEach-Object { $_.Name })
}

function Add-StatusLineMember {
    <# Insert the statusLine member into a settings file's TEXT, before the root object's closing brace,
       and return the new text -- or $null where the text has no closing brace to insert before.

       Everything that was there stays byte for byte (#2505): the member is written in the file's own
       indent unit (read off its first member, two spaces where there is none) and its own line ending,
       and the text after the closing brace -- a trailing newline, or none -- is kept as found. The
       caller has already parsed the text, so the last '}' in it IS the root's: valid JSON ends there. #>
    param([AllowEmptyString()][string]$Text, [string]$Command, [int]$Interval)
    $close = $Text.LastIndexOf('}')
    if ($close -lt 0) { return $null }
    $eol  = $(if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" })
    $unit = '  '
    $first = [regex]::Match($Text, '^\s*\{[ \t]*\r?\n([ \t]+)"')
    if ($first.Success) { $unit = $first.Groups[1].Value }
    $head = $Text.Substring(0, $close).TrimEnd()
    $tail = $Text.Substring($close)
    # An empty root ends its head in the '{' itself; anything else ends in a member, which takes a comma.
    $sep  = $(if ($head.EndsWith('{')) { '' } else { ',' })
    $cmd  = ($Command -replace '\\', '\\') -replace '"', '\"'
    $member = @(
        "$unit`"statusLine`": {"
        "$unit$unit`"type`": `"command`","
        "$unit$unit`"command`": `"$cmd`","
        "$unit$unit`"refreshInterval`": $Interval"
        "$unit}"
    ) -join $eol
    return ($head + $sep + $eol + $member + $eol + $tail)
}

# refreshInterval IS IN SECONDS, NOT MILLISECONDS (#2163). This carried 2000 until September 19, 2026,
# which Claude Code reads as 33 minutes: the timer never fired inside any real run, and the bar redrew
# only on the event-driven triggers -- a message sent, a turn ending -- so a backgrounded run showed a
# frozen count until the operator spoke. The statusline documentation states the unit and a minimum of 1.
$refreshIntervalSeconds = 2

$blockForPrinting = @"
  "statusLine": {
    "type": "command",
    "command": "$statusLineCommand",
    "refreshInterval": $refreshIntervalSeconds
  }
"@

if (-not $settingsReadable) {
    Write-Host "  [refuse] $settingsRel does not parse as JSON -- nothing was changed." -ForegroundColor Red
    Write-Host '           Repair the file first; this command will not rewrite one it cannot read.'
    Write-Host '           The block to place once it parses:'
    Write-Host ''
    Write-Host $blockForPrinting
    exit 1
}

$hasStatusLine = $false
if (@(Get-MemberNames $existingSettings) -contains 'statusLine') { $hasStatusLine = $true }

if ($hasStatusLine) {
    Write-Host "  [keep]  $settingsRel already defines a statusLine -- left exactly as it is." -ForegroundColor Yellow
    Write-Host '          There is one such key per settings file, so placing this one would REPLACE'
    Write-Host '          yours. Merging two status lines is a decision only you can make. The block:'
    Write-Host ''
    Write-Host $blockForPrinting
    Write-Host ''
    Write-Host '          The shim above is in place either way, so wiring it up later is a settings'
    Write-Host '          edit and nothing else.'
} elseif ($Apply) {
    # A missing or blank file is an empty object, so a new file comes out of the same insert as an
    # existing one rather than out of a second writer with a layout of its own.
    $baseText = $(if ($null -ne $existingSettings) { $settingsText } else { "{`n}`n" })
    $newText  = Add-StatusLineMember -Text $baseText -Command $statusLineCommand -Interval $refreshIntervalSeconds

    # PARSED BACK BEFORE IT IS WRITTEN. The insert is text surgery on somebody else's file, so what it
    # produced has to be the same keys plus statusLine -- anything else means the surgery misread the
    # file, and then the honest outcome is the original left alone and the block printed.
    $before = @(Get-MemberNames $existingSettings)
    $verified = $false
    if ($newText) {
        try {
            $parsed = $newText | ConvertFrom-Json
            $after  = @(Get-MemberNames $parsed)
            $verified = ("$($parsed.statusLine.command)" -ceq $statusLineCommand) -and
                        ($after.Count -eq $before.Count + 1) -and
                        (@($before | Where-Object { $after -notcontains $_ }).Count -eq 0)
        } catch { $verified = $false }
    }
    if (-not $verified) {
        Write-Host "  [refuse] $settingsRel -- the insert could not be verified, so nothing was changed." -ForegroundColor Red
        Write-Host '           Place the block by hand:'
        Write-Host ''
        Write-Host $blockForPrinting
        exit 1
    }

    $settingsDir = Split-Path -Parent $settingsAbs
    if (-not (Test-Path -LiteralPath $settingsDir -PathType Container)) {
        New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($settingsAbs, $newText, (New-Object System.Text.UTF8Encoding($settingsHadBom)))
    Write-Host "  [write] $settingsRel -- statusLine added, the rest of the file untouched" -ForegroundColor Green
} else {
    Write-Host "  [would write] $settingsRel -- statusLine added:"
    Write-Host ''
    Write-Host $blockForPrinting
}

# --- 3. can git see the shim? ----------------------------------------------------------------------
# A shim git ignores is a shim no other checkout receives, while the settings.json they DO receive names
# it -- see the header (#2505). Asked on a dry run too: the path is the same whether or not it exists
# yet, and a dry run is where the reader decides whether to apply. Exit 0 is "ignored", 1 is "not
# ignored"; anything else (no git, not a work tree) is said as unknown rather than read as clean.
$ignoreHit  = ''
$ignoreCode = -1
$savedEap = $ErrorActionPreference
try {
    $ErrorActionPreference = 'Continue'
    $ignoreHit  = "$(& git -C $repoRoot -c core.quotePath=true check-ignore -v -- $shimRel 2>$null)".Trim()
    $ignoreCode = $LASTEXITCODE
} catch {
    $ignoreCode = -1
} finally {
    $ErrorActionPreference = $savedEap
}

if ($ignoreCode -eq 0) {
    # -v prints '<source>:<line>:<pattern><TAB><path>'; the part before the tab is the rule that matched.
    $rule = Format-SafePathToken -Value (($ignoreHit -split "`t")[0])
    Write-Host ''
    Write-Host "  [WARNING] git IGNORES $shimRel -- matched by: $rule" -ForegroundColor Yellow
    Write-Host "            settings.json names this file, so every other checkout would get a statusLine"
    Write-Host '            pointing at a file it never received. Add an exception after that rule, e.g.:'
    Write-Host '                !.claude/statusline/'
    Write-Host '            and commit the shim with the settings change. Your .gitignore was not edited.'
} elseif ($ignoreCode -ne 1) {
    Write-Host ''
    Write-Host "  [note] could not ask git whether $shimRel is ignored -- check it yourself before committing:" -ForegroundColor Yellow
    Write-Host "         git check-ignore -v $shimRel"
}

Write-Host ''
Write-Host 'WHAT YOU GET, AND WHAT YOU DO NOT.' -ForegroundColor Cyan
Write-Host '  A bar for the long runs this workflow owns -- the test gate, and ship-pr waiting on CI.'
Write-Host '  Both publish from inside their own process, so nothing else has to be switched on.'
Write-Host '  With nothing running, the line shows the directory, the branch and the model.'
Write-Host ''
Write-Host '  The bar needs the payload this repo actually has installed. If nothing ever appears,'
Write-Host '  run plugin-versions.ps1: a payload released before #2103 landed carries no'
Write-Host '  scripts/task/show-progress.ps1 at all, and the shim then prints nothing, by design.'
