<#
.SYNOPSIS
    Regression tests for the bwj-development plugin: its structure, its marketplace registration, the
    Asana task helpers in scripts/lib/asana-task-lib.ps1, and the go-live block.

.DESCRIPTION
    Dependency-free: no Pester, only PowerShell. Exit 0 if everything passes, 1 on a failure.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/bwj-development.tests.ps1

    The asana-mirror CI workflow (templates/asana-mirror.yml and .ps1) was retired on October 5, 2026;
    the helpers that survived live in scripts/lib/asana-task-lib.ps1 and are exercised by dot-sourcing
    it. Section 1 asserts those templates no longer ship. The closed message came back the same day as
    templates/asana-closed-message.yml and .ps1 (#2818), exercised by dot-sourcing that template.

    Pure ASCII (repo convention for .ps1).
#>

# What this suite's live-tree walks read (#3309): the extension's own folder (its *-portable.md chapter pages).
# gate-selection: walks plugins/dkj-policy/bwj-development/*

# Test-FunctionDefined (issue #1729): the retirement asserts below ask the function table directly
# rather than through Get-Command, whose miss path -- the case every one of those asserts is in --
# scans the whole PATH for an executable of that name.
. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\fixture-git-lib.ps1')
$ErrorActionPreference = 'Stop'
$RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$PluginRoot = Join-Path $RepoRoot 'plugins\dkj-policy\bwj-development'

$script:pass = 0
$script:fail = 0

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

function Assert-Throws {
    param([scriptblock]$Block, [string]$Name)
    try { & $Block; $script:fail++; Write-Host "  [FAIL] $Name (no exception)" -ForegroundColor Red }
    catch { $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green }
}

# --- 1. Plugin structure -------------------------------------------------------------------------
Write-Host "`n-- structure --" -ForegroundColor Cyan

$manifestPath = Join-Path $PluginRoot '.claude-plugin\plugin.json'
Assert-True (Test-Path -LiteralPath $manifestPath) 'plugin.json is present'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Assert-Equal 'bwj-development' $manifest.name 'plugin.json name is bwj-development'

foreach ($rel in @('README.md', 'WORKFLOW-portable.md', 'SYNC-LOG-portable.md', 'PREVIEW-portable.md',
                   'THEME-LIFECYCLE-portable.md',
                   'skills\report-issue\SKILL.md', 'skills\adopt-bwj-development\SKILL.md',
                   'skills\golive-block\SKILL.md',
                   'scripts\lib\golive-block-rules.ps1', 'scripts\task\build-golive-block.ps1',
                   'skills\prepare-release\SKILL.md', 'scripts\lib\prepare-release-rules.ps1',
                   'scripts\task\prepare-release.ps1',
                   'skills\notify-live\SKILL.md', 'scripts\lib\live-message-rules.ps1', 'scripts\lib\live-record-lib.ps1',
                   'scripts\task\notify-live.ps1',
                   'scripts\lib\asana-task-lib.ps1')) {
    Assert-True (Test-Path -LiteralPath (Join-Path $PluginRoot $rel)) "ships $rel"
}
# THE ASANA-MIRROR CI TEMPLATES ARE RETIRED (Dave, October 5, 2026): the workflow and its script are
# gone and the helpers that survived moved to scripts\lib\asana-task-lib.ps1. Pinned so a revert or a
# stray re-add of the folder is loud rather than a quiet second copy of the helpers.
Assert-True (-not (Test-Path -LiteralPath (Join-Path $PluginRoot 'templates\asana-mirror.yml'))) 'templates\asana-mirror.yml no longer ships'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $PluginRoot 'templates\asana-mirror.ps1'))) 'templates\asana-mirror.ps1 no longer ships'
# THE CLOSED MESSAGE CAME BACK, AND ONLY IT (#2818, Dave, October 5, 2026): one workflow, one script.
foreach ($rel in @('templates\asana-closed-message.yml', 'templates\asana-closed-message.ps1')) {
    Assert-True (Test-Path -LiteralPath (Join-Path $PluginRoot $rel)) "ships $rel"
}

# EVERY CHAPTER PAGE IS LINKED FROM THE README, and the README's own count agrees with how many there
# are. The count is stated in five places across four files, each edited by hand -- and it has now gone
# wrong twice: on #1435 ('README overview tables say bwj-codex has one rule; it now has two chapters'),
# and again when chapter three arrived as TWO pages from two same-day reports (#1874 and #1873) that
# did not know about each other, one of which had to be folded into the other. What is pinned is that
# the plugin's own README cannot disagree with its own folder; the overviews outside the plugin are
# prose and stay the dead-link gate's business.
$readmeTxt   = Get-Content -LiteralPath (Join-Path $PluginRoot 'README.md') -Raw
$chapterDocs = @(Get-ChildItem -LiteralPath $PluginRoot -Filter '*-portable.md' -File)
# FOUR SINCE #1965 (September 14, 2026): the theme lifecycle joined as chapter four. The literal is
# updated DELIBERATELY rather than derived from the folder -- a count that counted itself would pass
# over a chapter page added by accident, and over one deleted, which is the drift this whole block
# exists to catch.
Assert-Equal 4 $chapterDocs.Count 'the plugin ships four chapter pages'
foreach ($doc in $chapterDocs) {
    Assert-True ($readmeTxt -match [regex]::Escape("($($doc.Name))")) `
        "README links $($doc.Name) -- a chapter page nothing links is a chapter nobody finds"
}
# The word, not the digit: the README says 'three chapters' in prose, and a stale count there is
# exactly the drift #1435 was filed over.
$countWord = @{ 1 = 'one'; 2 = 'two'; 3 = 'three'; 4 = 'four'; 5 = 'five' }[$chapterDocs.Count]
Assert-True ($readmeTxt -match "(?i)\bIt has $countWord chapters\b") `
    "README states '$countWord chapters', matching the $($chapterDocs.Count) pages it ships"

Assert-True (-not (Test-Path -LiteralPath (Join-Path $PluginRoot 'agents'))) 'carries no agents/ (workflow rule)'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $PluginRoot 'manuals'))) 'carries no manuals/ (workflow rule)'

# skill folder name matches its frontmatter name:
foreach ($skill in @('report-issue', 'adopt-bwj-development', 'golive-block', 'prepare-release', 'notify-live')) {
    $txt = Get-Content -LiteralPath (Join-Path $PluginRoot "skills\$skill\SKILL.md") -Raw
    $nm  = [regex]::Match($txt, '(?m)^name:\s*(\S+)\s*$')
    Assert-Equal $skill $nm.Groups[1].Value "skill '$skill' frontmatter name matches its folder"
}

# THE ASANA PREFLIGHT PROBES THE BOARD, NOT THE TOOL LIST (#2028). Availability and authorization come
# apart: measured on a smartwatchbanden checkout, September 15, 2026, both registered Asana connectors
# were authenticated and both answered `unauthorized` for the project the seam names, because the MCP
# was bound to a different workspace than the one ASANA_PAT drove the same board with. A preflight
# asking only whether the tools EXIST passes in exactly that state, and step 2's `create task` is then
# where the session finds out -- half way through the procedure the preflight exists to get ahead of.
#
# Pinned here because NOTHING ELSE READS IT: this page is prose, and the gates read manifests and
# frontmatter. The availability wording is also the shape the rule relapses into, being the shorter and
# more obvious half of the pair.
#
# SCOPED TO THE PREFLIGHT BLOCK, not the whole page: step 2 names Get-AsanaProjectGid too, so a
# page-wide sweep would stay green with the preflight bullet deleted -- the one edit this guards.
#
# MEASURED AGAINST THE PRE-BRANCH TREE rather than asserted: run over `main`, the retired pattern hits
# (on the very line #2028 reported) and all three required patterns miss, so this block is red there
# and green here. A sweep green on the tree it was written for proves nothing about the one it was
# written against.
$reportIssue = Get-Content -LiteralPath (Join-Path $PluginRoot 'skills\report-issue\SKILL.md') -Raw
$preflight   = [regex]::Match($reportIssue, '(?s)##\s+Before you start(.*?)\r?\n##\s').Groups[1].Value
Assert-True ($preflight.Length -gt 0) "report-issue still has a 'Before you start' preflight to read"

