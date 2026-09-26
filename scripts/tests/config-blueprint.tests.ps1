<#
.SYNOPSIS
    Regression tests for the config blueprint (issue #456): the Adopt axis in the contract registry,
    the generator that derives the artefact from this repo's own libs, and the adopt-config command
    that a consumer runs against it.

.DESCRIPTION
    Dependency-free: no Pester, plain PowerShell. Integration-style where it matters -- the adopt
    scenarios run the REAL script in a child process against throwaway consumer fixtures, and assert
    on what actually lands in the fixture's files.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/config-blueprint.tests.ps1

    THE THREE EXTRACTION BUGS BELOW WERE REAL, none of them found by reasoning -- the first two by
    reading the first generated artefact, the third by reading a file adopt-config had written in a
    consumer. Each has its own assert here:

      1. a structural walk that stopped only at the previous '}' swept up whatever sat between two
         functions -- Get-LiveStage came out carrying the retirement note of Get-ChangelogTierHeADINGS,
         a comment block about a different, deleted function;
      2. four functions in repo-config.ps1 share ONE assignment block, so three of them extracted
         without the '$script:' value they read -- copied on their own they would have returned $null
         in the consumer, a silent wrong answer where an absent function gets the documented fallback;
      3. the mirror of 2, and the reason it needed its own measurement: the same walk handed the FIRST
         of those four all four values, so with 2 repaired both records shipped the same assignment and
         a consumer's placed lib assigned three variables twice, the second silently winning. Nothing
         errors and the file is correct until somebody edits it -- and these four strings exist to be
         translated, which is the one act that meets it (inbound #1126, measured in ccs-testrun-3).

    Pure ASCII (repo convention for .ps1).

    Test-gaps (honest):
      - The blueprint is generated from THIS repo's real libs, so the generator is never exercised
        against a lib shaped differently (no '$script:' assignments at all, a function defined inside
        an if-block). That is deliberate: the generator is the source's own tool and only ever reads
        this tree.
      - adopt-config's "seam lib missing entirely" branch is exercised, but the pointer it prints at
        specialists-init is asserted only by its text, not by running that skill.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Generator  = Join-Path $RepoRoot 'scripts\sync\build-config-blueprint.ps1'
$Adopt      = Join-Path $RepoRoot 'scripts\task\adopt-config.ps1'
$ContractLib = Join-Path $RepoRoot 'scripts\lib\script-contract-lib.ps1'
$Artefact   = Join-Path $RepoRoot 'plugins\dkj-policy\blueprint\config-blueprint.json'
$Fixture    = Join-Path ([System.IO.Path]::GetTempPath()) "config-blueprint-test-fixture-$PID-$([guid]::NewGuid().ToString('n'))"

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
    param([string]$Pattern, [string]$Text, [string]$Name)
    if ($Text -match $Pattern) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         pattern not found: '$Pattern'" -ForegroundColor Red
    }
}

function Assert-NotMatch {
    param([string]$Pattern, [string]$Text, [string]$Name)
    if ($Text -notmatch $Pattern) {
        $script:pass++; Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:fail++; Write-Host "  [FAIL] $Name`n         pattern present but should not be: '$Pattern'" -ForegroundColor Red
    }
}

function New-ConsumerFixture {
    <# A throwaway consumer with a seam that predates most of the contract: it answers Get-RepoName
       with its OWN value, so the "never overwrites" rule has something real to protect. #>
    param([string]$Path, [switch]$NoRepoConfig)

    if (Test-Path -LiteralPath $Path) { Remove-Item -Recurse -Force -LiteralPath $Path }
    New-Item -ItemType Directory -Force -Path (Join-Path $Path 'scripts\lib') | Out-Null

    if (-not $NoRepoConfig) {
        Set-Content -LiteralPath (Join-Path $Path 'scripts\repo-config.ps1') -Encoding ascii -Value @(
            '# A consumer seam that predates most of the contract.',
            "`$script:RepoName = 'someone/their-repo'",
            'function Get-RepoName { return $script:RepoName }'
        )
    }
    Set-Content -LiteralPath (Join-Path $Path 'scripts\lib\branch-info.ps1') -Encoding ascii -Value @(
        'function Get-BranchInfo { param($Branch) return [pscustomobject]@{ Branch = $Branch } }'
    )
}

