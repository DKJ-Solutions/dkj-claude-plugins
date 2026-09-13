<#
.SYNOPSIS
    Regression tests for the repo-settings drift detector (issue #1726): the check script
    scripts/lint/check-repo-settings.ps1 and the declaration it reads from scripts/repo-config.ps1.

.DESCRIPTION
    Dependency-free: no Pester needed, only PowerShell.

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/repo-settings-gate.tests.ps1

    NOTHING HERE READS THE LIVE REPO, and that is the whole design of this suite. The check's subject
    is GITHUB-SIDE state, which is exactly the thing that moves without notice -- so a suite that let
    a real `gh api` through would assert a different thing tomorrow than today, and would go red for
    the very reason the check exists to report. That is not a test failing; that is the check working
    and the suite lying about it. Every case therefore feeds the three payloads in explicitly, from
    fixture files, and points -RootOverride at a fixture tree carrying its own repo-config.ps1.

    THE VARIABLE-NAME COLLISION IS ASSERTED, and it is the one case that would otherwise recur
    silently. Dot-sourcing repo-config.ps1 runs its assignments in the CALLING script's scope, so
    every `$script:<Name>` it sets is a reserved name there, case-insensitively -- and PowerShell
    variable names are case-insensitive, so a local `$repoName` overwrites `$script:RepoName` and
    Get-RepoName then returns the empty string it was just handed. Measured while writing the check:
    the run reported '[SKIP] names no repo' against a repo-config.ps1 whose value printed correctly
    two lines earlier. Nothing errors, nothing warns, and the only symptom is a check that reports
    itself inapplicable. So the happy path here asserts that the comparison actually RAN -- the header
    line naming the repo -- rather than only that the exit code was 0, because a [SKIP] is also 0.

    UNREADABLE IS A THIRD VERDICT AND IS ASSERTED AS ONE. A refused read must not collapse into
    "matches": bypass_actors is admin-only, so a CI run cannot see the one field whose emptying was
    #1244, and a check that reported that as green would be silent about the drift with the worst
    consequences. Both directions are covered -- a refusal is not a mismatch, and an EMPTY bypass list
    (the #1244 state itself) is a readable value that MUST compare and fail.

    A LIST IS A SET. GitHub returns rules and bypass actors in an order nobody controls, so the
    ordering cases exist to keep a reshuffle from ever being reported as drift.

    Fixture paths carry $PID (repo convention): the test gate is a throttled parallel scheduler, so two
    runs overlapping is ordinary and two sharing one fixed temp path tear down each other's tree.

    Pure ASCII (repo convention for .ps1).
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Script   = Join-Path $RepoRoot 'scripts\lint\check-repo-settings.ps1'
$Mirror   = Join-Path $RepoRoot 'plugins\dkj-policy\scripts\lint\check-repo-settings.ps1'
$RealCfg  = Join-Path $RepoRoot 'scripts\repo-config.ps1'
$Workflow = Join-Path $RepoRoot '.github\workflows\repo-settings.yml'

$script:pass  = 0
$script:fail  = 0
$script:trees = @()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { $script:pass++; Write-Host "  [PASS] $Message" -ForegroundColor DarkGreen }
    else { $script:fail++; Write-Host "  [FAIL] $Message" -ForegroundColor Red }
}

function New-Tree {
    param([Parameter(Mandatory = $true)][string]$Label)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("reposettings-$PID-$Label-" + [guid]::NewGuid().ToString('N').Substring(0, 6))
    New-Item -ItemType Directory -Path (Join-Path $dir 'scripts') -Force | Out-Null
    $script:trees += $dir
    return $dir
}

function Write-Ascii {
    # UTF8Encoding($false) -- no BOM, matching how every other .ps1 in this tree is written, so a
    # fixture cannot pass or fail for an encoding reason the real files do not have.
    param([string]$Path, [string]$Text)
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function New-Fixture {
    <#
        A fixture tree holding just the two things the check reads out of a repo: Get-RepoName and
        Get-ExpectedRepoSettings. -Declared is the literal PowerShell for the array, so a case can
        declare a bad Field, an empty list, or nothing at all.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Declared,
        [string]$RepoName = 'Owner/repo',
        [switch]$NoSeam,
        # Appends an optional Get-TrunkBranchName, for the trunk-seam-resolution cases below. Empty
        # (the default) means the fixture answers the trunk seam exactly like a consumer who never
        # heard of it -- absent, which is what makes the 'main' fallback case a real one rather than a
        # tautology.
        [string]$TrunkSeam = ''
    )
    $dir = New-Tree -Label $Label
    $body = @()
    $body += "`$script:RepoName = '$RepoName'"
    $body += 'function Get-RepoName { return $script:RepoName }'
    if (-not $NoSeam) {
        $body += "`$script:ExpectedRepoSettings = $Declared"
        $body += 'function Get-ExpectedRepoSettings { return $script:ExpectedRepoSettings }'
    }
    if ($TrunkSeam) {
        $body += "function Get-TrunkBranchName { return '$TrunkSeam' }"
    }
    Write-Ascii -Path (Join-Path $dir 'scripts\repo-config.ps1') -Text (($body -join "`r`n") + "`r`n")
    return $dir
}

function New-Payload {
    # AllowEmptyString on -Json: an empty payload is one of the states under test (gh answering with
    # nothing), so the fixture writer must be able to produce it.
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Json
    )
    $path = Join-Path $Dir "$Name.json"
    Write-Ascii -Path $path -Text $Json
    return $path
}

