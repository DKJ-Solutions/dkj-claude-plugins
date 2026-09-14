<#
.SYNOPSIS
    Lay out, in rank order, every document that legislates in this repo -- the installed plugins'
    portable pages on one side, this repo's own law-bearing prose on the other -- so the session can
    read the two against each other and report where they contradict. It locates and hands over; it
    decides nothing and edits nothing.

.DESCRIPTION
    WHAT IT IS FOR. CONTRIBUTING-portable.md's "A third rank sits above both" states the order (the
    plugin's portable pages and skills > dkj-policy/CONTRIBUTING.md > the floor) and the
    corollary that keeps it: a consumer document may POINT at a shared law, or state this repo's answer
    to a seam that law names, or say nothing -- it may not RESTATE the law in its own words. A
    restatement is a copy, and a copy does not fail on the day it is written, only on the day the
    plugin's answer moves under it. Nothing delivered that corollary as a whole, and #1380 measured why
    no script can: a section restating a law almost always also names the mechanism it is talking about,
    so a pointer test cannot tell correct deference from restatement-with-citation-and-override.

    SO THIS IS NOT THE CHECK #1380 DECLINED, AND THE DIFFERENCE IS WHO JUDGES. That decline is about a
    SCRIPT deciding what a sentence means, and it stands. Here the script's whole job is the half a
    script is good at -- WHICH documents are on each side of the comparison, in WHICH order, and which
    of them exist on this machine -- and the judgement is handed to the session that invoked it, which
    can read prose. On-demand and report-only, in the shape of adopt-config and check-branch-entry
    rather than of a gate: no SessionStart hook calls it, no CI leg reads it, and it exits 0 once it has
    been able to answer at all. An exit code here would be a verdict it has not earned.

    THE TWO NARROW SLICES THAT *ARE* AUTOMATIC ARE ECHOED, NOT REBUILT. Get-RetiredDocNameMention
    (#1389, a retired filename) and Get-SupremacyDeclaration (#1415, 'CLAUDE.md' adjacent to
    'wins'/'wint') are the two greps #1380 recorded as proportionate, and both already run from
    check-consumer-prose.ps1 behind the consumer-prose-sessioncheck hook -- one script and one hook
    since #1421 merged their two, before either had shipped. This report calls those same two functions
    so its picture is complete and so there is one definition of each -- the same move
    check-branch-entry makes on open-pr's two -- and it labels them as already-gated, so nobody reads a
    silence here as coverage the hook does not give.

    THE CONSUMER'S SIDE IS THE #1380 CORPUS, and it is not re-derived: Get-CheckProseCorpus supplies the
    always-on closure and Get-ConsumerProseDocuments decides which of those documents a prose check may
    read. Every exclusion in there is load-bearing for a measured reason -- the changelog, releases/,
    plugin-shipped payload, the per-branch document -- and a second list here would be a second answer
    to a question that has one.

    THE PLUGIN SIDE IS DISCOVERED, NOT LISTED. Every plugin this repo has ENABLED (Get-EnabledPlugins,
    which reads the whole settings chain rather than settings.json alone) is probed for '*-portable.md'
    pages; a plugin that ships none is not a legislator and drops out on its own. That is why no
    companion is named here by hand: dkj-policy-bwj is today's second workflow plugin and a hard-coded list
    would be one more thing to update on the day there is a third. dkj-policy is printed
    first because the top rung has an internal order -- see that same section: where two plugin pages
    speak to the same question, its page wins and a companion's is an extension, never an override.

    AND THE ENABLE IS ONLY HALF OF "INSTALLED" (inbound #302), so the other half is REPORTED. Claude
    Code loads a plugin only when the settings chain enables it AND an install record exists for this
    project path; a plugin with just the first legislates nothing in a session here. Test-PluginInstalledHere
    answers it, and the answer is printed under the listing rather than used to exclude anything -- the
    pages are on disk either way and still worth reading against, and a missing record is a fact about
    the machine rather than about the prose.

    WHAT IT DOES NOT DO, deliberately:
      * it never edits a consumer's CLAUDE.md. Repairing a contradiction is an ordinary branch + PR in
        the repo that owns the file, and a script that rewrote always-on prose on its own would be
        making exactly the unreviewed change this whole section exists to prevent;
      * it does not read the plugin pages FOR you. It prints their paths. A run that summarised them
        would be a third copy of the law, in the one place nobody looks for it;
      * it does not refuse. See above: the verdict is not the script's.

    WHAT IT PRINTS OUT OF A CONSUMER'S FILES IS SANITIZED (#1419), for the reason its two echoed
    detectors give: this output is read back into a session, so a raw echo would let untrusted text
    choose how loudly it is reported and repaint a terminal on the way past. Paths go through
    Format-SafePathToken, prose through Format-SafeProseToken, and a plugin id -- an 'enabledPlugins'
    key name, i.e. an arbitrary JSON string -- through Format-SafeToken.

    NO gh, NO NETWORK. Every input is a file on this machine, which is what lets it answer in a
    consumer with no token.

    NOT TO BE CONFUSED WITH check-consumer-drift.ps1, which is source-repo-only and compares COPIES OF
    AGENT DEFS in a consuming repo against this repo's canonical ones. Same word, different subject:
    that one is about files that were duplicated, this one about laws that were paraphrased.

    RUN IT FROM THE COMMAND LINE whenever you want the manifest directly:

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/task/check-policy-drift.ps1

    Pure ASCII, per this repo's script-layer convention.

.PARAMETER RootOverride
    Repo root to operate on, for the test suite. A consumer never types this: the root is resolved
    dual-context like every other shared script.

.PARAMETER RootDocument
    (Optional, for tests) the always-on root to walk instead of '<root>/CLAUDE.md'.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/task/check-policy-drift.ps1
#>
[CmdletBinding()]
param(
    [string]$RootOverride = '',
    [string]$RootDocument = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD: refuses this file when it is the released MIRROR running in the repo that
# maintains it, so a consumer's copy is never the one that answers here. Guarded dot-source, so a tree
# without the lib behaves as before. Unlike the two prose CHECKS this report echoes, nothing automatic
# invokes this script -- no SessionStart hook, no CI leg -- so the guard has no hook to refuse.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

# Test-FunctionDefined (issue #1729): the seam probes below read the function table directly rather
# than through Get-Command, which parses the name as a wildcard pattern and pays a full PATH scan on
# every miss -- and a miss is the normal case for an optional seam. $PSScriptRoot-relative, so it
# resolves in the plugin mirror as well as here.
. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')

# THE ROOT COMES FROM ONE DEFINITION (#1422), the same call the two prose checks make. Dot-sourced
# guarded, so a mirror built before that lib existed degrades to the old inline form rather than throwing.
$checkRootLib = Join-Path $PSScriptRoot '..\lib\consumer-check-lib.ps1'
if (Test-Path -LiteralPath $checkRootLib -PathType Leaf) { . $checkRootLib }

$repoRoot = if (Test-FunctionDefined 'Resolve-CheckRepoRoot') {
    Resolve-CheckRepoRoot -RootOverride $RootOverride
} elseif ($RootOverride) { $RootOverride } elseif ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { '' }

# '' MEANS "COULD NOT TELL", and here that IS a failure rather than nothing to judge: this script is
# invoked deliberately, so a run with no tree to point at has been asked a question it cannot answer.
# That is the divergence Resolve-CheckRepoRoot documents and leaves to each caller.
if (-not $repoRoot) {
    Write-Host '[ERROR] no git checkout here -- there is no repo whose prose to lay out.' -ForegroundColor Red
    exit 1
}

. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\entry-scaffold-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\seam-lib.ps1')

# The marketplace reader, for candidate 1 in Get-PortablePageDir below. Guarded: it is registered as a
# shared lib, but a mirror built before it travelled leaves the cache probe as the only route, which is
# the correct answer in a consumer anyway.
$treeLib = Join-Path $PSScriptRoot '..\lib\plugin-tree-lib.ps1'
if (Test-Path -LiteralPath $treeLib -PathType Leaf) { . $treeLib }

# repo-config.ps1 first and optional, exactly as the two prose checks load it: a repo that HAS answered
# a seam is read by its own names rather than by the built-in defaults.
$repoConfig = Join-Path $repoRoot 'scripts\repo-config.ps1'
if (Test-Path -LiteralPath $repoConfig -PathType Leaf) {
    try { . $repoConfig } catch { Write-Warning "scripts/repo-config.ps1 failed to load ($($_.Exception.Message)) -- the built-in wording is used." }
}

function Get-PortablePageDir {
    <#
        WHERE A PLUGIN'S OWN PAGES SIT, asked of a plugin NAME and answered by probing rather than by
        assuming a layout, because there are four and this script runs under all of them:

          1. the SOURCE REPO, where the pages are a working tree the marketplace declares. Asked FIRST
             and on purpose: in the repo that publishes the plugin, the tree is the law and the cached
             copy is last release's answer to it, so a probe that found the cache first would report a
             contradiction against a page the author is in the middle of changing.
          2. $env:CLAUDE_PLUGIN_ROOT, honoured only when it names THIS plugin -- the hook/skill context,
             and the strongest answer there is: it is the copy the session is actually running.
          3. THE INSTALL RECORD for this repo, which is the authority on which cached version a session
             HERE loads. Consulted before the version scan, and for Resolve-PluginDir's own measured
             reason: a cache holding several versions is the normal state on a machine with more than
             one consumer, and "the newest version present" is a different question from "the version
             this repo loads".
          4. the MARKETPLACE CLONE (every plugin a sibling directory of this one), then the PLUGIN
             CACHE, newest version first -- Get-CachedPluginDirs' own [version] order rather than a
             string sort.

        STEPS 2 TO 4 ARE Resolve-PluginDir's THREE, AND THEY ARE RESTATED HERE RATHER THAN CALLED for
        one reason: that function requires an `agents/` directory at every return path. It was built for
        a roster check, and a WORKFLOW plugin ships `skills/` and no agents -- so calling it here would
        answer $null on every machine, for every workflow plugin, always. That is a question it was
        never built to answer rather than a corner case it misses.

        THE PROBE RUNS TWICE, and that is what lets one function answer two questions the caller needs
        apart. The first pass accepts only a candidate carrying a '*-portable.md' page, so a cached
        version that PREDATES the page is stepped over rather than reported as the plugin's answer. The
        second accepts any directory carrying '.claude-plugin/plugin.json', which is what makes a
        directory a plugin at all: a plugin located and shipping no page is a TEAM plugin doing exactly
        what it should, and saying nothing about it is correct. Returns '' only when neither pass found
        anything -- which is a stale cache or a dropped install, and worth a line.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Marketplace,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    $candidates = New-Object System.Collections.Generic.List[string]

    # 1. This repo's own marketplace, when it publishes one. Empty in every consumer, which is what
    #    Get-RepoPluginRoots returns there rather than throwing.
    if (Test-FunctionDefined 'Get-RepoPluginRoots') {
        try {
            $declared = Get-PluginRootByName -PluginRoots @(Get-RepoPluginRoots -RepoRoot $RepoRoot) -Name $Name
            if ($declared) { $candidates.Add([string]$declared.Root) | Out-Null }
        } catch {
            # A marketplace.json this repo cannot parse is somebody else's finding -- check-plugin-integrity
            # reports it. Here it only means candidate 1 has no answer, and the rest still do.
        }
    }

    # 2. The running copy, when the harness named it and it is this plugin's.
    if ($env:CLAUDE_PLUGIN_ROOT) {
        $cpr = $env:CLAUDE_PLUGIN_ROOT
        if ((Test-Path -LiteralPath $cpr -PathType Container) -and
            ((Split-Path (Split-Path $cpr -Parent) -Leaf) -eq $Name)) {
            $candidates.Add($cpr) | Out-Null
        }
    }

    # 3. The install administration's answer for THIS repo. Best-effort and never a gate in front of the
    #    scan below: Get-InstallRecord reports rather than throws, so an unreadable or absent
    #    administration leaves the remaining candidates answering exactly as they did before.
    try {
        $record = Get-InstallRecord -RepoRoot $RepoRoot
        $recId = "$Name@$Marketplace"
        if ($record.RecordsById.ContainsKey($recId)) {
            foreach ($rec in @($record.RecordsById[$recId])) {
                if ($rec.InstallPath) { $candidates.Add([string]$rec.InstallPath) | Out-Null }
            }
        }
    } catch { }

    # 4a. Sibling of this script's own plugin folder. $PSScriptRoot is '<plugin>/scripts/task' in the
    #     mirror, so its grandparent's parent is the folder that holds the other plugins.
    $ownRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $candidates.Add((Join-Path (Split-Path $ownRoot -Parent) $Name)) | Out-Null

    # 4b. The plugin cache. Get-CachedPluginDirs owns the path shape, so it is not rebuilt here.
    $userHome = Get-UserClaudeHome
    if ($userHome) {
        $cacheRoot = Join-Path $userHome '.claude\plugins\cache'
        if (Test-Path -LiteralPath $cacheRoot -PathType Container) {
            foreach ($dir in (Get-CachedPluginDirs -Name $Name -Marketplace $Marketplace -CacheRoot $cacheRoot)) {
                $candidates.Add($dir) | Out-Null
            }
        }
    }

    # Pass one: a candidate that actually carries a page. Pass two: any plugin directory at all.
    foreach ($wantPage in @($true, $false)) {
        foreach ($dir in $candidates) {
            if (-not $dir) { continue }
            if (-not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
            if ($wantPage) {
                if (@(Get-ChildItem -LiteralPath $dir -Filter '*-portable.md' -File -ErrorAction SilentlyContinue).Count -eq 0) { continue }
            } elseif (-not (Test-Path -LiteralPath (Join-Path $dir '.claude-plugin\plugin.json') -PathType Leaf)) {
                continue
            }
            return (Resolve-Path -LiteralPath $dir).Path
        }
    }
    return ''
}

function Write-ConsumerRank {
    # One rank of the consumer's own prose. Paths are repo-relative and sanitized; the line count is
    # this script's own arithmetic and needs none.
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [string[]]$Rels = @(),
        [Parameter(Mandatory = $true)][string]$Root
    )
    Write-Host ''
    Write-Host "  $Title" -ForegroundColor Cyan
    if ($Rels.Count -eq 0) {
        Write-Host '    (none) -- this repo carries no document at this rank.' -ForegroundColor DarkGray
        return
    }
    foreach ($rel in $Rels) {
        $full = Join-Path $Root ($rel -replace '/', '\')
        if (Test-Path -LiteralPath $full -PathType Leaf) {
            $lines = @(Get-Content -LiteralPath $full).Count
            Write-Host "      $(Format-SafePathToken -Value $rel)  ($lines lines)"
        } else {
            Write-Host "      $(Format-SafePathToken -Value $rel)  (absent)" -ForegroundColor DarkGray
        }
    }
}

Write-Host ''
Write-Host 'POLICY DRIFT -- the documents that legislate here, in rank order' -ForegroundColor Cyan
Write-Host "  repo: $(Format-SafePathToken -Value $repoRoot)"

$isSourceRepo = Test-IsWorkflowSourceRepo -RepoRoot $repoRoot
if ($isSourceRepo) {
    Write-Host '  NOTE: this repo PUBLISHES the workflow, so rank 1 below is its own working tree rather' -ForegroundColor DarkYellow
    Write-Host '        than an installed copy. The comparison is still real -- this is where the law is' -ForegroundColor DarkYellow
    Write-Host '        written, so a contradiction here is the source contradicting itself -- but a page' -ForegroundColor DarkYellow
    Write-Host '        and its own mirror are not two opinions, and nothing drifts while they agree.' -ForegroundColor DarkYellow
}

# ---------------------------------------------------------------------------------------------------
# RANK 1 -- the shared law
# ---------------------------------------------------------------------------------------------------
$enabled = Get-EnabledPlugins -RepoRoot $repoRoot
$ids = @($enabled.Ids)

# dkj-policy first: the top rung's own internal order, per "A third rank sits above both".
$ordered = @($ids | Where-Object { $_ -like 'dkj-policy@*' }) +
           @($ids | Where-Object { $_ -notlike 'dkj-policy@*' } | Sort-Object)

$rank1 = New-Object System.Collections.Generic.List[object]
$unlocated = New-Object System.Collections.Generic.List[string]
$notInstalledHere = New-Object System.Collections.Generic.List[string]

# THE ENABLE IS HALF THE ANSWER, AND THE OTHER HALF IS REPORTED RATHER THAN ENFORCED (inbound #302).
# Claude Code needs two things before a session loads a plugin: an enable in the settings chain and an
# install record for THIS project path. A plugin with only the first legislates nothing in a session
# here, so a report that listed its pages beside the rest would describe a law the session never reads.
# It stays in the listing -- its pages are on disk and worth comparing against -- and the missing record
# is said out loud beneath it, because that is a fact about the machine rather than about the prose.
$installRecord = $null
try { $installRecord = Get-InstallRecord -RepoRoot $repoRoot } catch { }

foreach ($id in $ordered) {
    if (-not $id) { continue }
    $parts = $id -split '@', 2
    if ($parts.Count -ne 2) { continue }
    $name = $parts[0]
    $marketplace = $parts[1]
    # Both values become a PATH below, so both go through the slug GUARDS rather than the display
    # sanitizers: Format-SafeToken decides how a value is shown, never whether it may be walked.
    if (-not (Test-PluginNameSlug -Name $name)) { continue }
    if (-not (Test-PluginMarketplaceSlug -Marketplace $marketplace)) { continue }

    $dir = Get-PortablePageDir -Name $name -Marketplace $marketplace -RepoRoot $repoRoot
    if (-not $dir) { $unlocated.Add($id) | Out-Null; continue }

    $pages = @(Get-ChildItem -LiteralPath $dir -Filter '*-portable.md' -File | Sort-Object Name)
    if ($pages.Count -eq 0) { continue }

    # NO `$installRecord -and` IN FRONT ANY MORE (#1994). $installRecord is $null whenever the try above
    # threw, and the clause was here to keep that value away from a Mandatory parameter that would have
    # ended the run on it. The predicate now takes $null and answers $true -- an absent authority is not
    # evidence of absence -- so the guarded branch is not taken either way and the behaviour is unchanged.
    # Stated rather than silently deleted: this call site is the one place in the tree that proved $null
    # reaches there, so it is also the place a reader checks whether the repair was real.
    if (-not (Test-PluginInstalledHere -InstallRecord $installRecord -PluginId $id)) {
        $notInstalledHere.Add($id) | Out-Null
    }
    foreach ($page in $pages) {
        $rank1.Add([pscustomobject]@{ Plugin = $name; Path = $page.FullName }) | Out-Null
    }
}

Write-Host ''
Write-Host '  RANK 1 -- the shared law: the portable pages of the plugins enabled here' -ForegroundColor Cyan
if ($rank1.Count -eq 0) {
    Write-Host '    (none found) -- no plugin enabled here ships a *-portable.md page.' -ForegroundColor DarkGray
} else {
    $lastPlugin = ''
    foreach ($row in $rank1) {
        if ($row.Plugin -ne $lastPlugin) {
            Write-Host "    $(Format-SafeToken -Value $row.Plugin)" -ForegroundColor Gray
            $lastPlugin = $row.Plugin
        }
        Write-Host "      $(Format-SafePathToken -Value $row.Path)"
    }
    Write-Host '    ...and the skills beside them, which carry the mechanics these pages describe.' -ForegroundColor DarkGray
}
foreach ($id in $notInstalledHere) {
    Write-Host "    [no install record] $(Format-SafeToken -Value $id) -- enabled in" -ForegroundColor DarkYellow
    Write-Host "                  $(Format-SafeToken -Value ([string]$enabled.LayerById[$id])), but with no install record for THIS repo a session here" -ForegroundColor DarkYellow
    Write-Host '                  does not load it. Its pages are listed above because they are on disk and still' -ForegroundColor DarkYellow
    Write-Host "                  worth reading against; fix with 'claude plugin install <id> --scope project'." -ForegroundColor DarkYellow
}
foreach ($id in $unlocated) {
    Write-Host "    [not located] $(Format-SafeToken -Value $id) -- enabled here, but no plugin directory for" -ForegroundColor DarkYellow
    Write-Host '                  it exists on this machine, so whatever it legislates was not read. That is a' -ForegroundColor DarkYellow
    Write-Host '                  stale cache or a dropped install -- refresh the marketplace.' -ForegroundColor DarkYellow
}

# ---------------------------------------------------------------------------------------------------
# RANKS 2 AND 3 -- this repo's own prose
# ---------------------------------------------------------------------------------------------------
$documents = if (Test-FunctionDefined 'Get-CheckProseCorpus') {
    @(Get-CheckProseCorpus -RepoRoot $repoRoot -RootDocument $RootDocument)
} else { @() }

$branchPaths = Get-BranchFilePaths
$consumerRels = @(Get-ConsumerProseDocuments -Documents $documents)
$folderPrefix = "$($branchPaths.Directory)/"

$rank2 = @($consumerRels | Where-Object { $_.StartsWith($folderPrefix, [System.StringComparison]::OrdinalIgnoreCase) })
$rank3 = @($consumerRels | Where-Object { -not $_.StartsWith($folderPrefix, [System.StringComparison]::OrdinalIgnoreCase) })

Write-ConsumerRank -Title "RANK 2 -- this repo's answers to the seams: $($branchPaths.Directory)/" -Rels $rank2 -Root $repoRoot
Write-ConsumerRank -Title 'RANK 3 -- the floor: the always-on closure (CLAUDE.md and what it imports)' -Rels $rank3 -Root $repoRoot

# ---------------------------------------------------------------------------------------------------
# The two slices that are already gated, echoed so the picture is complete
# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host '  ALREADY MECHANICAL -- the two greps #1380 recorded as proportionate. Both run from the' -ForegroundColor Cyan
Write-Host '  consumer-prose-sessioncheck hook, so these lines are an echo, never this report''s own finding.' -ForegroundColor DarkGray

# THE SKIP IS THE HOOK'S SKIP, AND IT IS COPIED RATHER THAN RE-DECIDED. check-consumer-prose.ps1 returns
# [OK] for both detectors without looking in the repo that PUBLISHES the workflow -- its pages narrate a
# rename history and declare a rank correctly, so the detectors would be right about the strings and
# wrong about the repo. The detector FUNCTIONS carry no such skip: it lives in the entry script. Calling
# the functions here without it would print findings under a heading that says they run from a
# SessionStart hook while that hook prints [OK] two lines away -- which is a report contradicting the
# gate it claims to be echoing.
#
# ONE SCRIPT AND ONE HOOK SINCE #1421, which merged check-retired-doc-name.ps1 and
# check-supremacy-declaration.ps1 into check-consumer-prose.ps1 and their two hooks into
# consumer-prose-sessioncheck -- one day after both were built and before either had shipped.
$retired = @()
$supremacy = @()
if ($isSourceRepo) {
    Write-Host '    [skipped] both, exactly as their own check skips the repo that publishes the workflow.' -ForegroundColor DarkGray
} else {
    $retired = @(Get-RetiredDocNameMention -RepoRoot $repoRoot -Documents $documents)
    $supremacy = @(Get-SupremacyDeclaration -RepoRoot $repoRoot -Documents $documents)
}

if (-not $isSourceRepo -and $retired.Count -eq 0) {
    Write-Host '    [clean] no retired branch-document name in this repo''s prose.' -ForegroundColor Green
} else {
    foreach ($f in $retired) {
        # Rel is the CONSUMER's path and is sanitized; Name is the retired filename, which comes out of
        # the plugin's own table -- the same split check-consumer-prose.ps1 makes, and for its reason.
        Write-Host "    [retired-name] $(Format-SafePathToken -Value $f.Rel):$($f.Line)  '$($f.Name)'" -ForegroundColor Yellow
    }
}

if (-not $isSourceRepo -and $supremacy.Count -eq 0) {
    Write-Host '    [clean] no inverted supremacy declaration.' -ForegroundColor Green
} else {
    foreach ($f in $supremacy) {
        Write-Host "    [supremacy]    $(Format-SafePathToken -Value $f.Rel):$($f.Line)  '$(Format-SafeProseToken -Value $f.Match)'" -ForegroundColor Yellow
    }
}

# Only the supremacy line quotes a consumer's own PROSE, so only it needs the disclosure. A retired name
# is the plugin's own string and goes out raw.
if ($supremacy.Count -gt 0) {
    Write-Host '    The supremacy phrase above is a PREVIEW: square brackets are shown as round ones, so' -ForegroundColor DarkGray
    Write-Host '    nothing in it reads as a marker of ours. Open the file and line for the text itself.' -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------------------------------
# The hand-over. This is the point of the whole run.
# ---------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host '  NOW READ THEM AGAINST EACH OTHER -- that half is yours, not this script''s.' -ForegroundColor Cyan
Write-Host '    For every statement in a RANK 2 or RANK 3 document that speaks to something RANK 1'
Write-Host '    legislates -- the branch and PR mechanics, the branch document, the gates, the tier'
Write-Host '    model, the fold, the release cut -- classify it as one of three, which is the corollary'
Write-Host '    in CONTRIBUTING-portable.md under "A third rank sits above both":'
Write-Host '      POINTER      it names the page that owns the answer and stops.  Correct, leave it.'
Write-Host '      SEAM ANSWER  it states THIS repo''s answer to a seam a RANK 1 page asks about.  Correct.'
Write-Host '      RESTATEMENT  it says the law again in its own words.  A copy -- report it, whether or'
Write-Host '                   not it currently agrees, because agreeing today is what a copy does.'
Write-Host '    Where a restatement CONTRADICTS the page above it, say which side wins by the rank order'
Write-Host '    and quote both lines. Rank 1 beats rank 2 beats rank 3; inside rank 1,'
Write-Host '    dkj-policy beats a companion plugin such as dkj-policy-bwj.'
Write-Host ''
Write-Host '    A law a RANK 1 page explicitly DECLINES to answer is the fourth move and not a copy --'
Write-Host '    cut-release''s "No seam, deliberately" is the measured instance. Read that block before'
Write-Host '    reporting a repo''s own answer to a delegated question as a restatement.'
Write-Host ''
Write-Host '    REPORT ONLY. The repair to a consumer''s own document is an ordinary branch + PR in the'
Write-Host '    repo that owns it, and nothing here has edited a single file.' -ForegroundColor DarkGray
Write-Host ''
exit 0
