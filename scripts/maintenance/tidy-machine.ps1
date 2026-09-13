<#
.SYNOPSIS
    One command for the clutter this workflow leaves on a machine: finished branches, stale lanes,
    abandoned work, expired backups, plugin records naming a checkout or a plugin name that is gone,
    and leftover fixture trees. It DELETES
    only what prune-merged.ps1 can already prove; everything else it classifies and hands over.

.DESCRIPTION
    WHY THIS EXISTS, MEASURED IN THE SOURCE REPO ON SEPTEMBER 10, 2026. Running prune-merged.ps1
    -DryRun -IncludeRemote there found 32 local branches beside the trunk: 27 provably merged, and 5
    kept. Not one of the five was live work. They were a 7-day-old pre-sync backup, three branches
    whose pull requests had been CLOSED unmerged (#1299, #1243, #1260), and one whose PR had merged
    with the local tip a commit past it (#1599). One of the three also held an entire second checkout
    of the repository -- a lane worktree for a PR closed eight days earlier.

    prune-merged keeps all five CORRECTLY. It proves one thing and it proves it well, and inventing a
    proof it does not have is the defect inbound #1191 measured. What was missing was a command that
    NAMES the rest, plus the four kinds of clutter that are not branches at all.

    SO THIS IS A CONDUCTOR, NOT A SECOND IMPLEMENTATION. Six of its twelve lanes are a call into a
    script that already exists and is already tested; only six carry new logic, and that logic is pure
    and lives in tidy-lib.ps1. Nothing here re-derives a merge proof, re-reads a worktree list by hand, or
    re-answers a question another script in this repo already answers -- which is the whole of Ravi's
    rule and the reason issue #81 exists.

    THE AUTHORITY SPLIT, DECIDED BY DAVE ON SEPTEMBER 10, 2026, IS THE DESIGN. Asked what this command
    may throw away on its own, he chose: only what is provably merged. So:

      DELETES  -- exactly one lane, and only by delegation: prune-merged.ps1, on its own two existing
                  proofs (an ancestor of the trunk, or a tip that is the head commit of a merged PR).
      REPORTS  -- everything else, each item with what was measured and the command that would act on
                  it, paste-ready.

    THAT IS THE -IncludeRemote DOCTRINE TURNED INWARD. prune-merged already refuses to delete a remote
    branch and hands over the line instead, on the reasoning that with deleteBranchOnMerge on, the only
    branches a delete could still reach are the ones whose loss is unrecoverable. An abandoned branch is
    in exactly that position from the other direction: its pull request is closed, so the remote copy is
    gone and the local one is the last. A closed PR is strong evidence that nobody wants the work; it is
    not evidence that nobody wants the commits.

    WHAT IT NEVER TOUCHES, AND EACH IS A DECISION:

      - NO REMOTE BRANCH, ever, with or without a switch. Same rule as prune-merged, same reason, and
        asserted structurally by this script's suite.
      - NO STASH IS EVER DROPPED. A stash is unrecoverable and invisible to every other guard here;
        an old one is reported with its age and its `git stash show` line, and that is all.
      - NO PULL REQUEST is opened, merged or closed, and no issue is touched.
      - NOTHING UNDER THE SCRATCH ROOT IS DELETED, and this one is a decision this repo had already
        taken before the lane was written. scripts/README.md, on #1668, says those trees are "left
        standing on purpose" and names a sweep by name pattern as the delete primitive New-ScratchPath
        exists to remove (#1659). An earlier draft of lane 10 offered exactly that behind a flag; it
        was removed rather than defended. The lane ATTRIBUTES instead -- which is the scarce thing that
        measurement actually found, since its first reading mistook 546 retained-on-purpose artefacts
        and 162 unrelated files for leaked fixtures.
      - NO WORKING TREE IS MOVED BY THIS SCRIPT. The one exception is inherited rather than performed:
        prune-merged's step 4c steps off a branch it has just proven merged, and only then. Everything
        this script does itself is a read.

    THE ORDER OF THE LANES IS LOAD-BEARING IN EXACTLY ONE PLACE, and it is worth stating because it
    looks cosmetic. Stale lanes are reported BEFORE prune-merged runs, because git refuses to delete a
    branch that is checked out in any worktree, and that refusal is raised before the merged/unmerged
    question is asked (measured on git 2.54.0.windows.1, issue #1760):

        error: cannot delete branch 'X' used by worktree at '<path>'

    So a lane holding a provably merged branch makes that branch unreapable until the lane goes. Report
    it first and the reader can clear it in the same sitting; report it afterwards and they get git's
    sentence about a worktree in the middle of a list of merge proofs. This script also says so
    explicitly when it finds that pair, rather than leaving the reader to notice.

    THE MACHINE HALF READS ~/.claude/plugins/installed_plugins.json, which is this workflow's only
    machine-wide register. It is per-checkout install records keyed on FOLDER PATH, which is what makes
    a moved or renamed checkout leave a record behind pointing at nothing (issue #1449) -- and it is
    already the file plugin-versions.ps1 reads, so nothing new is being trusted here. A record can go
    dead from the OTHER end too, its checkout alive and its PLUGIN NAME retired by a rename in the
    marketplace, and that is lane 11 (issue #1773): the same file, the same doctrine, the other half of
    one defect. It is deliberately
    not connectors/, which exists only in the source repo: this script has to work in a consumer.

    AND ONE LANE READS WHAT THAT REGISTER POINTS AT, WHICH IS NOT THE SAME ARTEFACT (issue #1812). A
    record's installPath names an extracted copy of the plugin under ~/.claude/plugins/cache/, and that
    copy -- not the marketplace clone -- is what a session loads: measured September 10, 2026, the
    running process holds a lease at <installPath>/.in_use/<pid> for the life of the session and the
    clone holds none. Lanes 8 and 11 judge the pointer; lane 12 judges what is on the other end of it,
    and it is the only lane whose subject the register does not itself enumerate.

    IT VISITS NO OTHER CHECKOUT. Dave's second answer on September 10, 2026 was "this checkout plus the
    machine-wide lanes" rather than "every checkout the machine knows about". A run that walked into
    other repositories would be reaching past the tree the session is standing in, and the blast radius
    of a bug in it would be repositories nobody had opened.

    Every git and gh call goes through the shared Invoke-NativeCapture (EAP=Continue -> run -> record
    $LASTEXITCODE), because git writes progress to stderr, which under EAP=Stop becomes a terminating
    NativeCommandError before the exit code can be judged (the #96/#97/#107 pitfall).

    Pure ASCII (repo convention for .ps1).

.PARAMETER DryRun
    Report everything and change nothing at all, including in the one lane that would otherwise act:
    it is passed straight through to prune-merged.ps1. Use it the first time on any machine.

.PARAMETER CheckoutOnly
    Run only the six per-checkout lanes and skip the six machine-wide ones.

.PARAMETER MachineOnly
    Run only the six machine-wide lanes. Useful when a checkout is mid-flight and you want the
    ~/.claude and scratch answers without anything reading the branch list.

.PARAMETER MaxAgeDays
    How old a `backup/*` branch or a stash must be before it is reported as expired. Default 14. It
    applies to NOTHING else: an age is not evidence about a branch somebody may simply not have got
    round to, and the only branch prefix in this workflow that declares itself temporary is `backup/`.

.PARAMETER MinFixtureAgeHours
    How old a scratch fixture tree must be before it counts as a leftover rather than as a suite that
    is still running. Default 24.

.PARAMETER Remote
    The remote prune-merged fetches and prunes. Default 'origin'.

.PARAMETER UserHomeOverride
    (Fixtures) pin the user home the machine-wide lanes read. A consumer never types this.

.PARAMETER ScratchRoot
    (Fixtures) pin the scratch root the fixture-tree lane walks. Defaults to this machine's TEMP.

.EXAMPLE
    ./scripts/maintenance/tidy-machine.ps1 -DryRun

.EXAMPLE
    ./scripts/maintenance/tidy-machine.ps1

.EXAMPLE
    ./scripts/maintenance/tidy-machine.ps1 -MachineOnly
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$CheckoutOnly,
    [switch]$MachineOnly,
    [int]$MaxAgeDays = 14,
    [double]$MinFixtureAgeHours = 24,
    [string]$Remote = 'origin',
    [string]$UserHomeOverride = '',
    [string]$ScratchRoot = ''
)

$ErrorActionPreference = 'Stop'

# THE SOURCE-REPO GUARD: refuses this script when it is a released copy running in the repo that
# maintains it. Guarded dot-source, so a tree without the lib behaves as before. Why: the lib's header.
$guardLib = Join-Path $PSScriptRoot '..\lib\source-repo-guard-lib.ps1'
if (Test-Path -LiteralPath $guardLib -PathType Leaf) { . $guardLib; Assert-OwnCopy -ScriptPath $PSCommandPath }

. (Join-Path $PSScriptRoot '..\lib\native-capture-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\merged-pr-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\worktree-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\ref-print-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\check-report-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\command-probe-lib.ps1')
# Lane 11 only, and for one function: Get-RepoPluginRoots, to read which plugins a MARKETPLACE CLONE
# still lists. It is the same reader the release cut and the lint gate use, so a clone's manifest is
# not parsed by hand here (#1773).
. (Join-Path $PSScriptRoot '..\lib\plugin-tree-lib.ps1')
. (Join-Path $PSScriptRoot '..\lib\tidy-lib.ps1')

# Repo root -- dual context: if a consumer runs the shared plugin mirror, CLAUDE_PROJECT_DIR supplies
# its repo root; in the source root (or outside a session) it falls back to the git root. This way the
# SAME file works in both locations, and the root copy and the plugin mirror stay byte-identical.
# JUDGED (#1917): Resolve-RepoRootOrFail is check-report-lib's refusing sibling of Resolve-CheckRoot
# -- same precedence, but it names git's exit code and stderr instead of dying on $null.Trim().
$repoRoot = Resolve-RepoRootOrFail -ScriptName 'tidy-machine.ps1'
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }

if ($CheckoutOnly -and $MachineOnly) {
    Write-Error "-CheckoutOnly and -MachineOnly are mutually exclusive -- pass neither to run both halves."
    exit 2
}
$runCheckout = -not $MachineOnly
$runMachine  = -not $CheckoutOnly

# The trunk name is the one thing that is repo-owned here, read the way every other script in this set
# reads it, with the same default.
$trunk = 'main'
$cfg = Join-Path $repoRoot 'scripts\repo-config.ps1'
if (Test-Path -LiteralPath $cfg -PathType Leaf) {
    try {
        . $cfg
        # Test-FunctionDefined, never Get-Command (issue #1729): Get-Command reads its argument as a
        # WILDCARD pattern, so a seam function whose name carried a bracket would be missed silently.
        if (Test-FunctionDefined 'Get-TrunkBranchName') { $trunk = Get-TrunkBranchName }
    } catch {
        Write-Warning "scripts\repo-config.ps1 could not be loaded -- assuming the trunk is '$trunk'. ($($_.Exception.Message))"
    }
}

function Invoke-Git {
    param([string[]]$Arguments)
    return (Invoke-NativeCapture -FilePath 'git' -Arguments $Arguments)
}

function Write-Lane {
    param([string]$Number, [string]$Title)
    Write-Host ''
    Write-Host "[$Number] $Title" -ForegroundColor Cyan
}

function Write-Item {
    param([string]$Text, [string]$Colour = 'Gray')
    Write-Host "  $Text" -ForegroundColor $Colour
}

function Write-Handover {
    param([string]$Command)
    if ($Command) { Write-Host "      $Command" -ForegroundColor Yellow }
}

function Write-RefHandover {
    <#
        A paste-ready command carrying a BRANCH NAME, put through the shared paste guard first. A ref
        name is not safe to interpolate into a printed command on trust: git enforces only the \p{Cc}
        half of the class, so a branch created by hand, cloned or fetched can carry a \p{Cf} run or a
        shell metacharacter straight into the line a reader is about to paste (#1594, #1617). When the
        name is refused the command still prints -- with a placeholder -- followed by the lib's own
        note, which names the real branch as inert prose so the reader can quote it themselves.
    #>
    param([string]$Prefix, [string]$Ref)
    $safe = Get-PasteableRef -Ref $Ref
    Write-Handover "$Prefix $($safe.Token)"
    if ($safe.Note) { Write-Item "    $($safe.Note)" 'DarkGray' }
}

function Write-PathHandover {
    <#
        The same guard for a command carrying a FILESYSTEM PATH. -Kind Path selects the pattern the
        value is judged against, the noun the refusal note speaks in, and the strip that renders it
        there; the placeholder says which hole to fill, since '<branch>' would be the wrong word for a
        worktree directory.

        THIS WENT THROUGH A SECOND MECHANISM FOR ONE DAY, AND THE ALLOWLIST WON (issue #1768). A
        literal-quote formatter lived in tidy-lib.ps1 -- Format-PasteablePathToken -- which wrapped the
        path in PowerShell single quotes instead of judging it, on the ground that it could then refuse
        nothing but a path that would REPAINT the line. Two things retired it.

        ITS PREMISE HAD ALREADY EXPIRED WHEN IT LANDED. It argued that Get-PasteableRef -Kind Path
        judges against the ref allowlist, so "NO absolute Windows path can pass it, ever" -- true of the
        pattern it was written against, and false eleven minutes later: #1765 gave the path axis its own
        $PathPasteSafePattern with ':' and a folded '\', and an ordinary lane path passes it. The noise
        that justified a second mechanism was gone before the second mechanism was read.

        AND ITS GUARANTEE IS ONE SHELL'S, WHILE THE TWO COMMANDS BELOW ARE NOT. The single-quoted
        literal is exact in PowerShell and in nothing else this workflow commits to. Measured,
        September 10, 2026: the token for C:\it's\here is 'C:\it''s\here', and bash reads a doubled
        quote as a CLOSE followed by an OPEN, so Git Bash resolves it to C:\its\here -- a different,
        plausible-looking path, silently, with no error to notice. In cmd, where single quotes are not
        quoting at all, any spaced path splits into two arguments. That matters here specifically
        because the two lines this function prints per lane are 'worktree-lane.ps1 -HandBack -Lane ...',
        which is PowerShell-only, and 'git worktree remove ...' directly beneath it, which is exactly
        the kind a reader pastes into Git Bash.

        SO A SPACE IS REFUSED RATHER THAN ADMITTED, AND THAT IS THE ANSWER, NOT A GAP. The token is
        printed UNQUOTED -- ref-print-lib's header is explicit that quoting is not the guard -- so a
        space admitted to the allowlist would produce 'git worktree remove C:/Program Files/x', which
        splits in every shell rather than one. The refusal prints the placeholder and a note naming the
        real path as inert prose, for the reader to quote for the shell they are actually in.
        ref-print-lib.tests.ps1 has asserted that verdict for 'C:\Program Files\a b\x' since #1762.
    #>
    param([string]$Prefix, [string]$Path, [string]$Suffix = '', [string]$Placeholder = '<that lane>')
    $safe = Get-PasteableRef -Ref $Path -Kind Path -Placeholder $Placeholder
    $tail = if ($Suffix) { " $Suffix" } else { '' }
    Write-Handover "$Prefix $($safe.Token)$tail"
    if ($safe.Note) { Write-Item "    $($safe.Note)" 'DarkGray' }
}

function Write-PluginHandover {
    <#
        A paste-ready `claude plugin uninstall <plugin>@<marketplace> --scope <scope>` for lane 11.

        THE TWO HALVES OF THE ID ARE JUDGED SEPARATELY, and that is the whole reason this helper exists.
        An install id is not a ref: `@` is in neither shared paste allowlist, so handing the whole id to
        Get-PasteableRef refuses every legitimate id there is. Each half IS a ref-shaped token, so each
        is judged on the ref axis and the `@` between them is this line's own literal -- which narrows
        nothing and widens nothing in a pattern two other guards depend on (#1594, #1617).

        THE SCOPE IS THE RECORD'S OWN, never a fixed `project`. `claude plugin uninstall ... --scope
        project` REFUSES to remove a record sitting at local -- "Plugin ... is installed in local scope,
        not project" (inbound #315) -- and a session start alone is enough to create a local record, or
        to flip a project one to local (inbound #314). So printing `project` at a local record would hand
        over the one command that cannot do the job. An unrecognised scope prints no flag at all and says
        so, rather than guessing on the reader's behalf.
    #>
    param(
        [string]$Prefix,
        [string]$Plugin,
        [string]$Marketplace,
        [AllowEmptyString()][string]$Scope = ''
    )
    $p = Get-PasteableRef -Ref $Plugin -Placeholder '<plugin>'
    $m = Get-PasteableRef -Ref $Marketplace -Placeholder '<marketplace>'
    $scopeOk = ($Scope -match '^(project|local|user)$')
    $tail = if ($scopeOk) { " --scope $Scope" } else { '' }
    Write-Handover "$Prefix $($p.Token)@$($m.Token)$tail"
    if ($p.Note) { Write-Item "    $($p.Note)" 'DarkGray' }
    if ($m.Note) { Write-Item "    $($m.Note)" 'DarkGray' }
    if (-not $scopeOk) {
        Write-Item "    The record carries no scope this run recognises, so no --scope flag is printed; supply the one the record is at (project, local or user)." 'DarkGray'
    }
}

$actedTotal = 0
$reportedTotal = 0

Write-Host "tidy-machine -- repo root: $repoRoot, trunk: '$trunk'." -ForegroundColor White
if ($DryRun) { Write-Host "-DryRun: nothing will be changed anywhere, in any lane." -ForegroundColor DarkGray }

# ===================================================================================================
# GATHER (per-checkout half). Everything the first six lanes classify is read once, here, so no lane
# pays for a second git call and no two lanes can disagree about what the clone holds.
# ===================================================================================================

$branchClasses = @()
$worktreeRecords = @()

if ($runCheckout) {
    $wtRes = Invoke-Git -Arguments @('worktree', 'list', '--porcelain')
    if ($wtRes.ExitCode -eq 0) {
        $worktreeRecords = Get-WorktreeRecords -PorcelainLines @(($wtRes.Output | Out-String) -split '\r?\n')
    } else {
        Write-Warning "could not list worktrees -- the stale-lane lane is skipped. ($(($wtRes.Output | Out-String).Trim()))"
    }

    # Name, tip and committer date in one pass. A second call per branch would be one round trip per
    # branch on a clone that routinely holds thirty of them.
    $refRes = Invoke-Git -Arguments @(
        'for-each-ref', '--format=%(refname:short)%09%(objectname)%09%(committerdate:unix)', 'refs/heads')
    $rows = @()
    if ($refRes.ExitCode -eq 0) {
        $rows = @(($refRes.Output | Out-String) -split '\r?\n' |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ } |
            ForEach-Object {
                $parts = $_ -split "`t"
                if ($parts.Count -ge 3) {
                    [pscustomobject]@{ Name = $parts[0].Trim(); Tip = $parts[1].Trim(); Unix = $parts[2].Trim() }
                }
            })
    } else {
        Write-Warning "could not list local branches -- the branch lanes are skipped. ($(($refRes.Output | Out-String).Trim()))"
    }
    $rows = @($rows | Where-Object { $_.Name -ne $trunk })

    # BOTH PR LOOKUPS ARE ONE CALL EACH, matched locally, for the reason prune-merged states for its
    # own: a repo a week into this workflow already has dozens of each, and this is a tidy-up rather
    # than a report anyone waits on. A gh that cannot answer is NOT an error here either -- it means a
    # proof cannot be established, so the branch keeps the weakest classification it qualifies for.
    $mergedTips = $null
    $closedTips = $null
    if ($rows.Count -gt 0) {
        $ghCmd = Get-Command 'gh' -ErrorAction SilentlyContinue
        if ($ghCmd) {
            $mergedRes = Invoke-NativeCapture -FilePath 'gh' -Arguments @(
                'pr', 'list', '--state', 'merged', '--limit', '200', '--json', 'headRefName,headRefOid')
            if ($mergedRes.ExitCode -eq 0) {
                try {
                    $body = ($mergedRes.Output | Out-String).Trim()
                    $parsed = if ($body) { @($body | ConvertFrom-Json) } else { @() }
                    $mergedTips = Get-MergedPrTips -Pairs @($parsed | ForEach-Object {
                        [pscustomobject]@{ Name = $_.headRefName; Tip = $_.headRefOid } })
                } catch {
                    Write-Warning "gh's merged-PR list could not be read as JSON -- squash-merged branches will not be recognised. ($($_.Exception.Message))"
                }
            } else {
                Write-Warning "gh could not list merged PRs -- squash-merged branches will not be recognised. ($(($mergedRes.Output | Out-String).Trim()))"
            }

            # `--state closed` INCLUDES MERGED, because merged is a kind of closed and gh has no state
            # that means closed-and-not-merged. THE FILTER HAS TO BE ON THE SERVER, not here, and that
            # was measured rather than assumed: this script first dropped merged rows client-side after
            # `--limit 200`, and found ZERO abandoned branches in a repo that has three. In a repo where
            # nearly every PR merges, the 200 most recent CLOSED pull requests are 200 merged ones, so
            # every genuinely abandoned branch falls outside the window -- a filter that is correct and
            # reaches nothing. `--search is:unmerged` asks GitHub the question instead, so the whole
            # limit is spent on rows that can actually be a proof.
            #
            # mergedAt is still requested and still dropped on, as a belt: the search qualifier is
            # GitHub's to interpret, and a row carrying a merge date must never reach the abandoned
            # classification whatever the server thought it was answering.
            $closedRes = Invoke-NativeCapture -FilePath 'gh' -Arguments @(
                'pr', 'list', '--state', 'closed', '--search', 'is:unmerged', '--limit', '200',
                '--json', 'headRefName,headRefOid,mergedAt')
            if ($closedRes.ExitCode -eq 0) {
                try {
                    $body = ($closedRes.Output | Out-String).Trim()
                    $parsed = if ($body) { @($body | ConvertFrom-Json) } else { @() }
                    $closedTips = Get-ClosedPrTips -Pairs @($parsed |
                        Where-Object { -not $_.mergedAt } |
                        ForEach-Object { [pscustomobject]@{ Name = $_.headRefName; Tip = $_.headRefOid } })
                } catch {
                    Write-Warning "gh's closed-PR list could not be read as JSON -- no branch will be classified abandoned. ($($_.Exception.Message))"
                }
            } else {
                Write-Warning "gh could not list closed PRs -- no branch will be classified abandoned. ($(($closedRes.Output | Out-String).Trim()))"
            }
        } else {
            Write-Warning "gh is not available -- only ancestry can prove anything, so nothing will be classified abandoned."
        }
    }

    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    foreach ($row in $rows) {
        $anc = (Invoke-Git -Arguments @('merge-base', '--is-ancestor', $row.Tip, $trunk)).ExitCode -eq 0
        $age = -1
        $unix = 0
        if ([long]::TryParse($row.Unix, [ref]$unix) -and $unix -gt 0) {
            $age = [int][math]::Floor(($now - $unix) / 86400)
        }
        $branchClasses += Get-BranchTidyClass -Name $row.Name -Tip $row.Tip -IsAncestorOfTrunk $anc `
            -MergedTips $mergedTips -ClosedTips $closedTips -AgeDays $age -MaxAgeDays $MaxAgeDays
    }
}

# ===================================================================================================
# LANE 1 -- stale lanes. FIRST, because a worktree blocks the delete of the branch it holds (#1760).
# ===================================================================================================

if ($runCheckout) {
    Write-Lane '1' 'Stale lanes -- a worktree whose branch is finished'
    # WRAPPED, and it is not decoration: PowerShell unwraps a single-element array on return, so a run
    # that found exactly ONE stale lane would hand back a bare PSCustomObject whose .Count is $null.
    # That reads as 0, and the summary line then said "nothing found" underneath the lane it had just
    # printed. Measured on the first real run of this script.
    $lanes = @(Get-StaleLaneDecisions -WorktreeRecords $worktreeRecords -BranchClasses $branchClasses)
    if ($lanes.Count -eq 0) {
        Write-Item 'None.' 'DarkGray'
    }
    foreach ($l in $lanes) {
        $reportedTotal++
        Write-Item "$(Get-DisplayRef $l.Branch) -- $($l.Reason)" 'Yellow'
        Write-Item "    a second full checkout at $(Get-DisplayPath $l.Path)" 'DarkGray'
        if ($l.Class -eq 'reapable') {
            Write-Item '    this ALSO blocks lane 2: git will not delete a branch checked out in a worktree.' 'Red'
        }
        Write-PathHandover -Prefix $l.Command -Path $l.Path
        Write-PathHandover -Prefix $l.RawCommand -Path $l.Path
    }
    Write-Item (Get-TidySummaryLine -Lane 'Stale lanes' -Reported $lanes.Count) 'White'
}

# ===================================================================================================
# LANE 2 -- merged branches and stale tracking refs. THE ONLY LANE THAT DELETES, by delegation.
# ===================================================================================================

if ($runCheckout) {
    Write-Lane '2' 'Merged branches and stale tracking refs -- delegated to prune-merged.ps1'
    $prune = Join-Path $PSScriptRoot '..\task\prune-merged.ps1'
    if (-not (Test-Path -LiteralPath $prune -PathType Leaf)) {
        Write-Item "prune-merged.ps1 was not found at $prune -- this lane is skipped." 'Red'
    } else {
        $pruneArgs = @{ Remote = $Remote }
        if ($DryRun) { $pruneArgs['DryRun'] = $true }
        # Invoked directly rather than captured: its output IS this lane's report, and relaying it
        # through a capture would strip the colour that separates its kept lines from its deleted ones.
        & $prune @pruneArgs
        $reapable = @($branchClasses | Where-Object { $_.Class -eq 'reapable' }).Count
        if (-not $DryRun) { $actedTotal += $reapable }
    }
}

# ===================================================================================================
# LANE 3 -- abandoned branches. The new proof, and the reason this script exists.
# ===================================================================================================

if ($runCheckout) {
    Write-Lane '3' 'Abandoned branches -- a pull request that was CLOSED without merging'
    $abandoned = @($branchClasses | Where-Object { $_.Class -eq 'abandoned' })
    if ($abandoned.Count -eq 0) { Write-Item 'None.' 'DarkGray' }
    foreach ($a in $abandoned) {
        $reportedTotal++
        Write-Item "$(Get-DisplayRef $a.Name) -- $($a.Reason)" 'Yellow'
        Write-RefHandover -Prefix 'git branch -D' -Ref $a.Name
    }
    if ($abandoned.Count -gt 0) {
        Write-Item '  Nothing above was deleted. A closed PR means the remote copy is gone, so this clone holds the last one.' 'DarkGray'
    }
    Write-Item (Get-TidySummaryLine -Lane 'Abandoned' -Reported $abandoned.Count) 'White'
}

# ===================================================================================================
# LANE 4 -- expired backups and the unprovable middle. Report only, both of them.
# ===================================================================================================

if ($runCheckout) {
    Write-Lane '4' 'Expired backups, and branches no proof reaches'
    $backups  = @($branchClasses | Where-Object { $_.Class -eq 'expired-backup' })
    $recycled = @($branchClasses | Where-Object { $_.Class -eq 'recycled' })
    $live     = @($branchClasses | Where-Object { $_.Class -eq 'live' })
    if ($backups.Count -eq 0 -and $recycled.Count -eq 0) { Write-Item 'None.' 'DarkGray' }
    foreach ($b in $backups) {
        $reportedTotal++
        Write-Item "$(Get-DisplayRef $b.Name) -- $($b.Reason)" 'Yellow'
        Write-RefHandover -Prefix 'git branch -D' -Ref $b.Name
    }
    foreach ($r in $recycled) {
        $reportedTotal++
        Write-Item "$(Get-DisplayRef $r.Name) -- $($r.Reason)" 'Yellow'
        Write-Item '    nothing is proposed for this one: the lookup came up full and belonged to another commit.' 'DarkGray'
    }
    Write-Item (Get-TidySummaryLine -Lane 'Unproven' -Reported ($backups.Count + $recycled.Count) -Untouched $live.Count) 'White'
}

# ===================================================================================================
# LANE 5 -- old stashes. REPORTED, NEVER DROPPED.
# ===================================================================================================

if ($runCheckout) {
    Write-Lane '5' 'Stashes -- reported only, never dropped'
    $stashRes = Invoke-Git -Arguments @('stash', 'list', '--format=%gd%09%ct%09%s')
    $stale = 0
    $total = 0
    if ($stashRes.ExitCode -eq 0) {
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        foreach ($line in (($stashRes.Output | Out-String) -split '\r?\n')) {
            $t = $line.Trim()
            if (-not $t) { continue }
            $total++
            $parts = $t -split "`t"
            if ($parts.Count -lt 3) { continue }
            $unix = 0
            if (-not [long]::TryParse($parts[1].Trim(), [ref]$unix)) { continue }
            $days = [int][math]::Floor(($now - $unix) / 86400)
            if ($days -le $MaxAgeDays) { continue }
            $stale++
            $reportedTotal++
            # The subject is somebody else's free text -- the same class this workflow sanitises at four
            # other consoles (ref-print-lib.ps1's header lists them). Get-DisplayRef strips it here too.
            Write-Item "$($parts[0].Trim()) -- $days days old: $(Get-DisplayRef $parts[2].Trim())" 'Yellow'
            Write-Handover "git stash show -p $($parts[0].Trim())"
        }
    } else {
        Write-Item 'could not read the stash list.' 'Red'
    }
    if ($stale -eq 0) { Write-Item 'None older than the bound.' 'DarkGray' }
    Write-Item (Get-TidySummaryLine -Lane 'Stashes' -Reported $stale -Untouched ($total - $stale)) 'White'
}

# ===================================================================================================
# LANE 6 -- an unfolded branch document sitting on the trunk.
# ===================================================================================================

if ($runCheckout) {
    Write-Lane '6' 'Unfolded changelog entry on the trunk -- delegated to check-unfolded-entry.ps1'
    $unfolded = Join-Path $PSScriptRoot '..\lint\check-unfolded-entry.ps1'
    if (Test-Path -LiteralPath $unfolded -PathType Leaf) { & $unfolded }
    else { Write-Item 'check-unfolded-entry.ps1 is not present in this repo -- lane skipped.' 'DarkGray' }
}

# ===================================================================================================
# LANE 7 -- the ~/.claude plugin administration.
# ===================================================================================================

if ($runMachine) {
    Write-Lane '7' 'The ~/.claude plugin administration -- delegated to check-claude-home.ps1'
    $claudeHome = Join-Path $PSScriptRoot '..\lint\check-claude-home.ps1'
    if (Test-Path -LiteralPath $claudeHome -PathType Leaf) { & $claudeHome }
    else { Write-Item 'check-claude-home.ps1 is not present in this repo -- lane skipped.' 'DarkGray' }
}

# ===================================================================================================
# LANE 8 -- install records pointing at a checkout that is gone (#1449).
#
# ITS PROBE IS THE PROJECT PATH AND NOTHING ELSE, which is exactly why lane 11 exists: a record whose
# checkout is alive but whose PLUGIN NAME the marketplace has retired is not an orphan by this test, and
# this lane's own title says as much (#1773).
# ===================================================================================================

if ($runMachine) {
    Write-Lane '8' 'Orphaned plugin install records -- a checkout that is not on this machine'
    $install = Get-InstallRecord -RepoRoot $repoRoot -UserHomeOverride $UserHomeOverride
    if (-not $install.Exists) {
        Write-Item 'no install administration on this machine -- nothing to check.' 'DarkGray'
    } elseif (-not $install.Readable) {
        Write-Item "the install administration could not be read: $($install.Error)" 'Red'
    } else {
        # The probe is done here rather than in the lib so the lib stays pure -- and so a caller on a
        # machine with an unmounted drive can see exactly which path was tested.
        $probe = @{}
        foreach ($rec in @($install.AllRecords)) {
            $p = [string]$rec.ProjectPath
            if (-not $p) { continue }
            if ($probe.ContainsKey($p)) { continue }
            $probe[$p] = [bool](Test-Path -LiteralPath $p -PathType Container)
        }
        # Wrapped for the single-element unwrap described at the stale-lane call above.
        $orphans = @(Get-OrphanInstallRecords -Records @($install.AllRecords) -PathExists $probe)
        if ($orphans.Count -eq 0) { Write-Item 'None.' 'DarkGray' }
        foreach ($o in $orphans) {
            $reportedTotal++
            # Format-SuspectToken, not the raw id: it comes from a JSON key in ~/.claude, and this line
            # is prose rather than a command -- so the id is sanitized for display and the reader is told
            # when sanitizing changed it. Until #1773 this read $o.Plugin, a field no producer writes, so
            # the name was silently absent from every finding.
            Write-Item "$(Format-SuspectToken -Value ([string]$o.Id)) -> $(Get-DisplayPath $o.ProjectPath)" 'Yellow'
            Write-Item "    $($o.Reason)" 'DarkGray'
        }
        if ($orphans.Count -gt 0) {
            Write-Item '  Moved checkout? Re-install the plugin there. Deleted? The record is dead weight. Nothing on disk tells the two apart, so nothing here guesses.' 'DarkGray'
        }
        Write-Item (Get-TidySummaryLine -Lane 'Install records' -Reported $orphans.Count) 'White'
    }
}

# ===================================================================================================
# LANE 9 -- how far behind this checkout's plugins are.
# ===================================================================================================

if ($runMachine) {
    Write-Lane '9' 'Plugin and marketplace staleness -- delegated to plugin-versions.ps1'
    $versions = Join-Path $PSScriptRoot '..\task\plugin-versions.ps1'
    if (Test-Path -LiteralPath $versions -PathType Leaf) { & $versions }
    else { Write-Item 'plugin-versions.ps1 is not present in this repo -- lane skipped.' 'DarkGray' }
}

# ===================================================================================================
# LANE 10 -- leftover fixture trees under the scratch root.
# ===================================================================================================

if ($runMachine) {
    Write-Lane '10' 'Fixture trees under the scratch root -- attributed, never deleted'
    $scratch = if ($ScratchRoot) { $ScratchRoot } else { [System.IO.Path]::GetTempPath() } # temp-path-exempt: reader, not composer
    if (-not (Test-Path -LiteralPath $scratch -PathType Container)) {
        Write-Item "scratch root $(Get-DisplayPath $scratch) does not exist -- lane skipped." 'DarkGray'
    } else {
        # THE WALK IS ONE LEVEL DEEP, because that is where New-ScratchPath puts things: a direct child
        # of the temp root, always. A recursive scan would be slow and would also let a match deep
        # inside an unrelated tree be reported as if it were ours.
        $livePids = @()
        try { $livePids = @(Get-Process -ErrorAction SilentlyContinue | ForEach-Object { $_.Id }) } catch { }

        $leftover = 0; $live = 0; $retained = 0
        foreach ($dir in @(Get-ChildItem -LiteralPath $scratch -Directory -ErrorAction SilentlyContinue)) {
            $ageHours = ([DateTime]::UtcNow - $dir.LastWriteTimeUtc).TotalHours
            switch (Get-ScratchLeftoverVerdict -Name $dir.Name -LivePids $livePids -AgeHours $ageHours -MinAgeHours $MinFixtureAgeHours) {
                'leftover' {
                    $leftover++
                    $reportedTotal++
                    Write-Item "$(Get-DisplayPath $dir.Name) -- $([int]$ageHours)h old, and the pid in its name is not a running process" 'Yellow'
                }
                'live'     { $live++ }
                'retained' { $retained++ }
            }
        }
        if ($leftover -eq 0) {
            Write-Item 'No tree attributable to a run that has ended.' 'DarkGray'
        } else {
            # NO COMMAND IS HANDED OVER HERE, and that is the one lane where the omission is the point.
            # scripts/README.md already decided these stay standing, and names a sweep by name pattern
            # as the delete primitive New-ScratchPath exists to remove (#1659, #1668). Printing the
            # Remove-Item line would be re-proposing exactly that, one copy-paste away.
            Write-Item '  Left standing on purpose (#1668). Clear by hand what you recognise -- a pattern sweep here is the delete primitive New-ScratchPath exists to prevent (#1659).' 'DarkGray'
        }
        Write-Item (Get-TidySummaryLine -Lane 'Fixture trees' -Reported $leftover -Untouched ($live + $retained)) 'White'
        if ($retained -gt 0) { Write-Item "  ($retained retained-on-purpose artefact(s) skipped: sync-pr-body, test-suite-gate.)" 'DarkGray' }
    }
}

# ===================================================================================================
# LANE 11 -- install records under a plugin name the marketplace has retired (#1773).
#
# THE MIRROR IMAGE OF LANE 8, and it is numbered 11 rather than slotted in beside it on purpose: lane
# numbers are quoted in this repo's changelog, in the skill page and in a sibling suite, and renumbering
# to make two related lanes adjacent would silently invalidate every one of those references.
# ===================================================================================================

if ($runMachine) {
    Write-Lane '11' 'Install records under a RETIRED plugin name -- a checkout that is still here'
    $install11 = Get-InstallRecord -RepoRoot $repoRoot -UserHomeOverride $UserHomeOverride
    if (-not $install11.Exists) {
        Write-Item 'no install administration on this machine -- nothing to check.' 'DarkGray'
    } elseif (-not $install11.Readable) {
        Write-Item "the install administration could not be read: $($install11.Error)" 'Red'
    } else {
        $allRecs = @($install11.AllRecords)

        # THE AUTHORITY IS EACH MARKETPLACE'S OWN CLONE, not this repo's marketplace.json. The question
        # is machine-wide, a record can name a marketplace this repo has never heard of, and the clone
        # under ~/.claude is the only per-marketplace manifest a consumer has. Same directory
        # plugin-versions.ps1 reads, resolved the same way.
        $userHome11 = Get-UserClaudeHome -UserHomeOverride $UserHomeOverride
        $liveNames = @{}
        $unreadable = @()
        $marketplaces11 = @($allRecs |
            ForEach-Object { $p = ([string]$_.Id) -split '@'; if ($p.Count -eq 2 -and $p[1]) { $p[1] } } |
            Select-Object -Unique)
        foreach ($mp in $marketplaces11) {
            $cloneDir = if ($userHome11) { Join-Path $userHome11 (Join-Path '.claude' (Join-Path 'plugins' (Join-Path 'marketplaces' $mp))) } else { '' }
            if (-not $cloneDir -or -not (Test-Path -LiteralPath $cloneDir -PathType Container)) {
                $unreadable += "$mp (no clone at $(Get-DisplayPath $cloneDir))"
                continue
            }
            # GUARDED, because Get-RepoPluginRoots throws on a marketplace.json it cannot parse -- and
            # correctly so, that IS a misconfiguration. But an authority this run could not read is not
            # evidence that a plugin is gone, so the marketplace simply gets no entry and every record
            # naming it stays silent.
            try {
                $roots = @(Get-RepoPluginRoots -RepoRoot $cloneDir)
                if ($roots.Count -gt 0) { $liveNames[$mp] = [string[]]@($roots | ForEach-Object { [string]$_.Name }) }
                else { $unreadable += "$mp (the clone's marketplace.json lists no plugins)" }
            } catch {
                $unreadable += "$mp ($($_.Exception.Message))"
            }
        }

        $probe11 = @{}
        foreach ($rec in $allRecs) {
            $p = [string]$rec.ProjectPath
            if (-not $p) { continue }
            if ($probe11.ContainsKey($p)) { continue }
            $probe11[$p] = [bool](Test-Path -LiteralPath $p -PathType Container)
        }

        # Wrapped for the single-element unwrap described at the stale-lane call above.
        $dead = @(Get-RetiredNameInstallRecords -Records $allRecs -LivePluginNames $liveNames -PathExists $probe11)
        if ($dead.Count -eq 0) { Write-Item 'None.' 'DarkGray' }

        # WHOSE RECORD IS IT? The register is machine-wide, so most findings here name a checkout that
        # is not this one -- and `claude plugin uninstall` is keyed on the DIRECTORY IT RUNS IN, so the
        # printed line is only directly runnable for a record whose projectPath is this checkout. Saying
        # so is the difference between a handover and a line that quietly does nothing. Normalised the
        # way Get-InstallRecord normalises the same comparison, so a separator or a trailing slash does
        # not decide it.
        $rootResolved = Resolve-Path -LiteralPath $repoRoot -ErrorAction SilentlyContinue
        $rootKey = if ($rootResolved) { $rootResolved.Path.TrimEnd('\', '/') } else { ([string]$repoRoot).TrimEnd('\', '/') }
        $elsewhere = 0
        foreach ($d in $dead) {
            $reportedTotal++
            Write-Item "$(Format-SuspectToken -Value ([string]$d.Id)) -> $(Get-DisplayPath $d.ProjectPath)" 'Yellow'
            Write-Item "    $($d.Reason)" 'DarkGray'
            Write-PluginHandover -Prefix $d.Command -Plugin $d.Plugin -Marketplace $d.Marketplace -Scope $d.Scope
            $recResolved = Resolve-Path -LiteralPath $d.ProjectPath -ErrorAction SilentlyContinue
            $recKey = if ($recResolved) { $recResolved.Path.TrimEnd('\', '/') } else { ([string]$d.ProjectPath).TrimEnd('\', '/') }
            if ($recKey -ine $rootKey) {
                $elsewhere++
                Write-Item '    Run it FROM that checkout -- an uninstall is keyed on the directory it runs in, so from here it would not reach this record.' 'DarkGray'
            }
        }
        if ($elsewhere -gt 0) {
            Write-Item "  $elsewhere of these belong to another checkout on this machine. They are reported, not acted on, for the same reason lane 8 reports rather than repairs: this run reads the machine-wide register and does not visit another repository." 'DarkGray'
        }
        if ($unreadable.Count -gt 0) {
            Write-Item "  Not examined: $($unreadable.Count) marketplace(s) whose plugin list could not be read -- $($unreadable -join '; ')." 'DarkGray'
        }
        Write-Item (Get-TidySummaryLine -Lane 'Retired-name records' -Reported $dead.Count) 'White'
    }
}

# ===================================================================================================
# LANE 12 -- the extracted payload trees under ~/.claude/plugins/cache/ (#1812).
#
# THE OTHER END OF THE POINTER LANES 8 AND 11 JUDGE. Those two ask whether a RECORD is still good; this
# one asks what the record's installPath POINTS AT, which is the extracted copy of the plugin a session
# actually loads. Measured September 10, 2026 on Claude Code 2.1.267: 41 trees over 32.6 MB, of which 30
# -- 22.2 MB -- carried the harness's own .orphaned_at mark and every one of those was still on disk, the
# oldest mark six days old. An uninstall removes the record and leaves the payload.
#
# IT REPORTS AND HANDS OVER NOTHING TO RUN, and that omission is the point, exactly as in lane 10. No
# plugin-cache verb exists to hand over, so the only line to print would be a recursive Remove-Item
# under the user's home -- the delete primitive #1659 exists to remove.
# ===================================================================================================

if ($runMachine) {
    Write-Lane '12' 'Extracted plugin payload -- the copy a session loads, and the copies nothing points at'
    $userHome12 = Get-UserClaudeHome -UserHomeOverride $UserHomeOverride
    $cacheRoot = if ($userHome12) { Join-Path $userHome12 (Join-Path '.claude' (Join-Path 'plugins' 'cache')) } else { '' }
    if (-not $cacheRoot -or -not (Test-Path -LiteralPath $cacheRoot -PathType Container)) {
        Write-Item 'no extracted plugin payload on this machine -- nothing to check.' 'DarkGray'
    } else {
        $install12 = Get-InstallRecord -RepoRoot $repoRoot -UserHomeOverride $UserHomeOverride
        if ($install12.Exists -and -not $install12.Readable) {
            # WITHOUT THE REGISTER THERE IS NO VERDICT, only a directory listing. Saying so beats
            # reporting every tree as ownerless, which is what an empty install-path set would do.
            Write-Item "the install administration could not be read, so no tree can be judged: $($install12.Error)" 'Red'
        } else {
            $installPaths = @(@($install12.AllRecords) | ForEach-Object { [string]$_.InstallPath } | Where-Object { $_ })
            $livePids12 = @()
            try { $livePids12 = @(Get-Process -ErrorAction SilentlyContinue | ForEach-Object { $_.Id }) } catch { }

            # THE WALK IS EXACTLY THREE LEVELS: <marketplace>/<plugin>/<key>. That shape is the cache
            # key itself -- a version string, or a commit sha where an extraction happened between two
            # releases -- and a deeper walk would start reporting a plugin's own subdirectories as if
            # they were payload trees.
            $loaded = 0; $leased = 0; $ownerless = 0; $ownerlessBytes = [int64]0; $staleLeaseTrees = 0
            $ownerlessRows = @()
            foreach ($mp in @(Get-ChildItem -LiteralPath $cacheRoot -Directory -ErrorAction SilentlyContinue)) {
                foreach ($plugin in @(Get-ChildItem -LiteralPath $mp.FullName -Directory -ErrorAction SilentlyContinue)) {
                    foreach ($tree in @(Get-ChildItem -LiteralPath $plugin.FullName -Directory -ErrorAction SilentlyContinue)) {
                        $marked = Test-Path -LiteralPath (Join-Path $tree.FullName '.orphaned_at') -PathType Leaf
                        $leasePids = @()
                        $leaseDir = Join-Path $tree.FullName '.in_use'
                        if (Test-Path -LiteralPath $leaseDir -PathType Container) {
                            foreach ($lease in @(Get-ChildItem -LiteralPath $leaseDir -File -ErrorAction SilentlyContinue)) {
                                $leasePid = 0
                                if ([int]::TryParse($lease.BaseName, [ref]$leasePid)) { $leasePids += $leasePid }
                            }
                        }
                        $verdict = Get-PayloadTreeVerdict -Path $tree.FullName -InstallPaths $installPaths -OrphanMarked $marked -LeasePids $leasePids -LivePids $livePids12
                        if (@($verdict.StaleLeases).Count -gt 0) { $staleLeaseTrees++ }
                        switch ($verdict.Class) {
                            'loaded' {
                                $loaded++
                                # A disagreement between the register and the harness's own mark is the
                                # one thing in this lane worth interrupting an otherwise clean run for.
                                if ($marked) {
                                    $reportedTotal++
                                    Write-Item (Get-DisplayPath $tree.FullName) 'Yellow'
                                    Write-Item "    $($verdict.Reason)" 'DarkGray'
                                }
                            }
                            'leased' { $leased++ }
                            'ownerless' {
                                $ownerless++
                                $bytes = [int64]0
                                try { $bytes = [int64](@(Get-ChildItem -LiteralPath $tree.FullName -Recurse -File -ErrorAction SilentlyContinue) | Measure-Object -Property Length -Sum).Sum } catch { }
                                $ownerlessBytes += $bytes
                                $ownerlessRows += [pscustomobject]@{
                                    Path = $tree.FullName; Bytes = $bytes; Id = "$($plugin.Name)@$($mp.Name)"; Key = $tree.Name
                                }
                            }
                        }
                    }
                }
            }

            if ($ownerless -eq 0) {
                Write-Item 'Every extracted payload on this machine is one an install record still points at.' 'DarkGray'
            } else {
                # GROUPED BY PLUGIN ID, not one line per tree. A machine that has taken a dozen releases
                # holds a dozen trees per plugin, and a per-tree list buries the one number a reader
                # acts on -- how much of the disk this is -- under its own length.
                $groups = @($ownerlessRows | Group-Object -Property Id | Sort-Object -Property @{ Expression = { (@($_.Group) | Measure-Object -Property Bytes -Sum).Sum } } -Descending)
                foreach ($group in $groups) {
                    $sum = [int64]((@($group.Group) | Measure-Object -Property Bytes -Sum).Sum)
                    $keys = (@(@($group.Group) | Sort-Object -Property Key | ForEach-Object { $_.Key }) -join ', ')
                    $reportedTotal++
                    Write-Item "$(Format-SuspectToken -Value ([string]$group.Name)) -- $($group.Count) tree(s), $([math]::Round($sum / 1MB, 1)) MB: $keys" 'Yellow'
                }
                Write-Item "  $([math]::Round($ownerlessBytes / 1MB, 1)) MB in $ownerless tree(s) no install record points at." 'DarkGray'
                Write-Item '  NO COMMAND IS OFFERED HERE. No plugin-cache verb exists, an uninstall removes the record and leaves the payload (measured, #1812), and a recursive delete under your home is the primitive #1659 exists to prevent. Clear by hand what you recognise.' 'DarkGray'
            }
            if ($leased -gt 0) {
                Write-Item "  $leased tree(s) no record points at are still being READ by a live process -- a session that started before the record moved. Untouched, and they go when it does." 'DarkGray'
            }
            if ($staleLeaseTrees -gt 0) {
                Write-Item "  $staleLeaseTrees tree(s) carry a lease whose process has ended. Harmless to a session; the harness's own sweep is what reads them." 'DarkGray'
            }
            Write-Item (Get-TidySummaryLine -Lane 'Payload trees' -Reported $ownerless -Untouched ($loaded + $leased)) 'White'
        }
    }
}

# ===================================================================================================

Write-Host ''
if ($DryRun) {
    Write-Host "Done (-DryRun). Nothing was changed; $reportedTotal item(s) were handed over." -ForegroundColor Green
} else {
    Write-Host "Done. $actedTotal item(s) acted on, $reportedTotal handed over for you to decide." -ForegroundColor Green
}
Write-Host "No remote branch was touched, no stash was dropped, and no pull request was opened, merged or closed." -ForegroundColor DarkGray
exit 0