Assert-True (-not [regex]::IsMatch($preflight, '(?i)Asana MCP tools are available')) `
    'report-issue no longer states the Asana preflight as a tool-AVAILABILITY check'

foreach ($needed in @(
    @{ Pattern = '(?i)unauthorized';                What = 'names an unauthorized board as a preflight outcome' },
    @{ Pattern = 'Get-AsanaProjectGid`? names';     What = 'probes the project the seam names' },
    @{ Pattern = '(?i)wrong\s+\*{0,2}workspace';    What = 'has the note name the wrong workspace as the cause' }
)) {
    Assert-True ([regex]::IsMatch($preflight, $needed.Pattern)) `
        "report-issue's Asana preflight $($needed.What)"
}

# --- 2. Marketplace registration + lockstep version --------------------------------------------
Write-Host "`n-- marketplace --" -ForegroundColor Cyan

$marketplace = Get-Content -LiteralPath (Join-Path $RepoRoot '.claude-plugin\marketplace.json') -Raw | ConvertFrom-Json
$entry = $marketplace.plugins | Where-Object { $_.name -eq 'bwj-development' }
Assert-True ($null -ne $entry) 'bwj-development is listed in marketplace.json'
Assert-Equal './plugins/dkj-policy/bwj-development' $entry.source 'marketplace source points at the plugin folder'

$alphaManifest = Get-Content -LiteralPath (Join-Path $RepoRoot 'plugins\dkj-subagents\dkj-subagents-alpha\.claude-plugin\plugin.json') -Raw | ConvertFrom-Json
Assert-Equal $alphaManifest.version $manifest.version 'version is in lockstep with dkj-subagents-alpha'

# BOTH DESCRIPTIONS STATE THE SAME CHAPTER COUNT as the folder ships ($countWord, from section 1).
# plugin.json's and marketplace.json's descriptions are two hand-written copies of one blurb, and they
# drifted on the branch that added chapter three: the marketplace entry was updated while the plugin's
# own manifest still said two. Only the COUNT is pinned, never the whole text -- the two are
# deliberately worded for different readers (the installed plugin's own card, and the catalogue row),
# so a byte compare would be a rule nobody wants.
foreach ($blurb in @(
    @{ What = 'plugin.json';      Text = [string]$manifest.description },
    @{ What = 'marketplace.json'; Text = [string]$entry.description }
)) {
    Assert-True ($blurb.Text -match "(?i)\b$countWord chapters\b") `
        "$($blurb.What) description states '$countWord chapters' -- the two blurbs cannot disagree on the count"
}

# --- 3. the Asana task helpers (scripts/lib/asana-task-lib.ps1) ------------------------------------
Write-Host "`n-- asana-task-lib helpers --" -ForegroundColor Cyan

. (Join-Path $PluginRoot 'scripts\lib\asana-task-lib.ps1')

# The task GID an issue body resolves to, or $null -- the one answer most asserts below want.
function Get-TestTaskGid {
    param([string]$IssueBody)
    return (Resolve-AsanaTaskRef -IssueBody $IssueBody).Gid
}

# GID extraction
Assert-Equal '1201234567890123' (Get-TestTaskGid "text`n<!-- asana-task: 1201234567890123 -->`nmore") 'Resolve-AsanaTaskRef reads the marker'
Assert-Equal '1201234567890123' (Get-TestTaskGid '<!--asana-task:1201234567890123-->') 'Resolve-AsanaTaskRef tolerates no inner spaces'
Assert-True  ($null -eq (Get-TestTaskGid 'no marker here')) 'Resolve-AsanaTaskRef returns a null GID when absent'
Assert-True  ($null -eq (Get-TestTaskGid '<!-- asana-task: not-a-number -->')) 'Resolve-AsanaTaskRef rejects a non-numeric marker'
Assert-True  ($null -eq (Get-TestTaskGid '')) 'Resolve-AsanaTaskRef handles an empty body'
# matcher 2 -- the header row of a ticket imported FROM Asana (the intake shape). This is the case the
# marker alone could not reach: issue #388 in smartwatchbanden closed with its Asana task untouched,
# and the CI log said so in as many words -- "No <!-- asana-task: ... --> marker ... nothing to mirror".
$intake = @'
# 0150 CRO WIN | Lieferdatum unter ATC-button

| | |
|---|---|
| **Asana** | [1216905543348385](https://app.asana.com/1/1199613597897177/project/1214594032889511/task/1216905543348385) - project Development BWJ |
| **State** | buildable |

A sibling ticket is https://github.com/BWJ-ecommerce/smartwatchbanden/issues/390.
'@
$ref = Resolve-AsanaTaskRef -IssueBody $intake
Assert-Equal '1216905543348385' $ref.Gid    'header row of an imported ticket resolves its task'
Assert-Equal 'header-row'       $ref.Source 'and reports header-row as the source'

# the header row wins over any other Asana link in the body -- it is the ticket's own task
$sibling = "| **Asana** | [a](https://app.asana.com/1/9/project/8/task/111) |`nalso https://app.asana.com/1/9/project/8/task/222"
Assert-Equal '111' (Get-TestTaskGid $sibling) 'the header row wins over a sibling link further down'

# the marker wins over everything, so an issue that carries one is never re-matched
$both = "| **Asana** | [a](https://app.asana.com/1/9/project/8/task/111) |`n<!-- asana-task: 999 -->"
Assert-Equal 'marker' (Resolve-AsanaTaskRef -IssueBody $both).Source 'the marker outranks the header row'
Assert-Equal '999'    (Get-TestTaskGid $both)      'and it is the marker GID that is used'

# matcher 3 -- a single Asana task URL anywhere, in either URL shape Asana hands out
Assert-Equal '1216905543348385' (Get-TestTaskGid 'see https://app.asana.com/1/9/project/8/task/1216905543348385') 'a sole modern task URL resolves'
Assert-Equal '1216905543348385' (Get-TestTaskGid 'see https://app.asana.com/0/1214594032889511/1216905543348385/f') 'a sole classic task URL resolves'
Assert-Equal 'sole-url'         (Resolve-AsanaTaskRef -IssueBody 'https://app.asana.com/1/9/project/8/task/77').Source 'and reports sole-url as the source'

# several DIFFERENT tasks and no marker -- reported, never guessed
$ambiguous = Resolve-AsanaTaskRef -IssueBody 'a https://app.asana.com/1/9/project/8/task/111 b https://app.asana.com/1/9/project/8/task/222'
Assert-True  ($null -eq $ambiguous.Gid)   'two different linked tasks resolve to nothing'
Assert-Equal 'ambiguous' $ambiguous.Source 'and are reported as ambiguous'
Assert-Equal 2 $ambiguous.Candidates.Count 'with both candidates named for the log'

# the same task linked twice is not ambiguous
Assert-Equal '111' (Get-TestTaskGid 'a https://app.asana.com/1/9/project/8/task/111 b https://app.asana.com/1/9/project/8/task/111') 'the same task linked twice still resolves'

# a project link names no task
Assert-True ($null -eq (Get-TestTaskGid 'board: https://app.asana.com/1/9/project/8')) 'a project link contributes no task GID'

# a non-numeric task GID can never reach a request URL
Assert-Throws { Get-AsanaTaskState -Gid 'abc' -Pat 'x' } 'Get-AsanaTaskState throws on a non-numeric GID'
# THE CENTRAL GUARANTEE (Dave, 2026-09-01): automation never resolves a task -- the colleague who
# filed it does, after testing. So the lib must carry no way to write 'completed' at all. This is
# asserted over the source text rather than over behaviour, because the guarantee is the ABSENCE of a
# code path and no call can demonstrate an absence.
$libSrc = Get-Content -LiteralPath (Join-Path $PluginRoot 'scripts\lib\asana-task-lib.ps1') -Raw
Assert-True (-not (Test-FunctionDefined 'New-AsanaCompleteRequest')) 'no request builder for completing a task exists'
Assert-True (-not (Test-FunctionDefined 'Set-AsanaTaskCompleted')) 'no helper for completing a task exists'
Assert-True ($libSrc -notmatch "completed\s*=\s*\`$(true|false)") 'the lib never builds a completed=true/false payload'
Assert-True ($libSrc -notmatch "(?m)^\s*[^#]*-Method\s+(PUT|POST|DELETE)") 'the lib issues no write at all -- Get-AsanaTaskState only reads'

# the GitHub-side marker and lead sentence of the paste-ready go-live block
$hdr = "$([char]0x2014) GitHub automation $([char]::ConvertFromUtf32(0x1F916))"
$pasteMarker = Get-AsanaPasteBlockMarker
$pasteLead   = Get-AsanaPasteBlockLead
Assert-True ($pasteMarker -match '^<!--.*-->$')  'the paste-block marker is an HTML comment, so it renders as nothing'
Assert-True ($pasteLead.Length -gt 20)           'and the prose matcher is a whole sentence, not a word that could occur by chance'

# The two matchers are what a session-written block has to carry, so they are asserted against the
# shape WORKFLOW-portable.md publishes rather than only against this script's own output.
$bwjWorkflowText = Get-Content -LiteralPath (Join-Path $PluginRoot 'WORKFLOW-portable.md') -Raw
Assert-True ($bwjWorkflowText.Contains($pasteMarker)) 'WORKFLOW-portable.md publishes the same marker the script matches on'
Assert-True ($bwjWorkflowText.Contains($pasteLead))   'and the same lead sentence'

# --- the reach label is a seam, not a literal (issue #1841) ---------------------------------------
Write-Host "`n-- the reach label --" -ForegroundColor Cyan

# A consumer may rename the GitHub label that carries the reach axis -- smartwatchbanden renamed
# 'tier-1' to 'minor' on September 11, 2026 -- so every place this plugin TYPES a label name reads
# Get-ReachLabel instead. Since #1870 'minor' is the workflow's own default and the axis is defined one
# layer up, in dkj-policy's RELEASES-portable.md; what stays repo-specific is the string GitHub stores,
# never the model. So these asserts are aimed at the COMMANDS and nothing else, which is why they match
# on the flag as well as on the name rather than on 'tier-1' anywhere in the file -- the word is still
# legitimate prose here, naming the store that has not renamed its label.
$reachDocs = @{
    'skills\report-issue\SKILL.md'        = 'report-issue'
    'skills\adopt-bwj-development\SKILL.md' = 'adopt-bwj-development'
    'WORKFLOW-portable.md'                 = 'WORKFLOW-portable'
    'README.md'                            = 'README'
}
# ONE PATTERN PER SHAPE THE BRANCH ACTUALLY REPAIRED, and the fourth is the reason to say that out
# loud: the label-EXISTENCE check (gh label list | grep -E '^(tier-1|documentation)\b') is neither a
# --label flag nor a create nor a search query, so the first three leave the exact line #1841 was filed
# over unguarded. A guard that covers three of the four sites reads as covering all of them.
$reachLiterals = @(
    @{ Pattern = '--(?:add-|remove-)?label\s+["'']?tier-1\b'; What = "writes no '--label tier-1'" }
    @{ Pattern = 'gh\s+label\s+create\s+["'']?tier-1\b';      What = "creates no label named 'tier-1' outright" }
    @{ Pattern = 'label:tier-1\b';                            What = "writes no 'label:tier-1' search query" }
    @{ Pattern = '\^\((?:[^)\r\n]*\|)?tier-1[|)]';            What = "greps the label list for no literal 'tier-1'" }
)
foreach ($rel in $reachDocs.Keys) {
    $txt = Get-Content -LiteralPath (Join-Path $PluginRoot $rel) -Raw
    foreach ($lit in $reachLiterals) {
        Assert-True (-not [regex]::IsMatch($txt, $lit.Pattern)) `
            "$($reachDocs[$rel]) $($lit.What) -- the name comes from Get-ReachLabel"
    }
}

# And the seam has to be documented where a consumer looks for it, or the asserts above only prove the
# literal is gone rather than that anything replaced it. Same set as above, read from the same
# hashtable: two hand-kept lists would drift the moment a document joins or leaves one of them.
foreach ($rel in $reachDocs.Keys) {
    $txt = Get-Content -LiteralPath (Join-Path $PluginRoot $rel) -Raw
    Assert-True ($txt -match 'Get-ReachLabel') "$($reachDocs[$rel]) names the Get-ReachLabel seam"
}

# The PROPOSED value is 'tier-1', and since #1870 that is no longer the default but the opposite: the
# workflow defaults to 'minor', so this snippet is proposed precisely to a store that has NOT renamed
# its label and would otherwise file against a name it does not have. The subject is the VALUE and not
# the snippet's formatting: an optional 'return', either quote style and a trailing ';' are all the
# same answer, and pinning the assert to one spelling would fail on a reflow that changed nothing.
$adoptTxt = Get-Content -LiteralPath (Join-Path $PluginRoot 'skills\adopt-bwj-development\SKILL.md') -Raw
Assert-True ([regex]::IsMatch($adoptTxt, 'function\s+Get-ReachLabel\s*\{\s*(?:return\s+)?(["''])tier-1\1\s*;?\s*\}')) `
    'the proposed seam states tier-1 -- the answer a store that has not renamed its label owes'

# --- every label step 4 checks for is also created (issue #1846) ----------------------------------
Write-Host "`n-- step 4's label-existence check --" -ForegroundColor Cyan

# The check greps the repo's label list for the names report-issue files with, and a name it reports
# missing is only useful if the step then says how to create it. It named two and created one until
# September 11, 2026: 'documentation' was checked for and never created, so a repo without it got a
# hit in the check and no instruction -- and report-issue's `--label documentation` then fails at the
# gh issue create exactly as the reach label does. Both BWJ stores carry the label (it is one of
# GitHub's defaults), which is what kept the gap invisible rather than what made it safe.
#
# THE ASSERT IS THE INVARIANT, NOT THE ONE NAME. A third name added to the grep without its own
# create line reopens precisely this gap, and an assert pinned to 'documentation' would pass over it.
# The seam's '<reach label>' placeholder is skipped, and that skip is load-bearing rather than tidy:
# the line reads `gh label create "<reach label>"`, where \b cannot fire between '>' and '"' -- both
# non-word -- so without it the placeholder would fail an assert the reach-label block above already
# owns.
#
# EXACTLY ONE check line, not the first of several. Regex.Match returns the leftmost hit, so binding
# to a stale or unrelated `gh label list ... grep -E '^(...)` further up would swap the subject of
# every assert below without failing one. The file already mentions `gh label list` in prose, so the
# count is asserted rather than the existence.
$grepMatches = [regex]::Matches($adoptTxt, "gh label list[^\r\n]*grep\s+-E\s+'\^\(([^)]*)\)")
Assert-Equal 1 $grepMatches.Count 'adopt-bwj-development step 4 carries exactly one label-existence check'
if ($grepMatches.Count -eq 1) {
    foreach ($labelName in ($grepMatches[0].Groups[1].Value -split '\|')) {
        if ($labelName -match '^<.*>$') { continue }
        # The tail is anchored on what may legally follow a label name -- whitespace, a closing quote
        # or end of line -- and NOT on \b, which also fires on a hyphen: a step that gained a
        # 'documentation-only' label would then satisfy the assert for 'documentation'.
        $createPattern = 'gh\s+label\s+create\s+(["''])?' + [regex]::Escape($labelName) + '(?=\s|["'']|$)'
        Assert-True ([regex]::IsMatch($adoptTxt, $createPattern)) `
            "step 4 creates the '$labelName' label its own check greps for"
    }
}

# --- the documentation label is retired (issue #2783) ---------------------------------------------
# Every issue is a bug or a feature, so nothing files with, checks for or creates 'documentation'.
# Aimed at the WRITING commands only: the word stays legitimate prose, and step 4's cleanup still has
# to LIST the issues on the label (gh issue list --label documentation) to take it off them.
foreach ($rel in $reachDocs.Keys) {
    $txt = Get-Content -LiteralPath (Join-Path $PluginRoot $rel) -Raw
    Assert-True (-not [regex]::IsMatch($txt, '(?:--add-label\s+|gh\s+issue\s+create[^\r\n]*--label\s+)["'']?documentation\b')) `
        "$($reachDocs[$rel]) files with no '--label documentation' (#2783)"
}
Assert-True (-not [regex]::IsMatch($adoptTxt, 'gh\s+label\s+create\s+["'']?documentation\b')) `
    'adopt-bwj-development step 4 creates no documentation label (#2783)'
Assert-True (-not [regex]::IsMatch($adoptTxt, "Label\s*=\s*'documentation'")) `
    'adopt-bwj-development proposes no prefix-table row labelled documentation (#2783)'

# --- the go-live half of the paste-ready block (issue #2100) --------------------------------------
Write-Host "`n-- the go-live block --" -ForegroundColor Cyan

. (Join-Path $PluginRoot 'scripts\lib\golive-block-rules.ps1')

# THE NEXT RELEASE DAY IS STRICTLY AFTER, and the Monday-on-a-Monday case is the one that matters: BWJ
# cuts in the morning, so work closing later that day ships with the NEXT one. A block naming today
# would send a colleague looking for something that went out before it was built.
Assert-Equal ([datetime]'2026-09-21') (Get-NextReleaseDate -From ([datetime]'2026-09-18')) 'a Friday resolves to the following Monday'
Assert-Equal ([datetime]'2026-09-28') (Get-NextReleaseDate -From ([datetime]'2026-09-21')) 'a Monday resolves to the NEXT Monday, never to itself'
Assert-Equal ([datetime]'2026-09-21') (Get-NextReleaseDate -From ([datetime]'2026-09-20')) 'a Sunday resolves to the day after'
Assert-Equal ([datetime]'2026-09-21') (Get-NextReleaseDate -From ([datetime]'2026-09-18 23:59')) 'the time of day is discarded'
Assert-Equal ([datetime]'2026-09-25') (Get-NextReleaseDate -From ([datetime]'2026-09-21') -ReleaseDay ([System.DayOfWeek]::Friday)) 'another cadence is a parameter, not a fork'

# THE LANGUAGE IS THE COLLEAGUE'S, passed in and never read off the machine's locale (#2507). Dutch by
# default: BWJ's board is Dutch, and the reference block the shape comes from is too.
Assert-Equal 'maandag 21 september 2026' (Format-GoLiveDate -Date ([datetime]'2026-09-21')) 'the date reads as a Dutch colleague reads it'
Assert-Equal 'zondag 4 oktober 2026' (Format-GoLiveDate -Date ([datetime]'2026-10-04')) 'the day and month names come from the table, not the host culture'
Assert-Equal 'Monday 21 September 2026' (Format-GoLiveDate -Date ([datetime]'2026-09-21') -Language en) 'and in English for a task written in English'

# THE TALLY LINE IS THE SOURCE FOR THE BUMP, never a second copy of the tier arithmetic -- which this
# plugin could not reach anyway, since the tier parser lives in dkj-policy's own libs.
Assert-Equal 'minor' (Get-PendingBumpFromTally -Changelog "## [Unreleased]`n`n**4 / 9 minor entries** <!-- pending-tally -->") 'the tally names a minor'
Assert-Equal 'patch' (Get-PendingBumpFromTally -Changelog '**9 patch entries** <!-- pending-tally -->') 'the tally names a patch'
Assert-True ($null -eq (Get-PendingBumpFromTally -Changelog '**Nothing pending.** The last release took every entry. <!-- pending-tally -->')) 'nothing pending yields no bump -- there is no next version to name yet'
Assert-True ($null -eq (Get-PendingBumpFromTally -Changelog '# Changelog')) 'a changelog with no tally yields no bump'
Assert-True ($null -eq (Get-PendingBumpFromTally -Changelog '')) 'an empty changelog is answered, not thrown on'
# A TRANSLATED TALLY IS A MISSING NUMBER, NOT A WRONG ONE. The two words are seamed, so this is the
# correct failure, and -Version on the driver is the way past it.
Assert-True ($null -eq (Get-PendingBumpFromTally -Changelog '**4 / 9 kleine wijzigingen** <!-- pending-tally -->')) 'a translated tally yields no bump rather than a guess'
# THE MARKER MUST NOT BE READ OUT OF A SENTENCE THAT QUOTES IT -- the changelog intro is the one
# document that will ever describe this line, and inline backticks are how it names the marker.
Assert-True ($null -eq (Get-PendingBumpFromTally -Changelog 'the line ends with `<!-- pending-tally -->`, a minor detail')) 'a quoted marker is not a tally'

Assert-Equal '1.4.0' (Step-SemVer -Current '1.3.4' -Bump 'minor') 'a minor zeroes the patch component'
Assert-Equal '1.3.5' (Step-SemVer -Current '1.3.4' -Bump 'patch') 'a patch steps the patch component'
Assert-Throws { Step-SemVer -Current 'v1.3.4' -Bump 'patch' } 'a non-X.Y.Z current version throws rather than producing a number'
# NO 'major' CASE: a major recaps the minors behind it and is somebody's decision, so nothing that
# PREDICTS a version may produce one.
Assert-Throws { Step-SemVer -Current '1.3.4' -Bump 'major' } 'major is not a bump this may predict'

$glDash = [string][char]0x2014
$goLiveBlock = Format-GoLiveBlock -Marker (Get-AsanaPasteBlockMarker) -IssueRef 'BWJ-Development/smartwatchbanden#500' `
    -GoLiveDate 'maandag 21 september 2026' -ResultLink 'https://example.invalid/preview' -Version '1.4.0' `
    -LiveUrl @([pscustomobject]@{ Market = 'NL'; Url = 'https://example.invalid/nl/p' },
               [pscustomobject]@{ Market = 'DE'; Url = 'https://example.invalid/de/p' }) `
    -Changed @('Er is een SEO-intro per collectie.') -WhereToLook @('Kijk onder de titel.') -NotIncluded @('Geen A/B-test.')

# ONE SPELLING OF THE MARKER, and this is the assert that holds it: the driver reads
# Get-AsanaPasteBlockMarker and hands it to a lib that hard-codes nothing, so the duplicate check
# (Test-AsanaPasteBlockPosted) cannot miss a block this route already wrote.
Assert-True ($goLiveBlock.Contains((Get-AsanaPasteBlockMarker))) 'the block carries the marker the duplicate check matches on'
Assert-True ($goLiveBlock -notmatch '\[ADD LINK\]') 'it never writes a placeholder -- this route knows the link'
Assert-True ($goLiveBlock.Contains('Het staat gepland voor de release van')) 'the release fact is worded as a plan'
Assert-True ($goLiveBlock.Contains('als versie v1.4.0.')) 'it names the version it is on course for'
Assert-True ($goLiveBlock.Contains("NL $glDash https://example.invalid/nl/p")) 'one live URL per market, labelled by market'
Assert-True ($goLiveBlock.IndexOf("NL $glDash") -lt $goLiveBlock.IndexOf("DE $glDash")) 'and the market order is the table order'

# THE SHAPE BWJ SENDS (#2507): the opening line says where the message comes from, then five fixed
# headings, in the reference block's order.
$goLivePasted = ($goLiveBlock -split '(?m)^---$')[1]

# ONE SET OF WORDS FOR THE BLOCK'S OPENING (#2513, #2700): the header line is Get-GoLiveBlockText's,
# and it is the automation's own line, English on every board.
$glTextNl = Get-GoLiveBlockText -Language nl
Assert-True ($goLivePasted.TrimStart().StartsWith(($glTextNl.Header -f '500'))) 'the block opens with the header line'
Assert-True ($goLivePasted.TrimStart().StartsWith($hdr)) 'the block opens with the automation''s own header (#2700)'
$glPastedLines = @($goLivePasted.Trim() -split "`n")
Assert-Equal 'GitHub issue [BWJ-Development/smartwatchbanden#500](https://github.com/BWJ-Development/smartwatchbanden/issues/500) is now **closed**: this Asana task is now in review.' `
    $glPastedLines[2] 'then the intro, the issue name a link and the verb bold -- the requester''s form (#3069)'
Assert-Equal '' $glPastedLines[3] 'and directly under it nothing: a planned release day''s sections say when and that a no reopens it, so no line repeats them (#3328)'
Assert-True ($goLivePasted -notmatch 'becomes visible|reopened anytime') 'and neither half of the old after-release line is anywhere in the block (#3328)'
Assert-Equal (Format-GoLiveClosedLine -IssueRef 'o/r#1' -AfterRelease) (Format-GoLiveClosedLine -IssueRef 'o/r#1' -AfterRelease).Split("`n")[0] 'the after-release closed line is the intro alone, on one line (#3328)'
Assert-True (-not $goLiveBlock.Contains((Get-AsanaReleaseBlockMarker))) 'without -ReleaseMarker the block carries no second marker'
$glRel = Format-GoLiveBlock -Marker '<!-- m -->' -IssueRef 'o/r#1' -GoLiveDate 'maandag 19 oktober 2026' -ReleaseMarker (Get-AsanaReleaseBlockMarker)
Assert-True ($glRel.StartsWith("<!-- m -->`n$(Get-AsanaReleaseBlockMarker)`n`n")) 'a planned block carries the after-release marker beside its own, outside the rules (#3069)'
Assert-Throws { Format-GoLiveClosedLine -IssueRef '500' } 'a bare number has no repo to link the closed line to'
# WHERE TO LOOK LEADS (Dave, #2700); the rest keep their order.
$glHeadings = @('TE BEKIJKEN OP', 'WAT ER NU ANDERS IS', 'WANNEER HET LIVE KOMT', 'WAT ER BEWUST NIET IN ZIT', 'WAT WE VAN JE VRAGEN')
$glAt = -1
foreach ($h in $glHeadings) {
    $i = $goLivePasted.IndexOf("`n$h`n")
    Assert-True ($i -gt $glAt) "the heading '$h' is its own line, in the reference order"
    $glAt = $i
}
Assert-True ($goLivePasted.IndexOf('Er is een SEO-intro') -gt $goLivePasted.IndexOf('WAT ER NU ANDERS IS')) 'the session''s prose sits under its own heading'
Assert-True ($goLivePasted.IndexOf('Kijk onder de titel.') -gt $goLivePasted.IndexOf('Het resultaat is hier te bekijken')) 'and the where-to-look prose follows the link'
Assert-True ($goLivePasted -notmatch 'Planned to|What we ask|The fix for') 'the Dutch block carries no English words of the old shape'
Assert-True ($goLiveBlock.Contains((Get-GoLiveBlockLead))) 'while the framing sentence, read on GitHub, stays English'
Assert-True ((Get-GoLiveBlockLead) -match 'The closed message carries the block below into the Asana task') 'and says the closed message carries the block into the task (#2818)'
Assert-True ((Get-GoLiveBlockLead) -match 'closes as completed') 'and only on a close as completed -- the one close that posts'
Assert-True ((Get-GoLiveBlockLead) -match 'no paste needed') 'so nobody pastes it a second time (#2703)'
# BUT ONLY ON AN ISSUE THAT LINKS ITS TASK (#2918): the closed message posts nothing on 'none' or
# 'ambiguous', so the lead must not promise it there.
Assert-Equal (Get-GoLiveBlockLead) (Get-GoLiveBlockLead -AsanaLink linked) 'the default lead is the linked one'
Assert-True ((Get-GoLiveBlockLead -AsanaLink none) -notmatch 'no paste needed' -and (Get-GoLiveBlockLead -AsanaLink none) -match 'links no Asana task') 'an unlinked issue''s lead says nothing reaches Asana'
Assert-True ((Get-GoLiveBlockLead -AsanaLink ambiguous) -notmatch 'no paste needed' -and (Get-GoLiveBlockLead -AsanaLink ambiguous) -match 'more than one Asana task') 'and an ambiguous one says the close will not guess'
Assert-True ((Get-GoLiveBlockLead -AsanaLink unchecked) -notmatch 'no paste needed' -and (Get-GoLiveBlockLead -AsanaLink unchecked) -match '^If this issue links') 'an issue that could not be read gets a conditional lead, never the promise'
# THE POST WAITS FOR A PULL REQUEST (#2930): a merged or open closing PR is landing work; none, or only one
# closed without merging, is not.
Assert-Equal 'merged' (Get-GoLivePostReadiness -Nodes @([pscustomobject]@{ number = 1; state = 'CLOSED' }, [pscustomobject]@{ number = 2; state = 'MERGED' })) 'a merged closing PR is landed work'
Assert-Equal 'open' (Get-GoLivePostReadiness -Nodes @([pscustomobject]@{ number = 3; state = 'OPEN' })) 'an open one is on its way'
Assert-Equal 'none' (Get-GoLivePostReadiness -Nodes @([pscustomobject]@{ number = 4; state = 'CLOSED' })) 'a PR closed without merging is not'
Assert-Equal 'none' (Get-GoLivePostReadiness -Nodes @()) 'and no PR at all is the measured #402'
# A PR THAT ONLY REFERENCES THE ISSUE COUNTS TOO (#2957): an Asana-linked issue ships with -NoResolves, so its
# PR never closes it. Same repo only; a cross-reference from an issue carries no PR number and is dropped.
$glRefIssue = '{"closedByPullRequestsReferences":{"nodes":[]},"timelineItems":{"nodes":[' +
    '{"source":{"number":917,"state":"MERGED","repository":{"nameWithOwner":"O/R"}}},' +
    '{"source":{"number":5,"state":"OPEN","repository":{"nameWithOwner":"other/repo"}}},' +
    '{"source":{}},{}]}}' | ConvertFrom-Json
$glRefNodes = @(Get-GoLiveLandingNodes -IssueData $glRefIssue -Repo 'o/r')
Assert-Equal 1 $glRefNodes.Count 'a referencing PR in the same repo is a landing node; one elsewhere and an issue reference are not'
Assert-Equal 'merged' (Get-GoLivePostReadiness -Nodes $glRefNodes) 'and a merged referencing PR is landed work -- the measured smartwatchbanden#914'
$glBothIssue = '{"closedByPullRequestsReferences":{"nodes":[{"number":12,"state":"OPEN"}]},"timelineItems":{"nodes":[]}}' | ConvertFrom-Json
Assert-Equal 'open' (Get-GoLivePostReadiness -Nodes @(Get-GoLiveLandingNodes -IssueData $glBothIssue -Repo 'o/r')) 'the closing references still count on their own'
Assert-Equal 0 @(Get-GoLiveLandingNodes -IssueData $null -Repo 'o/r').Count 'and an issue the query did not return yields no nodes'
$glUnlinked = Format-GoLiveBlock -Marker '<!-- m -->' -IssueRef 'o/r#1' -GoLiveDate 'maandag 21 september 2026' -AsanaLink none
Assert-True ($glUnlinked.Contains((Get-GoLiveBlockLead -AsanaLink none)) -and $glUnlinked -notmatch 'no paste needed') 'Format-GoLiveBlock passes the link state through to its lead'

# A BARE LIST BESIDE A RESULT LINK SAYS HOW TO READ IT BEFORE THE RELEASE (#2477): a bare URL renders
# the preview in any browser that opened the result link first, so both tabs would agree. The caveat is
# in words, and the URL stays bare (#2619) -- a live-id pin read as a preview link to the requester.
Assert-True ($goLiveBlock.Contains('venster: een browser die de link hierboven al heeft geopend')) 'beside a result link, the list carries the cookie caveat'
Assert-True ($goLiveBlock -notmatch 'om mee te vergelijken') 'and does not call itself a comparison'
Assert-True (-not (Get-Command Format-GoLiveBlock).Parameters.ContainsKey('LivePinned')) 'the block has no pinned mode left to label (#2619)'
$goLiveNoLink = Format-GoLiveBlock -Marker '<!-- m -->' -IssueRef 'o/r#1' -GoLiveDate 'maandag 21 september 2026' `
    -LiveUrl @([pscustomobject]@{ Market = 'NL'; Url = 'https://example.invalid/nl/p' })
Assert-True ($goLiveNoLink.Contains("Zodra het live is, zie je het hier:`n")) 'with no result link there is no link of its own to set the cookie, so no caveat'

# THE MARKER SITS OUTSIDE THE PASTED BLOCK -- the same property the backstop's own copy is held to,
# for the same reason: everything between the rules lands in a colleague's ticket.
Assert-True ($goLivePasted -notmatch [regex]::Escape((Get-AsanaPasteBlockMarker))) 'the marker is outside the block that gets pasted'
Assert-True ($goLivePasted.Contains('WANNEER HET LIVE KOMT')) 'and the go-live half is INSIDE it -- it is what the requester reads'

# THE BLOCK ASKS FOR THE REQUESTER'S OWN LOOK (#2352), inside the pasted part, and after the facts.
Assert-True ($goLivePasted.IndexOf('WAT WE VAN JE VRAGEN') -gt $goLivePasted.IndexOf("DE $glDash")) 'the ask comes after the live URLs'
Assert-True ($goLivePasted.Contains('vink deze taak af')) 'an approval closes the TASK, and the requester is the one who closes it'
Assert-True ($goLivePasted.Contains("wat er niet goed is, $([char]0x00E9)n wat er precies anders moet")) 'a rejection asks for BOTH things, not only what is wrong'
Assert-True ($goLivePasted.Contains('volgende ronde')) 'and says it starts a new round'
# THE RELEASE IS NOT A REWARD: nothing in the block makes going live conditional on the answer.
Assert-True ($goLivePasted.Contains('hoe dan ook mee met die release')) 'the ask says the work goes live either way'

# THE SAME SHAPE IN ENGLISH, for a task written in English -- the words follow the task, not the repo.
$goLiveEn = Format-GoLiveBlock -Marker '<!-- m -->' -IssueRef 'o/r#3' -GoLiveDate 'Monday 21 September 2026' `
    -ResultLink 'https://example.invalid/preview' -Version '2.0.1' -Language en -Changed @('A thing changed.')
Assert-True ($goLiveEn.Contains("$hdr`n`nGitHub issue [o/r#3]")) 'English opens the same way -- the automation''s lines are English on every board'
Assert-True ($goLiveEn.Contains("`nWHAT IS DIFFERENT NOW`n") -and $goLiveEn.Contains("`nWHAT WE ASK OF YOU`n")) 'with the same sections'
Assert-True ($goLiveEn.Contains('planned to go live with the release of Monday 21 September 2026, as version v2.0.1.')) 'and the plan wording'
Assert-True ($goLiveEn -notmatch '(?m)will go live') 'never as a promise'
Assert-True ($goLiveEn -match 'what is not right yet, and what exactly should change') 'a rejection asks for both things in English too'
Assert-True ($goLiveEn -notmatch '(?i)\bif (it is|you) (right|approve)[^.]*(release|live)') 'and never ties the release to an approval'

# A FACT THAT CANNOT BE DERIVED IS LEFT OUT, NEVER GUESSED -- and a section with nothing in it is not
# written at all, heading included.
$goLiveBare = Format-GoLiveBlock -Marker '<!-- m -->' -IssueRef 'o/r#1' -GoLiveDate 'maandag 21 september 2026'
Assert-True ($goLiveBare -notmatch 'hier te bekijken') 'with no link, the block omits the link sentence rather than placeholdering it'
Assert-True ($goLiveBare -notmatch 'TE BEKIJKEN OP') 'and with no where-prose either, the whole section'
Assert-True ($goLiveBare -notmatch 'WAT ER NU ANDERS IS|WAT ER BEWUST NIET IN ZIT') 'no prose, no prose sections'
Assert-True ($goLiveBare.Contains('release van maandag 21 september 2026.')) 'with no version, the sentence names the day alone'
Assert-True ($goLiveBare -notmatch 'als versie') 'and no version clause at all'
Assert-True ($goLiveBare -notmatch 'Zodra het live is') 'with no markets, there is no live-URL list'
Assert-True ($goLiveBare -notmatch 'WAT WE VAN JE VRAGEN') 'with no link, there is nothing to look at, so no ask'

# ALREADY LIVE (#2943): xoxowildhearts#190 went live in a separate push before its close, and the block
# would have named the next Monday. -Live says 'live since', and drops what only holds before a release.
$glLive = Format-GoLiveBlock -Marker '<!-- m -->' -IssueRef 'o/r#190' -GoLiveDate 'maandag 12 oktober 2026' -Live `
    -ResultLink 'https://example.invalid/live' -LiveUrl @([pscustomobject]@{ Market = 'NL'; Url = 'https://example.invalid/p' })
Assert-True ($glLive.Contains('Het staat live sinds maandag 12 oktober 2026.')) '-Live names the day it went live'
Assert-True ($glLive -notmatch 'gepland|Zodra het live is|laatste moment') 'and no planned release, no before-the-release caveat, no last-moment sentence'
Assert-True ($glLive.Contains("Je ziet het hier live:`n`nNL $glDash https://example.invalid/p")) 'the live list carries a plain label'
Assert-True ($glLive.Contains("`nSINDS WANNEER HET LIVE STAAT`n") -and $glLive.Contains('Het staat al live')) 'the heading is past tense too (#3241); the ask says it is already live'
Assert-True ($glLive -notmatch 'WANNEER HET LIVE KOMT') 'and the future-tense heading never sits above a live-since sentence (#3241)'
Assert-True ($goLiveBare.Contains("`nWANNEER HET LIVE KOMT`n") -and $goLiveBare -notmatch 'SINDS WANNEER') 'while a planned block keeps the future-tense heading'
$glLiveEn = Format-GoLiveBlock -Marker '<!-- m -->' -IssueRef 'o/r#190' -GoLiveDate 'Monday 12 October 2026' -Live -Version '3.1.0' -Language en
Assert-True ($glLiveEn.Contains('It has been live since Monday 12 October 2026, as version v3.1.0.')) 'in English, with a version'
Assert-True ($glLiveEn.Contains("`nLIVE SINCE`n") -and $glLiveEn -notmatch 'WHEN IT GOES LIVE') 'and in English the heading is past tense as well (#3241)'
Assert-True ((Format-GoLiveBlock -Marker '<!-- m -->' -IssueRef 'o/r#190' -GoLiveDate 'Monday 12 October 2026' -Language en).Contains("`nWHEN IT GOES LIVE`n")) 'while an English planned block keeps WHEN IT GOES LIVE'
$glLiveRel = Format-GoLiveBlock -Marker '<!-- m -->' -IssueRef 'o/r#190' -GoLiveDate 'maandag 12 oktober 2026' -Live -ReleaseMarker (Get-AsanaReleaseBlockMarker)
Assert-True (-not $glLiveRel.Contains((Get-AsanaReleaseBlockMarker))) 'a -Live block never carries the after-release marker, even when one is handed in (#3069)'
Assert-True ($glLiveRel.Contains("is now **closed**: this Asana task is now in review.`nIt can be reopened anytime when something is still not working as expected.`n") -and $glLiveRel -notmatch 'becomes visible') 'and its closed line is the intro with the plain reopen line'

# NO STOREFRONT RESULT (#3236): smartwatchbanden#945 and #244 changed the deploy route, nothing a customer
# sees, and with no form for it a PR and a release URL reached the requester as 'the result'.
$glNsf = Format-GoLiveBlock -Marker '<!-- m -->' -IssueRef 'o/r#945' -GoLiveDate 'maandag 26 oktober 2026' -NoStorefront `
    -WhereToLook @('In de admin onder Thema''s.') -ReleaseMarker (Get-AsanaReleaseBlockMarker)
Assert-True ($glNsf.Contains("TE BEKIJKEN OP`n`nVoor klanten verandert er niets: op de storefront is deze wijziging niet te zien.`n`nIn de admin onder Thema's.")) '-NoStorefront opens where-to-look with the fixed sentence, the [where] prose under it'
Assert-True ($glNsf.Contains("WAT WE VAN JE VRAGEN`n`nOp de storefront is niets te bekijken") -and $glNsf -notmatch 'resultaat is hier te bekijken|wat een klant ziet|laatste moment') 'and asks without a link, never promising a look at what a customer sees'
Assert-True (-not $glNsf.Contains((Get-AsanaReleaseBlockMarker)) -and $glNsf -notmatch 'becomes visible' -and $glNsf.Contains('reopened anytime')) 'nothing becomes visible with the release, so no after-release marker and the plain reopen line'
Assert-True ($glNsf.Contains('Het staat gepland voor de release van maandag 26 oktober 2026.')) 'the release day is still named: the change still goes out with it'
$glNsfEn = Format-GoLiveBlock -Marker '<!-- m -->' -IssueRef 'o/r#945' -GoLiveDate 'Wednesday 21 October 2026' -NoStorefront -Live -Language en
Assert-True ($glNsfEn.Contains("WHERE TO LOOK`n`nNothing changes for customers") -and $glNsfEn.Contains('There is nothing to look at on the storefront')) 'in English too, and without [where] the fixed sentence stands alone'

# THE CLOSING RULE FOLLOWS A BLANK LINE, whichever section ends the block (#2701): a text line directly
# above '---' is a setext H2, which rendered the block's last paragraph as a heading on GitHub.
foreach ($glClosed in @(@{ Name = 'the ask section'; Block = $goLiveBlock }, @{ Name = 'the when section'; Block = $goLiveBare }, @{ Name = 'an English block'; Block = $goLiveEn })) {
    $glClosedLines = @($glClosed.Block -split "`n")
    Assert-Equal '---' $glClosedLines[-1] "a block ending on $($glClosed.Name) ends on the closing rule"
    Assert-Equal ''    $glClosedLines[-2] "and the line above that rule is blank, so $($glClosed.Name) is not rendered as a heading"
}

# THE SESSION'S PROSE ARRIVES THROUGH A FILE, parsed strictly -- a misspelled section line must not
# silently drop the paragraph under it.
$glProse = ConvertFrom-GoLiveProse -Text "[changed]`r`nEen.`r`nnog een regel`r`n`r`nTwee.`r`n[where]`r`n`r`nKijk.`r`n[not-included]`r`nNiets.`r`n"
Assert-Equal 2 @($glProse.Changed).Count 'paragraphs are split on a blank line'
Assert-Equal "Een.`nnog een regel" @($glProse.Changed)[0] 'and a paragraph keeps its own line breaks'
Assert-Equal 'Kijk.' @($glProse.WhereToLook)[0] '[where] fills the where-to-look prose'
Assert-Equal 'Niets.' @($glProse.NotIncluded)[0] '[not-included] fills its own section'
Assert-Equal 0 @((ConvertFrom-GoLiveProse -Text "[changed]`n").NotIncluded).Count 'a section nobody wrote is empty, not absent'
Assert-Throws { ConvertFrom-GoLiveProse -Text "[chnaged]`nEen." } 'an unknown section line is refused'
Assert-Throws { ConvertFrom-GoLiveProse -Text "Een.`n[changed]`nTwee." } 'text above the first section line is refused'
$glBrackets = ConvertFrom-GoLiveProse -Text "[changed]`nZie noot.`n[1]`n[ ]`n[TBD]"
Assert-Equal "Zie noot.`n[1]`n[ ]`n[TBD]" @($glBrackets.Changed)[0] 'a bracketed line that is not section-shaped stays prose'
Assert-Throws { ConvertFrom-GoLiveProse -Text "[changed]`nEen.`n---`nTwee." } 'a bare --- line is refused -- it would be a third rule inside the pasted block'
Assert-Throws { ConvertFrom-GoLiveProse -Text "[changed]`n<!-- asana-paste-block -->" } 'and so is an HTML comment, the marker included'
Assert-Equal 'Niets mis.' @((ConvertFrom-GoLiveProse -Text "[outcome]`nNiets mis.").Outcome)[0] '[outcome] fills the research block''s one section (#3017)'
Assert-Equal 'Niets mis.' @((ConvertFrom-GoLiveProse -Text "[found]`nNiets mis.").Outcome)[0] 'and [found], its name before #3017, still fills the same section'

# THE RESEARCH BLOCK (#3004, in #3017's general form): a ticket that changed nothing on the store, in the
# shape Maikel set on smartwatchbanden#944's task -- the research closed line, then OUTCOME as bullets.
$rbBlock = Format-GoLiveResearchBlock -Marker (Get-AsanaPasteBlockMarker) -ResearchMarker (Get-AsanaResearchBlockMarker) `
    -IssueRef 'BWJ-Development/smartwatchbanden#943' -Outcome @("Een.`n- punt", "Twee`nregels.")
Assert-True ($rbBlock.StartsWith("$(Get-AsanaPasteBlockMarker)`n$(Get-AsanaResearchBlockMarker)`n")) 'the research block carries both markers, outside the rules'
Assert-True ($rbBlock.Contains("GitHub issue [BWJ-Development/smartwatchbanden#943](https://github.com/BWJ-Development/smartwatchbanden/issues/943) is now **closed**: this Asana task is now in review.`nNothing has changed. Read the outcome below.`n`nOUTCOME")) 'its closed line is the shared intro with ''Nothing has changed'' under it, only the state word bold (#3017, #3069)'
Assert-True ($rbBlock -notmatch 'ready for review') 'and nothing of #3017''s lead'
Assert-True ($rbBlock.Contains("`nOUTCOME`n- Een.`n- punt`n- Twee regels.`n`n---")) 'the outcome sits under OUTCOME as one list: a paragraph per bullet, a hand-made list keeping its items, a blank line before the closing rule'
Assert-True ($rbBlock -notmatch 'WANNEER HET LIVE KOMT|WAT WE VAN JE VRAGEN|TE BEKIJKEN OP|reopened anytime|research purposes|GEVONDEN') 'and nothing that goes live, nothing to look at, no reopen invitation, nothing of the #3004 wording'
Assert-True ($rbBlock.Contains('no paste needed')) 'with the same lead as a result block'
Assert-True ((Format-GoLiveResearchBlock -Marker 'm' -ResearchMarker 'r' -IssueRef 'o/r#1' -Outcome @('x') -Language en).Contains("`nOUTCOME`n- x`n")) 'the heading is fixed English in either language (#3017)'
Assert-True ((Format-GoLiveResearchBlock -Marker 'm' -ResearchMarker 'r' -IssueRef 'o/r#1' -Found @('x')).Contains("`n- x`n")) '-Found still binds, as the alias of -Outcome'
Assert-Throws { Format-GoLiveResearchBlock -Marker 'm' -ResearchMarker 'r' -IssueRef 'o/r#1' -Outcome @('', ' ', '-') } 'a research block without an outcome is refused'
Assert-Equal 3 @(ConvertTo-GoLiveOutcomeBullets -Paragraphs @("* a`n-  b", 'c')).Count 'a * marker counts as a bullet too, and a paragraph is one'
Assert-Equal '**vet** blijft' @(ConvertTo-GoLiveOutcomeBullets -Paragraphs @('**vet** blijft'))[0] 'a line opening with bold is not read as a bullet'
Assert-True (Test-AsanaPasteBlockBody -Body $rbBlock) 'it is a block the closed message carries'

# THE MEASUREMENT BLOCK (#3179): a result that is a number the requester measures again (#3177).
$mpProse = ConvertFrom-GoLiveProse -Text "[measure]`nPageSpeed Insights, mobiel.`n- https://x.nl/`n`n[targets]`nLCP onder 2,5 s.`n`n[baseline]`n3,1 s op 13 oktober.`n`n[when]`nNa 28 dagen."
Assert-Equal 'Na 28 dagen.' @($mpProse.MeasureWhen)[0] '[when] fills the measurement block''s last section'
Assert-Equal 'LCP onder 2,5 s.' @($mpProse.Targets)[0] 'and [targets] its targets'
$mbBlock = Format-GoLiveMeasureBlock -Marker (Get-AsanaPasteBlockMarker) -MeasureMarker (Get-AsanaMeasureBlockMarker) `
    -IssueRef 'BWJ-Development/smartwatchbanden#919' -Measure $mpProse.Measure -Targets $mpProse.Targets -Baseline $mpProse.Baseline -When $mpProse.MeasureWhen
Assert-True ($mbBlock.StartsWith("$(Get-AsanaPasteBlockMarker)`n$(Get-AsanaMeasureBlockMarker)`n")) 'the measurement block carries both markers, outside the rules'
Assert-True ($mbBlock.Contains("is now **closed**: this Asana task is now in review.`nNothing changes visibly on the storefront. You can take a new measurement yourself, as described below.`n`nZO MEET JE HET`n`nPageSpeed Insights, mobiel.`n- https://x.nl/`n`nDOELEN`n`nLCP onder 2,5 s.`n`nLAATSTE METING`n`n3,1 s op 13 oktober.`n`nWANNEER JE MEET`n`nNa 28 dagen.`n`n---")) 'the shared intro, the measurement line under it, then the four sections in order, a blank line before the closing rule'
Assert-True ($mbBlock -notmatch 'Nothing has changed|reopened anytime|WANNEER HET LIVE KOMT|TE BEKIJKEN OP') 'and nothing of the research or the result form'
$mbMin = Format-GoLiveMeasureBlock -Marker 'm' -MeasureMarker 'k' -IssueRef 'o/r#1' -Measure @('a') -Targets @('b') -Language en
Assert-True ($mbMin.Contains("`nHOW TO MEASURE`n`na`n`nTARGETS`n`nb`n`n---") -and $mbMin -notmatch 'LAST MEASUREMENT|WHEN TO MEASURE') 'English headings, and an optional section with nothing to say is not written'
Assert-Throws { Format-GoLiveMeasureBlock -Marker 'm' -MeasureMarker 'k' -IssueRef 'o/r#1' -Measure @(' ') -Targets @('b') } 'a measurement block without how to measure is refused'
Assert-Throws { Format-GoLiveMeasureBlock -Marker 'm' -MeasureMarker 'k' -IssueRef 'o/r#1' -Measure @('a') -Targets @() } 'and one without targets'
Assert-True (Test-AsanaPasteBlockBody -Body $mbBlock) 'it is a block the closed message carries'
Assert-True ((Get-PasteBlockSections -Body $rbBlock).StartsWith('OUTCOME')) 'and its carried sections start at the heading: the closed line is the message''s own'

# THE ALREADY-FIXED BLOCK (#3242): a ticket an earlier release had fixed -- smartwatchbanden#1006, fixed by
# #186 in v2.11.1 -- verified, with nothing changed in this round. It must never read as this round's result.
$afProse = ConvertFrom-GoLiveProse -Text "[fixed]`nProductkaarten tonen weer een afbeelding.`n`n[where]`nOpen een collectiepagina."
Assert-Equal 'Productkaarten tonen weer een afbeelding.' @($afProse.Fixed)[0] '[fixed] fills the already-fixed block''s own section'
$afBlock = Format-GoLiveAlreadyFixedBlock -Marker (Get-AsanaPasteBlockMarker) -AlreadyFixedMarker (Get-AsanaAlreadyFixedBlockMarker) `
    -IssueRef 'BWJ-Development/smartwatchbanden#1006' -FixedOn 'woensdag 15 juli 2026' -FixedIn 'v2.11.1' `
    -ResultLink 'https://x.nl/collections/a' -Fixed $afProse.Fixed -WhereToLook $afProse.WhereToLook
Assert-True ($afBlock.StartsWith("$(Get-AsanaPasteBlockMarker)`n$(Get-AsanaAlreadyFixedBlockMarker)`n")) 'the already-fixed block carries both markers, outside the rules'
Assert-True ($afBlock.Contains("is now **closed**: this Asana task is now in review.`nNothing was changed for this ticket: it was already fixed by an earlier release. Check below that it holds for you.`n`nWANNEER HET IS OPGELOST`n`nHet is opgelost met de release van woensdag 15 juli 2026, als versie v2.11.1.`n`nProductkaarten tonen weer een afbeelding.`n`nTE BEKIJKEN OP`n`nKijk hier of het bij jou ook klopt: https://x.nl/collections/a`n`nOpen een collectiepagina.`n`n---")) 'the shared intro, the already-fixed line, then when it was fixed FIRST and where to look, a blank line before the closing rule'
Assert-True ($afBlock -notmatch 'WAT ER NU ANDERS IS|WANNEER HET LIVE KOMT|resultaat is hier|Nothing has changed|reopened anytime|WAT WE VAN JE VRAGEN') 'and nothing that presents the earlier fix as this round''s work'
Assert-True (Test-AsanaPasteBlockBody -Body $afBlock) 'it is a block the closed message carries'
$afMin = Format-GoLiveAlreadyFixedBlock -Marker 'm' -AlreadyFixedMarker 'k' -IssueRef 'o/r#1' -FixedOn 'Wednesday 15 July 2026' -FixedIn '2.11.1' -Language en
Assert-True ($afMin.Contains("`nWHEN IT WAS FIXED`n`nIt was fixed with the release of Wednesday 15 July 2026, as version v2.11.1.`n`n---") -and $afMin -notmatch 'WHERE TO LOOK') 'English, and without a link or [where] no where-to-look section is written'
Assert-Throws { Format-GoLiveAlreadyFixedBlock -Marker 'm' -AlreadyFixedMarker 'k' -IssueRef 'o/r#1' -FixedOn 'x' -FixedIn 'next week' } 'a -FixedIn that is not X.Y.Z is refused'
Assert-Throws { Format-GoLiveAlreadyFixedBlock -Marker 'm' -AlreadyFixedMarker 'k' -IssueRef 'o/r#1' -FixedOn ' ' -FixedIn '1.0.0' } 'and so is an empty -FixedOn'
Assert-Equal '2.11.1' (ConvertTo-GoLiveFixedVersion -Version ' V2.11.1 ') 'the version drops a leading v and whitespace'
Assert-Equal '' (ConvertTo-GoLiveFixedVersion -Version '2.11') 'and a two-part number is no release'
Assert-True ((Get-PasteBlockSections -Body $afBlock).StartsWith('WANNEER HET IS OPGELOST')) 'its carried sections start at the heading: the already-fixed line is the message''s own'

# THE BY-HAND RECORD (#3183): a closed message posted on the task by hand, recorded so the workflow posts nothing.
$hbBlock = Format-GoLiveByHandBlock -Marker (Get-AsanaPasteBlockMarker) -HandMarker (Get-AsanaHandBlockMarker) -Date ([datetime]'2026-10-19') -Story '1219392256834173'
Assert-True ($hbBlock.StartsWith("$(Get-AsanaPasteBlockMarker)`n$(Get-AsanaHandBlockMarker)`n")) 'the by-hand record carries both markers, outside the rules'
Assert-Equal 'Closed message posted by hand on 2026-10-19 (Asana story 1219392256834173).' (Get-PasteBlockSections -Body $hbBlock) 'between the rules is the one-line record, with the day and the story gid'
Assert-True (Test-AsanaPasteBlockBody -Body $hbBlock) 'and it is a block the close guard and the round logic accept as this round''s'
Assert-True ((Format-GoLiveByHandBlock -Marker 'm' -HandMarker 'h' -Date ([datetime]'2026-10-19')).Contains("`nClosed message posted by hand on 2026-10-19.`n`n---")) 'without -Story the record names the day only, a blank line before the closing rule'
Assert-Throws { Format-GoLiveByHandBlock -Marker 'm' -HandMarker 'h' -Date ([datetime]'2026-10-19') -Story '12a' } 'a story gid that is not digits is refused'

# A LINK THE REQUESTER CANNOT OPEN IS REFUSED (#2341): a claude.ai Artifact is private to its owner, and
# the handover page is the reviewer's surface. Both published shapes, and nothing that merely resembles one.
Assert-True (Test-PrivateResultLink -Link 'https://claude.ai/artifact/abc123') 'a claude.ai/artifact link is private'
Assert-True (Test-PrivateResultLink -Link 'https://claude.ai/code/artifact/0f1e-uuid') 'a claude.ai/code/artifact link is private'
Assert-True (Test-PrivateResultLink -Link 'HTTPS://Claude.AI/artifact/abc') 'case does not change the answer'
Assert-True (-not (Test-PrivateResultLink -Link 'https://store.example/products/foo?preview_theme_id=1&_ab=0&_fd=0&_sc=1')) 'a storefront preview URL is openable'
Assert-True (-not (Test-PrivateResultLink -Link 'https://store.example/pages/claude.ai/artifact/x')) 'a path that merely contains the shape is not refused'
Assert-True (-not (Test-PrivateResultLink -Link '')) 'no link is not a private link'

# A REPO ARTIFACT IS NO RESULT (#3236): a pull request, release or commit is what was done, not a page to look at.
Assert-True (Test-RepoArtifactLink -Link 'https://github.com/BWJ-Development/smartwatchbanden/pull/946') 'a pull request URL is a repo artifact'
Assert-True (Test-RepoArtifactLink -Link 'https://github.com/o/r/releases/tag/v2.49.0') 'and so is a release'
Assert-True (Test-RepoArtifactLink -Link 'HTTPS://WWW.GitHub.com/o/r/commit/abc') 'whatever the case, with or without www'
Assert-True (-not (Test-RepoArtifactLink -Link 'https://bwj.github.io/page')) 'a Pages site is another host'
Assert-True (-not (Test-RepoArtifactLink -Link 'https://store.example/pages/github.com/x')) 'a path that merely contains the host is not refused'
Assert-True (-not (Test-RepoArtifactLink -Link '')) 'no link is not a repo artifact'
foreach ($rlWalk in @('https://github.com:443/o/r', 'https://user@github.com/o/r', 'https://github.com?x=1', 'https://github.com#a', ' https://github.com/o/r ', 'https://GITHUB.COM./o', '//github.com/o', 'github.com', 'https://gist.github.com/x', 'https://raw.githubusercontent.com/o/r/main/f')) {
    Assert-True (Test-RepoArtifactLink -Link $rlWalk) "the host is parsed, so '$rlWalk' is refused too (review of #3236)"
}
Assert-True (-not (Test-RepoArtifactLink -Link 'https://github.com.evil.example/x')) 'a host that only starts with github.com is another host'
Assert-Throws { Format-GoLiveBlock -Marker 'm' -IssueRef 'o/r#1' -GoLiveDate 'x' -NoStorefront -ResultLink 'https://x.example/' } 'Format-GoLiveBlock refuses a link beside -NoStorefront itself, not only the driver'

# STORE-ADMIN PREREQUISITES ARE READ FROM THE ISSUE (#2885): only task-list lines after the marker count.
$saMarker = Get-StoreAdminPrerequisiteMarker
Assert-Equal '<!-- store-admin-prerequisites -->' $saMarker 'the prerequisite marker is an HTML comment, which renders as nothing'
$saItems = @(Get-StoreAdminPrerequisites -Text @(
    "Body.`n- [ ] an unrelated checklist above no marker",
    "- [ ] before the marker`n$saMarker`n**Store-admin prerequisites**`n`n- [ ] Metafield definition ``custom.show_menu_image```n- [x] Menu 'footer'`n* [X] App embed on`nprose [ ] not a box",
    $null))
Assert-Equal 3 $saItems.Count 'three boxes after the marker; the box above it and the marker-less text add nothing'
Assert-Equal 'Metafield definition `custom.show_menu_image`' $saItems[0].Item 'the item is the text after the box'
Assert-True (-not $saItems[0].Done) 'an empty box is open'
Assert-True ($saItems[1].Done -and $saItems[2].Done) 'x and X are ticked, under - and * bullets alike'
Assert-Equal 0 @(Get-StoreAdminPrerequisites -Text @('no marker', '- [ ] anywhere')).Count 'an issue without the marker declares no prerequisites'
Assert-Equal 0 @(Get-StoreAdminPrerequisites -Text @()).Count 'and an issue with no text at all declares none'
$saBounded = @(Get-StoreAdminPrerequisites -Text @("$saMarker`n- [x] a`n- [ ]`n`n## Acceptance criteria`n- [ ] unrelated AC"))
Assert-Equal 2 $saBounded.Count 'the checklist ends at the next heading'
Assert-True (-not $saBounded[1].Done) 'and a bare box is an open item, not nothing'
$saVariants = @(Get-StoreAdminPrerequisites -Text @("$saMarker`n1. [ ] numbered`n> - [ ] quoted`n- [ ]nospace"))
Assert-Equal 3 @($saVariants | Where-Object { -not $_.Done }).Count 'numbered, quoted and unspaced boxes all count as open'
$saEmpty = @(Get-StoreAdminPrerequisites -Text @("$saMarker`nWe will add the list later."))
Assert-True ($saEmpty.Count -eq 1 -and -not $saEmpty[0].Done) 'a marker with no box under it holds the post back'
Assert-Equal 1 @(Get-StoreAdminPrerequisites -Text @("$saMarker`n- [x] a`n<!-- other -->`n- [ ] b")).Count 'and at the next HTML comment'

# AND THE DRIVER REFUSES IT BEFORE ANYTHING IS PRINTED OR POSTED -- a static read, because the driver needs gh.
$goLiveDriver = [System.IO.File]::ReadAllText((Join-Path $PluginRoot 'scripts\task\build-golive-block.ps1'))
Assert-True ($goLiveDriver -match 'Test-PrivateResultLink -Link \$LinkArg\) -and -not \$AllowPrivateLink') 'the driver refuses a private link unless -AllowPrivateLink says it was shared'
Assert-True ($goLiveDriver.IndexOf('Test-PrivateResultLink -Link') -lt $goLiveDriver.IndexOf('Format-GoLiveBlock -Marker')) 'and it refuses before the block is built'
# THE POST GOES THROUGH A UTF-8 FILE, NEVER A PIPE (#2507): Windows PowerShell 5.1 encodes a pipe into a
# native command as ASCII, which posted every accent and dash of the colleague's language as '?'.
Assert-True ($goLiveDriver -notmatch '\|\s*&?\s*gh issue comment') 'the driver never pipes the block into gh'
Assert-True ($goLiveDriver -match 'gh issue comment \$issueNumber --repo \$StoreRepo --body-file \$bodyFile') 'it posts from the UTF-8 body file'
# AND THAT FILE IS ACTUALLY ASSIGNED, on a line of its own. The asana-mirror retirement once folded the
# assignment into the comment above it, which left -Post dying on an unset variable under StrictMode while
# every assert here stayed green -- nothing in this suite runs -Post.
Assert-True ($goLiveDriver -match '(?m)^\$bodyFile = Join-Path') 'the body file is assigned on its own line, not inside a comment'
# THE PREREQUISITE CHECK (#2885): read only for -OutFile or -Post, so a print-only run stays offline; the
# post refuses on an open or unreadable checklist unless -Force, and does so before anything is commented.
Assert-True ($goLiveDriver -match 'if \(\$PostArg -or \$OutFileArg\) \{(\s+#[^\n]*)?\s+\$issueJson = \$null\s+try \{ \$issueRun = Invoke-Native') 'the issue is read for prerequisites only where the block leaves the console'
Assert-True ($goLiveDriver -match 'if \(-not \$ForceArg -and \(\$prereqUnread -or \$prereqOpen\.Count -gt 0\)\)') 'an open or unreadable checklist refuses the post unless -Force'
Assert-True ($goLiveDriver.IndexOf('$prereqUnread -or $prereqOpen.Count') -lt $goLiveDriver.IndexOf('gh issue comment $issueNumber')) 'and it refuses before the comment is posted'
$glLandingCall = $goLiveDriver.IndexOf('Get-GoLivePostReadiness -Nodes')
Assert-True ($glLandingCall -gt 0 -and $glLandingCall -lt $goLiveDriver.IndexOf('gh issue comment $issueNumber')) 'the pull-request check (#2930) runs before the comment is posted'
Assert-True ($glLandingCall -gt $goLiveDriver.IndexOf('if (-not $PostArg) {')) 'and only on the post path, so -OutFile at the preview never asks it'
# -Research WARNS ON A MERGED PULL REQUEST (#3181), by the same read, on the post path, before the comment.
$glResWarn = $goLiveDriver.IndexOf('if ($ResearchArg -and (Read-GoLiveLandingState) -eq ''merged'')')
Assert-True ($glResWarn -gt $goLiveDriver.IndexOf('if (-not $PostArg) {') -and $glResWarn -lt $goLiveDriver.IndexOf('gh issue comment $issueNumber')) '-Research reads the landing state on the post path, before the comment'
$glResEnd = $goLiveDriver.IndexOf('if (-not $ForceArg -and $resultForm)', $glResWarn)
Assert-True ($glResEnd -gt $glResWarn -and $goLiveDriver.Substring($glResWarn, $glResEnd - $glResWarn) -notmatch 'exit 1') 'and warns rather than refuses: only the session knows whether that PR changed the store'
Assert-Equal 1 ([regex]::Matches($goLiveDriver, 'closedByPullRequestsReferences').Count) 'the landing query is written once, shared by both readers'
# ANOTHER OPEN ISSUE LINKING THE SAME TASK (#3182): asked by the pickup hook's own rule, only where the block
# leaves the console and the issue links one task, and refused on the post before the comment unless -Force.
Assert-True ($goLiveDriver -match "\. \(Join-Path \`$PSScriptRoot '\.\.\\lib\\asana-pickup-rules\.ps1'\)") 'the driver loads the one-task-one-issue rule rather than a copy'
$glCoSearch = $goLiveDriver.IndexOf('--search "$($asanaRef.Gid) in:body"')
Assert-True ($glCoSearch -gt $goLiveDriver.IndexOf('if ($PostArg -or $OutFileArg) {')) 'the open issues are searched after the issue read, so a print-only run stays offline'
Assert-True ($goLiveDriver -match 'Get-AsanaTaskCoClaimants -Gid \$asanaRef\.Gid -Number \(\[int\]\$issueNumber\)') 'the co-claimants are judged by that rule, this issue excluded'
$glCoRefuse = $goLiveDriver.IndexOf('if (-not $ForceArg -and $coClaimText) {')
Assert-True ($glCoRefuse -gt $goLiveDriver.IndexOf('if (-not $PostArg) {') -and $glCoRefuse -lt $goLiveDriver.IndexOf('gh issue comment $issueNumber')) 'a shared task refuses the post, unless -Force, before the comment'
Assert-True ($goLiveDriver -match '\$coClaimText = if \(\$coClaimants\.Count -gt 0\)') 'the refusal text comes from co-claimants found, so a search that could not answer cannot refuse'
Assert-Equal 1 ([regex]::Matches($goLiveDriver, 'if \(-not \$ForceArg -and \$coClaimText\)').Count) 'and the text is refused in one place only'
Assert-True ($goLiveDriver -notmatch '(?m)^.*\$coClaimUnread.*exit') 'nothing on the unread path exits'

# THE DRIVER, RUN THE WAY THE SKILL RUNS IT -- '-File', in a fresh process -- issue #2339. The config used
# to be dot-sourced inside a '& { }' scriptblock, so Get-StorefrontMarkets died with that scope and -Path
# refused with "this store has not declared its markets" in a store that had. Every case above calls the
# libs in THIS process, which is exactly the shape that hid it.
$glRoot = Join-Path ([System.IO.Path]::GetTempPath()) "bwj-golive-$PID-$([guid]::NewGuid().ToString('n'))"
try {
    New-Item -ItemType Directory -Path (Join-Path $glRoot 'scripts') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $glRoot 'scripts\repo-config.ps1'),
        "function Get-StorefrontMarkets { @(@{ Market = 'NL'; Domain = 'seam.example' }) }`r`n",
        (New-Object System.Text.UTF8Encoding $false))
    $glDriver = Join-Path $PluginRoot 'scripts\task\build-golive-block.ps1'
    $glOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -Version '1.0.0' `
        -Path '/pages/p' -RootOverride $glRoot 2>&1
    $glCode = $LASTEXITCODE
    $glText = (@($glOut | ForEach-Object { "$_" }) -join "`n")
    Assert-Equal 0 $glCode 'the driver run with -File and -Path exits 0 in a store that declares its markets'
    Assert-True ($glText -notmatch 'has not declared its markets') 'and does not claim the store declared none'
    Assert-True ($glText.Contains('https://seam.example/pages/p')) 'the live URL comes from the repo-config the driver read itself'
    Assert-True ($glText -notmatch 'preview_theme_id') 'with no live theme id anywhere, the live URL stays bare -- never a guessed id'

    # -LiveSince THROUGH -File (#2943): the string date binds, the block says so, and the two
    # contradictions -- a future day, or a planned day beside it -- are refused before anything is built.
    $glLiveOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -Version '1.0.0' `
        -LiveSince '2026-10-12' -Language en -RootOverride $glRoot 2>&1
    Assert-Equal 0 $LASTEXITCODE 'the driver run with -LiveSince exits 0'
    Assert-True ((@($glLiveOut | ForEach-Object { "$_" }) -join "`n").Contains('It has been live since Monday 12 October 2026, as version v1.0.0.')) 'and the block says live since that day'
    $glFuture = (Get-Date).AddDays(3).ToString('yyyy-MM-dd')
    $glFutOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -LiveSince $glFuture -RootOverride $glRoot 2>&1
    Assert-True ($LASTEXITCODE -eq 1 -and ((@($glFutOut | ForEach-Object { "$_" }) -join "`n") -match 'after today')) 'a -LiveSince after today is refused'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -LiveSince '2026-10-12' -From '2026-10-01' -RootOverride $glRoot 2>&1 | Out-Null
    Assert-Equal 1 $LASTEXITCODE '-LiveSince beside -From is refused'

    # -Measure THROUGH -File (#3179): the block from the prose file, and its three refusals.
    $glMeaProse = Join-Path $glRoot 'measure.md'
    [System.IO.File]::WriteAllText($glMeaProse, "[measure]`nPSI, mobile.`n`n[targets]`nLCP under 2.5 s.`n", (New-Object System.Text.UTF8Encoding $false))
    $glMeaOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -Measure -ProseFile $glMeaProse -Language en -RootOverride $glRoot 2>&1
    Assert-Equal 0 $LASTEXITCODE 'the driver run with -Measure exits 0'
    Assert-True ((@($glMeaOut | ForEach-Object { "$_" }) -join "`n").Contains("HOW TO MEASURE`n`nPSI, mobile.`n`nTARGETS`n`nLCP under 2.5 s.")) 'and prints the measurement block'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -Measure -ProseFile $glMeaProse -Link 'https://x.nl' -RootOverride $glRoot 2>&1 | Out-Null
    Assert-Equal 1 $LASTEXITCODE '-Measure beside -Link is refused'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -Measure -Research -ProseFile $glMeaProse -RootOverride $glRoot 2>&1 | Out-Null
    Assert-Equal 1 $LASTEXITCODE '-Measure beside -Research is refused'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -ProseFile $glMeaProse -RootOverride $glRoot 2>&1 | Out-Null
    Assert-Equal 1 $LASTEXITCODE 'measurement prose without -Measure is refused'
    # -ByHand THROUGH -File (#3183): a one-line record, and every other form's input refused.
    $glHandOut = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 911 -Repo 'o/r' -ByHand -Story 42 -RootOverride $glRoot 6>&1 2>&1) | ForEach-Object { "$_" }) -join "`n"
    Assert-Equal 0 $LASTEXITCODE 'the driver run with -ByHand exits 0'
    Assert-True ($glHandOut.Contains('(Asana story 42).') -and $glHandOut.Contains('by hand  :') -and $glHandOut -notmatch 'go live  :|No -Link given|No \[changed\]') 'and prints the record, with no go-live half and no result warnings'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 911 -Repo 'o/r' -ByHand -Research -RootOverride $glRoot 2>&1 | Out-Null
    Assert-Equal 1 $LASTEXITCODE '-ByHand beside -Research is refused'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 911 -Repo 'o/r' -ByHand -ProseFile $glMeaProse -RootOverride $glRoot 2>&1 | Out-Null
    Assert-Equal 1 $LASTEXITCODE '-ByHand beside -ProseFile is refused: the message is already on the task'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 911 -Repo 'o/r' -ByHand -Story 'x1' -RootOverride $glRoot 2>&1 | Out-Null
    Assert-Equal 1 $LASTEXITCODE 'a -Story that is not digits is refused'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 911 -Repo 'o/r' -Story 42 -RootOverride $glRoot 2>&1 | Out-Null
    Assert-Equal 1 $LASTEXITCODE '-Story without -ByHand is refused'

    # -AlreadyFixed THROUGH -File (#3242): the string date binds, the block names the earlier release, and
    # every input that would present it as this round's work is refused.
    $glAfProse = Join-Path $glRoot 'fixed.md'
    [System.IO.File]::WriteAllText($glAfProse, "[fixed]`nCards show one image again.`n`n[where]`nOpen a collection page.`n", (New-Object System.Text.UTF8Encoding $false))
    $glAfOut = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 1006 -Repo 'o/r' -AlreadyFixed -FixedIn 'v2.11.1' -FixedOn '2026-07-15' `
        -Link 'https://x.nl/collections/a' -ProseFile $glAfProse -Language en -RootOverride $glRoot 6>&1 2>&1) | ForEach-Object { "$_" }) -join "`n"
    Assert-Equal 0 $LASTEXITCODE 'the driver run with -AlreadyFixed exits 0'
    Assert-True ($glAfOut.Contains("WHEN IT WAS FIXED`n`nIt was fixed with the release of Wednesday 15 July 2026, as version v2.11.1.`n`nCards show one image again.`n`nWHERE TO LOOK`n`nCheck here that it holds for you: https://x.nl/collections/a")) 'and prints the already-fixed block'
    Assert-True ($glAfOut -notmatch 'go live  :|No \[changed\]|No -Link given') 'with no go-live half and no result warnings'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 1006 -Repo 'o/r' -AlreadyFixed -FixedOn '2026-07-15' -RootOverride $glRoot 2>&1 | Out-Null
    Assert-Equal 1 $LASTEXITCODE '-AlreadyFixed without -FixedIn is refused'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 1006 -Repo 'o/r' -AlreadyFixed -FixedIn '2.11.1' -RootOverride $glRoot 2>&1 | Out-Null
    Assert-Equal 1 $LASTEXITCODE '-AlreadyFixed without -FixedOn is refused'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 1006 -Repo 'o/r' -AlreadyFixed -FixedIn '2.11.1' -FixedOn $glFuture -RootOverride $glRoot 2>&1 | Out-Null
    Assert-Equal 1 $LASTEXITCODE 'a -FixedOn after today is refused'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 1006 -Repo 'o/r' -AlreadyFixed -FixedIn '2.11.1' -FixedOn '2026-07-15' -LiveSince '2026-07-15' -RootOverride $glRoot 2>&1 | Out-Null
    Assert-Equal 1 $LASTEXITCODE '-AlreadyFixed beside -LiveSince is refused: nothing goes live in this round'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 1006 -Repo 'o/r' -AlreadyFixed -Research -FixedIn '2.11.1' -FixedOn '2026-07-15' -RootOverride $glRoot 2>&1 | Out-Null
    Assert-Equal 1 $LASTEXITCODE '-AlreadyFixed beside -Research is refused'
    $glAfChanged = Join-Path $glRoot 'fixed-changed.md'
    [System.IO.File]::WriteAllText($glAfChanged, "[changed]`nCards show one image again.`n", (New-Object System.Text.UTF8Encoding $false))
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 1006 -Repo 'o/r' -AlreadyFixed -FixedIn '2.11.1' -FixedOn '2026-07-15' -ProseFile $glAfChanged -RootOverride $glRoot 2>&1 | Out-Null
    Assert-Equal 1 $LASTEXITCODE 'a [changed] section beside -AlreadyFixed is refused'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 1006 -Repo 'o/r' -FixedIn '2.11.1' -RootOverride $glRoot 2>&1 | Out-Null
    Assert-Equal 1 $LASTEXITCODE '-FixedIn without -AlreadyFixed is refused'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 1006 -Repo 'o/r' -ProseFile $glAfProse -RootOverride $glRoot 2>&1 | Out-Null
    Assert-Equal 1 $LASTEXITCODE 'a [fixed] section without -AlreadyFixed is refused'

    # BARE EVEN WHERE THE SEAM NAMES A LIVE ID (#2619). A URL pinned to it reads as a preview link to the
    # colleague the block is for, so the seam the control half of a preview pair reads is not read here.
    [System.IO.File]::WriteAllText((Join-Path $glRoot 'scripts\repo-config.ps1'),
        ("function Get-StorefrontMarkets { @(@{ Market = 'NL'; Domain = 'seam.example' }) }`r`n" +
         "function Get-ShopifyLiveThemeId { '4242' }`r`n"),
        (New-Object System.Text.UTF8Encoding $false))
    # READ BACK THROUGH -OutFile, as UTF-8: the block now carries characters a console code page may not
    # (#2507), so the console capture is the wrong witness for its exact words.
    $glOutFile = Join-Path $glRoot 'block.md'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -Version '1.0.0' `
        -Path '/pages/p' -Link 'https://seam.example/pages/p?preview_theme_id=1&_ab=0&_fd=0&_sc=1' -RootOverride $glRoot `
        -OutFile $glOutFile 2>&1 | Out-Null
    Assert-Equal 0 $LASTEXITCODE 'the driver run with a live-id seam exits 0'
    $glPinText = [System.IO.File]::ReadAllText($glOutFile, [System.Text.Encoding]::UTF8)
    Assert-True ($glPinText.Contains("NL $glDash https://seam.example/pages/p`n")) 'the live URL is bare, although the seam answers a live id'
    Assert-True ($glPinText -notmatch 'preview_theme_id=4242') 'and never carries that id'
    Assert-True ($glPinText.Contains("priv$([char]0x00E9)venster")) 'the private-window caveat stands beside the result link instead'
    $glBytes = [System.IO.File]::ReadAllBytes($glOutFile)
    Assert-True (-not ($glBytes.Length -ge 3 -and $glBytes[0] -eq 0xEF -and $glBytes[1] -eq 0xBB)) '-OutFile writes no BOM, which would arrive in a pasted comment as a stray character'

    # THE PER-MARKET -Path FORM REACHES THE BLOCK'S LIVE-URL LIST (#2627): one page, a different handle per
    # market, and each market's line carries its own handle -- not the default on every domain.
    $glCfgKeep = [System.IO.File]::ReadAllText((Join-Path $glRoot 'scripts\repo-config.ps1'))
    [System.IO.File]::WriteAllText((Join-Path $glRoot 'scripts\repo-config.ps1'),
        "function Get-StorefrontMarkets { @(@{ Market = 'NL'; Domain = 'a.example' }, @{ Market = 'UK'; Domain = 'b.example' }) }`r`n",
        (New-Object System.Text.UTF8Encoding $false))
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -Version '1.0.0' `
        -Path '/collections/straps|NL=/collections/bandjes' -RootOverride $glRoot -OutFile $glOutFile 2>&1 | Out-Null
    Assert-Equal 0 $LASTEXITCODE 'the driver run with a per-market -Path exits 0'
    $glPmText = [System.IO.File]::ReadAllText($glOutFile, [System.Text.Encoding]::UTF8)
    Assert-True ($glPmText.Contains('https://a.example/collections/bandjes')) 'per-market -Path: NL lists its own handle'
    Assert-True ($glPmText.Contains('https://b.example/collections/straps')) 'per-market -Path: UK falls back to the default'
    Assert-True (-not $glPmText.Contains('https://a.example/collections/straps')) 'per-market -Path: the default is not printed on the overridden market'

    # A MARKET MARKED GoLive = $false IS NOT IN THE BLOCK'S LIST (#3327), through the driver as the skill runs it.
    [System.IO.File]::WriteAllText((Join-Path $glRoot 'scripts\repo-config.ps1'),
        "function Get-StorefrontMarkets { @(@{ Market = 'NL'; Domain = 'a.example' }, @{ Market = 'NL-GB'; Domain = 'a.example'; PathPrefix = '/nl-gb'; GoLive = `$false }) }`r`n",
        (New-Object System.Text.UTF8Encoding $false))
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -Version '1.0.0' `
        -Path '/products/p' -RootOverride $glRoot -OutFile $glOutFile 2>&1 | Out-Null
    Assert-Equal 0 $LASTEXITCODE 'the driver run with a GoLive = $false market exits 0'
    $glGbText = [System.IO.File]::ReadAllText($glOutFile, [System.Text.Encoding]::UTF8)
    Assert-True ($glGbText.Contains('https://a.example/products/p')) 'GoLive: the go-live market is listed'
    Assert-True (-not $glGbText.Contains('/nl-gb/')) 'GoLive: the market marked $false is not'
    [System.IO.File]::WriteAllText((Join-Path $glRoot 'scripts\repo-config.ps1'), $glCfgKeep, (New-Object System.Text.UTF8Encoding $false))

    # THE SESSION'S PROSE, IN THE COLLEAGUE'S LANGUAGE, SURVIVES THE ROUND TRIP (#2507): in through a UTF-8
    # -ProseFile, out through -OutFile, accents intact.
    $glProseFile = Join-Path $glRoot 'prose.txt'
    $glAccent = "Twee dingen: $([char]0x00E9)$([char]0x00E9)n veld, g$([char]0x00E9)$([char]0x00E9)n test."
    [System.IO.File]::WriteAllText($glProseFile, "[changed]`r`n$glAccent`r`n", (New-Object System.Text.UTF8Encoding $true))
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -Version '1.0.0' `
        -RootOverride $glRoot -ProseFile $glProseFile -OutFile $glOutFile 2>&1 | Out-Null
    Assert-Equal 0 $LASTEXITCODE 'the driver run with a -ProseFile exits 0'
    Assert-True ([System.IO.File]::ReadAllText($glOutFile, [System.Text.Encoding]::UTF8).Contains("WAT ER NU ANDERS IS`n`n$glAccent")) 'the prose lands under its heading with every accent intact, BOM or no BOM on the way in'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -Version '1.0.0' `
        -RootOverride $glRoot -ProseFile $glProseFile -Language en -OutFile $glOutFile 2>&1 | Out-Null
    $glEnText = [System.IO.File]::ReadAllText($glOutFile, [System.Text.Encoding]::UTF8)
    Assert-True ($glEnText.Contains("`nWHAT IS DIFFERENT NOW`n") -and -not $glEnText.Contains('WAT ER NU ANDERS IS')) 'the driver passes -Language en through to the block'
    Assert-True ($glEnText.Contains('as version v1.0.0.') -and $glEnText -notmatch 'maandag|dinsdag|woensdag|donderdag|vrijdag|zaterdag|zondag') 'and the date follows it too'

    # THE REPO STATES ITS LANGUAGE ONCE (#2830): Get-GoLiveBlockLanguage is read when -Language is not
    # passed, an explicit -Language still wins, and an answer outside nl/en is refused.
    $glCfgLang = [System.IO.File]::ReadAllText((Join-Path $glRoot 'scripts\repo-config.ps1'))
    [System.IO.File]::WriteAllText((Join-Path $glRoot 'scripts\repo-config.ps1'),
        ($glCfgLang + "function Get-GoLiveBlockLanguage { 'en' }`r`n"), (New-Object System.Text.UTF8Encoding $false))
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -Version '1.0.0' `
        -RootOverride $glRoot -ProseFile $glProseFile -OutFile $glOutFile 2>&1 | Out-Null
    Assert-True ([System.IO.File]::ReadAllText($glOutFile, [System.Text.Encoding]::UTF8).Contains("`nWHAT IS DIFFERENT NOW`n")) 'Get-GoLiveBlockLanguage en: the block is English without -Language'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -Version '1.0.0' `
        -RootOverride $glRoot -ProseFile $glProseFile -Language nl -OutFile $glOutFile 2>&1 | Out-Null
    Assert-True ([System.IO.File]::ReadAllText($glOutFile, [System.Text.Encoding]::UTF8).Contains('WAT ER NU ANDERS IS')) 'and an explicit -Language nl still wins over the seam'
    [System.IO.File]::WriteAllText((Join-Path $glRoot 'scripts\repo-config.ps1'),
        ($glCfgLang + "function Get-GoLiveBlockLanguage { 'de' }`r`n"), (New-Object System.Text.UTF8Encoding $false))
    # EAP Continue around the call: the refusal is a throw, so the child writes stderr, and under this
    # suite's 'Stop' a redirected native stderr line would end the suite instead of being judged.
    $glEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -Version '1.0.0' `
            -RootOverride $glRoot -ProseFile $glProseFile -OutFile $glOutFile 2>&1 | Out-Null
        $glBadCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $glEap }
    Assert-True ($glBadCode -ne 0) 'a seam answering a language other than nl or en is refused'
    [System.IO.File]::WriteAllText((Join-Path $glRoot 'scripts\repo-config.ps1'), $glCfgLang, (New-Object System.Text.UTF8Encoding $false))
    [System.IO.File]::WriteAllText($glProseFile, "[wat]`r`nx`r`n", (New-Object System.Text.UTF8Encoding $false))
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -Version '1.0.0' `
        -RootOverride $glRoot -ProseFile $glProseFile 2>&1 | Out-Null
    Assert-Equal 1 $LASTEXITCODE 'a -ProseFile with an unknown section line is refused, not half-used'

    # -Research THROUGH -File (#3004): the findings come in through [found], and each form refuses the
    # other's prose and the go-live parameters, before anything is built.
    $glFoundFile = Join-Path $glRoot 'found.txt'
    [System.IO.File]::WriteAllText($glFoundFile, "[outcome]`r`nHet bandje past op $([char]0x00E9)lk model.`r`n", (New-Object System.Text.UTF8Encoding $false))
    $glResOut = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 943 -Repo 'o/r' -Research `
        -RootOverride $glRoot -ProseFile $glFoundFile 6>&1 2>&1) | ForEach-Object { "$_" }) -join "`n"
    Assert-Equal 0 $LASTEXITCODE 'the driver run with -Research and an [outcome] section exits 0'
    Assert-True ($glResOut.Contains('Nothing has changed. Read the outcome below.') -and $glResOut.Contains("OUTCOME`n- Het bandje")) 'and prints the research block, the outcome as a bullet (#3017)'
    Assert-True ($glResOut.Contains('nothing goes live') -and $glResOut -notmatch 'go live  :|version  :|No -Link given|No \[changed\]') 'with no go-live half and no result warnings'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 943 -Repo 'o/r' -Research -Link 'https://x.example/' `
        -RootOverride $glRoot -ProseFile $glFoundFile 2>&1 | Out-Null
    Assert-Equal 1 $LASTEXITCODE '-Research beside -Link is refused: nothing changed, so there is nothing to look at'
    [System.IO.File]::WriteAllText($glProseFile, "[changed]`r`nx`r`n[found]`r`ny`r`n", (New-Object System.Text.UTF8Encoding $false))
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 943 -Repo 'o/r' -Research -RootOverride $glRoot -ProseFile $glProseFile 2>&1 | Out-Null
    Assert-Equal 1 $LASTEXITCODE '-Research with a result section beside [found] is refused, so no paragraph is dropped'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 943 -Repo 'o/r' -RootOverride $glRoot -ProseFile $glFoundFile 2>&1 | Out-Null
    Assert-Equal 1 $LASTEXITCODE 'a [found] section without -Research is refused'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 943 -Repo 'o/r' -Research -RootOverride $glRoot 2>&1 | Out-Null
    Assert-Equal 1 $LASTEXITCODE '-Research with no findings is refused -- a link to the issue is no substitute'

    # -NoStorefrontResult THROUGH -File (#3236), and the github.com refusal in every form.
    [System.IO.File]::WriteAllText($glProseFile, "[changed]`r`nx`r`n[where]`r`nIn de admin.`r`n", (New-Object System.Text.UTF8Encoding $false))
    $glNsfOut = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 945 -Repo 'o/r' -NoStorefrontResult `
        -LiveSince '2026-10-01' -RootOverride $glRoot -ProseFile $glProseFile 6>&1 2>&1) | ForEach-Object { "$_" }) -join "`n"
    Assert-Equal 0 $LASTEXITCODE 'the driver run with -NoStorefrontResult exits 0'
    Assert-True ($glNsfOut.Contains('Voor klanten verandert er niets') -and $glNsfOut -notmatch 'No -Link given') 'and prints the no-storefront block, without the missing-link warning'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 945 -Repo 'o/r' -NoStorefrontResult -Link 'https://x.example/' -RootOverride $glRoot 2>&1 | Out-Null
    Assert-Equal 1 $LASTEXITCODE '-NoStorefrontResult beside -Link is refused'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 945 -Repo 'o/r' -NoStorefrontResult -Measure -RootOverride $glRoot 2>&1 | Out-Null
    Assert-Equal 1 $LASTEXITCODE '-NoStorefrontResult beside another form is refused'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 945 -Repo 'o/r' -Link 'https://github.com/o/r/pull/1' -AllowPrivateLink -RootOverride $glRoot 2>&1 | Out-Null
    Assert-Equal 1 $LASTEXITCODE 'a github.com -Link is refused, and -AllowPrivateLink does not pass it'

    # AN OPEN STORE-ADMIN PREREQUISITE, END TO END (#2885), through a stand-in gh on PATH that answers
    # 'issue view' with a checklist and fails everything else -- so no network, and a -Post that got past
    # the refusal would fail on the comment rather than post one.
    $glGhDir = Join-Path $glRoot 'fakegh'
    New-Item -ItemType Directory -Path $glGhDir -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $glGhDir 'issue.json'),
        ('{"body":"x","comments":[{"body":"' + (Get-StoreAdminPrerequisiteMarker) + '\n- [ ] Metafield definition custom.flag\n- [x] Menu footer"}]}'),
        (New-Object System.Text.UTF8Encoding $false))
    [System.IO.File]::WriteAllText((Join-Path $glGhDir 'gh.cmd'),
        "@echo off`r`nif `"%1 %2`"==`"issue view`" (type `"%~dp0issue.json`" & exit /b 0)`r`nexit /b 1`r`n",
        (New-Object System.Text.UTF8Encoding $false))
    $glPath = $env:PATH
    try {
        $env:PATH = "$glGhDir;$glPath"
        $glSaWarn = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -Version '1.0.0' `
            -RootOverride $glRoot -OutFile $glOutFile 6>&1 2>&1) | ForEach-Object { "$_" }) -join "`n"
        $glSaWarnCode = $LASTEXITCODE
        $glSaPost = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -Version '1.0.0' `
            -RootOverride $glRoot -Post 6>&1 2>&1) | ForEach-Object { "$_" }) -join "`n"
        $glSaPostCode = $LASTEXITCODE
    } finally { $env:PATH = $glPath }
    Assert-Equal 0 $glSaWarnCode '-OutFile with an open prerequisite still writes the block -- the handover warns'
    Assert-True ($glSaWarn -match '1 store-admin prerequisite\(s\) on o/r#7 still open' -and $glSaWarn.Contains('custom.flag')) 'and names the open item'
    Assert-True (-not $glSaWarn.Contains('Menu footer')) 'but not the ticked one'
    Assert-Equal 1 $glSaPostCode '-Post with an open prerequisite is refused'
    Assert-True ($glSaPost.Contains('Nothing posted') -and $glSaPost.Contains('-Force')) 'and says nothing was posted, and how to post regardless'
    Assert-True ($glSaWarn -match 'will carry nothing into Asana') 'an issue body with no Asana link warns at -OutFile (#2918)'

    # THE ASANA LINK, END TO END (#2918): the same stand-in gh, an issue with no prerequisites. Unlinked,
    # -Post refuses before anything is commented; -Force gets past it to the comment, which the stand-in
    # fails; linked, the lead keeps its promise and the link check stays silent.
    $glIssueJson = Join-Path $glGhDir 'issue.json'
    try {
        $env:PATH = "$glGhDir;$glPath"
        [System.IO.File]::WriteAllText($glIssueJson, '{"body":"Reported by a colleague via Asana (Dev - Bug)","comments":[]}', (New-Object System.Text.UTF8Encoding $false))
        $glNoLink = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -Version '1.0.0' `
            -RootOverride $glRoot -Post 6>&1 2>&1) | ForEach-Object { "$_" }) -join "`n"
        $glNoLinkCode = $LASTEXITCODE
        $glNoLinkForce = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -Version '1.0.0' `
            -RootOverride $glRoot -Post -Force 6>&1 2>&1) | ForEach-Object { "$_" }) -join "`n"
        & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -Version '1.0.0' `
            -RootOverride $glRoot -OutFile $glOutFile 2>&1 | Out-Null
        $glNoLinkFile = [System.IO.File]::ReadAllText($glOutFile, [System.Text.Encoding]::UTF8)
        [System.IO.File]::WriteAllText($glIssueJson, '{"body":"<!-- asana-task: 1219216227959314 -->\nbody","comments":[]}', (New-Object System.Text.UTF8Encoding $false))
        $glLinked = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -Version '1.0.0' `
            -RootOverride $glRoot -OutFile $glOutFile 6>&1 2>&1) | ForEach-Object { "$_" }) -join "`n"
        $glLinkedFile = [System.IO.File]::ReadAllText($glOutFile, [System.Text.Encoding]::UTF8)
        # A LINKED ISSUE STILL NEEDS ITS PR (#2930). First the stand-in answers no 'api graphql', so the
        # landing read fails, and an unreadable answer refuses like the checks before it.
        $glUnread = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -Version '1.0.0' `
            -RootOverride $glRoot -Post 6>&1 2>&1) | ForEach-Object { "$_" }) -join "`n"
        $glUnreadCode = $LASTEXITCODE
        # Then it answers the real response shape, so the JSON path the driver reads is exercised too: no PR,
        # then an open one -- which gets past the check to the comment, where the stand-in fails.
        [System.IO.File]::WriteAllText((Join-Path $glGhDir 'gh.cmd'),
            ("@echo off`r`nif `"%1 %2`"==`"issue view`" (type `"%~dp0issue.json`" & exit /b 0)`r`n" +
             "if `"%1 %2`"==`"api graphql`" (type `"%~dp0graphql.json`" & exit /b 0)`r`nexit /b 1`r`n"),
            (New-Object System.Text.UTF8Encoding $false))
        $glGraphql = Join-Path $glGhDir 'graphql.json'
        [System.IO.File]::WriteAllText($glGraphql, '{"data":{"repository":{"issue":{"closedByPullRequestsReferences":{"nodes":[]}}}}}', (New-Object System.Text.UTF8Encoding $false))
        $glNoPr = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -Version '1.0.0' `
            -RootOverride $glRoot -Post 6>&1 2>&1) | ForEach-Object { "$_" }) -join "`n"
        $glNoPrCode = $LASTEXITCODE
        [System.IO.File]::WriteAllText($glGraphql, '{"data":{"repository":{"issue":{"closedByPullRequestsReferences":{"nodes":[{"number":12,"state":"OPEN"}]}}}}}', (New-Object System.Text.UTF8Encoding $false))
        $glOpenPr = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -Version '1.0.0' `
            -RootOverride $glRoot -Post 6>&1 2>&1) | ForEach-Object { "$_" }) -join "`n"
        # And a merged PR that only REFERENCES the issue -- the -NoResolves ship (#2957).
        [System.IO.File]::WriteAllText($glGraphql, '{"data":{"repository":{"issue":{"closedByPullRequestsReferences":{"nodes":[]},"timelineItems":{"nodes":[{"source":{"number":13,"state":"MERGED","repository":{"nameWithOwner":"o/r"}}}]}}}}}', (New-Object System.Text.UTF8Encoding $false))
        $glRefPr = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -Version '1.0.0' `
            -RootOverride $glRoot -Post 6>&1 2>&1) | ForEach-Object { "$_" }) -join "`n"
        # A RESEARCH BLOCK HAS NO PULL REQUEST TO WAIT FOR (#3004): with no PR at all, -Post gets past the
        # landing check to the duplicate check, which the stand-in cannot answer.
        [System.IO.File]::WriteAllText($glGraphql, '{"data":{"repository":{"issue":{"closedByPullRequestsReferences":{"nodes":[]}}}}}', (New-Object System.Text.UTF8Encoding $false))
        $glResPost = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -Research `
            -RootOverride $glRoot -ProseFile $glFoundFile -Post 6>&1 2>&1) | ForEach-Object { "$_" }) -join "`n"
    } finally { $env:PATH = $glPath }
    Assert-True ($glResPost -notmatch 'No open or merged pull request|which pull requests close' -and $glResPost -match 'already appears') '-Research -Post skips the pull-request check, and the other checks still run'
    Assert-Equal 1 $glUnreadCode '-Post refuses where it cannot read which pull requests close the issue'
    Assert-True ($glUnread.Contains('which pull requests close or reference o/r#7') -and $glUnread.Contains('deliberate early post')) 'and says what it could not check, and the -Force valve'
    Assert-Equal 1 $glNoPrCode '-Post refuses while no pull request closes or references the issue -- the measured #402'
    Assert-True ($glNoPr.Contains('No open or merged pull request closes or references o/r#7') -and $glNoPr.Contains('Closes #7') -and $glNoPr.Contains('-NoResolves')) 'and says to post at the PR step, naming both shapes of PR'
    Assert-True ($glOpenPr.Contains('landing  : a pull request closing or referencing o/r#7 is open') -and $glOpenPr -notmatch 'No open or merged') 'an open closing PR passes the check, read from the real response shape'
    Assert-True ($glRefPr.Contains('landing  : a pull request closing or referencing o/r#7 is merged') -and $glRefPr -notmatch 'No open or merged') 'a merged PR that only references the issue passes too (#2957)'
    Assert-Equal 1 $glNoLinkCode '-Post on an issue that links no Asana task is refused'
    Assert-True ($glNoLink.Contains('Nothing posted') -and $glNoLink.Contains('GitHub-only')) 'and names the -Force valve for a GitHub-only issue'
    Assert-True ($glNoLink.Contains('asana-task: <gid>')) 'and names the marker that fixes it'
    Assert-True ($glNoLinkForce -notmatch 'GitHub-only' -and $glNoLinkForce -match 'already appears|Posting the comment') '-Force gets past the link refusal'
    Assert-True ($glNoLinkFile -notmatch 'no paste needed' -and $glNoLinkFile.Contains('links no Asana task')) 'the unlinked block''s lead promises nothing'
    Assert-True ($glLinkedFile.Contains('no paste needed')) 'a linked issue keeps the closed-message lead'
    Assert-True ($glLinked -match 'task 1219216227959314 \(found by marker\)' -and $glLinked -notmatch 'will carry nothing') 'and the console names the task it found, with no warning'

    # THE SEAM IS NOT READ AT ALL, so one that throws costs the block nothing -- not even a warning.
    [System.IO.File]::WriteAllText((Join-Path $glRoot 'scripts\repo-config.ps1'),
        ("function Get-StorefrontMarkets { @(@{ Market = 'NL'; Domain = 'seam.example' }) }`r`n" +
         "function Get-ShopifyLiveThemeId { throw 'token expired' }`r`n"),
        (New-Object System.Text.UTF8Encoding $false))
    $glErrOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' -Version '1.0.0' `
        -Path '/pages/p' -RootOverride $glRoot 2>&1
    $glErrText = (@($glErrOut | ForEach-Object { "$_" }) -join "`n")
    Assert-Equal 0 $LASTEXITCODE 'a throwing live-id seam still yields a block'
    Assert-True ($glErrText -notmatch 'token expired') 'and the seam is never called'
    Assert-True ($glErrText -notmatch 'preview_theme_id') 'with the URLs bare'

    # A DERIVABLE VERSION STAYS OUT OF THE BLOCK WITHOUT -Version (#2620): a tag plus a readable tally is a
    # projection the entries still to land can raise, so it is printed for the session and never pasted.
    [System.IO.File]::WriteAllText((Join-Path $glRoot 'CHANGELOG.md'),
        "# Changelog`n`n## [Unreleased]`n`n**1 / 1 patch entries** <!-- pending-tally -->`n", (New-Object System.Text.UTF8Encoding $false))
    Invoke-FixtureGitIn $glRoot init -q
    Invoke-FixtureGitIn $glRoot -c core.autocrlf=false add -A
    Invoke-FixtureGitIn $glRoot -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false commit -q -m init
    Invoke-FixtureGitIn $glRoot tag v2.45.0
    $glVerOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $glDriver -Issue 7 -Repo 'o/r' `
        -RootOverride $glRoot -OutFile $glOutFile 2>&1
    $glVerText = (@($glVerOut | ForEach-Object { "$_" }) -join "`n")
    Assert-Equal 0 $LASTEXITCODE 'the driver run with a tag and a tally but no -Version exits 0'
    Assert-True ($glVerText.Contains('projected v2.45.1')) 'the projection is still worked out, and printed for the session'
    $glVerBlock = [System.IO.File]::ReadAllText($glOutFile, [System.Text.Encoding]::UTF8)
    Assert-True ($glVerBlock -notmatch 'als versie|2\.45\.1') 'but the block names no predicted version'
    Assert-True ($glVerBlock -match 'Het staat gepland voor de release van [a-z]+ \d+ [a-z]+ \d{4}\.') 'only the release day'
} finally {
    if (Test-Path -LiteralPath $glRoot) { Remove-Item -LiteralPath $glRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

# --- prepare-release (inbound #2509) ------------------------------------------------------------
# THE RULES ARE PURE AND THE DRIVER IS NOT: the driver reads git, gh and the Shopify CLI, so what is pinned
# here is everything it decides from values already read -- which entries are pending, which sentence is an
# obligation, which fix is flagged, and that no runbook line can carry an authorisation marker.
Write-Host "`n-- prepare-release --" -ForegroundColor Cyan
. (Join-Path $PluginRoot 'scripts\lib\live-push-rules.ps1')
. (Join-Path $PluginRoot 'scripts\lib\ref-print-lib.ps1')
. (Join-Path $PluginRoot 'scripts\lib\prepare-release-rules.ps1')

$prDot = [char]0x00B7
$prChangelog = (@(
    '# Changelog', '', 'Intro prose that mentions ### DEPLOY: not/an-entry.', '',
    '## [Unreleased]', '', '**2 / 3 minor entries** <!-- pending-tally -->', '',
    "### DEPLOY: feat/12-strap-filter $prDot 20260925-100000Z", '',
    'A filter on the strap page. Once this is live, stop Convert experience 1004205630.', '',
    '**Score:** 3', '', '#### What makes this deploy extra special', '',
    'Management sees it. Once this is live, test 0212-26 can be switched off in Convert.', '', '**Score:** 2', '',
    '#### Pull Request', '', 'Turn off the old flag after the release', '', '---', '',
    "### DEPLOY: ``fix/13-cart-bug`` $prDot 20260925-110000Z", '',
    'Fixes the cart. After the release, turn off the app setting for bundles.', '',
    '**Score:** 2 -- a reason', '', '#### What makes this deploy extra special', '', '**Score:** 1', '',
    '#### Pull Request', '', 'y', '', '---', '',
    "### DEPLOY: fix/14-typo $prDot 20260925-120000Z", '', 'A typo in the golive-block output.', '',
    '**Score:** 1', '', '#### What makes this deploy extra special', '', '**Score:** N/A -- nobody sees it', '',
    '## Releases', '', '### DEPLOY: fix/1-old-and-released', '', 'Once this is live, released long ago.'
) -join "`n")

$prEntries = @(Get-PendingChangelogEntries -Changelog $prChangelog)
Assert-Equal 3 $prEntries.Count 'three pending entries -- the intro and the released section are not pending'
Assert-Equal 'feat/12-strap-filter' $prEntries[0].Branch 'the branch is what follows DEPLOY:, up to the timestamp'
Assert-Equal 'fix/13-cart-bug' $prEntries[1].Branch 'an older, backtick-quoted heading reads the same branch'
Assert-Equal '2' $prEntries[0].HigherScore 'the reach score is read from the first #### that is not the Pull Request'
Assert-Equal '2 -- a reason' $prEntries[1].Tier0Score 'the entry''s own score is read above its first ####'
Assert-True (Test-ScoreIsNone -Score $prEntries[2].HigherScore) 'N/A with a reason still reads as no reach'
Assert-Equal 0 @(Get-PendingChangelogEntries -Changelog "# Changelog`n`n## Releases`n`n### DEPLOY: x").Count 'no pending heading, no entries'

# THE SCORE NOTE, AND ONLY AT AUDIENCE TIER 1 -- measured noisy at tier 2 (6 of 23 in this repo, all correct).
$prNotes = @(Get-EntryScoreNotes -Entries $prEntries -AudienceTier 1)
Assert-Equal 1 $prNotes.Count 'one fix/ entry scores reach; the feat/ one and the N/A fix are not flagged'
Assert-Equal 'fix/13-cart-bug' $prNotes[0].Branch '...and it is the one that scored'
Assert-Equal 0 @(Get-EntryScoreNotes -Entries $prEntries -AudienceTier 2).Count 'a tier-2 repo gets no note at all'
Assert-Equal 0 @(Get-EntryScoreNotes -Entries $prEntries).Count 'an unstated audience gets no note either'

# THE OBLIGATIONS: every section but the Pull Request one, one row per sentence, and never a skill NAME.
$prObl = @(Get-GoLiveObligations -Entries $prEntries)
Assert-Equal 3 $prObl.Count 'three obligations -- the Pull Request section''s "after the release" and the golive-block name are not'
Assert-True ($prObl[0].Sentence -eq 'Once this is live, stop Convert experience 1004205630.') 'the sentence is returned whole, markdown stripped'
Assert-True ($prObl[1].Sentence -eq 'Once this is live, test 0212-26 can be switched off in Convert.') 'the reach section is read too (#2911), its title and score line dropped'
Assert-Equal 'feat/12-strap-filter' $prObl[1].Branch '...under the entry whose reach section carries it'
Assert-Equal 'fix/13-cart-bug' $prObl[2].Branch '...each under the entry it came from'
Assert-Equal 1 @(Get-GoLiveObligations -Entries $prEntries -Patterns @('(?i)\bbundles\b')).Count '-Patterns replaces the defaults rather than extending them'

# THE RUNBOOK: every command composed, none carrying a marker, and an empty push list composing none.
$prBook = (Format-ReleaseRunbook -Store 's.myshopify.com' -LiveThemeId '42' -PushFiles @('sections/a.liquid', 'snippets/b.liquid') `
    -Bump 'minor' -TargetVersion '1.3.0' -ReleaseDate 'Monday 28 September 2026' -Obligations $prObl) -join "`n"
Assert-True $prBook.Contains('shopify theme push --store s.myshopify.com --theme 42 --only sections/a.liquid --only snippets/b.liquid --allow-live') 'the push is composed one --only per file'
Assert-True $prBook.Contains('shopify theme pull --store s.myshopify.com --theme 42 --path') 'the verification pull reads the same files back'
Assert-True ($prBook -notmatch '(?m)--allow-live\s+#') 'no command line carries a trailing marker comment'
Assert-True ($prBook -cnotmatch '[A-Z]+-[A-Z-]*AUTHORI[SZ]ED') 'and no marker-shaped token (e.g. <STORE>-LIVE-PUSH-AUTHORIZED) appears anywhere in the runbook'
Assert-True $prBook.Contains('-Bump minor') 'the cut is named with the bump the tally gave'
Assert-True $prBook.Contains('audience note') 'a minor names the audience note it owes'
Assert-True $prBook.Contains('- [ ] feat/12-strap-filter: Once this is live') 'the obligations become a checklist'
$prEmpty = (Format-ReleaseRunbook -Store 's.myshopify.com' -LiveThemeId '42' -PushFiles @()) -join "`n"
Assert-True ($prEmpty -notmatch 'shopify theme (push|pull)') 'an empty push list composes no push and no pull -- a bare push is the whole theme'
$prNoId = (Format-ReleaseRunbook -Store 's.myshopify.com' -PushFiles @('sections/a.liquid')) -join "`n"
Assert-True ($prNoId -notmatch 'shopify theme push') 'with no live theme id, no push is composed at all'
Assert-Equal '' (Format-VerificationPullCommand -Store 's' -ThemeId '1' -Path 'p' -Only @()) 'an empty pull list composes no pull'
# A PATH THAT IS NOT PASTE-SAFE COMPOSES NO COMMAND AT ALL (this branch's security review). A theme file can
# reach the repo through a sync from the theme editor, and #1594 measured that quoting does not close the
# class -- so the runbook refuses to print a push or pull around it, and names the path instead.
foreach ($evil in @('assets/x.css; calc', 'assets/$(calc).css', "assets/a`ncalc.css", 'assets/a|b.css')) {
    $evilBook = (Format-ReleaseRunbook -Store 's.myshopify.com' -LiveThemeId '42' -PushFiles @('sections/ok.liquid', $evil)) -join "`n"
    Assert-True ($evilBook -notmatch 'shopify theme (push|pull)') "no push or pull is composed around '$($evil -replace "`n", '\n')'"
}
$evilBook = (Format-ReleaseRunbook -Store 's.myshopify.com' -LiveThemeId '42' -PushFiles @("assets/a$([char]27)[31m.css")) -join "`n"
Assert-True ($evilBook.Contains('cannot be pasted safely')) 'the refusal says why'
Assert-True (-not $evilBook.Contains([char]27)) 'and the path it names has its control characters stripped'
# THE APP DEPLOY (#3174): printed beside the push where the range changed the app, and never otherwise.
$appBook = (Format-ReleaseRunbook -Store 's.myshopify.com' -LiveThemeId '42' -PushFiles @('sections/a.liquid') -AppRoot 'extensions' -AppFiles @('extensions/d/run.js')) -join "`n"
Assert-True $appBook.Contains('shopify app deploy --path extensions') 'an app change prints the app deploy'
Assert-True ($appBook.IndexOf('2b. The app deploy') -gt $appBook.IndexOf('2. The push')) 'beside the push, as step 2b'
Assert-True ($prBook -notmatch 'app deploy') 'a range with no app change prints no app deploy'
$appOnly = (Format-ReleaseRunbook -Store 's.myshopify.com' -LiveThemeId '42' -PushFiles @() -AppRoot 'extensions' -AppFiles @('extensions/d/run.js')) -join "`n"
Assert-True ($appOnly.Contains('shopify app deploy') -and $appOnly -notmatch 'code and docs only') 'an app-only release is not called code and docs only'
$appBad = (Format-ReleaseRunbook -Store 's.myshopify.com' -LiveThemeId '42' -PushFiles @() -AppRoot 'ext;calc' -AppFiles @('ext;calc/x.js')) -join "`n"
Assert-True ($appBad -notmatch 'shopify app deploy' -and $appBad.Contains('not composed')) 'an unprintable app root composes no command and says so'
# THE GIT-CONNECTED MODE (#3012): the promotion PR replaces the push, by the function live-preflight prints
# it with, and the runbook still composes no marker. An unsafe or self-referential branch composes nothing.
$prConn = (Format-ReleaseRunbook -Store 's.myshopify.com' -LiveThemeId '42' -PushFiles @('sections/a.liquid') `
    -TargetVersion '1.3.0' -DeployBranch 'live' -Trunk 'main') -join "`n"
Assert-True $prConn.Contains('gh pr create --base live --head main --title "promote: main to live for v1.3.0"') 'connected: the promotion PR is printed, titled with the target version'
Assert-True ($prConn -notmatch 'shopify theme push') 'connected: no push is composed -- the promotion is the act that goes live'
Assert-True $prConn.Contains('shopify theme pull --store s.myshopify.com --theme 42 --path') 'connected: the verification pull still reads the files back off live'
Assert-True $prConn.Contains('rule-suite') 'connected: the preflight step names the write-back read'
Assert-True ($prConn -cnotmatch '[A-Z]+-[A-Z-]*AUTHORI[SZ]ED') 'connected: no marker-shaped token appears'
foreach ($badBranch in @('main', '-live', "live`n")) {
    $prBadConn = (Format-ReleaseRunbook -PushFiles @() -DeployBranch $badBranch -Trunk 'main') -join "`n"
    Assert-True ($prBadConn -notmatch 'gh pr create') "connected: no promotion is composed for deploy branch '$($badBranch -replace "`n", '\n')'"
}
$prCtl = @([pscustomobject]@{ Branch = 'feat/1-x'; Sentence = "Once live, stop it.$([char]27)[2J" })
Assert-True (-not ((Format-ReleaseRunbook -Obligations $prCtl) -join "`n").Contains([char]27)) 'entry prose reaches the runbook with its control characters stripped'

# THE DRIVER, STATICALLY: it runs no theme write and reads no marker, and it refuses in this source repo.
$prDriver = [System.IO.File]::ReadAllText((Join-Path $PluginRoot 'scripts\task\prepare-release.ps1'))
Assert-True ($prDriver -notmatch "(?m)^[^#]*\b(theme',\s*'(push|publish|delete|duplicate)|shopify theme (push|publish|delete))") 'the driver invokes no theme push, publish, delete or duplicate'
Assert-True ($prDriver -notmatch 'Get-ShopifyLivePushMarker|LIVE-PUSH-AUTHORIZED') 'the driver never reads the authorisation marker'
# Inbound #3144: Windows PowerShell 5.1 strips an embedded double quote from a native argument, so a quoted jq
# filter reaches gh as several arguments and the check-run read failed on every 5.1 run.
Assert-True ($prDriver -notmatch "(?m)^[^#]*(--jq|-q)'?,?\s+'[^']*""") 'no jq filter the driver hands gh carries a double quote'
$prRun = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PluginRoot 'scripts\task\prepare-release.ps1') 2>&1
Assert-Equal 1 $LASTEXITCODE 'run in the plugin''s own source repo, the driver refuses'
Assert-True ((@($prRun | ForEach-Object { "$_" }) -join "`n").Contains('publishes plugins')) '...and says why'

# THE SEAMS ARE READ (inbound #2565). The #2509 edit replaced the dot-source of repo-config.ps1 with a comment
# line, and no assert noticed: every seam fell back to its default and each step then reported a plausible
# skip. So a fixture root answers two seams with values no default could produce, and the run must print both.
# Get-RepoName is answered too so the run makes no 'gh repo view'; the root is no git repo, so no check-run read.
$prRoot = Join-Path ([System.IO.Path]::GetTempPath()) "bwj-prepare-$PID-$([guid]::NewGuid().ToString('n'))"
try {
    New-Item -ItemType Directory -Path (Join-Path $prRoot 'scripts') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $prRoot 'scripts\repo-config.ps1'), (@(
        "function Get-ShopifyThemeEstateStore { 'seam-fixture-2565.myshopify.com' }",
        "function Get-ChangelogPath { 'seam-fixture/CHANGELOG-2565.md' }",
        "function Get-RepoName { 'fixture/prepare-release-2565' }",
        "function Get-ShopifyLiveDeployBranch { 'deploy-3012' }"
    ) -join "`n"))
    $prSeamRun = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PluginRoot 'scripts\task\prepare-release.ps1') -RootOverride $prRoot -SkipDrift 2>&1) | ForEach-Object { "$_" }) -join "`n"
    Assert-True $prSeamRun.Contains('seam-fixture-2565.myshopify.com') 'the store domain is read from the repo''s own seam, not defaulted'
    Assert-True $prSeamRun.Contains("no changelog at 'seam-fixture/CHANGELOG-2565.md'") 'the changelog path is read from the repo''s own seam, not defaulted'
    Assert-True $prSeamRun.Contains("deploys from 'deploy-3012'") 'the deploy branch is read from the repo''s own seam (#3012)'
    Assert-True ($prSeamRun -match 'back-flow') '...and step 5 reads the back-flow instead of running the drift check'

    # A FAULTY CONFIG DEGRADES, and names the exception's type rather than the consumer's own text (#2509).
    [System.IO.File]::WriteAllText((Join-Path $prRoot 'scripts\repo-config.ps1'), "throw 'consumer-secret-text-2565'")
    $prBadRun = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PluginRoot 'scripts\task\prepare-release.ps1') -RootOverride $prRoot -SkipDrift 2>&1) | ForEach-Object { "$_" }) -join "`n"
    Assert-True $prBadRun.Contains('[8/8]') 'a repo-config that throws does not take the run down'
    Assert-True $prBadRun.Contains('scripts/repo-config.ps1 threw') '...it is named as the file that threw'
    Assert-True (-not $prBadRun.Contains('consumer-secret-text-2565')) '...and its own message never reaches the output'
} finally {
    if (Test-Path -LiteralPath $prRoot) { Remove-Item -LiteralPath $prRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

# THE LIVE MESSAGE IS THE RUNBOOK'S STEP AFTER THE CUT (#3070): printed there so the hand step is not forgotten.
$nlBook = (Format-ReleaseRunbook -Store 's.myshopify.com' -LiveThemeId '42' -PushFiles @('sections/a.liquid') -TargetVersion '1.3.0') -join "`n"
$nlCut = $nlBook.IndexOf('6. The cut'); $nlStep = $nlBook.IndexOf('7. Tell the requesters'); $nlBackup = $nlBook.IndexOf('8. Backup')
Assert-True ($nlCut -ge 0 -and $nlStep -gt $nlCut -and $nlBackup -gt $nlStep) 'the runbook names notify-live between the cut and the backup'
Assert-True $nlBook.Contains('`notify-live` skill, -Version v1.3.0') '...with the version the cut makes'

# --- notify-live (inbound #3070) ----------------------------------------------------------------
# WHO IS TOLD IS THE WHOLE RISK: a requester told 'live' too early, or told twice, or a -LiveSince one told
# again. So the verdict is pinned case by case over hand-built comments, and the message by its exact words.
Write-Host "`n-- notify-live --" -ForegroundColor Cyan
. (Join-Path $PluginRoot 'scripts\lib\live-message-rules.ps1')
Assert-Equal 'en' (Get-LiveMessageLanguage -Sections "LIVE SINCE`n`nIt has been live since Monday.") 'the live message reads the past-tense heading''s language too'

Assert-Equal '12,7,3067' ((Get-ReleaseRangePullNumbers -Subjects @('merge: fix/12-x (#12)', 'Merge pull request #7 from o/b', 'fold: y (#3067)', 'fold: again (#12)', 'no number')) -join ',') 'every #<n> in the subjects, distinct, in first-seen order'
Assert-Equal 0 @(Get-ReleaseRangePullNumbers -Subjects @()).Count 'no subjects, no numbers'
# #3498: a -NoResolves PR closes nothing, so its branch and body are read too (smartwatchbanden #1015 -> #1011).
$nlCand = Get-PullIssueCandidates -PullNumber 1015 -ClosingNumbers @() -HeadRefName 'liquid/1011-product-jsonld' -Body "Ships #1011.`n<!-- resolves: none -->`nFollows PR #1009, see #1015 and other/repo#7 and ``#55``."
Assert-Equal '' (@($nlCand.Closing) -join ',') 'no closing reference on a -NoResolves PR'
Assert-Equal '1011' (@($nlCand.Named) -join ',') 'the branch issue and the body mention, once -- not the PR''s own number, a ''PR #'' form, another repo''s issue or a code span'
$nlCand = Get-PullIssueCandidates -PullNumber 20 -ClosingNumbers @(12) -HeadRefName 'feat/12-x' -Body 'Closes #12, also touches #13.'
Assert-Equal '12' (@($nlCand.Closing) -join ',') 'a closing reference stays a closing reference'
Assert-Equal '13' (@($nlCand.Named) -join ',') '...and is not repeated among the named numbers'
Assert-Equal 0 @((Get-PullIssueCandidates -PullNumber 5 -HeadRefName 'main' -Body $null).Named).Count 'a branch with no number and no body name nothing'
$nlDriverCand = [System.IO.File]::ReadAllText((Join-Path $PluginRoot 'scripts\task\notify-live.ps1'))
Assert-True ($nlDriverCand.Contains('Get-PullIssueCandidates') -and $nlDriverCand.Contains('.pull_request == null')) 'the driver reads the candidates through the rule, and asks GitHub whether a named number is an issue'
Assert-True ($nlDriverCand.Contains('gh api -i') -and $nlDriverCand.Contains('$status -eq 404')) '...with -i, so a 404 (a #<n> from another tracker) is "not an issue" rather than a read failure on every rerun'
Assert-True $nlDriverCand.Contains('[named by a PR, not closed by one]') 'a row that rests on a mention alone says so, before anybody passes -Post'
Assert-Equal 'v2.9.0' (Get-PreviousReleaseTag -Tags @('v2.9.0', 'v2.44.0', 'v2.45.0', 'v1.0.0-rc1') -Version 'v2.44.0') 'the tag below is compared as a version, not lexically'
Assert-Equal 'v2.44.0' (Get-PreviousReleaseTag -Tags @('v2.9.0', 'v2.44.0', 'v2.45.0') -Version 'v2.45.0') 'the highest tag below wins'
Assert-Equal '' (Get-PreviousReleaseTag -Tags @('v1.0.0') -Version 'v1.0.0') 'the first release has no range start'

# A REBASE-MERGE'S EARLIER COMMITS (#3190): the merge's own diff is only its last commit, so gh's file list joins it.
$nlRebase = Get-PullChangedPaths -DiffPaths @('extensions/a.js') -PullFiles @('sections/b.liquid', 'extensions/a.js') -ChangedFiles 2 -ParentCount 1
Assert-Equal 'extensions/a.js,sections/b.liquid' ($nlRebase.Paths -join ',') 'a path only an earlier commit of a rebase-merged PR touched is seen, and none twice'
Assert-True $nlRebase.Complete '...and gh''s whole list makes the answer complete'
Assert-True (-not (Get-PullChangedPaths -DiffPaths @('a') -PullFiles @('a', 'b') -ChangedFiles 140 -ParentCount 1).Complete) 'a capped gh list on a one-parent merge is not complete -- the driver reads that PR as unread'
Assert-True (Get-PullChangedPaths -DiffPaths @('a') -PullFiles @('a') -ChangedFiles 140 -ParentCount 2).Complete 'while a two-parent merge commit''s diff is the whole PR, capped list or not'
Assert-Equal 0 @((Get-PullChangedPaths -DiffPaths @() -PullFiles @() -ChangedFiles 0).Paths).Count 'an empty PR changes nothing'
$nlDriverText = [System.IO.File]::ReadAllText((Join-Path $PluginRoot 'scripts\task\notify-live.ps1'))
Assert-True ($nlDriverText -match 'closingIssuesReferences,files,changedFiles' -and $nlDriverText.Contains('Get-PullChangedPaths')) 'the driver asks gh for the PR''s files in the same call, and joins them through the rule'

$nlDash = [string][char]0x2014
function New-NlBlockComment {
    param([string[]]$Kinds = @(), [string]$CreatedAt = '2026-10-10T10:00:00Z', [string]$Heading = 'WAT WE VAN JE VRAGEN')
    $kindLines = @($Kinds | ForEach-Object { "<!-- asana-paste-block-kind: $_ -->" })
    $body = (@('<!-- asana-paste-block -->') + $kindLines + @('', 'framing', '', '---', "$nlDash GitHub automation", '',
        'GitHub issue [o/r#5](https://github.com/o/r/issues/5) is now **closed**: this Asana task is now in review.', '',
        $Heading, 'Klopt het: laat het weten.', '---')) -join "`n"
    return [pscustomobject]@{ Body = $body; CreatedAt = $CreatedAt }
}
function New-NlIssue {
    param($Comments = @(), [string]$State = 'CLOSED', [string]$Reason = 'COMPLETED', $Reopened = $null,
          [string]$Body = "x`n<!-- asana-task: 1201 -->")
    return [pscustomobject]@{ Number = 5; State = $State; StateReason = $Reason; Body = $Body; Comments = @($Comments); LastReopenedAt = $Reopened }
}

$nlOwed = Get-LiveMessageVerdict -Issue (New-NlIssue -Comments @(New-NlBlockComment -Kinds @('after-release')))
Assert-True $nlOwed.Owed 'a block waiting on the release is owed the live message'
Assert-Equal '1201' $nlOwed.Gid '...on the task the issue marks'
Assert-Equal 'nl' $nlOwed.Language '...in the block''s own language'
Assert-Equal 'en' (Get-LiveMessageVerdict -Issue (New-NlIssue -Comments @(New-NlBlockComment -Kinds @('after-release') -Heading 'WHAT WE ASK OF YOU'))).Language 'an English block gets an English ask'
Assert-True (-not (Get-LiveMessageVerdict -Issue (New-NlIssue -Comments @(New-NlBlockComment))).Owed) 'a -LiveSince block (no after-release marker) was told at the close -- skipped'
$nlResearch = Get-LiveMessageVerdict -Issue (New-NlIssue -Comments @(New-NlBlockComment -Kinds @('research')))
Assert-True ((-not $nlResearch.Owed) -and $nlResearch.Reason -match 'research') 'a research block is skipped, and says so'
$nlHand = Get-LiveMessageVerdict -Issue (New-NlIssue -Comments @(New-NlBlockComment -Kinds @('by-hand')))
Assert-True ((-not $nlHand.Owed) -and $nlHand.Reason -match 'by-hand') 'a by-hand record is skipped, and says so (#3183)'
Assert-True (-not (Get-LiveMessageVerdict -Issue (New-NlIssue -State 'OPEN' -Comments @(New-NlBlockComment -Kinds @('after-release')))).Owed) 'an issue reopened since is back in development -- skipped'
Assert-True (-not (Get-LiveMessageVerdict -Issue (New-NlIssue -Reason 'NOT_PLANNED' -Comments @(New-NlBlockComment -Kinds @('after-release')))).Owed) 'a close as not planned is skipped'
Assert-True (-not (Get-LiveMessageVerdict -Issue (New-NlIssue -Body 'no task' -Comments @(New-NlBlockComment -Kinds @('after-release')))).Owed) 'an issue linking no task is skipped'
Assert-True (-not (Get-LiveMessageVerdict -Issue (New-NlIssue)).Owed) 'an issue with no block is skipped'
$nlTold = [pscustomobject]@{ Body = (Format-LiveMessageIssueComment -Version 'v1.3.0' -Gid '1201'); CreatedAt = '2026-10-12T10:00:00Z' }
Assert-True (-not (Get-LiveMessageVerdict -Issue (New-NlIssue -Comments @((New-NlBlockComment -Kinds @('after-release')), $nlTold))).Owed) 'an issue already told is not told twice'
$nlRound2 = @((New-NlBlockComment -Kinds @('after-release') -CreatedAt '2026-10-01T10:00:00Z'), $nlTold, (New-NlBlockComment -Kinds @('after-release') -CreatedAt '2026-10-14T10:00:00Z'))
Assert-True (Get-LiveMessageVerdict -Issue (New-NlIssue -Comments $nlRound2 -Reopened '2026-10-13T10:00:00Z')).Owed 'a marker from before the last reopen belongs to the earlier round -- this round is told'
Assert-True (-not (Get-LiveMessageVerdict -Issue (New-NlIssue -Comments @(New-NlBlockComment -Kinds @('after-release')) -Reopened '2026-10-13T10:00:00Z')).Owed) 'a block from before the last reopen is not this round''s -- skipped'

$nlLines = (Get-LiveMessageLines -IssueRef 'o/r#5' -Version 'v1.3.0' -Language 'nl') -join "`n"
Assert-True $nlLines.Contains('GitHub issue o/r#5 is now **live**, as version v1.3.0.') 'the live line, only the state word bold'
Assert-True $nlLines.Contains('the review already took place on the preview') 'a notice: it says the review already happened (#3492)'
Assert-True (-not $nlLines.Contains('review can start')) 'and never that the review starts at live (#3492)'
Assert-True (-not ($nlLines.Contains('WAT WE VAN JE VRAGEN') -or $nlLines.Contains('vink deze taak af'))) 'the block''s ask is not asked a second time (#3492)'
$nlHtml = New-LiveMessageHtml -IssueRef 'o/r#5' -Version '1.3.0' -Language 'en'
Assert-True $nlHtml.Contains('<a href="https://github.com/o/r/issues/5">o/r#5</a> is now <strong>live</strong>, as version v1.3.0') 'html: the issue as a link, the state word in <strong>, a bare version gets its v'
Assert-True ($nlHtml.StartsWith('<body>') -and $nlHtml.EndsWith('</body>') -and $nlHtml.Contains('the review already took place on the preview') -and -not $nlHtml.Contains('WHAT WE ASK OF YOU')) 'html: one body, the notice and no second ask (#3492)'
Assert-True ($nlHtml -notmatch '<(?!/?(body|a|strong)\b)') 'html: only <body>, <a> and <strong>'
Assert-Throws { New-LiveMessageHtml -IssueRef 'o/r#5"><x' -Version 'v1' } 'html: a ref that is not owner/repo#<n> is refused'
Assert-Throws { Format-LiveMessageIssueComment -Version 'v1.0.0' -Gid '12/../x' } 'the issue comment refuses a non-numeric GID'

# THE DRIVER, STATICALLY AND IN THIS REPO: no store write, the post gated by -Post, and a refusal here.
$nlDriver = [System.IO.File]::ReadAllText((Join-Path $PluginRoot 'scripts\task\notify-live.ps1'))
Assert-True ($nlDriver -notmatch '(?m)^[^#]*shopify theme') 'the driver touches no theme'
Assert-True ($nlDriver -match 'if \(\$PostArg -and \$owed\.Count -gt 0\)') 'the Asana write sits behind -Post'
$nlRun = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PluginRoot 'scripts\task\notify-live.ps1') 2>&1) | ForEach-Object { "$_" }) -join "`n"
Assert-Equal 1 $LASTEXITCODE 'run in the plugin''s own source repo, the driver refuses'
Assert-True $nlRun.Contains('publishes plugins') '...and says why'

