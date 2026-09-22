<#
.SYNOPSIS
    Regression tests for scripts/lib/pr-overlap-lib.ps1 -- the overlap scan that tells a branch which
    OTHER open pull requests change a file it also changes (issue #2315), and the open-pr.ps1 wiring
    that gives it its reach.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell. Exit 0 if everything passes, 1 on a failure.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/pr-overlap-lib.tests.ps1

    THE SCAN'S TWO NETWORK CALLS ARE NOT COVERED HERE AND CANNOT BE. `git diff --name-only` against a
    real branch and `gh pr list --json files` against a real remote are open-pr.ps1's to make, which is
    exactly why the parse, the intersection and the wording were extracted into a lib -- everything a
    suite can hold is on this side of that line. What section 5 does hold is that the caller still
    reaches them.

    WHAT IS ASSERTED, and why each one is here rather than assumed:

      1. Get-OpenPrPathRecords -- the payload parse. The 5.1 traps first (an array reaching the
         pipeline as a single object; a field gh was never asked for being ABSENT rather than empty),
         then the three ways an answer is unreadable, every one of which must produce an EMPTY array
         rather than a partial one. Empty means "could not be asked", never "nobody else is editing
         anything", and the caller's DarkGray line says which.
      2. ConvertTo-ComparablePath -- the normalisation both sides pass through. Backslashes, the quotes
         `git diff --name-only -c core.quotePath=true` wraps a non-ASCII path in, and the case rule.
         CASE IS PINNED DELIBERATELY: forgiving it would invent an overlap between Foo.ps1 and foo.ps1,
         which is the direction an advisory note must not err in.
      3. Get-PrOverlapFindings -- the intersection. Self excluded by NUMBER and by HEAD REF, because
         which of the two is available depends on whether the branch already has a PR; the empty cases;
         and the sort order, which is what makes two runs over one state print the same lines.
      4. Format-PrOverlapNote -- the wording, held to the three things a reader acts on rather than to
         its prose: that it names every finding's number, that both caps truncate and SAY they did, and
         that it does NOT tell the reader to merge the trunk in. That last assert is the repair #2315's
         own proposed wording needed -- every PR the note names is OPEN, so its work is not on the trunk
         and there is nothing to merge yet.
      5. THE WIRING. open-pr.ps1 dot-sources the lib, composes the note, and re-prints it at all three
         of its endings -- the same three the machine-local note (#1559) is repeated at, and for the
         same reason: everything printed before the gates is off-screen by the time anybody reads an
         ending. A note composed and printed once would be invisible on exactly the runs that matter.
      6. THE MIRROR. The lib is registered as a shared script and the plugin copy is identical, because
         open-pr.ps1 is mirrored and a consumer running the mirror would otherwise dot-source a file it
         does not have.

    Pure ASCII (repo convention for .ps1). The one non-ASCII path in section 2 is built from its
    codepoint.
#>
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# THE REPO ROOT, judged and ANCHORED (#1917) -- see document-newline.tests.ps1 for why -From matters.
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
$RepoRoot = Resolve-RepoRootOrFail -From $PSScriptRoot -ScriptName 'pr-overlap-lib.tests.ps1'
. (Join-Path $PSScriptRoot '..\lib\pr-overlap-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\shared-scripts-lib.ps1')

$script:pass = 0
$script:fail = 0
function Assert-Equal {
    param($Expected, $Actual, [string]$Label)
    if ("$Expected" -eq "$Actual") { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label`n         expected: '$Expected'`n         got:      '$Actual'" -ForegroundColor Red }
}
function Assert-True {
    param([bool]$Condition, [string]$Label)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Label" -ForegroundColor Green }
    else { $script:fail++; Write-Host "  [FAIL] $Label" -ForegroundColor Red }
}

# --- 1. Get-OpenPrPathRecords: the payload parse ----------------------------------------------------
Write-Host ''
Write-Host '1. Get-OpenPrPathRecords -- the payload parse' -ForegroundColor Cyan

# THE MEASURED INCIDENT'S OWN SHAPE (PR #2300, September 22, 2026): two open PRs both changing
# .github/workflows/ci.yml, which is what nothing reported until forward lap 3.
$incidentJson = @'
[
  { "number": 2308, "title": "feat: conditional merge-commit suite skip", "headRefName": "feat/2303-conditional-merge-commit-suite-skip",
    "files": [ { "path": ".github/workflows/ci.yml" }, { "path": "scripts/lib/ci-merge-skip-lib.ps1" } ] },
  { "number": 2310, "title": "feat: split the critical-path suites", "headRefName": "feat/2304-split-critical-path-suites",
    "files": [ { "path": ".github/workflows/ci.yml" }, { "path": "scripts/tests/ci-shard.tests.ps1" } ] }
]
'@
$incident = @(Get-OpenPrPathRecords -Json $incidentJson)
Assert-Equal 2 $incident.Count 'two records parse out of the incident payload'
Assert-Equal 2308 $incident[0].Number 'the number is read'
Assert-Equal 'feat/2303-conditional-merge-commit-suite-skip' $incident[0].HeadRefName 'the head ref is read'
Assert-Equal 2 $incident[0].Paths.Count 'both of a record''s file paths are read'
Assert-True ($incident[0].Paths -contains '.github/workflows/ci.yml') 'the colliding path is among them'

# A SINGLE-RECORD ARRAY: the 5.1 trap that reaches the pipeline as one object rather than a list.
$one = @(Get-OpenPrPathRecords -Json '[ { "number": 7, "title": "t", "headRefName": "h", "files": [ { "path": "a.md" } ] } ]')
Assert-Equal 1 $one.Count 'a one-record array parses as one record, not as its fields'
Assert-Equal 'a.md' ($one[0].Paths -join ',') 'and its single file path survives the same trap'

# A FIELD gh WAS NEVER ASKED FOR IS ABSENT, not empty -- so every record is probed before it is read.
$sparse = @(Get-OpenPrPathRecords -Json '[ { "number": 9 } ]')
Assert-Equal 1 $sparse.Count 'a record with no title, head ref or files still parses'
Assert-Equal '' $sparse[0].Title 'an absent title reads as empty rather than throwing'
Assert-Equal 0 $sparse[0].Paths.Count 'an absent files field reads as no paths'

# THE THREE UNREADABLE ANSWERS. Each is EMPTY, which the caller reads as "could not be asked".
Assert-Equal 0 @(Get-OpenPrPathRecords -Json '').Count            'empty input parses to nothing'
Assert-Equal 0 @(Get-OpenPrPathRecords -Json '   ').Count         'whitespace input parses to nothing'
Assert-Equal 0 @(Get-OpenPrPathRecords -Json 'not json').Count    'unparseable JSON parses to nothing rather than throwing'
Assert-Equal 0 @(Get-OpenPrPathRecords -Json '[]').Count          'an empty list parses to nothing'
# A RECORD WITH NO USABLE NUMBER IS DROPPED: the number is what the note cites, and a finding nobody
# can look up is worse than no finding.
Assert-Equal 0 @(Get-OpenPrPathRecords -Json '[ { "number": "x", "files": [ { "path": "a.md" } ] } ]').Count 'a record whose number does not parse is dropped'
Assert-Equal 0 @(Get-OpenPrPathRecords -Json '[ { "number": 0, "files": [ { "path": "a.md" } ] } ]').Count   'a record numbered 0 is dropped'

# --- 2. ConvertTo-ComparablePath: the normalisation both sides pass through -------------------------
Write-Host ''
Write-Host '2. ConvertTo-ComparablePath -- the normalisation' -ForegroundColor Cyan

Assert-Equal 'scripts/lib/a.ps1' (ConvertTo-ComparablePath -Path 'scripts\lib\a.ps1') 'backslashes become forward slashes'
Assert-Equal 'scripts/lib/a.ps1' (ConvertTo-ComparablePath -Path '  scripts/lib/a.ps1  ') 'surrounding whitespace is trimmed'
Assert-Equal '' (ConvertTo-ComparablePath -Path '')    'the empty string normalises to nothing'
Assert-Equal '' (ConvertTo-ComparablePath -Path '   ') 'whitespace normalises to nothing'
Assert-Equal '' (ConvertTo-ComparablePath -Path $null) 'a null path normalises to nothing rather than throwing'

# THE QUOTE STRIP. With -c core.quotePath=true a path holding a non-ASCII byte comes back wrapped in
# double quotes while gh's copy of the same path does not -- so without this the pair never matches.
$eacute = [char]0x00E9
Assert-Equal "docs/caf$($eacute).md" (ConvertTo-ComparablePath -Path "`"docs/caf$($eacute).md`"") 'a C-quoted path loses its wrapping quotes'
Assert-Equal 'docs/"quoted".md' (ConvertTo-ComparablePath -Path 'docs/"quoted".md') 'an inner quote is left alone -- only a wrapped path is unwrapped'

# CASE IS PINNED. See the banner: forgiving it would invent an overlap on a repo holding both spellings.
$caseHit = @(Get-PrOverlapFindings -ChangedPaths @('scripts/Foo.ps1') `
                                   -OpenPrs @([pscustomobject]@{ Number = 1; Title = 't'; HeadRefName = 'h'; Paths = @('scripts/foo.ps1') }))
Assert-Equal 0 $caseHit.Count 'a case difference is two different files, not an overlap'

# --- 3. Get-PrOverlapFindings: the intersection ------------------------------------------------------
Write-Host ''
Write-Host '3. Get-PrOverlapFindings -- the intersection' -ForegroundColor Cyan

$openPrs = @(
    [pscustomobject]@{ Number = 2308; Title = 'a'; HeadRefName = 'feat/a'; Paths = @('.github/workflows/ci.yml', 'scripts/lib/ci-merge-skip-lib.ps1') },
    [pscustomobject]@{ Number = 2310; Title = 'b'; HeadRefName = 'feat/b'; Paths = @('.github/workflows/ci.yml', '.claude/specialists/lenses/specialist-05-15-lens.md') },
    [pscustomobject]@{ Number = 2309; Title = 'c'; HeadRefName = 'feat/c'; Paths = @('README.md') }
)
$mine = @('.github/workflows/ci.yml', '.claude/specialists/lenses/specialist-05-15-lens.md', 'dkj-policy/fix-2296.md')

$found = @(Get-PrOverlapFindings -ChangedPaths $mine -OpenPrs $openPrs -SelfNumber 0 -SelfBranch 'fix/2296-workflow-job-timeouts')
Assert-Equal 2 $found.Count 'the two PRs sharing a path are found and the third is not'
# SORTED BY SHARED-PATH COUNT, THEN NUMBER: the PR sharing two files is the one worth reading first.
Assert-Equal 2310 $found[0].Number 'the PR sharing the most paths sorts first'
Assert-Equal 2 $found[0].SharedPaths.Count 'and it reports both of them'
Assert-Equal 2308 $found[1].Number 'the PR sharing one path follows'
Assert-Equal '.github/workflows/ci.yml' ($found[1].SharedPaths -join ',') 'only the SHARED path is reported, not the whole diff'

# SELF BY NUMBER: on a re-run -- and on every ship-pr, whose step 1 is open-pr -- this branch's own PR
# is in the list, and it shares every path with itself.
$selfByNumber = @(Get-PrOverlapFindings -ChangedPaths $mine -OpenPrs $openPrs -SelfNumber 2310 -SelfBranch '')
Assert-Equal 1 $selfByNumber.Count 'the branch''s own PR is excluded by number'
Assert-Equal 2308 $selfByNumber[0].Number 'and the other finding is untouched by that exclusion'

# SELF BY HEAD REF: on a fresh branch there is no PR number yet, so the ref is the only key available.
$selfByRef = @(Get-PrOverlapFindings -ChangedPaths $mine -OpenPrs $openPrs -SelfNumber 0 -SelfBranch 'feat/b')
Assert-Equal 1 $selfByRef.Count 'the branch''s own PR is excluded by head ref when its number is unknown'
Assert-Equal 2308 $selfByRef[0].Number 'and again the other finding survives'

# THE EMPTY CASES, each of which the caller reports with its own DarkGray line.
Assert-Equal 0 @(Get-PrOverlapFindings -ChangedPaths @() -OpenPrs $openPrs).Count 'a branch that changes nothing finds nothing'
Assert-Equal 0 @(Get-PrOverlapFindings -ChangedPaths $mine -OpenPrs @()).Count    'no open PRs finds nothing'
Assert-Equal 0 @(Get-PrOverlapFindings -ChangedPaths $null -OpenPrs $null).Count  'both sides null finds nothing rather than throwing'
Assert-Equal 0 @(Get-PrOverlapFindings -ChangedPaths @('a.md') -OpenPrs @([pscustomobject]@{ Number = 5; Paths = @('b.md') })).Count 'disjoint paths find nothing'

# A PATH SHARED IN THE OTHER SPELLING still matches, because both sides are normalised.
$slashed = @(Get-PrOverlapFindings -ChangedPaths @('scripts/lib/a.ps1') `
                                   -OpenPrs @([pscustomobject]@{ Number = 5; Paths = @('scripts\lib\a.ps1') }))
Assert-Equal 1 $slashed.Count 'a backslashed path on one side still matches the forward-slashed other'

# --- 4. Format-PrOverlapNote: the wording -----------------------------------------------------------
Write-Host ''
Write-Host '4. Format-PrOverlapNote -- the wording' -ForegroundColor Cyan

Assert-Equal '' (Format-PrOverlapNote -Findings @())   'no findings produce no note at all'
Assert-Equal '' (Format-PrOverlapNote -Findings $null) 'a null finding set produces no note either'

$note = Format-PrOverlapNote -Findings $found
Assert-True ($note -like '*#2310*' -and $note -like '*#2308*') 'the note cites every finding''s number'
Assert-True ($note -like '*.github/workflows/ci.yml*') 'and names the shared path'
Assert-True ($note -like '*feat/b*') 'and the head ref, so the reader can find the branch'
Assert-True ($note -like '*2 other open PRs change*') 'the lead line counts the findings'

# THE TITLE IS PRINTED AND NOT MERELY PARSED. It answers the half of the ordering decision the number
# cannot -- a typo fix and a refactor are not the same thing to land first -- and a field read into a
# record and never shown is dead weight the next reader has to re-derive a purpose for.
$titled = Format-PrOverlapNote -Findings @([pscustomobject]@{ Number = 5; Title = 'fix: a short title'; HeadRefName = 'fix/x'; SharedPaths = @('a.md') })
Assert-True ($titled -like '*fix: a short title*') 'the note prints the PR title beside its number'
# TRUNCATED, because a PR title in this house is a sentence and the full text is one gh call away.
$longTitle = 'x' * 200
$truncated = Format-PrOverlapNote -Findings @([pscustomobject]@{ Number = 5; Title = $longTitle; HeadRefName = ''; SharedPaths = @('a.md') })
Assert-True ($truncated -like '*...*') 'a long title is truncated rather than printed whole'
Assert-True ($truncated -notlike "*$longTitle*") 'and the full 200-character title does not reach the output'
$untitled = Format-PrOverlapNote -Findings @([pscustomobject]@{ Number = 5; Title = ''; HeadRefName = 'fix/x'; SharedPaths = @('a.md') })
Assert-True ($untitled -like '*#5  (fix/x)*') 'a record with no title leaves no dangling separator behind'

# THE REPAIR #2315'S OWN PROPOSED WORDING NEEDED. Every PR named is OPEN, so its work is not on the
# trunk: "merge the trunk in now" would send the reader to run a command that does nothing, and the
# silence would read as reassurance. Pinned so it cannot be helpfully re-added.
Assert-True ($note -notlike '*Merging the trunk in NOW*') 'the note does not tell the reader to merge the trunk in now'
Assert-True ($note -like '*Whoever merges SECOND resolves*') 'it states the fact that is true at this moment instead'
Assert-True ($note -like '*not a refusal*') 'and says in as many words that it blocks nothing'

# BOTH CAPS TRUNCATE AND SAY SO -- a note that silently stops is indistinguishable from one that found
# nothing more. The per-path cap is load-bearing rather than a corner: a change to a shared workflow
# script lands in the root copy and every plugin mirror, so one capability arrives as three or four paths.
$many = @(1..8 | ForEach-Object {
    [pscustomobject]@{ Number = 100 + $_; Title = "t$_"; HeadRefName = "feat/$_"; SharedPaths = @('a.md', 'b.md') }
})
$cappedPrs = Format-PrOverlapNote -Findings $many -MaxPrs 3
Assert-True ($cappedPrs -like '*and 5 more open PR(s) sharing a path*') 'the PR cap truncates and says how many it left out'
Assert-True ($cappedPrs -like '*#101*' -and $cappedPrs -notlike '*#108*') 'and it keeps the first three'

$wide = @([pscustomobject]@{ Number = 1; Title = 't'; HeadRefName = 'h'; SharedPaths = @('a.md', 'b.md', 'c.md', 'd.md', 'e.md') })
$cappedPaths = Format-PrOverlapNote -Findings $wide -MaxPaths 2
Assert-True ($cappedPaths -like '*and 3 more shared path(s)*') 'the path cap truncates and says how many it left out'
Assert-True ($cappedPaths -like '*a.md*' -and $cappedPaths -notlike '*e.md*') 'and it keeps the first two'

$single = Format-PrOverlapNote -Findings @($found[0])
Assert-True ($single -like '*1 other open PR changes*') 'one finding reads in the singular'

# --- 5. the wiring: open-pr.ps1 composes it and repeats it at all three endings ----------------------
Write-Host ''
Write-Host '5. the wiring in open-pr.ps1' -ForegroundColor Cyan

$openPrPath = Join-Path $RepoRoot 'scripts\release\open-pr.ps1'
$openPrText = [System.IO.File]::ReadAllText($openPrPath)
Assert-True ($openPrText -match [regex]::Escape("lib\pr-overlap-lib.ps1")) 'open-pr.ps1 dot-sources the lib'
Assert-True ($openPrText -match [regex]::Escape('Get-OpenPrPathRecords')) 'it parses the payload through the lib'
Assert-True ($openPrText -match [regex]::Escape('Get-PrOverlapFindings')) 'it intersects through the lib'
Assert-True ($openPrText -match [regex]::Escape('Format-PrOverlapNote'))  'it words the note through the lib'
Assert-True ($openPrText -match 'gh''\s*,\s*-Arguments\s*@\(''pr'',\s*''list''' -or
             $openPrText -match [regex]::Escape("'pr', 'list', '--state', 'open', '--json', 'number,title,headRefName,files'")) 'it asks gh for exactly the four fields the parse reads'

# THE THREE ENDINGS. The same three the machine-local note (#1559) is repeated at: everything printed
# before the gates is off-screen by the time anybody reads an ending, so a note printed once is
# invisible on exactly the runs that matter.
$reprints = @([regex]::Matches($openPrText, [regex]::Escape('if ($overlapNote) { Write-Warning $overlapNote }')))
Assert-Equal 3 $reprints.Count 'the note is re-printed at all three of open-pr.ps1''s endings'
$mlReprints = @([regex]::Matches($openPrText, [regex]::Escape('if ($machineLocalNote) { Write-Warning $machineLocalNote }')))
Assert-Equal $mlReprints.Count $reprints.Count 'and at exactly the same endings as the machine-local note it follows'

# IT MUST NOT BE ABLE TO BLOCK. The scan is advisory by construction, so nothing in its block exits.
$overlapBlock = ''
if ($openPrText -match '(?s)# --- Overlap scan \(issue #2315\).*?# --- Always-on budget gate') { $overlapBlock = $Matches[0] }
Assert-True ($overlapBlock.Length -gt 0) 'the overlap scan block is findable by its own banner'
Assert-True ($overlapBlock -notmatch '(?m)^\s*exit\s') 'nothing in the overlap scan exits -- it warns, it never refuses'
Assert-True ($overlapBlock -notmatch 'Write-Error') 'and it raises no error either'
# THE SCAN IS BOUNDED, like every other network call in this workflow (#1639): a stall here would sit
# in front of the gates rather than failing loudly.
Assert-True ($overlapBlock -match [regex]::Escape('-TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds')) 'the gh call passes the shared network bound'
# AND NO --base: a trunk named wrongly here would filter the list and print the CLEAN line over PRs
# that were never compared, which is the one failure in this block that is silent.
Assert-True ($overlapBlock -notmatch "'--base'") 'the gh call names no base -- a wrong one would go quiet rather than loud'

# --- 6. the mirror ----------------------------------------------------------------------------------
Write-Host ''
Write-Host '6. the mirror' -ForegroundColor Cyan

$pairs = @(Get-SharedScriptPairs -RepoRoot $RepoRoot)
$pair = @($pairs | Where-Object { $_.Name -eq 'pr-overlap-lib' })
Assert-Equal 1 $pair.Count 'the lib is registered as a shared script'
if ($pair.Count -eq 1) {
    Assert-True ([bool]$pair[0].LibOnly) 'registered as LibOnly -- it is dot-sourced, it resolves no repo root of its own'
    Assert-Equal 'dkj-policy' $pair[0].Plugin 'it travels in the workflow plugin, where open-pr.ps1 already does'
    Assert-True (Test-Path -LiteralPath $pair[0].MirrorPath) 'the plugin mirror exists'
    if (Test-Path -LiteralPath $pair[0].MirrorPath) {
        $srcText    = Get-NormalizedScriptContent -Path $pair[0].SourcePath
        $mirrorText = Get-NormalizedScriptContent -Path $pair[0].MirrorPath
        Assert-Equal $srcText $mirrorText 'the mirror is identical to the source -- a consumer runs the same scan'
    }
}

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host "FAILS: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