function Invoke-Adopt {
    param([string]$ConsumerRoot, [string[]]$ScriptArgs = @())
    $prev = $env:CLAUDE_PROJECT_DIR
    $env:CLAUDE_PROJECT_DIR = $ConsumerRoot
    try {
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Adopt @ScriptArgs
        return [pscustomobject]@{ Code = $LASTEXITCODE; Out = ($out -join "`n") }
    } finally {
        $env:CLAUDE_PROJECT_DIR = $prev
    }
}

try {

Write-Host "`n== the Adopt axis in the contract registry ==" -ForegroundColor Cyan

. $ContractLib
$contract = Get-ScriptContract

# THE COMPLETENESS GUARD, and it is the whole reason the marker lives beside the registration rather
# than in a list of its own: a record added without an Adopt marker would otherwise be classified by
# whatever the reader defaults to, silently.
$noAdopt = @($contract | Where-Object { -not $_.ContainsKey('Adopt') })
Assert-Equal 0 $noAdopt.Count "every contract record declares Adopt (missing: $($noAdopt.Function -join ', '))"

$badValue = @($contract | Where-Object { $_.ContainsKey('Adopt') -and $_.Adopt -notin @('copy', 'decide') })
Assert-Equal 0 $badValue.Count 'every Adopt value is copy or decide'

$noWhy = @($contract | Where-Object { -not $_.ContainsKey('AdoptWhy') -or -not $_.AdoptWhy })
Assert-Equal 0 $noWhy.Count "every record explains its marker (missing AdoptWhy: $($noWhy.Function -join ', '))"

# The same rule the registry already states for Returns: a report marker inside a record's prose is
# counted by the session hook and by this repo's own asserts, so writing one here inflates the counts.
$markerInWhy = @($contract | Where-Object { $_.ContainsKey('AdoptWhy') -and $_.AdoptWhy -match '\[(ERROR|INFO|OK|BOOTSTRAP)\]' })
Assert-Equal 0 $markerInWhy.Count 'no AdoptWhy text contains a report marker that counters would pick up'

# The four the issue named, plus Get-RepoName -- the case that is obvious under this question and was
# absent from the issue's list because it answers a different one.
foreach ($fn in 'Get-ReservedRootMd', 'Get-ReleasePluginTier', 'Get-ReleaseConsumerBumps', 'Get-ReleaseMajorMinMinors', 'Get-RepoName') {
    $rec = $contract | Where-Object { $_.Function -eq $fn }
    Assert-Equal 'decide' $rec.Adopt "$fn is the consumer's to decide"
}

# AND THE ONE THAT WAS MARKED 'copy' UNTIL AUGUST 10, 2026 (inbound #560). It belongs in the family
# directly above -- same three functions, same question -- and was justified on the value being harmless
# rather than on the question being shared: 'major' is also the built-in fallback, so copying it "changes no
# behaviour". True of the value, false of the question. Measured in a consumer foldering per minor since
# v2.0.0: 'major' was placed into their seam unseen and their next cut would have started a second
# releases/development/ tree beside fourteen directories of history. Its own assert, with its own reason,
# because that reasoning is what has to fail if anyone reclassifies it back.
$grpRec = $contract | Where-Object { $_.Function -eq 'Get-ReleaseNotesGrouping' }
Assert-Equal 'decide' $grpRec.Adopt 'Get-ReleaseNotesGrouping describes a TREE, not a way of working -- so it is proposed, never placed'
Assert-Match 'releases/changelog' $grpRec.Returns 'and its Returns text names the tree the answer is read off, so a decider does not have to guess (the tier-0 directory renamed development -> changelog in #914; the assert follows the current name, because a decider compares it against a tree they have TODAY)'

# branch-info.ps1 says of ITSELF that it is repo-owned and does not travel, and its refusal of 'chore/'
# is written down as this repo's rule. Both records were classified 'copy' on the first pass; this
# assert is what stops that returning.
foreach ($fn in 'Get-BranchInfo', 'Test-BranchName') {
    $rec = $contract | Where-Object { $_.Function -eq $fn }
    Assert-Equal 'decide' $rec.Adopt "$fn stays repo-owned -- branch-info.ps1 declares itself so"
}

Write-Host "`n== the generated artefact ==" -ForegroundColor Cyan

Assert-True (Test-Path -LiteralPath $Artefact -PathType Leaf) 'the blueprint artefact is committed'

$bp = Get-Content -LiteralPath $Artefact -Raw | ConvertFrom-Json
Assert-Equal $contract.Count $bp.records.Count 'the artefact carries exactly one record per contract entry'
Assert-Equal 'DKJ-Solutions/dkj-claude-plugins' $bp.sourceRepo 'the artefact names the repo it came from'

# In sync with the libs as they stand right now. This is the same thing the lint gate runs; asserting
# it here too means a stale artefact fails the suite rather than only the gate.
& powershell -NoProfile -ExecutionPolicy Bypass -File $Generator -Check | Out-Null
Assert-Equal 0 $LASTEXITCODE 'the committed artefact matches a fresh generation'

# --- Extraction bug 1: a foreign comment block must not travel as a function's reasoning ------------
$liveStage = $bp.records | Where-Object { $_.function -eq 'Get-LiveStage' }
Assert-Match 'go live' $liveStage.text 'Get-LiveStage carries its own reasoning'
Assert-NotMatch 'Get-ChangelogTierHeadings' $liveStage.text 'Get-LiveStage does NOT carry the retirement note of a different function'

$grouping = $bp.records | Where-Object { $_.function -eq 'Get-ReleaseNotesGrouping' }
Assert-NotMatch 'the LIVE marker' $grouping.text 'Get-ReleaseNotesGrouping does NOT carry the six-knob preamble above its block'

# --- Extraction bug 2: a function must carry every value it reads ----------------------------------
# Three of the four entry-wording functions sit BELOW the shared assignment block, so a contiguous walk
# alone leaves them without their value.
#
# Read through the PARSER here as well, deliberately duplicating the generator's approach rather than
# its code: a text scan reports a '$script:' name that a COMMENT points at (measured -- one block cites
# a variable living in another file entirely), and an assert built on that would fail on correct
# output. A test that re-derives the fact independently is worth more here than one sharing the helper.
function Get-ReadVars {
    param([string]$Text)
    $t = $null; $e = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$t, [ref]$e)
    if ($e -and $e.Count -gt 0) { return @() }
    return @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] }, $true) |
        Where-Object { $_.VariablePath.UserPath -like 'script:*' } |
        ForEach-Object { $_.VariablePath.UserPath.Substring(7) } | Sort-Object -Unique)
}