# THE LIVE-PUSH RECORD (#3176): read with the mirrored live-record-lib, and a held path holds the issue
# before its verdict is asked. The fixture repo's subjects name no PR, so the run asks gh nothing.
Assert-True ($nlDriver -match "live-record-lib\.ps1") 'the driver reads the record with the mirrored live-record-lib'
Assert-True ($nlDriver.IndexOf('$heldCount[$num] -gt 0') -ge 0 -and $nlDriver.IndexOf('$heldCount[$num] -gt 0') -lt $nlDriver.IndexOf('Get-LiveMessageVerdict -Issue')) 'a held issue is held before its verdict is asked'
$nlRoot = Join-Path ([System.IO.Path]::GetTempPath()) "bwj-notify-$PID-$([guid]::NewGuid().ToString('n'))"
try {
    New-Item -ItemType Directory -Path $nlRoot -Force | Out-Null
    Invoke-FixtureGitIn $nlRoot init -q
    Invoke-FixtureGitIn $nlRoot -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false commit -q --allow-empty -m one
    Invoke-FixtureGitIn $nlRoot tag v1.0.0
    Invoke-FixtureGitIn $nlRoot -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false commit -q --allow-empty -m two
    Invoke-FixtureGitIn $nlRoot tag v1.1.0
    $nlRecord = Join-Path $nlRoot 'record.txt'
    $nlDriverPath = Join-Path $PluginRoot 'scripts\task\notify-live.ps1'

    [System.IO.File]::WriteAllText($nlRecord, "live extensions/a.js`nhold sections/b.liquid`n")
    $nlGood = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File $nlDriverPath -RootOverride $nlRoot -Repo 'fixture/nl-3176' -LivePushRecord $nlRecord 2>&1) | ForEach-Object { "$_" }) -join "`n"
    Assert-Equal 0 $LASTEXITCODE 'a readable record with nothing in the range runs to the end'
    Assert-True $nlGood.Contains('live-push record -- 1 live, 1 held') '...and says what it read'

    [System.IO.File]::WriteAllText($nlRecord, "hodl sections/b.liquid`n")
    $nlBad = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File $nlDriverPath -RootOverride $nlRoot -Repo 'fixture/nl-3176' -LivePushRecord $nlRecord 2>&1) | ForEach-Object { "$_" }) -join "`n"
    Assert-Equal 1 $LASTEXITCODE 'a record with a line it cannot read refuses rather than running without it'
    Assert-True $nlBad.Contains('The live-push record could not be read') '...and says so'

    $nlNone = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File $nlDriverPath -RootOverride $nlRoot -Repo 'fixture/nl-3176' 2>&1) | ForEach-Object { "$_" }) -join "`n"
    Assert-True $nlNone.Contains('no -LivePushRecord') 'without a record the run says what it cannot see'
} finally {
    if (Test-Path -LiteralPath $nlRoot) { Remove-Item -LiteralPath $nlRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

# --- the preview step's carrier (#2655) ---------------------------------------------------------
# PREVIEW-portable.md names the step's exact words, and the adopt skill proposes the seam that makes
# new-branch write them. Two copies of one sentence: this holds them to each other, so a reworded step
# cannot leave the store repos scaffolding the old one.
Write-Host "`nthe preview step and the seam that writes it (#2655)"
$previewPage = Get-Content -Raw -LiteralPath (Join-Path $PluginRoot 'PREVIEW-portable.md')
$adoptPage   = Get-Content -Raw -LiteralPath (Join-Path $PluginRoot 'skills\adopt-bwj-development\SKILL.md')
$pageStep = if ($previewPage -match '(?m)^- \[ \] (Is the change visible[^\r\n]*)') { $Matches[1].Trim() } else { '' }
$seamStep = if ($adoptPage -match "function Get-BranchClosingSteps \{ @\('([^']+)'\) \}") { $Matches[1] } else { '' }
Assert-True ($pageStep -ne '') 'the preview page still states the step in its own fenced line'
Assert-Equal $pageStep $seamStep 'the adopt skill proposes Get-BranchClosingSteps with exactly the words the preview page prescribes'

# --- the closed message (templates/asana-closed-message.ps1, #2818) --------------------------------
# LAST IN THE SUITE ON PURPOSE: dot-sourcing the template redefines the lib helpers it carries copies of,
# so the lib's own answers are taken first and held against the copies after.
Write-Host "`n-- the closed message template (#2818) --" -ForegroundColor Cyan
$cmSamples = @(
    "Body`n<!-- asana-task: 1234 -->",
    "| **Asana** | https://app.asana.com/0/111/2222 |`nsee also https://app.asana.com/0/111/3333",
    'one link https://app.asana.com/1/9/project/8/task/4444 only',
    'two https://app.asana.com/0/1/5555 and https://app.asana.com/0/1/6666',
    'none at all')
$cmLibRefs   = @($cmSamples | ForEach-Object { $r = Resolve-AsanaTaskRef -IssueBody $_; "$($r.Gid)|$($r.Source)" })
$cmLibMarker = Get-AsanaPasteBlockMarker
$cmTemplate  = Join-Path $PluginRoot 'templates\asana-closed-message.ps1'
. $cmTemplate

Assert-Equal ($cmLibRefs -join ';') (@($cmSamples | ForEach-Object { $r = Resolve-AsanaTaskRef -IssueBody $_; "$($r.Gid)|$($r.Source)" }) -join ';') `
    'the template''s task matchers answer exactly as asana-task-lib.ps1''s on every matcher shape'
Assert-Equal $cmLibMarker (Get-AsanaPasteBlockMarker) 'and its block marker is the lib''s, so it finds the block build-golive-block wrote'
Assert-Equal (Get-GoLiveBlockText).Header (Get-ClosedMessageHeader) 'it opens with the same header the block does'

# WHEN IT POSTS: a close as completed (or with no reason) on an issue linking exactly one task.
Assert-True (Get-ClosedMessageDecision -StateReason 'completed' -IssueBody $cmSamples[0]).Post 'a close as completed with a linked task posts'
Assert-Equal '1234' (Get-ClosedMessageDecision -StateReason 'completed' -IssueBody $cmSamples[0]).Gid 'to the task the marker names'
Assert-True (Get-ClosedMessageDecision -StateReason '' -IssueBody $cmSamples[0]).Post 'a close with no reason is a close as completed'
Assert-True (-not (Get-ClosedMessageDecision -StateReason 'not_planned' -IssueBody $cmSamples[0]).Post) 'a close as not planned posts nothing (#2765)'
Assert-True (-not (Get-ClosedMessageDecision -StateReason 'not_planned' -IssueBody $cmSamples[0] -Labels @('bug', 'prio-2')).Post) 'nor with labels that do not park it'
Assert-True (-not (Get-ClosedMessageDecision -StateReason 'duplicate' -IssueBody $cmSamples[0]).Post) 'and neither does a close as a duplicate'
Assert-True (-not (Get-ClosedMessageDecision -StateReason 'duplicate' -IssueBody $cmSamples[0] -Labels @('awaiting-info-client')).Post) 'not even one still carrying awaiting-info-client'
Assert-Equal 'closed' (Get-ClosedMessageDecision -StateReason 'completed' -IssueBody $cmSamples[0]).Kind 'a close as completed is the closed message'

# THE ON-HOLD MESSAGE (#2902): not planned with awaiting-info-client kept on is the parked-while-waiting pair.
$cmHold = Get-ClosedMessageDecision -StateReason 'not_planned' -IssueBody $cmSamples[0] -Labels @('bug', 'awaiting-info-client')
Assert-True $cmHold.Post 'a close as not planned with awaiting-info-client kept on posts'
Assert-True (Get-ClosedMessageDecision -StateReason 'not_planned' -IssueBody $cmSamples[0] -Labels @('awaiting-more-info')).Post 'and so does the former name awaiting-more-info, which a tracker keeps until it is renamed (#2917)'
Assert-Equal 'on-hold' $cmHold.Kind 'and it is the on-hold message, not the closed one'
Assert-Equal '1234' $cmHold.Gid 'to the task the marker names'
Assert-True (-not (Get-ClosedMessageDecision -StateReason 'not_planned' -IssueBody $cmSamples[4] -Labels @('awaiting-info-client')).Post) 'with no linked task it posts nothing'
Assert-Equal 'closed' (Get-ClosedMessageDecision -StateReason 'completed' -IssueBody $cmSamples[0] -Labels @('awaiting-info-client')).Kind 'a close as completed stays the closed message, whatever the labels'
Assert-Equal 'reopened' (Get-ClosedMessageDecision -Event 'reopened' -IssueBody $cmSamples[0] -Labels @('awaiting-info-client')).Kind 'and a reopen stays the reopened message'
Assert-True (Get-ClosedMessageDecision -StateReason 'not_planned' -IssueBody $cmSamples[0] -Labels @('Awaiting-More-Info')).Post 'the label is matched whatever its case'
Assert-Equal 'bug, with comma|awaiting-info-client' ((ConvertFrom-IssueLabelList -Text "[`n  `"bug, with comma`",`n  `"awaiting-info-client`"`n]") -join '|') 'the workflow''s toJSON labels parse into names, a comma inside a name kept'
Assert-Equal 'awaiting-info-client' ((ConvertFrom-IssueLabelList -Text '["awaiting-info-client"]') -join '|') 'and a single label is a list of one'
Assert-Equal 0 @(ConvertFrom-IssueLabelList -Text '').Count 'an empty ISSUE_LABELS -- a workflow copied before #2902 -- is no labels'
Assert-Equal 0 @(ConvertFrom-IssueLabelList -Text '[]').Count 'and so is an issue without labels'
Assert-Equal 0 @(ConvertFrom-IssueLabelList -Text 'bug,awaiting-info-client').Count 'and a value that is not JSON is no labels, so the close stays silent'
$cmHoldHtml = New-OnHoldMessageHtml -IssueRef 'BWJ-Development/smartwatchbanden#882'
$cmHoldXml = New-Object System.Xml.XmlDocument
$cmHoldXml.PreserveWhitespace = $true
$cmHoldXml.LoadXml($cmHoldHtml)
Assert-True ($cmHoldXml.DocumentElement.InnerText -ceq (New-OnHoldMessage -IssueRef 'BWJ-Development/smartwatchbanden#882')) 'the on-hold message is well-formed XML and reads as the plain on-hold message'
Assert-True ($cmHoldHtml.Contains("<a href=`"https://github.com/BWJ-Development/smartwatchbanden/issues/882`">BWJ-Development/smartwatchbanden#882</a> is now <strong>closed</strong>: this Asana task has been cancelled, because there is not enough information to start development.`nOnce the questions above are answered, the issue will be reopened and the work picks up again.</body>")) 'the cancelled intro, then the requester''s fixed ask (#2909, #3069): the issue as a link, only the state word in bold'
Assert-True ($cmHoldHtml.StartsWith("<body>$(Get-ClosedMessageHeader)")) 'under the same header as the closed message'
Assert-True ($cmHoldHtml -notmatch 'in review|reopened anytime') 'and never ''in review'' or the reopen line, which a waiting requester reads as finished (#3069)'
Assert-True (-not (Get-ClosedMessageDecision -StateReason 'completed' -IssueBody $cmSamples[3]).Post) 'several different tasks is ambiguous and posts nothing'
Assert-True ((Get-ClosedMessageDecision -StateReason 'completed' -IssueBody $cmSamples[3]).Why -match 'refusing to guess') 'and says so'
Assert-True (-not (Get-ClosedMessageDecision -StateReason 'completed' -IssueBody $cmSamples[4]).Post) 'no linked task posts nothing'

# THE REOPENED MESSAGE (#2854): a reopen posts whatever the earlier close reason, to the same task.
Assert-True (Get-ClosedMessageDecision -Event 'reopened' -StateReason 'reopened' -IssueBody $cmSamples[0]).Post 'a reopen with a linked task posts'
Assert-True (Get-ClosedMessageDecision -Event 'reopened' -StateReason 'not_planned' -IssueBody $cmSamples[0]).Post 'and the close reason does not hold it back -- the issue is in development now'
Assert-True (-not (Get-ClosedMessageDecision -Event 'reopened' -IssueBody $cmSamples[4]).Post) 'a reopen with no linked task posts nothing'
Assert-True (-not (Get-ClosedMessageDecision -Event 'reopened' -IssueBody $cmSamples[3]).Post) 'and neither does one linking several tasks'
$cmReopen = New-ReopenedMessageHtml -IssueRef 'BWJ-Development/smartwatchbanden#393'
# PreserveWhitespace: a bare [xml] cast drops the whitespace-only text node between </a> and <strong>.
$cmReopenXml = New-Object System.Xml.XmlDocument
$cmReopenXml.PreserveWhitespace = $true
$cmReopenXml.LoadXml($cmReopen)
Assert-True ($cmReopenXml.DocumentElement.InnerText -ceq (New-ReopenedMessage -IssueRef 'BWJ-Development/smartwatchbanden#393')) 'the reopened message is well-formed XML and reads as the plain reopened message'
Assert-True ($cmReopen.Contains('<a href="https://github.com/BWJ-Development/smartwatchbanden/issues/393">BWJ-Development/smartwatchbanden#393</a> is <strong>reopened:</strong> this Asana task is now back in development.')) 'in the requester''s fixed form (#2656): the issue as a link, only the state word in bold (#2909)'
Assert-True ($cmReopen.StartsWith("<body>$(Get-ClosedMessageHeader)")) 'under the same header as the closed message'

# WHAT IT POSTS: the header, the closed line, and the block's sections under it.
$cmSections = Select-SessionPasteBlockSections -Bodies @('first', $goLiveBlock)
Assert-True ($cmSections.StartsWith('TE BEKIJKEN OP')) 'the carried sections start at the first heading -- the header and closed line are the message''s own'
Assert-True ($cmSections -notmatch 'GitHub automation|is now \*\*closed') 'so neither arrives twice'
Assert-Equal '' (Select-SessionPasteBlockSections -Bodies @('first', 'no block here')) 'an issue with no block carries no sections'
$cmQuestion = "Wat we van je vragen: 1. Een tijdstip.`n`n$cmLibMarker"
Assert-Equal $cmSections (Select-SessionPasteBlockSections -Bodies @($goLiveBlock, $cmQuestion)) 'an awaiting-info-client question carries the marker but no rules, so the block before it is still the one carried'
$cmHtml = New-ClosedMessageHtml -IssueRef 'BWJ-Development/smartwatchbanden#500' -BlockSections $cmSections
$cmXml  = [xml]$cmHtml
Assert-True ($cmXml.body.InnerText.StartsWith((New-ClosedMessage -IssueRef 'BWJ-Development/smartwatchbanden#500'))) 'the message is well-formed XML and opens with the plain closed message'
Assert-True ($cmHtml.Contains('<a href="https://github.com/BWJ-Development/smartwatchbanden/issues/500">BWJ-Development/smartwatchbanden#500</a> is now <strong>closed</strong>')) 'the issue name is a link and closed is bold -- the requester''s form'
Assert-True ($cmHtml.Contains('<strong>TE BEKIJKEN OP</strong>')) 'the headings arrive bold'
Assert-True ($cmHtml.Contains("`n`n<strong>WAT ER NU ANDERS IS</strong>`n`n")) 'and the line breaks arrive as written'
Assert-Equal '<a href="https://x.invalid/?a=1&amp;b=2">t</a> en <strong>vet</strong> &amp; meer' (ConvertTo-AsanaStoryHtml -Markdown '[t](https://x.invalid/?a=1&b=2) en **vet** & meer') 'Markdown links and bold convert, and everything else is escaped'
$cmBare = New-ClosedMessageHtml -IssueRef 'o/r#1'
Assert-True ($cmBare -cnotmatch '<strong>[A-Z ]+</strong>') 'with no block no section goes out'
Assert-True ($cmBare.EndsWith("It can be reopened anytime when something is still not working as expected.`n`nThe result message for this round follows.</body>")) 'and never the closed line alone: it says the result message follows (#3004)'
[void][xml]$cmBare

# THE RESEARCH FORM (#3004): a research block's sections under the research closed line.
$cmResSections = Get-PasteBlockSections -Body $rbBlock
$cmRes = New-ClosedMessageHtml -IssueRef 'BWJ-Development/smartwatchbanden#943' -BlockSections $cmResSections -Research
$cmResXml = New-Object System.Xml.XmlDocument
$cmResXml.PreserveWhitespace = $true
$cmResXml.LoadXml($cmRes)
Assert-True ($cmResXml.DocumentElement.InnerText.StartsWith((New-ClosedMessage -IssueRef 'BWJ-Development/smartwatchbanden#943' -Research))) 'the research message is well-formed XML and opens with the plain research closed message'
Assert-True ($cmRes.EndsWith("</a> is now <strong>closed</strong>: this Asana task is now in review.`nNothing has changed. Read the outcome below.`n`n<strong>OUTCOME</strong>`n<ul><li>Een.</li><li>punt</li><li>Twee regels.</li></ul>`nIs anything still unclear? Leave a comment on this task. No more questions? Mark the task as complete.</body>")) 'in Maikel''s general form (#3017): only the state word bold, OUTCOME, the bullets as one list, and the closing ask -- naming no section where none was found'
Assert-True ($cmRes -notmatch 'reopened anytime|follows|research purposes|ready for review|becomes visible') 'with no reopen invitation, no pending sentence, nothing of the #3004 or #3017 wording'
$cmResDone = New-ClosedMessageHtml -IssueRef 'o/r#1' -BlockSections $cmResSections -Research -DoneSection '4. Done & dusted'
Assert-True ($cmResDone.EndsWith("No more questions? Move the task to '4. Done &amp; dusted' and mark it as complete.</body>")) 'a found done section is named in the ask, escaped like any text'
[void][xml]$cmResDone
Assert-Equal "<ul><li><a href=`"https://x.nl/a`">https://x.nl/a</a></li></ul>`nnext" (ConvertTo-AsanaStoryHtml -Markdown "- https://x.nl/a`nnext" -Lists) 'a list item converts its links like a line does, and the list closes before the next line'
Assert-Equal "- a" (ConvertTo-AsanaStoryHtml -Markdown '- a') 'without -Lists a result block''s hyphen lines are posted as they always were'

# THE MEASUREMENT FORM (#3179): its sections under the measurement line, and the measurement ask.
$cmMeaSections = Get-PasteBlockSections -Body $mbBlock
Assert-True ($cmMeaSections.StartsWith('ZO MEET JE HET')) 'the measurement line is the message''s own, so it is dropped with the intro'
$cmMea = New-ClosedMessageHtml -IssueRef 'BWJ-Development/smartwatchbanden#919' -BlockSections $cmMeaSections -Measure -DoneSection '4. Done'
[void][xml]$cmMea
Assert-True ($cmMea.Contains("is now <strong>closed</strong>: this Asana task is now in review.`nNothing changes visibly on the storefront. You can take a new measurement yourself, as described below.`n`n<strong>ZO MEET JE HET</strong>")) 'the measurement message opens with the shared intro and the measurement line'
Assert-True ($cmMea.Contains('<ul><li><a href="https://x.nl/">https://x.nl/</a></li></ul>')) 'a hand-made list in a section becomes a list'
Assert-True ($cmMea.EndsWith("`nIs the target met? Move the task to '4. Done' and mark it as complete. Not met? Leave a comment with your measurement, and it becomes a new finding.</body>")) 'and it closes with the measurement ask, naming the done section'
Assert-True ($cmMea -notmatch 'Nothing has changed|reopened anytime|still unclear') 'with nothing of the research or the result form'
Assert-True ((New-ClosedMessageHtml -IssueRef 'o/r#1' -BlockSections 'DOELEN' -Measure -Research -AfterRelease) -match 'Nothing changes visibly' -and (New-ClosedMessageHtml -IssueRef 'o/r#1' -BlockSections 'DOELEN' -Measure -Research) -notmatch 'still unclear') 'the measurement form wins over research and -AfterRelease'
Assert-Equal 'Is the target met? Mark the task as complete. Not met? Leave a comment with your measurement, and it becomes a new finding.' (Get-ClosedMessageMeasureAsk) 'without a done section the ask names none'
Assert-True ((New-ClosedMessageHtml -IssueRef 'o/r#1' -Measure) -match 'result message for this round follows') 'without a block -Measure says nothing it cannot know'
Assert-Equal "with the session's measurement block" (Get-ClosedMessageBlockPhrase -Sections 'x' -Measure $true -Research $true) 'the log names the measurement block'

# THE ALREADY-FIXED FORM (#3242): its sections under the already-fixed line, and its own ask.
$cmAf = New-ClosedMessageHtml -IssueRef 'BWJ-Development/smartwatchbanden#1006' -BlockSections (Get-PasteBlockSections -Body $afBlock) -AlreadyFixed -DoneSection '4. Done'
[void][xml]$cmAf
Assert-True ($cmAf.Contains("is now <strong>closed</strong>: this Asana task is now in review.`nNothing was changed for this ticket: it was already fixed by an earlier release. Check below that it holds for you.`n`n<strong>WANNEER HET IS OPGELOST</strong>")) 'the already-fixed message opens with the shared intro and the already-fixed line'
Assert-True ($cmAf.EndsWith("`nDoes it hold for you? Move the task to '4. Done' and mark it as complete. Still not right? Leave a comment on this task with what you see, and it is picked up again.</body>")) 'and it closes with the already-fixed ask, naming the done section'
Assert-True ($cmAf -notmatch 'Nothing has changed|reopened anytime|still unclear|becomes visible') 'with nothing of the research or the result form'
Assert-Equal 'Does it hold for you? Mark the task as complete. Still not right? Leave a comment on this task with what you see, and it is picked up again.' (Get-ClosedMessageAlreadyFixedAsk) 'without a done section the ask names none'
Assert-True ((New-ClosedMessageHtml -IssueRef 'o/r#1' -BlockSections 'X' -AlreadyFixed -Research -AfterRelease) -match 'already fixed by an earlier release' -and (New-ClosedMessageHtml -IssueRef 'o/r#1' -BlockSections 'X' -AlreadyFixed -Research -AfterRelease) -notmatch 'Nothing has changed|becomes visible') 'already-fixed wins over research and -AfterRelease'
Assert-True ((New-ClosedMessageHtml -IssueRef 'o/r#1' -BlockSections 'X' -AlreadyFixed -Measure) -match 'Nothing changes visibly') 'and only the measurement form wins over it'
Assert-True ((New-ClosedMessageHtml -IssueRef 'o/r#1' -AlreadyFixed) -match 'result message for this round follows') 'without a block -AlreadyFixed says nothing it cannot know'
Assert-True ((New-ClosedMessage -IssueRef 'o/r#1' -AlreadyFixed).EndsWith("in review.`nNothing was changed for this ticket: it was already fixed by an earlier release. Check below that it holds for you.")) 'the plain message carries the same two lines'
Assert-Equal "with the session's already-fixed block" (Get-ClosedMessageBlockPhrase -Sections 'x' -AlreadyFixed $true -Research $true) 'the log names the already-fixed block'
Assert-Equal (Format-GoLiveClosedLine -IssueRef 'o/r#1' -AlreadyFixed).Split("`n")[1] (Get-ClosedMessageSecondLine -AlreadyFixed) 'the block''s closed line and the message''s second line are the same words'
Assert-Equal '' (Get-ClosedMessageSecondLine -AfterRelease) 'and the message''s after-release second line is empty, the same words as the block''s (#3328)'

# ONE INTRO, AND THE LINE UNDER IT TELLS THE FORMS APART (#3069).
$cmRel = New-ClosedMessageHtml -IssueRef 'o/r#1' -BlockSections 'TE BEKIJKEN OP' -AfterRelease
[void][xml]$cmRel
Assert-True ($cmRel.Contains("is now <strong>closed</strong>: this Asana task is now in review.`n`n<strong>TE BEKIJKEN OP</strong>")) 'a result visible only after the release has the intro alone above its sections, and stays the same message (#3328)'
Assert-True ((New-ClosedMessageHtml -IssueRef 'o/r#1' -AfterRelease) -notmatch 'becomes visible') 'without a block -AfterRelease says nothing about a release it cannot see'
Assert-True ((New-ClosedMessageHtml -IssueRef 'o/r#1' -BlockSections 'OUTCOME' -Research -AfterRelease) -match 'Nothing has changed' -and (New-ClosedMessageHtml -IssueRef 'o/r#1' -BlockSections 'OUTCOME' -Research -AfterRelease) -notmatch 'becomes visible') 'research wins over -AfterRelease: a research block has no release'
Assert-True ((New-ClosedMessage -IssueRef 'o/r#1' -AfterRelease).EndsWith("is now closed: this Asana task is now in review.")) 'the plain message ends on the intro too, with no empty line after it (#3328)'
$cmIntro = 'GitHub issue o/r#1 is now **closed**: this Asana task is now in review.'
Assert-Equal 'TE BEKIJKEN OP' (Get-PasteBlockSections -Body "m`n---`n$hdr`n`n$cmIntro`nIt can be reopened anytime.`n`nTE BEKIJKEN OP`n---") 'the closed line''s second line is the message''s own, so it is dropped with the intro'
Assert-Equal 'TE BEKIJKEN OP' (Get-PasteBlockSections -Body "m`n---`n$hdr`n`nGitHub issue o/r#1 is now **closed**. It can be reopened anytime.`n`nTE BEKIJKEN OP`n---") 'a block written before #3069, its closed line one line, is read as before'
Assert-Equal "TE BEKIJKEN OP`nx" (Get-PasteBlockSections -Body "m`n---`n$hdr`n`n$cmIntro`nTE BEKIJKEN OP`nx`n---") 'a heading directly under the closed line is a section, never dropped'

# THE DONE SECTION IS THE BOARD'S OWN (#3017): the Completed code from the repo's stage map, read as text,
# matched against the sections of the task's board. Never a fixed '4. Done'.
$cmCfg = "function Get-AsanaStageMap {`n    <# Completed = 9 in a comment #>`n    return @{`n        # Completed = 8`n        Filed     = '1'`n        Completed = '4'    # done`n    }`n}`nfunction Get-Other { @{ Completed = 5 } }"
Assert-Equal '4' (Get-RepoStageCode -ConfigText $cmCfg) 'the Completed code is read from the map''s body, past a commented-out line'
Assert-Equal '3A' (Get-RepoStageCode -ConfigText "function Get-AsanaStageMap { @{`nCompleted = `"3A`"`n} }") 'a lettered code, double-quoted'
Assert-Equal '7' (Get-RepoStageCode -ConfigText "function Get-AsanaStageMap { return @{ Filed = 3; Completed = 7 } }") 'a one-line map'
Assert-Equal '4' (Get-RepoStageCode -ConfigText "function Get-AsanaStageMap {`n    <#`n    Completed = 9`n    #>`n    @{`n        Completed = '4'`n    }`n}") 'a line inside a multi-line <# #> block is a comment'
Assert-Equal '7' (Get-RepoStageCode -ConfigText "function Get-AsanaStageMap { @{`n'Completed' = '7'`n} }") 'a quoted key is read too'
Assert-Equal '' (Get-RepoStageCode -ConfigText "function Get-AsanaStageMap { @{ CompletedLater = 7 } }") 'a longer key is not the stage'
Assert-Equal '' (Get-RepoStageCode -ConfigText "function Get-Other { @{`nCompleted = 4`n} }") 'a Completed key outside the stage map is not the map'
Assert-Equal '' (Get-RepoStageCode -ConfigText '') 'no file, no code -- and so no section is named'
Assert-Equal '4. Done' (Select-DoneSectionName -Names @('1. Todo', '2. In Progress', '3. Waiting for review', '4. Done') -Code '4') 'the section whose code is the Completed code'
Assert-Equal '3A. Done' (Select-DoneSectionName -Names @('3. Other', '3A. Done', '3B. Wait') -Code '3a') 'a lettered code matches exactly, without regard to case'
Assert-Equal '' (Select-DoneSectionName -Names @('4. Done', '4. Klaar') -Code '4') 'two different names for one code is a guess, so none is named'
Assert-Equal '' (Select-DoneSectionName -Names @('Done', '40. Later') -Code '4') 'an unnumbered section and a longer number do not match'
$cmGetOk = { param($Uri) if ($Uri -like '*/tasks/*') { @{ data = @{ memberships = @(@{ project = @{ gid = '77' } }) } } } else { @{ data = @(@{ name = '3. Review' }, @{ name = '4. Done' }) } } }
Assert-Equal '4. Done' (Resolve-DoneSectionName -Gid '123' -Code '4' -Get $cmGetOk).Name 'resolved through the task''s board'
$cmGetFail = { param($Uri) throw 'HTTP 403' }
$cmR = Resolve-DoneSectionName -Gid '123' -Code '4' -Get $cmGetFail
Assert-True ($cmR.Name -eq '' -and $cmR.Why -eq 'the task could not be read') 'a failed read names no section and never throws'
Assert-Equal 'the repo states no Completed stage in Get-AsanaStageMap' (Resolve-DoneSectionName -Gid '123' -Code '' -Get $cmGetOk).Why 'no code, no read'
Assert-Equal "Is anything still unclear? Leave a comment on this task. No more questions? Move the task to '4. Done' and mark it as complete." (Get-ClosedMessageAsk -DoneSection '4. Done') 'the closing ask, word for word from Maikel''s reference story'
Assert-True ((New-ClosedMessageHtml -IssueRef 'o/r#1' -Research).Contains('reopened anytime') -and (New-ClosedMessageHtml -IssueRef 'o/r#1' -Research).Contains('follows')) 'a research close that carries no block falls back to the result form, saying the message follows'
Assert-Equal $rbBlock (Select-SessionPasteBlockBody -Bodies @('talk', $rbBlock, 'more talk')) 'the selection hands back the whole newest block, so its research marker can be read'
Assert-True ((New-ClosedMessageHtml -IssueRef 'o/r&x#1') -match '&amp;') 'a character XML reserves is escaped, so Asana is never sent a malformed body'
Assert-Throws { New-AsanaCommentRequest -Gid '123; rm -rf /' -Html '<body/>' } 'a non-numeric GID never reaches a request URL'
$cmReq = New-AsanaCommentRequest -Gid '123' -Html '<body>x</body>'
Assert-Equal 'https://app.asana.com/api/1.0/tasks/123/stories' $cmReq.Uri 'the one write is a story on the task'
Assert-True ($cmReq.Body -match '"html_text"') 'posted as html_text'

# WHAT IT NEVER DOES: no write but the comment and the one InReview move (#3248), no completion, no label,
# no other event.
$cmSrc = [System.IO.File]::ReadAllText($cmTemplate)
Assert-True ($cmSrc -notmatch "completed\s*=\s*\`$true|addProject|removeProject|gh issue edit|gh label") 'the template carries no completion, board change or label write'
Assert-Equal 1 ([regex]::Matches($cmSrc, '/sections/[^"]*addTask')).Count 'and the one section write is the addTask New-AsanaMoveRequest builds'
# THE STRUCTURAL HALF (code review): two HTTP write sites, each sending the request its pure builder made.
Assert-Equal 2 ([regex]::Matches($cmSrc, '(?m)^\s*Invoke-RestMethod\b')).Count 'the template makes exactly two HTTP writes: the comment and the move'
Assert-True ($cmSrc -match '\$request\s*=\s*New-AsanaCommentRequest' -and $cmSrc -match 'Invoke-RestMethod -Method \$request\.Method -Uri \$request\.Uri') 'the first sends the one request New-AsanaCommentRequest builds'
Assert-True ($cmSrc -match '\$move\s*=\s*New-AsanaMoveRequest' -and $cmSrc -match 'Invoke-RestMethod -Method \$move\.Method -Uri \$move\.Uri') 'and the second the one New-AsanaMoveRequest builds'
Assert-True ($cmSrc.IndexOf('Invoke-RestMethod -Method $request.Method') -lt $cmSrc.IndexOf('Invoke-RestMethod -Method $move.Method')) 'the move comes after the message, so a skipped or refused move never costs the message'

# THE ONE CARD MOVE (#3248): into the board's InReview section, on a completed close with a block, never out
# of Completed, and skipped wherever the board does not answer one way.
$cmMem  = @([pscustomobject]@{ Project = '77'; SectionName = '2. In Progress' })
$cmSecs = @([pscustomobject]@{ Gid = '301'; Name = '1. Todo' }, [pscustomobject]@{ Gid = '302'; Name = '2. In Progress' },
            [pscustomobject]@{ Gid = '303'; Name = '3. Waiting for review' }, [pscustomobject]@{ Gid = '304'; Name = '4. Done' })
Assert-Equal '303' (Select-ReviewMoveSection -Memberships $cmMem -Sections $cmSecs -InReviewCode '3' -CompletedCode '4').SectionGid 'the section whose code is the InReview code'
Assert-Equal '' (Select-ReviewMoveSection -Memberships @([pscustomobject]@{ Project = '77'; SectionName = '4. Done' }) -Sections $cmSecs -InReviewCode '3' -CompletedCode '4').SectionGid 'a card already in Completed is never pulled backwards'
Assert-Equal '' (Select-ReviewMoveSection -Memberships @([pscustomobject]@{ Project = '77'; SectionName = '3. Waiting for review' }) -Sections $cmSecs -InReviewCode '3' -CompletedCode '4').SectionGid 'a card already in InReview is not moved again'
Assert-Equal '' (Select-ReviewMoveSection -Memberships ($cmMem + @([pscustomobject]@{ Project = '88'; SectionName = '1. Todo' })) -Sections $cmSecs -InReviewCode '3' -CompletedCode '4').SectionGid 'a task on several boards is not moved: which card is a guess'
Assert-Equal '' (Select-ReviewMoveSection -Memberships $cmMem -Sections ($cmSecs + @([pscustomobject]@{ Gid = '305'; Name = '3. Review' })) -InReviewCode '3' -CompletedCode '4').SectionGid 'two sections with the InReview code is a guess, so none'
Assert-Equal '' (Select-ReviewMoveSection -Memberships $cmMem -Sections $cmSecs -InReviewCode '' -CompletedCode '4').SectionGid 'no InReview code in the stage map, no move'
Assert-Equal '' (Select-ReviewMoveSection -Memberships $cmMem -Sections $cmSecs -InReviewCode '9' -CompletedCode '4').SectionGid 'a board without that code, no move'
Assert-Equal '' (Select-ReviewMoveSection -Memberships $cmMem -Sections $cmSecs -InReviewCode '3' -CompletedCode '').SectionGid 'no Completed code: a done card cannot be told apart, so the guard fails closed'
Assert-Equal '' (Select-ReviewMoveSection -Memberships @([pscustomobject]@{ Project = '77'; SectionName = 'Done' }) -Sections $cmSecs -InReviewCode '3' -CompletedCode '4').SectionGid 'a card in a section without a code is not moved either'
Assert-Equal '5' (Get-RepoStageCode -ConfigText "function Get-AsanaStageMap { @{`nInReview = 5`nCompleted = 7`n} }" -Stage 'InReview') 'the InReview code is read from the same map, as text'
$cmGetMove = { param($Uri) if ($Uri -like '*/tasks/*') { @{ data = @{ memberships = @(@{ project = @{ gid = '77' }; section = @{ name = '2. In Progress' } }) } } } else { @{ data = @(@{ gid = '303'; name = '3. Waiting for review' }, @{ gid = '304'; name = '4. Done' }) } } }
Assert-Equal '303' (Resolve-ReviewMoveSection -Gid '123' -InReviewCode '3' -CompletedCode '4' -Get $cmGetMove).SectionGid 'resolved through the task''s board and the section it sits in'
$cmMoveF = Resolve-ReviewMoveSection -Gid '123' -InReviewCode '3' -CompletedCode '4' -Get $cmGetFail
Assert-True ($cmMoveF.SectionGid -eq '' -and $cmMoveF.Why -eq 'the task could not be read') 'a failed read is a skipped move and never throws'
$cmMove = New-AsanaMoveRequest -Gid '123' -SectionGid '303'
Assert-Equal 'https://app.asana.com/api/1.0/sections/303/addTask' $cmMove.Uri 'the move is an addTask on the section'
Assert-Equal '{"data":{"task":"123"}}' $cmMove.Body 'naming the task alone'
Assert-Throws { New-AsanaMoveRequest -Gid '123' -SectionGid '3/../x' } 'a non-numeric section GID never reaches a request URL'
Assert-Throws { New-AsanaMoveRequest -Gid '1 2' -SectionGid '303' } 'nor a non-numeric task GID'
Assert-True ($cmSrc -match '(?s)# THE CARD FOLLOWS THE MESSAGE INTO REVIEW.*?if \(\$sections\) \{') 'the move is made only where this round''s block was carried'

# THE SECURITY REVIEW'S REPAIRS (#2818).
Assert-True (Test-TrustedCommentAuthor -Association 'MEMBER') 'a member''s comment may supply the block'
Assert-True (Test-TrustedCommentAuthor -Association 'collaborator') 'and so may a collaborator''s, in any case'
Assert-True (-not (Test-TrustedCommentAuthor -Association 'CONTRIBUTOR')) 'a contributor''s may not -- anyone else could put a link on the task under the automation''s header'
Assert-True (-not (Test-TrustedCommentAuthor -Association '')) 'nor a comment whose association is unknown'
Assert-True ($cmSrc -match 'Association = \[string\]\$comment\.author_association') 'and the comment read keeps the REST field author_association for that filter'

# THE COMMENT READ IS REST, AND A FAILED READ IS NOT AN ISSUE WITHOUT A BLOCK (#2875). The GraphQL read
# ('gh issue view --json comments 2>$null') answered nothing on the runner for an issue carrying a
# trusted block, and the log then said 'none was on the issue'.
$cmArgs = Get-IssueCommentsApiArgs -IssueRef 'BWJ-Development/xoxowildhearts#383'
Assert-Equal 'api|repos/BWJ-Development/xoxowildhearts/issues/383/comments|--paginate|--jq|.[] | {author_association, login: .user.login, body, created_at}' ($cmArgs -join '|') `
    'the comments are read through REST, every page, one JSON object per comment per line, with the author''s login and the time (#2968)'
Assert-Throws { Get-IssueCommentsApiArgs -IssueRef 'o/r#1;x' } 'and an IssueRef that is not owner/repo#<n> never reaches the gh call'
Assert-True ($cmSrc -notmatch '& gh issue view') 'the template no longer reads comments through gh issue view (GraphQL)'
Assert-True ($cmSrc -match '& gh @ghArgs 2>&1' -and $cmSrc -notmatch '2>\$null') 'and gh''s stderr is captured, never discarded'
# Two pages, as --paginate with --jq prints them: one line per comment, pages simply following each other.
# gh's jq escapes < and > as JSON unicode escapes (backslash-u003c), so the marker arrives escaped and must come back whole.
$cmJsonMarker = $cmLibMarker.Replace('<', ([string][char]92 + 'u003c')).Replace('>', ([string][char]92 + 'u003e'))
$cmPage1 = @('{"author_association":"MEMBER","body":"first\nline two"}', ('{"author_association":"CONTRIBUTOR","body":"' + $cmJsonMarker + ' forged"}'))
$cmPage2 = @('', ('{"author_association":"OWNER","body":"' + $cmJsonMarker + ' real"}'))
$cmComments = @(ConvertFrom-IssueCommentLines -Lines ($cmPage1 + $cmPage2))
Assert-Equal 3 $cmComments.Count 'paginated output parses into every comment of every page, blank lines skipped'
Assert-Equal "first`nline two" $cmComments[0].Body 'a body''s escaped newline comes back as a newline'
$cmBodies = @((Select-TrustedCommentBodies -Comments $cmComments).Bodies)
Assert-Equal 2 $cmBodies.Count 'the trust filter keeps the trusted bodies'
Assert-Equal "$cmLibMarker real" $cmBodies[1] 'and an untrusted comment between them is dropped, whatever it carries'
Assert-Equal 0 @(ConvertFrom-IssueCommentLines -Lines @()).Count 'an issue with no comments parses into none'

# A PRIVATE ORG MEMBER READS AS CONTRIBUTOR TO THE WORKFLOW TOKEN (#2907): smartwatchbanden#884 carried a
# block by an org member, and the run logged 'none was on the issue'. The author of an untrusted marker
# comment is asked about by repo permission, and a drop is logged as a drop.
Assert-True (Test-TrustedRepoPermission -Permission 'write') 'a writer may supply the block'
Assert-True (Test-TrustedRepoPermission -Permission 'ADMIN') 'and so may an admin, in any case'
Assert-True (-not (Test-TrustedRepoPermission -Permission 'read')) 'a reader may not'
Assert-True (-not (Test-TrustedRepoPermission -Permission 'none') -and -not (Test-TrustedRepoPermission -Permission '')) 'nor no permission, nor an unknown one'
$cmPriv = @(
    [pscustomobject]@{ Association = 'CONTRIBUTOR'; Login = 'maikel-bwj'; Body = "$cmLibMarker`n---`nTE BEKIJKEN OP`nx`n---" },
    [pscustomobject]@{ Association = 'NONE'; Login = 'stranger'; Body = 'no marker here' },
    [pscustomobject]@{ Association = 'CONTRIBUTOR'; Login = 'maikel-bwj'; Body = "$cmLibMarker again" },
    [pscustomobject]@{ Association = 'NONE'; Login = 'evil[bot]'; Body = "$cmLibMarker forged" },
    [pscustomobject]@{ Association = 'MEMBER'; Login = 'visible'; Body = "$cmLibMarker member" }
)
Assert-Equal 'maikel-bwj' ((Get-PermissionCheckLogins -Comments $cmPriv) -join ',') 'only an untrusted marker comment''s user login is asked about, once -- no marker, a bot and a visible member cost no call'
$cmTrustW = Select-TrustedCommentBodies -Comments $cmPriv -Permissions @{ 'maikel-bwj' = 'write' }
Assert-Equal 3 @($cmTrustW.Bodies).Count 'a writer''s marker comments are carried beside the member''s'
Assert-Equal 1 $cmTrustW.Dropped 'and the bot''s is the one dropped'
Assert-True ($cmTrustW.Bodies[0].StartsWith($cmLibMarker)) 'in the order GitHub returned them, so the newest block still wins'
Assert-True (@($cmTrustW.Notes) -join '|' -match "carried on repo permission 'write' \(association CONTRIBUTOR\)") 'a block carried on permission is logged with the association it overrode -- the measurement #2907 lacked'
Assert-True (-not ((@($cmTrustW.Notes) -join '|').Contains('evil[bot]'))) 'a login that is not a user login is never printed'
Assert-True (-not ((@($cmTrustW.Notes) -join '|').Contains('forged'))) 'and no note carries a comment body'
$cmTrustR = Select-TrustedCommentBodies -Comments $cmPriv -Permissions @{ 'maikel-bwj' = 'read' }
Assert-Equal 1 @($cmTrustR.Bodies).Count 'a reader''s marker comments are not carried'
Assert-True (@($cmTrustR.Notes) -join '|' -match "by 'maikel-bwj' was not carried: association CONTRIBUTOR, repo permission 'read'") 'and the drop names the association and the permission'
$cmTrustF = Select-TrustedCommentBodies -Comments $cmPriv -Permissions @{ 'maikel-bwj' = $null }
Assert-True (@($cmTrustF.Notes) -join '|' -match 'permission could not be read') 'a failed permission read is a drop that says so, never a permission'
Assert-Equal 3 $cmTrustF.Dropped 'and it counts as a drop'
Assert-True ((Get-ClosedMessageBlockPhrase -Sections '' -ReadOk $true -Dropped 1).StartsWith('without a go-live block -- one was on the issue but its author was not trusted (the reason is above)')) 'a dropped block is never logged as none on the issue'
$cmPermArgs = Get-CollaboratorPermissionApiArgs -IssueRef 'BWJ-Development/smartwatchbanden#884' -Login 'maikel-bwj'
Assert-Equal 'api|repos/BWJ-Development/smartwatchbanden/collaborators/maikel-bwj/permission|--jq|.permission' ($cmPermArgs -join '|') 'the permission is read through REST, the legacy base role alone'
Assert-Throws { Get-CollaboratorPermissionApiArgs -IssueRef 'o/r#1' -Login '../x' } 'and a login that is not a user login never reaches the request path'
Assert-True ($cmSrc -match 'Get-ClosedMessageBlockPhrase -Sections \$sections -ReadOk \$read\.Ok -Dropped \$dropped') 'the final log line knows about a drop'
# The permission read itself, against a stubbed gh: a function shadows the executable for '& gh'.
function gh { if ($script:cmGhFail) { Write-Error 'HTTP 403: Resource not accessible by integration'; $global:LASTEXITCODE = 1 } else { 'write'; $global:LASTEXITCODE = 0 } }
$script:cmGhFail = $false
$cmPermOk = Read-CollaboratorPermission -IssueRef 'o/r#1' -Login 'maikel-bwj'
Assert-True ($cmPermOk.Ok -and $cmPermOk.Permission -eq 'write') 'a permission read that works answers the permission'
$script:cmGhFail = $true
$cmPermNo = Read-CollaboratorPermission -IssueRef 'o/r#1' -Login 'maikel-bwj'
Assert-True (-not $cmPermNo.Ok -and $cmPermNo.ExitCode -eq 1 -and $cmPermNo.Error -match '403') 'and a refused one is reported with gh''s exit code and stderr, never as a permission'
Remove-Item Function:\gh
Assert-Throws { ConvertFrom-IssueCommentLines -Lines @('[{"author_association":"MEMBER"') } 'a garbled line throws, so it is reported as a failed read rather than as no block'
Assert-Equal "with the session's go-live block" (Get-ClosedMessageBlockPhrase -Sections 'X' -ReadOk $true) 'the log says a block was carried when one was'
Assert-True ((Get-ClosedMessageBlockPhrase -Sections '' -ReadOk $true).StartsWith('without a go-live block -- none was on the issue')) 'it says none was on the issue only after a read that worked'
Assert-True ((Get-ClosedMessageBlockPhrase -Sections '' -ReadOk $true) -match 'result message follows, which the task''s assignee still owes the requester') 'and that the assignee still owes the requester the result message (#3004)'
Assert-Equal "with the session's research block" (Get-ClosedMessageBlockPhrase -Sections 'X' -ReadOk $true -Research $true) 'a carried research block is logged as one'
Assert-True ((Get-ClosedMessageBlockPhrase -Sections '' -ReadOk $false) -match 'could not be read' -and (Get-ClosedMessageBlockPhrase -Sections '' -ReadOk $false) -notmatch 'none was on the issue') 'and a failed read says the comments could not be read, never that none was on the issue'
Assert-True ($cmSrc -match 'could not be read: gh exited \$\(\$read\.ExitCode\): \$\(\$read\.Error\)') 'a failed read logs gh''s exit code and stderr'
Assert-True ($cmSrc -match 'Get-ClosedMessageBlockPhrase -Sections \$sections -ReadOk \$read\.Ok\b') 'and the final log line is built from the read''s own outcome'
Assert-Equal 'a b' (ConvertTo-AsanaXmlText -Text ("a" + [char]0x0B + " b")) 'an XML-invalid control character is dropped, so Asana never answers 400 on it'
Assert-Equal "it's" (ConvertTo-AsanaXmlText -Text "it's") 'an apostrophe stays as typed -- no &apos; Asana was never measured accepting'
Assert-Equal 'Zie <a href="https://x.nl/a">https://x.nl/a</a>.' (ConvertTo-AsanaStoryHtml -Markdown 'Zie https://x.nl/a.') 'a bare URL does not swallow the full stop after it'
Assert-Throws { New-AsanaCommentRequest -Gid "123`n" -Html '<body/>' } 'a GID with a trailing newline is refused -- the guard is anchored with \z'
$cmYml = [System.IO.File]::ReadAllText((Join-Path $PluginRoot 'templates\asana-closed-message.yml'))
Assert-True ($cmYml -match 'types:\s*\[closed,\s*reopened\]') 'the workflow runs on a close and a reopen only (#2854)'
Assert-True ($cmYml -notmatch '(?m)^\s*(schedule|workflow_dispatch|pull_request|push):') 'with no schedule, manual or other trigger -- and the types line above names no label event'
Assert-True ($cmYml -match 'github\.event\.action' -and $cmYml -match '-Event \$env:ISSUE_EVENT') 'it hands the event to the script, which picks the message'
Assert-True ($cmYml -match 'secrets\.ASANA_PAT' -and $cmYml -notmatch 'GH_PROJECT_TOKEN|ASANA_PROJECT_GID') 'and needs ASANA_PAT alone'
Assert-True ($cmYml -match 'issues:\s*read') 'and only reads issues on GitHub'
Assert-True ($cmYml -match 'state_reason') 'it hands the close reason to the script, which decides'
Assert-True ($cmYml -match 'ISSUE_LABELS:\s*\$\{\{\s*toJSON\(github\.event\.issue\.labels\.\*\.name\)\s*\}\}') 'and the labels as JSON, which make a not-planned close the on-hold message (#2902)'
Assert-True ($cmYml -match 'persist-credentials:\s*false') 'the checkout leaves no token behind'
Assert-True ($cmYml -notmatch '-IssueBody') 'and the body reaches the script through the environment, not the command line'

# A BLOCK FROM BEFORE THE LAST REOPEN IS NOT CARRIED (#2968), and neither is one whose reopen could not be
# read. xoxowildhearts#414 closed after round 1, was reopened, and was closed again by round 2's PR: the
# second closed message carried round 1's block. The pure verdict is asserted first, then Invoke-Main
# end to end against a stubbed gh and a stubbed Asana call.
Write-Host "`n-- the stale block check (#2968) --" -ForegroundColor Cyan
$stBlock = "$cmLibMarker`nFraming sentence.`n---`n$hdr`n`nGitHub issue o/r#7 is now closed.`n`nTE BEKIJKEN OP`nhttps://x.invalid/round-1`n---"
$stBlock2 = $stBlock.Replace('round-1', 'round-2')
$stT1 = '2026-10-01T10:00:00Z'
$stT2 = '2026-10-02T10:00:00Z'
$stT3 = '2026-10-03T10:00:00Z'
function New-StComment { param([string]$Body, [string]$At) [pscustomobject]@{ Body = $Body; CreatedAt = $At } }

Assert-Equal 'none' (Get-AsanaPasteBlockVerdict -Comments @((New-StComment 'plain' $stT1)) -LastReopenedAt $stT2) 'an issue with no block is none, reopened or not'
Assert-Equal 'none' (Get-AsanaPasteBlockVerdict -Comments @() -LastReopenedAt $null) 'and so is one with no comments'
Assert-Equal 'not-reopened' (Get-AsanaPasteBlockVerdict -Comments @((New-StComment $stBlock $stT1)) -LastReopenedAt $null) 'a block on an issue never reopened is not-reopened'
Assert-Equal 'stale' (Get-AsanaPasteBlockVerdict -Comments @((New-StComment $stBlock $stT1)) -LastReopenedAt $stT2) 'a block posted before the last reopen is stale'
Assert-Equal 'fresh' (Get-AsanaPasteBlockVerdict -Comments @((New-StComment $stBlock $stT1), (New-StComment $stBlock2 $stT3)) -LastReopenedAt $stT2) 'a block posted after it is fresh, whatever an older one says'
Assert-Equal 'stale' (Get-AsanaPasteBlockVerdict -Comments @((New-StComment $stBlock $stT2)) -LastReopenedAt $stT2) 'a block stamped the very second of the reopen is stale: the repairable answer to a tie'
Assert-Equal 'stale' (Get-AsanaPasteBlockVerdict -Comments @((New-StComment $stBlock2 $stT3), (New-StComment $stBlock $stT1)) -LastReopenedAt $stT3) 'the NEWEST block is judged, not the first in the list'
Assert-Equal 'stale' (Get-AsanaPasteBlockVerdict -Comments @((New-StComment $stBlock $stT1), (New-StComment "question`n$cmLibMarker" $stT3)) -LastReopenedAt $stT2) 'a marker comment that is no block (a question) does not make the older block fresh'
Assert-Equal 'stale' (Get-AsanaPasteBlockVerdict -Comments @((New-StComment $stBlock $stT1), (New-StComment ($stBlock2 -replace 'TE BEKIJKEN OP', '[ADD LINK]') $stT3)) -LastReopenedAt $stT2) 'nor does a placeholder copy'
Assert-Equal 'unknown' (Get-AsanaPasteBlockVerdict -Comments @((New-StComment $stBlock 'not a time')) -LastReopenedAt $stT2) 'a block time that does not parse is unknown, never fresh'
Assert-Equal 'unknown' (Get-AsanaPasteBlockVerdict -Comments @((New-StComment $stBlock $stT1)) -LastReopenedAt 'garbage') 'and so is a reopen time that does not parse'
Assert-Equal 'stale' (Get-AsanaPasteBlockVerdict -Comments @((New-StComment $stBlock ([datetime]::Parse('2026-10-01T10:00:00Z').ToUniversalTime()))) -LastReopenedAt ([datetime]'2026-10-02T12:00:00+02:00')) 'datetimes in any kind are compared as UTC instants'
# ONE PREDICATE FOR "A BLOCK" (#2968, code review): the freshness check judges by what the selection would
# carry. A degenerate marker comment that the selection skips must not make an older block look fresh.
$stDegenerate = @(
    "$cmLibMarker`n---`n---",
    "$cmLibMarker`n---`n$hdr`n`nGitHub issue o/r#7 is now closed.`n---",
    "$cmLibMarker`nno rules at all",
    "$cmLibMarker`n---`nonly one rule")
foreach ($d in $stDegenerate) {
    Assert-True (-not (Test-AsanaPasteBlockBody -Body $d)) "a degenerate marker comment is no block: $(($d -split "`n")[1..2] -join ' / ')"
    Assert-Equal '' (Select-SessionPasteBlockSections -Bodies @($d)) 'and the selection carries nothing from it either'
    Assert-Equal 'stale' (Get-AsanaPasteBlockVerdict -Comments @((New-StComment $stBlock $stT1), (New-StComment $d $stT3)) -LastReopenedAt $stT2) 'so a newer one after the reopen leaves the older block stale, as the selection falls back to it'
}
$stFrameAdd = "$cmLibMarker`n[ADD LINK] in the framing line`n---`n$hdr`n`nGitHub issue o/r#7 is now closed.`n`nTE BEKIJKEN OP`nhttps://x.invalid/r2`n---"
Assert-True (Test-AsanaPasteBlockBody -Body $stFrameAdd) '[ADD LINK] OUTSIDE the sections is not a placeholder copy'
Assert-True ((Select-SessionPasteBlockSections -Bodies @($stFrameAdd)).Contains('r2')) 'the selection carries it'
Assert-Equal 'fresh' (Get-AsanaPasteBlockVerdict -Comments @((New-StComment $stBlock $stT1), (New-StComment $stFrameAdd $stT3)) -LastReopenedAt $stT2) 'so the freshness check agrees'
Assert-True ($null -eq (ConvertTo-AsanaInstant -Value '')) 'an empty timestamp is no instant'
Assert-Equal '2026-10-02 10:00:00' ((ConvertTo-AsanaInstant -Value $stT2).ToString('yyyy-MM-dd HH:mm:ss')) 'an ISO timestamp reads as UTC'

# The duplicate check of build-golive-block -Post counts only blocks of the CURRENT round.
Assert-True (Test-AsanaPasteBlockSinceReopen -Comments @((New-StComment $stBlock $stT1)) -LastReopenedAt $null) 'a block on an issue never reopened is a duplicate, as before'
Assert-True (-not (Test-AsanaPasteBlockSinceReopen -Comments @((New-StComment $stBlock $stT1)) -LastReopenedAt $stT2)) 'a block from before the reopen is not one: the corrected block posts without -Force'
Assert-True (Test-AsanaPasteBlockSinceReopen -Comments @((New-StComment $stBlock $stT1), (New-StComment $stBlock2 $stT3)) -LastReopenedAt $stT2) 'a block after the reopen is a duplicate'
Assert-True (Test-AsanaPasteBlockSinceReopen -Comments @((New-StComment (Get-AsanaPasteBlockLead) $stT3)) -LastReopenedAt $stT2) 'a hand-typed block, found by its lead sentence, counts the same way'
Assert-True (Test-AsanaPasteBlockSinceReopen -Comments @((New-StComment $stBlock 'garbage')) -LastReopenedAt $stT2) 'a block whose time cannot be read counts, the cautious answer'

# The one GraphQL read's reply.
$stJson = '{"data":{"repository":{"issue":{"reopened":{"nodes":[{"createdAt":"2026-10-02T10:00:00Z"}]},"comments":{"totalCount":2,"nodes":[{"body":"a","createdAt":"2026-10-01T10:00:00Z"},{"body":"b","createdAt":"2026-10-03T10:00:00Z"}]}}}}}'
$stState = ConvertFrom-AsanaIssueBlockStateJson -Json $stJson
Assert-True ($stState.Ok -and @($stState.Comments).Count -eq 2 -and -not $stState.Truncated) 'the reply parses into its comments'
Assert-Equal '2026-10-02' ((ConvertTo-AsanaInstant -Value $stState.LastReopenedAt).ToString('yyyy-MM-dd')) 'and the last reopen'
Assert-True ($null -eq (ConvertFrom-AsanaIssueBlockStateJson -Json $stJson.Replace('[{"createdAt":"2026-10-02T10:00:00Z"}]', '[]')).LastReopenedAt) 'an issue never reopened has no reopen time'
Assert-True ((ConvertFrom-AsanaIssueBlockStateJson -Json $stJson.Replace('"totalCount":2', '"totalCount":150')).Truncated) 'an issue with more comments than were read says so'
Assert-Equal '' $stState.Body 'a reply without the body field reads as an empty body'
Assert-Equal "<!-- asana-task: 1 -->`nx" (ConvertFrom-AsanaIssueBlockStateJson -Json $stJson.Replace('"issue":{', '"issue":{"body":"<!-- asana-task: 1 -->\nx",')).Body 'and one with it carries the issue body, which the close guard resolves the task from (#3004)'
Assert-True (-not (ConvertFrom-AsanaIssueBlockStateJson -Json 'not json').Ok -and -not (ConvertFrom-AsanaIssueBlockStateJson -Json '{"data":{"repository":{"issue":null}}}').Ok -and -not (ConvertFrom-AsanaIssueBlockStateJson -Json '').Ok) 'a reply that is not JSON, or names no issue, is not Ok'

# The template's own reads and its message.
$stArgs = Get-IssueReopenApiArgs -IssueRef 'BWJ-Development/xoxowildhearts#414'
Assert-Equal 'api|repos/BWJ-Development/xoxowildhearts/issues/414/events|--paginate|--jq|.[] | select(.event == "reopened") | .created_at' ($stArgs -join '|') 'the last reopen is read through REST too, every page, only the reopened events'
Assert-Throws { Get-IssueReopenApiArgs -IssueRef 'o/r#1;x' } 'and an IssueRef that is not owner/repo#<n> never reaches the gh call'
Assert-Equal $stT3 (ConvertFrom-ReopenEventLines -Lines @($stT1, '', $stT3, $stT2)) 'the LATEST of several reopens is the one returned, blank lines skipped'
Assert-True ($null -eq (ConvertFrom-ReopenEventLines -Lines @())) 'no lines is an issue never reopened'
Assert-Throws { ConvertFrom-ReopenEventLines -Lines @('<html>rate limited</html>') } 'a line that is not a timestamp throws, so a garbled read is a failed read and never "never reopened"'
$stPending = New-ClosedMessageHtml -IssueRef 'o/r#7'
[void][xml]$stPending
Assert-True ($stPending.Contains("is now <strong>closed</strong>: this Asana task is now in review.`nIt can be reopened anytime when something is still not working as expected.`n`nThe result message for this round follows.</body>")) 'the pending close is the closed line and one sentence under it'
Assert-True (-not ($stPending -cmatch '<strong>[A-Z ]+</strong>')) 'with no block'
Assert-True (-not (New-ClosedMessageHtml -IssueRef 'o/r#7' -BlockSections 'TE BEKIJKEN OP').Contains('follows')) 'and never beside a block, which it would contradict'
Assert-True ([System.IO.File]::ReadAllText($cmTemplate) -notmatch 'ResultPending') 'the switch is gone: every close without a block says the result follows (#3004)'
Assert-True ((Get-ClosedMessageBlockPhrase -Sections '' -Held 'stale') -match 'predates its last reopen' -and (Get-ClosedMessageBlockPhrase -Sections '' -Held 'unread') -match 'could not be read') 'the log names why a block was held back'
Assert-Equal 1 @((Select-TrustedCommentBodies -Comments @([pscustomobject]@{ Association = 'OWNER'; Login = 'a'; Body = 'x'; CreatedAt = $stT1 }, [pscustomobject]@{ Association = 'NONE'; Login = 'b'; Body = 'no marker'; CreatedAt = $stT1 })).Comments).Count 'the trust filter hands back the trusted comments themselves, so a block keeps its time'

# END TO END: Invoke-Main on a close, against a stubbed gh (the comment and event reads) and a stubbed Asana call.
function gh {
    $a = @($args)
    $script:stGhCalls += ,($a -join ' ')
    $global:LASTEXITCODE = 0
    if ($a[1] -like '*/comments') { $script:stComments; return }
    if ($a[1] -like '*/events') {
        if ($script:stEventsFail) { Write-Error 'HTTP 403: Resource not accessible by integration'; $global:LASTEXITCODE = 1; return }
        $script:stEvents
        return
    }
    $global:LASTEXITCODE = 1
}
function Invoke-RestMethod {
    param($Method, $Uri, $Headers, $Body)
    # The two board reads a research close makes for its done section (#3017).
    if ($Method -eq 'GET') {
        $script:stAsanaReads += ,$Uri
        if ($Uri -like '*/tasks/*') { return @{ data = @{ memberships = @(@{ project = @{ gid = '55' }; section = @{ name = $script:stCardSection } }) } } }
        return @{ data = @(@{ gid = '501'; name = '1. Todo' }, @{ gid = '503'; name = '3. Waiting for review' }, @{ gid = '504'; name = '4. Done' }) }
    }
    # The one card move (#3248), kept apart from the message so neither overwrites the other.
    if ($Uri -like '*/addTask') {
        $script:stMoves += ,$Uri
        if ($script:stMoveFail) { throw 'HTTP 403' }
        return
    }
    $script:stPosted = [System.Text.Encoding]::UTF8.GetString($Body)
}
$script:stCardSection = '2. In Progress'; $script:stMoves = @(); $script:stMoveFail = $false
$stConfig = Join-Path ([System.IO.Path]::GetTempPath()) "st-repo-config-$([Guid]::NewGuid().ToString('N')).ps1"
[System.IO.File]::WriteAllText($stConfig, "function Get-AsanaStageMap {`n    return @{ Completed = '4' }`n}`n")
$script:RepoConfigPath = $stConfig
function New-StLine { param([string]$Body, [string]$At) (ConvertTo-Json -Compress @{ author_association = 'OWNER'; login = 'dev'; body = $Body; created_at = $At }) }
function Invoke-StMain {
    param([string[]]$Comments, [string[]]$Events, [bool]$EventsFail = $false)
    $script:stComments = $Comments; $script:stEvents = $Events; $script:stEventsFail = $EventsFail
    $script:stGhCalls = @(); $script:stPosted = ''; $script:stAsanaReads = @(); $script:stMoves = @()
    $script:IssueRef = 'o/r#7'; $script:StateReason = 'completed'; $script:Event = 'closed'; $script:AsanaPat = 'x'
    $script:IssueBody = '<!-- asana-task: 1234 -->'; $script:IssueLabels = ''
    $log = (& { Invoke-Main } 6>&1 | Out-String)
    $posted = if ($script:stPosted) { [string](ConvertFrom-Json -InputObject $script:stPosted).data.html_text } else { '' }
    return [pscustomobject]@{ Body = $posted; Log = $log; Calls = @($script:stGhCalls); AsanaReads = @($script:stAsanaReads); Moves = @($script:stMoves) }
}
$stOld = New-StLine $stBlock $stT1
$stNew = New-StLine $stBlock2 $stT3

$stRun = Invoke-StMain -Comments @($stOld) -Events @()
Assert-True ($stRun.Body.Contains('round-1') -and $stRun.Body.Contains('TE BEKIJKEN OP')) 'never reopened: the block is carried, as before'
Assert-True (-not $stRun.Body.Contains('follows')) 'with no pending sentence'
$stRun = Invoke-StMain -Comments @($stOld) -Events @($stT2)
Assert-True (-not $stRun.Body.Contains('round-1') -and -not $stRun.Body.Contains('TE BEKIJKEN OP')) 'reopened after the block: the stale block is NOT carried (#2968)'
Assert-True ($stRun.Body.Contains('The result message for this round follows.') -and $stRun.Body.Contains('is now <strong>closed</strong>')) 'the closed line goes out, with the sentence that this round''s result follows'
Assert-True ($stRun.Log -match 'predates its last reopen') 'and the log says why'
$stRun = Invoke-StMain -Comments @($stOld, $stNew) -Events @($stT1, $stT2)
Assert-True ($stRun.Body.Contains('round-2') -and -not $stRun.Body.Contains('round-1') -and -not $stRun.Body.Contains('follows')) 'a block posted after the last reopen is carried: round 2''s, and not round 1''s'
$stRun = Invoke-StMain -Comments @($stOld) -Events @() -EventsFail $true
Assert-True (-not $stRun.Body.Contains('TE BEKIJKEN OP') -and $stRun.Body.Contains('follows')) 'a reopen read that failed carries no block that might be stale, and says the result message follows (#3004)'
Assert-True ($stRun.Log -match 'could not be read: gh exited 1: .*403' -and $stRun.Log -match 'whether it is stale is unknown') 'and the log carries gh''s own error and says the staleness is unknown'
$stRun = Invoke-StMain -Comments @((New-StLine 'just talk' $stT1)) -Events @($stT2)
Assert-True (-not @($stRun.Calls | Where-Object { $_ -like '*/events' }).Count) 'an issue with no block costs no events read'
Assert-True ($stRun.Body.Contains('follows')) 'and the closed line is never sent alone: the result message follows (#3004, smartwatchbanden#943)'
$stRun = Invoke-StMain -Comments @((New-StLine $rbBlock $stT1)) -Events @()
Assert-True ($stRun.Body.Contains('Nothing has changed. Read the outcome below.') -and $stRun.Body.Contains('<strong>OUTCOME</strong>')) 'a research block is carried under the research closed line (#3004, #3017)'
Assert-True ($stRun.Body.Contains("Move the task to '4. Done' and mark it as complete.")) 'and the ask names the done section the repo''s stage map and the task''s board agree on (#3017)'
Assert-True ($stRun.Log -match 'Done section for the closing ask: named -- found by code 4' -and $stRun.Log -notmatch '4\. Done') 'the log says it was found, and does not print the board''s text'
Assert-Equal 2 $stRun.AsanaReads.Count 'two Asana reads: the task''s boards, then that board''s sections'
Assert-True ($stRun.Body -notmatch 'reopened anytime|follows') 'without the reopen invitation'
Assert-True ($stRun.Log -match "with the session's research block") 'and the log says it was one'
$stRun = Invoke-StMain -Comments @($stOld) -Events @()
Assert-Equal 0 $stRun.AsanaReads.Count 'a result close makes no board read'
Assert-True ($stRun.Body.Contains("this Asana task is now in review.`nIt can be reopened anytime") -and $stRun.Body -notmatch 'becomes visible') 'a block without the after-release marker keeps the plain reopen line (#3069)'
$stRel = New-StLine ($stBlock.Replace("$cmLibMarker`n", "$cmLibMarker`n$(Get-AsanaReleaseBlockMarker)`n")) $stT1
$stRun = Invoke-StMain -Comments @($stRel) -Events @()
Assert-True ($stRun.Body.Contains("this Asana task is now in review.`n`n") -and $stRun.Body -notmatch 'becomes visible|reopened anytime' -and $stRun.Body.Contains('round-1')) 'a block carrying the after-release marker has the intro alone above its sections (#3069, #3328)'
$stRun = Invoke-StMain -Comments @($stRel) -Events @($stT2)
Assert-True ($stRun.Body -notmatch 'becomes visible' -and $stRun.Body.Contains('follows')) 'and a held-back after-release block takes its line with it'
$stRun = Invoke-StMain -Comments @((New-StLine $rbBlock $stT1)) -Events @($stT2)
Assert-True ($stRun.Body -notmatch 'Nothing has changed|OUTCOME' -and $stRun.Body.Contains('follows')) 'a research block from before the last reopen is held back like any other'
$stRun = Invoke-StMain -Comments @((New-StLine $stBlock $stT1)) -Events @($stT1)
Assert-True ($stRun.Body.Contains('follows')) 'a block stamped the second of the reopen is held back too'
$stRun = Invoke-StMain -Comments @($stOld, (New-StLine "$cmLibMarker`n---`n---" $stT3)) -Events @($stT2)
Assert-True (-not $stRun.Body.Contains('round-1') -and $stRun.Body.Contains('follows')) 'a newer degenerate marker comment after the reopen does not bring round 1''s block back (#2968)'
# A BY-HAND RECORD (#3183): this round's, from a trusted author, posts nothing; an earlier round's does not silence the close.
$stRun = Invoke-StMain -Comments @((New-StLine $hbBlock $stT1)) -Events @()
Assert-Equal '' $stRun.Body 'a by-hand record for this round: nothing is posted on the task'
Assert-True ($stRun.Log -match 'posted on Asana task 1234 by hand' -and $stRun.AsanaReads.Count -eq 0) 'and the log says why, with no board read'
Assert-Equal 0 $stRun.Moves.Count 'and a by-hand close never moves the card (#3248)'

# THE ONE CARD MOVE, END TO END (#3248): a stage map that states InReview, against the stubbed board.
$stMoveConfig = Join-Path ([System.IO.Path]::GetTempPath()) "st-repo-config-move-$([Guid]::NewGuid().ToString('N')).ps1"
[System.IO.File]::WriteAllText($stMoveConfig, "function Get-AsanaStageMap {`n    return @{ InReview = '3'; Completed = '4' }`n}`n")
$script:RepoConfigPath = $stMoveConfig
$stRun = Invoke-StMain -Comments @($stOld) -Events @()
Assert-True ($stRun.Body.Contains('round-1') -and @($stRun.Moves) -join '|' -eq 'https://app.asana.com/api/1.0/sections/503/addTask') 'a completed close with a block posts its message and moves the card into InReview'
Assert-True ($stRun.Log -match 'The card was moved to the InReview section \(found by code 3\)' -and $stRun.Log -notmatch 'Waiting for review') 'and the log says so without printing the board''s text'
$stRun = Invoke-StMain -Comments @((New-StLine 'just talk' $stT1)) -Events @()
Assert-True ($stRun.Body.Contains('follows') -and $stRun.Moves.Count -eq 0) 'a close without a block posts and moves nothing'
$stRun = Invoke-StMain -Comments @((New-StLine $hbBlock $stT1)) -Events @()
Assert-Equal 0 $stRun.Moves.Count 'a by-hand close moves nothing, with InReview stated too'
$script:stCardSection = '4. Done'
$stRun = Invoke-StMain -Comments @($stOld) -Events @()
Assert-True ($stRun.Body.Contains('round-1') -and $stRun.Moves.Count -eq 0 -and $stRun.Log -match 'never pulls it backwards') 'a card already in Completed keeps its place, and the message still goes out'
$script:stCardSection = '2. In Progress'; $script:stMoveFail = $true
$stRun = Invoke-StMain -Comments @($stOld) -Events @()
Assert-True ($stRun.Body.Contains('round-1') -and $stRun.Log -match 'The card was NOT moved: Asana refused the move \(HTTP') 'a refused move is logged, never thrown, and the message has gone out'
$script:stMoveFail = $false
$script:StateReason = 'not_planned'
$script:IssueLabels = '["awaiting-info-client"]'; $script:stMoves = @()
& { Invoke-Main } 6>&1 | Out-Null
Assert-Equal 0 @($script:stMoves).Count 'a not-planned close moves nothing'
$script:Event = 'reopened'; $script:stMoves = @()
& { Invoke-Main } 6>&1 | Out-Null
Assert-Equal 0 @($script:stMoves).Count 'nor does a reopen'
$script:StateReason = 'completed'; $script:Event = 'closed'; $script:IssueLabels = ''
$script:RepoConfigPath = $stConfig
Remove-Item -LiteralPath $stMoveConfig -Force
$stRun = Invoke-StMain -Comments @((New-StLine $hbBlock $stT1)) -Events @($stT2)
Assert-True ($stRun.Body.Contains('follows')) 'a by-hand record from before the last reopen is held back, and the close posts as any other'
$stRun = Invoke-StMain -Comments @((ConvertTo-Json -Compress @{ author_association = 'NONE'; login = 'stranger'; body = $hbBlock; created_at = $stT1 })) -Events @()
Assert-True ($stRun.Body.Contains('follows')) 'a by-hand record from an untrusted author silences nothing'
foreach ($v in 'IssueRef', 'StateReason', 'IssueBody', 'AsanaPat', 'IssueLabels', 'RepoConfigPath') { Set-Variable -Name $v -Value '' -Scope Script }
Remove-Item -LiteralPath $stConfig -ErrorAction SilentlyContinue
$Event = 'closed'
Remove-Item Function:\gh, Function:\Invoke-RestMethod, Function:\New-StLine, Function:\Invoke-StMain, Function:\New-StComment

# --- the prio label sync (templates/asana-prio-label.ps1, #2945) ----------------------------------
# AFTER the closed-message section on purpose: both templates carry copies of the same helpers, and the
# copy-equality pins below compare the two files' source text, not what is loaded.
Write-Host "`n-- the prio label template (#2945) --" -ForegroundColor Cyan
$plTemplate = Join-Path $PluginRoot 'templates\asana-prio-label.ps1'
$plYmlPath  = Join-Path $PluginRoot 'templates\asana-prio-label.yml'
foreach ($rel in @('templates\asana-prio-label.yml', 'templates\asana-prio-label.ps1')) {
    Assert-True (Test-Path -LiteralPath (Join-Path $PluginRoot $rel)) "ships $rel"
}
. $plTemplate

# THE MAPPING: closed at the bottom, open at the top, and nothing outside 1.00-5.00.
$plBands = @(
    @(1, 'prio-1'), @(1.99, 'prio-1'), @(2, 'prio-2'), @(2.99, 'prio-2'),
    @(3, 'prio-3'), @(3.99, 'prio-3'), @(4, 'prio-4'), @(5, 'prio-4'))
foreach ($b in $plBands) {
    Assert-Equal $b[1] (Get-PrioLabelForScore -Score $b[0]) "score $($b[0]) is $($b[1])"
}
foreach ($bad in @(0.99, 5.01, 0, -1)) {
    Assert-True ($null -eq (Get-PrioLabelForScore -Score $bad)) "score $bad names no label"
}
Assert-True ($null -eq (Get-PrioLabelForScore -Score $null)) 'a null score names no label'
Assert-Equal 'prio-2' (Get-PrioLabelForScore -Score '2.5') 'a score handed over as text is read as a number'

# THE SCORE IS FOUND BY NAME.
$plTask = [pscustomobject]@{ custom_fields = @(
    [pscustomobject]@{ name = 'Effort'; number_value = 9 },
    [pscustomobject]@{ name = 'Prio-Score'; number_value = 3.5 }) }
Assert-Equal 3.5 (Get-PrioScoreFromTask -Task $plTask -FieldName 'Prio-Score') 'the field is matched by name, not by position'
Assert-Equal 9 (Get-PrioScoreFromTask -Task $plTask -FieldName 'Effort') 'and any other name finds its own field'
Assert-True ($null -eq (Get-PrioScoreFromTask -Task $plTask -FieldName 'Missing')) 'a task without that field reads as unscored'
Assert-True ($null -eq (Get-PrioScoreFromTask -Task ([pscustomobject]@{ gid = '1' }) -FieldName 'Prio-Score')) 'a task with no custom_fields reads as unscored'
Assert-True ($null -eq (Get-PrioScoreFromTask -Task ([pscustomobject]@{ custom_fields = @() }) -FieldName 'Prio-Score')) 'and so does one with an empty field list'
Assert-True ($null -eq (Get-PrioScoreFromTask -Task $null -FieldName 'Prio-Score')) 'a null task reads as unscored'
$plEmpty = [pscustomobject]@{ custom_fields = @([pscustomobject]@{ name = 'Prio-Score'; number_value = $null }) }
Assert-True ($null -eq (Get-PrioScoreFromTask -Task $plEmpty -FieldName 'Prio-Score')) 'a field present with no value reads as unscored'

# WHAT CHANGES ON THE ISSUE: exactly one prio label, nothing else touched.
$c = Get-PrioLabelChange -Label 'prio-3' -Current @('bug')
Assert-Equal 'prio-3' $c.Add 'a missing label is added'
Assert-Equal 0 @($c.Remove).Count 'and nothing is removed when no other prio label is there'
$c = Get-PrioLabelChange -Label 'prio-3' -Current @('bug', 'prio-1', 'prio-4')
Assert-Equal 'prio-3' $c.Add 'a rescored issue gets the new label'
Assert-Equal 'prio-1,prio-4' (@($c.Remove) -join ',') 'and loses every OTHER prio-N'
$c = Get-PrioLabelChange -Label 'prio-3' -Current @('prio-3', 'bug')
Assert-True ($null -eq $c.Add) 'an issue already carrying the label adds nothing'
Assert-Equal 0 @($c.Remove).Count 'and removes nothing: a re-run is quiet'
$c = Get-PrioLabelChange -Label $null -Current @('prio-1', 'prio-2')
Assert-True ($null -eq $c.Add -and @($c.Remove).Count -eq 0) 'no label (no score) changes nothing -- a hand-set label survives'
$c = Get-PrioLabelChange -Label 'prio-2' -Current @('bug', 'priority-high', 'Prio-1', 'awaiting-info-client')
Assert-Equal 0 @($c.Remove).Count 'labels outside the four-name set are never removed (nor are other-case lookalikes)'
$c = Get-PrioLabelChange -Label 'bug' -Current @('prio-1')
Assert-True ($null -eq $c.Add -and @($c.Remove).Count -eq 0) 'a label outside the four-name set is refused, so gh is never handed another label'
$c = Get-PrioLabelChange -Label 'prio-2' -Current @()
Assert-Equal 'prio-2' $c.Add 'an issue with no labels at all gets the label'

# THE COPIED HELPERS EQUAL THEIR SOURCE. The function text is taken by AST from each file, minus its
# leading help comment, because the copies carry their own 'a copy of ...' sentence there.
function Get-FunctionSourceText {
    param([string]$Path, [string]$Name)
    $tokens = $null; $errs = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errs)
    $fn = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name }, $true)
    if (-not $fn) { return $null }
    $text = $fn.Extent.Text -replace "`r`n", "`n"
    return ([regex]::Replace($text, '(?s)<#.*?#>', '', 1) -replace '\s+', ' ').Trim()
}
$plLib = Join-Path $PluginRoot 'scripts\lib\asana-task-lib.ps1'
foreach ($fn in @('Get-AsanaGidsFromText', 'Get-AsanaHeaderRowText', 'Resolve-AsanaTaskRef')) {
    $mine = Get-FunctionSourceText -Path $plTemplate -Name $fn
    Assert-True ($null -ne $mine) "the prio template defines $fn"
    Assert-Equal (Get-FunctionSourceText -Path $plLib -Name $fn) $mine "$fn equals asana-task-lib.ps1's, apart from its help comment"
    Assert-Equal (Get-FunctionSourceText -Path $cmTemplate -Name $fn) $mine "and equals asana-closed-message.ps1's"
}
$plGh = Get-FunctionSourceText -Path $plTemplate -Name 'Invoke-GhCapture'
Assert-True ($null -ne $plGh) 'the prio template defines Invoke-GhCapture'
Assert-Equal (Get-FunctionSourceText -Path $cmTemplate -Name 'Invoke-GhCapture') $plGh 'Invoke-GhCapture equals asana-closed-message.ps1''s'
# #2968: the freshness judgement is copied into the template as well, and held equal to the lib's.
foreach ($fn in @('ConvertTo-AsanaInstant', 'Test-AsanaPasteBlockBody', 'Get-AsanaPasteBlockVerdict', 'Get-PasteBlockSections', 'Get-AsanaResearchBlockMarker', 'Get-AsanaReleaseBlockMarker', 'Get-AsanaMeasureBlockMarker', 'Get-AsanaHandBlockMarker', 'Get-AsanaAlreadyFixedBlockMarker')) {
    $mine = Get-FunctionSourceText -Path $cmTemplate -Name $fn
    Assert-True ($null -ne $mine) "the closed-message template defines $fn"
    Assert-Equal (Get-FunctionSourceText -Path $plLib -Name $fn) $mine "$fn equals asana-task-lib.ps1's, apart from its help comment"
}
# #3070: the live message escapes its html_text by the closed message's rule, copied because the template ships standalone.
Assert-Equal (Get-FunctionSourceText -Path $cmTemplate -Name 'ConvertTo-AsanaXmlText') (Get-FunctionSourceText -Path (Join-Path $PluginRoot 'scripts\lib\live-message-rules.ps1') -Name 'ConvertTo-AsanaXmlText') `
    'live-message-rules.ps1''s ConvertTo-AsanaXmlText equals the closed-message template''s, apart from its help comment'
# And the loaded matchers answer as the lib's did (the lib's answers were taken before either template loaded).
Assert-Equal ($cmLibRefs -join ';') (@($cmSamples | ForEach-Object { $r = Resolve-AsanaTaskRef -IssueBody $_; "$($r.Gid)|$($r.Source)" }) -join ';') 'the prio template''s matchers answer as the lib''s on every matcher shape'

# THE SCRIPT'S SHAPE: one GitHub write, no Asana write, and a non-numeric GID never reaches a URL.
$plSrc = [System.IO.File]::ReadAllText($plTemplate)
Assert-True ($plSrc -notmatch '-Method\s+(POST|PUT|PATCH|DELETE)') 'the template never writes to Asana'
Assert-Equal 1 ([regex]::Matches($plSrc, '(?m)^\s*\$resp = Invoke-RestMethod\b')).Count 'and makes exactly one HTTP call (a GET)'
Assert-True ($plSrc -match "'issue', 'edit'" -and $plSrc -notmatch "'issue', 'comment'|'issue', 'close'|gh label") 'its one GitHub write is gh issue edit'
Assert-Throws { Get-AsanaTaskScoreUri -Gid '123; rm -rf /' } 'a non-numeric GID never reaches a request URL'
Assert-Throws { Get-AsanaTaskScoreUri -Gid "123`n" } 'a GID with a trailing newline is refused'
Assert-True ((Get-AsanaTaskScoreUri -Gid '123') -match '^https://app\.asana\.com/api/1\.0/tasks/123\?') 'a numeric GID builds the task read'

