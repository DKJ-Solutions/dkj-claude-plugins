<#
.SYNOPSIS
    Tests for scripts/lib/merge-on-green-lib.ps1 -- issue #2319's pure eligibility verdict, used by
    scripts/ci/pick-merge-on-green.ps1 to decide which armed pull request a sweep hands to ship-pr.ps1.

.DESCRIPTION
    PURE FUNCTIONS ONLY -- no git, no gh, no network. Every branch of Get-MergeOnGreenPrVerdict is
    exercised against already-fetched facts, the same split ci-merge-skip-lib.tests.ps1 is written
    under and for the same reason: the reads drive a live remote no suite can reach.

    FAIL-CLOSED IS THE PROPERTY UNDER TEST. The negative cases outnumber the positive one on purpose.
    This verdict cannot let an unsound merge through -- ship-pr.ps1 re-runs every gate afterwards --
    so the cost of a wrong refusal is one sweep of delay, half an hour at the outside, with the pull
    request untouched. The cost of a wrong ACCEPT is a runner started against a pull request nobody armed,
    which is the one outcome the label exists to prevent, so the arming assert below is the load-
    bearing one.

    AND THE VERDICT IS FED THE REAL Get-MergeBlockVerdict, not only hand-built stand-ins. A pure
    function tested against a shape its caller never produces is tested against nothing, and this one
    reads two fields (Blocked, UnfinishedRequired) of an object defined in another file.

    Dependency-free (no Pester), same style as the rest of the suite. Pure ASCII.
#>
$ErrorActionPreference = 'Stop'

$RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$LibPath    = Join-Path $RepoRoot 'scripts\lib\merge-on-green-lib.ps1'
$PrLibPath  = Join-Path $RepoRoot 'scripts\lib\pr-issues-lib.ps1'
$ScriptPath = Join-Path $RepoRoot 'scripts\ci\pick-merge-on-green.ps1'
$FlowPath   = Join-Path $RepoRoot '.github\workflows\merge-on-green.yml'
$ShipPath   = Join-Path $RepoRoot 'scripts\release\ship-pr.ps1'

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

Assert-True (Test-Path -LiteralPath $LibPath) 'merge-on-green-lib.ps1 exists at its registered source path'
. $LibPath
. $PrLibPath
# Test-FunctionDefined (issue #1729), NOT a raw Get-Command probe -- section 5's own gate below refuses
# exactly that idiom for a hyphenated function name outside its named exceptions, and this file is not
# one of them.
. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')

# ---------------------------------------------------------------------------------------------
function New-PrRecord {
    param(
        [int]$Number = 10,
        [string]$Branch = 'feat/1-x',
        [bool]$Draft = $false,
        [string]$Mergeable = 'MERGEABLE',
        [string[]]$Labels = @('merge-when-green'),
        [bool]$CrossRepo = $false,
        # A diff that touches nothing the runner executes -- the ordinary shape of an armed docs PR.
        [string[]]$Files = @('dkj-policy/feat-1-x.md', 'README.md'),
        [int]$ChangedFiles = -1
    )
    return [pscustomobject]@{
        number            = $Number
        headRefName       = $Branch
        isDraft           = $Draft
        mergeable         = $Mergeable
        isCrossRepository = $CrossRepo
        labels            = @($Labels | ForEach-Object { [pscustomobject]@{ name = $_ } })
        files             = @($Files | ForEach-Object { [pscustomobject]@{ path = $_; additions = 1; deletions = 0 } })
        changedFiles      = $(if ($ChangedFiles -ge 0) { $ChangedFiles } else { @($Files).Count })
    }
}
function New-Green { return [pscustomobject]@{ Blocked = $false; Reason = 'ok'; UnfinishedRequired = @() } }

Write-Host ''
Write-Host 'Get-MergeOnGreenArmLabel -- the one spelling of the handshake' -ForegroundColor Cyan

Assert-Equal 'merge-when-green' (Get-MergeOnGreenArmLabel) 'the arming label is the one both halves agree on'

Write-Host ''
Write-Host 'ConvertFrom-MergeOnGreenListJson -- one record per pull request, on 5.1 too (#2381)' -ForegroundColor Cyan

# THE REAL PAYLOAD SHAPE, and the suite runs under whichever edition the gate uses -- on CI that is
# Windows PowerShell 5.1, the edition that wrapped the whole array as one record.
$oneJson   = '[{"headRefName":"fix/1-a","isCrossRepository":false,"isDraft":false,"labels":[{"id":"L1","name":"merge-when-green","description":"","color":"0e8a16"}],"mergeable":"MERGEABLE","number":2345}]'
$threeJson = '[{"number":11,"headRefName":"a/1","labels":[]},{"number":12,"headRefName":"a/2","labels":[]},{"number":13,"headRefName":"a/3","labels":[]}]'

