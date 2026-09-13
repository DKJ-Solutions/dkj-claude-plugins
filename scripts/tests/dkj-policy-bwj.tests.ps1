<#
.SYNOPSIS
    Regression tests for the dkj-policy-bwj plugin: its structure, its marketplace registration, and
    the pure helpers of the asana-mirror CI script it ships as a template.

.DESCRIPTION
    Dependency-free: no Pester, only PowerShell. Exit 0 if everything passes, 1 on a failure.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/dkj-policy-bwj.tests.ps1

    The asana-mirror helpers are exercised by dot-sourcing the template: it runs its main flow only
    when invoked directly, so a dot-source loads the functions and does nothing else.

    Pure ASCII (repo convention for .ps1).
#>

# Test-FunctionDefined (issue #1729): the retirement asserts below ask the function table directly
# rather than through Get-Command, whose miss path -- the case every one of those asserts is in --
# scans the whole PATH for an executable of that name.
. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')
$ErrorActionPreference = 'Stop'
$RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$PluginRoot = Join-Path $RepoRoot 'plugins\dkj-policy\dkj-policy-bwj'

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
Assert-Equal 'dkj-policy-bwj' $manifest.name 'plugin.json name is dkj-policy-bwj'

foreach ($rel in @('README.md', 'WORKFLOW-portable.md', 'SYNC-LOG-portable.md', 'PREVIEW-portable.md',
                   'skills\report-issue\SKILL.md', 'skills\adopt-dkj-policy-bwj\SKILL.md',
                   'templates\asana-mirror.yml', 'templates\asana-mirror.ps1')) {
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
Assert-Equal 3 $chapterDocs.Count 'the plugin ships three chapter pages'
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
foreach ($skill in @('report-issue', 'adopt-dkj-policy-bwj')) {
    $txt = Get-Content -LiteralPath (Join-Path $PluginRoot "skills\$skill\SKILL.md") -Raw
    $nm  = [regex]::Match($txt, '(?m)^name:\s*(\S+)\s*$')
    Assert-Equal $skill $nm.Groups[1].Value "skill '$skill' frontmatter name matches its folder"
}

# --- 2. Marketplace registration + lockstep version --------------------------------------------
Write-Host "`n-- marketplace --" -ForegroundColor Cyan

$marketplace = Get-Content -LiteralPath (Join-Path $RepoRoot '.claude-plugin\marketplace.json') -Raw | ConvertFrom-Json
$entry = $marketplace.plugins | Where-Object { $_.name -eq 'dkj-policy-bwj' }
Assert-True ($null -ne $entry) 'dkj-policy-bwj is listed in marketplace.json'
Assert-Equal './plugins/dkj-policy/dkj-policy-bwj' $entry.source 'marketplace source points at the plugin folder'

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

# --- 3. asana-mirror pure helpers ------------------------------------------------------------------
Write-Host "`n-- asana-mirror helpers --" -ForegroundColor Cyan

. (Join-Path $PluginRoot 'templates\asana-mirror.ps1')

# GID extraction
Assert-Equal '1201234567890123' (Get-AsanaTaskGid -IssueBody "text`n<!-- asana-task: 1201234567890123 -->`nmore") 'Get-AsanaTaskGid reads the marker'
Assert-Equal '1201234567890123' (Get-AsanaTaskGid -IssueBody '<!--asana-task:1201234567890123-->') 'Get-AsanaTaskGid tolerates no inner spaces'
Assert-True  ($null -eq (Get-AsanaTaskGid -IssueBody 'no marker here')) 'Get-AsanaTaskGid returns null when absent'
Assert-True  ($null -eq (Get-AsanaTaskGid -IssueBody '<!-- asana-task: not-a-number -->')) 'Get-AsanaTaskGid rejects a non-numeric marker'
Assert-True  ($null -eq (Get-AsanaTaskGid -IssueBody '')) 'Get-AsanaTaskGid handles an empty body'


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
Assert-Equal '111' (Get-AsanaTaskGid -IssueBody $sibling) 'the header row wins over a sibling link further down'

# the marker wins over everything, so an issue that carries one is never re-matched
$both = "| **Asana** | [a](https://app.asana.com/1/9/project/8/task/111) |`n<!-- asana-task: 999 -->"
Assert-Equal 'marker' (Resolve-AsanaTaskRef -IssueBody $both).Source 'the marker outranks the header row'
Assert-Equal '999'    (Get-AsanaTaskGid    -IssueBody $both)        'and it is the marker GID that is used'

# matcher 3 -- a single Asana task URL anywhere, in either URL shape Asana hands out
Assert-Equal '1216905543348385' (Get-AsanaTaskGid -IssueBody 'see https://app.asana.com/1/9/project/8/task/1216905543348385') 'a sole modern task URL resolves'
Assert-Equal '1216905543348385' (Get-AsanaTaskGid -IssueBody 'see https://app.asana.com/0/1214594032889511/1216905543348385/f') 'a sole classic task URL resolves'
Assert-Equal 'sole-url'         (Resolve-AsanaTaskRef -IssueBody 'https://app.asana.com/1/9/project/8/task/77').Source 'and reports sole-url as the source'

# several DIFFERENT tasks and no marker -- reported, never guessed
$ambiguous = Resolve-AsanaTaskRef -IssueBody 'a https://app.asana.com/1/9/project/8/task/111 b https://app.asana.com/1/9/project/8/task/222'
Assert-True  ($null -eq $ambiguous.Gid)   'two different linked tasks resolve to nothing'
Assert-Equal 'ambiguous' $ambiguous.Source 'and are reported as ambiguous'
Assert-Equal 2 $ambiguous.Candidates.Count 'with both candidates named for the log'

# the same task linked twice is not ambiguous
Assert-Equal '111' (Get-AsanaTaskGid -IssueBody 'a https://app.asana.com/1/9/project/8/task/111 b https://app.asana.com/1/9/project/8/task/111') 'the same task linked twice still resolves'

# a project link names no task
Assert-True ($null -eq (Get-AsanaTaskGid -IssueBody 'board: https://app.asana.com/1/9/project/8')) 'a project link contributes no task GID'

# a non-numeric task GID can never reach a request URL
Assert-Throws { Get-AsanaTaskState -Gid 'abc' -Pat 'x' } 'Get-AsanaTaskState throws on a non-numeric GID'

# THE CENTRAL GUARANTEE (Dave, 2026-09-01): automation never resolves a mirrored ticket -- the
# colleague who filed it does, after testing. So the script must carry no way to write 'completed'
# at all. This is asserted over the source text rather than over behaviour, because the guarantee is
# the ABSENCE of a code path and no call can demonstrate an absence.
$mirrorSrc = Get-Content -LiteralPath (Join-Path $PluginRoot 'templates\asana-mirror.ps1') -Raw
Assert-True (-not (Test-FunctionDefined 'New-AsanaCompleteRequest')) 'no request builder for completing a task exists'
Assert-True (-not (Test-FunctionDefined 'Set-AsanaTaskCompleted')) 'no helper for completing a task exists'
Assert-True ($mirrorSrc -notmatch "completed\s*=\s*\`$(true|false)") 'the script never builds a completed=true/false payload'
Assert-True ($mirrorSrc -notmatch "(?m)^\s*[^#]*-Method\s+PUT")      'the script issues no PUT at all -- the only write it knows is a comment'

# THE CI HALF NEEDS NO WORKSPACE (#1210): every call it makes addresses a task or a project by GID,
# so the parameter it used to declare had no reader, while the yml handed BOTH steps a variable
# nothing consumed -- which reads as a possible cause the next time a sweep reports 0 updated.
# Asserted over the source text and over the workflow, because this too is the absence of a thing.
$mirrorYml = Get-Content -LiteralPath (Join-Path $PluginRoot 'templates\asana-mirror.yml') -Raw
Assert-True ($mirrorSrc -notmatch 'WorkspaceGid')        'the script declares no workspace parameter'
Assert-True ($mirrorYml -notmatch 'ASANA_WORKSPACE_GID') 'and the workflow hands neither step a workspace variable'
Assert-True ($mirrorYml -match 'ASANA_PROJECT_GID')      'while the project variable it does read is still passed'

# THE CONCURRENCY GROUP IS SPLIT BY WHAT AN ARRIVAL CAN LOSE (#1301). One group per issue put the
# `closed`/`reopened` runs -- the only ones whose work is keyed on the event rather than recomputed
# from live state -- in the same queue as a triage burst, and a group drops its PENDING run without
# consulting `cancel-in-progress`. A dropped `reopened` is unrecoverable: no sweep comments on a
# reopen, and it is the only thing that sets AllowBackward while every sweep moves forward only.
# Asserted over the yml text because the defect is a group two kinds of event SHARE -- there is no
# helper to call, and the collapse back to one key is a one-line edit that changes nothing visible.
Assert-True ($mirrorYml -match "(?m)^\s*group:\s*asana-mirror-.*github\.event\.issue\.number") 'the concurrency group is still keyed per issue'
Assert-True ($mirrorYml -match "(?m)^\s*group:.*github\.event\.action\s*==\s*'closed'")   "and the group key separates 'closed'"
Assert-True ($mirrorYml -match "(?m)^\s*group:.*github\.event\.action\s*==\s*'reopened'") "and 'reopened' from the label events, so a triage burst cannot displace one"
Assert-True ($mirrorYml -match "(?m)^\s*cancel-in-progress:\s*false") 'while a run already going is still never killed'

# AND THE BLOCK STATES WHAT THE SPLIT COSTS (#1306). Two groups mean a `state` run and a `triage` run
# on ONE issue can overlap, where one group serialised them -- and Sync-AsanaTaskStage has no
# compare-and-set, so the later write wins whichever event was later. The split is still the better
# side of the trade, so the first three asserts pin that the comment SAYS SO: it is a property no
# reader can see in the key itself, and the previous comment was convincing while naming only the
# half that improved.
Assert-True ($mirrorYml -like '*#1306*')          'the block cites the issue for the cost the split carries'
Assert-True ($mirrorYml -like '*CONCURRENTLY*')   'and states that a state run and a triage run can overlap on one issue'
Assert-True ($mirrorYml -like '*sweep (d)*')      'and names the sweep that recovers the one case where that loses'

# The three above are claims about the COMMENT; the two below are the mechanism the comment PROMISES.
# Sweep (d) only re-derives a needs-info hold because it passes -Labels into Resolve-TargetStage, and
# dropping that argument would leave the block above describing a backstop that no longer exists --
# silently, since a card left at its forward floor looks exactly like a card that belongs there.
#
# READ THROUGH THE PARSER, NOT AS TEXT, and that is the whole reason this is not a regex. A pattern
# over the call's span is satisfied by any nearby MENTION of -Labels: a comment reading
# '# TODO: consider -Labels here' passes it while the argument itself is gone, which is exactly the
# silence these asserts exist to break. Only a CommandParameterAst is an argument -- the same rule
# check-plugin-integrity states for the Shopify CLI, where a comment naming the CLI is not a subject.
# It is also why neither assert is coupled to the call-site FORMATTING: reordering the arguments or
# switching either site to splatting changes the count rather than sneaking past a text anchor.
$mirrorAst = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $PluginRoot 'templates\asana-mirror.ps1'), [ref]$null, [ref]$null)
$stageCalls = @($mirrorAst.FindAll({ param($n)
    $n -is [System.Management.Automation.Language.CommandAst] -and
    $n.GetCommandName() -eq 'Resolve-TargetStage' }, $true))
