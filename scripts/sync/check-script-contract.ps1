<#
.SYNOPSIS
    Script-contract check: detects when a consumer's repo-owned workflow libs (scripts/lib/branch-
    info.ps1, scripts/repo-config.ps1) lag behind the function contract that the shared, mirrored
    workflow scripts (issue #81) actually call at runtime (LAYER 1 -- detection only, no fixes).

.DESCRIPTION
    The shared workflow scripts are centralized in the plugin, but dot-source REPO-OWNED libs from
    the consumer: scripts/lib/branch-info.ps1 and scripts/repo-config.ps1. After a plugin update
    these libs can lag the contract the shared scripts expect -- the real incident this check exists
    for (issue #147): after updating the plugin, the first `new-branch` run crashed with
    "The term 'Test-BranchName' is not recognized" because the consumer's branch-info.ps1 predated
    that helper. There was a roster-drift guard (check-roster-sync + roster-sessioncheck) but no
    equivalent guard for the repo-owned SCRIPT CONTRACT. This mirrors that architecture exactly.

    The declared contract (mandatory repo-owned functions per mirrored, consumer-run shared script):
      - new-branch -> branch-info.ps1: Get-BranchInfo
                               repo-config.ps1: Get-EntryTitlePlaceholder, Get-EntryBodyHeading,
                                                Get-EntryBodyPlaceholder, Get-EntryFallbackType
                                                (all OPTIONAL -- see below)
      - new-branch          -> branch-info.ps1: Test-BranchName
      - open-pr             -> branch-info.ps1: Get-BranchInfo
                               repo-config.ps1: Get-RepoName, Get-LintScript
      - fold-changelog-entry -> repo-config.ps1: Get-RepoName
                                repo-config.ps1: Get-ReleaseHistoryPath, Get-ReservedRootMd
                                                 (both OPTIONAL, and a repo needs at most one -- see
                                                 below)
      - check-roster-sync   -> repo-config.ps1: Get-RosterPath, Get-RosterIgnoredIds
      - cut-release skill   -> repo-config.ps1: Get-LiveStage (OPTIONAL -- see below)
      - ship-pr             -> repo-config.ps1: Get-RepoName
                               repo-config.ps1: Get-PrMergeMethod (OPTIONAL -- see below)
      - verify-resolved-issues -> repo-config.ps1: Get-RepoName
      - fix-mojibake        -> repo-config.ps1: Get-MojibakePaths (OPTIONAL -- see below)

    OPTIONAL contract entries are declared with Optional = $true and report [INFO] instead of
    [ERROR] when absent, naming the default that will be used. Get-ChangelogHeading (issue #178) is
    the case this exists for: fold-changelog-entry.ps1 falls back to '## Pull Requests', so a
    consumer without the function is not broken -- but a consumer whose CHANGELOG names its section
    differently DOES need it, and silence would leave them to discover that at fold time.
    Get-LiveStage (issue #177) is the same pattern for the cut-release skill: it falls back to an
    empty string (no separate live stage, Block 2 of the checklist never applies), so a consumer
    without the function is not broken either -- but a repo that DOES have a live stage needs it
    filled in, or the skill would silently never print that block.
    The four Get-Entry* functions (issue #410) are the third instance and the clearest case for
    declaring an optional: nothing crashes without them, so the only signal a consumer would ever get
    is reading English stubs in a repo that is not English -- one branch at a time, indefinitely.

    Note that new-branch.ps1 treats repo-config.ps1 ITSELF as optional (Test-Path + a
    try/catch that degrades to a warning), unlike open-pr/fold, which pre-flight on it. That is
    deliberate: it is the lightest script in the set and every string it reads from there has a working
    default. The contract records above therefore describe wording that CAN be configured, not a
    dependency that must exist.

    Deliberately OUT of the contract entirely: the optional repo-config functions that open-pr.ps1
    guards via Get-Command (Get-PrDescriptionPlaceholder, Get-PrApprovalPattern, Get-PrAssignee,
    Get-PrMilestone) -- those are per-repo taste with no wrong-by-default failure mode, so they are
    never declared here.
    cut-release.ps1 USED TO BE OUT OF SCOPE HERE, described as "genuinely workshop-only... not mirrored
    and not part of the consumer contract" because lockstep across a marketplace's plugins is meaningless
    in a consumer. It became a shared, mirrored script in #417, and the cut-release records below
    are the consumer contract this paragraph said did not exist -- so the paragraph is now the drift it
    was written to prevent, one file over. Corrected here rather than left standing: a reader who takes it
    at face value concludes those records are a mistake.

    What was true in it survives, and it is the reason the sharing worked: the lockstep bump IS
    marketplace-specific. It just did not need the script to be forked -- it needed one seam function
    (Get-ReleasePluginTier), after which a repo with no marketplace manifest simply skips that half.

    Two 'cut-release' things are named in this file and they are NOT the same, which is worth keeping
    straight: the shared cut-release SCRIPT (its repo-config records below) and the shared
    cut-release SKILL (issue #177), a checklist that reads Get-LiveStage to decide whether its Block 2
    applies. The Get-LiveStage record is attributed to 'cut-release skill' for exactly that reason.

    ship-pr.ps1 USED TO BE LISTED HERE and no longer is (issue #411). The stated reason -- "merge policy
    and the CI check name are repo-specific" -- was half right, and the half that was wrong was load-
    bearing: the check name never entered the script's logic at all. Merge policy is real and became
    Get-PrMergeMethod. What the exclusion cost in the meantime was the whole merge + fold sequence being
    retyped by hand in every consumer, on the one flow classified safety-critical precisely because it
    merges to main and then commits directly to main.

    For each repo-owned lib in the contract:
      - lib file MISSING            -> [ERROR] naming the file and every function/shared-script that
                                        depends on it (nothing to dot-source, so nothing more to check
                                        for that lib).
      - lib present but dot-sourcing it THROWS -> [ERROR] naming the lib and the error (e.g. a syntax
                                        error), rather than letting this script crash.
      - lib present, a required function MISSING -> [ERROR] naming the function, the lib it must
                                        live in, and which shared script(s) call it -- the same
                                        information the runtime crash would have surfaced, but before
                                        it happens.
      - lib present, function present -> [OK] (detail visible on a deliberate run, like
                                        check-roster-sync.ps1).

    A repo-config.ps1 that still contains VUL-IN placeholders (an unfilled specialists-init scaffold)
    is not, by itself, a contract violation here -- Get-RepoName/Get-LintScript etc. still exist as
    functions (they just return placeholder text), so open-pr.ps1's own VUL-IN pre-flight catches
    that case. This check's job is narrower and stays that way: function PRESENCE, not content.

    SINCE INBOUND #580 IT ALSO CHECKS REACHABILITY, which is the second half of what a record claims.
    "Get-BranchTypes lives in scripts\lib\branch-info.ps1" is presence; "fold-changelog-entry calls it"
    is whether that lib is ever in scope for that script, and a lib nothing dot-sources is not in scope
    at runtime however present it is. Both halves have to hold or the function is answered by the
    caller's built-in fallback while this check reports [OK] -- which is what happened: a consumer whose
    branch table produces types outside the canonical four had every folded entry read as typeless, and
    then a refused fold, with the contract green throughout.

    THE REACHABILITY FINDING IS ALWAYS [INFO], NEVER [ERROR]. Every function reached this way is probed
    with Get-Command by the lib that wants it, so the fallback is a designed state rather than a breach,
    and for most repos it is also the right one -- branch-info.ps1 is repo-owned, and a repo whose types
    ARE the canonical four loses nothing. What the reader needs is to know which of the two answers they
    are getting, before the fold rather than at it. A consumer closes it by making the lib reachable from
    a file the script already loads (chaining it from scripts\repo-config.ps1 is the shortest route);
    leaving it open is a legitimate choice, not a defect.

    WHERE THE SHARED SCRIPT CANNOT BE LOCATED, NO CLAIM IS MADE. check-roster-sync ships in the core
    plugin rather than this one and 'cut-release skill' is not a script at all, so from the mirror both
    resolve to nothing -- and a file this check cannot find is not evidence that a lib goes unloaded.

    The walk itself (Test-ContractLibReachable) lives in script-contract-lib.ps1 beside the records,
    with the measurement that chose it over a text match written down there.

    Soft/read-only, mirroring check-roster-sync.ps1: this script changes nothing, in any repo.
    [OK]/[INFO]/[ERROR] convention shared via check-report-lib.ps1 (issue #114).

    StrictMode note: this script itself runs under Set-StrictMode -Version Latest, but each
    consumer lib (branch-info.ps1 / repo-config.ps1) is dot-sourced and probed in a child scope with
    StrictMode explicitly OFF. The real runtime callers this check models (open-pr.ps1,
    new-branch.ps1, fold-changelog-entry.ps1) never call Set-StrictMode, and
    both consumer libs are deliberately written on that no-strict-mode assumption (harmless loose
    top-level code is expected there). Do NOT "helpfully" move the dot-source into strict scope --
    that produces false [ERROR]s for legacy-but-working consumer libs that never crash at real
    runtime (see issue tracker: reported by code review).

    Exit code: 0 = no errors, 1 = at least one error.

.PARAMETER ConsumerPathOverride
    (Optional, for tests) Use this path as the consumer repo root instead of the dual-context default.

.PARAMETER SkipReachability
    Run the presence half only. Passed by the SessionStart hook, which filters this check's output to
    [ERROR]/[SCOPE] -- so a reachability finding, always [INFO], could never reach the session context,
    while the AST walk behind it measured ~1,470 ms against a ~510 ms check. Off by default, because a
    deliberate run is exactly where those findings are read.

.EXAMPLE
    .\scripts\sync\check-script-contract.ps1
#>
[CmdletBinding()]
param(
    [string]$ConsumerPathOverride = '',
    [switch]$SkipReachability
)

# Test-FunctionDefined (issue #1729): the seam probes below read the function table directly rather
# than through Get-Command, which parses the name as a wildcard pattern and pays a full PATH scan on
# every miss -- and a miss is the normal case for an optional seam. $PSScriptRoot-relative, so it
# resolves in the plugin mirror as well as here.
. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:errors = 0
$script:infos  = 0

# Write-Ok/Write-Info/Write-Failure/Write-CheckSummary/Resolve-CheckRoot/Write-CheckScope: shared
# with check-roster-sync.ps1 (single source, issue #114). $PSScriptRoot-relative (NOT $repoRoot --
# this lib is not repo-owned, unlike branch-info.ps1/repo-config.ps1), so it resolves correctly from
# the workshop root or the plugin mirror. Dot-sourced BEFORE the repo-root resolution below, which
# now comes from that same shared lib.
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')

# Repo-root -- dual-context via the shared Resolve-CheckRoot: a consumer running the plugin mirror
# gets its repo-root from CLAUDE_PROJECT_DIR; in the workshop-root (or outside a session) it falls
# back to the git-root. This keeps the root-copy and the plugin-mirror byte-identical (guarded by the
# shared-scripts drift-lint). -ConsumerPathOverride wins so a fixture can point the check at a
# throwaway consumer. The returned Source/Note travel into the [SCOPE] line below, so a finding
# surfaced by the session hook always names the repo it is about (inbound #203).
$scope = Resolve-CheckRoot -Override $ConsumerPathOverride
if (-not $scope.Path) {
    Write-Host '== check-script-contract ==' -ForegroundColor Cyan
    Write-Failure "no repo root could be resolved ($($scope.Note)) -- nothing was checked."
    Write-CheckSummary
}
$repoRoot = $scope.Path

# The declared contract lives in scripts/lib/script-contract-lib.ps1 (issue #456): three things read it
# now -- this check, build-config-blueprint.ps1 and the test suite -- and a registry with two copies is
# how a new record silently falls out of one of them. $PSScriptRoot-relative like check-report-lib above,
# NOT $repoRoot: this lib is shared machinery, not one of the repo-owned libs the contract is about.
. (Join-Path $PSScriptRoot '..\lib\script-contract-lib.ps1')
$script:Contract = Get-ScriptContract

# An optional record reports [INFO] (with the fallback the caller uses) where a required one reports
# [ERROR]. ContainsKey rather than dot-access on a possibly-absent key: this script runs under
# Set-StrictMode -Version Latest.
function Test-OptionalRecord {
    param([hashtable]$Record)
    return ($Record.ContainsKey('Optional') -and $Record.Optional)
}

function Get-RecordDefault {
    param([hashtable]$Record)
    if ($Record.ContainsKey('Default')) { return $Record.Default }
    return ''
}

function Get-RecordReturns {
    <# The one-line "what it must give back" for a record, as ' It must return <...>.' ready to append
       to a finding -- empty when a record has no Returns yet, so an un-annotated record degrades to the
       old, shorter message instead of printing a dangling sentence. ContainsKey rather than dot-access:
       this script runs under Set-StrictMode -Version Latest. #>
    param([hashtable]$Record)
    if ($Record.ContainsKey('Returns') -and $Record.Returns) { return " It must return $($Record.Returns)." }
    return ''
}

# PRESENT IS NOT THE SAME AS IN SCOPE (inbound #580). A record claims a shared script calls the
# function; a lib that script never dot-sources is not in scope at runtime however present it is, so the
# probe above reports [OK] while the shared script silently runs on its built-in fallback. The measured
# instance: a consumer whose branch table produces types outside the canonical four had every folded
# entry read as typeless and then a refused fold, with this check green throughout.
#
# ALWAYS [INFO], NEVER [ERROR], and that is a deliberate ceiling rather than caution. Every function
# reached this way is probed with Get-Command by the lib that wants it, so the fallback is a designed
# state, not a breach -- and for most repos it is also the RIGHT state, since branch-info.ps1 is
# repo-owned and a repo whose types are the canonical four loses nothing. What the reader needs is to
# learn which answer they are getting, before the fold rather than at it.
#
# A SCRIPT THIS CHECK CANNOT LOCATE PRODUCES NO CLAIM AT ALL. check-roster-sync ships in a different
# plugin and 'cut-release skill' is not a script, so both resolve to nothing here -- and a missing file
# is not evidence that a lib is unloaded. Silence is the honest report; guessing would put two false
# findings in every consumer's session, which is how a check gets switched off rather than heeded.
#
# AND IT IS SKIPPED AT SESSION START, WHICH IS THE POINT OF -SkipReachability. Measured when the walk
# was built: it adds ~1,470 ms to a check that ran in ~510 ms, paid at every session in every consumer
# -- and the hook filters the output to '[ERROR]|[SCOPE]', so a finding that is ALWAYS [INFO] can never
# reach the session context anyway. That is 1.5 seconds buying nothing, forever. The walk stays ON by
# default, where it is read: a deliberate run, the adopt-config flow, CI. Surfacing it from the hook
# instead was considered and rejected for the reason this repo already has written down -- a signal a
# healthy repo cannot clear is noise, and a repo that legitimately leaves the seam unreachable would
# get the same line at every session until it stopped reading the check at all.
function Write-ReachabilityGaps {
    param([hashtable]$Record, [string]$LibRel)

    if ($SkipReachability) { return }

    foreach ($scriptName in @($Record.Scripts)) {
        $scriptPath = Resolve-SharedScriptPath -Name $scriptName
        if (-not $scriptPath) { continue }
        if (Test-ContractLibReachable -ScriptPath $scriptPath -RepoRoot $repoRoot -LibRelPath $LibRel) { continue }

        $def = Get-RecordDefault -Record $Record
        $fallback = if ($def) { "'$def'" } else { 'its built-in fallback' }
        Write-Info ("'$($Record.Function)' is present in $LibRel but NOT IN SCOPE for '$scriptName': " +
            "that script never dot-sources $LibRel, directly or through a lib it loads, so it runs on $fallback " +
            "instead of your answer. Nothing crashes -- the caller probes for the function and falls back by " +
            "design -- and if that fallback is right for this repo there is nothing to do. To make your answer " +
            "reachable, dot-source $LibRel from a file the script does load, such as scripts\repo-config.ps1.")
    }
}

# One finding line for a contract record that could not be satisfied: [ERROR] when required, [INFO]
# when optional (the caller has a documented fallback, so it is a signal, not a breach).
function Write-ContractGap {
    param([hashtable]$Record, [string]$Message)
    if (Test-OptionalRecord -Record $Record) {
        $def = Get-RecordDefault -Record $Record
        $suffix = if ($def) { " -- optional; the shared script falls back to '$def'." } else { ' -- optional; the shared script has a built-in fallback.' }
        Write-Info ($Message + $suffix)
    } else {
        Write-Failure $Message
    }
}

Write-Host '== check-script-contract ==' -ForegroundColor Cyan
Write-CheckScope -Scope $scope -CheckName 'check-script-contract'

# --- Is this repo set up at all? (issue #225) -----------------------------------------------------
# When EVERY contract lib is absent, the repo has not been through specialists-init: the scaffolds are
# exactly what the bootstrap puts down. Reporting each required function separately then produces a
# list of errors about files that were never meant to exist yet -- 6 [ERROR] lines on a fresh
# consumer, phrased as "this lib predates the contract", which is the wrong story for a repo that has
# no lib at all. A missing lib is only drift once the repo has been set up.
#
# Strict on purpose: if even one lib is present, this is a set-up repo with a real gap and every
# finding stands. Only the all-absent case is "never bootstrapped".
$contractLibs = @($script:Contract.Lib | Sort-Object -Unique)
$presentLibs = @($contractLibs | Where-Object { Test-Path -LiteralPath (Join-Path $repoRoot $_) -PathType Leaf })

if ($contractLibs.Count -gt 0 -and $presentLibs.Count -eq 0) {
    # Same non-counting shape as the roster check's marker, and for the same reason: nothing is
    # broken, the repo-side setup simply has not happened.
    #
    # NAMES THE COMMAND AND WHO TYPES IT (inbound #1093 / #1096) -- the second of the two SessionStart
    # hooks that told a fresh consumer's model to "run that skill" while disable-model-invocation
    # forbids exactly that. Full reasoning at the twin site in check-roster-sync.ps1's [BOOTSTRAP]
    # marker; the short of it is that the refused model's next move is the absolute path into the
    # plugin cache, and this line is where that temptation is created. The 'adopt-dkj-policy'
    # imperative further down is NOT the same case and stays as it is: that skill carries no flag.
    Write-Host ("  [BOOTSTRAP] this repo has none of the libs the shared workflow scripts expect (" + ($contractLibs -join ', ') + ") -- it has not been set up yet. Nothing is broken: those files are what /dkj-subagents-alpha:specialists-init puts down as scaffolds for you to fill in. That command must be TYPED by the repo owner, because the skill is reserved for explicit user invocation and an agent cannot start it. Until then this check reports nothing further, because every required function would otherwise be listed against a file that does not exist yet.") -ForegroundColor Yellow
    Write-CheckSummary
    exit 0
}

# --- The workflow's own root folder (Dave, August 14, 2026) ---------------------------------------
# dkj-policy/ is where everything portable about the workflow gathers in a consumer: the folder
# docs, the audience releases root, and the branch dossier the shared scripts read. A plugin install
# cannot create it -- an install is a clone into the plugin cache -- so the one signal a consumer gets
# is this line, surfaced at session start by the script-contract hook ([ERROR] is what that hook
# forwards, which is why this is not an [INFO]). EXISTENCE ONLY, deliberately: the folder's contents
# differ legitimately per repo (the source composes its own by hand, and since August 27, 2026 it holds
# more than a consumer's scaffold writes), so anything finer would need the per-repo exemption list this
# repo keeps declining.
# Placed AFTER the bootstrap marker: a repo that has not been through specialists-init already got the
# one message that names its actual state, and this line would be noise on top of it.
# EVERY FOLDER NAME SATISFIES THIS (#886, August 26, 2026; #1437, September 5, 2026). The folder renamed
# 'workflow-davekjohn/' -> 'contributing-davekjohn/' and then -> 'dkj-policy/', and this line is forwarded
# by a SessionStart hook as an [ERROR]. Checking only
# the newest name would greet every unmigrated consumer with "your folder does not exist" about a folder that
# is sitting right there -- the loudest possible way to be wrong. The names are literals rather than a
# read of Get-BranchFilePaths because this script dot-sources only check-report-lib and script-contract-lib;
# adding a third dependency to answer "does a directory exist" costs more than it buys. The previous note
# here said the trade would flip at a fourth name; the third has arrived and it has not, because the list
# is still one line and the dependency is still the whole cost.
$workflowFolderNames = @('dkj-policy', 'contributing-davekjohn', 'workflow-davekjohn')
$foundWorkflowFolder = $workflowFolderNames | Where-Object {
    Test-Path -LiteralPath (Join-Path $repoRoot $_) -PathType Container
} | Select-Object -First 1
if (-not $foundWorkflowFolder) {
    Write-Failure ("the workflow folder 'dkj-policy/' does not exist in this repo -- since " +
        "August 14, 2026 the branch dossier, the folder docs and the audience releases live there, and " +
        "the shared scripts read only that location. Run the 'adopt-dkj-policy' skill to scaffold " +
        "it (dry-run by default, additive, never overwrites). A leftover root branch/ from before the " +
        "move is yours to remove by hand.")
} elseif ($foundWorkflowFolder -ne $workflowFolderNames[0]) {
    Write-Ok ("workflow folder: $foundWorkflowFolder/ exists -- the PRE-RENAME name, still read. Renaming " +
        "it to $($workflowFolderNames[0])/ is yours to do when it suits you (#886).")
} else {
    Write-Ok "workflow folder: $foundWorkflowFolder/ exists."
}

foreach ($libRel in $contractLibs) {
    $records = @($script:Contract | Where-Object { $_.Lib -eq $libRel })
    $libPath = Join-Path $repoRoot $libRel

    Write-Host "`n-- lib: $libRel" -ForegroundColor Cyan

    if (-not (Test-Path -LiteralPath $libPath -PathType Leaf)) {
        foreach ($r in $records) {
            $scriptList = $r.Scripts -join ', '
            Write-ContractGap -Record $r -Message "'$libRel' not found -- '$($r.Function)' (required by: $scriptList) cannot be checked; the shared script(s) will crash on first use."
        }
        continue
    }

    # Dot-source + probe the consumer lib in a CHILD scope with StrictMode explicitly OFF -- the real
    # runtime callers this check models (open-pr.ps1, new-branch.ps1,
    # fold-changelog-entry.ps1) never call Set-StrictMode, and branch-info.ps1/repo-config.ps1 are
    # written on that no-strict-mode assumption (harmless loose top-level code is expected). Probing
    # inside the same block keeps the dot-sourced functions visible to Get-Command while nothing
    # leaks into this script's own strict scope.
    $probe = & {
        Set-StrictMode -Off
        $result = [pscustomobject]@{ Loaded = $true; Error = $null; Present = @{} }
        try {
            . $args[0]
        } catch {
            $result.Loaded = $false
            $result.Error = $_.Exception.Message
            return $result
        }
        foreach ($fn in $args[1]) {
            $result.Present[$fn] = [bool](Test-FunctionDefined $fn)
        }
        return $result
    } $libPath (@($records.Function))

    if (-not $probe.Loaded) {
        foreach ($r in $records) {
            $scriptList = $r.Scripts -join ', '
            Write-ContractGap -Record $r -Message "'$libRel' failed to load ($($probe.Error)) -- '$($r.Function)' (required by: $scriptList) cannot be checked."
        }
        continue
    }

    foreach ($r in $records) {
        $scriptList = $r.Scripts -join ', '
        $needed = if (Test-OptionalRecord -Record $r) { 'used by' } else { 'required by' }
        if ($probe.Present[$r.Function]) {
            Write-Ok "'$($r.Function)' present in $libRel"
            Write-ReachabilityGaps -Record $r -LibRel $libRel
        } else {
            Write-ContractGap -Record $r -Message "'$($r.Function)' missing from $libRel ($needed`: $scriptList) -- this lib predates the contract the shared script(s) call; add the function.$(Get-RecordReturns -Record $r)"
        }
    }
}

Write-CheckSummary