$one = @(ConvertFrom-MergeOnGreenListJson -Json $oneJson)
Assert-Equal 1 $one.Count 'a one-element list yields one record'
Assert-True ($one[0].PSObject.Properties['number'] -and $one[0].number -eq 2345) `
    'and that record IS the pull request, carrying its number -- not an array wrapped around it'
Assert-True (Test-MergeOnGreenArmed -Record $one[0]) 'and it reads as armed through the same verdict path the sweep uses'

$three = @(ConvertFrom-MergeOnGreenListJson -Json $threeJson)
Assert-Equal 3 $three.Count 'a three-element list yields three records'
Assert-Equal '11,12,13' (($three | ForEach-Object { $_.number }) -join ',') 'each one its own pull request, in order'

Assert-Equal 0 @(ConvertFrom-MergeOnGreenListJson -Json '[]').Count 'an empty list yields no records'
Assert-Equal 0 @(ConvertFrom-MergeOnGreenListJson -Json '').Count 'and so does empty text'
$threw = $false
try { $null = ConvertFrom-MergeOnGreenListJson -Json 'not json' } catch { $threw = $true }
Assert-True $threw 'text that is not JSON throws, so the caller keeps its fail-closed "could not be parsed" verdict'

# THE SCRIPT MUST GO THROUGH IT. The defect was one line in the script that no pure test could see, so
# the guard is that the line is gone and the function is called instead.
$pickSrc = Get-Content -LiteralPath $ScriptPath -Raw
Assert-True ($pickSrc -match 'ConvertFrom-MergeOnGreenListJson') 'pick-merge-on-green.ps1 parses the list through the lib'
Assert-True ($pickSrc -notmatch '\|\s*ConvertFrom-Json\)') 'and no longer pipes the payload into ConvertFrom-Json inside @()'
Assert-True ($pickSrc -match '\(skipped\)') 'a skipped record prints a line rather than vanishing'
Assert-True ($pickSrc -match 'none could be evaluated') 'and "armed, but no verdicts" is reported as the contradiction it is'

Write-Host ''
Write-Host 'Test-MergeOnGreenArmed' -ForegroundColor Cyan

Assert-True (Test-MergeOnGreenArmed -Record (New-PrRecord)) 'a record carrying the label is armed'
Assert-True (Test-MergeOnGreenArmed -Record (New-PrRecord -Labels @('prio-3', 'merge-when-green', 'minor'))) `
    'and it is found among other labels'
Assert-True (-not (Test-MergeOnGreenArmed -Record (New-PrRecord -Labels @('prio-3')))) 'a record without it is not armed'
Assert-True (-not (Test-MergeOnGreenArmed -Record (New-PrRecord -Labels @()))) 'nor is one with no labels at all'
Assert-True (-not (Test-MergeOnGreenArmed -Record $null)) 'and neither is $null'
# A field gh was never asked for is ABSENT, not empty -- the guard every payload reader in this tree
# carries, because absent is a throw under Set-StrictMode rather than a $false.
Assert-True (-not (Test-MergeOnGreenArmed -Record ([pscustomobject]@{ number = 1 }))) `
    'a record fetched without the labels field is not armed, rather than throwing'
# CASE MATTERS, like every other label comparison GitHub makes on the query side. A near-match is a
# different label, and treating it as the same one would arm on something nobody wrote.
Assert-True (-not (Test-MergeOnGreenArmed -Record (New-PrRecord -Labels @('Merge-When-Green')))) `
    'a differently-cased label is a different label'

Write-Host ''
Write-Host 'Get-MergeOnGreenPrVerdict -- the one path that answers Eligible=$true' -ForegroundColor Cyan

$ok = Get-MergeOnGreenPrVerdict -Record (New-PrRecord) -MergeBlockVerdict (New-Green) -GreenAgeMinutes 30
Assert-True $ok.Eligible 'armed, not a draft, MERGEABLE and every required check green -- eligible'
Assert-True ([bool]$ok.Reason) 'and the Reason is set on the accepting path too'

Write-Host ''
Write-Host 'Get-MergeOnGreenPrVerdict -- every refusal' -ForegroundColor Cyan

Assert-True (-not (Get-MergeOnGreenPrVerdict -Record $null -MergeBlockVerdict (New-Green)).Eligible) `
    'no record at all refuses'

$unarmed = Get-MergeOnGreenPrVerdict -Record (New-PrRecord -Labels @('prio-3')) -MergeBlockVerdict (New-Green)
Assert-True (-not $unarmed.Eligible) 'a green, mergeable, non-draft pull request NOBODY ARMED is refused'
Assert-True ($unarmed.Reason -match 'not armed') 'and the refusal says so in those words'

Assert-True (-not (Get-MergeOnGreenPrVerdict -Record (New-PrRecord -Draft $true) -MergeBlockVerdict (New-Green)).Eligible) `
    'a draft is refused even when armed and green'

# A FORK'S PULL REQUEST IS REFUSED ON ITS OWN AXIS, not left to fail at the checkout. This repository
# is public, so anybody may open one; the label is out of a stranger's reach today, and "is the head ref
# in this repo" is a second, cheaper fact that does not depend on that staying true.
$fork = Get-MergeOnGreenPrVerdict -Record (New-PrRecord -CrossRepo $true) -MergeBlockVerdict (New-Green)
Assert-True (-not $fork.Eligible) 'a cross-repository pull request is refused even when armed, mergeable and green'
Assert-True ($fork.Reason -match 'fork') 'and the refusal says why'