$stageWithLabels = @($stageCalls | Where-Object {
    @($_.CommandElements | Where-Object {
        $_ -is [System.Management.Automation.Language.CommandParameterAst] -and
        $_.ParameterName -eq 'Labels' }).Count -gt 0 })
Assert-Equal 2 $stageCalls.Count      'Resolve-TargetStage is still called at exactly two sites (event mode and sweep (d))'
Assert-Equal 2 $stageWithLabels.Count 'and BOTH pass -Labels as a real argument, so sweep (d) can still re-derive the needs-info hold'

# comment request -- the only write this script builds
Assert-Throws { New-AsanaCommentRequest -Gid 'abc' -Text 'x' }             'New-AsanaCommentRequest throws on a non-numeric GID'
Assert-Throws { New-AsanaCommentRequest -Gid '123; rm -rf /' -Text 'x' }   'and on a GID carrying a shell payload'
$c = New-AsanaCommentRequest -Gid '123' -Text 'GitHub issue owner/repo#7 is closed'
Assert-Equal 'POST' $c.Method 'comment request is a POST'
Assert-True  ($c.Uri.EndsWith('/tasks/123/stories')) 'comment request posts to the stories endpoint'

# the update text -- what a colleague actually reads
$pr = [pscustomobject]@{ number = 434; url = 'https://github.com/BWJ-ecommerce/smartwatchbanden/pull/434'; title = 'fix: close the delivery-date element' }
$closed = New-MirrorComment -IssueRef 'BWJ-ecommerce/smartwatchbanden#388' -Event 'closed' -ClosedBy @($pr) -StateReason 'completed'
Assert-True ($closed -match 'ready to test')                'the close update says the work is ready to test'
Assert-True ($closed -match 'stays open on purpose')        'and says the ticket deliberately stays open'
Assert-True ($closed -match 'Tick it off yourself')         'and puts the resolving in the requester hands'
Assert-True ($closed -match 'https://github\.com/BWJ-ecommerce/smartwatchbanden/issues/388') 'and carries the issue URL'
Assert-True ($closed -notmatch '(?i)resolved|completed|done\b') 'and never claims the ticket itself is resolved'