function Invoke-Check {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [string]$BranchRules = 'NONE',
        [string]$Repo = 'NONE',
        [string]$Ruleset = 'NONE',
        [string]$Trunk = '',
        [switch]$RequireRead,
        # Points a case at the plugin mirror instead of the source, so ONE case (below) can prove the
        # registered mirror behaves identically rather than only the file this suite happens to sit
        # beside. Same pattern as git-identity-gate.tests.ps1's own -ScriptPath.
        [string]$ScriptPath = $Script
    )
    $a = @('-RootOverride', $Root,
           '-BranchRulesJsonOverride', $BranchRules,
           '-RepoJsonOverride', $Repo,
           '-RulesetJsonOverride', $Ruleset)
    if ($Trunk) { $a += @('-Trunk', $Trunk) }
    if ($RequireRead) { $a += '-RequireRead' }
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @a 2>&1
    } finally { $ErrorActionPreference = $prevEap }
    return @{ Out = ($out | Out-String); Code = $LASTEXITCODE }
}

# The trunk payload this repo actually has, as of September 9, 2026 -- three rules, lint-en-tests
# required, strict off. Cases mutate a copy of it rather than each writing their own, so a case's
# intent is visible as the one thing it changed.
$RulesOk = @'
[{"type":"deletion"},
 {"type":"non_fast_forward"},
 {"type":"required_status_checks","parameters":{"strict_required_status_checks_policy":false,
   "required_status_checks":[{"context":"lint-en-tests","integration_id":15368}]}}]
'@

$DeclareRules = "@(@{ Field = 'ruleset.rules'; Expected = @('deletion','non_fast_forward','required_status_checks'); Recorded = '2026-09-09'; Where = 'the lens'; Why = 'the direct-on-main exceptions are bypassed for it' })"