# HOW A FAILED TASK READ IS TREATED: only a 404 is a quiet skip; everything else fails the run.
Assert-Equal 'skip' (Get-AsanaReadOutcome -Status 404) 'a 404 (task gone) is a skip'
foreach ($st in @(401, 403, 429, 500, 502, 503, 599, 0, $null)) {
    Assert-Equal 'failed' (Get-AsanaReadOutcome -Status $st) "status '$st' fails the run"
}

# THE ISSUE LISTING PARSE, including the PS 5.1 nested-array case (a parsed '[]' arriving as ONE object).
Assert-Equal 0 @(ConvertFrom-IssueListJson -Text '').Count 'an empty listing text is no issues'
Assert-Equal 0 @(ConvertFrom-IssueListJson -Text '   ').Count 'so is whitespace'
Assert-Equal 0 @(ConvertFrom-IssueListJson -Text '[]').Count 'and so is [] -- not one phantom element, on 5.1 or 7'
$plList = @(ConvertFrom-IssueListJson -Text '[{"number":1,"body":"a","labels":[]},{"number":2,"body":"b","labels":[{"name":"bug"}]}]')
Assert-Equal 2 $plList.Count 'two issues parse into two elements'
Assert-Equal 2 $plList[1].number 'each element is an issue object'
Assert-Equal 'bug' $plList[1].labels[0].name 'with its labels'
Assert-Equal 1 @(ConvertFrom-IssueListJson -Text '[{"number":7,"body":null,"labels":[]}]').Count 'a single-issue listing is a list of one'
Assert-Equal 7 (@(ConvertFrom-IssueListJson -Text '[{"number":7,"body":null,"labels":[]}]'))[0].number 'whose element is the issue, not the array'