# the closing pull request -- the first thing somebody about to test wants
Assert-True ($closed -match 'Closed by pull request:')   'the close update names the pull request that closed the issue'
Assert-True ($closed -match '#434')                      'by number'
Assert-True ($closed -match 'close the delivery-date element') 'with its title'
Assert-True ($closed -match 'https://github\.com/BWJ-ecommerce/smartwatchbanden/pull/434') 'and its URL, so it is one click away'

$two = New-MirrorComment -IssueRef 'o/r#1' -Event 'closed' -StateReason 'completed' -ClosedBy @(
    [pscustomobject]@{ number = 1; url = 'https://github.com/o/r/pull/1'; title = 'a' },
    [pscustomobject]@{ number = 2; url = 'https://github.com/o/r/pull/2'; title = 'b' })
Assert-True ($two -match 'Closed by pull requests:') 'two closing PRs are announced in the plural'
Assert-True ($two -match '#1' -and $two -match '#2')  'and both are listed'

# closed by hand -- say so rather than imply a PR that is not there
$byHand = New-MirrorComment -IssueRef 'o/r#1' -Event 'closed' -StateReason 'completed'
Assert-True ($byHand -match 'Closed by hand')            'an issue with no linked PR says it was closed by hand'
Assert-True ($byHand -notmatch '/pull/' -and $byHand -notmatch 'Closed by pull request') 'and links none, rather than inventing a reference'
Assert-True ($byHand -match 'ready to test')             'while still saying the ticket is ready to test'

# closed as not planned -- the opposite update, because nothing was built
$notPlanned = New-MirrorComment -IssueRef 'o/r#1' -Event 'closed' -StateReason 'not_planned'
Assert-True ($notPlanned -match 'as not planned')        'a not-planned close says so'
Assert-True ($notPlanned -match 'nothing to test')       'and tells the requester there is nothing to test'
Assert-True ($notPlanned -notmatch 'ready to test')      'rather than asking them to test something that was never built'
Assert-True ($notPlanned.StartsWith((Get-MirrorCommentMarker -IssueRef 'o/r#1'))) 'and it still carries the de-duplication marker'

$reopened = New-MirrorComment -IssueRef 'BWJ-ecommerce/smartwatchbanden#388' -Event 'reopened'
Assert-True ($reopened -match 'reopened')            'the reopen update says so'
Assert-True ($reopened -match 'hold off on testing') 'and tells the requester not to test yet'

# the de-duplication key is the close update's own opening sentence, and it names the issue --
# so two issues mirrored onto one task never mask each other
$marker = Get-MirrorCommentMarker -IssueRef 'BWJ-ecommerce/smartwatchbanden#388'
Assert-True ($closed.StartsWith($marker)) 'the marker is the first thing the close update says'
Assert-True ($marker -match '#388')       'and it names the issue'
Assert-True ($marker -ne (Get-MirrorCommentMarker -IssueRef 'BWJ-ecommerce/smartwatchbanden#390')) 'two issues get two different markers'

# issue-ref parsing for the reconciliation sweep
Assert-Equal 'BWJ-ecommerce/smartwatchbanden#42' (Get-IssueRefFromNotes -Notes 'see https://github.com/BWJ-ecommerce/smartwatchbanden/issues/42 for detail') 'Get-IssueRefFromNotes pulls owner/repo#n from a GitHub URL'
Assert-True  ($null -eq (Get-IssueRefFromNotes -Notes 'no link at all')) 'Get-IssueRefFromNotes returns null without a GitHub issue URL'