# A DIFF THAT REACHES CODE THE RUNNER EXECUTES IS LEFT TO A SESSION -- issue #2338. The runner checks this
# head out with FOLD_PUSH_TOKEN in the workspace and then runs code from it, so every path it reads code
# from is asked, in the source repo's shape and in a consumer's.
foreach ($hit in @(
    'scripts/release/ship-pr.ps1',                         # the source repo runs the branch's own copy
    'scripts/repo-config.ps1',                             # every repo's ship-pr dot-sources this
    'scripts/lib/branch-info.ps1',                         # and the seam libs beside it
    'plugins/dkj-policy/scripts/lib/merge-on-green-lib.ps1', # the plugin mirror of the same code
    '.github/workflows/merge-on-green.yml',                # the runner itself
    '.workflow-scripts/plugins/dkj-policy/scripts/release/ship-pr.ps1' # a consumer's plugin checkout path
)) {
    $v = Get-MergeOnGreenPrVerdict -Record (New-PrRecord -Files @('README.md', $hit)) -MergeBlockVerdict (New-Green)
    Assert-True (-not $v.Eligible) "a diff touching '$hit' is refused even when armed, mergeable and green"
    Assert-True ($v.Reason -like "*$hit*" -and $v.Reason -match 'session') '...and the refusal names the path and the way through'
}
Assert-True (-not (Get-MergeOnGreenPrVerdict -Record (New-PrRecord -Files @('scripts\repo-config.ps1')) -MergeBlockVerdict (New-Green)).Eligible) `
    'a backslash spelling is the same path'
Assert-True (Get-MergeOnGreenPrVerdict -Record (New-PrRecord -Files @('docs/scripts.md', 'plugins/dkj-policy/README.md')) -MergeBlockVerdict (New-Green) -GreenAgeMinutes 30).Eligible `
    'a path that merely NAMES scripts is not one -- the match is anchored on the directory'
# FAIL-CLOSED ON A LIST THAT DID NOT SHOW THE WHOLE DIFF: gh returns at most 100 files per record.
$truncated = Get-MergeOnGreenPrVerdict -Record (New-PrRecord -Files @('README.md') -ChangedFiles 150) -MergeBlockVerdict (New-Green)
Assert-True (-not $truncated.Eligible) 'a file list shorter than changedFiles is refused -- an unseen path is not a cleared one'
Assert-True ($truncated.Reason -match '1 of its changed files') '...and the refusal says how much it saw'
$noFiles = [pscustomobject]@{ number = 4; headRefName = 'feat/4-x'; isDraft = $false; mergeable = 'MERGEABLE'
    isCrossRepository = $false; labels = @([pscustomobject]@{ name = 'merge-when-green' }) }
Assert-True (-not (Get-MergeOnGreenPrVerdict -Record $noFiles -MergeBlockVerdict (New-Green)).Eligible) `
    'a record fetched without the files field is refused rather than cleared'
$ctrl = Get-MergeOnGreenPrVerdict -Record (New-PrRecord -Files @("scripts/x$([char]0x1b)[2J.ps1")) -MergeBlockVerdict (New-Green)
Assert-True ($ctrl.Reason -notmatch [char]0x1b) 'a control character in a pushed path never reaches the printed reason'

$conflicting = Get-MergeOnGreenPrVerdict -Record (New-PrRecord -Mergeable 'CONFLICTING') -MergeBlockVerdict (New-Green)
Assert-True (-not $conflicting.Eligible) 'CONFLICTING is refused'
Assert-True ($conflicting.Reason -match 'CONFLICTING') 'and the refusal names the state it read'
# UNKNOWN means "GitHub has not finished computing it", i.e. ask again -- which is what the next sweep
# is. Treating it as mergeable would start ship-pr against a branch that may never merge.
Assert-True (-not (Get-MergeOnGreenPrVerdict -Record (New-PrRecord -Mergeable 'UNKNOWN') -MergeBlockVerdict (New-Green)).Eligible) `
    'UNKNOWN mergeability refuses rather than optimistically proceeding'
Assert-True (-not (Get-MergeOnGreenPrVerdict -Record ([pscustomobject]@{ number = 3; labels = @([pscustomobject]@{ name = 'merge-when-green' }) }) -MergeBlockVerdict (New-Green)).Eligible) `
    'a record fetched without the mergeable field refuses, rather than throwing'

Assert-True (-not (Get-MergeOnGreenPrVerdict -Record (New-PrRecord) -MergeBlockVerdict $null).Eligible) `
    'an unreadable required-check state refuses'

$blocked = Get-MergeOnGreenPrVerdict -Record (New-PrRecord) -MergeBlockVerdict ([pscustomobject]@{
    Blocked = $true; Reason = 'lint-en-tests failed'; UnfinishedRequired = @() })
Assert-True (-not $blocked.Eligible) 'a blocked required check refuses'
Assert-Equal 'lint-en-tests failed' $blocked.Reason 'and the verdict borrows the block reason verbatim rather than restating it'

# NOT BLOCKED IS NOT GREEN -- inbound #1549's hole, one caller over: a required check that has not
# REGISTERED yet fails nothing, so Blocked is $false while the certificate does not exist.
$pending = Get-MergeOnGreenPrVerdict -Record (New-PrRecord) -MergeBlockVerdict ([pscustomobject]@{
    Blocked = $false; Reason = 'ok'; UnfinishedRequired = @('lint-en-tests') })
Assert-True (-not $pending.Eligible) 'a required check that has not finished refuses although nothing is blocked'
Assert-True ($pending.Reason -match 'lint-en-tests') 'and it names the check still to come'

Write-Host ''
Write-Host 'Get-MergeOnGreenPrVerdict against the REAL Get-MergeBlockVerdict' -ForegroundColor Cyan

$greenJson = '[{"name":"lint-en-tests","bucket":"pass","state":"SUCCESS","link":"https://x/actions/runs/1"}]'
$failJson  = '[{"name":"lint-en-tests","bucket":"fail","state":"FAILURE","link":"https://x/actions/runs/2"}]'
$pendJson  = '[{"name":"lint-en-tests","bucket":"pending","state":"IN_PROGRESS","link":"https://x/actions/runs/3"}]'