foreach ($rec in @($bp.records | Where-Object { $_.declared -and $_.text })) {
    $reads = Get-ReadVars -Text $rec.text
    foreach ($name in $reads) {
        $assigned = $rec.text -match ('(?m)^\s*\$script:' + [regex]::Escape($name) + '\s*=')
        Assert-True $assigned "$($rec.function): carries the assignment for `$script:$name that it reads"
    }
}

# --- Extraction bug 3: a record must not carry a value belonging to a SIBLING -----------------------
# The exact mirror of bug 2, and it had to be measured separately (inbound #1126): the contiguous walk
# that leaves the three LOWER functions valueless hands all four values to the FIRST one. Both records
# then ship the same assignment, so the repo-config.ps1 adopt-config writes assigns three variables
# twice with the second silently winning -- and these four strings are precisely the ones a consumer
# TRANSLATES, so the second assignment quietly puts the English back.
#
# ASSIGNMENTS READ THROUGH THE PARSER TOO, not by regex, for the reason the loop above already gives:
# in prose these names appear as text, and one of these very comment blocks cites a variable that lives
# in another file. That every record's text parses standalone is asserted first, because on a parse
# failure all three helpers return nothing and every assert below would pass vacuously.
#
# AND THE READS COME FROM THE FUNCTION ALONE, not from Get-ReadVars over the whole text -- the loop for
# bug 2 asks a different question and its helper cannot answer this one. To the parser the left of
# '$script:X = 1' is a VariableExpressionAst exactly like a read, so over the whole record every
# assignment counts as its own justification and the assert below could never fail. Measured: written
# that way it passed on the unrepaired artefact carrying all three duplicates.
function Get-FunctionReadVars {
    param([string]$Text, [string]$Name)
    $t = $null; $e = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$t, [ref]$e)
    if ($e -and $e.Count -gt 0) { return @() }
    $fn = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
        Where-Object { $_.Name -eq $Name })
    if ($fn.Count -eq 0) { return @() }
    return @($fn[0].FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] }, $true) |
        Where-Object { $_.VariablePath.UserPath -like 'script:*' } |
        ForEach-Object { $_.VariablePath.UserPath.Substring(7) } | Sort-Object -Unique)
}