# --- the prio label ------------------------------------------------------------------------------
# Dave's mapping, September 2, 2026: 1.00-1.99 prio-1 | 2.00-2.99 prio-2 | 3.00-3.99 prio-3 |
# 4.00-5.00 prio-4. EVERY boundary is asserted from both sides, because an off-by-a-hundredth
# here mislabels real work and nothing downstream would notice it had happened.
#
# The NAMES are the family's shared ones since September 11, 2026 (#1842); the bands are Dave's
# original four and did not move with them.
Assert-Equal 'prio-1' (Get-PrioLabelForScore -Score 1)    'score 1.00 is prio-1 -- the bottom of the scale'
Assert-Equal 'prio-1' (Get-PrioLabelForScore -Score 1.99) 'and 1.99 is still prio-1'
Assert-Equal 'prio-2' (Get-PrioLabelForScore -Score 2)    '2.00 flips to prio-2'
Assert-Equal 'prio-2' (Get-PrioLabelForScore -Score 2.99) 'and 2.99 is still prio-2'
Assert-Equal 'prio-3' (Get-PrioLabelForScore -Score 3)    '3.00 flips to prio-3'
Assert-Equal 'prio-3' (Get-PrioLabelForScore -Score 3.99) 'and 3.99 is still prio-3'
Assert-Equal 'prio-4' (Get-PrioLabelForScore -Score 4)    '4.00 flips to prio-4'
Assert-Equal 'prio-4' (Get-PrioLabelForScore -Score 5)    'and 5.00, the top of the scale, is prio-4'

# no score and an out-of-range score give the same answer -- no label, never the nearest bucket
Assert-True ($null -eq (Get-PrioLabelForScore -Score $null)) 'a task with no score gets no label at all'
Assert-True ($null -eq (Get-PrioLabelForScore -Score 0.99))  'and a score below the scale gets none rather than the nearest one'
Assert-True ($null -eq (Get-PrioLabelForScore -Score 5.01))  'and one above the scale gets none either'

# THE MAPPING IS CULTURE-INVARIANT, which is not obvious and was measured rather than assumed: the
# machine this repo is maintained on runs nl-NL, where the decimal separator is a comma. A score
# arriving as a string must still read as three-and-a-half and not as thirty-five.
Assert-Equal 'prio-3' (Get-PrioLabelForScore -Score '3.5') "a score arriving as the string '3.5' still reads as 3.5"

# every label the mapper can return is one the enforcer knows how to remove: if these two drift, a
# rescored ticket keeps a stale label forever and the issue claims two priorities at once
foreach ($s in @(1.5, 2.5, 3.5, 4.5)) {
    Assert-True ($script:PrioLabels -contains (Get-PrioLabelForScore -Score $s)) "the label for score $s is one PrioLabels knows"
}
Assert-Equal 4 $script:PrioLabels.Count 'and PrioLabels holds exactly the four buckets -- there is no medium'

# reading the score off a task object, past the other custom fields Asana returns beside it
$scoredTask = [pscustomobject]@{ custom_fields = @(
    [pscustomobject]@{ name = 'Type';       number_value = $null },
    [pscustomobject]@{ name = 'Prio-Score'; number_value = 3.8 }) }
Assert-Equal 3.8 (Get-PrioScoreFromTask -Task $scoredTask -FieldName 'Prio-Score') 'Get-PrioScoreFromTask finds the field by name, past another field'
Assert-True ($null -eq (Get-PrioScoreFromTask -Task $scoredTask -FieldName 'Nope'))      'and returns null for a field the task has not got'
Assert-True ($null -eq (Get-PrioScoreFromTask -Task $null       -FieldName 'Prio-Score')) 'and null for a task that could not be read at all'
$emptyScore = [pscustomobject]@{ custom_fields = @([pscustomobject]@{ name = 'Prio-Score'; number_value = $null }) }
Assert-True ($null -eq (Get-PrioScoreFromTask -Task $emptyScore -FieldName 'Prio-Score')) 'and null for a field that is present but empty'

# an issue that already reads correctly is not written to -- what keeps the daily re-run quiet. This
# path returns before any gh call, so it is safe to assert here with no network and no repo.
Assert-True (-not (Set-IssuePrioLabel -Repo 'o/r' -Number 1 -Label 'prio-3' -Current @('prio-3', 'tier-1'))) 'an issue already carrying the right prio label is left alone'

# --- the stage sections --------------------------------------------------------------------------
# The board's six sections are the cycle's stages, and a section is recognised by the NUMBER its name
# starts with -- the words after it belong to the board and may change any day.
Assert-Equal 3 (Get-StageFromSectionName -Name '3. In development - branch open') 'a numbered section yields its stage'
Assert-Equal 3 (Get-StageFromSectionName -Name '3. Building it')                  'and still does after the words are rewritten -- the number is the only machine-read half'
Assert-Equal 6 (Get-StageFromSectionName -Name '  6. Completed')                   'leading whitespace does not hide the number'
Assert-Equal 2 (Get-StageFromSectionName -Name '2.')                               'a bare number and dot is enough'
Assert-True ($null -eq (Get-StageFromSectionName -Name 'Waiting for more info'))   'an unnumbered section is on no pipeline'
Assert-True ($null -eq (Get-StageFromSectionName -Name 'Stap 3: bouwen'))          'and a number that is not the prefix does not count -- the anchor is the start of the name'
Assert-True ($null -eq (Get-StageFromSectionName -Name ''))                        'an empty name yields nothing rather than throwing'

# --- the stage MAP ------------------------------------------------------------------------------
# The number convention says how a section is RECOGNISED; the map says what each one MEANS. They were
# one question until the board this was written against grew a section the same afternoon, shifting
# every stage above it by one -- silently, since nothing failed and every card would simply have been
# filed a column early. The map is now a repo seam, and the default is what a repo stating none gets.
$map = Get-DefaultAsanaStageMap
Assert-Equal '1/2/3/4/5/6/7' ((Get-StageMapNumbers -Map $map) -join '/') 'the default map is the seven-section board, in cycle order'
Assert-Equal 'needs-info' $map.NeedsInfoLabel 'and it names the label that drives the Need more info column'
Assert-Equal 0 (Test-AsanaStageMap -Map $map).Count 'the default map validates'

