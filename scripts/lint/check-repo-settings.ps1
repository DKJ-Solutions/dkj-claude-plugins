<#
.SYNOPSIS
    Advisory: does this repo's live GitHub-side state still match what the tree declares? (issue #1726)

.DESCRIPTION
    THE HOLE THIS CLOSES. A ruleset and a repo's merge switches are GITHUB-SIDE state. Nothing in this
    tree changes when they change: no commit records it, no gate read one, and no session was told.
    The docs record them regardless, because they are load-bearing -- for the three direct-on-`main`
    exceptions, for the fold, and for ship-pr's staleness guard -- so the record and the live state
    could disagree indefinitely with nothing saying so. Sylvester's own lens says as much in prose
    ("nothing in this tree changes when it changes"), and prose is not a detector.

    THREE DRIFTS IN EIGHT DAYS is what turned it into a build. #1726 was filed arguing the opposite --
    "one occurrence is not a rate", plus this repo's no-pre-emptive-fixes rule -- and that premise did
    not survive the tree:

      Sept 2-3  the org transfer emptied `bypass_actors` (#1244). Every direct-on-`main` exception
                dead, every fold blocked, branch documents accumulating on the trunk. Found by a
                failing push, a day later.
      Sept 6-9  `merge_queue` added to the ruleset (#1499), gone again by the 9th (#1720). Neither
                event left a trace, so CLAUDE.md's always-on prose went on handing out the wrong
                answer for a stretch nobody can now put a length on.
      Sept 9    `allow_auto_merge` live `true` against four records in this tree saying `false`
                (#1730) -- found by this script's own first run, while #1726's premise was being
                checked.

    So two of the three had MECHANICAL consequences, not merely a session reading the wrong sentence,
    and the argument for doing nothing rested on there having been one.

    A SCHEDULED CI LEG RATHER THAN A SESSION HOOK (Dave's call, September 9, 2026, on #1726's menu).
    Both shapes were priced. The session hook reaches a drift sooner -- the next session start rather
    than the next morning -- and costs a `gh api` round trip on every session start, on top of the
    seven hooks already there. What decided it is the half a hook cannot do at all: a scheduled run
    leaves a DATED record. #1720's own complaint is that the removal "has no date anywhere, because
    September 9 is when it was measured, not when it happened" -- a hook reports to whoever happens to
    open a session, and if nobody does, nothing is written down. A daily run bounds every future
    answer to 24 hours.

    ADVISORY, AND DELIBERATELY NOT A GATE. It reports a fact about GITHUB, not about the diff, so it
    has no place in check-plugin-integrity.ps1 or in `main-ci-gate`: a red run here says a setting
    moved, which tells you nothing about the change under review, and gating merges on it would stop
    the trunk over a switch only the owner can flip. Same reasoning, and the same non-membership,
    as unfolded-entry.yml and branch-entry.yml.

    IT NEVER WRITES TO GITHUB. Repo settings are the owner's surface under this repo's constitution;
    this script reads and reports, exactly as adopt-ci-floor.ps1 composes its ruleset command and
    stops. Reading needs a token that can read; writing needs one that can administer the repo, and a
    check that quietly held the second would be a different kind of tool.

    THE DECLARATION LIVES IN scripts/repo-config.ps1 (Get-ExpectedRepoSettings), not here, and each
    record carries `Where` -- the document in this tree stating the fact -- and `Recorded`, the date
    it was last measured. That is what makes a red run actionable rather than merely true: the report
    names which document to repair when the drift turns out to be the intended change. An unstated
    field is not checked, so nothing here can go stale for a fact nobody chose to declare.

    ONE FIELD NEEDS ADMIN AND IS REPORTED AS UNREADABLE, NOT AS GREEN. `bypass_actors` is returned by
    the rulesets endpoint to repo administrators only, so a CI run authenticating as the job-scoped
    GITHUB_TOKEN cannot see it -- and that is the one field whose emptying was #1244. Collapsing
    unreadable into "matches" would make the check silent about exactly the drift with the worst
    consequences, so it is a distinct third verdict and it does not fail the run. Everything else
    comes from `/rules/branches/<trunk>` and the repo object, both of which read without admin.

    -RequireRead, AND WHY THE THIRD VERDICT NEEDED A FLOOR UNDER IT. Tolerating an unreadable field is
    right per field and wrong for ALL of them at once: if the job's token turns out not to read those
    two endpoints, every field reports as not-read, the run exits 0, and a job that checked nothing is
    green. That is worse than no detector, because it is a detector reporting success. Raised in
    Sebastian's security review of this change, with the advice to confirm it empirically on the first
    run; the flag is preferred because an empirical check only covers the day somebody looks, while
    this covers every run afterwards. So the scheduled workflow passes it and refuses a total blackout,
    while a local run without `gh` -- or a consumer that declares settings but cannot reach GitHub --
    stays the legitimate skip it always was. It says nothing about a PARTIAL read: one field short is
    the expected CI state, and gating on that would re-create the noise the third verdict exists to
    avoid.

    WHY /rules/branches/<trunk> AND NOT /rulesets/<id> FOR THE REST. The branch endpoint needs no
    admin, needs no ruleset id (so a re-created ruleset does not silently stop being read), and
    reports the rules EFFECTIVE on the trunk -- which is the question every document here is actually
    about. It is also the endpoint Get-MergeQueueVerdict and Get-DirectPushBlockingRules already take,
    so this adds no new way of asking.

    RUN IT from the command line whenever you want the answer directly:

        powershell -NoProfile -File scripts/lint/check-repo-settings.ps1

    Exit 0 when everything declared matches, when a field could not be read, and when there is nothing
    declared; exit 1 only on a real disagreement, naming the live value, the declared value, the
    document that states it and the date it was recorded.

    Pure ASCII (repo convention for .ps1).

.PARAMETER RootOverride
    Repo root to read scripts/repo-config.ps1 from. For the test suite; the root is otherwise resolved
    dual-context like every other script here.

.PARAMETER BranchRulesJsonOverride
    A file holding a `gh api repos/<repo>/rules/branches/<trunk>` payload, read instead of calling gh.
    For the test suite, which has to reach every verdict without a network or a trunk. The literal
    string 'NONE' stands for "the read was refused", which no file path can collide with.

.PARAMETER RepoJsonOverride
    A file holding a `gh api repos/<repo>` payload, read instead of calling gh. 'NONE' as above.

.PARAMETER RulesetJsonOverride
    A file holding a `gh api repos/<repo>/rulesets/<id>` payload -- the detail object carrying
    bypass_actors, which is what the admin-only field is read from. 'NONE' stands for "admin read
    refused", the ordinary state of a CI run.

.PARAMETER Trunk
    The branch whose effective rules are read. Defaults to 'main'.

.PARAMETER RequireRead
    Fail when NOT ONE declared setting could be read. Passed by the scheduled workflow and by nothing
    else -- see the block on it below the verdict table.

.EXAMPLE
    powershell -NoProfile -File scripts/lint/check-repo-settings.ps1
#>
[CmdletBinding()]
param(
    [string]$RootOverride = '',
    [string]$BranchRulesJsonOverride = '',
    [string]$RepoJsonOverride = '',
    [string]$RulesetJsonOverride = '',
    [string]$Trunk = 'main',
    [switch]$RequireRead
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# NO SOURCE-REPO GUARD, AND NO PLUGIN MIRROR: this script is repo-local, and the registry in
# shared-scripts-lib.ps1 is deliberately not extended. What it compares is THIS repo's declared
# settings; a consumer's answer to the same class of gap is their own ruleset with their own values,
# and #1726 asked about this repo. If it ever does travel, the values are already behind a seam.

# The root comes from one definition (#1422), tolerantly, so a tree that is not a checkout degrades
# rather than dying on .Trim() against $null.
$checkLib = Join-Path $PSScriptRoot '..\lib\consumer-check-lib.ps1'
if (Test-Path -LiteralPath $checkLib -PathType Leaf) { . $checkLib }

# TWO LIBS, AND BOTH REPLACE SOMETHING THIS SCRIPT HAD HAND-ROLLED. Same pair, and the same order, as
# adopt-ci-floor.ps1 -- which reads the very endpoint this script reads.
#
#   native-capture-lib  -> Invoke-NativeCapture, which centralises the save-EAP / Continue / run /
#     record $LASTEXITCODE / restore dance its own docstring exists to keep in one tested place. The
#     first draft here repeated that guard inline and was one gate away from being refused for it
#     (shared-scripts.tests.ps1, 'no unprotected native stderr redirect') -- but the guard was never
#     the point. -Utf8 is: Windows PowerShell 5.1 decodes a native child's stdout with the CONSOLE
#     code page, so the same `gh api` returns different strings on cp65001 and cp850, and this output
#     is PARSED. The hand-rolled read had no answer to that at all, which is inbound #821's class
#     (.claude/rules/language-layers.md states the rule) arriving in a brand-new script.
#
#   pr-issues-lib       -> Get-RequiredCheckContexts, which already answers 'ruleset.required_checks'
#     off this exact payload and is what ship-pr reads, so this check cannot disagree with the gate it
#     is describing. The local version was a near-line-for-line copy of it, minus its case-insensitive
#     compare on `type`.
. (Join-Path $PSScriptRoot '..\lib\pr-issues-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')

# Test-FunctionDefined (issue #1729): the three seam probes below read the function table directly
# rather than through Get-Command, which parses the name as a wildcard pattern and pays a full PATH
# scan on every miss -- and a miss is the normal case for an optional seam. A repo-wide suite enforces
# this, and it landed on `main` while this branch was open: the branch never had the suite, so the
# local gate passed and CI -- which tests the merge -- did not.
. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')

$repoRoot = ''
if (Test-FunctionDefined -Name 'Resolve-CheckRepoRoot') {
    $repoRoot = Resolve-CheckRepoRoot -RootOverride $RootOverride
} elseif ($RootOverride) {
    $repoRoot = $RootOverride
} elseif ($env:CLAUDE_PROJECT_DIR) {
    $repoRoot = $env:CLAUDE_PROJECT_DIR
} else {
    try { $repoRoot = (git rev-parse --show-toplevel 2>$null | Select-Object -First 1) } catch { $repoRoot = '' }
    if ($repoRoot) { $repoRoot = $repoRoot.Trim() }
}

$configPath = Join-Path $repoRoot 'scripts\repo-config.ps1'
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    Write-Host "[SKIP] no scripts/repo-config.ps1 under '$repoRoot' -- nothing declares what the live settings should be."
    exit 0
}
. $configPath

if (-not (Test-FunctionDefined -Name 'Get-ExpectedRepoSettings')) {
    Write-Host '[SKIP] scripts/repo-config.ps1 supplies no Get-ExpectedRepoSettings -- this repo declares no GitHub-side settings to watch.'
    exit 0
}
$declared = @(Get-ExpectedRepoSettings)
if ($declared.Count -eq 0) {
    Write-Host '[SKIP] Get-ExpectedRepoSettings is empty -- nothing is watched, which is a declaration rather than a gap.'
    exit 0
}

# NOT $repoName, AND THE NAME IS THE WHOLE REASON. Dot-sourcing repo-config.ps1 runs its assignments
# in THIS script's scope, so every `$script:<Name>` it sets -- RepoName, LintScript, RosterPath,
# ExpectedRepoSettings and the twenty-seven others -- is a reserved name here, case-insensitively.
# `$repoName = ''` therefore OVERWRITES `$script:RepoName`, and Get-RepoName then returns the empty
# string it was just handed: the seam reads as unconfigured while the file that configures it is
# loaded and correct. Measured while writing this script -- the run reported '[SKIP] names no repo'
# against a repo-config.ps1 whose value printed correctly two lines earlier.
$targetRepo = ''
if (Test-FunctionDefined -Name 'Get-RepoName') { $targetRepo = [string](Get-RepoName) }
if (-not $targetRepo) {
    Write-Host '[SKIP] scripts/repo-config.ps1 names no repo (Get-RepoName) -- there is no repo to read settings from.'
    exit 0
}

Write-Host "== repo settings vs. what the tree declares -- $targetRepo (trunk: $Trunk) =="

# --- the three reads -------------------------------------------------------------------------------
#
# EACH IS INDEPENDENTLY OPTIONAL. A read that fails leaves every field sourced from it UNREADABLE
# rather than mismatched, because "gh could not answer" and "GitHub says something else" are different
# facts and only the second is a finding. That distinction is Get-MergeQueueVerdict's own rule --
# "unreadable is not 'no queue'" -- applied to a whole payload.
function Read-Payload {
    param([string]$Override, [string[]]$GhArgs, [string]$What)

    # THE RAW TEXT IS KEPT BESIDE THE PARSED OBJECT, and that is not belt-and-braces: the lib
    # functions that already answer parts of this payload take the JSON STRING, not the object, so
    # discarding it is what forced the first draft to re-parse and re-implement them.
    $fail = { param($note) [pscustomobject]@{ Ok = $false; Data = $null; Raw = ''; Note = $note } }

    if ($Override) {
        if ($Override -eq 'NONE') { return (& $fail 'the read was refused (override)') }
        if (-not (Test-Path -LiteralPath $Override -PathType Leaf)) {
            return (& $fail "override file not found: $Override")
        }
        $raw = Get-Content -LiteralPath $Override -Raw
    } else {
        if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
            return (& $fail 'gh is not installed')
        }
        # -DiscardStderr BECAUSE THIS OUTPUT IS PARSED -- a gh warning merged into it would break the
        # ConvertFrom-Json and cost the read; and -Utf8 because it is DATA rather than progress, so it
        # must not be decoded with whatever console code page the run inherited. Same two flags, and
        # the same reasoning, as adopt-ci-floor.ps1's read of this endpoint.
        $read = Invoke-NativeCapture -FilePath 'gh' -DiscardStderr -Utf8 -Arguments $GhArgs
        if ($read.ExitCode -ne 0) {
            return (& $fail "gh refused the read (exit $($read.ExitCode)) -- no access, or no such $What")
        }
        # ShortRead MUST BE READ BY A CALLER THAT PARSES, per the lib's own contract: it separates
        # "the child said nothing" from "we read before the flush". Both are unreadable here, and only
        # one of them is worth a distinct sentence -- an empty payload from gh is a real answer to
        # report, a truncated capture is a retryable accident and says so.
        if ($read.ShortRead) { return (& $fail 'the capture was still being written when it was read -- the payload may be truncated; run again') }
        $raw = ($read.Output -join "`n")
    }

    if (-not $raw -or -not $raw.Trim()) { return (& $fail 'empty payload') }
    try { $parsed = $raw | ConvertFrom-Json } catch { return (& $fail 'payload did not parse as JSON') }
    return [pscustomobject]@{ Ok = $true; Data = $parsed; Raw = $raw; Note = '' }
}

$branchRules = Read-Payload -Override $BranchRulesJsonOverride -What 'branch' -GhArgs @(
    'api', "repos/$targetRepo/rules/branches/$Trunk")
$repoObject = Read-Payload -Override $RepoJsonOverride -What 'repo' -GhArgs @(
    'api', "repos/$targetRepo")

# THE BYPASS LIST IS READ LAZILY, and only if something declares it. The list endpoint omits
# bypass_actors, so answering that field costs one call per ruleset -- work no run should do for a
# field nobody watches. Resolved on first use and cached in this variable.
$script:BypassTypes = $null

function ConvertTo-BypassVerdict {
    param([object[]]$Payloads)

    $types = @()
    $sawField = $false
    foreach ($p in @($Payloads)) {
        if (-not $p -or -not $p.PSObject.Properties['bypass_actors']) { continue }
        $sawField = $true
        foreach ($a in @($p.bypass_actors)) {
            if ($a -and $a.PSObject.Properties['actor_type']) { $types += [string]$a.actor_type }
        }
    }
    if (-not $sawField) {
        return [pscustomobject]@{ Readable = $false; Value = $null
            Why = 'no ruleset reported a bypass_actors field -- it is returned to repo administrators only' }
    }
    # AN EMPTY LIST IS READABLE AND IS THE #1244 STATE EXACTLY -- nobody can push to the trunk, every
    # direct-on-main exception dead. It has to reach the comparison as a value, never as "not read".
    # THE OUTER @() IS LOAD-BEARING, and this is the field it matters most on. `Sort-Object` on an
    # empty collection emits NOTHING, which lands in the property as $null -- so without the wrap the
    # emptied bypass list, the #1244 state itself, would print as '(none)' and read as "unset" rather
    # than as "empty". The comparison failed correctly either way; the REPORT was the wrong one, on
    # the one field where the reader most needs to see that the list is there and has nothing in it.
    return [pscustomobject]@{ Readable = $true; Value = @(@($types) | Sort-Object -Unique); Why = '' }
}

function Get-BypassActorTypes {
    if ($null -ne $script:BypassTypes) { return $script:BypassTypes }

    if ($RulesetJsonOverride) {
        $detail = Read-Payload -Override $RulesetJsonOverride -What 'ruleset' -GhArgs @()
        if (-not $detail.Ok) {
            $script:BypassTypes = [pscustomobject]@{ Readable = $false; Value = $null
                Why = $detail.Note + ' -- bypass_actors is returned to repo administrators only' }
            return $script:BypassTypes
        }
        $script:BypassTypes = ConvertTo-BypassVerdict -Payloads @($detail.Data)
        return $script:BypassTypes
    }

    $list = Read-Payload -Override '' -What 'ruleset' -GhArgs @('api', "repos/$targetRepo/rulesets")
    if (-not $list.Ok) {
        $script:BypassTypes = [pscustomobject]@{ Readable = $false; Value = $null
            Why = $list.Note + ' -- bypass_actors is returned to repo administrators only' }
        return $script:BypassTypes
    }
    $sets = @(@($list.Data) | Where-Object { $_ -and $_.PSObject.Properties['id'] })
    if ($sets.Count -eq 0) {
        # NO RULESET AT ALL is readable and is a finding, not an unreadable field: it means every rule
        # this repo declares is gone, which ruleset.rules reports in its own right.
        $script:BypassTypes = [pscustomobject]@{ Readable = $true; Value = @(); Why = '' }
        return $script:BypassTypes
    }

    # THE RULESET IS FOUND BY ITS RULES, NOT BY AN ID. Hardcoding 19008062 would make a re-created
    # ruleset read as unreadable forever, and this check exists because GitHub-side state moves.
    $details = @()
    foreach ($s in $sets) {
        $detail = Read-Payload -Override '' -What 'ruleset' -GhArgs @('api', "repos/$targetRepo/rulesets/$($s.id)")
        if (-not $detail.Ok) {
            # A REFUSAL ON ANY ONE LEAVES THE FIELD UNREADABLE rather than partially answered: a
            # partial union of bypass actors would compare as a mismatch and read as a drift.
            $script:BypassTypes = [pscustomobject]@{ Readable = $false; Value = $null
                Why = $detail.Note + ' -- bypass_actors is returned to repo administrators only' }
            return $script:BypassTypes
        }
        $details += $detail.Data
    }
    $script:BypassTypes = ConvertTo-BypassVerdict -Payloads $details
    return $script:BypassTypes
}

# --- what each declared field resolves to live -----------------------------------------------------
#
# One arm per Field string, so the seam's names are the contract between the declaration and the
# reads. A Field nobody here knows is reported as UNKNOWN rather than skipped: a typo in the seam
# would otherwise mean a fact silently stops being watched, which is this check's own failure mode
# arriving from the inside.
function Get-LiveValue {
    param([string]$Field)

    $unreadable = { param($why) [pscustomobject]@{ Readable = $false; Value = $null; Why = $why } }
    $readable   = { param($v)   [pscustomobject]@{ Readable = $true;  Value = $v;   Why = '' } }

    # Assign first, wrap second -- Windows PowerShell 5.1 hands a parsed JSON array to the pipeline as
    # ONE object, and an empty array parses to $null, which is the legitimate "this trunk has no rules"
    # answer rather than an unreadable one.
    $ruleRecords = @()
    if ($branchRules.Ok) {
        $ruleRecords = @(@($branchRules.Data) | Where-Object { $_ -and $_.PSObject.Properties['type'] })
    }

    switch ($Field) {
        'ruleset.rules' {
            if (-not $branchRules.Ok) { return (& $unreadable $branchRules.Note) }
            # Outer @() for the same reason as the bypass list above: a trunk with NO rules is a real
            # finding (every declared rule gone), and it has to reach the report as an empty list.
            return (& $readable @(@($ruleRecords | ForEach-Object { [string]$_.type }) | Sort-Object -Unique))
        }
        'ruleset.required_checks' {
            if (-not $branchRules.Ok) { return (& $unreadable $branchRules.Note) }
            # THE LIB ANSWERS THIS, AND THAT MATTERS BEYOND SAVING TWELVE LINES: Get-RequiredCheckContexts
            # is what ship-pr reads to decide what to wait for, so asking it here means this check cannot
            # disagree with the gate it is describing. A second implementation could only drift from it --
            # and the local one already had, missing the case-insensitive compare on `type`.
            $ctx = Get-RequiredCheckContexts -BranchRulesJson $branchRules.Raw
            if (-not $ctx.Readable) { return (& $unreadable 'the branch-rules payload did not parse for the required-check reader') }
            return (& $readable @($ctx.Names))
        }
        'ruleset.strict_required_status_checks_policy' {
            if (-not $branchRules.Ok) { return (& $unreadable $branchRules.Note) }
            foreach ($r in $ruleRecords) {
                if (([string]$r.type) -ne 'required_status_checks') { continue }
                if ($r.PSObject.Properties['parameters'] -and $r.parameters -and
                    $r.parameters.PSObject.Properties['strict_required_status_checks_policy']) {
                    return (& $readable ([bool]$r.parameters.strict_required_status_checks_policy))
                }
            }
            # NO required_status_checks RULE AT ALL IS NOT "STRICT IS OFF": the rule the flag belongs to
            # is missing, which ruleset.rules reports on its own. Answering $false here would report one
            # drift as two and hide the larger one behind the smaller.
            return (& $unreadable "no required_status_checks rule applies to '$Trunk' -- see ruleset.rules")
        }
        'ruleset.bypass_actor_types' {
            $v = Get-BypassActorTypes
            if (-not $v.Readable) { return (& $unreadable $v.Why) }
            return (& $readable $v.Value)
        }
        default {
            if ($Field -like 'repo.*') {
                if (-not $repoObject.Ok) { return (& $unreadable $repoObject.Note) }
                $prop = $Field.Substring(5)
                if (-not $repoObject.Data.PSObject.Properties[$prop]) {
                    return (& $unreadable "the repo object carries no '$prop' field")
                }
                # A PRESENT-BUT-NULL VALUE IS UNREADABLE, NOT A MATCH -- and without this line it was
                # the latter, silently. `[bool]$null` casts to `$false`, so a JSON null on any of the
                # boolean fields declared here would have compared EQUAL to a declared `$false` and
                # printed as a passing '[OK] ... = (none)': a field GitHub never answered, reported as
                # agreeing. Not reachable today (GitHub does not return null for these), which is
                # exactly why it needed writing down rather than leaving to be discovered on the day
                # it is. Same class as the empty-list collapse further up this file.
                if ($null -eq $repoObject.Data.$prop) {
                    return (& $unreadable "the repo object answered null for '$prop' -- present, but not a value to compare")
                }
                return (& $readable $repoObject.Data.$prop)
            }
            return (& $unreadable "UNKNOWN FIELD -- nothing in check-repo-settings.ps1 knows how to read '$Field'")
        }
    }
}

# --- the comparison --------------------------------------------------------------------------------
#
# A LIST IS COMPARED AS A SET, ORDER-INDEPENDENT, because GitHub returns rules and actors in an order
# nobody controls -- ordering the declaration against it would make the check fire on a reshuffle. A
# scalar is normalised on both sides first, so `true` out of JSON and $true out of the seam are one
# answer rather than two.
function Format-Value {
    param($Value)
    if ($null -eq $Value) { return '(none)' }
    if ($Value -is [System.Array]) {
        if ($Value.Count -eq 0) { return '(EMPTY)' }
        return ($Value -join ', ')
    }
    if ($Value -is [bool]) { return $Value.ToString().ToLowerInvariant() }
    return [string]$Value
}

function Test-ValuesAgree {
    param($Live, $Expected)

    if (($Live -is [System.Array]) -or ($Expected -is [System.Array])) {
        $l = @(@($Live)     | ForEach-Object { [string]$_ } | Sort-Object -Unique)
        $e = @(@($Expected) | ForEach-Object { [string]$_ } | Sort-Object -Unique)
        if ($l.Count -ne $e.Count) { return $false }
        for ($i = 0; $i -lt $l.Count; $i++) { if ($l[$i] -ne $e[$i]) { return $false } }
        return $true
    }
    if (($Live -is [bool]) -or ($Expected -is [bool])) { return ([bool]$Live) -eq ([bool]$Expected) }
    return ([string]$Live) -eq ([string]$Expected)
}

$drift = @()
$notRead = @()
$agreed = 0

foreach ($rec in $declared) {
    $field = [string]$rec.Field
    $live = Get-LiveValue -Field $field

    if (-not $live.Readable) {
        $notRead += [pscustomobject]@{ Field = $field; Why = $live.Why }
        continue
    }
    if (Test-ValuesAgree -Live $live.Value -Expected $rec.Expected) {
        $agreed++
        Write-Host ('  [OK]  {0} = {1}' -f $field, (Format-Value $live.Value))
        continue
    }
    $drift += [pscustomobject]@{
        Field    = $field
        Live     = (Format-Value $live.Value)
        Declared = (Format-Value $rec.Expected)
        Recorded = [string]$rec.Recorded
        Where    = [string]$rec.Where
        Why      = [string]$rec.Why
    }
}

foreach ($u in $notRead) {
    Write-Host ('  [?]   {0} -- not read: {1}' -f $u.Field, $u.Why) -ForegroundColor DarkYellow
}

Write-Host ''

# THE BLACKOUT FLOOR, and it is checked before the drift verdict on purpose: with nothing read there is
# no drift to report either, so the ordinary pass line would be the ONLY thing printed.
if ($RequireRead -and $agreed -eq 0 -and $drift.Count -eq 0) {
    Write-Host ('[ERROR] not one of the {0} declared settings could be read -- this run checked nothing.' -f $declared.Count) -ForegroundColor Red
    Write-Host '        -RequireRead was given, so that is a failure rather than a pass: a detector that' -ForegroundColor Red
    Write-Host '        reports success while seeing nothing is worse than no detector at all.' -ForegroundColor Red
    Write-Host '        In CI the likely cause is the token: the two non-admin endpoints need read access to' -ForegroundColor Red
    Write-Host '        the repo, so check the job permissions and that GH_TOKEN is set. The reasons above' -ForegroundColor Red
    Write-Host '        say which read failed and why.' -ForegroundColor Red
    exit 1
}

if ($drift.Count -eq 0) {
    # THE COUNTS ARE PRINTED EVEN ON A PASS, so a run that read nothing is never mistaken for a run
    # that compared everything and agreed -- the failure a bare green line would hide.
    Write-Host ('[OK] {0} of {1} declared settings match; {2} could not be read.' -f $agreed, $declared.Count, $notRead.Count)
    if ($notRead.Count -gt 0) {
        Write-Host '     An unread field is not a passing one. bypass_actors needs a token that can administer'
        Write-Host '     the repo, so a CI run cannot see it -- run this locally to compare that one.'
    }
    exit 0
}

Write-Host ('[ERROR] {0} declared setting(s) no longer match GitHub:' -f $drift.Count) -ForegroundColor Red
foreach ($d in $drift) {
    Write-Host ''
    Write-Host ('  {0}' -f $d.Field) -ForegroundColor Red
    Write-Host ('    live      {0}' -f $d.Live) -ForegroundColor Red
    Write-Host ('    declared  {0}   (recorded {1})' -f $d.Declared, $d.Recorded) -ForegroundColor Red
    Write-Host ('    stated in {0}' -f $d.Where) -ForegroundColor Red
    Write-Host ('    declared because: {0}' -f $d.Why) -ForegroundColor Red
}
Write-Host ''
Write-Host '  Decide WHICH SIDE IS WRONG before changing anything -- this check cannot tell you, and' -ForegroundColor Red
Write-Host '  the two repairs go opposite ways:' -ForegroundColor Red
Write-Host '    the live value is wrong  -> change it at GitHub (Settings -> Rules, or the repo' -ForegroundColor Red
Write-Host '                                settings page). Nothing here writes to GitHub,' -ForegroundColor Red
Write-Host "                                deliberately: repo settings are the owner's surface." -ForegroundColor Red
Write-Host '    the declaration is wrong -> the setting was changed on purpose. Update the value AND' -ForegroundColor Red
Write-Host '                                the Recorded date in scripts/repo-config.ps1' -ForegroundColor Red
Write-Host '                                (Get-ExpectedRepoSettings), and the document named above,' -ForegroundColor Red
Write-Host '                                because that document is what a session actually reads.' -ForegroundColor Red
exit 1