function Get-AssignedVars {
    param([string]$Text)
    $t = $null; $e = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$t, [ref]$e)
    if ($e -and $e.Count -gt 0) { return @() }
    return @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true) |
        ForEach-Object { $_.Left } |
        Where-Object { $_ -is [System.Management.Automation.Language.VariableExpressionAst] -and $_.VariablePath.UserPath -like 'script:*' } |
        ForEach-Object { $_.VariablePath.UserPath.Substring(7) } | Sort-Object -Unique)
}

$assigners = @{}
foreach ($rec in @($bp.records | Where-Object { $_.declared -and $_.text })) {
    $t = $null; $e = $null
    [System.Management.Automation.Language.Parser]::ParseInput($rec.text, [ref]$t, [ref]$e) | Out-Null
    Assert-True (-not ($e -and $e.Count -gt 0)) "$($rec.function): its text parses on its own -- what a consumer pastes in has to"

    # Its own function must actually exist in the text, or the reads below are empty and every assert
    # in this loop goes vacuous in the other direction.
    $reads = Get-FunctionReadVars -Text $rec.text -Name $rec.function
    Assert-True ($reads.Count -gt 0 -or (Get-AssignedVars -Text $rec.text).Count -eq 0) "$($rec.function): its own definition is in its text and reads at least one `$script: value"

    foreach ($name in (Get-AssignedVars -Text $rec.text)) {
        Assert-True ($reads -contains $name) "$($rec.function): carries no `$script:$name it never reads"
        if (-not $assigners.ContainsKey($name)) { $assigners[$name] = @() }
        $assigners[$name] += $rec.function
    }
}

# The cross-record half, and the one that actually names the defect: two 'copy' records that both
# assign the same variable place it twice in one file.
$shared = @($assigners.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 })
$sharedNames = ($shared | ForEach-Object { "$($_.Key) <- $($_.Value -join ' + ')" }) -join '; '
Assert-Equal 0 $shared.Count "no `$script: variable is assigned by more than one record ($sharedNames)"