# Three ways a hand-written map goes wrong, and all three are SILENT at runtime rather than loud:
# a missing key reads as stage 0, a non-numeric one as 0 too, and a duplicate makes two stages one
# column so a card can never leave one of them.
$noKey = $map.Clone(); $noKey.Remove('InReview')
Assert-True (((Test-AsanaStageMap -Map $noKey) -join ' ') -match 'InReview') 'a map missing a stage is refused, naming which'
$notNum = $map.Clone(); $notNum['Filed'] = 'three'
Assert-True ((Test-AsanaStageMap -Map $notNum).Count -gt 0) 'a stage that is not a section number is refused'
$dupe = $map.Clone(); $dupe['InReview'] = $dupe['Filed']
Assert-True (((Test-AsanaStageMap -Map $dupe) -join ' ') -match 'more than one stage') 'two stages naming one section is refused -- a card could never leave one of them'
Assert-True ((Test-AsanaStageMap -Map $null).Count -gt 0) 'and an empty map is refused rather than treated as a default'

# The two ends of the board, asserted rather than assumed -- the same treatment the 'completes
# nothing' guarantee gets. Requests is the submitter's inbox; Completed is their verdict.
Assert-True (-not (Test-StageIsWritable -Stage $map.Requests  -Map $map)) 'Requests is the submitter inbox and is never a target'
Assert-True (-not (Test-StageIsWritable -Stage $map.Completed -Map $map)) 'Completed is NEVER a target -- the section-move twin of never completing a task'
Assert-True (Test-StageIsWritable -Stage $map.NeedsInfo   -Map $map) 'Need more info is ours to set, because a label drives it'
Assert-True (Test-StageIsWritable -Stage $map.Filed       -Map $map) 'Filed is ours'
Assert-True (Test-StageIsWritable -Stage $map.ReadyToTest -Map $map) 'and so is Ready to test, the last one that is'
Assert-True (-not (Test-StageIsWritable -Stage $null -Map $map)) 'no stage at all is not writable either'
Assert-Equal 5 (Get-WritableStages -Map $map).Count 'five writable stages -- the whole board minus its two ends'

# A REMAPPED board is the real test of the seam: the same assertions must hold against numbers this
# suite never mentions, or the map is decoration over hard-coded literals.
$shifted = @{ Requests = 10; NeedsInfo = 20; Filed = 30; InDevelopment = 40
              InReview = 50; ReadyToTest = 60; Completed = 70; NeedsInfoLabel = 'blocked' }
Assert-Equal 0 (Test-AsanaStageMap -Map $shifted).Count 'a board numbered any other way validates too'
Assert-True (Test-StageIsWritable -Stage 30 -Map $shifted)        'and its Filed stage is writable'
Assert-True (-not (Test-StageIsWritable -Stage 3 -Map $shifted))  'while the DEFAULT Filed number is not, under that map'
Assert-True (-not (Test-StageIsWritable -Stage 70 -Map $shifted))  'and its Completed stage is still the untouchable end'

# The derivation. THE PROJECT STATUS IS THE SOURCE since September 2, 2026 -- the issue's own state
# and its pull requests are no longer read for it. GitHub's own built-in project workflows already
# write that field ('Pull request linked to issue' sets In Progress, 'Item closed' sets Done), so
# deriving the same answer here a second time made two writers of one fact, which is a race.
$statusMap = Get-DefaultGithubStatusMap
Assert-Equal 0 (Test-GithubStatusMap -Map $statusMap).Count 'the default status map validates'
Assert-Equal 'Status' $statusMap.FieldName 'and it names the project field the stage is read from'
Assert-Equal $map.Filed         (Get-StageFloorForIssue -State 'OPEN'   -ProjectStatus 'Todo'        -StatusMap $statusMap -Map $map) 'status Todo floors at Filed'
Assert-Equal $map.InDevelopment (Get-StageFloorForIssue -State 'OPEN'   -ProjectStatus 'In Progress' -StatusMap $statusMap -Map $map) 'status In Progress floors at In development'
Assert-Equal $map.InReview      (Get-StageFloorForIssue -State 'CLOSED' -StateReason 'completed' -ProjectStatus 'Done' -StatusMap $statusMap -Map $map) 'and status Done floors at In review -- Dave, September 2, 2026: stages 3/4/5 ARE Todo/In Progress/Done'
Assert-True ($null -eq (Get-StageFloorForIssue -State 'OPEN' -ProjectStatus '' -StatusMap $statusMap -Map $map)) 'an issue on no board floors nowhere, rather than reading as stage 0'
Assert-True ($null -eq (Get-StageFloorForIssue -State 'OPEN' -ProjectStatus 'Blocked' -StatusMap $statusMap -Map $map)) 'and a column nobody has mapped floors nowhere either -- leaving the card alone is the answer to not knowing'
Assert-True ($null -eq (Get-StageFloorForIssue -State 'CLOSED' -StateReason 'not_planned' -ProjectStatus 'Done' -StatusMap $statusMap -Map $map)) "closed as not planned floors nowhere, though 'Item closed' set Done on it anyway -- nothing was built, so there is nothing to test"
Assert-Equal $map.InReview (Get-StageFloorForIssue -State 'closed' -StateReason 'COMPLETED' -ProjectStatus 'Done' -StatusMap $statusMap -Map $map) 'and the state is still read case-insensitively, since two GitHub surfaces disagree on it'

# The three stages a status may NOT name: two are a person's, and the third is the feedback rule's.
foreach ($stage in @('Requests', 'ReadyToTest', 'Completed')) {
    $badTarget = Get-DefaultGithubStatusMap
    $badTarget.Statuses = @{ 'Done' = $stage }
    Assert-True ((Test-GithubStatusMap -Map $badTarget).Count -gt 0) "a status naming $stage is refused -- that stage is reached by a person or by the feedback rule, never by a column"
}
$badStage = Get-DefaultGithubStatusMap
$badStage.Statuses = @{ 'Done' = 'Nonsense' }
Assert-True (((Test-GithubStatusMap -Map $badStage) -join ' ') -match 'not a stage') 'one naming something that is no stage at all is refused, naming it'
Assert-True ((Test-GithubStatusMap -Map $null).Count -gt 0) 'and an empty status map is refused rather than treated as a default'