Assert-True (Get-MergeOnGreenPrVerdict -Record (New-PrRecord) -MergeBlockVerdict (Get-MergeBlockVerdict -RequiredChecksJson $greenJson) -GreenAgeMinutes 30).Eligible `
    'a genuinely green required payload, through the real verdict function, is eligible'
Assert-True (-not (Get-MergeOnGreenPrVerdict -Record (New-PrRecord) -MergeBlockVerdict (Get-MergeBlockVerdict -RequiredChecksJson $failJson)).Eligible) `
    'a failing one is refused'
Assert-True (-not (Get-MergeOnGreenPrVerdict -Record (New-PrRecord) -MergeBlockVerdict (Get-MergeBlockVerdict -RequiredChecksJson $pendJson)).Eligible) `
    'a still-running one is refused'
# AN UNREADABLE REQUIRED LIST REFUSES, and this is where the sweep parts company with ship-pr's step
# 3b on purpose: that step warns and ships on, because a repo with no ruleset has no certificate to
# protect. A sweep with nothing named has no green to wait for at all.
Assert-True (-not (Get-MergeOnGreenPrVerdict -Record (New-PrRecord) -MergeBlockVerdict (Get-MergeBlockVerdict -RequiredChecksJson '')).Eligible) `
    'an unreadable required-check list refuses -- there is no green to wait for'

Write-Host ''
Write-Host 'The settle window -- green is not yet orphaned (#2393)' -ForegroundColor Cyan

# SHIP-PR ARMS BEFORE ITS OWN WAIT, and the sweep is woken by the same CI completion that ends that wait.
# Without the window every ordinary ship would be handed to a second ship-pr while the live one merges.
$settle = Get-MergeOnGreenSettleMinutes
Assert-Equal 10 $settle 'the settle window is ten minutes'
$fresh = Get-MergeOnGreenPrVerdict -Record (New-PrRecord) -MergeBlockVerdict (New-Green) -GreenAgeMinutes 2
Assert-True (-not $fresh.Eligible) 'green for two minutes is refused -- a live session is normally merging it'
Assert-True ($fresh.Reason -match 'settle window') 'and the refusal names the window, so the log reads as a wait'
Assert-True (-not (Get-MergeOnGreenPrVerdict -Record (New-PrRecord) -MergeBlockVerdict (New-Green)).Eligible) `
    'an age that was never passed refuses -- fail-closed, like every other unread fact'
Assert-True (Get-MergeOnGreenPrVerdict -Record (New-PrRecord) -MergeBlockVerdict (New-Green) -GreenAgeMinutes $settle).Eligible `
    'exactly the window is eligible'
Assert-True (-not (Get-MergeOnGreenPrVerdict -Record (New-PrRecord) -MergeBlockVerdict (New-Green) -GreenAgeMinutes ([double]::NaN)).Eligible) `
    'NaN refuses -- it compares false against the window and would otherwise read as settled'
Assert-True (-not (Get-MergeOnGreenPrVerdict -Record (New-PrRecord) -MergeBlockVerdict (New-Green) -GreenAgeMinutes ([double]::PositiveInfinity)).Eligible) `
    'and so does Infinity'
# THE CHEAPER DISQUALIFIERS STILL SPEAK FIRST: a red check must not be reported as a settle wait.
$redFresh = Get-MergeOnGreenPrVerdict -Record (New-PrRecord) -MergeBlockVerdict ([pscustomobject]@{
    Blocked = $true; Reason = 'lint-en-tests failed'; UnfinishedRequired = @() }) -GreenAgeMinutes 1
Assert-Equal 'lint-en-tests failed' $redFresh.Reason 'a red check is reported as red, not as a settle wait'

Write-Host ''
Write-Host 'Get-RequiredGreenAgeMinutes -- when the LAST required check finished' -ForegroundColor Cyan

$now = [datetime]::new(2026, 9, 23, 20, 0, 0, [DateTimeKind]::Utc)
$twoJson = '[{"name":"a","bucket":"pass","completedAt":"2026-09-23T19:30:00Z"},{"name":"b","bucket":"pass","completedAt":"2026-09-23T19:45:00Z"}]'
Assert-Equal 15 (Get-RequiredGreenAgeMinutes -RequiredChecksJson $twoJson -Now $now) `
    'the age runs from the slowest required check, not the first'
Assert-Equal 15 (Get-RequiredGreenAgeMinutes -RequiredChecksJson $twoJson -Now $now.ToLocalTime()) `
    'and a local Now gives the same answer -- both sides are compared in UTC'
Assert-Equal $null (Get-RequiredGreenAgeMinutes -RequiredChecksJson '' -Now $now) 'an empty payload is unreadable'
Assert-Equal $null (Get-RequiredGreenAgeMinutes -RequiredChecksJson '[]' -Now $now) 'and so is an empty list'
Assert-Equal $null (Get-RequiredGreenAgeMinutes -RequiredChecksJson 'not json' -Now $now) 'and so is text that is not JSON'
Assert-Equal $null (Get-RequiredGreenAgeMinutes -RequiredChecksJson '[{"name":"a","bucket":"pass"}]' -Now $now) `
    'a payload fetched without completedAt is unreadable, rather than throwing'
# A PENDING CHECK REPORTS THE ZERO DATE, and reading it as a date would make every pending PR look
# two thousand years old -- the most settled pull request on the tracker.
Assert-Equal $null (Get-RequiredGreenAgeMinutes -RequiredChecksJson '[{"name":"a","bucket":"pending","completedAt":"0001-01-01T00:00:00Z"}]' -Now $now) `
    'the zero date of a pending check is unreadable, not ancient'

