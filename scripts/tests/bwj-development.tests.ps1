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
foreach ($skill in @('report-issue', 'adopt-bwj-development', 'golive-block', 'prepare-release')) {
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
Assert-Equal 'GitHub issue [BWJ-Development/smartwatchbanden#500](https://github.com/BWJ-Development/smartwatchbanden/issues/500) is now **closed**. It can be reopened anytime when something is still not working as expected.' `
    $glPastedLines[2] 'then the closed line, the issue name a link and the verb bold -- the requester''s form'
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

# A LINK THE REQUESTER CANNOT OPEN IS REFUSED (#2341): a claude.ai Artifact is private to its owner, and
# the handover page is the reviewer's surface. Both published shapes, and nothing that merely resembles one.
Assert-True (Test-PrivateResultLink -Link 'https://claude.ai/artifact/abc123') 'a claude.ai/artifact link is private'
Assert-True (Test-PrivateResultLink -Link 'https://claude.ai/code/artifact/0f1e-uuid') 'a claude.ai/code/artifact link is private'
Assert-True (Test-PrivateResultLink -Link 'HTTPS://Claude.AI/artifact/abc') 'case does not change the answer'
Assert-True (-not (Test-PrivateResultLink -Link 'https://store.example/products/foo?preview_theme_id=1&_ab=0&_fd=0&_sc=1')) 'a storefront preview URL is openable'
Assert-True (-not (Test-PrivateResultLink -Link 'https://store.example/pages/claude.ai/artifact/x')) 'a path that merely contains the shape is not refused'
Assert-True (-not (Test-PrivateResultLink -Link '')) 'no link is not a private link'

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
    'Management sees it. After the release nobody has to do anything here.', '', '**Score:** 2', '',
    '#### Pull Request', '', 'x', '', '---', '',
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

# THE OBLIGATIONS: the entry's own text only, one row per sentence, and never a skill NAME.
$prObl = @(Get-GoLiveObligations -Entries $prEntries)
Assert-Equal 2 $prObl.Count 'two obligations -- the reach section''s "after the release" and the golive-block name are not'
Assert-True ($prObl[0].Sentence -eq 'Once this is live, stop Convert experience 1004205630.') 'the sentence is returned whole, markdown stripped'
Assert-Equal 'fix/13-cart-bug' $prObl[1].Branch '...each under the entry it came from'
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
$prCtl = @([pscustomobject]@{ Branch = 'feat/1-x'; Sentence = "Once live, stop it.$([char]27)[2J" })
Assert-True (-not ((Format-ReleaseRunbook -Obligations $prCtl) -join "`n").Contains([char]27)) 'entry prose reaches the runbook with its control characters stripped'

# THE DRIVER, STATICALLY: it runs no theme write and reads no marker, and it refuses in this source repo.
$prDriver = [System.IO.File]::ReadAllText((Join-Path $PluginRoot 'scripts\task\prepare-release.ps1'))
Assert-True ($prDriver -notmatch "(?m)^[^#]*\b(theme',\s*'(push|publish|delete|duplicate)|shopify theme (push|publish|delete))") 'the driver invokes no theme push, publish, delete or duplicate'
Assert-True ($prDriver -notmatch 'Get-ShopifyLivePushMarker|LIVE-PUSH-AUTHORIZED') 'the driver never reads the authorisation marker'
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
        "function Get-RepoName { 'fixture/prepare-release-2565' }"
    ) -join "`n"))
    $prSeamRun = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PluginRoot 'scripts\task\prepare-release.ps1') -RootOverride $prRoot -SkipDrift 2>&1) | ForEach-Object { "$_" }) -join "`n"
    Assert-True $prSeamRun.Contains('seam-fixture-2565.myshopify.com') 'the store domain is read from the repo''s own seam, not defaulted'
    Assert-True $prSeamRun.Contains("no changelog at 'seam-fixture/CHANGELOG-2565.md'") 'the changelog path is read from the repo''s own seam, not defaulted'

    # A FAULTY CONFIG DEGRADES, and names the exception's type rather than the consumer's own text (#2509).
    [System.IO.File]::WriteAllText((Join-Path $prRoot 'scripts\repo-config.ps1'), "throw 'consumer-secret-text-2565'")
    $prBadRun = (@(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PluginRoot 'scripts\task\prepare-release.ps1') -RootOverride $prRoot -SkipDrift 2>&1) | ForEach-Object { "$_" }) -join "`n"
    Assert-True $prBadRun.Contains('[8/8]') 'a repo-config that throws does not take the run down'
    Assert-True $prBadRun.Contains('scripts/repo-config.ps1 threw') '...it is named as the file that threw'
    Assert-True (-not $prBadRun.Contains('consumer-secret-text-2565')) '...and its own message never reaches the output'
} finally {
    if (Test-Path -LiteralPath $prRoot) { Remove-Item -LiteralPath $prRoot -Recurse -Force -ErrorAction SilentlyContinue }
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
Assert-True (-not (Get-ClosedMessageDecision -StateReason 'duplicate' -IssueBody $cmSamples[0] -Labels @('awaiting-more-info')).Post) 'not even one still carrying awaiting-more-info'
Assert-Equal 'closed' (Get-ClosedMessageDecision -StateReason 'completed' -IssueBody $cmSamples[0]).Kind 'a close as completed is the closed message'

# THE ON-HOLD MESSAGE (#2902): not planned with awaiting-more-info kept on is the parked-while-waiting pair.
$cmHold = Get-ClosedMessageDecision -StateReason 'not_planned' -IssueBody $cmSamples[0] -Labels @('bug', 'awaiting-more-info')
Assert-True $cmHold.Post 'a close as not planned with awaiting-more-info kept on posts'
Assert-Equal 'on-hold' $cmHold.Kind 'and it is the on-hold message, not the closed one'
Assert-Equal '1234' $cmHold.Gid 'to the task the marker names'
Assert-True (-not (Get-ClosedMessageDecision -StateReason 'not_planned' -IssueBody $cmSamples[4] -Labels @('awaiting-more-info')).Post) 'with no linked task it posts nothing'
Assert-Equal 'closed' (Get-ClosedMessageDecision -StateReason 'completed' -IssueBody $cmSamples[0] -Labels @('awaiting-more-info')).Kind 'a close as completed stays the closed message, whatever the labels'
Assert-Equal 'reopened' (Get-ClosedMessageDecision -Event 'reopened' -IssueBody $cmSamples[0] -Labels @('awaiting-more-info')).Kind 'and a reopen stays the reopened message'
Assert-True (Get-ClosedMessageDecision -StateReason 'not_planned' -IssueBody $cmSamples[0] -Labels @('Awaiting-More-Info')).Post 'the label is matched whatever its case'
Assert-Equal 'bug, with comma|awaiting-more-info' ((ConvertFrom-IssueLabelList -Text "[`n  `"bug, with comma`",`n  `"awaiting-more-info`"`n]") -join '|') 'the workflow''s toJSON labels parse into names, a comma inside a name kept'
Assert-Equal 'awaiting-more-info' ((ConvertFrom-IssueLabelList -Text '["awaiting-more-info"]') -join '|') 'and a single label is a list of one'
Assert-Equal 0 @(ConvertFrom-IssueLabelList -Text '').Count 'an empty ISSUE_LABELS -- a workflow copied before #2902 -- is no labels'
Assert-Equal 0 @(ConvertFrom-IssueLabelList -Text '[]').Count 'and so is an issue without labels'
Assert-Equal 0 @(ConvertFrom-IssueLabelList -Text 'bug,awaiting-more-info').Count 'and a value that is not JSON is no labels, so the close stays silent'
$cmHoldHtml = New-OnHoldMessageHtml -IssueRef 'BWJ-Development/smartwatchbanden#882'
$cmHoldXml = New-Object System.Xml.XmlDocument
$cmHoldXml.PreserveWhitespace = $true
$cmHoldXml.LoadXml($cmHoldHtml)
Assert-True ($cmHoldXml.DocumentElement.InnerText -ceq (New-OnHoldMessage -IssueRef 'BWJ-Development/smartwatchbanden#882')) 'the on-hold message is well-formed XML and reads as the plain on-hold message'
Assert-True ($cmHoldHtml.Contains('<a href="https://github.com/BWJ-Development/smartwatchbanden/issues/882">BWJ-Development/smartwatchbanden#882</a> <strong>is on hold:</strong> it is closed as not planned')) 'the issue as a link, is on hold: in bold, the reopened line''s form'
Assert-True ($cmHoldHtml.StartsWith("<body>$(Get-ClosedMessageHeader)")) 'under the same header as the closed message'
Assert-True (-not $cmHoldHtml.Contains('is now <strong>closed</strong>')) 'and never the closed line, which a waiting requester reads as finished'
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
Assert-True ($cmReopen.Contains('<a href="https://github.com/BWJ-Development/smartwatchbanden/issues/393">BWJ-Development/smartwatchbanden#393</a> <strong>is reopened:</strong> this Asana task is now back in development.')) 'in the requester''s fixed form (#2656): the issue as a link, is reopened: in bold'
Assert-True ($cmReopen.StartsWith("<body>$(Get-ClosedMessageHeader)")) 'under the same header as the closed message'

# WHAT IT POSTS: the header, the closed line, and the block's sections under it.
$cmSections = Select-SessionPasteBlockSections -Bodies @('first', $goLiveBlock)
Assert-True ($cmSections.StartsWith('TE BEKIJKEN OP')) 'the carried sections start at the first heading -- the header and closed line are the message''s own'
Assert-True ($cmSections -notmatch 'GitHub automation|is now \*\*closed') 'so neither arrives twice'
Assert-Equal '' (Select-SessionPasteBlockSections -Bodies @('first', 'no block here')) 'an issue with no block carries no sections'
$cmQuestion = "Wat we van je vragen: 1. Een tijdstip.`n`n$cmLibMarker"
Assert-Equal $cmSections (Select-SessionPasteBlockSections -Bodies @($goLiveBlock, $cmQuestion)) 'an awaiting-more-info question carries the marker but no rules, so the block before it is still the one carried'
$cmHtml = New-ClosedMessageHtml -IssueRef 'BWJ-Development/smartwatchbanden#500' -BlockSections $cmSections
$cmXml  = [xml]$cmHtml
Assert-True ($cmXml.body.InnerText.StartsWith((New-ClosedMessage -IssueRef 'BWJ-Development/smartwatchbanden#500'))) 'the message is well-formed XML and opens with the plain closed message'
Assert-True ($cmHtml.Contains('<a href="https://github.com/BWJ-Development/smartwatchbanden/issues/500">BWJ-Development/smartwatchbanden#500</a> is now <strong>closed</strong>')) 'the issue name is a link and closed is bold -- the requester''s form'
Assert-True ($cmHtml.Contains('<strong>TE BEKIJKEN OP</strong>')) 'the headings arrive bold'
Assert-True ($cmHtml.Contains("`n`n<strong>WAT ER NU ANDERS IS</strong>`n`n")) 'and the line breaks arrive as written'
Assert-Equal '<a href="https://x.invalid/?a=1&amp;b=2">t</a> en <strong>vet</strong> &amp; meer' (ConvertTo-AsanaStoryHtml -Markdown '[t](https://x.invalid/?a=1&b=2) en **vet** & meer') 'Markdown links and bold convert, and everything else is escaped'
$cmBare = New-ClosedMessageHtml -IssueRef 'o/r#1'
Assert-True ($cmBare -cnotmatch '<strong>[A-Z ]+</strong>') 'with no block the header and the closed line go out alone (#2818, item 3)'
[void][xml]$cmBare
Assert-True ((New-ClosedMessageHtml -IssueRef 'o/r&x#1') -match '&amp;') 'a character XML reserves is escaped, so Asana is never sent a malformed body'
Assert-Throws { New-AsanaCommentRequest -Gid '123; rm -rf /' -Html '<body/>' } 'a non-numeric GID never reaches a request URL'
$cmReq = New-AsanaCommentRequest -Gid '123' -Html '<body>x</body>'
Assert-Equal 'https://app.asana.com/api/1.0/tasks/123/stories' $cmReq.Uri 'the one write is a story on the task'
Assert-True ($cmReq.Body -match '"html_text"') 'posted as html_text'

# WHAT IT NEVER DOES: no write but the comment, no card, no completion, no label, no other event.
$cmSrc = [System.IO.File]::ReadAllText($cmTemplate)
Assert-True ($cmSrc -notmatch "completed\s*=\s*\`$true|addProject|/sections/|gh issue edit|gh label") 'the template carries no completion, card move or label write'
# THE STRUCTURAL HALF (code review): one HTTP call site, and the request it sends is New-AsanaCommentRequest's.
Assert-Equal 1 ([regex]::Matches($cmSrc, '(?m)^\s*Invoke-RestMethod\b')).Count 'the template makes exactly one HTTP call'
Assert-True ($cmSrc -match '\$request\s*=\s*New-AsanaCommentRequest' -and $cmSrc -match 'Invoke-RestMethod -Method \$request\.Method -Uri \$request\.Uri') 'and that call sends the one request New-AsanaCommentRequest builds'

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
Assert-Equal 'api|repos/BWJ-Development/xoxowildhearts/issues/383/comments|--paginate|--jq|.[] | {author_association, login: .user.login, body}' ($cmArgs -join '|') `
    'the comments are read through REST, every page, one JSON object per comment per line, with the author''s login'
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
Assert-Equal 'without a go-live block -- one was on the issue but its author was not trusted (the reason is above)' (Get-ClosedMessageBlockPhrase -Sections '' -ReadOk $true -Dropped 1) 'a dropped block is never logged as none on the issue'
$cmPermArgs = Get-CollaboratorPermissionApiArgs -IssueRef 'BWJ-Development/smartwatchbanden#884' -Login 'maikel-bwj'
Assert-Equal 'api|repos/BWJ-Development/smartwatchbanden/collaborators/maikel-bwj/permission|--jq|.permission' ($cmPermArgs -join '|') 'the permission is read through REST, the legacy base role alone'
Assert-Throws { Get-CollaboratorPermissionApiArgs -IssueRef 'o/r#1' -Login '../x' } 'and a login that is not a user login never reaches the request path'
Assert-True ($cmSrc -match 'Get-ClosedMessageBlockPhrase -Sections \$sections -ReadOk \$read\.Ok -Dropped \$dropped') 'the final log line knows about a drop'
Assert-Throws { ConvertFrom-IssueCommentLines -Lines @('[{"author_association":"MEMBER"') } 'a garbled line throws, so it is reported as a failed read rather than as no block'
Assert-Equal "with the session's go-live block" (Get-ClosedMessageBlockPhrase -Sections 'X' -ReadOk $true) 'the log says a block was carried when one was'
Assert-Equal 'without a go-live block -- none was on the issue' (Get-ClosedMessageBlockPhrase -Sections '' -ReadOk $true) 'it says none was on the issue only after a read that worked'
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

# --- done ---------------------------------------------------------------------------------------
Write-Host ""
if (Write-FixtureGitSummary -Subject 'build-golive-block.ps1') { $script:fail++ }
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