# Keyed on the BOARD's own column names, so a board that renames its columns states that once here.
$renamed = @{ FieldName = 'Fase'; SubmitterPattern = ''
              Statuses = @{ 'Te doen' = 'Filed'; 'Bezig' = 'InDevelopment'; 'Klaar' = 'InReview' } }
Assert-Equal 0 (Test-GithubStatusMap -Map $renamed).Count 'a board with its own column names validates too'
Assert-Equal $map.InReview (Get-StageFloorForIssue -State 'CLOSED' -StateReason 'completed' -ProjectStatus 'Klaar' -StatusMap $renamed -Map $map) 'and its own words drive the same stage'
Assert-True ($null -eq (Get-StageFloorForIssue -State 'OPEN' -ProjectStatus 'Todo' -StatusMap $renamed -Map $map)) "while the DEFAULT column names mean nothing under it -- or the map is decoration over literals"

# WHICH PAIR CHANGED: InDevelopment IS derived now, and ReadyToTest no longer is.
$derived = @()
foreach ($s in @('Todo', 'In Progress', 'Done')) {
    $f = Get-StageFloorForIssue -State 'OPEN' -ProjectStatus $s -StatusMap $statusMap -Map $map
    $derived += $f
    Assert-True (Test-StageIsWritable -Stage $f -Map $map) "the derivation never leaves the writable range ($s)"
}
Assert-True ($derived -contains $map.InDevelopment) 'In development IS derived now -- GitHub sets In Progress itself when a pull request is linked'
Assert-True ($derived -notcontains $map.ReadyToTest) 'and Ready to test is never derived from a status -- only the feedback rule reaches it'

# --- the target, and the two answers that may go BACKWARD -----------------------------------------
# Everything else is a floor, and floors only rise. These two are a person saying something.
$t = Resolve-TargetStage -State 'OPEN' -ProjectStatus 'In Progress' -Labels @('tier-1', 'needs-info') -StatusMap $statusMap -Map $map
Assert-Equal $map.NeedsInfo $t.Stage         'the needs-info label OUTRANKS the project status -- In Progress does not unblock a card somebody blocked'
Assert-True  $t.AllowBackward                'and it may move the card backward, because a person set it'
Assert-True  ($t.Why -match 'needs-info')    'and the log says which label decided it'

$t = Resolve-TargetStage -State 'OPEN' -ProjectStatus 'In Progress' -Labels @('tier-1') -StatusMap $statusMap -Map $map
Assert-Equal $map.InDevelopment $t.Stage     'removing the label hands the card back to its status-derived floor'
Assert-True  (-not $t.AllowBackward)         'which is forward, so it needs no permission'
Assert-True  ($t.Why -match 'In Progress')   'and the log names the status that decided it, not just that a status did'

$t = Resolve-TargetStage -State 'OPEN' -ProjectStatus 'Todo' -Labels @() -StatusMap $statusMap -Map $map -Reopened
Assert-Equal $map.Filed $t.Stage             'a reopen lands the card wherever the board now says it is'
Assert-True  $t.AllowBackward                'and is the other answer allowed to go backward -- it is a real state change'
Assert-True  ($t.Why -match 'reopen')        'and says so'

$t = Resolve-TargetStage -State 'CLOSED' -StateReason 'not_planned' -ProjectStatus 'Done' -Labels @('needs-info') -StatusMap $statusMap -Map $map
Assert-Equal $map.NeedsInfo $t.Stage 'the label still answers for an issue whose status answers nothing'

$t = Resolve-TargetStage -State 'OPEN' -ProjectStatus 'Todo' -Labels @('blocked') -StatusMap $statusMap -Map $shifted
Assert-Equal 20 $t.Stage 'the label name comes from the map too, so a repo may call it anything'
$t = Resolve-TargetStage -State 'OPEN' -ProjectStatus 'Todo' -Labels @() -StatusMap $statusMap -Map $shifted
Assert-Equal 30 $t.Stage 'and the stage NUMBERS still come off the stage map, so the status drives a board numbered any other way just the same'
$noLabel = $map.Clone(); $noLabel['NeedsInfoLabel'] = ''
$t = Resolve-TargetStage -State 'OPEN' -ProjectStatus 'Todo' -Labels @('needs-info') -StatusMap $statusMap -Map $noLabel
Assert-Equal $map.Filed $t.Stage 'and a map naming no label switches the column off -- a real answer for a board without one'

# --- the feedback promotion, and the two stages nothing here takes a card back out of -------------
# Dave, September 2, 2026, in two rules. A card reaches Ready to test only once the submitter has
# actually been TOLD -- and once a card is in 6 or 7 it does not come back.
$withPattern = Get-DefaultGithubStatusMap
$withPattern.SubmitterPattern = '(?m)^\s*Aangevraagd door:\s*(.+?)\s*$'
$closed = @{ State = 'CLOSED'; StateReason = 'completed'; ProjectStatus = 'Done' }

$t = Resolve-TargetStage @closed -StatusMap $withPattern -Map $map -Submitter 'Jordy Navarro' -SubmitterTold
Assert-Equal $map.ReadyToTest $t.Stage  'a closed issue whose submitter has been told advances one stage past its status, to Ready to test'
Assert-True  ($t.Why -match 'Jordy')    'and the log names who was told, so the hop is attributable'
Assert-True  (-not $t.AllowBackward)    'the promotion never earns a backward move -- it only ever goes one stage up'

$t = Resolve-TargetStage @closed -StatusMap $withPattern -Map $map -Submitter 'Jordy Navarro'
Assert-Equal $map.InReview $t.Stage 'while one whose submitter has NOT been told waits in In review -- no status means anybody has been told'

$t = Resolve-TargetStage @closed -StatusMap $withPattern -Map $map -Submitter '' -SubmitterTold
Assert-Equal $map.InReview $t.Stage 'and a ticket nobody else asked for SKIPS stage 6 entirely -- there is nobody to hand it to, so its owner accepts it into Completed himself'