# The source leaves seven contract functions at the built-in fallback: the two impact-table seams,
# Get-TestCommands since inbound #644 (this repo's suites are all PowerShell), Get-EntryGateExemptPrefixes
# since inbound #789 (this repo runs no mirror branches, so 'sync' being the default IS its answer), and
# Get-ReleasePageMasthead since inbound #809 (this repo has no wordmark to put on its page) -- five, until
# issue #885 added four more (Get-ChangelogPath, Get-ReleaseChangelogNotesRoot, Get-ReleaseGithubNotesRoot,
# Get-ReleaseInternalNotesRoot), each with a computed default that already stated this repo's own answer
# without an explicit declaration (see each record's own AdoptWhy). Recorded as declared=false with no text
# rather than dropped, because "this repo does not state it either" is an answer -- and the honest one to
# hand a consumer.
#
# NINE UNTIL AUGUST 27, 2026, when this repo moved its changelog and its release history into
# dkj-policy/ and therefore had to STATE Get-ChangelogPath and Get-ReleaseInternalNotesRoot --
# the first to differ from its own computed answer, the second because that one still branches on the
# source and would have recreated the root releases/ directory the move had just emptied. The two roots
# whose defaults stopped branching at #914 are still unstated, which is why it was seven and not five.
#
# EIGHT SINCE SEPTEMBER 11, 2026 (#1870): Get-ReachLabel joined, and it is the cleanest member of this
# set. The seam names the STRING a tracker stores for the reach label, the workflow's default is 'minor',
# and this repo's label is called exactly that -- so a function here would restate the default and become
# a value somebody has to maintain. Recorded as declared=false, which tells a consumer the truth: the
# source does not state it either, and neither should they unless their own label is spelled otherwise.
#
# NINE SINCE SEPTEMBER 18, 2026 (inbound #2120): Get-ResolvesExemptMatchers joined, and it is the member
# of this set whose silence is the feature. The seam names the text that marks an issue a MERGE MUST NOT
# CLOSE -- a ticket-mirror marker, a task link -- and those markers belong to another system entirely. A
# built-in default would be one family's tracker imposed on every consumer, so the workflow's answer is
# "nothing", the gate is silent, and it makes no extra `gh` call at all. This repo runs no such mirror,
# so its own answer IS that default; recorded as declared=false, which tells a consumer exactly that.
#
# TEN SINCE SEPTEMBER 21, 2026 (#2236): Get-DeclinedAdoptions joined, and it is the member of this set the
# source repo can never leave. The seam names the adopt-* commands a repo has decided against, and the
# adoption section that reads it is SKIPPED here -- every file-placing adopter refuses in the repo that
# publishes this workflow -- so an answer would be dead text declining commands that refuse anyway.
# Recorded as declared=false, which tells a consumer the useful thing: the source states nothing, and the
# reason is peculiar to the source rather than advice a consumer should copy.
$undeclared = @($bp.records | Where-Object { -not $_.declared })
Assert-Equal 10 $undeclared.Count 'the ten functions the source itself leaves at the fallback are recorded, not dropped'
foreach ($rec in $undeclared) {
    Assert-Equal '' $rec.text "$($rec.function): an undeclared record carries no text to copy"
}

Write-Host "`n== adopt-config against a fresh consumer ==" -ForegroundColor Cyan

New-ConsumerFixture -Path $Fixture
$repoConfig = Join-Path $Fixture 'scripts\repo-config.ps1'
$before = [System.IO.File]::ReadAllText($repoConfig)

# --- Dry run writes nothing -----------------------------------------------------------------------
$r = Invoke-Adopt -ConsumerRoot $Fixture
Assert-Equal 0 $r.Code 'dry run: exit 0'
Assert-Match 'DRY RUN' $r.Out 'dry run: says so'
# The copy example is Get-RosterPath. It was Get-ReleaseNotesGrouping until August 10, 2026, when that
# record became a decide one (#560) -- so this line asserted the classification the repair reverses.
Assert-Match '\[copy\]\s+Get-RosterPath' $r.Out 'dry run: names a value it would place'
Assert-Match '\[decide\]\s+Get-ReleasePluginTier' $r.Out 'dry run: names a value it would only propose'
Assert-Match '\[decide\]\s+Get-ReleaseNotesGrouping' $r.Out 'dry run: and the foldering scheme is among the ones it would only propose (#560)'
Assert-Equal $before ([System.IO.File]::ReadAllText($repoConfig)) 'dry run: the consumer lib is byte-identical afterwards'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $Fixture 'config-adoption-proposal.md'))) 'dry run: no proposal document is written'

# --- Apply ----------------------------------------------------------------------------------------
$r = Invoke-Adopt -ConsumerRoot $Fixture -ScriptArgs @('-Apply')
Assert-Equal 0 $r.Code 'apply: exit 0'

$after = [System.IO.File]::ReadAllText($repoConfig)
Assert-Match 'Get-RosterPath' $after 'apply: a copy record landed in the consumer lib'
Assert-Match 'Adopted from the DKJ-Solutions/dkj-claude-plugins config blueprint' $after 'apply: the placed block says where it came from'

