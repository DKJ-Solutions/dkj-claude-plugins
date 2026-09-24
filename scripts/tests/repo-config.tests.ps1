<#
.SYNOPSIS
    Regression tests for scripts/repo-config.ps1 (the local repo-data SSOT).

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Guards that the repo name lives in one
    place and that its blob URL is derived from it (issue #81 -- the repo name used to be
    hardcoded in open-pr.ps1, fold-changelog-entry.ps1 and release-lib.ps1).

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/repo-config.tests.ps1

    Pure ASCII (repo convention for .ps1).
#>

# Test-FunctionDefined (issue #1729): the retirement asserts below ask the function table directly
# rather than through Get-Command, whose miss path -- the case every one of those asserts is in --
# scans the whole PATH for an executable of that name.
. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\repo-config.ps1')

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

function Assert-Match {
    param([string]$Text, [string]$Pattern, [string]$Name)
    if ($Text -match $Pattern) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name (pattern '$Pattern' not found)" -ForegroundColor Red
    }
}

Write-Host "repo-config" -ForegroundColor Cyan
$name = Get-RepoName
Assert-Match $name '^[\w.-]+/[\w.-]+$' 'Get-RepoName has the form owner/name'

# The blob URL is derived from the repo name (single source) -- not separately hardcoded.
$blob = Get-RepoBlobUrl
Assert-Equal "https://github.com/$name/blob/main/" $blob 'Get-RepoBlobUrl is derived from Get-RepoName'

# The business publication target (Dave, August 14, 2026). owner/name form, because
# publish-to-business.ps1 expands that to an https URL; a full git URL is also legal for the seam
# in general, but THIS repo states owner/name, and a drift to something unresolvable should go red
# here rather than at the moment somebody publishes.
$business = Get-BusinessMarketplaceRepo
Assert-Match $business '^[\w.-]+/[\w.-]+$' 'Get-BusinessMarketplaceRepo has the form owner/name'
Assert-True ($business -ne (Get-RepoName)) 'Get-BusinessMarketplaceRepo is not this repo itself -- publishing overwrites the target'

# Which plugins travel to that target (issue #683). The target serves Claude App users, who have no
# repository, so no WORKFLOW plugin may be offered there: every one of its skills ends in a script run
# against a checkout. This assert is the tripwire on that rule -- the seam is a plain list, so adding a
# workflow to it is a one-word edit that nothing else would notice, and the failure it causes is a
# Claude App user being handed a command that can only fail at its last step.
#
# Held against the manifest rather than a hardcoded roster: a plugin added to plugins/dkj-subagents/ should
# reach the App marketplace by default, and a name the manifest does not know is refused by the script
# itself -- so what stays worth asserting here is that the list is non-empty (an empty one publishes
# EVERYTHING, silently reinstating the workflows) and that no workflow is in it.
$appPlugins = @(Get-BusinessMarketplacePlugins)
Assert-True ($appPlugins.Count -gt 0) 'Get-BusinessMarketplacePlugins names a subset -- an empty list would publish every plugin'
$manifestPlugins = @((Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\..\.claude-plugin\marketplace.json') -Raw |
                      ConvertFrom-Json).plugins)
foreach ($declared in $appPlugins) {
    Assert-True (@($manifestPlugins | ForEach-Object { $_.name }) -contains $declared) `
        "Get-BusinessMarketplacePlugins entry '$declared' is a plugin the marketplace actually has"
}
foreach ($entry in $manifestPlugins) {
    if ($entry.source -match '/workflows/') {
        Assert-True ($appPlugins -notcontains $entry.name) `
            "the workflow '$($entry.name)' does NOT travel to the Claude App target -- it needs a repository"
    }
}

# The lint gate that open-pr.ps1 runs (repo-specific, injected instead of hardcoded in open-pr).
$lint = Get-LintScript
Assert-Match $lint '\.ps1$' 'Get-LintScript points to a .ps1'
Assert-Match $lint '^scripts[\\/]' 'Get-LintScript is repo-root-relative under scripts/'