try {
    Write-Host 'the happy path -- and it asserts the comparison RAN, not merely that the exit was 0'
    $dir = New-Fixture -Label 'ok' -Declared $DeclareRules
    $p = New-Payload -Dir $dir -Name 'rules' -Json $RulesOk
    $r = Invoke-Check -Root $dir -BranchRules $p
    Assert-True ($r.Code -eq 0) 'declared rules match the trunk -- exit 0'
    Assert-True ($r.Out -match 'repo settings vs\. what the tree declares -- Owner/repo') `
        'the header names the repo, which is what proves the seam was read and not silently skipped'
    Assert-True ($r.Out -match '\[OK\]\s+ruleset\.rules') 'the matching field is reported by name'
    Assert-True ($r.Out -match '1 of 1 declared settings match') `
        'the counts are printed on a pass, so a run that compared nothing cannot read as a clean one'

    Write-Host ''
    Write-Host 'the collision that made this suite necessary -- a [SKIP] must never pass for a pass'
    # A local $repoName in the check would overwrite $script:RepoName here. If that regression ever
    # returns, the run still exits 0 -- so this pair is the only thing that catches it.
    Assert-True ($r.Out -notmatch '\[SKIP\]') 'a fully configured fixture produces no [SKIP] at all'
    $dirNoSeam = New-Fixture -Label 'noseam' -Declared '' -NoSeam
    $r2 = Invoke-Check -Root $dirNoSeam -BranchRules $p
    Assert-True ($r2.Code -eq 0 -and $r2.Out -match 'supplies no Get-ExpectedRepoSettings') `
        'no seam at all -- [SKIP] and exit 0, because declaring nothing is not a defect'
    Assert-True ($r2.Out -notmatch 'vs\. what the tree declares') `
        'and a [SKIP] run prints no comparison header, which is what makes the two distinguishable'

    Write-Host ''
    Write-Host 'a real drift -- the #1720 case: a fourth rule appears'
    $dir = New-Fixture -Label 'drift' -Declared $DeclareRules
    $queued = $RulesOk.Replace('[{"type":"deletion"}', '[{"type":"merge_queue"},{"type":"deletion"}')
    $p = New-Payload -Dir $dir -Name 'rules-queue' -Json $queued
    $r = Invoke-Check -Root $dir -BranchRules $p
    Assert-True ($r.Code -eq 1) 'a rule the tree does not declare -- exit 1'
    Assert-True ($r.Out -match 'merge_queue') 'the live value is named, so the reader sees WHAT appeared'
    Assert-True ($r.Out -match 'recorded 2026-09-09') `
        'the recorded date is printed -- a stale declaration has to be visible as stale'
    Assert-True ($r.Out -match 'stated in the lens') `
        'the document stating the fact is named, which is what makes a red run actionable'
    Assert-True ($r.Out -match 'declared because: .*bypassed') `
        'the reason travels with the finding, so nobody repairs it by deleting the declaration'

    Write-Host ''
    Write-Host 'the #1730 case -- a repo-object flag, not a ruleset rule'
    $declareAuto = "@(@{ Field = 'repo.allow_auto_merge'; Expected = `$false; Recorded = '2026-09-09'; Where = 'ci.yml'; Why = 'auto-merge lands a stale-but-green certificate unattended' })"
    $dir = New-Fixture -Label 'automerge' -Declared $declareAuto
    $pOn  = New-Payload -Dir $dir -Name 'repo-on'  -Json '{"allow_auto_merge":true,"visibility":"public"}'
    $pOff = New-Payload -Dir $dir -Name 'repo-off' -Json '{"allow_auto_merge":false,"visibility":"public"}'
    $r = Invoke-Check -Root $dir -Repo $pOn
    Assert-True ($r.Code -eq 1 -and $r.Out -match 'live\s+true') 'allow_auto_merge on against a declared false -- exit 1, live value named'
    $r = Invoke-Check -Root $dir -Repo $pOff
    Assert-True ($r.Code -eq 0) 'and off again -- exit 0'
    # JSON `false` and PowerShell $false must be one answer rather than two, or the check reports drift
    # on a setting nobody touched.
    Assert-True ($r.Out -match '\[OK\]\s+repo\.allow_auto_merge = false') 'a JSON boolean compares against a PowerShell boolean'
    # PRESENT BUT NULL MUST NOT PASS FOR `false`, and before Victor's review it did: `[bool]$null` casts
    # to $false, so a field GitHub never answered compared EQUAL to a declared $false and printed as a
    # matching '[OK] ... = (none)'. Not reachable against the real API, which is why only an assert
    # keeps it closed.
    $pNull = New-Payload -Dir $dir -Name 'repo-null' -Json '{"allow_auto_merge":null,"visibility":"public"}'
    $r = Invoke-Check -Root $dir -Repo $pNull
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'answered null for .allow_auto_merge.') `
        'a JSON null on a declared boolean -- unreadable, NOT a match against $false'
    Assert-True ($r.Out -notmatch '\[OK\]\s+repo\.allow_auto_merge') 'and it is never reported as an [OK] for that field'
    # A declared STRING field, through the same generic repo.* path.
    $declareVis = "@(@{ Field = 'repo.visibility'; Expected = 'public'; Recorded = '2026-09-09'; Where = 'CLAUDE.md'; Why = 'the marketplace source must be readable without gh auth' })"
    $dirVis = New-Fixture -Label 'visibility' -Declared $declareVis
    $r = Invoke-Check -Root $dirVis -Repo (New-Payload -Dir $dirVis -Name 'pub' -Json '{"visibility":"public"}')
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'repo\.visibility = public') 'public, as declared -- exit 0'
    $r = Invoke-Check -Root $dirVis -Repo (New-Payload -Dir $dirVis -Name 'priv' -Json '{"visibility":"private"}')
    Assert-True ($r.Code -eq 1 -and $r.Out -match 'live\s+private') `
        'gone private -- exit 1, the change that would break every consumer install silently'

    Write-Host ''
    Write-Host 'unreadable is a THIRD verdict -- never green, never a mismatch'
    $dir = New-Fixture -Label 'unreadable' -Declared $DeclareRules
    $r = Invoke-Check -Root $dir   # every payload defaults to 'NONE' = refused
    Assert-True ($r.Code -eq 0) 'a refused read is not a finding -- exit 0'
    Assert-True ($r.Out -match '\[\?\]\s+ruleset\.rules') 'it is reported under its own marker'
    Assert-True ($r.Out -match '0 of 1 declared settings match; 1 could not be read') `
        'and counted separately, so "read nothing" cannot be mistaken for "compared everything"'
    Assert-True ($r.Out -match 'An unread field is not a passing one') `
        'the pass line says so in words, because exit 0 on its own would imply otherwise'

    Write-Host ''
    Write-Host '-RequireRead -- the floor under that third verdict, so a run that checked NOTHING is not green'
    # The hole this closes: if the CI token cannot read those endpoints, every field reports as not-read
    # and the job exits 0 -- a detector reporting success. Raised in Sebastian's security review.
    $r = Invoke-Check -Root $dir -RequireRead
    Assert-True ($r.Code -eq 1) 'nothing read at all, with the flag -- exit 1'
    Assert-True ($r.Out -match 'this run checked nothing') 'and it says so in those words'
    Assert-True ($r.Out -match 'check the job permissions') 'naming the likely CI cause, which is the token'
    # It must NOT fire on a partial read: one field short is the EXPECTED CI state (bypass_actors is
    # admin-only), and gating on that would re-create the noise the third verdict exists to avoid.
    $dirPartial = New-Fixture -Label 'partial' -Declared ($DeclareRules.TrimEnd(')') + ", @{ Field = 'ruleset.bypass_actor_types'; Expected = @('OrganizationAdmin'); Recorded = 'x'; Where = 'x'; Why = 'y' })")
    $pRules = New-Payload -Dir $dirPartial -Name 'rules' -Json $RulesOk
    $r = Invoke-Check -Root $dirPartial -BranchRules $pRules -RequireRead
    Assert-True ($r.Code -eq 0 -and $r.Out -match '1 of 2 declared settings match; 1 could not be read') `
        'one field read and one refused, with the flag -- still exit 0, because a partial read is the expected CI state'
    # And with the flag absent, a total blackout stays the legitimate skip it always was -- a local run
    # without gh, or a consumer that declares settings and cannot reach GitHub.
    $r = Invoke-Check -Root $dir
    Assert-True ($r.Code -eq 0) 'nothing read, WITHOUT the flag -- exit 0, unchanged'

    Write-Host ''
    Write-Host 'the #1244 state -- an EMPTY bypass list is readable, and must FAIL'
    $declareBypass = "@(@{ Field = 'ruleset.bypass_actor_types'; Expected = @('OrganizationAdmin','RepositoryRole'); Recorded = '2026-09-09'; Where = 'the lens'; Why = 'the only thing between a green gate and three dead exceptions' })"
    $dir = New-Fixture -Label 'bypass' -Declared $declareBypass
    $pEmpty = New-Payload -Dir $dir -Name 'rs-empty' -Json '{"id":1,"bypass_actors":[]}'
    $r = Invoke-Check -Root $dir -Ruleset $pEmpty
    Assert-True ($r.Code -eq 1) 'bypass_actors emptied -- exit 1, the state that killed every fold for a day'
    Assert-True ($r.Out -match '\(EMPTY\)') 'and an empty list prints as EMPTY rather than as blank, which would read as unset'
    $pFull = New-Payload -Dir $dir -Name 'rs-full' -Json '{"id":1,"bypass_actors":[{"actor_type":"OrganizationAdmin"},{"actor_type":"RepositoryRole","actor_id":5}]}'
    $r = Invoke-Check -Root $dir -Ruleset $pFull
    Assert-True ($r.Code -eq 0) 'the restored pair -- exit 0'
    # EXACTLY ONE ACTOR is the PS 5.1 single-element collapse this file tests for on the rule lists and
    # had no case for here (Victor's review). It must compare as a one-item list, not as a scalar.
    $pOne = New-Payload -Dir $dir -Name 'rs-one' -Json '{"id":1,"bypass_actors":[{"actor_type":"OrganizationAdmin"}]}'
    $r = Invoke-Check -Root $dir -Ruleset $pOne
    Assert-True ($r.Code -eq 1 -and $r.Out -match 'live\s+OrganizationAdmin') `
        'a single remaining actor -- a drift against the declared pair, reported as the one name it still has'
    # The admin-only refusal is the ordinary state of a CI run: it must not be a finding there either.
    $r = Invoke-Check -Root $dir -Ruleset 'NONE'
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'repo administrators only') `
        'refused by a non-admin token -- unreadable, and the report says why rather than only that it failed'

    Write-Host ''
    Write-Host 'a list is a SET -- a reshuffle is not drift'
    $dir = New-Fixture -Label 'order' -Declared $DeclareRules
    $shuffled = @'
[{"type":"required_status_checks","parameters":{"strict_required_status_checks_policy":false,
   "required_status_checks":[{"context":"lint-en-tests"}]}},
 {"type":"non_fast_forward"},
 {"type":"deletion"}]
'@
    $r = Invoke-Check -Root $dir -BranchRules (New-Payload -Dir $dir -Name 'shuffled' -Json $shuffled)
    Assert-True ($r.Code -eq 0) 'the same three rules in a different order -- exit 0'
    $dirB = New-Fixture -Label 'orderb' -Declared $declareBypass
    $pRev = New-Payload -Dir $dirB -Name 'rs-rev' -Json '{"id":1,"bypass_actors":[{"actor_type":"RepositoryRole"},{"actor_type":"OrganizationAdmin"}]}'
    Assert-True ((Invoke-Check -Root $dirB -Ruleset $pRev).Code -eq 0) 'and the bypass pair reversed -- exit 0'

    Write-Host ''
    Write-Host 'strict, and the trap of reading a missing RULE as a false FLAG'
    $declareStrict = "@(@{ Field = 'ruleset.strict_required_status_checks_policy'; Expected = `$false; Recorded = '2026-09-09'; Where = 'the lens'; Why = 'strict does not converge outside a merge queue' })"
    $dir = New-Fixture -Label 'strict' -Declared $declareStrict
    $r = Invoke-Check -Root $dir -BranchRules (New-Payload -Dir $dir -Name 'rules' -Json $RulesOk)
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'strict_required_status_checks_policy = false') 'strict off, as declared -- exit 0'
    $on = $RulesOk.Replace('"strict_required_status_checks_policy":false', '"strict_required_status_checks_policy":true')
    $r = Invoke-Check -Root $dir -BranchRules (New-Payload -Dir $dir -Name 'rules-strict' -Json $on)
    Assert-True ($r.Code -eq 1) 'strict turned on -- exit 1, the #1325 round trip'
    # NO required_status_checks rule at all is not "strict is off". Reporting $false there would turn
    # one drift into two and bury the larger (the rule is gone) behind the smaller.
    $r = Invoke-Check -Root $dir -BranchRules (New-Payload -Dir $dir -Name 'rules-none' -Json '[{"type":"deletion"}]')
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'no required_status_checks rule applies') `
        'no such rule -- unreadable, not a false flag, and it points at ruleset.rules instead'

    Write-Host ''
    Write-Host 'the required-check name -- what ship-pr dates its certificate from'
    $declareChecks = "@(@{ Field = 'ruleset.required_checks'; Expected = @('lint-en-tests'); Recorded = '2026-09-09'; Where = 'Get-CiTestCheckName'; Why = 'no required check means the staleness guard is simply off' })"
    $dir = New-Fixture -Label 'checks' -Declared $declareChecks
    $r = Invoke-Check -Root $dir -BranchRules (New-Payload -Dir $dir -Name 'rules' -Json $RulesOk)
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'required_checks = lint-en-tests') 'the declared context is found -- exit 0'
    $renamed = $RulesOk.Replace('lint-en-tests', 'lint-and-tests')
    $r = Invoke-Check -Root $dir -BranchRules (New-Payload -Dir $dir -Name 'rules-renamed' -Json $renamed)
    Assert-True ($r.Code -eq 1 -and $r.Out -match 'lint-and-tests') `
        'a renamed context -- exit 1, which is the binding language-layers.md warns must never break silently'

    Write-Host ''
    Write-Host 'the failure modes of the declaration itself'
    # A Field nobody can read is reported as UNKNOWN rather than skipped: a typo in the seam would
    # otherwise mean a declared fact silently stops being watched, which is this check's own failure
    # mode arriving from the inside.
    $dir = New-Fixture -Label 'typo' -Declared "@(@{ Field = 'repo.allow_automerge_typo_'; Expected = `$false; Recorded = '2026-09-09'; Where = 'x'; Why = 'y' })"
    $r = Invoke-Check -Root $dir -Repo (New-Payload -Dir $dir -Name 'repo' -Json '{"allow_auto_merge":true}')
    Assert-True ($r.Out -match 'carries no .allow_automerge_typo_. field') 'a repo.* field the payload lacks -- named, not silently passed'
    $dir = New-Fixture -Label 'unknown' -Declared "@(@{ Field = 'nonsense.thing'; Expected = 1; Recorded = 'x'; Where = 'x'; Why = 'y' })"
    $r = Invoke-Check -Root $dir -Repo (New-Payload -Dir $dir -Name 'repo' -Json '{}')
    Assert-True ($r.Out -match 'UNKNOWN FIELD') 'a Field prefix nothing knows how to read -- reported as UNKNOWN'
    $dir = New-Fixture -Label 'empty' -Declared '@()'
    $r = Invoke-Check -Root $dir
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'is empty -- nothing is watched') 'an empty declaration -- a [SKIP], stated as a declaration rather than a gap'

    Write-Host ''
    Write-Host 'a malformed payload is unreadable, never a finding'
    $dir = New-Fixture -Label 'malformed' -Declared $DeclareRules
    $r = Invoke-Check -Root $dir -BranchRules (New-Payload -Dir $dir -Name 'bad' -Json '{ not json')
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'did not parse as JSON') 'unparseable JSON -- unreadable, exit 0'
    $r = Invoke-Check -Root $dir -BranchRules (New-Payload -Dir $dir -Name 'blank' -Json '')
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'empty payload') 'an empty payload -- unreadable, exit 0'
    # An empty JSON array is the legitimate "this trunk has no rules" answer and MUST reach the
    # comparison as a value: in 5.1 it parses to $null, which is exactly the shape that gets mistaken
    # for a failed read.
    $r = Invoke-Check -Root $dir -BranchRules (New-Payload -Dir $dir -Name 'norules' -Json '[]')
    Assert-True ($r.Code -eq 1 -and $r.Out -match 'live\s+\(EMPTY\)') `
        'a trunk with NO rules -- a finding, not an unreadable field: every declared rule is gone'

    Write-Host ''
    Write-Host 'an explicit -Trunk always wins -- over the fixture and over any seam it might carry'
    $dir = New-Fixture -Label 'trunk' -Declared $DeclareRules
    $r = Invoke-Check -Root $dir -BranchRules (New-Payload -Dir $dir -Name 'rules' -Json $RulesOk) -Trunk 'trunk'
    Assert-True ($r.Out -match 'trunk: trunk') 'a non-default trunk is named in the header'

    Write-Host ''
    Write-Host 'the trunk seam (issue #1843) -- read only when -Trunk is not given at all'
    # A consumer on a differently-named trunk would otherwise have every branch-rules read aimed at a
    # branch that does not exist, and -RequireRead would then report a red run whose real cause -- the
    # wrong branch name -- is never named.
    $dirSeam = New-Fixture -Label 'trunkseam' -Declared $DeclareRules -TrunkSeam 'develop'
    $r = Invoke-Check -Root $dirSeam -BranchRules (New-Payload -Dir $dirSeam -Name 'rules' -Json $RulesOk)
    Assert-True ($r.Out -match 'trunk: develop') `
        'no -Trunk given, and scripts/repo-config.ps1 answers Get-TrunkBranchName -- the seam is honoured'
    $dirNoSeam = New-Fixture -Label 'trunknoseam' -Declared $DeclareRules
    $r = Invoke-Check -Root $dirNoSeam -BranchRules (New-Payload -Dir $dirNoSeam -Name 'rules' -Json $RulesOk)
    Assert-True ($r.Out -match 'trunk: main') `
        'no -Trunk given and no seam either -- falls back to ''main'', exactly as before this issue'
    $r = Invoke-Check -Root $dirSeam -BranchRules (New-Payload -Dir $dirSeam -Name 'rules-explicit' -Json $RulesOk) -Trunk 'override'
    Assert-True ($r.Out -match 'trunk: override') `
        'and an explicit -Trunk still wins even where the fixture DOES answer the seam'

    Write-Host ''
    Write-Host 'this repo own declaration, and the runner that carries it'
    # The real seam is exercised for SHAPE only -- never for its values, which are the moving target
    # this whole suite avoids. What must hold is that every declared Field is one the check can read,
    # because a Field the check does not know is a fact that has silently stopped being watched.
    # A CHILD SCOPE, not a dot-source into this one: `$script:RepoName` would land here, and the
    # collision this file's synopsis is about is the reason that is worth avoiding in a test too.
    $declaredHere = @(& { param($p) . $p; Get-ExpectedRepoSettings } $RealCfg)
    Assert-True ($declaredHere.Count -gt 0) 'this repo declares at least one setting to watch'

    # ASKED OF THE REAL SCRIPT, NOT OF A HAND-COPIED LIST OF ITS CASES. The first version of this
    # assert compared each declared Field against a hardcoded array of the four `ruleset.*` names plus
    # a `repo.*` wildcard -- a proxy for Get-LiveValue's switch that could pass while the script
    # reported UNKNOWN FIELD at runtime, or fail while the script handled the field fine, the moment
    # either side was edited alone. Raised in Victor's review of this change. So each declared Field
    # now goes through the script itself with every payload refused: the UNKNOWN FIELD arm does not
    # depend on a payload, so an unknown Field still reaches it, while a known one reports the refusal.
    $unknownFields = @()
    foreach ($rec in $declaredHere) {
        $one = "@(@{ Field = '$([string]$rec.Field)'; Expected = 'x'; Recorded = 'x'; Where = 'x'; Why = 'x' })"
        $d = New-Fixture -Label 'realfield' -Declared $one
        if ((Invoke-Check -Root $d).Out -match 'UNKNOWN FIELD') { $unknownFields += [string]$rec.Field }
    }
    # Composed before the assert rather than inline: a parenthesised `if` does parse here, but reading
    # it as an expression is a habit that breaks the moment it is copied somewhere with 5.1's stricter
    # parsing of the same shape.
    $badNote = ''
    if ($unknownFields.Count -gt 0) { $badNote = ' -- unknown: ' + ($unknownFields -join ', ') }
    Assert-True ($unknownFields.Count -eq 0) `
        ('every declared Field is one the check ITSELF knows how to read' + $badNote)

    # And the probe is proved still able to find something -- a guard that can no longer fail is not a
    # guard, which is the shape the hardcoded list could have decayed into silently.
    $sentinel = New-Fixture -Label 'sentinel' -Declared "@(@{ Field = 'nosuchprefix.nosuchfield'; Expected = 'x'; Recorded = 'x'; Where = 'x'; Why = 'x' })"
    Assert-True ((Invoke-Check -Root $sentinel).Out -match 'UNKNOWN FIELD') `
        'and that probe still detects an unknown Field, so the green above means something'
    $incomplete = @($declaredHere | Where-Object { -not $_.Recorded -or -not $_.Where -or -not $_.Why })
    Assert-True ($incomplete.Count -eq 0) 'every declared setting carries Recorded, Where and Why -- the three that make a red run actionable'

    Assert-True (Test-Path -LiteralPath $Workflow -PathType Leaf) 'the scheduled runner exists'
    $wf = Get-Content -LiteralPath $Workflow -Raw
    Assert-True ($wf -match '(?m)^\s+-\s+cron:') 'it is scheduled -- the dated record is the whole reason it is CI and not a hook'
    Assert-True ($wf -match 'workflow_dispatch') 'and dispatchable, for the day a setting is changed on purpose'
    Assert-True ($wf -match 'contents:\s*read') 'least privilege: it reads, and nothing here writes to GitHub'
    Assert-True ($wf -notmatch 'FOLD_PUSH_TOKEN|secrets\.') 'it borrows no standing credential, unlike fold-on-merge.yml'
    Assert-True ($wf -match 'check-repo-settings\.ps1') 'and it runs the check this suite covers'
    Assert-True ($wf -match 'persist-credentials:\s*false') `
        'the checkout keeps no credential in the workspace -- this job never pushes (verify-resolved.yml states the reasoning)'
    Assert-True ($wf -match '-RequireRead') `
        'and the run passes -RequireRead, so a token that cannot read reports a failure instead of a green nothing'

    Write-Host ''
    Write-Host 'the registered mirror (issue #1843) -- one case proves it, not merely the file this suite sits beside'
    Assert-True (Test-Path -LiteralPath $Mirror -PathType Leaf) 'the plugin mirror exists at the registered path'
    $dirMirror = New-Fixture -Label 'mirror' -Declared $DeclareRules
    $r = Invoke-Check -Root $dirMirror -BranchRules (New-Payload -Dir $dirMirror -Name 'rules' -Json $RulesOk) -ScriptPath $Mirror
    Assert-True ($r.Code -eq 0 -and $r.Out -match 'repo settings vs\. what the tree declares -- Owner/repo') `
        'the mirror runs the happy path exactly like the source'
}
finally {
    foreach ($t in $script:trees) {
        if ($t -and (Test-Path -LiteralPath $t)) { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host "FAIL: $($script:fail) failed, $($script:pass) passed." -ForegroundColor Red
    exit 1
}
Write-Host "OK: all $($script:pass) asserts passed." -ForegroundColor Green
exit 0