# NEVER OVERWRITES: the consumer's own answer survives, and the source's is not appended beside it.
Assert-Match "someone/their-repo" $after "apply: the consumer's own Get-RepoName value is untouched"
Assert-NotMatch 'DKJ-Solutions/dkj-claude-plugins.{0,40}Single place this is stated' $after "apply: the source's repo name was not written into the consumer"

# A decide record is proposed and NEVER placed -- the assert that protects the whole doctrine.
# Get-ReleaseNotesGrouping joined the list on August 10, 2026 (#560), and it is the case that shows what the
# doctrine is FOR: this is the value a consumer was measured to have received wrongly, and the only signal
# would have been a second releases/development/ tree appearing at their next cut.
foreach ($fn in 'Get-ReleasePluginTier', 'Get-ReservedRootMd', 'Get-PrMergeMethod', 'Get-LintScript', 'Get-ReleaseNotesGrouping') {
    Assert-NotMatch ("(?m)^\s*function\s+$fn\b") $after "apply: '$fn' was NOT defined in the consumer lib"
}

$proposal = Join-Path $Fixture 'config-adoption-proposal.md'
Assert-True (Test-Path -LiteralPath $proposal -PathType Leaf) 'apply: the proposal document exists'
$prop = [System.IO.File]::ReadAllText($proposal)
Assert-Match '## `Get-ReleasePluginTier`' $prop 'proposal: one section per decision'
Assert-Match 'Why this is yours to decide' $prop 'proposal: each section carries the reason'
Assert-Match 'do not paste this in unadapted' $prop "proposal: the source's version is marked as reference"
# #560's user-visible half: the reclassified record now reaches the document a person actually answers, and
# it arrives with the way to look the answer up rather than only the question.
Assert-Match '## `Get-ReleaseNotesGrouping`' $prop 'proposal: the foldering scheme is asked rather than assumed (#560)'
Assert-Match 'READ IT OFF YOUR EXISTING TREE' $prop 'proposal: and it says the answer is readable off the existing directories, so it is a lookup rather than a choice'

# The placed functions must actually ANSWER in the consumer -- the thing extraction bug 2 broke.
$answers = & {
    Set-StrictMode -Off
    . $args[0]
    [pscustomobject]@{
        RepoName    = Get-RepoName
        RosterPath  = Get-RosterPath
        # Get-ReleaseNotesGrouping used to be read here as a third adopted answer. It is a decide record
        # since August 10, 2026 (#560), so it is deliberately NOT defined in the consumer and calling it
        # would fail on a command that does not exist -- which is the correct outcome, asserted in the
        # not-placed loop above rather than by reading a value that should not be there.
        HistoryPath = Get-ReleaseHistoryPath
        BodyHolder  = Get-EntryBodyPlaceholder
        Fallback    = Get-EntryFallbackType
    }
} $repoConfig
Assert-Equal 'someone/their-repo' $answers.RepoName 'the consumer keeps its own repo name'
Assert-Equal '.claude/specialists/SPECIALISTS.md' $answers.RosterPath 'an adopted function answers'
Assert-Equal 'dkj-policy/releases/history.md' $answers.HistoryPath 'an adopted function answers (in the workflow folder since August 27, 2026, which reverses the August 19 answer: the durability worry that sent the list back to the repo root was answered by #885 making that folder permanent)'
Assert-Equal 'Chore' $answers.Fallback 'an adopted function answers'
Assert-True ($null -ne $answers.BodyHolder -and $answers.BodyHolder.Length -gt 0) 'a function that sits below the shared assignment block still answers (extraction bug 2)'

# AND EACH OF THE FOUR IS ASSIGNED EXACTLY ONCE IN THE PLACED FILE (extraction bug 3, inbound #1126).
# Every assert above passes with the duplicates still in: the two assignments carry the same value, so
# the function answers correctly either way. That is why this one COUNTS rather than reads, and why it
# runs here rather than only on the artefact -- the placed lib is the file a consumer opens to
# translate these four strings, and the second assignment is what would silently undo that.
foreach ($name in 'EntryTitlePlaceholder', 'EntryBodyHeading', 'EntryBodyPlaceholder', 'EntryFallbackType') {
    $count = ([regex]::Matches($after, ('(?m)^\s*\$script:' + [regex]::Escape($name) + '\s*='))).Count
    Assert-Equal 1 $count "apply: `$script:$name is assigned exactly once in the placed lib"
}

