<#
.SYNOPSIS
    Connectors check: verifies whether all connected repos (connectors) are still in sync with
    this repo -- the source of truth.

.DESCRIPTION
    The register lives at family level, next to the plugin folders (deliberately NOT inside them,
    so it does not travel along with a consumer's plugin cache): ONE manifest per connected repo
    (connectors/<repo>.json), containing the extension
    inventory per plugin. Manifests contain only METADATA -- never
    lens content and never absolute machine paths; localCheckout is relative to this repo's root, and
    may be a LIST of relative paths when the layout differs per machine -- the first one present here
    wins (issue #1524).

    Per connector this script checks:
      1. Checkout present on this machine?          no -> [SKIP] (not an error). 'Present' means any
         one of the manifest's localCheckout candidates resolves; the [SKIP] names all of them, so a
         register that is merely stale about this machine's layout can be told from a genuine absence.
      1b. THE SAME SUBJECT AS 1, A DIFFERENT QUESTION: now that a checkout resolves, IS it a clone of
         the repository the manifest names, or merely a folder that happens to sit at that path
         (#1821)? Read via 'git ... remote get-url origin', before ANYTHING below (checks 2-6) reads
         that disk on the named repo's behalf. Agreement -> silent. A genuine mismatch, or one this
         run cannot tell apart from an old spelling landing on a transfer redirect (this check makes
         no network call) -> [ERROR] naming both slugs, and every verdict below is withheld for this
         connector rather than printed against a repository that was never actually read. A mismatch
         that is only THIS repo's own rename history landing on a transfer redirect -> [SKIP] naming
         the one command that ends it, and the run then proceeds exactly as on agreement. The
         question itself could not be asked (no git, not a work tree, no 'origin' remote naming
         GitHub, or a folder that resolves but is not the ROOT of the work tree it sits inside) ->
         [SKIP], and the run proceeds exactly as before this check existed -- never asserted as a
         mismatch from a failed read.
         (Naming note, Edith's finding: this check's own number, '1b', is unrelated to the '1b'/'1c'/etc.
         scenario labels in scripts/tests/connectors.tests.ps1 -- that suite already had an unrelated
         scenario labelled '1b' before this check existed, and the two sequences are not the same one.)
      2. Per plugin: enabled anywhere in the consumer's settings CHAIN? no -> [ERROR]. Read via
         Get-EnabledPlugins, so the verdict names the layer it came from (inbound #294); this line used
         to say '.claude/settings.json', which is the single-file reading that produced that inbound.
      3. Per plugin: all registered extensions present?  one missing -> [ERROR]
         Extensions of that plugin that exist in the consumer but are NOT registered
         -> [INFO] (inbound signal: update the register or bring the change back here), plus a
         non-counting [INVENTORY] line the session hook surfaces when that drifted register is
         the one describing the repo the session is in -- the only case a reader here can act on.
      4. Per plugin: machine record older than source -> [ERROR]; no record/no administration -> [INFO]
         (machine-specific, not a gate breach). The record comes from Get-InstallRecord
         (check-report-lib.ps1) -- the shared reader of ~/.claude/plugins/installed_plugins.json this
         block used to be the sole owner of (inbound #302). When a plugin has no record for a checkout
         while being ENABLED there, that [INFO] additionally states the consequence: a session in that
         checkout loads none of it, and that repo's own hooks cannot say so, because they are in the
         plugin that is not loading.
      4b. THE SAME QUESTION AS 4, asked in a different place: on a plugin whose name the marketplace has
         RETIRED (#1802). That id never reaches check 4 -- it is resolved before check 2 and its whole
         block is skipped, correctly for the extension inventory and the version comparison, which read
         a source folder a retired name has none of. The install-record question needs no source folder,
         so it is asked inside that arm instead: retired AND enabled there AND no record for that
         checkout -> [INFO], plus the same [NOT-INSTALLED-HERE] promotion check 4 makes for the
         session's own repo. It is the one state where 'claude plugin install <id>' is NOT the way out,
         because the catalogue no longer declares that id, so the finding hands over the migration.
         It is numbered beside 4 rather than beside 3 because its SUBJECT is 4's, not because it runs
         there -- it runs earliest of all of them.
      5. Per connector, once the plugin loop above has finished: is every plugin id enabled in the
         consumer's settings chain, for a marketplace THIS register describes, also named in this
         manifest's own 'plugins' list? One missing -> [INFO] naming the id (the loop above never even
         saw it, so nothing about it was checked at all: not an extension check, not a version check),
         plus a non-counting [UNLISTED] line the session hook surfaces on the same terms as
         [INVENTORY] -- only when the under-registered manifest is the one describing the repo the
         session is in (#1775). An id naming a marketplace other than this one is silently out of scope:
         this register has no way to judge a catalogue it does not own.
      6. Per connector: does every path its CI runners reach into a checkout of THIS repo for still
         exist here? Three outcomes, not two. Missing -> [ERROR] naming the workflow file, the line,
         the path, and where that script is NOW (the published mirror offered before this repo's own
         scripts/ copy, since only the first is a path a consumer may run). Present -> silence.
         And a reference that does not stay under the checkout at all -> [ERROR] of its own, saying
         so and saying it was NOT looked up: the path comes out of a consumer's file, so resolving
         '../..' against this disk would answer whether an arbitrary file exists on the maintainer's
         machine, unattended, at every session start. Three runners this workflow scaffolds
         (branch-entry.yml, fold-on-merge.yml, verify-resolved.yml) check this repository out beside
         the consumer's tree and run a path into it, so a move here silently breaks a file this repo
         cannot reach -- measured #1805, two consumers red on every pull request. This is the only
         check here whose subject is a path INTO this tree rather than the consumer's own state, and
         the only repair that can reach a repo which adopted before the move: fixing the scaffolder
         cannot, because it writes once. Switched off entirely, rather than guessing, when
         Get-RepoName cannot be read.
      6b. THE SAME CHECK, ASKED OVER THE NETWORK, and only under -RemoteRunners (#1808). Check 6 reads
         the consumer's local checkout, so it inherits check 1: an absent consumer is [SKIP] and its
         runners are not read at all -- and the consumers most likely to carry a stale path are the
         ones nobody visits, which are the ones least likely to be checked out where you happen to be
         running. So on request the workflow files are read from the repository's default branch
         through 'gh api graphql' and judged by exactly the same code, with the finding saying which
         branch it read. THREE OUTCOMES AGAIN, and the third is the one that earns the switch: a repo
         this token cannot read, or a call that does not answer, is an [INFO] naming the repo and the
         command to run by hand -- never silence, which on a check whose whole subject is an unnoticed
         breach would be indistinguishable from an all-clear. Off at session start because a network
         call per absent connector does not belong on that path; the same shape -SkipDrift and
         -SkipVersions already establish here, inverted.
      6c. AND THE QUESTION CHECK 6 CANNOT ASK: does this consumer reach into this tree AT ALL? (#1850)
         Check 6 judges paths that are named, so a consumer running none of the three runners produces
         no reference, no finding, and reads exactly like a fully adopted one -- adoption and
         non-adoption were indistinguishable to the register. Measured September 11, 2026:
         DaveKJohn/djcylow-react registers the full core-team adoption and names the workflow plugin,
         and its entire .github/workflows/ is one ci.yml. Reported as an [INFO], not an [ERROR], on the
         line the register already draws for an unmigrated plugin id: both halves of adopt-dkj-policy
         that place these runners are optional, so their absence is a state and may be a decision --
         which the finding says, pointing at the manifest's 'notes' for recording one. Gated on the
         manifest naming the workflow plugin (under any of its names), since nothing else scaffolds
         them; and the source repo is never asked, because it runs those scripts by local path and is
         the one registered repo that can never produce a reference. Runs on both routes -- the disk
         and, under -RemoteRunners, the network, where it replaces what used to be deliberate silence.
    The register no longer keeps a syncedVersion bookkeeping: the check reads the actual installed
    version from the machine record, and register administration that only duplicates numbers
    produced nothing but maintenance PRs (Dave's decision, July 20, 2026).
    After that, scripts/lint/check-consumer-drift.ps1 runs once per unique consumer
    (agent-def drift = error; persona drift = informational, as in that script itself).

    Guardrail (Sean's advice): manifest fields are data from a public repo and are never blindly
    trusted -- absolute or out-of-scope localCheckout paths and invalid plugin ids are rejected.

    Exit code: 0 = no errors (SKIP/INFO and the non-counting [UNREGISTERED]/[INVENTORY]/
    [NOT-INSTALLED-HERE]/[UNLISTED] markers do not count), 1 = at least one error.

.PARAMETER Manifest
    (Optional) Path to a single manifest instead of all connectors manifests.

.PARAMETER ConsumerPathOverride
    (Optional, for tests) Overrides localCheckout from the manifest.

.PARAMETER OnlyConsumer
    (Optional) Restrict the check to the manifest whose checkout resolves to this path
    (scoping for the SessionStart hook: a session only sees its own register data).

.PARAMETER SkipDrift
    Skip the check-consumer-drift step (faster; register checks only).

.PARAMETER SkipVersions
    Skip the machine-record check (e.g. on CI, where no plugin administration exists).

.PARAMETER RemoteRunners
    (Opt-in) For a consumer whose checkout is NOT on this machine, read its CI runners over the
    GitHub API instead of off the disk, so check 6 judges it rather than skipping it (#1808). OFF by
    default and deliberately so: this script runs from connector-sessioncheck.ps1 at every session
    start, and a network call per absent connector is a different cost class from everything else it
    does. Where the read cannot be made -- no gh, no auth, no answer -- it says so per connector and
    never falls through to silence, which would read as an all-clear.

.PARAMETER UserHomeOverride
    (Optional, for tests) Use this dir as the user home when resolving the user layer of a consumer's
    settings chain (~/.claude/settings.json), instead of $env:USERPROFILE. Without it a fixture would
    inherit whatever the machine running the suite has enabled globally, so a "plugin not enabled" case
    would pass here and fail on the next machine for a reason no assertion mentions.

.EXAMPLE
    .\scripts\sync\check-connectors.ps1
.EXAMPLE
    .\scripts\sync\check-connectors.ps1 -SkipDrift -SkipVersions
.EXAMPLE
    .\scripts\sync\check-connectors.ps1 -RemoteRunners
#>
[CmdletBinding()]
param(
    [string]$Manifest = '',
    [string]$ConsumerPathOverride = '',
    [string]$OnlyConsumer = '',
    [switch]$SkipDrift,
    [switch]$SkipVersions,
    [switch]$RemoteRunners,
    [string]$UserHomeOverride = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$DriftLint  = Join-Path $RepoRoot 'scripts\lint\check-consumer-drift.ps1'

$script:errors = 0
$script:infos  = 0

# Write-Ok/Write-Info/Write-Failure + Test-PluginNameSlug: shared with check-roster-sync.ps1 (single
# source, issue #114). This script is workshop-only (not mirrored -- it reads the connectors/
# register that only exists here), so the lib is dot-sourced unconditionally.
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')

# Which plugins this repo publishes, and where each one's folder is. Read once: the register is walked
# per consumer and per plugin, and re-reading the marketplace inside that loop is how two answers to one
# question start appearing in one run.
. (Join-Path $PSScriptRoot '..\lib\plugin-tree-lib.ps1')
$PluginRoots = @(Get-RepoPluginRoots -RepoRoot $RepoRoot)

# Which scripts of THIS tree a consumer's CI runners reach into, for check 6 (#1805). The lib carries
# the whole measurement; what it needs from here is the name half of this repo's own slug, because a
# scaffolded runner checks this repository out by name beside the consumer's tree.
. (Join-Path $PSScriptRoot '..\lib\consumer-runner-lib.ps1')

# The name half of the workflow plugin, under EVERY name it has carried -- the gate on check 6c (#1850).
# That plugin is what scaffolds the three runners, so a manifest that does not name it describes a
# consumer with no reason to hold them. The list is the same shape Get-MojibakePaths already keeps for
# the folder that renamed alongside it ('workflow-davekjohn' -> 'contributing-davekjohn' -> 'dkj-policy'),
# and it is kept here rather than in repo-config.ps1 on purpose: this is the REGISTER's knowledge about
# manifests only this repo holds, not a seam a consumer configures. It only ever grows -- a name dropped
# from it goes silent on precisely the consumer that has not migrated yet.
$WorkflowPluginNames = @('dkj-policy', 'contributing-davekjohn', 'workflow-davekjohn')

# The seam probe used just below. 87 lines, and it is the ONE definition of the question (#1729) --
# the inline `Get-Command <name>` it replaced costs 32ms on a MISS, which is the case a seam probe is
# in by default. Cheap enough for a script SessionStart runs, unlike the readers this file has already
# declined (see the $ThisMarketplaceName note above on release-lib).
. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')

# THE NAME COMES FROM THE ONE SOURCE THAT STATES IT (Get-RepoName, scripts/repo-config.ps1) -- the same
# rule that moved the slug out of open-pr and fold. Read through the child-scope, StrictMode-off idiom
# check-roster-sync.ps1 uses on the same file and for the same reason: repo-config.ps1 is documented as
# written on the no-strict-mode assumption, and this check does not hard-require it.
#
# UNREADABLE SWITCHES CHECK 6 OFF ENTIRELY rather than guessing at the name -- the same doctrine
# $ThisMarketplaceName follows two blocks up, and for the stronger version of the same reason: a guessed
# name that matches nothing makes every consumer read as clean, which is the exact silence #1805 was
# filed about. Guessing from the checkout's DIRECTORY NAME was the tempting shortcut and is refused on
# its own terms: a directory can be renamed or moved without the repo changing name, so it answers a
# different question. (This family keeps other state keyed on a folder path -- the plugin install
# record, #1449 -- and that is a neighbouring hazard rather than evidence for this one.)
$ThisRepoName = ''
# AND THE FULL SLUG, KEPT ALONGSIDE THE NAME HALF, for check 1b (#1821): that check's arm 2 has to ask
# "does this manifest describe THIS repo's own connector" before it may loosen a comparison to the name
# half alone, and the only honest way to ask that is the full owner/name Get-RepoName states, not a
# guess reconstructed from $ThisRepoName plus whatever owner happens to be on the manifest.
$ThisRepoSlug = ''
# AND THE NAMES THIS REPO HAS BEEN RENAMED AWAY FROM, read from the same seam (#1769). A consumer
# scaffolded before a rename still writes the old name into its runner, and that runner still works
# because GitHub answers the transfer redirect -- so matching only the current name reports nothing
# about it and the consumer reads as clean, which is the silence this check was filed to end. Same
# reasoning as 12c below carries for the old OWNER, one axis over. Optional: a repo that has never
# been renamed does not define the function, and the list stays empty.
$ThisRepoRetiredNames = @()
$repoConfigPath = Join-Path $RepoRoot 'scripts\repo-config.ps1'
if (Test-Path -LiteralPath $repoConfigPath -PathType Leaf) {
    $seam = & {
        Set-StrictMode -Off
        try { . $args[0] } catch { return @{ Slug = ''; Retired = @() } }
        $s = if (Test-FunctionDefined 'Get-RepoName') { [string](Get-RepoName) } else { '' }
        $r = if (Test-FunctionDefined 'Get-RetiredRepoNames') { @(Get-RetiredRepoNames) } else { @() }
        return @{ Slug = $s; Retired = $r }
    } $repoConfigPath
    $slug = [string]$seam.Slug
    if ($slug) { $ThisRepoName = $slug.Substring($slug.LastIndexOf('/') + 1); $ThisRepoSlug = $slug }
    $ThisRepoRetiredNames = @($seam.Retired | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

# --- CAN THE OPT-IN NETWORK READ ACTUALLY BE MADE? Asked ONCE per run (#1808) --------------------
# -RemoteRunners is a request, not a capability, and the two ways it can be unmeetable are properties
# of the MACHINE rather than of any one connector: gh is not installed, or gh is installed and holds no
# credential. Asking per connector would print the same sentence once for every absent checkout in the
# register and teach the reader nothing three times over -- so it is settled here, and the per-connector
# lines below are then only ever about a specific repository.
#
# AND A REFUSED REQUEST IS SAID OUT LOUD. The switch was typed on purpose; falling back to the ordinary
# [SKIP] would answer a deliberate question with the silence it was typed to end. That is the same
# doctrine the -OnlyConsumer "not registered" notice already stands on further down: the worst outcome
# available here is a positive-sounding run over consumers nothing looked at.
#
# THE LIB IS DOT-SOURCED LAZILY, INSIDE THE SWITCH, and that is the cost argument being carried out
# rather than stated. native-capture-lib.ps1 exists for exactly this call -- Windows PowerShell 5.1
# promotes a native command's stderr to a terminating error, and a network call has to be bounded -- but
# this script is run by connector-sessioncheck.ps1 at every session start, where -RemoteRunners is off
# and nothing in that file would ever be called. A feature that is opt-in should be opt-in in what it
# loads too.
#
# AND NOT ASKED AT ALL UNDER -OnlyConsumer, because the answer is unreachable there. That switch means a
# session is asking about its own repo, whose checkout is present by definition, so 6b never fires and
# $RemoteRunnerRead is never read -- while the probe itself would still spawn a gh process on the
# SessionStart path, which is the one cost this whole design is arranged around. A refusal notice would
# be wrong there too: nothing was going to be read either way, so there is nothing to report as refused.
$RemoteRunnerRead = $false
if ($RemoteRunners -and -not $OnlyConsumer) {
    if (-not $ThisRepoName) {
        Write-Info "-RemoteRunners was asked for, but this repo's own name could not be read from Get-RepoName (scripts/repo-config.ps1) -- so check 6 is off for this run in both directions, on the disk and over the network. Nothing about any consumer's runners was read."
    } elseif (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Info "-RemoteRunners was asked for, but 'gh' is not on PATH -- no consumer's runners were read over the network. A checkout that IS present on this machine is still judged off the disk by check 6."
    } else {
        . (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')
        # -DiscardStderr because `gh auth status` writes its whole report to stderr even when it
        # succeeds, and nothing here parses it: the exit code is the answer.
        $ghAuth = Invoke-NativeCapture -FilePath 'gh' -Arguments @('auth', 'status') -DiscardStderr -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds
        if (-not (Test-NativeExitMeasured -Capture $ghAuth)) {
            # A THIRD STATE, BECAUSE THE ADVICE IS WRONG IN IT (issue #1931, audited under #2081). An
            # unmeasurable exit code satisfies `-ne 0`, so this printed "'gh auth status' exited " and then
            # told the reader to log in -- on a run where gh may be perfectly authenticated and only its
            # exit code was lost. The remote read is still skipped, which is the honest direction, but the
            # remedy offered is now the one that fits.
            Write-Info "-RemoteRunners was asked for, but 'gh auth status' ran and its exit code could not be measured (issue #1931) -- no consumer's runners were read over the network. That says nothing about your credential; run this again."
        } elseif ($ghAuth.ExitCode -ne 0) {
            Write-Info "-RemoteRunners was asked for, but 'gh auth status' exited $($ghAuth.ExitCode) -- no consumer's runners were read over the network. Run 'gh auth login' and try again: this register's manifests carry a 'visibility' field and the private ones cannot be read without a credential, which is exactly the set this switch exists for."
        } else {
            $RemoteRunnerRead = $true
        }
    }
}

# THIS REPO'S OWN MARKETPLACE NAME, i.e. the segment after the '@' in an id like
# 'dkj-policy@dkj-claude-plugins' (#1775). Needed by the per-connector [UNLISTED] check further
# down, which has to tell "an id this register is responsible for" from "an id naming a marketplace
# this register has never heard of and has no business reporting on".
#
# READ VIA Get-MarketplacePath (plugin-tree-lib.ps1, just dot-sourced above) RATHER THAN A NEW READER --
# it is the same path $PluginRoots was built from a line above, so this does not add a second way to
# find marketplace.json, only a second field read out of it. Get-MarketplaceName (release-lib.ps1)
# already does this exact parse, but is not the source here: release-lib dot-sources entry-scaffold-lib
# behind it (release-lib.ps1:113), and that file is 8,289 lines (measured: `wc -l
# scripts/lib/entry-scaffold-lib.ps1`) -- and this script is the one SessionStart itself runs on every
# session via connector-sessioncheck.ps1, a cost every session would pay for a field only the (rare)
# [UNLISTED] finding ever uses.
#
# Degrades to '' on anything short of success (no marketplace.json, unparseable JSON, no/empty 'name'),
# and the [UNLISTED] check below is switched off entirely rather than guessing when this is empty --
# same doctrine as the source-stamp fallback just below: an omitted answer is honest, a fabricated one
# would be exactly the defect this repo has scar tissue from.
$ThisMarketplaceName = ''
try {
    $marketplacePath = Get-MarketplacePath -RepoRoot $RepoRoot
    if (Test-Path -LiteralPath $marketplacePath -PathType Leaf) {
        $marketplaceObj = Get-Content -LiteralPath $marketplacePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if (($marketplaceObj.PSObject.Properties.Name -contains 'name') -and $marketplaceObj.name) {
            $ThisMarketplaceName = [string]$marketplaceObj.name
        }
    }
} catch {
    $ThisMarketplaceName = ''
}

# Plugin id (before the '@') -> that plugin's folder, or $null when this repo does not publish a plugin
# by that name.
#
# IT ASKS THE MARKETPLACE INSTEAD OF JOINING A PATH. This used to be Join-Path <plugins root> <name>,
# which answers "is there a folder with this name" -- a different question, and one that gives the wrong
# answer in both directions: a folder that is not a published plugin resolved happily (subagent-shared/
# would have -- it sat directly under plugins/ then, and has since moved down beside the teams it
# feeds), while a plugin whose folder is not named after it, or does not sit exactly one level down,
# resolved to nothing.
#
# WHAT THE SLUG CHECK IS FOR NOW, STATED HONESTLY, because it used to be load-bearing and no longer is.
# Test-PluginNameSlug exists to gate a value "before it becomes a path segment" (see its own docstring),
# and nothing here builds a path out of $name any more -- the lookup is an ordinal string comparison
# against names the marketplace declares, so a traversal sequence in the register would simply match
# nothing. It is kept as a cheap early exit on a malformed id from a register file, not as a
# path-traversal guard, and removing it would reopen no security hole. Said plainly so the next reader
# does not infer one from its presence.
# THREE WAYS TO FAIL, AND ONLY TWO OF THEM ARE FAULTS (August 9, 2026). This returned a bare $null and
# the caller reported every one of them as 'invalid or unknown plugin field'. That was survivable while
# the lookup was a directory probe, because the only way to miss was a name nobody publishes. Asking the
# marketplace added a second way to miss, and it is not a defect at all: a plugin that HAS been renamed
# upstream is one this consumer simply has not migrated to yet.
#
# Measured the day the teams/workflows rename shipped: this check reported four [ERROR] lines against
# life-hub and smartwatchbanden for holding 'specialists@...' and 'specialists-shopify@...' -- ids that
# were correct for those repos, recorded on purpose, and which connectors/README.md had just been
# updated to say are kept deliberately until each consumer migrates. The check and the doctrine
# contradicted each other, and the doctrine was right: this register records what a consumer HAS.
#
# So the reasons are separated and named:
#   malformed  -- the id is not a slug at all. A register file defect. Still an error.
#   retired    -- a well-formed name the marketplace no longer declares. The consumer has not migrated.
#   no-source  -- declared, but its folder is absent from this checkout. A source-tree defect.
function Get-PluginDir([string]$PluginId) {
    $name = $PluginId.Split('@')[0]
    if (-not (Test-PluginNameSlug -Name $name)) {
        return [pscustomobject]@{ Dir = $null; Status = 'malformed'; Name = $name }
    }
    $root = Get-PluginRootByName -PluginRoots $PluginRoots -Name $name
    if (-not $root) {
        return [pscustomobject]@{ Dir = $null; Status = 'retired'; Name = $name }
    }
    if (-not (Test-Path -LiteralPath $root.Root)) {
        return [pscustomobject]@{ Dir = $null; Status = 'no-source'; Name = $name }
    }
    return [pscustomobject]@{ Dir = $root.Root; Status = 'ok'; Name = $name }
}

# Ids (<group>-<id>) owned by a plugin: agents/ + personas/.
function Get-PluginIds([string]$PluginDir) {
    $ids = @()
    foreach ($sub in @('subagents', 'agents', 'personas')) {
        $dir = Join-Path $PluginDir $sub
        if (Test-Path -LiteralPath $dir) {
            $ids += Get-ChildItem -LiteralPath $dir -Filter '*.md' -File |
                ForEach-Object { $_.BaseName -replace '-(agent|persona)$', '' }
        }
    }
    return $ids | Sort-Object -Unique
}

# Collect manifests from the register at family level.
if ($Manifest) {
    $manifestFiles = @(Get-Item -LiteralPath $Manifest)
} else {
    $connectorsRoot = Join-Path $RepoRoot 'connectors'
    $manifestFiles = @()
    if (Test-Path -LiteralPath $connectorsRoot) {
        $manifestFiles = @(Get-ChildItem -LiteralPath $connectorsRoot -Filter '*.json' -File)
    }
}

if ($manifestFiles.Count -eq 0) {
    Write-Host 'No connectors manifests found.' -ForegroundColor Yellow
    exit 0
}

$onlyPath = ''
if ($OnlyConsumer) {
    $onlyResolved = Resolve-Path -LiteralPath $OnlyConsumer -ErrorAction SilentlyContinue
    if ($onlyResolved) { $onlyPath = $onlyResolved.Path }
}

# Is this checkout the repo the current session is in? Two shapes, because the check runs two ways:
# a consumer's hook passes -OnlyConsumer <its own root>, while the workshop runs the full sweep with
# no scoping and finds itself as the connector whose localCheckout is '.'. Used to decide whether a
# register finding is actionable HERE (see the [INVENTORY] marker below); with -OnlyConsumer set,
# $onlyPath is authoritative -- falling back to $RepoRoot in that case would attribute a consumer's
# finding to the workshop.
function Test-IsSessionRepo {
    param([Parameter(Mandatory = $true)][string]$Checkout)
    if ($onlyPath) { return $Checkout -eq $onlyPath }
    return $Checkout -eq $RepoRoot
}

function Write-RunnerPathFinding {
    <#
        Check 6's verdicts about ONE workflow file, whatever route the text arrived by (#1808).

        Extracted rather than copied when the network read was added: the local half and the remote
        half differ only in how the bytes are obtained, and two copies of the judgement would be two
        places for the [ERROR] wording, the token wrapping and the three-outcome split to drift apart.
        The one thing the caller supplies is $Where -- a clause naming where this text came from,
        which is empty for a working copy (the reader is standing in it) and names the branch for a
        remote read (the reader is not, and a finding about a file they cannot open has to say which
        revision it is about).

        EVERY VALUE LIFTED OUT OF THE CONSUMER'S FILE IS WRAPPED, THE FILENAME INCLUDED.
        Format-SafePathToken rather than Format-SafeToken, because all three subjects here are
        path-shaped and #414 is exactly that argument -- the id charset deletes what makes a path
        findable. What it strips is the class that matters on this route: control characters, which
        could forge a line in the session context the SessionStart hook forwards, and square brackets,
        which the hooks COUNT as verdict markers. A workflow file named 'x[ERROR] evil.yml' is a legal
        filename on NTFS and would otherwise change a hook's verdict from a consumer's own directory
        listing -- and over the network it is a name anybody with push access to that repo chooses.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$WorkflowName,
        [Parameter(Mandatory = $true)][AllowEmptyString()][AllowNull()][string]$WorkflowText,
        [string]$Where = ''
    )

    $refs = @(Get-SharedScriptReference -WorkflowText $WorkflowText -RepositoryName (@($ThisRepoName) + $ThisRepoRetiredNames))
    if ($refs.Count -eq 0) { return }

    $wfName = Format-SafePathToken -Value $WorkflowName
    $suffix = if ($Where) { " ($Where)" } else { '' }
    foreach ($judged in @(Test-SharedScriptReference -Reference $refs -SourceRoot $RepoRoot)) {
        if ($judged.Exists) { continue }

        # AN ESCAPING REFERENCE IS ITS OWN FINDING, and deliberately not phrased as a missing path:
        # nothing was looked up, because looking it up is what the lib refuses to do (it would answer
        # whether an arbitrary file exists on this machine).
        if ($judged.Escapes) {
            Write-Failure "$wfName line $($judged.Line) runs '$(Format-SafePathToken -Value $judged.Path)', which does not stay inside the checkout of this repo it is resolved against -- so it was NOT looked up here. A runner reaching outside its own checkout cannot work on a CI machine whatever this tree holds; correct it in that consumer.$suffix"
            continue
        }

        $where = if ($judged.MovedTo.Count -gt 0) {
            "it is at $((@($judged.MovedTo) | ForEach-Object { Format-SafePathToken -Value $_ }) -join ' / ') now"
        } else {
            'no file of that name exists anywhere here, so it was removed rather than moved'
        }
        Write-Failure "$wfName line $($judged.Line) runs '$(Format-SafePathToken -Value $judged.Path)' out of a checkout of this repo, and that path does not exist here -- $where. That runner is red on every pull request in this consumer until the path is corrected there; nothing in this repo can correct it from here.$suffix"
    }
}

function Write-RunnerAdoptionFinding {
    <#
        Check 6c's verdict about a consumer's runners AS A SET (#1850) -- the question check 6 cannot
        ask, because it judges paths that are named and a consumer running no runner names none.

        [INFO], NOT [ERROR], and that is the register's own settled doctrine rather than a softening.
        connectors/README.md already draws the line for the neighbouring case (a plugin id the
        marketplace no longer declares): "this consumer has not migrated, which is a state rather than
        a defect". The two halves of adopt-dkj-policy that place these runners are optional and
        separate from enabling the plugin, so an absent runner may be a decision somebody made. That is
        exactly why check 6 stays an [ERROR] and this does not: a runner naming a path this tree no
        longer has is red on every pull request in that consumer, with nobody able to learn it from
        their side; a runner nobody scaffolded is a repo working as its owner left it.

        GATED ON THE MANIFEST LISTING THE WORKFLOW PLUGIN, because that plugin is what places these
        runners. A consumer registered for the subagent teams alone has no reason to carry them, and an
        [INFO] against it would be this register inventing an expectation the consumer never took on.
        Every name that plugin has carried is matched, for the reason its rename history already forces
        on $ThisRepoRetiredNames one axis over: this register records what a consumer HAS, so a manifest
        still naming an old id is accurate until that consumer reinstalls, and a matcher knowing only
        today's name would go quiet on exactly the repos furthest behind.

        THE SOURCE REPO IS EXCLUDED BY ITS CALLER, NOT HERE, and the exclusion is a fact about the
        mechanism rather than a courtesy to ourselves: this repo runs all three of those scripts by
        LOCAL path, because it is the tree the others check out. It is the most adopted consumer in the
        register and the only one that can never produce a reference.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][AllowNull()][object[]]$Workflow,
        [Parameter(Mandatory = $true)][string]$ManifestName,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$ListedPluginId,
        [string]$Where = ''
    )

    $wantsRunners = $false
    foreach ($id in @($ListedPluginId)) {
        if (-not $id) { continue }
        $name = ([string]$id).Split('@')[0]
        if ($WorkflowPluginNames -contains $name) { $wantsRunners = $true; break }
    }
    if (-not $wantsRunners) { return }

    $verdict = Test-ConsumerRunnerAdoption -Workflow $Workflow -RepositoryName (@($ThisRepoName) + $ThisRepoRetiredNames)
    if ($verdict.Status -eq 'adopted') { return }

    $suffix = if ($Where) { " ($Where)" } else { '' }

    # 'unreadable' is NOT reported as a verdict about adoption -- nothing was judged, and a line saying
    # otherwise would be the class of false all-clear (inverted) that this whole check exists to end.
    if ($verdict.Status -eq 'unreadable') {
        Write-Info "this consumer has $($verdict.Workflows) workflow file(s) and none of them came back with text, so whether any of them runs this workflow's CI runners was NOT established.$suffix"
        return
    }

    $state = if ($verdict.Status -eq 'no-workflows') {
        'has no .github/workflows at all'
    } else {
        "has $($verdict.Workflows) workflow file(s), and not one of them checks this repository out"
    }
    $partial = if ($verdict.Unreadable -gt 0) { " ($($verdict.Unreadable) of them could not be read and were not judged)" } else { '' }

    Write-Info "this consumer names the workflow plugin in $ManifestName but $state$partial -- so none of the runners 'adopt-dkj-policy' places is running there: the branch-entry gate (part 1) fires on none of its pull requests, and the fold and the resolves verification (part 3) do not survive a merge no session observes. That may be deliberate -- both parts are optional and separate from enabling the plugin, and nothing here can tell a decision from an omission. If it is deliberate, say so in $ManifestName's 'notes'; if it is not, run the 'adopt-dkj-policy' skill in that repo. Only a checkout step naming this repository counts as a runner here, so this says nothing recognisable reaches into this tree rather than that nothing is there.$suffix"
}

# Test-GitHubOwnerNameSlug moved to scripts/lib/check-report-lib.ps1 (#1869): a third caller outside
# this file -- check-consumer-siblings.ps1 -- turns the same manifest 'repo' field into the same kind
# of API call, which is the case its own docstring already made against a second copy of the regexes.


function Get-RemoteConsumerWorkflow {
    <#
        Every '.github/workflows/*.yml' of $Repo's default branch, WITH ITS TEXT, in one call (#1808).

        Returns @{ Status; Reason; Branch; Files } where Status is one of:
          'read'        -- Files holds @{ Name; Text } per workflow (possibly empty: a repo may have
                           the directory and no .yml in it, which is the same nothing-to-say as a
                           consumer whose runners are all current)
          'no-workflows'-- the repository was read and has no .github/workflows at all -> silence, the
                           same verdict the local half reaches when the directory is not there
          'unavailable' -- nothing was learned. Reason says what happened, and the CALLER must print
                           it: this is the state the switch exists to make visible.

        ONE GraphQL CALL, NOT 2+N REST ONES, and the reason is the third state rather than the count.
        The REST route is `contents/.github/workflows` to list, then `contents/<path>` per file, and
        its listing call answers a repository this token cannot see and a repository with no workflows
        directory with the SAME HTTP 404 -- so it cannot tell 'nothing to report' from 'nothing was
        read', which is the one distinction this whole function is for. GraphQL answers both in one
        response and distinguishes them structurally: a null 'repository' is no access, a null
        'object' is no such tree. That it is also one round trip instead of four is a bonus, not the
        argument.

        THE DEFAULT BRANCH IS THE SUBJECT, and 'HEAD:' is how that is said in an expression -- the
        runner that fires on a consumer's pull requests is the one on their trunk, not whatever a
        topic branch is carrying. The branch NAME is read back and returned so a finding can cite it,
        because a reader who cannot open the file needs to know which revision was judged.

        THE EXPRESSION IS A GraphQL VARIABLE AND NOT AN INLINE STRING, WHICH IS A 5.1 HAZARD AND NOT A
        STYLE PREFERENCE. Written the obvious way -- object(expression:"HEAD:.github/workflows") --
        the query carries double quotes, and Windows PowerShell 5.1 does not pass those through to a
        native command intact: gh received expression:HEAD:.github/workflows and answered
        'Expected NAME, actual: COLON (":") at [1, 118]'. Measured on the first run of this function,
        against three real connectors, and it failed IDENTICALLY on all three -- which is the shape
        worth recording: a transport fault that is total looks exactly like a repository nobody can
        read, so it would have been reported as the third state for every consumer and believed. As a
        variable the query string contains no quote at all, and the value travels as its own argument
        where nothing rewrites it.

        THE SLUG IS GUARDED BEFORE IT REACHES A URL, VIA Test-GitHubOwnerNameSlug (defined just above,
        and reused by check 1b's arm 2 and arm 3 remedy lines since #1821). 'repo' is manifest content
        from a public repository -- the same data the localCheckout guardrails above already refuse to
        trust -- and here it would become the owner and name of an API call. Held to GitHub's own shape
        rather than merely escaped: an owner is alphanumeric with hyphens, a repository name adds '.'
        and '_', and anything else is not a slug this register can have meant.

        stderr IS DISCARDED AND NOTHING IS LOST BY IT, because GraphQL puts its diagnosis in the BODY.
        A repository this credential cannot see comes back as HTTP 200 with data.repository = null and
        an errors[] block carrying "Could not resolve to a Repository with the name '<slug>'" -- on
        stdout, which is what this parses. gh still exits 1 on such a response, so the exit code is
        deliberately NOT consulted before the parse: reading it first would replace that sentence with
        'gh exited 1' on every private consumer, which is the single most common outcome this function
        has. The exit code is the fallback for a response there is no JSON in at all.

        THE API'S OWN MESSAGE IS WRAPPED BEFORE IT IS PRINTED. It quotes the slug back, which came
        from a manifest in a public repository, so the round trip through GitHub is not laundering:
        the same value returns inside a sentence this script prints into a session.
    #>
    param([Parameter(Mandatory = $true)][string]$Repo)

    $slugCheck = Test-GitHubOwnerNameSlug -Slug $Repo
    if (-not $slugCheck.Ok) {
        return @{ Status = 'unavailable'; Reason = "the manifest's 'repo' field is $($slugCheck.Reason)"; Branch = ''; Files = @() }
    }
    # Split ONLY after the guard above has already confirmed the shape, so this is a plain re-derivation
    # of what Test-GitHubOwnerNameSlug already validated, not a second, unchecked parse of manifest content.
    $slash = $Repo.IndexOf('/')
    $owner = $Repo.Substring(0, $slash)
    $name  = $Repo.Substring($slash + 1)

    $query = 'query($owner:String!,$name:String!,$expr:String!){repository(owner:$owner,name:$name){defaultBranchRef{name} object(expression:$expr){... on Tree{entries{name type object{... on Blob{text}}}}}}}'
    $call = Invoke-NativeCapture -FilePath 'gh' `
        -Arguments @('api', 'graphql', '-f', "query=$query", '-f', "owner=$owner", '-f', "name=$name", '-f', 'expr=HEAD:.github/workflows') `
        -DiscardStderr -TimeoutSeconds $NativeCaptureNetworkTimeoutSeconds

    if ($call.TimedOut) {
        return @{ Status = 'unavailable'; Reason = "gh did not answer within $NativeCaptureNetworkTimeoutSeconds seconds"; Branch = ''; Files = @() }
    }

    # PARSED BEFORE THE EXIT CODE IS LOOKED AT -- see the docstring. The body is where GraphQL says why.
    $json = $null
    try { $json = ($call.Output -join "`n") | ConvertFrom-Json } catch { $json = $null }
    if ($null -eq $json) {
        # A SHORT READ IS A FACT ABOUT THIS RUN, NOT ABOUT THE REPOSITORY, and separating the two is the
        # whole reason Invoke-NativeCapture carries the field (#1679). Passing -TimeoutSeconds routes
        # this call through the Start-Process arm, which can answer exit 0 with a capture a grandchild
        # was still writing -- and a truncated JSON document does not parse. Folded into the generic
        # line below it would read as 'this consumer could not be read', which is 13d's sentence about a
        # credential that cannot see the repo: the reader would go looking at the register or at their
        # auth for something that settles on a re-run. Same split, and the same remedy sentence, that
        # claim-issue.ps1 and verify-resolved-issues.ps1 already make at their own gh calls.
        # AND THE UNMEASURABLE EXIT CODE IS THE SAME KIND OF FACT (issue #1931, audited under #2081),
        # which is why it sits beside the short read rather than in the generic arm: the arm below would
        # have printed "gh exited  and answered with nothing this could parse as JSON", a sentence about
        # that repository built on a number this run never had. Same split, same remedy.
        $reason = if (-not (Test-NativeExitMeasured -Capture $call)) {
            'gh ran and its exit code came back unmeasurable (issue #1931), so nothing arrived that this could judge -- a fact about this run rather than about that repository, and it normally settles on a re-run'
        } elseif ($call.ShortRead) {
            'gh exited 0 but its capture was still being written when this run read it, so what arrived was not a whole JSON document -- a fact about this run rather than about that repository, and it normally settles on a re-run'
        } else {
            "gh exited $($call.ExitCode) and answered with nothing this could parse as JSON"
        }
        return @{ Status = 'unavailable'; Reason = $reason; Branch = ''; Files = @() }
    }

    # Read defensively throughout: StrictMode makes a missing property terminating, and every shape
    # below is a legitimate answer from the API rather than a corrupt response.
    $repoNode = Get-JsonField -Object (Get-JsonField -Object $json -Name 'data' -Default $null) -Name 'repository' -Default $null
    if ($null -eq $repoNode) {
        $apiSaid = ''
        foreach ($e in @(Get-JsonField -Object $json -Name 'errors' -Default @())) {
            $msg = [string](Get-JsonField -Object $e -Name 'message' -Default '')
            if ($msg) { $apiSaid = Format-SafeProseToken -Value $msg; break }
        }
        $reason = if ($apiSaid) {
            "the API answered: $apiSaid -- so it does not exist, or this credential cannot see it"
        } else {
            # THE LABEL HERE TOO (issue #1931, audited under #2081). This is the SIBLING of the repaired
            # branch above it, and it was missed on the first pass: the parse can succeed while the exit
            # code itself is the unmeasurable one -- two independent races on the same object -- and then
            # this printed "(gh exited )". Nothing else changes; the verdict was already right.
            "the API returned no repository (gh $(Get-NativeExitLabel -Capture $call)) -- it does not exist, or this credential cannot see it"
        }
        return @{ Status = 'unavailable'; Reason = $reason; Branch = ''; Files = @() }
    }

    $branch = [string](Get-JsonField -Object (Get-JsonField -Object $repoNode -Name 'defaultBranchRef' -Default $null) -Name 'name' -Default '')
    $tree = Get-JsonField -Object $repoNode -Name 'object' -Default $null
    if ($null -eq $tree) {
        return @{ Status = 'no-workflows'; Reason = ''; Branch = $branch; Files = @() }
    }

    $files = @()
    foreach ($entry in @(Get-JsonField -Object $tree -Name 'entries' -Default @())) {
        if ([string](Get-JsonField -Object $entry -Name 'type' -Default '') -ne 'blob') { continue }
        $entryName = [string](Get-JsonField -Object $entry -Name 'name' -Default '')
        if ($entryName -notmatch '\.ya?ml$') { continue }
        # A null 'text' is a blob the API declined to render as text (binary, or over its size limit).
        # Reported as its own file-level nothing rather than treated as an empty workflow, which would
        # read as 'this file names no reference' -- the exact false negative the lib's header warns
        # about, arriving through the transport instead of through the parser.
        $text = Get-JsonField -Object (Get-JsonField -Object $entry -Name 'object' -Default $null) -Name 'text' -Default $null
        $files += @{ Name = $entryName; Text = $(if ($null -eq $text) { $null } else { [string]$text }) }
    }

    return @{ Status = 'read'; Reason = ''; Branch = $branch; Files = @($files) }
}

# WHICH SOURCE TREE THE VERSION VERDICTS BELOW WERE READ FROM (#533).
#
# Every 'source on vX' in this run comes from a plugin.json in THIS checkout, read now. That is a
# point-in-time fact, and the SessionStart hook forwards it into a session that then keeps it for
# hours -- so the claim outlives the tree it was true of. Measured on 2026-08-09: a session started
# at faa7273 (source v3.6.0), a `git pull` moved the checkout to 855fd40 (source v3.9.0) at 10:24,
# and the line already in context still said v3.6.0. Nothing was wrong with it except its age, and
# nothing about it said how old it was.
#
# So the run names the commit it measured. A reader comparing it against `git rev-parse --short HEAD`
# sees the gap in one step, which is what an undated version claim cannot offer at any price. It is
# printed ONCE at run level rather than per finding: it is the same answer for every line below, and
# repeating it would cost the reader on every line to say nothing new.
#
# Degrades silently rather than guessing: a checkout without git, or a source tree that is not a git
# repo at all (a consumer holding a downloaded copy), simply gets the header it always had. An
# omitted stamp is honest; a fabricated one would be exactly the defect this closes.
$sourceStamp = ''
try {
    $sha = (& git -C $RepoRoot rev-parse --short HEAD 2>$null)
    if ($LASTEXITCODE -eq 0 -and $sha) { $sourceStamp = " -- source read at $($sha.Trim())" }
} catch {
    $sourceStamp = ''
}

Write-Host "== check-connectors -- $($manifestFiles.Count) manifest(s)$sourceStamp ==" -ForegroundColor Cyan

$checkedConsumers = @{}
$matched = 0

foreach ($mf in $manifestFiles) {
    $m = Get-Content -LiteralPath $mf.FullName -Raw -Encoding UTF8 | ConvertFrom-Json

    # Every finding from here to the end of this iteration belongs to THIS connector, so it carries
    # that name (inbound #203). The session hook filters this script's output down to the signal
    # lines and drops the '== connector: <repo>' headers, which is how two consumers on the same
    # outdated plugin version produced two IDENTICAL, unattributable [ERROR] lines. Set per iteration
    # rather than once: a stale label from the previous connector would misattribute the guardrail
    # failures below, which fire before this connector's header is ever printed.
    # 'repo' is manifest content, so its presence is probed rather than assumed (StrictMode); the
    # manifest filename is a truthful fallback.
    $connectorLabel = $(if ($m.PSObject.Properties.Name -contains 'repo') { [string]$m.repo } else { $mf.Name })
    Set-CheckScope $connectorLabel

    # Determine the checkout, with guardrails on the manifest field. With -OnlyConsumer, manifests
    # of other consumers are SILENTLY skipped -- their guardrail messages should not land in
    # someone else's session either (Sean's advice, round 3).
    if ($ConsumerPathOverride) {
        $checkout = $ConsumerPathOverride
        $candidates = @($ConsumerPathOverride)
    } else {
        # localCheckout is ONE relative path, or a LIST of candidates -- the first one present on this
        # machine wins. The list exists because the field is a single per-manifest value while the
        # layout it describes is per-machine: measured 2026-09-06 (issue #1524), the two machines that
        # hold the BWJ checkouts place them at '../../bwjecommerce/<repo>' and
        # '../../GitHub/bwjecommerce/<repo>' respectively, so no single string is true on both.
        #
        # WHY THAT MATTERS MORE THAN A WRONG PATH USUALLY WOULD: a path this machine cannot find is not
        # reported as wrong, it is reported as '[SKIP] not present on this machine' -- a sentence that
        # ASSERTS the checkout is absent, exits 0, and hides everything the connector would have said.
        # #1524 measured what one such skip covered: four [INFO] lines and a drift check reading 26
        # missing agent-defs. A register whose miss is silent teaches nobody it is stale, which is why
        # the answer is to record every layout rather than to pick a machine and be wrong on the others.
        $candidates = @(@($m.localCheckout) | Where-Object { $null -ne $_ -and [string]$_ -ne '' })
        if ($candidates.Count -eq 0) {
            if ($OnlyConsumer) { continue }
            Write-Failure "no localCheckout path in $($mf.Name) -- rejected (a manifest names at least one relative path)."
            continue
        }
        $rooted = @($candidates | Where-Object { [System.IO.Path]::IsPathRooted($_) })
        if ($rooted.Count -gt 0) {
            if ($OnlyConsumer) { continue }
            Write-Failure "absolute localCheckout path '$($rooted -join "', '")' in $($mf.Name) -- rejected (relative sibling paths only)."
            continue
        }
        # First present wins. Deliberately not 'the only one present': two candidates resolving on one
        # machine is a layout question for whoever wrote them, not something this check can adjudicate,
        # and refusing here would break the sweep over a register that is merely generous.
        $checkout = $null
        $chosenCandidate = ''
        foreach ($candidate in $candidates) {
            $probe = Join-Path $RepoRoot $candidate
            if (Test-Path -LiteralPath $probe) { $checkout = $probe; $chosenCandidate = $candidate; break }
        }
    }
    # $checkout is $null when no candidate resolved; with -ConsumerPathOverride it is the override,
    # which is probed here exactly as a single manifest path always was.
    if (-not $checkout -or -not (Test-Path -LiteralPath $checkout)) {
        if (-not $OnlyConsumer) {
            Write-Host "`n== connector: $($m.repo)" -ForegroundColor Cyan
            # THE [SKIP] SENTENCE CHANGES WITH THE SWITCH, because under -RemoteRunners it would
            # otherwise be false: one thing about this consumer IS about to be checked. A verdict line
            # that contradicts the lines under it is the class of defect this register keeps filing
            # against itself, so it is worded from what the run actually did.
            if ($RemoteRunnerRead) {
                Write-Skip "checkout '$($candidates -join "', '")' not present on this machine -- everything needing the disk is unchecked; its CI runners are read over the API below (-RemoteRunners)."
            } else {
                Write-Skip "checkout '$($candidates -join "', '")' not present on this machine -- not checked."
            }

            # --- 6b. CHECK 6, OVER THE NETWORK, ON REQUEST ONLY (#1808) --------------------------
            # This is the one thing about an absent consumer that can be learned from anywhere, and the
            # one this register most wants to know: a stale runner path is a required check red on every
            # pull request in a repo nobody is visiting, which is precisely why nobody has noticed. So
            # the [SKIP] above is no longer the last word when the switch is on -- everything else here
            # genuinely needs the disk (an extension inventory, a settings chain, a machine record), and
            # this alone does not.
            #
            # INSIDE THE -OnlyConsumer GUARD, deliberately. With -OnlyConsumer the session is asking
            # about its own repo, whose checkout is present by definition -- so an absent one reached
            # here is somebody else's, and reading it would put another consumer's findings in a
            # session that asked about neither. Same reasoning the [SKIP] itself is already suppressed
            # under.
            #
            # 'repo' is manifest content, so its presence is probed rather than assumed (StrictMode),
            # exactly as $connectorLabel above does it. Without it there is no repository to ask about
            # and the reason says so, rather than an empty slug reaching a URL.
            if ($RemoteRunnerRead) {
                $remoteRepo = [string]$(if ($m.PSObject.Properties.Name -contains 'repo') { $m.repo } else { '' })
                if (-not $remoteRepo) {
                    Write-Info "-RemoteRunners: $($mf.Name) names no 'repo', so its runners could not be read over the network either -- nothing about this consumer's CI was checked."
                } else {
                    $remote = Get-RemoteConsumerWorkflow -Repo $remoteRepo
                    if ($remote.Status -eq 'unavailable') {
                        # THE THIRD STATE, AND THE WHOLE REASON THE SWITCH IS WORTH HAVING. Silence here
                        # would be indistinguishable from a clean read on a check whose subject is a
                        # breach nobody has noticed -- so it says what happened and hands over the one
                        # command that shows gh's own message, which was discarded to keep the JSON
                        # parseable.
                        Write-Info "-RemoteRunners: this consumer's CI runners could not be read -- $($remote.Reason). Nothing about them was checked; 'gh api repos/$(Format-SafePathToken -Value $remoteRepo)' shows what gh itself says about the repository."
                    } elseif ($remote.Status -eq 'read' -or $remote.Status -eq 'no-workflows') {
                        $onBranch = if ($remote.Branch) { "read from $(Format-SafePathToken -Value $remote.Branch) over the API -- no checkout of this consumer is on this machine" } else { 'read over the API -- no checkout of this consumer is on this machine' }
                        foreach ($rf in @($remote.Files)) {
                            if ($null -eq $rf.Text) {
                                Write-Info "-RemoteRunners: $(Format-SafePathToken -Value $rf.Name) came back without text (binary, or past the API's size limit), so it was NOT judged. Every other workflow in that repository was."
                                continue
                            }
                            Write-RunnerPathFinding -WorkflowName $rf.Name -WorkflowText $rf.Text -Where $onBranch
                        }

                        # --- 6c OVER THE NETWORK (#1850) ------------------------------------------
                        # 'no-workflows' USED TO BE SILENCE ON PURPOSE here, on the reading that a
                        # consumer running none of these runners had nothing for this check to say
                        # about it. That reading was the blind spot itself: it made an unadopted repo
                        # indistinguishable from a clean one, which is what #1850 measured. It reaches
                        # this block rather than the one above because that status carries no files,
                        # and the verdict function is what turns 'no files' into a sentence.
                        $remotePluginIds = @()
                        if ($m.PSObject.Properties.Name -contains 'plugins') {
                            $remotePluginIds = @(@($m.plugins) |
                                Where-Object { $null -ne $_ -and ($_.PSObject.Properties.Name -contains 'id') -and $_.id } |
                                ForEach-Object { [string]$_.id })
                        }
                        Write-RunnerAdoptionFinding -Workflow @($remote.Files) -ManifestName $mf.Name -ListedPluginId $remotePluginIds -Where $onBranch
                    }
                }
            }
        }
        continue
    }
    $checkout = (Resolve-Path -LiteralPath $checkout).Path

    # Early scoping: only the manifest of the requested consumer gets through here.
    if ($onlyPath -and $checkout -ne $onlyPath) { continue }

    if (-not $ConsumerPathOverride) {
        $scopeRoot = (Resolve-Path -LiteralPath (Join-Path $RepoRoot '..\..')).Path
        if (-not $checkout.StartsWith($scopeRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Failure "localCheckout '$chosenCandidate' falls outside the allowed scope ('$scopeRoot') -- rejected."
            continue
        }
    }
    $matched++

    Write-Host "`n== connector: $($m.repo)" -ForegroundColor Cyan

    # --- 1b. THE CHECKOUT'S OWN GIT IDENTITY, ASKED BEFORE ANYTHING READS IT BY NAME (#1821) ---------
    # Check 1 above only asks whether A FOLDER is present at localCheckout; it never asks WHICH
    # repository that folder actually is. Reproduced on this machine: smartwatchbanden.json names
    # 'BWJ-Development/smartwatchbanden', while '../../bwjecommerce/smartwatchbanden' -- the candidate
    # that resolved -- is a clone of 'BWJ-ecommerce/smartwatchbanden', a DIFFERENT, archived repository
    # that merely shares a name half. Left unasked, every verdict from here on (checks 2-6) is read off
    # that wrong repo's disk and printed under the register's name -- worse than silence, because it
    # invites 'fixing' a consumer that was already correct. So this runs BEFORE
    # Get-EnabledPlugins/Get-InstallRecord touch that disk on the named repo's behalf.
    #
    # THE READ IS LOCAL, NOT NETWORK -- 'git -C <checkout> remote get-url origin' opens .git/config on
    # this machine, the same class of call the $sourceStamp block above already makes against this
    # repo's own HEAD. It is not routed through native-capture-lib.ps1: that lib exists to bound a call
    # that LEAVES the machine, and this one never does.
    #
    # --show-toplevel, NOT --is-inside-work-tree (Victor's finding, #1821). The latter answers about a
    # PARENT: it is 'true' for any folder NESTED INSIDE a work tree, not only for that work tree's own
    # root -- so a localCheckout candidate that resolves to a folder sitting inside somebody's wrapper
    # repo (their whole 'GitHub/' folder, say) would still read as a work tree, and 'remote get-url
    # origin' would then walk UP and answer with the ENCLOSING repository's origin as if it were this
    # checkout's own identity. Two ways that goes wrong: a folder that was never cloned produces a
    # false arm-3 [ERROR] blaming a repository that has nothing to do with it, or -- in the unlucky
    # case where the enclosing repo happens to match the manifest -- a false SILENT arm-1 agreement for
    # a folder that was never a clone of anything. The ROOT COMPARISON is the question this check
    # actually needs (IS $checkout itself the work tree's root), and it is what decides the verdict
    # below; --is-inside-work-tree on its own never could, for the reason just given.
    #
    # THE TWO FLAGS ARE NOW ASKED TOGETHER, IN ONE CALL (issue #2115), which this paragraph used to say
    # was unnecessary -- "REPLACES --is-inside-work-tree outright rather than joining it". That was
    # right about the VERDICT and is no longer right about the CALL. The root read moved to
    # Get-GitTopLevelPath, which resolves the root from --show-cdup because --show-toplevel's raw path
    # is decoded with the console code page -- and --show-cdup alone cannot tell a work tree from the
    # .git directory, where it exits 0. So the second flag is back as a GUARD on the first, not as a
    # rival to it, and it is still not a third git call: `git rev-parse` takes both at once.
    $originRepo = $null
    $checkoutToplevel = ''
    $notCheckoutRoot = $false
    try {
        # NOT A BARE --show-toplevel (issue #2115): its output is a raw path, decoded by Windows
        # PowerShell 5.1 with [Console]::OutputEncoding, so a registered checkout under an accented
        # directory name never matched $checkout and was reported as "not the root of its work tree".
        # Get-GitTopLevelPath joins --is-inside-work-tree to --show-cdup, which is the same pair this
        # block already wanted: a folder inside no work tree at all still fails it the same way.
        $rawToplevel = (Get-GitTopLevelPath -From $checkout).Path
        if ($rawToplevel) {
            # Normalised before comparing: git answers with forward slashes even on Windows, while
            # $checkout has been through Resolve-Path (backslashes), and a trailing separator on
            # either side must not turn a real match into a false one.
            $checkoutToplevel = $rawToplevel.Trim().Replace('/', '\').TrimEnd('\')
            $checkoutNorm = $checkout.TrimEnd('\')
            if ([string]::Equals($checkoutToplevel, $checkoutNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
                $rawOrigin = (& git -C $checkout remote get-url origin 2>$null)
                if ($LASTEXITCODE -eq 0 -and $rawOrigin) {
                    # THE URL SHAPES GITHUB HANDS OUT: 'https://github.com/<owner>/<name>(.git)?',
                    # 'git@github.com:<owner>/<name>(.git)?', and 'ssh://git@github.com/<owner>/<name>(.git)?'
                    # -- a valid, not-rare remote shape the pattern used to fall through on unasked
                    # (Victor's finding). Anything else -- a non-GitHub remote, a bare local path --
                    # names no owner/name pair and falls through to arm 4 below, unasked rather than
                    # guessed at.
                    if ($rawOrigin.Trim() -match '^(?:https://github\.com/|git@github\.com:|ssh://git@github\.com/)([^/]+)/(.+?)(?:\.git)?/?$') {
                        $originRepo = "$($Matches[1])/$($Matches[2])"
                    }
                }
            } else {
                # $checkout resolved and IS inside a work tree, but is NOT that work tree's own root --
                # the question this check asks ("is this folder a clone of X") does not even apply to
                # it. That is arm 4 below, worded to say so, not a mismatch: nothing here contradicts
                # the register, the folder simply is not a checkout of anything in its own right.
                $notCheckoutRoot = $true
            }
        }
    } catch {
        # A THROW HERE IS THE COMMON TRIGGER, NOT A MISSING BINARY (Victor verified this empirically).
        # Under $ErrorActionPreference = 'Stop', both 'git rev-parse' on a folder that is not a work
        # tree and 'git remote get-url origin' with no 'origin' configured throw a terminating
        # NativeCommandError DESPITE the '2>$null' redirection -- redirecting stderr does not suppress
        # PowerShell's own promotion of a native command's non-zero exit into a terminating error. A
        # missing git binary would also land here, but it is not the common case this guards: an
        # ordinary "not a repo yet" or "no origin remote" checkout throws on every run. A future
        # "simplification" to '-ErrorAction SilentlyContinue' would reintroduce exactly that crash.
        $originRepo = $null
    }

    # 'repo' is manifest content, so its presence is probed rather than assumed (StrictMode), exactly
    # as $connectorLabel and the -RemoteRunners block above already do it.
    $manifestRepo = [string]$(if ($m.PSObject.Properties.Name -contains 'repo') { $m.repo } else { '' })

    if ($null -eq $originRepo) {
        if ($notCheckoutRoot) {
            # ARM 4, NAMED PRECISELY (#1821, Victor's finding): the folder resolved and IS inside a git
            # work tree, but it is not that work tree's own ROOT, so the question this check asks does
            # not apply to it at all -- not a mismatch, and not silence either. The useful fact for the
            # reader is exactly this: localCheckout landed inside somebody else's checkout rather than
            # being a clone of anything in its own right.
            Write-Skip "'$checkout' is not the root of the git work tree it sits inside (that root is '$(Format-SafePathToken -Value $checkoutToplevel)') -- check 1b could not ask whether IT is a clone of '$(Format-SafePathToken -Value $manifestRepo)', because it is not a checkout of anything in its own right. Every check below still runs against it."
        } else {
            # ARM 4 -- THE QUESTION COULD NOT BE ASKED (no git, not a git work tree, no readable 'origin',
            # or a remote this pattern does not recognise as GitHub). Silence would read as agreement; a
            # dim line instead, and everything below runs exactly as it did before this check existed.
            # NEVER asserted as a mismatch from a failed read -- the same doctrine new-branch.ps1's
            # stale-base block already follows for a question its own git call could not answer.
            Write-Skip "could not read this checkout's own git identity (no git on PATH, not a git work tree, or no readable 'origin' remote naming GitHub) -- check 1b was not able to ask whether it is a clone of '$(Format-SafePathToken -Value $manifestRepo)'. Every check below still runs against it."
        }
    } elseif ([string]::Equals($originRepo, $manifestRepo, [System.StringComparison]::OrdinalIgnoreCase)) {
        # ARM 1 -- agreement. Silent; everything below proceeds exactly as it always did.
    } elseif ($ThisRepoSlug -and
              [string]::Equals($manifestRepo, $ThisRepoSlug, [System.StringComparison]::OrdinalIgnoreCase) -and
              (& { $half = $originRepo.Substring($originRepo.LastIndexOf('/') + 1)
                   foreach ($n in (@($ThisRepoName) + $ThisRepoRetiredNames)) {
                       if ([string]::Equals($n, $half, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
                   }
                   return $false })) {
        # ARM 2 -- THIS REPO'S OWN RENAME HISTORY, AND BOUNDED TO IT. Measured on this machine:
        # connectors/dkj-claude-plugins.json names 'DKJ-Solutions/dkj-claude-plugins' (the #1769
        # rename), while THIS checkout's own origin is still
        # 'https://github.com/DKJ-Solutions/claude-code-specialists.git' -- a name-half match this
        # repo's own rename history explains, consistent with a transfer redirect. Without this arm,
        # check 1b fires a false [ERROR] on the source repo's OWN connector, at every session start, in
        # the very repo that ships the check.
        #
        # LOOSE NAME-HALF MATCHING, IGNORING OWNER, IS SAFE ONLY INSIDE THIS BOUND -- and the bound is
        # narrower than "CLAUDE.md forbids recreating the old path" (Edith's finding, #1821: that rule
        # forbids recreation only at THIS repo's own two retired paths and says nothing about a THIRD,
        # unrelated owner registering the bare name 'claude-code-specialists' under their own account,
        # which GitHub's per-owner namespacing does not prevent). The bound that actually holds: this
        # arm is reached only once the manifest's 'repo' has ALREADY been pinned to $ThisRepoSlug --
        # this repo's own CURRENT full slug -- and this repo's own connector record carries
        # localCheckout: "." -- so the only checkout that can EVER reach this arm is the tree the
        # script is running FROM. A hostile same-named repository under another owner would have to BE
        # that tree for this arm to fire on it, and if it is, the whole run is already somebody else's
        # repo -- this arm is not what failed in that scenario.
        # Across repos in general the same looseness IS the smartwatchbanden failure this issue was
        # filed over: 'BWJ-ecommerce/smartwatchbanden' and 'BWJ-Development/smartwatchbanden' share a
        # name half and are two different, unrelated repositories. Accepting the name half regardless
        # of owner is itself deliberate, not a gap in the bound: this repo has retired an OWNER as
        # well as a name ('DaveKJohn/' -> 'DKJ-Solutions/', September 2, 2026), and only the name
        # halves are recorded in a seam (Get-RetiredRepoNames) -- there is no matching
        # Get-RetiredRepoOwners to hold the owner half to.
        #
        # THE [SKIP] SAYS WHAT WAS MEASURED, NOT MORE (Edith's finding): the origin's name half matches
        # a name this repo has since retired, and the manifest's slug is this repo's own current one --
        # that is consistent with a transfer redirect, not confirmed as one, since this run makes no
        # network call (arm 3 below carries the identical caution for the general case).
        #
        # THE REMEDY COMMAND IS ITSELF GUARDED (Sebastian's finding, #1821): $ThisRepoSlug is what gets
        # composed into the printed 'git remote set-url' command, so it is held to GitHub's own shape
        # via Test-GitHubOwnerNameSlug before that command is offered, exactly as Get-RemoteConsumerWorkflow
        # already holds a manifest 'repo' field before it becomes a URL.
        $thisSlugCheck = Test-GitHubOwnerNameSlug -Slug $ThisRepoSlug
        if ($thisSlugCheck.Ok) {
            Write-Skip "this checkout's origin ('$(Format-SafePathToken -Value $originRepo)') differs from the manifest's own current name ('$(Format-SafePathToken -Value $manifestRepo)') only in a way this repo's own rename history explains -- consistent with a transfer redirect rather than confirmed as one, since this run makes no network call. 'git -C <this checkout> remote set-url origin https://github.com/$(Format-SafePathToken -Value $ThisRepoSlug).git' ends it either way."
        } else {
            Write-Skip "this checkout's origin ('$(Format-SafePathToken -Value $originRepo)') differs from the manifest's own current name ('$(Format-SafePathToken -Value $manifestRepo)') only in a way this repo's own rename history explains -- consistent with a transfer redirect rather than confirmed as one, since this run makes no network call. No remedy command is printed here: this repo's own currently configured slug ('$(Format-SafePathToken -Value $ThisRepoSlug)') is $($thisSlugCheck.Reason) -- correct scripts/repo-config.ps1's Get-RepoName instead."
        }
    } else {
        # ARM 3 -- A GENUINE MISMATCH, OR ONE THIS RUN CANNOT TELL APART FROM ONE. This run makes no
        # network call (that is what -RemoteRunners is for, and this is not that path), so it cannot
        # distinguish 'a different repository' from 'an old spelling still answering a transfer
        # redirect'. So it asserts only what was measured -- the origin names one slug, the record
        # names another -- and withholds every verdict below rather than print any of them against a
        # repository that was never actually read. [ERROR] rather than [INFO], on the same precedent
        # check 4 already sets: a machine that simply has nothing is [INFO] ('machine-specific, not a
        # gate breach'), while the register asserting one thing and the machine answering another is
        # an [ERROR] -- and the session hook surfaces [ERROR] and suppresses [INFO]/[SKIP], so this is
        # the line that replaces the five wrong ones this issue was filed over.
        #
        # THE REMEDY COMMAND IS ITSELF GUARDED (Sebastian's finding, #1821): $manifestRepo is manifest
        # content from a public repo, and it is what gets composed into the printed 'git remote
        # set-url' command -- so it is held to GitHub's own shape via Test-GitHubOwnerNameSlug before
        # that command is offered, exactly as Get-RemoteConsumerWorkflow already holds this same field
        # before it becomes a URL for the API. Where it does not hold that shape, the command is
        # dropped rather than printed built from it -- the finding still fires (nothing about it was
        # checked, either way), it just says the register's value is not a well-formed slug, which is
        # itself worth knowing.
        $manifestSlugCheck = Test-GitHubOwnerNameSlug -Slug $manifestRepo
        $mismatchRemedy = if ($manifestSlugCheck.Ok) {
            "Either this checkout is a clone of a different repository (repoint it: git -C <checkout> remote set-url origin https://github.com/$(Format-SafePathToken -Value $manifestRepo).git), or this record's localCheckout points at the wrong folder on this machine (correct connectors/$($mf.Name))."
        } else {
            "No ready-to-run repoint command is printed here: $($mf.Name)'s own 'repo' value is $($manifestSlugCheck.Reason). Correct connectors/$($mf.Name), or repoint this checkout's origin yourself if that is the side that is wrong."
        }
        Write-Failure "this checkout's 'origin' is '$(Format-SafePathToken -Value $originRepo)', but $($mf.Name) names '$(Format-SafePathToken -Value $manifestRepo)' -- nothing about '$(Format-SafePathToken -Value $manifestRepo)' was checked. This could be a different repository, or an old spelling still answering a transfer redirect; this run does not call GitHub to tell the two apart. $mismatchRemedy"
        continue
    }

    # Read the consumer's enable state once, from the whole settings chain rather than settings.json
    # alone (inbound #294 -- Get-EnabledPlugins carries the measurement and the reasoning). This check
    # produced the mirror-image symptom of the roster check's false green: a flat
    # "is NOT (or no longer) enabled" for DaveKJohn/life-hub in the very session that had loaded four of
    # its skills and all three of its hooks, because the enable sat in settings.local.json. Literally
    # true about settings.json, false about the session -- and a gate that cries wolf about a working
    # setup is a gate whose next real finding gets waved away.
    #
    # The user layer legitimately counts here too: it belongs to the machine and the user running this
    # check, which is the same machine and user the consumer checkout is used from.
    $consumerEnabled = Get-EnabledPlugins -RepoRoot $checkout -UserHomeOverride $UserHomeOverride

    # The install administration for this checkout, read once per connector (inbound #302). Deliberately
    # WITHOUT -UserHomeOverride: that parameter is documented as pinning the user layer of the SETTINGS
    # CHAIN, and this is a different file answering a different question -- the version test controls it
    # by redirecting $env:USERPROFILE for the child process, which is where Get-InstallRecord reads it.
    #
    # Behind the -SkipVersions guard, because everything that reads it is: the administration is the
    # authority for check 4 and nothing else here. Reading it anyway would widen what a -SkipVersions run
    # does -- and could newly report an unparseable administration in a run that was explicitly asked not
    # to look at versions at all. Once per connector rather than once per plugin, so a consumer with
    # several plugin blocks still reads the file once.
    $consumerInstalled = $null
    if (-not $SkipVersions) {
        $consumerInstalled = Get-InstallRecord -RepoRoot $checkout
        if ($consumerInstalled.Exists -and -not $consumerInstalled.Readable) {
            Write-Failure "$($consumerInstalled.Path) does not parse as JSON ($($consumerInstalled.Error)) -- no install record could be read for this consumer, so every version verdict below is withheld."
        }
    }

    if (-not $consumerEnabled.AnyFileExists) {
        Write-Failure "no settings file found for '$checkout' (looked for $(($consumerEnabled.Layers | ForEach-Object { $_.Label }) -join ', '))"
    }
    foreach ($badLayer in @($consumerEnabled.Unreadable)) {
        Write-Failure "$badLayer does not parse as JSON in '$checkout' -- its enabledPlugins entries were not read."
    }

    # Every id THIS manifest already lists, collected as the loop below visits each one anyway (#1775 /
    # Victor's finding 3) -- check 5, after the loop, needs exactly this set to tell an unlisted id from a
    # listed one, and the loop already touches every $p.id once, so a second walk over $m.plugins purely
    # to rebuild it would re-read data already in hand for no reason beyond the check living further down
    # the file. Ordinal, for the same reason every id comparison in this file is: an id is a comparison
    # key, not prose (Get-PluginRootByName's own reasoning).
    $listedPluginIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

    foreach ($p in @($m.plugins)) {
        # The DISPLAY form of this manifest's plugin id (inbound #309), bound once per block for the same
        # reason check-roster-sync binds $plugIdShown: $p.id stays raw because Get-PluginDir derives a path
        # from it and the enable/record lookups key on it, while every printed line uses this. Manifest
        # fields are lower-risk than settings keys -- they live in this repo and pass a PR -- but the
        # guardrail note at the top of this file already says manifest values are never blindly trusted,
        # and 'never blindly trusted' had a hole in it for display.
        $pluginIdShown = Format-SafeToken -Value ([string]$p.id)
        Write-Host "  -- plugin: $pluginIdShown" -ForegroundColor Cyan
        if ($p.PSObject.Properties.Name -contains 'id' -and $p.id) { [void]$listedPluginIds.Add([string]$p.id) }

        # Narrow the label to this plugin block. A consumer can register SEVERAL plugins, and a shared
        # cause (one outdated install) then produces one finding per plugin -- word-for-word identical
        # once the '-- plugin:' header above is filtered out of the session summary. Verified against
        # this repo's own register: smartwatchbanden has two plugin blocks, both behind, and the hook
        # surfaced two indistinguishable [ERROR] lines. Connector name alone was not enough (inbound
        # #203); the plugin id is what makes each line actionable.
        Set-CheckScope "$connectorLabel / $($p.id)"

        $resolved = Get-PluginDir $p.id
        $pluginDir = $resolved.Dir
        if ($null -eq $pluginDir) {
            $shown = Format-SuspectToken -Value ([string]$p.id)
            switch ($resolved.Status) {
                'retired' {
                    # NOT A FAULT, and an [INFO] rather than an [ERROR] for the reason this register
                    # exists: it records what a consumer HAS. A plugin renamed upstream leaves every
                    # consumer holding the old id until they migrate, and writing the new one here
                    # early would report a migration that has not happened as done. The same
                    # [INFO]-silence rule the other administrative markers follow applies -- the
                    # session hook surfaces only [ERROR], so this shows on a deliberate run and does
                    # not interrupt anybody's session start over somebody else's repo.
                    #
                    # WHAT IS SKIPPED IS NAMED BY WHAT IT NEEDS, not as "everything below" (#1802).
                    # The extension inventory and the version comparison both read the plugin's SOURCE
                    # FOLDER, which a retired name no longer has -- so those genuinely cannot run. The
                    # install-record question needs no source folder at all: it asks whether this
                    # machine holds a record for that projectPath, and the answer is as available for a
                    # retired id as for a current one. It is answered below.
                    Write-Info "$shown is not a plugin this marketplace declares any more -- this consumer has not migrated to the current names yet. Correct as it stands for the REGISTER: it records what they HAVE, so it changes when they do. The extension inventory and the version comparison need this plugin's source folder, which a retired name has none of, so both are skipped for it."

                    # AND THE ONE QUESTION THAT SURVIVES THE RETIREMENT IS ASKED HERE (#1802), because
                    # this 'continue' is what hid the worst state this check can see. Until now a retired
                    # id skipped the whole plugin block, check 4 among it -- and check 4 holds the only
                    # sentence in the tree that says a checkout LOADS NONE OF IT. So the two consumers
                    # #1802 measured as worst, both of them enabling nothing but retired ids, were the two
                    # this check could say least about: every one of their plugin blocks left here, and the
                    # register reported them as "correct as it stands".
                    #
                    # THE WAY OUT IS NOT check 4's COMMAND, which is why this is not a copy of it.
                    # 'claude plugin install <retired id>' cannot repair this: install resolves the id
                    # against the marketplace catalogue, and the catalogue is precisely what no longer
                    # declares that name. So the record finding here hands over the MIGRATION instead --
                    # re-enable under the current name, then install that -- and says why the obvious
                    # command is the wrong one, since a reader who has just been told a plugin is not
                    # installed will otherwise reach for it and be told nothing useful by the failure.
                    #
                    # [INFO] for a walked connector, on the standing other-machine rule (Dave, July 20,
                    # 2026): a consumer used from another machine has no record here either, so the state
                    # is not conclusive from this vantage point. Promoted to the non-counting
                    # [NOT-INSTALLED-HERE] only for the repo the session is actually in, where that second
                    # reading does not exist -- the same scoping, and the same marker, check 4 uses for the
                    # same fact about a current id.
                    # The null check is explicit rather than left to -and's short-circuit: under
                    # -SkipVersions $consumerInstalled is $null by design, and a reader of this condition
                    # should not have to derive that the operator order is what keeps it safe.
                    if (-not $SkipVersions -and $null -ne $consumerInstalled -and $consumerInstalled.Exists -and $consumerInstalled.Readable -and ($consumerEnabled.Ids -contains $p.id)) {
                        $retiredRecords = @()
                        if ($consumerInstalled.RecordsById.ContainsKey($p.id)) { $retiredRecords = @($consumerInstalled.RecordsById[$p.id]) }
                        if ($retiredRecords.Count -eq 0) {
                            Write-Info "and there is no machine record for it either, while it IS enabled in $($consumerEnabled.LayerById[$p.id]) -- so a session in that checkout loads none of this plugin (no skills, no subagents, no hooks), and that repo cannot report it, because the hook that would is inside the plugin that is not loading. 'claude plugin install $shown --scope project' will NOT fix it: the marketplace no longer declares that id. The way out is the migration -- enable the plugin under its current name, then install that (see INSTALL.md)."
                            if (Test-IsSessionRepo $checkout) {
                                Write-Host "  [NOT-INSTALLED-HERE] '$shown' is enabled in $($consumerEnabled.LayerById[$p.id]) but is BOTH a retired plugin name and without an install record for this checkout -- a session here loads none of it (no skills, no subagents, no hooks), and cannot say so itself. Re-installing under this id is not the fix: the marketplace no longer declares it. Migrate the enable to the plugin's current name and install that (see INSTALL.md)." -ForegroundColor Yellow
                            }
                        }
                    }
                }
                'no-source' {
                    Write-Failure "$shown is declared by the marketplace but its source folder is missing from this checkout -- plugin block skipped. That is a defect in this repo, not in the consumer."
                }
                default {
                    Write-Failure "invalid or unknown plugin field '$shown' in $($mf.Name) -- plugin block skipped."
                }
            }
            continue
        }

        # 2. Plugin enabled in the consumer? Both verdicts name the LAYER, so an enable arriving from
        # outside .claude/settings.json is diagnosable instead of mysterious -- and so the negative
        # verdict states what it actually checked rather than a single path it happened to look at.
        if ($consumerEnabled.AnyFileExists) {
            if ($consumerEnabled.Ids -contains $p.id) {
                Write-Ok "plugin is enabled in $($consumerEnabled.LayerById[$p.id])"
            } else {
                Write-Failure "plugin '$pluginIdShown' is NOT (or no longer) enabled in $($consumerEnabled.Summary)"
            }
        }

        # 3. Registered extensions present? + unregistered extensions of this plugin.
        # Lenses can live on the canonical plugin path (.claude/plugins/<family>/<plugin>/, since
        # life-hub parity), on a non-canonical family segment a pre-#179 bootstrap left behind, or on
        # the legacy path (.claude/extensions/). All count; Get-LensDirCandidates is the shared source
        # for that list (issue #179), fed the already-validated plugin id (see Get-PluginDir).
        $extDirs = @(@(Get-LensDirCandidates -RepoRoot $checkout -PluginName $p.id.Split('@')[0]) |
            Where-Object { Test-Path -LiteralPath $_ })

        $missing = @()
        foreach ($id in $p.extensions) {
            $hit = $false
            foreach ($dir in $extDirs) {
                if (Test-Path -LiteralPath (Join-Path $dir "$id-extension.md")) { $hit = $true; break }
            }
            if (-not $hit) { $missing += $id }
        }
        if ($missing.Count -gt 0) { Write-Failure ("registered extension(s) missing: " + ($missing -join ', ')) }
        else                      { Write-Ok  "all $(@($p.extensions).Count) registered extensions present" }

        $ownedIds = Get-PluginIds $pluginDir
        $present = @()
        foreach ($dir in $extDirs) {
            $present += Get-ChildItem -LiteralPath $dir -Filter '*-extension.md' -File |
                ForEach-Object { $_.BaseName -replace '-extension$', '' }
        }
        $unregistered = @($present | Sort-Object -Unique | Where-Object { ($ownedIds -contains $_) -and ($p.extensions -notcontains $_) })
        foreach ($id in $unregistered) {
            Write-Info "extension '$id' exists in the consumer but is not in the register -- update the register or review the change."
        }

        # Non-counting marker the session hook DOES surface -- but only when the drifted register is
        # the one describing the repo this session is actually in, which is the only case a reader
        # here can act on. Third instance of the [UNREGISTERED]/[ORPHANS] shape, and for the same
        # reason: the [INFO] above stays (it counts, and a deliberate run should list every id),
        # while this line carries the actionable text for a session start.
        #
        # Why it was needed (2026-07-29): a deliberate run found eleven of these at once, six of them
        # in the register of THIS repo -- the lenses had landed with the adopt-the-six change (PR #212)
        # and the inventory was never updated alongside. Nothing had surfaced it, because the finding
        # is an [INFO] and the hook shows only [ERROR] lines. The connectors README already carried an
        # "after a refresh, also update the manifest" rule; it was not enough, precisely because it
        # reads as a follow-up step and nothing reported the omission.
        #
        # Deliberately NOT promoted for every connector: that would reintroduce exactly the
        # other-machine noise the [INFO]-silence rule removed (Dave, July 20, 2026). Scoped this way
        # the rule's justification -- "often the business of another machine or user" -- simply does
        # not apply: this register is in the repo the reader has open. Decision by Dave, July 29, 2026.
        if ($unregistered.Count -gt 0 -and (Test-IsSessionRepo $checkout)) {
            Write-Host "  [INVENTORY] this repo has $($unregistered.Count) lens(es) that its own entry in the connector register does not list ($($unregistered -join ', ')) -- add them to the 'extensions' array in $($mf.Name), in the same change that landed the lens. Nothing is broken: the register's view of this repo is simply behind reality." -ForegroundColor Yellow
        }

        # 4. Machine record vs. source.
        #
        # The record read here is now Get-InstallRecord's (inbound #302). This block used to hold the
        # ONLY reader of installed_plugins.json anywhere in these scripts -- which is why #302's grep for
        # it over the plugin tree found prose only, and concluded no code read it: true of the plugin
        # tree, and this file is workshop-owned. Its matching rules did not change; they moved, so the
        # roster check and the bootstrap can ask the same question rather than each growing a reader of
        # their own. The rules themselves, preserved verbatim in the lib:
        #
        # EVERY matching record, not the first one (#240). The old loop stopped at the first hit -- an
        # arbitrary pick dressed up as a fact. Measured on Dave's machine (2026-07-29): `claude plugin
        # list` showed `specialists` three times for one repo (2.13.1, 2.11.0, 2.9.0), because the
        # administration holds several project records for that checkout, in two path spellings. The
        # [OK]/[ERROR] the session hook prints every single start therefore rested on whichever record
        # happened to come first in the JSON. Same defect family as #227, #235 and the teardown's
        # docstring-VUL-IN: evidence that looks conclusive while being satisfied by something other than
        # what it claims to measure. This one did not lie about a string -- it lied about WHICH of several
        # answers it had found. An honest "I cannot tell" is worth more than a confident wrong number,
        # and unlike the wrong number it is actionable.
        #
        # Read once per connector, outside the plugin loop, and asked per plugin id here.
        if (-not $SkipVersions) {
            $pluginJsonPath = Join-Path $pluginDir '.claude-plugin\plugin.json'
            $sourceVersion = (Get-Content -LiteralPath $pluginJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json).version
            # Readable, not merely present. An administration that exists but does not parse yields an
            # EMPTY record set, and running the branches below on that would report "no machine record for
            # this consumer" -- a statement about absence, drawn from a file that could not be read. That is
            # the exact species of claim inbound #302 is about, so the unreadable case gets no verdict at
            # all here; the [ERROR] at connector level already named the file and said the verdicts are
            # withheld.
            if ($consumerInstalled.Exists -and $consumerInstalled.Readable) {
                $recordMatches = @()
                if ($consumerInstalled.RecordsById.ContainsKey($p.id)) { $recordMatches = @($consumerInstalled.RecordsById[$p.id]) }
                $recordVersions = @($recordMatches | ForEach-Object { $_.Version } | Sort-Object -Unique)
                if ($recordMatches.Count -eq 0) {
                    # Sharpened for the case that actually bites (inbound #302). "No record" was worded
                    # purely as a version check that could not run, which is right when the plugin is not
                    # enabled there either. When it IS enabled, the same fact means something much
                    # louder: a session in that checkout loads none of this plugin, while both this
                    # register and that repo's own settings say it is present. And that repo cannot
                    # report it -- the hook that would is inside the plugin that is not loading. This
                    # check, from the workshop, is the one vantage point that still has a voice.
                    #
                    # [INFO], not [ERROR], and deliberately so: a consumer legitimately used from
                    # another machine has no record here either, so the state is not conclusive. The
                    # honest move is to name both readings and the one command that settles it.
                    if ($consumerEnabled.Ids -contains $p.id) {
                        Write-Info "no machine record for this consumer, while the plugin IS enabled in $($consumerEnabled.LayerById[$p.id]) -- a session in that checkout loads none of this plugin (no skills, no subagents, no hooks). Either the install belongs to another machine, or it was never made for this path (or was taken over -- see inbound #301): 'claude plugin install $pluginIdShown --scope project' from that root settles it. Version check skipped."

                        # ...and for the repo the session is actually in, the [INFO] above is not enough
                        # (#533). The reasoning that keeps it an [INFO] is 'the install may belong to
                        # another machine' -- a real second reading for a consumer this check is merely
                        # walking, and NOT a possible one here: this session is running in that checkout
                        # right now, so a missing record means a missing install, full stop.
                        #
                        # Fourth instance of the [UNREGISTERED]/[INVENTORY]/[ORPHANS] shape, and scoped the
                        # same way for the same reason: promoting it for EVERY connector would reintroduce
                        # exactly the other-machine noise the [INFO]-silence rule removed (Dave, July 20,
                        # 2026). Non-counting, so it never turns an exit-0 run into a failure -- nothing is
                        # broken about the source, only about what this machine has of it.
                        #
                        # Why it was needed (2026-08-09, #533): a mid-session `git pull` moved this repo
                        # across the plugin rename. settings.json, the register and the plugin tree all went
                        # to the new names in one fast-forward while installed_plugins.json kept the old
                        # record, leaving BOTH enabled plugins with no install record -- a session here
                        # loading none of its own specialist surface. Every artefact that could have said so
                        # had already run, at a moment when it was not yet true, and the one line about
                        # plugins in the session context reported a version gap on a plugin that was no
                        # longer enabled. The marker roster-sync has for this state is unreachable here by
                        # design (a session start writes the record before any hook can look), and this
                        # [INFO] was suppressed -- so between the two of them, nothing had a voice.
                        if (Test-IsSessionRepo $checkout) {
                            Write-Host "  [NOT-INSTALLED-HERE] '$pluginIdShown' is enabled in $($consumerEnabled.LayerById[$p.id]) but has no install record for this checkout -- a session here loads none of it (no skills, no subagents, no hooks). Fix: 'claude plugin install $pluginIdShown --scope project' from this root. Nothing is wrong with the source; this machine simply does not have the plugin." -ForegroundColor Yellow
                        }
                    } else {
                        Write-Info "no machine record for this consumer (the install may run via a different machine)."
                    }
                } elseif ($recordVersions.Count -gt 1) {
                    # Deliberately a failure, not an INFO: as long as the records disagree, every other
                    # version statement about this consumer is unreliable, and that is exactly what the
                    # reader must not take on trust.
                    Write-Failure "$($recordMatches.Count) machine records for this consumer disagree (v$($recordVersions -join ', v')) -- cannot determine which version is running here, so the source comparison (v$sourceVersion) is withheld. Clean up the duplicate project records for this checkout, then re-run."
                } elseif ($recordVersions[0] -eq $sourceVersion) {
                    Write-Ok "machine record is on the source version (v$sourceVersion)"
                } else {
                    Write-Failure "machine record is on v$($recordVersions[0]), source on v$sourceVersion -- update the plugin from the consumer (scope lesson)."
                }
            } elseif (-not $consumerInstalled.Exists) {
                Write-Info "no plugin administration found on this machine -- version check skipped."
            }
            # No else: an unreadable administration was already reported as an [ERROR] at connector level,
            # and repeating it per plugin would say the same thing N times (the noise the per-plugin scope
            # label was introduced to make actionable, not to multiply).
        }
    }

    # Back to connector level: anything reported from here on belongs to the connector as a whole, not
    # to whichever plugin block the loop above happened to end on.
    Set-CheckScope $connectorLabel

    # 5. Per plugin: enabled in the consumer's settings chain, but never named in THIS manifest's
    # 'plugins' list at all -- so the foreach above never looped over it, and NOTHING was printed about
    # it: not [ERROR], not [INFO], not [SKIP] (#1775). This sits deliberately outside and after that
    # loop, because its subject is exactly what the loop cannot see: an id it was never handed.
    #
    # MEASURED (this branch, before this change): this repo's own connectors/claude-code-specialists.json
    # lists two plugin blocks ('dkj-team-alpha@...', a name the marketplace no longer declares, and
    # 'dkj-policy@...'), while .claude/settings.json enables six ids. Running the unmodified script
    # against that manifest prints exactly one line about the whole six: '[OK] plugin is enabled' for
    # dkj-policy@, the one id that happens to appear, verbatim, in the manifest's own list. The other
    # five -- dkj-subagents-alpha@, dkj-subagents-ecomm@, dkj-subagents-lifehub@, dkj-subagents-shopify@
    # and dkj-policy-bwj@ -- produce no line whatsoever from the loop above; #1775 describes four of
    # those five as 'completely silent' and folds the fifth (dkj-subagents-alpha@) into 'one printed an
    # [INFO] because it carries a retired id', on the reading that the manifest's 'dkj-team-alpha@' entry
    # is that plugin's old name. That reading is about the underlying PLUGIN; this check compares ID
    # STRINGS, and 'dkj-team-alpha@dkj-claude-plugins' is not
    # 'dkj-subagents-alpha@dkj-claude-plugins' -- so, run today, this check reports dkj-subagents-alpha@
    # as unlisted too, a fifth finding rather than folding into the retired-name one. That is not a
    # contradiction of #1775's count, only a sharper reading of the same five ids: every one of them was
    # unchecked, and this block is what makes each of the five say so on its own.
    #
    # SCOPE: only an id whose MARKETPLACE segment (the text after the last '@') names THIS repo's OWN
    # marketplace ($ThisMarketplaceName, read once near the top of this file) is this register's
    # business. This register exists to record what a consumer HAS of the plugins THIS repo publishes;
    # an id enabling a plugin from an unrelated third-party marketplace is not something this repo's
    # register was ever meant to track, and reporting on it here would be commenting on somebody else's
    # catalogue from a register that has no way to judge it. An id with no '@' at all is left alone for
    # the same reason -- it cannot even be attributed to a marketplace, so there is nothing to compare.
    #
    # A RETIRED id -- a name THIS marketplace no longer declares, but still carrying THIS marketplace's
    # own segment -- still counts here, deliberately. The per-plugin loop above already treats that state
    # as something the register should record (an [INFO] under the 'retired' branch, not silence), and
    # this predicate has to agree with that rather than quietly re-excluding by segment what the loop
    # above already includes by name.
    #
    # Matching is ORDINAL throughout (Get-PluginRootByName's own reasoning, restated for an id rather than
    # a plugin name): an id is a comparison key, not prose, and PowerShell's default '-eq'/'-contains'
    # collate culture-sensitively -- exactly the trap Test-TokenChanged in check-report-lib.ps1 was
    # written to avoid for the sibling case.
    if ($consumerEnabled.AnyFileExists -and $ThisMarketplaceName) {
        # $consumerEnabled.Ids is already ordinally sorted and de-duplicated (Get-EnabledPlugins builds it
        # from hashtable keys), so filtering it in place needs no re-sort -- the result stays in that
        # order, exactly as the [INVENTORY] block above relies on for $unregistered. $listedPluginIds was
        # built above, inside the per-plugin loop, rather than by re-walking $m.plugins here a second time.
        $unlistedPlugins = @(
            foreach ($id in @($consumerEnabled.Ids)) {
                $at = $id.LastIndexOf('@')
                # $at -eq -1: no '@' at all -- cannot be attributed to any marketplace, nothing to compare.
                # $at -eq  0: '@' is the FIRST character, so the id carries an attributable marketplace
                #             segment (everything after it) but an EMPTY plugin-name segment before it --
                #             not a real plugin id at all (Test-PluginNameSlug rejects exactly this shape
                #             elsewhere in this file as malformed). Both are excluded here, and for the
                #             SAME underlying reason, not by coincidence of one comparison: what this
                #             check tells a reader to do is 'add a plugins[] block for THIS id', and there
                #             is no id to add a block for when nothing before the '@' names a plugin.
                #             Reporting it as 'unlisted' would be actionable advice about a plugin that
                #             does not exist. Covered by connectors.tests.ps1 scenario 11h.
                if ($at -le 0) { continue }
                if (-not [string]::Equals($id.Substring($at + 1), $ThisMarketplaceName, [System.StringComparison]::Ordinal)) { continue }
                if ($listedPluginIds.Contains($id)) { continue }
                $id
            }
        )
        foreach ($id in $unlistedPlugins) {
            # Counting [INFO], on the same terms as the neighbouring [INVENTORY] finding one level down
            # (an extension present but not registered): a deliberate run always lists it, and the
            # [INFO]-silence rule (Dave, July 20, 2026) keeps it out of an ordinary session start.
            # $id is an 'enabledPlugins' KEY NAME out of a consumer's settings file, i.e. untrusted JSON
            # content (inbound #309/#302's own reasoning) -- Format-SafeToken, not Format-SuspectToken:
            # the id itself is not the complaint (it may well be a perfectly valid, correctly spelled
            # id), only its absence from this manifest is.
            Write-Info "plugin '$(Format-SafeToken -Value $id)' is enabled in $($consumerEnabled.LayerById[$id]) but this manifest's 'plugins' list does not name it -- it was never looped over above, so nothing about it was checked here (no extension check, no version check). Add a plugins[] block for it to $($mf.Name), in the same change that enabled it, or remove the enable if that was not intended."
        }

        # Non-counting marker the session hook surfaces -- but only when the drifted register is the one
        # describing the repo this session is actually in, same carve-out and same reason as
        # [INVENTORY]/[NOT-INSTALLED-HERE]/[UNREGISTERED] above: promoting it for every connector would
        # reintroduce exactly the other-machine noise the [INFO]-silence rule removed (Dave, July 20,
        # 2026), for a register that in every OTHER case is legitimately somebody else's business to fix.
        #
        # A NEW TOKEN, DELIBERATELY NOT A REUSE OF [INVENTORY]. That marker already has a subject: an
        # EXTENSION present in the consumer that a plugin block IN the register does not list -- one
        # level further IN, inside a block the loop above did reach. This finding is one level further
        # OUT: a whole PLUGIN block the loop never reached at all, because no id in the manifest named
        # it. Reusing one token for both would make two different subjects indistinguishable in the
        # hook's summary, which is precisely what a dedicated token exists to prevent (the same
        # discipline [NOT-INSTALLED-HERE] and [ORPHANS] already follow beside [INVENTORY]).
        # [UNLISTED] was chosen over [UNREGISTERED] (already this register's word for "the whole
        # CONNECTOR has no manifest at all") and over inventing a compound like [PLUGIN-INVENTORY] (which
        # would visually read as a variant of [INVENTORY] while meaning something else): it says exactly
        # what happened -- present in the consumer, absent from the list -- and collides with nothing
        # else this file or connector-sessioncheck.ps1 already prints.
        if ($unlistedPlugins.Count -gt 0 -and (Test-IsSessionRepo $checkout)) {
            $shownIds = @($unlistedPlugins | ForEach-Object { Format-SafeToken -Value $_ })
            Write-Host "  [UNLISTED] this repo has $($unlistedPlugins.Count) plugin(s) enabled that its own entry in the connector register does not list ($($shownIds -join ', ')) -- add a plugins[] block for each to $($mf.Name), in the same change that enabled it. Nothing is broken: the register's view of this repo is simply behind reality." -ForegroundColor Yellow
        }
    }

    # --- 6. Do this consumer's CI runners still name paths that exist here? (#1805) ----------------
    # THREE RUNNERS THIS WORKFLOW SCAFFOLDS reach their script by checking THIS repository out beside
    # the consumer's tree and running a path into it -- branch-entry.yml, fold-on-merge.yml and
    # verify-resolved.yml. The dependency therefore points the wrong way: a path INTO this tree,
    # written into a file this tree cannot reach, by a scaffolder that runs once at adoption and never
    # again. When plugins/workflows/contributing-davekjohn/ became plugins/dkj-policy/, every consumer
    # scaffolded before the move kept naming the old path, and two of them were red on every pull
    # request without anyone noticing -- because neither had opened one since.
    #
    # THIS IS THE HALF THAT REACHES AN ALREADY-ADOPTED CONSUMER. Repairing the scaffolder cannot: it
    # writes once, and their file is already written. The register is the only thing here that looks at
    # what a consumer actually HAS, which is why the detector lives at this end and not in the thing
    # that produced the path.
    #
    # [ERROR], not [INFO], and the [INFO]-silence rule (Dave, July 20, 2026) is exactly why. That rule
    # is justified as "often the business of another machine or user"; this is neither optional nor
    # anybody's deliberate choice -- the consumer's required check is red on every pull request, and
    # they have no way of learning it from their side, since the break announces itself only when
    # somebody opens one. Same reasoning check 2 already stands on: a consumer-side breach this
    # register can see is reported as a breach, and connector-sessioncheck surfaces it with the
    # connector named (inbound #203).
    #
    # IT READS THE LOCAL CHECKOUT, so it inherits check 1: an absent consumer is [SKIP] and its
    # runners are not read at all. That is the register's standing behaviour and right for every other
    # check here, and it landed awkwardly on this one -- the consumers most likely to carry a stale path
    # are the ones nobody visits, which are the ones least likely to be checked out on the machine you
    # run this from. Measured on the branch that built this: of six connectors, three were [SKIP] here,
    # including both of the two #1805 reported as red, so on that machine this check would not have
    # found the case that produced it.
    #
    # THAT GAP IS NOW CLOSED FROM THE OTHER END, ON REQUEST (#1808): -RemoteRunners reads an absent
    # consumer's runners over the API and judges them with the same function this block calls, up at
    # the [SKIP] where the loop turns back. It stays OPT-IN and the two reasons it was not simply
    # switched on are unchanged: a gh call per connector does not belong on the SessionStart path this
    # script runs from, and a private repository a credential cannot read needs a third verdict of its
    # own rather than falling into either of the two here. Both are honoured there -- do not widen
    # this block itself to the network.
    if ($ThisRepoName) {
        # The set is COLLECTED as it is judged, so check 6c below can ask its question about the whole
        # of .github/workflows without reading it twice. Each file is still judged one at a time by
        # exactly the call this block always made.
        $localWorkflows = @()
        $workflowDir = Join-Path $checkout '.github\workflows'
        if (Test-Path -LiteralPath $workflowDir -PathType Container) {
            foreach ($wf in @(Get-ChildItem -LiteralPath $workflowDir -File -ErrorAction SilentlyContinue |
                              Where-Object { $_.Extension -in @('.yml', '.yaml') } | Sort-Object Name)) {
                $wfText = [System.IO.File]::ReadAllText($wf.FullName)
                Write-RunnerPathFinding -WorkflowName $wf.Name -WorkflowText $wfText
                $localWorkflows += [pscustomobject]@{ Name = $wf.Name; Text = $wfText }
            }
        }

        # --- 6c. DOES THIS CONSUMER RUN ANY OF THESE RUNNERS AT ALL? (#1850) ----------------------
        # Check 6 above judges paths that ARE named, so a consumer naming none produces no finding and
        # reads exactly like a fully adopted one. THE SOURCE REPO IS NOT ASKED: it runs all three of
        # those scripts by local path, being the tree every consumer checks out, so it is the one
        # registered repo that can never produce a reference and an [INFO] about it would be false.
        if ($checkout -ne $RepoRoot) {
            Write-RunnerAdoptionFinding -Workflow $localWorkflows -ManifestName $mf.Name -ListedPluginId @($listedPluginIds)
        }
    }

    if (-not $checkedConsumers.ContainsKey($checkout)) { $checkedConsumers[$checkout] = $m.repo }
}

# Back to run-level findings: clear the per-connector label so the notice below is not attributed to
# whichever connector the loop happened to walk last.
Set-CheckScope

if ($OnlyConsumer -and $matched -eq 0) {
    Write-Info "not registered: no manifest for this consumer in the register."
    # Non-counting marker the session hook DOES surface. The [INFO] above is suppressed at session
    # start (Dave's July 20, 2026 decision), which for this particular signal produced the worst
    # possible outcome: a brand-new consumer was told "connector-sessioncheck: no errors." -- a
    # positive all-clear for a repo this workshop cannot see at all. Found 2026-07-28 on a third
    # consumer that had been running, and filing inbound issues, unregistered for days.
    #
    # The [INFO] deliberately stays (it counts, and a deliberate run should report it in the summary);
    # this line carries the ACTIONABLE text for the session. Same shape as [ORPHANS] in
    # check-roster-sync (inbound #204): a dedicated non-counting token rather than promoting the
    # finding to [ERROR], which would make the exit code 1 and put a red line in every session of a
    # repo somebody deliberately chose not to register.
    #
    # Note this is NOT a general relaxation of the [INFO]-silence rule. That rule was justified as
    # "often the business of another machine or user"; this signal is the opposite -- it is about THIS
    # repo and it is actionable HERE. The README's own classification rule points the same way: a
    # category that must not stay out of sight may not be filed as [INFO].
    # Phrased for a reader who has never heard of this workshop (Dave, July 28, 2026: assume a consumer
    # knows nothing about the source repo -- a colleague who merely installed the plugin must be served
    # by it, not put to work for it). The earlier wording said "add connectors/<repo>.json in the
    # workshop", which is homework in a repo that reader may not have, may not have access to, and has
    # no reason to know exists. Who benefits from registration is the plugin's maintainer; who was being
    # instructed was the consumer. So: state that nothing here is broken, and address the action to the
    # maintainer conditionally.
    Write-Host "  [UNREGISTERED] this repo is not in the plugin maintainer's connector register. Nothing here is affected -- the plugin works normally. It only means the maintainer has no view of this repo's plugin version and lens inventory. If you maintain the plugin source, add a connectors/<repo>.json manifest there; if you just use the plugin, no action is needed on your side." -ForegroundColor Yellow
}

# Content drift per unique consumer (agent defs = error, personas = informational).
if (-not $SkipDrift) {
    foreach ($checkout in $checkedConsumers.Keys) {
        if ($checkout -eq $RepoRoot) { continue }
        Write-Host "`n-- drift-check: $($checkedConsumers[$checkout])" -ForegroundColor Cyan
        Set-CheckScope $checkedConsumers[$checkout]
        & powershell -NoProfile -ExecutionPolicy Bypass -File $DriftLint -ConsumerPath $checkout -Quiet |
            Where-Object { $_ -match 'DRIFTED|IDENTICAL|summary|drift' } |
            ForEach-Object { Write-Host "  $_" }
        if ($LASTEXITCODE -ne 0) { Write-Failure "agent-def drift found -- see check-consumer-drift." }
    }
    Set-CheckScope
}

Write-CheckSummary