# THE SWEEP'S SHAPE: lists up to 1000 and raises a warning annotation at the cap.
Assert-True ($plSrc -match '\$limit\s*=\s*1000\b') 'the sweep''s limit is 1000'
Assert-True ($plSrc -match "'issue', 'list'[^\r\n]*'--limit', `"\`$limit`"") 'and gh issue list is given that limit'
Assert-True ($plSrc -match '\$issues\.Count -ge \$limit' -and $plSrc -match 'Write-Host "::warning::') 'reaching the cap emits a ::warning:: annotation'

# NO ASANA_PAT: said, and not a failure. Run in a child so nothing here reads the real environment.
$plSavedPat = $env:ASANA_PAT; $plSavedBody = $env:ISSUE_BODY
try {
    $env:ASANA_PAT = ''; $env:ISSUE_BODY = ''
    $plOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $plTemplate -Mode sweep 2>&1 | ForEach-Object { "$_" }
    Assert-Equal 0 $LASTEXITCODE 'with no ASANA_PAT the sweep exits 0'
    Assert-True (($plOut -join "`n") -match 'ASANA_PAT is not set') 'and says why'
    $plOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $plTemplate -Mode event -IssueRef 'o/r#1' 2>&1 | ForEach-Object { "$_" }
    Assert-Equal 0 $LASTEXITCODE 'and so does an event run'
} finally { $env:ASANA_PAT = $plSavedPat; $env:ISSUE_BODY = $plSavedBody }