# --- Idempotent -----------------------------------------------------------------------------------
$r = Invoke-Adopt -ConsumerRoot $Fixture -ScriptArgs @('-Apply')
Assert-Equal 0 $r.Code 're-run: exit 0'
Assert-Match 'to place \(copy\):\s+0' $r.Out 're-run: nothing left to place'
Assert-Equal $after ([System.IO.File]::ReadAllText($repoConfig)) 're-run: the lib is byte-identical -- nothing was appended twice'

# --- A repo that has not been bootstrapped at all --------------------------------------------------
$bare = Join-Path $Fixture '..\config-blueprint-test-bare'
New-ConsumerFixture -Path $bare -NoRepoConfig
$r = Invoke-Adopt -ConsumerRoot (Resolve-Path -LiteralPath $bare).Path
Assert-Equal 1 $r.Code 'missing seam lib: exits non-zero'
Assert-Match 'specialists-init' $r.Out 'missing seam lib: points at the bootstrap rather than half-creating one'
Remove-Item -Recurse -Force -LiteralPath $bare -ErrorAction SilentlyContinue

# --- A junctioned scripts/ and a proposal path outside the repo (issue #2546) ----------------------
# The append into the seam lib and the proposal write are both refused. The fixture's scripts/ is moved
# out and replaced by a junction to it, so the run still reads the libs it needs. A junction needs no
# privilege; it is removed with rmdir, never recursively, or the delete would empty its target.
$jFixture = Join-Path $Fixture '..\config-blueprint-test-junction'
$jOutside = Join-Path $Fixture '..\config-blueprint-test-junction-outside'
New-ConsumerFixture -Path $jFixture
if (Test-Path -LiteralPath $jOutside) { Remove-Item -Recurse -Force -LiteralPath $jOutside }
Move-Item -LiteralPath (Join-Path $jFixture 'scripts') -Destination $jOutside
& cmd /c mklink /J "$(Join-Path $jFixture 'scripts')" "$((Resolve-Path -LiteralPath $jOutside).Path)" | Out-Null
try {
    $jBefore = [System.IO.File]::ReadAllText((Join-Path $jOutside 'repo-config.ps1'))
    # The dry run shows the refusal -Apply will make, rather than a plan that silently will not happen.
    $r = Invoke-Adopt -ConsumerRoot (Resolve-Path -LiteralPath $jFixture).Path
    Assert-Match '\[refused\] scripts[\\/]repo-config\.ps1' $r.Out 'junction: the dry run already names the refusal'
    # A drive-rooted -ProposalPath is refused as outside the repo; Join-Path used to glue it onto the root
    # as a two-drive string that crashed the run in GetFullPath.
    $absProposal = Join-Path ([System.IO.Path]::GetTempPath()) "config-blueprint-abs-$PID.md"
    $r = Invoke-Adopt -ConsumerRoot (Resolve-Path -LiteralPath $jFixture).Path -ScriptArgs @('-ProposalPath', $absProposal)
    Assert-Equal 0 $r.Code 'junction: an absolute proposal path does not crash the run'
    Assert-Match ('\[refused\] ' + [regex]::Escape($absProposal)) $r.Out 'junction: and it is refused as outside the repo'
    $r = Invoke-Adopt -ConsumerRoot (Resolve-Path -LiteralPath $jFixture).Path -ScriptArgs @('-Apply', '-ProposalPath', '..\config-blueprint-escape.md')
    Assert-Equal 0 $r.Code 'junction: exit 0 -- a refusal is not a failed run'
    Assert-Equal $jBefore ([System.IO.File]::ReadAllText((Join-Path $jOutside 'repo-config.ps1'))) 'junction: the lib outside the repo is untouched'
    Assert-Match '\[refused\] scripts[\\/]repo-config\.ps1' $r.Out 'junction: the seam append is reported refused'
    Assert-Match '\[refused\] \.\.\\config-blueprint-escape\.md' $r.Out 'junction: a proposal path outside the repo is refused'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Fixture '..\config-blueprint-escape.md'))) 'junction: and nothing was written there'
} finally {
    & cmd /c rmdir "$(Join-Path $jFixture 'scripts')" | Out-Null
    foreach ($d in $jFixture, $jOutside) { Remove-Item -Recurse -Force -LiteralPath $d -ErrorAction SilentlyContinue }
}

