<#
.SYNOPSIS
    Finds every live mention of a specialist's NAME, grouped by the layer it sits in, so a rename can
    be completed by hand without missing a place.

.DESCRIPTION
    A reporter, and deliberately nothing else. It reads; it never writes, renames, commits or edits.
    It is a tool you run AT a rename, not a gate that watches every PR, and it exits 0 on every
    finding -- however many mentions it reports, that is never a failure. The single exception is a
    repo root it cannot determine, which is a broken invocation rather than a verdict on the tree.

    WHY THIS IS NOT A GATE, decided before it was built. A check that matches on names is the shape
    this repo has already been bitten by: the name-matching candidate measured for the entry-format
    check produced six findings, all six false. Worse, the one rename this repo has performed
    (Sean -> Sebastian, a437df9, July 22 2026) DELIBERATELY left mentions standing -- the history under
    releases/, and the past-advice attribution comments in scripts and tests. A gate that turned those
    back to red would need an exemption list holding the very things the rename decided to keep, and a
    gate that is argued with is a gate that gets switched off. So this prints; the reader decides.

    WHY IT EXISTS AT ALL. The stable id (<group>-<id>) already carries every FILENAME, PATH and LINK,
    and the lint holds it -- so a rename never breaks a reference. What it does not carry is the name
    in prose, and that is where the work is. Measured with this script against the tree as it stood
    before this branch: Chris in 179 live mentions across 59 files, Sebastian in 46 across 18 -- a
    factor of four. The cost of a rename scales with how central the specialist is, and nothing until
    now could tell you that number before you started.

    THE NAMES ARE DERIVED, NEVER HARDCODED -- the same rule and the same two sources as the teardown
    skill's audit, because a hardcoded list is a guess that rots on the next rename:
      - an agent def's `name:` frontmatter, and
      - a persona's H1 (personas deliberately have no agent def).

    THE FOUR LAYERS, and why they are reported separately rather than as one count. They are not four
    degrees of the same thing; they are four different decisions:

      prose      the name IS the content -- "Chris never acts as Chris". Not a label. Rewriting these
                 is the rename.
      link text  the name is READING AID -- [Tessa #16](.../06-16-extension.md). The link already hangs
                 off the id, so these are safe to change and safe to leave.
      scripts    attribution of past advice -- "(Victor #3)", "Sylvester's lens". The Sean rename kept
                 these on purpose: they record who said something, on a day when that was their name.
      history    releases/ and CHANGELOG.md. Published record; the repo's standing rule is that these
                 stay as written. Counted, never listed, unless -IncludeHistory.

    Pure ASCII (repo convention for .ps1).

.PARAMETER Name
    The specialist to look for, as a display name ('Tessa'). Case-insensitive. Omit it to get the
    per-specialist totals instead -- the overview that says which rename is cheap and which is not.

.PARAMETER IncludeHistory
    Also LIST the history matches instead of only counting them. Off by default because those are the
    ones the repo has already decided to keep.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/sync/find-specialist-mentions.ps1
    # the overview: every specialist, and what a rename would cost

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/sync/find-specialist-mentions.ps1 -Name Tessa
    # every live mention of Tessa, grouped by layer, with file:line
#>
[CmdletBinding()]
param(
    [string]$Name = '',
    [switch]$IncludeHistory
)

$ErrorActionPreference = 'Stop'

# WHERE THE REPO ROOT COMES FROM (issue #2115). Not `rev-parse --show-toplevel`: it returns a raw path
# that Windows PowerShell 5.1 decodes with [Console]::OutputEncoding, so under an accented checkout the
# Test-Path below refused a root that was really there. Unconditional -- this script is workshop-only,
# never mirrored, so the lib is always beside it.
. (Join-Path $PSScriptRoot '..\lib\repo-root-lib.ps1')

$repoRoot = if ($env:CLAUDE_PROJECT_DIR) {
    $env:CLAUDE_PROJECT_DIR
} else {
    (Get-GitTopLevelPath).Path
}
if (-not $repoRoot -or -not (Test-Path -LiteralPath $repoRoot)) {
    Write-Error 'Cannot determine the repo root. Run this from inside the repo.'
    exit 1
}

# Get-DisplayName is the single source for turning a raw `name:` into a display name (issue #145).
# Dot-sourced UNCONDITIONALLY, like every sibling in this directory (check-roster-sync, check-connectors):
# this script is workshop-only and never mirrored, so the lib is always beside it. A guarded version with
# a local fallback stood here until review -- and the fallback was byte-identical to the real function,
# which makes it a silent copy free to drift rather than a degraded last resort.
. (Join-Path $repoRoot 'scripts/lib/check-report-lib.ps1')

# The transport and the decode for this script's ONE git call (issue #2110). Unconditional for the same
# reason as the lib above -- workshop-only, never mirrored, so both libs are always beside it and a
# guarded dot-source here would only be a fallback nobody can reach. Invoke-NativeCapture is what every
# other reader in this tree already uses instead of a bare native call, and Convert-GitQuotedPath is the
# decode the raw call did not have.
. (Join-Path $repoRoot 'scripts/lib/native-capture-lib.ps1')
. (Join-Path $repoRoot 'scripts/lib/git-porcelain-lib.ps1')

# ---------------------------------------------------------------------------
# 1. The roster: derived from the plugin payload, never hardcoded.
# ---------------------------------------------------------------------------

function Get-SpecialistRoster {
    <# Returns @(@{ Name = 'Tessa'; Id = '06-16' }, ...) read from every team plugin's agents/ and
       personas/. Reads BOTH shapes because a persona ships without an agent def. #>
    $roster = @()
    $pluginRoot = Join-Path $repoRoot 'plugins'
    if (-not (Test-Path -LiteralPath $pluginRoot)) { return $roster }

    foreach ($dir in @(Get-ChildItem -LiteralPath $pluginRoot -Directory -Recurse -ErrorAction SilentlyContinue |
                       Where-Object { $_.Name -in @('subagents', 'agents', 'personas') })) {
        foreach ($f in @(Get-ChildItem -LiteralPath $dir.FullName -Filter '*.md' -File -ErrorAction SilentlyContinue)) {
            $txt = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
            # The id comes from the filename, which the lint already holds to the frontmatter. Read
            # through the dual-name layer (#2130) rather than off a leading-digits anchor: under the
            # #2128 names the id no longer starts the filename, and this loop walks THREE kinds at once
            # -- so it asks each in turn and takes the first that recognises the name.
            $id = ''
            foreach ($kind in 'Subagent', 'Persona', 'Manual') {
                $id = Get-SpecialistFileId -Kind $kind -Name $f.Name
                if ($id) { break }
            }

            $m = [regex]::Match($txt, '(?m)^name:\s*([A-Za-z0-9_-]+)\s*$')
            if ($m.Success) {
                $roster += @{ Name = (Get-DisplayName -RawName $m.Groups[1].Value); Id = $id }
                continue
            }
            # Persona: the display name is the first word of the H1 ('# Derek <emoji> -- the DevOps ...').
            $h = [regex]::Match($txt, '(?m)^#\s+([A-Za-z][A-Za-z0-9_-]*)')
            if ($h.Success) {
                $roster += @{ Name = (Get-DisplayName -RawName $h.Groups[1].Value); Id = $id }
            }
        }
    }

    # One entry per name: a specialist that ships in more than one plugin is still one person.
    $seen = @{}
    $unique = @()
    foreach ($r in ($roster | Sort-Object { $_.Name })) {
        if (-not $r.Name -or $seen.ContainsKey($r.Name)) { continue }
        $seen[$r.Name] = $true
        $unique += $r
    }
    return $unique
}

# ---------------------------------------------------------------------------
# 2. The layers.
# ---------------------------------------------------------------------------

# Documentation written for a human reading GitHub, as opposed to context a model is fed. The
# distinction matters for a rename: a stale name here is read by a person who can see it is stale,
# while in the context layer it is read by a model that takes it at face value.
#
# A PATTERN, NOT A LIST, and that was a review finding rather than the first design. The list stood at
# nine hardcoded paths and was measured incomplete the same day: .claude/specialists/README.md alone
# carries eleven mentions of Chris and was being filed as CONTEXT, and six more READMEs under plugins/
# were missing too. A hardcoded path list is the same guess-that-rots the roster derivation refuses --
# so any README.md, wherever it sits, is a human document, plus the named few that are not called that.
$script:HumanDocNames = @('INSTALL.md', 'UNINSTALL.md', 'CONTRIBUTING.md', 'SECURITY.md', 'ADOPTION.md')

function Test-HumanDoc {
    param([string]$RelPath)
    $leaf = Split-Path -Leaf $RelPath
    if ($leaf -ieq 'README.md') { return $true }
    return ($script:HumanDocNames -icontains $leaf)
}

function Get-Layer {
    <# Which of the four decisions a path falls under. Order matters: history wins over everything,
       because a release note that happens to be a README is still history. #>
    param([string]$RelPath)

    $p = $RelPath -replace '\\', '/'

    # History: published record. The release-history README is the living index, not a record, so it is
    # excluded -- recognised at both of its addresses, since the hand-kept release pages moved into the
    # workflow folder on August 14, 2026 while a consumer's may still sit at the old one.
    if ($p -eq 'CHANGELOG.md') { return 'history' }
    if ($p -like 'releases/*' -and $p -ne 'releases/README.md') { return 'history' }
    if ($p -like 'dkj-policy/releases/*' -and $p -ne 'dkj-policy/releases/README.md') { return 'history' }

    if ($p -like 'scripts/tests/*') { return 'tests' }
    if ($p -like '*.ps1' -or $p -like '*.json' -or $p -like '*.yml' -or $p -like '*.yaml') { return 'scripts' }
    if (Test-HumanDoc -RelPath $p) { return 'docs' }

    return 'context'
}

# The order the detail view walks, and the ONLY statement of it -- it used to be declared here and then
# hardcoded a second time at the call site, with the two disagreeing.
$script:LayerOrder = @('context', 'docs', 'scripts', 'tests')
$script:LayerTitle = @{
    context = 'CONTEXT     read by a model on every session -- CLAUDE.md, lenses, manuals, personas, agent defs'
    docs    = 'DOCS        read by a human on GitHub'
    scripts = 'SCRIPTS     comments and docstrings -- the Sean rename kept these as attribution'
    tests   = 'TESTS       fixtures and assertions -- these match on the literal name'
    history = 'HISTORY     published record -- the standing rule is that these stay as written'
}

# ---------------------------------------------------------------------------
# 3. The scan.
# ---------------------------------------------------------------------------

function Get-ScannableFiles {
    <# Every tracked text file, via git so that ignored files and .git/ are excluded for free.

       THE WIRE IS HELD TO ASCII AND DECODED HERE (issue #2110, September 18, 2026), the repair
       .claude/rules/language-layers.md prescribes for this class. This read was a bare native call --
       `@(git ls-files 2>$null)` -- so Windows PowerShell 5.1 decoded the bytes with
       [Console]::OutputEncoding, whatever code page the run happened to inherit. A mis-decoded name keeps
       its `.md` tail, so it passes the extension filter below, and then cannot be OPENED: the file drops
       out of the mention scan silently, which is the one failure a scan whose whole job is "do not miss a
       place" must not have. The flag is FORCED rather than left to git's default, since a repo may set
       core.quotepath in its own config.

       AND THE TRANSPORT CHANGED WITH IT, which is the other half of #2110's item 2: a bare native call is
       the shape every other git reader in this tree has already left behind, and Invoke-NativeCapture
       hands back the exit code beside the output instead of leaving it in $LASTEXITCODE for a caller to
       remember to read -- which this one never did. `2>$null` was not what hid it (that redirects stderr
       and leaves $LASTEXITCODE alone, measured); nothing asked. `-C $repoRoot` replaces
       the Push-Location/Pop-Location pair -- git is told which tree to read rather than the process being
       moved into it, which is one fewer piece of global state for a reporter to restore.

       A GIT THAT WILL NOT ANSWER RETURNS NOTHING, as before. This script is a reporter that exits 0 on
       every finding; an empty scan set is reported by the counts it prints, and there is no verdict here
       to falsify. #>
    $lsFiles = Invoke-NativeCapture -FilePath 'git' `
        -Arguments @('-C', $repoRoot, '-c', 'core.quotePath=true', 'ls-files') -DiscardStderr
    if ($lsFiles.ExitCode -ne 0) { return @() }
    $files = @($lsFiles.Output | Where-Object { $_ } | ForEach-Object {
        Convert-GitQuotedPath -Path ([string]$_)
    })
    return @($files | Where-Object {
        $_ -match '\.(md|ps1|json|yml|yaml|txt)$'
    })
}

$script:LineCache = @{}

function Get-CachedLines {
    <# Each file read from disk once per run, not once per specialist. Without this the overview does
       roster-size x file-count full reads -- measured at ~11,000 for this tree, about 4 seconds.

       THE CALLER WRAPS THIS IN @(), AND MUST. PowerShell unrolls a one-element array on return, so a
       single-line file comes back as a bare string; indexing that walks CHARACTERS while .Count still
       reads 1, and the file silently reports nothing. That is not hypothetical -- it was the state of
       this function for one revision and hid every hit in the fixture's one-line .ps1 files while the
       multi-line ones kept working, which is exactly the shape a casual test survives.

       Wrapping HERE as well (`return ,$lines`) does not fix it and breaks it differently: @() around
       an already-wrapped array keeps the wrapper, so every line becomes the whole array. One
       mechanism, at the call site. #>
    param([string]$RelPath)
    if ($script:LineCache.ContainsKey($RelPath)) { return $script:LineCache[$RelPath] }

    $full = Join-Path $repoRoot $RelPath
    $lines = if (Test-Path -LiteralPath $full -PathType Leaf) {
        [System.IO.File]::ReadAllLines($full, [System.Text.Encoding]::UTF8)
    } else {
        @()
    }
    $script:LineCache[$RelPath] = $lines
    return $lines
}

function Get-LinkTextSpans {
    <# The character ranges covered by the TEXT half of each markdown link on a line -- the '[...]' of
       '[...](...)'. Returned as @(@{ Start = n; End = m }, ...), End exclusive. #>
    param([string]$Line)
    $spans = @()
    foreach ($m in [regex]::Matches($Line, '\[([^\]]*)\]\([^)]*\)')) {
        $g = $m.Groups[1]
        $spans += @{ Start = $g.Index; End = $g.Index + $g.Length }
    }
    return $spans
}

function Find-Mentions {
    <# Every OCCURRENCE of $TargetName, word-bounded so 'Cody' never matches inside 'Codyssey'.

       PER OCCURRENCE, NOT PER LINE, and that distinction was a review finding rather than the first
       design. Counting once per line under-reports, and -- worse -- it decides the link-text question
       for the whole line: 06-25-extension.md:430 names Sylvester twice, once inside a link and once in
       prose after it, and the line-based version reported one hit filed as 'link text (reading aid)'.
       The prose mention, which is the half a rename must actually rewrite, disappeared from the report
       behind the reassuring label. The docstring's own example -- 'Chris never acts as Chris' -- is the
       same shape, counted as one where it is two.

       So each occurrence is placed individually: its index is checked against the link-text spans on
       that line, and only an occurrence sitting INSIDE one is reading aid. #>
    param([string]$TargetName, [string[]]$Files)

    # IgnoreCase, because an agent def writes its own name lowercase in `name: tessa` -- and at a rename
    # that line is the first one that has to change. [regex]::Matches is case-SENSITIVE where
    # PowerShell's -match is not, so moving from one to the other silently dropped exactly those hits.
    $pattern = '\b' + [regex]::Escape($TargetName) + '\b'
    $opts    = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    $hits = @()

    foreach ($rel in $Files) {
        $lines = @(Get-CachedLines -RelPath $rel)
        if ($lines.Count -eq 0) { continue }

        $layer = Get-Layer -RelPath $rel
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            # Not $matches: that is an automatic variable PowerShell also writes on every -match.
            $nameMatches = [regex]::Matches($line, $pattern, $opts)
            if ($nameMatches.Count -eq 0) { continue }

            $spans = Get-LinkTextSpans -Line $line
            foreach ($m in $nameMatches) {
                $inLinkText = $false
                foreach ($s in $spans) {
                    if ($m.Index -ge $s.Start -and $m.Index -lt $s.End) { $inLinkText = $true; break }
                }
                $hits += [pscustomobject]@{
                    Path       = $rel
                    Line       = $i + 1
                    Layer      = $layer
                    InLinkText = $inLinkText
                    Text       = $line.Trim()
                }
            }
        }
    }
    return $hits
}

# ---------------------------------------------------------------------------
# 4. Output.
# ---------------------------------------------------------------------------

$roster = Get-SpecialistRoster
if ($roster.Count -eq 0) {
    Write-Host 'No specialists found under plugins/. Nothing to scan.'
    exit 0
}

$files = Get-ScannableFiles

if (-not $Name) {
    # The overview. Answers "which rename is cheap and which is not" before anyone starts one.
    Write-Host ''
    Write-Host '== specialist mentions, per name ==' -ForegroundColor Cyan
    Write-Host ''
    Write-Host ('  {0,-12} {1,6} {2,6} {3,7} {4,8}' -f 'specialist', 'id', 'live', 'oflink', 'history')
    Write-Host ('  {0,-12} {1,6} {2,6} {3,7} {4,8}' -f '----------', '--', '----', '------', '-------')

    $rows = @()
    foreach ($s in $roster) {
        $hits = Find-Mentions -TargetName $s.Name -Files $files
        $live = @($hits | Where-Object { $_.Layer -ne 'history' })
        $rows += [pscustomobject]@{
            Name    = $s.Name
            Id      = $s.Id
            Live    = $live.Count
            InLink  = @($live | Where-Object { $_.InLinkText }).Count
            History = @($hits | Where-Object { $_.Layer -eq 'history' }).Count
        }
    }

    foreach ($r in ($rows | Sort-Object -Property Live -Descending)) {
        Write-Host ('  {0,-12} {1,6} {2,6} {3,7} {4,8}' -f $r.Name, $r.Id, $r.Live, $r.InLink, $r.History)
    }

    $totalLive = ($rows | Measure-Object -Property Live -Sum).Sum
    Write-Host ''
    Write-Host ("  {0} live mentions across {1} specialists." -f $totalLive, $rows.Count)
    Write-Host '  live    = everything outside releases/ and CHANGELOG.md'
    Write-Host '  oflink  = of those, the ones sitting in a markdown link text (reading aid, not content)'
    Write-Host ''
    Write-Host '  Name one to see where they are:  -Name <specialist>'
    Write-Host ''
    exit 0
}

# One specialist, in detail.
$target = $roster | Where-Object { $_.Name -ieq $Name } | Select-Object -First 1
if (-not $target) {
    Write-Host ''
    Write-Host ("Unknown specialist: '{0}'" -f $Name) -ForegroundColor Yellow
    Write-Host ('Known: ' + (($roster | ForEach-Object { $_.Name }) -join ', '))
    Write-Host ''
    Write-Host 'A name that is NOT in this list but still appears in the tree is the interesting case:'
    Write-Host 'that is a retired name left behind. Nothing here refuses it -- it is scanned anyway.'
    Write-Host ''
    # Deliberately NOT an early exit: a retired name is exactly what somebody checking a finished
    # rename is looking for, and refusing to scan it would make this tool useless for its main job.
    $target = @{ Name = (Get-DisplayName -RawName $Name); Id = '--' }
}

$hits = Find-Mentions -TargetName $target.Name -Files $files
$live = @($hits | Where-Object { $_.Layer -ne 'history' })
$hist = @($hits | Where-Object { $_.Layer -eq 'history' })

Write-Host ''
Write-Host ("== {0} (#{1}) -- {2} live mentions in {3} files ==" -f `
    $target.Name, $target.Id, $live.Count, (@($live | Select-Object -ExpandProperty Path -Unique)).Count) -ForegroundColor Cyan

foreach ($layer in @('context', 'docs', 'scripts', 'tests')) {
    $inLayer = @($live | Where-Object { $_.Layer -eq $layer })
    if ($inLayer.Count -eq 0) { continue }

    Write-Host ''
    Write-Host ("-- {0}" -f $script:LayerTitle[$layer])

    # Within a layer, link text first: those are the decisions that are cheap.
    foreach ($group in @(@{ K = $true; L = 'link text (reading aid -- the link target already carries the id)' },
                         @{ K = $false; L = 'prose (the name is the content here)' })) {
        $subset = @($inLayer | Where-Object { $_.InLinkText -eq $group.K })
        if ($subset.Count -eq 0) { continue }
        Write-Host ("   {0} x {1}" -f $subset.Count, $group.L) -ForegroundColor DarkGray
        foreach ($h in $subset) {
            $snippet = if ($h.Text.Length -gt 96) { $h.Text.Substring(0, 93) + '...' } else { $h.Text }
            Write-Host ("     {0}:{1}: {2}" -f $h.Path, $h.Line, $snippet)
        }
    }
}

Write-Host ''
if ($IncludeHistory -and $hist.Count -gt 0) {
    Write-Host ("-- {0}" -f $script:LayerTitle['history'])
    foreach ($h in $hist) {
        $snippet = if ($h.Text.Length -gt 96) { $h.Text.Substring(0, 93) + '...' } else { $h.Text }
        Write-Host ("     {0}:{1}: {2}" -f $h.Path, $h.Line, $snippet)
    }
    Write-Host ''
} elseif ($hist.Count -gt 0) {
    Write-Host ("-- HISTORY: {0} more in releases/ and CHANGELOG.md. These stay as written -- the" -f $hist.Count)
    Write-Host '   published-record rule. Pass -IncludeHistory to list them anyway.'
    Write-Host ''
}

Write-Host 'Nothing was changed. This script only reads.'
Write-Host ''
exit 0