# Roster config for check-roster-sync.ps1 (the roster file + the deliberately ignored agent ids).
$roster = Get-RosterPath
Assert-Match $roster '\.md$' 'Get-RosterPath points to a .md'
$ignored = @(Get-RosterIgnoredIds)
foreach ($id in $ignored) { Assert-Match $id '^\d{2}-\d{2}$' "Get-RosterIgnoredIds: '$id' is a valid <group>-<id>" }

# THE RETIRED CHANGELOG SECTION SEAMS (August 5, 2026), asserted on ABSENCE. Get-ChangelogTierHeadings
# mapped tier -> the '## ' heading its entries were folded under, and Get-ChangelogHeading (issue #178) was
# the single-section answer before it. CHANGELOG.md has no section headings any more: an entry IS an H3 and
# the document is an intro plus a flat ranked list of them, so the fold and release-lib derive the
# intro/list boundary structurally instead.
#
# ASSERTED RATHER THAN JUST DELETED, because a repo-config still answering these would hand values to a
# mechanism that no longer reads them -- the write-once-config failure this file already guards for the two
# retired remove-before-publishing knobs below.
foreach ($retired in @('Get-ChangelogTierHeadings', 'Get-ChangelogHeading')) {
    Assert-Equal $false (Test-FunctionDefined $retired) "$retired is retired -- the flat changelog has no sections to name"
}