# --- The plugin mirror, run from its OWN depth (issue #1857) ---------------------------------------
# check-plugin-integrity's check 8 proves this script and its mirror are byte-identical, and that is
# exactly what hides the difference here: Resolve-Blueprint's FIRST candidate is
# '..\..\blueprint\config-blueprint.json', two levels up from $PSScriptRoot -- the repo root from the
# source copy and the PLUGIN root from the mirror. Same characters, different folder.
#
# EVERY ASSERT ABOVE RUNS THE SOURCE COPY, so all of them exercise the workshop fallbacks and none of
# them exercises candidate 1 -- the one that fires in every released install. It was verified by hand
# when the candidate was introduced, which is what #1857 was filed about.
#
# AND THE MIRROR HAS NO SECOND ROUTE, which is what makes this assert worth its seconds rather than a
# duplicate of the one above. The fallbacks are derived from plugin roots under $PSScriptRoot\..\..
# and under $RepoRoot: from the mirror the first is plugins\dkj-policy\, which publishes no
# marketplace, and the second is this fixture, which publishes nothing at all. Both yield zero roots,
# so a pass here can only mean candidate 1 resolved.
$mirrorAdopt = Join-Path $RepoRoot 'plugins\dkj-policy\scripts\task\adopt-config.ps1'
Assert-True (Test-Path -LiteralPath $mirrorAdopt -PathType Leaf) 'the plugin mirror exists at the registered path'

$mirrorFixture = Join-Path $Fixture '..\config-blueprint-test-mirror'
New-ConsumerFixture -Path $mirrorFixture
$mirrorFixture = (Resolve-Path -LiteralPath $mirrorFixture).Path
$mirrorConfig = Join-Path $mirrorFixture 'scripts\repo-config.ps1'
try {
    $prevProjectDir = $env:CLAUDE_PROJECT_DIR
    $env:CLAUDE_PROJECT_DIR = $mirrorFixture
    try {
        $mirrorOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $mirrorAdopt '-Apply'
        $mirrorCode = $LASTEXITCODE
    } finally { $env:CLAUDE_PROJECT_DIR = $prevProjectDir }

    Assert-Equal 0 $mirrorCode 'mirror: exit 0 -- it found the blueprint beside itself, with no workshop root to fall back on'
    $mirrorAfter = [System.IO.File]::ReadAllText($mirrorConfig)
    Assert-Match 'Get-RosterPath' $mirrorAfter 'mirror: a copy record landed in the consumer lib, so the artefact it read was the real one'
    Assert-Match 'Adopted from the DKJ-Solutions/dkj-claude-plugins config blueprint' $mirrorAfter 'mirror: the placed block says where it came from'
    # The doctrine assert, repeated on this side on purpose: the two copies could only diverge by
    # reading a different artefact, and a decide record leaking through is what that would look like.
    Assert-NotMatch '(?m)^\s*function\s+Get-ReleasePluginTier\b' $mirrorAfter "mirror: a decide record was still NOT placed"
} finally {
    Remove-Item -Recurse -Force -LiteralPath $mirrorFixture -ErrorAction SilentlyContinue
}

} finally {
    if (Test-Path -LiteralPath $Fixture) { Remove-Item -Recurse -Force -LiteralPath $Fixture -ErrorAction SilentlyContinue }
}

Write-Host "`nResult: $($script:pass) pass, $($script:fail) fail." -ForegroundColor $(if ($script:fail -gt 0) { 'Red' } else { 'Green' })
if ($script:fail -gt 0) { exit 1 }
exit 0