$t = Resolve-TargetStage -State 'OPEN' -ProjectStatus 'Todo' -StatusMap $withPattern -Map $map -Submitter 'Jordy Navarro' -SubmitterTold
Assert-Equal $map.Filed $t.Stage 'the promotion fires only off In review -- a Todo card is not handed to anybody however much they have been told'

# The pattern is the repo's, because where a submitter's name sits is a property of the intake form.
$notes = "Type: Automation`nAangevraagd door: Jordy Navarro`nDeadline: 2026-10-30"
Assert-Equal 'Jordy Navarro' (Get-SubmitterFromNotes -Notes $notes -Pattern $withPattern.SubmitterPattern) 'the submitter comes off the intake form line in the notes'
Assert-True ($null -eq (Get-SubmitterFromNotes -Notes 'n8n query splitter' -Pattern $withPattern.SubmitterPattern)) "notes naming nobody name nobody -- created_by is NOT the submitter, measured September 2, 2026: the intake form creates every card as its own owner, so it reads the same either way"
Assert-True ($null -eq (Get-SubmitterFromNotes -Notes $notes -Pattern '')) 'and a repo naming no pattern can never tell, so the promotion never fires at all -- the fail-safe direction'
Assert-Equal '' ([string]$statusMap.SubmitterPattern) 'which is what the DEFAULT map does, so stage 6 is opt-in per repo'
Assert-True ($null -eq (Get-SubmitterFromNotes -Notes $notes -Pattern '(unclosed')) 'a pattern that will not compile names nobody rather than throwing mid-sweep'

# --- a repo with NO project board (inbound #1536) --------------------------------------------------
# An empty FieldName is the repo SAYING it has no board, which is the declaration that did not exist
# before. Without it a board-less repo derived $null for every issue, which also switched off the
# feedback promotion below -- so closing an issue told the submitter it was ready and left their card
# where it stood. Four stages lost, not the three the docs described.
$boardless = @{ FieldName = ''; Statuses = @{}; SubmitterPattern = $withPattern.SubmitterPattern }
Assert-Equal 0 (Test-GithubStatusMap -Map $boardless).Count 'a map naming no project field validates -- "this repo has no board" is an answer, not a gap'

$bothWays = @{ FieldName = ''; Statuses = @{ 'Done' = 'InReview' }; SubmitterPattern = '' }
Assert-True (((Test-GithubStatusMap -Map $bothWays) -join ' ') -match 'not both') 'while saying there is no board AND naming its columns is refused as a half-finished edit'

# The floor comes off the issue itself, and only here.
Assert-Equal $map.InReview      (Get-StageFloorForIssue -State 'CLOSED' -StateReason 'completed' -StatusMap $boardless -Map $map) 'with no board a closed issue floors at In review'
Assert-Equal $map.InDevelopment (Get-StageFloorForIssue -State 'OPEN' -StatusMap $boardless -Map $map -HasLinkedPullRequest) 'an open one with a pull request linked floors at In development'
Assert-Equal $map.Filed         (Get-StageFloorForIssue -State 'OPEN' -StatusMap $boardless -Map $map) 'and an open one with nothing linked floors at Filed'
Assert-True ($null -eq (Get-StageFloorForIssue -State '' -StatusMap $boardless -Map $map)) 'while an issue GitHub could not be asked about floors nowhere -- nothing is derived from silence'
Assert-True ($null -eq (Get-StageFloorForIssue -State 'CLOSED' -StateReason 'not_planned' -StatusMap $boardless -Map $map)) 'and the not_planned guard outranks the fallback too -- nothing was built, so nothing is staged'
Assert-Equal $shifted.InReview (Get-StageFloorForIssue -State 'CLOSED' -StateReason 'completed' -StatusMap $boardless -Map $shifted) 'the numbers come off the stage map here as well, or the fallback is literals'

foreach ($case in @(@{ S = 'CLOSED'; P = $false }, @{ S = 'OPEN'; P = $true }, @{ S = 'OPEN'; P = $false })) {
    $f = Get-StageFloorForIssue -State $case.S -StatusMap $boardless -Map $map -HasLinkedPullRequest:$case.P
    Assert-True (Test-StageIsWritable -Stage $f -Map $map) "the board-less derivation never leaves the writable range ($($case.S), PR=$($case.P))"
    Assert-True ($f -ne $map.ReadyToTest) "and never reaches Ready to test off the floor alone ($($case.S), PR=$($case.P)) -- that stays the feedback rule's"
}

# THE HEADLINE: the promotion this issue was filed about now fires without a board.
$t = Resolve-TargetStage @closed -StatusMap $boardless -Map $map -Submitter 'Jordy Navarro' -SubmitterTold
Assert-Equal $map.ReadyToTest $t.Stage 'a closed issue in a board-less repo IS handed back to the submitter -- the transition #1536 measured as silently lost'
$t = Resolve-TargetStage @closed -StatusMap $boardless -Map $map -Submitter 'Jordy Navarro'
Assert-Equal $map.InReview $t.Stage 'and the two conditions still both apply -- an untold submitter waits in In review exactly as with a board'
$t = Resolve-TargetStage -State 'OPEN' -StatusMap $boardless -Map $map -Labels @('needs-info')
Assert-Equal $map.NeedsInfo $t.Stage 'the needs-info label still outranks everything, board or no board'
$t = Resolve-TargetStage -State 'OPEN' -StatusMap $boardless -Map $map
Assert-True ($t.Why -match 'no project board') 'and the log says the stage came off the issue, so a move is still attributable'

# THE CONTAINMENT, and it is the assert that matters most: a repo that HAS a board is untouched, and
# the pull-request fact cannot leak onto that path -- the September 2, 2026 rule is not weakened.
Assert-True ($null -eq (Get-StageFloorForIssue -State 'OPEN' -ProjectStatus '' -StatusMap $statusMap -Map $map -HasLinkedPullRequest)) 'where a repo names a project field, a linked pull request derives NOTHING -- an issue off that board stays off it'
Assert-Equal $map.Filed (Get-StageFloorForIssue -State 'CLOSED' -StateReason 'completed' -ProjectStatus 'Todo' -StatusMap $statusMap -Map $map -HasLinkedPullRequest) 'and the column still outranks the issue there -- the status is the source, unchanged'