Write-Host ''
Write-Host 'Select-MergeOnGreenCandidate' -ForegroundColor Cyan

Assert-Equal $null (Select-MergeOnGreenCandidate -Verdicts @()) 'nothing armed yields no candidate'
Assert-Equal $null (Select-MergeOnGreenCandidate -Verdicts @(
    [pscustomobject]@{ Number = 5; Eligible = $false })) 'an armed-but-waiting pull request yields no candidate'
Assert-Equal 5 (Select-MergeOnGreenCandidate -Verdicts @(
    [pscustomobject]@{ Number = 5; Eligible = $true })).Number 'one eligible pull request is the candidate'
# LOWEST NUMBER, not newest -- so the oldest owed merge is never starved by a newer one arriving, and
# the same armed set always yields the same pick.
Assert-Equal 5 (Select-MergeOnGreenCandidate -Verdicts @(
    [pscustomobject]@{ Number = 9; Eligible = $true },
    [pscustomobject]@{ Number = 5; Eligible = $true },
    [pscustomobject]@{ Number = 7; Eligible = $true })).Number 'the lowest-numbered eligible pull request wins'
Assert-Equal 9 (Select-MergeOnGreenCandidate -Verdicts @(
    [pscustomobject]@{ Number = 5; Eligible = $false },
    [pscustomobject]@{ Number = 9; Eligible = $true })).Number 'and an ineligible lower number does not block a higher eligible one'

Write-Host ''
Write-Host 'Get-MergeOnGreenStrandedVerdict -- ready in every way but declined FOREVER on the executed-path reason (#2438)' -ForegroundColor Cyan

# THE ONE POSITIVE CASE: armed, not a draft, not a fork, the diff touches an executed path, the
# required check is green, and the green has stood for the settle window. Get-MergeOnGreenPrVerdict
# returns early on the executed-path check for such a record REGARDLESS of green/settle state (its own
# order, pinned above), so this is the one shape where Stranded can ever be $true.
$strandSettle = Get-MergeOnGreenSettleMinutes
$strandRecord = New-PrRecord -Files @('README.md', 'scripts/x.ps1')
$strandHit = Get-MergeOnGreenExecutedPathHit -Record $strandRecord
Assert-True ([bool]$strandHit) 'sanity: the fixture record really does touch an executed path'

$stranded = Get-MergeOnGreenStrandedVerdict -Record $strandRecord -MergeBlockVerdict (New-Green) -GreenAgeMinutes 30
Assert-True $stranded.Stranded 'armed + executed-path hit + green + settled -- stranded'
# THE REASON IS REUSED, NOT RE-DERIVED (this function's whole point): the exact string
# Get-MergeOnGreenExecutedPathHit composes, so a wording change to that function cannot drift the two
# apart without this failing.
Assert-Equal "$strandHit -- ship it from a session" $stranded.Reason `
    'the Reason is the SAME STRING Get-MergeOnGreenExecutedPathHit composes -- no drift'
Assert-True ($stranded.Reason -like '*scripts/x.ps1*') 'and it carries the path'

# NOT ARMED: the verdict declines with a DIFFERENT Reason ("not armed: ..."), so the identity check
# fails and this is never read as stranded, however ready everything else is.
$notArmed = Get-MergeOnGreenStrandedVerdict -Record (New-PrRecord -Labels @('prio-3') -Files @('README.md', 'scripts/x.ps1')) `
    -MergeBlockVerdict (New-Green) -GreenAgeMinutes 30
Assert-True (-not $notArmed.Stranded) 'not armed -- not stranded, even with an executed-path hit, green and settled'
Assert-Equal '' $notArmed.Reason 'and the Reason is empty on the not-stranded path'