# THE WORKFLOW.
$plYml = [System.IO.File]::ReadAllText($plYmlPath)
Assert-True ($plYml -match 'types:\s*\[opened,\s*edited\]') 'the workflow runs on an issue opened or edited'
Assert-True ($plYml -notmatch '(?m)^\s*types:.*\b(labeled|unlabeled)\b') 'and never on labeled or unlabeled, so a label change never wakes it'
Assert-True ($plYml -match '(?m)^\s*schedule:' -and $plYml -match 'cron:\s*"[^"]+"') 'it has a daily sweep schedule'
Assert-True ($plYml -match '(?m)^\s*workflow_dispatch:') 'and a manual dispatch'
Assert-True ($plYml -notmatch '(?m)^\s*(pull_request|pull_request_target|push|issue_comment):') 'with no other trigger'
$plPermBlock = [regex]::Match($plYml, '(?ms)^permissions:\s*\r?\n((?:[ \t]+[^\r\n]*\r?\n|[ \t]*\r?\n)+)').Groups[1].Value
$plPerms = @([regex]::Matches($plPermBlock, '(?m)^\s+([a-z-]+):\s*(\S+)') | ForEach-Object { "$($_.Groups[1].Value)=$($_.Groups[2].Value)" } | Sort-Object)
Assert-Equal 'contents=read,issues=write' ($plPerms -join ',') 'the token holds issues: write and contents: read, and nothing else'
Assert-True ($plYml -match '(?m)^\s*timeout-minutes:\s*\d+') 'the job has a timeout (#2296)'
Assert-True ($plYml -match 'persist-credentials:\s*false') 'the checkout leaves no token behind'
$plSecrets = @([regex]::Matches($plYml, 'secrets\.([A-Za-z0-9_]+)') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
Assert-Equal 'ASANA_PAT' ($plSecrets -join ',') 'ASANA_PAT is the only secret'
Assert-True ($plYml -match 'ISSUE_BODY:\s*\$\{\{\s*github\.event\.issue\.body\s*\}\}') 'the issue body reaches the script through the environment'
$plRun = [regex]::Match($plYml, '(?ms)^\s*run:\s*\|\s*\r?\n(.*)\z').Groups[1].Value
Assert-True ($plRun -ne '') 'the run block was found'
Assert-True ($plRun -notmatch '\$\{\{') 'and no expression is interpolated inside run:'
Assert-True ($plYml -notmatch '-IssueBody') 'the body is never on the command line'

# --- done ---------------------------------------------------------------------------------------
Write-Host ""
if (Write-FixtureGitSummary -Subject 'build-golive-block.ps1') { $script:fail++ }
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