# Terminal, and it OUTRANKS -AllowBackward: a card the submitter is holding is never taken back.
Assert-True (Test-StageIsTerminal -Stage $map.ReadyToTest -Map $map) 'a card in Ready to test is never moved out of it'
Assert-True (Test-StageIsTerminal -Stage $map.Completed   -Map $map) 'nor one in Completed'
Assert-True (-not (Test-StageIsTerminal -Stage $map.InReview -Map $map)) 'while In review is an ordinary stage a sweep may still move'
Assert-True (-not (Test-StageIsTerminal -Stage $map.Requests -Map $map)) 'and Requests is not terminal -- cards do leave it, they are just never sent there'
Assert-True (Test-StageIsTerminal -Stage 60 -Map $shifted) 'the terminal pair comes off the map too, so a board numbered any other way is protected the same'
Assert-True (-not (Test-StageIsTerminal -Stage $null -Map $map)) 'and no stage at all is not terminal'

# Select-ProjectStatus: one answer, none, or a refusal to guess -- the same three the Asana side gives.
$one = @([pscustomobject]@{ fieldValueByName = [pscustomobject]@{ name = 'Todo' } })
Assert-Equal 'Todo'   (Select-ProjectStatus -ProjectItems $one).Status 'one board, one status'
Assert-Equal 'status' (Select-ProjectStatus -ProjectItems $one).Source 'and it says where the answer came from'
Assert-Equal 'none'   (Select-ProjectStatus -ProjectItems @()).Source 'an issue on no board is on no pipeline'
$empty = @([pscustomobject]@{ fieldValueByName = $null })
Assert-Equal 'none'   (Select-ProjectStatus -ProjectItems $empty).Source 'and one on a board whose status is unset is the same answer'
$twoDifferent = @(
    [pscustomobject]@{ fieldValueByName = [pscustomobject]@{ name = 'Todo' } },
    [pscustomobject]@{ fieldValueByName = [pscustomobject]@{ name = 'Done' } }
)
Assert-Equal 'ambiguous' (Select-ProjectStatus -ProjectItems $twoDifferent).Source 'two boards naming two different statuses is two answers, so it gets neither'
$twoSame = @(
    [pscustomobject]@{ fieldValueByName = [pscustomobject]@{ name = 'Done' } },
    [pscustomobject]@{ fieldValueByName = [pscustomobject]@{ name = 'Done' } }
)
Assert-Equal 'Done' (Select-ProjectStatus -ProjectItems $twoSame).Status 'while two boards that agree are one answer, not a conflict'

# Which board -- read off the task's own memberships, so no repo keeps six section GIDs in its config.
# A task on an unnumbered board only is on no pipeline, which is how any other board is left alone.
$onBoard = @(
    [pscustomobject]@{ project = [pscustomobject]@{ gid = '1201907543904785' }; section = [pscustomobject]@{ gid = '11'; name = 'Backlog' } },
    [pscustomobject]@{ project = [pscustomobject]@{ gid = '1216936502427971' }; section = [pscustomobject]@{ gid = '22'; name = '4. Development done' } })
$sel = Select-StageMembership -Memberships $onBoard
Assert-Equal 'stage-section'    $sel.Source                'a numbered section past an unnumbered one still resolves'
Assert-Equal 4                  $sel.Membership.Stage      'and reports the stage the card is in now'
Assert-Equal '1216936502427971' $sel.Membership.ProjectGid 'and the board it read that from'
Assert-Equal '22'               $sel.Membership.SectionGid 'and that section GID, which is what a move needs'

Assert-Equal 'none' (Select-StageMembership -Memberships $onBoard[0]).Source 'a task on an unnumbered board only is on no pipeline'
Assert-Equal 'none' (Select-StageMembership -Memberships @()).Source         'and a task on no board at all is the same answer'
$twoBoards = @(
    [pscustomobject]@{ project = [pscustomobject]@{ gid = '111' }; section = [pscustomobject]@{ gid = '1'; name = '2. Filed' } },
    [pscustomobject]@{ project = [pscustomobject]@{ gid = '222' }; section = [pscustomobject]@{ gid = '2'; name = '5. Testing' } })
Assert-Equal 'ambiguous' (Select-StageMembership -Memberships $twoBoards).Source 'two numbered boards is two answers, and neither is taken'
Assert-Equal 2           (Select-StageMembership -Memberships $twoBoards).Candidates.Count 'and both are named for the log'

# The move request. Pure, and it refuses non-numeric input on BOTH sides -- a section name is read out
# of Asana and a GID out of an issue body, and neither may reach a request URL unchecked.
$move = New-AsanaSectionMoveRequest -Gid '1216905543348385' -SectionGid '1217315819287423'
Assert-Equal 'POST' $move.Method 'a section move is a POST'
Assert-Equal 'https://app.asana.com/api/1.0/sections/1217315819287423/addTask' $move.Uri 'to the section addTask endpoint -- the task is the payload, not the path'
Assert-Equal '{"data":{"task":"1216905543348385"}}' $move.Body 'and the body carries the task GID'
Assert-Throws { New-AsanaSectionMoveRequest -Gid 'abc' -SectionGid '123' } 'a non-numeric task GID is refused'
Assert-Throws { New-AsanaSectionMoveRequest -Gid '123' -SectionGid 'x/y' } 'and so is a non-numeric section GID'

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
    'skills\adopt-dkj-policy-bwj\SKILL.md' = 'adopt-dkj-policy-bwj'
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
$adoptTxt = Get-Content -LiteralPath (Join-Path $PluginRoot 'skills\adopt-dkj-policy-bwj\SKILL.md') -Raw
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
Assert-Equal 1 $grepMatches.Count 'adopt-dkj-policy-bwj step 4 carries exactly one label-existence check'
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

# --- done ---------------------------------------------------------------------------------------
Write-Host ""
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