Assert-True (-not (Get-MergeOnGreenStrandedVerdict -Record (New-PrRecord -Draft $true -Files @('README.md', 'scripts/x.ps1')) `
    -MergeBlockVerdict (New-Green) -GreenAgeMinutes 30).Stranded) `
    'a draft is not stranded -- the verdict declines on a different reason'
Assert-True (-not (Get-MergeOnGreenStrandedVerdict -Record (New-PrRecord -CrossRepo $true -Files @('README.md', 'scripts/x.ps1')) `
    -MergeBlockVerdict (New-Green) -GreenAgeMinutes 30).Stranded) `
    'a fork pull request is not stranded -- the verdict declines on a different reason'

# NO EXECUTED-PATH HIT AT ALL: the first gate returns immediately, before the verdict is even asked.
Assert-True (-not (Get-MergeOnGreenStrandedVerdict -Record (New-PrRecord) -MergeBlockVerdict (New-Green) -GreenAgeMinutes 30).Stranded) `
    'a diff touching nothing the runner executes is never stranded -- the sweep can take it'

# THE REQUIRED-CHECK STATE: only a genuinely green, finished, settled check strands a pull request --
# anything short of that is a pull request that may still become eligible on its own.
Assert-True (-not (Get-MergeOnGreenStrandedVerdict -Record $strandRecord -MergeBlockVerdict $null -GreenAgeMinutes 30).Stranded) `
    'an unreadable required-check state is not stranded -- fail-closed, same reading as the picker'
$redReq = [pscustomobject]@{ Blocked = $true; Reason = 'lint-en-tests failed'; UnfinishedRequired = @() }
Assert-True (-not (Get-MergeOnGreenStrandedVerdict -Record $strandRecord -MergeBlockVerdict $redReq -GreenAgeMinutes 30).Stranded) `
    'a red required check is not stranded -- it may still turn green on its own'
$pendReq = [pscustomobject]@{ Blocked = $false; Reason = 'ok'; UnfinishedRequired = @('lint-en-tests') }
Assert-True (-not (Get-MergeOnGreenStrandedVerdict -Record $strandRecord -MergeBlockVerdict $pendReq -GreenAgeMinutes 30).Stranded) `
    'a required check that has not finished is not stranded -- it may still go green'

# THE SETTLE WINDOW, INCLUDING ITS BOUNDARY (#2393's own window, asked one caller over): a green that
# has not yet settled may still be a live ship's own merge in progress.
Assert-True (-not (Get-MergeOnGreenStrandedVerdict -Record $strandRecord -MergeBlockVerdict (New-Green)).Stranded) `
    'an age that was never passed is not stranded -- fail-closed, like the picker'
Assert-True (-not (Get-MergeOnGreenStrandedVerdict -Record $strandRecord -MergeBlockVerdict (New-Green) -GreenAgeMinutes ([double]::NaN)).Stranded) `
    'NaN is not stranded'
Assert-True (-not (Get-MergeOnGreenStrandedVerdict -Record $strandRecord -MergeBlockVerdict (New-Green) -GreenAgeMinutes ([double]::PositiveInfinity)).Stranded) `
    'and neither is Infinity'
Assert-True (-not (Get-MergeOnGreenStrandedVerdict -Record $strandRecord -MergeBlockVerdict (New-Green) -GreenAgeMinutes ($strandSettle - 1)).Stranded) `
    'one minute short of the settle window -- not yet stranded, a live ship may still be merging it'
Assert-True (Get-MergeOnGreenStrandedVerdict -Record $strandRecord -MergeBlockVerdict (New-Green) -GreenAgeMinutes $strandSettle).Stranded `
    'exactly the settle window -- stranded'

Write-Host ''
Write-Host 'Test-MergeOnGreenRequiredChecksSettled -- the shared block both verdicts now call (#2438, Victor)' -ForegroundColor Cyan

Assert-True (Test-FunctionDefined 'Test-MergeOnGreenRequiredChecksSettled') `
    'Test-MergeOnGreenRequiredChecksSettled is defined -- the extraction landed'

$rUnread = Test-MergeOnGreenRequiredChecksSettled -MergeBlockVerdict $null -GreenAgeMinutes 30
Assert-True (-not $rUnread.Ready) 'an unreadable required-check state is not Ready'
Assert-Equal 'the required-check state could not be read' $rUnread.Reason `
    'the exact sentence Get-MergeOnGreenPrVerdict printed for this case before the extraction'

$rBlocked = Test-MergeOnGreenRequiredChecksSettled -MergeBlockVerdict $redReq -GreenAgeMinutes 30
Assert-True (-not $rBlocked.Ready) 'a blocked required check is not Ready'
Assert-Equal 'lint-en-tests failed' $rBlocked.Reason 'and it borrows the block Reason verbatim, same as before the extraction'

$rPending = Test-MergeOnGreenRequiredChecksSettled -MergeBlockVerdict $pendReq -GreenAgeMinutes 30
Assert-True (-not $rPending.Ready) 'a required check that has not finished is not Ready'
Assert-True ($rPending.Reason -match 'lint-en-tests') 'and it names the check still to come, same as before the extraction'

$rNoAge = Test-MergeOnGreenRequiredChecksSettled -MergeBlockVerdict (New-Green)
Assert-True (-not $rNoAge.Ready) 'an age that was never passed is not Ready -- fail-closed'
Assert-Equal 'when the required checks finished could not be read, so it cannot be told from a live ship' $rNoAge.Reason `
    'the exact sentence Get-MergeOnGreenPrVerdict printed for an unreadable age before the extraction'

Assert-True (-not (Test-MergeOnGreenRequiredChecksSettled -MergeBlockVerdict (New-Green) -GreenAgeMinutes ([double]::NaN)).Ready) `
    'NaN is not Ready -- it compares false against the window and would otherwise read as settled'
Assert-True (-not (Test-MergeOnGreenRequiredChecksSettled -MergeBlockVerdict (New-Green) -GreenAgeMinutes ([double]::PositiveInfinity)).Ready) `
    'and neither is Infinity'

$rShort = Test-MergeOnGreenRequiredChecksSettled -MergeBlockVerdict (New-Green) -GreenAgeMinutes ($strandSettle - 1)
Assert-True (-not $rShort.Ready) 'one minute short of the settle window -- not yet Ready'
Assert-True ($rShort.Reason -match 'settle window') 'and the Reason names the window, same wording as before the extraction'

$rExact = Test-MergeOnGreenRequiredChecksSettled -MergeBlockVerdict (New-Green) -GreenAgeMinutes $strandSettle
Assert-True $rExact.Ready 'exactly the settle window -- Ready'
Assert-Equal '' $rExact.Reason 'and the Reason is empty on the Ready path'
Assert-Equal $strandSettle $rExact.Settle 'and Settle always reports the window, so a caller need not ask Get-MergeOnGreenSettleMinutes a second time'

Write-Host ''
Write-Host "Get-MergeOnGreenPrVerdict's own check order is unchanged by the extraction (#2438)" -ForegroundColor Cyan

# EVERY REASON Get-MergeOnGreenPrVerdict PRINTS FOR THIS BLOCK IS THE SHARED HELPER'S OWN, so the two
# cannot drift apart without one of these failing -- fed the SAME inputs both ways.
Assert-Equal (Test-MergeOnGreenRequiredChecksSettled -MergeBlockVerdict $null).Reason `
    (Get-MergeOnGreenPrVerdict -Record (New-PrRecord) -MergeBlockVerdict $null).Reason `
    "unreadable: Get-MergeOnGreenPrVerdict's Reason is exactly Test-MergeOnGreenRequiredChecksSettled's"
Assert-Equal (Test-MergeOnGreenRequiredChecksSettled -MergeBlockVerdict $redReq -GreenAgeMinutes 1).Reason `
    (Get-MergeOnGreenPrVerdict -Record (New-PrRecord) -MergeBlockVerdict $redReq -GreenAgeMinutes 1).Reason `
    'blocked: same Reason through both callers'
Assert-Equal (Test-MergeOnGreenRequiredChecksSettled -MergeBlockVerdict $pendReq -GreenAgeMinutes 1).Reason `
    (Get-MergeOnGreenPrVerdict -Record (New-PrRecord) -MergeBlockVerdict $pendReq -GreenAgeMinutes 1).Reason `
    'pending: same Reason through both callers'
Assert-Equal (Test-MergeOnGreenRequiredChecksSettled -MergeBlockVerdict (New-Green) -GreenAgeMinutes ($strandSettle - 1)).Reason `
    (Get-MergeOnGreenPrVerdict -Record (New-PrRecord) -MergeBlockVerdict (New-Green) -GreenAgeMinutes ($strandSettle - 1)).Reason `
    'not-yet-settled: same Reason through both callers'

# AND THE CHEAPER DISQUALIFIERS -- armed/draft/fork -- STILL RUN BEFORE THIS BLOCK, exactly as pinned
# above: a draft or an unarmed record never reaches Test-MergeOnGreenRequiredChecksSettled at all, so its
# Reason (about the required-check state) is never what a caller sees for one of those. Re-run here,
# against the now-refactored function, to confirm the extraction did not reorder anything.
Assert-True ((Get-MergeOnGreenPrVerdict -Record (New-PrRecord -Draft $true) -MergeBlockVerdict $null).Reason -notmatch 'required-check') `
    'a draft still refuses on being a draft, not on the (unreachable) required-check block'
Assert-True ((Get-MergeOnGreenPrVerdict -Record (New-PrRecord -Labels @('prio-3')) -MergeBlockVerdict $null).Reason -match 'not armed') `
    'an unarmed record still refuses on not being armed, not on the (unreachable) required-check block'

Write-Host ''
Write-Host 'The two halves of the handshake name the same label' -ForegroundColor Cyan

# THE WHOLE POINT OF THE CONSTANT. ship-pr.ps1 WRITES the label and pick-merge-on-green.ps1 READS it;
# a second spelling anywhere would produce armed pull requests no sweep can see, and nothing would
# report it. Both must reach it through the lib rather than typing it.
$shipRaw = Get-Content -LiteralPath $ShipPath -Raw
$pickRaw = Get-Content -LiteralPath $ScriptPath -Raw
Assert-True ($shipRaw -match 'Get-MergeOnGreenArmLabel') 'ship-pr.ps1 reaches the label through the lib'
Assert-True ($pickRaw -match 'Get-MergeOnGreenArmLabel') 'pick-merge-on-green.ps1 reaches the label through the lib'
Assert-True ($shipRaw -match [regex]::Escape('..\lib\merge-on-green-lib.ps1')) 'and ship-pr.ps1 dot-sources it'
Assert-True ($pickRaw -match 'completedAt') 'the picker asks gh for completedAt -- without it every pull request reads as unsettled'
Assert-True ($pickRaw -match '-GreenAgeMinutes') 'and hands the age to the verdict'

Write-Host ''
Write-Host "ship-pr arms BEFORE its wait, not only on a CI refusal (#2393)" -ForegroundColor Cyan

# STRUCTURAL, SAID TO BE SO: the arming is inline in ship-pr.ps1 and drives gh. What can be held from
# here is the ORDER -- the arm call precedes step 3's heading, so a process that dies mid-watch or a
# step-3b refusal has already armed -- and that the two judgement gates disarm.
$armAt   = $shipRaw.IndexOf('if (Set-ShipMergeOnGreenArm)')
$step3At = $shipRaw.IndexOf('# --- Step 3: wait for the required CI check')
Assert-True ($armAt -gt 0 -and $step3At -gt 0 -and $armAt -lt $step3At) 'ship-pr arms before step 3 starts waiting on CI'
Assert-True ($shipRaw -match "(?s)if \(-not \`$NoMerge\) \{\s*\`$armLabel = Get-MergeOnGreenArmLabel\s*if \(Set-ShipMergeOnGreenArm\)") `
    'and not under -NoMerge'
Assert-True ($shipRaw -notmatch [regex]::Escape("'--add-label', `$armLabel")) `
    'the old inline arming in the CI-refusal branch is gone -- the label is written through Set-ShipMergeOnGreenArm only'
Assert-True ($shipRaw -match "Remove-ShipMergeOnGreenArmForJudgement -Gate 'step-list gate'") 'the step-list gate disarms -- only a commit clears it'
Assert-True ($shipRaw -match "Remove-ShipMergeOnGreenArmForJudgement -Gate 'DEPLOY lock'") 'and so does the DEPLOY lock'
Assert-True ($shipRaw -match "Remove-ShipMergeOnGreenArmForJudgement -Gate 'merge refusal from GitHub'") 'and so does a 4xx from gh pr merge'
Assert-True ($shipRaw -match "Remove-ShipMergeOnGreenArmForJudgement -Gate 'stale-CI check") `
    'and so does a required check with no Actions run behind it -- the sweep would re-pick it forever'

Write-Host ''
Write-Host "ship-pr's on-the-trunk resume (#2319's third precondition)" -ForegroundColor Cyan

# STRUCTURAL ASSERTS, AND SAID TO BE SO. The resume is inline in ship-pr.ps1 -- it reads HEAD, the
# tracker and the working tree, and drives `git checkout` -- so there is no pure function here to hand
# a payload to, and a suite that faked one would be asserting on its own stand-in. What CAN be held
# from here is that the three conditions the block is built on are still written into it, and that the
# refusal survived rather than being replaced. The behaviour itself is covered by nothing, which is a
# test gap named rather than papered over.
Assert-True ($shipRaw -match 'resumeCandidates\.Count -eq 1') `
    'the resume acts on exactly ONE candidate -- two is a question this script cannot ask'
Assert-True ($shipRaw -match "'status', '--porcelain'") `
    'and only on a clean tree -- a checkout carries uncommitted work across with it'
Assert-True ($shipRaw -match 'resumeCandidates\[0\]\.Note') `
    'and only for a branch name ref-print-lib will already put on a command line'
# THE REFUSAL IS STILL THERE, now conditional on the resume not having happened. A resume that cannot
# run must leave the message #1620 built, byte for byte.
Assert-True ($shipRaw -match 'You are on main; ship-pr runs from a branch\.\$resumeNote') `
    'the #1620 refusal survives unchanged for every case the resume declines'

Write-Host ''
Write-Host 'The runner, and what it must never do' -ForegroundColor Cyan

Assert-True (Test-Path -LiteralPath $FlowPath) '.github/workflows/merge-on-green.yml exists'
$flowRaw = Get-Content -LiteralPath $FlowPath -Raw
# THE MERGE MUST BE MADE BY THE PAT. A push CAUSED BY the job-scoped GITHUB_TOKEN starts no workflow
# runs, so a GITHUB_TOKEN merge would silence ci.yml on the trunk, fold-on-merge.yml and
# verify-resolved.yml in one go -- the unobserved-merge state those runners exist to close.
Assert-True ($flowRaw -match 'GH_TOKEN:\s*\$\{\{\s*secrets\.FOLD_PUSH_TOKEN\s*\}\}') `
    'the ship step authenticates gh as FOLD_PUSH_TOKEN, so its merge push still triggers the trunk runners'
Assert-True ($flowRaw -match 'ship-pr\.ps1') 'and it ships by running ship-pr.ps1 rather than by re-deriving its gates'
# THE ONE FLAG PAIR THIS JOB MUST NOT OMIT. ship-pr's step 1 calls open-pr.ps1 even for an already-open
# pull request -- it skips only the `gh pr create` -- so without these the runner re-runs the whole
# local suite pool it was started BECAUSE the green certificate already covers.
Assert-True ($flowRaw -match 'ship-pr\.ps1 -SkipLint -SkipTests') `
    'and it skips the local gates, which the green required check has already run on this same commit'
# STEP 3B WALKS FIRST-PARENT HISTORY, so a shallow clone would truncate the walk in the one direction a
# staleness gate must not err in. Cheap sweeps stay shallow; the ship step deepens first.
Assert-True ($flowRaw -match 'fetch --unshallow') 'the ship step deepens the clone before ship-pr walks the trunk'
Assert-True ($flowRaw -match "set-branches origin") 'and widens the refspec first, since actions/checkout narrowed it to one branch'
# THE BRANCH NAME NEVER REACHES A SHELL BODY THROUGH ${{ }}. It is the one attacker-influenced value
# in the file: anyone who can open a pull request chooses it.
Assert-True ($flowRaw -notmatch '(?m)^\s+git checkout \$\{\{') 'the branch is not interpolated into the checkout command line'
Assert-True ($flowRaw -match 'SHIP_BRANCH:') 'it arrives through env: instead'
Assert-True ($flowRaw -match 'cancel-in-progress:\s*false') 'an in-flight sweep is never cancelled -- it merges and folds'

Write-Host ''
Write-Host 'The lib, the script and the runner are ASCII' -ForegroundColor Cyan

$rawLib = Get-Content -LiteralPath $LibPath -Raw
Assert-True (-not ($rawLib -cmatch '[^\x00-\x7F]')) 'merge-on-green-lib.ps1 is pure ASCII'
Assert-True (Test-Path -LiteralPath $ScriptPath) 'scripts/ci/pick-merge-on-green.ps1 exists'
Assert-True (-not ($pickRaw -cmatch '[^\x00-\x7F]')) 'pick-merge-on-green.ps1 is pure ASCII'
Assert-True (-not ($flowRaw -cmatch '[^\x00-\x7F]')) 'merge-on-green.yml is pure ASCII'

# MIRRORED, UNLIKE ci-merge-skip-lib -- and the difference is one fact: ship-pr.ps1 dot-sources this
# one, unguarded, and ship-pr.ps1 travels to every consumer. A payload carrying the script without the
# lib would fail at LOAD there, which is the one failure a mirror exists to prevent.
Assert-True ((Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\lib\shared-scripts-lib.ps1') -Raw) -match 'merge-on-green-lib') `
    'merge-on-green-lib is registered as a shared script -- ship-pr.ps1 dot-sources it'

Write-Host ''
Write-Host "Result: $script:pass pass, $script:fail fail." -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
if ($script:fail -gt 0) { exit 1 }
exit 0
