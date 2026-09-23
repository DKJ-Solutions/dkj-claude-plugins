<#
.SYNOPSIS
    The pure classification behind tidy-machine.ps1: which local clutter is PROVABLY finished, which is
    merely finished-looking, and which is live work that must not be touched.

.DESCRIPTION
    WHY A SECOND PROOF EXISTS AT ALL, MEASURED SEPTEMBER 10, 2026. prune-merged.ps1 proves one thing:
    a branch was MERGED, by ancestry or by a merged PR's head commit. Run in the source repo that day,
    it classified 32 local branches beside the trunk as 27 reapable and 5 kept -- and not one of the
    five was live work:

      backup/main-pre-sync-20260903      no PR has ever existed for this name
      docs/changelog-dropped-ship-cost-v1   PR #1299 CLOSED, unmerged
      fix/round-tally-error-wrap-v1         PR #1243 CLOSED, unmerged
      fix/branch-doc-per-branch-path-v1     PR #1260 CLOSED, unmerged -- and holding a worktree
      feat/plugin-version-overview          PR #1599 MERGED, tip one commit past the merge

    prune-merged keeps all five CORRECTLY -- none of them has a merge proof, and inventing one would be
    the #1191 defect over again. What was missing is a name for what they ARE. A closed pull request is
    a decision a person took on the tracker: this work does not land. That is evidence of exactly the
    same kind as a merged one -- a state outside the working tree -- and it is the only thing that
    separates "abandoned" from "in progress" without guessing from a date or a branch name.

    SO THE CLOSED-PR PROOF IS HELD TO THE SAME PAIR TEST AS THE MERGED ONE, and this is the whole reason
    it lives here rather than being inlined at the call site. inbound #1191 measured what a NAME-ONLY
    match costs: deleteBranchOnMerge frees a branch name the moment a PR lands, so a name recycled by a
    later branch inherits the earlier PR's verdict. Nothing about that trap is specific to merging -- a
    closed PR frees the name just as thoroughly, and a name-only closed-PR test would force-delete a
    live branch while printing the word "abandoned" at it.

    THE MAP AND THE PAIR TEST ARE merged-pr-lib.ps1's, DELIBERATELY REUSED RATHER THAN RE-TYPED.
    Get-MergedPrTips and Test-RefMergedByPr read "merged" in their names, and what they actually
    implement is narrower and reusable: build a name -> tips lookup keyed with an ORDINAL comparer, then
    answer whether this exact name AND this exact tip are in it. Which PR state those tips describe is
    decided by the caller, in the `--state` it passed to gh. A private copy here would be a second
    implementation of the one thing that has already gone wrong twice (#1190, #1191) -- and the ordinal
    comparer is precisely the detail a re-typed copy loses silently. Get-ClosedPrTips below is a named
    alias over that call, so a reader of tidy-machine.ps1 does not have to hold the generalisation in
    their head while reading a line about closed PRs.

    WHAT THIS LIB WILL NOT DO: decide, or compose a command. Every function here returns a
    classification with a reason and, at most, the VERB that would act on it -- never a finished
    command line with a branch name or a path interpolated into it. That is deliberate rather than
    fussy: a ref name is not safe to paste on trust (git rejects only the control half of the display
    class, so a name can carry a format character or a shell metacharacter -- #1594, #1617), and a lib
    that handed back
    a ready-made string would be handing every future caller a line that skipped the paste guard. The
    caller renders the name through Get-PasteableRef and joins the two. Running the result is the
    reader's, for everything but prune-merged's own two proofs -- see tidy-machine.ps1's header for the
    authority split and Dave's September 10, 2026 decision behind it.

    PURE: nothing here runs git, gh, or touches the filesystem. Every input is handed in, which is what
    makes the suite able to drive the classifier over states this machine has never been in.

    Pure ASCII (repo convention for .ps1).
#>

# The classes this lib can return, in the order tidy-machine reports them. Declared once so the script
# and its suite cannot disagree about the spelling of a class -- the drift that a string literal in two
# files always eventually produces.
$script:TidyClasses = @(
    'stale-lane'      # a worktree whose branch is finished; blocks the branch delete until removed
    'reapable'        # prune-merged's own two proofs -- this lib names it, prune-merged acts on it
    'abandoned'       # a CLOSED, unmerged PR for this exact name and tip
    'recycled'        # a PR of this name exists, but not for this commit -- no proof either way
    'expired-backup'  # a backup/* branch older than the age bound
    'live'            # no proof of anything; unfinished work, parked work, another machine's branch
)

function Get-TidyClasses {
    <#
    .SYNOPSIS
        The classification vocabulary, so a caller can order or filter without re-typing the strings.
    #>
    return @($script:TidyClasses)
}

function Get-ClosedPrTips {
    <#
    .SYNOPSIS
        Name/tip pairs from a CLOSED-and-unmerged PR listing, as the same name -> tips lookup
        Get-MergedPrTips builds for merged ones.

    .DESCRIPTION
        A NAMED ALIAS, NOT A SECOND IMPLEMENTATION. It calls Get-MergedPrTips, whose behaviour is
        general (build an ordinal-keyed lookup from name/tip pairs and drop the rows that cannot be a
        proof) even though its name is not. The alias exists so the call site in tidy-machine.ps1 reads
        as a sentence about closed PRs, and so the reuse is stated in one place instead of needing a
        comment at every caller.

        THE CALLER IS RESPONSIBLE FOR THE STATE, and this cannot be checked from here. gh's
        `--state closed` includes MERGED pull requests -- merged is a kind of closed -- so a caller that
        passes that listing straight in gets a map in which every merged branch also reads as abandoned.
        tidy-machine.ps1 asks for `--state closed` and then drops every row with a non-null mergedAt,
        because gh has no state that means closed-and-not-merged.

    .PARAMETER Pairs
        Objects carrying a Name and a Tip, exactly as Get-MergedPrTips takes them.
    #>
    param($Pairs = @())
    return (Get-MergedPrTips -Pairs $Pairs)
}

function Get-BranchTidyClass {
    <#
    .SYNOPSIS
        Classify one local branch: what is it, why, and what -- if anything -- would act on it.

    .DESCRIPTION
        THE ORDER OF THE TESTS IS THE SAFETY PROPERTY, and it runs from the strongest proof to the
        weakest so that a branch can never be reported under a weaker one than it has earned:

          1. MERGED, by ancestry or by the merged name+tip pair       -> 'reapable'
          2. CLOSED unmerged, by the closed name+tip pair             -> 'abandoned'
          3. a PR of this name exists but not for this tip            -> 'recycled'
          4. a backup/* branch past the age bound                     -> 'expired-backup'
          5. none of the above                                        -> 'live'

        WHY 'reapable' IS FIRST AND WHY THIS LIB NAMES IT AT ALL, given prune-merged already decides it.
        The lane pass needs the answer before prune-merged runs: a worktree holding a finished branch has
        to be reported first, because git refuses to delete a branch that is checked out anywhere
        (measured, issue #1760 -- `error: cannot delete branch 'X' used by worktree at '<path>'`, and
        that refusal takes precedence over the unmerged check). So the class is computed here, the lane
        report is emitted from it, and the DELETING is still prune-merged's alone.

        WHY 'recycled' IS NOT 'live', AND NOT 'abandoned' EITHER. It is the state inbound #1191 named:
        the lookup came up FULL and belonged to a different commit. Calling it live would hide it;
        calling it abandoned would act on somebody else's proof. It gets its own class and its own
        sentence, and nothing is ever proposed for it -- the reader is told what was measured and left
        to decide, which is the same answer prune-merged reaches for its own recycled case (#1296).

        WHY THE AGE BOUND ONLY APPLIES TO backup/*. An age is not evidence about anything: a branch
        untouched for a month may be a month of not getting round to it. The one place a date carries
        meaning is a branch whose NAME says it was made to be temporary, and `backup/` is this
        workflow's only such prefix. Everything else is judged on the tracker or not at all.

        AND AN EXPIRED BACKUP IS REPORTED WITH WHETHER IT IS AN ANCESTOR, because the two cases are
        not the same risk wearing one name. A backup that is an ancestor of the trunk holds nothing
        the trunk does not; one that is NOT holds commits that exist in this clone and nowhere else --
        which is exactly what a pre-sync backup is for when a sync went non-fast-forward. Measured on
        backup/main-pre-sync-20260903 in the source repo: not an ancestor. Nothing here proposes
        deleting either kind; the distinction is what makes the report worth reading.

    .PARAMETER Name
        The branch name as a person types it -- no refs/heads/ prefix.

    .PARAMETER Tip
        The commit the branch points at now. Empty means unknown, which can never be a proof.

    .PARAMETER IsAncestorOfTrunk
        Whether the tip is an ancestor of the trunk. The caller runs git merge-base --is-ancestor.

    .PARAMETER MergedTips
        Get-MergedPrTips' lookup over MERGED pull requests. $null means gh could not answer.

    .PARAMETER ClosedTips
        Get-ClosedPrTips' lookup over CLOSED-and-unmerged pull requests. $null means gh could not
        answer, and then no branch is ever classified 'abandoned' -- the same erring-toward-nothing
        that prune-merged applies to its own missing lookup.

    .PARAMETER AgeDays
        How many days since the branch's tip commit. -1 means unknown, which never expires a backup.

    .PARAMETER MaxAgeDays
        The bound past which a backup/* branch is called expired.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Name,
        [AllowEmptyString()][string]$Tip = '',
        [bool]$IsAncestorOfTrunk = $false,
        $MergedTips = $null,
        $ClosedTips = $null,
        [int]$AgeDays = -1,
        [int]$MaxAgeDays = 14
    )

    if (-not $Name) {
        return [pscustomobject]@{ Name = ''; Class = 'live'; Reason = 'no branch name'; Command = '' }
    }

    if ($IsAncestorOfTrunk) {
        return [pscustomobject]@{
            Name    = $Name
            Class   = 'reapable'
            Reason  = 'ancestor of the trunk'
            Command = ''   # prune-merged acts on this one; nothing is handed to the reader.
        }
    }

    if (Test-RefMergedByPr -Name $Name -Tip $Tip -MergedTips $MergedTips) {
        return [pscustomobject]@{
            Name    = $Name
            Class   = 'reapable'
            Reason  = 'this commit is the head of a merged PR'
            Command = ''
        }
    }

    if (Test-RefMergedByPr -Name $Name -Tip $Tip -MergedTips $ClosedTips) {
        return [pscustomobject]@{
            Name    = $Name
            Class   = 'abandoned'
            Reason  = 'this commit is the head of a PR that was CLOSED without merging'
            # -D, never -d: an abandoned branch is by definition not an ancestor of the trunk, so -d
            # would refuse it and the reader would be handed a line that cannot work. The VERB only --
            # the name is joined on by the caller, through the paste guard. See this lib's header.
            Command = 'git branch -D'
        }
    }

    $mergedNameKnown = Test-MergedPrNameKnown -Name $Name -MergedTips $MergedTips
    $closedNameKnown = Test-MergedPrNameKnown -Name $Name -MergedTips $ClosedTips
    if ($mergedNameKnown -or $closedNameKnown) {
        $which = if ($mergedNameKnown) { 'merged' } else { 'closed' }
        return [pscustomobject]@{
            Name    = $Name
            Class   = 'recycled'
            Reason  = "a $which PR used this name, but not this commit -- no proof for this tip (a recycled name, or a commit added after that PR ended)"
            Command = ''
        }
    }

    if ($Name -like 'backup/*' -and $AgeDays -ge 0 -and $AgeDays -gt $MaxAgeDays) {
        $holds = if ($IsAncestorOfTrunk) {
            'its commits are all in the trunk, so nothing here is unique to it'
        } else {
            'it is NOT an ancestor of the trunk, so it holds commits that exist in this clone and nowhere else'
        }
        return [pscustomobject]@{
            Name    = $Name
            Class   = 'expired-backup'
            Reason  = "a backup branch $AgeDays days old (bound: $MaxAgeDays) -- $holds"
            Command = 'git branch -D'
        }
    }

    return [pscustomobject]@{
        Name    = $Name
        Class   = 'live'
        Reason  = 'no proof of a merge and no closed PR -- unfinished, parked, or pushed from another machine'
        Command = ''
    }
}

function Get-StaleLaneDecisions {
    <#
    .SYNOPSIS
        Which worktrees hold a branch that is finished, and are therefore both clutter in their own
        right and a blocker on reaping that branch.

    .DESCRIPTION
        A LANE IS TWO KINDS OF CLUTTER AT ONCE, which is why it is reported before anything else runs.
        It is a second full copy of the repository on disk, and it is the reason the branch underneath
        it cannot be deleted: git refuses to delete a branch checked out in ANY worktree, and that
        refusal is raised before the merged/unmerged question is even asked (measured on git
        2.54.0.windows.1, issue #1760). So a run that reaped first and reported lanes afterwards would
        hand the reader git's message about a worktree in the middle of a list of merge proofs.

        THE PRIMARY WORKTREE IS NEVER A LANE. git lists it first and there is no flag on the stanza
        saying so -- that IS the definition (worktree-lib.ps1's own note). It is where the session is
        standing and where shipping happens; removing it is not a tidy-up, it is deleting the checkout.

        A DETACHED OR BARE WORKTREE IS SKIPPED, not because it cannot be stale, but because it holds no
        branch -- so there is no classification to hang the decision on and nothing it can be blocking.
        An open lane mid-creation is detached for exactly one step (worktree-lane.ps1 adds the worktree
        detached, then delegates the branch to new-branch.ps1), and reporting that window as clutter
        would be reporting a script's own intermediate state back at it.

    .PARAMETER WorktreeRecords
        Get-WorktreeRecords' output for the whole clone, primary first.

    .PARAMETER BranchClasses
        Get-BranchTidyClass results, one per local branch, in any order.

    .PARAMETER FinishedClasses
        Which classes count as finished for this purpose. Defaults to reapable and abandoned: those are
        the two that carry a proof. 'recycled' is deliberately absent -- an unproven branch's lane is
        not clutter, it is somebody's open work in the one state we know we cannot judge.
    #>
    param(
        $WorktreeRecords = @(),
        $BranchClasses = @(),
        [string[]]$FinishedClasses = @('reapable', 'abandoned')
    )

    $byName = @{}
    foreach ($c in @($BranchClasses)) {
        if ($null -ne $c -and $c.Name) { $byName[[string]$c.Name] = $c }
    }

    $records = @($WorktreeRecords)
    $decisions = @()
    for ($i = 0; $i -lt $records.Count; $i++) {
        # Index 0 is the primary worktree, by git's own ordering. See the note above.
        if ($i -eq 0) { continue }
        $r = $records[$i]
        if ($null -eq $r) { continue }
        if ($r.Detached -or $r.Bare) { continue }
        if (-not $r.Branch) { continue }
        if (-not $byName.ContainsKey([string]$r.Branch)) { continue }

        $cls = $byName[[string]$r.Branch]
        if ($FinishedClasses -notcontains [string]$cls.Class) { continue }

        $decisions += [pscustomobject]@{
            Path    = $r.Path
            Branch  = $r.Branch
            Class   = $cls.Class
            Reason  = "the lane's branch is $($cls.Class): $($cls.Reason)"
            # THE VERBS ONLY, and the Path above is what the caller renders into them -- see this lib's
            # header for why no finished command line leaves this file.
            #
            # The hand-back route is named first because it is the workflow's own, and it refuses the
            # two states a bare `git worktree remove` would discover halfway through (uncommitted work
            # in the lane, a dirty primary). The raw verb is offered as well because a lane whose
            # branch is ABANDONED has nothing to hand back to -- nobody is going to ship it.
            Command    = 'scripts\task\worktree-lane.ps1 -HandBack -Lane'
            RawCommand = 'git worktree remove'
        }
    }

    return @($decisions)
}

function Get-OrphanInstallRecords {
    <#
    .SYNOPSIS
        Plugin install records in ~/.claude whose checkout folder no longer exists on this machine.

    .DESCRIPTION
        THE RECORD IS KEYED ON A FOLDER PATH, which is what makes this a real class of clutter rather
        than a hypothetical one. Installing a plugin with --scope project writes a per-checkout record
        under that checkout's path; renaming or moving the checkout unlinks the plugin with no error at
        all, and leaves the record behind pointing at a directory that is gone
        (issue #1449). Nothing reports it, because the two halves fail in opposite
        directions: the checkout reports "not installed here", the record reports a checkout.

        IT IS REPORT-ONLY, AND THAT IS NOT TIMIDITY. A record whose path is missing may be a checkout
        that was moved (the plugin should be re-installed at the new path) or one that was deleted (the
        record is dead weight). Those want opposite actions and nothing on disk distinguishes them, so
        the run says which paths are gone and lets the reader say which happened.

        A DRIVE THAT IS NOT MOUNTED IS THE FALSE POSITIVE TO BEAT, and the caller's probe is what has to
        answer for it. This function tests nothing itself: it takes the answer per path, so a caller on
        a machine with a detached external drive can decide to probe or to skip, and the suite can drive
        both.

    .PARAMETER Records
        Objects carrying at least a ProjectPath and a Plugin name.

    .PARAMETER PathExists
        A hashtable from project path to $true/$false. A path absent from the table is treated as
        UNKNOWN and never reported -- silence beats a wrong claim about somebody's disk.
    #>
    param(
        $Records = @(),
        [hashtable]$PathExists = @{}
    )

    $orphans = @()
    foreach ($r in @($Records)) {
        if ($null -eq $r) { continue }
        $path = [string]$r.ProjectPath
        if (-not $path) { continue }
        if (-not $PathExists.ContainsKey($path)) { continue }
        if ($PathExists[$path]) { continue }

        $orphans += [pscustomobject]@{
            ProjectPath = $path
            # THE FIELD IS 'Id', AND IT USED TO BE 'Plugin' -- which no producer writes. Get-InstallRecord
            # projects every record onto Id/Scope/Version/GitCommitSha/InstallPath/ProjectPath/
            # InstalledAt/LastUpdated, so the old read resolved to $null on every real record and lane 8
            # printed its finding with the plugin name missing: ' -> C:\gone'. Nothing caught it because
            # this lib's own fixture hand-wrote a Plugin field, and no assert ever read the value back --
            # the classification was always right, only the label was gone. Found while extending this
            # function for #1773; the suite now asserts the id itself.
            Id          = [string]$r.Id
            Reason      = 'the checkout this record was written for is not on this machine any more (moved, renamed, or deleted)'
            Command     = ''
        }
    }

    return @($orphans)
}

function Get-RetiredNameInstallRecords {
    <#
    .SYNOPSIS
        Plugin install records naming a plugin its own marketplace no longer lists, for a checkout that
        is still there -- the mirror image of Get-OrphanInstallRecords.

    .DESCRIPTION
        THE TWO ARE ONE DEFECT FROM OPPOSITE ENDS: a record naming something that no longer exists. Lane
        8 answers it for the CHECKOUT half and says so in its own title -- "a checkout that is not on
        this machine" -- and its probe is purely the record's projectPath, so a record whose PLUGIN NAME
        is gone while its checkout is alive is not an orphan by that test and was measured by nothing
        (issue #1773).

        AND THE PLUGIN-NAME HALF IS THE ONE THIS WORKFLOW GENERATES ITSELF. A rename is a deliberate act
        the source repo performs -- it performed two in two days, #1697 and #1698 -- and each one turns
        every existing install record into dead weight, on every machine and in every checkout that had
        the plugin. Measured after #1698: five records under three retired naming generations, none of
        them reported by any lane, while `claude plugin list` read as seventeen plugins and four of the
        six ENABLED plugins had no install record at all (the state #1764 caused). The signal that would
        have named the real problem was buried in noise nothing could clear.

        IT IS REPORT-ONLY, like its sibling -- but for the opposite reason. There the two candidate
        actions (re-install at the new path, or drop a dead record) are indistinguishable from disk, so
        nothing guesses. Here the action is unambiguous, and what is deliberate is not acting: an
        uninstall removes an install record, which is the kind of bookkeeping this workflow hands over
        rather than performs. The caller renders the verb.

        THE TEST IS SCOPED PER MARKETPLACE, WHICH IS THE ONE THING A CARELESS VERSION GETS WRONG. A
        record can legitimately name a plugin from a DIFFERENT marketplace this machine also uses, so
        the question is never "is this name in a manifest" but "is this name in the manifest of the
        marketplace this record names". A marketplace absent from $LivePluginNames is UNKNOWN and never
        reported -- the caller could not read that clone, and an authority you could not read is not
        evidence of absence.

    .PARAMETER Records
        Objects carrying at least an Id ('<plugin>@<marketplace>') and a ProjectPath -- Get-InstallRecord's
        AllRecords projection.

    .PARAMETER LivePluginNames
        A hashtable from marketplace name to the plugin names that marketplace currently lists. The
        caller reads each clone's own marketplace.json for this and adds a key only for a clone it could
        actually parse. An EMPTY list for a key is treated as unknown too: 'this marketplace ships
        nothing' and 'the read produced nothing' are indistinguishable from in here, and silence beats
        declaring every record for that marketplace dead.

    .PARAMETER PathExists
        A hashtable from project path to $true/$false, exactly as Get-OrphanInstallRecords takes it.
        Only a record whose checkout is PROVEN PRESENT is reported here: a missing one is lane 8's
        finding, an unprobed one is nobody's, and a record with no projectPath at all is machine-wide --
        the paste-ready uninstall carries the record's own scope, which a pathless record does not have,
        so it is left alone for the same reason lane 8 leaves it alone.
    #>
    param(
        $Records = @(),
        [hashtable]$LivePluginNames = @{},
        [hashtable]$PathExists = @{}
    )

    $retired = @()
    foreach ($r in @($Records)) {
        if ($null -eq $r) { continue }
        $id = [string]$r.Id
        if (-not $id) { continue }

        # EXACTLY TWO PARTS. plugin-versions.ps1 reads parts[0] and parts[-1] because it starts from an
        # id a settings file DECLARED and has to make a best effort; this function is deciding whether
        # to tell somebody a plugin is dead, so an id it cannot split unambiguously is one it says
        # nothing about.
        $parts = $id -split '@'
        if ($parts.Count -ne 2) { continue }
        $name = [string]$parts[0]
        $mp   = [string]$parts[1]
        if (-not $name -or -not $mp) { continue }

        $path = [string]$r.ProjectPath
        if (-not $path) { continue }
        if (-not $PathExists.ContainsKey($path)) { continue }
        if (-not $PathExists[$path]) { continue }

        if (-not $LivePluginNames.ContainsKey($mp)) { continue }
        $live = @($LivePluginNames[$mp] | Where-Object { $_ })
        if ($live.Count -eq 0) { continue }

        # ORDINAL AND CASE-SENSITIVE, the position Get-PluginRootByName already takes for this exact
        # comparison: a plugin name is a path segment on a case-sensitive filesystem and an install id,
        # so 'Alpha' is a different plugin from 'alpha'.
        $isLive = $false
        foreach ($ln in $live) {
            if ([string]::Equals([string]$ln, $name, [System.StringComparison]::Ordinal)) { $isLive = $true; break }
        }
        if ($isLive) { continue }

        $retired += [pscustomobject]@{
            ProjectPath = $path
            Id          = $id
            Plugin      = $name
            Marketplace = $mp
            Scope       = [string]$r.Scope
            Version     = [string]$r.Version
            Reason      = "marketplace '$mp' no longer lists a plugin called '$name' -- the record is dead weight from a rename or a removal"
            # THE VERB ONLY, per this lib's header: the caller renders the id through the paste guard and
            # appends the record's own scope. Which scope matters -- `--scope project` REFUSES to remove a
            # record sitting at local (inbound #315), and a session start alone is enough to create one.
            Command     = 'claude plugin uninstall'
        }
    }

    return @($retired)
}

# The leaf New-ScratchPath composes: '<label>-<pid>-<32 hex guid>', a direct child of the temp root.
# Anchored at both ends, and the pid is captured because it is the whole attribution mechanism -- the
# reason that function puts it in front of the guid at all (its own header, and Sylvester's lens).
$script:ScratchLeafPattern = '^(?<label>[A-Za-z0-9][A-Za-z0-9._-]*?)-(?<pid>\d+)-[0-9a-f]{32}$'

# Trees under the temp root that are RETAINED ON PURPOSE and are not litter, matched on their label.
# Both are measured cases, and both would be swept by a naive pattern match:
#   sync-pr-body  -- written deliberately by task/sync-main.ps1 for the operator to paste into
#                    `gh pr create --body-file`, so it MUST outlive the run that wrote it. 546 of them
#                    in the #1668 measurement, read at first as leaked fixtures.
#   test-suite-gate -- the gate's retained capture directories (#1636), kept so a red run can be read
#                    after the fact.
$script:ScratchRetainedLabels = @('sync-pr-body', 'test-suite-gate')

function Get-ScratchLeftoverVerdict {
    <#
    .SYNOPSIS
        What a directory under the scratch root IS: a live run's fixture, a retained artefact, a
        leftover from a run that is no longer alive, or none of this workflow's business.

    .DESCRIPTION
        THIS LANE REPORTS AND NEVER DELETES, AND THAT IS NOT CAUTION -- IT IS A DECISION THIS REPO HAS
        ALREADY TAKEN AND WRITTEN DOWN. Sylvester's lens (.claude/specialists/lenses/specialist-05-15-lens.md), on #1668: the leftovers "are left standing on
        purpose: $PID in the leaf is what makes one attributable to a run that is no longer alive, and a
        person can clear it by hand." It goes further and names the alternative by name -- "the fix that
        would actually reach these is a sweep by name pattern in a shared temp directory, i.e. the same
        delete primitive New-ScratchPath exists to remove."

        SO A SWEEP IS THE THING THAT FUNCTION WAS BUILT TO PREVENT (#1659): a recursive delete at a path
        in a world-writable directory, where New-Item and the .NET writers both FOLLOW a reparse point,
        which turns the operation into a delete primitive somewhere else on the disk. An earlier draft
        of this lane offered -ReapScratch behind a flag and was removed rather than defended. The
        guardrail's intent lived in the tracker and in a README, not in the code, which is exactly the
        case where reading only the tree looks like diligence and is not.

        WHAT IS LEFT IS WORTH HAVING ON ITS OWN. #1668 also measured that the first reading of that
        directory was wrong: 413 entries read as leaked fixtures, of which 546 in the same directory
        were retained-on-purpose artefacts and 162 belonged to an unrelated tool. Attribution is the
        scarce thing, not deletion -- so this answers "which of these belong to a run that is over",
        and a person clears what they choose to.

        THE PID IS THE SIGNATURE, NOT AN AGE. An age is a guess about whether a suite is still running;
        a dead pid is an answer. Age remains as a belt only, because a pid is reused by the OS
        eventually and a young tree whose pid has already been recycled would otherwise read as live.

        PURE: the caller supplies the live pid set and the age. It does not enumerate processes and it
        does not touch the disk.

    .PARAMETER Name
        The directory's leaf name.

    .PARAMETER LivePids
        The process ids alive on this machine right now. A tree whose pid is in here belongs to a
        running suite and is never a leftover.

    .PARAMETER AgeHours
        Hours since the tree was last written. -1 means unknown.

    .PARAMETER MinAgeHours
        Below this, a tree is treated as a live run's even when its pid is absent -- the pid-reuse belt
        described above.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Name,
        [int[]]$LivePids = @(),
        [double]$AgeHours = -1,
        [double]$MinAgeHours = 24
    )

    if (-not $Name) { return 'not-ours' }
    if ($Name -notmatch $script:ScratchLeafPattern) { return 'not-ours' }

    $label = $Matches['label']
    $pid_  = 0
    [void][int]::TryParse($Matches['pid'], [ref]$pid_)

    foreach ($retained in $script:ScratchRetainedLabels) {
        if ($label -eq $retained) { return 'retained' }
    }

    if ($LivePids -contains $pid_) { return 'live' }
    if ($AgeHours -ge 0 -and $AgeHours -lt $MinAgeHours) { return 'live' }

    return 'leftover'
}

function Get-PayloadTreeVerdict {
    <#
    .SYNOPSIS
        What one extracted payload tree under ~/.claude/plugins/cache/ IS: the copy a session loads
        today, a copy no install record points at any more, or one of those still being read by a
        process that is alive.

    .DESCRIPTION
        WHY A TREE AND NOT A RECORD, WHICH IS WHAT MAKES THIS DIFFERENT FROM LANES 8 AND 11. Both of
        those read installed_plugins.json and judge a RECORD. A record is a pointer; its installPath is
        where it points, and what it points AT is an extracted copy of the plugin -- skills, hooks,
        agent defs, the plugin's own scripts. That copy is what a session loads. Measured on
        September 10, 2026 (Claude Code 2.1.267, issue #1812): the running process writes a lease at
        <installPath>/.in_use/<pid> holding {"pid":...,"procStartFt":...} and keeps it for the life of
        the session, and the marketplace clone carries no lease at all. The clone is the catalogue, and
        the source an extraction copies FROM; the payload is the copy that loads.

        WHY THE MACHINE IS NOT ALREADY TIDY. The harness models this artefact itself -- it writes
        .orphaned_at (Unix milliseconds) into a tree no record names, and stamps
        ~/.claude/plugins/.last_inuse_sweep. What it was not observed to do is REMOVE one. On the
        machine measured, 30 of 41 trees carried an orphan mark, the oldest of them six days old, and
        every one of those trees was still on disk; `claude plugin uninstall` removed the record and
        left the payload standing (measured on dkj-team-lifehub@claude-code-specialists the same day).
        Marking is not reaping, and nothing in this workflow was reading the marks.

        AND THIS LANE HANDS OVER NO COMMAND, WHICH IS THE SAME DECISION LANE 10 TOOK. There is no
        `claude plugin cache` verb to hand over -- `claude plugin --help` lists none -- so the only
        line this could print is a recursive Remove-Item at a path under the user's home, which is
        precisely the delete primitive New-ScratchPath exists to remove (#1659, #1668). A tree still
        leased by a live process makes it worse rather than better: the reader would be deleting the
        files a running session is loading from.

        PURE: every fact about the disk and about the process table arrives as a parameter.

    .PARAMETER Path
        The tree's full path -- <cache>/<marketplace>/<plugin>/<version-or-sha>.

    .PARAMETER InstallPaths
        Every installPath in the machine's install register. Compared the way Get-InstallRecord
        compares a projectPath: trailing separator trimmed, case-insensitively, because two spellings
        of one path are not two answers.

    .PARAMETER OrphanMarked
        Does the tree carry the harness's own .orphaned_at file? Reported, never trusted as the
        verdict: the register is the authority on whether a tree is still pointed at, and a mark that
        disagrees with it is worth saying out loud rather than deferring to.

    .PARAMETER LeasePids
        The pids named by files under the tree's .in_use directory.

    .PARAMETER LivePids
        The process ids alive on this machine right now.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Path,
        [string[]]$InstallPaths = @(),
        [bool]$OrphanMarked = $false,
        [int[]]$LeasePids = @(),
        [int[]]$LivePids = @()
    )

    $key = ([string]$Path).TrimEnd('\', '/')
    $owned = $false
    foreach ($ip in @($InstallPaths)) {
        if (-not $ip) { continue }
        if (([string]$ip).TrimEnd('\', '/') -ieq $key) { $owned = $true; break }
    }

    $held  = @(@($LeasePids) | Where-Object { @($LivePids) -contains $_ })
    $stale = @(@($LeasePids) | Where-Object { @($LivePids) -notcontains $_ })

    if ($owned) {
        $reason = if ($OrphanMarked) {
            'an install record points here, yet the harness has marked it orphaned -- one of the two is out of date, and the register is the one to believe.'
        } else {
            'an install record points here: this is a copy a session loads.'
        }
        return [pscustomobject]@{
            Class = 'loaded'; Reason = $reason; HeldBy = $held; StaleLeases = $stale
        }
    }

    if ($held.Count -gt 0) {
        return [pscustomobject]@{
            Class  = 'leased'
            Reason = "no install record points here, but pid $($held -join ', ') is reading it right now -- a session that started before the record moved. It goes when that session does."
            HeldBy = $held; StaleLeases = $stale
        }
    }

    $reason = if ($OrphanMarked) {
        'no install record points here, and the harness has already marked it orphaned -- marking is not reaping, so it stays until something removes it.'
    } else {
        'no install record points here, and the harness has not marked it yet -- its sweep runs on its own schedule.'
    }
    return [pscustomobject]@{
        Class = 'ownerless'; Reason = $reason; HeldBy = $held; StaleLeases = $stale
    }
}

function Get-TidySummaryLine {
    <#
    .SYNOPSIS
        The one-line tally a lane ends with, in the shape every check in this repo prints.

    .DESCRIPTION
        SEPARATED FROM THE PRINTING so the suite can assert the sentence without capturing a console.
        The repo has measured that assertion the other way round twice (#1242, #1248: a test matching
        text against a wrapped WarningRecord), and a pure formatter is the shape that does not have the
        problem at all.

        THE ACTED COUNT COMES FIRST because it is the only number that describes something that
        happened; everything else in the sentence describes something the reader may now choose to do.

    .PARAMETER Lane
        The lane's short name, as the heading printed it.

    .PARAMETER Acted
        How many items this run actually changed.

    .PARAMETER Reported
        How many items were handed over for the reader to decide on.

    .PARAMETER Untouched
        How many items were looked at and deliberately left alone.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Lane,
        [int]$Acted = 0,
        [int]$Reported = 0,
        [int]$Untouched = 0
    )

    $total = $Acted + $Reported + $Untouched
    if ($total -eq 0) { return "$Lane -- nothing found." }
    return "$Lane -- $Acted acted on, $Reported handed over, $Untouched left alone, of $total."
}