# AND THE DOCUMENT ITSELF HAS NONE. The mirror-image assert: a heading left in CHANGELOG.md would be read
# as an ENTRY by the flat parser (it matches '^## ' exactly as an entry heading does), so it would be
# rendered into the release notes as a change with no content. Held against the file rather than assumed,
# because that failure produces well-formed markdown and no error anywhere.
# READ THROUGH THE SEAM, not from the repo root. The literal '..\..\CHANGELOG.md' was correct until
# August 27, 2026, when the file moved into contributing-davekjohn/ and Get-ChangelogPath started saying
# so -- and a hardcoded path here would have failed loudly, which is the good outcome; asserting against
# the seam is what keeps it from failing again the next time the answer moves.
#
# NAMED $changelogFile AND NOT $changelogPath, which is not a style choice. repo-config.ps1 is DOT-SOURCED
# by this file, so its `$script:ChangelogPath` backing variable and a `$changelogPath` written here are the
# SAME variable -- PowerShell variable names are case-insensitive and dot-sourcing shares one script scope.
# Assigning it here silently repointed the seam mid-file, and the next Get-ChangelogPath call returned this
# script's absolute path instead of the repo-relative one. It failed visibly here only because a later
# assert used the value; a test that merely READ the seam after such an assignment would have gone green on
# a wrong answer. The same trap is open to every consumer that dot-sources repo-config.
$changelogFile = Join-Path $PSScriptRoot ('..\..\' + ((Get-ChangelogPath) -replace '/', '\'))
$changelogText = Get-Content -LiteralPath $changelogFile -Raw -Encoding UTF8
foreach ($gone in @('Pull Requests', 'Latest Release', 'Releases')) {
    $found = @([regex]::Matches($changelogText, '(?m)^##\s+(Tier \d+ - )?' + [regex]::Escape($gone) + '\s*$')).Count
    Assert-Equal 0 $found "CHANGELOG.md carries no '## $gone' section any more -- a leftover would parse as an empty entry"
}

# How many minors a major must recap. Ten in this workshop, and the number is held against the literal
# because the shared script hardcodes the same fallback -- the same two-copy risk as the entry stubs
# below.
Assert-Equal 10 (Get-ReleaseMajorMinMinors) 'Get-ReleaseMajorMinMinors is 10 in this workshop'

# The two retired remove-before-publishing knobs. Asserted on ABSENCE: both configured the remove-before-publishing
# marker that the tier model replaced, and a repo-config still answering them would be handing values to
# a mechanism that no longer reads them.
foreach ($gone in 'Get-ReleaseHighlightsStakeholderTypes', 'Get-ReleaseHighlightsWording') {
    Assert-Equal $false (Test-FunctionDefined $gone) "$gone is retired, not left returning a value nothing reads"
}

# The optional "go live" stage description for the cut-release skill's Block 2 (issue #177, Optional
# in the script contract). Empty by default in this workshop and life-hub -- no separate live stage,
# so Block 2 of the checklist never applies here; only a repo that has one fills this in.
$liveStage = Get-LiveStage
Assert-Equal '' $liveStage "Get-LiveStage defaults to '' in this workshop (no separate live stage)"

# The stub wording new-branch.ps1 writes (issue #410, all four Optional in the script
# contract). Asserted against the LITERAL values rather than merely "is non-empty", because these four
# are the fallbacks the shared script hardcodes as well: if the two ever disagree, a consumer that
# defines nothing and a consumer that copies this file get different entries, which is exactly the
# split #410 exists to close. check-script-contract.ps1's Default fields are the third copy and are
# pinned by script-contract.tests.ps1.
Assert-Equal 'TODO: title' (Get-EntryTitlePlaceholder) 'Get-EntryTitlePlaceholder matches the shared default'
Assert-Equal '**To do / where I left off:**' (Get-EntryBodyHeading) 'Get-EntryBodyHeading matches the shared default'
Assert-Equal 'TODO: what this change does, for whoever reads CHANGELOG.md later.' (Get-EntryBodyPlaceholder) 'Get-EntryBodyPlaceholder matches the shared default'
Assert-Equal 'Chore' (Get-EntryFallbackType) 'Get-EntryFallbackType matches the shared default'

# The fallback type must be a type this repo's own branch table actually produces -- the release cut
# groups entries by that string, so a typo here silently drops every unknown-prefix entry into a
# catch-all category at the next release.
. (Join-Path $PSScriptRoot '..\lib\branch-info.ps1')
$knownTypes = @(Get-BranchTypes)
Assert-True ($knownTypes -contains (Get-EntryFallbackType)) "Get-EntryFallbackType ('$(Get-EntryFallbackType)') is one of the types this repo's branch table produces"

# How ship-pr.ps1 merges (issue #411, Optional in the contract). Constrained to the three values
# `gh pr merge` accepts: ship-pr validates it and refuses anything else rather than handing an unknown
# flag to gh at the moment it is about to write to main -- so this assert is the same guard, one layer
# earlier, where it costs nothing to hit.
$mergeMethod = Get-PrMergeMethod
Assert-True (@('merge', 'squash', 'rebase') -contains $mergeMethod) "Get-PrMergeMethod ('$mergeMethod') is one of merge/squash/rebase"
Assert-Equal 'merge' $mergeMethod 'Get-PrMergeMethod is merge in this workshop (every PR keeps its own commits on main)'

# The machine-local path list open-pr.ps1 warns about when a branch commit touches one (issue #1559).
# Optional and probed like the four Get-Pr* seams, so it is not in the script contract; asserted here
# for the same reason Get-MojibakePaths is -- a repo-owned list can quietly stop describing its repo.
$mlPaths = @(Get-MachineLocalPaths)
Assert-True ($mlPaths -contains '.claude/settings.json') 'Get-MachineLocalPaths watches the shared harness settings file'
Assert-Equal 0 (@($mlPaths | Where-Object { $_ -match '^[\\/]|^[A-Za-z]:' }).Count) 'Get-MachineLocalPaths entries are repo-root-relative, not absolute'

# The shared triage labels (issue #1895; 'dossier' added by #2462), Adopt='copy' in the script contract -- this repo's
# own live answer, and the same five values adopt-triage-labels.ps1 carries as its own built-in
# fallback (asserted there, against this repo's REAL gh labels, since that duality is the whole point
# of the two copies never being allowed to disagree).
$triageLabels = @(Get-TriageLabels)
Assert-Equal 5 $triageLabels.Count 'Get-TriageLabels names exactly five labels -- four rungs and the dossier kind'
# Joined into one string rather than compared as two arrays: PowerShell's -eq on two arrays compares
# elementwise against the WHOLE right-hand array per element, never a deep sequence equality, so
# Assert-Equal would silently pass or fail on the wrong thing. Same join-then-compare shape
# script-contract.tests.ps1 already uses for its own Scripts-list assertions.
Assert-Equal 'prio-1,prio-2,prio-3,prio-4,dossier' (($triageLabels | ForEach-Object { $_.Name }) -join ',') `
    'Get-TriageLabels names prio-1 through prio-4, then dossier, in that order'
foreach ($l in $triageLabels) {
    Assert-Match $l.Color '^[0-9A-Fa-f]{6}$' "Get-TriageLabels: '$($l.Name)' has a 6-digit hex colour"
    Assert-True ([bool]$l.Description) "Get-TriageLabels: '$($l.Name)' has a non-empty description"
}
# The exact values, held against a literal rather than merely "looks plausible" -- this IS the
# canonical set every dkj-policy consumer is invited to copy, so a silent drift here silently changes
# what every future adopter receives.
$expectedTriage = @{
    'prio-1' = @{ Color = '006B75'; Description = 'Priority 1 of 4 (lowest) -- nobody is waiting for it' }
    'prio-2' = @{ Color = 'FBCA04'; Description = 'Priority 2 of 4 -- worth doing, no pressure' }
    'prio-3' = @{ Color = 'D93F0B'; Description = 'Priority 3 of 4 -- do this before the ordinary backlog' }
    'prio-4' = @{ Color = 'B60205'; Description = 'Priority 4 of 4 (highest) -- takes precedence over other work' }
    'dossier' = @{ Color = '5319E7'; Description = 'Collects every instance of one recurring problem until its root cause is fixed' }
}
foreach ($l in $triageLabels) {
    Assert-Equal $expectedTriage[$l.Name].Color $l.Color "Get-TriageLabels: '$($l.Name)' colour matches this repo's own live label"
    Assert-Equal $expectedTriage[$l.Name].Description $l.Description "Get-TriageLabels: '$($l.Name)' description matches this repo's own live label"
}

# The file set fix-mojibake.ps1 examines by default (issue #413, Optional in the contract). Asserted
# against the real repo root rather than a fixture: the point of moving this list out of the tool was
# that a list can silently stop matching the repo it describes, and only the real tree can show that.
$repoRootForPaths = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$mjPaths = @(Get-MojibakePaths -RepoRoot $repoRootForPaths)
Assert-True ($mjPaths.Count -gt 0) 'Get-MojibakePaths returns a non-empty set'
Assert-True (($mjPaths | Where-Object { $_ -notmatch '\.md$' }).Count -eq 0) 'Get-MojibakePaths returns only .md files'
Assert-True (($mjPaths | Where-Object { -not (Test-Path -LiteralPath $_) }).Count -eq 0) 'Get-MojibakePaths returns only paths that exist'
# README.md stood first here until September 24, 2026, when the root README was retired; SECURITY.md is
# the other root document that stays.
foreach ($mustHave in @('CLAUDE.md', 'SECURITY.md')) {
    $want = Join-Path $repoRootForPaths $mustHave
    Assert-True ($mjPaths -contains $want) "Get-MojibakePaths includes the root $mustHave"
}
# THE CHANGELOG IS ASSERTED THROUGH THE SEAM, and it stopped being a root document on August 27, 2026.
# It is named separately rather than dropped from the list: it is the single highest-value file in this
# set -- its text is pasted into a release note and from there into a published document -- so what has
# to hold is that the set reaches it WHEREVER the repo keeps it, which is what the seam answers.
$wantChangelog = Join-Path $repoRootForPaths ((Get-ChangelogPath) -replace '/', '\')
Assert-True ($mjPaths -contains $wantChangelog) 'Get-MojibakePaths includes the changelog Get-ChangelogPath names'
# The two directories that made the old hardcoded list workshop-shaped, and the reason it had to move
# behind the seam: a consumer has neither, and the tool silently examined almost nothing there.
Assert-True (($mjPaths | Where-Object { $_ -match '\\plugins\\' }).Count -gt 0) 'Get-MojibakePaths reaches the per-plugin CHANGELOG.md/RELEASE.md files'
Assert-True (($mjPaths | Where-Object { $_ -match '\\releases\\' }).Count -gt 0) 'Get-MojibakePaths reaches the archived release notes'

# The consumer tier (#417, Optional in the contract). ON for minor/major since August 3, 2026 -- these
# asserts were written the other way round one commit earlier, when the tier was off, and were flipped
# with Dave's decision. Kept as asserts on the VALUE rather than deleted: the tier writes files into
# releases/ and its output is judged by eye, so a silent change to either knob is worth a red test.
# Whether the tier WORKS is release-lib.tests.ps1's job; this is only about what this repo answers.
$hlBumps = @(Get-ReleaseConsumerBumps)
Assert-Equal 2 $hlBumps.Count 'Get-ReleaseConsumerBumps names two bump types'
Assert-True ($hlBumps -contains 'minor') 'Get-ReleaseConsumerBumps includes minor'
Assert-True ($hlBumps -contains 'major') 'Get-ReleaseConsumerBumps includes major'
# Patch is excluded BY DESIGN, not by omission: a minor here is cut when a consumer notices something,
# so a patch has no consumer document reader by definition. Asserted so adding 'patch' becomes a decision.
Assert-True ($hlBumps -notcontains 'patch') 'Get-ReleaseConsumerBumps excludes patch -- a patch has nothing a consumer would read'
# A bump type that is not one of the three the script understands would silently never match, so the
# tier would appear configured and generate nothing. Guarded here rather than at release time.
$badBumps = @($hlBumps | Where-Object { @('major', 'minor', 'patch') -notcontains $_ })
Assert-Equal 0 $badBumps.Count "Get-ReleaseConsumerBumps names only major/minor/patch (stray: $($badBumps -join ', '))"

# WHAT USED TO BE ASSERTED HERE, and why it is not. Two more knobs configured the consumer draft: which
# branch types to promote above a "remove before publishing" marker, and in whose words to label that
# marker. The asserts held them against this repo's own branch table, because a type named there that
# branch-info never produces would put an empty category above the marker and drop the real ones below it.
#
# Both knobs, the marker and that whole failure mode are gone (August 5, 2026): the consumer document is
# now the release's TIER-2 entries, declared per entry by their author rather than inferred from a branch
# prefix -- which this repo had measured does not predict impact. Their absence is asserted at the top of
# this file, where the tier map is checked, rather than here where the values used to be read.

# THE RETIRED NAME IS NOT DEFINED HERE, AND THAT IS THE POINT OF ASSERTING IT (August 10, 2026). The knob
# was Get-ReleaseHighlightsBumps until the tier was renamed after its reader, and cut-release deliberately
# reads BOTH names. This repo must therefore answer under the CURRENT one only -- if both were defined here
# the fallback would never be exercised by anything, and the day it broke nothing in this repo would
# notice. That the fallback still reads the old name is asserted where it lives, in
# cut-release-guardrail.tests.ps1; this side asserts the other half of the pair.
Assert-True (-not (Test-FunctionDefined 'Get-ReleaseHighlightsBumps')) `
    'the retired name Get-ReleaseHighlightsBumps is NOT defined here -- only the fallback in cut-release still knows it'

Write-Host ""
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
